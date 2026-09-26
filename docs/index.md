---
icon: lucide/workflow
---

<div class="patina-hero" markdown>

<p class="patina-kicker">EventBridge · September 2026</p>

# Enhanced EventBridge custom event bus

<p class="patina-lede">
  Amazon EventBridge now offers an <strong>enhanced custom event bus</strong>:
  share one bus across accounts with AWS RAM, consume with a
  <strong>Subscriber</strong> resource, and optionally deliver events in order
  per <code>EventGroupId</code> — without bus-to-bus routing.
</p>

<div class="patina-actions">
<a class="patina-btn patina-btn--primary" href="patterns/">Compare the patterns</a>
<a class="patina-btn patina-btn--ghost" href="demo/">Run the CLI demo</a>
</div>

</div>

## The problem

Teams often start with one classic custom bus in one account. As more accounts
adopt events, the usual workaround is **many buses** stitched with cross-account
rules or bus-to-bus targets. Routing gets hard to see, hop charges stack, and
ordered processing usually means bolting on another queue in front of the consumer.

The enhanced custom event bus is built for that scale-up.

!!! info "AWS announcement"
    [Introducing enhanced custom event buses in Amazon EventBridge for enterprise-scale event-driven applications](https://aws.amazon.com/blogs/aws/introducing-enhanced-custom-event-buses-in-amazon-eventbridge-for-enterprise-scale-event-driven-applications/) (AWS News Blog, 24 Sep 2026). Also: [What's New](https://aws.amazon.com/about-aws/whats-new/2026/09/eventbridge-relaunches-custom-event-buses/).

## What the feature adds

| Capability | What it means |
| --- | --- |
| **Shared bus (RAM)** | One enhanced bus (`event-busv2`) visible to other accounts or OUs — publishers and Subscribers attach to the **same** ARN (no bus-to-bus hop) |
| **Subscriber resource** | Filter, target, retry, and DLQ in one unit — owned by the consumer account (instead of classic rule + target sprawl) |
| **Consumer DATA filter** | What you receive (and pay **egress** for) is selected on the Subscriber, not by bus-owner rules ([Cost](cost/)) |
| **Ordered delivery (optional)** | Publishers set `EventGroupId`; `--type FIFO` delivers that group in sequence; `UNORDERED` can share the same bus ([FIFO vs UNORDERED](patterns/#unordered-vs-fifo)) |
| **Built-in retention** | Hours to a year for replay / late joiners (this lab uses 7 days) |
| **Ingress / egress pricing** | Publishers pay ingest; subscribers pay delivery — replaces stacked hop economics ([Cost](cost/)) |

![Classic multi-bus routing versus one enhanced EventBridge bus shared with AWS RAM](assets/diagrams/classic-vs-enhanced.svg)

<p class="diagram-caption">Same org, different topology. Left: hop between buses. Right: one enhanced bus, RAM share, Subscribers in each account. Detail: <a href="patterns/">Patterns</a>.</p>

## Classic vs enhanced (summary)

| | Classic (`aws events`) | Enhanced (`aws eventsv2`) |
| --- | --- | --- |
| Cross-account | Bus policy / bus-to-bus | **RAM share** of one bus |
| Consumer unit | Rules + targets | **Subscriber** |
| Event selection | Often bus-owner rules | **Consumer DATA filter** on the Subscriber |
| Ordering | DIY (often SQS FIFO) | FIFO Subscriber + `EventGroupId` |
| Bus ARN | `event-bus/<name>` | `event-busv2/<name>/<generated-id>` |

Existing classic buses keep working as **Custom event bus – classic**. This site is about adopting the enhanced bus.

## What this does not do

- **Replace classic buses.** They remain available; this lab creates only the enhanced bus.
- **Replace your IoT ingest path.** The demo adds `eb-bridge` beside `iot-talk-ingest`; talk tables stay. Any other publisher that can `put-events` with the same envelope also works.
- **Touch the management account.** RAM share is owner account → consumer account (here lab → dev).
- **Cover every enhanced capability.** Dedup and JSONata reshape appear in Patterns; the demo only needs share + FIFO Subscriber.

The [Demo](demo/) proves those capabilities with a concrete Subscriber target.
IoT / `eb-bridge` / DynamoDB are feed and proof only — not the feature.

## Next

1. [Patterns](patterns/) — when classic multi-bus still fits vs enhanced share
2. [Design](design/) — resources and the consume path
3. [Cost](cost/) — ingress / egress vs hop stacking
4. [Demo](demo/) — `lab` / `dev` CLI walkthrough
5. [References](references/) — AWS posts and pricing
