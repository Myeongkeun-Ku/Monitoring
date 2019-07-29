# To use Servername, must register the server ip in the hosts file.
# Otherwise, must use the server ip

<#hosts
10.1.0.1 GameServer1
10.1.0.2 GameServer2
#>

<#Servername.txt
GameServer1:3389 << RDP
GameServer1:50001 << GameServer Application Port
#>

# Load server list
$ServerListPath = 'C:\PSTools\Servername.txt'

# Ignore all error due to excute PowerSehll command
$ErrorActionPreference = "SilentlyContinue"

Foreach ($Server in (Get-Content $ServerListPath -ReadCount 0)) {
    
    # To ensure execution even after terminate of terminal, run script on background

    $ServerName = ($Server -split ':')[0]
    $ServerPort = ($Server -split ':')[1]

    Start-Job -Name $ServerName -ErrorAction SilentlyContinue {
        param([string]$ServerName, [String]$ServerPort)

        $TCPConnectivity = $false
        $SentTCPWebhook = $false
        $SPAlertTimeTCP = $null
        $CheckInterval = 10 #second
        $AlertInterval = 1 #minute

        While ($true) {            
            $DropTCPNumber = 0    

            $ErrorActionPreference = "SilentlyContinue"

            $ping = "& C:\PSTools\psping.exe -n 5 -i 0 -w 1 $ServerName`:$ServerPort -nobanner"
            $pingCommand = Invoke-Expression $ping
            $pingResult = $pingCommand[-2]
            $pingLatency = $pingCommand[-1]
            $pingLatencyAvg = ($pingLatency.split(" "))[10].replace("ms","")
            $pingLatencyMin = ($pingLatency.split(" "))[4].replace("ms,","")
            $pingLatencyMax = ($pingLatency.split(" "))[7].replace("ms,","")
            $pingLossPercent = ($pingResult.Split(" "))[-2].replace("(","").replace("%","")

            if ($pingResult -imatch "Received = 5") {
                $TCPConnectivity = $true
            } elseif ($pingResult -imatch "Received = 0") {
                $TCPConnectivity = $false
                $SentTCPWebhook = $true
            } else {
                $TCPConnectivity = $false
                $DropTCPNumber = $pingResult.Split(" ")[-3]
            }

            if ($TCPConnectivity -eq $false) {
                if (($SentTCPWebhook -eq $true)) {
            
                    if ( ($SPAlertTimeTCP -eq $null) -or (((Get-Date)-$SPAlertTimeTCP).Minutes -gt $AlertInterval) ) {
                        $SPAlertTimeTCP = (Get-Date)
                        $attachments = @(@{
                            "pretext" = "[Network-Alert]"
                            "title" = [string]$ServerName
                            "color"="danger"
                            "text"= "*Server Port `:$ServerPort* Connectivity Problem at _$SPAlertTimeTCP`_"
                        })

                        # Slake Webhook URL
                        $webhook = "https://hooks.slack.com/services/************************************"

                        $body = @{attachments=$attachments; channel="#test"; username="Network Checker BOT"} | ConvertTo-Json
                        $webhookMSFT = Invoke-WebRequest -Method Post -Uri $webhook -Body $body | Out-Null
                    }
                }
            }

            ######################
            ## Normal Connectivity
            ######################
    
            # else {
            #    if (($SentTCPWebhook -eq $true)) {
            #        $SPAlertTimeTCP = (Get-Date)
            #        $attachments = @(@{
            #            "pretext" = "[Network-Alert]"
            #            "title" = [string]$ServerName
            #            "color"="normal"
            #            "text"= "*Server Port `:$ServerPort* Connectivity normal at _$SPAlertTimeTCP`_"
            #       })
            #
            #        $webhook = "https://hooks.slack.com/services/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"
            #        $body = @{attachments=$attachments; channel="#test"; username="Network Checker BOT"} | ConvertTo-Json
            #        $webhookMSFT = Invoke-WebRequest -Method Post -Uri $webhook -Body $body | Out-Null
            #
            #        $SentTCPWebhook = $false
            #    }
            #    
            #}
    

            Start-Sleep -Seconds $CheckInterval
        } #while($true)

    } -ArgumentList $Servername, $ServerPort
}