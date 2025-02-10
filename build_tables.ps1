Set-Variable -Name "PreferredDateFormat" -Value "MMddyyyy"
$sourceFolder = "C:\Users\keith\Documents\steam temp storage"
$destinationFolder = "C:\Users\keith\Documents\steambackup"

function Get-PlatformShortName {
    #    param (
    #        [string]$path
    #    )
    
        $path = $sourceFolder
        # additional platforms (xbox (Windows store?), origin, uplay, etc) can be added to the table below
        # easiest way would be to copy/paste an existing line
        # and modify it left/right (sample origin below. remove # to enable)
        $platforms = @{
            "epic games"   = "epic"
            "Amazon Games" = "amazon"
            "GOG"          = "gog"
            "Steam"        = "steam"
            #"Origin"        = "origin"
        }
        Set-Variable -Name $platforms -Option ReadOnly
        # fortunately, the -like parameter is NOT case sensitive by default
        foreach ($platform in $platforms.Keys) {
            if ($path -like "*$platform*") {
                return $platforms[$platform]
            }
        }
        return "unknown"  # Default value if no match
    }

    function Get-FileDateStamp {
        # $FileName is either a path to a folder or the zip file name. 
        # must pass in whole path for the folder but just a file name is fine for zip
        # so the folder i do the lastwritetime.tostring to get the date
        # and zip file name parse to date code with the [-2]
    param (
        [Parameter(Mandatory=$true)]
        $FileName
    )
    if (   ($FileName -is [string]) -and ($FileName.Length -eq $PreferredDateFormat.Length)   ) {
        try {
            $datecode = $FileName
            return [datetime]::ParseExact($datecode,$PreferredDateFormat,$null)
        } catch {
            Write-Output "Warning: Invalid DateCode format. Expected format is $PreferredDateFormat."
            return $null
        }
    }
    $justdate = ""
    if (Test-Path -Path $FileName -PathType Container) {
        Write-Host "Inside get-filedatestamp, the filename parameter is $FileName"
        $FolderModDate = (Get-Item -Path $FileName).LastWriteTime.ToString($PreferredDateFormat)
        $FolderModDate = [datetime]::ParseExact($FolderModDate,$PreferredDateFormat,$null)
        if ($FolderModDate -is [datetime]) {
            return $FolderModDate
        }
    
        } elseif  (Test-Path -Path $FileName -PathType Leaf) {
            try {
                    $justdate = $FileName -split "_"
                    if ($justdate.Length -ge 2) {
                        $justdate = $justdate[-2]
                        if ($justdate.Length -eq 8) {
                            return [datetime]::ParseExact($justdate,$PreferredDateFormat,$null)
                        }
                    }
            }
            catch {
                Write-Host "Unable to determine or convert to date object from value $justdate"
                return $null
             }
        }  elseif  ( (!(Test-Path -Path $FileName -PathType Leaf)) -and (!( Test-Path -Path $FileName -PathType Container) ) )    {
            Write-Host "the filename parameters, $FileName, is not a folder or a file"
            return $null
            }
    }


#    $sourceFolder = "C:\Users\keith\Documents\steam temp storage"

    Write-Host "Debug: Processing source folders..." -ForegroundColor Cyan
$sourceFoldersInTable = @{}
$destinationZipsInTable = @{}

# Process source folders
    Get-ChildItem -Path $sourceFolder -Directory | ForEach-Object {
        $sourceFoldersInTable[$_.FullName] = Get-FileDateStamp $_.FullName
    }

# Debugging: Print table contents to verify storage
Write-Host "`nFinal Source Folders Table:"
$sourceFoldersInTable.GetEnumerator() | ForEach-Object { Write-Host "  $($_.Key) -> $($_.Value)" -ForegroundColor Red }


# Process source folders
Get-ChildItem -Path $destinationFolder -File | ForEach-Object {
    $destinationZipsInTable[$_.FullName] = Get-FileDateStamp $_.FullName
}

Write-Host "`nFinal destination Folders Table:"
$destinationZipsInTable.GetEnumerator() | ForEach-Object { Write-Host "  $($_.Key) -> $($_.Value)" -ForegroundColor Blue }


#Write-Host "`nDebug: Processing destination zips..." -ForegroundColor Green
#$destinationZipsInTable = @{}
#Get-ChildItem -Path $destinationFolder -Filter "*.$CompressionExtension" | ForEach-Object {
#    $zipNameParts = $_.BaseName -split "_"
#    $dateCode = $zipNameParts[-2]
#    
#    if ($dateCode -match "^\d{8}$") {
#        $destinationZipsInTable[$_.FullName] = Get-FileDateStamp $dateCode
#        Write-Host "  Added: $($_.FullName) -> $($destinationZipsInTable[$_.FullName])"
#    } else {
#        Write-Host "  Skipped (invalid date format): $($_.FullName)" -ForegroundColor Yellow
#    }
#}
#