
/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/7cab685de62cdb93856431f8e3ddb813/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

00000000011bb460 <br.encoder.small_huffman.build__anon_35926>:
 11bb460:	48 85 f6             	test   %rsi,%rsi
 11bb463:	74 0f                	je     11bb474 <br.encoder.small_huffman.build__anon_35926+0x14>
 11bb465:	49 89 f2             	mov    %rsi,%r10
 11bb468:	48 83 fe 01          	cmp    $0x1,%rsi
 11bb46c:	75 09                	jne    11bb477 <br.encoder.small_huffman.build__anon_35926+0x17>
 11bb46e:	c6 02 01             	movb   $0x1,(%rdx)
 11bb471:	b0 01                	mov    $0x1,%al
 11bb473:	c3                   	ret    
 11bb474:	31 c0                	xor    %eax,%eax
 11bb476:	c3                   	ret    
 11bb477:	55                   	push   %rbp
 11bb478:	48 89 e5             	mov    %rsp,%rbp
 11bb47b:	41 57                	push   %r15
 11bb47d:	41 56                	push   %r14
 11bb47f:	41 55                	push   %r13
 11bb481:	41 54                	push   %r12
 11bb483:	53                   	push   %rbx
 11bb484:	48 81 ec c8 04 00 00 	sub    $0x4c8,%rsp
 11bb48b:	49 8d 42 ff          	lea    -0x1(%r10),%rax
 11bb48f:	44 89 d1             	mov    %r10d,%ecx
 11bb492:	83 e1 07             	and    $0x7,%ecx
 11bb495:	48 89 45 d0          	mov    %rax,-0x30(%rbp)
 11bb499:	48 83 f8 07          	cmp    $0x7,%rax
 11bb49d:	73 08                	jae    11bb4a7 <br.encoder.small_huffman.build__anon_35926+0x47>
 11bb49f:	45 31 c0             	xor    %r8d,%r8d
 11bb4a2:	e9 d1 00 00 00       	jmp    11bb578 <br.encoder.small_huffman.build__anon_35926+0x118>
 11bb4a7:	45 89 d1             	mov    %r10d,%r9d
 11bb4aa:	41 83 e1 78          	and    $0x78,%r9d
 11bb4ae:	45 31 c0             	xor    %r8d,%r8d
 11bb4b1:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11bb4b8:	0f 1f 84 00 00 00 00 
 11bb4bf:	00 
 11bb4c0:	42 8b 04 87          	mov    (%rdi,%r8,4),%eax
 11bb4c4:	4a 89 84 c5 90 fa ff 	mov    %rax,-0x570(%rbp,%r8,8)
 11bb4cb:	ff 
 11bb4cc:	46 88 44 05 88       	mov    %r8b,-0x78(%rbp,%r8,1)
 11bb4d1:	42 8b 44 87 04       	mov    0x4(%rdi,%r8,4),%eax
 11bb4d6:	4a 89 84 c5 98 fa ff 	mov    %rax,-0x568(%rbp,%r8,8)
 11bb4dd:	ff 
 11bb4de:	41 8d 40 01          	lea    0x1(%r8),%eax
 11bb4e2:	42 88 44 05 89       	mov    %al,-0x77(%rbp,%r8,1)
 11bb4e7:	42 8b 44 87 08       	mov    0x8(%rdi,%r8,4),%eax
 11bb4ec:	4a 89 84 c5 a0 fa ff 	mov    %rax,-0x560(%rbp,%r8,8)
 11bb4f3:	ff 
 11bb4f4:	41 8d 40 02          	lea    0x2(%r8),%eax
 11bb4f8:	42 88 44 05 8a       	mov    %al,-0x76(%rbp,%r8,1)
 11bb4fd:	42 8b 44 87 0c       	mov    0xc(%rdi,%r8,4),%eax
 11bb502:	4a 89 84 c5 a8 fa ff 	mov    %rax,-0x558(%rbp,%r8,8)
 11bb509:	ff 
 11bb50a:	41 8d 40 03          	lea    0x3(%r8),%eax
 11bb50e:	42 88 44 05 8b       	mov    %al,-0x75(%rbp,%r8,1)
 11bb513:	42 8b 44 87 10       	mov    0x10(%rdi,%r8,4),%eax
 11bb518:	4a 89 84 c5 b0 fa ff 	mov    %rax,-0x550(%rbp,%r8,8)
 11bb51f:	ff 
 11bb520:	41 8d 40 04          	lea    0x4(%r8),%eax
 11bb524:	42 88 44 05 8c       	mov    %al,-0x74(%rbp,%r8,1)
 11bb529:	42 8b 44 87 14       	mov    0x14(%rdi,%r8,4),%eax
 11bb52e:	4a 89 84 c5 b8 fa ff 	mov    %rax,-0x548(%rbp,%r8,8)
 11bb535:	ff 
 11bb536:	41 8d 40 05          	lea    0x5(%r8),%eax
 11bb53a:	42 88 44 05 8d       	mov    %al,-0x73(%rbp,%r8,1)
 11bb53f:	42 8b 44 87 18       	mov    0x18(%rdi,%r8,4),%eax
 11bb544:	4a 89 84 c5 c0 fa ff 	mov    %rax,-0x540(%rbp,%r8,8)
 11bb54b:	ff 
 11bb54c:	41 8d 40 06          	lea    0x6(%r8),%eax
 11bb550:	42 88 44 05 8e       	mov    %al,-0x72(%rbp,%r8,1)
 11bb555:	42 8b 44 87 1c       	mov    0x1c(%rdi,%r8,4),%eax
 11bb55a:	4a 89 84 c5 c8 fa ff 	mov    %rax,-0x538(%rbp,%r8,8)
 11bb561:	ff 
 11bb562:	41 8d 40 07          	lea    0x7(%r8),%eax
 11bb566:	42 88 44 05 8f       	mov    %al,-0x71(%rbp,%r8,1)
 11bb56b:	49 83 c0 08          	add    $0x8,%r8
 11bb56f:	4d 39 c8             	cmp    %r9,%r8
 11bb572:	0f 85 48 ff ff ff    	jne    11bb4c0 <br.encoder.small_huffman.build__anon_35926+0x60>
 11bb578:	48 85 c9             	test   %rcx,%rcx
 11bb57b:	74 1c                	je     11bb599 <br.encoder.small_huffman.build__anon_35926+0x139>
 11bb57d:	0f 1f 00             	nopl   (%rax)
 11bb580:	42 8b 04 87          	mov    (%rdi,%r8,4),%eax
 11bb584:	4a 89 84 c5 90 fa ff 	mov    %rax,-0x570(%rbp,%r8,8)
 11bb58b:	ff 
 11bb58c:	46 88 44 05 88       	mov    %r8b,-0x78(%rbp,%r8,1)
 11bb591:	49 ff c0             	inc    %r8
 11bb594:	48 ff c9             	dec    %rcx
 11bb597:	75 e7                	jne    11bb580 <br.encoder.small_huffman.build__anon_35926+0x120>
 11bb599:	48 8d 77 f8          	lea    -0x8(%rdi),%rsi
 11bb59d:	45 31 c9             	xor    %r9d,%r9d
 11bb5a0:	4c 89 55 c8          	mov    %r10,-0x38(%rbp)
 11bb5a4:	eb 1c                	jmp    11bb5c2 <br.encoder.small_huffman.build__anon_35926+0x162>
 11bb5a6:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 11bb5ad:	00 00 00 
 11bb5b0:	48 89 d8             	mov    %rbx,%rax
 11bb5b3:	48 f7 d0             	not    %rax
 11bb5b6:	49 01 c2             	add    %rax,%r10
 11bb5b9:	49 39 db             	cmp    %rbx,%r11
 11bb5bc:	0f 84 33 01 00 00    	je     11bb6f5 <br.encoder.small_huffman.build__anon_35926+0x295>
 11bb5c2:	4d 8d 5a ff          	lea    -0x1(%r10),%r11
 11bb5c6:	4a 8d 04 96          	lea    (%rsi,%r10,4),%rax
 11bb5ca:	45 8d 7a 06          	lea    0x6(%r10),%r15d
 11bb5ce:	45 8d 6a ff          	lea    -0x1(%r10),%r13d
 11bb5d2:	45 31 c0             	xor    %r8d,%r8d
 11bb5d5:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 11bb5dc:	00 00 00 00 
 11bb5e0:	4c 89 c3             	mov    %r8,%rbx
 11bb5e3:	45 89 fc             	mov    %r15d,%r12d
 11bb5e6:	45 89 ee             	mov    %r13d,%r14d
 11bb5e9:	4d 39 c3             	cmp    %r8,%r11
 11bb5ec:	74 32                	je     11bb620 <br.encoder.small_huffman.build__anon_35926+0x1c0>
 11bb5ee:	8b 08                	mov    (%rax),%ecx
 11bb5f0:	4c 8d 43 01          	lea    0x1(%rbx),%r8
 11bb5f4:	48 83 c0 fc          	add    $0xfffffffffffffffc,%rax
 11bb5f8:	45 8d 7c 24 ff       	lea    -0x1(%r12),%r15d
 11bb5fd:	45 8d 6e ff          	lea    -0x1(%r14),%r13d
 11bb601:	42 3b 4c 97 fc       	cmp    -0x4(%rdi,%r10,4),%ecx
 11bb606:	74 d8                	je     11bb5e0 <br.encoder.small_huffman.build__anon_35926+0x180>
 11bb608:	48 89 d8             	mov    %rbx,%rax
 11bb60b:	48 83 f0 ff          	xor    $0xffffffffffffffff,%rax
 11bb60f:	75 1b                	jne    11bb62c <br.encoder.small_huffman.build__anon_35926+0x1cc>
 11bb611:	eb 9d                	jmp    11bb5b0 <br.encoder.small_huffman.build__anon_35926+0x150>
 11bb613:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11bb61a:	84 00 00 00 00 00 
 11bb620:	4d 89 d0             	mov    %r10,%r8
 11bb623:	48 89 d8             	mov    %rbx,%rax
 11bb626:	48 83 f0 ff          	xor    $0xffffffffffffffff,%rax
 11bb62a:	74 84                	je     11bb5b0 <br.encoder.small_huffman.build__anon_35926+0x150>
 11bb62c:	49 83 f8 01          	cmp    $0x1,%r8
 11bb630:	4d 89 c7             	mov    %r8,%r15
 11bb633:	49 83 d7 00          	adc    $0x0,%r15
 11bb637:	49 83 f8 08          	cmp    $0x8,%r8
 11bb63b:	73 13                	jae    11bb650 <br.encoder.small_huffman.build__anon_35926+0x1f0>
 11bb63d:	45 31 ed             	xor    %r13d,%r13d
 11bb640:	41 83 e7 07          	and    $0x7,%r15d
 11bb644:	0f 85 8a 00 00 00    	jne    11bb6d4 <br.encoder.small_huffman.build__anon_35926+0x274>
 11bb64a:	e9 61 ff ff ff       	jmp    11bb5b0 <br.encoder.small_huffman.build__anon_35926+0x150>
 11bb64f:	90                   	nop
 11bb650:	4c 89 f8             	mov    %r15,%rax
 11bb653:	48 83 e0 f8          	and    $0xfffffffffffffff8,%rax
 11bb657:	48 8d 4d 8f          	lea    -0x71(%rbp),%rcx
 11bb65b:	4e 8d 04 09          	lea    (%rcx,%r9,1),%r8
 11bb65f:	45 31 ed             	xor    %r13d,%r13d
 11bb662:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11bb669:	1f 84 00 00 00 00 00 
 11bb670:	41 8d 4c 24 f9       	lea    -0x7(%r12),%ecx
 11bb675:	43 88 4c 28 f9       	mov    %cl,-0x7(%r8,%r13,1)
 11bb67a:	41 8d 4c 24 fa       	lea    -0x6(%r12),%ecx
 11bb67f:	43 88 4c 28 fa       	mov    %cl,-0x6(%r8,%r13,1)
 11bb684:	41 8d 4c 24 fb       	lea    -0x5(%r12),%ecx
 11bb689:	43 88 4c 28 fb       	mov    %cl,-0x5(%r8,%r13,1)
 11bb68e:	41 8d 4c 24 fc       	lea    -0x4(%r12),%ecx
 11bb693:	43 88 4c 28 fc       	mov    %cl,-0x4(%r8,%r13,1)
 11bb698:	41 8d 4c 24 fd       	lea    -0x3(%r12),%ecx
 11bb69d:	43 88 4c 28 fd       	mov    %cl,-0x3(%r8,%r13,1)
 11bb6a2:	41 8d 4c 24 fe       	lea    -0x2(%r12),%ecx
 11bb6a7:	43 88 4c 28 fe       	mov    %cl,-0x2(%r8,%r13,1)
 11bb6ac:	41 8d 4c 24 ff       	lea    -0x1(%r12),%ecx
 11bb6b1:	43 88 4c 28 ff       	mov    %cl,-0x1(%r8,%r13,1)
 11bb6b6:	47 88 24 28          	mov    %r12b,(%r8,%r13,1)
 11bb6ba:	49 83 c5 08          	add    $0x8,%r13
 11bb6be:	41 80 c4 08          	add    $0x8,%r12b
 11bb6c2:	4c 39 e8             	cmp    %r13,%rax
 11bb6c5:	75 a9                	jne    11bb670 <br.encoder.small_huffman.build__anon_35926+0x210>
 11bb6c7:	4d 01 e9             	add    %r13,%r9
 11bb6ca:	41 83 e7 07          	and    $0x7,%r15d
 11bb6ce:	0f 84 dc fe ff ff    	je     11bb5b0 <br.encoder.small_huffman.build__anon_35926+0x150>
 11bb6d4:	45 00 f5             	add    %r14b,%r13b
 11bb6d7:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 11bb6de:	00 00 
 11bb6e0:	46 88 6c 0d 88       	mov    %r13b,-0x78(%rbp,%r9,1)
 11bb6e5:	49 ff c1             	inc    %r9
 11bb6e8:	41 fe c5             	inc    %r13b
 11bb6eb:	49 ff cf             	dec    %r15
 11bb6ee:	75 f0                	jne    11bb6e0 <br.encoder.small_huffman.build__anon_35926+0x280>
 11bb6f0:	e9 bb fe ff ff       	jmp    11bb5b0 <br.encoder.small_huffman.build__anon_35926+0x150>
 11bb6f5:	4c 8b 5d c8          	mov    -0x38(%rbp),%r11
 11bb6f9:	4c 89 d9             	mov    %r11,%rcx
 11bb6fc:	49 83 fb 02          	cmp    $0x2,%r11
 11bb700:	0f 82 d1 00 00 00    	jb     11bb7d7 <br.encoder.small_huffman.build__anon_35926+0x377>
 11bb706:	31 ff                	xor    %edi,%edi
 11bb708:	4d 89 d8             	mov    %r11,%r8
 11bb70b:	4c 89 d9             	mov    %r11,%rcx
 11bb70e:	4d 89 d9             	mov    %r11,%r9
 11bb711:	eb 4c                	jmp    11bb75f <br.encoder.small_huffman.build__anon_35926+0x2ff>
 11bb713:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11bb71a:	84 00 00 00 00 00 
 11bb720:	44 89 c8             	mov    %r9d,%eax
 11bb723:	49 ff c1             	inc    %r9
 11bb726:	41 0f b6 f2          	movzbl %r10b,%esi
 11bb72a:	0f b6 c0             	movzbl %al,%eax
 11bb72d:	4c 8b 94 c5 90 fa ff 	mov    -0x570(%rbp,%rax,8),%r10
 11bb734:	ff 
 11bb735:	4c 03 94 f5 90 fa ff 	add    -0x570(%rbp,%rsi,8),%r10
 11bb73c:	ff 
 11bb73d:	4c 89 94 cd 90 fa ff 	mov    %r10,-0x570(%rbp,%rcx,8)
 11bb744:	ff 
 11bb745:	88 8c 35 8a fe ff ff 	mov    %cl,-0x176(%rbp,%rsi,1)
 11bb74c:	88 8c 05 8a fe ff ff 	mov    %cl,-0x176(%rbp,%rax,1)
 11bb753:	48 ff c1             	inc    %rcx
 11bb756:	49 ff c8             	dec    %r8
 11bb759:	49 83 f8 01          	cmp    $0x1,%r8
 11bb75d:	76 78                	jbe    11bb7d7 <br.encoder.small_huffman.build__anon_35926+0x377>
 11bb75f:	4c 39 df             	cmp    %r11,%rdi
 11bb762:	73 2c                	jae    11bb790 <br.encoder.small_huffman.build__anon_35926+0x330>
 11bb764:	44 0f b6 54 3d 88    	movzbl -0x78(%rbp,%rdi,1),%r10d
 11bb76a:	49 39 c9             	cmp    %rcx,%r9
 11bb76d:	73 31                	jae    11bb7a0 <br.encoder.small_huffman.build__anon_35926+0x340>
 11bb76f:	41 0f b6 c2          	movzbl %r10b,%eax
 11bb773:	48 8b 84 c5 90 fa ff 	mov    -0x570(%rbp,%rax,8),%rax
 11bb77a:	ff 
 11bb77b:	4a 3b 84 cd 90 fa ff 	cmp    -0x570(%rbp,%r9,8),%rax
 11bb782:	ff 
 11bb783:	76 1b                	jbe    11bb7a0 <br.encoder.small_huffman.build__anon_35926+0x340>
 11bb785:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 11bb78c:	00 00 00 00 
 11bb790:	45 89 ca             	mov    %r9d,%r10d
 11bb793:	49 ff c1             	inc    %r9
 11bb796:	4c 39 df             	cmp    %r11,%rdi
 11bb799:	73 85                	jae    11bb720 <br.encoder.small_huffman.build__anon_35926+0x2c0>
 11bb79b:	eb 0f                	jmp    11bb7ac <br.encoder.small_huffman.build__anon_35926+0x34c>
 11bb79d:	0f 1f 00             	nopl   (%rax)
 11bb7a0:	48 ff c7             	inc    %rdi
 11bb7a3:	4c 39 df             	cmp    %r11,%rdi
 11bb7a6:	0f 83 74 ff ff ff    	jae    11bb720 <br.encoder.small_huffman.build__anon_35926+0x2c0>
 11bb7ac:	0f b6 44 3d 88       	movzbl -0x78(%rbp,%rdi,1),%eax
 11bb7b1:	49 39 c9             	cmp    %rcx,%r9
 11bb7b4:	73 19                	jae    11bb7cf <br.encoder.small_huffman.build__anon_35926+0x36f>
 11bb7b6:	0f b6 f0             	movzbl %al,%esi
 11bb7b9:	48 8b b4 f5 90 fa ff 	mov    -0x570(%rbp,%rsi,8),%rsi
 11bb7c0:	ff 
 11bb7c1:	4a 3b b4 cd 90 fa ff 	cmp    -0x570(%rbp,%r9,8),%rsi
 11bb7c8:	ff 
 11bb7c9:	0f 87 51 ff ff ff    	ja     11bb720 <br.encoder.small_huffman.build__anon_35926+0x2c0>
 11bb7cf:	48 ff c7             	inc    %rdi
 11bb7d2:	e9 4f ff ff ff       	jmp    11bb726 <br.encoder.small_huffman.build__anon_35926+0x2c6>
 11bb7d7:	48 89 c8             	mov    %rcx,%rax
 11bb7da:	c6 84 0d 08 ff ff ff 	movb   $0x0,-0xf8(%rbp,%rcx,1)
 11bb7e1:	00 
 11bb7e2:	48 ff c8             	dec    %rax
 11bb7e5:	74 39                	je     11bb820 <br.encoder.small_huffman.build__anon_35926+0x3c0>
 11bb7e7:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 11bb7ee:	00 00 
 11bb7f0:	0f b6 84 0d 88 fe ff 	movzbl -0x178(%rbp,%rcx,1),%eax
 11bb7f7:	ff 
 11bb7f8:	0f b6 84 05 09 ff ff 	movzbl -0xf7(%rbp,%rax,1),%eax
 11bb7ff:	ff 
 11bb800:	c0 e0 03             	shl    $0x3,%al
 11bb803:	04 08                	add    $0x8,%al
 11bb805:	c0 f8 03             	sar    $0x3,%al
 11bb808:	0f 88 d9 00 00 00    	js     11bb8e7 <br.encoder.small_huffman.build__anon_35926+0x487>
 11bb80e:	24 1f                	and    $0x1f,%al
 11bb810:	88 84 0d 07 ff ff ff 	mov    %al,-0xf9(%rbp,%rcx,1)
 11bb817:	48 ff c9             	dec    %rcx
 11bb81a:	48 83 f9 01          	cmp    $0x1,%rcx
 11bb81e:	75 d0                	jne    11bb7f0 <br.encoder.small_huffman.build__anon_35926+0x390>
 11bb820:	44 89 d9             	mov    %r11d,%ecx
 11bb823:	83 e1 07             	and    $0x7,%ecx
 11bb826:	48 83 7d d0 07       	cmpq   $0x7,-0x30(%rbp)
 11bb82b:	73 07                	jae    11bb834 <br.encoder.small_huffman.build__anon_35926+0x3d4>
 11bb82d:	31 ff                	xor    %edi,%edi
 11bb82f:	e9 84 00 00 00       	jmp    11bb8b8 <br.encoder.small_huffman.build__anon_35926+0x458>
 11bb834:	41 83 e3 78          	and    $0x78,%r11d
 11bb838:	31 ff                	xor    %edi,%edi
 11bb83a:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 11bb840:	0f b6 84 3d 09 ff ff 	movzbl -0xf7(%rbp,%rdi,1),%eax
 11bb847:	ff 
 11bb848:	24 0f                	and    $0xf,%al
 11bb84a:	88 04 3a             	mov    %al,(%rdx,%rdi,1)
 11bb84d:	0f b6 84 3d 0a ff ff 	movzbl -0xf6(%rbp,%rdi,1),%eax
 11bb854:	ff 
 11bb855:	24 0f                	and    $0xf,%al
 11bb857:	88 44 3a 01          	mov    %al,0x1(%rdx,%rdi,1)
 11bb85b:	0f b6 84 3d 0b ff ff 	movzbl -0xf5(%rbp,%rdi,1),%eax
 11bb862:	ff 
 11bb863:	24 0f                	and    $0xf,%al
 11bb865:	88 44 3a 02          	mov    %al,0x2(%rdx,%rdi,1)
 11bb869:	0f b6 84 3d 0c ff ff 	movzbl -0xf4(%rbp,%rdi,1),%eax
 11bb870:	ff 
 11bb871:	24 0f                	and    $0xf,%al
 11bb873:	88 44 3a 03          	mov    %al,0x3(%rdx,%rdi,1)
 11bb877:	0f b6 84 3d 0d ff ff 	movzbl -0xf3(%rbp,%rdi,1),%eax
 11bb87e:	ff 
 11bb87f:	24 0f                	and    $0xf,%al
 11bb881:	88 44 3a 04          	mov    %al,0x4(%rdx,%rdi,1)
 11bb885:	0f b6 84 3d 0e ff ff 	movzbl -0xf2(%rbp,%rdi,1),%eax
 11bb88c:	ff 
 11bb88d:	24 0f                	and    $0xf,%al
 11bb88f:	88 44 3a 05          	mov    %al,0x5(%rdx,%rdi,1)
 11bb893:	0f b6 84 3d 0f ff ff 	movzbl -0xf1(%rbp,%rdi,1),%eax
 11bb89a:	ff 
 11bb89b:	24 0f                	and    $0xf,%al
 11bb89d:	88 44 3a 06          	mov    %al,0x6(%rdx,%rdi,1)
 11bb8a1:	0f b6 84 3d 10 ff ff 	movzbl -0xf0(%rbp,%rdi,1),%eax
 11bb8a8:	ff 
 11bb8a9:	24 0f                	and    $0xf,%al
 11bb8ab:	88 44 3a 07          	mov    %al,0x7(%rdx,%rdi,1)
 11bb8af:	48 83 c7 08          	add    $0x8,%rdi
 11bb8b3:	49 39 fb             	cmp    %rdi,%r11
 11bb8b6:	75 88                	jne    11bb840 <br.encoder.small_huffman.build__anon_35926+0x3e0>
 11bb8b8:	b0 01                	mov    $0x1,%al
 11bb8ba:	48 85 c9             	test   %rcx,%rcx
 11bb8bd:	74 2a                	je     11bb8e9 <br.encoder.small_huffman.build__anon_35926+0x489>
 11bb8bf:	48 8d 34 2f          	lea    (%rdi,%rbp,1),%rsi
 11bb8c3:	48 81 c6 09 ff ff ff 	add    $0xffffffffffffff09,%rsi
 11bb8ca:	48 01 fa             	add    %rdi,%rdx
 11bb8cd:	31 ff                	xor    %edi,%edi
 11bb8cf:	90                   	nop
 11bb8d0:	44 0f b6 04 3e       	movzbl (%rsi,%rdi,1),%r8d
 11bb8d5:	41 80 e0 0f          	and    $0xf,%r8b
 11bb8d9:	44 88 04 3a          	mov    %r8b,(%rdx,%rdi,1)
 11bb8dd:	48 ff c7             	inc    %rdi
 11bb8e0:	48 39 f9             	cmp    %rdi,%rcx
 11bb8e3:	75 eb                	jne    11bb8d0 <br.encoder.small_huffman.build__anon_35926+0x470>
 11bb8e5:	eb 02                	jmp    11bb8e9 <br.encoder.small_huffman.build__anon_35926+0x489>
 11bb8e7:	31 c0                	xor    %eax,%eax
 11bb8e9:	48 81 c4 c8 04 00 00 	add    $0x4c8,%rsp
 11bb8f0:	5b                   	pop    %rbx
 11bb8f1:	41 5c                	pop    %r12
 11bb8f3:	41 5d                	pop    %r13
 11bb8f5:	41 5e                	pop    %r14
 11bb8f7:	41 5f                	pop    %r15
 11bb8f9:	5d                   	pop    %rbp
 11bb8fa:	c3                   	ret    

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
