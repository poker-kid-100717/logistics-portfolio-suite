#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for app in freight-ops ltl-planner yard-ops; do
  echo "Generating lockfile for $app"
  (cd "$ROOT/apps/$app/web" && npm install --package-lock-only --ignore-scripts)
done

echo "Lockfiles generated. Run the production builds before committing them."
