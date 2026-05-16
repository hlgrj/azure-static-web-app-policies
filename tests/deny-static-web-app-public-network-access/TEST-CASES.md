# Test Cases: Deny Static Web Apps with Public Network Access Enabled

Policy definition: [`definitions/deny-static-web-app-public-network-access.json`](../../definitions/deny-static-web-app-public-network-access.json)

## Test Cases

| # | Scenario | `publicNetworkAccess` | Timing | Effect=Deny | Effect=Audit |
|---|---|---|---|---|---|
| TC1 | New resource, explicitly enabled | `Enabled` | Post-assignment | **BLOCKED** | NonCompliant |
| TC2 | New resource, explicitly disabled | `Disabled` | Post-assignment | Allowed, Compliant | Compliant |
| TC3 | New resource, property absent | *(null)* | Post-assignment | **BLOCKED** | NonCompliant |
| TC4 | Existing resource, enabled before policy | `Enabled` | Pre-assignment | Shows NonCompliant | Shows NonCompliant |
| TC5 | Update: Disabled → Enabled | `Enabled` (update) | Post-assignment | **BLOCKED** | NonCompliant |
| TC6 | Update: Enabled → Disabled (remediation) | `Disabled` (update) | Post-assignment | Allowed, Compliant | Compliant |
| TC7 | Exempted resource, enabled | `Enabled` | Post-assignment | Allowed | Allowed |

**TC3 rationale:** the policy condition is `notEquals: "Disabled"` — a null field is not equal to `"Disabled"`, so it is caught by the policy. Azure Static Web Apps default to public access when the property is omitted, so an absent field is genuinely non-compliant and should be blocked.

**TC7** requires a policy exemption applied out-of-band and is not covered by the Bicep files below.

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

Deploy the noncompliant resource **before** policy assignment so it exists as a pre-existing resource for compliance scan testing.

```bash
az deployment group create \
  --resource-group $RG \
  --template-file resources.bicep \
  --parameters includeNonCompliant=true location=$LOCATION
```

Expected: all three resources deploy successfully (`stapp-tc2-*`, `stapp-tc3-*`, `stapp-tc4-*`) — no policy is assigned yet.

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

Expected: `stapp-tc3-*` (absent) and `stapp-tc4-*` (Enabled) show `NonCompliant`; `stapp-tc2-*` (Disabled) shows `Compliant`.

---

### Step 4 — Switch policy to Deny mode

```bash
az deployment sub create \
  --location $LOCATION \
  --template-file policy.bicep \
  --parameters testResourceGroupName=$RG effect=Deny
```

---

### Step 5 — Verify compliant new resources are allowed (TC2, TC3)

```bash
az deployment group create \
  --resource-group $RG \
  --template-file resources.bicep \
  --parameters includeNonCompliant=false location=$LOCATION
```

Expected: deployment succeeds; only `stapp-tc2-*` (Disabled) is created or updated.

---

### Step 6 — Verify noncompliant new resource is blocked (TC1)

```bash
az deployment group create \
  --resource-group $RG \
  --template-file resources.bicep \
  --parameters includeNonCompliant=true location=$LOCATION
```

Expected: deployment **fails** with `RequestDisallowedByPolicy` on `stapp-tc3-noncompliant-default` (absent property) and `stapp-tc4-noncompliant-existing` (explicitly Enabled).

---

### Step 7 — Verify update Disabled → Enabled is blocked (TC5)

Attempt to update `stapp-tc2-*` to `Enabled` inline:

```bash
az deployment group create \
  --resource-group $RG \
  --template-file ../modules/static-web-app.bicep \
  --parameters name=stapp-tc2-compliant-disabled location=$LOCATION publicNetworkAccess=Enabled
```

Expected: deployment **fails** with `RequestDisallowedByPolicy`.

---

### Step 8 — Verify remediation (TC6)

Update the pre-existing noncompliant resource (`stapp-tc4-*`) to `Disabled`:

```bash
az deployment group create \
  --resource-group $RG \
  --template-file ../modules/static-web-app.bicep \
  --parameters name=stapp-tc4-noncompliant-existing location=$LOCATION publicNetworkAccess=Disabled
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
