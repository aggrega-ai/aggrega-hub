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
└── artifactlibrary/{name}/{version}/library.yaml
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
| ArtifactLibrary | `artifactlibrary/` | Named artifact bundles — a set of output files imported as one unit | `artifacts.<name>: { $import: <Library>#/artifacts/<entry> }` on a Recipe or FeatureRecipe |

SchemaLibrary and MappingLibrary are the baseline tier. WorkloadLibrary and
ArtifactLibrary are opt-in for catalogs that need cross-Recipe workload or
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
| `gateway` | API and AI gateways | server, resource | populated |
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
  cloud-native primitives — `server`, `worker`, `task`, `function`,
  `stateful-server`, `resource`. Describes how infrastructure treats the
  component (state, ingress, lifecycle). Never carries cognitive vocabulary,
  and never a word the category axis uses: a value on both axes leaves a
  reader unable to tell which one a label is speaking on, and a selector
  written for one silently matching the other. The set is Aggrega's own and
  the published Component schema enumerates it, so an entity carrying
  anything else is refused when the document loads. A catalog needing a
  classification of its own adds its own label key beside this one.
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
  `datastore.aggrega.ai/engine`, `pipeline.aggrega.ai/mode`,
  `security.aggrega.ai/text-anonymization`. These carry
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
| `request-mirroring` | `full-rate`, `sampled` | The component can copy a matching request to a second destination and discard that destination's response. `full-rate` copies every matching request and offers no setting that narrows it; `sampled` offers a settable share, so a component that can sample carries `sampled` and not both. |
| `caller-identity` | `client-certificate`, `injected-header` | The component can convey the original caller's identity to the service behind it, and the value names which mechanism does it. `client-certificate`: the client's own TLS certificate details travel to the backend. `injected-header`: the component authenticates the caller itself and composes headers naming them, which travel upstream on the forwarded request. |
| `content-masking` | `entity-recognition` | The component can replace sensitive text in the chat and completion payload it is routing with a placeholder before the text travels further. `entity-recognition` names the fidelity: it replaces matches of patterns supplied in its configuration and also entity types that a recognizer service it calls detects. A component that could only replace pattern matches would carry a narrower value, added in the same act as the first component to carry it. |
| `prompt-guard` | `pattern-list`, `classifier` | The component can inspect the chat and completion payload it is routing and refuse a request on its content. The value names the fidelity. `pattern-list`: the match is against patterns supplied in its configuration. `classifier`: the verdict is a trained text classifier's, reached through a detection service the component calls, against a threshold supplied in its configuration. The dimension is deliberately narrower than content inspection in general — a component here reads the model payload it already parses to route, and not one of them inspects an arbitrary HTTP body. |
| `upstream-tls` | `trust-anchor` | The component can require the service it forwards to present a certificate chaining to a trust anchor the Release supplies. |
| `upstream-pinning` | `public-key` | The component can refuse a service it forwards to unless a certificate that service presents carries one of the public keys the Release supplies for it. `public-key` names what is pinned: the key itself, so a certificate renewed over the same key still matches. |
| `log-masking` | `entity-recognition` | The component can replace sensitive text with a placeholder in the copy of a call it hands to its logs, while the request it forwards and the reply it returns stay as they were sent. `entity-recognition` names the fidelity: it replaces matches of patterns supplied in its configuration and also entity types that a recognizer service it calls detects. A component that could only replace pattern matches would carry a narrower value, added in the same act as the first component to carry it. |
| `period-budget` | `cost` | The component can refuse model requests once what it has counted over a period exceeds a limit set in its configuration, and the value names what it counts. `cost`: what the traffic cost, priced from a table the component keeps per model. A component that counts tokens would carry a value of its own, added in the same act as the first component to carry it. |

Three rules bind the family, and each has already been got wrong once:

- **The fidelity rides in the value, not in a second key.** Two components that
  both mirror requests can still differ in the way a Feature cares about, so a
  Feature selects the fidelity it needs and is refused early and by name when the
  component cannot deliver it.
- **A value asserts a capability, never a configured state.** The two read alike
  and only the first is a property of the product. `core/gateway/nginx` carries
  `upstream-tls: trust-anchor` although the verification it names is off until an
  operator turns it on, because the label is what a selector reads *before*
  anything is configured. Each component's label comment says this in its own
  terms, so a reader of the entity is not left to infer it.
- **A value is declared only once a component carries it, and each value is
  established against the product's own reference documentation.** A value
  nothing carries is worse than an absent one — a selector naming it parses,
  matches nothing, and reports nothing — so each is added in the same act as the
  first component to carry it. 🔴 **An upstream certificate pinned by key is a
  dimension of its own, `upstream-pinning`, and never a value of `upstream-tls`:
  a pin says which key a certificate must BE, where `trust-anchor` says what one
  must SAY.** A certificate-name assertion and a named trust anchor are neither
  of them pins, so a component able only to check a name or an anchor carries
  no `upstream-pinning` value.

Components today: `core/gateway/nginx` (`request-mirroring: full-rate`,
`upstream-tls: trust-anchor`), `core/gateway/contour` and
`core/gateway/envoy-gateway` (each `request-mirroring: sampled`,
`caller-identity: client-certificate`, `upstream-tls: trust-anchor`),
`core/gateway/kong` (`upstream-tls: trust-anchor`), `core/gateway/tyk`
(`upstream-pinning: public-key`), `core/gateway/litellm`
(`caller-identity: injected-header`, `content-masking: entity-recognition`, `log-masking: entity-recognition`,
`prompt-guard: pattern-list`, `upstream-tls: trust-anchor`),
`core/security/nemo-guardrails` and `core/security/trustyai-guardrails-gateway` (each
`prompt-guard: classifier`). Seven of the eight carry no
`gateway.aggrega.ai/intelligence` value and `core/gateway/litellm` carries `semantic` — and
that mixture is the separation working rather than an exception to it. The
intelligence label names a **product tier** — whether the router parses the
request body — while this family names **capabilities**, so the two answer
different questions and a component may honestly carry both. What a component's
tier value never tells a reader is which of these capabilities it has: the AI
gateway carries several of them, and no amount of reading its tier would say so.
`core/gateway/litellm` carries `period-budget: cost` as well, and so does
`core/gateway/cloudflare-ai-gateway`, Cloudflare's hosted AI gateway, which
carries no other value in this family and carries `semantic`.

A component carrying `prompt-guard: classifier` is also something another
component can send its traffic through: `core/gateway/litellm` and
`core/gateway/nginx` each declare a `guard` socket selecting it, which
`core/prompt-injection-shield` routes the gateway's model requests through.
The selector admits both guards that carry the value, and each gateway's
realization of the shield halts the build on any guard but
`core/security/nemo-guardrails`, the one its two sensitivities are measured
on — the same shape as `cache_store`, whose selector admits the key-value
stores and whose Recipe halts on any store but `core/datastore/redis`.

### The `security.aggrega.ai/text-anonymization` label

`security.aggrega.ai/text-anonymization` records which role a service plays in
masking sensitive data in text where that work is split across two services —
one finds the sensitive spans in a text and reports them, the other rewrites the
spans it is handed — and it is what a consumer's socket selects on to be handed
the right address. A consumer that masks text through such a pair calls both, so
it declares a socket per role and each selector names the value it needs:

| Value | What the value asserts |
| --- | --- |
| `analyzer` | The component finds sensitive spans in the text it is sent — an entity type, a position and a confidence for each — and changes nothing. |
| `anonymizer` | The component rewrites the spans a caller hands it, by the operator the caller names for each entity type, and finds nothing on its own. |

The value names the role, not the interface. Components today:
`core/security/presidio-analyzer` (`analyzer`) and
`core/security/presidio-anonymizer` (`anonymizer`), which speak the Presidio HTTP
API; `core/gateway/litellm` selects them on its `pii_analyzer` and
`pii_anonymizer` sockets. The compiler routes the address a selected component
publishes and checks nothing about what answers there, so a component carrying a
value here that speaks a different API is refused by nothing and fails when it
is called; each socket's comment names the API its consumer speaks. As with the
data-path family, a value is added in the same act as the first component to
carry it.

### The `security.aggrega.ai/text-detection` label

`security.aggrega.ai/text-detection` records which role a service plays where a
text is judged by a detector and the judgement is put to use by another service —
one scores the texts it is sent and reports what it detects, the other runs such
a detector around a call to a model — and it is what a consumer's socket selects
on to be handed the right address:

| Value | What the value asserts |
| --- | --- |
| `detector` | The component scores each text it is sent and reports what it detects in it — each label it scores at or above the threshold the caller names, or its own default, with the score — and changes and forwards nothing. |
| `orchestrator` | The component runs the detectors a request names over its text — the latest message before the model is called, the reply after — asks the model for no reply when the input carries a detection, and reports the detections beside the reply. |

It is a different label from `text-anonymization`, whose analyzer reports the
sensitive spans of a text for an anonymizer to rewrite: a detector here gives a
verdict on the whole text, and nothing is rewritten. Nor is an orchestrator a
guard on its own — a request naming no detector passes through it unchecked — so
the component that names the detectors for every request it routes carries the
data-path family's `prompt-guard` instead.

The value names the role, not the interface. Components today:
`core/security/trustyai-huggingface-detector` (`detector`), which speaks the
guardrails detector API, and `core/security/fms-guardrails-orchestrator`
(`orchestrator`), which serves the orchestrator's own chat route.
`core/security/nemo-guardrails` and `core/security/fms-guardrails-orchestrator`
select `detector` on their `detector` sockets, and
`core/security/trustyai-guardrails-gateway` selects `orchestrator` on its
`orchestrator` socket. The compiler routes the address a selected component
publishes and checks nothing about what answers there, so a component carrying a
value here that speaks a different API is refused by nothing and fails when it
is called; each socket's comment names the API its consumer speaks. As with the
data-path family, a value is added in the same act as the first component to
carry it.

### The `model.aggrega.ai/api` label

`model.aggrega.ai/api` records which model API answers at the `endpoint` a
component publishes, and it is what lets one socket take either a model or a
gateway serving models. Two categories carry it — every `ai-model` Component,
and a `gateway` Component that serves a model API — so the prefix names the
concern the two share, serving a model, rather than either category. It sits
beside `model.aggrega.ai/capability`, which says what kind of model answers, and
does not overlap it.

| Value | What the value asserts |
| --- | --- |
| `openai` | The OpenAI model API answers at the published endpoint — OpenAI's own, or a server's implementation of it — so a consumer speaks to it as it would to OpenAI. |
| `native` | The product's own model API answers there, and it is not the OpenAI API, so a consumer speaks that product's API, through its client or its request shape. |

Three rules bind it:

- **A model socket selects the key, never a value.** The catalog's model
  sockets — every agent's `model`, `core/ai-tool/model-invocation`'s
  `target_model`, and `core/datastore/cognee`'s `extraction_model` and
  `embedding_model` — select
  `component.aggrega.ai/category in (ai-model, gateway), model.aggrega.ai/api`.
  The category requirement admits the two categories and the key requirement
  admits only the components among them carrying the label, so every model is
  admitted whatever its value, a gateway serving a model API is admitted, and a
  gateway serving none is refused by name. A selector's requirements all have to
  hold and its alternatives live inside one key's set, so no selector can admit
  an unlabelled model and a labelled gateway while refusing an unlabelled
  gateway — which is why every `ai-model` Component carries the key. A socket
  that needs one particular API names its value.
- **A component carrying the key publishes what a model publishes:** `endpoint`
  and `model` in its `provides`, the two keys a consumer's Recipe reads off a
  model edge. One that published no `model` would hand its
  consumers an empty model name, and no build would report it. A gateway
  publishes one alias of its model map as its `model`, named by a value of its
  own and checked against the map by an assertion on its Component, so the order
  of the map never decides what a consumer asks for.
- **A value is read off the product's own reference** — the routes the server
  the Recipes pin registers, or the API its documentation names — and is added
  in the same act as the first component to carry it, as with every label family
  on this page. It names the product's API, never a configured state: a model
  whose endpoint an operator may repoint keeps the value of the product it
  describes.

Components today: `core/gateway/litellm` carries `openai`, as do
`core/ai-model/vllm`, `ollama`, `tgi`, `tei`, `nvidia-nim`, `litellm`, `openai`,
`openai-embedding`, `nvidia-api` and `openai-compatible` — the broker, whose
whole contract is to be pointed at a service speaking that API, and which stays
the handle for an endpoint the catalog does not model. Every other
`core/ai-model/*` Component carries `native`. Each label's comment says, in its
product's terms, what answers at its endpoint. The compiler matches the string
and checks nothing about what answers at the address, so a component carrying a
value its endpoint does not speak is refused by nothing and fails when it is
called.

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

**A credential the components of a module share is a module parameter.** An
Aggregate importing a module hands it `type`, `active` and `parameters` and
nothing else, so an attachment the module does not make itself never reaches a
component inside it. The module declares one parameter per distinct credential,
with a pinned development default its description says is for evaluation, and
attaches `core/referenced-secret` on every slot that shares it — on a
component's own slot where the component verifies the credential or uses it
itself, and as the `credential` of the connection where a component presents it
to another — with `origin` read from the parameter and `key` a literal, so the
one credential is authored once and cannot drift between the components that
must agree on it; an importer supplying its own declares a parameter of its own
and passes it down through its `aggregates` entry. What the parameter means
follows the realization the importer's Manifest binds: the credential itself under
`k8s-secret-from-parameter`, the name of a Secret that already exists under
`k8s-existing-secret`. So the default is a valid Kubernetes object name that also
meets what the product requires of the credential — a length, the characters it
refuses — and the parameter's description says what the value is under each.
Every Manifest whose Aggregate imports the module maps `core/referenced-secret`,
or the build halts, and the module's description says so. `core/apisix` declares
its parameter required and with no default, because the key it carries guards
the API that writes the gateway's routes and a pinned one would be a key every
reader of the catalog holds: an importer passes one down and its Release
fulfills it, or the build halts. The shape stops where
the Feature cannot follow. A
module that also builds on `compose` attaches nothing, because that target has no
realization of a Feature holding a credential by reference; its description says
its components run on their Recipes' development credentials and that a reader
needing real ones composes the components directly. And a slot no consumer can
present stays unattached, because filling it switches authentication on for
clients with no way to authenticate — the store's password in `core/livekit`,
which neither the media server nor the bridge declares a slot to present. So
does a credential that is a slot on some consumers and a plain value on another,
because one parameter would then be a Secret's name on one side and the literal
credential on the other — the object store's access key in `core/agenta`, the
`credential_id` of both API tiers' store connections and the store's own
`root_user`. `core/keycloak`, `core/harbor`, `core/thanos`, `core/apisix`,
`core/livekit`, `core/agenta` and `core/dify` are
the shipped shape, the last two leaving credentials unattached for those reasons;
`core/kong` and `core/ferretdb` show the `compose` limit.

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
every kind, Plugin included. That is a catalog convention, upheld by review rather
than by a check: a publication reads the version from the entity, never from the
directory, so a mismatch publishes at the version the entity declares and the
directory is simply misleading. One published version is one directory, so the
source tree holds every version of an entity side by side rather than relying on git
history for older versions.

**What is enforced is that each version directory holds one entity.** Every kind has
a directory of its own except Aggregate, Release and Manifest, and `aggrega pin` and
`aggrega push` refuse an entity of any other kind that has another entity beside it,
naming the entity in the way. A file beside the entity that is not an entity
document — a chart, a mapping, an artifact, the `entity.lock` — is not in the way. A
catalog load and a lint leave such a directory alone; the refusal arrives when the
entity is pinned or published. The `<entity>.yaml` filename is kind-conventional:

| Kind | Filename |
| --- | --- |
| Component | `component.yaml` |
| Feature | `feature.yaml` |
| Plugin | `plugin.yaml` |
| Aggregate | `aggregate.yaml` |
| Recipe / FeatureRecipe | `recipe.yaml` (co-located `source/`, `mappings/`, `artifacts/` and the `entity.lock` the pin step writes sit beside it inside the version dir) |
| SchemaLibrary / MappingLibrary / WorkloadLibrary / ArtifactLibrary | `library.yaml` |

Recipe and FeatureRecipe deliberately share the `recipe.yaml` filename. The walker
is layout-agnostic (it indexes by authored `name:version`), so this layout is an
authoring and publishing convention, not a load-time rule; its one enforced half is
the one-entity-per-directory rule above, held at pin and at publication.

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
ArtifactLibrary — follow their own naming rule, and it differs from Components
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

What is stripped is a suffix that only repeats the category. Where the category
word is part of the product's own name and stripping it would name another
product, the segment keeps it: Cloudflare's AI Gateway is
`core/gateway/cloudflare-ai-gateway`, because `cloudflare-ai` would read as the
vendor's model service and `cloudflare` as Cloudflare Gateway, a different
product of the same vendor.

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
| The artifact the Recipe sources | the artifact kind | `mariadb-rds-module`, `prometheus-chart` |
| That the resource lives outside the Release | `external` | `postgres-external` |

A chart realization added beside an authored one is the common case of the
sourced-artifact row: the authored Recipe fetches nothing, so it keeps the bare name,
and the chart realization takes `-chart` — `prometheus-chart` beside `prometheus`.
Where a component comes to carry two chart realizations from different publishers, the
later one is distinguished by what actually tells them apart rather than by a second
generic suffix.

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

### Descriptions: a few short paragraphs, the detail in comments

`metadata.description` is the prose a reader meets before choosing an entity: a
publish stamps it onto the artifact as its searchable description (see
"Searchable manifest annotations" below), and it is the text `aggrega search`
matches a query against. This catalog writes it for that moment and keeps it
short:

- **A few short paragraphs, separated by blank lines** in a folded
  `description: >` block — what the entity is; how a reader uses it; where it is
  realized and what it does not do. `feature/core/random-password` is the shape.
- **The detail is a YAML comment beside the field or block it explains**, written
  in the reader's terms: why a default is what it is, how a setting behaves on one
  provider, what a value means under each realization. A sentence cut from a
  description moves into a comment; the fact it carried is never dropped.
- **A limit a reader must meet before choosing the entity stays in the
  description, briefly.** The disclosures other conventions on this page ask a
  description to make — the input a fleet member leaves to the Release, which
  realization to reach for — are this case.

The length half of the convention is held by this catalog's own checks, which
refuse every entity description in this catalog longer than a ceiling declared
once in the check itself; the number lives there and nowhere else. The check measures length and nothing
more, so the paragraph shape and the kept facts stay with the author and the
reviewer. It is a convention of this catalog and never of the product: nothing in
the product limits a description's length — the entity schemas declare none, and
the compiler builds nothing from what a description says — so a catalog published
by anyone else may write its descriptions at any length.

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

An entity's content digest is taken over the **raw bytes** of its file and of each
file it carries beside it, with nothing parsed, normalised or re-serialised first:
it is the SHA-256 of a listing of one line per file, giving whether the file is
executable, the SHA-256 of its bytes and its path, not the hex `sha256sum` prints.

The consequence is that the digest tracks the bytes exactly — including across an
edit YAML defines as producing the identical parsed value. Re-wrapping a folded
scalar, rewrapping a comment and adding trailing whitespace each move the digest
while changing nothing the compiler reads.

That digest is what a consumer's `release.lock` pins. When it moves, every lockfile
holding the old one is out of date, and the next build halts instead of rendering:

```text
lockfile: out of date; it no longer matches what its Release resolves to: entity
"core/datastore/mariadb" changed: lockfile=(1.0.0,sha256:5c2ea291…)
current=(1.0.0,sha256:2392e621…)
```

The halt names the refresh that clears it, an ordinary
`aggrega pull --release <release>`. Once the consumer's lockfile is
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
- **`source_version`** — the version of the *source artifact* a Recipe pulls: a Helm chart version, a Terraform module version. Only artifact-backed Recipes (a sourced Recipe, over a chart or over a module) pull such an artifact, so `source_version` belongs only on components whose Recipes are artifact-backed. A pure-synth Recipe assembles its workload directly and pulls no chart or module, so it has no source artifact to version — it exposes `engine_version` alone.

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

These obligations follow a sourced Recipe, and the list below is the statement of
them — it is deliberately not counted in this sentence, because a count sitting
beside the thing it counts is a second copy that goes stale the first time the list
grows:

- **Pin the images the chart runs.** A chart that leaves an image tag to its own
  default makes the render irreproducible across pulls, which is the whole point
  of pinning the chart. Set each tag explicitly in the value mapping and offer an
  `infra.overrides.<name>_image` escape that replaces the block.
- **Pin the generated resource names to the rendered name.** Bind the chart's
  `fullnameOverride` to `.context.rendered_name` — the name the helm provider
  gives the chart, which is the chart's release name — and build every
  `provides` value that names an emitted resource from the same key, keeping
  whatever prefix or suffix the chart adds to it:

  ```yaml
  provides:
    host: "{{ .context.rendered_name }}-proxy"
  valuesMapping: |
    fullnameOverride: "{{ .context.rendered_name }}"
  ```

  The pin is what makes a Service the Component publishes through `provides` one
  the render actually emits. A `provides.host` that names no emitted Service is
  a broken contract, and a build reports nothing either way, because both sides
  render successfully. The key the pin is bound to is what makes the name one
  the cluster accepts. Never bind it to `.context.instance_id`: that is the
  Component's identity as written, and a Component's name may carry characters
  a Kubernetes resource name refuses — an underscore, a capital — so the chart
  would mint names the cluster refuses when the Release is applied, which no
  build catches: the render succeeds either way. The rendered name writes those
  characters out and spells the name in the alphabet a Kubernetes name allows.
  A name the Recipe writes itself for an object it emits beside the chart — an
  `artifacts:` entry, or a second Service-name knob the chart offers — is bound
  to the same key, so it agrees with the chart's own names. The rule binds a
  FeatureRecipe attached to a helm component in the same terms: there the key is
  the host component's name, and a name the attachment composes from its host,
  in a chart value or anywhere else, is built from it ("Name an emitted resource
  for the scope that carries it").
  This catalog's own checks refuse a sourced Helm Recipe that publishes a host
  while pinning no name, or while binding the pin to anything but
  `.context.rendered_name`. That catches the structural omission which causes
  the defect rather than the defect itself: the check reads authored YAML and
  renders nothing, so confirming the published address against a Service the
  chart really emits stays the author's to do.
  🔴 **And the name the chart honours is not always the top-level one.** Some
  charts derive a component's resource names from a knob of their own —
  `server.fullnameOverride` rather than `fullnameOverride`, say — and the
  top-level key never reaches it, so the pin is present, the check is satisfied,
  and the address still answers to nothing. **Render the chart both ways and read
  the emitted Service name before choosing which knob to bind.**
- 🔴 **Supply whatever the chart would otherwise generate.** A chart that invents a
  password, a key or a token when none is given produces **different bytes on every
  render**, which breaks the byte-identical output the whole toolchain rests on —
  and it breaks it silently, because the build succeeds and the artifacts look
  right. Nothing in a single build can show it: it is visible only by rendering
  twice and comparing. Supply the value on **both** paths, bound by name where a
  credential is wired in and a fixed development value where nothing is, so the
  realization renders the same bytes twice whatever is attached to it.

**Per-entity validation does not render a sourced Recipe, so its success says
less than it looks.** Validating a chart-backed Recipe reports that the render was
not attempted, precisely because resolving the chart is a separate step — so a
clean result there means *not examined*, never *examined and fine*. A sourced
Recipe is proven by a real build with the rendered output read, and by nothing
short of one.

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

The standard library ships that wiring for both managed-database capabilities —
[`feature-recipe/terraform/generated-secret`](../aggrega-catalog/feature-recipe/terraform/generated-secret/1.0.0/recipe.yaml)
and
[`feature-recipe/cloudformation/generated-secret`](../aggrega-catalog/feature-recipe/cloudformation/generated-secret/1.0.0/recipe.yaml)
— and for `helm`,
[`feature-recipe/helm/generated-secret`](../aggrega-catalog/feature-recipe/helm/generated-secret/1.0.0/recipe.yaml),
for a controller that owns the credential (below). They share the FeatureRecipe
name `generated-secret`, so a Manifest must reference the intended one
**provider-qualified** — `terraform/generated-secret:1.0.0`, not
`generated-secret:1.0.0`. A bare name resolves only when exactly one capability
in the catalog carries it; with more than one carrying this one, a bare reference
matches each of them and resolves to none, and the pull halts on it — as matching
no entity in the catalog, or, where it goes on to look the reference up in a
registry, as lacking the provider segment a registry reference needs. The rule is
the name's, not the Feature's: `provided-secret`, which realizes
`core/secret-provided` on both `helm` and `compose`, is referenced the same way, as
`helm/provided-secret:1.0.0` or `compose/provided-secret:1.0.0`.

The canonical examples are
[`recipe/terraform/mariadb-rds/1.0.0/recipe.yaml`](../aggrega-catalog/recipe/terraform/mariadb-rds/1.0.0/recipe.yaml)
and
[`recipe/cloudformation/mariadb-rds/1.0.0/recipe.yaml`](../aggrega-catalog/recipe/cloudformation/mariadb-rds/1.0.0/recipe.yaml).

The same binding serves a self-managed datastore whose controller-driven Recipe
leaves the credential to its controller.
[`recipe/helm/mariadb-cluster`](../aggrega-catalog/recipe/helm/mariadb-cluster/1.0.0/recipe.yaml)
with `infra.credentials: generated` emits a `MariaDB` custom resource that names
no root-password Secret, the mariadb-operator controller generates the password
into a Secret it creates and owns, and the Component's required `root_password`
slot is bound to `helm/generated-secret`. Bind it only where the Recipe reads
nothing from the slot: a Recipe that delivers the credential itself, such as the
synthesis `helm/mariadb`, cannot take it, and the build halts. Otherwise, Recipes
targeting self-managed datastores (Helm Bitnami chart, Compose container) still
use the credential FeatureRecipe path, because no upstream managed-secret flag
exists for those targets.

### Optional credential slots for self-managed datastores

A self-managed datastore Component declares its password as an **optional**
credential slot in `spec.featuresSchema`, and its Recipes wire that slot
**conditionally** — the credential subsystem when a credential is attached, an
inline development default when none is. This keeps the slot non-breaking: a
Release that attaches no credential still renders and runs, byte-identically
to a Recipe with no slot at all. The default is the same for every reader of the
catalog, so it serves evaluation; a Release that must not run on it binds the
slot — with a credential it supplies, or with one the target generates (see "A
credential the target generates" below).

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
credential is held in the Secret a `core/referenced-secret` attachment names —
one its realization emits, or, bound to `k8s-existing-secret`, one that already
exists in the namespace — and the consuming Recipe mounts that Secret as a file
and points the client's credential-path variable at the mounted file. No new
Secret-emitting Feature is authored — the file mount and the credential-path
variable are the only additions on the consumer.

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

### A credential the target generates

Where a Release supplies no credential, a self-managed datastore's Recipe falls
back on its inline development default, and a module falls back on its
parameter's default — values every reader of the catalog knows. Reach for
[`core/random-password`](../aggrega-catalog/feature/core/random-password/1.0.0/feature.yaml)
wherever that must not happen and no one should have to write the credential
down: the target generates it.

The build cannot be where it is made. The compiler's output is identical for
identical input and never carries a secret's value, so a password drawn at build
time would change on every build and sit in the rendered files. Each
FeatureRecipe renders a **request** instead — a generator resource naming the
secret resource it fills — and the target draws the value at deploy time. The
rendered output names the generator and the resource, and carries no value.

| Capability | FeatureRecipe | What it renders | What the target needs running |
| --- | --- | --- | --- |
| `helm` | `random-password-external-secrets` | an External Secrets Operator `Password` generator and an `ExternalSecret` that fills a Secret from it once and never refreshes it | the External Secrets Operator with its generator resources, which `core/security/external-secrets` installs |
| `helm` | `random-password-kubernetes-secret-generator` | a `StringSecret`, which the kubernetes-secret-generator controller reconciles into a Secret of the same name | that controller, which the catalog does not install |
| `terraform` | `terraform/random-password` | a module of its own holding a `random_password` resource and an output named by `values.key` | nothing: Terraform draws the value on apply and keeps it in the plan and state, which is where it must be protected |
| `cloudformation` | `cloudformation/random-password` | an `AWS::SecretsManager::Secret` that generates its own string under `values.key` | nothing: Secrets Manager generates the value when the stack creates the secret |

The two terraform and cloudformation realizations share the name
`random-password`, so a Manifest references each provider-qualified, as it does
`generated-secret`.

- **The runtime prerequisite is affirmed, not assumed.** A helm realization's
  request fills nothing until its controller runs, and the compiler cannot
  inspect the cluster, so both helm FeatureRecipes halt the build unless the
  Release sets `infra.control_plane_present: true` on the attachment — the key
  `core/public-ingress` reads, with the same meaning, for its ingress
  controller. Each helm description names its sibling and the controller that
  selects it.
- **Where it cannot be used.** Compose runs no controller and has no resource
  that generates a value, so no realization ships for it, and a build binding
  `core/random-password` on compose halts with `E0099`: *"no feature recipe
  implements this type"*. Supply the credential with `core/secret-value` there.
- **Its settings are the ones every generator honours.** `length` and
  `symbols` are read off the four products: each takes a length, and each can
  leave punctuation out. Finer control over character classes exists on some
  of them and not on all, so it is not offered. `symbols` is off by default,
  because a password is often placed inside a URL or a connection string.
- **A consumer reads it unchanged.** It carries `feature.aggrega.ai/kind:
  secret` and publishes the `name` and `key` locator `core/referenced-secret`
  publishes, so a slot selecting the credential family admits it and a Recipe
  reading `.features.<slot>.provides` needs no edit. On terraform the pair is
  the attachment's module call and its output, which a consumer joins into
  `${module.<call>.<output>}`; that reference resolves in the boundary's root
  configuration, so the consuming Recipe is a `source:` Recipe.
- **Sharing one generated credential takes one request.** Every attachment
  renders its own request and every request draws its own password, so
  attaching `core/random-password` on each of two components — or once at a
  scope that cascades to both — gives a database and its client two different
  passwords; with `values.name` pinned the two requests derive one name and the
  build halts on it (`E0038`). Attach it on one component with `values.name`
  pinned, and `core/referenced-secret` bound to `k8s-existing-secret` on the
  others, with `origin` set to the same name; write both from one parameter so
  they cannot disagree. One request is rendered and every workload references
  its Secret.
  This is available where `core/referenced-secret` has an existing-Secret
  realization, which is `helm`.
- **A module's credential is generated from the Aggregate importing it.** That
  Aggregate cannot attach anything to the components inside the module, so it
  carries the request itself: a free `core/random-password` attachment on a
  component of its own, with `values.name` pinned and `values.key` set to the
  data key the module's attachment reads — its parameter's description names
  it — and the same name passed down as the module's parameter, with the
  Manifest binding `core/referenced-secret` to `k8s-existing-secret`. A Release
  cannot carry the request in its place: an attachment a Release declares
  takes no `values`, so its key would stay the Feature's default rather than
  the one the module reads.
- **It is not `core/generated-secret`.** That Feature hands a credential to an
  engine that already owns it — a managed database, a database controller — and
  renders nothing. `core/random-password` renders the request itself, for a
  workload whose Recipe expects to be handed a credential.

### Who supplies a credential's locator: values or infra, exactly one

A credential Feature that carries a caller's locator — the secret's name, the
store entry to fetch, the value to deliver — takes it from either author. In
this catalog that is `core/referenced-secret`, `core/referenced-secret-set`,
`core/secret-value` and `core/secret-provided`: the developer writes the locator
in the attachment's `values`, in the Aggregate, and the operator writes it in the
attachment's `infra`, in the Release. `core/random-password` and
`core/generated-secret` take no locator and are not shaped this way.

**Why the operator's pillar.** A connection the Release wires has no entry in the
Aggregate, and a Release writes `values` nowhere, so a credential that took its
locator from `values` alone could never be named on such a connection, nor on any
attachment the Release makes. The operator's form is `infra`, which leaves the
Release's `values:` ban exactly as it is.

**Why exactly one.** Two locators on one attachment do not say which secret it
names, and none names no secret. Neither pillar's schema can state the rule,
because each pillar is validated on its own and neither sees the other, so the
Feature states it in its own `assertions` block, where both are in view: the
build halts on an attachment carrying the locator in both pillars or in neither,
naming the Feature, the attachment and the component. Presence decides, not
content. The rule is the Feature's contract — the compiler evaluates the
assertion as it evaluates any Feature's and holds no credential rule of its own.

**How to author one.**

- Declare the leaf in both pillars with **one name, one shape and one
  `sensitive: true`**, `required` in neither; the assertion is what requires it.
  Every other field keeps the single pillar it has: a data key stays in `values`,
  so an attachment the Release alone makes reads its default.
- Every realization reads the locator from whichever pillar carries it, with
  `optional .values "<leaf>" (optional .infra "<leaf>" "")` — `(list)` in place of
  `""` for a list. Read the `values` leaf only through `optional` in that
  template: one that also reads it as a path finds the key present and empty and
  never falls through to `infra`. The expression is repeated in each realization
  because it sits inside a template the realization owns, and no catalog kind
  holds a single expression for several entities to share; each says so in a
  comment beside it.
- State the two forms in the Feature's description, and any limit the operator's
  form meets. `core/secret-provided` is the one shipped case: its value is
  delivered by the attachment's own `inject:` block, which only the Aggregate
  writes and a connection's attachment never carries, so on a connection, or on
  an attachment the Release alone makes, no `inject:` block delivers it.
- Declaring one leaf in both pillars is what the pillar-overlap advisory reports,
  so every load reaching these Features prints it. The overlap is the contract
  here, and the advisory changes no verdict and no rendered byte.

### A key both ends of a connection hold

A server that checks a key and a caller that presents it each hold that key, each
on its own side. This is a **convention** catalog authors uphold, and the
compiler enforces none of it: it evaluates the slots and attachments it is given
and pipes their strings through, and it never compares what one component holds
with what another holds.

- **The caller's key is the caller's.** A caller holds the key it presents on the
  connection it presents it on, in a slot its socket declares under
  `usesSchema.<socket>.featuresSchema`, so a caller reaching several servers
  holds one key for each — `core/ai-agent/crewai`'s `model` socket declares it as
  `credential`. A caller whose Component declares the key in a slot of its own
  instead holds one key for every connection it makes.
- **The server's key is its own slot.** A server holds the key it verifies in a
  slot of its own Component, and every Recipe for it delivers that key as the
  variable the server reads. Neither end sees the other's attachments: an
  attachment on a connection lands on the caller alone, and a server's rendered
  output is the same whatever the connections reaching it carry. Filling one
  end's slot fills nothing on the other, so declaring the key on both ends is the
  minimum rather than a duplicate.
- **Both ends read one parameter.** The Aggregate declares one parameter and
  both attachments read it, so the key the caller presents and the key the server
  verifies cannot be written apart. What the parameter carries is the locator the
  bound realization reads `origin` as — a secret's name for `k8s-existing-secret`,
  the key of a store entry for `k8s-external-secret`, the value itself for
  `k8s-secret-from-parameter` and `dotenv-secret` — so the two ends' realizations
  read it in the same sense.

**One secret where the two ends share a secret scope, one each where they do
not.** A secret scope is the boundary within which a provider resolves a secret
by reference. Where both ends sit in one scope, both reference one secret
resource. Where they sit in different scopes, each end holds a secret resource
of its own, realized from the same store entry. The Manifest chooses each end's
realization: by Feature type for every attachment of that type, or for one
attachment by its name in the `features.name` tier, where a connection's
attachment is keyed `<alias>.<slot>`. Each provider draws the scope in its own
terms:

- `helm` — the Kubernetes namespace, read from the `aggrega.ai/namespace`
  annotation cascading from the boundary; a workload references a Secret only in
  its own namespace. In one namespace, bind both ends to `k8s-existing-secret`
  with one `origin`, and both reference that Secret by name. In two, bind each
  end to a realization that renders its own resource beside it, such as
  `k8s-external-secret` fetching the one store entry into each namespace.
  `k8s-secret-from-parameter`, which writes the value itself into a Secret for
  evaluation, derives one Secret per end even within one namespace, each
  carrying the same value.
- `compose` — the Compose project, one `docker-compose.yaml`, whose `${VAR}`
  references Docker Compose substitutes from the environment the project is
  started with: the shell, a file named with `--env-file`, or the `.env` file in
  the project directory. In one project, both ends' `dotenv-secret` attachments
  carry the same reference. Boundaries rendering to different files are
  different projects, each started with an environment of its own holding the
  entry.
- `terraform` — the boundary's root configuration, the one configuration a plan
  sees; a reference resolves only against what that configuration declares, so
  two root configurations each hold their own copy.
- `cloudformation` — the stack, in the AWS account and region it deploys into. A
  Secrets Manager secret a realization renders is published as a `Ref`, which
  resolves inside its own stack, so a component in another stack holds a secret
  of its own.

The standard library ships the key-checking model servers on `helm` and
`compose`, which are therefore the two capabilities where both cases are
realized end to end.

**A server holding one key cannot tell its callers apart.** `core/ai-model/vllm`,
`tei` and `tgi` each check one key, so every caller presents the same key, a
caller presenting any other is refused, and withdrawing one caller's access means
changing the key every caller presents. However many keys the callers'
connections hold, the server's slot holds one. That is the servers' own limit,
not the catalog's. Two targets add a difference of their own:

- **Text Generation Inference matches the key without regard to letter case.**
  At the release the catalog pins, the server folds both the `Authorization`
  header and the key it holds to lower case before comparing them, so two keys
  differing only in case are one key to it, and a key's strength is judged on its
  case-folded form. That is the server's behaviour, and no Recipe changes it.
- **LiteLLM also accepts the keys it issues.** The LiteLLM model and the LiteLLM
  gateway accept, beside the key their `api_key` slot holds — LiteLLM's master
  key — the keys they issue through their key-management API, and only while
  their bookkeeping database is attached through `database_url`; with none, they
  accept their own key alone.

**The caller key's name on the model-serving targets is `api_key`.** On
`core/ai-model/vllm`, `tei`, `tgi` and `litellm`, and on `core/gateway/litellm`,
the key a target requires of its callers is the optional slot `api_key`, with
`selector: "feature.aggrega.ai/kind=secret"`, `sensitive: true` and
`inject: [env]`, and a description saying every caller must present it and
naming the product's own term for it where it has one. The variable the server
reads is each Recipe's translation, as for any target-expected name. The name is
scoped to those targets: a datastore's password, a broker's credential and a key
that is one half of a pair keep the names their products give them. Because the
name is fixed, a lint plugin comparing what the two ends of a connection
reference can find the target's end by this slot name alone, a catalog
convention no schema keyword marks; the publishing linter that `aggrega lint`
runs carries no such rule.

**The caller key's name on a socket is `credential`.** A credential a caller
presents to the target of one of its own sockets is declared on that socket,
under `usesSchema.<socket>.featuresSchema`, as the slot `credential`, with
`selector: "feature.aggrega.ai/kind=secret"`, `sensitive: true`, the `inject`
mechanisms its Recipes deliver it through, `required: true` where the caller
cannot run without it, and a description naming what the caller presents it to
and the variable it is delivered as. The `core/ai-agent` Components that reach
a model declare it on their `model` socket, and their Recipes deliver it as
`OPENAI_API_KEY`; a platform presenting a password to the datastore on its
`backend` socket declares it there — `core/gateway/kong`, whose Recipes deliver
it as `KONG_PG_PASSWORD` — as do the cache and object-store sockets of
`core/observability/langfuse`, the sandbox and plugin-runtime sockets of
`core/ai-agent/dify`, and the media-server socket of
`core/messaging/livekit-sip`, where the slot is `required`. The name holds one
credential; it is a key a developer writes on the connection
(`uses.<socket>.<alias>.features.credential`) and an operator writes on a
connection the Release wires, so it is the same word on every socket.

- **Every Recipe reads it per connection.** It sits under the connection, at
  `.context.uses.<alias>.features.credential`, never among the Component's own
  `.features`. A synthesized Workload delivers it with `connection: <alias>`
  beside `from: credential`; a compose Recipe reads the value its credential
  writes on the inject pipe; a chart Recipe reads the locator it publishes, at
  `.context.uses.<alias>.features.credential.provides`, into the chart's
  existing-secret setting. Each guards the delivery on the connection carrying
  one — `hasKey (default dict $edge.features) "credential"` — because an entry
  naming a connection with nothing in the slot is refused, and a connection
  carrying no credential renders exactly what it renders with no slot at all.
- **The socket says when none is intended.** Each such socket also declares
  `unauthenticated` (`type: boolean`, `default: false`) in its `valueSchema`: the
  connection's own statement that its target takes no credential. It changes
  nothing a Component renders. A socket whose `credential` is `required` declares
  no `unauthenticated`, because a connection carrying no credential there halts
  whatever the connection says.
- **A managed target reached with neither is refused.** Every Component
  declaring such a socket carries the assertion
  `managed_target_needs_a_credential`. It ranges a list naming every socket of
  the Component that declares `unauthenticated`, and halts the build on a
  connection whose target is labelled `component.aggrega.ai/hosting: managed`
  and which carries neither a `credential` nor `unauthenticated: true`, naming
  the component instance, the socket, the connection and its target. A target
  labelled `self-hosted`, `external` or `mixed`, or carrying no hosting label,
  draws nothing — a `mixed` target's posture follows the Recipe the Manifest
  selects, which a Component assertion runs before. It is a Component assertion
  so that it holds whichever Recipe binds, and what the label means is this
  catalog's convention: the build carries the label's string, and the assertion
  decides what it means. A Component's assertions are written in the Component
  itself, so each carries its own copy, and the copies differ only in that list
  of sockets.
- **Several consumers share one credential by authoring.** Nothing cascades into
  a connection, so a shared key is one parameter every connection's credential
  reads — under `k8s-existing-secret`, the name of one Secret each connection
  references; under `k8s-secret-from-parameter`, the key itself, rendered once per
  connection. The worked example is
  [`language-reference/examples/model-api-key-sharing/`](https://github.com/aggrega-ai/aggrega-docs/blob/main/language-reference/examples/model-api-key-sharing/).

**A pair presented on one connection adds `credential_id`.** Where a caller
presents an identifier and its secret together on one connection — an object
store's access-key identifier and secret key — the secret half is `credential`,
as on every other socket, and the identifier half is `credential_id`, declared
beside it with the same keys and read and delivered the same way.
`core/ai-agent/agenta-api` and `core/ai-agent/agenta-services` declare the pair
on their `store` socket and deliver `credential_id` as `AGENTA_STORE_ACCESS_KEY`
and `credential` as `AGENTA_STORE_SECRET_KEY`. An identifier that is a plain
value rather than a credential stays a value on the connection:
`core/observability/langfuse` names its object store's access-key identifier in
the `event_store` connection's `access_key_id` value, and only the secret half
is its `credential`.

**Two realizations constrain the secret the two ends share.**

- **KubeAI** (`helm/vllm-kubeai`). The KubeAI `Model` imports the credential's
  secret through `envFrom`, which names each variable after one of the secret's
  data keys, so a shared secret carries the key under the data key
  `VLLM_API_KEY`, the Recipe halts the build naming any other, and the caller's
  attachment names that same data key. Every key the secret holds becomes a
  variable of the server's container, so the secret holds that key alone.
- **KServe** (`helm/vllm-kserve`). The `InferenceService` passes `VLLM_API_KEY`
  to the container of the serving runtime the cluster registered for the
  model's format, so the key takes effect only where that runtime runs vLLM's own
  server.

The [credential chapter](https://github.com/aggrega-ai/aggrega-docs/blob/main/architecture/08-credential-model.md#a-key-both-ends-of-a-connection-hold)
works the shape through in one Aggregate.

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
`.context.instance_id`, `.values`, `.infra`, `.locals`, and static text — and,
where the node's provider reports one, `.context.rendered_name`, the name the
node's resources are rendered under: on a `helm` Recipe, one that declares a
`workload:` or names a chart in `source:`. There is no `.workload` in scope, so
`provides.endpoint` cannot derive itself from the workload's endpoint. Where a
Recipe needs to publish an endpoint, declare it as a
static value or as an `.infra` / `.values` reference, and treat the workload's own
endpoint as a separate declaration. When both express the same address, that
duplication is a single-sourcing hazard — put the address in one `infra` or
`values` key and have both read it, rather than repeating the literal twice.

**On the `helm` target, build every published name from the rendered name.**
Unlike the three rules above, no build enforces this one. The helm provider names
everything it synthesizes for a node — the Deployment or StatefulSet, every
Service, every claim — from `.context.rendered_name`, the node's release name, so
a Service is `<rendered name>-<service key>`. Build every `provides` value that
names one of those resources — a `host`, an `endpoint`, a Service name — from the
same key, keeping the service-key suffix:

```yaml
provides:
  host: "{{ .context.rendered_name }}-default"
  endpoint: "http://{{ .context.rendered_name }}-default:{{ .infra.port }}"
```

Never build such a value from `.context.instance_id`: that is the Component's
identity as written, and a Component's name may carry characters a Kubernetes
resource name refuses — an underscore, a capital — which the rendered name writes
out. A value built from the identity then names a Service that does not exist, and
no build catches it: the render succeeds either way. A name the Recipe writes
itself for an object it emits — an `artifacts:` entry's ConfigMap, say — is built
from the same key, and so is every reference to it, such as the volume that mounts
it, so the object and its references agree and the cluster accepts both. A
`locals:` entry cannot read `.context.rendered_name`, so each of those values is
built where it is used — a published value in `provides` itself, an artifact's
name in the artifact and in the volume — even where that spells the name twice.
This catalog's own checks refuse a synthesized `helm` Recipe whose `provides`
reads `.context.instance_id`, directly or through a `locals:` entry. They judge
`provides` alone, and they read authored YAML and render nothing, so they cannot
see an artifact's name or a wrong service-key suffix: keeping those on the key,
and confirming the published address against a Service the render really emits,
stays the author's to do.

**The rule binds a FeatureRecipe's composed names too.** On a FeatureRecipe
attached to a component, `.context.rendered_name` is the host component's name
as the host's own provider reports it — the value the host's Recipe reads — so
every name the attachment composes from its host is built from that key, never
from `.context.instance_id`: a resource the attachment emits, every value it
publishes naming one, and a resource of the host it points at, such as the
`<rendered name>-<service key>` Service a route forwards to. "Name an emitted
resource for the scope that carries it" below sets out how.

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

Where a reference realization names the address the Component declares as
`infra.endpoint` with no default, so the Release supplies it, the Recipe carries a
build-time `assertions` entry keyed `endpoint_supplied`, which halts when
`infra.endpoint` is unset or empty with a sentence saying what the address is for
that product and that the Release sets it. A build whose Release omits the
address, and a check of the Recipe on its own, then stop on that sentence rather
than on the Workload schema's refusal of a missing property. The key is the
checked key with `_supplied` appended, the naming `image_supplied`,
`subnet_group_supplied` and `external_base_url_supplied` follow for the image,
the database subnet group and the external base URL a Release supplies. This is a
catalog convention, not something the compiler checks: the compiler evaluates the
assertion's template and knows nothing of what the key means.

The credential slot is filled by a referenced credential — the
`core/referenced-secret` Feature — rather than a provisioned one, and the
realization the Manifest binds decides whether the secret material stays outside
the Release. On helm, `k8s-existing-secret` points at a Secret that already
exists and `k8s-external-secret` has a secret-store operator fetch the
credential into one, so neither writes the material into the rendered output;
`k8s-secret-from-parameter` writes it in, which suits evaluation only.
`core/referenced-secret` has no compose realization, because the target has no
secret-reference primitive (see "What the `compose` target expresses" below):
there the credential arrives on the inject pipe, and a `core/secret-value`
attachment bound to `dotenv-secret` keeps the material out of the emitted file
when its origin is a Compose variable reference such as `${DB_PASSWORD}`. An
optional governance Feature can ride the same edge to carry policy context for
the referenced resource without coupling it to provisioning.

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
  sources the project's upstream install chart), declared in the same Aggregate
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
slot still publishes its resource's locator to the Recipe — the name of the Secret
the credential's realization emits, or of one that already exists — so the recipe
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
| `containers.<n>.health` | **One healthcheck per service.** Of the probes a container declares, `live` is translated, else `ready`, else `startup`, and a warning names the ones dropped. The check runs **inside the image**: an `http` probe becomes `curl -f` against the port whose name sorts first and a `tcp` probe becomes `nc -z`, both through the image's shell, while an `exec` probe runs its command directly. A `depends_on` entry derived from a `uses` edge has `service_started` semantics, so it orders start-up and does not wait for the target to report healthy. |
| `initContainers` | **Realized** as a companion service the main service waits on, through `depends_on` with `service_completed_successfully`. |
| `services.<n>` | A `NodePort` or `LoadBalancer` entry publishes its ports on the host. A `ClusterIP` or `Headless` entry publishes nothing, so a port an operator sets reaches no emitted byte. |
| `replicas` | **Dropped, with a warning** naming it. |
| An attached credential | Arrives on the inject pipe and is delivered as a **literal environment value** in the emitted file, written as the credential delivered it — so the material sits in the artifact, unless the delivered value is itself a Compose variable reference such as `${DB_PASSWORD}`, which Docker Compose substitutes from the shell environment or a `.env` file when the stack starts. The target has no secret-reference primitive for a `secretKeyRef`-style pointer to resolve, so neither credential Feature that publishes only a locator — `core/referenced-secret`, `core/referenced-secret-set` — has a `compose` realization, and attaching one the Manifest leaves unmapped halts the build. |
| `containers.<n>.lifecycle`, `containers.<n>.envFrom` | **The build halts.** The target has neither primitive, and dropping either silently would change what the Release means. |

Two consequences for a Recipe author:

- **A single configuration file is realizable on this target; a directory of them is
  not.** Where a component exposes both — a raw configuration block and a map of
  bootstrap scripts — the `compose` Recipe can realize the first and cannot realize
  the second. Say so on the component's own value description, where a developer
  reads it, rather than in a Recipe comment.
- **The volume-size row is the knob rule's standing exception**, and it is named
  rather than silent: see the datastore family template below.

### Health checks on server workloads

A Recipe realizing a Component whose `component.aggrega.ai/type` is `server` or
`stateful-server` declares the health checks its product documents. Without a
readiness probe a rollout counts a container ready as soon as it has started, which
for a slow server can be well before it answers a request. **This is a catalog
convention, not something the compiler checks:** a workload with no `health` block
renders exactly as authored.

- **Readiness at least, a startup probe where the product documents one, and a
  liveness probe whose delay and threshold fit the product's start time.** Each
  endpoint comes from the product's own documentation, or from its own chart or
  release manifest at the release the Recipe runs — never from a guess — and so does
  each timing wherever the product states one; the comment beside the probe says
  which. Where the product's own guidance declares no liveness probe, the Recipe
  declares none either.
- **A product that documents no health endpoint takes a `tcp` probe on its serving
  port.**
- **An `http` probe is sent to the container port whose name sorts first
  alphabetically,** because the probe carries a path and no port (see the
  [Workload reference](https://github.com/aggrega-ai/aggrega-docs/blob/main/language-reference/entities/workload.md)).
  A product serving health on a second port is reached in one of three ways:
  declare that port under a name that sorts first and publish it on no Service, as
  [`recipe/helm/keycloak`](../aggrega-catalog/recipe/helm/keycloak/1.0.0/recipe.yaml)
  does with `management` beside `tcp`; use a `tcp` probe; or use an `exec` probe
  running a client the image carries. **Never rename a port a Service, a Feature
  default or a consumer already names** to make it sort first.
- **On `compose` a service carries one healthcheck, and it runs inside the image**
  (the health row of the table above). A compose Recipe declares one `ready` probe:
  a second slot reaches no output and only adds a warning to every build. Establish
  that the image carries the tool the check runs before declaring it — a check whose
  tool is missing reports a healthy container unhealthy for ever while every build
  stays green. Where the image carries no shell, client or socket tool and the
  product ships no health command, the Recipe declares no healthcheck rather than
  one that cannot run.
- **A chart-wrapping Recipe inherits the chart's probes,** read from a real build.
  Where the chart leaves a workload that serves requests without a readiness probe,
  the Recipe sets the chart's own probe values to add one; a probe the chart has no
  value for is not forced.
- **A Recipe that installs a controller authors the controller's own probes** in
  the manifest it emits — the ones the project's own chart or release manifest gives
  that controller at the release its image comes from. A controller that, as the
  Recipe runs it, registers no health check takes a `tcp` probe on its serving port.
- **A Recipe that emits a custom resource leaves the probes to the controller that
  creates the pods.** Where the resource exposes a probe field and the controller
  already fills it, the field stays unset.

### The address a server is reached at

Some servers write their own address into what they hand out: an identity server
into every token it issues, a dashboard into every link and every redirect after
sign-in, a registry into the pull commands it shows, a workflow server into the
webhook addresses it publishes, an object store or a secrets server into the API
address it hands its clients. Left unconfigured, such a product typically falls
back to an address it derives for itself — from the request that reached it, from
its own host name, or from `localhost` — and behind an ingress that is rarely the
address a client outside the cluster uses. **This is a catalog convention, not
something the compiler checks:** the compiler pipes the authored address as a
string and resolves nothing about it.

- **The Component declares the address as `infra.external_base_url`** — one name
  for the concept across the catalog, whichever product it configures. It sits in
  `infra` because it is the address as assembled at the ingress tier, which
  differs for each environment the same Aggregate lands in, so the Release sets
  it. Its description says what the product composes from it and what the Recipe
  falls back to when it is omitted. It is the base URL an ingress assembles; an
  address of another kind — the domain a controller gives the routes it serves,
  or a media address handed to real-time clients — is not this key.
- **Every Recipe of that Component honours it, or refuses the build naming the
  key.** A Recipe honours it through whatever setting its product reads — an
  environment variable, a flag, the chart's own value — and says in its
  description, and in a comment beside the setting, which one. A Component whose
  address one Recipe honours and another silently drops breaks the knob rule
  above.
- **Adding the key changes no existing render.** While the key is unset a Recipe
  emits nothing for it — or, where a chart always carries the setting, gives it
  exactly the value it rendered before — so a Release that does not set the
  address renders byte for byte as it did before the Component offered it.
- **The address never moves where the server serves.** The server serves its
  routes in the same place whether the key is set or not, and the ingress in
  front of it maps the address's path onto them, so its health checks and every
  consumer that composes its address from its published host and port reach it
  exactly as before. Where the product would otherwise move its routes under the
  address's path, the Recipe also sets the product's own setting that keeps them
  in place — the Prometheus and Thanos Query Recipes pass `--web.route-prefix=/`
  beside the address. Where the product cannot honour a path at all — it takes an
  origin only, or drops the path from the address it advertises — the Recipe
  refuses an address carrying one, with a build-time `assertions` entry naming the
  key, rather than advertising an address other than the one authored. A path of
  `/` alone is not a path.

### The certificate an entry point presents

An entity that terminates TLS for traffic arriving from outside the cluster names
the certificate it presents as **`infra.tls_secret`** — one name for the concept at
every scope it appears: the ingress Feature for the Ingress it emits, a gateway
Component for its listener. The value is the name of an existing Secret of type
`kubernetes.io/tls` in the namespace the resource naming it lands in, and the
realization **references it and never issues it**: it emits neither that Secret
nor a request for a certificate, so the Secret is the operator's, or a certificate
controller's, to provide. Every realization honours the key or refuses the build
naming it, and while the key is unset it emits nothing for it, so a Release that
names no certificate renders byte for byte as before. This is a catalog
convention, not something the compiler checks: it pipes the Secret's name as a
string and knows nothing of what the Secret holds.

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
  target deploys. **`storage.type` declares no default: the class defaults to the
  cluster's own.** On a Kubernetes realization it is the volume's storage class, and
  the claim names one only when the Release does: a claim that names no class is
  provisioned from the cluster's default storage class, while an empty class asks for
  a volume with no class at all. The helm workload synthesis omits an empty class on
  its own; a Recipe handing the key to a chart or a custom resource guards the line
  with `{{- with … }}` rather than rendering it empty. On a managed realization the
  same key is the provider's volume type, and each managed Recipe supplies its own
  fallback where it renders the key.
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
  socket. The tell is a required model edge: an orchestrator is indifferent
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

### What earns a Feature: two independent products in the field

A Feature is an attachment that brings something — resources, a pipeline step,
wiring an operator attaches deliberately — and **it earns its name when at least
two independent products in the field realize the capability it declares.** The
products counted are products in the world, established from their own current
configuration references, and not the components this catalog happens to ship: a
capability two gateway products implement is portable whether the catalog carries
one of those gateways, both of them, or neither.

What the catalog ships is a separate question, answered one product at a time. A
Feature may be declared before anything here realizes it — attaching it then halts
the build naming the type, which is the honest state for a control no
FeatureRecipe realizes — and it may be realized on one component or on several. Each realization is a FeatureRecipe for one product that honours the
Feature in that product's own terms.

The AI gateway controls `core/semantic-caching`, `core/period-budget` and
`core/response-validation` show that answer gateway by gateway.
`core/gateway/litellm` realizes the period budget, and the semantic cache on a
`core/datastore/redis` wired to its `cache_store` socket.
`core/gateway/cloudflare-ai-gateway`, Cloudflare's hosted gateway, realizes the
period budget through its terraform Recipe, as a spend-limit rule on the
gateway's own resource, and not the semantic cache: its cache answers only a
request identical to an earlier one. Its helm and compose Recipes reference a
gateway configured elsewhere and realize neither. `core/gateway/kong` runs
Kong 3.9.3's open-source image, which carries neither a semantic cache nor a
period budget, Kong offering both in its enterprise edition only, and
`core/gateway/tyk` runs Tyk v5.14.0's gateway, which carries neither, the
budget of Tyk's separate AI Studio being enforced in its enterprise edition
only; so neither gateway realizes either Feature. APISIX at 3.18.0 carries a
semantic cache and a budget counted in tokens, and the Envoy AI Gateway such a
budget, in their open-source builds, but no Recipe here routes model traffic
through either. Envoy Gateway on its own, Contour and NGINX offer none of the
three. No gateway in this catalog checks a reply against a schema the operator
sets, so `core/response-validation` is realized nowhere.

`core/concurrency-limit`, the AI gateway control declaring a cap on the
requests a gateway carries at once across everything it serves, is realized
nowhere either. The proxy `core/gateway/litellm` runs can cap the requests in
flight for each entry of its model map, but holds no cap on their total, so
that gateway carries no realization; and no Recipe of
`core/gateway/cloudflare-ai-gateway` writes such a cap: the request limit its
terraform Recipe writes into the gateway's resource is a rate, a number of
requests over an interval.

`core/prompt-injection-shield` is answered the same way, on the two gateways
whose Recipes render the one route their model traffic takes.
`core/gateway/litellm` and `core/gateway/nginx` realize it by sending that route
through the guard wired to the gateway's `guard` socket, a
`core/security/nemo-guardrails` that checks each chat request with a trained
classifier and forwards what it admits to the model: on the AI gateway, every
entry of the model map is addressed to the guard; on NGINX, its one location
forwards to the guard in place of the upstream. Each realization halts the
build unless the guard's threshold is the one the attachment's sensitivity
names. The Feature selects `component.aggrega.ai/category=gateway`, because all
it needs of a gateway is that it forwards to an address it is configured with.
Every other gateway here renders no route a realization could send through a
guard — it keeps its routes in a store of its own, takes them from the
applications behind it, or is a hosted service — and realizes none.

**A capability that only one product in the field has is not a Feature.** It is a
value on that product's own Component, where an operator sets it and reads it beside
everything else that configures the product. A Recipe may declare `spec.pipeline`
of its own, driven by the values and infrastructure the component was authored
with, so that is where such a value is written into the product's configuration.

Counting the field rather than the catalog has three consequences for how a
Feature's options are authored:

- **Derive the options from what the products implement.** Read how the products
  realize the capability and declare the shape they share. Do not compose an ideal
  set of options first and then look for products to realize it.
- **One product's inability to honour an option is not grounds to drop it.** Where
  two or more products ship a capability under names that group — one product calls
  it cost-based routing, another balances on the lowest usage counted in cost, a
  third sorts providers by price — the option is portable and the Feature keeps it.
  A realization for a product that cannot honour the option refuses that value at
  build time and says why; it never accepts the value and ignores it.
- **An option no product implements is dropped**, rather than kept so the set reads
  as complete.

**This is a convention catalog authors uphold, not something the compiler
enforces.** The compiler validates a Feature against its schema and pipes strings,
so a Feature declaring options no product implements passes every gate and ships.
The judgement stays with the author and the reviewer.

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
# The host part is the host's rendered name, which the helm provider spells in
# the characters a Kubernetes name allows. The attachment name may be authored
# with underscores, which a Kubernetes resource name cannot carry, so it is
# folded to hyphens.
name: '{{ .context.rendered_name }}-{{ .attachment_name | replace "_" "-" }}'
```

Composing the host alone is enough where the chart already suffixes the resource
per kind. Composing the *attachment* name as well is what keeps one Feature
attached twice to a single component, under two names, from colliding with itself.

**On the `helm` target the host part is `.context.rendered_name`, never
`.context.instance_id`.** This is "build every published name from the rendered
name", the rule a Recipe follows, applied to an attachment: on a FeatureRecipe
attached to a component, `.context.rendered_name` is the host component's name as
the host's own provider reports it, the value the host's Recipe reads. A
component's name may carry an underscore or a capital, which a Kubernetes resource
name refuses and the rendered name writes out; a name built from the identity
renders without complaint and is refused only when the Release is applied, so no
build catches it. The rule reaches every name an attachment composes from its
host:

- a resource the attachment emits — a Secret, a ServiceAccount, a route, a policy,
  a ServiceMonitor;
- every value the attachment publishes naming such a resource, so the name a
  consumer reads and the name the render emits are one string;
- a resource of the host the attachment points at — the Service a route forwards
  to, `<rendered name>-<service key>` for a workload the helm provider synthesizes,
  or a gateway the host's Recipe names from its rendered name.

A label value is not a resource name. A selector that matches a label on the
host's resources reads what that label carries, and on a Service the helm
provider synthesizes, `app.kubernetes.io/name` carries the component's identity,
so such a selector keeps reading `.context.instance_id`. Unlike a Recipe's, an
attachment's `locals:` entries read the host's rendered name, so a name the
attachment both emits and publishes is derived once there. Where the host's
provider reports no name — a helm Recipe that places an artifact set alone — the
key is empty, and reading it from the attachment's inline templates, other than
its `injectMapping`, halts the build; an attachment carried by such a host names
its resources from the identity.

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
  sa_name: '{{ default (printf "%s-%s" .context.rendered_name (.attachment_name | replace "_" "-")) .infra.service_account_name }}'
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

### Pinning upstream keys is all-or-nothing on a gateway that stops verifying chains

A gateway may stop verifying certificate chains for every upstream once any
upstream is pinned; `core/gateway/tyk` does. On such a gateway, a Release
attaching `core/upstream-key-pinning` names every upstream the gateway reaches
or none of them: each upstream carries an entry of its own, or is covered by a
`*` entry. An upstream left out is reached with nothing verified at all rather
than verified less strictly.

Nothing checks this and a Release may leave an upstream out — the entries are
text carried through to the gateway, so a half-filled set renders as willingly
as a complete one. What pinning does on a given gateway belongs on that
gateway's realization of the Feature; the convention is here because a
realization's description answers what its gateway does and this is a property
of the whole set.

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

**A version also records the bytes its pinned inputs had when it was
published.** A Recipe or FeatureRecipe that reads a remote `source:` written out
in full, or a file an `artifacts` entry imports with `$import`, carries a pin for
each in the `entity.lock` beside it, and that file sits inside the version
directory the digest covers. `aggrega push` refuses such an entity until its lock
records every pin the pin step, `aggrega pin`, would record at that moment, so
the published version carries those digests. An upstream that later serves
different bytes under the same source version does not slip in under the same
entity version: a republish refuses the pin that no longer matches, and pinning
again changes the lock, which is a content change like any other and is published
under a new version. A source whose coordinates are filled in from a template
names an artifact only once a Release fills it in; its pin lives in that
Release's lockfile, outside anything the entity's version covers.

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
at a distinct location. The entity and its `.wasm` publish as one OCI manifest:
the entity is the manifest's config and the `.wasm` is its single layer.

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
