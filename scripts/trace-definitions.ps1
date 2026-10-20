<#
.SYNOPSIS
    Loads a set of mods with a tracing mod that logs every data.extend, and prints, as Markdown,
    each prototype name two or more mods define, in what stage and order, and whose definition
    stands. A probe: exit 0 means the data stage ran, the tracing mod saw base define its
    prototypes, and the summary was printed, with a table of the shared names when there are any
    (trulsjo/grado-factorio-tools#173).

.DESCRIPTION
    THE TRACING MOD. This script writes it into the harness's temporary mod directory
    (load-harness-lib.ps1), and nowhere else, and it is deleted with the harness. Its name,
    $TRACER, has an empty dependencies list and sorts before `base`, so it loads after core and
    before every other mod: the game orders mods by the depth of their dependency chain, then by
    the natural sort of their names (lua-api.factorio.com/2.0.77, *Data lifecycle*), and a mod
    whose info.json has no dependencies key depends on base (*Mod structure*, same version). Its
    data.lua logs what core defined before
    it, then wraps data.extend, which data:extend calls too. The original runs unchanged after
    each call is logged. The three data stages share one Lua state, so the wrap holds for all of
    them. The game runs with --dump-data, which stops after the data stage.

    WHO DEFINED IT. Each call is logged with the mod whose stage file is running, the deepest
    mod's frame of the Lua stack, and that file's name as the stage. That mod is the definer
    (Truls, 2026-10-20, on #173). Where the frame that called data.extend is another mod's file,
    a library's, that mod is named beside it as the caller.

    MEASURED ON 2.0.77, 2026-10-20, by a run of -SelfTest on a copy of this script whose
    Invoke-Trace passes -Keep to Remove-LoadHarness, reading the kept trace-stdout.txt. The game
    loaded core, then $TRACER, then base. debug.getinfo gave each frame's source as
    `@__<mod>__/<path>`, so the calling mod and the running one are both read: tdp-e's call
    through tdp-a's lib.lua was logged as run by tdp-e and called from tdp-a. log() reached the
    game's stdout. With the wrap removed, -SelfTest stops on this script's refusal, having logged
    only core's 147.

    A SHARED NAME is a type and name that two or more mods define. A mod defining its own name
    again is not one. A name core or base defines is a base-game name: those a mod defines again
    are counted, not listed. What stands is the last definition logged.

    WHAT IT CANNOT SEE. A prototype made other than through data.extend: assigned into data.raw,
    or extended through a reference to data.extend taken before the tracing mod ran. A mod that
    replaces data.extend itself: calls after that go unlogged, or, if its replacement calls
    through, are each logged as called from that mod. A prototype a later stage changes in place,
    or deletes, which is not a definition: what stands is the last data.extend, not what data.raw
    holds at the end. A definition whose data.extend errors inside a pcall is logged all the same.
    A mod that loads before the tracing mod: one whose info.json gives an empty dependencies list
    and whose name sorts before $TRACER. A type or name holding a tab or a line break, whose line
    is not read. Anything after the data stage. And what core defines is read from data.raw as
    the tracing mod finds it, not logged as calls.

.PARAMETER Mods
    Mod directories, mod zips, or directories of them, as load-harness.ps1 takes, comma-separated.

.PARAMETER With
    Bundled mods to enable, comma-separated, as load-harness.ps1 takes: space-age.

.PARAMETER FactorioExe
    As load-harness.ps1 takes it.

.PARAMETER SelfTest
    Load fixture mods from a temp directory with the tracing mod and check what is printed, and
    read two logs written without the game. Needs the game.

.EXAMPLE
    pwsh -File scripts/trace-definitions.ps1 .mod-cache/Grado_ABCS -With space-age
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [Parameter(Position = 0)] [string[]] $Mods = @(),
    [string[]] $With = @(),
    [string] $FactorioExe,
    [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'load-harness-lib.ps1')
. (Join-Path $PSScriptRoot 'dump-lib.ps1')

# Under pwsh -File a comma list arrives as one string.
$Mods = @($Mods | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$With = @($With | ForEach-Object { $_ -split ',' } | Where-Object { $_ })

$TRACER = '0-trace-definitions'
$MARK = 'trace-definitions'

# Each line logged: the mark, then type, name, the running mod, its stage file, and the mod whose
# file made the call. Core's prototypes, there before the tracing mod, are logged as core's, in `data`.
$TRACER_DATA = @'
local mark = "@MARK@"
for type, names in pairs(data.raw) do
  for name in pairs(names) do log(table.concat({ mark, type, name, "core", "data.lua", "core" }, "\t")) end
end
local tracer = "@TRACER@"
local original = data.extend
data.extend = function(self, prototypes)
  local list = prototypes
  if self ~= data and prototypes == nil then list = self end
  local caller, runner, file
  local level = 2
  while true do
    local info = debug.getinfo(level, "S")
    if not info then break end
    local mod, path = info.source:match("^@__(.-)__/(.+)$")
    if mod and mod ~= tracer then caller = caller or mod; runner, file = mod, path end
    level = level + 1
  end
  if type(list) == "table" then
    for _, p in ipairs(list) do
      if type(p) == "table" then
        log(table.concat({ mark, tostring(p.type), tostring(p.name), tostring(runner), tostring(file), tostring(caller) }, "\t"))
      end
    end
  end
  return original(self, prototypes)
end
'@

function New-Tracer {
    <#  The tracing mod, as a mod directory under $ModDirectory.  #>
    param([Parameter(Mandatory)] [string] $ModDirectory)
    $dir = Join-Path $ModDirectory $TRACER
    New-Item -ItemType Directory -Path $dir | Out-Null
    @{ name = $TRACER; version = '1.0.0'; title = $TRACER; author = 'trace-definitions.ps1'; factorio_version = '2.0'; dependencies = @() } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $dir 'info.json')
    $TRACER_DATA.Replace('@MARK@', $MARK).Replace('@TRACER@', $TRACER) | Set-Content -LiteralPath (Join-Path $dir 'data.lua')
}

function Read-Definitions {
    <#  The tracing mod's lines out of the game's stdout, in the order logged. Throws when none is
        base's: a working tracing mod always sees base's data.extend.  #>
    param([Parameter(Mandatory)] [string] $Path)
    $pattern = "$MARK`t([^`t]*)`t([^`t]*)`t([^`t]*)`t([^`t]*)`t([^`t]*)$"
    $found = @(foreach ($line in [IO.File]::ReadLines($Path)) {
        if ($line -notmatch $pattern) { continue }
        [pscustomobject]@{ Type = $Matches[1]; Name = $Matches[2]; Mod = $Matches[3]
            Stage = $Matches[4] -replace '\.lua$'; Caller = $Matches[5] }
    })
    if (-not ($found | Where-Object Mod -ceq 'base')) {
        throw "The tracing mod logged no data.extend by base: it did not load first, or it wraps nothing. $($found.Count) line(s) logged."
    }
    $found
}

function Write-Definitions {
    <#  The summary, and a table of the shared names when there are any, from Read-Definitions'
        rows.  #>
    param([object[]] $Definitions = @())
    # Ordinal, as the game tells Foo from foo and a plain hashtable does not.
    $byName = [Collections.Specialized.OrderedDictionary]::new([StringComparer]::Ordinal)
    foreach ($d in $Definitions) {
        $key = "$($d.Type)`t$($d.Name)"
        if (-not $byName.Contains($key)) { $byName[$key] = [Collections.Generic.List[object]]::new() }
        $byName[$key].Add($d)
    }
    $shared = [Collections.Generic.List[string]]::new(); $baseRedefined = 0; $own = 0
    foreach ($key in $byName.Keys) {
        $list = $byName[$key]
        $definers = @($list.Mod | Select-Object -Unique)
        if ($definers -ccontains 'core' -or $definers -ccontains 'base') { if (@($definers | Where-Object { $_ -cnotin 'core', 'base' })) { $baseRedefined++ }; continue }
        if ($definers.Count -ge 2) { $shared.Add($key) } elseif ($list.Count -ge 2) { $own++ }
    }
    "**$($shared.Count) prototype names are defined by two or more mods.** $own more are defined twice by one mod, and $baseRedefined base-game names are defined again by a mod; neither is listed."
    if (-not $shared.Count) { return }
    ''
    # Type, then name: the tab between them sorts before any character either holds.
    $shared.Sort([StringComparer]::Ordinal)
    # A list and not a pipeline: one row out of a pipeline is unrolled into its four cells.
    $rows = [Collections.Generic.List[object]]::new()
    foreach ($key in $shared) {
        $list = $byName[$key]
        $steps = @(for ($i = 0; $i -lt $list.Count; $i++) {
            $d = $list[$i]
            $via = if ($d.Caller -cne $d.Mod) { ', through `' + $d.Caller + '`' } else { '' }
            "$($i + 1). ``$($d.Mod)`` in $($d.Stage)$via"
        })
        $rows.Add(@("``$($list[0].Name)``", "``$($list[0].Type)``", ($steps -join '; '), "``$($list[$list.Count - 1].Mod)``"))
    }
    Format-MarkdownTable 'Name', 'Type', 'Defined by, in order', 'Stands' $rows.ToArray()
}

function Invoke-Trace {
    <#  Load -Mods with the tracing mod and return Read-Definitions' rows. Throws when the game fails,
        or when the tracing mod saw no call from base.  #>
    param([string[]] $Mods = @(), [string[]] $With = @(), [string] $FactorioExe)
    $h = New-LoadHarness -Mods $Mods -With $With -FactorioExe $FactorioExe
    try {
        New-Tracer -ModDirectory $h.ModDirectory
        Write-ModList -ModDirectory $h.ModDirectory -Bundled $h.Bundled -EnabledBundled $h.EnabledBundled -Mods (@($h.Mods.Name) + $TRACER)
        $out = Invoke-FactorioStep -FactorioExe $h.FactorioExe -ModDirectory $h.ModDirectory -Arguments @('--dump-data') -OutputDirectory $h.Temp -Tag 'trace'
        Read-Definitions -Path $out
    }
    finally { Remove-LoadHarness -Harness $h }
}

function Invoke-SelfTest {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "trace-definitions-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    $item = { param($name) "{ type = `"item`", name = `"$name`", stack_size = 50, icon = `"__base__/graphics/icons/iron-plate.png`" }" }
    $newMod = {
        param([string] $Name, [hashtable] $Files)
        $dir = Join-Path $temp $Name
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        @{ name = $Name; version = '1.0.0'; title = $Name; author = 'trace-definitions.ps1'; factorio_version = '2.0'; dependencies = @('base') } |
            ConvertTo-Json | Set-Content -LiteralPath (Join-Path $dir 'info.json')
        foreach ($f in $Files.Keys) { Set-Content -LiteralPath (Join-Path $dir $f) -Value $Files[$f] }
    }
    # tdp-a and tdp-b both define tdp-shared; tdp-c defines tdp-a's tdp-cond, only when tdp-a is
    # there; tdp-d defines tdp-own twice and redefines iron-plate; tdp-e defines tdp-lib through
    # tdp-a's lib.lua, as tdp-a does.
    & $newMod 'tdp-a' @{
        'data.lua' = "data:extend({ $(& $item 'tdp-shared'), $(& $item 'tdp-cond') }); require('lib').make()"
        'lib.lua'  = "return { make = function() data:extend({ $(& $item 'tdp-lib') }) end }" }
    & $newMod 'tdp-b' @{ 'data.lua' = "data.extend({ $(& $item 'tdp-shared') })" }
    & $newMod 'tdp-c' @{ 'data-updates.lua' = "if mods['tdp-a'] then data:extend({ $(& $item 'tdp-cond') }) end" }
    & $newMod 'tdp-d' @{
        'data.lua'             = "data:extend({ $(& $item 'tdp-own') }); local p = table.deepcopy(data.raw.item['iron-plate']); p.stack_size = 99; data:extend({ p })"
        'data-final-fixes.lua' = "data:extend({ $(& $item 'tdp-own') })" }
    & $newMod 'tdp-e' @{ 'data.lua' = "require('__tdp-a__/lib').make()" }

    $userData = Join-Path $env:APPDATA 'Factorio'
    $fingerprint = {
        foreach ($p in @('mods', 'saves', 'player-data.json', 'config')) {
            $root = Join-Path $userData $p
            if (-not (Test-Path -LiteralPath $root)) { continue }
            Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue |
                ForEach-Object { "$($_.FullName)|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)" }
        }
        Get-ChildItem -LiteralPath $temp -Recurse -File -Force | ForEach-Object { "$($_.FullName)|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)" }
    }
    # Two logs of the game's form, read without it: one shared name, beside two names that differ
    # in case only; and core's lines alone, as from a tracing mod that wraps nothing.
    $logged = { param($file, [string[]] $rows) $path = Join-Path $temp $file; Set-Content -LiteralPath $path -Value @($rows | ForEach-Object { "   1.000 Script @__${TRACER}__/data.lua:22: $MARK`t$_" }); $path }
    $oneLog = & $logged 'one.txt' @("item`tplate`tbase`tdata.lua`tbase", "item`tx`ta`tdata.lua`ta", "item`tx`tb`tdata.lua`tb", "item`tFoo`tc`tdata.lua`tc", "item`tfoo`td`tdata.lua`td")
    $coreLog = & $logged 'core.txt' @("font`tdefault`tcore`tdata.lua`tcore")
    try {
        $one = @(Write-Definitions -Definitions @(Read-Definitions -Path $oneLog))
        $refused = try { Read-Definitions -Path $coreLog | Out-Null; '' } catch { $_.Exception.Message }
        $before = @(& $fingerprint)
        $found = @(Invoke-Trace -Mods $temp)
        $after = @(& $fingerprint)
        $out = (Write-Definitions -Definitions $found) -join "`n"
        $cases = [ordered]@{
            'two mods defining one name are listed, the second standing, data.extend as data:extend' =
                $out -match '\| `tdp-shared` \| `item` \| 1\. `tdp-a` in data; 2\. `tdp-b` in data \| `tdp-b` \|'
            'a mod that defines a name only when the other is loaded is listed, with its stage' =
                $out -match '\| `tdp-cond` \| `item` \| 1\. `tdp-a` in data; 2\. `tdp-c` in data-updates \| `tdp-c` \|'
            'a mod redefining its own name is counted, not listed' = $out -notmatch '`tdp-own`' -and $out -match ' 1 more are defined twice by one mod'
            'a base prototype redefined is counted, not listed, and core is counted as base' =
                $out -notmatch '`iron-plate`' -and $out -match ' 1 base-game names are defined again' -and ($found | Where-Object Mod -ceq 'core')
            'a definition through another mod''s file is the running mod''s, naming the caller' =
                $out -match '\| `tdp-lib` \| `item` \| 1\. `tdp-a` in data; 2\. `tdp-e` in data, through `tdp-a` \| `tdp-e` \|'
            'only these three names are listed' = $out -match '^\*\*3 prototype names'
            'the player''s files and the fixtures are untouched' = -not (Compare-Object $before $after)
            'one shared name is one row of four cells, and names that differ in case are two names' =
                $one[0] -match '^\*\*1 prototype names' -and @($one | Where-Object { $_ -like '|*' }).Count -eq 3 -and
                ($one -ccontains '| `x` | `item` | 1. `a` in data; 2. `b` in data | `b` |')
            'a log with no data.extend by base is refused' = $refused -match 'logged no data\.extend by base'
        }
        $failures = 0; $n = 0
        foreach ($name in $cases.Keys) {
            $n++
            Write-Host ("self-test {0}/{1}: {2} -- {3}" -f $n, $cases.Count, $name, $(if ($cases[$name]) { 'ok' } else { 'FAILED' }))
            if (-not $cases[$name]) { $failures++ }
        }
        Write-Host ''
        if ($failures) { Write-Host $out; Write-Host "FAILED - self-test: $failures of $($cases.Count) case(s) did not hold."; exit 1 }
        Write-Host "OK - self-test passed: all $($cases.Count) cases."
        exit 0
    }
    finally { Remove-TempDirectory -Path $temp -Label 'trace-definitions self-test' }
}

if ($SelfTest) { Invoke-SelfTest }
if (-not $Mods) { throw 'Name the mods to load: mod directories, zips, or directories of them. Or -SelfTest.' }
Write-Definitions -Definitions @(Invoke-Trace -Mods $Mods -With $With -FactorioExe $FactorioExe)
exit 0
