#!/usr/bin/env pwsh
# test.ps1 - Automated tests for CloudSelect.psm1

$ErrorActionPreference = 'Stop'

# Create isolated playground directory
$TestDir = Join-Path ([System.IO.Path]::GetTempPath()) ("cloud-select-test." + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $TestDir -Force | Out-Null

try {
    # Mock the home/AppData directories and unset any existing overrides to test defaults
    $env:USERPROFILE = $TestDir
    $env:HOME = $TestDir
    $env:APPDATA = Join-Path $TestDir 'AppData' 'Roaming'
    Remove-Item Env:\CLOUD_CLI_PROFILE_DIR -ErrorAction SilentlyContinue
    Remove-Item Env:\GCLOUD_PROFILE_ROOT -ErrorAction SilentlyContinue
    Remove-Item Env:\AZURECLI_PROFILE_ROOT -ErrorAction SilentlyContinue
    Remove-Item Env:\CLOUDSDK_CONFIG -ErrorAction SilentlyContinue
    Remove-Item Env:\AZURE_CONFIG_DIR -ErrorAction SilentlyContinue

    function Write-TestHeader([string]$Name) {
        Write-Host "`n=== $Name ===" -ForegroundColor Cyan
    }

    function Assert-Equal($Expected, $Actual, [string]$Message = 'Assertion failed') {
        if ($Expected -ne $Actual) {
            Write-Host "ERROR: $Message`nExpected: '$Expected'`nActual:   '$Actual'" -ForegroundColor Red
            exit 1
        }
    }

    function Assert-DirectoryExists([string]$Path) {
        if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
            Write-Host "ERROR: Directory does not exist: $Path" -ForegroundColor Red
            exit 1
        }
    }

    function Assert-Empty($Value) {
        if ($Value) {
            Write-Host "ERROR: Expected empty value, got '$Value'" -ForegroundColor Red
            exit 1
        }
    }

    Import-Module (Join-Path $PSScriptRoot 'CloudSelect.psd1') -Force

    # ---------------------------------------------------------
    # Test Case 1: Default GCP Profile Directory Creation & Selection
    # ---------------------------------------------------------
    Write-TestHeader 'Test 1: Default GCP profile selection'
    Select-GCloudProfile my-gcp-profile
    Assert-Equal (Join-Path $TestDir '.config' 'gcloud.d' 'my-gcp-profile') $env:CLOUDSDK_CONFIG 'CLOUDSDK_CONFIG path is incorrect'
    Assert-DirectoryExists (Join-Path $TestDir '.config' 'gcloud.d' 'my-gcp-profile')

    # ---------------------------------------------------------
    # Test Case 2: Default Azure Profile Directory Creation & Selection
    # ---------------------------------------------------------
    Write-TestHeader 'Test 2: Default Azure profile selection'
    Select-AzureCLIProfile my-azure-profile
    Assert-Equal (Join-Path $TestDir '.config' 'azure.d' 'my-azure-profile') $env:AZURE_CONFIG_DIR 'AZURE_CONFIG_DIR path is incorrect'
    Assert-DirectoryExists (Join-Path $TestDir '.config' 'azure.d' 'my-azure-profile')

    # ---------------------------------------------------------
    # Test Case 3: CLOUD_CLI_PROFILE_DIR Override behavior
    # ---------------------------------------------------------
    Write-TestHeader 'Test 3: CLOUD_CLI_PROFILE_DIR override'
    $env:CLOUD_CLI_PROFILE_DIR = Join-Path $TestDir 'custom-profiles'

    Select-GCloudProfile custom-gcp
    Assert-Equal (Join-Path $TestDir 'custom-profiles' 'gcloud.d' 'custom-gcp') $env:CLOUDSDK_CONFIG 'GCP path not overridden correctly'
    Assert-DirectoryExists (Join-Path $TestDir 'custom-profiles' 'gcloud.d' 'custom-gcp')

    Select-AzureCLIProfile custom-azure
    Assert-Equal (Join-Path $TestDir 'custom-profiles' 'azure.d' 'custom-azure') $env:AZURE_CONFIG_DIR 'Azure path not overridden correctly'
    Assert-DirectoryExists (Join-Path $TestDir 'custom-profiles' 'azure.d' 'custom-azure')

    # ---------------------------------------------------------
    # Test Case 4: Individual Profile Root Overrides
    # ---------------------------------------------------------
    Write-TestHeader 'Test 4: Individual profile root overrides'
    $env:GCLOUD_PROFILE_ROOT = Join-Path $TestDir 'gcp-root-direct'
    $env:AZURECLI_PROFILE_ROOT = Join-Path $TestDir 'azure-root-direct'

    Select-GCloudProfile direct-gcp
    Assert-Equal (Join-Path $TestDir 'gcp-root-direct' 'direct-gcp') $env:CLOUDSDK_CONFIG 'Individual GCLOUD_PROFILE_ROOT override failed'
    Assert-DirectoryExists (Join-Path $TestDir 'gcp-root-direct' 'direct-gcp')

    Select-AzureCLIProfile direct-azure
    Assert-Equal (Join-Path $TestDir 'azure-root-direct' 'direct-azure') $env:AZURE_CONFIG_DIR 'Individual AZURECLI_PROFILE_ROOT override failed'
    Assert-DirectoryExists (Join-Path $TestDir 'azure-root-direct' 'direct-azure')

    # ---------------------------------------------------------
    # Test Case 5: Selecting default profile (no arguments)
    # ---------------------------------------------------------
    Write-TestHeader 'Test 5: Selecting default profile with no arguments'

    # Set up mock default candidate directories (gcloud's platform default lives under
    # %APPDATA% on Windows, not under the profile root used for named profiles)
    $gcloudAppDataDir = Join-Path $env:APPDATA 'gcloud'
    New-Item -ItemType Directory -Path $gcloudAppDataDir -Force | Out-Null
    Select-GCloudProfile
    Assert-Equal $gcloudAppDataDir $env:CLOUDSDK_CONFIG 'Should fall back to the platform gcloud config directory when no profile is provided'

    New-Item -ItemType Directory -Path (Join-Path $TestDir '.azure') -Force | Out-Null
    Select-AzureCLIProfile
    Assert-Equal (Join-Path $TestDir '.azure') $env:AZURE_CONFIG_DIR 'Should fall back to default candidates when no profile is provided'

    # Reset candidate directories and test unsetting when no candidate exists
    Remove-Item -Recurse -Force $gcloudAppDataDir
    Select-GCloudProfile
    Assert-Empty $env:CLOUDSDK_CONFIG 'CLOUDSDK_CONFIG should be unset if no default candidates exist'

    Remove-Item -Recurse -Force (Join-Path $TestDir '.azure')
    Select-AzureCLIProfile
    Assert-Empty $env:AZURE_CONFIG_DIR 'AZURE_CONFIG_DIR should be unset if no default candidates exist'

    # ---------------------------------------------------------
    # Test Case 6: Comment-based help is present
    # ---------------------------------------------------------
    Write-TestHeader 'Test 6: Help validation'
    $gcloudHelp = Get-Help Select-GCloudProfile
    $azureHelp = Get-Help Select-AzureCLIProfile
    if ($gcloudHelp.Synopsis -notmatch 'gcloud') {
        Write-Host "ERROR: Select-GCloudProfile help is missing a synopsis" -ForegroundColor Red
        exit 1
    }
    if ($azureHelp.Synopsis -notmatch 'Azure') {
        Write-Host "ERROR: Select-AzureCLIProfile help is missing a synopsis" -ForegroundColor Red
        exit 1
    }

    Write-Host "`nALL TESTS PASSED SUCCESSFULLY!" -ForegroundColor Green
} finally {
    Remove-Module CloudSelect -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $TestDir -ErrorAction SilentlyContinue
}
