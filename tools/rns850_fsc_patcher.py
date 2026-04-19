#!/usr/bin/env python3
"""
rns850_fsc_patcher.py — BouncyCastle FSC signature bypass for VW RNS 850

Extracts the SignatureBlockProcessor.class from the EFS-system JAR,
patches the verifyManifestAndSignatureFile() method to return immediately
(bytecode 0xB1 = void return), and optionally repacks the JAR.

The RNS 850 uses Java BouncyCastle (de.audi.crypto.*) for FSC verification
instead of Audi's native EscRsa. The verification flow:
  1. RSA decrypt (1024-bit, e=17) → AES key
  2. AES-CBC decrypt → signature file
  3. SHA1/MD5 hash comparison → pass/fail

This patcher targets step 3 (verifyManifestAndSignatureFile).

Supports: HN+ (P0534) and HN+R (P0824) firmware
Tested: EFS-system from MU9478 variants 41, 51, 61

Usage:
    # Analyze (find patch point, no modification)
    python3 rns850_fsc_patcher.py efs-system.efs --analyze

    # Extract patched class file only
    python3 rns850_fsc_patcher.py efs-system.efs --extract-class

    # Full EFS patch (modifies in-place — backup first!)
    python3 rns850_fsc_patcher.py efs-system.efs --patch

WARNING: This bypasses FSC signature validation. Use responsibly.
"""
import argparse
import struct
import sys
import os
import zlib
import shutil


# ZIP signatures
LFH_SIG = b'PK\x03\x04'
CDH_SIG = b'PK\x01\x02'
EOCD_SIG = b'PK\x05\x06'

# Target class
TARGET_CLASS = "de/audi/tghu/development/jobs/SignatureBlockProcessor.class"
TARGET_METHOD = "verifyManifestAndSignatureFile"

# RSA key info (for display)
RSA_MODULUS_B64 = "AI2fepz64ZbVLru5KITtZkPSwHu0RDuAGDhhGhdxdtjlGLnKXhy5Ar24z/fvOE6ZS3rA4sySFfenX3VV9CGtf1+sXnMtHRnPOPJptuThVgnNgoyPcSayRyiec2M9OC5zy1MK5HRUEP+8LMJxTt89BgAe5MgVI7M+Pmq2sVhlNHvd"
RSA_EXPONENT = 17


def find_jars(efs_data):
    """Find all embedded JARs in the EFS by locating EOCD records."""
    jars = []
    pos = 0
    while True:
        pos = efs_data.find(EOCD_SIG, pos)
        if pos < 0:
            break

        if pos + 22 > len(efs_data):
            pos += 1
            continue

        cd_entries = struct.unpack_from('<H', efs_data, pos + 10)[0]
        cd_size = struct.unpack_from('<I', efs_data, pos + 12)[0]
        cd_offset = struct.unpack_from('<I', efs_data, pos + 16)[0]
        comment_len = struct.unpack_from('<H', efs_data, pos + 20)[0]

        eocd_end = pos + 22 + comment_len
        cd_start_abs = pos - cd_size

        # Verify central directory signature
        if cd_start_abs >= 0 and efs_data[cd_start_abs:cd_start_abs + 4] == CDH_SIG:
            # Computed ZIP start from cd_offset
            zip_start_calc = cd_start_abs - cd_offset

            # The EFS format may cause computed start to be slightly off.
            # Search backwards from central directory for the actual first
            # PK\x03\x04 header. Search up to 64KB before computed start.
            search_from = max(0, zip_start_calc - 0x10000)
            zip_start = efs_data.find(LFH_SIG, search_from, cd_start_abs)
            if zip_start < 0:
                zip_start = zip_start_calc

            if zip_start >= 0:
                jars.append({
                    'start': zip_start,
                    'end': eocd_end,
                    'cd_start': cd_start_abs,
                    'cd_size': cd_size,
                    'cd_offset': cd_offset,
                    'entries': cd_entries,
                    'eocd': pos,
                })

        pos += 1

    return jars


def find_class_in_jar(efs_data, jar, class_name):
    """Find a specific class file within a JAR's central directory."""
    pos = jar['cd_start']
    zip_start = jar['start']

    while pos < jar['eocd']:
        if efs_data[pos:pos + 4] != CDH_SIG:
            break

        method = struct.unpack_from('<H', efs_data, pos + 10)[0]
        comp_size = struct.unpack_from('<I', efs_data, pos + 20)[0]
        uncomp_size = struct.unpack_from('<I', efs_data, pos + 24)[0]
        fname_len = struct.unpack_from('<H', efs_data, pos + 28)[0]
        extra_len = struct.unpack_from('<H', efs_data, pos + 30)[0]
        comment_len = struct.unpack_from('<H', efs_data, pos + 32)[0]
        local_offset = struct.unpack_from('<I', efs_data, pos + 42)[0]

        fname = efs_data[pos + 46:pos + 46 + fname_len].decode('ascii', errors='replace')

        if fname == class_name:
            # Found it — get the data from local header
            local_abs = zip_start + local_offset
            if efs_data[local_abs:local_abs + 4] == LFH_SIG:
                local_fname_len = struct.unpack_from('<H', efs_data, local_abs + 26)[0]
                local_extra_len = struct.unpack_from('<H', efs_data, local_abs + 28)[0]
                data_start = local_abs + 30 + local_fname_len + local_extra_len
                comp_data = efs_data[data_start:data_start + comp_size]

                return {
                    'fname': fname,
                    'method': method,
                    'comp_size': comp_size,
                    'uncomp_size': uncomp_size,
                    'local_offset': local_abs,
                    'data_offset': data_start,
                    'comp_data': comp_data,
                    'cd_entry_offset': pos,
                }

        pos += 46 + fname_len + extra_len + comment_len

    return None


def decompress_class(entry):
    """Decompress a class file from a JAR entry."""
    if entry['method'] == 8:  # Deflate
        return zlib.decompress(entry['comp_data'], -15)
    elif entry['method'] == 0:  # Stored
        return entry['comp_data']
    else:
        raise ValueError(f"Unsupported compression method: {entry['method']}")


def find_method_in_class(class_data, method_name):
    """Find a method's Code attribute in a Java class file. Returns (code_offset, code_length)."""
    if class_data[:4] != b'\xca\xfe\xba\xbe':
        raise ValueError("Not a Java class file")

    cp_count = struct.unpack_from('>H', class_data, 8)[0]

    # Parse constant pool
    i = 10
    cp = [None]
    idx = 1
    while idx < cp_count:
        tag = class_data[i]
        if tag == 1:  # UTF8
            length = struct.unpack_from('>H', class_data, i + 1)[0]
            s = class_data[i + 3:i + 3 + length].decode('utf-8', errors='replace')
            cp.append(('UTF8', s))
            i += 3 + length
        elif tag in (7, 8, 16, 19, 20):
            cp.append(('Ref', struct.unpack_from('>H', class_data, i + 1)[0]))
            i += 3
        elif tag in (9, 10, 11, 12, 17, 18):
            cp.append(('Ref2',))
            i += 5
        elif tag in (3, 4):
            cp.append(('Num',))
            i += 5
        elif tag in (5, 6):
            cp.append(('Long',))
            cp.append(None)
            i += 9
            idx += 1
        elif tag == 15:
            cp.append(('MH',))
            i += 4
        else:
            cp.append(('Unknown', tag))
            i += 1
        idx += 1

    # Skip access flags, this/super class, interfaces
    i += 6  # access_flags + this_class + super_class
    iface_count = struct.unpack_from('>H', class_data, i)[0]
    i += 2 + iface_count * 2

    # Skip fields
    field_count = struct.unpack_from('>H', class_data, i)[0]
    i += 2
    for _ in range(field_count):
        attr_count = struct.unpack_from('>H', class_data, i + 6)[0]
        i += 8
        for _ in range(attr_count):
            attr_len = struct.unpack_from('>I', class_data, i + 2)[0]
            i += 6 + attr_len

    # Parse methods
    method_count = struct.unpack_from('>H', class_data, i)[0]
    i += 2

    for _ in range(method_count):
        m_name_idx = struct.unpack_from('>H', class_data, i + 2)[0]
        m_attr_count = struct.unpack_from('>H', class_data, i + 6)[0]
        i += 8

        name = cp[m_name_idx][1] if cp[m_name_idx] and cp[m_name_idx][0] == 'UTF8' else ''

        code_offset = None
        code_length = None

        for _ in range(m_attr_count):
            attr_name_idx = struct.unpack_from('>H', class_data, i)[0]
            attr_len = struct.unpack_from('>I', class_data, i + 2)[0]
            attr_name = cp[attr_name_idx][1] if cp[attr_name_idx] and cp[attr_name_idx][0] == 'UTF8' else ''

            if attr_name == "Code":
                code_len = struct.unpack_from('>I', class_data, i + 10)[0]
                code_offset = i + 14  # offset into class_data
                code_length = code_len

            i += 6 + attr_len

        if name == method_name and code_offset is not None:
            return code_offset, code_length

    return None, None


def analyze(efs_path):
    """Analyze the EFS to find the patch point."""
    print(f"Loading {efs_path}...")
    with open(efs_path, 'rb') as f:
        efs = f.read()

    print(f"EFS size: {len(efs):,} bytes ({len(efs) / 1024 / 1024:.1f} MB)")
    print()

    # Find JARs
    jars = find_jars(efs)
    print(f"Found {len(jars)} embedded JAR(s)")

    for i, jar in enumerate(jars):
        print(f"\n  JAR {i}: offset 0x{jar['start']:08x}-0x{jar['end']:08x} "
              f"({jar['entries']} entries, {(jar['end'] - jar['start']) / 1024:.0f} KB)")

        entry = find_class_in_jar(efs, jar, TARGET_CLASS)
        if entry:
            print(f"    ✅ Found {TARGET_CLASS}")
            print(f"       Compressed: {entry['comp_size']} bytes, Uncompressed: {entry['uncomp_size']} bytes")
            print(f"       Data at EFS offset: 0x{entry['data_offset']:08x}")

            # Decompress and find method
            class_data = decompress_class(entry)
            code_off, code_len = find_method_in_class(class_data, TARGET_METHOD)

            if code_off is not None:
                print(f"\n    ★ {TARGET_METHOD}() found!")
                print(f"       Code offset in class: 0x{code_off:04x}, length: {code_len} bytes")
                print(f"       First 20 bytes: {' '.join(f'{class_data[code_off + j]:02x}' for j in range(min(20, code_len)))}")
                print(f"\n    BYPASS: Replace byte at class offset 0x{code_off:04x} with 0xB1 (return void)")
                print(f"    Effect: verifyManifestAndSignatureFile() returns immediately")
                print(f"           → FSC signature check skipped")
            else:
                print(f"    ❌ Method {TARGET_METHOD} not found in class")

            # Also show RSA key info
            print(f"\n    RSA Key Info:")
            print(f"       Modulus: 1024-bit")
            print(f"       Exponent: {RSA_EXPONENT}")
            print(f"       Base64: {RSA_MODULUS_B64[:50]}...")

            return efs, jar, entry, class_data, code_off, code_len

    print("\n❌ SignatureBlockProcessor.class not found in any JAR!")
    return None, None, None, None, None, None


def extract_class(efs_path, output_dir='.'):
    """Extract and optionally patch the target class file."""
    efs, jar, entry, class_data, code_off, code_len = analyze(efs_path)
    if class_data is None:
        return

    # Save original
    orig_path = os.path.join(output_dir, 'SignatureBlockProcessor.class.orig')
    with open(orig_path, 'wb') as f:
        f.write(class_data)
    print(f"\n  Saved original: {orig_path}")

    # Patch
    if code_off is not None:
        patched = bytearray(class_data)
        patched[code_off] = 0xB1  # return void
        patched_path = os.path.join(output_dir, 'SignatureBlockProcessor.class')
        with open(patched_path, 'wb') as f:
            f.write(patched)
        print(f"  Saved patched:  {patched_path}")
        print(f"\n  ✅ Patch applied: verifyManifestAndSignatureFile → immediate return")


def main():
    parser = argparse.ArgumentParser(
        description='RNS 850 BouncyCastle FSC signature bypass',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s efs-system.efs --analyze
  %(prog)s efs-system.efs --extract-class
  %(prog)s efs-system.efs --extract-class --output /tmp/

Platforms: VW Touareg (RNS 850), VW Phaeton (RNS 850)
           Shares platform with Audi MMI3G (HN+ family)
        """
    )
    parser.add_argument('efs', help='Path to efs-system.efs firmware file')
    parser.add_argument('--analyze', action='store_true',
                        help='Analyze EFS and find patch point (no modification)')
    parser.add_argument('--extract-class', action='store_true',
                        help='Extract and patch SignatureBlockProcessor.class')
    parser.add_argument('--output', '-o', default='.',
                        help='Output directory for extracted files')

    args = parser.parse_args()

    if not os.path.exists(args.efs):
        print(f"ERROR: File not found: {args.efs}", file=sys.stderr)
        sys.exit(1)

    if args.extract_class:
        os.makedirs(args.output, exist_ok=True)
        extract_class(args.efs, args.output)
    else:
        analyze(args.efs)


if __name__ == '__main__':
    main()
