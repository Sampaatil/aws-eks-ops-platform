Phase 14 — AWS cost optimization assessment
Project: OpsFlow AWS EKS Operations Platform
Assessment date: 12 October 2026 (IST)
Status: Cost baseline and recommendations documented. No optimization changes or measured savings verified.
1. Objective and scope
Understand the lab's main cost drivers and recommend practical controls while preserving enough CPU, memory and Pod capacity for the application and observability stack. This phase is an evidence-based documentation exercise. It creates no AWS resources and performs no application incident, load, CRUD or recovery tests.
The assessment uses one user-provided AWS Billing screenshot, image(20261012-170601).png. Its tooltip shows October 2026 costs grouped by service. The screenshot does not expose the selected cost metric, filters, exact cutoff, account scope, credits, taxes or resource-level usage. Treat the figures as the displayed October baseline, not a final invoice or a verified OpsFlow-only bill. October is incomplete at the assessment date.
2. Observed cost baseline
Displayed service	USD	Share of displayed total
Amazon EKS	8.21	42.6%
EC2 Compute	3.54	18.4%
EC2 – Other	2.87	14.9%
Amazon RDS	1.99	10.3%
Amazon VPC	1.41	7.3%
Others	1.26	6.5%
Total	19.28	100.0%


Calculation: 8.21 + 3.54 + 2.87 + 1.99 + 1.41 + 1.26 = 19.28 USD. Percentages are calculated from this total and rounded to one decimal place.
Observations
1. EKS is the largest displayed service cost, representing 42.6% of the total. Worker compute is separately displayed, so reducing application replicas alone would not address the entire EKS cost.
2. EC2 Compute and EC2 – Other together total 6.41 USD, or 33.2%. These should be investigated separately: instance capacity and ancillary resource charges require different controls.
3. The October bar is visibly higher than the preceding months shown. Exact prior-month totals are unavailable, and the screenshot does not establish the cause of that increase. The timing of this EKS project is context, not proof of attribution.
4. RDS is 10.3% of the displayed total. Its configuration and utilization were not supplied for this assessment, so neither oversizing nor eligibility for a cheaper configuration is established.
5. EC2 – Other can include EBS, snapshots, NAT gateways and data transfer. The screenshot cannot determine which contributed to the 2.87 USD. Similarly, VPC's 1.41 USD must not be labelled entirely as NAT or public IPv4 cost without usage-type evidence.
6. The 1.26 USD Others category is aggregated. It does not prove that CloudWatch, S3, ECR, load balancing or CI/CD were free or absent.
3. Architecture context and ongoing charges
The previously described OpsFlow design includes EKS workers, external RDS, an ALB, ECR, CodePipeline/CodeBuild, a private deployment subnet with NAT/public IPv4, Terraform state and artifact storage, and CloudWatch plus in-cluster Prometheus/Grafana. These are project context; current quantities, instance sizes and utilization have not been independently inspected in Phase 14.
Component	Cost consideration	Practical implication
EKS control plane	Cluster pricing is separate from worker compute	Fewer Pods do not eliminate the cluster's ongoing charge
EC2 workers	Running capacity and attached storage	Preserve capacity for system Pods, app and monitoring
NAT gateway	Provisioned hours and processed data	An idle pipeline does not remove NAT's provisioned-hour charges
Public IPv4	Address-related charges can apply	Check retained addresses separately from compute
RDS	Instance, storage and backup charges depend on configuration	Database data loss and recovery requirements govern teardown
ALB	Provisioned load balancer and usage	An idle application can still retain a billable load balancer
CI/CD	Pipeline actions and build compute	Avoid repeated builds of identical commits and documentation-only churn
Logs and storage	Ingestion, retained bytes, versions and requests	Retention and cleanup require deliberate policies
Prometheus/Grafana	Consume existing worker capacity in this design	Their lack of separate nodes does not mean their resource use is zero


Closing the laptop or keeping detect_changes=false is not infrastructure teardown. AWS resources can remain active afterward.
4. Prioritized optimization recommendations
These are recommendations, not changes performed in this phase. Exact dollar savings remain unmeasured.
Priority	Recommendation	Expected benefit	Constraint / decision
1	Use a bounded lab window; plan reviewed teardown between long periods of inactivity	Reduce provisioned hours of disposable infrastructure	Requires reliable recreation and explicit data/retention decisions. Phase 15 lifecycle automation is not verified complete
2	Investigate EC2 – Other and VPC by usage type when more billing evidence is available	Identify NAT, EBS, snapshots, IPv4 or transfer contributions	Do not delete resources from an aggregate billing label
3	Keep CI/CD on demand with detect_changes=false, as already chosen	Avoid unintended build/action execution	Does not stop NAT, EKS, RDS or ALB charges; no new savings claim
4	Review worker utilization, reservations and Pod limits before resizing	Avoid both wasted capacity and capacity failures	No node-count reduction recommended from this screenshot
5	Check bounded CloudWatch retention and preserve useful incident evidence	Limit retained log storage growth	Shorter retention does not reverse ingestion charges; current retention unverified here
6	Retain required rollback images; review obsolete ECR images and artifact versions	Limit storage accumulation	Protect digests referenced by live workloads and retained Helm revisions
7	Review unused EBS, old snapshots and unassociated addresses	Remove demonstrably unused resources	Establish ownership, backup value and Terraform management before deletion
8	Consider a small budget notification and project cost allocation tags	Improve visibility and early warning	Neither is implemented by this report; alerts do not automatically cap spending


Capacity decision
The user reports constrained resources and capacity. Reducing desired worker capacity to one could leave insufficient room for system services, backend/frontend replicas, logging and monitoring. Setting an HPA maximum only bounds application replicas; it does not reserve memory, increase node capacity or guarantee successful scheduling. Autoscaling remains deferred. Keep the existing capacity until representative utilization, requests/limits, allocatable resources and Pod limits support a reviewed change.
Network and database decisions
Do not remove NAT while private deployment builds depend on its egress. Interface endpoints and NAT instances are alternative designs with their own charges and operational requirements; this assessment does not establish that either is cheaper for this lab.
The user prefers a fresh database on future recreation. That preference does not mean the database was deleted in Phase 14. Any later teardown must settle running deployments, explicitly handle data disposal and backups, preserve required state/evidence, and review the intended Terraform destroy plan. Do not use broad account-wide deletion commands.
Commitment decision
Do not purchase Reserved Instances or Savings Plans based on this partial-month screenshot. A short-lived, intermittently used interview lab needs a usage history and commitment analysis before a purchase is justified. Spot workers would add interruption and scheduling complexity; no migration is proposed for the capacity-constrained lab.
5. Measurement and evidence limits
No monthly forecast is produced. Multiplying the displayed total by a calendar factor would assume stable operating hours, rates, resource counts and billing cutoff, none of which are established.
For a later comparable measurement, keep the same account/project scope, region, cost metric and credits treatment; record the change date and resource inventory; compare representative equal-duration periods after billing updates. Separately report one-time rebuild costs, retained storage and resource-hour reductions. Do not describe the full 19.28 USD as avoidable spend.
Optional future evidence, not required to accept this report:
- Cost Explorer grouped by usage type for EC2 – Other and VPC.
- Daily costs and the actual resource running window.
- EC2/RDS sizes, storage, backups and worker utilization over a representative period.
- Live log retention, artifact lifecycle and ECR rollback references.
- Credits/taxes and invoice amount payable.
6. Results and completion status
Item	Status
Read supplied billing screenshot	Complete
Calculate displayed total and service shares	Complete
Identify cost drivers and capacity-aware recommendations	Complete
Document evidence limits and retained-resource considerations	Complete
Provision new AWS resources	Not performed / not required
Run application or load tests	Not performed / not required
Apply cost optimization changes	Not performed
Verify utilization / resource attribution	Not verified
Verify dollar savings after changes	Not measured
Commit this report to the project repository	Pending user execution


Phase 14 cost assessment is complete as documentation. Optimization implementation and measured savings are not complete.
7. Install and commit the documentation
Save this file in the repository as docs/phase14-cost-optimization.md. Keep the existing README content and add one link if absent:
[Phase 14 — AWS cost optimization assessment](docs/phase14-cost-optimization.md)
Then use PowerShell from the repository root:
git --no-pager diff -- README.md
git add docs/phase14-cost-optimization.md README.md
git --no-pager diff --cached
git --no-pager diff --cached --name-only
git commit -m "docs: record AWS cost baseline and optimization assessment"
if ($LASTEXITCODE -ne 0) { throw 'Commit failed' }
git push origin main
if ($LASTEXITCODE -ne 0) { throw 'Push failed' }
git status --short
No pipeline execution or Terraform apply is necessary for this documentation-only change. Keep on-demand triggering as previously selected.
8. Interview explanation
“I reviewed the AWS service cost breakdown for my EKS lab. The screenshot showed 19.28 USD, with EKS the largest contributor at 42.6%. I prioritized reducing idle infrastructure time, investigating ancillary EC2/network costs and controlling build frequency and storage retention. I avoided reducing worker capacity without utilization evidence because the app and monitoring share limited resources. I documented recommendations separately from implemented changes and did not claim savings I had not measured.”
9. Reference material
AWS references checked on 12 October 2026. No region-specific price quote or purchase recommendation is made.
- Amazon EKS pricing — control plane and worker-related pricing context.
- NAT gateway pricing — provisioned hours, processing and network cost considerations.
- AWS: Optimize and save on other services — EC2 – Other contains multiple ancillary usage types.
- CloudWatch log retention — retention is configurable; logs otherwise remain indefinitely by default.
Billing evidence: user-supplied screenshot; numerical observations above derive from that screenshot rather than these reference pages.