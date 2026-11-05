# Accepted engine and shell impact

Nell approved the long steady engine and shell-impact sound on 5 November 2026.
She removed hull and debris playback because the grinding detail was annoying.

The optional native `pc-restrained-polish-v1` bank now contains exactly two
private 48 kHz mono PCM16 files: `engine.wav` (768,000 frames, 16 seconds) and
`impact.wav` (134,400 frames, 2.8 seconds). Originals and previous candidates
remain recoverable. Paid/free-pack derivatives stay outside Git, app bundles
and Web exports. The existing stock banks remain unchanged.

The engine is a processed spectral reconstruction from the owned Abrams idle
recording. Its existing player retains the original source period, amplitude,
gain, pitch, mute/pause/checkpoint and start/stop authority. The longer sample
removes the short two-second waveform repetition. It wraps after approximately
11.4 seconds at a representative observed running pitch and four seconds at
the maximum 4x pitch. Only the engine has a 2 MiB file cap.

The shell cue retains approved Impact B with an aligned stronger explosion
body. The original impact dispatcher, event ID, onset, cadence, pool allocation,
logical gain and shared limiter remain unchanged. No extra shot or separate
explosion player is created. Bluezone Corporation's free-pack component is
attributed in `NOTICE.md` and private provenance; it is designed sound, not an
authenticated field recording of an armor strike.

The loader binds both replacements to the incumbent parent PCM hashes and
publishes atomically after exact filenames, SHA, format, length and loop checks.
Missing or invalid optional content retains incumbent audio. The historical
seven-file supplemental bank is preserved for recovery, but no debris player
is allocated and no event or direct call can start debris. There is no hull
player, movement observer, random scatter dispatcher or new visibility binding.

Existing crew, music, world engines, environmental beds, settings and limiter
are unchanged. Original source audio, loop and mix checks plus focused optional
bank/removal checks apply. Background original-core capture verifies the
production mixer separately from device audio, window focus and performance.
