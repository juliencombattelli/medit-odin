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

// ReadFile may return several bytes at once (e.g. a multi-byte character):
// the extra ones are served from here on the next calls.
@(private = "file")
g_in_buf: [64]u8
@(private = "file")
g_in_pos, g_in_len: int

// Returns a `ResizeEvent` for console resize records (ENABLE_WINDOW_INPUT),
// coalescing consecutive ones.
_read :: proc() -> (ReadEvent, ReadError) {
    if g_in_pos < g_in_len {
        g_in_pos += 1
        return ByteEvent(g_in_buf[g_in_pos - 1]), .None
    }
    rec: windows.INPUT_RECORD
    n: windows.DWORD
    for {
        if windows.WaitForSingleObject(g_stdin, windows.INFINITE) !=
           windows.WAIT_OBJECT_0 {
            return nil, .Unknown
        }
        if !windows.PeekConsoleInputW(g_stdin, &rec, 1, &n) do return nil, .Unknown
        if n == 0 do continue
        is_text :=
            rec.EventType == .KEY_EVENT &&
            bool(rec.Event.KeyEvent.bKeyDown) &&
            rec.Event.KeyEvent.uChar.UnicodeChar != 0
        if is_text do break
        // Consume records ReadFile would skip (focus, mouse, key releases...),
        // else it would block until the next key press
        if !windows.ReadConsoleInputW(g_stdin, &rec, 1, &n) do return nil, .Unknown
        if rec.EventType != .WINDOW_BUFFER_SIZE_EVENT do continue
        for windows.PeekConsoleInputW(g_stdin, &rec, 1, &n) &&
            n == 1 &&
            rec.EventType == .WINDOW_BUFFER_SIZE_EVENT {
            windows.ReadConsoleInputW(g_stdin, &rec, 1, &n)
        }
        return ResizeEvent{}, .None
    }
    read: windows.DWORD
    if !windows.ReadFile(g_stdin, &g_in_buf, len(g_in_buf), &read, nil) {
        return nil, .Unknown
    }
    if read == 0 do return EofEvent{}, .None
    g_in_pos, g_in_len = 1, int(read)
    return ByteEvent(g_in_buf[0]), .None
}

_get_size :: proc "contextless" () -> (cols, rows: int, ok: bool) {
    info: windows.CONSOLE_SCREEN_BUFFER_INFO
    if !windows.GetConsoleScreenBufferInfo(g_stdout, &info) do return
    // srWindow is the visible area, dwSize includes the scrollback
    w := info.srWindow
    return int(w.Right - w.Left) + 1, int(w.Bottom - w.Top) + 1, true
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
    // Disable line buffering, echo, and Ctrl+C signal processing.
    // Report console resizes as input records, turned into `ResizeEvent`s by
    // `_read`.
    in_mode :=
        (g_orig_in_mode | windows.ENABLE_WINDOW_INPUT) &~
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
