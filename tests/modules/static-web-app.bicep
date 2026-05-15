param name string
param location string = resourceGroup().location

@allowed(['Free', 'Standard'])
param skuName string = 'Free'

// Pass '' to omit the property from the ARM request (tests TC3: absent field != "Enabled")
@allowed(['Enabled', 'Disabled', ''])
param publicNetworkAccess string = ''

param tags object = {}

resource staticSite 'Microsoft.Web/staticSites@2025-03-01' = {
  name: name
  location: location
  sku: {
    name: skuName
    tier: skuName
  }
  tags: tags
  properties: {
    publicNetworkAccess: empty(publicNetworkAccess) ? null : publicNetworkAccess
  }
}

output id string = staticSite.id
output name string = staticSite.name
output defaultHostname string = staticSite.properties.defaultHostname
