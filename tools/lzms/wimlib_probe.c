#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <wimlib.h>

static int read_file(const char *path, uint8_t **data_ret, size_t *size_ret)
{
	FILE *file = fopen(path, "rb");
	long size;
	uint8_t *data;

	if (!file)
		return -1;
	if (fseek(file, 0, SEEK_END) || (size = ftell(file)) < 0 ||
	    fseek(file, 0, SEEK_SET)) {
		fclose(file);
		return -1;
	}
	data = malloc(size ? (size_t)size : 1);
	if (!data || (size && fread(data, 1, size, file) != (size_t)size)) {
		free(data);
		fclose(file);
		return -1;
	}
	fclose(file);
	*data_ret = data;
	*size_ret = size;
	return 0;
}

static int write_file(const char *path, const void *data, size_t size)
{
	FILE *file = fopen(path, "wb");

	if (!file)
		return -1;
	if (size && fwrite(data, 1, size, file) != size) {
		fclose(file);
		return -1;
	}
	return fclose(file);
}

static int encode(const char *input_path, const char *output_path)
{
	struct wimlib_compressor *compressor = NULL;
	uint8_t *input = NULL, *output = NULL;
	size_t input_size, output_size, capacity;
	int result = 1;

	if (read_file(input_path, &input, &input_size) || input_size == 0 ||
	    input_size > (1U << 30))
		goto out;
	capacity = input_size * 2 + 4096;
	output = malloc(capacity);
	if (!output)
		goto out;
	if (wimlib_create_compressor(WIMLIB_COMPRESSION_TYPE_LZMS, input_size, 50,
				     &compressor))
		goto out;
	output_size = wimlib_compress(input, input_size, output, capacity, compressor);
	if (!output_size) {
		result = 3;
		goto out;
	}
	if (write_file(output_path, output, output_size))
		goto out;
	result = 0;
out:
	wimlib_free_compressor(compressor);
	free(output);
	free(input);
	return result;
}

static int decode(const char *input_path, const char *output_path,
		  const char *size_text)
{
	struct wimlib_decompressor *decompressor = NULL;
	uint8_t *input = NULL, *output = NULL;
	size_t input_size, output_size;
	char *end;
	int result = 1;

	errno = 0;
	output_size = strtoull(size_text, &end, 10);
	if (errno || *end || output_size == 0 || output_size > (1U << 30))
		goto out;
	/* Pinned wimlib cd5e231 initializes a zero-/one-symbol offset code for
	 * these outputs and faults even on the unchanged literal reference.
	 * Preserve the unmodified library and report this oracle limitation. */
	if (output_size < 3) {
		fprintf(stderr, "reference limitation: LZMS output below 3 bytes\n");
		return 4;
	}
	if (read_file(input_path, &input, &input_size))
		goto out;
	output = malloc(output_size);
	if (!output)
		goto out;
	if (wimlib_create_decompressor(WIMLIB_COMPRESSION_TYPE_LZMS, output_size,
				       &decompressor))
		goto out;
	if (wimlib_decompress(input, input_size, output, output_size, decompressor))
		goto out;
	if (write_file(output_path, output, output_size))
		goto out;
	result = 0;
out:
	wimlib_free_decompressor(decompressor);
	free(output);
	free(input);
	return result;
}

int main(int argc, char **argv)
{
    if (argc == 2 && strcmp(argv[1], "version") == 0) {
        printf("%s\n", wimlib_get_version_string());
        return 0;
    }
	if (argc == 4 && strcmp(argv[1], "encode") == 0)
		return encode(argv[2], argv[3]);
	if (argc == 5 && strcmp(argv[1], "decode") == 0)
		return decode(argv[2], argv[3], argv[4]);
	fprintf(stderr, "usage: %s encode <in> <out> | decode <in> <out> <size>\n",
		argv[0]);
	return 2;
}
