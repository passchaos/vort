/* Opaque reference states and parameters come from the actual Brotli headers. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <brotli/encode.h>
#include <brotli/decode.h>
#ifdef BHQR_MODERN
#include <common/version.h>
#include <common/dictionary.h>
#include <common/transform.h>
#endif

typedef struct {
    uint32_t quality, mode, window_bits, npostfix, ndirect_high, lgblock;
} Controls;
typedef struct {
    uint32_t type;
    const uint8_t *data;
    size_t size;
} Dictionary;
enum {
    BHQR_OK = 0, BHQR_STATE_FAILED = 1, BHQR_PARAMETER_FAILED = 2,
    BHQR_DICTIONARY_FAILED = 3, BHQR_OUTPUT_LIMIT = 4,
    BHQR_UNSUPPORTED_DICTIONARY = 5, BHQR_CODEC_FAILED = 6,
    BHQR_INPUT_ACCOUNTING = 7
};

uint32_t bhqr_header_version(void) {
#ifdef BHQR_MODERN
    return BROTLI_VERSION;
#else
    /* System public headers do not publish a package-version macro. */
    return 0;
#endif
}
uint32_t bhqr_encoder_version(void) { return BrotliEncoderVersion(); }
uint32_t bhqr_decoder_version(void) { return BrotliDecoderVersion(); }
uint32_t bhqr_dictionary_api(void) {
#ifdef BHQR_MODERN
    return 1;
#else
    return 0;
#endif
}
size_t bhqr_controls_size(void) { return sizeof(Controls); }
size_t bhqr_dictionary_size(void) { return sizeof(Dictionary); }
const char *bhqr_library_path(uint32_t side) {
    Dl_info info;
    const void *symbol = side == 0 ? (void *)BrotliEncoderVersion : side == 1 ? (void *)BrotliDecoderVersion
        : dlsym(RTLD_DEFAULT, "BrotliGetDictionary");
    return symbol && dladdr(symbol, &info) ? info.dli_fname : NULL;
}

/* A fixture oracle only: the wire is still checked through public enc/dec APIs.
 * Matching C headers own the private exported dictionary table layout. */
int bhqr_builtin_word(uint32_t length, uint32_t index, uint32_t transform,
                      uint8_t *output, size_t capacity, size_t *written) {
    *written = 0;
#ifdef BHQR_MODERN
    const BrotliDictionary *dictionary = BrotliGetDictionary();
    const BrotliTransforms *transforms = BrotliGetTransforms();
    if (length < 4 || length > 24 || index >= (1u << dictionary->size_bits_by_length[length]) ||
        transform >= transforms->num_transforms) return BHQR_PARAMETER_FAILED;
    const uint8_t *word = dictionary->data + dictionary->offsets_by_length[length] + length * index;
    uint8_t temporary[256];
    int size = BrotliTransformDictionaryWord(temporary, word, (int)length, transforms, (int)transform);
    if (size < 0 || (size_t)size > capacity) return BHQR_OUTPUT_LIMIT;
    memcpy(output, temporary, (size_t)size);
    *written = (size_t)size;
    return BHQR_OK;
#else
    (void)length; (void)index; (void)transform; (void)output; (void)capacity;
    return BHQR_UNSUPPORTED_DICTIONARY;
#endif
}

int bhqr_encode(const Controls *controls, const Dictionary *dictionaries, size_t dictionary_count,
                const uint8_t *input, size_t input_size, uint8_t *output, size_t output_size,
                size_t *read, size_t *written) {
    *read = *written = 0;
    BrotliEncoderState *state = BrotliEncoderCreateInstance(NULL, NULL, NULL);
    if (!state) return BHQR_STATE_FAILED;
    int status = BHQR_OK;
#ifdef BHQR_MODERN
    BrotliEncoderPreparedDictionary *prepared[15] = {0};
    if (dictionary_count > 15) { status = BHQR_DICTIONARY_FAILED; goto finish; }
#else
    if (dictionary_count) { status = BHQR_UNSUPPORTED_DICTIONARY; goto finish; }
#endif
#define PARAM(key, value) do { \
    if (!BrotliEncoderSetParameter(state, key, value)) { status = BHQR_PARAMETER_FAILED; goto finish; } \
} while (0)
    if (controls->npostfix > 3 || controls->ndirect_high > 15) { status = BHQR_PARAMETER_FAILED; goto finish; }
    PARAM(BROTLI_PARAM_QUALITY, controls->quality);
    PARAM(BROTLI_PARAM_MODE, controls->mode);
    PARAM(BROTLI_PARAM_LGWIN, controls->window_bits);
    PARAM(BROTLI_PARAM_NPOSTFIX, controls->npostfix);
    PARAM(BROTLI_PARAM_NDIRECT, controls->ndirect_high << controls->npostfix);
    if (controls->lgblock) PARAM(BROTLI_PARAM_LGBLOCK, controls->lgblock);
#ifdef BHQR_MODERN
    for (size_t index = 0; index < dictionary_count; ++index) {
        prepared[index] = BrotliEncoderPrepareDictionary((BrotliSharedDictionaryType)dictionaries[index].type,
            dictionaries[index].size, dictionaries[index].data, controls->quality, NULL, NULL, NULL);
        if (!prepared[index] || !BrotliEncoderAttachPreparedDictionary(state, prepared[index])) {
            status = BHQR_DICTIONARY_FAILED; goto finish;
        }
    }
#endif
    size_t available_in = input_size, available_out = output_size;
    const uint8_t *next_in = input;
    uint8_t *next_out = output;
    for (size_t steps = 0; steps < 1024; ++steps) {
        if (!BrotliEncoderCompressStream(state, BROTLI_OPERATION_FINISH, &available_in, &next_in,
                                         &available_out, &next_out, NULL)) { status = BHQR_CODEC_FAILED; break; }
        if (BrotliEncoderIsFinished(state)) break;
        if (!available_out) { status = BHQR_OUTPUT_LIMIT; break; }
        if (steps == 1023) status = BHQR_CODEC_FAILED;
    }
    *read = input_size - available_in;
    *written = output_size - available_out;
    if (status == BHQR_OK && *read != input_size) status = BHQR_INPUT_ACCOUNTING;
finish:
    BrotliEncoderDestroyInstance(state);
#ifdef BHQR_MODERN
    for (size_t index = 0; index < 15; ++index)
        if (prepared[index]) BrotliEncoderDestroyPreparedDictionary(prepared[index]);
#endif
    return status;
#undef PARAM
}

int bhqr_decode(const Dictionary *dictionaries, size_t dictionary_count,
                const uint8_t *input, size_t input_size, uint8_t *output, size_t output_size,
                size_t *read, size_t *written, int *decoder_error) {
    *read = *written = 0;
    *decoder_error = 0;
    BrotliDecoderState *state = BrotliDecoderCreateInstance(NULL, NULL, NULL);
    if (!state) return BHQR_STATE_FAILED;
    int status = BHQR_OK;
#ifdef BHQR_MODERN
    for (size_t index = 0; index < dictionary_count; ++index) {
        if (!BrotliDecoderAttachDictionary(state, (BrotliSharedDictionaryType)dictionaries[index].type,
                                           dictionaries[index].size, dictionaries[index].data)) {
            status = BHQR_DICTIONARY_FAILED; goto finish;
        }
    }
#else
    if (dictionary_count) { status = BHQR_UNSUPPORTED_DICTIONARY; goto finish; }
#endif
    size_t available_in = input_size, available_out = output_size;
    const uint8_t *next_in = input;
    uint8_t *next_out = output;
    BrotliDecoderResult result = BrotliDecoderDecompressStream(state, &available_in, &next_in,
                                                              &available_out, &next_out, NULL);
    *read = input_size - available_in;
    *written = output_size - available_out;
    *decoder_error = (int)BrotliDecoderGetErrorCode(state);
    if (result != BROTLI_DECODER_RESULT_SUCCESS) status = result == BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT
        ? BHQR_OUTPUT_LIMIT : BHQR_CODEC_FAILED;
    else if (*read != input_size) status = BHQR_INPUT_ACCOUNTING;
finish:
    BrotliDecoderDestroyInstance(state);
    return status;
}
