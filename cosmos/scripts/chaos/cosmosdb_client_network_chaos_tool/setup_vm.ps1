<#
.SYNOPSIS
This script installs all required dependencies of the Chaos script on the virtual machine.

.DESCRIPTION
The script installs Chocolatey, Python 3, pip, and the Azure.Identity module for Python.

.PARAMETER None

.INPUTS
None

.OUTPUTS
None

.EXAMPLE
.\setup_vm.ps1

.NOTES
    Author: Darshan Patnekar
    Date: 02/08/2024
    Version: 1.0
#>

try {
    # Chocolatey installation
    Write-Output "Installing Chocolatey...."
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    $env:ChocolateyInstall = Convert-Path "$( (Get-Command choco).Path)\\..\\.."
    Import-Module "$env:ChocolateyInstall\\helpers\\chocolateyProfile.psm1"
    choco install chocolatey-compatibility.extension -y --force
    Write-Output "Chocolatey installed successfully."
 
    # Refresh environment variables to reflect changes made by Chocolatey
    refreshenv

    # python 3 installation
    Write-Output "Installing python 3...."
    choco install python3 -y --force
    refreshenv

    # pip installation
    Write-Output "Installing pip...."
    python -m ensurepip --upgrade
    refreshenv

    # Install Azure.Identity module for Python
    Write-Output "Installing azure-identity module for Python...."
    pip install azure-identity
    refreshenv
}
catch {
    Write-Error "An error occurred during the installation process: $($_.Exception.Message)"
}