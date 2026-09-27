# Logistics Portfolio Suite

A clean-room portfolio reconstruction of three logistics software problems: freight/customer operations, LTL planning, and yard execution. The code in this repository was written for a personal engineering portfolio from generic workflow requirements and public vendor documentation. It does not contain former-employer source code, data, credentials, tenant identifiers, internal URLs, customer names, private schemas, or company-specific business rules.

## Applications

| App | Purpose | API | UI |
| --- | --- | --- | --- |
| Freight Ops | Customer/account intelligence, opportunity queue, operational dashboard, external load visibility | http://localhost:5101 | http://localhost:4201 |
| LTL Planner | Explainable shipment-to-truck planning, capacity checks, plan builds, Yard event inbox | http://localhost:5102 | http://localhost:4202 |
| Yard Ops | Yard board, gate/dock workflows, public Alvys trailer reads, live Yard -> LTL integration | http://localhost:5103 | http://localhost:4203 |

## Why this exists

The goal is to demonstrate senior-level application engineering without publishing proprietary implementation details. The suite intentionally highlights:

- .NET 10 minimal APIs and typed service boundaries
- Angular 22 standalone applications and signal-based state
- third-party REST API integration through an adapter layer
- OAuth 2.0 client-credentials token acquisition
- retry/time-out behavior for external calls
- service-to-service HTTP contracts
- signed integration events and idempotent consumers
- an outbox-style background dispatcher for reliable Yard -> LTL delivery
- explainable planning logic rather than opaque automation
- Docker Compose orchestration and health checks
- synthetic demo data so the entire suite works without external credentials
- CI that builds/tests every backend and builds/audits every frontend

## Yard <-> LTL relationship

This is intentionally a first-class part of the portfolio architecture.

1. Yard requests LTL planning candidates through `GET /api/integrations/v1/yard/candidates`.
2. When a dock inspection marks a trailer ready, Yard creates an integration event in its local outbox.
3. A background dispatcher signs the exact JSON payload with HMAC-SHA256 and POSTs it to LTL.
4. LTL verifies the signature and stores events idempotently by `eventId`.
5. LTL surfaces the event on its operations screen.

That demonstrates both synchronous request/response integration and asynchronous event delivery without requiring a message broker for a small portfolio deployment.

## Alvys public API integration

The suite contains an optional, read-only Alvys adapter. Demo mode is the default and requires no credentials. Live mode uses only documented Public API behavior:

- OAuth 2.0 Client Credentials: `https://auth.alvys.com/oauth/token`
- Public API base: `https://integrations.alvys.com/api/p/`
- Loads Search: `/v1/loads/search`
- Trailers Search: `/v1/trailers/search`

The credentials stay server-side. The Angular applications never receive the client secret or bearer token. Live mode is opt-in through environment variables and the portfolio still works when Alvys is unavailable.

Public documentation used to author the adapter is listed in `docs/alvys-public-api.md`.

## Run the suite

Copy the example environment file:

```bash
cp .env.example .env
```

Then:

```bash
docker compose up --build
```

Open:

- Freight Ops: http://localhost:4201
- LTL Planner: http://localhost:4202
- Yard Ops: http://localhost:4203

### Demo mode

Leave the Alvys variables empty. The apps use synthetic data and every core portfolio workflow remains usable.

### Optional live Alvys reads

Set:

```text
ALVYS_MODE=Live
ALVYS_CLIENT_ID=...
ALVYS_CLIENT_SECRET=...
```

The adapter requests a server-side bearer token and uses the public read endpoints. This repository intentionally does not perform Alvys writes.

## Cloudflare production hosting

Cloudflare deployment is built into GitHub Actions. You do **not** need to run a setup or deployment script locally.

Default production hosts:

```text
freight.<your-domain>
ltl.<your-domain>
yard.<your-domain>
```

Each hostname serves the Angular SPA at Cloudflare's edge and forwards `/api/*` plus health routes to that application's .NET 10 Cloudflare Container.

Yard keeps its production service-to-service relationship with LTL:

```text
Yard Worker / Container
        |
        +--> https://ltl.<your-domain>/api/integrations/v1/yard/candidates
        |
        +--> signed Yard events -> LTL integration endpoint
```

### One-time GitHub configuration

Add these **repository secrets** in GitHub:

```text
CLOUDFLARE_API_TOKEN
CLOUDFLARE_ACCOUNT_ID
```

Recommended for a stable Yard ↔ LTL HMAC key:

```text
YARD_LTL_SIGNING_KEY
```

If the signing-key secret is omitted, the deployment action generates a shared key for that deployment and installs it on both services.

Optional secrets for live, read-only Alvys integration:

```text
ALVYS_CLIENT_ID
ALVYS_CLIENT_SECRET
```

For automatic deploys on every push to `main`, add this repository variable:

```text
PORTFOLIO_DOMAIN=example.com
```

Optional hostname overrides:

```text
FREIGHT_HOST
LTL_HOST
YARD_HOST
```

### First deployment from the GitHub UI

1. Open **Actions**.
2. Select **deploy-cloudflare-suite**.
3. Choose **Run workflow**.
4. Enter your base domain, such as `example.com`.
5. Run it.

The domain entered in the UI overrides `PORTFOLIO_DOMAIN` for that run, so the first manual deployment does not require the repository variable.

The workflow calls the repository's composite action at:

```text
.github/actions/deploy-logistics-suite/action.yml
```

That action:

1. builds all three Angular applications;
2. renders each Wrangler configuration with the requested hostnames;
3. deploys each Worker and .NET Container;
4. uploads Worker secrets alongside code;
5. keeps the Yard/LTL HMAC key identical on both services;
6. optionally enables Alvys live-read mode;
7. deploys LTL before Yard;
8. smoke-tests all three production applications;
9. exercises the real production Yard → LTL candidate lookup;
10. writes the deployed URLs to the GitHub Actions job summary.

Cloudflare Custom Domains are declared in the Wrangler templates, making those files the infrastructure source of truth.

### Optional local deployment

`scripts/deploy-cloudflare.sh` remains as a developer fallback, but it is not required for normal setup or deployment.

## Repository structure

```text
apps/
  freight-ops/
    api/
    tests/
    web/
  ltl-planner/
    api/
    tests/
    web/
  yard-ops/
    api/
    tests/
    web/
docs/
  architecture.md
  alvys-public-api.md
  clean-room-boundary.md
scripts/
  scan-for-sensitive.sh
```

## Technology

- .NET 10 / ASP.NET Core (SDK pinned in `global.json`)
- Angular 22 / TypeScript 6
- Node.js 24.15+ in CI (pinned via `.nvmrc`)
- `Microsoft.Extensions.Http.Resilience` for outbound HTTP resilience
- Docker / Docker Compose
- GitHub Actions

## Portfolio safety boundary

Before publishing, run:

```bash
bash scripts/scan-for-sensitive.sh
```

The script rejects known employer identifiers and common secret patterns. It is not a substitute for human review, but it gives the repository a repeatable publication gate.

## Publish to GitHub

After reviewing the repository, the included helper can create and push a new GitHub repository with the GitHub CLI:

```bash
bash scripts/publish-github.sh logistics-portfolio-suite public
```

The script runs the sensitive-content scan before publishing and keeps `.env` ignored.

## License

MIT. See `LICENSE`.

## Contract evolution

The Yard/LTL service contract is exposed under `/api/integrations/v1/` and integration events carry `schemaVersion: 1`. LTL rejects unknown schema versions at its edge, keeping version negotiation out of domain logic.
