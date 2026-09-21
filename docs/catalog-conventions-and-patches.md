# Aggrega Catalog Conventions

> This document is the authoritative reference for catalog entity naming,
> directory structure, and YAML formatting. All catalog contributions
> (human or AI-generated) must follow these conventions.

## 1. Directory Structure

URI segments map 1:1 to filesystem path segments, and the version is a segment
like any other. The compiler resolves `type: core/datastore/mariadb:1.0.0` to
`component/core/datastore/mariadb/1.0.0/component.yaml`.

```text
aggrega-catalog/
├── component/{publisher}/{category}/{name}/{version}/component.yaml
├── feature/{publisher}/{name}/{version}/feature.yaml
├── recipe/{provider}/{name}/{version}/recipe.yaml
├── feature-recipe/{provider}/{name}/{version}/recipe.yaml
├── aggregate/{publisher}/{name}/{version}/aggregate.yaml
├── plugin/{pluginType}/{name}/{version}/plugin.yaml
├── schemalibrary/{name}/{version}/library.yaml
├── mappinglibrary/{name}/{version}/library.yaml
├── workloadlibrary/{name}/{version}/library.yaml
└── artifactslibrary/{name}/{version}/library.yaml
```

The `{version}` segment is mandatory on every kind; see "Per-version directory
layout" below for the rule it follows and the per-kind filename it ends in.

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
| `ai-agent` | AI agent frameworks, platforms, and patterns | worker, server, stateful-server, task, resource | populated |
| `ai-model` | Model providers and inference runtimes | server, resource | populated |
| `ai-tool` | Tools agents invoke | function, server, stateful-server, resource | populated |
| `ai-pipeline` | Orchestrators that run a multi-step job | server | populated |
| `datastore` | Persistent datastores (relational, vector, document, graph, KV) | stateful-server, server | populated |
| `gateway` | API and AI gateways | server | populated |
| `mesh` | Service meshes | server | created when the first entity lands |
| `network` | Network primitives | server, resource | created when the first entity lands |
| `messaging` | Event buses, queues, streams, the realtime media services that carry voice and video between participants, and the external carriers a message leaves the Release through | stateful-server, server, resource | populated |
| `storage` | Object/file storage, managed cloud resources | resource, server | populated |
| `compute` | Generic compute primitives, plus the control planes an event-driven realization depends on | server, worker, task, function | populated |
| `observability` | Telemetry, tracing, monitoring | varies | populated |
| `security` | Security and compliance components | varies | populated |
| `bigdata` | Large-scale data processing | varies | created when the first entity lands |
| `devtool` | Developer tooling | varies | populated |

The ontology column tracks the shelf. For a populated category it lists exactly
the `component.aggrega.ai/type` values its entities carry — every value listed
has an entity carrying it, and every entity's value is listed — so a selector
written from this column always has a target. For a category with no entity yet
the column states what the shelf is expected to hold, because there are no
members for it to match.

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
- **Axis 3 — capability labels** (`<role>.aggrega.ai/<dimension>`):
  e.g. `agent.aggrega.ai/autonomy`, `model.aggrega.ai/capability`,
  `tool.aggrega.ai/impact`, `gateway.aggrega.ai/intelligence`,
  `datastore.aggrega.ai/engine`, `pipeline.aggrega.ai/mode`. These carry
  the behavioral subsets selectors and policies discriminate on. Most are
  per-category, but `<role>` names the **concern** rather than the category
  where several categories share one: `dataplane.aggrega.ai/<dimension>` names
  a position on the traffic path, so a proxy, an ingress gateway and a service
  mesh describe themselves in one vocabulary.

Multi-membership is expressed through capability labels, never a
multi-valued category: an entity is `category: datastore` plus whatever
`datastore.aggrega.ai/engine` value its own product identity carries,
discoverable from both axes. A component carries an engine label on its base
where the product's identity is that engine, as `core/datastore/qdrant` carries
`vector` and `core/datastore/redis` carries `kv`. A capability whose truth
depends on what the Aggregate declares carries no label anywhere in the
catalog — it is injected at compile time by the governance socket's
`label-transform` role, which reads the developer's declared `values`.
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

- **`self-hosted`** — the Release runs the compute itself, as containers in
  its own cluster. The operator owns the process lifecycle.
- **`managed`** — the Release consumes a managed service it does not run:
  a managed instance in the operator's own cloud account, or a third-party
  managed / SaaS API. The provider owns the process lifecycle; the Release
  holds a contract and credentials.
- **`external`** — the Release references a pre-existing resource it neither
  provisions nor operates. The resource's lifecycle sits entirely outside the
  Release; the Recipe emits only the wiring to reach it.

**Where the value lives — hosting is a static identity label.** `hosting` is a
component identity label (`metadata.labels`): its value is a property of the
component, fixed by the entity rather than by any one Release. Which value a
component carries depends on whether the trait is invariant across the
component's Recipes:

- A component realized by Recipes that **all share one hosting posture** carries
  that single value — the component *is* one posture by identity, fixed the way
  `component.aggrega.ai/type` is fixed. Each standard-library AI model is exactly
  one value (a self-run server, or a managed API); the label states that identity.
- A **unified component whose Recipes span more than one posture** carries the
  value **`mixed`** — for example a datastore realized self-hosted by its Helm
  and Compose Recipes and managed by its Terraform/CloudFormation RDS Recipes.
  `mixed` is the honest identity value for a multi-posture component: no single
  posture *is* its identity, and the actual posture of a Release follows the
  Recipe the Manifest selects rather than any stamped trait. The component stays
  unified (one component, several Recipes); it is not split per posture.

`mixed` generalizes to any `<scope>.aggrega.ai/` identity label on a unified
component whose Recipes span multiple values of that axis: rather than dropping
the label or splitting the component, carry `mixed` to state honestly that the
axis is realization-dependent.

**The convention on output labels binds the literal block only.** A Recipe has
two ways to put a label on the output it renders, and this convention reaches
one of them. It says: do not type `component.aggrega.ai/hosting` as a literal
entry in `spec.outputLabels:`, the block whose keys *and values* a Recipe author
writes in place. It does not reach `spec.outputComponentLabels:`, the block that
names a component label key and stamps the value the component itself declares.
Promoting `component.aggrega.ai/hosting` through that block is supported, and it
is how a Recipe puts a component's posture onto the objects it renders.

**The asymmetry has a reason worth stating, because the rule otherwise reads as
an inconsistency.** A literal entry lets a Recipe author type a value the
component's own identity contradicts — stamping one posture on a node whose
Component declares another, and telling a downstream reader something the graph
does not say. A promoted entry copies *by reference*: the value is read from the
component every time output is rendered, so there is no second copy that can
drift from the first. A Recipe that wants the posture of its *own* realization
on the emitted objects declares an output-label key it owns for that realization
trait, which is a separate surface from the component's identity key.

Like the value set, this is convention rather than enforcement. The
reserved-namespace rule on output labels refuses the bare `aggrega.ai/` and
`app.kubernetes.io/` roots — in the literal block and the promoted block
alike — and `component.aggrega.ai/` identity keys sit outside those roots. So
nothing stops a Recipe from typing the identity label literally except the
author not doing it.

### The `dataplane.aggrega.ai/` capability family

`dataplane.aggrega.ai/<dimension>` records what a component standing in the
traffic path is able to do to the traffic passing through it. Like `hosting` it
is a **cross-cutter**, but on a different axis: the same dimensions describe a
reverse proxy, an ingress gateway, an AI gateway and a service mesh, so the
prefix names a **position on the traffic path** rather than any one component
kind. Naming it after the kind that carried it first would oblige every later
kind to restate the vocabulary under its own prefix, leaving one capability with
several names and no selector able to span them.

The dimensions and their value sets:

| Dimension | Values | What the value asserts |
| --- | --- | --- |
| `request-mirroring` | `full-rate`, `sampled` | The carrier can copy a matching request to a second destination and discard that destination's response. `full-rate` copies every matching request and offers no setting that narrows it; `sampled` offers a settable share, so a carrier that can sample carries `sampled` and not both. |
| `caller-identity` | `client-certificate`, `injected-header` | The component can convey the original caller's identity to the service behind it, and the value names which mechanism does it. `client-certificate`: the client's own TLS certificate details travel to the backend. `injected-header`: the component authenticates the caller itself and composes headers naming them, which travel upstream on the forwarded request. |
| `prompt-guard` | `pattern-list` | The component can inspect the chat and completion payload it is routing and refuse a request on its content. `pattern-list` names the fidelity: the match is against patterns supplied in its configuration. The dimension is deliberately narrower than content inspection in general — a component here reads the model payload it already parses to route, and not one of them inspects an arbitrary HTTP body. |
| `upstream-tls` | `trust-anchor` | The carrier can require the service it forwards to present a certificate chaining to a trust anchor the Release supplies. |

Three rules bind the family, and each has already been got wrong once:

- **The fidelity rides in the value, not in a second key.** Two carriers that both
  mirror requests can still differ in the way a Feature cares about, so a Feature
  selects the fidelity it needs and is refused early and by name when the carrier
  cannot deliver it.
- **A value asserts a capability, never a configured state.** The two read alike
  and only the first is a property of the product. `core/gateway/nginx` carries
  `upstream-tls: trust-anchor` although the verification it names is off until an
  operator turns it on, because the label is what a selector reads *before*
  anything is configured. Each carrier's label comment says this in its own
  terms, so a reader of the entity is not left to infer it.
- **A value is declared only once a component carries it, and each value is
  established against the product's own reference documentation.** A value
  nothing carries is worse than an absent one — a selector naming it parses,
  matches nothing, and reports nothing — so each is added in the same act as the
  first component to carry it. One fidelity the field does implement stays
  absent, and no longer for want of a product: an upstream certificate pinned by
  key rather than verified against an anchor. 🔴 **One gateway in the catalog can
  pin, and the ground for keeping it off this family is what a second value here
  would assert, not scarcity — a pin says which key a certificate must BE, where
  every value on this family says what one must SAY.** A certificate-name
  assertion and a named trust anchor are neither of them pins. While one product
  carries the capability it stays a dial on that Component's own surface; a
  shared value here is the thing to revisit if a second product gains it.

Carriers today: `core/gateway/nginx` (`request-mirroring: full-rate`,
`upstream-tls: trust-anchor`), `core/gateway/contour` (`request-mirroring:
sampled`, `caller-identity: client-certificate`, `upstream-tls: trust-anchor`),
`core/gateway/kong` (`upstream-tls: trust-anchor`), `core/gateway/litellm`
(`caller-identity: injected-header`, `prompt-guard: pattern-list`,
`upstream-tls: trust-anchor`). Three of the four carry no
`gateway.aggrega.ai/intelligence` value and the fourth carries `semantic` — and
that mixture is the separation working rather than an exception to it. The
intelligence label names a **product tier** — whether the router parses the
request body — while this family names **capabilities**, so the two answer
different questions and a component may honestly carry both. What a component's
tier value never tells a reader is which of these capabilities it has: the AI
gateway carries three of them, and no amount of reading its tier would say so.

### The `component.aggrega.ai/upstream-licensing` label

`component.aggrega.ai/upstream-licensing` records the licensing class of the
**product or service the Component wraps** — the third-party software a
Release actually runs or calls. Like `hosting` it is a **cross-cutter**: the
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
  licence, and that licence covers the artifact a Release runs.
- **`open-core`** — the wrapped product's core is published under an
  OSI-approved licence while a named subtree or edition is not, so which terms
  apply depends on which part a Release uses.
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
covering third-party software a Release runs or calls, and every value in the
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
- **A service a Release merely calls is not a pinned artifact.** Where the
  entity pins nothing and its Recipes only wire a Release to a service the
  reader contracts for directly — the reference realization of a hosted API — the
  test does not apply, and the entity is admitted whatever the service's own
  terms are. That relationship is between the user and the provider; the catalog
  neither distributes nor resells it.
- **An artifact the Release supplies is not pinned either.** A Recipe whose
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

### Specialization, sibling or fleet — which shape a product takes

A product that shares a protocol with an entity already in the catalog is
exactly when an author reaches for `extends`, and often should not. Three
shapes are available, and the choice is settled by asking about the **pillars**
— `values`, `infra` and `provides` — rather than by how much protocol the two
products share.

**A specialization — use `extends`.** An extending Component composes
structure: `metadata.labels`, `metadata.annotations`, `spec.featuresSchema`,
`spec.inject`, `spec.usesSchema` and `spec.assertions`. The pillars do not
compose. The child writes the literal marker `schema: inherited` and authors no
pillar content, so its contract is its base's identically — which is what lets
the base's Recipes serve it with no Recipe of its own.

> **The question to answer: do the base's pillar semantics still hold word for
> word** — every description, every default, every unit — for the artifact the
> child would run?

Only if they do is the product a specialization. A child inherits the base's
pillar *text* unaltered, so a knob that would mean something different on the
child's artifact makes the child's published contract a misdescription that no
build can catch. What a specialization adds is scope a selector or a policy
reads: an audit tier, a data zone, a governance contact, a socket narrower than
the base's. `example/gateway/nginx-reviewed` is the shipped shape — it extends
`core/gateway/nginx`, adds a reviewed-tier label and a data-zone label, adds
governance annotations, and adds one socket whose selector admits only targets
carrying the reviewed-tier label. Two authoring rules follow:

- **The pillar ban is enforced when the document loads**, not by convention. An
  extending Component that authors pillar content under `spec.schema` is
  refused, and one that omits `spec.schema` altogether is refused by a
  different message on the same constraint. There is no silent case.
- **The Manifest mapping line is still required.** Recipe selection is by exact
  mapping key, so a specialization needs its own `mappings.components.type`
  entry even though it needs no Recipe. Its base's entry does not cover it.

**A different product speaking the same protocol — author a sibling entity.**
Its identity is not "the base plus something", so inheritance would misdescribe
it, however drop-in the replacement is at the wire. `core/datastore/valkey`
sits beside `core/datastore/redis` rather than extending it: each is its own
product with its own pillars, and both are reachable by a consumer selecting on
`datastore.aggrega.ai/engine: kv`.

**A product needing several cooperating roles — author a fleet.** No amount of
shared protocol makes several roles one component. Each role is its own entity
with its own type, its own pillars and its own Recipe, wired together by the
edges an Aggregate declares. The agent-workspace platform under
`core/ai-agent/agenta-*` is the shipped shape — a control-plane API, a console,
queue and stream workers, a schema-migration step and a scheduler, authored as
separate components rather than one.

A fleet member may be authored with a required `infra` value for the image it
runs and no catalog-authored default, exactly as a standalone entity may: the
admission test above treats an artifact the Release supplies as one the
catalog does not pin, and belonging to a fleet changes nothing about that. It is
the honest shape for an upstream that publishes its software as a language
package rather than as a container image, where there is no reference to pin.
Declaring the value required is what keeps the omission loud — a build that
reaches such a component with the value unset halts naming the key, and renders
nothing.

What the shape costs a reader is discovery, and disclosure is the convention
that answers it. A member authored this way says in its own
`metadata.description` which input the catalog does not supply, why there is
none to pin, and that nothing renders until the Release sets it; an Aggregate
composing such a member says the same in its own description, so a reader
choosing the module meets the constraint while reading rather than at the halt.
Nothing checks this and an author may leave it out — the convention is here
because the halt names the key that is missing and not the reason the catalog
left it empty.

### Recipe/FeatureRecipe Provider Segment

Domain 3 entities use the execution engine as the first path segment:
`helm`, `terraform`, `cloudformation`, `compose`, `eval`.

### Per-version directory layout

**Every** publishable kind lives in a per-version subdirectory — run
`aggrega push --list-kinds` for the kinds the installed binary publishes:

```text
<kind>/<publisher-or-provider>/.../<name>/<version>/<entity>.yaml
```

The `<version>` directory segment MUST equal the entity's `metadata.version` on
every kind, Plugin included. The publish-time bundler rejects a mismatch
(`ErrEntityVersionPathMismatch`) for the kinds it bundles. A Plugin publishes by a
route of its own — its entity and its `.wasm` are packed into one manifest, tagged
by `metadata.version`, at the repository location its socket coordinate derives —
and that route reads the version from the entity rather than from the directory, so
for Plugin the per-version layout is a catalog convention rather than a
publish-time halt. One published version is one directory, so the source tree holds
every version of an entity side by side rather than relying on git history for
older versions. The `<entity>.yaml` filename is kind-conventional:

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
| FeatureRecipe | `feature-recipe/helm/k8s-dns-resolver/1.0.0/recipe.yaml` | `k8s-dns-resolver` |

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

When a component's name segment would repeat the category, strip the suffix. The
filename is always `component.yaml`, so what shortens is the segment the name
mirrors, not the file:

- `anthropic-agent/` in `ai-agent/` → `anthropic/` (name: `core/ai-agent/anthropic`)
- `openai-model/` in `ai-model/` → `openai/` (name: `core/ai-model/openai`)

### Naming a second realization of one component

A Component may be realized by several Recipes on the **same** provider, with the
Manifest choosing between them per Release. A chart or controller realization
is added beside an existing one rather than replacing it, so each Recipe needs a
`metadata.name` of its own and a reader has to be able to tell at a glance which
realization each name denotes.

(Recipes on *different* providers need none of this: `recipe/helm/mariadb` and
`recipe/compose/mariadb` share a name and are told apart by the provider segment
of their path. The rule below is for two names that would otherwise collide.)

**The bare component name belongs to the realization that stands the component up
with nothing already in place** — nothing installed in the cluster, no resource
already existing outside the Release, nothing that must be fetched. That is the
realization a reader can deploy anywhere, so it carries the plain name:
`recipe/helm/mariadb`, `recipe/helm/postgres`, `recipe/helm/kafka`.

**Every other realization is named `<bare name>-<distinguisher>`, and the
distinguisher names what realizes it.** It is read off the realization itself, not
invented for the name:

| What distinguishes the realization | Distinguisher | Example |
| --- | --- | --- |
| The controller whose custom resource it emits | the controller's own project name | `kafka-strimzi`, `vllm-kserve`, `vllm-kubeai`, `function-keda`, `function-knative` |
| The operator-managed instance it reconciles, where the controller carries the product's own name and repeating that would say nothing | what that instance is | `rabbitmq-cluster`, `mariadb-cluster` |
| The managed product it provisions | the product's name | `mariadb-rds`, `mysql-rds` |
| What stands between the application and the component | that mechanism | `openai-gateway` |
| The artifact the Recipe wraps | the artifact kind | `mariadb-rds-module` |
| That the resource lives outside the Release | `external` | `postgres-external` |

**Where no realization stands the component up with nothing already in place, none
of them takes the bare name and every one carries a distinguisher.**
`core/compute/function` is realized only through a scaling control plane, so its
Recipes are `function-keda` and `function-knative` and there is no plain
`function` to be had.

#### What a distinguisher must not be

A distinguisher describes **one** realization. It never ranks a realization
against its siblings, and three shapes that do will be proposed:

- **A version marker** — `-v2`, `-2`, `-next`. It records when the name was chosen
  rather than anything about the realization, and it has nowhere to go for a third
  realization that is neither earlier nor later but simply different. The version
  axis already has two homes of its own, `metadata.version` and the version
  directory segment, and a name that duplicates them can disagree with them.
- **A quality judgement** — `-better`, `-proper`, `-production`. Which realization
  is right is a property of the target cluster rather than of the Recipe: the
  synthesis realization is the correct choice where no control plane runs, and the
  controller-driven one is correct where one does. A name that settles the question
  in advance is wrong for every cluster the other answer suits, and it is wrong
  persuasively, because a reader has no reason to doubt a name.
- **A temporal marker** — `-new`, `-legacy`, `-old`. It is accurate only until the
  next realization is authored, and by then it is a name Manifests have been
  written against, so correcting it is a rename reaching every Manifest a reader
  has written.

A distinguisher taken from what realizes the component avoids all three, because
it states a fact about that one realization which stays true however many
siblings arrive beside it.

#### Say which realization to reach for

Two realizations offered with no guidance is a coin flip presented as a choice. So
each one states, in its own `metadata.description`, which realization to reach for
**and the condition that decides it** — a condition a reader can check against
their own cluster, never a bare preference.

The conditions that actually decide it are concrete: whether the control plane a
realization needs is already installed, whether a chart repository is reachable
from the build, whether the build has to complete with nothing fetched, whether
the resource already exists outside the Release, whether a credential must be
kept out of the application. `recipe/helm/mariadb-cluster` states it in one
sentence — *reach for this realization where the control plane is already in
place; reach for the synthesis recipe where it is not* — and
`recipe/helm/mariadb` states the same choice from its own side, naming the
conditions that select it.

**The sentence is stated on the Component as well as on each Recipe**, because a
reader arrives from either direction: someone choosing a component reads the
Component's description and needs to know the choice exists, and someone already
holding a Recipe needs to know what the alternative is and when it wins. The
Component's sentence names every realization; each Recipe's names itself and its
alternative.

### Key casing: two registers with two owners

An entity's YAML carries two kinds of key, and they follow different rules
because different people choose them.

**The product owns one register, and it is camelCase.** `apiVersion`, `kind`,
`metadata` and `spec`, the structural keys underneath them — `appliesTo`,
`conflictsWith`, `executionScope`, `usesSchema`, `featuresSchema`,
`valueSchema`, `infraSchema`, `valuesMapping` — and the schema vocabulary
written inside a pillar — `type`, `description`, `default`, `required`, `enum`,
`min`, `max`, `additionalProperties`, `$ref` — are all spelled by the product. An
author writes each as the product spells it, and restyles none of them.

**The catalog author owns the other register, and it is snake_case.** The data
keys declared inside `values:`, `infra:`, `provides:` and `parameters:`, and the
socket and slot names declared under `usesSchema:` and `featuresSchema:`, are the
author's own vocabulary: `engine_version`, `max_attempts`, `retention_days`,
`queue_depth_hint`, `app_user`.

**Keeping the two apart is the point of the rule.** A reader meeting
`engine_version` beside `executionScope` can tell which word this catalog
invented and which one the product defines, and an author reading a halt that
names a key knows immediately which surface to look at. Spelling the authored
keys camelCase would file them under the product's register and lose that
distinction — which is why the direction is snake_case for authored keys rather
than camelCase everywhere.

Two boundaries on the rule:

- **It binds the key, never the value.** A value's spelling follows whatever the
  thing it configures accepts, which is why one `log_level` key carries whatever
  level names its own product understands.
- **A library's `metadata.name` is outside it.** That name is an identity a
  consumer references rather than a data key, and it follows its own rule — see
  "Library-kind names are bare PascalCase" above.

### Prefer the compact constraint keyword

Write `min:` and `max:` rather than `minimum:` and `maximum:`.

The compact keyword follows the node's declared `type:` — `min:` is a numeric
bound on an `integer` or a `number`, a length bound on a `string`, and an
item-count bound on an `array` — so one spelling covers every type and keeps
meaning the right thing if the type changes. `minimum:` and `maximum:` are JSON
Schema's own keywords, carried through as authored; they are accepted, and on a
field declaring `type: integer` they express the same bound.

What they do not do is mark the node. A compact keyword is part of what
identifies a node as a compact-form leaf, so a node carrying only JSON Schema's
spellings is classified by whatever else it holds. Keeping to the compact
spelling keeps that question from arising, and keeps one field from carrying two
registers at once: `min:` beside `maximum:` on a single field reads as two
conventions in one place.

Where the compact form has no equivalent — `exclusiveMinimum:`, `multipleOf:`,
`uniqueItems:` — write the JSON Schema keyword, which is what it is there for.

### Differences that are not divergences

A pass that unifies key names across the catalog meets spellings that look
inconsistent and are not. Each of the following is a real distinction, and
flattening it changes what an entity means — usually with no build reporting it,
because the compiler pipes whatever string it is handed and validates nothing
about what the string means.

- **A level or mode vocabulary follows the wrapped product.** The key is uniform
  across the catalog; the accepted values are not, because each component's
  product accepts its own set. Normalising the values makes the compiler pipe a
  string the target rejects: the build succeeds and the container fails to start.
- **A qualified port name is a different port.** Where a component listens on
  several, the unqualified `port` is its primary and each qualified name is
  another physical port. Collapsing them onto one key merges two listeners.
- **A qualified image name is a different image.** A component that genuinely
  deploys several images declares several image keys.
- **A qualified account name is a different account.** `user` and `app_user` on
  one component are two accounts, not two spellings of one.
- **Label values are kebab-case while enum members are snake_case.** Two
  registers with two rules, and they only look like a collision when a label
  block and a pillar are read side by side. Label values are kebab-case across
  the catalog.
- **The same key in `values` and in `provides` is the string pipe working as
  intended.** A component that accepts a value and also publishes one names both
  for what they are; renaming either side to disambiguate makes the contract
  harder to read, not easier.
- **One word in two pillars can carry two directions.** `endpoint` under `infra`
  is an address supplied to a component; under `provides` it is one the component
  publishes. The pillar carries the direction, so the word does not have to.
- **`required:` has two authored forms and both are correct.** `required: true`
  on a field marks that one field; `required: [a, b]` beside a `properties:` map
  names several at once. They are the same contract written at two scopes, not a
  drift.
- **`source:` has two authored forms and both are correct.** A scalar is a path,
  relative to the Recipe file, to material the entity ships beside itself — a
  chart directory, or a single fragment. A map is a reference to a chart the
  entity does not ship, spelled `kind`, `url` and `version`, and carrying `chart`
  as well where the URL names a repository rather than the chart inside it. The
  two describe different origins, so there is no one form to converge them onto.
- **Two node names inside one Aggregate that read as variants of one word are
  two different nodes.** A stack that composes an object store together with the
  gateway reading from it names each separately, and merging the pair merges two
  workloads. The same word may also name the socket on the edge into a node —
  that is the edge's local alias, not a second spelling of the node.

Before renaming a key for consistency, establish what the two spellings denote.
Where they denote the same thing, converge them; where they denote different
things, the difference is the information.

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

### Metadata key order

Inside `metadata:`, the keys an entity carries are authored in this order:

```yaml
metadata:
  name: core/datastore/redis
  version: 1.0.0
  license: AGPL-3.0
  description: >
    A Redis in-memory key-value cache, speaking the Redis wire protocol.
  labels:
    component.aggrega.ai/type: server
    component.aggrega.ai/category: datastore
  maintainers:
    - name: Massimiliano Ferrero
      email: m.ferrero@cognitio.it
```

Identity first, then the terms the described software is published under, then
the prose, then the label set, then who answers for the entity. A key the entity
does not carry is simply absent: the convention fixes the relative order of the
keys that are present rather than which keys an entity must have, and keys
outside this list — `annotations`, for instance — it does not order.

Two things follow, and the second is the one worth knowing.

- **`license` sits above `description`, directly under `version`.** That keeps it
  within a couple of lines of the `# SPDX-License-Identifier:` header above, so
  the two surfaces that each name a licence — the file's own terms and the
  wrapped product's — are read together and told apart, instead of meeting a
  paragraph of prose in between.
- **Nothing enforces the order and nothing reads it.** YAML mapping order carries
  no meaning to the compiler, so a `metadata:` block written in any order parses
  to the same entity and renders byte-identical output. This is a reading
  convention, and what it buys is that a scan across a shelf of entities finds the
  same key in the same place every time.

Being a reading convention, reordering an existing entity is never urgent — and
it is not free either. It moves the file's bytes and therefore its content
digest, with the consumer cost described under "What a byte-level edit costs a
consumer" below. Carry a reorder along with a change the entity is being
published for anyway.

### Quoting follows the declared type

The quoting rules below are one rule applied to several surfaces: **write each value
in the spelling YAML reads as the type the schema declares.** YAML types a bare
scalar by how it is spelled, so the question is never taste — it is whether the
spelling and the declared type agree.

Two directions, and both are real:

- Where the schema declares a **string** and the value's spelling would make YAML
  read it as a number, a boolean or a date, the value is **quoted**. Most catalog
  values are words, which YAML already reads as strings, so most of them are written
  bare — that is why the two rules below say "unquoted".
- Where the schema declares a **number**, quoting is the error in the other
  direction. A container port is an integer, so `p: 5432` is right and `p: "5432"`
  is refused when the workload is parsed.

A value assembled by a template is judged the same way, on what it renders to rather
than on how it is written: the quotes go around the whole action, because YAML sees
only the rendered text.

### Label values: unquoted

Label values are declared as strings (`additionalProperties: { "type": "string" }`
on `metadata.labels`), and the standard library's values are words, so they need no
quotes. A label value spelled as a number or a boolean does need them — bare, it is
refused when the entity loads.

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

### Container variables: quoted

A container's `variables` map is the surface where the previous two rules mislead if
they are carried across unexamined. The Workload schema declares

```json
"variables": { "type": "object", "additionalProperties": { "type": "string" } }
```

on `$defs.container.properties.variables` — so **every value in the map is a
string**, and environment values are exactly the ones authors spell as numbers and
booleans. Quote them all:

```yaml
# CORRECT
variables:
  POSTGRES_USER: appuser
  PGMAXCONN: "200"
  DEBUG: "true"

# WRONG — YAML reads these as an integer and a boolean
variables:
  PGMAXCONN: 200
  DEBUG: true
```

The build halts at workload validation and names the contract:

```text
.containers.main.variables.PGMAXCONN: /$defs/container: type: 200 has type "integer", want "string"
```

The templated form is the one most easily missed, because what YAML reads is the
rendered text rather than the template. Quote the whole action:

```yaml
# CORRECT
variables:
  PGPORT: "{{ .infra.port }}"

# WRONG — renders to `PGPORT: 5432`, which YAML reads as an integer
variables:
  PGPORT: {{ .infra.port }}
```

### Other string-typed values inside `workload:`

The same contract governs every string-typed key in the Workload schema, which makes
the rule one line: **a templated value under a string-typed key is quoted.** The
quotes go around the whole action, because YAML reads the rendered text rather than
the template.

Quote it even when today's default renders as a word. The failure is invisible while
the defaults are read and appears the moment an operator supplies a value spelled as
a number — and that operator did nothing wrong, because the value is legitimate and
the key is a string. An unquoted template turns a correctly authored Release into a
failed build. A Recipe writing

```yaml
resources:
  requests:
    cpu: {{ .infra.compute.cpu }}
```

renders `cpu: 250m` — a string — for the usual default, and `cpu: 2` for an operator
who asked for two whole cores, which halts. Quote the action so both spellings are
strings:

```yaml
resources:
  requests:
    cpu: "{{ .infra.compute.cpu }}"
```

An extended resource quantity is the same case, which is why the schema's own example
spells it `'nvidia.com/gpu': '1'`.

**A sequence element is the same case and is the one most easily missed, because it
carries no key to read the type from.** `command` and `args` entries are string-typed,
so a templated element is quoted like any other value:

```yaml
# CORRECT
args:
  - "--listen=0.0.0.0:{{ .infra.http_port }}"

# WRONG — the rendered element is read by its spelling, not by its position
args:
  - --listen=0.0.0.0:{{ .infra.http_port }}
```

**Settle which keys are string-typed from the schema rather than from a list.** The
ones a Recipe hits most often are `containers.*.image`, `containers.*.variables.*`,
`resources.{requests,limits}.{cpu,memory}` and extended resource quantities,
`volumes.*.persistent.{size,class}`, `volumes.*.persistentTemplate.{size,class}`,
`volumes.*.ephemeral.sizeLimit`, `volumes.*.configmap.source`, `volumeMounts.*.path`,
`scheduling.nodeSelector.*`, `runtimeClassName` and `imagePullSecrets` — but that is
where the rule bites, not where it stops. `aggrega get-schema workload` prints the
declared type of every key and settles any key in doubt.

Container and service **ports** are the inverse: they are declared as integers, so
they are written bare and a quoted port is refused.

**Quoting costs nothing for a value that already worked.** A plain YAML scalar that
resolves to a string and the same text in quotes parse to the same string, so a
template already rendering a word is unaffected and the quotes are what keep a
numeric-looking one working. Where a template can render *nothing*, guard the whole
line with `{{- with … }}` instead of leaving it to emit an empty quoted value: an
empty string is a value, and an absent key is not.

### Maintainer block

```yaml
maintainers:
  - name: Massimiliano Ferrero
    email: m.ferrero@cognitio.it
```

### Comment syntax

Use `#` for comments throughout — every catalog file is YAML, and YAML's comment character is `#`. Schema bodies live under `spec.schema:` as JSON Schema 2020-12 declarations (compact form by default; full JSON Schema YAML via `$jsonschema:` when needed), so the inner content is YAML too and follows the same `#` convention.

### What a byte-level edit costs a consumer

An entity's content digest is the SHA-256 of the file's **raw bytes**. Nothing is
parsed, normalised or re-serialised first, which is what lets anything that can
compute a SHA-256 verify a pin: `sha256sum component.yaml` prints the same hex the
lockfile records, with no Aggrega-specific normalisation to agree on beforehand.

The consequence is that the digest tracks the bytes exactly — including across an
edit YAML defines as producing the identical parsed value. Re-wrapping a folded
scalar, rewrapping a comment and adding trailing whitespace each move the digest
while changing nothing the compiler reads.

That digest is what a consumer's `release.lock` pins. When it moves, every lockfile
holding the old one is out of date, and the next build halts instead of rendering:

```text
lockfile: out of date; it no longer matches the current catalog: entity
"core/datastore/mariadb" changed: lockfile=(1.0.0,sha256:5c2ea291…)
current=(1.0.0,sha256:2392e621…)
```

The halt names the refresh that clears it. Once the consumer's lockfile is
refreshed the build proceeds and renders output byte-identical to what the old pin
produced — the rendered output does not change, because the parsed entity did not.
`aggrega pull --verify` reports the same drift without writing, for a consumer that
wants to know before it builds.

So a tidy-up pass over catalog prose is a publishing event for everyone pinning the
entities it touches, **from a diff in which nothing observable changed** — the
author sees a whitespace change and the consumer sees a halted build. That
invisibility is the part worth knowing, because the diff itself carries no signal
of it.

Nothing prevents a reflow, and prose that has drifted out of measure is worth
fixing. What the cost argues for is timing: carry a reflow along with a change the
entity is being published for anyway, rather than spending every consumer's re-pull
on formatting alone.

What publishing such an edit then requires is a separate rule — see "A published
version is final" below.

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

The compact form (about 15 keywords) covers the common case in a fraction of the line count of full JSON Schema; the `$jsonschema:` escape hatch admits full JSON Schema 2020-12 at any node boundary when the compact form does not carry the needed keyword. See [`aggrega-docs/language-reference/vocabulary/compact-form-authoring.md`](https://github.com/aggrega-ai/aggrega-docs/blob/main/language-reference/vocabulary/compact-form-authoring.md) for the keyword vocabulary and [`aggrega-docs/language-reference/entities/component.md`](https://github.com/aggrega-ai/aggrega-docs/blob/main/language-reference/entities/component.md) for the per-pillar authoring framing.

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
# schemalibrary/base-components/1.0.0/library.yaml — the library
apiVersion: aggrega.ai/v1alpha1
kind: SchemaLibrary
metadata:
  name: BaseComponents
spec:
  schemas:
    BaseComponentParameter:
      type: object
      properties:
        display_name: { type: string }
        description: { type: string }
```

```yaml
# component/core/datastore/mariadb/1.0.0/component.yaml — the consumer
spec:
  schema:
    values:
      $ref: "BaseComponents#/schemas/BaseComponentParameter"
      properties:
        database_name: { type: string, required: true }
```

A MappingLibrary entry carries one or more named Go-template fragments under `spec.mappings:`. A consumer Recipe imports the entry inside `valuesMapping:`:

```yaml
# recipe/helm/mariadb/1.0.0/recipe.yaml — the consumer
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

### Sourced mode is the default wherever a good chart exists

A helm Recipe takes one of two shapes. A **sourced** Recipe names an upstream
chart in `source:` and maps the Component's values into that chart's own value
surface. A **synthesized** Recipe carries an authored `workload:` block the
provider assembles into resources directly.

**Point the Recipe at the chart wherever an official — or good, complete and
maintained — chart exists, and map values into it.** The upstream chart is where
the product's own maintainers encode what the product needs: the resources it
expects, the RBAC it runs under, the ordering its migrations require, the fields
its custom resources carry. Re-deriving that by hand produces a realization that
starts out equivalent and drifts every time the product moves, and the drift is
invisible because the render still succeeds.

**Synthesize when no such chart exists** — and say which of the three it failed:

- **Not official** — no chart published by the product's own maintainers, and no
  community chart with a maintainer who answers for it.
- **Not complete** — the chart covers part of the product, or omits a surface the
  Component needs to expose.
- **Not maintained** — the chart lags the product it packages, or its latest
  version predates the release the Component targets.

An unofficial chart that is complete and maintained qualifies; an official chart
that is unmaintained does not. Establish this per product against the chart
itself rather than assuming it, and record the finding in the Recipe's
`description` where a reader meets the choice.

Two obligations follow a sourced Recipe:

- **Pin the images the chart runs.** A chart that leaves an image tag to its own
  default makes the render irreproducible across pulls, which is the whole point
  of pinning the chart. Set each tag explicitly in the value mapping and offer an
  `infra.overrides.<name>_image` escape that replaces the block.
- **Pin the generated resource names.** Bind the chart's `fullnameOverride` to
  `.context.instance_id` so a Service the Component publishes through `provides`
  is named something the render actually emits. A `provides.host` that names no
  emitted Service is a broken contract that no gate catches, because both sides
  render successfully.

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
Release has. The form that binds the slot without reintroducing a second
lifecycle is `core/generated-secret`, the credential Feature that states the
target engine owns the material. Its FeatureRecipes are pure wiring: each
declares only the capability it binds to and the Feature it implements, and
renders nothing. A Release that binds the slot this way emits output
byte-identical to the same Release with no attachment at all — the slot is
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
[`recipe/terraform/mariadb-rds/1.0.0/recipe.yaml`](../aggrega-catalog/recipe/terraform/mariadb-rds/1.0.0/recipe.yaml)
and
[`recipe/cloudformation/mariadb-rds/1.0.0/recipe.yaml`](../aggrega-catalog/recipe/cloudformation/mariadb-rds/1.0.0/recipe.yaml).
This guidance applies to managed services only — Recipes targeting
self-managed datastores (Helm Bitnami chart, Compose container) still use the
credential FeatureRecipe path because no upstream managed-secret flag exists
for those targets.

### Optional credential slots for self-managed datastores

A self-managed datastore Component declares its password as an **optional**
credential slot in `spec.featuresSchema`, and its Recipes wire that slot
**conditionally** — the credential subsystem when a credential is attached, an
inline development default when none is. This keeps the slot non-breaking: a
Release that attaches no credential still renders and runs, byte-identically
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
[`recipe/helm/postgres/1.0.0/recipe.yaml`](../aggrega-catalog/recipe/helm/postgres/1.0.0/recipe.yaml)
and
[`recipe/compose/postgres/1.0.0/recipe.yaml`](../aggrega-catalog/recipe/compose/postgres/1.0.0/recipe.yaml).

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
[`language-reference/examples/mariadb-bitnami-credential-set/`](https://github.com/aggrega-ai/aggrega-docs/blob/main/language-reference/examples/mariadb-bitnami-credential-set/).

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
[`recipe/helm/postgres/1.0.0/recipe.yaml`](../aggrega-catalog/recipe/helm/postgres/1.0.0/recipe.yaml).

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
the key. Where a mount must instead place a **single** file from the volume
without masking the rest of the target directory, the `volumeMounts` entry
carries `subPath`, whose contract is stated on the generated
[Workload schema reference](https://github.com/aggrega-ai/aggrega-docs/blob/main/language-reference/schema/entities/workload.md).
For a runnable end-to-end walkthrough, see the worked example
[`component/example/compute/gcp-credentialed-service/`](../aggrega-catalog/component/example/compute/gcp-credentialed-service/1.0.0/component.yaml)
and its Recipe
[`recipe/helm/gcp-credentialed-service/`](../aggrega-catalog/recipe/helm/gcp-credentialed-service/1.0.0/recipe.yaml).

### The `workload:` authoring contract

Three rules govern every synthesized Recipe. Each is enforced at load or render
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
so a Release can toggle that component's presence per environment. The
convention: declare a boolean parameter such as `enable_cache` in the Aggregate's
`parameters`, and have the component's presence expression reference it. A
Release then flips the component on or off by fulfilling the parameter,
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
Release through the Manifest's component-type mapping. The consumer's wiring
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
material comes from outside the Release. An optional governance Feature can
ride the same edge to carry policy context for the referenced resource without
coupling it to provisioning.

**Reference is not adoption.** Hosting (`self-hosted | managed | external`) is
the who-operates axis; the resource *lifecycle* — provision → adopt → reference
— is a separate axis. A reference realization (provides-only, emits no compute)
ships with the conventions above. *Adoption* — taking an existing resource under
management so subsequent changes flow through the Release, via the engine's
own take-ownership syntax (Terraform `import` blocks, Crossplane observe-only
management) — is a distinct capability delivered by a FeatureRecipe transform,
not by the hosting label. A referenced resource stays externally owned; an
adopted resource becomes Release-managed.

### Gateway / operator-driven (custom-resource-emitting) Recipes

The production way to run complex software on Kubernetes is often an **operator**:
a controller that reconciles a **custom resource** into running infrastructure
(a message broker becomes a Strimzi `Kafka`; a model-serving path becomes an
Envoy AI Gateway `AIServiceBackend`). A Recipe realizes this by emitting the
custom resource — one more realization of an existing component, selected per
Release through the Manifest's component-type mapping, coexisting with that
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
- **Bundled-deploy** — the Release ships the control plane too. The operator
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
component, selected per Release through the Manifest:

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
or a synthesized StatefulSet with a PersistentVolumeClaim. Splitting a component
or recipe family by stateful-ness is an antipattern — it doubles the catalog and
forces the Aggregate's topology to be re-authored to change an operational setting.

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

Checking a component against that rule means knowing what each target can express.
The `compose` target is the one that most often cannot, so its envelope is stated in
the next section.

### What the `compose` target expresses, and what it does not

**This is the single home for the `compose` target's capability envelope.** A Recipe
documents what *it* does with a value; it does not carry its own account of what the
target can express. Several accounts of one target drift apart, and a reader
comparing two Recipes in the same family then cannot tell which is right — a wrong
account reads exactly as authoritative as a right one.

| Workload construct | What `compose` does with it |
| --- | --- |
| `volumes.<n>.configmap`, mounted by a `volumeMounts` entry | **Realized.** The source becomes a compose `config` carrying the content, delivered as **one file at the mount path**. The mount path is emitted verbatim, so it names a *file*. |
| Several named files mounted as a **directory** | **Not expressible.** One config is one file, and the target performs no key expansion: pointing the mount at a directory path writes a single file at that path. A value shaped as a map of filename to content — bootstrap scripts, a drop-in directory — has no `compose` realization. |
| `volumes.<n>.persistent` | The volume is **created and named**; the declared `size` reaches no emitted byte, and nothing reports it. The target has no volume-size concept. |
| `containers.<n>.resources` | **Realized** as `deploy.resources` — `cpu` as fractional cores, `memory` as an exact byte count. An operator's sizing is honored here, not dropped. |
| `initContainers` | **Realized** as a companion service the main service waits on, through `depends_on` with `service_completed_successfully`. |
| `services.<n>` | A `NodePort` or `LoadBalancer` entry publishes its ports on the host. A `ClusterIP` or `Headless` entry publishes nothing, so a port an operator sets reaches no emitted byte. |
| `replicas` | **Dropped, with a warning** naming it. |
| An attached credential | Arrives on the inject pipe and is delivered as a **literal environment value** in the emitted file. The target has no secret-reference primitive for a `secretKeyRef`-style pointer to resolve, so the material sits in the artifact rather than being pointed at from it. |
| `containers.<n>.lifecycle`, `containers.<n>.envFrom` | **The build halts.** The target has neither primitive, and dropping either silently would change what the Release means. |

Two consequences for a Recipe author:

- **A single configuration file is realizable on this target; a directory of them is
  not.** Where a component exposes both — a raw configuration block and a map of
  bootstrap scripts — the `compose` Recipe can realize the first and cannot realize
  the second. Say so on the component's own value description, where a developer
  reads it, rather than in a Recipe comment.
- **The volume-size row is the knob rule's standing exception**, and it is named
  rather than silent: see the datastore family template below.

### The datastore family template

Every datastore component targets the same shape, distilled from the PostgreSQL
exemplar. A new family member is authored against this template rather than by
copying whichever sibling happens to be nearest.

- **`values`** — the engine-specific subset of logical bootstrap names plus engine
  configuration, each key carrying a `description` and a sensible default so a bare
  Aggregate renders unchanged: the logical `database`, `user` (or `app_user` where
  an application-role split applies), `encoding` / `locale`, `init_scripts` (an
  object whose values are strings), and `custom_config` for a raw configuration
  block. Plus the persistence, HA and backup toggles as configurable knobs, per the
  rule above, wherever the engine has them.
- **`infra`** — `port`, `engine_version`, `compute.{cpu,memory}`, and for stateful
  engines `storage.{size,type}`; `ha.{enabled,read_replicas}`;
  `backup.{enabled,retention_days}`; and `overrides` as the open bag for the
  operational side. **`storage.{size,type}` is scoped to the targets that have a
  volume-size concept — the `compose` realization creates the volume and honors
  neither number, which is this template's one named exception to the knob rule, not
  a silent drop.** The key stays single-named and single-homed rather than split per
  target: the size means the same thing everywhere, and a stateful member needs its
  volume on the local target too or it would not be the same datastore the Kubernetes
  target deploys.
- **`provides`** — `host` and `port` are required; `user`, `database` and
  `protocol` are declared **only where the engine has the concept**. Redis, Valkey
  and Memcached have no user or database — do not invent them to make the family
  look uniform.
- **`featuresSchema`** — an optional transparent `password` slot carrying an inline
  development default when nothing is attached, so an unattached slot stays
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

### The pipeline family template

The `ai-pipeline` category holds **the thing that orchestrates a multi-step
job** — it schedules the job, retries a step that fails, fans a step out over a
list of inputs, and tracks what produced what. That is narrower than the words
"AI pipeline" suggest, and the boundary is the part that erodes, so a candidate
is admitted by stating what it is *not*:

- **Not an agent.** An application that serves an end user, or a framework an
  application is assembled from, belongs under `ai-agent` — including the
  workflow-automation platforms whose contract is an authored flow plus a model
  socket. The tell is a required `ai-model` edge: an orchestrator is indifferent
  to models, and usually has nothing to do with one.
- **Not a model.** An orchestrator infers nothing. Every step it starts runs code
  or an image the author supplied.
- **Not a tool.** A tool is invoked as a capability inside another component's
  turn. An orchestrator is submitted to, or connected to and polled; nothing
  calls it mid-turn.
- **Not a datastore.** An orchestrator persists run state as a means of resuming
  a run, not as its contract. Several *require* a datastore, which is the
  clearest signal of which side of the line they sit on.

**Record that test on the entity.** A one-line statement in the Component's
`description` of what it orchestrates is what lets the next author place the next
candidate without re-deriving the boundary.

- **`pipeline.aggrega.ai/mode`** is the family's capability label, and it names
  **who holds the run and who executes its steps** — which is what predicts what
  else a Release must contain:

  - **`reconciled`** — the run is a custom resource, and the engine's controller
    reconciles it into workload on the platform. The platform's own API is the
    run's record, so the engine keeps no separate run database; in exchange the
    Release carries the custom resource definitions and the runtime-prerequisite
    discipline described under the operator-driven Recipes above.
  - **`durable`** — the engine persists the run's event history and hands work to
    workers the *application* deploys, which execute it and resume from that
    history. The engine needs a datastore of its own and the application needs a
    worker of its own, and neither is optional.

  A value is added when a realization needs one, never ahead of it: a value with
  no entity carrying it describes nothing.

- **Realizations** — a helm Recipe pointing at the product's own chart, per the
  sourced-mode rule above. These products are exactly the complex case that rule
  is written for: several cooperating services, custom resources, cluster RBAC and
  schema-setup ordering. None of them has a meaningful single-container local
  form, so a Compose Recipe is generally not authored.

- **The datastore is a topology edge, never a bundled subchart.** Several upstream
  charts bundle their own database so the chart installs standalone; turn that off
  and declare a `uses` socket instead, so the Release's datastore is one
  component the Release can see, size and back up. Pass the edge's resolved
  `host`, `port`, `user` and database names into the product's own configuration
  rather than composing a connection string — a password embedded in a URL cannot
  be delivered as a secret reference, so composing one forces the credential into
  the rendered artifact.

- **The datastore password is a black-box credential slot.** Declare it with
  `inject: []` and bind the produced Secret by name and key to whatever the chart
  calls its existing-secret knob. The value then reaches the pods without passing
  through the rendered artifact, and unattached the Recipe emits no password at
  all, which suits a store reached without one.

- **Identity labels** — the component's `metadata.labels` carries
  `component.aggrega.ai/type` (`server` for the engine itself; `worker` or `task`
  for a component modelling a step), `component.aggrega.ai/category: ai-pipeline`,
  and `pipeline.aggrega.ai/mode`. Plus `component.aggrega.ai/hosting` and
  `component.aggrega.ai/upstream-licensing` per the rules above.

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

The tiers order the taxonomy by what unblocks a production Release soonest.
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

### Name an emitted resource for the scope that carries it

A Feature is authored once and attached many times. So a resource name a
FeatureRecipe derives has to be distinct per attachment, or two attachments in one
namespace derive the same name and the second resource overwrites the first.

**The convention: a resource name an attachment emits carries the identity of the
scope that carries the attachment.** At component scope that is the host component
and the name the attachment is carried under; at boundary scope it is the
boundary's own name. The catalog's component-scope FeatureRecipes compose both:

```yaml
# The attachment name may be authored with underscores, which a Kubernetes
# resource name cannot carry, so it is folded to hyphens.
name: '{{ .context.instance_id }}-{{ .attachment_name | replace "_" "-" }}'
```

Composing the host alone is enough where the chart already suffixes the resource
per kind. Composing the *attachment* name as well is what keeps one Feature
attached twice to a single component, under two names, from colliding with itself.

**This is a convention authors uphold, not a rule the compiler applies.** Nothing
in the compiler inspects a name template, infers that a value is a resource name,
or composes a scope identity into one — it evaluates the template and pipes the
string through. The compiler is deliberately unopinionated here, exactly as chart
authoring is: a chart that hardcodes a resource name installs once and collides
twice, and nothing in the templating engine prevents it either.

What the compiler *does* do is refuse the result. Two contributors deriving one
name in one key space halt the build (`E0038`), naming both contributors and the
key space. That is a Loud Guardrail on the outcome, and it is not the same thing as
enforcing the convention: it fires only once a collision is already reachable, and
it cannot fire at all for a name that is unique today and collides on the next
attachment someone writes. The convention is what keeps the halt from being
reachable from ordinary authoring.

#### Where an operator must be able to pin the name

Some emitted resources are named by something outside the build: an IAM role's
trust policy names the ServiceAccount it will mint credentials for, and a Workload
Identity binding names the ServiceAccount it trusts. Composing a scope identity
into such a name unconditionally would break that binding, which is worse than the
collision it avoids — the build stays green and the Release silently loses its
identity.

For that case, expose the name as an **optional** `infra` key, honour it exactly as
written when supplied, and derive the scope-composed name only when it is absent:

```yaml
locals:
  sa_name: '{{ default (printf "%s-%s" .context.instance_id (.attachment_name | replace "_" "-")) .infra.service_account_name }}'
```

Two things make this shape work. An omitted optional key arrives empty, so
`default` supplies the derived name without the template needing to test for the
key's presence. And deriving the name in `locals:` gives it one home: a
FeatureRecipe's `provides:` and its `valuesMapping:` both read `.locals`, so the
name published to the consumer and the name the chart emits are the same string by
construction rather than by two templates agreeing. Where a consumer binds to a
published name — a pod running under an emitted ServiceAccount — that agreement is
the binding, so a second copy of the expression is a place for the two to drift
apart silently.

State the behaviour on both the Feature's `infra` key and the FeatureRecipe's
`metadata.description`: an operator reading either needs to know that supplying the
key pins the name and omitting it derives one.

## 8. OCI Registry

The canonical registry is `hub.aggrega.ai`. OCI URIs mirror the filesystem:

- `hub.aggrega.ai/component/core/datastore/mariadb:1.0.0`
- `hub.aggrega.ai/recipe/helm/mariadb:1.0.0`
- `hub.aggrega.ai/featurerecipe/helm/k8s-secret-from-parameter:1.0.0`

### A published version is final

A catalog entity's content at a declared version is immutable. Once a
`name:version` is published, that version denotes those bytes; content that has
changed is published under a new `metadata.version`, and the version directory
segment moves with it — the two always move together (see "Per-version directory
layout" above).

This is enforced at publish time rather than left to convention. Before anything
is uploaded, `aggrega push` compares what is already published at the target tag
against what the content in front of it would publish, and halts when the two
differ:

```text
aggrega push: hub.aggrega.ai/component/core/datastore/mariadb:1.0.0 is already
published as sha256:afd69057…; refusing to overwrite with sha256:fe830920… —
publish a new version (aggrega lint --pre-publish verifies the bump): oci: tag
already published with different content
```

Pushing byte-identical content to a version that already holds it is not a
conflict: nothing is uploaded, and the command reports the version as already
published. No flag and no workspace-config setting relaxes the refusal.

**Two questions, answered by two different commands.** `aggrega push` answers
*whether a new version is owed* — it refuses changed content at a published
version, and says nothing about how far the version should move.
`aggrega lint --pre-publish` answers *how large the bump must be*, classifying
the change against the previously published version and halting on an
under-bump. The refusal above names the linter, which is why the two read as one
path rather than as competing rules; the classification rubric is in
[`aggrega-docs/language-reference/cli/aggrega-lint.md`](https://github.com/aggrega-ai/aggrega-docs/blob/main/language-reference/cli/aggrega-lint.md).

**What the comparison covers, and what it does not.** What `aggrega push`
compares is the entity's own published content. For a single-document kind that
is the entity file itself; for a Recipe or FeatureRecipe it is the whole version
directory — every non-hidden file beside `recipe.yaml`, the co-located chart,
mappings and artifacts included — because the content digest is computed over
the entity's authoring tree. Rendered output that moves *without* any
change to that content — because the compiler moved, or because a dependency's
realization changed — is not what the comparison sees. The first half has a gate
behind it and halts; the second has none: nothing detects it, and no version
promise covers it.

The shape worth recognising, because the entity edit can look smaller than the
output change: a FeatureRecipe whose `valuesMapping` gains a conditional passing
the scope's namespace into its chart, so an emitted resource gains a `namespace`
field whenever the scope declares one. The recipe's bytes moved and the rendered
output moved; the declared version did not. That is a content change, and it is
published under a new version. An edit that never touches `recipe.yaml` at all
lands in the same place: a chart template under the version directory is part of
the entity's published content, so editing one is a content change like any
other.

A first publication is accepted — nothing is published at the tag yet, so there
is nothing to compare against — and the bytes that land are what that version
means from then on. An entity's declared version is therefore worth settling
before its first publish rather than after.

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
