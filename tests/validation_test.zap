import cli

@test
def _constraints_accept_inclusive_limits_and_match_string_case():
    list[list[str]] entries = [[], ["group", "render"]]
    for entry in entries:
        list[str] start = ["./validation_commands", *entry]
        list[list[str]] valid = [
            ["--jobs=1", "--format=text", "3"],
            ["--jobs=64", "-7"],
            ["0"],
        ]
        list[str] expected = ["text:1:3\n", "json:64:-7\n", "json:4:0\n"]
        for i in range(len(valid)):
            auto code, out, err = process.run([*start, *valid[i]])
            assert err == ""
            assert code == 0 and out == expected[i]

        list[list[str]] invalid = [
            ["--format=JSON", "0"],
            ["--jobs=0", "0"],
            ["--jobs=65", "0"],
            ["4"],
        ]
        list[str] messages = [
            "invalid choice",
            "--jobs is outside range 1..64",
            "--jobs is outside range 1..64",
            "level is outside range <= 3",
        ]
        for i in range(len(invalid)):
            auto code, out, err = process.run([*start, *invalid[i]])
            assert code == 2 and out == ""
            assert err.find(messages[i]) >= 0

@test
def _constraint_help_displays_ranges_and_choices_without_running_the_handler():
    list[list[str]] entries = [[], ["group", "render"]]
    for entry in entries:
        auto code, out, err = process.run(["./validation_commands", *entry, "--help"])
        assert err == ""
        assert code == 0 and out.find("[range: 1..64]") >= 0
        assert out.find("[choices: json, text]") >= 0
        assert out.find("[range: <= 3]") >= 0
        assert out.find("json:4:0") < 0

def _no_dispatch(cli.Context ctx, Namespace ns):
    assert False

@test
def _invalid_constraint_declarations_raise_typed_usage_errors():
    bool invalid_type = False
    try:
        cli.option("--jobs", int64, choices=["one"], default=1, handler=_no_dispatch)
    except cli.UsageError as error:
        assert error == "choices require str for --jobs"
        invalid_type = True
    assert invalid_type

    bool invalid_range = False
    try:
        cli.argument("count", int64, min=7, max=3, handler=_no_dispatch)
    except cli.UsageError as error:
        assert error == "minimum exceeds maximum for count"
        invalid_range = True
    assert invalid_range

    bool duplicate_choice = False
    try:
        cli.argument("format", str, choices=["json", "json"], handler=_no_dispatch)
    except cli.UsageError as error:
        assert error == "duplicate choice for format: json"
        duplicate_choice = True
    assert duplicate_choice

    bool invalid_bound_type = False
    try:
        cli.option("--label", str, min=0, default="", handler=_no_dispatch)
    except cli.UsageError as error:
        assert error == "bounds require int64 for --label"
        invalid_bound_type = True
    assert invalid_bound_type

@test
def _selected_environment_values_obey_the_same_constraints_without_disclosure():
    list[list[str]] entries = [[], ["group", "render"]]
    for entry in entries:
        list[str] start = ["./validation_commands", *entry]
        dict[str, str] happy = {
            "ZAP_CLI_VALIDATION_FORMAT": "text",
            "ZAP_CLI_VALIDATION_JOBS": "64",
        }
        auto ok_code, ok_out, ok_err = process.run([*start, "3"], env=happy)
        assert ok_err == ""
        assert ok_code == 0 and ok_out == "text:64:3\n"

        dict[str, str] bad = {
            "ZAP_CLI_VALIDATION_FORMAT": "private-choice",
            "ZAP_CLI_VALIDATION_JOBS": "99993",
        }
        auto choice_code, choice_out, choice_err = process.run([*start, "3"], env=bad)
        assert choice_code == 2 and choice_out == ""
        assert choice_err.find("--format must be one of json, text") >= 0
        assert choice_err.find("private-choice") < 0

        auto bound_code, bound_out, bound_err = process.run(
            [*start, "--format=text", "3"],
            env=bad,
        )
        assert bound_code == 2 and bound_out == ""
        assert bound_err.find("--jobs is outside range 1..64") >= 0
        assert bound_err.find("99993") < 0

        auto override_code, override_out, override_err = process.run(
            [*start, "--format=text", "--jobs=1", "3"],
            env=bad,
        )
        assert override_err == ""
        assert override_code == 0 and override_out == "text:1:3\n"

@test
def _declared_defaults_obey_constraints_in_direct_and_group_dispatch():
    auto choice = cli.option(
        "--format",
        str,
        choices=["json"],
        default="text",
        handler=_no_dispatch,
    )
    auto bounds = cli.option("--jobs", int64, min=1, default=0, handler=_no_dispatch)
    auto format = cli.command(name="format", previous=choice)
    auto jobs = cli.command(name="jobs", previous=bounds)
    auto app = cli.Group(name="tool")
    app.add(format)
    app.add(jobs)
    for grouped in [False, True]:
        bool caught_choice = False
        try:
            if grouped:
                app.run(argv=["format"], standalone_mode=False)
            else:
                format.run(argv=[], standalone_mode=False)
        except cli.UsageError as error:
            assert error == "--format must be one of json"
            caught_choice = True
        assert caught_choice

        bool caught_bounds = False
        try:
            if grouped:
                app.run(argv=["jobs"], standalone_mode=False)
            else:
                jobs.run(argv=[], standalone_mode=False)
        except cli.UsageError as error:
            assert error == "--jobs is outside range >= 1"
            caught_bounds = True
        assert caught_bounds
