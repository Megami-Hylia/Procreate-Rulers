# V7: post-smoothing brush positions

The 14.429378-second operator video dated 4 November 2026 at 13:31:35 shows
v6 following the guide initially, then accumulating inward fans on successive
passes. Undo removes the fresh stroke and the same pattern recurs. The video
establishes that v6's input-level correction was insufficient; it does not by
itself establish which downstream brush stage altered the path.

## Static evidence from the exact supplied executable

These observations come from local Mach-O metadata parsing and ARM64
disassembly, not execution of the Procreate binary:

- `DocumentValkyrieController.paintBegan:options:` at `0x10070afe4` calls
  `strokeModeBeganWithOptions:kind:` and appends input samples. Stroke mode
  setup passes stroke options to the native layer's `strokeOnLayer:…` flow.
- `ValkyrieStroke` contains moving-average, streamline and FFT stages.
  Its `pushPlotFromControl:segment:slab:` creates native plots after those stages.
- `ValkyrieStrokePlot.plotCurve:previousPlot:initialAngle:` at `0x100ac39a8`
  creates brush dabs, then calculates variance, movement and grain corrections.
  At `0x100ac4394` it copies each dab using stride `0x150`.
- Plot getters and ObjC ivars agree: `_points` offset `0x308`, `_plotCount`
  offset `0x310`. `renderInstancesToBuffer:symmetry:variance:` at `0x100ac5844`
  reads the origin float pair at `0x10` within a dab. When variance is enabled,
  it adds the float pair at `0x78` before constructing the particle quad.
- SIMD fields are incomplete in the ObjC type encoding of a dab. The extension
  therefore does not infer that buffer's size from that encoding. It uses only
  the two verified field offsets and the verified stride; all other bytes are
  opaque and preserved.

The package builder already requires the exact analyzed executable SHA-256.
V7 also checks native method ABIs, the curve argument size and both ivar offsets
before installing the render hook. Unsupported layouts disable the ruler bridge.

## Correction

V7 retains input projection but additionally projects each final brush origin,
and its origin-plus-positional-variance, back onto the guide after the original
native plot method has completed. This prevents an inward post-smoothing origin
from being sent unchanged to the particle-quad renderer. Brush color, size,
pressure and other opaque dab attributes are not rewritten. This constrains
dab centers, not the footprint of a wide or textured brush.

`paintBegan:options:` and `paintRestart:options:` capture the current guide using
the native view-to-document conversion on the main thread. Each assisted stroke
gets a private options copy with an immutable guide snapshot. The snapshot is
propagated through native options copies and secondary-brush options, including
the normal case where no secondary options exist. Original reusable brush
settings and unrelated/freehand strokes remain untagged. Render-queue callbacks
use only the immutable document-coordinate geometry and native plot data.

## Tests and remaining limits

The C regression populates a native-layout dab buffer with an interior chord
and positional variance. It checks that both rendering origins lie on the guide,
that every opaque byte remains identical and that invalid values are unchanged.
The UIKit harness invokes the production runtime hooks using explicit native
ABI/layout test doubles. Its downstream mock deliberately produces inward brush
origins after input projection, then verifies correction off the main thread,
options-copy propagation, immutable delayed snapshots after the guide is hidden,
and disabled/unrelated/freehand passthrough. Earlier input and UI checks remain.

These tests do not execute real Procreate. Real-device confirmation is required
for the rendering path, performance, brush variants, undo, saving and export.
No video frames, proprietary binaries or recovered function bodies are published.
