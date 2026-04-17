/*
 * qnx_ifs_decompress.c — decompress QNX IFS (Image File System) images.
 *
 * A compressed IFS begins with a startup_header. If the header's flags1
 * field has a compression type set, the compressed image stream begins
 * at offset startup_size. Each compressed chunk is:
 *
 *     uint16_t  length  (BIG-ENDIAN)    — compressed chunk size
 *     uint8_t   data[length]            — LZO1X or UCL NRV2B payload
 *
 * A length of 0 ends the chunk stream. Each chunk typically decompresses
 * to exactly 65,536 bytes; the last may be smaller.
 *
 * Output file layout:
 *     startup_header + startup_code + startup_trailer  (from 0..startup_size,
 *                                                       copied as-is)
 *     uncompressed imagefs stream                      (from startup_size..)
 *
 * After decompression the result is a plain QNX IFS that `dumpifs` or
 * our `extract_qnx_ifs.py` can parse directly.
 *
 * Format documented in:
 *   openqnx/trunk/utils/m/mkxfs/dumpifs/dumpifs.c lines 500-650
 *
 * Usage: qnx_ifs_decompress <input.ifs> <output.ifs>
 */
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <lzo/minilzo.h>
#include <ucl/ucl.h>

/* Compression type constants — derived from QNX headers via unpackifs.py. */
#define FLAGS1_BIGENDIAN          0x01
#define FLAGS1_VIRTUAL            0x02
#define FLAGS1_COMPRESS_MASK      0x1c   /* bits 4:2 carry compression type */
#define FLAGS1_COMPRESS_SHIFT     2
#define COMPRESS_NONE             0
#define COMPRESS_ZLIB             1
#define COMPRESS_LZO              2
#define COMPRESS_UCL              3

struct startup_header {
    uint32_t signature;        /* branch instruction */
    uint16_t version;
    uint8_t  flags1;
    uint8_t  flags2;
    uint16_t header_size;
    uint16_t machine;
    uint32_t startup_vaddr;
    uint32_t paddr_bias;
    uint32_t image_paddr;
    uint32_t ram_paddr;
    uint32_t ram_size;
    uint32_t startup_size;
    uint32_t stored_size;
    uint32_t imagefs_paddr;
    uint32_t imagefs_size;
    uint16_t preboot_size;
    uint16_t zero0;
    uint32_t zero[3];
} __attribute__((packed));

static uint8_t cmpbuf[4 * 1024 * 1024];
static uint8_t outbuf[4 * 1024 * 1024];

int main(int argc, char *argv[])
{
    if (argc != 3) {
        fprintf(stderr, "usage: %s <input.ifs> <output.ifs>\n", argv[0]);
        return 2;
    }

    if (lzo_init() != LZO_E_OK) { fprintf(stderr, "lzo_init failed\n"); return 1; }
    if (ucl_init() != UCL_E_OK) { fprintf(stderr, "ucl_init failed\n"); return 1; }

    FILE *in = fopen(argv[1], "rb");
    if (!in)  { perror("fopen in");  return 1; }
    FILE *out = fopen(argv[2], "wb");
    if (!out) { perror("fopen out"); fclose(in); return 1; }

    struct startup_header sh;
    if (fread(&sh, sizeof(sh), 1, in) != 1) {
        fprintf(stderr, "read shdr failed\n");
        return 1;
    }

    int cmptype = (sh.flags1 & FLAGS1_COMPRESS_MASK) >> FLAGS1_COMPRESS_SHIFT;
    const char *ctname =
        cmptype == COMPRESS_NONE ? "none" :
        cmptype == COMPRESS_ZLIB ? "zlib" :
        cmptype == COMPRESS_LZO  ? "lzo"  :
        cmptype == COMPRESS_UCL  ? "ucl"  : "?";

    fprintf(stderr, "startup_header:\n");
    fprintf(stderr, "  flags1=0x%02x  compression=%s\n", sh.flags1, ctname);
    fprintf(stderr, "  startup_size=0x%x  stored_size=0x%x  imagefs_size=0x%x\n",
            sh.startup_size, sh.stored_size, sh.imagefs_size);

    if (cmptype == COMPRESS_NONE) {
        fprintf(stderr, "image is not compressed; copying through\n");
        rewind(in);
        size_t n;
        while ((n = fread(cmpbuf, 1, sizeof(cmpbuf), in)) > 0)
            fwrite(cmpbuf, 1, n, out);
        fclose(in); fclose(out);
        return 0;
    }

    /* Copy the startup section (header + code + trailer) verbatim. */
    rewind(in);
    uint32_t left = sh.startup_size;
    while (left > 0) {
        size_t want = left > sizeof(cmpbuf) ? sizeof(cmpbuf) : left;
        size_t got = fread(cmpbuf, 1, want, in);
        if (got == 0) { fprintf(stderr, "short read in startup copy\n"); return 1; }
        fwrite(cmpbuf, 1, got, out);
        left -= got;
    }

    /* Decompress the chunk stream. */
    int chunks = 0;
    uint64_t total_out = 0;
    for (;;) {
        int c1 = fgetc(in);
        int c2 = fgetc(in);
        if (c1 == EOF || c2 == EOF) {
            fprintf(stderr, "unexpected EOF reading chunk length (chunk %d)\n", chunks);
            break;
        }
        int clen = (c1 << 8) | c2;  /* BIG-ENDIAN per dumpifs.c */
        if (clen == 0) {
            fprintf(stderr, "chunk stream EOF after %d chunks\n", chunks);
            break;
        }
        if (clen < 0 || clen > (int)sizeof(cmpbuf)) {
            fprintf(stderr, "chunk %d: invalid length %d\n", chunks, clen);
            return 1;
        }
        if ((int)fread(cmpbuf, 1, clen, in) != clen) {
            fprintf(stderr, "chunk %d: short read of %d bytes\n", chunks, clen);
            return 1;
        }

        int err;
        int wr;
        if (cmptype == COMPRESS_LZO) {
            lzo_uint out_len = sizeof(outbuf);
            err = lzo1x_decompress(cmpbuf, clen, outbuf, &out_len, NULL);
            wr = (int)out_len;
            if (err != LZO_E_OK) {
                fprintf(stderr, "chunk %d: lzo1x err %d (clen=%d)\n", chunks, err, clen);
                return 1;
            }
        } else if (cmptype == COMPRESS_UCL) {
            ucl_uint out_len = sizeof(outbuf);
            err = ucl_nrv2b_decompress_8(cmpbuf, clen, outbuf, &out_len, NULL);
            wr = (int)out_len;
            if (err != UCL_E_OK) {
                fprintf(stderr, "chunk %d: ucl err %d (clen=%d)\n", chunks, err, clen);
                return 1;
            }
        } else {
            fprintf(stderr, "unsupported compression %d\n", cmptype);
            return 1;
        }

        fwrite(outbuf, 1, wr, out);
        total_out += wr;
        chunks++;
    }

    fprintf(stderr, "decompressed %d chunks -> %lu bytes\n",
            chunks, (unsigned long)total_out);
    if (sh.imagefs_size && total_out != sh.imagefs_size) {
        fprintf(stderr, "NOTE: imagefs_size header says %u, got %lu\n",
                sh.imagefs_size, (unsigned long)total_out);
    }

    fclose(in);
    fclose(out);
    return 0;
}
