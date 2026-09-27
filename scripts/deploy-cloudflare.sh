#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-${PORTFOLIO_DOMAIN:-}}"

if [ -z "$DOMAIN" ]; then
  echo "Usage: PORTFOLIO_DOMAIN=example.com bash scripts/deploy-cloudflare.sh"
  echo "   or: bash scripts/deploy-cloudflare.sh example.com"
  exit 2
fi

for cmd in node npm npx curl openssl; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "$cmd is required."; exit 1; }
done

: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is required}"
: "${CLOUDFLARE_ACCOUNT_ID:?CLOUDFLARE_ACCOUNT_ID is required}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FREIGHT_HOST="${FREIGHT_HOST:-freight.$DOMAIN}"
LTL_HOST="${LTL_HOST:-ltl.$DOMAIN}"
YARD_HOST="${YARD_HOST:-yard.$DOMAIN}"

LOCAL_ENV="$ROOT/.cloudflare.local.env"
if [ -z "${YARD_LTL_SIGNING_KEY:-}" ]; then
  if [ -f "$LOCAL_ENV" ]; then
    # shellcheck disable=SC1090
    source "$LOCAL_ENV"
  fi
fi

if [ -z "${YARD_LTL_SIGNING_KEY:-}" ]; then
  YARD_LTL_SIGNING_KEY="$(openssl rand -hex 32)"
  umask 077
  printf 'YARD_LTL_SIGNING_KEY=%q\n' "$YARD_LTL_SIGNING_KEY" > "$LOCAL_ENV"
  echo "Generated a persistent local Yard/LTL signing key in .cloudflare.local.env"
fi
export YARD_LTL_SIGNING_KEY

render_config() {
  app="$1"
  template="$ROOT/cloudflare/$app/wrangler.template.jsonc"
  output="$ROOT/cloudflare/$app/wrangler.generated.jsonc"
  sed \
    -e "s|__FREIGHT_HOST__|$FREIGHT_HOST|g" \
    -e "s|__LTL_HOST__|$LTL_HOST|g" \
    -e "s|__YARD_HOST__|$YARD_HOST|g" \
    "$template" > "$output"
}

build_web() {
  app="$1"
  echo "==> Building $app frontend"
  npm install --prefix "$ROOT/apps/$app/web"
  npm run build --prefix "$ROOT/apps/$app/web"
}

prepare_worker() {
  app="$1"
  echo "==> Installing Cloudflare dependencies for $app"
  npm install --prefix "$ROOT/cloudflare/$app"
  render_config "$app"
}

put_secret() {
  app="$1"
  name="$2"
  value="$3"
  [ -n "$value" ] || return 0
  printf '%s' "$value" | (
    cd "$ROOT/cloudflare/$app"
    npx wrangler secret put "$name" --config wrangler.generated.jsonc
  )
}

deploy_app() {
  app="$1"
  echo "==> Deploying $app"
  (
    cd "$ROOT/cloudflare/$app"
    npx wrangler deploy --config wrangler.generated.jsonc
  )
}

for app in freight-ops ltl-planner yard-ops; do
  build_web "$app"
  prepare_worker "$app"
done

# Shared integration secret must be identical on both sides of the contract.
put_secret ltl-planner YARD_LTL_SIGNING_KEY "$YARD_LTL_SIGNING_KEY"
put_secret yard-ops YARD_LTL_SIGNING_KEY "$YARD_LTL_SIGNING_KEY"

# Alvys is optional. Demo mode remains active when credentials are absent.
if [ -n "${ALVYS_CLIENT_ID:-}" ] && [ -n "${ALVYS_CLIENT_SECRET:-}" ]; then
  for app in freight-ops ltl-planner yard-ops; do
    put_secret "$app" ALVYS_CLIENT_ID "$ALVYS_CLIENT_ID"
    put_secret "$app" ALVYS_CLIENT_SECRET "$ALVYS_CLIENT_SECRET"
  done
else
  echo "ALVYS_CLIENT_ID / ALVYS_CLIENT_SECRET not set; deploying in demo mode."
fi

# Dependency order matters: Yard's production configuration points at LTL.
deploy_app ltl-planner
deploy_app freight-ops
deploy_app yard-ops

wait_for() {
  url="$1"
  pattern="$2"
  for attempt in $(seq 1 18); do
    body="$(curl --fail --silent --show-error --retry 2 --retry-delay 2 --retry-all-errors "$url" 2>/dev/null || true)"
    if printf '%s' "$body" | grep -q "$pattern"; then
      return 0
    fi
    echo "Waiting for $url (attempt $attempt/18)..."
    sleep 10
  done
  echo "Smoke test failed: $url"
  return 1
}

echo "==> Smoke testing production"
wait_for "https://$FREIGHT_HOST/health" "Healthy"
wait_for "https://$LTL_HOST/health" "Healthy"
wait_for "https://$YARD_HOST/health" "Healthy"

wait_for "https://$FREIGHT_HOST/" "<app-root"
wait_for "https://$LTL_HOST/" "<app-root"
wait_for "https://$YARD_HOST/" "<app-root"

# Exercise the Yard -> LTL synchronous service boundary through the production Yard API.
wait_for "https://$YARD_HOST/api/ltl/candidates/YD-1001" "\["

cat <<EOF

Cloudflare deployment complete:
  Freight Ops: https://$FREIGHT_HOST
  LTL Planner: https://$LTL_HOST
  Yard Ops:    https://$YARD_HOST

Yard is configured to call:
  https://$LTL_HOST/
EOF
