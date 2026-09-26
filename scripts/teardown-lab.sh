#!/usr/bin/env bash
# Tear down lab resources (after teardown-dev). Usage: AWS_PROFILE=lab EB_ENHANCED_ALLOW_AWS=1 ./scripts/teardown-lab.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_allow
require_cli
require_profile

BRIDGE_FN="${BRIDGE_FN:-eb-bridge}"
BRIDGE_ROLE="${BRIDGE_ROLE:-eb-bridge-role}"
IOT_INGEST_FN="${IOT_INGEST_FN:-iot-talk-ingest}"
SHARE_NAME="${SHARE_NAME:-eb-enhanced-bus-share}"

ensure_dir "${OUT_DIR}/lab"

ACCOUNT="$(aws_cli sts get-caller-identity --query Account --output text)"
INGEST_ARN="arn:aws:lambda:${REGION}:${ACCOUNT}:function:${IOT_INGEST_FN}"

# Restore IoT rules to ingest-only before deleting eb-bridge (camera never wired).
# Stable order for logs / docs.
RULE_ORDER=(
  iot_talk_events
  iot_talk_telemetry
  iot_talk_fleet_events
  iot_talk_fleet_telemetry
)
declare -A RULE_SQL=(
  [iot_talk_events]="SELECT * FROM 'devices/+/events'"
  [iot_talk_telemetry]="SELECT * FROM 'devices/+/telemetry'"
  [iot_talk_fleet_events]="SELECT * FROM 'fleet/+/events'"
  [iot_talk_fleet_telemetry]="SELECT * FROM 'fleet/+/telemetry'"
)

for RULE_NAME in "${RULE_ORDER[@]}"; do
  if aws_cli iot get-topic-rule --rule-name "${RULE_NAME}" &>/dev/null; then
    echo_step "Restoring IoT rule ${RULE_NAME} to ingest-only"
    aws_cli iot replace-topic-rule \
      --rule-name "${RULE_NAME}" \
      --topic-rule-payload "{
        \"sql\": \"${RULE_SQL[${RULE_NAME}]}\",
        \"actions\": [{\"lambda\": {\"functionArn\": \"${INGEST_ARN}\"}}],
        \"ruleDisabled\": false,
        \"awsIotSqlVersion\": \"2016-03-23\"
      }" || true
  fi
done

SHARE_ARN=""
[[ -f "${OUT_DIR}/lab/share-arn.txt" ]] && SHARE_ARN="$(tr -d '[:space:]' <"${OUT_DIR}/lab/share-arn.txt")"
if [[ -z "${SHARE_ARN}" ]]; then
  SHARE_ARN="$(aws_cli ram get-resource-shares --resource-owner SELF \
    --name "${SHARE_NAME}" --resource-share-status ACTIVE \
    --query 'resourceShares[0].resourceShareArn' --output text 2>/dev/null || true)"
  [[ "${SHARE_ARN}" == "None" ]] && SHARE_ARN=""
fi
if [[ -n "${SHARE_ARN}" ]]; then
  echo_step "Deleting RAM share ${SHARE_ARN}"
  aws_cli ram delete-resource-share --resource-share-arn "${SHARE_ARN}" >/dev/null || true
  rm -f "${OUT_DIR}/lab/share-arn.txt"
fi

if aws_cli lambda get-function --function-name "${BRIDGE_FN}" &>/dev/null; then
  echo_step "Deleting Lambda ${BRIDGE_FN}"
  aws_cli lambda delete-function --function-name "${BRIDGE_FN}" >/dev/null || true
fi

if aws_cli iam get-role --role-name "${BRIDGE_ROLE}" &>/dev/null; then
  echo_step "Deleting role ${BRIDGE_ROLE}"
  policies="$(aws_cli iam list-role-policies --role-name "${BRIDGE_ROLE}" --query PolicyNames --output text)"
  for p in ${policies}; do
    aws_cli iam delete-role-policy --role-name "${BRIDGE_ROLE}" --policy-name "${p}" || true
  done
  aws_cli iam delete-role --role-name "${BRIDGE_ROLE}" || true
fi

BUS_ARN=""
[[ -f "${OUT_DIR}/lab/bus-arn.txt" ]] && BUS_ARN="$(tr -d '[:space:]' <"${OUT_DIR}/lab/bus-arn.txt")"
if [[ -z "${BUS_ARN}" ]]; then
  BUS_ARN="$(eb_cli list-event-buses --query "EventBuses[?Name=='${BUS_NAME}'].EventBusArn | [0]" --output text 2>/dev/null || true)"
  [[ "${BUS_ARN}" == "None" ]] && BUS_ARN=""
fi
if [[ -n "${BUS_ARN}" ]]; then
  echo_step "Deleting event bus ${BUS_ARN}"
  eb_cli delete-event-bus --event-bus-arn "${BUS_ARN}" || true
  rm -f "${OUT_DIR}/lab/bus-arn.txt"
fi

rm -f "${OUT_DIR}/lab/bridge-fn-arn.txt" "${OUT_DIR}/lab/eb-bridge.zip" "${OUT_DIR}/lab/bridge-smoke.json"
echo "Lab teardown complete."
