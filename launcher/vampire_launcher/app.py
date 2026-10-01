"""The launcher window (tkinter, standard library only). Dark gothic look to match the site and game."""
from __future__ import annotations

import queue
import sys
import threading
import tkinter as tk
from tkinter import filedialog, messagebox

from . import config
from .core import Launcher
from .install import InstallError
from .releases import ReleaseError
from .state import State

BG, PANEL, LINE = "#060306", "#0f070b", "#2a1a20"
BONE, DIM, MUTED = "#ede0cc", "#bcb0a3", "#8f847b"
BLOOD, BLOOD_DK, BRIGHT, GOLD = "#c7121f", "#7c0912", "#ff404d", "#ffcc66"
SERIF = "Georgia"
SANS = "Segoe UI"


class FlatButton(tk.Label):
    """A label that behaves like a button, so colours look the same everywhere (tk.Button ignores them on Windows)."""

    def __init__(self, parent, text, command, *, primary=False, width=None):
        self.primary, self.command, self.enabled = primary, command, True
        super().__init__(parent, text=text, cursor="hand2", font=(SANS, 11 if primary else 9, "bold"),
                         padx=26 if primary else 16, pady=12 if primary else 8, width=width)
        self.bind("<Button-1>", lambda e: self.enabled and self.command())
        self.bind("<Enter>", lambda e: self._paint(hover=True))
        self.bind("<Leave>", lambda e: self._paint())
        self._paint()

    def set(self, *, text=None, enabled=None):
        if text is not None:
            self.configure(text=text)
        if enabled is not None:
            self.enabled = enabled
        self._paint()

    def _paint(self, hover=False):
        if not self.enabled:
            self.configure(bg=PANEL, fg=MUTED, cursor="arrow", highlightthickness=1, highlightbackground=LINE)
        elif self.primary:
            self.configure(bg=BRIGHT if hover else BLOOD, fg="#ffffff", cursor="hand2",
                           highlightthickness=1, highlightbackground=BLOOD_DK)
        else:
            self.configure(bg="#1c0e14" if hover else BG, fg=BONE, cursor="hand2",
                           highlightthickness=1, highlightbackground=DIM if hover else LINE)


class ProgressBar(tk.Canvas):
    def __init__(self, parent):
        super().__init__(parent, height=6, bg=PANEL, highlightthickness=0)
        self.value = 0.0
        self.indeterminate = False
        self._tick = 0
        self.bind("<Configure>", lambda e: self.draw())

    def set(self, fraction=0.0, indeterminate=False):
        self.value, self.indeterminate = fraction, indeterminate
        self.draw()

    def draw(self):
        self.delete("all")
        w = self.winfo_width()
        if self.indeterminate:
            self._tick = (self._tick + 25) % max(w, 1)
            self.create_rectangle(self._tick, 0, min(self._tick + 80, w), 6, fill=BLOOD, width=0)
        elif self.value > 0:
            self.create_rectangle(0, 0, int(w * self.value), 6, fill=BRIGHT, width=0)


class LauncherApp:
    def __init__(self, root: tk.Tk, launcher: Launcher):
        self.root, self.L = root, launcher
        self.busy = False
        self.check_done = False
        self.check_error: str | None = None
        self.q: queue.Queue = queue.Queue()
        self.cancel = threading.Event()

        root.title("Vampire Game Launcher")
        root.configure(bg=BG)
        root.geometry("820x610")
        root.minsize(760, 580)
        self._build()
        self.refresh()
        root.after(80, self._poll)
        self.check_for_updates()

    # ------------------------------------------------------------------------------- layout
    def _build(self):
        r = self.root
        head = tk.Frame(r, bg=BG)
        head.pack(fill="x", padx=32, pady=(24, 8))
        tk.Label(head, text="VAMPIRE GAME", font=(SERIF, 34, "bold"), fg="#d4161f", bg=BG).pack(anchor="w")
        tk.Label(head, text=f"L A U N C H E R   ·   v{config.launcher_version()}", font=(SANS, 9),
                 fg=MUTED, bg=BG).pack(anchor="w")
        tk.Frame(r, bg=LINE, height=1).pack(fill="x", padx=32, pady=(10, 0))

        body = tk.Frame(r, bg=BG)
        body.pack(fill="both", expand=True, padx=32, pady=16)
        body.columnconfigure(1, weight=1)
        body.rowconfigure(0, weight=1)

        left = tk.Frame(body, bg=PANEL, padx=20, pady=18, highlightthickness=1, highlightbackground=LINE)
        left.grid(row=0, column=0, sticky="ns", padx=(0, 16))
        self.v_installed = self._field(left, "INSTALLED VERSION")
        self.v_latest = self._field(left, "LATEST VERSION")
        self.v_status = tk.Label(left, text="", font=(SERIF, 14, "italic"), fg=BONE, bg=PANEL,
                                 anchor="w", justify="left", wraplength=250)
        self.v_status.pack(anchor="w", pady=(2, 14))
        tk.Label(left, text="INSTALL LOCATION", font=(SANS, 8), fg=MUTED, bg=PANEL).pack(anchor="w")
        self.v_path = tk.Label(left, text="", font=(SANS, 9), fg=DIM, bg=PANEL, wraplength=250, justify="left",
                               anchor="w")
        self.v_path.pack(anchor="w", pady=(2, 6))
        self.b_change = FlatButton(left, "CHANGE…", self.change_location)
        self.b_change.pack(anchor="w")

        right = tk.Frame(body, bg=PANEL, padx=16, pady=14, highlightthickness=1, highlightbackground=LINE)
        right.grid(row=0, column=1, sticky="nsew")
        self.v_notes_title = tk.Label(right, text="CHANGELOG", font=(SANS, 8), fg=MUTED, bg=PANEL)
        self.v_notes_title.pack(anchor="w")
        box = tk.Frame(right, bg=PANEL)
        box.pack(fill="both", expand=True, pady=(6, 0))
        self.notes = tk.Text(box, wrap="word", bg=PANEL, fg=DIM, relief="flat", font=(SANS, 10), padx=2,
                             highlightthickness=0, insertbackground=PANEL, height=8)
        sb = tk.Scrollbar(box, command=self.notes.yview)
        self.notes.configure(yscrollcommand=sb.set)
        self.notes.pack(side="left", fill="both", expand=True)
        sb.pack(side="right", fill="y")

        bottom = tk.Frame(r, bg=BG)
        bottom.pack(fill="x", padx=32, pady=(0, 6))
        row = tk.Frame(bottom, bg=BG)
        row.pack(fill="x")
        self.b_main = FlatButton(row, "INSTALL GAME", self.on_main, primary=True)
        self.b_main.pack(side="left")
        self.b_play = FlatButton(row, "PLAY", self.on_play)
        self.b_check = FlatButton(row, "CHECK FOR UPDATES", self.check_for_updates)
        self.b_check.pack(side="right")
        self.bar = ProgressBar(bottom)
        self.bar.pack(fill="x", pady=(12, 4))
        self.v_msg = tk.Label(bottom, text="", font=(SANS, 9), fg=DIM, bg=BG, anchor="w")
        self.v_msg.pack(fill="x")
        tk.Label(r, text="Your settings and saves live outside the game folder and are never touched by updates.",
                 font=(SANS, 8), fg=MUTED, bg=BG).pack(side="bottom", pady=(0, 12))

    def _field(self, parent, label):
        tk.Label(parent, text=label, font=(SANS, 8), fg=MUTED, bg=PANEL).pack(anchor="w")
        v = tk.Label(parent, text="", font=(SERIF, 20, "bold"), fg=BONE, bg=PANEL, anchor="w")
        v.pack(anchor="w", pady=(0, 10))
        return v

    # --------------------------------------------------------------------------------- state
    def refresh(self):
        inst = self.L.installed_version()
        rel = self.L.latest_release
        st = self.L.state()
        self.v_installed.configure(text=inst or "—")
        self.v_latest.configure(text=rel.version if rel else ("checking…" if not self.check_done else "unavailable"))
        self.v_path.configure(text=str(self.L.paths.root))
        status, colour = {
            State.NOT_INSTALLED: ("Game not installed", BONE),
            State.UP_TO_DATE: ("Up to date", "#73d966"),
            State.UPDATE_AVAILABLE: ("New update available", GOLD),
            State.UNKNOWN: ("Couldn't check for updates", DIM),
        }[st]
        self.v_status.configure(text=status, fg=colour)

        main_text = {State.NOT_INSTALLED: "INSTALL GAME", State.UPDATE_AVAILABLE: "UPDATE"}.get(st, "PLAY")
        can_install = rel is not None
        main_enabled = (not self.busy) and (can_install if st in (State.NOT_INSTALLED, State.UPDATE_AVAILABLE) else True)
        self.b_main.set(text=main_text, enabled=main_enabled)
        if st is State.UPDATE_AVAILABLE:
            self.b_play.pack(side="left", padx=(12, 0))
            self.b_play.set(enabled=not self.busy)
        else:
            self.b_play.pack_forget()
        self.b_check.set(enabled=not self.busy)
        self.b_change.set(enabled=(not self.busy) and inst is None)

        self.v_notes_title.configure(text=f"CHANGELOG  ·  {rel.name}" if rel else "CHANGELOG")
        self.notes.configure(state="normal")
        self.notes.delete("1.0", "end")
        if rel:
            self.notes.insert("1.0", rel.notes or "No notes were written for this release.")
        elif self.check_done and not self.check_error:
            self.notes.insert("1.0", "No game release has been published yet.\n\nWhen the first Windows release "
                                     "exists on GitHub, it will appear here and the install button will work.")
        self.notes.configure(state="disabled")

    def say(self, text, colour=DIM):
        self.v_msg.configure(text=text, fg=colour)

    def set_busy(self, busy):
        self.busy = busy
        self.refresh()

    # ------------------------------------------------------------------------------- actions
    def _run(self, fn, done):
        """Run fn on a worker thread; call done(result, error) on the UI thread."""
        def work():
            try:
                self.q.put(("done", done, fn(), None))
            except Exception as e:                        # shown to the player; never crashes the window
                self.q.put(("done", done, None, e))
        threading.Thread(target=work, daemon=True).start()

    def _poll(self):
        try:
            while True:
                kind, *rest = self.q.get_nowait()
                if kind == "progress":
                    stage, done, total = rest
                    if total:
                        self.bar.set(done / total)
                        self.say(f"{stage}… {done * 100 // total}%")
                    else:
                        self.bar.set(0, indeterminate=True)
                        self.say(f"{stage}…")
                else:
                    cb, result, err = rest
                    cb(result, err)
        except queue.Empty:
            pass
        if self.bar.indeterminate:
            self.bar.draw()
        self.root.after(80, self._poll)

    def check_for_updates(self):
        if self.busy:
            return
        self.set_busy(True)
        self.say("Checking GitHub for the latest version…")

        def done(rel, err):
            self.check_done = True
            self.check_error = str(err) if isinstance(err, ReleaseError) else None
            self.set_busy(False)
            if isinstance(err, ReleaseError):
                self.say(str(err), "#f26659")
            elif err:
                self.say(f"Unexpected problem: {err}", "#f26659")
            elif rel is None:
                self.say("No game release has been published yet.")
            else:
                self.say("Up to date." if self.L.state() is State.UP_TO_DATE else f"Version {rel.version} is available.")
        self._run(self.L.check_for_updates, done)

    def on_main(self):
        st = self.L.state()
        if st in (State.NOT_INSTALLED, State.UPDATE_AVAILABLE):
            self.install()
        else:
            self.on_play()

    def install(self):
        rel = self.L.latest_release
        if not rel or self.busy:
            return
        self.set_busy(True)
        self.bar.set(0)
        self.say(f"Getting version {rel.version}…")

        def progress(stage, done, total):
            self.q.put(("progress", stage, done, total))

        def done(version, err):
            self.bar.set(0)
            self.set_busy(False)
            if err is None:
                self.say(f"Version {version} is installed. Press PLAY.", "#73d966")
            elif isinstance(err, InstallError):
                self.say(str(err), "#f26659")
            else:
                self.say(f"Unexpected problem: {err}", "#f26659")
        self._run(lambda: self.L.install_latest(progress=progress), done)

    def on_play(self):
        try:
            self.L.play()
            self.say("Starting Vampire Game…", "#73d966")
        except InstallError as e:
            self.say(str(e), "#f26659")

    def change_location(self):
        folder = filedialog.askdirectory(title="Choose where to install Vampire Game", mustexist=False)
        if not folder:
            return
        try:
            self.L.set_install_root(folder.replace("/", "\\") if sys.platform == "win32" else folder)
        except InstallError as e:
            messagebox.showinfo("Install location", str(e))
        self.refresh()


def run_app(smoke: bool = False) -> int:
    try:
        import ctypes
        ctypes.windll.shcore.SetProcessDpiAwareness(1)    # crisp text on high-DPI screens
    except Exception:
        pass
    root = tk.Tk()
    app = LauncherApp(root, Launcher())
    if smoke:                                             # construct, paint once, quit: proves the window builds
        root.update_idletasks()
        root.update()
        root.destroy()
        return 0
    root.mainloop()
    return 0
