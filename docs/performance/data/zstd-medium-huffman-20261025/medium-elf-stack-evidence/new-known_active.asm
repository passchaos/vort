
/home/passchaos/project-z/vort-zstd-duplicate-profile/.zig-cache/o/e896d85b31c33819f34a4488826cd334/vort-zstd-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000111c260 <huffman.treeCodeLengthsKnownActive__anon_38967>:
 111c260:	test   %rcx,%rcx
 111c263:	je     111c34a <huffman.treeCodeLengthsKnownActive__anon_38967+0xea>
 111c269:	push   %rbp
 111c26a:	mov    %rsp,%rbp
 111c26d:	push   %r15
 111c26f:	push   %r14
 111c271:	push   %rbx
 111c272:	sub    $0x6c8,%rsp
 111c279:	cmp    $0x1,%rcx
 111c27d:	jne    111c385 <huffman.treeCodeLengthsKnownActive__anon_38967+0x125>
 111c283:	vxorps %xmm0,%xmm0,%xmm0
 111c287:	vmovups %ymm0,-0x400(%rbp)
 111c28f:	vmovups %ymm0,-0x420(%rbp)
 111c297:	vmovups %ymm0,-0x440(%rbp)
 111c29f:	vmovups %ymm0,-0x460(%rbp)
 111c2a7:	vmovups %ymm0,-0x480(%rbp)
 111c2af:	vmovups %ymm0,-0x4a0(%rbp)
 111c2b7:	vmovups %ymm0,-0x4c0(%rbp)
 111c2bf:	vmovups %ymm0,-0x4e0(%rbp)
 111c2c7:	movzbl (%rdx),%eax
 111c2ca:	movb   $0x1,-0x4e0(%rbp,%rax,1)
 111c2d2:	vmovups -0x400(%rbp),%ymm0
 111c2da:	vmovups %ymm0,0xe0(%rdi)
 111c2e2:	vmovups -0x420(%rbp),%ymm0
 111c2ea:	vmovups %ymm0,0xc0(%rdi)
 111c2f2:	vmovups -0x440(%rbp),%ymm0
 111c2fa:	vmovups %ymm0,0xa0(%rdi)
 111c302:	vmovups -0x460(%rbp),%ymm0
 111c30a:	vmovups %ymm0,0x80(%rdi)
 111c312:	vmovups -0x4e0(%rbp),%ymm0
 111c31a:	vmovups -0x4c0(%rbp),%ymm1
 111c322:	vmovups -0x4a0(%rbp),%ymm2
 111c32a:	vmovups -0x480(%rbp),%ymm3
 111c332:	vmovups %ymm3,0x60(%rdi)
 111c337:	vmovups %ymm2,0x40(%rdi)
 111c33c:	vmovups %ymm1,0x20(%rdi)
 111c341:	vmovups %ymm0,(%rdi)
 111c345:	jmp    111cce8 <huffman.treeCodeLengthsKnownActive__anon_38967+0xa88>
 111c34a:	vxorps %xmm0,%xmm0,%xmm0
 111c34e:	vmovups %ymm0,0xe0(%rdi)
 111c356:	vmovups %ymm0,0xc0(%rdi)
 111c35e:	vmovups %ymm0,0xa0(%rdi)
 111c366:	vmovups %ymm0,0x80(%rdi)
 111c36e:	vmovups %ymm0,0x60(%rdi)
 111c373:	vmovups %ymm0,0x40(%rdi)
 111c378:	vmovups %ymm0,0x20(%rdi)
 111c37d:	vmovups %ymm0,(%rdi)
 111c381:	vzeroupper 
 111c384:	ret    
 111c385:	cmp    $0x20,%rcx
 111c389:	ja     111c3a6 <huffman.treeCodeLengthsKnownActive__anon_38967+0x146>
 111c38b:	lea    -0x1(%rcx),%rbx
 111c38f:	mov    %ecx,%eax
 111c391:	and    $0x7,%eax
 111c394:	cmp    $0x7,%rbx
 111c398:	jae    111c799 <huffman.treeCodeLengthsKnownActive__anon_38967+0x539>
 111c39e:	xor    %r8d,%r8d
 111c3a1:	jmp    111c830 <huffman.treeCodeLengthsKnownActive__anon_38967+0x5d0>
 111c3a6:	cmp    $0x40,%rcx
 111c3aa:	ja     111c89c <huffman.treeCodeLengthsKnownActive__anon_38967+0x63c>
 111c3b0:	mov    %ecx,%eax
 111c3b2:	and    $0x7,%eax
 111c3b5:	mov    %ecx,%r9d
 111c3b8:	and    $0x78,%r9d
 111c3bc:	xor    %r8d,%r8d
 111c3bf:	nop
 111c3c0:	movzbl (%rdx,%r8,1),%r10d
 111c3c5:	mov    %r10w,-0x98(%rbp,%r8,2)
 111c3ce:	movzbl 0x1(%rdx,%r8,1),%r10d
 111c3d4:	mov    %r10w,-0x96(%rbp,%r8,2)
 111c3dd:	movzbl 0x2(%rdx,%r8,1),%r10d
 111c3e3:	mov    %r10w,-0x94(%rbp,%r8,2)
 111c3ec:	movzbl 0x3(%rdx,%r8,1),%r10d
 111c3f2:	mov    %r10w,-0x92(%rbp,%r8,2)
 111c3fb:	movzbl 0x4(%rdx,%r8,1),%r10d
 111c401:	mov    %r10w,-0x90(%rbp,%r8,2)
 111c40a:	movzbl 0x5(%rdx,%r8,1),%r10d
 111c410:	mov    %r10w,-0x8e(%rbp,%r8,2)
 111c419:	movzbl 0x6(%rdx,%r8,1),%r10d
 111c41f:	mov    %r10w,-0x8c(%rbp,%r8,2)
 111c428:	movzbl 0x7(%rdx,%r8,1),%r10d
 111c42e:	mov    %r10w,-0x8a(%rbp,%r8,2)
 111c437:	add    $0x8,%r8
 111c43b:	cmp    %r8,%r9
 111c43e:	jne    111c3c0 <huffman.treeCodeLengthsKnownActive__anon_38967+0x160>
 111c440:	test   %rax,%rax
 111c443:	je     111c466 <huffman.treeCodeLengthsKnownActive__anon_38967+0x206>
 111c445:	data16 cs nopw 0x0(%rax,%rax,1)
 111c450:	movzbl (%rdx,%r8,1),%r9d
 111c455:	mov    %r9w,-0x98(%rbp,%r8,2)
 111c45e:	inc    %r8
 111c461:	dec    %rax
 111c464:	jne    111c450 <huffman.treeCodeLengthsKnownActive__anon_38967+0x1f0>
 111c466:	vxorps %xmm0,%xmm0,%xmm0
 111c46a:	vmovups %ymm0,-0x100(%rbp)
 111c472:	vmovups %ymm0,-0x120(%rbp)
 111c47a:	vmovups %ymm0,-0x140(%rbp)
 111c482:	vmovups %ymm0,-0x160(%rbp)
 111c48a:	vmovups %ymm0,-0x180(%rbp)
 111c492:	vmovups %ymm0,-0x1a0(%rbp)
 111c49a:	vmovups %ymm0,-0x1c0(%rbp)
 111c4a2:	vmovups %ymm0,-0x1e0(%rbp)
 111c4aa:	mov    %ecx,%eax
 111c4ac:	and    $0x7,%eax
 111c4af:	mov    %ecx,%r8d
 111c4b2:	and    $0x78,%r8d
 111c4b6:	xor    %edx,%edx
 111c4b8:	nopl   0x0(%rax,%rax,1)
 111c4c0:	movzwl -0x98(%rbp,%rdx,2),%r9d
 111c4c9:	mov    (%rsi,%r9,4),%r9d
 111c4cd:	mov    %r9d,-0x1e0(%rbp,%rdx,4)
 111c4d5:	movzwl -0x96(%rbp,%rdx,2),%r9d
 111c4de:	mov    (%rsi,%r9,4),%r9d
 111c4e2:	mov    %r9d,-0x1dc(%rbp,%rdx,4)
 111c4ea:	movzwl -0x94(%rbp,%rdx,2),%r9d
 111c4f3:	mov    (%rsi,%r9,4),%r9d
 111c4f7:	mov    %r9d,-0x1d8(%rbp,%rdx,4)
 111c4ff:	movzwl -0x92(%rbp,%rdx,2),%r9d
 111c508:	mov    (%rsi,%r9,4),%r9d
 111c50c:	mov    %r9d,-0x1d4(%rbp,%rdx,4)
 111c514:	movzwl -0x90(%rbp,%rdx,2),%r9d
 111c51d:	mov    (%rsi,%r9,4),%r9d
 111c521:	mov    %r9d,-0x1d0(%rbp,%rdx,4)
 111c529:	movzwl -0x8e(%rbp,%rdx,2),%r9d
 111c532:	mov    (%rsi,%r9,4),%r9d
 111c536:	mov    %r9d,-0x1cc(%rbp,%rdx,4)
 111c53e:	movzwl -0x8c(%rbp,%rdx,2),%r9d
 111c547:	mov    (%rsi,%r9,4),%r9d
 111c54b:	mov    %r9d,-0x1c8(%rbp,%rdx,4)
 111c553:	movzwl -0x8a(%rbp,%rdx,2),%r9d
 111c55c:	mov    (%rsi,%r9,4),%r9d
 111c560:	mov    %r9d,-0x1c4(%rbp,%rdx,4)
 111c568:	add    $0x8,%rdx
 111c56c:	cmp    %rdx,%r8
 111c56f:	jne    111c4c0 <huffman.treeCodeLengthsKnownActive__anon_38967+0x260>
 111c575:	mov    %rdi,%rbx
 111c578:	test   %rax,%rax
 111c57b:	je     111c59a <huffman.treeCodeLengthsKnownActive__anon_38967+0x33a>
 111c57d:	nopl   (%rax)
 111c580:	movzwl -0x98(%rbp,%rdx,2),%edi
 111c588:	mov    (%rsi,%rdi,4),%edi
 111c58b:	mov    %edi,-0x1e0(%rbp,%rdx,4)
 111c592:	inc    %rdx
 111c595:	dec    %rax
 111c598:	jne    111c580 <huffman.treeCodeLengthsKnownActive__anon_38967+0x320>
 111c59a:	lea    -0xd8(%rbp),%rdi
 111c5a1:	lea    -0x1e0(%rbp),%rsi
 111c5a8:	mov    %rcx,%rdx
 111c5ab:	mov    %rcx,%r14
 111c5ae:	vzeroupper 
 111c5b1:	call   111cd00 <huffman.packageMergeCodeLengths__anon_39023>
 111c5b6:	mov    %r14,%rdx
 111c5b9:	vxorps %xmm0,%xmm0,%xmm0
 111c5bd:	vmovups %ymm0,-0x300(%rbp)
 111c5c5:	vmovups %ymm0,-0x320(%rbp)
 111c5cd:	vmovups %ymm0,-0x340(%rbp)
 111c5d5:	vmovups %ymm0,-0x360(%rbp)
 111c5dd:	vmovups %ymm0,-0x380(%rbp)
 111c5e5:	vmovups %ymm0,-0x3a0(%rbp)
 111c5ed:	vmovups %ymm0,-0x3c0(%rbp)
 111c5f5:	vmovups %ymm0,-0x3e0(%rbp)
 111c5fd:	mov    %edx,%eax
 111c5ff:	and    $0x7,%eax
 111c602:	and    $0x78,%edx
 111c605:	xor    %ecx,%ecx
 111c607:	nopw   0x0(%rax,%rax,1)
 111c610:	movzwl -0x98(%rbp,%rcx,2),%esi
 111c618:	movzbl -0xd8(%rbp,%rcx,1),%edi
 111c620:	movzbl -0xd7(%rbp,%rcx,1),%r8d
 111c629:	and    $0xf,%dil
 111c62d:	mov    %dil,-0x3e0(%rbp,%rsi,1)
 111c635:	movzwl -0x96(%rbp,%rcx,2),%esi
 111c63d:	and    $0xf,%r8b
 111c641:	mov    %r8b,-0x3e0(%rbp,%rsi,1)
 111c649:	movzwl -0x94(%rbp,%rcx,2),%esi
 111c651:	movzbl -0xd6(%rbp,%rcx,1),%edi
 111c659:	and    $0xf,%dil
 111c65d:	mov    %dil,-0x3e0(%rbp,%rsi,1)
 111c665:	movzwl -0x92(%rbp,%rcx,2),%esi
 111c66d:	movzbl -0xd5(%rbp,%rcx,1),%edi
 111c675:	and    $0xf,%dil
 111c679:	mov    %dil,-0x3e0(%rbp,%rsi,1)
 111c681:	movzwl -0x90(%rbp,%rcx,2),%esi
 111c689:	movzbl -0xd4(%rbp,%rcx,1),%edi
 111c691:	and    $0xf,%dil
 111c695:	mov    %dil,-0x3e0(%rbp,%rsi,1)
 111c69d:	movzwl -0x8e(%rbp,%rcx,2),%esi
 111c6a5:	movzbl -0xd3(%rbp,%rcx,1),%edi
 111c6ad:	and    $0xf,%dil
 111c6b1:	mov    %dil,-0x3e0(%rbp,%rsi,1)
 111c6b9:	movzwl -0x8c(%rbp,%rcx,2),%esi
 111c6c1:	movzbl -0xd2(%rbp,%rcx,1),%edi
 111c6c9:	and    $0xf,%dil
 111c6cd:	mov    %dil,-0x3e0(%rbp,%rsi,1)
 111c6d5:	movzwl -0x8a(%rbp,%rcx,2),%esi
 111c6dd:	movzbl -0xd1(%rbp,%rcx,1),%edi
 111c6e5:	and    $0xf,%dil
 111c6e9:	mov    %dil,-0x3e0(%rbp,%rsi,1)
 111c6f1:	add    $0x8,%rcx
 111c6f5:	cmp    %rcx,%rdx
 111c6f8:	jne    111c610 <huffman.treeCodeLengthsKnownActive__anon_38967+0x3b0>
 111c6fe:	test   %rax,%rax
 111c701:	je     111c734 <huffman.treeCodeLengthsKnownActive__anon_38967+0x4d4>
 111c703:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 111c710:	movzwl -0x98(%rbp,%rcx,2),%edx
 111c718:	movzbl -0xd8(%rbp,%rcx,1),%esi
 111c720:	and    $0xf,%sil
 111c724:	mov    %sil,-0x3e0(%rbp,%rdx,1)
 111c72c:	inc    %rcx
 111c72f:	dec    %rax
 111c732:	jne    111c710 <huffman.treeCodeLengthsKnownActive__anon_38967+0x4b0>
 111c734:	vmovups -0x300(%rbp),%ymm0
 111c73c:	vmovups %ymm0,0xe0(%rbx)
 111c744:	vmovups -0x320(%rbp),%ymm0
 111c74c:	vmovups %ymm0,0xc0(%rbx)
 111c754:	vmovups -0x340(%rbp),%ymm0
 111c75c:	vmovups %ymm0,0xa0(%rbx)
 111c764:	vmovups -0x360(%rbp),%ymm0
 111c76c:	vmovups %ymm0,0x80(%rbx)
 111c774:	vmovups -0x3e0(%rbp),%ymm0
 111c77c:	vmovups -0x3c0(%rbp),%ymm1
 111c784:	vmovups -0x3a0(%rbp),%ymm2
 111c78c:	vmovups -0x380(%rbp),%ymm3
 111c794:	jmp    111ccd5 <huffman.treeCodeLengthsKnownActive__anon_38967+0xa75>
 111c799:	mov    %ecx,%r9d
 111c79c:	and    $0x38,%r9d
 111c7a0:	xor    %r8d,%r8d
 111c7a3:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 111c7b0:	movzbl (%rdx,%r8,1),%r10d
 111c7b5:	mov    %r10w,-0x98(%rbp,%r8,2)
 111c7be:	movzbl 0x1(%rdx,%r8,1),%r10d
 111c7c4:	mov    %r10w,-0x96(%rbp,%r8,2)
 111c7cd:	movzbl 0x2(%rdx,%r8,1),%r10d
 111c7d3:	mov    %r10w,-0x94(%rbp,%r8,2)
 111c7dc:	movzbl 0x3(%rdx,%r8,1),%r10d
 111c7e2:	mov    %r10w,-0x92(%rbp,%r8,2)
 111c7eb:	movzbl 0x4(%rdx,%r8,1),%r10d
 111c7f1:	mov    %r10w,-0x90(%rbp,%r8,2)
 111c7fa:	movzbl 0x5(%rdx,%r8,1),%r10d
 111c800:	mov    %r10w,-0x8e(%rbp,%r8,2)
 111c809:	movzbl 0x6(%rdx,%r8,1),%r10d
 111c80f:	mov    %r10w,-0x8c(%rbp,%r8,2)
 111c818:	movzbl 0x7(%rdx,%r8,1),%r10d
 111c81e:	mov    %r10w,-0x8a(%rbp,%r8,2)
 111c827:	add    $0x8,%r8
 111c82b:	cmp    %r8,%r9
 111c82e:	jne    111c7b0 <huffman.treeCodeLengthsKnownActive__anon_38967+0x550>
 111c830:	test   %rax,%rax
 111c833:	je     111c862 <huffman.treeCodeLengthsKnownActive__anon_38967+0x602>
 111c835:	lea    -0x98(,%r8,2),%r9
 111c83d:	add    %rbp,%r9
 111c840:	add    %r8,%rdx
 111c843:	xor    %r8d,%r8d
 111c846:	cs nopw 0x0(%rax,%rax,1)
 111c850:	movzbl (%rdx,%r8,1),%r10d
 111c855:	mov    %r10w,(%r9,%r8,2)
 111c85a:	inc    %r8
 111c85d:	cmp    %r8,%rax
 111c860:	jne    111c850 <huffman.treeCodeLengthsKnownActive__anon_38967+0x5f0>
 111c862:	vxorps %xmm0,%xmm0,%xmm0
 111c866:	vmovups %ymm0,-0x180(%rbp)
 111c86e:	vmovups %ymm0,-0x1a0(%rbp)
 111c876:	vmovups %ymm0,-0x1c0(%rbp)
 111c87e:	vmovups %ymm0,-0x1e0(%rbp)
 111c886:	mov    %ecx,%eax
 111c888:	and    $0x7,%eax
 111c88b:	cmp    $0x7,%rbx
 111c88f:	jae    111c91a <huffman.treeCodeLengthsKnownActive__anon_38967+0x6ba>
 111c895:	xor    %edx,%edx
 111c897:	jmp    111c9e5 <huffman.treeCodeLengthsKnownActive__anon_38967+0x785>
 111c89c:	mov    %rdi,%rbx
 111c89f:	cmp    $0x7f,%rcx
 111c8a3:	ja     111cc66 <huffman.treeCodeLengthsKnownActive__anon_38967+0xa06>
 111c8a9:	lea    -0x5e0(%rbp),%rdi
 111c8b0:	call   1141640 <huffman.treeCodeLengthsMediumKnownActive__anon_38997>
 111c8b5:	vmovups -0x500(%rbp),%ymm0
 111c8bd:	vmovups %ymm0,0xe0(%rbx)
 111c8c5:	vmovups -0x520(%rbp),%ymm0
 111c8cd:	vmovups %ymm0,0xc0(%rbx)
 111c8d5:	vmovups -0x540(%rbp),%ymm0
 111c8dd:	vmovups %ymm0,0xa0(%rbx)
 111c8e5:	vmovups -0x560(%rbp),%ymm0
 111c8ed:	vmovups %ymm0,0x80(%rbx)
 111c8f5:	vmovups -0x5e0(%rbp),%ymm0
 111c8fd:	vmovups -0x5c0(%rbp),%ymm1
 111c905:	vmovups -0x5a0(%rbp),%ymm2
 111c90d:	vmovups -0x580(%rbp),%ymm3
 111c915:	jmp    111ccd5 <huffman.treeCodeLengthsKnownActive__anon_38967+0xa75>
 111c91a:	mov    %ecx,%r8d
 111c91d:	and    $0x38,%r8d
 111c921:	xor    %edx,%edx
 111c923:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 111c930:	movzwl -0x98(%rbp,%rdx,2),%r9d
 111c939:	mov    (%rsi,%r9,4),%r9d
 111c93d:	mov    %r9d,-0x1e0(%rbp,%rdx,4)
 111c945:	movzwl -0x96(%rbp,%rdx,2),%r9d
 111c94e:	mov    (%rsi,%r9,4),%r9d
 111c952:	mov    %r9d,-0x1dc(%rbp,%rdx,4)
 111c95a:	movzwl -0x94(%rbp,%rdx,2),%r9d
 111c963:	mov    (%rsi,%r9,4),%r9d
 111c967:	mov    %r9d,-0x1d8(%rbp,%rdx,4)
 111c96f:	movzwl -0x92(%rbp,%rdx,2),%r9d
 111c978:	mov    (%rsi,%r9,4),%r9d
 111c97c:	mov    %r9d,-0x1d4(%rbp,%rdx,4)
 111c984:	movzwl -0x90(%rbp,%rdx,2),%r9d
 111c98d:	mov    (%rsi,%r9,4),%r9d
 111c991:	mov    %r9d,-0x1d0(%rbp,%rdx,4)
 111c999:	movzwl -0x8e(%rbp,%rdx,2),%r9d
 111c9a2:	mov    (%rsi,%r9,4),%r9d
 111c9a6:	mov    %r9d,-0x1cc(%rbp,%rdx,4)
 111c9ae:	movzwl -0x8c(%rbp,%rdx,2),%r9d
 111c9b7:	mov    (%rsi,%r9,4),%r9d
 111c9bb:	mov    %r9d,-0x1c8(%rbp,%rdx,4)
 111c9c3:	movzwl -0x8a(%rbp,%rdx,2),%r9d
 111c9cc:	mov    (%rsi,%r9,4),%r9d
 111c9d0:	mov    %r9d,-0x1c4(%rbp,%rdx,4)
 111c9d8:	add    $0x8,%rdx
 111c9dc:	cmp    %rdx,%r8
 111c9df:	jne    111c930 <huffman.treeCodeLengthsKnownActive__anon_38967+0x6d0>
 111c9e5:	mov    %rdi,%r14
 111c9e8:	test   %rax,%rax
 111c9eb:	je     111ca25 <huffman.treeCodeLengthsKnownActive__anon_38967+0x7c5>
 111c9ed:	lea    -0x1e0(,%rdx,4),%rdi
 111c9f5:	add    %rbp,%rdi
 111c9f8:	lea    -0x98(,%rdx,2),%rdx
 111ca00:	add    %rbp,%rdx
 111ca03:	xor    %r8d,%r8d
 111ca06:	cs nopw 0x0(%rax,%rax,1)
 111ca10:	movzwl (%rdx,%r8,2),%r9d
 111ca15:	mov    (%rsi,%r9,4),%r9d
 111ca19:	mov    %r9d,(%rdi,%r8,4)
 111ca1d:	inc    %r8
 111ca20:	cmp    %r8,%rax
 111ca23:	jne    111ca10 <huffman.treeCodeLengthsKnownActive__anon_38967+0x7b0>
 111ca25:	lea    -0xd8(%rbp),%rdi
 111ca2c:	lea    -0x1e0(%rbp),%rsi
 111ca33:	mov    %rcx,%rdx
 111ca36:	mov    %rcx,%r15
 111ca39:	vzeroupper 
 111ca3c:	call   1130000 <huffman.packageMergeCodeLengths__anon_39220>
 111ca41:	mov    %r15,%rdx
 111ca44:	vxorps %xmm0,%xmm0,%xmm0
 111ca48:	vmovups %ymm0,-0x200(%rbp)
 111ca50:	vmovups %ymm0,-0x220(%rbp)
 111ca58:	vmovups %ymm0,-0x240(%rbp)
 111ca60:	vmovups %ymm0,-0x260(%rbp)
 111ca68:	vmovups %ymm0,-0x280(%rbp)
 111ca70:	vmovups %ymm0,-0x2a0(%rbp)
 111ca78:	vmovups %ymm0,-0x2c0(%rbp)
 111ca80:	vmovups %ymm0,-0x2e0(%rbp)
 111ca88:	mov    %edx,%eax
 111ca8a:	and    $0x7,%eax
 111ca8d:	cmp    $0x7,%rbx
 111ca91:	jae    111ca9d <huffman.treeCodeLengthsKnownActive__anon_38967+0x83d>
 111ca93:	xor    %esi,%esi
 111ca95:	mov    %r14,%rcx
 111ca98:	jmp    111cba5 <huffman.treeCodeLengthsKnownActive__anon_38967+0x945>
 111ca9d:	and    $0x38,%edx
 111caa0:	xor    %esi,%esi
 111caa2:	mov    %r14,%rcx
 111caa5:	data16 cs nopw 0x0(%rax,%rax,1)
 111cab0:	movzwl -0x98(%rbp,%rsi,2),%edi
 111cab8:	movzbl -0xd8(%rbp,%rsi,1),%r8d
 111cac1:	movzbl -0xd7(%rbp,%rsi,1),%r9d
 111caca:	and    $0xf,%r8b
 111cace:	mov    %r8b,-0x2e0(%rbp,%rdi,1)
 111cad6:	movzwl -0x96(%rbp,%rsi,2),%edi
 111cade:	and    $0xf,%r9b
 111cae2:	mov    %r9b,-0x2e0(%rbp,%rdi,1)
 111caea:	movzwl -0x94(%rbp,%rsi,2),%edi
 111caf2:	movzbl -0xd6(%rbp,%rsi,1),%r8d
 111cafb:	and    $0xf,%r8b
 111caff:	mov    %r8b,-0x2e0(%rbp,%rdi,1)
 111cb07:	movzwl -0x92(%rbp,%rsi,2),%edi
 111cb0f:	movzbl -0xd5(%rbp,%rsi,1),%r8d
 111cb18:	and    $0xf,%r8b
 111cb1c:	mov    %r8b,-0x2e0(%rbp,%rdi,1)
 111cb24:	movzwl -0x90(%rbp,%rsi,2),%edi
 111cb2c:	movzbl -0xd4(%rbp,%rsi,1),%r8d
 111cb35:	and    $0xf,%r8b
 111cb39:	mov    %r8b,-0x2e0(%rbp,%rdi,1)
 111cb41:	movzwl -0x8e(%rbp,%rsi,2),%edi
 111cb49:	movzbl -0xd3(%rbp,%rsi,1),%r8d
 111cb52:	and    $0xf,%r8b
 111cb56:	mov    %r8b,-0x2e0(%rbp,%rdi,1)
 111cb5e:	movzwl -0x8c(%rbp,%rsi,2),%edi
 111cb66:	movzbl -0xd2(%rbp,%rsi,1),%r8d
 111cb6f:	and    $0xf,%r8b
 111cb73:	mov    %r8b,-0x2e0(%rbp,%rdi,1)
 111cb7b:	movzwl -0x8a(%rbp,%rsi,2),%edi
 111cb83:	movzbl -0xd1(%rbp,%rsi,1),%r8d
 111cb8c:	and    $0xf,%r8b
 111cb90:	mov    %r8b,-0x2e0(%rbp,%rdi,1)
 111cb98:	add    $0x8,%rsi
 111cb9c:	cmp    %rsi,%rdx
 111cb9f:	jne    111cab0 <huffman.treeCodeLengthsKnownActive__anon_38967+0x850>
 111cba5:	test   %rax,%rax
 111cba8:	je     111cbee <huffman.treeCodeLengthsKnownActive__anon_38967+0x98e>
 111cbaa:	lea    (%rsi,%rbp,1),%rdx
 111cbae:	add    $0xffffffffffffff28,%rdx
 111cbb5:	lea    -0x98(,%rsi,2),%rsi
 111cbbd:	add    %rbp,%rsi
 111cbc0:	xor    %edi,%edi
 111cbc2:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 111cbd0:	movzwl (%rsi,%rdi,2),%r8d
 111cbd5:	movzbl (%rdx,%rdi,1),%r9d
 111cbda:	and    $0xf,%r9b
 111cbde:	mov    %r9b,-0x2e0(%rbp,%r8,1)
 111cbe6:	inc    %rdi
 111cbe9:	cmp    %rdi,%rax
 111cbec:	jne    111cbd0 <huffman.treeCodeLengthsKnownActive__anon_38967+0x970>
 111cbee:	vmovups -0x200(%rbp),%ymm0
 111cbf6:	vmovups %ymm0,0xe0(%rcx)
 111cbfe:	vmovups -0x220(%rbp),%ymm0
 111cc06:	vmovups %ymm0,0xc0(%rcx)
 111cc0e:	vmovups -0x240(%rbp),%ymm0
 111cc16:	vmovups %ymm0,0xa0(%rcx)
 111cc1e:	vmovups -0x260(%rbp),%ymm0
 111cc26:	vmovups %ymm0,0x80(%rcx)
 111cc2e:	vmovups -0x2e0(%rbp),%ymm0
 111cc36:	vmovups -0x2c0(%rbp),%ymm1
 111cc3e:	vmovups -0x2a0(%rbp),%ymm2
 111cc46:	vmovups -0x280(%rbp),%ymm3
 111cc4e:	vmovups %ymm3,0x60(%rcx)
 111cc53:	vmovups %ymm2,0x40(%rcx)
 111cc58:	vmovups %ymm1,0x20(%rcx)
 111cc5d:	vmovups %ymm0,(%rcx)
 111cc61:	jmp    111cce8 <huffman.treeCodeLengthsKnownActive__anon_38967+0xa88>
 111cc66:	lea    -0x6e0(%rbp),%rdi
 111cc6d:	mov    %rcx,%rdx
 111cc70:	call   11bf390 <huffman.treeCodeLengthsDenseKnownActive__anon_39007>
 111cc75:	vmovups -0x600(%rbp),%ymm0
 111cc7d:	vmovups %ymm0,0xe0(%rbx)
 111cc85:	vmovups -0x620(%rbp),%ymm0
 111cc8d:	vmovups %ymm0,0xc0(%rbx)
 111cc95:	vmovups -0x640(%rbp),%ymm0
 111cc9d:	vmovups %ymm0,0xa0(%rbx)
 111cca5:	vmovups -0x660(%rbp),%ymm0
 111ccad:	vmovups %ymm0,0x80(%rbx)
 111ccb5:	vmovups -0x6e0(%rbp),%ymm0
 111ccbd:	vmovups -0x6c0(%rbp),%ymm1
 111ccc5:	vmovups -0x6a0(%rbp),%ymm2
 111cccd:	vmovups -0x680(%rbp),%ymm3
 111ccd5:	vmovups %ymm3,0x60(%rbx)
 111ccda:	vmovups %ymm2,0x40(%rbx)
 111ccdf:	vmovups %ymm1,0x20(%rbx)
 111cce4:	vmovups %ymm0,(%rbx)
 111cce8:	add    $0x6c8,%rsp
 111ccef:	pop    %rbx
 111ccf0:	pop    %r14
 111ccf2:	pop    %r15
 111ccf4:	pop    %rbp
 111ccf5:	vzeroupper 
 111ccf8:	ret    

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_zstd_huffman_wide_x2:

Disassembly of section .vort_zstd_huffman_only_decode:

Disassembly of section .vort_zstd_frr_decode:

Disassembly of section .vort_zstd_zz_frr_pair:

Disassembly of section .vort_zstd_ffr_decode:

Disassembly of section .vort_zstd_raw_fse_decode:

Disassembly of section .vort_zstd_zz_ffr_pair:

Disassembly of section .vort_zstd_split_zz:

Disassembly of section .vort_zstd_split_wide_literal_decode:

Disassembly of section .vort_zstd_split_dense_literal_decode:

Disassembly of section .vort_zstd_split_literal_decode:

Disassembly of section .vort_zstd_zzz_long_match:

Disassembly of section .vort_zstd_zz_fse_mapped:

Disassembly of section .vort_zstd_fse_256:

Disassembly of section .vort_zstd_fse_counts:

Disassembly of section .vort_zstd_huffman_build:

Disassembly of section .vort_zstd_medium_split:

Disassembly of section .vort_zstd_tiny_raw:

Disassembly of section .vort_zstd_small_frame_decode:

Disassembly of section .vort_zstd_small_sequence_decode:

Disassembly of section .vort_zstd_fast_records:

Disassembly of section .vort_zstd_wide_sequence:

Disassembly of section .vort_zstd_dense_huffman:

Disassembly of section .vort_zstd_fast_encode:

Disassembly of section .vort_zstd_fast_large:

Disassembly of section .vort_zstd_fast_plan:

Disassembly of section .vort_zstd_multi_sequence_winner:

Disassembly of section .vort_zstd_fse_encode:

Disassembly of section .vort_zstd_dominance:

Disassembly of section .vort_zstd_zz_optimal:

Disassembly of section .vort_zstd_single_beam:

Disassembly of section .plt:
