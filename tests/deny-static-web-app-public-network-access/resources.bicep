param location string = resourceGroup().location
param tags object = {}

// Set to true when deploying BEFORE policy assignment to set TC4 (existing noncompliant resource).
// Keep false when deploying AFTER policy assignment — an enabled resource will be blocked (TC1/TC5).
param includeNonCompliant bool = false

// TC2: new compliant resource — explicitly disabled. Must pass under deny and audit.
module tc2 '../modules/static-web-app.bicep' = {
  name: 'tc2-compliant-disabled'
  params: {
    name: 'swa-tc2-compliant-disabled'
    location: location
    publicNetworkAccess: 'Disabled'
    tags: union(tags, { testCase: 'TC2' })
  }
}

// TC3: noncompliant resource — publicNetworkAccess absent. Caught by notEquals: "Disabled"
// Deploy BEFORE policy assignment to verify compliance scan catches implicit public access.
module tc3 '../modules/static-web-app.bicep' = if (includeNonCompliant) {
  name: 'tc3-noncompliant-default'
  params: {
    name: 'swa-tc3-noncompliant-default'
    location: location
    publicNetworkAccess: ''
    tags: union(tags, { testCase: 'TC3' })
  }
}

// TC4: noncompliant resource — explicitly enabled.
// Must exist BEFORE policy assignment to test compliance scan. 
// Re-deploying after assignment verifies TC1 (new Enabled blocked) and TC6 (remediation) when switched to "Disabled".
module tc4 '../modules/static-web-app.bicep' = if (includeNonCompliant) {
  name: 'tc4-noncompliant-existing'
  params: {
    name: 'swa-tc4-noncompliant-existing'
    location: location
    publicNetworkAccess: 'Enabled'
    tags: union(tags, { testCase: 'TC4' })
  }
}
