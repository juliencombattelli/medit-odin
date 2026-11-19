package gui

import "core:fmt"

import sdl "vendor:sdl3"

ErrorCode :: enum {
    FailedToStart,
}

Error :: union {
    ErrorCode,
}

run :: proc() -> Error {
    fmt.println("Running in GUI mode")

    frontend: Frontend
    defer frontend_destroy(&frontend)
    if !frontend_create(&frontend) do return .FailedToStart

    frontend.running = true
    frontend_show(&frontend)

    for frontend.running {
        frontend_handle_event(&frontend)

        sdl.RenderClear(frontend.renderer)
        sdl.RenderPresent(frontend.renderer)
    }

    return nil;
}
