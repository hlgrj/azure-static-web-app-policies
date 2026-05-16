param location string = resourceGroup().location
param tags object = {}

// Set to true when deploying BEFORE policy assignment to set TC4 (existing noncompliant resource).
// Keep false when deploying AFTER policy assignment — noncompliant resources will be blocked (TC2/TC3).
param includeNonCompliant bool = false

// TC1: compliant resource — name starts with required 'stapp-' prefix.
module tc1 '../modules/static-web-app.bicep' = {
  name: 'tc1-compliant-stapp-prefix'
  params: {
    name: 'stapp-tc1-compliant'
    location: location
    publicNetworkAccess: 'Disabled'
    tags: union(tags, { testCase: 'TC1' })
  }
}

// TC2: noncompliant resource — no naming prefix at all (ok, basically the same as an incorrect prefix).
module tc2 '../modules/static-web-app.bicep' = if (includeNonCompliant) {
  name: 'tc2-noncompliant-no-prefix'
  params: {
    name: 'tc2-noncompliant-no-prefix'
    location: location
    publicNetworkAccess: 'Disabled'
    tags: union(tags, { testCase: 'TC2' })
  }
}

// TC3: noncompliant resource — uses old 'swa-' abbreviation instead of required 'stapp-'.
module tc3 '../modules/static-web-app.bicep' = if (includeNonCompliant) {
  name: 'tc3-noncompliant-old-prefix'
  params: {
    name: 'swa-tc3-noncompliant'
    location: location
    publicNetworkAccess: 'Disabled'
    tags: union(tags, { testCase: 'TC3' })
  }
}

// TC4: pre-existing noncompliant resource — deployed BEFORE policy assignment to test compliance scan.
// Static Web App names are immutable, so this resource can never be remediated in-place; 
// it would have to be recreated with a compliant name.
module tc4 '../modules/static-web-app.bicep' = if (includeNonCompliant) {
  name: 'tc4-noncompliant-existing'
  params: {
    name: 'tc4-noncompliant-existing'
    location: location
    publicNetworkAccess: 'Disabled'
    tags: union(tags, { testCase: 'TC4' })
  }
}
