import cli

@test
def _progress_redraws_on_terminal_stderr_and_finishes_the_line():
    auto code, out, err = process.run(
        ["python3", "./tests/fixtures/progress_pty.py", "terminal"],
    )
    assert code == 0
    assert out == "4\n"
    assert err == "\rImporting [--------------------] 0/4\rImporting [##########----------] 2/4\rImporting [####################] 4/4\n"

@test
def _progress_redirects_to_one_plain_line_with_the_actual_count():
    auto code, out, err = process.run(["./progress_state", "partial"])
    assert code == 0 and out == "2\n"
    assert err == "Importing [##########----------] 2/4\n"

    auto full_code, full_out, full_err = process.run(["./progress_state", "terminal"])
    assert full_code == 0 and full_out == "4\n"
    assert full_err == "Importing [####################] 4/4\n"

    auto zero_code, zero_out, zero_err = process.run(["./progress_state", "zero"])
    assert zero_code == 0 and zero_out == "0\n"
    assert zero_err == "Importing [####################] 0/0\n"

@test
def _progress_closes_during_unwind_and_preserves_the_exception():
    auto code, out, err = process.run(
        ["python3", "./tests/fixtures/progress_pty.py", "unwind"],
    )
    assert code == 0 and out == "caught\n2\n"
    assert err == "\rImporting [--------------------] 0/4\rImporting [##########----------] 2/4\n"

    auto plain_code, plain_out, plain_err = process.run(["./progress_state", "unwind"])
    assert plain_code == 0 and plain_out == "caught\n2\n"
    assert plain_err == "Importing [##########----------] 2/4\n"

@test
def _invalid_totals_and_updates_raise_without_changing_progress():
    bool rejected_length = False
    try:
        cli.progressbar(length=-1)
    except ValueError as error:
        assert error == "progress length must be nonnegative"
        rejected_length = True
    assert rejected_length

    auto progress = cli.progressbar(length=4)
    with progress as bar:
        bar.update(2)
        for invalid in [-1, 3, 9223372036854775807]:
            bool rejected = False
            try:
                bar.update(invalid)
            except ValueError as error:
                assert error == "progress update is outside the remaining total"
                rejected = True
            assert rejected
            assert bar.completed == 2
        bar.update(2)
        bar.update(0)
        assert bar.completed == 4

    bool inactive = False
    try:
        progress.update(1)
    except ValueError as error:
        assert error == "progress bar is not active"
        inactive = True
    assert inactive

@test
def _progress_bars_keep_separate_counts_across_repeated_use():
    auto first = cli.progressbar(length=4)
    auto second = cli.progressbar(length=2)
    for _ in range(8):
        with first as one, second as two:
            one.update(1)
            two.update(2)
            assert one.completed == 1 and two.completed == 2
            one.update(3)
        assert first.completed == 4 and second.completed == 2
