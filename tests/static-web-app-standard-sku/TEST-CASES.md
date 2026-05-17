# Test Cases: Azure Static Web Apps should use the Standard SKU

Policy definition: [`definitions/static-web-app-standard-sku.json`](../../definitions/static-web-app-standard-sku.json)

## Test Cases

| # | Scenario | `sku.name` | Timing | Effect=Deny | Effect=Audit |
|---|---|---|---|---|---|
| TC1 | New resource, Free SKU | `Free` | Post-assignment | **BLOCKED** | NonCompliant |
| TC2 | New resource, Standard SKU | `Standard` | Post-assignment | Allowed, Compliant | Compliant |
| TC3 | Existing resource, Free SKU before policy | `Free` | Pre-assignment | Shows NonCompliant | Shows NonCompliant |
| TC4 | Update: Standard → Free (downgrade) | `Free` (update) | Post-assignment | **BLOCKED** | NonCompliant |
| TC5 | Update: Free → Standard (remediation) | `Standard` (update) | Post-assignment | Allowed, Compliant | Compliant |
| TC6 | Exempted resource, Free SKU | `Free` | Post-assignment | Allowed | Allowed |

**TC6** requires a policy exemption applied out-of-band and is not covered by the Bicep files below.

---

## Prerequisites

```bash
RG=<your-test-resource-group>
LOCATION=<azure-region>            # e.g. westeurope
SUBSCRIPTION=<your-subscription-id>
```

---

## Test Sequence

### Step 1 — Seed pre-existing noncompliant resource (TC3)

Deploy the noncompliant resource **before** policy assignment so it exists as a pre-existing resource for compliance scan testing.

```bash
az deployment group create \
  --resource-group $RG \
  --template-file resources.bicep \
  --parameters includeNonCompliant=true location=$LOCATION
```

Expected: both resources deploy successfully (`stapp-tc2-*`, `stapp-tc3-*`) — no policy is assigned yet.

---

### Step 2 — Deploy policy in Audit mode

```bash
az deployment sub create \
  --location $LOCATION \
  --template-file policy.bicep \
  --parameters testResourceGroupName=$RG effect=Audit
```

---

### Step 3 — Verify compliance scan (TC3)

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

Expected: `stapp-tc3-*` (Free) shows `NonCompliant`; `stapp-tc2-*` (Standard) shows `Compliant`.

---

### Step 4 — Switch policy to Deny mode

```bash
az deployment sub create \
  --location $LOCATION \
  --template-file policy.bicep \
  --parameters testResourceGroupName=$RG effect=Deny
```

---

### Step 5 — Verify compliant new resources are allowed (TC2)

```bash
az deployment group create \
  --resource-group $RG \
  --template-file resources.bicep \
  --parameters includeNonCompliant=false location=$LOCATION
```

Expected: deployment succeeds; `stapp-tc2-*` (Standard) is created or updated.

---

### Step 6 — Verify noncompliant new resource is blocked (TC1)

```bash
az deployment group create \
  --resource-group $RG \
  --template-file resources.bicep \
  --parameters includeNonCompliant=true location=$LOCATION
```

Expected: deployment **fails** with `RequestDisallowedByPolicy` on `stapp-tc3-*` (Free SKU).

---

### Step 7 — Verify update Standard → Free is blocked (TC4)

Attempt to downgrade `stapp-tc2-*` to Free:

```bash
az deployment group create \
  --resource-group $RG \
  --template-file ../modules/static-web-app.bicep \
  --parameters name=stapp-tc2-compliant-standard location=$LOCATION skuName=Free
```

Expected: deployment **fails** with `RequestDisallowedByPolicy`.

---

### Step 8 — Verify remediation (TC5)

Update the pre-existing noncompliant resource (`stapp-tc3-*`) to Standard:

```bash
az deployment group create \
  --resource-group $RG \
  --template-file ../modules/static-web-app.bicep \
  --parameters name=stapp-tc3-noncompliant-free location=$LOCATION skuName=Standard
```

Expected: deployment succeeds; `stapp-tc3-*` transitions to `Compliant` on the next evaluation cycle.

---

### Step 9 — Clean up

```bash
az deployment sub create \
  --location $LOCATION \
  --template-file policy.bicep \
  --parameters testResourceGroupName=$RG effect=Disabled

az group delete --name $RG --yes
```
