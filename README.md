# ExchangeMoblieDevicecleanup
To operate this script you will need to create a Microsoft Enterprise Graph Application with the ability to read and write to Exchange users. The method I choose to access the graph is TLS certifiate. You can also use a secert if you wanted to go that route. You could also use a username and password to access ExchangeOnline, but I am moving away from that method when I am automating scripts.

You will want to make sure you update this section of the script if you want to change the number of days a device is stale before removing it.
#This is the number of days you are setting to remove devices. The default I set is 90. This sets up to arrays, one with devices 90 days and over and one with devices 90 days and under.
#$SyncDevices90 = $Report | Where-Object {$_.DaysSinceLastSync -gt 90} #
#$SyncDevices90less = $Report | Where-Object {$_.DaysSinceLastSync -lt 90} #
