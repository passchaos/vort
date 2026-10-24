#include <stdio.h>
#include <stdlib.h>
#include <lzfse_internal.h>

/* The public Apple buffer API returns 0 for both success with no output and
 * failure. The CLI consequently retries empty streams until malloc fails.
 * Expose the unmodified decoder's status and full-input-consumption contract. */
int main(int argc, char **argv)
{
    FILE *input = NULL, *output = NULL;
    unsigned char *source = NULL, *destination = NULL;
    lzfse_decoder_state *state = NULL;
    size_t source_size, expected_size;
    long file_size;
    char *end;
    int status, result = 1;
    if (argc != 4)
        return 2;
    expected_size = (size_t)strtoull(argv[3], &end, 10);
    if (*end)
        return 2;
    input = fopen(argv[1], "rb");
    if (!input || fseek(input, 0, SEEK_END) || (file_size = ftell(input)) < 0 ||
        fseek(input, 0, SEEK_SET))
        goto out;
    source_size = (size_t)file_size;
    source = malloc(source_size ? source_size : 1);
    destination = malloc(expected_size ? expected_size : 1);
    state = calloc(1, sizeof(*state));
    if (!source || !destination || !state ||
        fread(source, 1, source_size, input) != source_size)
        goto out;
    state->src_begin = state->src = source;
    state->src_end = source + source_size;
    state->dst_begin = state->dst = destination;
    state->dst_end = destination + expected_size;
    status = lzfse_decode(state);
    if (status != LZFSE_STATUS_OK || !state->end_of_stream ||
        state->src != state->src_end || (size_t)(state->dst - destination) != expected_size) {
        fprintf(stderr, "Apple status=%d consumed=%zu/%zu decoded=%zu/%zu eos=%d\n",
                status, (size_t)(state->src - source), source_size,
                (size_t)(state->dst - destination), expected_size, state->end_of_stream);
        goto out;
    }
    output = fopen(argv[2], "wb");
    if (!output || fwrite(destination, 1, expected_size, output) != expected_size)
        goto out;
    result = 0;
out:
    if (input)
        fclose(input);
    if (output && fclose(output))
        result = 1;
    free(state);
    free(destination);
    free(source);
    return result;
}
