"""Repository sanity checks that don't need Godot. Run from anywhere:  python tools/check_repo.py

  * VERSION and launcher/VERSION are valid MAJOR.MINOR.PATCH
  * export_presets.cfg carries the same version as VERSION (run tools/sync_version.ps1 if not)
  * no Supabase service_role / secret keys, private keys or tokens anywhere in the repository
  * website/assets/js/config.js holds only public values
"""
import base64
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEMVER = re.compile(r"^\d+\.\d+\.\d+$")
problems = []


def read(p):
    return (ROOT / p).read_text(encoding="utf-8").strip()


# ---- versions ------------------------------------------------------------------------------
game, launcher = read("VERSION"), read("launcher/VERSION")
for name, v in (("VERSION", game), ("launcher/VERSION", launcher)):
    if not SEMVER.match(v):
        problems.append(f"{name} must look like 0.1.0, found {v!r}")
presets = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
for key in ("file_version", "product_version"):
    m = re.search(rf'^application/{key}="([^"]*)"', presets, re.M)
    if not m or m.group(1) != f"{game}.0":
        problems.append(f"export_presets.cfg application/{key} is {m.group(1) if m else 'missing'}, expected {game}.0 "
                        f"(run tools/sync_version.ps1)")

# ---- secrets ---------------------------------------------------------------------------------
JWT = re.compile(r"eyJ[A-Za-z0-9_-]{8,}\.([A-Za-z0-9_-]{8,})\.[A-Za-z0-9_-]{8,}")
OTHER = [
    (re.compile(r"sb_secret_[A-Za-z0-9_-]{10,}"), "Supabase secret key"),
    (re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"), "private key"),
    (re.compile(r"\bgh[pousr]_[A-Za-z0-9]{30,}"), "GitHub token"),
]
files = subprocess.run(["git", "ls-files", "-co", "--exclude-standard"], cwd=ROOT, capture_output=True,
                       text=True).stdout.splitlines()
for rel in files:
    path = ROOT / rel
    if path.suffix.lower() in {".png", ".jpg", ".ico", ".svg", ".uid", ".import", ".tres", ".tscn", ".gd", ".zip", ".exe"}:
        continue
    try:
        text = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        continue
    for m in JWT.finditer(text):
        try:
            payload = json.loads(base64.urlsafe_b64decode(m.group(1) + "=" * (-len(m.group(1)) % 4)))
        except ValueError:
            continue
        if payload.get("role") == "service_role":
            problems.append(f"{rel}: contains a Supabase service_role key. Remove it and ROTATE the key in Supabase.")
    for rx, label in OTHER:
        if rx.search(text):
            problems.append(f"{rel}: looks like it contains a {label}")

# ---- the public config may only hold public values ----------------------------------------------
cfg = read("website/assets/js/config.js")
key = re.search(r'supabaseAnonKey:\s*"([^"]*)"', cfg)
if not key:
    problems.append("website/assets/js/config.js: supabaseAnonKey line not found")
elif key.group(1).startswith("sb_secret_"):
    problems.append("website/assets/js/config.js holds a SECRET key; only the public anon/publishable key belongs there")

if problems:
    print("PROBLEMS:\n  " + "\n  ".join(problems))
    sys.exit(1)
print(f"OK: versions consistent (game {game}, launcher {launcher}); no secrets found in {len(files)} files.")
