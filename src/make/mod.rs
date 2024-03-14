use crate::i18n::LocalText;
use crate::tui::*;
use crate::*;

use console::style;
use indicatif::{ProgressBar, ProgressStyle};
use regex::Regex;
use std::collections::HashMap;
use std::io::prelude::*;
use std::{ffi::OsString, io};
use subprocess::{Exec, ExitStatus, Redirection};

// FTL: help-subcommand-make
/// Build specified target(s)
pub fn run(target: Vec<String>) -> Result<()> {
    let subcommand_status = SubcommandStatus::new("status-header", "status-good", "status-bad");
    setup::is_setup(subcommand_status)?;
    let subcommand_status = SubcommandStatus::new("make-header", "make-good", "make-bad");
    let mut makeflags: Vec<OsString> = Vec::new();
    let cpus = &num_cpus::get().to_string();
    makeflags.push(OsString::from(format!("--jobs={cpus}")));
    let mut makefiles: Vec<OsString> = Vec::new();
    let rules = status::get_rules()?;
    makefiles.push(OsString::from("-f"));
    makefiles.push(OsString::from(format!(
        "{}{}",
        CONFIGURE_DATADIR, "/rules/casile.mk"
    )));
    for rule in rules {
        makefiles.push(OsString::from("-f"));
        let p = rule.into_os_string();
        makefiles.push(p);
    }
    makefiles.push(OsString::from("-f"));
    makefiles.push(OsString::from(format!(
        "{}{}",
        CONFIGURE_DATADIR, "/rules/rules.mk"
    )));
    let mut targets: Vec<_> = target.into_iter().collect();
    if targets.is_empty() {
        targets.push(String::from("default"));
    }
    let is_gha = status::is_gha()?;
    let is_glc = status::is_glc()?;
    if is_gha {
        targets.push(String::from("_gha"));
    }
    if is_glc {
        targets.push(String::from("_glc"));
    }
    if (is_gha || is_glc)
        && targets.first().unwrap() != "debug"
        && targets.first().unwrap() != ".gitignore"
    {
        targets.push(String::from("install-dist"));
    }
    let mut process = Exec::cmd("make")
        .args(&makeflags)
        .args(&makefiles)
        .args(&targets);
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
    if CONF.get_bool("debug")? {
        process = process.env("DEBUG", "true");
    };
    if CONF.get_bool("quiet")? {
        process = process.env("QUIET", "true");
    };
    if CONF.get_bool("verbose")? || targets.contains(&"debug".into()) {
        process = process.env("VERBOSE", "true");
    };
    let repo = get_repo()?;
    let workdir = repo.workdir().unwrap();
    process = process.cwd(workdir);
    let process = process.stderr(Redirection::Merge).stdout(Redirection::Pipe);
    let mut popen = process.popen()?;
    let mut target_statuses = HashMap::new();
    let buf = io::BufReader::new(popen.stdout.as_mut().unwrap());
    let mut backlog: Vec<String> = Vec::new();
    let seps = Regex::new(r"").unwrap();
    let mut ret: u32 = 0;
    for line in buf.lines() {
        let text: &str =
            &line.unwrap_or_else(|_| String::from("INVALID UTF-8 FROM CHILD PROCESS STREAM"));
        let fields: Vec<&str> = seps.splitn(text, 4).collect();
        match fields[0] {
            "CASILE" => match fields[1] {
                "PRE" => {
                    let target = fields[2].to_owned();
                    let target_status = MakeTargetStatus::new(target.clone());
                    target_statuses.insert(target, target_status);
                }
                "STDOUT" => {
                    let target = fields[2].to_owned();
                    let target_status = target_statuses.get(&target).unwrap();
                    if is_gha || is_glc {
                        target_status.stdout(fields[3]);
                    } else if CONF.get_bool("verbose")? {
                        target_status.stderr(fields[3]);
                    } else {
                        backlog.push(String::from(fields[3]));
                    }
                }
                "STDERR" => {
                    let target = fields[2].to_owned();
                    let target_status = target_statuses.get(&target).unwrap();
                    if is_gha || is_glc {
                        target_status.stderr(fields[3]);
                    } else if CONF.get_bool("verbose")? {
                        target_status.stdout(fields[3]);
                    } else {
                        backlog.push(String::from(fields[3]));
                    }
                }
                "POST" => {
                    let target = fields[3].to_owned();
                    let target_status = target_statuses.get(&target).unwrap();
                    match fields[2] {
                        "0" => {
                            target_status.pass();
                        }
                        val => {
                            target_status.fail();
                            ret = val.parse().unwrap_or(1);
                        }
                    }
                }
                _ => {
                    let errmsg = LocalText::new("make-error-unknown-code").fmt();
                    panic!("{}", errmsg)
                }
            },
            _ => backlog.push(String::from(fields[0])),
        }
    }
    let status = popen.wait();
    let ret = match status {
        Ok(ExitStatus::Exited(int)) => {
            let code = int + ret;
            match code {
                0 => {
                    if CONF.get_bool("debug")?
                        || targets.contains(&"debug".into())
                        || targets.contains(&"-p".into())
                    {
                        dump_backlog(&backlog)
                    };
                    Ok(())
                }
                1 => {
                    dump_backlog(&backlog);
                    Err(Box::new(io::Error::new(
                        io::ErrorKind::InvalidInput,
                        LocalText::new("make-error-unfinished").fmt(),
                    )))
                }
                2 => {
                    dump_backlog(&backlog);
                    Err(Box::new(io::Error::new(
                        io::ErrorKind::InvalidInput,
                        LocalText::new("make-error-build").fmt(),
                    )))
                }
                3 => {
                    if !CONF.get_bool("verbose")? {
                        dump_backlog(&backlog);
                    }
                    Err(Box::new(io::Error::new(
                        io::ErrorKind::InvalidInput,
                        LocalText::new("make-error-target").fmt(),
                    )))
                }
                137 => {
                    if !CONF.get_bool("verbose")? {
                        dump_backlog(&backlog);
                    }
                    Err(Box::new(io::Error::new(
                        io::ErrorKind::InvalidInput,
                        LocalText::new("make-error-oom").fmt(),
                    )))
                }
                _ => {
                    dump_backlog(&backlog);
                    Err(Box::new(io::Error::new(
                        io::ErrorKind::InvalidInput,
                        LocalText::new("make-error-unknown").fmt(),
                    )))
                }
            }
        }
        _ => Err(Box::new(io::Error::new(
            io::ErrorKind::InvalidInput,
            LocalText::new("make-error").fmt(),
        ))),
    };
    subcommand_status.end(ret.is_ok());
    Ok(ret?)
}

fn dump_backlog(backlog: &[String]) {
    let bar = ProgressBar::new_spinner().with_style(ProgressStyle::with_template("{msg}").unwrap());
    let bar = TUI.add(bar);
    let mut dump = String::new();
    let start = LocalText::new("make-backlog-start").fmt();
    let start = format!("{} {start}\n", style(style("┄┄┄┄┄┄").cyan()));
    dump.push_str(start.as_str());
    let backlog_dump_file = ".casile/backlog_dump";
    let mut backlog_dump_file = std::fs::File::create(backlog_dump_file).unwrap();
    for line in backlog.iter() {
        write!(backlog_dump_file, "{line}\n").unwrap();
        dump.push_str(line.as_str());
        dump.push('\n');
    }
    let end = LocalText::new("make-backlog-end").fmt();
    let end = format!("{} {end}", style(style("┄┄┄┄┄").cyan()));
    dump.push_str(end.as_str());
    bar.set_message(dump);
    bar.finish();
}
