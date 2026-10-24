#include <lzma.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <stdbool.h>

/* Only this pointer ABI crosses ctypes. Installed liblzma structs and enum
 * values are handled by the matching C header rather than guessed in Python. */
typedef struct {
    uint32_t dictionary_size, lc, lp, pb, mode, finder, nice_len, depth;
} Controls;

uint32_t ecr_header_version(void) { return LZMA_VERSION; }
uint32_t ecr_runtime_version(void) { return lzma_version_number(); }
const char *ecr_version_string(void) { return lzma_version_string(); }
size_t ecr_controls_size(void) { return sizeof(Controls); }

int ecr_preset(uint32_t level, uint32_t extreme, Controls *out) {
    lzma_options_lzma p;
    memset(&p, 0, sizeof(p));
    if (lzma_lzma_preset(&p, level | (extreme ? LZMA_PRESET_EXTREME : 0)))
        return LZMA_OPTIONS_ERROR;
    *out = (Controls){p.dict_size, p.lc, p.lp, p.pb, p.mode, p.mf,
                      p.nice_len, p.depth};
    return LZMA_OK;
}

static int configure(const Controls *c, lzma_options_lzma *p) {
    memset(p, 0, sizeof(*p));
    if (lzma_lzma_preset(p, 6)) return LZMA_OPTIONS_ERROR;
    p->dict_size = c->dictionary_size;
    p->lc = c->lc;
    p->lp = c->lp;
    p->pb = c->pb;
    p->mode = (lzma_mode)c->mode;
    p->mf = (lzma_match_finder)c->finder;
    p->nice_len = c->nice_len;
    p->depth = c->depth;
    return LZMA_OK;
}

/* format: 0=raw LZMA1, 1=raw LZMA2, 2=modern MicroLZMA, 3=LZMA-Alone,
 * 4=XZ. Filter IDs are XZ delta=3 / BCJ IDs; zero means no prefilter. */
int ecr_encode(uint32_t format, const Controls *c, uint32_t check,
               uint32_t filter_id, uint32_t filter_argument,
               const uint8_t *input, size_t input_size,
               uint8_t *output, size_t output_size, size_t *written) {
    lzma_options_lzma p;
    int configured = configure(c, &p);
    if (configured != LZMA_OK) return configured;
    *written = 0;
    lzma_options_delta delta;
    memset(&delta, 0, sizeof(delta));
    delta.type = LZMA_DELTA_TYPE_BYTE;
    delta.dist = filter_argument;
    lzma_options_bcj bcj;
    memset(&bcj, 0, sizeof(bcj));
    bcj.start_offset = filter_argument;
    lzma_filter filters[3];
    size_t n = 0;
    if (filter_id) filters[n++] = (lzma_filter){filter_id, filter_id == 3 ? (void *)&delta : (void *)&bcj};
    filters[n++] = (lzma_filter){format == 0 ? LZMA_FILTER_LZMA1 : LZMA_FILTER_LZMA2, &p};
    filters[n] = (lzma_filter){LZMA_VLI_UNKNOWN, NULL};
    if (format < 2)
        return lzma_raw_buffer_encode(filters, NULL, input, input_size, output, written, output_size);
    if (format == 4)
        return lzma_stream_buffer_encode(filters, (lzma_check)check, NULL, input, input_size, output, written, output_size);
    lzma_stream stream = LZMA_STREAM_INIT;
    lzma_ret result = format == 2 ? lzma_microlzma_encoder(&stream, &p) : lzma_alone_encoder(&stream, &p);
    if (result == LZMA_OK) {
        stream.next_in = input;
        stream.avail_in = input_size;
        stream.next_out = output;
        stream.avail_out = output_size;
        result = lzma_code(&stream, LZMA_FINISH);
        *written = output_size - stream.avail_out;
        if (result == LZMA_STREAM_END && stream.avail_in == 0) result = LZMA_OK;
    }
    lzma_end(&stream);
    return result;
}

int ecr_decode(uint32_t format, const Controls *c,
               const uint8_t *input, size_t input_size,
               uint8_t *output, size_t output_size,
               size_t *read, size_t *written) {
    *read = *written = 0;
    if (format < 2) {
        lzma_options_lzma p;
        int configured = configure(c, &p);
        if (configured != LZMA_OK) return configured;
        lzma_filter filters[2] = {{format == 0 ? LZMA_FILTER_LZMA1 : LZMA_FILTER_LZMA2, &p}, {LZMA_VLI_UNKNOWN, NULL}};
        return lzma_raw_buffer_decode(filters, NULL, input, read, input_size, output, written, output_size);
    }
    lzma_stream stream = LZMA_STREAM_INIT;
    lzma_ret result = format == 2
        ? lzma_microlzma_decoder(&stream, input_size, output_size, true, c->dictionary_size)
        : (format == 3 ? lzma_alone_decoder(&stream, UINT64_MAX) : lzma_stream_decoder(&stream, UINT64_MAX, LZMA_CONCATENATED));
    if (result == LZMA_OK) {
        stream.next_in = input;
        stream.avail_in = input_size;
        stream.next_out = output;
        stream.avail_out = output_size;
        result = lzma_code(&stream, LZMA_FINISH);
        *read = input_size - stream.avail_in;
        *written = output_size - stream.avail_out;
        if (result == LZMA_STREAM_END) result = LZMA_OK;
    }
    lzma_end(&stream);
    return result;
}
