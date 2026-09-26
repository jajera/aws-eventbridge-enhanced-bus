# Deploy lab

Creates the enhanced bus, the **IoT → bus adapter** Lambda (`eb-bridge`), wires
the existing `iot_talk_*` events/telemetry rules to it, and RAM-shares the bus
to **dev** — **AWS CLI only**. Before this: [Prerequisites](prerequisites.md)
and [Check profiles](profiles.md) (`out/dev/account-id.txt` must exist).

## What this creates

| Resource | Detail |
| --- | --- |
| Enhanced bus `lab-events` | 7-day retention; ARN captured — never invent it |
| Lambda `eb-bridge` | Required adapter: IoT rule → `eventsv2 PutEvents` + `EventGroupId` |
| IAM role `eb-bridge-role` | Logs + PutEvents on the bus |
| IoT rule action | Extra Lambda action on events + telemetry rules → `eb-bridge` |
| RAM share `eb-enhanced-bus-share` | Principal = **dev** account id |

Why a Lambda? IoT topic-rule actions cannot `PutEvents` onto an **enhanced**
bus (`event-busv2/...`) with `SystemMetadata.EventGroupId`. `eb-bridge` is that
hop. The existing `iot-talk-ingest` action stays; talk DynamoDB / dashboard are
unchanged.

!!! tip "Mutation guard"
    These calls create billable / account resources. Tear down when finished.

## Load context

<div class="run" markdown>

```bash
export AWS_PROFILE=lab AWS_REGION=ap-southeast-2
mkdir -p out/lab
LAB_ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
DEV_ACCOUNT="$(cat out/dev/account-id.txt)"
echo "$LAB_ACCOUNT" > out/lab/account-id.txt
echo "$AWS_REGION" > out/lab/region.txt
echo "LAB=$LAB_ACCOUNT DEV=$DEV_ACCOUNT"
```

```text {.no-copy}
LAB=111122223333 DEV=444455556666
```

</div>

## Enhanced bus

<div class="run" markdown>

```bash
BUS_ARN="$(aws eventsv2 create-event-bus \
  --name lab-events \
  --description "Enhanced bus for cross-account ordered health alerts" \
  --storage-configuration RetentionPeriodInDays=7 \
  --tags Key=Project,Value=eb-enhanced-bus \
  --query EventBusArn --output text)"
echo "$BUS_ARN" | tee out/lab/bus-arn.txt
```

```text {.no-copy}
arn:aws:events:ap-southeast-2:111122223333:event-busv2/lab-events/4af03huoxjozsje2bexey6iw8
```

</div>

<div class="run" markdown>

```bash
aws eventsv2 describe-event-bus --event-bus-arn "$BUS_ARN" \
  --query '{State:State,RetentionDays:StorageConfiguration.RetentionPeriodInDays}' \
  --output json
```

```text {.no-copy}
{
    "State": "ACTIVE",
    "RetentionDays": 7
}
```

</div>

<div class="expect" markdown="0"><span class="pill">State = ACTIVE</span><span class="pill">RetentionDays = 7</span></div>

If `State` is still `CREATING`, re-run the describe until `ACTIVE`.

## Bridge role + Lambda

<div class="run" markdown>

```bash
aws iam create-role \
  --role-name eb-bridge-role \
  --assume-role-policy-document '{
    "Version":"2012-10-17",
    "Statement":[{
      "Effect":"Allow",
      "Principal":{"Service":"lambda.amazonaws.com"},
      "Action":"sts:AssumeRole"
    }]
  }' \
  --tags Key=Project,Value=eb-enhanced-bus \
  --query Role.Arn --output text
```

```text {.no-copy}
arn:aws:iam::111122223333:role/eb-bridge-role
```

</div>

<div class="run" markdown>

```bash
aws iam put-role-policy \
  --role-name eb-bridge-role \
  --policy-name eb-bridge-inline \
  --policy-document "{
  \"Version\": \"2012-10-17\",
  \"Statement\": [
    {
      \"Effect\": \"Allow\",
      \"Action\": [\"logs:CreateLogGroup\", \"logs:CreateLogStream\", \"logs:PutLogEvents\"],
      \"Resource\": \"arn:aws:logs:${AWS_REGION}:${LAB_ACCOUNT}:*\"
    },
    {
      \"Effect\": \"Allow\",
      \"Action\": [\"eventbridge:PutEvents\", \"events:PutEvents\"],
      \"Resource\": \"${BUS_ARN}\"
    }
  ]
}"
```

```text {.no-copy}
(no output)
```

</div>

<div class="run" markdown>

```bash
BRIDGE_ROLE_ARN="$(aws iam get-role --role-name eb-bridge-role --query Role.Arn --output text)"
sleep 10
# handler.py + vendored eventbridgev2 botocore model (Lambda runtime lacks it)
(cd bridge && zip -q -r ../out/lab/eb-bridge.zip handler.py data)
```

```text {.no-copy}
(no output)
```

</div>

`eb-bridge` calls `boto3.client("eventbridgev2")`. The managed Lambda runtime's
botocore does not ship that model yet, so the zip includes `bridge/data/`
(same service model AWS CLI ≥ 2.37.3 uses). Do not zip `handler.py` alone.

<div class="run" markdown>

```bash
aws lambda create-function \
  --function-name eb-bridge \
  --runtime python3.14 \
  --role "$BRIDGE_ROLE_ARN" \
  --handler handler.handler \
  --timeout 10 \
  --memory-size 128 \
  --zip-file fileb://out/lab/eb-bridge.zip \
  --environment "Variables={EVENT_BUS_ARN=${BUS_ARN},SOURCE=iot.lab}" \
  --tags Project=eb-enhanced-bus \
  --query FunctionArn --output text | tee out/lab/bridge-fn-arn.txt
```

```text {.no-copy}
arn:aws:lambda:ap-southeast-2:111122223333:function:eb-bridge
```

</div>

`SOURCE=iot.lab` is stamped on every publish — same value the **dev** Subscriber
filter matches. If the function already exists, update code and env instead:

<div class="run" markdown>

```bash
aws lambda update-function-code \
  --function-name eb-bridge \
  --zip-file fileb://out/lab/eb-bridge.zip \
  --query FunctionArn --output text
aws lambda wait function-updated --function-name eb-bridge
aws lambda update-function-configuration \
  --function-name eb-bridge \
  --environment "Variables={EVENT_BUS_ARN=${BUS_ARN},SOURCE=iot.lab}" \
  --query FunctionArn --output text
```

```text {.no-copy}
arn:aws:lambda:ap-southeast-2:111122223333:function:eb-bridge
```

</div>

## Wire IoT rules → bridge

Live feed is mostly **telemetry** (`devices/+/telemetry`, `fleet/+/telemetry`).
Wire those rules (plus events) so each keeps `iot-talk-ingest` **and** adds
`eb-bridge`. Skip camera — the bridge rejects camera blobs.

<div class="run" markdown>

```bash
BRIDGE_ARN="$(cat out/lab/bridge-fn-arn.txt)"
INGEST_ARN="arn:aws:lambda:${AWS_REGION}:${LAB_ACCOUNT}:function:iot-talk-ingest"

declare -A RULE_SQL=(
  [iot_talk_events]="SELECT * FROM 'devices/+/events'"
  [iot_talk_telemetry]="SELECT * FROM 'devices/+/telemetry'"
  [iot_talk_fleet_events]="SELECT * FROM 'fleet/+/events'"
  [iot_talk_fleet_telemetry]="SELECT * FROM 'fleet/+/telemetry'"
)

for RULE_NAME in "${!RULE_SQL[@]}"; do
  RULE_ARN="arn:aws:iot:${AWS_REGION}:${LAB_ACCOUNT}:rule/${RULE_NAME}"
  SID="AllowIot_${RULE_NAME}"
  aws lambda add-permission \
    --function-name eb-bridge \
    --statement-id "$SID" \
    --action lambda:InvokeFunction \
    --principal iot.amazonaws.com \
    --source-arn "$RULE_ARN" \
    --source-account "$LAB_ACCOUNT" 2>/dev/null || true
  aws iot replace-topic-rule \
    --rule-name "$RULE_NAME" \
    --topic-rule-payload "{
      \"sql\": \"${RULE_SQL[$RULE_NAME]}\",
      \"actions\": [
        {\"lambda\": {\"functionArn\": \"$INGEST_ARN\"}},
        {\"lambda\": {\"functionArn\": \"$BRIDGE_ARN\"}}
      ],
      \"ruleDisabled\": false,
      \"awsIotSqlVersion\": \"2016-03-23\"
    }"
  echo -n "$RULE_NAME: "
  aws iot get-topic-rule --rule-name "$RULE_NAME" \
    --query 'rule.actions[].lambda.functionArn' --output text
done
```

```text {.no-copy}
iot_talk_events: …:function:iot-talk-ingest	…:function:eb-bridge
iot_talk_telemetry: …:function:iot-talk-ingest	…:function:eb-bridge
iot_talk_fleet_events: …:function:iot-talk-ingest	…:function:eb-bridge
iot_talk_fleet_telemetry: …:function:iot-talk-ingest	…:function:eb-bridge
```

</div>

<div class="expect" markdown="0"><span class="pill">four rules</span><span class="pill">ingest + eb-bridge each</span></div>

If `add-permission` says the statement already exists, continue — the rule
replace is what matters.

## RAM share to dev

<div class="run" markdown>

```bash
SHARE_ARN="$(aws ram create-resource-share \
  --name eb-enhanced-bus-share \
  --resource-arns "$BUS_ARN" \
  --principals "$DEV_ACCOUNT" \
  --no-allow-external-principals \
  --tags key=Project,value=eb-enhanced-bus \
  --query resourceShare.resourceShareArn --output text)"
echo "$SHARE_ARN" | tee out/lab/share-arn.txt
```

```text {.no-copy}
arn:aws:ram:ap-southeast-2:111122223333:resource-share/ffdea398-4ee7-4967-956a-f433e9ae8edf
```

</div>

## Outputs

| File | Content |
| --- | --- |
| `out/lab/bus-arn.txt` | Enhanced bus ARN |
| `out/lab/bridge-fn-arn.txt` | `eb-bridge` function ARN |
| `out/lab/share-arn.txt` | RAM share ARN |

Next: [Deploy dev](dev.md). [Verify](verify.md) can still smoke with CLI
`put-events` (same envelope the bridge stamps); live devices hit the bus via
`eb-bridge`.
