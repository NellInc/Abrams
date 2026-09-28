# PC audio coverage and machine QA

The finite source audit now accounts for every relative-near-call candidate in
SIM's first 64 KiB code segment targeting the known original sound and message
routines. The fingerprinted original executable is decoded afresh. Unclassified
calls fail the audit. This denominator does not establish the absence of arbitrary
indirect calls elsewhere in the program.

| Source domain | Original coverage | Installed coverage |
|---|---:|---:|
| Sound dispatcher | 30 callsites: 21 sampled, 9 motor/stop | 11 one-shot sample types, 2 source-driven loops |
| Incoming bearing | 256 original byte inputs | 360 digit-wise takes, including 104 supplemental bearings |
| Damage | 24 captions | 24 takes |
| Warning/outcome | 8 captions | 8 takes |
| Scenario, destroyed class and speed | 50 captions from 54 assignments | 50 takes |
| Radio | 7 captions | 7 takes |
| Accepted cannon, smoke and visible READY | 3 qualified event routes | 3 reused authored voices |
| Frontend music | 4 source-qualified contexts | 4 local authored arrangements |

There are 345 distinct caption strings in the checked original CPU domains and
449 installed PC-caption takes. A further nine shared calibration voices are
installed, three of which have explicit PC event routes. The bank contains 472
export-tree WAVs: 458 voices and 14 effects/loops. The reload effect is retained
for the calibration range; PC READY uses its source-visible voice gate. Four
source-derived local music WAVs remain outside the export tree.

The 21 original message/radio routing callsites are classified separately from
caption counts. A caption count alone cannot establish that every caller has
been considered. Fresh isolated CPU execution reproduces all six committed
bearing, damage, warning, remaining, radio and additional-request fixtures.
Individual live mission occurrence remains a separate claim.

## Repeatable asset gate

```sh
python3 tools/audit_pc_audio.py --output artifacts/pc-audio-audit.json
python3 -m unittest tests.test_pc_audio_audit
```

The audit measures every installed and local-music WAV: complete 16-bit PCM,
receipt/master SHA-256 custody, sample peak, RMS, full-scale samples, and leading
and trailing silence at a -60 dBFS threshold. Speech starts later than 0.5 seconds
or tails longer than one second are reported as timing advisories. These metrics
are sample-domain measurements; they do not measure LUFS, true peak, subjective
balance or all possible concurrent output combinations.

The 28 September pass found three full-scale samples in the old bearing 182
master. A fresh Gemini 3.8 Flash TTS dry take replaced that installed file only,
after blind transcription and independent individual-digit classification.
Its peak is -1.18 dBFS. The prior dry master remains unchanged; provenance records
its hash and the replacement master. No source game audio or mixed gameplay
recording was uploaded. “Nine” and “niner” remain accepted individual-digit forms.

The runtime now checks sound dispatch IP, exact caller, request value, selected
sample, paired voice and enabled backend before any playback. The Python source
mapping and Godot constants are compared by a regression test. Known sample
names cannot legitimize a wrong original callsite. Existing once-only identity,
stale-batch suppression, source mute, transport mute, restore and shutdown gates
continue to apply. New speech replaces the shared current voice rather than
building a playback queue.

## Remaining boundaries

Briefing/debriefing narration remains unvoiced because the available frontend
text has no complete utterance grouping or interruption identity. Synthesizing
arbitrary visible fragments would introduce narration with weaker source custody.
The frontend arrangements are authored sample-based music, not a reconstruction
of the original Genesis score. Independent human listening, subjective mix
acceptance, per-cue live mission occurrence and redistribution permission are
not claimed by these machine checks.

## Dedicated PC overlap safeguard

Every PC presentation instance owns a separate audio bus containing Godot's
[AudioEffectHardLimiter](https://docs.godotengine.org/en/stable/classes/class_audioeffecthardlimiter.html).
All its existing effect, voice, motor and music players route through that bus.
The ceiling is -1 dB, pre-gain is 0 dB and release is 100 ms. Player/category
levels remain unchanged. The shared Master bus and calibration audio remain
untouched; scene teardown removes only the instance's own bus.

`test_pc_audio_limiter.gd` exercises actual Godot bus processing using newly
synthesized PCM, with
[AudioEffectCapture](https://docs.godotengine.org/en/stable/classes/class_audioeffectcapture.html)
before and after the limiter. No game recording is made. Eight overlapping
synthetic effects plus one synthetic voice produce a 2.912 pre-effect peak;
the protected peak is 0.891261, with zero full-scale frames. The measured added
onset delay is 2.04 ms and the added stop tail is 1.86 ms at 44.1 kHz, both below
the test's 15 ms bound. Tests also prove bus isolation, routing and teardown.

These are Dummy-driver mixer measurements on the pinned Godot runtime, rather
than hardware round-trip latency, an inter-sample true-peak proof or a human
intelligibility assessment. The limiter provides sample-domain overload protection
for the PC bus. Unrelated downstream gain and simultaneous external audio are
outside that guarantee.
