 115c96a:	31 ff                	xor    %edi,%edi
 115c96c:	45 31 c9             	xor    %r9d,%r9d
 115c96f:	45 31 c0             	xor    %r8d,%r8d
 115c972:	eb 11                	jmp    115c985 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1fe5>
 115c974:	49 83 c1 02          	add    $0x2,%r9
 115c978:	49 81 f9 00 01 00 00 	cmp    $0x100,%r9
 115c97f:	0f 84 88 00 00 00    	je     115ca0d <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x206d>
 115c985:	46 8b 54 8e fc       	mov    -0x4(%rsi,%r9,4),%r10d
 115c98a:	4d 85 d2             	test   %r10,%r10
 115c98d:	74 38                	je     115c9c7 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2027>
 115c98f:	46 0f b6 9c 0c 00 19 	movzbl 0x1900(%rsp,%r9,1),%r11d
 115c996:	00 00 
 115c998:	4d 85 db             	test   %r11,%r11
 115c99b:	0f 84 58 04 00 00    	je     115cdf9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2459>
 115c9a1:	c6 84 24 d0 03 00 00 	movb   $0x0,0x3d0(%rsp)
 115c9a8:	00 
 115c9a9:	45 84 ed             	test   %r13b,%r13b
 115c9ac:	0f 85 47 04 00 00    	jne    115cdf9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2459>
 115c9b2:	4d 0f af da          	imul   %r10,%r11
 115c9b6:	4d 01 d8             	add    %r11,%r8
 115c9b9:	0f 92 84 24 d0 03 00 	setb   0x3d0(%rsp)
 115c9c0:	00 
 115c9c1:	0f 82 32 04 00 00    	jb     115cdf9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2459>
 115c9c7:	46 8b 14 8e          	mov    (%rsi,%r9,4),%r10d
 115c9cb:	4d 85 d2             	test   %r10,%r10
 115c9ce:	74 a4                	je     115c974 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1fd4>
 115c9d0:	46 0f b6 9c 0c 01 19 	movzbl 0x1901(%rsp,%r9,1),%r11d
 115c9d7:	00 00 
 115c9d9:	4d 85 db             	test   %r11,%r11
 115c9dc:	0f 84 17 04 00 00    	je     115cdf9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2459>
 115c9e2:	c6 84 24 d0 03 00 00 	movb   $0x0,0x3d0(%rsp)
 115c9e9:	00 
 115c9ea:	45 84 ed             	test   %r13b,%r13b
 115c9ed:	0f 85 06 04 00 00    	jne    115cdf9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2459>
 115c9f3:	4d 0f af da          	imul   %r10,%r11
 115c9f7:	4d 01 d8             	add    %r11,%r8
 115c9fa:	0f 92 84 24 d0 03 00 	setb   0x3d0(%rsp)
 115ca01:	00 
 115ca02:	0f 83 6c ff ff ff    	jae    115c974 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1fd4>
 115ca08:	e9 ec 03 00 00       	jmp    115cdf9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2459>
