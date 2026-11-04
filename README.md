# Procreate Rulers

Experimental original extension for the supplied Procreate 5.4.8/build 57066 IPA. The v5 correction follows a reference video showing that earlier visible guides did not constrain actual painting. The v6 correction addresses cross-arc chords and touch routing observed in the follow-up video. See [the native call path](docs/Video-correction.md) and [the v6 regression](docs/Video-v6-correction.md).

## Rulers

The toolbar's Righello button opens two choices: Dritto and Flessibile. Native painting samples are constrained to the displayed path through Procreate's own coordinate conversions. Flexible input intervals are subdivided along the actual arc, including reversals and endpoint-to-endpoint jumps, rather than leaving the brush to join two distant projected endpoints. Repeated overlapping batches retain contiguous deterministic sample IDs. The extension does not intercept global UIKit UITouch methods or rely on selecting a guessed input view.

The normal ruler has two endpoint handles to pivot/resize it. The flexible ruler has three handles directly on its curve: two ends and a bend point. Drag any handle with a finger or Pencil to reshape it; drag the translucent body with a finger to move the whole guide. Pencil strokes on the body pass through to painting. Two fingers rotate/pinch-scale it, with cardinal-angle snapping. Double-tap its body to reset, or a flexible handle to fit the current curve into the view. Blocca disables guide manipulation. Native controls such as Undo and brush sliders take priority over the guide. Press the toolbar icon again for free drawing.

The interface uses a compact selector and neutral translucent ruler bodies, matching the interaction shown in the reference rather than an external cubic editing scaffold.

## Symmetry

The second toolbar button offers Verticale, Orizzontale, Entrambi and Radiale through Procreate's native guide engine. Selection activates assisted drawing on the current layer. Modifica assi opens the original editor. Disattiva switches the guide and current-layer assistance off. Radial remains Procreate's native 8-sector mode; Sketchbook's adjustable 16-sector mode, stop-at-center and separate symmetry lock/show controls are not reproduced.

## Validation boundaries

GitHub Actions compiles an ARM64 dylib with the iPhoneOS SDK, runs C geometry and Python packaging tests, and runs a UIKit iPad harness. The production Objective-C method hook is exercised through an exact-ABI native-input test double, not through a standalone projection helper. The harness checks pan/zoom/rotation conversion, copied pressure/tilt/timestamps, committed/predicted samples and passthrough when disabled or used by unrelated documents. It does not run real Procreate. Device input/rendering and downstream smoothing remain unverified.

Guides remain fixed to the screen during canvas pan/zoom/rotation and their settings are not saved in projects. Save copies of drawings before testing.

## Build and package

On macOS: `bash scripts/build.sh`. Package locally with `python scripts/package_ipa.py ORIGINAL.ipa ProcreateRulers.dylib NEW.ipa`. The original is never overwritten. The exact analyzed Procreate executable digest is required. Sign the resulting IPA with the user's normal Sideloadly setup. No proprietary IPA, resource or credential is published in this repository or its Actions artifacts.
