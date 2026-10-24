#define _GNU_SOURCE
#include <dlfcn.h>
#include <stddef.h>
#include <stdint.h>
#include <zstd.h>

uint32_t zlh_header_version(void) { return ZSTD_VERSION_NUMBER; }
uint32_t zlh_runtime_version(void) { return ZSTD_versionNumber(); }
const char *zlh_runtime_path(void) {
    Dl_info info;
    return dladdr((void *)ZSTD_versionNumber, &info) ? info.dli_fname : NULL;
}

size_t zlh_encode(const uint8_t *input, size_t input_size, uint8_t *output,
                  size_t capacity, int level, int window_log) {
    ZSTD_CCtx *context = ZSTD_createCCtx();
    if (!context) return (size_t)-1;
    size_t result = ZSTD_CCtx_setParameter(context, ZSTD_c_compressionLevel, level);
    if (!ZSTD_isError(result)) result = ZSTD_CCtx_setParameter(context, ZSTD_c_windowLog, window_log);
    if (!ZSTD_isError(result)) result = ZSTD_compress2(context, output, capacity, input, input_size);
    ZSTD_freeCCtx(context);
    return result;
}

/* Genuine stream decoder with explicit maximum window, not a one-shot helper
   whose resource policy would hide the requested decoder window. */
size_t zlh_decode(const uint8_t *input, size_t input_size, uint8_t *output,
                  size_t capacity, int maximum_window_log,
                  size_t *read, size_t *written) {
    ZSTD_DCtx *context = ZSTD_createDCtx();
    if (!context) return (size_t)-1;
    size_t result = ZSTD_DCtx_setParameter(context, ZSTD_d_windowLogMax, maximum_window_log);
    ZSTD_inBuffer source = { input, input_size, 0 };
    ZSTD_outBuffer destination = { output, capacity, 0 };
    if (!ZSTD_isError(result)) {
        do {
            const size_t previous_in = source.pos, previous_out = destination.pos;
            result = ZSTD_decompressStream(context, &destination, &source);
            if (ZSTD_isError(result) || result == 0) break;
            if (source.pos == previous_in && destination.pos == previous_out) break;
        } while (source.pos < source.size && destination.pos < destination.size);
    }
    *read = source.pos;
    *written = destination.pos;
    ZSTD_freeDCtx(context);
    return result;
}

size_t zlh_decode_dictionary(const uint8_t *input, size_t input_size,
                            const uint8_t *dictionary, size_t dictionary_size,
                            uint8_t *output, size_t capacity,
                            int maximum_window_log, size_t *read, size_t *written) {
    ZSTD_DCtx *context = ZSTD_createDCtx();
    if (!context) return (size_t)-1;
    size_t result = ZSTD_DCtx_setParameter(context, ZSTD_d_windowLogMax, maximum_window_log);
    if (!ZSTD_isError(result)) result = ZSTD_DCtx_loadDictionary(context, dictionary, dictionary_size);
    ZSTD_inBuffer source = { input, input_size, 0 };
    ZSTD_outBuffer destination = { output, capacity, 0 };
    if (!ZSTD_isError(result)) {
        do {
            const size_t previous_in = source.pos, previous_out = destination.pos;
            result = ZSTD_decompressStream(context, &destination, &source);
            if (ZSTD_isError(result) || result == 0) break;
            if (source.pos == previous_in && destination.pos == previous_out) break;
        } while (source.pos < source.size && destination.pos < destination.size);
    }
    *read = source.pos;
    *written = destination.pos;
    ZSTD_freeDCtx(context);
    return result;
}
