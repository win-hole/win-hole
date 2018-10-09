# common functions used by win-hole scripts


# FUNCTION: Get-TimeStamp
# PURPOSE: Returns a timestamp string

function Get-TimeStamp 
{
    return "$(Get-Date -format "yyyyMMdd_HHmmss_ffff")"
} # end Get-TimeStamp


# FUNCTION: Write-Log
# PURPOSE: Writes script information to a log file and to the screen when -Verbose is set.

function Write-Log {
    param ([string]$text, [switch]$tee = $false, [string]$foreColor = $null)

    $foreColors = "Black","Blue","Cyan","DarkBlue","DarkCyan","DarkGray","DarkGreen","DarkMagenta","DarkRed","DarkYellow","Gray","Green","Magenta","Red","White","Yellow"

    # check the log file, create if missing
    $isPath = Test-Path "$script:dataPath\$script:logName"
    if (!$isPath) {
        "$(Get-TimeStamp): Log started" | Out-File "$script:dataPath\$script:logName" -Force
        "$(Get-TimeStamp): Local log file path: $("$script:dataPath\$script:logName")" | Out-File "$script:dataPath\$script:logName" -Force
        Write-Verbose "Local log file path: $("$script:dataPath\$script:logName")"
    }
    
    # write to log
    "$(Get-TimeStamp): $text" | Out-File "$script:dataPath\$script:logName" -Append

    # write text verbosely
    Write-Verbose $text

    if ($tee)
    {
        # make sure the foreground color is valid
        if ($foreColors -contains $foreColor -and $foreColor)
        {
            Write-Host -ForegroundColor $foreColor $text
        } else {
            Write-Host $text
        }        
    }
} # end Write-Log


## Function: Download-WebFile
## Purpose: Downloads a file from the web when given a URL and an output location (path\file.ext)

function Get-WebFile {

    param ($dlUrl, $output)

    Write-Log "Attempting to download: $dlUrl"
    
    try {
        Invoke-WebRequest -Uri $dlUrl -OutFile $output
    } catch {
        Write-Log "ERROR: $($Error[0])"
        return $false
    }

    Write-Log "Downloaded successfully to: $output"
    return $true

} # end Download-WebFile