# https://stackoverflow.com/questions/64187004/powershell-selecting-noteproperty-type-objects-from-object
# Add your variable group id into this array before executing.
$VariableGroupId = @()
$AppSettingsPath = 'C:\temp\appsettingsDev.json'
$Org = "https://dev.azure.com/*****"
$Project = "*****"
##########################################################

foreach($Id in $VariableGroupId) {
	function Get-LeafProperty {
	  param([Parameter(ValueFromPipeline)] [object] $InputObject, [string] $NamePath)
	  process {   
		if ($null -eq $InputObject -or $InputObject -is [DbNull] -or $InputObject.GetType().IsPrimitive -or $InputObject.GetType() -in [string], [datetime], [datetimeoffset], [decimal], [bigint]) {
		  [pscustomobject] @{ NamePath = $NamePath; Value = $InputObject }
		}
		elseif ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [System.Collections.IDictionary]) {
		  $i = 0
		  foreach ($o in $InputObject) { Get-LeafProperty $o ($NamePath + '_' + $i++ + '_') }
		}
		else { 
		  $props = if ($InputObject -is [System.Collections.IDictionary]) { $InputObject.GetEnumerator() } else { $InputObject.psobject.properties }
		  $sep = '.' * ($NamePath -ne '')
		  foreach ($p in $props) {
			Get-LeafProperty $p.Value ($NamePath + $sep + $p.Name)
		  }
		}
	  }
	}

	$GetJson = Get-Content -path $AppSettingsPath -Encoding UTF8 -Raw
	$GetJson = $GetJson -replace '(?m)(?<=^([^"]|"[^"]*")*)//.*' -replace '(?ms)/\*.*?\*/' -replace '(?m)^\s*$\n'
	
	$HashTableFinal = $GetJson | ConvertFrom-Json | Get-LeafProperty | Sort-Object -Property NamePath
	
	foreach ($h in $HashTableFinal.GetEnumerator()) {
		# condition for true/false values. The Variable groups has issues with syntax occasionally
		if($($h.Value) -eq $false -or $($h.Value) -eq $true) {
			write-host "Updating vargroup Id -- $Id"
			az pipelines variable-group variable create --group-id $Id --name $($h.NamePath) --value $($h.Value) --output table --organization $Org --project $Project
		# condition for null values
		} elseif (!$($h.Value)) {
			write-host "Updating vargroup Id -- $Id"
			az pipelines variable-group variable create --group-id $Id --name $($h.NamePath) --output table --organization $Org --project $Project
		} else {
			write-host "Updating vargroup Id -- $Id"
			az pipelines variable-group variable create --group-id $Id --name $($h.NamePath) --value $($h.Value) --output table --organization $Org --project $Project
		}
	} 
}
