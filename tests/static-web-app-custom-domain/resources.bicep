param location string = resourceGroup().location
param tags object = {}

// TC1: non-compliant resource — Standard SKU with no custom domain.
module tc1 '../modules/static-web-app.bicep' = {
  name: 'tc1-noncompliant-no-domain'
  params: {
    name: 'stapp-tc1-noncompliant-no-domain'
    location: location
    skuName: 'Standard'
    tags: union(tags, { testCase: 'TC1' })
  }
}

// TC2: compliant resource — Standard SKU; custom domain must be added out-of-band
// (see TEST-CASES.md Step 1 for the manual DNS validation steps).
module tc2 '../modules/static-web-app.bicep' = {
  name: 'tc2-compliant-with-domain'
  params: {
    name: 'stapp-tc2-compliant-with-domain'
    location: location
    skuName: 'Standard'
    tags: union(tags, { testCase: 'TC2' })
  }
}

// TC3: non-compliant resource — Free SKU with no custom domain.
// Confirms the policy applies to both tiers, not only Standard.
module tc3 '../modules/static-web-app.bicep' = {
  name: 'tc3-noncompliant-free-no-domain'
  params: {
    name: 'stapp-tc3-noncompliant-free-no-domain'
    location: location
    skuName: 'Free'
    tags: union(tags, { testCase: 'TC3' })
  }
}
