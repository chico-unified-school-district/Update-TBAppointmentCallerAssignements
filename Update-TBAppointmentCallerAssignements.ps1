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
 # [ValidateScript( { Test-Connection -ComputerName $_ -Quiet -Count 1 })]
 [string]$SqlServer,
 [Parameter(Mandatory = $true)]
 [Alias('LFDB')]
 [string]$SqlDatabase,
 [Parameter(Mandatory = $true)]
 [Alias('LFCred')]
 [System.Management.Automation.PSCredential]$SqlCredential,
 [Alias('wi')]
	[switch]$WhatIf
)

function Invoke-LFSql ($sql) {
 process {
  if ($WhatIf) { Write-Verbose ('{0}, sql: {1}' -f $MyInvocation.MyCommand.name, $sql) }
  else { Invoke-SqlCmd @lfFormsDBParams -Query $sql }
 }
}

# ======================================================================

. .\lib\Show-TestRun.ps1
. .\lib\Load-Module.ps1
'SqlServer' | Load-Module

Show-TestRun

$DBParams = @{
 Server                 = $SqlServer
 Database               = $SqlDatabase
 Credential             = $SqlCredential
 TrustServerCertificate = $true
}


Show-TestRun