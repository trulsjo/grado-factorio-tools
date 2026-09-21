<#
.SYNOPSIS
    Checks a commit message against the format CLAUDE.md lays down: gitmoji, Conventional Commits,
    a subject of 72 characters or fewer, and a body wrapped at 72.

.DESCRIPTION
    A GATE, and the only one here that reads a commit message. It starts no game and touches no
    prototype, so it belongs with ship-check.ps1 and locale-check.ps1 rather than with the checks
    that build a map -- and like ship-check it exists because the thing it reads is prose that
    every other gate is blind to.

    WHY IT EXISTS. CLAUDE.md has said "Wrap at 72" since the repository started, and nothing was
    reading it. Measured by this script against the last fifty commits on main, 2026-09-06:
    21 of the 50 are rejected, on 183 body lines over 72 and 5 subject lines over 72 -- the
    longest subject being 82 characters. The argument reached for at review time was that a rule
    main breaks this widely must not really apply. That is backwards: a rule nothing enforces is a
    rule that rots, and the fix is the enforcement rather than the excuse.

    A FIRST COUNT OF THIS SAID 201 LINES IN EVERY ONE OF THE FIFTY, and it was wrong in the
    direction that flatters the finding. It was an awk one-liner over `git log`, and it charged
    every `Co-Authored-By:` and every session URL to the rule -- lines this script exempts on
    purpose and git would corrupt if they wrapped. The real number is smaller and it is still 21
    commits in 50. Stated because a gate whose own justification is unmeasured is the thing it
    exists to prevent.

    WHAT IT CHECKS, and every rule here is quoted from CLAUDE.md's "Commit messages" section:

      subject   <emoji> <type>(<scope>): <subject>, with the RENDERED emoji rather than a
                :shortcode:. Imperative mood is not checkable and is not checked.
      pairing   The ten types each have one emoji, and the emoji has to be the type's own. This is
                the rule that catches a real one in history: bf44099 is `docs fix(repo)`.
      case      Lowercase after the colon. Held perfectly in 300 commits, so it is safe to enforce.
      stop      No trailing period.
      length    The whole subject line, 72 characters or fewer.
      breaking  A `!` before the colon requires a `BREAKING CHANGE:` footer. All seven breaking
                commits in history carry one, so this too is safe to enforce.
      blank     A blank line between the subject and the body.
      wrap      Every body line, 72 characters or fewer.

    WHAT IT DELIBERATELY LETS THROUGH:

      - TRAILERS. `Co-Authored-By:` and `Claude-Session:` end in a URL or an address that cannot be
        broken, and git parses that block by position. Wrapping them would corrupt them.
      - A LINE WHOSE LONGEST WORD IS ITSELF OVER THE LIMIT. No wrapping makes such a line fit, so
        flagging it would only teach people to ignore the gate. A bare long URL in a body is the
        real case.
      - fixup!, squash! and amend! subjects, which git rewrites away on rebase.
      - Auto-generated `Merge ...` and `Revert "..."` subjects, which git writes rather than a
        person. The repository's OWN merges are written by hand as `🔀 chore(repo): merge ...` and
        are checked like anything else.

    ON 🔀. CLAUDE.md's table does not list it and this script accepts it, because the repository has
    used it for merge commits eight times and a gate that failed those would be asserting a rule
    nobody agreed to. It is accepted the way the other situational emoji are -- with any type --
    rather than given a row of its own. If that is wrong, the fix is one line in $SITUATIONAL and a
    row in CLAUDE.md, and it should be CLAUDE.md first.

.PARAMETER Path
    The file holding the message to check. This is what git passes a `commit-msg` hook. Comment
    lines and everything below a scissors line are stripped first, the same as git does.

.PARAMETER Range
    Check the messages of every commit in a revision range instead of a file, e.g. `-Range
    origin/main..HEAD` before opening a pull request, or `-Range '-50 main'` to sweep recent
    history. Split on spaces and passed to `git rev-list`, so anything that takes is a range.
    Reports every commit that fails and exits non-zero if any did.

.PARAMETER SelfTest
    Prove the checker can FAIL. A gate that only ever passes is a gate that has stopped reading, so
    this runs a table of messages that must each be rejected for a named reason, and a table that
    must be accepted. It starts nothing and takes about a second.

.EXAMPLE
    pwsh -File scripts/commit-check.ps1 .git/COMMIT_EDITMSG

.EXAMPLE
    pwsh -File scripts/commit-check.ps1 -Range origin/main..HEAD

.EXAMPLE
    pwsh -File scripts/commit-check.ps1 -Range '-50 main'

.EXAMPLE
    pwsh -File scripts/commit-check.ps1 -SelfTest
#>

#Requires -Version 7
[CmdletBinding(DefaultParameterSetName = 'File')]
param(
    [Parameter(ParameterSetName = 'File', Position = 0)] [string] $Path,
    [Parameter(ParameterSetName = 'Range', Mandatory)]   [string] $Range,
    [Parameter(ParameterSetName = 'SelfTest', Mandatory)] [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'

# EVERY RULE HERE IS ABOUT AN EMOJI, so how the console decodes git's output is not a detail. On
# Windows PowerShell decodes a native command's stdout with [Console]::OutputEncoding, which is a
# legacy code page unless something says otherwise -- and `git log` then hands back a subject whose
# emoji has become a question mark, which fails the very first test for every commit ever written.
# -Range reported exactly that against real history before this line existed.
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$OutputEncoding = [Text.Encoding]::UTF8

# The width every rule here is about. One number, named once, because CLAUDE.md states it once.
$LIMIT = 72

# CLAUDE.md's table, type by type. The emoji is the rendered character, which is the rule as much
# as the pairing is -- a :shortcode: fails the emoji test below rather than passing quietly.
$TYPES = [ordered]@{
    feat = '✨'; fix = '🐛'; docs = '📝'; refactor = '♻️'; perf = '⚡️'
    test = '✅'; build = '📦'; chore = '🔧'; style = '🎨'; revert = '⏪️'
}

# "A few situational ones worth knowing", which CLAUDE.md lists without binding to a type -- so
# they are accepted with any type. 🔀 is the one addition; see ON 🔀 above.
$SITUATIONAL = @('🎉', '🚚', '🔥', '🌐', '💄', '🚧', '🔀')

# ♻️, ⚡️ and ⏪️ carry a variation selector (U+FE0F) and are also legible without one. Comparing
# with it stripped accepts both spellings and is why this is a function rather than an -eq.
function Normalise([string] $s) { $s -replace "`u{FE0F}", '' }

# CHARACTERS, NOT BYTES AND NOT UTF-16 CODE UNITS. The unit is what a reader sees on the line --
# one grapheme, one character -- because that is what "72 characters" means to the person wrapping
# a paragraph, and because a rule about width should not charge more for an emoji than for a word.
#
# Every other candidate is wrong here, and by a lot:
#
#            bytes (UTF-8)   UTF-16 units   characters
#     🐛                 4              2            1
#     ♻️                 6              2            1
#     🇳🇴                 8              4            1
#
# So `.Length` -- PowerShell's default and the obvious thing to reach for -- charges two for every
# gitmoji, and a byte count charges four to eight. A legal 72-character subject would read as 73
# under the first and about 250 under the second. The self-test pins this with a subject that is
# exactly 72 characters and 252 bytes.
function Width([string] $s) {
    [System.Globalization.StringInfo]::new((Normalise $s)).LengthInTextElements
}

# The message with the parts git itself discards: comment lines, and everything below a scissors
# line. Without this the hook measures the instructions git wrote, not what the author typed.
function Get-MessageLines([string[]] $raw) {
    $kept = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $raw) {
        if ($line -match '^#\s*-+\s*>8\s*-+') { break }
        if ($line.StartsWith('#')) { continue }
        $kept.Add($line.TrimEnd())
    }
    while ($kept.Count -and $kept[$kept.Count - 1] -eq '') { $kept.RemoveAt($kept.Count - 1) }
    return , $kept.ToArray()
}

# Is `line` part of the trailing block of `Key: value` footers? Exempt from the wrap rule.
#
# Position matters and is the whole reason this walks backwards from the end: "Note: this is a
# sentence" in the middle of a body is prose and has to wrap, while `Co-Authored-By:` at the
# bottom is a field git parses and must not be touched.
function Get-TrailerStart([string[]] $lines) {
    $i = $lines.Count
    while ($i -gt 0) {
        $line = $lines[$i - 1]
        if ($line -eq '') { break }
        if ($line -notmatch '^(BREAKING CHANGE|[A-Za-z][A-Za-z0-9-]*): ') { break }
        $i--
    }
    return $i
}

# Could this line be wrapped to fit at all? A line carrying one unbreakable token longer than the
# limit -- a URL, usually -- cannot, and failing it would only teach people to ignore the gate.
function Test-Wrappable([string] $line) {
    $longest = 0
    foreach ($word in ($line -split '\s+')) {
        $w = Width $word
        if ($w -gt $longest) { $longest = $w }
    }
    return $longest -le $LIMIT
}

<#
.SYNOPSIS
    Every rule broken by one message, as a list of sentences. An empty list means it passes.
#>
function Test-CommitMessage([string[]] $raw) {
    $bad   = [System.Collections.Generic.List[string]]::new()
    $lines = Get-MessageLines $raw

    if (-not $lines.Count) {
        $bad.Add('the message is empty')
        return , $bad.ToArray()
    }

    $subject = $lines[0]

    # Git writes these, not a person, and rebase rewrites the first three away.
    if ($subject -match '^(fixup|squash|amend)! ' -or
        $subject -match '^Merge ' -or $subject -match '^Revert "') {
        return , @()
    }

    # ------------------------------------------------------------------------------- the subject
    $emoji = ($subject -split ' ', 2)[0]
    $known = @($TYPES.Values) + $SITUATIONAL
    $isKnown = (Normalise $emoji) -in ($known | ForEach-Object { Normalise $_ })

    if (-not $isKnown) {
        $bad.Add(("the subject must start with a rendered gitmoji and a space, and '$emoji' is not " +
            "one of them: $($known -join ' ')"))
    }

    $rest = if ($subject -match '^\S+ (?<r>.*)$') { $Matches.r } else { '' }
    if ($rest -notmatch '^(?<type>[a-z]+)(\((?<scope>[^()]+)\))?(?<bang>!)?: (?<subject>.+)$') {
        $bad.Add('the subject must read "<emoji> <type>(<scope>): <subject>", with the scope optional')
    } else {
        $type = $Matches.type
        $bang = [bool]$Matches.bang
        $text = $Matches.subject

        if (-not $TYPES.Contains($type)) {
            $bad.Add("'$type' is not one of the types CLAUDE.md lists: $($TYPES.Keys -join ', ')")
        } elseif ($isKnown -and (Normalise $emoji) -notin ($SITUATIONAL | ForEach-Object { Normalise $_ }) -and
                  (Normalise $emoji) -ne (Normalise $TYPES[$type])) {
            $bad.Add("$type takes $($TYPES[$type]), not $emoji")
        }

        if ($text -cmatch '^[A-Z]') { $bad.Add("lowercase after the colon: '$text'") }
        if ($text.EndsWith('.'))    { $bad.Add('no trailing period on the subject') }

        if ($bang -and -not ($lines | Where-Object { $_ -match '^BREAKING CHANGE: ' })) {
            $bad.Add('a "!" before the colon needs a "BREAKING CHANGE:" footer explaining the migration')
        }
    }

    $width = Width $subject
    if ($width -gt $LIMIT) {
        $bad.Add("the subject is $width characters and the limit is $LIMIT")
    }

    # ---------------------------------------------------------------------------------- the body
    if ($lines.Count -ge 2 -and $lines[1] -ne '') {
        $bad.Add('put a blank line between the subject and the body')
    }

    $trailerStart = Get-TrailerStart $lines
    for ($i = 1; $i -lt $trailerStart; $i++) {
        $line  = $lines[$i]
        $width = Width $line
        if ($width -le $LIMIT) { continue }
        if (-not (Test-Wrappable $line)) { continue }
        $bad.Add("body line $($i + 1) is $width characters and the limit is ${LIMIT}: $line")
    }

    return , $bad.ToArray()
}

# ------------------------------------------------------------------------------------- self-test
#
# A gate that cannot fail is a gate that has stopped reading. Each rejected case names the rule it
# must trip on, so a rewrite that still fails but for the WRONG reason is caught too -- which is
# the failure this kind of table usually misses.
if ($SelfTest) {
    $trailer = "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
    $long    = 'x' * 80

    # THE UNIT, pinned on both sides of the boundary. '🐛 fix(repo): ' is 13 characters, so these
    # are exactly 72 and exactly 73 -- while being 252 and 256 BYTES, and 132 and 134 UTF-16 code
    # units. Anything that measured bytes or `.Length` would reject the legal one out of hand.
    $head  = '🐛 fix(repo): '
    $exact = $head + ('🐛' * 59)
    $over  = $head + ('🐛' * 60)

    $url     = 'https://example.invalid/' + ('y' * 70)

    $mustFail = @(
        @{ why = 'not one of them'; msg = @('fix(repo): no emoji at all') }
        @{ why = 'not one of them'; msg = @(':bug: fix(repo): a shortcode is not the character') }
        @{ why = 'takes 🐛';        msg = @('📝 fix(repo): the wrong emoji for the type') }
        @{ why = 'is not one of the types'; msg = @('✨ nope(repo): a type nobody lists') }
        @{ why = 'lowercase after the colon'; msg = @('🐛 fix(repo): Capital letter') }
        @{ why = 'no trailing period'; msg = @('🐛 fix(repo): a trailing period.') }
        @{ why = 'the subject is';   msg = @("🐛 fix(repo): $('word ' * 15)") }
        @{ why = 'the subject is 73'; msg = @($over) }
        @{ why = 'BREAKING CHANGE';  msg = @('✨ feat(power)!: break a save', '', 'No footer here.') }
        @{ why = 'blank line';       msg = @('🐛 fix(repo): a subject', 'body with no blank line') }
        # Built from short words on purpose: a line made of ONE 80-character token is exempt by
        # design, and an earlier version of this case used $long twice and passed for that reason.
        @{ why = 'body line 3';      msg = @('🐛 fix(repo): a subject', '', ('wrappable ' * 12).Trim()) }
        @{ why = '<emoji> <type>';   msg = @('🐛 no colon in this subject') }
        @{ why = 'the message is empty'; msg = @('# just a comment', '') }
    )

    $mustPass = @(
        @{ msg = @('🐛 fix(repo): the plainest legal subject') }
        @{ msg = @($exact) }
        @{ msg = @('🐛 fix(repo): a body line of 72 characters is legal', '', ('🐛' * 72)) }
        @{ msg = @('♻️ refactor(repo): a variation selector on the emoji') }
        @{ msg = @('⚡️ perf(power): and another one') }
        @{ msg = @('💄 feat(graphics): a situational emoji takes any type') }
        @{ msg = @('🔀 chore(repo): merge something (#249)') }
        @{ msg = @('🐛 fix(repo): no scope is allowed') }
        @{ msg = @('✨ feat(power)!: break a save', '', 'Body.', '', 'BREAKING CHANGE: migrate thus.') }
        @{ msg = @('🐛 fix(repo): a trailer may run long', '', 'Body.', '', $trailer) }
        @{ msg = @('🐛 fix(repo): an unwrappable url is left alone', '', $url) }
        @{ msg = @('fixup! 🐛 fix(repo): git rewrites this away') }
        @{ msg = @('Merge branch ''main'' into topic') }
        @{ msg = @('🐛 fix(repo): comments and scissors are stripped', '',
                   'Body.', '# a comment', '# ------------------------ >8 ------------------------',
                   "diff --git $long") }
    )

    $checks = 0
    $failures = [System.Collections.Generic.List[string]]::new()

    foreach ($case in $mustFail) {
        $checks++
        $got = Test-CommitMessage $case.msg
        if (-not $got.Count) {
            $failures.Add("expected a failure mentioning '$($case.why)' and it passed: $($case.msg[0])")
        } elseif (-not ($got | Where-Object { $_ -like "*$($case.why)*" })) {
            $failures.Add(("expected a failure mentioning '$($case.why)' and got: " +
                ($got -join '; ')))
        }
    }

    foreach ($case in $mustPass) {
        $checks++
        $got = Test-CommitMessage $case.msg
        if ($got.Count) {
            $failures.Add("expected a pass and got: $($got -join '; ') -- for: $($case.msg[0])")
        }
    }

    # The floor, for the same reason ship-check carries one: this passes by finding nothing, so a
    # table that stopped being read would print green while checking nothing at all.
    $checks++
    if ($mustFail.Count -lt 13 -or $mustPass.Count -lt 14) {
        $failures.Add('the self-test tables shrank, so this proves much less than it claims')
    }

    if ($failures.Count) {
        Write-Host "commit-check -SelfTest: $checks checks, $($failures.Count) failure(s)."
        foreach ($f in $failures) { Write-Host "  - $f" }
        exit 1
    }
    Write-Host "commit-check -SelfTest: $checks checks, 0 failures."
    Write-Host 'Every rejected case was rejected for the reason it names, and every legal message passed.'
    exit 0
}

# ----------------------------------------------------------------------------------------- range
if ($PSCmdlet.ParameterSetName -eq 'Range') {
    # Split, because a range is often more than one token -- `-50 main` is two, and passing it as
    # one string makes git reject the whole thing as a single bad revision.
    $revArgs = @($Range -split '\s+' | Where-Object { $_ })
    $shas = @(& git rev-list @revArgs 2>$null)
    if ($LASTEXITCODE -ne 0) { throw "not a revision range: $Range" }
    if (-not $shas.Count) { Write-Host "commit-check: no commits in $Range."; exit 0 }

    $bad = 0
    foreach ($sha in $shas) {
        $raw = @(& git log -1 --format=%B $sha) -join "`n" -split "`n"
        $problems = Test-CommitMessage $raw
        if ($problems.Count) {
            $bad++
            $subject = (& git log -1 --format=%s $sha)
            Write-Host "$($sha.Substring(0, 7)) $subject"
            foreach ($p in $problems) { Write-Host "  - $p" }
        }
    }

    Write-Host "commit-check: $($shas.Count) commit(s) in $Range, $bad rejected."
    exit ($bad ? 1 : 0)
}

# ------------------------------------------------------------------------------------------ file
if (-not $Path) { throw 'give a message file to check, or -Range, or -SelfTest.' }
if (-not (Test-Path -LiteralPath $Path)) { throw "no such message file: $Path" }

$problems = Test-CommitMessage @(Get-Content -LiteralPath $Path -Encoding utf8)
if ($problems.Count) {
    Write-Host ''
    Write-Host 'This commit message does not match the format in CLAUDE.md:'
    foreach ($p in $problems) { Write-Host "  - $p" }
    Write-Host ''
    Write-Host '  <emoji> <type>(<scope>): <subject>      subject and body both wrap at 72'
    Write-Host '  feat ✨  fix 🐛  docs 📝  refactor ♻️  perf ⚡️  test ✅'
    Write-Host '  build 📦  chore 🔧  style 🎨  revert ⏪️'
    Write-Host ''
    Write-Host 'The message is kept, so `git commit -e -F .git/COMMIT_EDITMSG` reopens it.'
    exit 1
}
exit 0
