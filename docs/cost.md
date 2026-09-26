---
icon: lucide/circle-dollar-sign
---

# Cost

The expensive mistake is usually the **path**, not the payload.

Classic multi-bus bills by the **event** and again every time you hop to another
bus. The enhanced bus bills **ingress** when you publish and **egress** when a
Subscriber actually receives data. RAM share itself is free — you pay for
traffic and retention, not for the invitation.

Rates below are from
[EventBridge pricing](https://aws.amazon.com/eventbridge/pricing/)
(retrieved 26 September 2026). Check the live page before you budget.

## Two meters

Classic still thinks in millions of events (64 KB chunks). A custom publish is
about **$1 per million**. Same-account delivery is often free; send that event
to another account’s bus and you typically pay **another $1 per million** for
the hop.

Enhanced meters **gigabytes**, rounded up to 1 KB per event. The public example
uses roughly **$0.18/GB** ingress on the first tier (then **$0.12**), and
**$0.05/GB** egress per subscription that gets the event. Keep events for longer
than the included default and storage shows up (example **$0.08/GB**). Dedup and
JSONata are optional — leave them off and they cost nothing.

So the comparison is not “which table looks nicer.” It is whether your bill grows
with **how many times you hop** or with **how much data you publish and
deliver**.

## Who gets the invoice

On classic hops, the **sender** often eats cross-account delivery. On the
enhanced bus, publishers fund ingress and each consumer funds the egress for
their own Subscriber. The bus owner can see delivery volume per consumer account
(`EventsDelivered` / `EgressBytes` with `SubscriberAccount`) — useful when you
want chargeback without inventing hop accounting.

## A hop story (classic)

AWS’s own classic walkthrough: 10 million custom events into account A, half of
them forwarded to a bus in B, then to a service in B → **$10** to publish +
**$5** for the cross-bus hop = **$15**. The last hop inside B is free.

Now imagine three consumer accounts each needing that full 10M stream as a hop.
You still pay **$10** once to publish — and about **$30** more just to move the
same events across bus boundaries. Topology did the damage.

## Same volume, one bus (enhanced)

Keep the 10 million events. Say they average 2 KB → **20 GB** in. Three
Subscribers each take the lot → **60 GB** out. No evaluation features:

| | |
| --- | ---: |
| Ingress (20 GB × $0.18) | **$3.60** |
| Egress (60 GB × $0.05) | **$3.00** |
| Sketch total | **~$6.60** |

Against the ~**$40** hop sketch above, most of the gap is “we stopped paying per
hop,” not “events got cheaper by magic.” **Filters set egress:** only matched
events meter out. A wide or missing filter means every bus event can hit this
Subscriber’s bill; tighten the pattern and egress drops with it. Retries and
long retention add lines — keep them in mind, don’t ignore them.

Numbers move with size, selectivity, and region. Treat this as a shape check,
not a quote.

## When cost points which way

Stay on classic when you are mostly **one account**, you are not building a hop
chain, and per-event pricing is already boringly cheap.

Lean enhanced when **several accounts drink from the same stream**, when every
new consumer would mean another hop ticket, or when you want publishers and
subscribers on separate sides of the bill. Skip paid evaluation features until
you need them.

Cost will not save you from a bad blast-radius choice — that is still
[Patterns](patterns/#4-sharing-is-not-free). It will tell you if you are about
to pay for **plumbing** instead of **events**.

## This lab

A few verify puts, one FIFO Subscriber, 7-day retention, no dedup or JSONata.
Expect **cents**, then tear down ([Demo](demo/teardown/)).

Full source list: [References](references/).
