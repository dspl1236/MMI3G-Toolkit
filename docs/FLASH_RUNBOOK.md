# MMI3G-Toolkit Flash Runbook

Step-by-step guide for modifying and flashing custom firmware on
Audi MMI3G+ (HN+R) head units.

**WARNING: Modifying firmware can brick your head unit. Keep a backup
of your original firmware at all times. Proceed at your own risk.**


## Prerequisites

### Hardware
- Audi with MMI3G+ HN+R head unit (A6/A7/A8/Q3/A4/A5/Q5/Q7 etc.)
- SD card (8GB+ recommended, FAT32 formatted)
- Computer with Python 3.8+ installed

### Software
- This repository: `git clone https://github.com/dspl1236/MMI3G-Toolkit.git`
- Your original firmware archive (e.g., `HN+R_EU_AU_K0942_4_[8R0906961FB]`)
- Build tools: `gcc` and `liblzo2-dev` (for the LZO compressor)

### Identify your variant
Your head unit has a hardware variant number (stamped on the unit
or visible in the GEM version screen). Common variants:

| Variant | Vehicle |
|---------|---------|
| 41 | A6/A7/A8/Q3 (standard) |
| 51 | A6/A7/A8/Q3 (alternate display) |
| 61 | A6/A7/A8/Q3 (alternate display) |
| 31 | A6/A7/A8/Q3 (older revision) |

Your firmware archive contains variant-specific IFS images at:
```
MU9411/ifs-root/<variant>/default/ifs-root.ifs
```


## Step 0: Build the LZO compressor (one-time)

```bash
cd MMI3G-Toolkit/tools
gcc -O2 -o qnx_ifs_compress qnx_ifs_compress.c -llzo2
gcc -O2 -o qnx_ifs_decompress qnx_ifs_decompress.c -llzo2
```

On Ubuntu/Debian, install liblzo2 first:
```bash
sudo apt install liblzo2-dev
```


## Step 1: Extract and decompress the IFS

```bash
# Set your paths
FIRMWARE_DIR="/path/to/HN+R_EU_AU_K0942_4_[8R0906961FB]"
VARIANT=41
WORKDIR="./custom_fw"
mkdir -p "$WORKDIR"

# Locate original IFS
ORIGINAL_IFS="$FIRMWARE_DIR/MU9411/ifs-root/$VARIANT/default/ifs-root.ifs"

# Decompress
python3 tools/inflate_ifs.py "$ORIGINAL_IFS" -o "$WORKDIR/ifs_decompressed.ifs"

# Extract files for browsing/editing
python3 tools/inflate_ifs.py "$ORIGINAL_IFS" --extract "$WORKDIR/ifs_files/"
```

You now have all 345+ firmware files at `$WORKDIR/ifs_files/`.


## Step 2: Make your modifications

### Option A: Replace a specific file (patch_ifs.py)

Best for replacing a single binary, config file, or script.

```bash
# Replace a file (handles any size change)
python3 tools/patch_ifs.py "$WORKDIR/ifs_decompressed.ifs" \
    "$WORKDIR/ifs_patched.ifs" \
    --replace "mnt/ifs-root/usr/bin/start_network.sh=./my_modified_script.sh"

# Multiple replacements
python3 tools/patch_ifs.py "$WORKDIR/ifs_decompressed.ifs" \
    "$WORKDIR/ifs_patched.ifs" \
    --replace "mnt/ifs-root/usr/bin/start_network.sh=./mod_network.sh" \
    --replace "mnt/ifs-root/etc/mmi3g-srv-starter.cfg=./mod_config.cfg"
```

### Option B: Add/remove files (build_ifs.py)

Best for adding new files or removing existing ones.

```bash
# Edit the extracted tree
cp ./my_new_script.sh "$WORKDIR/ifs_files/mnt/ifs-root/usr/bin/"
rm "$WORKDIR/ifs_files/mnt/ifs-root/some/unnecessary/file"

# Rebuild IFS from modified tree
python3 tools/build_ifs.py \
    --reference "$WORKDIR/ifs_decompressed.ifs" \
    --tree "$WORKDIR/ifs_files/" \
    --output "$WORKDIR/ifs_patched.ifs"
```

### Option C: One-command pipeline (mu_repack.py)

For quick single-file replacements:

```bash
python3 tools/mu_repack.py \
    --mu-dir "$FIRMWARE_DIR/MU9411" \
    --variant $VARIANT \
    --replace "mnt/ifs-root/usr/bin/start_network.sh=./mod_network.sh" \
    --output "$WORKDIR/output/" \
    --skip-crc
```


## Step 3: Recompress the IFS

```bash
python3 tools/repack_ifs.py \
    "$WORKDIR/ifs_patched.ifs" \
    "$WORKDIR/ifs-root.ifs"
```

The output `ifs-root.ifs` is the flashable compressed image.


## Step 4: Handle CRC verification

The firmware update system checks CRC32 values in `metainfo2.txt`.
You have two options:

### Option A: Use skipCrc (recommended for testing)

Edit metainfo2.txt and replace ALL `CheckSum` lines in the
`[MU9411\ifs-root\<variant>\default\Application]` section with:

```ini
skipCrc = true
```

Or use the CRC patcher:
```bash
python3 tools/mu_crc_patcher.py \
    --metainfo "$FIRMWARE_DIR/metainfo2.txt" \
    --file "$WORKDIR/ifs-root.ifs" \
    --section "MU9411\ifs-root\41\default\Application" \
    --skip
```

### Option B: Recompute CRCs (recommended for production)

```bash
python3 tools/mu_crc_patcher.py \
    --metainfo "$FIRMWARE_DIR/metainfo2.txt" \
    --file "$WORKDIR/ifs-root.ifs" \
    --section "MU9411\ifs-root\41\default\Application"
```

This recalculates all 84 CheckSum values and updates metainfo2.txt.

Note: The K0942_4 release already has `skipMetaCRC = "true"` in the
`[common]` section, which means the MetafileChecksum line (CRC of the
metainfo2.txt file itself) is not checked.


## Step 5: Prepare the SD card

### For a full firmware update

1. Copy the entire firmware archive to the SD card root:
   ```
   SD:/
     metainfo2.txt        (modified with new CRCs or skipCrc)
     MU9411/
       ifs-root/
         41/default/
           ifs-root.ifs   (your modified image)
       efs-system/        (copy from original)
       ...                (copy all other dirs from original)
     finalScript
     ...                  (copy all other files from original)
   ```

2. Replace only the ifs-root.ifs with your modified version.
   Keep everything else from the original archive.

### For GEM screen deployment only (no flash required)

To deploy custom .esd engineering screens without modifying the IFS:
```
SD:/
  copie_scr.sh           (script to copy engdefs)
  engdefs/
    ToolkitMain.esd
    ToolkitSWDL.esd
    ToolkitDiag.esd
```

The copie_scr.sh approach uses the SD card detection mechanism
(storagetype=18) to copy files to writable storage on boot.


## Step 6: Flash the firmware

### Method A: Standard SWDL update

1. Insert the SD card into the MMI SD slot
2. The update dialog should appear automatically
   (if `/SwdlAutoRun.txt` exists on the SD card root)
3. Follow the on-screen prompts
4. Wait for the update to complete (10-30 minutes)
5. The unit will reboot automatically

### Method B: GEM-triggered update

1. Access the Green Engineering Menu (GEM):
   - With VCDS: adaptation channel for GEM access
   - Or via per3 persistence modification
2. Navigate to the SWDL screen
3. Enable "user defined mode" toggle
4. Enable "ignore region and variant" if needed
5. Select the update medium
6. Start the update

### Method C: Production mode

For unattended updates (factory-style):
1. Create `/HBpersistence/SWDL/SwdlProductionMode.txt` on the unit
2. Create `/HBpersistence/SWDL/AutoHandlePopUp.txt` to auto-accept
3. Place `/SwdlAutoRun.txt` on the SD card
4. Insert SD card — update starts and completes automatically


## Common modifications

### Enable telnet access

Modify `start_network.sh` to add USB-Ethernet support:
```bash
# Add these lines to the end of start_network.sh:
/sbin/io-pkt-v4-hc -d /lib/dll/devn-asix.so &
sleep 2
/sbin/ifconfig en0 172.16.42.1 netmask 255.255.255.0 up
```

Connect a D-Link DUB-E100 (or ASIX-based) USB-Ethernet adapter.
Set your PC to 172.16.42.2/24. Then: `telnet 172.16.42.1`

### Deploy custom GEM screens

Add .esd files to the IFS at `/mnt/ifs-root/` or deploy via
copie_scr.sh to `/mnt/efs-system/engdefs/`.
See `research/ESD_SCREEN_FORMAT.md` for the format specification.

### Disable SH4 watchdog (for debugging)

Via GEM screen `EepromFlags.esd`:
- DSI key `per 3 0x0011000E` → set to 241 ("disabled")

Or add to your custom ESD screen:
```
BIOSCtrl
   value    int per 3 0x0011000E
   label    "SH4 Watchdog"
   entry    "8 minutes" 32
   entry    "60 minutes" 240
   entry    "disabled" 241
```


## Troubleshooting

### Update doesn't start
- Verify SD card is FAT32 formatted
- Check that metainfo2.txt is at the SD card root
- Ensure the variant number matches your hardware
- Try adding `/SwdlAutoRun.txt` to the SD card root

### Update fails with CRC error
- Use `skipCrc = true` in the metainfo2.txt section
- Or recompute CRCs with `mu_crc_patcher.py`
- Verify `skipMetaCRC = "true"` is in the `[common]` section

### Unit doesn't boot after update
- Remove the SD card
- The unit should fall back to the previous firmware
- If not: use the emergency IFS (`ifs-emg/`) which is a minimal
  recovery image. This requires physical access to the board.

### Variant mismatch
- The SWDL screen in GEM has an "ignore region and variant" toggle
  at DSI key `per 1 0x001E0004`
- Enable this before attempting cross-variant updates


## File reference

| Tool | Purpose |
|------|---------|
| `inflate_ifs.py` | Decompress IFS (LZO/UCL) |
| `extract_qnx_ifs.py` | Extract files from IFS |
| `build_ifs.py` | Build IFS from file tree |
| `patch_ifs.py` | Replace files in IFS |
| `repack_ifs.py` | Recompress IFS (byte-identical) |
| `mu_crc_patcher.py` | Fix or skip CRC checksums |
| `mu_repack.py` | One-command pipeline |

| Research doc | Content |
|-------------|---------|
| `ENGINEERING_ACCESS.md` | 36 GEM controllers, DSI keys |
| `ESD_SCREEN_FORMAT.md` | GEM screen definition format |
| `FIRMWARE_UPDATE_FORMAT.md` | metainfo2.txt structure |


## Safety notes

- Always keep a complete backup of your original firmware archive
- The emergency IFS (`ifs-emg/`) should never be modified
- Test modifications on a bench unit before your daily driver
- The `skipCrc` bypass is for testing only — recompute CRCs for
  any firmware you plan to run long-term
- Do not interrupt the update process (power loss = potential brick)
