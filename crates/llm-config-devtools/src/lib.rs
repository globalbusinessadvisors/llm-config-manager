//! LLM Config Manager Development Tools
//!
//! This crate provides enterprise-grade security scanning and development tools
//! for the LLM Config Manager project.
//!
//! # Features
//!
//! - **Security Scanning**: Comprehensive code security analysis
//!   - Clippy security lints integration
//!   - Unsafe code detection
//!   - Secret scanning
//!   - SQL injection vulnerability detection
//!
//! - **Report Generation**: Multiple output formats
//!   - JSON (machine-readable)
//!   - YAML (human-readable structured)
//!   - Markdown (documentation)
//!   - SARIF (GitHub Security integration)
//!
//! # Usage
//!
//! ## As a Library
//!
//! ```rust,no_run
//! use llm_config_devtools::security::{SecurityScanner, ScanConfig};
//! use llm_config_devtools::report::{generate_report, OutputFormat};
//! use std::path::PathBuf;
//!
//! # fn main() -> Result<(), Box<dyn std::error::Error>> {
//! let config = ScanConfig {
//!     project_root: PathBuf::from("."),
//!     scan_clippy: true,
//!     scan_unsafe: true,
//!     scan_secrets: true,
//!     scan_sql: true,
//!     max_workers: None,
//! };
//!
//! let scanner = SecurityScanner::new(config);
//! let report = scanner.scan()?;
//!
//! let markdown = generate_report(&report, OutputFormat::Markdown)?;
//! println!("{}", markdown);
//! # Ok(())
//! # }
//! ```
//!
//! ## As a CLI Tool
//!
//! ```bash
//! # Run security scan
//! llm-security-scan --output report.md --format markdown
//!
//! # Generate SARIF for GitHub
//! llm-security-scan --output results.sarif --format sarif
//! ```

#![warn(missing_docs)]
#![warn(clippy::all)]
#![warn(clippy::pedantic)]
#![warn(clippy::nursery)]
#![allow(clippy::module_name_repetitions)]

pub mod error;
pub mod report;
pub mod security;

pub use error::{DevtoolsError, Result};

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_library_exports() {
        // Verify key types are exported
        let _: Result<()> = Ok(());
    }
}
