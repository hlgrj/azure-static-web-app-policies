# Test Cases: Azure Static Web Apps should use a private endpoint

Policy definition: [`definitions/audit-static-web-app-private-endpoint.json`](../../definitions/audit-static-web-app-private-endpoint.json)

## Why Deny is not supported

`privateEndpointConnections` is a read-only, externally-managed array populated when a `Microsoft.Network/privateEndpoints` resource is created pointing at the SWA — it is never present in the SWA's own PUT request body. Azure Policy evaluates the incoming request, so it always sees a count of 0 and would block every Static Web App deployment and update, including re-deployments of resources that already have a private endpoint. This policy therefore only supports `Audit` and `Disabled`.

## Test Cases

| # | Scenario | SKU | Private endpoint connections | Timing | Effect=Audit |
|---|---|---|---|---|---|
| TC1 | Standard resource, no private endpoint | `Standard` | 0 | Pre-assignment | Shows NonCompliant |
| TC2 | Standard resource, private endpoint connected | `Standard` | ≥ 1 | Pre-assignment | Shows Compliant |
| TC3 | Free-tier resource, private endpoint not supported | `Free` | 0 | Pre-assignment | Shows Compliant |
| TC4 | Exempted resource, no private endpoint | `Standard` | 0 | Post-assignment | Allowed |

**TC3 rationale:** The policy pre-condition `sku.name equals Standard` excludes Free-tier resources entirely. Free apps are addressed by the SKU policy.

**TC4** requires a policy exemption applied out-of-band and is not covered by the Bicep files below.

---

## Prerequisites

```bash
RG=<your-test-resource-group>
LOCATION=<azure-region>            # e.g. westeurope
SUBSCRIPTION=<your-subscription-id>
```

---

## Test Sequence

### Step 1 — Deploy test resources

Deploy all resources **before** policy assignment.

```bash
az deployment group create \
  --resource-group $RG \
  --template-file resources.bicep \
  --parameters location=$LOCATION
```

Expected: all resources deploy successfully — `stapp-tc2-*` gets a private endpoint connection; `stapp-tc1-*` has none. 
`stapp-tc3-free-tier-exempt` has none either since it is in the free tier.
No policy is assigned yet.

Verify the PE connection on TC2:

```bash
az staticwebapp show \
  --name stapp-tc2-compliant-with-pe \
  --resource-group $RG \
  --query "privateEndpointConnections[].{name:name, state:properties.privateLinkServiceConnectionState.status}" \
  --output table
```

Expected: one connection with status `Approved`.

---

### Step 2 — Deploy policy in Audit mode

```bash
az deployment sub create \
  --location $LOCATION \
  --template-file policy.bicep \
  --parameters testResourceGroupName=$RG effect=Audit
```

---

### Step 3 — Verify compliance scan (TC1, TC2, TC3)

```bash
az policy state trigger-scan --resource-group $RG

# Wait a few minutes before checking
az policy state list \
  --resource-group $RG \
  --filter "resourceType eq 'Microsoft.Web/staticSites'" \
  --query "[].{resource:resourceId, compliant:complianceState}" \
  --output table
```

Expected: `stapp-tc1-*` (Standard, no PE) shows `NonCompliant`; `stapp-tc2-*` (Standard, with PE) and `stapp-tc3-*` (Free) show `Compliant`.

---

### Step 4 — Verify remediation (TC1)

Add a private endpoint to the non-compliant resource:

```bash
<az network private-endpoint create \
  --name pe-stapp-tc1-remediation \
  --resource-group $RG \
  --location $LOCATION \
  --vnet-name vnet-stapp-pe-test \
  --subnet snet-pe \
  --private-connection-resource-id $(az staticwebapp show --name stapp-tc1-noncompliant-no-pe --resource-group $RG --query id -o tsv) \
  --group-id staticSites \
  --connection-name conn-stapp-tc1
```

Trigger a compliance rescan and verify `stapp-tc1-*` transitions to `Compliant`.

---

### Step 5 — Clean up

```bash
az deployment sub create \
  --location $LOCATION \
  --template-file policy.bicep \
  --parameters testResourceGroupName=$RG effect=Disabled

az group delete --name $RG --yes
```
