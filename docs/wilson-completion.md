# Remaining Wilson performances

Three additional high-resolution portraits cover the original CO.BMP performances:

| Original pose | Performance | Original origin | Visible portrait rectangle |
|---|---|---|---|
| 3 | Stern, right arm lowered | 84, 36 | 84, 36, 136, 130 |
| 4 | Stern, pistol held upright | 82, 36 | 82, 36, 138, 130 |
| 5 | Smiling, right-hand thumbs-up | 66, 33 | 66, 33, 148, 132 |

The portraits preserve the approved Genesis-derived Wilson identity, reflective
aviator glasses, moustache, olive uniform and illustrated contours. They are new
authored performances of that design. Exact matching Genesis animation frames
have not been recovered.

The original PC program continues to choose each performance and its timing.
Both BRIEF and END contain the same six-entry placement table. Recognition uses
the complete original office and portrait pixels above an original dialogue
border, including the difference between transparent palette index 0 and opaque
black index 11. Changed or incomplete compositions remain original.

## Local assets and reproduction

The three RGBA images and their generation prompts, reference and checksums are
in `local-art/genesis/remastered/wilson-completion-v1/`. Source recognition
fixtures and the supplemental catalog are in `local-art/pc-wilson-completion-v1/`.
These private assets remain outside the source repository.

```sh
python3 -m tools.build_pc_wilson_completion
python3 -m unittest tests.test_pc_wilson_completion -v
```

The builder verifies the original OFFICE, CO.BMP, BRIEF.EXE and END.EXE hashes,
checks both executable placement tables, and records each authored image's
checksum, dimensions and alpha bounds. It writes three supplemental templates;
the existing frontend renderer retains its program, full-prefix and dialogue
border checks when loading them.
