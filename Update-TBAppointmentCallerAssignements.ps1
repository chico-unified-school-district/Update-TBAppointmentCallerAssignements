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
 [string]$AssignmentsTable,
 [string]$RunUntil,
 [Alias('wi')]
	[switch]$WhatIf
)

function Clear-Callers ($dBparams, $sql) {
 process {
  Write-Verbose ($_ | out-string)
  if (!$_.clearCallers) { return $_ }
  # Write-Verbose ('{0},{1}' -f $MyInvocation.MyCommand.Name, $_.testDate)
  Write-Host ('{0},{1}' -f $MyInvocation.MyCommand.Name, ($_.testDate -split ' ')[0]) -F DarkCyan
  $sqlVars = "date=$($_.testDate)"
  Write-Verbose ('{0},{1}' -f $MyInvocation.MyCommand.Name, $sql, ($sqlVars -join ','))
  # Write-Verbose ($sql | Out-String)
  if (!$WhatIf) { New-SqlOperation @dBparams -Query $sql -Parameters $sqlVars }
  $_
 }
}

function Compare-CallersForClear {
 process {
  Write-Verbose ($_ | out-string)
  if ($null -eq $_.appointmentCallers) { return $_ }
  Write-Verbose ("`n", "Assigned:", $_.assignedCallers, "`n", "Appointments:", $_.appointmentCallers | Out-String)
  $changes = Compare-Object -ReferenceObject $_.assignedCallers -DifferenceObject $_.appointmentCallers
  $_.clearCallers = if ($changes) { $true } else { $false }
  $_
 }
}

function Get-AllAppointmentsForDate ($dBparams, $sql) {
 process {
  # Write-Host ('{0}' -f $MyInvocation.MyCommand.Name)
  $sqlVars = "date=$($_.testDate)"
  # Get row id and assigned caller
  $_.appointmentsList = New-SqlOperation @dBparams -Query $sql -Parameters $sqlVars | ConvertTo-Csv | ConvertFrom-Csv
  if (!$_.appointmentsList) { return }
  $_
 }
}

function Get-AssignedCallers ($dBparams, $sql) {
 process {
  $sqlVars = "date=$($_.testDate)"
  $_.assignedCallers = (New-SqlOperation @dBparams -Query $sql -Parameters $sqlVars).caller | Sort-Object
  Write-Verbose ('{0},{1},[{2}]' -f $MyInvocation.MyCommand.Name, $_.testDate, ($_.assignedCallers -join ','))
  if (!$_.assignedCallers) { return }
  $_
 }
}

function Get-AppointmentCallers {
 process {
  $_.appointmentCallers = ($_.appointmentsList | Select-Object -Property caller -Unique).caller |
   ForEach-Object { if ($_ -match '\w') { $_ } } | Sort-Object # Ensure both arrays are sorted equally
  $_
 }
}

function Get-TestingDates ($dBparams, $sql) {
 process {
  Write-Verbose ("{0},`n{1}" -f $MyInvocation.MyCommand.Name, $sql)
  New-SqlOperation @dBparams -Query $sql
 }
}

function New-CallsObject {
 begin {
 }
 process {
  $obj = '' | Select-Object -Property testDate, assignedCallers, appointmentCallers, appointmentsList, clearCallers
  $obj.testDate = $_.date
  $obj
 }
}

function Set-AllCallAssignments ($dBparams, $assignedSql, $unassignedSql, $updateBaseSql) {
 begin {
  function getLowestCaller ($appointments) {
   process {
    Write-Verbose ('{0}' -f $MyInvocation.MyCommand.Name)
    Write-Verbose ($appointments.caller | Group-Object | Select-Object name, count | Sort-Object count | out-string)
    $appointments.caller | Group-Object | Select-Object name, count | Sort-Object count | Select-Object -First 1
   }
  }

  function updateCallerAssignment ($dbParams, $sql, $caller, $id) {
   process {
    $sqlVars = "nurse=$caller", "id=$id"
    Write-Host ('{0},{1},[{2}],[{3}]' -f $MyInvocation.MyCommand.Name, ($_.testDate -split ' ')[0], $sql, ($sqlVars -join ',')) -f Blue
    if (!$WhatIf -and $id) {
     Write-Debug 'Proceed?'
     New-SqlOperation @dBparams -Query $sql -Parameters $sqlVars
    }
   }
  }

 }
 process {
  Write-Verbose ('{0},{1}' -f $MyInvocation.MyCommand.Name, $_.testDate)
  $unassignedCalls = New-SqlOperation @dBparams -Query $unassignedSql -Parameters "date=$($_.testDate)"
  Write-Verbose ('{0},Count: {1}' -f $MyInvocation.MyCommand.Name, $unassignedCalls.Count)
  if ($null -eq $unassignedCalls) {
   # no more unnassigned calls
   return Write-Verbose ('{0},{1},All calls assigned.' -f $MyInvocation.MyCommand.Name, $_.testDate)
  }
  $i = 0
  do {
   $i++
   $unassignedCalls = New-SqlOperation @dBparams -Query $unassignedSql -Parameters "date=$($_.testDate)"
   if ($null -eq $unassignedCalls) {
    # no more unnassigned calls
    return Write-Verbose ('{0},{1},All calls assigned.' -f $MyInvocation.MyCommand.Name, $_.testDate)
   }

   $assignedCalls = New-SqlOperation @dBparams -Query $assignedSql -Parameters "date=$($_.testDate)"
   $lowestCaller = (getLowestCaller $assignedCalls).name
   if ($lowestCaller) { Write-Verbose ('{0},Lowest Caller: {1}' -f $MyInvocation.MyCommand.Name, $lowestCaller) }

   # if no pre-existing callers then assign each caller a call
   if (!$lowestCaller) {
    # Set initial callers for test date
    foreach ($caller in $_.assignedCallers) {
     $unassignedCalls = New-SqlOperation @dBparams -Query $unassignedSql -Parameters "date=$($_.testDate)"
     if (!$unassignedCalls) { continue }
     $id = ($unassignedCalls | Select-Object id -First 1).id
     Write-Host ('{0},{1},{2},{3},Lowest caller loop' -f $MyInvocation.MyCommand.Name, $caller, $_.testDate, $id) -f Magenta
     updateCallerAssignment $dBparams $updateBaseSql $caller $id
    }
   }
   else {
    $unassignedCallId = ($unassignedCalls | Select-Object -Property id -First 1).id
    $msgVars = $MyInvocation.MyCommand.Name, $lowestCaller, $_.testDate, $unassignedCallId
    Write-Host ("{0},{1},{2},{3},Not 'Lowest Loop'" -f $msgVars) -f Magenta
    updateCallerAssignment $dBparams $updateBaseSql $lowestCaller $unassignedCallId
   }
  } until ( $null -eq (New-SqlOperation @dBparams -Query $unassignedSql -Parameters "date=$($_.testDate)") -or
   (($i -eq $_.assignedCallers.count) -and $WhatIf ) # exit do/until when testing
  )
  # $_
 }
}
# ============================================================================================

Import-Module -Name CommonScriptFunctions, dbatools

if ($WhatIf) { Show-TestRun }
Show-BlockInfo main


$dbParams = @{
 Server     = $SqlServer
 Database   = $SqlDatabase
 Credential = $SqlCredential
}

$assignedCallerSql = (Get-Content .\sql\assignedCallers.sql -Raw) -f $AssignmentsTable
$clearAssignmentsSql = (Get-Content .\sql\clearAssignments.sql -Raw) -f $AppointmentsTable
$unnasignedAppointmentsSql = (Get-Content .\sql\unnassignedAppointments.sql -Raw) -f $AppointmentsTable
$updateAppointmentSql = (Get-Content .\sql\updateAppointmentAssignment.sql -Raw) -f $AppointmentsTable
$selectTestingDatesSql = (Get-Content .\sql\selectTestingDates.sql -Raw) -f $AppointmentsTable
$allAppointmentsSql = (Get-Content .\sql\allAppointmentsForDate.sql -Raw ) -f $AppointmentsTable
$allAssignmentsForDateSql = (Get-Content .\sql\allAssignedAppointmentsForDate.sql -Raw) -f $AppointmentsTable

$RunUntil = '2:30pm'
Write-Host "Runs until $RunUntil"
do {
 Get-TestingDates $dbParams $selectTestingDatesSql |
  New-CallsObject |
   Get-AssignedCallers $dbParams $assignedCallerSql |
    Get-AllAppointmentsForDate $dbParams $allAppointmentsSql |
     Get-AppointmentCallers |
      Compare-CallersForClear |
       Clear-Callers $dbParams $clearAssignmentsSql |
        Set-AllCallAssignments $dbParams $allAssignmentsForDateSql $unnasignedAppointmentsSql $updateAppointmentSql
 if (!$WhatIf -and ((Get-Date) -lt (Get-Date $RunUntil))) {
  Write-Host ('Next Run at {0}' -f ((Get-Date).AddSeconds(600)))
  Start-Sleep 600
 }
} until ($WhatIf -or ((Get-Date) -ge (Get-Date $RunUntil)))

Show-BlockInfo End
if ($WhatIf) { Show-TestRun }