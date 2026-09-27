#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-}"
if [ -z "$DOMAIN" ]; then
  echo "Usage: bash scripts/setup-cloudflare-github.sh example.com"
  exit 2
fi

command -v gh >/dev/null 2>&1 || { echo "GitHub CLI (gh) is required."; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "openssl is required."; exit 1; }

REPO="${GITHUB_REPOSITORY:-poker-kid-100717/logistics-portfolio-suite}"

gh variable set PORTFOLIO_DOMAIN --repo "$REPO" --body "$DOMAIN"

if ! gh secret list --repo "$REPO" | grep -q '^YARD_LTL_SIGNING_KEY'; then
  openssl rand -hex 32 | gh secret set YARD_LTL_SIGNING_KEY --repo "$REPO"
  echo "Created YARD_LTL_SIGNING_KEY."
fi

cat <<EOF

GitHub repository variable configured:
  PORTFOLIO_DOMAIN=$DOMAIN

Required GitHub secrets before automatic deployment:
  CLOUDFLARE_API_TOKEN
  CLOUDFLARE_ACCOUNT_ID

Optional secrets for live Alvys reads:
  ALVYS_CLIENT_ID
  ALVYS_CLIENT_SECRET

Set a secret with:
  gh secret set SECRET_NAME --repo $REPO

Default production hosts will be:
  freight.$DOMAIN
  ltl.$DOMAIN
  yard.$DOMAIN

Override any hostname with GitHub repository variables:
  FREIGHT_HOST
  LTL_HOST
  YARD_HOST
EOF
