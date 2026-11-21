package gui

import "base:runtime"
import "core:fmt"
import "core:time"

import sdl "vendor:sdl3"

import "medit:util/perf"

_counter_periodic_report_callback :: proc "c" (
    userdata: rawptr,
    timerID: sdl.TimerID,
    interval: sdl.Uint32,
) -> sdl.Uint32 {
    context = runtime.default_context()
    frontend := cast(^Frontend)userdata
    if frontend.perf_counter.frame_count == 0 {
        fmt.printfln("Active frames: %d", frontend.perf_counter.frame_count)
    } else {
        fmt.printfln("Active frames: %d | Avg frame time: %.2f",
            frontend.perf_counter.frame_count,
            perf.counter_frame_time_average(&frontend.perf_counter),
        )
        perf.counter_reset(&frontend.perf_counter)
    }
    return interval
}

counter_periodic_report_start :: proc(
    frontend: ^Frontend,
    report_period: time.Duration,
) {
    frontend.perf_counter_timer = sdl.AddTimer(
        u32(time.duration_milliseconds(report_period)),
        _counter_periodic_report_callback,
        frontend,
    )
}

counter_periodic_report_stop :: proc(frontend: ^Frontend) {
    sdl_ensure(sdl.RemoveTimer(frontend.perf_counter_timer), "SDL_RemoveTimer")
}
