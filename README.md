# Procreate Rulers — experimental iPad extension

Original extension code; no Procreate executable, artwork, extracted resources or credentials are distributed here. Not affiliated with Procreate or Savage Interactive.

## What is implemented

Floating screen-space straight ruler, 90° and 45° guides, circle, ellipse, quadratic curve and angle guide. Drag the blue center with a finger; use angle and size sliders. Choose the drawing surface explicitly with **Scegli tela**, then enable **Aggancio**. Only Apple Pencil location queries on the chosen view are constrained. Finger gestures, pressure, inclination and timestamps are not modified. Both ordinary and precise current/previous UITouch position methods are intercepted.

Symmetry uses Procreate's existing native drawing guides; this extension does not add or replace the native symmetry engine. Activate symmetry through Procreate's guide controls. Combined ruler/symmetry behavior is unverified.

## Status and limitations

**Experimental; device behavior has not been tested.** Compilation and geometry tests cannot establish compatibility with Procreate's actual input pipeline. The app may bypass UITouch methods, in which case snapping will not work. Selecting the wrong drawing view can affect unrelated Pencil input until snapping is disabled. Reset the selection after changing documents. Guides stay fixed on the screen, so adjust them after zoom, pan or canvas rotation. Ellipse ratio and curve control shape are fixed in this first version. Guide settings are not persisted in projects. Guides are drawn as a separate window overlay; export exclusion is expected by design but not verified in the app. Native undo grouping is untouched and requires device verification.

Designed against the supplied Procreate 5.4.8/build 57066 ARM64 package. Compatibility with other versions is unknown. Keep backups of drawings before testing.

## Build

GitHub Actions uses a macOS runner with the iPhoneOS SDK, runs C geometry tests, builds an ARM64 dylib and uploads it as an artifact. The ad-hoc signature permits packaging; it is not a device installation signature.

Locally on macOS: `bash scripts/build.sh`.

## Package your own IPA locally

`python scripts/package_ipa.py /path/to/Procreate.ipa /path/to/ProcreateRulers.dylib /path/to/Procreate-Rulers-unsigned.ipa`

The packager checks the expected executable digest, Mach-O header padding and encryption command, inserts a dylib load command and removes the now-stale main signature load command. It never overwrites the original IPA. The result requires signing with Sideloadly or another appropriate signer. Installation and runtime compatibility are not guaranteed. Do not upload the proprietary IPA to this public repository or its artifacts.
