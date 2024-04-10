# failsafe
return

$presentationRoot = 'C:\Code\github\P2024-PSSummit-RunspaceWorkflows\code'

function Get-Numbers {
	[CmdletBinding()]
	param (
		[int]
		$Count
	)

	foreach ($number in 1..$Count) {
		Start-Sleep -Milliseconds (Get-Random -Minimum 50 -Maximum 200)
		$number
	}
}

$workflow = New-PSFRunspaceWorkflow -Name 'ExampleWorkflow-FirstStepData'
$functions = @{
	'Get-Numbers' = (Get-Command Get-Numbers).Definition
}
$workflow | Add-PSFRunspaceWorker -Name Source -InQueue Input -OutQueue Process -ScriptBlock {
	Get-Numbers -Count $_ | Write-PSFRunspaceQueue -Name Process -WorkflowName '' -InputObject $null
} -Count 1 -KillToStop -CloseOutQueue -Functions $functions

$workflow | Add-PSFRunspaceWorker -Name Processor -InQueue Process -OutQueue Results -Count 2 -ScriptBlock {
	[PSCustomObject]@{
		Timestamp = Get-Date
		Value = $_
	}
	Start-Sleep -Milliseconds 400
} -CloseOutQueue
$workflow | Write-PSFRunspaceQueue -Name Input -Value 100 -Close

$workflow | Start-PSFRunspaceWorkflow -PassThru
$workflow

$workflow | Wait-PSFRunspaceWorkflow -WorkerName Processor -Closed -PassThru | Stop-PSFRunspaceWorkflow
$results = $workflow | Read-PSFRunspaceQueue -Name Results -All
$workflow | Remove-PSFRunspaceWorkflow
$results

# Continue: Next
code "$presentationRoot\B-06-BeginAndEnd.ps1"