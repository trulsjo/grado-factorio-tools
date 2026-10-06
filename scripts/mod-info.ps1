#Requires -Version 7
<#
    How a mod's info.json is read by the scripts here that refuse a bad one. Dot-sourced by
    pack-mods.ps1, load-harness-lib.ps1 and resolve-modpack.ps1, so a refusal has one wording and
    a defect in the reading is fixed once (grado-factorio-tools#59). Before it, each script parsed
    the file on its own and the same defect was ticketed once per script.

        . "$PSScriptRoot/mod-info.ps1"
        $info = Read-ModInfo -Text (Get-Content -LiteralPath $path -Raw) -Where $path

    It takes the text and not a path, because the harness reads an info.json out of a zip. -Where
    is what a refusal calls the file.

    WHAT IT REFUSES, AND WHY EACH.

      not JSON          A file cut off partway, say. The parser's own reason follows the name.
                        This reader's rule, not a measured game rule: without it a run stopped
                        with the parser's error alone, naming no mod.
      not an object     `null`, an empty file, or an array. This reader's rule too: there is no
                        `name` to read, and PowerShell would otherwise unroll a one-element array
                        holding an object and read that object as the info.json.
      a missing key     No `name` or no `version` key in exact case. The game's rule: Factorio
                        2.0.77 (build 84539) refuses a lone `"Name"` or `"Version"`. The run, and
                        how to repeat it, is in docs/measurements.md.
      a bad value       A `name` or `version` that is not a non-empty string: `null`, a number,
                        an object, `""`. This reader's rule, not a measured game rule: both go
                        into the name of a zip or a junction, and a blank or a number there names
                        a file after nothing the mod declared.

    WHAT IT READS, WHERE ConvertFrom-Json ALONE WOULD NOT. An empty key, which is legal JSON:
    fluid-connection-indicators 0.2.9's `package` table holds `"": ""`
    (grado-factorio-tools#38, and #40 for the packer). And a `"Name"` beside `name`, or a `"Version"` beside `version`:
    the lower-case key is read and the other ignored, which is how the game reads them -- the run
    is in docs/measurements.md.

    WHAT IT CANNOT SEE. It reads `name` and `version` and checks nothing else about them: not a
    version's format, not that the name matches the directory or zip the file came from, and a
    string of only spaces passes. A caller that needs more checks it itself, as pack-mods.ps1
    does. One string is refused that should not be: a value shaped like a date and time, such as
    "2020-01-01T00:00:00", which ConvertFrom-Json reads as a date and not a string.

    TWO READS DO NOT COME THROUGH HERE. fetch-mods.ps1's Get-ModVersion, whose header says why,
    and Get-BundledMods in load-harness-lib.ps1, which reads the game's own mods from its data
    directory and refuses nothing.

    `pwsh -File scripts/mod-info.ps1 -SelfTest` proves each refusal can happen, with no game and
    no network. Exit 0 means every case held. Dot-sourced, the self-test is not reachable.
#>

function Read-ModInfo {
    <#  A mod's info.json as a hashtable whose keys match case exactly, or a refusal naming -Where.  #>
    param(
        [Parameter(Mandatory)] [AllowNull()] [AllowEmptyString()] [string] $Text,
        [Parameter(Mandatory)] [string] $Where
    )

    try { $info = $Text | ConvertFrom-Json -AsHashtable -NoEnumerate }
    catch { throw "$Where is not JSON: $($_.Exception.Message)" }
    if ($info -isnot [System.Collections.IDictionary]) { throw "$Where is not a JSON object." }
    # Both keys before either value, so a missing key is never reported as a bad value.
    foreach ($key in 'name', 'version') {
        if (-not $info.ContainsKey($key)) { throw "$Where has no ""$key"" key, which the game requires; keys match case exactly." }
    }
    foreach ($key in 'name', 'version') {
        if ($info[$key] -isnot [string] -or -not $info[$key]) { throw "$Where has a ""$key"" that is not a non-empty string." }
    }
    $info
}

# Only when run as a script. Dot-sourced, InvocationName is '.', and a caller's own -SelfTest is
# not this one. No param block, because dot-sourcing one would overwrite the caller's $SelfTest.
if ($MyInvocation.InvocationName -ne '.' -and $args -contains '-SelfTest') {
    $ErrorActionPreference = 'Stop'
    $ok = '{"name":"m","version":"1.0.0"}'
    # Json is one text or several; Refusal is what each must be refused with, and Read is what
    # must hold of the hashtable when each is read.
    $cases = @(
        @{ Name = 'a file cut off partway is not JSON, and the parser''s reason follows the name'
           Json = '{"name":"m",'; Refusal = '^m/info\.json is not JSON: \S' }
        @{ Name = 'null, an empty file and an array are not a JSON object; nor is a one-element array holding an object'
           Json = 'null', '', '[1]', "[$ok]"; Refusal = '^m/info\.json is not a JSON object' }
        @{ Name = 'a lone "Name" is a missing name key, not an empty value'
           Json = '{"Name":"m","version":"1.0.0"}'; Refusal = '^m/info\.json has no "name" key' }
        @{ Name = 'a lone "Version" is a missing version key, not an empty value'
           Json = '{"name":"m","Version":"1.0.0"}'; Refusal = '^m/info\.json has no "version" key' }
        @{ Name = 'a name that is empty, null, a number or an object is refused by key'
           Json = '{"name":"","version":"1.0.0"}', '{"name":null,"version":"1.0.0"}', '{"name":5,"version":"1.0.0"}', '{"name":{"a":"b"},"version":"1.0.0"}'
           Refusal = '^m/info\.json has a "name" that is not a non-empty string' }
        @{ Name = 'a version that is empty, null or a number is refused by key'
           Json = '{"name":"m","version":""}', '{"name":"m","version":null}', '{"name":"m","version":1}'
           Refusal = '^m/info\.json has a "version" that is not a non-empty string' }
        @{ Name = 'an empty key is read'
           Json = '{"name":"m","version":"1.0.0","package":{"":""}}'; Read = { param($i) $i.name -ceq 'm' -and $i.package[''] -eq '' } }
        @{ Name = 'a "Name" beside name and a "Version" beside version are read from the lower-case keys, in either order'
           Json = '{"Name":"other","name":"m","Version":"9.9.9","version":"1.0.0"}', '{"name":"m","Name":"other","version":"1.0.0","Version":"9.9.9"}'
           Read = { param($i) $i.name -ceq 'm' -and $i.version -ceq '1.0.0' } }
    )

    $failures = 0
    $n = 0
    foreach ($c in $cases) {
        $n++
        $held = foreach ($json in $c.Json) {
            try { $info = Read-ModInfo -Text $json -Where 'm/info.json'; $said = '' } catch { $info = $null; $said = $_.Exception.Message }
            if ($c.Refusal) { $said -match $c.Refusal } else { -not $said -and (& $c.Read $info) }
        }
        $pass = -not ($held -contains $false)
        Write-Host ("self-test {0}/{1}: {2} -- {3}" -f $n, $cases.Count, $c.Name, $(if ($pass) { 'ok' } else { 'FAILED' }))
        if (-not $pass) { $failures++ }
    }
    Write-Host ''
    if ($failures) { Write-Host "FAILED - self-test: $failures of $($cases.Count) case(s) did not hold."; exit 1 }
    Write-Host "OK - self-test passed: all $($cases.Count) cases."
    exit 0
}
