# failsafe
return

$presentationRoot = 'C:\Code\github\P2024-PSSummit-RunspaceWorkflows\code'

$workflow = New-PSFRunspaceWorkflow -Name 'ExampleWorkflow-Closing'

$workflow | Write-PSFRunspaceQueue -Name Input -BulkValues (1..1000) -Close

$workflow | Add-PSFRunspaceWorker -Name Processing -InQueue Input -OutQueue Processed -Count 3 -ScriptBlock {
    param ($Value)

	Start-Sleep -Milliseconds 15
    [PSCustomObject]@{
        Input = $Value
        Processed = $Value * 2
        Result = $null
    }
} -CloseOutQueue
$workflow | Add-PSFRunspaceWorker -Name Result -InQueue Processed -OutQueue Done -Count 2 -ScriptBlock {
    param ($Value)

	Start-Sleep -Milliseconds 10
    $Value.Result = $Value.Processed * 3
    $Value
} -CloseOutQueue

$workflow | Start-PSFRunspaceWorkflow

$workflow | Wait-PSFRunspaceWorkflow -WorkerName Result -Closed -PassThru | Stop-PSFRunspaceWorkflow
$results = $workflow | Read-PSFRunspaceQueue -Name Done -All
$workflow | Remove-PSFRunspaceWorkflow
$results.Count
$results[0..10]

# Continue: Next
code "$presentationRoot\B-04-Resources.ps1"