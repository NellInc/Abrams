# Install Abrams on Windows or Linux

The portable alpha bundles Godot, Python/Pillow and a native tracing core. No separate engine or interpreter is required.

**Supply the supported original PC game. Genesis is optional. Neither original game is included.**

## Install and play

1. Download the package for your platform from [GitHub Releases](https://github.com/NellInc/Abrams/releases). Choose the Windows or Linux x86_64 archive and its release checksums.
2. Extract the whole archive into a writable folder. Keep the folder structure intact.
3. On Windows, open **M1 Abrams Battle Tank Fan Remaster.exe**. **M1 Abrams Battle Tank Fan Remaster.cmd** is a diagnostic fallback. On Linux, run **M1 Abrams Battle Tank Fan Remaster.sh** from the extracted folder. If your extractor removed executable permissions, run `chmod +x "M1 Abrams Battle Tank Fan Remaster.sh" runtime/AbramsRuntime/AbramsRuntime renderer/AbramsRenderer` there.
4. Choose **Import PC folder** and select the complete extracted PC game folder containing `ABRAMS.COM`, `SIM.EXE` and its data files.
5. Optionally choose **Import Genesis ROM**. Then select **Play**.

The importer verifies the supported editions, leaves source files unchanged, and preserves existing profiles. Genesis alone cannot run the game. PC-only play offers EGA, PC-based Upscaled and Modern; importing Genesis enables its artwork and music.

Windows builds target x86_64 Windows 10 or newer. Linux builds target x86_64 with glibc 2.35 or newer and a working graphical desktop/OpenGL driver. These are alpha ports. Native build, frozen setup and synthetic core checks are separate from real-game playtesting on each platform. Consult the release notes for the tested boundaries. Intel Macs and ARM Linux are not included.

## Controls and profiles

**Ctrl+Alt+S** saves, **Ctrl+Alt+L** loads, **Ctrl+Alt+Shift+L** undoes a load, and **Ctrl+Alt+G** cycles graphics. The game's remaster menus provide all five save slots, graphics choices, audio levels and fast forward. Original controls are unchanged.

Profiles live outside the installation:

* Windows: `%LOCALAPPDATA%\Abrams`
* Linux: `$XDG_DATA_HOME/abrams`, or `~/.local/share/abrams`

The profile contains imported content, versioned installations, saves and logs. `ABRAMS_DATA_HOME` selects an alternative absolute directory. Keep backups and the previous alpha when upgrading. Checkpoints require the matching core/game compatibility; original campaign disk saves are separate.

Do not open two games against one profile. Close the game before closing setup. Moving the installation does not move or delete the profile.

## Troubleshooting

* **Import rejected:** choose the complete supported folder, not a ZIP or executables alone. See the supported file inventory in `tools/package/game-inputs.json`.
* **Genesis rejected:** use the supported raw ROM. Continue with PC-only play if unavailable.
* **Security warning:** Windows signing is not supplied in this alpha. Check the download source and release checksum; do not disable system security.
* **Linux will not start:** run `./"M1 Abrams Battle Tank Fan Remaster.sh"` in a terminal and retain the error. Check executable permissions and your graphics driver.
* **Verification/startup error:** preserve the displayed message and profile `logs/` (the game's console output is in `logs/game.log`). Do not alter manifests or delete saves to bypass integrity checks.
* **Imported game files changed:** choosing the PC folder again will not repair them. Restore the profile from a backup, or use a fresh data home (`ABRAMS_DATA_HOME`); the changed profile is kept for diagnosis.

The setup includes About, licences, the GitHub link, Nell Watson's remaster credit and the dedication to David “Ming” Kenny. See [rights and original game requirements](../NOTICE.md).
