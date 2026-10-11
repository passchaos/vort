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

static int compression_type(const char *name)
{
	if (strncmp(name, "xpress", 6) == 0)
		return WIMLIB_COMPRESSION_TYPE_XPRESS;
	if (strcmp(name, "lzx") == 0)
		return WIMLIB_COMPRESSION_TYPE_LZX;
	return WIMLIB_COMPRESSION_TYPE_NONE;
}

static int encode(const char *algorithm, const char *input_path,
		  const char *output_path)
{
	struct wimlib_compressor *compressor = NULL;
	uint8_t *input = NULL, *output = NULL;
	size_t input_size, output_size;
	int ctype = compression_type(algorithm);
	int result = 1;

	if (ctype == WIMLIB_COMPRESSION_TYPE_NONE ||
	    read_file(input_path, &input, &input_size) || input_size == 0)
		goto out;
	output = malloc(input_size);
	if (!output || wimlib_create_compressor(ctype, input_size, 50, &compressor))
		goto out;
	output_size = wimlib_compress(input, input_size, output, input_size - 1,
				     compressor);
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

static int decode(const char *algorithm, const char *input_path,
		  const char *output_path, size_t output_size)
{
	struct wimlib_decompressor *decompressor = NULL;
	uint8_t *input = NULL, *output = NULL;
	size_t input_size;
	int ctype = compression_type(algorithm);
	int result = 1;

	if (ctype == WIMLIB_COMPRESSION_TYPE_NONE ||
	    read_file(input_path, &input, &input_size))
		goto out;
	output = malloc(output_size ? output_size : 1);
	if (!output || wimlib_create_decompressor(ctype, output_size, &decompressor))
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
	if (argc == 5 && strcmp(argv[1], "encode") == 0)
		return encode(argv[2], argv[3], argv[4]);
	if (argc == 6 && strcmp(argv[1], "decode") == 0)
		return decode(argv[2], argv[3], argv[4],
			      strtoull(argv[5], NULL, 10));
	fprintf(stderr, "usage: %s encode ALG IN OUT | decode ALG IN OUT SIZE\n",
		argv[0]);
	return 2;
}
