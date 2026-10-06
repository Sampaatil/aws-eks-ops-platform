# OpsFlow — AWS EKS Operations Platform

OpsFlow is a production-oriented DevOps portfolio project designed
to demonstrate containerized application delivery and operations
on Amazon EKS.

## Project Goals

The project demonstrates:

- Docker containerization
- Kubernetes orchestration
- Amazon EKS
- Amazon ECR
- Terraform infrastructure as code
- Helm application packaging
- GitHub Actions CI/CD
- AWS IAM and OIDC
- AWS Load Balancer Controller
- Amazon RDS PostgreSQL
- AWS Secrets Manager
- Amazon CloudWatch
- Prometheus and Grafana
- Horizontal Pod Autoscaling
- Container and IaC security scanning
- Production troubleshooting
- AWS cost optimization

## Application

OpsFlow is a lightweight incident-management application consisting
of:

- React frontend
- Node.js/Express REST API
- PostgreSQL database

The application is intentionally simple. The primary purpose of the
project is to demonstrate infrastructure, deployment, reliability,
security and operational practices.

## Architecture

Architecture will evolve throughout the project.

Initial application flow:

Browser -> React -> Express API -> PostgreSQL

Target AWS flow:

Internet
-> Application Load Balancer
-> Amazon EKS
-> Kubernetes Services/Pods
-> Amazon RDS PostgreSQL

Container images are stored in Amazon ECR.

Infrastructure is provisioned using Terraform.

Application deployments are automated through GitHub Actions and
packaged using Helm.

## Repository Structure

frontend/        React application
backend/         Node.js REST API
infrastructure/  Terraform infrastructure
kubernetes/      Kubernetes manifests
helm/            Helm charts
monitoring/      Observability configuration
scripts/         Operational scripts
docs/            Architecture and operational documentation

## Current Status

Phase 1 — Application Foundation

- [x] Repository structure
- [x] React frontend
- [x] Express API
- [x] Health endpoint
- [x] Readiness endpoint
- [x] PostgreSQL schema
- [x] Graceful shutdown
- [x] Basic automated tests
- [ ] Docker
- [ ] Kubernetes
- [ ] AWS infrastructure
- [ ] EKS
- [ ] CI/CD
- [ ] Observability
- [ ] Security
- [ ] Production incident simulations

## API Endpoints

GET /health

GET /ready

GET /api/incidents

GET /api/incidents/:id

POST /api/incidents

PATCH /api/incidents/:id/status

DELETE /api/incidents/:id

## Security

Secrets and credentials must never be committed to this repository.

Local configuration uses environment variables.

AWS workloads will use IAM roles and AWS Secrets Manager where
appropriate.

## Cost

Phase 1 creates no AWS resources and incurs no AWS infrastructure cost.

AWS resource costs and cleanup procedures will be documented before
billable resources are provisioned.

## Phase 2 — Containerization

The application is containerized using Docker and orchestrated locally
using Docker Compose.

### Services

- Frontend — React production build served through Nginx
- Backend — Node.js/Express REST API
- Database — PostgreSQL

### Local Architecture

Browser
-> Nginx frontend
-> Express backend
-> PostgreSQL

Only the frontend is exposed to the host.

Internal communication uses Docker service discovery.

### Container Security

The backend application runs as a non-root user.

Sensitive local configuration is provided through environment
variables and is excluded from Git and Docker build contexts.

### Health Checks

Backend:

GET /health

verifies application process health.

GET /ready

verifies that the application can connect to PostgreSQL.

### Start

Create the local environment file:

```bash
cp .env.example .env

## Phase 3 — Kubernetes

OpsFlow now runs on a local Kubernetes cluster using kind.

### Kubernetes Resources

The application uses:

- Namespace
- Deployments
- ReplicaSets
- Pods
- ClusterIP Services
- NodePort Service
- ConfigMaps
- Kubernetes Secret
- PersistentVolumeClaim
- Liveness probes
- Readiness probes
- CPU and memory requests
- CPU and memory limits
- Rolling updates

### Architecture

Browser
-> NodePort
-> Frontend Service
-> Frontend Pods
-> Backend Service
-> Backend Pods
-> PostgreSQL Service
-> PostgreSQL Pod
-> PersistentVolumeClaim

### Application Namespace

All application workloads run in:

`opsflow`

### Health Model

`/health`

is used for application liveness.

`/ready`

checks PostgreSQL connectivity and determines whether backend Pods
should receive traffic.

### Local Cluster

The Kubernetes cluster is created using kind.

The locally built application images are loaded into the kind node
for development.

Production deployment will use Amazon ECR rather than locally loaded
images.

### Database

PostgreSQL runs inside Kubernetes only for local Kubernetes learning.

The AWS architecture will replace the local PostgreSQL workload with
Amazon RDS PostgreSQL.

### Production Differences

The local NodePort exposure mechanism is not the target AWS
architecture.

Amazon EKS will use AWS Load Balancer Controller and an Application
Load Balancer for application ingress.

## Phase 4 — AWS foundation

Terraform provisions an OpsFlow lab VPC across two AZs, four subnets,
explicit routing, two private ECR repositories, and a scoped ECR publisher
policy. Foundation state uses a versioned, encrypted S3 backend with native
lock files. Bootstrap state is local and backed up securely.

Private subnets currently have no internet egress. EKS/RDS/ALB and private
node outbound connectivity are subsequent phases. See docs/phase4-aws-foundation.md.