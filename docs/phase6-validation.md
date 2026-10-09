# Package validation

Prepared 2026-10-09.

Passed offline:
- PowerShell 7.5.3 AST parsing for all seven scripts.
- Valid release accepted; mutable image tag, broad/IPv6 CIDR and empty region rejected.
- Renderer exercised with the actual supplied Phase 5 templates and synthetic environment metadata.
- kubectl 1.35.0 Kustomize output parsed as YAML; both Deployments use digest-pinned images and include the configuration checksum in their Pod templates.
- Node diagnostic exercised with a mock Pool: TLS success exits 0, missing TLS exits 1, supplied password never printed.

Not executed: Windows PowerShell 5.1 runtime, actual application tests/builds, Docker push/ECR scans, AWS account preflight, server dry run, live deployment, browser CRUD, RDS connectivity or live rollback. These require the actual repository and authorized environment. Offline checks do not establish application acceptance.

Follow the deployment guide and record real evidence in phase6-results-template.md.
