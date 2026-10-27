#Requires -Version 7
<#
    The one rule for the breaking commits in a pin move's range (grado-factorio-tools#255):
    pin-measure.ps1 loads it to write breaking.txt, and grado-factorio-modpack's mentions.ps1 is
    to load it from its submodule. Dot-source it; it has no -SelfTest of its own: pin-measure.ps1's
    holds both functions.

    THE RULE. A commit is a breaking commit when its subject has a `!` before its first colon, or
    its body has a line starting `BREAKING CHANGE:` or `BREAKING-CHANGE:`, in upper case. Its
    footer runs from that line to the next blank line or the next trailer line, a line starting
    `<Token>: ` as `Co-Authored-By: ` does, which is not part of it. A body with two such lines
    has both footers, in order.

    Get-BreakingCommit -Repo <path> -Old <commit> -New <commit> returns, for each breaking commit
    in Old..New and then each in New..Old, one object with four keys:
    - Hash: the short hash, as git log's %h prints it;
    - Subject: the subject line;
    - Footer: the footer's lines joined with a newline, or '' where there is none;
    - Dropped: $false for a commit in Old..New, $true for one in New..Old, which a pin moved back
      undoes.
    Each half is in git log's order, newest first. A pin moved forward has no dropped commit; a
    pin moved back has nothing in Old..New. It throws when git cannot read the range.

    Format-BreakingCommit turns that list into lines of text, for breaking.txt:

        breaking: 1a2b3c4 ✨ feat(pin-measure)!: write the list by the library
            BREAKING CHANGE: breaking.txt holds the library's text.
        breaking, dropped: 5d6e7f8 🐛 fix(pack)!: refuse a missing info.json
            (no BREAKING CHANGE: footer)

    and `none` for an empty list.

    WHAT IT CANNOT SEE. What a commit breaks: it reads what a commit says of itself, whatever
    commit-check.ps1 let through, so a breaking change written as neither `!` nor a footer is not
    listed, and a `!` on a change that breaks nothing is. And a footer written in lower case,
    which the rule does not read.
#>

# Each breaking commit of $Repo in $Range, as Get-BreakingCommit returns it, with $Dropped.
function Get-BreakingCommitIn {
    param([string] $Repo, [string] $Range, [bool] $Dropped)
    # git writes UTF-8, which the console's own code page would mangle in a subject's emoji.
    $was = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
        $raw = @(git -C $Repo log --format='%h%x1f%s%x1f%b%x1e' $Range 2>&1)
    }
    finally { [Console]::OutputEncoding = $was }
    if ($LASTEXITCODE) { throw "git could not read the range ${Range} of ${Repo}: $($raw -join ' ')" }
    foreach ($c in ($raw -join "`n") -split "\x1e") {
        $f = $c.Trim("`n") -split "\x1f"
        if ($f.Count -lt 3) { continue }
        $footer = [Collections.Generic.List[string]]::new()
        $in = $false
        foreach ($line in ($f[2] -replace "`r") -split "`n") {
            if ($line -cmatch '^BREAKING[ -]CHANGE:') { $in = $true }
            elseif ($line -notmatch '\S' -or $line -match '^[A-Za-z][A-Za-z0-9-]*: ') { $in = $false }
            if ($in) { $footer.Add($line) }
        }
        if ($f[1] -match '^[^:]*!:' -or $footer.Count) {
            [pscustomobject] @{ Hash = $f[0]; Subject = $f[1]; Footer = $footer -join "`n"; Dropped = $Dropped }
        }
    }
}

# The breaking commits a pin move from $Old to $New brings in, then those it drops: see the header.
function Get-BreakingCommit {
    param([Parameter(Mandatory)] [string] $Repo, [Parameter(Mandatory)] [string] $Old, [Parameter(Mandatory)] [string] $New)
    Get-BreakingCommitIn -Repo $Repo -Range "$Old..$New" -Dropped $false
    Get-BreakingCommitIn -Repo $Repo -Range "$New..$Old" -Dropped $true
}

# The lines of text for $Commit, Get-BreakingCommit's list: see the header.
function Format-BreakingCommit {
    param([AllowEmptyCollection()] [object[]] $Commit = @())
    if (-not $Commit) { return 'none' }
    foreach ($b in $Commit) {
        "breaking$(if ($b.Dropped) { ', dropped' }): $($b.Hash) $($b.Subject)"
        if ($b.Footer) { $b.Footer -split "`n" | ForEach-Object { "    $_" } }
        else { '    (no BREAKING CHANGE: footer)' }
    }
}
