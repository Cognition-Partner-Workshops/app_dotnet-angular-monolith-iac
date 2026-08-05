using '../platform.bicep'

param environment = 'staging'
// Reuse the shared registry created by the dev platform stack (ACR names are global).
param registryName = 'workshopordermanager'
param deployRegistry = false
param keyVaultName = 'kv-ordermgr-stg'
param vnetAddressPrefix = '10.1.0.0/16'
param infrastructureSubnetPrefix = '10.1.0.0/23'
param zoneRedundant = true
param domainName = ''
param keyVaultSecrets = {}
