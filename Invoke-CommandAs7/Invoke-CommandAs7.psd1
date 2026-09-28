#
# Module manifest for module 'Invoke-CommandAs7'
#
# This is an EXPERIMENTAL fork of 'Invoke-CommandAs' by Marc R Kellerman,
# adapted to remove the dependency on the PSScheduledJob module (Register-ScheduledJob,
# New-ScheduledJobOption, Get-ScheduledJob, Unregister-ScheduledJob), which is a
# Windows PowerShell (Desktop) only module and was never ported to PowerShell 7 (Core).
# That dependency is what makes the original module fail under PowerShell 7.
#
# Packaged and named separately (own GUID/module name) so it can be installed
# side-by-side with the original 'Invoke-CommandAs' module without conflicting.
# The exported command is still 'Invoke-CommandAs', so usage/syntax is unchanged.
#
# If this fork proves stable, it is intended to either:
#   a) replace the original module 1:1 in existing environments, or
#   b) have its changes merged back upstream into the original 'Invoke-CommandAs' module.
#
# Forked from: https://github.com/mkellerman/Invoke-CommandAs
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'Invoke-CommandAs7.psm1'

# Version number of this module.
ModuleVersion = '3.1.7'

# Supported PSEditions
CompatiblePSEditions = @('Desktop', 'Core')

# ID used to uniquely identify this module
GUID = '1c2a12a9-edc7-48f9-a942-849be403f81d'

# Author of this module
Author = 'Marc R Kellerman'

# Company or vendor of this module
CompanyName = 'Marc R Kellerman'

# Copyright statement for this module
Copyright = '(c) 2019 MKellerman. All rights reserved.'

# Description of the functionality provided by this module
Description = 'EXPERIMENTAL PowerShell 7 (Core) compatible fork of Invoke-CommandAs. Invoke Command as System/User on Local/Remote computer using ScheduleTask, without depending on the Windows-PowerShell-only PSScheduledJob module. Not published/maintained independently; intended either to replace the original module 1:1 once proven stable, or to have its changes merged back into the original. Original project: https://github.com/mkellerman/Invoke-CommandAs'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '3.0'

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# CLRVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @('Invoke-CommandAs')

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('PSRemoting','PSExec','PowerShell7','Experimental','Fork')

        # A URL to the license for this module.
        # LicenseUri = ''

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/mkellerman/Invoke-CommandAs'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        ReleaseNotes = 'Experimental fork of Invoke-CommandAs: reworked Invoke-ScheduledTask (Private) to drop the PSScheduledJob dependency (Register-ScheduledJob/New-ScheduledJobOption/Get-ScheduledJob/Unregister-ScheduledJob), which does not exist in PowerShell 7. Elevated/impersonated execution (-AsSystem/-AsUser/-AsInteractive/-AsGMSA) is now run via a standalone bootstrap script launched by the same PowerShell engine (powershell.exe or pwsh.exe) hosting the caller, with results/errors exchanged via Clixml files instead of the ScheduledJob job infrastructure. Public interface (Invoke-CommandAs and its parameters) is unchanged.'

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}
