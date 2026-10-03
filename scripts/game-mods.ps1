<#  The game's own mods, which come with the build rather than the portal, and how a name is
    matched against them. Dot-sourced by resolve-modpack.ps1 and by grado-factorio-modpack's
    stage-pack.ps1, so the list and its case rule have one home (grado-factorio-modpack#99).

    Matched in exact case, measured for game mods as well as ordinary ones. Factorio 2.0.77 (build
    84539), headless, fails a dependency on `Alpha` when only `alpha` is present (grado-factorio-tools
    607ceef), and on the game's own mods the same way (grado-factorio-tools#44). A throwaway mod
    whose info.json declares only the dependency `Space-Age`, loaded through load-harness.ps1
    -With space-age, is refused with
        Failed to load mod "probe-spaceage": ... Missing required dependency Space-Age
    and `Base` and `Quality`, declared the same way, are refused the same way. A control declaring
    `space-age` in lower case, run the same way, loads.  #>

$GAME_MODS = @('base', 'space-age', 'quality', 'elevated-rails')

function Test-GameMod {
    <#  Whether a name is one of the game's mods, in exact case.  #>
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Name)
    $Name -cin $GAME_MODS
}

function Get-MiscasedGameMod {
    <#  The game mod a name spells in the wrong case, or nothing: `Space-Age` gives `space-age`,
        and `space-age` or `krastorio2` give nothing.  #>
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Name)
    $GAME_MODS | Where-Object { $_ -eq $Name -and $_ -cne $Name }
}
