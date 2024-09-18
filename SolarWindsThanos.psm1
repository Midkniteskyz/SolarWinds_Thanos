# This file acts as an entry point for the module and loads all the function files.

# Import shared functions
. $PSScriptRoot\Test-Swis.ps1
. $PSScriptRoot\Get-SwisData.ps1

# Import specific functions
Get-ChildItem -Path "$PSScriptRoot\Functions" -Filter *.ps1 | ForEach-Object {
    . $_.FullName
}
