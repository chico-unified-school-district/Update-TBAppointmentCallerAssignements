# Update-TBAppointmentCallerAssignements

Updates and balances call assignments for upcoming appointments by rotating them evenly across a list of configured callers.

## Overview

The script polls a SQL Server database for upcoming appointments and their configured callers (per date), then:

1. Loads upcoming callers (`caller1`/`caller2`/`caller3` per date) and upcoming appointments.
2. Matches appointments to each date's caller list.
3. Detects when a date's assigned callers no longer match the configured caller list (a caller was added/removed) and clears existing assignments for that date so they can be reassigned.
4. Determines the next caller in rotation based on the last-assigned caller for that date.
5. Assigns unassigned appointments to callers in round-robin order.
6. Writes the new assignments back to the database.

This loops on a 5-minute interval (via `Start-Sleep 300`) until the configured stop time is reached, unless `-WhatIf` is specified, in which case it runs once and exits.

## Requirements

- PowerShell modules:
  - `CommonScriptFunctions` (`New-SqlOperation`, `Show-BlockInfo`, `Show-TestRun`)
  - `dbatools` (`Connect-DbaInstance`, `Invoke-DbaQuery`, `Set-DbatoolsConfig`)
- SQL Server access to the appointments and callers tables.

## Parameters

| Parameter           | Required | Description                                                                                                                                                             |
| ------------------- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `SqlServer`         | Yes      | SQL Server/instance name.                                                                                                                                               |
| `SqlDatabase`       | Yes      | Database name.                                                                                                                                                          |
| `SqlCredential`     | Yes      | `PSCredential` used to connect to the database.                                                                                                                         |
| `AppointmentsTable` | No       | Name of the appointments table (used in queries under [sql](sql)).                                                                                                      |
| `CallersTable`      | No       | Name of the table containing per-date caller assignments.                                                                                                               |
| `RunUntil`          | No       | Time of day (e.g. `2:00PM`) the polling loop should run until.                                                                                                          |
| `Wait`              | No       | Switch. Pauses for confirmation (`Read-Host`) before clearing assignments, updating an assignment, and after each item is processed. Useful for step-by-step debugging. |
| `WhatIf` / `-wi`    | No       | Switch. Runs a single pass without making any database changes.                                                                                                         |

## Usage

```powershell
$cred = Get-Credential
.\Update-TBAppointmentCallerAssignements.ps1 `
  -SqlServer 'servername' `
  -SqlDatabase 'db_name' `
  -SqlCredential $cred `
  -AppointmentsTable 'appointments' `
  -CallersTable 'callers' `
  -RunUntil '1:00PM' `
  -WhatIf -Verbose
```

## SQL Files

Located under [sql](sql), each file is formatted with the configured table name(s) before being executed:

- [select-upcoming-callers.sql](sql/select-upcoming-callers.sql) - Retrieves upcoming dates that have at least one caller configured.
- [select-upcoming-appointments.sql](sql/select-upcoming-appointments.sql) - Retrieves upcoming, non-deleted appointments.
- [select-unassigned.sql](sql/select-unassigned.sql) - Retrieves appointments for a date that don't yet have a caller assigned.
- [clear-assignments.sql](sql/clear-assignments.sql) - Clears (`NULL`s) all caller assignments for a date, used when the configured caller list changes.
- [update-assignment.sql](sql/update-assignment.sql) - Assigns a caller to a specific appointment by id.

## Notes

- Run with `-WhatIf` first to preview behavior without writing to the database.
- The stop time defaults to `5:00PM`, except on Wednesdays when the `RunUntil` parameter value is used instead; under `-WhatIf` the loop runs once regardless of stop time.
