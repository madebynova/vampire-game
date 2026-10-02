import json
import tempfile
import threading
import unittest
import urllib.request
from pathlib import Path
from unittest import mock

from vampire_launcher import config, install, releases, state, versions
from vampire_launcher.core import Launcher
from vampire_launcher.install import InstallError, Paths
from vampire_launcher.releases import ReleaseError

from .helpers import REPO, FakeGitHub, make_package


class VersionTests(unittest.TestCase):
    def test_compare_is_numeric(self):
        self.assertEqual(versions.compare("0.1.0", "0.2.0"), -1)
        self.assertEqual(versions.compare("0.10.0", "0.9.0"), 1)
        self.assertEqual(versions.compare("1.0.0", "v1.0.0"), 0)

    def test_rejects_junk(self):
        for bad in ("1.0", "1.0.0-beta", "abc", "", "1.0.0.0"):
            self.assertFalse(versions.is_valid(bad), bad)

    def test_repo_version_files_are_valid(self):
        root = Path(__file__).resolve().parents[2]
        for f in (root / "VERSION", root / "launcher" / "VERSION"):
            self.assertTrue(versions.is_valid(f.read_text().strip()), f)


class StateTests(unittest.TestCase):
    def test_matrix(self):
        S = state.State
        self.assertIs(state.compute_state(None, "0.1.0"), S.NOT_INSTALLED)
        self.assertIs(state.compute_state(None, None), S.NOT_INSTALLED)
        self.assertIs(state.compute_state("0.1.0", "0.1.0"), S.UP_TO_DATE)
        self.assertIs(state.compute_state("0.1.0", "0.2.0"), S.UPDATE_AVAILABLE)
        self.assertIs(state.compute_state("0.3.0", "0.2.0"), S.UP_TO_DATE)
        self.assertIs(state.compute_state("0.1.0", None), S.UNKNOWN)


class ParseReleaseTests(unittest.TestCase):
    def setUp(self):
        self.gh = FakeGitHub().start()
        self.addCleanup(self.gh.stop)

    def parse(self, **kw):
        return releases.parse_releases(self.gh.releases, trusted_prefix=self.gh.prefix, **kw)

    def test_only_installable_releases_newest_first(self):
        gh = self.gh
        gh.add_release("0.1.0")
        gh.add_release("0.10.0")
        gh.add_release("0.9.0")
        gh.add_release("0.5.0", draft=True)
        gh.add_release("0.6.0", prerelease=True)
        gh.add_release("0.7.0", with_checksum=False)          # incomplete release: no checksum asset
        gh.add_release("0.2.0", tag="launcher-v0.2.0")        # a launcher release, not a game
        self.assertEqual([r.version for r in self.parse()], ["0.10.0", "0.9.0", "0.1.0"])
        self.assertIn("0.6.0", [r.version for r in self.parse(allow_prerelease=True)])

    def test_refuses_downloads_from_other_hosts(self):
        self.gh.add_release("0.1.0")
        self.assertEqual(releases.parse_releases(self.gh.releases), [])   # default trusts only github.com/<repo>

    def test_bad_payload(self):
        with self.assertRaises(ReleaseError):
            releases.parse_releases({"message": "nope"})


class FlowCase(unittest.TestCase):
    """Base: a fake GitHub, a temp launcher home, and a fake Godot user-data folder holding 'saves'."""

    def setUp(self):
        self.gh = FakeGitHub().start()
        self.addCleanup(self.gh.stop)
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.home = Path(tmp.name) / "VampireGame"
        self.userdata = Path(tmp.name) / "AppData" / "VampireGame"
        self.userdata.mkdir(parents=True)
        (self.userdata / "settings.cfg").write_text("master=0.5")
        (self.userdata / "save1.dat").write_text("precious")

    def launcher(self, running=False):
        return Launcher(self.home, api_base=self.gh.base, repo=REPO, trusted_prefix=self.gh.prefix,
                        is_running=lambda paths: running)

    def assertSavesIntact(self):
        self.assertEqual((self.userdata / "save1.dat").read_text(), "precious")
        self.assertEqual((self.userdata / "settings.cfg").read_text(), "master=0.5")


class InstallUpdateTests(FlowCase):
    def test_install_then_update_keeps_saves(self):
        self.gh.add_release("0.1.0", body="First playtest.")
        L = self.launcher()
        self.assertIs(L.state(), state.State.NOT_INSTALLED)
        self.assertEqual(L.check_for_updates().version, "0.1.0")
        self.assertEqual(L.install_latest(), "0.1.0")
        self.assertEqual(L.installed_version(), "0.1.0")
        self.assertIs(L.state(), state.State.UP_TO_DATE)
        self.assertTrue(L.paths.exe.is_file())

        self.gh.add_release("0.2.0", body="Foxes got scarier.", package=make_package("0.2.0", extra={"data/new.txt": "n"}))
        self.assertEqual(L.check_for_updates().version, "0.2.0")
        self.assertIs(L.state(), state.State.UPDATE_AVAILABLE)
        self.assertEqual(L.install_latest(), "0.2.0")
        self.assertEqual(L.installed_version(), "0.2.0")
        self.assertTrue((L.paths.game / "data" / "new.txt").exists())
        self.assertFalse(L.paths.backup.exists())
        self.assertFalse(L.paths.staging.exists())
        self.assertEqual(list(L.paths.downloads.glob("*")), [])
        self.assertSavesIntact()

    def test_package_inside_a_top_level_folder_is_accepted(self):
        self.gh.add_release("0.1.0", package=make_package("0.1.0", top_folder="VampireGame"))
        L = self.launcher()
        L.check_for_updates()
        self.assertEqual(L.install_latest(), "0.1.0")
        self.assertTrue((L.paths.game / "VampireGame.exe").is_file())

    def test_progress_is_reported(self):
        self.gh.add_release("0.1.0")
        L = self.launcher()
        L.check_for_updates()
        seen = []
        L.install_latest(progress=lambda stage, d, t: seen.append(stage))
        self.assertIn("Downloading", seen)
        self.assertIn("Installing", seen)

    def test_offline_falls_back_to_cached_release(self):
        self.gh.add_release("0.1.0", body="cached notes")
        L = self.launcher()
        L.check_for_updates()
        offline = Launcher(self.home, api_base="http://127.0.0.1:9", repo=REPO, trusted_prefix=self.gh.prefix)
        self.assertEqual(offline.latest_release.version, "0.1.0")
        self.assertEqual(offline.latest_release.notes, "cached notes")
        with self.assertRaises(ReleaseError):
            offline.check_for_updates()
        self.assertFalse(offline.latest_is_fresh)

    def test_install_location_can_be_chosen_before_install(self):
        self.gh.add_release("0.1.0")
        L = self.launcher()
        custom = self.home.parent / "Games" / "Vampire"
        L.set_install_root(str(custom))
        L.check_for_updates()
        L.install_latest()
        self.assertTrue((custom / "game" / "VampireGame.exe").is_file())
        self.assertEqual(self.launcher().installed_version(), "0.1.0")     # remembered across launches
        with self.assertRaises(InstallError):
            L.set_install_root(str(self.home))


class SafetyTests(FlowCase):
    def installed_010(self):
        self.gh.add_release("0.1.0")
        L = self.launcher()
        L.check_for_updates()
        L.install_latest()
        return L

    def assertStillGood(self, L, version="0.1.0"):
        self.assertEqual(L.installed_version(), version)
        self.assertEqual((L.paths.game / "data" / "readme.txt").read_text(), f"game {version}")
        self.assertFalse(L.paths.staging.exists())
        self.assertSavesIntact()

    def attempt(self, L, **release_kw):
        self.gh.add_release("0.2.0", **release_kw)
        L.check_for_updates()
        with self.assertRaises(InstallError) as cm:
            L.install_latest()
        return str(cm.exception)

    def test_wrong_checksum_is_rejected(self):
        L = self.installed_010()
        msg = self.attempt(L, checksum="0" * 64)
        self.assertIn("checksum", msg)
        self.assertStillGood(L)
        self.assertEqual(list(L.paths.downloads.glob("*")), [])

    def test_incomplete_download_is_rejected(self):
        L = self.installed_010()
        msg = self.attempt(L, size=12345)            # advertised size does not match what arrives
        self.assertIn("incomplete", msg)
        self.assertStillGood(L)

    def test_package_with_wrong_version_is_rejected(self):
        L = self.installed_010()
        msg = self.attempt(L, package=make_package("0.2.0", version_text="0.1.5"))
        self.assertIn("not the expected 0.2.0", msg)
        self.assertStillGood(L)

    def test_package_without_exe_or_version_is_rejected(self):
        L = self.installed_010()
        import io, zipfile
        buf = io.BytesIO()
        with zipfile.ZipFile(buf, "w") as z:
            z.writestr("hello.txt", "no game here")
        self.attempt(L, package=buf.getvalue())
        self.assertStillGood(L)

    def test_zip_slip_is_rejected(self):
        L = self.installed_010()
        evil = make_package("0.2.0", raw_names={"../../evil.txt": "pwned"})
        self.attempt(L, package=evil)
        self.assertStillGood(L)
        self.assertFalse((self.home.parent / "evil.txt").exists())
        self.assertFalse((self.home / "evil.txt").exists())

    def test_absolute_and_drive_paths_are_rejected(self):
        for bad in ("/abs.txt", "C:/Windows/x.txt", "a\\..\\..\\b.txt"):
            with self.subTest(bad=bad), tempfile.TemporaryDirectory() as d:
                zp = Path(d) / "p.zip"
                zp.write_bytes(make_package("0.2.0", raw_names={bad: "x"}))
                with self.assertRaises(InstallError):
                    install.safe_extract(zp, Path(d) / "out")

    def test_not_a_zip_is_rejected(self):
        L = self.installed_010()
        self.attempt(L, package=b"this is not a zip")
        self.assertStillGood(L)

    def test_running_game_blocks_the_update(self):
        L = self.installed_010()
        self.gh.add_release("0.2.0")
        L.check_for_updates()
        L.is_running = lambda paths: True
        with self.assertRaises(InstallError) as cm:
            L.install_latest()
        self.assertIn("running", str(cm.exception))
        self.assertStillGood(L)

    def test_failed_swap_rolls_back_to_the_old_game(self):
        L = self.installed_010()
        self.gh.add_release("0.2.0")
        L.check_for_updates()
        real_rename = Path.rename
        calls = {"n": 0}

        def flaky(self_path, target):
            calls["n"] += 1
            if self_path.parent == L.paths.staging or self_path.parent.parent == L.paths.staging:
                raise PermissionError("simulated: cannot move new version into place")
            return real_rename(self_path, target)

        with mock.patch.object(Path, "rename", flaky):
            with self.assertRaises(InstallError):
                L.install_latest()
        self.assertStillGood(L)
        self.assertFalse(L.paths.backup.exists())

    def test_recover_removes_leftovers_and_restores_backup(self):
        L = self.installed_010()
        # simulate a crash half-way through a swap: no game folder, previous version in backup/, junk in staging/
        L.paths.game.rename(L.paths.backup)
        (L.paths.staging / "0.2.0-abc").mkdir(parents=True)
        L.paths.downloads.mkdir(exist_ok=True)
        (L.paths.downloads / "x.zip.part").write_text("partial")
        fresh = self.launcher()                                  # start-up runs recover()
        self.assertEqual(fresh.installed_version(), "0.1.0")
        self.assertFalse(fresh.paths.staging.exists())
        self.assertEqual(list(fresh.paths.downloads.glob("*.part")), [])
        self.assertSavesIntact()

    def test_checksum_file_formats(self):
        h = "ab" * 32
        self.assertEqual(install.parse_checksum(f"{h}  pkg.zip\n", "pkg.zip"), h)
        self.assertEqual(install.parse_checksum(f"{h} *pkg.zip", "pkg.zip"), h)
        self.assertEqual(install.parse_checksum(h, "pkg.zip"), h)
        with self.assertRaises(InstallError):
            install.parse_checksum(f"{h}  other.zip", "pkg.zip")
        with self.assertRaises(InstallError):
            install.parse_checksum("garbage", "pkg.zip")

    def test_cancel_stops_download_and_leaves_no_partial(self):
        self.gh.add_release("0.1.0")
        L = self.launcher()
        L.check_for_updates()
        stop = threading.Event()
        stop.set()
        with self.assertRaises(InstallError):
            L.install_latest(cancel=stop)
        self.assertIsNone(L.installed_version())
        self.assertEqual(list(L.paths.downloads.glob("*")), [])


class ConfigTests(unittest.TestCase):
    def test_naming_contract(self):
        self.assertEqual(config.package_name("0.1.0"), "VampireGame-Windows-v0.1.0.zip")
        self.assertEqual(config.checksum_name("0.1.0"), "VampireGame-Windows-v0.1.0.zip.sha256")
        self.assertTrue(config.GAME_TAG_RE.match("v0.1.0"))
        self.assertFalse(config.GAME_TAG_RE.match("launcher-v0.1.0"))

    def test_launcher_version_comes_from_the_version_file(self):
        self.assertEqual(config.launcher_version(), (Path(__file__).resolve().parents[1] / "VERSION").read_text().strip())


if __name__ == "__main__":
    unittest.main()
