//! Template structure and management

use crate::{parser, Result, TemplateError};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// A configuration template
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Template {
    /// Template name/ID
    pub name: String,

    /// Template description
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,

    /// Template content with variable placeholders
    pub content: String,

    /// Required variables
    pub required_vars: Vec<String>,

    /// Optional variables with default values
    #[serde(default)]
    pub defaults: HashMap<String, String>,
}

impl Template {
    /// Create a new template
    pub fn new(name: impl Into<String>, content: impl Into<String>) -> Result<Self> {
        let name = name.into();
        let content = content.into();

        // Parse to extract variables
        let tokens = parser::parse(&content)?;
        let mut required_vars = Vec::new();

        for token in tokens {
            if let parser::Token::Variable(var) = token {
                if !required_vars.contains(&var) {
                    required_vars.push(var);
                }
            }
        }

        Ok(Self {
            name,
            description: None,
            content,
            required_vars,
            defaults: HashMap::new(),
        })
    }

    /// Set template description
    pub fn with_description(mut self, description: impl Into<String>) -> Self {
        self.description = Some(description.into());
        self
    }

    /// Add a default value for a variable
    pub fn with_default(mut self, var: impl Into<String>, value: impl Into<String>) -> Self {
        self.defaults.insert(var.into(), value.into());
        self
    }

    /// Render the template with the given variables
    pub fn render(&self, vars: &HashMap<String, String>) -> Result<String> {
        let tokens = parser::parse(&self.content)?;
        let mut result = String::new();

        for token in tokens {
            match token {
                parser::Token::Literal(text) => result.push_str(&text),
                parser::Token::Variable(var_name) => {
                    // Check user-provided vars first
                    if let Some(value) = vars.get(&var_name) {
                        result.push_str(value);
                    }
                    // Then check defaults
                    else if let Some(value) = self.defaults.get(&var_name) {
                        result.push_str(value);
                    }
                    // Variable not found
                    else {
                        return Err(TemplateError::VariableNotFound(var_name));
                    }
                }
            }
        }

        Ok(result)
    }

    /// Check if all required variables are provided
    pub fn validate_vars(&self, vars: &HashMap<String, String>) -> Result<()> {
        for var in &self.required_vars {
            if !vars.contains_key(var) && !self.defaults.contains_key(var) {
                return Err(TemplateError::VariableNotFound(var.clone()));
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_template_creation() {
        let template = Template::new("test", "Hello, {{name}}!").unwrap();
        assert_eq!(template.name, "test");
        assert_eq!(template.required_vars, vec!["name"]);
    }

    #[test]
    fn test_template_render() {
        let template = Template::new("greeting", "Hello, {{name}}!").unwrap();
        let mut vars = HashMap::new();
        vars.insert("name".to_string(), "Alice".to_string());

        let result = template.render(&vars).unwrap();
        assert_eq!(result, "Hello, Alice!");
    }

    #[test]
    fn test_template_with_defaults() {
        let template = Template::new("greeting", "Hello, {{name}}!")
            .unwrap()
            .with_default("name", "Guest");

        let vars = HashMap::new();
        let result = template.render(&vars).unwrap();
        assert_eq!(result, "Hello, Guest!");
    }

    #[test]
    fn test_template_override_default() {
        let template = Template::new("greeting", "Hello, {{name}}!")
            .unwrap()
            .with_default("name", "Guest");

        let mut vars = HashMap::new();
        vars.insert("name".to_string(), "Alice".to_string());

        let result = template.render(&vars).unwrap();
        assert_eq!(result, "Hello, Alice!");
    }

    #[test]
    fn test_template_missing_variable() {
        let template = Template::new("greeting", "Hello, {{name}}!").unwrap();
        let vars = HashMap::new();

        let result = template.render(&vars);
        assert!(result.is_err());
    }

    #[test]
    fn test_template_multiple_variables() {
        let template = Template::new("config", "host={{host}}, port={{port}}").unwrap();
        let mut vars = HashMap::new();
        vars.insert("host".to_string(), "localhost".to_string());
        vars.insert("port".to_string(), "8080".to_string());

        let result = template.render(&vars).unwrap();
        assert_eq!(result, "host=localhost, port=8080");
    }

    #[test]
    fn test_template_validation() {
        let template = Template::new("test", "{{var1}} and {{var2}}").unwrap();

        let mut vars = HashMap::new();
        vars.insert("var1".to_string(), "value1".to_string());
        vars.insert("var2".to_string(), "value2".to_string());

        assert!(template.validate_vars(&vars).is_ok());

        let partial_vars = HashMap::new();
        assert!(template.validate_vars(&partial_vars).is_err());
    }

    #[test]
    fn test_template_serialization() {
        let template = Template::new("test", "Hello, {{name}}!")
            .unwrap()
            .with_description("A greeting template")
            .with_default("name", "World");

        let json = serde_json::to_string(&template).unwrap();
        let deserialized: Template = serde_json::from_str(&json).unwrap();

        assert_eq!(template.name, deserialized.name);
        assert_eq!(template.content, deserialized.content);
    }
}
