package main

import "core:flags"
import "core:fmt"
import "core:os"

import "medit:client/frontend/gui"
import "medit:client/frontend/tui"

Frontend :: enum {
    auto,
    gui,
    tui,
}

Options :: struct {
    frontend: Frontend `usage:"Frontend the client must use: gui or tui."`,
}

main :: proc() {
    opt: Options
    flags.parse_or_exit(&opt, os.args, flags.Parsing_Style.Odin)

    switch opt.frontend {
    case .auto:
        switch gui.run() {
        case .FailedToStart: // fallback to tui
        case nil:
            os.exit(0)
        case:
            os.exit(1)
        }
        switch err in tui.run() {
        case tui.FailedToStart:
            fmt.printfln("TUI not available: %s", err.msg)
            fmt.println("Neither the GUI nor the TUI is available, exiting.")
            os.exit(1)
        case nil:
            os.exit(0)
        case:
            os.exit(1)
        }
    case .gui:
        gui.run()
    case .tui:
        tui.run()
    }
}
