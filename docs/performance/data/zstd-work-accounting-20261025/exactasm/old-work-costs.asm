 115c315:	48 8b 84 24 50 1d 00 	mov    0x1d50(%rsp),%rax
 115c31c:	00 
 115c31d:	48 ff c0             	inc    %rax
 115c320:	48 c7 c1 ff ff ff ff 	mov    $0xffffffffffffffff,%rcx
 115c327:	48 0f 44 c1          	cmove  %rcx,%rax
 115c32b:	48 89 84 24 50 1d 00 	mov    %rax,0x1d50(%rsp)
 115c332:	00 
 115c333:	48 83 fb 02          	cmp    $0x2,%rbx
 115c337:	48 89 7c 24 08       	mov    %rdi,0x8(%rsp)
 115c33c:	48 89 74 24 50       	mov    %rsi,0x50(%rsp)
 115c341:	0f 82 ca 01 00 00    	jb     115c511 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1b71>
 115c347:	49 83 ff 40          	cmp    $0x40,%r15
 115c34b:	0f 82 c0 01 00 00    	jb     115c511 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1b71>
 115c351:	48 8b 84 24 58 1d 00 	mov    0x1d58(%rsp),%rax
 115c358:	00 
 115c359:	48 ff c0             	inc    %rax
 115c35c:	48 0f 44 c1          	cmove  %rcx,%rax
 115c360:	48 89 84 24 58 1d 00 	mov    %rax,0x1d58(%rsp)
 115c367:	00 

 115c6f9:	00 00 
 115c6fb:	48 8b 84 24 60 1d 00 	mov    0x1d60(%rsp),%rax
 115c702:	00 
 115c703:	48 ff c0             	inc    %rax
 115c706:	48 c7 c1 ff ff ff ff 	mov    $0xffffffffffffffff,%rcx
 115c70d:	48 0f 44 c1          	cmove  %rcx,%rax
 115c711:	48 89 84 24 60 1d 00 	mov    %rax,0x1d60(%rsp)
 115c718:	00 
 115c719:	4c 8d ac 24 c0 03 00 	lea    0x3c0(%rsp),%r13
 115c720:	00 
 115c721:	4c 89 ef             	mov    %r13,%rdi
 115c724:	48 8d b4 24 90 31 00 	lea    0x3190(%rsp),%rsi
 115c72b:	00 
 115c72c:	c5 f8 77             	vzeroupper 
 115c72f:	e8 2c 7a ff ff       	call   1154160 <zstd.smallHuffmanTreeSerializedLen>
 115c734:	66 83 bc 24 d0 03 00 	cmpw   $0x0,0x3d0(%rsp)

 115c874:	46 8b 5c 97 fc       	mov    -0x4(%rdi,%r10,4),%r11d
 115c879:	4d 85 db             	test   %r11,%r11
 115c87c:	74 51                	je     115c8cf <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1f2f>
 115c87e:	42 0f b6 9c 14 88 30 	movzbl 0x3088(%rsp,%r10,1),%ebx
 115c885:	00 00 
 115c887:	48 85 db             	test   %rbx,%rbx
 115c88a:	0f 84 52 04 00 00    	je     115cce2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2342>
 115c890:	48 ff c6             	inc    %rsi
 115c893:	49 c7 c6 ff ff ff ff 	mov    $0xffffffffffffffff,%r14
 115c89a:	49 0f 44 f6          	cmove  %r14,%rsi
 115c89e:	48 89 b4 24 70 1d 00 	mov    %rsi,0x1d70(%rsp)
 115c8a5:	00 
 115c8a6:	c6 84 24 c0 03 00 00 	movb   $0x0,0x3c0(%rsp)
 115c8ad:	00 
 115c8ae:	45 31 f6             	xor    %r14d,%r14d
 115c8b1:	45 84 f6             	test   %r14b,%r14b
 115c8b4:	0f 85 28 04 00 00    	jne    115cce2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2342>
 115c8ba:	49 0f af db          	imul   %r11,%rbx
 115c8be:	49 01 d9             	add    %rbx,%r9
 115c8c1:	0f 92 84 24 c0 03 00 	setb   0x3c0(%rsp)
 115c8c8:	00 
 115c8c9:	0f 82 13 04 00 00    	jb     115cce2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2342>
 115c8cf:	46 8b 1c 97          	mov    (%rdi,%r10,4),%r11d
 115c8d3:	4d 85 db             	test   %r11,%r11
 115c8d6:	74 8b                	je     115c863 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1ec3>
 115c8d8:	42 0f b6 9c 14 89 30 	movzbl 0x3089(%rsp,%r10,1),%ebx
 115c8df:	00 00 
 115c8e1:	48 85 db             	test   %rbx,%rbx
 115c8e4:	0f 84 f8 03 00 00    	je     115cce2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2342>
 115c8ea:	48 ff c6             	inc    %rsi
 115c8ed:	49 c7 c6 ff ff ff ff 	mov    $0xffffffffffffffff,%r14
 115c8f4:	49 0f 44 f6          	cmove  %r14,%rsi
 115c8f8:	48 89 b4 24 70 1d 00 	mov    %rsi,0x1d70(%rsp)
 115c8ff:	00 
 115c900:	c6 84 24 c0 03 00 00 	movb   $0x0,0x3c0(%rsp)
 115c907:	00 
 115c908:	45 31 f6             	xor    %r14d,%r14d

 115cc15:	48 8b 06             	mov    (%rsi),%rax
 115cc18:	48 ff c0             	inc    %rax
 115cc1b:	48 c7 c2 ff ff ff ff 	mov    $0xffffffffffffffff,%rdx
 115cc22:	48 0f 44 c2          	cmove  %rdx,%rax
 115cc26:	48 89 06             	mov    %rax,(%rsi)
 115cc29:	48 8b 74 24 10       	mov    0x10(%rsp),%rsi
