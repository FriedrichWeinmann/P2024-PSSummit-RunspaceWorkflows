﻿
#region That Runspace Thing
function Invoke-Runspace {
	<#
	.SYNOPSIS
		Execute code in parallel.
	
	.DESCRIPTION
		Execute code in parallel.
		Will run the provided code for each item provided in parallel.
	
	.PARAMETER Scriptblock
		The code to parallelize.
	
	.PARAMETER Variables
		Variables to provide in each iteration.
	
	.PARAMETER Functions
		Functions to inject into the parallel tasks.
		Provide either function object or name.
	
	.PARAMETER Modules
		Modules to pre-import for each execution.
	
	.PARAMETER Throttle
		How many parallel executions should be performed.
		Defaults to 4 times the number of CPU cores.
	
	.PARAMETER Wait
		Whether to wait for it all to complete.
		Otherwise the command will return an object with a .Collect() method to wait for completion and retrieve results.
	
	.PARAMETER InputObject
		The items for which to create parallel runspaces.
	
	.EXAMPLE
		PS C:\> Get-Mailbox | Invoke-Runspace -ScriptBlock $addADData

		For each mailbox retrieved, execute the code stored in $addADData
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[scriptblock]
		$Scriptblock,

		[hashtable]
		$Variables,

		$Functions,

		$Modules,

		[int]
		$Throttle = ($env:NUMBER_OF_PROCESSORS * 4),

		[switch]
		$Wait,

		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		$InputObject
	)

	begin {
		#region Functions
		function Add-SSVariable {
			[CmdletBinding()]
			param (
				[Parameter(Mandatory = $true)]
				[System.Management.Automation.Runspaces.InitialSessionState]
				$SessionState,

				[Parameter(Mandatory = $true)]
				[hashtable]
				$Variables
			)

			foreach ($pair in $Variables.GetEnumerator()) {
				$variable = [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new($pair.Key, $pair.Value, "")
				$null = $SessionState.Variables.Add($variable)
			}
		}
		
		function Add-SSFunction {
			[CmdletBinding()]
			param (
				[Parameter(Mandatory = $true)]
				[System.Management.Automation.Runspaces.InitialSessionState]
				$SessionState,

				[Parameter(Mandatory = $true)]
				$Functions
			)

			foreach ($function in $Functions) {
				$functionDefinition = $function
				if ($function -is [string]) { $functionDefinition = Get-Command $function }

				$commandEntry = [System.Management.Automation.Runspaces.SessionStateFunctionEntry]::new(
					$functionDefinition.Name,
					$functionDefinition.Definition
				)
				$null = $SessionState.Commands.Add($commandEntry)
			}
		}
		
		function Add-SSModule {
			[CmdletBinding()]
			param (
				[Parameter(Mandatory = $true)]
				[System.Management.Automation.Runspaces.InitialSessionState]
				$SessionState,

				[Parameter(Mandatory = $true)]
				$Modules
			)

			foreach ($module in $Modules) {
				$moduleInfo = $module
				if ($module.ModuleBase) { $moduleInfo = $module.ModuleBase }
				$moduleSpec = [Microsoft.PowerShell.Commands.ModuleSpecification]::new($moduleInfo)
				$null = $SessionState.Modules.Add($moduleSpec)
			}
		}
		#endregion Functions

		$sessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
		if ($Variables) { Add-SSVariable -SessionState $sessionState -Variables $Variables }
		if ($Functions) { Add-SSFunction -SessionState $sessionState -Functions $Functions }
		if ($Modules) { Add-SSModule -SessionState $sessionState -Modules $Modules }

		$pool = [RunspaceFactory]::CreateRunspacePool($sessionState)
		$Null = $pool.SetMinRunspaces(1)
		$Null = $pool.SetMaxRunspaces($Throttle)
		$pool.ApartmentState = "MTA"
		$pool.Open()

		$result = [PSCustomObject]@{
			PSTypeName = 'Runspace.Job'
			Pool       = $pool
			Runspaces  = [System.Collections.ArrayList]@()
		}
		Add-Member -InputObject $result -MemberType ScriptMethod -Name Collect -Value {
			try {
				# Receive Results and cleanup
				foreach ($runspace in $this.Runspaces) {
					$runspace.Pipe.EndInvoke($runspace.Status)
					$runspace.Pipe.Dispose()
				}
			}
			finally {
				# Cleanup Runspace Pool
				$this.Pool.Close()
				$this.Pool.Dispose()
			}
		}
		Add-Member -InputObject $result -MemberType ScriptMethod -Name Kill -Value {
			try {
				# Kill it with fire
				foreach ($runspace in $this.Runspaces) {
					$runspace.Pipe.Dispose()
				}
			}
			finally {
				# Cleanup Runspace Pool
				$this.Pool.Close()
				$this.Pool.Dispose()
			}
		}
	}
	process {
		#region Set up new Runspace
		$runspace = [PowerShell]::Create()
		$null = $runspace.AddScript($Scriptblock)
		$null = $runspace.AddArgument($InputObject)
		$runspace.RunspacePool = $pool
		$rsObject = [PSCustomObject]@{
			Pipe   = $runspace
			Status = $runspace.BeginInvoke()
		}
		$null = $result.Runspaces.Add($rsObject)
		#endregion Set up new Runspace
	}
	end {
		if ($Wait) { $result.Collect() }
		else { $result }
	}
}
#endregion That Runspace Thing

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

function Get-RandomNumberSet {
	[CmdletBinding()]
	param ()

	process {
		1..(Get-Random -Minimum 200 -Maximum 500)
	}
}

#region C# Incrementer Code
$source = @'
using System;
using System.Threading;

namespace Freds.Awesome
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