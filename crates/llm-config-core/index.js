/**
 * This is a Rust crate published to npm for discoverability.
 * 
 * To use this crate:
 * 1. Install Rust: https://rustup.rs/
 * 2. Add to Cargo.toml: 
 *    [dependencies]
 *    llm-config-core = "0.5.0"
 * 
 * Or install the CLI:
 *    cargo install llm-config-core
 * 
 * For WASM/JavaScript usage, see the browser-compatible packages:
 *    - @llm-dev-ops/llm-config-crypto
 *    - @llm-dev-ops/llm-config-rbac
 *    - @llm-dev-ops/llm-config-security
 *    - @llm-dev-ops/llm-config-templates
 */

module.exports = {
  info: 'This package requires Rust. See package.json for installation instructions.',
  repository: 'https://github.com/globalbusinessadvisors/llm-config-manager'
};
