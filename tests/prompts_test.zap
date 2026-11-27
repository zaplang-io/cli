@test
def _text_prompts_preserve_visible_input_and_use_a_default_on_empty_input():
    auto code, out, err = process.run(
        ["./prompt_commands", "text"],
        input="\n  café  \r\n",
    )
    assert err == ""
    assert code == 0
    assert out == "Target: Error: A response is required.\nTarget: target=  café  \n"

    auto default_code, default_out, default_err = process.run(
        ["./prompt_commands", "text-default"],
        input="\n",
    )
    assert default_err == ""
    assert default_code == 0
    assert default_out == "Target [staging]: target=staging\n"

@test
def _integer_prompt_retries_and_distinguishes_an_explicit_zero_default():
    auto code, out, err = process.run(
        ["./prompt_commands", "integer"],
        input="bad\n\n -12 \n",
    )
    assert err == ""
    assert code == 0
    assert out == "Retries: Error: Enter a valid integer.\nRetries: Error: A response is required.\nRetries: retries=-12\n"

    auto default_code, default_out, default_err = process.run(
        ["./prompt_commands", "integer-default"],
        input="\n",
    )
    assert default_err == ""
    assert default_code == 0
    assert default_out == "Retries [0]: retries=0\n"

@test
def _confirmation_retries_case_insensitively_and_accepts_both_defaults():
    auto code, out, err = process.run(
        ["./prompt_commands", "confirm"],
        input="maybe\n YES \n",
    )
    assert err == ""
    assert code == 0
    assert out == "Continue? [y/N]: Error: Enter yes or no.\nContinue? [y/N]: True\n"

    auto no_code, no_out, no_err = process.run(
        ["./prompt_commands", "confirm"],
        input="\n",
    )
    assert no_code == 0 and no_out == "Continue? [y/N]: False\n" and no_err == ""

    auto yes_code, yes_out, yes_err = process.run(
        ["./prompt_commands", "confirm-yes"],
        input="\n",
    )
    assert yes_code == 0 and yes_out == "Continue? [Y/n]: True\n" and yes_err == ""

    auto explicit_code, explicit_out, explicit_err = process.run(
        ["./prompt_commands", "confirm-yes"],
        input="nO\n",
    )
    assert explicit_code == 0 and explicit_out == "Continue? [Y/n]: False\n" and explicit_err == ""

@test
def _eof_and_declining_abort_use_the_typed_handler_boundary():
    auto code, out, err = process.run(["./prompt_commands", "text-default"])
    assert code == 1 and out == "Target [staging]: " and err == "Aborted.\n"

    auto retry_code, retry_out, retry_err = process.run(
        ["./prompt_commands", "integer"],
        input="bad\n",
    )
    assert retry_code == 1 and retry_err == "Aborted.\n"
    assert retry_out == "Retries: Error: Enter a valid integer.\nRetries: "

    auto confirm_code, confirm_out, confirm_err = process.run(
        ["./prompt_commands", "confirm"],
    )
    assert confirm_code == 1 and confirm_out == "Continue? [y/N]: " and confirm_err == "Aborted.\n"

    auto abort_code, abort_out, abort_err = process.run(
        ["./prompt_commands", "confirm-abort"],
        input="no\n",
    )
    assert abort_code == 1 and abort_out == "Continue? [y/N]: " and abort_err == "Aborted.\n"

@test
def _help_and_unsupported_prompt_types_do_not_read_input():
    auto help_code, help_out, help_err = process.run(["./prompt_commands", "--help"])
    assert help_code == 0 and help_err == ""
    assert help_out.find("usage: ask") >= 0 and help_out.find("Target:") < 0

    auto code, out, err = process.run(["./prompt_commands", "unsupported"], input="y\n")
    assert code == 2 and out == ""
    assert err.find("prompt supports str and int64") >= 0
