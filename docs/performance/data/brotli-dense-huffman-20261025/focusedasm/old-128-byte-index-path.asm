 11bb250:	45 89 c2             	mov    %r8d,%r10d
 11bb253:	49 ff c0             	inc    %r8
 11bb256:	41 0f b6 f1          	movzbl %r9b,%esi
 11bb25a:	45 0f b6 ca          	movzbl %r10b,%r9d
 11bb25e:	4e 8b 94 cd 58 f5 ff 	mov    -0xaa8(%rbp,%r9,8),%r10
 11bb265:	ff 
 11bb266:	4c 03 94 f5 58 f5 ff 	add    -0xaa8(%rbp,%rsi,8),%r10
 11bb26d:	ff 
 11bb26e:	4c 89 94 c5 58 f5 ff 	mov    %r10,-0xaa8(%rbp,%rax,8)
 11bb275:	ff 
 11bb276:	88 84 35 52 fd ff ff 	mov    %al,-0x2ae(%rbp,%rsi,1)
 11bb27d:	42 88 84 0d 52 fd ff 	mov    %al,-0x2ae(%rbp,%r9,1)
 11bb284:	ff 
 11bb285:	48 ff c0             	inc    %rax
 11bb288:	48 ff cf             	dec    %rdi
 11bb28b:	48 83 ff 01          	cmp    $0x1,%rdi
 11bb28f:	76 7b                	jbe    11bb30c <br.encoder.small_huffman.build__anon_35942+0x38c>
 11bb291:	4c 39 d9             	cmp    %r11,%rcx
 11bb294:	73 2a                	jae    11bb2c0 <br.encoder.small_huffman.build__anon_35942+0x340>
 11bb296:	44 0f b6 8c 0d 50 ff 	movzbl -0xb0(%rbp,%rcx,1),%r9d
 11bb29d:	ff ff 
 11bb29f:	49 39 c0             	cmp    %rax,%r8
 11bb2a2:	73 2c                	jae    11bb2d0 <br.encoder.small_huffman.build__anon_35942+0x350>
 11bb2a4:	41 0f b6 f1          	movzbl %r9b,%esi
 11bb2a8:	48 8b b4 f5 58 f5 ff 	mov    -0xaa8(%rbp,%rsi,8),%rsi
 11bb2af:	ff 
 11bb2b0:	4a 3b b4 c5 58 f5 ff 	cmp    -0xaa8(%rbp,%r8,8),%rsi
 11bb2b7:	ff 
 11bb2b8:	76 16                	jbe    11bb2d0 <br.encoder.small_huffman.build__anon_35942+0x350>
 11bb2ba:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)

 11bb30c:	c6 84 05 50 fe ff ff 	movb   $0x0,-0x1b0(%rbp,%rax,1)
 11bb313:	00 
 11bb314:	48 ff c8             	dec    %rax
 11bb317:	74 34                	je     11bb34d <br.encoder.small_huffman.build__anon_35942+0x3cd>
 11bb319:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)
 11bb320:	0f b6 8c 05 51 fd ff 	movzbl -0x2af(%rbp,%rax,1),%ecx
 11bb327:	ff 
 11bb328:	0f b6 8c 0d 51 fe ff 	movzbl -0x1af(%rbp,%rcx,1),%ecx
 11bb32f:	ff 
 11bb330:	c0 e1 03             	shl    $0x3,%cl
 11bb333:	80 c1 08             	add    $0x8,%cl
 11bb336:	c0 f9 03             	sar    $0x3,%cl
 11bb339:	78 30                	js     11bb36b <br.encoder.small_huffman.build__anon_35942+0x3eb>
 11bb33b:	80 e1 1f             	and    $0x1f,%cl
 11bb33e:	88 8c 05 50 fe ff ff 	mov    %cl,-0x1b0(%rbp,%rax,1)
