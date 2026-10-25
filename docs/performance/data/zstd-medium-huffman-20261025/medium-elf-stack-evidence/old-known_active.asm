
/home/passchaos/project-z/vort/.zig-cache/o/ed94ec1c4a213c549af1a1d632f56d71/vort-zstd-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000111c260 <huffman.treeCodeLengthsKnownActive__anon_38967>:
 111c260:	test   %rcx,%rcx
 111c263:	je     111c34e <huffman.treeCodeLengthsKnownActive__anon_38967+0xee>
 111c269:	push   %rbp
 111c26a:	mov    %rsp,%rbp
 111c26d:	push   %r15
 111c26f:	push   %r14
 111c271:	push   %r13
 111c273:	push   %r12
 111c275:	push   %rbx
 111c276:	sub    $0x11f38,%rsp
 111c27d:	cmp    $0x1,%rcx
 111c281:	jne    111c389 <huffman.treeCodeLengthsKnownActive__anon_38967+0x129>
 111c287:	vxorps %xmm0,%xmm0,%xmm0
 111c28b:	vmovups %ymm0,-0x380(%rbp)
 111c293:	vmovups %ymm0,-0x3a0(%rbp)
 111c29b:	vmovups %ymm0,-0x3c0(%rbp)
 111c2a3:	vmovups %ymm0,-0x3e0(%rbp)
 111c2ab:	vmovups %ymm0,-0x400(%rbp)
 111c2b3:	vmovups %ymm0,-0x420(%rbp)
 111c2bb:	vmovups %ymm0,-0x440(%rbp)
 111c2c3:	vmovups %ymm0,-0x460(%rbp)
 111c2cb:	movzbl (%rdx),%eax
 111c2ce:	movb   $0x1,-0x460(%rbp,%rax,1)
 111c2d6:	vmovups -0x380(%rbp),%ymm0
 111c2de:	vmovups %ymm0,0xe0(%rdi)
 111c2e6:	vmovups -0x3a0(%rbp),%ymm0
 111c2ee:	vmovups %ymm0,0xc0(%rdi)
 111c2f6:	vmovups -0x3c0(%rbp),%ymm0
 111c2fe:	vmovups %ymm0,0xa0(%rdi)
 111c306:	vmovups -0x3e0(%rbp),%ymm0
 111c30e:	vmovups %ymm0,0x80(%rdi)
 111c316:	vmovups -0x460(%rbp),%ymm0
 111c31e:	vmovups -0x440(%rbp),%ymm1
 111c326:	vmovups -0x420(%rbp),%ymm2
 111c32e:	vmovups -0x400(%rbp),%ymm3
 111c336:	vmovups %ymm3,0x60(%rdi)
 111c33b:	vmovups %ymm2,0x40(%rdi)
 111c340:	vmovups %ymm1,0x20(%rdi)
 111c345:	vmovups %ymm0,(%rdi)
 111c349:	jmp    111d0d1 <huffman.treeCodeLengthsKnownActive__anon_38967+0xe71>
 111c34e:	vxorps %xmm0,%xmm0,%xmm0
 111c352:	vmovups %ymm0,0xe0(%rdi)
 111c35a:	vmovups %ymm0,0xc0(%rdi)
 111c362:	vmovups %ymm0,0xa0(%rdi)
 111c36a:	vmovups %ymm0,0x80(%rdi)
 111c372:	vmovups %ymm0,0x60(%rdi)
 111c377:	vmovups %ymm0,0x40(%rdi)
 111c37c:	vmovups %ymm0,0x20(%rdi)
 111c381:	vmovups %ymm0,(%rdi)
 111c385:	vzeroupper 
 111c388:	ret    
 111c389:	cmp    $0x20,%rcx
 111c38d:	ja     111c3a6 <huffman.treeCodeLengthsKnownActive__anon_38967+0x146>
 111c38f:	lea    -0x1(%rcx),%rbx
 111c393:	mov    %ecx,%eax
 111c395:	and    $0x7,%eax
 111c398:	cmp    $0x7,%rbx
 111c39c:	jae    111c3cb <huffman.treeCodeLengthsKnownActive__anon_38967+0x16b>
 111c39e:	xor    %r8d,%r8d
 111c3a1:	jmp    111c460 <huffman.treeCodeLengthsKnownActive__anon_38967+0x200>
 111c3a6:	cmp    $0x40,%rcx
 111c3aa:	ja     111c4cc <huffman.treeCodeLengthsKnownActive__anon_38967+0x26c>
 111c3b0:	lea    -0x1(%rcx),%rbx
 111c3b4:	mov    %ecx,%eax
 111c3b6:	and    $0x7,%eax
 111c3b9:	cmp    $0x7,%rbx
 111c3bd:	jae    111c8a0 <huffman.treeCodeLengthsKnownActive__anon_38967+0x640>
 111c3c3:	xor    %r8d,%r8d
 111c3c6:	jmp    111c930 <huffman.treeCodeLengthsKnownActive__anon_38967+0x6d0>
 111c3cb:	mov    %ecx,%r9d
 111c3ce:	and    $0x38,%r9d
 111c3d2:	xor    %r8d,%r8d
 111c3d5:	data16 cs nopw 0x0(%rax,%rax,1)
 111c3e0:	movzbl (%rdx,%r8,1),%r10d
 111c3e5:	mov    %r10w,-0x2760(%rbp,%r8,2)
 111c3ee:	movzbl 0x1(%rdx,%r8,1),%r10d
 111c3f4:	mov    %r10w,-0x275e(%rbp,%r8,2)
 111c3fd:	movzbl 0x2(%rdx,%r8,1),%r10d
 111c403:	mov    %r10w,-0x275c(%rbp,%r8,2)
 111c40c:	movzbl 0x3(%rdx,%r8,1),%r10d
 111c412:	mov    %r10w,-0x275a(%rbp,%r8,2)
 111c41b:	movzbl 0x4(%rdx,%r8,1),%r10d
 111c421:	mov    %r10w,-0x2758(%rbp,%r8,2)
 111c42a:	movzbl 0x5(%rdx,%r8,1),%r10d
 111c430:	mov    %r10w,-0x2756(%rbp,%r8,2)
 111c439:	movzbl 0x6(%rdx,%r8,1),%r10d
 111c43f:	mov    %r10w,-0x2754(%rbp,%r8,2)
 111c448:	movzbl 0x7(%rdx,%r8,1),%r10d
 111c44e:	mov    %r10w,-0x2752(%rbp,%r8,2)
 111c457:	add    $0x8,%r8
 111c45b:	cmp    %r8,%r9
 111c45e:	jne    111c3e0 <huffman.treeCodeLengthsKnownActive__anon_38967+0x180>
 111c460:	test   %rax,%rax
 111c463:	je     111c492 <huffman.treeCodeLengthsKnownActive__anon_38967+0x232>
 111c465:	lea    -0x2760(,%r8,2),%r9
 111c46d:	add    %rbp,%r9
 111c470:	add    %r8,%rdx
 111c473:	xor    %r8d,%r8d
 111c476:	cs nopw 0x0(%rax,%rax,1)
 111c480:	movzbl (%rdx,%r8,1),%r10d
 111c485:	mov    %r10w,(%r9,%r8,2)
 111c48a:	inc    %r8
 111c48d:	cmp    %r8,%rax
 111c490:	jne    111c480 <huffman.treeCodeLengthsKnownActive__anon_38967+0x220>
 111c492:	vxorps %xmm0,%xmm0,%xmm0
 111c496:	vmovups %ymm0,-0x11f00(%rbp)
 111c49e:	vmovups %ymm0,-0x11f20(%rbp)
 111c4a6:	vmovups %ymm0,-0x11f40(%rbp)
 111c4ae:	vmovups %ymm0,-0x11f60(%rbp)
 111c4b6:	mov    %ecx,%eax
 111c4b8:	and    $0x7,%eax
 111c4bb:	cmp    $0x7,%rbx
 111c4bf:	jae    111c568 <huffman.treeCodeLengthsKnownActive__anon_38967+0x308>
 111c4c5:	xor    %edx,%edx
 111c4c7:	jmp    111c635 <huffman.treeCodeLengthsKnownActive__anon_38967+0x3d5>
 111c4cc:	mov    %rdi,-0x40(%rbp)
 111c4d0:	cmp    $0x80,%rcx
 111c4d7:	jb     111c9bc <huffman.treeCodeLengthsKnownActive__anon_38967+0x75c>
 111c4dd:	lea    -0x960(%rbp),%rdi
 111c4e4:	mov    %rcx,%rdx
 111c4e7:	call   11bf290 <huffman.treeCodeLengthsDenseKnownActive__anon_39003>
 111c4ec:	vmovups -0x880(%rbp),%ymm0
 111c4f4:	mov    -0x40(%rbp),%rax
 111c4f8:	vmovups %ymm0,0xe0(%rax)
 111c500:	vmovups -0x8a0(%rbp),%ymm0
 111c508:	vmovups %ymm0,0xc0(%rax)
 111c510:	vmovups -0x8c0(%rbp),%ymm0
 111c518:	vmovups %ymm0,0xa0(%rax)
 111c520:	vmovups -0x8e0(%rbp),%ymm0
 111c528:	vmovups %ymm0,0x80(%rax)
 111c530:	vmovups -0x960(%rbp),%ymm0
 111c538:	vmovups -0x940(%rbp),%ymm1
 111c540:	vmovups -0x920(%rbp),%ymm2
 111c548:	vmovups -0x900(%rbp),%ymm3
 111c550:	vmovups %ymm3,0x60(%rax)
 111c555:	vmovups %ymm2,0x40(%rax)
 111c55a:	vmovups %ymm1,0x20(%rax)
 111c55f:	vmovups %ymm0,(%rax)
 111c563:	jmp    111d0d1 <huffman.treeCodeLengthsKnownActive__anon_38967+0xe71>
 111c568:	mov    %ecx,%r8d
 111c56b:	and    $0x38,%r8d
 111c56f:	xor    %edx,%edx
 111c571:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 111c580:	movzwl -0x2760(%rbp,%rdx,2),%r9d
 111c589:	mov    (%rsi,%r9,4),%r9d
 111c58d:	mov    %r9d,-0x11f60(%rbp,%rdx,4)
 111c595:	movzwl -0x275e(%rbp,%rdx,2),%r9d
 111c59e:	mov    (%rsi,%r9,4),%r9d
 111c5a2:	mov    %r9d,-0x11f5c(%rbp,%rdx,4)
 111c5aa:	movzwl -0x275c(%rbp,%rdx,2),%r9d
 111c5b3:	mov    (%rsi,%r9,4),%r9d
 111c5b7:	mov    %r9d,-0x11f58(%rbp,%rdx,4)
 111c5bf:	movzwl -0x275a(%rbp,%rdx,2),%r9d
 111c5c8:	mov    (%rsi,%r9,4),%r9d
 111c5cc:	mov    %r9d,-0x11f54(%rbp,%rdx,4)
 111c5d4:	movzwl -0x2758(%rbp,%rdx,2),%r9d
 111c5dd:	mov    (%rsi,%r9,4),%r9d
 111c5e1:	mov    %r9d,-0x11f50(%rbp,%rdx,4)
 111c5e9:	movzwl -0x2756(%rbp,%rdx,2),%r9d
 111c5f2:	mov    (%rsi,%r9,4),%r9d
 111c5f6:	mov    %r9d,-0x11f4c(%rbp,%rdx,4)
 111c5fe:	movzwl -0x2754(%rbp,%rdx,2),%r9d
 111c607:	mov    (%rsi,%r9,4),%r9d
 111c60b:	mov    %r9d,-0x11f48(%rbp,%rdx,4)
 111c613:	movzwl -0x2752(%rbp,%rdx,2),%r9d
 111c61c:	mov    (%rsi,%r9,4),%r9d
 111c620:	mov    %r9d,-0x11f44(%rbp,%rdx,4)
 111c628:	add    $0x8,%rdx
 111c62c:	cmp    %rdx,%r8
 111c62f:	jne    111c580 <huffman.treeCodeLengthsKnownActive__anon_38967+0x320>
 111c635:	mov    %rdi,%r14
 111c638:	test   %rax,%rax
 111c63b:	je     111c675 <huffman.treeCodeLengthsKnownActive__anon_38967+0x415>
 111c63d:	lea    -0x11f60(,%rdx,4),%rdi
 111c645:	add    %rbp,%rdi
 111c648:	lea    -0x2760(,%rdx,2),%rdx
 111c650:	add    %rbp,%rdx
 111c653:	xor    %r8d,%r8d
 111c656:	cs nopw 0x0(%rax,%rax,1)
 111c660:	movzwl (%rdx,%r8,2),%r9d
 111c665:	mov    (%rsi,%r9,4),%r9d
 111c669:	mov    %r9d,(%rdi,%r8,4)
 111c66d:	inc    %r8
 111c670:	cmp    %r8,%rax
 111c673:	jne    111c660 <huffman.treeCodeLengthsKnownActive__anon_38967+0x400>
 111c675:	lea    -0x860(%rbp),%rdi
 111c67c:	lea    -0x11f60(%rbp),%rsi
 111c683:	mov    %rcx,%rdx
 111c686:	mov    %rcx,%r15
 111c689:	vzeroupper 
 111c68c:	call   1130280 <huffman.packageMergeCodeLengths__anon_39186>
 111c691:	mov    %r15,%rdx
 111c694:	vxorps %xmm0,%xmm0,%xmm0
 111c698:	vmovups %ymm0,-0x80(%rbp)
 111c69d:	vmovups %ymm0,-0xa0(%rbp)
 111c6a5:	vmovups %ymm0,-0xc0(%rbp)
 111c6ad:	vmovups %ymm0,-0xe0(%rbp)
 111c6b5:	vmovups %ymm0,-0x100(%rbp)
 111c6bd:	vmovups %ymm0,-0x120(%rbp)
 111c6c5:	vmovups %ymm0,-0x140(%rbp)
 111c6cd:	vmovups %ymm0,-0x160(%rbp)
 111c6d5:	mov    %edx,%eax
 111c6d7:	and    $0x7,%eax
 111c6da:	cmp    $0x7,%rbx
 111c6de:	jae    111c6ea <huffman.treeCodeLengthsKnownActive__anon_38967+0x48a>
 111c6e0:	xor    %esi,%esi
 111c6e2:	mov    %r14,%rcx
 111c6e5:	jmp    111c7f5 <huffman.treeCodeLengthsKnownActive__anon_38967+0x595>
 111c6ea:	and    $0x38,%edx
 111c6ed:	xor    %esi,%esi
 111c6ef:	mov    %r14,%rcx
 111c6f2:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 111c700:	movzwl -0x2760(%rbp,%rsi,2),%edi
 111c708:	movzbl -0x860(%rbp,%rsi,1),%r8d
 111c711:	movzbl -0x85f(%rbp,%rsi,1),%r9d
 111c71a:	and    $0xf,%r8b
 111c71e:	mov    %r8b,-0x160(%rbp,%rdi,1)
 111c726:	movzwl -0x275e(%rbp,%rsi,2),%edi
 111c72e:	and    $0xf,%r9b
 111c732:	mov    %r9b,-0x160(%rbp,%rdi,1)
 111c73a:	movzwl -0x275c(%rbp,%rsi,2),%edi
 111c742:	movzbl -0x85e(%rbp,%rsi,1),%r8d
 111c74b:	and    $0xf,%r8b
 111c74f:	mov    %r8b,-0x160(%rbp,%rdi,1)
 111c757:	movzwl -0x275a(%rbp,%rsi,2),%edi
 111c75f:	movzbl -0x85d(%rbp,%rsi,1),%r8d
 111c768:	and    $0xf,%r8b
 111c76c:	mov    %r8b,-0x160(%rbp,%rdi,1)
 111c774:	movzwl -0x2758(%rbp,%rsi,2),%edi
 111c77c:	movzbl -0x85c(%rbp,%rsi,1),%r8d
 111c785:	and    $0xf,%r8b
 111c789:	mov    %r8b,-0x160(%rbp,%rdi,1)
 111c791:	movzwl -0x2756(%rbp,%rsi,2),%edi
 111c799:	movzbl -0x85b(%rbp,%rsi,1),%r8d
 111c7a2:	and    $0xf,%r8b
 111c7a6:	mov    %r8b,-0x160(%rbp,%rdi,1)
 111c7ae:	movzwl -0x2754(%rbp,%rsi,2),%edi
 111c7b6:	movzbl -0x85a(%rbp,%rsi,1),%r8d
 111c7bf:	and    $0xf,%r8b
 111c7c3:	mov    %r8b,-0x160(%rbp,%rdi,1)
 111c7cb:	movzwl -0x2752(%rbp,%rsi,2),%edi
 111c7d3:	movzbl -0x859(%rbp,%rsi,1),%r8d
 111c7dc:	and    $0xf,%r8b
 111c7e0:	mov    %r8b,-0x160(%rbp,%rdi,1)
 111c7e8:	add    $0x8,%rsi
 111c7ec:	cmp    %rsi,%rdx
 111c7ef:	jne    111c700 <huffman.treeCodeLengthsKnownActive__anon_38967+0x4a0>
 111c7f5:	test   %rax,%rax
 111c7f8:	je     111c83e <huffman.treeCodeLengthsKnownActive__anon_38967+0x5de>
 111c7fa:	lea    (%rsi,%rbp,1),%rdx
 111c7fe:	add    $0xfffffffffffff7a0,%rdx
 111c805:	lea    -0x2760(,%rsi,2),%rsi
 111c80d:	add    %rbp,%rsi
 111c810:	xor    %edi,%edi
 111c812:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 111c820:	movzwl (%rsi,%rdi,2),%r8d
 111c825:	movzbl (%rdx,%rdi,1),%r9d
 111c82a:	and    $0xf,%r9b
 111c82e:	mov    %r9b,-0x160(%rbp,%r8,1)
 111c836:	inc    %rdi
 111c839:	cmp    %rdi,%rax
 111c83c:	jne    111c820 <huffman.treeCodeLengthsKnownActive__anon_38967+0x5c0>
 111c83e:	vmovups -0x80(%rbp),%ymm0
 111c843:	vmovups %ymm0,0xe0(%rcx)
 111c84b:	vmovups -0xa0(%rbp),%ymm0
 111c853:	vmovups %ymm0,0xc0(%rcx)
 111c85b:	vmovups -0xc0(%rbp),%ymm0
 111c863:	vmovups %ymm0,0xa0(%rcx)
 111c86b:	vmovups -0xe0(%rbp),%ymm0
 111c873:	vmovups %ymm0,0x80(%rcx)
 111c87b:	vmovups -0x160(%rbp),%ymm0
 111c883:	vmovups -0x140(%rbp),%ymm1
 111c88b:	vmovups -0x120(%rbp),%ymm2
 111c893:	vmovups -0x100(%rbp),%ymm3
 111c89b:	jmp    111d0be <huffman.treeCodeLengthsKnownActive__anon_38967+0xe5e>
 111c8a0:	mov    %ecx,%r9d
 111c8a3:	and    $0x78,%r9d
 111c8a7:	xor    %r8d,%r8d
 111c8aa:	nopw   0x0(%rax,%rax,1)
 111c8b0:	movzbl (%rdx,%r8,1),%r10d
 111c8b5:	mov    %r10w,-0x2760(%rbp,%r8,2)
 111c8be:	movzbl 0x1(%rdx,%r8,1),%r10d
 111c8c4:	mov    %r10w,-0x275e(%rbp,%r8,2)
 111c8cd:	movzbl 0x2(%rdx,%r8,1),%r10d
 111c8d3:	mov    %r10w,-0x275c(%rbp,%r8,2)
 111c8dc:	movzbl 0x3(%rdx,%r8,1),%r10d
 111c8e2:	mov    %r10w,-0x275a(%rbp,%r8,2)
 111c8eb:	movzbl 0x4(%rdx,%r8,1),%r10d
 111c8f1:	mov    %r10w,-0x2758(%rbp,%r8,2)
 111c8fa:	movzbl 0x5(%rdx,%r8,1),%r10d
 111c900:	mov    %r10w,-0x2756(%rbp,%r8,2)
 111c909:	movzbl 0x6(%rdx,%r8,1),%r10d
 111c90f:	mov    %r10w,-0x2754(%rbp,%r8,2)
 111c918:	movzbl 0x7(%rdx,%r8,1),%r10d
 111c91e:	mov    %r10w,-0x2752(%rbp,%r8,2)
 111c927:	add    $0x8,%r8
 111c92b:	cmp    %r8,%r9
 111c92e:	jne    111c8b0 <huffman.treeCodeLengthsKnownActive__anon_38967+0x650>
 111c930:	test   %rax,%rax
 111c933:	je     111c962 <huffman.treeCodeLengthsKnownActive__anon_38967+0x702>
 111c935:	lea    -0x2760(,%r8,2),%r9
 111c93d:	add    %rbp,%r9
 111c940:	add    %r8,%rdx
 111c943:	xor    %r8d,%r8d
 111c946:	cs nopw 0x0(%rax,%rax,1)
 111c950:	movzbl (%rdx,%r8,1),%r10d
 111c955:	mov    %r10w,(%r9,%r8,2)
 111c95a:	inc    %r8
 111c95d:	cmp    %r8,%rax
 111c960:	jne    111c950 <huffman.treeCodeLengthsKnownActive__anon_38967+0x6f0>
 111c962:	vxorps %xmm0,%xmm0,%xmm0
 111c966:	vmovups %ymm0,-0x11e80(%rbp)
 111c96e:	vmovups %ymm0,-0x11ea0(%rbp)
 111c976:	vmovups %ymm0,-0x11ec0(%rbp)
 111c97e:	vmovups %ymm0,-0x11ee0(%rbp)
 111c986:	vmovups %ymm0,-0x11f00(%rbp)
 111c98e:	vmovups %ymm0,-0x11f20(%rbp)
 111c996:	vmovups %ymm0,-0x11f40(%rbp)
 111c99e:	vmovups %ymm0,-0x11f60(%rbp)
 111c9a6:	mov    %ecx,%eax
 111c9a8:	and    $0x7,%eax
 111c9ab:	cmp    $0x7,%rbx
 111c9af:	jae    111ca7b <huffman.treeCodeLengthsKnownActive__anon_38967+0x81b>
 111c9b5:	xor    %edx,%edx
 111c9b7:	jmp    111cb45 <huffman.treeCodeLengthsKnownActive__anon_38967+0x8e5>
 111c9bc:	lea    -0x2f60(%rbp),%rdi
 111c9c3:	mov    $0x400,%edx
 111c9c8:	mov    %rcx,-0x38(%rbp)
 111c9cc:	call   119d860 <compiler_rt.memcpy.memcpyFast>
 111c9d1:	mov    -0x38(%rbp),%rsi
 111c9d5:	xor    %eax,%eax
 111c9d7:	xor    %ecx,%ecx
 111c9d9:	jmp    111c9f1 <huffman.treeCodeLengthsKnownActive__anon_38967+0x791>
 111c9db:	nopl   0x0(%rax,%rax,1)
 111c9e0:	add    $0x2,%rcx
 111c9e4:	cmp    $0x100,%rcx
 111c9eb:	je     111cc01 <huffman.treeCodeLengthsKnownActive__anon_38967+0x9a1>
 111c9f1:	mov    -0x2f60(%rbp,%rcx,4),%edx
 111c9f8:	test   %rdx,%rdx
 111c9fb:	je     111ca32 <huffman.treeCodeLengthsKnownActive__anon_38967+0x7d2>
 111c9fd:	mov    %rax,%rdi
 111ca00:	shl    $0x4,%rdi
 111ca04:	mov    %rdx,-0x11f60(%rbp,%rdi,1)
 111ca0c:	mov    %cx,-0x11f54(%rbp,%rdi,1)
 111ca14:	mov    %ax,-0x11f52(%rbp,%rdi,1)
 111ca1c:	movl   $0xffffffff,-0x11f58(%rbp,%rdi,1)
 111ca27:	mov    %ax,-0x2960(%rbp,%rax,2)
 111ca2f:	inc    %rax
 111ca32:	mov    -0x2f5c(%rbp,%rcx,4),%edx
 111ca39:	test   %rdx,%rdx
 111ca3c:	je     111c9e0 <huffman.treeCodeLengthsKnownActive__anon_38967+0x780>
 111ca3e:	mov    %rax,%rdi
 111ca41:	shl    $0x4,%rdi
 111ca45:	mov    %rdx,-0x11f60(%rbp,%rdi,1)
 111ca4d:	lea    0x1(%rcx),%edx
 111ca50:	mov    %dx,-0x11f54(%rbp,%rdi,1)
 111ca58:	mov    %ax,-0x11f52(%rbp,%rdi,1)
 111ca60:	movl   $0xffffffff,-0x11f58(%rbp,%rdi,1)
 111ca6b:	mov    %ax,-0x2960(%rbp,%rax,2)
 111ca73:	inc    %rax
 111ca76:	jmp    111c9e0 <huffman.treeCodeLengthsKnownActive__anon_38967+0x780>
 111ca7b:	mov    %ecx,%r8d
 111ca7e:	and    $0x78,%r8d
 111ca82:	xor    %edx,%edx
 111ca84:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 111ca90:	movzwl -0x2760(%rbp,%rdx,2),%r9d
 111ca99:	mov    (%rsi,%r9,4),%r9d
 111ca9d:	mov    %r9d,-0x11f60(%rbp,%rdx,4)
 111caa5:	movzwl -0x275e(%rbp,%rdx,2),%r9d
 111caae:	mov    (%rsi,%r9,4),%r9d
 111cab2:	mov    %r9d,-0x11f5c(%rbp,%rdx,4)
 111caba:	movzwl -0x275c(%rbp,%rdx,2),%r9d
 111cac3:	mov    (%rsi,%r9,4),%r9d
 111cac7:	mov    %r9d,-0x11f58(%rbp,%rdx,4)
 111cacf:	movzwl -0x275a(%rbp,%rdx,2),%r9d
 111cad8:	mov    (%rsi,%r9,4),%r9d
 111cadc:	mov    %r9d,-0x11f54(%rbp,%rdx,4)
 111cae4:	movzwl -0x2758(%rbp,%rdx,2),%r9d
 111caed:	mov    (%rsi,%r9,4),%r9d
 111caf1:	mov    %r9d,-0x11f50(%rbp,%rdx,4)
 111caf9:	movzwl -0x2756(%rbp,%rdx,2),%r9d
 111cb02:	mov    (%rsi,%r9,4),%r9d
 111cb06:	mov    %r9d,-0x11f4c(%rbp,%rdx,4)
 111cb0e:	movzwl -0x2754(%rbp,%rdx,2),%r9d
 111cb17:	mov    (%rsi,%r9,4),%r9d
 111cb1b:	mov    %r9d,-0x11f48(%rbp,%rdx,4)
 111cb23:	movzwl -0x2752(%rbp,%rdx,2),%r9d
 111cb2c:	mov    (%rsi,%r9,4),%r9d
 111cb30:	mov    %r9d,-0x11f44(%rbp,%rdx,4)
 111cb38:	add    $0x8,%rdx
 111cb3c:	cmp    %rdx,%r8
 111cb3f:	jne    111ca90 <huffman.treeCodeLengthsKnownActive__anon_38967+0x830>
 111cb45:	mov    %rdi,%r14
 111cb48:	test   %rax,%rax
 111cb4b:	je     111cb85 <huffman.treeCodeLengthsKnownActive__anon_38967+0x925>
 111cb4d:	lea    -0x11f60(,%rdx,4),%rdi
 111cb55:	add    %rbp,%rdi
 111cb58:	lea    -0x2760(,%rdx,2),%rdx
 111cb60:	add    %rbp,%rdx
 111cb63:	xor    %r8d,%r8d
 111cb66:	cs nopw 0x0(%rax,%rax,1)
 111cb70:	movzwl (%rdx,%r8,2),%r9d
 111cb75:	mov    (%rsi,%r9,4),%r9d
 111cb79:	mov    %r9d,(%rdi,%r8,4)
 111cb7d:	inc    %r8
 111cb80:	cmp    %r8,%rax
 111cb83:	jne    111cb70 <huffman.treeCodeLengthsKnownActive__anon_38967+0x910>
 111cb85:	lea    -0x860(%rbp),%rdi
 111cb8c:	lea    -0x11f60(%rbp),%rsi
 111cb93:	mov    %rcx,%rdx
 111cb96:	mov    %rcx,%r15
 111cb99:	vzeroupper 
 111cb9c:	call   111d4e0 <huffman.packageMergeCodeLengths__anon_39019>
 111cba1:	mov    %r15,%rdx
 111cba4:	vxorps %xmm0,%xmm0,%xmm0
 111cba8:	vmovups %ymm0,-0x180(%rbp)
 111cbb0:	vmovups %ymm0,-0x1a0(%rbp)
 111cbb8:	vmovups %ymm0,-0x1c0(%rbp)
 111cbc0:	vmovups %ymm0,-0x1e0(%rbp)
 111cbc8:	vmovups %ymm0,-0x200(%rbp)
 111cbd0:	vmovups %ymm0,-0x220(%rbp)
 111cbd8:	vmovups %ymm0,-0x240(%rbp)
 111cbe0:	vmovups %ymm0,-0x260(%rbp)
 111cbe8:	mov    %edx,%eax
 111cbea:	and    $0x7,%eax
 111cbed:	cmp    $0x7,%rbx
 111cbf1:	jae    111cf18 <huffman.treeCodeLengthsKnownActive__anon_38967+0xcb8>
 111cbf7:	xor    %esi,%esi
 111cbf9:	mov    %r14,%rcx
 111cbfc:	jmp    111d015 <huffman.treeCodeLengthsKnownActive__anon_38967+0xdb5>
 111cc01:	lea    -0x11f60(%rbp),%rax
 111cc08:	mov    %rax,-0x58(%rbp)
 111cc0c:	mov    %rsi,-0x50(%rbp)
 111cc10:	lea    -0x2960(%rbp),%r15
 111cc17:	lea    -0x58(%rbp),%rdx
 111cc1b:	mov    %r15,%rdi
 111cc1e:	call   111db20 <sort.block.block__anon_39113>
 111cc23:	mov    -0x38(%rbp),%rax
 111cc27:	lea    (%rax,%rax,1),%rbx
 111cc2b:	lea    -0x860(%rbp),%r14
 111cc32:	mov    %r14,%rdi
 111cc35:	mov    %r15,%rsi
 111cc38:	mov    %rbx,%rdx
 111cc3b:	call   119d860 <compiler_rt.memcpy.memcpyFast>
 111cc40:	mov    -0x38(%rbp),%rax
 111cc44:	movb   $0x1,-0x29(%rbp)
 111cc48:	mov    $0x1,%cl
 111cc4a:	mov    %rbx,-0x48(%rbp)
 111cc4e:	mov    %rbx,%rdx
 111cc51:	mov    %rax,%r15
 111cc54:	cmp    $0xa,%cl
 111cc57:	ja     111d0ea <huffman.treeCodeLengthsKnownActive__anon_38967+0xe8a>
 111cc5d:	mov    %rax,%r15
 111cc60:	mov    %rax,%rdi
 111cc63:	jmp    111cc81 <huffman.treeCodeLengthsKnownActive__anon_38967+0xa21>
 111cc65:	data16 cs nopw 0x0(%rax,%rax,1)
 111cc70:	inc    %cl
 111cc72:	and    $0xf,%cl
 111cc75:	mov    %cl,-0x29(%rbp)
 111cc78:	cmp    $0xb,%cl
 111cc7b:	jae    111d0e6 <huffman.treeCodeLengthsKnownActive__anon_38967+0xe86>
 111cc81:	cmp    $0x2,%rdi
 111cc85:	jb     111ccb0 <huffman.treeCodeLengthsKnownActive__anon_38967+0xa50>
 111cc87:	add    $0xfffffffffffffffe,%rdi
 111cc8b:	mov    %rdi,%rsi
 111cc8e:	shr    %rsi
 111cc91:	cmp    $0x2,%rdi
 111cc95:	jae    111ccb7 <huffman.treeCodeLengthsKnownActive__anon_38967+0xa57>
 111cc97:	xor    %r8d,%r8d
 111cc9a:	xor    %r9d,%r9d
 111cc9d:	test   $0x2,%dil
 111cca1:	je     111cdb1 <huffman.treeCodeLengthsKnownActive__anon_38967+0xb51>
 111cca7:	jmp    111ce22 <huffman.treeCodeLengthsKnownActive__anon_38967+0xbc2>
 111ccac:	nopl   0x0(%rax)
 111ccb0:	xor    %esi,%esi
 111ccb2:	jmp    111ce25 <huffman.treeCodeLengthsKnownActive__anon_38967+0xbc5>
 111ccb7:	lea    0x1(%rsi),%r10
 111ccbb:	mov    %r15,%r11
 111ccbe:	shl    $0x4,%r11
 111ccc2:	lea    -0x11f42(%rbp),%rdx
 111ccc9:	add    %rdx,%r11
 111cccc:	and    $0xfffffffffffffffe,%r10
 111ccd0:	neg    %r10
 111ccd3:	xor    %r8d,%r8d
 111ccd6:	xor    %r9d,%r9d
 111ccd9:	nopl   0x0(%rax)
 111cce0:	movzwl -0x860(%rbp,%r9,2),%edx
 111cce9:	movzwl -0x85e(%rbp,%r9,2),%ebx
 111ccf2:	mov    %edx,%r13d
 111ccf5:	shl    $0x4,%r13d
 111ccf9:	mov    %ebx,%r12d
 111ccfc:	shl    $0x4,%r12d
 111cd00:	mov    -0x11f60(%rbp,%r12,1),%r12
 111cd08:	add    -0x11f60(%rbp,%r13,1),%r12
 111cd10:	mov    %r12,-0x1e(%r11,%r9,8)
 111cd15:	mov    %dx,-0x16(%r11,%r9,8)
 111cd1b:	mov    %bx,-0x14(%r11,%r9,8)
 111cd21:	mov    %r15w,-0x10(%r11,%r9,8)
 111cd27:	movw   $0xffff,-0x12(%r11,%r9,8)
 111cd2f:	movzwl -0x85c(%rbp,%r9,2),%edx
 111cd38:	movzwl -0x85a(%rbp,%r9,2),%ebx
 111cd41:	mov    %edx,%r12d
 111cd44:	shl    $0x4,%r12d
 111cd48:	mov    %ebx,%r13d
 111cd4b:	shl    $0x4,%r13d
 111cd4f:	mov    -0x11f60(%rbp,%r13,1),%r13
 111cd57:	add    -0x11f60(%rbp,%r12,1),%r13
 111cd5f:	mov    %r15w,-0x2b60(%rbp,%r9,1)
 111cd68:	mov    %r13,-0xe(%r11,%r9,8)
 111cd6d:	mov    %dx,-0x6(%r11,%r9,8)
 111cd73:	mov    %bx,-0x4(%r11,%r9,8)
 111cd79:	lea    0x1(%r15),%edx
 111cd7d:	mov    %dx,(%r11,%r9,8)
 111cd82:	movw   $0xffff,-0x2(%r11,%r9,8)
 111cd8a:	add    $0x2,%r15
 111cd8e:	mov    %dx,-0x2b5e(%rbp,%r9,1)
 111cd97:	add    $0x4,%r9
 111cd9b:	add    $0xfffffffffffffffe,%r8
 111cd9f:	cmp    %r8,%r10
 111cda2:	jne    111cce0 <huffman.treeCodeLengthsKnownActive__anon_38967+0xa80>
 111cda8:	neg    %r8
 111cdab:	test   $0x2,%dil
 111cdaf:	jne    111ce22 <huffman.treeCodeLengthsKnownActive__anon_38967+0xbc2>
 111cdb1:	movzwl -0x860(%rbp,%r9,2),%edx
 111cdba:	movzwl -0x85e(%rbp,%r9,2),%edi
 111cdc3:	mov    %r15,%r9
 111cdc6:	shl    $0x4,%r9
 111cdca:	mov    %edx,%r10d
 111cdcd:	shl    $0x4,%r10d
 111cdd1:	mov    %edi,%r11d
 111cdd4:	shl    $0x4,%r11d
 111cdd8:	mov    -0x11f60(%rbp,%r11,1),%r11
 111cde0:	add    -0x11f60(%rbp,%r10,1),%r11
 111cde8:	mov    %r11,-0x11f60(%rbp,%r9,1)
 111cdf0:	mov    %dx,-0x11f58(%rbp,%r9,1)
 111cdf9:	mov    %di,-0x11f56(%rbp,%r9,1)
 111ce02:	mov    %r15w,-0x11f52(%rbp,%r9,1)
 111ce0b:	movw   $0xffff,-0x11f54(%rbp,%r9,1)
 111ce16:	mov    %r15w,-0x2b60(%rbp,%r8,2)
 111ce1f:	inc    %r15
 111ce22:	inc    %rsi
 111ce25:	test   %rsi,%rsi
 111ce28:	setne  %r11b
 111ce2c:	mov    $0x1,%bl
 111ce2e:	mov    %r14,%r8
 111ce31:	xor    %r9d,%r9d
 111ce34:	xor    %r10d,%r10d
 111ce37:	xor    %edi,%edi
 111ce39:	nopl   0x0(%rax)
 111ce40:	test   $0x1,%r11b
 111ce44:	je     111ceb0 <huffman.treeCodeLengthsKnownActive__anon_38967+0xc50>
 111ce46:	test   $0x1,%bl
 111ce49:	je     111ced0 <huffman.treeCodeLengthsKnownActive__anon_38967+0xc70>
 111ce4f:	movzwl -0x2960(%rbp,%r10,2),%r11d
 111ce58:	movzwl -0x2b60(%rbp,%r9,2),%ebx
 111ce61:	mov    %r11d,%edx
 111ce64:	shl    $0x4,%edx
 111ce67:	mov    %ebx,%r13d
 111ce6a:	shl    $0x4,%r13d
 111ce6e:	mov    -0x11f60(%rbp,%r13,1),%r12
 111ce76:	cmp    %r12,-0x11f60(%rbp,%rdx,1)
 111ce7e:	jne    111cf08 <huffman.treeCodeLengthsKnownActive__anon_38967+0xca8>
 111ce84:	add    %rbp,%rdx
 111ce87:	add    $0xfffffffffffee0a0,%rdx
 111ce8e:	lea    -0x11f60(,%r13,1),%r12
 111ce96:	add    %rbp,%r12
 111ce99:	movzwl 0xe(%rdx),%r13d
 111ce9e:	mov    %r8,%rdx
 111cea1:	cmp    0xe(%r12),%r13w
 111cea7:	jb     111cf12 <huffman.treeCodeLengthsKnownActive__anon_38967+0xcb2>
 111cea9:	mov    %bx,(%rdx)
 111ceac:	jmp    111cedd <huffman.treeCodeLengthsKnownActive__anon_38967+0xc7d>
 111ceae:	xchg   %ax,%ax
 111ceb0:	movzwl -0x2960(%rbp,%r10,2),%edx
 111ceb9:	mov    %dx,(%r8)
 111cebd:	inc    %r10
 111cec0:	jmp    111cee0 <huffman.treeCodeLengthsKnownActive__anon_38967+0xc80>
 111cec2:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 111ced0:	movzwl -0x2b60(%rbp,%r9,2),%edx
 111ced9:	mov    %dx,(%r8)
 111cedd:	inc    %r9
 111cee0:	inc    %rdi
 111cee3:	cmp    %rsi,%r9
 111cee6:	setb   %r11b
 111ceea:	add    $0x2,%r8
 111ceee:	cmp    %rax,%r10
 111cef1:	setb   %bl
 111cef4:	jb     111ce40 <huffman.treeCodeLengthsKnownActive__anon_38967+0xbe0>
 111cefa:	cmp    %rsi,%r9
 111cefd:	jb     111ce40 <huffman.treeCodeLengthsKnownActive__anon_38967+0xbe0>
 111cf03:	jmp    111cc70 <huffman.treeCodeLengthsKnownActive__anon_38967+0xa10>
 111cf08:	lea    -0x860(%rbp,%rdi,2),%rdx
 111cf10:	jae    111cea9 <huffman.treeCodeLengthsKnownActive__anon_38967+0xc49>
 111cf12:	mov    %r11w,(%rdx)
 111cf16:	jmp    111cebd <huffman.treeCodeLengthsKnownActive__anon_38967+0xc5d>
 111cf18:	and    $0x78,%edx
 111cf1b:	xor    %esi,%esi
 111cf1d:	mov    %r14,%rcx
 111cf20:	movzwl -0x2760(%rbp,%rsi,2),%edi
 111cf28:	movzbl -0x860(%rbp,%rsi,1),%r8d
 111cf31:	movzbl -0x85f(%rbp,%rsi,1),%r9d
 111cf3a:	and    $0xf,%r8b
 111cf3e:	mov    %r8b,-0x260(%rbp,%rdi,1)
 111cf46:	movzwl -0x275e(%rbp,%rsi,2),%edi
 111cf4e:	and    $0xf,%r9b
 111cf52:	mov    %r9b,-0x260(%rbp,%rdi,1)
 111cf5a:	movzwl -0x275c(%rbp,%rsi,2),%edi
 111cf62:	movzbl -0x85e(%rbp,%rsi,1),%r8d
 111cf6b:	and    $0xf,%r8b
 111cf6f:	mov    %r8b,-0x260(%rbp,%rdi,1)
 111cf77:	movzwl -0x275a(%rbp,%rsi,2),%edi
 111cf7f:	movzbl -0x85d(%rbp,%rsi,1),%r8d
 111cf88:	and    $0xf,%r8b
 111cf8c:	mov    %r8b,-0x260(%rbp,%rdi,1)
 111cf94:	movzwl -0x2758(%rbp,%rsi,2),%edi
 111cf9c:	movzbl -0x85c(%rbp,%rsi,1),%r8d
 111cfa5:	and    $0xf,%r8b
 111cfa9:	mov    %r8b,-0x260(%rbp,%rdi,1)
 111cfb1:	movzwl -0x2756(%rbp,%rsi,2),%edi
 111cfb9:	movzbl -0x85b(%rbp,%rsi,1),%r8d
 111cfc2:	and    $0xf,%r8b
 111cfc6:	mov    %r8b,-0x260(%rbp,%rdi,1)
 111cfce:	movzwl -0x2754(%rbp,%rsi,2),%edi
 111cfd6:	movzbl -0x85a(%rbp,%rsi,1),%r8d
 111cfdf:	and    $0xf,%r8b
 111cfe3:	mov    %r8b,-0x260(%rbp,%rdi,1)
 111cfeb:	movzwl -0x2752(%rbp,%rsi,2),%edi
 111cff3:	movzbl -0x859(%rbp,%rsi,1),%r8d
 111cffc:	and    $0xf,%r8b
 111d000:	mov    %r8b,-0x260(%rbp,%rdi,1)
 111d008:	add    $0x8,%rsi
 111d00c:	cmp    %rsi,%rdx
 111d00f:	jne    111cf20 <huffman.treeCodeLengthsKnownActive__anon_38967+0xcc0>
 111d015:	test   %rax,%rax
 111d018:	je     111d05e <huffman.treeCodeLengthsKnownActive__anon_38967+0xdfe>
 111d01a:	lea    (%rsi,%rbp,1),%rdx
 111d01e:	add    $0xfffffffffffff7a0,%rdx
 111d025:	lea    -0x2760(,%rsi,2),%rsi
 111d02d:	add    %rbp,%rsi
 111d030:	xor    %edi,%edi
 111d032:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 111d040:	movzwl (%rsi,%rdi,2),%r8d
 111d045:	movzbl (%rdx,%rdi,1),%r9d
 111d04a:	and    $0xf,%r9b
 111d04e:	mov    %r9b,-0x260(%rbp,%r8,1)
 111d056:	inc    %rdi
 111d059:	cmp    %rdi,%rax
 111d05c:	jne    111d040 <huffman.treeCodeLengthsKnownActive__anon_38967+0xde0>
 111d05e:	vmovups -0x180(%rbp),%ymm0
 111d066:	vmovups %ymm0,0xe0(%rcx)
 111d06e:	vmovups -0x1a0(%rbp),%ymm0
 111d076:	vmovups %ymm0,0xc0(%rcx)
 111d07e:	vmovups -0x1c0(%rbp),%ymm0
 111d086:	vmovups %ymm0,0xa0(%rcx)
 111d08e:	vmovups -0x1e0(%rbp),%ymm0
 111d096:	vmovups %ymm0,0x80(%rcx)
 111d09e:	vmovups -0x260(%rbp),%ymm0
 111d0a6:	vmovups -0x240(%rbp),%ymm1
 111d0ae:	vmovups -0x220(%rbp),%ymm2
 111d0b6:	vmovups -0x200(%rbp),%ymm3
 111d0be:	vmovups %ymm3,0x60(%rcx)
 111d0c3:	vmovups %ymm2,0x40(%rcx)
 111d0c8:	vmovups %ymm1,0x20(%rcx)
 111d0cd:	vmovups %ymm0,(%rcx)
 111d0d1:	add    $0x11f38,%rsp
 111d0d8:	pop    %rbx
 111d0d9:	pop    %r12
 111d0db:	pop    %r13
 111d0dd:	pop    %r14
 111d0df:	pop    %r15
 111d0e1:	pop    %rbp
 111d0e2:	vzeroupper 
 111d0e5:	ret    
 111d0e6:	lea    (%r15,%r15,1),%rdx
 111d0ea:	mov    -0x48(%rbp),%r12
 111d0ee:	lea    -0x2(%r12),%r14
 111d0f3:	vxorps %xmm0,%xmm0,%xmm0
 111d0f7:	vmovups %ymm0,-0x280(%rbp)
 111d0ff:	vmovups %ymm0,-0x2a0(%rbp)
 111d107:	vmovups %ymm0,-0x2c0(%rbp)
 111d10f:	vmovups %ymm0,-0x2e0(%rbp)
 111d117:	vmovups %ymm0,-0x300(%rbp)
 111d11f:	vmovups %ymm0,-0x320(%rbp)
 111d127:	vmovups %ymm0,-0x340(%rbp)
 111d12f:	vmovups %ymm0,-0x360(%rbp)
 111d137:	lea    -0x2760(%rbp),%rdi
 111d13e:	xor    %ebx,%ebx
 111d140:	xor    %esi,%esi
 111d142:	vzeroupper 
 111d145:	call   119d440 <compiler_rt.memset>
 111d14a:	add    $0xfffffffffffffffd,%r12
 111d14e:	mov    %r14d,%eax
 111d151:	and    $0x6,%eax
 111d154:	cmp    $0x7,%r12
 111d158:	jae    111d163 <huffman.treeCodeLengthsKnownActive__anon_38967+0xf03>
 111d15a:	mov    -0x40(%rbp),%r12
 111d15e:	jmp    111d1fd <huffman.treeCodeLengthsKnownActive__anon_38967+0xf9d>
 111d163:	and    $0xfffffffffffffff8,%r14
 111d167:	xor    %ebx,%ebx
 111d169:	mov    -0x40(%rbp),%r12
 111d16d:	nopl   (%rax)
 111d170:	movzwl -0x860(%rbp,%rbx,2),%ecx
 111d178:	incw   -0x2760(%rbp,%rcx,2)
 111d180:	movzwl -0x85e(%rbp,%rbx,2),%ecx
 111d188:	incw   -0x2760(%rbp,%rcx,2)
 111d190:	movzwl -0x85c(%rbp,%rbx,2),%ecx
 111d198:	incw   -0x2760(%rbp,%rcx,2)
 111d1a0:	movzwl -0x85a(%rbp,%rbx,2),%ecx
 111d1a8:	incw   -0x2760(%rbp,%rcx,2)
 111d1b0:	movzwl -0x858(%rbp,%rbx,2),%ecx
 111d1b8:	incw   -0x2760(%rbp,%rcx,2)
 111d1c0:	movzwl -0x856(%rbp,%rbx,2),%ecx
 111d1c8:	incw   -0x2760(%rbp,%rcx,2)
 111d1d0:	movzwl -0x854(%rbp,%rbx,2),%ecx
 111d1d8:	incw   -0x2760(%rbp,%rcx,2)
 111d1e0:	movzwl -0x852(%rbp,%rbx,2),%ecx
 111d1e8:	incw   -0x2760(%rbp,%rcx,2)
 111d1f0:	add    $0x8,%rbx
 111d1f4:	cmp    %rbx,%r14
 111d1f7:	jne    111d170 <huffman.treeCodeLengthsKnownActive__anon_38967+0xf10>
 111d1fd:	test   %rax,%rax
 111d200:	mov    -0x38(%rbp),%r13
 111d204:	je     111d234 <huffman.treeCodeLengthsKnownActive__anon_38967+0xfd4>
 111d206:	lea    -0x860(,%rbx,2),%rcx
 111d20e:	add    %rbp,%rcx
 111d211:	xor    %edx,%edx
 111d213:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 111d220:	movzwl (%rcx,%rdx,2),%esi
 111d224:	incw   -0x2760(%rbp,%rsi,2)
 111d22c:	inc    %rdx
 111d22f:	cmp    %rdx,%rax
 111d232:	jne    111d220 <huffman.treeCodeLengthsKnownActive__anon_38967+0xfc0>
 111d234:	cmp    %r13,%r15
 111d237:	jbe    111d28d <huffman.treeCodeLengthsKnownActive__anon_38967+0x102d>
 111d239:	mov    %r15d,%edx
 111d23c:	sub    %r13d,%edx
 111d23f:	lea    0x1(%r13),%rcx
 111d243:	mov    %r15,%rax
 111d246:	test   $0x1,%dl
 111d249:	je     111d284 <huffman.treeCodeLengthsKnownActive__anon_38967+0x1024>
 111d24b:	lea    -0x1(%r15),%rax
 111d24f:	movzwl -0x2762(%rbp,%r15,2),%edx
 111d258:	test   %dx,%dx
 111d25b:	je     111d284 <huffman.treeCodeLengthsKnownActive__anon_38967+0x1024>
 111d25d:	mov    %rax,%rsi
 111d260:	shl    $0x4,%rsi
 111d264:	movzwl -0x11f58(%rbp,%rsi,1),%edi
 111d26c:	movzwl -0x11f56(%rbp,%rsi,1),%esi
 111d274:	add    %dx,-0x2760(%rbp,%rdi,2)
 111d27c:	add    %dx,-0x2760(%rbp,%rsi,2)
 111d284:	cmp    %rcx,%r15
 111d287:	jne    111d466 <huffman.treeCodeLengthsKnownActive__anon_38967+0x1206>
 111d28d:	lea    -0x1(%r13),%rcx
 111d291:	mov    %r13d,%eax
 111d294:	and    $0x7,%eax
 111d297:	cmp    $0x7,%rcx
 111d29b:	jae    111d2a4 <huffman.treeCodeLengthsKnownActive__anon_38967+0x1044>
 111d29d:	xor    %ecx,%ecx
 111d29f:	jmp    111d391 <huffman.treeCodeLengthsKnownActive__anon_38967+0x1131>
 111d2a4:	and    $0x78,%r13d
 111d2a8:	lea    -0x11ee4(%rbp),%rdx
 111d2af:	xor    %ecx,%ecx
 111d2b1:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 111d2c0:	movzwl -0x70(%rdx),%esi
 111d2c4:	movzbl -0x2760(%rbp,%rcx,2),%edi
 111d2cc:	movzbl -0x275e(%rbp,%rcx,2),%r8d
 111d2d5:	and    $0xf,%dil
 111d2d9:	mov    %dil,-0x360(%rbp,%rsi,1)
 111d2e1:	movzwl -0x60(%rdx),%esi
 111d2e5:	and    $0xf,%r8b
 111d2e9:	mov    %r8b,-0x360(%rbp,%rsi,1)
 111d2f1:	movzwl -0x50(%rdx),%esi
 111d2f5:	movzbl -0x275c(%rbp,%rcx,2),%edi
 111d2fd:	and    $0xf,%dil
 111d301:	mov    %dil,-0x360(%rbp,%rsi,1)
 111d309:	movzwl -0x40(%rdx),%esi
 111d30d:	movzbl -0x275a(%rbp,%rcx,2),%edi
 111d315:	and    $0xf,%dil
 111d319:	mov    %dil,-0x360(%rbp,%rsi,1)
 111d321:	movzwl -0x30(%rdx),%esi
 111d325:	movzbl -0x2758(%rbp,%rcx,2),%edi
 111d32d:	and    $0xf,%dil
 111d331:	mov    %dil,-0x360(%rbp,%rsi,1)
 111d339:	movzwl -0x20(%rdx),%esi
 111d33d:	movzbl -0x2756(%rbp,%rcx,2),%edi
 111d345:	and    $0xf,%dil
 111d349:	mov    %dil,-0x360(%rbp,%rsi,1)
 111d351:	movzwl -0x10(%rdx),%esi
 111d355:	movzbl -0x2754(%rbp,%rcx,2),%edi
 111d35d:	and    $0xf,%dil
 111d361:	mov    %dil,-0x360(%rbp,%rsi,1)
 111d369:	movzwl (%rdx),%esi
 111d36c:	movzbl -0x2752(%rbp,%rcx,2),%edi
 111d374:	and    $0xf,%dil
 111d378:	mov    %dil,-0x360(%rbp,%rsi,1)
 111d380:	add    $0x8,%rcx
 111d384:	sub    $0xffffffffffffff80,%rdx
 111d388:	cmp    %rcx,%r13
 111d38b:	jne    111d2c0 <huffman.treeCodeLengthsKnownActive__anon_38967+0x1060>
 111d391:	test   %rax,%rax
 111d394:	je     111d3de <huffman.treeCodeLengthsKnownActive__anon_38967+0x117e>
 111d396:	lea    -0x2760(,%rcx,2),%rdx
 111d39e:	add    %rbp,%rdx
 111d3a1:	shl    $0x4,%rcx
 111d3a5:	lea    -0x11f60(%rbp),%rsi
 111d3ac:	add    %rsi,%rcx
 111d3af:	add    $0xc,%rcx
 111d3b3:	add    %eax,%eax
 111d3b5:	xor    %esi,%esi
 111d3b7:	nopw   0x0(%rax,%rax,1)
 111d3c0:	movzwl (%rcx,%rsi,8),%edi
 111d3c4:	movzbl (%rdx,%rsi,1),%r8d
 111d3c9:	and    $0xf,%r8b
 111d3cd:	mov    %r8b,-0x360(%rbp,%rdi,1)
 111d3d5:	add    $0x2,%rsi
 111d3d9:	cmp    %rsi,%rax
 111d3dc:	jne    111d3c0 <huffman.treeCodeLengthsKnownActive__anon_38967+0x1160>
 111d3de:	vmovups -0x280(%rbp),%ymm0
 111d3e6:	vmovups %ymm0,0xe0(%r12)
 111d3f0:	vmovups -0x2a0(%rbp),%ymm0
 111d3f8:	vmovups %ymm0,0xc0(%r12)
 111d402:	vmovups -0x2c0(%rbp),%ymm0
 111d40a:	vmovups %ymm0,0xa0(%r12)
 111d414:	vmovups -0x2e0(%rbp),%ymm0
 111d41c:	vmovups %ymm0,0x80(%r12)
 111d426:	vmovups -0x360(%rbp),%ymm0
 111d42e:	vmovups -0x340(%rbp),%ymm1
 111d436:	vmovups -0x320(%rbp),%ymm2
 111d43e:	vmovups -0x300(%rbp),%ymm3
 111d446:	vmovups %ymm3,0x60(%r12)
 111d44d:	vmovups %ymm2,0x40(%r12)
 111d454:	vmovups %ymm1,0x20(%r12)
 111d45b:	vmovups %ymm0,(%r12)
 111d461:	jmp    111d0d1 <huffman.treeCodeLengthsKnownActive__anon_38967+0xe71>
 111d466:	mov    %rax,%rcx
 111d469:	shl    $0x4,%rcx
 111d46d:	lea    -0x11f60(%rbp),%rdx
 111d474:	add    %rdx,%rcx
 111d477:	add    $0xfffffffffffffffa,%rcx
 111d47b:	jmp    111d491 <huffman.treeCodeLengthsKnownActive__anon_38967+0x1231>
 111d47d:	nopl   (%rax)
 111d480:	add    $0xfffffffffffffffe,%rax
 111d484:	add    $0xffffffffffffffe0,%rcx
 111d488:	cmp    %r13,%rax
 111d48b:	jbe    111d28d <huffman.treeCodeLengthsKnownActive__anon_38967+0x102d>
 111d491:	movzwl -0x2762(%rbp,%rax,2),%edx
 111d499:	test   %dx,%dx
 111d49c:	je     111d4b5 <huffman.treeCodeLengthsKnownActive__anon_38967+0x1255>
 111d49e:	movzwl -0x2(%rcx),%esi
 111d4a2:	movzwl (%rcx),%edi
 111d4a5:	add    %dx,-0x2760(%rbp,%rsi,2)
 111d4ad:	add    %dx,-0x2760(%rbp,%rdi,2)
 111d4b5:	movzwl -0x2764(%rbp,%rax,2),%edx
 111d4bd:	test   %dx,%dx
 111d4c0:	je     111d480 <huffman.treeCodeLengthsKnownActive__anon_38967+0x1220>
 111d4c2:	movzwl -0x12(%rcx),%esi
 111d4c6:	movzwl -0x10(%rcx),%edi
 111d4ca:	add    %dx,-0x2760(%rbp,%rsi,2)
 111d4d2:	add    %dx,-0x2760(%rbp,%rdi,2)
 111d4da:	jmp    111d480 <huffman.treeCodeLengthsKnownActive__anon_38967+0x1220>

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
