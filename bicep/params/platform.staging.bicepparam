using '../platform.bicep'

param environment = 'staging'
param registryName = 'workshopordermanagerstg'
param keyVaultName = 'kv-ordermgr-stg'
param vnetAddressPrefix = '10.1.0.0/16'
param infrastructureSubnetPrefix = '10.1.0.0/23'
param zoneRedundant = true
param domainName = ''
param keyVaultSecrets = {}
