<#
.SYNOPSIS
    Checks Markdown for three things a machine can decide: emphasis or a code span left open at
    the end of its paragraph, or a `*` with nothing to close; a table row whose column count
    differs from its header's; and a link to a file in the repository, or to a heading, that is
    not there. Handed -MaxLineLength,
    a fourth: a prose line longer than that. Exit 0 means none was found in the files read;
    exit 1 names each as <file>:<line>: <what>.

.DESCRIPTION
    A PRE-COMMIT CHECK (grado-factorio-modpack#149, where it was written). Run with no arguments,
    as a pre-commit hook does, it reads the staged Markdown files as they are staged, not as they
    are on disk. A review there on 2026-10-05 found emphasis that could not close, so the rest of
    a note rendered wrongly, and a reviewer had to find it. Run with no arguments or with -All, it
    then names each file it read whose working tree differs from the index: those edits were not
    read. That is a note, which does not change the exit code (grado-factorio-tools#138). It reads the repository it is run in,
    which need not be the one that holds it, and from any directory inside that repository it
    reads the same files and says the same. In grado-factorio-tools, which holds it,
    scripts/check.ps1 runs it with -All and a line limit.

    WHAT IT READS AS WHAT. A paragraph ends at a blank line, a heading, a list item, a table or a
    fenced code block; nothing inside a fence is read, and a fence never closed is reported. A
    number ends a paragraph only as `1.`; inside a numbered list any number is the next item.
    Emphasis follows CommonMark's flanking rules: a `*` or `_` with whitespace on both sides is a
    literal, and so is a `_` inside a word. An opener still open when its paragraph ends is
    reported, and a lone `*` that could open is one: `*.md` in prose wants a code span or `\*`.
    So is a `*` that can only close, with nothing open to close (grado-factorio-tools#164): it
    renders as text, as `reach*.` does where an inverted italic meant it to reopen, and `2.0.*`
    in prose wants a code span too. A `_` closer with nothing to close is a literal, not reported. A table is a line holding a `|` followed by a delimiter
    row holding one; every line after it up to a blank line is a row, and each cell is read as a
    paragraph of its own. A link is `[text](target)` or a `[label]: target` line, in prose or in
    any row of a table; a target with a scheme (`https:`, `mailto:`) is not checked, and the
    rest must name a file or directory git tracks, in exact case, as GitHub serves it.
    A FRAGMENT, `#name` alone or after a `.md` file, must be the anchor of a heading in that
    file, read as the file is read, in exact case (grado-factorio-tools#155). The anchor is
    the one GitHub gives, asked of it 2026-10-15 and in docs/measurements.md: the heading's
    text as it renders, lower-cased, with all but letters, marks, decimal digits, connector
    punctuation such as `_`, `-` and spaces dropped and each space made a hyphen; a repeat takes -1, -2 and on. A heading is a `#`
    line or a line alone after a blank one and underlined with `=` or `-`.
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
    open and the next numbered item closes. Markdown outside `.md` files. A link whose target file or heading a
    commit deletes or renames, unless the linking file is staged too: -All sees it. A link into
    a submodule is asked of the working tree, so neither its case nor whether git tracks it is
    checked; into one not initialised it is said to be unchecked, and passes.

.PARAMETER Range
    Check the Markdown files changed in a commit range, as they are at its end:
    -Range origin/main...HEAD. With three dots the files are those the branch at its end has
    changed since it left the base; two dots would also list each file the base has edited or
    deleted since then. The switch is commit-check.ps1's and the form is not: that script's range
    is a list of commits, which two dots give.

.PARAMETER All
    Check every tracked Markdown file, as staged, naming those whose unstaged edits were not read.

.PARAMETER MaxLineLength
    Also report a prose line longer than this many characters, 1 or more. Without it, length is
    not read.

.PARAMETER SelfTest
    Run the cases that hold the check to what this header says, naming each as it runs. Needs git,
    for a fixture repository in a temp directory.

.EXAMPLE
    pwsh -File scripts/markdown-check.ps1

.EXAMPLE
    pwsh -File scripts/markdown-check.ps1 -Range origin/main...HEAD
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $Range,
    [switch] $All,
    [int] $MaxLineLength = 0,
    [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

function Get-BareAddress {
    <#  Each bare address in $Text, as @{ Index; Length }, ended where GitHub's renderer ends one
        (asked 2026-10-12, grado-factorio-tools#124; in docs/measurements.md). It runs to the
        next whitespace or `<`, and then gives back what stands last: any of ?!.,:;*_~'" and
        an entity such as &amp;, and a ) with no ( before it in the address to match. Where a
        [ stands open before it in $Text, it ends at the ] that closes that one: GitHub makes
        no link of an address inside square brackets, and reads the mark before the ] as one.
        So the mark that closes emphasis straight after an address is not part of it. It ends
        at a `>` too, which the renderer takes in: an address in a raw tag's attribute would
        otherwise run on into the text after the tag.  #>
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Text)

    foreach ($m in [regex]::Matches($Text, '(?i)https?://[^\s<>]+')) {
        $run = $m.Value
        $before = $Text.Substring(0, $m.Index)
        if ($before.Split('[').Count -gt $before.Split(']').Count) {
            $depth = 0
            for ($k = 0; $k -lt $run.Length; $k++) {
                if ($run[$k] -eq '[') { $depth++ }
                elseif ($run[$k] -eq ']') { if ($depth -eq 0) { $run = $run.Substring(0, $k); break }; $depth-- }
            }
        }
        $end = $run.Length
        while ($end -gt 0) {
            $kept = $run.Substring(0, $end)
            $last = [string] $kept[$end - 1]
            # Letters only: the renderer gives back &amp; whole and of &frac12; the `;` alone.
            if ($kept -match '&[a-zA-Z]+;$') { $end -= $Matches[0].Length }
            elseif ('?!.,:;*_~''"'.Contains($last)) { $end-- }
            elseif ($last -eq ')' -and $kept.Split(')').Count -gt $kept.Split('(').Count) { $end-- }
            else { break }
        }
        @{ Index = $m.Index; Length = $end }
    }
}

function Get-HeadingAnchor {
    <#  The anchor GitHub gives each heading in $Lines, as a set, asked of it on 2026-10-15
        (grado-factorio-tools#155; the answers are in docs/measurements.md). The anchor is made
        from the heading's text as it renders: a code span's content kept, a link's text kept,
        an image and a tag dropped, `_` emphasis that closes dropped, an escape and an entity
        read. That is lower-cased, all but letters, marks, decimal digits, connector punctuation
        such as `_`, hyphens and spaces dropped, and each space made a hyphen. A heading whose
        anchor is taken gets the first of -1, -2 and on that is not, counted per anchor.
        Ported from realistic-fusion-refreshed's ship-check.ps1, Get-HeadingAnchors, at
        f3238c5 (read 2026-10-15). That one made the anchor from the text as written, less
        each link's target, so it differed wherever rendering does; realistic-fusion-refreshed#712
        removed it on 2026-10-15, and this is the only copy.  #>
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [AllowEmptyString()] [string[]] $Lines)

    $anchors = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $seen = @{}
    # Front matter is no paragraph, so its closing --- underlines nothing and a `# comment` in it
    # is no heading. A --- with a blank line after it is a rule, not front matter.
    $i = 0
    if ($Lines.Count -gt 1 -and $Lines[0] -match '^---\s*$' -and $Lines[1] -match '\S') { for ($i = 1; $i -lt $Lines.Count -and $Lines[$i] -notmatch '^---\s*$'; $i++) { }; $i++ }
    $fence = $null
    $blank = $true
    for (; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i] -replace '^(\s*>)+\s?'
        if ($fence) { if ($line -match "^\s*$([regex]::Escape($fence))+\s*$") { $fence = $null }; continue }
        if ($line -match '^\s*(`{3,}|~{3,})') { $fence = $Matches[1]; continue }
        $next = if ($i + 1 -lt $Lines.Count) { $Lines[$i + 1] -replace '^(\s*>)+\s?' } else { '' }
        $text = $null
        if ($line -match '^ {0,3}#{1,6}(?:[ \t]+(.*?))?(?:[ \t]+#+)?[ \t]*$') { $text = "$($Matches[1])" }
        # A setext heading of one line: a line alone after a blank one, underlined.
        elseif ($blank -and $next -match '^ {0,3}(=+|-+)\s*$' -and $line -match '\S' -and $line -notmatch '^\s{0,3}([-*+]|\d+[.)])\s') { $text = $line.Trim(); $i++ }
        $blank = $line -notmatch '\S'
        if ($null -eq $text) { continue }
        $blank = $true

        # Code spans become one private character each, so nothing below reads inside them.
        $codes = [System.Collections.Generic.List[string]]::new()
        $shown = [regex]::Replace($text, '(`+)(.+?)\1', { param($m) $codes.Add($m.Groups[2].Value); [string] [char] (0xE000 + $codes.Count - 1) })
        $shown = $shown -replace '!\[[^\]]*\]\([^)]*\)' -replace '\[([^\]]*)\]\([^)]*\)', '$1'
        # An autolink keeps its address and a tag drops, its text staying; any other < is text.
        $shown = $shown -replace '<([a-zA-Z][a-zA-Z0-9+.-]*:[^<>\s]*)>', '$1' -replace '</?[a-zA-Z][a-zA-Z0-9-]*(?:\s[^<>]*)?/?>'
        # `_` emphasis that closes, innermost first; an unclosed or escaped `_` stays.
        do {
            $was = $shown
            $shown = $shown -replace '(?<![\p{L}\p{N}_\\])(_+)(?=[^\s_])(.*?[^\s\\_])\1(?![\p{L}\p{N}_])', '$2'
        } while ($shown -ne $was)
        $shown = [Net.WebUtility]::HtmlDecode(($shown -replace '\\([!-/:-@\[-`{-~])', '$1'))
        $shown = [regex]::Replace($shown, '[\uE000-\uF8FF]', { param($m) $codes[[int] $m.Value[0] - 0xE000] })
        $anchor = [regex]::Replace($shown.ToLowerInvariant(), '[^\p{L}\p{M}\p{Nd}\p{Pc}\- ]', '').Replace(' ', '-')
        $base = $anchor
        if (-not $seen.ContainsKey($base)) { $seen[$base] = 0 }
        while ($anchors.Contains($anchor)) { $seen[$base]++; $anchor = "$base-$($seen[$base])" }
        $null = $anchors.Add($anchor)
    }
    , $anchors
}

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
    # No script block is made or called from here on, as an evaluator, a predicate or a helper:
    # this runs for every paragraph and table cell, and those were most of its time
    # (grado-factorio-tools#125, in docs/measurements.md).
    foreach ($pattern in '(?<=\])\([^)\s]*(\s+"[^"]*")?\)', '://', '<[a-zA-Z][^>\s]*>') {
        $hidden = [Text.StringBuilder]::new($masked)
        # The second is no pattern: a bare address, looked for only where the text holds a
        # scheme, and before anything in angle brackets is hidden, so that it ends at a
        # <placeholder>. Its first and last characters stay, where a target and what is in
        # angle brackets are hidden whole: a mark straight after it is flanked by what the
        # address ends with, which is seldom punctuation, and the brackets of the other two are.
        if ($pattern -ne '://') { foreach ($m in [regex]::Matches($masked, $pattern)) { $null = $hidden.Remove($m.Index, $m.Length).Insert($m.Index, '.', $m.Length) } }
        elseif ($masked.Contains('://')) { foreach ($a in Get-BareAddress -Text $masked) { $null = $hidden.Remove($a.Index + 1, $a.Length - 2).Insert($a.Index + 1, '.', $a.Length - 2) } }
        $masked = $hidden.ToString()
    }

    $open = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($run in [regex]::Matches($masked, '\*+|_+')) {
        $prev = if ($run.Index -gt 0) { $masked[$run.Index - 1] } else { $null }
        $next = if ($run.Index + $run.Length -lt $masked.Length) { $masked[$run.Index + $run.Length] } else { $null }
        $prevSpace = $null -eq $prev -or [char]::IsWhiteSpace($prev)
        $nextSpace = $null -eq $next -or [char]::IsWhiteSpace($next)
        $prevPunct = $null -ne $prev -and ([char]::IsPunctuation($prev) -or [char]::IsSymbol($prev))
        $nextPunct = $null -ne $next -and ([char]::IsPunctuation($next) -or [char]::IsSymbol($next))
        $left  = -not $nextSpace -and (-not $nextPunct -or $prevSpace -or $prevPunct)
        $right = -not $prevSpace -and (-not $prevPunct -or $nextSpace -or $nextPunct)
        $char = $run.Value[0]
        $canOpen  = if ($char -eq '_') { $left -and (-not $right -or $prevPunct) } else { $left }
        $canClose = if ($char -eq '_') { $right -and (-not $left -or $nextPunct) } else { $right }
        $length = $run.Length
        while ($canClose -and $length -gt 0) {
            for ($at = $open.Count - 1; $at -ge 0 -and $open[$at].Char -ne $char; $at--) { }
            if ($at -lt 0) { break }
            # An opener of the other kind above it can no longer close around this one: a literal.
            if ($at + 1 -lt $open.Count) { $open.RemoveRange($at + 1, $open.Count - $at - 1) }
            $used = [Math]::Min($length, $open[$at].Length)
            $open[$at].Length -= $used
            $length -= $used
            if ($open[$at].Length -eq 0) { $open.RemoveAt($at) }
        }
        if ($canOpen -and $length -gt 0) { $open.Add(@{ Char = $char; Length = $length; Offset = $run.Index }) }
        # A `*` that can only close, left with nothing to close, renders as text, and is most often
        # an inverted italic whose reopening `*` stands against punctuation (grado-factorio-tools#164).
        # A `_` is not held to it: snake_case_ and the like end in one.
        elseif ($char -eq '*' -and $canClose -and $length -gt 0) {
            @{ Offset = $run.Index; Message = "a $([string]::new('*', $length)) that can only close has nothing open to close, so it renders as text; a * that reopens emphasis needs a space or a letter before it, not a letter before and punctuation after" }
        }
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
        $null for one it cannot tell. $Anchors is asked for the heading anchors of a tracked
        Markdown file by the same path, and answers $null for one it cannot read.  #>
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [AllowEmptyString()] [string[]] $Lines,
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [scriptblock] $Exists,
        [Parameter(Mandatory)] [scriptblock] $Anchors,
        [int] $MaxLineLength = 0
    )

    # The links on one line, dot-sourced, so that $prose, the line less its code spans, is left
    # for the length rule. A path in a code span is no link.
    $own = $null
    $links = {
        param([string] $linkLine, [int] $linkAt)
        $prose = [regex]::Replace($linkLine, '(`+)(?:(?!\1).)+?\1', '')
        $targets = @(foreach ($m in [regex]::Matches($prose, '\]\(\s*(?:<([^>]*)>|([^)\s]+))')) { $m.Groups[1].Value + $m.Groups[2].Value })
        if ($prose -match '^\s{0,3}\[[^\]^][^\]]*\]:\s*<?([^\s>]+)') { $targets += $Matches[1] }
        foreach ($t in $targets) {
            if ($t -match '^([a-zA-Z][a-zA-Z0-9+.-]*:|//)') { continue }
            $fragment = if ($t.Contains('#')) { [uri]::UnescapeDataString(($t -replace '^[^#]*#')) } else { '' }
            if ($t.StartsWith('#')) {
                if (-not $fragment) { continue }
                if ($null -eq $own) { $own = Get-HeadingAnchor -Lines $Lines }
                if (-not $own.Contains($fragment)) { @{ Line = $linkAt + 1; Message = "the link to $t names no heading of this file" } }
                continue
            }
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
            if ($null -eq $found) { Write-Host "markdown-check: ${Path}:$($linkAt + 1): $t is in a submodule that is not initialised, so it was NOT checked." }
            elseif (-not $found) { @{ Line = $linkAt + 1; Message = "the link to $t names no tracked file or directory (case matters)" } }
            # A query, as GitHub's ?plain=1#L3, asks for the source, whose fragments are lines.
            elseif ($fragment -and $file -match '\.md$' -and -not $t.Contains('?')) {
                $there = & $Anchors ($parts -join '/')
                if ($null -ne $there -and -not $there.Contains($fragment)) { @{ Line = $linkAt + 1; Message = "the link to $t names no heading of $($parts -join '/')" } }
            }
        }
    }

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
    # For the length rule alone: the lines PowerShell's own Markdown parser puts in an indented
    # code block, counted from 0. The parser is asked, and nothing here follows lists, blank lines
    # or rules to work it out (grado-factorio-tools#95). A fenced block has a type of its own.
    $codeLines = [System.Collections.Generic.HashSet[int]]::new()
    if ($MaxLineLength -gt 0) {
        $pending = [System.Collections.Generic.Stack[object]]::new()
        # The parser has a depth limit and throws past it. That must not end the run with no file
        # named, nor pass the page: it is held to the limit with nothing exempt as code.
        try { $pending.Push((ConvertFrom-Markdown -InputObject ($Lines -join "`n")).Tokens) }
        catch { Write-Host "markdown-check: ${Path}: PowerShell's parser could not read it, so no line of it was taken for code: $($_.Exception.Message)" }
        while ($pending.Count) {
            $block = $pending.Pop()
            if ($block.GetType().Name -eq 'CodeBlock') { for ($l = 0; $l -lt $block.Lines.Count; $l++) { $null = $codeLines.Add($block.Line + $l) } }
            elseif ($block -is [System.Collections.IEnumerable]) { foreach ($child in $block) { $pending.Push($child) } }
        }
    }
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i] -replace '^(\s*>)+\s?'
        if ($fence) {
            if ($line -match "^\s*$([regex]::Escape($fence))+\s*$") { $fence = $null }
            continue
        }
        if ($line -match '^\s*(`{3,}|~{3,})') { . $flush; $fence = $Matches[1]; $fenceLine = $i + 1; continue }

        # Links, on every line outside a fence, a table's rows included. Only a line holding
        # `](` or `]:` is handed over: called for every line, the script block made -All over
        # realistic-fusion-refreshed's 115 files at f3238c5 take 18.6 to 22.8 s where it had taken 12.1 to 16.0
        # (grado-factorio-tools#155, one machine, a run at a time).
        $prose = $line
        if ($line.Contains('](') -or $line.Contains(']:')) { . $links $line $i }

        if ($line -match '\|' -and $i + 1 -lt $Lines.Count -and $Lines[$i + 1] -match '\|' -and ($Lines[$i + 1] -replace '^(\s*>)+\s?') -match $delimiter) {
            . $flush
            $columns = (Split-TableRow $line).Count
            for ($r = $i; $r -lt $Lines.Count -and ($Lines[$r] -replace '^(\s*>)+\s?') -match '\S'; $r++) {
                if ($r -gt $i -and $Lines[$r].Contains('](')) { . $links ($Lines[$r] -replace '^(\s*>)+\s?') $r }
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

        # Length, only where a limit was handed in: the line as written, less what cannot be wrapped.
        # A heading and a `[label]: target` line cannot be broken at all, and neither can a line
        # with no space at or before the limit, past its list marker and first word. A space inside
        # a code span is no place to break: a command wrapped there is no longer the command.
        # A line of an indented code block is quoted output, which cannot be wrapped.
        if ($MaxLineLength -gt 0) {
            $counted = [regex]::Replace($Lines[$i].TrimEnd(), '(?<=\])\([^)\s]*(\s+"[^"]*")?\)|<[a-zA-Z][a-zA-Z0-9+.-]*:[^>\s]*>', '')
            if ($counted.Contains('://')) {
                $addresses = @(Get-BareAddress -Text $counted)
                for ($a = $addresses.Count - 1; $a -ge 0; $a--) { $counted = $counted.Remove($addresses[$a].Index, $addresses[$a].Length) }
            }
            if ($counted.Length -gt $MaxLineLength -and -not $codeLines.Contains($i) -and $line -notmatch '^\s{0,3}#{1,6}\s' -and $prose -notmatch '^\s{0,3}\[[^\]^][^\]]*\]:') {
                $lead = [regex]::Match($counted, '^(\s*>)*\s*(([-*+]|\d+[.)])\s+)?').Length
                $solid = [regex]::Replace($counted, '(`+)(?:(?!\1).)+?\1', { param($m) 'x' * $m.Length })
                if ($solid.Substring($lead, [Math]::Max(0, $MaxLineLength + 1 - $lead)) -match '\S\s') {
                    @{ Line = $i + 1; Message = "the line is $($counted.Length) characters, over the limit of $MaxLineLength, link targets and addresses not counted" }
                }
            }
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
    param([string[]] $Files, [string] $Revision = '', [Parameter(Mandatory)] [string] $Top, [int] $MaxLineLength = 0)

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
            # Each: what follows https://u.nu/ up to the next space, and how much of that is the address.
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
            # After a fence closes there is no paragraph left to continue, so the line ends the list.
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
# A limit that came out as 0 must not pass for a limit that was never asked for.
if ($PSBoundParameters.ContainsKey('MaxLineLength') -and $MaxLineLength -lt 1) { throw '-MaxLineLength must be 1 or more. Leave it out for no limit.' }

# git lists and reads from the root, so every path is the one it has there, whatever directory this
# is run in: ls-files and ls-tree would otherwise answer for the current directory only.
$top = git rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) { throw 'git found no repository here. Run it inside the repository.' }

if ($Range) {
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

$found = Invoke-Check -Files $files -Revision $revision -Top $top -MaxLineLength $MaxLineLength
# What was read is the index; a file whose working tree differs passed or failed on what is staged.
if (-not $Range) {
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
