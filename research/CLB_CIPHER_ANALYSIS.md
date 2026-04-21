# VCDS CLB Cipher Analysis (INTERNAL — DO NOT PUBLISH)

## Status: Partially Cracked

### Key Discoveries

1. **Byte 0** is always 0x00 — version/format marker, NOT encrypted
2. **Byte 1** varies per file — per-file seed/key component  
3. **Bytes 2-9** are IDENTICAL across all short-name (XX-YY.clb) files
   - Constant: `e6 42 7c 2e 26 10 07 a1`
   - This means positions 1-8 of the key stream are fixed for this file class

4. **Long-name files** (4G0-907-xxx.clb, 4H0-920-xxx-17.clb) have 
   DIFFERENT bytes 2-9 — the key stream depends on file class

5. **Plaintext format** confirmed: starts with `; Ross-Tech, LLC\r\n; VCDS Label File\r\n`
   - Successfully decrypts positions 1-8 across multiple files
   - Position 0 has per-file key byte
   - Position 9+ diverges (cipher state incorporates per-file seed)

### Confirmed Key Stream (short-name files)

Using crib `; Ross-Tech, LLC\r\n`:
```
Position:  0    1    2    3    4    5    6    7    8    9+
Key:       ??   0xc6 0x14 0x3f 0x6a 0x75 0x30 0x4b 0xc0  varies
```

Position 0 key byte varies per file and correlates with filename.

### What's Needed to Complete

- Figure out the key stream generation for position 9+
- Likely a seeded PRNG or stream cipher initialized from byte 1
- Or a feedback cipher where position 0's plaintext/key affects later state
- The VCDS binary has the algorithm but it's packed/obfuscated

### Codes.dat Structure

- 34,716 DTC records
- Each: `XXXXXXXX <encrypted_data>\r\n`
- First byte of encrypted_data = block-aligned length (multiples of 8)
- Second byte = actual text length before padding
- Same encryption as CLB but different key derivation

### Practical Note

The C7 Kombi adaptation channels are already documented by the 
community (Audizine, VCDS-Expert, Ross-Tech Wiki). CLB cracking
is a research exercise, not a practical blocker.
