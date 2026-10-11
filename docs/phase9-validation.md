# Offline validation and remaining limits

Prepared 2026-10-11 (India).

Passed: Python compilation; YAML parsing of both buildspecs and deployer RBAC; Terraform fmt -check (HCL syntax/format); mocked release guard checks for wrong identity/invalid SHA/mutable images; critical-scan rejection; tracked .env rejection; mocked successful CD; post-upgrade HTTP failure rollback to recorded prior revision; no redundant rollback after a failed atomic upgrade. Mocked checks do not execute Helm, Kubernetes, Docker or AWS.

Terraform init could not install the AWS provider in this environment; terraform validate consequently reported a missing provider. Provider-schema validation, live plan and apply are NOT passed. Run init/validate/plan in the authorized environment and resolve actual provider/account findings before provisioning.

Not executed: actual app npm tests/builds, Docker builds/ECR pushes/scans, CodeConnections authorization, CodePipeline/CodeBuild execution, VPC/NAT connectivity, namespace authorization, real Helm rollout/recovery or public ALB acceptance. Current app source/test contracts are prerequisites; no fabricated passing tests are included.

The package contains no application credentials or production data. It adds a billable NAT/EIP and uses a privileged CI builder; trusted branch review and manual deployment approval remain necessary. Deployer namespace Secret/workload permissions are a sensitive boundary.
