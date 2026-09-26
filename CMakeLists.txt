cmake_minimum_required(VERSION 3.20)
project(BloodyRoar2Recomp LANGUAGES C CXX)

set(PSXRECOMP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/psxrecomp" CACHE PATH
    "Path to psxrecomp")

# --- Opt-in product surfaces (OFF by default in the framework) -------------
# recomp-ui submodule present (PSX_RECOMP_UI defaults ON). Full netplay UI is
# gated behind lib/recomp-net (PSX_NETPLAY must be set BEFORE the include,
# see below).
set(PSX_SETUP_WIZARD ON CACHE BOOL
    "Advertise first-run setup wizard + Generate & rebuild in recomp-ui" FORCE)
if(EXISTS "${PSXRECOMP_ROOT}/lib/recomp-net/CMakeLists.txt")
    set(PSX_NETPLAY ON CACHE BOOL "Netplay runtime wired (recomp-net present)" FORCE)
endif()
include("${PSXRECOMP_ROOT}/runtime/runtime.cmake")

# --- Mod catalog curation (framework v4) -----------------------------------
# The framework stages its shared builtin mod catalog (psxrecomp/mods/builtin)
# next to every game exe. We curate it here via the allowlist:
#   - keep psx.enhancement.{cd-speed,fast-loading,pgxp}
#   - drop psx.enhancement.widescreen (generic framework-wide stub; Bloody
#     Roar II ships its own from-scratch widescreen in mods/preloaded)
#   - drop psx.presentation.bezel (framework generic, not part of the game)
#   - psx.enhancement.custom-combat no longer exists in the v4 builtin set.
set(PSX_BUILTIN_MOD_ALLOWLIST
    psx.enhancement.cd-speed
    psx.enhancement.fast-loading
    psx.enhancement.pgxp
    CACHE STRING "Builtin mods staged into Bloody Roar II (curated)" FORCE)

set(_BR2_PRELOADED "${CMAKE_CURRENT_SOURCE_DIR}/mods/preloaded")

# Japan/Asia is deliberately opt-in until its private generated C has been
# produced and its regional enhancement sites have been independently checked.
option(BR2_BUILD_JAPAN "Build the isolated Japan/Asia SLPS-01842 target" OFF)

# Universal executable: links EU + USA + Japan generated images (each emitted
# under its own symbol prefix) into one exe. The runtime selects the image from
# the boot disc's serial. Requires all three generated/ sets to be present.
option(BR2_BUILD_UNIVERSAL "Build the combined EU+USA+Japan universal target" OFF)

# --- Dual-region runtime targets ------------------------------------------
# Europe (SLES-01722) is the primary target (psx-runtime -> BloodyRoar2_Recompiled).
# USA (SCUS-94424) is a second target (psx-runtime-us -> BloodyRoar2_Recompiled_USA).
# Each config (game.toml / game_us.toml) drives its own generate step and
# produces its own generated/<serial>_*.c set that coexists in generated/.
# NOTE: keep EXTRAS_SOURCES/PRELOADED_MODS_DIR before GEN_FULL_GLOB/
# CODEGEN_SETUP_SOURCES — the wrapper only declares the latter two as
# multi-value args and would swallow the rest.

# The universal target owns the canonical `BloodyRoar2_Recompiled` name; when it
# is enabled the isolated EU target is suffixed `_EU` so two CMake targets never
# produce the same output file (fatal under Ninja).
if(BR2_BUILD_UNIVERSAL)
    set(_BR2_EU_EXE_NAME "BloodyRoar2_Recompiled_EU")
else()
    set(_BR2_EU_EXE_NAME "BloodyRoar2_Recompiled")
endif()

# PGXP: compile the PGXP_*() hook calls the recompiler emits (they are no-ops
# unless the PGXP mod is enabled) so the advertised psx.enhancement.pgxp mod has
# full dataflow coverage instead of the base build's reduced tier. The mod is
# default-off, so the faithful floor is unchanged; the single target keeps its
# name (only the PSX_PGXP_VARIANT clone is suffixed).
psxrecomp_add_game_runtime(psx-runtime
    PGXP
    ENABLE_NETPLAY_IF_PRESENT
    ENABLE_SETUP_WIZARD
    NETPLAY_LOBBY_URL "ws://netplay.retcomm.net:8765"
    WINDOW_TITLE "Bloody Roar II Recompiled"
    EXE_NAME "${_BR2_EU_EXE_NAME}"
    DEFAULT_GAME_CONFIG_PATH "game.toml"
    MAX_PLAYERS 2
    APP_ICON "${CMAKE_CURRENT_SOURCE_DIR}/assets/psxrecomp.ico"
    PRELOADED_MODS_DIR "${_BR2_PRELOADED}"
    EXTRAS_SOURCES
        "${CMAKE_CURRENT_SOURCE_DIR}/src/compat/psxrecomp_vulkan_stub_compat.c"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/mods/br2_widescreen_plugin.c"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/mods/br2_enhancement_plugin.c"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/mods/br2_unlock_plugin.c"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/mods/br2_turbo_plugin.c"
    GEN_MARKER "generated/SLES_017.22_dispatch.c"
    GEN_FULL_GLOB "generated/SLES_017.22_full_*.c"
    CODEGEN_SETUP_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/codegen_setup.c"
)

# Generated game symbols are namespaced per region, so every target owns the
# unprefixed dispatch interface through the game-backend registry (which also
# hosts the universal selection logic).
target_compile_definitions(psx-runtime PRIVATE PSX_GAME_BACKEND_REGISTRY=1)

psxrecomp_add_game_runtime(psx-runtime-us
    PGXP
    ENABLE_NETPLAY_IF_PRESENT
    ENABLE_SETUP_WIZARD
    NETPLAY_LOBBY_URL "ws://netplay.retcomm.net:8765"
    WINDOW_TITLE "Bloody Roar II Recompiled (USA)"
    EXE_NAME "BloodyRoar2_Recompiled_USA"
    DEFAULT_GAME_CONFIG_PATH "game_us.toml"
    MAX_PLAYERS 2
    APP_ICON "${CMAKE_CURRENT_SOURCE_DIR}/assets/psxrecomp.ico"
    PRELOADED_MODS_DIR "${_BR2_PRELOADED}"
    EXTRAS_SOURCES
        "${CMAKE_CURRENT_SOURCE_DIR}/src/compat/psxrecomp_vulkan_stub_compat.c"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/mods/br2_widescreen_plugin.c"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/mods/br2_enhancement_plugin.c"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/mods/br2_unlock_plugin.c"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/mods/br2_turbo_plugin.c"
    GEN_MARKER "generated/SCUS_944.24_dispatch.c"
    GEN_FULL_GLOB "generated/SCUS_944.24_full_*.c"
    CODEGEN_SETUP_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/codegen_setup.c"
)

target_compile_definitions(psx-runtime-us PRIVATE PSX_GAME_BACKEND_REGISTRY=1)

if(BR2_BUILD_JAPAN)
    psxrecomp_add_game_runtime(psx-runtime-japan
        PGXP
        ENABLE_NETPLAY_IF_PRESENT
        ENABLE_SETUP_WIZARD
        NETPLAY_LOBBY_URL "ws://netplay.retcomm.net:8765"
        WINDOW_TITLE "Bloody Roar II Recompiled (Japan/Asia)"
        EXE_NAME "BloodyRoar2_Recompiled_Japan"
        DEFAULT_GAME_CONFIG_PATH "game_japan.toml"
        MAX_PLAYERS 2
        APP_ICON "${CMAKE_CURRENT_SOURCE_DIR}/assets/psxrecomp.ico"
        PRELOADED_MODS_DIR "${_BR2_PRELOADED}"
        EXTRAS_SOURCES
            "${CMAKE_CURRENT_SOURCE_DIR}/src/compat/psxrecomp_vulkan_stub_compat.c"
            "${CMAKE_CURRENT_SOURCE_DIR}/src/mods/br2_widescreen_plugin.c"
            "${CMAKE_CURRENT_SOURCE_DIR}/src/mods/br2_enhancement_plugin.c"
            "${CMAKE_CURRENT_SOURCE_DIR}/src/mods/br2_unlock_plugin.c"
            "${CMAKE_CURRENT_SOURCE_DIR}/src/mods/br2_turbo_plugin.c"
        GEN_MARKER "generated/SLPS_018.42_dispatch.c"
        GEN_FULL_GLOB "generated/SLPS_018.42_full_*.c"
        CODEGEN_SETUP_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/codegen_setup_japan.c"
    )
    target_compile_definitions(psx-runtime-japan PRIVATE PSX_GAME_BACKEND_REGISTRY=1)
endif()

if(BR2_BUILD_UNIVERSAL)
    file(GLOB _BR2_US_FULL
        "${CMAKE_CURRENT_SOURCE_DIR}/generated/SCUS_944.24_full_*.c")
    file(GLOB _BR2_JP_FULL
        "${CMAKE_CURRENT_SOURCE_DIR}/generated/SLPS_018.42_full_*.c")
    if(NOT _BR2_US_FULL OR NOT _BR2_JP_FULL)
        message(FATAL_ERROR
            "BR2_BUILD_UNIVERSAL=ON needs generated USA and Japan C. Run the "
            "codegen for game_us.toml and game_japan.toml first.")
    endif()
    psxrecomp_add_game_runtime(psx-runtime-universal
        PGXP
        ENABLE_NETPLAY_IF_PRESENT
        ENABLE_SETUP_WIZARD
        NETPLAY_LOBBY_URL "ws://netplay.retcomm.net:8765"
        WINDOW_TITLE "Bloody Roar II Recompiled (EU + USA + Japan)"
        EXE_NAME "BloodyRoar2_Recompiled"
        DEFAULT_GAME_CONFIG_PATH "game.toml"
        MAX_PLAYERS 2
        APP_ICON "${CMAKE_CURRENT_SOURCE_DIR}/assets/psxrecomp.ico"
        PRELOADED_MODS_DIR "${_BR2_PRELOADED}"
        EXTRAS_SOURCES
            "${CMAKE_CURRENT_SOURCE_DIR}/src/compat/psxrecomp_vulkan_stub_compat.c"
            "${CMAKE_CURRENT_SOURCE_DIR}/src/mods/br2_widescreen_plugin.c"
            "${CMAKE_CURRENT_SOURCE_DIR}/src/mods/br2_enhancement_plugin.c"
            "${CMAKE_CURRENT_SOURCE_DIR}/src/mods/br2_unlock_plugin.c"
            "${CMAKE_CURRENT_SOURCE_DIR}/src/mods/br2_turbo_plugin.c"
            "${CMAKE_CURRENT_SOURCE_DIR}/generated/SCUS_944.24_dispatch.c"
            ${_BR2_US_FULL}
            "${CMAKE_CURRENT_SOURCE_DIR}/generated/SLPS_018.42_dispatch.c"
            ${_BR2_JP_FULL}
        GEN_MARKER "generated/SLES_017.22_dispatch.c"
        GEN_FULL_GLOB "generated/SLES_017.22_full_*.c"
        CODEGEN_SETUP_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/codegen_setup.c"
    )
    target_compile_definitions(psx-runtime-universal PRIVATE PSX_GAME_BACKEND_REGISTRY=1)
    # Size: the generated per-region C is ~20 MB of machine code each and
    # dominates the universal exe. Compile ONLY that code for size (the shared
    # runtime keeps -O3 for emulation speed), put each generated function in its
    # own section, and let the linker drop anything unreferenced.
    file(GLOB _BR2_EU_FULL
        "${CMAKE_CURRENT_SOURCE_DIR}/generated/SLES_017.22_full_*.c")
    set(_BR2_UNI_GENERATED
        ${_BR2_EU_FULL} ${_BR2_US_FULL} ${_BR2_JP_FULL}
        "${CMAKE_CURRENT_SOURCE_DIR}/generated/SLES_017.22_dispatch.c"
        "${CMAKE_CURRENT_SOURCE_DIR}/generated/SCUS_944.24_dispatch.c"
        "${CMAKE_CURRENT_SOURCE_DIR}/generated/SLPS_018.42_dispatch.c")
    set_source_files_properties(${_BR2_UNI_GENERATED} PROPERTIES
        COMPILE_OPTIONS "-Os;-ffunction-sections;-fdata-sections")
    target_link_options(psx-runtime-universal PRIVATE "-Wl,--gc-sections")
    foreach(_BR2_UNI_CFG game.toml game_options.toml)
        if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${_BR2_UNI_CFG}")
            add_custom_command(TARGET psx-runtime-universal POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${CMAKE_CURRENT_SOURCE_DIR}/${_BR2_UNI_CFG}"
                    "$<TARGET_FILE_DIR:psx-runtime-universal>/${_BR2_UNI_CFG}"
                COMMENT "Staging ${_BR2_UNI_CFG} for psx-runtime-universal"
                VERBATIM)
        endif()
    endforeach()
endif()

# Stage runtime configs next to the exe for direct build/ launches. Only copy
# files that exist — never fail POST_BUILD when a config is absent.
set(_BR2_RUNTIME_CONFIGS
    psx-runtime game.toml
    psx-runtime-us game_us.toml
    psx-runtime-japan game_japan.toml)
list(LENGTH _BR2_RUNTIME_CONFIGS _BR2_RUNTIME_CONFIGS_LEN)
math(EXPR _BR2_RUNTIME_CONFIGS_LAST "${_BR2_RUNTIME_CONFIGS_LEN} - 1")
foreach(_BR2_RUNTIME_CONFIG_INDEX RANGE 0 ${_BR2_RUNTIME_CONFIGS_LAST} 2)
    list(GET _BR2_RUNTIME_CONFIGS ${_BR2_RUNTIME_CONFIG_INDEX} _PSX_RUNTIME_TARGET)
    math(EXPR _BR2_RUNTIME_CONFIG_INDEX_NEXT "${_BR2_RUNTIME_CONFIG_INDEX} + 1")
    list(GET _BR2_RUNTIME_CONFIGS ${_BR2_RUNTIME_CONFIG_INDEX_NEXT} _PSX_RUNTIME_CONFIG)
    if(TARGET ${_PSX_RUNTIME_TARGET} AND
       EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${_PSX_RUNTIME_CONFIG}")
        add_custom_command(TARGET ${_PSX_RUNTIME_TARGET} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CMAKE_CURRENT_SOURCE_DIR}/${_PSX_RUNTIME_CONFIG}"
                "$<TARGET_FILE_DIR:${_PSX_RUNTIME_TARGET}>/${_PSX_RUNTIME_CONFIG}"
            COMMENT "Staging ${_PSX_RUNTIME_CONFIG} for ${_PSX_RUNTIME_TARGET}"
            VERBATIM)
    endif()
endforeach()

# psx-runtime-japan only exists with -DBR2_BUILD_JAPAN=ON; never reference a
# target that was not created (add_custom_command(TARGET ...) is fatal).
set(_BR2_GAME_OPTIONS_TARGETS psx-runtime psx-runtime-us)
if(BR2_BUILD_JAPAN)
    list(APPEND _BR2_GAME_OPTIONS_TARGETS psx-runtime-japan)
endif()
foreach(_PSX_RUNTIME_TARGET ${_BR2_GAME_OPTIONS_TARGETS})
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/game_options.toml")
        add_custom_command(TARGET ${_PSX_RUNTIME_TARGET} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CMAKE_CURRENT_SOURCE_DIR}/game_options.toml"
                "$<TARGET_FILE_DIR:${_PSX_RUNTIME_TARGET}>/game_options.toml"
            COMMENT "Staging game_options.toml for ${_PSX_RUNTIME_TARGET}"
            VERBATIM)
    endif()
endforeach()

if(BR2_BUILD_JAPAN)
    foreach(_PSX_RUNTIME_CONFIG game_japan.toml game_options.toml)
        if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${_PSX_RUNTIME_CONFIG}")
            add_custom_command(TARGET psx-runtime-japan POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${CMAKE_CURRENT_SOURCE_DIR}/${_PSX_RUNTIME_CONFIG}"
                    "$<TARGET_FILE_DIR:psx-runtime-japan>/${_PSX_RUNTIME_CONFIG}"
                COMMENT "Staging ${_PSX_RUNTIME_CONFIG} for psx-runtime-japan"
                VERBATIM)
        endif()
    endforeach()
endif()
