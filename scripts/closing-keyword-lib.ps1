#Requires -Version 7
<#
    The one reading of a closing keyword before an issue reference (grado-factorio-tools#472):
    pr-body-check.ps1 loads it to report one in a pull request's body (#112), and commit-check.ps1
    to refuse one in a commit message. Dot-source it; it has no -SelfTest of its own: each of those
    two scripts' self-tests holds it.

    THE READING. Find-ClosingKeyword -Line <text> returns, as text, each place in the line where a
    closing keyword stands before an issue reference: the keyword in any case, then a colon or a
    space or both, then `#N`, `OWNER/REPOSITORY#N` or the address of an issue on github.com. A
    keyword that ends a longer or a hyphenated word, as `prefixes #3` or `auto-fix #6`, is not one.
    The nine keywords, the colon and the first two forms are those of
    https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/linking-a-pull-request-to-an-issue,
    read 2026-10-12 and again 2026-11-16, when the page also said that a closing keyword in a commit
    message closes the issue when the commit is merged into the default branch. This reads wider
    than the page shows: a space before the colon, and none after it. The address is not on the page
    and GitHub closes on it, by pr-body-check.ps1's header.

    WHAT IT CANNOT SEE. A keyword with its reference on the next line, or with markup or a link's
    bracket between the two, whether GitHub closes on those or not. A keyword GitHub adds after
    the date read.
#>

function Find-ClosingKeyword {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Line)
    foreach ($m in [regex]::Matches($Line, '(?<![0-9A-Za-z-])(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)(?:\s*:\s*|\s+)(?:(?:[\w.-]+/[\w.-]+)?#\d+|https://github\.com/[\w.-]+/[\w.-]+/issues/\d+)', 'IgnoreCase')) {
        $m.Value
    }
}
