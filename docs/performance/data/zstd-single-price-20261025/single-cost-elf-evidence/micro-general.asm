
/tmp/vort-zstd-single-price-20261025/micro-bench:     file format elf64-x86-64


Disassembly of section .text:

00000000010bd320 <single_cost_bench.query__anon_2964>:
 10bd320:	push   %rbp
 10bd321:	mov    %rsp,%rbp
 10bd324:	push   %r15
 10bd326:	push   %r14
 10bd328:	push   %r13
 10bd32a:	push   %r12
 10bd32c:	push   %rbx
 10bd32d:	sub    $0x6c8,%rsp
 10bd334:	mov    %rdi,-0x68(%rbp)
 10bd338:	mov    (%rsi),%r14
 10bd33b:	mov    0x8(%rsi),%r15
 10bd33f:	mov    0x10(%rsi),%r12
 10bd343:	lea    -0x48(%rbp),%rdi
 10bd347:	mov    $0x10157b0,%edx
 10bd34c:	mov    $0x24,%ecx
 10bd351:	mov    $0x1014be0,%r8d
 10bd357:	mov    %r14,%rsi
 10bd35a:	call   10bd6f0 <zstd.sequenceCodeForValue>
 10bd35f:	movzwl -0x48(%rbp),%eax
 10bd363:	test   %ax,%ax
 10bd366:	jne    10bd4e6 <single_cost_bench.query__anon_2964+0x1c6>
 10bd36c:	movzbl -0x46(%rbp),%r13d
 10bd371:	lea    -0x50(%rbp),%rdi
 10bd375:	mov    $0x1015508,%edx
 10bd37a:	mov    $0x20,%ecx
 10bd37f:	mov    $0x1000860,%r8d
 10bd385:	mov    %r15,%rsi
 10bd388:	call   10bd6f0 <zstd.sequenceCodeForValue>
 10bd38d:	movzwl -0x50(%rbp),%eax
 10bd391:	test   %ax,%ax
 10bd394:	jne    10bd4e6 <single_cost_bench.query__anon_2964+0x1c6>
 10bd39a:	movzbl -0x4e(%rbp),%ebx
 10bd39e:	lea    -0x58(%rbp),%rdi
 10bd3a2:	mov    $0x1015608,%edx
 10bd3a7:	mov    $0x35,%ecx
 10bd3ac:	mov    $0x1014c04,%r8d
 10bd3b2:	mov    %r12,%rsi
 10bd3b5:	call   10bd6f0 <zstd.sequenceCodeForValue>
 10bd3ba:	movzwl -0x58(%rbp),%eax
 10bd3be:	test   %ax,%ax
 10bd3c1:	jne    10bd4e6 <single_cost_bench.query__anon_2964+0x1c6>
 10bd3c7:	movzbl -0x56(%rbp),%eax
 10bd3cb:	mov    %rax,-0x38(%rbp)
 10bd3cf:	lea    -0x290(%rbp),%rdi
 10bd3d6:	mov    $0x10157b0,%edx
 10bd3db:	mov    $0x24,%ecx
 10bd3e0:	mov    $0x1014be0,%r8d
 10bd3e6:	mov    %r14,%rsi
 10bd3e9:	call   10bd6f0 <zstd.sequenceCodeForValue>
 10bd3ee:	movzwl -0x290(%rbp),%eax
 10bd3f5:	test   %ax,%ax
 10bd3f8:	jne    10bd4e6 <single_cost_bench.query__anon_2964+0x1c6>
 10bd3fe:	cmp    %r13b,-0x28e(%rbp)
 10bd405:	jne    10bd4e2 <single_cost_bench.query__anon_2964+0x1c2>
 10bd40b:	lea    -0x4a8(%rbp),%rdi
 10bd412:	mov    $0x1015508,%edx
 10bd417:	mov    $0x20,%ecx
 10bd41c:	mov    $0x1000860,%r8d
 10bd422:	mov    %r15,%rsi
 10bd425:	call   10bd6f0 <zstd.sequenceCodeForValue>
 10bd42a:	movzwl -0x4a8(%rbp),%eax
 10bd431:	test   %ax,%ax
 10bd434:	jne    10bd4e6 <single_cost_bench.query__anon_2964+0x1c6>
 10bd43a:	cmp    %bl,-0x4a6(%rbp)
 10bd440:	jne    10bd4e2 <single_cost_bench.query__anon_2964+0x1c2>
 10bd446:	lea    -0x6c0(%rbp),%rdi
 10bd44d:	mov    $0x1015608,%edx
 10bd452:	mov    $0x35,%ecx
 10bd457:	mov    $0x1014c04,%r8d
 10bd45d:	mov    %r12,%rsi
 10bd460:	call   10bd6f0 <zstd.sequenceCodeForValue>
 10bd465:	movzwl -0x6c0(%rbp),%eax
 10bd46c:	test   %ax,%ax
 10bd46f:	jne    10bd4e6 <single_cost_bench.query__anon_2964+0x1c6>
 10bd471:	mov    $0x3c,%ax
 10bd475:	mov    -0x38(%rbp),%rcx
 10bd479:	cmp    %cl,-0x6be(%rbp)
 10bd47f:	jne    10bd4e6 <single_cost_bench.query__anon_2964+0x1c6>
 10bd481:	mov    $0x3f,%ax
 10bd485:	xor    %ecx,%ecx
 10bd487:	test   %cl,%cl
 10bd489:	jne    10bd4e6 <single_cost_bench.query__anon_2964+0x1c6>
 10bd48b:	xor    %ecx,%ecx
 10bd48d:	test   %cl,%cl
 10bd48f:	jne    10bd4e6 <single_cost_bench.query__anon_2964+0x1c6>
 10bd491:	movzbl 0x1014be0(%r13),%esi
 10bd499:	mov    -0x38(%rbp),%rcx
 10bd49d:	movzbl 0x1014c04(%rcx),%ecx
 10bd4a4:	movzbl 0x1000860(%rbx),%edx
 10bd4ab:	movb   $0x0,-0x30(%rbp)
 10bd4af:	xor    %edi,%edi
 10bd4b1:	test   %dil,%dil
 10bd4b4:	jne    10bd4e6 <single_cost_bench.query__anon_2964+0x1c6>
 10bd4b6:	xor    %edi,%edi
 10bd4b8:	test   %dil,%dil
 10bd4bb:	jne    10bd4e6 <single_cost_bench.query__anon_2964+0x1c6>
 10bd4bd:	xor    %edi,%edi
 10bd4bf:	test   %dil,%dil
 10bd4c2:	jne    10bd4e6 <single_cost_bench.query__anon_2964+0x1c6>
 10bd4c4:	movb   $0x0,-0x30(%rbp)
 10bd4c8:	xor    %edi,%edi
 10bd4ca:	test   %dil,%dil
 10bd4cd:	jne    10bd4e6 <single_cost_bench.query__anon_2964+0x1c6>
 10bd4cf:	add    %esi,%ecx
 10bd4d1:	lea    (%rdx,%rcx,1),%ebx
 10bd4d4:	add    $0x8,%ebx
 10bd4d7:	shr    $0x3,%ebx
 10bd4da:	add    $0x5,%rbx
 10bd4de:	xor    %ecx,%ecx
 10bd4e0:	jmp    10bd4f2 <single_cost_bench.query__anon_2964+0x1d2>
 10bd4e2:	mov    $0x3c,%ax
 10bd4e6:	mov    $0x1,%cl
 10bd4e8:	cmp    $0x3c,%ax
 10bd4ec:	jne    10bd6c5 <single_cost_bench.query__anon_2964+0x3a5>
 10bd4f2:	mov    %ecx,-0x38(%rbp)
 10bd4f5:	lea    -0x6e(%rbp),%r13
 10bd4f9:	mov    %r14,-0x48(%rbp)
 10bd4fd:	mov    %r15,-0x50(%rbp)
 10bd501:	mov    %r12,-0x58(%rbp)
 10bd505:	lea    -0x290(%rbp),%rdi
 10bd50c:	lea    -0x48(%rbp),%rsi
 10bd510:	mov    $0x1014c3c,%edx
 10bd515:	mov    $0x40,%ecx
 10bd51a:	xor    %r8d,%r8d
 10bd51d:	call   10bda00 <zstd.planPredefinedSequenceValues>
 10bd522:	movzwl -0x80(%rbp),%eax
 10bd526:	test   %ax,%ax
 10bd529:	jne    10bd68b <single_cost_bench.query__anon_2964+0x36b>
 10bd52f:	cmpb   $0x0,-0x88(%rbp)
 10bd536:	je     10bd678 <single_cost_bench.query__anon_2964+0x358>
 10bd53c:	mov    -0x290(%rbp),%r14
 10bd543:	movzbl -0x288(%rbp),%r15d
 10bd54b:	lea    -0x4a8(%rbp),%rdi
 10bd552:	lea    -0x50(%rbp),%rsi
 10bd556:	mov    $0x1014e3c,%edx
 10bd55b:	mov    $0x20,%ecx
 10bd560:	mov    $0x2,%r8d
 10bd566:	call   10bda00 <zstd.planPredefinedSequenceValues>
 10bd56b:	movzwl -0x298(%rbp),%eax
 10bd572:	test   %ax,%ax
 10bd575:	jne    10bd68b <single_cost_bench.query__anon_2964+0x36b>
 10bd57b:	cmpb   $0x0,-0x2a0(%rbp)
 10bd582:	je     10bd678 <single_cost_bench.query__anon_2964+0x358>
 10bd588:	mov    -0x4a8(%rbp),%r12
 10bd58f:	movzbl -0x4a0(%rbp),%eax
 10bd596:	mov    %rax,-0x60(%rbp)
 10bd59a:	lea    -0x6c0(%rbp),%rdi
 10bd5a1:	lea    -0x58(%rbp),%rsi
 10bd5a5:	mov    $0x1014f3c,%edx
 10bd5aa:	mov    $0x40,%ecx
 10bd5af:	xor    %r8d,%r8d
 10bd5b2:	call   10bda00 <zstd.planPredefinedSequenceValues>
 10bd5b7:	movzwl -0x4b0(%rbp),%eax
 10bd5be:	test   %ax,%ax
 10bd5c1:	jne    10bd68b <single_cost_bench.query__anon_2964+0x36b>
 10bd5c7:	cmpb   $0x0,-0x4b8(%rbp)
 10bd5ce:	je     10bd678 <single_cost_bench.query__anon_2964+0x358>
 10bd5d4:	cmp    $0x1,%r14
 10bd5d8:	jne    10bd678 <single_cost_bench.query__anon_2964+0x358>
 10bd5de:	cmp    $0x1,%r12
 10bd5e2:	jne    10bd678 <single_cost_bench.query__anon_2964+0x358>
 10bd5e8:	cmp    -0x6c0(%rbp),%r14
 10bd5ef:	jne    10bd678 <single_cost_bench.query__anon_2964+0x358>
 10bd5f5:	xor    %eax,%eax
 10bd5f7:	test   %al,%al
 10bd5f9:	jne    10bd672 <single_cost_bench.query__anon_2964+0x352>
 10bd5fb:	xor    %eax,%eax
 10bd5fd:	test   %al,%al
 10bd5ff:	jne    10bd672 <single_cost_bench.query__anon_2964+0x352>
 10bd601:	movzbl -0x6b8(%rbp),%eax
 10bd608:	movzbl 0x1014c42(,%r15,8),%edx
 10bd611:	movzbl 0x1014f42(,%rax,8),%eax
 10bd619:	mov    -0x60(%rbp),%rcx
 10bd61d:	movzbl 0x1014e42(,%rcx,8),%ecx
 10bd625:	movb   $0x0,-0x30(%rbp)
 10bd629:	xor    %esi,%esi
 10bd62b:	test   %sil,%sil
 10bd62e:	jne    10bd672 <single_cost_bench.query__anon_2964+0x352>
 10bd630:	movb   $0x0,-0x30(%rbp)
 10bd634:	xor    %esi,%esi
 10bd636:	test   %sil,%sil
 10bd639:	jne    10bd672 <single_cost_bench.query__anon_2964+0x352>
 10bd63b:	movb   $0x0,-0x30(%rbp)
 10bd63f:	xor    %esi,%esi
 10bd641:	test   %sil,%sil
 10bd644:	jne    10bd672 <single_cost_bench.query__anon_2964+0x352>
 10bd646:	movb   $0x0,-0x30(%rbp)
 10bd64a:	xor    %esi,%esi
 10bd64c:	test   %sil,%sil
 10bd64f:	jne    10bd672 <single_cost_bench.query__anon_2964+0x352>
 10bd651:	movb   $0x0,-0x30(%rbp)
 10bd655:	xor    %esi,%esi
 10bd657:	test   %sil,%sil
 10bd65a:	jne    10bd672 <single_cost_bench.query__anon_2964+0x352>
 10bd65c:	movb   $0x0,-0x30(%rbp)
 10bd660:	xor    %esi,%esi
 10bd662:	test   %sil,%sil
 10bd665:	jne    10bd672 <single_cost_bench.query__anon_2964+0x352>
 10bd667:	movb   $0x0,-0x30(%rbp)
 10bd66b:	xor    %esi,%esi
 10bd66d:	test   %sil,%sil
 10bd670:	je     10bd696 <single_cost_bench.query__anon_2964+0x376>
 10bd672:	mov    $0x3f,%ax
 10bd676:	jmp    10bd6c5 <single_cost_bench.query__anon_2964+0x3a5>
 10bd678:	mov    -0x38(%rbp),%ecx
 10bd67b:	test   %cl,%cl
 10bd67d:	je     10bd6b3 <single_cost_bench.query__anon_2964+0x393>
 10bd67f:	mov    $0x10005aa,%r13d
 10bd685:	mov    $0x3c,%ax
 10bd689:	jmp    10bd6b5 <single_cost_bench.query__anon_2964+0x395>
 10bd68b:	cmp    $0x3c,%ax
 10bd68f:	mov    -0x38(%rbp),%ecx
 10bd692:	je     10bd67b <single_cost_bench.query__anon_2964+0x35b>
 10bd694:	jmp    10bd6c5 <single_cost_bench.query__anon_2964+0x3a5>
 10bd696:	add    %edx,%eax
 10bd698:	add    %ecx,%eax
 10bd69a:	add    $0x19,%eax
 10bd69d:	shr    $0x3,%eax
 10bd6a0:	add    $0x2,%rax
 10bd6a4:	cmp    %rbx,%rax
 10bd6a7:	cmovb  %rax,%rbx
 10bd6ab:	cmpb   $0x0,-0x38(%rbp)
 10bd6af:	cmovne %rax,%rbx
 10bd6b3:	xor    %eax,%eax
 10bd6b5:	movzwl 0x4(%r13),%ecx
 10bd6ba:	mov    %cx,-0x3c(%rbp)
 10bd6be:	mov    0x0(%r13),%ecx
 10bd6c2:	mov    %ecx,-0x40(%rbp)
 10bd6c5:	mov    -0x68(%rbp),%rcx
 10bd6c9:	mov    %rbx,(%rcx)
 10bd6cc:	mov    %ax,0x8(%rcx)
 10bd6d0:	mov    -0x40(%rbp),%eax
 10bd6d3:	mov    %eax,0xa(%rcx)
 10bd6d6:	movzwl -0x3c(%rbp),%eax
 10bd6da:	mov    %ax,0xe(%rcx)
 10bd6de:	add    $0x6c8,%rsp
 10bd6e5:	pop    %rbx
 10bd6e6:	pop    %r12
 10bd6e8:	pop    %r13
 10bd6ea:	pop    %r14
 10bd6ec:	pop    %r15
 10bd6ee:	pop    %rbp
 10bd6ef:	ret    
