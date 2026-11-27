import cli

@cli.command
@cli.option("--endpoint", str, envvar="ZAP_CLI_ENV_ENDPOINT", required=True)
@cli.option("--jobs", int64, envvar="ZAP_CLI_ENV_JOBS", default=2)
@cli.option("--label", str, envvar="ZAP_CLI_ENV_LABEL", default="standard")
@cli.option("--plain", str, default="local")
def configured(cli.Context ctx, str endpoint, int64 jobs, str label, str plain):
    print(
        ctx.command_name + ":" + endpoint + ":" + str(jobs) + ":" + label + ":" + plain,
    )

@cli.command
@cli.option("--verbose", bool, envvar="ZAP_CLI_ENV_VERBOSE", help="Show details.")
def toggle(bool verbose):
    print("verbose=" + str(verbose))

def main():
    list[str] argv = sys.argv()[1:]
    if len(argv) > 0 and argv[0] == "group":
        auto app = cli.Group(name="tool")
        app.add(configured)
        app.add(toggle)
        app.run(argv=argv[1:])
    elif len(argv) > 0 and argv[0] == "toggle":
        toggle.run(argv=argv[1:])
    elif len(argv) > 0 and argv[0] == "embedded":
        bool caught = False
        try:
            configured.run(argv=argv[1:], standalone_mode=False)
        except cli.UsageError as error:
            print("typed: " + error)
            caught = True
        assert caught
    else:
        configured.run(argv=argv)
