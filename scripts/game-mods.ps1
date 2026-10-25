<#  The game's own mods, which come with the build rather than the portal, and how a name is
    matched against them. Dot-sourced by resolve-modpack.ps1 and by grado-factorio-modpack's
    stage-pack.ps1, so the list and its case rule have one home (grado-factorio-modpack#99).

    Five game mods on 2.1. `recycler` is new in 2.1.0, which moved the `recycling` recipe category
    into it, and space-age depends on it (data/space-age/info.json, 2.1.23). A 2.0 build has no
    `recycler`; main supports 2.1 only (#209).

    Matched in exact case, measured for all five game mods as well as for an ordinary one. Factorio
    2.0.77 (build 84539), headless, fails a dependency on `Alpha` when only `alpha` is present
    (grado-factorio-tools 607ceef), and on each of the four 2.0 game mods in another case
    (grado-factorio-tools#46, for #44). Factorio 2.1.23 (build 87750) fails one on `Recycler`
    (#209). What the game logged, and how to repeat the run, is in docs/measurements.md.  #>

$GAME_MODS = @('base', 'space-age', 'quality', 'elevated-rails', 'recycler')

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
