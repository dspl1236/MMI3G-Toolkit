/* hello_dynamic.c — dynamically linked QNX SH4 binary
 * Links against QNX libc.so.2 at runtime via ldqnx.so.2
 */
extern int write(int fd, const void *buf, unsigned nbytes);

int main(void) {
    const char msg[] = "Hello from MMI3G-Toolkit!\n";
    write(1, msg, 26);
    return 0;
}
