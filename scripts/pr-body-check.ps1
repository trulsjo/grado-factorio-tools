<#
.SYNOPSIS
    Checks a pull request body for four things: a commit it cites that is not on the main
    branch, a closing keyword that is not a `Closes #N` line, the pr template's three headings,
    and its four markers. Exit 0 means each word in the body that names a commit of this
    repository names one that is an ancestor of origin/main, no line holds a closing keyword
    before an issue reference unless the line is `Closes #N` alone, `## Summary`, `## Evidence`
    and `## Merge Danger` each stand once, in that order, and **Before:** and **After:** stand
    under `## Evidence` and **Door:** and **Blast Radius:** under `## Merge Danger`; exit 1 names
    each commit, each line, each heading and each marker that fails that. With -CiteSiblings, a
    fifth: each statement about a sibling repository carries a commit and an ISO date, and exit
    1 names each sentence that does not.

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
    The rule is the modpack's, ported from its Get-DraftProblem (scripts/pr-body.ps1 at
    0a58b02, read 2026-10-20) so that the repositories read one definition. A heading is its
    line exactly, case and all, from the first column, with trailing whitespace allowed: spaces,
    tabs, and the carriage return of a CRLF line. A line inside a fenced block is not one. Each
    of the three stands once, and then in that order. Each missing one and each repeated one is
    reported by name, a repeat with its count; with none missing or repeated, a wrong order is
    reported as found. Other sections may stand before, between and after them. An empty body
    lacks all three and fails. This third job reads the text alone and asks git nothing.

    THE PR TEMPLATE'S FOUR MARKERS (grado-factorio-tools#185). A body written by hand to the three
    headings alone passed the third job: realistic-fusion-refreshed#743 and
    realistic-fusion-refreshed#747 held none of the template's markers (read 2026-10-21). Truls
    ruled on 2026-10-21, on #185, that the check reaches them, and that a change with nothing to
    show says none after **Before:** and **After:**. A marker is its text exactly, `**Before:**`,
    `**After:**`, `**Door:**` or `**Blast Radius:**`, case, asterisks and colon and all, anywhere
    in a line under its own heading: from that heading's line to the next line that begins `## `.
    A line in a fenced block, by the fence rule above, is not read. Each marker missing is
    reported with its heading; a heading that is missing has its markers reported missing too.
    A body written before #185 may fail it: merged #184's Evidence writes `**After, on the
    branch:**`, which is not the marker. A merged body is not checked again unless it is edited:
    check.yml runs on `edited` and does not ask whether the pull request is merged. This fourth
    job reads the text alone and asks git nothing.

    A STATEMENT ABOUT A SIBLING CARRIES ITS COMMIT AND ITS DATE, WITH -CiteSiblings
    (grado-factorio-tools#177). docs/agents/code-review-prose.md held a body to this, and only a
    review's prose lane read it, after the pull request was open: PR #174's body said "No sibling
    calls it until its pin moves", which that lane found. Truls ruled on 2026-10-20, on #177,
    what is read. A sentence is a statement when it names grado-factorio-modpack or
    realistic-fusion-refreshed, or holds the word "sibling" or "siblings" as a word of its own,
    in any case. So does one holding "modpack" as a word of its own, in any case, or "RFR" as
    one, in capitals (Truls, 2026-10-25, #229): PR #228's first body said "The modpack's staged
    sets all declare `2.0`" with no commit and no date. A letter, digit, - or _ on either side
    makes either part of another word, as in resolve-modpack. So "a modpack", about modpacks in
    general, is held too: it needs a commit and a date, or a rewording. Neither short spelling
    is read in a code span, a run of backticks to the next run of the same length (Truls,
    2026-10-26, #234): PR #231's body, about this check, could not name the two spellings
    without a commit it had no source for. The full names and "sibling" are read in a code
    span too, so a sibling named only there is still seen. A bare reference to a
    sibling's ticket or pull request, `grado-factorio-modpack#337` with or without `trulsjo/`
    before it, is taken out first, so a sentence holding only that is none. A statement carries
    a commit and an ISO date: a word of 7 to 40 hexadecimal characters with a digit among them,
    and a YYYY-MM-DD. The rule is this repository's, so it is asked for: both siblings run this
    script on their pull request bodies, from their pin (grado-factorio-modpack's check.yml at
    dcb10df and realistic-fusion-refreshed's gates.yml at 9f3504f, read 2026-10-20), and a run
    there that does not ask checks what it did before (Truls, 2026-10-20). This repository's CI
    asks, and so does the command before `gh pr create` in docs/agents/issue-tracker.md.

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
    two it uses and however long. CommonMark reads an indent of four or more as code, closes a
    fence only with its own character at least as long, and reads a backtick line with a
    backtick after its opening run, such as a code span, as no fence. So the check can be wrong
    both ways. A fence line in an indented code block, or a line opening with a code span, hides
    every heading after it until the next fence line. A fence of one character inside one of
    the other, or a shorter fence inside a longer one, ends the outer fence early, and a
    heading inside it is counted.
    Of the markers: what follows each, so whether a marker says none or something true, and
    whether the line means it: one in a code span, or quoted in a sentence, counts. A section
    ends only at a level-2 heading, so a `# ` heading after `## Evidence` does not end it. A
    marker under a heading that stands twice counts under either.
    Of statements about a sibling: whether the commit and the date are the sibling's, or true. A
    sentence is cut where a . ! or ? is followed by a space and anything but a lower-case letter,
    so "e.g. A" ends one, and a commit cited in the next part is not counted, though not inside a
    code span; a paragraph's lines
    are joined, and a list item, a heading or a table row stands alone. A line in a fenced block
    is not read, by the fence rule above. Nor is an indented code block (#233): a line of four
    spaces or a tab and then text, after a blank line or at the start, with the indented and
    blank lines after it, a fence line among them. After a list item, an indented line is the
    item's and read, until a paragraph, heading, table row or fence starts at the margin.
    CommonMark asks instead whether the line is indented four past the item's content, so a code
    block in an item, six spaces in under `- `, is read here though GitHub shows it as code. So
    is an indented block in a block quote, one straight after a heading or a fence line with no
    blank line between, which CommonMark also reads as code, and one indented by a tab after
    fewer than four spaces. A sibling named by an address that holds its name is read as a
    statement. One named by its title is seen only
    through "modpack" in it, so "Realistic Fusion Refreshed" is not, nor is one named by any
    spelling but its name, the word, "modpack" and "RFR". A run id of 7 or more digits counts as
    a commit.

.PARAMETER Path
    The file holding the body, as handed to `gh pr create --body-file`.

.PARAMETER Body
    The body itself. For CI, which has it in the environment: -Body "$env:PR_BODY". Under
    `pwsh -File` the quotes matter: with the variable unset, the unquoted form hands over no
    argument and the run fails. Called from a pwsh session, as CI calls it, either form passes.

.PARAMETER Main
    The branch a cited commit must be on. origin/main unless said.

.PARAMETER CiteSiblings
    Hold each statement about a sibling to a commit and an ISO date, as above. Off unless asked.

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
    [string] $Main = 'origin/main',
    [switch] $CiteSiblings
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
        is. Ported from grado-factorio-modpack's Get-DraftProblem (scripts/pr-body.ps1 at
        0a58b02).  #>
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

$TemplateMarkers = [ordered]@{ 'Evidence' = 'Before', 'After'; 'Merge Danger' = 'Door', 'Blast Radius' }

function Get-MarkerProblem {
    <#  Each of the pr template's four markers that stands nowhere under its own heading in $Text,
        one line each. Empty if none is missing.  #>
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Text)
    $found = [System.Collections.Generic.HashSet[string]]::new()
    $section = $null; $fenced = $false
    foreach ($line in $Text -split '\r?\n') {
        if ($line -match '^\s*(```|~~~)') { $fenced = -not $fenced; continue }
        if ($fenced) { continue }
        # Any level-2 heading ends a section; only one of the template's starts one.
        if ($line -match '^## ') { $section = $TemplateMarkers.Keys | Where-Object { $line.TrimEnd() -ceq "## $_" }; continue }
        if (-not $section) { continue }
        foreach ($m in $TemplateMarkers[$section]) { if ($line.Contains("**${m}:**")) { [void] $found.Add($m) } }
    }
    foreach ($h in $TemplateMarkers.Keys) {
        foreach ($m in $TemplateMarkers[$h]) { if (-not $found.Contains($m)) { "``**${m}:**`` is missing under ``## $h``" } }
    }
}

function Get-SiblingProblem {
    <#  Each sentence of $Text that is a statement about a sibling repository and lacks a commit
        or an ISO date, as @{ Line; Missing; Sentence }: the line its block starts on, what it
        lacks, and the sentence.  #>
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Text)
    # Blocks: a paragraph's lines joined, a list item, a heading or a table row; nothing fenced,
    # and no indented code block: a line indented four spaces or a tab after a blank line or the
    # start, outside a list item, and the indented and blank lines after it (#233).
    $blocks = [System.Collections.Generic.List[hashtable]]::new()
    $current = $null; $fenced = $false; $blank = $true; $inList = $false; $n = 0
    foreach ($line in $Text -split '\r?\n') {
        $n++
        # Inside such a block $blank stays true, so each indented line after it is skipped too.
        if (-not $fenced -and $blank -and -not $inList -and $line -match '^(?: {4}|\t)\s*\S') { $current = $null; continue }
        if ($line -match '^\s*(```|~~~)') {
            # A fence at the margin ends a list item, as a paragraph there does.
            $fenced = -not $fenced; $current = $null; $blank = $false
            if ($line -match '^\S') { $inList = $false }
            continue
        }
        if ($fenced) { continue }
        if ($line -match '^\s*$') { $current = $null; $blank = $true; continue }
        $blank = $false
        if ($null -eq $current -or $line -match '^\s*(?:[-*+]|\d+[.)]|#{1,6})\s|^\s*\|') {
            $current = @{ Line = $n; Text = $line.Trim() }; $blocks.Add($current)
            # An indented block after a list item is the item's, until a block at the margin.
            $inList = $line -match '^\s*(?:[-*+]|\d+[.)])\s' -or ($inList -and $line -match '^\s')
        }
        else { $current.Text += ' ' + $line.Trim() }
    }
    foreach ($b in $blocks) {
        # A sentence ends at . ! or ? before a space and anything but a lower-case letter.
        # Not inside a code span: its spaces are held out of the cut and put back after.
        $held = [regex]::Replace($b.Text, '(?<!`)(`+)(?!`).*?(?<!`)\1(?!`)', { param($m) $m.Value.Replace(' ', [char] 1) })
        foreach ($sentence in [regex]::Split($held, '(?<=[.!?])\s+(?=[^a-z\s])') | ForEach-Object { $_.Replace([char] 1, ' ') }) {
            $plain = $sentence -replace '(?<![\w.-])(?:trulsjo/)?(?:grado-factorio-modpack|realistic-fusion-refreshed)#\d+', ''
            # The two short spellings are not read in a code span; the full names are (#234).
            $spanless = $plain -replace '(?<!`)(`+)(?!`).*?(?<!`)\1(?!`)', ''
            if ($plain -notmatch 'grado-factorio-modpack|realistic-fusion-refreshed|\bsiblings?\b' -and
                $spanless -notmatch '(?<![\w-])(?:modpack|(?-i:RFR))(?![\w-])') { continue }
            $missing = @()
            if ($sentence -notmatch '(?<![0-9A-Za-z_])(?=[a-fA-F]*\d)[0-9a-fA-F]{7,40}(?![0-9A-Za-z_])') { $missing += 'a commit' }
            if ($sentence -notmatch '(?<!\d)\d{4}-\d{2}-\d{2}(?!\d)') { $missing += 'an ISO date' }
            if ($missing) { @{ Line = $b.Line; Missing = $missing -join ' and '; Sentence = $sentence } }
        }
    }
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
    # The two headings that carry markers, each with its markers, for a body that is to pass.
    $marked = "## Evidence`n`n**Before:** none`n**After:** none`n`n## Merge Danger`n`n**Door:** two-way`n`n**Blast Radius:** none"
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
            Set-Content -LiteralPath $file -Value "## Summary`n`nRun on PR #94, after $($onMain.Substring(0, 7)).`n`n$marked"
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
            Set-Content -LiteralPath $file -Value ($start + 'This pull request closes no ticket. The measurement''s ticket, #103, went with #104.' + "`n`n$marked")
            $passed = & $run @($file)
            Write-Host ($refused.Text.TrimEnd() -replace '(?m)^', '    ')
            Write-Host ($passed.Text.TrimEnd() -replace '(?m)^', '    ')
            $refused.Code -eq 1 -and $refused.Text -match '(?m)^pr-body-check: line 4 says "closed: #103"' -and $refused.Text -match '(?m)^FAILED - pr-body-check: .*1 closing keyword' -and
                $passed.Code -eq 0 -and $passed.Text -match '(?m)^OK - pr-body-check: ' } }
        @{ Name = 'the three headings in order pass, with other sections before, between and after them, trailing whitespace, and CRLF line endings (whose carriage return the trim takes)'; Test = {
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
        @{ Name = 'PR #174''s first-drafted sentence about a sibling is refused, naming it, and passes with a commit and an ISO date'; Test = {
            $bare = @(Get-SiblingProblem 'No sibling calls it until its pin moves.')
            $cited = @(Get-SiblingProblem 'No sibling calls it until its pin moves past 3e86514, merged 2026-10-20.')
            $bare.Count -eq 1 -and $bare[0].Missing -eq 'a commit and an ISO date' -and $bare[0].Sentence -eq 'No sibling calls it until its pin moves.' -and
                $cited.Count -eq 0 } }
        @{ Name = 'a sentence naming either sibling repository, or Siblings in capitals, with only one of the two is refused, and only that sentence of its paragraph'; Test = {
            $commitOnly = @(Get-SiblingProblem "Intro.`n`ngrado-factorio-modpack pins a882314. Its gate is fine.")
            $dateOnly = @(Get-SiblingProblem 'realistic-fusion-refreshed was read on 2026-10-20.')
            $capital = @(Get-SiblingProblem 'Siblings are untouched, read 2026-10-20.')
            $commitOnly.Count -eq 1 -and $commitOnly[0].Line -eq 3 -and $commitOnly[0].Missing -eq 'an ISO date' -and $commitOnly[0].Sentence -eq 'grado-factorio-modpack pins a882314.' -and
                $dateOnly.Count -eq 1 -and $dateOnly[0].Missing -eq 'a commit' -and $capital.Count -eq 1 } }
        @{ Name = 'a bare reference to a sibling''s ticket or pull request is no statement, nor is the word inside a longer one or a title without modpack; an address is read; a sentence in a fenced block is not read, and a hex word with no digit is no commit'; Test = {
            $refs = @(Get-SiblingProblem "Filed as grado-factorio-modpack#337, after trulsjo/realistic-fusion-refreshed#12.`n- Unblocks grado-factorio-modpack#331.")
            $fenced = @(Get-SiblingProblem "``````text`nThe sibling is grado-factorio-modpack.`n```````n")
            $word = @(Get-SiblingProblem 'The sibling defaced nothing on 2026-10-20.')
            $inName = @(Get-SiblingProblem 'Get-SiblingProblem and -CiteSiblings are new.')
            # Held to what the header says is not seen: a title without modpack. An address
            # holding the name is read.
            $title = @(Get-SiblingProblem 'The Realistic Fusion Refreshed pins this.')
            $address = @(Get-SiblingProblem 'See https://github.com/trulsjo/grado-factorio-modpack for it.')
            $refs.Count -eq 0 -and $fenced.Count -eq 0 -and $word.Count -eq 1 -and $word[0].Missing -eq 'a commit' -and $inName.Count -eq 0 -and
                $title.Count -eq 0 -and $address.Count -eq 1 } }
        @{ Name = 'the modpack and RFR, each a word of its own, are refused and pass with a commit and an ISO date, and so is the modpack''s title; inside a longer word on either side, or rfr in lower case, they are none (#229)'; Test = {
            $modpack = @(Get-SiblingProblem 'The modpack is at its pin.')
            $modpackCited = @(Get-SiblingProblem 'The modpack is at its pin, 6be6609, read 2026-10-25.')
            $rfr = @(Get-SiblingProblem 'RFR''s gate runs it.')
            $rfrCited = @(Get-SiblingProblem 'RFR''s gate runs it at ff59e79, read 2026-10-25.')
            $modpackTitle = @(Get-SiblingProblem 'The Grado Factorio Modpack pins this.')
            $inWord = @(Get-SiblingProblem '`resolve-modpack.ps1` reads it.')
            $after = @(Get-SiblingProblem 'modpack-check and RFRs read it.')
            $lower = @(Get-SiblingProblem 'rfr is a prefix.')
            $modpack.Count -eq 1 -and $modpack[0].Missing -eq 'a commit and an ISO date' -and $modpackCited.Count -eq 0 -and
                $rfr.Count -eq 1 -and $rfr[0].Missing -eq 'a commit and an ISO date' -and $rfrCited.Count -eq 0 -and
                $modpackTitle.Count -eq 1 -and $inWord.Count -eq 0 -and $after.Count -eq 0 -and $lower.Count -eq 0 } }
        @{ Name = 'an indented code block after a blank line is not read, nor after a list a fence at the margin ended; the same line under a list item, or a paragraph''s indented continuation, is (#233)'; Test = {
            $code = @(Get-SiblingProblem "Intro.`n`n    pr-body-check: line 9 says the modpack is old.`n`n    It still is.`nAfter.")
            $start = @(Get-SiblingProblem "`tThe sibling is old.")
            $item = @(Get-SiblingProblem "- An item.`n`n    pr-body-check: line 9 says the modpack is old.")
            $joined = @(Get-SiblingProblem "Intro says`n    the modpack is old.")
            $afterFence = @(Get-SiblingProblem "- An item.`n`n``````text`nx`n```````n`n    the modpack is old.")
            $code.Count -eq 0 -and $start.Count -eq 0 -and $item.Count -eq 1 -and $item[0].Line -eq 3 -and $afterFence.Count -eq 0 -and
                $joined.Count -eq 1 -and $joined[0].Sentence -eq 'Intro says the modpack is old.' } }
        @{ Name = 'the modpack and RFR in a code span are not read, nor in one holding a sentence break; a full name in one is, and so is a short spelling outside the span (#234)'; Test = {
            $spanned = @(Get-SiblingProblem 'Case 17 holds `modpack` as a word. `RFR` is a spelling. ``modpack`` too.')
            $fullName = @(Get-SiblingProblem '`grado-factorio-modpack` pins its pin.')
            $outside = @(Get-SiblingProblem 'The modpack pins `x`.')
            $cut = @(Get-SiblingProblem 'Quoted `the modpack is old. Add a commit` here.')
            $spanned.Count -eq 0 -and $cut.Count -eq 0 -and $fullName.Count -eq 1 -and $outside.Count -eq 1 } }
        @{ Name = 'run with -CiteSiblings on such a body it exits 1 naming the line; without it, as a sibling''s CI runs it, the same body passes'; Test = {
            $file = Join-Path $temp 'body.md'
            Set-Content -LiteralPath $file -Value "## Summary`n`nNo sibling calls it until its pin moves.`n`n$marked"
            $refused = & $run @($file, '-CiteSiblings')
            $passed = & $run @($file)
            Write-Host ($refused.Text.TrimEnd() -replace '(?m)^', '    ')
            $refused.Code -eq 1 -and $refused.Text -match '(?m)^pr-body-check: line 3 says "No sibling calls it until its pin moves\.", a statement about a sibling with no commit and no ISO date' -and
                $refused.Text -match '(?m)^FAILED - pr-body-check: .*1 statement' -and $passed.Code -eq 0 } }
        @{ Name = 'the four markers each under its heading pass: in a list, after a ### heading or other lines, and with none after Before and After; run on such a body it exits 0'; Test = {
            $listed = @(Get-MarkerProblem "## Summary`n`n## Evidence`n`nRun.`n`n### Runs`n`n- **Before:** 3 failed`n- **After:** none failed`n`n## Merge Danger`n`n**Door:** one-way`n`nWhy.`n`n**Blast Radius:** consumers`n`n## Review")
            $file = Join-Path $temp 'body.md'
            Set-Content -LiteralPath $file -Value "## Summary`n`nA change.`n`n$marked"
            $passed = & $run @($file)
            Write-Host ($passed.Text.TrimEnd() -replace '(?m)^', '    ')
            $listed.Count -eq 0 -and @(Get-MarkerProblem "## Summary`n`n$marked").Count -eq 0 -and
                $passed.Code -eq 0 -and $passed.Text -match '(?m)^OK - pr-body-check: .*, in order, with ## Evidence and ## Merge Danger each carrying its markers\.' } }
        @{ Name = 'a body with the three headings and no marker is refused, naming each of the four and its heading; one under the wrong heading, in other case, without its colon, or only in a fenced block is missing'; Test = {
            $file = Join-Path $temp 'body.md'
            Set-Content -LiteralPath $file -Value "## Summary`n`nA change.`n`n## Evidence`n`nIt works.`n`n## Merge Danger`n`nLow."
            $refused = & $run @($file)
            Write-Host ($refused.Text.TrimEnd() -replace '(?m)^', '    ')
            $named = @('Before', 'After' | ForEach-Object { "\*\*${_}:\*\*`` is missing under ``## Evidence``" }) + @('Door', 'Blast Radius' | ForEach-Object { "\*\*${_}:\*\*`` is missing under ``## Merge Danger``" })
            $wrong = @(Get-MarkerProblem ("## Summary`n`n**Before:** none`n`n## Evidence`n`n**after:** none`n**Before** none`n**Door:** two-way`n`n" +
                "## Merge Danger`n`n**After:** none`n``````text`n**Door:** two-way`n```````n**Blast Radius:** none"))
            $refused.Code -eq 1 -and -not ($named | Where-Object { $refused.Text -notmatch "(?m)^pr-body-check: ``$_" }) -and
                $refused.Text -match '(?m)^FAILED - pr-body-check: .*4 marker' -and
                $refused.Text -match '\*\*Before:\*\* and \*\*After:\*\*, each saying none where there is nothing to show, and under ## Merge Danger \*\*Door:\*\* and \*\*Blast Radius:\*\*\.' -and
                ($wrong -join '|') -eq ('`**Before:**` is missing under `## Evidence`|`**After:**` is missing under `## Evidence`|' +
                    '`**Door:**` is missing under `## Merge Danger`') } }
        @{ Name = 'any other ## heading ends a section: a marker after it is missing'; Test = {
            $after = @(Get-MarkerProblem ("## Evidence`n`n**Before:** none`n`n## Notes`n`n**After:** none`n`n" +
                "## Merge Danger`n`n**Door:** two-way`n`n## Review`n`n**Blast Radius:** none"))
            ($after -join '|') -eq '`**After:**` is missing under `## Evidence`|`**Blast Radius:**` is missing under `## Merge Danger`' } }
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
$markers = @(Get-MarkerProblem -Text "$Body")
foreach ($m in $markers) {
    Write-Host "pr-body-check: $m. Under ## Evidence the body carries **Before:** and **After:**, each saying none where there is nothing to show, and under ## Merge Danger **Door:** and **Blast Radius:**."
}
$siblings = @(if ($CiteSiblings) { Get-SiblingProblem -Text "$Body" })
foreach ($s in $siblings) {
    Write-Host "pr-body-check: line $($s.Line) says `"$($s.Sentence)`", a statement about a sibling with no $($s.Missing -replace '^an? ' -replace ' and an? ', ' and no '). Give it the commit and the date it was read at."
}
$unchecked = if ($read.Unknown) { " $($read.Unknown) named no commit here and were NOT checked." } else { '' }
$found = @("$($read.Off.Count) word(s) of the body name a commit that is not on $Main", "$($closing.Count) closing keyword(s) stand outside a Closes #N line",
    "$($headings.Count) problem(s) with the pr template's three headings", "$($markers.Count) marker(s) of the pr template missing")
if ($CiteSiblings) { $found += "$($siblings.Count) statement(s) about a sibling lack a commit or an ISO date" }
if ($read.Off -or $closing -or $headings -or $markers -or $siblings) {
    Write-Host ''
    Write-Host "FAILED - pr-body-check: $(($found | Select-Object -SkipLast 1) -join ', '), and $($found[-1]).$unchecked"
    exit 1
}
$cited = if ($CiteSiblings) { ' Each statement about a sibling carries a commit and an ISO date.' } else { '' }
Write-Host "OK - pr-body-check: $($read.On) word(s) of the body name a commit, each on $Main, no closing keyword stands outside a Closes #N line, and the pr template's three headings stand once each, in order, with ## Evidence and ## Merge Danger each carrying its markers.$cited$unchecked"
exit 0
