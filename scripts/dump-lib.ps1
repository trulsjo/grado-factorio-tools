<#
.SYNOPSIS
    What the dump-*.ps1 scripts share: reading a --dump-data dump one prototype type at a time,
    comparing two prototypes, and printing a Markdown table. Dot-sourced; it runs nothing.

.DESCRIPTION
    A DUMP IS NOT READ WHOLE (grado-factorio-modpack#139). The dump of an overhaul pack is about
    160 MB, most of it graphics, and ConvertFrom-Json took 40 seconds and 2 GB to read one
    (measured 2026-10-12, Grado_ABCS on 2.0.77, pwsh 7.6.6). Open-Dump indexes the file with
    System.Text.Json, and Get-DumpTable converts one prototype type to hashtables when a script
    asks for it.

    WHAT IT CANNOT SEE. Anything the dump does not hold: which mod made a prototype, and
    anything a mod does at run time. A dump is data.raw after the last data stage.
#>

Set-StrictMode -Version Latest

function Open-Dump {
    <#  The dump at $Path as a JsonDocument. Its root is data.raw: type, then name.  #>
    param([Parameter(Mandatory)] [string] $Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "There is no dump at $Path." }
    $options = [System.Text.Json.JsonDocumentOptions]::new()
    $options.MaxDepth = 512
    $stream = [IO.File]::OpenRead((Convert-Path -LiteralPath $Path))
    try { [System.Text.Json.JsonDocument]::Parse($stream, $options) } finally { $stream.Dispose() }
}

function Get-DumpTable {
    <#  Every prototype of the named types as one hashtable, name to prototype. A type the dump
        does not have gives nothing. Two types sharing a name keep the first: ask for one type at
        a time where that matters.  #>
    param([Parameter(Mandatory)] [System.Text.Json.JsonDocument] $Dump, [Parameter(Mandatory)] [string[]] $Type)
    $table = @{}
    foreach ($t in $Type) {
        $element = [System.Text.Json.JsonElement]::new()
        if (-not $Dump.RootElement.TryGetProperty($t, [ref] $element)) { continue }
        $read = $element.GetRawText() | ConvertFrom-Json -AsHashtable -Depth 200
        foreach ($name in $read.Keys) { if (-not $table.ContainsKey($name)) { $table[$name] = $read[$name] } }
    }
    , $table
}

function Get-DumpTypes {
    <#  The prototype types in the dump, or those in which some prototype has $WithProperty.  #>
    param([Parameter(Mandatory)] [System.Text.Json.JsonDocument] $Dump, [string] $WithProperty)
    $ignored = [System.Text.Json.JsonElement]::new()
    foreach ($type in $Dump.RootElement.EnumerateObject()) {
        if (-not $WithProperty) { $type.Name; continue }
        foreach ($prototype in $type.Value.EnumerateObject()) {
            if ($prototype.Value.TryGetProperty($WithProperty, [ref] $ignored)) { $type.Name; break }
        }
    }
}

function Get-DumpIndex {
    <#  Every prototype's JSON text, as type, then name. Text and not tables, so that two dumps
        are compared without converting what is the same in both.  #>
    param([Parameter(Mandatory)] [System.Text.Json.JsonDocument] $Dump)
    $index = @{}
    foreach ($type in $Dump.RootElement.EnumerateObject()) {
        $names = [Collections.Generic.Dictionary[string, System.Text.Json.JsonElement]]::new([StringComparer]::Ordinal)
        foreach ($prototype in $type.Value.EnumerateObject()) { $names[$prototype.Name] = $prototype.Value }
        $index[$type.Name] = $names
    }
    , $index
}

function ConvertFrom-DumpElement {
    <#  One indexed prototype as a hashtable.  #>
    param([Parameter(Mandatory)] [System.Text.Json.JsonElement] $Element)
    $Element.GetRawText() | ConvertFrom-Json -AsHashtable -Depth 200
}

function Find-DumpPrototype {
    <#  Every prototype named $Name, whatever its type, as hashtables. Names are unique within a
        type and not across them: an item and its entity share one.  #>
    param([Parameter(Mandatory)] [System.Text.Json.JsonDocument] $Dump, [Parameter(Mandatory)] [string] $Name)
    $found = [System.Text.Json.JsonElement]::new()
    foreach ($type in $Dump.RootElement.EnumerateObject()) {
        if ($type.Value.TryGetProperty($Name, [ref] $found)) { $found.GetRawText() | ConvertFrom-Json -AsHashtable -Depth 200 }
    }
}

function ConvertTo-CanonicalText {
    <#  A value as text with every table's keys in ordinal order, so two prototypes are the same
        when their texts are. A number is written as .NET round-trips it.  #>
    param($Value)
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [Collections.IDictionary]) {
        $keys = [string[]] @($Value.Keys)
        [Array]::Sort($keys, [StringComparer]::Ordinal)
        return '{' + (@(foreach ($k in $keys) { "`"$k`":" + (ConvertTo-CanonicalText $Value[$k]) }) -join ',') + '}'
    }
    if ($Value -is [string]) { return '"' + $Value + '"' }
    if ($Value -is [Collections.IEnumerable]) { return '[' + (@(foreach ($v in $Value) { ConvertTo-CanonicalText $v }) -join ',') + ']' }
    if ($Value -is [bool]) { return "$Value".ToLowerInvariant() }
    ([IConvertible] $Value).ToString([cultureinfo]::InvariantCulture)
}

function Compare-Prototype {
    <#  The top-level fields in which two prototypes differ, sorted. Nothing when they are the
        same field for field.  #>
    param([Parameter(Mandatory)] [Collections.IDictionary] $Left, [Parameter(Mandatory)] [Collections.IDictionary] $Right)
    $fields = [string[]] @(@($Left.Keys) + @($Right.Keys) | Select-Object -Unique)
    [Array]::Sort($fields, [StringComparer]::Ordinal)
    foreach ($f in $fields) {
        if (-not ($Left.Contains($f) -and $Right.Contains($f)) -or
            (ConvertTo-CanonicalText $Left[$f]) -cne (ConvertTo-CanonicalText $Right[$f])) { $f }
    }
}

function Compare-DumpElement {
    <#  Compare-Prototype for two indexed prototypes, converting only the fields whose text
        differs.  #>
    param([Parameter(Mandatory)] [System.Text.Json.JsonElement] $Left, [Parameter(Mandatory)] [System.Text.Json.JsonElement] $Right)
    $fields = [Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
    $other = [System.Text.Json.JsonElement]::new()
    foreach ($p in $Left.EnumerateObject()) {
        if (-not $Right.TryGetProperty($p.Name, [ref] $other)) { [void] $fields.Add($p.Name); continue }
        $mine = $p.Value.GetRawText(); $theirs = $other.GetRawText()
        if ($mine -cne $theirs -and (ConvertTo-CanonicalText ($mine | ConvertFrom-Json -AsHashtable -Depth 200)) -cne (ConvertTo-CanonicalText ($theirs | ConvertFrom-Json -AsHashtable -Depth 200))) { [void] $fields.Add($p.Name) }
    }
    foreach ($p in $Right.EnumerateObject()) { if (-not $Left.TryGetProperty($p.Name, [ref] $other)) { [void] $fields.Add($p.Name) } }
    $fields
}

function Format-MarkdownTable {
    <#  A Markdown table, one line a row. A cell's own | is escaped.  #>
    param([Parameter(Mandatory)] [AllowEmptyString()] [string[]] $Header, [object[]] $Row = @())
    $line = { param($cells) '| ' + (@($cells | ForEach-Object { "$_" -replace '\|', '\|' }) -join ' | ') + ' |' }
    & $line $Header
    '|' + ('---|' * $Header.Count)
    foreach ($r in $Row) { & $line $r }
}

function Format-Names {
    <#  Names as the catalogue writes them: each in a code span, comma-separated, sorted.  #>
    param([string[]] $Name = @())
    $sorted = [string[]] @($Name)
    [Array]::Sort($sorted, [StringComparer]::Ordinal)
    (@($sorted | ForEach-Object { '`' + $_ + '`' }) -join ', ')
}

function Get-DumpLabel {
    <#  What a table calls a dump: its file's name as get-dump.ps1 gives it, less the checksum
        and the id, in a code span.  #>
    param([Parameter(Mandatory)] [string] $Path)
    '`' + ((Split-Path $Path -LeafBase) -replace '-\d+-[0-9a-f]{12}$') + '`'
}

function Format-Count {
    <#  A count as the catalogue writes one: 26,224.  #>
    param([Parameter(Mandatory)] [long] $Number)
    $Number.ToString('N0', [cultureinfo]::InvariantCulture)
}
