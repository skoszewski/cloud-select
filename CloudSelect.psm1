#Requires -Version 5.1
# CloudSelect.psm1 - PowerShell equivalent of cloud-select.sh
#
# Provides Select-GCloudProfile and Select-AzureCLIProfile, which isolate
# gcloud/az CLI credential state per "profile" (a subdirectory) by pointing
# CLOUDSDK_CONFIG / AZURE_CONFIG_DIR at it.

function Get-CloudSelectHome {
    if (Get-Variable -Name IsWindows -Scope Global -ErrorAction SilentlyContinue) {
        if ($IsWindows) { return $env:USERPROFILE } else { return $env:HOME }
    }
    return $env:USERPROFILE
}

function Write-CloudSelectHost {
    param(
        [Parameter(Mandatory, Position = 0)] [string] $Message,
        [ConsoleColor] $ForegroundColor,
        [switch] $NoNewline
    )
    if ($env:NO_COLOR -or -not $PSBoundParameters.ContainsKey('ForegroundColor')) {
        Write-Host $Message -NoNewline:$NoNewline
    } else {
        Write-Host $Message -ForegroundColor $ForegroundColor -NoNewline:$NoNewline
    }
}

function Select-GCloudProfile {
    <#
    .SYNOPSIS
        Switches the active gcloud CLI profile.
    .DESCRIPTION
        Points the gcloud CLI at an isolated configuration directory (a "profile") by
        setting the CLOUDSDK_CONFIG environment variable. Profiles are subdirectories of
        the gcloud profile root (see NOTES).
    .PARAMETER ProfileName
        The profile to switch to. Created automatically if it doesn't exist yet. If
        omitted, resets to the gcloud default: the first of the platform's gcloud config
        directory ("%APPDATA%\gcloud" on Windows, "$HOME/.config/gcloud" on macOS/Linux),
        "<root>/gcloud", or "<root>/../gcloud" that exists, or unsets CLOUDSDK_CONFIG if
        none exist.
    .PARAMETER Show
        Prints the active profile directory and the output of "gcloud config list".
    .EXAMPLE
        Select-GCloudProfile work
        Switches to the "work" profile, creating it if necessary.
    .EXAMPLE
        Select-GCloudProfile
        Resets to the default (unmanaged) gcloud profile.
    .EXAMPLE
        Select-GCloudProfile -Show
        Shows the active profile directory and configuration.
    .NOTES
        The profile root defaults to "$HOME/.config/gcloud.d" and can be overridden with
        the GCLOUD_PROFILE_ROOT environment variable, or by setting CLOUD_CLI_PROFILE_DIR
        to change the "$HOME/.config" base shared with Select-AzureCLIProfile.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Select')]
    param(
        [Parameter(ParameterSetName = 'Select', Position = 0)]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $root = if ($env:GCLOUD_PROFILE_ROOT) {
                $env:GCLOUD_PROFILE_ROOT
            } else {
                $homeDir = if ((Get-Variable -Name IsWindows -Scope Global -ErrorAction SilentlyContinue) -and -not $IsWindows) { $env:HOME } else { $env:USERPROFILE }
                $base = if ($env:CLOUD_CLI_PROFILE_DIR) { $env:CLOUD_CLI_PROFILE_DIR } else { Join-Path $homeDir '.config' }
                Join-Path $base 'gcloud.d'
            }
            if (Test-Path -LiteralPath $root -PathType Container) {
                Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -like "$wordToComplete*" } |
                    ForEach-Object { $_.Name }
            }
        })]
        [string] $ProfileName,

        [Parameter(ParameterSetName = 'Show', Mandatory)]
        [switch] $Show
    )

    $root = if ($env:GCLOUD_PROFILE_ROOT) {
        $env:GCLOUD_PROFILE_ROOT
    } else {
        $base = if ($env:CLOUD_CLI_PROFILE_DIR) { $env:CLOUD_CLI_PROFILE_DIR } else { Join-Path (Get-CloudSelectHome) '.config' }
        Join-Path $base 'gcloud.d'
    }

    if ($PSCmdlet.ParameterSetName -eq 'Show') {
        if ($env:CLOUDSDK_CONFIG) {
            Write-Host "Using profile directory: `"$env:CLOUDSDK_CONFIG`""
        } else {
            Write-Host 'Profile directory is not set.'
        }
        Write-Host ''
        & gcloud config list
        return
    }

    if ($ProfileName) {
        $target = Join-Path $root $ProfileName
        if (-not (Test-Path -LiteralPath $target -PathType Container)) {
            if (-not $PSCmdlet.ShouldContinue("Profile `"$ProfileName`" does not exist ($target). Create it?", 'Create new profile')) {
                Write-CloudSelectHost "Aborted: profile $ProfileName was not created" -ForegroundColor Red
                return
            }
            New-Item -ItemType Directory -Path $target -Force | Out-Null
            Write-CloudSelectHost "Created a new profile directory: $target" -ForegroundColor DarkGray
        }
        $env:CLOUDSDK_CONFIG = (Resolve-Path -LiteralPath $target).Path
        Write-CloudSelectHost "Selected gcloud CLI profile: $ProfileName" -ForegroundColor Green
    } else {
        $gcloudDefaultConfigDir = if (-not (Get-Variable -Name IsWindows -Scope Global -ErrorAction SilentlyContinue) -or $IsWindows) {
            Join-Path $env:APPDATA 'gcloud'
        } else {
            Join-Path (Join-Path (Get-CloudSelectHome) '.config') 'gcloud'
        }
        $candidates = @(
            $gcloudDefaultConfigDir,
            (Join-Path $root 'gcloud'),
            (Join-Path (Join-Path $root '..') 'gcloud')
        )
        $default = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -First 1

        if ($default) {
            $env:CLOUDSDK_CONFIG = (Resolve-Path -LiteralPath $default).Path
            Write-CloudSelectHost "Selected the default gcloud CLI profile: $($env:CLOUDSDK_CONFIG)" -ForegroundColor Green
        } else {
            Remove-Item Env:\CLOUDSDK_CONFIG -ErrorAction SilentlyContinue
        }
    }
}

function Select-AzureCLIProfile {
    <#
    .SYNOPSIS
        Switches the active Azure CLI profile.
    .DESCRIPTION
        Points the Azure CLI at an isolated configuration directory (a "profile") by
        setting the AZURE_CONFIG_DIR environment variable. Profiles are subdirectories of
        the Azure profile root (see NOTES).
    .PARAMETER ProfileName
        The profile to switch to. Created automatically if it doesn't exist yet. If
        omitted, resets to the Azure CLI default: the first of "$HOME/.azure",
        "<root>/.azure", or "<root>/../.azure" that exists, or unsets AZURE_CONFIG_DIR if
        none exist.
    .PARAMETER Show
        Prints the active profile directory and the signed-in account context.
    .PARAMETER Env
        Sets AZURE_SUBSCRIPTION_ID and AZURE_TENANT_ID from the signed-in account.
    .EXAMPLE
        Select-AzureCLIProfile work
        Switches to the "work" profile, creating it if necessary.
    .EXAMPLE
        Select-AzureCLIProfile
        Resets to the default (unmanaged) Azure CLI profile.
    .EXAMPLE
        Select-AzureCLIProfile -Show
        Shows the active profile directory and signed-in account.
    .EXAMPLE
        Select-AzureCLIProfile -Env
        Exports AZURE_SUBSCRIPTION_ID and AZURE_TENANT_ID for the active profile.
    .NOTES
        The profile root defaults to "$HOME/.config/azure.d" and can be overridden with
        the AZURECLI_PROFILE_ROOT environment variable, or by setting CLOUD_CLI_PROFILE_DIR
        to change the "$HOME/.config" base shared with Select-GCloudProfile.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Select')]
    param(
        [Parameter(ParameterSetName = 'Select', Position = 0)]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $root = if ($env:AZURECLI_PROFILE_ROOT) {
                $env:AZURECLI_PROFILE_ROOT
            } else {
                $homeDir = if ((Get-Variable -Name IsWindows -Scope Global -ErrorAction SilentlyContinue) -and -not $IsWindows) { $env:HOME } else { $env:USERPROFILE }
                $base = if ($env:CLOUD_CLI_PROFILE_DIR) { $env:CLOUD_CLI_PROFILE_DIR } else { Join-Path $homeDir '.config' }
                Join-Path $base 'azure.d'
            }
            if (Test-Path -LiteralPath $root -PathType Container) {
                Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -like "$wordToComplete*" } |
                    ForEach-Object { $_.Name }
            }
        })]
        [string] $ProfileName,

        [Parameter(ParameterSetName = 'Show', Mandatory)]
        [switch] $Show,

        [Parameter(ParameterSetName = 'Env', Mandatory)]
        [switch] $Env
    )

    $root = if ($env:AZURECLI_PROFILE_ROOT) {
        $env:AZURECLI_PROFILE_ROOT
    } else {
        $base = if ($env:CLOUD_CLI_PROFILE_DIR) { $env:CLOUD_CLI_PROFILE_DIR } else { Join-Path (Get-CloudSelectHome) '.config' }
        Join-Path $base 'azure.d'
    }

    if ($PSCmdlet.ParameterSetName -eq 'Show') {
        if ($env:AZURE_CONFIG_DIR) {
            Write-Host "Using profile directory: `"$env:AZURE_CONFIG_DIR`""
        } else {
            Write-Host 'Profile directory is not set.'
        }
        Write-Host ''

        $account = & az account show | ConvertFrom-Json
        Write-CloudSelectHost 'Tenant Id:         ' -ForegroundColor Cyan -NoNewline
        Write-Host $account.tenantId
        Write-CloudSelectHost 'Subscription Id:   ' -ForegroundColor Cyan -NoNewline
        Write-Host $account.id
        Write-CloudSelectHost 'Subscription Name: ' -ForegroundColor Cyan -NoNewline
        Write-Host $account.name
        Write-Host ''
        Write-CloudSelectHost 'User Name: ' -ForegroundColor Cyan -NoNewline
        Write-Host "$($account.user.name) [$($account.user.type)]"
        return
    }

    if ($PSCmdlet.ParameterSetName -eq 'Env') {
        $account = & az account show | ConvertFrom-Json
        $env:AZURE_SUBSCRIPTION_ID = $account.id
        $env:AZURE_TENANT_ID = $account.tenantId
        return
    }

    if ($ProfileName) {
        $target = Join-Path $root $ProfileName
        if (-not (Test-Path -LiteralPath $target -PathType Container)) {
            if (-not $PSCmdlet.ShouldContinue("Profile `"$ProfileName`" does not exist ($target). Create it?", 'Create new profile')) {
                Write-CloudSelectHost "Aborted: profile $ProfileName was not created" -ForegroundColor Red
                return
            }
            New-Item -ItemType Directory -Path $target -Force | Out-Null
            Write-CloudSelectHost "Created a new profile directory: $target" -ForegroundColor DarkGray
        }
        $env:AZURE_CONFIG_DIR = (Resolve-Path -LiteralPath $target).Path
        Write-CloudSelectHost "Selected Azure CLI profile: $ProfileName" -ForegroundColor Green
    } else {
        $candidates = @(
            (Join-Path (Get-CloudSelectHome) '.azure'),
            (Join-Path $root '.azure'),
            (Join-Path (Join-Path $root '..') '.azure')
        )
        $default = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -First 1

        if ($default) {
            $env:AZURE_CONFIG_DIR = (Resolve-Path -LiteralPath $default).Path
            Write-CloudSelectHost "Selected the default Azure CLI profile: $($env:AZURE_CONFIG_DIR)" -ForegroundColor Green
        } else {
            Remove-Item Env:\AZURE_CONFIG_DIR -ErrorAction SilentlyContinue
        }
    }
}

Export-ModuleMember -Function Select-GCloudProfile, Select-AzureCLIProfile
