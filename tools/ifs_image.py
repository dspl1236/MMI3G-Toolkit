#!/usr/bin/env python3
"""
ifs_image.py — layout-preserving editing of a decompressed QNX IFS.

Shared by patch_ifs.py and build_ifs.py. Pure Python, no dependencies.

Why "layout-preserving": mkifs links every executable in the image to run
in place (XIP). Each ELF's PT_LOAD p_paddr is the physical address of that
file inside the image (image_paddr + startup_size + file_offset), and every
file starts on a 4 KiB physical page. Moving a file without fixing its ELF
headers makes procnto, libc and every program load code from the wrong
address. So unchanged files are never moved here:

  * a replacement that fits the file's current slot is written in place;
  * a bigger one is moved to the end of the image, on a page boundary;
  * an ELF that is written (replaced, moved or added) gets its PT_LOAD
    p_paddr set for its new spot, following the file it replaces;
  * new files go to the end the same way; their dirents use the free space
    between the directory and the first file;
  * every other dirent (duplicates, directories, symlinks) is kept verbatim.

Checksums the boot chain verifies (all are plain uint32 sums that must be 0):

  * startup section  [0, startup_size)      — last word is the checksum;
    it covers the startup_header, so it must be redone whenever
    stored_size / imagefs_size / ram_size / flags1 change
  * imagefs          [startup_size, +image_size) — last word is the checksum
  * compressed only: [startup_size, stored_size) — the LZO chunk stream,
    its 0x0000 end marker, zero padding to 4 bytes, then a 4-byte trailer
    (written by qnx_ifs_compress / checked by the IPL before it boots)
"""
import struct

IMAGE_SIG = b'imagefs'
STARTUP_SIG = 0x00ff7eeb
S_IFMT = 0xf000
S_IFREG = 0x8000
S_IFDIR = 0x4000
S_IFLNK = 0xa000
PAGE = 4096

# startup_header field offsets
SH_FLAGS1 = 0x06
SH_IMAGE_PADDR = 0x14
SH_RAM_SIZE = 0x1c
SH_STARTUP_SIZE = 0x20
SH_STORED_SIZE = 0x24
SH_IMAGEFS_SIZE = 0x2c
FLAGS1_COMPRESS_MASK = 0x1c


def u16(b, o): return struct.unpack_from('<H', b, o)[0]
def u32(b, o): return struct.unpack_from('<I', b, o)[0]
def w16(b, o, v): struct.pack_into('<H', b, o, v)
def w32(b, o, v): struct.pack_into('<I', b, o, v & 0xffffffff)


def align(v, a):
    return (v + a - 1) & ~(a - 1)


def sum32(data, start, length):
    """uint32 sum of `length` bytes (a multiple of 4) at `start`."""
    if length % 4:
        raise ValueError('sum32 length %d is not a multiple of 4' % length)
    total = sum(struct.unpack_from('<%dI' % (length // 4), data, start))
    return total & 0xffffffff


def set_checksum_word(buf, start, length):
    """Make the uint32 sum of buf[start:start+length] zero via its last word."""
    w32(buf, start + length - 4, 0)
    w32(buf, start + length - 4, -sum32(buf, start, length))


def fix_startup_checksum(buf):
    set_checksum_word(buf, 0, u32(buf, SH_STARTUP_SIZE))


def parse_symlink(data, off, rec_size):
    """(path, target) of a symlink dirent. sym_offset counts from the path
    field (record + 28), not from the start of the record."""
    sym_offset = u16(data, off + 24)
    sym_size = u16(data, off + 26)
    pend = data.find(b'\x00', off + 28, off + rec_size)
    path = data[off + 28:pend if pend >= 0 else off + rec_size]
    t0 = off + 28 + sym_offset
    target = data[t0:t0 + sym_size]
    return path.decode('utf-8', 'replace'), target.decode('utf-8', 'replace')


class Entry:
    __slots__ = ('raw', 'ftype', 'path', 'ino', 'mode', 'foff', 'fsize', 'target')

    def __init__(self, raw):
        self.raw = bytearray(raw)
        self.ino = u32(raw, 4)
        self.mode = u32(raw, 8)
        self.ftype = self.mode & S_IFMT
        self.foff = self.fsize = None
        self.target = None
        n = len(raw)
        if self.ftype == S_IFREG:
            self.foff, self.fsize = u32(raw, 24), u32(raw, 28)
            start = 32
        elif self.ftype == S_IFDIR:
            start = 24
        elif self.ftype == S_IFLNK:
            self.path, self.target = parse_symlink(bytes(raw), 0, n)
            return
        else:
            start = 32
        end = raw.find(b'\x00', start, n)
        self.path = bytes(raw[start:end if end >= 0 else n]).decode('utf-8', 'replace')

    def set_file(self, foff, fsize):
        self.foff, self.fsize = foff, fsize
        w32(self.raw, 24, foff)
        w32(self.raw, 28, fsize)


def norm_path(p):
    return p.replace('\\', '/').strip('/')


class IfsImage:
    """A decompressed IFS: startup section + one imagefs."""

    def __init__(self, data):
        data = bytes(data)
        if u32(data, 0) != STARTUP_SIG:
            raise ValueError('no QNX startup signature')
        self.startup_size = u32(data, SH_STARTUP_SIZE)
        ip = self.startup_size
        if data[ip:ip + 7] != IMAGE_SIG:
            raise ValueError('no imagefs at startup_size; is this decompressed? '
                             '(run inflate_ifs.py first)')
        self.startup = bytearray(data[:ip])
        self.image_size = u32(data, ip + 8)
        self.hdr_dir_size = u32(data, ip + 12)
        self.dir_offset = u32(data, ip + 16)
        self.imagefs = bytearray(data[ip:ip + self.image_size])
        if len(self.imagefs) != self.image_size:
            raise ValueError('image truncated: imagefs needs %d bytes' % self.image_size)
        self.entries = []
        off = self.dir_offset
        while off < self.hdr_dir_size:
            rs = u16(self.imagefs, off)
            if rs == 0:
                break
            self.entries.append(Entry(self.imagefs[off:off + rs]))
            off += rs
        self.dir_end = off            # where the 0x0000 terminator sits
        # mkifs ends hdr_dir_size 4-byte aligned after the 0x0000 terminator;
        # keep whatever extra the source image used past that point
        self.dir_tail = self.hdr_dir_size - (off + 2)
        files = self.files()
        self.data_start = min((e.foff for e in files), default=align(self.hdr_dir_size, 4))
        self.orig_tail = self.image_size - 4   # trailer offset in the source image

    # ---- queries ----
    def files(self):
        return [e for e in self.entries if e.ftype == S_IFREG]

    def find(self, path):
        path = norm_path(path)
        return [e for e in self.entries if e.path == path]

    def file_data(self, e):
        return bytes(self.imagefs[e.foff:e.foff + e.fsize])

    def phys(self, foff):
        """Physical address of an imagefs offset."""
        return u32(self.startup, SH_IMAGE_PADDR) + self.startup_size + foff

    def data_end(self):
        """End of the last file's data (before the trailer)."""
        return max((e.foff + e.fsize for e in self.files()), default=self.data_start)

    def slot_end(self, e):
        """First offset after e's data that something else uses."""
        later = [f.foff for f in self.files() if f.foff > e.foff]
        return min(later) if later else self.image_size - 4

    # ---- edits ----
    def _alloc(self, size):
        """Page-aligned (physical) offset at the end of the image."""
        end = max(self.data_end(), self.image_size - 4)
        pad = (PAGE - (self.startup_size + end) % PAGE) % PAGE
        off = end + pad
        need = off + size
        if need > len(self.imagefs):
            self.imagefs.extend(b'\x00' * (need - len(self.imagefs)))
        return off

    def _load_segments(self, b):
        """[(phdr offset, p_offset, p_paddr, p_flags)] of an ELF's PT_LOADs."""
        if b[:4] != b'\x7fELF' or len(b) < 0x34:
            return None
        phoff, phentsize, phnum = u32(b, 0x1c), u16(b, 0x2a), u16(b, 0x2c)
        segs = []
        for i in range(phnum):
            ph = phoff + i * phentsize
            if ph + 32 <= len(b) and u32(b, ph) == 1:          # PT_LOAD
                segs.append((ph, u32(b, ph + 4), u32(b, ph + 12), u32(b, ph + 24)))
        return segs

    def _xip_fixup(self, content, foff, template=None, template_off=None):
        """Set an ELF's PT_LOAD p_paddr the way mkifs does for a file at `foff`:
        a segment the kernel maps straight from the image gets
        p_paddr = phys(foff) + p_offset, a segment it copies gets 0.
        Which segments are mapped is taken from `template` (the file this one
        replaces); without one: code mapped, data copied for executables,
        data mapped for shared objects (the image's own defaults)."""
        segs = self._load_segments(content)
        if not segs:
            return content
        b = bytearray(content)
        tsegs = self._load_segments(template) if template else None
        if tsegs and len(tsegs) == len(segs):
            mapped = [paddr != 0 and template_off is not None
                      and paddr == self.phys(template_off) + off
                      for (_ph, off, paddr, _fl) in tsegs]
            if not any(mapped):          # template was not an XIP file: copy its choice
                mapped = [paddr != 0 for (_ph, _off, paddr, _fl) in tsegs]
        else:
            is_dyn = u16(b, 0x10) == 3
            mapped = [bool(fl & 1) or is_dyn for (_ph, _off, _pa, fl) in segs]
        for (ph, off, _paddr, _fl), m in zip(segs, mapped):
            w32(b, ph + 12, self.phys(foff) + off if m else 0)
        return bytes(b)

    def replace(self, path, content):
        """Replace every dirent of `path` with `content`. Returns where it went."""
        hits = [e for e in self.find(path) if e.ftype == S_IFREG]
        if not hits:
            raise KeyError('not a file in the image: %s' % path)
        shifted = 0
        for e in hits:
            old_off, old_size = e.foff, e.fsize
            old = self.file_data(e)
            slot_end = self.slot_end(e)
            if old_off + len(content) > slot_end:
                # grow the slot: shift everything after it by whole pages
                delta = align(old_off + len(content) - slot_end, PAGE)
                self._shift_after(slot_end, delta)
                shifted += delta
            self.imagefs[old_off:old_off + old_size] = b'\x00' * old_size
            data = self._xip_fixup(content, old_off, old, old_off)
            self.imagefs[old_off:old_off + len(data)] = data
            e.set_file(old_off, len(data))
        if shifted:
            return 'in place, later files shifted by %d KiB' % (shifted // 1024)
        return 'in place'

    def _shift_after(self, at, delta):
        """Insert `delta` bytes (a multiple of PAGE) at imagefs offset `at` and
        move every file at or after it, re-linking moved ELFs for their new
        address. Keeps every file on its page, like mkifs would lay them out."""
        assert delta % PAGE == 0
        later = [f for f in self.files() if f.foff >= at]
        olds = {id(f): self.file_data(f) for f in later}
        self.imagefs[at:at] = b'\x00' * delta
        for f in later:
            old_off = f.foff
            new_off = old_off + delta
            data = self._xip_fixup(olds[id(f)], new_off, olds[id(f)], old_off)
            self.imagefs[new_off:new_off + len(data)] = data
            f.set_file(new_off, len(data))
        self.image_size += delta
        self.orig_tail += delta

    def differs(self, path, content):
        """True if writing `content` to `path` would change the image. An
        extracted ELF carries the load addresses of the copy it came from, so
        compare after linking it for each entry's own position."""
        for e in self.find(path):
            if e.ftype != S_IFREG:
                continue
            old = self.file_data(e)
            if self._xip_fixup(content, e.foff, old, e.foff) != old:
                return True
        return False

    def remove(self, path):
        hits = self.find(path)
        if not hits:
            raise KeyError('not in the image: %s' % path)
        for e in hits:
            self.entries.remove(e)

    def add_file(self, path, content, mode=S_IFREG | 0o755, uid=0, gid=0, mtime=0):
        path = norm_path(path)
        if self.find(path):
            raise KeyError('already in the image: %s' % path)
        parent = path.rsplit('/', 1)[0] if '/' in path else ''
        if parent and not self.has_dir(parent):
            self.add_dir(parent)
        ino = self._next_ino()
        pb = path.encode('utf-8') + b'\x00'
        raw = bytearray(align(32 + len(pb), 4))
        w16(raw, 0, len(raw)); w32(raw, 4, ino); w32(raw, 8, mode)
        w32(raw, 12, gid); w32(raw, 16, uid); w32(raw, 20, mtime)
        raw[32:32 + len(pb)] = pb
        e = Entry(raw)
        off = self._alloc(len(content))
        content = self._xip_fixup(content, off)
        self.imagefs[off:off + len(content)] = content
        e.set_file(off, len(content))
        self.entries.append(e)

    def add_dir(self, path, mode=S_IFDIR | 0o755):
        path = norm_path(path)
        if self.has_dir(path):
            return
        parent = path.rsplit('/', 1)[0] if '/' in path else ''
        if parent and not self.has_dir(parent):
            self.add_dir(parent)
        pb = path.encode('utf-8') + b'\x00'
        raw = bytearray(align(24 + len(pb), 4))
        w16(raw, 0, len(raw)); w32(raw, 4, self._next_ino()); w32(raw, 8, mode)
        raw[24:24 + len(pb)] = pb
        self.entries.append(Entry(raw))

    def has_dir(self, path):
        """True if `path` is a directory entry or an implicit parent of one
        (mkifs often writes no entry for parents such as mnt/ or proc/)."""
        path = norm_path(path)
        return any((e.path == path and e.ftype == S_IFDIR) or e.path.startswith(path + '/')
                   for e in self.entries)

    def _next_ino(self):
        used = [e.ino & 0x0fffffff for e in self.entries]
        return 0x80000000 | (max(used, default=0) + 1)

    # ---- output ----
    def build(self):
        """The decompressed IFS bytes, with all headers and checksums redone."""
        dirents = b''.join(bytes(e.raw) for e in self.entries) + b'\x00\x00'
        dir_end = self.dir_offset + len(dirents)
        if dir_end > self.data_start:
            raise ValueError('directory needs %d bytes but only %d fit before the first '
                             'file; add fewer/shorter paths'
                             % (dir_end - self.dir_offset, self.data_start - self.dir_offset))
        img = self.imagefs
        img[self.dir_offset:self.data_start] = b'\x00' * (self.data_start - self.dir_offset)
        img[self.dir_offset:dir_end] = dirents
        if self.hdr_dir_size % 4 == 0:
            hdr_dir_size = align(dir_end, 4)
        else:
            hdr_dir_size = dir_end + self.dir_tail

        # image end: after the data, padded so the trailer lands where mkifs puts it
        end = max(self.data_end(), self.orig_tail)
        pad = (PAGE - (self.startup_size + end) % PAGE) % PAGE
        image_size = end + pad + 4
        if image_size < len(img):
            del img[image_size:]
        else:
            img.extend(b'\x00' * (image_size - len(img)))
        w32(img, 8, image_size)
        w32(img, 12, hdr_dir_size)
        set_checksum_word(img, 0, image_size)

        st = bytearray(self.startup)
        old_imagefs = u32(st, SH_IMAGEFS_SIZE)
        w32(st, SH_IMAGEFS_SIZE, image_size)
        ram = u32(st, SH_RAM_SIZE)
        w32(st, SH_RAM_SIZE, ram + max(0, image_size - old_imagefs))
        st[SH_FLAGS1] &= ~FLAGS1_COMPRESS_MASK & 0xff       # this output is not compressed
        w32(st, SH_STORED_SIZE, len(st) + image_size)
        fix_startup_checksum(st)
        self.image_size = image_size
        return bytes(st) + bytes(img)


def load(path):
    with open(path, 'rb') as f:
        return IfsImage(f.read())
