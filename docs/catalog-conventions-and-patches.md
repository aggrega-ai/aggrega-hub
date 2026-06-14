# Aggrega Catalog Conventions

> This document is the authoritative reference for catalog entity naming,
> directory structure, and YAML formatting. All catalog contributions
> (human or AI-generated) must follow these conventions.

## 1. Directory Structure

URI segments map 1:1 to filesystem path segments. The compiler resolves
`type: core/datastore/mariadb:1.0.0` to `component/core/datastore/mariadb.yaml`.

```text
aggrega-catalog/
├── component/{namespace}/{category}/{name}.yaml
├── feature/{namespace}/{name}.yaml
├── recipe/{provider}/{name}/recipe.yaml
├── feature-recipe/{provider}/{name}/recipe.yaml
├── aggregate/{namespace}/{name}/aggregate.yaml
├── schemalibrary/{name}.yaml
└── mappinglibrary/{name}.yaml
```

`schemalibrary/` carries reusable JSON Schema 2020-12 fragments other Components and Features reference via `$ref:`. `mappinglibrary/` carries reusable Go template fragments Recipes and FeatureRecipes consume via `valuesMapping: { $import: ... }`. See the "Shared schema and mapping reuse" section below.

### Namespace

The first path segment after the entity type. Identifies the vendor/author.

- `core` — official Aggrega standard library (maintained by Cognitio S.r.l.)
- Third-party namespaces: use your organization name (e.g., `acme`, `enterprise`)

### Component Categories

A Component's second path segment is its cognitive category — the same
word as its `component.aggrega.ai/category` label (the 1:1 mirror; see
the label section below). The 15 categories:

| Category | Contains | Typical ontology labels | On disk |
| --- | --- | --- | --- |
| `ai-agent` | AI agent frameworks, platforms, and patterns | worker, server, resource | populated |
| `ai-model` | Model providers and inference runtimes | server, resource | populated |
| `ai-tool` | Tools agents invoke | function, server, resource | populated |
| `ai-pipeline` | AI data/processing pipelines | worker, task | populated |
| `datastore` | Persistent datastores (relational, vector, document, graph, KV) | stateful-server, resource | populated |
| `gateway` | API and AI gateways | server | populated |
| `mesh` | Service meshes | server | created when the first entity lands |
| `network` | Network primitives | server, resource | created when the first entity lands |
| `messaging` | Event buses, queues, streams | messaging | populated |
| `storage` | Object/file storage, managed cloud resources | resource | populated |
| `compute` | Generic compute primitives (server, worker, task, function bases) | server, worker, task, function | populated |
| `observability` | Telemetry, tracing, monitoring | varies | created when the first entity lands |
| `security` | Security and compliance components | varies | created when the first entity lands |
| `bigdata` | Large-scale data processing | varies | created when the first entity lands |
| `devtool` | Developer tooling | varies | created when the first entity lands |

Directory-presence discipline:

- **The first segment is the category — mandatory and lint-enforced.** The
  publishing linter's `category-matches-directory` rule checks the 1:1
  mirror (warning at `aggrega lint`, error at pre-publish). This is a
  standard-library convention (class C) with a per-workspace opt-out for
  enterprise layouts; the compiler itself never checks it.
- **Unpopulated categories have no on-disk placeholder.** Git does not
  track empty directories and the catalog carries no placeholder files;
  a category directory is created when its first entity lands. The
  closed set above — not the filesystem — is the category authority.
- **Sub-grouping below the top level is free.** `datastore/relational/…`
  is permitted filesystem tidiness as a category grows; the category
  label never reflects sub-segments.
- **Enterprise Exception.** Third-party namespaces may organize their
  trees however they choose; the conventions bind the `core/` standard
  library, and the linter rule is opt-out per workspace.

Features do NOT use categories (flat under `feature/core/`).

### The `component.aggrega.ai/category` label

Every Component under `core/` carries `component.aggrega.ai/category`, the
cognitive browse axis of the catalog's three-axis label scheme:

- **Axis 1 — operational `type`** (`component.aggrega.ai/type`): one of the
  7 cloud-native primitives. Describes how infrastructure treats the
  component (state, ingress, lifecycle). Never carries cognitive vocabulary.
- **Axis 2 — cognitive `category`** (`component.aggrega.ai/category`): a
  closed, single-valued set of 15:
  `ai-agent`, `ai-model`, `ai-tool`, `ai-pipeline`, `datastore`, `gateway`,
  `mesh`, `network`, `messaging`, `storage`, `compute`, `observability`,
  `security`, `bigdata`, `devtool`. The value matches the component's
  top-level directory name 1:1 — same word, no translation table. AI-pure
  categories carry the `ai-` prefix; dual-use categories (`datastore`,
  `gateway`, `mesh`, `network`, `messaging`, `storage`) appear bare, with
  AI flavor expressed by capability labels, not a category prefix.
- **Axis 3 — per-category capability labels** (`<role>.aggrega.ai/<dimension>`):
  e.g. `agent.aggrega.ai/autonomy`, `model.aggrega.ai/capability` +
  `/hosting`, `tool.aggrega.ai/impact`, `gateway.aggrega.ai/intelligence`,
  `datastore.aggrega.ai/engine`, `pipeline.aggrega.ai/mode`. These carry
  the behavioral subsets selectors and policies discriminate on.

Multi-membership is expressed through capability labels, never a
multi-valued category: a Postgres-with-pgvector is `category: datastore`
plus `datastore.aggrega.ai/engine: vector`, discoverable from both axes.
There is no stored "is-AI" boolean — tooling derives AI-relevance from any
`ai-`-prefixed category or AI-relevant capability value.

The category-vs-directory mirror is checked by the publishing linter's
`category-matches-directory` rule (warning at `aggrega lint`, error at
pre-publish, per-workspace opt-out for enterprise layouts). The compiler
itself is blind to all label vocabulary; the closed set is a standard-library
convention enterprises may extend or replace in their own catalogs.

### Recipe/FeatureRecipe Provider Namespace

Domain 3 entities use the execution engine as the first path segment:
`helm`, `terraform`, `cloudformation`, `compose`, `eval`.

### Per-version directory layout

**Every** publishable kind — Component, Feature, Provider, Aggregate, Recipe,
FeatureRecipe, SchemaLibrary, MappingLibrary — lives in a per-version
subdirectory:

```text
<kind>/<namespace-or-provider>/.../<name>/<version>/<entity>.yaml
```

The `<version>` directory segment MUST equal the entity's `metadata.version`; the
publish-time bundler rejects a mismatch (`ErrEntityVersionPathMismatch`). One
published version is one directory, so the source tree holds every version of an
entity side by side rather than relying on git history for older versions. The
`<entity>.yaml` filename is kind-conventional:

| Kind | Filename |
| --- | --- |
| Component | `component.yaml` |
| Feature | `feature.yaml` |
| Provider | `provider.yaml` |
| Aggregate | `aggregate.yaml` |
| Recipe / FeatureRecipe | `recipe.yaml` (co-located `source/`, `mappings/`, `artifacts/` sit beside it inside the version dir) |
| SchemaLibrary / MappingLibrary | `library.yaml` |

Recipe and FeatureRecipe deliberately share the `recipe.yaml` filename. The walker
is layout-agnostic (it indexes by authored `name:version`), so this layout is an
authoring + publishing convention enforced by the bundler, not a load-time rule.

## 2. Naming Conventions

### metadata.name

Must match the filesystem path segments after the entity type directory and before
the `<version>/` segment:

| Entity | Example filesystem path | metadata.name |
| --- | --- | --- |
| Component | `component/core/datastore/mariadb/1.0.0/component.yaml` | `core/datastore/mariadb` |
| Feature | `feature/core/data-masking/1.0.0/feature.yaml` | `core/data-masking` |
| Recipe | `recipe/helm/mariadb-bitnami/1.0.0/recipe.yaml` | `mariadb-bitnami` |
| FeatureRecipe | `feature-recipe/helm/k8s-dns-patcher/1.0.0/recipe.yaml` | `k8s-dns-patcher` |

Recipes and FeatureRecipes do NOT include namespace or provider in their name —
the provider is already the parent directory and `spec.provider` field.

The `ops/` prefix is NOT used. All Recipes are Domain 3 (Ops) by definition.

### Name shortening

When a component's filename would repeat the category, strip the suffix:

- `anthropic-agent.yaml` in `ai-agent/` → `anthropic.yaml` (name: `core/ai-agent/anthropic`)
- `openai-model.yaml` in `ai-model/` → `openai.yaml` (name: `core/ai-model/openai`)

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

Use `#` for comments throughout — every catalog file is YAML, and YAML's comment character is `#`. Schema bodies live under `spec.schema:` as JSON Schema 2020-12 declarations (compact form by default; full JSON Schema YAML via `$jsonschema:` when needed), so the inner content is YAML too and follows the same `#` convention.

## 4. Component Schema Pattern

Every Component declares its data pillars under `spec.schema:` in JSON Schema 2020-12 compact form. Three pillars cover the per-domain ownership split: `values:` (developer intent), `infra:` (operational sizing), `provides:` (public API contract):

```yaml
spec:
  schema:
    # values — Developer Intent
    # Filled by the Developer in the Aggregate.
    values:
      database_name: { type: string, required: true }
      charset: { type: string, default: utf8mb4 }

    # infra — Operational Sizing
    # Filled by Ops in the Release. Developer never sees this.
    infra:
      compute:
        type: object
        properties:
          cpu: { type: string }
          memory: { type: string }
      storage:
        type: object
        properties:
          size: { type: string }
          type: { type: string }

    # provides — Public API Contract
    # Keys exported to consumers via `uses` topology edges.
    provides:
      host: { type: string }
      port: { type: integer }
```

The compact form (about 15 keywords) covers the common case in a fraction of the line count of full JSON Schema; the `$jsonschema:` escape hatch admits full JSON Schema 2020-12 at any node boundary when the compact form does not carry the needed keyword. See [`aggrega-docs/language-reference/vocabulary/compact-form-authoring.md`](https://github.com/aggrega/aggrega-docs/blob/main/language-reference/vocabulary/compact-form-authoring.md) for the keyword vocabulary and [`aggrega-docs/language-reference/entities/component.md`](https://github.com/aggrega/aggrega-docs/blob/main/language-reference/entities/component.md) for the per-pillar authoring framing.

### The `overrides` escape hatch

Stateful components with provider-specific knobs should include an open-map field under `infra:`:

```yaml
spec:
  schema:
    infra:
      # ... universal fields ...

      # Provider-specific overrides. Accepts any nested structure.
      # Each Recipe documents which keys it reads.
      overrides:
        type: object
        additionalProperties: true
```

### The `source_version` field

Components backed by versioned upstream artifacts (Helm charts, Terraform modules) should include an `infra.source_version` override:

```yaml
spec:
  schema:
    infra:
      # Overrides the Recipe's default source artifact version.
      # Changing from default does not guarantee value mapping compatibility.
      source_version: { type: string }
```

## 5. Shared schema and mapping reuse

Schema fragments shared across multiple Components or Features live in **SchemaLibrary** entries under `schemalibrary/`. Go template fragments shared across multiple Recipes or FeatureRecipes live in **MappingLibrary** entries under `mappinglibrary/`. Reuse via cross-document references — `$ref:` for schemas, `$import:` for mappings — replaces the inline-duplication pattern.

A SchemaLibrary entry carries one or more named schema definitions under `spec.schemas:`. A consumer Component references the entry by library name and definition name:

```yaml
# schemalibrary/base-components.yaml — the library
apiVersion: aggrega.ai/v1alpha1
kind: SchemaLibrary
metadata:
  name: BaseComponents
spec:
  schemas:
    BaseComponentParameter:
      type: object
      properties:
        displayName: { type: string }
        description: { type: string }
```

```yaml
# component/core/datastore/mariadb.yaml — the consumer
spec:
  schema:
    values:
      $ref: "BaseComponents#/schemas/BaseComponentParameter"
      properties:
        database_name: { type: string, required: true }
```

A MappingLibrary entry carries one or more named Go-template fragments under `spec.mappings:`. A consumer Recipe imports the entry inside `valuesMapping:`:

```yaml
# recipe/helm/postgres-bitnami/recipe.yaml — the consumer
spec:
  valuesMapping:
    $import: BitnamiHelpers#/mappings/PostgresBitnamiCore
```

**Heuristic for when to factor.** A schema or mapping fragment that appears across three or more Components / Recipes is a candidate for a library entry; single-Component or single-Recipe content stays inline.

## 6. Recipe Pattern

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

## 7. OCI Registry

The canonical registry is `hub.aggrega.ai`. OCI URIs mirror the filesystem:

- `hub.aggrega.ai/component/core/datastore/mariadb:1.0.0`
- `hub.aggrega.ai/recipe/helm/mariadb-bitnami:1.0.0`
- `hub.aggrega.ai/feature-recipe/helm/k8s-secret-from-parameter:1.0.0`
