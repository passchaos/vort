/* Private Brotli reference harness, not a Vort implementation dependency.
 * build.py adds two read-only observation calls to a private decode.c copy.
 * All private-state declarations and linked Brotli objects come from that same
 * source snapshot. No struct layout is guessed from an installed library. */
#include <stdint.h>
#include <stdlib.h>
#include <brotli/decode.h>
#include <brotli/encode.h>
#include "c/dec/state.h"

#if defined(__GNUC__)
#define BRLC_PUBLIC __attribute__((visibility("default")))
#else
#define BRLC_PUBLIC
#endif

typedef void (*brlc_callback)(void*, unsigned, const uint32_t*,
                             const uint8_t*, const uint8_t*, const uint8_t*);
typedef struct {
  brlc_callback callback;
  void* opaque;
  BrotliDecoderState* decoder;
} brlc_session;

static void* brlc_alloc(void* opaque, size_t size) {
  (void)opaque;
  return malloc(size);
}

static void brlc_free(void* opaque, void* ptr) {
  (void)opaque;
  free(ptr);
}

/* Called once after a complete RFC metablock length/header, and once after
 * BOTH context maps have been decoded, including inverse MTF. */
void brlc_observe(const BrotliDecoderState* state, unsigned kind) {
  brlc_session* session = (brlc_session*)state->memory_manager_opaque;
  uint32_t info[11] = {0};
  if (!session || !session->callback) return;
  info[0] = state->window_bits;
  info[1] = state->is_last_metablock;
  info[2] = state->is_uncompressed;
  info[3] = state->is_metadata;
  info[4] = (uint32_t)state->meta_block_remaining_len;
  if (kind == 1) {
    info[5] = (uint32_t)state->num_block_types[0];
    info[6] = (uint32_t)state->num_block_types[1];
    info[7] = (uint32_t)state->num_block_types[2];
    info[8] = (uint32_t)state->num_literal_htrees;
    info[9] = (uint32_t)state->num_dist_htrees;
    info[10] = (uint32_t)state->distance_postfix_bits;
  }
  session->callback(session->opaque, kind, info,
                    kind == 1 ? state->context_map : NULL,
                    kind == 1 ? state->dist_context_map : NULL,
                    kind == 1 ? state->context_modes : NULL);
}

BRLC_PUBLIC void* brlc_decoder_create(brlc_callback callback, void* opaque) {
  brlc_session* session = (brlc_session*)calloc(1, sizeof(*session));
  if (!session) return NULL;
  session->callback = callback;
  session->opaque = opaque;
  session->decoder = BrotliDecoderCreateInstance(brlc_alloc, brlc_free, session);
  if (!session->decoder) { free(session); return NULL; }
  return session;
}

BRLC_PUBLIC void brlc_decoder_destroy(void* handle) {
  brlc_session* session = (brlc_session*)handle;
  if (!session) return;
  BrotliDecoderDestroyInstance(session->decoder);
  free(session);
}

BRLC_PUBLIC int brlc_decoder_parameter(void* handle, unsigned key, uint32_t value) {
  return BrotliDecoderSetParameter(((brlc_session*)handle)->decoder,
                                  (BrotliDecoderParameter)key, value);
}

BRLC_PUBLIC int brlc_decoder_stream(void* handle, size_t* available_in,
    const uint8_t** next_in, size_t* available_out, uint8_t** next_out,
    size_t* total_out) {
  return (int)BrotliDecoderDecompressStream(((brlc_session*)handle)->decoder,
      available_in, next_in, available_out, next_out, total_out);
}

BRLC_PUBLIC int brlc_decoder_error(void* handle) {
  return (int)BrotliDecoderGetErrorCode(((brlc_session*)handle)->decoder);
}

BRLC_PUBLIC uint32_t brlc_decoder_version(void) {
  return BrotliDecoderVersion();
}

BRLC_PUBLIC void* brlc_encoder_create(void) {
  return BrotliEncoderCreateInstance(NULL, NULL, NULL);
}

BRLC_PUBLIC void brlc_encoder_destroy(void* state) {
  BrotliEncoderDestroyInstance((BrotliEncoderState*)state);
}

BRLC_PUBLIC int brlc_encoder_parameter(void* state, unsigned key, uint32_t value) {
  return BrotliEncoderSetParameter((BrotliEncoderState*)state,
                                  (BrotliEncoderParameter)key, value);
}

BRLC_PUBLIC int brlc_encoder_stream(void* state, unsigned operation,
    size_t* available_in, const uint8_t** next_in, size_t* available_out,
    uint8_t** next_out, size_t* total_out) {
  return BrotliEncoderCompressStream((BrotliEncoderState*)state,
      (BrotliEncoderOperation)operation, available_in, next_in,
      available_out, next_out, total_out);
}

BRLC_PUBLIC int brlc_encoder_finished(void* state) {
  return BrotliEncoderIsFinished((BrotliEncoderState*)state);
}

BRLC_PUBLIC uint32_t brlc_encoder_version(void) {
  return BrotliEncoderVersion();
}
