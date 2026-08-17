param(
    [string]$ResourceGroup = "RG-FileServerLab",
    [string]$VMName = "FS01"
)

# terraform apply confirms Terraform created the role assignment resource.
# It does NOT confirm Azure has actually applied the permission yet -
# RBAC can take a few minutes to propagate. This script checks the real,
# live state in Azure, not what Terraform's state file says.

Write-Host "`n=== RBAC Lab Validation ===" -ForegroundColor Cyan

$vmId = az vm show -g $ResourceGroup -n $VMName --query id -o tsv 2>$null
if (-not $vmId) { throw "VM $VMName not found in $ResourceGroup. Confirm Lab 07 is deployed and running." }
Write-Host "Scope: $vmId`n"

$assignments = az role assignment list --scope $vmId `
    --query "[].{role:roleDefinitionName,principal:principalName}" `
    -o json | ConvertFrom-Json

$expected = @(
    @{ Role = "Owner";                       Label = "SysAdmin"    },
    @{ Role = "Virtual Machine Contributor"; Label = "SupportTech" },
    @{ Role = "Reader";                      Label = "Auditor"     }
)

$allPass = $true
Write-Host "[ Role Assignment Validation ]" -ForegroundColor White
foreach ($e in $expected) {
    $match = $assignments | Where-Object { $_.role -eq $e.Role }
    if ($match) {
        Write-Host "  [PASS] $($e.Role) -> $($match.principal)" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $($e.Role) not found on $VMName" -ForegroundColor Red
        $allPass = $false
    }
}

Write-Host "`n[ Permission Matrix - FS01 scope only ]" -ForegroundColor White
$matrix = @(
    @{ Action = "View VM details";   O = "Yes"; VC = "Yes"; R = "Yes" },
    @{ Action = "Start / Stop VM";   O = "Yes"; VC = "Yes"; R = "No"  },
    @{ Action = "Connect via RDP";   O = "Yes"; VC = "Yes"; R = "No"  },
    @{ Action = "Delete VM";         O = "Yes"; VC = "No";  R = "No"  },
    @{ Action = "Manage RBAC roles"; O = "Yes"; VC = "No";  R = "No"  }
)
Write-Host ("  {0,-26} {1,-8} {2,-20} {3}" -f "Action", "Owner", "VM Contributor", "Reader")
foreach ($row in $matrix) {
    Write-Host ("  {0,-26} {1,-8} {2,-20} {3}" -f $row.Action, $row.O, $row.VC, $row.R)
}

$report = "RBAC Lab Validation Report`nGenerated: $(Get-Date)`nVM Resource ID: $vmId`n`n"
$report += $assignments | Format-Table -AutoSize | Out-String
$report += "`nOverall: $(if ($allPass) { 'ALL PASS' } else { 'FAILURES DETECTED' })"
$report | Out-File "./RBAC_Lab_Report.txt" -Encoding UTF8

Write-Host "`nReport exported: RBAC_Lab_Report.txt" -ForegroundColor Cyan
Write-Host "Overall: $(if ($allPass) { 'ALL PASS' } else { 'FAILURES DETECTED' })" -ForegroundColor $(if ($allPass) { "Green" } else { "Red" })
