# Private kit installation and recovery

## Current platform boundary

| Task | macOS ARM64 | macOS Intel | Linux | Windows |
| --- | --- | --- | --- | --- |
| Inspect/build source ZIP with Python 3.10+ | Supported source operation | Supported source operation | Supported source operation | Python source operation; shell-launcher tests require POSIX |
| Current supplied private native core | Local ARM64 build | Unsupported | Unsupported | Unsupported |
| Managed gameplay launcher | macOS ARM64 dependency gate | Rejected | Rejected | Rejected |

The source CI workflow is intended to run on Ubuntu. A passing source job is not
native Linux gameplay validation. No native Windows or Linux package is supplied.

## Fresh installation

1. Keep the original game and the previous kit unchanged. Extract the new private
   ZIP into a new writable directory, outside any player profile.
2. Verify the ZIP with `python3 tools/package_build.py --verify /absolute/path/to/kit.zip`.
   This checks its internal integrity. It is not a trusted publisher signature.
3. Use an existing native ARM64 Python 3.10+ environment with Pillow and an existing
   Godot 4.4+ executable. Set `ABRAMS_PYTHON` and `GODOT_BIN` if necessary. No launcher
   installs software or downloads dependencies.
4. Run `python3 tools/package_runtime.py --check` with that chosen Python. Missing
   dependencies, missing owned inputs, changed core/content fingerprints or missing
   allowlisted resources must be resolved before play. The check creates no profile
   or save files and starts no gameplay.
5. Run `sh Play.command` in the private kit. Paths containing spaces are supported.

For a source ZIP, follow [packaging.md](packaging.md) to import separately owned
originals, build the pinned core, and supply the reviewed presentation assets.
Importing originals alone does not make the source kit playable. The importer
validates every input and the reconstructed ZIP before creating output. A damaged
input or incomplete input manifest leaves the destination unchanged. Existing
GAME directories or content ZIPs, including dangling symlinks, are never replaced.
An I/O failure during final copying may leave a partial new destination; retain it
for diagnosis and retry into a different empty directory after fixing the cause.

## Upgrade and rollback

Player data defaults to `~/Library/Application Support/Abrams`. Use an absolute
`ABRAMS_DATA_HOME` outside the kit to select another profile. Keep that setting
identical across upgrades. The launcher refuses paths inside the kit, including
symlink aliases, and does not migrate, reset or delete a profile.

Close the game before taking a complete profile backup. Extract upgrades into
separate directories and retain the previous kit and backup. First run `--check`,
then launch. A failed dependency check leaves the existing profile untouched.
The managed launcher owns the save/log paths and rejects `--saves`, `--output`,
`--trace` and `--reference` overrides.

Snapshots are tied to their native core and content fingerprints. If a new core
rejects an older checkpoint, keep the checkpoint unchanged and return to its
matching old kit/profile backup. Never edit receipt hashes to force compatibility.
Treat damaged or untrusted local checkpoints as untrusted input. Retain the
original file, use the runtime's slot validity diagnostics, and restore a known
good whole-profile backup if necessary. Packaging tests exercise path custody;
the save-state tests and private runtime gates exercise checkpoint validation.

## Native port work still required

The current builder and bridge use `.dylib` paths and the local ARM64 macOS build
receipt. Renaming that library to `.so` or `.dll` does not port it. A Linux or
Windows port needs its own toolchain build of the pinned DOSBox Pure revision,
reviewed observer patches, platform-specific library loading and launcher paths,
and a recorded native build receipt. It must then pass the live protocol,
audio/video parity, complete campaign, save/load and interrupted-recovery gates
on that operating system. Reuse the existing Python/Godot front end and source
helpers; do not promise an installer or binary until those gates have evidence.
Working if: every supported native platform has its own runtime acceptance report,
and unsupported hosts still fail before loading an incompatible core.
