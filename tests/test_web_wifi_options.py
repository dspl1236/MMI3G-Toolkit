"""The web builder's Wi-Fi client settings and the page's security headers.

The wifi-sta helpers are pulled out of docs/app/index.html and run under
node, like test_web_run_sh_parity does for generateRunSh.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import textwrap
import unittest
from urllib.parse import urlsplit

REPO_ROOT = Path(__file__).resolve().parents[1]


def _load_extract_function():
    spec = importlib.util.spec_from_file_location(
        'mmi3g_web_run_sh_parity_helpers', Path(__file__).resolve().parent / 'test_web_run_sh_parity.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.extract_function


extract_function = _load_extract_function()
WEB_BUILDER = REPO_ROOT / 'docs' / 'app' / 'index.html'
MANIFEST = REPO_ROOT / 'docs' / 'app' / 'manifest.json'

WIFI_FUNCTIONS = (
    'wifiSsidProblem',
    'wifiPassphraseProblem',
    'wifiPsk',
    'renderHotspotConf',
    'parseExtraPorts',
    'wifiAllowLines',
    'renderWifiOptions',
)
WEB_HEADER = '# Made by the MMI3G-Toolkit web builder (keys derived as wpa_passphrase does).\n'


def make_hotspot_conf_blocks(networks):
    """The network blocks exactly as make_hotspot_conf.py writes them."""
    blocks = []
    for i, (ssid, psk) in enumerate(networks):
        lines = ['network={', '\tssid="%s"' % ssid, '\tkey_mgmt=WPA-PSK', '\tpsk=%s' % psk]
        if len(networks) > 1:
            lines.append('\tpriority=%d' % (len(networks) - i))
        lines.append('}')
        blocks.append('\n'.join(lines) + '\n')
    return ''.join(blocks)


class WebWifiOptionsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        node = shutil.which('node')
        if node is None:
            raise unittest.SkipTest('node is not installed')
        cls.node = node
        source = WEB_BUILDER.read_text(encoding='utf-8')
        cls.functions_js = '\n'.join(extract_function(source, name) for name in WIFI_FUNCTIONS)

    def run_js(self, body):
        """Run `body` (an async function body returning a JSON-able value)."""
        script = textwrap.dedent(
            f'''
            const vm = require('node:vm');
            const sandbox = {{ crypto: require('node:crypto').webcrypto, TextEncoder }};
            vm.createContext(sandbox);
            vm.runInContext({json.dumps(self.functions_js)}, sandbox);
            const run = vm.runInContext('(async () => {{ ' + {json.dumps(body)} + ' }})', sandbox);
            run().then(
                (v) => process.stdout.write(JSON.stringify(v)),
                (e) => {{ process.stderr.write(String(e && e.stack || e)); process.exit(1); }});
            '''
        )
        result = subprocess.run(
            [self.node, '-'], input=script, cwd=str(REPO_ROOT), text=True, encoding='utf-8',
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_psk_matches_ieee_80211i_vector(self):
        psk = self.run_js('return await wifiPsk("IEEE", "password");')
        self.assertEqual(psk, 'f42c6fc52df0ebef9ebb4b90b38a5f902e83fe1b135a70e23aed762e9710a12e')

    def test_psk_matches_python_pbkdf2_for_utf8_name(self):
        ssid, passphrase = 'Café 5G ü', 'a b~c!d@e#f$'
        psk = self.run_js(f'return await wifiPsk({json.dumps(ssid)}, {json.dumps(passphrase)});')
        expected = hashlib.pbkdf2_hmac('sha1', passphrase.encode('ascii'), ssid.encode('utf-8'), 4096, 32).hex()
        self.assertEqual(psk, expected)

    def test_two_networks_render_like_make_hotspot_conf(self):
        nets = [('Pixel hotspot', 'correct horse 1'), ('Home', 'battery staple 2')]
        rendered = self.run_js(
            'const nets = ' + json.dumps(nets) + ';'
            'const keyed = [];'
            'for (const [ssid, pass] of nets) keyed.push({ ssid, psk: await wifiPsk(ssid, pass) });'
            'return renderHotspotConf(keyed);'
        )
        keyed = [
            (ssid, hashlib.pbkdf2_hmac('sha1', pw.encode('ascii'), ssid.encode('utf-8'), 4096, 32).hex())
            for ssid, pw in nets
        ]
        self.assertEqual(rendered, WEB_HEADER + make_hotspot_conf_blocks(keyed))
        self.assertIn('\tpriority=2\n', rendered)
        self.assertIn('\tpriority=1\n', rendered)
        self.assertNotIn('\r', rendered)
        for _, pw in nets:
            self.assertNotIn(pw, rendered)

    def test_one_network_has_no_priority_line(self):
        psk = 'ab' * 32
        rendered = self.run_js(f'return renderHotspotConf([{{ ssid: "Phone", psk: "{psk}" }}]);')
        self.assertEqual(rendered, WEB_HEADER + make_hotspot_conf_blocks([('Phone', psk)]))
        self.assertNotIn('priority', rendered)

    def test_invalid_names_and_passphrases_are_refused(self):
        problems = self.run_js(
            'return ['
            'wifiSsidProblem(""), wifiSsidProblem("a\\"b"), wifiSsidProblem("x".repeat(33)),'
            'wifiSsidProblem("\u00e9".repeat(17)), wifiSsidProblem("x".repeat(32)),'
            'wifiPassphraseProblem("short"), wifiPassphraseProblem("x".repeat(64)),'
            'wifiPassphraseProblem("caf\u00e9 caf\u00e9"), wifiPassphraseProblem("x".repeat(63)),'
            'wifiPassphraseProblem("12345678")];'
        )
        self.assertTrue(all(problems[:4]), problems)      # empty, quote, 33 bytes, 34 UTF-8 bytes
        self.assertIsNone(problems[4])                    # 32 bytes is fine
        self.assertTrue(all(problems[5:8]), problems)     # 5 chars, 64 chars, non-ASCII
        self.assertIsNone(problems[8])
        self.assertIsNone(problems[9])

    def test_options_defaults(self):
        out = self.run_js('return renderWifiOptions({ joinAtStartup: true, ping: true, telnet: false, extraPorts: "" });')
        self.assertEqual(out, '# wifi-sta options (made by the web builder)\nstart-up=client\nallow=icmp\n')

    def test_options_telnet_on_and_start_up_ap(self):
        out = self.run_js('return renderWifiOptions({ joinAtStartup: false, ping: true, telnet: true, extraPorts: "" });')
        self.assertEqual(out, '# wifi-sta options (made by the web builder)\nstart-up=ap\nallow=icmp\nallow=tcp 23\n')

    def test_options_extra_ports(self):
        out = self.run_js(
            'return renderWifiOptions({ ping: false, telnet: true, extraPorts: "TCP 2021, udp 5353; tcp 23\\ntcp  8080" });')
        self.assertEqual(
            out,
            '# wifi-sta options (made by the web builder)\nstart-up=client\n'
            'allow=tcp 23\nallow=tcp 2021\nallow=udp 5353\nallow=tcp 8080\n',
        )

    def test_options_nothing_allowed_writes_allow_none(self):
        out = self.run_js('return renderWifiOptions({ joinAtStartup: true, ping: false, telnet: false, extraPorts: "" });')
        self.assertEqual(out, '# wifi-sta options (made by the web builder)\nstart-up=client\nallow=none\n')

    def test_bad_extra_ports_are_refused(self):
        bad = self.run_js(
            'return ["tcp 0", "tcp 023", "udp 65536", "icmp 5", "tcp", "tcp 22 23", "tcp 65535"]'
            '.map((t) => parseExtraPorts(t).problems.length);'
        )
        self.assertEqual(bad, [1, 1, 1, 1, 1, 1, 0])
        too_many = self.run_js(
            'const extra = Array.from({ length: 16 }, (_, i) => "tcp " + (1000 + i)).join(", ");'
            'try { renderWifiOptions({ ping: true, extraPorts: extra }); return "rendered"; }'
            'catch (e) { return "refused"; }'
        )
        self.assertEqual(too_many, 'refused')


class WebPageSecurityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = WEB_BUILDER.read_text(encoding='utf-8')
        m = re.search(r'<meta http-equiv="Content-Security-Policy" content="([^"]+)">', cls.source)
        cls.csp = m.group(1) if m else None

    def directive(self, name):
        for part in self.csp.split(';'):
            words = part.split()
            if words and words[0] == name:
                return words[1:]
        return None

    def test_csp_meta_is_present_and_tight(self):
        self.assertIsNotNone(self.csp, 'no Content-Security-Policy meta tag')
        connect = self.directive('connect-src')
        self.assertIsNotNone(connect)
        self.assertFalse(any('*' in src for src in connect), connect)
        self.assertEqual(self.directive('object-src'), ["'none'"])
        self.assertEqual(self.directive('base-uri'), ["'none'"])
        self.assertEqual(self.directive('form-action'), ["'none'"])
        for directive in self.csp.split(';'):
            self.assertNotIn(' * ', f' {directive.strip()} ', directive)

    def test_connect_src_covers_every_host_the_manifest_names(self):
        connect = set(self.directive('connect-src'))
        manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
        urls = [manifest['raw_url_base']]
        ga = manifest.get('gemmi_assets') or {}
        urls += [ga.get('base_url')] + [a.get('url') for a in ga.get('files', [])]
        for meta in manifest['modules'].values():
            rz = meta.get('release_zip') or {}
            urls += [rz.get('web_url') or rz.get('url')]
            ra = meta.get('release_assets') or {}
            urls += [ra.get('base_url')]
        for url in filter(None, urls):
            parts = urlsplit(url)
            with self.subTest(url=url):
                self.assertIn(f'{parts.scheme}://{parts.netloc}', connect)

    def test_every_cdnjs_script_has_sri(self):
        tags = re.findall(r'<script[^>]*src="https://cdnjs\.cloudflare\.com/[^"]+"[^>]*>', self.source)
        self.assertTrue(tags)
        for tag in tags:
            with self.subTest(tag=tag):
                self.assertRegex(tag, r'integrity="sha384-[A-Za-z0-9+/]{64}"')
                self.assertIn('crossorigin="anonymous"', tag)
        # Nothing else loads script from off the page.
        external = re.findall(r'<script[^>]*src="(https?://[^"]+)"', self.source)
        self.assertTrue(all(u.startswith('https://cdnjs.cloudflare.com/') for u in external), external)


if __name__ == '__main__':
    unittest.main()
