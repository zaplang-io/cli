import cli

def _validate(str value) -> str:
    print("unexpected callback")
    return value

@cli.command
@cli.option("--release", bool, deprecated=True)
@cli.option("--restricted", str, hidden=True, default="")
@cli.option("--mode", str, choices=["debug", "release"], default="debug", callback=_validate)
@cli.argument("target", str, choices=["alpha beta", "alpha \"quoted\" $HOME;*"])
def build(bool release, str restricted, str mode, str target):
    print("unexpected handler")

@cli.command
def bundle():
    print("unexpected handler")

def main():
    auto app = cli.Group(name="completion_commands")
    app.add(build)
    app.add(bundle)
    app.run()
