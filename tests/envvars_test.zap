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
        assert env_code == 0 and env_err == ""
        assert env_out == "configured:env-endpoint:7:env-label:local\n"

        auto argv_code, argv_out, argv_err = process.run(
            [*start, "--jobs=9", "--label=", "--endpoint", "argv-endpoint"],
            env=environment,
        )
        assert argv_code == 0 and argv_err == ""
        assert argv_out == "configured:argv-endpoint:9::local\n"

        auto empty_code, empty_out, empty_err = process.run(
            [*start, "--endpoint="],
            env=environment,
        )
        assert empty_code == 0 and empty_err == ""
        assert empty_out == "configured::7:env-label:local\n"

@test
def _unset_and_empty_environment_variables_fall_back_to_declared_defaults():
    auto code, out, err = process.run(["./env_commands", "--endpoint=cli"])
    assert code == 0 and err == ""
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
    assert empty_code == 0 and empty_err == ""
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
        assert override_code == 0 and override_err == ""
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
    assert code == 0 and err == ""
    assert out == "typed: environment variable ZAP_CLI_ENV_JOBS for --jobs requires an integer\n"
