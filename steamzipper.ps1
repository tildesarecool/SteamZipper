# P:\steamzipper

# Script parameters (this should be the very first thing in the script)
param (
    [string]$sourceFolder,      # Source folder with subfolders to zip
    [string]$destinationFolder  # Destination folder for the zip files
)

# Check if source and destination folders are provided
if (-not $sourceFolder -or -not $destinationFolder) {
    Write-Host "Error: Source folder and destination folder must be specified."
    exit 1
}

# Function to get platform short name from folder path
function Get-PlatformShortName {
    param (
        [string]$path
    )

    $platforms = @{
        "epic games"   = "epic"
        "Amazon Games" = "amazon"
        "GOG"          = "gog"
        "Steam"        = "steam"
    }

    foreach ($platform in $platforms.Keys) {
        if ($path -like "*$platform*") {
            return $platforms[$platform]
        }
    }
    return "unknown"  # Default value if no match
}

# Function to create a zip file if it doesn't already exist or needs updating
function Proc-ZipCreate {
    param (
        [string]$sourceFolderPath,
        [string]$destinationFolderPath,
        [string]$folderName,
        [string]$platformShortName,
        [string]$dateStamp
    )

    $zipFileName = "${folderName}_${dateStamp}_${platformShortName}.zip"
    $zipFilePath = Join-Path -Path $destinationFolderPath -ChildPath $zipFileName

    # Check if the zip file already exists
    if (Test-Path -Path $zipFilePath) {
        # Extract the date from the existing zip file name and compare with folder's last modified date
        $existingDate = ($zipFileName -split "_")[1]
        $folderModifiedDate = (Get-Item $sourceFolderPath).LastWriteTime.ToString("MMddyyyy")

        if ($existingDate -eq $folderModifiedDate) {
            Write-Host "Skipping $folderName (no changes since $existingDate)"
            return
        } else {
            Write-Host "Updating $folderName (folder modified after $existingDate)"
        }
    }

    # Create a zip file
    Compress-Archive -Path "$sourceFolderPath\*" -DestinationPath $zipFilePath -Force
    Write-Host "Created/Updated: $zipFileName"
}

# Function to monitor jobs and display progress
function Monitor-Jobs {
    param (
        [array]$jobs,
        [int]$totalJobs
    )

    while ($jobs.Count -gt 0) {
        $runningJobs = ($jobs | Where-Object { $_.State -eq 'Running' }).Count
        $completedJobs = $totalJobs - $runningJobs

        Write-Host "Total jobs: $totalJobs | Jobs completed: $completedJobs | Jobs left to do: $runningJobs"
        Write-Host "Currently running jobs: $($jobs | Where-Object { $_.State -eq 'Running' }).Name"

        Start-Sleep -Seconds 5

        $jobs = $jobs | Where-Object { $_.State -eq 'Running' }  # Filter running jobs
    }

    Write-Host "All jobs completed."
}

# Main function to process folders
function Process-Folders {
    param (
        [string]$sourceFolder,
        [string]$destinationFolder
    )

    # Clean up any previous jobs
    Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue

    # Create destination folder if it doesn't exist
    if (-not (Test-Path -Path $destinationFolder)) {
        New-Item -Path $destinationFolder -ItemType Directory
    }

    # Get list of subfolders to zip
    $folders = Get-ChildItem -Path $sourceFolder -Directory
    $totalFolders = $folders.Count
    $jobs = @()

    Write-Host "Starting zipping process for $totalFolders folders..."

    foreach ($folder in $folders) {
        $folderName = $folder.Name -replace ' ', '_' -replace '\.', '_'
        $folderModifiedDate = (Get-Item $folder.FullName).LastWriteTime.ToString("MMddyyyy")
        $platformShortName = Get-PlatformShortName -path $folder.FullName

        # Start a job to process the zip creation
        $jobName = "Zipping_$folderName"
        $jobs += Start-Job -Name $jobName -ScriptBlock {
            param ($src, $dest, $fname, $platform, $dStamp)
            Proc-ZipCreate -sourceFolderPath $src -destinationFolderPath $dest -folderName $fname -platformShortName $platform -dateStamp $dStamp
        } -ArgumentList $folder.FullName, $destinationFolder, $folderName, $platformShortName, $folderModifiedDate
    }

    # Monitor remaining jobs
    Monitor-Jobs -jobs $jobs -totalJobs $totalFolders
}

# Start the folder processing
Proc-ZipCreate -sourceFolder $sourceFolder -destinationFolder $destinationFolder
