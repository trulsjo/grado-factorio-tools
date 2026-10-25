<#
.SYNOPSIS
    Fails if a prototype of the mods' own would show a player something other than its name.
    Exit 0 means every prototype whose name starts with -Prefix, of a type whose other prototypes
    are named, has a locale entry that resolved, and that each description it carries resolved
    too.

.DESCRIPTION
    A load does not do this: Factorio's data stage loads a prototype with no locale entry without
    complaint, and the omission surfaces only in front of a player as
    "Unknown key: item-name.<name>".

    WHERE IT CAME FROM. realistic-fusion-refreshed's scripts/locale-check.ps1, at c48fadf
    (grado-factorio-tools#102). There it loaded that repository's own mods and held their prefix
    as a constant. Here the mods are arguments, as load-harness.ps1 takes them, and so is the
    prefix. The method and the comparison are that script's.

    WHICH PROTOTYPES ARE THE MODS' OWN IS SAID BY -Prefix, and by nothing else. A prototype counts
    when its name starts with it, exactly and in that case, whichever mod in the set defined it;
    so a prototype the game derives from one of the mods' own and names after it, such as a
    recycling recipe, counts too. A MOD WITH NO PREFIX CONVENTION CANNOT USE THIS CHECK: it has no
    other way to tell the mods' prototypes from the game's. One that names a prototype outside its
    prefix is not told so here; that prototype is simply not read.

    METHOD

    Two dumps, diffed.

    --dump-prototype-locale writes one JSON file per category listing every prototype whose name
    resolves -- "if they have a valid value", in the game's own words. A prototype with no locale
    entry is simply absent. So the dump is the *resolved* set and cannot, on its own, tell you what
    is missing.

    --dump-data supplies the other half: data.raw as JSON, which is the *expected* set. Everything
    in it named with the prefix has to turn up in the locale dump.

    Turning up is not enough, though, which is the second half of the check. A dumped name is a
    resolved *value*, and the engine resolves a string containing something it cannot look up -- a
    rich-text reference to a renamed item, a control code that names nothing -- by writing
    "Unknown key" or "Unknown control sequence" into the text and carrying on. That value is
    present, so membership alone reports it clean, and the player reads the error on the tooltip.
    Get-LocaleFailure in load-harness-lib.ps1 holds what those strings are, and its comment
    records what the engine does and does not do here. This check passes it -EngineOnly, so it
    fails on the engine's own errors and not on a placeholder another mod ships deliberately.

    The two failures are reported apart, because the fixes are not the same: an absent name wants a
    locale entry written, and an unresolved one wants an entry that is already there corrected.

    Which categories need a name is not hardcoded, because a hardcoded list goes stale the moment a
    mod adds a prototype type nobody thought about. Instead it is derived from the game: for each
    type the mods define something in, look at where the other prototypes of that type appear in
    the locale dump, and require the mods' in the same file. Types whose other members appear
    nowhere -- recipe categories, fuel categories, anything with no player-visible name -- are
    skipped on that evidence rather than by assumption.

    A type with no other members at all is an error, not a skip, unless it is an item type. That is
    the case where this check would otherwise go quiet exactly when something new arrives. An item
    type is one whose prototypes carry stack_size, as dump-walk.ps1 finds items: 2.1 defines no
    `tool` of its own, its science packs being plain items, and a mod's own `tool` is compared
    against the game's prototypes of every item type instead, the item group, and its mapping
    line says so. Any other type with no other members, such as an entity type the game stops
    defining, is still the error. -Nameless is the answer to it: a type named there is declared to
    have no visible name, and is skipped and reported as declared.
    `animation` and `custom-input` are declared already; why the second, below.

    Descriptions are reported but not required: the count of prototypes carrying one is printed,
    and any that fails to resolve fails the run. Factorio treats a description as optional, so an
    absent one is not a finding -- but a parameterised localised string usually lives in a
    description, and a parameter is the ordinary way to name something that has since been
    renamed.

    Expect the count to rise under -With space-age: the expansion generates a recycling recipe for
    every item, named after it, and those carry the prefix too.

    WHAT IT CANNOT SEE. Anything that needs a map: it only dumps, so a pass says nothing about a
    mod loading. A prototype outside the prefix. A type skipped because under half of its other
    prototypes, the game's and any other mod's in the set, are named. The name of a custom
    input: see below. An absent description. A placeholder another mod ships on purpose. And any
    language but the one the isolated run dumps in.

    A CUSTOM INPUT IS NOT READ. Its name is a [controls] entry, and --dump-prototype-locale
    writes no file for those. Left to the method above, the type was matched to the shortcuts'
    file, because 86% of the game's custom inputs share a name with a shortcut, and every custom
    input of the mods' own was reported missing whether or not it had its entry. Measured on
    2.0.77 on 2026-10-11, in the review of grado-factorio-tools#102. So `custom-input` is
    declared beside `animation`, and a custom input with no [controls] entry is not found here.

.PARAMETER Mods
    The mods to load: mod directories, mod zips, or directories of them. Everything the mods
    depend on has to be among them, or bundled with the game.

.PARAMETER Prefix
    What the names of the mods' own prototypes start with, e.g. my-. Matched exactly, in case.

.PARAMETER Nameless
    Prototype types this check must not ask a name of, beyond the two it declares itself: a type
    with no player-visible name of which the set holds none but the mods' own. Several are
    separated by commas.

.PARAMETER FactorioExe
    Path to Factorio.exe. Defaults to $env:FACTORIO_EXE, then the Steam install on the machine
    the harness was written on.

.PARAMETER With
    Bundled mods to enable, e.g. -With space-age. Several are separated by commas. Locale can
    differ under an expansion, so this is worth running both ways before a release.

.PARAMETER SelfTest
    Verify the check can fail. Runs twice: once as normal, which must pass, and once with a mod
    carrying four planted prototypes -- one with no locale entry, one whose name resolves to an
    engine error, one whose description does, and a tool with no locale entry, a type the game
    has none of on 2.1 -- every one of which must be caught, and caught as the right kind. Both
    halves are required: a check that never fires proves nothing, and one
    that reported an unresolved name as a missing one would send the fix to the wrong place.
    With mods and a prefix it runs on those, which must pass first; with neither it builds a small
    mod of its own. Needs Factorio.

.PARAMETER KeepTemp
    Keep the dumps for inspection. Junctions are always removed.

.EXAMPLE
    pwsh -File scripts/locale-check.ps1 path/to/my-mod -Prefix my-

.EXAMPLE
    pwsh -File scripts/locale-check.ps1 path/to/my-mod path/to/my-mod-core -Prefix my- -With space-age

.EXAMPLE
    pwsh -File scripts/locale-check.ps1 -SelfTest
#>

#Requires -Version 7
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(ValueFromRemainingArguments)] [string[]] $Mods,
    [string]   $Prefix,
    [string[]] $Nameless = @(),
    [string]   $FactorioExe,
    [string[]] $With = @(),
    [switch]   $SelfTest,
    [switch]   $KeepTemp
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/load-harness-lib.ps1"

# Under `pwsh -File` a list arrives as one string with its commas in it, so both are split here.
$With     = @($With     | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$Nameless = @($Nameless | ForEach-Object { $_ -split ',' } | Where-Object { $_ })

# Prototype types with no player-visible name at all, where an absent locale entry is correct rather
# than a gap.
#
# This exists because the check below refuses to guess: it decides whether a type needs names by
# looking at how many of the GAME'S OWN prototypes of that type have them, and a type the game
# defines none of leaves it nothing to look at. Rather than let it assume either way, it throws and
# asks to be taught. -Nameless is where a caller's teaching goes; what is here is true of the game.
$NAMELESS_TYPES = @{
    'animation'    = 'a named sprite sheet for rendering.draw_animation; nothing ever shows its name'
    'custom-input' = 'named under [controls], which the locale dump does not write; see the header'
}
foreach ($type in $Nameless) { $NAMELESS_TYPES[$type] = 'declared with -Nameless' }

# With no mods, -SelfTest builds one that resolves, so its first half has something to pass on.
$fixture = $null
if ($SelfTest -and -not $Mods -and -not $Prefix) {
    $fixture = Join-Path ([IO.Path]::GetTempPath()) ('locale-check-fixture-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $good = Join-Path $fixture 'localecheck-good'
    New-Item -ItemType Directory -Path (Join-Path $good 'locale/en') -Force | Out-Null
    @{ name = 'localecheck-good'; version = '0.0.1'; title = 'Locale-check fixture'
       author = 'locale-check.ps1'; factorio_version = '2.1'; dependencies = @('base') } |
        ConvertTo-Json | Set-Content -Path (Join-Path $good 'info.json') -Encoding utf8
    # The tool is a type the game defines none of on 2.1, so its file comes through the item group.
    @'
data:extend({
  { type = "item", name = "lc-named-item", stack_size = 1, icon = "__base__/graphics/icons/pipe.png", icon_size = 64 },
  { type = "tool", name = "lc-named-pack", stack_size = 1, durability = 1, icon = "__base__/graphics/icons/pipe.png", icon_size = 64 },
})
'@ | Set-Content -Path (Join-Path $good 'data.lua') -Encoding utf8
    "[item-name]`nlc-named-item=Named item`nlc-named-pack=Named pack`n[item-description]`nlc-named-item=An item with a name." |
        Set-Content -Path (Join-Path $good 'locale/en/good.cfg') -Encoding utf8
    $Mods = @($good); $Prefix = 'lc-'
}
if (-not $Mods)   { throw 'Name the mods to check: mod directories, zips, or directories of them. Or -SelfTest with neither mods nor -Prefix.' }
if (-not $Prefix) { throw 'Say what the names of the mods'' own prototypes start with: -Prefix. Without one this check cannot tell them from the game''s.' }

# Inside a try of its own, so the fixture goes when the harness cannot be built: a -With that
# names nothing, or no game at the path.
try { $harness = New-LoadHarness -Mods $Mods -FactorioExe $FactorioExe -With $With }
catch {
    if ($fixture) { Remove-TempDirectory -Path $fixture -Label 'locale-check fixture' }
    throw
}
$temp    = $harness.Temp
$modDir  = $harness.ModDirectory
$ourMods = @($harness.Mods.Name)

function Invoke-Dumps {
    <#  Run both dumps and return the parsed results.

        Each dump exits after writing, so they are two runs. They land in the isolated write-data
        directory the harness gives every run, which is also why this works with the game open. #>
    param([string[]] $Mods, [string] $Tag)

    Write-ModList -ModDirectory $modDir -Bundled $harness.Bundled -EnabledBundled $harness.EnabledBundled -Mods $Mods

    foreach ($dump in @('--dump-data', '--dump-prototype-locale')) {
        Invoke-FactorioStep -FactorioExe $harness.FactorioExe -ModDirectory $modDir `
            -Arguments @($dump) -OutputDirectory $temp -Tag "$Tag$dump" | Out-Null
    }

    $scriptOutput = Join-Path $temp 'write-data/script-output'
    $rawPath = Join-Path $scriptOutput 'data-raw-dump.json'
    if (-not (Test-Path $rawPath)) { throw "no data-raw-dump.json in $scriptOutput." }

    $raw = Get-Content -LiteralPath $rawPath -Raw | ConvertFrom-Json

    # The value is kept, not only the key: membership answers "is there a name", the value answers
    # "is it one". Ordinal, because these are compared against a dump the engine wrote and
    # PowerShell's own hashtables are case-insensitive.
    function ConvertTo-LocaleMap($Section) {
        $map = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
        if ($Section) {
            foreach ($entry in $Section.PSObject.Properties) { $map[$entry.Name] = [string] $entry.Value }
        }
        return , $map   # comma, or PowerShell unrolls the dictionary into its pairs on the way out
    }

    $locale = [ordered]@{}
    foreach ($file in Get-ChildItem -Path $scriptOutput -Filter '*-locale.json') {
        $parsed = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
        $locale[$file.Name] = @{
            Names        = ConvertTo-LocaleMap $parsed.names
            Descriptions = ConvertTo-LocaleMap $parsed.descriptions
        }
    }
    if ($locale.Count -eq 0) { throw "no *-locale.json in $scriptOutput; did --dump-prototype-locale run?" }

    # Dumps are overwritten rather than appended, but a stale file from a previous invocation would
    # be read as current. Clearing between runs keeps -SelfTest's two halves independent.
    Remove-Item -Path $scriptOutput -Recurse -Force

    return @{ Raw = $raw; Locale = $locale }
}

function Test-Stackable($Prototypes) {
    <#  Whether some prototype of a type in the data dump carries stack_size: an item type.  #>
    [bool] @($Prototypes.PSObject.Properties.Value | Where-Object { $_.PSObject.Properties['stack_size'] }).Count
}

function Test-Locale {
    <#  Compare the expected set against the resolved set. Returns findings; empty means clean.  #>
    param([Parameter(Mandatory)] [hashtable] $Dumps)

    $missing    = @()
    $unresolved = @()
    $skipped    = @()
    $mapping    = @()
    $checked    = 0
    $described  = 0

    foreach ($type in $Dumps.Raw.PSObject.Properties) {
        $names   = @($type.Value.PSObject.Properties.Name)
        $ours    = @($names | Where-Object { $_.StartsWith($Prefix, [StringComparison]::Ordinal) })
        if ($ours.Count -eq 0) { continue }

        if ($NAMELESS_TYPES.ContainsKey($type.Name)) {
            $skipped += "{0} ({1}, declared nameless: {2})" -f $type.Name, $ours.Count, $NAMELESS_TYPES[$type.Name]
            continue
        }

        $vanilla = @($names | Where-Object { -not $_.StartsWith($Prefix, [StringComparison]::Ordinal) })

        # An item type the game has stopped defining, as `tool` on 2.1, is compared against the
        # game's items of every type instead. An item is what carries stack_size, as dump-walk.ps1
        # finds one.
        $through = ''
        if ($vanilla.Count -eq 0 -and (Test-Stackable $type.Value)) {
            $through = ', through the item group'
            $vanilla = @(foreach ($other in $Dumps.Raw.PSObject.Properties) {
                if (Test-Stackable $other.Value) {
                    $other.Value.PSObject.Properties.Name |
                        Where-Object { -not $_.StartsWith($Prefix, [StringComparison]::Ordinal) }
                }
            })
        }
        if ($vanilla.Count -eq 0) {
            # Parenthesised as one string before -f, which binds tighter than +: without them the
            # format applies to the second half only and the message prints its own placeholders.
            throw (("prototype type '{0}' has {1} named {2}* and none of the game's, so there is no way to tell " +
                    "whether it needs a locale entry. Pass -Nameless {0} if it has no visible name, rather " +
                    "than letting the check guess.") -f $type.Name, $ours.Count, $Prefix)
        }

        # Where do the game's own prototypes of this type get their names from? Judged by the share
        # of them a file accounts for, not by the raw count: prototype names are only unique within
        # a type, so a handful of coincidental collisions across types is normal. "oil-processing"
        # is both a recipe category and a technology, and matching on count alone was enough for
        # that one collision to declare every recipe category a technology and demand names for
        # things that have never had one.
        $source = $null; $bestShare = 0.0
        foreach ($entry in $Dumps.Locale.GetEnumerator()) {
            $share = @($vanilla | Where-Object { $entry.Value.Names.ContainsKey($_) }).Count / $vanilla.Count
            if ($share -gt $bestShare) { $bestShare = $share; $source = $entry }
        }

        # Half is a wide margin either way: a type that is named runs near 1.0, and a type that is
        # not runs near 0 with only collisions to its name.
        if ($bestShare -lt 0.5) {
            $skipped += "{0} ({1}, best match {2:P0})" -f $type.Name, $ours.Count, $bestShare
            $source = $null
            continue
        }
        $mapping += "{0} -> {1} ({2:P0} of the game's own{3})" -f $type.Name, $source.Key, $bestShare, $through

        foreach ($name in $ours) {
            $checked++
            if (-not $source.Value.Names.ContainsKey($name)) {
                $missing += [pscustomobject]@{ Type = $type.Name; Name = $name; Expected = $source.Key }
                continue
            }

            # A description stays optional -- an absent one is not a finding -- but a present one is
            # held to the same standard as a name.
            $fields = [ordered]@{ name = $source.Value.Names[$name] }
            if ($source.Value.Descriptions.ContainsKey($name)) {
                $described++
                $fields['description'] = $source.Value.Descriptions[$name]
            }

            foreach ($field in $fields.Keys) {
                $marker = Get-LocaleFailure $fields[$field] -EngineOnly
                if ($marker) {
                    $unresolved += [pscustomobject]@{
                        Type = $type.Name; Name = $name; Field = $field; Value = $fields[$field]
                    }
                }
            }
        }
    }

    return @{
        Missing = @($missing); Unresolved = @($unresolved); Skipped = $skipped
        Mapping = $mapping; Checked = $checked; Described = $described
    }
}

try {
    $bundledOn = if ($harness.EnabledBundled) { $harness.EnabledBundled -join ', ' } else { 'none (base only)' }
    Write-Host "locale-check: $($ourMods -join ', ')  |  prefix: $Prefix  |  bundled enabled: $bundledOn"

    $report = Test-Locale -Dumps (Invoke-Dumps -Mods $ourMods -Tag 'run')

    # A prefix nothing carries would otherwise pass for having had nothing to read.
    if ($report.Checked -eq 0) {
        Write-Host ''
        Write-Host "FAILED - no prototype of a named type starts with '$Prefix', so nothing was checked. Is the prefix right?"
        exit 1
    }

    if ($SelfTest) {
        # Declared by name and numbered by Invoke-SelfTestHalves, so the total is written nowhere
        # and a half added later relabels neither of these.
        Invoke-SelfTestHalves -Halves @(
            @{ Name = 'mods-resolve'; Body = {
                if ($report.Missing.Count -gt 0 -or $report.Unresolved.Count -gt 0) {
                    Write-Host ''
                    Write-Host 'FAILED - self-test: the mods as they stand already have a locale finding, so the'
                    Write-Host '         canary result would prove nothing. Fix the mods first.'
                    exit 1
                }
                "the mods as they stand resolve ($($report.Checked) prototypes)."
            } }

            @{ Name = 'planted-prototypes'; Body = {
                # Four planted prototypes, named with the prefix so they count: one per failure this
                # check claims to see, and a tool with no entry, whose file comes through the item
                # group on 2.1. They live in the temp directory, never beside the mods.
                #
                # The two unresolved ones lean on __ITEM__...__ naming an item that does not exist,
                # because that is the shape the engine answers with text rather than by refusing: a
                # localised string that is structurally wrong -- too deep, too many parameters --
                # stops the data stage and never reaches a dump, and a localised_name pointing
                # straight at a missing key is dropped from the dump entirely, which is the FIRST
                # canary's case, not this one. Measured on 2.0.77.
                $stem   = "${Prefix}localecheck-canary"
                $canary = Join-Path $modDir 'localecheck-canary'
                New-Item -ItemType Directory -Path (Join-Path $canary 'locale/en') -Force | Out-Null
                @{
                    name = 'localecheck-canary'; version = '0.0.1'; title = 'Locale-check canary'
                    author = 'locale-check.ps1'; factorio_version = '2.1'; dependencies = @('base >= 2.0.77')
                } | ConvertTo-Json | Set-Content -Path (Join-Path $canary 'info.json') -Encoding utf8

                @"
[item-name]
$stem-unresolved-name=Canary __ITEM__$stem-no-such-item__
$stem-unresolved-desc=Canary
[item-description]
$stem-unresolved-desc=Canary __ITEM__$stem-no-such-item__
"@ | Set-Content -Path (Join-Path $canary 'locale/en/canary.cfg') -Encoding utf8

                @"
local function canary(name)
  return { type = "item", name = name, stack_size = 1,
           icon = "__base__/graphics/icons/pipe.png", icon_size = 64 }
end
data:extend({
  canary("$stem-item"),
  canary("$stem-unresolved-name"),
  canary("$stem-unresolved-desc"),
  { type = "tool", name = "$stem-pack", stack_size = 1, durability = 1,
    icon = "__base__/graphics/icons/pipe.png", icon_size = 64 },
})
"@ | Set-Content -Path (Join-Path $canary 'data.lua') -Encoding utf8

                $canaryReport = Test-Locale -Dumps (Invoke-Dumps -Mods ($ourMods + 'localecheck-canary') -Tag 'canary')

                # Caught is not enough: caught as the right kind. A run that reported the
                # unresolved pair as missing would send someone to write a locale entry that is
                # already there.
                $wanted = @(
                    @{ Name = "$stem-item";             In = 'Missing';    Field = $null
                       What = 'a prototype with no locale entry' }
                    @{ Name = "$stem-pack";             In = 'Missing';    Field = $null
                       Expected = 'item-locale.json'
                       What = 'a tool with no locale entry, expected among the items' }
                    @{ Name = "$stem-unresolved-name";  In = 'Unresolved'; Field = 'name'
                       What = 'a name that does not resolve' }
                    @{ Name = "$stem-unresolved-desc";  In = 'Unresolved'; Field = 'description'
                       What = 'a description that does not resolve' }
                )
                $failed = $false
                foreach ($w in $wanted) {
                    $caught = @($canaryReport[$w.In] | Where-Object {
                        $_.Name -eq $w.Name -and (-not $w.Field -or $_.Field -eq $w.Field) -and
                        (-not $w.Expected -or $_.Expected -eq $w.Expected) })
                    if ($caught.Count -eq 0) {
                        Write-Host ''
                        Write-Host ("FAILED - self-test: {0} was NOT caught as {1}." -f $w.What, $w.In.ToLower())
                        $failed = $true
                    }
                }
                if ($failed) {
                    Write-Host '         This check is not proving anything; fix it before trusting a pass.'
                    exit 1
                }
                'all four planted prototypes were caught, each as its own kind.'
            } }
        )

        Write-Host ''
        Write-Host 'OK - self-test passed.'
        exit 0
    }

    foreach ($m in $report.Mapping) { Write-Host "  $m" }
    if ($report.Skipped) {
        Write-Host "  no visible name, so not checked: $($report.Skipped -join ', ')"
    }

    # Against the named count, not the checked one: a prototype with no name at all was never
    # looked at for a description, so counting it in the denominator would read as descriptions
    # going missing when it is nothing of the kind.
    Write-Host "  $($report.Described) of $($report.Checked - $report.Missing.Count) named prototypes also carry a description"

    if ($report.Missing.Count -gt 0) {
        Write-Host ''
        Write-Host "FAILED - $($report.Missing.Count) prototype(s) have no locale entry and would show as 'Unknown key' in game:"
        foreach ($m in $report.Missing | Sort-Object Type, Name) {
            Write-Host ("    {0,-22} {1}   (expected a name in {2})" -f $m.Type, $m.Name, $m.Expected)
        }
    }

    if ($report.Unresolved.Count -gt 0) {
        Write-Host ''
        Write-Host "FAILED - $($report.Unresolved.Count) locale entry(s) exist but do not resolve; the player reads this text:"
        foreach ($u in $report.Unresolved | Sort-Object Type, Name, Field) {
            Write-Host ("    {0,-22} {1} ({2})" -f $u.Type, $u.Name, $u.Field)
            Write-Host ("        {0}" -f $u.Value)
        }
    }

    if ($report.Missing.Count -gt 0 -or $report.Unresolved.Count -gt 0) { exit 1 }

    Write-Host "OK - all $($report.Checked) prototypes resolve to a name."
    exit 0
}
finally {
    Remove-LoadHarness -Harness $harness -Keep:$KeepTemp
    if ($fixture) { Remove-TempDirectory -Path $fixture -Label 'locale-check fixture' }
}
