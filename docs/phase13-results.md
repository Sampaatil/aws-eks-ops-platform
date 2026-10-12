# Phase 13 — Controlled Application Error Investigation Report

**Project:** OpsFlow — AWS EKS Operations Platform  
**Environment:** AWS EKS (`opsflow-lab`)  
**AWS Region:** `ap-south-1`  
**Kubernetes Namespace:** `opsflow`  
**Investigation Date:** 12 October 2026  
**Status:** SUCCESS — Controlled incident executed, observability verified, application healthy. Final disarm and public ALB acceptance require confirmation.

> This was a controlled synthetic application-error investigation, not a real production outage.

## 1. Deployment and CI/CD Evidence

- **Application source commit:** `89b18a3`
- **Repository:** `https://github.com/Sampaatil/aws-eks-ops-platform`
- **Branch:** `main`
- **CI/CD pipeline:** `opsflow-lab-application`
- **Pipeline result:** Succeeded, as confirmed during Phase 13.
- **Pipeline execution ID:** Not captured in the available evidence.
- **CodeBuild execution ID:** Not captured.
- **Helm release:** `opsflow`
- **Helm namespace:** `opsflow`
- **Previous and deployed Helm revisions:** Not recorded.
- **Backend image repository:** `952078551971.dkr.ecr.ap-south-1.amazonaws.com/opsflow-lab-backend`
- **Deployed backend image digest observed in CloudWatch:**

  `sha256:320faf8be43d59b09304aa30f9f98fb0927cb04919cfd75984c3a1ca254788ef`

- **Frontend image digest:** Not recorded.
- **Investigation report initial commit:** `565053d`

The updated application was deployed through the existing CI/CD pipeline. The synthetic incident was executed against a running backend Pod.

## 2. Application and Monitoring Baseline

Before the investigation, application health and readiness checks returned:

| Component | Result |
|---|---|
| Backend service | `opsflow-api` |
| Application version | `1.1.1` |
| `/health` | `healthy` |
| `/ready` | `ready` |
| Database | `connected` |
| Incident lab initial status | `armed=false` |
| Backend Pod | Running and Ready |

Monitoring configuration:

- **Prometheus:** Existing Phase 10 monitoring deployment
- **Grafana:** Existing Phase 10 monitoring deployment
- **PodMonitor:** `opsflow-incident-lab`
- **Monitoring namespace:** `monitoring`
- **Dashboard:** `OpsFlow — Controlled Application Error Lab`
- **Grafana datasource:** `Prometheus`
- **Prometheus job:** `monitoring/opsflow-incident-lab`

Prometheus returned the selected Pod's metric series, and Grafana displayed the corresponding application metrics.

The exact pre-incident Prometheus counter value and an explicit target-UP screenshot were not preserved in the supplied evidence.

## 3. Controlled Incident Execution

**Selected backend Pod:** `backend-667779b7d6-28qgr`

**Run ID:** `52806f73-23a2-4ee1-925d-1115b32cc815`

**Execution date:** 12 October 2026

**Synthetic event timestamps:** 06:10:46.022–06:10:46.343 UTC

**Method:** Controlled synthetic HTTP errors through the Pod's loopback-only incident listener on port `3001`.

**Execution command:**

`.\scripts\phase13\Invoke-IncidentLab.ps1 -RepoRoot $OpsRepoRoot -Pod $OpsPod`

### Generated HTTP 500 Responses

| # | Request ID | HTTP status |
|---|---|---|
| 1 | `2fdf3ce3-6bc5-4883-b3dc-f8c9196b23f4` | 500 |
| 2 | `4a28f08d-66dd-40bf-914a-093868df1078` | 500 |
| 3 | `9531531b-320f-405f-8060-fe55df89dcc7` | 500 |
| 4 | `a8a50620-0206-4bdc-9eff-e3fe276c974b` | 500 |
| 5 | `5ef56450-ae18-4125-87dd-59e81823aabf` | 500 |

**Total generated:** 5 synthetic HTTP 500 responses.

The execution script reported:

- All five synthetic responses validated.
- Request and run identifiers matched.
- Local application counter checks passed.
- Local evidence saved to `.phase13/run-52806f73-23a2-4ee1-925d-1115b32cc815.json`.

**Local counter delta:** 5, as validated by the execution script.

The exercise was bounded to five requests and did not intentionally modify the database, terminate Pods, or change application readiness.

## 4. Prometheus Metrics Verification

**Metric:**

`opsflow_incident_lab_errors_total`

**Selected metric labels:**

- `namespace="opsflow"`
- `job="monitoring/opsflow-incident-lab"`
- `pod="backend-667779b7d6-28qgr"`

**Observed Prometheus counter after the incident:** `5`

Prometheus returned a single matching metric series for the selected backend Pod.

**Before counter:** Not recorded in the supplied output.

**After counter:** 5

**Exact Prometheus before/after delta:** Not independently established from two saved snapshots. The local execution script independently validated a delta of five.

The metrics confirm that Prometheus scraped the synthetic incident counter from the backend.

## 5. Grafana Dashboard Verification

**Dashboard:** OpsFlow — Controlled Application Error Lab

**Datasource:** Prometheus

**Observation window:** Approximately 11:35–11:50 IST on 12 October 2026, based on the displayed dashboard.

### Observed Results

| Grafana panel | Observation |
|---|---|
| Synthetic errors since Pod start | Selected Pod counter increased from 0 to 5 in the displayed graph |
| Synthetic errors per second — 5m | Temporary nonzero synthetic error rate |
| Real API 5xx per second | Zero in the displayed window |
| Backend available replicas | Stable at 2 |
| Backend CPU | Minor fluctuations |
| Backend working memory | Minor fluctuations |

The synthetic error-rate graph subsequently returned to zero when the event moved outside the five-minute rate window.

The cumulative counter remained at five while the same backend process was running.

This demonstrates that the synthetic errors were visible through the observability stack without a corresponding observed increase in production API 5xx responses.

## 6. CloudWatch Logs Verification

**AWS Region:** `ap-south-1`

**CloudWatch log group:** `/opsflow/opsflow-lab/application`

**Event name:** `opsflow_incident_lab_error`

**Log level:** `ERROR`

**Synthetic flag:** `true`

**HTTP status:** `500`

**Matching run ID:** `52806f73-23a2-4ee1-925d-1115b32cc815`

**Matching CloudWatch events:** 5

All five events contained distinct request IDs matching the HTTP response evidence.

CloudWatch records also included Kubernetes metadata identifying the backend Pod, namespace, container and deployed image.

**Log delivery:** Verified in AWS CloudWatch, not only through local container logs.

**Log stream name:** Not recorded in the supplied output.

The log records indicated that the synthetic error handler did not perform a database operation.

## 7. Post-Incident Application Verification

After the controlled incident, the following results were observed:

| Component | Verified result |
|---|---|
| Backend `/health` | `healthy` |
| Backend `/ready` | `ready` |
| Database connectivity | `connected` |
| Backend deployment | `2/2` available |
| Frontend deployment | `2/2` available |
| Backend Pods | `2/2` Running |
| Frontend Pods | `2/2` Running |
| Container restarts | 0 across all four listed Pods |

**Application version:** `1.1.1`

**Post-incident health-check timestamp:** 2026-10-12T06:26:57Z

The Kubernetes deployment and Pod checks showed healthy workloads after the investigation.

**Public ALB frontend and read-only API acceptance:** Not independently confirmed in the supplied output.

**Final incident lab `armed=false` check:** Not independently confirmed after execution. The script was designed to disarm in its cleanup procedure, but the final status response was not supplied.

**Port-forward closure:** Not confirmed.

## 8. Impact Assessment

The incident was intentionally generated through a restricted synthetic listener rather than the application's normal production API endpoint.

Observed evidence:

- Five synthetic HTTP 500 responses were generated.
- Production API 5xx rate remained zero in the observed Grafana window.
- Backend availability remained at two replicas.
- Database readiness checks succeeded.
- No container restarts were observed.

No customer-facing outage was observed in the available monitoring evidence. However, this experiment does not establish that all possible customer-facing paths were unaffected.

## 9. Root Cause

**Cause:** Intentional activation of the Phase 13 synthetic HTTP error handler.

This was a controlled fault-injection exercise designed to validate logging, metrics and operational investigation.

It was not caused by a production application defect, database failure, Kubernetes scheduling issue or infrastructure outage.

## 10. Resolution

The bounded incident execution completed after five synthetic HTTP 500 responses.

The execution script reported successful local verification. No database restoration, Pod replacement, application rollback or infrastructure recovery was required.

Subsequent health and readiness checks confirmed normal backend and database operation.

This represents completion of a controlled experiment, not recovery from a genuine production outage.

## 11. Detection and Observability

The investigation demonstrated three observability capabilities:

**Application logging:** Structured error records included timestamps, HTTP status, run ID, request ID, synthetic marker and Pod identity.

**CloudWatch:** All five synthetic error records were successfully ingested and correlated by run/request identifiers.

**Prometheus and Grafana:** The application exposed synthetic error metrics, which were collected by Prometheus and visualized in Grafana alongside application availability and resource metrics.

No automated alert notification, CloudWatch-to-Grafana integration, distributed tracing or comprehensive APM capability was added during this phase.

## 12. Prevention, Safety Controls and Limitations

The controlled incident implementation uses:

- A loopback-only synthetic listener.
- Default disarmed state.
- A maximum of five synthetic error requests per activation.
- A two-minute activation expiry.
- Separate metrics for synthetic and production traffic.
- Structured request and run identifiers for correlation.
- No intentional database operations during error generation.

The investigation does not demonstrate production outage recovery, automatic remediation, autoscaling behavior, complete distributed tracing, or SLO compliance.

## 13. Cost and Cleanup

No additional billable AWS infrastructure was provisioned specifically for the incident execution.

The experiment reused the existing:

- Amazon EKS cluster and worker nodes.
- Application deployments.
- CloudWatch logging pipeline.
- Prometheus and Grafana monitoring stack.
- CI/CD infrastructure.

The five synthetic requests generated limited additional log ingestion and metric activity.

Existing EKS, database, networking, load balancing, monitoring, artifact storage and CodeBuild costs continue to apply while those resources remain provisioned.

**Monitoring retention:** Existing Phase 10 lab retention and ephemeral-storage limitations apply.

**Cleanup status:** No new infrastructure teardown required. Port-forward closure and final disarm confirmation were not documented in the supplied evidence.

## 14. Final Outcome

**Technical investigation: SUCCESS**

Successfully demonstrated:

1. Deployment of instrumented application code through the existing CI/CD pipeline.
2. Controlled generation of exactly five synthetic HTTP 500 responses.
3. Request-level correlation using unique identifiers.
4. Collection of synthetic error metrics through Prometheus.
5. Visualization of error activity and workload availability in Grafana.
6. Ingestion and correlation of five structured application error logs in CloudWatch.
7. Healthy backend, database and Kubernetes workloads after the experiment.

**Remaining documentation confirmations:** Final lab disarm status, port-forward closure, public ALB acceptance, exact Prometheus baseline/delta and missing CI/CD identifiers.

**Overall conclusion:** Phase 13 successfully validated the core application-error observability and investigation workflow on the AWS EKS OpsFlow platform, while preserving healthy application workloads throughout the observed exercise.