use crate::*;

use std::io::prelude::*;
use std::{ffi::OsString, io};
use subprocess::{Exec, Redirection};

// FTL: help-subcommand-script
/// Run helper script inside CaSILE environment
pub fn run(name: String, arguments: Vec<OsString>) -> Result<()> {
    setup::is_setup()?;
    show_header("script-header");
    let cpus = &num_cpus::get().to_string();
    let mut process = Exec::cmd(format!("{CONFIGURE_DATADIR}/scripts/{name}")).args(&arguments);
    let gitname = status::get_gitname()?;
    let git_version = status::get_git_version();
    process = process
        .env("CASILE_CLI", "true")
        .env("CASILE_JOBS", cpus)
        .env("CASILEDIR", CONFIGURE_DATADIR)
        .env("CONTAINERIZED", status::is_container().to_string())
        .env("LANGUAGE", locale_to_language(CONF.get_string("language")?))
        .env("PROJECT", gitname)
        .env("PROJECTDIR", CONF.get_string("path")?)
        .env("PROJECTVERSION", git_version);
    let repo = get_repo()?;
    let workdir = repo.workdir().unwrap();
    process = process.cwd(workdir);
    let process = process.stderr(Redirection::Pipe).stdout(Redirection::Pipe);
    let mut popen = process.popen()?;
    let buf = io::BufReader::new(popen.stdout.as_mut().unwrap());
    for line in buf.lines() {
        let text: &str =
            &line.unwrap_or_else(|_| String::from("INVALID UTF-8 FROM CHILD PROCESS STREAM"));
        println!("{text}");
    }
    Ok(())
}
