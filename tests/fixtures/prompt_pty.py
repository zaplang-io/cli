"""Drive CLI stdin through a PTY. The Zap tests assert the captured behavior."""

import os
import pty
import select
import subprocess
import sys
import termios
import time

PROMPT = b"Secret: "


def read_prompt(stream):
    data = bytearray()
    deadline = time.monotonic() + 5
    while not data.endswith(PROMPT):
        remaining = deadline - time.monotonic()
        if remaining <= 0 or not select.select([stream], [], [], remaining)[0]:
            raise TimeoutError("hidden prompt did not appear")
        chunk = os.read(stream.fileno(), 1)
        if not chunk:
            raise RuntimeError(f"closed stderr before prompt: {data!r}")
        data.extend(chunk)
    return bytes(data)


def run(mode, replies, initial_echo):
    master, slave = pty.openpty()
    try:
        settings = termios.tcgetattr(slave)
        if initial_echo:
            settings[3] |= termios.ECHO
        else:
            settings[3] &= ~termios.ECHO
        termios.tcsetattr(slave, termios.TCSANOW, settings)

        with subprocess.Popen(
            ["./prompt_commands", mode],
            stdin=slave,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        ) as process:
            transcript = bytearray()
            echo_disabled = True
            try:
                for reply in replies:
                    transcript.extend(read_prompt(process.stderr))
                    echo_disabled &= not bool(termios.tcgetattr(slave)[3] & termios.ECHO)
                    os.write(master, reply)
                stdout, stderr = process.communicate(timeout=5)
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait()
            transcript.extend(stderr)
            echo_restored = termios.tcgetattr(slave) == settings
            while select.select([master], [], [], 0)[0]:
                transcript.extend(os.read(master, 4096).replace(b"\r\n", b""))
            print(f"echo_disabled={echo_disabled}\necho_restored={echo_restored}", flush=True)
            sys.stdout.buffer.write(stdout)
            sys.stderr.buffer.write(transcript)
            return process.returncode
    finally:
        os.close(master)
        os.close(slave)


mode = sys.argv[1]
replies = {
    "hidden": [b"secret-value\n"],
    "hidden-default": [b"\n"],
    "hidden-retry": [b"secret-invalid\n", b"42\n"],
    "hidden-eof": [b"\x04"],
}
raise SystemExit(run(mode, replies[mode], initial_echo=mode != "hidden-default"))
