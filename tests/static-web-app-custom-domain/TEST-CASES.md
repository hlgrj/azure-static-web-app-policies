# Test Cases: Azure Static Web Apps should use a custom domain

Policy definition: [`definitions/static-web-app-custom-domain.json`](../../definitions/static-web-app-custom-domain.json)

## Why Deny is not supported

`customDomains` are child resources (`Microsoft.Web/staticSites/customDomains`) that are never present in the Static Web App's PUT request body. Azure Policy evaluates the incoming request, so it always sees a count of 0 and would block every Static Web App deployment and update — including re-deployments of resources that already have custom domains. This policy therefore only supports `Audit` and `Disabled`.

## Test Cases

| # | Scenario | SKU | Custom domains | Timing | Effect=Audit |
|---|---|---|---|---|---|
| TC1 | Standard resource, no custom domain | `Standard` | 0 | Pre-assignment | Shows NonCompliant |
| TC2 | Standard resource, custom domain configured out-of-band | `Standard` | ≥ 1 | Pre-assignment | Shows Compliant |
| TC3 | Free-tier resource, no custom domain | `Free` | 0 | Pre-assignment | Shows NonCompliant |
| TC4 | Exempted resource, no custom domain | `Standard` | 0 | Post-assignment | Allowed |

**TC2 rationale:** Custom domains require DNS ownership validation and cannot be scripted without control over the target domain's DNS records. TC2's Static Web App is deployed by `resources.bicep`; the custom domain must be added manually (see Step 1b below) before the compliance scan in Step 3.

**TC3 rationale:** Unlike the private endpoint and public network access policies, this policy has no SKU pre-condition — custom domains are supported on both Free and Standard tier.

**TC4** requires a policy exemption applied out-of-band and is not covered by the Bicep files below.

---

## Prerequisites

```bash
RG=<your-test-resource-group>
LOCATION=<azure-region>            # e.g. westeurope
SUBSCRIPTION=<your-subscription-id>
CUSTOM_DOMAIN=<your-domain>        # e.g. app.example.com — must be DNS-resolvable; CNAME entry that points to the Azure Static Web App
```

---

## Test Sequence

### Step 1a — Deploy test resources

Deploy all resources **before** policy assignment.

```bash
az deployment group create \
  --resource-group $RG \
  --template-file resources.bicep \
  --parameters location=$LOCATION
```

Expected: three Static Web Apps deploy successfully with no custom domains attached.

### Step 1b — Add custom domain to TC2 (manual, out-of-band)

First get the Static Web App's default hostname and create a CNAME record in your DNS provider pointing `$CUSTOM_DOMAIN` to it:

```bash
az staticwebapp show \
  --name stapp-tc2-compliant-with-domain \
  --resource-group $RG \
  --query "defaultHostname" \
  --output tsv
```

Once the CNAME is in place, register the domain. Azure validates ownership automatically via the CNAME — no separate validation token is issued:

```bash
az staticwebapp hostname set \
  --name stapp-tc2-compliant-with-domain \
  --resource-group $RG \
  --hostname $CUSTOM_DOMAIN
```

The command waits for validation to complete and exits with `status: Ready`. TC2 is now in a compliant state.

> **Note:** TXT-based validation (for apex/root domains that cannot use a CNAME) requires a different flow — get the token first via `az staticwebapp hostname show`, add a `_dnsauth` TXT record, then run `hostname set`.

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

Expected: `stapp-tc1-*` (Standard, no domain) and `stapp-tc3-*` (Free, no domain) show `NonCompliant`; `stapp-tc2-*` (Standard, with domain) shows `Compliant`.

---

### Step 4 — Verify remediation (TC1)

Add a custom domain to the non-compliant TC1 resource following the same steps as Step 1b, substituting `stapp-tc1-noncompliant-no-domain`. Trigger a compliance rescan and verify it transitions to `Compliant`.

---

### Step 5 — Clean up

```bash
az deployment sub create \
  --location $LOCATION \
  --template-file policy.bicep \
  --parameters testResourceGroupName=$RG effect=Disabled

az group delete --name $RG --yes
```
