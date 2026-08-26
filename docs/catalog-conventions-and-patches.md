# Aggrega Catalog Conventions

> This document is the authoritative reference for catalog entity naming,
> directory structure, and YAML formatting. All catalog contributions
> (human or AI-generated) must follow these conventions.

## 1. Directory Structure

URI segments map 1:1 to filesystem path segments. The compiler resolves
`type: core/datastore/mariadb:1.0.0` to `component/core/datastore/mariadb.yaml`.

```text
aggrega-catalog/
├── component/{publisher}/{category}/{name}.yaml
├── feature/{publisher}/{name}.yaml
├── recipe/{provider}/{name}/recipe.yaml
├── feature-recipe/{provider}/{name}/recipe.yaml
├── aggregate/{publisher}/{name}/aggregate.yaml
├── schemalibrary/{name}.yaml
├── mappinglibrary/{name}.yaml
├── workloadlibrary/{name}.yaml
└── artifactslibrary/{name}.yaml
```

The four library kinds carry reusable fragments other entities reference by
identity:

| Kind | Directory | Carries | Consumed via |
| --- | --- | --- | --- |
| SchemaLibrary | `schemalibrary/` | Reusable JSON Schema 2020-12 fragments | `$ref:` from a Component or Feature |
| MappingLibrary | `mappinglibrary/` | Reusable Go template fragments | `valuesMapping: { $import: <Library>#/mappings/<entry> }` |
| WorkloadLibrary | `workloadlibrary/` | Reusable Workload template fragments | `workload: { $import: <Library>#/workloads/<entry> }` on a Recipe |
| ArtifactsLibrary | `artifactslibrary/` | Named artifact bundles — a set of output files imported as one unit | `artifacts.<name>: { $import: <Library>#/artifacts/<entry> }` on a Recipe or FeatureRecipe |

SchemaLibrary and MappingLibrary are the baseline tier. WorkloadLibrary and
ArtifactsLibrary are opt-in for catalogs that need cross-Recipe workload or
artifact reuse; both accept Go templates as their only authoring mode. See the
"Shared schema and mapping reuse" section below.

### Publisher

The first path segment after the entity type. Identifies the vendor/author.

- `core` — official Aggrega standard library (maintained by Cognitio S.r.l.)
- Third-party publishers: use your organization name (e.g., `acme`, `enterprise`)

### Component Categories

A Component's second path segment is its cognitive category — the same
word as its `component.aggrega.ai/category` label (the 1:1 mirror; see
the label section below). The 15 categories:

| Category | Contains | Typical ontology labels | On disk |
| --- | --- | --- | --- |
| `ai-agent` | AI agent frameworks, platforms, and patterns | worker, server, resource | populated |
| `ai-model` | Model providers and inference runtimes | server, resource | populated |
| `ai-tool` | Tools agents invoke | function, server, resource | populated |
| `ai-pipeline` | AI data/processing pipelines | worker, task | created when the first entity lands |
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
- **Enterprise Exception.** Third-party publishers may organize their
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
  e.g. `agent.aggrega.ai/autonomy`, `model.aggrega.ai/capability`,
  `tool.aggrega.ai/impact`, `gateway.aggrega.ai/intelligence`,
  `datastore.aggrega.ai/engine`, `pipeline.aggrega.ai/mode`. These carry
  the behavioral subsets selectors and policies discriminate on.

Multi-membership is expressed through capability labels, never a
multi-valued category: a Postgres specialization for pgvector deployments is
`category: datastore` plus `datastore.aggrega.ai/engine: vector`, discoverable
from both axes. The label sits on that specialization rather than on the
general-purpose Postgres, whose vector capability arrives with an extension a
deployment enables; a component carries an engine label on its own base only
where the product's identity is that engine, as `core/datastore/qdrant` and
`core/datastore/redis` do.
There is no stored "is-AI" boolean — tooling derives AI-relevance from any
`ai-`-prefixed category or AI-relevant capability value.

The category-vs-directory mirror is checked by the publishing linter's
`category-matches-directory` rule (warning at `aggrega lint`, error at
pre-publish, per-workspace opt-out for enterprise layouts). The compiler
itself is blind to all label vocabulary; the closed set is a standard-library
convention enterprises may extend or replace in their own catalogs.

### The `component.aggrega.ai/hosting` label

`component.aggrega.ai/hosting` records who operates a component's underlying
resource — the trust-boundary axis a policy engine reads to reason about data
exfiltration and ownership. It is a **cross-cutter**: the same three values
describe a managed database, a managed LLM API, and a self-run inference server
alike, so the label lives under the shared `component.aggrega.ai/` namespace
rather than any one category's `<role>.aggrega.ai/` capability namespace. The
value set is a standard-library convention (the compiler is blind to it):

- **`self-hosted`** — the deployment runs the compute itself, as containers in
  its own cluster. The operator owns the process lifecycle.
- **`managed`** — the deployment consumes a managed service it does not run:
  a managed instance in the operator's own cloud account, or a third-party
  managed / SaaS API. The provider owns the process lifecycle; the deployment
  holds a contract and credentials.
- **`external`** — the deployment references a pre-existing resource it neither
  provisions nor operates. The resource's lifecycle sits entirely outside the
  deployment; the Recipe emits only the wiring to reach it.

**Where the value lives — hosting is a static identity label.** `hosting` is a
selector-only component identity label (`metadata.labels`); it is never stamped
onto rendered output. Which value a component carries depends on whether the
trait is invariant across the component's Recipes:

- A component realized by Recipes that **all share one hosting posture** carries
  that single value — the component *is* one posture by identity, fixed the way
  `component.aggrega.ai/type` is fixed. Each standard-library AI model is exactly
  one value (a self-run server, or a managed API); the label states that identity.
- A **unified component whose Recipes span more than one posture** carries the
  value **`mixed`** — for example a datastore realized self-hosted by its Helm
  and Compose Recipes and managed by its Terraform/CloudFormation RDS Recipes.
  `mixed` is the honest identity value for a multi-posture component: no single
  posture *is* its identity, and the actual posture of a deployment follows the
  Recipe the Manifest selects rather than any stamped trait. The component stays
  unified (one component, several Recipes); it is not split per posture.

`mixed` generalizes to any `<scope>.aggrega.ai/` identity label on a unified
component whose Recipes span multiple values of that axis: rather than dropping
the label or splitting the component, carry `mixed` to state honestly that the
axis is realization-dependent. Because hosting is a selection concern — read
from *which* Recipe renders — it belongs on component identity, not on rendered
output: `component.aggrega.ai/hosting` is a `metadata.labels` key and never a
`spec.outputLabels` key. Like the value set, that is convention rather than
enforcement — the reserved-namespace rule on output labels covers the bare
`aggrega.ai/` keyspace, not the `component.aggrega.ai/` identity keys, so
nothing stops a Recipe from stamping the identity label except the author not
doing it. A Recipe that wants the posture of *its own* realization visible on
the emitted objects declares its own output-label key for that realization
trait, which is a separate, Recipe-owned surface.

### The `component.aggrega.ai/upstream-licensing` label

`component.aggrega.ai/upstream-licensing` records the licensing class of the
**product or service the Component wraps** — the third-party software a
deployment actually runs or calls. Like `hosting` it is a **cross-cutter**: the
same values describe a datastore engine, a hosted model API and an agent
framework alike, so it lives under the shared `component.aggrega.ai/` namespace
rather than under any one category's `<role>.aggrega.ai/` capability namespace.

**It is a different field from `metadata.license`, and the two are not
interchangeable.** Both describe the same subject — the wrapped product — at
different precisions. `metadata.license` carries that product's SPDX identifier,
naming exactly the licence of the software the entity packages;
`upstream-licensing` carries the coarse class that licence falls into. A reader
filtering on either one is reading about the software they are about to run, so
which to reach for is a question of precision: the field to match a named
licence, the label to match a policy category.

**Neither can be derived from the other, so both are stated.** A class does not
recover a licence — the standard library carries `osi-approved` over Apache-2.0,
AGPL-3.0, MPL-2.0, MIT and BSD-3-Clause alike, and a policy that turns on
copyleft cannot read that distinction out of the class. Nor does every wrapped
product yield a single identifier: `open-core`, `proprietary` and
`not-applicable` describe situations no one SPDX identifier expresses, and the
convention is to state the field where a single identifier applies and leave it
absent where none does — so the label classifies entities the field says nothing
about. The two also sit on different kinds. The label is a Component-identity
key, while `metadata.license` is stated on Recipes as well, where it is the only
surface naming the terms of the software the Recipe realizes.

**The catalog file's own licence is a third surface: the per-file
`# SPDX-License-Identifier:` header.** It states the terms the YAML itself is
published under, which is a different question again from the licence, or the
class, of the software that YAML describes. `core/datastore/redis` carries all
three, and each says something the other two cannot: an `Apache-2.0` header over
the file, `metadata.license: AGPL-3.0` over the datastore the file describes, and
`upstream-licensing: osi-approved` over the class that licence falls into.

The value set is a closed, single-valued standard-library convention (the
compiler is blind to it, as it is to every label):

- **`osi-approved`** — the wrapped product is published under an OSI-approved
  licence, and that licence covers the artifact a deployment runs.
- **`open-core`** — the wrapped product's core is published under an
  OSI-approved licence while a named subtree or edition is not, so which terms
  apply depends on which part a deployment uses.
- **`source-available`** — the source is published under terms that are not
  OSI-approved, and those terms attach conditions to redistribution, to hosting,
  or to offering the software as a service. Whether they also let a given reader
  obtain and run the artifact varies across the class and is not settled by the
  value itself — that is the one question the admission test below asks.
- **`proprietary`** — no source licence is granted to the user. The relationship
  is a vendor agreement: a hosted service the user contracts for, or a
  distributed artifact under the vendor's own terms.
- **`not-applicable`** — the Component wraps no single third-party product, so
  there is nothing to classify. Protocol shims that reach any implementation of
  an interface, abstract bases, and the generic compute primitives are this case.

Absence of the label means **not yet classified** — never "nothing to state",
which is `not-applicable`. Every `core/` Component naming a third-party product
carries a value; like the rest of the label scheme the field is convention, not
schema enforcement.

**It classifies the wrapped product, not this project's own dependencies.** The
two are separate surfaces with separate rules. This label records the terms
covering third-party software a deployment runs or calls, and every value in the
set is available to it. The terms this project accepts for its own third-party
dependencies — the libraries its compiler and tooling are built from — are
governed separately, by a dependency-licence gate that is stricter. So a value
recorded here describes the wrapped product and nothing else: it is never a
statement that this project's own dependency policy would accept the same terms,
and whether the `core/` catalog may wrap a given product is settled by the
admission test below rather than by its value.

**It composes with `hosting` rather than duplicating it.** Licensing says what
terms cover the software; hosting says who operates it. A hosted model API is
`hosting: managed` plus `upstream-licensing: proprietary` — proprietary software
the user never possesses. A vendor-licensed inference image run in-cluster is
`hosting: self-hosted` plus that same licensing value, and it is a materially
different obligation: the user must themselves be entitled to pull and run the
artifact. Reading either label alone loses that distinction, which is why
licensing is not folded into the hosting value set.

### What the standard library may wrap

The `core/` catalog applies one admission test to a Component before it is
authored, and the test is about **redistribution and brokerage** rather than
about the wrapped product's licence in the abstract:

> Does authoring this entity put the catalog in the position of distributing, or
> brokering access to, software whose terms do not permit that?

It is answered by inspecting each artifact the entity **pins** — every image
reference, chart reference and module source the catalog itself names — and the
answer is taken **per layer**: a permissive packaging artifact never settles the
software it packages, and where the two differ the packaged software governs.

- A pinned artifact must be obtainable and runnable by any reader on the
  artifact's own published terms, with no agreement the catalog would be a party
  to. `osi-approved` passes; `open-core` passes where the pinned artifact is the
  open core; `source-available` passes only where its terms let any reader obtain
  and run the pinned artifact for themselves — a right terms can grant while
  still attaching conditions to redistribution, to hosting, or to offering the
  software as a service.
- **A service a deployment merely calls is not a pinned artifact.** Where the
  entity pins nothing and its Recipes only wire a deployment to a service the
  reader contracts for directly — the reference realization of a hosted API — the
  test does not apply, and the entity is admitted whatever the service's own
  terms are. That relationship is between the user and the provider; the catalog
  neither distributes nor resells it.
- **An artifact the deployment supplies is not pinned either.** A Recipe whose
  image comes from a required `infra` value with no catalog-authored default
  names nothing, so the reader supplies an artifact they already hold the right
  to run.

The two failing shapes are therefore narrow and specific: a pinned artifact under
terms that forbid a reader obtaining and running it without a separate agreement,
and a pinned packaging artifact whose packaged software carries such terms even
though the packaging itself is permissive.

Admission and disclosure are separate acts. Whatever the verdict, the wrapped
product's licensing class is recorded through
`component.aggrega.ai/upstream-licensing`: passing the test is not a claim that
the wrapped product is open source, and a reader filtering on the label can still
exclude what their own policy forbids.

### Recipe/FeatureRecipe Provider Segment

Domain 3 entities use the execution engine as the first path segment:
`helm`, `terraform`, `cloudformation`, `compose`, `eval`.

### Per-version directory layout

**Every** publishable kind lives in a per-version subdirectory — run
`aggrega push --list-kinds` for the kinds the installed binary publishes:

```text
<kind>/<publisher-or-provider>/.../<name>/<version>/<entity>.yaml
```

The `<version>` directory segment MUST equal the entity's `metadata.version`. The
publish-time bundler rejects a mismatch (`ErrEntityVersionPathMismatch`); Plugin
sits outside that check, taking its version from `metadata.version` and its
repository location from its socket coordinate. One published version is one
directory, so the source tree holds every version of an entity side by side rather
than relying on git history for older versions. The `<entity>.yaml` filename is
kind-conventional:

| Kind | Filename |
| --- | --- |
| Component | `component.yaml` |
| Feature | `feature.yaml` |
| Plugin | `plugin.yaml` |
| Aggregate | `aggregate.yaml` |
| Recipe / FeatureRecipe | `recipe.yaml` (co-located `source/`, `mappings/`, `artifacts/` sit beside it inside the version dir) |
| SchemaLibrary / MappingLibrary / WorkloadLibrary / ArtifactsLibrary | `library.yaml` |

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
| Recipe | `recipe/helm/postgres/1.0.0/recipe.yaml` | `postgres` |
| FeatureRecipe | `feature-recipe/helm/k8s-dns-patcher/1.0.0/recipe.yaml` | `k8s-dns-patcher` |

Recipes and FeatureRecipes do NOT include a publisher or capability in their name —
the capability is the `spec.capability` field, which the parent directory mirrors
by convention.

Plugins are the one exception to the "`metadata.name` equals the path segments"
rule: a Plugin's `metadata.name` is **bare** and its socket lives in
`metadata.pluginType`. The filesystem location `plugin/<pluginType>/<name>` is
**derived** from the `<pluginType>/<name>` coordinate rather than mirrored from a
socket-prefixed name — so the `plugin/terraform` entity is at
`plugin/provider/terraform/<version>/plugin.yaml` with `metadata.name: terraform`
and `metadata.pluginType: provider`.

The `ops/` prefix is NOT used. All Recipes are Domain 3 (Ops) by definition.

### Library-kind names are bare PascalCase

The four library kinds — SchemaLibrary, MappingLibrary, WorkloadLibrary,
ArtifactsLibrary — follow their own naming rule, and it differs from Components
and Features on two counts: the name carries **no publisher prefix** (not even
`core/`), and it is **PascalCase** while its directory segment is kebab-case.

| Entity | Example filesystem path | metadata.name |
| --- | --- | --- |
| SchemaLibrary | `schemalibrary/base-components/1.0.0/library.yaml` | `BaseComponents` |
| SchemaLibrary | `schemalibrary/ai-datastores/1.0.0/library.yaml` | `AIDatastores` |
| WorkloadLibrary | `workloadlibrary/base-workloads/1.0.0/library.yaml` | `BaseWorkloads` |

The directory segment is the kebab-case transliteration of the PascalCase name;
an acronym stays fully uppercase in the name (`ai-datastores` → `AIDatastores`).

The reason for the difference is that a library is referenced **by identity, not
by location**: a consumer writes `$import: BaseWorkloads#/workloads/http-service`
and the per-Release lockfile supplies the version. Since the reference carries no
publisher and no registry host, a publisher prefix on the name would be
decoration the reference could never use. Library names are therefore
catalog-global and must be unique across every publisher publishing into the same
consumer's closure — pick a name specific enough not to collide (`AcmeBaseWorkloads`
rather than `Base`).

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

The header states the terms **this YAML file** is published under, and it is the
only surface that can: `metadata.license` names the licence of the software the
entity describes, not of the file describing it. It is stated per file rather
than inferred from the repository so that a catalog published by anyone else can
say what its own terms are.

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

### Version knobs: `engine_version` and `source_version`

Two `infra` fields carry version selection, and they are distinct. Both are provider-neutral conventions — the compiler reads neither; each Recipe decides which it honors and how.

- **`engine_version`** — the running server or binary version. Every component carries it. On synthesized and Compose targets it selects the container image tag; on managed-service targets (Terraform, CloudFormation) it selects the provider's engine version — an RDS `engine_version`, for example. It is the live version knob for the software the component runs.
- **`source_version`** — the version of the *source artifact* a Recipe pulls: a Helm chart version, a Terraform module version. Only artifact-backed Recipes (a chart wrap, a module wrap) pull such an artifact, so `source_version` belongs only on components whose Recipes are artifact-backed. A pure-synth Recipe assembles its workload directly and pulls no chart or module, so it has no source artifact to version — it exposes `engine_version` alone.

Declare `source_version` only where an artifact-backed Recipe reads it:

```yaml
spec:
  schema:
    infra:
      # Selects the version of the source artifact (Helm chart, Terraform
      # module) the Recipe pulls. Changing it away from the Recipe's default
      # does not guarantee value-mapping compatibility with the new artifact.
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
# recipe/helm/mariadb/recipe.yaml — the consumer
spec:
  valuesMapping:
    $import: DatastoreHelpers#/mappings/MariaDBCore
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

### Target-expected names are the Recipe's translation

A Component publishes a value once, under the name that reads best on Aggrega's
own surface — `model`, `host`, `endpoint`. The target that consumes it rarely
expects that spelling: one agent framework resolves its model name from `MODEL`,
another from `OPENAI_CHAT_MODEL_ID`, a third reads no model variable at all.
Mapping the one published value onto whatever spelling the target expects is the
Recipe's job, and it belongs nowhere else. A Recipe therefore states, in the
comment block around the environment map it renders, which variable its target
reads and why that one — and where a target's own documentation names several
aliases, it delivers the documented-canonical one rather than carrying a second
variable for insurance.

This is not a naming fracture. One concept keeps one name on the surface Aggrega
defines — the keys authored in an Aggregate, the values a Component publishes,
the diagnostic codes and CLI flags a user reads. A third party's
environment-variable spelling is not that surface; it is the target's, and no
convention here can change it. The Component publishes one `model`, and each
Recipe translates it, exactly as every Recipe already translates an attached
credential into `OPENAI_API_KEY`.

Where a target reads no variable for the value at all, the Recipe still delivers
it under a stable name for the application's own code to read, and says so. A
value with a named consumer is not an inert declaration, even when the framework
itself is not the consumer; what makes it inert is nothing reading it, and that is
the claim a Recipe's comment has to get right.

### Managed-service credentials

For Recipes targeting cloud-managed services (AWS RDS, Azure Database, GCP
Cloud SQL, etc.), prefer the provider's native managed-secret flag over a
credential FeatureRecipe that *renders* a secret. Terraform Recipes for RDS set
`manage_master_user_password = true` so RDS auto-manages the password via AWS
Secrets Manager; CloudFormation Recipes set `ManageMasterUserPassword: true`
for the same effect. The cloud provider already owns the password lifecycle,
and a FeatureRecipe that renders a secret beside it duplicates that lifecycle
and adds synchronization risk.

Preferring the native flag does not mean leaving the credential slot unbound.
Where the Component declares that slot with `required: true`, nothing binding it
halts the build — so "do not attach a credential here" is not an option the
deployment has. The form that binds the slot without reintroducing a second
lifecycle is `core/generated-secret`, the credential Feature that states the
target engine owns the material. Its FeatureRecipes are pure wiring: each
declares only the capability it binds to and the Feature it implements, and
renders nothing. A deployment that binds the slot this way emits output
byte-identical to the same deployment with no attachment at all — the slot is
satisfied, and no second secret exists to drift out of step.

The standard library ships that wiring for both managed-database capabilities:
[`feature-recipe/terraform/generated-secret`](../aggrega-catalog/feature-recipe/terraform/generated-secret/1.0.0/recipe.yaml)
and
[`feature-recipe/cloudformation/generated-secret`](../aggrega-catalog/feature-recipe/cloudformation/generated-secret/1.0.0/recipe.yaml).
Both carry the FeatureRecipe name `generated-secret`, so a Manifest must
reference the intended one **provider-qualified** —
`terraform/generated-secret:1.0.0`, not `generated-secret:1.0.0`. A bare name
resolves only when exactly one capability in the catalog carries it; with two
carrying this one, a bare reference matches both, resolves to neither, and the
attachment is reported unmapped when the build checks resolution completeness.

The canonical examples are
[`recipe/terraform/mariadb-rds/recipe.yaml`](../aggrega-catalog/recipe/terraform/mariadb-rds/1.0.0/recipe.yaml)
and
[`recipe/cloudformation/mariadb-rds/recipe.yaml`](../aggrega-catalog/recipe/cloudformation/mariadb-rds/1.0.0/recipe.yaml).
This guidance applies to managed services only — Recipes targeting
self-managed datastores (Helm Bitnami chart, Compose container) still use the
credential FeatureRecipe path because no upstream managed-secret flag exists
for those targets.

### Optional credential slots for self-managed datastores

A self-managed datastore Component declares its password as an **optional**
credential slot in `spec.featuresSchema`, and its Recipes wire that slot
**conditionally** — the credential subsystem when a credential is attached, an
inline development default when none is. This keeps the slot non-breaking: a
deployment that attaches no credential still renders and runs, byte-identically
to a Recipe with no slot at all.

The shared Component declares an optional, transparent slot — no `required:`,
and `inject: [env]` so a synthesized Workload may reference it as an env secret.
The selector is secret-kind-pinned but family-agnostic
(`feature.aggrega.ai/kind=secret`), so either an inject-value credential or a
referenceable credential may fill it per provider:

```yaml
spec:
  featuresSchema:
    password:
      selector: "feature.aggrega.ai/kind=secret"
      inject: [env]
```

Each Recipe guards the credential wiring with a presence test on the slot. The
live `features` pillar is **absent** (not an empty map) when nothing is attached,
so coerce it before the key test: `hasKey (default dict .features) "<slot>"`. The
helm Recipe renders an env `secretKeyRef` via `containers.<n>.attachments` when
attached (a referenceable credential); the compose Recipe reads the value its
credential delivers on the inject pipe (an inject-value credential). When
unattached, both fall back to the inline default:

```gotemplate
variables:
  DB_USER: appuser
{{- if not (hasKey (default dict .features) "password") }}
  DB_PASSWORD: devdefault
{{- end }}
{{- if hasKey (default dict .features) "password" }}
attachments:
  DB_PASSWORD:
    from: password
    as: env
{{- end }}
```

The canonical examples are
[`recipe/helm/postgres/recipe.yaml`](../aggrega-catalog/recipe/helm/postgres/1.0.0/recipe.yaml)
and
[`recipe/compose/postgres/recipe.yaml`](../aggrega-catalog/recipe/compose/postgres/1.0.0/recipe.yaml).

### Credential-slot models — match the chart's auth surface

Self-managed datastore families use one of two principled credential-slot
conventions. The convention is chosen by what the upstream chart's
authentication surface demands, **not** by author preference: the Recipe adapts
to the chart, and the compiler is unopinionated about which model a Component
declares. The standard library does not force convergence on one model — the two
coexist because they are dictated by the charts, and an author picks the one the
chart's auth surface requires.

**Model A — bundled multi-key `existingSecret`.** For charts that authenticate
**only** from a single Kubernetes Secret carrying several fixed keys, the Component
declares a Black-Box `root_password` slot (`required: true`, `inject: []`) plus a
transparent `user_password` slot. A multi-key credential producer — the
`referenced-secret-set` Feature via the `k8s-secret-set` FeatureRecipe — emits one
Secret carrying the caller-named keys (e.g. `<engine>-root-password` and
`<engine>-password`), and the chart reads it through `auth.existingSecret` bound to
`{{ .features.root_password.provides.name }}`:

```yaml
spec:
  featuresSchema:
    root_password:
      required: true
      inject: []          # Black-Box — the Recipe controls delivery
    user_password:
      inject: [env, file] # transparent — developer may dictate delivery
```

The Recipe binds the chart's `existingSecret` knob to the producer's published
Secret name — the shape a Model-A Recipe's `valuesMapping` takes:

```yaml
spec:
  valuesMapping: |
    auth:
      existingSecret: "{{ .features.root_password.provides.name }}"
```

For a runnable end-to-end walkthrough of this model, see
[`language-reference/examples/mariadb-bitnami-credential-set/`](https://github.com/aggrega/aggrega-docs/blob/main/language-reference/examples/mariadb-bitnami-credential-set/).

**Model B — granular transparent inject-value.** For charts that accept a single
password **value** (`postgres`, `valkey`, `redis`, `memcached`), the Component
declares one optional transparent `password` slot
(`selector: feature.aggrega.ai/kind=secret`, `inject: [env]`), filled by an
inject-value credential, with a deterministic inline development default when the
slot is unattached (the conditional-wiring pattern documented in the previous
subsection):

```yaml
spec:
  featuresSchema:
    password:
      selector: "feature.aggrega.ai/kind=secret"
      inject: [env]
```

The canonical example is
[`recipe/helm/postgres/recipe.yaml`](../aggrega-catalog/recipe/helm/postgres/1.0.0/recipe.yaml).

The two models are principled, not arbitrary: Model A is required whenever the
chart reads credentials **only** from a named multi-key Secret; Model B fits
charts that take a single password value. Match the model to the chart's auth
surface.

### File-mounted credential delivery

Some clients read their credential from a **file** rather than an environment
variable — a Google Cloud service-account key, for example, is a JSON file the
client libraries locate through the `GOOGLE_APPLICATION_CREDENTIALS` environment
variable. The delivery reuses the referenceable-secret family unchanged: the
credential is materialized as a Secret by a `core/referenced-secret` attachment,
and the consuming Recipe mounts that Secret as a file and points the client's
credential-path variable at the mounted file. No new Secret-emitting Feature is
authored — the file mount and the credential-path variable are the only additions
on the consumer.

The consumer Component declares a secret slot that allowlists the file mount:

```yaml
spec:
  featuresSchema:
    gcp_key:
      required: true
      inject: [file]     # the slot permits the Recipe's `as: file` mount
```

The Recipe mounts the whole Secret at a directory and derives the credential
file's path from the slot's published data key, so the path tracks whatever key
the attached secret publishes:

```yaml
spec:
  workload: |
    apiVersion: aggrega.ai/v1alpha1
    kind: Workload
    containers:
      main:
        variables:
          GOOGLE_APPLICATION_CREDENTIALS: "/var/secrets/google/{{ .features.gcp_key.provides.key }}"
        attachments:
          gcp-service-account-key:
            from: gcp_key
            as: file
            path: /var/secrets/google
```

The whole Secret mounts as a directory, so each data key becomes a file named by
the key. For a runnable end-to-end walkthrough, see the worked example
[`component/example/compute/gcp-credentialed-service/`](../aggrega-catalog/component/example/compute/gcp-credentialed-service/1.0.0/component.yaml)
and its Recipe
[`recipe/helm/gcp-credentialed-service/`](../aggrega-catalog/recipe/helm/gcp-credentialed-service/1.0.0/recipe.yaml).

### The `workload:` authoring contract

Three rules govern every synthesised Recipe. Each is enforced at load or render
time, so getting one wrong is a build failure rather than a silent difference.

**1. `workload:` is a template string, never an inline map.** Author it as a block
scalar (`workload: |`). The Recipe envelope accepts a string or a single-key
`$import:` map, so an inline YAML map fails validation with a type error naming
`string` as the expected shape:

```yaml
# CORRECT
spec:
  workload: |
    apiVersion: aggrega.ai/v1alpha1
    kind: Workload
    form: stateless

# WRONG — an inline map is rejected
spec:
  workload:
    form: stateless
```

**2. The template's output must carry `apiVersion` and `kind` at its head.** The
rendered text is parsed as a standalone Workload document, so the first two lines
of the template are always:

```yaml
    apiVersion: aggrega.ai/v1alpha1
    kind: Workload
```

Omitting them fails workload validation at render. Every snippet in this document
that shows a partial `workload:` body still requires this header in the authored
file.

**3. `provides` cannot read the workload.** `provides` is self-contained: it
evaluates before any caller is resolved, and its template context offers only
`.context.instance_id`, `.values`, `.infra`, `.locals`, and static text. There is
no `.workload` in scope, so `provides.endpoint` cannot derive itself from the
workload's endpoint. Where a Recipe needs to publish an endpoint, declare it as a
static value or as an `.infra` / `.values` reference, and treat the workload's own
endpoint as a separate declaration. When both express the same address, that
duplication is a single-sourcing hazard — put the address in one `infra` or
`values` key and have both read it, rather than repeating the literal twice.

### Presence parametrization — expose an enable-parameter per component

A published Aggregate exposes an enable/disable parameter per optional component
so a deployment can toggle that component's presence per environment. The
convention: declare a boolean parameter such as `enable_cache` in the Aggregate's
`parameters`, and have the component's presence expression reference it. A
deployment then flips the component on or off by fulfilling the parameter,
without editing the Aggregate's topology.

Per-component presence toggling is documentation-only today; it becomes
authorable in a future iteration when the optional-component capability ships.
Author the Aggregate's `parameters` with the enable-flag in place now so the
intent is captured; the `active:` expression that consumes it takes the following
shape once the capability lands:

```yaml
# authorable once the optional-component capability ships
spec:
  parameters:
    enable_cache:
      type: boolean
      default: true
  components:
    cache:
      type: core/datastore/valkey:1.0.0
      # active: "{{ .parameters.enable_cache }}"
      #   the active expression gates whether this component
      #   enters the graph; authorable in a future iteration
```

Until the capability ships, declare the enable-parameter as the intended
convention and document which component it is meant to gate; do not author the
`active:` expression itself yet.

### Reference-realization Recipes

A component's `provides` contract can be fulfilled by a Recipe that provisions
**nothing** — a *reference realization* that emits only the wiring a consumer
needs to reach a pre-existing resource. Provisioning nothing does not mean
declaring nothing: every Recipe outside the `eval` capability must still carry
one of the engine input kinds — `source`, `valuesMapping`, `workload` or
`artifacts` — and a Recipe carrying only `provides` is refused when the document
is loaded. For `helm` and `compose` the input kind a reference realization
declares is a `workload` in `form: reference`, which names the endpoint, carries
no containers, and so runs nothing. This is the shape a
`component.aggrega.ai/hosting: external` realization takes.

The reference realization fulfils the **same `provides` contract** as a
provisioning Recipe for the same component, so a single component can offer
several realizations — self-hosted, managed, referenced — selected per
deployment through the Manifest's component-type mapping. The consumer's wiring
is identical regardless of which realization answers it, because it reads the
component's `provides` outputs, not the realization behind them.

Per engine, the wiring the reference Recipe emits:

- **helm** — where the resource is addressed by name, an `ExternalName` Service
  that maps an in-cluster DNS name onto the external endpoint. No
  `Deployment`/`StatefulSet` — nothing runs, and no `Secret`: a reference
  workload carries no credential of its own, because the environment-variable
  name belongs to the consumer rather than to the endpoint. The connection
  material arrives from the attached credential Feature described below.
- **terraform** — a `data` source that reads the existing resource, or input
  variables carrying its coordinates. No `resource` block — nothing is created.
- **compose** — environment variables carrying the endpoint and credentials into
  the consuming service. No service definition for the referenced resource.

The credential slot is filled by a referenced credential — the
`core/referenced-secret` Feature — rather than a provisioned one, so the secret
material comes from outside the deployment. An optional governance Feature can
ride the same edge to carry policy context for the referenced resource without
coupling it to provisioning.

**Reference is not adoption.** Hosting (`self-hosted | managed | external`) is
the who-operates axis; the resource *lifecycle* — provision → adopt → reference
— is a separate axis. A reference realization (provides-only, emits no compute)
ships with the conventions above. *Adoption* — taking an existing resource under
management so subsequent changes flow through the deployment, via the engine's
own take-ownership syntax (Terraform `import` blocks, Crossplane observe-only
management) — is a distinct capability delivered by a FeatureRecipe transform,
not by the hosting label. A referenced resource stays externally owned; an
adopted resource becomes deployment-managed.

### Gateway / operator-driven (custom-resource-emitting) Recipes

The production way to run complex software on Kubernetes is often an **operator**:
a controller that reconciles a **custom resource** into running infrastructure
(a message broker becomes a Strimzi `Kafka`; a model-serving path becomes an
Envoy AI Gateway `AIServiceBackend`). A Recipe realizes this by emitting the
custom resource — one more realization of an existing component, selected per
deployment through the Manifest's component-type mapping, coexisting with that
component's synthesis, reference, and cloud-native realizations.

The custom resource carries in `artifacts:`, one map entry per emitted file. The
recipe fulfils the **same `provides` contract** as the component's other
realizations, so consumers are realization-agnostic: an operator-driven Kafka
publishes `provides.host` as the operator-created client bootstrap Service, and a
gateway-mediated model publishes `provides.endpoint` as the in-cluster gateway
Service — the consumer's wiring is unchanged from the synthesized or managed form.

**The runtime-prerequisite discipline.** A custom resource only reconciles if its
**control plane** — the custom-resource definition and its controller — already
exists in the target cluster; emitted into a cluster that lacks it, the resource
is an orphan that never becomes infrastructure. The compiler is ahead-of-time and
cannot inspect cluster state, so it cannot check the control plane is present.
The prerequisite is therefore made an **explicit, declared part of the model** —
never a silent emit. Two shapes, both explicit:

- **Ambient-assumed** — the control plane is platform-provided (installed
  cluster-wide). The recipe emits only the custom resource, and declares the
  prerequisite: the component carries an operator-affirmed `infra` boolean (a
  `control_plane_present` flag, defaulting false), and the recipe guards emission
  with a build-time `assertions` entry that halts loudly when the flag is
  unaffirmed. The operator sets the flag in the Release once the control plane is
  in place, consciously acknowledging the requirement.
- **Bundled-deploy** — the deployment ships the control plane too. The operator
  install is a first-class **companion component** (a `server` component whose
  Recipe emits the ServiceAccount, cluster RBAC, and controller Deployment, or
  wraps the project's upstream install chart), declared in the same Aggregate
  alongside the custom-resource-emitting component, so the custom resource and the
  controller that reconciles it are deployed together.

Both make the prerequisite a declared thing the reader can see. The shape to
avoid is the third, silent one: emitting a custom resource with the control plane
merely hoped to be present and nothing in the model saying so.

**Credential custody.** A gateway holds the provider credential and authenticates
upstream on the application's behalf, so the credential never reaches the
application. The credential is a referenceable Secret filled through the
`core/referenced-secret` credential Feature on the component's credential slot; a
security-policy custom resource binds it to the backend. A black-box credential
slot still publishes its produced resource's locator to the Recipe, so the recipe
reads the Secret's name for the security policy without exposing the value.

**The exemplar.** Strimzi Kafka is the template for this pattern: `core/messaging/kafka`
offers an operator-driven realization emitting a `Kafka` and `KafkaNodePool`
custom resource alongside its synthesized StatefulSet realization, and ships both
prerequisite modes (the Strimzi Cluster Operator as an ambient assumption or as a
bundled companion component). The same shape carries to further operators —
Elasticsearch, HA Postgres, additional AI gateways. The Envoy AI Gateway path
(`AIServiceBackend` plus a `BackendSecurityPolicy` for the provider credential) is
the AI-gateway instance of the pattern. Author custom-resource fields against the
target project's current API documentation, since custom-resource schemas evolve
independently of the catalog.

### Self-hosted inference: dual realization (synthesis and controller-driven)

A self-hosted inference runtime — a model server run on the cluster's own
compute, marked `component.aggrega.ai/hosting: self-hosted` in the `ai-model`
category (`ollama`, `vllm`, `tgi`, `tei`, `nvidia-nim`) — is deployed two
genuinely different ways in the field, and each is a Recipe realizing the same
component, selected per deployment through the Manifest:

- **Direct synthesis.** The Recipe synthesizes the server itself as a `Workload`:
  a weights-pull initContainer resolves the model pointer into a per-replica
  model-cache volume, and the serving container mounts that volume and fronts the
  API behind a ClusterIP Service. The model value (a Hugging Face id, or an OCI
  reference) is a deterministic pointer the initContainer resolves at pod start;
  the compiler never fetches weights. This realization needs no serving control
  plane, so it is the default where the cluster runs none. CPU and GPU are both
  expressible: GPU requests the extended resource `nvidia.com/gpu` on the serving
  container and, when a runtime class is named, schedules the pod under it.
- **Controller-driven.** The Recipe emits a model-serving controller's custom
  resource — a KServe `InferenceService` or a KubeAI `Model` — in `artifacts:`,
  and the controller owns the serving workload. GPU carries through the custom
  resource directly. This realization suits a cluster that already runs a serving
  control plane, and carries the **runtime-prerequisite discipline** described
  under "Gateway / operator-driven (custom-resource-emitting) Recipes" above —
  the same `control_plane_present` affirmation and build-time assertion, so a
  serving custom resource is never emitted as an orphan. It is one discipline, not
  two; the self-hosted controller-driven recipes reuse it rather than defining
  their own.

Both realizations fulfil the **same `provides` contract** — `host`, `port`,
`endpoint`, `model`, `protocol` — so a consumer that `uses` the model reads the
same keys regardless of realization; only the values differ, each supplied as its
runtime requires. A synthesized server publishes its own ClusterIP Service and the
weights id as the model name; a KServe realization publishes the predictor Service
the controller creates; a KubeAI realization publishes the operator's shared proxy
and the resource name the operator routes on. The contract is one of keys, not
values: the consumer's wiring is unchanged across all of them.

Which realization to choose follows the cluster: with no serving control plane,
synthesize directly; with KServe or KubeAI installed, emit its custom resource and
let the controller serve. Custom-resource field names and service-naming
conventions here (for example a predictor Service name, or an operator's resource
profile names) follow each project's current API and installation, which evolve
independently of the catalog — verify them against the target cluster, per the
note above.

### Persistence, HA, active-passive and backup are options, not separate components

**A user must never change component to turn on persistence, high availability,
active-passive or backup.** A datastore with persistence enabled is still that
datastore. These capabilities are configurable values on the single component's
surface, realized per target by whatever mechanism that target has: a chart's HA
options, an operator custom resource's HA spec, a cloud provider's multi-AZ flag,
or a synthesised StatefulSet with a PersistentVolumeClaim. Splitting a component
or recipe family by stateful-ness is an antipattern — it doubles the catalog and
forces a deployment to re-author its topology to change an operational setting.

Two consequences for authors:

- **Where enabling persistence flips the controller shape** between a stateless
  and a stateful workload, drive `form` from the persistence value rather than
  forking the recipe:

  ```yaml
  form: "{{ if .values.persistence.enabled }}stateful{{ else }}stateless{{ end }}"
  ```

  `form` is normalized and validated after template rendering, so a template that
  resolves to a legal form value is accepted. Prove the conditional end to end
  before a component leans on it: a persistence-on build must render the stateful
  shape and a persistence-off build the stateless one, both byte-identical across
  repeated runs.

- **A stateful form needs its governing Service declared.** The engine never
  auto-generates a headless Service, so the branch that resolves to
  `form: stateful` must always declare the headless Service alongside it.

This rule also settles a trap worth naming: a knob a component's surface exposes
must **do something** on every target that component ships. A value that is
declared, validated and then silently dropped on one target is a defect, not a
gap — either realize it for that target per the target's own pattern, or do not
expose it for that target at all.

### The datastore family template

Every datastore component targets the same shape, distilled from the PostgreSQL
exemplar. A new family member is authored against this template rather than by
copying whichever sibling happens to be nearest.

- **`values`** — the engine-specific subset of logical bootstrap names plus engine
  configuration, each key carrying a `description` and a sensible default so a bare
  deployment renders unchanged: the logical `database`, `user` (or `app_user` where
  an application-role split applies), `encoding` / `locale`, `init_scripts` (an
  object whose values are strings), and `custom_config` for a raw configuration
  block. Plus the persistence, HA and backup toggles as configurable knobs, per the
  rule above, wherever the engine has them.
- **`infra`** — `port`, `engine_version`, `compute.{cpu,memory}`, and for stateful
  engines `storage.{size,type}`; `ha.{enabled,read_replicas}`;
  `backup.{enabled,retention_days}`; and `overrides` as the open bag for the
  operational side.
- **`provides`** — `host` and `port` are required; `user`, `database` and
  `protocol` are declared **only where the engine has the concept**. Redis, Valkey
  and Memcached have no user or database — do not invent them to make the family
  look uniform.
- **`featuresSchema`** — an optional transparent `password` slot carrying an inline
  development default when nothing is attached, so an unattached deployment stays
  byte-identical to its pre-slot output; plus an optional `app_user_password` where
  the application-role split applies.
- **Realizations** — helm synthesis (the workload `form`, a PersistentVolumeClaim
  and a headless Service for stateful engines), compose for local development, and
  the managed cloud equivalents where one exists, with HA and backup honored there
  through the provider's native flags rather than re-implemented.
- **Identity labels** — the component's `metadata.labels` carries all three label
  axes: `component.aggrega.ai/type`, `component.aggrega.ai/category: datastore`,
  and the family's capability label `datastore.aggrega.ai/engine` where the engine
  has a discriminating value. Plus `component.aggrega.ai/hosting` per the hosting
  rule above — a single posture where every Recipe of the member shares one,
  `mixed` where the member is realized both self-hosted (helm, compose) and
  managed (the Terraform/CloudFormation equivalents). These are selector-only
  identity; the family's Recipes do not stamp them onto rendered output.

## 7. Feature Pattern

Features are how the operational ecosystem *wraps* a workload, and the Feature
track is co-equal with the component track rather than an afterthought. A Feature
attaches to any workload by selector, is authored once, and is reused across every
component it matches. That is what keeps each component's own surface at a
service-specific few dozen values instead of accumulating a dial for every
operational concern.

### Component installs the machinery; Feature attaches the resource

The distinction to hold, because it decides which kind you are authoring:

- Installing a controller or operator — cert-manager, ingress-nginx,
  external-secrets — is a **component**, usually a source-input helm recipe.
- The per-workload resource that controller reconciles — a `Certificate` for this
  workload, an `Ingress` or `HTTPRoute` for this workload, a `ServiceMonitor` for
  this workload, an `ExternalSecret` for this workload — is a **Feature**.

A runtime guardrail or gateway binding to a node is a Feature (or its annotation
shortcut), **not** a `uses` edge. A `uses` edge is dumb string-routing between
components that already exist; a guardrail is new runtime configuration to attach,
which is exactly what a Feature is for.

### The Feature taxonomy

- **secrets management** — external-secrets-operator, sealed-secrets, vault
  injector, secrets-store CSI
- **sidecars** — generic, logging and proxy injection
- **service meshes** — Istio, Linkerd
- **load balancers and ingresses** — ingress-nginx, Contour, Traefik, Gateway API,
  cloud load balancers
- **TLS and certificates** — cert-manager Issuer and Certificate
- **network policies** — NetworkPolicy, Cilium
- **runtime policies** — Kyverno, OPA Gatekeeper
- **runtime AI controls** — prompt and response guardrails, PII filters,
  rate limiting, model firewalls
- **autoscaling** — HPA, VPA, KEDA
- **availability** — PodDisruptionBudget, priorityClass
- **observability** — ServiceMonitor and PodMonitor, OpenTelemetry collector or
  sidecar, dashboards
- **backup** — cluster backup tooling, database backup custom resources
- **RBAC**, and storage or volume snapshots

### Authoring tiers

The tiers order the taxonomy by what unblocks a production deployment soonest.
They are an authoring priority, not a dependency graph — a catalog may author any
Feature at any time.

| Tier | Scope | Members |
| --- | --- | --- |
| 1 | The production floor every real service needs | TLS and certificates; ingress or load balancer; observability; secrets management |
| 2 | Availability and scale | autoscaling; PodDisruptionBudget and priorityClass; network policy |
| 3 | Advanced operations | backup; RBAC beyond a ServiceAccount; sidecars; service mesh |
| 4 | Runtime AI controls | prompt and response guardrails; PII filters; rate limiting; model firewalls |

Tier 1 is the highest-leverage Feature work for any catalog, because it is the
wrap a shipped component needs before it is production-grade.

### Two realization realms for policy — and why guardrails are Features

Two realms, never conflated:

- **Compiler policy is the governance socket.** It runs ahead of time, inside the
  compilation pipeline, as a verdict or transform over the compiler's graph or
  rendered output. It regulates what the compiler may *produce*.
- **A runtime guardrail is a Feature.** It is rendered, deployed, and then active
  at runtime on the workload — filtering what a user may ask a model, or what the
  model may answer. It may emit a custom resource a controller reconciles, inject a
  sidecar, or call an external service.

The boundary is where the thing acts: pipeline and output for the first, output
and runtime for the second. This is why the runtime AI-control tier above, and
operator-driven custom resources generally, are Features and artifacts rather than
workload dials or edges.

## 8. OCI Registry

The canonical registry is `hub.aggrega.ai`. OCI URIs mirror the filesystem:

- `hub.aggrega.ai/component/core/datastore/mariadb:1.0.0`
- `hub.aggrega.ai/recipe/helm/mariadb:1.0.0`
- `hub.aggrega.ai/featurerecipe/helm/k8s-secret-from-parameter:1.0.0`

### Registry repository segments

Every artifact in the registry lives under a top-level repository segment. There
are three classes of segment.

**Entity-kind segments.** A catalog entity publishes under its kind name,
lowercased: a `Component` at `component/`, a `Feature` at `feature/`, a
`SchemaLibrary` at `schemalibrary/`, a `MappingLibrary` at `mappinglibrary/`, an
`Aggregate` at `aggregate/`. Recipes and FeatureRecipes additionally carry their
execution engine as a scope segment, because two engines may ship a recipe of the
same name: a `Recipe` at `recipe/<provider>/`, a `FeatureRecipe` at
`featurerecipe/<provider>/`. The full repository path is the segment followed by
the entity's lowercased identity path (`component/core/datastore/mariadb`).

**The plugin segment.** A `Plugin` publishes under `plugin/`, and its socket is
part of its identity. A plugin's `metadata.name` is **bare** — the plugin's own
name with no socket prefix — and the socket it attaches to is carried separately
in `metadata.pluginType`. The identity coordinate is the pair
`<pluginType>/<name>`, and the location and catalog layout `plugin/<pluginType>/<name>`
are **derived** from that pair. The same bare name under a different
`pluginType` is a different plugin, so the socket travels with the plugin's
identity through its `metadata.pluginType`, and the derived coordinate places it
at a distinct location. The raw `.wasm` binary the entity pins by digest is
published as its own artifact alongside the entity.

The core plugin entities are **generated, not hand-authored** — one per guest
embedded in the compiler, filed under the socket directory its `pluginType`
derives, so the committed set covers whichever sockets those guests serve rather
than an enumeration kept by hand. The CLI derives each entity's contract fields
(`metadata.pluginType`, ABI version, targets, exports, capabilities) directly from
the compiled guest's self-report and merges them with a small authored overlay
under `plugin-overlays/`: the bare identity, the runtime limits, and the provider
block for a plugin that carries one. A guest serving a socket that resolves no
capability — a `governance`, `linter` or `cli` plugin — declares none, and its
entity carries none.
The generator writes the derived `metadata.pluginType`
into the entity and computes the entity's location from the `<pluginType>/<name>`
coordinate; the overlay carries only the bare `metadata.name` and never a
`pluginType` of its own. The entity version is the compiler build that produced it.
The tag-driven publishing CI regenerates and signs this set from the released
binary, so a generated entity can never promise a capability the shipped guest
does not provide. Each generated file carries a `generated; DO NOT EDIT` header —
edit the overlay, then regenerate.

**Reserved non-kind segments.** Two top-level segments are reserved for
artifacts that are not catalog entities: `tools/` holds tooling container images,
and `docs/` holds documentation bundles. These names are reserved so that no
future entity kind can lowercase into a collision with them — no entity kind is
named `tool` or `docs`, and none may be introduced.

### Searchable manifest annotations

Every publish stamps a small set of searchable annotations onto the artifact's
OCI manifest so a registry index or a catalog browser can filter artifacts by
their catalog metadata without fetching and parsing each entity body. Every
entity carries its human-readable description plus its catalog category and
kind; a Plugin additionally carries its socket type and the capabilities it
serves. `aggrega registry update` reads these annotations back into a local
searchable index — the deterministic, offline-after-refresh index a later
search consults.
