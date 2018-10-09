#requires -version 5 
#requires -modules ServerManager
#requires -RunAsAdministrator

<#
    TO-DO:
    - [Optional/Future] Create the black hole website
       - Install IIS
       - Configure IIS
       - Build site
       - Test

#>

# Setup DNS server as a caching/forwarder DNS server

param (
    # Hostname or IP of the DNS server. Default is the local host.
    $computerName = '.',

    ### Forwarder settings ###
    # Forwarder IP addresses.
    # CloudFlare DNS servers are setup by default. These IPs are:
    # - IPv4: 1.1.1.1, 1.0.0.1
    # - IPv6: 2606:4700:4700::1111, 2606:4700:4700::1001
    [string[]]$forwarderIPv4 = @("1.1.1.1", "1.0.0.1"), 
    [string[]]$forwarderIPv6 = @("2606:4700:4700::1111", "2606:4700:4700::1001"),

    # Option to not add IPv6 forwarders
    [switch]$forwarderNoIPv6 = $false,

    # Forwarder timeout. Default is 3 seconds.
    [int]$forwarderTimeout = 3,

    # Do not use root hints when forwarder fails. Default is FALSE ().
    [boolean]$forwarderUseRootHints = $true

)


##### INITIALIZE #####

# import global settings
$settings = Get-Content .\settings.json | ConvertFrom-Json

# path to save files and log
$script:dataPath = $PSScriptRoot

# log filename
$script:logName = $settings.logName



##### VALIDATION #####
#region

# make sure the support scripts are there
[string[]]$supportScripts = $settings.supportScripts

[boolean]$scriptMissing = $false

foreach ($file in $supportScripts)
{
    $isScriptFnd = Get-Item "$PSScriptRoot\$file" -EA SilentlyContinue
    if (-not $isScriptFnd)
    {
        $scriptMissing = $true
        Write-Error "A support script is missing: $file"
    }
}

# exit if there is a missing support script
if ($scriptMissing)
{
    Write-Output "Execution is stopping due to missing support script(s)."
    exit
}


#endregion VALIDATION


##### FUNCTIONS #####
#region

# load common functions
. $PSScriptRoot\Load-WinHoleFunctions.ps1

#endregion FUNCTIONS


##### MAIN #####

# check whether DNS Server role is installed
$isDnsInstalled = Get-WindowsFeature DNS
if (-not $isDnsInstalled.Installed)
{
    Write-Log "Installing DNS Server."
    try {
        Install-WindowsFeature DNS -IncludeAllSubFeature -IncludeManagementTools -Confirm:$false -ErrorAction Stop
    }
    catch {
        Write-Log "ERROR: Failed to install DNS Server."
        Write-Error "Failed to install DNS Server."
        exit
    }
}


### build file structure ###
Write-Log "Checking directory structure."
$isSavePathFnd = Test-Path $settings.savePath -EA SilentlyContinue
if (-not $isSavePathFnd)
{
    # create the base folder
    Write-Log "Creating $($settings.savePath)"
    mkdir $settings.savePath -Force | Out-Null

    # create the bin folder
    Write-Log "Creating $($settings.savePath)\bin"
    mkdir "$($settings.savePath)\bin" -Force | Out-Null

    # create data folder
    Write-Log "Creating $($settings.savePath)\data"
    mkdir "$($settings.savePath)\data" -Force | Out-Null
} else {
    # make sure the data and bin folders are there
    if (-not (Test-Path "$($settings.savePath)\bin"))
    {
        # create the bin folder
        Write-Log "Creating $($settings.savePath)\bin"
        mkdir "$($settings.savePath)\bin" -Force | Out-Null
    }

    if (-not (Test-Path "$($settings.savePath)\data"))
    {
        # create the bin folder
        Write-Log "Creating $($settings.savePath)\data"
        mkdir "$($settings.savePath)\data" -Force | Out-Null
    }
}
Write-Log "Directory structure test complete."

# move the log to the new directory sctructure
Write-Log "Porting the log to the bin dir."
$script:dataPath = $settings.savePath

Copy-Item "$PSScriptRoot\$script:logName" $script:dataPath -Force -PassThru:$false
Remove-Item "$PSScriptRoot\$script:logName" -Force | Out-Null


# copy the scripts to the bin folder
Write-Log "Copying scripts to the bin directory"
foreach ($file in $supportScripts)
{
    Write-Log "Copying $file"
    Copy-Item "$PSScriptRoot\$file" "$script:dataPath\bin" -Force
}


### Setup DNS Forwarders ###

# create a complete list of forwarders based on whether IPv6 is allowed or not
if ($noIPv6Fwdr)
{
    Write-Log "IPv6 forwarders are disabled."
    [string[]]$allForwarders = $forwarderIPv4
} else
{
    Write-Log "Combining IPv4 and IPv6 forwarders."
    [string[]]$allForwarders = $forwarderIPv4 + $forwarderIPv6
}

# set the forwarder details
Write-Log "Setting up te DNS Server forwarder: Set-DnsServerForwarder -ComputerName $computerName -IPAddress $allForwarders -UseRootHint $forwarderUseRootHints -Timeout $forwarderTimeout"
Set-DnsServerForwarder -ComputerName $computerName -IPAddress $allForwarders -UseRootHint $forwarderUseRootHints -Timeout $forwarderTimeout


### Collect Initial Ad/Malware Blacklist ###

# execute Get-AdList.ps1
Push-Location "$script:dataPath\bin"
Write-Log "Generating the initial ad/malware blacklists."
$result = .\Get-WinHoleBlackList.ps1
Write-Log "Result of Get-WinHoleBlackList: $result"

if ($result)
{
    $isBlackListFnd = Get-Item $result -ErrorAction SilentlyContinue

    if (-not $isBlackListFnd)
    {
        Write-Log "Error accessing blacklist file."
        exit
    } else {
        Write-Log "Confirmed the blackhole file."
    }

} else {
    Write-Log "Execution is stopping due to missing blacklist file."
    exit
}

### Create the DNS policy to block 

.\Set-WinHoleDnsPolicy.ps1