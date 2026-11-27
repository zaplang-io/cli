import cli

@test
def _declared_command_binds_by_name_and_keeps_positional_declaration_order():
    auto code, out, err = process.run(
        [
            "./declared_commands",
            "--shout",
            "Ada",
            "--max-count=1",
            "--prefix",
            "hi",
            "7",
        ],
    )
    assert code == 0
    assert out == "greet:greet\nHI ADA:7\n"
    assert err == ""

    auto default_code, default_out, default_err = process.run(
        [
            "./declared_commands",
            "--prefix=hello",
            "--max-count",
            "2",
            "--",
            "-Ada",
            "-7",
        ],
    )
    assert default_code == 0
    assert default_out == "greet:greet\nhello -Ada:-7\nhello -Ada:-7\n"
    assert default_err == ""

@test
def _declared_command_supports_bare_and_context_free_handlers():
    auto quiet_code, quiet_out, quiet_err = process.run(
        ["./declared_commands", "quiet"],
    )
    assert quiet_code == 0
    assert quiet_out == ":3\n"
    assert quiet_err == ""

    auto bare_code, bare_out, bare_err = process.run(["./declared_commands", "bare"])
    assert bare_code == 0
    assert bare_out == "bare\n"
    assert bare_err == ""

@test
def _declared_command_rejects_invalid_input_without_entering_handler():
    list[list[str]] invalid = [
        ["--prefix=hi", "Ada", "7", "--nope"],
        ["--prefix=hi", "Ada", "7", "--max-count", "bad"],
        ["--prefix=hi", "Ada", "7", "--max-count"],
        ["--prefix=hi", "Ada", "7", "--shout=false"],
        ["--prefix=hi", "Ada"],
        ["--prefix=hi", "Ada", "7", "extra"],
        ["Ada", "7"],
    ]
    for argv in invalid:
        auto code, out, err = process.run(["./declared_commands", *argv])
        assert code == 2
        assert out == ""
        assert err.find("usage: greet") >= 0
        assert err.find("Error: ") >= 0

def _unused_handler(cli.Context ctx, Namespace ns):
    assert False

@test
def _declaration_rejects_duplicate_normalized_destinations():
    auto first = cli.option("--max-count", int64, handler=_unused_handler, default=3)
    auto second = cli.argument("max_count", int64, previous=first)
    bool caught = False
    try:
        cli.command(previous=second, name="duplicate")
    except cli.UsageError as error:
        assert error == "duplicate parameter: max_count"
        caught = True
    assert caught

@test
def _declaration_rejects_bad_metadata():
    bool reserved = False
    try:
        cli.option("--help", bool, handler=_unused_handler)
    except cli.UsageError as error:
        assert error == "invalid long option name: --help"
        reserved = True
    assert reserved

    bool missing_default = False
    try:
        cli.option("--count", int64, handler=_unused_handler)
    except cli.UsageError as error:
        assert error == "provide a default or required=True for --count"
        missing_default = True
    assert missing_default

    bool non_flag = False
    try:
        cli.option("--flag", bool, handler=_unused_handler, default=True)
    except cli.UsageError as error:
        assert error == "boolean flag requires a False default: --flag"
        non_flag = True
    assert non_flag
