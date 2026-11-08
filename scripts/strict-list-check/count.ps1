# Fixture for strict-list-check.ps1: .Count reads. Each line strict-list-check.ps1 must flag ends in
# "expect: flag"; every other read must pass. Its self-test also runs this file under strict mode,
# with each read caught, and requires the flagged reads, and only those, to throw: a line marked
# "known false hit" or "known miss" is where the check and PowerShell are known to disagree.
Set-StrictMode -Version Latest
function Get-None { }

$bare = Get-None
$bare.Count                                         # expect: flag
(Get-None | Where-Object { $_ }).Count              # expect: flag
"$((Get-None).Count)"                               # expect: flag
$(Get-None).Count                                   # expect: flag
((Get-None)).Count                                  # expect: flag
([array](Get-None)).Count                           # expect: flag

$wrapped = @(Get-None)
$wrapped.Count
@(Get-None).Count

# A type constraint or cast does not wrap: an empty result stays $null.
[string[]] $typed = Get-None
$typed.Count                                        # expect: flag
$cast = [array](Get-None)
$cast.Count                                         # expect: flag
$paren = (Get-None)
$paren.Count                                        # expect: flag
$sub = $(Get-None)
$sub.Count                                          # expect: flag

# A copy takes the state of what it copies.
$copy = $bare
$copy.Count                                         # expect: flag
$copyWrapped = $wrapped
$copyWrapped.Count

# Rewrapped before the read.
$re = Get-None
$re = @($re)
$re.Count

# += keeps the state the variable had.
$grown = Get-None
$grown += 1
$grown.Count                                        # expect: flag
$list = @()
$list += Get-None
$list.Count

# Several variables from one command; a later value no command produced clears them.
$first, $rest = Get-None
$rest.Count                                         # expect: flag
$one, $two = Get-None
$one, $two = @(1), @(2)
$one.Count

# A statement used as a value is unrolled, even with @() in every branch.
$loop = foreach ($i in @(1)) { $i }
$loop.Count                                         # expect: flag
$branch = if ($true) { @() } else { @(1) }
$branch.Count                                       # expect: flag
# Each branch emits an array as one object.
$whole = if ($true) { , @(1) } else { , @(2) }
$whole.Count                                        # expect: flag  # known false hit

# Round a loop: the bare assignment reaches the read on the next pass.
$carried = @()
foreach ($i in 1..2) {
    $carried.Count                                  # expect: flag
    $carried = Get-None
}
# Unless an assignment earlier in the same loop comes first.
foreach ($i in 1..2) {
    $fresh = @(Get-None)
    $fresh.Count
    $fresh = Get-None
}

$literal = 1..3
$literal.Count
@(1) | ForEach-Object { $_.Count }                  # known miss: $_ is not followed

function Get-Inner {
    $bare.Count                                     # known miss: assigned in another function
    $inner = Get-None
    $inner.Count                                    # expect: flag
}
Get-Inner

# An assignment inside the read.
($inline = Get-None).Count                          # known miss

# A scope prefix names the same variable as the plain name.
$local:prefixed = Get-None
$prefixed.Count                                     # expect: flag

# A typed variable in a list of targets is still set: past the first, it can be $null.
$firstOf, [object] $secondOf = Get-Item .
$secondOf.Count                                     # expect: flag
