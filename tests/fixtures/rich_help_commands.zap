import cli

@cli.command(help="Prepare a release.\nA longer description follows.")
@cli.option("--jobs", int64, default=2, help="Parallel jobs.", help_panel="Execution")
@cli.option("--output", str, required=True, help="Output location.")
@cli.option("--legacy", bool, deprecated=True, help="Compatibility flag.", help_panel="Migration")
@cli.option("--dry-run", bool, help="Preview work.", help_panel="Execution")
@cli.option("--internal", bool, hidden=True, help_panel="Internal")
@cli.argument("source", str, help="Release source.")
def release(
    int64 jobs,
    str output,
    bool legacy,
    bool dry_run,
    bool internal,
    str source,
):
    print(str(jobs) + ":" + output + ":" + source)

def main():
    list[str] argv = sys.argv()[1:]
    if len(argv) > 0 and argv[0] == "group":
        auto app = cli.Group(name="tool")
        app.add(release)
        app.run(argv=argv[1:])
    else:
        release.run(argv=argv)
