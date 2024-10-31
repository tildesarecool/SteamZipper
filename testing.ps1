$srcdir = "P:\steamzipper\steam temp storage"
$destdir = "P:\steamzipper\backup-steam"

#$DestZipExist = Join-Path -Path $destinationFolder -ChildPath $finalName
#$logNames = 'Security', 'Application', 'System', 'Windows PowerShell',
#    'Microsoft-Windows-Store/Operational'


#$filelist = "Dig_Dog_10152024_steam.zip", "Dig_Dog_10162024_steam.zip", Horizon_Chase_10172024_steam.zip, Markov_Alg_10152024_steam.zip, Ms._PAC-MAN_10152024_steam.zip, Outzone_10152024_steam.zip, PAC-MAN_10152024_steam.zip

$filelist = @($destdir + "\" + "Dig_Dog_10162024_steam.zip", $destdir + "\" + "Horizon_Chase_10172024_steam.zip", $destdir + "\" + "Markov_Alg_10152024_steam.zip")


$filelist | ForEach-Object -Process {
    if (!$_.PSIsContainer) {
        $_.Name; $_.Length / 1024; " " 
        Write-Host "name is $_.Name "

    }
}

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
