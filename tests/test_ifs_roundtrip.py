"""Round-trip and layout tests for the IFS rebuild tools (issue #25).

A synthetic image built the way mkifs lays one out (every file on a 4 KiB
physical page, executables linked to run in place from there, a duplicate
entry, a symlink) stands in for real firmware, which can't be in the repo.

Set MMI3G_TEST_IFS=/path/to/ifs-root.ifs to also run the real-image
round trip (needs gcc, liblzo2 and libucl for inflate/repack).
"""
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest

REPO_ROOT = Path(__file__).resolve().parents[1]
TOOLS = REPO_ROOT / 'tools'
sys.path.insert(0, str(TOOLS))

import ifs_image as ifs  # noqa: E402
import verify_ifs  # noqa: E402

STARTUP_SIZE = 0x200
IMAGE_PADDR = 0x08010000
PAGE = 4096


def elf(etype, payload, data_mapped):
    """Minimal SH-4 ELF: code + data PT_LOADs; p_paddr filled in later."""
    ehdr = bytearray(0x34)
    ehdr[0:7] = b'\x7fELF\x01\x01\x01'
    struct.pack_into('<HHI', ehdr, 0x10, etype, 0x2a, 1)
    struct.pack_into('<I', ehdr, 0x1c, 0x34)                 # e_phoff
    struct.pack_into('<HHH', ehdr, 0x28, 0x34, 32, 2)        # ehsize, phentsize, phnum
    body = bytearray(ehdr + bytes(64) + payload)
    code_end = 0x74 + len(payload) // 2
    for i, (off, size, flags) in enumerate(((0, code_end, 5),
                                           (code_end, len(body) - code_end, 6))):
        struct.pack_into('<IIIIIIII', body, 0x34 + 32 * i, 1, off, 0x08040000 + off,
                         0, size, size, flags, 0x1000)
    return bytes(body), data_mapped


def link(content, phys, data_mapped):
    """Set p_paddr like mkifs: code mapped from the image, data as asked."""
    b = bytearray(content)
    for i in range(2):
        ph = 0x34 + 32 * i
        off = ifs.u32(b, ph + 4)
        mapped = i == 0 or data_mapped
        ifs.w32(b, ph + 12, phys + off if mapped else 0)
    return bytes(b)


def make_image():
    """(decompressed IFS bytes, {path: content as stored}) in mkifs's layout."""
    files = [
        ('proc/boot/procnto', *elf(2, b'K' * 3000, True)),
        ('proc/boot/.script', b'#script\n' * 40, None),
        ('bin/tool', *elf(2, b'T' * 5000, False)),
        ('bin/dup', b'same bytes\n' * 30, None),
        ('lib/libx.so', *elf(3, b'L' * 2500, True)),
        ('etc/data.txt', b'data\n' * 999, None),
        ('bin/dup', b'same bytes\n' * 30, None),     # duplicate entry, like the MMI's
        ('etc/last.cfg', b'last=1\n', None),
    ]
    dirents, data, placed = [], bytearray(), {}
    ino = 0x80000002
    foff = PAGE - STARTUP_SIZE                       # first file on a physical page
    layout = []
    for path, content, data_mapped in files:
        if data_mapped is not None:
            content = link(content, IMAGE_PADDR + STARTUP_SIZE + foff, data_mapped)
        layout.append((path, foff, content))
        placed[path] = content
        foff = ifs.align(foff + len(content), 4)
        foff += (PAGE - (STARTUP_SIZE + foff) % PAGE) % PAGE
    image_size = foff + 4                            # trailer right at a page

    def dirent_file(path, off, size, ino, mode=0o100755):
        pb = path.encode() + b'\x00'
        r = bytearray(ifs.align(32 + len(pb), 4))
        struct.pack_into('<HHIIIII', r, 0, len(r), 0, ino, mode, 0, 0, 0x5e000000)
        struct.pack_into('<II', r, 24, off, size)
        r[32:32 + len(pb)] = pb
        return bytes(r)

    for d in ('proc', 'proc/boot', 'bin', 'etc'):
        pb = d.encode() + b'\x00'
        r = bytearray(ifs.align(24 + len(pb), 4))
        struct.pack_into('<HHIIIII', r, 0, len(r), 0, ino, 0o040755, 0, 0, 0)
        r[24:24 + len(pb)] = pb
        dirents.append(bytes(r)); ino += 1
    boot_ino = script_ino = 0
    for path, off, content in layout:
        this = 0xe0000002 if path == 'proc/boot/procnto' else ino
        boot_ino = this if path == 'proc/boot/procnto' else boot_ino
        script_ino = this if path == 'proc/boot/.script' else script_ino
        dirents.append(dirent_file(path, off, len(content), this)); ino += 1
    # symlink usr/lib/ld.so -> /proc/boot/libc.so.2 (sym_offset from the path field)
    pb, tb = b'usr/lib/ld.so\x00', b'/proc/boot/libc.so.2\x00'
    r = bytearray(ifs.align(28 + len(pb) + len(tb), 4))
    struct.pack_into('<HHIIIIIHH', r, 0, len(r), 0, ino, 0o120777, 0, 0, 0, len(pb), len(tb) - 1)
    r[28:28 + len(pb)] = pb
    r[28 + len(pb):28 + len(pb) + len(tb)] = tb
    dirents.append(bytes(r))

    blob = b''.join(dirents) + b'\x00\x00'
    dir_offset = 0x5c
    imagefs = bytearray(image_size)
    imagefs[0:7] = b'imagefs'
    imagefs[7] = 4
    struct.pack_into('<IIIIIIIII', imagefs, 8, image_size, ifs.align(dir_offset + len(blob), 4),
                     dir_offset, boot_ino, 0, 0, 0, script_ino, 0)
    imagefs[88:90] = b'/\x00'
    imagefs[dir_offset:dir_offset + len(blob)] = blob
    for path, off, content in layout:
        imagefs[off:off + len(content)] = content
    ifs.set_checksum_word(imagefs, 0, image_size)

    st = bytearray(STARTUP_SIZE)
    struct.pack_into('<IHBBHH', st, 0, ifs.STARTUP_SIG, 1, 0x09, 0, 0x100, 0x2a)
    struct.pack_into('<IIIIIIIII', st, 12, 0x88013000, 0x80000000, IMAGE_PADDR, IMAGE_PADDR,
                     STARTUP_SIZE + image_size, STARTUP_SIZE, 0x12345678, 0, image_size)
    st[0x100:0x110] = b'startup code....'
    ifs.fix_startup_checksum(st)
    return bytes(st) + bytes(imagefs), placed


def verify_bytes(data):
    r = verify_ifs.Report('test')
    verify_ifs.verify_decompressed(data, r)
    return r


class IfsImageTests(unittest.TestCase):
    def setUp(self):
        self.orig, self.files = make_image()
        self.tmp = Path(tempfile.mkdtemp())

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def imagefs(self, data):
        return data[STARTUP_SIZE:]

    def test_synthetic_image_is_valid(self):
        self.assertEqual(verify_bytes(self.orig).errors, 0)

    def test_unchanged_build_keeps_the_imagefs_byte_for_byte(self):
        out = ifs.IfsImage(self.orig).build()
        self.assertEqual(self.imagefs(out), self.imagefs(self.orig))
        self.assertEqual(ifs.sum32(out, 0, STARTUP_SIZE), 0)
        self.assertEqual(verify_bytes(out).errors, 0)

    def test_duplicates_and_symlink_survive(self):
        img = ifs.IfsImage(ifs.IfsImage(self.orig).build())
        self.assertEqual(len(img.find('bin/dup')), 2)
        link = img.find('usr/lib/ld.so')[0]
        self.assertEqual(link.target, '/proc/boot/libc.so.2')

    def test_same_size_replacement_is_in_place(self):
        img = ifs.IfsImage(self.orig)
        before = {e.path: e.foff for e in img.files()}
        img.replace('etc/data.txt', b'DATA\n' * 999)
        out = img.build()
        after = {e.path: e.foff for e in ifs.IfsImage(out).files()}
        self.assertEqual(before, after)
        self.assertEqual(len(out), len(self.orig))
        self.assertEqual(verify_bytes(out).errors, 0)

    def test_growing_a_file_shifts_later_files_by_pages_and_relinks_elfs(self):
        img = ifs.IfsImage(self.orig)
        old = [(e.path, e.foff) for e in img.files()]
        tool_off = img.find('bin/tool')[0].foff
        img.replace('bin/tool', self.files['bin/tool'] + b'\x00' * 9000)
        out = img.build()
        new = ifs.IfsImage(out)
        for e, (path, off) in zip(new.files(), old):
            self.assertEqual(e.path, path)
            if off <= tool_off:
                self.assertEqual(e.foff, off, path)                 # before it: untouched
            else:
                self.assertGreater(e.foff, off, path)
                self.assertEqual((e.foff - off) % PAGE, 0, path)
        lib = new.find('lib/libx.so')[0]
        segs = new._load_segments(new.file_data(lib))
        self.assertEqual(segs[0][2], new.phys(lib.foff) + segs[0][1])
        self.assertEqual(segs[1][2], new.phys(lib.foff) + segs[1][1])   # data stays mapped
        tool = new.find('bin/tool')[0]
        tsegs = new._load_segments(new.file_data(tool))
        self.assertEqual(tsegs[1][2], 0)                                  # data stays copied
        self.assertEqual(verify_bytes(out).errors, 0)
        self.assertEqual(ifs.u32(out, ifs.SH_RAM_SIZE), len(out))

    def test_toolchain_elf_gets_linked_for_its_slot(self):
        """A freshly compiled ELF (p_paddr = vaddr) must be linked on the way in."""
        raw, _ = elf(2, b'N' * 100, False)
        b = bytearray(raw)
        for i in range(2):
            ifs.w32(b, 0x34 + 32 * i + 12, 0x08040000)
        img = ifs.IfsImage(self.orig)
        img.replace('bin/tool', bytes(b))
        self.assertEqual(verify_bytes(img.build()).errors, 0)

    def test_add_and_remove(self):
        img = ifs.IfsImage(self.orig)
        img.add_file('opt/new/hello.txt', b'hi\n')
        img.remove('etc/last.cfg')
        out = ifs.IfsImage(img.build())
        self.assertEqual(out.file_data(out.find('opt/new/hello.txt')[0]), b'hi\n')
        self.assertFalse(out.find('etc/last.cfg'))
        self.assertTrue(out.has_dir('opt/new'))
        self.assertEqual(verify_bytes(img.build()).errors, 0)

    def test_verify_catches_the_old_repacking_layout(self):
        """Moving files without relinking (what the old tools did) must fail."""
        img = ifs.IfsImage(self.orig)
        e = img.find('bin/tool')[0]
        data = img.file_data(e)
        new_off = img._alloc(len(data))
        img.imagefs[new_off:new_off + len(data)] = data          # moved, not relinked
        e.set_file(new_off, len(data))
        r = verify_bytes(img.build())
        self.assertGreater(r.errors, 0)

    def test_verify_catches_a_stale_startup_checksum(self):
        bad = bytearray(self.orig)
        ifs.w32(bad, ifs.SH_STORED_SIZE, 0x1234)
        self.assertGreater(verify_bytes(bytes(bad)).errors, 0)

    def run_tool(self, *args):
        return subprocess.run([sys.executable, *map(str, args)], capture_output=True, text=True)

    def test_build_ifs_unchanged_tree_round_trips(self):
        ref = self.tmp / 'ref.ifs'
        ref.write_bytes(self.orig)
        tree = self.tmp / 'tree'
        for path, content in self.files.items():
            (tree / path).parent.mkdir(parents=True, exist_ok=True)
            (tree / path).write_bytes(content)
        out = self.tmp / 'out.ifs'
        res = self.run_tool(TOOLS / 'build_ifs.py', '--reference', ref, '--tree', tree,
                            '--output', out)
        self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
        self.assertIn('0 replaced, 0 added, 0 removed', res.stdout)
        self.assertEqual(self.imagefs(out.read_bytes()), self.imagefs(self.orig))

    def test_patch_ifs_cli(self):
        ref = self.tmp / 'ref.ifs'
        ref.write_bytes(self.orig)
        newfile = self.tmp / 'data.txt'
        newfile.write_bytes(b'x' * 20000)
        out = self.tmp / 'out.ifs'
        res = self.run_tool(TOOLS / 'patch_ifs.py', ref, out,
                            '--replace', f'/etc/data.txt={newfile}')
        self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
        self.assertEqual(verify_bytes(out.read_bytes()).errors, 0)
        res = self.run_tool(TOOLS / 'verify_ifs.py', out)
        self.assertEqual(res.returncode, 0, res.stdout)

    def test_extract_lists_full_symlink_targets(self):
        ref = self.tmp / 'ref.ifs'
        ref.write_bytes(self.orig)
        res = self.run_tool(TOOLS / 'extract_qnx_ifs.py', ref, self.tmp / 'x', '--list')
        self.assertIn('-> /proc/boot/libc.so.2', res.stdout)


def compressor_available():
    return shutil.which('gcc') is not None and any(
        Path(p, 'lzo', 'lzo1x.h').exists() for p in ('/usr/include', '/usr/local/include'))


@unittest.skipUnless(compressor_available(), 'needs gcc + liblzo2-dev')
class CompressorTests(unittest.TestCase):
    def test_repack_writes_trailer_and_startup_checksum(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            dec = tmp / 'dec.ifs'
            dec.write_bytes(ifs.IfsImage(make_image()[0]).build())
            first, second = tmp / 'a.ifs', tmp / 'b.ifs'
            subprocess.run([sys.executable, str(TOOLS / 'repack_ifs.py'), str(dec), str(first)],
                           check=True, capture_output=True)
            d = first.read_bytes()
            r = verify_ifs.Report('compressed')
            verify_ifs.verify_compressed(d, r)
            self.assertEqual(r.errors, 0)
            res = subprocess.run([sys.executable, str(TOOLS / 'repack_ifs.py'), str(dec),
                                  str(second), '--reference', str(first)],
                                 capture_output=True, text=True)
            self.assertIn('byte-identical', res.stdout)
            self.assertEqual(first.read_bytes(), second.read_bytes())
        finally:
            shutil.rmtree(tmp, ignore_errors=True)


@unittest.skipUnless(os.environ.get('MMI3G_TEST_IFS'), 'set MMI3G_TEST_IFS to a real ifs-root.ifs')
class RealImageRoundTrip(unittest.TestCase):
    def test_inflate_build_repack_is_byte_identical(self):
        src = Path(os.environ['MMI3G_TEST_IFS'])
        tmp = Path(tempfile.mkdtemp())
        try:
            run = lambda *a: subprocess.run([sys.executable, *map(str, a)], check=True,
                                            capture_output=True)
            run(TOOLS / 'inflate_ifs.py', src, '-o', tmp / 'dec.ifs', '--no-container-fallback')
            run(TOOLS / 'inflate_ifs.py', src, '--extract', tmp / 'tree', '--no-container-fallback')
            run(TOOLS / 'build_ifs.py', '--reference', tmp / 'dec.ifs', '--tree', tmp / 'tree',
                '--output', tmp / 'built.ifs')
            run(TOOLS / 'repack_ifs.py', tmp / 'built.ifs', tmp / 'rep.ifs', '--reference', src)
            self.assertEqual((tmp / 'rep.ifs').read_bytes(), src.read_bytes())
        finally:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    unittest.main()
