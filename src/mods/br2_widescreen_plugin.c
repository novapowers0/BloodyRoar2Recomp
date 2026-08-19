#include "mod_plugins.h"

/*
 * Bloody Roar II widescreen plugin.
 *
 * Authored from scratch for Bloody Roar II (SLES-01722 / SCUS-94424),
 * following the ApeEscapeRecomp / Tomba methodology (mstan) carried into the
 * psxrecomp framework fork maintained by NovaPowers.
 *
 * The projection, culling and HUD hooks for Bloody Roar II live as framework
 * configuration in game.toml / game_us.toml ([widescreen] / [widescreen.cull]),
 * baked into the recompiled code at codegen time. These trusted activation
 * callbacks only choose the host display aspect from the mod's option before
 * renderer startup — identical to how ApeEscapeRecomp's ape_widescreen_plugin
 * drives the display.
 */
static void br2_widescreen_16_9_activate(void) {
    (void)psx_mod_set_fixed_display_aspect(16u, 9u);
}

static void br2_widescreen_21_9_activate(void) {
    (void)psx_mod_set_fixed_display_aspect(21u, 9u);
}

static void br2_widescreen_adaptive_activate(void) {
    (void)psx_mod_set_fixed_display_aspect(16u, 9u);
    (void)psx_mod_set_adaptive_display_aspect(21u, 9u);
}

PSX_MOD_CONSTRUCTOR(br2_register_widescreen_plugins) {
    (void)psx_mod_register_activation_plugin(
        "br2.widescreen.16-9", br2_widescreen_16_9_activate);
    (void)psx_mod_register_activation_plugin(
        "br2.widescreen.21-9", br2_widescreen_21_9_activate);
    (void)psx_mod_register_activation_plugin(
        "br2.widescreen.adaptive", br2_widescreen_adaptive_activate);
}
