# 2. PSEUDOCODE

**LLM-Config-Manager - Technical Implementation Planner**
**SPARC Phase:** Pseudocode
**Version:** 1.0.0
**Date:** 2025-11-21

---

## Table of Contents

1. [Core Operations Pseudocode](#21-core-operations-pseudocode)
2. [API Design](#22-api-design)
3. [CLI Interface](#23-cli-interface)
4. [Integration Flows](#24-integration-flows)

---

## 2.1 Core Operations Pseudocode

### 2.1.1 Configuration Storage and Retrieval

#### Store Configuration

```rust
// Pseudocode for storing a configuration entry
function store_configuration(namespace: String, key: String, value: ConfigValue, metadata: ConfigMetadata) -> Result<ConfigId, Error> {
    // 1. Validate inputs
    validate_namespace(namespace)?;
    validate_key(key)?;
    validate_value_schema(value, metadata.schema_version)?;

    // 2. Check authorization
    actor = get_current_actor();
    if !policy_engine.authorize(actor, namespace, Action::Write) {
        return Error::Unauthorized("Write permission denied");
    }

    // 3. Prepare configuration object
    config = Configuration {
        id: generate_uuid(),
        namespace: namespace,
        key: key,
        value: value,
        value_type: infer_type(value),
        encrypted: false,
        encryption_key_id: None,
        schema_version: metadata.schema_version,
        metadata: metadata,
        tags: metadata.tags,
        created_at: now_utc(),
        updated_at: now_utc(),
        created_by: actor.id,
        updated_by: actor.id,
    };

    // 4. Check if configuration contains secrets
    if contains_secret_markers(value) {
        config.encrypted = true;
        config.encryption_key_id = Some(get_or_create_encryption_key(namespace));
        config.value = encrypt_secrets(value, config.encryption_key_id)?;
    }

    // 5. Begin transaction
    transaction = storage.begin_transaction();

    try {
        // 6. Store configuration in primary storage
        vault_adapter.write(
            path: format!("configs/{}/{}", namespace, key),
            data: serialize_config(config)
        )?;

        // 7. Store metadata in database
        db.execute(
            "INSERT INTO configurations (id, namespace, key, value_type, encrypted, encryption_key_id, created_at, created_by)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8)",
            [config.id, config.namespace, config.key, config.value_type, config.encrypted, config.encryption_key_id, config.created_at, config.created_by]
        )?;

        // 8. Create version entry
        version = ConfigVersion {
            id: generate_uuid(),
            config_id: config.id,
            version_number: 1,
            value: config.value,
            change_type: ChangeType::Create,
            changed_by: actor.id,
            changed_at: now_utc(),
            change_reason: metadata.commit_message,
            diff: None,
            git_commit: None,
            rollback_to: None,
        };

        db.execute(
            "INSERT INTO config_versions (id, config_id, version_number, value, change_type, changed_by, changed_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7)",
            [version.id, version.config_id, version.version_number, version.value, version.change_type, version.changed_by, version.changed_at]
        )?;

        // 9. Invalidate cache
        cache_manager.invalidate(namespace, key);

        // 10. Publish cache invalidation event
        redis_pubsub.publish(
            channel: "cache_invalidation",
            message: json({
                "namespace": namespace,
                "key": key,
                "timestamp": now_utc()
            })
        );

        // 11. Log audit event (async)
        audit_logger.log_async(AuditEvent {
            event_type: AuditEventType::ConfigWrite,
            actor: actor,
            resource: Resource::Config(namespace, key),
            action: "create",
            result: Result::Success,
            timestamp: now_utc(),
            metadata: {"config_id": config.id}
        });

        // 12. Notify governance dashboard (async)
        governance_notifier.notify_async(ConfigChangeEvent {
            event: "config.created",
            config_id: config.id,
            namespace: namespace,
            key: key,
            timestamp: now_utc()
        });

        // 13. Commit transaction
        transaction.commit();

        return Ok(config.id);

    } catch (error) {
        // Rollback transaction on error
        transaction.rollback();

        // Log error
        audit_logger.log_async(AuditEvent {
            event_type: AuditEventType::ConfigWrite,
            actor: actor,
            resource: Resource::Config(namespace, key),
            action: "create",
            result: Result::Failure,
            timestamp: now_utc(),
            metadata: {"error": error.to_string()}
        });

        return Err(error);
    }
}
```

#### Retrieve Configuration

```rust
// Pseudocode for retrieving a configuration entry
function retrieve_configuration(namespace: String, key: String, environment: Option<String>) -> Result<ConfigValue, Error> {
    // 1. Validate inputs
    validate_namespace(namespace)?;
    validate_key(key)?;

    // 2. Check authorization
    actor = get_current_actor();
    if !policy_engine.authorize(actor, namespace, Action::Read) {
        return Error::Unauthorized("Read permission denied");
    }

    // 3. Construct cache key
    cache_key = if environment.is_some() {
        format!("{}/{}@{}", namespace, key, environment.unwrap())
    } else {
        format!("{}/{}", namespace, key)
    };

    // 4. Check L1 cache (in-memory)
    if let Some(cached_value) = l1_cache.get(cache_key) {
        // Cache hit - return immediately
        audit_logger.log_async(AuditEvent {
            event_type: AuditEventType::ConfigRead,
            actor: actor,
            resource: Resource::Config(namespace, key),
            action: "read",
            result: Result::Success,
            metadata: {"cache_layer": "L1"}
        });

        return Ok(cached_value);
    }

    // 5. Check L2 cache (Redis)
    if let Some(cached_value) = redis_cache.get(cache_key) {
        // Cache hit - populate L1 and return
        l1_cache.set(cache_key, cached_value.clone(), ttl: Duration::minutes(5));

        audit_logger.log_async(AuditEvent {
            event_type: AuditEventType::ConfigRead,
            actor: actor,
            resource: Resource::Config(namespace, key),
            action: "read",
            result: Result::Success,
            metadata: {"cache_layer": "L2"}
        });

        return Ok(cached_value);
    }

    // 6. Cache miss - fetch from vault
    vault_path = format!("configs/{}/{}", namespace, key);

    // Apply environment override if specified
    if environment.is_some() {
        env_path = format!("configs/{}/{}@{}", namespace, key, environment.unwrap());

        // Try environment-specific config first
        if let Some(env_config) = vault_adapter.read(env_path)? {
            value = deserialize_config(env_config).value;
        } else {
            // Fall back to base config
            base_config = vault_adapter.read(vault_path)?
                .ok_or(Error::NotFound("Configuration not found"))?;
            value = deserialize_config(base_config).value;
        }
    } else {
        base_config = vault_adapter.read(vault_path)?
            .ok_or(Error::NotFound("Configuration not found"))?;
        value = deserialize_config(base_config).value;
    }

    // 7. Decrypt if encrypted
    config_metadata = db.query_one(
        "SELECT encrypted, encryption_key_id FROM configurations WHERE namespace = $1 AND key = $2",
        [namespace, key]
    )?;

    if config_metadata.encrypted {
        value = decrypt_secrets(value, config_metadata.encryption_key_id)?;
    }

    // 8. Validate schema
    validate_value_schema(value, config_metadata.schema_version)?;

    // 9. Populate caches
    l2_cache.set(cache_key, value.clone(), ttl: Duration::minutes(15));
    l1_cache.set(cache_key, value.clone(), ttl: Duration::minutes(5));

    // 10. Log audit event (async)
    audit_logger.log_async(AuditEvent {
        event_type: AuditEventType::ConfigRead,
        actor: actor,
        resource: Resource::Config(namespace, key),
        action: "read",
        result: Result::Success,
        metadata: {"cache_layer": "vault"}
    });

    return Ok(value);
}
```

---

### 2.1.2 Secret Encryption and Decryption

#### Encrypt Secret Value

```rust
// Pseudocode for encrypting a secret value
function encrypt_secret(plaintext: Vec<u8>, key_id: String) -> Result<EncryptedValue, Error> {
    // 1. Get or generate data encryption key (DEK)
    dek = get_data_encryption_key(key_id)?;

    // 2. Generate random nonce (96 bits for AES-GCM)
    nonce = generate_random_bytes(12);

    // 3. Encrypt using AES-256-GCM
    algorithm = Algorithm::AES256GCM;

    // Create AEAD cipher
    cipher = create_aes_gcm_cipher(dek);

    // Encrypt plaintext
    ciphertext = cipher.encrypt(nonce, plaintext)?;

    // 4. Envelope encryption (encrypt DEK with KMS)
    kms_provider = get_kms_provider(key_id);
    kek_id = get_key_encryption_key_id(key_id);

    encrypted_dek = kms_provider.encrypt(
        key_id: kek_id,
        plaintext: dek
    )?;

    envelope = EnvelopeData {
        encrypted_dek: encrypted_dek,
        kek_id: kek_id,
        kms_provider: kms_provider.name(),
    };

    // 5. Construct encrypted value object
    encrypted_value = EncryptedValue {
        ciphertext: ciphertext,
        nonce: nonce,
        algorithm: algorithm,
        key_id: key_id,
        envelope: Some(envelope),
    };

    // 6. Zero out sensitive data
    zero_memory(dek);
    zero_memory(plaintext);

    return Ok(encrypted_value);
}
```

#### Decrypt Secret Value

```rust
// Pseudocode for decrypting a secret value
function decrypt_secret(encrypted_value: EncryptedValue) -> Result<Vec<u8>, Error> {
    // 1. Decrypt DEK using KMS
    envelope = encrypted_value.envelope
        .ok_or(Error::MissingEnvelope("Envelope data missing"))?;

    kms_provider = get_kms_provider_by_name(envelope.kms_provider);

    dek = kms_provider.decrypt(
        key_id: envelope.kek_id,
        ciphertext: envelope.encrypted_dek
    )?;

    // 2. Decrypt ciphertext using DEK
    match encrypted_value.algorithm {
        Algorithm::AES256GCM => {
            cipher = create_aes_gcm_cipher(dek);
            plaintext = cipher.decrypt(encrypted_value.nonce, encrypted_value.ciphertext)?;
        },
        Algorithm::ChaCha20Poly1305 => {
            cipher = create_chacha20_cipher(dek);
            plaintext = cipher.decrypt(encrypted_value.nonce, encrypted_value.ciphertext)?;
        },
        _ => return Err(Error::UnsupportedAlgorithm),
    }

    // 3. Zero out DEK
    zero_memory(dek);

    return Ok(plaintext);
}
```

---

### 2.1.3 Version Management

#### Create Version Snapshot

```rust
// Pseudocode for creating a configuration version snapshot
function create_version_snapshot(config_id: Uuid, new_value: ConfigValue, change_reason: Option<String>) -> Result<u64, Error> {
    // 1. Get current version number
    current_version = db.query_one(
        "SELECT MAX(version_number) FROM config_versions WHERE config_id = $1",
        [config_id]
    )?.unwrap_or(0);

    next_version = current_version + 1;

    // 2. Get previous version for diff
    if current_version > 0 {
        prev_version = db.query_one(
            "SELECT value FROM config_versions WHERE config_id = $1 AND version_number = $2",
            [config_id, current_version]
        )?;

        // Compute JSON patch diff
        diff = compute_json_patch(prev_version.value, new_value);
    } else {
        diff = None;
    }

    // 3. Create version entry
    actor = get_current_actor();

    version = ConfigVersion {
        id: generate_uuid(),
        config_id: config_id,
        version_number: next_version,
        value: new_value.clone(),
        change_type: ChangeType::Update,
        changed_by: actor.id,
        changed_at: now_utc(),
        change_reason: change_reason,
        diff: diff,
        git_commit: get_current_git_commit(),
        rollback_to: None,
    };

    // 4. Insert version
    db.execute(
        "INSERT INTO config_versions (id, config_id, version_number, value, change_type, changed_by, changed_at, change_reason, diff, git_commit)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)",
        [version.id, version.config_id, version.version_number, version.value, version.change_type, version.changed_by, version.changed_at, version.change_reason, version.diff, version.git_commit]
    )?;

    // 5. Update current configuration
    db.execute(
        "UPDATE configurations SET value = $1, updated_at = $2, updated_by = $3 WHERE id = $4",
        [new_value, now_utc(), actor.id, config_id]
    )?;

    // 6. Prune old versions (keep last 100)
    retention_limit = 100;
    if next_version > retention_limit {
        db.execute(
            "DELETE FROM config_versions WHERE config_id = $1 AND version_number < $2",
            [config_id, next_version - retention_limit]
        )?;
    }

    return Ok(next_version);
}
```

#### Rollback to Version

```rust
// Pseudocode for rolling back configuration to a previous version
function rollback_to_version(config_id: Uuid, target_version: u64) -> Result<(), Error> {
    // 1. Validate target version exists
    version_data = db.query_one(
        "SELECT value FROM config_versions WHERE config_id = $1 AND version_number = $2",
        [config_id, target_version]
    )?;

    if version_data.is_none() {
        return Err(Error::NotFound("Target version not found"));
    }

    // 2. Check authorization
    actor = get_current_actor();
    config = db.query_one(
        "SELECT namespace, key FROM configurations WHERE id = $1",
        [config_id]
    )?;

    if !policy_engine.authorize(actor, config.namespace, Action::Write) {
        return Err(Error::Unauthorized("Rollback permission denied"));
    }

    // 3. Get target value
    target_value = version_data.unwrap().value;

    // 4. Create rollback version entry
    current_version = db.query_one(
        "SELECT MAX(version_number) FROM config_versions WHERE config_id = $1",
        [config_id]
    )?.unwrap();

    rollback_version = ConfigVersion {
        id: generate_uuid(),
        config_id: config_id,
        version_number: current_version + 1,
        value: target_value.clone(),
        change_type: ChangeType::Restore,
        changed_by: actor.id,
        changed_at: now_utc(),
        change_reason: Some(format!("Rollback to version {}", target_version)),
        diff: compute_json_patch(get_current_value(config_id), target_value),
        git_commit: get_current_git_commit(),
        rollback_to: Some(target_version),
    };

    // 5. Begin transaction
    transaction = storage.begin_transaction();

    try {
        // Insert rollback version
        db.execute(
            "INSERT INTO config_versions (id, config_id, version_number, value, change_type, changed_by, changed_at, change_reason, diff, rollback_to)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)",
            [rollback_version.id, rollback_version.config_id, rollback_version.version_number, rollback_version.value, rollback_version.change_type, rollback_version.changed_by, rollback_version.changed_at, rollback_version.change_reason, rollback_version.diff, rollback_version.rollback_to]
        )?;

        // Update vault
        vault_adapter.write(
            path: format!("configs/{}/{}", config.namespace, config.key),
            data: serialize_config_value(target_value)
        )?;

        // Update current configuration
        db.execute(
            "UPDATE configurations SET value = $1, updated_at = $2, updated_by = $3 WHERE id = $4",
            [target_value, now_utc(), actor.id, config_id]
        )?;

        // Invalidate cache
        cache_manager.invalidate(config.namespace, config.key);

        // Commit transaction
        transaction.commit();

        // Log audit event
        audit_logger.log_async(AuditEvent {
            event_type: AuditEventType::ConfigWrite,
            actor: actor,
            resource: Resource::Config(config.namespace, config.key),
            action: "rollback",
            result: Result::Success,
            metadata: {
                "target_version": target_version,
                "new_version": rollback_version.version_number
            }
        });

        return Ok(());

    } catch (error) {
        transaction.rollback();
        return Err(error);
    }
}
```

---

### 2.1.4 Dynamic Configuration Reload

```rust
// Pseudocode for dynamic configuration reload without service restart
function dynamic_reload_config(namespace: String, key: String) -> Result<(), Error> {
    // 1. Fetch latest configuration
    latest_config = retrieve_configuration(namespace, key, None)?;

    // 2. Validate new configuration
    validation_result = validate_config_for_live_reload(latest_config)?;

    if !validation_result.safe_to_reload {
        return Err(Error::UnsafeReload(validation_result.reason));
    }

    // 3. Get registered reload handlers
    handlers = reload_registry.get_handlers(namespace, key);

    if handlers.is_empty() {
        return Err(Error::NoHandlers("No reload handlers registered"));
    }

    // 4. Execute pre-reload hooks
    for handler in handlers {
        if let Some(pre_hook) = handler.pre_reload_hook {
            pre_hook(latest_config.clone())?;
        }
    }

    // 5. Apply configuration atomically
    reload_result = apply_config_atomically(latest_config.clone(), handlers);

    match reload_result {
        Ok(()) => {
            // 6. Execute post-reload hooks
            for handler in handlers {
                if let Some(post_hook) = handler.post_reload_hook {
                    post_hook(latest_config.clone())?;
                }
            }

            // 7. Notify subscribers via webhook
            notify_config_reloaded(namespace, key, latest_config);

            // 8. Log successful reload
            audit_logger.log_async(AuditEvent {
                event_type: AuditEventType::ConfigWrite,
                actor: Actor::System,
                resource: Resource::Config(namespace, key),
                action: "dynamic_reload",
                result: Result::Success,
                metadata: {}
            });

            return Ok(());
        },
        Err(error) => {
            // 9. Rollback on failure
            rollback_to_previous_config(namespace, key)?;

            // 10. Log failed reload
            audit_logger.log_async(AuditEvent {
                event_type: AuditEventType::ConfigWrite,
                actor: Actor::System,
                resource: Resource::Config(namespace, key),
                action: "dynamic_reload",
                result: Result::Failure,
                metadata: {"error": error.to_string()}
            });

            return Err(Error::ReloadFailed(error));
        }
    }
}

// Apply configuration atomically with rollback capability
function apply_config_atomically(new_config: ConfigValue, handlers: Vec<ReloadHandler>) -> Result<(), Error> {
    // Create checkpoint of current state
    checkpoint = create_state_checkpoint(handlers);

    try {
        // Apply new configuration to all handlers
        for handler in handlers {
            handler.apply(new_config.clone())?;
        }

        // Validate post-apply state
        for handler in handlers {
            if let Some(validator) = handler.post_apply_validator {
                validator()?;
            }
        }

        return Ok(());

    } catch (error) {
        // Rollback to checkpoint
        restore_state_checkpoint(checkpoint, handlers);
        return Err(error);
    }
}
```

---

### 2.1.5 Multi-Module Synchronization

```rust
// Pseudocode for synchronizing configuration across multiple modules
function synchronize_config_multi_module(namespace: String, key: String, target_modules: Vec<String>) -> Result<SyncReport, Error> {
    // 1. Fetch source configuration
    source_config = retrieve_configuration(namespace, key, None)?;

    // 2. Initialize sync report
    sync_report = SyncReport {
        namespace: namespace.clone(),
        key: key.clone(),
        started_at: now_utc(),
        target_modules: target_modules.clone(),
        successes: vec![],
        failures: vec![],
    };

    // 3. Parallel sync to target modules
    sync_tasks = vec![];

    for module in target_modules {
        // Create async task for each module
        task = spawn_async(move || {
            sync_to_module(module, namespace.clone(), key.clone(), source_config.clone())
        });

        sync_tasks.push((module, task));
    }

    // 4. Await all sync tasks with timeout
    timeout = Duration::seconds(30);

    for (module, task) in sync_tasks {
        result = task.await_timeout(timeout);

        match result {
            Ok(Ok(())) => {
                sync_report.successes.push(module);
            },
            Ok(Err(error)) | Err(timeout_error) => {
                sync_report.failures.push((module, error.to_string()));
            }
        }
    }

    // 5. Finalize report
    sync_report.completed_at = now_utc();
    sync_report.success_count = sync_report.successes.len();
    sync_report.failure_count = sync_report.failures.len();

    // 6. Log sync report
    audit_logger.log_async(AuditEvent {
        event_type: AuditEventType::ConfigWrite,
        actor: Actor::System,
        resource: Resource::Config(namespace, key),
        action: "multi_module_sync",
        result: if sync_report.failure_count == 0 { Result::Success } else { Result::PartialFailure },
        metadata: {"sync_report": serialize_json(sync_report)}
    });

    return Ok(sync_report);
}

// Sync configuration to a single module
function sync_to_module(module_name: String, namespace: String, key: String, config: ConfigValue) -> Result<(), Error> {
    // 1. Get module endpoint
    module_endpoint = service_registry.get_endpoint(module_name)?;

    // 2. Create gRPC client
    client = create_grpc_client(module_endpoint);

    // 3. Call module's config update RPC
    request = ConfigUpdateRequest {
        namespace: namespace,
        key: key,
        value: config,
        source: "config-manager",
        timestamp: now_utc(),
    };

    response = client.update_config(request).await?;

    // 4. Verify success
    if response.status != "success" {
        return Err(Error::ModuleSyncFailed(response.error_message));
    }

    return Ok(());
}
```

---

### 2.1.6 RBAC Enforcement

```rust
// Pseudocode for role-based access control enforcement
function enforce_rbac(actor: Actor, resource: Resource, action: Action) -> Result<(), Error> {
    // 1. Extract resource components
    (namespace, resource_type, resource_id) = parse_resource(resource);

    // 2. Get actor's roles for namespace
    roles = db.query_all(
        "SELECT r.* FROM roles r
         JOIN role_bindings rb ON r.id = rb.role_id
         WHERE rb.subject_type = $1 AND rb.subject_id = $2 AND rb.namespace = $3
         AND (rb.expires_at IS NULL OR rb.expires_at > $4)",
        [actor.subject_type, actor.id, namespace, now_utc()]
    )?;

    // 3. Collect all permissions (including inherited roles)
    permissions = vec![];

    for role in roles {
        // Add direct permissions
        permissions.extend(role.permissions);

        // Add inherited permissions
        if !role.inherits_from.is_empty() {
            inherited_permissions = get_inherited_permissions(role.inherits_from)?;
            permissions.extend(inherited_permissions);
        }
    }

    // 4. Evaluate permissions
    decision = evaluate_permissions(permissions, resource, action)?;

    // 5. Log authorization decision
    audit_logger.log_async(AuditEvent {
        event_type: if decision == Decision::Allow {
            AuditEventType::AuthorizationSuccess
        } else {
            AuditEventType::AuthorizationFailure
        },
        actor: actor.clone(),
        resource: resource.clone(),
        action: action.to_string(),
        result: if decision == Decision::Allow { Result::Success } else { Result::Denied },
        metadata: {
            "decision": decision.to_string(),
            "evaluated_permissions": permissions.len()
        }
    });

    // 6. Return decision
    match decision {
        Decision::Allow => Ok(()),
        Decision::Deny => Err(Error::Forbidden("Access denied by RBAC policy")),
        Decision::Conditional(conditions) => {
            // Evaluate runtime conditions
            if evaluate_conditions(conditions, actor, resource)? {
                Ok(())
            } else {
                Err(Error::Forbidden("Conditional access denied"))
            }
        }
    }
}

// Evaluate permissions against resource and action
function evaluate_permissions(permissions: Vec<Permission>, resource: Resource, action: Action) -> Result<Decision, Error> {
    // 1. Separate allow and deny permissions
    allows = permissions.filter(|p| p.effect == Effect::Allow);
    denies = permissions.filter(|p| p.effect == Effect::Deny);

    // 2. Deny takes precedence (fail-safe)
    for deny in denies {
        if matches_permission(deny, resource, action) {
            return Ok(Decision::Deny);
        }
    }

    // 3. Check for explicit allow
    for allow in allows {
        if matches_permission(allow, resource, action) {
            // Check conditions if present
            if allow.conditions.is_some() {
                return Ok(Decision::Conditional(allow.conditions.unwrap()));
            } else {
                return Ok(Decision::Allow);
            }
        }
    }

    // 4. Default deny
    return Ok(Decision::Deny);
}

// Check if permission matches resource and action
function matches_permission(permission: Permission, resource: Resource, action: Action) -> bool {
    // 1. Match resource pattern (supports wildcards)
    resource_str = format!("{}:{}:{}", resource.namespace, resource.resource_type, resource.resource_id);

    if !glob_match(permission.resource, resource_str) {
        return false;
    }

    // 2. Match action
    if !permission.actions.contains(action) && !permission.actions.contains(Action::Admin) {
        return false;
    }

    return true;
}
```

---

## 2.2 API Design

### 2.2.1 REST API Endpoints

#### Configuration CRUD

```
BASE_URL: https://config-manager.example.com/api/v1
```

##### Create Configuration

```
POST /configs/{namespace}/{key}
Headers:
  Authorization: Bearer <jwt_token>
  Content-Type: application/json

Request Body:
{
  "value": <any JSON value>,
  "schema_version": "v1",
  "metadata": {
    "description": "Configuration description",
    "owner": "team-name",
    "tags": {
      "environment": "production",
      "service": "ml-inference"
    },
    "commit_message": "Add new config for feature X"
  }
}

Response: 201 Created
{
  "config_id": "550e8400-e29b-41d4-a716-446655440000",
  "namespace": "production/ml-service",
  "key": "inference.timeout",
  "version": 1,
  "created_at": "2025-11-21T10:00:00Z",
  "created_by": "user@example.com"
}

Errors:
  400 Bad Request - Invalid input
  401 Unauthorized - Missing or invalid token
  403 Forbidden - Insufficient permissions
  409 Conflict - Configuration already exists
  422 Unprocessable Entity - Schema validation failed
  500 Internal Server Error - Server error
```

##### Read Configuration

```
GET /configs/{namespace}/{key}?environment=<env>&version=<version>
Headers:
  Authorization: Bearer <jwt_token>

Query Parameters:
  environment (optional): Environment override (dev, staging, prod)
  version (optional): Specific version number (default: latest)

Response: 200 OK
{
  "config_id": "550e8400-e29b-41d4-a716-446655440000",
  "namespace": "production/ml-service",
  "key": "inference.timeout",
  "value": {
    "read_timeout_ms": 5000,
    "write_timeout_ms": 10000
  },
  "value_type": "object",
  "version": 3,
  "schema_version": "v1",
  "metadata": {...},
  "created_at": "2025-11-21T10:00:00Z",
  "updated_at": "2025-11-21T14:30:00Z"
}

Errors:
  401 Unauthorized
  403 Forbidden
  404 Not Found - Configuration not found
  500 Internal Server Error
```

##### Update Configuration

```
PUT /configs/{namespace}/{key}
Headers:
  Authorization: Bearer <jwt_token>
  Content-Type: application/json

Request Body:
{
  "value": <new JSON value>,
  "change_reason": "Increase timeout for large models",
  "validate_before_apply": true
}

Response: 200 OK
{
  "config_id": "550e8400-e29b-41d4-a716-446655440000",
  "version": 4,
  "updated_at": "2025-11-21T15:00:00Z",
  "updated_by": "user@example.com",
  "validation_result": {
    "valid": true,
    "warnings": []
  }
}

Errors:
  400 Bad Request
  401 Unauthorized
  403 Forbidden
  404 Not Found
  422 Unprocessable Entity - Validation failed
  500 Internal Server Error
```

##### Delete Configuration

```
DELETE /configs/{namespace}/{key}?soft_delete=<bool>
Headers:
  Authorization: Bearer <jwt_token>

Query Parameters:
  soft_delete (optional): If true, mark as deleted but retain history (default: true)

Response: 204 No Content

Errors:
  401 Unauthorized
  403 Forbidden
  404 Not Found
  500 Internal Server Error
```

##### List Configurations

```
GET /configs/{namespace}?environment=<env>&tags=<tag_filter>&limit=<limit>&offset=<offset>
Headers:
  Authorization: Bearer <jwt_token>

Query Parameters:
  environment (optional): Filter by environment
  tags (optional): Filter by tags (comma-separated key:value pairs)
  limit (optional): Page size (default: 50, max: 500)
  offset (optional): Pagination offset (default: 0)

Response: 200 OK
{
  "configs": [
    {
      "config_id": "...",
      "namespace": "production/ml-service",
      "key": "inference.timeout",
      "value_type": "object",
      "version": 3,
      "updated_at": "2025-11-21T15:00:00Z"
    },
    ...
  ],
  "pagination": {
    "total": 142,
    "limit": 50,
    "offset": 0,
    "has_more": true
  }
}
```

#### Version History

```
GET /configs/{namespace}/{key}/versions?limit=<limit>&offset=<offset>
Headers:
  Authorization: Bearer <jwt_token>

Response: 200 OK
{
  "versions": [
    {
      "version_number": 4,
      "value": {...},
      "change_type": "update",
      "changed_by": "user@example.com",
      "changed_at": "2025-11-21T15:00:00Z",
      "change_reason": "Increase timeout",
      "diff": {...}
    },
    {
      "version_number": 3,
      "value": {...},
      "change_type": "update",
      "changed_by": "user2@example.com",
      "changed_at": "2025-11-21T14:30:00Z",
      "change_reason": null
    },
    ...
  ],
  "pagination": {...}
}
```

#### Configuration Validation

```
POST /configs/{namespace}/validate
Headers:
  Authorization: Bearer <jwt_token>
  Content-Type: application/json

Request Body:
{
  "key": "inference.timeout",
  "value": {...},
  "schema_version": "v1"
}

Response: 200 OK
{
  "valid": true,
  "schema_version": "v1",
  "warnings": [],
  "errors": []
}

or

Response: 422 Unprocessable Entity
{
  "valid": false,
  "schema_version": "v1",
  "warnings": [],
  "errors": [
    {
      "field": "read_timeout_ms",
      "message": "Must be a positive integer",
      "code": "type_error"
    }
  ]
}
```

#### Bulk Operations

```
POST /configs/bulk
Headers:
  Authorization: Bearer <jwt_token>
  Content-Type: application/json

Request Body:
{
  "operations": [
    {
      "operation": "create",
      "namespace": "prod/service-a",
      "key": "config1",
      "value": {...}
    },
    {
      "operation": "update",
      "namespace": "prod/service-b",
      "key": "config2",
      "value": {...}
    },
    {
      "operation": "delete",
      "namespace": "prod/service-c",
      "key": "config3"
    }
  ],
  "atomic": true,
  "dry_run": false
}

Response: 200 OK
{
  "results": [
    {
      "operation": "create",
      "namespace": "prod/service-a",
      "key": "config1",
      "status": "success",
      "config_id": "..."
    },
    {
      "operation": "update",
      "namespace": "prod/service-b",
      "key": "config2",
      "status": "success",
      "version": 5
    },
    {
      "operation": "delete",
      "namespace": "prod/service-c",
      "key": "config3",
      "status": "failed",
      "error": "Not found"
    }
  ],
  "summary": {
    "total": 3,
    "succeeded": 2,
    "failed": 1
  }
}
```

---

### 2.2.2 gRPC API Service Definitions

```protobuf
syntax = "proto3";

package llm.config.v1;

// Configuration Service
service ConfigService {
  rpc GetConfig(GetConfigRequest) returns (GetConfigResponse);
  rpc CreateConfig(CreateConfigRequest) returns (CreateConfigResponse);
  rpc UpdateConfig(UpdateConfigRequest) returns (UpdateConfigResponse);
  rpc DeleteConfig(DeleteConfigRequest) returns (DeleteConfigResponse);
  rpc ListConfigs(ListConfigsRequest) returns (ListConfigsResponse);
  rpc WatchConfigs(WatchConfigsRequest) returns (stream ConfigChangeEvent);
  rpc ValidateConfig(ValidateConfigRequest) returns (ValidateConfigResponse);
  rpc GetVersionHistory(GetVersionHistoryRequest) returns (GetVersionHistoryResponse);
  rpc RollbackConfig(RollbackConfigRequest) returns (RollbackConfigResponse);
}

// Messages
message GetConfigRequest {
  string namespace = 1;
  string key = 2;
  optional string environment = 3;
  optional uint64 version = 4;
}

message GetConfigResponse {
  string config_id = 1;
  string namespace = 2;
  string key = 3;
  google.protobuf.Value value = 4;
  string value_type = 5;
  uint64 version = 6;
  ConfigMetadata metadata = 7;
  google.protobuf.Timestamp created_at = 8;
  google.protobuf.Timestamp updated_at = 9;
}

message CreateConfigRequest {
  string namespace = 1;
  string key = 2;
  google.protobuf.Value value = 3;
  ConfigMetadata metadata = 4;
}

message CreateConfigResponse {
  string config_id = 1;
  uint64 version = 2;
  google.protobuf.Timestamp created_at = 3;
}

message UpdateConfigRequest {
  string namespace = 1;
  string key = 2;
  google.protobuf.Value value = 3;
  optional string change_reason = 4;
  bool validate_before_apply = 5;
}

message UpdateConfigResponse {
  string config_id = 1;
  uint64 version = 2;
  google.protobuf.Timestamp updated_at = 3;
  ValidationResult validation_result = 4;
}

message DeleteConfigRequest {
  string namespace = 1;
  string key = 2;
  bool soft_delete = 3;
}

message DeleteConfigResponse {
  bool success = 1;
}

message ListConfigsRequest {
  string namespace = 1;
  optional string environment = 2;
  map<string, string> tag_filter = 3;
  uint32 limit = 4;
  uint32 offset = 5;
}

message ListConfigsResponse {
  repeated ConfigSummary configs = 1;
  Pagination pagination = 2;
}

message WatchConfigsRequest {
  string namespace = 1;
  repeated string keys = 2;  // Empty means watch all
}

message ConfigChangeEvent {
  string event_type = 1;  // "created", "updated", "deleted"
  string config_id = 2;
  string namespace = 3;
  string key = 4;
  google.protobuf.Value new_value = 5;
  google.protobuf.Value old_value = 6;
  uint64 version = 7;
  google.protobuf.Timestamp timestamp = 8;
}

message ValidateConfigRequest {
  string namespace = 1;
  string key = 2;
  google.protobuf.Value value = 3;
  string schema_version = 4;
}

message ValidationResult {
  bool valid = 1;
  repeated string warnings = 2;
  repeated ValidationError errors = 3;
}

message ValidationError {
  string field = 1;
  string message = 2;
  string code = 3;
}

message GetVersionHistoryRequest {
  string namespace = 1;
  string key = 2;
  uint32 limit = 3;
  uint32 offset = 4;
}

message GetVersionHistoryResponse {
  repeated ConfigVersion versions = 1;
  Pagination pagination = 2;
}

message ConfigVersion {
  uint64 version_number = 1;
  google.protobuf.Value value = 2;
  string change_type = 3;
  string changed_by = 4;
  google.protobuf.Timestamp changed_at = 5;
  optional string change_reason = 6;
  optional string diff = 7;
}

message RollbackConfigRequest {
  string namespace = 1;
  string key = 2;
  uint64 target_version = 3;
  string reason = 4;
}

message RollbackConfigResponse {
  uint64 new_version = 1;
  google.protobuf.Timestamp rolled_back_at = 2;
}

// Supporting messages
message ConfigMetadata {
  string description = 1;
  string owner = 2;
  map<string, string> tags = 3;
  string schema_version = 4;
}

message ConfigSummary {
  string config_id = 1;
  string namespace = 2;
  string key = 3;
  string value_type = 4;
  uint64 version = 5;
  google.protobuf.Timestamp updated_at = 6;
}

message Pagination {
  uint64 total = 1;
  uint32 limit = 2;
  uint32 offset = 3;
  bool has_more = 4;
}
```

---

### 2.2.3 Authentication Flow

#### JWT Token-Based Authentication

```
1. Client obtains JWT token from identity provider (OAuth2/OIDC)
2. Client includes token in Authorization header: "Bearer <token>"
3. Config-Manager validates token:
   a. Verify signature using public key (RS256/ES256)
   b. Check expiration (exp claim)
   c. Validate issuer (iss claim)
   d. Validate audience (aud claim)
   e. Extract subject (sub claim) for actor identification
4. If valid, extract claims for authorization
5. If invalid, return 401 Unauthorized

Token Claims:
{
  "sub": "user@example.com",
  "iss": "https://auth.example.com",
  "aud": "config-manager",
  "exp": 1732186200,
  "iat": 1732182600,
  "roles": ["developer", "operator"],
  "tenant_id": "acme-corp"
}
```

#### mTLS Authentication (Service-to-Service)

```
1. Client initiates TLS handshake with client certificate
2. Config-Manager validates client certificate:
   a. Verify certificate chain against trusted CA
   b. Check certificate validity (not expired)
   c. Check certificate revocation status (OCSP/CRL)
   d. Extract subject DN for actor identification
3. If valid, extract identity from certificate subject
4. If invalid, reject connection

Certificate Subject Format:
CN=ml-inference-service.production.example.com
O=ACME Corp
OU=ML Platform
```

#### API Key Authentication (Legacy Clients)

```
1. Client includes API key in header: "X-API-Key: <key>"
2. Config-Manager looks up API key:
   a. Hash API key using SHA-256
   b. Query database for matching hash
   c. Check key expiration
   d. Check key permissions
3. If valid, extract actor from key metadata
4. If invalid, return 401 Unauthorized

API Key Metadata:
{
  "key_id": "ak_550e8400e29b41d4a716",
  "name": "CI/CD Pipeline Key",
  "actor_id": "service-account-123",
  "permissions": ["read:configs:*"],
  "created_at": "2025-11-01T00:00:00Z",
  "expires_at": "2026-11-01T00:00:00Z",
  "last_used_at": "2025-11-21T10:00:00Z"
}
```

---

## 2.3 CLI Interface

### 2.3.1 Command Structure

```
llm-config [GLOBAL_OPTIONS] <COMMAND> [COMMAND_OPTIONS] [ARGS]

GLOBAL OPTIONS:
  --profile <profile>      Configuration profile (default: default)
  --vault-addr <url>       Vault server address
  --vault-token <token>    Vault authentication token
  --format <format>        Output format: json, yaml, table (default: table)
  --verbose, -v            Verbose output
  --quiet, -q              Quiet mode (errors only)
  --no-color               Disable colored output

COMMANDS:
  get          Get configuration value
  set          Set configuration value
  delete       Delete configuration
  list         List configurations
  validate     Validate configuration
  versions     View version history
  rollback     Rollback to previous version
  sync         Sync configuration to modules
  watch        Watch for configuration changes
  export       Export configurations
  import       Import configurations
  auth         Authentication commands
  vault        Vault management commands
```

### 2.3.2 Command Examples

#### Get Configuration

```bash
# Basic get
llm-config get production/ml-service/inference.timeout

# Get with environment override
llm-config get production/ml-service/inference.timeout --env staging

# Get specific version
llm-config get production/ml-service/inference.timeout --version 3

# Get with JSON output
llm-config get production/ml-service/inference.timeout --format json

# Get nested value using JSONPath
llm-config get production/ml-service/inference.timeout --query '.read_timeout_ms'

Output (table format):
╭─────────────────────────────────────────────────────────╮
│ Configuration: production/ml-service/inference.timeout  │
├─────────────────────────────────────────────────────────┤
│ Value:                                                  │
│   read_timeout_ms: 5000                                 │
│   write_timeout_ms: 10000                               │
│                                                         │
│ Version: 3                                              │
│ Updated: 2025-11-21 15:00:00 UTC                        │
│ Updated by: user@example.com                            │
╰─────────────────────────────────────────────────────────╯
```

#### Set Configuration

```bash
# Set simple value
llm-config set production/ml-service/max_workers 16

# Set complex value from JSON
llm-config set production/ml-service/inference.timeout \
  '{"read_timeout_ms": 5000, "write_timeout_ms": 10000}'

# Set from file
llm-config set production/ml-service/model_config --file config.json

# Set with metadata
llm-config set production/ml-service/api_key "secret_value" \
  --secret \
  --description "Production API key" \
  --tags environment=production,service=ml

# Interactive editor
llm-config set production/ml-service/complex_config --edit

Output:
✓ Configuration updated successfully
  Namespace: production/ml-service
  Key: inference.timeout
  Version: 4 (previous: 3)
  Updated at: 2025-11-21 16:00:00 UTC
```

#### Delete Configuration

```bash
# Soft delete (retains history)
llm-config delete production/ml-service/old_config

# Hard delete (permanent)
llm-config delete production/ml-service/old_config --hard

# Delete with confirmation
llm-config delete production/ml-service/critical_config --confirm

Output:
⚠ Are you sure you want to delete 'production/ml-service/critical_config'? [y/N]: y
✓ Configuration deleted successfully
  Version history retained: yes
```

#### List Configurations

```bash
# List all in namespace
llm-config list production/ml-service

# List with filters
llm-config list production/ml-service --tags environment=production

# List with pagination
llm-config list production/ml-service --limit 20 --offset 40

# List all namespaces
llm-config list --all

Output (table format):
╭─────────────────────────────────────────────────────────────────────────────╮
│ Configurations in production/ml-service (showing 3 of 12)                  │
├───────────────────────────┬──────────────┬─────────┬─────────────────────────┤
│ Key                       │ Type         │ Version │ Updated                 │
├───────────────────────────┼──────────────┼─────────┼─────────────────────────┤
│ inference.timeout         │ object       │ 4       │ 2025-11-21 16:00:00     │
│ max_workers              │ number       │ 2       │ 2025-11-20 10:30:00     │
│ model_config             │ object       │ 1       │ 2025-11-19 14:15:00     │
╰───────────────────────────┴──────────────┴─────────┴─────────────────────────╯
```

#### Validate Configuration

```bash
# Validate before applying
llm-config validate production/ml-service/inference.timeout \
  --file new_config.json

# Validate with schema
llm-config validate production/ml-service/inference.timeout \
  --file new_config.json \
  --schema schema.json

Output:
✓ Validation successful
  Schema version: v1
  Warnings: 0
  Errors: 0

or

✗ Validation failed
  Schema version: v1
  Warnings: 1
  - Field 'write_timeout_ms' is deprecated, use 'write_timeout' instead

  Errors: 1
  - Field 'read_timeout_ms': Must be a positive integer, got string
```

#### Version History

```bash
# View version history
llm-config versions production/ml-service/inference.timeout

# View with diffs
llm-config versions production/ml-service/inference.timeout --show-diffs

# View specific version
llm-config versions production/ml-service/inference.timeout --version 3

Output:
╭─────────────────────────────────────────────────────────────────────────────╮
│ Version History: production/ml-service/inference.timeout                   │
├─────────┬──────────────────────────┬─────────────────────┬──────────────────┤
│ Version │ Changed By               │ Changed At          │ Change Type      │
├─────────┼──────────────────────────┼─────────────────────┼──────────────────┤
│ 4       │ user@example.com         │ 2025-11-21 16:00:00 │ Update           │
│         │ Reason: Increase timeout for large models                         │
│ 3       │ user2@example.com        │ 2025-11-21 14:30:00 │ Update           │
│ 2       │ system                   │ 2025-11-20 10:00:00 │ Restore (v1)     │
│ 1       │ admin@example.com        │ 2025-11-19 09:00:00 │ Create           │
╰─────────┴──────────────────────────┴─────────────────────┴──────────────────╯
```

#### Rollback Configuration

```bash
# Rollback to version 2
llm-config rollback production/ml-service/inference.timeout --version 2

# Rollback with reason
llm-config rollback production/ml-service/inference.timeout \
  --version 2 \
  --reason "Revert changes due to performance issues"

Output:
✓ Configuration rolled back successfully
  Namespace: production/ml-service
  Key: inference.timeout
  Rolled back to version: 2
  New version: 5
  Rolled back at: 2025-11-21 17:00:00 UTC
```

#### Sync Configuration

```bash
# Sync to specific modules
llm-config sync production/ml-service/inference.timeout \
  --modules ml-inference,ml-training

# Sync all configs in namespace
llm-config sync production/ml-service --all

# Dry run
llm-config sync production/ml-service --all --dry-run

Output:
Syncing configuration to 2 modules...
✓ ml-inference: success (47ms)
✗ ml-training: failed - connection timeout

Summary:
  Total: 2
  Succeeded: 1
  Failed: 1
```

#### Watch Configuration Changes

```bash
# Watch single config
llm-config watch production/ml-service/inference.timeout

# Watch namespace
llm-config watch production/ml-service --all

# Watch with filters
llm-config watch production/ml-service --tags environment=production

Output:
Watching production/ml-service/inference.timeout for changes...
Press Ctrl+C to stop.

[2025-11-21 17:30:15] UPDATE
  Version: 5 → 6
  Changed by: user@example.com
  Diff:
    - read_timeout_ms: 5000
    + read_timeout_ms: 6000
```

#### Export Configurations

```bash
# Export to JSON
llm-config export production/ml-service --output configs.json

# Export to YAML
llm-config export production/ml-service --format yaml --output configs.yaml

# Export with secrets (encrypted)
llm-config export production/ml-service \
  --include-secrets \
  --encrypt-output \
  --output configs.json.enc

# Export to environment variables format
llm-config export production/ml-service --format env --output .env

Output:
Exporting 12 configurations...
✓ Exported to configs.json
  Format: JSON
  Size: 4.2 KB
  Includes secrets: no
```

#### Import Configurations

```bash
# Import from JSON
llm-config import --file configs.json

# Import with merge strategy
llm-config import --file configs.json --merge-strategy overwrite

# Import with validation
llm-config import --file configs.json --validate

# Dry run
llm-config import --file configs.json --dry-run

Output:
Importing configurations from configs.json...
Validating... ✓

Operations to perform:
  Create: 5
  Update: 7
  Skip: 0

Proceed with import? [Y/n]: y

Importing...
✓ production/ml-service/config1: created
✓ production/ml-service/config2: updated (v3 → v4)
...

Summary:
  Total: 12
  Created: 5
  Updated: 7
  Failed: 0
```

---

## 2.4 Integration Flows

### 2.4.1 LLM-Policy-Engine Integration Flow

```
┌─────────────────┐                               ┌──────────────────┐
│ Config-Manager  │                               │  Policy-Engine   │
└────────┬────────┘                               └────────┬─────────┘
         │                                                 │
         │  1. Authorize Write Request                    │
         │─────────────────────────────────────────────────▶
         │     EvaluatePermission(actor, resource, write) │
         │                                                 │
         │  2. Authorization Decision                     │
         │◀─────────────────────────────────────────────────
         │     Decision: ALLOW / DENY                     │
         │                                                 │
         │  3. Validate Configuration                     │
         │─────────────────────────────────────────────────▶
         │     ValidateConfiguration(config, policies)    │
         │                                                 │
         │  4. Validation Result                          │
         │◀─────────────────────────────────────────────────
         │     ValidationResult(valid, warnings, errors)  │
         │                                                 │
         │  5. Write Configuration to Vault               │
         │  (internal operation)                          │
         │                                                 │
         │  6. Notify Policy Change (if applicable)       │
         │◀─────────────────────────────────────────────────
         │     OnPolicyChange(policy_id)                  │
         │                                                 │
         │  7. Invalidate Policy Cache                    │
         │  (internal operation)                          │
         │                                                 │

Pseudocode:

function integrate_policy_validation(config: Configuration, actor: Actor) -> Result<(), Error> {
    // Step 1: Check authorization
    decision = policy_engine_client.evaluate_permission(
        actor: actor,
        resource: format!("configs:{}/{}", config.namespace, config.key),
        action: Action::Write
    )?;

    if decision != Decision::Allow {
        return Err(Error::Forbidden("Policy denied write access"));
    }

    // Step 2: Validate configuration against policies
    validation_result = policy_engine_client.validate_configuration(
        config: serialize_config(config),
        policies: get_applicable_policies(config.namespace)
    )?;

    if !validation_result.valid {
        return Err(Error::PolicyViolation(validation_result.errors));
    }

    // Log warnings if any
    if !validation_result.warnings.is_empty() {
        log_warnings(validation_result.warnings);
    }

    return Ok(());
}
```

### 2.4.2 LLM-Governance-Dashboard Integration Flow

```
┌─────────────────┐                               ┌──────────────────────┐
│ Config-Manager  │                               │ Governance-Dashboard │
└────────┬────────┘                               └────────┬─────────────┘
         │                                                 │
         │  1. WebSocket Connection                       │
         │◀────────────────────────────────────────────────
         │     Connect to /ws/config-events               │
         │                                                 │
         │  2. Subscribe to Events                        │
         │◀────────────────────────────────────────────────
         │     Subscribe(namespace: "production/*")       │
         │                                                 │
         │  [Configuration Change Occurs]                 │
         │                                                 │
         │  3. Stream Change Event                        │
         │─────────────────────────────────────────────────▶
         │     ConfigChangeEvent{...}                     │
         │                                                 │
         │  4. Dashboard Query Audit Logs                 │
         │◀────────────────────────────────────────────────
         │     GET /api/v1/audit-logs?...                 │
         │                                                 │
         │  5. Return Audit Logs                          │
         │─────────────────────────────────────────────────▶
         │     AuditLogResponse{logs: [...]}              │
         │                                                 │
         │  6. Push Metrics (async)                       │
         │─────────────────────────────────────────────────▶
         │     POST /api/v1/metrics                       │
         │     MetricsPayload{...}                        │
         │                                                 │

Pseudocode:

function integrate_governance_dashboard() {
    // Initialize WebSocket server
    ws_server = WebSocketServer::new("/ws/config-events");

    // Handle client connections
    ws_server.on_connect(|client| {
        // Add client to subscribers
        subscribers.add(client);

        // Send initial state
        send_initial_state(client);
    });

    // Handle subscriptions
    ws_server.on_message(|client, message| {
        match message {
            Subscribe(filter) => {
                client.set_filter(filter);
            },
            Unsubscribe => {
                subscribers.remove(client);
            }
        }
    });

    // Publish events to subscribers
    event_bus.subscribe("config.*", |event| {
        filtered_clients = subscribers.filter_by_event(event);

        for client in filtered_clients {
            ws_send(client, serialize_event(event));
        }
    });

    // Periodic metrics push
    scheduler.schedule_interval(Duration::seconds(30), || {
        metrics = collect_metrics();

        http_client.post(
            url: "http://governance-dashboard/api/v1/metrics",
            body: serialize_json(metrics)
        );
    });
}
```

### 2.4.3 LLM-Observatory Integration Flow

```
┌─────────────────┐                               ┌─────────────────┐
│ Config-Manager  │                               │  Observatory    │
└────────┬────────┘                               └────────┬────────┘
         │                                                 │
         │  1. Prometheus Scrape Request                  │
         │◀────────────────────────────────────────────────
         │     GET /metrics                               │
         │                                                 │
         │  2. Return Metrics                             │
         │─────────────────────────────────────────────────▶
         │     Prometheus Text Format                     │
         │                                                 │
         │  [Trace Span Created]                          │
         │                                                 │
         │  3. Push Trace Span                            │
         │─────────────────────────────────────────────────▶
         │     OTLP/gRPC: ExportTraceServiceRequest       │
         │                                                 │
         │  4. Acknowledgment                             │
         │◀────────────────────────────────────────────────
         │     ExportTraceServiceResponse                 │
         │                                                 │
         │  [Log Entry Generated]                         │
         │                                                 │
         │  5. Push Log Entry (stdout)                    │
         │─────────────────────────────────────────────────▶
         │     JSON Log Line                              │
         │                                                 │

Pseudocode:

function integrate_observatory() {
    // Initialize Prometheus exporter
    prometheus_exporter = PrometheusExporter::new();

    // Register metrics
    prometheus_exporter.register_counter(
        name: "config_operations_total",
        help: "Total configuration operations",
        labels: ["operation", "namespace", "status"]
    );

    prometheus_exporter.register_histogram(
        name: "config_operation_duration_seconds",
        help: "Configuration operation duration",
        labels: ["operation", "namespace"],
        buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0]
    );

    // Expose metrics endpoint
    http_server.route(
        path: "/metrics",
        handler: |_req| {
            metrics_text = prometheus_exporter.export_text();
            Response::ok(metrics_text, content_type: "text/plain")
        }
    );

    // Initialize OpenTelemetry tracer
    tracer = opentelemetry::tracer("config-manager");

    // Create spans for operations
    function trace_operation<F>(operation_name: String, func: F) -> Result<T, Error> {
        span = tracer.start_span(operation_name);

        result = func();

        match result {
            Ok(value) => {
                span.set_attribute("status", "success");
                span.end();
                Ok(value)
            },
            Err(error) => {
                span.set_attribute("status", "error");
                span.set_attribute("error.message", error.to_string());
                span.end();
                Err(error)
            }
        }
    }

    // Push traces via OTLP
    tracer.set_exporter(
        OtlpExporter::new("http://observatory:4317")
    );

    // Structured JSON logging to stdout
    logger = StructuredLogger::new(
        format: LogFormat::JSON,
        level: LogLevel::INFO,
        output: stdout
    );
}
```

### 2.4.4 Secret Rotation Workflow

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────┐    ┌──────────────┐
│ Config-Manager  │    │  Scheduler   │    │    Vault    │    │  Dependent   │
│                 │    │              │    │             │    │  Services    │
└────────┬────────┘    └──────┬───────┘    └──────┬──────┘    └──────┬───────┘
         │                    │                   │                  │
         │  1. Schedule Check │                   │                  │
         │◀────────────────────                   │                  │
         │     Check for expiring secrets         │                  │
         │                                        │                  │
         │  2. Query Expiring Secrets             │                  │
         │─────────────────────────────────────────▶                  │
         │     List secrets with rotation_policy  │                  │
         │                                        │                  │
         │  3. Return Expiring Secrets            │                  │
         │◀─────────────────────────────────────────                  │
         │     [secret1, secret2, ...]            │                  │
         │                                        │                  │
         │  4. Generate New Secret                │                  │
         │  (internal operation)                  │                  │
         │                                        │                  │
         │  5. Write New Secret to Vault          │                  │
         │─────────────────────────────────────────▶                  │
         │     PUT /secret/new_version            │                  │
         │                                        │                  │
         │  6. Acknowledge Write                  │                  │
         │◀─────────────────────────────────────────                  │
         │                                        │                  │
         │  7. Update Metadata                    │                  │
         │  (set next_rotation, last_rotated)     │                  │
         │                                        │                  │
         │  8. Notify Dependent Services          │                  │
         │──────────────────────────────────────────────────────────────▶
         │     SecretRotationEvent{old_version, new_version, grace_period}
         │                                        │                  │
         │  9. Invalidate Cache                   │                  │
         │  (internal operation)                  │                  │
         │                                        │                  │
         │ 10. Log Rotation Event                 │                  │
         │  (audit log)                           │                  │
         │                                        │                  │
         │ [Grace Period Expires]                 │                  │
         │                                        │                  │
         │ 11. Invalidate Old Secret              │                  │
         │─────────────────────────────────────────▶                  │
         │     DELETE /secret/old_version         │                  │
         │                                        │                  │

Pseudocode:

function execute_secret_rotation_workflow() {
    // Scheduled job runs every hour
    scheduler.schedule_interval(Duration::hours(1), || {
        // 1. Query secrets needing rotation
        expiring_secrets = db.query_all(
            "SELECT * FROM secrets
             WHERE rotation_policy_enabled = true
             AND next_rotation <= $1",
            [now_utc() + Duration::days(1)]  // Rotate 1 day before expiry
        )?;

        for secret in expiring_secrets {
            // 2. Execute rotation
            rotate_secret_async(secret);
        }
    });
}

function rotate_secret_async(secret: Secret) {
    spawn_async(move || {
        // 1. Generate new secret value
        new_secret_value = match secret.secret_type {
            SecretType::ApiKey => generate_api_key(),
            SecretType::DatabaseCredentials => rotate_db_credentials(secret),
            SecretType::Certificate => renew_certificate(secret),
            _ => return Err(Error::UnsupportedSecretType),
        };

        // 2. Encrypt new secret
        encrypted_new = encrypt_secret(new_secret_value, secret.encryption_key_id)?;

        // 3. Write to Vault with new version
        vault_adapter.write(
            path: format!("secrets/{}/{}@v{}", secret.namespace, secret.key, get_next_version(secret)),
            data: serialize_encrypted_value(encrypted_new)
        )?;

        // 4. Update metadata
        db.execute(
            "UPDATE secrets
             SET last_rotated = $1, next_rotation = $2, version = version + 1
             WHERE id = $3",
            [now_utc(), now_utc() + secret.rotation_policy.interval, secret.id]
        )?;

        // 5. Invalidate cache
        cache_manager.invalidate(secret.namespace, secret.key);

        // 6. Notify dependent services
        dependent_services = get_dependent_services(secret);

        for service in dependent_services {
            notify_service_of_rotation(
                service,
                SecretRotationEvent {
                    secret_id: secret.id,
                    namespace: secret.namespace,
                    key: secret.key,
                    old_version: secret.version,
                    new_version: secret.version + 1,
                    grace_period: secret.rotation_policy.grace_period,
                    rotated_at: now_utc(),
                }
            );
        }

        // 7. Schedule old secret invalidation after grace period
        scheduler.schedule_once(secret.rotation_policy.grace_period, move || {
            vault_adapter.delete(
                path: format!("secrets/{}/{}@v{}", secret.namespace, secret.key, secret.version)
            );
        });

        // 8. Log rotation event
        audit_logger.log(AuditEvent {
            event_type: AuditEventType::SecretRotation,
            actor: Actor::System,
            resource: Resource::Secret(secret.namespace, secret.key),
            action: "rotate",
            result: Result::Success,
            metadata: {
                "old_version": secret.version,
                "new_version": secret.version + 1,
                "next_rotation": now_utc() + secret.rotation_policy.interval
            }
        });
    });
}
```

---

**End of Pseudocode Section**

This pseudocode section provides detailed, implementation-ready algorithms for all core operations of the LLM-Config-Manager system. The pseudocode uses Rust-style conventions and is designed to be directly translatable to actual Rust code during the implementation phase.
