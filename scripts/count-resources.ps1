<#
.SYNOPSIS
    Creates a map of a set of mods at a seed, runs it 700 ticks with the grado-count mod, and
    copies out the resource counts it wrote. Exit 0 means the map was created, both runs of the
    game exited 0, the counts were copied, and no mod directory changed while it ran.

.DESCRIPTION
    WHAT IT DOES. Builds a harness (load-harness-lib.ps1) of -Mods and a copy of scripts/grado-count
    whose config.lua holds -Radius and whether to create every planet's surface, creates a map with
    --create and --map-gen-seed, and runs --benchmark on it for 700 ticks. Into -OutDirectory it
    writes, each named after -Name:

        <Name>.json                what grado-count wrote; its header says what that holds
        <Name>-create-stdout.txt   the game's stdout for --create
        <Name>-bench-stdout.txt    the game's stdout for --benchmark
        <Name>-mods.json           the mods the harness resolved: name, version, kind and path
        <Name>-fingerprint.txt     files and bytes of each mod directory, before and after

    compare-resource-counts.ps1 reads the first. From the throwaway driver of
    trulsjo/grado-factorio-modpack#307 (grado-factorio-tools#161).

    WHY THE FINGERPRINT. The harness junctions a mod directory in, so the game runs on the
    directory itself, and grado-factorio-modpack#307's runs were on that repository's fetched
    cache. A directory that changed between before and after fails the run, and the counts are
    still copied; so does a --benchmark that exits non-zero after grado-count wrote them.

    WHAT IT CANNOT SEE. A change to a mod directory that keeps its file count and its bytes, or a
    change to a zip. A mod path with a comma in it: -Mods is split on commas. Which mods a set
    should hold: the caller passes the list. What the counts mean: that is
    compare-resource-counts.ps1's, and what grado-count cannot see is in its control.lua. It has
    no -SelfTest; it needs the game, and a run of it is its check.

.PARAMETER Mods
    Mod directories, mod zips, or directories of them, as load-harness.ps1 takes,
    comma-separated. None counts the game alone.

.PARAMETER Seed
    The map seed, for --map-gen-seed.

.PARAMETER Name
    What the files written are named after.

.PARAMETER OutDirectory
    Where they are written. Made if missing.

.PARAMETER Radius
    The chunks counted around each surface's origin chunk: a square of 2 * Radius + 1 a side.

.PARAMETER NoPlanets
    Count the surfaces the map has at start, and create no planet's surface. With Space Age that
    is Nauvis alone.

.PARAMETER With
    Bundled mods to enable, comma-separated, as load-harness.ps1 takes: space-age, or
    space-age,quality.

.PARAMETER FactorioExe
    As load-harness.ps1 takes it.

.EXAMPLE
    pwsh -File scripts/count-resources.ps1 .mod-cache/Grado_ABCS -With space-age -Seed 140140 `
        -Radius 48 -NoPlanets -Name abcs-r48 -OutDirectory counts
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [Parameter(Position = 0)] [string[]] $Mods = @(),
    [Parameter(Mandatory)] [uint32] $Seed,
    [Parameter(Mandatory)] [string] $Name,
    [Parameter(Mandatory)] [string] $OutDirectory,
    [ValidateRange(0, 1000)] [int] $Radius = 24,
    [switch] $NoPlanets,
    [string[]] $With = @(),
    [string] $FactorioExe
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'load-harness-lib.ps1')

# Under pwsh -File a comma list arrives as one string.
$Mods = @($Mods | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$With = @($With | ForEach-Object { $_ -split ',' } | Where-Object { $_ })

function Get-Fingerprint([string] $Root) {
    $files = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force)
    '{0} files, {1} bytes' -f $files.Count, [long]($files | Measure-Object Length -Sum).Sum
}

New-Item -ItemType Directory -Force $OutDirectory | Out-Null
$out = { param($suffix) Join-Path $OutDirectory "$Name$suffix" }

# Each directory -Mods names, a mod or a directory of mods: what the harness junctions in, or holds
# it.
$directories = @(foreach ($p in $Mods) {
    $item = Get-Item -LiteralPath $p
    if ($item -isnot [IO.DirectoryInfo]) { continue }
    $item.FullName
})
$before = @($directories | ForEach-Object { "$_`t$(Get-Fingerprint $_)" })

$counter = Join-Path ([IO.Path]::GetTempPath()) ('grado-count-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'grado-count') -Destination $counter -Recurse
"return { radius = $Radius, create_planets = $((-not $NoPlanets).ToString().ToLower()) }" |
    Set-Content -LiteralPath (Join-Path $counter 'config.lua') -Encoding utf8

$failed = $null
$h = $null
try {
    $h = New-LoadHarness -Mods (@($Mods) + $counter) -With $With -FactorioExe $FactorioExe
    Write-ModList -ModDirectory $h.ModDirectory -Bundled $h.Bundled -EnabledBundled $h.EnabledBundled -Mods @($h.Mods.Name)
    ConvertTo-Json -InputObject @($h.Mods | Where-Object Path -ne $counter | Select-Object Name, Version, Kind, Path) |
        Set-Content -LiteralPath (& $out '-mods.json') -Encoding utf8
    $save = Join-Path $h.Temp 'map.zip'
    $create = Invoke-Factorio -FactorioExe $h.FactorioExe -ModDirectory $h.ModDirectory `
        -Arguments @('--create', $save, '--map-gen-seed', "$Seed") -OutputDirectory $h.Temp -Tag 'create'
    Copy-Item -LiteralPath $create.OutFile -Destination (& $out '-create-stdout.txt') -Force
    if ($create.Code -ne 0 -or -not (Test-Path -LiteralPath $save)) {
        Write-FactorioTail $create
        $failed = "--create exited $($create.Code) and $(if (Test-Path -LiteralPath $save) { 'wrote' } else { 'wrote no' }) save"
    }
    else {
        $bench = Invoke-Factorio -FactorioExe $h.FactorioExe -ModDirectory $h.ModDirectory `
            -Arguments @('--benchmark', $save, '--benchmark-ticks', '700', '--benchmark-runs', '1') -OutputDirectory $h.Temp -Tag 'bench'
        Copy-Item -LiteralPath $bench.OutFile -Destination (& $out '-bench-stdout.txt') -Force
        $json = Join-Path $h.Temp 'write-data/script-output/grado-count.json'
        if (Test-Path -LiteralPath $json) { Copy-Item -LiteralPath $json -Destination (& $out '.json') -Force }
        if ($bench.Code -ne 0 -or -not (Test-Path -LiteralPath $json)) {
            Write-FactorioTail $bench
            $failed = "--benchmark exited $($bench.Code) and grado-count $(if (Test-Path -LiteralPath $json) { 'wrote' } else { 'wrote no' }) counts"
        }
    }
}
finally {
    if ($h) { Remove-LoadHarness -Harness $h }
    Remove-Item -LiteralPath $counter -Recurse -Force -ErrorAction SilentlyContinue
}

$after = @($directories | ForEach-Object { "$_`t$(Get-Fingerprint $_)" })
@('before') + $before + @('after') + $after | Set-Content -LiteralPath (& $out '-fingerprint.txt') -Encoding utf8
$changed = @(for ($i = 0; $i -lt $before.Count; $i++) { if ($before[$i] -ne $after[$i]) { $directories[$i] } })
if ($changed) { $failed = (@($failed) + "a mod directory changed while it ran: $($changed -join ', ')" | Where-Object { $_ }) -join '; ' }

if ($failed) { Write-Host "FAILED - count-resources: $failed."; exit 1 }
Write-Host "OK - count-resources: counted $Name at seed $Seed, radius $Radius$(if ($NoPlanets) { ', no planets created' }), into $(& $out '.json')."
exit 0
