package build

import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:terminal"
import "core:terminal/ansi"
import "core:time"

SEP :: filepath.SEPARATOR_STRING

BUILD_SRC_FILE :: "." + SEP + "build.odin"
when ODIN_OS == .Windows {
    BUILD_EXE_FILE :: "." + SEP + "build.exe"
} else {
    BUILD_EXE_FILE :: "." + SEP + "build"
}

main :: proc() {
    context.logger = setup_logger()
    if is_newer(BUILD_SRC_FILE, BUILD_EXE_FILE) {
        rebuild_builder()
        reexec_builder()
    }
    build_medit()
}

BASE_ARGS :: []string {
    "odin",
    "build",
    "src",
    "-debug",
    "-show-timings",
    "-collection:medit=src",
    "-out:medit",
}

build_medit :: proc() -> ! {
    log.info("Building medit...")
    state := process_run(
        slice.concatenate(
            [][]string{BASE_ARGS, os.args[1:]},
            context.temp_allocator,
        ),
    )
    os.exit(state.exit_code)
}

rebuild_builder :: proc() {
    log.infof(
        "%s was modified, reboostrapping the build system...",
        BUILD_SRC_FILE,
    )
    state := process_run(
        {
            "odin",
            "build",
            BUILD_SRC_FILE,
            "-file",
            "-show-timings",
            fmt.tprintf("-out:%s", BUILD_EXE_FILE),
        },
    )
    if !state.success || state.exit_code != 0 {
        os.exit(state.exit_code)
    }
    log.infof("Builder executable was written to: %s", BUILD_EXE_FILE)
}

reexec_builder :: proc() -> ! {
    state := process_run(
        slice.concatenate(
            [][]string{{BUILD_EXE_FILE}, os.args[1:]},
            context.temp_allocator,
        ),
    )
    os.exit(state.exit_code)
}

////////////////////////////////////////////////////////////////////////////////
/// General utilities
////////////////////////////////////////////////////////////////////////////////

setup_logger :: proc() -> log.Logger {
    opts: log.Options
    if terminal.is_terminal(os.stdout) {
        opts += {.Terminal_Color}
    }
    return log.Logger {
        procedure = logger_proc,
        lowest_level = .Debug,
        options = opts,
    }
}

logger_proc :: proc(
    data: rawptr,
    level: log.Level,
    text: string,
    options: log.Options,
    location := #caller_location,
) {
    BOLD :: ansi.CSI + ansi.BOLD + ansi.SGR
    RESET :: ansi.CSI + ansi.RESET + ansi.SGR

    color := .Terminal_Color in options
    start := color ? BOLD : ""
    end := color ? RESET : ""

    switch level {
    case .Debug, .Info:
        fmt.eprintfln("%s-- %s%s", start, text, end)
    case .Warning:
        fmt.eprintfln("%s-- Warning: %s%s", start, text, end)
    case .Error, .Fatal:
        fmt.eprintfln("%s-- Error: %s%s", start, text, end)
    }
}

// Run a child process till its completion, sharing stdout and stderr
process_run :: proc(command: []string) -> os.Process_State {
    proc_handle, err := os.process_start(
        {command = command, stdout = os.stdout, stderr = os.stderr},
    )
    ensure(err == nil)

    state, wait_err := os.process_wait(proc_handle)
    ensure(wait_err == nil)

    return state
}

// Return true if a is newer than b
is_newer :: proc(a, b: string) -> bool {
    info_a := stat_ensure_file_exists(a)
    info_b := stat_ensure_file_exists(b)
    return time.diff(info_a.modification_time, info_b.modification_time) < 0
}

// Return the stat of a given file path, exit if it is not a regular file
stat_ensure_file_exists :: proc(path: string) -> os.File_Info {
    file_info, err := os.stat_do_not_follow_links(path, context.temp_allocator)
    if err == .Not_Exist {
        log.errorf("%s does not exist anymore, exiting.", path)
        os.exit(1)
    }
    if file_info.type != .Regular {
        log.errorf("%s exists and is not a regular file, exiting.", path)
        os.exit(1)
    }
    return file_info
}
