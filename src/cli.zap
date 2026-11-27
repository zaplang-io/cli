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

# End the command with an explicit process status.
@exception
struct Exit:
    int64 code = 0

# End the command as an abort.
@exception
struct Abort:
    pass


# A configured parser and the typed callback synthesized for its command.
struct Command:
    str name
    ArgumentParser _parser
    fn(Context, Namespace) _handler
    list[_Parameter] _parameters = []

    # Run with explicit argv or the process arguments when argv is omitted.
    # Embedded calls return a status and can catch UsageError.
    def run(
        self,
        Optional[list[str]] argv = None,
        bool standalone_mode = True,
    ) -> int64:
        list[str] args = argv.unwrap() if argv.is_some() else sys.argv()[1:]
        dict[str, str] environment = _environment_defaults(self._parameters)
        ArgumentParser parser = self._parser
        if len(environment) > 0:
            parser = argparse.ArgumentParser(
                prog=self.name,
                description=self._parser.description,
            )
            _register_parameters(parser, self._parameters, environment)

        Namespace values = Namespace()
        try:
            values = parser.parse_args(args)
        except Exception as error:
            return _usage_failure(error, self._parser.format_help(), standalone_mode)

        if values.help_requested():
            print(self._parser.format_help())
            return _finish(0, standalone_mode)
        return self._dispatch(
            values,
            [self.name],
            self._parser,
            standalone_mode,
            environment,
        )

    def _dispatch(
        self,
        Namespace values,
        list[str] path,
        ArgumentParser parser,
        bool standalone_mode,
        dict[str, str] environment,
    ) -> int64:
        for parameter in self._parameters:
            if parameter.kind == "int64" and parameter.name in environment:
                str key = _parameter_key(parameter.name)
                if not values.has(key):
                    try:
                        values.get_int(key)
                    except ValueError:
                        str error = "environment variable " + parameter.envvar + " for " + parameter.name + " requires an integer"
                        return _usage_failure(
                            error,
                            parser.format_help(),
                            standalone_mode,
                        )
        Context ctx = Context(command_name=self.name, command_path=path)
        auto handler = self._handler
        try:
            handler(ctx, values)
        except UsageError as error:
            if not standalone_mode:
                raise
            return _usage_failure(error, parser.format_help(), standalone_mode)
        except Exit as error:
            return _finish(error.code, standalone_mode)
        except Abort:
            if not standalone_mode:
                raise
            io.write(sys.stderr_fd(), "Aborted.\n")
            return _finish(1, standalone_mode)
        return _finish(0, standalone_mode)

# A named collection of commands. Registration order controls help display.
struct Group:
    str name
    str help = ""
    list[Command] _commands = []

    # Register a command by its public name.
    def add(self, Command command):
        if command.name == "" or command.name.startswith("-"):
            raise UsageError("invalid command name: " + command.name)
        for existing in self._commands:
            if existing.name == command.name:
                raise UsageError("duplicate command: " + command.name)
        self._commands.append(command)

    # Parse argv through the core subparsers and dispatch the selected command.
    def run(
        self,
        Optional[list[str]] argv = None,
        bool standalone_mode = True,
    ) -> int64:
        list[str] args = argv.unwrap() if argv.is_some() else sys.argv()[1:]
        auto parser = argparse.ArgumentParser(prog=self.name, description=self.help)
        # Brackets make this reserved destination distinct from handler parameters.
        str selector = "<command>"
        auto children = parser.add_subparsers(dest=selector)
        dict[str, ArgumentParser] child_parsers = {}
        dict[str, dict[str, str]] child_environment = {}
        for command in self._commands:
            auto child = children.add_parser(
                command.name,
                help=command._parser.description,
            )
            child.prog = self.name + " " + command.name
            auto environment = _environment_defaults(command._parameters)
            _register_parameters(child, command._parameters, environment)
            child_parsers[command.name] = child
            child_environment[command.name] = environment

        Namespace values = Namespace()
        try:
            values = parser.parse_args(args)
        except Exception as error:
            str unknown = "argument " + selector + ": invalid choice: "
            if error.startswith(unknown):
                error = "unknown command: " + error[len(unknown):] + self._choices()
            return _usage_failure(error, self._format_help(parser), standalone_mode)

        if not values.has(selector):
            if not values.help_requested():
                return _usage_failure(
                    "missing command" + self._choices(),
                    self._format_help(parser),
                    standalone_mode,
                )
            print(self._format_help(parser))
        else:
            str selected = values.get_str(selector)
            for command in self._commands:
                if command.name == selected:
                    auto environment = child_environment[selected]
                    auto child = child_parsers[selected]
                    if len(environment) > 0:
                        child = argparse.ArgumentParser(
                            prog=child.prog,
                            description=child.description,
                        )
                        _register_parameters(child, command._parameters)
                    if values.help_requested():
                        print(child.format_help())
                        break
                    return command._dispatch(
                        values,
                        [self.name, command.name],
                        child,
                        standalone_mode,
                        environment,
                    )
        return _finish(0, standalone_mode)

    def _choices(self) -> str:
        if len(self._commands) == 0:
            return " (no commands registered)"
        list[str] names = [command.name for command in self._commands]
        return ". Available commands: " + ", ".join(names)

    def _format_help(self, ArgumentParser parser) -> str:
        str help = parser.format_help()
        if len(self._commands) > 0:
            help = help + "\n\ncommands:"
        for command in self._commands:
            str summary = command._parser.description
            int64 newline = summary.find("\n")
            if newline >= 0:
                summary = summary[:newline]
            help = help + "\n  " + command.name
            if summary != "":
                help = help + "  " + summary
        return help

def _finish(int64 code, bool standalone_mode) -> int64:
    if standalone_mode:
        sys.exit(code)
    return code

def _usage_failure(str message, str usage, bool standalone_mode) -> int64:
    if not standalone_mode:
        raise UsageError(message)
    io.write(sys.stderr_fd(), usage + "\nError: " + message + "\n")
    return _finish(2, standalone_mode)

# Metadata is collected before the parser is constructed. Every outer decorator
# receives the declaration rather than another function value.
struct _Parameter:
    str name
    str kind
    str default_value = ""
    bool required = False
    str help = ""
    str envvar = ""

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
    str envvar = "",
) -> _Declaration:
    str type_name = reflect.type_info(T).name
    if not name.startswith("--") or name.startswith("---") or len(name) < 3 or name == "--help" or name.find("=") >= 0:
        raise UsageError("invalid long option name: " + name)
    str default_value = str(default.unwrap()) if default.is_some() else ""
    if type_name == "bool":
        if envvar != "":
            raise UsageError(
                "boolean environment defaults require core argparse support: " + name,
            )
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
        envvar=envvar,
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
        _register_parameters(parser, declaration.parameters)
        return Command(
            name=name,
            _parser=parser,
            _handler=declaration.handler,
            _parameters=declaration.parameters,
        )
    return Command(name=name, _parser=parser, _handler=handler)

def _parameter_key(str name) -> str:
    return (name[2:] if name.startswith("--") else name).replace("-", "_")

def _environment_defaults(list[_Parameter] parameters) -> dict[str, str]:
    dict[str, str] result = {}
    for parameter in parameters:
        if parameter.envvar != "":
            str value = os.getenv(parameter.envvar)
            if value != "":
                result[parameter.name] = value
    return result

def _register_parameters(
    ArgumentParser parser,
    list[_Parameter] parameters,
    dict[str, str] environment = {},
):
    dict[str, bool] destinations = {}
    for parameter in parameters:
        str arg_name = parameter.name
        bool option = arg_name.startswith("--")
        str key = _parameter_key(arg_name)
        if key == "<command>":
            raise UsageError("reserved parameter: " + key)
        if key in destinations:
            raise UsageError("duplicate parameter: " + key)
        destinations[key] = True
        str help = parameter.help
        if option and not parameter.required:
            str default_label = parameter.default_value
            if parameter.kind == "bool":
                default_label = "False"
            elif default_label == "":
                default_label = '""'
            if help != "":
                help = help + " "
            help = help + "[default: " + default_label + "]"
        if parameter.kind == "bool":
            parser.add_argument(arg_name, action="store_true", help=help)
        else:
            str parser_type = "int" if parameter.kind == "int64" else "str"
            bool has_environment = arg_name in environment
            str fallback = environment[arg_name] if has_environment else parameter.default_value
            parser.add_argument(
                arg_name,
                type=parser_type,
                default=fallback,
                required=parameter.required and not has_environment,
                help=help,
            )

# Read one response and translate EOF to the framework's abort path.
def _prompt_line(str text, bool hide_input = False) -> str:
    try:
        if hide_input:
            return sys.getpass(text)
        return input(text)
    except EOFError:
        raise Abort()

def _convert_prompt_value[T](Type[T] kind, str value) -> T:
    if reflect.type_info(T).name == "int64":
        return int(value)
    elif reflect.type_info(T).name == "str":
        return value
    raise UsageError("prompt supports str and int64")

# Read text or an integer, retrying malformed input. Hidden prompts use stderr
# and require a terminal. Their typed defaults stay out of the prompt text.
def prompt[T](
    str text,
    Type[T] kind,
    Optional[T] default = None,
    bool hide_input = False,
) -> T:
    str type_name = reflect.type_info(T).name
    if type_name != "str" and type_name != "int64":
        raise UsageError("prompt supports str and int64")
    str label = text
    if default.is_some() and not hide_input:
        label = label + " [" + str(default.unwrap()) + "]"
    label = label + ": "
    int64 output = sys.stderr_fd() if hide_input else sys.stdout_fd()
    while True:
        str response = _prompt_line(label, hide_input=hide_input)
        if response == "":
            if default.is_some():
                return default.unwrap()
            io.write(output, "Error: A response is required.\n")
        else:
            try:
                return _convert_prompt_value(kind, response)
            except ValueError:
                io.write(output, "Error: Enter a valid integer.\n")

# Read a case-insensitive yes/no answer and optionally abort on a decline.
def confirm(str text, bool default = False, bool abort = False) -> bool:
    str label = text + (" [Y/n]: " if default else " [y/N]: ")
    while True:
        str response = _prompt_line(label).strip().lower()
        bool accepted = False
        if response == "":
            accepted = default
        elif response == "y" or response == "yes":
            accepted = True
        elif response != "n" and response != "no":
            io.write(sys.stdout_fd(), "Error: Enter yes or no.\n")
            continue
        if abort and not accepted:
            raise Abort()
        return accepted

# A progress display that borrows stderr for the duration of its with block.
struct ProgressBar:
    int64 length
    str label
    bool _terminal
    int64 completed = 0
    bool _active = False

    def __enter__(self) -> ProgressBar:
        if self._active:
            raise ValueError("progress bar is already active")
        self.completed = 0
        if self._terminal:
            io.write(sys.stderr_fd(), "\r" + self._line())
        self._active = True
        return self

    def __exit__(self):
        if not self._active:
            return
        self._active = False
        str tail = "\n" if self._terminal else self._line() + "\n"
        io.write(sys.stderr_fd(), tail)

    # Advance by a nonnegative amount that fits within the declared total.
    def update(self, int64 step):
        if not self._active:
            raise ValueError("progress bar is not active")
        if step < 0 or step > self.length - self.completed:
            raise ValueError("progress update is outside the remaining total")
        if step > 0:
            self.completed = self.completed + step
            if self._terminal:
                io.write(sys.stderr_fd(), "\r" + self._line())

    def _line(self) -> str:
        int64 width = 20
        int64 filled = width
        if self.completed < self.length:
            filled = min(
                width - 1,
                int(float(self.completed) / float(self.length) * float(width)),
            )
        str cells = ""
        for i in range(width):
            cells = cells + ("#" if i < filled else "-")
        str prefix = self.label + " " if self.label != "" else ""
        return prefix + "[" + cells + "] " + str(self.completed) + "/" + str(self.length)

# Create a progress bar for a known total, using stderr for feedback.
# Terminal stderr redraws in place. Redirected stderr gets one final line.
def progressbar(int64 length, str label = "") -> ProgressBar:
    if length < 0:
        raise ValueError("progress length must be nonnegative")
    return ProgressBar(length=length, label=label, _terminal=io.isatty(sys.stderr_fd()))
