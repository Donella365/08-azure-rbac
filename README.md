# 08 Azure RBAC Lab
Azure RBAC · Service Principals · Terraform · PowerShell · Azure

## ▶️ Lab Walkthrough Video
*[Loom link goes here once recorded]*

## What This Lab Covers

This lab controls who can manage the FS01 virtual machine from Azure itself, separate from anything happening inside Windows. Lab 07 controlled which departments could open which folders. This lab controls a different question entirely: who can start, stop, delete, or reconfigure the FS01 server from the Azure side.

I deployed three role assignments scoped to FS01 only, each one tied to a Service Principal standing in for a real job function: a sysadmin with full control, a support technician who can restart the server but not delete it, and an auditor who can view its status but take no action at all. Terraform reads FS01 as an existing resource rather than creating anything new, and every role assignment is scoped to FS01's exact resource ID so nothing else in the resource group is affected.

The goal was to model least privilege at the infrastructure level: each identity gets exactly what its job requires, nothing more, and the enforcement is provable, not assumed.

## Focus Areas

| Area | What I did |
|---|---|
| Azure RBAC | Created 3 role assignments (Owner, VM Contributor, Reader) scoped to a single VM |
| Identity | Used Service Principals instead of user accounts, since the school tenant restricts new user creation to IT staff |
| Terraform | Used data sources to read Lab 07's existing FS01 VM without modifying it |
| Scoping | Pointed every role assignment at FS01's resource ID specifically, not the resource group |
| Validation | Confirmed the live Azure state directly with the CLI, separate from what Terraform's state file claims |
| Testing | Logged in as each Service Principal individually to prove enforcement, not just configuration |
| State management | Reused Lab 07's Terraform state storage account with a separate state file key |

## Architecture

![Lab 08 architecture diagram - identities, scope, and permission matrix](screenshots/01-diagram.png)

Three Service Principals, each mapped to one role, each scoped to FS01 only:

- **SysAdmin** — Owner. Full control on FS01, including managing who else has access.
- **SupportTech** — Virtual Machine Contributor. Can start, stop, and restart FS01. Cannot delete it or touch RBAC.
- **Auditor** — Reader. Can view FS01's configuration and status. Cannot take any action.

FS01 itself, along with DC01 and CLIENT01, comes from Lab 07's `RG-FileServerLab`. This lab reads that resource group, it does not deploy into it.

## Build Stages

### 1. Confirm Dependencies
Checked that Lab 07's resource group and FS01 VM exist before doing anything else. RBAC and the VMs are independent Terraform states, but the role assignments are meaningless without a real VM to scope them to.

### 2. Create Identities
Ran a script that creates three Service Principals through the Azure CLI instead of manually creating user accounts through the portal. This became necessary partway through: the original plan was to create Entra ID user accounts, but the school tenant restricts that to IT staff. Service Principals only need a much lower permission level, and they are arguably the more realistic choice anyway, since real organizations use them for scripted and automated access.

### 3. Configure
Pasted the three Object IDs the script printed into `terraform.tfvars`, along with the resource group and VM names matching Lab 07 exactly.

### 4. Deploy
Ran `terraform apply` to create the three role assignments. This step is fast, there is no VM to build, just permissions to attach to an existing one.

### 5. Validate
Ran a separate validation script against the live Azure state, not Terraform's state file. RBAC propagation can lag a few minutes after `apply` completes, so this step confirms the permissions are actually active in Azure, not just that Terraform believes it created them.

### 6. Test as Each Persona
Logged in individually as each Service Principal and tried actions specific to their role. A blocked action was the expected, correct result for lower-privilege identities, not a bug.

## Automation

The Service Principal creation is handled by `00-create-test-users.ps1`, which creates all three identities in one run and prints their Object IDs ready to paste into `terraform.tfvars`. Validation is handled separately by `validate-lab.ps1`, which queries Azure directly for the live role assignment state and exports a report.

Splitting deployment (Terraform) from validation (a separate script against live Azure state) mirrors how this should work in a real environment: infrastructure-as-code creates the configuration, but a real audit or compliance check confirms what is actually enforced.

## Verification

I validated this lab two ways: an automated script against live Azure state, and manual testing by logging in as each Service Principal directly.

**Validation:**
![Validation script output, all 3 role assignments PASS](screenshots/02-validate-lab-output.png)

**Auditor (Reader) test:**
![Auditor viewing FS01 details successfully](screenshots/03-auditor-view-succeeds.png)
![Auditor blocked from stopping FS01 with AuthorizationFailed](screenshots/04-auditor-stop-fails.png)

**SupportTech (VM Contributor) test:**
![SupportTech starting FS01 successfully, and also successfully listing role assignments](screenshots/05-supporttech.png)

This was the finding that corrected my original assumption. I expected VM Contributor to be blocked from viewing RBAC entirely. It wasn't. Almost every built-in Azure role includes read-only access to authorization data by default, which is how the Access Control tab works for any user in the portal. VM Contributor can see who has access. It cannot change it.

**SysAdmin (Owner) test — the real proof of Owner's unique power:**
![SysAdmin logged in and running the role assignment create command](screenshots/06-sysadmin-login-and-command.png)
![SysAdmin's role assignment create command succeeding](screenshots/07-sysadmin-create-role.png)

Since viewing RBAC turned out to be common across roles, the actual test that separates Owner from everyone else is a write action. I had SysAdmin create a new role assignment (an extra Reader role for SupportTech), which succeeded. Neither SupportTech nor Auditor could have done this. I removed the extra assignment afterward so FS01's live RBAC state matched exactly what Terraform manages.

## Security Decisions

A few design choices were intentional:

- Each role assignment is scoped to FS01's specific resource ID, not the resource group, so DC01 and CLIENT01 are unaffected.
- Service Principals were used instead of standing up real user accounts, avoiding unnecessary identities in the tenant.
- `terraform.tfvars` and the Service Principal credentials file are excluded from Git.
- Validation runs against live Azure state rather than trusting Terraform's state file alone.
- Terraform state for this lab uses its own key in the same storage account as Lab 07, keeping the two labs' state fully independent.

## What I Learned

The biggest takeaway was the difference between what a role's name implies and what it actually grants. I assumed Virtual Machine Contributor would be blocked from RBAC entirely, since the role name only mentions VMs. In reality, almost every built-in Azure role includes read-only access to authorization data, because that is what powers the Access Control tab in the portal for any signed-in user. Viewing permissions and managing permissions are two separate levels, and only testing the actual commands against live Azure revealed that. A role's description is a summary, not the full permission set.

I also ran into a real-world identity constraint that the original lab plan did not account for. School and organization tenants restrict new user account creation to IT staff, which meant the planned approach of creating three Entra ID test users was not something a student account could do. Switching to Service Principals solved it, and it turned out to be a more accurate model anyway, since organizations commonly use Service Principals for scripted and automated access rather than standing up fake human accounts for every test scenario.

Scoping mattered more than I expected going in. Pointing every role assignment at FS01's specific resource ID, rather than the resource group, meant DC01 and CLIENT01 were never touched. That is the actual mechanism behind the principle of least privilege, not just a policy statement.

## What I'd Do Differently

I would write the validation script to test a write action from the start, not just visibility. My first pass at testing SupportTech only checked whether it could view RBAC assignments, which led to a result that looked like a failure until I understood why it actually succeeded. Testing an actual create or delete action against RBAC from the beginning, the way I eventually did for SysAdmin, would have caught the real distinction (view vs. manage) without the detour.

I would also build the Service Principal credential handling with automatic cleanup in mind. I manually removed the extra role assignment SysAdmin created during testing, but a script that logs its own test actions and reverses them automatically would make repeat runs of this lab faster and less error-prone.

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `Set-ExecutionPolicy` error on script run | That cmdlet is Windows-only and does not exist on Linux PowerShell | Removed the line, it is unnecessary on this platform |
| Service Principal / user creation fails with a permissions warning | School tenant restricts new user creation to IT staff | Switched from Entra ID user accounts to Service Principals, which need a lower permission level |
| `terraform plan` finds no configuration | Ran the command from the project root instead of the `terraform/` subfolder | `cd terraform` before running `init` or `plan` |
| `az vm list` shows no status column | Basic `az vm list` does not include power state by default | Added the `-d` flag to include live VM status |

## Tools & Technologies
Azure · Azure RBAC · Microsoft Entra ID · Service Principals · Terraform · Azure CLI · PowerShell · Windows Server 2022
