//! Markdown report generator.

use crate::error::Result;
use crate::security::{SecurityReport, Severity};

/// Generate a Markdown report.
pub fn generate(report: &SecurityReport) -> Result<String> {
    let mut md = String::new();

    // Title
    md.push_str("# Security Scan Report\n\n");

    // Metadata
    md.push_str(&format!("**Generated**: {}\n", report.timestamp.format("%Y-%m-%d %H:%M:%S UTC")));
    md.push_str(&format!("**Project**: {}\n", report.project_root.display()));

    if let Some(commit) = &report.git_commit {
        md.push_str(&format!("**Commit**: `{}`\n", commit));
    }
    if let Some(branch) = &report.git_branch {
        md.push_str(&format!("**Branch**: `{}`\n", branch));
    }

    md.push_str("\n---\n\n");

    // Summary
    md.push_str("## Summary\n\n");
    md.push_str(&format!("- **Total Findings**: {}\n", report.summary.total));
    md.push_str(&format!("- **Critical**: {} 🔴\n", report.summary.critical));
    md.push_str(&format!("- **High**: {} 🟠\n", report.summary.high));
    md.push_str(&format!("- **Medium**: {} 🟡\n", report.summary.medium));
    md.push_str(&format!("- **Low**: {} 🟢\n", report.summary.low));
    md.push_str(&format!("- **Scan Duration**: {:.2}s\n", report.summary.duration_seconds));

    md.push_str("\n");

    // Status
    if report.summary.total == 0 {
        md.push_str("✅ **Status**: No security issues found!\n\n");
    } else if report.summary.critical > 0 {
        md.push_str("🔴 **Status**: CRITICAL issues found - immediate action required\n\n");
    } else if report.summary.high > 0 {
        md.push_str("🟠 **Status**: HIGH severity issues found - fix soon\n\n");
    } else {
        md.push_str("🟡 **Status**: Issues found - review recommended\n\n");
    }

    if report.findings.is_empty() {
        return Ok(md);
    }

    md.push_str("---\n\n");

    // Findings by severity
    for severity in [Severity::Critical, Severity::High, Severity::Medium, Severity::Low] {
        let severity_findings: Vec<_> = report
            .findings
            .iter()
            .filter(|f| f.severity == severity)
            .collect();

        if severity_findings.is_empty() {
            continue;
        }

        let emoji = match severity {
            Severity::Critical => "🔴",
            Severity::High => "🟠",
            Severity::Medium => "🟡",
            Severity::Low => "🟢",
        };

        md.push_str(&format!("## {} {} Severity Findings\n\n", emoji, severity));

        for (i, finding) in severity_findings.iter().enumerate() {
            md.push_str(&format!("### {}.{} {}\n\n", severity, i + 1, finding.title));

            md.push_str(&format!("- **Category**: `{}`\n", finding.category));
            md.push_str(&format!("- **Severity**: {}\n", severity));
            md.push_str(&format!("- **File**: `{}`\n", finding.file.display()));

            if let Some(line) = finding.line {
                md.push_str(&format!("- **Line**: {}\n", line));
            }

            md.push_str(&format!("\n**Message**: {}\n\n", finding.message));

            if let Some(snippet) = &finding.snippet {
                md.push_str("**Code**:\n");
                md.push_str("```rust\n");
                md.push_str(snippet);
                md.push_str("\n```\n\n");
            }

            if let Some(recommendation) = &finding.recommendation {
                md.push_str(&format!("**Recommendation**: {}\n\n", recommendation));
            }

            md.push_str("---\n\n");
        }
    }

    // Recommendations
    md.push_str("## General Recommendations\n\n");
    md.push_str("1. Address all Critical and High severity findings immediately\n");
    md.push_str("2. Review and plan fixes for Medium severity findings\n");
    md.push_str("3. Consider fixing Low severity findings during refactoring\n");
    md.push_str("4. Re-run security scan after fixes to verify resolution\n");
    md.push_str("5. Integrate security scanning into CI/CD pipeline\n\n");

    Ok(md)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::security::Finding;
    use std::path::PathBuf;

    #[test]
    fn test_markdown_generation_empty() {
        let report = SecurityReport::new(PathBuf::from("."), vec![]);
        let md = generate(&report).unwrap();
        assert!(md.contains("# Security Scan Report"));
        assert!(md.contains("No security issues found"));
    }

    #[test]
    fn test_markdown_generation_with_findings() {
        let findings = vec![Finding {
            severity: Severity::Critical,
            category: "test".to_string(),
            title: "Test Finding".to_string(),
            message: "Test message".to_string(),
            file: PathBuf::from("test.rs"),
            line: Some(42),
            column: None,
            snippet: Some("let x = unsafe { ... };".to_string()),
            recommendation: Some("Fix this immediately".to_string()),
        }];

        let report = SecurityReport::new(PathBuf::from("."), findings);
        let md = generate(&report).unwrap();

        assert!(md.contains("Test Finding"));
        assert!(md.contains("test.rs"));
        assert!(md.contains("Line**: 42"));
        assert!(md.contains("Fix this immediately"));
    }
}
