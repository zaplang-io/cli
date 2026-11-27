import cli

@cli.command(help="Build the project.\nA more detailed build description.")
@cli.option("--release", bool, help="Build with optimization.")
@cli.option("--jobs", int64, default=2, help="Number of jobs.")
def build(cli.Context ctx, int64 jobs, bool release):
    assert ctx.command_path == ["tool", "build"]
    print(ctx.command_name + ":" + str(release) + ":" + str(jobs))

@cli.command(name="test", help="Run the tests.")
@cli.argument("command", str, help="Path to test.")
def check(str command):
    print("test:" + command)

def main():
    auto app = cli.Group(name="tool", help="Project tooling.")
    app.add(build)
    app.add(check)
    app.run()
