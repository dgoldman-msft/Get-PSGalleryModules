Function Get-PSGalleryModules {
    <#
        .SYNOPSIS
            Calls PowerShell Gallery to get module statistics

        .DESCRIPTION
            This function will take a list of modules and retrieve current download statistics from the PowerShell Gallery

        .PARAMETER ModuleList
            List of modules to pull download statistics for

        .PARAMETER Repository
            Module repository to search

        .PARAMETER EnableException
            Disables user-friendly warnings and enables the throwing of exceptions. This is less user friendly, but allows catching exceptions in calling scripts.

        .PARAMETER ShowFull
            Show full table entries

        .PARAMETER DisableProgressBar
            Disable progress bar

        .PARAMETER Update
            Update to the latest version of the module from the PowerShell Gallery

        .EXAMPLE
            PS C:\> Get-PSGalleryModules PSUtil,PSFramework,PSServicePrincipal

            Returns stats for the following modules PSUtil,PSFramework,PSServicePrincipal

        .EXAMPLE
            PS C:\> Get-PSGalleryModules ModuleOne, ModuleTwo, ModuleThree -EnableException

            Returns stats for the following modules ModuleOne, ModuleTwo, ModuleThree and if fails will report all errors

        .EXAMPLE
            PS C:\> Getpgstat ModuleOne, ModuleTwo, ModuleThree -ShowFull -DisableProgressBar

            Executes via alias and returns stats for the following modules ModuleOne, ModuleTwo, ModuleThree and shows full details and the progress bar for large queries

        .NOTES
            None
    #>

    [OutputType([System.Management.Automation.PSCustomObject[]])]
    [Alias('getpgstat')]
    [CmdletBinding(DefaultParameterSetName = "Default")]
    param(
        [switch]
        $DisableProgressBar,

        [switch]
        $EnableException,

        [Parameter(Position = 1)]
        [Object[]]
        $ModuleList = "PSFramework",

        [string]
        $Repository = 'PSGallery',

        [switch]
        $ShowFull,

        [switch]
        $Update
    )

    begin {
        Write-Output "Initializing searching query to the $($Repository) repository"
        $parameters = $PSBoundParameters
        [System.Collections.ArrayList]$objects = @()
    }

    process {
        try {
            if (-NOT $ModuleList) {
                Write-Output "No module passed in or set in module configuration settings"
                return
            }

            # If we pass in a Get-Module -ListAvailable strip duplicates out and handle it below locally
            $ModuleList | Get-Unique | Foreach-Object {
                if (-NOT ($parameters.ContainsKey('DisableProgressBar'))) {
                    $policyCounter ++
                    Write-Progress -Activity "Querying module list. List contains $($ModuleList.Count) modules" -Status "Querying module list #: $progressCounter" -PercentComplete ($progressCounter / $ModuleList.count * 100)
                    $progressCounter ++
                }

                Write-Output "Searching PowerShell Gallery for module $($PSItem)"
                if (-NOT ($PSGalleryModule = Find-Module -Name $PSItem -Repository $Repository -ErrorAction SilentlyContinue)) {

                    Write-Output "Module $($PSItem) not found"
                    return
                }
                else {
                    if (-NOT ($localVersion = Get-Module -Name $PSItem -ListAvailable -ErrorAction SilentlyContinue)) {
                        $currentModule = [PSCustomObject]@{
                            PSTypeName      = 'PowershellUtilities.PSGalleryModules'
                            Name            = $PSGalleryModule.Name
                            Published       = $PSGalleryModule.PublishedDate.ToShortDateString()
                            Downloads       = $PSGalleryModule.AdditionalMetadata.downloadCount
                            'PSG Version'   = $PSGalleryModule.Version.ToString()
                            'Local Version' = "None"
                            'PSEdition'     = "None"
                            'Local Path'    = "None"
                            'Last Update'   = ($PSGalleryModule.AdditionalMetadata.lastUpdated -Split ' ')[0]
                            'Updatable'     = "No"
                            'Pre-Release'   = $PSGalleryModule.AdditionalMetadata.IsPrerelease
                            Provider        = $PSGalleryModule.AdditionalMetadata.PackageManagementProvider
                            Tag             = $PSGalleryModule.Tags | Sort-Object | Join-String -Separator ', '
                            License         = $PSGalleryModule.LicenseUri
                            ProjectUri      = $PSGalleryModule.ProjectUri
                        }
                        # No local version so add the one found from the PSGallery
                        $null = $objects.Add($currentModule)
                    }
                    else {
                        foreach ($instance in $localVersion) {
                            if ($PSGalleryModule.Version.ToString() -gt $instance.Version) { $needsUpdate = "Yes" } else { $needsUpdate = "No" }
                            if ($instance.Path -match '\\WindowsPowerShell') { $psVersion = 'Desktop' }
                            elseif ($instance.Path -match '\\PowerShell') { $psVersion = 'Core' }
                            $null = $instance.Path -match '[\S\s]*(?=Modules\\)'

                            $currentModule = [PSCustomObject]@{
                                PSTypeName      = 'PowershellUtilities.PSGalleryModules'
                                Name            = $PSGalleryModule.Name
                                Published       = $PSGalleryModule.PublishedDate.ToShortDateString()
                                Downloads       = $PSGalleryModule.AdditionalMetadata.downloadCount
                                'PSG Version'   = $PSGalleryModule.Version.ToString()
                                'Local Version' = $instance.Version.ToString()
                                'PSEdition'     = $psVersion
                                'Local Path'    = $matches[0]
                                'Last Update'   = ($PSGalleryModule.AdditionalMetadata.lastUpdated -Split ' ')[0]
                                'Updatable'     = $needsUpdate
                                'Pre-Release'   = $PSGalleryModule.AdditionalMetadata.IsPrerelease
                                Provider        = $PSGalleryModule.AdditionalMetadata.PackageManagementProvider
                                Tag             = $PSGalleryModule.Tags | Sort-Object | Join-String -Separator ', '
                                License         = $PSGalleryModule.LicenseUri
                                ProjectUri      = $PSGalleryModule.ProjectUri
                            }

                            # Need this because you can't compare against a null collection
                            if (-NOT ($objects)) { $null = $objects.Add($currentModule) }
                            elseif (-NOT (Compare-Object -ReferenceObject $objects.'Local Version' -DifferenceObject $instance.Version -IncludeEqual -ExcludeDifferent)) { $null = $objects.Add($currentModule) }
                        }
                    }
                }
            }
            if ($parameters.ContainsKey('Update')) {
                foreach ($object in $objects) {
                    if (-NOT ($parameters.ContainsKey('DisableProgressBar'))) {
                        $policyCounter ++
                        Write-Progress -Activity "Querying module list. List contains $($object.Count) modules" -Status "Querying module list #: $progressCounter" -PercentComplete ($progressCounter / $object.count * 100)
                        $progressCounter ++
                    }
                    if ($currentVersion = Get-Module $object.Name -ListAvailable -ErrorAction SilentlyContinue) {
                        if ($currentVersion[0].Version.ToString() -lt $object.PSGallery) {
                            Write-Output "Module: $($object.Name) being updated to the latest version"
                            Install-Module -Name $object.Name -Repository PSGallery -Force -ErrorAction SilentlyContinue
                            Import-Module -Name $object.Name -Force -ErrorAction SilentlyContinue

                            # Update the object version because we updated to latest
                            $object.Local = $object.PSGallery
                        }
                        else {
                            Write-Output "Module: $($object.Name) - Version $($object.Version) does not need to be updated at this time"
                        }
                    }
                    else {
                        Write-Output "Module: $($object.Name) not in local repository"
                    }
                }
            }

            if ($parameters.ContainsKey('ShowFull')) { $objects | Sort-Object Name } else { $objects | Select-Object Name, Downloads, 'PSG Version', 'Local Version', 'PSEdition', 'Updatable', 'Local Path' | Sort-Object Name }
        }
        catch {
            Stop-PSFFunction -String 'Failure' -Cmdlet $PSCmdlet -ErrorRecord $_ -EnableException $EnableException
            return
        }
    }

    end {
        Write-Output "Calculating stats completed"
    }
}