cmake_minimum_required(VERSION 3.20)
project(BloodyRoar2Recomp LANGUAGES C CXX)

set(PSXRECOMP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/psxrecomp" CACHE PATH
    "Path to psxrecomp")

# --- Opt-in product surfaces (OFF by default in the framework) -------------
# recomp-ui submodule present (PSX_RECOMP_UI defaults ON). Full netplay UI is
# gated behind lib/recomp-net (ENABLE_NETPLAY_IF_PRESENT below).
set(PSX_SETUP_WIZARD ON CACHE BOOL
    "Advertise first-run setup wizard + Generate & rebuild in recomp-ui" FORCE)
# libchdr from a project-local copy when the network fetch is unavailable
# (GitHub rate-limits; keeps Generate & rebuild deterministic offline).
if(NOT FETCHCONTENT_SOURCE_DIR_PSX_LIBCHDR AND
   EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/deps/libchdr/CMakeLists.txt")
    set(FETCHCONTENT_SOURCE_DIR_PSX_LIBCHDR
        "${CMAKE_CURRENT_SOURCE_DIR}/deps/libchdr" CACHE PATH
        "Use project-local libchdr (offline)" FORCE)
endif()
include("${PSXRECOMP_ROOT}/runtime/runtime.cmake")

# --- Dual-region runtime targets ------------------------------------------
# Europe (SLES-01722) is the primary target (psx-runtime -> BloodyRoar2_Recompiled).
# USA (SCUS-94424) is a second target (psx-runtime-us -> BloodyRoar2_Recompiled_USA).
# Each config (game.toml / game_us.toml) drives its own generate step and
# produces its own generated/<serial>_*.c set that coexists in generated/.

psxrecomp_add_game_runtime(psx-runtime
    ENABLE_NETPLAY_IF_PRESENT
    ENABLE_SETUP_WIZARD
    WINDOW_TITLE "Bloody Roar II Recompiled"
    EXE_NAME "BloodyRoar2_Recompiled"
    DEFAULT_GAME_CONFIG_PATH "game.toml"
    MAX_PLAYERS 2
    APP_ICON "${CMAKE_CURRENT_SOURCE_DIR}/assets/psxrecomp.ico"
    GEN_MARKER "generated/SLES_017.22_dispatch.c"
    GEN_FULL_GLOB "generated/SLES_017.22_full_*.c"
    CODEGEN_SETUP_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/codegen_setup.c"
    EXTRAS_SOURCES
        "${CMAKE_CURRENT_SOURCE_DIR}/src/mods/br2_widescreen_plugin.c"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/mods/br2_enhancement_plugin.c"
)

psxrecomp_add_game_runtime(psx-runtime-us
    ENABLE_NETPLAY_IF_PRESENT
    ENABLE_SETUP_WIZARD
    WINDOW_TITLE "Bloody Roar II Recompiled (USA)"
    EXE_NAME "BloodyRoar2_Recompiled_USA"
    DEFAULT_GAME_CONFIG_PATH "game_us.toml"
    MAX_PLAYERS 2
    APP_ICON "${CMAKE_CURRENT_SOURCE_DIR}/assets/psxrecomp.ico"
    GEN_MARKER "generated/SCUS_944.24_dispatch.c"
    GEN_FULL_GLOB "generated/SCUS_944.24_full_*.c"
    CODEGEN_SETUP_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/codegen_setup.c"
    EXTRAS_SOURCES
        "${CMAKE_CURRENT_SOURCE_DIR}/src/mods/br2_widescreen_plugin.c"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/mods/br2_enhancement_plugin.c"
)

# --- Mod catalog curation ------------------------------------------------
# The framework stages its shared builtin mod catalog (psxrecomp/mods/builtin)
# next to every game exe, including Final Bout-specific or generic packages
# that do not belong in Bloody Roar II. We curate that catalog here:
#   - drop psx.enhancement.custom-combat  (Final Bout-specific combat hijack;
#     its guest bridge is hardcoded to Final Bout and must not ship here)
#   - drop psx.enhancement.widescreen     (generic framework-wide stub; Bloody
#     Roar II ships its own from-scratch widescreen in mods/preloaded)
# then stage our own reviewed mod catalog (mods/preloaded) over the tree.
set(_BR2_BUILTIN_DROP
    psx.enhancement.custom-combat
    psx.enhancement.widescreen
)
set(_BR2_PRELOADED "${CMAKE_CURRENT_SOURCE_DIR}/mods/preloaded")

# Stage runtime configs next to the exe for direct build/ launches. Only copy
# files that exist — never fail POST_BUILD when a config is absent.
foreach(_PSX_RUNTIME_TARGET psx-runtime psx-runtime-us)
    foreach(_PSX_RUNTIME_CONFIG game.toml game_us.toml game_options.toml)
        if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${_PSX_RUNTIME_CONFIG}")
            add_custom_command(TARGET ${_PSX_RUNTIME_TARGET} POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${CMAKE_CURRENT_SOURCE_DIR}/${_PSX_RUNTIME_CONFIG}"
                    "$<TARGET_FILE_DIR:${_PSX_RUNTIME_TARGET}>/${_PSX_RUNTIME_CONFIG}"
                COMMENT "Staging ${_PSX_RUNTIME_CONFIG} for ${_PSX_RUNTIME_TARGET}"
                VERBATIM)
        endif()
    endforeach()

    # Curation runs after the framework's builtin-mod POST_BUILD (added inside
    # psxrecomp_add_game_runtime, which runs before this loop).
    foreach(_BR2_DROP IN LISTS _BR2_BUILTIN_DROP)
        add_custom_command(TARGET ${_PSX_RUNTIME_TARGET} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E rm -rf
                "$<TARGET_FILE_DIR:${_PSX_RUNTIME_TARGET}>/mods/packages/${_BR2_DROP}"
            COMMENT "Curating ${_BR2_DROP} out of ${_PSX_RUNTIME_TARGET} mods"
            VERBATIM)
    endforeach()

    # Stage the game's own reviewed mod catalog (mods/preloaded) over the tree.
    if(EXISTS "${_BR2_PRELOADED}")
        add_custom_command(TARGET ${_PSX_RUNTIME_TARGET} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_directory
                "${_BR2_PRELOADED}"
                "$<TARGET_FILE_DIR:${_PSX_RUNTIME_TARGET}>/mods"
            COMMENT "Staging Bloody Roar II mods/preloaded catalog"
            VERBATIM)
    endif()
endforeach()
