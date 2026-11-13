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
    defaults to one under %TEMP%; a zip is copied in beside the junctions; -With is one
    comma-separated string, not a [string[]]; the two console hints it printed, /editor and
    research_all_technologies, are dropped, as about one mod's testing; and it prints the game it
    launched.

    WHAT IT BUILDS. A mod directory holding only the mods given and the bundled mods -With names,
    with their dependencies. A mod directory is junctioned in, so an edit to a prototype and a
    restart of the game is the whole edit-test loop: nothing is copied and nothing needs
    reinstalling. Data-stage changes need a full restart; Factorio has no hot reload for them. The
    junctions and the copied zips are rebuilt every run, so a mod renamed or removed cannot linger.
    It writes mod-list.json, and a README-BEFORE-DELETING.txt that says how to remove the
    directory.

    NO FOLDER THIS DID NOT MAKE IS USED UNLESS IT IS EMPTY (#423, #434). A run deletes the junctions
    and zips in -ModDirectory and overwrites its mod-list.json; -Clean deletes it whole. So a run
    and -Clean alike refuse, exit 1 before anything in it changes, naming it, an existing
    -ModDirectory that is a file, or a folder that is not empty and does not hold the
    README-BEFORE-DELETING.txt this writes into every folder it makes, first, before it changes
    anything there. A new folder, an empty one and one holding the marker are used. The comparison
    with the Steam path that stood here until #423 is gone. So the player's mod directory, the Steam
    build's %APPDATA%\Factorio\mods or a zip install's mods beside the game, is refused where it
    holds a file, and taken where it is empty. The game writes mod-list.json into an empty mod
    directory when it starts with --dump-data, measured on the Steam build 2.1.24
    (docs/factorio-facts.md, *Measured*, #434), so a folder that build has loaded mods from is not
    empty; a start with the game's window and a zip install were not run there. It cannot see a
    folder that holds a file of that name it did not write, which it then treats as its own. The
    game runs with the player's own write-data, so saves and settings are the player's. That is the
    difference from the load harness, which gives every run a write-data of its own.

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

.PARAMETER SelfTest
    Run the cases that hold the refusal of a folder this did not make, by a run and by -Clean,
    written whole to stderr with nothing on stdout (#429), a folder whose one file is hidden among
    them (#430); the use of one it made, a new one and an empty one; and the marker a run writes
    into the folder it builds; in folders under the temp directory; and the runner's own verdict on
    a case. A run is refused, or cleans, or builds its folder from a mod zip for a game whose
    Factorio.exe is text: it is cut short by a copy that fails, or it writes steam_appid.txt into
    %TEMP%\dev-launch, as every run does, and fails at the launch it attempts, as no system starts a
    text file. So no game is needed or started. Not run: a launch that starts, a junction, a bundled
    mod.

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
    [switch] $Clean,
    [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/load-harness-lib.ps1"

# Written into every folder this makes, before anything else there; the folders it may change.
$MARKER = 'README-BEFORE-DELETING.txt'

# Why $Path may not be used as the mod directory, or nothing: it is a file, or a folder that holds
# anything and not $MARKER, so this did not make it (#423). Its junctions and zips would be
# deleted and its mod-list.json overwritten, or with -Clean the whole of it.
function Get-ModDirectoryRefusal {
    param([Parameter(Mandatory)] [string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $isFolder = Test-Path -LiteralPath $Path -PathType Container
    if ($isFolder -and (Test-Path -LiteralPath (Join-Path $Path $MARKER) -PathType Leaf)) { return }
    if ($isFolder -and -not (Get-ChildItem -LiteralPath $Path -Force | Select-Object -First 1)) { return }
    "Refusing -ModDirectory $Path`: it is $($isFolder ? "a folder that holds files and no $MARKER" : 'a file'), so dev-launch.ps1 did not make it. " +
        'A run would delete its zips and junctions and overwrite its mod-list.json, and -Clean would delete it. Name a new or empty folder.'
}

if ($SelfTest) {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "dev-launch-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    New-Item -ItemType Directory -Path $temp | Out-Null
    # This script run on $Folder with $Arguments; its exit code, what it wrote to stdout and to
    # stderr apart (#429), and both in the order written. A line the child wrote to stderr reaches
    # this as an ErrorRecord, and one it wrote to stdout as a string.
    $run = {
        param([string] $Folder, [string[]] $Arguments)
        $lines = @(& pwsh -NoProfile -File $PSCommandPath -ModDirectory $Folder @Arguments 2>&1)
        $code = $LASTEXITCODE
        $isErr = { $args[0] -is [Management.Automation.ErrorRecord] }
        @{ Code = $code; Said = ($lines | ForEach-Object { "$_" } | Out-String)
           Out = ($lines | Where-Object { -not (& $isErr $_) } | ForEach-Object { "$_" } | Out-String)
           Err = ($lines | Where-Object { & $isErr $_ } | ForEach-Object { "$_" } | Out-String) }
    }
    # A run refused as $Refusal says: exit 1, the whole refusal in one line on stderr, and nothing
    # on stdout, where a caller reading a run's result would take it for output (#429). An empty
    # $Refusal, a folder not refused, is no refusal: every string contains ''.
    $refused = {
        param([hashtable] $Got, [string] $Refusal)
        $Refusal -ne '' -and $Got.Code -eq 1 -and $Got.Err.Contains($Refusal) -and $Got.Out.Trim() -eq ''
    }
    # A folder of a player's mods: a zip and a mod-list.json, no marker.
    $theirs = {
        param([string] $Name)
        $folder = Join-Path $temp $Name
        New-Item -ItemType Directory -Path $folder | Out-Null
        Set-Content -LiteralPath (Join-Path $folder 'some-mod_1.0.0.zip') -Value 'zip'
        Set-Content -LiteralPath (Join-Path $folder 'mod-list.json') -Value '{"mods":[]}'
        $folder
    }
    $both = { param([string] $Folder) (Test-Path -LiteralPath (Join-Path $Folder 'some-mod_1.0.0.zip')) -and (Test-Path -LiteralPath (Join-Path $Folder 'mod-list.json')) }
    # A case passes on one output, $true (#419). Any other output fails it, saying
    # why: [bool] of two values or more is true whatever they are.
    $judgeCase = {
        param([scriptblock] $CaseBlock)
        $caseOutput = @(& $CaseBlock)
        if ($caseOutput.Count -ne 1) { Write-Host "    gave $($caseOutput.Count) values, not one [bool]"; return $false }
        if ($caseOutput[0] -isnot [bool]) { Write-Host "    gave $($null -eq $caseOutput[0] ? '$null' : $caseOutput[0].GetType().Name), not a [bool]"; return $false }
        $caseOutput[0]
    }
    # A case that leaks a value, judged by the loop's own line, which must fail it:
    # so a loop put back to [bool] of the whole output fails the run (#419).
    $leakCase = 'the loop fails a case giving $null and then $false (#419); ok here means it was failed'
    # A game that is no game: Factorio.exe is text, which no system starts, and data/ holds no
    # bundled mod. A run on it gets as far as the launch, having built the mod directory, and fails
    # there; so no game is needed or started.
    $fakeGame = {
        $game = Join-Path $temp 'game'
        New-Item -ItemType Directory -Path (Join-Path $game 'bin/x64'), (Join-Path $game 'data') -Force | Out-Null
        $exe = Join-Path $game 'bin/x64/Factorio.exe'; Set-Content -LiteralPath $exe -Value 'not a program'
        $exe
    }
    # A mod zip of version 1.0.0 whose info.json gives $Name, in a folder of its own: a zip and
    # not a directory, as a junction cannot be made on every system CI runs.
    $modZip = {
        param([string] $Name = 'some-mod')
        $key = $Name -replace '[^\w-]', '-'
        $source = Join-Path $temp "mod-source-$key"
        New-Item -ItemType Directory -Path (Join-Path $source 'mod') | Out-Null
        Set-Content -LiteralPath (Join-Path $source 'mod/info.json') -Value (@{ name = $Name; version = '1.0.0' } | ConvertTo-Json)
        $zip = Join-Path $temp "$($key)_1.0.0.zip"
        [IO.Compression.ZipFile]::CreateFromDirectory($source, $zip)
        $zip
    }
    $cases = @(
        @{ Name = $leakCase; Test = { $null; $false } }
        @{ Name = 'a case passes on one $true; two values, a string or none fail it, and say so (#419)'; Test = {
            (& $judgeCase { $true }) -eq $true -and (& $judgeCase { $false }) -eq $false -and
                "$(& $judgeCase { $null; $true } 6>&1)" -ceq '    gave 2 values, not one [bool] False' -and
                "$(& $judgeCase { 'x' } 6>&1)" -ceq '    gave String, not a [bool] False' -and "$(& $judgeCase { } 6>&1)" -ceq '    gave 0 values, not one [bool] False' }}
        @{ Name = 'a run marks the folder it makes before the launch: on a game that cannot start, it leaves the marker, the zip and a mod-list.json, and a second run takes the folder (#423)'; Test = {
            $exe = & $fakeGame; $zip = & $modZip
            $folder = Join-Path $temp 'built'
            $first = & $run $folder @('-FactorioExe', $exe, $zip)
            $marked = Test-Path -LiteralPath (Join-Path $folder $MARKER) -PathType Leaf
            $built = & $both $folder
            $second = & $run $folder @('-FactorioExe', $exe, $zip)
            $first.Code -ne 0 -and $first.Said.Contains("mod dir    : $folder") -and $marked -and $built -and
                $second.Code -ne 0 -and -not $second.Said.Contains('Refusing -ModDirectory') -and $second.Said.Contains("mod dir    : $folder") } }
        @{ Name = 'a run cut short while it builds, before mod-list.json, has marked the folder first, and a second run takes it (#423)'; Test = {
            # A mod whose info.json names it bad/name: the zip's copy, to bad/name_1.0.0.zip in a
            # folder bad/ that is not there, fails after the folder is made and before
            # Write-ModList, which the marker followed until #423.
            $exe = & $fakeGame; $zip = & $modZip 'bad/name'
            $folder = Join-Path $temp 'cut'
            $first = & $run $folder @('-FactorioExe', $exe, $zip)
            $marked = Test-Path -LiteralPath (Join-Path $folder $MARKER) -PathType Leaf
            $listed = Test-Path -LiteralPath (Join-Path $folder 'mod-list.json')
            $second = & $run $folder @('-FactorioExe', $exe, $zip)
            $first.Code -ne 0 -and -not $first.Said.Contains('mod dir    :') -and $marked -and -not $listed -and
                $second.Code -ne 0 -and -not $second.Said.Contains('Refusing -ModDirectory') } }
        # The refusal cases below, through $refused, look for the whole refusal, which is longer
        # than any console is wide: a message wrapped at the width, as a thrown one is, fails them
        # on any machine.
        @{ Name = 'a run refuses a folder holding a zip and a mod-list.json and no marker, says why in one piece on stderr and nothing on stdout, and leaves both files'; Test = {
            $folder = & $theirs 'run'
            $got = & $run $folder @('some-mod')
            (& $refused $got (Get-ModDirectoryRefusal $folder)) -and (& $both $folder) } }
        @{ Name = '-Clean refuses that folder too, says why in one piece on stderr and nothing on stdout, and leaves both files'; Test = {
            $folder = & $theirs 'clean'
            $got = & $run $folder @('-Clean')
            (& $refused $got (Get-ModDirectoryRefusal $folder)) -and (& $both $folder) } }
        @{ Name = '-Clean refuses a file named as the mod directory, says it is a file in one piece on stderr, and leaves it'; Test = {
            $file = Join-Path $temp 'a-file.txt'; Set-Content -LiteralPath $file -Value 'x'
            $refusal = Get-ModDirectoryRefusal $file
            $got = & $run $file @('-Clean')
            $refusal.Contains('it is a file') -and (& $refused $got $refusal) -and (Test-Path -LiteralPath $file -PathType Leaf) } }
        @{ Name = 'a folder whose one file is hidden is not empty: a run and -Clean refuse it, say why, and leave the file (#430)'; Test = {
            # Hidden as the system it runs on reads it: by a leading dot off Windows, and by the
            # Hidden attribute on Windows. A listing without -Force must not see it, or the case
            # holds nothing.
            $folder = Join-Path $temp 'hidden'; New-Item -ItemType Directory -Path $folder | Out-Null
            $file = Join-Path $folder '.hidden-file'; Set-Content -LiteralPath $file -Value 'x'
            if ($IsWindows) { $item = Get-Item -LiteralPath $file -Force; $item.Attributes = $item.Attributes -bor [IO.FileAttributes]::Hidden }
            $unseen = -not (Get-ChildItem -LiteralPath $folder | Select-Object -First 1)
            $refusal = Get-ModDirectoryRefusal $folder
            $ran = & $run $folder @('some-mod')
            $cleaned = & $run $folder @('-Clean')
            $unseen -and [bool] $refusal -and (& $refused $ran $refusal) -and (& $refused $cleaned $refusal) -and (Test-Path -LiteralPath $file -PathType Leaf) } }
        @{ Name = '-Clean removes a folder holding the marker, its zip and its mod-list.json'; Test = {
            $folder = & $theirs 'made'
            Set-Content -LiteralPath (Join-Path $folder $MARKER) -Value 'made by dev-launch.ps1'
            $got = & $run $folder @('-Clean')
            $got.Code -eq 0 -and $got.Said.Contains("removed $folder") -and -not (Test-Path -LiteralPath $folder) } }
        @{ Name = 'a new folder, an empty one and one holding the marker are not refused; -Clean of a new one says there is nothing'; Test = {
            $empty = Join-Path $temp 'empty'; New-Item -ItemType Directory -Path $empty | Out-Null
            $made = & $theirs 'made-too'; Set-Content -LiteralPath (Join-Path $made $MARKER) -Value 'x'
            $new = Join-Path $temp 'new'
            $nothing = & $run $new @('-Clean')
            -not (Get-ModDirectoryRefusal $new) -and -not (Get-ModDirectoryRefusal $empty) -and -not (Get-ModDirectoryRefusal $made) -and
                $nothing.Code -eq 0 -and $nothing.Said.Contains("nothing to clean at $new") } }
    )
    $failures = 0
    $n = 0
    try {
        foreach ($c in $cases) {
            $n++
            $ok = try { & $judgeCase $c.Test } catch { Write-Host "    threw: $($_.Exception.Message)"; $false }
            if ($c.Name -ceq $leakCase) { $ok = -not $ok }
            Write-Host ("self-test {0}/{1}: {2} -- {3}" -f $n, $cases.Count, $c.Name, $(if ($ok) { 'ok' } else { 'FAILED' }))
            if (-not $ok) { $failures++ }
        }
    }
    finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host ''
    if ($failures) { Write-Host "FAILED - self-test: $failures of $($cases.Count) case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all $($cases.Count) cases."
    exit 0
}

if (-not $ModDirectory) { $ModDirectory = Join-Path ([IO.Path]::GetTempPath()) 'dev-launch-mods' }
$ModDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ModDirectory)

# Before anything in it changes, for a run and for -Clean alike (#423). Written whole, not thrown:
# the error view wraps a thrown message at the console's width, breaking the path inside it.
$refusal = Get-ModDirectoryRefusal -Path $ModDirectory
if ($refusal) { [Console]::Error.WriteLine($refusal); exit 1 }

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
# These junctions outlive the script, since the game needs them while it runs, so a warning goes
# where whoever finds this directory later will see it. Written first: it marks the folder as this
# script's (#423), so a run cut short below leaves one the next run still takes.
@"
This directory is generated by dev-launch.ps1, from grado-factorio-tools.

DO NOT delete it with ``Remove-Item -Recurse`` from Windows PowerShell 5.1, or with any tool that
follows reparse points. The mod folders here are JUNCTIONS pointing into the mods' sources, and 5.1
recurses through them: it would delete the sources, not just these links.

To remove it safely:

    pwsh -File $PSCommandPath -Clean -ModDirectory "$ModDirectory"
"@ | Set-Content -LiteralPath (Join-Path $ModDirectory $MARKER) -Encoding utf8

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
