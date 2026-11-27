package client

import "core:fmt"

// odinfmt: disable
Key :: enum {
    Unknown,

    // Letters (A-Z)
    A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z,

    // Numbers (0-9)
    Num0, Num1, Num2, Num3, Num4, Num5, Num6, Num7, Num8, Num9,

    // Function keys
    F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12,

    // Special keys
    LeftShift, RightShift, LeftCtrl, RightCtrl, LeftAlt, RightAlt,
    Space, Enter, Escape, Backspace, Tab, CtxMenu, Capslock, Numlock,

    // Navigation
    Left, Right, Up, Down, Home, End, PageUp, PageDown, Insert, Delete,

    // Punctuation and symbols
    LeftBracket, RightBracket, LeftParen, RightParen, LeftBrace, RightBrace,
    Semicolon, Quote, Comma, Period, Slash, Backslash, Minus, Equals,
    Grave, Colon, Exclam, Asterisk, Dollar, Ugrave, Superscript2,

    // Numpad
    Npad0, Npad1, Npad2, Npad3, Npad4, Npad5, Npad6, Npad7, Npad8, Npad9,
    NpadDivide, NpadMultiply, NpadMinus, NpadPlus, NpadEnter, NpadPeriod,
}
// odinfmt: enable

KeyCount :: len(Key)

KeyMod :: enum {
    None,
    Shift,
    Ctrl,
    Alt,
}

KeyMods :: bit_set[KeyMod;u8]

KeyModsCount :: cast(int)~KeyMods{} + 1 // Total number of valid combinations

EventKind :: enum {
    Unknown,
    Press,
    Release,
    Repeat,
}

Event :: struct {
    kind:          EventKind,
    key:           Key,
    scancode:      u32, // Physical key position (platform-specific)
    modifiers:     KeyMods,
    platform_data: rawptr,
}

KeyActionProc :: #type proc(userdata: rawptr)

KeybindEntry :: struct {
    callback: KeyActionProc,
    userdata: rawptr,
}

Keybinds :: struct {
    bindings: [KeyCount][KeyModsCount]KeybindEntry,
}

reinit :: proc(keybinds: ^Keybinds) {
    keybinds^ = {}
}

bind :: proc(
    keybinds: ^Keybinds,
    key: Key,
    mods: KeyMods,
    callback: KeyActionProc,
    userdata: rawptr,
) {
    keybinds.bindings[key][transmute(u8)mods] = {callback, userdata}
}

unbind :: proc(keybinds: ^Keybinds, key: Key, mods: KeyMods) {
    keybinds.bindings[key][transmute(u8)mods] = {}
}

get :: proc(keybinds: ^Keybinds, key: Key, mods: KeyMods) -> ^KeybindEntry {
    return &keybinds.bindings[key][transmute(u8)mods]
}

handle_event :: proc(keybinds: ^Keybinds, event: ^Event) -> (handled: bool) {
    fmt.eprintfln("[DEBUG] Key: %s", event.key)
    entry := get(keybinds, event.key, event.modifiers)
    if entry != nil && entry.callback != nil {
        entry.callback(entry.userdata)
        return true
    }
    return false
}
