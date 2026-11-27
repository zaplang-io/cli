import cli

@test
def _hidden_options_bind_but_stay_out_of_help_and_usage():
    list[list[str]] entries = [
        ["./option_metadata_commands"],
        ["./option_metadata_commands", "group", "switch"],
    ]
    for start in entries:
        auto code, out, err = process.run(
            [*start, "--internal", "--secret-label=chosen"],
        )
        assert code == 0 and out == "current:fallback:2:True:chosen:False\n"
        assert err == "Warning: Option --internal is deprecated.\n"

        auto help_code, help_out, help_err = process.run(
            [*start, "--internal", "--help"],
        )
        assert help_code == 0 and help_err == ""
        for hidden_text in ["--internal", "--secret-label", "Internal label", "Compatibility flag", "private default"]:
            assert help_out.find(hidden_text) < 0
        assert help_out.find("Old mode spelling [default: fallback] (deprecated)") >= 0
        assert help_out.find("[range: >= 0] (deprecated)") >= 0
        assert help_out.find("Active flag [default: False] (deprecated)") < 0
        assert help_out.find("Use --mode instead.") < 0

        auto bad_code, bad_out, bad_err = process.run(
            [*start, "--internal", "--unknown"],
        )
        assert bad_code == 2 and bad_out == ""
        assert bad_err.find("--unknown") >= 0
        assert bad_err.find("--internal") < 0 and bad_err.find("--secret-label") < 0
        assert bad_err.find("Warning:") < 0

@test
def _deprecated_options_warn_once_per_explicit_option_in_declaration_order():
    list[list[str]] entries = [
        ["./option_metadata_commands"],
        ["./option_metadata_commands", "group", "switch"],
    ]
    for start in entries:
        dict[str, str] environment = {"ZAP_CLI_LEGACY_MODE": "environment"}
        auto default_code, default_out, default_err = process.run(start)
        assert default_code == 0 and default_out == "current:fallback:2:False:private default:False\n"
        assert default_err == ""
        auto env_code, env_out, env_err = process.run(start, env=environment)
        assert env_code == 0 and env_out == "current:environment:2:False:private default:False\n"
        assert env_err == ""
        auto code, out, err = process.run(
            [
                *start,
                "--internal",
                "--old-count=2",
                "--legacy-mode=first",
                "--legacy-mode=",
                "--active",
                "--mode=next",
            ],
            env=environment,
        )
        assert code == 0 and out == "next::2:True:private default:True\n"
        assert err == "Warning: Option --legacy-mode is deprecated. Use --mode instead.\nWarning: Option --old-count is deprecated.\nWarning: Option --internal is deprecated.\n"

@test
def _invalid_invocations_do_not_emit_deprecation_warnings():
    list[list[str]] entries = [
        ["./option_metadata_commands"],
        ["./option_metadata_commands", "group", "switch"],
    ]
    for entry in entries:
        list[str] start = [*entry, "--legacy-mode=old"]
        list[str] invalid = [
            "--internal=true",
            "--secret-label",
            "--old-count=wrong",
            "--old-count=-1",
            "--mode=reject",
        ]
        list[str] messages = [
            "--internal",
            "--secret-label",
            "--old-count",
            "outside range",
            "mode rejected by callback",
        ]
        for i in range(len(invalid)):
            auto code, out, err = process.run([*start, invalid[i]])
            assert code == 2 and out == ""
            assert err.find(messages[i]) >= 0 and err.find("Warning:") < 0

@test
def _invalid_deprecation_metadata_raises_usage_error():
    bool required = False
    try:
        cli.option("--old", str, required=True, deprecated=True)
    except cli.UsageError as error:
        assert error == "deprecated option cannot be required: --old"
        required = True
    assert required

    bool wrong_type = False
    try:
        cli.option("--old", str, default="", deprecated=42)
    except cli.UsageError as error:
        assert error == "deprecated requires bool or str for --old"
        wrong_type = True
    assert wrong_type
