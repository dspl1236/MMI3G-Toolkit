"""Regression tests for issues #12 and #13.

The system-info diagnostic must never wedge on a hung QNX utility (notably
`pidin fd`, which walks every process's fd table): it must time-bound each
heavy dump, always finish, and always advance the on-screen status to
done.png so the unit is never left stuck on running.png ("Running
Diagnose"). Host-only; the QNX commands are mocked and no listeners or
hardware are touched.

Set MMI_TEST_SHELL to a Korn/POSIX shell to exercise a specific
interpreter (defaults to /bin/sh); CI also runs this under mksh, whose
pdksh lineage is closer to the unit's ksh88 than dash is.
"""
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest


SOURCE = (Path(__file__).resolve().parents[1]
          / "modules" / "system-info" / "scripts" / "sysinfo_dump.sh")


class SystemInfoRobustnessTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.sd = self.root / "sd"
        (self.sd / "bin").mkdir(parents=True)
        (self.sd / "lib").mkdir(parents=True)
        self.mockbin = self.root / "mockbin"
        self.mockbin.mkdir()
        self.screens = self.root / "screens.log"

        # showScreen lives under SDPATH/bin — the script invokes it by path.
        self._write(self.sd / "bin" / "showScreen",
                    '#!/bin/sh\necho "$@" >> "$SHOWSCREEN_CAPTURE"\n')
        (self.sd / "lib" / "running.png").write_text("")
        (self.sd / "lib" / "done.png").write_text("")

        # Trivial mocks for the other heavy commands.
        for name in ("qdbc", "sloginfo"):
            self._write(self.mockbin / name, '#!/bin/sh\necho "%s mock"\n' % name)
        self._pidin()   # default: everything echoes

        self.env = dict(os.environ)
        self.env["PATH"] = str(self.mockbin) + os.pathsep + self.env["PATH"]
        self.env["SHOWSCREEN_CAPTURE"] = str(self.screens)
        # Tiny budgets so the test is fast; production defaults are generous.
        self.env["MMI_CMD_BUDGET"] = "1"
        self.env["MMI_RUN_BUDGET"] = "8"

    def _write(self, path, body):
        path.write_text(body)
        path.chmod(0o755)

    def _pidin(self, fd='echo "fd mock"', info='echo "info mock"'):
        """Install a pidin mock. `fd` is wrapped by run_bounded (per-command
        budget); `info` (section 1) is NOT wrapped, so hanging it exercises
        the global watchdog. Use 'exec sleep N' so the killed pid IS the
        blocked workload (not a shell whose child is orphaned)."""
        self._write(
            self.mockbin / "pidin",
            '#!/bin/sh\ncase "$1" in\n'
            '  fd) %s ;;\n'
            '  info) %s ;;\n'
            '  *) echo "pidin $* mock" ;;\n'
            'esac\n' % (fd, info),
        )

    def _run(self):
        return subprocess.run(
            [os.environ.get("MMI_TEST_SHELL", "/bin/sh"), str(SOURCE), str(self.sd)],
            env=self.env, input="", text=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=90)

    def _screens(self):
        if not self.screens.exists():
            return []
        return [ln for ln in self.screens.read_text().splitlines() if ln.strip()]

    def _report(self):
        hits = list((self.sd / "var" / "sysinfo").glob("sysinfo-*.txt"))
        return hits[0].read_text() if hits else ""

    def _assert_running_then_one_done(self):
        screens = self._screens()
        done = [i for i, ln in enumerate(screens) if "done.png" in ln]
        running = [i for i, ln in enumerate(screens) if "running.png" in ln]
        self.assertEqual(len(done), 1, "done.png must show exactly once: %r" % screens)
        self.assertTrue(running, "running.png must show: %r" % screens)
        self.assertLess(running[0], done[0], "running.png must precede done.png")

    def test_hanging_pidin_fd_is_bounded_per_command_and_completes(self):
        # The #12/#13 failure: pidin fd wedges. exec so the killed pid IS the sleep.
        self._pidin(fd="exec sleep 45")
        start = time.time()
        result = self._run()
        elapsed = time.time() - start
        self.assertEqual(result.returncode, 0)
        # Per-command budget (1s) must bound it — well under the 8s global net.
        self.assertLess(elapsed, int(self.env["MMI_RUN_BUDGET"]),
                        "hang must be caught by the per-command budget, not the global net")
        self._assert_running_then_one_done()
        self.assertIn("End of System Information Report", self._report(),
                      "later sections must still run after a bounded hang")

    def test_normal_run_completes_fast_without_pipe_stall(self):
        # Regression guard for the orphaned-watchdog-sleep pipe stall: a healthy
        # run under a captured pipe must finish well under MMI_RUN_BUDGET.
        start = time.time()
        result = self._run()
        elapsed = time.time() - start
        self.assertEqual(result.returncode, 0)
        self.assertLess(elapsed, int(self.env["MMI_RUN_BUDGET"]) - 2,
                        "normal run must not block for the whole run budget")
        self._assert_running_then_one_done()
        report = self._report()
        self.assertIn("18. EXTENDED PROCESS DUMP", report)
        self.assertIn("19. FULL SYSLOG DUMP", report)
        self.assertIn("End of System Information Report", report)

    def test_global_watchdog_catches_an_unwrapped_hang(self):
        # #12's "unknown stall point": hang a command that is NOT run_bounded
        # (pidin info, section 1). Only the global watchdog can save it.
        self.env["MMI_RUN_BUDGET"] = "3"
        self._pidin(info="exec sleep 45")
        start = time.time()
        result = self._run()
        elapsed = time.time() - start
        self.assertEqual(result.returncode, 0)
        self.assertGreaterEqual(elapsed, 3, "should run until the global budget")
        self.assertLess(elapsed, 30, "global watchdog must fire and end the run")
        self._assert_running_then_one_done()


if __name__ == "__main__":
    unittest.main()
