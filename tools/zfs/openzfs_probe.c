#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "module/zfs/lzjb.c"
#include "module/zfs/zle.c"

static unsigned char *read_file(const char *path, size_t *size)
{
    FILE *file = fopen(path, "rb");
    if (file == NULL)
        return NULL;
    if (fseek(file, 0, SEEK_END) != 0) {
        fclose(file);
        return NULL;
    }
    long end = ftell(file);
    if (end < 0 || fseek(file, 0, SEEK_SET) != 0) {
        fclose(file);
        return NULL;
    }
    *size = (size_t)end;
    unsigned char *bytes = malloc(*size == 0 ? 1 : *size);
    if (bytes == NULL || fread(bytes, 1, *size, file) != *size) {
        free(bytes);
        fclose(file);
        return NULL;
    }
    fclose(file);
    return bytes;
}

static int write_file(const char *path, const unsigned char *bytes, size_t size)
{
    FILE *file = fopen(path, "wb");
    if (file == NULL)
        return 1;
    int failed = fwrite(bytes, 1, size, file) != size || fclose(file) != 0;
    return failed;
}

int main(int argc, char **argv)
{
    if (argc != 5 && argc != 6) {
        fprintf(stderr, "usage: %s encode|decode lzjb|zle input output [decoded_size]\n", argv[0]);
        return 2;
    }
    size_t input_size = 0;
    unsigned char *input = read_file(argv[3], &input_size);
    if (input == NULL) {
        fprintf(stderr, "read failed: %s\n", strerror(errno));
        return 2;
    }
    int is_lzjb = strcmp(argv[2], "lzjb") == 0;
    int is_zle = strcmp(argv[2], "zle") == 0;
    if (!is_lzjb && !is_zle) {
        free(input);
        return 2;
    }
    if (strcmp(argv[1], "encode") == 0 && argc == 5) {
        unsigned char *output = malloc(input_size == 0 ? 1 : input_size);
        if (output == NULL) {
            free(input);
            return 2;
        }
        size_t written = is_lzjb
            ? zfs_lzjb_compress_buf(input, output, input_size, input_size, 0)
            : zfs_zle_compress_buf(input, output, input_size, input_size, 64);
        int failed = written >= input_size || write_file(argv[4], output, written);
        free(output);
        free(input);
        return failed;
    }
    if (strcmp(argv[1], "decode") == 0 && argc == 6) {
        char *end = NULL;
        unsigned long long parsed = strtoull(argv[5], &end, 10);
        if (*argv[5] == '\0' || *end != '\0' || parsed > SIZE_MAX) {
            free(input);
            return 2;
        }
        size_t output_size = (size_t)parsed;
        unsigned char *output = malloc(output_size == 0 ? 1 : output_size);
        if (output == NULL) {
            free(input);
            return 2;
        }
        int result = is_lzjb
            ? zfs_lzjb_decompress_buf(input, output, input_size, output_size, 0)
            : zfs_zle_decompress_buf(input, output, input_size, output_size, 64);
        int failed = result != 0 || write_file(argv[4], output, output_size);
        free(output);
        free(input);
        return failed;
    }
    free(input);
    return 2;
}
