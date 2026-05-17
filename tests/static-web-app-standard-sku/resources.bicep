param location string = resourceGroup().location
param tags object = {}

// Set to true when deploying BEFORE policy assignment to set TC3 (pre-existing Free-tier resource).
// Keep false when deploying AFTER policy assignment — a Free-tier resource will be blocked (TC1/TC5).
param includeNonCompliant bool = false

// TC2: new compliant resource — Standard SKU. Must pass under Deny and Audit.
module tc2 '../modules/static-web-app.bicep' = {
  name: 'tc2-compliant-standard'
  params: {
    name: 'stapp-tc2-compliant-standard'
    location: location
    skuName: 'Standard'
    tags: union(tags, { testCase: 'TC2' })
  }
}

// TC3: noncompliant resource — Free SKU (the ARM default).
// Deploy BEFORE policy assignment to verify the compliance scan catches pre-existing Free-tier resources.
module tc3 '../modules/static-web-app.bicep' = if (includeNonCompliant) {
  name: 'tc3-noncompliant-free'
  params: {
    name: 'stapp-tc3-noncompliant-free'
    location: location
    skuName: 'Free'
    tags: union(tags, { testCase: 'TC3' })
  }
}
