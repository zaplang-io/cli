# Declarative command objects backed by Zap core's ArgumentParser.

# Return the installed CLI package version.
def version() -> str:
    return "0.1.0"

# The command selected for an invocation and its path from the root command.
struct Context:
    str command_name
    list[str] command_path

# An invalid invocation, with a diagnostic suitable for command-line users.
@exception
struct UsageError:
    str message

# A configured parser and the typed callback synthesized for its command.
struct Command:
    str name
    ArgumentParser _parser
    fn(Context, Namespace) _handler

    # Run with explicit argv or the process arguments when argv is omitted.
    # Embedded calls return a status and can catch UsageError.
    def run(
        self,
        Optional[list[str]] argv = None,
        bool standalone_mode = True,
    ) -> int64:
        list[str] args = argv.unwrap() if argv.is_some() else sys.argv()[1:]
        Namespace values = Namespace()
        try:
            values = self._parser.parse_args(args)
        except Exception as error:
            if not standalone_mode:
                raise UsageError(error)
            io.write(
                sys.stderr_fd(),
                self._parser.format_help() + "\nError: " + error + "\n",
            )
            sys.exit(2)
            return 2

        if not values.help_requested():
            Context ctx = Context(command_name=self.name, command_path=[self.name])
            auto handler = self._handler
            handler(ctx, values)
        if standalone_mode:
            sys.exit(0)
        return 0
