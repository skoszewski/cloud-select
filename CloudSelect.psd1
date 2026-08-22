@{
    RootModule        = 'CloudSelect.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '4358f928-0066-43cf-b676-be31b71deb79'
    Author            = 'Sławomir Koszewski'
    Description       = 'Isolate gcloud and Azure CLI credential state per profile via Select-GCloudProfile and Select-AzureCLIProfile.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Select-GCloudProfile', 'Select-AzureCLIProfile')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags = @('gcloud', 'azure', 'az', 'cli', 'profile')
        }
    }
}
