# Contributing

This repository is intentionally publication-safe. Changes should preserve that boundary.

## Before opening a pull request

1. Keep all sample data fictional.
2. Do not add production credentials, tenant IDs, internal URLs, screenshots, private schemas, or employer-specific business rules.
3. Keep third-party integrations behind adapters and map vendor payloads into portfolio-owned contracts.
4. Run `bash scripts/scan-for-sensitive.sh`.
5. Build and test the .NET projects with the SDK pinned by `global.json`.
6. Use Node from `.nvmrc`, generate frontend lockfiles if they are not present, then build all three Angular apps.
7. Run `docker compose config` and the complete suite when Docker is available.

The CI workflow repeats the publication scan, backend build/tests, dependency vulnerability checks, frontend audit/typecheck/build, and Compose contract validation.
