import cli

@cli.command(help="Greet people.")
@cli.option("--max-count", int64, default=2, help="How many times.")
@cli.option("--shout", bool, default=False)
@cli.option("--prefix", str, required=True)
@cli.argument("first", str)
@cli.argument("last", int64)
def greet(
    cli.Context ctx,
    int64 last,
    bool shout,
    str first,
    int64 max_count,
    str prefix,
):
    print(ctx.command_name + ":" + ctx.command_path[0])
    str message = prefix + " " + first + ":" + str(last)
    if shout:
        message = message.upper()
    for _ in range(max_count):
        print(message)

@cli.command(name="quiet")
@cli.option("--label", str, default="")
@cli.option("--count", int64, default=3)
def no_context(int64 count, str label):
    print(label + ":" + str(count))

@cli.command
def bare():
    print("bare")

def main():
    list[str] argv = sys.argv()[1:]
    if len(argv) > 0 and argv[0] == "quiet":
        assert no_context.name == "quiet"
        no_context.run(argv=argv[1:])
    elif len(argv) > 0 and argv[0] == "bare":
        assert bare.name == "bare"
        bare.run(argv=argv[1:])
    else:
        assert greet.name == "greet"
        greet.run()
