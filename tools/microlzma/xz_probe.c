#include <errno.h>
#include <lzma.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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

static int encode(const char *input_path, const char *output_path,
		  uint32_t dictionary_size, uint32_t lc, uint32_t lp, uint32_t pb,
		  size_t capacity_limit)
{
	uint8_t *input = NULL, *output = NULL;
	size_t input_size, capacity;
	lzma_stream stream = LZMA_STREAM_INIT;
	lzma_options_lzma options;
	int result = 1;

	if (read_file(input_path, &input, &input_size))
		goto out;
	capacity = capacity_limit ? capacity_limit : input_size * 2 + 64;
	if (capacity < 6)
		goto out;
	output = malloc(capacity);
	if (!output || lzma_lzma_preset(&options, LZMA_PRESET_DEFAULT))
		goto out;
	options.dict_size = dictionary_size;
	options.lc = lc;
	options.lp = lp;
	options.pb = pb;
	if (lzma_microlzma_encoder(&stream, &options) != LZMA_OK)
		goto out;
	stream.next_in = input;
	stream.avail_in = input_size;
	stream.next_out = output;
	stream.avail_out = capacity;
	if (lzma_code(&stream, LZMA_FINISH) != LZMA_STREAM_END ||
	    (!capacity_limit && stream.total_in != input_size))
		goto out;
	if (write_file(output_path, output, stream.total_out))
		goto out;
	printf("consumed=%llu written=%llu\n",
	       (unsigned long long)stream.total_in,
	       (unsigned long long)stream.total_out);
	result = 0;
out:
	lzma_end(&stream);
	free(output);
	free(input);
	return result;
}

static int decode(const char *input_path, const char *output_path,
		  size_t output_size, uint32_t dictionary_size)
{
	uint8_t *input = NULL, *output = NULL;
	size_t input_size;
	lzma_stream stream = LZMA_STREAM_INIT;
	int result = 1;

	if (read_file(input_path, &input, &input_size))
		goto out;
	output = malloc(output_size ? output_size : 1);
	if (!output || lzma_microlzma_decoder(&stream, input_size, output_size,
					      1, dictionary_size) != LZMA_OK)
		goto out;
	stream.next_in = input;
	stream.avail_in = input_size;
	stream.next_out = output;
	stream.avail_out = output_size;
	if (lzma_code(&stream, LZMA_FINISH) != LZMA_STREAM_END ||
	    stream.total_in != input_size || stream.total_out != output_size)
		goto out;
	if (write_file(output_path, output, output_size))
		goto out;
	result = 0;
out:
	lzma_end(&stream);
	free(output);
	free(input);
	return result;
}

int main(int argc, char **argv)
{
	if (argc == 8 && strcmp(argv[1], "encode") == 0)
		return encode(argv[2], argv[3], strtoul(argv[4], NULL, 10),
			      strtoul(argv[5], NULL, 10),
			      strtoul(argv[6], NULL, 10),
			      strtoul(argv[7], NULL, 10), 0);
	if (argc == 9 && strcmp(argv[1], "encode-limit") == 0)
		return encode(argv[2], argv[3], strtoul(argv[4], NULL, 10),
			      strtoul(argv[5], NULL, 10),
			      strtoul(argv[6], NULL, 10),
			      strtoul(argv[7], NULL, 10),
			      strtoull(argv[8], NULL, 10));
	if (argc == 6 && strcmp(argv[1], "decode") == 0)
		return decode(argv[2], argv[3], strtoull(argv[4], NULL, 10),
			      strtoul(argv[5], NULL, 10));
	fprintf(stderr, "usage: %s encode IN OUT DICT LC LP PB | encode-limit IN OUT DICT LC LP PB CAPACITY | decode IN OUT SIZE DICT\n",
		argv[0]);
	return 2;
}
