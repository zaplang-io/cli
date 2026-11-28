import cli

def _check_jobs(int64 value) -> int64:
    if value == 2:
        print("jobs callback ran")
    return value

@cli.command(help="Prepare a release.\nA longer description follows.\nCafé résumé\twith details.")
@cli.option("--jobs", int64, default=2, help="Parallel jobs.", help_panel="Execution", callback=_check_jobs)
@cli.option("--output", str, required=True, help="Output location.")
@cli.option("--legacy", bool, deprecated=True, help="Compatibility flag.", help_panel="Migration")
@cli.option("--dry-run", bool, help="Preview work.", help_panel="Execution")
@cli.option("--internal", bool, hidden=True, help_panel="Internal")
@cli.argument("source", str, help="Release source.\nSecond line\x1b[31m.")
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
    str width_setting = os.getenv("ZAP_CLI_HELP_WIDTH")
    int64 width = int(width_setting) if width_setting != "" else 80
    bool color = os.getenv("ZAP_CLI_HELP_COLOR") == "1"
    if len(argv) > 0 and argv[0] == "group":
        auto app = cli.Group(name="tool", help="Project tools.\nGroup detail.")
        app.add(release)
        app.run(argv=argv[1:], color=color, width=width)
    else:
        release.run(argv=argv, color=color, width=width)
