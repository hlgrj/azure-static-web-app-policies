# Test Cases: Azure Static Web Apps should have public network access disabled

Policy definition: [`definitions/audit-static-web-app-public-network-access.json`](../../definitions/audit-static-web-app-public-network-access.json)

## Test Cases

| # | Scenario | SKU | `publicNetworkAccess` | Timing | Effect=Deny | Effect=Audit |
|---|---|---|---|---|---|---|
| TC1 | New Standard resource, explicitly enabled | `Standard` | `Enabled` | Post-assignment | **BLOCKED** | NonCompliant |
| TC2 | New Standard resource, explicitly disabled | `Standard` | `Disabled` | Post-assignment | Allowed, Compliant | Compliant |
| TC3 | New Standard resource, property absent | `Standard` | *(null)* | Post-assignment | **BLOCKED** | NonCompliant |
| TC4 | Existing Standard resource, enabled before policy | `Standard` | `Enabled` | Pre-assignment | Shows NonCompliant | Shows NonCompliant |
| TC5 | Free-tier resource, public access enabled | `Free` | `Enabled` | Post-assignment | Allowed, Compliant | Compliant |
| TC6 | Update: Disabled → Enabled | `Standard` | `Enabled` (update) | Post-assignment | **BLOCKED** | NonCompliant |
| TC7 | Update: Enabled → Disabled (remediation) | `Standard` | `Disabled` (update) | Post-assignment | Allowed, Compliant | Compliant |
| TC8 | Exempted resource, enabled | `Standard` | `Enabled` | Post-assignment | Allowed | Allowed |

**TC3 rationale:** the policy condition is `notEquals: "Disabled"` — a null field is not equal to `"Disabled"`, so it is caught by the policy. Standard Static Web Apps default to public access when the property is omitted, so an absent field is genuinely non-compliant.

**TC5 rationale:** the policy pre-condition `sku.name equals Standard` excludes Free-tier resources entirely. Free apps cannot use private endpoints and have no compliant alternative to public access; they are addressed by the SKU policy.

**TC8** requires a policy exemption applied out-of-band and is not covered by the Bicep files below.

---

## Prerequisites

```bash
RG=<your-test-resource-group>
LOCATION=<azure-region>            # e.g. westeurope
SUBSCRIPTION=<your-subscription-id>
```

---

## Test Sequence

### Step 1 — Seed pre-existing noncompliant resource (TC4)

Deploy resources **before** policy assignment so TC4 exists as a pre-existing non-compliant resource.

```bash
az deployment group create \
  --resource-group $RG \
  --template-file resources.bicep \
  --parameters includeNonCompliant=true location=$LOCATION
```

Expected: all resources deploy successfully (`stapp-tc2-*`, `stapp-tc3-*`, `stapp-tc4-*`, `stapp-tc5-*`) — no policy is assigned yet.

---

### Step 2 — Deploy policy in Audit mode

```bash
az deployment sub create \
  --location $LOCATION \
  --template-file policy.bicep \
  --parameters testResourceGroupName=$RG effect=Audit
```

---

### Step 3 — Verify compliance scan (TC3, TC4, TC5)

```bash
az policy state trigger-scan --resource-group $RG

# Wait a few minutes before checking
az policy state list \
  --resource-group $RG \
  --filter "resourceType eq 'Microsoft.Web/staticSites'" \
  --query "[].{resource:resourceId, compliant:complianceState}" \
  --output table
```

Expected: `stapp-tc3-*` (absent) and `stapp-tc4-*` (Enabled) show `NonCompliant`; `stapp-tc2-*` (Disabled) and `stapp-tc5-*` (Free) show `Compliant`.

---

### Step 4 — Switch policy to Deny mode

```bash
az deployment sub create \
  --location $LOCATION \
  --template-file policy.bicep \
  --parameters testResourceGroupName=$RG effect=Deny
```

---

### Step 5 — Verify compliant new resource is allowed (TC2)

```bash
az deployment group create \
  --resource-group $RG \
  --template-file resources.bicep \
  --parameters includeNonCompliant=false location=$LOCATION
```

Expected: `stapp-tc2-*` (Standard, Disabled) and `stapp-tc5-*` (Free) deploy or update successfully.

---

### Step 6 — Verify noncompliant new Standard resource is blocked (TC1)

```bash
az deployment group create \
  --resource-group $RG \
  --template-file resources.bicep \
  --parameters includeNonCompliant=true location=$LOCATION
```

Expected: deployment **fails** with `RequestDisallowedByPolicy` on `stapp-tc3-*` (absent) and `stapp-tc4-*` (Enabled).

---

### Step 7 — Verify update Disabled → Enabled is blocked (TC6)

```bash
az deployment group create \
  --resource-group $RG \
  --template-file ../modules/static-web-app.bicep \
  --parameters name=stapp-tc2-compliant-disabled location=$LOCATION skuName=Standard publicNetworkAccess=Enabled
```

Expected: deployment **fails** with `RequestDisallowedByPolicy`.

---

### Step 8 — Verify remediation (TC7)

Update the pre-existing noncompliant resource to `Disabled`:

```bash
az deployment group create \
  --resource-group $RG \
  --template-file ../modules/static-web-app.bicep \
  --parameters name=stapp-tc4-noncompliant-existing location=$LOCATION skuName=Standard publicNetworkAccess=Disabled
```

Expected: deployment succeeds; `stapp-tc4-*` transitions to `Compliant` on the next evaluation cycle.

---

### Step 9 — Clean up

```bash
az deployment sub create \
  --location $LOCATION \
  --template-file policy.bicep \
  --parameters testResourceGroupName=$RG effect=Disabled

az group delete --name $RG --yes
```
