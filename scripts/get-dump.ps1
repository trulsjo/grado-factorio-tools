<#
.SYNOPSIS
    Gives the path of a --dump-data dump of a directory of mods, making it only when the cache has
    none for that set. The path is the last line printed. Exit 0 means the path names a dump of
    the set its .key file lists.

.DESCRIPTION
    A DUMP IS KEPT, NOT THROWN AWAY (grado-factorio-modpack#148, where this was written). A dump
    of an overhaul pack takes about a minute, and measuring sessions there each made their own of
    the same sets. This makes one through the load harness's Invoke-HarnessDump and keeps it in
    the cache directory. Three files per dump:

      <name>[+<bundled>...]-<checksum>-<id>.json   the dump
      ....log                                      the game's output from the run that made it
      ....key                                      the set it is a dump of, as text

    <name> is the last part of the mod directory's path. <checksum> is the prototype list
    checksum the game prints in that log. <id> is the first twelve hex digits of the SHA-256 of
    the .key file's text.

    WHAT MAKES A SET. The .key lists the game build, the bundled mods enabled, and every enabled
    mod in the directory as name, version, directory or zip, file count and total bytes. A
    request is served from the cache only when a .key there holds exactly that text and its dump
    is still beside it. So a member at another release, a mod disabled, another bundled
    selection, another build, or a file added to or removed from a mod, is a different set and
    gets a dump of its own. A disabled mod is left out of the key, so a set with a mod disabled
    and a set without that mod are one set. The directory's path and name are not in the key: the
    same mods somewhere else are the same set.

    WHAT IT CANNOT SEE. A change inside a mod that leaves its version, file count and total bytes
    the same: the key reads sizes, not contents, because hashing would read every file of every
    mod. The mod settings: the harness loads every mod at its defaults. And whether the directory
    is what its owner meant it to hold: it is dumped as it stands.

    IT WRITES NOTHING UNDER THE MOD DIRECTORY, and no info.json. The self-test measures that
    against a stand-in for the game. For a real run it is read from the harness's source, not
    measured: the mods are junctioned or copied into a temp directory, and the game writes there.
    Keep the cache outside the mod directory, and out of git.

    TO CLEAR IT, delete the cache directory, or the three files of one dump.

.PARAMETER Mods
    The directory of mods to dump, as load-harness.ps1 takes one: mod directories and zips.

.PARAMETER With
    Bundled mods to enable, comma-separated, e.g. -With space-age. Dependencies are pulled in.
    Without it the dump is base only.

.PARAMETER Disabled
    Mods in the directory to load disabled, comma-separated, in exact case. A name that is not
    there is refused.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults as load-harness.ps1 does.

.PARAMETER CacheDirectory
    Where the dumps are kept. Defaults to .dump-cache under the current directory, as
    fetch-mods.ps1's cache defaults to .mod-cache there.

.PARAMETER SelfTest
    Prove a second request is served from the cache and a changed set is not, against fixture
    mods in a temp directory and a stand-in for the game. No network and no game.

.EXAMPLE
    pwsh -File scripts/get-dump.ps1 .mod-cache/Grado_ABC

.EXAMPLE
    pwsh -File scripts/get-dump.ps1 .mod-cache/Grado_ABCS -With space-age -Disabled Grado_ABCS
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [Parameter(Position = 0)] [string] $Mods,
    [string] $With,
    [string] $Disabled,
    [string] $FactorioExe,
    [string] $CacheDirectory,
    [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'load-harness-lib.ps1')

function Get-CachedDump {
    <#  The path of a dump of the mods in $ModsDirectory less $Disabled, from $CacheDirectory if a
        dump of that set is there. Otherwise $Make is called with a directory, into which it writes
        dump.json and dump.log, and the dump is kept. The .key is written last, so a run that stops
        half-way leaves nothing a later request is served.  #>
    param(
        [Parameter(Mandatory)] [string] $ModsDirectory,
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Build,
        [Parameter(Mandatory)] [string] $CacheDirectory,
        [Parameter(Mandatory)] [scriptblock] $Make,
        [string[]] $Bundled = @(),
        [string[]] $Disabled = @()
    )

    $rows = @(Get-HarnessMods -Path $ModsDirectory)
    # Refused, because the set is keyed by what is enabled: a misspelt name would disable nothing
    # and be served the whole set's dump.
    $unknown = @($Disabled | Where-Object { $_ -cnotin $rows.Name })
    if ($unknown) { throw "Not in ${ModsDirectory}: $($unknown -join ', '). Names match case exactly." }

    $key = @(
        "factorio $Build"
        "bundled $(($Bundled | Sort-Object) -join ',')"
        foreach ($r in $rows | Where-Object { $_.Name -cnotin $Disabled }) {
            # ponytail: sizes, not contents. An edit that keeps the count and the bytes is not seen;
            # hash the files if mods ever get edited in place.
            $size = Get-ChildItem -LiteralPath $r.Path -Recurse -File -Force | Measure-Object Length -Sum
            "$($r.Name) $($r.Version) $($r.Kind), $($size.Count) file(s), $([long] $size.Sum) bytes"
        }
    ) -join "`n"
    $id = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($key))).Substring(0, 12).ToLower()

    $kept = Get-ChildItem -LiteralPath $CacheDirectory -Filter "*-$id.key" -ErrorAction SilentlyContinue |
        Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -ceq $key } |
        ForEach-Object { [IO.Path]::ChangeExtension($_.FullName, '.json') } |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($kept) { Write-Host "get-dump: served from the cache, nothing run"; return $kept }

    $work = Join-Path $CacheDirectory ".making-$id"
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    try {
        & $Make $work | Out-Null
        $checksum = Select-String -LiteralPath (Join-Path $work 'dump.log') -Pattern 'Prototype list checksum: (\d+)' |
            Select-Object -Last 1 | ForEach-Object { $_.Matches[0].Groups[1].Value }
        if (-not $checksum) { throw "The game printed no prototype list checksum, so the dump has no name and is not kept." }
        $base = Join-Path $CacheDirectory ((@($Name) + @($Bundled | Sort-Object) -join '+') + "-$checksum-$id")
        Move-Item -LiteralPath (Join-Path $work 'dump.json') -Destination "$base.json" -Force
        Move-Item -LiteralPath (Join-Path $work 'dump.log') -Destination "$base.log" -Force
        Set-Content -LiteralPath "$base.key" -Value $key -NoNewline
    }
    finally { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host "get-dump: made, no dump of this set was in the cache"
    "$base.json"
}

function Invoke-SelfTest {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "get-dump-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    $mods = Join-Path $temp 'mods'
    $cache = Join-Path $temp 'cache'
    $putMod = {
        param($name, $version)
        New-Item -ItemType Directory -Path (Join-Path $mods $name) -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $mods "$name/info.json") -Value "{`"name`":`"$name`",`"version`":`"$version`"}" -NoNewline
    }
    & $putMod 'alpha' '1.0.0'
    & $putMod 'beta' '1.0.0'
    & $putMod 'zipped' '1.0.0'
    Compress-Archive -Path (Join-Path $mods 'zipped') -DestinationPath (Join-Path $mods 'zipped_1.0.0.zip')
    Remove-Item -LiteralPath (Join-Path $mods 'zipped') -Recurse -Force

    # The stand-in for the game: counts its runs, and prints a checksum as the game does.
    $script:runs = 0
    $script:log = '   1.234 Prototype list checksum: 4242'
    $make = {
        param($dir)
        $script:runs++
        Set-Content -LiteralPath (Join-Path $dir 'dump.json') -Value "{`"run`":$script:runs}"
        Set-Content -LiteralPath (Join-Path $dir 'dump.log') -Value $script:log
    }
    # Files only: NTFS settles a directory's own write time late, after the fixture edits below.
    $listing = { @(Get-ChildItem -LiteralPath $mods -Recurse -File -Force | ForEach-Object { "$($_.FullName)|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)" }) }
    $script:touched = $false
    # One request, returning the path and whether the game ran for it.
    $ask = {
        param([hashtable] $More = @{})
        $before = & $listing
        $ran = $script:runs
        $path = Get-CachedDump -ModsDirectory $mods -Name 'Fixture' -Build '2.0.77' -CacheDirectory $cache -Make $make @More 6>$null
        foreach ($d in Compare-Object $before (& $listing)) { $script:touched = $true; Write-Host "    $($d.SideIndicator) $($d.InputObject)" }
        @{ Path = $path; Made = $script:runs -gt $ran }
    }

    $cases = @(
        @{ Name = 'a first request makes the dump, named by directory and checksum, with its log and key beside it'; Test = {
            $script:first = & $ask
            $first.Made -and (Split-Path $first.Path -Leaf) -match '^Fixture-4242-[0-9a-f]{12}\.json$' -and
                (Test-Path ([IO.Path]::ChangeExtension($first.Path, '.log'))) -and
                (Get-Content ([IO.Path]::ChangeExtension($first.Path, '.key')) -Raw) -match '(?m)^alpha 1\.0\.0 directory, 1 file\(s\), \d+ bytes$' } }
        @{ Name = 'a second request for the same set runs nothing and gives the same path'; Test = {
            $r = & $ask
            -not $r.Made -and $r.Path -eq $first.Path } }
        @{ Name = 'a member at another release is not served the old dump'; Test = {
            & $putMod 'beta' '1.0.1'
            $r = & $ask
            $r.Made -and $r.Path -ne $first.Path } }
        @{ Name = 'a mod disabled is not served the dump of the whole set, and is served its own the second time'; Test = {
            $r = & $ask @{ Disabled = 'alpha' }
            $again = & $ask @{ Disabled = 'alpha' }
            $r.Made -and -not $again.Made -and $again.Path -eq $r.Path -and
                (Get-Content ([IO.Path]::ChangeExtension($r.Path, '.key')) -Raw) -notmatch 'alpha' } }
        @{ Name = 'a disabled name that is not there, or is there in another case, is refused'; Test = {
            $refused = foreach ($n in 'gamma', 'Alpha') { try { $null = & $ask @{ Disabled = $n }; $false } catch { $_.Exception.Message -match "Not in .*$n" } }
            -not ($refused -contains $false) } }
        @{ Name = 'another bundled selection is not served, and is in the name'; Test = {
            $r = & $ask @{ Bundled = 'space-age', 'quality' }
            $r.Made -and (Split-Path $r.Path -Leaf) -match '^Fixture\+quality\+space-age-4242-' } }
        @{ Name = 'a file added to a mod under the same version is not served the old dump'; Test = {
            Set-Content -LiteralPath (Join-Path $mods 'alpha/data.lua') -Value '-- new'
            (& $ask).Made } }
        @{ Name = 'a zip replaced by one of another size is not served the old dump'; Test = {
            Add-Content -LiteralPath (Join-Path $mods 'zipped_1.0.0.zip') -Value 'x'
            (& $ask).Made -and -not (& $ask).Made } }
        @{ Name = 'a key whose dump has gone is not served; the dump is made again'; Test = {
            $r = & $ask
            Remove-Item -LiteralPath $r.Path
            $again = & $ask
            -not $r.Made -and $again.Made -and (Test-Path -LiteralPath $again.Path) } }
        @{ Name = 'a run that prints no checksum is refused and leaves nothing to be served'; Test = {
            & $putMod 'beta' '1.0.2'
            $script:log = 'no checksum here'
            $before = @(Get-ChildItem -LiteralPath $cache -Force | ForEach-Object Name)
            $threw = try { $null = & $ask; $false } catch { $_.Exception.Message -match 'no prototype list checksum' }
            $script:log = '   1.234 Prototype list checksum: 4242'
            $threw -and -not (Compare-Object $before @(Get-ChildItem -LiteralPath $cache -Force | ForEach-Object Name)) -and (& $ask).Made } }
        @{ Name = 'no request wrote under the mod directory'; Test = { -not $script:touched } }
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
    finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host ''
    if ($failures) { Write-Host "FAILED - self-test: $failures of $($cases.Count) case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all $($cases.Count) cases."
    exit 0
}

if ($SelfTest) { Invoke-SelfTest }
if (-not $Mods) { throw 'Name the directory of mods to dump, e.g. .mod-cache/Grado_ABC. Or -SelfTest.' }

$resolve = { param($p) $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p) }
$Mods = & $resolve $Mods
if (-not (Test-Path -LiteralPath $Mods -PathType Container)) { throw "There is no directory of mods at $Mods." }
$CacheDirectory = & $resolve ($CacheDirectory ? $CacheDirectory : '.dump-cache')

$exe = Resolve-FactorioExe -Path $FactorioExe
try { $bundled = @(Resolve-BundledSelection -Requested @($With -split ',' | Where-Object { $_ }) -Bundled (Get-BundledMods -FactorioExe $exe)) }
catch { throw "-With $($_.Exception.Message)" }
$build = (Get-Content -LiteralPath (Join-Path (Get-FactorioDataDirectory -FactorioExe $exe) 'base/info.json') -Raw | ConvertFrom-Json).version
$off = @($Disabled -split ',' | Where-Object { $_ })

$path = Get-CachedDump -ModsDirectory $Mods -Name (Split-Path $Mods -Leaf) -Build $build -CacheDirectory $CacheDirectory -Bundled $bundled -Disabled $off -Make {
    param($dir)
    $h = New-LoadHarness -Mods $Mods -FactorioExe $exe -With $bundled
    try {
        try { $dump = Invoke-HarnessDump -Harness $h -Tag 'dump' -Disabled $off }
        finally { Copy-Item -LiteralPath (Join-Path $h.Temp 'dump-stdout.txt') -Destination (Join-Path $dir 'dump.log') -ErrorAction SilentlyContinue }
        Move-Item -LiteralPath $dump -Destination (Join-Path $dir 'dump.json')
    }
    finally { Remove-LoadHarness -Harness $h }
}
Write-Host "  the set it is a dump of: $([IO.Path]::ChangeExtension($path, '.key'))"
$path
exit 0
