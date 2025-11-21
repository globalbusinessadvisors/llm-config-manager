# Performance Benchmarks

This document describes the performance benchmarks for the LLM Config Manager platform and how to run and interpret them.

## Overview

The platform includes comprehensive performance benchmarks using [Criterion.rs](https://github.com/bheisler/criterion.rs), which provides:

- **Statistical rigor**: Multiple iterations with variance analysis
- **Regression detection**: Automatic detection of performance regressions
- **HTML reports**: Beautiful, interactive reports with charts
- **Comparison**: Compare performance across code changes

## Available Benchmarks

### Core Configuration Benchmarks (`llm-config-core`)

Tests the performance of core configuration operations:

- **`config_set`**: Measures throughput of setting configurations (10, 100, 1000 items)
- **`config_get`**: Single configuration retrieval performance
- **`config_get_with_overrides`**: Environment override resolution performance
- **`config_list`**: List all configurations in a namespace (10, 100, 1000 items)
- **`secret_operations`**: Secret encryption/decryption performance
  - `set_secret`: Storing encrypted secrets
  - `get_secret`: Retrieving and decrypting secrets
- **`versioning`**: Version control operations
  - `get_history`: Retrieving version history
  - `rollback`: Rolling back to previous versions

### Cache Benchmarks (`llm-config-cache`)

Tests the multi-tier caching system performance:

- **`cache_put`**: Write performance for L1+L2 caches (10, 100, 1000 items)
- **`cache_get_l1_hit`**: L1 cache hit latency (fastest path)
- **`cache_get_l2_hit`**: L2 cache hit with promotion to L1
- **`cache_invalidate`**: Cache invalidation throughput (10, 100, 1000 items)
- **`cache_mixed_ops`**: Realistic workload (70% reads, 20% writes, 10% invalidations)
- **`cache_promotion_l2_to_l1`**: L2 to L1 promotion performance

### Cryptography Benchmarks (`llm-config-crypto`)

Tests cryptographic operation performance with AES-256-GCM:

- **`key_generation`**: Secret key generation speed
- **`encryption`**: Encryption throughput at various payload sizes (16B - 16KB)
- **`decryption`**: Decryption throughput at various payload sizes
- **`encrypt_decrypt_roundtrip`**: Full round-trip performance (256B, 1KB, 4KB)
- **`encryption_with_aad`**: Additional Authenticated Data (AAD) overhead
- **`concurrent_encryption`**: Sequential encryption workload

### RBAC Benchmarks (`llm-config-rbac`)

Tests Role-Based Access Control performance:

- **`role_assignment`**: User role assignment throughput (10, 100, 1000 users)
- **`permission_check`**: Permission validation latency
  - Admin can delete
  - Editor can update
  - Viewer can read
  - Viewer cannot update (denial path)
- **`namespace_permission_check`**: Scoped permission checks
- **`mixed_permission_checks`**: Realistic mixed workload (100 checks)
- **`role_revocation`**: Role removal throughput (10, 100, 1000 users)
- **`get_user_roles`**: User role lookup performance

## Running Benchmarks

### Quick Start with Cargo Aliases

Run all benchmarks:
```bash
cargo bench-all
```

Run specific benchmark suites:
```bash
cargo bench-core      # Core configuration operations
cargo bench-cache     # Cache performance
cargo bench-crypto    # Cryptographic operations
cargo bench-rbac      # RBAC permission checks
```

### Using Cargo Directly

Run all benchmarks:
```bash
cargo bench --workspace
```

Run benchmarks for a specific crate:
```bash
cargo bench --package llm-config-core
cargo bench --package llm-config-cache
cargo bench --package llm-config-crypto
cargo bench --package llm-config-rbac
```

Run a specific benchmark:
```bash
cargo bench --package llm-config-core --bench core_benchmarks
```

Run a specific benchmark function:
```bash
cargo bench --package llm-config-cache -- cache_get_l1_hit
```

### Baseline Comparisons

Save a baseline for comparison:
```bash
cargo bench -- --save-baseline before-optimization
```

Compare against a baseline:
```bash
# Make your changes, then run:
cargo bench -- --baseline before-optimization
```

## Viewing Results

### HTML Reports

After running benchmarks, open the HTML report:
```bash
open target/criterion/report/index.html
# or on Linux:
xdg-open target/criterion/report/index.html
```

The reports include:
- Throughput measurements
- Latency percentiles
- Statistical analysis
- Performance trends
- Comparison charts

### Console Output

Criterion prints summary statistics to the console:
```
config_set/10          time:   [45.231 µs 45.987 µs 46.812 µs]
                       thrpt:  [213.65 Kelem/s 217.45 Kelem/s 221.07 Kelem/s]
```

## Performance Targets

### Production Performance Goals

Based on enterprise requirements, the platform should achieve:

#### Core Operations (per operation)
- **Set config**: < 100µs (10,000+ ops/sec)
- **Get config**: < 50µs (20,000+ ops/sec)
- **Get with overrides**: < 75µs (13,000+ ops/sec)
- **List configs (100 items)**: < 500µs

#### Cache Operations
- **L1 cache hit**: < 10µs (100,000+ ops/sec)
- **L2 cache hit**: < 50µs (20,000+ ops/sec)
- **Cache put**: < 100µs

#### Cryptographic Operations
- **Secret encryption (1KB)**: < 20µs (50,000+ ops/sec)
- **Secret decryption (1KB)**: < 20µs (50,000+ ops/sec)
- **Key generation**: < 1ms

#### RBAC Operations
- **Permission check**: < 10µs (100,000+ ops/sec)
- **Role assignment**: < 50µs (20,000+ ops/sec)

## Optimization Guidelines

### Identifying Bottlenecks

1. **Run benchmarks** with baseline:
   ```bash
   cargo bench -- --save-baseline main
   ```

2. **Make changes** and re-run:
   ```bash
   cargo bench -- --baseline main
   ```

3. **Review changes**: Criterion highlights performance changes (improvements in green, regressions in red)

### Common Optimization Strategies

1. **Caching**
   - Use L1 cache for hot paths
   - Monitor cache hit rates
   - Tune cache sizes based on benchmarks

2. **Allocation**
   - Reduce allocations in hot paths
   - Use object pooling for frequent operations
   - Pre-allocate collections when size is known

3. **Concurrency**
   - Minimize lock contention
   - Use lock-free structures where possible
   - Benchmark concurrent access patterns

4. **Serialization**
   - Use binary formats (bincode) over JSON for internal storage
   - Cache serialized forms
   - Lazy deserialization where possible

5. **Cryptography**
   - Batch encrypt/decrypt operations
   - Use hardware acceleration (AES-NI)
   - Consider async crypto for large payloads

## Continuous Integration

### Benchmark in CI

Add to your CI pipeline to detect regressions:

```yaml
benchmark:
  script:
    - cargo bench --no-run  # Compile benchmarks
    - cargo bench -- --test  # Quick benchmark run for CI
```

### Performance Regression Testing

For critical changes:
1. Run full benchmarks on baseline
2. Apply changes
3. Run benchmarks again
4. Review Criterion's change detection

## Interpreting Results

### Understanding Criterion Output

```
bench_cache_get_l1_hit  time:   [8.2143 µs 8.3251 µs 8.4512 µs]
                        change: [-2.3451% -0.5123% +1.2341%] (p = 0.23 > 0.05)
```

- **time**: Lower, mean, upper bounds of execution time
- **change**: Performance change vs. previous run (if baseline exists)
- **p-value**: Statistical significance (< 0.05 indicates significant change)

### Throughput vs Latency

- **Latency**: Time per operation (lower is better)
- **Throughput**: Operations per second (higher is better)
- Both are important for different use cases

### Variance and Outliers

- Check violin plots in HTML reports
- High variance indicates inconsistent performance
- Outliers may indicate GC pauses or system interference

## Best Practices

1. **Consistent Environment**
   - Run on dedicated hardware
   - Disable CPU frequency scaling
   - Close other applications

2. **Warm-up**
   - Criterion automatically warms up
   - First run may be slower (compilation, caching)

3. **Sample Size**
   - Criterion uses adaptive sampling
   - Longer benchmarks = more accurate results
   - Use `--sample-size` for custom control

4. **Measurement Period**
   - Default: 5 seconds per benchmark
   - Adjust with `--measurement-time` for faster/slower benchmarks

5. **Profiling**
   - Use `cargo flamegraph` for flame graphs
   - Use `perf` on Linux for detailed profiling
   - Benchmark first, profile second

## Advanced Usage

### Comparing Algorithms

```rust
group.bench_function("algorithm_a", |b| {
    b.iter(|| algorithm_a(black_box(&data)))
});

group.bench_function("algorithm_b", |b| {
    b.iter(|| algorithm_b(black_box(&data)))
});
```

### Throughput Benchmarks

```rust
group.throughput(Throughput::Elements(size as u64));
group.bench_with_input(BenchmarkId::from_parameter(size), &size, |b, &size| {
    b.iter(|| process_batch(size))
});
```

### Custom Measurement

```rust
b.iter_custom(|iters| {
    let start = Instant::now();
    for _ in 0..iters {
        custom_operation();
    }
    start.elapsed()
});
```

## Troubleshooting

### Benchmarks Taking Too Long

Reduce sample size:
```bash
cargo bench -- --sample-size 10
```

Or measurement time:
```bash
cargo bench -- --measurement-time 1
```

### Unstable Results

- Run on idle system
- Disable power management
- Increase sample size
- Check for background processes

### Compilation Errors

Ensure all dependencies are up to date:
```bash
cargo update
cargo bench --no-run
```

## References

- [Criterion.rs Documentation](https://bheisler.github.io/criterion.rs/book/)
- [Rust Performance Book](https://nnethercote.github.io/perf-book/)
- [Benchmarking Best Practices](https://easyperf.net/blog/)

## Contributing

When adding new benchmarks:

1. Place benchmarks in appropriate crate's `benches/` directory
2. Use descriptive benchmark names
3. Test various input sizes
4. Document performance expectations
5. Update this document with new benchmarks
