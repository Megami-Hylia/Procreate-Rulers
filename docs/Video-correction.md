# Correction from the reference video

The operator's clip shows freehand purple marks in the modified Procreate even with the ruler visible (roughly 0–24 seconds). In Sketchbook, strokes are constrained to a straight line and then a bent guide (roughly 30–80 seconds). That is runtime evidence of a failure in the earlier extension, not merely a visual preference.

## Actual code-path evidence

Static analysis of the exact Procreate 5.4.8/build 57066 executable (SHA-256 74a4e8aae310e6f479f52688b09a7be260677ef54648499f2acac66a3f6d5ff1) establishes:

- `DocumentValkyrieViewController.paint:` calls `constrainedPointsFromGesture:restart:` before its paint-began/moved/ended commands (for example 0x100731a1c and 0x100731c6c).
- `constrainedPointsFromGesture:restart:` calls `controlPointsFromGesture:brush:options:recentOnly:includePredicted:` and then `constrainedControlPoints:initialLocationInView:` at 0x100731010.
- `constrainedControlPoints:initialLocationInView:` (0x100730e0c) itself copies control points and uses their `location`/`setLocation:` selectors when applying native constraints. Its recorded ABI is `@40@0:8@16{CGPoint=dd}24`.
- `DocumentValkyrieController.viewPointFromValkyriePoint:` and `valkyriePointFromViewPoint:` are inverse conversion entry points. The decoded instructions use `valkyrieView.superview` as the view-coordinate space and account for viewport scaling and the reversed Y axis.

## Fix

Remove all global UITouch swizzles. Wrap the native constrained-control-point method, call its original implementation, copy its returned committed/predicted control points and constrain their locations using Procreate's coordinate converters. Restrict the operation to the engine controller belonging to the visible editor. Preserve pressure, tilt, roll, timestamps and all other copied fields. Disabled rulers and unrelated documents pass through unchanged.

The old fake-touch geometric test did not exercise the actual installed runtime hook. The replacement harness calls an Objective-C class with the exact recorded entry-point ABI; the production method swizzle intercepts that call. It checks noisy batches with translated/scaled/rotated coordinates, point-copy attributes, predicted samples, disabled passthrough and an unrelated document. The native engine is still a test double: this does not execute the Procreate binary or establish real-device success.

## Interaction correction

The flexible guide now has three on-curve handles (two ends and one bend point), with a quadratic curve interpolating all three. It does not display four external cubic-control handles. The normal guide's endpoint handles pivot it. Both guides have a faint translucent body; one finger moves it, two fingers manipulate it, and the editing panel is compact. The input status counts native points actually processed instead of claiming that a visible ruler necessarily constrained the pen.

This is an original reconstruction from the recorded behavior, not a recovery of Sketchbook's original curve implementation. Native smoothing after the hook and actual device rendering still need observation on the user's iPad.
