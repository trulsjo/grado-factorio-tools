<#
.SYNOPSIS
    Checks a pull request body for three things: a commit it cites that is not on the main
    branch, a closing keyword that is not a `Closes #N` line, and the pr template's three
    headings. Exit 0 means each word in the body that names a commit of this repository names one
    that is an ancestor of origin/main, no line holds a closing keyword before an issue reference
    unless the line is `Closes #N` alone, and `## Summary`, `## Evidence` and `## Merge Danger`
    each stand once, in that order; exit 1 names each commit, each line and each heading that
    fails that.

.DESCRIPTION
    WHY (grado-factorio-tools#96). Pull requests here are rebase-merged, which rewrites every
    SHA on the branch, so a body that cites a branch commit cites something the merge deletes.
    docs/agents/issue-tracker.md says to cite the pull request, and a SHA only once it is on
    main. On PR #94 (2026-10-09) the body cited a commit of its own branch and a reviewer found
    it; a fixed pattern is a check's work.

    WHAT IT READS. Every word of 7 to 40 hexadecimal characters, in either case, with no letter,
    digit or underscore against it, wherever it stands: prose, a code span, a fenced block, an
    address. Each is asked of git as a commit. One that names a commit is on main when
    `git merge-base --is-ancestor` says so. A word of digits alone is read like any other, since
    an abbreviated SHA can be all digits; a count or a run id is passed over unless it happens
    to abbreviate a commit here.

    A CLOSING KEYWORD THE AUTHOR DID NOT MEAN (grado-factorio-tools#112). GitHub closes an issue
    when a pull request merges with a closing keyword before a reference to it anywhere in the
    body. PR #105 (2026-10-11) said "No ticket is closed: #103" and GitHub listed #103 as an
    issue the merge would close. docs/agents/issue-tracker.md asks for one `Closes #N` line per
    ticket closed, so a keyword before a reference anywhere else is a mistake or a second way of
    saying that line. Reported, with its line: a closing keyword in any case, then a colon or a
    space or both, then `#N`, `OWNER/REPOSITORY#N` or the address of an issue on github.com. A
    line that is `Closes #N` and nothing else is passed over. The keywords, the colon and the
    first two forms are those of
    https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/linking-a-pull-request-to-an-issue
    as read on 2026-10-12. This reads wider than that page shows: a space before the colon, and
    none after it. The address is not on the page and GitHub closes on it: the merged
    zen-browser/desktop#15894 has four such lines and lists those four issues as closed by it
    (`closingIssuesReferences`, read 2026-10-12). This half is a second job in one script,
    because CI and a session already hand this script every body; it reads the text alone and
    asks git nothing.

    THE PR TEMPLATE'S THREE HEADINGS (grado-factorio-tools#171). Truls ruled on 2026-10-19, in
    grado-factorio-modpack#320, that a pull request body carries the `mattpocock-skills:pr`
    template's `## Summary`, `## Evidence` and `## Merge Danger`, and that the ruling reaches
    realistic-fusion-refreshed too; on 2026-10-20, triaging #171, that it holds here as well.
    The rule is the modpack's, ported from
    its Get-DraftProblem (scripts/pr-body.ps1 at 0a58b02) so that the repositories read one
    definition. A heading is its line exactly, case and all, from the first column, with
    trailing spaces allowed; a line inside a fenced block is not one. Each of the three stands
    once, and then in that order. Each missing one and each repeated one is reported by name,
    a repeat with its count; with none missing or repeated, a wrong order is reported as found.
    Other sections may stand before, between and after them. An empty body lacks all three and
    fails. This half reads the text alone and asks git nothing.

    A SHALLOW CLONE IS REFUSED, and nothing is checked: there an ancestor cannot be told from a
    commit whose history was cut off. CI therefore fetches the whole history for this. Whatever
    else git cannot answer fails the run too; nothing passes for not having been asked.

    WHAT IT CANNOT SEE. A word that names no commit in this clone is counted, said to be
    unchecked, and passes: a commit of a sibling repository, or one from before a rebase that a
    fresh clone no longer holds. Run locally, origin/main is as this clone last fetched it, so
    a commit that reached main since is reported. A commit cited by fewer than 7 characters is
    not read. Whether a commit on main is the one the prose means. Anything else a body says.
    Of closing keywords: one GitHub adds after that date. One in a commit message, which that
    page says GitHub reads too. A keyword with its reference on the next line, or with markup
    or a link's bracket between the two; whether GitHub closes on those was not measured.
    Whether a `Closes #N` line names the ticket the pull request is for. And a keyword in a code
    span or a fenced block is reported like any other: the page does not say GitHub passes over
    one there.
    And a word is asked of git as a name, so a branch or a tag whose name is 7 to 40 hexadecimal
    characters answers for the commit it points at.
    Of the headings: what stands under each, and any section a repository names itself, such as
    where its review stands. An indented heading, one closed with `##`, or an underlined one is
    taken as missing, though GitHub renders each as a heading. One in an HTML comment is taken
    as a heading, though GitHub shows none. A fence is any line of optional spaces then three
    backticks or three tildes, at any indent, and the next such line closes it, whichever of the
    two it uses; CommonMark reads an indent of four or more as code, and closes a fence only
    with its own character. So a fence line in an indented code block hides every heading after
    it until the next fence line.

.PARAMETER Path
    The file holding the body, as handed to `gh pr create --body-file`.

.PARAMETER Body
    The body itself. For CI, which has it in the environment: -Body "$env:PR_BODY". Under
    `pwsh -File` the quotes matter: with the variable unset, the unquoted form hands over no
    argument and the run fails. Called from a pwsh session, as CI calls it, either form passes.

.PARAMETER Main
    The branch a cited commit must be on. origin/main unless said.

.PARAMETER SelfTest
    Run the cases that hold the check to what this header says, naming each as it runs. Needs
    git, for fixture repositories in a temp directory.

.EXAMPLE
    pwsh -File scripts/pr-body-check.ps1 ../scratch/body.md

.EXAMPLE
    ./scripts/pr-body-check.ps1 -Body "$env:PR_BODY"
#>

#Requires -Version 7
[CmdletBinding(DefaultParameterSetName = 'Path')]
param(
    [Parameter(ParameterSetName = 'Path', Mandatory, Position = 0)] [string] $Path,
    [Parameter(ParameterSetName = 'Body', Mandatory)] [AllowEmptyString()] [string] $Body,
    [Parameter(ParameterSetName = 'SelfTest', Mandatory)] [switch] $SelfTest,
    [string] $Main = 'origin/main'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

function Test-Body {
    <#  What the words of $Text that could be a SHA name in the repository at $Top, as
        @{ Off; On; Unknown }: the words naming a commit that is not on $Main, how many name one
        that is, and how many name no commit there.  #>
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Text,
        [Parameter(Mandatory)] [string] $Top,
        [Parameter(Mandatory)] [string] $Main
    )
    if ((git -C $Top rev-parse --is-shallow-repository) -ne 'false') {
        throw "This clone is shallow, so a commit on $Main cannot be told from one whose history was cut off. Fetch the whole history (git fetch --unshallow)."
    }
    $null = git -C $Top rev-parse --verify --quiet "$Main^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) { throw "git cannot resolve $Main here, so nothing can be checked against it. Fetch it, or name the branch with -Main." }

    $result = @{ Off = @(); On = 0; Unknown = 0 }
    $words = [regex]::Matches($Text, '(?<![0-9A-Za-z_])[0-9a-fA-F]{7,40}(?![0-9A-Za-z_])') | ForEach-Object Value | Sort-Object -Unique
    foreach ($word in $words) {
        $commit = git -C $Top rev-parse --verify --quiet "$word^{commit}" 2>$null
        if ($LASTEXITCODE -ne 0) { $result.Unknown++; continue }
        git -C $Top merge-base --is-ancestor $commit $Main
        if ($LASTEXITCODE -eq 0) { $result.On++ }
        elseif ($LASTEXITCODE -eq 1) { $result.Off += $word }
        else { throw "git could not say whether $word is on $Main." }
    }
    $result
}

function Get-ClosingKeyword {
    <#  Each place in $Text where a closing keyword stands before an issue reference, but on a
        line that is `Closes #N` alone, as @{ Line; Found }: the line's number and the words.  #>
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Text)
    $n = 0
    foreach ($line in $Text -split '\r?\n') {
        $n++
        if ($line -cmatch '^Closes #\d+\s*$') { continue }
        foreach ($m in [regex]::Matches($line, '(?<![0-9A-Za-z-])(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)(?:\s*:\s*|\s+)(?:(?:[\w.-]+/[\w.-]+)?#\d+|https://github\.com/[\w.-]+/[\w.-]+/issues/\d+)', 'IgnoreCase')) {
            @{ Line = $n; Found = $m.Value }
        }
    }
}

$TemplateHeadings = 'Summary', 'Evidence', 'Merge Danger'

function Get-HeadingProblem {
    <#  What is wrong with the pr template's three headings in $Text, one line each: each one
        missing, each one standing more than once, or the order they stand in. Empty if nothing
        is. Ported from grado-factorio-modpack's Get-DraftProblem (scripts/pr-body.ps1 at 0a58b02).  #>
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Text)
    $found = [System.Collections.Generic.List[string]]::new()
    $fenced = $false
    foreach ($line in $Text -split '\r?\n') {
        if ($line -match '^\s*(```|~~~)') { $fenced = -not $fenced; continue }
        if ($fenced) { continue }
        foreach ($h in $TemplateHeadings) { if ($line.TrimEnd() -ceq "## $h") { $found.Add($h) } }
    }
    $problems = @(foreach ($h in $TemplateHeadings) {
            $count = @($found | Where-Object { $_ -ceq $h }).Count
            if ($count -eq 0) { "``## $h`` is missing" }
            elseif ($count -gt 1) { "``## $h`` stands $count times" }
        })
    if (-not $problems -and ($found -join '|') -cne ($TemplateHeadings -join '|')) {
        $problems += "the headings stand in the order $($found -join ', ')"
    }
    $problems
}

function Invoke-SelfTest {
    $temp = Join-Path ([IO.Path]::GetTempPath()) "pr-body-check-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    $repo = Join-Path $temp 'repo'
    $shallow = Join-Path $temp 'shallow'
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    git -C $repo init --quiet
    if ($LASTEXITCODE -ne 0) { throw 'git init failed; the self-test needs git.' }
    $commit = {
        git -C $repo -c user.name=self-test -c user.email=self-test@example.invalid -c commit.gpgsign=false commit --quiet --allow-empty -m $args[0] 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "git could not commit '$($args[0])' in the fixture repository." }
        git -C $repo rev-parse HEAD
    }
    # Two commits on main, so that a clone of depth 1 is shallow, and one on the branch after it.
    $root = & $commit 'the first on main'
    $onMain = & $commit 'the second on main'
    git -C $repo update-ref refs/remotes/origin/main $onMain
    $onBranch = & $commit 'on the branch'
    $check = { param([string] $text, [string] $top = $repo, [string] $main = 'origin/main') Test-Body -Text $text -Top $top -Main $main }
    $run = {
        param([string[]] $Arguments)
        Push-Location $repo
        try { $text = (& pwsh -NoProfile -File $PSCommandPath @Arguments 2>&1 | Out-String) } finally { Pop-Location }
        @{ Code = $LASTEXITCODE; Text = $text }
    }

    $cases = @(
        @{ Name = 'a commit on the branch and not on main is refused, in full or abbreviated, and named once'; Test = {
            $r = & $check "Run at ``$($onBranch.Substring(0, 7))``, which is $onBranch, and again at $($onBranch.ToUpperInvariant())."
            $r.Off.Count -eq 2 -and $r.Off -contains $onBranch -and $r.Off -contains $onBranch.Substring(0, 7) -and $r.On -eq 0 } }
        @{ Name = 'a commit on main passes, in full, abbreviated, in capitals and at the end of an address; -Main names another branch to be on'; Test = {
            $r = & $check "At $onMain, at ``$($root.Substring(0, 9))``, at $($onMain.Substring(0, 12).ToUpperInvariant()) and https://example.com/commit/$($root.Substring(0, 7))"
            $other = & $check "At $onBranch." $repo 'HEAD'
            $r.Off.Count -eq 0 -and $r.On -eq 4 -and $r.Unknown -eq 0 -and $other.Off.Count -eq 0 -and $other.On -eq 1 } }
        @{ Name = 'a word that names no commit here is counted as unchecked and passes: a run id, a count, a commit of another repository, a tree'; Test = {
            $tree = git -C $repo rev-parse 'HEAD^{tree}'
            $r = & $check "Run 37917514429 took 1234567 ms; the modpack is at ``0123abc`` and defaced nothing. The tree is $tree."
            $r.Off.Count -eq 0 -and $r.On -eq 0 -and $r.Unknown -eq 5 } }
        @{ Name = 'a word that is not 7 to 40 hexadecimal characters standing alone is not read'; Test = {
            $six = $onBranch.Substring(0, 6)
            $r = & $check "Six, $six; inside a word, x$($onBranch.Substring(0, 8)), _$($onBranch.Substring(0, 8)) and $($onBranch.Substring(0, 8))_y; 41 of them, $($onBranch)0; and an empty body."
            $empty = & $check ''
            $r.Off.Count -eq 0 -and $r.On -eq 0 -and $r.Unknown -eq 0 -and $empty.Off.Count -eq 0 -and $empty.Unknown -eq 0 } }
        @{ Name = 'a shallow clone is refused, and so is a main branch git cannot resolve'; Test = {
            git clone --quiet --depth 1 "file:///$($repo -replace '\\', '/')" $shallow 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'git could not make the shallow fixture.' }
            $atShallow = try { & $check 'nothing' $shallow; 'ran' } catch { $_.Exception.Message }
            $noMain = try { & $check 'nothing' $repo 'origin/nowhere'; 'ran' } catch { $_.Exception.Message }
            Write-Host "    $atShallow`n    $noMain"
            $atShallow -match 'shallow' -and $noMain -match 'origin/nowhere' } }
        @{ Name = 'run on a body file it exits 1 naming the branch commit, and 0 on a body that cites none'; Test = {
            $file = Join-Path $temp 'body.md'
            Set-Content -LiteralPath $file -Value "## Summary`n`n## Evidence`n`nRun at ``$($onBranch.Substring(0, 7))``, after $($onMain.Substring(0, 7)) and 0123abc.`n`n## Merge Danger"
            $refused = & $run @($file)
            Set-Content -LiteralPath $file -Value "## Summary`n`n## Evidence`n`nRun on PR #94, after $($onMain.Substring(0, 7)).`n`n## Merge Danger"
            $passed = & $run @($file)
            Write-Host ($refused.Text.TrimEnd() -replace '(?m)^', '    ')
            Write-Host ($passed.Text.TrimEnd() -replace '(?m)^', '    ')
            $refused.Code -eq 1 -and $refused.Text -match "(?m)^pr-body-check: $($onBranch.Substring(0, 7)) is a commit that is not on origin/main" -and
                $refused.Text -match '1 named no commit here' -and $refused.Text -match '0 problem' -and
                $passed.Code -eq 0 -and $passed.Text -match '(?m)^OK - pr-body-check: 1 ' } }
        @{ Name = 'a closing keyword before an issue reference is found with its line: each keyword, in capitals, around a colon, in underscores, before another repository''s issue or an issue''s address, and in a code span'; Test = {
            $each = 'close', 'closes', 'closed', 'fix', 'fixes', 'fixed', 'resolve', 'resolves', 'resolved' | ForEach-Object { @(Get-ClosingKeyword "It $_ #7.").Count }
            $forms = @(Get-ClosingKeyword "Summary`n`nCLOSES #7 and Fixed: #8, with resolves:#9.`r`nIt fixes octo-org/octo-repo#100, and ``closes #10`` too.")
            $more = @(Get-ClosingKeyword "It fixes : #3, and _closes #4_, and resolves https://github.com/octo-org/octo-repo/issues/5.")
            -not ($each -ne 1) -and $each.Count -eq 9 -and $forms.Count -eq 5 -and -not ($forms[0..2].Line -ne 3) -and -not ($forms[3..4].Line -ne 4) -and
                $forms[1].Found -eq 'Fixed: #8' -and $forms[3].Found -eq 'fixes octo-org/octo-repo#100' -and
                $more.Count -eq 3 -and $more[0].Found -eq 'fixes : #3' -and $more[2].Found -eq 'resolves https://github.com/octo-org/octo-repo/issues/5' } }
        @{ Name = 'a line that is Closes #N alone passes; so do a keyword with no reference after it, a reference with no keyword before it, and a keyword that ends a longer or a hyphenated word'; Test = {
            $alone = @(Get-ClosingKeyword "Closes #7`nCloses #8  `r`n`nBody.")
            $none = @(Get-ClosingKeyword "This closes nothing. See #7, which was fixed in PR #9. A prefix #3, an unresolved #4, an auto-fix #6, and it closes the gap: #5 has more. Fixed at https://github.com/octo-org/octo-repo/pull/5.")
            $notAlone = @(Get-ClosingKeyword "Closes #7, closes #8`ncloses #9`n- Closes #10")
            $alone.Count -eq 0 -and $none.Count -eq 0 -and $notAlone.Count -eq 4 } }
        @{ Name = 'the opening of PR #105''s body as first posted is refused, naming line 4, and as reworded passes'; Test = {
            $file = Join-Path $temp 'body.md'
            $start = "## Summary`n`nTruls ruled on 2026-10-11 that ``name-check.ps1`` stays in ``realistic-fusion-refreshed`` for now.`n"
            Set-Content -LiteralPath $file -Value ($start + 'No ticket is closed: #103, the measurement, closed with #104.')
            $refused = & $run @($file)
            Set-Content -LiteralPath $file -Value ($start + 'This pull request closes no ticket. The measurement''s ticket, #103, went with #104.' + "`n`n## Evidence`n`n## Merge Danger")
            $passed = & $run @($file)
            Write-Host ($refused.Text.TrimEnd() -replace '(?m)^', '    ')
            Write-Host ($passed.Text.TrimEnd() -replace '(?m)^', '    ')
            $refused.Code -eq 1 -and $refused.Text -match '(?m)^pr-body-check: line 4 says "closed: #103"' -and $refused.Text -match '(?m)^FAILED - pr-body-check: .*1 closing keyword' -and
                $passed.Code -eq 0 -and $passed.Text -match '(?m)^OK - pr-body-check: ' } }
        @{ Name = 'the three headings in order pass, with other sections before, between and after them, trailing spaces, and CRLF line endings'; Test = {
            $lf = @(Get-HeadingProblem "Closes #1`n`n## Why`n`n## Summary`n`nA change.`n`n## Notes`n`n## Evidence  `n`nRun.`n`n## Merge Danger`t`n`nNone.`n`n## Review`n")
            $crlf = @(Get-HeadingProblem "## Summary`r`n`r`n## Evidence`r`n`r`n## Merge Danger`r`n")
            $lf.Count -eq 0 -and $crlf.Count -eq 0 } }
        @{ Name = 'a heading missing, one twice and the three out of order are each refused by name; a run with problems reports them all'; Test = {
            $missing = @(Get-HeadingProblem "## Summary`n`n## Merge Danger`n")
            $twice = @(Get-HeadingProblem "## Summary`n## Evidence`n## Evidence`n## Merge Danger`n## Evidence`n")
            $order = @(Get-HeadingProblem "## Evidence`n## Summary`n## Merge Danger`n")
            $both = @(Get-HeadingProblem "## Summary`n## Summary`n")
            $missing.Count -eq 1 -and $missing[0] -match '`## Evidence` is missing' -and
                $twice.Count -eq 1 -and $twice[0] -match '`## Evidence` stands 3 times' -and
                $order.Count -eq 1 -and $order[0] -match 'in the order Evidence, Summary, Merge Danger' -and
                $both.Count -eq 3 -and $both[0] -match 'Summary` stands 2 times' } }
        @{ Name = 'a heading only inside a fenced block, indented, closed with ##, underlined, or in other case is taken as missing'; Test = {
            $rest = "`n## Evidence`n## Merge Danger`n"
            $forms = "``````text`n## Summary`n```````n", "~~~`n## Summary`n~~~`n", "  ``````md`n## Summary`n  ```````n",
                " ## Summary`n", "## Summary ##`n", "Summary`n-------`n", "Summary`n=======`n", "## summary`n", "##Summary`n"
            $missing = @($forms | ForEach-Object { @(Get-HeadingProblem ($_ + $rest)) | Where-Object { $_ -match '`## Summary` is missing' } })
            $missing.Count -eq $forms.Count } }
        @{ Name = 'run on a body without the headings, or an empty one, it exits 1 naming each heading missing'; Test = {
            $file = Join-Path $temp 'body.md'
            Set-Content -LiteralPath $file -Value 'Just prose, with no headings.'
            $refused = & $run @($file)
            $empty = & $run @('-Body', '')
            Write-Host ($refused.Text.TrimEnd() -replace '(?m)^', '    ')
            $refused.Code -eq 1 -and $empty.Code -eq 1 -and
                @([regex]::Matches($refused.Text, '(?m)^pr-body-check: `## (Summary|Evidence|Merge Danger)` is missing')).Count -eq 3 -and
                $refused.Text -match '(?m)^FAILED - pr-body-check: .*3 problem' } }
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

$top = git rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) { throw 'git found no repository here. Run it inside the repository.' }
if ($Path) { $Body = Get-Content -LiteralPath $Path -Raw }

$read = Test-Body -Text "$Body" -Top $top -Main $Main
foreach ($word in $read.Off) {
    Write-Host "pr-body-check: $word is a commit that is not on $Main. A rebase-merge rewrites it: cite the pull request, or the commit once it is on main."
}
$closing = @(Get-ClosingKeyword -Text "$Body")
foreach ($c in $closing) {
    Write-Host "pr-body-check: line $($c.Line) says `"$($c.Found)`", which GitHub reads as closing that issue when this merges. If it is meant, give it a line of its own, as Closes #N; if not, reword it."
}
$headings = @(Get-HeadingProblem -Text "$Body")
foreach ($h in $headings) {
    Write-Host "pr-body-check: $h. The body carries ## Summary, ## Evidence and ## Merge Danger, once each and in that order."
}
$unchecked = if ($read.Unknown) { " $($read.Unknown) named no commit here and were NOT checked." } else { '' }
if ($read.Off -or $closing -or $headings) {
    Write-Host ''
    Write-Host "FAILED - pr-body-check: $($read.Off.Count) word(s) of the body name a commit that is not on $Main, $($closing.Count) closing keyword(s) stand outside a Closes #N line, and $($headings.Count) problem(s) with the pr template's three headings.$unchecked"
    exit 1
}
Write-Host "OK - pr-body-check: $($read.On) word(s) of the body name a commit, each on $Main, no closing keyword stands outside a Closes #N line, and the pr template's three headings stand once each, in order.$unchecked"
exit 0
