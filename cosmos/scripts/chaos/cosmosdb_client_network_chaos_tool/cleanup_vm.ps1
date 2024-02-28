<#
.SYNOPSIS
This script is used to clean up the environment by uninstalling the azure.identity python package, Python3, and Chocolatey.

.DESCRIPTION
The script performs the following actions:
1. Uninstalls the azure.identity module for python.
2. Uninstalls Python using Chocolatey.
3. Uninstalls Chocolatey.

.PARAMETER None

.EXAMPLE
.\cleanup_vm.ps1
This command will execute the script and perform the cleanup actions.

.NOTES
    Author: Darshan Patnekar
    Date: 02/08/2024
    Version: 1.0
#>

# Remove azure.identity python package
Write-Output "Uninstalling azure.identity module for python...."
try {
    & python -m pip uninstall azure.identity -y
} 
catch {
    Write-Error "Failed to uninstall azure.identity module for python: $_"
}

# Uninstall Python using Chocolatey
Write-Output "Uninstalling python3..."
try {
    choco uninstall python3 -y
} 
catch {
    Write-Error "Failed to uninstall python3: $_"
}

# Uninstall Chocolatey
Write-Output "Uninstalling Chocolatey..."
try {
    Remove-Item -Path $env:ChocolateyInstall -Recurse -Force
} 
catch {
    Write-Error "Failed to uninstall Chocolatey: $_"
}
