/*
 * qnx_inflator.c — inflate QNX "deflate" (iwlyfmbp) compressed files
 *
 * Handles the file format documented in openqnx/trunk/utils/d/deflate/deflate.c:
 *
 *   struct filehdr {                      // 16 bytes
 *       char     signature[8];            // "iwlyfmbp"
 *       uint32_t usize;                   // total uncompressed size
 *       uint16_t blksize;                 // 4/8/16/32 KB
 *       uint8_t  cmptype;                 // 0 = LZO, 1 = UCL
 *       uint8_t  flags;
 *   };
 *   struct cmphdr {                       // 8 bytes before each block
 *       uint16_t prev, next;              // byte offsets
 *       uint16_t pusize, usize;
 *   };
 *
 * Blocks loop until a header with next == 0 marks EOF.
 *
 * Usage:
 *   qnx_inflator <input.bin> <output.bin>
 */
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

#include <lzo/minilzo.h>
#include <ucl/ucl.h>

#define CMP_LZO 0
#define CMP_UCL 1

#define SIGNATURE "iwlyfmbp"

struct filehdr {
    char     signature[8];
    uint32_t usize;
    uint16_t blksize;
    uint8_t  cmptype;
    uint8_t  flags;
} __attribute__((packed));

struct cmphdr {
    uint16_t prev;
    uint16_t next;
    uint16_t pusize;
    uint16_t usize;
} __attribute__((packed));

static uint8_t workbuf[64 * 1024];
static uint8_t cmpbuf[64 * 1024];

int main(int argc, char *argv[])
{
    if (argc != 3) {
        fprintf(stderr, "usage: %s <input> <output>\n", argv[0]);
        return 2;
    }

    if (ucl_init() != UCL_E_OK) {
        fprintf(stderr, "ucl_init failed\n");
        return 1;
    }
    if (lzo_init() != LZO_E_OK) {
        fprintf(stderr, "lzo_init failed\n");
        return 1;
    }

    FILE *in = fopen(argv[1], "rb");
    if (!in) { perror("fopen in"); return 1; }
    FILE *out = fopen(argv[2], "wb");
    if (!out) { perror("fopen out"); fclose(in); return 1; }

    struct filehdr hdr;
    if (fread(&hdr, sizeof(hdr), 1, in) != 1) {
        fprintf(stderr, "read header failed\n");
        return 1;
    }
    if (memcmp(hdr.signature, SIGNATURE, 8) != 0) {
        fprintf(stderr, "bad signature: %.8s (expected %s)\n",
                hdr.signature, SIGNATURE);
        return 1;
    }

    fprintf(stderr, "signature: %.8s\n", hdr.signature);
    fprintf(stderr, "usize:     %u\n", hdr.usize);
    fprintf(stderr, "blksize:   %u\n", hdr.blksize);
    fprintf(stderr, "cmptype:   %u (%s)\n", hdr.cmptype,
            hdr.cmptype == CMP_LZO ? "LZO" :
            hdr.cmptype == CMP_UCL ? "UCL" : "?");

    uint32_t total_out = 0;
    int block_num = 0;

    while (1) {
        struct cmphdr ch;
        if (fread(&ch, sizeof(ch), 1, in) != 1) break;

        /* next == 0 marks end-of-file */
        if (ch.next == 0) {
            fprintf(stderr, "EOF marker at block %d\n", block_num);
            break;
        }

        int blksize = ch.next - sizeof(ch);
        if (blksize < 0 || blksize > (int)sizeof(cmpbuf)) {
            fprintf(stderr, "block %d: invalid blksize %d\n", block_num, blksize);
            return 1;
        }
        if ((int)fread(cmpbuf, 1, blksize, in) != blksize) {
            fprintf(stderr, "block %d: read %d bytes failed\n", block_num, blksize);
            return 1;
        }

        int out_size;
        int err;

        if (hdr.cmptype == CMP_LZO) {
            lzo_uint d_out = sizeof(workbuf);
            err = lzo1x_decompress(cmpbuf, blksize, workbuf, &d_out, NULL);
            out_size = (int)d_out;
            if (err != LZO_E_OK) {
                fprintf(stderr, "block %d: lzo1x_decompress err %d\n", block_num, err);
                return 1;
            }
        } else if (hdr.cmptype == CMP_UCL) {
            ucl_uint d_out = sizeof(workbuf);
            err = ucl_nrv2b_decompress_8(cmpbuf, blksize, workbuf, &d_out, NULL);
            out_size = (int)d_out;
            if (err != UCL_E_OK) {
                fprintf(stderr, "block %d: ucl decompress err %d\n", block_num, err);
                return 1;
            }
        } else {
            fprintf(stderr, "unknown compression type %u\n", hdr.cmptype);
            return 1;
        }

        if (out_size != ch.usize) {
            fprintf(stderr, "block %d: usize mismatch (got %d, header says %u)\n",
                    block_num, out_size, ch.usize);
        }

        if ((int)fwrite(workbuf, 1, out_size, out) != out_size) {
            fprintf(stderr, "block %d: write failed\n", block_num);
            return 1;
        }
        total_out += out_size;
        block_num++;
    }

    fprintf(stderr, "done: %d blocks, %u bytes uncompressed\n", block_num, total_out);
    if (total_out != hdr.usize) {
        fprintf(stderr, "WARNING: total mismatch with header usize %u\n", hdr.usize);
    }

    fclose(out);
    fclose(in);
    return 0;
}
