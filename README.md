# Custom Azure Policies

Some custom azure policy definitions with bicep-based test infrastructure.

## Repository structure

```
definitions/          Policy definition JSON files (one per policy)
tests/
  modules/            Reusable Bicep modules for deploying test resources
  <policy-name>/      Per-policy test folder
    resources.bicep   Deploys test resources for the policy scenarios
    policy.bicep      Deploys the policy definition and assignment (subscription scope)
    TEST-CASES.md     Test cases and step-by-step test sequence
```

## Policies

### [Deny Static Web Apps with public network access enabled](definitions/deny-static-web-app-public-network-access.json)

**Resource type:** `Microsoft.Web/staticSites`  
**Effects:** `Deny` (default), `Audit`, `Disabled`  
**Category:** App Service

Denies creation or update of Azure Static Web Apps unless `publicNetworkAccess` is explicitly set to `Disabled`. Resources that omit the property are also denied.

## Testing

Each policy has a dedicated folder under `tests/` with Bicep deployments and a test guide.

The general test flow is:

1. Deploy test resources **before** policy assignment (`includeNonCompliant=true`) to seed pre-existing non-compliant resources.
2. Assign the policy in **Audit** mode and verify the compliance scan catches the expected resources.
3. Switch the policy to **Deny** mode and verify that non-compliant deployments are blocked while compliant ones succeed.
4. Verify remediation by updating a non-compliant resource to `Disabled`.

See the `TEST-CASES.md` in each test folder for the full test case table and exact commands.

### Prerequisites

- Azure CLI (`az`) with an active login
- Contributor and Resource Policy Contributor rights on the target subscription/resource group
