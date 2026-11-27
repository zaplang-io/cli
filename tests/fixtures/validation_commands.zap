import cli

@cli.command(help="Render given constraints.")
@cli.option("--format", str, choices=["json", "text"], envvar="ZAP_CLI_VALIDATION_FORMAT", default="json")
@cli.option("--jobs", int64, min=1, max=64, envvar="ZAP_CLI_VALIDATION_JOBS", default=4)
@cli.argument("level", int64, max=3)
def render(str format, int64 jobs, int64 level):
    print(format + ":" + str(jobs) + ":" + str(level))

def _name(str value) -> str:
    print("callback: name")
    return value.upper()

def _jobs(int64 value) -> int64:
    print("callback: jobs")
    if value == 13:
        raise cli.UsageError("jobs cannot be thirteen")
    if value == 17:
        raise ValueError("callback broke")
    return value + 1

def _flag(bool value) -> bool:
    print("callback: flag")
    return not value

def _level(int64 value) -> int64:
    print("callback: level")
    return value - 1

@cli.command(help="Rewrite typed parameters.")
@cli.option("--name", str, default="default", envvar="ZAP_CLI_CALLBACK_NAME", callback=_name)
@cli.option("--jobs", int64, min=1, max=64, default=4, envvar="ZAP_CLI_CALLBACK_JOBS", callback=_jobs)
@cli.option("--flag", bool, envvar="ZAP_CLI_CALLBACK_FLAG", callback=_flag)
@cli.argument("level", int64, max=3, callback=_level)
def rewrite(int64 level, bool flag, int64 jobs, str name):
    print("handler: " + name + ":" + str(jobs) + ":" + str(flag) + ":" + str(level))

def main():
    list[str] argv = sys.argv()[1:]
    if len(argv) > 0 and argv[0] == "group":
        auto app = cli.Group(name="tool")
        app.add(render)
        app.add(rewrite)
        app.run(argv=argv[1:])
    elif len(argv) > 0 and argv[0] == "rewrite":
        rewrite.run(argv=argv[1:])
    else:
        render.run(argv=argv)
