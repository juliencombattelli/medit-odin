#+private
package tui

import "core:os"

available :: proc() -> Error {
    stdin_not_a_tty := !os.is_tty(os.stdin)
    stdout_not_a_tty := !os.is_tty(os.stdout)
    msg: string
    switch {
    case stdin_not_a_tty && stdout_not_a_tty:
        msg = "both stdin and stdout are not ttys"
    case stdin_not_a_tty:
        msg = "stdin is not a tty"
    case stdout_not_a_tty:
        msg = "stdout is not a tty"
    }
    if stdin_not_a_tty || stdout_not_a_tty {
        return FailedToStart{stdin_not_a_tty, stdout_not_a_tty, msg}
    }
    return nil
}
