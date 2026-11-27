import cli

@cli.command
@cli.argument("mode", str)
def exercise(str mode):
    int64 total = 0 if mode == "zero" else 4
    auto progress = cli.progressbar(length=total, label="Importing")
    try:
        with progress as bar:
            if total > 0:
                bar.update(2)
                bar.update(0)
                if mode == "unwind":
                    raise ValueError("render interrupted")
                if mode != "partial":
                    bar.update(2)
    except ValueError as error:
        assert error == "render interrupted"
        print("caught")
    progress.__exit__()
    print(progress.completed)

def main():
    exercise.run()
