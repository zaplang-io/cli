import cli

@cli.command(help="Exercise the framework exit boundary.")
@cli.argument("mode", str)
@cli.option("--count", int64, default=1)
def exercise(str mode, int64 count):
    if mode == "usage":
        raise cli.UsageError("mode is invalid")
    if mode == "abort":
        raise cli.Abort()
    if mode == "zero":
        raise cli.Exit()
    if mode == "one":
        raise cli.Exit(1)
    if mode == "three":
        raise cli.Exit(code=3)
    if mode == "unrelated":
        raise ValueError("unexpected handler failure")
    print("ok:" + str(count))

def main():
    list[str] argv = sys.argv()[1:]
    if len(argv) > 0 and argv[0] == "group":
        auto app = cli.Group(name="tool")
        app.add(exercise)
        app.run(argv=argv[1:])
    else:
        exercise.run(argv=argv)
