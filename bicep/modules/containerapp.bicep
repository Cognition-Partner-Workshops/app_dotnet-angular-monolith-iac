// ─────────────────────────────────────────────────────────────────────────────
// OrderManager Container App
//
// Azure Container Apps equivalent of the Helm chart + ArgoCD Application that
// deployed the monolith to EKS. One Container App replaces the Deployment,
// Service, Ingress, HPA, and probes. Helm value mapping:
//
//   replicaCount / autoscaling  -> scale.minReplicas / maxReplicas + rules
//   service.targetPort          -> ingress.targetPort
//   ingress.hosts               -> ingress.external + customDomains
//   liveness/readinessProbe     -> template.containers[].probes (/health)
//   resources.limits            -> template.containers[].resources
//   env (inline)                -> template.containers[].env
//   env (secret)                -> Key Vault references (secretRef)
//   monitoring/ServiceMonitor   -> managed environment Log Analytics
// ─────────────────────────────────────────────────────────────────────────────

@description('Container App name.')
param name string

@description('Azure region.')
param location string = resourceGroup().location

@description('Resource ID of the Container Apps managed environment.')
param managedEnvironmentId string

@description('ACR login server used to pull the image (e.g. workshopordermanager.azurecr.io).')
param registryLoginServer string

@description('Resource ID of the user-assigned managed identity (pre-granted AcrPull + Key Vault Secrets User).')
param userAssignedIdentityId string

@description('Fully qualified container image reference.')
param image string

@description('Container port the app listens on (maps to Helm service.targetPort).')
param targetPort int = 8080

@description('Expose the app to the public internet (maps to Helm ingress.enabled + external LB).')
param externalIngress bool = true

@description('Optional custom domain bound to the ingress (maps to Helm ingress.hosts[].host). Empty = default env domain only.')
param customDomainName string = ''

@description('Minimum replicas (maps to Helm replicaCount / autoscaling.minReplicas).')
param minReplicas int = 1

@description('Maximum replicas (maps to Helm autoscaling.maxReplicas).')
param maxReplicas int = 3

@description('Target CPU utilization percentage for the KEDA cpu scaler (maps to Helm autoscaling.targetCPUUtilizationPercentage).')
param cpuUtilization int = 80

@description('CPU cores for the container (maps to Helm resources.limits.cpu).')
param cpu string = '0.5'

@description('Memory for the container (maps to Helm resources.limits.memory).')
param memory string = '1Gi'

@description('HTTP health probe path (maps to Helm liveness/readinessProbe.httpGet.path).')
param healthPath string = '/health'

@description('Plain (non-secret) environment variables: array of { name, value }.')
param envVars array = []

@description('Key Vault-backed environment variables (replaces Secrets Manager): array of { secretName, keyVaultUrl, envName }.')
param keyVaultRefs array = []

@description('Tags applied to the Container App.')
param tags object = {}

var plainEnv = [
  for e in envVars: {
    name: e.name
    value: e.value
  }
]

var secretEnv = [
  for s in keyVaultRefs: {
    name: s.envName
    secretRef: s.secretName
  }
]

// Key Vault references resolved with the app's user-assigned identity.
var kvSecrets = [
  for s in keyVaultRefs: {
    name: s.secretName
    keyVaultUrl: s.keyVaultUrl
    identity: userAssignedIdentityId
  }
]

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: managedEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: externalIngress
        targetPort: targetPort
        transport: 'auto'
        allowInsecure: false
        customDomains: empty(customDomainName) ? [] : [
          {
            name: customDomainName
            bindingType: 'SniEnabled'
          }
        ]
      }
      registries: [
        {
          server: registryLoginServer
          identity: userAssignedIdentityId
        }
      ]
      secrets: kvSecrets
    }
    template: {
      containers: [
        {
          name: name
          image: image
          resources: {
            cpu: json(cpu)
            memory: memory
          }
          env: concat(plainEnv, secretEnv)
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: healthPath
                port: targetPort
              }
              initialDelaySeconds: 15
              periodSeconds: 20
            }
            {
              type: 'Readiness'
              httpGet: {
                path: healthPath
                port: targetPort
              }
              initialDelaySeconds: 5
              periodSeconds: 10
            }
          ]
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'cpu-scaling'
            custom: {
              type: 'cpu'
              metadata: {
                type: 'Utilization'
                value: string(cpuUtilization)
              }
            }
          }
        ]
      }
    }
  }
}

@description('Fully qualified default domain of the app.')
output fqdn string = containerApp.properties.configuration.ingress.fqdn

@description('Resource ID of the Container App.')
output containerAppId string = containerApp.id
