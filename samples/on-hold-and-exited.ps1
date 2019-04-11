Import-Module TotalDiscovery
$ErrorActionPreference = Stop
# This script will send an email for each custodian that is on hold and has had a change in status 

### Customize Here ###

# The list of addresses to send this email to
$mailTo = @("youraccount@yourdomain.com")

# The TotalDiscovery API Token
$authToken = "YOUR_TOTAL_DISCOVERY_AUTH_TOKEN"

# The SMTP Server to send mail throught
$smtpServer = "address.of.your.smtp.server"


# The address that this email should be from, we recommend a shared legal mailbox
$fromAddress = "from@yourdomain.com"

# A list of companies ids that this report should generate emails for, these are the two
# companies already in your account
#$companyIds = @(COMPANYID1,COMPANYID2)
$companyIds = @(COMPANYID1,COMPANYID2)

# A file that is used to store the last sucessful run of the script so that all notifications are for new data
$trackerFile = "tracker.xml"


### DO NOT MODIFY ###

$style = "
<style>
TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
</style>
"

$startDate = (Get-Date).AddDays(-1)
if (Test-Path $trackerFile -PathType Leaf) {
  $startDate = Import-Clixml -Path $trackerFile
} else {
  Write-Warning "Date tracker was not found, results will only be generated for the last 24 hours"
}

$endDate = (Get-Date)

### Main Application code
Connect-TDDC -AuthToken $authToken -Server "preserve.catalystapps.com"

#### Gather a list of matters in the account
$matters = @()
$companyIds | ForEach-Object {
  $matters += Get-Matters -Company $_
}

$mh = New-Object System.Collections.ArrayList

#### Gather a list of emails to send
$matters | ForEach-Object {
  write-host "Processing $($_.name)"
  $lhs = Get-LegalHolds $_.id

  $lhs | ForEach-Object {
    $lh = $_
    $_.custodians_legal_holds | ForEach-Object {

      if (  ($_.released_at -eq $null) -and
            (-not $_.employee_status_changed_at -eq $null) -and
            ((Get-Date $_.employee_status_changed_at) -gt $startDate -and $_.released_at -lt $endDate) ) {
        Write-Host $_
        $mh.Add((New-Object -TypeName PSObject -Property @{
          "Employee Name" = $_.custodian.name
          "Employee Email" = $_.custodian.email
          "Employee Number" = $_.custodian.employee_id
          "Employee Status" = $_.custodian.employee_status
          "Employee Status Change Date" = $_.custodian.employee_status_changed_at
          "Legal Hold Name" = $lh.Name
    
        }) ) | Out-Null
      }

    }
  }
}



if ($mh.Length -gt 0) {
  $messageBody = $mh | Select-Object "Employee Name", "Employee Email", "Employee Number", "Employee Status", "Employee Status Change Date", "Legal Hold Name"  | ConvertTo-Html -Head $style
  Send-MailMessage -To $mailTo -BodyAsHtml -Body ([System.String]$messageBody) -Subject "Exiting Employee Email" -SmtpServer $smtpServer -From $fromAddress -WarningAction SilentlyContinue  
}

Export-Clixml -Path $trackerFile -InputObject $endDate