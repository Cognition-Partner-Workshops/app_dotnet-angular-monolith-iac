# OrderManager IaC — Azure (Bicep)

Azure delivery for the OrderManager monolith, migrated from AWS. The application
code is unchanged; only the packaging, deployment target, and shared platform
infrastructure moved from AWS to Azure.

| Layer | Before (AWS) | After (Azure) |
|-------|--------------|---------------|
| Image build/push | GitHub Actions → ECR | GitHub Actions → ACR (`ci/build-push.yaml`) |
| App deploy | Helm chart + ArgoCD on EKS | Container App (`bicep/app.bicep`) |
| Shared compute | EKS cluster (Terraform) | Container Apps environment (`bicep/platform.bicep`) |
| Registry | ECR (Terraform) | ACR (`bicep/modules/acr.bicep`) |
| Secrets | Secrets Manager | Key Vault (`bicep/modules/keyvault.bicep`) |
| DNS | Route 53 | Azure DNS (`bicep/modules/dns.bicep`) |

## Layout

```
bicep/
├── platform.bicep            # shared platform: ACA env + ACR + Key Vault + DNS
├── app.bicep                 # OrderManager Container App + identity + role grants
├── modules/
│   ├── aca-environment.bicep # VNet + Log Analytics + managed environment (EKS)
│   ├── acr.bicep             # Azure Container Registry (ECR)
│   ├── keyvault.bicep        # Key Vault (Secrets Manager)
│   ├── dns.bicep             # Azure DNS zone (Route 53)
│   └── containerapp.bicep    # Container App (Helm chart)
└── params/
    ├── platform.{dev,staging}.bicepparam
    └── app.{dev,staging}.bicepparam
```

`platform.bicep` mirrors the shared-services Terraform (owned by the platform
team); `app.bicep` mirrors the Helm chart + ArgoCD Application (owned by the app
team). They are kept in one repo here to make the AWS→Azure translation
self-contained.

The ACR is a **single shared registry** (`workshopordermanager`) across all
environments — parity with the single shared ECR the Helm values pointed at, and
the same registry name the CI pipeline pushes to. The dev platform stack creates
it (`deployRegistry = true`); other environments reuse it (`deployRegistry =
false`) and their app stacks reference it via `registryResourceGroup`.

## Deploy

```bash
RG=rg-ordermanager-dev
az group create -n "$RG" -l eastus

# 1. Shared platform (ACA environment, ACR, Key Vault)
az deployment group create -g "$RG" \
  -f bicep/platform.bicep -p bicep/params/platform.dev.bicepparam

# 2. Seed the DB connection string into Key Vault (replaces the inline Helm env value).
#    Container-relative path: the SQLite file lives in the container filesystem and is
#    ephemeral (lost on restart/scale, and per-replica when minReplicas > 1). Point this
#    at a mounted path only once an Azure Files volume is added — see Persistence below.
az keyvault secret set --vault-name kv-ordermgr-dev \
  --name ordermanager-db-connectionstring \
  --value 'Data Source=ordermanager.db'

# 3. App (Container App) — pass the managedEnvironmentId output from step 1
az deployment group create -g "$RG" \
  -f bicep/app.bicep -p bicep/params/app.dev.bicepparam
```

## Helm value → Container App mapping

| Helm value | Container App |
|------------|---------------|
| `replicaCount` / `autoscaling.minReplicas` | `scale.minReplicas` |
| `autoscaling.maxReplicas` | `scale.maxReplicas` |
| `autoscaling.targetCPUUtilizationPercentage` | KEDA `cpu` scale rule (`Utilization`) |
| `image.repository` / `image.tag` | `template.containers[].image` (ACR) |
| `service.targetPort` | `ingress.targetPort` |
| `ingress.enabled` / `ingress.hosts[].host` | `ingress.external` / `ingress.customDomains` |
| `livenessProbe` / `readinessProbe` (`/health`) | `template.containers[].probes` |
| `resources.limits.cpu/memory` | `template.containers[].resources` |
| `env` (inline) | `template.containers[].env` (`value`) |
| `env` (secret) | Key Vault reference → `secret` + `env.secretRef` |
| `monitoring` / ServiceMonitor | managed environment → Log Analytics |
| `persistence` (PVC) | Azure Files mount on the managed environment* |
| `networkPolicy` | managed environment network isolation* |

\* Not provisioned in this initial cut; see notes in the PR description.

## Persistence

The Helm chart set `persistence.enabled: true` with a `gp2` 1Gi volume, but the
chart shipped **no PVC template and no `volumeMount`** — the value was never
wired up, so `Data Source=/data/ordermanager.db` from `values.yaml` had no
backing volume on EKS either. The Bicep translation does not carry that dead
config forward: the seeded connection string uses a container-relative path, and
the SQLite file is ephemeral.

To make the database durable, add an Azure Files share plus a
`Microsoft.App/managedEnvironments/storages` resource, mount it as a volume in
`modules/containerapp.bicep`, and point the Key Vault secret at the mount path.
Note SQLite over SMB is not safe for concurrent writers, so this also requires
pinning the app to a single replica (or moving to Azure SQL / PostgreSQL).
