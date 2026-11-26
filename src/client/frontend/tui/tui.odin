package tui

import "core:fmt"

import "medit:client/frontend/tui/term"
import kb "medit:client/keybind"

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

    keybinds := kb.Keybinds{}

    running := true
    for running {
        event := term.read() or_break
        switch type in event {
            case term.ByteEvent:
                fmt.printf("Received byte %d\r\n", event)
                // kb_event := kb.Event{...}
                // kb.handle_event(&keybinds)
            case term.ResizeEvent:
                fmt.printf("Received resize event\r\n")
            case term.EofEvent:
                fmt.printf("Received EOF\r\n")
        }
    }

    return nil
}
