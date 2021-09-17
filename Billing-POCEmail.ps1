<# 

.SYNOPSIS
Emails a weekly usage billing report to Resource Group (RG) owners.

.DESCRIPTION
This script parses a custom tag (Line 36) that will have to be created and pushed out to all RGs. Owners email addresses will need to be inputted in those tags. No matter how many RGs
an individual owner has, they will only get one email with a spreadsheet attached from each RG. Acceptable delimiters are "," and ";". Add a Trim() command below Line 89 for your delimiter

.EXAMPLE
Can be run stand-alone or in an Azure Function/ASE

#>

function New-CellData {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Does not change system state')]
    param(
        $Range,
        $Value,
        $Format
    )
    $setFormatParams = @{
        Worksheet    = $worksheet
        Range        = $Range
        NumberFormat = $Format
    }
    if ($Value -is [string] -and $Value.StartsWith('=')) {
        $setFormatParams.Formula = $Value
    }
    else {
        $setFormatParams.Value = $Value
    }
    Set-ExcelRange @setFormatParams

}
$TagName = 'CustomBillingTagName'

$date = (Get-Date).AddDays(0).ToString('yyyy-MM-dd')
$weekbeforedate = (Get-Date).AddDays(-7).ToString('yyyy-MM-dd')
$smtpserver = 'smtpserver.contoso.com'

$subscriptions = Get-AzSubscription
foreach ($subscription in $subscriptions) {
    Select-AzSubscription -Subscription $subscription.Id

    $context = Get-AzContext
    Set-AzContext -Context $context

    #gets a list of filtered RG's with the matched Tag Name
    $resourcegroups = Get-AzResourceGroup | Where-Object { $_.Tags.Keys -match $TagName }


    # $resourcegroups = Get-AzResourceGroup -Name 'AZ-GOV-MGMT-IC-TEST4-VA' | Where-Object { $_.Tags.Keys -match $TagName }
    $resourcegroups = foreach ($RG in $RGtest) 
    { Get-AzResourceGroup -Name $RG | Where-Object { $_.Tags.Keys -match $TagName } }

   

    # build all the reports first
    foreach ($resourcegroup in $resourcegroups) {
        $pathandfilexlsx = Join-Path -Path '.' -ChildPath "ConsumptionUsageDetail-$($resourceGroup.ResourceGroupName)-$($date).xlsx"
        $output = Get-AzConsumptionUsageDetail -StartDate $weekbeforedate -EndDate $date -ResourceGroup $resourcegroup.ResourceGroupName -IncludeMeterDetails -IncludeAdditionalProperties
        $output | Select-Object 'InstanceName', 'InstanceLocation', 'product', 'ConsumedService', 'usagestart', 'usageend', 'usagequantity', 'pretaxcost' | Export-Excel -Path $pathandfilexlsx -WorksheetName $resourcegroup.ResourceGroupName -Numberformat 'General' -AutoSize -AutoFilter -FreezeTopRow -Calculate
    }

    # get a list of unique contacts
    $contacts = ($resourcegroups.Tags).$TagName 
    $contacts = ($contacts -split ',').Trim()
    $contacts = ($contacts -split ';').Trim()
    $contacts = $contacts | Select-Object -Unique

    # loop through individual contacts instead of resourcegroups
    foreach ($contact in $contacts) {
        # attach all ResourceGroups that where the individual is identified
        $attachments = [System.Collections.ArrayList]::new()
        $resourcegroups | Where-Object { $_.Tags[$TagName] -like "*$($contact)*" } | ForEach-Object {
            $resourceGroup = $_
            $attachments += Join-Path -Path '.' -ChildPath "ConsumptionUsageDetail-$($resourceGroup.ResourceGroupName)-$($date).xlsx"
        }

        $subject = ('Azure Consumption Usage Details')
        $body = -join ('Hello, This is an automated message sending a document.  Attached in this e-mail is the Azure Usage and Consumption Report for the Resource Group ' + $resourcegroup.ResourceGroupName + ' Begining from ' + $weekbeforedate + ' and ending on ' + $date + '.')
        Send-MailMessage -From ContoseCLoudAdmins@noreply.com -To $contact -Subject $subject -Body $body -SmtpServer $smtpserver -Attachments $attachments
    }

    # clean up all files
    Remove-Item -Path "ConsumptionUsageDetail-*.xlsx"
}
