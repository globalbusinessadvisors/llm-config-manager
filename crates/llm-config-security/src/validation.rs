//! Generic validation framework

use crate::errors::{SecurityError, SecurityResult};
use std::collections::HashMap;

/// Validation rule
pub trait ValidationRule: Send + Sync {
    /// Validate a value
    fn validate(&self, value: &str) -> SecurityResult<()>;

    /// Get the rule name
    fn name(&self) -> &str;

    /// Get the rule description
    fn description(&self) -> &str;
}

/// Composite validator
pub struct Validator {
    rules: HashMap<String, Box<dyn ValidationRule>>,
}

impl Validator {
    /// Create a new validator
    pub fn new() -> Self {
        Self {
            rules: HashMap::new(),
        }
    }

    /// Add a validation rule
    pub fn add_rule(&mut self, name: String, rule: Box<dyn ValidationRule>) {
        self.rules.insert(name, rule);
    }

    /// Remove a validation rule
    pub fn remove_rule(&mut self, name: &str) {
        self.rules.remove(name);
    }

    /// Validate a value against all rules
    pub fn validate_all(&self, value: &str) -> SecurityResult<()> {
        for (name, rule) in &self.rules {
            rule.validate(value).map_err(|e| {
                SecurityError::ValidationError(format!("Rule '{}' failed: {}", name, e))
            })?;
        }
        Ok(())
    }

    /// Validate against specific rules
    pub fn validate_with(&self, value: &str, rule_names: &[&str]) -> SecurityResult<()> {
        for name in rule_names {
            if let Some(rule) = self.rules.get(*name) {
                rule.validate(value).map_err(|e| {
                    SecurityError::ValidationError(format!("Rule '{}' failed: {}", name, e))
                })?;
            } else {
                return Err(SecurityError::ValidationError(format!(
                    "Rule '{}' not found",
                    name
                )));
            }
        }
        Ok(())
    }

    /// Get all rule names
    pub fn get_rule_names(&self) -> Vec<String> {
        self.rules.keys().cloned().collect()
    }
}

impl Default for Validator {
    fn default() -> Self {
        Self::new()
    }
}

/// Length validation rule
pub struct LengthRule {
    min: usize,
    max: usize,
}

impl LengthRule {
    pub fn new(min: usize, max: usize) -> Self {
        Self { min, max }
    }
}

impl ValidationRule for LengthRule {
    fn validate(&self, value: &str) -> SecurityResult<()> {
        let len = value.len();
        if len < self.min {
            return Err(SecurityError::ValidationError(format!(
                "Value too short (minimum {} characters)",
                self.min
            )));
        }
        if len > self.max {
            return Err(SecurityError::ValidationError(format!(
                "Value too long (maximum {} characters)",
                self.max
            )));
        }
        Ok(())
    }

    fn name(&self) -> &str {
        "length"
    }

    fn description(&self) -> &str {
        "Validates string length"
    }
}

/// Regex validation rule
pub struct RegexRule {
    pattern: regex::Regex,
    description_text: String,
}

impl RegexRule {
    pub fn new(pattern: regex::Regex, description: String) -> Self {
        Self {
            pattern,
            description_text: description,
        }
    }
}

impl ValidationRule for RegexRule {
    fn validate(&self, value: &str) -> SecurityResult<()> {
        if !self.pattern.is_match(value) {
            return Err(SecurityError::ValidationError(format!(
                "Value does not match required pattern: {}",
                self.description_text
            )));
        }
        Ok(())
    }

    fn name(&self) -> &str {
        "regex"
    }

    fn description(&self) -> &str {
        &self.description_text
    }
}

/// Alphanumeric validation rule
pub struct AlphanumericRule {
    allow_spaces: bool,
}

impl AlphanumericRule {
    pub fn new(allow_spaces: bool) -> Self {
        Self { allow_spaces }
    }
}

impl ValidationRule for AlphanumericRule {
    fn validate(&self, value: &str) -> SecurityResult<()> {
        for c in value.chars() {
            if !c.is_alphanumeric() {
                if self.allow_spaces && c.is_whitespace() {
                    continue;
                }
                return Err(SecurityError::ValidationError(
                    "Value must be alphanumeric".to_string(),
                ));
            }
        }
        Ok(())
    }

    fn name(&self) -> &str {
        "alphanumeric"
    }

    fn description(&self) -> &str {
        if self.allow_spaces {
            "Validates alphanumeric characters with spaces"
        } else {
            "Validates alphanumeric characters"
        }
    }
}

/// Not empty validation rule
pub struct NotEmptyRule;

impl ValidationRule for NotEmptyRule {
    fn validate(&self, value: &str) -> SecurityResult<()> {
        if value.trim().is_empty() {
            return Err(SecurityError::ValidationError(
                "Value cannot be empty".to_string(),
            ));
        }
        Ok(())
    }

    fn name(&self) -> &str {
        "not_empty"
    }

    fn description(&self) -> &str {
        "Validates that value is not empty"
    }
}

/// Custom validation rule from closure
pub struct CustomRule<F>
where
    F: Fn(&str) -> SecurityResult<()> + Send + Sync,
{
    validator: F,
    rule_name: String,
    description_text: String,
}

impl<F> CustomRule<F>
where
    F: Fn(&str) -> SecurityResult<()> + Send + Sync,
{
    pub fn new(validator: F, name: String, description: String) -> Self {
        Self {
            validator,
            rule_name: name,
            description_text: description,
        }
    }
}

impl<F> ValidationRule for CustomRule<F>
where
    F: Fn(&str) -> SecurityResult<()> + Send + Sync,
{
    fn validate(&self, value: &str) -> SecurityResult<()> {
        (self.validator)(value)
    }

    fn name(&self) -> &str {
        &self.rule_name
    }

    fn description(&self) -> &str {
        &self.description_text
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_length_rule() {
        let rule = LengthRule::new(5, 10);

        assert!(rule.validate("hello").is_ok());
        assert!(rule.validate("hello world").is_err()); // Too long
        assert!(rule.validate("hi").is_err()); // Too short
    }

    #[test]
    fn test_regex_rule() {
        let pattern = regex::Regex::new(r"^[a-z]+$").unwrap();
        let rule = RegexRule::new(pattern, "lowercase letters only".to_string());

        assert!(rule.validate("hello").is_ok());
        assert!(rule.validate("Hello").is_err());
        assert!(rule.validate("123").is_err());
    }

    #[test]
    fn test_alphanumeric_rule() {
        let rule = AlphanumericRule::new(false);

        assert!(rule.validate("abc123").is_ok());
        assert!(rule.validate("abc 123").is_err());
        assert!(rule.validate("abc-123").is_err());

        let rule_with_spaces = AlphanumericRule::new(true);
        assert!(rule_with_spaces.validate("abc 123").is_ok());
    }

    #[test]
    fn test_not_empty_rule() {
        let rule = NotEmptyRule;

        assert!(rule.validate("hello").is_ok());
        assert!(rule.validate("").is_err());
        assert!(rule.validate("   ").is_err());
    }

    #[test]
    fn test_validator_multiple_rules() {
        let mut validator = Validator::new();

        validator.add_rule("not_empty".to_string(), Box::new(NotEmptyRule));
        validator.add_rule("length".to_string(), Box::new(LengthRule::new(3, 10)));

        assert!(validator.validate_all("hello").is_ok());
        assert!(validator.validate_all("").is_err());
        assert!(validator.validate_all("this is too long").is_err());
    }

    #[test]
    fn test_validator_specific_rules() {
        let mut validator = Validator::new();

        validator.add_rule("not_empty".to_string(), Box::new(NotEmptyRule));
        validator.add_rule("length".to_string(), Box::new(LengthRule::new(3, 10)));
        validator.add_rule(
            "alphanumeric".to_string(),
            Box::new(AlphanumericRule::new(false)),
        );

        // Validate with specific rules
        assert!(validator
            .validate_with("hello123", &["not_empty", "alphanumeric"])
            .is_ok());

        // Should fail alphanumeric but we're not checking it
        assert!(validator.validate_with("hello!", &["not_empty"]).is_ok());

        // Should fail when we check alphanumeric
        assert!(validator
            .validate_with("hello!", &["not_empty", "alphanumeric"])
            .is_err());
    }

    #[test]
    fn test_custom_rule() {
        let rule = CustomRule::new(
            |value| {
                if value.starts_with("test_") {
                    Ok(())
                } else {
                    Err(SecurityError::ValidationError(
                        "Must start with test_".to_string(),
                    ))
                }
            },
            "starts_with_test".to_string(),
            "Validates that value starts with test_".to_string(),
        );

        assert!(rule.validate("test_value").is_ok());
        assert!(rule.validate("value").is_err());
    }

    #[test]
    fn test_validator_rule_management() {
        let mut validator = Validator::new();

        validator.add_rule("rule1".to_string(), Box::new(NotEmptyRule));
        assert_eq!(validator.get_rule_names().len(), 1);

        validator.add_rule("rule2".to_string(), Box::new(NotEmptyRule));
        assert_eq!(validator.get_rule_names().len(), 2);

        validator.remove_rule("rule1");
        assert_eq!(validator.get_rule_names().len(), 1);
    }

    #[test]
    fn test_nonexistent_rule() {
        let validator = Validator::new();

        let result = validator.validate_with("value", &["nonexistent"]);
        assert!(result.is_err());
    }
}
