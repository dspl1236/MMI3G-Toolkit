"""
copie_scr.sh XOR Encoder/Decoder for Harman Becker MMI3G systems.

Reimplementation of the PRNG-based XOR cipher used by Audi/VW MMI3G
systems to encode SD card autorun scripts. Compatible with:
  - megusta1337/Copie_scr_Decoder
  - cmbsolutions/copie_scr.sh-Encoding-Decoding

The cipher is symmetric - encoding and decoding use the same operation.

Usage:
    python encoder.py encode input.sh output.sh
    python encoder.py decode copie_scr.sh output.sh
"""

import sys
import os


class MMI3GCipher:
    """PRNG-based XOR cipher matching the MMI3G proc_scriptlauncher."""
    
    SEED_INIT = 0x001be3ac

    def __init__(self):
        self.seed = self.SEED_INIT

    def _prng_rand(self) -> int:
        """Generate next PRNG value (matches Harman Becker implementation)."""
        r0 = self.seed & 0xFFFFFFFF
        r1 = ((self.seed >> 1) | (self.seed << 31)) & 0xFFFFFFFF
        r3 = (((r1 >> 16) & 0xFF) + r1) & 0xFFFFFFFF
        r1 = (((r3 >> 8) & 0xFF) << 16) & 0xFFFFFFFF
        r3 = (r3 - r1) & 0xFFFFFFFF
        self.seed = r3
        return r0

    def process(self, data: bytes) -> bytes:
        """Encode or decode data (symmetric operation)."""
        self.seed = self.SEED_INIT
        self._prng_rand()  # First call is discarded
        
        result = bytearray()
        for byte in data:
            xor_val = self._prng_rand() & 0xFF
            result.append(byte ^ xor_val)
        
        return bytes(result)


def encode_file(input_path: str, output_path: str):
    """Encode a plain-text script to copie_scr.sh format."""
    cipher = MMI3GCipher()
    
    with open(input_path, 'rb') as f:
        plaintext = f.read()
    
    encoded = cipher.process(plaintext)
    
    with open(output_path, 'wb') as f:
        f.write(encoded)
    
    print(f"Encoded: {input_path} -> {output_path}")
    print(f"  Input:  {len(plaintext)} bytes")
    print(f"  Output: {len(encoded)} bytes")


def decode_file(input_path: str, output_path: str):
    """Decode a copie_scr.sh to plain text."""
    cipher = MMI3GCipher()
    
    with open(input_path, 'rb') as f:
        encoded = f.read()
    
    decoded = cipher.process(encoded)
    
    with open(output_path, 'wb') as f:
        f.write(decoded)
    
    print(f"Decoded: {input_path} -> {output_path}")
    print(f"  Input:  {len(encoded)} bytes")
    print(f"  Output: {len(decoded)} bytes")


def main():
    if len(sys.argv) < 4:
        print("MMI3G copie_scr.sh Encoder/Decoder")
        print()
        print("Usage:")
        print(f"  {sys.argv[0]} encode <input.sh> <copie_scr.sh>")
        print(f"  {sys.argv[0]} decode <copie_scr.sh> <output.sh>")
        print()
        print("The cipher is symmetric - encode/decode are the same")
        print("operation, labels are just for clarity.")
        sys.exit(1)

    action = sys.argv[1].lower()
    input_path = sys.argv[2]
    output_path = sys.argv[3]

    if not os.path.exists(input_path):
        print(f"Error: {input_path} not found")
        sys.exit(1)

    if action in ('encode', 'enc', 'e'):
        encode_file(input_path, output_path)
    elif action in ('decode', 'dec', 'd'):
        decode_file(input_path, output_path)
    else:
        print(f"Unknown action: {action}")
        print("Use 'encode' or 'decode'")
        sys.exit(1)


if __name__ == '__main__':
    main()
