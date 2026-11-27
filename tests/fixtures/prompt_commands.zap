import cli

@cli.command
@cli.argument("mode", str)
def ask(str mode):
    if mode == "text":
        str value = cli.prompt("Target", str)
        print("target=" + value)
    elif mode == "text-default":
        str value = cli.prompt("Target", str, default="staging")
        print("target=" + value)
    elif mode == "integer":
        int64 count = cli.prompt("Retries", int64)
        print("retries=" + str(count))
    elif mode == "integer-default":
        int64 count = cli.prompt("Retries", int64, default=0)
        print("retries=" + str(count))
    elif mode == "confirm":
        print(cli.confirm("Continue?"))
    elif mode == "confirm-yes":
        print(cli.confirm("Continue?", default=True))
    elif mode == "confirm-abort":
        print(cli.confirm("Continue?", abort=True))
    else:
        bool value = cli.prompt("Continue?", bool)
        print(value)

def main():
    ask.run()
