<#  The game's own mods, which come with the build rather than the portal, and how a name is
    matched against them. Dot-sourced by resolve-modpack.ps1 and by grado-factorio-modpack's
    stage-pack.ps1, so the list and its case rule have one home (grado-factorio-modpack#99).

    Matched in exact case, as the game does: Factorio 2.0.77 (build 84539), measured headless in
    grado-factorio-tools 607ceef, fails a dependency on `Alpha` when only `alpha` is present.  #>

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
