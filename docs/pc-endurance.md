# Finite local endurance acceptance

Run against a built, stable trace core, with no concurrent performance probes.
Every invocation needs a new output directory. The gates use isolated original
save overlays and never write `GAME/` or `GENESIS/`.

```sh
python3 tools/verify_pc_endurance.py --output artifacts/endurance-host-NEW
./tools/godot.sh --script res://tests/test_pc_endurance.gd -- --boot --play --capture --frame-audit --output "$PWD/artifacts/endurance-native-NEW"
./tools/godot.sh --script res://tests/test_pc_play_resize.gd -- --boot --play --capture --frame-audit --output "$PWD/artifacts/endurance-resize-NEW"
```

The host gate visits all eight original scenarios and all four stations, pauses,
resumes, toggles original sound, fires the existing weapon route, quits and
returns through original debriefs. Nineteen checkpoint cycles compare fifteen
one-frame requests with 1+2+4+8-frame requests using full paired RAM/video hashes
and complete decoded state. Seven original information screens have exact pixel
witnesses. A separate campaign profile uses original Take R+R, closes the host,
and enters Continue from a new cold boot. No mission victory is attempted.

The native gate uses the production viewer, shortcuts and transport for three
checkpoint cycles plus three 1,200-frame paced segments. It records frame rate,
inter-packet p50/p95/max, Godot static memory and audio-consumer lag relative to
the current original envelope. This last metric verifies event consumption;
it does not measure speaker latency or replace listening review. The host gate
records native host/worker resident memory and request timings. Bulk-step audio
age is reported separately from real-time playback.

Resize acceptance requires the requested mode and dimensions to remain stable
for 750 milliseconds, with a ten-second deadline. This avoids treating twenty
unthrottled redraws as completion of a macOS fullscreen transition. Exact fitted
viewport pixels, black letterboxes and unchanged guest state remain required.

Completion requires zero process errors, explicit terminal completion lines,
passing JSON reports and unchanged original source hashes. A finite measured
performance sample is not an indefinite leak test. Rate and memory observations
have no invented historical or hardware-independent performance thresholds.
Checkpoint replay compares the trace core to itself; independent unmodified-core
RAM/video parity remains a separate gate. Acoustic drift, long campaign outcomes,
other hardware and other operating systems remain outside this gate.
