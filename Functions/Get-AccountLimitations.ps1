function Get-AccountLimitations {
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
        [string]$Username,

        [Parameter(Mandatory = $true, HelpMessage = "Enter the password for the SWIS connection.")]
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
        
        # Initialize the results table
        $results = @()
        
        # Define the base SWQL query
        $baseQuery = @"
            SELECT a.AccountID
          , lt1.name as [Limitation Name 1]
          , l1.WhereClause as [Limitation Definition 1]
          , lt2.name as [Limitation Name 2]
          , l2.WhereClause as [Limitation Definition 2]
          , lt3.name as [Limitation Name 3]
          , l3.WhereClause as [Limitation Definition 3]
            FROM Orion.Accounts AS a
            LEFT JOIN Orion.Limitations AS l1
            ON a.LimitationID1 = l1.LimitationID
            LEFT JOIN Orion.Limitations AS l2
            ON a.LimitationID2 = l2.LimitationID
            LEFT JOIN Orion.Limitations AS l3
            ON a.LimitationID3 = l3.LimitationID
            LEFT JOIN Orion.LimitationTypes AS lt1
            ON l1.LimitationTypeID = lt1.LimitationTypeID
            LEFT JOIN Orion.LimitationTypes AS lt2
            ON l2.LimitationTypeID = lt2.LimitationTypeID
            LEFT JOIN Orion.LimitationTypes AS lt3
            ON l3.LimitationTypeID = lt3.LimitationTypeID
            --  0 = System
            --  1 = SolarWinds individual
            --  2 = Windows Individual
            --  3 = Windows group
            --  4 = Windows group individual
            WHERE 1=1
            AND a.AccountType = 3
"@
    }

    Process {
        foreach ($server in $Hostname) {
            Write-Host "Connecting to $server..."

            # Attempt to connect to SWIS
            try {
                # Attempt to connect to SWIS for each server
                $swis = Connect-Swis -Hostname $server -Username $Username -Password $Password

                if ($swis) {
                    Write-Host "Successfully connected to $server" -ForegroundColor Green
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
            } catch {
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
        # Output the results
        return $results
    }
}