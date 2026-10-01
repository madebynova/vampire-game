"""The launcher's one decision: given what is installed and what is out there, what can the player do?

Kept free of any UI so it is trivial to test and so the window only has to render the answer.
"""
from __future__ import annotations

import json
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Optional

from . import versions


class State(Enum):
    NOT_INSTALLED = "not_installed"          # nothing on disk
    UP_TO_DATE = "up_to_date"                # installed version is the latest (or newer, e.g. a dev build)
    UPDATE_AVAILABLE = "update_available"    # a newer release exists
    UNKNOWN = "unknown"                      # installed, but the latest release could not be checked


def compute_state(installed: Optional[str], latest: Optional[str]) -> State:
    if installed is None:
        return State.NOT_INSTALLED
    if latest is None:
        return State.UNKNOWN
    return State.UPDATE_AVAILABLE if versions.compare(installed, latest) < 0 else State.UP_TO_DATE


@dataclass
class Settings:
    """The launcher's few user settings (launcher.json)."""
    install_root: Optional[str] = None       # None = the default folder
    allow_prerelease: bool = False


def load_settings(path: Path) -> Settings:
    try:
        d = json.loads(path.read_text(encoding="utf-8"))
        return Settings(install_root=d.get("install_root") or None,
                        allow_prerelease=bool(d.get("allow_prerelease", False)))
    except (OSError, ValueError, AttributeError):
        return Settings()


def save_settings(path: Path, s: Settings) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(json.dumps({"install_root": s.install_root, "allow_prerelease": s.allow_prerelease}, indent=2),
                   encoding="utf-8")
    tmp.replace(path)
