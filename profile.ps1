﻿trap { Write-Warning ($_.ScriptStackTrace | Out-String) }
# This timer is used by Trace-Message, I want to start it immediately
$TraceVerboseTimer = New-Object System.Diagnostics.Stopwatch
$TraceVerboseTimer.Start()

## Set the profile directory first, so we can refer to it from now on.
Set-Variable ProfileDir (Split-Path $MyInvocation.MyCommand.Path -Parent) -Scope Global -Option AllScope, Constant -ErrorAction SilentlyContinue

# Ensure that PSHome\Modules is there so we can load the default modules
$Env:PSModulePath += ";$PSHome\Modules;$Home\Projects\Modules"

# These will get loaded automatically, but it's faster to load them explicitly all at once
Import-Module Microsoft.PowerShell.Management,
              Microsoft.PowerShell.Security,
              Microsoft.PowerShell.Utility -Verbose:$false

Import-Module -FullyQualifiedName @{
                ModuleName="Environment";       ModuleVersion="1.0.4"},
              @{ModuleName="Configuration";     ModuleVersion="1.0.4"},
              @{ModuleName="Pansies";           ModuleVersion="1.2.0"},
              @{ModuleName="PowerLine";         ModuleVersion="3.0.0"},
              @{ModuleName="DefaultParameter";  ModuleVersion="1.0.0"}

# Need to
[System.Collections.Generic.List[ScriptBlock]]$global:Prompt =  @(
    { $MyInvocation.HistoryId }
    { "$([char]9587)" * $NestedPromptLevel }
    { if($pushd = (Get-Location -Stack).count) { "$([char]187)" + $pushd } }
    { Get-SegmentedPath }
)

Set-PowerLinePrompt -Newline

Import-Module -FullyQualifiedName @{
                ModuleName="PSGit";             ModuleVersion="2.1.0"} -Verbose:$false,
              @{ModuleName="Profile";           ModuleVersion="1.2.0"} -Verbose:$false

# For now, CORE edition is always verbose, because I can't test for KeyState
if("Core" -eq $PSVersionTable.PSEdition) {
    $VerbosePreference = "Continue"
} else {
    # Import-Module xColors
    # Check SHIFT state ASAP at startup so I can use that to control verbosity :)
    Add-Type -Assembly PresentationCore, WindowsBase
    try {
        if([System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftShift) -OR
           [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::RightShift)) {
            $VerbosePreference = "Continue"
        }
    } catch {}
}

# First call to Trace-Message, pass in our TraceTimer that I created at the top to make sure we time EVERYTHING.
# This has to happen after the verbose check, obviously
Trace-Message "Modules Imported" -Stopwatch $TraceVerboseTimer

# I prefer that my sessions start in my profile directory
if($ProfileDir -ne (Get-Location)) { Set-Location $ProfileDir }

## Add my Projects folder to the module path
$Env:PSModulePath = Select-UniquePath "$ProfileDir\Modules" (Get-SpecialFolder *Modules -Value) ${Env:PSModulePath} "${Home}\Projects\Modules"
Trace-Message "Env:PSModulePath Updated"

## This function cannot be in a module (else it will import the module to a nested scope)
function Reset-Module {
    <#
    .Synopsis
        Remove and re-import a module to force a full reload
    #>
    param($ModuleName)
    Microsoft.PowerShell.Core\Remove-Module $ModuleName
    Microsoft.PowerShell.Core\Import-Module $ModuleName -force -pass | Format-Table Name, Version, Path -Auto
}

# I have a hard time remembering to use ZLocation. This helped...
Set-Alias cd Set-ZLocation -Option AllScope

Trace-Message "Profile Finished!" -KillTimer
Remove-Variable TraceVerboseTimer

## Relax the code signing restriction so we can actually get work done
try { Set-ExecutionPolicy RemoteSigned Process } catch [PlatformNotSupportedException] {}

$VerbosePreference = "SilentlyContinue"