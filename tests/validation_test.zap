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
