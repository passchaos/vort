/* Test-only public liblzma ABI adapter. Compile against the pinned 5.8.4
 * headers, then dynamically load the explicit original/instrumented library.
 * No production Vort hooks and no timers, barriers or simulated worker counts. */
#define _GNU_SOURCE
#include <lzma.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

typedef lzma_ret (*decoder_mt_fn)(lzma_stream *, const lzma_mt *);
typedef lzma_ret (*encoder_mt_fn)(lzma_stream *, const lzma_mt *);
typedef lzma_ret (*code_fn)(lzma_stream *, lzma_action);
typedef void (*end_fn)(lzma_stream *);
typedef lzma_bool (*preset_fn)(lzma_options_lzma *, uint32_t);
typedef uint32_t (*abi_fn)(void);
typedef int (*reset_fn)(void);
typedef int (*snapshot_fn)(uint64_t *, size_t);

uint32_t vort_xz_bs_adapter_abi(void) { return 1; }
size_t vort_xz_bs_sizeof_stream(void) { return sizeof(lzma_stream); }
size_t vort_xz_bs_sizeof_mt(void) { return sizeof(lzma_mt); }
size_t vort_xz_bs_sizeof_lzma_options(void) { return sizeof(lzma_options_lzma); }

int vort_xz_bs_library_owner(const char *library_path, char *output, size_t capacity) {
    void *library = dlopen(library_path, RTLD_NOW | RTLD_LOCAL);
    if (library == NULL) return 1;
    void *symbol = dlsym(library, "lzma_stream_decoder_mt");
    Dl_info info;
    if (symbol == NULL || dladdr(symbol, &info) == 0 || info.dli_fname == NULL) {
        dlclose(library); return 2;
    }
    size_t count = strlen(info.dli_fname);
    if (count + 1 > capacity) { dlclose(library); return 3; }
    memcpy(output, info.dli_fname, count + 1);
    dlclose(library);
    return 0;
}

/* Adapter result 0 means invocation/snapshot succeeded. lzma_status is the
 * actual library result, normally LZMA_STREAM_END; no errors are normalized. */
int vort_xz_bs_decode_mt(const char *library_path, uint32_t threads,
        uint64_t memlimit_threading, uint64_t memlimit_stop,
        const uint8_t *input, size_t input_size, uint8_t *output,
        size_t output_size, uint64_t *input_read, uint64_t *output_written,
        uint32_t *lzma_status, uint64_t *counters, size_t counter_count) {
    void *library = dlopen(library_path, RTLD_NOW | RTLD_LOCAL);
    if (library == NULL) return 1;
    decoder_mt_fn decode = (decoder_mt_fn)dlsym(library, "lzma_stream_decoder_mt");
    code_fn code = (code_fn)dlsym(library, "lzma_code");
    end_fn end = (end_fn)dlsym(library, "lzma_end");
    abi_fn abi = (abi_fn)dlsym(library, "vort_xz_mt_probe_abi_version");
    reset_fn reset = (reset_fn)dlsym(library, "vort_xz_mt_probe_reset");
    snapshot_fn snapshot = (snapshot_fn)dlsym(library, "vort_xz_mt_probe_snapshot");
    if (decode == NULL || code == NULL || end == NULL) { dlclose(library); return 2; }
    if (counter_count != 0 && (abi == NULL || reset == NULL || snapshot == NULL || abi() != 1)) {
        dlclose(library); return 3;
    }
    if (counter_count != 0 && reset() != 0) { dlclose(library); return 4; }
    lzma_stream stream = LZMA_STREAM_INIT;
    lzma_mt options;
    memset(&options, 0, sizeof(options));
    options.threads = threads;
    options.memlimit_threading = memlimit_threading;
    options.memlimit_stop = memlimit_stop;
    options.timeout = 0;
    lzma_ret status = decode(&stream, &options);
    stream.next_in = input;
    stream.avail_in = input_size;
    stream.next_out = output;
    stream.avail_out = output_size;
    size_t calls = 0;
    int invocation_result = 0;
    while (status == LZMA_OK) {
        if (++calls > 1000000) { invocation_result = 6; break; }
        status = code(&stream, LZMA_FINISH);
    }
    *input_read = input_size - stream.avail_in;
    *output_written = output_size - stream.avail_out;
    *lzma_status = (uint32_t)status;
    end(&stream); /* Joins workers before snapshot/reset of the next invocation. */
    int result = invocation_result;
    if (counter_count != 0 && snapshot(counters, counter_count) != 0) result = 5;
    dlclose(library);
    return result;
}

int vort_xz_bs_encode_mt(const char *library_path, uint32_t threads,
        uint64_t block_size, uint32_t check, uint32_t preset,
        const uint64_t *filter_ids, const uint32_t *filter_parameters,
        size_t filter_count, const uint8_t *input, size_t input_size,
        uint8_t *output, size_t output_size, uint64_t *output_written,
        uint32_t *lzma_status) {
    if (filter_count > 3) return 10;
    void *library = dlopen(library_path, RTLD_NOW | RTLD_LOCAL);
    if (library == NULL) return 1;
    encoder_mt_fn encode = (encoder_mt_fn)dlsym(library, "lzma_stream_encoder_mt");
    code_fn code = (code_fn)dlsym(library, "lzma_code");
    end_fn end = (end_fn)dlsym(library, "lzma_end");
    preset_fn set_preset = (preset_fn)dlsym(library, "lzma_lzma_preset");
    if (encode == NULL || code == NULL || end == NULL || set_preset == NULL) { dlclose(library); return 2; }
    lzma_filter filters[5];
    lzma_options_delta delta[3];
    lzma_options_bcj bcj[3];
    memset(filters, 0, sizeof(filters));
    memset(delta, 0, sizeof(delta));
    memset(bcj, 0, sizeof(bcj));
    for (size_t i = 0; i < filter_count; ++i) {
        filters[i].id = filter_ids[i];
        if (filter_ids[i] == LZMA_FILTER_DELTA) {
            delta[i].type = LZMA_DELTA_TYPE_BYTE;
            delta[i].dist = filter_parameters[i];
            filters[i].options = &delta[i];
        } else {
            bcj[i].start_offset = filter_parameters[i];
            filters[i].options = &bcj[i];
        }
    }
    lzma_options_lzma lzma;
    memset(&lzma, 0, sizeof(lzma));
    if (set_preset(&lzma, preset)) { dlclose(library); return 11; }
    lzma.dict_size = 4096;
    filters[filter_count].id = LZMA_FILTER_LZMA2;
    filters[filter_count].options = &lzma;
    filters[filter_count + 1].id = LZMA_VLI_UNKNOWN;
    filters[filter_count + 1].options = NULL;
    lzma_mt options;
    memset(&options, 0, sizeof(options));
    options.threads = threads;
    options.block_size = block_size;
    options.check = (lzma_check)check;
    options.filters = filters;
    options.timeout = 0;
    lzma_stream stream = LZMA_STREAM_INIT;
    lzma_ret status = encode(&stream, &options);
    stream.next_in = input;
    stream.avail_in = input_size;
    stream.next_out = output;
    stream.avail_out = output_size;
    size_t calls = 0;
    int invocation_result = 0;
    while (status == LZMA_OK) {
        if (++calls > 1000000) { invocation_result = 6; break; }
        status = code(&stream, LZMA_FINISH);
    }
    *output_written = output_size - stream.avail_out;
    *lzma_status = (uint32_t)status;
    end(&stream);
    dlclose(library);
    return invocation_result;
}
