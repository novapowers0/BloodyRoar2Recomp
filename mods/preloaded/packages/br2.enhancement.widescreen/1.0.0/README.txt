Bloody Roar II Widescreen
=========================

From-scratch widescreen for Bloody Roar II (Europe SLES-01722 / USA
SCUS-94424), built on the psxrecomp widescreen framework carried by
NovaPowers and following the ApeEscapeRecomp / Tomba methodology (mstan).

Unlike a RAM/GPU projection patch (DuckStation's `0x1333` write), this mod
uses the framework's GTE X-squash + present-stretch path, which:

  - applies uniformly to generated code, the interpreter and overlay DLLs;
  - keeps the game's post-projection screen-bounds culls aligned with the
    visible frame (the cull sites are widened at codegen time from
    game.toml [widescreen.cull]); and
  - pillarboxes 2D menus/FMV (gte_game_mode), so only 3D fights reveal the
    extra horizontal world.

Select 16:9, 21:9 or Adaptive (follows the window) on the launcher's Mods
tab. Disabled by default; the 4:3 floor is unchanged until enabled.

Known state: authored based on static analysis of the boot EXEs; verify in-game
that HUD anchoring and backdrop edges hold on the wide stretch before
releasing (see game.toml [widescreen] comments).
