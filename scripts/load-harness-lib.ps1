#Requires -Version 7
<#
    The load harness as functions, for a caller that runs its own checks on a loaded game.
    Dot-source it:

        . "$PSScriptRoot/load-harness-lib.ps1"
        $h = New-LoadHarness -Mods .mod-cache/krastorio2, ./my-mod -FactorioExe $exe
        try {
            $load = Invoke-HarnessLoad -Harness $h
            if ($load.Loaded) { $dump = Invoke-HarnessDump -Harness $h -Tag 'loaded' }
        }
        finally { Remove-LoadHarness -Harness $h }

    load-harness.ps1 is the same thing as a command, for a caller with no checks of its own.

    WHERE IT CAME FROM. realistic-fusion-refreshed's load-check.ps1 and factorio-lib.ps1, at
    19e2d92 (grado-factorio-tools#16). The harness moved and the invariants did not: everything
    here is what that script did around its checks -- build an isolated mod directory, junction or
    copy the mods in, write the mod list, create a throwaway map, report which way it went. The
    functions taken from factorio-lib.ps1 keep their names and code, with some doc comments
    trimmed to what is true outside that repository; New-ModJunctions takes
    source paths rather than a repository root, and the harness functions are new.

    IT NEVER TOUCHES THE PLAYER'S GAME. Mods go into a mod directory under a temp directory, and
    every run gets a write-data directory of its own there (Invoke-Factorio), so the player's mods,
    mod-list.json, saves and player-data.json are neither read nor written. Mod directories are
    junctioned in rather than copied, and zips are copied, so Remove-LoadHarness deletes the
    junctions before the directory.

    WHAT IT CANNOT SEE, as a harness. A load validates prototypes and runs on_init; it loads no
    sprites or sounds and runs no ticks. Invoke-HarnessLoad reports Loaded and the game's error
    text; what a pass should also require is the caller's to check.

    PowerShell 7 is required: 5.1's Remove-Item -Recurse follows junctions instead of skipping
    them, which would delete a mod's source through the link. Junctions make this Windows-only.
#>

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Resolve-FactorioExe {
    <#  Preferred path, then $env:FACTORIO_EXE, then the Steam path on the machine this was written
        on -- which on any other machine means: pass one of the first two.  #>
    param([string] $Path)

    if (-not $Path) { $Path = $env:FACTORIO_EXE }
    if (-not $Path) { $Path = 'D:\SteamLibrary\steamapps\common\Factorio\bin\x64\Factorio.exe' }
    if (-not (Test-Path $Path)) {
        throw "Factorio.exe not found at '$Path'. Pass -FactorioExe or set `$env:FACTORIO_EXE."
    }
    return (Resolve-Path $Path).Path
}

function Get-FactorioDataDirectory {
    <#  <install>\bin\x64\Factorio.exe -> <install>\data, where base and core live.  #>
    param([Parameter(Mandatory)] [string] $FactorioExe)

    $dataDir = Join-Path (Split-Path (Split-Path (Split-Path $FactorioExe -Parent) -Parent) -Parent) 'data'
    if (-not (Test-Path $dataDir)) { throw "Factorio data directory not found at '$dataDir'." }
    return $dataDir
}

function ConvertTo-NativeArgument {
    <#  Quote one argument for a native Windows command line.

        Start-Process -ArgumentList joins an array with spaces and quotes nothing, so a path
        containing a space arrives as several arguments. "C:\Users\Jo Smith\mods" reaches the exe
        as "C:\Users\Jo" plus a stray "Smith\mods" -- which means Factorio running against a mod
        directory that has none of the junctions in it.

        Windows parses backslashes literally except where they precede a quote, so a run of them
        at the end of the value has to be doubled before the closing quote or it escapes it.  #>
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Value)

    $escaped = $Value -replace '(\\+)$', '$1$1'
    $escaped = $escaped -replace '"', '\"'
    return '"' + $escaped + '"'
}

function Invoke-Factorio {
    <#  Run Factorio headless against a mod directory, capturing both streams to files.

        Returns the exit code and the two capture paths; it deliberately decides nothing about
        what a failure means, because callers disagree -- a load check treats a non-zero exit as
        the answer it went looking for, a bench treats it as the run being over.

        Runs in its own write-data directory, so it works while the game is open -- see below.

        Factorio.exe is a GUI-subsystem binary: the call operator does not wait for it and leaves
        $LASTEXITCODE unset, so the exit code has to come from the process object. That rules out
        native invocation, and so requires the quoting that ConvertTo-NativeArgument does.  #>
    param(
        [Parameter(Mandatory)] [string]   $FactorioExe,
        [Parameter(Mandatory)] [string]   $ModDirectory,
        [Parameter(Mandatory)] [string[]] $Arguments,
        [Parameter(Mandatory)] [string]   $OutputDirectory,
        [Parameter(Mandatory)] [string]   $Tag
    )

    $outFile = Join-Path $OutputDirectory "$Tag-stdout.txt"
    $errFile = Join-Path $OutputDirectory "$Tag-stderr.txt"

    # Factorio takes an exclusive lock on its write-data directory, so any headless run fails
    # outright while the game is open. That matters more than it sounds: the failure text is
    # "Is another instance already running?" buried in the captured stdout, and to a caller
    # checking only the exit code it is indistinguishable from a rejected prototype. It cost two
    # wrong conclusions in a row before anyone noticed the game was simply running.
    #
    # So every run gets a write-data directory of its own, inside the caller's temp directory and
    # thrown away with it. --mod-directory still wins for mods; this only moves the lock, the
    # player-data and the log.
    $configPath = Join-Path $OutputDirectory 'factorio-config.ini'
    if (-not (Test-Path $configPath)) {
        $writeData = Join-Path $OutputDirectory 'write-data'
        New-Item -ItemType Directory -Path $writeData -Force | Out-Null
        # read-data is the stock default; only write-data moves.
        @"
[path]
read-data=__PATH__executable__/../../data
write-data=$writeData
"@ | Set-Content -Path $configPath -Encoding utf8
    }

    $line = (@('--config', $configPath, '--mod-directory', $ModDirectory) + $Arguments |
        ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' '

    $proc = Start-Process -FilePath $FactorioExe -ArgumentList $line `
        -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput $outFile -RedirectStandardError $errFile

    [pscustomobject]@{ Code = $proc.ExitCode; OutFile = $outFile; ErrFile = $errFile }
}

function Write-FactorioTail {
    <#  Print the end of each captured stream from an Invoke-Factorio result.

        Tailed separately rather than interleaved: Factorio's stdout runs to hundreds of lines and
        would otherwise push every stderr line out of a shared window.  #>
    param(
        [Parameter(Mandatory)] [object] $Result,
        [int] $Lines = 20
    )

    foreach ($f in @($Result.ErrFile, $Result.OutFile)) {
        if (-not (Test-Path $f)) { continue }
        $captured = Get-Content $f -ErrorAction SilentlyContinue | Where-Object { $_ -match '\S' }
        if (-not $captured) { continue }
        Write-Host "  --- $(Split-Path $f -Leaf) (last $Lines of $($captured.Count)) ---"
        $captured | Select-Object -Last $Lines | ForEach-Object { Write-Host "    $_" }
    }
}

function Remove-TempDirectory {
    <#  Delete a temporary directory, retrying briefly.

        Factorio can hold a save open for a moment after exiting, so a single Remove-Item loses
        the race often enough to leak the directory silently. Always call Remove-ModJunctions
        first: under PowerShell 5.1 this would follow junctions rather than skip them.  #>
    param(
        [Parameter(Mandatory)] [string] $Path,
        [string] $Label = 'cleanup'
    )

    if (-not (Test-Path $Path)) { return }
    foreach ($attempt in 1..5) {
        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path $Path)) { return }
        Start-Sleep -Milliseconds 200
    }
    Write-Warning "${Label}: could not remove temp directory $Path"
}

function Get-BundledMods {
    <#  Mods shipped inside the game's data/ directory -- space-age, elevated-rails, quality and
        anything a future version adds. They are present whatever --mod-directory points at, so
        they load unless explicitly disabled. Discovered rather than hardcoded, so the list
        cannot go stale. base and core are not optional and are excluded.

        Returns a hashtable of mod name -> parsed info.json.  #>
    param([Parameter(Mandatory)] [string] $FactorioExe)

    $dataDir = Get-FactorioDataDirectory -FactorioExe $FactorioExe

    $bundled = @{}
    Get-ChildItem -Path $dataDir -Directory |
        Where-Object { $_.Name -notin @('base', 'core') -and (Test-Path (Join-Path $_.FullName 'info.json')) } |
        ForEach-Object { $bundled[$_.Name] = (Get-Content (Join-Path $_.FullName 'info.json') -Raw | ConvertFrom-Json) }
    return $bundled
}

function Resolve-BundledSelection {
    <#  Canonicalise the requested names and close over their hard dependencies.

        Both halves matter. space-age hard-depends on elevated-rails and quality, so enabling it
        alone writes a mod-list whose dependencies are explicitly disabled -- Factorio then fails
        on the missing dependency and it reads as the mods under test being broken. And an unknown
        name must be rejected rather than ignored, or a typo produces a base-only run that gets
        reported as an expansion pass.

        CASE MATTERS HERE and is why this is one implementation. PowerShell's -in, -notin and its
        hashtables are case-insensitive, while HashSet[string] is ordinal, so an uncanonicalised
        name validates, then silently fails to match, then gets written disabled while the caller
        reports it as enabled.

        Returns canonical names as a string array (empty when nothing was requested).  #>
    param(
        [string[]]   $Requested,
        [Parameter(Mandatory)] [hashtable] $Bundled
    )

    $requested = @($Requested | Where-Object { $_ })
    if (-not $requested) { return @() }

    $unknown = $requested | Where-Object { $_ -notin $Bundled.Keys }
    if ($unknown) {
        throw ("names no bundled mod: {0}. Available: {1}." -f
            ($unknown -join ', '), (($Bundled.Keys | Sort-Object) -join ', '))
    }

    $canonical = { param($n) $Bundled.Keys | Where-Object { $_ -eq $n } | Select-Object -First 1 }

    $enabled = [System.Collections.Generic.HashSet[string]]::new()
    $queue = [System.Collections.Queue]::new()
    foreach ($r in $requested) { $queue.Enqueue((& $canonical $r)) }

    while ($queue.Count -gt 0) {
        $m = $queue.Dequeue()
        if (-not $m -or -not $enabled.Add($m)) { continue }
        foreach ($dep in @($Bundled[$m].dependencies)) {
            # Skip optional ("?"), hidden-optional ("(?)") and incompatible ("!") only. "~" is a
            # REQUIRED dependency that merely does not affect load order, so it must be followed.
            if ($dep -match '^\s*[?!(]') { continue }
            $name = (($dep -replace '^\s*~?\s*', '') -split '\s+' | Select-Object -First 1)
            $c = & $canonical $name
            if ($c) { $queue.Enqueue($c) }
        }
    }
    return @($enabled | Sort-Object)
}

function Write-ModList {
    <#  Write mod-list.json enabling base, the given mods, and exactly the bundled mods in
        $EnabledBundled -- every other bundled mod is written explicitly disabled.

        OMITTING A MOD DOES NOT KEEP IT OUT, and that is the whole reason $Disabled exists.
        Factorio AUTO-ENABLES a mod present in the mod directory but absent from mod-list.json, so
        a list naming only some of what is on disk loads all of it. Name what must stay out; do not
        merely leave it unnamed.  #>
    param(
        [Parameter(Mandatory)] [string]    $ModDirectory,
        [Parameter(Mandatory)] [hashtable] $Bundled,
        [string[]] $EnabledBundled = @(),
        [string[]] $Mods = @(),
        [string[]] $Disabled = @()
    )

    # A name in both lists is a caller fault rather than a precedence question: Factorio reads the
    # last entry for a name and nothing here should depend on knowing that.
    $both = @($Mods | Where-Object { $Disabled -contains $_ })
    if ($both) {
        throw "Write-ModList: $($both -join ', ') given as both enabled and disabled."
    }

    $entries = @(@{ name = 'base'; enabled = $true })
    foreach ($m in ($Bundled.Keys | Sort-Object)) {
        $entries += @{ name = $m; enabled = [bool]($EnabledBundled -contains $m) }
    }
    foreach ($m in $Mods) { $entries += @{ name = $m; enabled = $true } }
    foreach ($m in $Disabled) { $entries += @{ name = $m; enabled = $false } }

    @{ mods = $entries } | ConvertTo-Json -Depth 4 |
        Set-Content -Path (Join-Path $ModDirectory 'mod-list.json') -Encoding utf8
}

function New-ModJunctions {
    <#  Link mod directories into a mod directory, each under the name given. Junctions rather than
        copies: no admin rights needed, nothing duplicated, and edits to the source are picked up
        live. $Links maps a link name to the directory it points at.  #>
    param(
        [Parameter(Mandatory)] [string]    $ModDirectory,
        [Parameter(Mandatory)] [hashtable] $Links
    )

    foreach ($name in $Links.Keys) {
        # ABSOLUTE, BECAUSE A JUNCTION TARGET MUST BE: New-Item refuses a relative one.
        $src = (Resolve-Path -LiteralPath $Links[$name]).Path
        $link = Join-Path $ModDirectory $name
        if (Test-Path $link) {
            # Only ever delete a junction here. A real directory of the same name -- an unzipped
            # release, a leftover copy -- would otherwise hit a non-recursive Directory.Delete and
            # either throw an opaque "directory is not empty" or, if empty, vanish silently.
            $existing = Get-Item -LiteralPath $link -Force
            if ($existing.LinkType -ne 'Junction') {
                throw "Refusing to replace '$link': it is a real directory, not a junction. Move or delete it yourself."
            }
            [IO.Directory]::Delete($link)
        }
        New-Item -ItemType Junction -Path $link -Target $src | Out-Null
    }
}

function Remove-ModJunctions {
    <#  Delete the junction entries themselves. Always call this before removing a directory that
        contains them: PowerShell 5.1's Remove-Item -Recurse follows junctions rather than
        skipping them, and would delete the source through the link.  #>
    param([Parameter(Mandatory)] [string] $ModDirectory)

    Get-ChildItem -Path $ModDirectory -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.LinkType -eq 'Junction' } |
        ForEach-Object { [IO.Directory]::Delete($_.FullName) }
}

function Get-HarnessMods {
    <#  The mods a set of paths holds, as Name, Version, Kind (directory or zip) and Path.

        Each path is a mod directory (it holds an info.json), a mod zip, or a directory of those --
        which is what fetch-mods.ps1's cache is. In a directory of mods, anything that is neither is
        ignored, so the cache's `.zips` and staging directories are passed over. Name and version
        come from the mod's own info.json, never from a file or directory name.

        An empty directory is an error, not an empty set: a load of nothing would otherwise be
        reported as a pass for mods that were never loaded. So is one name found twice.  #>
    param([Parameter(Mandatory)] [string[]] $Path)

    $readInfo = {
        param($item)
        if ($item -is [IO.FileInfo]) {
            $zip = [IO.Compression.ZipFile]::OpenRead($item.FullName)
            try {
                $entry = $zip.Entries | Where-Object { $_.FullName -match '^[^/]+/info\.json$' } | Select-Object -First 1
                if (-not $entry) { throw "$($item.FullName) holds no <folder>/info.json, so it is not a mod zip." }
                $reader = [IO.StreamReader]::new($entry.Open())
                try { $info = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
            }
            finally { $zip.Dispose() }
            $kind = 'zip'
        }
        else {
            $info = Get-Content -LiteralPath (Join-Path $item.FullName 'info.json') -Raw | ConvertFrom-Json
            $kind = 'directory'
        }
        [pscustomobject]@{ Name = $info.name; Version = $info.version; Kind = $kind; Path = $item.FullName }
    }
    $isMod = { param($i) ($i -is [IO.FileInfo] -and $i.Extension -eq '.zip') -or
                         ($i -is [IO.DirectoryInfo] -and (Test-Path -LiteralPath (Join-Path $i.FullName 'info.json'))) }

    $found = foreach ($p in $Path) {
        if (-not (Test-Path -LiteralPath $p)) { throw "No mod or mod directory at $p." }
        $item = Get-Item -LiteralPath $p
        if (& $isMod $item) { & $readInfo $item; continue }
        if ($item -isnot [IO.DirectoryInfo]) { throw "$p is neither a mod directory, a mod zip, nor a directory of them." }
        $children = @(Get-ChildItem -LiteralPath $item.FullName | Where-Object { & $isMod $_ })
        if (-not $children) { throw "$p holds no mods: no directory with an info.json in it, and no zip." }
        foreach ($c in $children) { & $readInfo $c }
    }

    $twice = @($found | Group-Object Name | Where-Object Count -gt 1)
    if ($twice) {
        throw ("One mod name, two sources -- a load can hold only one: " +
            (($twice | ForEach-Object { "$($_.Name) at $(($_.Group.Path) -join ' and ')" }) -join '; '))
    }
    return @($found | Sort-Object Name)
}

function New-LoadHarness {
    <#  An isolated mod directory under a new temp directory, holding the mods -Mods names.

        Directories are junctioned in under their mod name; zips are copied in as
        <name>_<version>.zip. Returns the harness: Temp, ModDirectory, FactorioExe, Bundled,
        EnabledBundled and Mods (Get-HarnessMods' rows), for the other functions here and for a
        caller's own checks.  #>
    param(
        [Parameter(Mandatory)] [string[]] $Mods,
        [string]   $FactorioExe,
        [string[]] $With = @()
    )

    $exe = Resolve-FactorioExe -Path $FactorioExe
    $bundled = Get-BundledMods -FactorioExe $exe
    try { $enabledBundled = Resolve-BundledSelection -Requested $With -Bundled $bundled }
    catch { throw "-With $($_.Exception.Message)" }
    $rows = Get-HarnessMods -Path $Mods

    $temp = Join-Path ([IO.Path]::GetTempPath()) ('load-harness-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $modDir = Join-Path $temp 'mods'
    New-Item -ItemType Directory -Path $modDir -Force | Out-Null

    $harness = [pscustomobject]@{
        Temp = $temp; ModDirectory = $modDir; FactorioExe = $exe
        Bundled = $bundled; EnabledBundled = $enabledBundled; Mods = $rows
    }
    try {
        $links = @{}
        foreach ($r in $rows) {
            if ($r.Kind -eq 'directory') { $links[$r.Name] = $r.Path }
            else { Copy-Item -LiteralPath $r.Path -Destination (Join-Path $modDir "$($r.Name)_$($r.Version).zip") }
        }
        if ($links.Count) { New-ModJunctions -ModDirectory $modDir -Links $links }
    }
    catch { Remove-LoadHarness -Harness $harness; throw }
    return $harness
}

function Get-FactorioErrorText {
    <#  The game's own account of why a run failed, out of its captured stdout: from the first
        line Factorio logs as an Error to the end, which is where it prints the mod, the
        prototype and the reason. Empty when it logged no error.  #>
    param([Parameter(Mandatory)] [object] $Result)

    if (-not (Test-Path -LiteralPath $Result.OutFile)) { return @() }
    $lines = @(Get-Content -LiteralPath $Result.OutFile | Where-Object { $_ -match '\S' })
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*\d+\.\d+\s+Error\b') { return @($lines[$i..($lines.Count - 1)]) }
    }
    return @()
}

function Invoke-HarnessLoad {
    <#  Enable every harness mod (less -Disabled), create a throwaway map, and say whether it
        loaded. Creating a map runs every mod's on_init, so a mod that refuses itself at start-up
        fails here as well as one whose prototypes do not validate.

        Loaded means Factorio exited 0 AND wrote the save: "exit 0 but no save" is a failure.
        ErrorText is Get-FactorioErrorText's, for a failed load.  #>
    param(
        [Parameter(Mandatory)] [object] $Harness,
        [string[]] $Disabled = @(),
        [string] $Tag = 'load'
    )

    $enabled = @($Harness.Mods.Name | Where-Object { $_ -notin $Disabled })
    $off = @($Harness.Mods.Name | Where-Object { $_ -in $Disabled })
    Write-ModList -ModDirectory $Harness.ModDirectory -Bundled $Harness.Bundled `
        -EnabledBundled $Harness.EnabledBundled -Mods $enabled -Disabled $off

    $save = Join-Path $Harness.Temp "$Tag.zip"
    Remove-Item -LiteralPath $save -Force -ErrorAction SilentlyContinue
    $result = Invoke-Factorio -FactorioExe $Harness.FactorioExe -ModDirectory $Harness.ModDirectory `
        -Arguments @('--create', $save) -OutputDirectory $Harness.Temp -Tag $Tag
    $saved = Test-Path -LiteralPath $save

    [pscustomobject]@{
        Loaded    = $result.Code -eq 0 -and $saved
        Code      = $result.Code
        SavePath  = if ($saved) { $save } else { $null }
        OutFile   = $result.OutFile
        ErrFile   = $result.ErrFile
        ErrorText = if ($result.Code -ne 0) { @(Get-FactorioErrorText -Result $result) } else { @() }
    }
}

function Invoke-HarnessDump {
    <#  Run --dump-data with every harness mod enabled (less -Disabled) and return the path of the
        dump, kept aside under -Tag. Throws if Factorio fails or writes no dump.

        THE DUMP PATH IS DELETED FIRST, NOT MERELY OVERWRITTEN. Every dump in a run writes the one
        path, so a run that exits 0 without writing would leave the PREVIOUS dump there to be read
        as this one. Kept aside because the next dump overwrites that path.  #>
    param(
        [Parameter(Mandatory)] [object] $Harness,
        [Parameter(Mandatory)] [string] $Tag,
        [string[]] $Disabled = @()
    )

    $raw = Join-Path $Harness.Temp 'write-data/script-output/data-raw-dump.json'
    Remove-Item -LiteralPath $raw -Force -ErrorAction SilentlyContinue

    $enabled = @($Harness.Mods.Name | Where-Object { $_ -notin $Disabled })
    $off = @($Harness.Mods.Name | Where-Object { $_ -in $Disabled })
    Write-ModList -ModDirectory $Harness.ModDirectory -Bundled $Harness.Bundled `
        -EnabledBundled $Harness.EnabledBundled -Mods $enabled -Disabled $off
    $result = Invoke-Factorio -FactorioExe $Harness.FactorioExe -ModDirectory $Harness.ModDirectory `
        -Arguments @('--dump-data') -OutputDirectory $Harness.Temp -Tag $Tag
    if ($result.Code -ne 0) {
        Write-FactorioTail $result
        throw "Factorio exited $($result.Code) on --dump-data for the $Tag dump."
    }
    if (-not (Test-Path -LiteralPath $raw)) { throw "Factorio exited 0 but wrote no data-raw-dump.json for the $Tag dump." }
    $kept = Join-Path $Harness.Temp "$Tag-data-raw.json"
    Copy-Item -LiteralPath $raw -Destination $kept -Force
    return $kept
}

function Remove-LoadHarness {
    <#  Junctions first, always -- even with -Keep: leaving links to a mod's source in %TEMP%
        hands a delete-through-the-link hazard to whatever cleans it up later. Then the temp
        directory, unless -Keep.  #>
    param([Parameter(Mandatory)] [object] $Harness, [switch] $Keep)

    Remove-ModJunctions -ModDirectory $Harness.ModDirectory
    if ($Keep) { Write-Host "temp kept at: $($Harness.Temp)" }
    else { Remove-TempDirectory -Path $Harness.Temp -Label 'load-harness' }
}
