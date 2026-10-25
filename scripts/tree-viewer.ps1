<#
.SYNOPSIS
    Renders the technology tree of a set of mods as one self-contained, zoomable HTML page, with
    each prototype attributed to the mod that created it and, for the mods named as the focus,
    candidates for things another mod in the set also has.

.DESCRIPTION
    A PROBE, NOT A CHECK. It asserts nothing about the tree it draws. Exit 0 means the set loaded,
    three Factorio runs finished and a page was written: never that the tree looked right or that
    an overlap was welcome. It does not belong in a check sweep. Its purpose is to let a person
    see how the trees of several mods interleave, and judge overlaps of meaning that no pass or
    fail can see.

    WHERE IT CAME FROM. realistic-fusion-refreshed's scripts/tree-viewer.ps1, with
    tree-viewer.template.html and tree-layout-probe.js, at c48fadf (grado-factorio-tools#101).
    There it loaded that repository's own mods unless told not to, and took them as the focus.
    Here the mods are arguments and there is no focus unless one is named. The tickets and
    research notes its comments cite are that repository's, and are named as such.

    THE MODS ARE WHAT load-harness.ps1 TAKES: mod directories, mod zips, or directories of them,
    such as a cache fetch-mods.ps1 filled. They are loaded in an isolated mod directory through
    load-harness-lib.ps1, so the player's game is neither read nor written.

    THREE FACTORIO RUNS, ONE OUTPUT

      --dump-data                data.raw as JSON: technologies, recipes, costs, effects
                                 (field semantics: realistic-fusion-refreshed's
                                 docs/research/tech-tree-dump-fields.md)
      --dump-prototype-locale    resolved localized names per category
      --create                   fires on_init in a generated exporter mod, which walks
                                 prototypes.get_history() for every technology, recipe, item,
                                 fluid and entity and writes the histories to script-output

    Attribution is the engine's own PrototypeHistory: a node is coloured by `created`, the
    `changed` chain rides in its detail panel, and a tick marks prototypes changed by a mod other
    than their creator. Measured semantics (realistic-fusion-refreshed#165, in its
    docs/research/get-history-semantics.md): the original mod stays `created` under wholesale
    redefinition, and `changed` records value changes only. If the set cannot reach the runtime
    stage the run FAILS LOUDLY and emits nothing -- a set that cannot create a map is a finding,
    and the crash log is it.

    Overlap candidates follow a three-tier heuristic (realistic-fusion-refreshed#160) --
    localized-name equality, then token overlap after stopwords, then prototype-name stems after
    prefix stripping -- computed for things (items, fluids, entities) between the focus mods and
    everything else. False positives are expected and fine: the viewer surfaces candidates, a
    human judges. Base-game pairs are computed, shipped flagged, and hidden behind a viewer toggle.

    Read "localized-name" there with one caveat. Some dumped names are not names: an engine
    "Unknown key" or "Unknown control sequence" left inside the resolved text, or a placeholder
    another mod ships deliberately -- Angels gives [item-name] angels-void the literal value
    "Something went wrong" and points 334 of its recipes at it. Get-LocaleFailure in
    load-harness-lib.ps1 holds the list and the measurements behind it. A thing in that state is
    labelled by its PROTOTYPE name instead, so the first two tiers then compare that name rather
    than a localized one. The run reports how many the set failed to localize; the number is the
    mods' own localisation, not this tool's, and nothing here tries to fix it. What is fixed is
    that no label is ever one of those strings.

    Researchability rides along the same way: each technology carries its `enabled`, `hidden` and
    `visible_when_disabled` state, and the ones no player can research are kept off the canvas
    until a toggle reveals them, dashed and dimmed. They are flagged, never dropped -- a dead base
    tech another mod left standing is a finding about how the set interleaves. An unlock or bonus
    whose effect is `hidden` rides along the same way, behind the same toggle (#218).

    The viewer itself is tree-viewer.template.html: dagre layered cards, top-down, d3 pan/zoom,
    detail on the card near and counter-scaled badges far, click for a side panel with
    prerequisite/dependent links highlighted. The libraries load from a CDN -- the accepted
    trade-off; the output needs network to render. Two CDNs: d3 from cdnjs, dagre from jsdelivr,
    because cdnjs's dagre stops at 0.8.5 and the maintained package is not on cdnjs at any
    version. The template's own comment carries the rest.

    WHAT IT CANNOT SEE. Whether the page renders: that takes a browser and the network, and
    nothing here opens one. Whether a label is right, beyond its not being one of the strings
    above. A mod handed over as a zip is named in the legend by its internal name, because only a
    directory's info.json is read for a title. And -SelfTest reads the dataset in the page it
    wrote; it draws nothing.

.PARAMETER Mods
    The mods to load: mod directories, mod zips, or directories of them.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on the machine
    the harness was written on.

.PARAMETER With
    Bundled mods to enable, e.g. -With space-age. Several are separated by commas.

.PARAMETER FocusMod
    The mod(s), by internal name, whose things form the LEFT side of every overlap pair. A list,
    not one name, because engine attribution splits a project into its real creators: a core mod
    defines the fluids a main mod's technologies unlock. A name that is no mod of the set is
    dropped with a warning. With none named, or none left, overlap analysis is off and the viewer
    says so. Several are separated by commas.

.PARAMETER OutName
    Basename of the emitted HTML, and the title the viewer shows. Default: tech-tree.

.PARAMETER OutDirectory
    Where the page is written. Default: tree-viewer-out in the current directory, which a
    repository that runs this will want git to ignore.

.PARAMETER KeepTemp
    Keep the dumps, the exporter mod and the captured output for inspection.

.PARAMETER SelfTest
    Build two small mods, render them, and read the page's dataset. Needs Factorio.

.EXAMPLE
    pwsh -File scripts/tree-viewer.ps1 .mod-cache/krastorio2 path/to/my-mod -FocusMod my-mod -OutName krastorio2-lane

.EXAMPLE
    pwsh -File scripts/tree-viewer.ps1 .mod-cache/angels -OutName angels-alone
#>

#Requires -Version 7
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(ValueFromRemainingArguments)] [string[]] $Mods,
    [string]   $FactorioExe,
    [string[]] $With = @(),
    [string[]] $FocusMod = @(),
    [string]   $OutName = 'tech-tree',
    [string]   $OutDirectory = 'tree-viewer-out',
    [switch]   $KeepTemp,
    [switch]   $SelfTest
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/load-harness-lib.ps1"

if ($SelfTest) {
    # Two mods that each make an item of one name's stem, one of them with a technology, rendered
    # by this script in a pwsh of its own; then the dataset is read back out of the page.
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('tree-viewer-selftest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $newMod = {
        param([string] $Name, [string] $Data, [string] $Locale)
        $dir = Join-Path $temp "src/$Name"
        New-Item -ItemType Directory -Path (Join-Path $dir 'locale/en') -Force | Out-Null
        @{ name = $Name; version = '1.0.0'; title = "Title of $Name"; author = 'tree-viewer.ps1'
           factorio_version = '2.1'; dependencies = @('base') } | ConvertTo-Json | Set-Content (Join-Path $dir 'info.json')
        $Data | Set-Content (Join-Path $dir 'data.lua')
        $Locale | Set-Content (Join-Path $dir 'locale/en/names.cfg')
        $dir
    }
    $item = '{ type = "item", name = "NAME", stack_size = 50, icon = "__base__/graphics/icons/iron-plate.png" }'
    try {
        $focus = & $newMod 'viewer-focus' @"
data:extend({ $($item.Replace('NAME', 'vf-plasma-widget')),
  { type = "technology", name = "vf-planted-tech", icon = "__base__/graphics/icons/iron-plate.png", icon_size = 64,
    prerequisites = { "automation" }, effects = {},
    unit = { count = 7, time = 5, ingredients = { { "automation-science-pack", 1 } } } },
  { type = "technology", name = "vf-mined-tech", icon = "__base__/graphics/icons/iron-plate.png", icon_size = 64,
    effects = {}, research_trigger = { type = "mine-entity", entities = { "crude-oil", "iron-ore" } } },
  { type = "technology", name = "vf-built-tech", icon = "__base__/graphics/icons/iron-plate.png", icon_size = 64,
    effects = {}, research_trigger = { type = "build-entity", entity = "stone-furnace" } },
  { type = "technology", name = "vf-hiding-tech", icon = "__base__/graphics/icons/iron-plate.png", icon_size = 64,
    effects = { { type = "unlock-recipe", recipe = "iron-gear-wheel" }, { type = "unlock-recipe", recipe = "pipe", hidden = true },
                { type = "inserter-stack-size-bonus", modifier = 1, hidden = true } },
    research_trigger = { type = "build-entity", entity = "stone-furnace" } } })
"@ "[item-name]`nvf-plasma-widget=Plasma widget`n[technology-name]`nvf-planted-tech=Planted technology"
        $other = & $newMod 'viewer-other' "data:extend({ $($item.Replace('NAME', 'vo-plasma-widget')) })" "[item-name]`nvo-plasma-widget=Plasma widget"

        $out = Join-Path $temp 'out'
        $run = @('-NoProfile', '-File', $PSCommandPath, $focus, $other, '-FocusMod', 'viewer-absent,viewer-focus', '-OutName', 'selftest', '-OutDirectory', $out)
        if ($FactorioExe) { $run += @('-FactorioExe', $FactorioExe) }
        $said = (& pwsh @run 2>&1 | Out-String)
        $code = $LASTEXITCODE
        $page = Join-Path $out 'selftest.html'

        Invoke-SelfTestHalves -Halves @(
            @{ Name = 'page-written'; Body = {
                if ($code -ne 0 -or -not (Test-Path -LiteralPath $page)) { throw "the run exited $code and wrote no page:`n$said" }
                if ((Get-Content -LiteralPath $page -Raw).Contains('"__DATASET__"')) { throw 'the page still holds the placeholder.' }
                'two mods rendered to a page with the dataset in place of the placeholder' } }
            @{ Name = 'planted-tech-attributed'; Body = {
                $m = [regex]::Match((Get-Content -LiteralPath $page -Raw), '\{"id":"vf-planted-tech".*?"mod":"([^"]+)".*?"prereqs":\[([^\]]*)\]')
                if (-not $m.Success) { throw 'vf-planted-tech is not in the page''s dataset.' }
                if ($m.Groups[1].Value -cne 'viewer-focus') { throw "vf-planted-tech is attributed to $($m.Groups[1].Value), not viewer-focus." }
                if ($m.Groups[2].Value -notmatch '"automation"') { throw "vf-planted-tech lost its prerequisite: $($m.Groups[2].Value)" }
                if ((Get-Content -LiteralPath $page -Raw) -notmatch '"label":"Planted technology"') { throw 'its localised name is not on the page.' }
                'a planted technology reaches the dataset with its name, its prerequisite and the mod that created it' } }
            @{ Name = 'entity-triggers-named'; Body = {
                $m = [regex]::Match((Get-Content -LiteralPath $page -Raw), '\{"id":"vf-mined-tech".*?"trigger":"([^"]*)"')
                if (-not $m.Success) { throw 'vf-mined-tech has no trigger in the page''s dataset.' }
                if ($m.Groups[1].Value -cne 'mine-entity crude-oil iron-ore') { throw "its trigger reads '$($m.Groups[1].Value)', not 'mine-entity crude-oil iron-ore'." }
                $m = [regex]::Match((Get-Content -LiteralPath $page -Raw), '\{"id":"vf-built-tech".*?"trigger":"([^"]*)"')
                if (-not $m.Success) { throw 'vf-built-tech has no trigger in the page''s dataset.' }
                if ($m.Groups[1].Value -cne 'build-entity stone-furnace') { throw "its trigger reads '$($m.Groups[1].Value)', not 'build-entity stone-furnace'." }
                'a mine-entity trigger names each of its entities, and a build-entity trigger its one entity' } }
            @{ Name = 'hidden-effects-marked'; Body = {
                $json = [regex]::Match((Get-Content -LiteralPath $page -Raw), '(?m)^const DATA = (.*);\r?$').Groups[1].Value
                $t = @(($json | ConvertFrom-Json -AsHashtable)['techs'] | Where-Object { $_['id'] -ceq 'vf-hiding-tech' })
                if ($t.Count -ne 1) { throw 'vf-hiding-tech is not in the page''s dataset.' }
                $read = (@($t[0]['unlocks'] | ForEach-Object { "$($_['name'])=$($_['hidden'])" }) +
                         @($t[0]['bonuses'] | ForEach-Object { "$($_['text'])=$($_['hidden'])" })) -join ', '
                if ($read -cne 'iron-gear-wheel=False, pipe=True, inserter-stack-size-bonus 1=True') {
                    throw "its effects read '$read', not 'iron-gear-wheel=False, pipe=True, inserter-stack-size-bonus 1=True'."
                }
                'a hidden unlock and a hidden bonus are marked hidden, and a visible unlock is not' } }
            @{ Name = 'focus-overlap-paired'; Body = {
                if ((Get-Content -LiteralPath $page -Raw) -notmatch '"a":"vf-plasma-widget"[^}]*"b":"vo-plasma-widget"[^}]*"tier":1') {
                    throw 'the focus mod''s item was not paired with the other mod''s item of the same name.'
                }
                if ((Get-Content -LiteralPath $page -Raw) -notmatch '"name":"viewer-focus","label":"Title of viewer-focus"') {
                    throw 'the legend does not name the focus mod by the title in its info.json.'
                }
                if ((Get-Content -LiteralPath $page -Raw) -notmatch '"focusMods":\["viewer-focus"\]') {
                    throw 'a focus mod that is not in the set was not dropped from the page.'
                }
                'a focus mod''s item is paired, on its localised name, with another mod''s item of that name; the legend has the mod''s title; a focus not in the set is dropped' } }
        )
    }
    catch { Write-Host "FAILED - self-test: $($_.Exception.Message)"; exit 1 }
    finally { Remove-TempDirectory -Path $temp -Label 'tree-viewer self-test' }
    Write-Host ''
    Write-Host 'OK - self-test passed.'
    exit 0
}

if (-not $Mods) { throw 'Name the mods to render: mod directories, zips, or directories of them. Or -SelfTest.' }
# Under `pwsh -File` a list arrives as one string with its commas in it, so both are split here.
$With     = @($With     | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$FocusMod = @($FocusMod | ForEach-Object { $_ -split ',' } | Where-Object { $_ })

$rigName = 'treeview-history'
$harness = New-LoadHarness -Mods $Mods -FactorioExe $FactorioExe -With $With
$temp    = $harness.Temp
$modDir  = $harness.ModDirectory

try {
    # Mod titles are read here so the viewer's legend can print names rather than internal ids.
    # ponytail: only a directory's info.json is read for its title; a zip is named by its internal
    # name. Read the zip's entry, as Get-HarnessMods does, if a set of zips ever needs titles.
    $modTitles = @{ base = 'Base'; core = 'Factorio core' }
    $setMods   = @($harness.Mods.Name)
    foreach ($row in $harness.Mods | Where-Object Kind -eq 'directory') {
        $where = Join-Path $row.Path 'info.json'
        $title = (Read-ModInfo -Text (Get-Content -LiteralPath $where -Raw) -Where $where)['title']
        if ($title) { $modTitles[$row.Name] = $title }
    }

    # The exporter: an empty data stage and an on_init that asks the engine for every prototype's
    # history. It defines nothing, so its presence changes nothing about the tree it measures. A
    # real directory in the harness's mod directory, so it goes with the temp directory.
    $rigDir = Join-Path $modDir $rigName
    New-Item -ItemType Directory -Path $rigDir -Force | Out-Null
    @{
        name = $rigName; version = '0.0.1'; title = 'Tree-viewer history exporter'
        author = 'tree-viewer.ps1'; factorio_version = '2.1'; dependencies = @('base >= 2.0.77')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $rigDir 'info.json') -Encoding utf8
    Set-Content -Encoding utf8 -Path (Join-Path $rigDir 'control.lua') -Value @'
-- Generated by tree-viewer.ps1. Reports; asserts nothing; defines nothing.
script.on_init(function()
  local classes = {
    technology = prototypes.technology, recipe = prototypes.recipe,
    item = prototypes.item, fluid = prototypes.fluid, entity = prototypes.entity,
  }
  local out = {}
  for class, tbl in pairs(classes) do
    local rows = {}
    for name, p in pairs(tbl) do
      -- get_history takes the concrete type ("boiler", "tool"), which is what p.type reports.
      local ok, h = pcall(prototypes.get_history, p.type, name)
      if ok and h then rows[name] = { c = h.created, ch = h.changed }
      else rows[name] = { c = "?", err = tostring(h) } end
    end
    out[class] = rows
  end
  helpers.write_file("treeview-history.json", helpers.table_to_json(out))
  log("TREEVIEW done")
end)
'@

    Write-ModList -ModDirectory $modDir -Bundled $harness.Bundled -EnabledBundled $harness.EnabledBundled `
        -Mods (@($setMods) + $rigName)

    # A focus the set does not hold pairs nothing, and the page would still name it as the left
    # side of every pair. The engine attributes by exact name, so the comparison is exact too.
    $inSet = @($setMods) + @($harness.EnabledBundled) + @('base', 'core')
    foreach ($absent in @($FocusMod | Where-Object { $_ -cnotin $inSet })) {
        Write-Warning "-FocusMod $absent is not a mod of this set, and is left out."
    }
    $FocusMod = @($FocusMod | Where-Object { $_ -cin $inSet })

    $bundledOn = if ($harness.EnabledBundled) { $harness.EnabledBundled -join ', ' } else { 'none (base only)' }
    Write-Host "tree-viewer: $($setMods -join ', ')  |  bundled enabled: $bundledOn"

    $step = @{ FactorioExe = $harness.FactorioExe; ModDirectory = $modDir; OutputDirectory = $temp }
    Invoke-FactorioStep @step -Tag 'dump-data'   -Arguments @('--dump-data') | Out-Null
    Invoke-FactorioStep @step -Tag 'dump-locale' -Arguments @('--dump-prototype-locale') | Out-Null
    # The attribution run. A set that cannot create a map fails HERE, loudly, by design:
    # Invoke-FactorioStep prints both stream tails and throws, and no viewer is emitted.
    $createOut = Invoke-FactorioStep @step -Tag 'create' -Arguments @('--create', (Join-Path $temp 'treeview.zip'))

    $factorioVersion = 'unknown'
    $m = Select-String -Path $createOut -Pattern 'Factorio (\d+\.\d+\.\d+)' | Select-Object -First 1
    if ($m) { $factorioVersion = $m.Matches[0].Groups[1].Value }

    # ------------------------------------------ read the three outputs
    $scriptOutput = Join-Path $temp 'write-data/script-output'
    $rawPath  = Join-Path $scriptOutput 'data-raw-dump.json'
    $histPath = Join-Path $scriptOutput 'treeview-history.json'
    if (-not (Test-Path $rawPath))  { throw "no data-raw-dump.json in $scriptOutput." }
    if (-not (Test-Path $histPath)) { throw "no treeview-history.json in $scriptOutput; the exporter never ran." }

    Write-Host 'parsing dumps...'
    $raw     = Get-Content -LiteralPath $rawPath  -Raw | ConvertFrom-Json -AsHashtable
    $history = Get-Content -LiteralPath $histPath -Raw | ConvertFrom-Json -AsHashtable
    # EVERY read of a key from these two dumps uses INDEX access, never dot
    # (realistic-fusion-refreshed#167). On a hashtable, dot-access falls back to .NET members when
    # the key is absent, so a missing key yields metadata instead of $null: `.item` renders the Item
    # indexer's signature, `.count` the entry count. Both shipped. Dot-access on the tables THIS
    # script builds ($h.c, $t.packs) is safe and stays.

    function Read-LocaleNames([string] $File) {
        $p = Join-Path $scriptOutput $File
        if (-not (Test-Path $p)) { return @{} }
        $parsed = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json -AsHashtable
        # -AsHashtable gives a CASE-INSENSITIVE map, where locale-check.ps1 builds an ordinal one
        # over the same files. Left as it is on purpose: prototype names are lowercase by
        # convention, and if one ever is not, the gate is the lane that must not guess. Here a
        # case-folded hit returns a plausible label instead of none, which for a tool that asserts
        # nothing is the better of the two wrong answers.
        if ($parsed['names']) { return $parsed['names'] } else { return @{} }
    }
    # Absent key OR a value that is not a name -> $null, so a caller's existing fall-through runs.
    # Nothing else here changes: the chain behind an unlock label already knew where to look next,
    # and was only ever stopped by an unusable value arriving as a truthy one -- which is how
    # "Something went wrong" reached the Sulphur processing card (realistic-fusion-refreshed#169).
    # Every locale read goes through this, and what counts as unusable lives in load-harness-lib.ps1
    # -- which keeps two lists, not one. This reads BOTH, engine errors and the placeholders other
    # mods ship, because the question here is whether a string makes a usable label.
    # locale-check.ps1 asks the narrower question of whether it resolved, so it reads only the
    # engine half.
    function Get-LocaleName($Map, [string] $Key) {
        $v = $Map[$Key]
        if (-not $v -or (Get-LocaleFailure $v)) { return $null }
        return $v
    }

    $techLocale   = Read-LocaleNames 'technology-locale.json'
    $itemLocale   = Read-LocaleNames 'item-locale.json'
    $fluidLocale  = Read-LocaleNames 'fluid-locale.json'
    $entityLocale = Read-LocaleNames 'entity-locale.json'
    $recipeLocale = Read-LocaleNames 'recipe-locale.json'

    # Both dumps write an empty Lua table as {}, so a key that should be a list arrives as an empty
    # OBJECT -- and an absent key arrives as $null, which @() turns into a one-element array holding
    # $null. Either ships junk the template silently filters. Every list-valued dump key comes
    # through here (realistic-fusion-refreshed#167); the comma keeps the empty array from unrolling
    # to $null on return.
    function Get-DumpList($Value) {
        if ($Value -is [System.Collections.IList]) { return ,@($Value) }
        return ,@()
    }

    # A boolean the dump OMITS when it holds its default -- which is how all three of a technology's
    # researchability flags arrive when nothing switched them (realistic-fusion-refreshed#168):
    # `enabled` defaults to true, `hidden` and `visible_when_disabled` to false.
    # <https://lua-api.factorio.com/2.0.77/prototypes/TechnologyPrototype.html>
    function Get-DumpFlag($Value, [bool] $Default) {
        if ($null -eq $Value) { return $Default }
        return [bool]$Value
    }

    # Three of a trigger's ID-bearing fields are FILTER unions at 2.1.23 -- a bare ID *or* a
    # {name, quality, comparator} table: craft-item's and send-item-to-orbit's `item`
    # (ItemIDFilter) and build-entity's `entity` (EntityIDFilter). The rest are plain IDs:
    # capture-spawner's `entity` is EntityID, craft-fluid's `fluid` is FluidID, and mine-entity's
    # `entities` is a list of EntityID (2.0.77's `entity`, one EntityID, renamed in 2.1.7).
    # Joining a table form into the label would print "System.Collections.Hashtable" --
    # the same leak of .NET metadata into node text this fixes -- so the filter fields go
    # through here. A bare ID passes straight back, which is why the caller can apply it to both
    # `item` and `entity` without caring which variant it holds.
    # <https://lua-api.factorio.com/2.1.23/types/ItemIDFilter.html>
    # <https://lua-api.factorio.com/2.1.23/types/EntityIDFilter.html>
    function Get-FilterName($Value) {
        if ($Value -is [System.Collections.IDictionary]) { return $Value['name'] }
        return $Value
    }

    function Get-History([string] $Class, [string] $Name) {
        $row = $history[$Class][$Name]
        if (-not $row) { return @{ c = 'base'; ch = @() } }
        return @{ c = $row['c']; ch = (Get-DumpList $row['ch']) }
    }

    # ------------------------------------------ overlap candidates (realistic-fusion-refreshed#160)
    $focusSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$FocusMod, [StringComparer]::Ordinal)

    $STOP = @('the','and','with','from','advanced','basic','improved','empty','used','mk1','mk2','mk3')
    function Get-Tokens([string] $s) {
        @(($s.ToLowerInvariant() -split '[^a-z0-9]+') | Where-Object { $_.Length -ge 4 -and $_ -notin $STOP })
    }
    # Tier 3 works on the prototype NAME with its mod prefix stripped: kr-fusion-reactor and
    # xy-dd-reactor share the stem token "reactor" even when the localized labels do not line up.
    function Get-StemTokens([string] $name) {
        @(( ($name -replace '^[a-z0-9]{1,8}-', '') -split '[-_]' ) |
            Where-Object { $_.Length -ge 4 -and $_ -notin $STOP })
    }

    $things = [System.Collections.Generic.List[object]]::new()
    foreach ($cat in @(@('item', $itemLocale), @('fluid', $fluidLocale), @('entity', $entityLocale))) {
        $catName, $locale = $cat
        foreach ($kv in $locale.GetEnumerator()) {
            $h = Get-History $catName $kv.Key
            # A thing whose dumped name is not usable as one stays in the analysis under its
            # prototype name rather than dropping out of it (realistic-fusion-refreshed#169). Tier 3
            # reads the prototype name anyway, so it can still pair; and a thing silently missing
            # from the pool is a worse answer than one labelled plainly. Its tokens then come from
            # that name, not from the unusable text -- and that text carries real tokens if you let
            # it. "wrong" and "something" from Angels' placeholder, "unknown" and "sequence" from an
            # engine error: four letters or more, straight through the stopword filter, and feeding
            # tier 2 overlap between two things that have nothing whatever in common.
            $label = Get-LocaleName $locale $kv.Key
            if (-not $label) { $label = $kv.Key }
            $things.Add([pscustomobject]@{
                Name = $kv.Key; Label = $label; Cat = $catName; Mod = $h.c
                Tokens = Get-Tokens $label; Stems = Get-StemTokens $kv.Key
            })
        }
    }

    $overlaps = [System.Collections.Generic.List[object]]::new()
    if ($focusSet.Count) {
        Write-Host "scoring overlaps (focus: $($FocusMod -join ', '))..."
        $focusThings = @($things | Where-Object { $focusSet.Contains($_.Mod) })
        $otherThings = @($things | Where-Object { -not $focusSet.Contains($_.Mod) })
        $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($a in $focusThings) {
            foreach ($b in $otherThings) {
                $score = 0; $tier = 0
                if ($a.Label -and ($a.Label -ieq $b.Label)) { $score = 4; $tier = 1 }
                elseif ($a.Tokens.Count) {
                    $shared = @($a.Tokens | Where-Object { $_ -in $b.Tokens })
                    if ($shared.Count -ge 1) { $score = $shared.Count; $tier = 2 }
                }
                if ($tier -eq 0 -and $a.Stems.Count) {
                    $shared = @($a.Stems | Where-Object { $_ -in $b.Stems })
                    if ($shared.Count -ge 1) { $score = $shared.Count; $tier = 3 }
                }
                if ($tier -eq 0) { continue }
                if (-not $seen.Add("$($a.Name)|$($b.Name)")) { continue }
                if ($a.Cat -eq $b.Cat) { $score++ }   # same-class boost
                $overlaps.Add([pscustomobject]@{
                    a = $a.Name; aLabel = $a.Label; aCat = $a.Cat; aMod = $a.Mod
                    b = $b.Name; bLabel = $b.Label; bCat = $b.Cat; bMod = $b.Mod
                    score = $score; tier = $tier; base = ($b.Mod -in @('base', 'core'))
                })
            }
        }
    }
    # Base pairs are computed but viewer-filtered (realistic-fusion-refreshed#160): shipped flagged
    # and capped separately so the toggle has something to reveal without drowning the mod pairs.
    $overlaps = @(
        @($overlaps | Where-Object { -not $_.base } | Sort-Object score -Descending | Select-Object -First 150) +
        @($overlaps | Where-Object base            | Sort-Object score -Descending | Select-Object -First 100)
    )

    # ------------------------------------------ technologies (realistic-fusion-refreshed#159)
    # The comma is load-bearing, exactly as in Get-DumpList: PowerShell UNROLLS a one-element
    # array on return, so a single-result recipe came back as the bare string and $results[0] then
    # indexed that STRING -- yielding 's' for sulfuric-acid, never the name. Silent since
    # realistic-fusion-refreshed#159, because the label chain only reaches $results[0] when the
    # recipe's own locale entry misses, which before realistic-fusion-refreshed#169 also meant it
    # had stopped on the sentinel. Nineteen of the Angels lane's twenty-eight failed labels are this
    # bug, not the sentinel.
    function Get-RecipeResults($recipe) {
        if (-not $recipe['results']) { return ,@() }
        ,@($recipe['results'] | ForEach-Object { $_['name'] } | Where-Object { $_ })
    }

    $techs = [System.Collections.Generic.List[object]]::new()
    foreach ($kv in $raw['technology'].GetEnumerator()) {
        $name = $kv.Key; $t = $kv.Value
        $h = Get-History 'technology' $name
        $packs = @(); $count = $null; $formula = $null; $trigger = $null; $time = $null
        if ($t['unit']) {
            $u = $t['unit']
            $count = $u['count']; $formula = $u['count_formula']; $time = $u['time']
            $packs = @($u['ingredients'] | ForEach-Object { ,@($_[0], $_[1]) })
        }
        elseif ($t['research_trigger']) {
            # The data-bearing field of every TechnologyTrigger variant at 2.1.23: craft-item
            # (item, count, default 1), craft-fluid (fluid, amount, default 0), mine-entity
            # (entities, a list, each named), build-entity (entity), send-item-to-orbit (item),
            # capture-spawner (entity, optional), create-space-platform (type alone). A 2.0
            # dump's mine-entity gives one `entity`, read with build-entity's. Absent keys --
            # which is how the dump writes a field left at its default -- drop out of the join.
            # Not rendered: scripted's trigger_description and icon fields, which describe how the
            # trigger PRESENTS itself rather than what satisfies it, and so say nothing about the
            # tree. Read the variant pages, not the union page: it lists the variants without
            # their fields. <https://lua-api.factorio.com/2.1.23/types/TechnologyTrigger.html>
            $rt = $t['research_trigger']
            $trigger = (@($rt['type'], (Get-FilterName $rt['item']), (Get-FilterName $rt['entity'])) + (Get-DumpList $rt['entities']) +
                        @($rt['fluid'], $rt['count'], $rt['amount']) | Where-Object { $_ }) -join ' '
        }
        $unlocks = [System.Collections.Generic.List[object]]::new()
        $bonuses = [System.Collections.Generic.List[object]]::new()
        # `effects = {}` dumps as an empty OBJECT, which survives the per-effect guard as one truthy
        # element and adds a blank bonus -- 66 techs in the set this was found on.
        foreach ($e in (Get-DumpList $t['effects'])) {
            if (-not $e) { continue }
            # An effect's `hidden` (BaseModifier, default false) is shipped, never dropped, as a
            # technology's is: the viewer keeps a hidden one behind the same toggle. 2.1.23's Space
            # Age with Quality hides 315, 312 of them the recycling technology's recycling unlocks
            # (#218). <https://lua-api.factorio.com/2.1.23/types/BaseModifier.html>
            $hidden = Get-DumpFlag $e['hidden'] $false
            if ($e['type'] -eq 'unlock-recipe') {
                $recipeName = $e['recipe']
                $r = $raw['recipe'][$recipeName]
                $results = if ($r) { Get-RecipeResults $r } else { @() }
                # Recipe name, then the first result's item and fluid names, then the prototype
                # name. Same order as before; it just no longer halts on the sentinel, so
                # sulfuric-acid falls through the failed recipe entry to the fluid's "Sulfuric
                # acid". The last step is the prototype name and never the sentinel
                # (realistic-fusion-refreshed#169).
                $first = if ($results.Count) { $results[0] } else { $null }
                $label = Get-LocaleName $recipeLocale $recipeName
                if (-not $label -and $first) { $label = Get-LocaleName $itemLocale  $first }
                if (-not $label -and $first) { $label = Get-LocaleName $fluidLocale $first }
                if (-not $label) { $label = $recipeName }
                $unlocks.Add(@{ name = $recipeName; label = $label; results = @($results); hidden = $hidden })
            }
            else {
                $desc = $e['type']
                $modifier = $e['modifier']
                if ($null -ne $modifier -and $modifier -isnot [bool]) { $desc += " $modifier" }
                $bonuses.Add(@{ text = $desc; hidden = $hidden })
            }
        }
        # The changed chain, order kept, deduplicated, without the creator's own later edits
        # (realistic-fusion-refreshed#164).
        $changedBy = [System.Collections.Generic.List[string]]::new()
        foreach ($c in $h.ch) { if ($c -ne $h.c -and $changedBy -notcontains $c) { $changedBy.Add($c) } }
        # No technology carries the sentinel on the Angels lane, but the path has the same shape
        # and no lane is proof of every lane (realistic-fusion-refreshed#169).
        $techLabel = Get-LocaleName $techLocale $name
        if (-not $techLabel) { $techLabel = $name }
        $techs.Add([ordered]@{
            id = $name; label = $techLabel
            mod = $h.c; changedBy = @($changedBy)
            # Absent when a tech has none, so @() alone shipped [null] -- steam-power and
            # electronics here, filtered by the template and wrong in the dataset all the same.
            prereqs = (Get-DumpList $t['prerequisites'])
            count = $count; formula = $formula; trigger = $trigger; time = $time
            packs = $packs; unlocks = @($unlocks); bonuses = @($bonuses)
            # Researchability, shipped rather than dropped (realistic-fusion-refreshed#168): a tech
            # another mod switched off is a finding about how the lane interleaves, so the viewer
            # flags and hides it behind a toggle instead of the dataset losing it. Angels leaves 72
            # of these on the canvas, sulfur-processing among them -- an orphan card with no edges,
            # which is what a reader notices first.
            enabled = (Get-DumpFlag $t['enabled'] $true)
            hidden = (Get-DumpFlag $t['hidden'] $false)
            visibleWhenDisabled = (Get-DumpFlag $t['visible_when_disabled'] $false)
        })
    }

    $packOrder = [System.Collections.Generic.List[string]]::new()
    foreach ($t in $techs) { foreach ($p in $t.packs) { if ($packOrder -notcontains $p[0]) { $packOrder.Add($p[0]) } } }
    $packLabels = @{}
    foreach ($p in $packOrder) {
        $n = Get-LocaleName $itemLocale $p
        $packLabels[$p] = if ($n) { $n } else { $p }
    }

    # ------------------------------------------ mod legend and colours
    # Every mod the viewer will name: creators of techs, their modifiers, and both sides of every
    # pair. Focus first, base and core last, the rest in load-list order.
    $named = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($t in $techs) { [void]$named.Add($t.mod); foreach ($c in $t.changedBy) { [void]$named.Add($c) } }
    foreach ($o in $overlaps) { [void]$named.Add($o.aMod); [void]$named.Add($o.bMod) }
    $ordered = @()
    $ordered += @($FocusMod | Where-Object { $named.Contains($_) })
    $ordered += @($setMods | Where-Object { $named.Contains($_) -and $_ -notin $ordered })
    $ordered += @($named | Where-Object { $_ -notin $ordered -and $_ -notin @('base', 'core') } | Sort-Object)
    foreach ($b in @('base', 'core')) { if ($named.Contains($b)) { $ordered += $b } }

    # Focus mods share a cyan family so a project of several mods reads as one thing at a glance
    # while its real creators stay tellable apart.
    $FOCUS_COLORS = @('#2bb3c0', '#4fd0a7', '#3f8fd0')
    $PALETTE = @('#e0762b', '#57ab5a', '#986ee2', '#c69026', '#d94fd0', '#539bf5',
                 '#e5534b', '#5cc9a7', '#8250df', '#b55cd9', '#c0562b', '#7fa8d9')
    $FIXED = @{ base = '#8a8f98'; core = '#6a6f76' }
    # Not $mods: a variable name is case-insensitive, and that is the [string[]] parameter.
    $legend = [System.Collections.Generic.List[object]]::new()
    $pi = 0; $fi = 0
    foreach ($m in $ordered) {
        $color = if ($focusSet.Contains($m)) { $FOCUS_COLORS[$fi++ % $FOCUS_COLORS.Count] }
                 elseif ($FIXED[$m])         { $FIXED[$m] }
                 else                        { $PALETTE[$pi++ % $PALETTE.Count] }
        $label = if ($modTitles[$m]) { $modTitles[$m] } else { $m }
        $legend.Add([ordered]@{ name = $m; label = $label; color = $color })
    }

    # ------------------------------------------ emit
    $dataset = [ordered]@{
        meta = [ordered]@{
            name = $OutName; generated = (Get-Date -Format 'yyyy-MM-dd HH:mm')
            factorio = $factorioVersion; modList = @($setMods); focusMods = @($FocusMod)
            focusLabels = @($FocusMod | ForEach-Object { if ($modTitles[$_]) { $modTitles[$_] } else { $_ } })
            techCount = $techs.Count
        }
        mods = @($legend); packs = @($packOrder); packLabels = $packLabels
        techs = @($techs); overlaps = @($overlaps)
    }

    $template = Get-Content "$PSScriptRoot/tree-viewer.template.html" -Raw
    if (-not $template.Contains('"__DATASET__"')) { throw 'placeholder "__DATASET__" not found in the template.' }
    New-Item -ItemType Directory -Path $OutDirectory -Force | Out-Null
    $outPath = Join-Path (Resolve-Path -LiteralPath $OutDirectory).Path "$OutName.html"
    $template.Replace('"__DATASET__"', ($dataset | ConvertTo-Json -Depth 8 -Compress)) |
        Set-Content -LiteralPath $outPath -Encoding utf8

    # Surfaced, not silenced: the count is the mods' own localisation failing, which is
    # not this tool's to fix but every bit of it worth reporting.
    $failedLocale = @(@($recipeLocale.Values) + @($itemLocale.Values) + @($fluidLocale.Values) +
                      @($entityLocale.Values) + @($techLocale.Values) |
                      Where-Object { Get-LocaleFailure $_ }).Count
    $ticked = @($techs | Where-Object { $_.changedBy.Count -gt 0 }).Count
    $dead   = @($techs | Where-Object { -not $_.enabled -or $_.hidden }).Count
    Write-Host ''
    Write-Host ("reported: {0} techs ({1} changed by another mod, {2} unresearchable), {3} overlap candidates ({4} base-flagged), {5} mods named" -f
        $techs.Count, $ticked, $dead, $overlaps.Count, @($overlaps | Where-Object base).Count, $legend.Count)
    if ($failedLocale) {
        Write-Host ("          {0} prototypes have no usable localised name in this set -- an 'Unknown key' left in the text, or a placeholder the mod ships on purpose -- and every label naming one falls through to what the recipe produces, or last of all to the prototype name" -f
            $failedLocale)
    }
    Write-Host "viewer:   $outPath"
    Write-Host ''
    Write-Host 'OK - the tool ran and reported. It asserts nothing: the tree and its overlap'
    Write-Host '     candidates are measurements for a human to judge, not a verdict.'
}
finally { Remove-LoadHarness -Harness $harness -Keep:$KeepTemp }
exit 0
