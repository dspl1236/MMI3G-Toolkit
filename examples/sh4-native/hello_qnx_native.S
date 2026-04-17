/* hello_qnx_native.S — native QNX SH4 binary
 * 
 * Uses trapa #0xfd (DebugKDOutput) to write to kernel debug channel.
 * No library dependencies. Runs directly on QNX 6.3.2 SH4.
 *
 * Deploy: copy to MMI3G via telnet, chmod +x, ./hello_qnx_native
 * Output appears in slogger/slog2 output.
 */
    .text
    .global _start

_start:
    /* r4 = pointer to message string */
    mova    msg, r0
    mov     r0, r4

    /* r5 = length of message */
    mov     #26, r5

    /* trapa #0xfd = SH_KER_TRAP_KDOUTPUT */
    /* Writes r5 bytes from *r4 to kernel debug channel */
    trapa   #0xfd

    /* Exit: trapa #0xfe = debug break (stops cleanly) */
    /* For a real exit, we'd call _exit() from libc */
    /* For now, just loop forever */
    mov     #0, r0
loop:
    bra     loop
    nop

    .align 2
msg:
    .ascii "Hello from MMI3G-Toolkit!\n"
    .byte 0
