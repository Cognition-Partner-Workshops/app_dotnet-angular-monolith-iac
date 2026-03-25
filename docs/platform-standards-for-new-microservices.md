# Platform Standards for New Microservices

> **Purpose:** Reference document for teams decomposing the OrderManager monolith into microservices. Every new service's Helm chart must conform to the patterns defined here.
>
> **Source of truth:**
> - Helm chart template: [`helm/ordermanager/`](../helm/ordermanager/) (this repo)
> - Platform infrastructure: [`Cognition-Partner-Workshops/platform-engineering-shared-services`](https://github.com/Cognition-Partner-Workshops/platform-engineering-shared-services)

---

## Table of Contents

1. [Required Kubernetes Resource Checklist](#1-required-kubernetes-resource-checklist)
2. [Standard Labels and Annotations](#2-standard-labels-and-annotations)
3. [Resource Limits, Requests, and Namespace Quotas](#3-resource-limits-requests-and-namespace-quotas)
4. [Networking Requirements](#4-networking-requirements)
5. [Security Requirements](#5-security-requirements)
6. [Observability Requirements](#6-observability-requirements)
7. [Container Image and CI/CD Requirements](#7-container-image-and-cicd-requirements)
8. [ArgoCD GitOps Deployment](#8-argocd-gitops-deployment)
9. [Platform vs. Microservice Responsibility Matrix](#9-platform-vs-microservice-responsibility-matrix)
10. [Helm Chart Scaffold Reference](#10-helm-chart-scaffold-reference)

---

## 1. Required Kubernetes Resource Checklist

Every new microservice Helm chart **must** include the following resources:

| # | Resource Type | Template File | Required? | Notes |
|---|---------------|---------------|-----------|-------|
| 1 | **Deployment** | `templates/deployment.yaml` | **Required** | Main workload definition |
| 2 | **Service** | `templates/service.yaml` | **Required** | ClusterIP service exposing the app |
| 3 | **Ingress** | `templates/ingress.yaml` | **Required** | L7 routing via shared NGINX ingress controller |
| 4 | **NetworkPolicy** | `templates/networkpolicy.yaml` | **Required** | App-specific ingress/egress rules (extends platform default-deny) |
| 5 | **ServiceMonitor** | `templates/servicemonitor.yaml` | **Required** | Prometheus metrics scraping configuration |
| 6 | **HorizontalPodAutoscaler** | `templates/hpa.yaml` | Conditional | Required for staging/prod; gated by `autoscaling.enabled` |
| 7 | **Helper templates** | `templates/_helpers.tpl` | **Required** | Naming conventions, standard labels, selector labels |

Additionally, every service needs the following **outside the Helm chart** (in the IaC repo):

| # | Resource | Location | Notes |
|---|----------|----------|-------|
| 8 | **ArgoCD Application** | `argocd/application-{env}.yaml` | One per environment (dev, staging) |
| 9 | **Dockerfile** | `docker/Dockerfile` | Multi-stage build, exposes port 8080 |
| 10 | **CI/CD Pipeline** | `ci/build-push.yaml` | GitHub Actions workflow for ECR push |

---

## 2. Standard Labels and Annotations

### 2.1 Standard Labels (Required on All Resources)

Defined in `_helpers.tpl` via the `<chartname>.labels` helper:

```yaml
helm.sh/chart: <chart-name>-<chart-version>    # e.g. order-service-0.1.0
app.kubernetes.io/name: <chart-name>            # e.g. order-service
app.kubernetes.io/instance: <release-name>      # e.g. release-order-service
app.kubernetes.io/managed-by: Helm              # Always "Helm" for Helm-managed resources
```

### 2.2 Selector Labels (Pod Template and Service Selectors)

Defined via the `<chartname>.selectorLabels` helper:

```yaml
app.kubernetes.io/name: <chart-name>
app.kubernetes.io/instance: <release-name>
```

> **Important:** Selector labels must be a stable subset of the full labels. Never include `helm.sh/chart` in selectors as it changes on chart version bumps.

### 2.3 Namespace Labels (Applied by Platform)

The platform provisions namespaces with these labels:

```yaml
app.kubernetes.io/managed-by: cdk          # or "terraform" for legacy
platform/environment: dev                   # dev | staging | prod
platform/team: dotnet-angular-monolith      # team identifier
```

### 2.4 Required Annotations

| Annotation | Applied To | Value | Purpose |
|------------|-----------|-------|---------|
| `cert-manager.io/cluster-issuer` | Ingress | `letsencrypt-staging` (non-prod) or `letsencrypt-prod` (prod) | Automatic TLS certificate provisioning |

### 2.5 Naming Conventions

Defined in `_helpers.tpl`:

| Helper | Pattern | Max Length | Example |
|--------|---------|-----------|---------|
| `<chart>.name` | `Chart.Name` (or `nameOverride`) | 63 chars | `order-service` |
| `<chart>.fullname` | `<release>-<chart>` (or `fullnameOverride`) | 63 chars | `release-order-service` |

---

## 3. Resource Limits, Requests, and Namespace Quotas

### 3.1 Namespace-Level Resource Quotas (Platform-Provisioned)

Each app namespace has the following quotas enforced by the platform:

| Quota | Default Value |
|-------|---------------|
| `requests.cpu` | `2` (cores) |
| `requests.memory` | `4Gi` |
| `limits.cpu` | `4` (cores) |
| `limits.memory` | `8Gi` |
| `pods` | `20` |
| `services` | `10` |
| `persistentvolumeclaims` | `5` |

> **Implication:** The sum of all pods' resource requests/limits in a namespace cannot exceed these quotas. Plan your replica counts and per-pod resources accordingly.

### 3.2 Namespace-Level LimitRange (Platform-Provisioned)

Containers without explicit resource specs get these defaults:

| Setting | CPU | Memory |
|---------|-----|--------|
| Default request | `100m` | `128Mi` |
| Default limit | `500m` | `256Mi` |
| Max (per container) | `2` | `2Gi` |

### 3.3 Recommended Per-Service Resource Specs

Specify explicit `resources` in your `values.yaml` per environment:

| Environment | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-------------|-------------|----------------|-----------|--------------|
| **Dev** | `50m` | `128Mi` | `250m` | `256Mi` |
| **Staging** | `100m` | `256Mi` | `500m` | `512Mi` |
| **Production** | `100m` | `256Mi` | `500m` | `512Mi` |

Example in `values.yaml`:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### 3.4 Replica Counts and Autoscaling

| Environment | Replica Count | HPA Enabled | Min Replicas | Max Replicas | Target CPU% |
|-------------|---------------|-------------|--------------|--------------|-------------|
| **Dev** | 1 | No | - | - | - |
| **Staging** | 2 | Yes | 2 | 4 | 75% |
| **Production** | 2+ | Yes | 2+ | 4+ | 75-80% |

HPA template (gated by `autoscaling.enabled`):

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "<chart>.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
```

> **Important:** When HPA is enabled, do **not** set `spec.replicas` on the Deployment (the HPA manages it).

---

## 4. Networking Requirements

### 4.1 Platform Default Network Policies (Applied to Every App Namespace)

The platform applies these four `NetworkPolicy` resources to each namespace:

| Policy Name | Type | Effect |
|-------------|------|--------|
| `default-deny-all` | Ingress + Egress | **Deny all** traffic by default |
| `allow-dns` | Egress | Allow DNS resolution (UDP/TCP port 53) |
| `allow-ingress-controller` | Ingress | Allow traffic from `ingress-nginx` namespace |
| `allow-prometheus-scrape` | Ingress | Allow Prometheus scraping from `monitoring` namespace on ports 8080 and 9090 |

### 4.2 App-Specific NetworkPolicy (Required in Helm Chart)

Each service **must** define its own `NetworkPolicy` that:

1. **Selects its own pods** via `selectorLabels`
2. **Allows ingress** from the `ingress-nginx` namespace on the app's `targetPort`
3. **Allows ingress** from the `monitoring` namespace on the metrics port (if monitoring is enabled)
4. **Allows egress** for DNS (UDP/TCP 53) and HTTPS (TCP 443)
5. **Allows egress** to any service-specific dependencies (e.g., databases, other microservices)

Reference template:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "<chart>.fullname" . }}
  labels:
    {{- include "<chart>.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      {{- include "<chart>.selectorLabels" . | nindent 6 }}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow traffic from NGINX ingress controller
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ingress-nginx
      ports:
        - protocol: TCP
          port: {{ .Values.service.targetPort }}
    # Allow Prometheus scraping
    {{- if .Values.monitoring.enabled }}
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
      ports:
        - protocol: TCP
          port: {{ .Values.monitoring.port }}
    {{- end }}
  egress:
    # DNS resolution
    - to: []
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    # HTTPS outbound (e.g., AWS services, external APIs)
    - to: []
      ports:
        - protocol: TCP
          port: 443
    # Add service-specific egress rules below (e.g., database, other services)
```

### 4.3 Ingress Conventions

| Setting | Standard Value |
|---------|---------------|
| `ingressClassName` | `nginx` |
| Annotation | `cert-manager.io/cluster-issuer: letsencrypt-staging` (non-prod) |
| Host pattern | `<service-name>-<env>.workshop.local` (e.g., `order-service-dev.workshop.local`) |
| Path | `/` with `pathType: Prefix` |
| Backend port | Service port (default `80`) |

Example:

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-staging
  hosts:
    - host: order-service-dev.workshop.local
      paths:
        - path: /
          pathType: Prefix
```

### 4.4 Service Conventions

| Setting | Standard Value |
|---------|---------------|
| Service type | `ClusterIP` |
| Service port | `80` |
| Target port | `8080` (container port) |
| Port name | `http` |
| Protocol | `TCP` |

---

## 5. Security Requirements

### 5.1 No Shared Databases

Each microservice **must** own its own data store. The monolith's shared SQLite database must be split so each service has an independent database. No cross-service database access is permitted.

### 5.2 Network Isolation

- All namespaces start with **default-deny** network policies
- Services must explicitly declare their ingress and egress rules
- Cross-namespace communication must be declared in the service's `NetworkPolicy`

### 5.3 Container Security

- Use **minimal base images** (Alpine variants preferred, e.g., `mcr.microsoft.com/dotnet/aspnet:8.0-alpine`)
- Containers listen on port **8080** (non-privileged port)
- Do not run containers as root unless absolutely necessary

### 5.4 Image Scanning

ECR repositories have **scan-on-push** enabled. All images are automatically scanned for vulnerabilities when pushed.

### 5.5 Secret Management

- Sensitive configuration (connection strings, API keys) should use Kubernetes Secrets or external secret managers
- Do not hardcode secrets in `values.yaml`; use environment variable references

### 5.6 RBAC and ServiceAccounts

The platform does not currently provision per-service RBAC roles or ServiceAccounts. Services use the default ServiceAccount in their namespace. If your service requires specific API server permissions:
- Create a dedicated `ServiceAccount` in your Helm chart
- Define a `Role` and `RoleBinding` scoped to your namespace
- Reference the ServiceAccount in your Deployment's `spec.template.spec.serviceAccountName`

---

## 6. Observability Requirements

### 6.1 Health Check Endpoints

Every service **must** expose an HTTP health check endpoint:

| Probe | Path | Port | Initial Delay | Period |
|-------|------|------|---------------|--------|
| **Liveness** | `/health` | `http` (8080) | `15s` | `20s` |
| **Readiness** | `/health` | `http` (8080) | `5s` | `10s` |

Deployment template:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 15
  periodSeconds: 20
readinessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 5
  periodSeconds: 10
```

> **Recommendation:** Consider adding a **startupProbe** for services with longer initialization times to prevent premature liveness probe failures.

### 6.2 Prometheus Metrics

Every service **must** expose a Prometheus-compatible metrics endpoint:

| Setting | Standard Value |
|---------|---------------|
| Metrics path | `/metrics` |
| Metrics port | `8080` (same as app port) |
| Scrape interval | `30s` |
| Enabled by default | `true` |

A `ServiceMonitor` resource (Prometheus Operator CRD) must be included:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "<chart>.fullname" . }}
  labels:
    {{- include "<chart>.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      {{- include "<chart>.selectorLabels" . | nindent 6 }}
  endpoints:
    - port: http
      path: {{ .Values.monitoring.path }}
      interval: 30s
```

`values.yaml` defaults:

```yaml
monitoring:
  enabled: true
  path: /metrics
  port: 8080
```

### 6.3 Logging Conventions

- Write logs to **stdout/stderr** (Kubernetes collects them automatically)
- Use structured JSON logging where possible
- Include correlation IDs for distributed tracing across microservices

---

## 7. Container Image and CI/CD Requirements

### 7.1 ECR Repository

Each service gets a dedicated ECR repository provisioned by the platform team. The naming convention is:

```
workshop/<service-name>
```

Examples: `workshop/order-service`, `workshop/product-service`, `workshop/customer-service`

ECR registry: `599083837640.dkr.ecr.us-east-1.amazonaws.com`

Lifecycle policies (platform-enforced):
- Keep last 10 tagged images (tags prefixed with `v` or `release`)
- Remove untagged images after 7 days

### 7.2 Image Tagging Convention

| Tag | Usage |
|-----|-------|
| `<git-sha>` | Immutable per-commit tag (used in CI) |
| `latest` | Rolling tag pointing to latest main build |
| `dev-latest` | Dev environment override |
| `staging-latest` | Staging environment override |

### 7.3 Dockerfile Conventions

- Multi-stage build
- Final image uses Alpine variant for minimal size
- Expose port `8080`
- Set `ASPNETCORE_URLS=http://+:8080` (for .NET services)
- Use `ENTRYPOINT`, not `CMD`

### 7.4 CI/CD Pipeline (GitHub Actions)

Each service needs a `ci/build-push.yaml` workflow that:

1. Triggers on push/PR to `main`
2. Checks out both the app code repo and the IaC repo
3. Authenticates to AWS via OIDC (`role-to-assume`)
4. Logs in to ECR
5. Builds and pushes the Docker image tagged with `${{ github.sha }}` and `latest`
6. Runs tests

### 7.5 Image Pull Policy

| Environment | Pull Policy |
|-------------|-------------|
| Default / Production | `IfNotPresent` |
| Dev (optional) | `Always` (if using `latest` tag) |

---

## 8. ArgoCD GitOps Deployment

### 8.1 ArgoCD Application Manifest

Each service needs an ArgoCD `Application` manifest per environment:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <service-name>-<env>          # e.g. order-service-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/Cognition-Partner-Workshops/app_dotnet-angular-monolith-iac.git
    targetRevision: main
    path: helm/<service-name>
    helm:
      valueFiles:
        - values.yaml
        - values-<env>.yaml           # e.g. values-dev.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: decomposition-<env>     # e.g. decomposition-dev
  syncPolicy:
    automated:
      prune: true                      # Remove resources no longer in Git
      selfHeal: true                   # Revert manual cluster changes
    syncOptions:
      - CreateNamespace=true
```

### 8.2 Target Namespaces

| Environment | Namespace |
|-------------|-----------|
| Dev | `decomposition-dev` |
| Staging | `decomposition-staging` |
| Production | `decomposition-prod` |

### 8.3 Values File Layering

```
values.yaml          # Base defaults (all environments)
values-dev.yaml      # Dev overrides (lower resources, dev image tag, no persistence)
values-staging.yaml  # Staging overrides (HPA enabled, higher replicas)
```

ArgoCD applies them in order; later files override earlier ones.

---

## 9. Platform vs. Microservice Responsibility Matrix

| Resource / Concern | Provisioned By | Repo | Notes |
|--------------------|----------------|------|-------|
| **EKS Cluster** | Platform | `platform-engineering-shared-services` | VPC, node groups, IAM |
| **Namespace** | Platform | `platform-engineering-shared-services` | CDK `K8sNamespaces` construct |
| **ResourceQuota** | Platform | `platform-engineering-shared-services` | Per-namespace CPU/memory/pod limits |
| **LimitRange** | Platform | `platform-engineering-shared-services` | Default container resource specs |
| **NetworkPolicy (default-deny)** | Platform | `platform-engineering-shared-services` | `k8s/network-policies/default-deny.yaml` |
| **NetworkPolicy (allow-dns)** | Platform | `platform-engineering-shared-services` | DNS egress for all pods |
| **NetworkPolicy (allow-ingress)** | Platform | `platform-engineering-shared-services` | Traffic from ingress-nginx |
| **NetworkPolicy (allow-prometheus)** | Platform | `platform-engineering-shared-services` | Scraping from monitoring namespace |
| **Ingress Controller (NGINX)** | Platform | `platform-engineering-shared-services` | `helm-releases/ingress-nginx/` |
| **cert-manager + ClusterIssuers** | Platform | `platform-engineering-shared-services` | `letsencrypt-staging` and `letsencrypt-prod` |
| **Prometheus + Grafana** | Platform | `platform-engineering-shared-services` | `helm-releases/monitoring/` |
| **ArgoCD** | Platform | `platform-engineering-shared-services` | `helm-releases/argocd/` |
| **ExternalDNS** | Platform | `platform-engineering-shared-services` | Automatic Route 53 DNS records |
| **ECR Repositories** | Platform | `platform-engineering-shared-services` | CDK `EcrRepositories` construct |
| | | | |
| **Deployment** | Microservice | `app_dotnet-angular-monolith-iac` | App workload definition |
| **Service** | Microservice | `app_dotnet-angular-monolith-iac` | ClusterIP service |
| **Ingress** | Microservice | `app_dotnet-angular-monolith-iac` | Host-based routing rules |
| **NetworkPolicy (app-specific)** | Microservice | `app_dotnet-angular-monolith-iac` | Extends base policies with app egress |
| **ServiceMonitor** | Microservice | `app_dotnet-angular-monolith-iac` | Prometheus scrape config |
| **HPA** | Microservice | `app_dotnet-angular-monolith-iac` | Autoscaling rules |
| **ArgoCD Application** | Microservice | `app_dotnet-angular-monolith-iac` | GitOps deployment manifest |
| **Dockerfile** | Microservice | `app_dotnet-angular-monolith-iac` | Container image build |
| **CI/CD Pipeline** | Microservice | `app_dotnet-angular-monolith-iac` | GitHub Actions workflow |
| **Health endpoints** | Microservice | App source code | `/health` endpoint in app code |
| **Metrics endpoint** | Microservice | App source code | `/metrics` Prometheus endpoint in app code |

---

## 10. Helm Chart Scaffold Reference

When creating a new microservice Helm chart, replicate this directory structure:

```
helm/<service-name>/
  Chart.yaml
  values.yaml
  values-dev.yaml
  values-staging.yaml
  templates/
    _helpers.tpl
    deployment.yaml
    service.yaml
    ingress.yaml
    networkpolicy.yaml
    servicemonitor.yaml
    hpa.yaml
```

### 10.1 Chart.yaml

```yaml
apiVersion: v2
name: <service-name>
description: Helm chart for the <ServiceName> microservice
type: application
version: 0.1.0
appVersion: "1.0.0"
```

### 10.2 `_helpers.tpl`

Replace `ordermanager` with your service name in all template definitions:

```
{{- define "<service>.name" -}}
{{- define "<service>.fullname" -}}
{{- define "<service>.labels" -}}
{{- define "<service>.selectorLabels" -}}
```

### 10.3 Minimum `values.yaml`

```yaml
replicaCount: 1

image:
  repository: 599083837640.dkr.ecr.us-east-1.amazonaws.com/workshop/<service-name>
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80
  targetPort: 8080

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-staging
  hosts:
    - host: <service-name>.workshop.local
      paths:
        - path: /
          pathType: Prefix

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 3
  targetCPUUtilizationPercentage: 80

env: []

monitoring:
  enabled: true
  path: /metrics
  port: 8080
```

---

## Quick-Start Checklist for a New Microservice

- [ ] Platform team has added ECR repository to `platform-engineering-shared-services` CDK config
- [ ] Platform team has confirmed namespace exists (`decomposition-dev`, `decomposition-staging`)
- [ ] Created Helm chart under `helm/<service-name>/` with all required templates
- [ ] `_helpers.tpl` defines `name`, `fullname`, `labels`, and `selectorLabels` helpers
- [ ] Deployment includes liveness probe (`/health`, initial delay 15s, period 20s)
- [ ] Deployment includes readiness probe (`/health`, initial delay 5s, period 10s)
- [ ] Deployment specifies explicit resource requests and limits
- [ ] Service is type `ClusterIP` on port 80, targeting container port 8080
- [ ] Ingress uses `ingressClassName: nginx` with `cert-manager.io/cluster-issuer` annotation
- [ ] NetworkPolicy allows ingress from `ingress-nginx` and `monitoring` namespaces only
- [ ] NetworkPolicy allows egress for DNS (53) and HTTPS (443) plus service-specific dependencies
- [ ] ServiceMonitor is configured for `/metrics` endpoint with 30s scrape interval
- [ ] HPA template exists (gated by `autoscaling.enabled`)
- [ ] `values.yaml`, `values-dev.yaml`, and `values-staging.yaml` created with appropriate overrides
- [ ] ArgoCD Application manifests created under `argocd/` for each environment
- [ ] Dockerfile follows multi-stage build pattern, exposes port 8080, uses Alpine base
- [ ] CI/CD pipeline (`ci/build-push.yaml`) builds, tests, and pushes to ECR
- [ ] Application code exposes `/health` and `/metrics` HTTP endpoints
- [ ] Service has its own independent database (no shared DB)
- [ ] Total resource usage fits within namespace quota (requests.cpu: 2, requests.memory: 4Gi)
