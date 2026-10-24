#define _GNU_SOURCE
#define XXH_INLINE_ALL
#include <dlfcn.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <zstd.h>
#include <brotli/decode.h>
#include <xxhash.h>

typedef struct {
    uint64_t input_read, output_written, calls, content_checks, xxh64;
    uint32_t done, failed;
} Receipt;
typedef struct {
    uint32_t family, pattern;
    uint64_t expected, prefix;
    const uint8_t *tail;
    size_t tail_size;
    ZSTD_DStream *zstd;
    BrotliDecoderState *br;
    XXH64_state_t hash;
    Receipt result;
    uint8_t output[65536];
    uint8_t pattern_bytes[65536];
} State;
static const uint8_t zero_tail[] = "vort-4GiB-tail!!!";

uint32_t rc_zstd_header_version(void) { return ZSTD_VERSION_NUMBER; }
uint32_t rc_zstd_version(void) { return ZSTD_versionNumber(); }
uint32_t rc_br_version(void) { return BrotliDecoderVersion(); }
size_t rc_receipt_size(void) { return sizeof(Receipt); }
const char *rc_library_path(uint32_t family) {
    Dl_info info;
    return dladdr(family ? (void *)BrotliDecoderVersion : (void *)ZSTD_versionNumber, &info) ? info.dli_fname : NULL;
}
static int verify(State *state, const uint8_t *data, size_t size) {
    for (size_t index = 0; index < size; ++index) {
        uint64_t position = state->result.output_written + index;
        if (position >= state->expected) return 0;
        uint8_t expected;
        if (state->pattern == 0) expected = 'R';
        else if (state->pattern == 1) expected = position < state->prefix ? 0 : zero_tail[position - state->prefix];
        else if (position < state->prefix) expected = state->pattern_bytes[position % 65536];
        else if (state->tail) expected = state->tail[position - state->prefix];
        else expected = state->pattern_bytes[position % 65536];
        if (data[index] != expected) return 0;
    }
    XXH64_update(&state->hash, data, size);
    state->result.output_written += size;
    state->result.content_checks += 1;
    return 1;
}
void *rc_create(uint32_t family, uint32_t kind, uint64_t expected, uint64_t prefix,
                 const uint8_t *tail, size_t tail_size) {
    State *state = calloc(1, sizeof(*state));
    if (!state) return NULL;
    state->family = family; state->pattern = kind; state->expected = expected;
    state->prefix = prefix; state->tail = tail; state->tail_size = tail_size;
    uint32_t random = 0x51a7c0de;
    for (size_t index = 0; index < sizeof(state->pattern_bytes); ++index) {
        random ^= random << 13; random ^= random >> 17; random ^= random << 5;
        state->pattern_bytes[index] = (uint8_t)random;
    }
    XXH64_reset(&state->hash, 0);
    if (family == 0) {
        state->zstd = ZSTD_createDStream();
        if (!state->zstd || ZSTD_isError(ZSTD_initDStream(state->zstd))) { free(state); return NULL; }
    } else {
        state->br = BrotliDecoderCreateInstance(NULL, NULL, NULL);
        if (!state->br) { free(state); return NULL; }
    }
    return state;
}
int rc_feed(void *opaque, const uint8_t *input, size_t size) {
    State *state = opaque;
    size_t offset = 0;
    for (;;) {
        size_t produced = 0, consumed = 0;
        if (state->family == 0) {
            ZSTD_inBuffer source = {input, size, offset};
            ZSTD_outBuffer output = {state->output, sizeof(state->output), 0};
            size_t result = ZSTD_decompressStream(state->zstd, &output, &source);
            if (ZSTD_isError(result)) { state->result.failed = 1; return -1; }
            consumed = source.pos - offset; produced = output.pos; state->result.done = result == 0;
        } else {
            size_t available_in = size - offset, available_out = sizeof(state->output);
            const uint8_t *next_in = input + offset;
            uint8_t *next_out = state->output;
            BrotliDecoderResult result = BrotliDecoderDecompressStream(state->br, &available_in, &next_in,
                                                                      &available_out, &next_out, NULL);
            if (result == BROTLI_DECODER_RESULT_ERROR) { state->result.failed = 1; return -2; }
            consumed = size - offset - available_in; produced = sizeof(state->output) - available_out;
            state->result.done = result == BROTLI_DECODER_RESULT_SUCCESS;
        }
        state->result.calls += 1;
        offset += consumed; state->result.input_read += consumed;
        if (!verify(state, state->output, produced)) { state->result.failed = 1; return -3; }
        if (state->result.done) return offset == size ? 0 : -4;
        if (offset == size && produced < sizeof(state->output)) return 0;
        if (!consumed && !produced) return offset == size ? 0 : -5;
    }
}
int rc_finish(void *opaque, Receipt *receipt) {
    State *state = opaque;
    state->result.xxh64 = XXH64_digest(&state->hash);
    *receipt = state->result;
    return state->result.done && !state->result.failed && state->result.output_written == state->expected ? 0 : -1;
}
void rc_destroy(void *opaque) {
    State *state = opaque;
    if (!state) return;
    if (state->zstd) ZSTD_freeDStream(state->zstd);
    if (state->br) BrotliDecoderDestroyInstance(state->br);
    free(state);
}
static void le(uint8_t *out, uint64_t value, size_t bytes) {
    for (size_t i = 0; i < bytes; ++i) out[i] = (uint8_t)(value >> (8 * i));
}
size_t rc_rle_fixture(uint64_t length, uint8_t *output, size_t capacity, uint64_t *checksum) {
    const uint64_t blocks = length / 131072 + (length % 131072 != 0);
    if (!length || blocks > (capacity - 18) / 4) return 0;
    XXH64_state_t hash;
    XXH64_reset(&hash, 0);
    uint8_t plain[65536]; memset(plain, 'R', sizeof(plain));
    for (uint64_t remaining = length; remaining;) {
        size_t size = remaining < sizeof(plain) ? (size_t)remaining : sizeof(plain);
        XXH64_update(&hash, plain, size); remaining -= size;
    }
    *checksum = XXH64_digest(&hash);
    memcpy(output, "\x28\xb5\x2f\xfd\xc4\x50", 6);
    le(output + 6, length, 8);
    size_t offset = 14;
    for (uint64_t remaining = length; remaining;) {
        uint32_t size = remaining < 131072 ? (uint32_t)remaining : 131072;
        remaining -= size;
        le(output + offset, ((uint64_t)size << 3) | 2 | (remaining == 0), 3);
        output[offset + 3] = 'R'; offset += 4;
    }
    le(output + offset, *checksum, 4);
    return offset + 4;
}
