function Load-Module {
 process {
  if (-not(Get-Module -Name $_ -ListAvailable)) {
   Install-Module -Name $_ -Scope CurrentUser -AllowClobber -Confirm:$false -Force
  }
  Import-Module -Name $_ -Force -ErrorAction Stop | Out-Null
  # Get-Module -Name $_
 }
}