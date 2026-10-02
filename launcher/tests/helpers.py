"""A fake GitHub for the launcher tests: serves /repos/<repo>/releases and the release assets."""
import hashlib
import io
import json
import threading
import zipfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

REPO = "test/vg"


def make_package(version, *, exe=b"MZ-fake-exe", version_text=None, extra=None, top_folder=None, raw_names=None):
    """Build a game zip in memory. `raw_names` adds members with exact (possibly hostile) names."""
    buf = io.BytesIO()
    prefix = f"{top_folder}/" if top_folder else ""
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr(prefix + "VampireGame.exe", exe + version.encode())
        z.writestr(prefix + "VERSION", (version if version_text is None else version_text) + "\n")
        z.writestr(prefix + "data/readme.txt", f"game {version}")
        for name, data in (extra or {}).items():
            z.writestr(prefix + name, data)
        for name, data in (raw_names or {}).items():
            z.writestr(name, data)
    return buf.getvalue()


class FakeGitHub:
    def __init__(self):
        self.releases = []        # raw GitHub-style dicts
        self.files = {}           # path -> bytes
        self.lie_about_size = {}  # path -> size to advertise in Content-Length-less listing
        self.server = None

    @property
    def base(self):
        return f"http://127.0.0.1:{self.server.server_address[1]}"

    @property
    def prefix(self):
        return self.base + "/dl/"

    def add_release(self, version, *, package=None, tag=None, draft=False, prerelease=False, body="",
                    checksum=None, with_checksum=True, size=None, tag_only=False):
        package = package if package is not None else make_package(version)
        tag = tag or f"v{version}"
        zname = f"VampireGame-Windows-v{version}.zip"
        zpath = f"/dl/{tag}/{zname}"
        self.files[zpath] = package
        assets = [{"name": zname, "browser_download_url": self.base + zpath,
                   "size": len(package) if size is None else size}]
        if with_checksum:
            digest = checksum or hashlib.sha256(package).hexdigest()
            text = f"{digest}  {zname}\n".encode()
            self.files[zpath + ".sha256"] = text
            assets.append({"name": zname + ".sha256", "browser_download_url": self.base + zpath + ".sha256",
                           "size": len(text)})
        self.releases.append({"tag_name": tag, "name": f"Vampire Game {version}", "body": body, "draft": draft,
                              "prerelease": prerelease, "published_at": "2026-01-01T00:00:00Z", "assets": assets})

    def start(self):
        outer = self

        class H(BaseHTTPRequestHandler):
            def log_message(self, *a):
                pass

            def do_GET(self):
                if self.path.startswith(f"/repos/{REPO}/releases"):
                    body = json.dumps(outer.releases).encode()
                elif self.path in outer.files:
                    body = outer.files[self.path]
                else:
                    self.send_error(404)
                    return
                self.send_response(200)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), H)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        return self

    def stop(self):
        self.server.shutdown()
        self.server.server_close()
