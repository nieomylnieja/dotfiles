---
name: grafana-dashboards
description: |
  Create or revise Grafana dashboard models and provisioning files when the
  user asks for Grafana panels, dashboards, or operational metric views. Do not
  use for database schema work, generic charts, or alerting resources that do
  not belong to a dashboard.
---

# Grafana dashboards

Build the smallest dashboard that answers the operator's questions.
Do not invent metrics, labels, data-source identifiers, or alert thresholds.

## Establish the contract

Before editing or generating a model:

1. Identify the target Grafana version.
2. Identify the input form: exported dashboard JSON, API envelope,
   provisioning configuration, Grafonnet, Terraform, or another project model.
3. Read the repository's existing dashboards, metric definitions, naming
   conventions, and deployment path.
4. List the operational questions, target audience, data sources, variables,
   refresh interval, and expected time range.
5. Confirm every metric and label from a queryable source or repository code.

Do not copy legacy `graph`, `yaxes`, or panel-alert models into a current
dashboard. Use the target version's supported panel and unified-alerting models.

## Design

Use a clear information order:

1. current health and high-cost failures;
2. rate, errors, and latency trends for services;
3. utilization, saturation, and errors for resources;
4. drill-down panels and diagnostic dimensions.

Apply RED or USE only when it fits the monitored system. Show units,
descriptions, legends, and no-data behavior. Use thresholds only when an
operational objective or verified convention defines them.

Keep variables few and bounded. Avoid high-cardinality defaults and queries
that multiply series without a clear diagnostic use. Match histogram buckets,
counter rates, numerator and denominator labels, and aggregation windows.

## Edit safely

- Preserve dashboard, panel, library-panel, and data-source UIDs.
- Preserve `refId`, `schemaVersion`, plugin versions, field configuration,
  transformations, links, variables, and unknown fields unless the task changes
  them.
- Preserve the repository's API envelope or provisioning wrapper.
- Make the smallest structural edit. Do not regenerate unrelated panel IDs or
  reorder the whole model.
- Keep secrets, credentials, and environment-specific URLs out of tracked JSON.
- Do not import a dashboard, call a Grafana API, apply Terraform, restart a
  service, or write provisioning paths unless the user explicitly requests that
  external mutation.

## Verify

1. Parse changed JSON, YAML, HCL, or source files with the repository tools.
2. Compare preserved identifiers and unknown fields with the input model.
3. Validate queries against the target data source when safe access exists.
4. Check representative no-data, partial-data, and high-cardinality cases.
5. Render or import into a compatible non-production Grafana only when the user
   authorizes that write.
6. Report the target Grafana version and any query or rendering check that did
   not run.

A valid JSON document does not prove that Grafana accepts the model or that its
queries return useful data.
