# failsafe
return

$presentationRoot = 'C:\Code\github\P2024-PSSummit-RunspaceWorkflows\code'

$workflow = New-PSFRunspaceWorkflow -Name 'ExampleWorkflow-Throttling'

$throttle = New-PSFThrottle -Interval '3s' -Limit 5
$workflow | Add-PSFRunspaceWorker -Name S1 -InQueue Q1 -OutQueue Q2 -Count 10 -ScriptBlock {
    param ($Value)
    Start-Sleep -Milliseconds 200
    [PSCustomObject]@{
        Value = $Value
        Stage1 = Get-Date
        Stage2 = $null
    }
} -CloseOutQueue
$workflow | Add-PSFRunspaceWorker -Name S2 -InQueue Q2 -OutQueue Q3 -Count 10 -ScriptBlock {
    param ($Value)
    $Value.Stage2 = Get-Date
    $Value
} -CloseOutQueue -Throttle $throttle

$workflow | Write-PSFRunspaceQueue -Name Q1 -BulkValues (1..20) -Close
$workflow | Start-PSFRunspaceWorkflow -PassThru | Wait-PSFRunspaceWorkflow -WorkerName S2 -Closed -PassThru | Stop-PSFRunspaceWorkflow
$results = $workflow | Read-PSFRunspaceQueue -Name Q3 -All
$workflow | Remove-PSFRunspaceWorkflow
$results


# Wait UNTIL
$workflow = New-PSFRunspaceWorkflow -Name 'ExampleWorkflow-Throttling2'

$throttle = New-PSFThrottle -Interval '1m' -Limit 100
$workflow | Add-PSFRunspaceWorker -Name S1 -InQueue Q1 -OutQueue Q2 -Count 1 -ScriptBlock {
    param ($Value)
    Start-Sleep -Milliseconds 200
    [PSCustomObject]@{
        Value = $Value
        Stage1 = Get-Date
        Stage2 = $null
    }
} -CloseOutQueue
$workflow | Add-PSFRunspaceWorker -Name S2 -InQueue Q2 -OutQueue Q3 -Count 2 -ScriptBlock {
    param ($Value)
    if (10 -eq $Value.Value) {
        $__PSF_Worker.Throttle.NotBefore = (Get-Date).AddSeconds(10)
    }
    $Value.Stage2 = Get-Date
    $Value
} -CloseOutQueue -Throttle $throttle

$workflow | Write-PSFRunspaceQueue -Name Q1 -BulkValues (1..20) -Close
$workflow | Start-PSFRunspaceWorkflow -PassThru | Wait-PSFRunspaceWorkflow -WorkerName S2 -Closed -PassThru | Stop-PSFRunspaceWorkflow
$results = $workflow | Read-PSFRunspaceQueue -Name Q3 -All
$workflow | Remove-PSFRunspaceWorkflow

$results

#----------------------------------------------------------------------------# 
#                                    Done!                                   # 
#----------------------------------------------------------------------------# 