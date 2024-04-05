# failsafe
return

$presentationRoot = 'C:\Code\github\P2024-PSSummit-RunspaceWorkflows\code'

# Dictionaries
$dictionary = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
$dictionary['Name'] = 'Fred'
$dictionary
$dictionary.Name

# As runspace status
$status = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
$processing = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()

$param = @{
	Variables   = @{
		processing = $processing
		status     = $status
	}
	Functions   = 'Get-DataSlowly'
	Throttle    = 1
	InputObject = 'NoMatter'
}
$job1 = Invoke-Runspace @param -Scriptblock {
	Get-DataSlowly -Count 15 | ForEach-Object {
		$processing.Enqueue($_)
	}
	$status['input'] = $true
}
$job2 = Invoke-Runspace @param -Scriptblock {
	$value = $null
	$attempts = 0
	while ($true) {
		$attempts++
		if (-not $processing.TryDequeue([ref]$value)) {
			if ($status.Input) { break }
			Start-Sleep -Milliseconds 250
			continue
		}
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
$status
$job1.Collect()
$results = $job2.Collect()
$results

#region Interrupt with variable input count

#region C# Incrementer Code
$source = @'
using System;
using System.Threading;

namespace Freds.Questionable
{
	public class Incrementer
	{
		public long Count;

		public void Increment()
		{
			Interlocked.Increment(ref Count);
		}
	}
}
'@
Add-Type $source
#endregion C# Incrementer Code

function Get-RandomNumberSet {
	[CmdletBinding()]
	param ()

	process {
		1..(Get-Random -Minimum 200 -Maximum 500)
	}
}

$processing = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
$result = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
$status = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
$incrementer = [Freds.Questionable.Incrementer]::new()

$param = @{
	Variables = @{
		processing  = $processing
		result      = $result
		incrementer = $incrementer
		status      = $status
	}
}

$job3 = Get-RandomNumberSet | Invoke-Runspace @param -Throttle 3 -Scriptblock {
	param ($Number)

	$datum = [PSCustomObject]@{
		Start    = Get-Date
		End      = $null
		Number   = $Number
		NewValue = $null
	}
	$processing.Enqueue($datum)
	$incrementer.Increment()
	Start-Sleep -Milliseconds 10
}
$job4 = Invoke-Runspace @param -InputObject 'Whatever' -Throttle 5 -Scriptblock {
	$value = $null
	while ($true) {
		if (-not $processing.TryDequeue([ref]$value)) {
			if ($status.Done) { break }
			Start-Sleep -Milliseconds 250
			continue
		}
		$value.NewValue = $value.Number * 2
		$value.End = Get-Date
		$result.Enqueue($value)
		Start-Sleep -Milliseconds 20
	}
}
$job3.Collect()

$incrementer.Count
$result.Count
while ($incrementer.Count -gt $result.Count) {
	Start-Sleep -Seconds 1
}
$status['Done'] = $true
$job4.Collect()
$result | Select-Object -First 40

#endregion Interrupt with variable input count


# Continue: Next
code "$presentationRoot\A-04-Throttling.ps1"
# Continue: Runspace Workflows
code "$presentationRoot\B-01-RunspaceWorkflows.ps1"