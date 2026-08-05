// ─────────────────────────────────────────────────────────────────────────────
// Azure Key Vault
//
// Azure equivalent of AWS Secrets Manager. Application secrets (e.g. the
// database connection string that was previously an inline Helm env value) live
// here and are surfaced to the Container App via Key Vault references resolved
// with the app's managed identity — no secret material is stored in Git or in
// the container spec.
// ─────────────────────────────────────────────────────────────────────────────

@description('Globally unique Key Vault name (3-24 chars).')
param vaultName string

@description('Azure region for the vault.')
param location string = resourceGroup().location

@description('Azure AD tenant ID that backs RBAC on the vault.')
param tenantId string = subscription().tenantId

@description('Secrets to seed into the vault. Values are @secure and never rendered into templates.')
@secure()
param secrets object = {}

@description('Tags applied to the vault.')
param tags object = {}

resource vault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: vaultName
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    // RBAC (not access policies) — the Container App identity is granted the
    // "Key Vault Secrets User" role in app.bicep.
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: true
    publicNetworkAccess: 'Enabled'
  }
}

resource vaultSecrets 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = [
  for name in items(secrets): {
    parent: vault
    name: name.key
    properties: {
      value: name.value
    }
  }
]

@description('URI of the Key Vault (e.g. https://kv-name.vault.azure.net/).')
output vaultUri string = vault.properties.vaultUri

@description('Resource ID of the Key Vault.')
output vaultId string = vault.id

@description('Name of the Key Vault.')
output vaultName string = vault.name
