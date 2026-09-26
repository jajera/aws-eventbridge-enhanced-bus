#!/usr/bin/env bash
# Shared helpers for aws-eventbridge-enhanced-bus scripts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${OUT_DIR:-$ROOT/out}"
REGION="${AWS_REGION:-ap-southeast-2}"
PROJECT_TAG="${PROJECT_TAG:-eb-enhanced-bus}"
BUS_NAME="${BUS_NAME:-lab-events}"
ALLOW_ENV="EB_ENHANCED_ALLOW_AWS"
# Set by require_cli: eventsv2 (CLI >= 2.37.3) or eventbridgev2 (2.37.2 only).
EB_CLI_SVC="${EB_CLI_SVC:-}"

require_allow() {
  if [[ "${!ALLOW_ENV:-}" != "1" ]]; then
    echo "Refusing to mutate AWS. Export ${ALLOW_ENV}=1 to run this script." >&2
    exit 1
  fi
}

resolve_eb_cli() {
  if aws eventsv2 help >/dev/null 2>&1; then
    EB_CLI_SVC=eventsv2
  elif aws eventbridgev2 help >/dev/null 2>&1; then
    EB_CLI_SVC=eventbridgev2
  else
    echo "Enhanced EventBridge CLI missing. Need AWS CLI >= 2.37.3 (aws eventsv2)." >&2
    echo "  (2.37.2 briefly used aws eventbridgev2; 2.37.3 renamed it.)" >&2
    aws --version >&2 || true
    exit 1
  fi
}

require_cli() {
  if ! command -v aws >/dev/null 2>&1; then
    echo "aws CLI not found" >&2
    exit 1
  fi
  resolve_eb_cli
}

require_profile() {
  local profile="${AWS_PROFILE:-}"
  if [[ -z "$profile" ]]; then
    echo "Set AWS_PROFILE (lab or dev)." >&2
    exit 1
  fi
}

aws_cli() {
  aws --region "$REGION" --profile "${AWS_PROFILE}" "$@"
}

# Enhanced bus surface: aws eventsv2 ... (or legacy eventbridgev2).
eb_cli() {
  if [[ -z "${EB_CLI_SVC}" ]]; then
    resolve_eb_cli
  fi
  aws_cli "${EB_CLI_SVC}" "$@"
}

account_id() {
  aws_cli sts get-caller-identity --query Account --output text
}

ensure_dir() {
  mkdir -p "$1"
}

tag_args() {
  # Usage: tag_args Key=Project,Value=...
  echo "Key=Project,Value=${PROJECT_TAG}"
}

wait_bus_active() {
  local arn="$1"
  local i
  for i in $(seq 1 60); do
    local state
    state="$(eb_cli describe-event-bus --event-bus-arn "$arn" --query State --output text 2>/dev/null || echo CREATING)"
    if [[ "$state" == "ACTIVE" ]]; then
      return 0
    fi
    sleep 2
  done
  echo "Timed out waiting for bus ACTIVE: $arn" >&2
  return 1
}

echo_step() {
  echo ""
  echo "==> $*"
}

ensure_log_retention() {
  local log_group="$1"
  local days="${2:-7}"
  aws_cli logs create-log-group --log-group-name "${log_group}" >/dev/null 2>&1 || true
  aws_cli logs put-retention-policy --log-group-name "${log_group}" --retention-in-days "${days}" >/dev/null 2>&1 || true
}
