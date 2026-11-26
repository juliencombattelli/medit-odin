package term

import "base:intrinsics"
import "base:runtime"
import "core:c/libc"
import "core:terminal/ansi"

// Set once the original mode is saved. Atomic because `deinit` may run from a
// signal handler or another thread, and must undo the terminal changes exactly
// once.
@(private = "file")
g_active: bool
@(private = "file")
g_handlers_installed: bool

// Saves the terminal state, then enters raw mode and the alternate screen with
// a hidden cursor.
// Also registers `deinit` to run on libc `exit`, fatal/termination signals
// (POSIX) and console close events / unhandled exceptions (Windows), and on
// POSIX a SIGWINCH handler feeding `read`'s resize events.
// Panics must be handled by the caller through `context.assertion_failure_proc`
// using `assertion_failure_proc` below.
// Odin's `os.exit` may bypass all of these: as of Odin 2026.10, on Linux
// exit_group is called, and on Windows ExitProcess is called).
init :: proc "contextless" () -> (ok: bool) {
    if intrinsics.atomic_load(&g_active) do return true
    if !intrinsics.atomic_exchange(&g_handlers_installed, true) {
        libc.atexit(proc "c" () {deinit()})
        _install_signal_handlers()
    }
    _save_mode() or_return
    // Mark active before changing anything so an interruption mid-init still
    // leads to a restore
    intrinsics.atomic_store(&g_active, true)
    // Raw mode first: on Windows it enables the VT processing the escape
    // sequences rely on
    enter_alternate_screen_buffer :: ansi.CSI + ansi.DECASB_ENTER
    hide_text_cursor :: ansi.CSI + ansi.DECTCEM_HIDE
    if !_apply_raw_mode() ||
       !_write(enter_alternate_screen_buffer + hide_text_cursor) {
        deinit()
        return false
    }
    return true
}

assertion_failure_proc :: proc(
    prefix, message: string,
    loc: runtime.Source_Code_Location,
) -> ! {
    deinit() // restore first so the panic message prints on a usable screen
    runtime.default_assertion_failure_proc(prefix, message, loc)
}

// Restores the terminal state saved by `init`. Safe to call multiple times:
// only the first call after `init` does anything, later ones are no-ops.
// Also async-signal-safe.
deinit :: proc "contextless" () {
    if !intrinsics.atomic_exchange(&g_active, false) do return
    // Emit escape sequences before restoring the mode so they are drained
    // before the input flush
    show_text_cursor :: ansi.CSI + ansi.DECTCEM_SHOW
    exit_alternate_screen_buffer :: ansi.CSI + ansi.DECASB_EXIT
    _write(show_text_cursor + exit_alternate_screen_buffer)
    _restore_mode()
}

// Writes directly to stdout with the lowest-level OS primitive
// (no buffering, locks or allocations).
write :: proc "contextless" (data: string) -> (ok: bool) {
    return _write(data)
}

ByteEvent :: distinct byte
ResizeEvent :: struct {}
EofEvent :: struct {}

ReadEvent :: union {
    ByteEvent,
    ResizeEvent,
    EofEvent,
}

ReadError :: enum {
    None,
    Unknown,
}

read :: proc() -> (ReadEvent, ReadError) {
    return _read()
}

get_size :: proc "contextless" () -> (cols, rows: int, ok: bool) {
    return _get_size()
}

show_cursor :: proc "contextless" () {
    _write(ansi.CSI + ansi.DECTCEM_SHOW)
}

hide_cursor :: proc "contextless" () {
    _write(ansi.CSI + ansi.DECTCEM_HIDE)
}
