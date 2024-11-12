#$srcdir = "P:\steamzipper\steam temp storage" # alienware
#$destinationFolder = "P:\steamzipper\backup-steam" # alienware

$srcdir = "C:\Users\keith\Documents\steam temp storage" # thinkpad
$destinationFolder = "C:\Users\keith\Documents\steambackup" # thinkpad

#### thinkpad
$sampleFile = "PAC-MAN_256"
$sampleSrcFolderPath = "PAC-MAN 256"
#### thinkpad

$CompressionExtension = "zip"

$SampleSrcGamePath = Join-Path -Path $srcdir -ChildPath $sampleSrcFolderPath

#if (Test-Path -Path $SampleSrcGamePath) {
#    Write-Host "value of SampleSrcGamePath is $SampleSrcGamePath (which does exist)"# $($filename.Length)"
#}

$PreferredDateFormat = "MMddyyyy"


function determineExistZipFile {
    param (
        [Parameter(Mandatory=$true)]
        $szZipFileName
    )
    $ZipNameBreakout = $szZipFileName -split '_'

    if ( $ZipNameBreakout.Length -gt 3 ) {
        $target = $ZipNameBreakout.Length - 3

        $zipNoExtra = $($ZipNameBreakout[0..$($target)])

        $justzipname = $zipNoExtra -replace ' ', '_'# -or $zipNoExtra -join '_')
        $justzipname =  $zipNoExtra -join '_'
    } else {        
        $justzipname = $zipNoExtra -replace ' ', '_'# -or $zipNoExtra -join '_')
        $justzipname =  $zipNoExtra -join '_'
    }

#    Write-Host "after attempted string trickery justzipname value is $justzipname"
        $SeeIfExist =  (Get-ChildItem -Path $destinationFolder -Filter "$justzipname*"  | Measure-Object).Count
                   #(Get-ChildItem -Path  "P:\steamzipper\backup-steam" -Filter "$jstzipname*" | Measure-Object ).Count

#    $fileExists = [bool]$SeeIfExist
    

    if ($SeeIfExist -ne 0) {
#        Write-Host "fileexists turns out true - $fileExists"
        return $true
    } else {
#        Write-Host "fileexists turns out false - $fileExists"
        return $false
    }
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
# this is something of an "undocumented feature". Sending in random date codes in 8-digit format returns a date object.
# I don't know why, just seemed to match the vibe of the function so why not?
if (   ($FileName -is [string]) -and ($FileName.Length -eq $PreferredDateFormat.Length)   ) {
    try {
        $datecode = $FileName
        return [datetime]::ParseExact($datecode,$PreferredDateFormat,$null)
    } catch {
        Write-Output "Warning: Invalid DateCode format. Expected format is $PreferredDateFormat."
        return $null
    }
}

#$item = $FileName
$justdate = ""

if (Test-Path -Path $FileName -PathType Container) {
    # this may be a little redundant but I'm just going to go with it
    $FolderModDate = (Get-Item -Path $FileName).LastWriteTime.ToString($PreferredDateFormat)
    $FolderModDate = [datetime]::ParseExact($FolderModDate,$PreferredDateFormat,$null)
    if ($FolderModDate -is [datetime]) {
        return $FolderModDate
    }
} elseif  (Test-Path -Path $FileName -PathType Leaf) {
    try {
        $ext = $FileName -split '\.' 
        $ext = $ext[-1]
        if ($ext -eq $CompressionExtension) { # this may not be necessary. different extensions could be added though. So I'll keeep it.
            $justdate = $FileName -split "_"
            if ($justdate.Length -ge 2) {
                $justdate = $justdate[-2]
                if ($justdate.Length -eq 8) {
                    return [datetime]::ParseExact($justdate,$PreferredDateFormat,$null)
                }
            }
        }
    }
    catch {
        Write-Host "Unable to determine or convert to date object from value $justdate"
        return $null
     }
}   
}

function DetermineZipStatusDelete {
    param (
        [Parameter(Mandatory=$true)]
        $szSrcFullGameDirPath,
        [Parameter(Mandatory=$true)]
        $szDestZipFileName
    )
    Write-Host "sending in value of SampleSrcGamePath, which is $szSrcFullGameDirPath"
    $fileDatestamp = Get-FileDateStamp $szSrcFullGameDirPath
    Write-Host "value received back is $fileDatestamp"

#    Write-Host "############################# sample data #############################"
#    Write-Host "sending in value of SampleSrcGamePath, which is $SampleSrcGamePath"
#    $fileDatestamp = Get-FileDateStamp $SampleSrcGamePath
#    Write-Host "value received back is $fileDatestamp"
#    Write-Host "############################# sample data #############################"

    $getchildReturnResultCount = (Get-ChildItem -Path $destinationFolder -Filter "$szDestZipFileName*" | Measure-Object).Count
    Write-Host "Number of results returned was $getchildReturnResultCount (search was '$szDestZipFileName')" 
    if ($getchildReturnResultCount -gt 0) {
        $getchildReturn = Get-ChildItem -Path $destinationFolder -Filter "$szDestZipFileName*"
        Write-Host "that returned value is apparently $getchildReturn"
        $justFilename = Split-Path $getchildReturn -Leaf
        Write-Host "the zip file from that should probably be $justFilename"
        $splitFileName = $justFilename -split '_'
        $justdate = $splitFileName[-2]
        Write-Host "out of that, the date part is likely $justdate"
        $zipfiledateAsDate = Get-FileDateStamp $justdate
        Write-Host "############################# zip file date #############################"
        Write-Host "converted to a date object, that would be $zipfiledateasdate"
        Write-Host "############################# zip file date #############################"

        Write-Host "so, the folder date is $fileDatestamp and the zip file date is $zipfiledateAsDate"
    }

    if ($zipfiledateAsDate -le  $fileDatestamp) {
        Write-Host "zip file date is equal to or older than folder"
    } else {
        Write-Host "folder is older than zip file - new zip file creation necessary"
    }
}

DetermineZipStatusDelete "C:\Users\keith\Documents\steam temp storage" "Andro_Dunos_II_10232024_steam.zip"

#$determineExists = determineExistZipFile -szZipFileName $sampleFile

#    if ($determineExists) { # -and (Test-Path -Path $SampleSrcGamePath) ) {
#    #$splitFileName = $sampleFile -split '_'
#
#    Write-Host "sampleFile value is $sampleFile"
#    $getchildReturnResultCount = (Get-ChildItem -Path $destinationFolder -Filter "$sampleFile*" | Measure-Object).Count
#    if ($getchildReturnResultCount -lt 2) {
#        $getchildReturn = Get-ChildItem -Path $destinationFolder -Filter "$sampleFile*"
#        Write-Host "getchilditem return value via variable is $getchildReturn"
#        if ( Test-Path -Path $getchildReturn ) {
#            $justFilename = Split-Path $getchildReturn -Leaf
#            Write-Host "using split-path, the zip file value is $justFilename"
#            Write-Host "sending justFilename, which is $justFilename to Get-FileDateStamp..."
#            $GetBackDatestamp = Get-FileDateStamp $justFilename
#            Write-Host "result back is $GetBackDatestamp" # date object from zip file name as date object
#            # now i need the folder last written date as a date object
#            Write-Host "sending in SampleSrcGamePath, $SampleSrcGamePath"
#
#            if (Test-Path -Path $SampleSrcGamePath -PathType Container) {
#                $folderDateStamp = Get-FileDateStamp $sampleSrcFolderPath
#                Write-Host "result back for folderDateStamp is $folderDateStamp" # date object from folder path as date object
#            }
#        }
#    }
#    
#
#
#
###########################################################################    ###########################################################################
#    $extractDate = $splitFileName[-2]
#    Write-Host "extractdate value is $extractDate"

#    $extractDateAsDate = Get-FileDateStamp $extractDate
#
#    Write-Host "date from zip file name value is $extractDateAsDate"
#
#    $getFolderWriteDate = Get-FileDateStamp $SampleSrcGamePath
#
#    Write-Host "The last write date of $SampleSrcGamePath, is $getFolderWriteDate"
#
#    $sampleFoldate = Get-FileDateStamp "10122024"
#    #Write-Host "_________ sampleFoldate is $sampleFoldate"
#
#    #if ($extractDateAsDate -le $getFolderWriteDate) {
#    if ($extractDateAsDate -le $sampleFoldate) {
#       # zip date   "older"   folder date
#
#       Write-Host "date from zip filename OLDER ($extractDateAsDate) than folder write date ($sampleFoldate)"
#       Write-Host "which means a new zip file is needed and the old one deleted"
#       Write-Host "Zip file pending deletion: $sampleFile" 
#       Write-Host "$sampleFile deleted successfully - return true"
#    } else {
#        Write-Host "date from zip filename newer ($extractDateAsDate) than folder write date ($getFolderWriteDate)"
#        Write-Host "return true. or do nothing. or this 'else' doesn't need to exist. whatever."
#    }

#}




#$DestZipExist = Join-Path -Path $destinationFolder -ChildPath $finalName
#$logNames = 'Security', 'Application', 'System', 'Windows PowerShell',
#    'Microsoft-Windows-Store/Operational'





#$filelist = "Dig_Dog_10152024_steam.zip", "Dig_Dog_10162024_steam.zip", "Horizon_Chase_10172024_steam.zip", "Markov_Alg_10152024_steam.zip", "Ms._PAC-MAN_10152024_steam.zip", "Outzone_10152024_steam.zip", "PAC-MAN_10152024_steam.zip"

#$filelist = @($destdir + "\" + "Dig_Dog_10162024_steam.zip", $destdir + "\" + "Horizon_Chase_10172024_steam.zip", $destdir + "\" + "Markov_Alg_10152024_steam.zip")


#$filelist | ForEach-Object -Process {
#    if (!$_.PSIsContainer) {
#        $_.Name; $_.Length / 1024; " " 
#        Write-Host "name is $_.Name "
#
#    }
#}

#$filelist = "Dig_Dog_10152024_steam.zip", "Outzone_10152024_steam.zip"

#Write-Host "file list content is $filelist"

#$fileEntries = $filelist | ForEach-Object -Parallel {
#    Get-FileHash -Path $_ -Algorithm MD5 
##    Get-WinEvent -LogName $_ -MaxEvents 10000
#    
#} -ThrottleLimit 30
#
#Write-Host "value of fileEntries is $fileEntries"
#
#$fileEntries.Count
#


#function Get-FileDateStamp {
#    # $FileName is either a path to a folder or the zip file name. 
#    # must pass in whole path for the folder but just a file name is fine for zip
#    # so the folder i do the lastwritetime.tostring to get the date
#    # and zip file name parse to date code with the [-2]
#param (
#    [Parameter(Mandatory=$true)]
#    $FileName
#)
#Write-Host "inside Get-FileDateStamp, parameter value is $FileName"
## this is something of an "undocumented feature". Sending in random date codes in 8-digit format returns a date object.
## I don't know why, just seemed to match the vibe of the function so why not?
##Write-Host "value of filename length is $($filename.Length)"
##Write-Host "value of preferredDateFormat length is $($PreferredDateFormat.Length)"
#$LenPreferDateFormat = (  ($FileName.Length -eq $PreferredDateFormat.Length) -and ( ! (Test-Path -Path $FileName -PathType Container) )  )
#if (   ($LenPreferDateFormat) ) { #($FileName -is [string]) -and 
#    try {
#        $datecode = $FileName
##        Write-Host "datecode value is $datecode"
#        return [datetime]::ParseExact($datecode,$PreferredDateFormat,$null)
#    } catch {
#        Write-Output "Warning: Invalid DateCode format. Expected format is $PreferredDateFormat."
#        return $null
#    }
#}
#
#$item = $FileName
#$justdate = ""
##Write-Host "inside Get-FileDateStamp, parameter value is $FileName"
#    if (Test-Path -Path $item -PathType Container) {
#        # this may be a little redundant but I'm just going to go with it
#        $FolderModDate = (Get-Item -Path $item).LastWriteTime.ToString($PreferredDateFormat)
#        $FolderModDate = [datetime]::ParseExact($FolderModDate,$PreferredDateFormat,$null)
#        if ($FolderModDate -is [datetime]) {
#            return $FolderModDate
#        }
#    #} elseif  (Test-Path -Path $item -PathType Leaf) {
#    } elseif  (-not ( Test-Path -Path $item -PathType Container) ) {
#        try {
#            Write-Host "test-path determined $item is a leaf is true (-not (Test-Path -Path (parameter) -PathType Leaf))"
#                $ext = $item -split '\.' 
#                $ext = $ext[-1]
#                if ($ext -eq $CompressionExtension) { # this may not be necessary. different extensions could be added though. So I'll keeep it.
#                    $justdate = $item -split "_"
#                    if ($justdate.Length -ge 2) {
#                        $justdate = $justdate[-2]
#                        if ($justdate.Length -eq $PreferredDateFormat.Length) {
#                        
#                            return [datetime]::ParseExact($justdate,$PreferredDateFormat,$null)
#                        }
#                    }
#                }
#            }
#        catch {
#            Write-Host "Unable to determine or convert to date object from value $justdate"
#            return $null
#            }
#        }   
#}