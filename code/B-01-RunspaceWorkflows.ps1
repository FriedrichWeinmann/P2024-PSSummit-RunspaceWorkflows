# failsafe
return

$presentationRoot = 'C:\Code\github\P2024-PSSummit-RunspaceWorkflows\code'

# Install the module
Install-PSResource PSFramework
<#
Project Website:
https://psframework.org

Runspace Workflow Docs:
TODO: Add link to docs landing page
#>

<#
Core Concepts:
- Workflow: The entire construct of actions together
- Worker: A single Step / Action
- Queue: Managed data exchange between workers
#>

# Continue: Next
code "$presentationRoot\B-02-BasicWorkflow.ps1"