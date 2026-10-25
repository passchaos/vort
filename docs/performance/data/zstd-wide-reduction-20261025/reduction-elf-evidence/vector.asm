
/tmp/vort-zstd-wide-reduction-20261025/kernel-bench:     file format elf64-x86-64


Disassembly of section .text:

00000000010bc380 <weighted_bound_bench.query__anon_2995>:
 10bc380:	vpxor  %xmm0,%xmm0,%xmm0
 10bc384:	mov    $0xfffffffffffffff8,%rcx
 10bc38b:	xor    %eax,%eax
 10bc38d:	vpxor  %xmm3,%xmm3,%xmm3
 10bc391:	vpxor  %xmm4,%xmm4,%xmm4
 10bc395:	vpxor  %xmm1,%xmm1,%xmm1
 10bc399:	vpxor  %xmm2,%xmm2,%xmm2
 10bc39d:	xor    %r9d,%r9d
 10bc3a0:	vpmovzxdq 0x30(%rdx,%rcx,4),%ymm5
 10bc3a7:	vpaddq %ymm5,%ymm4,%ymm4
 10bc3ab:	vpmovzxdq 0x20(%rdx,%rcx,4),%ymm5
 10bc3b2:	vpaddq %ymm5,%ymm3,%ymm3
 10bc3b6:	vmovdqu 0x20(%rdx,%rcx,4),%ymm7
 10bc3bc:	vmovdqu 0x40(%rdx,%rcx,4),%ymm5
 10bc3c2:	vmovdqu 0x30(%rsi,%rcx,4),%ymm8
 10bc3c8:	vmovdqu 0x50(%rsi,%rcx,4),%ymm6
 10bc3ce:	vpmaxud %ymm7,%ymm8,%ymm9
 10bc3d3:	vpsubd %ymm7,%ymm9,%ymm9
 10bc3d7:	vextracti128 $0x1,%ymm9,%xmm10
 10bc3dd:	vpmovzxdq %xmm10,%ymm10
 10bc3e2:	vpaddq %ymm2,%ymm10,%ymm2
 10bc3e6:	vpmovzxdq %xmm9,%ymm9
 10bc3eb:	vpaddq %ymm1,%ymm9,%ymm1
 10bc3ef:	vpcmpeqd %ymm0,%ymm8,%ymm8
 10bc3f3:	vpcmpeqd %ymm0,%ymm7,%ymm7
 10bc3f7:	vpxor  %ymm7,%ymm8,%ymm8
 10bc3fb:	vmovmskps %ymm8,%r8d
 10bc400:	or     %r9b,%r8b
 10bc403:	vmovmskps %ymm7,%r9d
 10bc407:	xor    $0xff,%r9d
 10bc40e:	xor    %r10d,%r10d
 10bc411:	popcnt %r9d,%r10d
 10bc416:	add    %rax,%r10
 10bc419:	vpmovzxdq 0x40(%rdx,%rcx,4),%ymm7
 10bc420:	vpaddq %ymm7,%ymm3,%ymm3
 10bc424:	vpmovzxdq 0x50(%rdx,%rcx,4),%ymm7
 10bc42b:	vpaddq %ymm7,%ymm4,%ymm4
 10bc42f:	vpmaxud %ymm5,%ymm6,%ymm7
 10bc434:	vpsubd %ymm5,%ymm7,%ymm7
 10bc438:	vpmovzxdq %xmm7,%ymm8
 10bc43d:	vpaddq %ymm1,%ymm8,%ymm1
 10bc441:	vextracti128 $0x1,%ymm7,%xmm7
 10bc447:	vpmovzxdq %xmm7,%ymm7
 10bc44c:	vpaddq %ymm7,%ymm2,%ymm2
 10bc450:	vpcmpeqd %ymm0,%ymm6,%ymm6
 10bc454:	vpcmpeqd %ymm0,%ymm5,%ymm5
 10bc458:	vpxor  %ymm6,%ymm5,%ymm6
 10bc45c:	vmovmskps %ymm6,%r9d
 10bc460:	or     %r8b,%r9b
 10bc463:	vmovmskps %ymm5,%eax
 10bc467:	xor    $0xff,%eax
 10bc46c:	popcnt %eax,%eax
 10bc470:	add    %r10,%rax
 10bc473:	add    $0x10,%rcx
 10bc477:	cmp    $0xf8,%rcx
 10bc47e:	jb     10bc3a0 <weighted_bound_bench.query__anon_2995+0x20>
 10bc484:	push   %rbp
 10bc485:	mov    %rsp,%rbp
 10bc488:	vpaddq %ymm4,%ymm3,%ymm0
 10bc48c:	vextracti128 $0x1,%ymm0,%xmm3
 10bc492:	vpaddq %xmm3,%xmm0,%xmm0
 10bc496:	vpshufd $0xee,%xmm0,%xmm3
 10bc49b:	vpaddq %xmm3,%xmm0,%xmm0
 10bc49f:	vmovq  %xmm0,%rcx
 10bc4a4:	mov    $0x38,%r8w
 10bc4a9:	cmp    $0x20000,%rcx
 10bc4b0:	ja     10bc4e3 <weighted_bound_bench.query__anon_2995+0x163>
 10bc4b2:	vpaddq %ymm2,%ymm1,%ymm0
 10bc4b6:	vextracti128 $0x1,%ymm0,%xmm1
 10bc4bc:	vpaddq %xmm1,%xmm0,%xmm0
 10bc4c0:	vpshufd $0xee,%xmm0,%xmm1
 10bc4c5:	vpaddq %xmm1,%xmm0,%xmm0
 10bc4c9:	vmovq  %xmm0,%rdx
 10bc4ce:	test   %r9b,%r9b
 10bc4d1:	sete   -0x8(%rbp)
 10bc4d5:	mov    %rdx,%r8
 10bc4d8:	shr    $0x20,%r8
 10bc4dc:	mov    $0x3a,%r8w
 10bc4e1:	je     10bc52a <weighted_bound_bench.query__anon_2995+0x1aa>
 10bc4e3:	mov    %rax,(%rdi)
 10bc4e6:	mov    %r9,0x8(%rdi)
 10bc4ea:	mov    %r10b,0x10(%rdi)
 10bc4ee:	mov    -0x18(%rbp),%eax
 10bc4f1:	mov    -0x15(%rbp),%r9d
 10bc4f5:	mov    %eax,0x11(%rdi)
 10bc4f8:	mov    %r9d,0x14(%rdi)
 10bc4fc:	mov    %ecx,0x18(%rdi)
 10bc4ff:	mov    %edx,0x1c(%rdi)
 10bc502:	mov    %sil,0x20(%rdi)
 10bc506:	mov    -0x28(%rbp),%eax
 10bc509:	mov    -0x25(%rbp),%ecx
 10bc50c:	mov    %eax,0x21(%rdi)
 10bc50f:	mov    %ecx,0x24(%rdi)
 10bc512:	mov    %r8w,0x28(%rdi)
 10bc517:	mov    -0x20(%rbp),%eax
 10bc51a:	mov    %eax,0x2a(%rdi)
 10bc51d:	movzwl -0x1c(%rbp),%eax
 10bc521:	mov    %ax,0x2e(%rdi)
 10bc525:	pop    %rbp
 10bc526:	vzeroupper 
 10bc529:	ret    
 10bc52a:	movzbl -0x8(%rbp),%r8d
 10bc52f:	and    $0x1,%r8b
 10bc533:	mov    %r8b,-0x10(%rbp)
 10bc537:	je     10bc55a <weighted_bound_bench.query__anon_2995+0x1da>
 10bc539:	mov    0x8(%rsi),%r9
 10bc53d:	test   %r9,%r9
 10bc540:	js     10bc54a <weighted_bound_bench.query__anon_2995+0x1ca>
 10bc542:	xor    %r8d,%r8d
 10bc545:	test   %r8b,%r8b
 10bc548:	je     10bc577 <weighted_bound_bench.query__anon_2995+0x1f7>
 10bc54a:	movl   $0x0,-0x15(%rbp)
 10bc551:	movl   $0x0,-0x18(%rbp)
 10bc558:	jmp    10bc5ad <weighted_bound_bench.query__anon_2995+0x22d>
 10bc55a:	movzbl -0x10(%rbp),%esi
 10bc55e:	movl   $0x0,-0x18(%rbp)
 10bc565:	movl   $0x0,-0x15(%rbp)
 10bc56c:	xor    %r10d,%r10d
 10bc56f:	xor    %r8d,%r8d
 10bc572:	jmp    10bc4e3 <weighted_bound_bench.query__anon_2995+0x163>
 10bc577:	mov    0x410(%rsi),%esi
 10bc57d:	mov    %rcx,%r8
 10bc580:	sub    %rsi,%r8
 10bc583:	add    %r8,%r9
 10bc586:	seto   -0x8(%rbp)
 10bc58a:	jo     10bc59f <weighted_bound_bench.query__anon_2995+0x21f>
 10bc58c:	mov    %rdx,%rsi
 10bc58f:	add    %rdx,%rsi
 10bc592:	lea    (%rsi,%rsi,4),%rsi
 10bc596:	sub    %rsi,%r9
 10bc599:	seto   -0x8(%rbp)
 10bc59d:	jno    10bc5d4 <weighted_bound_bench.query__anon_2995+0x254>
 10bc59f:	movl   $0x0,-0x18(%rbp)
 10bc5a6:	movl   $0x0,-0x15(%rbp)
 10bc5ad:	movl   $0x0,-0x28(%rbp)
 10bc5b4:	movl   $0x0,-0x25(%rbp)
 10bc5bb:	movl   $0x0,-0x20(%rbp)
 10bc5c2:	movw   $0x0,-0x1c(%rbp)
 10bc5c8:	mov    $0x3a,%r8w
 10bc5cd:	xor    %esi,%esi
 10bc5cf:	jmp    10bc4e3 <weighted_bound_bench.query__anon_2995+0x163>
 10bc5d4:	cmp    %r9,%rcx
 10bc5d7:	cmovg  %rcx,%r9
 10bc5db:	movzbl -0x10(%rbp),%esi
 10bc5df:	movl   $0x0,-0x18(%rbp)
 10bc5e6:	movl   $0x0,-0x15(%rbp)
 10bc5ed:	mov    $0x1,%r10b
 10bc5f0:	jmp    10bc56f <weighted_bound_bench.query__anon_2995+0x1ef>
