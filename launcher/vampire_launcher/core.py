"""Facade used by both the window (app.py) and the command line (cli.py)."""
from __future__ import annotations

import subprocess
import sys
import urllib.request
from pathlib import Path
from typing import Optional

from . import config, install, releases, state
from .install import InstallError, Paths
from .releases import Release, ReleaseError


class Launcher:
    def __init__(self, home: Path | None = None, *, opener=urllib.request.urlopen, api_base: str | None = None,
                 repo: str = config.REPO, trusted_prefix: str | None = None, is_running=None):
        self.home = Path(home) if home else config.default_home()
        self.opener = opener
        self.api_base = api_base
        self.repo = repo
        self.trusted_prefix = trusted_prefix
        self.is_running = is_running          # None = really look for the game process
        self.settings = state.load_settings(self.home / "launcher.json")
        self.latest_release: Optional[Release] = releases.load_cache(self._cache_file)
        self.latest_is_fresh = False
        install.recover(self.paths)

    # -- locations -------------------------------------------------------------------------
    @property
    def _cache_file(self) -> Path:
        return self.home / "release_cache.json"

    @property
    def paths(self) -> Paths:
        return Paths(Path(self.settings.install_root) if self.settings.install_root else self.home)

    def set_install_root(self, folder: str | None) -> None:
        if self.installed_version() is not None:
            raise InstallError("The game is already installed. Move is not supported yet; the location is fixed.")
        self.settings.install_root = folder or None
        state.save_settings(self.home / "launcher.json", self.settings)
        install.recover(self.paths)

    # -- queries ---------------------------------------------------------------------------
    def installed_version(self) -> Optional[str]:
        return install.installed_version(self.paths)

    def state(self) -> state.State:
        latest = self.latest_release.version if self.latest_release else None
        return state.compute_state(self.installed_version(), latest)

    # -- actions ---------------------------------------------------------------------------
    def check_for_updates(self) -> Optional[Release]:
        """Ask GitHub for the newest installable release. Falls back to the cached one when offline."""
        try:
            found = releases.fetch_releases(repo=self.repo, api_base=self.api_base,
                                            allow_prerelease=self.settings.allow_prerelease,
                                            opener=self.opener, trusted_prefix=self.trusted_prefix)
        except ReleaseError:
            self.latest_is_fresh = False
            raise
        self.latest_is_fresh = True
        self.latest_release = releases.latest(found)
        if self.latest_release:
            releases.save_cache(self._cache_file, self.latest_release)
        return self.latest_release

    def install_latest(self, progress=None, cancel=None) -> str:
        if not self.latest_release:
            raise InstallError("No release is available to install yet.")
        return install.install_release(self.paths, self.latest_release, progress=progress, cancel=cancel,
                                       opener=self.opener, is_running=self.is_running)

    def play(self) -> None:
        exe = self.paths.exe
        if self.installed_version() is None:
            raise InstallError("The game is not installed.")
        if sys.platform != "win32":
            raise InstallError("The Windows game can only be started on Windows.")
        subprocess.Popen([str(exe)], cwd=str(exe.parent))
