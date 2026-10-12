# OpsFlow portfolio guide

Prepared on 12 October 2026 from source commit f0b543803be701b98b35055159ddf33fef291e71. Documentation only: no infrastructure changes or extra application tests.

## Five-minute interview walkthrough

1. Explain the purpose: React status UI, Express incident API and external PostgreSQL; the focus is delivery and operations.
2. Show the architecture: Terraform owns AWS infrastructure; Helm owns app objects; RDS and credentials are external dependencies.
3. Walk through exact commit → CI checks → ECR digests → approval → private CodeBuild Helm upgrade → acceptance and recovery.
4. Show observability evidence: tagged CloudWatch logs, Kubernetes metrics and the five-request synthetic error investigation.
5. Explain practical tradeoffs: shared limited capacity, ephemeral monitoring, test coverage, Single-AZ RDS and ongoing infrastructure costs.

## Resume bullets

- Built an AWS EKS application platform using Terraform, Helm, ECR and external RDS PostgreSQL, with health/readiness checks and digest-pinned releases.
- Implemented a CodePipeline/CodeBuild workflow with lint, declared tests, IaC checks, Trivy scanning, manual approval and private-endpoint Helm deployment; documented successful release execution.
- Integrated CloudWatch logging and Prometheus/Grafana monitoring; correlated five synthetic HTTP errors with metrics and structured logs while recorded workloads remained healthy.

Use these only to describe your own contributions. Do not claim measured savings, complete security coverage or professional production ownership from this lab.

## Evidence and screenshots

Existing reports are linked in the README. Use verified screenshots already captured; no repeat test is needed for presentation. Optional screenshot files can go under `docs/images/`:

| Filename | What to show |
|---|---|
| `opsflow-status.png` | Status frontend and API version |
| `pipeline-success.png` | Exact successful execution and stages |
| `grafana-incident.png` | Synthetic error activity, real API errors and replicas; visible time window |
| `cloudwatch-incident.png` | Matching synthetic run/request IDs; hide sensitive content |

Add Markdown image links only after files exist. Include capture date and the matching report/execution. Screenshots are not included in this package; the README uses evidence links instead.

## Source and evidence observations

- The previous README named GitHub Actions and contained stale early-stage status sections. The replacement describes the actual AWS pipeline.
- Phase 9 revision 5 is a historical example, not the latest release.
- Phase 10 includes a verified results section after its original blank template.
- Current dependency scanner code uses production dependencies; older security documentation describes broader intended coverage. The README reflects current code.
- Phase 12 preparation evidence includes failures; scanner implementation is not treated as proof of a fully passing live execution.
- Phase 13 supports the synthetic investigation, while identifying missing final acceptance confirmations.
- The cost report is presently named `phase14-ccost-optimization.md` in Git. Links preserve that actual filename.

## Apply and publish

The package contains only `README.md` and `docs/portfolio-guide.md`. It preserves application/infrastructure files. Copy both into the repository and review before committing:

```powershell
Set-Location 'C:\Users\ROHIT\Desktop\aws-eks-ops-platform'
git --no-pager diff -- README.md
Get-Content .\docs\portfolio-guide.md
git add README.md docs/portfolio-guide.md
git --no-pager diff --cached --stat
git --no-pager diff --cached --name-only
git --no-pager diff --cached
git commit -m "docs: present OpsFlow architecture and portfolio evidence"
if ($LASTEXITCODE -ne 0) { throw 'Commit failed' }
git push origin main
if ($LASTEXITCODE -ne 0) { throw 'Push failed' }
git status --short
```

Confirm GitHub renders the diagrams, tables and links. On-demand triggering means no pipeline execution is needed for these documentation changes.

## Completion record

README and interview/evidence guide prepared. Local documentation links and numerical summary checked. No AWS changes, deployment or extra application tests performed. Git commit/push and GitHub rendering await the user's actual outputs.
