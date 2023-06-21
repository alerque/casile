use clap::{Args, Command, FromArgMatches as _};

use casile::cli::{Cli, Commands};
use casile::config::CONF;
use casile::{make, script, setup, status};
use casile::{Result, VERSION};

fn main() -> Result<()> {
    CONF.defaults()?;
    CONF.merge_env()?;
    CONF.merge_files()?;
    let cli = Command::new("casile").version(*VERSION);
    let cli = Cli::augment_args(cli);
    let matches = cli.get_matches();
    let args = Cli::from_arg_matches(&matches).expect("Unable to parse arguments");
    CONF.merge_args(&args)?;
    casile::show_welcome();
    let subcommand = Commands::from_arg_matches(&matches)?;
    let ret = match subcommand {
        Commands::Make { target } => make::run(target),
        Commands::Script { name, arguments } => script::run(name, arguments),
        Commands::Setup {} => setup::run(),
        Commands::Status {} => status::run(),
    };
    casile::show_outro();
    ret
}
