param location string = resourceGroup().location
param tags object = {}

// Shared VNet required for the private endpoint in TC2.
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-stapp-pe-test'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        name: 'snet-pe'
        properties: {
          addressPrefix: '10.0.0.0/24'
          // Required to allow private endpoint NICs in the subnet.
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// TC1: non-compliant resource — Standard SKU with no private endpoint.
module tc1 '../modules/static-web-app.bicep' = {
  name: 'tc1-noncompliant-no-pe'
  params: {
    name: 'stapp-tc1-noncompliant-no-pe'
    location: location
    skuName: 'Standard'
    tags: union(tags, { testCase: 'TC1' })
  }
}

// TC2: compliant resource — Standard SKU with a private endpoint connection.
module tc2 '../modules/static-web-app.bicep' = {
  name: 'tc2-compliant-with-pe'
  params: {
    name: 'stapp-tc2-compliant-with-pe'
    location: location
    skuName: 'Standard'
    tags: union(tags, { testCase: 'TC2' })
  }
}

resource tc2PrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-stapp-tc2'
  location: location
  tags: union(tags, { testCase: 'TC2' })
  properties: {
    subnet: {
      id: '${vnet.id}/subnets/snet-pe'
    }
    privateLinkServiceConnections: [
      {
        name: 'conn-stapp-tc2'
        properties: {
          privateLinkServiceId: tc2.outputs.id
          // 'staticSites' is the private link sub-resource type for Static Web Apps.
          groupIds: ['staticSites']
        }
      }
    ]
  }
}

// TC3: Free-tier resource — should NOT be flagged (policy is scoped to Standard only).
module tc3 '../modules/static-web-app.bicep' = {
  name: 'tc3-free-tier-exempt'
  params: {
    name: 'stapp-tc3-free-tier-exempt'
    location: location
    skuName: 'Free'
    tags: union(tags, { testCase: 'TC3' })
  }
}
