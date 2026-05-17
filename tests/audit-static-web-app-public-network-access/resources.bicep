param location string = resourceGroup().location
param tags object = {}

// Set to true when deploying BEFORE policy assignment to seed TC4 (existing noncompliant resource).
// Keep false when deploying AFTER policy assignment — noncompliant Standard resources will be blocked (TC1/TC5).
param includeNonCompliant bool = false

// TC2: compliant resource — Standard SKU, explicitly disabled. Must pass under Deny and Audit.
module tc2 '../modules/static-web-app.bicep' = {
  name: 'tc2-compliant-disabled'
  params: {
    name: 'stapp-tc2-compliant-disabled'
    location: location
    skuName: 'Standard'
    publicNetworkAccess: 'Disabled'
    tags: union(tags, { testCase: 'TC2' })
  }
}

// TC3: noncompliant resource — Standard SKU, publicNetworkAccess absent. Caught by notEquals: "Disabled".
// Deploy BEFORE policy assignment to verify compliance scan catches implicit public access.
module tc3 '../modules/static-web-app.bicep' = if (includeNonCompliant) {
  name: 'tc3-noncompliant-default'
  params: {
    name: 'stapp-tc3-noncompliant-default'
    location: location
    skuName: 'Standard'
    publicNetworkAccess: ''
    tags: union(tags, { testCase: 'TC3' })
  }
}

// TC4: noncompliant resource — Standard SKU, explicitly enabled.
// Must exist BEFORE policy assignment to test compliance scan.
// Re-deploying after assignment verifies TC1 (new Enabled blocked) and TC6 (remediation).
module tc4 '../modules/static-web-app.bicep' = if (includeNonCompliant) {
  name: 'tc4-noncompliant-existing'
  params: {
    name: 'stapp-tc4-noncompliant-existing'
    location: location
    skuName: 'Standard'
    publicNetworkAccess: 'Enabled'
    tags: union(tags, { testCase: 'TC4' })
  }
}

// TC5: Free-tier resource — should NOT be flagged (policy is scoped to Standard only).
module tc5 '../modules/static-web-app.bicep' = {
  name: 'tc5-free-tier-exempt'
  params: {
    name: 'stapp-tc5-free-tier-exempt'
    location: location
    skuName: 'Free'
    publicNetworkAccess: 'Enabled'
    tags: union(tags, { testCase: 'TC5' })
  }
}
