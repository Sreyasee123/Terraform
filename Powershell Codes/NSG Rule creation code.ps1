# Function to ensure the address is in CIDR format
function Convert-ToCIDR($addressPrefix) {
    # Check if it's an IP address (not a service tag) and ensure it's in CIDR format
    if ($addressPrefix -match "^\d{1,3}(\.\d{1,3}){3}$") {
        return "$addressPrefix/32"  # If it's an IP, return as /32 CIDR block
    }
    return $addressPrefix  # Otherwise return as is (could be a service tag)
}

# Path to your CSV file
$csvFilePath = "C:\Users\pc\Downloads\testNsgRules.csv"

# Import the CSV file
$nsgData = Import-Csv -Path $csvFilePath

# Login to Azure account (if not logged in already)
Connect-AzAccount

# Loop through each row in the CSV and create the NSG rule
foreach ($row in $nsgData) {
    $nsgName = $row.NSGName
    $location = $row.Location
    $direction = $row.Direction.Trim()  # Trim any extra spaces
    $ruleName = $row.Name
    $source = $row.Source
    $sourceIP = $row.'Source IP/Source service tag'
    $sourcePort = $row.'Source port'
    $destination = $row.Destination
    $destinationIPs = $row.'Destination IP addresses/CIDR ranges' -split ",\s*"  # Split multiple IPs
    $service = $row.Service
    $destinationPortRange = $row.'Destination port range' -split ",\s*"  # Split multiple ports
    $protocol = $row.Protocol
    $action = $row.Action
    $priority = $row.Priority
    $machineId = $row.'Machine ID'
    $resourceGroup = $row.ResourceGroupName

    # Convert source and destination IPs to CIDR format
    $sourceIP = Convert-ToCIDR $sourceIP
    $destinationIPs = $destinationIPs | ForEach-Object { Convert-ToCIDR $_ }

    # Get the existing NSG
    $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup -Name $nsgName

    # Create the new security rule configuration
    $ruleParams = @{
        Name                      = $ruleName
        Direction                 = $direction
        SourceAddressPrefix       = $sourceIP  # Using service tag or IP address
        SourcePortRange           = $sourcePort
        DestinationAddressPrefix  = $destinationIPs  # Multiple destination prefixes
        DestinationPortRange      = $destinationPortRange  # Multiple destination ports
        Protocol                  = $protocol
        Access                    = $action
        Priority                  = $priority
        Description               = "Rule for $machineId"
    }

    # If any of the fields are not set, handle the defaults:
    if ($protocol -eq "Any") {
        $ruleParams['Protocol'] = '*'
    }

    # Create the security rule
    $securityRule = New-AzNetworkSecurityRuleConfig @ruleParams

    # Initialize an empty list for the SecurityRules if not already initialized
    if ($null -eq $nsg.SecurityRules) {
        $nsg.SecurityRules = New-Object System.Collections.Generic.List[Microsoft.Azure.Commands.Network.Models.PSSecurityRule]
    }

    # Add the new rule to the existing list
    $nsg.SecurityRules.Add($securityRule)

    # Apply the changes to the NSG
    $nsg | Set-AzNetworkSecurityGroup

    Write-Host "NSG Rule '$ruleName' created successfully for NSG: '$nsgName' in location: '$location'"
}

Write-Host "All NSG rules processed successfully!"
