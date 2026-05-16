# Test Cases: Deny Static Web Apps with Non-Compliant Names

Policy definition: [`definitions/deny-static-web-app-naming-convention.json`](../../definitions/deny-static-web-app-naming-convention.json)

The Microsoft CAF abbreviation for Azure Static Web Apps is `stapp`. This policy requires all Static Web App names to start with `stapp-`.

The `like` operator in Azure Policy is **case-insensitive**, so `STAPP-myapp` also passes. Strict lowercase enforcement is not achievable with `like`.

**Important difference from property-based policies:** Static Web App names are **immutable** — a resource cannot be renamed once created. There are therefore no update-path test cases. Deny mode prevents wrong names from being created in the first place; it cannot remediate existing noncompliant resources in-place though.

## Test Cases

| # | Scenario | Name | Timing | Effect=Deny | Effect=Audit |
|---|---|---|---|---|---|
| TC1 | Compliant name with `stapp-` prefix | `stapp-tc1-compliant` | Post-assignment | Allowed, Compliant | Compliant |
| TC2 | Non-compliant, no prefix | `tc2-noncompliant-no-prefix` | Post-assignment | **BLOCKED** | NonCompliant |
| TC3 | Non-compliant, wrong prefix (`swa-`) | `swa-tc3-noncompliant` | Post-assignment | **BLOCKED** | NonCompliant |
| TC4 | Existing non-compliant, pre-existing | `tc4-noncompliant-existing` | Pre-assignment | Shows NonCompliant | Shows NonCompliant |
| TC5 | Exempted resource with non-compliant name | *(any non-compliant name)* | Post-assignment | Allowed | Allowed |

**TC3 rationale:** `swa-` might have been a previously common informal abbreviation for Static Web Apps. This test case ensures the policy catches resources using the old convention.

**TC5** requires a policy exemption applied out-of-band and is not covered by the Bicep files below.

---

## Prerequisites

```bash
RG=<your-test-resource-group>
LOCATION=<azure-region>            # e.g. westeurope
SUBSCRIPTION=<your-subscription-id>
```

---

## Test Sequence

### Step 1 — Seed pre-existing noncompliant resources (TC4)

Deploy all resources **before** policy assignment so noncompliant ones exist for compliance scan testing.

```bash
az deployment group create \
  --resource-group $RG \
  --template-file resources.bicep \
  --parameters includeNonCompliant=true location=$LOCATION
```

Expected: all four resources deploy successfully (`stapp-tc1-compliant`, `tc2-noncompliant-no-prefix`, `swa-tc3-noncompliant`, `tc4-noncompliant-existing`) — no policy is assigned yet.

---

### Step 2 — Deploy policy in Audit mode

Start with `Audit` to verify the compliance scan without risking blocked deployments.

```bash
az deployment sub create \
  --location $LOCATION \
  --template-file policy.bicep \
  --parameters testResourceGroupName=$RG effect=Audit
```

---

### Step 3 — Verify compliance scan (TC4)

Policy evaluation runs on a background cycle. Trigger an on-demand scan and wait for results.

```bash
az policy state trigger-scan --resource-group $RG

# Wait a few minutes before checking
az policy state list \
  --resource-group $RG \
  --filter "resourceType eq 'Microsoft.Web/staticSites'" \
  --query "[].{resource:resourceId, compliant:complianceState}" \
  --output table
```

Expected: `tc2-noncompliant-no-prefix`, `swa-tc3-noncompliant`, and `tc4-noncompliant-existing` show `NonCompliant`; `stapp-tc1-compliant` shows `Compliant`.

---

### Step 4 — Switch policy to Deny mode

```bash
az deployment sub create \
  --location $LOCATION \
  --template-file policy.bicep \
  --parameters testResourceGroupName=$RG effect=Deny
```

---

### Step 5 — Verify compliant new resource is allowed (TC1)

```bash
az deployment group create \
  --resource-group $RG \
  --template-file resources.bicep \
  --parameters includeNonCompliant=false location=$LOCATION
```

Expected: deployment succeeds; only `stapp-tc1-compliant` is created or updated.

---

### Step 6 — Verify noncompliant new resources are blocked (TC2, TC3)

```bash
az deployment group create \
  --resource-group $RG \
  --template-file resources.bicep \
  --parameters includeNonCompliant=true location=$LOCATION
```

Expected: deployment **fails** with `RequestDisallowedByPolicy` on `tc2-noncompliant-no-prefix`, `swa-tc3-noncompliant`, and `tc4-noncompliant-existing` (re-deploying an existing resource also triggers policy evaluation).

---

### Step 7 — Clean up

```bash
az deployment sub create \
  --location $LOCATION \
  --template-file policy.bicep \
  --parameters testResourceGroupName=$RG effect=Disabled

az group delete --name $RG --yes
```
