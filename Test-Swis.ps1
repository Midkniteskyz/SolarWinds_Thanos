function Test-Swis {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Enter one or more hostnames for the SolarWinds server(s). If not provided, servers will be read from servers.txt."
        )]
        [string[]]$Hostname,

        [Parameter(Mandatory = $true, HelpMessage = "Username for SWIS connection.")]
        [string]$Username,

        [Parameter(Mandatory = $true, HelpMessage = "Password for SWIS connection.")]
        [string]$Password
    )

    Begin {
        # Define the root directory for servers.txt
        $scriptRoot = (Get-Item -Path ".\" | Select-Object -ExpandProperty FullName)

        # Load the server list from servers.txt if no Hostname is provided
        if (-not $Hostname) {
            $serverFilePath = Join-Path -Path $scriptRoot -ChildPath "servers.txt"
            
            if (Test-Path $serverFilePath) {
                $Hostname = Get-Content -Path $serverFilePath
            } else {
                Write-Error "No hostnames were provided and servers.txt could not be found."
                return
            }
        } 

        # Initialize an array to store successful connections
        $swisConnections = @()
    }

    Process {
        foreach ($server in $Hostname) {
            Write-Host "Connecting to $server..."
            try {
                # Attempt to connect to SWIS for each server
                $swis = Connect-Swis -Hostname $server -Username $Username -Password $Password

                if ($swis) {
                    Write-Host "Successfully connected to $server" -ForegroundColor Green
                    $swisConnections += [pscustomobject]@{
                        Hostname = $server
                        Connection = $swis
                    }
                }
            } catch {
                Write-Error "Failed to connect to $server. Error: $_"
            }
        }
    }

    End {
        # Output the array of successful connections
        if ($swisConnections.Count -gt 0) {
            return $swisConnections
        } else {
            Write-Error "No successful connections were made."
        }
    }
}
