"""Find the newest installable game release on GitHub.

An *installable* release is: published (not draft), not a pre-release (unless allowed), tagged
v<MAJOR>.<MINOR>.<PATCH>, and carrying BOTH the package zip and its .sha256 file as assets.
Anything else is ignored, so a half-finished release can never be offered to players.
"""
from __future__ import annotations

import json
import urllib.error
import urllib.request
from dataclasses import dataclass, asdict
from pathlib import Path

from . import config, versions


class ReleaseError(Exception):
    """Something went wrong talking to GitHub. The message is safe to show to a player."""


@dataclass(frozen=True)
class Asset:
    name: str
    url: str
    size: int


@dataclass(frozen=True)
class Release:
    version: str
    tag: str
    name: str
    notes: str
    published_at: str
    package: Asset
    checksum: Asset


def parse_releases(payload, *, repo: str = config.REPO, allow_prerelease: bool = False,
                   trusted_prefix: str | None = None) -> list[Release]:
    """Turn GitHub's /releases JSON into installable Releases, newest version first."""
    prefix = trusted_prefix if trusted_prefix is not None else config.trusted_download_prefix(repo)
    if not isinstance(payload, list):
        raise ReleaseError("GitHub returned an unexpected response.")
    found: list[Release] = []
    for item in payload:
        if not isinstance(item, dict) or item.get("draft"):
            continue
        if item.get("prerelease") and not allow_prerelease:
            continue
        m = config.GAME_TAG_RE.match(str(item.get("tag_name", "")))
        if not m:
            continue  # launcher releases, typos, anything that is not a game version
        version = m.group(1)
        assets = {a.get("name"): a for a in item.get("assets", []) if isinstance(a, dict)}
        pkg_raw = assets.get(config.package_name(version))
        sum_raw = assets.get(config.checksum_name(version))
        if not pkg_raw or not sum_raw:
            continue
        pkg, chk = _asset(pkg_raw), _asset(sum_raw)
        if not (pkg.url.startswith(prefix) and chk.url.startswith(prefix)):
            continue  # never download from anywhere but the project's own release assets
        found.append(Release(
            version=version,
            tag=item["tag_name"],
            name=str(item.get("name") or item["tag_name"]),
            notes=str(item.get("body") or "").strip(),
            published_at=str(item.get("published_at") or ""),
            package=pkg,
            checksum=chk,
        ))
    found.sort(key=lambda r: versions.parse(r.version), reverse=True)
    return found


def _asset(raw: dict) -> Asset:
    return Asset(name=str(raw.get("name")), url=str(raw.get("browser_download_url", "")),
                 size=int(raw.get("size") or 0))


def fetch_releases(*, repo: str = config.REPO, api_base: str | None = None, allow_prerelease: bool = False,
                   timeout: float = 15.0, opener=urllib.request.urlopen,
                   trusted_prefix: str | None = None) -> list[Release]:
    base = (api_base or config.API_BASE).rstrip("/")
    req = urllib.request.Request(
        f"{base}/repos/{repo}/releases?per_page=30",
        headers={"Accept": "application/vnd.github+json",
                 "User-Agent": f"VampireGameLauncher/{config.launcher_version()}"})
    try:
        with opener(req, timeout=timeout) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        if e.code == 403 and e.headers.get("X-RateLimit-Remaining") == "0":
            raise ReleaseError("GitHub is rate-limiting this computer. Try again in a little while.") from e
        if e.code == 404:
            raise ReleaseError("The release list could not be found.") from e
        raise ReleaseError(f"GitHub returned an error ({e.code}).") from e
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        raise ReleaseError("Could not reach GitHub. Check your internet connection.") from e
    except ValueError as e:
        raise ReleaseError("GitHub returned something unreadable.") from e
    return parse_releases(payload, repo=repo, allow_prerelease=allow_prerelease, trusted_prefix=trusted_prefix)


def latest(releases: list[Release]) -> Release | None:
    return releases[0] if releases else None


# ---- tiny cache so the changelog and "latest version" still show when offline -----------------

def save_cache(path: Path, release: Release) -> None:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(asdict(release), indent=2), encoding="utf-8")
    except OSError:
        pass  # a cache is a nicety, never a failure


def load_cache(path: Path) -> Release | None:
    try:
        d = json.loads(path.read_text(encoding="utf-8"))
        return Release(version=d["version"], tag=d["tag"], name=d["name"], notes=d["notes"],
                       published_at=d["published_at"], package=Asset(**d["package"]),
                       checksum=Asset(**d["checksum"]))
    except (OSError, ValueError, KeyError, TypeError):
        return None
