@test
def _completion_queries_resolve_command_option_values_and_cursor():
    dict[str, str] protocol = {"_COMPLETION_COMMANDS_COMPLETE": "bash_complete"}
    list[list[str]] cases = [
        ["0", "bu"],
        ["1", "build", "--re"],
        ["1", "build", "-"],
        ["2", "build", "--mode", "re"],
        ["1", "build", "--mode=re"],
        ["1", "build", "--mode=re", "--unknown"],
        ["2", "build", "--", "alpha "],
        ["1", "build", ""],
    ]
    list[str] results = [
        "build\x00bundle\x00",
        "--release\x00",
        "-h\x00--help\x00--release\x00--mode\x00",
        "release\x00",
        "--mode=release\x00",
        "--mode=release\x00",
        "alpha beta\x00alpha \"quoted\" $HOME;*\x00",
        "alpha beta\x00alpha \"quoted\" $HOME;*\x00",
    ]
    for i in range(len(cases)):
        auto code, out, err = process.run(
            ["./completion_commands", *cases[i]],
            env=protocol,
        )
        assert code == 0 and err == ""
        assert out == results[i]

@test
def _invalid_completion_requests_are_silent():
    dict[str, str] protocol = {"_COMPLETION_COMMANDS_COMPLETE": "fish_complete"}
    list[list[str]] bad = [
        [],
        ["oops", "build"],
        ["-1", "build"],
        ["1", "build"],
        ["1", "unknown", "--r"],
        ["2", "build", "--unknown", ""],
        ["2", "build", "--", "--re"],
    ]
    for args in bad:
        auto code, out, err = process.run(
            ["./completion_commands", *args],
            env=protocol,
        )
        assert code == 0 and out == "" and err == ""

@test
def _completion_rejects_malformed_value_prefixes_and_hides_private_choices():
    dict[str, str] protocol = {"_COMPLETION_COMMANDS_COMPLETE": "zsh_complete"}
    list[list[str]] suppressed = [
        ["3", "build", "--mode", "--release", "alpha"],
        ["3", "build", "--mode", "--unknown", "alpha"],
        ["3", "build", "--mode", "--", "alpha"],
        ["2", "build", "--restricted", ""],
        ["1", "build", "--restricted=in"],
        ["1", "build", "--restr=in"],
    ]
    for args in suppressed:
        auto code, out, err = process.run(
            ["./completion_commands", *args],
            env=protocol,
        )
        assert code == 0 and out == "" and err == ""

    auto code, out, err = process.run(
        ["./completion_commands", "2", "build", "--mode", ""],
        env=protocol,
    )
    assert code == 0 and out == "debug\x00release\x00" and err == ""

@test
def _generated_completion_scripts_run_in_all_supported_shells():
    for shell in ["bash", "zsh", "fish"]:
        auto code, out, err = process.run(
            ["python3", "./tests/fixtures/completion_shell_probe.py", shell],
        )
        if code != 0:
            print(out + err)
        assert code == 0
