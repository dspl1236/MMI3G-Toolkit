#!/usr/bin/env python3
"""
prepare_fsc_deploy.py — Generate deployment files for FSC bypass

Takes an efs-system.efs file and produces everything needed for
the runtime deployment:

  1. patch_offsets.txt — Shell-sourceable offset file
  2. patched_comp.bin — Recompressed patched class data
  3. copie_scr.sh     — XOR-encoded deployment script
  4. deploy_fsc_bypass.sh — Human-readable copy

Usage:
    python3 prepare_fsc_deploy.py efs-system.efs --output /path/to/usb/

The output directory can be an SD card or USB drive root.
Insert into the car, reboot, and the patch deploys automatically.
"""
import argparse
import struct
import sys
import os
import zlib
import shutil

# Import the EFS patcher logic
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

LFH_SIG = b'PK\x03\x04'
CDH_SIG = b'PK\x01\x02'
EOCD_SIG = b'PK\x05\x06'

TARGET_CLASS = "de/audi/tghu/development/jobs/SignatureBlockProcessor.class"
PATCH_OFFSET = 0x1FE8
PATCH_ORIG = 0xBB
PATCH_NEW = 0xB1
RECOMPRESS_LEVEL = 7

# XOR PRNG cipher for copie_scr.sh (seed 0x001be3ac)
def xor_encode(data, seed=0x001be3ac):
    """Encode data using the Harman XOR PRNG cipher."""
    result = bytearray(len(data))
    state = seed
    for i in range(len(data)):
        state = (state * 0x41C64E6D + 0x3039) & 0xFFFFFFFF
        key_byte = (state >> 16) & 0xFF
        result[i] = data[i] ^ key_byte
    return bytes(result)


def find_target_in_efs(efs):
    """Find SignatureBlockProcessor.class in the EFS."""
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
                    'data_offset': data_start,
                    'local_crc_offset': local_abs + 14,
                    'cd_crc_offset': p + 16,
                    'method': method,
                    'comp_size': comp_size,
                    'uncomp_size': uncomp_size,
                    'crc32': crc32_val,
                }

            p += 46 + fname_len + extra_len + comment_len

        pos += 1

    return None


def main():
    parser = argparse.ArgumentParser(
        description='Prepare FSC bypass deployment USB/SD card')
    parser.add_argument('efs', help='Path to efs-system.efs firmware file')
    parser.add_argument('--output', '-o', required=True,
                        help='Output directory (USB/SD card root)')

    args = parser.parse_args()

    if not os.path.exists(args.efs):
        print(f"ERROR: {args.efs} not found", file=sys.stderr)
        sys.exit(1)

    os.makedirs(args.output, exist_ok=True)

    print(f"Loading {args.efs}...")
    with open(args.efs, 'rb') as f:
        efs = f.read()

    info = find_target_in_efs(efs)
    if not info:
        print("ERROR: SignatureBlockProcessor.class not found!")
        sys.exit(1)

    print(f"✅ Found patch point:")
    print(f"   Data offset:      0x{info['data_offset']:08x}")
    print(f"   Local CRC offset: 0x{info['local_crc_offset']:08x}")
    print(f"   CD CRC offset:    0x{info['cd_crc_offset']:08x}")
    print(f"   Original CRC32:   0x{info['crc32']:08x}")

    # Decompress, patch, recompress
    comp_data = efs[info['data_offset']:info['data_offset'] + info['comp_size']]
    class_data = bytearray(zlib.decompress(comp_data, -15))

    if class_data[PATCH_OFFSET] == PATCH_NEW:
        print("\n⚡ Already patched!")
        sys.exit(0)

    if class_data[PATCH_OFFSET] != PATCH_ORIG:
        print(f"\n❌ Unexpected byte 0x{class_data[PATCH_OFFSET]:02x}")
        sys.exit(1)

    class_data[PATCH_OFFSET] = PATCH_NEW
    new_crc = zlib.crc32(bytes(class_data)) & 0xFFFFFFFF

    compressor = zlib.compressobj(RECOMPRESS_LEVEL, zlib.DEFLATED, -15)
    new_comp = compressor.compress(bytes(class_data)) + compressor.flush()

    if len(new_comp) != info['comp_size']:
        print(f"⚠️ Size mismatch: {len(new_comp)} vs {info['comp_size']}")
        # Try other levels
        for level in range(1, 10):
            c = zlib.compressobj(level, zlib.DEFLATED, -15)
            test = c.compress(bytes(class_data)) + c.flush()
            if len(test) == info['comp_size']:
                new_comp = test
                break

    print(f"   Patched CRC32:    0x{new_crc:08x}")
    print(f"   Compressed size:  {len(new_comp)} (original: {info['comp_size']})")

    # Write patched_comp.bin
    comp_path = os.path.join(args.output, 'patched_comp.bin')
    with open(comp_path, 'wb') as f:
        f.write(new_comp)
    print(f"\n✅ Wrote: patched_comp.bin ({len(new_comp)} bytes)")

    # Write patch_offsets.txt
    offsets_path = os.path.join(args.output, 'patch_offsets.txt')
    with open(offsets_path, 'w') as f:
        f.write(f"# FSC Bypass patch offsets\n")
        f.write(f"# Generated from: {os.path.basename(args.efs)}\n")
        f.write(f"# Original CRC32: 0x{info['crc32']:08x}\n")
        f.write(f"# Patched CRC32:  0x{new_crc:08x}\n")
        f.write(f"DATA_OFFSET={info['data_offset']}\n")
        f.write(f"LOCAL_CRC_OFFSET={info['local_crc_offset']}\n")
        f.write(f"CD_CRC_OFFSET={info['cd_crc_offset']}\n")
        f.write(f"COMP_SIZE={info['comp_size']}\n")
        f.write(f"COMP_DATA_FILE=patched_comp.bin\n")
    print(f"✅ Wrote: patch_offsets.txt")

    # Copy deploy script
    script_dir = os.path.dirname(os.path.abspath(__file__))
    deploy_src = os.path.join(script_dir, 'deploy_fsc_bypass.sh')
    if os.path.exists(deploy_src):
        shutil.copy2(deploy_src, os.path.join(args.output, 'deploy_fsc_bypass.sh'))
        print(f"✅ Wrote: deploy_fsc_bypass.sh")

    # Generate copie_scr.sh (XOR encoded deployment script)
    if os.path.exists(deploy_src):
        with open(deploy_src, 'rb') as f:
            script_data = f.read()
        encoded = xor_encode(script_data)
        copie_path = os.path.join(args.output, 'copie_scr.sh')
        with open(copie_path, 'wb') as f:
            f.write(encoded)
        print(f"✅ Wrote: copie_scr.sh (XOR encoded, {len(encoded)} bytes)")

    print(f"\n{'='*50}")
    print(f"  DEPLOYMENT READY!")
    print(f"  Files written to: {args.output}")
    print(f"")
    print(f"  To deploy:")
    print(f"  1. Copy all files to USB stick / SD card root")
    print(f"  2. Insert into car (MMI fully booted)")
    print(f"  3. Wait for VW/Audi logo to appear")
    print(f"  4. Check fsc_bypass_log.txt for results")
    print(f"  5. Reboot the head unit")
    print(f"{'='*50}")


if __name__ == '__main__':
    main()
