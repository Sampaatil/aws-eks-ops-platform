# Phase 9 — AWS CI/CD Results

Date: 2026-10-11
Account: 952078551971
Region: ap-south-1
Repository: Sampaatil/aws-eks-ops-platform

## Infrastructure and authorization

- Terraform apply succeeded: 30 added, 0 changed, 0 destroyed.
- Separate state key: opsflow/lab/ci-cd.tfstate.
- GitHub connection opsflow-github: AVAILABLE.
- Connection ID: cd096bcc-dd7d-4f65-ad6c-e5d3039341e7.
- Namespace deployer Role/RoleBinding: applied successfully.
- Pipeline: opsflow-lab-application.
- Push triggers: disabled intentionally; execution is on demand.

## Verified releases

First successful execution: 06df19fd-d593-4659-a03a-ec312ee160b9
Source commit: 4803c7ad5f205fba6cc811c50ea5cc338e32ef50
Helm revision: 4
Public ALB acceptance: frontend loaded, healthy status displayed,
and GET /api/incidents returned one existing incident.

Final successful execution: 795f03ce-1f37-4ff6-8fec-e44f479f1a62
Source commit: e3a3cc178b5fe182f7493a0a4f0f5f20f95c1379
CI build: opsflow-lab-ci:703f8fae-b275-4c0a-9cbf-39e1d7a8022e
Release tag: re3a3cc178b5f-d2c5497fc4894396
Source, BuildAndScan, approval and Deploy: Succeeded
Helm revision: 5 deployed
Backend/frontend: 2 ready replicas each
Deployed digests match the final release artifact.

Backend:
952078551971.dkr.ecr.ap-south-1.amazonaws.com/opsflow-lab-backend@sha256:a3092a691a4f2c4886982ca4796b28cec730275b87982e33d5ed9a5a8d966571

Frontend:
952078551971.dkr.ecr.ap-south-1.amazonaws.com/opsflow-lab-frontend@sha256:f30455a36afa2b66d42afc13998d144a3fc11216de7266654a2ace09a2d363bd

## Coverage and limitations

- Backend declared test:ci passed.
- Frontend tests NOT RUN: no declared test:ci script.
- Both final basic ECR scans passed with empty finding counts.
- Frontend source-map-js updated from 1.2.1 to 1.2.2.
- Local frontend audit and final CI frontend install reported 0 vulnerabilities.
- Local frontend build passed.
- Basic ECR scans do not establish complete application security coverage.
- Deployment succeeded through the private EKS API and internal acceptance gate.
- Public browser acceptance was performed after revision 4; not repeated for revision 5.
- No new rollback drill was performed during Phase 9.
- Rollback does not restore database schema or external credentials.
- Deployer permissions include namespace Secrets required by Helm.
- No database migration, password rotation or automatic EKS/RDS Terraform apply ran.

## Failures and fixes

- Initial CI failed because the ECR scan record was not yet available.
  Added bounded retries for ScanNotFoundException.
- A later CI failed on an interrupted tool download.
  Added three download attempts while retaining SHA-256 verification.
- Final CI logs confirmed an interrupted download recovered on retry.

## Cost and cleanup status

- Phase 9 infrastructure remains provisioned; teardown NOT RUN.
- NAT: nat-0a3a424ff6cbe72ee.
- Deploy subnet: subnet-02afa545941e1487d.
- Artifact bucket: opsflow-lab-952078551971-ap-south-1-pipeline.
- NAT and Elastic IP charges continue while idle.
- Exact provisioning time, teardown time and billed cost have not been recorded.
- Preserve release/deployment evidence before emptying the artifact bucket.
- Retain images needed by current and rollback Helm revisions.
- Phase 9 teardown leaves existing EKS/RDS/application infrastructure running.
