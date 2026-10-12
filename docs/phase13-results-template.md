# Phase 13 — Controlled application error report

Status: PENDING real deployment and investigation. This is a synthetic lab, not a real production outage.

- Reviewed source SHA / pipeline execution / CodeBuild ID: PENDING.
- Approved backend/frontend digests / Helm previous and deployed revision: PENDING.
- Healthy app, monitoring and scrape baseline: PENDING.
- PodMonitor selected and target UP / Grafana datasource: PENDING.
- Selected backend Pod / run UUID / UTC start-end: PENDING.
- Synthetic request IDs / five HTTP 500 responses: PENDING.
- Exact same-Pod local counter delta: PENDING.
- Same-Pod Prometheus before/after values and delta: PENDING.
- Grafana counter/rate observation and UTC window: PENDING.
- CloudWatch group/stream / five distinct matching request IDs: PENDING.
- Real API health/readiness, backend replicas, public read-only acceptance: PENDING.
- Lab disarmed / port-forwards closed / cleanup: PENDING.
- Impact: describe actual evidence; do not assume there was no customer impact.
- Cause: intentional synthetic handler activation; no database operation.
- Resolution: stop intentional trigger/disarm; not a repaired production defect.
- Detection: describe actual log/metric observations; no notification configured.
- Prevention/limits: loopback-only, default disarmed, max five, two-minute expiry, separate synthetic metrics; no outage recovery/SLO proof.
- CodeBuild and existing infrastructure budget/retention status: PENDING.
