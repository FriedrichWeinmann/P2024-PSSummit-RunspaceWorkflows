﻿# failsafe
return

$presentationRoot = 'C:\Code\github\P2024-PSSummit-RunspaceWorkflows\code'

$workflow = New-PSFRunspaceWorkflow -Name 'ExampleWorkflow-BeginEnd'

$begin = {
    $global:sqlInstance = Connect-DbaInstance -SqlInstance sql01.contoso.com\userdb
}
$process = {
    $_ | Write-DbaDataTable -SqlInstance $global:sqlInstance -Database userDB -Table Users
}
$end = {
    Disconnect-DbaInstance $global:sqlInstance
}

$workflow | Add-PSFRunspaceWorker -Name Users -InQueue UserList -OutQueue Users -Count 5 -ScriptBlock {
    Get-ADUser -Identity $_
} -CloseOutQueue
$workflow | Add-PSFRunspaceWorker -Name WriteToDB -InQueue Users -OutQueue Done -Count 1 -Begin $begin -ScriptBlock $process -End $end -CloseOutQueue

# Add values and execute
$workflow | Write-PSFRunspaceQueue -Name UserList -BulkValues $users -Close
$workflow | Start-PSFRunspaceWorkflow -PassThru | Wait-PSFRunspaceWorkflow -WorkerName WriteToDB -Closed -PassThru | Remove-PSFRunspaceWorkflow

# Continue: Next
code "$presentationRoot\B-07-Throttling.ps1"