#!/usr/bin/env bash
# Capture lab and/or dev account IDs into out/ (read-only STS).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_cli

SIDE="${1:-}"
if [[ -z "$SIDE" ]]; then
  echo "Usage: AWS_PROFILE=lab $0 lab" >&2
  echo "       AWS_PROFILE=dev $0 dev" >&2
  exit 1
fi
require_profile
ensure_dir "${OUT_DIR}/${SIDE}"
ID="$(account_id)"
echo "$ID" > "${OUT_DIR}/${SIDE}/account-id.txt"
echo "$REGION" > "${OUT_DIR}/${SIDE}/region.txt"
echo "${SIDE} account-id=${ID} region=${REGION} profile=${AWS_PROFILE}"
