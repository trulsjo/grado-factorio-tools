# Fixture for strict-list-check.ps1: .Id and .Name reads, which throw off $null and off an empty array
# alike, so @() does not make them safe. Lines to flag end in "expect: flag". The self-test also
# runs it under strict mode (see count.ps1).
Set-StrictMode -Version Latest
function Get-None { }

(Get-None).Name                                     # expect: flag
@(Get-None).Name                                    # expect: flag
@(Get-None).Id                                      # expect: flag
$wrapped = @(Get-None)
$wrapped.Name                                       # expect: flag
$wrapped.Count
$bare = Get-None
$bare.Id                                            # expect: flag
$first, $rest = @(Get-None)
$rest.Count                                         # expect: flag

# Rewrapped or added to an array: still an array that can be empty.
$re = Get-None
$re = @($re)
$re.Name                                            # expect: flag
$re.Count
@($bare).Name                                       # expect: flag
$list = @()
$list += Get-None
$list.Name                                          # expect: flag
$list.Count

# The fix: ForEach-Object gives nothing for nothing.
$names = @(Get-None | ForEach-Object Name)
$names.Count

# A statement that always outputs exactly one object, marked: safe for .Id and .Name, and still
# no .Count, since one object has none.
$proc = Start-Process pwsh -PassThru -NoNewWindow `
    -RedirectStandardOutput nul  # strict-lists: one
$proc.Id
$proc.Count                                         # expect: flag
(Get-Item .).Name  # strict-lists: one
@($proc).Name
@($proc).Count

# In $a, $b = ... only the first variable gets the one object.
$only, $none = Get-Item .  # strict-lists: one
$only.Name
$none.Name                                          # expect: flag

# Every branch gives a hashtable, yet a statement used as a value counts as bare.
$table = if ($true) { @{ Name = 'a' } } else { @{ Name = 'b' } }
$table.Name                                         # expect: flag  # known false hit
