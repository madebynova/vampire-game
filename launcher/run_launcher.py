"""Entry point used by PyInstaller (and handy for `python launcher/run_launcher.py`)."""
import sys

from vampire_launcher.__main__ import run

if __name__ == "__main__":
    sys.exit(run())
