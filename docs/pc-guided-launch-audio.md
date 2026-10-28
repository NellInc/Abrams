# Source-qualified guided launch audio

Local integration, 28 October 2026. This work was implemented and reviewed with
root input. The public application and browser editions have not been rebuilt.

## Original trigger mapping

| Original class | Intact shape | Actual firing witness | Presentation result |
| --- | --- | --- | --- |
| BRDM-2, class13 | 141 | frame13086, controller50965 | Original firing branch confirmed; small source silhouette fails the unchanged separated-pixel requirement. |
| BRDM-3 rail launcher, class14 | 143 | frame14320, controller50982 | Native owner25 admits one recorded attack. |
| SAGGER, class15 | 161 | frame32056, controller51262, scenario record28 | Successful missile initialization and original request15 confirmed. The actor is absent from the presented pass, so no extra attack is admitted. |
| SPIGOT, class16 | 162 | frame21256, controller51279 | Native owner12 admits one recorded attack. Frame21761 has visible pixels but lacks the required prior source stamp; its original sound is retained. |
| M1-A1 AX | 125 | Existing original cannon request1 at33C4 | Ordinary round sound, with no own-AX rocket hook or override. |

The successful original enemy initialization boundary is `0000:033F`, following
allocator success at02C6. The original player-target request15 follows at034C,
return034F. Class names come from the pinned original class table and each live
controller/scenario/actor join. Original request9 companions remain unchanged.
The Sagger's weapon12 range table excludes bins0/1, below2048 original approximate
distance units. That constraint and the original terrain/marker tests remain intact.

## Admission and timing

Native events59/60 are stateless, read-only observations. Exact core receipts
must advertise both guided schemas1. Draw-start identities carry actor,
controller and global continuity revisions; allocator/free, rebinding, reset and
identity-conversion barriers invalidate them. Current movement may differ from
the frozen displayed pose. No guest state, registers or emulated cycles change.

The optional launch context identifies the already-presented pass, VGA, start
RAM, original UI mask, actor, class and unique mesh owner. Godot requires an
already-completed production owner proof for that exact stamp, immutable mesh,
camera and UI. The existing same-owner, UI-clear, separated-pixel criterion is
unchanged. Missing, hidden, ambiguous, protected-line, stale or newly appearing
owners never acquire delayed permission.

For an eligible original request15, the existing effect player selects the
recorded stream once, at that request's existing onset. It does not play the old
request15 tone first. Without proof the original tone remains untouched.
Other-target launches use a separate once-only source token, without inventing
original event IDs. Muted, restored, duplicate and missed opportunities cannot
replay. Working if: genuine eligible firing admits at most one attack, every
failed proof keeps its original behavior, and source IDs/onsets/masks remain exact.

## Recording, balance and recovery

The private `local-audio/pc-rocket-effects-v1` bank contains one nonlooping
48kHz mono16 clip,115200frames. It uses the previously approved TOW-derived
launch texture as a generic stand-in. It is not labelled an authentic Sagger or
Spigot field recording. Original material, edits and provenance remain private
and recoverable. No additional purchase, agreement or audio upload occurred.

The attack uses the existing effects pool and conservative0.39 default gain.
The saved **Missiles** control manages attack and the existing visible-flight
fizz; other gains are unchanged. There is no second sustained tail. Native
rail-capture true peak was-15.1dBFS. Existing motor authority, crew, music and the
shared limiter remain unchanged. The final new companion/attack listening check
is pending Nell's response; it is separate from earlier approved previews.

Runtime core: `60f45558d61aaeaf5ab761fb1bd3fef95081d6eb0c4daffdee566b51af2af688`.
The prior37bff0core and receipt are preserved under `.runtime/pc-core/previous/`.
The exact-core save guard remains in force; prior-core saves are not silently
migrated or relabelled. The bank's removal restores stock-only attacks.

## Evidence and limits

`artifacts/rocket-trigger-20261028/verification.json` indexes the exact receipts.
Across four original-input suffixes,4754 every-frame RAM, paired-RAM, VGA and
original audio fences match old/new cores. A separate2144-frame comparison
against the actual default37bff0core also matches. Native rail and Spigot proof
uses genuine retained source passes and the actual painter/mixer, with controlled
host capture timing. These are functional proofs, not device audition, healthy-host
pacing or sustained performance measurements. Sagger has a genuine firing and
visibility-negative witness; no audible native Sagger positive is claimed.

The earlier full release gate remains incomplete because of its retained RAM
fixture mismatch. Focused passing checks do not close that gate. No standalone,
browser, packaging or publication operation was performed here. Rejected helper
runs and diagnostic-only counterfactual terrain queries remain separate from
actual original-game acceptance evidence.
