// ─────────────────────────────────────────────────────────────────────────────
// OrderManager App Deployment (Azure)
//
// Azure equivalent of the Helm chart + ArgoCD Application. Provisions the
// user-assigned identity for the app, grants it AcrPull on the shared ACR and
// Key Vault Secrets User on the shared Key Vault, then deploys the Container App
// into the shared managed environment created by platform.bicep.
//
// Deploy:
//   az deployment group create -g <rg> \
//     -f bicep/app.bicep -p bicep/params/app.dev.bicepparam
// ─────────────────────────────────────────────────────────────────────────────

targetScope = 'resourceGroup'

@description('Environment name (dev, staging, prod).')
param environment string

@description('Azure region.')
param location string = resourceGroup().location

@description('Container App name.')
param containerAppName string = 'ordermanager'

@description('Resource ID of the shared Container Apps managed environment (platform output).')
param managedEnvironmentId string

@description('Name of the shared ACR (must exist in this resource group).')
param registryName string

@description('Name of the shared Key Vault (must exist in this resource group).')
param keyVaultName string

@description('Image repository within the registry (maps to Helm image.repository path).')
param imageRepository string = 'workshop/ordermanager'

@description('Image tag (maps to Helm image.tag).')
param imageTag string = 'latest'

@description('Minimum replicas (maps to Helm replicaCount / autoscaling.minReplicas).')
param minReplicas int = 1

@description('Maximum replicas (maps to Helm autoscaling.maxReplicas).')
param maxReplicas int = 3

@description('Target CPU utilization for the scaler (maps to Helm autoscaling.targetCPUUtilizationPercentage).')
param cpuUtilization int = 80

@description('CPU cores (maps to Helm resources.limits.cpu).')
param cpu string = '0.5'

@description('Memory (maps to Helm resources.limits.memory).')
param memory string = '1Gi'

@description('Optional custom domain (maps to Helm ingress.hosts[].host).')
param customDomainName string = ''

@description('Plain environment variables: array of { name, value } (maps to non-secret Helm env).')
param envVars array = [
  {
    name: 'ASPNETCORE_ENVIRONMENT'
    value: 'Production'
  }
]

@description('Name of the Key Vault secret holding the DB connection string (replaces the inline Helm env value / Secrets Manager entry).')
param dbConnectionSecretName string = 'ordermanager-db-connectionstring'

var tags = {
  Environment: environment
  ManagedBy: 'bicep'
  Project: 'workshop-platform'
  Team: 'dotnet-angular-monolith'
}

// Well-known Azure built-in role definition IDs.
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  name: registryName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${containerAppName}-${environment}-id'
  location: location
  tags: tags
}

// AcrPull — the ACA-native replacement for the EKS node IAM role / ECR pull.
resource acrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, identity.id, acrPullRoleId)
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Key Vault Secrets User — lets the app resolve Key Vault references at runtime.
resource keyVaultSecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, identity.id, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

module containerApp 'modules/containerapp.bicep' = {
  name: 'ordermanager-app'
  params: {
    name: containerAppName
    location: location
    managedEnvironmentId: managedEnvironmentId
    registryLoginServer: acr.properties.loginServer
    userAssignedIdentityId: identity.id
    image: '${acr.properties.loginServer}/${imageRepository}:${imageTag}'
    minReplicas: minReplicas
    maxReplicas: maxReplicas
    cpuUtilization: cpuUtilization
    cpu: cpu
    memory: memory
    customDomainName: customDomainName
    envVars: envVars
    keyVaultRefs: [
      {
        secretName: 'connectionstrings-defaultconnection'
        keyVaultUrl: '${keyVault.properties.vaultUri}secrets/${dbConnectionSecretName}'
        envName: 'ConnectionStrings__DefaultConnection'
      }
    ]
    tags: tags
  }
  dependsOn: [
    acrPull
    keyVaultSecretsUser
  ]
}

@description('Public FQDN of the deployed app.')
output appFqdn string = containerApp.outputs.fqdn
