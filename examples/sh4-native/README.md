# SH4 Native Binary Development

Cross-compile SH4 binaries for the MMI3G head unit.

## Prerequisites

```bash
sudo apt install gcc-14-sh4-linux-gnu binutils-sh4-linux-gnu
```

## Approach 1: Raw Assembly (no dependencies)

```bash
sh4-linux-gnu-gcc-14 -nostdlib -nostartfiles -static \
    -Wl,-e,_start \
    -o hello_qnx_native \
    hello_qnx_native.S
```

Produces a 696-byte SH4 ELF using `trapa #0xfd` (QNX kernel
debug output). Output appears in the kernel debug channel.

## Approach 2: C with Dynamic Linking (requires telnet access)

The Linux cross-linker cannot resolve symbols from QNX's
libc.so.2 (different symbol table format). To build C programs:

1. Cross-compile to object file:
   ```bash
   sh4-linux-gnu-gcc-14 -c -fPIC -O2 -fno-stack-protector \
       -ffreestanding -o hello.o hello_dynamic.c
   ```

2. Transfer to MMI via telnet (see docs/FLASH_RUNBOOK.md)

3. Link on the target system using QNX's linker:
   ```bash
   # On the MMI via telnet:
   /usr/bin/ld -o hello hello.o -lc
   ```

## Approach 3: Java OSGi Bundles (recommended)

For most custom apps, Java OSGi bundles are the practical path.
The per3-reader module demonstrates the framework. See
`modules/per3-reader/` for a working example with DSI integration.

## Architecture Notes

- CPU: Renesas SH7785 (SH4A)
- OS: QNX Neutrino 6.3.2
- Dynamic linker: /usr/lib/ldqnx.so.2
- C library: libc.so.2 (QNX-specific)
- QNX syscall mechanism: trapa-based kernel calls via libc
  - trapa #0xfd = DebugKDOutput (r4=text, r5=len)
  - trapa #0xfe = DebugBreak
