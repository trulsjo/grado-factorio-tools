<#
.SYNOPSIS
    Walks the recipe graph of a --dump-data dump from what the surfaces supply, and prints, as
    Markdown, what can be researched and made. With -Against it prints what became of another
    dump's recipes, technologies and science packs in this one, and what each surface makes from
    its own materials in both. Exit 0 means the tables were printed, not that anything is playable.

.DESCRIPTION
    WHAT IT READS. One dump, or two: get-dump.ps1 gives a path. Nothing else. A walk writes
    nothing; the self-test may make a dump, as below.

    THE WALK (grado-factorio-modpack#132, where the rules were first written down, in
    docs/catalogue/Grado_ABCS.md under "How the walk was made"). Three rules, repeated until
    nothing new is added:

      A surface supplies   what is in $SOURCE_RULES below, each rule with what it reads.
      A recipe counts      when it is not hidden, every ingredient can be had, a machine of its
                           category can be built, and it is enabled or a technology that unlocks
                           it can be researched.
      A technology can be  when it is not hidden or disabled, every prerequisite can be, and
      researched           either its trigger can be met or its science packs can be made and
                           one lab that can be built takes them all.

    WHERE IT IS LOOSER THAN THE GAME, so that "can be made" is an upper bound:

      - It does not know where anything is. An item made on one planet counts on every other.
        What a nest drops, what a plant gives and a pump's own fluid count with no planet, seed
        or water asked for. No surface condition is read in the walk.
      - A trigger that asks for mining an entity or capturing a nest, and any trigger type it
        does not know, is taken as met.
      - A resource counts without asking what can mine it, or which fluid mining it takes.
      - A machine counts as buildable when an item that places it can be made. A machine a
        captured nest turns into counts once `capture-robot-rocket` can be made, when the dump
        has that item.
      - A fluid's temperature is not read, and neither is an amount or a probability.
      - An item and a fluid of one name are one thing here.

    FROM ITS OWN MATERIALS asks the opposite question: what one surface makes from what that
    surface supplies, with nothing brought in. There every machine is taken as there and every
    technology as researched; a recipe counts when it is not hidden or is a recycling recipe,
    every ingredient can be had, and its surface conditions hold on that surface. An entity is on
    a planet when the planet's settings list it; a tree, a plant or a nest also when its
    autoplace control is one of the planet's. A pump's own fluid is given to a planet whose
    tiles give water, which is a guess at where such a pump can stand. The count is of the items
    and fluids some counted recipe gives, so what is only mined is not in it. -BroughtIn adds
    names to every surface's supply in the first dump.

    WHAT IT CANNOT SEE. Play: nothing is crafted, researched or shipped. Amounts and rates. What
    a control script places or removes at run time, so a resource a mod places from its script
    and not from the planet's settings is not supplied, and one whose autoplace a mod zeroed
    still is. Whether a technology the walk does not reach is unreachable in the game or only
    here: a source rule may be missing.

    THE WALK KNOWS THREE NAMES OF SPACE AGE: the surface `space-platform`, where the chunks are; the
    item `capture-robot-rocket`; and the category `recycling`. A dump without them is walked
    without them.

    THE SELF-TEST runs the walk on a dump of Space Age alone, where the answer is known. Then it
    removes each source rule in turn and fails unless the answer changes. A rule
    the Space Age dump cannot show is named in the self-test's output, and is not proven. It
    needs the game, unless -Dump names a dump of Space Age alone.

.PARAMETER Dump
    The dump to walk.

.PARAMETER Against
    The dump to compare with, e.g. Space Age alone when -Dump is a pack beside Space Age.

.PARAMETER BroughtIn
    Items or fluids, comma-separated, that every surface is also given in the first dump, for a
    last column of the table of own materials.

.PARAMETER SelfTest
    See above. With -Dump, reads that dump; without, makes or reuses one through get-dump.ps1.

.EXAMPLE
    pwsh -File scripts/dump-walk.ps1 <Grado_ABCS dump> -Against <Space Age dump> -BroughtIn wood
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [Parameter(Position = 0)] [string] $Dump,
    [string] $Against,
    [string[]] $BroughtIn = @(),
    [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'dump-lib.ps1')

# What a surface supplies, by rule. The self-test removes each in turn.
$SOURCE_RULES = [ordered]@{
    mined  = 'what an entity on the planet gives when mined'
    tiles  = "the fluid of a tile in the planet's settings"
    plants = 'what a plant gives when harvested'
    chunks = 'the asteroid chunks, on a platform'
    nests  = 'what an enemy nest drops'
    pumps  = 'the fluid of a pump that has one of its own'
    steam  = 'steam where there is water, since a boiler is not a recipe'
    after  = 'what an item spoils into, burns into, or gives when launched in a rocket'
}
# The rules a dump of Space Age alone does not show: the self-test says so and does not fail.
$NOT_SHOWN_BY_SPACE_AGE = 'pumps', 'steam'

function Get-MinedNames {
    param($Prototype)
    $minable = $Prototype['minable']
    if (-not $minable) { return }
    if ($minable['result']) { $minable['result'] }
    foreach ($r in Get-List $minable['results']) { $r['name'] }
}

function Read-WalkData {
    <#  What the walk needs of one dump: the recipes, technologies, machines and labs, prepared,
        and each surface with what it supplies under each source rule.  #>
    param([Parameter(Mandatory)] [string] $Path)
    $doc = Open-Dump $Path
    try {
        $itemTypes = @(Get-DumpTypes $doc -WithProperty 'stack_size')
        $items = Get-DumpTable $doc $itemTypes
        $after = @{}
        $placers = @{}
        foreach ($i in $items.Values) {
            $next = @($i['spoil_result'], $i['burnt_result']) + @(Get-List $i['rocket_launch_products'] | ForEach-Object { $_['name'] }) | Where-Object { $_ }
            if ($next) { $after[$i['name']] = [string[]] $next }
            if ($i['place_result']) { $placers[$i['place_result']] = @($placers[$i['place_result']]) + $i['name'] | Where-Object { $_ } }
        }

        $recipes = foreach ($r in (Get-DumpTable $doc 'recipe').Values) {
            [pscustomobject]@{
                Name        = [string] $r['name']
                Hidden      = [bool] $r['hidden']
                Enabled     = $r['enabled'] -ne $false
                Category    = $r['category'] ? [string] $r['category'] : 'crafting'
                Ingredients = [string[]] @(Get-List $r['ingredients'] | ForEach-Object { $_['name'] })
                Results     = [string[]] @(Get-List $r['results'] | ForEach-Object { $_['name'] })
                Conditions  = @(Get-List $r['surface_conditions'])
            }
        }

        $technologies = foreach ($t in (Get-DumpTable $doc 'technology').Values) {
            [pscustomobject]@{
                Name          = [string] $t['name']
                Off           = [bool] $t['hidden'] -or $t['enabled'] -eq $false
                Prerequisites = [string[]] @(Get-List $t['prerequisites'])
                Trigger       = $t['research_trigger']
                Packs         = [string[]] @(if ($t['unit']) { Get-List $t['unit']['ingredients'] | ForEach-Object { $_[0] } })
                Unlocks       = [string[]] @(Get-List $t['effects'] | Where-Object { $_['type'] -eq 'unlock-recipe' } | ForEach-Object { $_['recipe'] })
            }
        }

        $spawners = Get-DumpTable $doc 'unit-spawner'
        $captured = @($spawners.Values | ForEach-Object { $_['captured_spawner_entity'] } | Where-Object { $_ } | Select-Object -Unique)
        $machines = foreach ($m in (Get-DumpTable $doc (Get-DumpTypes $doc -WithProperty 'crafting_categories')).Values) {
            [pscustomobject]@{
                Name       = [string] $m['name']
                Categories = [string[]] @(Get-List $m['crafting_categories'])
                Always     = $m['type'] -in 'character', 'god-controller'
                Placers    = [string[]] @(@($placers[$m['name']]) + $(if ($m['name'] -in $captured -and $items.ContainsKey('capture-robot-rocket')) { 'capture-robot-rocket' }) | Where-Object { $_ })
            }
        }
        $labs = foreach ($l in (Get-DumpTable $doc 'lab').Values) {
            [pscustomobject]@{ Name = [string] $l['name']; Inputs = [string[]] @(Get-List $l['inputs']); Placers = [string[]] @($placers[$l['name']] | Where-Object { $_ }) }
        }

        # Where things are. An entity is on a planet when the planet lists it; a tree, a plant or
        # a nest also when the planet has its autoplace control.
        $tiles = Get-DumpTable $doc 'tile'
        $byControl = @{ mined = (Get-DumpTable $doc 'tree').Values; plants = (Get-DumpTable $doc 'plant').Values; nests = $spawners.Values }
        $pumpFluids = @((Get-DumpTable $doc 'offshore-pump').Values | ForEach-Object { $_['fluid_box']?['filter'] } | Where-Object { $_ })
        $defaults = @{}
        foreach ($p in (Get-DumpTable $doc 'surface-property').Values) { $defaults[$p['name']] = $p['default_value'] }

        $surfaces = [ordered]@{}
        foreach ($planet in (Get-DumpTable $doc 'planet').Values | Sort-Object { $_['order'] }, { $_['name'] }) {
            $settings = $planet['map_gen_settings']
            if (-not $settings) { continue }
            $controls = @($settings['autoplace_controls']?.Keys | Where-Object { $_ })
            $listed = { param($kind) @($settings['autoplace_settings']?[$kind]?['settings']?.Keys | Where-Object { $_ }) }
            $supply = @{}
            foreach ($rule in $SOURCE_RULES.Keys) { $supply[$rule] = [Collections.Generic.HashSet[string]]::new() }
            foreach ($name in & $listed 'entity') {
                foreach ($prototype in Find-DumpPrototype $doc $name) {
                    $rule = switch ($prototype['type']) { 'plant' { 'plants' } 'unit-spawner' { 'nests' } default { 'mined' } }
                    foreach ($n in Get-MinedNames $prototype) { [void] $supply[$rule].Add($n) }
                }
            }
            foreach ($rule in $byControl.Keys) {
                foreach ($prototype in $byControl[$rule]) {
                    $control = $prototype['autoplace']?['control']
                    if (-not $control -or $control -notin $controls) { continue }
                    foreach ($n in Get-MinedNames $prototype) { [void] $supply[$rule].Add($n) }
                    foreach ($l in Get-List $prototype['loot']) { [void] $supply[$rule].Add($l['item']) }
                }
            }
            foreach ($name in & $listed 'tile') { if ($tiles[$name]?['fluid']) { [void] $supply.tiles.Add($tiles[$name]['fluid']) } }
            if ($supply.tiles.Contains('water')) { foreach ($f in $pumpFluids) { [void] $supply.pumps.Add($f) } }
            $surfaces[$planet['name']] = @{ Properties = $planet['surface_properties'] ?? @{}; Supply = $supply }
        }

        # What the walk supplies with no planet asked for. The chunks are the platform's.
        $everywhere = @{}
        foreach ($rule in $SOURCE_RULES.Keys) { $everywhere[$rule] = [Collections.Generic.HashSet[string]]::new() }
        foreach ($prototype in $byControl.plants) { foreach ($n in Get-MinedNames $prototype) { [void] $everywhere.plants.Add($n) } }
        foreach ($prototype in $byControl.nests) { foreach ($l in Get-List $prototype['loot']) { [void] $everywhere.nests.Add($l['item']) } }
        foreach ($f in $pumpFluids) { [void] $everywhere.pumps.Add($f) }
        $chunks = [Collections.Generic.HashSet[string]]::new()
        foreach ($c in (Get-DumpTable $doc 'asteroid-chunk').Values) { foreach ($n in Get-MinedNames $c) { [void] $chunks.Add($n) } }
        $platform = (Get-DumpTable $doc 'surface')['space-platform']
        if ($platform -and $chunks.Count) {
            $supply = @{}
            foreach ($rule in $SOURCE_RULES.Keys) { $supply[$rule] = [Collections.Generic.HashSet[string]]::new() }
            $supply.chunks = $chunks
            $surfaces['space-platform'] = @{ Properties = $platform['surface_properties'] ?? @{}; Supply = $supply }
        }

        @{
            Recipes = @($recipes); Technologies = @($technologies); Machines = @($machines); Labs = @($labs)
            After = $after; Placers = $placers; Surfaces = $surfaces; Everywhere = $everywhere; Defaults = $defaults
            StarterPacks = [string[]] @($items.Values | Where-Object { $_['type'] -eq 'space-platform-starter-pack' } | ForEach-Object { $_['name'] })
        }
    }
    finally { $doc.Dispose() }
}

function Get-Supply {
    <#  The names supplied by the rules not in $Without: on one surface, or on all of them with
        what is on no planet's list.  #>
    param([Parameter(Mandatory)] $Data, [string] $Surface, [string[]] $Without = @())
    $names = [Collections.Generic.HashSet[string]]::new()
    $from = if ($Surface) { @($Data.Surfaces[$Surface].Supply) } else { @($Data.Surfaces.Values | ForEach-Object { $_.Supply }) + $Data.Everywhere }
    foreach ($supply in $from) {
        foreach ($rule in $supply.Keys) { if ($rule -notin $Without) { $names.UnionWith([string[]] @($supply[$rule])) } }
    }
    , $names
}

function Invoke-Walk {
    <#  The walk from $Supply. With -Surface it is the walk of own materials on that surface.
        Gives what can be had, the recipes that count and the technologies that can be
        researched.  #>
    param([Parameter(Mandatory)] $Data, [Parameter(Mandatory)] [AllowEmptyCollection()] [Collections.Generic.HashSet[string]] $Supply, [string] $Surface, [string[]] $Without = @())
    $have = [Collections.Generic.HashSet[string]]::new($Supply)
    $used = [Collections.Generic.HashSet[string]]::new()
    $made = [Collections.Generic.HashSet[string]]::new()
    $by = @{}
    $researched = [Collections.Generic.HashSet[string]]::new()
    $unlocked = [Collections.Generic.HashSet[string]]::new()
    $categories = [Collections.Generic.HashSet[string]]::new()
    $any = { param([string[]] $names) foreach ($n in $names) { if ($have.Contains($n)) { return $true } } $false }
    $all = { param([string[]] $names) foreach ($n in $names) { if (-not $have.Contains($n)) { return $false } } $true }
    # A trigger names its item or entity as a string, or as a table with a name and a quality.
    $named = { param($id) if ($id -is [Collections.IDictionary]) { [string] $id['name'] } else { [string] $id } }

    if ($Surface) {
        $properties = $Data.Surfaces[$Surface].Properties
        $pending = [Collections.Generic.List[object]] @($Data.Recipes | Where-Object {
                if ($_.Hidden -and $_.Category -ne 'recycling') { return $false }
                foreach ($c in $_.Conditions) {
                    $value = $properties[$c['property']] ?? $Data.Defaults[$c['property']]
                    if (($null -ne $c['min'] -and $value -lt $c['min']) -or ($null -ne $c['max'] -and $value -gt $c['max'])) { return $false }
                }
                $true
            })
    }
    else { $pending = [Collections.Generic.List[object]] @($Data.Recipes | Where-Object { -not $_.Hidden }) }
    $technologies = [Collections.Generic.List[object]] @(if (-not $Surface) { $Data.Technologies | Where-Object { -not $_.Off } })
    $machines = [Collections.Generic.List[object]] @(if (-not $Surface) { $Data.Machines })

    do {
        $changed = $false
        if ('steam' -notin $Without -and $have.Contains('water') -and $have.Add('steam')) { $changed = $true }
        if ('after' -notin $Without) {
            foreach ($name in @($have)) { foreach ($next in $Data.After[$name]) { if ($next -and $have.Add($next)) { $changed = $true } } }
        }
        foreach ($m in @($machines)) {
            if ($m.Always -or (& $any $m.Placers)) { $categories.UnionWith($m.Categories); [void] $machines.Remove($m) }
        }
        foreach ($t in @($technologies)) {
            if (-not $researched.IsSupersetOf($t.Prerequisites)) { continue }
            $met = if ($t.Trigger) {
                switch ($t.Trigger['type']) {
                    'craft-item' { $have.Contains((& $named $t.Trigger['item'])) }
                    'craft-fluid' { $have.Contains((& $named $t.Trigger['fluid'])) }
                    'send-item-to-orbit' { $have.Contains((& $named $t.Trigger['item'])) }
                    'build-entity' { & $any @($Data.Placers[(& $named $t.Trigger['entity'])]) }
                    'create-space-platform' { & $any $Data.StarterPacks }
                    default { $true }
                }
            }
            else {
                $takes = $false
                if (& $all $t.Packs) {
                    foreach ($lab in $Data.Labs) {
                        if ((& $any $lab.Placers) -and -not @($t.Packs | Where-Object { $_ -notin $lab.Inputs }).Count) { $takes = $true; break }
                    }
                }
                $takes
            }
            if (-not $met) { continue }
            [void] $researched.Add($t.Name); [void] $technologies.Remove($t); $unlocked.UnionWith($t.Unlocks); $changed = $true
        }
        foreach ($r in @($pending)) {
            if (-not $Surface -and -not (($r.Enabled -or $unlocked.Contains($r.Name)) -and $categories.Contains($r.Category))) { continue }
            if (-not (& $all $r.Ingredients)) { continue }
            [void] $used.Add($r.Name); [void] $pending.Remove($r); $changed = $true
            foreach ($n in $r.Results) { if ($have.Add($n)) { $by[$n] = $r.Name }; [void] $made.Add($n) }
        }
    } while ($changed)
    @{ Have = $have; Made = $made; By = $by; Used = $used; Researched = $researched }
}

function Get-WalkResult {
    <#  One dump, walked: the data, the walk, and the walk of own materials on each surface.  #>
    param([Parameter(Mandatory)] [string] $Path, [string[]] $Without = @(), [string[]] $BroughtIn = @(), [switch] $NoSurfaces)
    $data = Read-WalkData $Path
    $result = @{ Data = $data; Walk = Invoke-Walk $data (Get-Supply $data -Without $Without) -Without $Without; Own = [ordered]@{}; With = [ordered]@{} }
    if (-not $NoSurfaces) {
        foreach ($surface in $data.Surfaces.Keys) {
            $supply = Get-Supply $data -Surface $surface
            $result.Own[$surface] = Invoke-Walk $data $supply -Surface $surface
            if ($BroughtIn) { $supply.UnionWith($BroughtIn); $result.With[$surface] = Invoke-Walk $data $supply -Surface $surface }
        }
    }
    $result.Open = @($data.Recipes | Where-Object { -not $_.Hidden })
    $result.Packs = [string[]] @($data.Labs | ForEach-Object { $_.Inputs } | Select-Object -Unique)
    $result
}


function Write-WalkOfOne {
    param([Parameter(Mandatory)] $Result, [Parameter(Mandatory)] [string] $Label)
    $data = $Result.Data; $walk = $Result.Walk
    $on = @($data.Technologies | Where-Object { -not $_.Off })
    $unreached = @($on | Where-Object { -not $walk.Researched.Contains($_.Name) } | ForEach-Object Name)
    $unmade = @($Result.Open | Where-Object { -not $walk.Used.Contains($_.Name) } | ForEach-Object Name)
    "**$(Format-Count $walk.Researched.Count) of the $(Format-Count $on.Count) technologies of $Label that are not hidden or disabled can be researched**, as the prototypes read."
    if ($unreached) { ''; "The $(Format-Count $unreached.Count) the walk does not reach: $(Format-Names $unreached)." }
    ''
    "**$(Format-Count ($Result.Open.Count - $unmade.Count)) of the $(Format-Count $Result.Open.Count) recipes that are not hidden can be made.**"
    if ($unmade) { ''; "The $(Format-Count $unmade.Count) that cannot: $(Format-Names $unmade)." }
    ''
    $missing = @($Result.Packs | Where-Object { -not $walk.Have.Contains($_) })
    "**$($Result.Packs.Count - $missing.Count) of the $($Result.Packs.Count) science packs a lab takes can be made.**$(if ($missing) { " Not made: $(Format-Names $missing)." })"
    if ($Result.Own.Count) {
        ''
        Format-MarkdownTable 'Surface', 'Made from its own materials', 'Science packs among them' @(
            foreach ($s in $Result.Own.Keys) { , @($s, "$($Result.Own[$s].Made.Count) items and fluids", (Format-Names @($Result.Packs | Where-Object { $Result.Own[$s].Made.Contains($_) }))) })
    }
}

function Write-WalkAgainst {
    <#  What became of $Base's recipes, technologies and science packs in $Pack.  #>
    param([Parameter(Mandatory)] $Pack, [Parameter(Mandatory)] $Base, [Parameter(Mandatory)] [string] $PackLabel, [Parameter(Mandatory)] [string] $BaseLabel, [string[]] $BroughtIn = @())
    $recipe = @{}; foreach ($r in $Pack.Data.Recipes) { $recipe[$r.Name] = $r }
    $technology = @{}; foreach ($t in $Pack.Data.Technologies) { $technology[$t.Name] = $t }
    $names = @($Base.Open | ForEach-Object Name)
    $gone = @($names | Where-Object { -not $recipe.ContainsKey($_) })
    $hidden = @($names | Where-Object { $recipe.ContainsKey($_) -and $recipe[$_].Hidden })
    $count = @($names | Where-Object { $recipe.ContainsKey($_) -and -not $recipe[$_].Hidden })
    $made = @($count | Where-Object { $Pack.Walk.Used.Contains($_) })
    $unmade = @($count | Where-Object { -not $Pack.Walk.Used.Contains($_) })
    $unmadeBase = @($names | Where-Object { -not $Base.Walk.Used.Contains($_) })
    $techNames = @($Base.Data.Technologies | ForEach-Object Name)
    $techGone = @($techNames | Where-Object { -not $technology.ContainsKey($_) })
    $techOff = @($techNames | Where-Object { $technology.ContainsKey($_) -and $technology[$_].Off })
    $techReached = @($techNames | Where-Object { $Pack.Walk.Researched.Contains($_) })
    $techLost = @($techNames | Where-Object { $technology.ContainsKey($_) -and -not $technology[$_].Off -and -not $Pack.Walk.Researched.Contains($_) })
    $also = { param($list, $word) if ($list) { "; $($list.Count) $word" } }

    "Of the recipes and technologies of $BaseLabel, in ${PackLabel}:"
    ''
    Format-MarkdownTable '', "In $BaseLabel", "In $PackLabel" @(
        , @('Recipes that are not hidden', $names.Count, "$($count.Count) still count; $($hidden.Count) are hidden$(& $also $gone 'are not there')")
        , @('of those, can be made', ($names.Count - $unmadeBase.Count), "$($made.Count)$(if ($unmade) { ": all but $($unmade.Count)" })")
        , @('Technologies', "$($techNames.Count), of which $($Base.Walk.Researched.Count) can be researched", "$($techReached.Count) can be researched; $($techOff.Count) are hidden or disabled; $($techLost.Count) cannot be reached$(& $also $techGone 'are not there')")
    )
    ''
    if ($hidden) { "The $($hidden.Count) hidden recipes: $(Format-Names $hidden)."; '' }
    if ($unmade) { "The $($unmade.Count) recipes that are not hidden and cannot be made: $(Format-Names $unmade)."; '' }
    if ($unmadeBase) { "The $($unmadeBase.Count) that cannot be made in $BaseLabel either: $(Format-Names $unmadeBase)."; '' }
    if ($techOff) { "The $($techOff.Count) technologies hidden or disabled: $(Format-Names $techOff)."; '' }
    if ($techLost) { "The $($techLost.Count) that cannot be reached: $(Format-Names $techLost)."; '' }
    if ($gone -or $techGone) { "Not in ${PackLabel}: $(Format-Names ($gone + $techGone))."; '' }

    $packsMade = @($Base.Packs | Where-Object { $Pack.Walk.Have.Contains($_) })
    $packsResearched = @($Base.Packs | Where-Object { $Pack.Walk.Researched.Contains($_) })
    $labs = @($Pack.Data.Labs | Where-Object { $lab = $_; @($lab.Placers | Where-Object { $Pack.Walk.Have.Contains($_) }) -and -not @($Base.Packs | Where-Object { $_ -notin $lab.Inputs }) } | ForEach-Object Name)
    "**$($packsMade.Count) of the $($Base.Packs.Count) science packs the labs of $BaseLabel take can be made in $PackLabel, as the prototypes read.**$(if ($packsMade.Count -lt $Base.Packs.Count) { " Not made: $(Format-Names @($Base.Packs | Where-Object { $_ -notin $packsMade }))." })"
    "$($packsResearched.Count) of the technologies of those names can be researched. The labs that can be built and take them all: $(Format-Names $labs)."
    ''
    $on = @($Pack.Data.Technologies | Where-Object { -not $_.Off })
    $unreached = @($on | Where-Object { -not $Pack.Walk.Researched.Contains($_.Name) })
    "$(Format-Count $unreached.Count) of the $(Format-Count $on.Count) technologies of $PackLabel that are not hidden or disabled did not come out as researchable."
    ''
    '### From its own materials'
    ''
    $header = @('Surface', "Made from its own materials, $BaseLabel", "Of those, not in $PackLabel") + @(if ($BroughtIn) { "With $(Format-Names $BroughtIn) brought in" })
    Format-MarkdownTable $header @(
        foreach ($s in $Base.Own.Keys) {
            $mine = $Pack.Own[$s]?.Made
            $lost = @($Base.Own[$s].Made | Where-Object { -not $mine -or -not $mine.Contains($_) })
            , (@($s, "$($Base.Own[$s].Made.Count) items and fluids", $lost.Count) + @(if ($BroughtIn) { @($lost | Where-Object { -not $Pack.With[$s]?.Made?.Contains($_) }).Count }))
        })
    ''
    Format-MarkdownTable 'Surface', "Science packs made from its own materials, $BaseLabel", "In $PackLabel" @(
        foreach ($s in $Base.Own.Keys) {
            , @($s, (Format-Names @($Base.Packs | Where-Object { $Base.Own[$s].Made.Contains($_) })), (Format-Names @($Base.Packs | Where-Object { $Pack.Own[$s]?.Made?.Contains($_) })))
        })
    foreach ($s in $Base.Own.Keys) {
        $mine = if ($BroughtIn) { $Pack.With[$s]?.Made } else { $Pack.Own[$s]?.Made }
        $lost = @($Base.Own[$s].Made | Where-Object { -not $mine -or -not $mine.Contains($_) })
        ''
        "Not made on $s in $PackLabel$(if ($BroughtIn) { ", with $(Format-Names $BroughtIn) brought in" }), $($lost.Count): $(Format-Names $lost)."
    }
}

function Invoke-SelfTest {
    param([string] $Path)
    if (-not $Path) {
        # Space Age alone, through the dump cache: a stub mod, disabled, because the harness
        # refuses a directory with no mod in it and a disabled mod is not part of the set.
        $temp = Join-Path ([IO.Path]::GetTempPath()) "dump-walk-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
        try {
            New-Item -ItemType Directory -Path (Join-Path $temp 'space-age-alone/stub') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $temp 'space-age-alone/stub/info.json') -Value '{"name":"stub","version":"0.0.1","title":"stub","author":"self-test","factorio_version":"2.0"}'
            $Path = & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'get-dump.ps1') (Join-Path $temp 'space-age-alone') -With space-age -Disabled stub | Select-Object -Last 1
            if ($LASTEXITCODE -or -not $Path) { Write-Host 'FAILED - self-test: get-dump.ps1 gave no dump of Space Age alone.'; exit 1 }
        }
        finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
    }
    $six = 'space-science-pack', 'metallurgic-science-pack', 'agricultural-science-pack', 'electromagnetic-science-pack', 'cryogenic-science-pack', 'promethium-science-pack'
    $answer = {
        param([string[]] $Without)
        $r = Get-WalkResult $Path -Without $Without -NoSurfaces
        '{0} technologies, {1} of the six packs, {2} of {3} recipes' -f $r.Walk.Researched.Count, @($six | Where-Object { $r.Walk.Have.Contains($_) }).Count,
            @($r.Open | Where-Object { $r.Walk.Used.Contains($_.Name) }).Count, $r.Open.Count
    }
    $known = '275 technologies, 6 of the six packs, 330 of 340 recipes'
    $whole = & $answer @()
    $ok = $whole -ceq $known
    Write-Host "self-test: Space Age alone gives $whole -- $($ok ? 'ok' : "FAILED, the known answer is $known")"
    $unproven = @()
    foreach ($rule in $SOURCE_RULES.Keys) {
        $without = & $answer @($rule)
        if ($without -ceq $known) { $unproven += $rule; Write-Host "self-test: without the rule '$rule' the answer is the same -- NOT PROVEN on this dump" }
        else { Write-Host "self-test: without the rule '$rule': $without -- ok, the answer changed" }
    }
    Write-Host ''
    # The rules a dump of Space Age alone was seen not to show. Another rule joining them fails.
    $surprise = @($unproven | Where-Object { $_ -notin $NOT_SHOWN_BY_SPACE_AGE })
    if (-not $ok) { Write-Host 'FAILED - self-test: the walk of Space Age alone does not give the known answer.'; exit 1 }
    if ($surprise) { Write-Host "FAILED - self-test: removing $($surprise -join ', ') does not change the answer."; exit 1 }
    Write-Host "OK - self-test passed: the known answer, and $($SOURCE_RULES.Count - $unproven.Count) of the $($SOURCE_RULES.Count) source rules shown to carry it.$(if ($unproven) { " Not proven here: $($unproven -join ', ')." })"
    exit 0
}

if ($MyInvocation.InvocationName -eq '.') { return }
if ($SelfTest) { Invoke-SelfTest -Path $Dump }
if (-not $Dump) { throw 'Name the dump to walk; get-dump.ps1 gives a path. Or -SelfTest.' }

# Through pwsh -File a list arrives as one string, commas and all.
$BroughtIn = @($BroughtIn -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$pack = Get-WalkResult $Dump -BroughtIn $BroughtIn
if ($Against) { Write-WalkAgainst -Pack $pack -Base (Get-WalkResult $Against) -PackLabel (Get-DumpLabel $Dump) -BaseLabel (Get-DumpLabel $Against) -BroughtIn $BroughtIn }
else { Write-WalkOfOne -Result $pack -Label (Get-DumpLabel $Dump) }
exit 0
