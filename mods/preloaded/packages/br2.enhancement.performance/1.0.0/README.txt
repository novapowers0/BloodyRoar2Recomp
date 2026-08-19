Bloody Roar II Intro Skip
=========================

Automatic skipping of Bloody Roar II's intro FMVs (Europe SLES-01722 / USA
SCUS-94424), built on the psxrecomp framework's mod-owned FMV-skip API
(psx_mod_set_auto_skip_fmv). Author: NovaPowers.

Auto-skip intro FMVs
--------------------
The framework's streaming-FMV detector (MDEC video + XA audio) ends intro
videos the game's own way (holds START) the instant they are detected, so
boot reaches the attract / title sooner. Only genuine streaming movies are
affected; static 2D copyright logos are not videos and are left untouched.

Enable it on the launcher's Mods tab. Disabled by default.

History / why frame interpolation is NOT here
---------------------------------------------
An uncapped-display-rate frame-interpolation feature (120/144/165/240 Hz via
psx_mod_set_frame_interpolation) was originally shipped alongside this, but
was removed. On real hardware it corrupts the in-game picture when combined
with Bloody Roar II's widescreen (squash-mode GTE): at high refresh the
characters vanish / content goes black, and toggling the rate 165->60->165
crashes the runtime. The root cause is in the framework's GL interpolation
present/capture machinery interacting with the squash-wide present path (not
in this title's hooks), so the feature was dropped rather than shipping
broken. It can be revisited once the framework interpolation is fixed for
the squash-wide present.
