/* Installed headers own all LZ4 frame and stream layouts crossing this helper. */
#define _GNU_SOURCE
#define LZ4F_STATIC_LINKING_ONLY
#include <dlfcn.h>
#include <stdint.h>
#include <stddef.h>
#include <limits.h>
#include <lz4.h>
#include <lz4frame.h>

uint32_t lfcr_header_version(void) { return LZ4_VERSION_NUMBER; }
uint32_t lfcr_runtime_version(void) { return LZ4_versionNumber(); }
const char *lfcr_version_string(void) { return LZ4_versionString(); }
const char *lfcr_runtime_library_path(void) {
    Dl_info info;
    return dladdr((void *)LZ4_versionNumber, &info) ? info.dli_fname : NULL;
}

typedef struct {
    int32_t acceleration, frame_level;
    uint32_t block_size_id, block_independent, content_size, content_checksum, block_checksum, dictionary_id;
} Controls;
size_t lfcr_controls_size(void) { return sizeof(Controls); }
size_t lfcr_frame_preferences_size(void) { return sizeof(LZ4F_preferences_t); }

int lfcr_block_encode(int32_t acceleration, const uint8_t *input, size_t input_size,
                      const uint8_t *dictionary, size_t dictionary_size,
                      uint8_t *output, size_t capacity) {
    if (input_size > INT_MAX || capacity > INT_MAX || dictionary_size > INT_MAX) return 0;
    if (!dictionary_size)
        return LZ4_compress_fast((const char *)input, (char *)output, (int)input_size, (int)capacity, acceleration);
    LZ4_stream_t *stream = LZ4_createStream();
    if (!stream) return 0;
    LZ4_loadDict(stream, (const char *)dictionary, (int)dictionary_size);
    int result = LZ4_compress_fast_continue(stream, (const char *)input, (char *)output,
                                          (int)input_size, (int)capacity, acceleration);
    LZ4_freeStream(stream);
    return result;
}

int lfcr_block_decode(const uint8_t *input, size_t input_size,
                      const uint8_t *dictionary, size_t dictionary_size,
                      uint8_t *output, size_t capacity) {
    if (input_size > INT_MAX || capacity > INT_MAX || dictionary_size > INT_MAX) return -1;
    return LZ4_decompress_safe_usingDict((const char *)input, (char *)output, (int)input_size, (int)capacity,
                                        (const char *)dictionary, (int)dictionary_size);
}

static LZ4F_preferences_t preferences(const Controls *controls) {
    LZ4F_preferences_t options = {0};
    options.frameInfo.blockSizeID = (LZ4F_blockSizeID_t)controls->block_size_id;
    options.frameInfo.blockMode = controls->block_independent ? LZ4F_blockIndependent : LZ4F_blockLinked;
    options.frameInfo.contentChecksumFlag = controls->content_checksum ? LZ4F_contentChecksumEnabled : LZ4F_noContentChecksum;
    options.frameInfo.blockChecksumFlag = controls->block_checksum ? LZ4F_blockChecksumEnabled : LZ4F_noBlockChecksum;
    options.frameInfo.dictID = controls->dictionary_id;
    options.compressionLevel = controls->frame_level;
    return options;
}

size_t lfcr_frame_bound(const Controls *controls, size_t input_size) {
    LZ4F_preferences_t options = preferences(controls);
    options.frameInfo.contentSize = controls->content_size ? input_size : 0;
    return LZ4F_compressFrameBound(input_size, &options);
}

size_t lfcr_frame_encode(const Controls *controls, const uint8_t *input, size_t input_size,
                         const uint8_t *dictionary, size_t dictionary_size,
                         uint8_t *output, size_t capacity) {
    LZ4F_preferences_t options = preferences(controls);
    options.frameInfo.contentSize = controls->content_size ? input_size : 0;
    if (!dictionary_size) return LZ4F_compressFrame(output, capacity, input, input_size, &options);
    LZ4F_cctx *context = NULL;
    size_t result = LZ4F_createCompressionContext(&context, LZ4F_VERSION);
    if (LZ4F_isError(result)) return result;
    LZ4F_CDict *cdict = LZ4F_createCDict(dictionary, dictionary_size);
    if (!cdict) { LZ4F_freeCompressionContext(context); return (size_t)-1; }
    result = LZ4F_compressFrame_usingCDict(context, output, capacity, input, input_size, cdict, &options);
    LZ4F_freeCDict(cdict);
    LZ4F_freeCompressionContext(context);
    return result;
}

size_t lfcr_frame_decode(const uint8_t *input, size_t input_size,
                         const uint8_t *dictionary, size_t dictionary_size,
                         uint8_t *output, size_t capacity, size_t *read, size_t *written) {
    *read = *written = 0;
    LZ4F_dctx *context = NULL;
    size_t result = LZ4F_createDecompressionContext(&context, LZ4F_VERSION);
    if (LZ4F_isError(result)) return result;
    for (size_t steps = 0; steps < input_size + capacity + 32; ++steps) {
        size_t consumed = input_size - *read, produced = capacity - *written;
        result = LZ4F_decompress_usingDict(context, output + *written, &produced, input + *read, &consumed,
                                          dictionary, dictionary_size, NULL);
        *read += consumed;
        *written += produced;
        if (LZ4F_isError(result) || result == 0) break;
        if (!consumed && !produced) { result = (size_t)-1; break; }
    }
    LZ4F_freeDecompressionContext(context);
    return result;
}
