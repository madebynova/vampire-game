"""Strict MAJOR.MINOR.PATCH version parsing and comparison (0.1.0 -> 0.2.0)."""
import re

_RE = re.compile(r"^v?(\d+)\.(\d+)\.(\d+)$")


def parse(version: str) -> tuple[int, int, int]:
    m = _RE.match(version.strip())
    if not m:
        raise ValueError(f"not a MAJOR.MINOR.PATCH version: {version!r}")
    return int(m.group(1)), int(m.group(2)), int(m.group(3))


def is_valid(version: str) -> bool:
    try:
        parse(version)
        return True
    except ValueError:
        return False


def compare(a: str, b: str) -> int:
    """-1 if a < b, 0 if equal, 1 if a > b. Numeric, so 0.10.0 > 0.9.0."""
    pa, pb = parse(a), parse(b)
    return (pa > pb) - (pa < pb)


def normalize(version: str) -> str:
    return "%d.%d.%d" % parse(version)
