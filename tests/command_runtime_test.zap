import cli

# The configured Command is the runtime seam used by the declaration factories.
@test
def _command_repeatedly_dispatches_split_inline_and_default_values():
    auto parser = argparse.ArgumentParser(prog="greet")
    parser.add_argument("--count", type="int", default="1")
    parser.add_argument("--shout", action="store_true")
    parser.add_argument("--prefix", default="hello")
    parser.add_argument("name")

    list[str] calls = []
    fn(cli.Context, Namespace) record = lambda ctx, ns: _record_call(calls, ctx, ns)

    auto cmd = cli.Command(name="greet", _parser=parser, _handler=record)
    for _ in range(128):
        assert cmd.run(argv=["--count", "3", "Ada", "--shout", "--prefix=hi"], standalone_mode=False) == 0
        assert cmd.run(argv=["--count=2", "--prefix", "hey", "Bo"], standalone_mode=False) == 0
        assert cmd.run(argv=["Lin"], standalone_mode=False) == 0
    assert len(calls) == 384
    for i in range(128):
        assert calls[3 * i] == "hi:Ada:3:True"
        assert calls[3 * i + 1] == "hey:Bo:2:False"
        assert calls[3 * i + 2] == "hello:Lin:1:False"

@test
def _command_accepts_explicit_empty_argv_with_only_defaults():
    auto parser = argparse.ArgumentParser(prog="count")
    parser.add_argument("--count", type="int", default="7")
    list[int64] counts = []
    fn(cli.Context, Namespace) record = lambda ctx, ns: counts.append(ns.get_int("count"))

    auto cmd = cli.Command(name="count", _parser=parser, _handler=record)
    assert cmd.run(argv=[], standalone_mode=False) == 0
    assert counts == [7]

@test
def _command_reports_bad_argv_without_invoking_the_handler():
    auto parser = argparse.ArgumentParser(prog="build")
    parser.add_argument("--count", type="int", default="1")
    parser.add_argument("--shout", action="store_true")
    parser.add_argument("path")

    auto cmd = cli.Command(name="build", _parser=parser, _handler=_unexpected_handler)
    list[list[str]] invalid = [
        ["--unknown", "src"],
        ["src", "--count", "bad"],
        ["src", "--count"],
        ["src", "--count", "--shout"],
        ["src", "--shout=false"],
        [],
        ["src", "extra"],
    ]
    list[str] fragments = [
        "--unknown",
        "bad",
        "--count",
        "--count",
        "--shout",
        "path",
        "extra",
    ]
    for i in range(len(invalid)):
        bool caught = False
        try:
            cmd.run(argv=invalid[i], standalone_mode=False)
        except cli.UsageError as error:
            assert error.find(fragments[i]) >= 0
            caught = True
        assert caught
    assert cmd.run(argv=["--help"], standalone_mode=False) == 0

@test
def _command_does_not_reclassify_handler_exceptions():
    auto parser = argparse.ArgumentParser(prog="broken")

    auto cmd = cli.Command(name="broken", _parser=parser, _handler=_broken_handler)
    bool caught = False
    try:
        cmd.run(argv=[], standalone_mode=False)
    except cli.UsageError:
        assert False
    except ValueError as error:
        assert error == "handler failed"
        caught = True
    assert caught

def _record_call(list[str] calls, cli.Context ctx, Namespace ns):
    assert ctx.command_name == "greet"
    assert ctx.command_path == ["greet"]
    calls.append(
        ns.get_str("prefix") + ":" + ns.get_str("name") + ":" + str(ns.get_int("count")) + ":" + str(ns.get_flag("shout")),
    )

def _unexpected_handler(cli.Context ctx, Namespace ns):
    assert False

def _broken_handler(cli.Context ctx, Namespace ns):
    raise ValueError("handler failed")

@test
def _command_binds_typed_positionals_and_preserves_literal_help_after_separator():
    auto parser = argparse.ArgumentParser(prog="copy")
    parser.add_argument("count", type="int")
    parser.add_argument("path")

    list[str] calls = []
    fn(cli.Context, Namespace) record = lambda ctx, ns: calls.append(ctx.command_name + ":" + str(ns.get_int("count")) + ":" + ns.get_str("path"))
    auto cmd = cli.Command(name="copy", _parser=parser, _handler=record)
    assert cmd.run(argv=["-h"], standalone_mode=False) == 0
    assert len(calls) == 0
    assert cmd.run(argv=["-2", "--", "--help"], standalone_mode=False) == 0
    assert cmd.run(argv=["0", "--", "-draft"], standalone_mode=False) == 0
    assert calls == ["copy:-2:--help", "copy:0:-draft"]

    bool caught = False
    try:
        cmd.run(argv=["not-an-integer", "file"], standalone_mode=False)
    except cli.UsageError as error:
        assert error.find("not-an-integer") >= 0
        caught = True
    assert caught
    assert len(calls) == 2
