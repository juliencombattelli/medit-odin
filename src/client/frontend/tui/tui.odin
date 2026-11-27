package tui

import "core:fmt"
import "core:os"

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

    // Open or create the log file
    file_handle, err := os.open(
        "medit.log",
        os.O_WRONLY | os.O_CREATE | os.O_TRUNC,
        os.perm(0o644),
    )
    if err != nil {
        fmt.println("Failed to open file:", err)
        return FailedToStart{}
    }
    defer os.close(file_handle)
    // Save the original stderr and redirect it to the file
    original_stderr := os.stderr
    os.stderr = file_handle
    defer os.stderr = original_stderr

    context.assertion_failure_proc = term.assertion_failure_proc
    if !term.init() {
        return FailedToStart{msg = "failed to initialise the terminal"}
    }
    defer term.deinit()

    decoder := KeyDecoder{}
    running := true

    keybinds := kb.Keybinds{}
    kb.bind(
        &keybinds, .Q, {.Ctrl},
        proc(userdata: rawptr) {
            fmt.eprintln("Exiting!")
            (cast(^bool)userdata)^ = false
        },
        &running
    )

    for running {
        uevent := term.read() or_break
        switch event in uevent {
        case term.ByteEvent:
            if kb_event, ok := key_decoder_feed(&decoder, byte(event)); ok {
                kb.handle_event(&keybinds, &kb_event)
            }
        case term.ResizeEvent: fmt.eprintfln("Received resize event")
        case term.EofEvent: fmt.eprintfln("Received EOF")
        }
    }

    return nil
}
