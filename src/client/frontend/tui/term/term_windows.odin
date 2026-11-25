#+private
package term

import "core:sys/windows"

@(private = "file")
g_stdin: windows.HANDLE
@(private = "file")
g_stdout: windows.HANDLE
@(private = "file")
g_orig_in_mode: windows.DWORD
@(private = "file")
g_orig_out_mode: windows.DWORD
@(private = "file")
g_prev_exception_filter: windows.LPTOP_LEVEL_EXCEPTION_FILTER

// Bypasses core:os, whose Windows write path takes a mutex.
_write :: proc "contextless" (data: string) -> (ok: bool) {
    stdout := g_stdout
    if stdout == nil do stdout = windows.GetStdHandle(windows.STD_OUTPUT_HANDLE)
    if stdout == nil || stdout == windows.INVALID_HANDLE_VALUE do return false

    p := transmute([]byte)data
    for len(p) > 0 {
        written: windows.DWORD
        chunk := windows.DWORD(min(len(p), int(max(windows.DWORD))))
        if !windows.WriteFile(stdout, raw_data(p), chunk, &written, nil) do return false
        p = p[written:]
    }
    return true
}

_save_mode :: proc "contextless" () -> (ok: bool) {
    stdin := windows.GetStdHandle(windows.STD_INPUT_HANDLE)
    stdout := windows.GetStdHandle(windows.STD_OUTPUT_HANDLE)
    if stdin == nil || stdin == windows.INVALID_HANDLE_VALUE do return false
    if stdout == nil || stdout == windows.INVALID_HANDLE_VALUE do return false
    if !windows.GetConsoleMode(stdin, &g_orig_in_mode) do return false
    if !windows.GetConsoleMode(stdout, &g_orig_out_mode) do return false
    g_stdin, g_stdout = stdin, stdout
    return true
}

_apply_raw_mode :: proc "contextless" () -> (ok: bool) {
    // Disable line buffering, echo, and Ctrl+C signal processing
    in_mode :=
        g_orig_in_mode &~
        (windows.ENABLE_ECHO_INPUT |
                windows.ENABLE_LINE_INPUT |
                windows.ENABLE_PROCESSED_INPUT)
    // Interpret ANSI escape sequences (alternate screen, cursor, ...)
    out_mode := g_orig_out_mode | windows.ENABLE_VIRTUAL_TERMINAL_PROCESSING
    if !windows.SetConsoleMode(g_stdin, in_mode) do return false
    if !windows.SetConsoleMode(g_stdout, out_mode) do return false
    return true
}

_restore_mode :: proc "contextless" () {
    windows.SetConsoleMode(g_stdin, g_orig_in_mode)
    windows.SetConsoleMode(g_stdout, g_orig_out_mode)
}

_install_signal_handlers :: proc "contextless" () {
    windows.SetConsoleCtrlHandler(_console_ctrl_handler, true)
    g_prev_exception_filter = windows.SetUnhandledExceptionFilter(
        _unhandled_exception_filter,
    )
}

// Runs on a separate thread for console close, logoff and shutdown events.
@(private = "file")
_console_ctrl_handler :: proc "system" (
    ctrl_type: windows.DWORD,
) -> windows.BOOL {
    deinit()
    return false // let the next handler (default: ExitProcess) run
}

// Covers crashes and Odin traps (bounds checks, type assertions) when no
// debugger is attached.
@(private = "file")
_unhandled_exception_filter :: proc "system" (
    info: ^windows.EXCEPTION_POINTERS,
) -> windows.LONG {
    deinit()
    if g_prev_exception_filter != nil do return g_prev_exception_filter(info)
    return windows.EXCEPTION_CONTINUE_SEARCH
}
