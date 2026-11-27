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

# Metadata is collected before the parser is constructed. Every outer decorator
# receives the declaration rather than another function value.
struct _Parameter:
    str name
    str kind
    str default_value = ""
    bool required = False
    str help = ""

struct _Declaration:
    list[_Parameter] parameters
    fn(Context, Namespace) handler

def _missing_handler(Context ctx, Namespace values):
    raise UsageError("command declaration has no handler")

def _prepend(
    _Parameter parameter,
    Optional[_Declaration] previous,
    fn(Context, Namespace) handler,
) -> _Declaration:
    if previous.is_some():
        auto declaration = previous.unwrap()
        declaration.parameters.insert(0, parameter)
        return declaration
    return _Declaration(parameters=[parameter], handler=handler)

# Declare a required positional with a Zap type and optional help text.
def argument[T](
    str name,
    Type[T] kind,
    Optional[_Declaration] previous = None,
    fn(Context, Namespace) handler = _missing_handler,
    str help = "",
) -> _Declaration:
    str type_name = reflect.type_info(T).name
    if name == "" or name.startswith("-"):
        raise UsageError("invalid positional name: " + name)
    if type_name != "int64" and type_name != "str":
        raise UsageError("unsupported positional type for " + name + ": " + type_name)
    return _prepend(_Parameter(name=name, kind=type_name, help=help), previous, handler)

# Declare a long option with a typed default, or mark a value option required.
# A bool option is a zero-arity flag that defaults to False.
def option[T](
    str name,
    Type[T] kind,
    Optional[_Declaration] previous = None,
    fn(Context, Namespace) handler = _missing_handler,
    Optional[T] default = None,
    bool required = False,
    str help = "",
) -> _Declaration:
    str type_name = reflect.type_info(T).name
    if not name.startswith("--") or name.startswith("---") or len(name) < 3 or name == "--help" or name.find("=") >= 0:
        raise UsageError("invalid long option name: " + name)
    str default_value = str(default.unwrap()) if default.is_some() else ""
    if type_name == "bool":
        if required or default_value == "True":
            raise UsageError("boolean flag requires a False default: " + name)
    elif type_name == "int64" or type_name == "str":
        if required == default.is_some():
            raise UsageError("provide a default or required=True for " + name)
    else:
        raise UsageError("unsupported option type for " + name + ": " + type_name)
    auto parameter = _Parameter(
        name=name,
        kind=type_name,
        default_value=default_value,
        required=required,
        help=help,
    )
    return _prepend(parameter, previous, handler)

# Finish the declaration and bind the resulting Command under the function name.
# Zap provides the original declaration name when name is omitted.
def command(
    Optional[_Declaration] previous = None,
    fn(Context, Namespace) handler = _missing_handler,
    str name = "",
    str help = "",
) -> Command:
    auto parser = argparse.ArgumentParser(prog=name, description=help)
    if previous.is_some():
        auto declaration = previous.unwrap()
        dict[str, bool] destinations = {}
        for parameter in declaration.parameters:
            str arg_name = parameter.name
            str key = (arg_name[2:] if arg_name.startswith("--") else arg_name).replace(
                "-",
                "_",
            )
            if key in destinations:
                raise UsageError("duplicate parameter: " + key)
            destinations[key] = True
            if parameter.kind == "bool":
                parser.add_argument(arg_name, action="store_true", help=parameter.help)
            else:
                str parser_type = "int" if parameter.kind == "int64" else "str"
                parser.add_argument(
                    arg_name,
                    type=parser_type,
                    default=parameter.default_value,
                    required=parameter.required,
                    help=parameter.help,
                )
        return Command(name=name, _parser=parser, _handler=declaration.handler)
    return Command(name=name, _parser=parser, _handler=handler)
