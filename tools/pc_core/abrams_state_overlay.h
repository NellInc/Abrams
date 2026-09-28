/* Local checkpoint ABI 1, included after unionDriveImpl is defined.
 * Called only while the emulation worker is paused. Ordinary execution never
 * calls these helpers. A fresh host boot can mutate transient game files before
 * unserialize, so restore must reload the saved overlay before recreating file
 * handles. The immutable underlying content drive is retained unchanged.
 */
bool unionDrive::AbramsReloadSave() {
    if (!impl->save_mem || impl->save_file.empty() || !impl->autodelete_over)
        return false;
    ForceCloseAll(); // replace boot handles before deleting their backing store
    DOS_Drive* under = impl->under;
    const bool owns_under = impl->autodelete_under;
    const std::string path = impl->save_file;
    PIC_RemoveSpecificEvents(unionDriveImpl::WriteSaveFile, (Bitu)impl);
    impl->dirty = false; // deliberately discard only fresh-boot modifications
    impl->autodelete_under = false;
    delete impl;
    impl = new unionDriveImpl(under, NULL, path.c_str(), owns_under, false, false);
    return true;
}

bool unionDrive::AbramsFlushSave() {
    if (!impl->save_mem || impl->save_file.empty()) return false;
    unionDriveImpl::WriteSaveFile((Bitu)impl);
    return !impl->dirty;
}

extern "C" __attribute__((visibility("default")))
unsigned abrams_state_overlay_abi() { return 1; }

extern "C" __attribute__((visibility("default")))
bool abrams_state_reload_overlay() {
    unionDrive* drive = dynamic_cast<unionDrive*>(Drives[2]);
    return drive && drive->AbramsReloadSave();
}

extern "C" __attribute__((visibility("default")))
bool abrams_state_flush_overlay() {
    unionDrive* drive = dynamic_cast<unionDrive*>(Drives[2]);
    return drive && drive->AbramsFlushSave();
}
