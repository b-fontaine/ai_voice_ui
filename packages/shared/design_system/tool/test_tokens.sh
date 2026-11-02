#!/usr/bin/env bash
# Tests du générateur de tokens par fixtures (développement uniquement, hors
# porte : Node n'est jamais requis par la porte).
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
trap 'rm -rf node_modules' EXIT
npm ci --ignore-scripts --no-audit --no-fund
node --test build_tokens.test.mjs
