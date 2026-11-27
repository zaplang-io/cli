import cli

@test
def _group_dispatches_the_selected_command_and_scopes_child_options():
    auto build_code, build_out, build_err = process.run(["./group_commands", "build"])
    assert build_code == 0 and build_out == "build:False:2\n" and build_err == ""

    auto release_code, release_out, release_err = process.run(
        ["./group_commands", "build", "--release", "--jobs=8"],
    )
    assert release_code == 0 and release_out == "build:True:8\n" and release_err == ""

    auto test_code, test_out, test_err = process.run(
        ["./group_commands", "test", "./src"],
    )
    assert test_code == 0 and test_out == "test:./src\n" and test_err == ""

    auto literal_code, literal_out, literal_err = process.run(
        ["./group_commands", "test", "--", "--help"],
    )
    assert literal_code == 0 and literal_out == "test:--help\n" and literal_err == ""

@test
def _group_help_lists_subcommands_and_only_their_summaries():
    auto code, out, err = process.run(["./group_commands", "--help"])
    assert code == 0 and err == ""
    assert out.find("usage: tool") >= 0
    assert out.find("Project tooling.") >= 0
    assert out.find("build  Build the project.") >= 0
    assert out.find("test  Run the tests.") >= 0
    assert out.find("A more detailed build description.") < 0
    assert out.find("build:False:2") < 0 and out.find("test:") < 0

    auto short_code, short_out, short_err = process.run(["./group_commands", "-h"])
    assert short_code == 0 and short_out == out and short_err == ""

@test
def _command_help_uses_its_selected_path_and_declared_defaults():
    auto code, out, err = process.run(["./group_commands", "build", "--help"])
    assert code == 0 and err == ""
    assert out.find("usage: tool build") >= 0
    assert out.find("A more detailed build description.") >= 0
    assert out.find("--release") >= 0 and out.find("[default: False]") >= 0
    assert out.find("Number of jobs. [default: 2]") >= 0
    assert out.find("build:False:2") < 0

    auto short_code, short_out, short_err = process.run(
        ["./group_commands", "build", "-h"],
    )
    assert short_code == 0 and short_out == out and short_err == ""

    auto test_code, test_out, test_err = process.run(
        ["./group_commands", "test", "--help"],
    )
    assert test_code == 0 and test_err == ""
    assert test_out.find("usage: tool test") >= 0
    assert test_out.find("Path to test.") >= 0
    assert test_out.find("test:") < 0

    auto direct_code, direct_out, direct_err = process.run(
        ["./declared_commands", "--help"],
    )
    assert direct_code == 0 and direct_err == ""
    assert direct_out.find("usage: greet") >= 0
    assert direct_out.find("[default: 2]") >= 0
    assert direct_out.find("greet:greet") < 0

@test
def _group_usage_errors_exit_without_dispatching():
    list[list[str]] invalid = [
        [],
        ["bogus"],
        ["--release", "build"],
        ["test"],
        ["build", "--jobs=bad"],
    ]
    list[str] messages = [
        "missing command",
        "unknown command: bogus",
        "--release",
        "command",
        "bad",
    ]
    for i in range(len(invalid)):
        auto code, out, err = process.run(["./group_commands", *invalid[i]])
        assert code == 2 and out == ""
        assert err.find(messages[i]) >= 0
        if i < 2:
            assert err.find("Available commands: build, test") >= 0

@test
def _embedded_group_dispatch_is_repeatable_and_errors_remain_typed():
    list[str] calls = []
    fn(cli.Context, Namespace) record = lambda ctx, ns: calls.append(ctx.command_path[0] + ":" + ctx.command_name)
    auto app = cli.Group(name="first")
    app.add(cli.command(name="build", handler=record))
    app.add(cli.command(name="test", handler=record))
    auto other = cli.Group(name="other")
    other.add(cli.command(name="build", handler=record))
    for _ in range(96):
        assert app.run(argv=["build"], standalone_mode=False) == 0
        assert other.run(argv=["build"], standalone_mode=False) == 0
        assert app.run(argv=["test"], standalone_mode=False) == 0
    assert len(calls) == 288
    for i in range(96):
        assert calls[3 * i] == "first:build"
        assert calls[3 * i + 1] == "other:build"
        assert calls[3 * i + 2] == "first:test"

    bool caught_unknown = False
    try:
        app.run(argv=["other"], standalone_mode=False)
    except cli.UsageError as error:
        assert error == "unknown command: other. Available commands: build, test"
        caught_unknown = True
    assert caught_unknown

    bool caught_duplicate = False
    try:
        app.add(cli.command(name="build", handler=record))
    except cli.UsageError as error:
        assert error == "duplicate command: build"
        caught_duplicate = True
    assert caught_duplicate
    assert len(calls) == 288
