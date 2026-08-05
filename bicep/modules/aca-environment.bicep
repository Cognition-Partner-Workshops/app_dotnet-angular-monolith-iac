// ─────────────────────────────────────────────────────────────────────────────
// Azure Container Apps Environment
//
// Azure equivalent of the shared-services EKS compute plane. Translates the
// Terraform `networking` (VPC/subnets) and `eks-cluster` (managed node groups)
// modules into a VNet-injected Container Apps managed environment backed by a
// Log Analytics workspace (the observability plane that replaced Prometheus).
// ─────────────────────────────────────────────────────────────────────────────

@description('Environment name (dev, staging, prod).')
param environment string

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Name of the Container Apps managed environment.')
param managedEnvironmentName string

@description('Name of the VNet that hosts the environment (maps to the EKS VPC).')
param vnetName string

@description('CIDR for the VNet (maps to Terraform vpc_cidr).')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('CIDR for the Container Apps infrastructure subnet (maps to EKS private subnets). Must be at least /23.')
param infrastructureSubnetPrefix string = '10.0.0.0/23'

@description('Log Analytics workspace name (replaces the Prometheus/Grafana stack).')
param logAnalyticsName string

@description('Deploy the environment across availability zones (parity with multi-AZ EKS node groups).')
param zoneRedundant bool = false

@description('Tags applied to every resource.')
param tags object = {}

// Namespace-style environment label (parity with the EKS `platform/environment` namespace label).
var resourceTags = union(tags, {
  'platform-environment': environment
})

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: resourceTags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// VNet + infrastructure subnet — the ACA equivalent of the EKS VPC and the
// private subnets that hosted the managed node groups.
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: resourceTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'aca-infrastructure'
        properties: {
          addressPrefix: infrastructureSubnetPrefix
          delegations: [
            {
              name: 'aca-delegation'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
    ]
  }
}

resource managedEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: managedEnvironmentName
  location: location
  tags: resourceTags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: vnet.properties.subnets[0].id
      internal: false
    }
    zoneRedundant: zoneRedundant
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}

@description('Resource ID of the Container Apps managed environment.')
output managedEnvironmentId string = managedEnvironment.id

@description('Default domain of the managed environment.')
output defaultDomain string = managedEnvironment.properties.defaultDomain

@description('Static outbound/inbound IP of the managed environment.')
output staticIp string = managedEnvironment.properties.staticIp

@description('Resource ID of the Log Analytics workspace.')
output logAnalyticsWorkspaceId string = logAnalytics.id
