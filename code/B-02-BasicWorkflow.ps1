# failsafe
return

$presentationRoot = 'C:\Code\github\P2024-PSSummit-RunspaceWorkflows\code'

# Create Workflow
$workflow = New-PSFRunspaceWorkflow -Name 'ExampleWorkflow'

# Add Workers
$workflow | Add-PSFRunspaceWorker -Name Processing -InQueue Input -OutQueue Processed -Count 3 -ScriptBlock {
    [PSCustomObject]@{
        Input = $_
        Processed = $_ * 2
        Result = $null
    }
}
$workflow | Add-PSFRunspaceWorker -Name Result -InQueue Processed -OutQueue Done -Count 2 -ScriptBlock {
    $_.Result = $_.Processed * 3
    $_
}

# Add input
$workflow | Write-PSFRunspaceQueue -Name Input -BulkValues (1..1000)

# Start Workflow
$workflow | Start-PSFRunspaceWorkflow

# Wait for Workflow to complete and stop it
$workflow | Wait-PSFRunspaceWorkflow -Queue Done -Count 1000 -PassThru | Stop-PSFRunspaceWorkflow

# Retrieve results
$results = $workflow | Read-PSFRunspaceQueue -Name Done -All

# Final Cleanup
$workflow | Remove-PSFRunspaceWorkflow

$results[0..20]
$results.Count

# Continue: Next
code "$presentationRoot\B-03-ClosingQueues.ps1"