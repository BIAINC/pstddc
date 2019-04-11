Import-Module TotalDiscovery

# This script will send an email for each matter that has released or added custodions within the change period. 

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

### Tracks the custodians on hold
$holdTracker = @{}

### Main Application code
Connect-TDDC -AuthToken $authToken -Server "preserve.catalystapps.com"

#### Gather a list of matters in the account
$matters = @()
$companyIds | ForEach-Object {
  $matters += Get-Matters -Company $_
}

#### Gather a list of emails to send
$emailsToSend = $matters | ForEach-Object {
  $matter = $_
  $custodians = @()
  write-host "Processing $($_.name)"
  $custodians = New-Object System.Collections.ArrayList
  $lhs = Get-LegalHolds $_.id

  $lhs | ForEach-Object {
    $_.custodians_legal_holds | ForEach-Object {
      # Track custodians on hold
      if( -not $holdTracker.ContainsKey($_.custodian.id) ) {
        $holdTracker[$_.custodian.id] = 0
      }

      if ( $_.released_at -eq $null ) {
        $holdTracker[$_.custodian.id]++
      }

      # Create a list of custodians that have been added or released from holder during the time frame
      if(
        ($_.sent_at -gt $startDate -and $_.sent_at -lt $endDate) -or
        ($_.released_at -gt $startDate -and $_.released_at -lt $endDate)
      ){
        $custodians.Add($_) | out-null
      }
    }
  }

  if($custodians.Length -gt 0) {
    Write-Output (New-Object -TypeName PSObject -Property @{
      Matter = $matter
      Custodians = $custodians
    })
  }
}

$emailsToSend | ForEach-Object {
  $emailData = $_
  $mh = New-Object System.Collections.ArrayList
  # Build the table view of the matter email
  $emailData.Custodians | ForEach-Object {

    # Check and see if the custodian is on any other holds
    if($holdTracker[$_.custodian.id] -ne 0) {
      $onOtherHolds = "Yes"
    } else {
      $onOtherHolds = "No"
    }

    # Figure out the action that is being performed
    if($_.released_at -ne $null) {
      $status = "Released"
    } else {
      $status = "Added"
    }

    # Add the custodian to the custodians list
    $mh.Add((New-Object -TypeName PSObject -Property @{
        "Employee Name" = $_.custodian.name
        "Employee Email" = $_.custodian.email
        "Employee Number" = $_.custodian.employee_id
        "Employee Status" = $_.custodian.employee_status
        "Employee Status Change Date" = $_.custodian.employee_status_changed_at
        "Released Date" = $_.released_at
        "Sent Date" = $_.sent_at
        "Status" = $status
        "On Other Holds" =  $onOtherHolds

      }) ) | Out-Null
  }

    $messageBody = $mh | Select-Object "Employee Name", "Employee Email", "Employee Number", "Employee Status", "Employee Status Change Date", "Status", "Released Date", "Sent Date", "On Other Holds"  | ConvertTo-Html -Head $style
    Send-MailMessage -To $mailTo -BodyAsHtml -Body ([System.String]$messageBody) -Subject "Legal Hold Update - $($emailData.Matter.name)" -SmtpServer $smtpServer -From $fromAddress -WarningAction SilentlyContinue
}

Export-Clixml -Path $trackerFile -InputObject $endDate