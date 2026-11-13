#Requires -Version 7
<#
    The width rules for comment and header lines, which check.ps1 and comment-line-check.ps1 both
    load, so the rule they hold a file to is one (grado-factorio-tools#225, #344). A line of a
    PowerShell block comment, or one that begins with #, over the limit fails; a help block's
    .EXAMPLE section and a line of one word after its indent and comment marker are exempt. In a
    file that is not PowerShell, such as a hook or a workflow, a line that begins with # is the
    comment line, a shebang aside, as markdown-rewrap.ps1 -Comment reads one. What the PowerShell
    rule cannot see is in check.ps1's header, under A COMMENT OR HEADER LINE. The limit is the
    caller's.

    Dot-source it; it has no -SelfTest of its own: check.ps1's holds Get-LongCommentLine,
    comment-line-check.ps1's holds Get-LongHashLine and Get-ShortHelpLine, and
    markdown-rewrap.ps1's holds Get-HelpParagraph, Split-Token and Format-HelpParagraph, through
    -Comment and -Fill.

    A HELP PARAGRAPH (grado-factorio-tools#442) is read from the lines of a block comment whose
    opening mark starts a line, to its closing mark, and markdown-rewrap.ps1 -Comment and -Fill
    both read one so (Truls's ruling on #442): it ends at a blank line, a help keyword line, a
    change of indent, a line opening with a list marker, and a section lead such as `WHY.` after
    a line ending in a full stop. The .EXAMPLE section is not read. A paragraph indented deeper
    than the first of its section is marked as code: the fill and the report leave it, and the
    over-limit rewrap still rewraps a line of it that is over. The report reads the words the
    fill moves, by Split-Token, and a closing mark with the word before it, so a paragraph the
    fill has filled is one it names no line of (PR #452's review). What it cannot see: a block
    comment opened after code on its line, an opening mark that starts a line of a here-string,
    and a list item's lines after its first, which are deeper and so are left as code by the fill;
    and a figure in thousands split across a line end, as "580" and "000", which the fill keeps
    whole and the report reads as two.
#>

# The numbers of a script's comment and header lines over $Limit characters: each line of a <# #>
# block, and a line that begins with #. A help block's .EXAMPLE section is skipped, as an example
# is copied whole. Read from the parser's comment tokens, so a # line in a here-string is not one.
function Get-LongCommentLine {
    param([Parameter(Mandatory)] [string] $Path, [Parameter(Mandatory)] [int] $Limit)
    $tokens = $null
    [void] [Management.Automation.Language.Parser]::ParseFile($Path, [ref] $tokens, [ref] $null)
    $lines = [IO.File]::ReadAllLines($Path)
    # One word after its indent and comment marker, as an address is, cannot be broken.
    $over = { param($line) $line.Length -gt $Limit -and $line -notmatch '^\s*(#+\s*)?\S+\s*$' }
    foreach ($comment in $tokens | Where-Object Kind -eq 'Comment') {
        $first = $comment.Extent.StartLineNumber
        if (-not $comment.Text.StartsWith('<#')) {
            if ($lines[$first - 1] -match '^\s*#' -and (& $over $lines[$first - 1])) { $first }
            continue
        }
        $section = ''
        foreach ($n in $first..$comment.Extent.EndLineNumber) {
            # A help keyword in upper case, as they are written here, with or without an argument:
            # a line beginning `.githooks` or `.NET` is text.
            $keyword = '^\s*\.(SYNOPSIS|DESCRIPTION|PARAMETER|EXAMPLE|INPUTS|OUTPUTS|NOTES|LINK|COMPONENT|ROLE|FUNCTIONALITY)(\s|$)'
            if ($lines[$n - 1] -cmatch $keyword) { $section = $Matches[1] }
            if ($section -ne 'EXAMPLE' -and (& $over $lines[$n - 1])) { $n }
        }
    }
}

# A word, as every rewrap of markdown-rewrap.ps1 breaks between them: a run of text with no space
# outside a code span, a link, an autolink or an HTML comment, which may hold spaces and are never
# broken.
$WORD_TOKEN = '(?:(`+)(?:(?!\1).)*?\1|<!--.*?-->|\[(?:\\.|[^\[\]\\]|\[[^\]]*\])*\](?:\([^)]*\)|\[[^\]]*\])?|<[a-zA-Z][a-zA-Z0-9+.-]*:[^>\s]*>|[^\s`<\[]|[`<\[])+'

# The words of $Text, by $WORD_TOKEN. A figure grouped in thousands is one too: a space with a
# digit before it and exactly three digits after it is no place to break (grado-factorio-tools#345),
# so "580 000" is one word. That is wider than what markdown-check.ps1 fails, as "in 2026 100
# lines" is kept together too. Here, and not in markdown-rewrap.ps1, which loads it, so that
# Get-ShortHelpLine reads the words the fill moves (PR #452's review).
function Split-Token {
    param([AllowEmptyString()] [string] $Text)
    # Held by a character that is no whitespace while the words are found, then put back.
    $glue = [string] [char] 0x2063
    $glued = [regex]::Replace($Text, '(?<=\d) (?=\d{3}(?!\d))', $glue)
    , @([regex]::Matches($glued, $WORD_TOKEN) | ForEach-Object { $_.Value.Replace($glue, ' ') })
}

# The paragraphs of the block comments in $Lines, as the header says, each as @{ Start; End,
# 0-based and inclusive; First, the first line's indent and any `<#` opener; Rest, the indent of
# the lines after it; Close, the closing mark and the space before it where the paragraph's last
# line ends the block, or ''; Code, where it is indented deeper than its section's first, which
# a fill and the report leave and the over-limit rewrap still rewraps (PR #452's review) }.
function Get-HelpParagraph {
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [AllowEmptyString()] [string[]] $Lines)
    $keyword = '^\s*\.(SYNOPSIS|DESCRIPTION|PARAMETER|EXAMPLE|INPUTS|OUTPUTS|NOTES|LINK|COMPONENT|ROLE|FUNCTIONALITY)(\s|$)'
    $lead = "^[A-Z]{2,}[A-Z0-9'-]*(?:,? [A-Z][A-Z0-9'-]*)*(?: \([^)]*\))?\.(?:\s|$)"
    $item = '^(?:[-*+]|\d+[.)])\s'
    $closes = '#>\s*$'
    $open = $false; $section = ''; $base = -1; $i = 0
    while ($i -lt $Lines.Count) {
        $l = $Lines[$i]
        if (-not $open) {
            if ($l -notmatch '^\s*<#') { $i++; continue }
            $open = $true; $section = ''; $base = -1
        }
        $opener = [regex]::Match($l, '^\s*(?:<#\s*)?')
        $text = $l.Substring($opener.Length) -replace '\s*#>\s*$'
        if ($l -cmatch $keyword) { $section = $Matches[1]; $base = -1 }
        if ($l -cmatch $keyword -or $section -eq 'EXAMPLE' -or $text -notmatch '\S' -or $l -match '^\s*#>') {
            if ($l -match $closes) { $open = $false }
            $i++; continue
        }
        $indent = $opener.Length
        if ($base -lt 0) { $base = $indent }
        $e = $i
        while ($Lines[$e] -notmatch $closes -and $e + 1 -lt $Lines.Count) {
            $n = $Lines[$e + 1]
            if ($n -notmatch '\S' -or $n -cmatch $keyword -or $n -match '^\s*#>' -or [regex]::Match($n, '^\s*').Length -ne $indent) { break }
            $t = $n.Substring($indent)
            if ($t -match $item -or ($Lines[$e].TrimEnd().EndsWith('.') -and $t -cmatch $lead)) { break }
            $e++
        }
        @{ Start = $i; End = $e; First = $opener.Value; Rest = ' ' * $indent; Close = [regex]::Match($Lines[$e], '\s*#>\s*$').Value.TrimEnd()
           Code = $indent -gt $base }
        if ($Lines[$e] -match $closes) { $open = $false }
        $i = $e + 1
    }
}

# The numbers of the help lines in $Lines that are under-filled (#442): a line of a paragraph
# that is not code, not its last, that the next line's first word, by Split-Token, would fit on
# within $Limit. Where that word is all of the paragraph's last line, its closing mark comes with
# it, as the fill moves it.
function Get-ShortHelpLine {
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [AllowEmptyString()] [string[]] $Lines,
        [Parameter(Mandatory)] [int] $Limit)
    foreach ($p in Get-HelpParagraph -Lines $Lines | Where-Object { -not $_.Code }) {
        for ($k = $p.Start; $k -lt $p.End; $k++) {
            $next = $Lines[$k + 1].Substring($p.Rest.Length) -replace '\s*#>\s*$'
            $words = Split-Token $next
            $first = $words[0]
            if ($k + 1 -eq $p.End -and $p.Close -and $words.Count -eq 1) { $first += $p.Close }
            if ($Lines[$k].TrimEnd().Length + 1 + $first.Length -le $Limit) { $k + 1 }
        }
    }
}

# The lines of $Lines' paragraph $Paragraph, from its line $From, 0-based, to its end, filled
# greedily to $Max by $Join, the rewrap's Join-Greedy, with the closing mark carried on the last
# word, so it is measured with it (PR #452's review).
function Format-HelpParagraph {
    param([string[]] $Lines, [hashtable] $Paragraph, [int] $From, [int] $Max, [scriptblock] $Join)
    $text = (@($Lines[$From..$Paragraph.End] | ForEach-Object { ($_ -replace '^\s*<#') -replace '\s*#>\s*$' } | ForEach-Object { $_.Trim() }) -join ' ')
    # Split-Token returns its array whole; @() round it would make one word of the paragraph.
    $words = Split-Token $text
    if ($Paragraph.Close -and $words.Count) { $words[-1] += $Paragraph.Close }
    $first = if ($From -eq $Paragraph.Start) { $Paragraph.First } else { $Paragraph.Rest }
    & $Join $words $first $Paragraph.Rest $Max
}

# The numbers of the comment lines over $Limit characters in a file that is not PowerShell, as a
# hook or a workflow: a line that begins, after its indent, with #, less a shebang. A line of one
# word after its marker is exempt, as for a script. Whether the line is a comment is not asked: a
# line of a here-document or of a workflow's run: block that begins with # is read as one.
function Get-LongHashLine {
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [AllowEmptyString()] [string[]] $Lines,
        [Parameter(Mandatory)] [int] $Limit)
    for ($n = 1; $n -le $Lines.Count; $n++) {
        $line = $Lines[$n - 1]
        if ($line -match '^\s*#' -and $line -notmatch '^#!' -and $line.Length -gt $Limit -and
            $line -notmatch '^\s*(#+\s*)?\S+\s*$') { $n }
    }
}
