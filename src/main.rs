use structopt::StructOpt;
use structopt::clap::AppSettings;
use std::path;
use std::vec;
use std::fs;
use std::io;
use std::io::{Error, ErrorKind};
use git2::Repository;

/// The command line interface to the CaSILE toolkit, a book publishing
/// workflow employing SILE and other wizardry
#[derive(StructOpt)]
#[structopt(version = env!("VERGEN_SEMVER"))]
#[structopt(setting = AppSettings::InferSubcommands)]
struct Cli {

    /// Activate debug mode
    #[structopt(short, long, env = "DEBUG")]
    debug: bool,

    /// Outputs verbose feedback where possible
    #[structopt(short, long)]
    verbose: bool,

    #[structopt(subcommand)]
    subcommand: Subcommand,

}

#[derive(StructOpt)]
enum Subcommand {

    /// Executes a make target
    Make {

        /// Target as defined in CaSILE makefile
        target: Vec<String>,

    },

    /// Configure a book repository
    Setup {

        /// Path to project repository
        #[structopt(parse(from_os_str), default_value = "./")]
        path: path::PathBuf,

    },

    /// Pass through other commands to shell
    #[structopt(external_subcommand)]
    Other(Vec<String>),

}

fn main () -> io::Result<()> {

    let args = Cli::from_args();

    if args.debug {
        println!("User requested debug mode")
    }

    if args.verbose {
        println!("User requested verbose output")
    }

    return match args.subcommand {
        Subcommand::Make{ target } => make(target),
        Subcommand::Setup{ path } => setup(path),
        _a => shell(),
    }

}

fn make (_target: vec::Vec<String>) -> io::Result<()> {

    println!("Make make make sense or I’ll make you make makefiles.");

    Ok(())
}

fn setup (path: path::PathBuf) -> io::Result<()> {

    let metadata = fs::metadata(&path)?;

    return match metadata.is_dir() {
        true => match Repository::open(path) {
            Ok(_repo) => Ok(
                println!("Run setup, “They said you were this great colossus!”")
            ),
            Err(_error) => Err(Error::new(ErrorKind::InvalidInput, "Not a git repo!")),
        },
        false => Err(Error::new(ErrorKind::InvalidInput, "Not a dir, Frank!")),
    }

}

fn shell () -> io::Result<()> {

    println!("Ship all this off to the shell, maybe they can handle it.");

    Ok(())
}
