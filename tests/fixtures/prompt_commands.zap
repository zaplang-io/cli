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
    elif mode == "hidden" or mode == "hidden-eof":
        assert cli.prompt("Secret", str, hide_input=True) == "secret-value"
        print("accepted")
    elif mode == "hidden-default":
        assert cli.prompt("Secret", str, default="private-default", hide_input=True) == "private-default"
        print("accepted")
    elif mode == "hidden-retry":
        assert cli.prompt("Secret", int64, hide_input=True) == 42
        print("accepted")
    elif mode == "hidden-pipe":
        bool rejected = False
        try:
            cli.prompt("Secret", str, hide_input=True)
        except OSError:
            rejected = True
        assert rejected
        assert input() == "still-available"
        print("pipe rejected")
    else:
        bool value = cli.prompt("Continue?", bool)
        print(value)

def main():
    ask.run()
