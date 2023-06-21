# Currently hard coded, see clap issue #1880
help-description =
  The command line interface to the CaSILE toolkit,
  a publishing workflow employing SILE and other wizardry.

# Currently hard coded, see clap issue #1880
help-flags-debug =
  Enable extra debug output from tooling

# Currently hard coded, see clap issue #1880
help-flags-language =
  Set language

# Currently hard coded, see clap issue #1880
help-flags-quiet =
  Enable extra debug output from tooling

# Currently hard coded, see clap issue #1880
help-flags-verbose =
  Enable extra verbose output from tooling

# Currently hard coded, see clap issue #1880
help-subcommand-make =
  Build specified target(s) with ‘make’

# Currently hard coded, see clap issue #1880
help-subcommand-make-target =
  Target as defined by rules in CaSILE or project

help-subcommand-script =
  Run helper script inside CaSILE environment

help-subcommand-script-name =
  Script name as supplied by CaSILE, toolkit, or project

help-subcommand-script-arguments =
  Arguments to pass to script

# Currently hard coded, see clap issue #1880
help-subcommand-setup =
  Setup a publishing project for use with CaSILE

# Currently hard coded, see clap issue #1880
help-subcommand-setup-path =
  Path to publishing project repository

error-not-setup =
  This project path (if it is a project path) is not setup for use with
  CaSILE.  Please run run ‘casile status’ for details or ‘casile setup’
  to initialize it properly.

error-invalid-language =
  Could not parse BCP47 language tag.

error-invalid-resources =
  Could not find valid BCP47 resource files.

error-no-remote =
  Git repository does not have a working remote named 'origin'.

error-no-path =
  Cannot parse directory path.

welcome =
  Welcome to CaSILE { $version }!

outro =
  CaSILE run complete

make-header =
  Building target(s) using ‘make’

make-report-start =
  Starting make job for target: { $target }

make-report-end =
  Finished make job for target: { $target }

make-report-fail =
  Failed make job for target: { $target }

make-backlog-start =
  Dumping captured output of ‘make’

make-backlog-end =
  End dump

make-error-unknown-code =
  Make returned an action code CaSILE doesn't have a handler for.  The most
  likely cause is the shell helper script being out of sync with the CLI
  binary.  Needless to say this should not have happened. If you are not
  currently hacking on CaSILE itself please report this as a bug.

make-error =
  Failed to execute a subprocess for ‘make’.

make-error-oom =
  Make reported process aborted because system ran out of memory (OOM).

make-error-unfinished =
  Make reported outdated targets were not built.

make-error-build =
  Make failed to parse or execute a build plan.

make-error-target =
  Make failed to execute a recipe.

make-error-unknown =
  Make returned unknown error.

script-header =
  Running script inside CaSILE environment

setup-header =
  Configuring repository for use with CaSILE

setup-true =
  Yes

setup-false =
  No

setup-good =
  Everything seems to be ship shape, warm up the presses!

setup-bad =
  Hold the presses, something isn’t right, run ‘casile setup’

setup-is-repo =
  Is the path a Git repository?

setup-is-deep =
  Is the Git a deep clone?

setup-is-not-casile =
  Are we not in the CaSILE source repository?

setup-is-writable =
  Can we write to the project base directory?

setup-is-make-executable =
  Is the system’s ‘make’ executable?

setup-is-make-gnu =
  Is the system’s ‘make’ a supported version of GNU Make?

setup-gitignore-committing =
  Committing updated .gitignore file

setup-gitignore-fresh =
  Existing .gitignore file is up to date

setup-short-shas =
  Setting default length of short SHA hashes in repository

setup-warp-time =
  Reseting version tracked file timestamps to last affecting commit

setup-warp-time-file =
  Rewound clock on { $path }

status-header =
  Scanning project status

status-is-gha =
  Are we running as a GitHub Action?

status-is-glc =
  Are we running as a GitLab CI job?
