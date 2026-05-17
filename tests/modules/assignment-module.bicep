param policyDefinitionId string
param effect string
param assignmentName string
param displayName string

@description('Additional policy parameters beyond effect, as a { paramName: { value: ... } } object.')
param additionalParameters object = {}

resource policyAssignment 'Microsoft.Authorization/policyAssignments@2025-11-01' = {
  name: assignmentName
  properties: {
    displayName: displayName
    policyDefinitionId: policyDefinitionId
    parameters: union(additionalParameters, {
      effect: {
        value: effect
      }
    })
  }
}

output policyAssignmentId string = policyAssignment.id
