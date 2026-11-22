package gui

import "core:fmt"
import "core:time"

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

    perf_counter_periodic_report_start(&frontend, 1 * time.Second)
    defer perf_counter_periodic_report_stop(&frontend)

    for frontend.running {
        reaction := frontend_handle_event(&frontend)
        if .RequestRender not_in reaction do continue
        frontend_clear(&frontend)
        frontend_render_frame(&frontend)
    }

    return nil
}
