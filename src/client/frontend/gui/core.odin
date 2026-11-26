#+private
package gui

import "core:fmt"

import sdl "vendor:sdl3"
import sdl_ttf "vendor:sdl3/ttf"

import "medit:util/perf"
import kb "medit:client/keybind"

Frontend :: struct {
    window:             ^sdl.Window,
    renderer:           ^sdl.Renderer,
    perf_counter:       perf.Counter,
    perf_counter_timer: sdl.TimerID,
    text_engine:        ^sdl_ttf.TextEngine,
    text_cache:         [FontId]^sdl_ttf.Text,
    fonts:              [FontId]Font,
    // TODO move into a core editor struct
    running:            bool,
    keybinds:           kb.Keybinds,
}

frontend_create :: proc(frontend: ^Frontend) -> (ok: bool) {
    defer if !ok do frontend_destroy(frontend)

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
    return true
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
            frontend_dispatch_event(frontend, &event)
        }
        return {.RequestRender}
    }
    return {}
}

frontend_dispatch_event :: proc(frontend: ^Frontend, event: ^sdl.Event) {
    #partial switch event.type {
    case .QUIT:
        frontend.running = false
    case .WINDOW_RESIZED:
    case .KEY_DOWN:
        keybind_event := sdl3_keybind_translate_event(event)
        if handled := kb.handle_event(&frontend.keybinds, &keybind_event); handled == true do break
        // TODO handle key press not handled by keybinds (unbindable keys)
    case .TEXT_INPUT:
    case .KEYMAP_CHANGED:
    case .MOUSE_WHEEL:
    }
}

frontend_clear :: proc(frontend: ^Frontend) {
    sdl.RenderClear(frontend.renderer)
}

frontend_render_frame :: proc(frontend: ^Frontend) {
    sdl.RenderPresent(frontend.renderer)
    perf.counter_frame_end(&frontend.perf_counter)
}

Position :: distinct [2]int
Color :: distinct [4]u8

frontend_draw_text :: proc(
    frontend: ^Frontend,
    text: string,
    font_id: FontId,
    position: Position,
    color: Color,
) {
    if len(text) == 0 do return
    text_cache := frontend.text_cache[font_id]
    font := frontend.fonts[font_id]
    sdl_ttf.SetTextFont(text_cache, font.main)
    sdl_ttf.SetTextString(text_cache, raw_data(text), len(text))
    sdl_ttf.SetTextColor(text_cache, color.r, color.g, color.b, color.a)
    sdl_ttf.DrawRendererText(text_cache, f32(position.x), f32(position.y + font.line_centering_offset))
}