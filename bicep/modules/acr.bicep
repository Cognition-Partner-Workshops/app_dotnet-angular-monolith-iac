// ─────────────────────────────────────────────────────────────────────────────
// Azure Container Registry
//
// Azure equivalent of the Terraform `ecr` module. ECR created one repository per
// microservice; ACR is a single registry that holds all repositories as image
// paths (e.g. workshop/ordermanager). Scan-on-push maps to Microsoft Defender
// for Containers, and the ECR untagged-image lifecycle rule maps to the ACR
// retention policy (both Premium-tier features).
// ─────────────────────────────────────────────────────────────────────────────

@description('Globally unique ACR name (alphanumeric, 5-50 chars).')
param registryName string

@description('Azure region for the registry.')
param location string = resourceGroup().location

@description('Registry SKU. Premium is required for retention policies and geo-replication.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param sku string = 'Premium'

@description('Days to retain untagged manifests (maps to the ECR untagged-image lifecycle rule).')
param untaggedRetentionDays int = 7

@description('Tags applied to the registry.')
param tags object = {}

resource registry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: registryName
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    // Pulls use managed identity (AcrPull) rather than a static admin user.
    adminUserEnabled: false
    policies: {
      retentionPolicy: sku == 'Premium' ? {
        status: 'enabled'
        days: untaggedRetentionDays
      } : null
    }
  }
}

@description('Login server hostname (e.g. workshopordermanager.azurecr.io).')
output loginServer string = registry.properties.loginServer

@description('Resource ID of the registry.')
output registryId string = registry.id

@description('Name of the registry.')
output registryName string = registry.name
