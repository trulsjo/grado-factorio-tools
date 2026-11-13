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
    markdown-rewrap.ps1's holds Get-HelpParagraph, through its -Fill.

    A HELP PARAGRAPH (grado-factorio-tools#442) is read from the lines of a block comment whose
    opening mark starts a line, to its closing mark, as markdown-rewrap.ps1 -Comment reads one:
    it ends at a blank
    line, a help keyword line, a change of indent, a line opening with a list marker, and a
    section lead such as `WHY.` after a line ending in a full stop. The .EXAMPLE section is not
    read, and nor is a paragraph indented deeper than the first of its section, which is taken
    for code. What it cannot see: a block comment opened after code on its line, an opening mark
    that starts a line of a here-string, and a list item's lines after its first, which are deeper and
    so are left as code.
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

# The prose paragraphs of the block comments in $Lines, as the header says, each as @{ Start;
# End, 0-based and inclusive; First, the first line's indent and any `<#` opener; Rest, the
# indent of the lines after it }.
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
        if ($indent -eq $base) { @{ Start = $i; End = $e; First = $opener.Value; Rest = ' ' * $indent } }
        if ($Lines[$e] -match $closes) { $open = $false }
        $i = $e + 1
    }
}

# The numbers of the help lines in $Lines that are under-filled (#442): a line of a help
# paragraph, not its last, that the next line's first word would fit on within $Limit. A word is
# a run with no space outside a code span, an HTML comment or a link, as markdown-rewrap.ps1
# breaks between them; a figure grouped in thousands, which it keeps whole, is read as two here.
function Get-ShortHelpLine {
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [AllowEmptyString()] [string[]] $Lines,
        [Parameter(Mandatory)] [int] $Limit)
    $word = '^(?:(`+)(?:(?!\1).)*?\1|<!--.*?-->|\[[^\]]*\]\([^)]*\)|\S)+'
    foreach ($p in Get-HelpParagraph -Lines $Lines) {
        for ($k = $p.Start; $k -lt $p.End; $k++) {
            $first = [regex]::Match($Lines[$k + 1].Substring($p.Rest.Length), $word).Value
            if ($Lines[$k].TrimEnd().Length + 1 + $first.Length -le $Limit) { $k + 1 }
        }
    }
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
