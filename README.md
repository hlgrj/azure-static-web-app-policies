# Custom Azure Policies

Custom Azure Policy definitions, with Bicep-based test infrastructure. Each policy ships with a definition JSON, a parameterised test deployment, and a documented test sequence.

See [CONTRIBUTING.md](CONTRIBUTING.md) to add a new policy.

## Policies

| Policy | Resource type | Category | Version | Default effect |
|---|---|---|---|---|
| [Deny public network access](#deny-static-web-apps-with-public-network-access-enabled) | `Microsoft.Web/staticSites` | App Service | 1.2.0 | Deny |
| [Enforce CAF naming convention](#enforce-caf-naming-convention-stapp--prefix) | `Microsoft.Web/staticSites` | App Service | 1.0.0 | Deny |

---

### Deny Static Web Apps with public network access enabled

**Definition:** [`definitions/deny-static-web-app-public-network-access.json`](definitions/deny-static-web-app-public-network-access.json)  
**Resource type:** `Microsoft.Web/staticSites`  
**Effects:** `Deny` (default), `Audit`, `Disabled`  
**Category:** App Service  
**Version:** 1.2.0

Denies creation or update of Azure Static Web Apps unless `publicNetworkAccess` is explicitly set to `Disabled`. Resources that omit the property are also denied, because Azure defaults to public access when the field is absent.

---

### Enforce CAF naming convention (stapp- prefix)

**Definition:** [`definitions/deny-static-web-app-naming-convention.json`](definitions/deny-static-web-app-naming-convention.json)  
**Resource type:** `Microsoft.Web/staticSites`  
**Effects:** `Deny` (default), `Audit`, `Disabled`  
**Category:** App Service  
**Version:** 1.0.0

Denies creation of Azure Static Web Apps whose name does not start with the `stapp-` prefix, as required by the [Microsoft Cloud Adoption Framework abbreviation recommendations](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations). The prefix check is case-insensitive. Because Static Web App names are immutable, the Deny effect is the only enforcement option — there is no in-place remediation path.

---

## Repository structure

```
definitions/          Policy definition JSON files (one per policy)
tests/
  modules/            Reusable Bicep modules shared across test deployments
  <policy-name>/      Per-policy test folder (name matches definition filename)
    resources.bicep   Deploys test resources covering all test scenarios
    policy.bicep      Deploys the policy definition and assignment (subscription scope)
    TEST-CASES.md     Test case table and step-by-step test sequence
```

## Testing

Each policy has a dedicated folder under `tests/` with Bicep deployments and a test guide.

The general test flow is:

1. Deploy test resources **before** policy assignment (`includeNonCompliant=true`) to seed pre-existing non-compliant resources.
2. Assign the policy in **Audit** mode and verify the compliance scan catches the expected resources.
3. Switch the policy to **Deny** mode and verify that non-compliant deployments are blocked while compliant ones succeed.
4. Where applicable, verify remediation by updating a non-compliant resource to a compliant state.

See the `TEST-CASES.md` in each test folder for the full test case table and exact commands.

### Prerequisites

- Azure CLI (`az`) with an active login
- Contributor and Resource Policy Contributor rights on the target subscription/resource group
