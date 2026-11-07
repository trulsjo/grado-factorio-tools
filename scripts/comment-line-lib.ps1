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

    Dot-source it; it has no -SelfTest of its own: check.ps1's holds Get-LongCommentLine, and
    comment-line-check.ps1's holds Get-LongHashLine.
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
