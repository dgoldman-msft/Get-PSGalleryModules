# Get-PSGalleryModules
Find PowerShell Gallery modules and all their statistics

### Getting Started with GetPSGalleryModStats

Copy this script down and save it to a local directory and run the following command: Import-Module Get-PSGalleryModules.ps1

- EXAMPLE 1: Get-PSGalleryModules PSUtil,PSFramework,PSServicePrincipal

    Returns stats for the following modules PSUtil,PSFramework,PSServicePrincipal

- EXAMPLE 2: Get-PSGalleryModules ModuleOne, ModuleTwo, ModuleThree -EnableException

    Returns stats for the following modules ModuleOne, ModuleTwo, ModuleThree and if fails will report all errors

- EXAMPLE 3: Getpgstat ModuleOne, ModuleTwo, ModuleThree -ShowFull -DisableProgressBar

    Executes via alias and returns stats for the following modules ModuleOne, ModuleTwo, ModuleThree and shows full details and the progress bar for large queries
