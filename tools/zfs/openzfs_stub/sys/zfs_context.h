#ifndef VORT_OPENZFS_STUB_CONTEXT_H
#define VORT_OPENZFS_STUB_CONTEXT_H

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef unsigned char uchar_t;

#define NBBY 8
#define KM_SLEEP 0
#define MIN(a, b) ((a) < (b) ? (a) : (b))

static inline void *kmem_zalloc(size_t size, int flags)
{
    (void)flags;
    return calloc(1, size);
}

static inline void kmem_free(void *pointer, size_t size)
{
    (void)size;
    free(pointer);
}

#endif
