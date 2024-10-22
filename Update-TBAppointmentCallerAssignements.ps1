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

function Get-TestingDates ($params, $baseSql, $table) {
 process {
  $sql = $baseSql -f $table
  Write-Verbose ("{0},`n{1}" -f $MyInvocation.MyCommand.Name, $sql)
  Invoke-SqlCmd @params -Query $sql
 }
}

function Get-AssignedCallers ($params, $baseSql, $table, $date) {
 process {
  $sql = $baseSql -f $table, $date
  Write-Verbose ('{0},Assigned Callers for {1}' -f $MyInvocation.MyCommand.Name, $date)
  Invoke-SqlCmd @params -Query $sql
 }
}

# ============================== Main ==================================
Clear-Host
. .\lib\Show-TestRun.ps1

Show-TestRun
Import-Module -Name 'SqlServer' -Cmdlet 'Invoke-SqlCmd'

$dbParams = @{
 Server                 = $SqlServer
 Database               = $SqlDatabase
 Credential             = $SqlCredential
 TrustServerCertificate = $true
}

# ============================
$assignedCallerSql = Get-Content .\sql\assignedCallers.sql -Raw
$clearAssignmentsBaseSql = Get-Content .\sql\clearAssignments.sql -Raw
$firstUnnasignedAppointmentBaseSql = Get-Content .\sql\firstUnnasignedAppointment.sql -Raw
$unnasignedAppointmentsBaseSql = Get-Content .\sql\unnassignedAppointments.sql -Raw
$updateAppointmentBaseSql = Get-Content .\sql\updateAppointmentAssignment.sql -Raw
$selectTestingDatesBaseSql = Get-Content .\sql\selectTestingDates.sql -Raw
$delaySeconds = 300
Write-Host ('Runnning Until {0}' -f (Get-Date $RunUntil)) -F Blue

do {
 $testingDates = Get-TestingDates $dbParams $selectTestingDatesBaseSql $AppointmentsTable
 foreach ($tbDate in $testingDates.date) {
  Write-Verbose ('Tb Date: ' + $tbDate)

  # Get all possible callers for this tb date
  $assignedCallers = Get-AssignedCallers $dbParams $assignedCallerSql $AssignmentsTable $tbDate

  # Clear Appointments
  $clearAssignmentsSql = $clearAssignmentsBaseSql -f $AppointmentsTable, $tbDate
  Write-Verbose $clearAssignmentsSql
  if (!$WhatIf) { Invoke-Sqlcmd @dbParams -Query $clearAssignmentsSql }

  $unnasignedAppointmentsSql = $unnasignedAppointmentsBaseSql -f $AppointmentsTable, $tbDate
  $unnasignedAppointments = Invoke-Sqlcmd @dbParams -Query $unnasignedAppointmentsSql

  # Loop through each unnasigned appointment until none are left unnassigned.
  foreach ($appointment in $unnasignedAppointments) {
   foreach ($nurse in $assignedCallers) {
    # SELECT first unnassigned appointment
    $firstUnnasignedSql = $firstUnnasignedAppointmentBaseSql -f $AppointmentsTable, $tbDate
    $unassignedAppointment = Invoke-Sqlcmd @dbParams -Query $firstUnnasignedSql

    if ($null -eq $unassignedAppointment) { break }

    $udpateAssignmentSql = $updateAppointmentBaseSql -f $AppointmentsTable , $nurse.caller, $unassignedAppointment.id
    Write-Verbose ( '{0},tbDate: {1}' -f $udpateAssignmentSql, $tbDate)
    if (!$WhatIf -and ($unassignedAppointment.id)) { Invoke-Sqlcmd @dbParams -Query $udpateAssignmentSql }
   }
  }
 }
 if (!$WhatIf) {

  Write-Host ('Next Run @ {0}' -f ((Get-Date).AddSeconds($delaySeconds))) -F Green
  Start-Sleep $delaySeconds
 }
} Until (((Get-Date) -gt (Get-Date $RunUntil)) -or $WhatIf)
# ============================

Show-TestRun