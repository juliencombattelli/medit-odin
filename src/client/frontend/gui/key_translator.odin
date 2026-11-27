package gui

import sdl "vendor:sdl3"

import kb "medit:client/keybind"

key_translate_event :: proc(sdl_event: ^sdl.Event) -> (event: kb.Event) {
    event = {}

    if sdl_event == nil do return

    event.platform_data = sdl_event

    #partial switch sdl_event.type {
    case .KEY_DOWN: event.kind = .Repeat if sdl_event.key.repeat else .Press
    case .KEY_UP: event.kind = .Release
    case: return
    }

    event.key = _sdl3_keycode_to_keybind_key(sdl_event.key.key)
    event.scancode = cast(u32)sdl_event.key.scancode // TODO safe cast
    event.modifiers = _sdl3_keymod_to_keybind_mod(sdl_event.key.mod)
    return
}

@(private = "file")
_sdl3_keycode_to_keybind_key :: proc(keycode: sdl.Keycode) -> kb.Key {
    // odinfmt: disable
    switch keycode {
        case sdl.K_A:               return .A;
        case sdl.K_B:               return .B;
        case sdl.K_C:               return .C;
        case sdl.K_D:               return .D;
        case sdl.K_E:               return .E;
        case sdl.K_F:               return .F;
        case sdl.K_G:               return .G;
        case sdl.K_H:               return .H;
        case sdl.K_I:               return .I;
        case sdl.K_J:               return .J;
        case sdl.K_K:               return .K;
        case sdl.K_L:               return .L;
        case sdl.K_M:               return .M;
        case sdl.K_N:               return .N;
        case sdl.K_O:               return .O;
        case sdl.K_P:               return .P;
        case sdl.K_Q:               return .Q;
        case sdl.K_R:               return .R;
        case sdl.K_S:               return .S;
        case sdl.K_T:               return .T;
        case sdl.K_U:               return .U;
        case sdl.K_V:               return .V;
        case sdl.K_W:               return .W;
        case sdl.K_X:               return .X;
        case sdl.K_Y:               return .Y;
        case sdl.K_Z:               return .Z;

        case sdl.K_0:               return .Num0;
        case sdl.K_1:               return .Num1;
        case sdl.K_2:               return .Num2;
        case sdl.K_3:               return .Num3;
        case sdl.K_4:               return .Num4;
        case sdl.K_5:               return .Num5;
        case sdl.K_6:               return .Num6;
        case sdl.K_7:               return .Num7;
        case sdl.K_8:               return .Num8;
        case sdl.K_9:               return .Num9;

        case sdl.K_SPACE:           return .Space;
        case sdl.K_RETURN:          return .Enter;
        case sdl.K_ESCAPE:          return .Escape;
        case sdl.K_BACKSPACE:       return .Backspace;
        case sdl.K_TAB:             return .Tab;

        case sdl.K_LSHIFT:          return .LeftShift;
        case sdl.K_RSHIFT:          return .RightShift;
        case sdl.K_LCTRL:           return .LeftCtrl;
        case sdl.K_RCTRL:           return .RightCtrl;
        case sdl.K_LALT:            return .LeftAlt;
        case sdl.K_RALT:            return .RightAlt;
        case sdl.K_APPLICATION:     return .CtxMenu;
        case sdl.K_CAPSLOCK:        return .Capslock;
        case sdl.K_NUMLOCKCLEAR:    return .Numlock;

        case sdl.K_LEFT:            return .Left;
        case sdl.K_RIGHT:           return .Right;
        case sdl.K_UP:              return .Up;
        case sdl.K_DOWN:            return .Down;

        case sdl.K_HOME:            return .Home;
        case sdl.K_END:             return .End;
        case sdl.K_PAGEUP:          return .PageUp;
        case sdl.K_PAGEDOWN:        return .PageDown;
        case sdl.K_INSERT:          return .Insert;
        case sdl.K_DELETE:          return .Delete;

        case sdl.K_F1:              return .F1;
        case sdl.K_F2:              return .F2;
        case sdl.K_F3:              return .F3;
        case sdl.K_F4:              return .F4;
        case sdl.K_F5:              return .F5;
        case sdl.K_F6:              return .F6;
        case sdl.K_F7:              return .F7;
        case sdl.K_F8:              return .F8;
        case sdl.K_F9:              return .F9;
        case sdl.K_F10:             return .F10;
        case sdl.K_F11:             return .F11;
        case sdl.K_F12:             return .F12;

        case sdl.K_MINUS:           return .Minus;
        case sdl.K_EQUALS:          return .Equals;
        case sdl.K_LEFTBRACKET:     return .LeftBracket;
        case sdl.K_RIGHTBRACKET:    return .RightBracket;
        case sdl.K_LEFTPAREN:       return .LeftParen;
        case sdl.K_RIGHTPAREN:      return .RightParen;
        case sdl.K_LEFTBRACE:       return .LeftBrace;
        case sdl.K_RIGHTBRACE:      return .RightBrace;
        case sdl.K_SEMICOLON:       return .Semicolon;
        case sdl.K_APOSTROPHE:      return .Quote;
        case sdl.K_COMMA:           return .Comma;
        case sdl.K_PERIOD:          return .Period;
        case sdl.K_SLASH:           return .Slash;
        case sdl.K_BACKSLASH:       return .Backslash;
        case sdl.K_GRAVE:           return .Grave;
        case sdl.K_COLON:           return .Colon;
        case sdl.K_EXCLAIM:         return .Exclam;
        case sdl.K_ASTERISK:        return .Asterisk;
        case sdl.K_DOLLAR:          return .Dollar;

        case sdl.K_KP_0:            return .Npad0;
        case sdl.K_KP_1:            return .Npad1;
        case sdl.K_KP_2:            return .Npad2;
        case sdl.K_KP_3:            return .Npad3;
        case sdl.K_KP_4:            return .Npad4;
        case sdl.K_KP_5:            return .Npad5;
        case sdl.K_KP_6:            return .Npad6;
        case sdl.K_KP_7:            return .Npad7;
        case sdl.K_KP_8:            return .Npad8;
        case sdl.K_KP_9:            return .Npad9;
        case sdl.K_KP_PLUS:         return .NpadPlus;
        case sdl.K_KP_MINUS:        return .NpadMinus;
        case sdl.K_KP_DIVIDE:       return .NpadDivide;
        case sdl.K_KP_MULTIPLY:     return .NpadMultiply;
        case sdl.K_KP_ENTER:        return .NpadEnter;
        case sdl.K_KP_PERIOD:       return .NpadPeriod;

        case 0xB2:                  return .Superscript2;
        case 0xF9:                  return .Ugrave;

        case:                       return .Unknown;
    }
    // odinfmt: enable
}

@(private = "file")
_sdl3_keymod_to_keybind_mod :: proc(mods: sdl.Keymod) -> kb.KeyMods {
    result := kb.KeyMods{}
    if mods & sdl.KMOD_SHIFT != {} {
        result += {kb.KeyMod.Shift}
    }
    if mods & sdl.KMOD_CTRL != {} {
        result += {kb.KeyMod.Ctrl}
    }
    if mods & sdl.KMOD_ALT != {} {
        result += {kb.KeyMod.Alt}
    }
    return result
}
