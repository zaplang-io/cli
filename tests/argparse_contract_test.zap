# Exercise the core API that the CLI surface spec relies on. These tests run
# from the same consumer project as the package import test.

@test
def _core_parser_binds_values_and_resets_defaults():
    auto parser = argparse.ArgumentParser(prog="greet")
    parser.add_argument("--count", type="int", default="1")
    parser.add_argument("--shout", action="store_true")
    parser.add_argument("name")

    auto supplied = parser.parse_args(["--shout", "Ada", "--count=3"])
    assert supplied.get_int("count") == 3
    assert supplied.get_flag("shout")
    assert supplied.get_str("name") == "Ada"
    assert supplied.has("count")

    auto split = parser.parse_args(["--count", "-2", "Lin"])
    assert split.get_int("count") == -2
    assert not split.get_flag("shout")
    assert split.get_str("name") == "Lin"

    auto defaulted = parser.parse_args(["Grace"])
    assert defaulted.get_int("count") == 1
    assert not defaulted.has("count")
    assert not defaulted.has("shout")
    assert defaulted.get_str("name") == "Grace"
    assert supplied.get_int("count") == 3

@test
def _core_parser_selects_the_subcommand_and_signals_help():
    auto parser = argparse.ArgumentParser(prog="tool", description="Project tools")
    auto subcommands = parser.add_subparsers(dest="selected")
    auto build = subcommands.add_parser("build", help="Build summary")
    build.description = "Build the project"
    build.add_argument("target")
    auto check = subcommands.add_parser("check", help="Check the project")
    check.add_argument("--verbose", action="store_true")

    auto selected = parser.parse_args(["check", "--verbose"])
    assert selected.get_str("selected") == "check"
    assert selected.get_flag("verbose")
    assert not selected.help_requested()

    auto group_help = parser.parse_args(["--help"])
    assert group_help.help_requested()
    assert not group_help.has("selected")
    assert parser.format_help().find("Project tools") >= 0

    auto child_help = parser.parse_args(["build", "-h"])
    assert child_help.help_requested()
    assert child_help.get_str("selected") == "build"
    assert not child_help.has("target")
    assert build.format_help().find("Build the project") >= 0
    assert build.format_help().find("target") >= 0

@test
def _core_parser_rejects_structural_input_errors():
    auto parser = argparse.ArgumentParser()
    parser.add_argument("--name")
    parser.add_argument("path")

    bool unknown = False
    try:
        parser.parse_args(["--unknown", "src"])
    except Exception as error:
        unknown = error.find("--unknown") >= 0
    assert unknown

    bool missing_value = False
    try:
        parser.parse_args(["src", "--name"])
    except Exception as error:
        missing_value = error.find("--name") >= 0
    assert missing_value

    bool missing_positional = False
    try:
        parser.parse_args([])
    except Exception as error:
        missing_positional = error.find("path") >= 0
    assert missing_positional

    bool extra_positional = False
    try:
        parser.parse_args(["src", "extra"])
    except Exception as error:
        extra_positional = error.find("extra") >= 0
    assert extra_positional

@test
def _core_parser_rejects_invalid_integer_values():
    auto parser = argparse.ArgumentParser()
    parser.add_argument("--count", type="int")

    bool rejected = False
    try:
        parser.parse_args(["--count", "abc"])
    except ValueError:
        rejected = True
    assert rejected

@test
def _core_parser_rejects_an_unknown_subcommand():
    auto parser = argparse.ArgumentParser(prog="tool")
    auto subcommands = parser.add_subparsers()
    subcommands.add_parser("build")

    bool rejected = False
    try:
        parser.parse_args(["unknown"])
    except Exception as error:
        rejected = error.find("unknown") >= 0
    assert rejected

@test
def _core_parser_treats_tokens_after_the_separator_as_positional():
    auto parser = argparse.ArgumentParser()
    parser.add_argument("--name")
    parser.add_argument("first")
    parser.add_argument("second")
    parser.add_argument("third")

    auto ns = parser.parse_args(["--name", "label", "--", "--help", "-draft", "--"])
    assert ns.get_str("name") == "label"
    assert ns.get_str("first") == "--help"
    assert ns.get_str("second") == "-draft"
    assert ns.get_str("third") == "--"
    assert not ns.help_requested()

@test
def _core_parser_preserves_explicit_option_like_values():
    auto parser = argparse.ArgumentParser()
    parser.add_argument("--name")
    parser.add_argument("--verbose", action="store_true")

    auto explicit = parser.parse_args(["--name=--verbose"])
    assert explicit.get_str("name") == "--verbose"
    assert not explicit.get_flag("verbose")
    auto empty = parser.parse_args(["--name="])
    assert empty.has("name")
    assert empty.get_str("name") == ""
    auto stdin_value = parser.parse_args(["--name", "-"])
    assert stdin_value.get_str("name") == "-"

@test
def _core_parser_rejects_an_option_token_in_place_of_a_value():
    auto parser = argparse.ArgumentParser()
    parser.add_argument("--name")
    parser.add_argument("--verbose", action="store_true")

    for next_token in ["--verbose", "--unknown", "--"]:
        bool rejected = False
        try:
            parser.parse_args(["--name", next_token])
        except Exception as error:
            rejected = error.find("--name") >= 0 and error.find("expected one argument") >= 0
        assert rejected

@test
def _core_parser_rejects_attached_values_on_boolean_flags():
    auto parser = argparse.ArgumentParser()
    parser.add_argument("--verbose", action="store_true")

    for token in ["--verbose=false", "--verbose="]:
        bool rejected = False
        try:
            parser.parse_args([token])
        except Exception as error:
            rejected = error.find("--verbose") >= 0 and error.find("ignored explicit argument") >= 0
        assert rejected
