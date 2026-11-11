<#
.SYNOPSIS
    Launches the Factorio client, the full game with its window, with the mods it is given, in a
    mod directory of their own. Exit 0 means the game was started; with -Wait, the game's own exit
    code is returned. With -Clean it removes that mod directory, junctions first, and starts
    nothing.

.DESCRIPTION
    WHERE IT CAME FROM (grado-factorio-tools#350, #321 ruling 3). realistic-fusion-refreshed's
    scripts/dev-launch.ps1 at 605b960, read 2026-11-06, which launched that repository's own three
    mods. What changed in the move: the mods are its arguments, as the packer's were when it moved,
    each a mod directory or zip, named by its info.json through Get-HarnessMods; the mod directory
    defaults to one under %TEMP%; and a zip is copied in beside the junctions.

    WHAT IT BUILDS. A mod directory holding only the mods given and the bundled mods -With names,
    with their dependencies. A mod directory is junctioned in, so an edit to a prototype and a
    restart of the game is the whole edit-test loop: nothing is copied and nothing needs
    reinstalling. Data-stage changes need a full restart; Factorio has no hot reload for them. The
    junctions and the copied zips are rebuilt every run, so a mod renamed or removed cannot linger.
    It writes mod-list.json, and a README-BEFORE-DELETING.txt that says how to remove the
    directory.

    THE PLAYER'S MOD DIRECTORY IS NEVER USED, and is refused as -ModDirectory: this rewrites
    mod-list.json and would lose which of the player's mods are enabled. The game runs with the
    player's own write-data, so saves and settings are the player's. That is the difference from
    the load harness, which gives every run a write-data of its own.

    ON A STEAM BUILD, running Factorio.exe directly makes the Steam API relaunch the game through
    Steam and exit ("Steam requires game restart, restarting..."), and Steam starts it WITHOUT
    --mod-directory, so the player's mods load silently in place of these. A steam_appid.txt in
    the working directory tells the Steam API not to restart. This launches the game from a
    scratch directory under %TEMP% that holds one, so the Steam installation is never changed.
    Passing arguments through steam:// URLs does not work: Steam clients ignore them. On a zip
    install the file is not read. Both were launched on 2026-11-11; docs/measurements.md has the
    runs.

    THE GAME VERSION. -FactorioExe, else $env:FACTORIO_EXE, else the Steam path
    Resolve-FactorioExe names. Steam updates on its own, so a run without either changes version
    silently (#321 ruling 7).

    WHAT IT CANNOT SEE. Whether the game loaded the mods: it starts the game and returns, and the
    game's own window says what failed. A mod a given mod depends on and was not given, which the
    game then reports missing.

.PARAMETER Mods
    The mods to launch with: mod directories, mod zips, or directories of those. The trailing
    arguments, so `pwsh -File` can pass several. See Get-HarnessMods in load-harness-lib.ps1 for
    what is picked up from a directory.

.PARAMETER With
    Bundled mods to enable, comma-separated, e.g. -With space-age. Dependencies are pulled in, and
    an unknown name is refused.

.PARAMETER ModDirectory
    Where to build the mod directory. Defaults to dev-launch-mods under %TEMP%.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam path Resolve-FactorioExe
    names.

.PARAMETER Wait
    Block until the game exits, and exit with its code. Without it the script returns as soon as
    the game has started.

.PARAMETER Clean
    Remove the junctions and the mod directory, then exit without launching. Use this rather than
    deleting the directory by hand: it holds junctions into the mods' sources, and Windows
    PowerShell 5.1's Remove-Item -Recurse follows them instead of skipping them, which would delete
    the sources through the links.

.EXAMPLE
    pwsh -File vendor/grado-factorio-tools/scripts/dev-launch.ps1 ./my-mod ./my-mod-assets

.EXAMPLE
    pwsh -File vendor/grado-factorio-tools/scripts/dev-launch.ps1 -With space-age -ModDirectory ../_dev-mods ./my-mod

.EXAMPLE
    pwsh -File vendor/grado-factorio-tools/scripts/dev-launch.ps1 -Clean -ModDirectory ../_dev-mods
#>

#Requires -Version 7
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(ValueFromRemainingArguments)] [string[]] $Mods,
    [string] $With,
    [string] $ModDirectory,
    [string] $FactorioExe,
    [switch] $Wait,
    [switch] $Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/load-harness-lib.ps1"

if (-not $ModDirectory) { $ModDirectory = Join-Path ([IO.Path]::GetTempPath()) 'dev-launch-mods' }
$ModDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ModDirectory)

# This directory gets its junctions and zips deleted and its mod-list.json overwritten wholesale.
# Pointed at the player's own mod directory that would destroy the enabled state of every mod
# installed there.
$playerMods = Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'Factorio/mods'
if ((Resolve-Path -LiteralPath $ModDirectory -ErrorAction SilentlyContinue)?.Path -eq
    (Resolve-Path -LiteralPath $playerMods -ErrorAction SilentlyContinue)?.Path -and (Test-Path -LiteralPath $playerMods)) {
    throw "Refusing to use your own Factorio mod directory ($playerMods): this script rewrites mod-list.json and would lose which mods you have enabled."
}

if ($Clean) {
    if (Test-Path -LiteralPath $ModDirectory) {
        Remove-ModJunctions -ModDirectory $ModDirectory
        Remove-Item -LiteralPath $ModDirectory -Recurse -Force
        Write-Host "removed $ModDirectory"
    }
    else { Write-Host "nothing to clean at $ModDirectory" }
    exit 0
}
if (-not $Mods) { throw 'Name the mods to launch with: mod directories, zips, or directories of them. Or -Clean.' }

$exe = Resolve-FactorioExe -Path $FactorioExe
$bundled = Get-BundledMods -FactorioExe $exe
try { $enabled = Resolve-BundledSelection -Requested @($With -split ',' | ForEach-Object Trim | Where-Object { $_ }) -Bundled $bundled }
catch { throw "-With $($_.Exception.Message)" }
$rows = @(Get-HarnessMods -Path $Mods)

New-Item -ItemType Directory -Path $ModDirectory -Force | Out-Null
# Rebuilt every run, so a mod renamed or removed cannot linger as a stale link or zip.
Remove-ModJunctions -ModDirectory $ModDirectory
Get-ChildItem -LiteralPath $ModDirectory -Filter *.zip -File | Remove-Item -Force
$links = @{}
foreach ($r in $rows) {
    if ($r.Kind -eq 'directory') { $links[$r.Name] = $r.Path }
    else { Copy-Item -LiteralPath $r.Path -Destination (Join-Path $ModDirectory "$($r.Name)_$($r.Version).zip") }
}
if ($links.Count) { New-ModJunctions -ModDirectory $ModDirectory -Links $links }
Write-ModList -ModDirectory $ModDirectory -Bundled $bundled -EnabledBundled $enabled -Mods @($rows | ForEach-Object Name)

# These junctions outlive the script, since the game needs them while it runs, so a warning goes
# where whoever finds this directory later will see it.
@"
This directory is generated by dev-launch.ps1, from grado-factorio-tools.

DO NOT delete it with ``Remove-Item -Recurse`` from Windows PowerShell 5.1, or with any tool that
follows reparse points. The mod folders here are JUNCTIONS pointing into the mods' sources, and 5.1
recurses through them: it would delete the sources, not just these links.

To remove it safely:

    pwsh -File $PSCommandPath -Clean -ModDirectory "$ModDirectory"
"@ | Set-Content -LiteralPath (Join-Path $ModDirectory 'README-BEFORE-DELETING.txt') -Encoding utf8

Write-Host "mods       : $(($rows | ForEach-Object { "$($_.Name) ($($_.Kind))" }) -join ', ')"
Write-Host "bundled    : $(if ($enabled) { $enabled -join ', ' } else { 'none (base only)' })"
Write-Host "mod dir    : $ModDirectory"
Write-Host "game       : $exe"
Write-Host ''
Write-Host 'Restart the game to pick up prototype, recipe or locale edits.'
Write-Host ''

# From a scratch directory holding steam_appid.txt: the Steam API reads it from the WORKING
# directory, not from beside the executable, and then skips the relaunch through Steam that would
# drop --mod-directory. 427520 is Factorio's Steam app id.
$launchDir = Join-Path ([IO.Path]::GetTempPath()) 'dev-launch'
New-Item -ItemType Directory -Path $launchDir -Force | Out-Null
'427520' | Set-Content -LiteralPath (Join-Path $launchDir 'steam_appid.txt') -Encoding ascii -NoNewline

$proc = Start-Process -FilePath $exe -ArgumentList @('--mod-directory', (ConvertTo-NativeArgument $ModDirectory)) -WorkingDirectory $launchDir -PassThru  # strict-lists: one
Write-Host "launched Factorio (pid $($proc.Id))"

if ($Wait) {
    $proc.WaitForExit()
    Write-Host "Factorio exited with code $($proc.ExitCode)"
    exit $proc.ExitCode
}
exit 0
