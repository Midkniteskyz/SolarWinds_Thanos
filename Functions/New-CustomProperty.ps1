function New-CustomProperty {
    <#
    .SYNOPSIS
        Creates a new custom property on multiple SolarWinds Orion servers.

    .DESCRIPTION
        This function creates a new custom property on specified SolarWinds servers, allowing for customization of the property name, description, data type, and other properties. 
        The script supports multiple SolarWinds instances, reading from 'servers.txt' if no hostnames are provided.

    .PARAMETER Hostname
        An array of hostnames for SolarWinds servers. If not provided, the function reads from 'servers.txt'.

    .PARAMETER Username
        The username for authenticating the connection to the SolarWinds Information Service (SWIS).

    .PARAMETER Password
        The password associated with the provided username for connecting to SWIS.

    .PARAMETER PropertyName
        The name of the custom property you want to create.

    .PARAMETER Description
        A description for the custom property. This is optional.

    .PARAMETER ValueType
        The data type for the custom property. Must be one of: string, integer, datetime, single, double, boolean.

    .PARAMETER Size
        For string types, this is the maximum length of the values, in characters. The default is 250.

    .PARAMETER Mandatory
        Specifies whether the custom property should be mandatory in the Add Node wizard in the Orion web console.

    .PARAMETER DefaultValue
        Specifies the default value for the custom property. This is optional.

    .EXAMPLE
        C:\PS> New-CustomProperty -Hostname "solarwinds-server1" -Username "admin" -Password "password" -PropertyName "Location" -ValueType "string"
        
        Creates a new custom property "Location" on the SolarWinds server "solarwinds-server1".

    .NOTES
        Name: New-CustomProperty
        Author: Ryan Woolsey
        Last Edit: 9-17-2024
        Version: 1.0
        Keywords: SolarWinds, Custom Property, OrionSDK, PowerShell

    .LINK
        https://github.com/solarwinds/OrionSDK/wiki/PowerShell
    .INPUTS
        None.
    .OUTPUTS
        None.
    #Requires -Version 2.0
    #>

    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Enter one or more hostnames for the SolarWinds server(s). If not provided, servers will be read from servers.txt."
        )]
        [string[]]$Hostname,

        [Parameter(Mandatory = $true, HelpMessage = "Enter the username for the SWIS connection.")]
        [ValidateNotNullOrEmpty()]
        [string]$Username,

        [Parameter(Mandatory = $true, HelpMessage = "Enter the password for the SWIS connection.")]
        [ValidateNotNullOrEmpty()]
        [string]$Password,

        [Parameter(Mandatory = $true, HelpMessage = "Enter a name for the custom property.")]
        [ValidateNotNullOrEmpty()]
        [string]$PropertyName,

        [Parameter(Mandatory = $false, HelpMessage = "Enter a description for the custom property.")]
        [string]$Description,

        [Parameter(Mandatory = $true, HelpMessage = "The data type for the custom property. The following types are allowed: string, integer, datetime, single, double, boolean.")]
        [ValidateSet('string', 'integer', 'datetime', 'single', 'double', 'boolean')]
        [string]$ValueType,

        [Parameter(Mandatory = $false, HelpMessage = "For string types, this is the maximum length of the values, in characters. Ignored for other types. The default is 250.")]
        [int]$Size = 250,

        [Parameter(Mandatory = $false, HelpMessage = "Defaults to false. If set to true, the Add Node wizard in the Orion web console will require that a value for this custom property be specified at node creation time.")]
        [bool]$Mandatory = $false,

        [Parameter(Mandatory = $false, HelpMessage = "You can pass null for this. If you provide a value, this will be the default value for new nodes.")]
        [string]$DefaultValue
    )

    Begin {
        Write-Verbose -Message "Entering the BEGIN block."

        # Define the root directory using $PSScriptRoot
        $scriptRoot = $PSScriptRoot

        # Load the server list from servers.txt if no Hostname is provided
        if (-not $Hostname) {
            $serverFilePath = Join-Path -Path $scriptRoot -ChildPath "servers.txt"
            
            if (Test-Path $serverFilePath) {
                $Hostname = Get-Content -Path $serverFilePath
                Write-Verbose -Message "Hostnames loaded from servers.txt."
            } else {
                Write-Error "No hostnames were provided and servers.txt could not be found."
                return
            }
        }

        # Initialize results table
        $createdProperties = @()
    
        # Define the parameters for the custom property
        $params = @(
            $PropertyName,
            $Description,
            $ValueType,
            $Size,
            $null,        # ValidRange - unused, pass null
            $null,        # Parser - unused, pass null
            $null,        # Header - unused, pass null
            $null,        # Alignment - unused, pass null
            $null,        # Format - unused, pass null
            $null,        # Units - unused, pass null
            @{
                IsForAlerting = $true
                IsForFiltering = $true
                IsForGrouping = $true
                IsForReporting = $true
                IsForEntityDetail = $true
                IsForAssetInventory = $true
            } # Usages
            $Mandatory,
            $DefaultValue
        )
    }

    Process {
        foreach ($server in $Hostname) {
            Write-Host "Connecting to $server..."

            # Attempt to connect to SWIS
            try {
                $swis = Connect-Swis -Hostname $server -Username $Username -Password $Password

                if ($swis) {
                    Write-Host "Successfully connected to $server" -ForegroundColor Green
                    Write-Verbose -Message "Connection to $server established."
                }

            } catch {
                Write-Error "Failed to connect to $server. Error: $_"
                continue # Skip to the next host if connection fails
            }

            # Attempt to create the custom property
            try {
                Invoke-SwisVerb -SwisConnection $swis -EntityName 'Orion.NodesCustomProperties' -Verb 'CreateCustomProperty' -Arguments $params -ErrorAction Stop
                Write-Host "Custom property '$PropertyName' created successfully on $server." -ForegroundColor Green

                # Add to the results
                $createdProperties += [pscustomobject]@{
                    Server = $server
                    PropertyName = $PropertyName
                    Description = $Description
                    ValueType = $ValueType
                }

            } catch {
                Write-Error "Failed to create custom property '$PropertyName' on $server. Error: $_"
                continue # Skip to the next host if query fails
            }
        }
    }

    End {
        Write-Verbose -Message "Entering the END block."

        if ($createdProperties.Count -gt 0) {
            Write-Host "`nCustom Properties Created:" -ForegroundColor Cyan
            $createdProperties | Format-Table -AutoSize
        } else {
            Write-Host "No custom properties were created."
        }
    }
}
