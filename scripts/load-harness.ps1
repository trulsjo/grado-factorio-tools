<#
.SYNOPSIS
    Loads a set of mods in an isolated mod directory against a Factorio install, creates a throwaway
    map, and reports whether it loaded -- with the game's own error text when it did not. Exit 0
    means the map was created and, if -Check was given, the check passed.

.DESCRIPTION
    THE HARNESS, NOT A CHECK OF ANY ONE MOD. Moved from realistic-fusion-refreshed's load-check.ps1
    at 19e2d92 (grado-factorio-tools#16): the machinery that script ran its invariants inside. The
    invariants stayed there. This carries none, and a caller that has some brings them with -Check,
    or dot-sources load-harness-lib.ps1 and drives the load itself.

    WHAT A PASS MEANS. Every mod's prototypes validated, every dependency resolved, and a map was
    created -- which runs every mod's on_init, so a mod that refuses itself at start-up fails here
    too. Factorio exiting 0 without writing the save is a failure, not a pass.

    WHAT IT CANNOT SEE. A headless run loads no sprites or sounds, so a prototype naming a file that
    does not exist validates and the player's game still refuses to start. Two mods defining one
    prototype name load without a word -- the second replaces the first. And it runs no ticks:
    whatever breaks only once the game runs is out of reach. Those are a caller's checks to bring.

    WHAT IT REFUSES BEFORE THE GAME RUNS. A mod directory or zip whose info.json the shared reader
    refuses -- mod-info.ps1, whose header gives each refusal and its reason -- is refused with a
    message naming the info.json's path, or for a zip the entry and the zip, the same through this
    script and through Get-HarnessMods in the library. The harness uses the name before the game can
    run: a directory is junctioned in under it, and a zip is copied in as <name>_<version>.zip,
    which uses the version too. A directory's version it does not use; it is refused the same way
    because the game requires the key, and so that no mod Get-HarnessMods returns has a blank
    version, which this script prints beside the name. Without the refusal, a missing key stopped
    this script with a PowerShell error naming no mod. Through the library, from a caller without
    strict mode, a directory with no `name` also stopped with one, and a directory with no
    `version`, or a zip missing either key, went on with a blank name or version. To see the game's
    own refusal of a lone `"Name"` or `"Version"` and not this one, build the harness from a valid
    info.json and rewrite it before Invoke-HarnessLoad, as docs/measurements.md describes. A
    version's format is not checked, nor that the name matches the directory or zip it came from.
    pack-mods.ps1 checks both, because it names a zip for the portal; this loads mods from a cache
    it did not build, and what the game accepts there has not been measured.

    THE PLAYER'S GAME IS NEVER TOUCHED. The mods go into a mod directory under a temp directory, and
    Factorio runs with a write-data directory of its own there, so the player's mods, mod-list.json,
    saves and player-data.json are neither read nor written. -SelfTest asserts it.

    Bundled mods (space-age, elevated-rails, quality, recycler) live in the game's data/ directory,
    so they load unless explicitly disabled. They are disabled unless -With names them, for a
    base-only load.

.PARAMETER Mods
    What to load: mod directories, mod zips, or directories of those -- a fetch-mods.ps1 cache is
    one. The trailing arguments, so `pwsh -File` can pass several. See Get-HarnessMods in
    load-harness-lib.ps1 for what is picked up from a directory.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam path Resolve-FactorioExe
    names.

.PARAMETER With
    Bundled mods to enable, comma-separated, e.g. -With space-age. Dependencies are pulled in, so
    space-age alone is enough, and on 2.1 it brings quality, which it declares `+` (#208). An
    unknown name is refused rather than ignored.

.PARAMETER Check
    A script to run on the loaded game, called as `& <Check> -Harness $h -Load $load` after a
    successful load: $h is New-LoadHarness's object and $load is Invoke-HarnessLoad's. It can
    dot-source load-harness-lib.ps1 to dump the data stage or load again under another mod list. A
    non-zero exit or a throw fails the run.

.PARAMETER KeepTemp
    Keep the temp directory -- the save, the captured output -- for debugging. Junctions are always
    removed.

.PARAMETER SelfTest
    Prove the harness can fail and that it passes what it should, by running the game: each case
    prints its name and whether it held. Needs Factorio installed.

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

    # Each info.json $newMod writes carries an empty key, as fluid-connection-indicators 0.2.9's
    # `package` table does: valid JSON that ConvertFrom-Json refuses without -AsHashtable. So the
    # cases that load a good mod read it from a directory and from a zip, and the game is shown to
    # load it.
    $newMod = {
        param([string] $Dir, [string] $Name, [string] $Data)
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        @{ name = $Name; version = '1.0.0'; title = $Name; author = 'load-harness.ps1'
           factorio_version = '2.1'; dependencies = @('base'); package = @{ '' = '' } } | ConvertTo-Json | Set-Content (Join-Path $Dir 'info.json')
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

    # What the harness refuses before the game runs is the shared reader's to test, in
    # mod-info.ps1 -SelfTest. These two show the harness calls it, and names a directory by its
    # path and a zip by its entry and the zip. Kept out of src/ and the cache, which the cases
    # above load.
    $keyless = Join-Path $temp 'keyless'
    $putInfo = {
        param([string] $Dir, [string] $Json)
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $Dir 'info.json') -Value $Json -NoNewline
    }
    & $putInfo (Join-Path $keyless 'no-name') '{"Name":"harness-keyless","version":"1.0.0"}'
    & $putInfo (Join-Path $keyless 'stage/cut-off-zipped') '{"name":"harness-keyless",'
    Compress-Archive -Path (Join-Path $keyless 'stage/cut-off-zipped') -DestinationPath (Join-Path $keyless 'cut-off.zip')

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
    # A stand-in for a launched game: a pwsh that holds a file in -Dir open, as the game holds its
    # write-data, so the directory cannot be removed while it runs. Returned once it holds it.
    # The cases of Stop-LaunchedGame that use it are true-nukes-refreshed's
    # scripts/tests/probe-runner-cleanup.ps1 cases throws, warnstop, keep, normal and stop's
    # first half, at 916074c, adapted by Truls's ruling on #351; its others test that runner.
    $standIn = {
        param([string] $Dir)
        $held = Join-Path $Dir 'held.txt'
        $p = Start-Process pwsh -PassThru -WindowStyle Hidden -ArgumentList '-NoProfile', '-Command',
            "`$f = [IO.File]::Open('$held', 'OpenOrCreate', 'ReadWrite', 'None'); Start-Sleep -Seconds 300"
        $end = (Get-Date).AddSeconds(30)
        while ((Get-Date) -lt $end) {
            if (Test-Path -LiteralPath $held) {
                try { [IO.File]::Open($held, 'Open', 'Read', 'ReadWrite').Dispose() } catch { return $p }
            }
            Start-Sleep -Milliseconds 100
        }
        $p.Kill()
        throw "the stand-in game never held $held"
    }
    # A game Stop-LaunchedGame cannot tell from a Process: its kill can fail, and its exit can
    # come after the kill only on the wait, or never, which no real process does on demand.
    $fakeGame = {
        param([bool] $KillFails, [bool] $GoneByFailure, [bool] $Exits = $true, [bool] $Exited)
        $g = [pscustomobject] @{ Id = 99999; Exited = $Exited; Exits = $Exits; KillFails = $KillFails; GoneByFailure = $GoneByFailure; Killed = 0; Waited = @() }
        $g | Add-Member -MemberType ScriptProperty -Name HasExited -Value { $this.Exited }
        $g | Add-Member -MemberType ScriptMethod -Name Kill -Value {
            $this.Killed++
            if ($this.KillFails) { if ($this.GoneByFailure) { $this.Exited = $true }; throw 'the kill failed' }
        }
        $g | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value {
            param([int] $Milliseconds)
            $this.Waited += $Milliseconds
            if ($this.Exits) { $this.Exited = $true }
            $this.Exits
        }
        $g
    }
    $failingCheck = Join-Path $temp 'failing-check.ps1'
    'Write-Host "CHECK SAYS NO"; exit 3' | Set-Content $failingCheck
    $env:LOAD_HARNESS_LIB = $PSScriptRoot

    $run = {
        param([string[]] $Arguments)
        $text = (& pwsh -NoProfile -File $PSCommandPath @Arguments 2>&1 | Out-String)
        @{ Code = $LASTEXITCODE; Text = $text }
    }

    # Each row is a path under $keyless and what the refusal must say. True when every one is
    # refused through the library naming the path, and through the entry point in the same words
    # before any mod is listed.
    $refusedByPath = {
        param([object[]] $Rows)
        $all = foreach ($k in $Rows) {
            $path = Join-Path $keyless $k[0]
            $viaLibrary = try { Get-HarnessMods -Path $path | Out-Null; '' } catch { $_.Exception.Message }
            $r = & $run @($path)
            Write-Host "    $viaLibrary"
            $viaLibrary -match [regex]::Escape($path) -and
                -not ($k | Select-Object -Skip 1 | Where-Object { $viaLibrary -notmatch [regex]::Escape($_) }) -and
                $r.Code -ne 0 -and $r.Text -notmatch 'load-harness: \d+ mod' -and
                # The entry point's error is wrapped to the console's width, each further line
                # behind a bar; the library's is not.
                ($r.Text -replace '[\s|]', '').Contains(($viaLibrary -replace '[\s|]', ''))
        }
        -not ($all -contains $false)
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
        }
    }
    $userBefore = @(& $fingerprint)
    $sourceBefore = @(Get-ChildItem -LiteralPath (Join-Path $temp 'src'), $cache -Recurse -File -Force | ForEach-Object FullName)

    # A case passes on one output, $true (#419). Any other output fails it, saying
    # why: [bool] of two values or more is true whatever they are, so a case that
    # leaked a line passed on a false verdict.
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
    $cases = @(
        @{ Name = $leakCase; Test = { $null; $false } }
        @{ Name = 'a case passes on one $true; two values, a string or none fail it, and say so (#419)'; Test = {
            (& $judgeCase { $true }) -eq $true -and (& $judgeCase { $false }) -eq $false -and
                "$(& $judgeCase { $null; $true } 6>&1)" -ceq '    gave 2 values, not one [bool] False' -and
                "$(& $judgeCase { 'x' } 6>&1)" -ceq '    gave String, not a [bool] False' -and "$(& $judgeCase { } 6>&1)" -ceq '    gave 0 values, not one [bool] False' }}
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
        @{ Name = 'an info.json the shared reader refuses is refused before the game runs, by path or by entry and zip, the same through the library'; Test = {
            & $refusedByPath @(@('no-name', 'has no "name" key, which the game requires'),
                @('cut-off.zip', 'cut-off-zipped/info.json in ', 'is not JSON: ')) } }
        @{ Name = 'Get-ModLinks maps each name to its directory under the root, and refuses a missing one'; Test = {
            $links = Get-ModLinks -Root (Join-Path $temp 'src') -Mods 'harness-good', 'harness-broken'
            $missing = try { Get-ModLinks -Root (Join-Path $temp 'src') -Mods 'harness-good', 'no-such-mod' | Out-Null; '' } catch { $_.Exception.Message }
            $links.PSBase.Count -eq 2 -and $links['harness-good'] -eq $good -and $missing -match 'Mod directory not found: .*no-such-mod' } }
        @{ Name = 'Get-LocaleFailure finds an engine error inside a value, a foreign placeholder unless -EngineOnly, and nothing in a name or in no value'; Test = {
            (Get-LocaleFailure 'Canary Unknown key: "item-name.x"') -ceq 'Unknown key:' -and
                (Get-LocaleFailure 'a [Unknown control sequence: X] b' -EngineOnly) -ceq 'Unknown control sequence:' -and
                (Get-LocaleFailure 'Something went wrong') -ceq 'Something went wrong' -and
                $null -eq (Get-LocaleFailure 'Something went wrong' -EngineOnly) -and
                $null -eq (Get-LocaleFailure 'unknown key: lower case is not the engine''s') -and
                $null -eq (Get-LocaleFailure 'Iron plate') -and $null -eq (Get-LocaleFailure '') -and $null -eq (Get-LocaleFailure $null) } }
        @{ Name = 'Invoke-FactorioStep returns the captured stdout of a run that exits 0, and throws naming the tag of one that does not'; Test = {
            $h = New-LoadHarness -Mods $good
            try {
                $out = Invoke-FactorioStep -FactorioExe $h.FactorioExe -ModDirectory $h.ModDirectory -Arguments @('--version') -OutputDirectory $h.Temp -Tag 'step-ok'
                $said = try { Invoke-FactorioStep -FactorioExe $h.FactorioExe -ModDirectory $h.ModDirectory -Arguments @('--no-such-option') -OutputDirectory $h.Temp -Tag 'step-bad' 6>$null | Out-Null; '' } catch { $_.Exception.Message }
                Write-Host "    $said"
                (Test-Path -LiteralPath $out) -and (Get-Content -LiteralPath $out -Raw) -match 'Version: \d' -and $said -match "Factorio exited \d+ during 'step-bad'" }
            finally { Remove-LoadHarness -Harness $h } } }
        @{ Name = 'Find-MissingAssets reports a missing file of base, of core, of a stripe and of a mapped mod once, passes a file there, a stripes sprite''s own filename and an unmapped mod, and throws on a missing dump'; Test = {
            $assets = Join-Path $temp 'assets/harness-assets'
            New-Item -ItemType Directory -Path $assets -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $assets 'stripe.png') -Value 'not a picture'
            $dump = Join-Path $temp 'assets/dump.json'
            @{
                item   = @{ a = @{ icon = '__base__/graphics/icons/iron-plate.png'; pictures = @(@{ filename = '__harness-assets__/no-such.png' }) } }
                sprite = @{ s = @{ filename = '__harness-assets__/never-opened.png'; stripes = @(@{ filename = '__harness-assets__/stripe.png' }, @{ filename = '__harness-assets__/no-such-stripe.png' }) } }
                other  = '__harness-unmapped__/x.png'
                again  = @('__harness-assets__/no-such.png')
                # The header's own failure: a file of base not there, and one of core.
                game   = @('__base__/graphics/icons/no-such-base.png', '__core__/graphics/no-such-core.png', '__core__/graphics/arrows/no-such-arrow.png')
            } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $dump
            $found = @(Find-MissingAssets -DumpPath $dump -DataDir (Get-FactorioDataDirectory -FactorioExe (Resolve-FactorioExe)) -ModDirectories @{ 'harness-assets' = $assets })
            foreach ($f in $found) { Write-Host "    $($f.Mod) $($f.Reference)" }
            $noDump = try { Find-MissingAssets -DumpPath (Join-Path $temp 'assets/no-dump.json') -DataDir $temp -ModDirectories @{} | Out-Null; '' } catch { $_.Exception.Message }
            $want = '__base__/graphics/icons/no-such-base.png|base', '__core__/graphics/arrows/no-such-arrow.png|core', '__core__/graphics/no-such-core.png|core',
                '__harness-assets__/no-such-stripe.png|harness-assets', '__harness-assets__/no-such.png|harness-assets'
            $got = @($found | ForEach-Object { "$($_.Reference)|$($_.Mod)" })
            $got.Count -eq $want.Count -and -not (Compare-Object $want $got -CaseSensitive) -and $noDump -match 'no data dump' } }
        @{ Name = 'Find-MissingAssets finds, in a real dump, an icon path a prototype builds by joining strings, and passes the base icon beside it'; Test = {
            $canary = Join-Path $temp 'assets/harness-canary'
            & $newMod $canary 'harness-canary' ('local D = "__harness-canary__/graphics/"' + "`n" +
                'data:extend({ { type = "item", name = "harness-canary-item", stack_size = 1, icon = D .. "no-such-icon" .. ".png", icon_size = 64 },' +
                ' { type = "item", name = "harness-canary-plate", stack_size = 1, icon = "__base__/graphics/icons/iron-plate.png" } })')
            $h = New-LoadHarness -Mods $canary
            try {
                $dumped = Invoke-HarnessDump -Harness $h -Tag 'assets'
                $found = @(Find-MissingAssets -DumpPath $dumped -DataDir (Get-FactorioDataDirectory -FactorioExe $h.FactorioExe) -ModDirectories @{ 'harness-canary' = $canary })
                foreach ($f in $found) { Write-Host "    $($f.Reference)" }
                $found.Count -eq 1 -and $found[0].Reference -ceq '__harness-canary__/graphics/no-such-icon.png' }
            finally { Remove-LoadHarness -Harness $h } } }
        @{ Name = 'Stop-LaunchedGame kills a game holding a file in its harness, waits until it has gone, and removes the harness, junctions first'; Test = {
            $h = New-LoadHarness -Mods $good
            $p = & $standIn $h.Temp
            Stop-LaunchedGame -Process $p -Label 'self-test' -Harness $h
            $p.HasExited -and -not (Test-Path -LiteralPath $h.Temp) -and (Test-Path -LiteralPath (Join-Path $good 'info.json')) } }
        @{ Name = 'Stop-LaunchedGame, with a game it could not close and a caller''s $WarningPreference of Stop, leaves the harness without junctions, names it in a warning, and lets the caller''s own error through'; Test = {
            $h = New-LoadHarness -Mods $good
            $p = & $standIn $h.Temp
            try {
                $WarningPreference = 'Stop'
                $warned = [System.Collections.Generic.List[string]]::new()
                $said = try { try { throw 'the caller''s own error' } finally { Stop-LaunchedGame -Label 'self-test' -Harness $h 3>&1 | ForEach-Object { $warned.Add("$_") } } } catch { $_.Exception.Message }
                $WarningPreference = 'Continue'
                $linked = @(Get-ChildItem -LiteralPath $h.ModDirectory -Directory -Force -ErrorAction SilentlyContinue | Where-Object LinkType -eq 'Junction')
                foreach ($w in $warned) { Write-Host "    warned: $w" }
                $said -ceq 'the caller''s own error' -and (Test-Path -LiteralPath $h.Temp) -and -not $linked -and
                    [bool] ($warned -match [regex]::Escape($h.Temp)) }
            finally { $p.Kill(); $p.WaitForExit(); Remove-TempDirectory -Path $h.Temp -Label 'self-test' } } }
        @{ Name = 'Stop-LaunchedGame waits two minutes for a killed game to go, warns naming its pid where it has not, under a caller''s $WarningPreference of Stop too, and kills no game that has gone'; Test = {
            $gone = & $fakeGame
            Stop-LaunchedGame -Process $gone -Label 'self-test' 3>&1 | ForEach-Object { Write-Host "    warned: $_" }
            $stuck = & $fakeGame -Exits $false
            $warned = @(Stop-LaunchedGame -Process $stuck -Label 'self-test' 3>&1 | ForEach-Object { "$_" })
            $already = & $fakeGame -Exited $true
            Stop-LaunchedGame -Process $already -Label 'self-test'
            # The same warning in a caller's finally under $WarningPreference = 'Stop': written,
            # not thrown, so the caller's own error is the one that comes out.
            $stuckUnderStop = & $fakeGame -Exits $false
            $stopWarned = [System.Collections.Generic.List[string]]::new()
            try {
                $WarningPreference = 'Stop'
                $callerSaid = try { try { throw 'the caller''s own error' } finally { Stop-LaunchedGame -Process $stuckUnderStop -Label 'self-test' 3>&1 | ForEach-Object { $stopWarned.Add("$_") } } } catch { $_.Exception.Message }
            }
            finally { $WarningPreference = 'Continue' }
            foreach ($w in @($warned) + @($stopWarned)) { Write-Host "    warned: $w" }
            Write-Host "    under Stop, the caller got: $callerSaid"
            $gone.HasExited -and $gone.Killed -eq 1 -and "$($gone.Waited)" -eq '120000' -and
                $warned.Count -eq 1 -and $warned[0] -match 'pid 99999' -and $warned[0] -match 'two minutes' -and
                $already.Killed -eq 0 -and $already.Waited.Count -eq 0 -and
                $callerSaid -ceq 'the caller''s own error' -and $stopWarned.Count -eq 1 -and $stopWarned[0] -match 'two minutes' } }
        @{ Name = 'Stop-LaunchedGame lets a failed kill pass where the game went meanwhile, and throws it where the game still runs, after removing the harness'; Test = {
            $raced = & $fakeGame -KillFails $true -GoneByFailure $true
            $racedSaid = try { Stop-LaunchedGame -Process $raced -Label 'self-test'; '' } catch { $_.Exception.Message }
            $h = New-LoadHarness -Mods $good
            $running = & $fakeGame -KillFails $true
            $runningSaid = try { Stop-LaunchedGame -Process $running -Label 'self-test' -Harness $h; '' } catch { $_.Exception.Message }
            Write-Host "    raced: '$racedSaid'; running: '$runningSaid'"
            -not $racedSaid -and $runningSaid -match 'the kill failed' -and -not (Test-Path -LiteralPath $h.Temp) } }
        @{ Name = 'Stop-LaunchedGame -Keep keeps the harness directory and its files, never the junctions'; Test = {
            $h = New-LoadHarness -Mods $good
            $p = & $standIn $h.Temp
            try {
                Stop-LaunchedGame -Process $p -Label 'self-test' -Harness $h -Keep | Out-Null
                $linked = @(Get-ChildItem -LiteralPath $h.ModDirectory -Directory -Force -ErrorAction SilentlyContinue | Where-Object LinkType -eq 'Junction')
                $p.HasExited -and (Test-Path -LiteralPath (Join-Path $h.Temp 'held.txt')) -and -not $linked }
            finally { Remove-LoadHarness -Harness $h } } }
        @{ Name = 'Stop-LaunchedGame in a finally block, the run stopped while its game runs as Ctrl+C stops it, leaves no game running and no harness'; Test = {
            $mark = Join-Path $temp 'stopped.mark'
            $ps = [powershell]::Create()
            [void] $ps.AddScript({
                param($Lib, $Mod, $Mark, $StandIn)
                . $Lib
                $h = New-LoadHarness -Mods $Mod
                $p = $null
                try {
                    $p = & ([scriptblock]::Create($StandIn)) $h.Temp  # strict-lists: one
                    Set-Content -LiteralPath $Mark -Value "$($h.Temp)|$($p.Id)"
                    Start-Sleep -Seconds 120
                }
                finally { Stop-LaunchedGame -Process $p -Label 'stopped' -Harness $h }
            }).AddArgument((Join-Path $PSScriptRoot 'load-harness-lib.ps1')).AddArgument($good).AddArgument($mark).AddArgument($standIn.ToString())
            $async = $ps.BeginInvoke()
            $end = (Get-Date).AddSeconds(90)
            while (-not (Test-Path -LiteralPath $mark) -and -not $async.IsCompleted -and (Get-Date) -lt $end) { Start-Sleep -Milliseconds 200 }
            $running = -not $async.IsCompleted
            $ps.Stop()
            $ps.Dispose()
            if (-not (Test-Path -LiteralPath $mark)) { Write-Host '    the run never reached its game'; return $false }
            $harnessTemp, $gameId = (Get-Content -LiteralPath $mark -Raw).Trim() -split '\|'
            $alive = [bool] (Get-Process -Id ([int] $gameId) -ErrorAction SilentlyContinue)
            $running -and -not $alive -and -not (Test-Path -LiteralPath $harnessTemp) } }
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
            $ok = try { & $judgeCase $c.Test } catch { Write-Host "    threw: $($_.Exception.Message)"; $false }
            if ($c.Name -ceq $leakCase) { $ok = -not $ok }
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
