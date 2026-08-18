<#
.SYNOPSIS
.DESCRIPTION
.EXAMPLE
.INPUTS
.OUTPUTS
.NOTES
.LINK
#>

[cmdletbinding()]
param (
 # Laserfiche DB Server
 [Parameter(Mandatory = $true)]
 [string]$SqlServer,
 [Parameter(Mandatory = $true)]
 [string]$SqlDatabase,
 [Parameter(Mandatory = $true)]
 [System.Management.Automation.PSCredential]$SqlCredential,
 [string]$AppointmentsTable,
 [string]$CallersTable,
 [string]$RunUntil,
 [switch]$Wait,
 [Alias('wi')][switch]$WhatIf
)

function Clear-Callers ($dBparams, $sql) {
 process {
  if ($_.clearCallers -ne $true) { return $_ }
  Write-Host ('{0},{1}' -f $MyInvocation.MyCommand.Name, ($_.date -split ' ')[0]) -F DarkCyan
  $sqlVars = "date=$($_.date)"
  Write-Verbose ('{0},{1},{2}' -f $MyInvocation.MyCommand.Name, $sql, ($sqlVars -join ','))
  if (!$WhatIf) { New-SqlOperation @dBparams -Query $sql -Parameters $sqlVars }
  $_
 }
}

function New-PSObject {
 process {
  [array]$callers = foreach ($item in ($_.caller1, $_.caller2, $_.caller3)) {
   if ($item -match '\w') { $item }
  }
  [PSCustomObject]@{
   appts           = $null
   callers         = $callers
   clearCallers    = $false
   date            = $_.date
   msgInfo         = $null
   newAssignments  = $null
   nextCaller      = $null
   unassignedAppts = $null
  }
 }
}

function Out-Object {
 process {
  Write-Verbose ("$($MyInvocation.MyCommand.Name),$($_.msgInfo)", $_ | Format-List | Out-String)
  if ($Wait) { Read-Host ('{0}' -f ('x' * 50)) }
 }
}

function Set-PropAppts ($apptsData) {
 process {
  $callDate = $_.date
  $results = $apptsData.Where({ $_.date -eq $callDate })
  if (!$results) { return } # No need to assign caller(s) if no appointments exist for this date
  $_.appts = $results
  $_
 }
}

function Set-PropNewAssignment {
 process {
  $index = $_.callers.IndexOf($_.nextCaller)
  $_.newAssignments = foreach ($appt in $_.unassignedAppts) {
   # Write-Verbose ('{0},index {1},caller count {2}' -f $MyInvocation.MyCommand.Name, $index, $assignedCallers.count)
   $callerName = $_.callers[$index % $_.callers.count]
   # Write-Verbose ('{0},{1},{2},{3},modulo: {4}' -f $MyInvocation.MyCommand.Name, $_.msgInfo, $appt.id, $callerName, ($index % $_.callers.count))
   [PSCustomObject]@{
    id   = $appt.id
    name = $callerName
   }
   $index++
  }
  $_
 }
}

function Set-PropClearCallers {
 process {
  [array]$apptsCallers = $_.appts.nurseName.Where({ $_ -match '\w' }) | Select-Object -Unique
  $callerRemoved = foreach ($name in $apptsCallers) {
   if ($_.callers -notcontains $name ) { $true } # Currently assigned caller not in callers list
  }
  <# (Caller count changes AND total appointments exceed caller count AND at least one call has been assigned) OR
  (a caller has been removed) #>
  if ( ($_.callers.count -ne $apptsCallers.count -and $_.appts.count -gt $_.callers.count -and $apptsCallers.count -gt 0 ) -or
   $callerRemoved -eq $true) {
   $msg = $MyInvocation.MyCommand.Name, $_.msgInfo, $_.callers.count, $apptsCallers.count, $callerRemoved
   Write-Verbose ('{0},{1},Callers Count: {2}, Appts Callers Count: {3}, Callers Changed: {4}' -f $msg)
   $_.clearCallers = $true
  }
  $_
 }
}

function Set-PropNextCaller {
 process {
  [array]$apptCallers = ($_.appts.Where({ $_.nurseName -match '\w' }) | Sort-Object -Property id).nurseName
  $lastCaller = if ($apptCallers.count -gt 0) { $apptCallers[-1] } else { $_.callers[0] } # If none assigned then start fresh!
  $lastCallerIndex = if ($apptCallers.count -gt 0) { $_.callers.IndexOf($lastCaller) } else { 0 } # If none assigned then start fresh!
  $_.nextCaller = if ($apptCallers.count -ge 1 -and $_.callers.count -gt 1) {
   $_.callers[($lastCallerIndex + 1) % $_.callers.count]
  }
  else { $lastCaller } # if none assigned then start fresh!
  Write-Verbose ('{0},{1},last: [{2}], next: [{3}]' -f $MyInvocation.MyCommand.Name, $_.msgInfo, $lastCaller, $_.nextCaller)
  $_
 }
}

function Set-PropMsgInfo {
 process {
  $_.msgInfo = '[[{0}],[{1}],[{2}]]' -f $_.date.Split(' ')[0], ($_.callers -join '|'), $_.appts.count
  $_
 }
}

function Set-PropUnassignedAppts ($instance, $sql) {
 process {
  $queryParams = @{date = $($_.date) }
  $params = @{
   SqlInstance  = $instance
   Query        = $sql
   SqlParameter = $queryParams
  }
  $_.unassignedAppts = Invoke-DbaQuery @params | ConvertTo-Csv | ConvertFrom-Csv
  # if (!$_.unassignedAppts) { return }
  $_
 }
}

function Update-Assignment ($instance, $sql) {
 process {
  $i = $_.appts.count
  foreach ($item in $_.newAssignments) {
   $sqlVars = "id=$($item.id)", "nurse=$($item.name)"
   Write-Verbose ('{0},{1},Remaining: [{2}]' -f $MyInvocation.MyCommand.Name, $_.msgInfo, $i)
   Write-Host ('{0},{1},[{2}],[{3}]' -f $MyInvocation.MyCommand.Name, $_.msgInfo, $sql, ($sqlVars -join ',')) -F Blue
   # Write-Host ('{0},[{1}],id:[{2}],nurse:[{3}]' -f $MyInvocation.MyCommand.Name, $sql, ($sqlVars -join ',')) -F Blue
   if ($Wait) { Read-Host 'Update entry?' | Out-Null }
   # if (!$WhatIf) { Invoke-DbaQuery -SqlInstance $instance -Query $sql -SqlParameter $queryParams }
   if (!$WhatIf) { New-SqlOperation -Server $instance -Query $sql -Parameters $sqlVars }
   $i--
  }
  $_
 }
}

# ============================================================================================

Import-Module -Name CommonScriptFunctions -Cmdlet New-SqlOperation, Show-BlockInfo , Show-TestRun
Import-Module -Name dbatools -Cmdlet Connect-DbaInstance, Invoke-DbaQuery, Set-DbatoolsConfig

if ($WhatIf) { Show-TestRun }
Show-BlockInfo main

$dbParams = @{
 SqlInstance   = $SqlServer
 Database      = $SqlDatabase
 SqlCredential = $SqlCredential
}
$sqlInstance = Connect-DbaInstance @dbParams

$appointmentsSql = (Get-Content .\sql\select-upcoming-appointments.sql -Raw) -f $AppointmentsTable
$callerSql = (Get-Content .\sql\select-upcoming-callers.sql -Raw) -f $CallersTable
$clearAssignmentsSql = (Get-Content .\sql\clear-assignments.sql -Raw) -f $AppointmentsTable
$unassignedApptsSql = (Get-Content .\sql\select-unnassigned.sql -Raw) -f $AppointmentsTable
$updateAssignmentSql = (Get-Content .\sql\update-assignment.sql -Raw) -f $AppointmentsTable

$stopTime = if ($WhatIf) { Get-Date -f 'hh:mmtt' } elseif ((Get-Date).DayOfWeek -eq 'Wednesday') { $RunUntil } else { '5:00PM' }
Write-Host "Table: $AppointmentsTable - Runs until $stopTime" -F Green

do {
 $callers = Invoke-DbaQuery -SqlInstance $sqlInstance -Query $callerSql | ConvertTo-Csv | ConvertFrom-Csv
 $appointments = Invoke-DbaQuery -SqlInstance $sqlInstance -Query $appointmentsSql | ConvertTo-Csv | ConvertFrom-Csv
 $callers |
  New-PSObject |
   Set-PropAppts -apptsData $appointments |
    Set-PropMsgInfo |
     Set-PropClearCallers |
      Clear-Callers -dBparams $sqlInstance -sql $clearAssignmentsSql |
       Set-PropUnassignedAppts -instance $sqlInstance -sql $unassignedApptsSql |
        Set-PropNextCaller |
         Set-PropNewAssignment |
          Update-Assignment -instance $sqlInstance -sql $updateAssignmentSql |
           Out-Object

 if ($WhatIf) { break }
 Write-Verbose ('Next Run at {0}' -f ((Get-Date).AddSeconds(300)))
 Start-Sleep 300

} until ($WhatIf -or ((Get-Date) -ge (Get-Date $stopTime)))

Show-BlockInfo End
if ($WhatIf) { Show-TestRun }