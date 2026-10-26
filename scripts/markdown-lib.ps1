#Requires -Version 7
<#
    What markdown-check.ps1 and markdown-rewrap.ps1 both read Markdown by: the inline rules,
    the table rows, the links, and Test-Markdown, which classifies each line and reports what the
    check reports. Moved out of markdown-check.ps1 unchanged (grado-factorio-tools#215), so the
    rewrap cannot read a line as prose that the check reads as a table row, code or a heading.
    Get-CountedLine, the length rule's count, was taken out of Test-Markdown in the same change,
    so the rewrap measures a line as the check does. Dot-source it; it has no -SelfTest of its
    own: markdown-check.ps1's holds Test-Markdown and the count.
#>

Set-StrictMode -Version Latest

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
        emphasis never closed; and each `*` that can only close, with nothing open to close.
        Each as @{ Offset; Message }, the offset into $Text.  #>
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
    # Raw HTML is not prose either: a comment, and a tag with its attributes, on one line.
    foreach ($pattern in '(?<=\])\([^)\s]*(\s+"[^"]*")?\)', '://', '(?s)<!--.*?-->', '</?[a-zA-Z][^>\n]*>') {
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
        $both = $canOpen -and $canClose
        while ($canClose -and $length -gt 0) {
            # CommonMark's rule of 3: where either run can both open and close, two runs whose
            # lengths sum to a multiple of 3 do not pair, unless both lengths are multiples of 3.
            for ($at = $open.Count - 1; $at -ge 0; $at--) {
                $o = $open[$at]
                if ($o.Char -ne $char) { continue }
                if (($o.Both -or $both) -and ($o.Run + $run.Length) % 3 -eq 0 -and ($o.Run % 3 -ne 0 -or $run.Length % 3 -ne 0)) { continue }
                break
            }
            if ($at -lt 0) { break }
            # An opener of the other kind above it can no longer close around this one: a literal.
            if ($at + 1 -lt $open.Count) { $open.RemoveRange($at + 1, $open.Count - $at - 1) }
            $used = [Math]::Min($length, $open[$at].Length)
            $open[$at].Length -= $used
            $length -= $used
            if ($open[$at].Length -eq 0) { $open.RemoveAt($at) }
        }
        if ($canOpen -and $length -gt 0) { $open.Add(@{ Char = $char; Length = $length; Offset = $run.Index; Run = $run.Length; Both = $both }) }
        # A `*` that can only close, left with nothing to close, renders as text, and is most often
        # an inverted italic whose reopening `*` stands against punctuation
        # (grado-factorio-tools#164). A `_` is not held to it: snake_case_ and the like end in one.
        elseif ($char -eq '*' -and $canClose -and $length -gt 0) {
            @{ Offset = $run.Index; Message = "a $([string]::new('*', $length)) that can only close has nothing open to close, so it renders as text: put a space before a * meant to reopen emphasis, and write a * meant as text as \* or in a code span" }
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

function Get-CountedLine {
    <#  $Line as the length rule counts it: as written, less trailing spaces, the target of each
        `[text](target)` link, each `<scheme:...>` address and each bare address.  #>
    param([AllowEmptyString()] [string] $Line)
    $counted = [regex]::Replace($Line.TrimEnd(), '(?<=\])\([^)\s]*(\s+"[^"]*")?\)|<[a-zA-Z][a-zA-Z0-9+.-]*:[^>\s]*>', '')
    if ($counted.Contains('://')) {
        $addresses = @(Get-BareAddress -Text $counted)
        for ($a = $addresses.Count - 1; $a -ge 0; $a--) { $counted = $counted.Remove($addresses[$a].Index, $addresses[$a].Length) }
    }
    $counted
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
    # The lines PowerShell's own Markdown parser puts in an indented code block, counted from 0,
    # which no rule reads as prose (grado-factorio-tools#261). The parser is asked, and nothing
    # here follows lists, blank lines or rules to work it out (grado-factorio-tools#95). A fenced
    # block has a type of its own.
    $codeLines = [System.Collections.Generic.HashSet[int]]::new()
    $pending = [System.Collections.Generic.Stack[object]]::new()
    # The parser has a depth limit and throws past it. That must not end the run with no file
    # named, nor pass the page: it is read with no line of it taken for code.
    try { $pending.Push((ConvertFrom-Markdown -InputObject ($Lines -join "`n")).Tokens) }
    catch { Write-Host "markdown-check: ${Path}: PowerShell's parser could not read it, so no line of it was taken for code: $($_.Exception.Message)" }
    while ($pending.Count) {
        $block = $pending.Pop()
        if ($block.GetType().Name -eq 'CodeBlock') { for ($l = 0; $l -lt $block.Lines.Count; $l++) { $null = $codeLines.Add($block.Line + $l) } }
        elseif ($block -is [System.Collections.IEnumerable]) { foreach ($child in $block) { $pending.Push($child) } }
    }
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i] -replace '^(\s*>)+\s?'
        if ($fence) {
            if ($line -match "^\s*$([regex]::Escape($fence))+\s*$") { $fence = $null }
            continue
        }
        # A line of an indented code block ends the paragraph before it, and is not read: a fence
        # line in one opens no fence.
        if ($codeLines.Contains($i)) { . $flush; continue }
        if ($line -match '^\s*(`{3,}|~{3,})') { . $flush; $fence = $Matches[1]; $fenceLine = $i + 1; continue }

        # Links, on every line outside a fence, a table's rows included. Only a line holding
        # `](` or `]:` is handed over: called for every line, the script block made -All over
        # realistic-fusion-refreshed's 115 files at f3238c5 take 18.6 to 22.8 s where it had taken
        # 12.1 to 16.0 (grado-factorio-tools#155, one machine, a run at a time).
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

        # Length, only where a limit was handed in: the line as written, less what cannot be
        # wrapped. A heading and a `[label]: target` line cannot be broken at all, and neither can a
        # line with no space at or before the limit, past its list marker and first word. A space
        # inside a code span is no place to break: a command wrapped there is no longer the command.
        # A line of an indented code block never reaches here.
        if ($MaxLineLength -gt 0) {
            $counted = Get-CountedLine $Lines[$i]
            if ($counted.Length -gt $MaxLineLength -and $line -notmatch '^\s{0,3}#{1,6}\s' -and $prose -notmatch '^\s{0,3}\[[^\]^][^\]]*\]:') {
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
