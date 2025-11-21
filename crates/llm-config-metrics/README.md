# llm-config-metrics

[![Crates.io](https://img.shields.io/crates/v/llm-config-metrics.svg)](https://crates.io/crates/llm-config-metrics)
[![Documentation](https://docs.rs/llm-config-metrics/badge.svg)](https://docs.rs/llm-config-metrics)
[![License](https://img.shields.io/crates/l/llm-config-metrics.svg)](https://github.com/globalbusinessadvisors/llm-config-manager/blob/main/LICENSE)

Prometheus-based metrics collection and export for monitoring configuration access, performance, and usage patterns in LLM Config Manager.

## Features

- **Prometheus Integration**: Native Prometheus metrics export
- **Performance Metrics**: Request latency, throughput, error rates
- **Usage Tracking**: Configuration access patterns and hot keys
- **Custom Metrics**: Define application-specific metrics
- **Histogram Support**: Detailed latency distribution

## Usage

```toml
[dependencies]
llm-config-metrics = "0.5.0"
```

```rust
use llm_config_metrics::MetricsCollector;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let metrics = MetricsCollector::new();

    // Record metric
    metrics.record_request_duration("get_config", 0.045)?;
    metrics.increment_counter("config_access", &["production"])?;

    // Export metrics (Prometheus format)
    let exported = metrics.export()?;
    println!("{}", exported);

    Ok(())
}
```

## Metrics Provided

- `config_requests_total`: Total configuration requests
- `config_request_duration_seconds`: Request latency histogram
- `config_cache_hits_total`: Cache hit counter
- `config_errors_total`: Error counter by type

## License

Licensed under the Apache License, Version 2.0.
