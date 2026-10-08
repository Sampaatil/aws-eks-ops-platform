# Step 14 — EKS End-to-End Validation

Date: 8 October 2026
Region: ap-south-1
Cluster: opsflow-lab
Namespace: opsflow

## Architecture
Client → ALB → Nginx Frontend → Node.js Backend → RDS PostgreSQL

## Results
- ALB health check: Passed
- Backend health check: Passed
- Database readiness: Passed
- Incident creation: Passed (ID 1)
- Incident retrieval: Passed
- Repeated incident retrieval: Passed
- Readiness smoke test: 10/10 passed
- Backend replicas: 2/2 Ready
- Frontend replicas: 2/2 Ready
- Backend restarts: 0
- Backend Service endpoints: 2

## Observations
- Backend replicas are scheduled on the same worker node.
- Node-level high availability is not yet achieved.
- ALB currently uses HTTP with restricted ingress.
- HTTPS, authentication, and availability improvements remain future work.

## Conclusion
End-to-end API functionality through AWS ALB, EKS, and RDS
PostgreSQL was successfully validated.