<#

.SYNOPSIS
Adds new IP ranges, either v4 or v6 to your subnets
.DESCRIPTION
This Powershell script add new ranges to subnets and takes care of the peering/unpeering automatically in seconds as compared to minutes
when performing manually in the Azure Portal
.PARAMETER IPAddressRange
The IP range you want to add in CIDR notation
.PARAMETER HubVNetRGName
Names the Resource Group containing the hub Virtual Network being targetted
.PARAMETER HubVNetName
Name of the hub Virtual Network being targetted
.EXAMPLE
.\Add-IPRange.ps1 -IPAddressRange 10.0.0.0/24 or 2607:f000:1000:42::/64 -HubVnetRGName RGNameforTargetVnet -HubVnetName TargetVnetName


The sample scripts provided here are not supported under any Microsoft standard support program or service. 
All scripts are provided AS IS without warranty of any kind. Microsoft further disclaims all implied warranties including, without limitation, 
any implied warranties of merchantability or of fitness for a particular purpose.
Copyright (c) Microsoft. All rights reserved.
#>

param (
    # Address Prefix range (CIDR Notation, e.g., 10.0.0.0/24 or 2607:f000:1000:42::/64)
    [Parameter(Mandatory = $true)]
    [String[]]
    $IPAddressRange,

    # Address Prefix range (Hub VNet Resource Group Name)
    [Parameter(Mandatory = $true)]
    [String]
    $HubVNetRGName, 

    # Address Prefix range (Hub VNet Name)
    [Parameter(Mandatory = $true)]
    [String]
    $HubVNetName
)

#Set context to Hub VNet Subscription
Get-AzSubscription -SubscriptionName YourSubscriptionName | Set-AzContext

#Get All Hub VNet Peerings and Hub VNet Object
$hubPeerings = Get-AzVirtualNetworkPeering -ResourceGroupName $HubVNetRGName -VirtualNetworkName $HubVNetName
$hubVNet = Get-AzVirtualNetwork -Name $HubVNetName -ResourceGroupName $HubVNetRGName

#Remove All Hub VNet Peerings
Remove-AzVirtualNetworkPeering -VirtualNetworkName $HubVNetName -ResourceGroupName $HubVNetRGName -name $hubPeerings.Name -Force

#Add IP address range to the hub vnet
$hubVNet.AddressSpace.AddressPrefixes.Add($IPAddressRange)
# Add $IPAddressRange to subnet
$subnet = $HUBvnet.subnets[0]
$subnet.addressprefix.add($IPAddressRange)

#Apply configuration stored in $hubVnet
Set-AzVirtualNetwork -VirtualNetwork $hubVNet

foreach ($vNetPeering in $hubPeerings) {
    # Get remote vnet name
    $vNetFullId = $vNetPeering.RemoteVirtualNetwork.Id
    $vNetName = $vNetFullId.Substring($vNetFullId.LastIndexOf('/') + 1)

    # Pull remote vNet object
    $vNetObj = Get-AzVirtualNetwork -Name $vNetName

    # Get the peering from the remote vnet object
    $peeringName = $vNetObj.VirtualNetworkPeerings.Where( { $_.RemoteVirtualNetwork.Id -like "*$($hubVNet.Name)" }).Name
    $peering = Get-AzVirtualNetworkPeering -ResourceGroupName $vNetObj.ResourceGroupName -VirtualNetworkName $vNetName -Name $peeringName

    # Reset to initiated state
    Set-AzVirtualNetworkPeering -VirtualNetworkPeering $peering

    # Re-create peering on hub
    Add-AzVirtualNetworkPeering -Name $vNetPeering.Name -VirtualNetwork $HubVNet -RemoteVirtualNetworkId $vNetFullId -AllowGatewayTransit

}