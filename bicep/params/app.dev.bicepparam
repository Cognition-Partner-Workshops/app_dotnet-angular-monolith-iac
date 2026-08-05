using '../app.bicep'

param environment = 'dev'
param containerAppName = 'ordermanager'
// Replace with the managedEnvironmentId output from the platform deployment.
param managedEnvironmentId = '/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.App/managedEnvironments/workshop-dev'
param registryName = 'workshopordermanager'
param keyVaultName = 'kv-ordermgr-dev'
param imageRepository = 'workshop/ordermanager'
param imageTag = 'dev-latest'
param minReplicas = 1
param maxReplicas = 3
param cpuUtilization = 80
param cpu = '0.25'
param memory = '0.5Gi'
param customDomainName = ''
param envVars = [
  {
    name: 'ASPNETCORE_ENVIRONMENT'
    value: 'Development'
  }
]
param dbConnectionSecretName = 'ordermanager-db-connectionstring'
