MDMCleanup.ps1
# A script to Find Moblie Devices and remove Unused Devices, some of this script is borrowed from #https://github.com/12Knocksinna/Office365itpros/blob/master/Report-MobileDevices.PS1

# Remove Report Files
Remove-Item 'C:temp\MoblieDviceCleanup\MobileDevices.csv'
Remove-Item 'C:\temp\MoblieDeviceCleanup\MobileDevices.html'

#CUSTOM SMTP SETTINGS
$Company = "Company Name"
$From = xxx@xxx.com
$To = @(xxx@xxx.com)
$SMTPServer = "xxx.xxx.com"   


#DATE & TIME
$StartTime = (Get-Date)                     #Used later to calculate execution time
$Error.Clear()                              #Clear errors to start fresh
$Today = (get-date).ToString("MM-dd-yyyy")  #Used for the reportfile and emai




# Setting HTML header Information
$HtmlHead ="<html>
                  <style>
                  BODY{font-family: Arial; font-size: 8pt;}
                  H1{font-size: 22px; font-family: 'Segoe UI Light','Segoe UI','Lucida Grande',Verdana,Arial,Helvetica,sans-serif;}
                  H2{font-size: 18px; font-family: 'Segoe UI Light','Segoe UI','Lucida Grande',Verdana,Arial,Helvetica,sans-serif;}
                  H3{font-size: 16px; font-family: 'Segoe UI Light','Segoe UI','Lucida Grande',Verdana,Arial,Helvetica,sans-serif;}
                  TABLE{border: 1px solid black; border-collapse: collapse; font-size: 8pt;}
                  TH{border: 1px solid #969595; background: #dddddd; padding: 5px; color: #000000;}
                  TD{border: 1px solid #969595; padding: 5px; }
                  td.pass{background: #B7EB83;}
                  td.warn{background: #FFF275;}
                  td.fail{background: #FF2626; color: #ffffff;}
                  td.info{background: #85D4FF;}
                  </style>
                  <body>
           <div align=center>
           <p><h1>Microsoft 365 Mailboxes with Synchronized Mobile Devices</h1></p>
           <p><h3>Generated: " + (Get-Date -format 'dd-MMM-yyyy hh:mm tt') + "</h3></p></div>"

$Version = "1.0"
# Report Files
$HtmlReportFile = "C:temp\MoblieDeviceCleanup\MobileDevices.html"
$CSVReportFile = "C:temp\MoblieDeviceCleanup\MobileDevices.csv"

# Connect To Excchange Online using a Cert From Microsoft Graph
Connect-ExchangeOnline -CertificateThumbPrint "Your Cert Thumb Print" -AppID "Your AppID Here" -Organization "xxx.onmicrosoft.com"

# Get O365 Org Name
$Organization = Get-OrganizationConfig | Select-Object -ExpandProperty DisplayName

# Get Mailbox and Mobile Devices
$Mbx = Get-ExoMailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox | Sort-Object DisplayName
If (!($Mbx)) { Write-Host "Unable to find any user mailboxes..." ; break }

$Report = [System.Collections.Generic.List[Object]]::new() 

[int]$i = 0
ForEach ($M in $Mbx) {
$i++
Write-Host ("Scanning mailbox {0} for registered mobile devices... {1}/{2}" -f $M.DisplayName, $i, $Mbx.count)
$Devices = Get-MobileDevice -Mailbox $M.DistinguishedName

ForEach ($Device in $Devices) {
   $DaysSinceLastSync = $Null; $DaySinceFirstSync = $Null; $SyncStatus = "OK"
   $DeviceStats = Get-ExoMobileDeviceStatistics -Identity $Device.id
   If ($Device.FirstSyncTime) {
      $DaysSinceFirstSync = (New-TimeSpan $Device.FirstSyncTime).Days }
   If (!([string]::IsNullOrWhiteSpace($DeviceStats.LastSuccessSync))) {
      $DaysSinceLastSync = (New-TimeSpan $DeviceStats.LastSuccessSync).Days }
   If ($DaysSinceLastSync -gt 30)  {
      $SyncStatus = ("Warning: {0} days since last sync" -f $DaysSinceLastSync) }
   If ($Null -eq $DaysSinceLastSync) {
      $SyncStatus = "Never synched" 
      $DeviceStatus = "Unknown" 
   } Else {
      $DeviceStatus =  $DeviceStats.Status }
   $ReportLine = [PSCustomObject]@{
     ID                 = $Device.Id
     DeviceID           = $Device.Identity
     DeviceOS           = $Device.DeviceOS
     Model              = $Device.DeviceModel
     UA                 = $Device.DeviceUserAgent
     User               = $Device.UserDisplayName
     UPN                = $M.UserPrincipalName
     FirstSync          = $Device.FirstSyncTime
     DaysSinceFirstSync = $DaysSinceFirstSync
     LastSync           = $DeviceStats.LastSuccessSync
     DaysSinceLastSync  = $DaysSinceLastSync
     SyncStatus         = $SyncStatus
     Status             = $DeviceStatus
     
     Policy             = $DeviceStats.DevicePolicyApplied
     State              = $DeviceStats.DeviceAccessState
     LastPolicy         = $DeviceStats.LastPolicyUpdateTime
     DeviceDN           = $Device.DistinguishedName }
   $Report.Add($ReportLine)
} #End Devices
} #End Mailboxes
# Mailboxes and Devices to Put into the report

$SyncMailboxes = $Report | Sort-Object UPN -Unique | Select-Object UPN
$SyncDevices = $Report | Sort-Object DeviceId -Unique | Select-Object DeviceId
#This is the number of days you are setting to remove devices. The default I set is 90. This sets up to arrays, one with devices 90 days and over and one with devices 90 days and under.
$SyncDevices90 = $Report | Where-Object {$_.DaysSinceLastSync -gt 90} 
$SyncDevices90less = $Report | Where-Object {$_.DaysSinceLastSync -lt 90} 
$HtmlReport = $Report | Select-Object DeviceId, DeviceOS, Model, UA, User, UPN, FirstSync, DaysSinceFirstSync, LastSync, DaysSinceLastSync | Sort-Object UPN | ConvertTo-Html -Fragment

# Create the HTML report
$Htmltail = "<p>Report created for: " + ($Organization) + "</p><p>" +
             "<p>Number of mailboxes:                          " + $Mbx.count + "</p>" +
             "<p>Number of users synchronzing devices:         " + $SyncMailboxes.count + "</p>" +
             "<p>Number of synchronized devices:               " + $SyncDevices.count + "</p>" +
             "<p>Number of devices not synced in last 90 days and Removed: " + $SyncDevices90.count + "</p>" 
                    "<p>Number of devices synced in last 90 days:     " + $SyncDevices90less.count + "</p>" 
             "<p>-----------------------------------------------------------------------------------------------------------------------------" +
             "<p>Microsoft 365 Mailboxes with Synchronized Mobile Devices<b>" + $Version + "</b>"   
$HtmlReport = $HtmlHead + $HtmlReport + $HtmlTail
$HtmlReport | Out-File $HtmlReportFile  -Encoding UTF8

$Report | Export-CSV -NoTypeInformation $CSVReportFile

# Remove Devcies that have not Sync in the last 90 days
ForEach ($OldDevice in $SyncDevices90){


remove-MobileDevice -Identity $OldDevice[0].Id -Confirm:$False
}

#CUSTOM MESSAGE SUBJECT
    $MessageSubject = "XXX mobile device report $Today"
    
    
    
#Send Email   
Send-MailMessage -To $To -From $From -Subject $MessageSubject -SmtpServer $SMTPServer -Body $HtmlReport -BodyAsHtml -Attachments $CSVReportFile
