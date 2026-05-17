# Test Cases: Azure Static Web Apps should be connected to an approved GitHub organization

Policy definition: [`definitions/static-web-app-allowed-repository-organizations.json`](../../definitions/static-web-app-allowed-repository-organizations.json)

## Test Cases

| # | Scenario | repositoryUrl | Timing | Effect=Audit | Effect=Deny |
|---|---|---|---|---|---|
| TC1 | SWA connected to a repo in a disallowed org | `https://github.com/unapproved-org/...` | Pre-assignment | Shows NonCompliant | Blocked |
| TC2 | SWA connected to a repo in an approved org | `https://github.com/myorg/...` | Pre-assignment | Shows Compliant | Allowed |
| TC3 | SWA with no GitHub integration (no repositoryUrl) | absent | Pre-assignment | Not evaluated | Not evaluated |
| TC4 | Exempted SWA connected to a disallowed org | `https://github.com/unapproved-org/...` | Post-assignment | Allowed | Allowed |

**TC1 rationale:** The `repositoryUrl` prefix does not match any entry in `allowedOrganizations`, so the `count` expression evaluates to 0 and the resource is flagged.

**TC2 rationale:** The `repositoryUrl` prefix matches one of the `allowedOrganizations` entries, so the `count` expression evaluates to ≥ 1 and the resource is compliant.

**TC3 rationale:** The policy pre-conditions `repositoryUrl exists: true` and `repositoryUrl notEquals: ""` exclude SWAs with no GitHub integration. TC3 confirms these resources do not appear in the compliance scan.

**TC4** requires a policy exemption applied out-of-band and is not covered by the Bicep files below.

---

## Prerequisites

```bash
RG=<your-test-resource-group>
LOCATION=<azure-region>                  # e.g. westeurope
SUBSCRIPTION=<your-subscription-id>
ALLOWED_ORG=<your-approved-github-org>   # e.g. myorg
DISALLOWED_REPO=https://github.com/<other-org>/<repo>
ALLOWED_REPO=https://github.com/$ALLOWED_ORG/<repo>
DISALLOWED_TOKEN=<github-pat-for-the-disallowed-org>
ALLOWED_TOKEN=<github-pat-for-the-allowed-org>
```

> **Note:** Both `DISALLOWED_REPO` and `ALLOWED_REPO` must be real, accessible repositories. Azure validates the GitHub integration at deployment time and requires a PAT with `repo` scope to set up the GitHub Actions workflow.

---

## Test Sequence

### Step 1 — Deploy test resources (no policy yet)

```bash
az deployment group create \
  --resource-group $RG \
  --template-file resources.bicep \
  --parameters \
      location=$LOCATION \
      disallowedRepoUrl=$DISALLOWED_REPO \
      allowedRepoUrl=$ALLOWED_REPO \
      disallowedRepositoryToken=$DISALLOWED_TOKEN \
      allowedRepositoryToken=$ALLOWED_TOKEN
```

Expected: all three Static Web Apps deploy successfully — TC1 and TC2 with GitHub integrations, TC3 without. Policy is not assigned yet.

---

### Step 2 — Deploy policy in Audit mode

```bash
az deployment sub create \
  --location $LOCATION \
  --template-file policy.bicep \
  --parameters \
      testResourceGroupName=$RG \
      effect=Audit \
      allowedOrganizations="[\"$ALLOWED_ORG\"]"
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

Expected: `stapp-tc1-*` (disallowed org) shows `NonCompliant`; `stapp-tc2-*` (allowed org) and `stapp-tc3-*` (no repo URL) show `Compliant`.

---

### Step 4 — Switch to Deny mode and verify blocking (TC1)

```bash
az deployment sub create \
  --location $LOCATION \
  --template-file policy.bicep \
  --parameters \
      testResourceGroupName=$RG \
      effect=Deny \
      allowedOrganizations="[\"$ALLOWED_ORG\"]"
```

Attempt to create a new non-compliant SWA — expect a policy denial:

```bash
az staticwebapp create \
  --name stapp-deny-test \
  --resource-group $RG \
  --location $LOCATION \
  --source $DISALLOWED_REPO \
  --branch main \
  --token $DISALLOWED_TOKEN \
  --sku Standard
```

Expected: request is rejected with a policy denial error.

Verify a compliant SWA is still allowed:

```bash
az staticwebapp create \
  --name stapp-allow-test \
  --resource-group $RG \
  --location $LOCATION \
  --source $ALLOWED_REPO \
  --branch main \
  --token $ALLOWED_TOKEN \
  --sku Standard
```

Expected: request succeeds.

---

### Step 5 — Clean up

```bash
az deployment sub create \
  --location $LOCATION \
  --template-file policy.bicep \
  --parameters \
      testResourceGroupName=$RG \
      effect=Disabled \
      allowedOrganizations="[\"$ALLOWED_ORG\"]"

az group delete --name $RG --yes
```
