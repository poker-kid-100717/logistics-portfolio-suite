#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OWNER="${GITHUB_OWNER:-poker-kid-100717}"
REPO_NAME="${1:-logistics-portfolio-suite}"
VISIBILITY="${2:-public}"

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required." >&2
  exit 1
fi

gh auth status
bash scripts/scan-for-sensitive.sh

if [ -f .env ]; then
  echo "Local .env detected. It is ignored and will not be committed."
fi

if [ ! -d .git ]; then
  git init -b main
fi

git add .
if ! git diff --cached --quiet; then
  git commit -m "Create clean-room logistics portfolio suite"
fi

if git remote get-url origin >/dev/null 2>&1; then
  echo "origin already exists: $(git remote get-url origin)"
  git push -u origin main
else
  case "$VISIBILITY" in
    public|private) ;;
    *) echo "Visibility must be public or private." >&2; exit 1 ;;
  esac
  gh repo create "$OWNER/$REPO_NAME" "--$VISIBILITY" --source=. --remote=origin --push \
    --description "Clean-room .NET 10 + Angular 22 logistics portfolio: freight operations, LTL planning, Yard-to-LTL integration, and optional read-only Alvys Public API adapters."
fi
