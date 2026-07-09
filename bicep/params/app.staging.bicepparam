using '../app.bicep'

param environment = 'staging'
param containerAppName = 'ordermanager'
// Replace with the managedEnvironmentId output from the platform deployment.
param managedEnvironmentId = '/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.App/managedEnvironments/workshop-staging'
param registryName = 'workshopordermanagerstg'
param keyVaultName = 'kv-ordermgr-stg'
param imageRepository = 'workshop/ordermanager'
param imageTag = 'staging-latest'
param minReplicas = 2
param maxReplicas = 4
param cpuUtilization = 75
param cpu = '0.5'
param memory = '1Gi'
param customDomainName = ''
param envVars = [
  {
    name: 'ASPNETCORE_ENVIRONMENT'
    value: 'Production'
  }
]
param dbConnectionSecretName = 'ordermanager-db-connectionstring'
