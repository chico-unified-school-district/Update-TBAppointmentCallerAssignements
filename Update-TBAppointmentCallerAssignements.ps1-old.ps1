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

# Functions

# ============================== Main ==================================
Clear-Host
. .\lib\Show-TestRun.ps1

Show-TestRun

Import-Module -Name 'SqlServer' -Cmdlet 'Invoke-SqlCmd' -Verbose:$false

function Clear-Callers ($dBparams, $baseSql, $table) {
 process {
  if ($_.clearCallers -eq $false) { return $_ }
  $sql = $baseSql -f $table, $_.testDate
  Write-Host ('{0},{1}' -f $MyInvocation.MyCommand.Name, $_.testDate) -F Magenta
  Write-Verbose ($sql | Out-String)
  if (!$WhatIf) { Invoke-Sqlcmd @dBparams -Query $sql }
  $_
 }
}

function Compare-Callers {
 begin {
 }
 process {
  if (!$_.assignedCallers -or !$_.appointmentCallers) { return $_ }
  Write-Verbose ("`n", "Assigned:", $_.assignedCallers, "`n", "Appointments:", $_.appointmentCallers | Out-String)
  $result = Compare-Object -ReferenceObject $_.assignedCallers -DifferenceObject $_.appointmentCallers
  $_.clearCallers = if ($result) { $true } else { $false }
  $_
 }
}

function Get-AllAppointmentsForDate ($dBparams, $baseSql, $table) {
 begin {
 }
 process {
  # Write-Host ('{0}' -f $MyInvocation.MyCommand.Name)
  $sql = $baseSql -f $table, $_.testDate
  # Get row id and assigned caller
  $_.appointmentsList = Invoke-SqlCmd @dBparams -Query $sql
  # | ConvertTo-Csv | ConvertFrom-Csv
  if (!$_.appointmentsList) { return }
  $_
 }
}

function Get-AssignedCallers ($dBparams, $baseSql, $table) {
 process {
  $sql = $baseSql -f $table, $_.testDate
  $_.assignedCallers = (Invoke-SqlCmd @dBparams -Query $sql).caller | Sort-Object
  Write-Verbose ('{0},Assigned Callers for {1},[{2}]' -f $MyInvocation.MyCommand.Name, $_.testDate, ($_.assignedCallers -join ','))
  if (!$_.assignedCallers) { return }
  $_
 }
}

function Get-AppointmentCallers {
 begin {
 }
 process {
  # Write-Host ('{0}' -f $MyInvocation.MyCommand.Name)
  $_.appointmentCallers = ($_.appointmentsList | Select-Object -Property caller -Unique).caller |
  ForEach-Object { if ($_ -match '\w') { $_ } } | Sort-Object
  $_
 }
}

function Get-TestingDates ($dBparams, $baseSql, $table) {
 process {
  $sql = $baseSql -f $table
  Write-Verbose ("{0},`n{1}" -f $MyInvocation.MyCommand.Name, $sql)
  Invoke-SqlCmd @dBparams -Query $sql
 }
}

function New-CallsObject {
 begin {
 }
 process {
  # Write-Host ('{0}' -f $MyInvocation.MyCommand.Name)
  $obj = '' | Select-Object -Property testDate, assignedCallers, appointmentCallers, appointmentsList, clearCallers
  $obj.testDate = $_.date
  $obj
 }
}

function Set-AllCallAssignments ($dBparams, $assignedBaseSql, $unassignedBaseSql, $updateBaseSql, $table) {
 begin {
  function Get-LowestCaller ($appointments) {
   process {
    Write-Verbose ('{0}' -f $MyInvocation.MyCommand.Name)
    $appointments.caller | Group-Object | Select-Object name, count | Sort-Object count | Select-Object -First 1
   }
  }

  function Update-CallerAssignment ($dbParams, $baseSql, $table, $caller, $id) {
   process {
    $sql = $baseSql -f $table, $caller, $id
    Write-Host ('{0},{2}' -f $MyInvocation.MyCommand.Name, $_.testDate, $sql) -f Blue
    if (!$WhatIf) { Invoke-SqlCmd @dBparams -Query $sql }
   }
  }

 }
 process {
  $assignedSql = $assignedBaseSql -f $table, $_.testDate

  $unassignedSql = $unassignedBaseSql -f $table, $_.testDate
  $unassignedCalls = $_.appointmentsList | Where-Object { $_.caller -notmatch '\w' }
  if (!$unassignedCalls) { return $_ } # no more unnassigned calls
  $i = 0
  do {
   $i++
   $unassignedCalls = Invoke-SqlCmd @dBparams -Query $unassignedSql
   if ($null -eq $unassignedCalls) { return $_ } # no more unnassigned calls
   Write-Verbose ('{0},Count: {1}' -f $MyInvocation.MyCommand.Name, $unassignedCalls.Count)
   $unassignedCallId = ($unassignedCalls | Select-Object -Property id -First 1).id
   Write-Verbose $unassignedCallId

   $assignedCalls = Invoke-SqlCmd @dBparams -Query $assignedSql
   $lowestCaller = (Get-LowestCaller $assignedCalls).name
   if ($lowestCaller) { Write-Verbose $lowestCaller }

   # if no callers then assign each caller a call
   if (!$lowestCaller) {
    foreach ($caller in $_.assignedCallers) {
     $unassignedCallsTemp = Invoke-SqlCmd @dBparams -Query $unassignedSql
     $id = ($unassignedCallsTemp | Select-Object caller -First 1).id
     Update-CallerAssignment $dBparams $updateBaseSql $table $caller $unassignedCallId
    }
   }
   else { Update-CallerAssignment $dBparams $updateBaseSql $table $lowestCaller $unassignedCallId }
  } until ( $null -eq (Invoke-SqlCmd @dBparams -Query $unassignedSql) -or
  (($i -eq $_.assignedCallers.count) -and $WhatIf ) # exit do/until when testing
  )
  $_
 }
}

$dbParams = @{
 Server                 = $SqlServer
 Database               = $SqlDatabase
 Credential             = $SqlCredential
 TrustServerCertificate = $true
}

$assignedCallerBaseSql = Get-Content .\sql\assignedCallers.sql -Raw
$clearAssignmentsBaseSql = Get-Content .\sql\clearAssignments.sql -Raw
# $firstUnnasignedAppointmentBaseSql = Get-Content .\sql\firstUnnasignedAppointment.sql -Raw
$unnasignedAppointmentsBaseSql = Get-Content .\sql\unnassignedAppointments.sql -Raw
$updateAppointmentBaseSql = Get-Content .\sql\updateAppointmentAssignment.sql -Raw
$selectTestingDatesBaseSql = Get-Content .\sql\selectTestingDates.sql -Raw
$allAppointmentsBaseSql = Get-Content .\sql\allAppointmentsForDate.sql -Raw
$allAssignedAppointmentsForDateBaseSql = Get-Content .\sql\allAssignedAppointmentsForDate.sql -Raw

#TODO FIX SQL Date range selectTestingDates.sql
Get-TestingDates $dbParams $selectTestingDatesBaseSql $AppointmentsTable |
New-CallsObject |
Get-AssignedCallers $dbParams $assignedCallerBaseSql $AssignmentsTable |
Get-AllAppointmentsForDate $dbParams $allAppointmentsBaseSql $AppointmentsTable |
Get-AppointmentCallers |
Compare-Callers |
Clear-Callers $dbParams $clearAssignmentsBaseSql $AppointmentsTable |
Set-AllCallAssignments $dbParams $allAssignedAppointmentsForDateBaseSql $unnasignedAppointmentsBaseSql $updateAppointmentBaseSql $AppointmentsTable

Show-TestRun