#include <stdio.h>
#include <mspack.h>

/* Decode the single-file CAB through unmodified libmspack. */
int main(int argc, char **argv)
{
    struct mscab_decompressor *decoder;
    struct mscabd_cabinet *cabinet;
    struct mscabd_cabinet *last;
    int result = 1;
    if (argc < 3)
        return 2;
    decoder = mspack_create_cab_decompressor(NULL);
    if (!decoder)
        return 1;
    cabinet = decoder->open(decoder, argv[1]);
    last = cabinet;
    for (int index = 3; cabinet && index < argc; index++) {
        struct mscabd_cabinet *next = decoder->open(decoder, argv[index]);
        if (!next || decoder->append(decoder, last, next)) {
            if (next)
                decoder->close(decoder, next);
            goto out;
        }
        last = next;
    }
    if (cabinet && cabinet->files && !cabinet->files->next)
        result = decoder->extract(decoder, cabinet->files, argv[2]);
    if (result)
        fprintf(stderr, "libmspack LZX decode error: %d\n", result);
out:
    if (cabinet)
        decoder->close(decoder, cabinet);
    mspack_destroy_cab_decompressor(decoder);
    return result;
}
