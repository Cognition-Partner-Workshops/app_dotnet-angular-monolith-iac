// ─────────────────────────────────────────────────────────────────────────────
// AcrPull role assignment
//
// Grants a principal AcrPull on the shared registry. Deployed as a module so the
// grant can target the registry's resource group even when the app lives in a
// different resource group (the shared ACR mirrors the single shared ECR).
// ─────────────────────────────────────────────────────────────────────────────

@description('Name of the shared ACR in this resource group.')
param registryName string

@description('Principal ID (managed identity) to grant AcrPull.')
param principalId string

var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  name: registryName
}

resource acrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, principalId, acrPullRoleId)
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
