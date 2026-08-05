// ─────────────────────────────────────────────────────────────────────────────
// Azure DNS Zone
//
// Azure equivalent of the Terraform `dns` module (Route 53 hosted zone).
// ExternalDNS record automation on EKS is replaced by Container Apps custom
// domain bindings plus optional ExternalDNS-for-Azure integration.
// ─────────────────────────────────────────────────────────────────────────────

@description('DNS zone name (e.g. workshop.example.com).')
param domainName string

@description('Tags applied to the zone.')
param tags object = {}

resource zone 'Microsoft.Network/dnsZones@2023-07-01-preview' = {
  name: domainName
  location: 'global'
  tags: tags
}

@description('Name servers for the delegated zone.')
output nameServers array = zone.properties.nameServers

@description('Name of the DNS zone.')
output zoneName string = zone.name
