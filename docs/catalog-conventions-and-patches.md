# Aggrega Catalog Conventions

> This document is the authoritative reference for catalog entity naming,
> directory structure, and YAML formatting. All catalog contributions
> (human or AI-generated) must follow these conventions.

## 1. Directory Structure

URI segments map 1:1 to filesystem path segments. The compiler resolves
`type: core/database/mariadb:1.0.0` to `component/core/database/mariadb.yaml`.

```text
aggrega-catalog/
├── component/{namespace}/{category}/{name}.yaml
├── feature/{namespace}/{name}.yaml
├── recipe/{provider}/{name}/recipe.yaml
├── feature-recipe/{provider}/{name}/recipe.yaml
├── aggregate/{namespace}/{name}/aggregate.yaml
├── cue/core/
└── cue.mod/
```

### Namespace

The first path segment after the entity type. Identifies the vendor/author.

- `core` — official Aggrega standard library (maintained by Cognitio S.r.l.)
- Third-party namespaces: use your organization name (e.g., `acme`, `enterprise`)

### Component Categories

Components use a second path segment for human-navigable categorization:

| Category | Contains | Ontology labels |
| --- | --- | --- |
| `database` | Persistent datastores (relational, vector, document, graph, KV) | stateful-server |
| `model` | AI model providers and inference runtimes | server |
| `agent` | AI agent frameworks and patterns | worker, server |
| `tool` | AI tools invoked by agents | ai-tool |
| `server` | Long-running HTTP/gRPC endpoints, gateways, UIs | server |
| `worker` | Background processors, consumers | worker |
| `messaging` | Event buses, queues, streams | messaging |
| `storage` | Object/file storage, managed cloud resources | resource |
| `compute` | Tasks, functions, serverless | task, function |
| `pipeline` | Data and AI pipelines | ai-pipeline |

Features do NOT use categories (25 files, flat under `feature/core/`).

### Recipe/FeatureRecipe Provider Namespace

Domain 3 entities use the execution engine as the first path segment:
`helm`, `terraform`, `cloudformation`, `compose`, `eval`.

## 2. Naming Conventions

### metadata.name

Must match the filesystem path segments after the entity type directory:

| Entity | Example filesystem path | metadata.name |
| --- | --- | --- |
| Component | `component/core/database/mariadb.yaml` | `core/database/mariadb` |
| Feature | `feature/core/data-masking.yaml` | `core/data-masking` |
| Recipe | `recipe/helm/mariadb-bitnami/recipe.yaml` | `mariadb-bitnami` |
| FeatureRecipe | `feature-recipe/helm/k8s-dns-patcher/recipe.yaml` | `k8s-dns-patcher` |

Recipes and FeatureRecipes do NOT include namespace or provider in their name —
the provider is already the parent directory and `spec.provider` field.

The `ops/` prefix is NOT used. All Recipes are Domain 3 (Ops) by definition.

### Name shortening

When a component's filename would repeat the category, strip the suffix:

- `anthropic-agent.yaml` in `agent/` → `anthropic.yaml` (name: `core/agent/anthropic`)
- `openai-model.yaml` in `model/` → `openai.yaml` (name: `core/model/openai`)

## 3. YAML Formatting

### License header (required on every .yaml file)

```yaml
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Cognitio S.r.l.
```

### Label values: unquoted

```yaml
# CORRECT
labels:
  component.aggrega.ai/type: stateful-server

# WRONG
labels:
  component.aggrega.ai/type: "stateful-server"
```

### Version values: unquoted

```yaml
# CORRECT
version: 1.0.0

# WRONG
version: "1.0.0"
```

### Maintainer block

```yaml
maintainers:
  - name: Massimiliano Ferrero
    email: m.ferrero@cognitio.it
```

### Comment syntax

- YAML context (outside `cueSchema: |`): use `#`
- CUE context (inside `cueSchema: |` blocks): use `//`
- Standalone `.cue` files: use `//`

CUE's parser rejects `#` as a comment character, and YAML's parser rejects `//`. A `cueSchema: |` block is CUE code embedded in a YAML literal scalar — the inner content follows CUE conventions.

## 4. Component Schema Pattern

Every Component cueSchema must document its pillars with section headers:

```yaml
spec:
  cueSchema: |
    // values — Developer Intent
    // Filled by the Developer in the Aggregate.
    values: { ... }

    // infra — Operational Sizing
    // Filled by Ops in the Release. Developer never sees this.
    infra: { ... }

    // provides — Public API Contract
    // Keys exported to consumers via `uses` topology edges.
    provides: { ... }
```

### The `overrides` escape hatch

Stateful components with provider-specific knobs should include:

```cue
infra: {
  // ... universal fields ...

  // Provider-specific overrides. Accepts any nested structure.
  // Each Recipe documents which keys it reads.
  overrides?: _
}
```

### The `source_version` field

Components backed by versioned upstream artifacts (Helm charts, Terraform modules)
should include:

```cue
infra: {
  // Overrides the Recipe's default source artifact version.
  // Changing from default does not guarantee value mapping compatibility.
  source_version?: string
}
```

## 5. Recipe Pattern

Every Recipe valuesMapping should document which `infra.overrides` keys it reads
in a header comment block inside the spec:

```yaml
spec:
  # This Recipe reads from infra.overrides:
  #   nodeSelector    - map[string]string
  #   tolerations     - []object
  #   service_type    - string
  #   metrics         - { enabled: bool, image: { repository: string } }
  valuesMapping: |
    ...
```

### Managed-service credentials

For Recipes targeting cloud-managed services (AWS RDS, Azure Database, GCP
Cloud SQL, etc.), prefer the provider's native managed-secret flag over an
Aggrega credential FeatureRecipe. Terraform Recipes for RDS set
`manage_master_user_password = true` so RDS auto-manages the password via AWS
Secrets Manager; CloudFormation Recipes set `ManageMasterUserPassword: true`
for the same effect. The cloud provider already owns the password lifecycle,
and introducing an Aggrega credential FeatureRecipe alongside duplicates that
lifecycle and adds synchronization risk.

The canonical examples are
[`recipe/terraform/mariadb-rds/recipe.yaml`](../aggrega-catalog/recipe/terraform/mariadb-rds/recipe.yaml)
and
[`recipe/cloudformation/mariadb-rds/recipe.yaml`](../aggrega-catalog/recipe/cloudformation/mariadb-rds/recipe.yaml).
This guidance applies to managed services only — Recipes targeting
self-managed datastores (Helm Bitnami chart, Compose container) still use the
credential FeatureRecipe path because no upstream managed-secret flag exists
for those targets.

## 6. OCI Registry

The canonical registry is `hub.aggrega.ai`. OCI URIs mirror the filesystem:

- `hub.aggrega.ai/component/core/database/mariadb:1.0.0`
- `hub.aggrega.ai/recipe/helm/mariadb-bitnami:1.0.0`
- `hub.aggrega.ai/feature-recipe/helm/k8s-secret-from-parameter:1.0.0`
