package util

import "core:path/filepath"

relative_location :: proc(location := #caller_location) -> string{
    PROJECT_ROOT :: #directory + ".."
    file, err := filepath.rel(PROJECT_ROOT, location.file_path, context.temp_allocator)
    if err != nil do file = location.file_path
    return file
}
