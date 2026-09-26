# AWS source lock

Cite AWS docs or the launch blog before shipping behavioural claims about
`eventbridgev2`, Subscribers, RAM sharing, or pricing.

## Primary sources

| Topic | Source |
| --- | --- |
| Launch | [Introducing enhanced custom event buses](https://aws.amazon.com/blogs/aws/introducing-enhanced-custom-event-buses-in-amazon-eventbridge-for-enterprise-scale-event-driven-applications/) (24 Sep 2026) |
| What's new | [EventBridge relaunches custom event buses](https://aws.amazon.com/about-aws/whats-new/2026/09/eventbridge-relaunches-custom-event-buses/) |
| CLI (v2) | `aws eventsv2 help` (CLI ≥ 2.37.3; was `eventbridgev2` in 2.37.2) |
| Pricing | [EventBridge pricing](https://aws.amazon.com/eventbridge/pricing/) — note date of retrieval |

## Verified lab facts (evidence pass may tighten)

- Enhanced bus available in `ap-southeast-2` (Sydney) per launch post region list.
- Bus ARN shape: `arn:aws:events:<region>:<acct>:event-busv2/<name>/<generated-id>`.
- Ordered Subscriber type: `FIFO`; unordered: `UNORDERED`.
- Publish ordering key: `SystemMetadata.EventGroupId` on `put-events`.
- Subscriber `StartingPosition` default: `LATEST`.

Mark new behavioural claims **unverified** until run in-account.
