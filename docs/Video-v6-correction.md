# Follow-up device video: v6 correction

The operator-supplied 29.664-second video, dated 4 November 2026 at 13:06:37,
shows v5's guide receiving native painting samples, but repeated strokes leave
straight chords inside the flexible arc (approximately 1–7 seconds). The latter
part shows attempts to manipulate the ruler and use native controls. Video frames
are local investigation material and are not published in this repository.

## Changes and evidence limits

V5 independently projected each native sample onto the nearest curve location.
This does not constrain the connection drawn *between* consecutive samples: a
jump between the ends can still draw the chord. V6 inserts 16 equal parameter
steps along each flexible interval, including backward motion. Original endpoint
attributes are copied; inserted attributes interpolate pressure, tilt, roll,
size, opacity and timestamp. Native source samples are not mutated. Straight
input remains one-for-one.

Native metadata in the previously analyzed executable exposes `index` as an
unsigned 32-bit integer. Its stroke pipeline overlays overlapping input arrays
in native point caches. Expanded IDs are therefore contiguous and deterministic
(`originalIndex * 16` for each original endpoint). Unsupported index sequences,
overflow or invalid coordinates return the unmodified batch instead of passing
malformed expanded data to the renderer. This is static evidence and an
implementation choice, not a recording of the modified renderer executing.

Pencil manipulation previously was excluded both in hit testing and in the pan
recognizer. V6 accepts Pencil input on the visible handles, and passes Pencil
input on the ruler body to painting. Finger routing examines the nearest active
contact instead of rejecting all fingers whenever any Pencil contact exists.
Native UIControls underneath the guide take priority so the infinite straight
guide cannot swallow Undo or brush slider touches. The processing counter is
removed from the visible panel; it was not a count of unique stroke samples.

## Regression checks

The UIKit harness calls the production runtime hook using explicit native test
doubles. A two-sample full-arc sweep must produce 17 contiguous output samples;
connections between those samples must remain within one point of the guide in
the tested shape. Replays must preserve IDs and locations. Checks cover dynamics
interpolation, unsupported ID gaps, Pencil handles versus body, a simultaneous
unrelated Pencil contact during finger dragging, and a native Undo button placed
directly beneath the guide. Existing transformed-coordinate, disabled/unrelated
document and symmetry checks remain.

The harness does not execute real Procreate's downstream smoothing or renderer.
Sixteen subdivisions bound the sampled approximation, not every possible brush
effect or extreme guide shape. Real-iPad verification is still required for
rendering, latency, Undo and saved projects. Guides remain screen-relative during
canvas navigation; this version does not change that existing behavior.
