<#
.SYNOPSIS
    Resolves a modpack's mandatory closure to the exact releases a given game build would install,
    and checks that those releases satisfy each other. Exit 0 means every member resolved and no
    constraint between the picks is violated.

.DESCRIPTION
    A CHECK, run before every pack release. A pack names its members without versions, so each
    member is served its newest release for the declared line -- and when a member publishes a
    release with a higher `base` floor, the pack's declared minimum silently stops being true.
    Ruled on grado-factorio-modpack#16, 2026-09-24.

    THE METHOD is grado-factorio-modpack's docs/porting-notes.md, "Resolves on stable 2.0.77":

      pick     For each mod, its newest release whose factorio_version equals -Line and whose
               `base` constraint -Build satisfies. Newest by version number, which is what the
               mod manager installs.
      walk     The mandatory closure from those picks: every dependency with no prefix or a `~`
               prefix. `?`, `(?)` and `!` are not followed. The game's own mods -- base,
               space-age, quality, elevated-rails -- are left out: they come with the build, not
               the portal.
      check    Every dependency line of every member of a pack's closure, against the other
               members: a mandatory version constraint, a `!` incompatibility, and a version range
               on an optional dependency whose mod is in the closure.

    PER PACK, NOT AS ONE UNION. Each pack given is resolved and checked as the closure a player of
    that pack installs, so the ABCX/ABCS pair, which declare opposite answers on space-age, cannot
    flag each other. A pack named by another pack is taken from the -InfoJson files given rather
    than the portal, so its own dependencies are walked as part of the closure above it.

    THE EFFECTIVE FLOOR of a pack is the highest `base >=` among its picks. The pack's own declared
    `base` minimum is printed beside it, and a declaration below the floor is reported -- but it is
    not counted as a failure: the packs' minimums are edited on grado-factorio-modpack#16, after
    this script re-measures them.

    WHAT IT CANNOT SEE. It reads portal metadata and loads nothing: two releases whose declarations
    agree can still fail together in game, which is the load harness's question. It assumes the
    mod manager takes the newest qualifying release. It does not check a game mod's constraints
    beyond `base`, and it does not read a mod's `!` against a game mod (SpaceX's `! space-age` is
    the designed ABCX/ABCS split). A dependency prefix Factorio does not define -- `+` has been
    seen in the wild -- is read as part of the name, so it is reported as a mod the portal does
    not know rather than silently dropped.

.PARAMETER InfoJson
    One or more pack info.json paths: a pack plus the packs it depends on. Each is reported. The
    trailing arguments, so `pwsh -File` can pass several.

.PARAMETER Line
    The declared line, `2.0` or `2.1`. A release qualifies only if its factorio_version is exactly
    this.

.PARAMETER Build
    The game build the pack must install on, e.g. `2.0.77`.

.PARAMETER PinFile
    Where to write the pinned list: a .psd1 of one set per pack, named after the pack --
    `@{ Sets = @{ <pack> = @( @{ Name = ...; Version = ... } ) } }`. Each entry has the shape of an
    entry in fetch-mods.ps1's $MOD_SETS in realistic-fusion-refreshed, which holds its pins inside
    the script rather than reading a file; this is the file it is to read once it moves here
    (grado-factorio-tools#15). Optional; without it only the report is printed.

.PARAMETER PortalBaseUrl
    The mod portal's base URL. Only /api/mods/<name>/full is read, which needs no login.

.PARAMETER SelfTest
    Prove this check can fail: a table of fixture packs against an in-memory portal, each case
    naming the finding it must produce. No network.

.EXAMPLE
    pwsh -File scripts/resolve-modpack.ps1 -Line 2.0 -Build 2.0.77 -PinFile pins.psd1 `
        Grado_NonChanging/info.json Grado_ChangingBase/info.json

.EXAMPLE
    pwsh -File scripts/resolve-modpack.ps1 -SelfTest
#>

#Requires -Version 7
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(ValueFromRemainingArguments)] [string[]] $InfoJson,
    [string]   $Line,
    [string]   $Build,
    [string]   $PinFile,
    [string]   $PortalBaseUrl = 'https://mods.factorio.com',
    [switch]   $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$GAME_MODS = @('base', 'space-age', 'quality', 'elevated-rails')

function ConvertFrom-Dependency {
    <#  One info.json dependency string as Kind, Name, Op and Version. Kind is required, unordered
        (`~`), optional (`?`), hidden (`(?)`) or incompatible (`!`). Names may hold spaces, so
        the name ends where an operator starts, not at whitespace.  #>
    param([Parameter(Mandatory)] [string] $Text)

    $m = [regex]::Match($Text, '^\s*(?<prefix>\(\?\)|[?!~])?\s*(?<name>.+?)\s*(?:(?<op><=|>=|<|>|=)\s*(?<ver>\S+))?\s*$')
    $kind = switch ($m.Groups['prefix'].Value) {
        '!'   { 'incompatible' }
        '?'   { 'optional' }
        '(?)' { 'hidden' }
        '~'   { 'unordered' }
        default { 'required' }
    }
    [pscustomobject]@{
        Kind    = $kind
        Name    = $m.Groups['name'].Value
        Op      = if ($m.Groups['op'].Success) { $m.Groups['op'].Value } else { $null }
        Version = if ($m.Groups['ver'].Success) { $m.Groups['ver'].Value } else { $null }
    }
}

function ConvertTo-Version {
    <#  A version with at least three parts, so `2.0` and `2.0.0` compare equal.  #>
    param([Parameter(Mandatory)] [string] $Text)
    $parts = @($Text -split '\.')
    while ($parts.Count -lt 3) { $parts += '0' }
    [version] ($parts -join '.')
}

function Test-Constraint {
    <#  Whether $Have satisfies `<op> <want>`. No op is always satisfied.  #>
    param([Parameter(Mandatory)] [string] $Have, [string] $Op, [string] $Want)

    if (-not $Op) { return $true }
    $c = (ConvertTo-Version $Have).CompareTo((ConvertTo-Version $Want))
    switch ($Op) {
        '>=' { $c -ge 0 }
        '>'  { $c -gt 0 }
        '='  { $c -eq 0 }
        '<=' { $c -le 0 }
        '<'  { $c -lt 0 }
    }
}

function Select-Release {
    <#  The newest release on $Line whose base constraint $Build satisfies, or $null.  #>
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Releases, [string] $Line, [string] $Build)

    $qualifying = foreach ($r in $Releases) {
        if ($r.info_json.factorio_version -ne $Line) { continue }
        $ok = $true
        foreach ($d in @($r.info_json.dependencies)) {
            $dep = ConvertFrom-Dependency $d
            if ($dep.Name -eq 'base' -and $dep.Kind -ne 'incompatible' -and -not (Test-Constraint $Build $dep.Op $dep.Version)) { $ok = $false }
        }
        if ($ok) { $r }
    }
    @($qualifying) | Sort-Object { ConvertTo-Version $_.version } | Select-Object -Last 1
}

function Resolve-Packs {
    <#  Resolve and check each pack. $GetReleases is { param($name) } returning that mod's portal
        releases, or $null for a name the portal does not know -- the seam -SelfTest drives.

        Returns one row per pack: Name, Declared (its own base minimum), Floor and FloorBy, Picks
        (ordered name -> release), Violations and Unresolved (strings).  #>
    param(
        [Parameter(Mandatory)] [System.Collections.IDictionary] $Packs,
        [Parameter(Mandatory)] [scriptblock] $GetReleases,
        [Parameter(Mandatory)] [string] $Line,
        [Parameter(Mandatory)] [string] $Build
    )

    # One lookup per name across every pack: name -> @{ Release; Problem }.
    $picked = @{}
    $pick = {
        param($name)
        if (-not $picked.ContainsKey($name)) {
            $releases = & $GetReleases $name
            $picked[$name] = if ($null -eq $releases) {
                @{ Release = $null; Problem = "$name`: the portal does not know this name" }
            }
            elseif (-not ($r = Select-Release -Releases @($releases) -Line $Line -Build $Build)) {
                $have = (@($releases) | ForEach-Object { "$($_.version) ($($_.info_json.factorio_version))" }) -join ', '
                @{ Release = $null; Problem = "$name`: no release declares factorio_version $Line with a base floor $Build meets. It has: $have" }
            }
            else { @{ Release = $r; Problem = $null } }
        }
        $picked[$name]
    }

    foreach ($packName in $Packs.Keys) {
        # The closure: name -> @{ Version; Dependencies; Label }, local packs included.
        $closure = [ordered]@{}
        $unresolved = [System.Collections.Generic.List[string]]::new()
        $queue = [System.Collections.Generic.Queue[string]]::new()
        $queue.Enqueue($packName)
        while ($queue.Count) {
            $name = $queue.Dequeue()
            if ($closure.Contains($name) -or $name -in $GAME_MODS) { continue }
            if ($Packs.Contains($name)) {
                $info = $Packs[$name]
                $closure[$name] = @{ Version = $info.version; Dependencies = @($info.dependencies); Local = $true }
            }
            else {
                $p = & $pick $name
                if (-not $p.Release) {
                    if (-not $unresolved.Contains($p.Problem)) { $unresolved.Add($p.Problem) }
                    continue
                }
                $closure[$name] = @{ Version = $p.Release.version; Dependencies = @($p.Release.info_json.dependencies); Local = $false }
            }
            foreach ($d in $closure[$name].Dependencies) {
                $dep = ConvertFrom-Dependency $d
                if ($dep.Kind -in 'required', 'unordered') { $queue.Enqueue($dep.Name) }
            }
        }

        $violations = [System.Collections.Generic.List[string]]::new()
        $floor = $null; $floorBy = $null
        foreach ($name in $closure.Keys) {
            $member = $closure[$name]
            foreach ($d in $member.Dependencies) {
                $dep = ConvertFrom-Dependency $d
                if ($dep.Name -eq 'base') {
                    if (-not $member.Local -and $dep.Op -in '>=', '>' -and (-not $floor -or (ConvertTo-Version $dep.Version) -gt (ConvertTo-Version $floor))) {
                        $floor = $dep.Version; $floorBy = "$name $($member.Version)"
                    }
                    continue
                }
                if ($dep.Name -in $GAME_MODS) { continue }
                $present = $closure.Contains($dep.Name)
                $who = "$name $($member.Version) declares '$d'"
                if ($dep.Kind -eq 'incompatible') {
                    if ($present) { $violations.Add("$who, and $($dep.Name) $($closure[$dep.Name].Version) is in the closure") }
                }
                elseif ($present -and -not (Test-Constraint $closure[$dep.Name].Version $dep.Op $dep.Version)) {
                    $violations.Add("$who, but the closure has $($dep.Name) $($closure[$dep.Name].Version)")
                }
            }
        }

        $declared = @($Packs[$packName].dependencies | ForEach-Object { ConvertFrom-Dependency $_ } |
            Where-Object { $_.Name -eq 'base' -and $_.Op }) | Select-Object -First 1
        $picks = [ordered]@{}
        foreach ($name in $closure.Keys) { if (-not $closure[$name].Local) { $picks[$name] = $closure[$name].Version } }

        [pscustomobject]@{
            Name       = $packName
            Declared   = if ($declared) { $declared.Version } else { $null }
            Floor      = $floor
            FloorBy    = $floorBy
            Picks      = $picks
            Violations = @($violations)
            Unresolved = @($unresolved)
        }
    }
}

function ConvertTo-PinFile {
    <#  The pinned list: one set per pack, portal route only -- see -PinFile.  #>
    param([Parameter(Mandatory)] [object[]] $Results, [string] $Line, [string] $Build)

    $out = [System.Text.StringBuilder]::new()
    [void] $out.AppendLine("# Written by resolve-modpack.ps1 for line $Line on build $Build. Re-run it rather than editing.")
    [void] $out.AppendLine('@{')
    [void] $out.AppendLine('    Sets = @{')
    foreach ($r in $Results) {
        [void] $out.AppendLine("        '$($r.Name)' = @(")
        foreach ($name in ($r.Picks.Keys | Sort-Object)) {
            [void] $out.AppendLine("            @{ Name = '$($name -replace "'", "''")'; Version = '$($r.Picks[$name])' }")
        }
        [void] $out.AppendLine('        )')
    }
    [void] $out.AppendLine('    }')
    [void] $out.AppendLine('}')
    $out.ToString()
}

function Write-Report {
    <#  Print the per-pack report; return whether it is a pass.  #>
    param([Parameter(Mandatory)] [object[]] $Results)

    $pass = $true
    foreach ($r in $Results) {
        $floor = if ($r.Floor) { "base >= $($r.Floor) (from $($r.FloorBy))" } else { 'none declared by any pick' }
        Write-Host ''
        Write-Host "$($r.Name): $($r.Picks.Count) mods, effective floor $floor"
        if ($r.Floor -and (-not $r.Declared -or (ConvertTo-Version $r.Declared) -lt (ConvertTo-Version $r.Floor))) {
            Write-Host "  declares base >= $($r.Declared), below that floor -- the pack's minimum is not true"
        }
        foreach ($u in $r.Unresolved) { Write-Host "  UNRESOLVED  $u"; $pass = $false }
        foreach ($v in $r.Violations) { Write-Host "  VIOLATION   $v"; $pass = $false }
        if (-not $r.Unresolved -and -not $r.Violations) { Write-Host '  every member resolved, no constraint violated' }
    }
    $pass
}

function Invoke-SelfTest {
    $portal = @{
        # Newest-on-line, base-floor filter: 3.0.0 is 2.1, 2.5.0 needs a newer build, 2.4.0 wins.
        'lib'      = @(
            @{ version = '2.3.0'; info_json = @{ factorio_version = '2.0'; dependencies = @('base >= 2.0.10') } }
            @{ version = '2.4.0'; info_json = @{ factorio_version = '2.0'; dependencies = @('base >= 2.0.60') } }
            @{ version = '2.5.0'; info_json = @{ factorio_version = '2.0'; dependencies = @('base >= 2.0.80') } }
            @{ version = '3.0.0'; info_json = @{ factorio_version = '2.1'; dependencies = @('base >= 2.1.0') } })
        'content'  = @(@{ version = '1.0.0'; info_json = @{ factorio_version = '2.0'; dependencies = @(
            'base >= 2.0.20', '~ lib >= 2.0.0', '? not-installed', '(?) hidden-opt', '! enemy-of-content', 'space-age >= 2.0.0', 'mod with spaces') } })
        'mod with spaces' = @(@{ version = '0.1.0'; info_json = @{ factorio_version = '2.0'; dependencies = @() } })
        'too-new'  = @(@{ version = '1.0.0'; info_json = @{ factorio_version = '2.0'; dependencies = @('lib >= 2.5.0') } })
        'hater'    = @(@{ version = '1.0.0'; info_json = @{ factorio_version = '2.0'; dependencies = @('! lib') } })
        'picky'    = @(@{ version = '1.0.0'; info_json = @{ factorio_version = '2.0'; dependencies = @('? lib < 2.0.0', '? absent < 1.0.0') } })
        'only-2.1' = @(@{ version = '1.0.0'; info_json = @{ factorio_version = '2.1'; dependencies = @() } })
        'enemy-of-content' = @(@{ version = '1.0.0'; info_json = @{ factorio_version = '2.0'; dependencies = @() } })
    }
    $get = { param($n) if ($portal.ContainsKey($n)) { $portal[$n] } else { $null } }
    $pack = { param($name, [string[]] $deps) @{ name = $name; version = '0.1.0'; dependencies = $deps } }
    $resolve = {
        param([hashtable[]] $infos)
        $packs = [ordered]@{}
        foreach ($i in $infos) { $packs[$i.name] = $i }
        @(Resolve-Packs -Packs $packs -GetReleases $get -Line '2.0' -Build '2.0.77')
    }

    $cases = @(
        @{ Name = 'picks the newest release on the line that the build can install'; Test = {
            $r = & $resolve (& $pack 'P' @('base >= 2.0.0', 'lib'))
            $r[0].Picks['lib'] -eq '2.4.0' } }
        @{ Name = 'walks bare and ~, not ?, (?), ! or game mods; reads names with spaces'; Test = {
            $r = & $resolve (& $pack 'P' @('content'))
            (($r[0].Picks.Keys | Sort-Object) -join ',') -eq 'content,lib,mod with spaces' -and -not $r[0].Unresolved } }
        @{ Name = 'the floor is the highest base >= among the picks'; Test = {
            $r = & $resolve (& $pack 'P' @('base >= 2.0.0', 'content'))
            $r[0].Floor -eq '2.0.60' -and $r[0].FloorBy -eq 'lib 2.4.0' -and $r[0].Declared -eq '2.0.0' } }
        @{ Name = 'a mandatory version constraint the closure misses is a violation'; Test = {
            $r = & $resolve (& $pack 'P' @('too-new'))
            $r[0].Violations.Count -eq 1 -and $r[0].Violations[0] -match "too-new 1\.0\.0 declares 'lib >= 2\.5\.0'.*lib 2\.4\.0" } }
        @{ Name = 'an incompatibility with a closure member is a violation'; Test = {
            $r = & $resolve (& $pack 'P' @('hater', 'lib'))
            $r[0].Violations.Count -eq 1 -and $r[0].Violations[0] -match "declares '! lib'" } }
        @{ Name = 'an incompatibility with a mod outside the closure is not'; Test = {
            $r = & $resolve (& $pack 'P' @('content'))
            -not $r[0].Violations } }
        @{ Name = 'an optional range is checked only when its mod is in the closure'; Test = {
            $r = & $resolve (& $pack 'P' @('picky', 'lib'))
            $r[0].Violations.Count -eq 1 -and $r[0].Violations[0] -match "'\? lib < 2\.0\.0'" } }
        @{ Name = 'an unknown name and a mod with no qualifying release are both reported'; Test = {
            $r = & $resolve (& $pack 'P' @('ghost', 'only-2.1'))
            $r[0].Unresolved.Count -eq 2 -and ($r[0].Unresolved -join ' ') -match 'ghost: the portal does not know' -and
                ($r[0].Unresolved -join ' ') -match 'only-2\.1: no release declares factorio_version 2\.0' } }
        @{ Name = 'a pack named by another pack is walked locally, and each pack gets its own closure'; Test = {
            $r = & $resolve (& $pack 'Low' @('lib')), (& $pack 'High' @('Low', 'hater'))
            $r[0].Picks.Keys -join ',' -eq 'lib' -and -not $r[0].Violations -and
                (($r[1].Picks.Keys | Sort-Object) -join ',') -eq 'hater,lib' -and $r[1].Violations.Count -eq 1 } }
        @{ Name = 'the pinned list reads back as one set of Name and Version per pack'; Test = {
            $r = & $resolve (& $pack 'P' @('content'))
            $file = Join-Path ([IO.Path]::GetTempPath()) "resolve-selftest-$([guid]::NewGuid().ToString('N')).psd1"
            try {
                ConvertTo-PinFile -Results $r -Line '2.0' -Build '2.0.77' | Set-Content -LiteralPath $file -Encoding utf8
                $set = @((Import-PowerShellDataFile -LiteralPath $file).Sets['P'])
                $set.Count -eq 3 -and ($set | Where-Object { $_.Name -eq 'mod with spaces' }).Version -eq '0.1.0'
            }
            finally { Remove-Item -LiteralPath $file -ErrorAction SilentlyContinue } } }
    )

    $failures = 0
    $n = 0
    foreach ($c in $cases) {
        $n++
        $ok = try { [bool] (& $c.Test) } catch { Write-Host "    threw: $($_.Exception.Message)"; $false }
        Write-Host ("self-test {0}/{1}: {2} -- {3}" -f $n, $cases.Count, $c.Name, $(if ($ok) { 'ok' } else { 'FAILED' }))
        if (-not $ok) { $failures++ }
    }
    Write-Host ''
    if ($failures) { Write-Host "FAILED - self-test: $failures of $($cases.Count) case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all $($cases.Count) cases."
    exit 0
}

if ($SelfTest) { Invoke-SelfTest }

if (-not $InfoJson -or -not $Line -or -not $Build) { throw 'Give -InfoJson, -Line and -Build, or -SelfTest.' }

$packs = [ordered]@{}
foreach ($path in $InfoJson) {
    $info = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
    $packs[$info.name] = $info
}

$getReleases = {
    param($name)
    try { @((Invoke-RestMethod -Uri "$PortalBaseUrl/api/mods/$([uri]::EscapeDataString($name))/full" -Verbose:$false).releases) }
    catch {
        $response = $_.Exception.PSObject.Properties['Response']?.Value
        if ($response -and [int] $response.StatusCode -eq 404) { return $null }
        throw "$name`: could not read the mod portal -- $($_.Exception.Message)"
    }
}

Write-Host "resolve-modpack: line $Line on build $Build, $($packs.Count) pack(s), from $PortalBaseUrl"
$results = @(Resolve-Packs -Packs $packs -GetReleases $getReleases -Line $Line -Build $Build)
$pass = Write-Report -Results $results

if ($PinFile) {
    ConvertTo-PinFile -Results $results -Line $Line -Build $Build | Set-Content -LiteralPath $PinFile -Encoding utf8
    Write-Host ''
    Write-Host "pinned list: $PinFile"
}

$all = @($results | ForEach-Object { $_.Picks.Keys } | Sort-Object -Unique)
Write-Host ''
if (-not $pass) { Write-Host "FAILED - $($all.Count) mods resolved; see the UNRESOLVED and VIOLATION lines above."; exit 1 }
Write-Host "OK - $($all.Count) mods across $($results.Count) pack(s), every one resolved, no constraint violated."
exit 0
