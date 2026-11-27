"""Scripts that run on the unit may only use tools the unit has.

The tool list was probed on a real MMI 3G+ (Audi A6, K0942_3) on 2026-11-27:
most POSIX tools are absent (no awk, head, tail, cut, tr, find, xargs, wc...).
core/platform.sh supplies stand-ins for some of them, so a script may use those
only if it sources platform.sh. The stand-ins themselves are run here with
nothing but the unit's tools on PATH, under bash and dash."""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
PLATFORM_SH = REPO_ROOT / 'core' / 'platform.sh'

# On the A6's PATH (/proc/boot:/bin:/sbin:/usr/sbin:/usr/bin:/j9/bin), 2026-11-27.
UNIT_HAS = set('''sed grep cat ls cp mv rm mkdir cksum df netstat ifconfig pidin sloginfo
    ping date uname use slay mount umount route touch chmod ln sleep'''.split())
# Probed and absent.
UNIT_LACKS = set('''awk head tail cut tr sort uniq wc xargs find od hexdump md5 strings dd tee
    basename dirname expr printf env which stat seq diff gzip tar readlink'''.split())

# Uses that are known not to work on the unit yet, with the reason. A new
# script that needs one of these tools must source platform.sh (for a tool it
# stands in for) or avoid the tool; add here only with a reason.
KNOWN_GAPS = {
    'modules/can-diag/scripts/can_diag.sh': {'awk', 'cut'},
    'modules/can-diag/scripts/grab_binaries.sh': {'awk'},
    'modules/can-diag/scripts/read_live_data.sh': {'awk', 'cut', 'head', 'printf'},
    'modules/can-diag/scripts/read_module_info.sh': {'awk', 'cut'},
    'modules/can-diag/scripts/scan_modules.sh': {'awk', 'printf', 'tail'},
    # ^ can-diag is hidden from the catalog; rewrite before showing it again.
    'modules/can-scanner/scripts/scan_log.sh': {'dd', 'strings'},
    'modules/google-earth/payload/gemmi_server.sh': {'awk', 'printf', 'tr', 'wc'},
    # ^ legacy HTTP stand-in: also shadows $PATH with the request path.
    'modules/jvm-extract/scripts/jvm_extract.sh': {'dd', 'od', 'strings'},
    'modules/long-coding/scripts/coding_changelog.sh': {'diff'},
}

USE = re.compile(
    r'(?:^|[|;&(`]|\$\(|\bthen\b|\bdo\b|\belse\b|&&|\|\|)\s*'
    r'(?:(?:mmi_)?run_bounded\s+\S+\s+)?(' + '|'.join(sorted(UNIT_LACKS)) + r')(?=\s|$|\))')


def on_unit_scripts():
    paths = set(REPO_ROOT.glob('modules/*/scripts/**/*.sh'))
    paths |= set(REPO_ROOT.glob('modules/*/payload/**/*.sh'))
    paths |= set(REPO_ROOT.glob('core/*.sh'))
    paths.discard(PLATFORM_SH)
    return sorted(paths)


def tools_used(text):
    used = set()
    for line in text.splitlines():
        s = line.strip()
        if s.startswith('#'):
            continue
        s = re.sub(r'^(echo|print|say|log)\s+"[^"]*"', '', s)
        used.update(m.group(1) for m in USE.finditer(s))
    return used


def stood_in():
    return set(re.findall(r'^if ! command -v (\w+) ', PLATFORM_SH.read_text(encoding='utf-8'), re.M))


class UnitToolUse(unittest.TestCase):
    def test_the_probed_lists_do_not_overlap(self):
        self.assertFalse(UNIT_HAS & UNIT_LACKS)

    def test_platform_sh_stands_in_for_what_the_scripts_use(self):
        self.assertTrue({'head', 'tail', 'awk', 'cut', 'tr', 'wc', 'xargs', 'find',
                         'basename', 'dirname', 'sort', 'uniq', 'printf', 'readlink'} <= stood_in())

    def test_every_on_unit_script_uses_only_what_the_unit_has(self):
        shims = stood_in()
        problems = []
        seen_gaps = {}
        for path in on_unit_scripts():
            rel = path.relative_to(REPO_ROOT).as_posix()
            text = path.read_text(encoding='utf-8', errors='replace')
            sources = 'platform.sh' in text
            bad = {t for t in tools_used(text) if not (sources and t in shims)}
            gaps = KNOWN_GAPS.get(rel, set())
            if bad & gaps:
                seen_gaps[rel] = bad & gaps
            for tool in sorted(bad - gaps):
                why = ('source scripts/common/platform.sh' if tool in shims
                       else 'the unit has no stand-in for it')
                problems.append(f'{rel}: uses {tool} ({why})')
        self.assertEqual(problems, [], '\n' + '\n'.join(problems))
        # A gap that was fixed should leave the list too.
        stale = {k: v - seen_gaps.get(k, set()) for k, v in KNOWN_GAPS.items()}
        stale = {k: v for k, v in stale.items() if v}
        self.assertEqual(stale, {}, 'remove fixed entries from KNOWN_GAPS')


# The stand-ins against what the real tools print. Same cases as the run on the A6.
SHIM_CASES = r'''
. "$PLAT"
P=0; F=0
chk() { if [ "$2" = "$3" ]; then P=$((P+1)); else F=$((F+1)); echo "FAIL $1: got [$2] want [$3]"; fi; }
NL="
"
for l in "l1 a:b:c" "l2 d:e:f" "l3 g:h:i" "l4 j:k:l" "l4 j:k:l"; do echo "$l"; done > "$T/t.txt"
chk head-file "$(head -2 "$T/t.txt" < /dev/null)" "l1 a:b:c${NL}l2 d:e:f"
chk head-n "$(head -n 1 "$T/t.txt" < /dev/null)" "l1 a:b:c"
chk head-pipe "$(cat "$T/t.txt" | head -1)" "l1 a:b:c"
chk tail-file "$(tail -2 "$T/t.txt" < /dev/null)" "l4 j:k:l${NL}l4 j:k:l"
chk tail-1 "$(cat "$T/t.txt" | tail -1)" "l4 j:k:l"
chk tail-n3 "$(tail -n 3 "$T/t.txt")" "l3 g:h:i${NL}l4 j:k:l${NL}l4 j:k:l"
chk awk-file "$(awk '{print $2}' "$T/t.txt" < /dev/null | head -1)" "a:b:c"
chk awk-F "$(awk -F: '{print $2}' "$T/t.txt" | head -1)" "b"
chk awk-ls "$(echo '-rw-------  1 root  root   296 Jan 01 00:00 /etc/passwd' | awk '{print $5}')" "296"
chk awk-star "$(echo 'a * c' | awk '{print $2}')" "*"
chk cut-f "$(cut -d: -f2 "$T/t.txt" | head -1)" "b"
chk cut-f1 "$(echo 'main=Foo' | cut -d= -f2)" "Foo"
chk cut-frest "$(echo 'a:b:c' | cut -d: -f2-)" "b:c"
chk cut-space "$(echo '-rw-r--r-- 1 root root 296 Jan' | cut -d' ' -f5)" "296"
chk cut-nodelim "$(echo 'plain' | cut -d: -f2)" "plain"
chk cut-past-end "$(echo 'a:b' | cut -d: -f5)" ""
chk cut-c12 "$(echo 'A1B2' | cut -c1-2)" "A1"
chk cut-c34 "$(echo 'A1B2' | cut -c3-4)" "B2"
chk tr-range "$(echo 'DEADBEEF' | tr 'A-F' 'a-f')" "deadbeef"
chk tr-d-space "$(echo '0a 1b 2c' | tr -d ' ')" "0a1b2c"
CR="$(echo x | sed 's/x/\r/')"
chk tr-d-cr "$(echo "GET${CR}" | tr -d '\r')" "GET"
chk dirname "$(dirname /fs/sd0/run.sh)" "/fs/sd0"
chk dirname-top "$(dirname /run.sh)" "/"
chk dirname-rel "$(dirname run.sh)" "."
chk basename "$(basename /a/b/c.sh .sh)" "c"
chk sort-u "$(sort -u "$T/t.txt" | tail -1)" "l4 j:k:l"
chk sort-u-count "$(sort -u "$T/t.txt" | wc -l)" "4"
chk uniq "$(uniq "$T/t.txt" | wc -l)" "4"
chk wc "$(wc -l < "$T/t.txt")" "5"
mkdir -p "$T/fd/sub"; echo 1 > "$T/fd/a.txt"; echo 2 > "$T/fd/sub/b.txt"; echo 3 > "$T/fd/sub/c.log"
chk find-name "$(find "$T/fd" -name '*.txt' -type f | sort -u | wc -l)" "2"
chk find-depth "$(find "$T/fd" -maxdepth 1 -type f)" "$T/fd/a.txt"
chk find-dirs "$(find "$T/fd" -type d | wc -l)" "2"
chk xargs-grep "$(find "$T/fd" -type f | xargs grep -l 3)" "$T/fd/sub/c.log"
chk xargs-basename "$(ls -d "$T/fd/sub" | head -1 | xargs basename)" "sub"
echo "RESULT pass=$P fail=$F"
'''


class PlatformStandIns(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.shells = [s for s in (shutil.which('bash'), shutil.which('dash')) if s]
        if not cls.shells or shutil.which('sed') is None:
            raise unittest.SkipTest('needs a POSIX shell and sed')

    def run_cases(self, shell):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            bindir = tmp / 'bin'
            bindir.mkdir()
            for tool in UNIT_HAS:
                real = shutil.which(tool)
                if real:
                    (bindir / tool).symlink_to(real)
            work = tmp / 'work'
            work.mkdir()
            out = subprocess.run(
                [shell, '-c', SHIM_CASES],
                env={'PATH': str(bindir), 'PLAT': str(PLATFORM_SH), 'T': str(work)},
                capture_output=True, text=True, timeout=60)
            return out.stdout + out.stderr

    def test_the_stand_ins_print_what_the_real_tools_print(self):
        for shell in self.shells:
            with self.subTest(shell=Path(shell).name):
                out = self.run_cases(shell)
                want = len(re.findall(r'^chk ', SHIM_CASES, re.M))
                self.assertIn(f'RESULT pass={want} fail=0', out, out)


if __name__ == '__main__':
    unittest.main()
