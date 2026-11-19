#+private
package gui

import "core:fmt"

import sdl "vendor:sdl3"

Frontend :: struct {
    running:  bool,
    window:   ^sdl.Window,
    renderer: ^sdl.Renderer,
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

frontend_handle_event :: proc(frontend: ^Frontend) {
    if sdl.WaitEventTimeout(nil, WAIT_FOR_EVENT_TIMEOUT_MS) {
        event: sdl.Event
        for sdl.PollEvent(&event) {
            frontend_dispatch_event(frontend, event)
        }
    }
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
