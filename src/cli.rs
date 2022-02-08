use clap::{AppSettings, Parser, Subcommand};
use std::path;

// FTL: help-description
/// The `casile` command is the CLI interface providing access to CaSILE functionality. Most
/// functions are accessed through subcommands.
///
/// The CaSILE toolkit is a build system that glues together a large collection of tools into
/// a cohesive system that automates book publishing from start to finish. The concept is to take
/// very simple, easily edited content and configuration files as input and turn them into all the
/// artifacts of a finished product with as little manual intervention as possible. Plain text
/// document formats and a small amount of meta data are transformed automatically into press ready
/// PDFs, E-Books, and rendered promotional materials.
#[derive(Parser, Debug)]
#[clap(bin_name = "casile")]
#[clap(about)]
#[clap(setting = AppSettings::InferSubcommands)]
pub struct Cli {
    // FTL: help-flags-debug
    /// Enable extra debug output from tooling
    #[clap(short, long)]
    pub debug: bool,

    // FTL: help-flags-language
    /// Set language
    #[clap(short, long)]
    pub language: Option<String>,

    // FTL: help-flags-path
    /// Set project root path
    #[clap(short, long, default_value = "./")]
    pub path: path::PathBuf,

    // FTL: help-flags-quiet
    /// Discard all non-error output messages
    #[clap(short, long)]
    pub quiet: bool,

    // FTL: help-flags-verbose
    /// Enable extra verbose output from tooling
    #[clap(short, long)]
    pub verbose: bool,

    #[clap(subcommand)]
    pub subcommand: Commands,
}

#[derive(Subcommand, Debug)]
pub enum Commands {
    // FTL: help-subcommand-make
    /// Build specified target(s) with ‘make’
    Make {
        // FTL: help-subcommand-make-target
        /// Target as defined in CaSILE or project rules
        target: Vec<String>,
    },

    // FTL: help-subcommand-setup
    /// Configure a publishing project repository
    Setup {},

    // FTL: help-subcommand-status
    /// Show status information about setup, configuration, and build state
    Status {},
}
