package gui

import "core:c"
import "core:fmt"
import "core:os"

import sdl "vendor:sdl3"
import sdl_ttf "vendor:sdl3/ttf"

FontId :: enum {
    Ui,
    Editor,
}

Font :: struct {
    props:                 sdl.PropertiesID,
    main:                  ^sdl_ttf.Font,
    emoji:                 ^sdl_ttf.Font,
    size:                  int,
    line_spacing:          int,
    default_cursor_width:  int,
    line_centering_offset: int,
}

frontend_ttf_setup :: proc(frontend: ^Frontend) -> (ok: bool) {
    defer if !ok do frontend_ttf_teardown(frontend)

    sdl_ensure(sdl_ttf.Init(), "TTF_Init") or_return

    frontend.text_engine = sdl_ttf.CreateRendererTextEngine(frontend.renderer)
    sdl_ensure(
        frontend.text_engine != nil,
        "TTF_CreateRendererTextEngine",
    ) or_return

    for font_id, index in FontId {
        frontend_load_font(frontend, font_id)
    }
    return true
}

frontend_ttf_teardown :: proc(frontend: ^Frontend) {
    for font_id, index in FontId {
        frontend_unload_font(frontend, font_id)
    }

    sdl_ttf.DestroyRendererTextEngine(frontend.text_engine)
    frontend.text_engine = nil

    sdl_ttf.Quit()
}

PROP_NAME :: sdl_ttf.PROP_FONT_CREATE_FILENAME_STRING
PROP_SIZE :: sdl_ttf.PROP_FONT_CREATE_SIZE_FLOAT
PROP_HDPI :: sdl_ttf.PROP_FONT_CREATE_HORIZONTAL_DPI_NUMBER
PROP_VDPI :: sdl_ttf.PROP_FONT_CREATE_VERTICAL_DPI_NUMBER

DEFAULT_FONT_PATH :: "asset/font/consola.ttf"
DEFAULT_FONT_SIZE :: 14
DEFAULT_FONT_HDPI :: 96
DEFAULT_FONT_VDPI :: DEFAULT_FONT_HDPI

frontend_load_font :: proc(frontend: ^Frontend, font_id: FontId) {
    font := &frontend.fonts[font_id]

    if font.props == 0 {
        font.props = sdl.CreateProperties()
        ensure(font.props != 0)
    }

    // TODO read values from config
    sdl.SetStringProperty(font.props, PROP_NAME, DEFAULT_FONT_PATH)
    sdl.SetFloatProperty(font.props, PROP_SIZE, DEFAULT_FONT_SIZE)
    sdl.SetNumberProperty(font.props, PROP_HDPI, DEFAULT_FONT_HDPI)
    sdl.SetNumberProperty(font.props, PROP_VDPI, DEFAULT_FONT_VDPI)

    font.main = sdl_ttf.OpenFontWithProperties(font.props)
    if font.main == nil {
        // TODO implement fallback
        fmt.eprintfln(
            "Failed to load editor font from %s (size %d): %s",
            DEFAULT_FONT_PATH,
            DEFAULT_FONT_SIZE,
            sdl.GetError(),
        )
        os.exit(1)
    }

    if !sdl_ttf.FontIsFixedWidth(font.main) {
        fmt.eprintfln(
            "Warning: editor font '%s' is not fixed-width\n",
            DEFAULT_FONT_PATH,
        )
    }

    line_spacing := sdl_ttf.GetFontLineSkip(font.main)
    font_height := sdl_ttf.GetFontHeight(font.main)

    font.line_spacing = cast(int)line_spacing // TODO safe cast
    font.line_centering_offset = cast(int)(line_spacing - font_height + 1) / 2 // TODO safe cast

    w: c.int = 0
    sdl_ttf.GetStringSize(font.main, raw_data(string("M")), 0, &w, nil)
    font.default_cursor_width = cast(int)w // TODO safe cast

    frontend.text_cache[font_id] = sdl_ttf.CreateText(
        frontend.text_engine,
        font.main,
        nil,
        0,
    )
    ensure(frontend.text_cache[font_id] != nil)

    width_factor := 0
    font.emoji = _load_emoji_font_aligned_to(
        font.main,
        // "asset/font/NotoColorEmoji-Regular.ttf",
        "asset/font/OpenMoji-color-colr0_svg.ttf",
        // "asset/font/seguiemj.ttf",
        DEFAULT_FONT_SIZE,
        width_factor,
    )
    if font.emoji == nil {
        fmt.eprintfln("Warning: failed to load fallback emoji font: %s", sdl.GetError());
    } else if !sdl_ttf.AddFallbackFont(font.main, font.emoji) {
            fmt.eprintfln("Warning: failed to add fallback emoji font: %s", sdl.GetError());
    }
}

frontend_unload_font :: proc(frontend: ^Frontend, font_id: FontId) {
    font := &frontend.fonts[font_id]

    sdl_ttf.DestroyText(frontend.text_cache[font_id])
    frontend.text_cache[font_id] = nil

    sdl_ttf.ClearFallbackFonts(font.main)
    sdl_ttf.CloseFont(font.main)
    sdl_ttf.CloseFont(font.emoji)
}


// **Note about emoji**
// A fallback font is used to render emoji. As we want emoji to fit in a grid
// cell, we compute the size of an emoji glyph (currently 😀) so that it is
// equal to the size of a letter glyph in the main editor font. The computation
// is using strings of a hundred glyphs for a better precision.
// This method works well for the currently used fonts and size but it is
// expected to be brittle. Also, rendered emoji are quite small and might not be
// properly readable at all...

_FONT_TEST_CHAR_COUNT :: 100

_EDITOR_FONT_TEST_STRING :: """
    MMMMMMMMMM
    MMMMMMMMMM
    MMMMMMMMMM
    MMMMMMMMMM
    MMMMMMMMMM
    MMMMMMMMMM
    MMMMMMMMMM
    MMMMMMMMMM
    MMMMMMMMMM
    MMMMMMMMMM
    """


_EMOJI_FONT_TEST_STRING :: """
    😀😀😀😀😀😀😀😀😀😀
    😀😀😀😀😀😀😀😀😀😀
    😀😀😀😀😀😀😀😀😀😀
    😀😀😀😀😀😀😀😀😀😀
    😀😀😀😀😀😀😀😀😀😀
    😀😀😀😀😀😀😀😀😀😀
    😀😀😀😀😀😀😀😀😀😀
    😀😀😀😀😀😀😀😀😀😀
    😀😀😀😀😀😀😀😀😀😀
    😀😀😀😀😀😀😀😀😀😀
    """


_glyph_width :: proc(font: ^sdl_ttf.Font, s: cstring) -> int {
    w: c.int = 0
    if !sdl_ttf.MeasureString(font, transmute([^]u8)s, 0, 0, &w, nil) {
        fmt.eprintfln("Error: failed to get font metric: %s", sdl.GetError())
        return 0
    }
    return cast(int)w / _FONT_TEST_CHAR_COUNT // TODO safe cast
}

_FORCE_MONOSPACE_FONTS_MAX_ITER :: 128

_load_emoji_font_aligned_to :: proc(
    font: ^sdl_ttf.Font,
    path: cstring,
    size: int,
    width_factor: int,
) -> ^sdl_ttf.Font {
    if width_factor == 0 {
        return sdl_ttf.OpenFont(path, cast(f32)size)
    }

    main_font_w := _glyph_width(font, _EDITOR_FONT_TEST_STRING)

    factor: f32 = 1.0
    for iter := _FORCE_MONOSPACE_FONTS_MAX_ITER; iter > 0; iter -= 1 {
        emoji_font := sdl_ttf.OpenFont(path, cast(f32)size * factor)
        emoji_font_w := _glyph_width(emoji_font, _EMOJI_FONT_TEST_STRING)
        if (emoji_font_w > width_factor * main_font_w) {
            factor -= factor / 2.0
        } else if (emoji_font_w < width_factor * main_font_w) {
            factor += factor / 2.0
        } else if (emoji_font_w == width_factor * main_font_w) {
            return emoji_font
        }
        sdl_ttf.CloseFont(emoji_font)
    }
    sdl.SetError("cannot find a size aligned to the requested width factor")
    return nil
}
