#!/usr/bin/env bash
# Tear down dev resources. Usage: AWS_PROFILE=dev EB_ENHANCED_ALLOW_AWS=1 ./scripts/teardown-dev.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_allow
require_cli
require_profile

EVAL_FN="${EVAL_FN:-health-eval}"
EVAL_ROLE="${EVAL_ROLE:-health-eval-role}"
DELIVERY_ROLE="${DELIVERY_ROLE:-eb-subscriber-delivery}"
TABLE_NAME="${TABLE_NAME:-health-alerts}"
SUB_NAME="${SUB_NAME:-health-fifo}"
DLQ_NAME="${DLQ_NAME:-health-alerts-dlq}"

ensure_dir "${OUT_DIR}/dev"

SUB_ARN=""
[[ -f "${OUT_DIR}/dev/subscriber-arn.txt" ]] && SUB_ARN="$(tr -d '[:space:]' <"${OUT_DIR}/dev/subscriber-arn.txt")"
if [[ -z "${SUB_ARN}" ]]; then
  SUB_ARN="$(eb_cli list-subscribers --query "Subscribers[?Name=='${SUB_NAME}'].SubscriberArn | [0]" --output text 2>/dev/null || true)"
  [[ "${SUB_ARN}" == "None" ]] && SUB_ARN=""
fi
if [[ -n "${SUB_ARN}" ]]; then
  echo_step "Deleting Subscriber ${SUB_ARN}"
  eb_cli delete-subscriber --subscriber-arn "${SUB_ARN}" || true
  for _ in $(seq 1 30); do
    if ! eb_cli describe-subscriber --subscriber-arn "${SUB_ARN}" &>/dev/null; then
      break
    fi
    sleep 2
  done
  rm -f "${OUT_DIR}/dev/subscriber-arn.txt"
fi

if aws_cli lambda get-function --function-name "${EVAL_FN}" &>/dev/null; then
  echo_step "Deleting Lambda ${EVAL_FN}"
  aws_cli lambda delete-function --function-name "${EVAL_FN}" >/dev/null || true
fi

for role in "${DELIVERY_ROLE}" "${EVAL_ROLE}"; do
  if aws_cli iam get-role --role-name "${role}" &>/dev/null; then
    echo_step "Deleting role ${role}"
    policies="$(aws_cli iam list-role-policies --role-name "${role}" --query PolicyNames --output text)"
    for p in ${policies}; do
      aws_cli iam delete-role-policy --role-name "${role}" --policy-name "${p}" || true
    done
    aws_cli iam delete-role --role-name "${role}" || true
  fi
done

DLQ_URL=""
[[ -f "${OUT_DIR}/dev/dlq-url.txt" ]] && DLQ_URL="$(tr -d '[:space:]' <"${OUT_DIR}/dev/dlq-url.txt")"
if [[ -z "${DLQ_URL}" ]]; then
  DLQ_URL="$(aws_cli sqs get-queue-url --queue-name "${DLQ_NAME}" --query QueueUrl --output text 2>/dev/null || true)"
  [[ "${DLQ_URL}" == "None" ]] && DLQ_URL=""
fi
if [[ -n "${DLQ_URL}" ]]; then
  echo_step "Deleting DLQ ${DLQ_URL}"
  aws_cli sqs delete-queue --queue-url "${DLQ_URL}" || true
fi
rm -f "${OUT_DIR}/dev/dlq-url.txt" "${OUT_DIR}/dev/dlq-arn.txt"

if aws_cli dynamodb describe-table --table-name "${TABLE_NAME}" &>/dev/null; then
  echo_step "Deleting table ${TABLE_NAME}"
  aws_cli dynamodb delete-table --table-name "${TABLE_NAME}" >/dev/null || true
fi

rm -f \
  "${OUT_DIR}/dev/eval-fn-arn.txt" \
  "${OUT_DIR}/dev/health-eval.zip" \
  "${OUT_DIR}/dev/table-arn.txt" \
  "${OUT_DIR}/dev/filter.json" \
  "${OUT_DIR}/dev/invoke.json" \
  "${OUT_DIR}/dev/failure.json"
echo "Dev teardown complete."
