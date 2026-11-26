#+private
#+build linux, darwin, netbsd, openbsd, freebsd
package term

import "core:c"
import "core:sys/posix"

@(private = "file")
g_orig: posix.termios

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

// Self-pipe: the SIGWINCH handler writes to [1] to wake up `_read`, which
// polls [0] along with stdin. A signal can't get lost between checking for a
// resize and blocking, whichever thread it is delivered to.
@(private = "file")
g_winch_pipe: [2]posix.FD = {-1, -1}

// Returns a `ResizeEvent` before pending input, coalescing all resizes since
// the previous call.
_read :: proc() -> (ReadEvent, ReadError) {
    fds := [2]posix.pollfd {
        {fd = posix.STDIN_FILENO, events = {.IN}},
        {fd = g_winch_pipe[0], events = {.IN}}, // ignored by poll if -1
    }
    for {
        if posix.poll(raw_data(fds[:]), len(fds), -1) == -1 {
            if posix.errno() == .EINTR do continue
            return nil, .Unknown
        }
        if .IN in fds[1].revents {
            buf: [64]u8
            for posix.read(g_winch_pipe[0], raw_data(buf[:]), len(buf)) > 0 {}
            return ResizeEvent{}, .None
        }
        // Also covers HUP/ERR, so a hangup is reported instead of spinning
        if fds[0].revents != {} {
            b: u8
            switch posix.read(posix.STDIN_FILENO, &b, 1) {
            case 1:
                return ByteEvent(b), .None
            case 0:
                return EofEvent{}, .None
            case:
                if posix.errno() == .EINTR || posix.errno() == .EAGAIN do continue
                return nil, .Unknown
            }
        }
    }
}

// ioctl isn't in POSIX, so core:sys/posix doesn't bind it.
when ODIN_OS == .Darwin {
    foreign import libc "system:System.framework"
} else {
    foreign import libc "system:c"
}

@(default_calling_convention = "c")
foreign libc {
    ioctl :: proc(fd: posix.FD, request: c.ulong, #c_vararg args: ..any) -> c.int ---
}

// The request code depends on the OS:
// - Linux: 0x5413 on x86, arm, arm64 and riscv (all targets Odin supports)
// - BSDs and Darwin: _IOR('t', 104, struct winsize)
@(private = "file")
TIOCGWINSZ :: c.ulong(0x5413 when ODIN_OS == .Linux else 0x40087468)

@(private = "file")
winsize :: struct {
    ws_row, ws_col, ws_xpixel, ws_ypixel: c.ushort,
}

_get_size :: proc "contextless" () -> (cols, rows: int, ok: bool) {
    ws: winsize
    if ioctl(posix.STDOUT_FILENO, TIOCGWINSZ, &ws) == -1 do return
    // Some terminals (e.g. serial consoles) succeed but report 0
    if ws.ws_col == 0 || ws.ws_row == 0 do return
    return int(ws.ws_col), int(ws.ws_row), true
}

_save_mode :: proc "contextless" () -> (ok: bool) {
    return posix.tcgetattr(posix.STDIN_FILENO, &g_orig) == .OK
}

_apply_raw_mode :: proc "contextless" () -> (ok: bool) {
    raw := g_orig

    raw.c_lflag -= {
        .ISIG,   // Disable signal generation (SIGINT, SIGTSTP, SIGQUIT)
        .ICANON, // Disable canonical mode (line buffering)
        .ECHO,   // Disable echoing of input characters
        .ECHONL, // Disable echoing of NL
        .IEXTEN, // Disable extended input processing (e.g. Ctrl-V)
    }

    raw.c_iflag -= {
        .BRKINT, // Do not signal interrupt on break
        .INPCK,  // Disable input parity checking
        .ISTRIP, // Disable stripping of eighth bit
        .INLCR,  // Disable mapping of NL to CR on input
        .IGNCR,  // Disable ignoring CR on input
        .ICRNL,  // Disable mapping of CR to NL on input
        .IXON,   // Disable software flow control
    }

    raw.c_oflag -= {
        .OPOST,  // Disable output post-processing (e.g. \n -> \r\n)
    }

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
    _install_winch_handler()
}

// Not in core:sys/posix (only standardized in POSIX.1-2024), but 28 on every
// supported OS
@(private = "file")
SIGWINCH :: posix.Signal(28)

// Separate from CLEANUP_SIGNALS: a resize must not restore the terminal.
@(private = "file")
_install_winch_handler :: proc "contextless" () {
    // Pipe first, so the handler never writes to an invalid or reused fd
    if posix.pipe(&g_winch_pipe) != .OK {
        g_winch_pipe = {-1, -1} // `_read` then never reports resizes
        return
    }
    for fd in g_winch_pipe {
        // Non-blocking: the handler must never block on a full pipe, and
        // `_read` drains it until empty
        flags := transmute(posix.O_Flags)posix.fcntl(fd, .GETFL)
        posix.fcntl(fd, .SETFL, transmute(c.int)(flags + {.NONBLOCK}))
        posix.fcntl(fd, .SETFD, c.int(posix.FD_CLOEXEC))
    }
    act: posix.sigaction_t
    act.sa_handler = _winch_handler
    act.sa_flags = {.RESTART}
    posix.sigemptyset(&act.sa_mask)
    posix.sigaction(SIGWINCH, &act, nil)
}

// Async-signal-safe: only write(2) and errno. If the pipe is full a wakeup is
// already pending, so dropping the byte is fine.
@(private = "file")
_winch_handler :: proc "c" (sig: posix.Signal) {
    saved_errno := posix.errno()
    b: u8 = 1
    posix.write(g_winch_pipe[1], &b, 1)
    posix.errno(saved_errno)
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
