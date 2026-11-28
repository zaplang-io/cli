@test
def _option_panels_keep_visible_options_in_declaration_order():
    list[list[str]] invocations = [
        ["./rich_help_commands"],
        ["./rich_help_commands", "group", "release"],
    ]
    for invocation in invocations:
        auto code, out, err = process.run([*invocation, "--help"])
        assert code == 0 and err == ""
        int64 default_panel = out.find("options:")
        int64 execution = out.find("Execution:")
        int64 migration = out.find("Migration:")
        assert out.find("positional arguments:") >= 0
        assert default_panel >= 0 and default_panel < execution and execution < migration
        assert out[default_panel:execution].find("--output") >= 0
        assert out[execution:migration].find("Parallel jobs. [default: 2]") >= 0
        assert out[execution:migration].find("Parallel jobs.") < out[execution:migration].find("Preview work.")
        assert out[migration:].find("Compatibility flag. [default: False] (deprecated)") >= 0
        assert out.find("--internal") < 0 and out.find("Internal:") < 0
        assert out.find("Prepare a release.\nA longer description follows.") >= 0
        assert out.find("\x1b") < 0

        auto run_code, run_out, run_err = process.run(
            [*invocation, "--jobs=3", "--output=target", "src"],
        )
        assert run_code == 0 and run_out == "3:target:src\n" and run_err == ""

@test
def _usage_diagnostics_escape_untrusted_terminal_controls():
    list[list[str]] invocations = [
        ["./rich_help_commands"],
        ["./rich_help_commands", "group", "release"],
    ]
    for invocation in invocations:
        auto code, out, err = process.run([*invocation, "--unknown\x1b[31m\nextra\t"])
        assert code == 2 and out == ""
        assert err.find("--unknown\\x1b[31m\\x0aextra\\x09") >= 0
        assert err.find("\x1b") < 0 and err.find("\textra") < 0

@test
def _help_wraps_without_losing_unicode_or_explicit_line_breaks():
    list[list[str]] invocations = [
        ["./rich_help_commands"],
        ["./rich_help_commands", "group", "release"],
    ]
    for invocation in invocations:
        auto narrow_code, narrow, narrow_err = process.run(
            [*invocation, "--help"],
            env={"ZAP_CLI_HELP_WIDTH": "26"},
        )
        assert narrow_code == 0 and narrow_err == ""
        for line in narrow.split("\n"):
            assert len(line) <= 26
        assert narrow.find("Café") >= 0 and narrow.find("résumé\\x09with details.") >= 0
        assert narrow.find("Second line\\x1b[31m.") >= 0 and narrow.find("\x1b") < 0
        assert narrow.find("jobs callback ran") < 0

        auto wide_code, wide, wide_err = process.run(
            [*invocation, "--help"],
            env={"ZAP_CLI_HELP_WIDTH": "160"},
        )
        assert wide_code == 0 and wide_err == ""
        assert wide.find("Prepare a release.\nA longer description follows.\nCafé résumé\\x09with details.") >= 0
        assert wide.find("Output location. [required]") >= 0
        assert wide.find("\n    Second line\\x1b[31m.") >= 0
        assert wide.find("jobs callback ran") < 0

@test
def _explicit_color_styles_help_and_usage_even_on_redirected_streams():
    auto plain_code, plain, plain_err = process.run(
        ["./rich_help_commands", "group", "--help"],
    )
    assert plain_code == 0 and plain_err == "" and plain.find("\x1b") < 0
    assert plain.find("usage: tool [-h] <command> ...") >= 0
    assert plain.find("release  Prepare a release.") >= 0
    assert plain.find("A longer description follows.") < 0

    dict[str, str] color = {"ZAP_CLI_HELP_COLOR": "1"}
    auto code, out, err = process.run(
        ["./rich_help_commands", "group", "--help"],
        env=color,
    )
    assert code == 0 and err == ""
    assert out.find("\x1b[1musage:\x1b[0m tool") >= 0
    assert out.find("\x1b[1mcommands:\x1b[0m") >= 0
    assert out.find("\x1b[36mrelease\x1b[0m  Prepare a release.") >= 0

    auto bad_code, bad_out, bad_err = process.run(
        ["./rich_help_commands", "--unknown"],
        env=color,
    )
    assert bad_code == 2 and bad_out == ""
    assert bad_err.find("\x1b[1mExecution:\x1b[0m") >= 0
    assert bad_err.find("\x1b[36m--jobs jobs\x1b[0m") >= 0
    assert bad_err.find("Error: unrecognized arguments: --unknown") >= 0
