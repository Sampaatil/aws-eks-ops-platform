# Phase 12 — DevSecOps for OpsFlow

## Scope and current status

Extend the existing Phase 9 pipeline: trusted GitHub commit → secret/dependency checks → lint/declared tests → Terraform validation/static IaC checks → Docker builds → Trivy → ECR digests/basic scans → manual approval → existing private Helm deployment.

This package is prepared code, not a successful AWS execution. No live AWS provisioning, pipeline run, database operation or Helm upgrade was performed while preparing it. Phase 11 remains deferred. No HPA, scanner Pod, new node or AWS resource is added by this package. The two existing application replicas and Helm behavior are retained.

Preparation found real blockers: the existing IaC baseline produced 114 findings, including 25 HIGH/CRITICAL blockers. See `docs/phase12-validation.md` and `docs/preparation-iac-findings.json`. Do not start a paid pipeline execution expecting this baseline to pass. Resolve/review the blockers first. Static checks do not establish the state of live AWS resources.

## What the gates mean

| Gate | Actual implementation | Limits |
|---|---|---|
| Secrets | Trivy filesystem and built-image secret checks | Pattern-based; not proof that no secret exists |
| Dependencies | Both npm lockfiles, including development dependencies | Database coverage and applicability need review |
| Lint | Existing frontend Oxlint; same locked binary checks backend source/tests | Code quality checks, not behavior tests |
| Tests | Run declared `test:ci`; explicitly disclose missing scripts | Existing backend health test does not test PostgreSQL; frontend has no declared CI suite |
| IaC | `fmt -check`, backend-disabled `init`, `validate` for all five Terraform roots; Trivy scans Terraform, Kubernetes, Dockerfiles and rendered app chart | No Terraform plan/apply/state read; variable-dependent findings may require interpretation; external vendored charts are not scanned |
| Images | Serial builds and Trivy OS/application vulnerability + secret scanning of both local images | No runtime penetration test or exploitability proof |
| ECR | Unique tags, actual digests, existing COMPLETE basic scans and CRITICAL gate | Basic ECR scans are not comprehensive npm checks |
| Deploy | Passing evidence/digests verified, manual approval, existing atomic Helm upgrade/internal checks | Existing namespace deployer can read/write Secrets; retain trusted code review |

Both images must pass Trivy before either is pushed. A later ECR/API failure can still leave already-pushed images. Scan/build failures stop deployment. Artifact upload may succeed on a failed build because sanitized failure reports exist; it does not turn a failed Build action into an approved release. A passing `release.json` is created only after all configured gates pass.

HIGH and CRITICAL findings block. Secrets of every severity and UNKNOWN-severity findings block. CRITICAL/secret findings cannot use exceptions. MEDIUM/LOW findings remain visible for review. Missing frontend tests are recorded as NOT RUN; the tests stage only means the actual declared suite passed. At least one declared test suite must run.

Only a specific HIGH finding may receive a reviewed exception in `security/exceptions.json`. Each entry needs its exact fingerprint, owner, reason, review reference and UTC expiry no more than 30 days away. No exceptions are supplied. A finding reappears when its package/version/resource identity changes. Image fingerprints normalize the unique release tag; image evidence remains bound to the actual digest. Do not add wildcard ignores, inline `trivy:ignore`/`tfsec:ignore`, `--ignore-unfixed`, skipped databases or passing dummy tests.

Example entry structure, using the actual reviewed fingerprint rather than this placeholder:

```json
[
  {
    "fingerprint": "ACTUAL_64_CHARACTER_FINGERPRINT",
    "owner": "authorized reviewer",
    "reason": "specific applicability assessment and compensating controls",
    "reviewReference": "repository issue or reviewed change URL",
    "expires": "ACTUAL_UTC_DATE_WITHIN_30_DAYS"
  }
]
```

Do not paste actual secrets into an issue or report. For a genuine committed credential, stop, revoke/rotate through the appropriate existing credential workflow and assess Git history. This pipeline does not rotate the RDS password.

## Tools, permissions and capacity

Trivy 0.75.0 and Terraform 1.13.5 archive versions/SHA-256 hashes are checked in under `security/tool-pins.json`. Downloads use bounded retries and exact archive checksums. No `curl | sh`, floating scanner installer or mutable GitHub Action is used. Helm/kubectl retain Phase 9's pinned versions and official companion checksum verification. Review pin updates like application code.

Trivy's current vulnerability database and IaC checks are fetched at build time. Database/network/scanner failures fail the gate; no offline or stale-cache fallback is configured. `release.json` records tool pins, database metadata and safe report checksums. Raw secret reports/errors remain in private temporary build files, never in logs or published artifacts; raw scanner JSON is removed after processing. Scan-error text is not published. Failed builds print a scanner-failure category rather than secret-bearing output.

Build and scan serially to reduce memory pressure, but CodeBuild can still run out of memory. This consumes CI compute minutes/storage/network; it does not add Kubernetes capacity. If the current SMALL build cannot handle it, diagnose the actual failure before reviewing an increase to the CI project only in Phase 9 Terraform. Do not increase EKS nodes to fix a CodeBuild memory failure. This package does not automatically change CodeBuild size or IAM.

Existing CI permissions remain limited to its current build/artifact/log/ECR operations. Terraform `validate` needs provider downloads but no AWS infrastructure read/write permissions; no provider credential is passed to a deployment job or application. Deployment still uses Phase 9's private endpoint, NAT, namespace role and approval. Scanners do not need Secrets Manager/RDS/EKS IAM. Trivy does not authenticate to ECR for image scans: it uses the exact local Docker image.

The artifact contains the same-commit chart, deployment scripts, checksum-verified tools, `release.json` and sanitized JSON reports. It does not contain the whole source tree, `node_modules`, scanner databases, Terraform providers/state, real configuration or DB credentials. The CD project verifies the report checksums and digest binding before EKS access. Checksums detect mismatches; they are not signatures that make malicious trusted pipeline code safe. Protect/review main and the scripts, chart, Dockerfiles, tool pins and exception policy. Do not run this privileged pipeline on untrusted PR code.

## 1. Apply the package locally

Download `OpsFlow_Phase12_DevSecOps.zip` to your Downloads folder. Extraction creates `Desktop\opsflow-phase12`. Preserve any older directory rather than mixing package versions.

```powershell
$OpsRepoRoot = 'C:\Users\ROHIT\Desktop\aws-eks-ops-platform'
$OpsPhase12Source = 'C:\Users\ROHIT\Desktop\opsflow-phase12'
if (Test-Path $OpsPhase12Source) { throw 'Extraction target exists; preserve it and use a fresh path' }
Expand-Archive -LiteralPath "$env:USERPROFILE\Downloads\OpsFlow_Phase12_DevSecOps.zip" `
    -DestinationPath 'C:\Users\ROHIT\Desktop'
& "$OpsPhase12Source\scripts\phase12\Apply-Phase12.ps1" -RepoRoot $OpsRepoRoot
Set-Location $OpsRepoRoot
git status --short
git --no-pager diff --stat
git --no-pager diff -- backend/src ci infrastructure
```

The installer checks every existing file against the reviewed repository baseline before writing anything, tolerates CRLF, and backs up changed files under ignored `.phase12/`. It will stop if your current files differ; do not force overwrite. It does not replace your chart or frontend source. Two backend lint fixes preserve behavior: `_next` retains Express's four-argument error handler; unused catch binding is removed. Three Phase 10 Terraform files receive formatting only. Provider lockfiles add signed Linux checksums without changing provider versions, so Linux CI can validate the Windows-created roots.

If PowerShell blocks a downloaded script, inspect it first, unblock that specific file with `Unblock-File`, then rerun. Do not change machine-wide execution policy.

```powershell
git check-ignore .phase12/apply-backup-example/file.txt
# Expected ignored. Only .phase12/.gitignore belongs in Git.
git --no-pager diff -- infrastructure/phase10
# Review: formatting/checksums only; no resource/configuration changes.
```

## 2. Review the known IaC findings before a pipeline run

Open `docs/phase12-validation.md` and `docs/preparation-iac-findings.json`. These are preparation evidence, not passing release evidence. Review each blocked resource/check against the original source and actual lab design.

- EKS public-endpoint/allowlist findings can depend on unresolved Terraform variables. Your earlier live output had private access plus a restricted public admin /32; verify current values instead of assuming that output remains current.
- Broad egress findings include Phase 5 control/node rules and Phase 9's intended TCP443 NAT egress. A static CRITICAL label is not an exploitability finding. It still blocks this policy; do not hide it. Narrow actual rules only after dependency analysis and a separately reviewed Terraform plan. Do not break cluster/RDS/CodeBuild connectivity to silence a scanner.
- Older `kubernetes/base` PostgreSQL and migration Job manifests are scanned because they remain deployable tracked IaC. Retire obsolete manifests from deployable paths with reviewed Git history/documentation, or harden them. Merely calling them historical does not exempt them in this gate.
- Helm Secret permissions and Fluent Bit host access are sensitive intentional capabilities. Review whether the precise HIGH finding warrants a short-lived documented exception; do not give cluster-admin.
- Frontend Dockerfile has no explicit USER, although the chart supplies runtime security context. Review the image's nginx paths/permissions before changing USER; an arbitrary USER change can break it.
- Encryption checks prefer stronger key management than existing SSE-S3. Assess cost, IAM and operational impact before adding KMS; this package does not silently provision it.

The policy has no CRITICAL exceptions. If the design requires an intentional scanner-rated CRITICAL control, that is a policy/design decision to resolve explicitly before claiming Phase 12 gate success. Do not claim a pass from this package's failed baseline. Do not run Terraform apply against existing phases from CI. Infrastructure fixes are separate, operator-reviewed work and may have cost/capacity implications.

To inspect the current cluster endpoint configuration without changing it:

```powershell
$OpsRegion = 'ap-south-1'
$OpsCluster = 'opsflow-lab'
$OpsContext = 'opsflow-eks'
$env:AWS_REGION = $OpsRegion
$env:AWS_DEFAULT_REGION = $OpsRegion
$env:AWS_PAGER = ''
aws sts get-caller-identity --query Account --output text
if ($LASTEXITCODE -ne 0) { throw 'AWS session unavailable; reauthenticate the intended profile' }
aws eks describe-cluster --name $OpsCluster --region $OpsRegion `
    --query 'cluster.{Status:status,Network:resourcesVpcConfig}' --output json
if ($LASTEXITCODE -ne 0) { throw 'Cluster lookup failed' }
```

Do not paste private tfvars/state/credentials into chat. A redacted endpoint/allowlist output and the blocked check/resource IDs are enough to start review.

## 3. Commit reviewed code and any resolved findings

Do this only after reviewing the actual diffs. There is no need to rerun Phase 6 CRUD/failure drills. The current backend health test and lint commands were already run during package preparation; CI reruns them against the committed source. Do not add dummy frontend tests.

```powershell
Set-Location $OpsRepoRoot
git add ci security docs/phase12-devsecops.md docs/phase12-validation.md `
    docs/phase12-results-template.md docs/preparation-iac-findings.json `
    scripts/phase12 .phase12/.gitignore `
    backend/src/middleware/errorHandler.js backend/src/routes/readiness.routes.js `
    infrastructure/phase10/main.tf infrastructure/phase10/variables.tf infrastructure/phase10/versions.tf `
    infrastructure/phase10/.terraform.lock.hcl infrastructure/phase9/.terraform.lock.hcl `
    infrastructure/phase5/.terraform.lock.hcl `
    infrastructure/phase4/bootstrap/.terraform.lock.hcl infrastructure/phase4/foundation/.terraform.lock.hcl
# Stage any separately reviewed remediation explicitly, not with git add .
git --no-pager diff --cached --stat
git --no-pager diff --cached --name-only
git --no-pager diff --cached
# Confirm no real .env, runtime backup, backend.hcl, tfvars, tfstate/tfplan or credentials.
git commit -m 'feat: add DevSecOps gates before approved Helm deployment'
if ($LASTEXITCODE -ne 0) { throw 'Commit failed' }
git push origin main
if ($LASTEXITCODE -ne 0) { throw 'Push failed' }
```

Keep `detect_changes=false`. No Phase 9 Terraform apply is needed just to use the updated repository buildspec/scripts. A future unified up/down wrapper is separate work and does not remove the separate Terraform state/dependency ordering.

## 4. One controlled execution, after blockers are resolved

Check that the existing application is healthy and no pipeline execution is active. Do not manually upgrade Helm while the pipeline is active.

```powershell
$OpsPipeline = 'opsflow-lab-application'
helm status opsflow -n opsflow --kube-context $OpsContext
if ($LASTEXITCODE -ne 0) { throw 'Existing deployed Helm release required' }
aws codepipeline list-pipeline-executions --pipeline-name $OpsPipeline --region $OpsRegion `
    --max-items 10 --query 'pipelineExecutionSummaries[].{Id:pipelineExecutionId,Status:status}' --output table
if ($LASTEXITCODE -ne 0) { throw 'Execution lookup failed' }
# Stop here if anything is InProgress or otherwise awaiting approval/deployment.
$OpsStartJson = aws codepipeline start-pipeline-execution --name $OpsPipeline --region $OpsRegion --output json
if ($LASTEXITCODE -ne 0) { throw 'Pipeline start failed' }
$OpsExecutionId = ($OpsStartJson | ConvertFrom-Json).pipelineExecutionId
Write-Host "Execution ID: $OpsExecutionId"
aws codepipeline list-action-executions --pipeline-name $OpsPipeline `
    --filter "pipelineExecutionId=$OpsExecutionId" --region $OpsRegion `
    --query 'actionExecutionDetails[].{Stage:stageName,Action:actionName,Status:status,Error:output.executionResult.errorDetails.message}' `
    --output table
```

Keep `$OpsExecutionId` in the current PowerShell scope. Do not start a second run just because an initial status query is empty. On failure, inspect the exact stage and sanitized report, fix the real cause, review/commit it, then start one new execution. Do not repeatedly rebuild an unchanged failing commit. Scanner download/database/provider failures are failures, not “zero findings.” Do not approve a run missing passing evidence.

## 5. Approval and final acceptance

For the exact execution, review the full source SHA, actual lint/test logs, `testCoverage`, all five sanitized reports, accepted HIGH exceptions/expiry, remaining MEDIUM/LOW findings, tool/database metadata, image digests, completed ECR scans and chart diff. Only an authorized operator decides whether the disclosed gaps/findings are acceptable.

Approve in the existing AWS console approval action only after the review. CD rejects missing/tampered reports, a digest mismatch or an exception that expired while awaiting approval, then uses the existing read-only baseline, Helm atomic upgrade, image/rollout checks and internal frontend → backend → RDS checks. No DB bootstrap/migration/secret rotation runs. Existing rollback limits still apply; this phase does not repeat a destructive rollback drill.

```powershell
aws codepipeline get-pipeline-execution --pipeline-name $OpsPipeline `
    --pipeline-execution-id $OpsExecutionId --region $OpsRegion `
    --query 'pipelineExecution.{ExecutionId:pipelineExecutionId,Status:status,Source:artifactRevisions}' --output json
helm history opsflow -n opsflow --kube-context $OpsContext
$OpsDeploymentJson = kubectl --context $OpsContext get deployments -n opsflow -o json
if ($LASTEXITCODE -ne 0) { throw 'Deployment lookup failed' }
($OpsDeploymentJson | ConvertFrom-Json).items | ForEach-Object {
    [PSCustomObject]@{Deployment=$_.metadata.name; Ready=$_.status.readyReplicas;
        Images=($_.spec.template.spec.containers.image -join ', ')}
} | Format-List
```

Verify deployed digests match the approved artifact and deployment evidence. Open the existing ALB once from the allowed admin IP; confirm the frontend and read-only `/api/incidents`. No new incident is required. Internal checks do not establish public ALB routing. Do not widen its allowlist for CodeBuild. Record only non-secret evidence; avoid copying incident content or credential material.

## Results, costs and cleanup

Copy the template to `docs/phase12-results.md`, fill actual statuses/IDs/digests/scanner evidence/test gaps and link it from your existing README. Keep incomplete steps pending. Commit only that evidence and README after successful acceptance. A documentation commit with triggers disabled needs no redundant deployment.

No new always-on infrastructure is added, but existing Phase 9 NAT/EIP and AWS lab resources continue to cost money. Scans increase CodeBuild minutes and downloads; ECR images/artifact versions/logs also have retention costs. Use a bounded lab window. Follow the existing Phase 9-only teardown if retiring the pipeline, preserving required evidence and rollback digests first. Do not delete Terraform state, the state bucket or DB data. No cleanup is performed by this package.

Completion requires a real passing security build, reviewed approval, successful Helm deployment and external read-only acceptance. Prepared code, a previous Phase 9 success or a failed security baseline is not Phase 12 completion.

Primary references: [Trivy installation](https://trivy.dev/latest/docs/getting-started/installation/), [Trivy vulnerability scanning](https://trivy.dev/latest/docs/scanner/vulnerability/), [Trivy misconfiguration scanning](https://trivy.dev/latest/docs/scanner/misconfiguration/), [Oxlint CLI](https://oxc.rs/docs/guide/usage/linter.html), [Terraform validate](https://developer.hashicorp.com/terraform/cli/commands/validate), [Terraform provider locks](https://developer.hashicorp.com/terraform/cli/commands/providers/lock). Tool pins are intentional; review scanner supply-chain notices before upgrading.


