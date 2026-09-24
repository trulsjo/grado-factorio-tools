<#
.SYNOPSIS
    Fill a cache directory with third-party mods at pinned versions, for a load to run against.
    Exit 0 means every mod in the set is in the cache at its pinned version.

.DESCRIPTION
    WHERE IT CAME FROM. Written in realistic-fusion-refreshed (#60 there) and moved here
    (grado-factorio-tools#15); the issue numbers below without a repository are that one's. It
    carried that repository's pins inside the script. They are the consumer's version decisions,
    not machinery, so they now come from -PinFile, and the only change to what a fetch does is
    where the pins are read from.

    The one step that was missing (#60). A load that junctions whatever mod directories it finds
    already existed; what did not was a way to GET a third-party mod onto disk at a version
    somebody chose. load-harness.ps1 here takes the cache this writes as its mod source.

    GIT FIRST, PORTAL AS THE FALLBACK -- Truls's call, 2026-08-26 (#60). The ticket set out three
    shapes and declined to choose between them. Git-only is cheapest but cannot reach a mod that
    publishes nowhere else; portal-only reaches everything but makes every coexistence check
    unrunnable on a machine that has never signed in to Factorio. This does both, and the cost is
    honestly two mechanisms to keep working rather than one.

    Consequence worth stating: a mod with a Git entry NEVER touches the portal, so it never reads
    player-data.json and never builds a URL with a token in it. realistic-fusion-refreshed's whole
    Krastorio 2 set is in that category, which is why the credential path below can be exercised
    deliberately (-PreferPortal) rather than only by accident.

    WHY A TAG IS A BETTER PIN THAN A VERSION STRING. `git clone --depth 1 --branch v2.0.19` names an
    immutable object and git verifies its own integrity on the way in, so there is no sha1 step to
    write and no "latest" to drift. The portal half has no such property, which is why it does have
    one: every release carries a `sha1` and it is checked before the zip is used, cached or fresh.

    WHAT THE PIN DOES NOT GUARANTEE, and it is worth knowing before trusting this for a coexistence
    claim: a git tag is the mod's SOURCE, and the portal zip is the mod's RELEASE. They are usually
    the same tree and are not required to be. Every mod fetched here therefore has its info.json
    version checked against the pin afterwards -- that catches a mistagged release, though not a
    release built from a tree that was never tagged.

    THE TOKEN IS THE DANGEROUS PART. The portal's download endpoint takes credentials as QUERY
    PARAMETERS, so the URL itself is a secret. Four things follow, and all four are enforced rather
    than hoped for: the URL is never written to output; `Invoke-WebRequest` is called with
    -Verbose:$false so a caller's -Verbose cannot print it; every error that escapes the download is
    scrubbed before it is rethrown; and the ErrorRecord PowerShell files in $Error is DROPPED, because
    a scrubbed message is not the only copy -- the record's TargetObject holds the request URI, token
    and all, even when the message does not. `-SelfTest` proves all of it with a sentinel rather than
    asserting it, and checks 2/5 and 5/5 are two different checks for that reason: a child process
    takes its $Error to the grave, so only an in-process call can see that leak.

.PARAMETER PinFile
    The manifest: a .psd1 holding the pinned sets, which is the caller's and not this script's.

        @{
            Default = 'krastorio2'                        # optional: the set when -Set is omitted
            Sets = @{
                krastorio2 = @(
                    @{ Name = 'flib'; Version = '0.16.2'; Git = 'https://github.com/factoriolib/flib.git' }
                    @{ Name = 'Krastorio2Assets'; Version = '2.0.5' }
                )
            }
            Lanes = @{ 'k2-spaceex' = @('krastorio2', 'spaceex') }   # optional: unions of sets
        }

    Each entry is Name and Version, plus an optional Git URL -- a mod with one is cloned rather than
    downloaded -- and an optional Tag, which defaults to 'v' + Version. resolve-modpack.ps1 writes
    this format, one set per pack and no Git.

    A LANE IS A UNION OF SETS, composed rather than written out again, so a pin lives in one place:
    refreshing a set refreshes every lane it appears in. Which unions are possible at all is a
    matter of what the mods declare -- a `!` between two sets means that lane is not meant to
    exist.

.PARAMETER Set
    Which set or lane of -PinFile to fetch. Defaults to the file's Default.

.PARAMETER CacheDirectory
    Where the mods live between runs. Defaults to `.mod-cache/<set>/` under the current directory,
    so a consumer run from its own root caches there; git-ignore it. Deliberately NOT the temp mod
    directory a check builds: that is torn down
    per run, and refetching per run would be slow and rude. Measured in realistic-fusion-refreshed,
    its Krastorio 2 set is 414 MB -- 376 of it Krastorio2Assets, which is the mod that actually
    motivates caching. Nearly half of that total is .git: --depth 1 keeps the history shallow, not
    absent, and an asset repository's single commit is still every sprite.

    PER SET, AND NOT BY PREFERENCE. One shared directory accumulates every set ever fetched, and a
    load junctions everything it finds -- so fetching seablock after krastorio2 there produced a
    51-mod directory containing both, which is not a set anybody chose and which SeaBlockWanne
    forbids outright (`! Krastorio2`). The same shape bites on versions: `flib` was pinned 0.16.2 in
    one set and 0.16.5 in the other, and a cache keyed by name alone can only hold one of them.
    Separate directories cost duplicated downloads where lanes overlap and remove both problems.
    Pass this explicitly only if you want that behaviour back.

.PARAMETER PreferPortal
    Take the portal route even for a mod that has a Git source. Nothing needs this to work; it exists
    so the credential path can be exercised on a mod whose git route is known good, instead of only
    ever running when some other mod happens to lack a repository.

.PARAMETER Force
    Re-fetch even when the cache already holds the pinned version.

.PARAMETER PlayerDataPath
    Where to read the mod-portal credentials. Defaults to %APPDATA%\Factorio\player-data.json. A
    parameter rather than a constant so -SelfTest can point it at a file it controls.

.PARAMETER PortalBaseUrl
    The mod portal's base URL. A parameter for the same reason: it lets -SelfTest exercise the
    download path against an address that refuses instantly, so the leak check needs no network and
    no real credentials.

.PARAMETER SelfTest
    Prove this script does what it claims: that a union pinning one mod at two versions is refused
    rather than silently resolved, that a missing credential is reported as such, that the token
    reaches no output, and that a corrupted cached zip is rejected rather than used. It brings its
    own fixture manifest. Given -PinFile as well, it also certifies that file's lanes.

.EXAMPLE
    pwsh -File vendor/grado-factorio-tools/scripts/fetch-mods.ps1 -PinFile scripts/mod-sets.psd1 -Set krastorio2
    pwsh -File vendor/grado-factorio-tools/scripts/load-harness.ps1 -Mods .mod-cache/krastorio2

.EXAMPLE
    pwsh -File scripts/fetch-mods.ps1 -PinFile pins.psd1 -PreferPortal
    pwsh -File scripts/fetch-mods.ps1 -SelfTest -PinFile pins.psd1
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $PinFile,
    [string] $Set,
    [string] $CacheDirectory,
    [switch] $PreferPortal,
    [switch] $Force,
    [switch] $SelfTest,
    [string] $PlayerDataPath,
    [string] $PortalBaseUrl = 'https://mods.factorio.com'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $PlayerDataPath) { $PlayerDataPath = Join-Path $env:APPDATA 'Factorio\player-data.json' }

# ---------------------------------------------------------------------------------------------
# The pins, read from -PinFile.
#
# THESE ARE VERSION DECISIONS, NOT MACHINERY, and #60 said so in as many words: "build the pin as a
# parameter and the answer fills it in later". The parameter is the file. What to fetch, at which
# version, belongs to the repository that runs the check; this script only fetches it.
#
# $MOD_SETS and $COMBINED_SETS are what the pins were called while they lived in this file, and
# Join-ModSets and Resolve-ModSet still read them by those names. Main and -SelfTest set them.
# ---------------------------------------------------------------------------------------------
function Import-PinFile {
    <#  A manifest's sets and lanes, checked for shape so a malformed entry is named here rather
        than failing somewhere inside a fetch.  #>
    param([Parameter(Mandatory)] [string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) { throw "No pin file at $Path." }
    $data = Import-PowerShellDataFile -LiteralPath $Path
    if ($data['Sets'] -isnot [hashtable]) { throw "$Path has no Sets table." }
    $sets = @{}
    foreach ($name in $data.Sets.Keys) {
        $sets[$name] = @($data.Sets[$name])
        foreach ($mod in $sets[$name]) {
            if ($mod -isnot [hashtable] -or -not $mod['Name'] -or -not $mod['Version']) {
                throw "$Path`: set '$name' has an entry without a Name and a Version."
            }
        }
    }
    $lanes = [ordered]@{}
    if ($data['Lanes']) { foreach ($name in $data.Lanes.Keys) { $lanes[$name] = @($data.Lanes[$name]) } }
    @{ Sets = $sets; Lanes = $lanes; Default = $data['Default'] }
}

function Join-ModSets {
    <#  One lane's mods from several sets, deduplicated by name.

        The overlap is real rather than defensive: in realistic-fusion-refreshed, `madclowns`
        carries six Angel's mods that `angels` carries too. A name pinned at two DIFFERENT
        versions is refused rather than resolved, because picking one would be a version decision
        made silently by a helper -- `flib` was 0.16.2 in one of that repository's sets and 0.16.5
        in another, so the case is real and only stayed out of its unions by luck.  #>
    param([Parameter(Mandatory)] [string[]] $Names)

    $byName = [ordered]@{}
    foreach ($set in $Names) {
        if (-not $MOD_SETS.ContainsKey($set)) { throw "Join-ModSets: no such set '$set'." }
        foreach ($mod in $MOD_SETS[$set]) {
            if ($byName.Contains($mod.Name)) {
                if ($byName[$mod.Name].Version -ne $mod.Version) {
                    throw ("$($mod.Name) is pinned at $($byName[$mod.Name].Version) and at " +
                           "$($mod.Version) across $($Names -join ' + '). One lane cannot hold both " +
                           "versions of a mod; reconcile the pins rather than letting this pick.")
                }
                continue
            }
            $byName[$mod.Name] = $mod
        }
    }
    return @($byName.Values | Sort-Object { $_.Name })
}

# LANES ARE COMPOSED PER REQUEST, not when the file is read.
#
# Composing every lane at load looks tidier and puts the guard's blast radius everywhere: the day
# someone bumps `flib` in one set and not another, Join-ModSets throws before `param` dispatch is
# reached, and a single-mod set sharing nothing with any of it dies with an unhandled error. So
# does `-SelfTest`, the one run that exists to explain what went wrong. Resolving per request keeps
# the refusal exactly where it belongs and nowhere else.

function Resolve-ModSet {
    <#  One set's mods by name, whether it is a family or a composed lane.  #>
    param([Parameter(Mandatory)] [string] $Name)

    if ($MOD_SETS.Contains($Name))      { return @($MOD_SETS[$Name]) }
    if ($COMBINED_SETS.Contains($Name)) { return @(Join-ModSets $COMBINED_SETS[$Name]) }
    $known = @($MOD_SETS.Keys) + @($COMBINED_SETS.Keys) | Sort-Object
    throw "Unknown set '$Name'. Defined: $($known -join ', ')."
}

# ---------------------------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------------------------

function Get-ModVersion {
    <#  The version a fetched directory actually declares, or $null if it is not a mod at all.  #>
    param([Parameter(Mandatory)] [string] $Path)

    $info = Join-Path $Path 'info.json'
    if (-not (Test-Path -LiteralPath $info)) { return $null }
    try { return (Get-Content -LiteralPath $info -Raw | ConvertFrom-Json).version }
    catch { return $null }
}

function Assert-PinnedVersion {
    <#  A tag is a promise about a tree, not about what the tree says it is. Check.  #>
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Version,
        [Parameter(Mandatory)] [string] $Source
    )

    $actual = Get-ModVersion -Path $Path
    if (-not $actual) {
        throw "$Name`: fetched from $Source but there is no readable info.json in $Path -- the source may not have the mod at its root."
    }
    if ($actual -ne $Version) {
        throw "$Name`: pinned at $Version but $Source delivered $actual. Either the pin is wrong or the tag moved; fix the pin in $PinFile rather than loosening this check."
    }
}

function Protect-Token {
    <#  Replace a secret with a marker wherever it appears in a string.

        THE LAST LINE OF DEFENCE FOR THE DOWNLOAD URL. Invoke-WebRequest's failures can carry the
        request URI, and the URI carries the token as a query parameter, so an unscrubbed error
        message is a leak into whatever captured it. Called on the way out of every portal failure.  #>
    param(
        [string] $Text,
        [string] $Secret
    )

    if (-not $Text) { return $Text }
    if (-not $Secret) { return $Text }
    return $Text.Replace($Secret, '<token-redacted>')
}

function Get-PortalCredential {
    <#  Read service-username and service-token out of Factorio's own player-data.json.

        FAILS BY NAMING THE CAUSE, which is a requirement rather than politeness (#60). A machine
        that has never signed in to Factorio cannot fetch from the portal at all, and that is a real
        new precondition on these checks. Surfaced here, it says so; surfaced by the game, it is a
        403 behind a Cloudflare challenge or a missing-zip error, and reads as this repo being
        broken.  #>
    param([Parameter(Mandatory)] [string] $Path)

    $advice = @(
        "The mod portal needs the credentials Factorio itself stores. Sign in once in the game"
        "(Settings -> Your Factorio account) and they appear. Mods with a Git source need none of"
        "this -- only the portal fallback does."
    ) -join ' '

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No Factorio credentials: $Path does not exist. $advice"
    }

    try { $data = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
    catch { throw "No Factorio credentials: $Path could not be parsed as JSON. $advice" }

    $username = $null
    $token    = $null
    foreach ($p in $data.PSObject.Properties) {
        if ($p.Name -eq 'service-username') { $username = $p.Value }
        if ($p.Name -eq 'service-token')    { $token    = $p.Value }
    }

    $missing = @()
    if (-not $username) { $missing += 'service-username' }
    if (-not $token)    { $missing += 'service-token' }
    if ($missing) {
        throw "No Factorio credentials: $Path has no $($missing -join ' and '). $advice"
    }

    return @{ Username = $username; Token = $token }
}

function Get-PortalRelease {
    <#  The pinned release's file_name, sha1 and download_url.

        This half of the API needs no authentication -- the portal's own wiki says so -- which is
        why the token is not read until the download itself. Picks by exact version: taking "latest"
        is what makes a check that passes today fail the next time an author bumps a major.  #>
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Version,
        [Parameter(Mandatory)] [string] $BaseUrl
    )

    $url = "$BaseUrl/api/mods/$Name/full"
    try { $full = Invoke-RestMethod -Uri $url -Method Get -Verbose:$false }
    catch { throw "$Name`: could not reach the mod portal API at $url -- $($_.Exception.Message)" }

    $release = @($full.releases) | Where-Object { $_.version -eq $Version } | Select-Object -First 1
    if (-not $release) {
        $have = (@($full.releases) | ForEach-Object { $_.version }) -join ', '
        throw "$Name`: the portal has no release $Version. It has: $have."
    }
    return $release
}

function Save-PortalMod {
    <#  Download the pinned release, check its sha1, and unpack it into the cache.

        CACHED ZIP, CHECKED ANYWAY. The hash is verified whether the zip was just downloaded or
        found on disk from a previous run: a cache is exactly where a truncated or tampered file
        would sit unnoticed, and re-checking costs a hash of a file we already have.  #>
    param(
        [Parameter(Mandatory)] [hashtable] $Mod,
        [Parameter(Mandatory)] [string]    $CacheDirectory,
        [Parameter(Mandatory)] [string]    $PlayerDataPath,
        [Parameter(Mandatory)] [string]    $BaseUrl
    )

    $name    = $Mod.Name
    $version = $Mod.Version
    $release = Get-PortalRelease -Name $name -Version $version -BaseUrl $BaseUrl

    $zipDir = Join-Path $CacheDirectory '.zips'
    New-Item -ItemType Directory -Path $zipDir -Force | Out-Null
    $zip = Join-Path $zipDir $release.file_name

    $needDownload = -not (Test-Path -LiteralPath $zip)
    if (-not $needDownload) {
        $cachedHash = (Get-FileHash -LiteralPath $zip -Algorithm SHA1).Hash
        if ($cachedHash -ne $release.sha1.ToUpperInvariant()) {
            Write-Host "  $name`: cached zip fails its sha1, discarding and refetching"
            Remove-Item -LiteralPath $zip -Force
            $needDownload = $true
        }
        else { Write-Host "  $name`: cached zip matches the portal's sha1" }
    }

    if ($needDownload) {
        # The token is read HERE and nowhere earlier, so a git-only run never touches it.
        $cred = Get-PortalCredential -Path $PlayerDataPath
        $url  = "$BaseUrl$($release.download_url)?username=$([uri]::EscapeDataString($cred.Username))&token=$([uri]::EscapeDataString($cred.Token))"
        Write-Host "  $name`: downloading $($release.file_name) from the mod portal"
        # Where $Error stood before the request, so the records this one adds can be dropped again.
        $errorFloor = $Error.Count
        try {
            # -Verbose:$false so a caller's -Verbose cannot print the URI, which is a secret here.
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $url -OutFile $zip -Verbose:$false | Out-Null
        }
        catch {
            $safe = Protect-Token -Text $_.Exception.Message -Secret $cred.Token
            if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
            # THE RETHROWN MESSAGE IS NOT THE ONLY COPY, which is what the first version of this
            # missed. PowerShell appends the original ErrorRecord to $Error whatever we throw, and
            # that record's TargetObject is the HttpRequestMessage -- whose RequestUri still holds
            # ?username=...&token=... in clear, even when Exception.Message does not. Measured on
            # 7.6.5: Message clean, TargetObject dirty, `$Error[0] | Format-List *` dirty.
            #
            # Scrubbing the message and leaving the record is a leak into anything that later reads
            # $Error: a CI wrapper dumping it on failure, a transcript, or a session that dot-sourced
            # this script. Dropping the records rather than trusting nobody looks.
            while ($Error.Count -gt $errorFloor) { $Error.RemoveAt(0) }
            throw "$name`: the mod portal download failed -- $safe"
        }
        finally { $url = $null; $cred = $null }

        $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA1).Hash
        if ($hash -ne $release.sha1.ToUpperInvariant()) {
            Remove-Item -LiteralPath $zip -Force
            throw "$name`: the downloaded zip's sha1 is $hash but the portal says $($release.sha1). Not using it."
        }
    }

    # Unpack beside the cache, then move into place: a mod's folder inside its zip is named
    # {name}_{version}, and a load finds mods by DIRECTORY NAME, so it has to end up as {name}.
    $staging = Join-Path $CacheDirectory ('.staging-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $target  = Join-Path $CacheDirectory $name
    try {
        Expand-Archive -LiteralPath $zip -DestinationPath $staging -Force
        $inner = @(Get-ChildItem -Path $staging -Directory)
        $root  = if ($inner.Count -eq 1 -and (Test-Path (Join-Path $inner[0].FullName 'info.json'))) { $inner[0].FullName } else { $staging }
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
        Move-Item -LiteralPath $root -Destination $target
    }
    finally {
        if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue }
    }

    Assert-PinnedVersion -Path $target -Name $name -Version $version -Source 'the mod portal'
    return 'portal'
}

function Save-GitMod {
    <#  Clone the pinned tag, shallow. No credential, no hash step -- git verifies its own objects.  #>
    param(
        [Parameter(Mandatory)] [hashtable] $Mod,
        [Parameter(Mandatory)] [string]    $CacheDirectory
    )

    $name   = $Mod.Name
    $tag    = if ($Mod.ContainsKey('Tag')) { $Mod.Tag } else { 'v' + $Mod.Version }
    $target = Join-Path $CacheDirectory $name

    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }

    Write-Host "  $name`: cloning $tag from $($Mod.Git)"
    # GIT_TERMINAL_PROMPT=0 so a moved tag or a private URL fails instead of blocking on a prompt
    # this script has no way to answer.
    $previous = $env:GIT_TERMINAL_PROMPT
    $env:GIT_TERMINAL_PROMPT = '0'
    try {
        # git writes ordinary progress to stderr, and with $ErrorActionPreference = 'Stop' that
        # alone would throw before the exit code is ever read. Gather the streams under Continue
        # and judge the command by its exit code, which is the only thing that means failure.
        $output = & {
            $ErrorActionPreference = 'Continue'
            & git clone --quiet --depth 1 --branch $tag -- $Mod.Git $target 2>&1
        }
        if ($LASTEXITCODE -ne 0) {
            throw "$name`: git clone of $tag from $($Mod.Git) failed -- $(($output | ForEach-Object { $_.ToString() }) -join ' ')"
        }
    }
    finally { $env:GIT_TERMINAL_PROMPT = $previous }

    Assert-PinnedVersion -Path $target -Name $name -Version $Mod.Version -Source "git tag $tag"
    return 'git'
}

function Invoke-Fetch {
    <#  Fetch one set into the cache, and report where each mod came from.  #>
    param(
        [Parameter(Mandatory)] [array]  $Mods,
        [Parameter(Mandatory)] [string] $CacheDirectory,
        [Parameter(Mandatory)] [string] $PlayerDataPath,
        [Parameter(Mandatory)] [string] $BaseUrl,
        [switch] $PreferPortal,
        [switch] $Force
    )

    New-Item -ItemType Directory -Path $CacheDirectory -Force | Out-Null
    $results = @()

    foreach ($mod in $Mods) {
        $target = Join-Path $CacheDirectory $mod.Name
        if (-not $Force -and (Get-ModVersion -Path $target) -eq $mod.Version) {
            Write-Host "  $($mod.Name)`: already cached at $($mod.Version)"
            $results += @{ Name = $mod.Name; Version = $mod.Version; Source = 'cache' }
            continue
        }

        $useGit = $mod.ContainsKey('Git') -and $mod.Git -and -not $PreferPortal
        $source = if ($useGit) {
            Save-GitMod -Mod $mod -CacheDirectory $CacheDirectory
        }
        else {
            Save-PortalMod -Mod $mod -CacheDirectory $CacheDirectory -PlayerDataPath $PlayerDataPath -BaseUrl $BaseUrl
        }
        $results += @{ Name = $mod.Name; Version = $mod.Version; Source = $source }
    }

    return $results
}

# ---------------------------------------------------------------------------------------------
# Self-test
# ---------------------------------------------------------------------------------------------

function Start-FakePortal {
    <#  A mod portal on loopback, so the download path can be driven without credentials.

        WHY THIS EXISTS RATHER THAN A REFUSING ADDRESS. The first version of this self-test pointed
        -PortalBaseUrl at a port nothing listens on and searched the output for a sentinel token. It
        passed, and it proved nothing: the API call fails first, so Get-PortalCredential is never
        reached and the token never enters the URL the check exists to police. A leak test that never
        handles the secret is the same class of pass as an asset check that never opens the archive.

        So this answers /api/mods/{name}/full for real, hands back a download_url, and logs every
        request line it receives -- INCLUDING the query string, token and all. That log is the proof
        the token actually travelled; the leak check is only meaningful because it did.  #>
    param(
        [Parameter(Mandatory)] [int]    $Port,
        [Parameter(Mandatory)] [string] $RequestLog,
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Version,
        [Parameter(Mandatory)] [string] $ClaimedSha1,
        [string] $ZipPath,
        [switch] $FailDownload
    )

    Start-ThreadJob -ScriptBlock {
        param($port, $log, $name, $version, $sha1, $zip, $fail)
        $h = [System.Net.HttpListener]::new()
        $h.Prefixes.Add("http://localhost:$port/")
        $h.Start()
        try {
            while ($true) {
                $ctx = $h.GetContext()
                $req = $ctx.Request
                $res = $ctx.Response
                Add-Content -LiteralPath $log -Value $req.Url.PathAndQuery
                $path = $req.Url.AbsolutePath
                if ($path -eq '/__stop') { $res.StatusCode = 200; $res.Close(); break }
                elseif ($path -like '/api/mods/*/full') {
                    $body = @{
                        name     = $name
                        releases = @(@{
                            version      = $version
                            file_name    = ($name + '_' + $version + '.zip')
                            sha1         = $sha1
                            download_url = '/download/' + $name + '/0000000000000000000000000000000000000000'
                        })
                    } | ConvertTo-Json -Depth 5
                    $b = [Text.Encoding]::UTF8.GetBytes($body)
                    $res.ContentType = 'application/json'
                    $res.StatusCode = 200
                    $res.OutputStream.Write($b, 0, $b.Length)
                    $res.Close()
                }
                elseif ($path -like '/download/*') {
                    if ($fail -or -not $zip) { $res.StatusCode = 500; $res.Close() }
                    else {
                        $b = [IO.File]::ReadAllBytes($zip)
                        $res.ContentType = 'application/zip'
                        $res.StatusCode = 200
                        $res.OutputStream.Write($b, 0, $b.Length)
                        $res.Close()
                    }
                }
                else { $res.StatusCode = 404; $res.Close() }
            }
        }
        finally { $h.Stop(); $h.Close() }
    } -ArgumentList $Port, $RequestLog, $Name, $Version, $ClaimedSha1, $ZipPath, ([bool]$FailDownload)
}

function Invoke-SelfTest {
    <#  Prove the five things a passing fetch does not show.

        Every portal check runs the real script in a child process against the loopback portal above,
        so what is exercised is the shipped code path rather than a re-implementation of it.  #>
    param([Parameter(Mandatory)] [string] $ScriptPath, [string] $UserPinFile)

    $temp = Join-Path ([IO.Path]::GetTempPath()) ('fetchmods-selftest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    $failures = 0
    $sentinel = 'SENTINEL-TOKEN-b3a1f29c47d5'

    # THE FIXTURE MANIFEST. The self-test brings its own pins rather than borrowing a consumer's,
    # so it proves the same thing in every repository. `selftest` has no Git entry on purpose: that
    # is what makes it take the portal route, and so drives the token.
    $modName = 'fetchmods-selftest-mod'
    $fixture = Join-Path $temp 'pins.psd1'
    @"
@{
    Sets = @{
        selftest = @( @{ Name = '$modName'; Version = '1.0.0' } )
        low      = @( @{ Name = 'shared'; Version = '1.0.0' }; @{ Name = 'only-low'; Version = '1.0.0' } )
        high     = @( @{ Name = 'shared'; Version = '2.0.0' } )
        also     = @( @{ Name = 'shared'; Version = '1.0.0' }; @{ Name = 'only-also'; Version = '1.0.0' } )
    }
    Lanes = @{ 'low-also' = @('low', 'also') }
}
"@ | Set-Content -LiteralPath $fixture -Encoding utf8

    # The credentials the child will use: real shape, invented values.
    $creds = Join-Path $temp 'player-data.json'
    @{ 'service-username' = 'selftest-user'; 'service-token' = $sentinel } |
        ConvertTo-Json | Set-Content -LiteralPath $creds -Encoding utf8

    # The zip the fake portal serves: a real archive holding a real info.json, so the unpack and the
    # version check downstream are exercised rather than stubbed.
    $stage = Join-Path $temp ('stage\' + $modName + '_1.0.0')
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    @{ name = $modName; version = '1.0.0'; title = 'fetch-mods self-test fixture'
       author = 'fetch-mods.ps1'; factorio_version = '2.0'; dependencies = @('base') } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stage 'info.json') -Encoding utf8
    $zip = Join-Path $temp 'served.zip'
    Compress-Archive -Path $stage -DestinationPath $zip -Force
    $trueSha1 = (Get-FileHash -LiteralPath $zip -Algorithm SHA1).Hash

    # A free port, taken and released so the listener can claim it.
    $probe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $probe.Start(); $port = $probe.LocalEndpoint.Port; $probe.Stop()

    $runChild = {
        param([string] $CacheDir, [string] $CaptureDir, [bool] $Loud)
        New-Item -ItemType Directory -Path $CaptureDir -Force | Out-Null
        $out = Join-Path $CaptureDir 'stdout.txt'
        $err = Join-Path $CaptureDir 'stderr.txt'
        $psArgs = @(
            '-NoProfile', '-File', $ScriptPath,
            '-PinFile', $fixture,
            '-Set', 'selftest',
            '-CacheDirectory', $CacheDir,
            '-PlayerDataPath', $creds,
            '-PortalBaseUrl', ('http://localhost:' + $port),
            '-Force'
        )
        if ($Loud) { $psArgs += '-Verbose' }
        $p = Start-Process -FilePath 'pwsh' -ArgumentList $psArgs -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $out -RedirectStandardError $err
        $text = (Get-Content -LiteralPath $out -Raw -ErrorAction SilentlyContinue) + "`n" +
                (Get-Content -LiteralPath $err -Raw -ErrorAction SilentlyContinue)
        return @{ Code = $p.ExitCode; CaptureDir = $CaptureDir; Text = $text }
    }

    $stopPortal = {
        param($Job)
        try { Invoke-WebRequest -Uri ('http://localhost:' + $port + '/__stop') -TimeoutSec 5 -Verbose:$false | Out-Null } catch { }
        Wait-Job -Job $Job -Timeout 10 | Out-Null
        Remove-Job -Job $Job -Force -ErrorAction SilentlyContinue
    }

    try {
        # --- 1/6 -------------------------------------------------------------------------------
        # THE MANIFEST BEFORE THE PORTAL. This half needs no network and no credentials, so a
        # broken set list is reported before a fake portal is spent on it.
        #
        # What it holds is Join-ModSets' refusal, not its arithmetic. A union that deduplicates by
        # name has exactly one way to be quietly wrong: two sets pinning the same mod at different
        # versions, where picking either is a version decision that belongs in the manifest rather
        # than in a helper. The fixture's `low` + `high` is that case, and it is not a lane, so
        # without this the guard would never run.
        Write-Host 'self-test 1/6: a union of two sets pinning one mod at two versions must be refused.'

        # THE EXPECTED SIZES ARE DERIVED, NOT WRITTEN DOWN. Refreshing the pins is editing numbers
        # in a manifest, and a refresh that grows a set must not fail the one check meant to
        # certify the manifest. So the expectation is counted from the sets by hand here -- same
        # data, different code path from Join-ModSets, which is what makes it worth asserting at
        # all. Over the fixture's lanes, and over -PinFile's when one was given.
        $manifests = [ordered]@{ 'the fixture' = Import-PinFile -Path $fixture }
        if ($UserPinFile) { $manifests[(Split-Path $UserPinFile -Leaf)] = Import-PinFile -Path $UserPinFile }
        $composed = [ordered]@{}
        $dupes = @()
        $wrongSize = @()
        foreach ($label in $manifests.Keys) {
            $script:MOD_SETS = $manifests[$label].Sets
            $script:COMBINED_SETS = $manifests[$label].Lanes
            foreach ($lane in $COMBINED_SETS.Keys) {
                $lanes = @(Join-ModSets $COMBINED_SETS[$lane])
                $composed["$lane ($label)"] = $lanes.Count
                $distinct = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
                foreach ($family in $COMBINED_SETS[$lane]) {
                    foreach ($mod in $MOD_SETS[$family]) { [void] $distinct.Add($mod.Name) }
                }
                # PER LANE, not across all of them: two lanes may share members by design, and
                # flattening them together reported every one of those as a duplicate.
                foreach ($g in ($lanes | Group-Object { $_.Name })) {
                    if ($g.Count -gt 1) { $dupes += "$($g.Name) twice in $lane ($label)" }
                }
                if ($lanes.Count -ne $distinct.Count) {
                    $wrongSize += "$lane ($label) is $($lanes.Count) mods, expected $($distinct.Count)"
                }
            }
        }
        $script:MOD_SETS = $manifests['the fixture'].Sets
        $script:COMBINED_SETS = $manifests['the fixture'].Lanes

        # OUTSIDE THE CATCH. These three assertions used to sit inside it, so they ran only when the
        # guard threw -- if it ever stopped throwing, the run reported that one failure and
        # silently skipped the other two rather than also evaluating them.
        $refused = ''
        try {
            Join-ModSets 'low', 'high' | Out-Null
        }
        catch { $refused = $_.Exception.Message }

        if (-not $refused) {
            Write-Host '  FAILED: shared at 1.0.0 and 2.0.0 in one lane was not refused.'; $failures++
        }
        elseif ($refused -notmatch 'shared is pinned at') {
            Write-Host "  FAILED: refused for the wrong reason -- $refused"; $failures++
        }
        if ($dupes)     { Write-Host "  FAILED: $($dupes -join '; ')"; $failures++ }
        if ($wrongSize) { Write-Host "  FAILED: $($wrongSize -join '; ')"; $failures++ }
        if ($refused -match 'shared is pinned at' -and -not $dupes -and -not $wrongSize) {
            Write-Host '  ok: the conflict is named and refused, and the composed lanes are'
            Write-Host ("      $(($composed.Keys | ForEach-Object { "$_ $($composed[$_])" }) -join ', ') " +
                        'mods, each matching its sets'' distinct count with no name appearing twice')
        }

        # --- 2/6 -------------------------------------------------------------------------------
        Write-Host 'self-test 2/6: a machine with no Factorio credentials must say so.'
        try {
            Get-PortalCredential -Path (Join-Path $temp 'absent.json') | Out-Null
            Write-Host '  FAILED: a missing player-data.json did not throw.'; $failures++
        }
        catch {
            if ($_.Exception.Message -match 'No Factorio credentials') { Write-Host '  ok: a missing file names the cause' }
            else { Write-Host "  FAILED: wrong message -- $($_.Exception.Message)"; $failures++ }
        }
        $signedOut = Join-Path $temp 'signed-out.json'
        '{ "last-played-version": { "build_version": 84539 } }' | Set-Content -LiteralPath $signedOut -Encoding utf8
        try {
            Get-PortalCredential -Path $signedOut | Out-Null
            Write-Host '  FAILED: a player-data.json without the keys did not throw.'; $failures++
        }
        catch {
            if ($_.Exception.Message -match 'service-username' -and $_.Exception.Message -match 'service-token') {
                Write-Host '  ok: a signed-out player-data.json names both missing keys'
            }
            else { Write-Host "  FAILED: wrong message -- $($_.Exception.Message)"; $failures++ }
        }

        # --- 3/6 -------------------------------------------------------------------------------
        Write-Host 'self-test 3/6: the token must travel, and must reach no captured output.'
        $log = Join-Path $temp 'requests-fail.log'
        New-Item -ItemType File -Path $log -Force | Out-Null
        $job = Start-FakePortal -Port $port -RequestLog $log -Name $modName -Version '1.0.0' `
            -ClaimedSha1 $trueSha1 -ZipPath $zip -FailDownload
        $r = & $runChild (Join-Path $temp 'cache-fail') (Join-Path $temp 'capture-fail') $true
        & $stopPortal $job

        $served = Get-Content -LiteralPath $log -Raw -ErrorAction SilentlyContinue
        # The anti-vacuous half: unless the portal SAW the token, the leak check below is empty.
        if ($served -notmatch [regex]::Escape($sentinel)) {
            Write-Host '  FAILED: the token never reached the download request, so this proves nothing.'
            Write-Host "          requests seen: $served"
            $failures++
        }
        elseif ($r.Code -eq 0) {
            Write-Host '  FAILED: a 500 from the download endpoint did not fail the run.'; $failures++
        }
        else {
            $leaked = @(Get-ChildItem -Path $r.CaptureDir -File -Recurse | Where-Object {
                (Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue) -match [regex]::Escape($sentinel) })
            if ($leaked) {
                Write-Host "  FAILED: the token reached $($leaked.Count) captured file(s): $(($leaked.Name) -join ', ')"
                $failures++
            }
            else {
                Write-Host "  ok: the portal saw the token, the run failed, and $($r.Text.Length) bytes of"
                Write-Host '      captured stdout/stderr -- taken with -Verbose, the obvious way a URL leaks -- hold none of it'
            }
        }

        # --- 4/6 -------------------------------------------------------------------------------
        Write-Host 'self-test 4/6: a download whose sha1 does not match must be refused.'
        $log2 = Join-Path $temp 'requests-badsha.log'
        New-Item -ItemType File -Path $log2 -Force | Out-Null
        $job = Start-FakePortal -Port $port -RequestLog $log2 -Name $modName -Version '1.0.0' `
            -ClaimedSha1 ('a' * 40) -ZipPath $zip
        $cacheBad = Join-Path $temp 'cache-badsha'
        $r = & $runChild $cacheBad (Join-Path $temp 'capture-badsha') $false
        & $stopPortal $job

        if ($r.Code -eq 0) {
            Write-Host '  FAILED: a zip whose sha1 disagreed with the portal was accepted.'; $failures++
        }
        elseif ($r.Text -notmatch 'sha1') {
            Write-Host "  FAILED: it failed, but not with a message about the hash -- $($r.Text)"; $failures++
        }
        elseif (Test-Path (Join-Path $cacheBad $modName)) {
            Write-Host '  FAILED: the mod was unpacked into the cache despite failing its hash.'; $failures++
        }
        else { Write-Host '  ok: the mismatch is named and nothing reaches the cache' }

        # --- 5/6 -------------------------------------------------------------------------------
        Write-Host 'self-test 5/6: a good download lands, and a second run reuses the cached zip.'
        $log3 = Join-Path $temp 'requests-good.log'
        New-Item -ItemType File -Path $log3 -Force | Out-Null
        $job = Start-FakePortal -Port $port -RequestLog $log3 -Name $modName -Version '1.0.0' `
            -ClaimedSha1 $trueSha1 -ZipPath $zip
        $cacheGood = Join-Path $temp 'cache-good'
        $first  = & $runChild $cacheGood (Join-Path $temp 'capture-good-1') $false
        $second = & $runChild $cacheGood (Join-Path $temp 'capture-good-2') $false
        & $stopPortal $job

        $landed = Get-ModVersion -Path (Join-Path $cacheGood $modName)
        if ($first.Code -ne 0) {
            Write-Host "  FAILED: a valid download did not succeed (exit $($first.Code)) -- $($first.Text)"; $failures++
        }
        elseif ($landed -ne '1.0.0') {
            Write-Host "  FAILED: the cache holds '$landed', not the pinned 1.0.0."; $failures++
        }
        elseif ($second.Text -notmatch 'cached zip matches') {
            Write-Host "  FAILED: the second run did not reuse and re-verify the cached zip -- $($second.Text)"; $failures++
        }
        else {
            Write-Host '  ok: unpacked at its pinned version, and the second run re-checked the cached'
            Write-Host '      zip against the portal sha1 rather than downloading it again'
        }

        # --- 6/6 -------------------------------------------------------------------------------
        # THE LEAK THE CHILD-PROCESS CHECK CANNOT SEE. 2/4 above reads files the child wrote, and a
        # child that exits takes its $Error with it -- so a token sitting in the ErrorRecord looks
        # identical to no token at all. This calls Save-PortalMod IN THIS PROCESS, where $Error
        # survives the failure and can be read, which is the only way to tell those apart.
        Write-Host 'self-test 6/6: a failed download must leave no token in $Error either.'
        $log4 = Join-Path $temp 'requests-errorscan.log'
        New-Item -ItemType File -Path $log4 -Force | Out-Null
        $job = Start-FakePortal -Port $port -RequestLog $log4 -Name $modName -Version '1.0.0' `
            -ClaimedSha1 $trueSha1 -ZipPath $zip -FailDownload
        $thrown = ''
        try {
            Save-PortalMod -Mod @{ Name = $modName; Version = '1.0.0' } `
                -CacheDirectory (Join-Path $temp 'cache-errorscan') `
                -PlayerDataPath $creds -BaseUrl ('http://localhost:' + $port) | Out-Null
        }
        catch { $thrown = $_.Exception.Message }
        & $stopPortal $job

        $sawToken = (Get-Content -LiteralPath $log4 -Raw -ErrorAction SilentlyContinue) -match [regex]::Escape($sentinel)
        $errorDump = ($Error | Format-List * -Force | Out-String)
        if (-not $sawToken) {
            Write-Host '  FAILED: the token never reached the download request, so this proves nothing.'
            $failures++
        }
        elseif (-not $thrown) {
            Write-Host '  FAILED: a 500 from the download endpoint did not throw.'; $failures++
        }
        elseif ($thrown -match [regex]::Escape($sentinel)) {
            Write-Host '  FAILED: the thrown message carries the token.'; $failures++
        }
        elseif ($errorDump -match [regex]::Escape($sentinel)) {
            Write-Host '  FAILED: the token survives in $Error -- the ErrorRecord holds the request'
            Write-Host '          URI even when the message is clean, so scrubbing the message is not enough.'
            $failures++
        }
        else {
            Write-Host '  ok: the portal saw the token, the throw is clean, and $Error holds no copy'
        }
    }
    finally {
        Get-Job -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host ''
    if ($failures -gt 0) {
        Write-Host "FAILED - self-test: $failures check(s) did not hold."
        exit 1
    }
    Write-Host 'OK - self-test passed: a conflicting union is refused, a missing credential is named,'
    Write-Host '     the token travels to the portal and reaches neither captured output nor $Error, a'
    Write-Host '     bad sha1 is refused, and a good download is cached and re-verified rather than'
    Write-Host '     refetched.'
    exit 0
}

# ---------------------------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------------------------

if ($SelfTest) { Invoke-SelfTest -ScriptPath $PSCommandPath -UserPinFile $PinFile }

if (-not $PinFile) { throw 'Give -PinFile: the manifest of pinned sets. Get-Help shows its format.' }
$pins = Import-PinFile -Path $PinFile
$MOD_SETS = $pins.Sets
$COMBINED_SETS = $pins.Lanes
if (-not $Set) { $Set = $pins.Default }
if (-not $Set) { throw "Give -Set: $PinFile names no Default." }
if (-not $CacheDirectory) { $CacheDirectory = Join-Path (Get-Location).Path (Join-Path '.mod-cache' $Set) }

# @() FOR THE SAME REASON THE $results LINE BELOW HAS ONE, and this needed it only once Resolve-ModSet
# existed: `$MOD_SETS[$Set]` was a hashtable INDEX and indexes do not unroll, while a function RETURN
# does. Without it a one-mod set came back as the bare hashtable, so $mods.Count counted
# its two KEYS and the banner said "2 mods" for a set of one. Invoke-Fetch declares [array] $Mods and
# coerces, so the fetch itself still worked and -SelfTest still passed -- which is exactly why the
# wrong number is the only symptom, and why it would have survived a long time.
$mods = @(Resolve-ModSet -Name $Set)

Write-Host "fetch-mods: $Set -- $($mods.Count) mods into $CacheDirectory"
if ($PreferPortal) { Write-Host '            -PreferPortal: taking the portal route even where a git source exists' }

# @() BECAUSE POWERSHELL UNROLLS A ONE-ELEMENT ARRAY ON RETURN. Without it a single-mod set --
# a one-mod set -- comes back as the bare hashtable, and $results.Count then counts its three KEYS
# rather than one mod, so the summary claimed "3 mods" for a set of one.
$results = @(Invoke-Fetch -Mods $mods -CacheDirectory $CacheDirectory -PlayerDataPath $PlayerDataPath `
    -BaseUrl $PortalBaseUrl -PreferPortal:$PreferPortal -Force:$Force)

Write-Host ''
foreach ($r in $results) {
    Write-Host ("  {0,-28} {1,-8} {2}" -f $r.Name, $r.Version, $r.Source)
}
Write-Host ''
Write-Host "OK - $($results.Count) mods at their pinned versions in $CacheDirectory"
Write-Host "     Load them with: pwsh -File $(Join-Path $PSScriptRoot 'load-harness.ps1') -Mods $CacheDirectory"
