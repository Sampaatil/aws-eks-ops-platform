# Kubernetes Architecture

## Workloads

### Frontend

The frontend runs as a Kubernetes Deployment with two replicas.

Nginx serves the compiled React application and reverse proxies API
requests to the backend Kubernetes Service.

### Backend

The backend runs as a Deployment with two replicas.

The application uses separate liveness and readiness endpoints.

Liveness verifies that the Node.js process is functioning.

Readiness verifies PostgreSQL connectivity.

### PostgreSQL

PostgreSQL runs as a single replica for local Kubernetes development.

A PersistentVolumeClaim separates database storage from the Pod
lifecycle.

The AWS architecture will replace this workload with Amazon RDS.

## Service Discovery

Applications communicate using Kubernetes Service DNS rather than
Pod IP addresses.

Frontend:

backend-service:3000

Backend:

postgres-service:5432

## Failure Recovery

Deployments continuously reconcile desired and actual state.

Deleting a backend Pod causes its ReplicaSet to create a replacement
automatically.

## Rolling Updates

Backend and frontend Deployments use RollingUpdate.

The deployment configuration allows a new Pod to become ready before
an existing Pod is removed.

## Configuration

Non-sensitive configuration is stored in ConfigMaps.

Sensitive local development configuration is provided using a
Kubernetes Secret.

Production AWS secrets will not be stored directly in Git.