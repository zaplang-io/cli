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
