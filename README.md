# Procreate Rulers

Experimental original iPad extension, with ruler interactions recreated from analysis of an operator-supplied Sketchbook IPA and its official documentation. No proprietary executable, image asset or recovered function body is included.

## Drawing tools

Two toolbar buttons appear after Procreate's Transform control.

**Righello** offers Dritto and Flessibile. Apple Pencil coordinate queries are projected onto the displayed line or editable cubic curve. The native canvas is bound automatically when possible; Scegli tela selects it manually. Press the toolbar icon again to return to free drawing.

Drag one finger along the ruler or its center to move it. Use two fingers over the ruler to rotate/pinch-scale it; rotation snaps within 3 degrees of a cardinal angle. Double-tap its body to reset; double-tap a flexible-ruler handle to fit the current shape into view. Four handles reshape the flexible curve. Blocca disables ruler manipulation until Sblocca is pressed. Angle and size sliders are also available.

**Simmetria** opens direct Verticale, Orizzontale, Entrambi and Radiale choices. Selection calls Procreate's native guide engine and commits assisted drawing to the current layer. Modifica assi opens the original guide editor; Disattiva disables the guide and current-layer assistance. Ruler and native symmetry may remain active together, but the combined real-app pipeline is unverified.

## Known limits

Experimental and not device-tested. A successful build/harness test does not prove compatibility with Procreate's input/rendering pipeline. If it bypasses the intercepted UITouch methods, constraint will not act. Finger painting is unconstrained. Rulers remain fixed on the screen and must be repositioned after canvas pan/zoom/rotation; their parameters are not saved with projects. Native export and undo behavior require device checks. Avoid self-crossing curves where nearest-point projection can switch branches.

Symmetry uses Procreate's native 8-sector radial mode. Sketchbook's 16-sector slider, stop-at-center and separate symmetry lock/show controls are not implemented. See [analysis and evidence boundaries](docs/Sketchbook-analysis.md).

## Build and package

GitHub Actions uses macOS/iPhoneOS SDK to compile an ARM64 dylib. Tests cover C geometry, Python IPA packaging, and a UIKit iPad simulator harness with explicit Procreate-engine test doubles. The simulator does not execute real Procreate or Sketchbook. Artifacts include the dylib and labeled harness screenshot/results.

On macOS: `bash scripts/build.sh`. Package locally: `python scripts/package_ipa.py ORIGINAL.ipa ProcreateRulers.dylib NEW.ipa`. Only the exact previously analyzed Procreate 5.4.8 build 57066 executable is accepted. The original IPA is never overwritten; the resulting IPA requires signing (for example with Sideloadly). Keep copies of drawings before testing. Proprietary IPAs must remain outside the public repository and Actions artifacts.
