using '../platform.bicep'

param environment = 'dev'
param registryName = 'workshopordermanagerdev'
param keyVaultName = 'kv-ordermgr-dev'
param vnetAddressPrefix = '10.0.0.0/16'
param infrastructureSubnetPrefix = '10.0.0.0/23'
param zoneRedundant = false
param domainName = ''
// Seed Key Vault secrets out-of-band (e.g. `az keyvault secret set`) or pass
// them here via a secure parameter file; never commit secret values.
param keyVaultSecrets = {}
