package build

import "core:fmt"
import "core:os"

main :: proc() {
    proc_handle, err := os.process_start({
        command = {
            "odin", "build", "src",
            "-show-timings", "-collection:medit=src", "-out:medit",
        },
        stdout  = os.stdout,
        stderr  = os.stderr,
    })
    ensure(err == nil)

    state, wait_err := os.process_wait(proc_handle)
    ensure(wait_err == nil)

    os.exit(state.exit_code)
}