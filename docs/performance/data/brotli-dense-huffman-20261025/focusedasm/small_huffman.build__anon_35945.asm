
/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/7cab685de62cdb93856431f8e3ddb813/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

00000000011ba7c0 <br.encoder.small_huffman.build__anon_35945>:
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
 11ba7e5:	89 f0                	mov    %esi,%eax
 11ba7e7:	83 e0 07             	and    $0x7,%eax
 11ba7ea:	48 83 fe 08          	cmp    $0x8,%rsi
 11ba7ee:	73 1c                	jae    11ba80c <br.encoder.small_huffman.build__anon_35945+0x4c>
 11ba7f0:	31 c9                	xor    %ecx,%ecx
 11ba7f2:	e9 00 01 00 00       	jmp    11ba8f7 <br.encoder.small_huffman.build__anon_35945+0x137>
 11ba7f7:	48 85 f6             	test   %rsi,%rsi
 11ba7fa:	74 0d                	je     11ba809 <br.encoder.small_huffman.build__anon_35945+0x49>
 11ba7fc:	83 7c b7 fc 00       	cmpl   $0x0,-0x4(%rdi,%rsi,4)
 11ba801:	74 06                	je     11ba809 <br.encoder.small_huffman.build__anon_35945+0x49>
 11ba803:	c6 02 01             	movb   $0x1,(%rdx)
 11ba806:	b0 01                	mov    $0x1,%al
 11ba808:	c3                   	ret    
 11ba809:	31 c0                	xor    %eax,%eax
 11ba80b:	c3                   	ret    
 11ba80c:	41 89 f0             	mov    %esi,%r8d
 11ba80f:	41 81 e0 f8 01 00 00 	and    $0x1f8,%r8d
 11ba816:	31 c9                	xor    %ecx,%ecx
 11ba818:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 11ba81f:	00 
 11ba820:	44 8b 0c 8f          	mov    (%rdi,%rcx,4),%r9d
 11ba824:	4c 89 8c cd d8 eb ff 	mov    %r9,-0x1428(%rbp,%rcx,8)
 11ba82b:	ff 
 11ba82c:	66 89 8c 4d d0 fd ff 	mov    %cx,-0x230(%rbp,%rcx,2)
 11ba833:	ff 
 11ba834:	44 8b 4c 8f 04       	mov    0x4(%rdi,%rcx,4),%r9d
 11ba839:	4c 89 8c cd e0 eb ff 	mov    %r9,-0x1420(%rbp,%rcx,8)
 11ba840:	ff 
 11ba841:	44 8d 49 01          	lea    0x1(%rcx),%r9d
 11ba845:	66 44 89 8c 4d d2 fd 	mov    %r9w,-0x22e(%rbp,%rcx,2)
 11ba84c:	ff ff 
 11ba84e:	44 8b 4c 8f 08       	mov    0x8(%rdi,%rcx,4),%r9d
 11ba853:	4c 89 8c cd e8 eb ff 	mov    %r9,-0x1418(%rbp,%rcx,8)
 11ba85a:	ff 
 11ba85b:	44 8d 49 02          	lea    0x2(%rcx),%r9d
 11ba85f:	66 44 89 8c 4d d4 fd 	mov    %r9w,-0x22c(%rbp,%rcx,2)
 11ba866:	ff ff 
 11ba868:	44 8b 4c 8f 0c       	mov    0xc(%rdi,%rcx,4),%r9d
 11ba86d:	4c 89 8c cd f0 eb ff 	mov    %r9,-0x1410(%rbp,%rcx,8)
 11ba874:	ff 
 11ba875:	44 8d 49 03          	lea    0x3(%rcx),%r9d
 11ba879:	66 44 89 8c 4d d6 fd 	mov    %r9w,-0x22a(%rbp,%rcx,2)
 11ba880:	ff ff 
 11ba882:	44 8b 4c 8f 10       	mov    0x10(%rdi,%rcx,4),%r9d
 11ba887:	4c 89 8c cd f8 eb ff 	mov    %r9,-0x1408(%rbp,%rcx,8)
 11ba88e:	ff 
 11ba88f:	44 8d 49 04          	lea    0x4(%rcx),%r9d
 11ba893:	66 44 89 8c 4d d8 fd 	mov    %r9w,-0x228(%rbp,%rcx,2)
 11ba89a:	ff ff 
 11ba89c:	44 8b 4c 8f 14       	mov    0x14(%rdi,%rcx,4),%r9d
 11ba8a1:	4c 89 8c cd 00 ec ff 	mov    %r9,-0x1400(%rbp,%rcx,8)
 11ba8a8:	ff 
 11ba8a9:	44 8d 49 05          	lea    0x5(%rcx),%r9d
 11ba8ad:	66 44 89 8c 4d da fd 	mov    %r9w,-0x226(%rbp,%rcx,2)
 11ba8b4:	ff ff 
 11ba8b6:	44 8b 4c 8f 18       	mov    0x18(%rdi,%rcx,4),%r9d
 11ba8bb:	4c 89 8c cd 08 ec ff 	mov    %r9,-0x13f8(%rbp,%rcx,8)
 11ba8c2:	ff 
 11ba8c3:	44 8d 49 06          	lea    0x6(%rcx),%r9d
 11ba8c7:	66 44 89 8c 4d dc fd 	mov    %r9w,-0x224(%rbp,%rcx,2)
 11ba8ce:	ff ff 
 11ba8d0:	44 8b 4c 8f 1c       	mov    0x1c(%rdi,%rcx,4),%r9d
 11ba8d5:	4c 89 8c cd 10 ec ff 	mov    %r9,-0x13f0(%rbp,%rcx,8)
 11ba8dc:	ff 
 11ba8dd:	44 8d 49 07          	lea    0x7(%rcx),%r9d
 11ba8e1:	66 44 89 8c 4d de fd 	mov    %r9w,-0x222(%rbp,%rcx,2)
 11ba8e8:	ff ff 
 11ba8ea:	48 83 c1 08          	add    $0x8,%rcx
 11ba8ee:	4c 39 c1             	cmp    %r8,%rcx
 11ba8f1:	0f 85 29 ff ff ff    	jne    11ba820 <br.encoder.small_huffman.build__anon_35945+0x60>
 11ba8f7:	48 85 c0             	test   %rax,%rax
 11ba8fa:	74 20                	je     11ba91c <br.encoder.small_huffman.build__anon_35945+0x15c>
 11ba8fc:	0f 1f 40 00          	nopl   0x0(%rax)
 11ba900:	44 8b 04 8f          	mov    (%rdi,%rcx,4),%r8d
 11ba904:	4c 89 84 cd d8 eb ff 	mov    %r8,-0x1428(%rbp,%rcx,8)
 11ba90b:	ff 
 11ba90c:	66 89 8c 4d d0 fd ff 	mov    %cx,-0x230(%rbp,%rcx,2)
 11ba913:	ff 
 11ba914:	48 ff c1             	inc    %rcx
 11ba917:	48 ff c8             	dec    %rax
 11ba91a:	75 e4                	jne    11ba900 <br.encoder.small_huffman.build__anon_35945+0x140>
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
 11ba990:	eb 9e                	jmp    11ba930 <br.encoder.small_huffman.build__anon_35945+0x170>
 11ba992:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11ba999:	1f 84 00 00 00 00 00 
 11ba9a0:	4d 89 cc             	mov    %r9,%r12
 11ba9a3:	4c 89 d8             	mov    %r11,%rax
 11ba9a6:	48 83 f0 ff          	xor    $0xffffffffffffffff,%rax
 11ba9aa:	74 84                	je     11ba930 <br.encoder.small_huffman.build__anon_35945+0x170>
 11ba9ac:	49 83 fc 01          	cmp    $0x1,%r12
 11ba9b0:	4d 89 e6             	mov    %r12,%r14
 11ba9b3:	49 83 d6 00          	adc    $0x0,%r14
 11ba9b7:	49 83 fc 08          	cmp    $0x8,%r12
 11ba9bb:	73 13                	jae    11ba9d0 <br.encoder.small_huffman.build__anon_35945+0x210>
 11ba9bd:	45 31 e4             	xor    %r12d,%r12d
 11ba9c0:	41 83 e6 07          	and    $0x7,%r14d
 11ba9c4:	0f 85 8b 00 00 00    	jne    11baa55 <br.encoder.small_huffman.build__anon_35945+0x295>
 11ba9ca:	e9 61 ff ff ff       	jmp    11ba930 <br.encoder.small_huffman.build__anon_35945+0x170>
 11ba9cf:	90                   	nop
 11ba9d0:	4d 89 f5             	mov    %r14,%r13
 11ba9d3:	49 83 e5 f8          	and    $0xfffffffffffffff8,%r13
 11ba9d7:	48 8d 85 de fd ff ff 	lea    -0x222(%rbp),%rax
 11ba9de:	4a 8d 0c 40          	lea    (%rax,%r8,2),%rcx
 11ba9e2:	45 31 e4             	xor    %r12d,%r12d
 11ba9e5:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 11ba9ec:	00 00 00 00 
 11ba9f0:	41 8d 47 f9          	lea    -0x7(%r15),%eax
 11ba9f4:	66 42 89 44 61 f2    	mov    %ax,-0xe(%rcx,%r12,2)
 11ba9fa:	41 8d 47 fa          	lea    -0x6(%r15),%eax
 11ba9fe:	66 42 89 44 61 f4    	mov    %ax,-0xc(%rcx,%r12,2)
 11baa04:	41 8d 47 fb          	lea    -0x5(%r15),%eax
 11baa08:	66 42 89 44 61 f6    	mov    %ax,-0xa(%rcx,%r12,2)
 11baa0e:	41 8d 47 fc          	lea    -0x4(%r15),%eax
 11baa12:	66 42 89 44 61 f8    	mov    %ax,-0x8(%rcx,%r12,2)
 11baa18:	41 8d 47 fd          	lea    -0x3(%r15),%eax
 11baa1c:	66 42 89 44 61 fa    	mov    %ax,-0x6(%rcx,%r12,2)
 11baa22:	41 8d 47 fe          	lea    -0x2(%r15),%eax
 11baa26:	66 42 89 44 61 fc    	mov    %ax,-0x4(%rcx,%r12,2)
 11baa2c:	41 8d 47 ff          	lea    -0x1(%r15),%eax
 11baa30:	66 42 89 44 61 fe    	mov    %ax,-0x2(%rcx,%r12,2)
 11baa36:	66 46 89 3c 61       	mov    %r15w,(%rcx,%r12,2)
 11baa3b:	49 83 c4 08          	add    $0x8,%r12
 11baa3f:	41 83 c7 08          	add    $0x8,%r15d
 11baa43:	4d 39 e5             	cmp    %r12,%r13
 11baa46:	75 a8                	jne    11ba9f0 <br.encoder.small_huffman.build__anon_35945+0x230>
 11baa48:	4d 01 e0             	add    %r12,%r8
 11baa4b:	41 83 e6 07          	and    $0x7,%r14d
 11baa4f:	0f 84 db fe ff ff    	je     11ba930 <br.encoder.small_huffman.build__anon_35945+0x170>
 11baa55:	44 01 e3             	add    %r12d,%ebx
 11baa58:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 11baa5f:	00 
 11baa60:	66 42 89 9c 45 d0 fd 	mov    %bx,-0x230(%rbp,%r8,2)
 11baa67:	ff ff 
 11baa69:	49 ff c0             	inc    %r8
 11baa6c:	ff c3                	inc    %ebx
 11baa6e:	49 ff ce             	dec    %r14
 11baa71:	75 ed                	jne    11baa60 <br.encoder.small_huffman.build__anon_35945+0x2a0>
 11baa73:	e9 b8 fe ff ff       	jmp    11ba930 <br.encoder.small_huffman.build__anon_35945+0x170>
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
 11baba7:	81 e6 f8 01 00 00    	and    $0x1f8,%esi
 11babad:	31 ff                	xor    %edi,%edi
 11babaf:	90                   	nop
 11babb0:	0f b6 84 3d d1 fb ff 	movzbl -0x42f(%rbp,%rdi,1),%eax
 11babb7:	ff 
 11babb8:	24 0f                	and    $0xf,%al
 11babba:	41 88 04 38          	mov    %al,(%r8,%rdi,1)
 11babbe:	0f b6 84 3d d2 fb ff 	movzbl -0x42e(%rbp,%rdi,1),%eax
 11babc5:	ff 
 11babc6:	24 0f                	and    $0xf,%al
 11babc8:	41 88 44 38 01       	mov    %al,0x1(%r8,%rdi,1)
 11babcd:	0f b6 84 3d d3 fb ff 	movzbl -0x42d(%rbp,%rdi,1),%eax
 11babd4:	ff 
 11babd5:	24 0f                	and    $0xf,%al
 11babd7:	41 88 44 38 02       	mov    %al,0x2(%r8,%rdi,1)
 11babdc:	0f b6 84 3d d4 fb ff 	movzbl -0x42c(%rbp,%rdi,1),%eax
 11babe3:	ff 
 11babe4:	24 0f                	and    $0xf,%al
 11babe6:	41 88 44 38 03       	mov    %al,0x3(%r8,%rdi,1)
 11babeb:	0f b6 84 3d d5 fb ff 	movzbl -0x42b(%rbp,%rdi,1),%eax
 11babf2:	ff 
 11babf3:	24 0f                	and    $0xf,%al
 11babf5:	41 88 44 38 04       	mov    %al,0x4(%r8,%rdi,1)
 11babfa:	0f b6 84 3d d6 fb ff 	movzbl -0x42a(%rbp,%rdi,1),%eax
 11bac01:	ff 
 11bac02:	24 0f                	and    $0xf,%al
 11bac04:	41 88 44 38 05       	mov    %al,0x5(%r8,%rdi,1)
 11bac09:	0f b6 84 3d d7 fb ff 	movzbl -0x429(%rbp,%rdi,1),%eax
 11bac10:	ff 
 11bac11:	24 0f                	and    $0xf,%al
 11bac13:	41 88 44 38 06       	mov    %al,0x6(%r8,%rdi,1)
 11bac18:	0f b6 84 3d d8 fb ff 	movzbl -0x428(%rbp,%rdi,1),%eax
 11bac1f:	ff 
 11bac20:	24 0f                	and    $0xf,%al
 11bac22:	41 88 44 38 07       	mov    %al,0x7(%r8,%rdi,1)
 11bac27:	48 83 c7 08          	add    $0x8,%rdi
 11bac2b:	48 39 fe             	cmp    %rdi,%rsi
 11bac2e:	75 80                	jne    11babb0 <br.encoder.small_huffman.build__anon_35945+0x3f0>
 11bac30:	b0 01                	mov    $0x1,%al
 11bac32:	48 85 c9             	test   %rcx,%rcx
 11bac35:	74 2c                	je     11bac63 <br.encoder.small_huffman.build__anon_35945+0x4a3>
 11bac37:	48 8d 34 2f          	lea    (%rdi,%rbp,1),%rsi
 11bac3b:	48 81 c6 d1 fb ff ff 	add    $0xfffffffffffffbd1,%rsi
 11bac42:	49 01 f8             	add    %rdi,%r8
 11bac45:	31 ff                	xor    %edi,%edi
 11bac47:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 11bac4e:	00 00 
 11bac50:	0f b6 14 3e          	movzbl (%rsi,%rdi,1),%edx
 11bac54:	80 e2 0f             	and    $0xf,%dl
 11bac57:	41 88 14 38          	mov    %dl,(%r8,%rdi,1)
 11bac5b:	48 ff c7             	inc    %rdi
 11bac5e:	48 39 f9             	cmp    %rdi,%rcx
 11bac61:	75 ed                	jne    11bac50 <br.encoder.small_huffman.build__anon_35945+0x490>
 11bac63:	48 81 c4 80 17 00 00 	add    $0x1780,%rsp
 11bac6a:	5b                   	pop    %rbx
 11bac6b:	41 5c                	pop    %r12
 11bac6d:	41 5d                	pop    %r13
 11bac6f:	41 5e                	pop    %r14
 11bac71:	41 5f                	pop    %r15
 11bac73:	5d                   	pop    %rbp
 11bac74:	c3                   	ret    

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
