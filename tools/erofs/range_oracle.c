/* Read through unmodified erofs-utils' public positional API. fsck's
 * whole-file extraction can skip NONHEAD backtracking checks. */
#include "erofs/internal.h"
#include "erofs/config.h"
#include "erofs/io.h"
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv)
{
    if (argc != 5)
        return 2;
    struct erofs_sb_info sbi = {0};
    erofs_init_configure();
    int ret = erofs_dev_open(&sbi, argv[1], O_RDONLY);
    if (!ret)
        ret = erofs_read_superblock(&sbi);
    struct erofs_inode inode = {.sbi = &sbi, .nid = strtoull(argv[2], NULL, 10)};
    if (!ret)
        ret = erofs_read_inode_from_disk(&inode);
    struct erofs_vfile vf;
    if (!ret)
        ret = erofs_iopen(&vf, &inode);
    size_t size = strtoull(argv[4], NULL, 10);
    if (size > 1024 * 1024)
        return 2;
    void *buf = malloc(size ? size : 1);
    if (!buf)
        return 2;
    if (!ret)
        ret = erofs_pread(&vf, buf, size, strtoull(argv[3], NULL, 10));
    if (!ret && fwrite(buf, 1, size, stdout) != size)
        ret = -1;
    fprintf(stderr, "reference_error=%d\n", ret);
    free(buf);
    return ret ? 1 : 0;
}
