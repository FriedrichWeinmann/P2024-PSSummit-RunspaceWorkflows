# failsafe
return

$presentationRoot = 'C:\Code\github\P2024-PSSummit-RunspaceWorkflows\code'

$values = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
foreach ($id in 1..5) {
	$values.Enqueue($id)
}

$param = @{
	Variables = @{
		values = $values
	}
	Throttle = 3
	Wait = $true
}

1..10 | Invoke-Runspace @param -Scriptblock {
	param ($Value)
	if (-not $myID) {
		$myId = $null
		$null = $values.TryDequeue([ref]$myId)
	}
	[PSCustomObject]@{
		Value = $Value
		Agent = $myID
	}
}
#-> Missing IDs/Empty IDs? Runspacepools recycle runspaces

$values = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
foreach ($id in 1..5) {
	$values.Enqueue($id)
}

$param = @{
	Variables = @{
		values = $values
	}
	Throttle = 3
	Wait = $true
}

1..10 | Invoke-Runspace @param -Scriptblock {
	param ($Value)
	if (-not $myID) {
		$myId = $null
		$null = $values.TryDequeue([ref]$myId)
	}
	[PSCustomObject]@{
		Value = $Value
		Agent = $myID
	}
	Start-Sleep -Milliseconds 200
}

# Continue: Runspace Workflows
code "$presentationRoot\B-01-RunspaceWorkflows.ps1"