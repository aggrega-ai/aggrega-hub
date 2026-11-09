# aggrega-hub

This repository holds the standard-library catalog of [Aggrega](https://aggrega.ai) entities, the catalog published on the `hub.aggrega.ai` registry.

The catalog is `aggrega-catalog/`, with one directory per entity kind: `component/`, `feature/`, `recipe/`, `feature-recipe/`, `aggregate/`, `plugin/`, and the four libraries `schemalibrary/`, `mappinglibrary/`, `workloadlibrary/` and `artifactlibrary/`. Below the kind, the path is the entity's identity followed by its version, so `type: core/datastore/mariadb:1.0.0` names `component/core/datastore/mariadb/1.0.0/component.yaml`. A Component's path carries its category, the same word as its `component.aggrega.ai/category` label; a Feature's does not (`feature/core/data-masking/1.0.0/feature.yaml`); a Recipe's or FeatureRecipe's starts with its capability (`recipe/helm/mariadb/1.0.0/recipe.yaml`). [Catalog conventions](docs/catalog-conventions-and-patches.md) is the reference for entity naming, the directory layout, labels and YAML formatting, and every addition to the catalog follows it.

The [Publish and sign catalog](.github/workflows/catalog-publish-sign.yml) workflow publishes `aggrega-catalog/` when a release tag (`v*`) is pushed or when it is run by hand with `dry_run` off, never on a merge to a branch: it publishes the entities that changed since the last publish, or the whole catalog on a manual full run, and signs each one keyless through Sigstore. Plugin entities are the exception: they are generated and published with each compiler release, not from this repository.

A build reaches these entities through `hub.aggrega.ai`, the default registry: `aggrega pull`, or a build run with `--auto-pull`, fetches the ones a Release needs into the local cache and pins them in the Release's lockfile. To build against a checkout of this repository instead, list its `aggrega-catalog/` directory under `workspace.catalog_dirs` in your `.aggrega-config.yaml`. [Catalog and Registry](https://aggrega.ai/docs/architecture/13-catalog-and-registry/) describes how a reference is resolved.

## License

The Aggrega standard-library catalog is released under the Apache License, Version 2.0; the full text is in the [`LICENSE`](LICENSE) file.
