# Phase 6 release evidence

Record actual results; do not mark unexecuted checks as passed. Never paste credentials, Secret values, Terraform state, or database connection passwords.

| Check | Actual result / evidence |
|---|---|
| Date, AWS account, region, cluster/context | |
| Infrastructure preflight and drift review | |
| Git commit / release ID | |
| Backend and frontend ECR digests | |
| Scan completion, CRITICAL count, HIGH review | |
| Database TLS, app role, incidents schema | |
| Server dry run and rollout | |
| ALB health, database readiness, incident create/list | |
| Browser create/read/update/delete supported by actual app | |
| Incident retained after backend Pod replacement | |
| Release A → B → rollback A, database compatibility | |
| Remaining limitations / cleanup status | |

Release records, baselines and verification JSON are generated under `.phase6/`. Keep those privately; commit only a reviewed, sanitized summary.
