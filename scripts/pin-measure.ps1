<#
.SYNOPSIS
    Measures what moving a sibling's vendor/grado-factorio-tools pin from -Old to -New changes:
    each form the sibling lists is run at both pins, in two clones of the sibling at GitHub's
    main, and its output and exit code are kept in -Out with a table that compares them. Exit 0
    means the measurement was made, whatever it found; exit 1 means it could not be made, and
    says why.

.DESCRIPTION
    WHY (grado-factorio-tools#247). docs/agents/issue-tracker.md, Pin tickets, described the
    measurement in prose, and each sibling session wrote it by hand and got it wrong first: on
    grado-factorio-modpack's PR #387 (2026-10-26) the first run put the pin's copy at the wrong
    path, gave a hook its input without a cwd and ran a -SelfTest -Settings with vendor/ empty,
    and was discarded; PR #380 discarded a first run of its -Body form. The why of measuring in a
    clone, and what the clone cannot see, stay on that page.

    WHERE IT RUNS. From the sibling's vendor/grado-factorio-tools/scripts/, with the submodule
    checked out at the new pin. The sibling is the repository the submodule sits in. Both pins
    must be commits of the submodule's repository, from which both copies are made with
    `git archive`; where either is not, it refuses, naming the commit.

    WHAT IT DOES, in -Out, which must be empty or not there:
    - ls-remote.txt: `git ls-remote <origin> refs/heads/main`, origin being the sibling's.
    - clone-old/ and clone-new/: two clones of the sibling, from one fetch of origin's main, both
      detached there with origin/main set to it. Each clone's vendor/grado-factorio-tools/scripts/
      holds its pin's copy of scripts/. The clones share no directory, so a form that writes into
      its clone leaves the other pin's run as it was. The old pin runs first.
    - <form>.old.txt, <form>.old.exit, <form>.new.txt and <form>.new.exit for every form: its
      output, stdout and stderr together, and its exit code, run with pwsh -NoProfile -File in
      its clone's root.
    - breaking.txt: the breaking commits of the move, those -Old..-New brings in and those a pin
      moved back drops, marked dropped, for the pull request's Merge Danger; "none" where there is
      none. The rule and the text are breaking-lib.ps1's (grado-factorio-tools#255), which its
      header states with an example.
    - table.md: a Markdown table of each form, its old and new exit, whether the outputs are the
      same, and each pin's last non-empty output line; a form whose outputs differ while those
      lines are the same reads "differs above the last line". Outputs are compared with each
      clone's own path written as <clone>, so a path that only names the clone is no difference.
      Under the table, each `git grep -n vendor/grado-factorio-tools/scripts` hit in the sibling
      that no form runs, matched by script name: a hit is run when every script of this
      repository it names is a form's tools script, wherever the hit sits (#247's brief).

    It reports and does not judge: a form that differs, or fails at both pins, is evidence for
    the pull request, and the run still exits 0. It exits 1 only when it cannot measure: a pin
    missing, a forms file it cannot read, a clone, fetch or archive that fails, or gh or the
    remote out of reach. It fetches, lists the remote and reads pull requests with gh; nothing
    downloaded is run but the sibling's own forms and scripts, at origin's main.

    THE FORMS FILE, the one contract between this repository and each sibling: a PowerShell data
    file the sibling keeps, at -Forms in its clone, read with Import-PowerShellDataFile. It holds
    Forms, a list; each form has a Name, used in the file names; From, `tools` for a script of
    this repository, found in the pin's copy, or `sibling` for one of the sibling's own, found
    from its clone's root; Script, its path from there; and Args, a list of arguments. In an
    argument these are replaced:
    - {tools}: the pin's copy of scripts/, in that clone.
    - {headmsg}: the path of a file holding the clone's HEAD commit message.
    - {prbody:last-merged:<n>}: the body of one of the sibling's last <n> merged pull requests,
      read with gh. The form is run once for each, as <form>-pr<number>, with the body in place of
      the placeholder and in the environment variable PR_BODY.
    - {stdin:<text>}: an argument that is this alone is taken out, and <text> is given to the
      form on its stdin, as a hook's tool call is. Its cwd may be `.`: the form runs in the clone.
    An example is the second below.

    WHAT IT CANNOT SEE. What Pin tickets says the copy cannot: the clone's own submodule is not
    initialised, its index matches HEAD, and a form over origin/main...HEAD reads nothing. A form
    the sibling's file does not list, though the grep under the table names each reference no
    form runs, by name only: a script one form runs may still be called with other arguments
    elsewhere. And what a difference means, which is the pull request's to say.

.PARAMETER Old
    The commit the sibling's pin is at now.

.PARAMETER New
    The commit the pin moves to.

.PARAMETER Out
    The directory everything is written to; empty or not there. Nothing in it is committed.

.PARAMETER Forms
    The forms file's path in the sibling's clone. Defaults to scripts/pin-forms.psd1.

.PARAMETER SelfTest
    Build, in a temp directory and offline, a tools repository whose pins have between them a
    plain commit, a `!` with no footer, a BREAKING-CHANGE footer and a BREAKING CHANGE footer with
    a trailer in its paragraph, and a sibling holding a forms file, whose origin is a local path,
    and measure the move with pull request bodies read from a stub. Check each form's output and
    exit at both pins, each placeholder, breaking.txt and breaking-lib.ps1's rule, forward, back
    and over an empty range, table.md's rows, a "differs above the last line"
    row among them, a sibling reference no form runs being listed, by script name, and that a
    write into one clone does not show in the other's run. Then run this script itself: copied
    into the tools repository, with a pin that is not there, it exits 1, naming it; copied into a
    sibling that holds the tools repository as its submodule, with forms that differ and none
    that reads gh, it exits 0. Needs git, and no game and no network.

.EXAMPLE
    From the sibling's root, with the submodule at the new pin:

        pwsh -File vendor/grado-factorio-tools/scripts/pin-measure.ps1 -Old 8189e45 -New 2c13393 -Out ../pin-8189e45-2c13393

.EXAMPLE
    A forms file, scripts/pin-forms.psd1 in the sibling:

        @{
            Forms = @(
                @{ Name = 'markdown'; From = 'tools'; Script = 'markdown-check.ps1'; Args = @('-All') }
                @{ Name = 'msg'; From = 'tools'; Script = 'commit-check.ps1'; Args = @('-ScopeFile', 'commit-scopes.txt', '{headmsg}') }
                @{ Name = 'body'; From = 'tools'; Script = 'pr-body-check.ps1'; Args = @('-Body', '{prbody:last-merged:2}') }
                @{ Name = 'cd-hook'; From = 'tools'; Script = 'refuse-cd-into-mod-cache.ps1'; Args = @('-Root', '.', '{stdin:{"cwd":".","tool_input":{"command":"cd .mod-cache"}}}') }
                @{ Name = 'ship'; From = 'sibling'; Script = 'scripts/ship-check.ps1'; Args = @('-Tools', '{tools}') }
            )
        }
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $Old,
    [string] $New,
    [string] $Out,
    [string] $Forms = 'scripts/pin-forms.psd1',
    [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Runs git with the arguments after the first, and throws, naming what the first says was being
# done, when it fails; returns what it printed. A plain function, so a -C or -E is git's.
function Invoke-Git {
    $What = $args[0]; $GitArgs = @($args | Select-Object -Skip 1)
    $said = & git @GitArgs 2>&1
    if ($LASTEXITCODE) { throw "$What failed: git $($GitArgs -join ' '): $($said -join ' ')" }
    $said
}

# Get-BreakingCommit and Format-BreakingCommit, the one rule for a pin move's breaking commits.
. "$PSScriptRoot/breaking-lib.ps1"

# breaking.txt, in $Out: the breaking commits of the move from $Old to $New in $Tools, as
# Format-BreakingCommit writes them.
function Write-BreakingList {
    param([string] $Tools, [string] $Old, [string] $New, [string] $Out)
    $text = Format-BreakingCommit @(Get-BreakingCommit -Repo $Tools -Old $Old -New $New)
    Set-Content -LiteralPath (Join-Path $Out 'breaking.txt') -Value $text
}

# The last line of $Text that is not blank, ready for a table cell.
function Get-LastLine {
    param([string] $Text)
    $last = @($Text -split '\r?\n' | Where-Object { $_.Trim() }) | Select-Object -Last 1
    "$last".Trim() -replace '\|', '\|'
}

# The runs of one form: each its name, its arguments with the placeholders filled, its stdin and
# its PR_BODY. $Bodies reads the last <n> merged pull requests' bodies as @{ Number; Body }.
function Expand-Form {
    param([hashtable] $Form, [string] $Tools, [string] $HeadMsg, [scriptblock] $Bodies)
    $stdin = $null
    $args_ = foreach ($a in @($Form.Args)) {
        $a = "$a"
        if ($a -match '^\{stdin:(.*)\}$') { $stdin = $Matches[1]; continue }
        $a.Replace('{tools}', $Tools).Replace('{headmsg}', $HeadMsg)
    }
    $args_ = @($args_)
    $pr = @($args_ | Where-Object { $_ -match '\{prbody:last-merged:(\d+)\}' })
    if (-not $pr) { return , @{ Name = $Form.Name; Args = $args_; Stdin = $stdin; Body = $null } }
    $null = $pr[0] -match '\{prbody:last-merged:(\d+)\}'
    $token = $Matches[0]
    foreach ($b in & $Bodies ([int] $Matches[1])) {
        , @{ Name = "$($Form.Name)-pr$($b.Number)"; Args = @($args_ | ForEach-Object { $_.Replace($token, [string] $b.Body) }); Stdin = $stdin; Body = [string] $b.Body }
    }
}

# The measurement, into $Out: see the header. $Tools is this repository, $Sibling the sibling's
# checkout, and $Bodies reads pull request bodies, as Expand-Form says.
function Invoke-PinMeasure {
    param([string] $Tools, [string] $Sibling, [string] $Old, [string] $New, [string] $Out, [string] $Forms, [scriptblock] $Bodies)
    $pins = [ordered]@{}
    foreach ($p in @{ old = $Old; new = $New }.GetEnumerator() | Sort-Object Name -Descending) {
        $sha = git -C $Tools rev-parse --verify --quiet "$($p.Value)^{commit}" 2>$null
        if ($LASTEXITCODE -or -not $sha) { throw "the $($p.Name) pin, $($p.Value), is not a commit of $Tools; fetch it there first." }
        $pins[$p.Name] = $sha
    }
    if ((Test-Path -LiteralPath $Out) -and (Get-ChildItem -LiteralPath $Out -Force)) { throw "$Out is not empty; give a new directory." }
    New-Item -ItemType Directory -Path $Out -Force | Out-Null
    $Out = (Resolve-Path -LiteralPath $Out).Path

    $origin = Invoke-Git "reading the sibling's origin" -C $Sibling remote get-url origin
    Invoke-Git "listing the sibling's origin" ls-remote $origin refs/heads/main | Set-Content -LiteralPath (Join-Path $Out 'ls-remote.txt')
    $clones = [ordered]@{}
    foreach ($pin in $pins.Keys) {
        $clone = Join-Path $Out "clone-$pin"
        # The first clone fetches origin's main once; the second is made from the first.
        $from = if ($clones.Count) { $clones['old'] } else { $Sibling }
        Invoke-Git 'cloning the sibling' clone --quiet --no-checkout $from $clone | Out-Null
        if (-not $clones.Count) {
            Invoke-Git "fetching origin's main" -C $clone fetch --quiet $origin main | Out-Null
            $main = Invoke-Git 'reading the fetch' -C $clone rev-parse FETCH_HEAD
        }
        Invoke-Git 'checking out the clone' -C $clone -c advice.detachedHead=false switch --quiet --detach $main | Out-Null
        Invoke-Git 'setting origin/main' -C $clone update-ref refs/remotes/origin/main $main | Out-Null
        $scripts = Join-Path $clone 'vendor/grado-factorio-tools'
        New-Item -ItemType Directory -Path $scripts -Force | Out-Null
        $zip = Join-Path $Out "scripts-$pin.zip"
        Invoke-Git "archiving the $pin pin's scripts" -C $Tools archive --format=zip -o $zip $pins[$pin] scripts | Out-Null
        Expand-Archive -LiteralPath $zip -DestinationPath $scripts
        Remove-Item -LiteralPath $zip
        $clones[$pin] = $clone
    }

    $file = Join-Path $clones['old'] $Forms
    $list = try { @((Import-PowerShellDataFile -LiteralPath $file).Forms) } catch { throw "the forms file $file could not be read: $($_.Exception.Message)" }
    $rows = [Collections.Generic.List[object]]::new()
    $runScripts = [Collections.Generic.List[object]]::new()
    $results = @{}
    foreach ($pin in $pins.Keys) {
        $clone = $clones[$pin]
        $copy = Join-Path $clone 'vendor/grado-factorio-tools/scripts'
        $headMsg = Join-Path $Out "head-message.$pin.msg"
        Invoke-Git 'reading the HEAD message' -C $clone log -1 --format=%B | Set-Content -LiteralPath $headMsg
        foreach ($form in $list) {
            $script = if ($form.From -eq 'tools') { Join-Path $copy $form.Script } else { Join-Path $clone $form.Script }
            if ($pin -eq 'old') { $runScripts.Add($form) }
            foreach ($run in Expand-Form -Form $form -Tools $copy -HeadMsg $headMsg -Bodies $Bodies) {
                $was = $env:PR_BODY
                Push-Location -LiteralPath $clone
                try {
                    if ($null -ne $run.Body) { $env:PR_BODY = $run.Body }
                    $said = if ($null -ne $run.Stdin) { $run.Stdin | & pwsh -NoProfile -File $script @($run.Args) 2>&1 | Out-String }
                    else { & pwsh -NoProfile -File $script @($run.Args) 2>&1 | Out-String }
                    $code = $LASTEXITCODE
                }
                finally { Pop-Location; $env:PR_BODY = $was }
                Set-Content -LiteralPath (Join-Path $Out "$($run.Name).$pin.txt") -Value $said -NoNewline
                Set-Content -LiteralPath (Join-Path $Out "$($run.Name).$pin.exit") -Value $code
                if (-not $results.ContainsKey($run.Name)) { $results[$run.Name] = @{}; $rows.Add($run.Name) }
                # Each clone's own path, as either slash writes it, is the same <clone> in both.
                $results[$run.Name][$pin] = @{ Code = $code; Said = $said; Same = $said.Replace($clone, '<clone>').Replace(($clone -replace '\\', '/'), '<clone>') }
            }
        }
    }

    Write-BreakingList -Tools $Tools -Old $pins['old'] -New $pins['new'] -Out $Out

    $table = [Collections.Generic.List[string]]::new()
    $table.Add('| form | old exit | new exit | output | old last line | new last line |')
    $table.Add('| --- | --- | --- | --- | --- | --- |')
    foreach ($name in $rows) {
        $o = $results[$name]['old']; $n = $results[$name]['new']
        $oldLast = Get-LastLine $o.Said; $newLast = Get-LastLine $n.Said
        $verdict = if ($o.Same -ceq $n.Same) { 'same' } elseif ((Get-LastLine $o.Same) -ceq (Get-LastLine $n.Same)) { 'differs above the last line' } else { 'differs' }
        $table.Add("| $name | $($o.Code) | $($n.Code) | $verdict | $oldLast | $newLast |")
    }
    $hits = @(git -C $clones['old'] grep -n vendor/grado-factorio-tools/scripts HEAD -- 2>$null | ForEach-Object { $_ -replace '^HEAD:', '' })
    $toolNames = @($runScripts | Where-Object { $_.From -eq 'tools' } | ForEach-Object { Split-Path -Leaf $_.Script })
    $unrun = foreach ($hit in $hits) {
        $named = @([regex]::Matches($hit, 'vendor/grado-factorio-tools/scripts/([\w.-]+)') | ForEach-Object { $_.Groups[1].Value })
        if ($named -and -not ($named | Where-Object { $_ -notin $toolNames })) { continue }
        $hit
    }
    $table.Add('')
    $table.Add("Sibling references no form runs (``git grep -n vendor/grado-factorio-tools/scripts`` at $($main.Substring(0, 7))):")
    $table.Add('')
    # Two backticks, and a space inside each, so a hit's own backticks stay in the span.
    if ($unrun) { foreach ($u in $unrun) { $table.Add("- ```` $u ````") } } else { $table.Add('- none') }
    Set-Content -LiteralPath (Join-Path $Out 'table.md') -Value $table
    $table
}

if ($SelfTest) {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "pin-measure-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    $toolsRepo = Join-Path $temp 'tools'; $sib = Join-Path $temp 'sibling'; $out = Join-Path $temp 'out'
    $failures = 0; $n = 0
    $check = {
        param([string] $Name, [bool] $Ok, [string] $Said)
        $script:n++
        Write-Host ("self-test {0}: {1} -- {2}" -f $script:n, $Name, $(if ($Ok) { 'ok' } else { 'FAILED' }))
        if (-not $Ok) { $script:failures++; if ($Said) { Write-Host "    $Said" } }
    }
    $write = { param($path, [string[]] $text) New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null; Set-Content -LiteralPath $path -Value $text }
    $commit = { param($repo, [string[]] $msg) git -C $repo add -A; git -C $repo commit --quiet @($msg | ForEach-Object { '-m', $_ }); git -C $repo rev-parse HEAD }
    try {
        foreach ($r in $toolsRepo, $sib) {
            New-Item -ItemType Directory -Path $r -Force | Out-Null
            git -C $r init --quiet -b main; if ($LASTEXITCODE) { throw 'git init failed; the self-test needs git.' }
            git -C $r config user.email self-test@example.com; git -C $r config user.name self-test
        }
        $tool = {
            param([string] $above, [string] $last)
            'param($Mode, $Value)', 'switch ($Mode) {', "  'same' { 'same' }", "  'above' { '$above'; 'last' }", "  'last' { '$last' }",
            "  'stdin' { 'stdin: ' + [Console]::In.ReadToEnd() }", "  'headmsg' { 'head: ' + (Get-Content -LiteralPath `$Value -Raw).Trim() }",
            "  'prbody' { 'arg: ' + `$Value + '; env: ' + `$env:PR_BODY }", "  'tools' { 'tools has t.ps1: ' + (Test-Path (Join-Path `$Value 't.ps1')) }", '}', "exit $(if ($last -eq 'v2') { 3 } else { 0 })"
        }
        & $write (Join-Path $toolsRepo 'scripts/t.ps1') (& $tool 'one' 'v1')
        $oldPin = & $commit $toolsRepo '✨ feat: one'
        # Between the pins: a plain commit, a `!` with no footer, a footer spelt with a hyphen, and
        # the new pin, whose footer has a trailer in its paragraph.
        & $write (Join-Path $toolsRepo 'scripts/other.txt') 'plain'
        $null = & $commit $toolsRepo '🐛 fix: plain', 'Not breaking.'
        & $write (Join-Path $toolsRepo 'scripts/other.txt') 'bang'
        $null = & $commit $toolsRepo '✨ feat!: bang'
        & $write (Join-Path $toolsRepo 'scripts/other.txt') 'hyphen'
        $null = & $commit $toolsRepo '✨ feat: hyphen', 'BREAKING-CHANGE: written with a hyphen.'
        & $write (Join-Path $toolsRepo 'scripts/t.ps1') (& $tool 'two' 'v2')
        $newPin = & $commit $toolsRepo '✨ feat!: two', 'Body.', "BREAKING CHANGE: t.ps1 says v2.`nIt exits 3.`nCo-Authored-By: someone <a@b.c>"
        & $write (Join-Path $sib 'scripts/w.ps1') 'if (Test-Path marker.txt) { ''marker seen'' } else { ''no marker'' }', 'Set-Content marker.txt x'
        & $write (Join-Path $sib 'docs/use.md') 'Run `vendor/grado-factorio-tools/scripts/t.ps1` and `vendor/grado-factorio-tools/scripts/unrun.ps1`.'
        & $write (Join-Path $sib 'docs/run.md') 'Run `vendor/grado-factorio-tools/scripts/t.ps1` alone.'
        & $write (Join-Path $sib 'scripts/w2.ps1') '# runs vendor/grado-factorio-tools/scripts/elsewhere.ps1'
        # For the run of this script itself: forms that differ, and none that reads gh.
        & $write (Join-Path $sib 'scripts/pin-forms-offline.psd1') "@{ Forms = @( @{ Name = 'last'; From = 'tools'; Script = 't.ps1'; Args = @('last') } ) }"
        & $write (Join-Path $sib 'scripts/pin-forms.psd1') @(
            '@{ Forms = @(',
            "  @{ Name = 'same'; From = 'tools'; Script = 't.ps1'; Args = @('same') }",
            "  @{ Name = 'above'; From = 'tools'; Script = 't.ps1'; Args = @('above') }",
            "  @{ Name = 'last'; From = 'tools'; Script = 't.ps1'; Args = @('last') }",
            "  @{ Name = 'stdin'; From = 'tools'; Script = 't.ps1'; Args = @('stdin', '{stdin:{""cwd"":"".""}}') }",
            "  @{ Name = 'headmsg'; From = 'tools'; Script = 't.ps1'; Args = @('headmsg', '{headmsg}') }",
            "  @{ Name = 'prbody'; From = 'tools'; Script = 't.ps1'; Args = @('prbody', 'body={prbody:last-merged:2}') }",
            "  @{ Name = 'tools'; From = 'tools'; Script = 't.ps1'; Args = @('tools', '{tools}') }",
            "  @{ Name = 'writes'; From = 'sibling'; Script = 'scripts/w2.ps1'; Args = @() }",
            "  @{ Name = 'marker'; From = 'sibling'; Script = 'scripts/w.ps1'; Args = @() }",
            ') }')
        $null = & $commit $sib 'feat: the sibling at main'
        git -C $sib remote add origin $sib
        $stub = { param([int] $count) @(@{ Number = 8; Body = 'body eight' }, @{ Number = 7; Body = 'body seven' }) | Select-Object -First $count }
        $table = $null
        $threw = try { $table = @(Invoke-PinMeasure -Tools $toolsRepo -Sibling $sib -Old $oldPin -New $newPin -Out $out -Forms 'scripts/pin-forms.psd1' -Bodies $stub); '' } catch { $_.Exception.Message }
        & $check 'the measurement returns, with forms that differ' (-not $threw -and $table) $threw
        $read = { param($name) $p = Join-Path $out $name; if (Test-Path -LiteralPath $p) { (Get-Content -LiteralPath $p -Raw).Trim() } else { "<no $name>" } }
        $names = 'same', 'above', 'last', 'stdin', 'headmsg', 'prbody-pr8', 'prbody-pr7', 'tools', 'writes', 'marker'
        $missing = @(foreach ($f in $names) { foreach ($pin in 'old', 'new') { foreach ($ext in 'txt', 'exit') { if (-not (Test-Path -LiteralPath (Join-Path $out "$f.$pin.$ext"))) { "$f.$pin.$ext" } } } })
        & $check "each form's output and exit kept at both pins" (-not $missing) "missing: $missing"
        & $check 'the exits are kept as each pin gave them' ((& $read 'last.old.exit') -eq '0' -and (& $read 'last.new.exit') -eq '3' -and (& $read 'last.new.txt') -eq 'v2') "$(& $read 'last.old.exit') $(& $read 'last.new.exit') $(& $read 'last.new.txt')"
        & $check '{stdin:<text>} is given on stdin and taken out of the arguments' ((& $read 'stdin.old.txt') -eq 'stdin: {"cwd":"."}') (& $read 'stdin.old.txt')
        & $check "{headmsg} is a file holding the clone's HEAD message" ((& $read 'headmsg.old.txt') -eq 'head: feat: the sibling at main') (& $read 'headmsg.old.txt')
        & $check '{prbody:last-merged:2} runs once per body, in place and in PR_BODY' ((& $read 'prbody-pr8.new.txt') -eq 'arg: body=body eight; env: body eight' -and (& $read 'prbody-pr7.old.txt') -eq 'arg: body=body seven; env: body seven') "$(& $read 'prbody-pr8.new.txt') | $(& $read 'prbody-pr7.old.txt')"
        & $check "{tools} is the pin's copy of scripts/" ((& $read 'tools.old.txt') -eq 'tools has t.ps1: True') (& $read 'tools.old.txt')
        & $check "a form that writes into its clone does not show in the other pin's run" ((& $read 'marker.old.txt') -eq 'no marker' -and (& $read 'marker.new.txt') -eq 'no marker') "$(& $read 'marker.old.txt') | $(& $read 'marker.new.txt')"
        $forward = (Format-BreakingCommit @(Get-BreakingCommit -Repo $toolsRepo -Old $oldPin -New $newPin)) -join "`n"
        $back = (Format-BreakingCommit @(Get-BreakingCommit -Repo $toolsRepo -Old $newPin -New $oldPin)) -join "`n"
        $breaking = (& $read 'breaking.txt') -replace "`r"
        & $check "breaking.txt holds Format-BreakingCommit's text of the move, subject and indented footer" (
            $breaking -ceq $forward -and $breaking -cmatch "(?m)^breaking: $($newPin.Substring(0, 4))[0-9a-f]* ✨ feat!: two\n    BREAKING CHANGE: t\.ps1 says v2\.\n    It exits 3\.$") $breaking
        & $check 'a ! commit with no footer is listed, with a note under it' ($forward -cmatch '(?m)^breaking: [0-9a-f]+ ✨ feat!: bang\n    \(no BREAKING CHANGE: footer\)$') $forward
        & $check 'a BREAKING-CHANGE: footer is listed' ($forward -cmatch '(?m)^breaking: [0-9a-f]+ ✨ feat: hyphen\n    BREAKING-CHANGE: written with a hyphen\.$') $forward
        & $check "a trailer in the footer's paragraph is not printed" ($forward -match 'It exits 3\.' -and $forward -notmatch 'Co-Authored-By') $forward
        & $check 'a plain commit in the range is not listed' ($forward -notmatch 'fix: plain' -and @($forward -split "`n" | Where-Object { $_ -like 'breaking*' }).Count -eq 3) $forward
        & $check 'a pin moved back lists its breaking commits as dropped' (
            @($back -split "`n" | Where-Object { $_ -like 'breaking, dropped: *' }).Count -eq 3 -and $back -notmatch '(?m)^breaking: ' -and $back -match 'dropped: [0-9a-f]+ ✨ feat!: bang') $back
        $emptyOut = Join-Path $temp 'empty'; New-Item -ItemType Directory -Path $emptyOut | Out-Null
        Write-BreakingList -Tools $toolsRepo -Old $oldPin -New $oldPin -Out $emptyOut
        $empty = "$(Get-Content -LiteralPath (Join-Path $emptyOut 'breaking.txt') -Raw)".Trim()
        & $check 'an empty range writes none to breaking.txt' ($empty -ceq 'none') $empty
        # Commits off the old pin, outside the fixture's range, each a move of its own.
        $side = { param([string[]] $msg) git -C $toolsRepo commit-tree "$oldPin^{tree}" -p $oldPin @($msg | ForEach-Object { '-m', $_ }) }
        $text = { param($to) (Format-BreakingCommit @(Get-BreakingCommit -Repo $toolsRepo -Old $oldPin -New $to)) -join "`n" }
        $para = & $text (& $side 'feat: para', 'BREAKING CHANGE: the footer.', 'A later paragraph.')
        & $check 'a footer ends at a blank line: a later paragraph is not printed' ($para -cmatch '(?m)^    BREAKING CHANGE: the footer\.$' -and $para -notmatch 'later paragraph') $para
        $two = & $text (& $side 'feat: two', 'BREAKING CHANGE: first.', 'BREAKING-CHANGE: second.')
        & $check 'a body with two footers prints both, in order' ($two -cmatch '(?m)^    BREAKING CHANGE: first\.\n    BREAKING-CHANGE: second\.$') $two
        $plain = @(Get-BreakingCommit -Repo $toolsRepo -Old $oldPin -New (& $side 'fix: say "wow!: x"', 'breaking change: written in lower case.'))
        & $check 'a !: after the first colon, and a footer in lower case, are not breaking' (-not $plain) ($plain | Out-String)
        $order = @(Get-BreakingCommit -Repo $toolsRepo -Old (& $side 'feat!: side') -New $newPin | ForEach-Object Dropped)
        & $check 'a pin moved sideways lists what it brings in, then what it drops' (($order -join ',') -ceq 'False,False,False,True') ($order -join ',')
        $page = [Console]::OutputEncoding.CodePage
        $threw = try { $null = Get-BreakingCommit -Repo $toolsRepo -Old 0123456789abcdef -New $newPin; '' } catch { $_.Exception.Message }
        & $check "a range git cannot read throws, naming it, and the console's encoding is left as it was" (
            $threw -match 'could not read the range 0123456789abcdef\.\.' -and [Console]::OutputEncoding.CodePage -eq $page) "$threw $([Console]::OutputEncoding.CodePage)"
        $md = & $read 'table.md'
        & $check "table.md's rows: same, differs above the last line, differs" (
            $md -match '(?m)^\| same \| 0 \| 3 \| same \| same \| same \|\r?$' -and
            $md -match '(?m)^\| above \| 0 \| 3 \| differs above the last line \| last \| last \|\r?$' -and
            $md -match '(?m)^\| last \| 0 \| 3 \| differs \| v1 \| v2 \|\r?$' -and
            $md -match '(?m)^\| tools \| 0 \| 3 \| same \|') $md
        & $check 'a sibling reference to a script no form runs is listed, even inside a script a form runs; one naming only run scripts is not' (
            $md -match 'docs/use\.md:1:.*unrun\.ps1' -and $md -match 'scripts/w2\.ps1:1:.*elsewhere\.ps1' -and $md -notmatch 'docs/run\.md') $md
        $again = try { Invoke-PinMeasure -Tools $toolsRepo -Sibling $sib -Old $oldPin -New $newPin -Out $out -Forms 'scripts/pin-forms.psd1' -Bodies $stub | Out-Null; '' } catch { $_.Exception.Message }
        & $check 'an -Out that is not empty is refused' ($again -match 'not empty') $again
        # The script itself, from inside the tools repository, with a pin that is not there.
        Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $toolsRepo 'scripts/pin-measure.ps1')
        Copy-Item -LiteralPath "$PSScriptRoot/breaking-lib.ps1" -Destination (Join-Path $toolsRepo 'scripts/breaking-lib.ps1')
        $said = & pwsh -NoProfile -File (Join-Path $toolsRepo 'scripts/pin-measure.ps1') -Old 0123456789abcdef -New $newPin -Out (Join-Path $temp 'out2') 2>&1 | Out-String
        & $check 'a pin missing from the tools repository: exit 1, naming it' ($LASTEXITCODE -eq 1 -and $said -match '0123456789abcdef') "$LASTEXITCODE $said"
        # The script itself, as a sibling runs it: from its submodule, with forms that differ.
        git -C $sib -c protocol.file.allow=always submodule add --quiet $toolsRepo vendor/grado-factorio-tools 2>&1 | Out-Null
        $inSub = Join-Path $sib 'vendor/grado-factorio-tools/scripts/pin-measure.ps1'
        Copy-Item -LiteralPath $PSCommandPath -Destination $inSub
        Copy-Item -LiteralPath "$PSScriptRoot/breaking-lib.ps1" -Destination (Join-Path (Split-Path $inSub) 'breaking-lib.ps1')
        $out3 = Join-Path $temp 'out3'
        $said = & pwsh -NoProfile -File $inSub -Old $oldPin -New $newPin -Out $out3 -Forms 'scripts/pin-forms-offline.psd1' 2>&1 | Out-String
        $code = $LASTEXITCODE
        $row = if (Test-Path -LiteralPath (Join-Path $out3 'table.md')) { Get-Content -LiteralPath (Join-Path $out3 'table.md') -Raw } else { '' }
        & $check 'run from a sibling, with forms that differ: exit 0' ($code -eq 0 -and $row -match '(?m)^\| last \| 0 \| 3 \| differs \|') "$code $said"
    }
    finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host ''
    if ($failures) { Write-Host "FAILED - self-test: $failures of $n case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all $n cases."
    exit 0
}

try {
    if (-not ($Old -and $New -and $Out)) { throw 'give -Old, -New and -Out.' }
    $tools = Split-Path $PSScriptRoot -Parent
    $sibling = git -C $tools rev-parse --show-superproject-working-tree 2>$null
    $bodies = {
        param([int] $count)
        $slug = (git -C $sibling remote get-url origin) -replace '^.*github\.com[:/]', '' -replace '\.git$', ''
        $json = gh pr list --repo $slug --state merged --limit 30 --json number,body,mergedAt 2>&1
        if ($LASTEXITCODE) { throw "gh could not read $slug's merged pull requests: $json" }
        $json | ConvertFrom-Json | Sort-Object mergedAt -Descending | Select-Object -First $count | ForEach-Object { @{ Number = $_.number; Body = $_.body } }
    }
    # The pins are checked first, so a pin that is not there is named before anything else.
    foreach ($pin in $Old, $New) {
        git -C $tools rev-parse --verify --quiet "$pin^{commit}" *> $null
        if ($LASTEXITCODE) { throw "the pin $pin is not a commit of $tools; fetch it there first." }
    }
    if (-not $sibling) { throw "$tools is not a submodule of a sibling; run this from the sibling's vendor/grado-factorio-tools/scripts/." }
    Invoke-PinMeasure -Tools $tools -Sibling $sibling -Old $Old -New $New -Out $Out -Forms $Forms -Bodies $bodies
    Write-Host ''
    Write-Host "OK - pin-measure: measured $Old to $New; everything is in $Out."
    exit 0
}
catch {
    [Console]::Error.WriteLine("FAILED - pin-measure: $($_.Exception.Message)")
    exit 1
}
