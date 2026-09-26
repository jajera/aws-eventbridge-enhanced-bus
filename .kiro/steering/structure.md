# Structure

```plaintext
docs/           Zensical pages (Overview → Patterns → Design → Demo → References)
bridge/         lab Lambda source (eb-bridge — IoT → enhanced bus adapter)
                + data/eventbridgev2/ (vendored botocore model for Lambda)
consumer/       dev Lambda source (health-eval)
scripts/        capture-accounts, teardown-*
out/            gitignored ARNs and account ids
```

Reading order: **Overview → Patterns → Design → Demo → References**.

Demo nested: prerequisites → profiles → lab → dev → verify → teardown → troubleshooting.

Resource names are fixed (`lab-events`, `eb-bridge`, `health-fifo`,
`health-alerts`, …). Do not invent alternate names without updating docs together.
