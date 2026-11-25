/* Standalone interoperability check against upstream Zstd 1.6.0.
 * Run from the Vort root with a built upstream checkout:
 *   ZSTD="$HOME/Work/zstd"
 *   cc -std=c99 -O2 -Wall -Wextra -Werror -I"$ZSTD/lib" -I"$ZSTD/lib/common" \
 *     -I"$ZSTD/contrib/seekable_format" tools/zstd/source_seekable_encode_verify.c \
 *     "$ZSTD/contrib/seekable_format/zstdseek_compress.c" \
 *     "$ZSTD/contrib/seekable_format/zstdseek_decompress.c" \
 *     "$ZSTD/lib/libzstd.a" -pthread -o /tmp/vort-seekable-encode-verify
 *   /tmp/vort-seekable-encode-verify ARCHIVE PLAINTEXT [FRAME_SIZE|- [SEEK_CHECKSUM]]
 * FRAME_SIZE checks Vort's fixed-size split (one standard frame for empty input).
 * Use '-' to skip the split check. SEEK_CHECKSUM is 0 or 1 and controls the
 * expected seek-table checksum mode, not the standard Zstd frame checksum.
 * Both inputs must be regular files. No Vort code is linked.
 */
#define _FILE_OFFSET_BITS 64
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <inttypes.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>

#include <xxhash.h>
#include <zstd_seekable.h>

struct bytes {
    const unsigned char *data;
    size_t size;
};

struct seek_footer {
    size_t table_offset;
    unsigned frames;
    int checksums;
};

enum { BUFFER_SIZE = 64 * 1024, PROBE_SIZE = 128 };

static void fail(const char *format, ...)
{
    va_list args;
    va_start(args, format);
    fputs("verify: ", stderr);
    vfprintf(stderr, format, args);
    fputc('\n', stderr);
    va_end(args);
    exit(EXIT_FAILURE);
}

static size_t checked(size_t result, const char *operation)
{
    if (ZSTD_isError(result)) fail("%s: %s", operation, ZSTD_getErrorName(result));
    return result;
}

static FILE *open_input(const char *path)
{
    FILE *file = fopen(path, "rb");
    if (!file) fail("%s: %s", path, strerror(errno));
    return file;
}

static struct bytes map_input(FILE *file, const char *path)
{
    static const unsigned char empty;
    struct stat info;
    if (fstat(fileno(file), &info) != 0) fail("%s: %s", path, strerror(errno));
    if (!S_ISREG(info.st_mode) || info.st_size < 0 || (uintmax_t)info.st_size > SIZE_MAX)
        fail("%s: expected a regular file that fits in the address space", path);
    if (info.st_size == 0) return (struct bytes){ &empty, 0 };
    size_t size = (size_t)info.st_size;
    void *data = mmap(NULL, size, PROT_READ, MAP_PRIVATE, fileno(file), 0);
    if (data == MAP_FAILED) fail("%s: %s", path, strerror(errno));
    return (struct bytes){ data, size };
}

static uint32_t read_le32(const unsigned char *p)
{
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static size_t min_size(size_t a, size_t b)
{
    return a < b ? a : b;
}

static struct seek_footer read_footer(struct bytes archive)
{
    if (archive.size < 8 + ZSTD_seekTableFooterSize) fail("missing seek table");
    const unsigned char *footer = archive.data + archive.size - ZSTD_seekTableFooterSize;
    if (read_le32(footer + 5) != ZSTD_SEEKABLE_MAGICNUMBER) fail("bad seek table footer magic");
    uint32_t frames = read_le32(footer);
    int checksums = footer[4] >> 7;
    if (frames > ZSTD_SEEKABLE_MAXFRAMES) fail("seek table frame count exceeds upstream limit");
    size_t table_size = 8 + ZSTD_seekTableFooterSize + (size_t)frames * (checksums ? 12 : 8);
    if (table_size > archive.size) fail("seek table exceeds archive size");
    return (struct seek_footer){ archive.size - table_size, frames, checksums };
}

/* Decode the data prefix without using seek-table boundaries. This observes
 * actual compressed/decompressed lengths, completes even empty frames, and
 * verifies standard Zstd frame checksums if present. Then independently log
 * these lengths and XXH64s with upstream's canonical table serializer. */
static void verify_table(ZSTD_seekable *reader, struct bytes archive, struct bytes plain,
                         struct seek_footer footer, size_t frame_size)
{
    if (ZSTD_seekable_getNumFrames(reader) != footer.frames) fail("upstream frame count mismatch");
    if (frame_size) {
        size_t count = plain.size ? 1 + (plain.size - 1) / frame_size : 1;
        if (footer.frames != count)
            fail("expected %zu frames for frame size %zu, got %u", count, frame_size, footer.frames);
    }

    ZSTD_DStream *decoder = ZSTD_createDStream();
    ZSTD_frameLog *log = ZSTD_seekable_createFrameLog(footer.checksums);
    if (!decoder || !log) fail("cannot allocate upstream frame verifier");
    checked(ZSTD_initDStream(decoder), "ZSTD_initDStream");

    unsigned char buffer[BUFFER_SIZE];
    ZSTD_inBuffer in = { archive.data, footer.table_offset, 0 };
    size_t decoded = 0;
    for (unsigned frame = 0; frame < footer.frames; ++frame) {
        size_t compressed_start = in.pos, plain_start = decoded;
        if (frame_size && (in.size - in.pos < 4 ||
                           read_le32(archive.data + in.pos) != ZSTD_MAGICNUMBER))
            fail("frame %u is not a standard Zstd frame", frame);
        for (;;) {
            ZSTD_outBuffer out = { buffer, sizeof(buffer), 0 };
            size_t prev_in = in.pos;
            size_t need = checked(ZSTD_decompressStream(decoder, &out, &in), "ZSTD_decompressStream");
            if (out.pos > plain.size - decoded || memcmp(buffer, plain.data + decoded, out.pos) != 0)
                fail("plaintext mismatch in frame %u at output chunk starting at %zu", frame, decoded);
            decoded += out.pos;
            if (!need) break;
            if (prev_in == in.pos && !out.pos) fail("incomplete data frame %u", frame);
        }

        size_t compressed = in.pos - compressed_start, decompressed = decoded - plain_start;
        if (!compressed || compressed > UINT32_MAX || decompressed > UINT32_MAX)
            fail("frame %u sizes cannot be represented in the seek table", frame);
        if (ZSTD_seekable_getFrameCompressedOffset(reader, frame) != compressed_start ||
            ZSTD_seekable_getFrameDecompressedOffset(reader, frame) != plain_start ||
            ZSTD_seekable_getFrameCompressedSize(reader, frame) != compressed ||
            ZSTD_seekable_getFrameDecompressedSize(reader, frame) != decompressed)
            fail("frame %u metadata does not match the independently decoded frame", frame);
        if (frame_size && decompressed != min_size(frame_size, plain.size - plain_start))
            fail("frame %u has unexpected decompressed length %zu", frame, decompressed);
        uint32_t hash = footer.checksums ? (uint32_t)XXH64(plain.data + plain_start, decompressed, 0) : 0;
        checked(ZSTD_seekable_logFrame(log, (unsigned)compressed, (unsigned)decompressed, hash),
                "ZSTD_seekable_logFrame");
    }
    if (in.pos != in.size) fail("seek table does not cover all compressed frame bytes");
    if (decoded != plain.size) fail("decoded %zu of %zu expected plaintext bytes", decoded, plain.size);

    size_t table_pos = footer.table_offset;
    size_t left;
    do {
        ZSTD_outBuffer out = { buffer, sizeof(buffer), 0 };
        left = checked(ZSTD_seekable_writeSeekTable(log, &out), "ZSTD_seekable_writeSeekTable");
        if (out.pos > archive.size - table_pos || memcmp(buffer, archive.data + table_pos, out.pos) != 0)
            fail("seek table differs from upstream serialization (chunk starting at archive offset %zu)", table_pos);
        table_pos += out.pos;
    } while (left);
    if (table_pos != archive.size) fail("upstream seek table length differs from archive");
    ZSTD_seekable_freeFrameLog(log);
    ZSTD_freeDStream(decoder);
}

static void verify_range(ZSTD_seekable *reader, struct bytes plain, unsigned char *out,
                         size_t offset, size_t length)
{
    size_t want = min_size(length, plain.size - offset);
    size_t got = ZSTD_seekable_decompress(reader, out, length, offset);
    if (ZSTD_isError(got)) fail("seekable range at %zu: %s", offset, ZSTD_getErrorName(got));
    if (got != want || memcmp(out, plain.data + offset, got) != 0)
        fail("seekable range mismatch at %zu (requested %zu, expected %zu, got %zu)",
             offset, length, want, got);
}

static void verify_ranges(ZSTD_seekable *reader, struct bytes plain, unsigned frames)
{
    unsigned char out[BUFFER_SIZE];
    if (!plain.size) {
        verify_range(reader, plain, out, 0, 0);
        return;
    }

    /* Non-sequential reads exercise repositioning, EOF clipping, and up to
     * three frame crossings. Then read and compare every byte via initFile. */
    verify_range(reader, plain, out, plain.size - min_size(plain.size, PROBE_SIZE / 2), PROBE_SIZE);
    const unsigned boundaries[] = { frames ? frames - 1 : 0, frames / 2, 1 };
    for (size_t i = 0; i < sizeof(boundaries) / sizeof(boundaries[0]); ++i) {
        if (boundaries[i] == 0 || boundaries[i] >= frames ||
            (i != 0 && boundaries[i] == boundaries[i - 1])) continue;
        size_t cut = (size_t)ZSTD_seekable_getFrameDecompressedOffset(reader, boundaries[i]);
        if (cut && cut < plain.size)
            verify_range(reader, plain, out, cut - min_size(cut, PROBE_SIZE / 2), PROBE_SIZE);
    }
    verify_range(reader, plain, out, plain.size / 2, PROBE_SIZE);
    for (size_t offset = 0; offset < plain.size;) {
        size_t length = min_size(sizeof(out), plain.size - offset);
        verify_range(reader, plain, out, offset, length);
        offset += length;
    }
}

int main(int argc, char **argv)
{
    if (argc < 3 || argc > 5) {
        fprintf(stderr, "usage: %s ARCHIVE PLAINTEXT [FRAME_SIZE|- [SEEK_CHECKSUM:0|1]]\n", argv[0]);
        return EXIT_FAILURE;
    }
    size_t frame_size = 0;
    if (argc >= 4 && strcmp(argv[3], "-") != 0) {
        if (!argv[3][0] || strspn(argv[3], "0123456789") != strlen(argv[3]))
            fail("expected a positive decimal frame size or '-'");
        errno = 0;
        uintmax_t n = strtoumax(argv[3], NULL, 10);
        if (errno || n == 0 || n > ZSTD_SEEKABLE_MAX_FRAME_DECOMPRESSED_SIZE)
            fail("expected frame size in 1..%u", ZSTD_SEEKABLE_MAX_FRAME_DECOMPRESSED_SIZE);
        frame_size = (size_t)n;
    }
    int expected_checksums = -1;
    if (argc == 5) {
        if (strcmp(argv[4], "0") == 0) expected_checksums = 0;
        else if (strcmp(argv[4], "1") == 0) expected_checksums = 1;
        else fail("expected seek-table checksum flag of 0 or 1");
    }
    if (ZSTD_versionNumber() != 10600) fail("expected upstream Zstd 1.6.0, got %s", ZSTD_versionString());

    FILE *file = open_input(argv[1]);
    FILE *plain_file = open_input(argv[2]);
    struct bytes archive = map_input(file, argv[1]);
    struct bytes plain = map_input(plain_file, argv[2]);
    struct seek_footer footer = read_footer(archive);
    if (expected_checksums >= 0 && footer.checksums != expected_checksums)
        fail("expected seek-table checksum flag %d, got %d", expected_checksums, footer.checksums);

    ZSTD_seekable *reader = ZSTD_seekable_create();
    if (!reader) fail("cannot allocate upstream seekable reader");
    checked(ZSTD_seekable_initFile(reader, file), "ZSTD_seekable_initFile");
    verify_table(reader, archive, plain, footer, frame_size);
    verify_ranges(reader, plain, footer.frames);
    ZSTD_seekable_free(reader);

    munmap((void *)archive.data, archive.size);
    if (plain.size) munmap((void *)plain.data, plain.size);
    fclose(plain_file);
    fclose(file);
    printf("zstd=%s frames=%u seek_checksum=%d plaintext_bytes=%zu seek_table_bytes=%zu verified\n",
           ZSTD_versionString(), footer.frames, footer.checksums, plain.size,
           archive.size - footer.table_offset);
    return EXIT_SUCCESS;
}
