#+private
#+build linux, darwin, netbsd, openbsd, freebsd
package term

import "core:sys/posix"

// Async-signal-safe: only uses write(2) and errno, no locks, allocations or
// buffering.
_write :: proc "contextless" (data: string) -> (ok: bool) {
    p := transmute([]byte)data
    for len(p) > 0 {
        n := posix.write(posix.STDOUT_FILENO, raw_data(p), len(p))
        if n < 0 {
            if posix.errno() == .EINTR do continue
            return false
        }
        p = p[n:]
    }
    return true
}

@(private = "file")
g_orig: posix.termios

_save_mode :: proc "contextless" () -> (ok: bool) {
    return posix.tcgetattr(posix.STDIN_FILENO, &g_orig) == .OK
}

_apply_raw_mode :: proc "contextless" () -> (ok: bool) {
    raw := g_orig
    // Disable canonical mode (line buffering), echo, and signals (Ctrl+C / Ctrl+Z)
    raw.c_lflag &~= {.ECHO, .ICANON, .ISIG, .IEXTEN}
    // Disable Ctrl+S/Ctrl+Q flow control and CR-to-NL translation
    raw.c_iflag &~= {.IXON, .ICRNL}
    // Disable output post-processing (e.g. \n -> \r\n)
    raw.c_oflag &~= {.OPOST}

    // Read returns as soon as 1 byte is available, with no timeout
    raw.c_cc[.VMIN] = 1
    raw.c_cc[.VTIME] = 0

    return posix.tcsetattr(posix.STDIN_FILENO, .TCSAFLUSH, &raw) == .OK
}

_restore_mode :: proc "contextless" () {
    posix.tcsetattr(posix.STDIN_FILENO, .TCSAFLUSH, &g_orig)
}

// Fatal signals (crashes, Odin traps) and termination requests.
// SIGKILL/SIGSTOP cannot be caught.
@(private = "file")
CLEANUP_SIGNALS :: [?]posix.Signal {
    .SIGHUP,
    .SIGINT,
    .SIGQUIT,
    .SIGTERM,
    .SIGPIPE,
    .SIGILL,
    .SIGTRAP,
    .SIGABRT,
    .SIGBUS,
    .SIGFPE,
    .SIGSEGV,
    .SIGSYS,
}

@(private = "file")
g_prev_actions: [len(CLEANUP_SIGNALS)]posix.sigaction_t

_install_signal_handlers :: proc "contextless" () {
    signals := CLEANUP_SIGNALS
    for sig, i in signals {
        act: posix.sigaction_t
        act.sa_handler = _signal_handler
        posix.sigemptyset(&act.sa_mask)
        if posix.sigaction(sig, &act, &g_prev_actions[i]) != .OK do continue
        // Keep ignored signals ignored (e.g. SIGHUP under nohup)
        if rawptr(g_prev_actions[i].sa_handler) == posix.SIG_IGN {
            posix.sigaction(sig, &g_prev_actions[i], nil)
        }
    }
}

// Restores the terminal, reinstates the previous disposition and re-raises,
// so the process still terminates (or core dumps) as it would have without this
// handler, or chains to a prior handler.
@(private = "file")
_signal_handler :: proc "c" (sig: posix.Signal) {
    saved_errno := posix.errno()
    deinit()
    signals := CLEANUP_SIGNALS
    for s, i in signals {
        if s == sig {
            posix.sigaction(sig, &g_prev_actions[i], nil)
            break
        }
    }
    posix.raise(sig) // Blocked while we run, will be delivered after we return
    posix.errno(saved_errno)
}
