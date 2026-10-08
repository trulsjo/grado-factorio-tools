<#
.SYNOPSIS
    Checks Markdown for three things a machine can decide: emphasis or a code span left open at
    the end of its paragraph, a table row whose column count differs from its header's, and a
    link to a file in the repository that is not there. Exit 0 means none was found in the files
    read; exit 1 names each as <file>:<line>: <what>.

.DESCRIPTION
    A PRE-COMMIT CHECK (grado-factorio-modpack#149, where it was written). Run with no arguments,
    as a pre-commit hook does, it reads the staged Markdown files as they are staged, not as they
    are on disk. A review there on 2026-10-05 found emphasis that could not close, so the rest of
    a note rendered wrongly, and a reviewer had to find it. It reads the repository it is run in,
    which need not be the one that holds it, and from any directory inside that repository it
    reads the same files and says the same. In grado-factorio-tools, which holds it,
    scripts/check.ps1 runs it with -All.

    WHAT IT READS AS WHAT. A paragraph ends at a blank line, a heading, a list item, a table or a
    fenced code block; nothing inside a fence is read, and a fence never closed is reported. A
    number ends a paragraph only as `1.`; inside a numbered list any number is the next item.
    Emphasis follows CommonMark's flanking rules: a `*` or `_` with whitespace on both sides is a
    literal, so is a `_` inside a word, and so is a closer with nothing to close. Only an opener
    still open when its paragraph ends is reported, and a lone `*` that could open is one: `*.md`
    in prose wants a code span or `\*`. A table is a line holding a `|` followed by a delimiter
    row holding one; every line after it up to a blank line is a row, and each cell is read as a
    paragraph of its own. A link is `[text](target)` or a `[label]: target` line; a target with a
    scheme (`https:`, `mailto:`) or that is only a `#fragment` is not checked, and the rest must
    name a file or directory git tracks, in exact case, as GitHub serves it.

    WHAT IT CANNOT SEE. Prose: numbers, dates and quantifiers stay the reviewer's. Whether a
    `#fragment` names a heading. A code block made by
    indenting, which is read as text. Emphasis that closes in the wrong place, or that a bullet nested in a
    numbered item leaves open and the next numbered item closes. Markdown outside
    `.md` files. A link whose target a commit deletes or renames, unless the linking file is
    staged too: -All sees it. A link into a submodule is asked of the working tree, so neither its
    case nor whether git tracks it is checked; into one not initialised it is said to be unchecked,
    and passes.

.PARAMETER Range
    Check the Markdown files changed in a commit range, as they are at its end:
    -Range origin/main..HEAD. The same switch as commit-check.ps1's.

.PARAMETER All
    Check every tracked Markdown file, as staged.

.PARAMETER SelfTest
    Prove each of the three can fail and a clean file passes, and that a commit's staged content is
    what is read. Needs git, for a fixture repository in a temp directory.

.EXAMPLE
    pwsh -File scripts/markdown-check.ps1

.EXAMPLE
    pwsh -File scripts/markdown-check.ps1 -Range origin/main..HEAD
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $Range,
    [switch] $All,
    [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

function Test-Inline {
    <#  The openers left open in one paragraph: a backtick run with no partner, and `*` or `_`
        emphasis never closed. Each as @{ Offset; Message }, the offset into $Text.  #>
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Text)

    # Code spans and backslash escapes first, left to right, since each hides the other: what is
    # inside a code span is not emphasis, and an escaped backtick opens no span. A span is masked
    # with backticks, which are punctuation to the flanking rules below, as its delimiters are.
    $chars = $Text.ToCharArray()
    $i = 0
    while ($i -lt $chars.Length) {
        if ($chars[$i] -eq '\' -and $i + 1 -lt $chars.Length -and ([char]::IsPunctuation($chars[$i + 1]) -or [char]::IsSymbol($chars[$i + 1]))) {
            $chars[$i + 1] = '.'; $i += 2; continue
        }
        if ($chars[$i] -ne '`') { $i++; continue }
        $n = 1
        while ($i + $n -lt $chars.Length -and $chars[$i + $n] -eq '`') { $n++ }
        $close = -1
        $j = $i + $n
        while ($j -lt $chars.Length) {
            if ($chars[$j] -ne '`') { $j++; continue }
            $m = 1
            while ($j + $m -lt $chars.Length -and $chars[$j + $m] -eq '`') { $m++ }
            if ($m -eq $n) { $close = $j; break }
            $j += $m
        }
        if ($close -lt 0) {
            @{ Offset = $i; Message = "a code span opened with $('`' * $n) is not closed in its paragraph" }
            for ($k = $i; $k -lt $i + $n; $k++) { $chars[$k] = '.' }
            $i += $n; continue
        }
        for ($k = $i; $k -lt $close + $n; $k++) { if ($chars[$k] -ne "`n") { $chars[$k] = '`' } }
        $i = $close + $n
    }
    $masked = [string]::new($chars)
    # A link's target and a bare address are not prose: a_b_c in one is no emphasis.
    $hide = { param($m) '.' * $m.Length }
    $masked = [regex]::Replace($masked, '(?<=\])\([^)\s]*(\s+"[^"]*")?\)', $hide)
    $masked = [regex]::Replace($masked, '<[a-zA-Z][^>\s]*>|https?://[^\s)>]+', $hide)

    $isSpace = { param($c) $null -eq $c -or [char]::IsWhiteSpace($c) }
    $isPunct = { param($c) $null -ne $c -and ([char]::IsPunctuation($c) -or [char]::IsSymbol($c)) }
    $open = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($run in [regex]::Matches($masked, '\*+|_+')) {
        $prev = if ($run.Index -gt 0) { $masked[$run.Index - 1] } else { $null }
        $next = if ($run.Index + $run.Length -lt $masked.Length) { $masked[$run.Index + $run.Length] } else { $null }
        $left  = -not (& $isSpace $next) -and (-not (& $isPunct $next) -or (& $isSpace $prev) -or (& $isPunct $prev))
        $right = -not (& $isSpace $prev) -and (-not (& $isPunct $prev) -or (& $isSpace $next) -or (& $isPunct $next))
        $char = $run.Value[0]
        $canOpen  = if ($char -eq '_') { $left -and (-not $right -or (& $isPunct $prev)) } else { $left }
        $canClose = if ($char -eq '_') { $right -and (-not $left -or (& $isPunct $next)) } else { $right }
        $length = $run.Length
        while ($canClose -and $length -gt 0) {
            $at = $open.FindLastIndex([Predicate[hashtable]] { param($o) $o.Char -eq $char })
            if ($at -lt 0) { break }
            # An opener of the other kind above it can no longer close around this one: a literal.
            if ($at + 1 -lt $open.Count) { $open.RemoveRange($at + 1, $open.Count - $at - 1) }
            $used = [Math]::Min($length, $open[$at].Length)
            $open[$at].Length -= $used
            $length -= $used
            if ($open[$at].Length -eq 0) { $open.RemoveAt($at) }
        }
        if ($canOpen -and $length -gt 0) { $open.Add(@{ Char = $char; Length = $length; Offset = $run.Index }) }
    }
    foreach ($o in $open) { @{ Offset = $o.Offset; Message = "emphasis opened with $([string]::new($o.Char, $o.Length)) is not closed in its paragraph" } }
}

function Split-TableRow {
    <#  The cells of one table line: split on every `|` not behind a backslash, less the empty
        piece outside a leading and a trailing one.  #>
    param([Parameter(Mandatory)] [string] $Line)
    $cells = [System.Collections.Generic.List[string]] ([regex]::Split($Line.Trim(), '(?<!\\)\|'))
    if ($cells.Count -gt 1 -and $cells[0] -notmatch '\S') { $cells.RemoveAt(0) }
    if ($cells.Count -gt 1 -and $cells[$cells.Count - 1] -notmatch '\S') { $cells.RemoveAt($cells.Count - 1) }
    , $cells.ToArray()
}

function Test-Markdown {
    <#  The findings in one Markdown file, each as @{ Line; Message }. $Exists is asked whether a
        repository-relative path, with forward slashes, is a tracked file or directory; it answers
        $null for one it cannot tell.  #>
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [AllowEmptyString()] [string[]] $Lines,
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [scriptblock] $Exists
    )

    $delimiter = '^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$'
    $paragraph = [System.Collections.Generic.List[string]]::new()
    $start = 0
    $flush = {
        if (-not $paragraph.Count) { return }
        $text = $paragraph -join "`n"
        foreach ($f in Test-Inline -Text $text) {
            @{ Line = $start + ($text.Substring(0, $f.Offset) -split "`n").Count - 1; Message = $f.Message }
        }
        $paragraph.Clear()
    }
    $fence = $null
    $numbered = $false
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i] -replace '^(\s*>)+\s?'
        if ($fence) {
            if ($line -match "^\s*$([regex]::Escape($fence))+\s*$") { $fence = $null }
            continue
        }
        if ($line -match '^\s*(`{3,}|~{3,})') { . $flush; $fence = $Matches[1]; $fenceLine = $i + 1; continue }

        # Links, on every line outside a fence. Code spans are blanked first: a path in one is no link.
        $prose = [regex]::Replace($line, '(`+)(?:(?!\1).)+?\1', '')
        $targets = @([regex]::Matches($prose, '\]\(\s*(?:<([^>]*)>|([^)\s]+))') | ForEach-Object { $_.Groups[1].Value + $_.Groups[2].Value })
        if ($prose -match '^\s{0,3}\[[^\]^][^\]]*\]:\s*<?([^\s>]+)') { $targets += $Matches[1] }
        foreach ($t in $targets) {
            if ($t -match '^([a-zA-Z][a-zA-Z0-9+.-]*:|#|//)') { continue }
            $file = [uri]::UnescapeDataString(($t -replace '[#?].*$'))
            $parts = [System.Collections.Generic.List[string]]::new()
            if (-not $file.StartsWith('/')) { $parts.AddRange([string[]] @((Split-Path $Path -Parent) -split '[\\/]' | Where-Object { $_ })) }
            $outside = $false
            foreach ($p in $file -split '/') {
                if ($p -eq '' -or $p -eq '.') { continue }
                if ($p -ne '..') { $parts.Add($p); continue }
                if ($parts.Count) { $parts.RemoveAt($parts.Count - 1) } else { $outside = $true }
            }
            $found = if ($outside) { $false } else { & $Exists ($parts -join '/') }
            if ($null -eq $found) { Write-Host "markdown-check: ${Path}:$($i + 1): $t is in a submodule that is not initialised, so it was NOT checked." }
            elseif (-not $found) { @{ Line = $i + 1; Message = "the link to $t names no tracked file or directory (case matters)" } }
        }

        if ($line -match '\|' -and $i + 1 -lt $Lines.Count -and $Lines[$i + 1] -match '\|' -and ($Lines[$i + 1] -replace '^(\s*>)+\s?') -match $delimiter) {
            . $flush
            $columns = (Split-TableRow $line).Count
            for ($r = $i; $r -lt $Lines.Count -and ($Lines[$r] -replace '^(\s*>)+\s?') -match '\S'; $r++) {
                $cells = Split-TableRow ($Lines[$r] -replace '^(\s*>)+\s?')
                if ($cells.Count -ne $columns) {
                    @{ Line = $r + 1; Message = "the table row has $($cells.Count) column(s) and its header has $columns" }
                }
                if ($r -eq $i + 1) { continue }
                foreach ($cell in $cells) { foreach ($f in Test-Inline -Text $cell) { @{ Line = $r + 1; Message = "$($f.Message), a table cell" } } }
            }
            $i = $r - 1
            continue
        }

        if ($line -notmatch '\S' -or $line -match '^\s*([-*_])(\s*\1){2,}\s*$') { . $flush; continue }
        if ($line -match '^\s{0,3}#{1,6}(\s|$)') { . $flush; $start = $i + 1; $paragraph.Add($line); . $flush; continue }
        # A number begins a list only as 1., so a wrapped line that begins "31. In" is still its
        # paragraph (a page in grado-factorio-modpack had one, 2026-10-06). Inside a numbered list
        # any number is the next item.
        if ($line -match '^\s*(?:[-*+]|(?<n>\d+)[.)])\s+(?<rest>.*)$' -and (-not $paragraph.Count -or $numbered -or $Matches['n'] -in $null, '1')) {
            . $flush; $numbered = [bool] $Matches['n']; $line = $Matches['rest']
        }
        elseif (-not $paragraph.Count) { $numbered = $false }
        if (-not $paragraph.Count) { $start = $i + 1 }
        $paragraph.Add($line)
    }
    . $flush
    if ($fence) { @{ Line = $fenceLine; Message = "the code fence opened with $fence is not closed, so nothing after it was read" } }
}

function Invoke-Check {
    <#  Check the Markdown files git names, read at $Revision ('' is the index). Prints each
        finding and returns how many.  #>
    param([string[]] $Files, [string] $Revision = '', [Parameter(Mandatory)] [string] $Top)

    $entries = if ($Revision) { git -C $Top -c core.quotepath=off ls-tree -r $Revision } else { git -C $Top -c core.quotepath=off ls-files -s }
    if ($LASTEXITCODE -ne 0) { throw "git could not list the files at '$Revision'." }
    $tracked = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $submodules = @()
    foreach ($e in $entries) {
        $mode, $name = ($e -split ' ', 2)[0], ($e -split "`t", 2)[1]
        if ($mode -eq '160000') { $submodules += $name }
        for ($p = $name; $p; $p = ($p -replace '/?[^/]*$')) { $null = $tracked.Add($p) }
    }
    $exists = {
        param($p)
        if ($p -eq '' -or $tracked.Contains($p)) { return $true }
        $sub = $submodules | Where-Object { $p.StartsWith("$_/") } | Select-Object -First 1
        if (-not $sub) { return $false }
        # Not this repository's to list, so the working tree answers; an empty one cannot.
        if (-not (Get-ChildItem -LiteralPath (Join-Path $Top $sub) -Force -ErrorAction SilentlyContinue)) { return $null }
        Test-Path -LiteralPath (Join-Path $Top $p)
    }.GetNewClosure()

    $count = 0
    foreach ($f in $Files | Where-Object { $_ -match '\.md$' }) {
        $lines = @(git -C $Top show "${Revision}:$f")
        if ($LASTEXITCODE -ne 0) { throw "git could not read ${Revision}:$f." }
        foreach ($finding in Test-Markdown -Lines $lines -Path $f -Exists $exists | Sort-Object { $_.Line }) {
            Write-Host "${f}:$($finding.Line): $($finding.Message)"
            $count++
        }
    }
    $count
}

function Invoke-SelfTest {
    $exists = { param($p) $p -cin 'docs', 'docs/there.md', 'README.md' }
    $find = { param([string] $text, [string] $path = 'docs/note.md') @(Test-Markdown -Lines ($text -split "`n") -Path $path -Exists $exists | ForEach-Object { "$($_.Line): $($_.Message)" }) }
    $clean = @'
# A title with `code_in_it` and a snake_case_name

A paragraph with *emphasis*, **strong**, _underscores_ and `a * in code`, an escaped \*star and \_under, 2 * 3 * 4,
a glob like 2.0.* and a note: *Until 2026-10-01 this said two: it missed an* Aside *line. One took
31. That wrapped line is no list item, so this closes.*

* a bullet made with a star, holding **strong** text
- [a link](there.md), [one up](../README.md#the-chain), [a directory](../docs/),
  [outside](https://example.com/a_b_c) and [a fragment](#here)

| mod | ruling |
|---|---|
| `a\|b` and a \| b, both escaped | **out** |

```
*never closed, | ragged | and [dead](nowhere.md) inside a fence
```

[label]: there.md
'@
    $run = {
        param([string] $Directory, [string[]] $Arguments)
        Push-Location $Directory
        try { $text = (& pwsh -NoProfile -File $PSCommandPath @Arguments 2>&1 | Out-String) } finally { Pop-Location }
        @{ Code = $LASTEXITCODE; Text = $text }
    }
    $temp = Join-Path ([IO.Path]::GetTempPath()) "markdown-check-selftest-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    git -C $temp init --quiet
    if ($LASTEXITCODE -ne 0) { throw 'git init failed; the self-test needs git.' }

    $cases = @(
        @{ Name = 'a clean file passes: closed emphasis, literal stars, snake_case, a fence, an escaped pipe, live links'; Test = {
            $f = @(& $find $clean)
            $f | ForEach-Object { Write-Host "    $_" }
            $f.Count -eq 0 } }
        @{ Name = 'emphasis left open at the end of its paragraph fails, on the line that opened it'; Test = {
            $f = @(& $find "fine`n`nline two`nand *this never closes`n`na new paragraph*")
            $f.Count -eq 1 -and $f[0] -match '^4: emphasis opened with \* is not closed' } }
        @{ Name = 'strong and underscore emphasis left open fail too'; Test = {
            @(& $find 'a **strong start')[0] -match '^1: emphasis opened with \*\*' -and @(& $find 'an _underscore start')[0] -match '^1: emphasis opened with _' } }
        @{ Name = 'emphasis whose closer has a space before it is left open'; Test = {
            @(& $find '*Later: see* Decisions *for more. *').Count -eq 1 } }
        @{ Name = 'a code span left open fails'; Test = {
            $f = @(& $find "a ``code span`nthat runs on`n`nnext")
            $f.Count -eq 1 -and $f[0] -match '^1: a code span opened with ` is not closed' } }
        @{ Name = 'emphasis left open in a numbered item is not closed by the next item'; Test = {
            $f = @(& $find "1. first`n2. second *open`n3. third* closes")
            $f.Count -eq 1 -and $f[0] -match '^2: emphasis opened' } }
        @{ Name = 'a fence never closed fails, on the line that opened it'; Test = {
            $f = @(& $find "text`n`n``````powershell`n*hidden")
            $f.Count -eq 1 -and $f[0] -match '^3: the code fence opened with ``` is not closed' } }
        @{ Name = 'a quoted table ended by a bare > is read, not thrown on, and a footnote is no link'; Test = {
            @(& $find "> | a | b |`n> |---|---|`n> | 1 | 2 |`n>`n> more`n`n[^1]: The note.").Count -eq 0 } }
        @{ Name = 'a table row with fewer or more columns than its header fails, naming both counts'; Test = {
            $f = @(& $find "| a | b |`n|---|---|`n| 1 | 2 |`n| 1 |`n| 1 | 2 | 3 |")
            $f.Count -eq 2 -and $f[0] -match '^4: the table row has 1 column\(s\) and its header has 2' -and $f[1] -match '^5: the table row has 3' } }
        @{ Name = 'a delimiter row that does not match its header fails'; Test = {
            @(& $find "| a | b |`n|---|`n| 1 | 2 |")[0] -match '^2: the table row has 1' } }
        @{ Name = 'a link to a file that is not tracked fails, and so does one right but for its case'; Test = {
            $f = @(& $find "see [this](gone.md) and`n[that](There.md) and [root](/docs/there.md)")
            $f.Count -eq 2 -and $f[0] -match '^1: the link to gone\.md' -and $f[1] -match '^2: the link to There\.md' } }
        @{ Name = 'a link that climbs out of the repository fails'; Test = {
            @(& $find '[sibling](../../other/README.md)').Count -eq 1 } }
        @{ Name = 'a commit''s staged content is what is read: a staged defect is refused by file and line, an unstaged one is not'; Test = {
            Set-Content -LiteralPath (Join-Path $temp 'good.md') -Value 'fine *text*'
            Set-Content -LiteralPath (Join-Path $temp 'bad.md') -Value "one`n`n[dead](nowhere.md) and *open"
            git -C $temp add good.md bad.md
            $refused = & $run $temp @()
            git -C $temp rm --cached --quiet bad.md
            Set-Content -LiteralPath (Join-Path $temp 'good.md') -Value 'now *broken on disk only'
            $passed = & $run $temp @()
            Write-Host ($refused.Text.TrimEnd() -replace '(?m)^', '    ')
            $refused.Code -eq 1 -and $refused.Text -match '(?m)^bad\.md:3: the link to nowhere\.md' -and
                $refused.Text -match '(?m)^bad\.md:3: emphasis opened' -and $passed.Code -eq 0 } }
        @{ Name = 'run from a directory below the root, each mode says what it says at the root'; Test = {
            $below = Join-Path $temp 'below'
            New-Item -ItemType Directory -Path $below | Out-Null
            Set-Content -LiteralPath (Join-Path $temp 'top.md') -Value 'fine'
            Set-Content -LiteralPath (Join-Path $below 'page.md') -Value '[up](../top.md), [beside](page.md) and [dead](nowhere.md)'
            $commit = { git -C $temp -c user.name=self-test -c user.email=self-test@example.invalid -c commit.gpgsign=false commit --quiet --allow-empty -m $args[0] 2>&1 | Out-Null }
            & $commit 'empty'
            git -C $temp add top.md below/page.md
            $same = $true
            $modes = @{ Staged = @(); Range = @('-Range', 'HEAD~1..HEAD'); All = @('-All') }
            foreach ($mode in 'Staged', 'Range', 'All') {
                if ($mode -eq 'Range') { & $commit 'pages' }
                $atRoot = & $run $temp $modes[$mode]
                $fromBelow = & $run $below $modes[$mode]
                $ok = $atRoot.Code -eq 1 -and $atRoot.Text -match '(?m)^below/page\.md:1: the link to nowhere\.md' -and
                    $atRoot.Text -match '1 finding\(s\)' -and $fromBelow.Code -eq 1 -and $fromBelow.Text -eq $atRoot.Text
                if (-not $ok) { Write-Host "    ${mode}, at the root:`n$($atRoot.Text.TrimEnd() -replace '(?m)^', '      ')`n    ${mode}, from below it:`n$($fromBelow.Text.TrimEnd() -replace '(?m)^', '      ')" }
                $same = $same -and $ok
            }
            $same } }
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

# git lists and reads from the root, so every path is the one it has there, whatever directory this
# is run in: ls-files and ls-tree would otherwise answer for the current directory only.
$top = git rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) { throw 'git found no repository here. Run it inside the repository.' }

if ($Range) {
    if ($Range -notmatch '\.\.+[^.]') { throw '-Range needs both ends, as origin/main..HEAD: the files are read at its end.' }
    $revision = $Range -replace '^.*\.\.+'
    $files = @(git -C $top -c core.quotepath=off diff --name-only --diff-filter=ACMR $Range)
}
else {
    $revision = ''
    $files = if ($All) { @(git -C $top -c core.quotepath=off ls-files) } else { @(git -C $top -c core.quotepath=off diff --cached --name-only --diff-filter=ACMR) }
}
if ($LASTEXITCODE -ne 0) { throw 'git could not list the files to check.' }
$files = @($files | Where-Object { $_ -match '\.md$' })

$found = Invoke-Check -Files $files -Revision $revision -Top $top
if ($found) {
    Write-Host ''
    Write-Host "FAILED - markdown-check: $found finding(s) in $($files.Count) Markdown file(s). What it reads as what: the header of markdown-check.ps1."
    exit 1
}
Write-Host "OK - markdown-check: $($files.Count) Markdown file(s), nothing found."
exit 0
