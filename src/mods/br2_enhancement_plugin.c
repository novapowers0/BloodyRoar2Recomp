#include "mod_plugins.h"

#include <stdlib.h>
#include <string.h>

/*
 * Bloody Roar II presentation enhancements, implemented with the framework's
 * own mod-owned APIs so they never touch guest logic, timers, audio, or VBlank.
 *
 *   - Auto-skip FMV / intro videos: the framework's MDEC+XA streaming-FMV
 *     detector ends intro movies the game's own way (hold START) the instant
 *     they are detected, so boot reaches the title / attract sooner.
 *
 * These are activation callbacks selected by the mod package manifest
 * (mods/preloaded/packages/br2.enhancement.performance), identical in shape
 * to the framework's builtin speed plugins (mod_builtin_speed.c).
 *
 * NOTE (frame interpolation): an uncapped-display-rate frame-interpolation
 * feature was authored and shipped here first, wired through
 * psx_mod_set_frame_interpolation() (120/144/165/240 + host). On real
 * hardware it corrupts the picture in-game when combined with Bloody Roar
 * II's widescreen (squash-mode GTE): characters vanish / content goes black
 * at high refresh, and toggling the rate 165->60->165 crashes the runtime.
 * Root cause is in the framework's GL interpolation present/capture
 * machinery interacting with the squash-wide present path, not in this
 * title's hooks, so the feature was removed rather than shipping broken.
 * It can be revisited once the framework interpolation is fixed for the
 * squash-wide present (see the mod catalog README).
 */

#define PKG "br2.enhancement.performance"

static void br2_fmv_skip_activate(void) {
    (void)psx_mod_set_auto_skip_fmv(1);
}

PSX_MOD_CONSTRUCTOR(br2_register_enhancement_plugins) {
    (void)psx_mod_register_activation_plugin(
        "br2.enhancement.fmv-skip", br2_fmv_skip_activate);
}
