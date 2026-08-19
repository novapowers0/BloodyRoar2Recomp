# Bloody Roar II — Widescreen (documentación técnica)

Este documento explica **cómo se hizo** el widescreen de *Bloody Roar II* en este
proyecto: el razonamiento, la investigación, el análisis del binario, la
implementación y los créditos. Es una guía para entender el enfoque y para
reproducirlo en otros títulos de PS1.

> Estado: funcional y compilado en ambos ejecutables (`BloodyRoar2_Recompiled`
> Europa y `BloodyRoar2_Recompiled_USA`). La verificación visual in-game
> (anclaje de HUD y bordes de backdrop en el estiramiento wide) queda como paso
> de QA antes de un release.

---

## 1. Objetivo y enfoque

El objetivo era **ampliar el campo de visión (FOV)** de las peleas 3D de Bloody
Roar II a 16:9 / 21:9 **sin estirar el arte** ni romper la lógica del juego, y
**sin heredar** la configuración de widescreen de otro proyecto (Dragon Ball
Final Bout).

Dos caminos posibles:

| Camino | Descripción | Estado |
|---|---|---|
| **Cheat RAM/GPU** | Escribir `0x1333` / `0x19991333` (el hack de DuckStation) en el struct de proyección del juego. | Descartado como *parche de emulador*; no cubre los 3 backends del recomp (generado, intérprete, overlay DLLs). |
| **Squash GTE + stretch** (el elegido) | Comprimir la proyección GTE en X alrededor de OFX y presentar el frame estirado al ancho wide. | ✔ Es el enfoque de mstan / DuckStation / Beetle, aplicado **en la librería GTE** del recomp, cubre todos los backends y mantiene alineados los culls del juego. |

Se eligió el **squash GTE + present-stretch**, el mismo mecanismo verificado que
usa el framework de psxrecomp y que mstan aplica en Ape Escape / Tomba.

---

## 2. Créditos (quién hizo qué)

| Pieza | Autor |
|---|---|
| **Infraestructura de widescreen del framework** (GTE X-squash `gte_set_display_aspect`, compositor native-wide, `psx_mod_set_fixed_display_aspect`, cull sites, `psx_ws_cull_*`, backdrop unsquash) | **NovaPowers** — fork `novapowers0/psxrecomp` (rama `nova-mods`) |
| **Metodología de widescreen por-título** (mod package + plugin que solo elige el aspect + sitios de código en `game.toml [widescreen]`) | **mstan** — proyectos `ApeEscapeRecomp`, `TombaRecomp`, `Tomba2Recomp` y `recomp-ui` |
| **Widescreen específico de Bloody Roar II** (análisis del binario, sitios de culling, `[widescreen]`/`[widescreen.cull]`, plugin `br2_widescreen_plugin.c`, paquete `br2.enhancement.widescreen`) | **Este proyecto (BloodyRoar2Recomp)** |
| **Ground truth del widescreen de BR2** (cheat `0x1333` / `0x19991333`) | **DuckStation** (base de datos `chtdb.txt` en `E:\Emuladores\PS1`) |

No se copió la configuración `[widescreen]` de ningún otro juego: los sitios de
Bloody Roar II se derivaron del análisis de sus propios binarios
(`SLES_017.22` / `SCUS_944.24`).

---

## 3. Investigación previa

### 3.1 Metodología de mstan (Ape Escape / Tomba)

Analizando `ApeEscapeRecomp` (repositorio público de mstan) se identificó el
patrón exacto:

- **Un paquete de mod por-título** en `mods/preloaded/packages/<id>.enhancement.widescreen/`
  con `[[target]] game_id` + `disc_sha256`, y una opción `aspect` (16:9 / 21:9 /
  adaptive).
- **Un plugin de activación** (`src/mods/<game>_widescreen_plugin.c`) que
  únicamente llama a `psx_mod_set_fixed_display_aspect()` al activarse.
- **La configuración del FOV vive en `game.toml`** en el bloque `[widescreen]`
  y `[widescreen.cull]`, que el recompilador hornea en el C generado (los
  "sitios" de culling se reescriben en tiempo de codegen).

Esto es justo lo que replicamos: el plugin no contiene lógica de FOV, solo
selecciona el aspect del display; el trabajo real está en `game.toml`.

### 3.2 Ground truth de Bloody Roar II (DuckStation)

En `E:\Emuladores\PS1\database\chtdb.txt` aparecen los cheats oficiales:

```
; Bloody Roar II (USA) (SCUS-94424)
#Widescreen 16-9
A71F0018 19991333

; Bloody Roar 2: Bringer of the New Age (Europe) (SLES-01722)
#Widescreen 16-9
801F0270 1333

; Bloody Roar 2: Bringer of the New Age (Japan) (SLPS-01842)
#Widescreen 16-9
A71EF308 19991333
```

**Decodificación del valor `0x1333` (= 4915):** no es un OFX. Es un override de
**escala horizontal de proyección** (≈1.2× la base `0x1000` en Q12). En Europa
se escribe en RAM `0x801F0270` (campo 16-bit del struct de viewport/cámara);
en USA/Japón el *mismo struct* vive en `0x801F0018` y se parchea como palabra de
32 bits (`0x19991333` — mitad baja `0x1333` = la escala X, mitad alta `0x1999`
= la escala Y/adyacente).

---

## 4. Análisis del binario (cómo se encontraron los sitios)

Se analizaron los EXE `disc/SLES_017.22` y `disc/SCUS_944.24` (ambos 659.456
bytes, load `0x8011E800`, text `0xA0800`) y el C generado
(`generated/*_full_*.c`).

### 4.1 Proyección GTE (centro de pantalla)

- Boot-init GTE en `0x801944A8` (EU) / `0x8019426C` (US): H=1000, DQA=-4194,
  DQB=0x01400000, OFX=0, OFY=0.
- Setters de proyección:
  - `func_80195290` (EU) / `func_80195038` (US): `OFX = a0<<16; OFY = a1<<16`.
  - `func_801952B0` (EU) / `func_80195058` (US): `H = a0`.
- Init de viewport `func_8012708C`: anchos `{384, 512, 640}` × altos `{240,
  480}`; el modo estándar 640×480 da **OFX = 320<<16, OFY = 240<<16, H = 360**.
- La cámara de pelea usa **H = 360** cada frame.

El 3D de pelea se renderiza en un viewport GTE de **512×480** (OFX=256,
OFY=240), con la cámara a H=360.

### 4.2 Firmas de culling de pantalla

Los funnels de transformación de triángulos (`func_8018A59C` y ~13 variantes en
`full_39`, `func_80187504` etc. en `full_38`) hacen `RTPT` y luego rechazan por
extensión de pantalla:

```
sltiu t9, t9, 0x200   ; SXY.X < 512  (X reject)
sltiu t5, t5, 0x1E0   ; SXY.Y < 480  (Y reject)
```

Es decir, la firma de culling de BR2 es **`0x200` (X) emparejada con `0x1E0`
(Y)** — **no** los defaults de Tomba (`0x140`/`0xE0`) ni los de Ape Escape
(`0x181`). Por eso `screen_w_imms = ["0x200"]` y `screen_h_imms = ["0x1E0"]`.

> ⚠️ **Ojo:** también hay un near-plane reject `sltiu ...,0x100` (256) que lee
> `OTZ` (`gte_data[7]`) en `0x8018A95C` y otros. **No** debe ir en
> `screen_w_imms` (ensancharía el rechazo del plano cercano).

### 4.3 ¿Se lee SXY de vuelta? (¿es seguro `squash = true`?)

Se auditaron los 61 `mfc2` de SXY en los shards: **todos** están dentro de los
funnels de culling que `auto_screen_x` reescribe. **No hay** lectura de SXY que
alimente IA de actores, decisiones de volteo o layout de UI. Por eso el squash
GTE **no corrompe** la lógica de BR2 — a diferencia de Dragon Ball Final Bout,
que necesitaba `squash = false` (su render lee SXY para culling de actores y
layout de UI).

### 4.4 Detección 2D vs 3D (¿cuándo ensanchar?)

- Las peleas hacen **cientos de RTPS/RTPT** por frame.
- Los menús / select de personaje / opciones son sprites 2D (SPRT/TMRECT) que
  **nunca tocan el GTE**.

Por tanto `gte_game_mode = true` (detector de actividad GTE) es el gate correcto:
las peleas 3D revelan el FOV extra y las pantallas 2D genuinas se mantienen
pillarboxed a 4:3.

### 4.5 NCLIP y clipping wide-edge

Como es un juego de lucha 3D con mucha geometría en los bordes, el clipping en
el clamp SXY ±1024 puede producir artefactos en el FOV ensanchado; por eso se
activa `precise_nclip = true` (el flag existe en el framework justamente para
esta clase de títulos 3D).

---

## 5. Implementación

### 5.1 El plugin (elige el aspect del display)

`src/mods/br2_widescreen_plugin.c` — replicando `ape_widescreen_plugin.c`:

```c
#include "mod_plugins.h"

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
```

Se compila en el runtime vía `EXTRAS_SOURCES` en `CMakeLists.txt`.

### 5.2 El paquete de mod

`mods/preloaded/packages/br2.enhancement.widescreen/1.0.0/manifest.toml` —
cubre **ambas regiones** con dos `[[target]]` (una por `game_id` + `disc_sha256`),
con opción `aspect` (16:9 / 21:9 / Adaptive), desactivado por defecto.

### 5.3 La configuración `[widescreen]` (los sitios de FOV)

En `game.toml` y `game_us.toml`:

```toml
[video]
aspect_ratio = "4:3"   # el mod eleva a 16:9/21:9 en runtime

[widescreen]
gte_game_mode  = true
squash         = true   # seguro: BR2 solo lee SXY dentro del funnel que auto_screen_x ensancha
native_wide    = false  # validado: el squash+stretch, no el compositor native-wide
precise_nclip  = true   # evita artefactos de clipping wide-edge en NCLIP
offer          = true
offer_ultrawide = true
adaptive_view  = true

[widescreen.cull]
auto_screen_x  = true
screen_w_imms  = ["0x200"]   # firma real de BR2 (no el default 0x140 de Tomba)
screen_h_imms  = ["0x1E0"]
```

> `squash` se deja en su default `true` porque el análisis demostró que BR2 no
> lee SXY fuera del funnel de culling — a diferencia de Final Bout.

### 5.4 Catálogo de mods curado

En `CMakeLists.txt`, tras el staging del catálogo builtin del framework, se
**eliminan** los mods que no pertenecen a Bloody Roar II:

- `psx.enhancement.custom-combat` — combate de Final Bout (hardcodeado a ese
  título; su bridge de invitado es específico de Final Bout).
- `psx.enhancement.widescreen` — stub genérico; se sustituye por el
  `br2.enhancement.widescreen` propio.

Y se despliega `mods/preloaded` sobre el árbol, quedando el catálogo final:
`br2.enhancement.widescreen`, `cd-speed`, `fast-loading`, `pgxp`.

---

## 6. Cómo verificar

- **Compilación**: el plugin aparece en el build como
  `Building ... br2_widescreen_plugin.c.obj`.
- **Código generado**: los sitios de culling ensanchados aparecen en
  `generated/*_full_39.c` como `psx_ws_cull_sltiu(cpu->gpr[25], 512)` en las
  direcciones `0x8018A6xx`–`0x8018BAxx`.
- **Catálogo**: `build-release/mods/packages/` no contiene
  `psx.enhancement.custom-combat` ni `psx.enhancement.widescreen`, y sí
  contiene `br2.enhancement.widescreen`.
- **Runtime**: el launcher arranca ("Bloody Roar II (Europe) - Launcher") y el
  mod aparece en la pestaña Mods (por defecto off, manteniendo el 4:3 fiel).

**QA visual pendiente**: confirmar en pelea que el anclaje del HUD y los bordes
del backdrop se mantienen en el estiramiento wide (16:9 y 21:9), y que las
pantallas 2D quedan pillarboxed a 4:3.

---

## 7. Referencias

- **mstan / ApeEscapeRecomp** — `src/mods/ape_widescreen_plugin.c`,
  `mods/preloaded/packages/ape.enhancement.widescreen/`, `game.toml [widescreen]`.
- **mstan / TombaRecomp** — primero en usar el bloque `[widescreen]` (framework
  `feat/widescreen`, commits citados en `psxrecomp/WIDESCREEN.md`).
- **NovaPowers / psxrecomp (nova-mods)** — `runtime/src/gte.cpp`
  (`gte_set_display_aspect`, X-squash, `gte_ws_*`), `runtime/src/gpu.c`,
  `runtime/include/ws_cull_detect.h`, `recompiler/src/config_loader.cpp`.
- **DuckStation** — `database/chtdb.txt` (cheats widescreen de BR2, ground
  truth de `0x1333` / `0x19991333`).
- **BlackLabelHQ/SymphonyRecomp** — referencias de parches (otro recompilador;
  útiles conceptualmente, no se portó código).
