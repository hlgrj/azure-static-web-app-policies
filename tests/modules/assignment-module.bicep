param policyDefinitionId string
param effect string
param assignmentName string
param displayName string

resource policyAssignment 'Microsoft.Authorization/policyAssignments@2025-11-01' = {
  name: assignmentName
  properties: {
    displayName: displayName
    policyDefinitionId: policyDefinitionId
    parameters: {
      effect: {
        value: effect
      }
    }
  }
}

output policyAssignmentId string = policyAssignment.id
