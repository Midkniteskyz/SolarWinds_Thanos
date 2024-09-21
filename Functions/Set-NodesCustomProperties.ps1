function Connect-SolarWinds {
    
    <#
    .SYNOPSIS
        Connects to the SolarWinds Information Service (SWIS) using specified credentials.
    
    .DESCRIPTION
        This function establishes a connection to the SolarWinds Information Service (SWIS) on a given SolarWinds server. 
        The function takes the hostname of the server, a username, and a password as input parameters. If the connection fails, 
        it will throw an error and return null.
    
    .PARAMETER Hostname
        The hostname or IP address of the SolarWinds server.
    
    .PARAMETER Username
        The username used to authenticate the connection to the SolarWinds server.
    
    .PARAMETER Password
        The password associated with the provided username for authentication.
    
    .EXAMPLE
        PS> Connect-SolarWinds -Hostname "solarwinds-server1" -Username "admin" -Password "password"
    
        Connects to the SolarWinds server 'solarwinds-server1' using the credentials 'admin' and 'password'.
    
    .EXAMPLE
        PS> $connection = Connect-SolarWinds -Hostname "10.0.0.1" -Username "loop1" -Password "P@ssw0rd"
    
        Stores the connection object to the SolarWinds server '10.0.0.1' in the variable $connection.
    
    .NOTES
        Author: Ryan Woolsey
        Last Edit: 9-20-2024
        Version: 1.1
        Keywords: SolarWinds, OrionSDK, PowerShell, SWIS
    
    .LINK
        https://github.com/solarwinds/OrionSDK/wiki/PowerShell
    
    .REQUIRES
        # Requires -Version 5.1
        # Requires -Modules OrionSDK
    
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, 
                   HelpMessage = "Enter the hostname or IP address of the SolarWinds server.")]
        [string]$Hostname,

        [Parameter(Mandatory = $true, 
                   HelpMessage = "Enter the username for authentication.")]
        [string]$Username,

        [Parameter(Mandatory = $true, 
                   HelpMessage = "Enter the password for the provided username.")]
        [string]$Password
    )

    # Build the connection parameters for SWIS
    $swisParams = @{
        Hostname = $Hostname
        UserName = $Username
        Password = $Password
        ErrorAction = 'Stop'  # Stops the function if an error occurs
    }

    # Attempt to connect to SWIS
    try {
        # The Connect-Swis cmdlet is used to establish a connection to the SolarWinds server
        return Connect-Swis @swisParams
    }
    catch {
        # If the connection fails, output an error message with the reason for the failure
        Write-Error "Failed to connect to SWIS: $_"
        return $null
    }
}

function Get-CustomPropertyFields {

    <#
    .SYNOPSIS
        Retrieves the custom property fields from the SolarWinds server for nodes.
    
    .DESCRIPTION
        This function executes a SWQL query on the provided SolarWinds Information Service (SWIS) connection to retrieve the 
        custom property fields associated with the 'NodesCustomProperties' table. The custom properties are typically used 
        for filtering and classifying nodes within SolarWinds.
    
    .PARAMETER Swis
        The active SWIS connection object returned by the 'Connect-Swis' function.
    
    .EXAMPLE
        PS> $customProperties = Get-CustomPropertyFields -Swis $swisConnection
    
        Retrieves the custom property fields for nodes from the SolarWinds server and stores them in the $customProperties variable.
    
    .NOTES
        Author: Ryan Woolsey
        Last Edit: 9-20-2024
        Version: 1.1
        Keywords: SolarWinds, Custom Property, OrionSDK, SWQL
    
    .LINK
        https://github.com/solarwinds/OrionSDK/wiki/PowerShell
    
    .REQUIRES
        # Requires -Version 5.1
        # Requires -Modules OrionSDK
    
    .INPUTS
        [object] - A SWIS connection object.
    
    .OUTPUTS
        [array] - Returns an array of custom property field names.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, 
                   ValueFromPipeline = $true, 
                   HelpMessage = "Provide the SWIS connection object for querying custom properties.")]
        [object]$Swis
    )

    # SWQL query to retrieve custom property fields for the 'NodesCustomProperties' table
    $query = @"
    SELECT Field 
    FROM Orion.CustomProperty 
    WHERE Table = 'NodesCustomProperties'
"@

    # Execute the query on the SolarWinds server and return the results
    try {
        # The Get-SwisData cmdlet runs the SWQL query to fetch the custom property fields
        return Get-SwisData -SwisConnection $Swis -Query $query
    }
    catch {
        # If an error occurs, output an error message
        Write-Error "Failed to retrieve custom property fields: $_"
        return $null
    }
}

function Build-NodeQuery {

    <#
    .SYNOPSIS
        Builds a SWQL query to retrieve node properties along with custom property fields.
    
    .DESCRIPTION
        This function dynamically constructs a SWQL query to retrieve node information, including the custom properties. 
        It takes an array of custom property fields, formats them, and appends them to the query for node details. 
        The query can then be executed to fetch node data from the SolarWinds server.
    
    .PARAMETER CustomProperties
        An array of custom property field names that will be included in the query for retrieving node data.
    
    .EXAMPLE
        PS> $query = Build-NodeQuery -CustomProperties $customProperties
    
        This command builds a SWQL query to fetch node data and includes the custom property fields stored in the `$customProperties` array.
    
    .NOTES
        Author: Ryan Woolsey
        Last Edit: 9-20-2024
        Version: 1.1
        Keywords: SolarWinds, SWQL, NodeQuery, OrionSDK
    
    .LINK
        https://github.com/solarwinds/OrionSDK/wiki/PowerShell
    
    .INPUTS
        [array] - An array of custom property field names.
    
    .OUTPUTS
        [string] - Returns a formatted SWQL query as a string.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, 
                   HelpMessage = "An array of custom property fields to be included in the query.")]
        [array]$CustomProperties
    )

    # Join custom property fields into a formatted string for inclusion in the SWQL query
    # This ensures the custom properties are retrieved in the SWQL query.
    $CPFieldsFormatted = $CustomProperties | ForEach-Object { "n.CustomProperties.$_" }
    $CPFieldsFormatted = $CPFieldsFormatted -join ",`n"

    # Build the SWQL query to retrieve node properties including custom properties
    $query = @"
    SELECT
        n.Caption,                     -- Node's caption (display name)
        n.Vendor,                      -- Node's vendor
        n.MachineType,                 -- Machine type of the node
        SUBSTRING(n.IPAddress, 1, CHARINDEX('.', n.IPAddress) - 1) AS [Octet1],       -- First octet of the IP address
        SUBSTRING(n.IPAddress, CHARINDEX('.', n.IPAddress) + 1, CHARINDEX('.', n.IPAddress, CHARINDEX('.', n.IPAddress) + 1) - CHARINDEX('.', n.IPAddress) - 1) AS [Octet2],  -- Second octet of the IP address
        SUBSTRING(n.IPAddress, CHARINDEX('.', n.IPAddress, CHARINDEX('.', n.IPAddress) + 1) + 1, CHARINDEX('.', n.IPAddress, CHARINDEX('.', n.IPAddress, CHARINDEX('.', n.IPAddress) + 1) + 1) - CHARINDEX('.', n.IPAddress, CHARINDEX('.', n.IPAddress) + 1) - 1) AS [Octet3],  -- Third octet of the IP address
        SUBSTRING(n.IPAddress, CHARINDEX('.', n.IPAddress, CHARINDEX('.', n.IPAddress, CHARINDEX('.', n.IPAddress) + 1) + 1) + 1, LENGTH(n.IPAddress)) AS [Octet4],           -- Fourth octet of the IP address
        $CPFieldsFormatted,             -- Custom properties (dynamically injected into the query)
        n.CustomProperties.URI          -- URI for the node's custom properties
    FROM Orion.Nodes AS n
"@

    # Return the formatted query string
    return $query
}

function Get-NodeData {
    
    <#
    .SYNOPSIS
        Executes a SWQL query to retrieve node data from SolarWinds.
    
    .DESCRIPTION
        This function runs a SWQL query on a provided SolarWinds Information Service (SWIS) connection 
        to retrieve node data. The data includes both standard node attributes (such as Caption, Vendor, 
        and IP address) and any custom properties included in the query.
    
    .PARAMETER Swis
        The active SWIS connection object returned by the 'Connect-Swis' function.
    
    .PARAMETER Query
        A SWQL query string used to retrieve the desired node data.
    
    .EXAMPLE
        PS> $nodeData = Get-NodeData -Swis $swisConnection -Query $query
    
        This command retrieves the node data from the SolarWinds server based on the SWQL query stored in `$query`.
    
    .NOTES
        Author: Ryan Woolsey
        Last Edit: 9-20-2024
        Version: 1.1
        Keywords: SolarWinds, SWQL, OrionSDK
    
    .LINK
        https://github.com/solarwinds/OrionSDK/wiki/PowerShell
    
    .INPUTS
        [object] - A SWIS connection object.
        [string] - A SWQL query string.
    
    .OUTPUTS
        [array] - Returns an array of node data retrieved from the SolarWinds server.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, 
                   ValueFromPipeline = $true, 
                   HelpMessage = "Provide the SWIS connection object.")]
        [object]$Swis,

        [Parameter(Mandatory = $true, 
                   HelpMessage = "Provide the SWQL query string to retrieve node data.")]
        [string]$Query
    )

    # Execute the provided SWQL query to retrieve node data
    try {
        # The Get-SwisData cmdlet runs the SWQL query on the provided SWIS connection
        return Get-SwisData -SwisConnection $Swis -Query $Query
    }
    catch {
        # If an error occurs, output an error message and return null
        Write-Error "Failed to retrieve node data: $_"
        return $null
    }
}

function Update-Environment {
    
    <#
    .SYNOPSIS
        Updates the 'Environment' custom property of a node based on its IP Octet2 value.
    
    .DESCRIPTION
        This function checks the value of the second octet (Octet2) of a node's IP address and maps it to a predefined environment.
        If the node's current 'Environment' custom property does not match the mapped environment, the function updates the property. 
        Otherwise, no changes are made.
    
    .PARAMETER Node
        A PSCustomObject representing a node. The object should contain at least the IP octet information (Octet2) and the current 'Environment' custom property.
    
    .EXAMPLE
        PS> $updatedEnv = Update-Environment -Node $node
    
        Checks the node's IP Octet2 value and updates the 'Environment' custom property accordingly.
    
    .NOTES
        Author: Ryan Woolsey
        Last Edit: 9-20-2024
        Version: 1.1
        Keywords: SolarWinds, Environment, Node Properties, OrionSDK
    
    .LINK
        https://github.com/solarwinds/OrionSDK/wiki/PowerShell
    
    .INPUTS
        [PSCustomObject] - A node object with relevant properties like Octet2 and Environment.
    
    .OUTPUTS
        [string] - Returns the updated or unchanged environment string.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, 
                   HelpMessage = "Provide the node object which contains IP octet information and the current Environment property.")]
        [PSCustomObject]$Node
    )

    # Define a map for the environment based on the value of IP Octet2
    $environmentMap = @{
        '56'  = 'Dream'
        '57'  = 'Fantasy'
        '58'  = 'Magic'
        '59'  = 'Wonder'
        '60'  = 'Castaway'
        '61'  = 'Castaway'
        '217' = 'LightHouse Point'
    }

    # Retrieve the current environment from the map using the node's Octet2 value
    $currentEnvironment = $environmentMap.($Node.Octet2)

    # Check if the node's current environment is null or different from the mapped environment
    if ([string]::IsNullOrEmpty($Node.Environment) -or $Node.Environment -ne $currentEnvironment) {
        # If an update is needed, write a verbose message and update the environment
        Write-Verbose "[UPDATE] $($Node.Caption): Environment updated to '$currentEnvironment' based on IP Octet 2: '$($Node.Octet2)'."
        $Node.Environment = $currentEnvironment
    }
    else {
        # No update required if the environment matches the current value
        Write-Verbose "[NO CHANGE] $($Node.Caption): Environment is already set to '$($Node.Environment)'."
    }

    # Return the updated or unchanged environment value
    return $Node.Environment
}

function Update-DeviceType {
    
    <#
    .SYNOPSIS
        Updates the 'Device_Type' custom property of a node based on its Caption or MachineType.
    
    .DESCRIPTION
        This function checks the node's 'Caption' and 'MachineType' properties for specific keywords and maps them to predefined device types.
        If a match is found, the function updates the 'Device_Type' custom property accordingly. If no matches are found, no changes are made.
    
    .PARAMETER Node
        A PSCustomObject representing a node. The object should contain the 'Caption', 'MachineType', and 'Device_Type' custom properties.
    
    .EXAMPLE
        PS> $updatedDeviceType = Update-DeviceType -Node $node
    
        Checks the node's 'Caption' and 'MachineType' for matching keywords and updates the 'Device_Type' custom property.
    
    .NOTES
        Author: Ryan Woolsey
        Last Edit: 9-20-2024
        Version: 1.1
        Keywords: SolarWinds, DeviceType, Node Properties, OrionSDK
    
    .LINK
        https://github.com/solarwinds/OrionSDK/wiki/PowerShell
    
    .INPUTS
        [PSCustomObject] - A node object with relevant properties like Caption, MachineType, and Device_Type.
    
    .OUTPUTS
        [string] - Returns the updated or unchanged device type string.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, 
                   HelpMessage = "Provide the node object which contains the Caption, MachineType, and Device_Type properties.")]
        [PSCustomObject]$Node
    )

    # Define a map of keywords and corresponding device types for MachineType and Caption
    $DeviceTypeMap = @{
        MachineType = @{
            'Switch'                = 'Switch'
            'Wireless Controller'   = 'Wireless Controller'
            'ISR'                   = 'Router'
            'DRAC'                  = 'Remote Management Interface'
            'Nexus'                 = 'Data Center Switch'
            'PA-5220'               = 'Firewall'
            'Panorama'              = 'Firewall'
            'Veritiv'               = 'UPS'
            'Emerson'               = 'UPS'
            'Liebert'               = 'UPS'
            'VMware ESX Server'     = 'Hypervisor'
            'VMware vCenter Server' = 'Virtualization Management Server'
            'Windows'               = 'Server'
        }
        Caption = @{
            'tc'        = 'Time Clock'
            '-sw'       = 'Switch'
            'radionode' = 'RFID Reader'
            'brightsign' = 'Digital Signage'
            'solar'     = 'Server'
            'pos'       = 'Point of Sale'
        }
    }

    $deviceTypeUpdated = $false  # Track if an update is made

    # Iterate over each table (MachineType and Caption) in the device type map
    foreach ($table in $DeviceTypeMap.Keys) {

        Write-Debug "Checking Device_Type Table: $table"

        # Check each keyword in the current table for a match
        foreach ($key in $DeviceTypeMap.$table.Keys) {
            Write-Debug "Checking key: $key"

            # Check for matches in either MachineType or Caption
            if ($table -eq 'MachineType' -and $Node.MachineType -match $key) {
                $newDeviceType = $DeviceTypeMap.$table[$key]
                Write-Verbose "[UPDATE] $($Node.Caption): Device_Type updated to '$newDeviceType' based on keyword '$key' found in MachineType."
                $Node.Device_Type = $newDeviceType
                $deviceTypeUpdated = $true
            }
            elseif ($table -eq 'Caption' -and $Node.Caption -match $key) {
                $newDeviceType = $DeviceTypeMap.$table[$key]
                Write-Verbose "[UPDATE] $($Node.Caption): Device_Type updated to '$newDeviceType' based on keyword '$key' found in Caption."
                $Node.Device_Type = $newDeviceType
                $deviceTypeUpdated = $true
            }
        }
    }

    # If no updates were made, log a verbose message
    if (-not $deviceTypeUpdated) {
        Write-Verbose "[NO CHANGE] $($Node.Caption): Device_Type is already set to '$($Node.Device_Type)' or no matching keyword found."
    }

    # Return the updated or unchanged Device_Type value
    return $Node.Device_Type
}

function Update-DeviceFunction {
    
    <#
    .SYNOPSIS
        Updates the 'Device_Function' custom property of a node based on its Caption.
    
    .DESCRIPTION
        This function checks the node's 'Caption' property for specific keywords and maps them to predefined device functions.
        If a match is found, the function updates the 'Device_Function' custom property accordingly. If no matches are found, no changes are made.
    
    .PARAMETER Node
        A PSCustomObject representing a node. The object should contain the 'Caption' and 'Device_Function' custom properties.
    
    .EXAMPLE
        PS> $updatedDeviceFunction = Update-DeviceFunction -Node $node
    
        Checks the node's 'Caption' for matching keywords and updates the 'Device_Function' custom property.
    
    .NOTES
        Author: Ryan Woolsey
        Last Edit: 9-20-2024
        Version: 1.1
        Keywords: SolarWinds, DeviceFunction, Node Properties, OrionSDK
    
    .LINK
        https://github.com/solarwinds/OrionSDK/wiki/PowerShell
    
    .INPUTS
        [PSCustomObject] - A node object with relevant properties like Caption and Device_Function.
    
    .OUTPUTS
        [string] - Returns the updated or unchanged device function string.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, 
                   HelpMessage = "Provide the node object which contains the Caption and Device_Function properties.")]
        [PSCustomObject]$Node
    )

    # Define a map of keywords and corresponding device functions for the Caption
    $DeviceFunctionMap = @{
        'brightsign' = 'Brightsign'
        'ex'         = 'Exchange'
        'ora'        = 'Oracle'
        'sql'        = 'SQL'
    }

    $deviceFunctionUpdated = $false  # Track if an update is made

    # Iterate through the device function map to check if any key matches the Caption
    foreach ($key in $DeviceFunctionMap.Keys) {
        Write-Debug "Checking key: $key"

        # Check if the Caption contains the keyword
        if ($Node.Caption -match $key) {
            $newDeviceFunction = $DeviceFunctionMap[$key]
            Write-Verbose "[UPDATE] $($Node.Caption): Device_Function updated to '$newDeviceFunction' based on keyword '$key'."
            $Node.Device_Function = $newDeviceFunction
            $deviceFunctionUpdated = $true
        }
    }

    # If no updates were made, log a verbose message
    if (-not $deviceFunctionUpdated) {
        Write-Verbose "[NO CHANGE] $($Node.Caption): Device_Function is already set to '$($Node.Device_Function)' or no matching keyword found."
    }

    # Return the updated or unchanged Device_Function value
    return $Node.Device_Function
}

function Build-NodeUpdateList {
    
    <#
    .SYNOPSIS
        Builds a list of nodes that require updates based on changes to custom properties.
    
    .DESCRIPTION
        This function compares the current values of the node's custom properties (Environment, Device_Type, Device_Function) 
        with new values generated by the update functions (Update-Environment, Update-DeviceType, and Update-DeviceFunction). 
        If any changes are detected, the node is added to the update list along with the new property values.
    
    .PARAMETER Nodes
        An array of PSCustomObjects representing nodes. Each node should contain relevant properties like Environment, Device_Type, Device_Function, and their IP address octets.
    
    .EXAMPLE
        PS> $updateList = Build-NodeUpdateList -Nodes $nodeData
    
        This command builds a list of nodes that need updates based on changes in custom properties like Environment, Device_Type, and Device_Function.
    
    .NOTES
        Author: Ryan Woolsey
        Last Edit: 9-20-2024
        Version: 1.1
        Keywords: SolarWinds, NodeUpdate, CustomProperties, OrionSDK
    
    .LINK
        https://github.com/solarwinds/OrionSDK/wiki/PowerShell
    
    .INPUTS
        [array] - An array of node objects.
    
    .OUTPUTS
        [array] - Returns an array of objects representing nodes that require updates to their custom properties.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, 
                   HelpMessage = "Provide an array of node objects to check for custom property updates.")]
        [array]$Nodes
    )

    $updateList = @()  # Initialize the update list

    foreach ($Node in $Nodes) {
        # Store previous values for comparison
        $oldEnvironment = $Node.Environment
        $oldDeviceType = $Node.Device_Type
        $oldDeviceFunction = $Node.Device_Function

        # Update custom properties using the respective functions
        $newEnvironment = Update-Environment -Node $Node
        $newDeviceType = Update-DeviceType -Node $Node
        $newDeviceFunction = Update-DeviceFunction -Node $Node

        # Hashtable to store properties that have changed
        $properties = @{}

        # Check if Environment has changed
        if ($newEnvironment -ne $oldEnvironment) {
            Write-Host "[CHANGE] $($Node.Caption): Environment changed from '$oldEnvironment' to '$newEnvironment'" -ForegroundColor Cyan
            $properties['Environment'] = $newEnvironment
        }

        # Check if Device_Type has changed
        if ($newDeviceType -ne $oldDeviceType) {
            Write-Host "[CHANGE] $($Node.Caption): Device_Type changed from '$oldDeviceType' to '$newDeviceType'" -ForegroundColor Cyan
            $properties['Device_Type'] = $newDeviceType
        }

        # Check if Device_Function has changed
        if ($newDeviceFunction -ne $oldDeviceFunction) {
            Write-Host "[CHANGE] $($Node.Caption): Device_Function changed from '$oldDeviceFunction' to '$newDeviceFunction'" -ForegroundColor Cyan
            $properties['Device_Function'] = $newDeviceFunction
        }

        # Only add the node to the update list if there are changes
        if ($properties.Count -gt 0) {
            # Add the node to the update list with its URI and changed properties
            $updateList += [PSCustomObject]@{
                Uri        = $Node.URI
                Node       = $Node.Caption
                Properties = $properties
            }
        }
        else {
            Write-Host "[NO CHANGE] $($Node.Caption): No updates needed for this node." -ForegroundColor Gray
        }
    }

    # Return the list of nodes that require updates
    return $updateList
}

function Update-NodesInSolarWinds {
    
    <#
    .SYNOPSIS
        Updates the custom properties of nodes in SolarWinds based on the provided list of changes.
    
    .DESCRIPTION
        This function takes a list of nodes with their corresponding custom property changes and updates those properties 
        in SolarWinds using the Set-SwisObject cmdlet. The function iterates over each node and applies the updates 
        to its custom properties as specified in the input list.
    
    .PARAMETER Swis
        The active SWIS connection object returned by the 'Connect-Swis' function.
    
    .PARAMETER NodeUpdates
        An array of PSCustomObjects where each object contains the URI of the node and a hashtable of properties that need to be updated.
    
    .EXAMPLE
        PS> Update-NodesInSolarWinds -Swis $swisConnection -NodeUpdates $updateList
    
        This command updates the custom properties of nodes in SolarWinds based on the changes specified in `$updateList`.
    
    .NOTES
        Author: Ryan Woolsey
        Last Edit: 9-20-2024
        Version: 1.1
        Keywords: SolarWinds, NodeUpdate, CustomProperties, OrionSDK
    
    .LINK
        https://github.com/solarwinds/OrionSDK/wiki/PowerShell
    
    .INPUTS
        [object] - A SWIS connection object.
        [array] - An array of objects where each contains a node's URI and the properties to be updated.
    
    .OUTPUTS
        None. The function applies changes to SolarWinds but does not return any output.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, 
                   HelpMessage = "Provide the SWIS connection object to perform updates.")]
        [object]$Swis,

        [Parameter(Mandatory = $true, 
                   HelpMessage = "Provide the array of node updates containing URIs and changed properties.")]
        [array]$NodeUpdates
    )

    # Iterate over each node in the update list and apply the changes
    foreach ($update in $NodeUpdates) {
        Write-Debug "Updating node with URI: $($update.Uri)"
        Write-Debug "Properties: $($update.Properties | Out-String)"

        try {
            # Apply the custom property updates to the node using Set-SwisObject
            Set-SwisObject -SwisConnection $Swis -Uri $update.Uri -Properties $update.Properties

            # Log success message
            Write-Verbose "[SUCCESS] Updated node $($update.Node)."
        }
        catch {
            # Catch and report errors during the update process
            Write-Error "Failed to update node $($update.Node): $_"
        }
    }
}

function Main {
    
    <#
    .SYNOPSIS
        Main function to connect to SolarWinds, retrieve node data, and update custom properties.
    
    .DESCRIPTION
        This function connects to a specified SolarWinds server using the provided credentials. It retrieves custom properties, 
        builds a SWQL query to fetch node data, determines if any custom properties need to be updated, and applies those updates.
    
    .PARAMETER Hostname
        The hostname or IP address of the SolarWinds server to connect to.
    
    .PARAMETER Username
        The username used to authenticate the connection to the SolarWinds server.
    
    .PARAMETER Password
        The password associated with the provided username for authentication.
    
    .EXAMPLE
        PS> Main -Hostname "solarwinds-server1" -Username "admin" -Password "password"
    
        Connects to the SolarWinds server 'solarwinds-server1', retrieves the node data, and updates custom properties as needed.
    
    .NOTES
        Author: Ryan Woolsey
        Last Edit: 9-20-2024
        Version: 1.1
        Keywords: SolarWinds, NodeUpdate, CustomProperties, OrionSDK
    
    .LINK
        https://github.com/solarwinds/OrionSDK/wiki/PowerShell
    
    .INPUTS
        None. The function accepts input from parameters.
    
    .OUTPUTS
        None. The function performs actions and logs updates but does not return any output.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, 
                   HelpMessage = "Provide the hostname or IP address of the SolarWinds server.")]
        [string]$Hostname,

        [Parameter(Mandatory = $true, 
                   HelpMessage = "Provide the username for authenticating with SolarWinds.")]
        [string]$Username,

        [Parameter(Mandatory = $true, 
                   HelpMessage = "Provide the password for the provided username.")]
        [string]$Password
    )

    # Log the server we're connecting to
    Write-Host "Connecting to SolarWinds server: $Hostname" -ForegroundColor Yellow

    # Connect to SWIS
    $swis = Connect-SolarWinds -Hostname $Hostname -Username $Username -Password $Password
    if (-not $swis) {
        Write-Error "Unable to connect to SolarWinds on $Hostname"
        return
    }

    # Retrieve custom property fields for the nodes
    $customProperties = Get-CustomPropertyFields -Swis $swis
    if (-not $customProperties) {
        Write-Error "Failed to retrieve custom properties from SolarWinds on $Hostname"
        return
    }

    # Build and execute the node query
    $query = Build-NodeQuery -CustomProperties $customProperties
    $nodeData = Get-NodeData -Swis $swis -Query $query
    if (-not $nodeData) {
        Write-Error "Failed to retrieve node data from SolarWinds on $Hostname"
        return
    }

    # Build the list of nodes that need updates based on custom property changes
    $nodeUpdates = Build-NodeUpdateList -Nodes $nodeData

    # Perform the updates if there are nodes to update
    if ($nodeUpdates.Count -gt 0) {
        Update-NodesInSolarWinds -Swis $swis -NodeUpdates $nodeUpdates
    }
    else {
        Write-Host "No updates required for nodes on server $Hostname" -ForegroundColor Green
    }
}

<#
.SYNOPSIS
    Executes the Main function for a list of SolarWinds servers to update node custom properties.

.DESCRIPTION
    This section of the script processes an array of SolarWinds server hostnames. 
    It calls the `Main` function for each server, using the provided credentials to connect 
    and update node custom properties if needed.

.EXAMPLE
    PS> .\Update-SolarWindsNodes.ps1

    Loops through the list of SolarWinds servers and applies custom property updates as necessary.

.NOTES
    Author: Ryan Woolsey
    Last Edit: 9-20-2024
    Version: 1.1
    Keywords: SolarWinds, NodeUpdate, CustomProperties, OrionSDK

.LINK
    https://github.com/solarwinds/OrionSDK/wiki/PowerShell

.INPUTS
    None. The list of servers and credentials are defined within the script.

.OUTPUTS
    None. The function performs actions and logs updates but does not return any output.
#>

# List of SolarWinds servers to process
$servers = @(
    'localhost',
    '10.217.161.203',  # LightHouse
    '10.60.15.200',    # Wish
    '10.59.15.206',    # Wonder
    '10.57.15.206',    # Fantasy
    '10.56.15.206',    # Dream
    '10.58.15.206',    # Magic
    '10.61.131.17'     # Castaway
)

# Credentials for connecting to the SolarWinds servers
$user = 'loop1'
$password = '30DayPassword!'

# Loop through each server and call the Main function
foreach ($server in $servers) {
    # Call the Main function with the current server, username, and password
    Main -Hostname $server -Username $user -Password $password 
}

