# cli

Declarative command-line framework for [Zap](https://github.com/zaplang-io/zap) — an official **non-core** package.

- Tracking issue: [zaplang-io/zap#314](https://github.com/zaplang-io/zap/issues/314)
- Contributor & agent conventions: [AGENTS.md](AGENTS.md)
- Design decisions: [DECISIONS.md](DECISIONS.md)

This repository is at the **scaffold** stage — governance and layout only, no library code yet. The [Tier-1 epic](https://github.com/zaplang-io/cli/issues/1) tracks the public surface and the phased implementation.

## Goals

A typed Zap CLI framework whose public API mirrors Python's [**click**](https://click.palletsprojects.com/) and [**typer**](https://typer.tiangolo.com/) as closely as Zap's static typing allows. API-parity with the popular Python libraries is a project rule — see [AGENTS.md](AGENTS.md).

`cli` is the **high-level, declarative layer**. It does **not** reimplement token-level argument parsing: it builds on Zap core's `argparse` `ArgumentParser` object ([zaplang-io/zap#997](https://github.com/zaplang-io/zap/issues/997), merged) as its parsing engine, and adds the command/option declaration surface, subcommand grouping, automatic `--help` rendering, and exit-code conventions on top. Core owns *how argv is parsed*; `cli` owns *how commands are declared, dispatched, and reported*.

## Planned surface (first cut)

The exact signatures (decorator vs. declaration form, keyword-vs-positional, defaults, return shapes) are **not final** — see the epic. Illustrative only:

```zap
import cli

# A command: typed options and arguments, auto --help.
@cli.command(help="Greet a user.")
@cli.option("--count", int64, default=1, help="Repetitions.")
@cli.argument("name", str)
def greet(int64 count, str name):
    for _ in range(count):
        print("Hello " + name)

# A group with subcommands (git-style: tool build / tool test).
app = cli.Group(name="tool")
app.add(greet)

def main():
    app.run()   # parses argv, dispatches, prints --help, returns an exit code
```

Python analogs:

| Concern | click | typer | Proposed Zap surface |
| --- | --- | --- | --- |
| Declare a command | `@click.command()` | function + `typer.Typer()` | `@cli.command(...)` |
| Typed option | `@click.option("--n", type=int)` | typed param + `typer.Option` | `@cli.option("--n", int64, ...)` |
| Positional argument | `@click.argument("name")` | typed param + `typer.Argument` | `@cli.argument("name", str)` |
| Group / subcommands | `@click.group()` | nested `Typer` | `cli.Group(...)` + `.add(...)` |
| Automatic `--help` | built-in | built-in | rendered from declared metadata |
| Error / exit | `click.UsageError`, `ctx.exit(code)` | `typer.Exit`, `typer.Abort` | `cli.UsageError`, `cli.Exit`, `cli.Abort` |

## Phased plan

- **Phase 0 — docs-first.** Pin the public surface, the layering over core `argparse`, README, DECISIONS, threat model. ([#2](https://github.com/zaplang-io/cli/issues/2))
- **Phase 1 — first slice.** Command + typed options & arguments ([#3](https://github.com/zaplang-io/cli/issues/3)); groups / subcommands + automatic `--help` ([#4](https://github.com/zaplang-io/cli/issues/4)); error handling + exit codes ([#5](https://github.com/zaplang-io/cli/issues/5)).
- **Phase 2+ — breadth (named in the epic, not yet filed).** Prompts & confirmation, progress bars, environment-variable binding, shell completion, rich help rendering.

## Build and test

Run the native `zap test` suite against a temporary consumer that installs this
checkout as a package:

```
sh tools/test.sh
```

GitHub Actions runs the suite on pull requests and pushes inside the
`ghcr.io/zaplang-io/zap:latest` container. CI stays pinned to `zap:latest`
until this module reaches a 1.0 release.

## Development

Read **[AGENTS.md](AGENTS.md)** before contributing — it covers the click/typer-parity rule, the one-issue-one-PR flow, how design decisions are recorded in **[DECISIONS.md](DECISIONS.md)**, and the rule for reporting core Zap language/stdlib defects upstream in `zaplang-io/zap` (rather than working around them here).
