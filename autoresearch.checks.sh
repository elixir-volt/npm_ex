#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "=== Format check ==="
mix format --check-formatted

echo "=== Credo ==="
mix credo --strict

echo "=== ExDNA ==="
mix ex_dna

echo "=== Tests ==="
MIX_ENV=test mix test
