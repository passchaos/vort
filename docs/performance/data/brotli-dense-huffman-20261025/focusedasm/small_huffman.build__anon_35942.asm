
/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/7cab685de62cdb93856431f8e3ddb813/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

00000000011baf80 <br.encoder.small_huffman.build__anon_35942>:
 11baf80:	49 89 f3             	mov    %rsi,%r11
 11baf83:	45 84 db             	test   %r11b,%r11b
 11baf86:	74 0c                	je     11baf94 <br.encoder.small_huffman.build__anon_35942+0x14>
 11baf88:	41 83 fb 01          	cmp    $0x1,%r11d
 11baf8c:	75 09                	jne    11baf97 <br.encoder.small_huffman.build__anon_35942+0x17>
 11baf8e:	c6 02 01             	movb   $0x1,(%rdx)
 11baf91:	b0 01                	mov    $0x1,%al
 11baf93:	c3                   	ret    
 11baf94:	31 c0                	xor    %eax,%eax
 11baf96:	c3                   	ret    
 11baf97:	55                   	push   %rbp
 11baf98:	48 89 e5             	mov    %rsp,%rbp
 11baf9b:	41 57                	push   %r15
 11baf9d:	41 56                	push   %r14
 11baf9f:	41 55                	push   %r13
 11bafa1:	41 54                	push   %r12
 11bafa3:	53                   	push   %rbx
 11bafa4:	48 81 ec 00 0a 00 00 	sub    $0xa00,%rsp
 11bafab:	4d 85 db             	test   %r11,%r11
 11bafae:	74 13                	je     11bafc3 <br.encoder.small_huffman.build__anon_35942+0x43>
 11bafb0:	44 89 d8             	mov    %r11d,%eax
 11bafb3:	83 e0 07             	and    $0x7,%eax
 11bafb6:	49 83 fb 08          	cmp    $0x8,%r11
 11bafba:	73 13                	jae    11bafcf <br.encoder.small_huffman.build__anon_35942+0x4f>
 11bafbc:	31 c9                	xor    %ecx,%ecx
 11bafbe:	e9 ec 00 00 00       	jmp    11bb0af <br.encoder.small_huffman.build__anon_35942+0x12f>
 11bafc3:	48 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%rax
 11bafca:	e9 51 03 00 00       	jmp    11bb320 <br.encoder.small_huffman.build__anon_35942+0x3a0>
 11bafcf:	45 89 d8             	mov    %r11d,%r8d
 11bafd2:	41 81 e0 f8 00 00 00 	and    $0xf8,%r8d
 11bafd9:	31 c9                	xor    %ecx,%ecx
 11bafdb:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 11bafe0:	44 8b 0c 8f          	mov    (%rdi,%rcx,4),%r9d
 11bafe4:	4c 89 8c cd 58 f5 ff 	mov    %r9,-0xaa8(%rbp,%rcx,8)
 11bafeb:	ff 
 11bafec:	88 8c 0d 50 ff ff ff 	mov    %cl,-0xb0(%rbp,%rcx,1)
 11baff3:	44 8b 4c 8f 04       	mov    0x4(%rdi,%rcx,4),%r9d
 11baff8:	4c 89 8c cd 60 f5 ff 	mov    %r9,-0xaa0(%rbp,%rcx,8)
 11bafff:	ff 
 11bb000:	44 8d 49 01          	lea    0x1(%rcx),%r9d
 11bb004:	44 88 8c 0d 51 ff ff 	mov    %r9b,-0xaf(%rbp,%rcx,1)
 11bb00b:	ff 
 11bb00c:	44 8b 4c 8f 08       	mov    0x8(%rdi,%rcx,4),%r9d
 11bb011:	4c 89 8c cd 68 f5 ff 	mov    %r9,-0xa98(%rbp,%rcx,8)
 11bb018:	ff 
 11bb019:	44 8d 49 02          	lea    0x2(%rcx),%r9d
 11bb01d:	44 88 8c 0d 52 ff ff 	mov    %r9b,-0xae(%rbp,%rcx,1)
 11bb024:	ff 
 11bb025:	44 8b 4c 8f 0c       	mov    0xc(%rdi,%rcx,4),%r9d
 11bb02a:	4c 89 8c cd 70 f5 ff 	mov    %r9,-0xa90(%rbp,%rcx,8)
 11bb031:	ff 
 11bb032:	44 8d 49 03          	lea    0x3(%rcx),%r9d
 11bb036:	44 88 8c 0d 53 ff ff 	mov    %r9b,-0xad(%rbp,%rcx,1)
 11bb03d:	ff 
 11bb03e:	44 8b 4c 8f 10       	mov    0x10(%rdi,%rcx,4),%r9d
 11bb043:	4c 89 8c cd 78 f5 ff 	mov    %r9,-0xa88(%rbp,%rcx,8)
 11bb04a:	ff 
 11bb04b:	44 8d 49 04          	lea    0x4(%rcx),%r9d
 11bb04f:	44 88 8c 0d 54 ff ff 	mov    %r9b,-0xac(%rbp,%rcx,1)
 11bb056:	ff 
 11bb057:	44 8b 4c 8f 14       	mov    0x14(%rdi,%rcx,4),%r9d
 11bb05c:	4c 89 8c cd 80 f5 ff 	mov    %r9,-0xa80(%rbp,%rcx,8)
 11bb063:	ff 
 11bb064:	44 8d 49 05          	lea    0x5(%rcx),%r9d
 11bb068:	44 88 8c 0d 55 ff ff 	mov    %r9b,-0xab(%rbp,%rcx,1)
 11bb06f:	ff 
 11bb070:	44 8b 4c 8f 18       	mov    0x18(%rdi,%rcx,4),%r9d
 11bb075:	4c 89 8c cd 88 f5 ff 	mov    %r9,-0xa78(%rbp,%rcx,8)
 11bb07c:	ff 
 11bb07d:	44 8d 49 06          	lea    0x6(%rcx),%r9d
 11bb081:	44 88 8c 0d 56 ff ff 	mov    %r9b,-0xaa(%rbp,%rcx,1)
 11bb088:	ff 
 11bb089:	44 8b 4c 8f 1c       	mov    0x1c(%rdi,%rcx,4),%r9d
 11bb08e:	4c 89 8c cd 90 f5 ff 	mov    %r9,-0xa70(%rbp,%rcx,8)
 11bb095:	ff 
 11bb096:	44 8d 49 07          	lea    0x7(%rcx),%r9d
 11bb09a:	44 88 8c 0d 57 ff ff 	mov    %r9b,-0xa9(%rbp,%rcx,1)
 11bb0a1:	ff 
 11bb0a2:	48 83 c1 08          	add    $0x8,%rcx
 11bb0a6:	4c 39 c1             	cmp    %r8,%rcx
 11bb0a9:	0f 85 31 ff ff ff    	jne    11bafe0 <br.encoder.small_huffman.build__anon_35942+0x60>
 11bb0af:	48 85 c0             	test   %rax,%rax
 11bb0b2:	74 27                	je     11bb0db <br.encoder.small_huffman.build__anon_35942+0x15b>
 11bb0b4:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 11bb0bb:	00 00 00 00 00 
 11bb0c0:	44 8b 04 8f          	mov    (%rdi,%rcx,4),%r8d
 11bb0c4:	4c 89 84 cd 58 f5 ff 	mov    %r8,-0xaa8(%rbp,%rcx,8)
 11bb0cb:	ff 
 11bb0cc:	88 8c 0d 50 ff ff ff 	mov    %cl,-0xb0(%rbp,%rcx,1)
 11bb0d3:	48 ff c1             	inc    %rcx
 11bb0d6:	48 ff c8             	dec    %rax
 11bb0d9:	75 e5                	jne    11bb0c0 <br.encoder.small_huffman.build__anon_35942+0x140>
 11bb0db:	48 8d 77 f8          	lea    -0x8(%rdi),%rsi
 11bb0df:	45 31 c0             	xor    %r8d,%r8d
 11bb0e2:	4c 89 5d d0          	mov    %r11,-0x30(%rbp)
 11bb0e6:	4d 89 d9             	mov    %r11,%r9
 11bb0e9:	eb 17                	jmp    11bb102 <br.encoder.small_huffman.build__anon_35942+0x182>
 11bb0eb:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 11bb0f0:	4c 89 d9             	mov    %r11,%rcx
 11bb0f3:	48 f7 d1             	not    %rcx
 11bb0f6:	49 01 c9             	add    %rcx,%r9
 11bb0f9:	4d 39 da             	cmp    %r11,%r10
 11bb0fc:	0f 84 26 01 00 00    	je     11bb228 <br.encoder.small_huffman.build__anon_35942+0x2a8>
 11bb102:	4d 8d 51 ff          	lea    -0x1(%r9),%r10
 11bb106:	4a 8d 0c 8e          	lea    (%rsi,%r9,4),%rcx
 11bb10a:	45 8d 71 06          	lea    0x6(%r9),%r14d
 11bb10e:	45 8d 69 ff          	lea    -0x1(%r9),%r13d
 11bb112:	45 31 e4             	xor    %r12d,%r12d
 11bb115:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 11bb11c:	00 00 00 00 
 11bb120:	4d 89 e3             	mov    %r12,%r11
 11bb123:	45 89 f7             	mov    %r14d,%r15d
 11bb126:	44 89 eb             	mov    %r13d,%ebx
 11bb129:	4d 39 e2             	cmp    %r12,%r10
 11bb12c:	74 32                	je     11bb160 <br.encoder.small_huffman.build__anon_35942+0x1e0>
 11bb12e:	8b 01                	mov    (%rcx),%eax
 11bb130:	4d 8d 63 01          	lea    0x1(%r11),%r12
 11bb134:	48 83 c1 fc          	add    $0xfffffffffffffffc,%rcx
 11bb138:	45 8d 77 ff          	lea    -0x1(%r15),%r14d
 11bb13c:	44 8d 6b ff          	lea    -0x1(%rbx),%r13d
 11bb140:	42 3b 44 8f fc       	cmp    -0x4(%rdi,%r9,4),%eax
 11bb145:	74 d9                	je     11bb120 <br.encoder.small_huffman.build__anon_35942+0x1a0>
 11bb147:	4c 89 d8             	mov    %r11,%rax
 11bb14a:	48 83 f0 ff          	xor    $0xffffffffffffffff,%rax
 11bb14e:	75 1c                	jne    11bb16c <br.encoder.small_huffman.build__anon_35942+0x1ec>
 11bb150:	eb 9e                	jmp    11bb0f0 <br.encoder.small_huffman.build__anon_35942+0x170>
 11bb152:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11bb159:	1f 84 00 00 00 00 00 
 11bb160:	4d 89 cc             	mov    %r9,%r12
 11bb163:	4c 89 d8             	mov    %r11,%rax
 11bb166:	48 83 f0 ff          	xor    $0xffffffffffffffff,%rax
 11bb16a:	74 84                	je     11bb0f0 <br.encoder.small_huffman.build__anon_35942+0x170>
 11bb16c:	49 83 fc 01          	cmp    $0x1,%r12
 11bb170:	4d 89 e6             	mov    %r12,%r14
 11bb173:	49 83 d6 00          	adc    $0x0,%r14
 11bb177:	49 83 fc 08          	cmp    $0x8,%r12
 11bb17b:	73 13                	jae    11bb190 <br.encoder.small_huffman.build__anon_35942+0x210>
 11bb17d:	45 31 e4             	xor    %r12d,%r12d
 11bb180:	41 83 e6 07          	and    $0x7,%r14d
 11bb184:	0f 85 83 00 00 00    	jne    11bb20d <br.encoder.small_huffman.build__anon_35942+0x28d>
 11bb18a:	e9 61 ff ff ff       	jmp    11bb0f0 <br.encoder.small_huffman.build__anon_35942+0x170>
 11bb18f:	90                   	nop
 11bb190:	4d 89 f5             	mov    %r14,%r13
 11bb193:	49 83 e5 f8          	and    $0xfffffffffffffff8,%r13
 11bb197:	48 8d 85 57 ff ff ff 	lea    -0xa9(%rbp),%rax
 11bb19e:	4a 8d 0c 00          	lea    (%rax,%r8,1),%rcx
 11bb1a2:	45 31 e4             	xor    %r12d,%r12d
 11bb1a5:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 11bb1ac:	00 00 00 00 
 11bb1b0:	41 8d 47 f9          	lea    -0x7(%r15),%eax
 11bb1b4:	42 88 44 21 f9       	mov    %al,-0x7(%rcx,%r12,1)
 11bb1b9:	41 8d 47 fa          	lea    -0x6(%r15),%eax
 11bb1bd:	42 88 44 21 fa       	mov    %al,-0x6(%rcx,%r12,1)
 11bb1c2:	41 8d 47 fb          	lea    -0x5(%r15),%eax
 11bb1c6:	42 88 44 21 fb       	mov    %al,-0x5(%rcx,%r12,1)
 11bb1cb:	41 8d 47 fc          	lea    -0x4(%r15),%eax
 11bb1cf:	42 88 44 21 fc       	mov    %al,-0x4(%rcx,%r12,1)
 11bb1d4:	41 8d 47 fd          	lea    -0x3(%r15),%eax
 11bb1d8:	42 88 44 21 fd       	mov    %al,-0x3(%rcx,%r12,1)
 11bb1dd:	41 8d 47 fe          	lea    -0x2(%r15),%eax
 11bb1e1:	42 88 44 21 fe       	mov    %al,-0x2(%rcx,%r12,1)
 11bb1e6:	41 8d 47 ff          	lea    -0x1(%r15),%eax
 11bb1ea:	42 88 44 21 ff       	mov    %al,-0x1(%rcx,%r12,1)
 11bb1ef:	46 88 3c 21          	mov    %r15b,(%rcx,%r12,1)
 11bb1f3:	49 83 c4 08          	add    $0x8,%r12
 11bb1f7:	41 80 c7 08          	add    $0x8,%r15b
 11bb1fb:	4d 39 e5             	cmp    %r12,%r13
 11bb1fe:	75 b0                	jne    11bb1b0 <br.encoder.small_huffman.build__anon_35942+0x230>
 11bb200:	4d 01 e0             	add    %r12,%r8
 11bb203:	41 83 e6 07          	and    $0x7,%r14d
 11bb207:	0f 84 e3 fe ff ff    	je     11bb0f0 <br.encoder.small_huffman.build__anon_35942+0x170>
 11bb20d:	41 00 dc             	add    %bl,%r12b
 11bb210:	46 88 a4 05 50 ff ff 	mov    %r12b,-0xb0(%rbp,%r8,1)
 11bb217:	ff 
 11bb218:	49 ff c0             	inc    %r8
 11bb21b:	41 fe c4             	inc    %r12b
 11bb21e:	49 ff ce             	dec    %r14
 11bb221:	75 ed                	jne    11bb210 <br.encoder.small_huffman.build__anon_35942+0x290>
 11bb223:	e9 c8 fe ff ff       	jmp    11bb0f0 <br.encoder.small_huffman.build__anon_35942+0x170>
 11bb228:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 11bb22c:	4c 89 d8             	mov    %r11,%rax
 11bb22f:	49 83 fb 02          	cmp    $0x2,%r11
 11bb233:	0f 82 d3 00 00 00    	jb     11bb30c <br.encoder.small_huffman.build__anon_35942+0x38c>
 11bb239:	31 c9                	xor    %ecx,%ecx
 11bb23b:	4c 89 df             	mov    %r11,%rdi
 11bb23e:	4c 89 d8             	mov    %r11,%rax
 11bb241:	4d 89 d8             	mov    %r11,%r8
 11bb244:	eb 4b                	jmp    11bb291 <br.encoder.small_huffman.build__anon_35942+0x311>
 11bb246:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 11bb24d:	00 00 00 
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
 11bb2c0:	45 89 c1             	mov    %r8d,%r9d
 11bb2c3:	49 ff c0             	inc    %r8
 11bb2c6:	4c 39 d9             	cmp    %r11,%rcx
 11bb2c9:	73 85                	jae    11bb250 <br.encoder.small_huffman.build__anon_35942+0x2d0>
 11bb2cb:	eb 0f                	jmp    11bb2dc <br.encoder.small_huffman.build__anon_35942+0x35c>
 11bb2cd:	0f 1f 00             	nopl   (%rax)
 11bb2d0:	48 ff c1             	inc    %rcx
 11bb2d3:	4c 39 d9             	cmp    %r11,%rcx
 11bb2d6:	0f 83 74 ff ff ff    	jae    11bb250 <br.encoder.small_huffman.build__anon_35942+0x2d0>
 11bb2dc:	44 0f b6 94 0d 50 ff 	movzbl -0xb0(%rbp,%rcx,1),%r10d
 11bb2e3:	ff ff 
 11bb2e5:	49 39 c0             	cmp    %rax,%r8
 11bb2e8:	73 1a                	jae    11bb304 <br.encoder.small_huffman.build__anon_35942+0x384>
 11bb2ea:	41 0f b6 f2          	movzbl %r10b,%esi
 11bb2ee:	48 8b b4 f5 58 f5 ff 	mov    -0xaa8(%rbp,%rsi,8),%rsi
 11bb2f5:	ff 
 11bb2f6:	4a 3b b4 c5 58 f5 ff 	cmp    -0xaa8(%rbp,%r8,8),%rsi
 11bb2fd:	ff 
 11bb2fe:	0f 87 4c ff ff ff    	ja     11bb250 <br.encoder.small_huffman.build__anon_35942+0x2d0>
 11bb304:	48 ff c1             	inc    %rcx
 11bb307:	e9 4a ff ff ff       	jmp    11bb256 <br.encoder.small_huffman.build__anon_35942+0x2d6>
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
 11bb345:	48 ff c8             	dec    %rax
 11bb348:	48 85 c0             	test   %rax,%rax
 11bb34b:	75 d3                	jne    11bb320 <br.encoder.small_huffman.build__anon_35942+0x3a0>
 11bb34d:	b0 01                	mov    $0x1,%al
 11bb34f:	4d 85 db             	test   %r11,%r11
 11bb352:	0f 84 ed 00 00 00    	je     11bb445 <br.encoder.small_huffman.build__anon_35942+0x4c5>
 11bb358:	44 89 d9             	mov    %r11d,%ecx
 11bb35b:	83 e1 07             	and    $0x7,%ecx
 11bb35e:	49 83 fb 08          	cmp    $0x8,%r11
 11bb362:	73 0e                	jae    11bb372 <br.encoder.small_huffman.build__anon_35942+0x3f2>
 11bb364:	31 ff                	xor    %edi,%edi
 11bb366:	e9 a9 00 00 00       	jmp    11bb414 <br.encoder.small_huffman.build__anon_35942+0x494>
 11bb36b:	31 c0                	xor    %eax,%eax
 11bb36d:	e9 d3 00 00 00       	jmp    11bb445 <br.encoder.small_huffman.build__anon_35942+0x4c5>
 11bb372:	41 81 e3 f8 00 00 00 	and    $0xf8,%r11d
 11bb379:	31 ff                	xor    %edi,%edi
 11bb37b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 11bb380:	0f b6 b4 3d 51 fe ff 	movzbl -0x1af(%rbp,%rdi,1),%esi
 11bb387:	ff 
 11bb388:	40 80 e6 0f          	and    $0xf,%sil
 11bb38c:	40 88 34 3a          	mov    %sil,(%rdx,%rdi,1)
 11bb390:	0f b6 b4 3d 52 fe ff 	movzbl -0x1ae(%rbp,%rdi,1),%esi
 11bb397:	ff 
 11bb398:	40 80 e6 0f          	and    $0xf,%sil
 11bb39c:	40 88 74 3a 01       	mov    %sil,0x1(%rdx,%rdi,1)
 11bb3a1:	0f b6 b4 3d 53 fe ff 	movzbl -0x1ad(%rbp,%rdi,1),%esi
 11bb3a8:	ff 
 11bb3a9:	40 80 e6 0f          	and    $0xf,%sil
 11bb3ad:	40 88 74 3a 02       	mov    %sil,0x2(%rdx,%rdi,1)
 11bb3b2:	0f b6 b4 3d 54 fe ff 	movzbl -0x1ac(%rbp,%rdi,1),%esi
 11bb3b9:	ff 
 11bb3ba:	40 80 e6 0f          	and    $0xf,%sil
 11bb3be:	40 88 74 3a 03       	mov    %sil,0x3(%rdx,%rdi,1)
 11bb3c3:	0f b6 b4 3d 55 fe ff 	movzbl -0x1ab(%rbp,%rdi,1),%esi
 11bb3ca:	ff 
 11bb3cb:	40 80 e6 0f          	and    $0xf,%sil
 11bb3cf:	40 88 74 3a 04       	mov    %sil,0x4(%rdx,%rdi,1)
 11bb3d4:	0f b6 b4 3d 56 fe ff 	movzbl -0x1aa(%rbp,%rdi,1),%esi
 11bb3db:	ff 
 11bb3dc:	40 80 e6 0f          	and    $0xf,%sil
 11bb3e0:	40 88 74 3a 05       	mov    %sil,0x5(%rdx,%rdi,1)
 11bb3e5:	0f b6 b4 3d 57 fe ff 	movzbl -0x1a9(%rbp,%rdi,1),%esi
 11bb3ec:	ff 
 11bb3ed:	40 80 e6 0f          	and    $0xf,%sil
 11bb3f1:	40 88 74 3a 06       	mov    %sil,0x6(%rdx,%rdi,1)
 11bb3f6:	0f b6 b4 3d 58 fe ff 	movzbl -0x1a8(%rbp,%rdi,1),%esi
 11bb3fd:	ff 
 11bb3fe:	40 80 e6 0f          	and    $0xf,%sil
 11bb402:	40 88 74 3a 07       	mov    %sil,0x7(%rdx,%rdi,1)
 11bb407:	48 83 c7 08          	add    $0x8,%rdi
 11bb40b:	49 39 fb             	cmp    %rdi,%r11
 11bb40e:	0f 85 6c ff ff ff    	jne    11bb380 <br.encoder.small_huffman.build__anon_35942+0x400>
 11bb414:	48 85 c9             	test   %rcx,%rcx
 11bb417:	74 2c                	je     11bb445 <br.encoder.small_huffman.build__anon_35942+0x4c5>
 11bb419:	48 8d 34 2f          	lea    (%rdi,%rbp,1),%rsi
 11bb41d:	48 81 c6 51 fe ff ff 	add    $0xfffffffffffffe51,%rsi
 11bb424:	48 01 fa             	add    %rdi,%rdx
 11bb427:	31 ff                	xor    %edi,%edi
 11bb429:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)
 11bb430:	44 0f b6 04 3e       	movzbl (%rsi,%rdi,1),%r8d
 11bb435:	41 80 e0 0f          	and    $0xf,%r8b
 11bb439:	44 88 04 3a          	mov    %r8b,(%rdx,%rdi,1)
 11bb43d:	48 ff c7             	inc    %rdi
 11bb440:	48 39 f9             	cmp    %rdi,%rcx
 11bb443:	75 eb                	jne    11bb430 <br.encoder.small_huffman.build__anon_35942+0x4b0>
 11bb445:	48 81 c4 00 0a 00 00 	add    $0xa00,%rsp
 11bb44c:	5b                   	pop    %rbx
 11bb44d:	41 5c                	pop    %r12
 11bb44f:	41 5d                	pop    %r13
 11bb451:	41 5e                	pop    %r14
 11bb453:	41 5f                	pop    %r15
 11bb455:	5d                   	pop    %rbp
 11bb456:	c3                   	ret    

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
