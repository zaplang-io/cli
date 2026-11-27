"""Attach stderr to a PTY while keeping stdout separately captured."""

import errno
import os
import pty
import subprocess
import sys
import termios

master, slave = pty.openpty()
try:
    settings = termios.tcgetattr(slave)
    settings[1] &= ~termios.OPOST
    termios.tcsetattr(slave, termios.TCSANOW, settings)
    result = subprocess.run(
        ["./progress_state", sys.argv[1]],
        stdout=subprocess.PIPE,
        stderr=slave,
        timeout=5,
        check=False,
    )
finally:
    os.close(slave)

try:
    while True:
        try:
            chunk = os.read(master, 4096)
        except OSError as error:
            if error.errno != errno.EIO:
                raise
            break
        if not chunk:
            break
        sys.stderr.buffer.write(chunk)
finally:
    os.close(master)

sys.stdout.buffer.write(result.stdout)
raise SystemExit(result.returncode)
