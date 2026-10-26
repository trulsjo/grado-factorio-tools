#Requires -Version 7
<#
    The width rule for a script's comment and header lines, which check.ps1 and the pre-commit
    hook both load, so the rule they hold a script to is one (grado-factorio-tools#225). A line
    of a block comment, or one that begins with #, over the limit fails; a help block's .EXAMPLE
    section and a line of one word after its indent and comment marker are exempt. Moved out of
    check.ps1 unchanged, Get-LongCommentLine's rule and its exemptions with it; what the rule
    cannot see is in check.ps1's header, under A COMMENT OR HEADER LINE. The limit is the
    caller's: check.ps1 holds it, and the hook reads it from there.

    Invoke-StagedCommentCheck reads the staged scripts/*.ps1, as the commit will commit them,
    from the index git hands the hook. It cannot see a script outside scripts/, which check.ps1
    does not read either, nor an edit not staged. Dot-source it; it has no -SelfTest of its own:
    check.ps1's holds both functions.
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

# Each staged scripts/*.ps1 of the repository at $Root held to Get-LongCommentLine, read from the
# index: written out by checkout-index, byte for byte, into a scratch directory, so the working
# tree is neither read nor touched. Prints a line for each script that fails and one that sums
# up, and returns the exit code: 1 when one failed, 0 otherwise, a commit staging none included.
function Invoke-StagedCommentCheck {
    param([Parameter(Mandatory)] [string] $Root, [Parameter(Mandatory)] [int] $Limit)
    $staged = @("$(git -C $Root diff --cached --name-only --diff-filter=ACMR -z -- ':(glob)scripts/*.ps1')".Split("`0") | Where-Object { $_ })
    if ($LASTEXITCODE) { throw "git could not list the staged scripts of $Root." }
    if (-not $staged) { Write-Host 'OK - comment-line check: no script is staged, so none was read.'; return 0 }
    $scratch = Join-Path ([IO.Path]::GetTempPath()) "staged-comments-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    try {
        git -C $Root checkout-index "--prefix=$scratch/" -- @staged
        if ($LASTEXITCODE) { throw "git could not write the staged scripts of $Root out." }
        $failed = foreach ($path in $staged) {
            $long = @(Get-LongCommentLine -Path (Join-Path $scratch $path) -Limit $Limit)
            if ($long) { "$path has comment lines over $Limit characters, line $($long -join ', ')" }
        }
    }
    finally { Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue }
    if ($failed) { Write-Host "FAILED - comment-line check, as staged: $($failed -join '; ')."; return 1 }
    Write-Host "OK - comment-line check: $($staged.Count) staged script(s), no comment line over $Limit."
    0
}
