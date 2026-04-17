/*
 * qnx_ifs_compress.c — recompress a QNX IFS image for MMI3G firmware.
 *
 * Takes a decompressed IFS (output of qnx_ifs_decompress) and an
 * original compressed IFS (for startup section + chunk boundaries),
 * produces a new compressed IFS.
 *
 * Two modes:
 *   --reference <orig.ifs>   Preserve original chunk boundaries for
 *                            bit-identical output on unmodified images.
 *   --chunk-size <bytes>     Use fixed decompressed chunk size (default 65536).
 *                            For modified images where size changed.
 *
 * Compression: lzo1x_999 (optimal), matching Harman's encoder.
 *
 * Usage:
 *   qnx_ifs_compress <decompressed.ifs> <output.ifs> --reference <original.ifs>
 *   qnx_ifs_compress <decompressed.ifs> <output.ifs> --chunk-size 65536
 */
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <lzo/lzo1x.h>

#define FLAGS1_COMPRESS_MASK   0x1c
#define FLAGS1_COMPRESS_SHIFT  2
#define COMPRESS_LZO           2

struct startup_header {
    uint32_t signature;
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

static void write_u16be(FILE *f, uint16_t v) {
    uint8_t buf[2] = { (v >> 8) & 0xff, v & 0xff };
    fwrite(buf, 1, 2, f);
}

/*
 * Mode 1: Reference-based compression.
 * Read chunk boundaries from original, apply to (potentially modified)
 * decompressed image. If decompressed image is same size and content,
 * output is bit-identical to original.
 */
static int compress_with_reference(
    const uint8_t *decomp, size_t decomp_size,
    FILE *orig_f, uint32_t orig_startup_size,
    FILE *out_f, uint32_t startup_size)
{
    /* Seek to chunk stream in original */
    fseek(orig_f, orig_startup_size, SEEK_SET);

    size_t BUFSZ = 8 * 1024 * 1024;
    uint8_t *cmpbuf = malloc(BUFSZ);
    uint8_t *outbuf = malloc(BUFSZ);
    uint8_t *decbuf = malloc(BUFSZ);
    uint8_t *wrkbuf = malloc(LZO1X_999_MEM_COMPRESS);
    if (!cmpbuf || !outbuf || !decbuf || !wrkbuf) return -1;

    size_t decomp_offset = 0;
    int chunks = 0;
    long total_compressed = 0;

    for (;;) {
        /* Read original chunk to learn decompressed size */
        uint8_t hdr[2];
        if (fread(hdr, 1, 2, orig_f) != 2) break;
        unsigned orig_clen = (hdr[0] << 8) | hdr[1];
        if (orig_clen == 0) break;
        if (orig_clen > BUFSZ) break;
        if (fread(cmpbuf, 1, orig_clen, orig_f) != orig_clen) break;

        /* Decompress original chunk to learn its decompressed size */
        lzo_uint orig_dec_len = BUFSZ;
        if (lzo1x_decompress(cmpbuf, orig_clen, decbuf, &orig_dec_len, NULL) != LZO_E_OK) {
            fprintf(stderr, "chunk %d: failed to decompress reference\n", chunks);
            free(cmpbuf); free(outbuf); free(decbuf); free(wrkbuf);
            return -1;
        }

        /* Take same number of bytes from our (modified) decompressed image */
        size_t take = orig_dec_len;
        if (decomp_offset + take > decomp_size) {
            take = decomp_size - decomp_offset;
        }
        if (take == 0) break;

        /* Compress with lzo1x_999 */
        lzo_uint new_clen = BUFSZ;
        if (lzo1x_999_compress(decomp + decomp_offset, take, outbuf, &new_clen, wrkbuf) != LZO_E_OK) {
            fprintf(stderr, "chunk %d: compress failed\n", chunks);
            free(cmpbuf); free(outbuf); free(decbuf); free(wrkbuf);
            return -1;
        }

        if (new_clen > 65535) {
            fprintf(stderr, "chunk %d: compressed size %lu exceeds u16 max!\n",
                    chunks, (unsigned long)new_clen);
            free(cmpbuf); free(outbuf); free(decbuf); free(wrkbuf);
            return -1;
        }

        write_u16be(out_f, (uint16_t)new_clen);
        fwrite(outbuf, 1, new_clen, out_f);
        total_compressed += 2 + new_clen;
        decomp_offset += take;
        chunks++;
    }

    /* Handle any remaining data (if modified image is larger) */
    while (decomp_offset < decomp_size) {
        size_t take = decomp_size - decomp_offset;
        if (take > 65536) take = 65536;  /* safe chunk size */

        lzo_uint new_clen = BUFSZ;
        if (lzo1x_999_compress(decomp + decomp_offset, take, outbuf, &new_clen, wrkbuf) != LZO_E_OK) {
            fprintf(stderr, "extra chunk: compress failed\n");
            break;
        }
        if (new_clen > 65535) {
            fprintf(stderr, "extra chunk: too large\n");
            break;
        }
        write_u16be(out_f, (uint16_t)new_clen);
        fwrite(outbuf, 1, new_clen, out_f);
        total_compressed += 2 + new_clen;
        decomp_offset += take;
        chunks++;
    }

    /* End-of-stream marker */
    write_u16be(out_f, 0);
    total_compressed += 2;

    fprintf(stderr, "compressed %d chunks, %ld bytes payload\n", chunks, total_compressed);
    free(cmpbuf); free(outbuf); free(decbuf); free(wrkbuf);
    return 0;
}

/*
 * Mode 2: Fixed chunk size compression.
 */
static int compress_fixed_chunks(
    const uint8_t *decomp, size_t decomp_size,
    FILE *out_f, size_t chunk_size)
{
    size_t BUFSZ = 8 * 1024 * 1024;
    uint8_t *outbuf = malloc(BUFSZ);
    uint8_t *wrkbuf = malloc(LZO1X_999_MEM_COMPRESS);
    if (!outbuf || !wrkbuf) return -1;

    size_t offset = 0;
    int chunks = 0;
    long total_compressed = 0;

    while (offset < decomp_size) {
        size_t take = decomp_size - offset;
        if (take > chunk_size) take = chunk_size;

        lzo_uint clen = BUFSZ;
        if (lzo1x_999_compress(decomp + offset, take, outbuf, &clen, wrkbuf) != LZO_E_OK) {
            fprintf(stderr, "chunk %d: compress failed\n", chunks);
            free(outbuf); free(wrkbuf);
            return -1;
        }
        if (clen > 65535) {
            fprintf(stderr, "chunk %d: compressed %lu > 65535, reduce chunk_size\n",
                    chunks, (unsigned long)clen);
            free(outbuf); free(wrkbuf);
            return -1;
        }

        write_u16be(out_f, (uint16_t)clen);
        fwrite(outbuf, 1, clen, out_f);
        total_compressed += 2 + clen;
        offset += take;
        chunks++;
    }

    write_u16be(out_f, 0);
    total_compressed += 2;

    fprintf(stderr, "compressed %d chunks (%zu-byte), %ld bytes payload\n",
            chunks, chunk_size, total_compressed);
    free(outbuf); free(wrkbuf);
    return 0;
}

int main(int argc, char *argv[])
{
    if (argc < 3) {
        fprintf(stderr,
            "usage: %s <decompressed.ifs> <output.ifs> [options]\n"
            "  --reference <original.ifs>   Use original chunk boundaries\n"
            "  --chunk-size <bytes>         Fixed chunk size (default: 65536)\n",
            argv[0]);
        return 2;
    }

    if (lzo_init() != LZO_E_OK) { fprintf(stderr, "lzo_init failed\n"); return 1; }

    const char *decomp_path = argv[1];
    const char *out_path = argv[2];
    const char *ref_path = NULL;
    size_t chunk_size = 65536;

    for (int i = 3; i < argc; i++) {
        if (strcmp(argv[i], "--reference") == 0 && i + 1 < argc)
            ref_path = argv[++i];
        else if (strcmp(argv[i], "--chunk-size") == 0 && i + 1 < argc)
            chunk_size = atoi(argv[++i]);
    }

    /* Read decompressed IFS */
    FILE *df = fopen(decomp_path, "rb");
    if (!df) { perror("open decompressed"); return 1; }
    fseek(df, 0, SEEK_END);
    size_t decomp_file_size = ftell(df);
    rewind(df);

    uint8_t *decomp_data = malloc(decomp_file_size);
    if (!decomp_data) { fprintf(stderr, "malloc %zu failed\n", decomp_file_size); return 1; }
    if (fread(decomp_data, 1, decomp_file_size, df) != decomp_file_size) {
        fprintf(stderr, "short read\n"); return 1;
    }
    fclose(df);

    /* Parse startup header from decompressed image */
    struct startup_header *sh = (struct startup_header *)decomp_data;
    if (sh->signature != 0x00FF7EEB) {
        fprintf(stderr, "bad signature: 0x%08x\n", sh->signature);
        return 1;
    }
    uint32_t startup_size = sh->startup_size;
    size_t imagefs_size = decomp_file_size - startup_size;

    fprintf(stderr, "decompressed: %zu bytes, startup=%u, imagefs=%zu\n",
            decomp_file_size, startup_size, imagefs_size);

    /* Open output */
    FILE *out = fopen(out_path, "wb");
    if (!out) { perror("open output"); return 1; }

    /* Write startup section (copy from decompressed, fix flags later) */
    /* Set compression flag to LZO */
    sh->flags1 = (sh->flags1 & ~FLAGS1_COMPRESS_MASK) | (COMPRESS_LZO << FLAGS1_COMPRESS_SHIFT);
    sh->imagefs_size = (uint32_t)imagefs_size;
    /* stored_size will be patched after compression */
    fwrite(decomp_data, 1, startup_size, out);

    /* Compress the imagefs payload */
    const uint8_t *payload = decomp_data + startup_size;
    int rc;

    if (ref_path) {
        FILE *ref = fopen(ref_path, "rb");
        if (!ref) { perror("open reference"); return 1; }
        struct startup_header ref_sh;
        if (fread(&ref_sh, sizeof(ref_sh), 1, ref) != 1) {
            fprintf(stderr, "read ref header failed\n"); return 1;
        }
        fprintf(stderr, "reference: startup=%u\n", ref_sh.startup_size);
        rc = compress_with_reference(payload, imagefs_size, ref, ref_sh.startup_size,
                                     out, startup_size);
        fclose(ref);
    } else {
        rc = compress_fixed_chunks(payload, imagefs_size, out, chunk_size);
    }

    if (rc != 0) {
        fprintf(stderr, "compression failed\n");
        fclose(out);
        return 1;
    }

    /* Patch stored_size in the output header */
    long total_size = ftell(out);
    fseek(out, offsetof(struct startup_header, stored_size), SEEK_SET);
    uint32_t stored = (uint32_t)total_size;
    fwrite(&stored, 4, 1, out);

    fprintf(stderr, "output: %ld bytes (stored_size=0x%x)\n", total_size, stored);
    fclose(out);
    free(decomp_data);
    return 0;
}
