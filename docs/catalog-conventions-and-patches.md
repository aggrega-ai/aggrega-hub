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
| `storage` | Object/file storage: a bucket reached over the S3 API (`core/storage/s3-object-store`), on Amazon S3 or Google Cloud Storage or on a SeaweedFS server the Release runs; a managed bucket reached through Google Cloud Storage's own API (`core/storage/gcs`); and the backup controllers that copy a cluster's resources, or its volumes' files, into such a bucket (`core/storage/velero`, `core/storage/k8up`) | server, resource | populated |
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
`vector` and `core/datastore/redis` carries `kv`. An extension counts as
identity when the component pins an image that carries it and every Recipe
enables it: `core/datastore/pgvector` runs the pgvector project's own PostgreSQL
image and creates the extension in the database it starts, so it carries
`vector` on its base, while `core/datastore/postgres` carries no engine value. A
search and analytics engine that also indexes vectors carries `search`: its
identity is search over the documents it indexes, which `vector` would
misdescribe, and every vector-store socket in the standard library admits it
beside `vector` and `semantic-memory` by selecting
`datastore.aggrega.ai/engine in (vector, semantic-memory, search)`. A socket
that must admit only vector stores selects `datastore.aggrega.ai/engine=vector`
instead. A capability whose truth depends on what the Aggregate declares carries
no label anywhere in the catalog — it is injected at compile time by the governance
socket's `label-transform` role, which reads the developer's declared `values`.
There is no stored "is-AI" boolean — tooling derives AI-relevance from any
`ai-`-prefixed category or AI-relevant capability value.

The category-vs-directory mirror is checked by the publishing linter's
`category-matches-directory` rule (warning at `aggrega lint`, error at
pre-publish, per-workspace opt-out for enterprise layouts). The compiler
itself is agnostic to all label vocabulary; the closed set is a standard-library
convention enterprises may extend or replace in their own catalogs.

### The `component.aggrega.ai/hosting` label

`component.aggrega.ai/hosting` records who operates a component's underlying
resource — the trust-boundary axis a policy engine reads to reason about data
exfiltration and ownership. It is a **cross-cutter**: the same three values
describe a managed database, a managed LLM API, and a self-run inference server
alike, so the label lives under the shared `component.aggrega.ai/` namespace
rather than any one category's `<role>.aggrega.ai/` capability namespace. The
value set is a standard-library convention (the compiler is agnostic to it):

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
| `content-masking` | `entity-recognition`, `pattern-list` | The component can replace sensitive text in the chat and completion payload it is routing with a placeholder before the text travels further. The value names the fidelity. `entity-recognition`: it replaces matches of patterns supplied in its configuration and also entity types that a recognizer service it calls detects. `pattern-list`: it replaces matches of patterns supplied in its configuration and recognizes no entity types. |
| `prompt-guard` | `pattern-list`, `classifier` | The component can inspect the chat and completion payload it is routing and refuse a request on its content. The value names the fidelity. `pattern-list`: the match is against patterns supplied in its configuration. `classifier`: the verdict is a trained text classifier's, reached through a detection service the component calls, against a threshold supplied in its configuration. The dimension is deliberately narrower than content inspection in general — a component here reads the model payload it already parses to route, and not one of them inspects an arbitrary HTTP body. |
| `upstream-tls` | `trust-anchor` | The component can require the service it forwards to present a certificate chaining to a trust anchor the Release supplies. |
| `upstream-pinning` | `public-key` | The component can refuse a service it forwards to unless a certificate that service presents carries one of the public keys the Release supplies for it. `public-key` names what is pinned: the key itself, so a certificate renewed over the same key still matches. |
| `period-budget` | `cost`, `tokens` | The component can refuse model requests once what it has counted over a period exceeds a limit set in its configuration, and the value names what it counts. `cost`: what the traffic cost, priced from a table the component keeps per model. `tokens`: the tokens each model's reply reports reading, writing or both, which the component counts and prices nothing. |
| `concurrency-cap` | `total`, `per-target` | The component can hold or refuse a request that would take the requests it is carrying at once past a cap set in its configuration, and the value names what one cap counts. `total`: every request the component forwards, whatever it forwards it to, against one cap. `per-target`: one cap for each upstream target the component sends to, each counting the requests in flight to that target, and none on their total. |

Three rules bind the family:

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
`upstream-tls: trust-anchor`, `concurrency-cap: total`), `core/gateway/contour`
(`request-mirroring: sampled`, `caller-identity: client-certificate`,
`upstream-tls: trust-anchor`), `core/gateway/envoy-gateway` (the same three,
`period-budget: tokens` and `concurrency-cap: per-target`), `core/gateway/kong` (`upstream-tls: trust-anchor`,
`prompt-guard: pattern-list`), `core/gateway/tyk`
(`upstream-pinning: public-key`), `core/gateway/litellm`
(`caller-identity: injected-header`, `content-masking: entity-recognition`,
`prompt-guard: pattern-list`, `upstream-tls: trust-anchor`, `period-budget: cost`, `concurrency-cap: per-target`),
`core/security/nemo-guardrails` and `core/security/trustyai-guardrails-gateway` (each
`prompt-guard: classifier`). Of these, `core/gateway/litellm` and
`core/gateway/envoy-gateway` carry `gateway.aggrega.ai/intelligence: semantic`
and the others carry no value of it — and
that mixture is the separation working rather than an exception to it. The
intelligence label names a **product tier** — whether the router parses the
request body — while this family names **capabilities**, so the two answer
different questions and a component may honestly carry both. What a component's
tier value never tells a reader is which of these capabilities it has: the AI
gateway carries several of them, and no amount of reading its tier would say so.
`core/gateway/cloudflare-ai-gateway`, Cloudflare's hosted AI gateway, carries
`period-budget: cost`, its one value in this family, and `semantic`.
`core/gateway/apisix` carries `period-budget: tokens`, `prompt-guard:
pattern-list`, its `ai-prompt-guard` matching a request's messages against the
lists its configuration holds, and `semantic`, because its AI proxy reads the
request body of every route it serves a model on. `core/gateway/kong` carries
`prompt-guard: pattern-list` for the AI Prompt Guard of Kong 3.9.3, which matches
the text of a model request — every message of every role, or a completion's
prompt — against the lists its routes hold; Kong Gateway
Enterprise documents the same plugin, but how much of a request it reads changes
across the releases a Release may name there, so `core/gateway/kong-enterprise`
carries no `prompt-guard` value. On
`core/gateway/envoy-gateway`, the tokens its `period-budget` value names are the ones Envoy AI Gateway reads from each reply
of a wired model, which Envoy Gateway's rate limit counts, and the targets its
`concurrency-cap` value counts apart are the backends of its route rules, one
for each wired model; on `core/gateway/litellm` they are the entries of its
model map, typed by hand or wired.
`core/gateway/kong-enterprise` carries `period-budget: tokens`, the tokens
each reply reports as Kong's AI Rate Limiting Advanced counts them,
`content-masking: entity-recognition` and `semantic`. `core/gateway/traefik-hub`
carries `content-masking: entity-recognition` and `prompt-guard: pattern-list`,
its Content Guard middleware masking the matches of the patterns its
configuration holds or the entity types a Presidio analyzer it calls detects,
or refusing a request a pattern matches, `period-budget: cost`, priced from the
per-model price list its Token Rate Limit & Quota middleware ships with, which
can count the tokens each reply reports instead, and `semantic`.
`core/gateway/agentgateway` carries `content-masking: pattern-list` and
`prompt-guard: pattern-list`, its regular-expression guard masking or refusing
the matches of the patterns its configuration holds, `period-budget: cost`, the
budgets it keeps per API key in US dollars, priced from its model cost catalog,
or in tokens, and `semantic`.
`core/gateway/higress` carries `content-masking: pattern-list`, its
`ai-data-masking` plugin masking the matches of the patterns its configuration
holds in the text of a chat request's messages, `period-budget: tokens`, the
prompt and completion tokens each reply reports, counted together by its
`ai-token-ratelimit` plugin, and `semantic`.
`core/gateway/azure-api-management`, the AI gateway of Azure API Management, a
hosted service, carries `period-budget: tokens`, its one value in this family,
and `semantic`: its token limit counts the prompt and completion tokens each
reply reports, together, and keeps a separate count at each gateway of the
instance.

A component carrying `prompt-guard: classifier` is also something another
component can send its traffic through: `core/gateway/litellm` and
`core/gateway/nginx` each declare a `guard` socket selecting it, which
`core/prompt-injection-shield` routes the gateway's model requests through.
The selector admits both guards that carry the value, and each gateway's
realization of the shield halts the build on any guard but
`core/security/nemo-guardrails`, the one its two sensitivities are measured
on. `cache_store`'s selector admits the key-value stores too, and each of its
Recipes halts on a store that publishes no `vector_search`.

### The `security.aggrega.ai/text-anonymization` label

`security.aggrega.ai/text-anonymization` records which role a service plays in
masking sensitive data in text — finding the sensitive spans in a text and
reporting them, rewriting the spans it is handed, or doing both in one call —
and it is what a consumer's socket selects on to be handed the right address.
Where the work is split across two services, a consumer that masks text through
the pair calls both, so it declares a socket per role and each selector names
the value it needs; where one service does both, the consumer declares one
socket selecting it:

| Value | What the value asserts |
| --- | --- |
| `analyzer` | The component finds sensitive spans in the text it is sent — an entity type, a position and a confidence for each — and changes nothing. |
| `anonymizer` | The component rewrites the spans a caller hands it, by the operator the caller names for each entity type, and finds nothing on its own. |
| `sanitizer` | The component finds the sensitive spans in the text it is sent and rewrites them itself, answering with the rewritten text. |

The value names the role, not the interface. Components today:
`core/security/presidio-analyzer` (`analyzer`) and
`core/security/presidio-anonymizer` (`anonymizer`), which speak the Presidio HTTP
API; `core/gateway/litellm` selects them on its `pii_analyzer` and
`pii_anonymizer` sockets, and `core/gateway/traefik-hub` selects the analyzer
alone, on its `pii_analyzer` socket, because Traefik Hub's Content Guard, which
its chart Recipe writes for `core/data-masking`, replaces what the analyzer
finds itself. `core/security/kong-ai-pii-service` (`sanitizer`) speaks Kong's AI PII
service API, and `core/gateway/kong-enterprise` selects it
on its `pii_sanitizer` socket. The compiler routes the address a selected
component publishes and checks nothing about what answers there, so a component
carrying a value here that speaks a different API is refused by nothing and
fails when it is called; each socket's comment names the API its consumer
speaks. As with the data-path family, a value is added in the same act as the
first component to carry it.

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
| `anthropic` | Anthropic's Messages API answers at the published endpoint — Anthropic's own, or a server's implementation of it — so a consumer speaks to it as it would to Anthropic. |
| `gemini` | Google's Gemini API answers at the published endpoint, so a consumer speaks to it through Google's Gen AI client or that API's request shape. |
| `native` | The product's own model API answers there, and it is none of the APIs the values above name, so a consumer speaks that product's API, through its client or its request shape. |

Three rules bind it:

- **A model socket selects the key unless it needs one API.** The catalog's model
  sockets that take any model API — every agent's `model` but the five named below,
  `core/ai-tool/model-invocation`'s `target_model`, and `core/datastore/cognee`'s
  `extraction_model` and `embedding_model` — select
  `component.aggrega.ai/category in (ai-model, gateway), model.aggrega.ai/api`.
  The category requirement admits the two categories and the key requirement
  admits only the components among them carrying the label, so every model is
  admitted whatever its value, a gateway serving a model API is admitted, and a
  gateway serving none is refused by name. A selector's requirements all have to
  hold and its alternatives live inside one key's set, so no selector can admit
  an unlabelled model and a labelled gateway while refusing an unlabelled
  gateway — which is why every `ai-model` Component carries the key. A socket
  that needs one particular API names its value
  (`core/ai-agent/openai-agents-sdk`'s `model` selects `model.aggrega.ai/api=openai`
  and `core/ai-agent/claude-agent-sdk`'s selects `model.aggrega.ai/api=anthropic`,
  each SDK speaking that API alone; `core/ai-agent/mastra`'s and
  `core/ai-agent/agent-framework`'s select `model.aggrega.ai/api=openai`, the API
  whose variables their Recipes deliver; and `core/ai-agent/google-adk`'s selects
  `model.aggrega.ai/api=gemini`, the API whose key its Recipes deliver, with its
  category narrowed to `component.aggrega.ai/category=ai-model`, because ADK's
  client reads no address and would send a gateway's credential to Google's
  own address) — or,
  where a model it cannot
  use has somewhere else to go, admits the whole category and refuses the value
  in an assertion that says where. `core/gateway/litellm`'s `models` socket
  selects `component.aggrega.ai/category=ai-model`, and its Component's
  assertion halts on a connection whose target carries any value but `openai`,
  because the gateway describes a wired model to its proxy through the OpenAI
  API alone; the message names the connection and points at the gateway's
  hand-typed `values.models`, which takes such a provider in the proxy's own
  provider/model notation. The `models` sockets of `core/gateway/kong`,
  `core/gateway/kong-enterprise`, `core/gateway/apisix`,
  `core/gateway/envoy-gateway`, `core/gateway/traefik-hub`,
  `core/gateway/agentgateway` and `core/gateway/higress` select the same and
  each Component's assertion halts the same way, because each writes a wired
  model's route, or model entry, for the OpenAI API alone — the two Kongs,
  APISIX and Higress through their AI proxy, Envoy Gateway through the Envoy AI
  Gateway resources its Recipe renders, Traefik Hub through its Chat Completion
  middleware, agentgateway as an OpenAI-compatible provider in its
  configuration file.
- **A component carrying the key publishes what a model publishes:** `endpoint`
  and `model` in its `provides`, the two keys a consumer's Recipe reads off a
  model edge. One that published no `model` would hand its
  consumers an empty model name, and no build would report it. A gateway
  publishes one alias of its model map as its `model`, named by a value of its
  own and checked against the map by an assertion on its Component, so the order
  of the map never decides what a consumer asks for. A gateway whose every
  model is wired to a socket — `core/gateway/kong`,
  `core/gateway/kong-enterprise`, `core/gateway/apisix`, `core/gateway/envoy-gateway`,
  `core/gateway/traefik-hub` and `core/gateway/agentgateway`, each of whose
  `values.model` names one of its `models` connections, and
  `core/gateway/higress`, whose `values.model` names an alias those connections
  serve — serves none while nothing is wired there and then publishes both keys
  empty; it
  carries the key all the same, since the
  value names what the product serves rather than what one Release wires, so a
  consumer wired to it in that state reads an empty address and model name, and
  no build reports it.
- **A value is read off the product's own reference** — the routes the server
  the Recipes pin registers, or the API its documentation names — and is added
  in the same act as the first component to carry it, as with every label family
  on this page. It names the product's API, never a configured state: a model
  whose endpoint an operator may repoint keeps the value of the product it
  describes.

Components today: `core/gateway/litellm`, `core/gateway/kong`,
`core/gateway/kong-enterprise`, `core/gateway/apisix`, `core/gateway/envoy-gateway`,
`core/gateway/traefik-hub`, `core/gateway/agentgateway` and
`core/gateway/higress` carry `openai`, as do `core/ai-model/vllm`, `ollama`, `docker-model-runner`, `tgi`, `tei`, `nvidia-nim`, `litellm`, `openai`,
`openai-embedding`, `nvidia-api` and `openai-compatible` — the broker, whose
whole contract is to be pointed at a service speaking that API, and which stays
the handle for an endpoint the catalog does not model.
`core/ai-model/anthropic` carries `anthropic`, and `core/ai-model/gemini`
carries `gemini`. Every other `core/ai-model/*`
Component carries `native`. Each label's comment says, in its
product's terms, what answers at its endpoint. The compiler matches the string
and checks nothing about what answers at the address, so a component carrying a
value its endpoint does not speak is refused by nothing and fails when it is
called.

### The `gateway.aggrega.ai/extension-server` label

`gateway.aggrega.ai/extension-server` records whose extension protocol a
component serves: the protocol a gateway's control plane calls, at the address
the component publishes, to have the configuration it translates for its data
plane adjusted. It is a dimension of the `gateway.aggrega.ai/` capability
family beside `intelligence`, and it is what a gateway's socket for an
extension server selects on, so the socket takes a component serving that
gateway's protocol and refuses any other.

| Value | What the value asserts |
| --- | --- |
| `envoy-gateway` | The component serves Envoy Gateway's extension protocol over gRPC, so an Envoy Gateway control plane can call it as its extension server. |

The value names whose protocol is served, never a configured state: the
component serves it whether or not a gateway is wired to it. Components today:
`core/gateway/envoy-ai-gateway-operator` carries `envoy-gateway`, and
`core/gateway/envoy-gateway`'s `extension` socket selects
`gateway.aggrega.ai/extension-server=envoy-gateway`. The compiler routes the
address the selected component publishes and checks nothing about what answers
there. As with every family on this page, a value is added in the same act as
the first component to carry it.

### The `observability.aggrega.ai/` signal labels

`observability.aggrega.ai/<signal>` records that a component receives one
telemetry signal pushed to it, and over which protocol, at the address it
publishes. There is one key per signal — `traces`, `metrics` and `logs` —
because a label holds one value and a backend may receive more than one signal,
and the key is the same word as the socket that selects it. It is what an
OpenTelemetry Collector's signal sockets select on, so each socket takes the
backends for its signal and refuses every other.

| Value | What the value asserts |
| --- | --- |
| `otlp-grpc` | The component receives the signal over OTLP's gRPC transport, at the `host` and `port` it publishes. |
| `otlp-http` | The component receives the signal over OTLP's HTTP transport, at the base address it publishes as `otlp_http_endpoint`, to which an exporter appends the signal's own path, such as `/v1/logs`. |

Three rules bind it:

- **A collector's socket selects the key, never a value.**
  `core/observability/otel-collector`'s `traces`, `metrics` and `logs` sockets
  each select their key alone, so every component receiving the signal is
  admitted whatever its protocol, and one receiving only another signal is
  refused by the selector before anything renders. The collector's
  configuration writes the exporter the value names — `otlp_grpc` for
  `otlp-grpc`, `otlp_http` for `otlp-http` — and halts the build, naming the
  connection, on a value it writes no exporter for.
- **A component carrying `otlp-http` declares and publishes
  `otlp_http_endpoint`.** The path a product receives OTLP at differs by
  product — `/otlp` on Loki, `/api/v1/otlp` on Prometheus — so the component
  publishes the address and the collector keeps no table of paths. The key is
  declared on the Component, because a connection carries only the keys its
  target declares, and so every Recipe of that Component publishes it. One that
  receives the signal only on request publishes it empty while the request is
  off, and a collector wired to it halts the build, naming what to set.
- **A value asserts a capability, never a configured state**, as with every
  family on this page. `core/observability/prometheus` carries
  `metrics: otlp-http` although its OTLP receiver is off until its
  `values.otlp_receiver` turns it on: the receiver authenticates no caller, so
  it is a write endpoint an Aggregate opens deliberately, beside the wiring that
  needs it.

Components today: `core/observability/tempo` and `core/observability/jaeger`
carry `traces: otlp-grpc`; `core/observability/loki` carries `logs: otlp-http`
and publishes `http://<host>:<port>/otlp`; `core/observability/prometheus`
carries `metrics: otlp-http` and publishes `http://<host>:<port>/api/v1/otlp`
while `values.otlp_receiver` is true. The compiler routes the address the
selected component publishes and checks nothing about what answers there. As
with every family on this page, a value is added in the same act as the first
component to carry it.

### Where a component serves its Prometheus metrics

A component whose product serves metrics in the Prometheus format publishes
where, so a scraper reads that fact rather than guessing a port and a path.
`core/observability/prometheus` reads it off each connection of its
`scrape_target` socket, which admits any `server` or `stateful-server`. The
keys are declared in the Component's `provides` pillar, and every Recipe of it
publishes them — empty where that realization offers no such address. They
come in three shapes:

| Keys | What they hold |
| --- | --- |
| `metrics_endpoint` | The full address — scheme, host, port and path, an `http` or `https` URL with no query string — where one address reaches all of the product's metrics. |
| `metrics_service`, `metrics_service_port`, `metrics_path` | A Service the product already has, or a comma-separated list of them, the name of the Service port carrying the metrics, and the path — where every pod behind the Service serves them, as a server running more than one replica does. |
| `metrics_pod_selector`, `metrics_pod_port`, `metrics_path` | A label selector over the pods serving them, the name of their container port, and the path — where no Service carries them. |

Six rules bind them:

- **One shape per instance.** A Recipe publishes one shape and leaves the other
  keys empty. A model server publishes the Service facts only while its
  `replicas` is above one, and `metrics_endpoint` otherwise. Prometheus halts
  the build, naming the target, on a target publishing none of the three, an
  address beside a discovery fact, or both discovery kinds.
- **The host is published as the realization names it.** A Recipe publishes the
  bare name its realization gives the Service, and a consumer in another
  namespace qualifies it caller-side; a Recipe placing its objects in a
  namespace of its own, as the operators' raw manifests do, publishes the host
  already qualified, `<name>.<namespace>`. On Kubernetes Prometheus qualifies a
  host carrying no dot with the namespace its connection's
  `aggrega.ai/namespace` annotation names, where that differs from its own, and
  leaves every other host as published.
- **Metrics a product serves only on request take `metrics_enabled`.** One
  boolean in the Component's `values`, false by default, under the same name on
  every Component offering it: true turns the product's metrics on and, where
  needed, puts their port on a Service, and the Recipe publishes the address;
  false publishes the keys empty, even where the product keeps its metrics on
  internally. A realization that cannot honour true refuses it by name. The
  value's description states what else the metrics port serves with no caller
  check.
- **Discovery is Kubernetes'.** Prometheus's Kubernetes Recipes render a job
  that discovers the Service's endpoints or the selected pods, in the namespace
  the connection's annotation names. A Compose Recipe publishes
  `metrics_endpoint` or nothing, and Prometheus's Compose Recipe halts on a
  discovery fact, naming the target.
- **A credential is the connection's.** A target whose metrics answer only a
  scrape presenting a credential publishes `metrics_credential_required` true,
  as the annotation below describes; the connection carries the credential in
  its `credential` slot, which Prometheus presents as `Authorization: Bearer`,
  read from a file each of its Recipes delivers by reference, and a connection
  carrying none halts the build. That halt sits in Prometheus's Recipes rather
  than in a Component assertion, because an assertion sees a connection's
  attachments but nothing its target published, so `aggrega build` reaches it
  and `aggrega validate --release` does not.
- **A request parameter is the scraper's.** The address carries no query
  string. Where a product needs one, Prometheus sends it as a scrape parameter
  of its own: `format=prometheus` to `core/security/openbao`, whose connection
  it recognises by the target's Component.

The compiler routes these strings and checks none of the rules; they are this
catalog's, and Prometheus's Recipes are where a target breaking them halts the
build.

### The `observability.aggrega.ai/metrics-credential` annotation

`observability.aggrega.ai/metrics-credential`, under a Component's
`metadata.annotations`, states how the product's Prometheus metrics
authenticate: whether a scraper presents a credential, and which one. It is an
annotation rather than a label because nothing selects on it; `aggrega lint`
reads it, in the two rules below. A metrics scraper reaches the components it
scrapes through a socket named `scrape_target`, as
`core/observability/prometheus` does.

| Value | What the value asserts |
| --- | --- |
| `none` | The product serves its metrics with no credential, even while the Component's `api_key` slot is filled, so a scrape presents none. |
| `target-key` | The metrics take the key the Component requires of every caller, the one its `api_key` slot holds, so a scrape presents that key as any caller does. |
| `separate-token` | The metrics take a token of their own rather than the key the Component requires of its callers — one the running product issues, or one created or set for the metrics alone — so a scrape presents that token and never the `api_key`. |

Three rules bind it:

- **`target-key` and `separate-token` go with the provides key
  `metrics_credential_required`.** A Component annotated either way declares
  it, as a `boolean` in its `provides` pillar beside `metrics_endpoint`, and
  every Recipe publishes it: true exactly while a scrape of the
  `metrics_endpoint` that instance publishes must present a credential. A
  Recipe whose metrics are off publishes it false beside an empty
  `metrics_endpoint`. The annotation states the product's behaviour; the key
  states what one configured instance asks of a scraper, so neither stands in
  for the other. A Component annotated `none` declares no such key. The rule
  `metrics-credential-annotation-matches-provides`, which `aggrega lint` runs
  over each Component it checks, advises where a Component's annotation and its
  declaration disagree.
- **The annotation decides how a scrape connection is compared with the
  target's `api_key`.** The rule `connection-credential-matches-target-key`,
  described under "A key both ends of a connection hold" below, passes over a
  `scrape_target` connection whose target is annotated `none`, does not compare
  the connection's `credential` with the target's `api_key` where it is
  annotated `separate-token`, and judges it like any other connection where it
  is annotated `target-key` or not annotated at all.
- **A value states the product's behaviour at the version the catalog runs**,
  read from the product's source or documentation at that version, and is
  written only once it has been. A product that serves no Prometheus metrics
  carries no annotation.

For example, `core/ai-model/vllm` carries `none`, since vLLM serves its
metrics outside the routes its `api_key` guards, and `core/security/openbao`
carries `separate-token`, since OpenBao answers its metrics only to an OpenBao
token, which the running server issues. The compiler attaches no meaning to the
annotation, and the build checks neither rule.

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
product yield a single identifier: `open-core`, `proprietary`, `not-applicable`
and `mixed` describe situations no one SPDX identifier expresses, and the
convention is to state the field where a single identifier applies and leave it
absent where none does — so the label classifies entities the field says nothing
about. The two also sit on different kinds. The label is a Component-identity
key, while `metadata.license` is stated on Recipes as well, where it is the only
surface naming the terms of the software the Recipe realizes.

**A Recipe that vendors a published Terraform module names the module's
licence.** The service such a module provisions — a managed database, say — is
one the reader contracts for directly with its provider and never possesses, so
no identifier names its terms; what the Recipe does carry is third-party code,
the module it pins and writes into the output. So `metadata.license` carries the
module's SPDX identifier, with a comment beside it saying that it is the licence
of the vendored module and that the provisioned service is contracted for
directly. `recipe/terraform/postgres-rds-terraform-aws-modules` is the shape.

**The catalog file's own licence is a third surface: the per-file
`# SPDX-License-Identifier:` header.** It states the terms the YAML itself is
published under, which is a different question again from the licence, or the
class, of the software that YAML describes. `core/datastore/weaviate` carries all
three, and each says something the other two cannot: an `Apache-2.0` header over
the file, `metadata.license: BSD-3-Clause` over the database the file describes,
and `upstream-licensing: osi-approved` over the class that licence falls into.

The value set is a closed, single-valued standard-library convention (the
compiler is agnostic to it, as it is to every label). A Component carries one
value, and where its Recipes realize it under terms of more than one class that
value is `mixed`:

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
- **`mixed`** — the Component's Recipes run or call software under terms of
  more than one of the classes above, so which class covers a Release follows
  the Recipe its Manifest selects, as `mixed` states for `hosting`. Such a
  Component carries no `metadata.license`, since no single identifier applies,
  and its description and each Recipe's state the terms of what each
  realization runs. `core/datastore/redis` is this case: its container
  realizations run the Redis server under its AGPL-3.0 arm and its ElastiCache
  realizations Redis OSS under BSD-3-Clause, both `osi-approved`, while
  `recipe/terraform/redis-azure-managed` provisions Azure Managed Redis, which
  Microsoft offers under its terms of service, a `proprietary` relationship. A
  reader filtering on one of the other values does not match a `mixed`
  Component.

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

  **The NVIDIA NIM entities are carried without that test being applied to
  them**, so that a reader who holds an NVIDIA account can deploy NIM from the
  catalog. Two of their Recipes pin artifacts NVIDIA publishes under its own
  licence: `helm/nvidia-nim-chart` pins NVIDIA's `nim-llm` chart, whose licence
  file names `LicenseRef-NvidiaProprietary`, and `helm/nvidia-nim-operator`
  pins the NIM Operator's chart and image, which NVIDIA's NIM Operator
  documentation lists under the "NVIDIA AI Enterprise Software License
  Agreement". Using them needs that account and an NGC API key, under NVIDIA's
  licence terms. NVIDIA's own pages say so in their words. The chart's licence
  file: "Any use, reproduction, disclosure or distribution of this material and
  related documentation without an express license agreement from NVIDIA
  CORPORATION or its affiliates is strictly prohibited." The chart's NGC page:
  "The NVIDIA NIM Helm Chart is governed by the NVIDIA Software License
  Agreement and the Product-Specific Terms for NVIDIA AI Products." The
  operator's NGC page: "By pulling and using the containers from NGC, you
  accept the terms and conditions of this license." The operator's install
  page names its prerequisite as "An active subscription to an NVIDIA AI
  Enterprise product or be an NVIDIA Developer Program member." and says
  "Access to the containers and models for NVIDIA NIM microservices is
  restricted." The catalog distributes none of NVIDIA's artifacts: each build
  fetches the chart it names from NVIDIA's chart repository, a publication of
  either Recipe carries the Recipe and no chart, and every NIM image is the one
  the Release names.
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
`datastore.aggrega.ai/engine: kv`. A product that is an existing engine plus an
extension usually lands here too, sent by the pillar question rather than the
identity one: `core/datastore/timescaledb` and `core/datastore/pgvector` each
run an image of their own that carries the extension, addressed by a compound
tag — the extension's version beside the PostgreSQL major — so
`core/datastore/postgres`'s `engine_version`, a bare major version, would not
hold word for word, and each is authored standalone, with Recipes of its own.

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
nothing else, so an attachment the module does not make itself reaches a
component inside it only from the Release, which can attach it there through
the routing entry that places the module, one component at a time. The module
declares one parameter per distinct credential,
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
fulfills it, or the build halts. `core/harbor` does the same for its three keys
(see "A key with no development default"). The shape stops where
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
credential on the other. `core/keycloak`, `core/harbor`, `core/thanos`,
`core/apisix`, `core/livekit`, `core/agenta` and `core/dify` are the shipped
shape, the last two leaving credentials unattached for those reasons;
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
| The artifact the Recipe sources | the artifact kind | `mariadb-rds-module`, `prometheus-chart` |
| The publisher of a published artifact it sources, beside one of the same kind the catalog wrote | the publisher's name | `postgres-rds-terraform-aws-modules` |
| That the resource lives outside the Release | `external` | `postgres-external` |

A chart realization added beside an authored one is the common case of the
sourced-artifact row: the authored Recipe fetches nothing, so it keeps the bare name,
and the chart realization takes `-chart` — `prometheus-chart` beside `prometheus`.
Where a component comes to carry two chart realizations from different publishers, the
later one is distinguished by what actually tells them apart rather than by a second
generic suffix.

The publisher row is that case for a module. `mariadb-rds-module` vendors a module
the catalog wrote and keeps beside the Recipe; a Recipe that sources the RDS module
the terraform-aws-modules project publishes is told apart from it by that publisher,
after the managed product's own stem, so the RDS realizations still sort together:
`mariadb-rds`, `mariadb-rds-module`, `mariadb-rds-terraform-aws-modules`.

**Where no realization stands the component up with nothing already in place, none
of them takes the bare name and every one carries a distinguisher.**
`core/compute/function` is realized only through a scaling control plane or a
managed service, so its Recipes are `function-keda`, `function-knative` and
`function-lambda` and there is no plain `function` to be had.

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
  name: core/datastore/weaviate
  version: 1.0.0
  license: BSD-3-Clause
  description: >
    A Weaviate vector database.
  labels:
    component.aggrega.ai/type: stateful-server
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

Components with provider-specific knobs should include an open-map field under `infra:` — a stateful
component for its managed services' settings, and a stateless one whose realizations on a cloud provider's
container service run in a cluster, a network and a role the operator already holds, as `core/compute/server`
and `core/compute/worker` do for Amazon ECS. Each Recipe documents the keys it reads. A terraform Recipe names
each for the module input it sets, unless another terraform Recipe already reads the same concept under a
spelling of its own, which it then reuses — `subnet_ids` for subnets and `vpc_security_groups` for security
groups on the AWS Recipes; a CloudFormation Recipe names each for the property it sets, such as `Subnets`. A
realization that reads none of the keys, such as a synthesized Kubernetes workload, says so in a comment:

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

- **`engine_version`** — the running server or binary version. On synthesized and Compose targets it selects the container image tag; on managed-service targets (Terraform, CloudFormation) it selects the provider's engine version — an RDS `engine_version`, for example. It is the live version knob for the software the component runs.
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

A Recipe that sources a published Terraform module from its git repository writes
the tag out and reads no `source_version`, because a templated reference would
move the module's pin out of the Recipe's own `entity.lock` — "A published
Terraform module" under "Recipe Pattern" sets out why.

A Recipe that delivers code holding a Feature's guarantee into the product
honours `engine_version` only at the versions that code was proven at, as "A
guarantee held in catalog code pins the product version it was proven at" under
"Feature Pattern" sets out.

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
  `aggrega build --verify-determinism` renders twice and halts when the two renders
  differ, which is how such a value shows itself. Where the chart offers no setting
  that stops it generating the value — it renders the generated document whatever
  it is given — **leave that document out with `omits:`** and supply the value
  another way. The `helm/envoy-ai-gateway-operator` Recipe is the shape: in the
  mode where the Release names its own webhook certificate, the chart still
  renders a Secret under that name holding a certificate it generates, so the
  Recipe leaves that Secret out and the controller's pod mounts the one the
  Release names. An entry that stops matching after a chart upgrade — the document
  renamed, or no longer rendered — halts the build, naming the entry, so the entry
  is updated with the upgrade.

**Per-entity validation does not render a sourced Recipe, so its success says
less than it looks.** Validating a chart-backed Recipe reports that the render was
not attempted, precisely because resolving the chart is a separate step — so a
clean result there means *not examined*, never *examined and fine*. A sourced
Recipe is proven by a real build with the rendered output read, and by nothing
short of one.

#### A published Terraform module

**The same default holds on terraform.** A terraform Recipe sources an official —
or good, complete and maintained — published module wherever one exists and the
configuration Terraform loads from it calls no module from a registry. That
configuration is the module's root and each directory a local `source` (`./`,
`../`) reaches from it. The Recipe names the module by its git repository with the
`git-repository` source kind, at the tag the module is published under. It writes
the body otherwise — as an `artifacts:` body, or as a module kept beside the Recipe
— and its `description` says which test failed: not official, not complete, not
maintained, or calling a registry module.

- **The pin is the git commit.** A registry publishes each version of a module as a
  tag of the module's own git repository, and what it answers when asked to download
  a version is a git source at the commit that tag names. Terraform's dependency lock
  file records the providers a configuration selected and no module. So the pin is
  the one `aggrega pin` takes: it resolves the tag to its commit and records that
  commit and the digest of the repository's archive in the Recipe's `entity.lock`,
  and every build vendors exactly those bytes. The tag is written out: a `ref:`
  filled in from a template is pinned in each Release's lockfile rather than in the
  Recipe's own, so a module-sourcing Recipe offers no `source_version` knob.
- **A registry call is refused because `terraform init` would fetch it outside the
  pin.** A `module` block in the loaded configuration whose `source` is a registry
  address, or any other remote one, names a module Terraform downloads when the
  configuration is initialised, at whatever version it then selects, and neither the
  entity's lock nor Terraform's covers it. The build reports each such call as a
  warning; this catalog does not source a module that makes one. Calls made only from
  directories nothing loads — a repository's `examples/` or `wrappers/` — do not
  count. Those directories are vendored with the module all the same, because
  neither a repository's `.terraformignore` nor an `.aggregaignore` beside the Recipe
  narrows a fetched source.
- **A consuming terraform Recipe is a `source:` Recipe.** A sourced module publishes
  what a consumer reads through its `output` blocks, as `${module.<instance>.<output>}`,
  and that reference resolves only in the boundary's root configuration, where a
  consuming Recipe's `valuesMapping:` becomes the arguments of its own module block.
  An `artifacts:` body renders inside the component's own directory, where no
  module call is declared.

The module's own `required_providers` stays as its publisher wrote it, since a
vendored module is copied byte for byte; "One AWS provider constraint for every AWS
body" below covers how it composes with the catalog's own AWS bodies. Its licence is
recorded as "The `component.aggrega.ai/upstream-licensing` label" sets out for a
vendored module. `recipe/terraform/postgres-rds-terraform-aws-modules` and its MySQL
and MariaDB siblings are the shape: they source the terraform-aws-modules project's
RDS module, whose root calls only its own `./modules/` directories.
`recipe/terraform/valkey-elasticache`, `redis-elasticache` and `memcached-elasticache`
source the same project's ElastiCache module, whose root declares no module call at
all. `recipe/terraform/postgres-cloud-sql` and `mysql-cloud-sql` source the
terraform-google-modules project's Cloud SQL module, whose repository root holds no
module of its own: each engine is a directory under `modules/`, which the Recipe names
as its `module_subdir`. Such a directory is vendored alone, so it qualifies only where
it is whole — it declares no module call and no file in it reaches a sibling with a
`../` path — and the configuration Terraform loads is that directory. The same
project's Memorystore module fails the registry test: its `valkey` and `memcache`
directories each call `terraform-google-modules/project-factory/google` from the
registry, which `terraform init` fetches whatever inputs the call is given. So
`recipe/terraform/valkey-memorystore` and `memcached-memorystore` write their module
beside the Recipe, as `recipe/terraform/rabbitmq-amazon-mq` does for an Amazon MQ
broker, and their descriptions say why. `recipe/terraform/postgres-flexible-server`
sources the Azure Verified Modules programme's flexible server module, whose root
calls only its own `./modules/database` directory. The same programme's Azure
Managed Redis module fails the completeness test instead: it calls no module, but
it takes no persistence or access-key setting and leaves out eviction policies the
service offers, so `recipe/terraform/redis-azure-managed` writes its body rather
than refusing values the service can honour.

#### A CloudFormation template

**CloudFormation Recipes are written as fragments by default.** The reusable
CloudFormation units AWS publishes do not fit a build that pins what it reads: a
public extension or a registry module must first be activated or registered in the
account and Region that deploys it; a nested stack's `TemplateURL`, in AWS's
words, "must point to a template … located in an Amazon S3 bucket", which the build
does not read; and AWS's own samples repository says "these templates are not meant
to be production-ready". A
fragment carries only the resources the component contributes, and the provider
assembles it into the boundary's stack.

**A template worth reusing may still be sourced**, named as an exception by the
Recipe that sources it, with the reason in its `description`. The cloudformation
provider binds such a template's declared `Parameters` from the Recipe's
`valuesMapping`, at every `Ref` and `Fn::Sub` that reads them, and carries the
`Transform`s its contributors declare in the assembled stack where the stack can
carry them — as the provider page's "Values for a sourced template's parameters"
and "Top-level sections in the assembled stack" set out.

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
it under a stable name for the application's own code to read, and says so. Where
the value comes from a connection, that stable name is a default: the code is the
Release's, and an `inject:` block on the connection replaces the default with the
names that code reads, as the next section describes. A value with a named
consumer is not an inert declaration, even when the framework itself is not the
consumer; what makes it inert is nothing reading it, and that is the claim a
Recipe's comment has to get right.

### A component running the Release's own code takes `inject:` on its connections

A component whose Recipes run an image the Release supplies as its own code — the
catalog pins no image, `infra.image` carries no default, and the Component
describes the image as the Release's: an application built on a framework, a
tool's implementation, a generic compute primitive — runs code no Recipe can
know. It is the White-Box case of the injection contract
[`language-reference/vocabulary/topology-triad.md`](https://github.com/aggrega-ai/aggrega-docs/blob/main/language-reference/vocabulary/topology-triad.md)
describes. Which variable that code reads for a connection is its author's
choice, so the names a Recipe delivers a connection under are defaults, and the
author's `inject:` block on the connection replaces them. A component whose image
the Release only versions or mirrors — an operator, a gateway, a model server, a
guardrails server — is not such a component: its Recipe writes each connection
into the product's own configuration, under names the product defines.

- **Every socket such a Component declares admits `inject:`.** Its `usesSchema`
  entry carries `inject: [env]`, with `file` beside `env` only where every
  Recipe of the Component writes a pipe `file` entry as a file at the path the
  author names; where one cannot, the socket admits `env` alone and its
  description says why. A socket that declares no allowlist refuses any
  `inject:` block on its connections, so the allowlist is what opens the socket
  to the author. A socket the Component does not declare carries no allowlist
  at all, and a connection through it may dictate any mechanism.
- **A connection that dictates nothing gets the defaults.** The Recipe derives
  its variables from the connection's `provides` and delivers them under the
  names it chose, so a connection needs no `inject:` block to be complete.
- **A connection that dictates gets what it dictates, instead of the
  defaults.** For each mechanism and each name the connection's own entry lists
  — the Recipe reads them at `.context.uses.<alias>.inject.<mechanism>`, an
  empty map where the connection writes no `inject:` block — it delivers the
  resolved value at `.context.inject.<mechanism>.<name>`: any key the target
  publishes, under any name the code reads. It delivers none of the default
  variables it would derive from that connection's `provides`, so a dictated
  name equal to a default replaces it rather than colliding with it. Two
  deliveries stay on every connection, dictated or not: a variable the framework
  or SDK in the image reads by itself, which the Recipe's comment names as read
  by the target, since no code in the image would read a substitute; and
  whatever an attachment on the connection delivers, since such an attachment
  carries no `inject:` block of its own. An Aggregate dictates in the
  array-of-entries form:

  ```yaml
  api:
    type: core/compute/server
    uses:
      database:
        orders:
          target: db
          inject:
            env:
              - in: ORDERS_DB_HOST
                from: host
              - in: ORDERS_DB_PORT
                from: port
  ```

- **A dictated name equal to a name the Recipe renders itself halts.** The
  compiler halts on a key two inject sources deliver, and knows nothing of the
  names a Recipe writes, so the Recipe halts the build on a dictated name equal
  to one it writes — a variable the framework reads, another connection's
  default, an attachment's variable, a variable carrying one of the component's
  own values — naming the name, the connection that dictated it and what else
  delivers it.
- **A refusal about the default delivery applies to it alone.** Where a Recipe
  refuses because its default delivery cannot convey something — a store served
  over TLS alone, or over HTTPS, to code handed only its host and port; two
  connections on one socket whose default variables would share names — it
  refuses only on a connection taking that delivery. A refusal about the
  connection's own consistency — a certificate slot on a connection whose
  target serves no TLS, a required socket left unwired — stands on every
  connection.
- **Nothing is dropped.** A Recipe delivers every mechanism its target can
  deliver and refuses by name each pipe entry of a mechanism it cannot — an
  `arg` where it renders no command line, a `file` where the target offers no
  way to write one, a custom mechanism — naming the entry and the mechanism.
- **A `core/secret-value` attachment's value is written into the rendered
  workload in the clear.** Its realizations put the value as the author wrote it
  into the inject pipe, and the Recipe writes what the pipe carries: a container
  variable on Kubernetes, as in an Amazon ECS task definition. A secret that must
  stay out of rendered output takes `core/referenced-secret` or
  `core/random-password`, which publish only the secret resource's locator — its
  name and data key — so no value of theirs reaches the pipe.

The generic compute primitives — `core/compute/server`, `worker`, `task` and
`function` — are the worked example. They declare no socket, so every
connection from one is ad hoc and may dictate any mechanism, and they derive no
default from a connection, so a connection that dictates nothing delivers
nothing. Their Kubernetes Recipes deliver `env` entries as container variables
and `file` entries as read-only files from one ConfigMap, each mounted by
subPath, refusing a path that is not absolute or that lies beneath another
entry's; their Amazon ECS Recipes deliver `env` entries and refuse `file`,
because a Fargate task definition offers no volume whose content it supplies
itself; the server's and the worker's Cloud Run Recipes deliver `env` entries
and refuse `file`, because neither a service nor a worker pool offers a volume
whose content its configuration supplies itself, and refuse a dictated name
Cloud Run reserves for itself or cannot take; the server's and the worker's
Azure Container Apps Recipes deliver `env` entries, and `file` entries as
secrets of the app, each mounted alone at its path from one Secret volume,
refusing a path that is not absolute or that lies beneath another entry's, and
refuse a dictated name Container Apps sets in every app itself; and the
function's AWS Lambda Recipes deliver `env` entries and refuse `file`, because
a function's configuration offers no way to write one, and refuse a dictated
name Lambda reserves for itself or cannot take. Every one
refuses `arg`, because none renders a command line: each target takes what a
container is given to run in place of the image's default command, and that
command is the Release's. A dictated name equal to
`WORKER_CONCURRENCY` or `WORKER_QUEUE_DEPTH_HINT` while the worker's value is
set, to `TASK_TIMEOUT` while the task's timeout is set, or to `FUNCTION_RUNTIME`
halts.

This is a catalog convention, upheld by its Recipes. The compiler enforces two
parts of it and nothing else: a socket's `inject` allowlist, and the inject key
collision rule. What a connection receives, which names are defaults, which
refusals apply and what is refused by name are the Recipes' to uphold: the
compiler pipes what a connection's `inject:` block resolves to and knows nothing
of the names a Recipe expects or writes.

### A connection variable is read off the inject pipe as a map, and an absent one halts

A Recipe whose product reads its connection settings under names the edge must
deliver reads a connection's values — a backend's host and port, a sibling's
endpoint — from variables the edge's `inject:` block delivers, under names the
Recipe expects and the Aggregate writes on the edge. The render reads a variable
nothing delivered as an empty string wherever any other variable reached the pipe,
so a Recipe reading one directly as `.context.inject.env.<NAME>` builds green and
ships an address with nothing in it when the Aggregate leaves that name out.

So such a Recipe reads the pipe as a map,
`{{ $env := optional (default dict .context.inject) "env" dict }}`, and before it
uses any of those variables it halts when one is absent, naming the component
instance, the edge and its socket, every variable that edge leaves missing, and the
inject block that delivers them, in the form the Aggregate writes — for example
`inject: { env: [ { in: KONG_PG_HOST, from: host }, { in: KONG_PG_PORT, from: port } ] }`.
A socket whose variables the Recipe reads whether or not anything is wired to it
halts the same way when nothing is. Every read of those variables then goes through
that map, never through a dotted path: a template that also reads a name as
`.context.inject.env.<NAME>` finds it present and empty, and the check passes over
the very gap it exists to catch. Reading the map is also what tells a variable
delivered empty apart from one never delivered; whether an empty value is usable is
the Recipe's own judgement about its product. The `helm/nginx` and `helm/kong`
Recipes are worked examples. A Recipe for a component running the Release's own
code asks for no such names: it reads its defaults from the connection's
`provides`, so a connection writing no `inject:` block is complete, and it reads
the names a connection does dictate off the pipe the same way, as a map. This is a
catalog convention: the compiler pipes what the edge delivers and knows nothing of
which names a Recipe expects.

### Managed-service credentials

For Recipes targeting a cloud-managed service that keeps a credential of its own
(AWS RDS, say), prefer the provider's native managed-secret flag over a
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

Where the managed service keeps no credential of its own and takes one as an
argument — an ElastiCache Valkey replication group's AUTH token, say — a Terraform
Recipe takes it from `core/random-password`, as the module output reference
`terraform/random-password` publishes. The apply draws the value, the rendered
configuration names it without carrying it, and the value is kept in the
Terraform state. Another credential Feature either carries its value as text,
which would be written into the configuration, or carries none the service could
take, so such a Recipe halts on it, naming the slot, as it halts
on a generator setting the service refuses — punctuation outside the characters it
permits, a length it does not take.
[`recipe/terraform/valkey-elasticache`](../aggrega-catalog/recipe/terraform/valkey-elasticache/1.0.0/recipe.yaml)
is the shape.

Cloud SQL keeps no database password of its own either, and the module the
Cloud SQL Recipes source draws one itself when none is given.
[`recipe/terraform/postgres-cloud-sql`](../aggrega-catalog/recipe/terraform/postgres-cloud-sql/1.0.0/recipe.yaml)
hands the user `values.user` names the `core/random-password` reference when one is
attached to its `password` slot, and with nothing attached, or
`core/generated-secret`, leaves the module to draw the password at apply time; either
way the password is kept in the Terraform state and no rendered file carries it.
Cloud SQL for MySQL creates `root'@'%` with no password, so
[`recipe/terraform/mysql-cloud-sql`](../aggrega-catalog/recipe/terraform/mysql-cloud-sql/1.0.0/recipe.yaml)
takes its required `root_password` slot from `core/random-password` alone and halts on
`core/generated-secret`, which would leave root open. Azure Database for PostgreSQL
flexible server takes its administrator's password as an argument and neither it nor
the module the Recipe sources draws one, so
[`recipe/terraform/postgres-flexible-server`](../aggrega-catalog/recipe/terraform/postgres-flexible-server/1.0.0/recipe.yaml)
takes the optional `password` slot from `core/random-password` alone and halts with the
slot empty or on `core/generated-secret`.

A service that takes no password a Release supplies leaves the slot nothing to
carry, and its Recipe halts on any attachment, naming the slot and why.
Memorystore for Valkey authenticates with a token it generates for itself or with
IAM access tokens, so
[`recipe/terraform/valkey-memorystore`](../aggrega-catalog/recipe/terraform/valkey-memorystore/1.0.0/recipe.yaml)
runs the cache without authentication, gated by the private network alone;
Memorystore for Memcached offers no instance authentication at all, as ElastiCache
offers none for Memcached. Azure Managed Redis authenticates every client, with
Microsoft Entra ID tokens or with access keys it generates, so
[`recipe/terraform/redis-azure-managed`](../aggrega-catalog/recipe/terraform/redis-azure-managed/1.0.0/recipe.yaml)
halts on any attachment and the cache still authenticates with nothing attached.

A service that requires the credential halts with the slot empty, too, naming it,
where the Component's slot is optional and an unattached slot means a development
default on the self-hosted targets: a password every reader of the catalog holds
is not left on a managed endpoint, and the service may refuse it outright. An
Amazon OpenSearch Service domain's master user is the case:
[`recipe/terraform/opensearch-service`](../aggrega-catalog/recipe/terraform/opensearch-service/1.0.0/recipe.yaml)
hands the service the same module output reference as its master password, and
[`recipe/cloudformation/opensearch-service`](../aggrega-catalog/recipe/cloudformation/opensearch-service/1.0.0/recipe.yaml)
the dynamic reference below; both halt with nothing attached, the Component's
`apppass` being shorter than the eight characters the service takes. Both also
require `values.symbols: true` on the attachment, so the password holds an
upper-case letter, a lower-case letter, a digit and a punctuation character: the
service documents a length alone, and a password holding every class is accepted
whether or not it asks for one, while one without punctuation would fail every
apply if it does.

A CloudFormation Recipe takes the same credential as a Secrets Manager dynamic
reference to the secret `cloudformation/random-password` declares in the same
stack, composed with `Fn::Sub` from the reference that realization publishes —
`{{resolve:secretsmanager:${Secret}:SecretString:<key>}}` with `Secret` bound to
the secret's `Ref`, the form AWS's own templates compose a database password in.
CloudFormation resolves it when it creates the resource, so the template names the
secret and never carries the value, and the attachment needs no fixed secret
name.
[`recipe/cloudformation/valkey-elasticache`](../aggrega-catalog/recipe/cloudformation/valkey-elasticache/1.0.0/recipe.yaml)
is the shape.

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

### One AWS provider constraint for every AWS body

Every Terraform body the catalog authors for AWS — an `artifacts:` body, or a
module a Recipe vendors — declares `hashicorp/aws` in its `required_providers`
block, so the engine installs a provider whose resource schema the body was
written against rather than whichever release is latest. The constraint is **one
string, the same in every AWS body**, and it is a **range of the form
`~> <major>.<minor>`**, never an exact version: several AWS Recipes compose into
one boundary's root configuration, Terraform installs one provider version that
satisfies every module's constraint, and two exact pins that differ fail
`init`. The major and minor are those of the provider's current release when the
constraint is set, and never lower than the highest `hashicorp/aws` floor
declared by a published AWS module a catalog Recipe sources, so one installed
provider satisfies the catalog's own bodies and those modules together. Moving it
is one change made to every AWS body at once.

Each body carries the string itself, with a comment naming this section. A
library import cannot place a block inside an authored body — a MappingLibrary
entry is consumed by `valuesMapping:`, and an ArtifactLibrary bundle lands in a
sub-directory of the module, which Terraform does not read as part of it — and a
vendored module is copied byte for byte, so the repeat is deliberate and this
section is the one statement of the rule. The terraform RDS Recipes
(`recipe/terraform/postgres-rds`, `mysql-rds`, `mariadb-rds` and the two
`-module` Recipes) follow it. This is a catalog convention: the compiler pipes
the block as text and reads nothing in it.

A published module a Recipe sources is not a body the catalog authors, and it
keeps its publisher's own constraint: the terraform-aws-modules RDS module the
`-rds-terraform-aws-modules` Recipes vendor declares `hashicorp/aws >= 6.28`, the
ElastiCache module the `-elasticache` Recipes vendor `hashicorp/aws >= 5.93`, the
OpenSearch module `recipe/terraform/opensearch-service` vendors
`hashicorp/aws >= 6.51`, the MSK module `recipe/terraform/kafka-msk` vendors
`hashicorp/aws >= 6.40`, and the s3-bucket module
`recipe/terraform/s3-object-store-amazon-s3` vendors `hashicorp/aws >= 6.44`.
The highest of those floors is why the constraint above may not drop below it — in
a boundary holding both, Terraform installs one provider satisfying the catalog's
range and every module's floor together.

### One Google provider constraint for every Google body

The same rule holds for Google Cloud, with its own string. Every Terraform body the
catalog authors for Google Cloud declares `hashicorp/google` in its
`required_providers` block as **`~> 8.8`**, one string in every such body, carried
by each body with a comment naming this section, for the reasons the AWS section
gives. The major and minor are those of the provider's current release when the
constraint is set, and never lower than the highest `hashicorp/google` floor a
published Google module a catalog Recipe sources declares. The bodies that follow it
are the modules `recipe/terraform/valkey-memorystore`, `memcached-memorystore`,
`server-cloud-run` and `worker-cloud-run` keep beside them, which declare only GA
resources and so need no `hashicorp/google-beta`.

The Cloud SQL module the `-cloud-sql` Recipes vendor keeps its publisher's own
constraint, `hashicorp/google` and `hashicorp/google-beta` `>= 7.22, < 9` and
`hashicorp/random` `~> 3.1`, and so does the cloud-storage module that
`recipe/terraform/s3-object-store-gcs` and `recipe/terraform/gcs` vendor, with
`hashicorp/google` `>= 6.37.0, < 9` and `hashicorp/random` `>= 2.1`. In a boundary
holding a Cloud SQL instance, a Memorystore cache and a Cloud Storage bucket,
Terraform installs one `hashicorp/google` satisfying `~> 8.8`, `>= 7.22, < 9` and
`>= 6.37.0, < 9` together, a release from 8.8 below 9, one `hashicorp/google-beta`
for the Cloud SQL module alone, and one `hashicorp/random` satisfying both modules'
ranges. Moving the range is one change made to every Google body at once, and when
the major moves to 9 each vendored module's `< 9` ceiling has to move with it. This
is a catalog convention: the compiler pipes the block as text and reads nothing in it.

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

### A key with no development default

Some credentials are keys a product signs or encrypts with, where a default every
reader of the catalog holds would let anyone mint what the product trusts or read
what it stored. Those slots carry no development default. The Component declares
the slot `required: true`, so a build leaving it empty halts at load naming the
slot and the component type (`E0006`), before anything renders, and no Recipe
renders a value in its place. A chart Recipe that points its chart at the
credential by name also halts when the fill publishes no Secret name, since an
empty name would send the chart back to generating the key at render time; a
synthesized Recipe needs no such check, because the provider refuses a workload
reference to a fill that publishes none. An entity that follows this shape
applies it to every key the product signs or encrypts with and every secret its
own services authenticate to each other with, while a password stays an
optional slot with a development default — save a root password that opens what
the product trusts. The shipped slots are
`core/devtool/harbor`'s `token_key`, `core_secret`, `csrf_key`, `secret_key`,
`jobservice_secret` and `registry_http_secret`,
`core/observability/langfuse`'s `encryption_key` and `session_secret`, and
`core/ai-agent/librechat`'s `credential_encryption_key`, `session_secret` and
`session_refresh_secret`. The self-hosted realizations of
`core/storage/s3-object-store`, `helm/s3-object-store` and
`compose/s3-object-store`, keep the same rule for the store's key pair, whose
slots the Component declares optional because a managed service takes none:
each halts naming an empty `access_key_id` or `secret_access_key`. The Recipes
presenting a store's secret key as an S3 secret key — `helm/agenta-api`,
`helm/agenta-services`, `helm/langfuse`, `helm/langfuse-chart` and
`helm/thanos-store` — carry no default for it either: a store connection with
nothing in its `credential` halts the build, naming the connection, unless its
values set `unauthenticated: true`, and then no secret key is presented. A
module filling such a slot from a parameter declares the parameter required
with no default, as `core/harbor` does for
`csrf_key`, `jobservice_secret` and `registry_http_secret`. `core/agenta` and
`core/thanos` are the exception: each fills its object store's key pair, and the
store connections that present it, from two parameters — `store_access_key` and
`store_secret_key`, `s3_access_key` and `s3_secret_key` — each carrying a pinned
development default its description says is for evaluation only.

`token_key` holds the registry's token-signing key and its certificate in one
Secret, under `tls.key` and `tls.crt`, which the chart reads by name. No catalog
Feature generates a key pair in the cluster, so the Secret is created in the
namespace the registry runs in and `core/referenced-secret` bound to
`k8s-existing-secret` names it; a string-shaped key such as `core_secret` or
`secret_key` can instead be generated by the target through
`core/random-password`, with `key` set to the data key the chart reads.

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
password **value** (`postgres`, `valkey`, `redis`), the Component
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

A Recipe that renders its resource from an `artifacts` template rather than a
Workload writes the Secret volume and its mount itself, and the slot's
`inject: [file]` still states how the material is delivered. On a Knative
Service the mount is `readOnly: true`, which Knative Serving requires of a
Secret volume. A slot on a connection is delivered the same way:
`helm/agent-invocation-knative` mounts a `target_agent` connection's
`client_certificate` and `server_ca` (see "A key both ends of a connection
hold").

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
  because a password is often placed inside a URL or a connection string. The
  terraform and cloudformation realizations put at least one character of
  every class they draw from into the password — Secrets Manager by default,
  the `random_password` resource through its `min_upper`, `min_lower`,
  `min_numeric` and `min_special` settings — so with `symbols` on, a service
  requiring each class accepts it.
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
`core/generated-secret` take no locator and are not shaped this way. The locator
is the one Feature input either author writes; every other input has a single
owner, as "Who writes each input, and where a Feature is attached" under
"Feature Pattern" sets out.

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
convention no schema keyword marks. The publishing linter that `aggrega lint`
runs carries that comparison as the rule
`connection-credential-matches-target-key`, which `aggrega lint --release`
runs over the Release it names. For each connection whose target declares
`api_key` and is not a managed target (below), it reports a `credential` on
the connection with the target's
`api_key` unfilled, a filled `api_key` with no `credential` on the connection,
and two ends whose `origin` is written differently, and it never quotes
either. It reads `api_key` and `credential` and no other slot, so a target's
other secrets — `core/ai-model/vllm`'s `model_pull_token` — are never
compared, and a key slot named any other way draws no advice. A connection on a
`scrape_target` socket is compared as its target's
`observability.aggrega.ai/metrics-credential` annotation says, described with
that annotation above. The finding is advisory, and a workspace whose two ends
deliberately differ opts out with `allow_connection_credential_mismatches`.

**A managed target's `api_key` is the vendor's key, and the rule does not
judge it.** A Component labelled `component.aggrega.ai/hosting: managed`
stands for a service its vendor runs, so nothing the Release runs checks a key
on it. Where such a Component declares `api_key` — `core/ai-agent/bland`,
`letta`, `retell` and `vapi`, and `core/messaging/telnyx` and `vonage` — the
slot holds the key the Release
presents to that vendor, named as the vendor's product names it, like the
other product-named keys above, and never a key its callers present. The rule
therefore passes over every connection whose target carries that label. A
target labelled `self-hosted`, `external` or `mixed`, or carrying no hosting
label, is judged.

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
it as `KONG_PG_PASSWORD`, and which declares it on its `models` socket as well,
for the key it presents to each model it serves, delivered as
`AI_PROXY_<ALIAS>_API_KEY` and presented as the bearer token
`AI_PROXY_<ALIAS>_AUTHORIZATION` that the connection's routes read through
Kong's environment vault, a shape `core/gateway/apisix` repeats on its own
`models` socket under the same two names, its routes reading the token through
APISIX's `$env://` reference, and which declares it on its `cache_store` socket
for the password its semantic cache presents to the store, delivered as
`CACHE_STORE_PASSWORD` and read through the same reference — as do the cache
and object-store sockets of `core/observability/langfuse`, the sandbox and
plugin-runtime sockets of `core/ai-agent/dify`, and the media-server socket of
`core/messaging/livekit-sip`, where the slot is `required`. `core/gateway/litellm`
declares it on two sockets: on `models`, where each connection's credential is
the key the gateway presents to that model, delivered under a variable of its
own, `LITELLM_MODEL_<ALIAS>_API_KEY` — the connection's alias in capitals, every
character other than a letter or a digit an underscore — which that model's
entry in the routing table names; and on `cache_store`, where it is the
password the gateway's semantic cache presents to the store, delivered as
`REDIS_PASSWORD`. `core/gateway/envoy-gateway` declares it on two sockets as
well, with no `inject` list, since no container of its own receives it: on
`models`, where the connection's backend security policy names the Secret the
credential publishes and Envoy AI Gateway's controller reads the key from it
under the data key `apiKey`; and on `cache`, where it is the password Envoy
Gateway's rate-limit service presents to the store keeping a period budget's
count, handed to that service as `REDIS_AUTH` from the Secret the credential
publishes. `core/observability/prometheus` declares it on its `scrape_target`
socket, for the token it presents to each target it scrapes as
`Authorization: Bearer`, which its Recipes deliver as a file the scrape job
reads: a Secret mounted by reference on Kubernetes, and on Docker Compose a
variable the start-up command writes to the file. The name holds one
credential; it is a key a developer writes on the connection
(`uses.<socket>.<alias>.features.credential`) and an operator writes on a
connection the Release wires, so it is the same word on every socket.

- **Every Recipe reads it per connection.** It sits under the connection, at
  `.context.uses.<alias>.features.credential`, never among the Component's own
  `.features`. A synthesized Workload delivers it with `connection: <alias>`
  beside `from: credential`; a compose Recipe reads the value its credential
  writes on the inject pipe; a chart Recipe reads the locator it publishes, at
  `.context.uses.<alias>.features.credential.provides`, into the chart's
  existing-secret setting. A Recipe rendering its output from an `artifacts`
  template reads the same locator into a `secretKeyRef` it writes itself, as
  `helm/agent-invocation-knative` does; such a host has no
  `.context.rendered_name`, so a realization naming its Secret after the host —
  `k8s-external-secret`, `k8s-secret-from-parameter` — halts the build there,
  and `k8s-existing-secret` fills the slot. Each guards the delivery on the
  connection carrying one — `hasKey (default dict $edge.features) "credential"`
  — because an entry naming a connection with nothing in the slot is refused,
  and a connection carrying no credential renders exactly what it renders with
  no slot at all.
- **An optional socket whose unwired side reaches a provider keeps a Component
  slot for that side.** `core/datastore/cognee`'s `extraction_model` and
  `embedding_model` sockets are optional, and a socket left unwired reaches the
  provider the Component's `values` name, at that provider's own address, which
  no connection reaches. Each socket declares `credential`, and the Component
  keeps `model_api_key`, which its Recipe reads only for a socket left unwired:
  a wired socket's key is its connection's `credential`, never the Component's
  slot. Each side's key is delivered under its own variable, `LLM_API_KEY` for
  extraction and `EMBEDDING_API_KEY` for embedding, because the server, given no
  embedding key, may present the extraction key to the embedding provider.
  `core/gateway/litellm` meets the same case in its model map, which has two
  parts. The models wired to its optional `models` socket are entries of the
  routing table, each served under its connection's alias and presenting that
  connection's `credential`; the entries typed by hand into `values.models`
  name upstreams no connection reaches — one the catalog does not model, a
  provider whose own API a wired entry cannot describe, several entries sharing
  one alias — and present the Component's `provider_key`, one credential for
  all of them. A wired entry never reads `provider_key`, and an alias both parts
  publish halts the build, naming it.
- **The socket says when none is intended.** Each such socket also declares
  `unauthenticated` (`type: boolean`, `default: false`) in its `valueSchema`: the
  connection's own statement that its target takes no credential. It changes
  nothing a Component renders. Where the Recipe carries no default for the
  credential, it is also what lets a connection carrying none build, as on the
  object-store connections named under "A key with no development default". A
  socket whose `credential` is `required` declares no `unauthenticated`, because a connection carrying no credential there halts
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
  itself, so each carries its own copy, and the copies differ in that list of
  sockets and in one more respect: `core/ai-tool/agent-invocation`'s copy also
  counts a `client_secret` or a `client_certificate` on the connection as its
  credential (below), since the token obtained with the one, and the
  certificate the other holds, are what the target is presented.
  `core/observability/prometheus`'s `scrape_target` socket declares no
  `unauthenticated` and no such assertion names it, because the socket selects
  only `server` and `stateful-server` components and every Component this
  catalog labels `managed` is a `resource`, so no managed target can be wired
  there.
- **Several consumers share one credential by authoring.** Nothing cascades into
  a connection, so a shared key is one parameter every connection's credential
  reads — under `k8s-existing-secret`, the name of one Secret each connection
  references; under `k8s-secret-from-parameter`, the key itself, rendered once per
  connection. The worked example is
  [`language-reference/examples/model-api-key-sharing/`](https://github.com/aggrega-ai/aggrega-docs/blob/main/language-reference/examples/model-api-key-sharing/).

**A gateway's own callers are `infra.callers`, and their keys are
`caller_keys`.** A gateway that authenticates the callers sending it traffic,
so that a control can keep them apart, declares them as `infra.callers`, a list
of caller names the operator writes in the Release, and their keys in one
Component credential slot, `caller_keys`: one Secret holding a data key per
caller name, the data key being the name, which a secret-set attachment such as
`core/referenced-secret-set` fills. Each key reaches the gateway by reference
to that Secret, never as a value in a rendered file. The two names are the same
on every gateway that declares callers. `core/gateway/apisix` declares them:
each caller is a consumer of its routes file, authenticated by the key it
presents as `Authorization: Bearer <key>`, and its semantic cache and period
budget keep callers apart by it. `core/gateway/agentgateway` declares them on
its chart Recipe: each caller is an API key of its configuration, checked in
strict mode and presented the same way, and its period budget and its request
records keep callers apart by it. `core/gateway/traefik-hub` declares them
too: Traefik Hub's API Key middleware heads each model route and reads the key
presented the same way, but it checks a key against its htpasswd hash, so the
gateway's `caller_keys` Secret holds that hash under each caller's name and is
not the Secret a caller presents its key from; its semantic cache keeps
callers apart by it.

**A pair presented on one connection adds `credential_id`.** Where a caller
presents an identifier and its secret together on one connection — an object
store's access-key identifier and secret key — the secret half is `credential`,
as on every other socket, and the identifier half is `credential_id`, declared
beside it with the same keys and read and delivered the same way.
`core/ai-agent/agenta-api` and `core/ai-agent/agenta-services` declare the pair
on their `store` socket and deliver `credential_id` as `AGENTA_STORE_ACCESS_KEY`
and `credential` as `AGENTA_STORE_SECRET_KEY`; `core/observability/thanos-store`
declares it on its `objstore` socket and delivers the two as `AWS_ACCESS_KEY_ID`
and `AWS_SECRET_ACCESS_KEY`, presenting its `s3_access_key` value where no
`credential_id` is attached. An identifier that is a plain
value rather than a credential stays a value on the connection:
`core/observability/langfuse` names its object store's access-key identifier in
the `event_store` connection's `access_key_id` value, and only the secret half
is its `credential`.

**A token the caller obtains itself takes `client_secret`.** Where the target's
card requires OAuth 2.0 client credentials, or OpenID Connect, the caller
presents a token it obtains from the target's authorization server rather than a
key it already holds. It obtains the token with its own registration at that
server, a client id and a client secret, and presents neither to the target, so
neither is the connection's `credential`. The secret half is the slot
`client_secret`, declared beside `credential` with the same keys and filled the
same way. The client id is not a secret — OAuth 2.0 says so of every client
identifier — so it is a setting the operator writes in the connection's `infra`,
`client_id`, declared in the socket's `infraSchema` beside `audience`, the
resource the token is requested for where the authorization server asks for
one. Where the token is obtained, and for which scopes, is the target's, read
from its card, so the target publishes it, as `core/ai-agent/a2a-remote`
publishes `token_url`, `oidc_discovery_url` and `scopes` (see
"Reference-realization Recipes" below).

- **`core/ai-tool/agent-invocation` declares the shape on its `target_agent`
  socket**, and `helm/agent-invocation-knative` delivers the secret as
  `AGENT_TOOL_TARGET_CLIENT_SECRET`, a `secretKeyRef` to the Secret it publishes,
  beside `AGENT_TOOL_TARGET_CLIENT_ID`, `AGENT_TOOL_TARGET_AUDIENCE` and, on a
  connection writing no `inject:` block, `AGENT_TOOL_TARGET_TOKEN_URL`,
  `AGENT_TOOL_TARGET_OIDC_DISCOVERY_URL` and `AGENT_TOOL_TARGET_SCOPES`, each
  only where it has a value and none of them on a connection holding no
  `client_secret`, which therefore renders exactly what it renders with no such
  slot at all.
- **The token is the caller's software's job.** Obtaining it, caching it,
  obtaining another before it expires and presenting it on each request belong
  to the image the caller runs, and no build observes any of it: the catalog
  delivers the inputs and nothing more. OAuth 2.0 tells a server not to issue a
  refresh token for a client-credentials grant, so obtaining another is running
  the grant again.
- **The Recipe refuses what the caller could not use, naming the connection**: a
  `client_secret` with no `client_id`, or on a connection whose target publishes
  neither `token_url` nor `oidc_discovery_url`; a `client_id` or `audience` with
  no `client_secret`; and a delivered address that is not an `https` URL naming
  a host — OAuth 2.0 sends a client secret only over TLS — or that carries a user
  name or password, which would write a credential into the rendered output. No
  message repeats the address.
- **A target requiring two schemes together is reached with both slots filled**,
  each delivered under its own variables.

**A certificate the caller presents in the TLS handshake takes
`client_certificate`.** Where the target's card requires mutual TLS, the caller
proves who it is by the certificate it presents as the connection is set up,
not by anything a request carries. A2A's mutual TLS scheme carries only a
description: the card names no certificate, issuer or authority, so the
caller's certificate is agreed with the target's party out of band, and the
target publishes nothing for it. The certificate and its private key are the
slot `client_certificate`, declared beside `credential` with the same selector
and `sensitive: true`, and with `inject: [file]`, since the material reaches
the caller's container as files rather than as a variable's value — a
realization delivering it through a Workload entry is held to `as: file`. Its
Secret holds `tls.crt` and `tls.key`, the two keys a `kubernetes.io/tls` Secret
holds. The authority the caller checks the target's server certificate
against, where the caller's image does not already trust the one that signs
it, is a second slot, `server_ca`, whose Secret holds `ca.crt`, declared with
the same keys: `sensitive: true` because a secret-kind Feature fills it, though
an authority's certificate is not itself secret.

- **`core/ai-tool/agent-invocation` declares both on its `target_agent`
  socket**, and `helm/agent-invocation-knative` mounts the whole Secret each
  filled slot's attachment names — no `items`, no `subPath` — read-only, which
  Knative Serving requires of a Secret volume, at
  `/var/run/secrets/agent-tool/target-agent/client-certificate` and
  `/var/run/secrets/agent-tool/target-agent/server-ca`, and delivers
  `AGENT_TOOL_TARGET_CLIENT_CERT_FILE`, `AGENT_TOOL_TARGET_CLIENT_KEY_FILE` and
  `AGENT_TOOL_TARGET_SERVER_CA_FILE` naming the files, each only where its slot
  is filled, so a connection holding neither renders exactly what it renders
  with no such slot at all. The data key the attachment publishes is not read,
  since the whole Secret is mounted, and the rendered Service names only the
  Secret.
- **The target's authority is kept apart from the client's issuer.** A
  certificate issuer that writes `ca.crt` beside a client certificate writes
  the authority that signed that certificate, which need not be the one that
  signs the target's server certificate; the target's authority sits in
  `server_ca`'s own Secret, so the caller never trusts the client's issuer in
  its place. `server_ca` serves a connection holding any credential, or none.
- **Presenting the certificate is the caller's software's job.** Presenting it
  in the handshake, checking the target against the authority, and reading the
  files again when Kubernetes updates them after the Secret changes belong to
  the image the caller runs. The build cannot see that the Secret exists, holds
  those keys, or holds a certificate the target accepts.
- **The Recipe refuses, naming the connection**, either slot whose attachment
  publishes no Secret name, since nothing could be mounted, and either slot on
  a connection whose target would be reached without TLS, since no TLS
  handshake takes place there: a target publishing `protocol` `http`, and a
  target publishing no `protocol` whose published `endpoint` is not an `https`
  URL. A target publishing neither is reached by its host alone and is not
  judged.
- **The slots compose.** A card requiring mutual TLS together with a key or a
  token is reached with `client_certificate` beside `credential` or
  `client_secret`, each delivered under its own variables. Between them the
  three slots reach an API key in a header or a cookie, and an HTTP scheme whose
  value is fixed, such as Bearer or Basic, through `credential`; OAuth 2.0 or
  OpenID Connect through `client_secret` where the token is obtained by the
  client-credentials grant; and mutual TLS through `client_certificate`. A key
  in the query string, an HTTP scheme whose value answers a challenge, such as
  Digest, and any other OAuth 2.0 grant are not reached.
- **A credential is not sent to an external target over plain HTTP.** A
  `credential` or `client_secret` on a connection to a target labelled
  `component.aggrega.ai/hosting: external` that publishes `protocol` `http`
  halts the build, naming the connection, since the credential, or the token
  obtained with the secret, would travel to that target unencrypted. A target
  with another hosting label, or none, stays reachable over `http` with either,
  and one running inside the Release, such as `core/ai-agent/mastra`, then
  receives the credential unencrypted on the cluster network. The rule sits in
  `helm/agent-invocation-knative`'s template rather than in a Component
  assertion, because the protocol is a value the target publishes, which no
  assertion sees.

**Three realizations constrain the secret the two ends share.**

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
- **agentgateway** (`helm/agentgateway-chart`, `compose/agentgateway`). The
  gateway puts the key it presents to a wired model into its configuration
  file's text before it reads the file as YAML, so the key must be a plain token
  — letters, digits and `- . _ ~ + / =` — and other characters can load as a
  different key or stop the gateway.

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

Where the referenced service checks a credential its callers present, the
reference realization publishes the request header the service reads it from as
`credential_header`, from an `infra.credential_header` defaulting to
`Authorization`, and holds no credential of its own: each consumer holds one on
its connection, in the `credential` slot its socket declares (see "A key both
ends of a connection hold"), and presents it under that header. An
`infra.endpoint` carrying a user name or password is
refused, because it would write a credential into every rendered file the
address reaches. `helm/mcp-remote` and `compose/mcp-remote` take this shape for
a Model Context Protocol server someone else runs (see "Model Context Protocol
servers" below), and `helm/a2a-remote` and `compose/a2a-remote` for an agent
another party runs over the A2A protocol, `core/ai-agent/a2a-remote`, whose
`credential_header` is the header the security scheme in the agent's card reads
and which also publishes where that card is read, `agent_card_url`, and, for a
card requiring OAuth 2.0 client credentials or OpenID Connect, where a caller
obtains a token: `token_url`, `oidc_discovery_url` and `scopes`, from infra keys
of the same names, each optional and published empty while unset. A
`token_url` or `oidc_discovery_url` that is set is refused by both realizations
unless it is an `https` URL naming a host with no user name or password, since
OAuth 2.0 sends a client secret only over TLS, so the rule holds whichever
consumer reads the address.
`core/ai-tool/agent-invocation` holds the credential for such an agent on its
`target_agent` connection, the client secret it obtains a token with, and the
client certificate it presents for a card requiring mutual TLS, which names no
certificate for the reference to publish (see "A key both ends of a connection
hold").

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

### Model Context Protocol servers: their credentials and the tool socket

`core/ai-tool/mcp` stands for a Model Context Protocol server whose software is
the Release's, and the Manifest chooses how it is realized: `helm/mcp` runs an
image serving the protocol over HTTP; `helm/mcp-stdio-bridge` and
`compose/mcp-stdio-bridge` run a package that speaks only stdio behind a pinned
bridge serving it over HTTP; `helm/mcp-remote` and `compose/mcp-remote` reach a
server someone else runs, as reference realizations. Every one publishes
`host`, `port`, `endpoint`, `protocol` and `credential_header`, so a consumer
wires to the tool the same way whichever answers it. Two kinds of credential
meet at such a server, and each has its own holder. This is a catalog
convention: the compiler pipes the slots, the attachments and the published
strings, and checks none of what follows.

- **A bridged server's credentials are environment variables the server
  reads.** They are held in the Component's `server_env` slot as one Secret
  with one data key per variable, each key named as the variable.
  `helm/mcp-stdio-bridge` imports every data key of the Secret the attachment
  names into the bridge's environment by reference, and the bridge starts the
  server with that environment, so the server inherits each variable. Attach
  `core/referenced-secret`, mapped to `helm/k8s-existing-secret`, to name a
  Secret that already exists, and the credential stays out of every rendered
  file; `core/referenced-secret-set`'s realization writes the values into a
  Secret the build renders, which suits evaluation. `compose/mcp-stdio-bridge`
  halts the build on an attachment here, because the compose target has no
  secret reference to deliver one through, and the realizations that start no
  server behind the bridge halt on one too.
- **A remote server's credential is held by its consumer**, on the consumer's
  connection to the tool, in the `credential` slot its socket declares (see "A
  key both ends of a connection hold"), and presented under the request header
  the tool publishes as `credential_header`. That header is `Authorization`
  unless the Release names the one the server reads in
  `infra.credential_header`. Under `Authorization` the credential is presented
  as a bearer token, `Authorization: Bearer <credential>`, the form the
  protocol's authorization specification gives a client; under another header
  it is that header's value. The remote realizations hold no credential and
  deliver none, as no reference realization does: they halt the build on a
  `server_env` attachment, and on an `infra.endpoint` carrying a user name or
  password. A server that reads its credential from its own address rather
  than from a header — a key in the URL's path or query — is reached as the
  next bullet describes.
- **A remote server that reads its key from its own address has that address
  held by its consumer too**, as a secret on the consumer's connection to the
  tool, because the address is published as written and would otherwise carry
  the key into every file it reaches. The tool's `infra.endpoint` holds the
  address without the part that carries the key — at least its scheme and
  host, which the remote realizations read the host, port and protocol they
  publish from, and which `helm/mcp-remote` makes the `ExternalName` it emits.
  The whole address fills the `endpoint` slot a consumer's tool socket
  declares beside `credential`:

  ```yaml
  featuresSchema:
    endpoint:
      selector: "feature.aggrega.ai/kind=secret"
      sensitive: true
      inject: [env]
  ```

  The consumer's Recipe delivers what fills the slot in place of the
  `endpoint` the tool publishes, and keeps the `host` the tool publishes. On
  helm the slot is filled by `core/referenced-secret` mapped to
  `helm/k8s-existing-secret`, naming a Secret created outside the Release
  whose data key is `value` — the Feature's default, which is the key when the
  Release alone attaches it — so the consumer's container reads the address
  through a `secretKeyRef` and no Secret is rendered. On compose it is
  `core/secret-value` mapped to `compose/dotenv-secret`, with a Compose
  variable reference as its origin, which Docker Compose substitutes when the
  stack starts. A Release writes it this way:

  ```yaml
  components:
    search:
      infra:
        endpoint: https://mcp.example.com/mcp
    agent:
      uses:
        tools:
          search:
            features:
              endpoint:
                type: core/referenced-secret
                infra:
                  origin: search-mcp-address
  ```

  with the Secret created beside it, for example `kubectl -n agents create
  secret generic search-mcp-address
  --from-literal=value='https://mcp.example.com/mcp?api_key=<key>'`; on
  compose the attachment is `type: core/secret-value` with `infra: {origin:
  "${SEARCH_MCP_URL}"}`. Three limits come with the shape:

  - On compose, two `core/secret-value` attachments the Release alone makes on
    one consumer — two such addresses, or one beside a credential — both
    deliver under `value`, and the build halts naming both. An Aggregate that
    names `values.key` on one of them avoids it.
  - Where the key sits in the address's path, `infra.endpoint` holds the
    address with that part removed.
  - The host is written twice, plainly on the tool and inside the Secret, and
    nothing checks that the two match, because the compiler never reads a
    Secret.

  Composing the address at run time from the key alone, through a `$(VAR)`
  reference in a plain variable, works on Kubernetes only: Kubernetes expands
  such a reference from the entries listed before it in the container, and the
  helm provider lists the entries it reads from a Secret before the plain
  variables, while Docker Compose expands no `$(VAR)` reference between a
  service's environment entries.
  `core/ai-agent/openai-agents-sdk`, `core/ai-agent/claude-agent-sdk`,
  `core/ai-agent/agent-framework`, `core/ai-agent/google-adk` and
  `core/ai-agent/mastra`, and the platforms
  `core/ai-agent/flowise` and `core/ai-agent/n8n`, declare the slot on their
  `tools` socket and read it on both targets; `core/ai-agent/langflow`
  declares it and its Recipes halt the build on an attachment there, because
  Langflow reads a server's address only from the flow file it loads, where
  the key would be written as a literal;
  [`language-reference/examples/mcp-address-from-secret/`](https://github.com/aggrega-ai/aggrega-docs/blob/main/language-reference/examples/mcp-address-from-secret/)
  declares one on a consumer of its own and renders both targets too.
- **A bridged server checks no caller's credential.** The bridge reads no
  credential from a request that reaches it, so the bridge realizations publish
  `credential_header` empty, and a consumer's connection to one carries no
  credential.
- **A consumer's tool socket selects `component.aggrega.ai/category=ai-tool`
  together with the transport the consumer speaks**, which is
  `tool.aggrega.ai/transport=http` for a consumer speaking HTTP. A tool socket
  in this catalog takes that form:

  ```yaml
  selector: "component.aggrega.ai/category=ai-tool, tool.aggrega.ai/transport=http"
  ```

  The category admits tools and nothing else, and the transport admits only
  the tools the consumer can reach: a selector reads labels and never the
  content of a published value, so how a tool is reached has to be a label. A
  socket whose connections present a credential declares the `credential` slot
  and the `unauthenticated` value every such socket declares, and its Recipe
  delivers the credential as every socket's credential is delivered, with
  `credential_header` beside it, for the consumer to present the one under the
  other. A socket reaching servers that read their key from their address
  declares the `endpoint` slot beside it, as above.
- **A tool connection reaches the consumer under variables named for its
  alias**, the alias in capitals with every character other than a letter or
  a digit an underscore. The agent runtimes named above and the platforms
  `core/ai-agent/flowise` and `core/ai-agent/n8n` deliver the address as
  `AGGREGA_TOOL_<ALIAS>_URL`, the `endpoint` slot's secret in its place where
  the connection holds one, the `credential` as
  `AGGREGA_TOOL_<ALIAS>_CREDENTIAL` and the `credential_header` the tool
  publishes as `AGGREGA_TOOL_<ALIAS>_CREDENTIAL_HEADER`, each secret by
  reference on helm and from the inject pipe on compose. On any of these
  connections writing an `inject:` block, the names it dictates replace the
  published address and header, while the `endpoint` slot's secret and the
  `credential` stay. Those two platforms
  and `core/ai-agent/langflow` also declare `vector_store`, selecting
  `datastore.aggrega.ai/engine in (vector, semantic-memory, search)`, delivered
  the same way: the store's address as `AGGREGA_VECTOR_STORE_<ALIAS>_URL` — the
  `endpoint` it publishes, or `<protocol>://<host>:<port>` composed from what
  it publishes where it publishes no `endpoint` — and the connection's
  `credential` as `AGGREGA_VECTOR_STORE_<ALIAS>_CREDENTIAL`. A store that
  also publishes a `database` and a `user`, as `core/datastore/pgvector`
  does, reaches `flowise` and `n8n` in parts as well, as
  `AGGREGA_VECTOR_STORE_<ALIAS>_HOST`, `_PORT`, `_DATABASE` and `_USER`,
  because neither platform's PostgreSQL vector node takes a connection
  string: Flowise's takes the host, the port and the database in fields of
  its own and the user and the password from a credential Flowise stores,
  and n8n's reads a Postgres credential with a field for each. `langflow`,
  whose PGVector component takes one connection string, receives such a store
  as `AGGREGA_VECTOR_STORE_<ALIAS>_CONNECTION_STRING`,
  `postgresql://<user>:<password>@<host>:<port>/<database>`, the connection's
  `credential` its password: on Kubernetes the reference
  `$(AGGREGA_VECTOR_STORE_<ALIAS>_CREDENTIAL)`, which expands from the
  Secret-read entry written ahead of the plain variables, and
  on compose the credential as delivered, a Compose variable reference staying
  one. The password is written unencoded, because Langflow percent-encodes it
  itself, and a connection with no `credential` gets the string without one. A
  store publishing no `database` or no `user` gets no parts and no string. Two
  aliases of one socket that fold to one name would deliver one variable
  twice — on
  Kubernetes one of them may be a plain variable and the other read from a
  Secret, which the rendered Workload holds in two different maps — so
  `langflow` carries an assertion, `connection_aliases_deliver_apart`, that
  halts the build on two such `tools` aliases, naming both connections, and
  the Recipes halt it on every other pair wherever the two would still deliver
  one variable, since a connection writing an `inject:` block delivers no default.
  A flow reads each
  in the platform's own way: on `langflow` through a field naming a global
  variable of the same name, which Langflow reads from the environment where
  no stored variable carries that name; on `flowise` through a Runtime
  variable of the same name created on Flowise's Variables page; on `n8n`
  through `$env`, which its Recipes leave blocked unless the Aggregate sets
  `allow_env_access_in_nodes`.
- **`core/ai-agent/langflow` takes its `tools` connections through the flow
  it runs**, because its MCP Tools component reads a server's address from
  the server configuration written into the flow, or from a server of that
  name stored in Langflow's settings, which takes precedence, and never from
  a variable. A flow names a wired connection by Langflow's own server name:
  an MCP Tools node whose `mcp_server` value names the connection's alias. The
  Recipes write the address the tool publishes into that node's server
  configuration as its `url`, keep every other part of the definition, and
  write it back as JSON with its keys sorted; with no `tools` connection the
  definition is carried as authored. Every Recipe imports that rewrite from
  one ArtifactLibrary, `LangflowFlow`, whose bundle `FlowFile` emits the flow
  as the helm ConfigMap or the compose config. The Component's assertion
  halts the build on a connection with no flow or one no node names, and on
  a node naming a server no connection answers. A `credential` is delivered
  as `AGGREGA_TOOL_<ALIAS>_CREDENTIAL`, by reference as on every socket, and
  the node's header under the tool's `credential_header` carries the name of
  a variable holding that header's whole value, listed in
  `LANGFLOW_VARIABLES_TO_GET_FROM_ENVIRONMENT`, which Langflow replaces with
  the stored variable's value — only when the whole header value is the name,
  and only once the variable is stored, at the administrator's sign-in. Under
  any header but `Authorization` that variable is
  `AGGREGA_TOOL_<ALIAS>_CREDENTIAL` itself. Under `Authorization`, whose value
  is `Bearer <credential>`, it is `AGGREGA_TOOL_<ALIAS>_AUTHORIZATION`,
  holding `Bearer` and the credential by reference: on Kubernetes `Bearer
  $(AGGREGA_TOOL_<ALIAS>_CREDENTIAL)`, which expands from the Secret-read
  entry written ahead of the plain variables, and on compose
  the credential as delivered, a Compose variable reference staying one. A
  credential for a tool publishing no header halts the build. Langflow also
  refuses an MCP server or a vector store whose host resolves to a private
  address, so its Recipes set `LANGFLOW_SSRF_ALLOWED_HOSTS` to the hosts of
  the wired `tools` and `vector_store` connections, and leave it unset where
  neither is wired.

### Gateway / operator-driven (custom-resource-emitting) Recipes

The production way to run complex software on Kubernetes is often an **operator**:
a controller that reconciles a **custom resource** into running infrastructure
(a message broker becomes a Strimzi `Kafka`; a gateway's model routes become
Envoy AI Gateway's `AIGatewayRoute` and `AIServiceBackend`). A Recipe realizes
this by emitting the custom resource — as one more realization of an existing
component, selected per Release through the Manifest's component-type mapping,
coexisting with that component's synthesis, reference, and cloud-native
realizations; or, where the resources describe what is wired to a component, as
part of that component's own Recipe, once per connection, as Envoy Gateway's
Recipe does for the models on its `models` socket.

The custom resource carries in `artifacts:`, one map entry per emitted file. The
recipe fulfils the **same `provides` contract** as the component's other
realizations, so consumers are realization-agnostic: an operator-driven Kafka
publishes `provides.host` as the operator-created client bootstrap Service — the
consumer's wiring is unchanged from the synthesized or managed form. A gateway
emitting the resources for the models wired to it publishes what a model
publishes, `endpoint` and `model`, so a consumer reaches the gateway exactly as
it reaches a model.

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
  install is a first-class **companion component** (a `server` component),
  declared in the same Aggregate alongside the custom-resource-emitting
  component, so the custom resource and the controller that reconciles it are
  deployed together. A companion is realized by a Recipe that sources the
  project's own install chart, rendering the custom-resource definitions,
  webhooks and roles the project ships with the controller — and, where the
  project ships its definitions only as a chart of their own, carrying those
  definitions beside the Recipe as published and emitting them beside the
  chart's render — or by a bootstrap Recipe that emits the ServiceAccount,
  cluster RBAC and controller Deployment and no definitions, the realization
  for a cluster whose definitions are already installed and a build that must
  fetch nothing. Where a companion carries both, as the KEDA, mariadb-operator,
  MySQL Operator and Strimzi companions do, the chart realization is named
  `-chart`; a companion realized by the project's chart alone gives that Recipe
  the bare name, as the NIM Operator companion,
  `core/ai-model/nvidia-nim-operator`, does with `helm/nvidia-nim-operator`.
  Where the emitting component reaches the controller through
  a socket, that connection is the declared prerequisite: Envoy Gateway's models
  need the AI gateway controller wired to its `extension` socket, and the build
  halts while it is not.

Both make the prerequisite a declared thing the reader can see. The shape to
avoid is the third, silent one: emitting a custom resource with the control plane
merely hoped to be present and nothing in the model saying so.

**Credential custody.** A gateway holds the provider credential and authenticates
upstream on the application's behalf, so the credential never reaches the
application. The credential is a referenceable Secret filled through the
`core/referenced-secret` credential Feature on a credential slot — the
component's own, or, on a gateway serving the models wired to it, the slot of the
connection that reaches each model; a security-policy custom resource binds it
to the backend. A black-box credential slot still publishes its resource's
locator to the Recipe — the name of the Secret the credential's realization
emits, or of one that already exists — so the recipe reads the Secret's name for
the security policy without exposing the value.

**The exemplar.** Strimzi Kafka is the template for this pattern: `core/messaging/kafka`
offers an operator-driven realization emitting a `Kafka` and `KafkaNodePool`
custom resource at the Strimzi `v1` API alongside its synthesized StatefulSet
realization, and ships both prerequisite modes (the Strimzi Cluster Operator as
an ambient assumption or as a bundled companion component, realized by the
project's own chart or by a bootstrap). The same shape carries to further operators —
Elasticsearch, HA Postgres, additional AI gateways. NVIDIA's NIM Operator is one:
`core/ai-model/nvidia-nim` offers a realization emitting a `NIMService`, guarded by
the same `control_plane_present` affirmation, and the operator itself is the
companion `core/ai-model/nvidia-nim-operator`, realized from NVIDIA's own chart. The
cluster must already run NVIDIA's GPU Operator, which NVIDIA names as the NIM
Operator's prerequisite and the catalog does not install. The Envoy AI Gateway path is
the AI-gateway instance of the pattern, in its bundled shape.
`core/gateway/envoy-ai-gateway-operator` is the companion: its Recipe sources the
project's controller chart and emits the project's six custom-resource
definitions beside it, as the definitions chart publishes them, and the
controller's webhook certificate is a cert-manager `Certificate`, so cert-manager
must already run in the cluster — unless the Release names a Secret holding the
certificate in `infra.webhook_tls_secret`, in which case no `Certificate` is
rendered and cert-manager is not needed. `core/gateway/envoy-gateway` calls that
controller through its `extension` socket and, for each model on its `models`
socket, renders the AI route rule, the `AIServiceBackend`, the Envoy Gateway
`Backend` it points at and, where the connection carries a credential, the
`BackendSecurityPolicy` naming that credential's Secret. Author custom-resource
fields against the target project's current API documentation, since
custom-resource schemas evolve independently of the catalog.

### Self-hosted inference: dual realization (synthesis and controller-driven)

A self-hosted inference runtime — a model server run on the cluster's own
compute, marked `component.aggrega.ai/hosting: self-hosted` in the `ai-model`
category (`ollama`, `docker-model-runner`, `vllm`, `tgi`, `tei`, `nvidia-nim`) —
is deployed two genuinely different ways in the field, and each is a Recipe
realizing the same component, selected per Release through the Manifest:

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
  resource — a KServe `InferenceService`, a KubeAI `Model` or a `NIMService` of
  NVIDIA's NIM Operator — in `artifacts:`, and the controller owns the serving
  workload. GPU carries through the custom
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
and the resource name the operator routes on; a NIM Operator realization publishes
the Service the operator names after the `NIMService`. The contract is one of keys, not
values: the consumer's wiring is unchanged across all of them. Every runtime
listed above also has a Docker Compose Recipe publishing the same keys. `ollama`,
`vllm`, `tgi`, `tei` and `nvidia-nim` synthesize their server on the compose
network, and a GPU count the Release sets is reserved there as that many NVIDIA
GPUs on the serving service — which `nvidia-nim` always reserves, at least one.
`docker-model-runner` runs no server of its own: the host's Docker Model Runner
serves the model the compose file declares, and the same keys name that runner's
address, which the Release can point elsewhere.

Which realization to choose follows the cluster: with no serving control plane,
synthesize directly; with KServe, KubeAI or NVIDIA's NIM Operator installed, emit
its custom resource and let the controller serve. The NIM Operator is also a
companion component of the catalog's own, `core/ai-model/nvidia-nim-operator`, so
a Release can ship it beside the model. Custom-resource field names and service-naming
conventions here (for example a predictor Service name, or an operator's resource
profile names) follow each project's current API and installation, which evolve
independently of the catalog — verify them against the target cluster, per the
note above.

### Persistence, HA, active-passive and backup are options, not separate components

**A user must never change component to turn on persistence, high availability,
active-passive or backup.** A datastore with persistence enabled is still that
datastore. Persistence, high availability and active-passive are configurable
values on the single component's surface, realized per target by whatever
mechanism that target has: a chart's HA options, an operator custom resource's HA
spec, a cloud provider's multi-AZ flag, or a synthesized StatefulSet with a
PersistentVolumeClaim. Backup is the `core/backup` attachment rather than a value
on the component: the operator attaches it to the same component in the Release,
and each target realizes it its own way — a managed Recipe configures the
service's own automated backups from it, bound to `terraform/backup-native` or
`cloudformation/backup-native`, and keeps them on with none attached; on
Kubernetes the backup product the Manifest binds realizes it. Splitting a component
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
| `volumes.<n>.configmap`, mounted by a `volumeMounts` entry | **Realized.** The source becomes a compose `config` carrying the content, delivered as **one file at the mount path**. The mount path is emitted verbatim, so it names a *file*. The content is **interpolated**: Docker Compose substitutes a variable reference, `$NAME` or `${NAME}`, inside it as in every other value of the file, an unset one by an empty string, and reads `$$` as one literal `$`. The content an `artifacts:` fragment declares is written as the Recipe rendered it, with nothing escaped, so a Recipe carrying content that must reach the container as authored — a definition an Aggregate supplies verbatim, say — doubles every `$` in it with `replace "$" "$$"`, and leaves single only a reference it means Compose to substitute. |
| Several named files mounted as a **directory** | **Not expressible.** One config is one file, and the target performs no key expansion: pointing the mount at a directory path writes a single file at that path. A value shaped as a map of filename to content — bootstrap scripts, a drop-in directory — has no `compose` realization. |
| `volumes.<n>.persistent` | The volume is **created and named**; the declared `size` reaches no emitted byte, and nothing reports it. The target has no volume-size concept. |
| `containers.<n>.resources` | **Realized** as `deploy.resources` — `cpu` as fractional cores, `memory` as an exact byte count, and an `nvidia.com/gpu` count as a reservation of that many NVIDIA GPUs, which the Docker host must be able to hand to containers. An operator's sizing is honored here, not dropped. Every other extended resource key is dropped, with a warning naming it. |
| `containers.<n>.health` | **One healthcheck per service.** Of the probes a container declares, `live` is translated, else `ready`, else `startup`, and a warning names the ones dropped. The check runs **inside the image**: an `http` probe becomes `curl -f` against the port whose name sorts first and a `tcp` probe becomes `nc -z`, both through the image's shell, while an `exec` probe runs its command directly. A `depends_on` entry derived from a `uses` edge has `service_started` semantics, so it orders start-up and does not wait for the target to report healthy. |
| `initContainers` | **Realized** as a companion service the main service waits on, through `depends_on` with `service_completed_successfully`. |
| `services.<n>` | A `NodePort` or `LoadBalancer` entry publishes its ports on every host interface, and a `Loopback` entry on the host's loopback address, 127.0.0.1, only. A `ClusterIP` or `Headless` entry publishes nothing, so a port an operator sets reaches no emitted byte. |
| `replicas` | **Dropped, with a warning** naming it. |
| An attached credential | Arrives on the inject pipe and is delivered as a **literal environment value** in the emitted file, written as the credential delivered it — so the material sits in the artifact, unless the delivered value is itself a Compose variable reference such as `${DB_PASSWORD}`, which Docker Compose substitutes from the shell environment or a `.env` file when the stack starts. The target has no secret-reference primitive for a `secretKeyRef`-style pointer to resolve, so neither credential Feature that publishes only a locator — `core/referenced-secret`, `core/referenced-secret-set` — has a `compose` realization, and attaching one the Manifest leaves unmapped halts the build. |
| `containers.<n>.lifecycle`, `containers.<n>.envFrom` | **The build halts.** The target has neither primitive, and dropping either silently would change what the Release means. |
| A top-level `models` entry — not a Workload construct; an `artifacts:` fragment or a sourced compose file writes it, with a service's `models:` reference | **Carried as written**, in Compose's own spelling. Docker Compose 2.38 or later, with Docker Model Runner on the host, pulls and configures each model before it starts any container, and the build checks neither. **A model no service is granted is left out**: `docker compose up` drops it unless run with `--all-resources`. So a Recipe that writes a model also writes a service granted it, as `compose/docker-model-runner` does. |
| A run that ends, or one held until someone starts it — the `task` form, or a Feature asking for a run started by hand | **Written whole as a service in an `artifacts:` fragment, with `restart: "no"`.** Workload synthesis on this target maps the `stateless` and `stateful` forms only and halts on `task`, `scheduled` and `daemon`, and it writes no `profiles`; nor can a fragment add a key to a service the workload synthesizes, since two definitions of one service name within a component do not combine, one replaces the other whole. With `restart: "no"` Compose does not start the service again when it exits, so it runs once at each `docker compose up`. To hold it until someone starts it, the service also carries a profile, `profiles: ["manual"]`: `docker compose up` leaves it stopped, and `docker compose run --rm <service>` starts one run. `compose/task` is the pattern. The quantity conversion in the `resources` row runs only for a synthesized service, so such a Recipe sizes the service itself, refusing by name a quantity it does not read. Nothing on this target starts a service on a schedule, so a scheduled run is refused by name. |

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

A server inside the cluster that terminates its own clients' TLS takes a
different shape, because the certificate belongs to the server's own listener,
which only its Recipe configures:

- **The operator turns it on with `infra.client_tls`** on the server's
  Component, off by default, and off renders exactly as a Component without
  the setting.
- **A self-hosted realization presents the certificate attached to the
  server's slot `server_certificate`**, a Secret holding `tls.crt` and
  `tls.key` mounted into its container as files; a realization whose operator
  or service issues its own certificate presents that one instead.
- **The caller checks it against the authority in a `server_ca` slot on its
  own connection**, a Secret holding `ca.crt` mounted into its container, or,
  with none attached, against its image's default trust store.
- **The published `protocol` takes a value of its own while TLS is on**, which
  is what tells a caller that TLS is required: a caller holding `server_ca` on
  a connection to a server publishing a value served without TLS halts naming
  the connection.

The caches follow it, as "Encrypted client connections to a cache" below sets
out, and so does `core/messaging/kafka`, publishing `kafka-ssl` — the wire
protocol paired with `SSL`, the name a Kafka client's `security.protocol`
takes. Its synthesized realization requires `server_certificate`, its Strimzi
realization presents a certificate from the operator's cluster certificate
authority unless one is attached, publishing that authority's certificate as
`ca.crt` in the Secret `<instance>-cluster-ca-cert`, and its MSK realization
presents one AWS issues, which a default trust store holds.
`core/ai-tool/event-publisher` takes `server_ca` on its `target_messaging`
connection and names the mounted file to the tool's code as
`EVENT_TOOL_BROKER_SERVER_CA_FILE`.

### The datastore family template

Every datastore component targets the same shape, distilled from the PostgreSQL
exemplar. A new family member is authored against this template rather than by
copying whichever sibling happens to be nearest.

- **`values`** — the engine-specific subset of logical bootstrap names plus engine
  configuration, each key carrying a `description` and a sensible default so a bare
  Aggregate renders unchanged: the logical `database`, `user` (or `app_user` where
  an application-role split applies), `encoding` / `locale`, `init_scripts` (an
  object whose values are strings), and `custom_config` for a raw configuration
  block. Plus the persistence and HA toggles as configurable knobs, per the rule
  above, wherever the engine has them; backup is the `core/backup` attachment, not
  a knob.
- **`infra`** — `port`, `engine_version`, `compute.{cpu,memory}`, and for stateful
  engines `storage.{size,type}`; `ha.{enabled,read_replicas}`; and `overrides`
  as the open bag for the operational side. **`storage.{size,type}` is scoped to the targets that have a
  volume-size concept — the `compose` realization creates the volume and honors
  neither number, which is one of this template's two named exceptions to the knob
  rule, not a silent drop.** **The other is `compute.{cpu,memory}` on a managed
  realization:** a managed service sizes the instance by its own instance class
  rather than by a CPU and memory figure, and because the Component's defaults
  reach every Recipe, a managed Recipe cannot tell them from a value a Release
  wrote, so it does not read them rather than refusing them. Each of those keys'
  descriptions on the Component says so, and names the `overrides` key the managed
  Recipes size the instance by. A managed cache that provisions no volume — the
  ElastiCache and Memorystore realizations — reads no `storage.*` either, for the same reason, and
  its descriptions say so too, and a managed service that serves one port of its
  own — the Amazon OpenSearch Service realizations — reads no `port` while it holds
  the Component's default, refusing any other value by name. A key that alone
  carries a setting the managed service needs — its engine version, the volume
  size of the OpenSearch domain — is read even where its Component default is a
  value the service refuses, such as an image tag naming a release the service
  does not run or a volume below its minimum: the Recipe halts on it naming the
  key and what to set, and the key's description says the default halts there.
  A value a managed service cannot honour and that a
  Recipe can tell apart from a default — an application user the service does not
  create, an initialisation script, a raw configuration file, a replica count a
  Recipe does not provision — is refused by name instead. The key stays
  single-named and single-homed rather than split per target: the size means the
  same thing everywhere, and a stateful member needs its
  volume on the local target too or it would not be the same datastore the Kubernetes
  target deploys. **`storage.type` declares no default: the class defaults to the
  cluster's own.** On a Kubernetes realization it is the volume's storage class, and
  the claim names one only when the Release does: a claim that names no class is
  provisioned from the cluster's default storage class, while an empty class asks for
  a volume with no class at all. The helm workload synthesis omits an empty class on
  its own; a Recipe handing the key to a chart or a custom resource guards the line
  with `{{- with … }}` rather than rendering it empty. On a managed realization the
  same key is the provider's volume type, and each managed Recipe supplies its own
  fallback where it renders the key. It refuses by name a volume type the service
  will not attach to the instance type it provisions, and one that needs a figure
  no key carries: the OpenSearch Service Recipes refuse anything but gp3 on an
  instance family that takes gp3 alone, magnetic storage on a Graviton family or
  above 100 GiB, and the Provisioned IOPS io1, whose IOPS figure the Component
  declares no key for.
- **`provides`** — `host` and `port` are required; `user`, `database` and
  `protocol` are declared **only where the engine has the concept**. Redis, Valkey
  and Memcached have no user or database — do not invent them to make the family
  look uniform. A member whose consumers take one address also publishes
  `endpoint`, joined from those parts and carrying no credential:
  `core/datastore/pgvector` publishes
  `postgresql://<user>@<host>:<port>/<database>`, its password staying the
  credential attached to the component. A managed realization publishes `host`
  and `port` as "The name a managed datastore is reached at from another
  target" below sets out.
- **`featuresSchema`** — an optional transparent `password` slot carrying an inline
  development default when nothing is attached, so an unattached slot stays
  byte-identical to its pre-slot output; plus an optional `app_user_password` where
  the application-role split applies.
- **Realizations** — helm synthesis (the workload `form`, a PersistentVolumeClaim
  and a headless Service for stateful engines), compose for local development, and
  the managed cloud equivalents where one exists — on AWS, RDS, ElastiCache and
  Amazon OpenSearch Service; on Google Cloud, Cloud SQL and Memorystore; on Azure,
  Azure Database for PostgreSQL flexible server — with HA honored there through
  the provider's native flags rather than re-implemented, and, on the managed
  databases (RDS, Cloud SQL, the flexible server), an attached `core/backup`
  configuring the service's own automated backups.
  `recipe/helm/mariadb` runs one server, so it halts on `ha.enabled` and on a
  non-zero `ha.read_replicas` by name, naming `recipe/helm/mariadb-cluster`, rather
  than rendering one instance under them. `recipe/helm/mariadb-cluster` honours
  both through the mariadb-operator controller's replication: one primary plus
  `ha.read_replicas` replicas, automatic failover to a replica while `ha.enabled`
  is true — so `ha.enabled` with no replica halts by name — and `provides.host`
  naming the controller's `<name>-primary` Service while replication is on, since
  the instance's own Service then routes to the replicas too. A managed
  realization of a Component promising an extension enabled in its database is
  authored only where the service enables it through its own configuration of the
  database; where only a SQL statement enables it, the Component's description
  says so and names the managed path. `core/datastore/pgvector` has no RDS
  realization for that reason: RDS for PostgreSQL offers the pgvector extension,
  but no setting of the database instance enables it in a database, only a
  `CREATE EXTENSION` statement, so its description names `core/datastore/postgres`
  on its RDS Recipes, with the application running `CREATE EXTENSION vector` in
  its own database. `core/datastore/timescaledb` has no flexible server
  realization for the same reason: the service carries TimescaleDB, and its
  server parameters allow the extension (`azure.extensions`) and preload its
  library (`shared_preload_libraries`), but neither creates it in a database, so
  the Component's description names `core/datastore/postgres` on
  `recipe/terraform/postgres-flexible-server`, with both parameters set through
  that Recipe's `infra.overrides.server_configuration` and the application running
  `CREATE EXTENSION timescaledb`. This is a catalog convention, not something the
  compiler checks.
- **Identity labels** — the component's `metadata.labels` carries all three label
  axes: `component.aggrega.ai/type`, `component.aggrega.ai/category: datastore`,
  and the family's capability label `datastore.aggrega.ai/engine` where the engine
  has a discriminating value. Plus `component.aggrega.ai/hosting` per the hosting
  rule above — a single posture where every Recipe of the member shares one,
  `mixed` where the member is realized both self-hosted (helm, compose) and
  managed (the Terraform/CloudFormation equivalents). These are selector-only
  identity; the family's Recipes do not stamp them onto rendered output.

### Encrypted client connections to a cache

`core/datastore/valkey`, `core/datastore/redis` and `core/datastore/memcached` serve
their clients over TLS when the operator turns it on. It is a setting on the Component rather than a
Feature, because TLS reconfigures the server's own listener, which only the
cache's Recipe controls. This is a catalog convention upheld by each Recipe's
template, not something the compiler checks: the compiler pipes the published
`protocol` as a string and does not interpret it.

- **The setting is `infra.client_tls`**, a boolean that defaults to false. Off, the
  Component's contract and every render are exactly what they are without the
  setting.
- **On, the published `protocol` says so** — `valkey-tls` for `valkey`, `redis-tls` for
  `redis`, `memcached-tls` for `memcached`: the product's name and the word its own
  documentation uses for the feature. The port then accepts TLS alone, and `host` and
  `port` are unchanged, so `protocol` is what tells a consumer that TLS is required; a
  plaintext client reaching the port fails its handshake and exchanges no command.
  Every consumer Recipe checks `protocol` on a connection it delivers under its default
  variables: one taught the TLS value reaches the cache over TLS; every other refuses
  it, naming the connection. A connection that dictates gets what it dictates (see "A
  component running the Release's own code takes `inject:` on its connections").
- **A self-hosted realization presents the certificate attached to the slot
  `server_certificate`**, declared optional with `selector:
  "feature.aggrega.ai/kind=secret"`, `sensitive: true` and `inject: [file]`. Its
  Secret holds `tls.crt`, the certificate followed by any intermediate
  certificates, and `tls.key`, its private key — the two keys a
  `kubernetes.io/tls` Secret holds — and the certificate names every address a
  client dials. The Secret is mounted into the server's container as files, so the
  slot is filled by a Feature that names an existing Secret, `core/referenced-secret`.
  The server asks no client for a certificate.
- **Two halts, each naming what to change:** `client_tls` true with nothing attached
  to `server_certificate`, since the server would have no certificate to present;
  and a certificate attached while `client_tls` is false, since nothing would
  present it. An attachment that publishes no Secret name halts naming the slot.
- **A managed realization turns on the service's own in-transit encryption.** The
  ElastiCache realizations do: the service presents a certificate AWS issues, which
  is publicly trusted, so a consumer needs no `server_ca` for it, and an attachment
  to `server_certificate` halts naming the slot. An attached Valkey or Redis
  password becomes the AUTH token, which ElastiCache accepts only with in-transit
  encryption on, so it halts while `client_tls` is false; an attached Memcached
  password halts, since ElastiCache offers no Memcached authentication. The
  Memorystore for Valkey realization does too, with a certificate from the
  instance's own certificate authority, which no system trust store holds: each
  consumer checks it against that authority in its `server_ca` slot, a Secret
  holding the chain under `ca.crt`, which the operator reads with `gcloud
  memorystore instances get-certificate-authority` once the instance exists. An
  attachment to `server_certificate` halts there as well. So does the Azure
  Managed Redis realization, which serves TLS by default with a certificate of
  its own; there `client_tls` false serves plaintext, which the service accepts
  from access-key clients alone, so it halts while access keys are off.
- **A realization that cannot serve TLS refuses `client_tls` by name and names one
  that can.** The Compose realizations do: each server reads its certificate
  from files, and no credential Feature realized on Compose names a secret a
  service can mount, so they refuse the setting, and a certificate attached
  without it, and name the helm realizations. The Memorystore for Memcached
  realization does too, since the service offers no encryption in transit.
- **A consumer taught the TLS value reaches the cache over TLS while the cache
  publishes it**, with the product's own switch, and checks the cache's
  certificate against the authority in a `server_ca` slot on its cache socket —
  optional, `selector: "feature.aggrega.ai/kind=secret"`, `sensitive: true`,
  `inject: [file]`, a Secret holding `ca.crt`, mounted into its container — or,
  with none attached, against its image's default trust store, which a publicly
  trusted certificate chains to. It halts, naming the connection, on a
  `server_ca` publishing no Secret name, on a `server_ca` on a connection whose
  cache serves no TLS, and on a value served over TLS it is not taught to reach.
  A consumer whose product takes the authority from a file it cannot be given on
  its target refuses `server_ca` by name there: the Compose realizations of Tyk
  and Loki do, and connect over TLS against their images' trust stores. The Dify
  API server, task worker, scheduler and plugin runtime, the Agenta API and its
  two workers, whose services and scheduler Recipes compose the same URLs,
  Langfuse, Tyk, the LiveKit media server and SIP bridge, and the period-budget
  stores of Envoy Gateway and Traefik Hub consume a Valkey or Redis cache this
  way, accepting `valkey-tls` and `redis-tls` alike, and so do the semantic
  caches of Traefik Hub and LiteLLM, for a Redis store. LiteLLM's semantic cache
  reaches a store publishing `redis-tls` over TLS through a whole connection URL,
  so its Recipes compose that URL with the password in it as a reference the
  gateway's container expands from the password's Secret when it starts, and the
  password reaches no rendered file; inserted unencoded, a password carrying `/`,
  `?`, `#` or `%` breaks the URL when the gateway starts and nothing refuses it at
  build, so the store takes a password of letters and digits. The cache checks
  the store's certificate chain and that the certificate names the store's
  published host, refusing an authority certificate carrying no key usage
  extension; a refused certificate fails the connection, and every lookup is
  then a miss and nothing is stored. Loki's
  chunk cache consumes a Memcached cache this way, its shared protocol check
  accepting `memcached` and `memcached-tls`.
- **A consumer whose product checks a certificate only against the authorities
  it trusts for every connection offers no `server_ca`.** APISIX's semantic cache
  reaches a Redis store publishing `redis-tls` over TLS and checks its
  certificate chain against the authorities the gateway trusts, its system's by
  default, and not the store's name; a privately signed certificate fails the
  handshake when the gateway runs.
- **A consumer whose product cannot reach a cache over TLS refuses the TLS value
  by name**, naming the connection and the cache's protocol: Higress's token
  limit, whose plugin's Redis settings offer no TLS connection, and the four
  consumers that hand a store's address to the Release's own code, on a
  connection writing no `inject:` block — `core/ai-tool/datastore-query`,
  `core/ai-agent/langgraph`, `dynamiq` and
  `phidata` — which give that code no authority to check a certificate against,
  and the last three not even the store's protocol.
- **A consumer checking `protocol` through the shared TargetProtocol check lists
  every value its client speaks** in its `check_protocol` local: one protocol as
  a plain string, or several as a JSON list in the string — a local is a string,
  and a list local is written this way elsewhere in the catalog — as
  `'["memcached", "memcached-tls"]'` on the Loki Recipes. The check refuses any
  other value, naming every one listed.

### The name a managed datastore is reached at from another target

A managed datastore's address — an RDS instance's, say — does not exist until the
instance is created, so a Terraform or CloudFormation realization publishes `host`
as a pointer that target resolves inside its own output:
`${module.<instance>.address}` on Terraform, `!GetAtt <LogicalId>.Endpoint.Address`
on CloudFormation. A consumer rendered to another target — a helm Deployment, a
compose service — receives that pointer as text. **Every managed datastore
realization therefore lets the operator supply the name to publish instead.** This
is a catalog convention, not something the compiler checks: the compiler pipes the
operator's string and resolves nothing about it.

- **The key is `infra.overrides.host`**, the name the referenced realization
  `recipe/helm/postgres-external` reads for the same concept — the address a
  consumer reaches the server at, supplied by the Release. It sits in the open
  `overrides` bag, so the Component's schema does not list it; each Recipe's
  comment listing the `overrides` keys it reads does, and this section is the rule.
- **Set, `host` publishes the name; unset, it publishes the pointer exactly as
  before.** On CloudFormation the name goes into both `provides` blocks — the
  Recipe-level one a consumer's value pipe reads, and the fragment's own that the
  stack Outputs are projected from — so a consumer in another stack imports the
  name through the same export it would import the pointer through. A Release that
  does not set the key renders byte for byte as it did before the option existed.
- **`port` publishes the configured `infra.port`, set or unset.** The Recipe sets
  the instance's port from it, so the value is known ahead of time and a consumer
  on any target can use it, where a port pointer would reach another target as
  text exactly as the host's does. A service that serves one port of its own
  publishes that port instead, and refuses an `infra.port` other than the
  Component's default by name: an Amazon OpenSearch Service domain serves HTTPS
  on 443 alone, so `recipe/terraform/opensearch-service` and
  `recipe/cloudformation/opensearch-service` publish `port` `443`, `protocol`
  `https` and `endpoint` `https://` joined to the same `host`, the name or the
  pointer alike — on CloudFormation an `Fn::Sub` over the domain's
  `DomainEndpoint`, which a consumer in the stack receives as that intrinsic and
  one in another stack imports through its export. A client checking that
  domain's certificate needs a name the certificate carries, which a name of the
  operator's own gets only from the domain's custom endpoint, so on those two
  Recipes `infra.overrides.host` also names the custom endpoint, which presents
  the AWS Certificate Manager certificate the Release names beside it, in
  `infra.overrides.custom_endpoint_certificate_arn` on terraform and
  `infra.overrides.CustomEndpointCertificateArn` on CloudFormation, each named for
  the field it sets. The two keys go together: either without the other halts,
  naming the missing one, and so does a name the custom endpoint cannot take — an
  IP literal, a single label, a label over 63 characters or a name over 255. The
  certificate's ARN is piped as text; the Recipes create no certificate.
- **The Recipe emits nothing for the name** — no DNS record, no alias. The operator
  points the name at the instance outside the Release, and the build cannot check
  that it does: resolving the name is the runtime's, and a record the Release never
  declared would be infrastructure nobody authored.
- **The value is a bare host: a DNS name or an IP literal**, as
  `recipe/helm/postgres-external` accepts. A value carrying a scheme (`://`), a
  path (`/`), a user (`@`), a port (one `:` after a name or an IPv4 literal, `]:`
  after a bracketed IPv6 one) or whitespace, or one that is not a string, is
  refused by a build-time `assertions` entry naming the key and saying that the
  port is `infra.port`. An IPv6 literal carries several colons and is accepted.
- **A consumer on the same target receives the name too, and loses the ordering
  the pointer gave it.** Terraform acts on a module after the module it references,
  and CloudFormation creates a resource after the one its `Fn::GetAtt` names; a
  name references nothing. Each Recipe's description says so. The operator orders
  the two with `syncWave:` — the consumer in its own boundary, sharing the
  database's `directory:`, with a later wave, since every component of one boundary
  carries that boundary's wave. The terraform and cloudformation provider pages'
  "Deployment ordering" sections set out what a wave expresses on each target.

The terraform RDS Recipes (`recipe/terraform/postgres-rds`, `mysql-rds`,
`mariadb-rds`, the two `-module` Recipes and the three
`-rds-terraform-aws-modules` Recipes, whose pointer names the module's
`db_instance_address` output) and the CloudFormation ones
(`recipe/cloudformation/postgres-rds`, `mysql-rds` and `mariadb-rds`) follow it,
and so do the terraform ElastiCache Recipes (`recipe/terraform/valkey-elasticache`
and `redis-elasticache`, whose pointer names the module's
`replication_group_primary_endpoint_address` output, and `memcached-elasticache`,
whose pointer names `cluster_address`, the host of the cluster's configuration
endpoint) and the CloudFormation ones
(`recipe/cloudformation/valkey-elasticache` and `redis-elasticache`, publishing
`!GetAtt <LogicalId>.PrimaryEndPoint.Address`, and `memcached-elasticache`, publishing
`!GetAtt <LogicalId>.ConfigurationEndpoint.Address` — the two resource types spell
the attribute differently), and `recipe/terraform/opensearch-service`, whose
pointer names the module's `domain_endpoint` output, and
`recipe/cloudformation/opensearch-service`, publishing `!GetAtt
<LogicalId>.DomainEndpoint`. So do the Cloud SQL Recipes
(`recipe/terraform/postgres-cloud-sql` and `mysql-cloud-sql`), whose pointer names the
module's `private_ip_address` output, the instance's address in the operator's
network; Cloud SQL serves one port per engine, so they publish `port` `5432` and
`3306` and refuse an `infra.port` other than the Component's default by name.
So do the Memorystore Recipes: `recipe/terraform/valkey-memorystore`, whose pointer
names its module's `primary_address` output, the instance's primary endpoint, and
`memcached-memorystore`, whose pointer names `node_address`, the address of its one
node, since the instance's discovery endpoint answers Auto Discovery queries alone;
they publish `port` `6379` and `11211`, the ports the service serves, and refuse an
`infra.port` other than the Component's default by name.
So does `recipe/terraform/postgres-flexible-server`, whose pointer names the module's
`fqdn` output, the server's name under `postgres.database.azure.com`, which resolves
through the operator's private DNS zone; it publishes `port` `5432`, the one port the
service serves PostgreSQL on, and refuses any other `infra.port` by name.
So does `recipe/terraform/redis-azure-managed`, whose pointer names its body's
`hostname` output, the instance's name under `<region>.redis.azure.net`; it
publishes `port` `10000`, the one port Azure Managed Redis serves, and refuses
an `infra.port` other than the Component's default by name.
So does `recipe/terraform/kafka-msk`, a managed Kafka
cluster rather than a datastore, whose `host` names the first broker of the module's
`bootstrap_brokers_plaintext` output, or of `bootstrap_brokers_tls` while
`infra.client_tls` is on, and whose `bootstrap_servers` names the whole list, both
replaced by the operator's name, `bootstrap_servers` joined with the port; it refuses
that name while `infra.client_tls` is on, since the certificate AWS issues does not
carry it. So do `recipe/terraform/rabbitmq-amazon-mq` and
`recipe/cloudformation/rabbitmq-amazon-mq`, a managed RabbitMQ broker, whose
`host` names the module's `amqp_host` output on Terraform and, on
CloudFormation, the host read out of the first of the broker's `AmqpEndpoints`
URLs with `Fn::Select` over `Fn::Split`, since no attribute carries the host
alone; both publish `port` `5671`, the one port the service serves AMQP on, and
refuse an `infra.port` other than the Component's default by name. A managed
datastore Recipe
added later follows this section rather than a sibling Recipe.

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
shortcut), **not** a `uses` edge. A `uses` edge is content-neutral string-routing between
components that already exist; a guardrail is new runtime configuration to attach,
which is exactly what a Feature is for. Whether a given guardrail earns a Feature
of its own is the test below: one that only a single product in the field has is
a value on that product's own Component.

### What earns a Feature: two independent products in the field

A Feature is an attachment that brings something — resources, a pipeline step,
wiring the developer or the operator attaches deliberately — and **it earns its
name when at least two independent products in the field realize the capability
it declares.** The products counted are products in the world, established from
their own current configuration references, and not the components this catalog
happens to ship: a capability two gateway products implement is portable whether
the catalog carries one of those gateways, both of them, or neither. Kong
3.9.3's open-source image carries neither a semantic cache nor a period budget,
which Kong offers in its enterprise edition only, and Tyk v5.14.0's gateway
carries neither, the budget of Tyk's separate AI Studio being enforced in its
enterprise edition only: those editions count toward the field whether or not
this catalog runs them.

What the catalog ships is a separate question, answered one product at a time. A
Feature may be declared before anything here realizes it — attaching it then
halts the build naming the type, which is the honest state while no product the
catalog ships can realize it — and it may be realized on one component or on
several. Each realization is a FeatureRecipe for one product that honours the
Feature in that product's own terms. Where a product the catalog ships could
realize a Feature and only the catalog's own rendering of that product stands in
the way, the missing realization is the catalog's to write, as "Before a
realization refuses, establish whose refusal it is" below sets out.

**A capability that only one product in the field has is not a Feature.** It is a
setting on that product's own Component, which the author who decides it sets in
that author's pillar and reads beside everything else that configures the product.
A Recipe may declare `spec.pipeline` of its own, driven by the values and
infrastructure the component was authored with, so that is where such a setting
is written into the product's configuration.

**A Feature that fails the test is widened or removed, never kept as a contract
only one product can meet.** Where the field shares a shape of the same
capability — the same promise kept at a narrower scope or a finer grain — the
Feature is widened to that shape. A different control serving the same concern
is not a shape of it; it has a name and a test of its own. Where the field
shares no shape of the capability, the Feature is removed — its declaration, its
validation and its realizations together — and the capability becomes a value
on the Component of the one product that has it. LiteLLM v1.103.1 caps the
requests in flight for each entry of its model map, its one total counting a
request for its first second only, and Envoy Gateway v1.9.1 for each backend of
a route rule, its connection limit counting connections rather than requests;
neither holds a cap on the total across everything it serves. A
cap per target passes the test and a cap on that total does not, so a Feature
capping the requests in flight is widened to the cap per target rather than kept
as a total alone.

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
- **An option no product honours is dropped** — in its configuration or in code a
  realization delivers into it — rather than kept so the set reads as complete. A
  protection one product keeps only through such code is not dropped: it stays an
  option whose default is the protection, as "Core, option or drop — and a
  protection keeps its default" below sets out.

**This is a convention catalog authors uphold, not something the compiler
enforces.** The compiler validates a Feature against its schema and pipes strings,
so a Feature declaring options no product implements passes every gate and ships.
The judgement stays with the author and the reviewer.

### Measure the field first, and re-measure after a release

**Before a Feature is written, measure the field.** Read the current
configuration reference of each product that offers the capability, and keep
with every read the date it was made and the product version it describes.
Then establish, member by member, that every core promise is honoured
**exactly, by configuration**, by two or more independent products: by a setting
the product's own reference documents, not by code a realization would have to
deliver into it, and not by a looser behaviour carrying the same name.

A period budget is the worked case. Refusing further model requests once what
was counted over a period exceeds a limit is configuration on LiteLLM v1.103.1,
as a budget in US dollars over a number of days or a calendar month; on APISIX
3.18.0, as token rate limiting over a fixed window that opens with the first
request after the last window closed; on Envoy Gateway v1.9.1 with Envoy AI
Gateway v1.1.0, as a usage-based rate limit counting the tokens each reply
reports; and on Cloudflare's AI Gateway, a hosted service with no version to
pin, so that the date of the read places it, as a spend-limit rule. What each
counts, over which period and for whom differs from one product to the next,
which is why `core/period-budget` declares those as values each realization
keeps or refuses by name, and the refusal past the limit as its core.

On Envoy Gateway that core holds while the count cannot be checked only under a
setting of its control plane, `rateLimit.failClosed`, which the Recipe of
`core/gateway/envoy-gateway` turns on while `core/period-budget` is attached:
while the store or the rate-limit service cannot be reached, or a check takes
longer than Envoy's rate-limit timeout, model requests are refused with HTTP
500 rather than served and not counted, the product's default. The setting
holds for every rate limit that install keeps, so a rate limit applied to it by
hand fails closed too, and a request admitted just before an outage is still
served and not counted, because its tokens are charged after the reply.

**Re-measure a vendor fact before relying on it when the product has released
since it was read.** A reading answers for the version it describes. A later
release can add what the reading found missing, or change what it found there,
and a member's classification, a realization's refusal or a version pin resting
on the older reading is then wrong in a way no build shows. Compare the date of
the reading with the product's releases since, and re-read the reference where
one has shipped. APISIX 3.18 carries a semantic cache, its `ai-cache` plugin,
and a check for prompt injection, its `ai-lakera-guard` plugin, which has Lakera
Guard inspect each prompt; APISIX 3.17 carries neither. A reading of APISIX 3.17
answers neither question for 3.18, and a refusal written from it would refuse
what 3.18 can do.

### Core, option or drop — and a protection keeps its default

Classify every member of a Feature before writing it: each promise its
description makes and each value its schema declares.

- **Core** — honoured exactly, by configuration, by two or more independent
  products, and by nearly every product that offers the capability at all.
  Every attachment gets it, and the Feature's description states it.
- **Option** — a declared value that a realization honours, or refuses by name
  without refusing the rest of the attachment. It carries a default where one
  value suits every attachment, and is required where none does, as a period
  budget's unit, scope and period are.
- **Drop** — a member no product honours, in its configuration or in code a
  realization delivers into it, leaves the Feature's promise. Where it is one
  realization's own behaviour, that realization's description states it.

**The deciding question is not how many products honour a member, but whether a
realization lacking it can decline it alone.** A member several products honour
is still an option where many products offering the capability lack it — a cost
in an audit record, a budget in a currency, a list of patterns a request must
match to be admitted — because a realization for a product without it refuses
that value and keeps the rest. A member exactly one product honours leaves the Feature and
becomes a value on that product's own Component, as "What earns a Feature" sets
out; a protection is the exception, kept however few products give it, as the
rule on guarantees below sets out.

A cost in an audit record shows the question at work. LiteLLM v1.103.1 records
what each request cost in US dollars, the unit its budgets count in; Kong 3.9.3
computes a cost only where both of a model's per-token prices are configured,
and names no currency; and the per-request cost Envoy AI Gateway v1.1.0
computes is a whole number with no unit, the gateway keeping no prices. A
gateway that keeps a record of each request can lack the cost, so the cost is an
option: a realization for such a gateway refuses it by name and keeps the
record.

**A guarantee a gateway may lack is a value with a default, never an
unconditional sentence.** Where the guarantee is a protection, its default is
the protection. An attachment written without the value gets the protection; a
realization whose product cannot give it refuses the attachment by name at
build time; and an author who accepts less writes the relaxation visibly, on
that attachment, in the document of the author who decides it — where that is
the operator, in the attachment's `infra` in the Release, as "Who writes each
input, and where a Feature is attached" below sets out. A realization never
accepts such a value and ignores it. A sentence in a Feature's description that
no realization can decline — "a request a realization cannot mask is refused
before it is forwarded", say — leaves a product lacking that one promise
nothing to refuse but the whole Feature, so its realization halts on every
attachment rather than on the one promise the product lacks.

Kong Gateway Enterprise's AI PII Sanitizer, which reaches replies from Kong
3.12, masks a reply's message text and not the reasoning a reasoning model
returns beside it. `core/data-masking` declares masking that reasoning as
`mask_reasoning`, an `infra` value on by default, so Kong's realization refuses
an attachment masking replies while it is on, naming the value, and the
operator who accepts reasoning reaching callers unmasked sets
`mask_reasoning: false` on that attachment in the Release.

### Before a realization refuses, establish whose refusal it is

A refusal by name is honest when the **product** lacks the capability. It is a
catalog defect when the cause is the catalog's own rendering of the product: a
gateway rendered with no caller authentication, a route rendered with a single
target, an input the catalog never supplies, such as a price. A catalog cause is
fixed in the catalog — render the authentication, the targets, the input — and
the refusal that remains names only what the product lacks. So before writing a
refusal, ask whether the product, configured as its own reference allows, would
keep the promise; where it would, the refusal is the catalog's to remove rather
than to ship.

APISIX 3.18.0's semantic cache keeps one caller's stored replies apart from
another's by the consumer an authentication plugin names, where its
`include_consumer` setting is on, and otherwise only by values the request
carries, which it does not verify. A rendering of the gateway that declares no
consumer leaves the cache no caller to keep apart, so a realization over that
rendering could only refuse every attachment, and the refusal would be the
catalog's rather than APISIX's. So `core/gateway/apisix` renders a consumer
with key authentication for each caller its Release declares, the cache keeps
each key's replies apart, and `semantic-caching-apisix` refuses by name only
what APISIX itself cannot keep: the end users behind one key, under `scope:
end_user`. The same consumers let `period-budget-apisix` count each caller
apart.

### One home per setting

A choice a Feature declares is not also a value on the gateway's Component. Two
homes for one setting disagree the first time one of them is edited, and a
reader of either cannot tell which one the rendered configuration took. Where
both exist, one is retired, and the test in "What earns a Feature" says which: a
choice two or more products offer has earned its Feature, and the Feature is its
home; a choice only one product offers is a value on that product's Component,
and no Feature declares it.

LiteLLM v1.103.1 picks among the entries of its model map that publish one
alias by a single setting, its routing strategy, which offers latency-based
routing; the AI Proxy Advanced plugin of Kong's AI Gateway Enterprise picks the
target observed to answer quickest as well. Choosing a target by latency passes
the test, so its home is `core/target-selection`: `core/gateway/litellm`
declares no routing-strategy value of its own, and `target-selection-litellm`
writes the proxy's setting from the attachment.

### A guarantee held in catalog code pins the product version it was proven at

Most realizations keep a promise through the product's own configuration, which
the product's reference documents. Where a guarantee is kept instead by code the
catalog delivers into the product — a module the product loads, a hook it
calls — the guarantee is only as good as the product internals that code was
proven against. So the Recipe delivering that code halts the build on any
product version outside the set the code was proven at, naming that set, and a
version joins the set only once the proof has run at it.

"Version knobs: `engine_version` and `source_version`", under "Component Schema
Pattern", states both knobs as conventions: "Both are provider-neutral
conventions — the compiler reads neither; each Recipe decides which it honors
and how." A Recipe delivering such code decides it this way: it honours
`engine_version` within the proven set and refuses every other value by name,
because outside that set the delivered code may fail to load or, worse, load
over changed internals and keep less than the Feature promises while the build
stays green.

The masking `core/gateway/litellm` delivers for `core/data-masking` is Python
the proxy loads, which imports LiteLLM's own guardrail classes, its Presidio
guardrail and its content filter among them, so it rests on internals no
LiteLLM setting describes. What it refuses and withholds is proven by running it
at LiteLLM v1.103.1, the release the gateway's `engine_version` defaults to; at
another release the import may fail and stop the proxy, or succeed over changed
internals and keep less. So each of the gateway's Recipes — the workload
synthesis and the chart Recipe, which deliver the same code from the same two
bundles — holds the releases that code is proven at in one local of its own,
the two lists changed together, and an assertion reading it halts the build on
any other `engine_version`, naming them. The halt holds on every Release of
either Recipe, masking attached or not, because the request guard each delivers
on every Release is code of the same kind.

### Who writes each input, and where a Feature is attached

A Feature's `schema` has the two authored pillars a Component's has, with the
owners "Component Schema Pattern" gives them: `values`, which the developer
writes in the Aggregate, and `infra`, which the operator writes in the Release.
Which pillar declares an input, and so where the Feature is attached, follows
from one question: which of the two decides it.

**This is a convention of this catalog, not something the compiler enforces.**
The compiler validates each pillar against the Feature's schema and pipes the
strings through. It is agnostic to which author decided an input, and it accepts a
Feature attached in either document, so an enterprise catalog is free to draw
the line elsewhere. One line under the convention is the schema's rather than
the catalog's: the Release schema admits no `values`, so a Feature whose
`values` require a field with no default cannot be attached by a Release alone.
Such an attachment halts, naming each value it requires.

**An input belongs to the author who decides it.**

- **`values`** carries application behaviour the developer decides once and
  keeps the same in every environment: what to mask, which guardrail lists
  apply, which models a request may be routed to, how a response is validated,
  what is counted.
- **`infra`** carries what the operator decides, and anything that varies from
  one environment to the next: capacity and spending limits (a budget's ceiling
  and its period, a concurrency cap), sizing and sampling shares, a retention
  period compliance sets, the names an environment gives things (a hostname, a
  namespace, an identity), ports and network seams, and whether and how often a
  platform scrapes.
- **A guardrail list stays with the developer; its limits do not.** The
  patterns a request is checked against are part of what the application is,
  so the list is `values`. How much the traffic may spend, or how many requests
  may run at once, is the operator's, so each is `infra`.
- **A credential's locator is the one input either author writes**, in
  `values` or in `infra` and exactly one per attachment, as "Who supplies a
  credential's locator: values or infra, exactly one" sets out. Every other
  input has one owner.

**Where a Feature is attached follows from its inputs.**

- **When every input is the operator's, the operator attaches it in the
  Release**: on a boundary, under the boundary's `features:`, or on one
  component, under `components.<id>.features`.
- **When any input is the developer's, the developer attaches it in the
  Aggregate**, and the operator sizes that same attachment in the Release,
  writing only `infra`, under the same attachment name on the Release's entry
  for the component; the type and the values come from the Aggregate. It is
  also how the operator names the secret of a credential the Aggregate attached
  without one.
- **When it has no inputs, the author who decides the attachment itself
  attaches it.** `core/manual-trigger` takes none, and whether a task runs only
  when someone starts it is part of what the task is, so the developer attaches
  it in the Aggregate and the Release writes nothing for it.

**`core/compose-bridge` is the first case.** Its port base, the port a bridged
edge falls back to when two edges resolve to one listen port, is a seam of the
network the Release lands in, and so is the published field it takes as the
upstream address. Both inputs are `infra`, and its `values` declare nothing of
their own:

```yaml
# feature/core/compose-bridge/1.0.0/feature.yaml — descriptions left out
spec:
  schema:
    values:
      $ref: "BaseComponents#/schemas/BaseFeatureParameter"
    infra:
      portBase:
        type: integer
        default: 10000
      providesField:
        type: string
        default: host
```

The operator attaches it in the Release, on the boundary holding the seam; two
bridged edges resolving to one port then render one of them at 12000 rather
than at 10000:

```yaml
# the Release
spec:
  boundaries:
    bridge:
      features:
        gateway:
          type: core/compose-bridge:1.0.0
          infra:
            portBase: 12000
```

**`core/period-budget` is the second case.** What a budget counts and whose traffic
one limit covers are part of what the application is, so `unit` and `scope`
are `values`; how much the traffic may spend and over how long are decided per
environment, so `limit` and `period` are `infra`:

```yaml
# feature/core/period-budget/1.0.0/feature.yaml — descriptions left out
spec:
  schema:
    values:
      $ref: "BaseComponents#/schemas/BaseFeatureParameter"
      properties:
        scope:
          type: string
          enum: [gateway, caller, model]
        unit:
          type: string
          enum: [usd, total_tokens, prompt_tokens, completion_tokens]
      required: [scope, unit]
    infra:
      limit:
        type: number
        exclusiveMinimum: 0
        required: true
      period:
        type: string
        pattern: "^[1-9][0-9]*(s|m|h|d|mo)$"
        required: true
```

The developer attaches it in the Aggregate, and the operator sizes the same
attachment on the Release's entry for the component:

```yaml
# the Aggregate — the gateway's other values and its credentials left out
spec:
  components:
    router:
      type: core/gateway/litellm
      features:
        budget:
          type: core/period-budget
          values:
            scope: gateway
            unit: usd
```

```yaml
# the Release
spec:
  components:
    router:
      features:
        budget:
          infra:
            limit: 50
            period: 1d
```

Each pillar is closed and both `limit` and `period` are required, so the build
halts on an Aggregate writing either of them in `values`, and on a Release
leaving either out.

**`core/public-ingress` splits the same way.** The request path a component
serves is part of what the application is, so `path` is `values`; the hostname
is the environment's name for the component, and the routing knobs describe the
cluster it lands in, so `host` and every other input are `infra`:

```yaml
# feature/core/public-ingress/1.0.0/feature.yaml — descriptions left out
spec:
  schema:
    values:
      $ref: "BaseComponents#/schemas/BaseFeatureParameter"
      properties:
        path:
          type: string
    infra:
      host:
        type: string
      control_plane_present:
        type: boolean
        default: false
      service_name:
        type: string
      service_port_name:
        type: string
      ingress_class_name:
        type: string
      tls_secret:
        type: string
```

The developer attaches it in the Aggregate with the path, and the operator
writes the host and the cluster knobs on the Release's entry for the component,
under the same attachment name:

```yaml
# the Aggregate — the router's values and its other attachments left out
spec:
  components:
    router:
      type: core/gateway/litellm
      features:
        published:
          type: core/public-ingress
          values:
            path: /
```

```yaml
# the Release — the router's own infra and its other attachments left out
spec:
  components:
    router:
      features:
        published:
          infra:
            host: assistant.example.internal
            control_plane_present: true
            service_port_name: http
```

The rendered Ingress routes `assistant.example.internal` and `/` to the router's
Service. Each pillar is closed, so pulling the Release halts on an Aggregate
writing `host` in `values`, and on a Release writing `path` in `infra`, naming
the field. A path that has to differ from one environment to the next is a
parameter of the Aggregate, written `path: "{{ .parameters.<name> }}"`, which
each Release fulfils. `core/http-route` takes the same split.

**A need the developer declares and the operator supplies is a slot.** A
workload that needs an identity to run under is the case: the Component
declares a slot for it in its `featuresSchema`, and the Release fills that slot
on its entry for the component, with the Feature's `type` and its `infra`. The
need is never written as an attachment in the Aggregate that configures
nothing. The slot's fields are in the Component reference, under
["Attachment Slots: `featuresSchema`"](https://github.com/aggrega-ai/aggrega-docs/blob/main/language-reference/entities/component.md#attachment-slots-featuresschema).

In the worked example
[`workload-identity-binding`](https://github.com/aggrega-ai/aggrega-docs/blob/main/language-reference/examples/workload-identity-binding/),
the workload's Component declares the need:

```yaml
# the Component — its schema left out
spec:
  featuresSchema:
    identity:
      required: true
      selector: "feature.aggrega.ai/kind!=secret"
      inject: []
```

The Aggregate writes nothing for it, and the Release fills the slot on its
entry for the component with `core/gcp-workload-identity`:

```yaml
# the Release
spec:
  boundaries:
    main:
      components:
        app:
          features:
            identity:
              type: core/gcp-workload-identity
              infra:
                service_account_name: app-workload-identity
                gcp_service_account: app-dev@example-project.iam.gserviceaccount.com
```

A Release that leaves the slot unfilled halts, naming the slot. The identity
Features carry no label, so the selector admits them by excluding what they are
not: a credential filling the slot halts, and `core/aws-irsa` fills it as
`core/gcp-workload-identity` does.

**A Feature's description says who attaches it and where**, in those terms:
attached by the operator in the Release, on a boundary or on a component; or
attached by the developer in the Aggregate, naming the inputs the operator
sizes in the Release.

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
- **backup** — a datastore backed up on a schedule, `core/backup`: a managed
  database service's own automated backup, which the database's own Recipe
  configures from an attachment bound to `terraform/backup-native` or
  `cloudformation/backup-native`; an AWS Backup plan and selection run under
  the IAM role `infra.role_arn` names, beside which an Amazon RDS instance keeps
  its own automated backups unless `infra.keep_automated_backups` is false; or
  the resource a backup product reconciles — a Velero Schedule, a K8up
  Schedule, a CloudNativePG ScheduledBackup, a mariadb-operator Backup. Where a backup goes is always
  written: the `store` connection sends it to a bucket, and `infra.volume`
  (`size`, and `storage_class`, the cluster's default where it is unset) to a
  disk volume in the cluster, for a product that can keep backups there. An
  attachment carrying both halts; one carrying neither halts under a
  realization that writes to a bucket or a volume, while a realization keeping
  backups in storage of its own, such as AWS Backup's vault, refuses both. A
  realization whose product cannot keep a backup on a volume refuses
  `infra.volume` by name. A backup on a volume sits in the same cluster as
  the data it protects, so it guards against a bad change or deletion but not
  against losing the cluster. `infra.run_as_user` and `infra.run_as_group` set
  the user and group a product's own backup jobs run as, written into the
  jobs' security context by a realization that starts them, such as K8up's,
  and refused by name by every other realization. `infra.point_in_time_recovery`
  asks for restores to any moment of the retention window rather than only to
  the moment of a backup. It declares no schema default, because there is no
  single one: left out, each product keeps its own default, which its
  realization's description states, and a written value the product cannot
  keep halts by name. Amazon RDS keeps it for as long as it keeps automated
  backups, and Azure Database for PostgreSQL flexible server for every server,
  so `true` is what they give and `false` halts. Cloud SQL's Recipes keep it on
  — point-in-time recovery on PostgreSQL, binary logging on MySQL — since Cloud
  SQL makes an instance highly available, and a MySQL instance takes read
  replicas, only with it on; `false` turns it off and halts beside either. AWS
  Backup keeps a continuous backup only where a rule asks for one, so it is
  off until `true` writes the rule's continuous-backup setting, which halts
  above 35 days and beside `infra.keep_automated_backups: false`; the RDS
  instance's own automated backups then follow AWS Backup's retention, and a
  native attachment beside it halts. CloudNativePG archives its write-ahead
  log continuously through the Barman Cloud plugin, so it is on and `false`
  halts. mariadb-operator's logical Backup, Velero, K8up, KubeStash and Kasten
  keep no log of the changes between backups, so it is off and `true` halts
- **on-demand runs** — a task held until someone starts it: a suspended
  CronJob, a Compose service behind a profile, an Amazon ECS task definition
  a RunTask call starts
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
workload dials or edges, wherever a control earns a Feature; a control only one
product in the field has is a value on that product's own Component, as "What
earns a Feature" sets out.

### Network policy: who may connect to a component, and where it may connect

The catalog's network-policy family is two Features, one per direction of a
connection, reading the same `uses` edges from opposite ends.
`core/caller-allowlist` restricts who may connect to the component it is
attached to: the components whose `uses` edges point at it.
`core/egress-allowlist` restricts where the component it is attached to may
connect: the components its own `uses` edges point at. One edge from a gateway
to a model server is read by both — the model server's caller allowlist admits
the gateway's pods, and the gateway's egress allowlist admits the model
server's pods — so, with both attached, a connection the Aggregate declares
stays open at both ends, and one it does not declare can be refused at either.
Every input of both is `infra`, so the operator attaches them in the Release,
under `components.<id>.features`, as "Who writes each input, and where a
Feature is attached" sets out. caller-allowlist applies to `server` and
`stateful-server`, the types that serve connections; egress-allowlist to every
type that runs pods: `server`, `stateful-server`, `worker`, `task` and
`function`.

**Pods are selected from what each render emitted, never restated by hand.**
`helm/caller-allowlist` sets `readsCallerRenderFacts: true` and reads each
caller's render facts on `.context.used_by`; `helm/egress-allowlist` sets
`readsTargetRenderFacts: true` and reads each target's at
`.context.uses.<alias>.render_facts`. Both read the host's own at
`.context.render_facts`, and either key makes the attachment render after
every component, so every render it reads is complete. From the helm
provider's `pod_template_labels`, `controller_selectors` and `container_ports`,
each workload's pods are named by one peer carrying two selectors that must
both match: its namespace, by the `kubernetes.io/metadata.name` label, and its
pods, by the selector its controller writes or, where it writes none, by the
identity labels the build stamps, taken only from a template carrying
`aggrega.ai/component-id` and less the two carrying a version. A chart's pod
templates carry none of those labels, so a chart-rendered component is selected
by its controller's selector. A workload with neither, one emitted into no
namespace, and two controllers sharing one workload's kind, name and namespace
each halt the build. Each Feature writes one NetworkPolicy per workload its host
renders, in that workload's namespace, named from the workload's name and kind
and the attachment name, so a caller allowlist and an egress allowlist on one
workload write two policies.

**Ports are what containers declare.** caller-allowlist admits its peers on the
ports the host's containers declare; egress-allowlist admits each target on the
ports that target's own containers declare, never the port the target provides
to its callers, which is usually a Service port mapped onto a container's. A
port a workload serves on but does not declare is not admitted, and the build
cannot tell, so a Recipe declares on its containers every port they serve on.
That is why `helm/caller-allowlist-higress` refuses caller-allowlist on
`core/gateway/higress`: in a cluster layout its gateway container declares only
its telemetry ports, and its control plane programs the port that serves model
traffic.

**Own pods, and what each admits beyond the Aggregate.** Both admit the
attached component's own pods, on the ports their containers declare, so a
clustered server keeps reaching its peers. Beyond that, the ingress side names
sources and the egress side names destinations:

- caller-allowlist's `admitted_sources` lists sources outside the Aggregate —
  an ingress controller, a monitoring agent — each entry an address range
  (`cidr`) or pods (`namespace`, `pod_labels`, or both), admitted on the
  declared callers' ports. An entry naming a range together with pods, or
  naming nothing, halts.
- egress-allowlist admits the cluster's DNS on UDP and TCP port 53, to the pods
  `dns_pods` names with the same `namespace` and `pod_labels` fields. Left
  unset, they are the pods labelled `k8s-app: kube-dns` in `kube-system`; the
  helm FeatureRecipe applies that default, and a value the Release writes
  replaces it whole. A value naming neither field halts.
- egress-allowlist's `admitted_destinations` lists address ranges, each entry
  naming one connection by its `target`, the target's instance ID, and one
  `cidr`; a target reached at several ranges takes one entry per range. An
  entry with no target, a target the component has no connection to, or an
  empty range halts, naming the entry.

**A target whose render emits no pods is admitted only by address range.** A
target the cluster does not run — a hosted model API, a remote agent — renders
no pod template, and neither does a component another provider renders or one
whose pods a controller creates at runtime; a network policy cannot name such a
destination by its pods, nor any destination by its host name. egress-allowlist
recognises such a connection by its target's render emitting no pods, never by
a label, and admits it only through the `admitted_destinations` entries naming
its target; without one, the build halts, naming every such connection in one
message. A range carries no port and no connection: it admits its addresses on
any port, for every connection of the component. The build is ahead-of-time
and resolves no host name, so nothing checks that a range covers the address
the target is reached at. Every other outbound connection is refused, the
cluster's API server included. The ingress side has no such opening: a caller
whose render emits no pods halts the build, naming it, whatever
`admitted_sources` lists.

**The runtime prerequisite is affirmed, not assumed.** A network policy
restricts nothing unless the cluster's network plugin enforces it, and the
compiler cannot inspect the cluster, so `helm/caller-allowlist` and
`helm/egress-allowlist` halt the build unless the Release sets
`infra.control_plane_present: true` on the attachment. Network policies add up:
where another policy selects the same pods in the same direction, a connection
either of them admits is admitted.

**Compose.** Neither Feature restricts anything on compose, and both halt
there. caller-allowlist has no compose FeatureRecipe, so binding it on compose
halts for want of a realization. egress-allowlist has one,
`compose/egress-allowlist`, whose single assertion halts every attachment,
naming the Feature and saying compose has no network policy.

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
