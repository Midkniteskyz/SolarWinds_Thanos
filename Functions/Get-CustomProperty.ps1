function Get-CustomProperty {
    <#
    .SYNOPSIS
        Retrieves custom properties from SolarWinds Orion.

    .DESCRIPTION
        This function connects to specified SolarWinds servers and retrieves custom properties, optionally filtered by custom property names.
        If no hostnames are provided, it reads from a 'servers.txt' file in the script's root directory. You can filter the results using 
        wildcard patterns on the custom property name.

    .PARAMETER Hostname
        An array of hostnames for SolarWinds servers. If not provided, the function reads from 'servers.txt'.

    .PARAMETER Username
        The username for authenticating the connection to the SolarWinds Information Service (SWIS).

    .PARAMETER Password
        The password associated with the provided username for connecting to SWIS.

    .PARAMETER PropertyName
        An array of custom property names to filter by. You can use wildcards (e.g., 'Test*'). If omitted, all custom properties are returned.

    .EXAMPLE
        C:\PS> Get-CustomProperty -Hostname "solarwinds-server1" -Username "admin" -Password "password"
        Retrieves all custom properties from "solarwinds-server1".

    .EXAMPLE
        C:\PS> Get-CustomProperty -PropertyName "Location"
        Retrieves the "Location" custom property from the servers listed in 'servers.txt'.

    .NOTES
        Name: Get-CustomProperty
        Author: Ryan Woolsey
        Last Edit: 9-17-2024
        Version: 1.0
        Keywords: SolarWinds, Custom Property, OrionSDK, PowerShell
    .LINK
        https://github.com/solarwinds/OrionSDK/wiki/PowerShell
    .INPUTS
        None. The function accepts input from parameters.
    .OUTPUTS
        System.Object. Custom property details.
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

        [Parameter(
            Mandatory = $true,
            HelpMessage = "Enter the username for the SWIS connection."
        )]
        [ValidateNotNullOrEmpty()]
        [string]$Username,

        [Parameter(
            Mandatory = $true,
            HelpMessage = "Enter the password for the SWIS connection."
        )]
        [ValidateNotNullOrEmpty()]
        [string]$Password,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "Enter one or more custom property names to filter by. Supports wildcards."
        )]
        [string[]]$PropertyName
    )

    Begin {
        Write-Verbose -Message "Entering the BEGIN block."
        
        # Define the root directory using $PSScriptRoot for consistency
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

        # Initialize the results table
        $results = @()

        # Build the dynamic WHERE clause if PropertyName is provided
        $whereClause = ""
        if ($PropertyName) {
            if ($PropertyName -like '*`*') {
                # Handle case where PropertyName contains a wildcard
                $whereClause = ("`nWHERE " + ($PropertyName.Replace('*', '%') | ForEach-Object { "CP.Field LIKE '$_'" })).TrimEnd(' OR')
                Write-Verbose -Message "Wildcard detected. WHERE clause: $whereClause"
            } else {
                # Handle exact matches
                $whereClause = ("`nWHERE " + ($PropertyName | ForEach-Object { "CP.Field = '$_'" })).TrimEnd(' OR')
                Write-Verbose -Message "No wildcard detected. WHERE clause: $whereClause"
            }
        }

        # Define the base SWQL query
        $baseQuery = @"
SELECT 
    CP.Table, 
    CP.Field, 
    CP.DataType, 
    CP.MaxLength, 
    CP.StorageMethod, 
    CP.Description, 
    CP.TargetEntity, 
    CP.Mandatory, 
    CP.Default, 
    CP.DisplayName AS CPDisplayName,
    CPU.IsForAlerting, 
    CPU.IsForFiltering, 
    CPU.IsForGrouping, 
    CPU.IsForReporting, 
    CPU.IsForEntityDetail, 
    CPU.IsForAssetInventory,
    CPV.Value, 
    CPV.DisplayName AS CPVDisplayName, 
    CPV.Description AS CPVDescription
FROM 
    Orion.CustomProperty AS CP
LEFT JOIN 
    Orion.CustomPropertyUsage AS CPU
    ON CP.Table = CPU.Table 
    AND CP.Field = CPU.Field
LEFT JOIN 
    Orion.CustomPropertyValues AS CPV
    ON CP.Table = CPV.Table 
    AND CP.Field = CPV.Field
"@ + $whereClause

        Write-Verbose -Message "SWQL query built: $baseQuery"
    }

    Process {
        foreach ($server in $Hostname) {
            Write-Host "Connecting to $server..."

            # Attempt to connect to SWIS
            try {
                $swis = Connect-Swis -Hostname $server -Username $Username -Password $Password

                if ($swis) {
                    Write-Host "Successfully connected to $server" -ForegroundColor Green
                    Write-Verbose "Connection to $server established."
                }
            } catch {
                Write-Error "Failed to connect to $server. Error: $_"
                continue # Skip to the next host if connection fails
            }

            # Attempt to run the SWQL query
            try {
                $queryParams = @{
                    SwisConnection = $swis
                    Query = $baseQuery
                }
                $data = Get-SwisData @queryParams
                Write-Verbose "SWQL query executed successfully on $server."
            } catch {
                Write-Error "Failed to execute SWQL query on $server. Error: $_"
                continue # Skip to the next host if query fails
            }

            # Parse the data into results
            foreach ($row in $data) {
                $result = [ordered]@{ Hostname = $server }

                # Dynamically add all properties from the row data
                foreach ($property in $row.PSObject.Properties) {
                    $result[$property.Name] = $property.Value
                }

                # Add to the results table
                $results += [pscustomobject]$result
            }
        }
    }

    End {
        if ($results) {
            # Output the results
            Write-Host "Query finished."
            return $results | Select-Object HostName, Table, Field, Description, DataType, MaxLength, Mandatory, Value, Default, IsForAlerting, IsForFiltering, IsForGrouping, IsForReporting, IsForEntityDetail, IsAssetInventory | Out-GridView
        } else {
            Write-Host "No results found for the custom property $PropertyName."
        }
    }
}

# Get-CustomProperty -Hostname 'localhost' -Username $Username -Password $Password -PropertyName "Test*"
