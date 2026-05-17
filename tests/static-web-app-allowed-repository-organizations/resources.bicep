param location string = resourceGroup().location
param tags object = {}

@description('GitHub Personal Access Token with repo scope for the disallowed org (TC1).')
@secure()
param disallowedRepositoryToken string

@description('GitHub Personal Access Token with repo scope for the allowed org (TC2).')
@secure()
param allowedRepositoryToken string

@description('Repository URL from a disallowed GitHub org (e.g. https://github.com/unapproved-org/my-repo).')
param disallowedRepoUrl string

@description('Repository URL from an approved GitHub org (e.g. https://github.com/myorg/my-repo).')
param allowedRepoUrl string

@description('Branch to track for both GitHub-connected SWAs.')
param branch string = 'main'

// TC1: non-compliant — SWA connected to a repo outside the approved org(s).
resource stappTc1 'Microsoft.Web/staticSites@2025-03-01' = {
  name: 'stapp-tc1-disallowed-org'
  location: location
  sku: { name: 'Standard', tier: 'Standard' }
  tags: union(tags, { testCase: 'TC1' })
  properties: {
    repositoryUrl: disallowedRepoUrl
    branch: branch
    repositoryToken: disallowedRepositoryToken
  }
}

// TC2: compliant — SWA connected to a repo inside an approved org.
resource stappTc2 'Microsoft.Web/staticSites@2025-03-01' = {
  name: 'stapp-tc2-allowed-org'
  location: location
  sku: { name: 'Standard', tier: 'Standard' }
  tags: union(tags, { testCase: 'TC2' })
  properties: {
    repositoryUrl: allowedRepoUrl
    branch: branch
    repositoryToken: allowedRepositoryToken
  }
}

// TC3: exempt — SWA with no repositoryUrl (e.g. deployed via CI/CD without a GitHub integration).
// The policy's repositoryUrl exists/notEquals conditions exclude this resource entirely.
module tc3 '../modules/static-web-app.bicep' = {
  name: 'tc3-no-repo-url'
  params: {
    name: 'stapp-tc3-no-repo-url'
    location: location
    tags: union(tags, { testCase: 'TC3' })
  }
}
