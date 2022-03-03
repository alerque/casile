use crate::cli::Cli;
use crate::status;
use crate::Result;

use config::{Config, Environment, File, FileFormat};
use std::{env, sync::RwLock};

static ERROR_CONFIG_WRITE: &str = "Unable to gain write lock on global app config";
static ERROR_CONFIG_READ: &str = "Unable to gain read lock on global app config";

lazy_static! {
    pub static ref CONF: RwLock<Config> = RwLock::new(Config::default());
}

impl CONF {
    pub fn defaults(&self) -> Result<()> {
        let mut config = self.write().expect(ERROR_CONFIG_WRITE);
        config
            .set_default("debug", false)?
            .set_default("quiet", false)?
            .set_default("verbose", false)?
            .set_default("language", crate::DEFAULT_LOCALE)?
            .set_default("path", "./")?;
        Ok(())
    }

    pub fn merge_env(&self) -> Result<()> {
        let mut config = self.write().expect(ERROR_CONFIG_WRITE);
        if let Some(lang) = env::var_os("LANG") {
            if lang.len() > 0 && env::var_os("CASILE_LANGUAGELANG").is_none() {
                env::set_var("CASILE_LANGUAGE", lang)
            }
        }
        config.merge(Environment::with_prefix("casile"))?;
        Ok(())
    }

    pub fn merge_files(&self) -> Result<()> {
        let confs = status::get_confs()?;
        let mut config = self.write().expect(ERROR_CONFIG_WRITE);
        for (_, conf) in confs.iter().enumerate() {
            let f = File::new(conf.to_str().unwrap(), FileFormat::Yaml);
            config.merge(f).unwrap();
        }
        Ok(())
    }

    pub fn merge_args(&self, args: &Cli) -> Result<()> {
        if args.debug {
            self.set_bool("debug", true)?;
            self.set_bool("verbose", true)?;
        } else if args.verbose {
            self.set_bool("verbose", true)?;
        } else if args.quiet {
            self.set_bool("quiet", true)?;
        }
        if let Some(path) = &args.path.to_str() {
            self.set_str("path", path)?;
        }
        if let Some(language) = &args.language {
            self.set_str("language", language)?;
        };
        Ok(())
    }

    pub fn set_bool(&self, key: &str, val: bool) -> Result<()> {
        self.write().expect(ERROR_CONFIG_WRITE).set(key, val)?;
        Ok(())
    }

    pub fn get_bool(&self, key: &str) -> Result<bool> {
        Ok(self.read().expect(ERROR_CONFIG_READ).get_bool(key)?)
    }

    pub fn set_str(&self, key: &str, val: &str) -> Result<()> {
        self.write().expect(ERROR_CONFIG_WRITE).set(key, val)?;
        Ok(())
    }

    pub fn get_string(&self, key: &str) -> Result<String> {
        Ok(self.read().expect(ERROR_CONFIG_READ).get_str(key)?)
    }
}
