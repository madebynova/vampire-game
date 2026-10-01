"""Command-line front-end: handy for testing and for support ("run `status` and paste the output")."""
from __future__ import annotations

import argparse
import sys

from . import config, state
from .core import Launcher
from .install import InstallError
from .releases import ReleaseError


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(prog="vampire_launcher", description="Vampire Game launcher (command line)")
    p.add_argument("command", choices=["status", "check", "install", "play"])
    p.add_argument("--home", help="launcher folder (default: %%LOCALAPPDATA%%\\VampireGame)")
    p.add_argument("--api-base", help="GitHub API base URL (testing)")
    a = p.parse_args(argv)

    launcher = Launcher(a.home, api_base=a.api_base)
    try:
        if a.command in ("check", "install", "status"):
            try:
                launcher.check_for_updates()
            except ReleaseError as e:
                if a.command == "install":
                    raise
                print(f"(could not check for updates: {e})")
        if a.command == "play":
            launcher.play()
            return 0
        if a.command == "install":
            def progress(stage, done, total):
                pct = f" {done * 100 // total}%" if total else ""
                print(f"\r{stage}{pct}      ", end="", flush=True)
            version = launcher.install_latest(progress=progress)
            print(f"\nInstalled version {version}.")
            return 0
    except (ReleaseError, InstallError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    inst = launcher.installed_version()
    latest = launcher.latest_release.version if launcher.latest_release else None
    print(f"Launcher {config.launcher_version()}")
    print(f"Install location : {launcher.paths.root}")
    print(f"Installed version: {inst or 'not installed'}")
    print(f"Latest version   : {latest or 'unknown'}")
    print(f"State            : {launcher.state().value}")
    return 0
