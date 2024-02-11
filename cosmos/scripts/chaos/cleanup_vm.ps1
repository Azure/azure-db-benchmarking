<#
.SYNOPSIS
This script is used to clean up the environment by uninstalling the azure.identity python package, Python, and Chocolatey.

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
& python -m pip uninstall azure.identity -y

# Uninstall Python using Chocolatey
Write-Output "Uninstalling python3..."
choco uninstall python3 -y

# Uninstall Chocolatey
Write-Output "Uninstalling Chocolatey..."
Remove-Item -Path $env:ChocolateyInstall -Recurse -Force