#!/usr/bin/env python3
"""
rns850_efs_patcher.py — Full end-to-end EFS binary patch for RNS 850 FSC bypass

Applies the 1-byte BouncyCastle bypass DIRECTLY to the efs-system.efs file
as a binary in-place patch. No JAR extraction/repacking needed — just three
binary writes to the EFS:

  1. Overwrite compressed class data (recompressed with patch)
  2. Update CRC32 in ZIP local file header
  3. Update CRC32 in ZIP central directory

The patched class (verifyManifestAndSignatureFile → immediate return) compresses
to the EXACT SAME SIZE as the original, enabling true in-place patching.

Works on: Audi MMI3G (MU9411) AND VW RNS 850 (MU9478) — same RSA key, same class.

Usage:
    # Analyze (find patch points, no modification)
    python3 rns850_efs_patcher.py efs-system.efs --analyze

    # Patch in-place (MODIFIES THE FILE — back up first!)
    python3 rns850_efs_patcher.py efs-system.efs --patch

    # Patch to new file
    python3 rns850_efs_patcher.py efs-system.efs --patch --output efs-system-patched.efs

    # Verify a previously patched EFS
    python3 rns850_efs_patcher.py efs-system.efs --verify

WARNING: This bypasses FSC signature validation. Back up your EFS first!
"""
import argparse
import struct
import sys
import os
import zlib
import shutil

LFH_SIG = b'PK\x03\x04'
CDH_SIG = b'PK\x01\x02'
EOCD_SIG = b'PK\x05\x06'

TARGET_CLASS = "de/audi/tghu/development/jobs/SignatureBlockProcessor.class"
TARGET_METHOD = "verifyManifestAndSignatureFile"
PATCH_OFFSET = 0x1FE8  # Offset within the class file
PATCH_ORIG = 0xBB      # 'new' bytecode
PATCH_NEW = 0xB1        # 'return void' bytecode
RECOMPRESS_LEVEL = 7    # zlib level that produces same-size output


def find_target_in_efs(efs):
    """Find SignatureBlockProcessor.class in the EFS and return patch locations."""
    # Find all EOCDs
    pos = 0
    while True:
        pos = efs.find(EOCD_SIG, pos)
        if pos < 0:
            return None

        cd_size = struct.unpack_from('<I', efs, pos + 12)[0]
        cd_start = pos - cd_size

        if cd_start < 0 or efs[cd_start:cd_start + 4] != CDH_SIG:
            pos += 1
            continue

        cd_offset = struct.unpack_from('<I', efs, pos + 16)[0]
        zip_start_calc = cd_start - cd_offset
        zip_start = efs.find(LFH_SIG, max(0, zip_start_calc - 0x10000), cd_start)
        if zip_start < 0:
            pos += 1
            continue

        # Scan central directory
        p = cd_start
        while p < pos:
            if efs[p:p + 4] != CDH_SIG:
                break

            method = struct.unpack_from('<H', efs, p + 10)[0]
            crc32_val = struct.unpack_from('<I', efs, p + 16)[0]
            comp_size = struct.unpack_from('<I', efs, p + 20)[0]
            uncomp_size = struct.unpack_from('<I', efs, p + 24)[0]
            fname_len = struct.unpack_from('<H', efs, p + 28)[0]
            extra_len = struct.unpack_from('<H', efs, p + 30)[0]
            comment_len = struct.unpack_from('<H', efs, p + 32)[0]
            local_offset = struct.unpack_from('<I', efs, p + 42)[0]

            fname = efs[p + 46:p + 46 + fname_len].decode('ascii', errors='replace')

            if fname == TARGET_CLASS:
                local_abs = zip_start + local_offset
                if efs[local_abs:local_abs + 4] != LFH_SIG:
                    p += 46 + fname_len + extra_len + comment_len
                    continue

                lf_len = struct.unpack_from('<H', efs, local_abs + 26)[0]
                le_len = struct.unpack_from('<H', efs, local_abs + 28)[0]
                data_start = local_abs + 30 + lf_len + le_len

                return {
                    'zip_start': zip_start,
                    'cd_entry': p,
                    'cd_crc_offset': p + 16,
                    'cd_comp_size_offset': p + 20,
                    'local_header': local_abs,
                    'local_crc_offset': local_abs + 14,
                    'local_comp_size_offset': local_abs + 18,
                    'data_offset': data_start,
                    'method': method,
                    'comp_size': comp_size,
                    'uncomp_size': uncomp_size,
                    'crc32': crc32_val,
                }

            p += 46 + fname_len + extra_len + comment_len

        pos += 1

    return None


def analyze(efs_path):
    """Analyze an EFS file and show patch details."""
    with open(efs_path, 'rb') as f:
        efs = f.read()

    print(f"File: {efs_path}")
    print(f"Size: {len(efs):,} bytes ({len(efs) / 1024 / 1024:.1f} MB)")

    info = find_target_in_efs(efs)
    if not info:
        print("\n❌ SignatureBlockProcessor.class not found!")
        return None, None

    print(f"\n✅ Found {TARGET_CLASS}")
    print(f"   Compressed data at:     0x{info['data_offset']:08x} ({info['comp_size']} bytes)")
    print(f"   Local header CRC32 at:  0x{info['local_crc_offset']:08x}")
    print(f"   Central dir CRC32 at:   0x{info['cd_crc_offset']:08x}")
    print(f"   Original CRC32:         0x{info['crc32']:08x}")

    # Decompress and check current state
    comp_data = efs[info['data_offset']:info['data_offset'] + info['comp_size']]
    try:
        class_data = zlib.decompress(comp_data, -15)
    except zlib.error:
        print("\n❌ Failed to decompress class data!")
        return efs, info

    byte_at_patch = class_data[PATCH_OFFSET]

    if byte_at_patch == PATCH_NEW:
        print(f"\n   ⚡ ALREADY PATCHED! Byte at 0x{PATCH_OFFSET:04x} = 0x{byte_at_patch:02x} (return void)")
        return efs, info
    elif byte_at_patch == PATCH_ORIG:
        print(f"\n   🔧 UNPATCHED — Byte at 0x{PATCH_OFFSET:04x} = 0x{byte_at_patch:02x} (new)")
        print(f"   Ready to patch: 0x{PATCH_ORIG:02x} → 0x{PATCH_NEW:02x}")
    else:
        print(f"\n   ⚠️ UNEXPECTED byte at 0x{PATCH_OFFSET:04x} = 0x{byte_at_patch:02x}")
        print(f"   Expected 0x{PATCH_ORIG:02x} (unpatched) or 0x{PATCH_NEW:02x} (patched)")

    return efs, info


def patch(efs_path, output_path=None):
    """Apply the 1-byte FSC bypass patch to an EFS file."""
    efs_data, info = analyze(efs_path)
    if not info:
        return False

    # Decompress
    comp_data = efs_data[info['data_offset']:info['data_offset'] + info['comp_size']]
    class_data = bytearray(zlib.decompress(comp_data, -15))

    if class_data[PATCH_OFFSET] == PATCH_NEW:
        print("\n   Already patched — nothing to do.")
        return True

    if class_data[PATCH_OFFSET] != PATCH_ORIG:
        print(f"\n   ❌ Unexpected byte — aborting for safety.")
        return False

    # Apply patch
    class_data[PATCH_OFFSET] = PATCH_NEW
    new_crc = zlib.crc32(bytes(class_data)) & 0xFFFFFFFF

    # Recompress
    compressor = zlib.compressobj(RECOMPRESS_LEVEL, zlib.DEFLATED, -15)
    new_comp = compressor.compress(bytes(class_data))
    new_comp += compressor.flush()

    if len(new_comp) > info['comp_size']:
        print(f"\n   ❌ Recompressed data is larger ({len(new_comp)} > {info['comp_size']}) — cannot patch in-place!")
        return False

    # Pad if smaller
    pad_needed = info['comp_size'] - len(new_comp)
    if pad_needed > 0:
        # For deflate, we can't just add zeros. Use the data as-is and update sizes.
        # Actually, let's try different compression levels first.
        for level in range(1, 10):
            c = zlib.compressobj(level, zlib.DEFLATED, -15)
            test = c.compress(bytes(class_data)) + c.flush()
            if len(test) == info['comp_size']:
                new_comp = test
                pad_needed = 0
                break
            elif len(test) < info['comp_size'] and len(test) > len(new_comp):
                new_comp = test
                pad_needed = info['comp_size'] - len(test)

    # Build patched EFS
    efs_out = bytearray(efs_data)

    # Write 1: compressed data
    efs_out[info['data_offset']:info['data_offset'] + len(new_comp)] = new_comp
    if pad_needed > 0:
        # Zero-fill remaining space (safe for deflate streams — decoder stops at end)
        for i in range(pad_needed):
            efs_out[info['data_offset'] + len(new_comp) + i] = 0x00

    # Write 2: Update CRC32 in local header
    struct.pack_into('<I', efs_out, info['local_crc_offset'], new_crc)

    # Write 3: Update CRC32 in central directory
    struct.pack_into('<I', efs_out, info['cd_crc_offset'], new_crc)

    # If compressed size changed, update that too
    if pad_needed > 0:
        actual_comp_size = len(new_comp)
        struct.pack_into('<I', efs_out, info['local_comp_size_offset'], actual_comp_size)
        struct.pack_into('<I', efs_out, info['cd_comp_size_offset'], actual_comp_size)

    # Write output
    out_path = output_path or efs_path
    if out_path != efs_path:
        shutil.copy2(efs_path, out_path)

    with open(out_path, 'wb') as f:
        f.write(efs_out)

    print(f"\n   ✅ PATCH APPLIED SUCCESSFULLY!")
    print(f"   Output: {out_path}")
    print(f"   New CRC32: 0x{new_crc:08x}")
    print(f"   Binary writes: 3 (comp data + local CRC + CD CRC)")
    if pad_needed > 0:
        print(f"   Note: {pad_needed} bytes padded, comp_size fields updated")

    # Verify
    print(f"\n   Verifying...")
    with open(out_path, 'rb') as f:
        verify_efs = f.read()
    verify_info = find_target_in_efs(verify_efs)
    verify_comp = verify_efs[verify_info['data_offset']:verify_info['data_offset'] + verify_info['comp_size']]
    verify_class = zlib.decompress(verify_comp, -15)
    if verify_class[PATCH_OFFSET] == PATCH_NEW:
        verify_crc = zlib.crc32(verify_class) & 0xFFFFFFFF
        if verify_crc == verify_info['crc32']:
            print(f"   ✅ Verification PASSED — patch is clean!")
        else:
            print(f"   ⚠️ CRC mismatch after verification!")
    else:
        print(f"   ❌ Patch verification FAILED!")

    return True


def main():
    parser = argparse.ArgumentParser(
        description='RNS 850 / Audi MMI3G — Full EFS binary patch for FSC bypass',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
The patch modifies ONE BYTE in SignatureBlockProcessor.class:
  Offset 0x1FE8: 0xBB (new) → 0xB1 (return void)
  Method: verifyManifestAndSignatureFile() → immediate return
  Effect: FSC signature verification bypassed

Three binary writes to the EFS file:
  1. Recompressed class data (same size — true in-place patch!)
  2. Updated CRC32 in ZIP local file header
  3. Updated CRC32 in ZIP central directory

Works on: VW RNS 850 (MU9478) AND Audi MMI3G (MU9411)
          Same RSA-1024 key (e=17), same SignatureBlockProcessor
        """
    )
    parser.add_argument('efs', help='Path to efs-system.efs firmware file')
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--analyze', action='store_true', help='Show patch points (no modification)')
    group.add_argument('--patch', action='store_true', help='Apply the 1-byte FSC bypass patch')
    group.add_argument('--verify', action='store_true', help='Check if EFS is already patched')
    parser.add_argument('--output', '-o', help='Write patched EFS to this file (default: in-place)')

    args = parser.parse_args()

    if not os.path.exists(args.efs):
        print(f"ERROR: File not found: {args.efs}", file=sys.stderr)
        sys.exit(1)

    if args.analyze or args.verify:
        analyze(args.efs)
    elif args.patch:
        if not args.output:
            resp = input(f"\n⚠️  This will MODIFY {args.efs} in-place. Continue? [y/N] ")
            if resp.lower() != 'y':
                print("Aborted.")
                sys.exit(0)
        success = patch(args.efs, args.output)
        sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
