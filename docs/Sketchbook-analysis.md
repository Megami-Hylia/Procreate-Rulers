# Sketchbook reference analysis

Operator-supplied IPA: Sketchbook 6.0.9, build 3, bundle com.autodesk.ios.SketchBookPro3. SHA-256: 0f8e68fb15682de0586ab2a19357c93250d45048ed03f1f4e42b59f351abcbd2. Executable SHA-256: ef317af4c207ea27f662302bf94c261ec133ed30af9e2ff6fe0123e2db98fe1b. ARM64 Mach-O; LC_ENCRYPTION_INFO_64 cryptid=0.

REA CLI 6.7.0 inventory: ev_ec905d1152cf98d915bb9644b4d61dba8f23ffea32cdf4fa07d5e3d187875bdf. Offline Python parsed plist/Mach-O/Objective-C structures; Capstone disassembled selected dispatch methods. Native decompilers were unavailable on this host. No application execution or complete source recovery was performed.

## Observations from the supplied bytes

The actual app classes (excluding the unrelated Adonit accessory SDK) include GuidesToolController, GuidesViewController, SymmetryToolController and SymmetryViewController. Their UIKit selectors include guidesRulerPressed: at 0x1005b08bc, guidesCurveRulerPressed: at 0x1005b0908, symmetryXPressed: at 0x1005c64cc, symmetryYPressed: at 0x1005c64fc, radialSymmetryPressed: at 0x1005c685c and sectorSliderValueChanged: at 0x1005c6a88. Addresses are unslid and specific to this exact executable.

Swift dispatch instructions route the two axis buttons through distinct values 1 and 2. The package also contains strings for ruler manipulation, symmetry lock/show/stop-center controls and a radial sector slider. These observations establish implemented entry points and encoded UI text, not complete runtime behavior.

C++ RTTI names identify app-specific sk::HudRuler, sk::HudCurveRuler, sk::RulerTool, sk::HudSymmetry and sk::SymmetryTool. Feature-name searches of the Mach-O nlist symbol table found no matching feature symbols; this is a bounded negative search, not proof of absent code. Those classes depend on Sketchbook-specific view, document, gesture, property and rendering systems, so transplanting compiled functions into Procreate is not established as compatible.

## Behavior used for an independent recreation

The [official ruler guide](https://help.sketchbook.com/docs/rulers-and-guides) describes drawing onto an active guide from anywhere on the canvas, direct curve manipulation, one-finger translation, two-finger manipulation, reset and curve-fitting gestures. These interactions were reimplemented with original UIKit and cubic geometry code; the proprietary curve algorithm was not recovered or copied.

The [official symmetry guide](https://help.sketchbook.com/docs/symmetry) describes axis combination, radial symmetry, movable axes and additional lock/visibility/center-crossing controls. The supplied binary independently contains matching entry-point names and controls. The Procreate extension recreates the basic four mode choices through Procreate's own engine and commits assisted drawing on the current layer.

## Compatibility boundary

Procreate's native radial mode is retained at 8 sectors. Sketchbook's adjustable radial count (up to 16 in the current official guide), stop-at-center option and separate symmetry visibility/lock controls are not recreated. Axis positioning uses Procreate's native guide editor. Finger painting is not constrained; ruler manipulation uses fingers and constrained painting uses Apple Pencil. Guides remain screen-space and their custom settings are not stored in projects.

Tests cover geometry, ruler fitting/cardinal snapping and a UIKit harness with explicit native-engine test doubles. Neither original app was run in that harness. Real Procreate input/rendering, pressure behavior, installation and final native-state transitions remain device verification requirements.
