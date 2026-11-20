#+private
package gui

import "core:fmt"

import sdl "vendor:sdl3"

import "medit:util/perf"

Frontend :: struct {
    running:  bool,
    window:   ^sdl.Window,
    renderer: ^sdl.Renderer,
    perf_counter: perf.Counter,
    perf_counter_timer: sdl.TimerID,
}

frontend_create :: proc(frontend: ^Frontend) -> (ok: bool) {
    sdl_ensure(sdl.Init({.VIDEO}), "SDL_Init") or_return

    frontend.window = sdl.CreateWindow("medit", 800, 600, {.HIDDEN})
    sdl_ensure(frontend.window != nil, "SDL_CreateWIndow") or_return

    frontend.renderer = sdl.CreateRenderer(frontend.window, nil)
    sdl_ensure(frontend.renderer != nil, "SDL_CreateRenderer") or_return

    return true
}

frontend_destroy :: proc(frontend: ^Frontend) {
    sdl.DestroyRenderer(frontend.renderer)
    sdl.DestroyWindow(frontend.window)
    sdl.Quit()
}

frontend_show :: proc(frontend: ^Frontend) -> (ok: bool) {
    sdl_ensure(sdl.ShowWindow(frontend.window), "") or_return
    return true;
}

WAIT_FOR_EVENT_TIMEOUT_MS :: 100

EventReaction :: enum {
    RequestRender,
}

EventReactionSet :: bit_set[EventReaction]

frontend_handle_event :: proc(frontend: ^Frontend) -> EventReactionSet {
    if sdl.WaitEventTimeout(nil, WAIT_FOR_EVENT_TIMEOUT_MS) {
        perf.counter_frame_begin(&frontend.perf_counter)
        event: sdl.Event
        for sdl.PollEvent(&event) {
            frontend_dispatch_event(frontend, event)
        }
        return {.RequestRender}
    }
    return {}
}

frontend_dispatch_event :: proc(frontend: ^Frontend, event: sdl.Event) {
    #partial switch event.type {
    case .QUIT: frontend.running = false
    case .WINDOW_RESIZED:
    case .KEY_DOWN:
    case .TEXT_INPUT:
    case .KEYMAP_CHANGED:
    case .MOUSE_WHEEL:
    }
}

frontend_clear :: proc(frontend: ^Frontend) {
    sdl.RenderClear(frontend.renderer)
}

frontend_render_frame :: proc(frontend: ^Frontend) {
    sdl.RenderClear(frontend.renderer)
    perf.counter_frame_end(&frontend.perf_counter)
}
