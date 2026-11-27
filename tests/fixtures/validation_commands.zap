import cli

@cli.command(help="Render given constraints.")
@cli.option("--format", str, choices=["json", "text"], envvar="ZAP_CLI_VALIDATION_FORMAT", default="json")
@cli.option("--jobs", int64, min=1, max=64, envvar="ZAP_CLI_VALIDATION_JOBS", default=4)
@cli.argument("level", int64, max=3)
def render(str format, int64 jobs, int64 level):
    print(format + ":" + str(jobs) + ":" + str(level))

def main():
    list[str] argv = sys.argv()[1:]
    if len(argv) > 0 and argv[0] == "group":
        auto app = cli.Group(name="tool")
        app.add(render)
        app.run(argv=argv[1:])
    else:
        render.run(argv=argv)
