# Phase 12 — Preparation validation

Date: 11 October 2026. Read-only repository baseline: `a33fcd7` (`feat: add CloudWatch logging and Kubernetes observability`). No AWS or local Windows machine access was used.

| Check | Actual result |
|---|---|
| Trivy 0.75.0 Linux archive | SHA-256 matched official release checksum; binary version ran |
| Terraform 1.13.5 Linux archive | SHA-256 matched official release checksum; binary version ran |
| Python files | Syntax compilation passed |
| Guarded installer | PowerShell 7.5.3 local disposable-target check passed with CRLF originals; unexpected edits rejected before any mutation. User Windows execution remains pending |
| Security policy/contract | Seven focused checks passed: HIGH blocks, CRITICAL cannot be excepted, secret values do not leak, specific HIGH acceptance is recorded, MEDIUM stays visible, expired exception rejects, digest/report tampering rejects |
| Frontend lint | Existing locked Oxlint, deny warnings: passed |
| Backend lint | Same locked Oxlint, node/Jest config: passed after two unused-binding fixes |
| Backend tests | Existing Jest/Supertest health test: one suite/one test passed; no RDS call |
| Frontend tests | NOT RUN: no declared `test:ci` |
| Source secret scan | Passed locally, zero detected findings; pattern-based coverage only |
| Dependency scan | Initial default production-dependency scan returned zero findings. Final gate explicitly includes development dependencies; complete final dependency gate not claimed verified locally |
| Terraform format | Three Phase 10 files required formatting; formatting corrected |
| Provider locks | Official signed Linux/Windows provider checksums obtained; existing versions retained. Linux h1 checksum added to Phase 9/10 locks |
| All-root Terraform validate | NOT COMPLETE: local provider startup failed after initialization. CI validation remains required; failure was not treated as success |
| Helm render/static IaC | Real app chart rendered using non-secret synthetic values. Trivy found 114 findings: 59 LOW, 30 MEDIUM, 21 HIGH, 4 CRITICAL. Gate correctly FAILED on 25 blockers |
| Docker/image/ECR/CD/AWS acceptance | NOT RUN during preparation |

The sanitized baseline is `docs/preparation-iac-findings.json`. Its status is FAILED. No exceptions were added. The report includes safe check/resource identifiers and fingerprints, not secret matches or source snippets.

A later local dependency inspection encountered a scanner/database read failure and produced no complete report. It is not a pass. The release gate fails on scanner/database execution errors. The final development-dependency coverage must be demonstrated in the real build.

## Known blockers to review

| Existing source/control | Blocked finding(s) | Review implication |
|---|---|---|
| Frontend Dockerfile | DS-0002 HIGH | Runtime chart security context does not establish non-root standalone image behavior |
| State/artifact bucket encryption | AWS-0132 HIGH | Existing SSE-S3 differs from scanner's preferred key-management control; no automatic KMS provisioning |
| EKS public endpoint/allowlist | AWS-0039 HIGH; AWS-0040 CRITICAL | Unresolved variables can affect static results; compare current actual /32/private endpoint settings |
| Phase 5 control/node egress and Phase 9 TCP443 egress | AWS-0104 CRITICAL | Broad destinations flagged; assess actual traffic needs before narrowing Terraform rules |
| Historical app/PostgreSQL/DB Job YAML | KSV-0014/KSV-0118 HIGH | Retire obsolete deployable manifests or harden them; do not execute the old jobs as a test |
| Fluent Bit manifest | KSV-0118 HIGH | Logging requires host access; review exact container/host mount trust boundary |
| Namespace Helm deployer RBAC | KSV-0056 HIGH | Helm requires dynamic namespace Secret operations; sensitive permission, not a harmless scanner nuisance |

These are scanner findings against source. They are not proof of an exposed database or successful exploitation. Some intentional lab controls may conflict with the strict severity gate. Resolve design/policy interpretation explicitly; do not suppress all findings to obtain a green build. The four CRITICAL findings have no exception path in this package.

## Changes requiring review

- CI source/security gates and artifact contract; CD verifies passing evidence before EKS operations.
- Two backend binding changes only; Express error handler retains four arguments.
- Three Terraform formatting changes only; no AWS resource changes/applies.
- Linux provider checksum additions; provider versions unchanged.
- New ignored runtime directory and guarded installer.
- No chart, frontend application logic, replicas, database schema/credentials, AWS IAM or EKS capacity change.

Phase 12 is prepared but not complete. All live success/approval/acceptance rows remain pending until real outputs exist.
