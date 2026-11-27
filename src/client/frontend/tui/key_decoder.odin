package tui

import "core:unicode/utf8"

import kb "medit:client/keybind"

@(private = "file")
ESC :: 0x1b

// Terminals send keys as byte sequences (UTF-8 text, control bytes, escape
// sequences), so bytes are buffered until a full sequence is received.
KeyDecoder :: struct {
    buf: [32]byte,
    len: int,
}

// Feeds one byte from `term.read`. Returns an event once a sequence completes.
key_decoder_feed :: proc(
    decoder: ^KeyDecoder,
    byte: byte,
) -> (
    event: kb.Event,
    ok: bool,
) {
    if decoder.len >= len(decoder.buf) do decoder.len = 0 // Garbage, drop the whole buffer
    decoder.buf[decoder.len] = byte
    decoder.len += 1
    consumed: int
    event, consumed = _translate_sequence(decoder.buf[:decoder.len])
    if consumed == 0 do return {}, false
    copy(decoder.buf[:], decoder.buf[consumed:decoder.len])
    decoder.len -= consumed
    return event, true
}

// Call when no byte followed an incomplete sequence within a short delay:
// a lone ESC is the Escape key, and ESC + one byte is Alt + that key.
key_decoder_flush :: proc(d: ^KeyDecoder) -> (event: kb.Event, ok: bool) {
    if d.len == 0 do return {}, false
    defer d.len = 0
    event.kind = .Press
    if d.buf[0] == ESC && d.len <= 2 {
        if d.len == 1 {
            event.key = .Escape
        } else {
            event.key, event.modifiers, _ = _translate_char(d.buf[1:2])
            event.modifiers += {.Alt}
        }
    }
    return event, true
}

// Translates the key sequence at the start of `seq`. `consumed` is the number
// of bytes used, or 0 if `seq` is incomplete and more bytes are needed.
_translate_sequence :: proc(seq: []byte) -> (event: kb.Event, consumed: int) {
    if len(seq) == 0 do return
    // Legacy terminal input has no release events, and repeats look like presses
    event.kind = .Press

    if seq[0] != ESC || len(seq) == 1 {
        if seq[0] == ESC do return // Escape key or start of a sequence: wait for now
        event.key, event.modifiers, consumed = _translate_char(seq)
        return
    }

    switch seq[1] {
    case '[':
        event.key, event.modifiers, consumed = _translate_csi(seq[2:])
        if consumed > 0 do consumed += 2
    case 'O':
        if len(seq) < 3 do return
        event.key, event.modifiers = _translate_ss3(seq[2])
        consumed = 3
    case:
        // ESC + key is how terminals encode Alt + key
        event.key, event.modifiers, consumed = _translate_char(seq[1:])
        if consumed > 0 {
            event.modifiers += {.Alt}
            consumed += 1
        }
    }
    return
}

@(private = "file")
_translate_char :: proc(
    seq: []byte,
) -> (
    key: kb.Key,
    mods: kb.KeyMods,
    consumed: int,
) {
    b := seq[0]
    // odinfmt: disable
    switch b {
    case 0x00:          return .Space, {.Ctrl}, 1
    // Ctrl+A..Ctrl+Z, except H, I and M
    case 0x01 ..= 0x07,
         0x0a ..= 0x0c,
         0x0e ..= 0x1a: return .A + kb.Key(int(b - 0x01)), {.Ctrl}, 1
    case 0x08:          return .Backspace, {.Ctrl}, 1
    case '\t':          return .Tab, {}, 1
    case '\r':          return .Enter, {}, 1
    case ESC:           return .Escape, {}, 1
    case 0x1c:          return .Backslash, {.Ctrl}, 1
    case 0x1d:          return .RightBracket, {.Ctrl}, 1
    case 0x1f:          return .Slash, {.Ctrl}, 1
    case ' ':           return .Space, {}, 1
    case '!':           return .Exclam, {}, 1
    case '$':           return .Dollar, {}, 1
    case '\'':          return .Quote, {}, 1
    case '(':           return .LeftParen, {}, 1
    case ')':           return .RightParen, {}, 1
    case '*':           return .Asterisk, {}, 1
    case ',':           return .Comma, {}, 1
    case '-':           return .Minus, {}, 1
    case '.':           return .Period, {}, 1
    case '/':           return .Slash, {}, 1
    case '0' ..= '9':   return .Num0 + kb.Key(int(b - '0')), {}, 1
    case ':':           return .Colon, {}, 1
    case ';':           return .Semicolon, {}, 1
    case '=':           return .Equals, {}, 1
    case 'A' ..= 'Z':   return .A + kb.Key(int(b - 'A')), {.Shift}, 1
    case '[':           return .LeftBracket, {}, 1
    case '\\':          return .Backslash, {}, 1
    case ']':           return .RightBracket, {}, 1
    case '`':           return .Grave, {}, 1
    case 'a' ..= 'z':   return .A + kb.Key(int(b - 'a')), {}, 1
    case '{':           return .LeftBrace, {}, 1
    case '}':           return .RightBrace, {}, 1
    case 0x7f:          return .Backspace, {}, 1
    case 0x80 ..= 0xff: return _translate_utf8_rune(seq)
    }
    // odinfmt: enable
    return .Unknown, {}, 1
}

@(private = "file")
_translate_utf8_rune :: proc(
    seq: []byte,
) -> (
    key: kb.Key,
    mods: kb.KeyMods,
    consumed: int,
) {
    if !utf8.full_rune(seq) do return .Unknown, {}, 0
    r, size := utf8.decode_rune(seq)
    switch r {
    case 'ù': return .Ugrave, {}, size
    case '²': return .Superscript2, {}, size
    }
    return .Unknown, {}, size
}

// CSI sequences: ESC [ <params> <final>, e.g. "ESC [ 1 ; 5 A" for Ctrl+Up.
@(private = "file")
_translate_csi :: proc(
    seq: []byte,
) -> (
    key: kb.Key,
    mods: kb.KeyMods,
    consumed: int,
) {
    params: [2]int
    n_params := 0
    // odinfmt: disable
    for b, i in seq {
        switch b {
        case '0' ..= '9':
            if n_params < len(params) {
                params[n_params] = params[n_params] * 10 + int(b - '0')
            }
        case ';': n_params += 1
        case 0x40 ..= 0x7e:
            consumed = i + 1
            if params[1] > 1 do mods = _xterm_mods(params[1])
            switch b {
            case 'A': key = .Up
            case 'B': key = .Down
            case 'C': key = .Right
            case 'D': key = .Left
            case 'H': key = .Home
            case 'F': key = .End
            case 'P': key = .F1
            case 'Q': key = .F2
            case 'R': key = .F3
            case 'S': key = .F4
            case 'Z': key = .Tab; mods += {.Shift}
            case '~':
                switch params[0] {
                case 1, 7:  key = .Home
                case 2:     key = .Insert
                case 3:     key = .Delete
                case 4, 8:  key = .End
                case 5:     key = .PageUp
                case 6:     key = .PageDown
                case 11:    key = .F1
                case 12:    key = .F2
                case 13:    key = .F3
                case 14:    key = .F4
                case 15:    key = .F5
                case 17:    key = .F6
                case 18:    key = .F7
                case 19:    key = .F8
                case 20:    key = .F9
                case 21:    key = .F10
                case 23:    key = .F11
                case 24:    key = .F12
                }
            }
            return
        }
    }
    // odinfmt: enable
    return // No final byte yet: incomplete
}

// SS3 sequences: ESC O <final>, sent for F1-F4 and in application cursor/keypad
// modes.
@(private = "file")
_translate_ss3 :: proc(b: byte) -> (key: kb.Key, mods: kb.KeyMods) {
    // odinfmt: disable
    switch b {
    case 'A':           return .Up, {}
    case 'B':           return .Down, {}
    case 'C':           return .Right, {}
    case 'D':           return .Left, {}
    case 'H':           return .Home, {}
    case 'F':           return .End, {}
    case 'P':           return .F1, {}
    case 'Q':           return .F2, {}
    case 'R':           return .F3, {}
    case 'S':           return .F4, {}
    case 'M':           return .NpadEnter, {}
    case 'k':           return .NpadPlus, {}
    case 'm':           return .NpadMinus, {}
    case 'j':           return .NpadMultiply, {}
    case 'o':           return .NpadDivide, {}
    case 'n':           return .NpadPeriod, {}
    case 'p' ..= 'y':   return .Npad0 + kb.Key(int(b - 'p')), {}
    }
    // odinfmt: enable
    return .Unknown, {}
}

// xterm modifier parameter: 1 + (Shift=1 | Alt=2 | Ctrl=4)
@(private = "file")
_xterm_mods :: proc(param: int) -> (mods: kb.KeyMods) {
    m := param - 1
    if m & 1 != 0 do mods += {.Shift}
    if m & 2 != 0 do mods += {.Alt}
    if m & 4 != 0 do mods += {.Ctrl}
    return
}
