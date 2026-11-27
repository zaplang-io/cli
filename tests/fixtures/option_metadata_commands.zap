import cli

def _validate_mode(str value) -> str:
    if value == "reject":
        raise cli.UsageError("mode rejected by callback")
    return value

@cli.command(help="Switch modes.")
@cli.option("--mode", str, default="current", deprecated=False, callback=_validate_mode)
@cli.option("--legacy-mode", str, default="fallback", deprecated="Use --mode instead.", envvar="ZAP_CLI_LEGACY_MODE", help="Old mode spelling")
@cli.option("--old-count", int64, default=2, deprecated=True, min=0)
@cli.option("--internal", bool, hidden=True, deprecated=True, help="Compatibility flag")
@cli.option("--secret-label", str, hidden=True, default="private default", help="Internal label")
@cli.option("--active", bool, deprecated="", help="Active flag")
def switch(
    str mode,
    str legacy_mode,
    int64 old_count,
    bool internal,
    str secret_label,
    bool active,
):
    print(
        mode + ":" + legacy_mode + ":" + str(old_count) + ":" + str(internal) + ":" + secret_label + ":" + str(active),
    )

def main():
    list[str] argv = sys.argv()[1:]
    if len(argv) > 0 and argv[0] == "group":
        auto app = cli.Group(name="tool")
        app.add(switch)
        app.run(argv=argv[1:])
    else:
        switch.run(argv=argv)
