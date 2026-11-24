# cli package decisions

Design decisions for the Zap `cli` library, keyed to issues. Each records a
choice that could not be read straight off Python's [click](https://click.palletsprojects.com/) /
[typer](https://typer.tiangolo.com/), with the reference it follows or departs
from. Signature ambiguities are resolved with the maintainer (with click/typer
examples) before being recorded here.

## Parity target: click / typer

The package tracks [**click**](https://click.palletsprojects.com/) and
[**typer**](https://typer.tiangolo.com/) as its primary API references. Where the
two libraries differ, the decision — and which one `cli` follows — is recorded
below, keyed to the issue that introduces it.

## Layering over core `argparse` ([#1](https://github.com/zaplang-io/cli/issues/1))

- `cli` builds on Zap core's `argparse` `ArgumentParser` object
  ([zaplang-io/zap#997](https://github.com/zaplang-io/zap/issues/997)) as its
  parsing engine and does not reimplement token-level argv parsing. The split:
  core owns *how argv is tokenized and matched*; `cli` owns *how commands are
  declared, dispatched, and reported* (decorators/declarations, subcommand
  grouping, `--help` rendering, exit-code conventions).
- Open items to settle during Phase 0 (#2), recorded here once decided:
  - Declaration form: decorator-based (`@cli.command`, click-style) vs.
    function-signature inference (typer-style) vs. both.
  - Exit-code convention and the error hierarchy (`cli.Exit` / `cli.UsageError`
    / `cli.Abort`) and how it maps to process exit status.
  - Whether automatic `--help` rendering reuses core `argparse`'s
    `format_help` or is rendered by `cli` from its own command metadata.
