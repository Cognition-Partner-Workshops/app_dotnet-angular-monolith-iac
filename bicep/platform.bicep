// ─────────────────────────────────────────────────────────────────────────────
// Shared Platform (Azure)
//
// Azure equivalent of the shared-services Terraform under
// `platform-engineering-shared-services/terraform/environments/*`. Deploys the
// Container Apps environment (EKS + VPC), a shared ACR (ECR), a Key Vault
// (Secrets Manager), and an optional Azure DNS zone (Route 53).
//
// In the real platform/app IaC split this would live in the platform repo; it
// is included here to make the AWS→Azure translation self-contained.
//
// Deploy:
//   az deployment group create -g <rg> \
//     -f bicep/platform.bicep -p bicep/params/platform.dev.bicepparam
// ─────────────────────────────────────────────────────────────────────────────

targetScope = 'resourceGroup'

@description('Environment name (dev, staging, prod).')
param environment string

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Globally unique ACR name. Shared across environments (parity with the single shared ECR registry).')
param registryName string = 'workshopordermanager'

@description('Create the shared ACR in this deployment. Set false for environments that reuse a registry created by another environment stack.')
param deployRegistry bool = true

@description('Globally unique Key Vault name (maps to Secrets Manager).')
param keyVaultName string

@description('CIDR for the environment VNet (maps to Terraform vpc_cidr).')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('CIDR for the Container Apps infrastructure subnet (maps to EKS private subnets).')
param infrastructureSubnetPrefix string = '10.0.0.0/23'

@description('Deploy the environment zone-redundant (parity with multi-AZ node groups).')
param zoneRedundant bool = false

@description('Optional DNS zone name (maps to the Route 53 hosted zone). Empty = no zone.')
param domainName string = ''

@description('Secrets to seed into Key Vault. Values are @secure.')
@secure()
param keyVaultSecrets object = {}

var tags = {
  Environment: environment
  ManagedBy: 'bicep'
  Project: 'workshop-platform'
}

module acaEnvironment 'modules/aca-environment.bicep' = {
  name: 'aca-environment'
  params: {
    environment: environment
    location: location
    managedEnvironmentName: 'workshop-${environment}'
    vnetName: 'workshop-${environment}'
    vnetAddressPrefix: vnetAddressPrefix
    infrastructureSubnetPrefix: infrastructureSubnetPrefix
    logAnalyticsName: 'workshop-${environment}-logs'
    zoneRedundant: zoneRedundant
    tags: tags
  }
}

module acr 'modules/acr.bicep' = if (deployRegistry) {
  name: 'acr'
  params: {
    registryName: registryName
    location: location
    sku: 'Premium'
    tags: tags
  }
}

module keyVault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  params: {
    vaultName: keyVaultName
    location: location
    secrets: keyVaultSecrets
    tags: tags
  }
}

module dns 'modules/dns.bicep' = if (!empty(domainName)) {
  name: 'dns'
  params: {
    domainName: domainName
    tags: tags
  }
}

@description('Resource ID of the Container Apps managed environment.')
output managedEnvironmentId string = acaEnvironment.outputs.managedEnvironmentId

@description('Default domain of the managed environment.')
output managedEnvironmentDefaultDomain string = acaEnvironment.outputs.defaultDomain

@description('ACR login server.')
output acrLoginServer string = deployRegistry ? acr!.outputs.loginServer : '${toLower(registryName)}.azurecr.io'

@description('Key Vault URI.')
output keyVaultUri string = keyVault.outputs.vaultUri
