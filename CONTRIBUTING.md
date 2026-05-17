# Contributing

## Adding a new policy

### 1. Name the policy

Use kebab-case describing what the policy governs, not how it responds to violations. The default effect is a configuration detail that can change; the filename should stay stable.

```
<resource-type-abbreviation>-<what-is-governed>.json
```

Examples: `static-web-app-public-network-access.json`, `static-web-app-standard-sku.json`, `static-web-app-private-endpoint.json`

Exception: if the Deny effect is the *only* meaningful option (e.g. naming conventions on immutable fields), a `deny-` prefix is acceptable since it describes a permanent property of the policy, not a default that might change.

Example: `deny-static-web-app-naming-convention.json`

The filename (without `.json`) becomes the folder name under `tests/`, the ARM `policyDefinitions` resource name, and the `policyAssignments` resource name. Keep them consistent.

### 2. Create the definition

Add `definitions/<policy-name>.json` along the lines of this sample structure:

```json
{
  "displayName": "<Human-readable name>",
  "description": "<What the policy blocks or audits, and why.>",
  "mode": "Indexed",
  "metadata": {
    "category": "<Azure Policy category, e.g. App Service, Network, Storage>",
    "version": "1.0.0"
  },
  "parameters": {
    "effect": {
      "type": "String",
      "metadata": {
        "displayName": "Effect",
        "description": "Audit logs a compliance warning without blocking; Deny blocks the request; Disabled turns the policy off."
      },
      "allowedValues": ["Audit", "Deny", "Disabled"],
      "defaultValue": "Deny"
    }
  },
  "policyRule": {
    "if": { ... },
    "then": {
      "effect": "[parameters('effect')]"
    }
  }
}
```

Guidelines:
- `description` should explain the *behaviour* (what is blocked/audited) and the *reason* (why it matters). It should not just restate the `displayName`.
- `mode` is `Indexed` for resource-level policies. Use `All` only if you need to target resource groups or subscriptions.
- If the policy uses `Modify` or `DeployIfNotExists`, add a `roleDefinitionIds` array to the `then` block.
- Bump `metadata.version` on any change to `policyRule` or `parameters`.

### 3. Create the test folder

Create `tests/<policy-name>/` with three files:

#### `policy.bicep`

Deploys the definition and a resource-group-scoped assignment. Use the shared module:

```bicep
targetScope = 'subscription'

@description('Resource group to scope the policy assignment to.')
param testResourceGroupName string

@allowed(['Audit', 'Deny', 'Disabled'])
param effect string = 'Deny'

param definitionName string = '<policy-name>'   // must match the filename slug

var policyDefinitionJson = loadJsonContent('../../definitions/<policy-name>.json')

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
    assignmentName: '<policy-name>'             // must match definitionName
    policyDefinitionId: policyDefinition.id
    displayName: policyDefinitionJson.displayName
    effect: effect
  }
}

output policyDefinitionId string = policyDefinition.id
output policyAssignmentId string = policyAssignment.outputs.policyAssignmentId
```

#### `resources.bicep`

Deploys test resources that cover all test scenarios. Use an `includeNonCompliant` parameter to gate non-compliant resources so they can be deployed before the policy is assigned (to seed pre-existing non-compliant state).

#### `TEST-CASES.md`

Document every scenario the policy should handle. Use the table format from the existing policies. At minimum cover:

| # | Scenario | Timing | Effect=Deny | Effect=Audit |
|---|---|---|---|---|
| TC1 | Non-compliant new resource | Post-assignment | BLOCKED | NonCompliant |
| TC2 | Compliant new resource | Post-assignment | Allowed | Compliant |
| TC3 | Pre-existing non-compliant resource | Pre-assignment | Shows NonCompliant | Shows NonCompliant |

Include the full step-by-step `az` command sequence (see existing `TEST-CASES.md` files for the pattern).

### 4. Update the README

Add a row to the summary table and a `###` section under `## Policies`. Include:
- Link to the definition file
- Resource type
- Allowed effects and default
- Category and version
- A plain-English description

### PR checklist

- [ ] Definition JSON is valid
- [ ] `metadata.version` is set and follows semver
- [ ] `description` explains behaviour and reason, not just the resource
- [ ] Test folder has all three files: `policy.bicep`, `resources.bicep`, `TEST-CASES.md`
- [ ] `definitionName` param default and `assignmentName` param match the filename slug
- [ ] `displayName` in the assignment comes from `policyDefinitionJson.displayName`, not a hardcoded string
- [ ] README summary table and `###` section are updated
