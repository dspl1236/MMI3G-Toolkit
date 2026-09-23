"""Tests for the shared module-hardening helpers in core/platform.sh
(mmi_run_bounded, mmi_arm_completion, mmi_at_exit) — the backstop that keeps
a module from wedging on running.png (issues #12/#13). Host-only; QNX
commands are mocked. Set MMI_TEST_SHELL to exercise a specific interpreter
(defaults to /bin/sh); CI also runs this under mksh.
"""
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]
PLATFORM = ROOT / "core" / "platform.sh"


class PlatformHardeningTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.sd = self.root / "sd"
        (self.sd / "bin").mkdir(parents=True)
        (self.sd / "lib").mkdir(parents=True)
        self.screens = self.root / "screens.log"
        self._write(self.sd / "bin" / "showScreen",
                    '#!/bin/sh\necho "$@" >> "$SHOWSCREEN_CAPTURE"\n')
        (self.sd / "lib" / "running.png").write_text("")
        (self.sd / "lib" / "done.png").write_text("")
        self.env = dict(os.environ)
        self.env["SHOWSCREEN_CAPTURE"] = str(self.screens)

    def _write(self, path, body):
        path.write_text(body)
        path.chmod(0o755)

    def _run(self, body, timeout=40):
        """Run a driver that sources platform.sh then executes `body`."""
        driver = self.root / "driver.sh"
        driver.write_text(
            'SDPATH="%s"\n. "%s"\n%s\n' % (self.sd.as_posix(), PLATFORM.as_posix(), body))
        start = time.time()
        r = subprocess.run(
            [os.environ.get("MMI_TEST_SHELL", "/bin/sh"), str(driver)],
            env=self.env, input="", text=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
        return r, time.time() - start

    def _screens(self):
        if not self.screens.exists():
            return []
        return [ln for ln in self.screens.read_text().splitlines() if ln.strip()]

    def test_run_bounded_bounds_a_hang(self):
        r, elapsed = self._run("MMI_CMD_BUDGET=1\n"
                               "mmi_run_bounded 1 sleep 30\n"
                               'echo AFTER')
        self.assertIn("AFTER", r.stdout, "run must continue past a bounded hang")
        self.assertLess(elapsed, 15, "the hang must be time-bounded")

    def test_arm_completion_shows_running_then_done_once(self):
        self._run("mmi_arm_completion done.png\n"
                  "mmi_show_screen running.png\n"
                  "exit 0")
        s = self._screens()
        run = [i for i, ln in enumerate(s) if "running.png" in ln]
        done = [i for i, ln in enumerate(s) if "done.png" in ln]
        self.assertTrue(run, "running.png must show: %r" % s)
        self.assertEqual(len(done), 1, "done.png must show exactly once: %r" % s)
        self.assertLess(run[0], done[0], "running.png must precede done.png")

    def test_completion_fires_on_a_signal(self):
        # arm, then TERM ourselves — trap 'exit' INT TERM HUP must still run EXIT
        self._run("mmi_arm_completion done.png\n"
                  "mmi_show_screen running.png\n"
                  "( sleep 0.3; kill -TERM $$ ) &\n"
                  "sleep 20")
        self.assertIn("done.png", "\n".join(self._screens()),
                      "completion screen must show even on a TERM")

    def test_at_exit_composes_multiple_cleanups(self):
        # mmi_reclaim_hold + mmi_arm_completion must not clobber each other.
        marker = self.root / "marker"
        self._run("mmi_at_exit 'echo A >> \"%s\"'\n"
                  "mmi_at_exit 'echo B >> \"%s\"'\n"
                  "exit 0" % (marker.as_posix(), marker.as_posix()))
        got = marker.read_text().split() if marker.exists() else []
        self.assertEqual(got, ["A", "B"], "both registered cleanups must run")


if __name__ == "__main__":
    unittest.main()
