package tui

import "core:fmt"

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

    return nil
}
