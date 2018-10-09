#requires -version 5

# get pi-hole ad list

# import global settings
$settings = Get-Content .\settings.json | ConvertFrom-Json


##### INITIALIZE #####
#region

[string[]]$listOfLists = $settings.listOfBlockLists

# exclusions for hosts files
[string[]]$hostExclusions = $settings.hostExclusions

# create a regex object of the host exlusions
[regex]$hostsEx = "{$($hostExclusions -join '|')}"


# regex pattern for IPv4 addresses
[regex]$IPv4Pattern = "\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b"

# regex pattern for IPv6 addresses
[regex]$IPv6Pattern = '(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))'

# path to save files and log
$script:dataPath = $settings.savePath

# log filename
$script:logName = $settings.logName

#endregion INITIALIZE


##### FUNCTIONS #####
#region

# load common functions
. $PSScriptRoot\Load-WinHoleFunctions.ps1

#endregion FUNCTIONS


##### MAIN #####

# make sure the data path is there
if (!(Test-Path $script:dataPath)) {
    mkdir $script:dataPath -Force | Out-Null
    Write-Log "Creating data directory: $script:dataPath"
}

# get the public block lists
Write-Log "Getting pi-hole ad lists."

# stores a list of successfully downloaded block lists
$adFiles = @()

$c = 0
$listOfLists | ForEach-Object {
    # create the local file with "hosts" for hosts files, and "file" for everything else
    # the filename determines which parsing engine to use
    if ($_ -match "hosts")
    {
        $outName = "hosts_$("{0:00}" -f $c)`.txt"
    } else {
        $outName = "file_$("{0:00}" -f $c)`.txt"
    }

    # download the file
    $result = Get-WebFile -dlUrl $_ -output "$script:dataPath\$outName"

    if ($result)
    {
        $adFiles += "$script:dataPath\$outName"
    }
    
    $c++
}

# parse and aggregate the ad lists
Write-Log "Parsing the adlists."
$blackList = @()

foreach ($file in $adFiles)
{
    switch -Regex ($file)
    {
        "hosts_\d{2}.txt"  {
                # parse as hosts file
                Write-Log "Parsing hosts file: $file"
                $tmpList = Get-Content $file | Where-Object {$_ -notmatch "^\s+#.*$" -and $_ -notmatch "#.*$" -and $_ -ne "" -and ($_ -match $IPv4Pattern -or $_ -match $IPv6Pattern) -and $_ -notmatch $hostsEx} | ForEach-Object {
                    ($_ -replace "\s+"," ").Trim(" ").Split(" ")[-1]
                }
                break
        }

        "file_\d{2}.txt"  {
                # parse as generic file
                Write-Log "Parsing file: $file"
                $tmpList = Get-Content $file | Where-Object {$_ -notmatch "^\s+#.*$" -and $_ -notmatch "#.*$" -and $_ -ne ""} | ForEach-Object {
                                ($_ -replace "\s+"," ").Trim(" ").Split(" ")[-1]
                            }
        }

        default { Write-Log "Unknown file type: $file" }
    }

    $blackList += $tmpList
}



Write-Log "Unfiltered blacklist total: $($blackList.Count)"
#$blackList = $blackList | Where-Object {$_ -notmatch $IPv4Pattern -and $_ -notmatch $IPv6Pattern} | Sort-Object -Unique  | ForEach-Object {"*.$_`."}
$blackList = $blackList | Where-Object {$_ -notmatch $IPv4Pattern -and $_ -notmatch $IPv6Pattern} | Sort-Object -Unique
Write-Log "Filtered blacklist total: $($blackList.Count)"

# write results to blacklist.txt
Write-Log "Writing blacklist to file: $script:dataPath\blacklist.txt"
$blackList | Out-File "$script:dataPath\data\$($settings.blackholeDnsList)" -Force

# clean up the downloads
Write-Log "Cleaning up downloads."
$adFiles | Remove-Item -Force

Write-Log "Work complete!"

return "$script:dataPath\data\$($settings.blackholeDnsList)"