//! Secret scanning module.
//!
//! Scans source files for potential hardcoded secrets like passwords, API keys, and tokens.

use crate::error::Result;
use crate::security::{Finding, Severity};
use ignore::WalkBuilder;
use lazy_static::lazy_static;
use regex::Regex;
use std::fs;
use std::path::{Path, PathBuf};

lazy_static! {
    /// Regex patterns for detecting secrets.
    static ref SECRET_PATTERNS: Vec<SecretPattern> = vec![
        SecretPattern {
            name: "Password",
            regex: Regex::new(r#"(?i)(password|passwd|pwd)\s*[:=]\s*["']([^"']{3,})["']"#).unwrap(),
            severity: Severity::Critical,
        },
        SecretPattern {
            name: "API Key",
            regex: Regex::new(r#"(?i)(api[_-]?key|apikey)\s*[:=]\s*["']([^"']{10,})["']"#).unwrap(),
            severity: Severity::Critical,
        },
        SecretPattern {
            name: "Secret Key",
            regex: Regex::new(r#"(?i)(secret[_-]?key|secretkey)\s*[:=]\s*["']([^"']{10,})["']"#).unwrap(),
            severity: Severity::Critical,
        },
        SecretPattern {
            name: "Access Token",
            regex: Regex::new(r#"(?i)(access[_-]?token|accesstoken)\s*[:=]\s*["']([^"']{10,})["']"#).unwrap(),
            severity: Severity::Critical,
        },
        SecretPattern {
            name: "Auth Token",
            regex: Regex::new(r#"(?i)(auth[_-]?token|authtoken)\s*[:=]\s*["']([^"']{10,})["']"#).unwrap(),
            severity: Severity::Critical,
        },
        SecretPattern {
            name: "Bearer Token",
            regex: Regex::new(r#"(?i)bearer\s+([a-zA-Z0-9_\-\.]{20,})"#).unwrap(),
            severity: Severity::High,
        },
        SecretPattern {
            name: "Private Key",
            regex: Regex::new(r#"(?i)(private[_-]?key|privatekey)\s*[:=]\s*["']([^"']{10,})["']"#).unwrap(),
            severity: Severity::Critical,
        },
        SecretPattern {
            name: "AWS Access Key",
            regex: Regex::new(r#"(?i)(aws[_-]?access[_-]?key|aws_access_key_id)\s*[:=]\s*["']([A-Z0-9]{20})["']"#).unwrap(),
            severity: Severity::Critical,
        },
        SecretPattern {
            name: "AWS Secret Key",
            regex: Regex::new(r#"(?i)(aws[_-]?secret[_-]?key|aws_secret_access_key)\s*[:=]\s*["']([A-Za-z0-9/+=]{40})["']"#).unwrap(),
            severity: Severity::Critical,
        },
        SecretPattern {
            name: "RSA Private Key",
            regex: Regex::new(r#"-----BEGIN (RSA|DSA|EC) PRIVATE KEY-----"#).unwrap(),
            severity: Severity::Critical,
        },
        SecretPattern {
            name: "GitHub Token",
            regex: Regex::new(r#"gh[pousr]_[A-Za-z0-9_]{36,}"#).unwrap(),
            severity: Severity::Critical,
        },
        SecretPattern {
            name: "Generic Secret",
            regex: Regex::new(r#"(?i)(secret|token)\s*[:=]\s*["']([a-zA-Z0-9_\-\.]{20,})["']"#).unwrap(),
            severity: Severity::Medium,
        },
    ];
}

/// A pattern for detecting secrets.
struct SecretPattern {
    name: &'static str,
    regex: Regex,
    severity: Severity,
}

/// Scanner for detecting hardcoded secrets.
pub struct SecretScanner {
    project_root: PathBuf,
}

impl SecretScanner {
    /// Create a new secret scanner.
    pub fn new(project_root: &Path) -> Self {
        Self {
            project_root: project_root.to_path_buf(),
        }
    }

    /// Scan for hardcoded secrets.
    pub fn scan(&self) -> Result<Vec<Finding>> {
        tracing::info!("Scanning for hardcoded secrets");

        let mut findings = Vec::new();

        // Walk through relevant source files
        for entry in WalkBuilder::new(&self.project_root)
            .filter_entry(|e| !Self::is_excluded(e.path()))
            .build()
        {
            let entry = entry?;
            let path = entry.path();

            if Self::should_scan(path) {
                if let Ok(content) = fs::read_to_string(path) {
                    findings.extend(self.scan_file(path, &content)?);
                }
            }
        }

        tracing::info!("Found {} potential secrets", findings.len());
        Ok(findings)
    }

    fn is_excluded(path: &Path) -> bool {
        let path_str = path.to_string_lossy();
        path_str.contains("target/")
            || path_str.contains("node_modules/")
            || path_str.contains(".git/")
            || path_str.contains("test")
            || path_str.contains("example")
    }

    fn should_scan(path: &Path) -> bool {
        if let Some(ext) = path.extension().and_then(|s| s.to_str()) {
            matches!(
                ext,
                "rs" | "toml" | "yaml" | "yml" | "json" | "env" | "sh" | "py" | "js" | "ts"
            )
        } else {
            false
        }
    }

    fn scan_file(&self, path: &Path, content: &str) -> Result<Vec<Finding>> {
        let mut findings = Vec::new();

        for (line_num, line) in content.lines().enumerate() {
            // Skip comments (basic heuristic)
            let trimmed = line.trim();
            if trimmed.starts_with("//") || trimmed.starts_with('#') || trimmed.starts_with("/*") {
                // Check if it contains "TODO", "FIXME", "example" - these are likely not real secrets
                if trimmed.to_lowercase().contains("todo")
                    || trimmed.to_lowercase().contains("fixme")
                    || trimmed.to_lowercase().contains("example")
                {
                    continue;
                }
            }

            for pattern in SECRET_PATTERNS.iter() {
                if pattern.regex.is_match(line) {
                    // Filter out obvious false positives
                    if Self::is_false_positive(line) {
                        continue;
                    }

                    let relative_path = path
                        .strip_prefix(&self.project_root)
                        .unwrap_or(path)
                        .to_path_buf();

                    findings.push(Finding {
                        severity: pattern.severity,
                        category: "secret".to_string(),
                        title: format!("Potential hardcoded {}", pattern.name),
                        message: format!(
                            "Found potential hardcoded {} in source code. Never commit secrets to version control.",
                            pattern.name
                        ),
                        file: relative_path,
                        line: Some(line_num + 1),
                        column: None,
                        snippet: Some(Self::redact_secret(line)),
                        recommendation: Some(
                            "Use environment variables or a secret management service (e.g., AWS Secrets Manager, HashiCorp Vault) instead of hardcoding secrets.".to_string(),
                        ),
                    });
                }
            }
        }

        Ok(findings)
    }

    fn is_false_positive(line: &str) -> bool {
        let lower = line.to_lowercase();
        lower.contains("example")
            || lower.contains("test")
            || lower.contains("placeholder")
            || lower.contains("your-")
            || lower.contains("xxx")
            || lower.contains("***")
            || lower.contains("changeme")
            || lower.contains("replace")
    }

    fn redact_secret(line: &str) -> String {
        // Redact potential secret values for display
        let mut redacted = line.to_string();
        for pattern in SECRET_PATTERNS.iter() {
            if let Some(captures) = pattern.regex.captures(line) {
                if let Some(secret) = captures.get(2).or_else(|| captures.get(1)) {
                    let secret_str = secret.as_str();
                    if secret_str.len() > 4 {
                        let visible = &secret_str[..4];
                        let masked = "*".repeat(secret_str.len() - 4);
                        redacted = redacted.replace(secret_str, &format!("{}{}",visible, masked));
                    }
                }
            }
        }
        redacted
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_secret_scanner_detects_password() {
        let dir = TempDir::new().unwrap();
        // Create a subdirectory that won't be filtered out by "test" exclusion
        let src_dir = dir.path().join("src");
        fs::create_dir(&src_dir).unwrap();
        let file_path = src_dir.join("config.rs");
        // Use a format that matches the regex pattern more directly
        fs::write(
            &file_path,
            r#"
// Configuration
let password = "super_secret_password_123";
let api_key = "sk_live_1234567890abcdefghij";
"#,
        )
        .unwrap();

        let scanner = SecretScanner::new(dir.path());
        let findings = scanner.scan().unwrap();

        assert!(!findings.is_empty(), "Expected to find at least one secret");
        assert!(findings.iter().any(|f| f.category == "secret"));
    }

    #[test]
    fn test_secret_scanner_ignores_placeholders() {
        let dir = TempDir::new().unwrap();
        let src_dir = dir.path().join("src");
        fs::create_dir(&src_dir).unwrap();
        let file_path = src_dir.join("config.rs");
        fs::write(
            &file_path,
            r#"
// Example configuration - replace with your values
const PASSWORD: &str = "your-password-here";
const API_KEY: &str = "example-api-key";
"#,
        )
        .unwrap();

        let scanner = SecretScanner::new(dir.path());
        let findings = scanner.scan().unwrap();

        // Should not flag placeholders
        assert_eq!(findings.len(), 0);
    }

    #[test]
    fn test_redact_secret() {
        let line = r#"password = "secretvalue123""#;
        let redacted = SecretScanner::redact_secret(line);
        assert!(redacted.contains("****"));
        assert!(!redacted.contains("secretvalue123"));
    }
}
