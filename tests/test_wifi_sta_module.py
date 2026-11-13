"""Tests for the wifi-sta module: its payload matches the sums the module's
scripts check, and wifi_sta_run.sh runs the bundled scripts in the right
order, stops at the first refusal and changes nothing on unsupported
firmware. Host-only: the bundled scripts are replaced by stand-ins that log
their arguments, and the QNX paths are moved into a temporary directory.
The bundled scripts' own behaviour is tested in chundla/mmi3g-wifi-sta.
Set MMI_TEST_SHELL to exercise a specific interpreter (defaults to /bin/sh).
"""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / 'modules' / 'wifi-sta'
PAYLOAD = MODULE / 'payload'
RUN = MODULE / 'scripts' / 'wifi_sta_run.sh'
STEPS = ('sta-install.sh', 'gem-install.sh', 'lan-mode.sh')


def cksum(path):
    out = subprocess.run(['cksum', str(path)], capture_output=True, text=True,
                         check=True).stdout.split()
    return f'{out[0]} {out[1]}'


class Payload(unittest.TestCase):
    def test_cksums_cover_every_payload_file(self):
        listed = {}
        for line in (PAYLOAD / 'CKSUMS').read_text().splitlines():
            s, z, name = line.split(' ', 2)
            listed[name] = f'{s} {z}'
        present = {p.relative_to(PAYLOAD).as_posix() for p in PAYLOAD.rglob('*')
                   if p.is_file() and p.name != 'CKSUMS'}
        self.assertEqual(set(listed), present)
        for name, want in listed.items():
            self.assertEqual(cksum(PAYLOAD / name), want, name)

    def test_the_station_files_are_the_ones_sta_install_pins(self):
        text = (PAYLOAD / 'sta-install.sh').read_text()
        block = text[text.index("files='") + len("files='"):]
        block = block[:block.index("'")]
        for line in block.splitlines():
            name, _mode, s, z = line.split()
            self.assertEqual(cksum(PAYLOAD / name), f'{s} {z}', name)

    def test_the_gem_files_are_the_ones_gem_install_pins(self):
        text = (PAYLOAD / 'gem-install.sh').read_text()
        esd = re.search(r"^esd_sum='([^']+)'", text, re.M).group(1)
        gem = re.search(r"^gem_sum='([^']+)'", text, re.M).group(1)
        self.assertEqual(cksum(PAYLOAD / 'WifiClient.esd'), esd)
        self.assertEqual(cksum(PAYLOAD / 'gem.sh'), gem)

    def test_the_licences_and_sources_ship_with_the_binaries(self):
        for name in ('LICENCE.Marvell', 'GPL-2.0.txt', 'wpa_supplicant-COPYING.txt',
                     'jitterentropy-LICENSE.bsd.txt', 'qnx632-openssh-BSD-2-Clause.txt',
                     'mmi3g-wifi-sta-BSD-3-Clause.txt'):
            self.assertTrue((PAYLOAD / 'LICENSES' / name).is_file(), name)
        sources = (PAYLOAD / 'SOURCES.md').read_text()
        for name in ('devn-mv8688sta.so', 'mv8688-ctl', 'mv8688-probe', 'wpa_supplicant',
                     'jitter-egd', 'sd8688.bin', 'sd8688_helper.bin'):
            self.assertIn(f'`{name}` | `{cksum(PAYLOAD / name)}`', sources, name)


class Installer(unittest.TestCase):
    """wifi_sta_run.sh with stand-ins for the bundled scripts."""

    STATUS_OLD = 'wifi-sta: start-up line: in /mnt/persistence/openssh/start.sh (an older build\'s; unhook, then hook, to move it)'

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        b = self.base = Path(self.tmp.name)
        self.sd = b / 'sd'
        self.pay = self.sd / 'wifi-sta'
        shutil.copytree(PAYLOAD, self.pay)
        (self.sd / 'scripts').mkdir()
        self.calls = b / 'calls'
        self.bin = b / 'bin'
        self.bin.mkdir()
        self.flag = b / 'DLinkReplacesPPP'
        self.gem_dir = b / 'efs-persist' / 'wifi-sta' / 'gem'
        self.gem_dir.mkdir(parents=True)
        self.marker = self.gem_dir / 'client-at-start-up'
        self.persistence = b / 'persistence'
        self.persistence.mkdir()
        self.run_dir = b / 'tmpfs'
        self.run_dir.mkdir()
        self.factory = {}
        for name in ('devnp-mv8688uap.so', 'dhcp.client', 'dhcp-up'):
            path = b / name
            path.write_text(f'factory {name}\n')
            self.factory[name] = path
        # Each stand-in logs its arguments (and its stdin for conf), then
        # does what the test's environment asks.
        for name in STEPS:
            self.stand_in(name, f'''echo "{name} $*" >> "{self.calls}"
case "{name} $1" in
    "sta-install.sh status") echo "wifi-sta: state: ${{MOCK_STA_STATE:-absent}}"
        [ -n "${{MOCK_OLD_HOOK-}}" ] && echo "{self.STATUS_OLD}"
        [ -n "${{MOCK_CONF_PRESENT-}}" ] && echo "wifi-sta: wpa-hotspot.conf: present, root, mode 600, one WPA-PSK network"
        exit 0;;
    "gem-install.sh status") echo "wifi-gem: state: ${{MOCK_GEM_STATE:-absent}}"; exit 0;;
    "sta-install.sh conf") cat > "{b}/conf.received"; exit ${{MOCK_CONF_RC:-0}};;
    "sta-install.sh unhook") rm -f "{self.marker}";;
    "sta-install.sh install") [ -n "${{MOCK_HANG-}}" ] && exec /bin/sleep 30;;
esac
case " ${{MOCK_REFUSE-}} " in
    *" {name}:$1 "*) echo "refused"; exit 2;;
esac
exit 0
''')
        self.tool('uname', '#!/bin/sh\necho QNX\n')
        self.tool('mount', f'#!/bin/sh\necho "mount $*" >> "{self.calls}"\n')
        self.tool('cksum', '#!/bin/sh\ncase $1 in\n'
                  f'    {self.factory["devnp-mv8688uap.so"]}) echo "${{MOCK_DRIVER_SUM:-1022510863 93538}} $1";;\n'
                  f'    {self.factory["dhcp.client"]}) echo "263280565 57048 $1";;\n'
                  f'    {self.factory["dhcp-up"]}) echo "3046797907 6292 $1";;\n'
                  '    *) exec /usr/bin/cksum "$@";;\nesac\n')
        text = RUN.read_text()
        shell = os.environ.get('MMI_TEST_SHELL', '/bin/sh')
        for original, replacement in (
                ('ksh=/bin/ksh', f'ksh={shell}'),
                ('run=/fs/tmpfs', f'run={self.run_dir}'),
                ('persistence=/mnt/persistence', f'persistence={self.persistence}'),
                ('efs_system=/mnt/efs-system', f'efs_system={b}/efs-system'),
                ('marker=/mnt/efs-persist/wifi-sta/gem/client-at-start-up', f'marker={self.marker}'),
                ('gem_dir=/mnt/efs-persist/wifi-sta/gem', f'gem_dir={self.gem_dir}'),
                ('flag=/HBpersistence/DLinkReplacesPPP', f'flag={self.flag}'),
                ('driver=/lib/dll/devnp-mv8688uap.so', f'driver={self.factory["devnp-mv8688uap.so"]}'),
                ('dhcp_client=/usr/sbin/dhcp.client', f'dhcp_client={self.factory["dhcp.client"]}'),
                ('dhcp_up=/etc/dhcp/dhcp-up', f'dhcp_up={self.factory["dhcp-up"]}'),
                ('budget=300', 'budget=${MOCK_BUDGET:-300}'),
                ('PATH=/bin:/sbin:/usr/bin:/usr/sbin', f'PATH={self.bin}:/bin:/usr/bin')):
            self.assertIn(original, text)
            text = text.replace(original, replacement)
        self.script = self.sd / 'scripts' / 'wifi_sta_run.sh'
        self.script.write_text(text)
        self.reseal()

    def tool(self, name, text):
        path = self.bin / name
        path.write_text(text)
        path.chmod(0o755)

    def stand_in(self, name, text):
        (self.pay / name).write_text(text)

    def reseal(self):
        """CKSUMS for the stand-ins, as the build writes it for the real files."""
        lines = []
        for p in sorted(self.pay.rglob('*')):
            rel = p.relative_to(self.pay).as_posix()
            if p.is_file() and rel not in ('CKSUMS', 'hotspot.conf', 'REMOVE'):
                lines.append(f'{cksum(p)} {rel}')
        (self.pay / 'CKSUMS').write_text('\n'.join(lines) + '\n')

    def run_it(self, **env):
        out = subprocess.run([os.environ.get('MMI_TEST_SHELL', '/bin/sh'), str(self.script),
                              str(self.sd)], capture_output=True, text=True, timeout=60,
                             env={'PATH': '/usr/bin:/bin', 'LD_PRELOAD': '', **env})
        self.assertEqual(out.returncode in (0, 2), True, out.stdout + out.stderr)
        return out

    def steps(self):
        if not self.calls.exists():
            return []
        return [c for c in self.calls.read_text().splitlines()
                if not c.endswith(' status') and not c.startswith('mount')]

    def test_a_fresh_install_runs_every_step_in_order(self):
        (self.pay / 'hotspot.conf').write_text(
            'network={\n\tssid="phone"\n\t#psk="the passphrase"\n\tkey_mgmt=WPA-PSK\n'
            '\tpsk=' + '0' * 64 + '\n}\n')
        out = self.run_it()
        self.assertIn('RESULT: OK, installed.', out.stdout, out.stdout)
        self.assertEqual(self.steps(), [
            'lan-mode.sh enable', f'sta-install.sh install {self.pay}', 'sta-install.sh conf',
            f'gem-install.sh install {self.pay}', 'sta-install.sh hook'])
        received = (self.base / 'conf.received').read_text()
        self.assertNotIn('the passphrase', received)
        self.assertIn('psk=' + '0' * 64, received)
        self.assertFalse((self.pay / 'hotspot.conf').exists())
        self.assertEqual(list(self.run_dir.iterdir()), [])
        self.assertIn('Restart the unit: the LAN-mode flag', out.stdout)
        self.assertNotIn('the passphrase', out.stdout)

    def test_an_upgrade_moves_the_old_hook_and_keeps_the_start_up_choice(self):
        self.flag.write_text('')
        self.marker.write_text('')
        out = self.run_it(MOCK_OLD_HOOK='1', MOCK_STA_STATE='older', MOCK_GEM_STATE='older',
                          MOCK_CONF_PRESENT='1')
        self.assertIn('RESULT: OK, installed.', out.stdout, out.stdout)
        self.assertEqual(self.steps(), [
            'sta-install.sh unhook', f'sta-install.sh install {self.pay}',
            'gem-install.sh remove', f'gem-install.sh install {self.pay}',
            'sta-install.sh hook'])
        self.assertTrue(self.marker.exists())
        self.assertIn('GEM start-up choice kept', out.stdout)
        self.assertIn('the installed configuration stays', out.stdout)

    def test_unsupported_firmware_changes_nothing(self):
        out = self.run_it(MOCK_DRIVER_SUM='1 2')
        self.assertIn('this firmware is not supported, nothing was changed', out.stdout)
        self.assertEqual(self.steps(), [])
        self.assertFalse(self.calls.exists())

    def test_a_damaged_card_changes_nothing(self):
        with (self.pay / 'sd8688.bin').open('ab') as f:
            f.write(b'x')
        out = self.run_it()
        self.assertIn('sd8688.bin does not match its sum', out.stdout)
        self.assertIn('RESULT: FAILED', out.stdout)
        self.assertFalse(self.calls.exists())

    def test_a_refused_configuration_stays_on_the_card_and_stops_the_install(self):
        self.flag.write_text('')
        (self.pay / 'hotspot.conf').write_text('network={\n}\n')
        out = self.run_it(MOCK_CONF_RC='2')
        self.assertIn('sta-install.sh conf refused', out.stdout)
        self.assertTrue((self.pay / 'hotspot.conf').exists())
        self.assertEqual(self.steps(), [f'sta-install.sh install {self.pay}', 'sta-install.sh conf'])
        self.assertEqual(list(self.run_dir.iterdir()), [])

    def test_the_first_refusal_stops_the_steps_after_it(self):
        self.flag.write_text('')
        out = self.run_it(MOCK_REFUSE='gem-install.sh:install', MOCK_CONF_PRESENT='1')
        self.assertIn('FAILED: gem-install.sh install', out.stdout)
        self.assertNotIn('sta-install.sh hook', self.steps())

    def test_a_step_that_hangs_is_stopped(self):
        self.flag.write_text('')
        out = self.run_it(MOCK_HANG='1', MOCK_BUDGET='1')
        self.assertIn('FAILED: sta-install.sh install', out.stdout)

    def test_no_configuration_anywhere_is_a_warning(self):
        self.flag.write_text('')
        out = self.run_it()
        self.assertIn('WARNING: no hotspot configured', out.stdout)
        self.assertIn('RESULT: OK, installed.', out.stdout)

    def test_remove(self):
        (self.pay / 'REMOVE').write_text('')
        out = self.run_it()
        self.assertIn('RESULT: OK, removed.', out.stdout, out.stdout)
        self.assertEqual(self.steps(), ['sta-install.sh unhook', 'sta-install.sh remove',
                                        'gem-install.sh remove'])


if __name__ == '__main__':
    unittest.main()
