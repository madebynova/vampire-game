"""Constants that define the release contract between the game's releases and the launcher.

Everything about "what does a release look like" lives here and in docs/RELEASING.md, so the
launcher and the packaging script (tools/package_release.ps1) cannot drift apart silently.
"""
import os
import re
import sys
from pathlib import Path

REPO = "madebynova/vampire-game"
API_BASE = os.environ.get("VAMPIRE_API_BASE", "https://api.github.com")

# Game releases are tagged v<MAJOR>.<MINOR>.<PATCH>. Launcher releases use "launcher-v..." and are
# ignored here, so the two can share one repository without confusing each other.
GAME_TAG_RE = re.compile(r"^v(\d+\.\d+\.\d+)$")

GAME_EXE = "VampireGame.exe"          # what the Godot export preset writes (export_presets.cfg)
VERSION_FILE = "VERSION"          # written into the package root by tools/package_release.ps1
GAME_PROCESS_NAMES = ("VampireGame.exe", "VampireGame.console.exe")


def package_name(version: str) -> str:
    return f"VampireGame-Windows-v{version}.zip"


def checksum_name(version: str) -> str:
    return package_name(version) + ".sha256"


def trusted_download_prefix(repo: str = REPO) -> str:
    """Packages are only ever downloaded from this repository's release assets."""
    return f"https://github.com/{repo}/releases/download/"


def default_home() -> Path:
    """Where the launcher keeps its own files and the installed game.

    Deliberately NOT the game's user-data folder (%APPDATA%\\VampireGame), which is
    where the game keeps settings and, later, saves. The launcher never reads or writes that folder.
    """
    override = os.environ.get("VAMPIRE_LAUNCHER_HOME")
    if override:
        return Path(override)
    base = os.environ.get("LOCALAPPDATA")
    return (Path(base) if base else Path.home() / ".local" / "share") / "VampireGame"


def _find_version_file() -> Path | None:
    here = Path(__file__).resolve().parent
    candidates = [here.parent / "VERSION"]                      # running from source: launcher/VERSION
    bundle = getattr(sys, "_MEIPASS", None)                    # PyInstaller one-file bundle
    if bundle:
        candidates.insert(0, Path(bundle) / "VERSION")
    for c in candidates:
        if c.is_file():
            return c
    return None


def launcher_version() -> str:
    """The launcher's own version. Single source of truth: launcher/VERSION."""
    f = _find_version_file()
    return f.read_text(encoding="utf-8").strip() if f else "0.0.0"
