# Pinning the tooling image in a publisher workflow

A repository that publishes artifacts to the registry runs its publish steps
inside the `aggrega` tooling image (`hub.aggrega.ai/tools/aggrega`) so the CLI
is already on `PATH` without a toolchain build. Because the image evolves and
can carry a different plugin ABI over time, every consumer that runs inside it
follows the same three-part coupling pattern. This repository's catalog publish
workflow is the reference implementation; the docs publisher and any future
plugin publisher adopt the identical shape.

## The pattern

### 1. A single reviewed pin location

The tooling-image tag lives in exactly one place: the `container.image`
reference of the publish workflow. The job derives its execution image from
that one line, and there is no second copy of the version to drift from. Bumping
the pinned tag is a deliberate edit to that single reference, reviewed and
merged like any other change.

### 2. Update pull requests, never auto-adoption

A dependency-update bot watches the pinned reference and opens a pull request
when a newer tag is published. It never auto-merges. A human reviews the
proposed bump — together with the compatibility gate below — and merges it
deliberately. New tags are never adopted automatically, and the workflow never
silently follows a moving tag.

The bot configuration for a private registry needs registry credentials
supplied in the bot itself (as host rules), not committed to the repository. The
built-in workflow manager reads the `container.image` reference directly, so no
custom matcher is required to track it.

### 3. A plugin-ABI compatibility gate

The publish workflow carries a gate step that runs early, inside the pinned
image. It reads the image's own reported ABI version — `aggrega version --json`
reports it, and the image also exposes it as the `ai.aggrega.abi-version`
manifest label for a registry-level read — and compares it against the ABI
version this repository is authored against, held as a single reviewed value in
the workflow.

On a match the gate passes silently. On a mismatch it fails loudly and halts the
run. A human then reviews catalog compatibility and, only if the new ABI is
intended, bumps the expected ABI value in the same reviewed change that adopts
the new image tag. The gate is the load-bearing safety net: it protects the
publish whether or not the update bot is wired, and it turns an ABI-crossing
image bump into a conscious human decision rather than a surprise at publish
time.

The gate script lives in the consumer repository, not inside the tooling image.
A check shipped inside the image being validated could not be trusted to report
that image's own incompatibility.

## Adopting the pattern in another publisher

A new consumer repository (the docs publisher, a future plugin publisher) copies
the same three pieces:

- pin the tooling image once, in the publisher workflow's `container.image`;
- add a dependency-update configuration that watches that reference, opens
  pull requests, and never auto-merges;
- add the ABI-compatibility gate step and the single expected-ABI value it
  compares against, so an ABI-crossing image is caught before it publishes.

The expected-ABI value each consumer holds is the ABI its own content is
authored against; the gate keeps that expectation and the pinned image in
agreement, and makes any divergence a reviewed decision.
