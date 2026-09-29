/* Tiny Windows launcher; all provisioning remains in the verified Python kit. */
#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#include <windows.h>
#include <wchar.h>
#include <stdlib.h>

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE previous, PWSTR arguments, int show) {
    (void)instance; (void)previous; (void)show;
    wchar_t executable[32768];
    DWORD length = GetModuleFileNameW(NULL, executable, 32768);
    if (!length || length >= 32768) return 1;
    wchar_t *slash = wcsrchr(executable, L'\\');
    if (!slash) return 1;
    *slash = 0;
    const wchar_t *relative = L"\\runtime\\AbramsRuntime\\AbramsRuntime.exe";
    size_t capacity = wcslen(executable) + wcslen(relative) + wcslen(arguments) + 32;
    wchar_t *runtime = calloc(capacity, sizeof(wchar_t));
    wchar_t *command = calloc(capacity, sizeof(wchar_t));
    if (!runtime || !command) { free(runtime); free(command); return 1; }
    wcscpy(runtime, executable); wcscat(runtime, relative);
    swprintf(command, capacity, L"\"%ls\" --launcher %ls", runtime, arguments);
    STARTUPINFOW startup = {0}; startup.cb = sizeof(startup);
    PROCESS_INFORMATION child = {0};
    BOOL started = CreateProcessW(runtime, command, NULL, NULL, FALSE, CREATE_NO_WINDOW,
                                  NULL, executable, &startup, &child);
    free(runtime); free(command);
    if (!started) {
        MessageBoxW(NULL, L"The bundled runtime could not start. Keep the complete Abrams folder together.", L"Abrams", MB_OK | MB_ICONERROR);
        return 1;
    }
    WaitForSingleObject(child.hProcess, INFINITE);
    DWORD code = 1;
    GetExitCodeProcess(child.hProcess, &code);
    CloseHandle(child.hThread); CloseHandle(child.hProcess);
    if (code) MessageBoxW(NULL, L"Abrams could not start or the game reported an error. Check the player data logs and restore an intact release folder.", L"Abrams", MB_OK | MB_ICONERROR);
    return (int)code;
}
