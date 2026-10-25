<#
.SYNOPSIS
    Prints, as Markdown, what each planet's map generation settings hold in a --dump-data dump:
    the resources, and with -Against what differs from another dump's settings. It also says
    whether the settings name anything the dump does not have. Exit 0 means it was printed.

.DESCRIPTION
    WHAT IT READS. One dump, or two, from get-dump.ps1. It writes nothing. Of each planet it
    reads map_gen_settings: the autoplace controls, the entities, tiles and decoratives listed,
    the cliff, the territory units and the property expressions (grado-factorio-modpack#133).

    A RESOURCE is an entity in a planet's list whose prototype type is `resource`.

    NAMES THAT DO NOT EXIST. Every name in those lists is looked up in the dump, and so is the
    name inside a property expression's key, as in `entity:coal:probability`. Every item or
    fluid a listed entity gives when mined is looked up too. An entity, a territory unit and
    what is mined are looked up under any prototype type, so another prototype of the same name
    passes for one.

    WHAT IT CANNOT SEE. A map: nothing is generated. What a mod places from its control script.
    A mod that zeroes a resource's autoplace and places it itself shows here as the count of
    resources whose probability is 0, and no further. Amounts: the richness and frequency of an
    autoplace control are not compared. What a property expression's value names, since a value
    may be an expression and not a name. Asteroids and routes.

    CHECKED ON 2.1.23 (#219, 2026-10-25): what it reads, against the `Modding:` changes of 2.1.7,
    and a run on a dump of Space Age with Quality.

.PARAMETER Dump
    The dump to read.

.PARAMETER Against
    The dump whose settings it is compared with, e.g. Space Age alone.

.PARAMETER SelfTest
    Read two fixture dumps in a temp directory and check what is printed. No game.

.EXAMPLE
    pwsh -File scripts/dump-planets.ps1 <Grado_ABCS dump> -Against <Space Age dump>
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [Parameter(Position = 0)] [string] $Dump,
    [string] $Against,
    [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'dump-lib.ps1')

# The parts of a planet's settings that are lists of names, and where each name is looked up:
# a prototype type, or * for any type.
$PARTS = [ordered]@{ 'autoplace controls' = 'autoplace-control'; 'entities' = '*'; 'tiles' = 'tile'; 'decoratives' = 'optimized-decorative'; 'cliff' = 'cliff'; 'territory units' = '*' }

function Read-Planets {
    <#  Each planet's settings as lists of names, with the dump's index for looking names up.  #>
    param([Parameter(Mandatory)] [System.Text.Json.JsonDocument] $Doc)
    $index = Get-DumpIndex $Doc
    $planets = [ordered]@{}
    foreach ($planet in (Get-DumpTable $Doc 'planet').Values | Sort-Object { $_['order'] }, { $_['name'] }) {
        $settings = $planet['map_gen_settings']
        if (-not $settings) { continue }
        $listed = { param($kind) $settings['autoplace_settings']?[$kind]?['settings']?.Keys | Where-Object { $_ } }
        $entities = [string[]] @(& $listed 'entity')
        $planets[$planet['name']] = @{
            'autoplace controls' = [string[]] @($settings['autoplace_controls']?.Keys | Where-Object { $_ })
            'entities'           = $entities
            'tiles'              = [string[]] @(& $listed 'tile')
            'decoratives'        = [string[]] @(& $listed 'decorative')
            'cliff'              = [string[]] @($settings['cliff_settings']?['name'] | Where-Object { $_ })
            'territory units'    = [string[]] @(Get-List $settings['territory_settings']?['units'])
            Resources            = [string[]] @($entities | Where-Object { $index.ContainsKey('resource') -and $index['resource'].ContainsKey($_) })
            Expressions          = $settings['property_expression_names'] ?? @{}
            Settings             = $settings
        }
    }
    @{ Index = $index; Planets = $planets }
}

function Test-DumpName {
    param($Index, [string] $Type, [string] $Name)
    if ($Type -ne '*') { return $Index.ContainsKey($Type) -and $Index[$Type].ContainsKey($Name) }
    foreach ($t in $Index.Keys) { if ($Index[$t].ContainsKey($Name)) { return $true } }
    $false
}

function Write-Planets {
    param([Parameter(Mandatory)] [string] $Dump, [string] $Against)
    $docs = @($Dump, $Against | Where-Object { $_ } | ForEach-Object { Open-Dump $_ })
    try {
        $pack = Read-Planets $docs[0]
        $label = Get-DumpLabel $Dump
        $other = if ($Against) { Read-Planets $docs[1] }
        $otherLabel = if ($Against) { Get-DumpLabel $Against }

        # The resources, planet by planet.
        if ($other) {
            Format-MarkdownTable 'Planet', "Resources, $otherLabel", "Resources, $label" @(
                foreach ($p in $pack.Planets.Keys) {
                    $theirs = $other.Planets[$p]?.Resources
                    , @($p, $(if ($null -eq $theirs) { 'not a planet there' } else { "$($theirs.Count): $(Format-Names $theirs)" }), "$($pack.Planets[$p].Resources.Count): $(Format-Names $pack.Planets[$p].Resources)")
                })
        }
        else {
            Format-MarkdownTable 'Planet', "Resources, $label" @(foreach ($p in $pack.Planets.Keys) { , @($p, "$($pack.Planets[$p].Resources.Count): $(Format-Names $pack.Planets[$p].Resources)") })
        }

        # What each planet's settings hold beside them, against the other dump.
        if ($other) {
            foreach ($p in $pack.Planets.Keys) {
                if (-not $other.Planets.Contains($p)) { continue }
                $mine = $pack.Planets[$p]; $theirs = $other.Planets[$p]
                ''; "**$p.**"; ''
                $rows = foreach ($part in $PARTS.Keys) {
                    $added = @($mine[$part] | Where-Object { $_ -notin $theirs[$part] })
                    $gone = @($theirs[$part] | Where-Object { $_ -notin $mine[$part] })
                    $what = if (-not $added -and -not $gone) { 'the same' } else { @($(if ($added) { "added $($added.Count): $(Format-Names $added)" }), $(if ($gone) { "gone $($gone.Count): $(Format-Names $gone)" }) | Where-Object { $_ }) -join '. ' }
                    , @($part, $theirs[$part].Count, $mine[$part].Count, $what)
                }
                $keys = @(@($mine.Expressions.Keys) + @($theirs.Expressions.Keys) | Select-Object -Unique)
                $differ = @($keys | Where-Object { "$($mine.Expressions[$_])" -cne "$($theirs.Expressions[$_])" -or $mine.Expressions.Contains($_) -ne $theirs.Expressions.Contains($_) })
                $rows += , @('property expressions', $theirs.Expressions.Count, $mine.Expressions.Count, $(if ($differ) { "differ $($differ.Count): $(Format-Names $differ)" } else { 'the same' }))
                $rest = @(Compare-Prototype $mine.Settings $theirs.Settings | Where-Object { $_ -notin 'autoplace_controls', 'autoplace_settings', 'cliff_settings', 'territory_settings', 'property_expression_names' })
                foreach ($field in 'cliff_settings', 'territory_settings') {
                    if ((ConvertTo-CanonicalText $mine.Settings[$field]) -cne (ConvertTo-CanonicalText $theirs.Settings[$field])) { $rest += $field }
                }
                Format-MarkdownTable '', $otherLabel, $label, 'Difference' @($rows)
                if ($rest) { ''; "Other settings that differ on ${p}: $(Format-Names $rest)." }
            }
        }

        # Names the dump does not have.
        $missing = foreach ($p in $pack.Planets.Keys) {
            $planet = $pack.Planets[$p]
            foreach ($part in $PARTS.Keys) {
                foreach ($name in $planet[$part]) { if (-not (Test-DumpName $pack.Index $PARTS[$part] $name)) { "$p, ${part}: ``$name``" } }
            }
            foreach ($key in $planet.Expressions.Keys) {
                if ($key -match '^(entity|tile|decorative):(.+):[^:]+$' -and -not (Test-DumpName $pack.Index $(if ($Matches[1] -eq 'entity') { '*' } elseif ($Matches[1] -eq 'tile') { 'tile' } else { 'optimized-decorative' }) $Matches[2])) { "$p, property expression: ``$key``" }
            }
            foreach ($name in $planet['entities']) {
                foreach ($prototype in Find-DumpPrototype $docs[0] $name) {
                    $minable = $prototype['minable']
                    if (-not $minable) { continue }
                    $gives = @($minable['result']) + @(Get-List $minable['results'] | ForEach-Object { $_['name'] }) | Where-Object { $_ }
                    foreach ($g in $gives) { if (-not (Test-DumpName $pack.Index '*' $g)) { "$p, what ``$name`` gives when mined: ``$g``" } }
                }
            }
        }
        ''
        if ($missing) { "**The settings of $label name $(@($missing).Count) things the dump does not have:**"; ''; $missing | ForEach-Object { "- $_" } }
        else { "**Every name in the planets' settings of $label is in the dump**: each autoplace control, entity, tile, decorative, cliff and territory unit, the name in each property expression's key, and each item or fluid a listed entity gives when mined." }

        # The resources' own autoplace.
        $resources = (Get-DumpTable $docs[0] 'resource').Values
        $zero = @($resources | Where-Object { $_['autoplace'] -and "$($_['autoplace']['probability_expression'])" -ceq '0' } | ForEach-Object { $_['name'] })
        $none = @($resources | Where-Object { -not $_['autoplace'] } | ForEach-Object { $_['name'] })
        $live = @($resources | Where-Object { $_['autoplace'] -and "$($_['autoplace']['probability_expression'])" -cne '0' } | ForEach-Object { $_['name'] })
        ''
        "**$($zero.Count) of the $(@($resources).Count) resource prototypes of $label have an autoplace probability of ``0``.** $($none.Count) have no autoplace$(if ($none) { ": $(Format-Names $none)" }). $($live.Count) have another probability$(if ($live) { ": $(Format-Names $live)" })."
    }
    finally { $docs | ForEach-Object { $_.Dispose() } }
}

function Invoke-SelfTest {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "dump-planets-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    New-Item -ItemType Directory -Path $temp | Out-Null
    try {
        $planet = { param($entities, $expressions) '{"p":{"name":"p","order":"a","map_gen_settings":{"autoplace_controls":{"c":{}},"cliff_settings":{"name":"cl"},"property_expression_names":' + $expressions + ',"autoplace_settings":{"entity":{"settings":' + $entities + '},"tile":{"settings":{"t":{}}},"decorative":{"settings":{}}}}}}' }
        $rest = '"autoplace-control":{"c":{}},"cliff":{"cl":{}},"tile":{"t":{}},"item":{"ore":{},"stone":{}},"simple-entity":{"rock":{"name":"rock","minable":{"result":"stone"}}}'
        $alone = Join-Path $temp 'alone.json'; $pack = Join-Path $temp 'pack.json'
        Set-Content -LiteralPath $alone -Value ('{"planet":' + (& $planet '{"ore":{},"rock":{}}' '{"entity:ore:probability":"x"}') + ',"resource":{"ore":{"name":"ore","autoplace":{"probability_expression":"x"},"minable":{"result":"ore"}}},' + $rest + '}')
        Set-Content -LiteralPath $pack -Value ('{"planet":' + (& $planet '{"ore":{},"ore2":{},"ghost":{}}' '{"entity:ore:probability":0,"entity:nothing:richness":0}') + ',"resource":{"ore":{"name":"ore","autoplace":{"probability_expression":0},"minable":{"result":"ore"}},"ore2":{"name":"ore2","minable":{"results":[{"type":"item","name":"dust"}]}}},' + $rest + '}')
        $out = (Write-Planets $pack -Against $alone) -join "`n"
        $own = (Write-Planets $alone) -join "`n"
        $cases = [ordered]@{
            'a resource is a listed entity of type resource'        = $out -match '\| p \| 1: `ore` \| 2: `ore`, `ore2` \|'
            'what a list gained and lost is named'                  = $out -match '\| entities \| 2 \| 3 \| added 2: `ghost`, `ore2`\. gone 1: `rock` \|' -and $out -match '\| tiles \| 1 \| 1 \| the same \|'
            'a property expression that changed is named'           = $out -match 'differ 2: `entity:nothing:richness`, `entity:ore:probability`'
            'a listed entity the dump lacks is reported'            = $out -match '- p, entities: `ghost`'
            'a name in an expression key the dump lacks is reported' = $out -match '- p, property expression: `entity:nothing:richness`'
            'a mined result the dump lacks is reported'             = $out -match '- p, what `ore2` gives when mined: `dust`'
            'zeroed, missing and live autoplace are counted'        = $out -match '\*\*1 of the 2 resource prototypes.*1 have no autoplace: `ore2`\. 0 have another'
            'a dump that names nothing missing says so'             = $own -match '\*\*Every name in the planets'' settings' -and $own -match '0 of the 1 resource'
        }
        $failures = 0; $n = 0
        foreach ($name in $cases.Keys) {
            $n++
            Write-Host ("self-test {0}/{1}: {2} -- {3}" -f $n, $cases.Count, $name, $(if ($cases[$name]) { 'ok' } else { 'FAILED' }))
            if (-not $cases[$name]) { $failures++ }
        }
        Write-Host ''
        if ($failures) { Write-Host $out; Write-Host $own; Write-Host "FAILED - self-test: $failures of $($cases.Count) case(s) did not hold."; exit 1 }
        Write-Host "OK - self-test passed: all $($cases.Count) cases."
        exit 0
    }
    finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}

if ($SelfTest) { Invoke-SelfTest }
if (-not $Dump) { throw 'Name the dump to read; get-dump.ps1 gives a path. Or -SelfTest.' }
Write-Planets -Dump $Dump -Against $Against
exit 0
