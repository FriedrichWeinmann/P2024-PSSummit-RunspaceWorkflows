# failsafe
return

$presentationRoot = 'C:\Code\github\P2024-PSSummit-RunspaceWorkflows\code'


## Variables

$workflow = New-PSFRunspaceWorkflow -Name 'ExampleWorkflow-Variables'

$variables = @{
    Multiplier = 3
}
$workflow | Add-PSFRunspaceWorker -Name Multiply -InQueue Numbers -OutQueue Results -Count 5 -ScriptBlock {
    param ($Value)
    Start-Sleep -Milliseconds 200
    [PSCustomObject]@{
        Input = $Value
        Multiplier = $Multiplier
        Result = $Value * $Multiplier
    }
} -Variables $variables -CloseOutQueue

$workflow | Write-PSFRunspaceQueue -Name Numbers -BulkValues (1..20) -Close
$workflow | Start-PSFRunspaceWorkflow -PassThru | Wait-PSFRunspaceWorkflow -WorkerName Multiply -Closed -PassThru
$workflow | Stop-PSFRunspaceWorkflow
$results = $workflow | Read-PSFRunspaceQueue -Name Results -All
$workflow | Remove-PSFRunspaceWorkflow

$results

## Variables (Per Runspace)

$workflow = New-PSFRunspaceWorkflow -Name 'ExampleWorkflow-VariablesPerRS'

$variables = @{
    Multiplier = 3,4,5,6,7
}
$workflow | Add-PSFRunspaceWorker -Name Multiply -InQueue Numbers -OutQueue Results -Count 5 -ScriptBlock {
    param ($Value)
    Start-Sleep -Milliseconds 200
    [PSCustomObject]@{
        Input = $Value
        Multiplier = $Multiplier
        Result = $Value * $Multiplier
    }
} -VarPerRunspace $variables -CloseOutQueue

$workflow | Write-PSFRunspaceQueue -Name Numbers -BulkValues (1..20) -Close
$workflow | Start-PSFRunspaceWorkflow -PassThru | Wait-PSFRunspaceWorkflow -WorkerName Multiply -Closed -PassThru
$workflow | Stop-PSFRunspaceWorkflow
$results = $workflow | Read-PSFRunspaceQueue -Name Results -All
$workflow | Remove-PSFRunspaceWorkflow

$results

## Functions

$workflow = New-PSFRunspaceWorkflow -Name 'ExampleWorkflow-Functions'

function Get-RandomNumber {
	[CmdletBinding()]
	param()
	Get-Random -Minimum 10 -Maximum 99
}
$functions = @{
	'Get-RandomNumber' = (Get-Command Get-RandomNumber).Definition
}

$workflow | Add-PSFRunspaceWorker -Name Multiply -InQueue Numbers -OutQueue Results -Count 5 -ScriptBlock {
    param ($Value)
    Start-Sleep -Milliseconds 200
    [PSCustomObject]@{
        Input = $Value
        Random = Get-RandomNumber
    }
} -Functions $functions -CloseOutQueue

$workflow | Write-PSFRunspaceQueue -Name Numbers -BulkValues (1..20) -Close
$workflow | Start-PSFRunspaceWorkflow -PassThru | Wait-PSFRunspaceWorkflow -WorkerName Multiply -Closed -PassThru | Stop-PSFRunspaceWorkflow
$results = $workflow | Read-PSFRunspaceQueue -Name Results -All
$workflow | Remove-PSFRunspaceWorkflow

$results

### Notes on functions and CLM
#-> This works in regular PowerShell only
$functions = @{
	'Get-RandomNumber' = (Get-Command Get-RandomNumber).Definition
}

#-> This works under CLM, assuming the defining code is trusted and not CLM-constrained
$functions = @{
	'Get-RandomNumber' = [ScriptBlock]::Create((Get-Command Get-RandomNumber).Definition)
}

## Modules
$workflow = New-PSFRunspaceWorkflow -Name 'ExampleWorkflow-Modules'

$workflow | Add-PSFRunspaceWorker -Name Multiply -InQueue Numbers -OutQueue Results -Count 5 -ScriptBlock {
    param ($Value)
    Start-Sleep -Milliseconds 200
    [PSCustomObject]@{
        Input = $Value
        Random = Get-RandomNumber
    }
} -Modules "$repoRoot\modules\MyModule\MyModule.psd1" -CloseOutQueue

$workflow | Write-PSFRunspaceQueue -Name Numbers -BulkValues (1..20) -Close
$workflow | Start-PSFRunspaceWorkflow -PassThru | Wait-PSFRunspaceWorkflow -WorkerName Multiply -Closed -PassThru | Stop-PSFRunspaceWorkflow
$results = $workflow | Read-PSFRunspaceQueue -Name Results -All
$workflow | Remove-PSFRunspaceWorkflow

$results


# Continue: Next
code "$presentationRoot\B-05-DataFromFirstStep.ps1"