@test
def _environment_options_follow_argv_envvar_default_precedence():
    list[list[str]] entries = [[], ["group", "configured"]]
    dict[str, str] environment = {
        "ZAP_CLI_ENV_ENDPOINT": "env-endpoint",
        "ZAP_CLI_ENV_JOBS": "7",
        "ZAP_CLI_ENV_LABEL": "env-label",
        "ZAP_CLI_ENV_PLAIN": "ignored",
    }
    for entry in entries:
        list[str] start = ["./env_commands", *entry]
        auto env_code, env_out, env_err = process.run(start, env=environment)
        assert env_err == ""
        assert env_code == 0
        assert env_out == "configured:env-endpoint:7:env-label:local\n"

        auto argv_code, argv_out, argv_err = process.run(
            [*start, "--jobs=9", "--label=", "--endpoint", "argv-endpoint"],
            env=environment,
        )
        assert argv_err == ""
        assert argv_code == 0
        assert argv_out == "configured:argv-endpoint:9::local\n"

        auto empty_code, empty_out, empty_err = process.run(
            [*start, "--endpoint="],
            env=environment,
        )
        assert empty_err == ""
        assert empty_code == 0
        assert empty_out == "configured::7:env-label:local\n"

@test
def _unset_and_empty_environment_variables_fall_back_to_declared_defaults():
    auto code, out, err = process.run(["./env_commands", "--endpoint=cli"])
    assert err == ""
    assert code == 0
    assert out == "configured:cli:2:standard:local\n"

    dict[str, str] empty = {
        "ZAP_CLI_ENV_ENDPOINT": "",
        "ZAP_CLI_ENV_JOBS": "",
        "ZAP_CLI_ENV_LABEL": "",
    }
    auto empty_code, empty_out, empty_err = process.run(
        ["./env_commands", "--endpoint=cli"],
        env=empty,
    )
    assert empty_err == ""
    assert empty_code == 0
    assert empty_out == out

    auto required_code, required_out, required_err = process.run(
        ["./env_commands"],
        env=empty,
    )
    assert required_code == 2 and required_out == ""
    assert required_err.find("--endpoint") >= 0

@test
def _invalid_environment_is_redacted_and_only_validated_when_selected():
    dict[str, str] environment = {
        "ZAP_CLI_ENV_ENDPOINT": "private-target",
        "ZAP_CLI_ENV_JOBS": "private-invalid-integer",
        "ZAP_CLI_ENV_LABEL": "private-label",
    }
    list[list[str]] entries = [[], ["group", "configured"]]
    for entry in entries:
        list[str] start = ["./env_commands", *entry]
        auto code, out, err = process.run(start, env=environment)
        assert code == 2 and out == ""
        assert err.find("environment variable ZAP_CLI_ENV_JOBS for --jobs requires an integer") >= 0
        assert err.find("private-") < 0

        auto override_code, override_out, override_err = process.run(
            [*start, "--jobs", "3"],
            env=environment,
        )
        assert override_err == ""
        assert override_code == 0
        assert override_out == "configured:private-target:3:private-label:local\n"

        auto help_code, help_out, help_err = process.run(
            [*start, "--help"],
            env=environment,
        )
        auto base_code, base_out, base_err = process.run([*start, "--help"])
        assert help_code == 0 and base_code == 0 and help_err == "" and base_err == ""
        assert help_out == base_out
        assert help_out.find("private-") < 0
        assert help_out.find("ZAP_CLI_ENV_JOBS") < 0

@test
def _embedded_invalid_environment_raises_usage_error():
    auto code, out, err = process.run(
        ["./env_commands", "embedded", "--endpoint=provided"],
        env={"ZAP_CLI_ENV_JOBS": "secret-invalid"},
    )
    assert err == ""
    assert code == 0
    assert out == "typed: environment variable ZAP_CLI_ENV_JOBS for --jobs requires an integer\n"

@test
def _boolean_environment_values_follow_click_activation_rules():
    list[list[str]] entries = [["toggle"], ["group", "toggle"]]
    for entry in entries:
        list[str] start = ["./env_commands", *entry]
        for value in ["true", "1", " YeS ", "ON", "t", "Y"]:
            auto code, out, err = process.run(start, env={"ZAP_CLI_ENV_VERBOSE": value})
            assert err == ""
            assert code == 0
            assert out == "verbose=True\n"
        for value in ["false", "0", " No ", "off", "f", "n", "", "unknown"]:
            auto code, out, err = process.run(start, env={"ZAP_CLI_ENV_VERBOSE": value})
            assert err == ""
            assert code == 0
            assert out == "verbose=False\n"

@test
def _explicit_boolean_switch_overrides_environment_and_help_stays_declarative():
    list[list[str]] entries = [["toggle"], ["group", "toggle"]]
    for entry in entries:
        list[str] start = ["./env_commands", *entry]
        auto code, out, err = process.run(
            [*start, "--verbose"],
            env={"ZAP_CLI_ENV_VERBOSE": "off"},
        )
        assert code == 0 and out == "verbose=True\n" and err == ""

        auto malformed_code, malformed_out, malformed_err = process.run(
            [*start, "--verbose=false"],
            env={"ZAP_CLI_ENV_VERBOSE": "on"},
        )
        assert malformed_code == 2 and malformed_out == ""
        assert malformed_err.find("--verbose") >= 0

        auto help_code, help_out, help_err = process.run(
            [*start, "--help"],
            env={"ZAP_CLI_ENV_VERBOSE": "on"},
        )
        assert help_err == ""
        assert help_code == 0
        assert help_out.find("Show details. [default: False]") >= 0
        assert help_out.find("ZAP_CLI_ENV_VERBOSE") < 0
        assert help_out.find("verbose=True") < 0
