/* Title config for psxrecomp/host/psxrecomp_codegen_host.
 * Wired only when the build opts into -DPSX_SETUP_WIZARD=ON.
 *
 * USA variant (SCUS-94424). codegen_setup.c is pinned to the Europe config
 * (game.toml / generated/SLES_017.22_dispatch.c); using it for the USA target
 * made the first-run wizard demand an EU dump ("Disc verification failed
 * (wrong dump)") even though the launcher had validated the US disc, and its
 * sources-missing probe looked for the EU marker, so the wizard was forced on
 * every launch of a USA-only tree. This file keeps each region's wizard
 * pointed at its own config and generated C. */

#include "codegen_setup.h"

#include "psxrecomp_codegen_host.h"

static const PsxrecompCodegenHostConfig kCodegenConfigUs = {
    .display_name = "Bloody Roar II (USA)",
    .project_root_env = "BLOODYROAR2RECOMP_PROJECT_ROOT",
    .build_dir_env = "BLOODYROAR2RECOMP_BUILD_DIR",
    .force_setup_env = "BLOODYROAR2RECOMP_FORCE_SETUP",
    .psxrecomp_cli_relpath = "psxrecomp/psxrecomp_cli.py",
    .seed_cfg_relpath = "game_us.toml",
    .game_toml_relpath = "game_us.toml",
    .gen_marker_relpath = "generated/SCUS_944.24_dispatch.c",
    /* Separate product dir: an EU and a USA setup host can coexist beside the
     * same project tree without overwriting each other's build-release/. */
    .build_dir_name = "build-release-usa",
    .cmake_target = "psx-runtime-us",
    .exe_basename = "BloodyRoar2_Recompiled_USA",
    .prepare_note =
        "Uses your legal USA disc with the local psxrecomp SDK to generate "
        "BIOS + game C, then cmake --build. The product lives under "
        "build-release-usa/; reopening this setup exe forwards there.",
    .prepare_note_windows =
        "Uses your legal USA disc with the local psxrecomp SDK to generate "
        "BIOS + game C, then quits and rebuilds via a helper. Afterward, "
        "this setup exe forwards to build-release-usa/ (bios, mods, settings).",
    .prepare_note_no_cmake =
        "Uses your legal USA disc with the local psxrecomp SDK to generate "
        "BIOS + game C. Rebuild into build-release-usa/, then relaunch this "
        "setup exe (it forwards to the product build).",
};

void psx_game_codegen_setup_apply(RecompLauncherCGameInfo *gi) {
  psxrecomp_codegen_host_apply(gi, &kCodegenConfigUs);
}

void psx_game_codegen_relaunch_or_exit(const char *disc_path) {
  psxrecomp_codegen_host_relaunch_or_exit(disc_path);
}

void psx_game_codegen_forward_if_built(int argc, char **argv) {
  psxrecomp_codegen_host_forward_if_built(&kCodegenConfigUs, argc, argv);
}