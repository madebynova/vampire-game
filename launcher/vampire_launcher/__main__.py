import sys


def run() -> int:
    argv = sys.argv[1:]
    if argv and argv[0] != "--smoke":
        from .cli import main
        return main(argv)
    from .app import run_app
    return run_app(smoke="--smoke" in argv)


if __name__ == "__main__":
    sys.exit(run())
