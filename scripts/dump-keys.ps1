<#
.SYNOPSIS
    Prints, as Markdown, the custom inputs of a --dump-data dump against the engine's own
    controls: which default keys an input shares with an engine control, and which inputs are
    linked to one. Exit 0 means the tables were printed. A shared default is not a clash.

.DESCRIPTION
    WHAT IT READS. One dump from get-dump.ps1, and the [controls] section of a config.ini the
    game wrote, where each control stands with its default, commented out until it is rebound
    (grado-factorio-modpack#96 and #135). With -Below, a second dump whose inputs are left out,
    so a pack is reported without the pack under it. With -Mods, the Lua of each mod directory
    there, to name the member whose source holds an input's name in quotes. It writes nothing.

    THE ENGINE'S CONTROLS are the controls in the section that are not a custom input of the
    dump. Each has a primary and an alternative slot; the controller slots are not read. A
    control that is rebound is listed, because its default is then not in the file.

    HOW KEYS ARE MATCHED. Exactly, in either slot of either side, after putting the modifiers in
    one order, reading COMMAND as CONTROL and ignoring case. One spelling is bridged: a prototype
    writes the numpad as `PAD +` and the file writes `KP_PLUS`. That bridge is an assumption for
    every key but plus and minus, which a linked input showed to agree (#135).

    WHAT IT CANNOT SEE. Which input acts when a shared key is pressed: nothing is pressed. A
    control of a mod that is in the file and not in the dump is counted as the engine's, so read
    the file of a game that ran no other mods, or hand it the dump of everything that game ran.
    Gamepad bindings. With -Mods, an input a mod names by building the string, and a mod that is
    a zip; a name two mods quote is given both.

.PARAMETER Dump
    The dump whose custom inputs are read.

.PARAMETER Config
    The config.ini. Defaults to the player's, %APPDATA%\Factorio\config\config.ini.

.PARAMETER Below
    A dump whose custom inputs are left out of the report.

.PARAMETER Mods
    A directory of mod directories, for a Member column.

.PARAMETER SelfTest
    Read a fixture dump and a fixture config.ini in a temp directory and check what is printed.

.EXAMPLE
    pwsh -File scripts/dump-keys.ps1 <Grado_ABC dump> -Below <Grado_ChangingBase dump> -Mods .mod-cache/Grado_ABC
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [Parameter(Position = 0)] [string] $Dump,
    [string] $Config,
    [string] $Below,
    [string] $Mods,
    [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'dump-lib.ps1')

$NUMPAD = @{ '+' = 'PLUS'; '-' = 'MINUS'; '*' = 'MULTIPLY'; '/' = 'DIVIDE' }
$MODIFIERS = 'CONTROL', 'SHIFT', 'ALT'

function ConvertTo-KeyForm {
    <#  A key sequence in the one form two spellings of it share. Nothing for no key.  #>
    param([string] $Sequence)
    if (-not $Sequence) { return }
    $parts = @($Sequence.ToUpperInvariant() -split ' \+ ' | ForEach-Object {
            $p = $_.Trim()
            if ($p -eq 'COMMAND') { 'CONTROL' }
            elseif ($p -match '^PAD (.+)$') { 'KP_' + ($NUMPAD[$Matches[1]] ?? $Matches[1]) }
            else { $p }
        })
    (@($MODIFIERS | Where-Object { $_ -in $parts }) + @($parts | Where-Object { $_ -notin $MODIFIERS })) -join ' + '
}

function Read-Controls {
    <#  The [controls] section: name to its primary and alternative value and whether either
        was rebound. The controller slots are left out.  #>
    param([Parameter(Mandatory)] [string] $Path)
    $controls = [ordered]@{}
    $inside = $false
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\[(.+)\]\s*$') { $inside = $Matches[1] -eq 'controls'; continue }
        if (-not $inside -or $line -notmatch '^(; )?([^=;\s][^=]*)=(.*)$') { continue }
        $name = $Matches[2]; $value = $Matches[3].Trim(); $rebound = -not $Matches[1]
        if ($name -match '-controller(-alternative)?$') { continue }
        $slot = 'Primary'
        if ($name -match '^(.+)-alternative$') { $name = $Matches[1]; $slot = 'Alternative' }
        if (-not $controls.Contains($name)) { $controls[$name] = @{ Primary = ''; Alternative = ''; Rebound = $false } }
        $controls[$name][$slot] = $value
        if ($rebound) { $controls[$name].Rebound = $true }
    }
    if (-not $controls.Count) { throw "$Path has no [controls] section with a control in it." }
    $controls
}

function Get-InputMembers {
    <#  Input name to the mod directories under $Mods whose Lua quotes it.  #>
    param([Parameter(Mandatory)] [string] $Mods, [string[]] $Name = @())
    $members = @{}
    if (-not $Name) { return $members }
    $pattern = [regex] ('["''](' + (@($Name | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')["'']')
    foreach ($mod in Get-ChildItem -LiteralPath $Mods -Directory) {
        foreach ($file in Get-ChildItem -LiteralPath $mod.FullName -Recurse -File -Filter *.lua) {
            foreach ($m in $pattern.Matches([IO.File]::ReadAllText($file.FullName))) {
                $n = $m.Groups[1].Value
                if ($mod.Name -notin $members[$n]) { $members[$n] = @($members[$n]) + $mod.Name | Where-Object { $_ } }
            }
        }
    }
    $members
}

function Write-Keys {
    param([Parameter(Mandatory)] [string] $Dump, [Parameter(Mandatory)] [string] $Config, [string] $Below, [string] $Mods)
    $doc = Open-Dump $Dump
    try { $all = Get-DumpTable $doc 'custom-input' } finally { $doc.Dispose() }
    # Not $below: a variable name is the parameter of that name whatever its case.
    $under = @{}
    if ($Below) { $doc = Open-Dump $Below; try { $under = Get-DumpTable $doc 'custom-input' } finally { $doc.Dispose() } }
    $controls = Read-Controls $Config
    $engine = [ordered]@{}
    foreach ($name in $controls.Keys) { if (-not $all.ContainsKey($name)) { $engine[$name] = $controls[$name] } }
    $rebound = @($engine.Keys | Where-Object { $engine[$_].Rebound })
    "**$($engine.Count) engine controls** are in the ``[controls]`` section and are not a custom input of the dump. $(@($engine.Values | Where-Object { $_.Primary }).Count) have a key in the primary slot and $(@($engine.Values | Where-Object { $_.Alternative }).Count) in the alternative. $(if ($rebound) { "$($rebound.Count) are rebound, so the file does not hold their default: $(Format-Names $rebound)." } else { 'None is rebound, so each key is a default.' })"
    ''

    # Which engine controls have a key, by its form. An alternative slot is marked.
    $byKey = @{}
    foreach ($name in $engine.Keys) {
        foreach ($slot in 'Primary', 'Alternative') {
            $form = ConvertTo-KeyForm $engine[$name][$slot]
            if ($form) { $byKey[$form] = @($byKey[$form]) + $(if ($slot -eq 'Primary') { "``$name``" } else { "``$name`` in its alternative slot" }) | Where-Object { $_ } }
        }
    }

    $inputs = @($all.Values | Where-Object { -not $under.ContainsKey($_['name']) } | Sort-Object { $_['name'] })
    $members = if ($Mods) { Get-InputMembers $Mods @($inputs | ForEach-Object { $_['name'] }) } else { @{} }
    $member = { param($name) if ($Mods) { , ($members[$name] ? (Format-Names $members[$name]) : 'not found') } }
    $lead = @(if ($Mods) { 'Member' })
    $linked = @($inputs | Where-Object { $_['linked_game_control'] })
    $keyed = @($inputs | Where-Object { -not $_['linked_game_control'] -and ($_['key_sequence'] -or $_['alternative_key_sequence']) })
    $bare = @($inputs | Where-Object { -not $_['linked_game_control'] -and -not ($_['key_sequence'] -or $_['alternative_key_sequence']) })
    $shown = { param($i) (@($i['key_sequence'], $i['alternative_key_sequence']) | Where-Object { $_ } | ForEach-Object { "``$_``" }) -join ' or ' }
    "The dump has $($all.Count) custom inputs$(if ($Below) { ", $($inputs.Count) of them not in $(Get-DumpLabel $Below)" }): $($keyed.Count) with a default key, $($linked.Count) linked to a control, and $($bare.Count) with neither."
    ''

    $sharing = @(); $alone = @()
    foreach ($i in $keyed) {
        $hits = @(@($i['key_sequence'], $i['alternative_key_sequence']) | ForEach-Object { ConvertTo-KeyForm $_ } | Where-Object { $_ } | Select-Object -Unique | ForEach-Object { $byKey[$_] } | Where-Object { $_ } | Select-Object -Unique)
        if ($hits) { $sharing += , (@(& $member $i['name']) + @("``$($i['name'])``", (& $shown $i), "``$($i['consuming'] ?? 'none')``", "$($hits.Count): $($hits -join ', ')")) }
        else { $alone += "``$($i['name'])`` ($(& $shown $i))" }
    }
    "**$($sharing.Count) of the $($keyed.Count) inputs with a default key share it with an engine control:**"
    if ($sharing) { ''; Format-MarkdownTable ($lead + 'Input', 'Default', 'Consuming', 'Engine controls with the same default') $sharing }
    ''
    if ($alone) { "The other $($alone.Count) share with no engine control: $($alone -join ', ')."; '' }

    "**$($linked.Count) are linked to a control:**"
    if ($linked) {
        ''
        Format-MarkdownTable ($lead + 'Input', 'Linked to', "That control's default") @(
            foreach ($i in $linked) {
                $to = $i['linked_game_control']
                $default = if (-not $engine.Contains($to)) { 'not among the engine controls' } else { (@($engine[$to].Primary, $engine[$to].Alternative) | Where-Object { $_ } | ForEach-Object { "``$_``" }) -join ' or ' }
                , (@(& $member $i['name']) + @("``$($i['name'])``", "``$to``", $default))
            })
    }
    if ($bare) { ''; "$($bare.Count) have no key and no link: $(Format-Names @($bare | ForEach-Object { $_['name'] }))." }
}

function Invoke-SelfTest {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "dump-keys-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    New-Item -ItemType Directory -Path (Join-Path $temp 'mods/alpha') -Force | Out-Null
    try {
        $dump = Join-Path $temp 'dump.json'; $below = Join-Path $temp 'below.json'; $config = Join-Path $temp 'config.ini'
        Set-Content -LiteralPath $dump -Value '{"custom-input":{"same":{"name":"same","key_sequence":"SHIFT + CONTROL + R"},"pad":{"name":"pad","key_sequence":"PAD +"},"mac":{"name":"mac","key_sequence":"","alternative_key_sequence":"COMMAND + F"},"free":{"name":"free","key_sequence":"ALT + Q"},"link":{"name":"link","key_sequence":"","linked_game_control":"rotate"},"lost":{"name":"lost","key_sequence":"","linked_game_control":"gone"},"bare":{"name":"bare","key_sequence":""},"lower":{"name":"lower","key_sequence":"R"}}}'
        Set-Content -LiteralPath $below -Value '{"custom-input":{"lower":{"name":"lower","key_sequence":"R"}}}'
        Set-Content -LiteralPath $config -Value @'
[other]
; rotate=NOT THIS SECTION
[controls]
; rotate=R
; rotate-alternative=
; rotate-controller=controller-x
; reverse=CONTROL + SHIFT + R
; bigger=KP_PLUS
; find=
; find-alternative=CONTROL + F
; same=SHIFT + CONTROL + R
moved=X
[sound]
; rotate=NOR THIS
'@
        Set-Content -LiteralPath (Join-Path $temp 'mods/alpha/data.lua') -Value 'data:extend({{ type = "custom-input", name = "same" }})'
        $out = (Write-Keys -Dump $dump -Config $config -Below $below -Mods (Join-Path $temp 'mods')) -join "`n"
        $cases = [ordered]@{
            'only [controls] is read, and a custom input in it is not an engine control' = $out -match '\*\*5 engine controls\*\*'
            'the slots are counted and a rebound control is named'                       = $out -match '4 have a key in the primary slot and 1 in the alternative\. 1 are rebound.*`moved`'
            'an input of the dump below is left out'                                     = $out -match '8 custom inputs, 7 of them not in' -and $out -notmatch '`lower`'
            'modifiers in another order are one key'                                     = $out -match '\| `same` \| `SHIFT \+ CONTROL \+ R` \| `none` \| 1: `reverse` \|'
            'the numpad spelling is bridged'                                             = $out -match '\| `pad` \| `PAD \+` \| `none` \| 1: `bigger` \|'
            'COMMAND is CONTROL, and an alternative slot is matched and marked'          = $out -match '\| `mac` \| `COMMAND \+ F` \| `none` \| 1: `find` in its alternative slot \|'
            'the counts add up'                                                          = $out -match '\*\*3 of the 4 inputs with a default key' -and $out -match 'The other 1 share with no engine control: `free`'
            'a linked input gets its control''s default, or is told it has none'         = $out -match '\| `link` \| `rotate` \| `R` \|' -and $out -match '\| `lost` \| `gone` \| not among the engine controls \|'
            'an input with neither is named'                                             = $out -match '1 have no key and no link: `bare`\.'
            'two inputs whose names differ only in case are both read'                   = (& { $p = Join-Path $temp 'case.json'; Set-Content -LiteralPath $p -Value '{"custom-input":{"Ab":{},"ab":{}}}'; $d = Open-Dump $p; try { (Get-DumpTable $d 'custom-input').Count -eq 2 } finally { $d.Dispose() } })
            'the member is the mod whose Lua quotes the name'                        = $out -match '\| `alpha` \| `same` \|' -and $out -match '\| not found \| `pad` \|'
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
    finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}

if ($SelfTest) { Invoke-SelfTest }
if (-not $Dump) { throw 'Name the dump to read; get-dump.ps1 gives a path. Or -SelfTest.' }
if (-not $Config) { $Config = Join-Path $env:APPDATA 'Factorio/config/config.ini' }
if (-not (Test-Path -LiteralPath $Config -PathType Leaf)) { throw "There is no config.ini at $Config. Name one with -Config." }
Write-Keys -Dump $Dump -Config $Config -Below $Below -Mods $Mods
exit 0
