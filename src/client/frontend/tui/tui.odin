package tui

import "core:fmt"

import "medit:client/frontend/tui/term"

FailedToStart :: struct {
    stdin_not_a_tty:  bool,
    stdout_not_a_tty: bool,
    msg:              string,
}

Error :: union {
    FailedToStart,
}

run :: proc() -> Error {
    fmt.println("Running in TUI mode")

    available() or_return

    context.assertion_failure_proc = term.assertion_failure_proc
    if !term.init() {
        return FailedToStart{msg = "failed to initialise the terminal"}
    }
    defer term.deinit()

    return nil
}
