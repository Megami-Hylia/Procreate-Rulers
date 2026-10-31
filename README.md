# Procreate Rulers — experimental iPad extension

Original extension code; no Procreate executable, artwork, extracted resources or credentials are distributed here. Not affiliated with Procreate or Savage Interactive.

## What is implemented

Two icon buttons are placed immediately after the native **Transform** control: **Righello** has exactly two modes: **Dritto** (straight) and **Flessibile** (flexible). Drawing coordinates are constrained to the displayed line or curve, not merely accompanied by a visual guide. Snapping is automatic while the ruler is on and a canvas is bound. The native canvas getter is used when available; otherwise the user taps a blank canvas area once. **Scegli tela** rebinds it manually. Press the toolbar ruler icon again to turn the guide and constraint off.

The flexible guide is a cubic Bezier with four draggable handles: green endpoints and orange control points. The blue center moves the whole ruler. Angle and size sliders rotate/scale both guide and projection together. The visible curve and Pencil coordinate constraint share the same control points. Handles accept finger dragging; Pencil drawing is passed through to the canvas. Current/previous and precise UITouch coordinates are constrained; pressure, inclination and timestamps are untouched. Finger painting is not constrained in this version.

**Simmetria** (split square). Their positions follow the actual native Transform control rather than fixed screen coordinates. They appear in the document editor, not the Gallery. A narrow window with insufficient space hides the buttons instead of covering native tools.

**Righello** opens screen-space straight ruler, 90° and 45° guides, circle, ellipse, quadratic curve and angle guide. Drag the blue center with a finger; use angle and size sliders. Choose the drawing surface explicitly with **Scegli tela**, then enable **Aggancio**. Only Apple Pencil location queries on the chosen view are constrained. Finger gestures, pressure, inclination and timestamps are not modified. Both ordinary and precise current/previous UITouch position methods are intercepted. Press Righello again to turn the overlay and snapping off.

**Simmetria** opens the native guide editor and switches its guide type to symmetry, through the model/controller methods found in the analyzed build. The native type-change checkpoint records undo; the original native options and Done/Cancel controls remain in charge of editing and assistance. This bridge does not replace the symmetry engine. Unsupported runtime methods show an explicit fallback message instead of silently pretending to activate symmetry. The native type value (3) was verified in the supplied executable's `symmetryStrokes` instructions; runtime behavior in real Procreate still requires device testing.

Startup accepts a changed signing bundle identifier and supports both scene-based and legacy UIKit windows. A timer retries attachment after startup and document transitions; the toolbar is hidden when the native document/Transform control cannot be found.

## Status and limitations

**Experimental; device behavior has not been tested.** Compilation and geometry tests cannot establish compatibility with Procreate's actual input pipeline. The app may bypass UITouch methods, in which case snapping will not work. Selecting the wrong drawing view can affect unrelated Pencil input until snapping is disabled. Reset the selection after changing documents. Guides stay fixed on the screen, so adjust them after zoom, pan or canvas rotation. Guide settings are not persisted in projects. Guides are drawn as a separate window overlay; export exclusion is expected by design but not verified in the app. Native undo grouping is untouched and requires device verification.

Designed against the supplied Procreate 5.4.8/build 57066 ARM64 package. Compatibility with other versions is unknown. Keep backups of drawings before testing.

## Build

GitHub Actions uses a macOS runner with the iPhoneOS SDK, runs C geometry and Python packaging tests, builds an ARM64 dylib and runs a UIKit integration harness in an iPad simulator. The harness checks changed bundle IDs, legacy windows, button placement, ruler open/close, exactly two ruler choices, automatic canvas binding, projection of Pencil coordinates onto straight and reshaped curves, and the native bridge selector sequence using explicit test doubles. Its screenshot is labeled as a test environment. These checks do **not** execute real Procreate or prove its input pipeline works. The ad-hoc signature permits packaging; it is not a device installation signature.

Locally on macOS: `bash scripts/build.sh`.

## Package your own IPA locally

`python scripts/package_ipa.py /path/to/Procreate.ipa /path/to/ProcreateRulers.dylib /path/to/Procreate-Rulers-unsigned.ipa`

The packager checks the expected executable digest, Mach-O header padding and encryption command, inserts a dylib load command and removes the now-stale main signature load command. It never overwrites the original IPA. The result requires signing with Sideloadly or another appropriate signer. Installation and runtime compatibility are not guaranteed. Do not upload the proprietary IPA to this public repository or its artifacts.
