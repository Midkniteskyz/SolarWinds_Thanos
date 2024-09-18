function Set-CustomProperty {
        
    <#
    .SYNOPSIS
        Updates an existing custom property for nodes in SolarWinds Orion.

    .DESCRIPTION
        This function connects to specified SolarWinds servers, checks if a custom property with the specified name exists, and then updates the values for that custom property. 
        If no hostnames are provided, the function will attempt to read a list of servers from a servers.txt file located in the script's root directory.

    .PARAMETER Hostname
        An array of one or more hostnames for SolarWinds servers. If this parameter is not provided, the function will attempt to read the hostnames from a 'servers.txt' file located in the script's root directory.

    .PARAMETER Username
        The username for authenticating the connection to the SolarWinds Information Service (SWIS).

    .PARAMETER Password
        The password associated with the provided username for connecting to the SolarWinds Information Service (SWIS).

    .PARAMETER PropertyName
        The name of the custom property you want to update.

    .PARAMETER Values
        An array of values to be assigned to the specified custom property.

    .EXAMPLE
        C:\PS> Set-CustomProperty -Hostname "solarwinds-server1" -Username "admin" -Password "password" -PropertyName "Location" -Values "HQ", "Remote"
        
        This command connects to the SolarWinds server at "solarwinds-server1" and updates the custom property named "Location" with the values "HQ" and "Remote".

    .EXAMPLE
        C:\PS> Set-CustomProperty -PropertyName "Department" -Values "IT", "HR", "Finance"

        This command reads the hostnames from 'servers.txt', connects to the SolarWinds servers, and updates the "Department" custom property with the values "IT", "HR", and "Finance".

    .NOTES
        Name: Set-CustomProperty
        Author: Ryan Woolsey
        Last Edit: 9-17-2024
        Version: 1.0
        Keywords: SolarWinds, Custom Property, OrionSDK, PowerShell
        Link: https://github.com/solarwinds/OrionSDK/wiki/PowerShell
        The script reads from 'servers.txt' if the Hostname parameter is not provided.

    .LINK
        https://github.com/solarwinds/OrionSDK/wiki/PowerShell

    .INPUTS
        None. The function accepts input from parameters.

    .OUTPUTS
        None. The function does not return an output object.

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
        [string]$Username,

        [Parameter(
            Mandatory = $true, 
            HelpMessage = "Enter the password for the SWIS connection."
        )]
        [ValidateNotNullOrEmpty()]
        [string]$Password,

        [Parameter(
            Mandatory = $true, 
            HelpMessage = "Enter the name of the custom property to update."
        )]
        [ValidateNotNullOrEmpty()]
        [string]$PropertyName,

        [Parameter(
            Mandatory = $true, 
            HelpMessage = "Enter the values for the custom property."
        )]
        [ValidateNotNullOrEmpty()]
        [string[]]$Values
    )

    Begin {
        Write-Verbose -Message "Entering the BEGIN block [$($MyInvocation.MyCommand.CommandType): $($MyInvocation.MyCommand.Name)]."
        
        # Define the root directory for servers.txt
        $scriptRoot = $PSScriptRoot 

        # Load the server list from servers.txt if no Hostname is provided
        if (-not $Hostname) {
            $serverFilePath = Join-Path -Path $scriptRoot -ChildPath "servers.txt"
            
            if (Test-Path $serverFilePath) {
                $Hostname = Get-Content -Path $serverFilePath
            }
            else {
                Write-Error "No hostnames were provided and servers.txt could not be found."
                return
            }
        } 

        # Define the base SWQL query
        $baseQuery = @"
SELECT Table, Field, DataType, MaxLength, Description, TargetEntity, Mandatory, Default 
FROM Orion.CustomProperty 
WHERE Field = '$PropertyName' 
"@

    }

    Process {
        Write-Verbose -Message "Entering the PROCESS block [$($MyInvocation.MyCommand.CommandType): $($MyInvocation.MyCommand.Name)]."

        foreach ($server in $Hostname) {
            Write-Host "Connecting to $server..."

            # Attempt to connect to SWIS
            try {
                # Attempt to connect to SWIS for each server
                $swis = Connect-Swis -Hostname $server -Username $Username -Password $Password

                if ($swis) {
                    Write-Host "Successfully connected to $server" -ForegroundColor Green
                }

            }
            catch {
                Write-Error "Failed to connect to $server. Error: $_"
                continue # Skip to the next host if connection fails
            }

            # Check if the custom property exists
            try {
                $queryParams = @{
                    SwisConnection = $swis
                    Query          = $baseQuery
                }
                $data = Get-SwisData @queryParams

                if ($data) {
                    Write-Host "$PropertyName exists on $server." -ForegroundColor Green
                    
                    # Keep the existing custom property properties
                    $params = @(
                        $data.Field, # Custom property name
                        $data.Description, # Keep the same description
                        $data.MaxLength, # Keep the same max length (size)
                        $Values # Updated list of values
                    )

                    # Output verbose details
                    Write-Verbose "Custom Property Name: $($data.Field)"
                    Write-Verbose "Description: $($data.Description)"
                    Write-Verbose "Max Length: $($data.MaxLength)"
                    Write-Verbose "Values: $($Values -join ', ')"

                    try {
                        Write-Host "Replacing existing values on $PropertyName with $Values."
                        Invoke-SwisVerb -SwisConnection $swis -EntityName 'Orion.NodesCustomProperties' -Verb 'ModifyCustomProperty' -Arguments $params
                    }
                    catch {
                        Write-Error "Failed to update $PropertyName on $server. Error: $_"
                        continue # Skip to the next host if query fails
                    }
                }
            }
            catch {
                Write-Error "Failed to execute SWQL query on $server. Error: $_"
                continue # Skip to the next host if query fails
            }
        }

    }

    End {
        Write-Verbose -Message "Entering the END block [$($MyInvocation.MyCommand.CommandType): $($MyInvocation.MyCommand.Name)]."

        # Output the results

    }
}
