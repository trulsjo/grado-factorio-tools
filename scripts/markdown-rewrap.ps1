<#
.SYNOPSIS
    Rewraps the prose lines markdown-check.ps1 reports as longer than -MaxLineLength, each from
    that line to the end of its paragraph, so the check then passes on them. With -Comment, the
    same for the comment lines of a script. Exit 0 means it ran, whether or not it changed
    anything; a bad argument or a file it cannot read exits non-zero.

.DESCRIPTION
    WHY (grado-factorio-tools#215). The modpack's pre-commit hook runs markdown-check.ps1 with a
    limit of 100, and on grado-factorio-modpack PR #374 refused about nine commits, nearly all for
    length. Each repair by hand made a defect the next run or the review found: an HTML comment
    split across two lines, a table row wrapped, a code span split, a `*` left that the check
    rejects, a list item's continuation left unindented. The wrap is mechanical, so it is a script.

    WHAT IT READS. The same files the check would, by the same switches, read from disk: -Path
    names them, -All is every Markdown file git tracks, -Range the files a commit range changes,
    and with none of the three the staged ones. Which lines are over the limit, and which are
    prose at all, is asked of Test-Markdown in markdown-lib.ps1, which the check runs too
    (Truls, 2026-10-25, ruling 12 on #215), so the two cannot disagree on what is a table row,
    code, a heading or a link target. A line is counted as the check counts it, Get-CountedLine.

    WHAT IT DOES TO A FLAGGED LINE. From that line to the end of its paragraph, the words are
    filled greedily back to the limit; lines before it are left as they are, and the sequence of
    words is unchanged (ruling 13). It breaks only between words, never inside a code span, a
    link with its text and target, an autolink or an HTML comment, and an HTML comment stays on
    the line of the word before it. A list item's later lines are indented to its content, and a
    block quote's `>` is kept on each line. A line is never started with what would make it a
    list item, a heading, a block quote, a table row, a fence or an HTML block: the word before
    goes down with it. Since every break is at a space, no emphasis delimiter changes its sides.
    A paragraph ends at a blank line, a line that starts another block, or a hard line break. The
    file is written back with its line endings and byte-order mark as they were, to the working
    tree only, never staged (ruling 14). A second run changes nothing.

    WITH -Comment (ruling 15), for -Path files only, it finds the comment lines over the limit by
    their length, and rewraps each from that line to the end of its block: a run of lines with
    the same indent, `#` and one space, ended by a line of that prefix alone or another prefix;
    or a paragraph of a PowerShell block comment, between its opening and closing marks, ended by
    a blank line, a help keyword line such as `.SYNOPSIS`, or a change of indent. A keyword is
    a `.` and upper-case letters, matched with case (#254): a line opening `.github/` is prose of
    its paragraph. The indent is kept on each line written, and lines under `.EXAMPLE` are left as
    they are. A shebang and code are never touched.

    WHAT IT LEAVES, and names: a line the check still reports once it is rewrapped, as one
    holding a word and a token too long to share a line. A line of one token longer than the
    limit is not named: the check passes it, having no space to break at. What the check exempts
    is never flagged, so never touched. With -Comment, every comment line over the limit after
    the run is named, rewrapped or not, as a keyword line or a `##` line is not: all but a line
    under `.EXAMPLE` and a line of one word after its marker, which comment-line-lib.ps1 exempts.

    WHAT IT CANNOT SEE. Whether the wrap reads well: it is greedy, not balanced. A flagged line
    that starts inside a code span opened on the line before, whose backticks it then pairs
    wrongly: grado-factorio-modpack at 6d7a119 had one, a line starting `>= 4.17.10`, which
    GitHub reads as a block quote. A paragraph that
    continues lazily into a line the check reads as something else. In -Comment mode, a block
    comment's opening or closing mark inside a string, which is taken as the block's edge, and a
    hanging indent such as a help paragraph's term and its text, whose flagged line is rewrapped to
    its own indent. A prose line in a block comment opening with `.` and upper-case letters, as
    `.NET`, which is taken for a keyword and left. And a line starting `# ` inside a here-string or
    a YAML block scalar, which is taken for a comment and rewrapped.

.PARAMETER Range
    Rewrap the Markdown files changed in this commit range, as markdown-check.ps1 takes it:
    -Range origin/main...HEAD. They are read and written on disk.

.PARAMETER All
    Rewrap every Markdown file git tracks.

.PARAMETER Path
    Rewrap these files, split on commas. With -Comment they are scripts.

.PARAMETER MaxLineLength
    The limit, 1 or more, as markdown-check.ps1 takes it. Required.

.PARAMETER Comment
    Rewrap the comment lines of the -Path files instead of Markdown.

.PARAMETER SelfTest
    Run the cases that hold it to this header, against text in memory and a scratch file; the
    ticket's five defects each against a naive greedy wrap too, which makes it. Needs no git and
    no game.

.EXAMPLE
    pwsh -File scripts/markdown-rewrap.ps1 -MaxLineLength 100

.EXAMPLE
    pwsh -File scripts/markdown-rewrap.ps1 -Comment -Path .github/workflows/check.yml -MaxLineLength 100
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $Range,
    [switch] $All,
    [string[]] $Path,
    [int] $MaxLineLength = 0,
    [switch] $Comment,
    [switch] $SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

. "$PSScriptRoot/markdown-lib.ps1"

# A token is a run of text with no space outside a code span, a link, an autolink or an HTML
# comment, which may hold spaces and are never broken.
$TOKEN = '(?:(`+)(?:(?!\1).)*?\1|<!--.*?-->|\[(?:\\.|[^\[\]\\]|\[[^\]]*\])*\](?:\([^)]*\)|\[[^\]]*\])?|<[a-zA-Z][a-zA-Z0-9+.-]*:[^>\s]*>|[^\s`<\[]|[`<\[])+'
# What a line must not start with: it would begin a list item, a heading, a block quote, a table
# row, a fence, a setext underline or an HTML block.
$OPENS = '^(?:[-*+]|\d+[.)]|#{1,6}|=+|-+|>.*|\|.*|```.*|~~~.*|<[a-zA-Z/!].*)$'

function Split-Token {
    <#  The tokens of $Text. An HTML comment is one, and stays beside the word before it because
        $OPENS keeps it from starting a line.  #>
    param([AllowEmptyString()] [string] $Text)
    , @([regex]::Matches($Text, $TOKEN) | ForEach-Object Value)
}

function Join-Greedy {
    <#  $Tokens filled into lines no longer than $Max as $Measure counts them, the first behind
        $First and the rest behind $Rest. With $Guard, a token $OPENS matches never starts a line:
        the token before it goes down too.  #>
    param([string[]] $Tokens, [string] $First, [string] $Rest, [int] $Max, [scriptblock] $Measure, [switch] $Guard)
    $lines = [System.Collections.Generic.List[string]]::new()
    $line = [System.Collections.Generic.List[string]]::new()
    $prefix = $First
    foreach ($t in $Tokens) {
        if ($line.Count -and (& $Measure ($prefix + (($line + $t) -join ' '))) -gt $Max) {
            $carry = @()
            if ($Guard -and $t -match $OPENS -and $line.Count -gt 1) { $carry = @($line[$line.Count - 1]); $line.RemoveAt($line.Count - 1) }
            if (-not ($Guard -and $t -match $OPENS -and -not $carry)) {
                $lines.Add($prefix + ($line -join ' ')); $prefix = $Rest
                $line.Clear(); foreach ($c in $carry) { $line.Add($c) }
            }
        }
        $line.Add($t)
    }
    if ($line.Count) { $lines.Add($prefix + ($line -join ' ')) }
    , $lines.ToArray()
}

function Invoke-MarkdownRewrap {
    <#  $Lines with each paragraph that holds a line Test-Markdown reports as over $Max rewrapped
        from that line on. Returns @{ Lines; Rewrapped (each 'first-last', 1-based, of the new
        lines); Left (each line number still over) }.  #>
    param([AllowEmptyCollection()] [AllowEmptyString()] [string[]] $Lines, [int] $Max)
    $flagged = @(Test-Markdown -Lines $Lines -Path 'rewrap.md' -Exists { $true } -Anchors { $null } -MaxLineLength $Max 6>$null |
        Where-Object { $_.Message -like 'the line is *' } | ForEach-Object { $_.Line - 1 } | Sort-Object -Unique)
    $out = [System.Collections.Generic.List[string]]::new()
    $rewrapped = @(); $left = @()
    $next = 0
    foreach ($f in $flagged) {
        if ($f -lt $next) { continue }
        for ($k = $next; $k -lt $f; $k++) { $out.Add($Lines[$k]) }
        $quote = [regex]::Match($Lines[$f], '^(?:\s*>)+\s?').Value
        $body = $Lines[$f].Substring($quote.Length)
        # A later line's marks have a space after them, so no word is joined to a `>`.
        $marks = if ($quote) { $quote.TrimEnd() + ' ' } else { '' }
        $item = [regex]::Match($body, '^(\s*)([-*+]|\d+[.)])(\s+)(?=\S)')
        if ($item.Success) { $first = $quote + $item.Value; $rest = $marks + (' ' * $item.Length) }
        else { $first = $quote + [regex]::Match($body, '^\s*').Value; $rest = $marks + [regex]::Match($body, '^\s*').Value }
        # The paragraph runs on while a line holds more of it.
        $e = $f
        while ($e + 1 -lt $Lines.Count -and $Lines[$e] -notmatch '(  |\\)$') {
            $n = $Lines[$e + 1]
            if (-not $n.StartsWith($quote) -or ($quote -eq '' -and $n -match '^\s*>')) { break }
            $b = $n.Substring($quote.Length)
            if ($b -notmatch '\S' -or $b -match '^\s*(?:[-*+]|\d+[.)])\s|^\s{0,3}#{1,6}(\s|$)|^\s*(```|~~~)|^\s*\||^\s{0,3}\[[^\]]+\]:|^\s*<|^\s*(?<rule>[-*_=])(\s*\k<rule>){2,}\s*$|^\s*>') { break }
            $e++
        }
        # Each line trimmed, so that a link or an HTML comment the paragraph had broken across two
        # lines is one token with one space where the break was.
        $text = (@($Lines[$f].Substring($first.Length)) + @(for ($k = $f + 1; $k -le $e; $k++) { $Lines[$k].Substring($quote.Length).Trim() })) -join ' '
        $new = Join-Greedy -Tokens (Split-Token $text.Trim()) -First $first -Rest $rest -Max $Max -Measure { (Get-CountedLine $args[0]).Length } -Guard
        # A hard line break of two spaces ends the paragraph here, and is kept.
        if ($Lines[$e] -match '\S  +$') { $new[-1] += '  ' }
        $start = $out.Count + 1
        foreach ($l in $new) { $out.Add($l) }
        $rewrapped += "$start-$($out.Count)"
        $next = $e + 1
    }
    for ($k = $next; $k -lt $Lines.Count; $k++) { $out.Add($Lines[$k]) }
    # Left is what the check still reports, so the two cannot disagree on it.
    if ($rewrapped) {
        $left = @(Test-Markdown -Lines $out.ToArray() -Path 'rewrap.md' -Exists { $true } -Anchors { $null } -MaxLineLength $Max 6>$null |
            Where-Object { $_.Message -like 'the line is *' } | ForEach-Object Line)
    }
    @{ Lines = $out.ToArray(); Rewrapped = $rewrapped; Left = $left }
}

function Invoke-CommentRewrap {
    <#  As Invoke-MarkdownRewrap, for the comment lines of a script: a `#` block or a paragraph of
        a block comment, found over $Max by length alone.  #>
    param([AllowEmptyCollection()] [AllowEmptyString()] [string[]] $Lines, [int] $Max)
    # What each line is: in a block comment, and under which help keyword. A keyword is matched
    # in upper case, as PowerShell writes .SYNOPSIS: a line opening .github is prose.
    $HELP_KEYWORD = '^\s*\.([A-Z]+)\b'
    $read = {
        param([string[]] $l)
        $inBlock = @($false) * $l.Count; $section = @('') * $l.Count
        $open = $false; $keyword = ''
        for ($i = 0; $i -lt $l.Count; $i++) {
            if (-not $open -and $l[$i] -match '^\s*<#') { $open = $true; $keyword = '' }
            if ($open) {
                $inBlock[$i] = $true
                if ($l[$i] -cmatch $HELP_KEYWORD) { $keyword = $Matches[1] }
                $section[$i] = $keyword
                if ($l[$i] -match '#>\s*$') { $open = $false }
            }
        }
        @{ InBlock = $inBlock; Section = $section }
    }
    $seen = & $read $Lines
    $inBlock = $seen.InBlock; $section = $seen.Section
    $out = [System.Collections.Generic.List[string]]::new()
    $rewrapped = @(); $left = @()
    $next = 0
    for ($f = 0; $f -lt $Lines.Count; $f++) {
        if ($f -lt $next -or $Lines[$f].TrimEnd().Length -le $Max) { continue }
        if ($inBlock[$f]) {
            if ($section[$f] -eq 'EXAMPLE' -or $Lines[$f] -cmatch $HELP_KEYWORD) { continue }
            $opener = [regex]::Match($Lines[$f], '^\s*<#\s*')
            $first = if ($opener.Success) { $opener.Value } else { [regex]::Match($Lines[$f], '^\s*').Value }
            $rest = ' ' * $first.Length
            $e = $f
            while ($e + 1 -lt $Lines.Count -and $inBlock[$e + 1] -and $Lines[$e] -notmatch '#>\s*$') {
                $n = $Lines[$e + 1]
                if ($n -notmatch '\S' -or $n -cmatch $HELP_KEYWORD -or $n -match '^\s*#>' -or [regex]::Match($n, '^\s*').Length -ne $rest.Length) { break }
                $e++
            }
        }
        else {
            $hash = [regex]::Match($Lines[$f], '^(\s*)# ')
            if (-not $hash.Success -or $Lines[$f] -match '^#!') { continue }
            # The text's own indent past the `# ` is kept, and a change of it ends the paragraph.
            $first = $hash.Value + [regex]::Match($Lines[$f].Substring($hash.Length), '^\s*').Value
            $rest = $first
            $e = $f
            while ($e + 1 -lt $Lines.Count -and $Lines[$e + 1].StartsWith($first) -and $Lines[$e + 1].Substring($first.Length) -match '^\S') { $e++ }
        }
        # Each line less its prefix: the `# ` of a `#` block, or the `<#` that opens a block
        # comment.
        $strip = if ($inBlock[$f]) { '^\s*<#' } else { '^\s*# ' }
        $text = (@($Lines[$f..$e] | ForEach-Object { ($_ -replace $strip).Trim() }) -join ' ')
        $close = [regex]::Match($text, '\s*#>$')
        if ($close.Success) { $text = $text.Substring(0, $close.Index) }
        for ($k = $next; $k -lt $f; $k++) { $out.Add($Lines[$k]) }
        $new = Join-Greedy -Tokens (Split-Token $text) -First $first -Rest $rest -Max $Max -Measure { $args[0].Length }
        if ($close.Success) { $new[-1] += $close.Value }
        $start = $out.Count + 1
        foreach ($l in $new) { $out.Add($l) }
        $rewrapped += "$start-$($out.Count)"
        $next = $e + 1
    }
    for ($k = $next; $k -lt $Lines.Count; $k++) { $out.Add($Lines[$k]) }
    # Left is each comment line still over, rewrapped or not, less what the comment-line check
    # exempts: a line under .EXAMPLE, and one of a single word after its marker.
    $after = & $read $out.ToArray()
    for ($k = 0; $k -lt $out.Count; $k++) {
        $comment = $after.InBlock[$k] -or ($out[$k] -match '^\s*#' -and $out[$k] -notmatch '^#!')
        if ($comment -and $out[$k].TrimEnd().Length -gt $Max -and $after.Section[$k] -ne 'EXAMPLE' -and $out[$k] -notmatch '^\s*(#+\s*)?\S+\s*$') { $left += $k + 1 }
    }
    @{ Lines = $out.ToArray(); Rewrapped = $rewrapped; Left = $left }
}

function Invoke-SelfTest {
    $max = 40
    # The words, less each line's block-quote marks.
    $words = { param([string[]] $l) ((($l | ForEach-Object { $_ -replace '^(\s*>)+' }) -join ' ') -split '\s+' | Where-Object { $_ }) -join ' ' }
    # The rewrap a hand does: split at every space, fill to the limit, no rule.
    $naive = {
        param([string[]] $l)
        $out = @(); $line = ''
        foreach ($w in (($l -join ' ') -split '\s+' | Where-Object { $_ })) {
            if ($line -and ($line.Length + 1 + $w.Length) -gt $max) { $out += $line; $line = $w } else { $line = if ($line) { "$line $w" } else { $w } }
        }
        $out + $line
    }
    $clean = { param([string[]] $l) -not @(Test-Markdown -Lines $l -Path 'rewrap.md' -Exists { $true } -Anchors { $null } -MaxLineLength $max 6>$null) }
    # After the rewrap the check finds nothing, the words are the input's, and a second run
    # changes nothing.
    $holds = {
        param([string[]] $in, [scriptblock] $also)
        $r = Invoke-MarkdownRewrap -Lines $in -Max $max
        $again = Invoke-MarkdownRewrap -Lines $r.Lines -Max $max
        $ok = (& $clean $r.Lines) -and (& $words $r.Lines) -ceq (& $words $in) -and ($again.Lines -join "`n") -ceq ($r.Lines -join "`n") -and $r.Rewrapped -and (& $also $r.Lines)
        if (-not $ok) { $r.Lines | ForEach-Object { Write-Host "    |$_" } }
        $ok
    }
    # The same of a comment block, whose body is the lines $body matches: none is over, each
    # keeps $prefix.
    $commentHolds = {
        param([string[]] $in, [string] $body, [string] $prefix)
        $r = Invoke-CommentRewrap -Lines $in -Max $max
        $again = Invoke-CommentRewrap -Lines $r.Lines -Max $max
        $lines = @($r.Lines | Where-Object { $_ -match $body })
        $bare = { param([string[]] $l) (& $words $l) -replace '(^| )(#|<#|#>)(?= |$)' }
        $ok = $lines -and -not @($lines | Where-Object { $_.Length -gt $max }) -and (& $bare $r.Lines) -ceq (& $bare $in) -and
            ($again.Lines -join "`n") -ceq ($r.Lines -join "`n") -and -not @($lines | Where-Object { -not $_.StartsWith($prefix) }) -and $r.Rewrapped
        if (-not $ok) { $r.Lines | ForEach-Object { Write-Host "    |$_" } }
        $ok
    }
    $cases = [ordered]@{
        'an HTML comment stays whole on the line of the word before it' = {
            $in = @('A first line that is long enough, break <!-- deliberate: word --> then more.')
            -not @(& $naive $in | Where-Object { $_ -match 'break <!-- deliberate: word -->' }) -and (& $holds $in { param($l) @($l | Where-Object { $_ -match 'break <!-- deliberate: word -->' }).Count -eq 1 }) }
        'a table row is left as it was' = {
            $row = '| a cell holding a great many words | and another cell holding more |'
            $in = @('A prose line that runs well past the limit of forty.', '', '| head | head |', '|---|---|', $row)
            -not ((& $naive $in) -ccontains $row) -and (& $holds $in { param($l) $l -ccontains $row }) }
        'a code span is never broken' = {
            $in = @('One two three four five six `base >= 2.1.0` here.')
            @(& $naive $in | Where-Object { ($_.Split('`').Count - 1) % 2 }) -and (& $holds $in { param($l) @($l | Where-Object { $_.Contains('`base >= 2.1.0`') }).Count -eq 1 }) }
        'no line starts with a lone * or another block opener' = {
            $in = @('The yield is two thirds of seven, times * three and + four.')
            @(& $naive $in | Where-Object { $_ -match '^[*+] ' }) -and (& $holds $in { param($l) -not @($l | Where-Object { $_ -match '^[*+-] ' }) }) }
        'a list item''s later lines are indented to its content' = {
            $in = @('- An item that is long enough that it has to wrap onto further lines.', '- The next.')
            @(& $naive $in | Select-Object -Skip 1 | Where-Object { $_ -notmatch '^(- |  )' }) -and
                (& $holds $in { param($l) $l[0].StartsWith('- ') -and -not @($l[1..($l.Count - 2)] | Where-Object { -not $_.StartsWith('  ') -or $_.StartsWith('   ') }) -and $l[-1] -ceq '- The next.' }) }
        'a line before the flagged one is left, and a block quote keeps its >' = {
            $in = @('> Short first.', '> Then a quoted line well past the limit of forty.')
            (& $holds $in { param($l) $l[0] -ceq '> Short first.' -and -not @($l | Where-Object { -not $_.StartsWith('> ') }) }) }
        'a thematic break, a setext underline and a hard break end the paragraph, and are kept' = {
            $ok = foreach ($rule in '***', '---', '=====') {
                & $holds @('A paragraph line that is long enough to pass forty.', $rule, 'After.') { param($l) $l -ccontains $rule }
            }
            $hard = Invoke-MarkdownRewrap -Lines @('A line that is long enough to go well past forty  ', 'next line kept on its own.') -Max $max
            -not ($ok -contains $false) -and $hard.Lines[-2].EndsWith('forty  ') -and $hard.Lines[-1] -ceq 'next line kept on its own.' }
        'a link whose text holds brackets is not broken' = {
            $in = @('Some words first, [a link with [nested] text and more](https://example.com/x) after.')
            (& $holds $in { param($l) @($l | Where-Object { $_.Contains('[a link with [nested] text and more](https://example.com/x)') }).Count -eq 1 }) }
        'a link broken across a list item''s lines is joined with one space, and left whole' = {
            $in = @('- An item that runs past the limit, [a link', '  text](https://example.com) and more words.')
            (& $holds $in { param($l) @($l | Where-Object { $_.Contains('[a link text](https://example.com)') }).Count -eq 1 }) }
        'a # comment block is rewrapped to its end, its prefix kept; code is not touched' = {
            $in = @('#!/usr/bin/env pwsh', '    # A comment line that is well over the limit of forty.', '    # And a line near it, close to it.', '$x = 1 # a trailing comment on code that runs long')
            $r = Invoke-CommentRewrap -Lines $in -Max $max
            # The next line is near the limit, so the flagged line's overflow pushed onto it alone
            # would put it over.
            $in[2].Length -gt $max - 8 -and ($r.Lines[0] -ceq $in[0]) -and ($r.Lines[-1] -ceq $in[-1]) -and (& $commentHolds $in '^(?!#!|\$x)' '    # ') }
        'a <# #> paragraph is rewrapped to its end, its indent kept' = {
            $in = @('<#', '.SYNOPSIS', '    A help line that is well over the limit of forty.', '    And a line near it, close to the end.', '#>')
            $in[3].Length -gt $max - 8 -and (& $commentHolds $in '^\s' '    ') -and (Invoke-CommentRewrap -Lines $in -Max $max).Lines[-1] -ceq '#>' }
        'a block-comment paragraph ends at a blank line, a help keyword or a change of indent; a # inside it is a word' = {
            $in = @('<#', '.DESCRIPTION', '    A help line that is well over the limit of forty.', '', '    Second paragraph.',
                '    Third, a long line well over the limit of forty,', '    # in it here.', '.NOTES', '    After.', '    Long again past the limit of forty chars.', '        Deeper.', '#>')
            $r = (Invoke-CommentRewrap -Lines $in -Max $max).Lines
            ($r -ccontains '    Second paragraph.') -and ($r -ccontains '.NOTES') -and ($r -ccontains '    After.') -and ($r -ccontains '        Deeper.') -and
                ($r -join ' ') -match ' # in it' -and -not @($r | Where-Object { $_.Length -gt $max }) }
        'a doc comment opened and closed on its paragraph keeps <# and #>' = {
            $in = @('    <#  A doc comment that is well over the limit.  #>')
            $r = (Invoke-CommentRewrap -Lines $in -Max $max).Lines
            $r[0].StartsWith('    <#  ') -and $r[-1].EndsWith('  #>') -and -not @($r | Where-Object { $_.Length -gt $max }) -and (& $words $r) -ceq (& $words $in) }
        'a command under .EXAMPLE is left over the limit' = {
            $cmd = '    pwsh -File scripts/markdown-rewrap.ps1 -MaxLineLength 100'
            $r = Invoke-CommentRewrap -Lines @('<#', '.EXAMPLE', $cmd, '#>') -Max $max
            $r.Lines[2] -ceq $cmd -and -not $r.Rewrapped }
        'a block-comment line opening with . and a lowercase word is prose, rewrapped; .EXAMPLE beside it is left' = {
            $cmd = '    pwsh -File scripts/markdown-rewrap.ps1 -MaxLineLength 100'
            $in = @('<#', '.DESCRIPTION', '    The start of a paragraph,', '    .github/, .claude/ or scripts/ names its path here.', '    Then more.', '.EXAMPLE', $cmd, '#>')
            $r = Invoke-CommentRewrap -Lines $in -Max $max
            ($r.Lines -ccontains $cmd) -and ($r.Lines -ccontains '.EXAMPLE') -and ($r.Lines -join ' ') -match '\.github/' -and
                (& $commentHolds $in '^    (?!pwsh)' '    ') }
        'a comment line over the limit that is not rewrapped is counted as left over' = {
            $in = @('<#', '.PARAMETER AParameterNameThatIsLong with its text', '    Short.', '#>', '## A ## line that is well over the limit of forty.')
            $r = Invoke-CommentRewrap -Lines $in -Max $max
            -not $r.Rewrapped -and ($r.Left -join ',') -ceq '2,5' }
        'a token longer than the limit goes on a line of its own, not named; a line the check still reports is named' = {
            $r = Invoke-MarkdownRewrap -Lines @('A word then `a-code-span-much-longer-than-forty-characters` after.') -Max $max
            $named = Invoke-MarkdownRewrap -Lines @('A word then a [link whose text runs well past forty characters](u) after.') -Max $max
            -not $r.Left -and $r.Lines -ccontains '`a-code-span-much-longer-than-forty-characters`' -and $named.Left.Count -eq 1 }
        'an autolink is not broken, and no line starts with # or |' = {
            $in = @('Words, and words <https://example.com/a b> then # and | more words to wrap here.')
            (& $holds $in { param($l) -not @($l | Where-Object { $_ -match '^[#|]' }) -and @($l | Where-Object { $_.Contains('<https://example.com/a') }) }) }
        'a file is written back with its byte-order mark and CRLF line endings' = {
            $file = Join-Path ([IO.Path]::GetTempPath()) "rewrap-selftest-$([guid]::NewGuid().ToString('N')).md"
            try {
                [IO.File]::WriteAllBytes($file, [byte[]] (0xEF, 0xBB, 0xBF) + [Text.Encoding]::UTF8.GetBytes("A line that is long enough to go well past forty.`r`nNext.`r`n"))
                $null = & pwsh -NoProfile -File $PSCommandPath -Path $file -MaxLineLength $max
                $bytes = [IO.File]::ReadAllBytes($file)
                $text = [Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
                $LASTEXITCODE -eq 0 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF -and
                    ($text -split "`r`n").Count -eq 3 -and -not ($text -replace "`r`n" -match "`n")
            }
            finally { Remove-Item -LiteralPath $file -ErrorAction SilentlyContinue } }
        'no -MaxLineLength is refused, and so is a script without -Comment, -Comment without -Path, -Path with -All, and a missing file' = {
            $said = & pwsh -NoProfile -File $PSCommandPath -Path 'x.md' 2>&1 | Out-String
            $code = $LASTEXITCODE
            $script = & pwsh -NoProfile -File $PSCommandPath -Path 'x.ps1' -MaxLineLength 40 2>&1 | Out-String
            $scriptCode = $LASTEXITCODE
            $refused = foreach ($a in @('-Comment', '-MaxLineLength', '40'), @('-All', '-Path', 'x.md', '-MaxLineLength', '40'), @('-Path', 'no-such.md', '-MaxLineLength', '40')) {
                $null = & pwsh -NoProfile -File $PSCommandPath @a 2>&1; $LASTEXITCODE -ne 0
            }
            $code -ne 0 -and $said -match '-MaxLineLength' -and $scriptCode -ne 0 -and $script -match 'not a Markdown file' -and -not ($refused -contains $false) }
    }
    $failures = 0; $n = 0
    foreach ($name in $cases.Keys) {
        $n++
        $ok = try { [bool] (& $cases[$name]) } catch { Write-Host "    threw: $($_.Exception.Message)"; $false }
        Write-Host ("self-test {0}/{1}: {2} -- {3}" -f $n, $cases.Count, $name, $(if ($ok) { 'ok' } else { 'FAILED' }))
        if (-not $ok) { $failures++ }
    }
    Write-Host ''
    if ($failures) { Write-Host "FAILED - self-test: $failures of $($cases.Count) case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all $($cases.Count) cases."
    exit 0
}

if ($SelfTest) { Invoke-SelfTest }
if ($MaxLineLength -lt 1) { throw 'Give -MaxLineLength, 1 or more: the limit markdown-check.ps1 holds the lines to.' }
$Path = @($Path -split ',' | Where-Object { $_ })
if ($Comment -and -not $Path) { throw '-Comment reads only the files -Path names.' }
if ($Path -and ($All -or $Range)) { throw '-Path cannot be combined with -All or -Range: it names the files itself.' }
# As markdown-check.ps1 refuses it: a script read as Markdown would have its code rewrapped.
$notMarkdown = @($Path | Where-Object { $_ -notmatch '\.md$' })
if ($notMarkdown -and -not $Comment) { throw "$($notMarkdown -join ', ') is not a Markdown file. Give -Comment to rewrap a script's comment lines." }

if ($Path) { $files = $Path }
else {
    $top = git rev-parse --show-toplevel
    if ($LASTEXITCODE -ne 0) { throw 'git found no repository here. Run it inside the repository, or name the files with -Path.' }
    $listed = if ($Range) { @(git -C $top -c core.quotepath=off diff --name-only --diff-filter=ACMR $Range) }
        elseif ($All) { @(git -C $top -c core.quotepath=off ls-files) }
        else { @(git -C $top -c core.quotepath=off diff --cached --name-only --diff-filter=ACMR) }
    if ($LASTEXITCODE -ne 0) { throw 'git could not list the files.' }
    $files = @($listed | Where-Object { $_ -match '\.md$' } | ForEach-Object { Join-Path $top $_ })
}

$changed = 0; $ranges = 0; $over = 0
foreach ($file in $files) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "$file is no file." }
    $bytes = [IO.File]::ReadAllBytes($file)
    $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $text = [Text.UTF8Encoding]::new($false).GetString($bytes, $(if ($bom) { 3 } else { 0 }), $bytes.Length - $(if ($bom) { 3 } else { 0 }))
    $newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $lines = $text -split '\r?\n'
    $r = if ($Comment) { Invoke-CommentRewrap -Lines $lines -Max $MaxLineLength } else { Invoke-MarkdownRewrap -Lines $lines -Max $MaxLineLength }
    foreach ($l in $r.Left) { Write-Host "markdown-rewrap: ${file}:${l}: cannot be brought under $MaxLineLength, left as it is"; $over++ }
    $after = $r.Lines -join $newline
    if ($after -ceq $text) { continue }
    foreach ($span in $r.Rewrapped) { Write-Host "markdown-rewrap: ${file}:$span rewrapped" }
    $out = [Text.UTF8Encoding]::new($bom).GetPreamble() + [Text.UTF8Encoding]::new($false).GetBytes($after)
    [IO.File]::WriteAllBytes($file, $out)
    $changed++; $ranges += $r.Rewrapped.Count
}
Write-Host "OK - markdown-rewrap: $ranges paragraph(s) rewrapped in $changed of $($files.Count) file(s); $over line(s) left over $MaxLineLength."
exit 0
