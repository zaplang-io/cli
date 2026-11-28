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
        bool color = False,
        int64 width = 80,
    ) -> int64:
        _check_help_width(width)
        list[str] args = argv.unwrap() if argv.is_some() else sys.argv()[1:]
        str completion = _completion_request(self.name)
        if completion != "":
            if not _emit_completion_source(self.name, completion):
                _emit_completion_candidates(self._parser, completion, args)
            return _finish(0, standalone_mode)
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
            return _usage_failure(
                error,
                _command_help(self._parser, self._parameters, color, width),
                standalone_mode,
            )

        if values.help_requested():
            print(_command_help(self._parser, self._parameters, color, width))
            return _finish(0, standalone_mode)
        return self._dispatch(
            values,
            [self.name],
            self._parser,
            standalone_mode,
            environment,
            color,
            width,
        )

    def _dispatch(
        self,
        Namespace values,
        list[str] path,
        ArgumentParser parser,
        bool standalone_mode,
        dict[str, str] environment,
        bool color,
        int64 width,
    ) -> int64:
        Context ctx = Context(command_name=self.name, command_path=path)
        auto handler = self._handler
        try:
            for parameter in self._parameters:
                _validate_parameter(parameter, values, parameter.name in environment)
            for parameter in self._parameters:
                if parameter.transform.is_some():
                    fn(Namespace) transform = parameter.transform.unwrap()
                    transform(values)
            for parameter in self._parameters:
                if parameter.deprecation != "" and values.has(_parameter_key(parameter.name)):
                    io.write(
                        sys.stderr_fd(),
                        "Warning: " + _escape_controls(parameter.deprecation) + "\n",
                    )
            handler(ctx, values)
        except UsageError as error:
            if not standalone_mode:
                raise
            return _usage_failure(
                error,
                _command_help(parser, self._parameters, color, width),
                standalone_mode,
            )
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
        bool color = False,
        int64 width = 80,
    ) -> int64:
        _check_help_width(width)
        list[str] args = argv.unwrap() if argv.is_some() else sys.argv()[1:]
        str completion = _completion_request(self.name)
        if completion != "" and _emit_completion_source(self.name, completion):
            return _finish(0, standalone_mode)
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
            dict[str, str] environment = {}
            if completion == "":
                environment = _environment_defaults(command._parameters)
            _register_parameters(child, command._parameters, environment)
            child_parsers[command.name] = child
            child_environment[command.name] = environment

        if completion != "":
            _emit_completion_candidates(parser, completion, args)
            return _finish(0, standalone_mode)

        Namespace values = Namespace()
        try:
            values = parser.parse_args(args)
        except Exception as error:
            str unknown = "argument " + selector + ": invalid choice: "
            if error.startswith(unknown):
                error = "unknown command: " + error[len(unknown):] + self._choices()
            return _usage_failure(
                error,
                self._format_help(parser, selector, color, width),
                standalone_mode,
            )

        if not values.has(selector):
            if not values.help_requested():
                return _usage_failure(
                    "missing command" + self._choices(),
                    self._format_help(parser, selector, color, width),
                    standalone_mode,
                )
            print(self._format_help(parser, selector, color, width))
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
                        print(_command_help(child, command._parameters, color, width))
                        break
                    return command._dispatch(
                        values,
                        [self.name, command.name],
                        child,
                        standalone_mode,
                        environment,
                        color,
                        width,
                    )
        return _finish(0, standalone_mode)

    def _choices(self) -> str:
        if len(self._commands) == 0:
            return " (no commands registered)"
        list[str] names = [command.name for command in self._commands]
        return ". Available commands: " + ", ".join(names)

    def _format_help(
        self,
        ArgumentParser parser,
        str selector,
        bool color,
        int64 width,
    ) -> str:
        auto help = _start_help(parser, color, width)
        list[str] names = [command.name for command in self._commands]
        help.heading("positional arguments:")
        help.row(selector, "{" + ",".join(names) + "}")
        _help_option(help)
        if len(self._commands) > 0:
            help.heading("commands:")
        for command in self._commands:
            str summary = command._parser.description.split("\n")[0]
            help.row(command.name, _escape_controls(summary))
        return "\n".join(help.lines)

# The completion branch runs before environment defaults, parsing, or dispatch.
def _completion_variable(str name) -> str:
    str alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    list[str] pieces = ["_"]
    for char in name.upper():
        str piece = str(char)
        pieces.append(piece if alphabet.find(piece) >= 0 else "_")
    pieces.append("_COMPLETE")
    return "".join(pieces)

def _completion_request(str name) -> str:
    if name == "" or name.startswith("-"):
        return ""
    return os.getenv(_completion_variable(name))

def _emit_completion_source(str name, str mode) -> bool:
    str template = ""
    if mode == "bash_source":
        template = _bash_completion_source()
    elif mode == "zsh_source":
        template = _zsh_completion_source()
    elif mode == "fish_source":
        template = _fish_completion_source()
    else:
        return False
    str variable = _completion_variable(name)
    list[str] identity = ["_zap_complete"]
    for char in name:
        identity.append(str(ord(char)))
    str function_name = "_".join(identity)
    str program = "'" + name.replace("'", "'\"'\"'") + "'"
    if mode == "fish_source":
        program = "'" + name.replace("\\", "\\\\").replace("'", "\\'") + "'"
    str assignment = variable + "=" + mode.replace("_source", "_complete")
    io.write(
        sys.stdout_fd(),
        template.replace("@FUNCTION@", function_name).replace("@QUERY@", assignment).replace(
            "@PROGRAM@",
            program,
        ),
    )
    return True

def _emit_completion_candidates(ArgumentParser parser, str mode, list[str] args):
    if mode not in ["bash_complete", "zsh_complete", "fish_complete"] or len(args) < 2:
        return
    int64 cursor = 0
    try:
        cursor = int(args[0])
    except ValueError:
        return
    list[str] words = args[1:]
    if cursor < 0 or cursor >= len(words):
        return
    str prefix = words[cursor]
    auto context = parser.completion_context(words[:cursor], prefix)
    if context.invalid:
        return
    str attached = ""
    if context.kind == "value" and prefix != context.value_prefix:
        attached = context.active_option + "="
    str nul = "\x00"
    for candidate in context.candidates:
        if candidate != "" and candidate.find(nul) < 0:
            io.write(sys.stdout_fd(), attached + candidate + nul)

def _bash_completion_source() -> str:
    return """@FUNCTION@() {
    local LC_ALL=C
    local line=${COMP_LINE:0:COMP_POINT} char state=plain word='' started=0 i
    local -a before=()
    for ((i = 0; i < ${#line}; i++)); do
        char=${line:i:1}
        case "$state:$char" in
            "single:'"|'double:"') state=plain ;;
            'plain:"') state=double; started=1 ;;
            "plain:'") state=single; started=1 ;;
            'plain:\\'|'double:\\')
                if ((i + 1 < ${#line})); then
                    ((i++))
                    char=${line:i:1}
                    if [[ $char == $'\\n' ]]; then
                        continue
                    fi
                    if [[ $state == double && $char != [\\$\\`\\"\\\\] ]]; then
                        word+='\\'
                    fi
                    word+=$char
                    started=1
                fi ;;
            'plain: ' | plain:$'\\t' | plain:$'\\n')
                if ((started)); then
                    before+=("$word")
                    word=''
                    started=0
                fi ;;
            plain:[\\;\\|\\&]) before=(); word=''; started=0 ;;
            *) word+=$char; started=1 ;;
        esac
    done
    COMPREPLY=()
    (( ${#before[@]} > 0 )) || return 0
    local candidate
    while IFS= read -r -d '' candidate; do
        # Readline keeps the left side when '=' is a completion word break.
        if [[ $word == --*=* && $candidate == --*=* &&
              $COMP_WORDBREAKS == *=* && $2 != --*=* ]]; then
            candidate=${candidate#*=}
        fi
        COMPREPLY+=("$candidate")
    done < <(env @QUERY@ @PROGRAM@ "$((${#before[@]} - 1))" "${before[@]:1}" "$word")
}
complete -o filenames -F @FUNCTION@ -- @PROGRAM@
"""

def _zsh_completion_source() -> str:
    return """@FUNCTION@() {
    local -a before candidates
    local token value i
    for ((i = 2; i < CURRENT; i++)); do
        token=$words[i]
        before+=("${(Q)token}")
    done
    while IFS= read -r -d '' value; do
        candidates+=("$value")
    done < <(env @QUERY@ @PROGRAM@ "${#before}" "${before[@]}" "$IPREFIX$PREFIX")
    (( ${#candidates} )) && compadd -a candidates
}
compdef @FUNCTION@ @PROGRAM@
"""

def _fish_completion_source() -> str:
    return """function @FUNCTION@
    set -l before (commandline -opc)
    if test (count $before) -lt 1
        return 0
    end
    set -e before[1]
    set -l raw (commandline -ct | string collect -a)
    set -l prefix "$raw"
    for suffix in '' '"' "'"
        set -l decoded (string unescape -- "$raw$suffix" | string collect -a)
        if set -q decoded[1]
            set prefix "$decoded"
            break
        end
    end
    env @QUERY@ @PROGRAM@ (count $before) $before "$prefix" | string split0
end
complete -c @PROGRAM@ -f -a '(@FUNCTION@)'
"""

def _finish(int64 code, bool standalone_mode) -> int64:
    if standalone_mode:
        sys.exit(code)
    return code

def _usage_failure(str message, str usage, bool standalone_mode) -> int64:
    if not standalone_mode:
        raise UsageError(message)
    io.write(sys.stderr_fd(), usage + "\nError: " + _escape_controls(message) + "\n")
    return _finish(2, standalone_mode)

def _escape_controls(str text, bool keep_newlines = False) -> str:
    str digits = "0123456789abcdef"
    list[str] pieces = []
    for character in text:
        int64 point = ord(character)
        if (point < 32 or point >= 127 and point <= 159) and not (point == 10 and keep_newlines):
            pieces.append("\\x" + str(digits[point // 16]) + str(digits[point % 16]))
        else:
            pieces.append(str(character))
    return "".join(pieces)

# Metadata is collected before the parser is constructed. Every outer decorator
# receives the declaration rather than another function value.
struct _Parameter:
    str name
    str kind
    str default_value = ""
    bool required = False
    str help = ""
    str envvar = ""
    list[str] choices = []
    Optional[int64] minimum = None
    Optional[int64] maximum = None
    Optional[fn(Namespace)] transform = None
    bool hidden = False
    str deprecation = ""
    str help_panel = ""

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
    list[str] choices = [],
    Optional[int64] min = None,
    Optional[int64] max = None,
    Optional[fn(T) -> T] callback = None,
) -> _Declaration:
    str type_name = reflect.type_info(T).name
    if name == "" or name.startswith("-"):
        raise UsageError("invalid positional name: " + name)
    if type_name != "int64" and type_name != "str":
        raise UsageError("unsupported positional type for " + name + ": " + type_name)
    _check_constraints(name, type_name, choices, min, max)
    auto parameter = _Parameter(
        name=name,
        kind=type_name,
        help=help,
        choices=choices,
        minimum=min,
        maximum=max,
        transform=_parameter_transform(name, kind, callback),
    )
    return _prepend(parameter, previous, handler)

# Declare a long option with a typed default, or mark a value option required.
# A bool option is a zero-arity flag that defaults to False. Hidden options
# still parse. Deprecated options accept True or a custom message.
# Set help_panel to place the option under a named heading in help.
def option[T, D](
    str name,
    Type[T] kind,
    Optional[_Declaration] previous = None,
    fn(Context, Namespace) handler = _missing_handler,
    Optional[T] default = None,
    bool required = False,
    str help = "",
    str envvar = "",
    list[str] choices = [],
    Optional[int64] min = None,
    Optional[int64] max = None,
    Optional[fn(T) -> T] callback = None,
    bool hidden = False,
    D deprecated = False,
    str help_panel = "",
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
    str deprecation = _option_deprecation(name, deprecated)
    if deprecation != "" and required:
        raise UsageError("deprecated option cannot be required: " + name)
    _check_constraints(name, type_name, choices, min, max)
    auto parameter = _Parameter(
        name=name,
        kind=type_name,
        default_value=default_value,
        required=required,
        help=help,
        envvar=envvar,
        choices=choices,
        minimum=min,
        maximum=max,
        transform=_parameter_transform(name, kind, callback),
        hidden=hidden,
        deprecation=deprecation,
        help_panel=help_panel,
    )
    return _prepend(parameter, previous, handler)

def _option_deprecation[D](str name, D deprecated) -> str:
    str message = "Option " + name + " is deprecated."
    if reflect.type_info(D).name == "bool":
        return message if deprecated else ""
    elif reflect.type_info(D).name == "str":
        return message + " " + deprecated if deprecated != "" else ""
    raise UsageError("deprecated requires bool or str for " + name)

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

def _apply_parameter_callback[T](str key, fn(T) -> T callback, Namespace values):
    if reflect.type_info(T).name == "str":
        values.set_str(key, callback(values.get_str(key)))
    elif reflect.type_info(T).name == "int64":
        values.set_int(key, callback(values.get_int(key)))
    elif reflect.type_info(T).name == "bool":
        values.set_flag(key, callback(values.get_flag(key)))

def _parameter_transform[T](
    str name,
    Type[T] kind,
    Optional[fn(T) -> T] callback,
) -> Optional[fn(Namespace)]:
    if callback.is_none():
        return None
    str key = _parameter_key(name)
    fn(T) -> T transform = callback.unwrap()
    fn(Namespace) apply = lambda values: _apply_parameter_callback[T](key, transform, values)
    return Optional.Some(apply)

def _check_constraints(
    str name,
    str kind,
    list[str] choices,
    Optional[int64] minimum,
    Optional[int64] maximum,
):
    if len(choices) > 0 and kind != "str":
        raise UsageError("choices require str for " + name)
    if (minimum.is_some() or maximum.is_some()) and kind != "int64":
        raise UsageError("bounds require int64 for " + name)
    if minimum.is_some() and maximum.is_some() and minimum.unwrap() > maximum.unwrap():
        raise UsageError("minimum exceeds maximum for " + name)
    dict[str, bool] seen = {}
    for choice in choices:
        if choice in seen:
            raise UsageError("duplicate choice for " + name + ": " + choice)
        seen[choice] = True

def _range_label(_Parameter parameter) -> str:
    if parameter.minimum.is_some():
        if parameter.maximum.is_some():
            return str(parameter.minimum.unwrap()) + ".." + str(parameter.maximum.unwrap())
        return ">= " + str(parameter.minimum.unwrap())
    return "<= " + str(parameter.maximum.unwrap())

def _validate_parameter(_Parameter parameter, Namespace values, bool has_environment):
    str name = parameter.name
    str key = _parameter_key(name)
    if len(parameter.choices) > 0 and values.get_str(key) not in parameter.choices:
        raise UsageError(name + " must be one of " + ", ".join(parameter.choices))
    if parameter.kind != "int64":
        return
    bool bounded = parameter.minimum.is_some() or parameter.maximum.is_some()
    bool from_environment = has_environment and not values.has(key)
    if not bounded and not from_environment:
        return
    int64 number = 0
    try:
        number = values.get_int(key)
    except ValueError:
        if not from_environment:
            raise
        raise UsageError(
            "environment variable " + parameter.envvar + " for " + name + " requires an integer",
        )
    if parameter.minimum.is_some() and number < parameter.minimum.unwrap() or parameter.maximum.is_some() and number > parameter.maximum.unwrap():
        raise UsageError(name + " is outside range " + _range_label(parameter))

def _check_help_width(int64 width):
    if width <= 0:
        raise ValueError("help width must be positive")

# Wrap at spaces, keeping an individual word intact even on a narrow display.
def _wrap_help(str text, str prefix, str indent, int64 width) -> list[str]:
    if len(prefix) + len(text) <= width:
        return [prefix + text]
    if len(indent) >= width:
        indent = ""
    list[str] lines = []
    str line = prefix
    bool has_word = False
    for word in text.split(" "):
        if word == "":
            continue
        str separator = " " if has_word else ""
        if len(line) + len(separator) + len(word) > width and line.strip() != "":
            lines.append(line.rstrip())
            line = indent + word
        else:
            line = line + separator + word
        has_word = True
    lines.append(line.rstrip())
    return lines

struct _Help:
    bool color
    int64 width
    list[str] lines = []

    def style(self, str text, str sgr) -> str:
        if self.color:
            return "\x1b[" + sgr + "m" + text + "\x1b[0m"
        return text

    def heading(self, str title):
        self.lines.append("")
        for line in _wrap_help(_escape_controls(title), "", "", self.width):
            self.lines.append(self.style(line, "1"))

    def row(self, str label, str description):
        str head = "  " + _escape_controls(label)
        str styled_head = "  " + self.style(head[2:], "36")
        if description == "":
            self.lines.append(styled_head)
            return
        list[str] paragraphs = description.split("\n")
        auto first = _wrap_help(paragraphs[0], head + "  ", "    ", self.width)
        self.lines.append(styled_head + first[0][len(head):])
        for line in first[1:]:
            self.lines.append(line)
        for paragraph in paragraphs[1:]:
            if paragraph == "":
                self.lines.append("")
            else:
                for line in _wrap_help(paragraph, "    ", "    ", self.width):
                    self.lines.append(line)

def _start_help(ArgumentParser parser, bool color, int64 width) -> _Help:
    auto help = _Help(color=color, width=width)
    str synopsis = _escape_controls(parser.format_usage())
    auto usage = _wrap_help(synopsis, "", "  ", width)
    str label = "usage:"
    help.lines.append(help.style(label, "1") + usage[0][len(label):])
    for line in usage[1:]:
        help.lines.append(line)
    if parser.description != "":
        help.lines.append("")
        for paragraph in _escape_controls(parser.description, keep_newlines=True).split("\n"):
            for line in _wrap_help(paragraph, "", "", width):
                help.lines.append(line)
    return help

def _help_option(_Help help):
    help.heading("options:")
    help.row("-h, --help", "show this help message and exit")

def _parameter_row(_Help help, _Parameter parameter):
    str label = parameter.name
    if label.startswith("--"):
        if parameter.kind != "bool":
            label = label + " " + _parameter_key(label)
    else:
        label = _parameter_key(label)
    help.row(label, _parameter_description(parameter))

def _command_help(
    ArgumentParser parser,
    list[_Parameter] parameters,
    bool color,
    int64 width,
) -> str:
    auto help = _start_help(parser, color, width)
    list[_Parameter] arguments = []
    list[_Parameter] options = []
    list[str] panel_order = []
    dict[str, list[_Parameter]] panels = {}
    for parameter in parameters:
        if parameter.hidden:
            continue
        if not parameter.name.startswith("--"):
            arguments.append(parameter)
        elif parameter.help_panel == "":
            options.append(parameter)
        else:
            str panel = parameter.help_panel
            if panel not in panels:
                panel_order.append(panel)
                panels[panel] = []
            panels[panel].append(parameter)
    if len(arguments) > 0:
        help.heading("positional arguments:")
        for parameter in arguments:
            _parameter_row(help, parameter)
    _help_option(help)
    for parameter in options:
        _parameter_row(help, parameter)
    for panel in panel_order:
        help.heading(panel + ":")
        for parameter in panels[panel]:
            _parameter_row(help, parameter)
    return "\n".join(help.lines)

def _parameter_description(_Parameter parameter) -> str:
    str help = _escape_controls(parameter.help, keep_newlines=True)
    if parameter.name.startswith("--") and parameter.required:
        help = (help + " " if help != "" else "") + "[required]"
    elif parameter.name.startswith("--"):
        str default_label = _escape_controls(parameter.default_value)
        if parameter.kind == "bool":
            default_label = "False"
        elif default_label == "":
            default_label = '""'
        if help != "":
            help = help + " "
        help = help + "[default: " + default_label + "]"
    if len(parameter.choices) > 0:
        help = (help + " " if help != "" else "") + "[choices: " + _escape_controls(", ".join(parameter.choices)) + "]"
    if parameter.minimum.is_some() or parameter.maximum.is_some():
        help = (help + " " if help != "" else "") + "[range: " + _range_label(parameter) + "]"
    if parameter.deprecation != "":
        help = (help + " " if help != "" else "") + "(deprecated)"
    return help

def _register_parameters(
    ArgumentParser parser,
    list[_Parameter] parameters,
    dict[str, str] environment = {},
):
    dict[str, bool] destinations = {}
    for parameter in parameters:
        str arg_name = parameter.name
        str key = _parameter_key(arg_name)
        if key == "<command>":
            raise UsageError("reserved parameter: " + key)
        if key in destinations:
            raise UsageError("duplicate parameter: " + key)
        destinations[key] = True
        bool has_environment = arg_name in environment
        str fallback = environment[arg_name] if has_environment else parameter.default_value
        if parameter.kind == "bool":
            bool enabled = fallback.strip().lower() in ["true", "1", "yes", "on", "t", "y"]
            str flag_default = "true" if enabled else "false"
            parser.add_argument(
                arg_name,
                action="store_true",
                default=flag_default,
                hidden=parameter.hidden,
            )
        else:
            str parser_type = "int" if parameter.kind == "int64" else "str"
            parser.add_argument(
                arg_name,
                type=parser_type,
                default=fallback,
                required=parameter.required and not has_environment,
                choices=parameter.choices,
                hidden=parameter.hidden,
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
