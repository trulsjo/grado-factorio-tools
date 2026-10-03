<#
.SYNOPSIS
    Build one distributable zip per mod directory given, named the way the mod portal requires.
    Exit 0 means every mod given was packed; nothing is written for any of them if one is refused.

.DESCRIPTION
    Turns each mod directory given into a zip a player could install, and reports what each one
    weighs. It uploads nothing and it changes no version -- the version is read out of each mod's
    own info.json and never written.

    WHY THE ZIP IS WORTH BUILDING. A check that junctions a mod directory into the game lets
    Factorio read the working tree in place, so "it loads" means "it loads when the game can see
    the working tree". A file that resolves through a junction but never makes it into a zip fails
    for a player and for nobody else. Loading the zips this script writes is how a consumer
    exercises the path the player is actually on.

    WHAT GOES IN, AND WHY IT IS NOT A DENYLIST. The file list comes from `git ls-files` -- every
    tracked path under the mod directory -- rather than from walking the filesystem and skipping
    known junk. A denylist is wrong here by construction: agent state such as `.omc/` has appeared
    inside a mod's graphics directory, and the next stray directory will be named something else.
    Tracking is the allowlist, and it is the same answer as "what is this mod". So every mod
    directory must be inside a git work tree; one that is not is refused.

    Content is read from the WORKING TREE, not from the index. Only the path list comes from git.
    Packing the index would mean a load of the zips silently checked committed content while you
    edited something else. Uncommitted edits are packed; untracked files are not, and are reported
    as a warning rather than dropped in silence.

    THE ZIP NAME IS THE STRICT PART, NOT THE FOLDER. Verified against the 2.0.77 mod-structure
    documentation: the zip must be named `{mod-name}_{version-number}` -- the example given is
    `better-armor_0.3.6` -- while "the folder inside the zip file does not have any naming
    restrictions". info.json must sit in that top-level folder. The name is computed from
    info.json rather than passed in, and the mod directory's own name must equal info.json's
    `name`: the zip and its folder are named from info.json while the files come from the
    directory, and a zip named after one mod and filled from another is one the portal would
    accept, since it only reads the name.

    NAMES ARE CASE-SENSITIVE. That documentation says nothing about case, so it was measured on
    2026-09-26 against Factorio 2.0.77 (build 84539): a zip `Alpha_1.0.0.zip` or a directory
    `Alpha` holding a mod named `alpha` is refused with "doesn't match the expected
    alpha_1.0.0.zip (case sensitive!)", and a dependency on `Alpha` with only `alpha` present
    fails as "Missing required dependency Alpha". The mod portal agrees: /api/mods/Krastorio2
    answers and /api/mods/krastorio2 is "Mod not found". So `Alpha` and `alpha` are two mods. The
    name check refuses a case-only mismatch, and the one-copy rule leaves the other case's zips
    alone -- whatever the check accepts, the rule cleans up after. Two places cannot follow that,
    because at one version the two mods' zips are one file on a case-insensitive file system:
    packing `alpha` 1.0.0 replaces an `Alpha_1.0.0.zip` already there, and giving both in one run
    is refused as the same mod twice.

    THE VERSION BOUNDS are the portal's: major.minor.sub, each 0-65535, and 0.0.0 invalid. A regex
    of three digit-runs accepts 0.0.0 and 1.0.99999, which the portal rejects at upload, so the
    bounds are enforced rather than described.

    ONE COPY PER MOD. Once a mod's new zip is in place, every other `<name>_<x.y.z>.zip` of that
    mod in -OutputDirectory is deleted, whatever its version. A mod whose name only contains this one
    is left alone, and so is anything that is not a zip -- an unpacked `<name>` directory there is
    not this script's to remove. A mod that fails leaves any earlier zip of it untouched.

    INFO.JSON KEYS ARE CASE-SENSITIVE, AND THAT IS THE GAME'S RULE. An info.json whose only name
    key is spelled `"Name"`, or whose only version key is `"Version"`, is refused as having no
    `name` or `version` key. Measured against Factorio 2.0.77 (build 84539), headless, isolated
    from the player's mods (grado-factorio-tools#49, for #47): it logs
        Error Util.cpp:81: Failed to load mod "probe-name": Key "name" not found in property tree at ROOT
    and the same line naming `version` for `"Version"`, while a lower-case control loads. To repeat
    it: dot-source load-harness-lib.ps1, build the harness with New-LoadHarness from a valid
    info.json, then rewrite the junctioned info.json with the wrong-case key and call
    Invoke-HarnessLoad. The rewrite comes after New-LoadHarness because Get-HarnessMods reads
    `name` and `version` itself and would stop first. A `"Name"` beside `name` is not refused: the
    mod is read from `name`, and the `"Name"` is ignored.

    AN INFO.JSON THAT IS NOT A JSON OBJECT IS REFUSED, naming the mod: `null`, an empty file, or an
    array, including a one-element array holding an object. That reason is this script's, not a
    measured game rule: it has no `name` to read, and PowerShell would otherwise unroll the
    one-element array and pack the object inside it as if it were the info.json.

    WHAT IT CANNOT SEE. It does not load anything: a zip that is shaped right can still fail in
    game. It does not read info.json beyond `name` and `version`, so a bad `factorio_version` or
    dependency line reaches the portal as it stands. A
    tracked path git reports under a mod directory but that is not a file -- a nested submodule --
    is refused as missing. "Nothing is written" covers every refusal the script makes itself; a
    read or write failure while zipping the second mod leaves the first mod's zip written and its
    other versions deleted.

.PARAMETER ModDirectory
    One or more mod directories, each holding info.json and each inside a git work tree. The
    trailing arguments, so `pwsh -File` can pass several.

.PARAMETER OutputDirectory
    Where to write the zips. Created if missing.

.PARAMETER SelfTest
    Prove this script can fail. Builds a scratch git repository of fixture mods and checks, among
    other things -- each case prints its own name -- the naming, the layout, the version bounds,
    the one-copy rule, that it and the name check agree on case, the refusal of a lone `"Name"` or
    `"Version"` key and of an info.json that is `null`, `[1]` or a one-element array holding an
    object, and -- the half that matters -- the exclusion, by planting a git-ignored file inside a
    mod directory and proving it does not reach the zip while its tracked neighbour does. Without
    that half, "no junk in the zip" is a claim about a directory that happened to be clean. It does
    not run an empty info.json, or a `"Name"` beside `name`. Needs git; touches no repository but
    its own.

.EXAMPLE
    pwsh -File scripts/pack-mods.ps1 -OutputDirectory dist my-mod my-mod-graphics

.EXAMPLE
    pwsh -File scripts/pack-mods.ps1 -SelfTest
#>

#Requires -Version 7
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(ValueFromRemainingArguments)] [string[]] $ModDirectory,
    [string] $OutputDirectory,
    [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-ModManifest {
    <#  What a mod is called, what version it declares, and which files belong to it.  #>
    param([Parameter(Mandatory)] [string] $Directory)

    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) { throw "mod directory not found: $Directory" }
    $dir = (Resolve-Path -LiteralPath $Directory).ProviderPath.TrimEnd('\', '/')
    # From Get-Item, not from the path: on a case-insensitive file system Resolve-Path keeps the
    # case it was typed in, so `alpha` would pass the name check for a directory named `Alpha`.
    $leaf = (Get-Item -LiteralPath $dir).Name

    $infoPath = Join-Path $dir 'info.json'
    if (-not (Test-Path -LiteralPath $infoPath)) { throw "$leaf has no info.json" }
    # As a hashtable: an info.json may hold an empty key, which ConvertFrom-Json refuses otherwise
    # (fluid-connection-indicators 0.2.9, grado-factorio-tools#40). Its keys then match case
    # exactly, so `"Name"` is no longer read as `name`, and an info.json holding both `name` and
    # `Name`, which ConvertFrom-Json also refused, is now read, from `name`.
    # -NoEnumerate, or a one-element array holding an object is unrolled and read as that object.
    $info = Get-Content -LiteralPath $infoPath -Raw | ConvertFrom-Json -AsHashtable -NoEnumerate
    # Before the value checks, which would otherwise report a `"Name"` key as an empty name. The
    # game refuses such an info.json too (see the header), so the refusal names the game.
    if ($info -isnot [System.Collections.IDictionary]) { throw "$leaf/info.json is not a JSON object." }
    foreach ($key in 'name', 'version') {
        if (-not $info.ContainsKey($key)) { throw "$leaf/info.json has no ""$key"" key, which Factorio 2.0.77 requires; keys match case exactly." }
    }

    # -cne, as the one-copy rule's -cmatch: Factorio compares mod names case-sensitively (see the
    # header), so the two must agree or a name this accepts is one that rule does not clean up after.
    if ($info.name -cne $leaf) {
        throw "$leaf/info.json declares name '$($info.name)'. The zip is named from info.json and the files come from the directory, so these must agree."
    }
    if ($info.version -notmatch '^\d{1,5}\.\d{1,5}\.\d{1,5}$') {
        throw "$leaf/info.json version '$($info.version)' is not major.minor.sub."
    }
    $parts = @($info.version -split '\.' | ForEach-Object { [int]$_ })
    if ($parts | Where-Object { $_ -gt 65535 }) {
        throw "$leaf/info.json version '$($info.version)' has a component above 65535."
    }
    if (($parts | Measure-Object -Sum).Sum -eq 0) {
        throw "$leaf/info.json version is 0.0.0, which Factorio rejects."
    }

    # -c core.quotePath=false, because the default is true and it is not cosmetic here: a tracked
    # path holding any non-ASCII byte comes back C-quoted ("caf\303\251.png"), Test-Path then
    # misses it, and Write-ModZip throws "tracked but not on disk" about a file that is on disk.
    # Paths come back relative to $dir, because git -C runs there.
    $tracked = @(git -C $dir -c core.quotePath=false ls-files --cached -- . 2>$null)
    if ($LASTEXITCODE -ne 0) { throw "$leaf is not inside a git work tree; the tracked set is what gets packed." }
    if (-not $tracked) { throw "$leaf has no tracked files; there would be nothing to ship." }
    # A tracked path with no file behind it means the working tree is mid-delete. Packing around it
    # would ship a mod missing a file that every other check still sees. Checked here, not while
    # zipping, so the mod is refused before any zip is written.
    $missing = @($tracked | Where-Object { -not (Test-Path -LiteralPath (Join-Path $dir $_) -PathType Leaf) })
    if ($missing) {
        throw "$leaf/$($missing[0]) is tracked but not on disk. Commit the deletion or restore the file before packing."
    }
    $untracked = @(git -C $dir -c core.quotePath=false ls-files --others --exclude-standard -- .)

    [pscustomobject]@{
        Name      = $info.name
        Version   = $info.version
        Directory = $dir
        ZipName   = "$($info.name)_$($info.version).zip"
        Files     = $tracked
        Untracked = $untracked
    }
}

function Write-ModZip {
    <#  Write one mod's zip, every entry under a single top-level folder named after the mod, then
        delete every other version's zip of it beside the new one.  #>
    param(
        [Parameter(Mandatory)] [pscustomobject] $Manifest,
        [Parameter(Mandatory)] [string]         $Destination
    )

    # Built under a temporary name and moved into place only on success. Disposing a ZipArchive
    # writes a valid central directory whatever happened before it, so a read failure partway
    # through the loop -- a file deleted since Get-ModManifest looked -- would otherwise leave a zip
    # that opens cleanly and is quietly missing every file after the failure point. An artefact
    # that looks finished and is not is worse than no artefact.
    $partial = "$Destination.partial"
    if (Test-Path -LiteralPath $partial) { Remove-Item -LiteralPath $partial -Force }

    $zip = [IO.Compression.ZipFile]::Open($partial, 'Create')
    try {
        foreach ($rel in $Manifest.Files) {
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $zip, (Join-Path $Manifest.Directory $rel), "$($Manifest.Name)/$rel", [IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    }
    catch {
        $zip.Dispose()
        Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
        throw
    }
    $zip.Dispose()

    if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Force }
    Move-Item -LiteralPath $partial -Destination $Destination

    $pattern = '^' + [regex]::Escape($Manifest.Name) + '_\d+\.\d+\.\d+\.zip$'
    Get-ChildItem -LiteralPath (Split-Path $Destination -Parent) -File |
        Where-Object { $_.Name -cmatch $pattern -and $_.Name -cne $Manifest.ZipName } |
        ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
}

function Invoke-Pack {
    <#  Pack every mod directory into $Destination and return what was written. Every manifest is
        read before any zip is written, so a refused mod stops the run with nothing packed.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string[]] $Directory,
        [Parameter(Mandatory)] [string]   $Destination,
        [switch] $Quiet
    )

    $manifests = @($Directory | ForEach-Object { Get-ModManifest -Directory $_ })
    # Case-insensitive on purpose: `alpha` and `Alpha` are two mods, but at one version their zips
    # are one file on a case-insensitive file system (see the header).
    $twice = @($manifests | Group-Object Name | Where-Object Count -gt 1 | ForEach-Object Name)
    if ($twice) { throw "given more than once: $($twice -join ', '). One copy per mod means the second would delete the first." }

    # Resolved to a full path, because the .NET zip calls resolve a relative one against the
    # process's directory, which is not PowerShell's location after a Set-Location.
    $Destination = (New-Item -ItemType Directory -Path $Destination -Force).FullName
    $built = @()
    foreach ($m in $manifests) {
        if ($m.Untracked) {
            Write-Warning "$($m.Name) has $($m.Untracked.Count) untracked file(s), which will NOT be in the zip:"
            foreach ($u in $m.Untracked | Select-Object -First 5) { Write-Warning "    $u" }
        }
        $path = Join-Path $Destination $m.ZipName
        Write-ModZip -Manifest $m -Destination $path
        $built += [pscustomobject]@{
            Mod   = $m.Name
            Zip   = $path
            Files = $m.Files.Count
            Bytes = (Get-Item -LiteralPath $path).Length
        }
    }

    if (-not $Quiet) {
        $total = ($built | Measure-Object -Property Bytes -Sum).Sum
        foreach ($b in $built) {
            Write-Host ("{0,-44} {1,5} files{2,10}" -f (Split-Path $b.Zip -Leaf), $b.Files, (Format-Bytes $b.Bytes))
        }
        Write-Host ("{0,-44} {1,11}{2,10}" -f '', '', (Format-Bytes $total))
    }
    return $built
}

function Format-Bytes {
    <#  Invariant culture on purpose: these figures get quoted in ADRs and issues, and a decimal
        comma on one machine against a point on another is noise in a number people compare.  #>
    param([long] $Bytes)
    $c = [cultureinfo]::InvariantCulture
    if ($Bytes -ge 1MB) { return ((($Bytes / 1MB)).ToString('N1', $c) + ' MB') }
    if ($Bytes -ge 1KB) { return ((($Bytes / 1KB)).ToString('N0', $c) + ' KB') }
    return "$Bytes B"
}

function Invoke-SelfTest {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "pack-mods-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    $repo = Join-Path $temp 'repo'
    $out = Join-Path $temp 'out'
    $put = {
        param($rel, $body)
        $p = Join-Path $repo $rel
        New-Item -ItemType Directory -Path (Split-Path $p -Parent) -Force | Out-Null
        Set-Content -LiteralPath $p -Value $body -NoNewline
    }
    # Every info.json built by $info carries an empty key, as fluid-connection-indicators 0.2.9's
    # `package` table does: valid JSON that ConvertFrom-Json refuses without -AsHashtable. So every
    # mod a case packs or refuses holds one, and case 1 fails if Get-ModManifest again cannot read
    # one. The exception is epsilon, whose info.json is written whole because its case is the file's
    # shape: a key in the wrong case, or no object at all.
    $info = { param($name, $version) "{`"name`":`"$name`",`"version`":`"$version`",`"package`":{`"`":`"`"}}" }
    $entries = {
        param($zip)
        $a = [IO.Compression.ZipFile]::OpenRead($zip)
        try { @($a.Entries | ForEach-Object FullName) } finally { $a.Dispose() }
    }
    $refused = {
        param([scriptblock] $act, [string] $pattern)
        try { & $act | Out-Null; $false } catch { $_.Exception.Message -match $pattern }
    }

    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    git -C $repo init --quiet
    if ($LASTEXITCODE -ne 0) { throw 'git init failed; the self-test needs git.' }
    & $put '.gitignore' '.omc/'
    & $put 'alpha/info.json' (& $info 'alpha' '1.2.3')
    & $put 'alpha/prototypes/entities.lua' 'return {}'
    & $put 'beta/info.json' (& $info 'beta' '0.1.0')
    & $put 'beta/data.lua' '-- beta'
    & $put 'gamma/info.json' (& $info 'gamma' '1.0.0')
    & $put 'misnamed/info.json' (& $info 'somebody-else' '1.0.0')
    & $put 'Delta/info.json' (& $info 'delta' '1.0.0')
    git -C $repo add -A
    # After the add, so neither is tracked. The plant is IGNORED, not merely untracked, or it
    # demonstrates the wrong thing: ls-files --cached leaves out untracked files too, so an
    # untracked plant would be absent from the zip without the ignore rule doing any work.
    & $put 'alpha/prototypes/.omc/state/selftest-junk.json' '{"selftest":true}'
    & $put 'alpha/stray.lua' '-- untracked'
    # An uncommitted edit to a tracked file, which must be packed as it stands on disk.
    & $put 'beta/data.lua' '-- beta, edited'
    $alpha = Join-Path $repo 'alpha'
    $beta = Join-Path $repo 'beta'
    $gamma = Join-Path $repo 'gamma'

    $cases = @(
        @{ Name = 'each zip is <name>_<version>.zip, every entry under one top-level folder holding info.json, which may hold an empty key'; Test = {
            $b = @(Invoke-Pack -Directory $alpha, $beta -Destination $out -Quiet -WarningAction SilentlyContinue)
            $names = @($b | ForEach-Object { Split-Path $_.Zip -Leaf })
            $a = & $entries $b[0].Zip
            ($names -join ',') -eq 'alpha_1.2.3.zip,beta_0.1.0.zip' -and $a -contains 'alpha/info.json' -and
                -not ($a | Where-Object { $_ -notlike 'alpha/*' }) } }
        @{ Name = 'a relative -OutputDirectory resolves against PowerShell''s location, not the process''s'; Test = {
            Push-Location -LiteralPath $temp
            try { Invoke-Pack -Directory $gamma -Destination 'relative-out' -Quiet | Out-Null } finally { Pop-Location }
            Test-Path -LiteralPath (Join-Path $temp 'relative-out/gamma_1.0.0.zip') } }
        @{ Name = 'the plant is git-ignored, so the next case tests the ignore rule and not mere untracking'; Test = {
            $ignored = @(git -C $alpha -c core.quotePath=false ls-files --others --ignored --exclude-standard -- .)
            $ignored -contains 'prototypes/.omc/state/selftest-junk.json' } }
        @{ Name = 'the ignored plant is not packed; its tracked neighbour is'; Test = {
            $a = & $entries (Join-Path $out 'alpha_1.2.3.zip')
            -not ($a | Where-Object { $_ -like '*selftest-junk.json' }) -and $a -contains 'alpha/prototypes/entities.lua' } }
        @{ Name = 'an untracked file is reported as a warning and not packed'; Test = {
            Invoke-Pack -Directory $alpha -Destination $out -Quiet -WarningVariable w -WarningAction SilentlyContinue | Out-Null
            $a = & $entries (Join-Path $out 'alpha_1.2.3.zip')
            ($w -join ' ') -match '1 untracked file' -and ($w -join ' ') -match 'stray\.lua' -and $a -notcontains 'alpha/stray.lua' } }
        @{ Name = 'an uncommitted edit is packed from the working tree'; Test = {
            $a = [IO.Compression.ZipFile]::OpenRead((Join-Path $out 'beta_0.1.0.zip'))
            try { $r = [IO.StreamReader]::new($a.GetEntry('beta/data.lua').Open()); $text = $r.ReadToEnd(); $r.Dispose() }
            finally { $a.Dispose() }
            $text -eq '-- beta, edited' } }
        @{ Name = 'versions the portal rejects are refused: not x.y.z, a component above 65535, 0.0.0'; Test = {
            $all = foreach ($v in @(@('1.0', 'not major.minor.sub'), @('1.2.3.4', 'not major.minor.sub'),
                    @('1.65536.0', 'above 65535'), @('0.0.0', '0\.0\.0'))) {
                & $put 'gamma/info.json' (& $info 'gamma' $v[0])
                & $refused { Invoke-Pack -Directory $gamma -Destination $out -Quiet } $v[1]
            }
            -not ($all -contains $false) } }
        @{ Name = 'the bounds themselves are accepted: 65535.65535.65535 and 0.0.1'; Test = {
            $ok = foreach ($v in '65535.65535.65535', '0.0.1') {
                & $put 'gamma/info.json' (& $info 'gamma' $v)
                (Split-Path (Invoke-Pack -Directory $gamma -Destination $out -Quiet).Zip -Leaf) -eq "gamma_$v.zip"
            }
            -not ($ok -contains $false) } }
        @{ Name = 'repacking at any version leaves one zip of the mod; a neighbour whose name only contains it stays'; Test = {
            foreach ($n in 'alpha_0.9.0.zip', 'alpha_9.9.9.zip', 'alpha_extra_1.0.0.zip', 'alpha-2_1.0.0.zip', 'my-alpha_1.0.0.zip') {
                Set-Content -LiteralPath (Join-Path $out $n) -Value 'old'
            }
            Invoke-Pack -Directory $alpha -Destination $out -Quiet -WarningAction SilentlyContinue | Out-Null
            $left = @(Get-ChildItem -LiteralPath $out -Filter '*alpha*' | ForEach-Object Name | Sort-Object)
            ($left -join ',') -eq 'alpha_1.2.3.zip,alpha_extra_1.0.0.zip,alpha-2_1.0.0.zip,my-alpha_1.0.0.zip' } }
        @{ Name = 'a directory whose name is not info.json''s name is refused'; Test = {
            & $refused { Invoke-Pack -Directory (Join-Path $repo 'misnamed') -Destination $out -Quiet } "declares name 'somebody-else'" } }
        @{ Name = 'an info.json spelling a key "Name" or "Version" is refused as missing that key, not as an empty value; one that is not an object is refused by name'; Test = {
            # The new message alone would prove the wording; the old one is named too, so the case
            # fails if a refusal ever says both.
            $all = foreach ($k in @(@('{"Name":"epsilon","version":"1.0.0"}', 'name'), @('{"name":"epsilon","Version":"1.0.0"}', 'version'))) {
                & $put 'epsilon/info.json' $k[0]
                $m = try { Invoke-Pack -Directory (Join-Path $repo 'epsilon') -Destination $out -Quiet | Out-Null; '' } catch { $_.Exception.Message }
                $m -match "epsilon/info\.json has no ""$($k[1])"" key, which Factorio 2\.0\.77 requires" -and $m -notmatch "declares name ''|version '' is not"
            }
            $notObject = foreach ($j in 'null', '[1]', '[{"name":"epsilon","version":"1.0.0"}]') {
                & $put 'epsilon/info.json' $j
                & $refused { Invoke-Pack -Directory (Join-Path $repo 'epsilon') -Destination $out -Quiet } 'epsilon/info\.json is not a JSON object'
            }
            -not ($all -contains $false) -and -not ($notObject -contains $false) } }
        @{ Name = 'names are compared case-sensitively by both halves: a case-only mismatch is refused, and another case''s zip stays'; Test = {
            # Both halves in one case, so either one going case-insensitive on its own turns it red.
            # On a case-insensitive file system the path is also passed in the wrong case, which
            # proves the directory's name is read from disk and not from how it was typed.
            $delta = @(Join-Path $repo 'Delta') + @(Join-Path $repo 'delta' | Where-Object { Test-Path -LiteralPath $_ })
            $nameCheck = foreach ($d in $delta) { & $refused { Invoke-Pack -Directory $d -Destination $out -Quiet } "Delta/info.json declares name 'delta'" }
            Set-Content -LiteralPath (Join-Path $out 'Alpha_0.9.0.zip') -Value 'another mod, to Factorio'
            Invoke-Pack -Directory $alpha -Destination $out -Quiet -WarningAction SilentlyContinue | Out-Null
            -not ($nameCheck -contains $false) -and
                (Get-ChildItem -LiteralPath $out -File | Where-Object Name -ceq 'Alpha_0.9.0.zip') } }
        @{ Name = 'a mod directory outside any git work tree is refused'; Test = {
            $loose = Join-Path $temp 'loose'
            New-Item -ItemType Directory -Path $loose -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $loose 'info.json') -Value (& $info 'loose' '1.0.0')
            & $refused { Invoke-Pack -Directory $loose -Destination $out -Quiet } 'not inside a git work tree' } }
        @{ Name = 'the same mod given twice is refused'; Test = {
            & $refused { Invoke-Pack -Directory $beta, $beta -Destination $out -Quiet } 'given more than once: beta' } }
        @{ Name = 'a refused mod stops the run before any zip is written'; Test = {
            & $put 'gamma/info.json' (& $info 'gamma' '0.0.0')
            Remove-Item -LiteralPath (Join-Path $out 'beta_0.1.0.zip')
            (& $refused { Invoke-Pack -Directory $beta, $gamma -Destination $out -Quiet } '0\.0\.0') -and
                -not (Test-Path -LiteralPath (Join-Path $out 'beta_0.1.0.zip')) } }
        @{ Name = 'a tracked file missing from disk is refused before any mod is packed; earlier zips stay'; Test = {
            & $put 'gamma/info.json' (& $info 'gamma' '1.0.0')
            & $put 'beta/info.json' (& $info 'beta' '0.2.0')
            Set-Content -LiteralPath (Join-Path $out 'beta_0.1.0.zip') -Value 'earlier'
            Remove-Item -LiteralPath (Join-Path $beta 'data.lua')
            (& $refused { Invoke-Pack -Directory $gamma, $beta -Destination $out -Quiet } 'beta/data\.lua is tracked but not on disk') -and
                -not (Get-ChildItem -LiteralPath $out -Filter '*_*.partial') -and
                -not (Test-Path -LiteralPath (Join-Path $out 'gamma_1.0.0.zip')) -and
                (Test-Path -LiteralPath (Join-Path $out 'gamma_0.0.1.zip')) -and
                -not (Get-ChildItem -LiteralPath $out -Filter 'beta_0.2.0*') -and (Test-Path -LiteralPath (Join-Path $out 'beta_0.1.0.zip')) } }
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
if (-not $ModDirectory -or -not $OutputDirectory) { throw 'Give -OutputDirectory and one or more mod directories, or -SelfTest.' }

$built = Invoke-Pack -Directory $ModDirectory -Destination $OutputDirectory
Write-Host ''
Write-Host "wrote $($built.Count) zip(s) to $OutputDirectory. Nothing is uploaded and no version is changed."
exit 0
