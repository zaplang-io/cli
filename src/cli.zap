# Zap cli — declarative command-line framework (click/typer parity).
#
# This module is at the scaffold stage: it carries no command/option
# implementation yet. The public surface (commands, typed options and
# arguments, groups/subcommands, automatic --help, exit codes) is tracked in
# the Tier-1 epic (zaplang-io/cli#1) and built out in the first-slice issues.
# `cli` builds on Zap core's argparse ArgumentParser object as its parsing
# engine rather than reimplementing argv parsing. See README.md and AGENTS.md.

# The package version. Replaced by the real public surface in the first slice.
def version() -> str:
    return "0.1.0"
