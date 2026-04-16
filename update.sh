#!/usr/bin/env bash
# Thin wrapper; delegates to `up --self-update`.
set -Eeuo pipefail
REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
exec bash "$REPO_DIR/src/emerger.sh" --self-update "$@"
