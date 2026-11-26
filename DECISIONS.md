# cli package decisions

The first-release contract is tracked in
[#3](https://github.com/zaplang-io/cli/issues/3) under the
[Tier-1 epic](https://github.com/zaplang-io/cli/issues/2).
[README.md](README.md) describes the parser boundary and threat model.

## Declaration and handler binding

Use Click-style command objects. `@cli.command(name=..., help="")` binds the
decorated name to a `cli.Command`. Omitting `name` uses the function name.
Stack `@cli.option` and `@cli.argument` below `@cli.command`. Bind by matching
each declaration to the handler parameter name. For an option, remove the
leading `--` and replace interior hyphens with underscores. For a positional,
use the declared parameter name. Positional decorators establish argv order
from top to bottom. The handler is called with typed values in its own
signature order. Declaration names must resolve to unique parameters whose
types match the declarations.
[Click commands and groups](https://click.palletsprojects.com/en/stable/commands-and-groups/)
[Click option names](https://click.palletsprojects.com/en/stable/options/)
[Typer commands](https://typer.tiangolo.com/tutorial/commands/)

A returning dotted decorator binds the returned object under the decorated
name. Core supports imported module functions and adapts argv-sourced scalar
parameters by name through `fn(Namespace)`.
[zaplang-io/zap#1519](https://github.com/zaplang-io/zap/issues/1519) ·
[zaplang-io/zap#1544](https://github.com/zaplang-io/zap/issues/1544)

## Signatures and defaults

- `option(name, type, default=..., required=False, help="")` takes the long
  option spelling and its Zap type positionally. For `str` and `int64`, provide
  a typed `default` or use `required=True`. A `bool` option is a flag with
  `default=False` that stores `True` when supplied. Paired boolean flags and
  short aliases are deferred.
- `argument(name, type, help="")` takes the name and the `str` or `int64`
  type positionally. It consumes one required value. Optional positionals
  are deferred.
- `Group(name=..., help="")` requires a name. `add(command)` takes the child
  positionally. The first release supports one level. A missing subcommand
  produces usage and status 2. Child options belong after the child name.
- `-h` and `--help` render the applicable command's usage and help on stdout,
  including available subcommands at the group level. Help returns success
  without calling a handler.

[Click options](https://click.palletsprojects.com/en/stable/options/)
[Click arguments](https://click.palletsprojects.com/en/stable/arguments/)

## Explicit typed context

A handler may declare `cli.Context ctx` as its first parameter. The dispatcher
supplies it directly. `command_name` is the selected command's name and
`command_path` is a `list[str]` of names from the root to the selected command.
For example, running `tool build` produces `["tool", "build"]`. A directly run
command has a one-element path. This first slice uses a concrete context type
for invocation metadata. Application-specific context storage is deferred.
The compiler adapter still needs to pass explicit context through.
[zaplang-io/zap#1621](https://github.com/zaplang-io/zap/issues/1621)
[Click contexts](https://click.palletsprojects.com/en/stable/commands-and-groups/#context)
[Typer context](https://typer.tiangolo.com/tutorial/commands/context/)

## Variadic arguments

The eventual surface is one trailing `list[T]` positional. The first slice
supports fixed-arity positionals. Variadics follow once core supports declaring
and retrieving them.
[Click arguments](https://click.palletsprojects.com/en/stable/arguments/)
[Typer multiple arguments](https://typer.tiangolo.com/tutorial/multiple-values/arguments-with-multiple-values/)

## Run boundary and exits

`Command.run(argv=..., standalone_mode=True)` and `Group.run` share the same
behavior. Omitted argv means `sys.argv()[1:]`. An explicit empty list means an
empty invocation. In standalone mode the framework exits the process after
handling normal completion and framework errors.

| Outcome | Standalone behavior | `standalone_mode=False` |
| --- | --- | --- |
| Handler completes | Exit 0 | Return 0 |
| Help requested | Print help to stdout, exit 0 | Print help to stdout, return 0 |
| `UsageError(message)` or invalid argv | Print usage and diagnostic to stderr, exit 2 | Raise `UsageError` |
| `Exit(code=0)` | Exit with the given code | Return the code |
| `Abort()` | Print `Aborted.` to stderr, exit 1 | Raise `Abort` |
| Unrelated handler exception | Propagate | Propagate |

`UsageError` takes its message positionally. `Exit` accepts its integer code
positionally or as `code=`. The non-standalone path lets callers exercise the
same dispatch contract with native status assertions and typed error checks.
[Click exit codes and standalone mode](https://click.palletsprojects.com/en/stable/exceptions/)
[Typer termination](https://typer.tiangolo.com/tutorial/terminating/)

## Parser ownership

Use Zap core's `ArgumentParser` for argument registration, argv scanning
and matching, validation, and child parser selection. Bind the returned
`Namespace` to a typed handler in `cli`. Build help on `format_help()` with
framework metadata for defaults and command summaries. The framework controls
when a handler or diagnostic runs.

Core recognizes the `--` separator, rejects an option-like token in place of a
missing option value, and rejects attached values on boolean flags.
[zaplang-io/zap#1512](https://github.com/zaplang-io/zap/pull/1512)
