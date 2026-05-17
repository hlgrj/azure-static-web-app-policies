targetScope = 'subscription'

@description('Resource group to scope the policy assignment to.')
param testResourceGroupName string

@allowed(['Audit', 'Disabled'])
param effect string = 'Audit'

param definitionName string = 'static-web-app-custom-domain'

var policyDefinitionJson = loadJsonContent('../../definitions/static-web-app-custom-domain.json')

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
    assignmentName: 'static-web-app-custom-domain'
    policyDefinitionId: policyDefinition.id
    displayName: policyDefinitionJson.displayName
    effect: effect
  }
}

output policyDefinitionId string = policyDefinition.id
output policyAssignmentId string = policyAssignment.outputs.policyAssignmentId
