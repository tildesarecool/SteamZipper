# Define a mapping of known game platforms and their short names
$platforms = @{
    "Epic Games" = "epic"
    "Amazon Games" = "amazon"
    "GOG" = "gog"
    "Steam" = "steam"
}

# Function to find a platform keyword in the source path and return the short name
function Get-PlatformShortName {
    param (
        [string]$path
    )

    foreach ($key in $platforms.Keys) {
        if ($path -like "*$key*") {
            return $platforms[$key]
        }
    }
    # Return a default value if no platform keyword is found
    return "unknown"
}

# Function to extract the date stamp from the zip file name (in MMDDYYYY format)
function Get-DateFromZipName {
    param (
        [string]$zipFileName
    )

    $pattern = "\d{8}" # Matches an 8-digit date
    if ($zipFileName -match $pattern) {
        return $matches[0]
    }
    return $null
}

# Function to create a zip file if needed based on folder's last modified date
function Process-ZipCreation {
    param (
        [string]$sourceFolderPath,
        [string]$destinationFolderPath,
        [string]$folderName,
        [string]$platformShortName,
        [string]$dateStamp,
        [int]$maxJobs
    )

    $zipFileName = "$folderName" + "_$dateStamp" + "_$platformShortName.zip"
    $zipFilePath = Join-Path $destinationFolderPath $zipFileName

    # Check if an up-to-date zip already exists
    $existingZip = Get-ChildItem -Path $destinationFolderPath -Filter "$folderName*_*.zip" | Where-Object {
        $_.Name -like "$folderName*_$platformShortName.zip"
    }

    $skipZip = $false
    if ($existingZip) {
        $existingZipDate = Get-DateFromZipName -zipFileName $existingZip.Name
        if ($existingZipDate -eq $dateStamp) {
            Write-Output "Skipping $folderName - zip file already up-to-date."
            $skipZip = $true
        }
    }

    # Create a zip if it doesn't already exist or is outdated
    if (-not $skipZip) {
        # Start a job to zip the folder
        Start-Job -ScriptBlock {
            param ($folderPath, $zipFilePath)
            Compress-Archive -Path $folderPath -DestinationPath $zipFilePath
            Write-Output "Created zip: $zipFilePath"
        } -ArgumentList $sourceFolderPath, $zipFilePath
    }
}

# Main function that processes each folder
function Process-Folders {
    param (
        [string]$sourceFolder,
        [string]$destinationFolder,
        [int]$maxJobs
    )

    # Clean up any previous jobs
    Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue

    # Create destination folder if it doesn't exist
    if (-not (Test-Path -Path $destinationFolder)) {
        New-Item -Path $destinationFolder -ItemType Directory
    }

    # Get platform short name from the source path
    $platformShortName = Get-PlatformShortName -path $sourceFolder

    # Initialize job tracking and progress bar
    $jobs = @()
    $folders = Get-ChildItem -Path $sourceFolder -Directory
    $totalFolders = $folders.Count
    $currentFolderIndex = 0

    # Process each subfolder
    foreach ($folder in $folders) {
        $folderName = $folder.Name -replace ' ', '_'
        $folderModifiedDate = $folder.LastWriteTime
        $dateStamp = $folderModifiedDate.ToString("MMddyyyy") # Format the date as MMDDYYYY

        # Call function to create zip if necessary
        Process-ZipCreation -sourceFolderPath $folder.FullName -destinationFolderPath $destinationFolder -folderName $folderName -platformShortName $platformShortName -dateStamp $dateStamp -maxJobs $maxJobs

        # Limit the number of concurrent jobs
        while ($jobs.Count -ge $maxJobs) {
            $completedJob = Wait-Job -Any
            Receive-Job -Job $completedJob
            Remove-Job -Job $completedJob
            $jobs = $jobs | Where-Object { $_.State -eq 'Running' }
        }

        # Progress Bar Update
        $currentFolderIndex++
        $percentComplete = ($currentFolderIndex / $totalFolders) * 100
        Write-Progress -Activity "Zipping Folders" -Status "$currentFolderIndex out of $totalFolders completed" -PercentComplete $percentComplete
    }

    # Wait for remaining jobs to complete
    Write-Output "Waiting for all remaining jobs to complete..."
    while ($jobs.Count -gt 0) {
        $completedJob = Wait-Job -Any
        Receive-Job -Job $completedJob
        Remove-Job -Job $completedJob
        $jobs = $jobs | Where-Object { $_.State -eq 'Running' }
    }

    # Final progress bar update
    Write-Progress -Activity "Zipping Folders" -Status "All jobs completed" -Completed
}

# Start of the script - entry point

# Check if the required arguments are provided
if ($args.Count -lt 2) {
    Write-Error "Usage: .\steamzipper.ps1 <source_folder> <destination_folder> [max_jobs]"
    exit
}

# Get command line arguments
$sourceFolder = $args[0]
$destinationFolder = $args[1]
$maxJobs = if ($args.Count -ge 3) { [int]$args[2] } else { [System.Environment]::ProcessorCount }

# Start processing the folders
Process-Folders -sourceFolder $sourceFolder -destinationFolder $destinationFolder -maxJobs $maxJobs
