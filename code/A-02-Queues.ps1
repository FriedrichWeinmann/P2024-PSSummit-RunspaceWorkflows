# failsafe
return

$presentationRoot = 'C:\Code\github\P2024-PSSummit-RunspaceWorkflows\code'

#region Functions
function Get-DataSlowly {
	[CmdletBinding()]
	param (
		[int]
		$Count = 5
	)

	foreach ($number in 1..$Count) {
		Start-Sleep -Seconds 1
		$number
	}
}
function Write-Input {
	[CmdletBinding()]
	param (
		[Parameter(ValueFromPipeline = $true)]
		$InputObject
	)

	process {
		Write-Host "$(Get-Date -Format 'HH:mm:ss.fff'): Received item: $InputObject"
	}
}
#endregion Functions

# Getting Data before command is done
Get-DataSlowly | Write-Input

# Queues
$queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
$queue.Enqueue(1)
$queue.Enqueue(2)

$result = $null
$queue.TryDequeue([ref]$result)
$result # 1
$queue.TryDequeue([ref]$result)
$result # 2
$queue.TryDequeue([ref]$result) # false
$result

$processing = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
$param = @{
	Variables   = @{ processing = $processing }
	Functions   = 'Get-DataSlowly'
	Throttle    = 1
	InputObject = 'NoMatter'
}
$job1 = Invoke-Runspace @param -Scriptblock {
	Get-DataSlowly -Count 30 | ForEach-Object {
		$processing.Enqueue($_)
	}
}
$job2 = Invoke-Runspace @param -Scriptblock {
	$value = $null
	$count = 0
	$attempts = 0
	while ($count -lt 30) {
		$attempts++
		if (-not $processing.TryDequeue([ref]$value)) {
			Start-Sleep -Milliseconds 250
			continue
		}
		$count++
		[PSCustomObject]@{
			Timestamp = Get-Date
			Value     = $value
			Attempt   = $attempts
		}
	}
}
$job1
$job2
$processing.Count
$job1.Collect()
$results = $job2.Collect()
$results

# Continue: Next
code "$presentationRoot\A-03-Status.ps1"
# Continue: Runspace Workflows
code "$presentationRoot\B-01-RunspaceWorkflows.ps1"