import cli

@test
def _standalone_exit_codes_and_streams_match_for_direct_and_group_dispatch():
    list[list[str]] entries = [[], ["group", "exercise"]]
    for entry in entries:
        list[str] start = ["./error_commands", *entry]
        auto ok_code, ok_out, ok_err = process.run([*start, "success", "--count=4"])
        assert ok_code == 0 and ok_out == "ok:4\n" and ok_err == ""

        list[str] modes = ["zero", "one", "three", "abort"]
        list[int64] codes = [0, 1, 3, 1]
        for i in range(len(modes)):
            auto code, out, err = process.run([*start, modes[i]])
            assert code == codes[i] and out == ""
            assert err == ("Aborted.\n" if modes[i] == "abort" else "")

        auto usage_code, usage_out, usage_err = process.run([*start, "usage"])
        assert usage_code == 2 and usage_out == ""
        assert usage_err.find("Error: mode is invalid") >= 0
        if len(entry) == 0:
            assert usage_err.find("usage: exercise") >= 0
        else:
            assert usage_err.find("usage: tool exercise") >= 0

        auto help_code, help_out, help_err = process.run([*start, "--help"])
        assert help_code == 0 and help_err == ""
        assert help_out.find("Exercise the framework exit boundary.") >= 0
        assert help_out.find("ok:") < 0

@test
def _standalone_parse_failures_and_unrelated_handler_exceptions_keep_distinct_statuses():
    list[list[str]] invalid = [
        ["success", "--unknown"],
        ["success", "--count"],
        ["success", "--count=no"],
        ["group", "bogus"],
        ["group", "exercise", "success", "--unknown"],
        ["group", "exercise", "success", "--count"],
        ["group", "exercise", "success", "--count=no"],
    ]
    list[str] diagnostics = [
        "--unknown",
        "--count",
        "no",
        "unknown command: bogus",
        "--unknown",
        "--count",
        "no",
    ]
    for i in range(len(invalid)):
        auto code, out, err = process.run(["./error_commands", *invalid[i]])
        assert code == 2 and out == ""
        assert err.find("usage:") >= 0 and err.find("Error: ") >= 0
        assert err.find(diagnostics[i]) >= 0

    list[list[str]] entries = [[], ["group", "exercise"]]
    for entry in entries:
        auto code, out, err = process.run(["./error_commands", *entry, "unrelated"])
        assert code == 1 and out == ""
        assert err.find("unexpected handler failure") >= 0
        assert err.find("ValueError") >= 0
        assert err.find("usage:") < 0

def _embedded_exit(cli.Context ctx, Namespace ns):
    raise cli.Exit(code=3)

def _embedded_usage(cli.Context ctx, Namespace ns):
    raise cli.UsageError("handler usage")

def _embedded_abort(cli.Context ctx, Namespace ns):
    raise cli.Abort()

def _embedded_unrelated(cli.Context ctx, Namespace ns):
    raise ValueError("handler failure")

@test
def _embedded_dispatch_returns_exit_codes_and_preserves_other_exception_types():
    auto stopped = cli.command(name="stopped", handler=_embedded_exit)
    auto usage = cli.command(name="usage", handler=_embedded_usage)
    auto abort = cli.command(name="abort", handler=_embedded_abort)
    auto unrelated = cli.command(name="unrelated", handler=_embedded_unrelated)
    auto app = cli.Group(name="tool")
    app.add(stopped)
    app.add(usage)
    app.add(abort)
    app.add(unrelated)

    assert stopped.run(argv=[], standalone_mode=False) == 3
    assert app.run(argv=["stopped"], standalone_mode=False) == 3
    for grouped in [False, True]:
        bool caught_usage = False
        try:
            if grouped:
                app.run(argv=["usage"], standalone_mode=False)
            else:
                usage.run(argv=[], standalone_mode=False)
        except cli.UsageError as error:
            assert error == "handler usage"
            caught_usage = True
        assert caught_usage

        bool caught_abort = False
        try:
            if grouped:
                app.run(argv=["abort"], standalone_mode=False)
            else:
                abort.run(argv=[], standalone_mode=False)
        except cli.Abort:
            caught_abort = True
        assert caught_abort

        bool caught_unrelated = False
        try:
            if grouped:
                app.run(argv=["unrelated"], standalone_mode=False)
            else:
                unrelated.run(argv=[], standalone_mode=False)
        except ValueError as error:
            assert error == "handler failure"
            caught_unrelated = True
        assert caught_unrelated
