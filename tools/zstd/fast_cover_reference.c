#define ZDICT_STATIC_LINKING_ONLY
#include <zdict.h>
#include <zstd.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <time.h>

/* Fixed pointer ABI for the Python harness. The installed header supplies the
 * upstream by-value ABI, and its version is checked against the loaded library. */
typedef struct {
    uint32_t k, d, f, steps, threads;
    double split;
    uint32_t acceleration, shrink, regression;
    int32_t level;
    uint32_t dictionary_id;
} VfcParameters;

typedef struct {
    uint64_t elapsed_ns;
    VfcParameters selected;
} VfcResult;

unsigned vfc_header_version(void) { return ZSTD_VERSION_NUMBER; }
const char *vfc_runtime_version(void) { return ZSTD_versionString(); }
size_t vfc_parameters_size(void) { return sizeof(VfcParameters); }
size_t vfc_result_size(void) { return sizeof(VfcResult); }
size_t vfc_split_offset(void) { return offsetof(VfcParameters, split); }

static uint64_t now_ns(void) {
    struct timespec value;
    if (clock_gettime(CLOCK_MONOTONIC, &value) != 0) return 0;
    return (uint64_t)value.tv_sec * UINT64_C(1000000000) + (uint64_t)value.tv_nsec;
}

static ZDICT_fastCover_params_t native_parameters(const VfcParameters *p) {
    ZDICT_fastCover_params_t result;
    memset(&result, 0, sizeof(result));
    result.k = p->k;
    result.d = p->d;
    result.f = p->f;
    result.steps = p->steps;
    result.nbThreads = p->threads;
    result.splitPoint = p->split;
    result.accel = p->acceleration;
    result.shrinkDict = p->shrink;
    result.shrinkDictMaxRegression = p->regression;
    result.zParams.compressionLevel = p->level;
    result.zParams.notificationLevel = 0;
    result.zParams.dictID = p->dictionary_id;
    return result;
}

static VfcParameters public_parameters(ZDICT_fastCover_params_t p) {
    VfcParameters result;
    memset(&result, 0, sizeof(result));
    result.k = p.k;
    result.d = p.d;
    result.f = p.f;
    result.steps = p.steps;
    result.threads = p.nbThreads;
    result.split = p.splitPoint;
    result.acceleration = p.accel;
    result.shrink = p.shrinkDict;
    result.regression = p.shrinkDictMaxRegression;
    result.level = p.zParams.compressionLevel;
    result.dictionary_id = p.zParams.dictID;
    return result;
}

size_t vfc_train(void *dictionary, size_t capacity, const void *samples,
                 const size_t *sample_sizes, unsigned sample_count,
                 const VfcParameters *parameters, unsigned optimize,
                 VfcResult *result) {
    ZDICT_fastCover_params_t p = native_parameters(parameters);
    uint64_t start = now_ns();
    size_t size = optimize
        ? ZDICT_optimizeTrainFromBuffer_fastCover(dictionary, capacity, samples,
                                                 sample_sizes, sample_count, &p)
        : ZDICT_trainFromBuffer_fastCover(dictionary, capacity, samples,
                                          sample_sizes, sample_count, p);
    uint64_t end = now_ns();
    result->elapsed_ns = end >= start ? end - start : 0;
    result->selected = public_parameters(p);
    return size;
}

size_t vfc_finalize(void *dictionary, size_t capacity, const void *content,
                    size_t content_size, const void *samples,
                    const size_t *sample_sizes, unsigned sample_count,
                    const VfcParameters *parameters, VfcResult *result) {
    ZDICT_params_t p;
    memset(&p, 0, sizeof(p));
    p.compressionLevel = parameters->level;
    p.dictID = parameters->dictionary_id;
    uint64_t start = now_ns();
    size_t size = ZDICT_finalizeDictionary(dictionary, capacity, content,
        content_size, samples, sample_sizes, sample_count, p);
    uint64_t end = now_ns();
    result->elapsed_ns = end >= start ? end - start : 0;
    result->selected = *parameters;
    return size;
}
