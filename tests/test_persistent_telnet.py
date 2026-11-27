"""Host-only behavioral tests; no QNX services or network listeners are started."""
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "tools" / "persistent_telnet.sh"


class PersistentTelnetTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.ram = self.root / "ram"
        self.ram.mkdir()
        self.conf = self.ram / "inetd_2323.conf"
        self.log = self.ram / "mmi-persistent-telnet.log"
        self.lock = self.ram / "mmi-persistent-telnet.lock"
        self.capture = self.root / "launch"
        self.processes = self.root / "processes"
        self.addresses = self.root / "addresses"
        self.env = dict(os.environ, TEST_ROOT=str(self.root))
        self.command("uname", 'case "$1" in -s) echo QNX;; -r) echo 6.3.2;; -m) echo SH7785;; esac')
        self.command("pidin", 'cat "$TEST_ROOT/processes"')
        self.command("ifconfig", 'cat "$TEST_ROOT/addresses"')
        self.command("sleep", 'echo tick >> "$TEST_ROOT/sleeps"')
        self.command("inetd", '{ echo "$*"; pwd; echo "$LD_LIBRARY_PATH"; cat; } > "$TEST_ROOT/launch"')
        # Replace only fixed runtime paths in a temporary copy. Production has
        # no environment overrides for paths or for the platform guard.
        text = SOURCE.read_text()
        text = text.replace("PATH=/proc/boot:/bin:/sbin:/usr/bin:/usr/sbin",
                            "PATH=" + str(self.bin) + ":/bin:/usr/bin")
        text = text.replace("/dev/shmem/", str(self.ram) + "/")
        text = text.replace("/usr/sbin/inetd", str(self.bin / "inetd"))
        text = text.replace("[ -x /bin/ksh ]", "[ -x /bin/sh ]")
        # Host ksh can implement sleep as a builtin, bypassing PATH mocks.
        text = text.replace("    sleep 3", "    " + str(self.bin / "sleep") + " 3")
        self.script = self.root / "helper.sh"
        self.script.write_text(text)
        self.processes.write_text("1 /sbin/devc-pty\n2 " + str(self.bin / "inetd") + "\n")
        self.addresses.write_text("en5: flags=UP\n    inet 172.16.42.1 netmask 0xffffff00\n")

    def command(self, name, body):
        path = self.bin / name
        path.write_text("#!/bin/sh\n" + body + "\n")
        path.chmod(0o755)

    def run_helper(self, *args):
        return subprocess.run([os.environ.get("MMI_TEST_SHELL", "/bin/sh"),
                               str(self.script)] + list(args),
                              env=self.env, input="", text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              timeout=5)

    def opted_in(self):
        return self.run_helper("--allow-unauthenticated-root")

    def test_opt_in_required_before_writes(self):
        for args in [(), ("--wrong",), ("--allow-unauthenticated-root", "extra")]:
            result = self.run_helper(*args)
            self.assertEqual(result.returncode, 2)
            self.assertEqual(list(self.ram.iterdir()), [])

    def test_unsupported_platform_before_writes(self):
        self.command("uname", "echo Linux")
        self.assertEqual(self.opted_in().returncode, 1)
        self.assertEqual(list(self.ram.iterdir()), [])

    def test_launch_context_and_repeat_invocation(self):
        self.assertEqual(self.opted_in().returncode, 0)
        for _ in range(100):
            if self.capture.exists() and len(self.capture.read_text().splitlines()) >= 3:
                break
            time.sleep(0.01)
        lines = self.capture.read_text().splitlines()
        self.assertEqual(lines, [str(self.conf), "/",
                               "/lib:/lib/dll:/usr/lib:/usr/lib/dll:/proc/boot:/j9/bin"])
        self.assertEqual(self.conf.read_text(), "2323 stream tcp nowait root /bin/ksh ksh -i\n")
        self.assertIn("SHELL_NOT_TESTED", self.log.read_text())
        self.assertFalse(self.lock.exists())
        self.processes.write_text("12 " + str(self.bin / "inetd") + " " + str(self.conf) + "\n")
        self.capture.unlink()
        self.assertEqual(self.opted_in().returncode, 0)
        self.assertIn("EXISTING_INSTANCE=12", self.log.read_text())
        self.assertFalse(self.capture.exists())

    def test_existing_debug_instance_does_not_touch_config(self):
        self.processes.write_text("12 " + str(self.bin / "inetd") + " -d " + str(self.conf) + "\n")
        self.conf.write_text("leave this alone\n")
        self.assertEqual(self.opted_in().returncode, 0)
        self.assertEqual(self.conf.read_text(), "leave this alone\n")
        self.assertFalse(self.capture.exists())

    def test_address_substring_does_not_pass_readiness(self):
        self.addresses.write_text("inet 172.16.42.10 netmask 0xffffff00\n")
        self.assertEqual(self.opted_in().returncode, 1)
        self.assertIn("READINESS_TIMEOUT", self.log.read_text())
        self.assertEqual(len((self.root / "sleeps").read_text().splitlines()), 30)
        self.assertFalse(self.conf.exists())

    def test_missing_prerequisites(self):
        for listing in ["1 /sbin/devc-pty\n", "2 " + str(self.bin / "inetd") + "\n"]:
            self.processes.write_text(listing)
            self.assertEqual(self.opted_in().returncode, 1)
            self.assertIn("READINESS_TIMEOUT", self.log.read_text())
            self.assertFalse(self.conf.exists())

    def test_conflicting_configuration_is_preserved(self):
        self.conf.write_text("another service\n")
        self.assertEqual(self.opted_in().returncode, 1)
        self.assertEqual(self.conf.read_text(), "another service\n")
        self.assertIn("CONFIG_CONFLICT", self.log.read_text())
        self.assertFalse(self.capture.exists())

    def test_existing_lock_is_preserved(self):
        self.lock.write_text("123\n")
        self.assertEqual(self.opted_in().returncode, 1)
        self.assertEqual(self.lock.read_text(), "123\n")
        self.assertFalse(self.log.exists())

    def test_symlink_paths_are_rejected(self):
        target = self.root / "untouched"
        target.write_text("original")
        for path in [self.conf, self.log, self.lock]:
            path.symlink_to(target)
            self.assertEqual(self.opted_in().returncode, 1)
            self.assertEqual(target.read_text(), "original")
            path.unlink()
        self.assertFalse(self.capture.exists())

    def test_pidin_failure_aborts_without_start(self):
        self.command("pidin", "exit 1")
        self.assertEqual(self.opted_in().returncode, 1)
        self.assertFalse(self.conf.exists())
        self.assertFalse(self.lock.exists())


if __name__ == "__main__":
    unittest.main()
