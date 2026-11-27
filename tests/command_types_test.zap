import cli

@test
def _context_exposes_the_selected_name_and_full_path():
    auto single = cli.Context(command_name="greet", command_path=["greet"])
    assert single.command_name == "greet"
    assert single.command_path == ["greet"]

    auto child = cli.Context(command_name="build", command_path=["tool", "build"])
    assert child.command_name == "build"
    assert child.command_path == ["tool", "build"]
    assert single.command_path == ["greet"]

@test
def _usage_error_is_catchable_with_the_original_message():
    for diagnostic in ["missing value for --count", "unknown option: --☃", ""]:
        bool caught = False
        try:
            raise cli.UsageError(diagnostic)
        except cli.UsageError as error:
            assert error == diagnostic
            caught = True
        assert caught

@test
def _usage_error_catch_leaves_unrelated_exceptions_untouched():
    bool caught_unrelated = False
    try:
        raise ValueError("handler failed")
    except cli.UsageError:
        assert False
    except ValueError as error:
        assert error == "handler failed"
        caught_unrelated = True
    assert caught_unrelated
