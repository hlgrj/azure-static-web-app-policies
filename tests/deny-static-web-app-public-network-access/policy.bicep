targetScope = 'subscription'

@description('Resource group to scope the policy assignment to.')
param testResourceGroupName string

@allowed(['Audit', 'Deny', 'Disabled'])
param effect string = 'Deny'

param definitionName string = 'deny-static-web-app-public-network-access'

var policyDefinitionJson = loadJsonContent('../../definitions/deny-static-web-app-public-network-access.json')

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
    assignmentName: 'deny-static-web-app-public-network-access'
    policyDefinitionId: policyDefinition.id
    displayName: policyDefinitionJson.displayName
    effect: effect
  }
}

output policyDefinitionId string = policyDefinition.id
output policyAssignmentId string = policyAssignment.outputs.policyAssignmentId
