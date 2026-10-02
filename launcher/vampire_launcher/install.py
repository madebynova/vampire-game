"""Download, verify and install a game release - safely.

Layout under the launcher home (default %LOCALAPPDATA%\\VampireGame):

    game\\        the installed game (REPLACED on every update; never put player data in here)
    staging\\     where a new version is unpacked and checked before it goes live
    backup\\      the previous game for the few moments an update is swapping in
    downloads\\   packages being downloaded (*.part until complete)

Player settings/saves live in the game's user-data folder (%APPDATA%\\VampireGame),
which this module never touches. That separation is what lets 0.1.0 -> 0.2.0 keep a player's data.

Order of an update (every step can fail without damaging the installed game):
    download -> verify size -> verify SHA-256 -> unpack to staging -> verify contents and version ->
    refuse if the game is running -> swap folders (old one kept until the swap succeeds).
"""
from __future__ import annotations

import hashlib
import os
import re
import shutil
import stat
import subprocess
import sys
import urllib.error
import urllib.request
import uuid
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Optional

from . import config, versions
from .releases import Release

Progress = Callable[[str, int, int], None]   # (stage, bytes_done, bytes_total)

MAX_UNPACKED_BYTES = 8 * 1024 ** 3           # refuse absurd archives
MAX_MEMBERS = 20000


class InstallError(Exception):
    """A failure with a message that is safe to show to a player. The installed game is untouched."""


@dataclass(frozen=True)
class Paths:
    root: Path

    @property
    def game(self) -> Path: return self.root / "game"
    @property
    def staging(self) -> Path: return self.root / "staging"
    @property
    def backup(self) -> Path: return self.root / "backup"
    @property
    def downloads(self) -> Path: return self.root / "downloads"
    @property
    def exe(self) -> Path: return self.game / config.GAME_EXE


# ------------------------------------------------------------------------------ what is installed

def _read_version(folder: Path) -> Optional[str]:
    try:
        v = (folder / config.VERSION_FILE).read_text(encoding="utf-8").strip()
    except OSError:
        return None
    return versions.normalize(v) if versions.is_valid(v) else None


def _is_valid_game(folder: Path) -> bool:
    return (folder / config.GAME_EXE).is_file() and _read_version(folder) is not None


def installed_version(paths: Paths) -> Optional[str]:
    """The version of the files actually on disk (the game folder is its own source of truth)."""
    return _read_version(paths.game) if _is_valid_game(paths.game) else None


def recover(paths: Paths) -> None:
    """Call at launcher start-up: clean up after an interrupted install or update."""
    _rmtree(paths.staging)
    if paths.downloads.is_dir():
        for part in paths.downloads.glob("*.part"):
            _unlink(part)
    if not _is_valid_game(paths.game) and _is_valid_game(paths.backup):
        _rmtree(paths.game)                       # a half-swapped, unusable folder
        paths.backup.rename(paths.game)           # put the previous working game back


# --------------------------------------------------------------------------------- running check

def is_game_running(paths: Paths | None = None) -> bool:
    if sys.platform != "win32":
        return False
    try:
        out = subprocess.run(["tasklist", "/FO", "CSV", "/NH"], capture_output=True, text=True,
                             timeout=15, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0)).stdout.lower()
    except (OSError, subprocess.SubprocessError):
        return False
    return any(f'"{name.lower()}"' in out for name in config.GAME_PROCESS_NAMES)


# ------------------------------------------------------------------------------------ checksums

def file_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


_HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")


def parse_checksum(text: str, filename: str) -> str:
    """Accepts `<hash>  <filename>` (sha256sum style) or a bare `<hash>`."""
    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    for ln in lines:
        parts = ln.split()
        if _HEX64.match(parts[0]) and (len(parts) == 1 or parts[-1].lstrip("*") == filename):
            return parts[0].lower()
    raise InstallError("The release's checksum file could not be read.")


# -------------------------------------------------------------------------------------- download

def download(url: str, dest: Path, *, expected_size: int = 0, progress: Progress | None = None,
             cancel=None, opener=urllib.request.urlopen, timeout: float = 30.0) -> Path:
    """Download to dest.part, check the size, then rename to dest. A partial file never looks finished."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    part = dest.with_name(dest.name + ".part")
    req = urllib.request.Request(url, headers={"User-Agent": f"VampireGameLauncher/{config.launcher_version()}"})
    try:
        with opener(req, timeout=timeout) as resp, open(part, "wb") as out:
            total = int(resp.headers.get("Content-Length") or expected_size or 0)
            done = 0
            while True:
                if cancel is not None and cancel.is_set():
                    raise InstallError("Download cancelled.")
                block = resp.read(1 << 16)
                if not block:
                    break
                out.write(block)
                done += len(block)
                if progress:
                    progress("Downloading", done, total)
    except InstallError:
        _unlink(part)
        raise
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        _unlink(part)
        raise InstallError("The download was interrupted. Nothing was changed; try again.") from e
    if (expected_size and done != expected_size) or (total and done != total):
        _unlink(part)
        raise InstallError("The download was incomplete. Nothing was changed; try again.")
    os.replace(part, dest)
    return dest


def download_text(url: str, *, opener=urllib.request.urlopen, timeout: float = 30.0, limit: int = 64 * 1024) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": f"VampireGameLauncher/{config.launcher_version()}"})
    try:
        with opener(req, timeout=timeout) as resp:
            return resp.read(limit).decode("utf-8", "replace")
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        raise InstallError("Could not download the release's checksum. Nothing was changed.") from e


# ---------------------------------------------------------------------------------------- unpack

def safe_extract(zip_path: Path, dest: Path) -> None:
    """Unpack, refusing anything that could write outside dest (zip-slip), links, or absurd sizes."""
    dest.mkdir(parents=True, exist_ok=True)
    root = dest.resolve()
    try:
        zf = zipfile.ZipFile(zip_path)
    except (zipfile.BadZipFile, OSError) as e:
        raise InstallError("The downloaded package is not a valid zip file.") from e
    with zf:
        infos = zf.infolist()
        if len(infos) > MAX_MEMBERS or sum(i.file_size for i in infos) > MAX_UNPACKED_BYTES:
            raise InstallError("The package is larger than expected and was refused.")
        for info in infos:
            name = info.filename
            if name.startswith(("/", "\\")) or re.match(r"^[A-Za-z]:", name) or ".." in re.split(r"[\\/]", name):
                raise InstallError("The package contains an unsafe path and was refused.")
            if (info.external_attr >> 16) & 0o170000 == stat.S_IFLNK:
                raise InstallError("The package contains a link and was refused.")
            target = (root / name).resolve()
            if target != root and root not in target.parents:
                raise InstallError("The package contains an unsafe path and was refused.")
            if info.is_dir():
                target.mkdir(parents=True, exist_ok=True)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            with zf.open(info) as src, open(target, "wb") as out:
                shutil.copyfileobj(src, out)


def _package_root(stage: Path) -> Path:
    """Packages may hold the game at the zip root, or inside one top-level folder."""
    if (stage / config.VERSION_FILE).exists() or (stage / config.GAME_EXE).exists():
        return stage
    entries = [p for p in stage.iterdir()]
    if len(entries) == 1 and entries[0].is_dir():
        return entries[0]
    return stage


def verify_package(folder: Path, expected_version: str) -> None:
    if not (folder / config.GAME_EXE).is_file():
        raise InstallError(f"The package does not contain {config.GAME_EXE}, so it was not installed.")
    found = _read_version(folder)
    if found is None:
        raise InstallError("The package has no valid VERSION file, so it was not installed.")
    if found != versions.normalize(expected_version):
        raise InstallError(f"The package is version {found}, not the expected {expected_version}. Nothing was changed.")


# ------------------------------------------------------------------------------------- install

def install_package(paths: Paths, zip_path: Path, version: str, *,
                    is_running: Optional[Callable[[Paths], bool]] = None) -> str:
    """Unpack zip_path, verify it really is `version`, and swap it in for the installed game."""
    is_running = is_running or is_game_running
    stage = paths.staging / f"{version}-{uuid.uuid4().hex[:8]}"
    try:
        safe_extract(zip_path, stage)
        content = _package_root(stage)
        verify_package(content, version)
        if is_running(paths):
            raise InstallError("Vampire Game is running. Close it and try again.")
        _swap(paths, content)
    finally:
        _rmtree(paths.staging)
    return versions.normalize(version)


def _swap(paths: Paths, new_game: Path) -> None:
    paths.root.mkdir(parents=True, exist_ok=True)
    _rmtree(paths.backup)
    had_old = paths.game.exists()
    if had_old:
        try:
            paths.game.rename(paths.backup)
        except OSError as e:
            raise InstallError("The current game folder is in use. Close the game and try again.") from e
    try:
        new_game.rename(paths.game)
    except OSError as e:
        if had_old:
            paths.backup.rename(paths.game)       # roll back: the old game goes straight back
        raise InstallError("The new version could not be put in place. The old version was kept.") from e
    _rmtree(paths.backup)                         # success: the previous version is no longer needed


def install_release(paths: Paths, release: Release, *, progress: Progress | None = None, cancel=None,
                    opener=urllib.request.urlopen,
                    is_running: Optional[Callable[[Paths], bool]] = None) -> str:
    """The whole official flow for one release. Returns the installed version."""
    expected = parse_checksum(download_text(release.checksum.url, opener=opener), release.package.name)
    zip_path = download(release.package.url, paths.downloads / release.package.name,
                        expected_size=release.package.size, progress=progress, cancel=cancel, opener=opener)
    try:
        if progress:
            progress("Verifying", 0, 0)
        if file_sha256(zip_path) != expected:
            raise InstallError("The download does not match its checksum, so it was discarded. Nothing was changed.")
        if progress:
            progress("Installing", 0, 0)
        return install_package(paths, zip_path, release.version, is_running=is_running)
    finally:
        _unlink(zip_path)


# ----------------------------------------------------------------------------------- helpers

def _rmtree(p: Path) -> None:
    def _fix(func, path, _exc):                   # Windows: clear read-only bits then retry
        try:
            os.chmod(path, stat.S_IWRITE)
            func(path)
        except OSError:
            pass
    if p.exists():
        if sys.version_info >= (3, 12):
            shutil.rmtree(p, onexc=_fix)
        else:
            shutil.rmtree(p, onerror=_fix)


def _unlink(p: Path) -> None:
    try:
        p.unlink()
    except OSError:
        pass
