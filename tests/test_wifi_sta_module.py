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
STEPS = ('sta-install.sh', 'gem-install.sh', 'lan-mode.sh', 'sta-mode.sh')


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
        [ -n "${{MOCK_CONF_PRESENT-}}" ] && echo "wifi-sta: wpa-hotspot.conf: present, root, mode 600, 1 WPA-PSK network(s)"
        exit 0;;
    "gem-install.sh status") echo "wifi-gem: state: ${{MOCK_GEM_STATE:-absent}}"; exit 0;;
    "sta-install.sh conf") cat > "{b}/conf.received"; exit ${{MOCK_CONF_RC:-0}};;
    "sta-install.sh unhook") rm -f "{self.marker}";;
    "sta-install.sh install") [ -n "${{MOCK_HANG-}}" ] && exec /bin/sleep 30;;
    "sta-mode.sh stop") [ -n "${{MOCK_STOP_KEEPS_LOCK-}}" ] || rm -rf "{self.run_dir}/mmi-sta/lock";;
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
                  f'    {self.factory["dhcp-up"]}) echo "${{MOCK_DHCP_UP_SUM:-3046797907 6292}} $1";;\n'
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

    def test_drgers_lte_dhcp_up_is_accepted(self):
        # A unit with DrGER's LTE set-up: his dhcp-up, and the flag already set.
        self.flag.write_text('')
        out = self.run_it(MOCK_DHCP_UP_SUM='1601281849 792', MOCK_CONF_PRESENT='1')
        self.assertIn("dhcp-up is DrGER's LTE one (accepted)", out.stdout, out.stdout)
        self.assertIn('RESULT: OK, installed.', out.stdout, out.stdout)
        self.assertEqual(self.steps(), [
            f'sta-install.sh install {self.pay}', f'gem-install.sh install {self.pay}',
            'sta-install.sh hook'])

    def test_any_other_dhcp_up_changes_nothing(self):
        out = self.run_it(MOCK_DHCP_UP_SUM='12345 678')
        self.assertIn("neither the factory", out.stdout, out.stdout)
        self.assertIn('nothing was changed', out.stdout)
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

    def test_a_running_station_is_stopped_before_its_files_are_replaced(self):
        # With "start-up: join the hotspot" the station is up before any card.
        (self.run_dir / 'mmi-sta' / 'lock').mkdir(parents=True)
        self.flag.write_text('')
        out = self.run_it(MOCK_STA_STATE='older', MOCK_GEM_STATE='installed', MOCK_CONF_PRESENT='1')
        self.assertIn('RESULT: OK, installed.', out.stdout, out.stdout)
        self.assertEqual(self.steps()[:2], ['sta-mode.sh stop', f'sta-install.sh install {self.pay}'])
        self.assertIn('Wi-Fi drops until the restart', out.stdout)

    def test_a_station_that_will_not_stop_stops_the_install(self):
        (self.run_dir / 'mmi-sta' / 'lock').mkdir(parents=True)
        self.flag.write_text('')
        out = self.run_it(MOCK_STOP_KEEPS_LOCK='1', MOCK_CONF_PRESENT='1')
        self.assertIn('restart the unit with the card out', out.stdout, out.stdout)
        self.assertEqual(self.steps(), ['sta-mode.sh stop'])

    def test_remove(self):
        (self.pay / 'REMOVE').write_text('')
        out = self.run_it()
        self.assertIn('RESULT: OK, removed.', out.stdout, out.stdout)
        self.assertEqual(self.steps(), ['sta-install.sh unhook', 'sta-install.sh remove',
                                        'gem-install.sh remove'])

    # --- wifi-sta/options -------------------------------------------------

    def inbound(self):
        path = self.gem_dir / 'inbound'
        return path.read_text().splitlines() if path.exists() else None

    def test_options_set_the_start_up_choice_and_the_inbound_list(self):
        self.flag.write_text('')
        (self.gem_dir / 'telnet-on-hotspot').write_text('')
        (self.pay / 'options').write_text(
            '# made by the web builder\nstart-up=client\nallow=icmp\n'
            'allow=tcp 23   # telnet\n  allow=udp 5353\n')
        out = self.run_it()
        self.assertIn('RESULT: OK, installed.', out.stdout, out.stdout)
        self.assertTrue(self.marker.exists())
        self.assertEqual(self.inbound(), ['icmp', 'tcp 23', 'udp 5353'])
        self.assertFalse((self.gem_dir / 'telnet-on-hotspot').exists())
        self.assertIn('inbound: ping, tcp 23, udp 5353 admitted', out.stdout)
        self.assertIn('WARNING: telnet (tcp 23) is a root login', out.stdout)

    def test_options_ap_clears_the_start_up_choice(self):
        self.flag.write_text('')
        self.marker.write_text('')
        (self.pay / 'options').write_text('start-up=ap\n')
        out = self.run_it()
        self.assertIn('RESULT: OK, installed.', out.stdout, out.stdout)
        self.assertFalse(self.marker.exists())
        self.assertIn('inbound: unchanged', out.stdout)

    def test_without_options_the_inbound_list_stays(self):
        self.flag.write_text('')
        (self.gem_dir / 'inbound').write_text('icmp\n')
        out = self.run_it()
        self.assertIn('RESULT: OK, installed.', out.stdout, out.stdout)
        self.assertEqual(self.inbound(), ['icmp'])

    def test_allow_none_clears_the_list_and_the_telnet_marker(self):
        self.flag.write_text('')
        (self.gem_dir / 'inbound').write_text('icmp\ntcp 23\n')
        (self.gem_dir / 'telnet-on-hotspot').write_text('')
        (self.pay / 'options').write_text('allow=icmp\nallow=none\n')
        out = self.run_it()
        self.assertIn('RESULT: OK, installed.', out.stdout, out.stdout)
        self.assertIsNone(self.inbound())
        self.assertFalse((self.gem_dir / 'telnet-on-hotspot').exists())

    def test_a_bad_option_stops_before_any_step(self):
        for bad in ('allow=tcp', 'allow=tcp 0', 'allow=tcp 65536', 'allow=tcp 023',
                    'allow=tcp 23 24', 'allow=any', 'start-up=maybe'):
            with self.subTest(bad=bad):
                if self.calls.exists():
                    self.calls.unlink()
                (self.pay / 'options').write_text(f'start-up=client\n{bad}\n')
                out = self.run_it()
                self.assertIn('RESULT: FAILED', out.stdout)
                self.assertEqual(self.steps(), [])
                self.assertFalse(self.marker.exists())

    def test_remove_takes_the_inbound_list_too(self):
        (self.gem_dir / 'inbound').write_text('icmp\n')
        (self.gem_dir / 'telnet-on-hotspot').write_text('')
        (self.pay / 'REMOVE').write_text('')
        out = self.run_it()
        self.assertIn('RESULT: OK, removed.', out.stdout, out.stdout)
        self.assertIsNone(self.inbound())
        self.assertFalse((self.gem_dir / 'telnet-on-hotspot').exists())


class StationInbound(unittest.TestCase):
    """sta-mode.sh's inbound allow-list: its parser and the pf rules it loads,
    with pfctl replaced by a stand-in that keeps the rules in a file."""

    FUNCS = ('say', 'network_of', 'inbound_read', 'inbound_words', 'pf_load', 'inbound_pf')
    RULES = (
        'scrub in all no-df fragment reassemble\n'
        'pass in quick on en6 inet proto udp from any port = bootps to any port = bootpc keep state label "mmi_sta_en6"\n'
        'block drop in quick on en6 all label "mmi_sta_en6"\n'
        'pass out all keep state\n'
        'pass in quick on en5 all keep state\n')

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        b = self.base = Path(self.tmp.name)
        (b / 'state').mkdir()
        (b / 'rules').write_text(self.RULES)
        text = (PAYLOAD / 'sta-mode.sh').read_text()
        parts = []
        for name in self.FUNCS:
            m = re.search(rf'^{name}\(\) {{\n.*?^}}\n', text, re.M | re.S)
            self.assertIsNotNone(m, name)
            parts.append(m.group(0))
        consts = {k: re.search(rf'^{k}=(.*)$', text, re.M).group(1)
                  for k in ('sta_if', 'pf_label', 'ssh_label', 'inbound_label', 'inbound_max')}
        self.prelude = ''.join(f'{k}={v}\n' for k, v in consts.items()) + f"""
state={b}/state
inbound_file={b}/inbound
telnet_marker={b}/telnet-on-hotspot
pfctl() {{
    case "$1 $2" in
        "-sr ") cat "{b}/rules";;
        "-n -R") :;;
        "-R -f") cp "$3" "{b}/rules";;
        *) echo "pfctl $*" >&2; return 1;;
    esac
}}
""" + ''.join(parts)

    def sh(self, body):
        out = subprocess.run([os.environ.get('MMI_TEST_SHELL', '/bin/sh'), '-c',
                              self.prelude + body], capture_output=True, text=True, timeout=30)
        self.assertEqual(out.returncode, 0, out.stdout + out.stderr)
        return out.stdout

    def test_the_list_keeps_what_it_can_use(self):
        (self.base / 'inbound').write_text(
            "# the owner's list\nicmp\ntcp 23   # telnet\nudp 5353\ntcp 0\ntcp 70000\n"
            'tcp 023\ngopher 1\ntcp\ntcp 23\n\n')
        (self.base / 'telnet-on-hotspot').write_text('')
        out = self.sh('inbound_read; echo "LIST=$inbound"; echo "WORDS=$(inbound_words)"')
        self.assertIn('LIST=tcp:23 icmp udp:5353\n', out)
        self.assertIn('WORDS=tcp 23, ping, udp 5353\n', out)
        for skipped in ('tcp 0', 'tcp 70000', 'tcp 023', 'gopher', 'tcp '):
            self.assertIn(f'skipped "{skipped}', out)

    def test_no_list_admits_nothing(self):
        self.assertIn('LIST=\n', self.sh('inbound_read; echo "LIST=$inbound"'))

    def test_the_rules_follow_the_lease(self):
        self.sh('inbound="icmp tcp:23 udp:5353"; inbound_pf "192.168.43.17 24"')
        rules = (self.base / 'rules').read_text().splitlines()
        ours = [r for r in rules if 'label "mmi_sta_in"' in r]
        self.assertEqual(ours, [
            'pass in quick on en6 inet proto icmp from 192.168.43.0/24 to 192.168.43.17 icmp-type echoreq keep state label "mmi_sta_in"',
            'pass in quick on en6 inet proto tcp from 192.168.43.0/24 to 192.168.43.17 port = 23 flags S/SA keep state label "mmi_sta_in"',
            'pass in quick on en6 inet proto udp from 192.168.43.0/24 to 192.168.43.17 port = 5353 keep state label "mmi_sta_in"'])
        block = next(i for i, r in enumerate(rules) if r.startswith('block drop in quick on en6'))
        self.assertLess(rules.index(ours[-1]), block)
        # a lease on another network replaces them
        self.sh('inbound="icmp tcp:23 udp:5353"; inbound_pf "172.20.10.5 24"')
        rules = (self.base / 'rules').read_text()
        self.assertEqual(rules.count('label "mmi_sta_in"'), 3)
        self.assertNotIn('192.168.43.17', rules)
        self.assertIn('from 172.20.10.0/24 to 172.20.10.5 port = 23', rules)
        self.assertEqual(rules.count('label "mmi_sta_en6"'), 2)


if __name__ == '__main__':
    unittest.main()
