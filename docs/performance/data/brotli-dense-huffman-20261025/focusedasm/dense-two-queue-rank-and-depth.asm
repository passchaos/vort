 11ba7c0:	48 83 fe 01          	cmp    $0x1,%rsi
 11ba7c4:	76 31                	jbe    11ba7f7 <br.encoder.small_huffman.build__anon_35945+0x37>
 11ba7c6:	83 7c b7 fc 00       	cmpl   $0x0,-0x4(%rdi,%rsi,4)
 11ba7cb:	74 3c                	je     11ba809 <br.encoder.small_huffman.build__anon_35945+0x49>
 11ba7cd:	55                   	push   %rbp
 11ba7ce:	48 89 e5             	mov    %rsp,%rbp
 11ba7d1:	41 57                	push   %r15
 11ba7d3:	41 56                	push   %r14
 11ba7d5:	41 55                	push   %r13
 11ba7d7:	41 54                	push   %r12
 11ba7d9:	53                   	push   %rbx
 11ba7da:	48 81 ec 80 17 00 00 	sub    $0x1780,%rsp
 11ba7e1:	48 89 55 d0          	mov    %rdx,-0x30(%rbp)

 11ba91c:	48 8d 57 f8          	lea    -0x8(%rdi),%rdx
 11ba920:	45 31 c0             	xor    %r8d,%r8d
 11ba923:	49 89 f1             	mov    %rsi,%r9
 11ba926:	eb 1a                	jmp    11ba942 <br.encoder.small_huffman.build__anon_35945+0x182>
 11ba928:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 11ba92f:	00 
 11ba930:	4c 89 d9             	mov    %r11,%rcx
 11ba933:	48 f7 d1             	not    %rcx
 11ba936:	49 01 c9             	add    %rcx,%r9
 11ba939:	4d 39 da             	cmp    %r11,%r10
 11ba93c:	0f 84 36 01 00 00    	je     11baa78 <br.encoder.small_huffman.build__anon_35945+0x2b8>
 11ba942:	4d 8d 51 ff          	lea    -0x1(%r9),%r10
 11ba946:	4a 8d 0c 8a          	lea    (%rdx,%r9,4),%rcx
 11ba94a:	45 8d 71 06          	lea    0x6(%r9),%r14d
 11ba94e:	45 8d 69 ff          	lea    -0x1(%r9),%r13d
 11ba952:	45 31 e4             	xor    %r12d,%r12d
 11ba955:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 11ba95c:	00 00 00 00 
 11ba960:	4d 89 e3             	mov    %r12,%r11
 11ba963:	45 89 f7             	mov    %r14d,%r15d
 11ba966:	44 89 eb             	mov    %r13d,%ebx
 11ba969:	4d 39 e2             	cmp    %r12,%r10
 11ba96c:	74 32                	je     11ba9a0 <br.encoder.small_huffman.build__anon_35945+0x1e0>
 11ba96e:	8b 01                	mov    (%rcx),%eax
 11ba970:	4d 8d 63 01          	lea    0x1(%r11),%r12
 11ba974:	48 83 c1 fc          	add    $0xfffffffffffffffc,%rcx
 11ba978:	45 8d 77 ff          	lea    -0x1(%r15),%r14d
 11ba97c:	44 8d 6b ff          	lea    -0x1(%rbx),%r13d
 11ba980:	42 3b 44 8f fc       	cmp    -0x4(%rdi,%r9,4),%eax
 11ba985:	74 d9                	je     11ba960 <br.encoder.small_huffman.build__anon_35945+0x1a0>
 11ba987:	4c 89 d8             	mov    %r11,%rax
 11ba98a:	48 83 f0 ff          	xor    $0xffffffffffffffff,%rax
 11ba98e:	75 1c                	jne    11ba9ac <br.encoder.small_huffman.build__anon_35945+0x1ec>

 11baa78:	31 c9                	xor    %ecx,%ecx
 11baa7a:	48 89 f7             	mov    %rsi,%rdi
 11baa7d:	48 89 f0             	mov    %rsi,%rax
 11baa80:	49 89 f0             	mov    %rsi,%r8
 11baa83:	eb 4e                	jmp    11baad3 <br.encoder.small_huffman.build__anon_35945+0x313>
 11baa85:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 11baa8c:	00 00 00 00 
 11baa90:	45 89 c2             	mov    %r8d,%r10d
 11baa93:	49 ff c0             	inc    %r8
 11baa96:	41 0f b7 d1          	movzwl %r9w,%edx
 11baa9a:	45 0f b7 ca          	movzwl %r10w,%r9d
 11baa9e:	4e 8b 94 cd d8 eb ff 	mov    -0x1428(%rbp,%r9,8),%r10
 11baaa5:	ff 
 11baaa6:	4c 03 94 d5 d8 eb ff 	add    -0x1428(%rbp,%rdx,8),%r10
 11baaad:	ff 
 11baaae:	4c 89 94 c5 d8 eb ff 	mov    %r10,-0x1428(%rbp,%rax,8)
 11baab5:	ff 
 11baab6:	66 89 84 55 da e7 ff 	mov    %ax,-0x1826(%rbp,%rdx,2)
 11baabd:	ff 
 11baabe:	66 42 89 84 4d da e7 	mov    %ax,-0x1826(%rbp,%r9,2)
 11baac5:	ff ff 
 11baac7:	48 ff c0             	inc    %rax
 11baaca:	48 ff cf             	dec    %rdi
 11baacd:	48 83 ff 01          	cmp    $0x1,%rdi
 11baad1:	76 79                	jbe    11bab4c <br.encoder.small_huffman.build__anon_35945+0x38c>
 11baad3:	48 39 f1             	cmp    %rsi,%rcx
 11baad6:	73 28                	jae    11bab00 <br.encoder.small_huffman.build__anon_35945+0x340>
 11baad8:	44 0f b7 8c 4d d0 fd 	movzwl -0x230(%rbp,%rcx,2),%r9d
 11baadf:	ff ff 
 11baae1:	49 39 c0             	cmp    %rax,%r8
 11baae4:	73 2a                	jae    11bab10 <br.encoder.small_huffman.build__anon_35945+0x350>
 11baae6:	41 0f b7 d1          	movzwl %r9w,%edx
 11baaea:	48 8b 94 d5 d8 eb ff 	mov    -0x1428(%rbp,%rdx,8),%rdx
 11baaf1:	ff 
 11baaf2:	4a 3b 94 c5 d8 eb ff 	cmp    -0x1428(%rbp,%r8,8),%rdx
 11baaf9:	ff 
 11baafa:	76 14                	jbe    11bab10 <br.encoder.small_huffman.build__anon_35945+0x350>
 11baafc:	0f 1f 40 00          	nopl   0x0(%rax)
 11bab00:	45 89 c1             	mov    %r8d,%r9d
 11bab03:	49 ff c0             	inc    %r8
 11bab06:	48 39 f1             	cmp    %rsi,%rcx
 11bab09:	73 85                	jae    11baa90 <br.encoder.small_huffman.build__anon_35945+0x2d0>
 11bab0b:	eb 0f                	jmp    11bab1c <br.encoder.small_huffman.build__anon_35945+0x35c>
 11bab0d:	0f 1f 00             	nopl   (%rax)
 11bab10:	48 ff c1             	inc    %rcx
 11bab13:	48 39 f1             	cmp    %rsi,%rcx
 11bab16:	0f 83 74 ff ff ff    	jae    11baa90 <br.encoder.small_huffman.build__anon_35945+0x2d0>
 11bab1c:	44 0f b7 94 4d d0 fd 	movzwl -0x230(%rbp,%rcx,2),%r10d
 11bab23:	ff ff 
 11bab25:	49 39 c0             	cmp    %rax,%r8
 11bab28:	73 1a                	jae    11bab44 <br.encoder.small_huffman.build__anon_35945+0x384>
 11bab2a:	41 0f b7 d2          	movzwl %r10w,%edx
 11bab2e:	48 8b 94 d5 d8 eb ff 	mov    -0x1428(%rbp,%rdx,8),%rdx
 11bab35:	ff 
 11bab36:	4a 3b 94 c5 d8 eb ff 	cmp    -0x1428(%rbp,%r8,8),%rdx
 11bab3d:	ff 
 11bab3e:	0f 87 4c ff ff ff    	ja     11baa90 <br.encoder.small_huffman.build__anon_35945+0x2d0>
 11bab44:	48 ff c1             	inc    %rcx
 11bab47:	e9 4a ff ff ff       	jmp    11baa96 <br.encoder.small_huffman.build__anon_35945+0x2d6>

 11bab4c:	c6 84 05 d0 fb ff ff 	movb   $0x0,-0x430(%rbp,%rax,1)
 11bab53:	00 
 11bab54:	4c 8b 45 d0          	mov    -0x30(%rbp),%r8
 11bab58:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 11bab5f:	00 
 11bab60:	0f b7 8c 45 d6 e7 ff 	movzwl -0x182a(%rbp,%rax,2),%ecx
 11bab67:	ff 
 11bab68:	0f b6 8c 0d d1 fb ff 	movzbl -0x42f(%rbp,%rcx,1),%ecx
 11bab6f:	ff 
 11bab70:	c0 e1 03             	shl    $0x3,%cl
 11bab73:	80 c1 08             	add    $0x8,%cl
 11bab76:	c0 f9 03             	sar    $0x3,%cl
 11bab79:	78 25                	js     11baba0 <br.encoder.small_huffman.build__anon_35945+0x3e0>
 11bab7b:	80 e1 1f             	and    $0x1f,%cl
 11bab7e:	88 8c 05 cf fb ff ff 	mov    %cl,-0x431(%rbp,%rax,1)
 11bab85:	48 ff c8             	dec    %rax
 11bab88:	48 83 f8 01          	cmp    $0x1,%rax
 11bab8c:	75 d2                	jne    11bab60 <br.encoder.small_huffman.build__anon_35945+0x3a0>
 11bab8e:	89 f1                	mov    %esi,%ecx
 11bab90:	83 e1 07             	and    $0x7,%ecx
 11bab93:	48 83 fe 08          	cmp    $0x8,%rsi
 11bab97:	73 0e                	jae    11baba7 <br.encoder.small_huffman.build__anon_35945+0x3e7>
 11bab99:	31 ff                	xor    %edi,%edi
 11bab9b:	e9 90 00 00 00       	jmp    11bac30 <br.encoder.small_huffman.build__anon_35945+0x470>
 11baba0:	31 c0                	xor    %eax,%eax
 11baba2:	e9 bc 00 00 00       	jmp    11bac63 <br.encoder.small_huffman.build__anon_35945+0x4a3>
