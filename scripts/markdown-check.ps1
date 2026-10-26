<#
.SYNOPSIS
    Checks Markdown for three things a machine can decide: emphasis or a code span left open at
    the end of its paragraph, or a `*` that can only close with nothing open to close; a table
    row whose column count differs from its header's; and a link to a file in the repository,
    or to a heading, that is not there. Handed -MaxLineLength, a fourth: a prose line longer than
    that. Exit 0 means none was found in the files read, with -All alone that there was at least
    one to read, and with -Path that each file named was read; exit 1 names each as
    <file>:<line>: <what>.

.DESCRIPTION
    A PRE-COMMIT CHECK (grado-factorio-modpack#149, where it was written). Run with no arguments,
    as a pre-commit hook does, it reads the staged Markdown files as they are staged, not as they
    are on disk. A review there on 2026-10-05 found emphasis that could not close, so the rest of
    a note rendered wrongly, and a reviewer had to find it. Run with no arguments or with -All, it
    then names each file it read whose working tree differs from the index: those edits were not
    read. That is a note, which does not change the exit code (grado-factorio-tools#138). It
    reads the repository it is run in, which need not be the one that holds it, and from any
    directory inside that repository it reads the same files and says the same. In
    grado-factorio-tools, which holds it, scripts/check.ps1 runs it with -All and a line limit.

    WITH -Path (grado-factorio-tools#191) it reads the files named as they are on disk, staged or
    not, tracked or not, so an edit can be checked before it is staged. A name is read against
    the current directory, and a finding names the file by its path from the root. A named file
    counts as there for a link, as a tracked one does, and a fragment into one is read against
    its headings on disk; every other file is answered by the index, as with no arguments. So a
    link to a file on disk that git does not track and that is not named fails, and one to a
    tracked file deleted from disk but not from the index passes. A name that git tracks in
    another case is read under git's name, so a finding names it as git does and a link in the
    typed case still fails; the case of a name git does not track is not checked. Where git's
    core.ignorecase says the file system ignores case, two spellings are one file: a file named
    twice, in one case or two, is read once, and a submodule's file is known in either case. A name
    it cannot read as this repository's Markdown fails the run before anything is read, and says
    why; so does a file inside a submodule, which is read by running the check from inside it.

    WHAT IT READS AS WHAT. A paragraph ends at a blank line, a heading, a list item, a table or a
    fenced code block; nothing inside a fence is read, and a fence never closed is reported. A
    number ends a paragraph only as `1.`; inside a numbered list any number is the next item.
    Emphasis follows CommonMark's flanking rules and its rule of 3: a `*` or `_` with whitespace
    on both sides is a literal, and so is a `_` inside a word. An opener still open when its
    paragraph ends is reported, and a lone `*` that could open is one: `*.md` in prose wants a
    code span or `\*`. A `*` that can only close, with nothing open to close, is reported too
    (grado-factorio-tools#164): it renders as text, as `reach*.` does where an inverted italic
    meant it to reopen, and `2.0.*` in prose wants a code span as well. A `_` closer with nothing
    to close is a literal, and not reported. An HTML comment and a tag, attributes and all, on
    one line, are not read for emphasis. A table is a line holding a `|` followed by a delimiter
    row holding one; every line after it up to a blank line is a row, and each cell is read as a
    paragraph of its own. A link is `[text](target)` or a `[label]: target` line, in prose or in
    any row of a table; a target with a scheme (`https:`, `mailto:`) is not checked, and the
    rest must name a file or directory git tracks, in exact case, as GitHub serves it.
    A FRAGMENT, `#name` alone or after a `.md` file, must be the anchor of a heading in that
    file, read as the file is read, in exact case (grado-factorio-tools#155). The anchor is
    the one GitHub gives, asked of it 2026-10-15 and in docs/measurements.md: the heading's
    text as it renders, lower-cased, with all but letters, marks, decimal digits, connector
    punctuation such as `_`, `-` and spaces dropped and each space made a hyphen; a repeat takes
    -1, -2 and on. A heading is a `#` line or a line alone after a blank one and underlined with
    `=` or `-`.
    A BARE ADDRESS, `https://...` with no brackets, is not read for emphasis, and ends where
    GitHub's renderer ends one, asked 2026-10-12 (grado-factorio-tools#124; the answers are in
    docs/measurements.md, with what the GitHub Flavored Markdown spec says, read the same day).
    It runs to the next whitespace or `<` and then gives back what stands last: any of
    ?!.,:;*_~'" and an entity such as `&amp;`, and a `)` that no `(` in the address opened.
    Inside square brackets it ends at the `]` that closes them, where GitHub makes no link.
    So emphasis that closes straight after an address is closed, as in
    `*see https://example.com*`, and a `*` or `_` inside one is part of it. The spec names
    fewer: not the two quotes, nor a `;` that ends no entity. The check follows the renderer.

    LINE LENGTH, ONLY WHEN HANDED A LIMIT (grado-factorio-tools#93). With no -MaxLineLength the
    check is silent on length, so a repository that never asked is not held to one. With it, a
    line longer than the limit is reported with its length, counted as written less the target
    of each `[text](target)` link and each address, `https://...` bare or `<scheme:...>` in
    angle brackets, none of which can be wrapped. What stands straight after a bare address,
    where it ends as said above, is counted. A `<placeholder>` is counted. Not held to it: a
    table row, a line in a fence, a `# heading`, a `[label]: target` line, a line of an indented
    code block, and a line with no space to break at within the limit. A space inside a code span
    is no such place, so a command in one is never wrapped. Trailing spaces are not counted. A
    limit below 1 is refused.
    WHICH LINES ARE AN INDENTED CODE BLOCK IS ASKED OF POWERSHELL'S PARSER, ConvertFrom-Markdown
    (grado-factorio-tools#95), and of nothing here: the script follows no list, blank line or
    rule to work it out. Fences, tables and headings are still read by this script, as they are
    with no limit. The parser is not GitHub's renderer, and where the two disagree the check
    follows the parser. Where they were found to, each time over an indented line, is recorded
    in docs/measurements.md (2026-10-10). Code to the parser and prose to GitHub: after a rule
    that is itself indented into a list item, and straight after a `^^^` or a `:::` line. Prose
    to the parser and code to GitHub: after a `term` line and a `:   definition` line, and on a
    first line that follows a byte-order mark.
    A page the parser gives up on, which it does on one nested too deep or holding a very large
    table, is said to be unread by it, and then no line of the page is taken for code.
    What this cannot see: a heading underlined with `===` is held to the limit as prose, and an
    address with no scheme is counted.
    OF A BARE ADDRESS, what neither rule sees: one with no scheme, as `www.example.com`, and an
    e-mail address, both of which GitHub links, are prose here. An address ends at a `>`, which
    the renderer takes in: an address in a raw tag's attribute would otherwise hide the text
    after the tag. Whether GitHub makes a link of it at all is not asked: it makes none of
    `xhttps://...`, nor of an address inside `[square brackets]`, and both are hidden here,
    so a `_` or `*` inside such an address is not read as the emphasis it may be to GitHub.

    WHAT IT CANNOT SEE. Prose: numbers, dates and quantifiers stay the reviewer's. Of a
    fragment: an anchor made by raw HTML, as `<a id="x">`, a heading inside a list item, and a
    setext heading of more than one line, so a link to any of them fails; a heading holding a
    reference link, `[text][label]`, read as written; whether GitHub follows a fragment that
    differs from an anchor only in case, which is reported and was not asked; and a fragment
    into a submodule, a directory or a file that is not `.md`, or after a `?query`, which is
    not checked. A code block made by indenting, which all but the length rule read as text.
    Emphasis that closes in the wrong place, or that a bullet nested in a numbered item leaves
    open and the next numbered item closes. Markdown outside `.md` files. A link whose target
    file or heading a commit deletes or renames, unless the linking file is staged too: -All sees
    it. A link into a submodule is asked of the working tree, so neither its case nor whether git
    tracks it is checked; into one not initialised it is said to be unchecked, and passes.

.PARAMETER Range
    Check the Markdown files changed in a commit range, as they are at its end:
    -Range origin/main...HEAD. With three dots the files are those the branch at its end has
    changed since it left the base; two dots would also list each file the base has edited or
    deleted since then. The switch is commit-check.ps1's and the form is not: that script's range
    is a list of commits, which two dots give.

.PARAMETER All
    Check every tracked Markdown file, as staged, naming those whose unstaged edits were not read.
    With none tracked it fails, having checked nothing (grado-factorio-tools#168), as in a clone
    whose checkout failed, which has an empty index. With no argument or with -Range, which
    decides the files when given with -All, no file is no failure.

.PARAMETER Path
    Check these Markdown files as they are on disk, named from the current directory and split
    on commas: -Path README.md,docs/note.md. What that reads as there is under WITH -Path above.
    Not with -All or -Range.

.PARAMETER MaxLineLength
    Also report a prose line longer than this many characters, 1 or more. Without it, length is
    not read.

.PARAMETER SelfTest
    Run the cases that hold the check to what this header says, naming each as it runs. Needs git,
    for a fixture repository in a temp directory.
    One case reads commonmark-examples.json beside this script: the examples of CommonMark
    0.31.2's Emphasis and Raw HTML sections, under CC BY-SA 4.0 (grado-factorio-tools#167). It
    runs each through the check and fails where emphasis left open, or a `*` with nothing to
    close, is reported more often than the spec's HTML shows a literal `*` or `_`: a count, not
    which mark each finding names. That proves no example holds more such findings than literal
    marks. It cannot prove a literal mark is found, nor say anything of GitHub's renderer,
    cmark-gfm, where it parts from the spec. Nor does it hold the hiding of HTML comments and
    tags: no example puts a `*` in a comment, and examples 475 to 477, which put one in a tag's
    attribute, pair it with a mark outside the tag, so reading the attribute drops a finding
    rather than adding one. Their own case holds those.

.EXAMPLE
    pwsh -File scripts/markdown-check.ps1

.EXAMPLE
    pwsh -File scripts/markdown-check.ps1 -Range origin/main...HEAD

.EXAMPLE
    pwsh -File scripts/markdown-check.ps1 -Path README.md,docs/note.md -MaxLineLength 100
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $Range,
    [switch] $All,
    [string[]] $Path,
    [int] $MaxLineLength = 0,
    [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

. "$PSScriptRoot/markdown-lib.ps1"

function Invoke-Check {
    <#  Check the Markdown files git names, read at $Revision ('' is the index); with -FromDisk,
        the files the caller names, read from disk, which count as there for a link whether git
        tracks them or not. Prints each finding and returns how many.  #>
    param([string[]] $Files, [string] $Revision = '', [Parameter(Mandatory)] [string] $Top, [int] $MaxLineLength = 0, [switch] $FromDisk)

    $entries = if ($Revision) { git -C $Top -c core.quotepath=off ls-tree -r $Revision } else { git -C $Top -c core.quotepath=off ls-files -s }
    if ($LASTEXITCODE -ne 0) { throw "git could not list the files at '$Revision'." }
    $tracked = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $submodules = @()
    # With -FromDisk the files are read as they are on disk, and count as there as if tracked.
    $onDisk = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    if ($FromDisk) { foreach ($f in $Files) { $null = $onDisk.Add($f) }; $entries = @($entries) + @($Files | ForEach-Object { "100644 0 0`t$_" }) }
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

    # One git for every file, asked for each in turn and answering with its size and then its
    # bytes. A `git show` for each file was a process for each, which on Windows took as long
    # as reading the files did once Test-Inline was quick (grado-factorio-tools#125).
    $start = [Diagnostics.ProcessStartInfo]::new('git')
    foreach ($a in '-C', $Top, 'cat-file', '--batch') { $start.ArgumentList.Add($a) }
    $start.RedirectStandardInput = $start.RedirectStandardOutput = $true
    $start.StandardInputEncoding = [Text.UTF8Encoding]::new($false)
    $git = [Diagnostics.Process]::Start($start)
    $out = $git.StandardOutput.BaseStream
    $readLines = {
        param([string] $f)
        if ($onDisk.Contains($f)) {
            $reader = [IO.StringReader]::new([Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes((Join-Path $Top $f))))
            return , @(while ($null -ne ($l = $reader.ReadLine())) { $l })
        }
        $git.StandardInput.Write("${Revision}:$f`n")
        $git.StandardInput.Flush()
        $header = [System.Collections.Generic.List[byte]]::new()
        while (($b = $out.ReadByte()) -notin 10, -1) { $header.Add($b) }
        if ([Text.Encoding]::UTF8.GetString($header.ToArray()) -notmatch ' blob (\d+)$') { throw "git could not read ${Revision}:$f." }
        $bytes = [byte[]]::new([int] $Matches[1])
        for ($read = 0; $read -lt $bytes.Length; $read += $got) {
            if (($got = $out.Read($bytes, $read, $bytes.Length - $read)) -le 0) { throw "git could not read ${Revision}:$f." }
        }
        $null = $out.ReadByte()
        # Lines as PowerShell takes them from a program's output: ended by a line feed, a
        # carriage return or both, and no empty one after the last.
        $reader = [IO.StringReader]::new([Text.Encoding]::UTF8.GetString($bytes))
        , @(while ($null -ne ($l = $reader.ReadLine())) { $l })
    }
    # A linked file's anchors, read once. A file in a submodule is not this repository's to read.
    $known = @{}
    $anchors = {
        param($p)
        if (-not $tracked.Contains($p) -or ($submodules | Where-Object { $p.StartsWith("$_/") })) { return $null }
        if (-not $known.ContainsKey($p)) { $known[$p] = Get-HeadingAnchor -Lines (& $readLines $p) }
        , $known[$p]
    }
    $count = 0
    try {
        foreach ($f in $Files | Where-Object { $_ -match '\.md$' }) {
            $lines = & $readLines $f
            foreach ($finding in Test-Markdown -Lines $lines -Path $f -Exists $exists -Anchors $anchors -MaxLineLength $MaxLineLength | Sort-Object { $_.Line }) {
                Write-Host "${f}:$($finding.Line): $($finding.Message)"
                $count++
            }
        }
    }
    finally { $git.StandardInput.Close(); $git.WaitForExit(); $git.Dispose() }
    $count
}

function Invoke-SelfTest {
    $exists = { param($p) $p -cin 'docs', 'docs/there.md', 'README.md' }
    $anchors = { param($p) if ($p -ceq 'README.md') { , (Get-HeadingAnchor -Lines '# The chain') } elseif ($p -ceq 'docs/there.md') { , (Get-HeadingAnchor -Lines '## Results', '## Results') } }
    $find = { param([string] $text, [string] $path = 'docs/note.md') @(Test-Markdown -Lines ($text -split "`n") -Path $path -Exists $exists -Anchors $anchors | ForEach-Object { "$($_.Line): $($_.Message)" }) }
    $long = { param([string] $text, [int] $max) @(Test-Markdown -Lines ($text -split "`n") -Path 'docs/note.md' -Exists $exists -Anchors $anchors -MaxLineLength $max | ForEach-Object { "$($_.Line): $($_.Message)" }) }
    $clean = @'
# A title with `code_in_it` and a snake_case_name

A paragraph with *emphasis*, **strong**, _underscores_ and `a * in code`, an escaped \*star and \_under, 2 * 3 * 4,
a glob like `2.0.*` and a note: *Until 2026-10-01 this said two: it missed an* Aside *line. One took
31. That wrapped line is no list item, so this closes.*

* a bullet made with a star, holding **strong** text
- [a link](there.md), [one up](../README.md#the-chain), [a directory](../docs/),
  [outside](https://example.com/a_b_c) and [a fragment](#a-title-with-code_in_it-and-a-snake_case_name)

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
        @{ Name = 'emphasis left open at the end of its paragraph fails, on the line that opened it, and the next paragraph''s * closes nothing'; Test = {
            $f = @(& $find "fine`n`nline two`nand *this never closes`n`na new paragraph*")
            $f.Count -eq 2 -and $f[0] -match '^4: emphasis opened with \* is not closed' -and $f[1] -match '^6: a \* that can only close' } }
        @{ Name = 'strong and underscore emphasis left open fail too'; Test = {
            @(& $find 'a **strong start')[0] -match '^1: emphasis opened with \*\*' -and @(& $find 'an _underscore start')[0] -match '^1: emphasis opened with _' } }
        @{ Name = 'emphasis whose closer has a space before it is left open'; Test = {
            @(& $find '*Later: see* Decisions *for more. *').Count -eq 1 } }
        @{ Name = 'a * that can only close, with nothing open, fails on its line: the inverted italics of grado-factorio-modpack#315, and one alone'; Test = {
            $note = @(& $find "fine`n`n*Chased again in ``docs/catalogue/Grado_ABC.md`` under* Technologies`nthe walk cannot reach*. Counted again on 2026-10-18.*")
            $alone = @(& $find 'a word* alone')
            $under = @(& $find 'a word_ alone is a literal')
            ($note + $alone + $under) | ForEach-Object { Write-Host "    $_" }
            $note.Count -ge 1 -and $note[0] -match '^4: a \* that can only close has nothing open' -and $alone.Count -eq 1 -and $alone[0] -match '^1: a \* that can only close' -and
                $under.Count -eq 0 } }
        @{ Name = 'CommonMark''s rule of 3 holds, as GitHub rendered each on 2026-10-18: a * that can open and close does not close **, so the closer after it is matched'; Test = {
            $f = @(& $find "**foo*bar baz* qux**`n`n**a*b c* d**`n`n*a**b c** d*")
            $wrong = @(& $find '***a**b c* d*')
            ($f + $wrong) | ForEach-Object { Write-Host "    $_" }
            $f.Count -eq 0 -and $wrong.Count -eq 1 -and $wrong[0] -match '^1: a \* that can only close' } }
        @{ Name = 'a * inside an HTML comment or a tag''s attribute is not read, as GitHub shows none'; Test = {
            $f = @(& $find "<!-- TODO: say why* -->`n`nA paragraph.`n<!-- see the note* -->`n`ntext <!-- note* --> more`n`n<span title=`"a*`">x</span> and <a href=`"x`" title=`"b*`">y</a>")
            $f | ForEach-Object { Write-Host "    $_" }
            $f.Count -eq 0 } }
        @{ Name = 'no example of CommonMark 0.31.2''s Emphasis and Raw HTML sections draws more emphasis findings than its HTML shows literal * and _'; Test = {
            # The spec's HTML is the oracle, one way only: a finding says a mark renders as text, so
            # the HTML must show at least as many literal marks as there are findings.
            $corpus = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'commonmark-examples.json') | ConvertFrom-Json
            $wrong = @(foreach ($e in $corpus.examples) {
                    $markdown = $e.markdown.TrimEnd("`n")
                    $found = @(Test-Markdown -Lines ($markdown -split "`n") -Path 'docs/note.md' -Exists { $true } -Anchors { $null } |
                            ForEach-Object Message | Where-Object { $_ -match '^(a \*+ that can only close|emphasis opened with)' })
                    $shown = $e.html -replace '(?s)<code>.*?</code>', '' -replace '(?s)<!--.*?-->', '' -replace '<[^>]*>', ''
                    if ($found.Count -gt [regex]::Matches($shown, '[*_]').Count) { "example $($e.example): $($markdown -replace "`n", '\n') -> $($found -join '; ')" } })
            if ($corpus.examples.Count -ne 152) { $wrong += "the file holds $($corpus.examples.Count) examples, where the two sections hold 152" }
            $wrong | ForEach-Object { Write-Host "    $_" }
            $wrong.Count -eq 0 } }
        @{ Name = 'the catalogues'' inverted italics pass, with a space before the * that reopens: a* Patch *in, as* Measured *in'; Test = {
            $f = @(& $find "*Moving it would do one member's own job, a* Patch *in*`n``GLOSSARY.md``.`n`n*That the cause is measured as* Measured *in ``GLOSSARY.md`` asks.*")
            $f | ForEach-Object { Write-Host "    $_" }
            $f.Count -eq 0 } }
        @{ Name = 'emphasis that closes straight after a bare address is closed, in a paragraph and in a table cell'; Test = {
            $lines = '*"colors from https://u.nu/factoriogfx"*', '*see https://u.nu/factoriogfx*', '_see https://u.nu/a_b_', '**see https://u.nu/x**', '*see https://u.nu/x.* and *more*'
            $alone = @(& $find ($lines -join "`n`n"))
            $cells = @(& $find ("| a |`n|---|`n" + (($lines | ForEach-Object { "| $_ |" }) -join "`n")))
            ($alone + $cells) | ForEach-Object { Write-Host "    $_" }
            $alone.Count -eq 0 -and $cells.Count -eq 0 } }
        @{ Name = 'emphasis never closed after a bare address still fails, in a cell and after a raw tag too; a mark inside an address is part of it'; Test = {
            $open = @(& $find '*see https://u.nu/x and never closed')
            $cell = @(& $find "| a |`n|---|`n| *open https://u.nu/x |")
            $tag = @(& $find 'see <a href="https://u.nu/x">*open</a> end')
            $inside = @(& $find "*see https://u.nu/a*b c*`n`n~~see https://u.nu/x~~`n`n*see <https://u.nu/x>*`n`n_see https://u.nu/a_(b)_`n`n*see https://u.nu/<id>/a*b")
            # A ] is part of the address to GitHub, so the mark before it closes nothing.
            $bracket = @(& $find "_see https://u.nu/a_]`n`n*see https://u.nu/x*]`n`n[a] *see https://u.nu/y*]")
            # Inside square brackets GitHub makes no link, and the mark before the ] closes.
            $inside += @(& $find "[*see https://u.nu/x*]`n`n[ and *see https://u.nu/x*]`n`n[*see https://u.nu/x* more]`n`n*[see https://u.nu/x]*`n`n[*see https://u.nu/x*](there.md)")
            $open.Count -eq 1 -and $open[0] -match '^1: emphasis opened with \*' -and $cell.Count -eq 1 -and $tag.Count -eq 1 -and $inside.Count -eq 0 -and $bracket.Count -eq 3 } }
        @{ Name = 'a bare address ends where GitHub ends one: before trailing punctuation, an entity and a ) nothing opened, and at a <; and at a >, where GitHub does not'; Test = {
            # Each: what follows https://u.nu/ up to the next space, and how much of that is the
            # address.
            $ends = [ordered]@{ 'x".' = 'x'; 'x."' = 'x'; 'x?!.,:;*_~' = 'x'; "x'" = 'x'; 'x?q=1.' = 'x?q=1'; 'a"b' = 'a"b'; 'a*b' = 'a*b'; 'a_b_' = 'a_b'
                'x)' = 'x'; 'x))' = 'x'; 'a(b)' = 'a(b)'; 'a(b))' = 'a(b)'; 'a(b' = 'a(b'; 'a)b' = 'a)b'; 'x]' = 'x]'; 'x].' = 'x]'; 'x[1]' = 'x[1]'; 'a]b' = 'a]b'
                'x&amp;' = 'x'; 'x&amp' = 'x&amp'; 'x&frac12;' = 'x&frac12'; 'x}' = 'x}'; 'x/' = 'x/'; 'x<b' = 'x'; 'x>y' = 'x' }
            $wrong = @(foreach ($e in $ends.GetEnumerator()) {
                    $text = "see https://u.nu/$($e.Key) end"
                    $got = @(Get-BareAddress -Text $text | ForEach-Object { $text.Substring($_.Index, $_.Length) }) -join ' and '
                    if ($got -cne "https://u.nu/$($e.Value)") { "$($e.Key) gave $got" } })
            $wrong | ForEach-Object { Write-Host "    $_" }
            $upper = 'HTTPS://U.NU/x. and ftp://u.nu/y'
            $wrong.Count -eq 0 -and @(Get-BareAddress -Text $upper).Count -eq 1 -and @(Get-BareAddress -Text $upper)[0].Length -eq 14 -and @(Get-BareAddress -Text 'no address').Count -eq 0 } }
        @{ Name = 'a code span left open fails'; Test = {
            $f = @(& $find "a ``code span`nthat runs on`n`nnext")
            $f.Count -eq 1 -and $f[0] -match '^1: a code span opened with ` is not closed' } }
        @{ Name = 'emphasis left open in a numbered item is not closed by the next item, whose * has nothing to close'; Test = {
            $f = @(& $find "1. first`n2. second *open`n3. third* closes")
            $f.Count -eq 2 -and $f[0] -match '^2: emphasis opened' -and $f[1] -match '^3: a \* that can only close' } }
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
        @{ Name = 'a link to a file that is not tracked fails in a table row too, below the header'; Test = {
            $f = @(& $find "| a |`n|---|`n| [this](gone.md) |")
            $f.Count -eq 1 -and $f[0] -match '^3: the link to gone\.md' } }
        @{ Name = 'a #fragment that names no heading of its file fails, in prose and in a table row, and one that names a later heading passes'; Test = {
            $f = @(& $find "[up](#later) and [x](#no-such-heading)`n`n| a |`n|---|`n| [y](#no-such-heading) |`n`n## Later")
            $f | ForEach-Object { Write-Host "    $_" }
            $f.Count -eq 2 -and $f[0] -match '^1: the link to #no-such-heading names no heading of this file' -and $f[1] -match '^5: the link to #no-such-heading' } }
        @{ Name = 'a path.md#fragment fails when that file has no such heading, and passes on its first and its repeated heading'; Test = {
            $f = @(& $find "[a](there.md#results), [b](there.md#results-1), [c](../README.md#the-chain)`n[d](there.md#results-2) and [e](../README.md#the-chain-1)")
            $f | ForEach-Object { Write-Host "    $_" }
            $f.Count -eq 2 -and $f[0] -match '^2: the link to there\.md#results-2 names no heading of docs/there\.md' -and $f[1] -match '^2: the link to \.\./README\.md#the-chain-1 names no heading of README\.md' } }
        @{ Name = 'a fragment into a file the anchors cannot be read of, or on a link to a directory, is not checked'; Test = {
            @(& $find '[a](../docs/#anything) and [b](there.md#) and [c](#)').Count -eq 0 } }
        @{ Name = 'anchors are what GitHub gave each heading, asked 2026-10-15: backticks, punctuation, non-ASCII, emphasis, escapes, entities, repeats'; Test = {
            # Each heading and the anchor GitHub gave it, in order (docs/measurements.md).
            $asked = [ordered]@{
                '# Results' = 'results'; '# Results ' = 'results-1'; '# Results-1' = 'results-1-1'; '# Results  ' = 'results-2'
                '## A `code_span` heading, with punctuation: (yes!) & "quotes"?' = 'a-code_span-heading-with-punctuation-yes--quotes'
                "## Temperature 150 $([char] 0xB0)C $([char] 0xD7) 2" = 'temperature-150-c--2'
                '## _Underscore emphasis_ and snake_case_name' = 'underscore-emphasis-and-snake_case_name'
                '## *Star emphasis* and **strong**' = 'star-emphasis-and-strong'; '## __Strong underscores__ done' = 'strong-underscores-done'
                '## Escaped \_under\_ and \*star\*' = 'escaped-_under_-and-star'; '## A [link](https://example.com) in it' = 'a-link-in-it'
                '## Closing hashes ##' = 'closing-hashes'; "## $([char] 0xC6)ble $([char] 0xD6) CAPS" = "$([char] 0xE6)ble-$([char] 0xF6)-caps"
                "## Dots.and/slashes$([char] 0x2014)dash $([char] 0x2013) en" = 'dotsandslashesdash--en'
                '## <span id="custom">Raw html</span> heading' = 'raw-html-heading'; '## Emoji :tada: here' = 'emoji-tada-here'
                "## 10$([char] 0xB2) superscript" = '10-superscript'; "## Tab`tinside" = 'tabinside'; '## Multiple   spaces' = 'multiple---spaces'
                '## _open underscore' = '_open-underscore'; '## a _ b' = 'a-_-b'; '## `__init__` and `a*b`' = '__init__-and-ab'
                '## ![alt text](x.png) image' = '-image'; '## Hyphens - and -- double' = 'hyphens---and----double'
                '## 1. Numbered-looking heading' = '1-numbered-looking-heading'; '## Trailing space   ' = 'trailing-space'
                '## <code>tag</code> heading' = 'tag-heading'; "## Caf$([char] 0xE9)" = "caf$([char] 0xE9)"; '## &amp; entity &copy;' = '-entity-'; '## foo_ trailing' = 'foo_-trailing'
                '## *emphasis_with_under*' = 'emphasis_with_under'; "## $([char]::ConvertFromUtf32(0x1F4A5)) Emoji literal" = '-emoji-literal'
                '> ## Quoted heading' = 'quoted-heading'; '   ## Indented three' = 'indented-three'
            }
            $lines = @(foreach ($h in $asked.Keys) { $h; '' }) + 'Setext one', '==========', '', 'Setext two', '----------'
            $got = Get-HeadingAnchor -Lines $lines
            $want = @($asked.Values) + 'setext-one', 'setext-two'
            $wrong = @($want | Where-Object { -not $got.Contains($_) }) + @($got | Where-Object { $_ -cnotin $want })
            $wrong | ForEach-Object { Write-Host "    not as GitHub gave it: $_" }
            $wrong.Count -eq 0 } }
        @{ Name = 'a heading in a fence, in front matter or indented as code makes no anchor; one after an opening rule does'; Test = {
            $got = Get-HeadingAnchor -Lines '---', 'title: x', '# a yaml comment', '---', '', '```', '# Fenced', '```', '', '    # Code', '', 'text', '', '# Real'
            $rule = Get-HeadingAnchor -Lines '---', '', '# Kept', '', '---'
            $got.Count -eq 1 -and $got.Contains('real') -and $rule.Contains('kept') } }
        @{ Name = 'a < that opens no tag is text in a heading, and an autolink keeps its address'; Test = {
            $got = Get-HeadingAnchor -Lines '## A <-> B', '', '## See <https://example.com>', '', '## <b>Bold</b> <br/> end'
            @($got) -join ' ' -ceq 'a---b see-httpsexamplecom bold--end' } }
        @{ Name = 'a [label]: line is read for its target and its fragment, and a ?query link''s fragment is not checked'; Test = {
            $f = @(& $find "[a]: gone.md`n[b]: #no-heading`n[c]: there.md?plain=1#L3")
            $f.Count -eq 2 -and $f[0] -match '^1: the link to gone\.md' -and $f[1] -match '^2: the link to #no-heading' } }
        @{ Name = 'a run refuses a dangling #fragment and a dangling other.md#fragment, and passes once each names a heading'; Test = {
            $own = Join-Path $temp 'fragments'
            New-Item -ItemType Directory -Path $own | Out-Null
            git -C $own init --quiet
            Set-Content -LiteralPath (Join-Path $own 'other.md') -Value "# Other`n`n## Its `code` part"
            Set-Content -LiteralPath (Join-Path $own 'page.md') -Value "# Page`n`n[x](#no-such-heading) and [y](other.md#no-such-heading)"
            git -C $own add other.md page.md
            $refused = & $run $own @()
            Set-Content -LiteralPath (Join-Path $own 'page.md') -Value "# Page`n`n[x](#page) and [y](other.md#its-code-part)"
            git -C $own add page.md
            $passed = & $run $own @('-All')
            Write-Host ($refused.Text.TrimEnd() -replace '(?m)^', '    ')
            $refused.Code -eq 1 -and $refused.Text -match '(?m)^page\.md:3: the link to #no-such-heading names no heading of this file' -and
                $refused.Text -match '(?m)^page\.md:3: the link to other\.md#no-such-heading names no heading of other\.md' -and $passed.Code -eq 0 } }
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
            $commit = { git -C $temp -c user.name=self-test -c user.email=self-test@example.invalid -c commit.gpgsign=false commit --quiet --allow-empty -m $args[0] 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "git could not commit '$($args[0])' in the fixture repository." } }
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
        @{ Name = 'handed a limit, a prose line over it fails with its length and the limit, and one at the limit passes'; Test = {
            $f = @(& $long "short`n$('word ' * 8)end`n$('word ' * 7)12345" 40)
            $f.Count -eq 1 -and $f[0] -match '^2: the line is 43 characters, over the limit of 40' } }
        @{ Name = 'a table row, a fenced line, a heading and a line with no space to break at outside a code span are not held to the limit'; Test = {
            $wide = 'word ' * 12
            @(& $long "| $wide | b |`n|---|---|`n| 1 | 2 |`n`n``````text`n$wide`n```````n`n## $wide`n`n- $('x' * 60)`n`n$('x' * 60) and more`n`n``$('gh pr ' * 10)`` and more" 40).Count -eq 0 } }
        @{ Name = 'a line indented four spaces after a blank one is code and not held to the limit, unless it continues a list item'; Test = {
            $wide = 'word ' * 12
            $f = @(& $long "text`n`n    $wide`n    $wide`n`ntext`n`n- item`n`n    $wide" 40)
            $f.Count -eq 1 -and $f[0] -match '^10: the line is 63 characters' } }
        @{ Name = 'a table or a rule ends a list, so a code block after it is not held to the limit; a lazy line does not, so the item''s next paragraph is'; Test = {
            $wide = 'word ' * 12
            $afterTable = @(& $long "- item`n`n| a | b |`n|---|---|`n`n    $wide" 40)
            $afterRule = @(& $long "- item`n`n* * *`n`n    $wide" 40)
            $lazy = @(& $long "- item`nlazy line`n`n    $wide" 40)
            # After a fence closes there is no paragraph left to continue, so the line ends the
            # list.
            $afterFence = @(& $long "- item`n`n  ``````text`n  code`n  ```````nunindented`n`n    $wide" 40)
            $afterTable.Count -eq 0 -and $afterRule.Count -eq 0 -and $afterFence.Count -eq 0 -and $lazy.Count -eq 1 -and $lazy[0] -match '^4: the line is 63 characters' } }
        @{ Name = 'what the parser calls a code block is not held to the limit: indented by a tab, inside a quote, inside a numbered item; an indented line with no blank line before it is its paragraph, and is'; Test = {
            $wide = 'word ' * 12
            $tab = @(& $long "text`n`n`t$wide" 40)
            $quoted = @(& $long "> text`n>`n>     $wide" 40)
            $inItem = @(& $long "1. item`n`n       $wide`n`n       $wide" 40)
            $noBlank = @(& $long "text`n    $wide" 40)
            # The line straight after a block is prose again: the block must not run one line long.
            $after = @(& $long "text`n`n    $wide`n$wide" 40)
            $tab.Count -eq 0 -and $quoted.Count -eq 0 -and $inItem.Count -eq 0 -and @(& $long '' 40).Count -eq 0 -and
                $noBlank.Count -eq 1 -and $noBlank[0] -match '^2: the line is 63 characters' -and
                $after.Count -eq 1 -and $after[0] -match '^4: the line is 59 characters' } }
        @{ Name = 'a page the parser gives up on is still held to the limit, with no line of it taken for code'; Test = {
            $wide = 'word ' * 12
            # 90 levels is past the parser's depth limit in pwsh 7.6.6. A PowerShell with a higher
            # limit would read this page, take line 94 for code, and fail this case, not the check.
            $deep = (0..89 | ForEach-Object { ('  ' * $_) + '- x' }) -join "`n"
            $f = @(& $long "$deep`n`ntext`n`n    $wide" 40)
            $f.Count -eq 1 -and $f[0] -match '^94: the line is 63 characters' } }
        @{ Name = 'a heading underlined with === is held to the limit as prose'; Test = {
            @(& $long "$('word ' * 12)`n===" 40).Count -eq 1 } }
        @{ Name = 'a <placeholder> is counted, where an <https:> address is not'; Test = {
            $f = @(& $long "$('word ' * 7)<owner>/<repo>`n`n$('word ' * 7)<https://example.com/a>" 40)
            $f.Count -eq 1 -and $f[0] -match '^1: the line is 49 characters' } }
        @{ Name = 'a limit of 0 or less is refused, not taken as no limit'; Test = {
            $zero = & $run $temp @('-MaxLineLength', '0')
            $zero.Code -eq 1 -and $zero.Text -match '-MaxLineLength must be 1 or more' } }
        @{ Name = 'a link target, a bare address and a [label]: line are not counted, and the text around them is'; Test = {
            $target = 'there.md?' + ('a' * 60)
            $passes = @(& $long "see [this]($target) and https://example.com/$('b' * 60) too`n`n[label]: $target" 40)
            $fails = @(& $long "$('word ' * 8)[this]($target)" 40)
            $passes.Count -eq 0 -and $fails.Count -eq 1 -and $fails[0] -match '^1: the line is 46 characters' } }
        @{ Name = 'what stands straight after a bare address is counted, and the address is not'; Test = {
            # 35 characters, then three before the address and four after it.
            $after = @(& $long "$('word ' * 7)(*`"https://example.com/$('b' * 60)`"*)." 40)
            $alone = @(& $long "$('word ' * 7)https://example.com/$('b' * 60) end" 40)
            $after.Count -eq 1 -and $after[0] -match '^1: the line is 42 characters' -and $alone.Count -eq 0 } }
        @{ Name = 'handed no limit, a long line is not reported, by the function or by a run'; Test = {
            Set-Content -LiteralPath (Join-Path $temp 'long.md') -Value ('word ' * 30)
            git -C $temp add long.md
            $silent = & $run $temp @()
            $held = & $run $temp @('-MaxLineLength', '100')
            Write-Host ($held.Text.TrimEnd() -replace '(?m)^', '    ')
            @(& $find ('word ' * 30)).Count -eq 0 -and $silent.Code -eq 0 -and $silent.Text -notmatch 'characters' -and
                $held.Code -eq 1 -and $held.Text -match '(?m)^long\.md:1: the line is 149 characters, over the limit of 100' } }
        @{ Name = 'a file is read as git holds it: a name outside ASCII, a byte-order mark, CRLF line ends and no last one, and beside it an empty file'; Test = {
            $name = "sm$([char] 0xF8)r br$([char] 0xF8)d.md"
            [IO.File]::WriteAllBytes((Join-Path $temp $name), [byte[]] (0xEF, 0xBB, 0xBF) + [Text.Encoding]::UTF8.GetBytes("one`r`n`r`nand *open"))
            [IO.File]::WriteAllBytes((Join-Path $temp 'empty.md'), [byte[]] @())
            git -C $temp add -- $name empty.md
            $read = & $run $temp @()
            Write-Host ($read.Text.TrimEnd() -replace '(?m)^', '    ')
            $read.Code -eq 1 -and $read.Text -match "(?m)^$([regex]::Escape($name)):3: emphasis opened" -and $read.Text -match '1 finding\(s\) in' } }
        @{ Name = 'a line over the limit left unstaged is named as not read, by -All and with no argument, and the exit code does not change'; Test = {
            # A repository of its own, so that the run before the edit passes and an exit code
            # the note changed would show.
            $own = Join-Path $temp 'own'
            New-Item -ItemType Directory -Path $own | Out-Null
            git -C $own init --quiet
            Set-Content -LiteralPath (Join-Path $own 'unread.md') -Value 'short'
            git -C $own add unread.md
            $ok = $true
            foreach ($mode in @(), @('-All')) {
                Set-Content -LiteralPath (Join-Path $own 'unread.md') -Value 'short'
                $before = & $run $own ($mode + '-MaxLineLength', '100')
                Set-Content -LiteralPath (Join-Path $own 'unread.md') -Value ('x' * 150)
                $after = & $run $own ($mode + '-MaxLineLength', '100')
                Write-Host ($after.Text.TrimEnd() -replace '(?m)^', '    ')
                $ok = $ok -and $before.Code -eq 0 -and $before.Text -notmatch 'unstaged' -and $after.Code -eq 0 -and
                    $after.Text -match '1 file\(s\) have unstaged edits that were not read' -and $after.Text -match '(?m)^ +unread\.md\r?$'
            }
            $ok } }
        @{ Name = '-All with no tracked Markdown file fails; nothing staged, a range that changes none, and -All with that range pass'; Test = {
            $none = Join-Path $temp 'none'
            New-Item -ItemType Directory -Path $none | Out-Null
            git -C $none init --quiet
            $all = & $run $none @('-All')
            $staged = & $run $none @()
            foreach ($m in 'one', 'two') {
                git -C $none -c user.name=self-test -c user.email=self-test@example.invalid -c commit.gpgsign=false commit --quiet --allow-empty -m $m 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "git could not commit '$m' in the fixture repository." }
            }
            $range = & $run $none @('-Range', 'HEAD~1..HEAD')
            # -Range decides the files when both are given, so -All adds no refusal to it.
            $both = & $run $none @('-All', '-Range', 'HEAD~1..HEAD')
            ($all, $staged, $range, $both) | ForEach-Object { Write-Host ($_.Text.TrimEnd() -replace '(?m)^', '    ') }
            $all.Code -eq 1 -and $all.Text -match '(?m)^FAILED - markdown-check: -All found no Markdown file' -and
                @($staged, $range, $both | Where-Object { $_.Code -eq 0 -and $_.Text -match '(?m)^OK - markdown-check: 0 Markdown file' }).Count -eq 3 } }
        @{ Name = '-Path reads named files from disk, staged or not, tracked or not: a comma list names each, a named file counts as there, its anchors are its own on disk'; Test = {
            $own = Join-Path $temp 'paths'
            New-Item -ItemType Directory -Path (Join-Path $own 'sub') -Force | Out-Null
            git -C $own init --quiet
            Set-Content -LiteralPath (Join-Path $own 'other.md') -Value '# Staged'
            Set-Content -LiteralPath (Join-Path $own 'page.md') -Value 'fine'
            git -C $own add other.md page.md
            Set-Content -LiteralPath (Join-Path $own 'other.md') -Value '# Disk'
            Set-Content -LiteralPath (Join-Path $own 'page.md') -Value "# Page`n`n[a](other.md#disk), [b](new.md) and [c](stray.md)`n`nand *open"
            Set-Content -LiteralPath (Join-Path $own 'new.md') -Value '# New'
            Set-Content -LiteralPath (Join-Path $own 'stray.md') -Value '# Stray'
            Set-Content -LiteralPath (Join-Path $own 'sub/deep.md') -Value '[up](../page.md) and *open'
            $all3 = & $run $own @('-Path', 'page.md,other.md,new.md')
            $one = & $run $own @('-Path', 'page.md')
            $atRoot = & $run $own @('-Path', 'sub/deep.md')
            $fromBelow = & $run (Join-Path $own 'sub') @('-Path', 'deep.md')
            ($all3, $one, $fromBelow) | ForEach-Object { Write-Host ($_.Text.TrimEnd() -replace '(?m)^', '    ') }
            $all3.Code -eq 1 -and $all3.Text -match '(?m)^page\.md:3: the link to stray\.md names no tracked file' -and
                $all3.Text -match '(?m)^page\.md:5: emphasis opened' -and $all3.Text -notmatch 'other\.md#disk|new\.md names|unstaged' -and
                $all3.Text -match '2 finding\(s\) in 3 Markdown file' -and
                $one.Code -eq 1 -and $one.Text -match 'the link to other\.md#disk names no heading of other\.md' -and $one.Text -match 'the link to new\.md names no tracked file' -and
                $atRoot.Code -eq 1 -and $atRoot.Text -match '(?m)^sub/deep\.md:1: emphasis opened' -and $fromBelow.Text -eq $atRoot.Text } }
        @{ Name = '-Path refuses -All and -Range beside it, a file that is not .md, one that is missing, one outside the repository and a list that names no file, reading nothing'; Test = {
            $own = Join-Path $temp 'refusals'
            New-Item -ItemType Directory -Path $own | Out-Null
            git -C $own init --quiet
            Set-Content -LiteralPath (Join-Path $own 'page.md') -Value 'and *open'
            Set-Content -LiteralPath (Join-Path $own 'notes.txt') -Value 'text'
            Set-Content -LiteralPath (Join-Path $temp 'outside.md') -Value 'text'
            $said = @(
                @{ Run = & $run $own @('-Path', 'page.md', '-All'); Want = 'cannot be combined' }
                @{ Run = & $run $own @('-Path', 'page.md', '-Range', 'HEAD~1..HEAD'); Want = 'cannot be combined' }
                @{ Run = & $run $own @('-Path', 'page.md,notes.txt'); Want = 'notes\.txt is not a Markdown file' }
                @{ Run = & $run $own @('-Path', 'page.md,missing.md'); Want = 'missing\.md is no file' }
                @{ Run = & $run $own @('-Path', 'page.md,../outside.md'); Want = '\.\./outside\.md is outside the repository' }
                @{ Run = & $run $own @('-Path', ','); Want = '-Path named no file' }
                @{ Run = & $run $own @('-Path', ',', '-All'); Want = 'cannot be combined' }
            )
            $ok = $true
            foreach ($s in $said) {
                $held = $s.Run.Code -ne 0 -and $s.Run.Text -match $s.Want -and $s.Run.Text -notmatch '(?m)^page\.md:'
                if (-not $held) { Write-Host ($s.Run.Text.TrimEnd() -replace '(?m)^', '    ') }
                $ok = $ok -and $held
            }
            $ok } }
        @{ Name = '-Path takes a tracked file in git''s case, so a link in another case still fails and a finding names the file as git holds it (#193)'; Test = {
            $own = Join-Path $temp 'case'
            New-Item -ItemType Directory -Path $own | Out-Null
            git -C $own init --quiet
            Set-Content -LiteralPath (Join-Path $own 'README.md') -Value "# Readme`n`nand *open"
            git -C $own add README.md
            Set-Content -LiteralPath (Join-Path $own 'linker.md') -Value '[x](readme.md)'
            $pair = & $run $own @('-Path', 'readme.md,linker.md')
            $alone = & $run $own @('-Path', 'readme.md')
            ($pair, $alone) | ForEach-Object { Write-Host ($_.Text.TrimEnd() -replace '(?m)^', '    ') }
            # Where the file system holds case, readme.md is no file, and that refusal is the run.
            if (-not (Test-Path -LiteralPath (Join-Path $own 'readme.md'))) { return $alone.Code -eq 1 -and $alone.Text -match 'readme\.md is no file' }
            $pair.Code -eq 1 -and $pair.Text -match '(?m)^linker\.md:1: the link to readme\.md names no tracked file' -and
                $alone.Code -eq 1 -and $alone.Text -cmatch '(?m)^README\.md:3: emphasis opened' -and $alone.Text -cnotmatch '(?m)^readme\.md:' } }
        @{ Name = '-Path refuses a file inside a submodule, in any case the file system takes, naming the submodule and reading nothing (#193)'; Test = {
            $own = Join-Path $temp 'insub'
            New-Item -ItemType Directory -Path (Join-Path $own 'sub') -Force | Out-Null
            git -C $own init --quiet
            git -C $own update-index --add --cacheinfo "160000,$('1' * 40),sub"
            Set-Content -LiteralPath (Join-Path $own 'sub/doc.md') -Value 'and *open'
            Set-Content -LiteralPath (Join-Path $own 'top.md') -Value 'and *open'
            $r = & $run $own @('-Path', 'sub/doc.md,top.md')
            # In another case: refused as inside sub where the file system ignores case (PR #197's
            # review, B1), and as no file where it holds case.
            $upper = & $run $own @('-Path', 'SUB/doc.md')
            ($r, $upper) | ForEach-Object { Write-Host ($_.Text.TrimEnd() -replace '(?m)^', '    ') }
            $want = if (Test-Path -LiteralPath (Join-Path $own 'SUB/doc.md')) { 'SUB/doc\.md is inside the submodule sub' } else { 'SUB/doc\.md is no file' }
            $r.Code -eq 1 -and $r.Text -match 'sub/doc\.md is inside the submodule sub' -and $r.Text -notmatch '(?m)^(sub/doc|top)\.md:' -and
                $upper.Code -eq 1 -and $upper.Text -match $want -and $upper.Text -notmatch '(?m)^SUB/doc\.md:' } }
        @{ Name = '-Path reads a file named twice once, in the same spelling or another, tracked or not (#193)'; Test = {
            $own = Join-Path $temp 'twice'
            New-Item -ItemType Directory -Path $own | Out-Null
            git -C $own init --quiet
            Set-Content -LiteralPath (Join-Path $own 'a.md') -Value 'and *open'
            $same = & $run $own @('-Path', 'a.md,a.md')
            $other = & $run $own @('-Path', 'a.md,./a.md')
            # Untracked, in two cases: one file where the file system ignores case (PR #197's
            # review, B2), and A.md no file where it holds case.
            $cased = & $run $own @('-Path', 'a.md,A.md')
            ($same, $other, $cased) | ForEach-Object { Write-Host ($_.Text.TrimEnd() -replace '(?m)^', '    ') }
            $folded = if (Test-Path -LiteralPath (Join-Path $own 'A.md')) { $cased.Code -eq 1 -and @([regex]::Matches($cased.Text, '(?mi)^a\.md:1:')).Count -eq 1 -and $cased.Text -match '1 finding\(s\) in 1 Markdown file' }
                else { $cased.Code -eq 1 -and $cased.Text -match 'A\.md is no file' }
            $folded -and @($same, $other | Where-Object { $_.Code -eq 1 -and @([regex]::Matches($_.Text, '(?m)^a\.md:1:')).Count -eq 1 -and $_.Text -match '1 finding\(s\) in 1 Markdown file' }).Count -eq 2 } }
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
# Under pwsh -File a comma list arrives as one string. -Path given is the mode, even when it names
# nothing, so an empty list fails rather than falling back to the staged files.
$named = $PSBoundParameters.ContainsKey('Path')
$Path = @($Path -split ',' | Where-Object { $_ })
# A limit that came out as 0 must not pass for a limit that was never asked for.
if ($PSBoundParameters.ContainsKey('MaxLineLength') -and $MaxLineLength -lt 1) { throw '-MaxLineLength must be 1 or more. Leave it out for no limit.' }

# git lists and reads from the root, so every path is the one it has there, whatever directory this
# is run in: ls-files and ls-tree would otherwise answer for the current directory only.
$top = git rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) { throw 'git found no repository here. Run it inside the repository.' }

if ($named) {
    if ($All -or $Range) { throw '-Path cannot be combined with -All or -Range: it names the files itself.' }
    if (-not $Path) { Write-Host 'FAILED - markdown-check: -Path named no file, so nothing was checked.'; exit 1 }
    # A name is read against this directory, and reported by its path from the root.
    $revision = ''
    $refused = @()
    # A tracked file is taken in git's case, as GitHub serves it, where the file system let another
    # case through; an untracked one keeps the case it was typed in.
    $index = @(git -C $top -c core.quotepath=off ls-files -s)
    if ($LASTEXITCODE -ne 0) { throw 'git could not list the files it tracks.' }
    $inGit = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)
    $exact = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $gitlinks = @()
    foreach ($e in $index) {
        $name = ($e -split "`t", 2)[1]
        if ($e -match '^160000 ') { $gitlinks += $name }
        $null = $exact.Add($name)
        if (-not $inGit.ContainsKey($name)) { $inGit[$name] = $name }
    }
    # Where the file system ignores case, as git found when it made the repository, two spellings
    # are one file: a submodule's in another case is still in it, and a name is read once.
    $foldCase = (git -C $top config --bool --default false core.ignorecase) -eq 'true'
    $compare = if ($foldCase) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::FromComparison($compare))
    $files = @(foreach ($p in $Path) {
        $relative = [IO.Path]::GetRelativePath($top, [IO.Path]::GetFullPath($p, $PWD.ProviderPath)) -replace '\\', '/'
        $sub = $gitlinks | Where-Object { $relative.StartsWith("$_/", $compare) } | Select-Object -First 1
        if ($relative -match '^\.\.(/|$)' -or [IO.Path]::IsPathRooted($relative)) { $refused += "$p is outside the repository" }
        elseif ($p -notmatch '\.md$') { $refused += "$p is not a Markdown file" }
        elseif ($sub) { $refused += "$p is inside the submodule $sub, which is not this repository's to read: run the check from inside $sub" }
        elseif (-not (Test-Path -LiteralPath $p -PathType Leaf)) { $refused += "$p is no file" }
        else {
            if (-not $exact.Contains($relative) -and $inGit.ContainsKey($relative)) { $relative = $inGit[$relative] }
            if ($seen.Add($relative)) { $relative }
        }
    })
    if ($refused) {
        $refused | ForEach-Object { Write-Host "markdown-check: $_." }
        Write-Host 'FAILED - markdown-check: -Path named a file it cannot read as Markdown, so nothing was checked.'
        exit 1
    }
}
elseif ($Range) {
    if ($Range -notmatch '\.\.+[^.]') { throw '-Range needs both ends, as origin/main...HEAD: the files are read at its end.' }
    $revision = $Range -replace '^.*\.\.+'
    $files = @(git -C $top -c core.quotepath=off diff --name-only --diff-filter=ACMR $Range)
}
else {
    $revision = ''
    $files = if ($All) { @(git -C $top -c core.quotepath=off ls-files) } else { @(git -C $top -c core.quotepath=off diff --cached --name-only --diff-filter=ACMR) }
}
if ($LASTEXITCODE -ne 0) { throw 'git could not list the files to check.' }
$files = @($files | Where-Object { $_ -match '\.md$' })
# -All asks for every Markdown file, so none at all means nothing was checked.
if ($All -and -not $Range -and -not $files) {
    Write-Host 'FAILED - markdown-check: -All found no Markdown file that git tracks here, so nothing was checked. A clone whose checkout failed has an empty index.'
    exit 1
}

$found = Invoke-Check -Files $files -Revision $revision -Top $top -MaxLineLength $MaxLineLength -FromDisk:$named
# What was read is the index; a file whose working tree differs passed or failed on what is staged.
if (-not $Range -and -not $named) {
    # safecrlf off: under autocrlf git would otherwise warn of each LF file it compares.
    $unread = @(git -C $top -c core.quotepath=off -c core.safecrlf=false diff --name-only -- '*.md' | Where-Object { $_ -cin $files })
    if ($LASTEXITCODE -ne 0) { throw 'git could not list the files with unstaged edits.' }
    if ($unread) {
        Write-Host "markdown-check: $($unread.Count) file(s) have unstaged edits that were not read; what was read is what is staged:"
        $unread | ForEach-Object { Write-Host "    $_" }
    }
}
if ($found) {
    Write-Host ''
    Write-Host "FAILED - markdown-check: $found finding(s) in $($files.Count) Markdown file(s). What it reads as what: the header of markdown-check.ps1."
    exit 1
}
Write-Host "OK - markdown-check: $($files.Count) Markdown file(s), nothing found."
exit 0
