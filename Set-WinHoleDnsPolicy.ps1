#requires -version 5
#requires -modules ServerManager,DnsServer

Set-StrictMode -Version Latest

# import global settings
$settings = Get-Content .\settings.json | ConvertFrom-Json


$winHoleBasePolicyName = "WinHoleBlacklist"


function Get-DnsPolicyState
{
    param($policyName)

    Try
    {
        Get-DnsServerQueryResolutionPolicy -Name $policyName -ErrorAction Stop
    }
    Catch
    {
        return $False
    }

    return $True
}

function Set-DnsBlackholePolicy
{
    param($PolicyExists,$BlackListPolicyName,$FqdnPolicyString)
    
    if ($PolicyExists)
    {
        Set-DnsServerQueryResolutionPolicy -Name $BlackListPolicyName -Fqdn $FqdnPolicyString

        Write-Verbose 'DNS Server Query Resolution Policy updated.'
    }
    else
    {
        Add-DnsServerQueryResolutionPolicy -Name $BlackListPolicyName -Action DENY -Fqdn $FqdnPolicyString

        Write-Verbose 'DNS Server Query Resolution Policy created.'
    } 

}


# Example: Set-DnsServerQueryResolutionPolicy -Name BlockListPolicy -Fqdn 'EQ,*.doubleclick.com,*.doubleclick.net' -Action DENY

# read first 10 URLs from the blacklist list
$bhlAll = Get-Content "$($settings.savePath)\data\$($settings.blackholeDnsList)"

if ($bhlAll.Count -gt 1000)
{
    [int]$numPolicies = $bhlAll.Count / 1000

    for ($i = 0; $i -lt $numPolicies; $i++)
    {
        if ((($bhlAll.Count) - ($i * 1000)) -ge 1000)
        {
            $srtNum = $i * 1000
            $endNum = ($i + 1) * 1000 - 1
            $tmp = $bhlAll[$srtNum..$endNum]
        } else {
            $srtNum = $i * 1000
            $endNum = ($bhlAll.Count) - ($i * 1000)
            $tmp = $bhlAll[$srtNum..$endNum]
        }
        
        Write-Host "$srtNum .. $endNum"

        # generate a policy name
        $policyName = "$winHoleBasePolicyName`_$("{0:0000}" -f $i)"

        $policyName

        [Bool]$PolicyExists = Get-DnsPolicyState $policyName

        Set-DnsBlackholePolicy -PolicyExists $PolicyExists -BlackListPolicyName $policyName -FqdnPolicyString "EQ,$($tmp -join ',')"
    }
}