# Changelog

This file lists the releases of the Aggrega catalog, each named by the date of its release.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [2026.11.27] - 2026-11-27

### Added

- Cloud Run servers and workers on Terraform mount file entries as Secret Manager secret volumes.
- The catalog adds managed MySQL on Azure, Aurora on AWS, AlloyDB and Memorystore for Redis on Google Cloud, and cloud server, task and function Recipes.
- Shared settings attach on Terraform as an AWS Systems Manager parameter or as a key-value in the operator's Azure App Configuration store.
- A manual trigger attaches to Container Apps jobs on Azure Resource Manager: the job deploys without a schedule and starts only by hand.
- Azure API Management on Azure Resource Manager writes token budgets, prompt shields, retries and semantic caching from attached Features into its API policy.
- Public ingress attaches to App Service servers on Terraform and Azure Resource Manager: a custom domain bound with the operator's certificate by `certificate_id`.
- Azure services join the catalog as Components built for Azure Resource Manager and Terraform: Cosmos DB, Service Bus, Key Vault, Front Door and more.
- AWS services join the catalog as Components built for CloudFormation and Terraform: DynamoDB, SQS, EventBridge, Cognito, CloudFront and more.
- Google Cloud services join the catalog as Components built for Terraform: BigQuery, Pub/Sub, Firestore, Cloud KMS and more.
- `core/datastore/sql-server` and `core/network/dns-record` build one Aggregate for Azure, AWS or Google Cloud.

### Changed

- Compute Recipes on Cloud Run, ECS and Container Apps share one body per target; upgrades keep running resources.
- Compute Recipes on the shared bodies keep minor versions although `aggrega lint --pre-publish` rates them major, reading their move into libraries as a removal.
- `terraform/postgres-flexible-server` 1.1.0 turns the Azure Verified Module's telemetry off; set `infra.overrides.enable_telemetry: true` to keep it.
- `terraform/postgres-flexible-server` 1.1.0 halts on an `infra.overrides` key it does not read; remove such keys before upgrading from 1.0.0.
- `manual-trigger` 1.1.0 on Terraform halts on `infra` set on its attachment; `backup-native` 1.1.0 serves `core/backup` 1.1.0 and refuses its `vault_id`.
