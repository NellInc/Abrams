# Source-only CI and Git boundary

The `Source-only safeguards` workflow runs on pushes and pull requests and can be
started manually. It uses a read-only GitHub token, does not persist checkout
credentials, and does not upload artifacts, publish packages, build native cores,
or obtain either game. Third-party actions are pinned to complete commit hashes.
The reviewed upstream documentation is [actions/checkout](https://github.com/actions/checkout)
and [actions/setup-python](https://github.com/actions/setup-python).

Run the same checks locally with Python 3.10+ and Git:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m tools.package.git_boundary --history
PYTHONDONTWRITEBYTECODE=1 python3 -m tools.package.source_ci
```

The first command reads the complete index and every tree reachable from local
Git refs. It checks staged bytes even when the working file has subsequently been
cleaned. A file deleted in a later commit remains checked. Shallow history fails
closed; the workflow fetches full history. No Git data is modified.

The boundary rejects:

* Original `GAME` and `GENESIS` directory names, including case variants and
  nested copies; runtime, capture, save, artifact and private working directories.
* Executable, ROM, state, native library, archive and credential-container formats.
* Renamed files matching the existing 68 PC input SHA-256 pins, the canonical
  Genesis ROM pin, or the pinned PC content archive.
* Environment files, recognizable private-key headers and common GitHub, AWS
  access-key-ID and OpenAI token signatures. Matching bytes are never printed.
* Files larger than 50,000,000 bytes, symlinks, submodules and unresolved indexes.

Before a commit, run `python3 -m tools.package.git_boundary` after staging only
the intended files. Before a push, include `--history`. These are explicit local
checks; no Git hooks are installed. CI can detect a bad push only after the bytes
have reached GitHub. Configure a required status check separately if merge
blocking is desired; merely adding a workflow does not configure branch rules.
Working if: synthetic prohibited-file tests fail closed and the candidate index
plus reachable history pass before publication.

The source gate builds and verifies the allowlisted source ZIP, extracts it into
a new temporary directory, asserts that private input directories are absent,
and runs packaging, dependency, Git-boundary and launcher tests under `python -S`.
This disables site packages, so Pillow, Godot, native cores and owned game files
cannot accidentally satisfy these tests. Native dependency checks are simulated;
no Windows, Linux or macOS gameplay is certified by this gate. Original-dependent
packaging tests are explicitly skipped. The complete private runtime and campaign
acceptance gates remain separate.

## Limits

The repository already contains generated presentation assets and extracted
text fixtures; these are outside the source ZIP but may remain in the private
GitHub repository. Their presence is not rights clearance. See
[release-rights.md](release-rights.md).

Fingerprint checks detect known byte-identical inputs. They do not prove that
arbitrarily transformed or repackaged content is cleared. Secret signatures are
bounded detection, not a complete secret audit. Review staged diffs, keep actual
credentials in Keychain, and never rely on an ignore rule to hide a tracked file.
The history scan covers reachable refs available locally, not deleted remote
refs, reflogs or inaccessible objects. If it reports a credential or original,
stop the push, preserve evidence without redisplaying secrets, and resolve the
exposure and history deliberately.
