#+private
package gui

import "core:fmt"
import "core:os"

import sdl "vendor:sdl3"

import "medit:util"

sdl_ensure :: proc(
    result: bool,
    call: string,
    location := #caller_location,
) -> bool {
    if !result {
        file := util.relative_location(location)
        error := sdl.GetError() if len(sdl.GetError()) > 0 else "<no details>"
        fmt.eprintfln("%s:%d: Error: %s failed: %s", file, location.line, call, error)
    }
    return result
}
