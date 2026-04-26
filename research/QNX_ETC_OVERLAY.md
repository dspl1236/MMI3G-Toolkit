# QNX /etc/ Overlay — Making Read-Only IFS Writable

## The Problem (Affects Both PCM 3.1 AND MMI3G/RNS-850)

Both Harman head units boot from an IFS (Image FileSystem) that contains
`/etc/` as a read-only directory. This prevents modifying:
- `/etc/hosts` — DNS hostname resolution
- `/etc/inetd.conf` — network daemon config (telnet, FTP, port 2323)
- `/etc/resolv.conf` — DNS server config  
- `/etc/shadow` — password hashes
- `/etc/passwd` — user accounts

## The Solution: QNX Prefix Tree Mount Overlay

QNX's pathname resolution uses a prefix tree with a **longest-match** rule.
When multiple filesystems are mounted at the same prefix, QNX resolves
them in mount order. The `mount -o before` option places a new mount
**in front of** existing ones, so it's checked first.

### How It Works
```
BEFORE overlay:
  / → IFS (read-only)
  /etc/ → IFS /etc/ (read-only)
  
AFTER overlay:
  / → IFS (read-only)  
  /etc/ → RAM disk (read/write) ← checked FIRST (mounted with -o before)
  /etc/ → IFS /etc/ (read-only) ← only checked if file not found above
```

### Implementation

#### Method 1: devf-ram + mount (Preferred)
```bash
# 1. Save current /etc contents
mkdir -p /dev/shmem/etc_backup
cp /etc/* /dev/shmem/etc_backup/ 2>/dev/null

# 2. Create a RAM flash filesystem
devf-ram -s0,512k -i20,1
# Creates: /dev/fs20 (raw), /dev/fs20p0 (partition)

# 3. Format the partition  
flashctl -p /dev/fs20p0 -e -f -m /etc
# Erases, formats, and sets mount point to /etc

# 4. Mount over /etc (before = in front of IFS)
mount -t flash /dev/fs20p0 /etc

# 5. Restore original contents + add our modifications
cp /dev/shmem/etc_backup/* /etc/ 2>/dev/null
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "2323 stream tcp nowait root /bin/ksh ksh -i" >> /etc/inetd.conf
echo "192.168.0.91 pc" >> /etc/hosts
```

#### Method 2: /dev/shmem alias (Simpler, Less Robust)
```bash
# QNX's /dev/shmem is always writable (RAM-based)
# Create an etc directory in shmem
mkdir -p /dev/shmem/etc_overlay
cp /etc/* /dev/shmem/etc_overlay/ 2>/dev/null

# Add modifications
echo "nameserver 8.8.8.8" > /dev/shmem/etc_overlay/resolv.conf
echo "2323 stream tcp nowait root /bin/ksh ksh -i" >> /dev/shmem/etc_overlay/inetd.conf

# Processes that open specific files can be redirected:
# This only works for processes that accept config file paths
# (e.g., inetd can be started with a custom config path)
slay -f inetd; /usr/sbin/inetd /dev/shmem/etc_overlay/inetd.conf &
```

#### Method 3: QNX Prefix Alias
```bash
# QNX prefix utility can create pathname aliases
# This redirects /etc/* lookups to /dev/shmem/etc_overlay/*
prefix -A /etc=/dev/shmem/etc_overlay
```

### Platform-Specific Notes

#### PCM 3.1 (Cayenne 958)
- `/etc/` is in IFS boot image (read-only)
- `devf-ram` is running (instances 1 and 4)
- `/dev/shmem/` is writable (= `/tmp/`)
- `flashctl` may or may not be available
- Key files needed: hosts, resolv.conf, inetd.conf

#### MMI3G+ (Audi A6/A7/A8/Q7)
- `/etc/` is in IFS but may be partially writable
- Andrew's C7 A6 can write to `/etc/inetd.conf` (confirmed working)
- RNS-850 (daredoole's VW) may have same read-only issue
- Key files: hosts, inetd.conf, shadow

#### RNS-850 (VW Touareg)
- Same Harman HN+R platform as MMI3G+
- daredoole's unit — may have read-only /etc/ like PCM
- Overlay technique directly applicable

### Implications

If the overlay works, it solves EVERY /etc/ limitation:

| Problem | Status Before | Status After Overlay |
|---------|--------------|---------------------|
| DNS resolution (hosts) | ❌ Can't add entries | ✅ Full control |
| DNS servers (resolv.conf) | ❌ Can't create file | ✅ 8.8.8.8 + 8.8.4.4 |
| Telnet port 2323 (inetd.conf) | ❌ Can't modify | ✅ Add raw ksh shell |
| Passwordless root (shadow) | ❌ No shadow file | ✅ Create with empty hash |
| Telnet reverse DNS timeout | ❌ 5-7 second delay | ✅ Instant connection |
| Internet (full DNS) | ❌ IP only | ✅ Full hostname resolution |

### Session Persistence
The overlay is RAM-based — lost on reboot. But the toolkit script
sets it up automatically on each run. This is actually SAFER than
permanent changes (can't brick the car by corrupting /etc/).

### Investigation Commands
```bash
# Check what's available
which flashctl
which prefix
mount
df

# Test Method 1 (devf-ram)
devf-ram -s0,512k -i20,1 2>&1
ls /dev/fs20*

# Test Method 3 (prefix alias)
prefix
prefix -A /etc=/dev/shmem/etc_overlay
```

### References
- reddit.com/r/QNX/comments/1h4l09k/overlaying_root_paths_in_qnx/
- QNX mount(1): `-o before` option for mount ordering
- QNX prefix(1): pathname alias support
- QNX devf-ram: RAM flash filesystem driver
