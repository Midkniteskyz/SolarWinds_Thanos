@{
    # Script module or binary module file associated with this manifest
    RootModule        = 'SolarWindsThanos.psm1'

    # Version number of this module
    ModuleVersion     = '1.0.0'

    # Name of the module author
    Author            = 'Ryan Woolsey'

    # Description of the functionality provided by this module
    Description       = 'A PowerShell module for managing SolarWinds.'

    # Minimum version of the PowerShell engine required to run this module
    PowerShellVersion = '5.1'

    # Modules that must be imported before this module
    RequiredModules   = @()

    # Functions to export from this module
    FunctionsToExport = @('Test-Swis', 'New-CustomProperty', 'Remove-CustomProperty')

    # Cmdlets to export from this module
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport   = @()

    # Private data for the module, such as encryption keys or credentials
    PrivateData       = @{
        PSData = @{
            LicenseUri = ''
        }
    }
}
