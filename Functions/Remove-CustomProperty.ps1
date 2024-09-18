function Remove-CustomProperty {
    <#
    .SYNOPSIS
        Removes custom properties from multiple SolarWinds Orion servers.

    .DESCRIPTION
        This function connects to specified SolarWinds servers and removes custom properties based on a provided name or wildcard (e.g., 'Test*'). 
        It prompts the user for confirmation before executing the removal.

    .PARAMETER Hostname
        An array of hostnames for SolarWinds servers. If not provided, the function reads from 'servers.txt'.

    .PARAMETER Username
        The username for authenticating the connection to the SolarWinds Information Service (SWIS).

    .PARAMETER Password
        The password associated with the provided username for connecting to SWIS.

    .PARAMETER PropertyName
        The name of the custom property to remove. Supports wildcards (e.g., 'Test*').

    .EXAMPLE
        C:\PS> Remove-CustomProperty -Hostname "solarwinds-server1" -Username "admin" -Password "password" -PropertyName "Test*"
        
        This removes all custom properties starting with "Test" on "solarwinds-server1".

    .NOTES
        Name: Remove-CustomProperty
        Author: Ryan Woolsey
        Last Edit: 9-17-2024
        Version: 1.0
        Keywords: SolarWinds, Custom Property, OrionSDK, PowerShell

    .LINK
        https://github.com/solarwinds/OrionSDK/wiki/PowerShell
    .INPUTS
        None. The function accepts input from parameters.
    .OUTPUTS
        System.Object. Custom property removal details.
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
            Mandatory = $true,
            HelpMessage = "Enter the name of the custom property to remove. Supports wildcards."
        )]
        [ValidateNotNullOrEmpty()]
        [string]$PropertyName
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
        $removalResults = @()

        # Replace * with %
        $PropertyName = $PropertyName.Replace('*','%')

        # Define the base SWQL query to fetch custom properties based on the wildcard
        $baseQuery = @"
SELECT Field, DisplayName 
FROM Orion.CustomProperty
WHERE Field LIKE '$PropertyName'
"@
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

            # Retrieve custom properties matching the wildcard
            try {
                $queryParams = @{
                    SwisConnection = $swis
                    Query = $baseQuery
                }
                $propertiesToRemove = Get-SwisData @queryParams

                if ($propertiesToRemove.Count -eq 0) {
                    Write-Host "No matching custom properties found on $server for pattern '$PropertyName'."
                    continue
                }

                # Display the matching custom properties and ask for confirmation
                Write-Host "`nThe following custom properties will be removed from $server :"
                $propertiesToRemove | Format-Table -AutoSize

                $confirmation = Read-Host "Are you sure you want to remove these custom properties? (y/n)"
                if ($confirmation -ne 'y') {
                    Write-Host "Skipping removal on $server."
                    continue
                }

                # Remove each custom property
                foreach ($property in $propertiesToRemove) {
                    try {
                        Invoke-SwisVerb -SwisConnection $swis -EntityName 'Orion.NodesCustomProperties' -Verb 'DeleteCustomProperty' -Arguments $property.Field
                        Write-Host "Successfully removed custom property '$($property.Field)' on $server." -ForegroundColor Green

                        # Add to the results table
                        $removalResults += [pscustomobject]@{
                            Server = $server
                            PropertyName = $property.Field
                        }

                    } catch {
                        Write-Error "Failed to remove custom property '$($property.Field)' on $server. Error: $_"
                        continue # Skip to the next property if removal fails
                    }
                }

            } catch {
                Write-Error "Failed to retrieve custom properties on $server. Error: $_"
                continue # Skip to the next host if query fails
            }
        }
    }

    End {
        Write-Verbose -Message "Entering the END block."

        if ($removalResults.Count -gt 0) {
            Write-Host "`nRemoved Custom Properties:" -ForegroundColor Cyan
            $removalResults | Format-Table -AutoSize
        } else {
            Write-Host "No custom properties were removed."
        }
    }
}
