/* Extend the existing, header-owned ABI without duplicating codec setup. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include "encode_controls_reference.c"

const char *lbr_runtime_library_path(void) {
    Dl_info info;
    return dladdr((void *)lzma_version_number, &info) ? info.dli_fname : NULL;
}

int lbr_dictionary_property(const Controls *controls, uint8_t *property,
                            uint64_t *decoder_memory) {
    lzma_options_lzma options;
    int result = configure(controls, &options);
    if (result != LZMA_OK) return result;
    lzma_filter filter = {LZMA_FILTER_LZMA2, &options};
    uint32_t size = 0;
    result = lzma_properties_size(&size, &filter);
    if (result != LZMA_OK || size != 1) return LZMA_OPTIONS_ERROR;
    result = lzma_properties_encode(&filter, property);
    lzma_filter filters[2] = {filter, {LZMA_VLI_UNKNOWN, NULL}};
    *decoder_memory = lzma_raw_decoder_memusage(filters);
    return result;
}

int lbr_dictionary_size_from_property(uint8_t property, uint32_t *size) {
    lzma_filter filters[2] = {{LZMA_FILTER_LZMA2, NULL}, {LZMA_VLI_UNKNOWN, NULL}};
    lzma_ret result = lzma_properties_decode(&filters[0], NULL, &property, 1);
    if (result == LZMA_OK)
        *size = ((lzma_options_lzma *)filters[0].options)->dict_size;
    lzma_filters_free(filters, NULL);
    return result;
}

/* A real original-container decode with a caller-owned memory limit. The
 * MEMLIMIT result includes the library's required bytes; FORMAT stays distinct.
 * format 3=Alone, 4=XZ, 5=auto (Alone or XZ). No dictionary rewriting occurs. */
int lbr_decode_budgeted(uint32_t format, uint64_t memory_limit,
                       const uint8_t *input, size_t input_size,
                       uint8_t *output, size_t output_size,
                       size_t *read, size_t *written,
                       uint64_t *memory_needed) {
    lzma_stream stream = LZMA_STREAM_INIT;
    *read = *written = 0;
    *memory_needed = 0;
    lzma_ret result;
    switch (format) {
    case 3: result = lzma_alone_decoder(&stream, memory_limit); break;
    case 4: result = lzma_stream_decoder(&stream, memory_limit, 0); break;
    case 5: result = lzma_auto_decoder(&stream, memory_limit, 0); break;
    default: return LZMA_OPTIONS_ERROR;
    }
    if (result == LZMA_OK) {
        stream.next_in = input;
        stream.avail_in = input_size;
        stream.next_out = output;
        stream.avail_out = output_size;
        result = lzma_code(&stream, LZMA_FINISH);
        *read = input_size - stream.avail_in;
        *written = output_size - stream.avail_out;
        *memory_needed = lzma_memusage(&stream);
        if (result == LZMA_STREAM_END) result = LZMA_OK;
    }
    lzma_end(&stream);
    return result;
}

const char *lbr_status_name(uint32_t status) {
    switch ((lzma_ret)status) {
    case LZMA_OK: return "OK";
    case LZMA_MEM_ERROR: return "MEM_ERROR";
    case LZMA_MEMLIMIT_ERROR: return "MEMLIMIT_ERROR";
    case LZMA_FORMAT_ERROR: return "FORMAT_ERROR";
    case LZMA_OPTIONS_ERROR: return "OPTIONS_ERROR";
    case LZMA_DATA_ERROR: return "DATA_ERROR";
    case LZMA_BUF_ERROR: return "BUF_ERROR";
    case LZMA_PROG_ERROR: return "PROG_ERROR";
    default: return "OTHER";
    }
}
