# Fixture for strict-list-check.ps1: which assignments reach a read through branches and loops.
# Lines to flag end in "expect: flag". The self-test also runs it under strict mode (see count.ps1).
Set-StrictMode -Version Latest
function Get-None { }
$c = $true

# A safe assignment in one branch does not hide a bare one in the other.
if ($c) { $either = Get-None } else { $either = @() }
$either.Count                                       # expect: flag
if ($c) { $both = @(Get-None) } else { $both = @() }
$both.Count
$maybe = Get-None
if (-not $c) { $maybe = @() }
$maybe.Count                                        # expect: flag

# An assignment in one branch never reaches a read in another.
if (-not $c) { $apart = Get-None } else { $apart = @(); $apart.Count }

# Round a loop, the last assignment directly in the body after the read reaches it.
$carried = @()
foreach ($i in 1..2) {
    $carried.Count                                  # expect: flag
    $carried = Get-None
}
$rewrapped = @()
foreach ($i in 1..2) {
    $rewrapped.Count
    $rewrapped = Get-None
    $rewrapped = @($rewrapped)
}
$sometimes = @()
foreach ($i in 1..2) {
    $sometimes.Count                                # expect: flag
    $sometimes = Get-None
    if (-not $c) { $sometimes = @($sometimes) }
}

# An assignment before the read in the loop comes first only if it surely runs.
foreach ($i in 1..2) {
    $fresh = @(Get-None)
    $fresh.Count
    $fresh = Get-None
}
$nested = @()
foreach ($i in 1..2) {
    foreach ($j in @()) { $nested = @() }
    $nested.Count                                   # expect: flag
    $nested = Get-None
}
$skipped = @()
foreach ($i in 1..2) {
    if ($i -eq 99) { $skipped = @(Get-None) }
    $skipped.Count                                  # expect: flag
    $skipped = Get-None
}

# Inside a loop, another branch of an if can have run on an earlier pass.
$turns = @()
foreach ($i in 1..2) {
    if ($i -eq 1) { $turns = Get-None } else { $turns.Count }    # expect: flag
}

# A switch runs every clause that matches, and its clauses once per item.
$clauses = @()
switch -Regex ('ab') { 'a' { $clauses = Get-None } 'b' { $clauses.Count } }    # expect: flag
$items = @()
switch (1, 2) { default { $items.Count; $items = Get-None } }    # expect: flag

# A for loop's iterator runs after the body, and its initializer only once.
$stepped = Get-None
for ($i = 0; $i++ -lt 2; $stepped = @()) { $stepped.Count }    # expect: flag
$i = 0
for ($started = @(); $i -lt 2; $i++) {
    $started.Count                                  # expect: flag
    $started = Get-None
}

# A try block can stop anywhere, and a catch block may not run.
$tried = Get-None
try { throw 'stop'; $tried = @() } catch { $tried.Count } finally { $tried.Count }    # expect: flag 2

# An inline read follows a loop like a plain one.
$inLoop = @()
foreach ($i in 1..2) {
    ($inLoop).Count                                 # expect: flag
    $inLoop = Get-None
}

# Reassigned in every branch, yet the bare value still counts.
$everyBranch = Get-None
if ($c) { $everyBranch = @() } else { $everyBranch = @() }
$everyBranch.Count                                  # expect: flag  # known false hit

# A copy made in a loop of a variable assigned later in it.
$source = @()
foreach ($i in 1..2) {
    $copied = $source
    $copied.Count                                   # known miss
    $source = Get-None
}

# A script block that a command runs repeatedly is not a loop.
$piped = @()
1..2 | ForEach-Object { $piped.Count; $piped = Get-None }    # known miss

# An assignment in one branch never reaches a read in another, past a safe value before the if.
$apart2 = @()
if (-not $c) { $apart2 = Get-None } else { $apart2.Count }

# A catch block may not run, so it hides nothing from the finally block.
$late = Get-None
try { $null = 1 } catch { $late = @() } finally { $late.Count }    # expect: flag

# A try or a switch used as a value is unrolled, as an if is.
$triedValue = try { Get-None } catch { }
$triedValue.Count                                   # expect: flag
$switched = switch (1) { 2 { 'x' } }
$switched.Count                                     # expect: flag

# The right side of || may not run.
$chained = Get-None
$true || ($chained = @())
$chained.Count                                      # expect: flag

# A trap's body runs only on an error.
function Test-Trap {
    $trapped = Get-None
    trap { $trapped = @(); continue }
    $trapped.Count                                  # expect: flag
}
Test-Trap

# A script block may not run, as ForEach-Object's does not when nothing is piped in.
$blocked = Get-None
Get-None | ForEach-Object { $blocked = @() }
$blocked.Count                                      # expect: flag

# A switch clause may not run, so it hides nothing after the switch.
$switchSet = Get-None
switch (1) { 2 { $switchSet = @() } }
$switchSet.Count                                    # expect: flag

# A try block may stop before an assignment in it.
$trySet = Get-None
try { throw 'skip'; $trySet = @() } catch { }
$trySet.Count                                       # expect: flag

# One switch clause does not run before another on the same item.
$clauseSet = Get-None
switch (2) { 1 { $clauseSet = @() } 2 { $clauseSet.Count } }    # expect: flag
