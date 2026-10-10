# Phase 7 actual results

Record verified outputs only. Leave unexecuted steps pending. Do not include credentials or private baseline JSON.

| Step | Status and actual evidence |
|---|---|
| Account/context/Helm version | |
| Live values export and chart lint | |
| Server validation and reviewed diff | |
| Seven resources adopted | |
| Helm revision 1 deployed | |
| Same ALB/images; read-only API/frontend pass | |
| Upgrade revision and changed request | |
| Rollback target/new revision; original request restored | |
| Chart packaged and Git commit | |
| External DB/Secret/CA/controller boundaries | |
| Remaining limitations and environment cleanup decision | |


Field	Value
Migration date	10 October 2026
EKS cluster	opsflow-lab
Namespace	opsflow
Helm release	opsflow
Chart	opsflow-0.1.0
Helm revision	1
Helm status	deployed
Adopted resources	7
Images	Existing Phase 6 ECR digests
Rollout and readiness	Record actual output
Rollback	No earlier Helm revision exists

## Helm Deployment (Phase 7)

OpsFlow application resources are managed using Helm 3.

- Chart: `helm/opsflow`
- Release: `opsflow`
- Namespace: `opsflow`
- Managed resources: 2 Deployments, 2 Services, 2 ConfigMaps and 1 Ingress
- Infrastructure: AWS resources remain managed by Terraform
- External dependencies: RDS, Kubernetes database Secret and RDS CA ConfigMap

### Release Management

- Initial installation: revision 1
- Configuration upgrade: revision 2
- Successful rollback: revision 3 (restored revision 1)

See [Phase 7 Helm Guide](docs/phase7-helm.md) and
[Phase 7 Results](docs/phase7-results.md)