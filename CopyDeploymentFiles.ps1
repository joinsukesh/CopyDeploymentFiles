<# ------ COPY DEPLOYMENT FILES ------ 
This Powershell script is to copy all the deployment files (e.g.: assets, views, Dlls, etc.),
from a Visual Studio solution with *.csproj projects, to an output directory.
1. Go through the variables under the #VARIABLES section in this script and modify the values as needed.
2. I would recommend to have the $outputDirectory as some temporary folder instead of your actual webroot folder. Because the script includes delete operations.
3. Place this script in the same folder Visual Studio's .sln file exists.
4. Build the VS Solution.
5. Open Powershell, change the directory to the folder where the script exists.
6. Run the command CopyDeploymentFiles.ps1
7. Verify files and folders in the specified output directory.
#>

Clear-Host

# VARIABLES

# Output directory where files should be copied to
$outputDirectory = "D:\out\Test"

# Project folders to be excluded while copying. 
# For e.g., there could be configuration projects created in Visual Studio, whose files need not be deployed to the actual (website) folder.
$excludeProjectFolders = @("mycompany.publish.website")

# DLL file patterns to include while copying
$includeDllFilePatterns = @("mycompany.*")

# DLL file patterns to exclude while copying
$excludeDlls = @("mycompany.publish.website.dll")

# Project folders to exclude while copying
$excludeFoldersInProject = @("bin", "controllers", "models", "obj")

# Files inside a project root folder to be excluded while copying
$excludeProjectRootFiles = @("app.config", "packages.config", "web.config", "web.debug.config", "web.release.config", "favicon.ico", "global.asax")

# Files with extensions inside a project folder to be excluded while copying. 
$excludeFilesWithExtensions = @(".cs", ".csproj", ".user", ".sql")

# This may not be needed. However, if after executing the script, if any desired file(s) are not copied, 
# then add the absolute paths of those files in the array separated by commas - e.g. "D:\Projects\MyCompany\src\MyCompany.Website\web.config"
$filePathsToBeCopied = @("D:\Projects\Internal\MyCompany\src\Feature\code\MyCompany.Feature.Accounts\abc\xyz\123.html")

# Relative paths of files to be deleted from output folder after copying is done.
# Ensure all paths have a leading "\"
$deleteFilesFromOutputDirectory = @("\views\web.config")

# Should existing files in output directory be deleted before copying source files
$deleteExistingFilesInOutputDirectory = $true

# This will copy DLLs from the specified folder. Expected Value: debug or release
$buildMode = "debug"

# FUNCTIONS

# Remove any empty folders in the specified directory
function Remove-EmptyFolders {
    param (
        [string]$path
    )

    # Get all the child items (folders and files) in the current directory
    $items = Get-ChildItem -Path $path

    # Check if the folder is empty
    if ($items.Count -eq 0) {
        # If empty, remove the folder
        Remove-Item -Path $path -Force
    }
    else {
        # If not empty, iterate through child items
        foreach ($item in $items) {
            # Recursively call the function for each child folder
            if ($item.PSIsContainer) {
                Remove-EmptyFolders -path $item.FullName
            }
        }

        # Check again if the folder is empty after deleting child folders
        $remainingItems = Get-ChildItem -Path $path
        if ($remainingItems.Count -eq 0) {
            # If empty, remove the folder
            Remove-Item -Path $path -Force
        }
    }
}

# Remove unnecessary files and folders from the output directory
function DeleteUnnecessaryFilesAndFoldersInOutputDirectory {
    Write-Host "Deleting unnecessary files and folders from $outputDirectory ..." -ForegroundColor Yellow
    $files = Get-ChildItem -Path $outputDirectory -File -Recurse
    foreach ($item in $files) {
        if ($excludeFilesWithExtensions -contains $item.Extension) {
            Remove-Item -Path $item.FullName -Recurse
        }
        else {
            foreach ($relFilePath in $deleteFilesFromOutputDirectory) {
                if (($outputDirectory + $relFilePath) -like $item.FullName) {
                    Remove-Item -Path $item.FullName -Recurse
                }
            }
        }        
    }

    Remove-EmptyFolders $outputDirectory
}

# Copy DLLs from the project folders to the output directory
function CopyDlls {
    param (
        [string]$sourceFolderPath
    )
    $dllsFolderPath = $($sourceFolderPath + "\obj\" + $buildMode)
    $files = Get-ChildItem -Path $dllsFolderPath -File -Recurse -Filter "*.dll"
    if ($files.Count -gt 0) {
        $outputDirectoryBinFolderPath = $($outputDirectory + "\bin")
        CreateDirectory $outputDirectoryBinFolderPath
        foreach ($file in $files) {
            $fileName = $file.Name
            if ($excludeDlls -notcontains $fileName) {
                foreach ($pattern in $includeDllFilePatterns) {                
                    if (($fileName -like "$pattern")) {                    
                        Copy-Item -Path $file.FullName -Destination $outputDirectoryBinFolderPath 
                    }
                } 
            }                                         
        }            
    }    
}

# Copy all folders from the project folder into the output directory
function CopyFolders {
    param (
        [string]$sourceFolderPath
    )
    $folders = Get-ChildItem -Path $sourceFolderPath | Where-Object {    
        if ($_ -is [System.IO.DirectoryInfo] -And $excludeFoldersInProject -notcontains $_.Name) {
            return $true
        }        
    }

    if ($folders.Count -gt 0) { 
        foreach ($folder in $folders) { 
            Copy-Item -Path $folder.FullName -Destination $outputDirectory -Recurse -Force
        }
    }    
}

# Create a folder in the specified folder if unavailable
function CreateDirectory {    
    param (
        [string]$folderPath
    )
    If (!(test-path -PathType container $folderPath)) {        
        $null = New-Item -Path $folderPath -ItemType Directory
    }    
}

# Copy files specified in $filePathsToBeCopied into the output directory
function CopySpecifiedFiles {    
    param (
        [string[]]$projectFolderPaths
    ) 
    foreach ($path in $filePathsToBeCopied) {
        foreach ($projectFolderPath in $projectFolderPaths) {
            if ($path.StartsWith($projectFolderPath, 'CurrentCultureIgnoreCase')) {
                
                $fileOutputFolderPath = $path.Replace($projectFolderPath, $outputDirectory)

                # Split the path into directory and file name
                $directory = [System.IO.Path]::GetDirectoryName($fileOutputFolderPath)

                # Create the directory if it doesn't exist
                if (-not (Test-Path -Path $directory)) {
                    $null = New-Item -Path $directory -ItemType Directory -Force
                }                 

                Copy-Item -Path $path -Destination $fileOutputFolderPath
            }            
        }        
    }
}

# Copy root files from the project into the output directory
function CopyFiles {
    param (
        [string]$sourceFolderPath
    )
    # Get files and filter out specified extensions
    $files = Get-ChildItem -Path $sourceFolderPath -File | Where-Object {            
        if ($excludeFilesWithExtensions -contains $_.Extension -or 
            $excludeProjectRootFiles -contains $_.Name) {
            return $false
        }
        else {
            return $true
        }
    }
    
    if ($files.Count -gt 0) {
        CreateDirectory $outputDirectory 
        foreach ($file in $files) {            
            Copy-Item -Path $file.FullName -Destination $outputDirectory  
        }            
    }    
}

# Remove existing files & folders from the output directory
function CleanUpDirectory {
    param (
        [string]$folderPath
    )
    if ((test-path -PathType container $folderPath)) {
        Remove-Item -Path "$folderPath\*" -Recurse
    }
}

# Main method to start the copying procress from source folders to output folders
function CopyProjectFilesToOutputDirectory { 
    param (
        [string[]]$projectFolderPaths
    ) 

    if ($deleteExistingFilesInOutputDirectory -eq $true) {
        CleanUpDirectory $outputDirectory
    }  
    foreach ($folder in $projectFolderPaths) { 
        Write-Host "Copying files from $folder ..." -ForegroundColor Yellow        
        CopyFiles $folder
        CopyFolders $folder
        CopyDlls $folder                         
    }
    
    if ($filePathsToBeCopied.Count -gt 0) {
        CopySpecifiedFiles $projectFolderPaths
    }
}

# Get the list of all *.csproj folders
function GetAllProjectFolders {
    param (
        [string]$folderPath
    )
    Write-Host "Collecting project folder names..." -ForegroundColor Yellow
    # Get *.csproj files in the current folder
    $files = Get-ChildItem -Path $folderPath -File -Recurse -Filter *.csproj
    
    # If any .csproj files are found, add the parent folder to the array
    if ($files.Count -gt 0) {
        [string[]]$csProjFolders = @()
        foreach ($file in $files) {
            $parentFolderName = Split-Path -Path $file.FullName -Parent | Split-Path -Leaf
            
            if ($excludeProjectFolders -notcontains $parentFolderName) {
                $folderName = Split-Path -Path $file.FullName -Parent
                $csProjFolders += $folderName 
            }           
        }
        
        return $csProjFolders
    }       
}

# The main method of this script which initiates the process
function Main {
    [string[]]$csProjectFolders = GetAllProjectFolders $PSScriptRoot
    
    if ($csProjectFolders.Count -gt 0) {
        CopyProjectFilesToOutputDirectory $csProjectFolders
        DeleteUnnecessaryFilesAndFoldersInOutputDirectory 
        Write-Host "COMPLETE" -ForegroundColor Green
    }
    else {
        Write-Host "No project folders found" -ForegroundColor Red
    } 
}

Main

