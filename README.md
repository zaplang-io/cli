# cli

Declarative command-line framework for [Zap](https://github.com/zaplang-io/zap) — an official **non-core** package.

- Tracking issue: [zaplang-io/zap#314](https://github.com/zaplang-io/zap/issues/314)
- Contributor & agent conventions: [AGENTS.md](AGENTS.md)
- Design decisions: [DECISIONS.md](DECISIONS.md)

The [Tier-1 epic](https://github.com/zaplang-io/cli/issues/2) tracks the
first release. The framework contract below is specified in
[#3](https://github.com/zaplang-io/cli/issues/3). The checkout exposes
typed command declarations, one level of subcommands, automatic help, and
framework exit helpers.

## First-release scope

```zap
import cli

@cli.command(help="Greet a user.")
@cli.option("--count", int64, default=1, help="Number of greetings.")
@cli.option("--shout", bool, default=False, help="Use uppercase.")
@cli.argument("name", str, help="Person to greet.")
def greet(cli.Context ctx, int64 count, bool shout, str name):
    str greeting = "HELLO " + name if shout else "Hello " + name
    for _ in range(count):
        print(greeting)

def main():
    greet.run()
```

`greet` is a `cli.Command`, so it can also be run directly with
`greet.run()`. A handler can declare `cli.Context ctx` as its first parameter
to receive invocation metadata. The other parameters receive declared option
and positional values.

| Concern | Click | Typer | Zap contract |
| --- | --- | --- | --- |
| Command declaration | `@click.command()` turns the function into a command | `@app.command()` registers a typed function | `@cli.command(name=..., help=...)` builds a command object from a typed handler and stacked metadata decorators. |
| Option | `@click.option("--count", type=int, default=1)` | `count: Annotated[int, typer.Option()] = 1` | Long `--name value` and `--name=value` for `str` and `int64`. A `bool` option is a flag. Pass `default=...` or `required=True` for each value option. Flags default to `False` and store `True` when present. |
| Positional | `@click.argument("name")` | A required typed parameter or `typer.Argument()` | Declare names and types in CLI order. Each required positional consumes one value. |
| Group | `@click.group()` and `add_command()` | `Typer()` and `add_typer()` | Register named subcommands with one level of grouping. Subcommand options follow the subcommand name. |
| Help | Automatic command and group help | Automatic command and group help | `-h` and `--help` show help on stdout and exit 0 without invoking a handler. Group help lists subcommands and their summaries. Command help lists usage, positionals, options, and defaults. |
| Usage error | `click.UsageError` maps to 2 | Invalid invocation exits 2 | `cli.UsageError(message)` maps to a diagnostic and usage on stderr and status 2. |
| Explicit exit or abort | `ctx.exit(code)`, `click.Abort()` | `typer.Exit(code=...)`, `typer.Abort()` | `cli.Exit(code)` exits with that status silently. `cli.Abort()` writes `Aborted.` to stderr and exits 1. Normal handler completion exits 0. |

See [Click options](https://click.palletsprojects.com/en/stable/options/),
[Click commands and groups](https://click.palletsprojects.com/en/stable/commands-and-groups/),
[Click exit codes](https://click.palletsprojects.com/en/stable/exceptions/),
and [Typer command options](https://typer.tiangolo.com/tutorial/commands/options/).
[DECISIONS.md](DECISIONS.md) specifies signatures, defaults, and standalone behavior.

## Groups and help

Register decorated commands on a `cli.Group(name="tool", help="Project tools.")`
with `app.add(command)`, then call `app.run()`. A command's options follow its
name. For example, `tool build --release` passes `--release` to `build`.
`tool --help` lists commands and their summaries, and `tool build --help`
shows the selected command's arguments, options, and defaults. Both accept
`-h`. Missing and unknown commands are usage errors. Subcommands receive the
full command path through optional handler context.

## Exit and usage errors

Raise `cli.UsageError(message)` to report invalid input, `cli.Exit(code)` to
stop with a specific status, or `cli.Abort()` to abort. In standalone mode,
usage errors write usage and a diagnostic to stderr and exit with status 2.
Abort writes `Aborted.` to stderr and exits with status 1. Explicit exits
write nothing. Embedded callers can use `run(standalone_mode=False)` to
receive exit statuses and catch the typed usage and abort exceptions.
Unrelated handler exceptions propagate in either mode.

## Core `argparse` boundary

The parser is Zap core's object API from
[zaplang-io/zap#997](https://github.com/zaplang-io/zap/issues/997).
The framework owns command metadata, typed handler binding, dispatch, help
presentation, and the status and I/O at the run boundary.

| Input or operation | Core API | Framework responsibility |
| --- | --- | --- |
| Command metadata | `ArgumentParser(prog=..., description=...)` | Construct one parser for each command from its declared name and help. |
| Value options and positionals | `add_argument(name, type=..., default=..., required=..., help=...)` | Use core's `"str"` and `"int"` tags and serialize typed option defaults for the parser. Core scans argv and consumes positionals in declaration order. |
| Boolean flags | `add_argument(name, action="store_true")` | Use `Namespace.get_flag` to obtain the boolean value. |
| Parsing and invocation | `parse_args(argv)`, `Namespace.get_str`, `get_int`, `get_flag`, and `has` | Pass argv without the executable name. Bind the validated values to declared parameter types and invoke the selected handler once. |
| Subcommands | `add_subparsers(dest=...)`, `add_parser(name, help=...)`, and `Namespace.get_str` | Keep the selector destination distinct from handler parameters. Register the child parsers and dispatch using the selected name returned by core. |
| Help | `Namespace.help_requested()` and `ArgumentParser.format_help()` | Select the help for the parsed command, add declared defaults and summaries from metadata, and handle the stdout and exit status. |
| Parse failures | Catchable failures from `parse_args(argv)` | Translate input failures to `cli.UsageError` and include the valid command names in diagnostics for an unknown subcommand. |

Zap core now rejects malformed option values and honors `--` as the
end-of-options separator. See
[zaplang-io/zap#1512](https://github.com/zaplang-io/zap/pull/1512).
The innermost decorator receives a monomorphic typed callback through Zap's
explicit context adapter seam. Each subsequent decorator receives the
accumulated declaration, and `command` creates the parser after collecting
all parameters.
Core accepts one name per argument and has no variadic positional argument
API.

## Threat model

Treat argv as untrusted. Unknown options and commands, missing or extra
arguments, and type mismatches must become typed usage errors with a nonzero
status without dispatching the handler. Help uses declaration metadata and
must never execute handler code. The framework inherits the host and core
parser's argv bounds, including for oversized tokens and large argument counts.
The framework stores no credentials. Environment-variable binding is deferred
and will require explicit opt-in per option.

## Implementation order

- [#3 Public surface and core parser boundary](https://github.com/zaplang-io/cli/issues/3)
- [#4 Commands, typed options, and arguments](https://github.com/zaplang-io/cli/issues/4)
- [#5 Groups, subcommands, and automatic help](https://github.com/zaplang-io/cli/issues/5)
- [#6 Error handling and exit codes](https://github.com/zaplang-io/cli/issues/6)

Prompts and confirmation, progress bars, environment-variable binding, shell
completion, and rich help are later work tracked in the epic.

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
