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

The innermost factory requests the literal `fn(Context, Namespace)` adapter
seam. When the handler omits context, Zap synthesizes an adapter of that same
declared type which ignores the context. Subsequent decorators receive a
declaration containing the existing callback and the ordered parameter
metadata. A separate factory parameter accepts that composed declaration,
and the outer command factory registers the metadata with core `argparse`.
This preserves Zap's monomorphic function model (D-0067).
[Explicit context adapter](https://github.com/zaplang-io/zap/issues/1621) ·
[Callback storage decision](https://github.com/zaplang-io/zap/issues/1674)

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

## Group routing and help

For [#5](https://github.com/zaplang-io/cli/issues/5), the group builds a core
subparser for each command from the same metadata used for direct execution.
Core matches the command name and validates that command's argv. CLI appends
the first line of each command's help in registration order and includes valid
commands in a missing or unknown command diagnostic. The registered command's
parser receives the full program path for contextual help. Command options
retain their metadata, including defaults, in both help entry points.

## Explicit typed context

A handler may declare `cli.Context ctx` as its first parameter. The dispatcher
supplies it directly. `command_name` is the selected command's name and
`command_path` is a `list[str]` of names from the root to the selected command.
For example, running `tool build` produces `["tool", "build"]`. A directly run
command has a one-element path. This first slice uses a concrete context type
for invocation metadata. Application-specific context storage is deferred.
Core passes explicit context through the `fn(Context, Namespace)` adapter seam.
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

The implementation is tracked in [#6](https://github.com/zaplang-io/cli/issues/6).
The command handler boundary applies the same mapping to direct and group dispatch.

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

## Interactive prompts

For [#11](https://github.com/zaplang-io/cli/issues/11), keep the prompt label
and Zap type positional, with the optional typed default named. Support
`str` and `int64`. An empty line selects a supplied default and otherwise
retries. String responses are returned verbatim. Integer responses use Zap's
`int` conversion rules and retry on `ValueError`. Use stdout for prompts and
retry diagnostics. Dispatch translates `Abort()` to status 1 and stderr in
standalone mode. EOF raises `Abort()` even when a default is supplied. Visible
input retains the host's signal behavior.

`confirm(text, default=False, abort=False)` accepts case-insensitive
`y`/`yes` and `n`/`no` after stripping surrounding whitespace. An empty line
selects the default and an invalid answer retries. A decline raises
`Abort()` when `abort=True`.

`prompt(text, kind, default=..., hide_input=False)` accepts named
`hide_input=True` for manual hidden input. Use core `sys.getpass` for echo
control, with the prompt and retries on stderr. Omit default values from
hidden prompt text. Preserve the core `OSError` for non-terminal input and
map hidden EOF to `Abort()`. A hard terminating signal during the read
inherits core's terminal-restoration limitation. Decorator prompting is deferred.
[Zap hidden input](https://github.com/zaplang-io/zap/blob/main/decisions/stdlib/1684-getpass-hidden-input.md)
[Click prompts](https://click.palletsprojects.com/en/stable/prompts/)
[Typer prompts](https://typer.tiangolo.com/tutorial/prompt/)

## Progress bars

For [#12](https://github.com/zaplang-io/cli/issues/12), use
`progressbar(length, label="")` with explicit `bar.update(step)` calls in a
`with` block. The known total and each increment must be nonnegative. An
update beyond the remaining total raises `ValueError` without changing the
count. A zero total displays as complete. Closing an unfinished bar displays
the actual count.

Choose rendering from `io.isatty(sys.stderr_fd())`. Terminal stderr redraws
in place and ends the line on exit. Redirected stderr receives one plain
line on exit. The bar borrows stderr and keeps the handler's exception path
intact when the block unwinds.
[Click progress bars](https://click.palletsprojects.com/en/stable/api/#click.progressbar) ·
[Zap terminal detection](https://github.com/zaplang-io/zap/issues/1685)

## Environment variable options

For [#13](https://github.com/zaplang-io/cli/issues/13), declare
`envvar="APP_JOBS"` as named option metadata. Explicit argv has priority over
a nonempty environment value, which takes priority over the declared default.
An empty variable counts as unset. A nonempty value satisfies a required
option. String values are taken verbatim. Integer values use core conversion,
and a selected invalid value produces a typed usage error with the variable
and option names. Help uses declarative metadata and keeps environment
contents and names out of the generated option rows.

Boolean flags will use Click activation rules after core supports explicit
boolean flag defaults. [Click environment variables](https://click.palletsprojects.com/en/stable/options/#values-from-environment-variables) ·
[Zap flag defaults](https://github.com/zaplang-io/zap/issues/1692)

## Parser ownership

Use Zap core's `ArgumentParser` for argument registration, argv scanning
and matching, validation, and child parser selection. Bind the returned
`Namespace` to a typed handler in `cli`. Build help on `format_help()` with
framework metadata for defaults and command summaries. The framework controls
when a handler or diagnostic runs.

Core recognizes the `--` separator, rejects an option-like token in place of a
missing option value, and rejects attached values on boolean flags.
[zaplang-io/zap#1512](https://github.com/zaplang-io/zap/pull/1512)
