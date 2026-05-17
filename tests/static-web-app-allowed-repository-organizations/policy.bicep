targetScope = 'subscription'

@description('Resource group to scope the policy assignment to.')
param testResourceGroupName string

@allowed(['Audit', 'Deny', 'Disabled'])
param effect string = 'Audit'

@description('List of approved GitHub organization names (without the https://github.com/ prefix).')
param allowedOrganizations array

param definitionName string = 'static-web-app-allowed-repository-organizations'

var policyDefinitionJson = loadJsonContent('../../definitions/static-web-app-allowed-repository-organizations.json')

resource policyDefinition 'Microsoft.Authorization/policyDefinitions@2025-11-01' = {
  name: definitionName
  properties: {
    displayName: policyDefinitionJson.displayName
    description: policyDefinitionJson.description
    policyType: 'Custom'
    mode: policyDefinitionJson.mode
    metadata: policyDefinitionJson.metadata
    parameters: policyDefinitionJson.parameters
    policyRule: policyDefinitionJson.policyRule
  }
}

module policyAssignment '../modules/assignment-module.bicep' = {
  name: 'policyAssignment'
  scope: resourceGroup(subscription().subscriptionId, testResourceGroupName)
  params: {
    assignmentName: 'swa-allowed-repo-orgs'
    policyDefinitionId: policyDefinition.id
    displayName: policyDefinitionJson.displayName
    effect: effect
    additionalParameters: {
      allowedOrganizations: {
        value: allowedOrganizations
      }
    }
  }
}

output policyDefinitionId string = policyDefinition.id
output policyAssignmentId string = policyAssignment.outputs.policyAssignmentId
