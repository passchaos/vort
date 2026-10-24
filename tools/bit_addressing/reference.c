/* Real file-backed Brotli input, opaque state from the installed public headers.
 * A private loader namespace selects exactly the requested reference runtime.
 */
#define _GNU_SOURCE
#include <brotli/decode.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <link.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <unistd.h>

#define LOAD(name) __typeof__(&name) call_##name = (__typeof__(&name))dlsym(runtime, #name); if (!call_##name) return 11

int main(int argc, char **argv) {
    if (argc != 4) return 2;
    size_t expected = (size_t)strtoull(argv[3], NULL, 10);
    if (expected > 64) return 3;
    int fd = open(argv[2], O_RDONLY);
    struct stat stats;
    if (fd < 0 || fstat(fd, &stats) || stats.st_size < 1) return 4;
    size_t length = (size_t)stats.st_size;
    const uint8_t *mapping = mmap(NULL, length, PROT_READ, MAP_PRIVATE, fd, 0);
    if (mapping == MAP_FAILED) return 5;
    void *runtime = dlmopen(LM_ID_NEWLM, argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!runtime) { fprintf(stderr, "%s\n", dlerror()); return 10; }
    LOAD(BrotliDecoderCreateInstance);
    LOAD(BrotliDecoderDestroyInstance);
    LOAD(BrotliDecoderDecompressStream);
    LOAD(BrotliDecoderGetErrorCode);
    LOAD(BrotliDecoderVersion);
    LOAD(BrotliDecoderSetParameter);
    BrotliDecoderState *state = call_BrotliDecoderCreateInstance(NULL, NULL, NULL);
    if (!state) return 12;
    if (!call_BrotliDecoderSetParameter(state, BROTLI_DECODER_PARAM_LARGE_WINDOW, 0)) return 13;
    uint8_t storage[80];
    memset(storage, 0xa5, sizeof(storage));
    size_t consumed = 0, written = 0, calls = 0, released = 0;
    size_t page_size = (size_t)sysconf(_SC_PAGESIZE);
    BrotliDecoderResult result = BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT;
    while (consumed < length && result != BROTLI_DECODER_RESULT_SUCCESS && calls < length / 65536 + 4096) {
        size_t available_in = length - consumed;
        if (available_in > 65536) available_in = 65536;
        size_t offered = available_in;
        const uint8_t *next_in = mapping + consumed;
        size_t available_out = 64 - written;
        uint8_t *next_out = storage + 8 + written;
        result = call_BrotliDecoderDecompressStream(state, &available_in, &next_in, &available_out, &next_out, NULL);
        consumed += offered - available_in;
        written = 64 - available_out;
        calls++;
        /* Older references physically visit metadata bytes. Release consumed
         * mapped pages after every bounded feed, so one sparse file does not
         * turn into a 512MiB resident working set. Decoder state never borrows
         * returned input; the incomplete final page remains mapped and valid.
         */
        size_t release_end = consumed / page_size * page_size;
        if (release_end > released) {
            if (madvise((void *)(mapping + released), release_end - released, MADV_DONTNEED)) return 16;
            released = release_end;
        }
        if (result == BROTLI_DECODER_RESULT_ERROR || result == BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT) break;
        if (offered == available_in && result == BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT) break;
    }
    int decoder_error = (int)call_BrotliDecoderGetErrorCode(state);
    uint32_t version = call_BrotliDecoderVersion();
    call_BrotliDecoderDestroyInstance(state);
    int guards = 1, output = written == expected;
    for (size_t i = 0; i < 8; ++i) guards &= storage[i] == 0xa5 && storage[72 + i] == 0xa5;
    for (size_t i = 0; i < written; ++i) output &= storage[8 + i] == 'R';
    for (size_t i = written; i < 64; ++i) guards &= storage[8 + i] == 0xa5;
    struct rusage usage;
    if (getrusage(RUSAGE_SELF, &usage)) return 14;
    Dl_info info;
    if (!dladdr((void *)call_BrotliDecoderVersion, &info)) return 15;
    printf("{\"status\":\"%s\",\"decoder_version\":%" PRIu32 ",\"decoder_library\":\"%s\","
           "\"mapped_input_bytes\":%zu,\"allocated_file_bytes\":%" PRIu64 ",\"input_read\":%zu,"
           "\"output_written\":%zu,\"stream_calls\":%zu,\"feed_bytes\":65536,\"decoder_error\":%d,"
           "\"peak_rss_kib\":%ld,\"released_consumed_mapping_bytes\":%zu,\"output_hex\":\"",
           result == BROTLI_DECODER_RESULT_SUCCESS && consumed == length && guards && output ? "ok" : "error",
           version, info.dli_fname, length, (uint64_t)stats.st_blocks * 512, consumed, written, calls, decoder_error, usage.ru_maxrss, released);
    for (size_t i = 0; i < written; ++i) printf("%02x", storage[8 + i]);
    printf("\",\"guards_verified\":%s,\"large_window_enabled\":false,\"whole_file_sha256\":null}\n", guards ? "true" : "false");
    munmap((void *)mapping, length);
    close(fd);
    dlclose(runtime);
    return result == BROTLI_DECODER_RESULT_SUCCESS && consumed == length && guards && output ? 0 : 20;
}
