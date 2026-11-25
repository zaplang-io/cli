# cli package decisions

The first-release contract is tracked in
[#3](https://github.com/zaplang-io/cli/issues/3) under the
[Tier-1 epic](https://github.com/zaplang-io/cli/issues/2).
[README.md](README.md) describes the parser boundary and threat model.

## Parser ownership

Use Zap core's `ArgumentParser` for argument registration, argv tokenization and
matching, validation, and child parser selection. Bind the returned `Namespace`
to a typed handler in `cli`. Build help on `format_help()` with framework
metadata for defaults and command summaries. The framework controls when a
handler or diagnostic runs.

Core dependencies for matching malformed input and option-like positionals
are tracked in [zaplang-io/zap#1508](https://github.com/zaplang-io/zap/issues/1508)
and [zaplang-io/zap#1507](https://github.com/zaplang-io/zap/issues/1507).

## Pending maintainer decisions

### Declaration and handler binding

Click uses stacked decorators such as `@click.option("--count", type=int)`
and replaces the decorated name with a command object. The corresponding
Zap proposal uses `@cli.command(help="Greet a user.")`,
`@cli.option("--count", int64, default=1)`, and
`@cli.argument("name", str)` over `def greet(int64 count, str name)`,
then calls `greet.run()`. Zap's current dotted decorator lowering emits a
registration call and leaves the decorated name as a function. A behavioral
wrapper also preserves the original function signature. Command-object
replacement would require a core capability.
[Click commands and groups](https://click.palletsprojects.com/en/stable/commands-and-groups/)

Typer uses `@app.command()` to register the function and reads the parameter
types and metadata from the signature. Zap's registering decorator has a
corresponding app method call. Inferring argument declarations and producing a
typed binder still requires a language-level feasibility check. A first release
with both forms would need both declaration contracts.
[Typer commands](https://typer.tiangolo.com/tutorial/commands/)

### Context

Click can inject a context through `@click.pass_context` and attach arbitrary
application data to `Context.obj`. Typer can receive context as an explicitly
typed handler parameter. The proposed first release passes only the declared
typed arguments. An explicit typed context parameter is the alternative if
group state needs to flow into handlers in this release.
[Click contexts](https://click.palletsprojects.com/en/stable/commands-and-groups/#context)
[Typer context](https://typer.tiangolo.com/tutorial/commands/context/)

### Variadic arguments

Click's `nargs=-1` collects one trailing positional into a tuple. Typer uses
`list[T]`. The proposal defers variadics until core has a way to declare a
trailing variadic and retrieve its typed values. If included in the first
release, the same core capability would gate the typed positional contract.
[Click arguments](https://click.palletsprojects.com/en/stable/arguments/)
[Typer multiple arguments](https://typer.tiangolo.com/tutorial/multiple-values/arguments-with-multiple-values/)

### Run boundary and exits

The proposal is `run(argv=...)` returning an `int64` status. With argv
omitted, use `sys.argv()[1:]`; an explicit empty list represents an empty
invocation. The executable can call `sys.exit` with the returned status.
Propagate unrelated handler exceptions. Click defaults to process exit and
offers a non-standalone mode to leave control with the caller. Typer exposes
`Exit` and `Abort` for intentional termination.
[Click exit codes](https://click.palletsprojects.com/en/stable/exceptions/)
[Typer termination](https://typer.tiangolo.com/tutorial/terminating/)

### Optional metadata and defaults

For the command-object proposal, make option and argument names and declared
types positional. Use keywords for optional metadata such as `default=`,
`required=` and `help=`. In that proposal `command(name=..., help=...)`
would infer the function name when omitted and default help to an empty string.
`Group(name=..., help=...)` would require the group name, default help to an
empty string, and take the child positionally in `add(child)`. A bare group
would report a missing command with status 2. Omitting a boolean flag default
would mean `False`. Short aliases and optional positionals would be deferred.
The declaration-form decision may change the option and argument signatures.
[Click options](https://click.palletsprojects.com/en/stable/options/)
