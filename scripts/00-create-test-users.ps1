# Creates the three test identities as Service Principals (app registrations)
# instead of Entra ID user accounts.
#
# Why: creating a brand new USER account requires "User Administrator" rights
# on the tenant. School/org tenants (like umbc.edu) restrict that to IT staff -
# students can't get it, no matter how the script is written.
#
# Creating a SERVICE PRINCIPAL only needs the much more common "Application
# Developer" permission, which most tenants leave enabled for all users.
# It's also arguably more realistic: real companies use service principals
# for scripted/automated access all the time - a "robot identity" instead
# of a human one. For this lab, each one just plays the role of a person.

Write-Host "`n=== Creating RBAC Lab Test Identities (Service Principals) ===" -ForegroundColor Cyan

$testIdentities = @(
    @{ Label = "SysAdmin";    VarName = "sysadmin_object_id";     Name = "rbaclab-sysadmin"    },
    @{ Label = "SupportTech"; VarName = "support_user_object_id"; Name = "rbaclab-supporttech" },
    @{ Label = "Auditor";     VarName = "auditor_object_id";      Name = "rbaclab-auditor"     }
)

$results = @()
foreach ($u in $testIdentities) {
    Write-Host "Creating $($u.Label) -> $($u.Name)" -ForegroundColor Cyan

    # --skip-assignment: Terraform is what assigns the RBAC roles, not this
    # command. This just creates the identity itself.
    $spJson = az ad sp create-for-rbac --name $u.Name --skip-assignment 2>$null

    if (-not $spJson) {
        Write-Warning "Failed to create $($u.Name). See the fallback note at the bottom of this script's output."
        continue
    }

    $sp = $spJson | ConvertFrom-Json

    # create-for-rbac returns the appId, not the objectId. Role assignments
    # in Terraform need the objectId - one more lookup to get it.
    $objectId = az ad sp show --id $sp.appId --query id -o tsv 2>$null

    if (-not $objectId) {
        Write-Warning "$($u.Name) was created but the Object ID lookup failed. Run: az ad sp show --id $($sp.appId) --query id -o tsv"
        continue
    }

    Write-Host "  Created. Object ID: $objectId" -ForegroundColor Green
    $results += [PSCustomObject]@{
        Role         = $u.Label
        VarName      = $u.VarName
        AppId        = $sp.appId
        ClientSecret = $sp.password
        Tenant       = $sp.tenant
        ObjectId     = $objectId
    }
}

if ($results.Count -eq 0) {
    Write-Host "`nNo identities were created. Fallback options:" -ForegroundColor Red
    Write-Host "  1. Ask your tenant admin (UMBC IT) to grant Application Developer rights, or" -ForegroundColor Yellow
    Write-Host "  2. Create the app registrations manually: Entra admin center -> App registrations -> New registration" -ForegroundColor Yellow
    Write-Host "     Then get each one's Object ID from Enterprise Applications -> (app name) -> Overview" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n=== Paste these into terraform.tfvars ===" -ForegroundColor Yellow
foreach ($r in $results) {
    Write-Host "$($r.VarName.PadRight(25)) = `"$($r.ObjectId)`""
}

# Saved locally so you have the AppId/ClientSecret for Step 6 (logging in
# as each persona via az login --service-principal). Gitignored - never commit.
$results | Export-Csv -Path "./rbac-test-identities.csv" -NoTypeInformation
Write-Host "`nCredentials saved to scripts/rbac-test-identities.csv (gitignored - do not commit)" -ForegroundColor Red