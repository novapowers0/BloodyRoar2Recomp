# Bloody Roar II Recompiled v0.7.1 — release candidate

## Changes

- Updated the shared `recomp-ui` launcher to `b688ca79109bc3cc30a6f9de66d81ea70f0acf81`.
- Prepared matching Windows x64 and Linux x64 universal-game build workflows.
- Release packagers now reject a version mismatch between `VERSION` and the
  version embedded in the runtime before creating a distributable zip.
- Kept the `psxrecomp` pin at compatible commit
  `219a3627f817c5ad60b852d368c1bebc4f584b71`, which contains the multi-region,
  mod catalog and netplay integrations required by this title.

## Build artifacts

- Windows: `BloodyRoar2-v0.7.1.zip`
- Linux x64: `BloodyRoar2-linux-x64-0.7.1.zip`

The full Windows and Linux workflows produce build artifacts for validation.
Publish the release only after both artifacts have passed their platform checks.
Japan/Asia remains experimental; EU and USA remain the supported regions.
