/* Reproduce src/tests/zstd_source_decode/seekable_dictionary.zig constants
 * with upstream Zstd 1.6.0, commit 01b7154f1172432f8abe9b3bb9909e14a1176b7d.
 * From the Vort root, with ZSTD pointing to that built checkout:
 *   cc -std=c99 -Wall -Wextra -Werror -I"$ZSTD/lib" \
 *     tools/zstd/source_seekable_dictionary_fixture.c "$ZSTD/lib/libzstd.a" -pthread \
 *     -o /tmp/vort-seekable-dictionary-fixture
 *   /tmp/vort-seekable-dictionary-fixture
 */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define ZSTD_STATIC_LINKING_ONLY
#include <zdict.h>
#include <zstd.h>

struct fixture {
    unsigned id;
    const char *pattern;
    unsigned char dict[256];
    size_t dict_size;
    char plain[256];
    size_t plain_size;
    unsigned char frame[256];
    size_t frame_size;
    size_t frame_header;
};

enum { REPEAT = 3, SAMPLE_COUNT = 128, SAMPLE_CAPACITY = 160 };

static void create(struct fixture *f)
{
    char samples[SAMPLE_COUNT * SAMPLE_CAPACITY];
    size_t sizes[SAMPLE_COUNT], used = 0;
    for (unsigned i = 0; i < SAMPLE_COUNT; ++i) {
        int len = snprintf(samples + used, SAMPLE_CAPACITY,
                           "id=%03u/%02u;%s:bucket=%u;serial=%05u;\n",
                           i, i % 11, f->pattern, i % 7, i * 19 + 67);
        assert(len > 0 && len < SAMPLE_CAPACITY);
        sizes[i] = (size_t)len;
        used += sizes[i];
    }
    f->dict_size = ZDICT_trainFromBuffer(f->dict, sizeof(f->dict), samples,
                                         sizes, SAMPLE_COUNT);
    assert(!ZDICT_isError(f->dict_size));
    /* Only replace the trained dictionary's ID, a little-endian wire field.
     * The independent upstream entropy tables and history stay unchanged. */
    for (size_t i = 0; i < 4; ++i)
        f->dict[4 + i] = (unsigned char)(f->id >> (8 * i));
    assert(ZSTD_getDictID_fromDict(f->dict, f->dict_size) == f->id);

    const size_t pattern_len = strlen(f->pattern);
    f->plain_size = REPEAT * pattern_len;
    assert(f->plain_size <= sizeof(f->plain));
    for (size_t i = 0; i < REPEAT; ++i)
        memcpy(f->plain + i * pattern_len, f->pattern, pattern_len);

    ZSTD_CCtx *cctx = ZSTD_createCCtx();
    assert(cctx != NULL);
    assert(!ZSTD_isError(ZSTD_CCtx_loadDictionary(cctx, f->dict, f->dict_size)));
    assert(!ZSTD_isError(ZSTD_CCtx_setParameter(cctx, ZSTD_c_compressionLevel, 5)));
    assert(!ZSTD_isError(ZSTD_CCtx_setParameter(cctx, ZSTD_c_checksumFlag, 1)));
    f->frame_size = ZSTD_compress2(cctx, f->frame, sizeof(f->frame),
                                   f->plain, f->plain_size);
    assert(!ZSTD_isError(f->frame_size));
    ZSTD_freeCCtx(cctx);

    ZSTD_frameHeader header;
    assert(ZSTD_getFrameHeader(&header, f->frame, f->frame_size) == 0);
    assert(header.dictID == f->id && header.checksumFlag == 1);
    assert(header.frameContentSize == f->plain_size);
    f->frame_header = header.headerSize;
}

static void verify(const struct fixture *f, const struct fixture *other)
{
    ZSTD_DCtx *dctx = ZSTD_createDCtx();
    assert(dctx != NULL);
    char decoded[sizeof(f->plain)];
    size_t size = ZSTD_decompress_usingDict(dctx, decoded, sizeof(decoded),
                                             f->frame, f->frame_size,
                                             f->dict, f->dict_size);
    assert(size == f->plain_size && memcmp(decoded, f->plain, size) == 0);
    size = ZSTD_decompress_usingDict(dctx, decoded, sizeof(decoded),
                                      f->frame, f->frame_size, NULL, 0);
    assert(ZSTD_isError(size));
    /* Even if the wrong dictionary has the expected ID, upstream rejects
     * its entropy/history. These are not frames that merely carry an ID. */
    unsigned char wrong[sizeof(other->dict)];
    memcpy(wrong, other->dict, other->dict_size);
    memcpy(wrong + 4, f->dict + 4, 4);
    size = ZSTD_decompress_usingDict(dctx, decoded, sizeof(decoded),
                                      f->frame, f->frame_size,
                                      wrong, other->dict_size);
    assert(ZSTD_isError(size));
    ZSTD_freeDCtx(dctx);
}

static void print_bytes(const char *name, char suffix,
                        const unsigned char *bytes, size_t size)
{
    printf("const %s_%c = [_]u8{\n", name, suffix);
    for (size_t i = 0; i < size; ++i) {
        if (i % 12 == 0) fputs("    ", stdout);
        printf("0x%02x,%c", (unsigned)bytes[i],
               i % 12 == 11 || i + 1 == size ? '\n' : ' ');
    }
    puts("};");
}

static void print(const struct fixture *f, char suffix)
{
    printf("const plain_%c = \"%s\" ** %d;\n", suffix, f->pattern, REPEAT);
    printf("const header_%c = %zu;\n", suffix, f->frame_header);
    print_bytes("dict", suffix, f->dict, f->dict_size);
    print_bytes("frame", suffix, f->frame, f->frame_size);
}

int main(void)
{
    assert(ZSTD_versionNumber() == 10600);
    struct fixture a = { .id = 0x12345678,
                         .pattern = "alpha/warehouse/temperature=301.25K;pressure=1000hPa;" };
    struct fixture b = { .id = 0x23456789,
                         .pattern = "bravo/drive/events=write,append,commit;sector=65536;" };
    create(&a);
    create(&b);
    verify(&a, &b);
    verify(&b, &a);
    print(&a, 'a');
    print(&b, 'b');
    return 0;
}
