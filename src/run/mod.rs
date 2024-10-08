use crate::ui::*;
use crate::*;

use std::io::prelude::*;
use std::{ffi::OsString, io};
use subprocess::{Exec, Redirection};

// FTL: help-subcommand-run
/// Run helper script inside CaSILE environment
pub fn run(name: String, arguments: Vec<OsString>) -> Result<()> {
    setup::is_setup()?;
    let subcommand_status = CASILEUI.new_subcommand("run");
    let cpus = &num_cpus::get().to_string();
    let mut process = Exec::cmd(format!("{CONFIGURE_DATADIR}/scripts/{name}")).args(&arguments);
    let gitname = status::get_gitname()?;
    let git_version = status::get_git_version();
    process = process
        .env("BUILDDIR", CONF.get_string("builddir")?)
        .env("CASILE_CLI", "true")
        .env("CASILE_JOBS", cpus)
        .env("CASILEDIR", CONFIGURE_DATADIR)
        .env("CONTAINERIZED", status::is_container().to_string())
        .env("LANGUAGE", locale_to_language(CONF.get_string("language")?))
        .env("PROJECT", gitname)
        .env("PROJECTDIR", CONF.get_string("project")?)
        .env("PROJECTVERSION", git_version);
    let repo = get_repo()?;
    let workdir = repo.workdir().unwrap();
    process = process
        .cwd(workdir)
        .stderr(Redirection::Pipe)
        .stdout(Redirection::Pipe);
    let mut popen = process.popen()?;
    let bufstdout = io::BufReader::new(popen.stdout.as_mut().unwrap());
    let bufstderr = io::BufReader::new(popen.stderr.as_mut().unwrap());
    for line in bufstdout.lines() {
        let text: &str =
            &line.unwrap_or_else(|_| String::from("INVALID UTF-8 FROM CHILD PROCESS STREAM"));
        println!("{text}");
    }
    for line in bufstderr.lines() {
        let text: &str =
            &line.unwrap_or_else(|_| String::from("INVALID UTF-8 FROM CHILD PROCESS STREAM"));
        eprintln!("{text}");
    }
    let status = popen.wait().expect("Script failed to run");
    subcommand_status.end(status.success());
    // TODO: figure out how to pass through error code from script
    //if status.success() {
    Ok(())
    //} else {
    //    Err(Error::new("error-)
    //}
}
