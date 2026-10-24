/* Header-owned libzstd parameters for independent HQ wire generation. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdint.h>
#include <stddef.h>
#include <zstd.h>
#include <zdict.h>

uint32_t hqr_header_version(void) { return ZSTD_VERSION_NUMBER; }
uint32_t hqr_runtime_version(void) { return ZSTD_versionNumber(); }
const char *hqr_version_string(void) { return ZSTD_versionString(); }
const char *hqr_runtime_library_path(void) {
    Dl_info info;
    return dladdr((void *)ZSTD_versionNumber, &info) ? info.dli_fname : NULL;
}

typedef struct {
    int32_t level;
    uint32_t strategy, search_log, min_match, target_length, window_log;
    uint32_t checksum, content_size;
} HqControls;
size_t hqr_controls_size(void) { return sizeof(HqControls); }

size_t hqr_encode(const HqControls *controls,
                  const uint8_t *input, size_t input_size,
                  const uint8_t *dictionary, size_t dictionary_size,
                  uint8_t *output, size_t output_capacity) {
    ZSTD_CCtx *context = ZSTD_createCCtx();
    if (!context) return (size_t)-1;
    size_t result = 0;
#define PARAM(name, value) do { \
    result = ZSTD_CCtx_setParameter(context, name, value); \
    if (ZSTD_isError(result)) goto finish; \
} while (0)
    PARAM(ZSTD_c_compressionLevel, controls->level);
    if (controls->strategy) PARAM(ZSTD_c_strategy, controls->strategy);
    if (controls->search_log) PARAM(ZSTD_c_searchLog, controls->search_log);
    if (controls->min_match) PARAM(ZSTD_c_minMatch, controls->min_match);
    if (controls->target_length) PARAM(ZSTD_c_targetLength, controls->target_length);
    if (controls->window_log) PARAM(ZSTD_c_windowLog, controls->window_log);
    PARAM(ZSTD_c_checksumFlag, controls->checksum);
    PARAM(ZSTD_c_contentSizeFlag, controls->content_size);
    PARAM(ZSTD_c_dictIDFlag, 1);
    result = ZSTD_CCtx_loadDictionary(context, dictionary, dictionary_size);
    if (ZSTD_isError(result)) goto finish;
    result = ZSTD_compress2(context, output, output_capacity, input, input_size);
finish:
    ZSTD_freeCCtx(context);
    return result;
#undef PARAM
}

size_t hqr_decode(const uint8_t *input, size_t input_size,
                  const uint8_t *dictionary, size_t dictionary_size,
                  uint8_t *output, size_t output_capacity) {
    ZSTD_DCtx *context = ZSTD_createDCtx();
    if (!context) return (size_t)-1;
    size_t result = ZSTD_decompress_usingDict(context, output, output_capacity,
                                            input, input_size, dictionary, dictionary_size);
    ZSTD_freeDCtx(context);
    return result;
}

size_t hqr_decode_ddict(const uint8_t *input, size_t input_size,
                        const uint8_t *dictionary, size_t dictionary_size,
                        uint8_t *output, size_t output_capacity) {
    ZSTD_DCtx *context = ZSTD_createDCtx();
    ZSTD_DDict *ddict = ZSTD_createDDict(dictionary, dictionary_size);
    if (!context || !ddict) {
        ZSTD_freeDDict(ddict);
        ZSTD_freeDCtx(context);
        return (size_t)-1;
    }
    size_t result = ZSTD_decompress_usingDDict(context, output, output_capacity, input, input_size, ddict);
    ZSTD_freeDDict(ddict);
    ZSTD_freeDCtx(context);
    return result;
}

size_t hqr_train(const uint8_t *samples, const size_t *sizes, uint32_t count,
                 uint8_t *dictionary, size_t capacity) {
    return ZDICT_trainFromBuffer(dictionary, capacity, samples, sizes, count);
}
