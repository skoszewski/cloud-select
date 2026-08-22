#!/usr/bin/env pwsh
# install.ps1 - Installs the CloudSelect PowerShell module for the current user.

$ErrorActionPreference = 'Stop'

$moduleName = 'CloudSelect'
$userModulesRoot = ($env:PSModulePath -split [System.IO.Path]::PathSeparator)[0]
$targetDir = Join-Path $userModulesRoot $moduleName

New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot 'CloudSelect.psd1') -Destination $targetDir -Force
Copy-Item -Path (Join-Path $PSScriptRoot 'CloudSelect.psm1') -Destination $targetDir -Force

Write-Host "CloudSelect has been installed to $targetDir"
Write-Host 'To use it, add the following line to your PowerShell profile ($PROFILE):'
Write-Host "  Import-Module $moduleName"
