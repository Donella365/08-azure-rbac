---
lab: 08-rbac
depends_on: 07-ntfs-file-server (RG-FileServerLab, FS01 must exist and be running)
---

# Lab 08 SOP — Azure RBAC on FS01 (Optimized Edition)

## What this lab is actually doing

Lab 07 controlled who can open a folder *inside* Windows. This lab controls who can touch the *VM itself* from Azure's side — start it, stop it, delete it, or manage who else has access. Same VM, two completely different locks.

Three fake people get three different keys to FS01:

| Person | Key they get | What they can do |
|---|---|---|
| SysAdmin | Owner | Everything, including giving keys to other people |
| SupportTech | Virtual Machine Contributor | Start it, stop it, restart it — can't delete it or hand out keys |
| Auditor | Reader | Look at it — can't touch anything |

That's it. No new VMs. No new networking. Just three permission slips, scoped so they only work on FS01.

## What's different from the original lab doc (and why)

The original lab doc is solid, but it has you do one thing manually that should be scripted: creating three test user accounts by hand in the Azure Portal. A real cloud engineer scripts repeatable setup work instead of clicking through a UI. So this SOP replaces that step with `00-create-test-users.ps1`.

One adjustment made along the way: the script creates **Service Principals** (app/robot identities) instead of human Entra ID user accounts. Creating a real user account needs "User Administrator" rights, which school/org tenants (like a `.edu` tenant) reserve for IT staff — students can't get that no matter how it's scripted. Service principals only need a much more common permission level, and they're actually how real companies do scripted/automated access anyway. Each one just plays the role of a person for this lab.

Everything else follows the original doc's order and logic exactly — same file structure, same data-source pattern, same validation approach.

## Before you start

Confirm Lab 07's resources actually exist (VMs can be stopped for this part — you're just checking they're there):

```bash
az vm list -g RG-FileServerLab --query "[].name" -o table
```

You should see DC01, FS01, and CLIENT01 listed. Steps 1-5 below (folders, creating test users, deploying RBAC) all work fine even with the VMs powered off. You only need them actually running for Step 6, where you log in as each persona and prove they can start/stop/view the VM — that check is called out again right before Step 6.

## Step 1 — Project folder

This lives in its own folder, separate from Lab 07. It reads Lab 07's stuff but never touches Lab 07's Terraform state.

```bash
mkdir -p ~/Documents/01AZ\ labs/cte-sys-admin/s2/08-rbac
cd ~/Documents/01AZ\ labs/cte-sys-admin/s2/08-rbac
```

Drop in the `terraform/`, `scripts/`, and `validate-lab.ps1` files provided. Folder should look like:

```
08-rbac/
├── SOP.md
├── validate-lab.ps1
├── terraform/
│   ├── backend.tf
│   ├── versions.tf
│   ├── variables.tf
│   ├── data.tf
│   ├── rbac.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── .gitignore
├── scripts/
│   └── 00-create-test-users.ps1
└── screenshots/
```

## Step 2 — Create the three test identities (automated)

This is the scripted replacement for the manual portal step in the original doc.

```bash
cd scripts
pwsh ./00-create-test-users.ps1
```

**What this does, in plain terms:** it creates three Service Principals — robot identities named SysAdmin, SupportTech, and Auditor — that stand in for the three personas. Each one gets an App ID and a client secret (basically a robot's username and password). At the end it prints three lines you paste straight into `terraform.tfvars`, and it saves the full credentials to `scripts/rbac-test-identities.csv` (already gitignored) so you have them for testing later.

If it fails with a permissions error, ask your tenant admin (school IT) about "Application Developer" rights, or create the app registrations by hand: Entra admin center → App registrations → New registration, then grab each one's Object ID from Enterprise Applications → (app name) → Overview.

📸 **Screenshot:** terminal output showing all three identities created with their Object IDs.

## Step 3 — Configure variables

```bash
cd ../terraform
cp terraform.tfvars.example terraform.tfvars
```

Open `terraform.tfvars` and paste in the three Object IDs the script printed. Double check `resource_group_name = "RG-FileServerLab"` and `vm_name = "FS01"` match your Lab 07 deployment exactly — capitalization matters.

## Step 4 — Deploy

```bash
az login
terraform init
terraform plan
```

**Stop and check:** `plan` must show exactly 3 resources to add. If it shows more, `resource_group_name` or `vm_name` doesn't match Lab 07 exactly.

```bash
terraform apply
```

Type `yes`. This finishes in under a minute — there's no VM to build, just permission slips to hand out.

📸 **Screenshot:** `terraform apply` output showing 3 resources added.

## Step 5 — Validate

RBAC can take a couple minutes to actually take effect in Azure, even after Terraform says it's done. Wait 2-3 minutes, then:

```powershell
pwsh ../validate-lab.ps1
```

This checks the real, live permissions in Azure (not just what Terraform's file says), prints a permission matrix, and saves `RBAC_Lab_Report.txt`.

📸 **Screenshot:** validation output showing all 3 checks as `[PASS]`.

## Step 6 — Prove it works by testing as each person

**This step needs FS01 actually running** — SupportTech has to start/stop a live VM, and Auditor has to view a live VM's real status. Check and start it if needed:

```bash
az vm list -d -g RG-FileServerLab --query "[].{name:name,status:powerState}" -o table
# All three should say: VM running

# If not:
az vm start --ids $(az vm list -g RG-FileServerLab --query "[].id" -o tsv)
```

Open a fresh terminal for each test. Log in as that identity using its App ID and client secret from `scripts/rbac-test-identities.csv`, try something it should be able to do, then try something it shouldn't. A **FAIL is not a bug** — it's proof the lock works.

Service principals log in differently than a human — no browser popup, just three values from the CSV:

```bash
# Auditor
az login --service-principal -u <Auditor AppId> -p <Auditor ClientSecret> --tenant <Tenant>

az vm show -g RG-FileServerLab -n FS01 --query "{name:name,size:hardwareProfile.vmSize}"
# should succeed

az vm stop -g RG-FileServerLab -n FS01
# should FAIL with AuthorizationFailed — this is correct
```

```bash
# SupportTech
az login --service-principal -u <SupportTech AppId> -p <SupportTech ClientSecret> --tenant <Tenant>

az vm start -g RG-FileServerLab -n FS01
# should succeed

az role assignment list --scope $(az vm show -g RG-FileServerLab -n FS01 --query id -o tsv)
# should FAIL — SupportTech can't see or manage RBAC
```

```bash
# SysAdmin
az login --service-principal -u <SysAdmin AppId> -p <SysAdmin ClientSecret> --tenant <Tenant>

az role assignment list --scope $(az vm show -g RG-FileServerLab -n FS01 --query id -o tsv)
# should succeed — Owner can see and manage RBAC
```

```bash
# Back to you
az login
az account show
```

📸 **Screenshots:** one showing a successful action, one showing a blocked (FAIL) action — the pairing is the actual proof of least-privilege enforcement.

## Step 7 — Pause or tear down

```bash
# Remove RBAC only, keep Lab 07's VMs
terraform destroy

# Full teardown of everything, only when completely done
terraform destroy
az group delete -n RG-FileServerLab --yes --no-wait
```

If you're moving on to more labs against FS01 later, just stop the VMs in Lab 07 instead of destroying anything here.

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `00-create-test-users.ps1` fails to create identities | You lack Application Developer rights on the tenant | Create manually: Entra admin center → App registrations → New registration |
| `terraform apply`: principal not found | Object ID typo or wrong | Re-run the create script, confirm tfvars matches |
| `terraform apply`: resource group not found | Lab 07 isn't deployed or is in a different RG | Confirm with `az group list` |
| `plan` shows more than 3 resources | RG or VM name mismatch | Check exact capitalization against Lab 07 |
| Validation still shows FAIL after 10 min | Rare, but happens | Run `terraform state list` — confirm 3 `azurerm_role_assignment` resources exist, re-apply if not |
| `az vm stop` succeeds for Auditor | RBAC still propagating | Wait 5 more minutes, retest |