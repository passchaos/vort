/* Keep the established header-owned pointer ABI and dictionary setup. */
#include "hq_controls_reference.c"

int blwr_encode(uint32_t large_window, const Controls *controls,
                 const Dictionary *dictionaries, size_t dictionary_count,
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
    /* The opt-in flag precedes LGWIN; no ordinary window header is substituted. */
    PARAM(BROTLI_PARAM_LARGE_WINDOW, large_window);
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

int blwr_decode(uint32_t allow_large_window, const Dictionary *dictionaries, size_t dictionary_count,
                 const uint8_t *input, size_t input_size, uint8_t *output, size_t output_size,
                 size_t *read, size_t *written, int *decoder_error) {
    *read = *written = 0;
    *decoder_error = 0;
    BrotliDecoderState *state = BrotliDecoderCreateInstance(NULL, NULL, NULL);
    if (!state) return BHQR_STATE_FAILED;
    int status = BHQR_OK;
    if (!BrotliDecoderSetParameter(state, BROTLI_DECODER_PARAM_LARGE_WINDOW, allow_large_window)) {
        status = BHQR_PARAMETER_FAILED; goto finish;
    }
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
