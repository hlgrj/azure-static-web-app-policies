param policyDefinitionId string
param effect string
param assignmentName string

resource policyAssignment 'Microsoft.Authorization/policyAssignments@2025-11-01' = {
  name: assignmentName
  properties: {
    displayName: 'Deny Static Web Apps with public network access enabled'
    policyDefinitionId: policyDefinitionId
    parameters: {
      effect: {
        value: effect
      }
    }
  }
}

output policyAssignmentId string = policyAssignment.id
