# Phase 10 — Observability Results
Preparation only. Fill from actual successful outputs.
- Account/context/control plane:
- Node capacity and any resize plan/apply:
- Existing monitoring/collector inventory:
- Phase 10 Terraform plan/apply and outputs:
- Pod Identity agent healthy / association:
- Helm chart version and downloaded SHA-256:
- Prometheus/Grafana/Alertmanager ready:
- OpsFlow application log group receiving new tagged request:
- Prometheus up, cAdvisor CPU/memory, deployment metrics:
- Grafana OpsFlow dashboard contains real series:
- Rules loaded / evaluation health / notifications configured: NONE
- App replicas remained healthy:
- CloudWatch retention: 7 days
- Metrics storage: ephemeral, 6h/1GB; no PVC
- No application HTTP request/latency instrumentation claimed:
- Costs: no added NAT/ALB/PVC in this package; existing costs continue
- Provisioned time / teardown time / residual resources:
- Cleanup status: NOT RUN until verified


# Phase 10 — Observability Validation Results

**Project:** OpsFlow — AWS EKS Operations Platform  
**Date:** 11 October 2026  
**AWS Region:** ap-south-1  
**EKS Cluster:** opsflow-lab  
**Application Namespace:** opsflow  
**Monitoring Namespace:** monitoring  

## 1. Objective

Implement and validate centralized application logging and Kubernetes monitoring using AWS CloudWatch Logs, Fluent Bit, Prometheus and Grafana.

## 2. AWS CloudWatch Logs — PASS

- CloudWatch log group: `/opsflow/opsflow-lab/application`
- Log retention: 7 days
- Log collector: AWS for Fluent Bit 3.2.1
- Fluent Bit deployment: DaemonSet
- Fluent Bit Pods: 2/2 Ready
- Authentication: EKS Pod Identity with IAM role
- Verified application: frontend (Nginx)
- Log stream: `opsflow-kube.var.log.containers.frontend-...`

**Test performed:**

Sent an HTTP request through the AWS Application Load Balancer with a unique identifier.

- HTTP response: `200 OK`
- Test marker: `phase10-3b569221bfd64ba9831f648cd4bc262a`
- Event timestamp: `2026-10-11T14:55:36.147Z`

**Verification:**

The exact marker appeared in:

1. Frontend container logs using `kubectl logs`.
2. AWS CloudWatch Logs using `aws logs tail`.

The CloudWatch event included Kubernetes metadata such as Pod name, namespace, container name and worker node.

**Result: PASS — Frontend application logs successfully forwarded to CloudWatch.**

Backend log delivery was not separately verified.

## 3. Prometheus Monitoring — PASS

- Monitoring stack: kube-prometheus-stack 92.3.0
- Deployment method: Helm
- Prometheus replicas: 1
- Retention: 6 hours
- Persistent storage: Disabled for lab
- Prometheus scrape targets: 17/17 UP

Prometheus successfully collected Kubernetes monitoring metrics.

**Result: PASS**

## 4. Prometheus Alert Rules — PASS

Three custom alert rules were validated:

- `OpsFlowDeploymentUnavailable`
- `OpsFlowContainerRestarts`
- `OpsFlowMetricsMissing`

All three rules reported healthy evaluation status and were inactive during verification.

Alertmanager was intentionally disabled. External alert notifications were not configured.

**Result: PASS — Rule evaluation verified.**

## 5. Grafana Dashboard — PASS

- Dashboard: OpsFlow — Kubernetes Operations
- Grafana deployed using Helm
- Access: Local Kubernetes port-forward
- Authentication: Kubernetes Secret
- Dashboard provisioning: Kubernetes ConfigMap and Grafana sidecar

**Dashboard panels:**

1. Available replicas — Application availability.
2. CPU cores by Pod — Container CPU consumption.
3. Working memory by Pod — Container memory usage.
4. Restarts in 15 minutes — Recent container restarts.

The dashboard successfully displayed live Kubernetes metrics from Prometheus.

**Result: PASS**

## 6. Troubleshooting — Grafana Sidecar OOMKilled

**Problem:**

Grafana dashboard and datasource sidecars repeatedly restarted with `OOMKilled` and exit code 137.

**Root cause:**

Both sidecars had a memory limit of 64Mi, which was insufficient for their observed workload.

**Resolution:**

Updated `kubernetes/phase10/metrics-values.yaml`:

- Memory request: 32Mi → 64Mi
- Memory limit: 64Mi → 192Mi

Upgraded the existing Helm release to revision 2.

**Verification:**

- Grafana Pod: 3/3 Running
- Restarts after upgrade: 0
- Dashboard successfully displayed metrics

**Result: RESOLVED**

## 7. Security and Cost Considerations

- IAM permissions scoped for CloudWatch log delivery.
- EKS Pod Identity used instead of hardcoded AWS credentials.
- Grafana administrator credentials stored in a Kubernetes Secret.
- Monitoring services exposed internally using ClusterIP.
- Grafana and Prometheus accessed using local port-forwarding.
- CloudWatch log retention configured to 7 days.
- Prometheus retention configured to 6 hours.
- No additional EC2 worker nodes provisioned for monitoring.
- Monitoring uses ephemeral storage for this lab.

Existing EKS, EC2, networking, load balancing, RDS and CloudWatch usage may incur AWS charges.

## 8. Final Acceptance Summary

| Component | Result |
|---|---|
| CloudWatch frontend log delivery | PASS |
| Fluent Bit DaemonSet | PASS |
| Prometheus metrics collection | PASS |
| Prometheus alert rule evaluation | PASS |
| Grafana dashboard provisioning | PASS |
| Grafana sidecar memory issue | RESOLVED |
| Backend CloudWatch logging | NOT SEPARATELY VERIFIED |
| External alert notifications | NOT CONFIGURED |

**Overall result:** Phase 10 core observability functionality validated for the lab environment.