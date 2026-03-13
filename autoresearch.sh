#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
MIX_ENV=test mix test 2>&1 | tail -5
