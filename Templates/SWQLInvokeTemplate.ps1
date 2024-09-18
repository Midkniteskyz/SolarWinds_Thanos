function FnNameVERB-NOUN {
        
    <#
    .Synopsis
        The short function description.
    .Description
        The long function description
    .Example
        C:\PS>Function-Name -param "Param Value"
        
        This example does something
    .Example
        C:\PS>
        
        You can have multiple examples
    .Notes
        Name: Function-Name
        Author: Author Name
        Last Edit: Date
        Keywords: Any keywords
    .Link
    http://foo.com
    http://twitter.com/foo
    .Inputs
        None
    .Outputs
        None
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
        [string]$Password
    )

    Begin {
        Write-Verbose -Message "Entering the BEGIN block [$($MyInvocation.MyCommand.CommandType): $($MyInvocation.MyCommand.Name)]."
        
        # Define the root directory for servers.txt
        $scriptRoot = (Get-Item -Path ".\" | Select-Object -ExpandProperty FullName)

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
        
        # Initialize the results table
        $results = @()

        # Build the dynamic WHERE clause if  is provided
        $whereClause = ""
        if () {
            $whereClause = "`nWHERE " + ( | ForEach-Object { " = '$_'" }) -join " OR "
        }

        # Define the base SWQL query
        $baseQuery = @"

"@ + $whereClause
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

            # Attempt to run the SWQL query
            try {
                $queryParams = @{
                    SwisConnection = $swis
                    Query          = $baseQuery
                }
                $data = Get-SwisData @queryParams
            }
            catch {
                Write-Error "Failed to execute SWQL query on $host. Error: $_"
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
        Write-Verbose -Message "Entering the END block [$($MyInvocation.MyCommand.CommandType): $($MyInvocation.MyCommand.Name)]."
        # Output the results
        return $results
    }
}