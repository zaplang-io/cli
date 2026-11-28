"""Exercise the generated completion script in the named shell."""

import os
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory

SHELL = sys.argv[1]
ENV = {
    **os.environ,
    "PATH": f"{Path.cwd()}{os.pathsep}{os.environ['PATH']}",
}
EXPECTED = [b"alpha beta", b'alpha "quoted" $HOME;*']

with TemporaryDirectory() as directory:
    script = Path(directory, f"completion.{SHELL}")
    script.write_bytes(
        subprocess.check_output(
            ["./completion_commands"],
            env={**ENV, "_COMPLETION_COMMANDS_COMPLETE": f"{SHELL}_source"},
        )
    )
    subprocess.run([SHELL, "-n", script], env=ENV, check=True)
    first = script.read_text().splitlines()[0]
    if SHELL == "bash":
        output = subprocess.check_output(
            [
                SHELL, "--noprofile", "--norc", "-c",
                'source "$1"; COMP_LINE=\'completion_commands build --mode "debug" "alpha \'\n'
                'COMP_POINT=${#COMP_LINE}; "$2" completion_commands "alpha " debug\n'
                'printf "%s\\0" "${COMPREPLY[@]}"',
                "probe", script, first.split("(", 1)[0],
            ],
            env=ENV,
        )
    elif SHELL == "zsh":
        output = subprocess.check_output(
            [
                SHELL, "-f", "-c",
                'compdef() { :; }; compadd() { printf "%s\\0" "${candidates[@]}"; }\n'
                'source "$1"; words=(completion_commands build --mode \'"debug"\' "alpha ");\n'
                'CURRENT=5; PREFIX="alpha "; "$2"',
                "probe", script, first.split("(", 1)[0],
            ],
            env=ENV,
        )
    else:
        output = subprocess.check_output(
            [
                SHELL, "-c",
                '''source "$argv[1]"; complete -C 'completion_commands build --mode "debug" alpha' ''',
                script,
            ],
            env=ENV,
        )
    if SHELL == "fish":
        assert set(output.splitlines()) == set(EXPECTED), output
    else:
        assert output.split(b"\0") == [*EXPECTED, b""], output
