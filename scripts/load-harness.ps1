<#
.SYNOPSIS
    Loads a set of mods in an isolated mod directory against a Factorio install, creates a
    throwaway map, and reports whether it loaded -- with the game's own error text when it did
    not. Exit 0 means the map was created and, if -Check was given, the check passed.

.DESCRIPTION
    THE HARNESS, NOT A CHECK OF ANY ONE MOD. Moved from realistic-fusion-refreshed's
    load-check.ps1 at 19e2d92 (grado-factorio-tools#16): the machinery that script ran its
    invariants inside. The invariants stayed there. This carries none, and a caller that has some
    brings them with -Check, or dot-sources load-harness-lib.ps1 and drives the load itself.

    WHAT A PASS MEANS. Every mod's prototypes validated, every dependency resolved, and a map was
    created -- which runs every mod's on_init, so a mod that refuses itself at start-up fails here
    too. Factorio exiting 0 without writing the save is a failure, not a pass.

    WHAT IT CANNOT SEE. A headless run loads no sprites or sounds, so a prototype naming a file
    that does not exist validates and the player's game still refuses to start. Two mods defining
    one prototype name load without a word -- the second replaces the first. And it runs no ticks:
    whatever breaks only once the game runs is out of reach. Those are a caller's checks to bring.

    THE PLAYER'S GAME IS NEVER TOUCHED. The mods go into a mod directory under a temp directory,
    and Factorio runs with a write-data directory of its own there, so the player's mods,
    mod-list.json, saves and player-data.json are neither read nor written. -SelfTest asserts it.

    Bundled mods (space-age, elevated-rails, quality) live in the game's data/ directory, so they
    load unless explicitly disabled. They are disabled unless -With names them, for a base-only
    load.

.PARAMETER Mods
    What to load: mod directories, mod zips, or directories of those -- a fetch-mods.ps1 cache is
    one. The trailing arguments, so `pwsh -File` can pass several. See Get-HarnessMods in
    load-harness-lib.ps1 for what is picked up from a directory.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on this machine.

.PARAMETER With
    Bundled mods to enable, comma-separated, e.g. -With space-age. Dependencies are pulled in, so
    space-age alone is enough. An unknown name is refused rather than ignored.

.PARAMETER Check
    A script to run on the loaded game, called as `& <Check> -Harness $h -Load $load` after a
    successful load: $h is New-LoadHarness's object and $load is Invoke-HarnessLoad's. It can
    dot-source load-harness-lib.ps1 to dump the data stage or load again under another mod list.
    A non-zero exit or a throw fails the run.

.PARAMETER KeepTemp
    Keep the temp directory -- the save, the captured output -- for debugging. Junctions are
    always removed.

.PARAMETER SelfTest
    Prove the harness can fail and that it passes what it should, against the install: a good mod
    loads from a directory, a zip and a cache-shaped directory; a broken one fails with the game's
    error text; a failing -Check fails the run; the mods' sources and the player's game are left
    as they were.

.EXAMPLE
    pwsh -File scripts/load-harness.ps1 .mod-cache/Grado_ABC

.EXAMPLE
    pwsh -File scripts/load-harness.ps1 -With space-age -Check scripts/my-invariants.ps1 ./my-mod .mod-cache/krastorio2
#>

#Requires -Version 7
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(ValueFromRemainingArguments)] [string[]] $Mods,
    [string] $FactorioExe,
    [string] $With,
    [string] $Check,
    [switch] $KeepTemp,
    [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/load-harness-lib.ps1"

function Invoke-SelfTest {
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('load-harness-selftest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $temp -Force | Out-Null

    $newMod = {
        param([string] $Dir, [string] $Name, [string] $Data)
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        @{ name = $Name; version = '1.0.0'; title = $Name; author = 'load-harness.ps1'
           factorio_version = '2.0'; dependencies = @('base') } | ConvertTo-Json | Set-Content (Join-Path $Dir 'info.json')
        $Data | Set-Content (Join-Path $Dir 'data.lua')
    }
    $good = Join-Path $temp 'src/harness-good'
    & $newMod $good 'harness-good' 'data:extend({ { type = "item", name = "harness-good-item", stack_size = 50, icon = "__base__/graphics/icons/iron-plate.png" } })'
    $broken = Join-Path $temp 'src/harness-broken'
    & $newMod $broken 'harness-broken' 'data:extend({ { type = "item", name = "harness-broken-item" } })'

    # A cache-shaped directory: one mod directory, one zip named as nothing in particular, and the
    # kind of clutter fetch-mods.ps1 leaves beside them.
    $cache = Join-Path $temp 'cache'
    & $newMod (Join-Path $cache 'harness-cached') 'harness-cached' 'data:extend({ { type = "item", name = "harness-cached-item", stack_size = 50, icon = "__base__/graphics/icons/iron-plate.png" } })'
    $zipped = Join-Path $temp 'stage/harness-zipped_1.0.0'
    & $newMod $zipped 'harness-zipped' 'data:extend({ { type = "item", name = "harness-zipped-item", stack_size = 50, icon = "__base__/graphics/icons/iron-plate.png" } })'
    Compress-Archive -Path $zipped -DestinationPath (Join-Path $cache 'anything.zip')
    New-Item -ItemType Directory -Path (Join-Path $cache '.zips') -Force | Out-Null

    # The check a caller would bring: it dumps the data stage through the library and requires
    # every item it is told to expect.
    $checkScript = Join-Path $temp 'check.ps1'
    @'
param($Harness, $Load)
. (Join-Path $env:LOAD_HARNESS_LIB 'load-harness-lib.ps1')
$dump = Get-Content -LiteralPath (Invoke-HarnessDump -Harness $Harness -Tag 'check') -Raw
foreach ($item in $env:LOAD_HARNESS_EXPECT -split ',') {
    if ($dump -notmatch [regex]::Escape("`"$item`"")) { Write-Host "CHECK FAILED: no $item in the dump"; exit 1 }
}
Write-Host "CHECK RAN: $($Harness.Mods.Count) mod(s), save $([bool] $Load.SavePath), expected items in the dump"
exit 0
'@ | Set-Content $checkScript
    $failingCheck = Join-Path $temp 'failing-check.ps1'
    'Write-Host "CHECK SAYS NO"; exit 3' | Set-Content $failingCheck
    $env:LOAD_HARNESS_LIB = $PSScriptRoot

    $run = {
        param([string[]] $Arguments)
        $text = (& pwsh -NoProfile -File $PSCommandPath @Arguments 2>&1 | Out-String)
        @{ Code = $LASTEXITCODE; Text = $text }
    }

    # What "the player's game" is, as path, size and write time. Logs are left out: the game
    # rewrites them whenever it runs, and it may be running.
    $userData = Join-Path $env:APPDATA 'Factorio'
    $fingerprint = {
        foreach ($p in @('mods', 'saves', 'player-data.json', 'config')) {
            $root = Join-Path $userData $p
            if (-not (Test-Path -LiteralPath $root)) { continue }
            Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue |
                ForEach-Object { "$($_.FullName)|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)" }
            if ((Get-Item -LiteralPath $root) -is [IO.FileInfo]) {
                $f = Get-Item -LiteralPath $root; "$($f.FullName)|$($f.Length)|$($f.LastWriteTimeUtc.Ticks)"
            }
        }
    }
    $userBefore = @(& $fingerprint)
    $sourceBefore = @(Get-ChildItem -LiteralPath (Join-Path $temp 'src'), $cache -Recurse -File -Force | ForEach-Object FullName)

    $cases = @(
        @{ Name = 'a good mod directory loads, and -Check runs on the loaded game'; Test = {
            $env:LOAD_HARNESS_EXPECT = 'harness-good-item'
            $r = & $run @('-Check', $checkScript, $good)
            $r.Code -eq 0 -and $r.Text -match 'CHECK RAN: 1 mod\(s\), save True' -and $r.Text -match 'OK - loaded' } }
        @{ Name = 'a zip and a cache-shaped directory load, clutter passed over'; Test = {
            $env:LOAD_HARNESS_EXPECT = 'harness-cached-item,harness-zipped-item,harness-good-item'
            $r = & $run @('-Check', $checkScript, $cache, $good)
            $r.Code -eq 0 -and $r.Text -match 'CHECK RAN: 3 mod\(s\)' -and $r.Text -match '1 zip' } }
        @{ Name = 'a broken mod fails, with the game''s own error text'; Test = {
            $r = & $run @($broken)
            $r.Code -ne 0 -and $r.Text -match 'FAILED - did not load' -and
                $r.Text -match 'Key "stack_size" not found' -and $r.Text -match 'harness-broken-item' } }
        @{ Name = 'a failing -Check fails the run'; Test = {
            $r = & $run @('-Check', $failingCheck, $good)
            $r.Code -ne 0 -and $r.Text -match 'CHECK SAYS NO' -and $r.Text -match 'FAILED - the check .* exited 3' } }
        @{ Name = 'a directory holding no mod is refused, not loaded as nothing'; Test = {
            $r = & $run @((Join-Path $cache '.zips'))
            $r.Code -ne 0 -and $r.Text -match 'holds no mods' } }
        @{ Name = 'every mod source is still there after the junctions went'; Test = {
            $after = @(Get-ChildItem -LiteralPath (Join-Path $temp 'src'), $cache -Recurse -File -Force | ForEach-Object FullName)
            $sourceBefore.Count -gt 0 -and -not (Compare-Object $sourceBefore $after) } }
        @{ Name = 'the player''s mods, saves, config and player-data.json are untouched'; Test = {
            $after = @(& $fingerprint)
            $moved = @(Compare-Object $userBefore $after)
            Write-Host "    $($userBefore.Count) file(s) watched under $userData"
            foreach ($m in $moved) { Write-Host "    $($m.SideIndicator) $($m.InputObject)" }
            -not $moved } }
    )

    $failures = 0
    $n = 0
    try {
        foreach ($c in $cases) {
            $n++
            $ok = try { [bool] (& $c.Test) } catch { Write-Host "    threw: $($_.Exception.Message)"; $false }
            Write-Host ("self-test {0}/{1}: {2} -- {3}" -f $n, $cases.Count, $c.Name, $(if ($ok) { 'ok' } else { 'FAILED' }))
            if (-not $ok) { $failures++ }
        }
    }
    finally {
        Remove-Item Env:LOAD_HARNESS_LIB, Env:LOAD_HARNESS_EXPECT -ErrorAction SilentlyContinue
        Remove-TempDirectory -Path $temp -Label 'load-harness self-test'
    }
    Write-Host ''
    if ($failures) { Write-Host "FAILED - self-test: $failures of $($cases.Count) case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all $($cases.Count) cases."
    exit 0
}

if ($SelfTest) { Invoke-SelfTest }
if (-not $Mods) { throw 'Name the mods to load: mod directories, zips, or directories of them. Or -SelfTest.' }

$h = New-LoadHarness -Mods $Mods -FactorioExe $FactorioExe -With @($With -split ',' | Where-Object { $_ })
try {
    $zips = @($h.Mods | Where-Object Kind -eq 'zip').Count
    $bundledOn = if ($h.EnabledBundled) { $h.EnabledBundled -join ', ' } else { 'none (base only)' }
    Write-Host "load-harness: $($h.Mods.Count) mod(s), $zips zip(s), bundled enabled: $bundledOn"
    Write-Host "  $(($h.Mods | ForEach-Object { "$($_.Name) $($_.Version)" }) -join ', ')"

    $load = Invoke-HarnessLoad -Harness $h
    if (-not $load.Loaded) {
        Write-Host ''
        if ($load.Code -eq 0) { Write-Host 'FAILED - did not load: Factorio exited 0 but wrote no save.' }
        else { Write-Host "FAILED - did not load: Factorio exited $($load.Code)." }
        if ($load.ErrorText) { $load.ErrorText | ForEach-Object { Write-Host "    $_" } }
        else { Write-FactorioTail $load }
        exit 1
    }

    if ($Check) {
        Write-Host "check: $Check"
        $global:LASTEXITCODE = 0
        try { & $Check -Harness $h -Load $load | Out-Host }
        catch { Write-Host ''; Write-Host "FAILED - the check $Check threw: $($_.Exception.Message)"; exit 1 }
        if ($LASTEXITCODE -ne 0) { Write-Host ''; Write-Host "FAILED - the check $Check exited $LASTEXITCODE."; exit 1 }
    }

    Write-Host ''
    Write-Host "OK - loaded: $($h.Mods.Count) mod(s) validated and a map was created$(if ($Check) { ', and the check passed' })."
    exit 0
}
finally { Remove-LoadHarness -Harness $h -Keep:$KeepTemp }
