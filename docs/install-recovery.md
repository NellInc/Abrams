# Installation and recovery

## Standalone app

Native alpha candidates exist for Apple Silicon macOS 14 or newer, x86_64
Windows 10 or newer, and x86_64 Linux with glibc 2.35 or newer. Godot and
Python/Pillow are bundled. **Supply the original PC files; Genesis is optional.
Neither is bundled.** Open M1 Abrams Battle Tank Fan Remaster, choose the PC
folder, optionally add the Genesis ROM, then click Play. See the installation
guides for [macOS](standalone-macos.md) and [Windows/Linux](standalone-portable.md).

Saves and imported content live outside the app: `~/Library/Application Support/Abrams/`
on macOS, `%LOCALAPPDATA%\Abrams` on Windows, and `$XDG_DATA_HOME/abrams`
(or `~/.local/share/abrams`) on Linux. Close the game and back up that whole folder before upgrading. Keep the
previous app, copy the new app separately and use the same profile. Each app's
payload installs into its own `versions/<build-id>/` directory; upgrades retain
existing content, saves and older versions.

New checkpoints preserve the remastered display as well as native game and
campaign state. Legacy same-core checkpoints may temporarily show PC artwork
until the game redraws it. Checkpoints are keyed to the core's pre-signing
identity, so re-signing an unchanged core keeps them compatible. Slots saved
by a Developer ID build made before this change still need that build. A changed
core can make checkpoints incompatible;
retain the old app and profile backup rather than modifying receipt hashes.
The original campaign save system remains separate from save-state slots.

For an independent test profile, use the launcher's `--data-home /absolute/path`
option. It works alike for the macOS app, the Windows `.exe`/`.cmd` and the Linux
`.sh` launcher. The path is validated as absolute and outside the application
(including miscased paths into it), and every setup request inherits it.
No profile is automatically deleted, migrated or repaired.

### Portable setup recovery

Windows/Linux setup has a **Recheck installation** action. If the bundled runtime is missing or verification cannot start, controls recover immediately and name the repair/recheck route. Only correctly typed verified status enables Play; a failed recheck clears the earlier verification state. The PC picker requests an extracted folder containing ABRAMS.COM and SIM.EXE. The optional Genesis picker accepts supported raw `.md`, `.bin` or `.gen` ROMs; the importer still checks the exact revision.

At small windows, the content scrolls while Recheck, references, About and Play remain reachable. Keyboard focus follows the scroll content. Original files and saves are never automatically deleted or repaired. Setup requests retain their five-minute deadline; gameplay has no launcher timeout. Runtime output retains bounded diagnostic tails. Timeout cleanup targets only the directly created child, never a foreign session or controller.

## Developer-kit platform boundary

| Task | macOS ARM64 | macOS Intel | Linux | Windows |
| --- | --- | --- | --- | --- |
| Inspect/build source ZIP with Python 3.10+ | Supported source operation | Supported source operation | Supported source operation | Python source operation; shell-launcher tests require POSIX |
| Current supplied private native core | Local ARM64 build | Unsupported | Unsupported | Unsupported |
| Managed gameplay launcher | macOS ARM64 dependency gate | Rejected | Rejected | Rejected |

This table describes legacy shell developer kits. The standalone Windows/Linux
packages use separate native builders and launchers. A passing source-only job
does not prove native gameplay on any platform.

## Legacy developer-kit installation

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

## Legacy developer-kit upgrade and rollback

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

## Platform acceptance

Windows and Linux candidates are built natively with their own pinned tracing
core and frozen runtime. Their CI checks cover original-free core execution,
checkpoints, setup/About, source correspondence and package integrity. Original
PC files are never uploaded to CI. Actual game playback, graphics/audio and
campaign outcomes on those operating systems still need equipped target-machine
tests. Intel Macs and ARM Linux are unsupported. Consult each release's notes
for the exact acceptance boundary.

## Browser keyboard recovery

Before import and after engine shutdown the inactive player frame is hidden. An early import/download error keeps the retry action focused. After engine initialization or an original-worker failure, Reload page receives keyboard focus. The original failure text remains visible through normal engine exit; checkpoint storage is retained. A dead canvas cannot continue accepting game input.

## Renderer preflight and unfinished installation recovery

Desktop startup checks each current Godot import/check-only log segment as well as its exit code. Parse, script, shader and engine errors stop before the game is launched. Each preflight command has a 300-second deadline; gameplay retains its existing lifetime and shutdown path. The complete output remains in the player profile's `logs/application.log`, and an error identifies that path. Old errors from earlier launches do not invalidate a clean current check. Managed-log leaf checks prevent an unexpected link from redirecting a write.

A new version's copied payload, original PC files and reconstructed archive are checked before its unfinished directory is renamed into an accepted version. Original-file expectations are captured from the hash-verified application manifest, so a later application-file edit cannot redefine valid content during copying. A corrupt successful copy is refused just like an incomplete copy.

A failed version copy, verification or promotion removes only its unique unfinished `.install-*` directory. Accepted versions, imported originals and campaigns remain intact. After correcting the reported cause, retry the same verified application and build ID. An already accepted version that has subsequently changed is preserved for diagnosis and is never repaired in place.

Working if: a failed new copy leaves no accepted version or unfinished directory, a clean same-build retry succeeds, and originals, existing installations and campaign files retain their exact bytes.

In the browser, **Clear Genesis ROM** removes only the optional selection, preserves the PC folder and confirms PC-only retry. The action is disabled while startup/gameplay owns those inputs. Required original basenames still receive strict collision, size and fingerprint checks; unrelated folder extras are ignored without reading their contents.
