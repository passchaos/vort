
/home/passchaos/project-z/vort-zstd-duplicate-profile/.zig-cache/o/e896d85b31c33819f34a4488826cd334/vort-zstd-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000111d340 <sort.block.block__anon_39129>:
 111d340:	push   %rbp
 111d341:	mov    %rsp,%rbp
 111d344:	push   %r15
 111d346:	push   %r14
 111d348:	push   %r13
 111d34a:	push   %r12
 111d34c:	push   %rbx
 111d34d:	sub    $0x628,%rsp
 111d354:	mov    %rdx,-0x30(%rbp)
 111d358:	cmp    $0x3,%rsi
 111d35c:	mov    %rdi,-0x38(%rbp)
 111d360:	ja     111d3ca <sort.block.block__anon_39129+0x8a>
 111d362:	cmp    $0x2,%rsi
 111d366:	je     1126872 <sort.block.block__anon_39129+0x9532>
 111d36c:	cmp    $0x3,%rsi
 111d370:	jne    112698d <sort.block.block__anon_39129+0x964d>
 111d376:	movzwl 0x2(%rdi),%ecx
 111d37a:	movzwl (%rdi),%r8d
 111d37e:	mov    -0x30(%rbp),%rax
 111d382:	mov    (%rax),%rdx
 111d385:	mov    %ecx,%r9d
 111d388:	shl    $0x4,%r9d
 111d38c:	mov    (%rdx,%r9,1),%rdi
 111d390:	mov    %r8d,%r10d
 111d393:	shl    $0x4,%r10d
 111d397:	mov    (%rdx,%r10,1),%r11
 111d39b:	mov    %ecx,%eax
 111d39d:	shr    $0x8,%eax
 111d3a0:	mov    %ecx,%esi
 111d3a2:	cmp    %r11,%rdi
 111d3a5:	jne    11268c9 <sort.block.block__anon_39129+0x9589>
 111d3ab:	add    %rdx,%r9
 111d3ae:	add    %rdx,%r10
 111d3b1:	movzwl 0xe(%r9),%r9d
 111d3b6:	cmp    0xe(%r10),%r9w
 111d3bb:	jb     11268cf <sort.block.block__anon_39129+0x958f>
 111d3c1:	mov    -0x38(%rbp),%r10
 111d3c5:	jmp    1126904 <sort.block.block__anon_39129+0x95c4>
 111d3ca:	lzcnt  %rsi,%rax
 111d3cf:	mov    $0x3d,%cl
 111d3d1:	sub    %al,%cl
 111d3d3:	not    %al
 111d3d5:	mov    $0x1,%edx
 111d3da:	shlx   %rax,%rdx,%rax
 111d3df:	shr    $0x2,%rax
 111d3e3:	shrx   %rcx,%rsi,%rdi
 111d3e8:	mov    %rax,-0x120(%rbp)
 111d3ef:	dec    %rax
 111d3f2:	and    %rsi,%rax
 111d3f5:	mov    %rax,-0xf8(%rbp)
 111d3fc:	xor    %eax,%eax
 111d3fe:	xor    %edx,%edx
 111d400:	mov    %rsi,-0x118(%rbp)
 111d407:	mov    %rdi,-0xb8(%rbp)
 111d40e:	jmp    111d455 <sort.block.block__anon_39129+0x115>
 111d410:	mov    %r9d,%ecx
 111d413:	shr    $0x8,%ecx
 111d416:	mov    %r9b,0x2(%r8)
 111d41a:	mov    %r14b,0x4(%r8)
 111d41e:	mov    $0x5,%edi
 111d423:	mov    $0x3,%r9d
 111d429:	mov    %cl,(%r8,%r9,1)
 111d42d:	mov    %r15b,(%r8,%rdi,1)
 111d431:	mov    -0xb8(%rbp),%rdi
 111d438:	add    %rdi,%rax
 111d43b:	sub    -0x98(%rbp),%rdx
 111d442:	add    %r13,%rax
 111d445:	mov    -0x118(%rbp),%rsi
 111d44c:	cmp    %rsi,%rax
 111d44f:	jae    111f02b <sort.block.block__anon_39129+0x1ceb>
 111d455:	add    -0xf8(%rbp),%rdx
 111d45c:	xor    %r13d,%r13d
 111d45f:	mov    -0x120(%rbp),%rcx
 111d466:	cmp    %rcx,%rdx
 111d469:	setae  %r13b
 111d46d:	mov    $0x0,%esi
 111d472:	cmovae %rcx,%rsi
 111d476:	mov    %rsi,-0x98(%rbp)
 111d47d:	lea    (%rdi,%r13,1),%rcx
 111d481:	add    $0xfffffffffffffffc,%rcx
 111d485:	cmp    $0x4,%rcx
 111d489:	ja     111d431 <sort.block.block__anon_39129+0xf1>
 111d48b:	mov    -0x38(%rbp),%rsi
 111d48f:	lea    (%rsi,%rax,2),%r8
 111d493:	lea    -0x113456(%rip),%rsi        # 100a044 <__anon_3623+0x763c>
 111d49a:	movslq (%rsi,%rcx,4),%rcx
 111d49e:	add    %rsi,%rcx
 111d4a1:	jmp    *%rcx
 111d4a3:	mov    -0x30(%rbp),%rcx
 111d4a7:	mov    (%rcx),%rcx
 111d4aa:	movzwl 0x2(%r8),%edi
 111d4af:	movzwl (%r8),%r9d
 111d4b3:	mov    %edi,%esi
 111d4b5:	shl    $0x4,%esi
 111d4b8:	mov    (%rcx,%rsi,1),%r11
 111d4bc:	mov    %r9d,%r10d
 111d4bf:	shl    $0x4,%r10d
 111d4c3:	mov    (%rcx,%r10,1),%rbx
 111d4c7:	cmp    %rbx,%r11
 111d4ca:	jne    111de8d <sort.block.block__anon_39129+0xb4d>
 111d4d0:	add    %rcx,%rsi
 111d4d3:	add    %rcx,%r10
 111d4d6:	movzwl 0xe(%rsi),%esi
 111d4da:	cmp    0xe(%r10),%si
 111d4df:	jb     111de93 <sort.block.block__anon_39129+0xb53>
 111d4e5:	mov    $0x1,%sil
 111d4e8:	mov    %esi,-0x48(%rbp)
 111d4eb:	xor    %r14d,%r14d
 111d4ee:	jmp    111debe <sort.block.block__anon_39129+0xb7e>
 111d4f3:	mov    -0x30(%rbp),%rcx
 111d4f7:	mov    (%rcx),%r10
 111d4fa:	movzwl 0x2(%r8),%ecx
 111d4ff:	movzwl (%r8),%edi
 111d503:	mov    %ecx,%esi
 111d505:	shl    $0x4,%esi
 111d508:	mov    (%r10,%rsi,1),%r11
 111d50c:	mov    %edi,%r9d
 111d50f:	shl    $0x4,%r9d
 111d513:	mov    (%r10,%r9,1),%rbx
 111d517:	cmp    %rbx,%r11
 111d51a:	jne    111d63c <sort.block.block__anon_39129+0x2fc>
 111d520:	add    %r10,%rsi
 111d523:	add    %r10,%r9
 111d526:	movzwl 0xe(%rsi),%esi
 111d52a:	cmp    0xe(%r9),%si
 111d52f:	jb     111d642 <sort.block.block__anon_39129+0x302>
 111d535:	mov    $0x1,%cl
 111d537:	mov    %ecx,-0x48(%rbp)
 111d53a:	movl   $0x0,-0x58(%rbp)
 111d541:	jmp    111d670 <sort.block.block__anon_39129+0x330>
 111d546:	mov    -0x30(%rbp),%rcx
 111d54a:	mov    (%rcx),%r10
 111d54d:	movzwl 0x4(%r8),%ecx
 111d552:	movzwl 0x2(%r8),%edi
 111d557:	mov    %ecx,%esi
 111d559:	shl    $0x4,%esi
 111d55c:	mov    (%r10,%rsi,1),%r11
 111d560:	mov    %edi,%r9d
 111d563:	shl    $0x4,%r9d
 111d567:	mov    (%r10,%r9,1),%rbx
 111d56b:	cmp    %rbx,%r11
 111d56e:	jne    111d9e0 <sort.block.block__anon_39129+0x6a0>
 111d574:	add    %r10,%rsi
 111d577:	add    %r10,%r9
 111d57a:	movzwl 0xe(%rsi),%esi
 111d57e:	cmp    0xe(%r9),%si
 111d583:	jb     111d9e6 <sort.block.block__anon_39129+0x6a6>
 111d589:	mov    $0x2,%r14b
 111d58c:	mov    $0x1,%r15b
 111d58f:	jmp    111da0f <sort.block.block__anon_39129+0x6cf>
 111d594:	mov    -0x30(%rbp),%rcx
 111d598:	mov    (%rcx),%r10
 111d59b:	movzwl 0x4(%r8),%ecx
 111d5a0:	movzwl 0x2(%r8),%edi
 111d5a5:	mov    %ecx,%esi
 111d5a7:	shl    $0x4,%esi
 111d5aa:	mov    (%r10,%rsi,1),%r11
 111d5ae:	mov    %edi,%r9d
 111d5b1:	shl    $0x4,%r9d
 111d5b5:	mov    (%r10,%r9,1),%rbx
 111d5b9:	cmp    %rbx,%r11
 111d5bc:	jne    111dbcc <sort.block.block__anon_39129+0x88c>
 111d5c2:	add    %r10,%rsi
 111d5c5:	add    %r10,%r9
 111d5c8:	movzwl 0xe(%rsi),%esi
 111d5cc:	cmp    0xe(%r9),%si
 111d5d1:	jb     111dbd2 <sort.block.block__anon_39129+0x892>
 111d5d7:	mov    $0x2,%cl
 111d5d9:	mov    %ecx,-0x48(%rbp)
 111d5dc:	movb   $0x1,-0x80(%rbp)
 111d5e0:	jmp    111dbfe <sort.block.block__anon_39129+0x8be>
 111d5e5:	mov    -0x30(%rbp),%rcx
 111d5e9:	mov    (%rcx),%r10
 111d5ec:	movzwl 0x2(%r8),%ecx
 111d5f1:	movzwl (%r8),%edi
 111d5f5:	mov    %ecx,%esi
 111d5f7:	shl    $0x4,%esi
 111d5fa:	mov    (%r10,%rsi,1),%r11
 111d5fe:	mov    %edi,%r9d
 111d601:	shl    $0x4,%r9d
 111d605:	mov    (%r10,%r9,1),%rbx
 111d609:	cmp    %rbx,%r11
 111d60c:	mov    %r13,-0x40(%rbp)
 111d610:	jne    111df0e <sort.block.block__anon_39129+0xbce>
 111d616:	add    %r10,%rsi
 111d619:	add    %r10,%r9
 111d61c:	movzwl 0xe(%rsi),%esi
 111d620:	cmp    0xe(%r9),%si
 111d625:	jb     111df14 <sort.block.block__anon_39129+0xbd4>
 111d62b:	mov    $0x1,%cl
 111d62d:	mov    %ecx,-0x50(%rbp)
 111d630:	movl   $0x0,-0x48(%rbp)
 111d637:	jmp    111df42 <sort.block.block__anon_39129+0xc02>
 111d63c:	jae    111d535 <sort.block.block__anon_39129+0x1f5>
 111d642:	mov    %edi,%esi
 111d644:	shr    $0x8,%esi
 111d647:	mov    %ecx,%r9d
 111d64a:	shr    $0x8,%r9d
 111d64e:	mov    %cl,(%r8)
 111d651:	mov    %dil,0x2(%r8)
 111d655:	mov    %r9b,0x1(%r8)
 111d659:	mov    %sil,0x3(%r8)
 111d65d:	mov    -0x30(%rbp),%rcx
 111d661:	mov    (%rcx),%r10
 111d664:	mov    $0x1,%cl
 111d666:	mov    %ecx,-0x58(%rbp)
 111d669:	movl   $0x0,-0x48(%rbp)
 111d670:	movzwl 0x6(%r8),%ecx
 111d675:	movzwl 0x4(%r8),%edi
 111d67a:	mov    %ecx,%esi
 111d67c:	shl    $0x4,%esi
 111d67f:	mov    (%r10,%rsi,1),%r11
 111d683:	mov    %edi,%r9d
 111d686:	shl    $0x4,%r9d
 111d68a:	mov    (%r10,%r9,1),%rbx
 111d68e:	cmp    %rbx,%r11
 111d691:	jne    111d6ad <sort.block.block__anon_39129+0x36d>
 111d693:	add    %r10,%rsi
 111d696:	add    %r10,%r9
 111d699:	movzwl 0xe(%rsi),%esi
 111d69d:	cmp    0xe(%r9),%si
 111d6a2:	jb     111d6af <sort.block.block__anon_39129+0x36f>
 111d6a4:	movb   $0x3,-0x50(%rbp)
 111d6a8:	mov    $0x2,%r15b
 111d6ab:	jmp    111d6d9 <sort.block.block__anon_39129+0x399>
 111d6ad:	jae    111d6a4 <sort.block.block__anon_39129+0x364>
 111d6af:	mov    %edi,%esi
 111d6b1:	shr    $0x8,%esi
 111d6b4:	mov    %ecx,%r9d
 111d6b7:	shr    $0x8,%r9d
 111d6bb:	mov    %cl,0x4(%r8)
 111d6bf:	mov    %dil,0x6(%r8)
 111d6c3:	mov    %r9b,0x5(%r8)
 111d6c7:	mov    %sil,0x7(%r8)
 111d6cb:	mov    -0x30(%rbp),%rcx
 111d6cf:	mov    (%rcx),%r10
 111d6d2:	movb   $0x2,-0x50(%rbp)
 111d6d6:	mov    $0x3,%r15b
 111d6d9:	movzwl 0xa(%r8),%edi
 111d6de:	movzwl 0x8(%r8),%r9d
 111d6e3:	mov    %edi,%esi
 111d6e5:	shl    $0x4,%esi
 111d6e8:	mov    (%r10,%rsi,1),%rbx
 111d6ec:	mov    %r9d,%r11d
 111d6ef:	shl    $0x4,%r11d
 111d6f3:	mov    (%r10,%r11,1),%r14
 111d6f7:	cmp    %r14,%rbx
 111d6fa:	jne    111d716 <sort.block.block__anon_39129+0x3d6>
 111d6fc:	add    %r10,%rsi
 111d6ff:	add    %r10,%r11
 111d702:	movzwl 0xe(%rsi),%esi
 111d706:	cmp    0xe(%r11),%si
 111d70b:	jb     111d718 <sort.block.block__anon_39129+0x3d8>
 111d70d:	movb   $0x5,-0x80(%rbp)
 111d711:	mov    $0x4,%r11b
 111d714:	jmp    111d743 <sort.block.block__anon_39129+0x403>
 111d716:	jae    111d70d <sort.block.block__anon_39129+0x3cd>
 111d718:	mov    %r9d,%esi
 111d71b:	shr    $0x8,%esi
 111d71e:	mov    %edi,%r10d
 111d721:	shr    $0x8,%r10d
 111d725:	mov    %dil,0x8(%r8)
 111d729:	mov    %r9b,0xa(%r8)
 111d72d:	mov    %r10b,0x9(%r8)
 111d731:	mov    %sil,0xb(%r8)
 111d735:	mov    -0x30(%rbp),%rcx
 111d739:	mov    (%rcx),%r10
 111d73c:	movb   $0x4,-0x80(%rbp)
 111d740:	mov    $0x5,%r11b
 111d743:	movzwl 0xe(%r8),%edi
 111d748:	movzwl 0xc(%r8),%ebx
 111d74d:	mov    %edi,%esi
 111d74f:	shl    $0x4,%esi
 111d752:	mov    (%r10,%rsi,1),%r9
 111d756:	mov    %ebx,%r14d
 111d759:	shl    $0x4,%r14d
 111d75d:	mov    (%r10,%r14,1),%r12
 111d761:	cmp    %r12,%r9
 111d764:	mov    %r13,-0x40(%rbp)
 111d768:	jne    111d783 <sort.block.block__anon_39129+0x443>
 111d76a:	add    %r10,%rsi
 111d76d:	add    %r10,%r14
 111d770:	movzwl 0xe(%rsi),%esi
 111d774:	cmp    0xe(%r14),%si
 111d779:	jb     111d785 <sort.block.block__anon_39129+0x445>
 111d77b:	mov    $0x7,%r14b
 111d77e:	mov    $0x6,%r12b
 111d781:	jmp    111d7ae <sort.block.block__anon_39129+0x46e>
 111d783:	jae    111d77b <sort.block.block__anon_39129+0x43b>
 111d785:	mov    %ebx,%esi
 111d787:	shr    $0x8,%esi
 111d78a:	mov    %edi,%r9d
 111d78d:	shr    $0x8,%r9d
 111d791:	mov    %dil,0xc(%r8)
 111d795:	mov    %bl,0xe(%r8)
 111d799:	mov    %r9b,0xd(%r8)
 111d79d:	mov    %sil,0xf(%r8)
 111d7a1:	mov    -0x30(%rbp),%rcx
 111d7a5:	mov    (%rcx),%r10
 111d7a8:	mov    $0x6,%r14b
 111d7ab:	mov    $0x7,%r12b
 111d7ae:	movzwl 0x4(%r8),%edi
 111d7b3:	movzwl (%r8),%ebx
 111d7b7:	mov    %edi,%esi
 111d7b9:	shl    $0x4,%esi
 111d7bc:	mov    (%r10,%rsi,1),%r13
 111d7c0:	mov    %ebx,%r9d
 111d7c3:	shl    $0x4,%r9d
 111d7c7:	mov    (%r10,%r9,1),%rcx
 111d7cb:	cmp    %rcx,%r13
 111d7ce:	jne    111d7f2 <sort.block.block__anon_39129+0x4b2>
 111d7d0:	add    %r10,%rsi
 111d7d3:	add    %r10,%r9
 111d7d6:	movzwl 0xe(%rsi),%ecx
 111d7da:	cmp    0xe(%r9),%cx
 111d7df:	jb     111d7f4 <sort.block.block__anon_39129+0x4b4>
 111d7e1:	mov    -0x58(%rbp),%ecx
 111d7e4:	mov    %cl,-0xc8(%rbp)
 111d7ea:	mov    %r15d,%ecx
 111d7ed:	mov    %ecx,-0x58(%rbp)
 111d7f0:	jmp    111d81b <sort.block.block__anon_39129+0x4db>
 111d7f2:	jae    111d7e1 <sort.block.block__anon_39129+0x4a1>
 111d7f4:	mov    %ebx,%ecx
 111d7f6:	shr    $0x8,%ecx
 111d7f9:	mov    %edi,%esi
 111d7fb:	shr    $0x8,%esi
 111d7fe:	mov    %dil,(%r8)
 111d801:	mov    %bl,0x4(%r8)
 111d805:	mov    %sil,0x1(%r8)
 111d809:	mov    %cl,0x5(%r8)
 111d80d:	mov    -0x30(%rbp),%rcx
 111d811:	mov    (%rcx),%r10
 111d814:	mov    %r15b,-0xc8(%rbp)
 111d81b:	movzwl 0x6(%r8),%edi
 111d820:	movzwl 0x2(%r8),%ebx
 111d825:	mov    %edi,%esi
 111d827:	shl    $0x4,%esi
 111d82a:	mov    (%r10,%rsi,1),%rcx
 111d82e:	mov    %ebx,%r9d
 111d831:	shl    $0x4,%r9d
 111d835:	mov    (%r10,%r9,1),%r15
 111d839:	cmp    %r15,%rcx
 111d83c:	jne    111d85e <sort.block.block__anon_39129+0x51e>
 111d83e:	add    %r10,%rsi
 111d841:	add    %r10,%r9
 111d844:	movzwl 0xe(%rsi),%ecx
 111d848:	cmp    0xe(%r9),%cx
 111d84d:	jb     111d860 <sort.block.block__anon_39129+0x520>
 111d84f:	mov    -0x48(%rbp),%ecx
 111d852:	mov    %ecx,%r15d
 111d855:	movzbl -0x50(%rbp),%ecx
 111d859:	mov    %ecx,-0x48(%rbp)
 111d85c:	jmp    111d886 <sort.block.block__anon_39129+0x546>
 111d85e:	jae    111d84f <sort.block.block__anon_39129+0x50f>
 111d860:	mov    %ebx,%ecx
 111d862:	shr    $0x8,%ecx
 111d865:	mov    %edi,%esi
 111d867:	shr    $0x8,%esi
 111d86a:	mov    %dil,0x2(%r8)
 111d86e:	mov    %bl,0x6(%r8)
 111d872:	mov    %sil,0x3(%r8)
 111d876:	mov    %cl,0x7(%r8)
 111d87a:	mov    -0x30(%rbp),%rcx
 111d87e:	mov    (%rcx),%r10
 111d881:	movzbl -0x50(%rbp),%r15d
 111d886:	movzwl 0xc(%r8),%ecx
 111d88b:	movzwl 0x8(%r8),%edi
 111d890:	mov    %ecx,%esi
 111d892:	shl    $0x4,%esi
 111d895:	mov    (%r10,%rsi,1),%rbx
 111d899:	mov    %edi,%r9d
 111d89c:	shl    $0x4,%r9d
 111d8a0:	mov    (%r10,%r9,1),%r13
 111d8a4:	cmp    %r13,%rbx
 111d8a7:	jne    111d8c3 <sort.block.block__anon_39129+0x583>
 111d8a9:	add    %r10,%rsi
 111d8ac:	add    %r10,%r9
 111d8af:	movzwl 0xe(%rsi),%esi
 111d8b3:	cmp    0xe(%r9),%si
 111d8b8:	jb     111d8c5 <sort.block.block__anon_39129+0x585>
 111d8ba:	mov    %r11b,-0x50(%rbp)
 111d8be:	mov    %r12d,%r11d
 111d8c1:	jmp    111d8ec <sort.block.block__anon_39129+0x5ac>
 111d8c3:	jae    111d8ba <sort.block.block__anon_39129+0x57a>
 111d8c5:	mov    %edi,%esi
 111d8c7:	shr    $0x8,%esi
 111d8ca:	mov    %ecx,%r9d
 111d8cd:	shr    $0x8,%r9d
 111d8d1:	mov    %cl,0x8(%r8)
 111d8d5:	mov    %dil,0xc(%r8)
 111d8d9:	mov    %r9b,0x9(%r8)
 111d8dd:	mov    %sil,0xd(%r8)
 111d8e1:	mov    -0x30(%rbp),%rcx
 111d8e5:	mov    (%rcx),%r10
 111d8e8:	mov    %r12b,-0x50(%rbp)
 111d8ec:	movzwl 0xe(%r8),%edi
 111d8f1:	movzwl 0xa(%r8),%ebx
 111d8f6:	mov    %edi,%esi
 111d8f8:	shl    $0x4,%esi
 111d8fb:	mov    (%r10,%rsi,1),%rcx
 111d8ff:	mov    %ebx,%r9d
 111d902:	shl    $0x4,%r9d
 111d906:	mov    (%r10,%r9,1),%r12
 111d90a:	cmp    %r12,%rcx
 111d90d:	jne    111d92b <sort.block.block__anon_39129+0x5eb>
 111d90f:	add    %r10,%rsi
 111d912:	add    %r10,%r9
 111d915:	movzwl 0xe(%rsi),%ecx
 111d919:	cmp    0xe(%r9),%cx
 111d91e:	jb     111d92d <sort.block.block__anon_39129+0x5ed>
 111d920:	movzbl -0x80(%rbp),%r12d
 111d925:	mov    %r14b,-0x80(%rbp)
 111d929:	jmp    111d951 <sort.block.block__anon_39129+0x611>
 111d92b:	jae    111d920 <sort.block.block__anon_39129+0x5e0>
 111d92d:	mov    %ebx,%ecx
 111d92f:	shr    $0x8,%ecx
 111d932:	mov    %edi,%esi
 111d934:	shr    $0x8,%esi
 111d937:	mov    %dil,0xa(%r8)
 111d93b:	mov    %bl,0xe(%r8)
 111d93f:	mov    %sil,0xb(%r8)
 111d943:	mov    %cl,0xf(%r8)
 111d947:	mov    -0x30(%rbp),%rcx
 111d94b:	mov    (%rcx),%r10
 111d94e:	mov    %r14d,%r12d
 111d951:	movzwl 0x4(%r8),%edi
 111d956:	movzwl 0x2(%r8),%ebx
 111d95b:	mov    %edi,%esi
 111d95d:	shl    $0x4,%esi
 111d960:	mov    (%r10,%rsi,1),%r14
 111d964:	mov    %ebx,%r9d
 111d967:	shl    $0x4,%r9d
 111d96b:	mov    (%r10,%r9,1),%rcx
 111d96f:	cmp    %rcx,%r14
 111d972:	jne    111d99f <sort.block.block__anon_39129+0x65f>
 111d974:	add    %r10,%rsi
 111d977:	add    %r10,%r9
 111d97a:	movzwl 0xe(%r9),%ecx
 111d97f:	movzwl 0xe(%rsi),%esi
 111d983:	cmp    %cx,%si
 111d986:	mov    -0x58(%rbp),%r9d
 111d98a:	jb     111d9b7 <sort.block.block__anon_39129+0x677>
 111d98c:	cmp    %r9b,%r15b
 111d98f:	jbe    111e0ef <sort.block.block__anon_39129+0xdaf>
 111d995:	cmp    %si,%cx
 111d998:	jae    111d9b7 <sort.block.block__anon_39129+0x677>
 111d99a:	jmp    111e0ef <sort.block.block__anon_39129+0xdaf>
 111d99f:	mov    -0x58(%rbp),%r9d
 111d9a3:	jb     111d9b7 <sort.block.block__anon_39129+0x677>
 111d9a5:	cmp    %r9b,%r15b
 111d9a8:	jbe    111e0ef <sort.block.block__anon_39129+0xdaf>
 111d9ae:	cmp    %r14,%rcx
 111d9b1:	jb     111e0ef <sort.block.block__anon_39129+0xdaf>
 111d9b7:	mov    %ebx,%ecx
 111d9b9:	shr    $0x8,%ecx
 111d9bc:	mov    %edi,%esi
 111d9be:	shr    $0x8,%esi
 111d9c1:	mov    %dil,0x2(%r8)
 111d9c5:	mov    %bl,0x4(%r8)
 111d9c9:	mov    %sil,0x3(%r8)
 111d9cd:	mov    %cl,0x5(%r8)
 111d9d1:	mov    -0x30(%rbp),%rcx
 111d9d5:	mov    (%rcx),%r10
 111d9d8:	mov    %r9d,%r14d
 111d9db:	jmp    111e0f5 <sort.block.block__anon_39129+0xdb5>
 111d9e0:	jae    111d589 <sort.block.block__anon_39129+0x249>
 111d9e6:	mov    %edi,%esi
 111d9e8:	shr    $0x8,%esi
 111d9eb:	mov    %ecx,%r9d
 111d9ee:	shr    $0x8,%r9d
 111d9f2:	mov    %cl,0x2(%r8)
 111d9f6:	mov    %dil,0x4(%r8)
 111d9fa:	mov    %r9b,0x3(%r8)
 111d9fe:	mov    %sil,0x5(%r8)
 111da02:	mov    -0x30(%rbp),%rcx
 111da06:	mov    (%rcx),%r10
 111da09:	mov    $0x1,%r14b
 111da0c:	mov    $0x2,%r15b
 111da0f:	movzwl 0xa(%r8),%ecx
 111da14:	movzwl 0x8(%r8),%edi
 111da19:	mov    %ecx,%esi
 111da1b:	shl    $0x4,%esi
 111da1e:	mov    (%r10,%rsi,1),%r9
 111da22:	mov    %edi,%r11d
 111da25:	shl    $0x4,%r11d
 111da29:	mov    (%r10,%r11,1),%rbx
 111da2d:	cmp    %rbx,%r9
 111da30:	jne    111da4c <sort.block.block__anon_39129+0x70c>
 111da32:	add    %r10,%rsi
 111da35:	add    %r10,%r11
 111da38:	movzwl 0xe(%rsi),%esi
 111da3c:	cmp    0xe(%r11),%si
 111da41:	jb     111da4e <sort.block.block__anon_39129+0x70e>
 111da43:	movb   $0x5,-0x50(%rbp)
 111da47:	mov    $0x4,%r12b
 111da4a:	jmp    111da78 <sort.block.block__anon_39129+0x738>
 111da4c:	jae    111da43 <sort.block.block__anon_39129+0x703>
 111da4e:	mov    %edi,%esi
 111da50:	shr    $0x8,%esi
 111da53:	mov    %ecx,%r9d
 111da56:	shr    $0x8,%r9d
 111da5a:	mov    %cl,0x8(%r8)
 111da5e:	mov    %dil,0xa(%r8)
 111da62:	mov    %r9b,0x9(%r8)
 111da66:	mov    %sil,0xb(%r8)
 111da6a:	mov    -0x30(%rbp),%rcx
 111da6e:	mov    (%rcx),%r10
 111da71:	movb   $0x4,-0x50(%rbp)
 111da75:	mov    $0x5,%r12b
 111da78:	movzwl 0x4(%r8),%edi
 111da7d:	movzwl (%r8),%r11d
 111da81:	mov    %edi,%esi
 111da83:	shl    $0x4,%esi
 111da86:	mov    (%r10,%rsi,1),%rcx
 111da8a:	mov    %r11d,%ebx
 111da8d:	shl    $0x4,%ebx
 111da90:	mov    (%r10,%rbx,1),%r9
 111da94:	cmp    %r9,%rcx
 111da97:	mov    %r13,-0x40(%rbp)
 111da9b:	jne    111dab2 <sort.block.block__anon_39129+0x772>
 111da9d:	add    %r10,%rsi
 111daa0:	add    %r10,%rbx
 111daa3:	movzwl 0xe(%rsi),%ecx
 111daa7:	cmp    0xe(%rbx),%cx
 111daab:	jb     111dab4 <sort.block.block__anon_39129+0x774>
 111daad:	xor    %r11d,%r11d
 111dab0:	jmp    111dadb <sort.block.block__anon_39129+0x79b>
 111dab2:	jae    111daad <sort.block.block__anon_39129+0x76d>
 111dab4:	mov    %r11d,%ecx
 111dab7:	shr    $0x8,%ecx
 111daba:	mov    %edi,%esi
 111dabc:	shr    $0x8,%esi
 111dabf:	mov    %dil,(%r8)
 111dac2:	mov    %r11b,0x4(%r8)
 111dac6:	mov    %sil,0x1(%r8)
 111daca:	mov    %cl,0x5(%r8)
 111dace:	mov    -0x30(%rbp),%rcx
 111dad2:	mov    (%rcx),%r10
 111dad5:	mov    %r14d,%r11d
 111dad8:	xor    %r14d,%r14d
 111dadb:	mov    %r14d,-0x48(%rbp)
 111dadf:	movzwl 0xa(%r8),%edi
 111dae4:	movzwl 0x6(%r8),%ebx
 111dae9:	mov    %edi,%esi
 111daeb:	shl    $0x4,%esi
 111daee:	mov    (%r10,%rsi,1),%rcx
 111daf2:	mov    %ebx,%r13d
 111daf5:	shl    $0x4,%r13d
 111daf9:	mov    (%r10,%r13,1),%r9
 111dafd:	cmp    %r9,%rcx
 111db00:	jne    111db18 <sort.block.block__anon_39129+0x7d8>
 111db02:	add    %r10,%rsi
 111db05:	add    %r10,%r13
 111db08:	movzwl 0xe(%rsi),%ecx
 111db0c:	mov    $0x3,%r14b
 111db0f:	cmp    0xe(%r13),%cx
 111db14:	jb     111db1d <sort.block.block__anon_39129+0x7dd>
 111db16:	jmp    111db47 <sort.block.block__anon_39129+0x807>
 111db18:	mov    $0x3,%r14b
 111db1b:	jae    111db47 <sort.block.block__anon_39129+0x807>
 111db1d:	mov    %ebx,%ecx
 111db1f:	shr    $0x8,%ecx
 111db22:	mov    %edi,%esi
 111db24:	shr    $0x8,%esi
 111db27:	mov    %dil,0x6(%r8)
 111db2b:	mov    %bl,0xa(%r8)
 111db2f:	mov    %sil,0x7(%r8)
 111db33:	mov    %cl,0xb(%r8)
 111db37:	mov    -0x30(%rbp),%rcx
 111db3b:	mov    (%rcx),%r10
 111db3e:	movzbl -0x50(%rbp),%r14d
 111db43:	movb   $0x3,-0x50(%rbp)
 111db47:	movzwl 0x2(%r8),%edi
 111db4c:	movzwl (%r8),%ebx
 111db50:	mov    %edi,%esi
 111db52:	shl    $0x4,%esi
 111db55:	mov    (%r10,%rsi,1),%r13
 111db59:	mov    %ebx,%r9d
 111db5c:	shl    $0x4,%r9d
 111db60:	mov    (%r10,%r9,1),%rcx
 111db64:	cmp    %rcx,%r13
 111db67:	jne    111db90 <sort.block.block__anon_39129+0x850>
 111db69:	add    %r10,%rsi
 111db6c:	add    %r10,%r9
 111db6f:	movzwl 0xe(%r9),%ecx
 111db74:	movzwl 0xe(%rsi),%esi
 111db78:	cmp    %cx,%si
 111db7b:	jb     111dba4 <sort.block.block__anon_39129+0x864>
 111db7d:	cmp    %r15b,%r11b
 111db80:	jbe    111e569 <sort.block.block__anon_39129+0x1229>
 111db86:	cmp    %si,%cx
 111db89:	jae    111dba4 <sort.block.block__anon_39129+0x864>
 111db8b:	jmp    111e569 <sort.block.block__anon_39129+0x1229>
 111db90:	jb     111dba4 <sort.block.block__anon_39129+0x864>
 111db92:	cmp    %r15b,%r11b
 111db95:	jbe    111e569 <sort.block.block__anon_39129+0x1229>
 111db9b:	cmp    %r13,%rcx
 111db9e:	jb     111e569 <sort.block.block__anon_39129+0x1229>
 111dba4:	mov    %ebx,%ecx
 111dba6:	shr    $0x8,%ecx
 111dba9:	mov    %edi,%esi
 111dbab:	shr    $0x8,%esi
 111dbae:	mov    %dil,(%r8)
 111dbb1:	mov    %bl,0x2(%r8)
 111dbb5:	mov    %sil,0x1(%r8)
 111dbb9:	mov    %cl,0x3(%r8)
 111dbbd:	mov    -0x30(%rbp),%rcx
 111dbc1:	mov    (%rcx),%r10
 111dbc4:	mov    %r15d,%r13d
 111dbc7:	jmp    111e56f <sort.block.block__anon_39129+0x122f>
 111dbcc:	jae    111d5d7 <sort.block.block__anon_39129+0x297>
 111dbd2:	mov    %edi,%esi
 111dbd4:	shr    $0x8,%esi
 111dbd7:	mov    %ecx,%r9d
 111dbda:	shr    $0x8,%r9d
 111dbde:	mov    %cl,0x2(%r8)
 111dbe2:	mov    %dil,0x4(%r8)
 111dbe6:	mov    %r9b,0x3(%r8)
 111dbea:	mov    %sil,0x5(%r8)
 111dbee:	mov    -0x30(%rbp),%rcx
 111dbf2:	mov    (%rcx),%r10
 111dbf5:	mov    $0x1,%cl
 111dbf7:	mov    %ecx,-0x48(%rbp)
 111dbfa:	movb   $0x2,-0x80(%rbp)
 111dbfe:	movzwl 0x8(%r8),%ecx
 111dc03:	movzwl 0x6(%r8),%edi
 111dc08:	mov    %ecx,%esi
 111dc0a:	shl    $0x4,%esi
 111dc0d:	mov    (%r10,%rsi,1),%r11
 111dc11:	mov    %edi,%r9d
 111dc14:	shl    $0x4,%r9d
 111dc18:	mov    (%r10,%r9,1),%rbx
 111dc1c:	cmp    %rbx,%r11
 111dc1f:	jne    111dc3a <sort.block.block__anon_39129+0x8fa>
 111dc21:	add    %r10,%rsi
 111dc24:	add    %r10,%r9
 111dc27:	movzwl 0xe(%rsi),%esi
 111dc2b:	cmp    0xe(%r9),%si
 111dc30:	jb     111dc3c <sort.block.block__anon_39129+0x8fc>
 111dc32:	movb   $0x4,-0x58(%rbp)
 111dc36:	mov    $0x3,%cl
 111dc38:	jmp    111dc65 <sort.block.block__anon_39129+0x925>
 111dc3a:	jae    111dc32 <sort.block.block__anon_39129+0x8f2>
 111dc3c:	mov    %edi,%esi
 111dc3e:	shr    $0x8,%esi
 111dc41:	mov    %ecx,%r9d
 111dc44:	shr    $0x8,%r9d
 111dc48:	mov    %cl,0x6(%r8)
 111dc4c:	mov    %dil,0x8(%r8)
 111dc50:	mov    %r9b,0x7(%r8)
 111dc54:	mov    %sil,0x9(%r8)
 111dc58:	mov    -0x30(%rbp),%rcx
 111dc5c:	mov    (%rcx),%r10
 111dc5f:	movb   $0x3,-0x58(%rbp)
 111dc63:	mov    $0x4,%cl
 111dc65:	movzwl 0xc(%r8),%edi
 111dc6a:	movzwl 0xa(%r8),%r11d
 111dc6f:	mov    %edi,%esi
 111dc71:	shl    $0x4,%esi
 111dc74:	mov    (%r10,%rsi,1),%r9
 111dc78:	mov    %r11d,%ebx
 111dc7b:	shl    $0x4,%ebx
 111dc7e:	mov    (%r10,%rbx,1),%r14
 111dc82:	cmp    %r14,%r9
 111dc85:	jne    111dc9f <sort.block.block__anon_39129+0x95f>
 111dc87:	add    %r10,%rsi
 111dc8a:	add    %r10,%rbx
 111dc8d:	movzwl 0xe(%rsi),%esi
 111dc91:	cmp    0xe(%rbx),%si
 111dc95:	jb     111dca1 <sort.block.block__anon_39129+0x961>
 111dc97:	mov    $0x6,%r14b
 111dc9a:	mov    $0x5,%r12b
 111dc9d:	jmp    111dccb <sort.block.block__anon_39129+0x98b>
 111dc9f:	jae    111dc97 <sort.block.block__anon_39129+0x957>
 111dca1:	mov    %r11d,%esi
 111dca4:	shr    $0x8,%esi
 111dca7:	mov    %edi,%r9d
 111dcaa:	shr    $0x8,%r9d
 111dcae:	mov    %dil,0xa(%r8)
 111dcb2:	mov    %r11b,0xc(%r8)
 111dcb6:	mov    %r9b,0xb(%r8)
 111dcba:	mov    %sil,0xd(%r8)
 111dcbe:	mov    -0x30(%rbp),%rsi
 111dcc2:	mov    (%rsi),%r10
 111dcc5:	mov    $0x5,%r14b
 111dcc8:	mov    $0x6,%r12b
 111dccb:	movzwl 0x4(%r8),%edi
 111dcd0:	movzwl (%r8),%r11d
 111dcd4:	mov    %edi,%esi
 111dcd6:	shl    $0x4,%esi
 111dcd9:	mov    (%r10,%rsi,1),%r9
 111dcdd:	mov    %r11d,%ebx
 111dce0:	shl    $0x4,%ebx
 111dce3:	mov    (%r10,%rbx,1),%r15
 111dce7:	cmp    %r15,%r9
 111dcea:	mov    %r13,-0x40(%rbp)
 111dcee:	jne    111dd05 <sort.block.block__anon_39129+0x9c5>
 111dcf0:	add    %r10,%rsi
 111dcf3:	add    %r10,%rbx
 111dcf6:	movzwl 0xe(%rsi),%esi
 111dcfa:	cmp    0xe(%rbx),%si
 111dcfe:	jb     111dd07 <sort.block.block__anon_39129+0x9c7>
 111dd00:	xor    %r15d,%r15d
 111dd03:	jmp    111dd35 <sort.block.block__anon_39129+0x9f5>
 111dd05:	jae    111dd00 <sort.block.block__anon_39129+0x9c0>
 111dd07:	mov    %r11d,%esi
 111dd0a:	shr    $0x8,%esi
 111dd0d:	mov    %edi,%r9d
 111dd10:	shr    $0x8,%r9d
 111dd14:	mov    %dil,(%r8)
 111dd17:	mov    %r11b,0x4(%r8)
 111dd1b:	mov    %r9b,0x1(%r8)
 111dd1f:	mov    %sil,0x5(%r8)
 111dd23:	mov    -0x30(%rbp),%rsi
 111dd27:	mov    (%rsi),%r10
 111dd2a:	mov    -0x48(%rbp),%r15d
 111dd2e:	movl   $0x0,-0x48(%rbp)
 111dd35:	movzwl 0xa(%r8),%edi
 111dd3a:	movzwl 0x6(%r8),%r11d
 111dd3f:	mov    %edi,%esi
 111dd41:	shl    $0x4,%esi
 111dd44:	mov    (%r10,%rsi,1),%r9
 111dd48:	mov    %r11d,%ebx
 111dd4b:	shl    $0x4,%ebx
 111dd4e:	mov    (%r10,%rbx,1),%r13
 111dd52:	cmp    %r13,%r9
 111dd55:	jne    111dd65 <sort.block.block__anon_39129+0xa25>
 111dd57:	add    %r10,%rsi
 111dd5a:	add    %r10,%rbx
 111dd5d:	movzwl 0xe(%rsi),%esi
 111dd61:	cmp    0xe(%rbx),%si
 111dd65:	movzbl -0x80(%rbp),%r13d
 111dd6a:	jae    111dd96 <sort.block.block__anon_39129+0xa56>
 111dd6c:	mov    %r11d,%esi
 111dd6f:	shr    $0x8,%esi
 111dd72:	mov    %edi,%r9d
 111dd75:	shr    $0x8,%r9d
 111dd79:	mov    %dil,0x6(%r8)
 111dd7d:	mov    %r11b,0xa(%r8)
 111dd81:	mov    %r9b,0x7(%r8)
 111dd85:	mov    %sil,0xb(%r8)
 111dd89:	mov    -0x30(%rbp),%rsi
 111dd8d:	mov    (%rsi),%r10
 111dd90:	mov    %r12b,-0x50(%rbp)
 111dd94:	jmp    111dd9c <sort.block.block__anon_39129+0xa5c>
 111dd96:	mov    %cl,-0x50(%rbp)
 111dd99:	mov    %r12d,%ecx
 111dd9c:	movzwl 0xc(%r8),%edi
 111dda1:	movzwl 0x8(%r8),%ebx
 111dda6:	mov    %edi,%esi
 111dda8:	shl    $0x4,%esi
 111ddab:	mov    (%r10,%rsi,1),%r9
 111ddaf:	mov    %ebx,%r12d
 111ddb2:	shl    $0x4,%r12d
 111ddb6:	mov    (%r10,%r12,1),%r11
 111ddba:	cmp    %r11,%r9
 111ddbd:	jne    111dddc <sort.block.block__anon_39129+0xa9c>
 111ddbf:	add    %r10,%rsi
 111ddc2:	add    %r10,%r12
 111ddc5:	movzwl 0xe(%rsi),%esi
 111ddc9:	cmp    0xe(%r12),%si
 111ddcf:	jb     111ddde <sort.block.block__anon_39129+0xa9e>
 111ddd1:	movzbl -0x58(%rbp),%r12d
 111ddd6:	mov    %r14b,-0x58(%rbp)
 111ddda:	jmp    111de04 <sort.block.block__anon_39129+0xac4>
 111dddc:	jae    111ddd1 <sort.block.block__anon_39129+0xa91>
 111ddde:	mov    %ebx,%esi
 111dde0:	shr    $0x8,%esi
 111dde3:	mov    %edi,%r9d
 111dde6:	shr    $0x8,%r9d
 111ddea:	mov    %dil,0x8(%r8)
 111ddee:	mov    %bl,0xc(%r8)
 111ddf2:	mov    %r9b,0x9(%r8)
 111ddf6:	mov    %sil,0xd(%r8)
 111ddfa:	mov    -0x30(%rbp),%rsi
 111ddfe:	mov    (%rsi),%r10
 111de01:	mov    %r14d,%r12d
 111de04:	movzwl 0x2(%r8),%edi
 111de09:	movzwl (%r8),%ebx
 111de0d:	mov    %edi,%esi
 111de0f:	shl    $0x4,%esi
 111de12:	mov    (%r10,%rsi,1),%r14
 111de16:	mov    %ebx,%r9d
 111de19:	shl    $0x4,%r9d
 111de1d:	mov    (%r10,%r9,1),%r11
 111de21:	cmp    %r11,%r14
 111de24:	jne    111de4f <sort.block.block__anon_39129+0xb0f>
 111de26:	add    %r10,%rsi
 111de29:	add    %r10,%r9
 111de2c:	movzwl 0xe(%r9),%r9d
 111de31:	movzwl 0xe(%rsi),%esi
 111de35:	cmp    %r9w,%si
 111de39:	jb     111de63 <sort.block.block__anon_39129+0xb23>
 111de3b:	cmp    %r13b,%r15b
 111de3e:	jbe    111e882 <sort.block.block__anon_39129+0x1542>
 111de44:	cmp    %si,%r9w
 111de48:	jae    111de63 <sort.block.block__anon_39129+0xb23>
 111de4a:	jmp    111e882 <sort.block.block__anon_39129+0x1542>
 111de4f:	jb     111de63 <sort.block.block__anon_39129+0xb23>
 111de51:	cmp    %r13b,%r15b
 111de54:	jbe    111e882 <sort.block.block__anon_39129+0x1542>
 111de5a:	cmp    %r14,%r11
 111de5d:	jb     111e882 <sort.block.block__anon_39129+0x1542>
 111de63:	mov    %ebx,%esi
 111de65:	shr    $0x8,%esi
 111de68:	mov    %edi,%r9d
 111de6b:	shr    $0x8,%r9d
 111de6f:	mov    %dil,(%r8)
 111de72:	mov    %bl,0x2(%r8)
 111de76:	mov    %r9b,0x1(%r8)
 111de7a:	mov    %sil,0x3(%r8)
 111de7e:	mov    -0x30(%rbp),%rsi
 111de82:	mov    (%rsi),%r10
 111de85:	mov    %r13d,%r14d
 111de88:	jmp    111e888 <sort.block.block__anon_39129+0x1548>
 111de8d:	jae    111d4e5 <sort.block.block__anon_39129+0x1a5>
 111de93:	mov    %r9d,%ecx
 111de96:	shr    $0x8,%ecx
 111de99:	mov    %edi,%esi
 111de9b:	shr    $0x8,%esi
 111de9e:	mov    %dil,(%r8)
 111dea1:	mov    %r9b,0x2(%r8)
 111dea5:	mov    %sil,0x1(%r8)
 111dea9:	mov    %cl,0x3(%r8)
 111dead:	mov    -0x30(%rbp),%rcx
 111deb1:	mov    (%rcx),%rcx
 111deb4:	mov    $0x1,%r14b
 111deb7:	movl   $0x0,-0x48(%rbp)
 111debe:	movzwl 0x6(%r8),%r10d
 111dec3:	movzwl 0x4(%r8),%r15d
 111dec8:	mov    %r10d,%r11d
 111decb:	shl    $0x4,%r11d
 111decf:	mov    (%rcx,%r11,1),%rdi
 111ded3:	mov    %r15d,%esi
 111ded6:	shl    $0x4,%esi
 111ded9:	mov    (%rcx,%rsi,1),%rbx
 111dedd:	mov    %r15d,%r12d
 111dee0:	shr    $0x8,%r12d
 111dee4:	cmp    %rbx,%rdi
 111dee7:	jne    111df86 <sort.block.block__anon_39129+0xc46>
 111deed:	add    %rcx,%r11
 111def0:	add    %rcx,%rsi
 111def3:	movzwl 0xe(%r11),%r11d
 111def8:	cmp    0xe(%rsi),%r11w
 111defd:	jb     111df8c <sort.block.block__anon_39129+0xc4c>
 111df03:	mov    $0x3,%r10b
 111df06:	mov    $0x2,%r11b
 111df09:	jmp    111eef2 <sort.block.block__anon_39129+0x1bb2>
 111df0e:	jae    111d62b <sort.block.block__anon_39129+0x2eb>
 111df14:	mov    %edi,%esi
 111df16:	shr    $0x8,%esi
 111df19:	mov    %ecx,%r9d
 111df1c:	shr    $0x8,%r9d
 111df20:	mov    %cl,(%r8)
 111df23:	mov    %dil,0x2(%r8)
 111df27:	mov    %r9b,0x1(%r8)
 111df2b:	mov    %sil,0x3(%r8)
 111df2f:	mov    -0x30(%rbp),%rcx
 111df33:	mov    (%rcx),%r10
 111df36:	mov    $0x1,%cl
 111df38:	mov    %ecx,-0x48(%rbp)
 111df3b:	movl   $0x0,-0x50(%rbp)
 111df42:	movzwl 0x8(%r8),%r13d
 111df47:	movzwl 0x6(%r8),%ecx
 111df4c:	mov    %r13d,%r11d
 111df4f:	shl    $0x4,%r11d
 111df53:	mov    (%r10,%r11,1),%rdi
 111df57:	mov    %ecx,%esi
 111df59:	shl    $0x4,%esi
 111df5c:	mov    (%r10,%rsi,1),%rbx
 111df60:	mov    %r13d,%r9d
 111df63:	shr    $0x8,%r9d
 111df67:	cmp    %rbx,%rdi
 111df6a:	jne    111dfca <sort.block.block__anon_39129+0xc8a>
 111df6c:	add    %r10,%r11
 111df6f:	add    %r10,%rsi
 111df72:	movzwl 0xe(%r11),%r11d
 111df77:	cmp    0xe(%rsi),%r11w
 111df7c:	jb     111dfcc <sort.block.block__anon_39129+0xc8c>
 111df7e:	mov    $0x4,%r14b
 111df81:	mov    $0x3,%r12b
 111df84:	jmp    111e004 <sort.block.block__anon_39129+0xcc4>
 111df86:	jae    111eee9 <sort.block.block__anon_39129+0x1ba9>
 111df8c:	mov    %r10d,%ecx
 111df8f:	shr    $0x8,%ecx
 111df92:	mov    %r10b,0x4(%r8)
 111df96:	mov    %r15b,0x6(%r8)
 111df9a:	mov    %cl,0x5(%r8)
 111df9e:	mov    %r12b,0x7(%r8)
 111dfa2:	mov    -0x30(%rbp),%rcx
 111dfa6:	mov    (%rcx),%rcx
 111dfa9:	movzwl 0x4(%r8),%r15d
 111dfae:	mov    %r15d,%esi
 111dfb1:	shl    $0x4,%esi
 111dfb4:	mov    (%rcx,%rsi,1),%rdi
 111dfb8:	mov    %r15d,%r12d
 111dfbb:	shr    $0x8,%r12d
 111dfbf:	mov    $0x2,%r10b
 111dfc2:	mov    $0x3,%r11b
 111dfc5:	jmp    111eef2 <sort.block.block__anon_39129+0x1bb2>
 111dfca:	jae    111df7e <sort.block.block__anon_39129+0xc3e>
 111dfcc:	mov    %ecx,%esi
 111dfce:	shr    $0x8,%esi
 111dfd1:	mov    %r13b,0x6(%r8)
 111dfd5:	mov    %cl,0x8(%r8)
 111dfd9:	mov    %r9b,0x7(%r8)
 111dfdd:	mov    %sil,0x9(%r8)
 111dfe1:	mov    -0x30(%rbp),%rcx
 111dfe5:	mov    (%rcx),%r10
 111dfe8:	movzwl 0x8(%r8),%r13d
 111dfed:	mov    %r13d,%ecx
 111dff0:	shl    $0x4,%ecx
 111dff3:	mov    (%r10,%rcx,1),%rdi
 111dff7:	mov    %r13d,%r9d
 111dffa:	shr    $0x8,%r9d
 111dffe:	mov    $0x3,%r14b
 111e001:	mov    $0x4,%r12b
 111e004:	movzwl 0x4(%r8),%esi
 111e009:	mov    %esi,%ecx
 111e00b:	shl    $0x4,%ecx
 111e00e:	mov    (%r10,%rcx,1),%rbx
 111e012:	mov    %esi,%r11d
 111e015:	shr    $0x8,%r11d
 111e019:	cmp    %rbx,%rdi
 111e01c:	jne    111e03b <sort.block.block__anon_39129+0xcfb>
 111e01e:	add    %r10,%rcx
 111e021:	mov    %r13d,%ebx
 111e024:	shl    $0x4,%ebx
 111e027:	movzwl 0xe(%r10,%rbx,1),%ebx
 111e02d:	mov    $0x2,%r15b
 111e030:	cmp    0xe(%rcx),%bx
 111e034:	jb     111e040 <sort.block.block__anon_39129+0xd00>
 111e036:	mov    %rdi,%rbx
 111e039:	jmp    111e072 <sort.block.block__anon_39129+0xd32>
 111e03b:	mov    $0x2,%r15b
 111e03e:	jae    111e072 <sort.block.block__anon_39129+0xd32>
 111e040:	mov    %r13b,0x4(%r8)
 111e044:	mov    %sil,0x8(%r8)
 111e048:	mov    %r9b,0x5(%r8)
 111e04c:	mov    %r11b,0x9(%r8)
 111e050:	mov    -0x30(%rbp),%rcx
 111e054:	mov    (%rcx),%r10
 111e057:	movzwl 0x4(%r8),%esi
 111e05c:	mov    %esi,%ecx
 111e05e:	shl    $0x4,%ecx
 111e061:	mov    (%r10,%rcx,1),%rbx
 111e065:	mov    %esi,%r11d
 111e068:	shr    $0x8,%r11d
 111e06c:	mov    %r14d,%r15d
 111e06f:	mov    $0x2,%r14b
 111e072:	mov    -0x40(%rbp),%r13
 111e076:	movzwl 0x6(%r8),%edi
 111e07b:	mov    %edi,%ecx
 111e07d:	shl    $0x4,%ecx
 111e080:	mov    (%r10,%rcx,1),%r9
 111e084:	cmp    %rbx,%r9
 111e087:	jne    111e0b7 <sort.block.block__anon_39129+0xd77>
 111e089:	add    %r10,%rcx
 111e08c:	mov    %esi,%r9d
 111e08f:	shl    $0x4,%r9d
 111e093:	movzwl 0xe(%r10,%r9,1),%r9d
 111e099:	movzwl 0xe(%rcx),%ecx
 111e09d:	cmp    %r9w,%cx
 111e0a1:	jb     111e0cb <sort.block.block__anon_39129+0xd8b>
 111e0a3:	cmp    %r12b,%r15b
 111e0a6:	jbe    111eca1 <sort.block.block__anon_39129+0x1961>
 111e0ac:	cmp    %cx,%r9w
 111e0b0:	jae    111e0cb <sort.block.block__anon_39129+0xd8b>
 111e0b2:	jmp    111eca1 <sort.block.block__anon_39129+0x1961>
 111e0b7:	jb     111e0cb <sort.block.block__anon_39129+0xd8b>
 111e0b9:	cmp    %r12b,%r15b
 111e0bc:	jbe    111eca1 <sort.block.block__anon_39129+0x1961>
 111e0c2:	cmp    %r9,%rbx
 111e0c5:	jb     111eca1 <sort.block.block__anon_39129+0x1961>
 111e0cb:	mov    %edi,%ecx
 111e0cd:	shr    $0x8,%ecx
 111e0d0:	mov    %dil,0x4(%r8)
 111e0d4:	mov    %sil,0x6(%r8)
 111e0d8:	mov    %cl,0x5(%r8)
 111e0dc:	mov    %r11b,0x7(%r8)
 111e0e0:	mov    -0x30(%rbp),%rcx
 111e0e4:	mov    (%rcx),%r10
 111e0e7:	mov    %r12d,%ecx
 111e0ea:	jmp    111eca7 <sort.block.block__anon_39129+0x1967>
 111e0ef:	mov    %r15d,%r14d
 111e0f2:	mov    %r9d,%r15d
 111e0f5:	movzwl 0xc(%r8),%edi
 111e0fa:	movzwl 0xa(%r8),%ebx
 111e0ff:	mov    %edi,%esi
 111e101:	shl    $0x4,%esi
 111e104:	mov    (%r10,%rsi,1),%r13
 111e108:	mov    %ebx,%r9d
 111e10b:	shl    $0x4,%r9d
 111e10f:	mov    (%r10,%r9,1),%rcx
 111e113:	cmp    %rcx,%r13
 111e116:	jne    111e138 <sort.block.block__anon_39129+0xdf8>
 111e118:	add    %r10,%rsi
 111e11b:	add    %r10,%r9
 111e11e:	movzwl 0xe(%r9),%ecx
 111e123:	movzwl 0xe(%rsi),%esi
 111e127:	cmp    %cx,%si
 111e12a:	jb     111e144 <sort.block.block__anon_39129+0xe04>
 111e12c:	cmp    %r11b,%r12b
 111e12f:	jbe    111e16a <sort.block.block__anon_39129+0xe2a>
 111e131:	cmp    %si,%cx
 111e134:	jae    111e144 <sort.block.block__anon_39129+0xe04>
 111e136:	jmp    111e16a <sort.block.block__anon_39129+0xe2a>
 111e138:	jb     111e144 <sort.block.block__anon_39129+0xe04>
 111e13a:	cmp    %r11b,%r12b
 111e13d:	jbe    111e16a <sort.block.block__anon_39129+0xe2a>
 111e13f:	cmp    %r13,%rcx
 111e142:	jb     111e16a <sort.block.block__anon_39129+0xe2a>
 111e144:	mov    %ebx,%ecx
 111e146:	shr    $0x8,%ecx
 111e149:	mov    %edi,%esi
 111e14b:	shr    $0x8,%esi
 111e14e:	mov    %dil,0xa(%r8)
 111e152:	mov    %bl,0xc(%r8)
 111e156:	mov    %sil,0xb(%r8)
 111e15a:	mov    %cl,0xd(%r8)
 111e15e:	mov    -0x30(%rbp),%rcx
 111e162:	mov    (%rcx),%r10
 111e165:	mov    %r11d,%r13d
 111e168:	jmp    111e170 <sort.block.block__anon_39129+0xe30>
 111e16a:	mov    %r12d,%r13d
 111e16d:	mov    %r11d,%r12d
 111e170:	movzwl 0x8(%r8),%edi
 111e175:	movzwl (%r8),%r11d
 111e179:	mov    %edi,%esi
 111e17b:	shl    $0x4,%esi
 111e17e:	mov    (%r10,%rsi,1),%rcx
 111e182:	mov    %r11d,%r9d
 111e185:	shl    $0x4,%r9d
 111e189:	mov    (%r10,%r9,1),%rbx
 111e18d:	cmp    %rbx,%rcx
 111e190:	jne    111e1a1 <sort.block.block__anon_39129+0xe61>
 111e192:	add    %r10,%rsi
 111e195:	add    %r10,%r9
 111e198:	movzwl 0xe(%rsi),%ecx
 111e19c:	cmp    0xe(%r9),%cx
 111e1a1:	jae    111e1ce <sort.block.block__anon_39129+0xe8e>
 111e1a3:	mov    %r11d,%ecx
 111e1a6:	shr    $0x8,%ecx
 111e1a9:	mov    %edi,%esi
 111e1ab:	shr    $0x8,%esi
 111e1ae:	mov    %dil,(%r8)
 111e1b1:	mov    %r11b,0x8(%r8)
 111e1b5:	mov    %sil,0x1(%r8)
 111e1b9:	mov    %cl,0x9(%r8)
 111e1bd:	mov    -0x30(%rbp),%rcx
 111e1c1:	mov    (%rcx),%r10
 111e1c4:	movzbl -0xc8(%rbp),%ecx
 111e1cb:	mov    %cl,-0x50(%rbp)
 111e1ce:	movzwl 0xe(%r8),%edi
 111e1d3:	movzwl 0x6(%r8),%r11d
 111e1d8:	mov    %edi,%esi
 111e1da:	shl    $0x4,%esi
 111e1dd:	mov    (%r10,%rsi,1),%rcx
 111e1e1:	mov    %r11d,%r9d
 111e1e4:	shl    $0x4,%r9d
 111e1e8:	mov    (%r10,%r9,1),%rbx
 111e1ec:	cmp    %rbx,%rcx
 111e1ef:	jne    111e200 <sort.block.block__anon_39129+0xec0>
 111e1f1:	add    %r10,%rsi
 111e1f4:	add    %r10,%r9
 111e1f7:	movzwl 0xe(%rsi),%ecx
 111e1fb:	cmp    0xe(%r9),%cx
 111e200:	jae    111e22b <sort.block.block__anon_39129+0xeeb>
 111e202:	mov    %r11d,%ecx
 111e205:	shr    $0x8,%ecx
 111e208:	mov    %edi,%esi
 111e20a:	shr    $0x8,%esi
 111e20d:	mov    %dil,0x6(%r8)
 111e211:	mov    %r11b,0xe(%r8)
 111e215:	mov    %sil,0x7(%r8)
 111e219:	mov    %cl,0xf(%r8)
 111e21d:	mov    -0x30(%rbp),%rcx
 111e221:	mov    (%rcx),%r10
 111e224:	movzbl -0x80(%rbp),%ecx
 111e228:	mov    %ecx,-0x48(%rbp)
 111e22b:	movzwl 0xa(%r8),%edi
 111e230:	movzwl 0x2(%r8),%r9d
 111e235:	mov    %edi,%esi
 111e237:	shl    $0x4,%esi
 111e23a:	mov    (%r10,%rsi,1),%rcx
 111e23e:	mov    %r9d,%r11d
 111e241:	shl    $0x4,%r11d
 111e245:	mov    (%r10,%r11,1),%rbx
 111e249:	cmp    %rbx,%rcx
 111e24c:	jne    111e267 <sort.block.block__anon_39129+0xf27>
 111e24e:	add    %r10,%rsi
 111e251:	add    %r10,%r11
 111e254:	movzwl 0xe(%rsi),%ecx
 111e258:	cmp    0xe(%r11),%cx
 111e25d:	jb     111e269 <sort.block.block__anon_39129+0xf29>
 111e25f:	mov    %r14d,%r11d
 111e262:	mov    %r13d,%r14d
 111e265:	jmp    111e28e <sort.block.block__anon_39129+0xf4e>
 111e267:	jae    111e25f <sort.block.block__anon_39129+0xf1f>
 111e269:	mov    %r9d,%ecx
 111e26c:	shr    $0x8,%ecx
 111e26f:	mov    %edi,%esi
 111e271:	shr    $0x8,%esi
 111e274:	mov    %dil,0x2(%r8)
 111e278:	mov    %r9b,0xa(%r8)
 111e27c:	mov    %sil,0x3(%r8)
 111e280:	mov    %cl,0xb(%r8)
 111e284:	mov    -0x30(%rbp),%rcx
 111e288:	mov    (%rcx),%r10
 111e28b:	mov    %r13d,%r11d
 111e28e:	movzwl 0xc(%r8),%edi
 111e293:	movzwl 0x4(%r8),%r9d
 111e298:	mov    %edi,%esi
 111e29a:	shl    $0x4,%esi
 111e29d:	mov    (%r10,%rsi,1),%rcx
 111e2a1:	mov    %r9d,%ebx
 111e2a4:	shl    $0x4,%ebx
 111e2a7:	mov    (%r10,%rbx,1),%r13
 111e2ab:	cmp    %r13,%rcx
 111e2ae:	jne    111e2c8 <sort.block.block__anon_39129+0xf88>
 111e2b0:	add    %r10,%rsi
 111e2b3:	add    %r10,%rbx
 111e2b6:	movzwl 0xe(%rsi),%ecx
 111e2ba:	cmp    0xe(%rbx),%cx
 111e2be:	jb     111e2ca <sort.block.block__anon_39129+0xf8a>
 111e2c0:	mov    %r15d,%r9d
 111e2c3:	mov    %r12d,%r15d
 111e2c6:	jmp    111e2ef <sort.block.block__anon_39129+0xfaf>
 111e2c8:	jae    111e2c0 <sort.block.block__anon_39129+0xf80>
 111e2ca:	mov    %r9d,%ecx
 111e2cd:	shr    $0x8,%ecx
 111e2d0:	mov    %edi,%esi
 111e2d2:	shr    $0x8,%esi
 111e2d5:	mov    %dil,0x4(%r8)
 111e2d9:	mov    %r9b,0xc(%r8)
 111e2dd:	mov    %sil,0x5(%r8)
 111e2e1:	mov    %cl,0xd(%r8)
 111e2e5:	mov    -0x30(%rbp),%rcx
 111e2e9:	mov    (%rcx),%r10
 111e2ec:	mov    %r12d,%r9d
 111e2ef:	movzwl 0x8(%r8),%edi
 111e2f4:	movzwl 0x2(%r8),%ebx
 111e2f9:	mov    %edi,%esi
 111e2fb:	shl    $0x4,%esi
 111e2fe:	mov    (%r10,%rsi,1),%r12
 111e302:	mov    %ebx,%r13d
 111e305:	shl    $0x4,%r13d
 111e309:	mov    (%r10,%r13,1),%rcx
 111e30d:	cmp    %rcx,%r12
 111e310:	jne    111e337 <sort.block.block__anon_39129+0xff7>
 111e312:	add    %r10,%rsi
 111e315:	add    %r10,%r13
 111e318:	movzwl 0xe(%r13),%ecx
 111e31d:	movzwl 0xe(%rsi),%esi
 111e321:	cmp    %cx,%si
 111e324:	mov    -0x40(%rbp),%r13
 111e328:	jb     111e348 <sort.block.block__anon_39129+0x1008>
 111e32a:	cmp    -0x50(%rbp),%r11b
 111e32e:	jbe    111e36d <sort.block.block__anon_39129+0x102d>
 111e330:	cmp    %si,%cx
 111e333:	jae    111e348 <sort.block.block__anon_39129+0x1008>
 111e335:	jmp    111e36d <sort.block.block__anon_39129+0x102d>
 111e337:	mov    -0x40(%rbp),%r13
 111e33b:	jb     111e348 <sort.block.block__anon_39129+0x1008>
 111e33d:	cmp    -0x50(%rbp),%r11b
 111e341:	jbe    111e36d <sort.block.block__anon_39129+0x102d>
 111e343:	cmp    %r12,%rcx
 111e346:	jb     111e36d <sort.block.block__anon_39129+0x102d>
 111e348:	mov    %ebx,%ecx
 111e34a:	shr    $0x8,%ecx
 111e34d:	mov    %edi,%esi
 111e34f:	shr    $0x8,%esi
 111e352:	mov    %dil,0x2(%r8)
 111e356:	mov    %bl,0x8(%r8)
 111e35a:	mov    %sil,0x3(%r8)
 111e35e:	mov    %cl,0x9(%r8)
 111e362:	mov    -0x30(%rbp),%rcx
 111e366:	mov    (%rcx),%r10
 111e369:	mov    %r11b,-0x50(%rbp)
 111e36d:	movzwl 0xc(%r8),%edi
 111e372:	movzwl 0x6(%r8),%r11d
 111e377:	mov    %edi,%esi
 111e379:	shl    $0x4,%esi
 111e37c:	mov    (%r10,%rsi,1),%rbx
 111e380:	mov    %r11d,%r12d
 111e383:	shl    $0x4,%r12d
 111e387:	mov    (%r10,%r12,1),%rcx
 111e38b:	cmp    %rcx,%rbx
 111e38e:	jne    111e3b2 <sort.block.block__anon_39129+0x1072>
 111e390:	add    %r10,%rsi
 111e393:	add    %r10,%r12
 111e396:	movzwl 0xe(%r12),%ecx
 111e39c:	movzwl 0xe(%rsi),%esi
 111e3a0:	cmp    %cx,%si
 111e3a3:	jb     111e3bf <sort.block.block__anon_39129+0x107f>
 111e3a5:	cmp    %r15b,-0x48(%rbp)
 111e3a9:	jbe    111e3e7 <sort.block.block__anon_39129+0x10a7>
 111e3ab:	cmp    %si,%cx
 111e3ae:	jae    111e3bf <sort.block.block__anon_39129+0x107f>
 111e3b0:	jmp    111e3e7 <sort.block.block__anon_39129+0x10a7>
 111e3b2:	jb     111e3bf <sort.block.block__anon_39129+0x107f>
 111e3b4:	cmp    %r15b,-0x48(%rbp)
 111e3b8:	jbe    111e3e7 <sort.block.block__anon_39129+0x10a7>
 111e3ba:	cmp    %rbx,%rcx
 111e3bd:	jb     111e3e7 <sort.block.block__anon_39129+0x10a7>
 111e3bf:	mov    %r11d,%ecx
 111e3c2:	shr    $0x8,%ecx
 111e3c5:	mov    %edi,%esi
 111e3c7:	shr    $0x8,%esi
 111e3ca:	mov    %dil,0x6(%r8)
 111e3ce:	mov    %r11b,0xc(%r8)
 111e3d2:	mov    %sil,0x7(%r8)
 111e3d6:	mov    %cl,0xd(%r8)
 111e3da:	mov    -0x30(%rbp),%rcx
 111e3de:	mov    (%rcx),%r10
 111e3e1:	mov    %r15d,%ecx
 111e3e4:	mov    %ecx,-0x48(%rbp)
 111e3e7:	movzwl 0x8(%r8),%edi
 111e3ec:	movzwl 0x4(%r8),%r11d
 111e3f1:	mov    %edi,%esi
 111e3f3:	shl    $0x4,%esi
 111e3f6:	mov    (%r10,%rsi,1),%rbx
 111e3fa:	mov    %r11d,%r15d
 111e3fd:	shl    $0x4,%r15d
 111e401:	mov    (%r10,%r15,1),%rcx
 111e405:	cmp    %rcx,%rbx
 111e408:	jne    111e42b <sort.block.block__anon_39129+0x10eb>
 111e40a:	add    %r10,%rsi
 111e40d:	add    %r10,%r15
 111e410:	movzwl 0xe(%r15),%ecx
 111e415:	movzwl 0xe(%rsi),%esi
 111e419:	cmp    %cx,%si
 111e41c:	jb     111e438 <sort.block.block__anon_39129+0x10f8>
 111e41e:	cmp    -0x50(%rbp),%r9b
 111e422:	jbe    111e45e <sort.block.block__anon_39129+0x111e>
 111e424:	cmp    %si,%cx
 111e427:	jae    111e438 <sort.block.block__anon_39129+0x10f8>
 111e429:	jmp    111e45e <sort.block.block__anon_39129+0x111e>
 111e42b:	jb     111e438 <sort.block.block__anon_39129+0x10f8>
 111e42d:	cmp    -0x50(%rbp),%r9b
 111e431:	jbe    111e45e <sort.block.block__anon_39129+0x111e>
 111e433:	cmp    %rbx,%rcx
 111e436:	jb     111e45e <sort.block.block__anon_39129+0x111e>
 111e438:	mov    %r11d,%ecx
 111e43b:	shr    $0x8,%ecx
 111e43e:	mov    %edi,%esi
 111e440:	shr    $0x8,%esi
 111e443:	mov    %dil,0x4(%r8)
 111e447:	mov    %r11b,0x8(%r8)
 111e44b:	mov    %sil,0x5(%r8)
 111e44f:	mov    %cl,0x9(%r8)
 111e453:	mov    -0x30(%rbp),%rcx
 111e457:	mov    (%rcx),%r10
 111e45a:	mov    %r9b,-0x50(%rbp)
 111e45e:	movzwl 0xa(%r8),%r11d
 111e463:	movzwl 0x6(%r8),%r9d
 111e468:	mov    %r11d,%r12d
 111e46b:	shl    $0x4,%r12d
 111e46f:	mov    (%r10,%r12,1),%rbx
 111e473:	mov    %r9d,%esi
 111e476:	shl    $0x4,%esi
 111e479:	mov    (%r10,%rsi,1),%rdi
 111e47d:	mov    %r9d,%r15d
 111e480:	shr    $0x8,%r15d
 111e484:	cmp    %rdi,%rbx
 111e487:	jne    111e4ae <sort.block.block__anon_39129+0x116e>
 111e489:	add    %r10,%r12
 111e48c:	add    %r10,%rsi
 111e48f:	movzwl 0xe(%rsi),%ecx
 111e493:	movzwl 0xe(%r12),%esi
 111e499:	cmp    %cx,%si
 111e49c:	jb     111e4bb <sort.block.block__anon_39129+0x117b>
 111e49e:	cmp    %r14b,-0x48(%rbp)
 111e4a2:	jbe    111e4a9 <sort.block.block__anon_39129+0x1169>
 111e4a4:	cmp    %si,%cx
 111e4a7:	jae    111e4bb <sort.block.block__anon_39129+0x117b>
 111e4a9:	mov    %rbx,%rdi
 111e4ac:	jmp    111e4f0 <sort.block.block__anon_39129+0x11b0>
 111e4ae:	jb     111e4bb <sort.block.block__anon_39129+0x117b>
 111e4b0:	cmp    %r14b,-0x48(%rbp)
 111e4b4:	jbe    111e4f0 <sort.block.block__anon_39129+0x11b0>
 111e4b6:	cmp    %rbx,%rdi
 111e4b9:	jb     111e4f0 <sort.block.block__anon_39129+0x11b0>
 111e4bb:	mov    %r11d,%ecx
 111e4be:	shr    $0x8,%ecx
 111e4c1:	mov    %r11b,0x6(%r8)
 111e4c5:	mov    %r9b,0xa(%r8)
 111e4c9:	mov    %cl,0x7(%r8)
 111e4cd:	mov    %r15b,0xb(%r8)
 111e4d1:	mov    -0x30(%rbp),%rcx
 111e4d5:	mov    (%rcx),%r10
 111e4d8:	movzwl 0x6(%r8),%r9d
 111e4dd:	mov    %r9d,%ecx
 111e4e0:	shl    $0x4,%ecx
 111e4e3:	mov    (%r10,%rcx,1),%rdi
 111e4e7:	mov    %r9d,%r15d
 111e4ea:	shr    $0x8,%r15d
 111e4ee:	jmp    111e4f6 <sort.block.block__anon_39129+0x11b6>
 111e4f0:	mov    -0x48(%rbp),%ecx
 111e4f3:	mov    %ecx,%r14d
 111e4f6:	movzwl 0x8(%r8),%r11d
 111e4fb:	mov    %r11d,%esi
 111e4fe:	shl    $0x4,%esi
 111e501:	mov    (%r10,%rsi,1),%rbx
 111e505:	cmp    %rdi,%rbx
 111e508:	jne    111e536 <sort.block.block__anon_39129+0x11f6>
 111e50a:	add    %r10,%rsi
 111e50d:	mov    %r9d,%ecx
 111e510:	shl    $0x4,%ecx
 111e513:	movzwl 0xe(%r10,%rcx,1),%ecx
 111e519:	movzwl 0xe(%rsi),%esi
 111e51d:	cmp    %cx,%si
 111e520:	jb     111e54b <sort.block.block__anon_39129+0x120b>
 111e522:	cmp    -0x50(%rbp),%r14b
 111e526:	jbe    111d431 <sort.block.block__anon_39129+0xf1>
 111e52c:	cmp    %si,%cx
 111e52f:	jae    111e54b <sort.block.block__anon_39129+0x120b>
 111e531:	jmp    111d431 <sort.block.block__anon_39129+0xf1>
 111e536:	jb     111e54b <sort.block.block__anon_39129+0x120b>
 111e538:	cmp    -0x50(%rbp),%r14b
 111e53c:	jbe    111d431 <sort.block.block__anon_39129+0xf1>
 111e542:	cmp    %rbx,%rdi
 111e545:	jb     111d431 <sort.block.block__anon_39129+0xf1>
 111e54b:	mov    %r11d,%ecx
 111e54e:	shr    $0x8,%ecx
 111e551:	mov    %r11b,0x6(%r8)
 111e555:	mov    %r9b,0x8(%r8)
 111e559:	mov    $0x9,%edi
 111e55e:	mov    $0x7,%r9d
 111e564:	jmp    111d429 <sort.block.block__anon_39129+0xe9>
 111e569:	mov    %r11d,%r13d
 111e56c:	mov    %r15d,%r11d
 111e56f:	movzwl 0x8(%r8),%edi
 111e574:	movzwl 0x6(%r8),%ebx
 111e579:	mov    %edi,%esi
 111e57b:	shl    $0x4,%esi
 111e57e:	mov    (%r10,%rsi,1),%r15
 111e582:	mov    %ebx,%r9d
 111e585:	shl    $0x4,%r9d
 111e589:	mov    (%r10,%r9,1),%rcx
 111e58d:	cmp    %rcx,%r15
 111e590:	jne    111e5b2 <sort.block.block__anon_39129+0x1272>
 111e592:	add    %r10,%rsi
 111e595:	add    %r10,%r9
 111e598:	movzwl 0xe(%r9),%ecx
 111e59d:	movzwl 0xe(%rsi),%esi
 111e5a1:	cmp    %cx,%si
 111e5a4:	jb     111e5be <sort.block.block__anon_39129+0x127e>
 111e5a6:	cmp    %r12b,%r14b
 111e5a9:	jbe    111e5e5 <sort.block.block__anon_39129+0x12a5>
 111e5ab:	cmp    %si,%cx
 111e5ae:	jae    111e5be <sort.block.block__anon_39129+0x127e>
 111e5b0:	jmp    111e5e5 <sort.block.block__anon_39129+0x12a5>
 111e5b2:	jb     111e5be <sort.block.block__anon_39129+0x127e>
 111e5b4:	cmp    %r12b,%r14b
 111e5b7:	jbe    111e5e5 <sort.block.block__anon_39129+0x12a5>
 111e5b9:	cmp    %r15,%rcx
 111e5bc:	jb     111e5e5 <sort.block.block__anon_39129+0x12a5>
 111e5be:	mov    %ebx,%ecx
 111e5c0:	shr    $0x8,%ecx
 111e5c3:	mov    %edi,%esi
 111e5c5:	shr    $0x8,%esi
 111e5c8:	mov    %dil,0x6(%r8)
 111e5cc:	mov    %bl,0x8(%r8)
 111e5d0:	mov    %sil,0x7(%r8)
 111e5d4:	mov    %cl,0x9(%r8)
 111e5d8:	mov    -0x30(%rbp),%rcx
 111e5dc:	mov    (%rcx),%r10
 111e5df:	mov    %r12b,-0x58(%rbp)
 111e5e3:	jmp    111e5ec <sort.block.block__anon_39129+0x12ac>
 111e5e5:	mov    %r14b,-0x58(%rbp)
 111e5e9:	mov    %r12d,%r14d
 111e5ec:	movzwl 0xa(%r8),%edi
 111e5f1:	movzwl 0x4(%r8),%ebx
 111e5f6:	mov    %edi,%esi
 111e5f8:	shl    $0x4,%esi
 111e5fb:	mov    (%r10,%rsi,1),%rcx
 111e5ff:	mov    %ebx,%r12d
 111e602:	shl    $0x4,%r12d
 111e606:	mov    (%r10,%r12,1),%r9
 111e60a:	cmp    %r9,%rcx
 111e60d:	jne    111e61f <sort.block.block__anon_39129+0x12df>
 111e60f:	add    %r10,%rsi
 111e612:	add    %r10,%r12
 111e615:	movzwl 0xe(%rsi),%ecx
 111e619:	cmp    0xe(%r12),%cx
 111e61f:	jae    111e649 <sort.block.block__anon_39129+0x1309>
 111e621:	mov    %ebx,%ecx
 111e623:	shr    $0x8,%ecx
 111e626:	mov    %edi,%esi
 111e628:	shr    $0x8,%esi
 111e62b:	mov    %dil,0x4(%r8)
 111e62f:	mov    %bl,0xa(%r8)
 111e633:	mov    %sil,0x5(%r8)
 111e637:	mov    %cl,0xb(%r8)
 111e63b:	mov    -0x30(%rbp),%rcx
 111e63f:	mov    (%rcx),%r10
 111e642:	movzbl -0x50(%rbp),%ecx
 111e646:	mov    %ecx,-0x48(%rbp)
 111e649:	movzwl 0x6(%r8),%ecx
 111e64e:	movzwl (%r8),%edi
 111e652:	mov    %ecx,%esi
 111e654:	shl    $0x4,%esi
 111e657:	mov    (%r10,%rsi,1),%r9
 111e65b:	mov    %edi,%ebx
 111e65d:	shl    $0x4,%ebx
 111e660:	mov    (%r10,%rbx,1),%r12
 111e664:	cmp    %r12,%r9
 111e667:	jne    111e677 <sort.block.block__anon_39129+0x1337>
 111e669:	add    %r10,%rsi
 111e66c:	add    %r10,%rbx
 111e66f:	movzwl 0xe(%rsi),%esi
 111e673:	cmp    0xe(%rbx),%si
 111e677:	jae    111e69f <sort.block.block__anon_39129+0x135f>
 111e679:	mov    %edi,%esi
 111e67b:	shr    $0x8,%esi
 111e67e:	mov    %ecx,%r9d
 111e681:	shr    $0x8,%r9d
 111e685:	mov    %cl,(%r8)
 111e688:	mov    %dil,0x6(%r8)
 111e68c:	mov    %r9b,0x1(%r8)
 111e690:	mov    %sil,0x7(%r8)
 111e694:	mov    -0x30(%rbp),%rcx
 111e698:	mov    (%rcx),%r10
 111e69b:	mov    %r13b,-0x58(%rbp)
 111e69f:	movzwl 0x8(%r8),%ecx
 111e6a4:	movzwl 0x2(%r8),%ebx
 111e6a9:	mov    %ecx,%r12d
 111e6ac:	shl    $0x4,%r12d
 111e6b0:	mov    (%r10,%r12,1),%rdi
 111e6b4:	mov    %ebx,%esi
 111e6b6:	shl    $0x4,%esi
 111e6b9:	mov    (%r10,%rsi,1),%r9
 111e6bd:	mov    %ecx,%r13d
 111e6c0:	shr    $0x8,%r13d
 111e6c4:	cmp    %r9,%rdi
 111e6c7:	jne    111e6e4 <sort.block.block__anon_39129+0x13a4>
 111e6c9:	add    %r10,%r12
 111e6cc:	add    %r10,%rsi
 111e6cf:	movzwl 0xe(%r12),%r9d
 111e6d5:	cmp    0xe(%rsi),%r9w
 111e6da:	jb     111e6e6 <sort.block.block__anon_39129+0x13a6>
 111e6dc:	mov    %r11d,%r12d
 111e6df:	mov    %r14d,%r11d
 111e6e2:	jmp    111e71a <sort.block.block__anon_39129+0x13da>
 111e6e4:	jae    111e6dc <sort.block.block__anon_39129+0x139c>
 111e6e6:	mov    %ebx,%esi
 111e6e8:	shr    $0x8,%esi
 111e6eb:	mov    %cl,0x2(%r8)
 111e6ef:	mov    %bl,0x8(%r8)
 111e6f3:	mov    %r13b,0x3(%r8)
 111e6f7:	mov    %sil,0x9(%r8)
 111e6fb:	mov    -0x30(%rbp),%rcx
 111e6ff:	mov    (%rcx),%r10
 111e702:	movzwl 0x8(%r8),%ecx
 111e707:	mov    %ecx,%esi
 111e709:	shl    $0x4,%esi
 111e70c:	mov    (%r10,%rsi,1),%rdi
 111e710:	mov    %ecx,%r13d
 111e713:	shr    $0x8,%r13d
 111e717:	mov    %r14d,%r12d
 111e71a:	movzwl 0x4(%r8),%ebx
 111e71f:	mov    %ebx,%r9d
 111e722:	shl    $0x4,%r9d
 111e726:	mov    (%r10,%r9,1),%rsi
 111e72a:	cmp    %rsi,%rdi
 111e72d:	mov    -0x48(%rbp),%r15d
 111e731:	jne    111e757 <sort.block.block__anon_39129+0x1417>
 111e733:	add    %r10,%r9
 111e736:	movzwl 0xe(%r9),%esi
 111e73b:	mov    %ecx,%edi
 111e73d:	shl    $0x4,%edi
 111e740:	movzwl 0xe(%r10,%rdi,1),%edi
 111e746:	cmp    %si,%di
 111e749:	jb     111e763 <sort.block.block__anon_39129+0x1423>
 111e74b:	cmp    %r11b,%r15b
 111e74e:	jbe    111e782 <sort.block.block__anon_39129+0x1442>
 111e750:	cmp    %di,%si
 111e753:	jae    111e763 <sort.block.block__anon_39129+0x1423>
 111e755:	jmp    111e782 <sort.block.block__anon_39129+0x1442>
 111e757:	jb     111e763 <sort.block.block__anon_39129+0x1423>
 111e759:	cmp    %r11b,%r15b
 111e75c:	jbe    111e782 <sort.block.block__anon_39129+0x1442>
 111e75e:	cmp    %rdi,%rsi
 111e761:	jb     111e782 <sort.block.block__anon_39129+0x1442>
 111e763:	mov    %ebx,%esi
 111e765:	shr    $0x8,%esi
 111e768:	mov    %cl,0x4(%r8)
 111e76c:	mov    %bl,0x8(%r8)
 111e770:	mov    %r13b,0x5(%r8)
 111e774:	mov    %sil,0x9(%r8)
 111e778:	mov    -0x30(%rbp),%rcx
 111e77c:	mov    (%rcx),%r10
 111e77f:	mov    %r11d,%r15d
 111e782:	movzwl 0x6(%r8),%r11d
 111e787:	movzwl 0x2(%r8),%edi
 111e78c:	mov    %r11d,%ebx
 111e78f:	shl    $0x4,%ebx
 111e792:	mov    (%r10,%rbx,1),%r14
 111e796:	mov    %edi,%esi
 111e798:	shl    $0x4,%esi
 111e79b:	mov    (%r10,%rsi,1),%r13
 111e79f:	mov    %r11d,%ecx
 111e7a2:	shr    $0x8,%ecx
 111e7a5:	cmp    %r13,%r14
 111e7a8:	jne    111e7cd <sort.block.block__anon_39129+0x148d>
 111e7aa:	add    %r10,%rbx
 111e7ad:	add    %r10,%rsi
 111e7b0:	movzwl 0xe(%rsi),%esi
 111e7b4:	movzwl 0xe(%rbx),%r9d
 111e7b9:	cmp    %si,%r9w
 111e7bd:	jb     111e7da <sort.block.block__anon_39129+0x149a>
 111e7bf:	cmp    -0x58(%rbp),%r12b
 111e7c3:	jbe    111e80d <sort.block.block__anon_39129+0x14cd>
 111e7c5:	cmp    %r9w,%si
 111e7c9:	jae    111e7da <sort.block.block__anon_39129+0x149a>
 111e7cb:	jmp    111e80d <sort.block.block__anon_39129+0x14cd>
 111e7cd:	jb     111e7da <sort.block.block__anon_39129+0x149a>
 111e7cf:	cmp    -0x58(%rbp),%r12b
 111e7d3:	jbe    111e80d <sort.block.block__anon_39129+0x14cd>
 111e7d5:	cmp    %r14,%r13
 111e7d8:	jb     111e80d <sort.block.block__anon_39129+0x14cd>
 111e7da:	mov    %edi,%esi
 111e7dc:	shr    $0x8,%esi
 111e7df:	mov    %r11b,0x2(%r8)
 111e7e3:	mov    %dil,0x6(%r8)
 111e7e7:	mov    %cl,0x3(%r8)
 111e7eb:	mov    %sil,0x7(%r8)
 111e7ef:	mov    -0x30(%rbp),%rcx
 111e7f3:	mov    (%rcx),%r10
 111e7f6:	movzwl 0x6(%r8),%r11d
 111e7fb:	mov    %r11d,%ecx
 111e7fe:	shl    $0x4,%ecx
 111e801:	mov    (%r10,%rcx,1),%r14
 111e805:	mov    %r11d,%ecx
 111e808:	shr    $0x8,%ecx
 111e80b:	jmp    111e812 <sort.block.block__anon_39129+0x14d2>
 111e80d:	movzbl -0x58(%rbp),%r12d
 111e812:	movzwl 0x4(%r8),%edi
 111e817:	mov    %edi,%r9d
 111e81a:	shl    $0x4,%r9d
 111e81e:	mov    (%r10,%r9,1),%rsi
 111e822:	cmp    %rsi,%r14
 111e825:	mov    -0x40(%rbp),%r13
 111e829:	jne    111e85a <sort.block.block__anon_39129+0x151a>
 111e82b:	add    %r10,%r9
 111e82e:	movzwl 0xe(%r9),%esi
 111e833:	mov    %r11d,%r9d
 111e836:	shl    $0x4,%r9d
 111e83a:	movzwl 0xe(%r10,%r9,1),%r9d
 111e840:	cmp    %si,%r9w
 111e844:	jb     111e86e <sort.block.block__anon_39129+0x152e>
 111e846:	cmp    %r12b,%r15b
 111e849:	jbe    111d431 <sort.block.block__anon_39129+0xf1>
 111e84f:	cmp    %r9w,%si
 111e853:	jae    111e86e <sort.block.block__anon_39129+0x152e>
 111e855:	jmp    111d431 <sort.block.block__anon_39129+0xf1>
 111e85a:	jb     111e86e <sort.block.block__anon_39129+0x152e>
 111e85c:	cmp    %r12b,%r15b
 111e85f:	jbe    111d431 <sort.block.block__anon_39129+0xf1>
 111e865:	cmp    %r14,%rsi
 111e868:	jb     111d431 <sort.block.block__anon_39129+0xf1>
 111e86e:	mov    %edi,%r15d
 111e871:	shr    $0x8,%r15d
 111e875:	mov    %r11b,0x4(%r8)
 111e879:	mov    %dil,0x6(%r8)
 111e87d:	jmp    111ec91 <sort.block.block__anon_39129+0x1951>
 111e882:	mov    %r15d,%r14d
 111e885:	mov    %r13d,%r15d
 111e888:	movzwl 0xa(%r8),%edi
 111e88d:	movzwl 0x8(%r8),%ebx
 111e892:	mov    %edi,%esi
 111e894:	shl    $0x4,%esi
 111e897:	mov    (%r10,%rsi,1),%r13
 111e89b:	mov    %ebx,%r9d
 111e89e:	shl    $0x4,%r9d
 111e8a2:	mov    (%r10,%r9,1),%r11
 111e8a6:	cmp    %r11,%r13
 111e8a9:	jne    111e8cd <sort.block.block__anon_39129+0x158d>
 111e8ab:	add    %r10,%rsi
 111e8ae:	add    %r10,%r9
 111e8b1:	movzwl 0xe(%r9),%r9d
 111e8b6:	movzwl 0xe(%rsi),%esi
 111e8ba:	cmp    %r9w,%si
 111e8be:	jb     111e8d9 <sort.block.block__anon_39129+0x1599>
 111e8c0:	cmp    %cl,%r12b
 111e8c3:	jbe    111e901 <sort.block.block__anon_39129+0x15c1>
 111e8c5:	cmp    %si,%r9w
 111e8c9:	jae    111e8d9 <sort.block.block__anon_39129+0x1599>
 111e8cb:	jmp    111e901 <sort.block.block__anon_39129+0x15c1>
 111e8cd:	jb     111e8d9 <sort.block.block__anon_39129+0x1599>
 111e8cf:	cmp    %cl,%r12b
 111e8d2:	jbe    111e901 <sort.block.block__anon_39129+0x15c1>
 111e8d4:	cmp    %r13,%r11
 111e8d7:	jb     111e901 <sort.block.block__anon_39129+0x15c1>
 111e8d9:	mov    %ebx,%esi
 111e8db:	shr    $0x8,%esi
 111e8de:	mov    %edi,%r9d
 111e8e1:	shr    $0x8,%r9d
 111e8e5:	mov    %dil,0x8(%r8)
 111e8e9:	mov    %bl,0xa(%r8)
 111e8ed:	mov    %r9b,0x9(%r8)
 111e8f1:	mov    %sil,0xb(%r8)
 111e8f5:	mov    -0x30(%rbp),%rsi
 111e8f9:	mov    (%rsi),%r10
 111e8fc:	mov    %ecx,%r13d
 111e8ff:	jmp    111e907 <sort.block.block__anon_39129+0x15c7>
 111e901:	mov    %r12d,%r13d
 111e904:	mov    %ecx,%r12d
 111e907:	movzwl 0xc(%r8),%ecx
 111e90c:	movzwl 0x4(%r8),%edi
 111e911:	mov    %ecx,%esi
 111e913:	shl    $0x4,%esi
 111e916:	mov    (%r10,%rsi,1),%r9
 111e91a:	mov    %edi,%ebx
 111e91c:	shl    $0x4,%ebx
 111e91f:	mov    (%r10,%rbx,1),%r11
 111e923:	cmp    %r11,%r9
 111e926:	jne    111e936 <sort.block.block__anon_39129+0x15f6>
 111e928:	add    %r10,%rsi
 111e92b:	add    %r10,%rbx
 111e92e:	movzwl 0xe(%rsi),%esi
 111e932:	cmp    0xe(%rbx),%si
 111e936:	jae    111e962 <sort.block.block__anon_39129+0x1622>
 111e938:	mov    %edi,%esi
 111e93a:	shr    $0x8,%esi
 111e93d:	mov    %ecx,%r9d
 111e940:	shr    $0x8,%r9d
 111e944:	mov    %cl,0x4(%r8)
 111e948:	mov    %dil,0xc(%r8)
 111e94c:	mov    %r9b,0x5(%r8)
 111e950:	mov    %sil,0xd(%r8)
 111e954:	mov    -0x30(%rbp),%rcx
 111e958:	mov    (%rcx),%r10
 111e95b:	movzbl -0x58(%rbp),%ecx
 111e95f:	mov    %ecx,-0x48(%rbp)
 111e962:	movzwl 0x8(%r8),%ecx
 111e967:	movzwl (%r8),%edi
 111e96b:	mov    %ecx,%esi
 111e96d:	shl    $0x4,%esi
 111e970:	mov    (%r10,%rsi,1),%r11
 111e974:	mov    %edi,%r9d
 111e977:	shl    $0x4,%r9d
 111e97b:	mov    (%r10,%r9,1),%rbx
 111e97f:	cmp    %rbx,%r11
 111e982:	jne    111e99d <sort.block.block__anon_39129+0x165d>
 111e984:	add    %r10,%rsi
 111e987:	add    %r10,%r9
 111e98a:	movzwl 0xe(%rsi),%esi
 111e98e:	cmp    0xe(%r9),%si
 111e993:	jb     111e99f <sort.block.block__anon_39129+0x165f>
 111e995:	mov    %r14d,%r9d
 111e998:	mov    %r13d,%r14d
 111e99b:	jmp    111e9c4 <sort.block.block__anon_39129+0x1684>
 111e99d:	jae    111e995 <sort.block.block__anon_39129+0x1655>
 111e99f:	mov    %edi,%esi
 111e9a1:	shr    $0x8,%esi
 111e9a4:	mov    %ecx,%r9d
 111e9a7:	shr    $0x8,%r9d
 111e9ab:	mov    %cl,(%r8)
 111e9ae:	mov    %dil,0x8(%r8)
 111e9b2:	mov    %r9b,0x1(%r8)
 111e9b6:	mov    %sil,0x9(%r8)
 111e9ba:	mov    -0x30(%rbp),%rcx
 111e9be:	mov    (%rcx),%r10
 111e9c1:	mov    %r13d,%r9d
 111e9c4:	movzwl 0xa(%r8),%ecx
 111e9c9:	movzwl 0x2(%r8),%edi
 111e9ce:	mov    %ecx,%esi
 111e9d0:	shl    $0x4,%esi
 111e9d3:	mov    (%r10,%rsi,1),%r11
 111e9d7:	mov    %edi,%ebx
 111e9d9:	shl    $0x4,%ebx
 111e9dc:	mov    (%r10,%rbx,1),%r13
 111e9e0:	cmp    %r13,%r11
 111e9e3:	jne    111e9fd <sort.block.block__anon_39129+0x16bd>
 111e9e5:	add    %r10,%rsi
 111e9e8:	add    %r10,%rbx
 111e9eb:	movzwl 0xe(%rsi),%esi
 111e9ef:	cmp    0xe(%rbx),%si
 111e9f3:	jb     111e9ff <sort.block.block__anon_39129+0x16bf>
 111e9f5:	mov    %r15d,%ecx
 111e9f8:	mov    %r12d,%r15d
 111e9fb:	jmp    111ea25 <sort.block.block__anon_39129+0x16e5>
 111e9fd:	jae    111e9f5 <sort.block.block__anon_39129+0x16b5>
 111e9ff:	mov    %edi,%esi
 111ea01:	shr    $0x8,%esi
 111ea04:	mov    %ecx,%r10d
 111ea07:	shr    $0x8,%r10d
 111ea0b:	mov    %cl,0x2(%r8)
 111ea0f:	mov    %dil,0xa(%r8)
 111ea13:	mov    %r10b,0x3(%r8)
 111ea17:	mov    %sil,0xb(%r8)
 111ea1b:	mov    -0x30(%rbp),%rcx
 111ea1f:	mov    (%rcx),%r10
 111ea22:	mov    %r12d,%ecx
 111ea25:	movzwl 0x6(%r8),%edi
 111ea2a:	movzwl (%r8),%ebx
 111ea2e:	mov    %edi,%esi
 111ea30:	shl    $0x4,%esi
 111ea33:	mov    (%r10,%rsi,1),%r12
 111ea37:	mov    %ebx,%r13d
 111ea3a:	shl    $0x4,%r13d
 111ea3e:	mov    (%r10,%r13,1),%r11
 111ea42:	cmp    %r11,%r12
 111ea45:	jne    111ea6e <sort.block.block__anon_39129+0x172e>
 111ea47:	add    %r10,%rsi
 111ea4a:	add    %r10,%r13
 111ea4d:	movzwl 0xe(%r13),%r11d
 111ea52:	movzwl 0xe(%rsi),%esi
 111ea56:	cmp    %r11w,%si
 111ea5a:	mov    -0x40(%rbp),%r13
 111ea5e:	jb     111ea7f <sort.block.block__anon_39129+0x173f>
 111ea60:	cmp    -0x50(%rbp),%r9b
 111ea64:	jbe    111eaa5 <sort.block.block__anon_39129+0x1765>
 111ea66:	cmp    %si,%r11w
 111ea6a:	jae    111ea7f <sort.block.block__anon_39129+0x173f>
 111ea6c:	jmp    111eaa5 <sort.block.block__anon_39129+0x1765>
 111ea6e:	mov    -0x40(%rbp),%r13
 111ea72:	jb     111ea7f <sort.block.block__anon_39129+0x173f>
 111ea74:	cmp    -0x50(%rbp),%r9b
 111ea78:	jbe    111eaa5 <sort.block.block__anon_39129+0x1765>
 111ea7a:	cmp    %r12,%r11
 111ea7d:	jb     111eaa5 <sort.block.block__anon_39129+0x1765>
 111ea7f:	mov    %ebx,%esi
 111ea81:	shr    $0x8,%esi
 111ea84:	mov    %edi,%r10d
 111ea87:	shr    $0x8,%r10d
 111ea8b:	mov    %dil,(%r8)
 111ea8e:	mov    %bl,0x6(%r8)
 111ea92:	mov    %r10b,0x1(%r8)
 111ea96:	mov    %sil,0x7(%r8)
 111ea9a:	mov    -0x30(%rbp),%rsi
 111ea9e:	mov    (%rsi),%r10
 111eaa1:	mov    %r9b,-0x50(%rbp)
 111eaa5:	movzwl 0xa(%r8),%edi
 111eaaa:	movzwl 0x4(%r8),%r9d
 111eaaf:	mov    %edi,%esi
 111eab1:	shl    $0x4,%esi
 111eab4:	mov    (%r10,%rsi,1),%rbx
 111eab8:	mov    %r9d,%r12d
 111eabb:	shl    $0x4,%r12d
 111eabf:	mov    (%r10,%r12,1),%r11
 111eac3:	cmp    %r11,%rbx
 111eac6:	jne    111eaec <sort.block.block__anon_39129+0x17ac>
 111eac8:	add    %r10,%rsi
 111eacb:	add    %r10,%r12
 111eace:	movzwl 0xe(%r12),%r11d
 111ead4:	movzwl 0xe(%rsi),%esi
 111ead8:	cmp    %r11w,%si
 111eadc:	jb     111eaf9 <sort.block.block__anon_39129+0x17b9>
 111eade:	cmp    %r15b,-0x48(%rbp)
 111eae2:	jbe    111eb21 <sort.block.block__anon_39129+0x17e1>
 111eae4:	cmp    %si,%r11w
 111eae8:	jae    111eaf9 <sort.block.block__anon_39129+0x17b9>
 111eaea:	jmp    111eb21 <sort.block.block__anon_39129+0x17e1>
 111eaec:	jb     111eaf9 <sort.block.block__anon_39129+0x17b9>
 111eaee:	cmp    %r15b,-0x48(%rbp)
 111eaf2:	jbe    111eb21 <sort.block.block__anon_39129+0x17e1>
 111eaf4:	cmp    %rbx,%r11
 111eaf7:	jb     111eb21 <sort.block.block__anon_39129+0x17e1>
 111eaf9:	mov    %r9d,%esi
 111eafc:	shr    $0x8,%esi
 111eaff:	mov    %edi,%r10d
 111eb02:	shr    $0x8,%r10d
 111eb06:	mov    %dil,0x4(%r8)
 111eb0a:	mov    %r9b,0xa(%r8)
 111eb0e:	mov    %r10b,0x5(%r8)
 111eb12:	mov    %sil,0xb(%r8)
 111eb16:	mov    -0x30(%rbp),%rsi
 111eb1a:	mov    (%rsi),%r10
 111eb1d:	mov    %r15d,-0x48(%rbp)
 111eb21:	movzwl 0x6(%r8),%edi
 111eb26:	movzwl 0x2(%r8),%r9d
 111eb2b:	mov    %edi,%esi
 111eb2d:	shl    $0x4,%esi
 111eb30:	mov    (%r10,%rsi,1),%rbx
 111eb34:	mov    %r9d,%r15d
 111eb37:	shl    $0x4,%r15d
 111eb3b:	mov    (%r10,%r15,1),%r11
 111eb3f:	cmp    %r11,%rbx
 111eb42:	jne    111eb66 <sort.block.block__anon_39129+0x1826>
 111eb44:	add    %r10,%rsi
 111eb47:	add    %r10,%r15
 111eb4a:	movzwl 0xe(%r15),%r11d
 111eb4f:	movzwl 0xe(%rsi),%esi
 111eb53:	cmp    %r11w,%si
 111eb57:	jb     111eb72 <sort.block.block__anon_39129+0x1832>
 111eb59:	cmp    -0x50(%rbp),%cl
 111eb5c:	jbe    111eb99 <sort.block.block__anon_39129+0x1859>
 111eb5e:	cmp    %si,%r11w
 111eb62:	jae    111eb72 <sort.block.block__anon_39129+0x1832>
 111eb64:	jmp    111eb99 <sort.block.block__anon_39129+0x1859>
 111eb66:	jb     111eb72 <sort.block.block__anon_39129+0x1832>
 111eb68:	cmp    -0x50(%rbp),%cl
 111eb6b:	jbe    111eb99 <sort.block.block__anon_39129+0x1859>
 111eb6d:	cmp    %rbx,%r11
 111eb70:	jb     111eb99 <sort.block.block__anon_39129+0x1859>
 111eb72:	mov    %r9d,%esi
 111eb75:	shr    $0x8,%esi
 111eb78:	mov    %edi,%r10d
 111eb7b:	shr    $0x8,%r10d
 111eb7f:	mov    %dil,0x2(%r8)
 111eb83:	mov    %r9b,0x6(%r8)
 111eb87:	mov    %r10b,0x3(%r8)
 111eb8b:	mov    %sil,0x7(%r8)
 111eb8f:	mov    -0x30(%rbp),%rsi
 111eb93:	mov    (%rsi),%r10
 111eb96:	mov    %cl,-0x50(%rbp)
 111eb99:	movzwl 0x8(%r8),%edi
 111eb9e:	movzwl 0x4(%r8),%r9d
 111eba3:	mov    %edi,%r12d
 111eba6:	shl    $0x4,%r12d
 111ebaa:	mov    (%r10,%r12,1),%rbx
 111ebae:	mov    %r9d,%esi
 111ebb1:	shl    $0x4,%esi
 111ebb4:	mov    (%r10,%rsi,1),%rcx
 111ebb8:	mov    %r9d,%r15d
 111ebbb:	shr    $0x8,%r15d
 111ebbf:	cmp    %rcx,%rbx
 111ebc2:	jne    111ebe9 <sort.block.block__anon_39129+0x18a9>
 111ebc4:	add    %r10,%r12
 111ebc7:	add    %r10,%rsi
 111ebca:	movzwl 0xe(%rsi),%ecx
 111ebce:	movzwl 0xe(%r12),%esi
 111ebd4:	cmp    %cx,%si
 111ebd7:	jb     111ebf6 <sort.block.block__anon_39129+0x18b6>
 111ebd9:	cmp    %r14b,-0x48(%rbp)
 111ebdd:	jbe    111ebe4 <sort.block.block__anon_39129+0x18a4>
 111ebdf:	cmp    %si,%cx
 111ebe2:	jae    111ebf6 <sort.block.block__anon_39129+0x18b6>
 111ebe4:	mov    %rbx,%rcx
 111ebe7:	jmp    111ec2a <sort.block.block__anon_39129+0x18ea>
 111ebe9:	jb     111ebf6 <sort.block.block__anon_39129+0x18b6>
 111ebeb:	cmp    %r14b,-0x48(%rbp)
 111ebef:	jbe    111ec2a <sort.block.block__anon_39129+0x18ea>
 111ebf1:	cmp    %rbx,%rcx
 111ebf4:	jb     111ec2a <sort.block.block__anon_39129+0x18ea>
 111ebf6:	mov    %edi,%ecx
 111ebf8:	shr    $0x8,%ecx
 111ebfb:	mov    %dil,0x4(%r8)
 111ebff:	mov    %r9b,0x8(%r8)
 111ec03:	mov    %cl,0x5(%r8)
 111ec07:	mov    %r15b,0x9(%r8)
 111ec0b:	mov    -0x30(%rbp),%rcx
 111ec0f:	mov    (%rcx),%r10
 111ec12:	movzwl 0x4(%r8),%r9d
 111ec17:	mov    %r9d,%ecx
 111ec1a:	shl    $0x4,%ecx
 111ec1d:	mov    (%r10,%rcx,1),%rcx
 111ec21:	mov    %r9d,%r15d
 111ec24:	shr    $0x8,%r15d
 111ec28:	jmp    111ec30 <sort.block.block__anon_39129+0x18f0>
 111ec2a:	mov    -0x48(%rbp),%esi
 111ec2d:	mov    %esi,%r14d
 111ec30:	movzwl 0x6(%r8),%edi
 111ec35:	mov    %edi,%esi
 111ec37:	shl    $0x4,%esi
 111ec3a:	mov    (%r10,%rsi,1),%rbx
 111ec3e:	cmp    %rcx,%rbx
 111ec41:	jne    111ec6f <sort.block.block__anon_39129+0x192f>
 111ec43:	add    %r10,%rsi
 111ec46:	mov    %r9d,%ecx
 111ec49:	shl    $0x4,%ecx
 111ec4c:	movzwl 0xe(%r10,%rcx,1),%ecx
 111ec52:	movzwl 0xe(%rsi),%esi
 111ec56:	cmp    %cx,%si
 111ec59:	jb     111ec84 <sort.block.block__anon_39129+0x1944>
 111ec5b:	cmp    -0x50(%rbp),%r14b
 111ec5f:	jbe    111d431 <sort.block.block__anon_39129+0xf1>
 111ec65:	cmp    %si,%cx
 111ec68:	jae    111ec84 <sort.block.block__anon_39129+0x1944>
 111ec6a:	jmp    111d431 <sort.block.block__anon_39129+0xf1>
 111ec6f:	jb     111ec84 <sort.block.block__anon_39129+0x1944>
 111ec71:	cmp    -0x50(%rbp),%r14b
 111ec75:	jbe    111d431 <sort.block.block__anon_39129+0xf1>
 111ec7b:	cmp    %rbx,%rcx
 111ec7e:	jb     111d431 <sort.block.block__anon_39129+0xf1>
 111ec84:	mov    %edi,%ecx
 111ec86:	shr    $0x8,%ecx
 111ec89:	mov    %dil,0x4(%r8)
 111ec8d:	mov    %r9b,0x6(%r8)
 111ec91:	mov    $0x7,%edi
 111ec96:	mov    $0x5,%r9d
 111ec9c:	jmp    111d429 <sort.block.block__anon_39129+0xe9>
 111eca1:	mov    %r15d,%ecx
 111eca4:	mov    %r12d,%r15d
 111eca7:	movzwl 0x8(%r8),%edi
 111ecac:	movzwl 0x2(%r8),%r9d
 111ecb1:	mov    %edi,%esi
 111ecb3:	shl    $0x4,%esi
 111ecb6:	mov    (%r10,%rsi,1),%rbx
 111ecba:	mov    %r9d,%r11d
 111ecbd:	shl    $0x4,%r11d
 111ecc1:	mov    (%r10,%r11,1),%r12
 111ecc5:	cmp    %r12,%rbx
 111ecc8:	jne    111ecd9 <sort.block.block__anon_39129+0x1999>
 111ecca:	add    %r10,%rsi
 111eccd:	add    %r10,%r11
 111ecd0:	movzwl 0xe(%rsi),%esi
 111ecd4:	cmp    0xe(%r11),%si
 111ecd9:	jae    111ed05 <sort.block.block__anon_39129+0x19c5>
 111ecdb:	mov    %r9d,%esi
 111ecde:	shr    $0x8,%esi
 111ece1:	mov    %edi,%r10d
 111ece4:	shr    $0x8,%r10d
 111ece8:	mov    %dil,0x2(%r8)
 111ecec:	mov    %r9b,0x8(%r8)
 111ecf0:	mov    %r10b,0x3(%r8)
 111ecf4:	mov    %sil,0x9(%r8)
 111ecf8:	mov    -0x30(%rbp),%rsi
 111ecfc:	mov    (%rsi),%r10
 111ecff:	mov    %r14d,%esi
 111ed02:	mov    %esi,-0x50(%rbp)
 111ed05:	movzwl 0x6(%r8),%edi
 111ed0a:	movzwl (%r8),%r14d
 111ed0e:	mov    %edi,%ebx
 111ed10:	shl    $0x4,%ebx
 111ed13:	mov    (%r10,%rbx,1),%r11
 111ed17:	mov    %r14d,%esi
 111ed1a:	shl    $0x4,%esi
 111ed1d:	mov    (%r10,%rsi,1),%r9
 111ed21:	mov    %r14d,%r12d
 111ed24:	shr    $0x8,%r12d
 111ed28:	cmp    %r9,%r11
 111ed2b:	jne    111ed44 <sort.block.block__anon_39129+0x1a04>
 111ed2d:	add    %r10,%rbx
 111ed30:	add    %r10,%rsi
 111ed33:	movzwl 0xe(%rbx),%r9d
 111ed38:	cmp    0xe(%rsi),%r9w
 111ed3d:	jb     111ed46 <sort.block.block__anon_39129+0x1a06>
 111ed3f:	mov    %r11,%r9
 111ed42:	jmp    111ed7b <sort.block.block__anon_39129+0x1a3b>
 111ed44:	jae    111ed7b <sort.block.block__anon_39129+0x1a3b>
 111ed46:	mov    %edi,%esi
 111ed48:	shr    $0x8,%esi
 111ed4b:	mov    %dil,(%r8)
 111ed4e:	mov    %r14b,0x6(%r8)
 111ed52:	mov    %sil,0x1(%r8)
 111ed56:	mov    %r12b,0x7(%r8)
 111ed5a:	mov    -0x30(%rbp),%rsi
 111ed5e:	mov    (%rsi),%r10
 111ed61:	movzwl (%r8),%r14d
 111ed65:	mov    %r14d,%esi
 111ed68:	shl    $0x4,%esi
 111ed6b:	mov    (%r10,%rsi,1),%r9
 111ed6f:	mov    %r14d,%r12d
 111ed72:	shr    $0x8,%r12d
 111ed76:	mov    %r15d,%edi
 111ed79:	jmp    111ed86 <sort.block.block__anon_39129+0x1a46>
 111ed7b:	mov    -0x48(%rbp),%esi
 111ed7e:	mov    %esi,%edi
 111ed80:	mov    %r15d,%esi
 111ed83:	mov    %esi,-0x48(%rbp)
 111ed86:	movzwl 0x4(%r8),%r11d
 111ed8b:	mov    %r11d,%esi
 111ed8e:	shl    $0x4,%esi
 111ed91:	mov    (%r10,%rsi,1),%rbx
 111ed95:	cmp    %r9,%rbx
 111ed98:	jne    111edc1 <sort.block.block__anon_39129+0x1a81>
 111ed9a:	add    %r10,%rsi
 111ed9d:	mov    %r14d,%r9d
 111eda0:	shl    $0x4,%r9d
 111eda4:	movzwl 0xe(%r10,%r9,1),%r9d
 111edaa:	movzwl 0xe(%rsi),%esi
 111edae:	cmp    %r9w,%si
 111edb2:	jb     111edcd <sort.block.block__anon_39129+0x1a8d>
 111edb4:	cmp    %cl,%dil
 111edb7:	jbe    111edeb <sort.block.block__anon_39129+0x1aab>
 111edb9:	cmp    %si,%r9w
 111edbd:	jae    111edcd <sort.block.block__anon_39129+0x1a8d>
 111edbf:	jmp    111edeb <sort.block.block__anon_39129+0x1aab>
 111edc1:	jb     111edcd <sort.block.block__anon_39129+0x1a8d>
 111edc3:	cmp    %cl,%dil
 111edc6:	jbe    111edeb <sort.block.block__anon_39129+0x1aab>
 111edc8:	cmp    %rbx,%r9
 111edcb:	jb     111edeb <sort.block.block__anon_39129+0x1aab>
 111edcd:	mov    %r11d,%ecx
 111edd0:	shr    $0x8,%ecx
 111edd3:	mov    %r11b,(%r8)
 111edd6:	mov    %r14b,0x4(%r8)
 111edda:	mov    %cl,0x1(%r8)
 111edde:	mov    %r12b,0x5(%r8)
 111ede2:	mov    -0x30(%rbp),%rcx
 111ede6:	mov    (%rcx),%r10
 111ede9:	mov    %edi,%ecx
 111edeb:	movzwl 0x6(%r8),%r9d
 111edf0:	movzwl 0x2(%r8),%r14d
 111edf5:	mov    %r9d,%ebx
 111edf8:	shl    $0x4,%ebx
 111edfb:	mov    (%r10,%rbx,1),%r11
 111edff:	mov    %r14d,%esi
 111ee02:	shl    $0x4,%esi
 111ee05:	mov    (%r10,%rsi,1),%rdi
 111ee09:	mov    %r14d,%r15d
 111ee0c:	shr    $0x8,%r15d
 111ee10:	cmp    %rdi,%r11
 111ee13:	jne    111ee3d <sort.block.block__anon_39129+0x1afd>
 111ee15:	add    %r10,%rbx
 111ee18:	add    %r10,%rsi
 111ee1b:	movzwl 0xe(%rsi),%esi
 111ee1f:	movzwl 0xe(%rbx),%edi
 111ee23:	cmp    %si,%di
 111ee26:	mov    -0x48(%rbp),%ebx
 111ee29:	jb     111ee54 <sort.block.block__anon_39129+0x1b14>
 111ee2b:	cmp    %bl,-0x50(%rbp)
 111ee2e:	jbe    111ee35 <sort.block.block__anon_39129+0x1af5>
 111ee30:	cmp    %di,%si
 111ee33:	jae    111ee54 <sort.block.block__anon_39129+0x1b14>
 111ee35:	mov    %r11,%rdi
 111ee38:	mov    -0x50(%rbp),%ebx
 111ee3b:	jmp    111ee87 <sort.block.block__anon_39129+0x1b47>
 111ee3d:	mov    -0x48(%rbp),%ebx
 111ee40:	jb     111ee54 <sort.block.block__anon_39129+0x1b14>
 111ee42:	cmp    %bl,-0x50(%rbp)
 111ee45:	jbe    111f023 <sort.block.block__anon_39129+0x1ce3>
 111ee4b:	cmp    %r11,%rdi
 111ee4e:	jb     111f023 <sort.block.block__anon_39129+0x1ce3>
 111ee54:	mov    %r9d,%esi
 111ee57:	shr    $0x8,%esi
 111ee5a:	mov    %r9b,0x2(%r8)
 111ee5e:	mov    %r14b,0x6(%r8)
 111ee62:	mov    %sil,0x3(%r8)
 111ee66:	mov    %r15b,0x7(%r8)
 111ee6a:	mov    -0x30(%rbp),%rsi
 111ee6e:	mov    (%rsi),%r10
 111ee71:	movzwl 0x2(%r8),%r14d
 111ee76:	mov    %r14d,%esi
 111ee79:	shl    $0x4,%esi
 111ee7c:	mov    (%r10,%rsi,1),%rdi
 111ee80:	mov    %r14d,%r15d
 111ee83:	shr    $0x8,%r15d
 111ee87:	movzwl 0x4(%r8),%r9d
 111ee8c:	mov    %r9d,%esi
 111ee8f:	shl    $0x4,%esi
 111ee92:	mov    (%r10,%rsi,1),%r11
 111ee96:	cmp    %rdi,%r11
 111ee99:	jne    111eecd <sort.block.block__anon_39129+0x1b8d>
 111ee9b:	add    %r10,%rsi
 111ee9e:	mov    %r14d,%edi
 111eea1:	shl    $0x4,%edi
 111eea4:	movzwl 0xe(%r10,%rdi,1),%edi
 111eeaa:	movzwl 0xe(%rsi),%esi
 111eeae:	cmp    %di,%si
 111eeb1:	jb     111d410 <sort.block.block__anon_39129+0xd0>
 111eeb7:	cmp    %cl,%bl
 111eeb9:	jbe    111d431 <sort.block.block__anon_39129+0xf1>
 111eebf:	cmp    %si,%di
 111eec2:	jae    111d410 <sort.block.block__anon_39129+0xd0>
 111eec8:	jmp    111d431 <sort.block.block__anon_39129+0xf1>
 111eecd:	jb     111d410 <sort.block.block__anon_39129+0xd0>
 111eed3:	cmp    %cl,%bl
 111eed5:	jbe    111d431 <sort.block.block__anon_39129+0xf1>
 111eedb:	cmp    %r11,%rdi
 111eede:	jae    111d410 <sort.block.block__anon_39129+0xd0>
 111eee4:	jmp    111d431 <sort.block.block__anon_39129+0xf1>
 111eee9:	mov    $0x3,%r10b
 111eeec:	mov    $0x2,%r11b
 111eeef:	mov    %rbx,%rdi
 111eef2:	movzwl (%r8),%ebx
 111eef6:	mov    %ebx,%esi
 111eef8:	shl    $0x4,%esi
 111eefb:	cmp    (%rcx,%rsi,1),%rdi
 111eeff:	jne    111ef1a <sort.block.block__anon_39129+0x1bda>
 111ef01:	mov    %r13,%r9
 111ef04:	add    %rcx,%rsi
 111ef07:	mov    %r15d,%edi
 111ef0a:	shl    $0x4,%edi
 111ef0d:	movzwl 0xe(%rcx,%rdi,1),%edi
 111ef12:	cmp    0xe(%rsi),%di
 111ef16:	jb     111ef1f <sort.block.block__anon_39129+0x1bdf>
 111ef18:	jmp    111ef3d <sort.block.block__anon_39129+0x1bfd>
 111ef1a:	mov    %r13,%r9
 111ef1d:	jae    111ef3d <sort.block.block__anon_39129+0x1bfd>
 111ef1f:	mov    %ebx,%ecx
 111ef21:	shr    $0x8,%ecx
 111ef24:	mov    %r15b,(%r8)
 111ef27:	mov    %bl,0x4(%r8)
 111ef2b:	mov    %r12b,0x1(%r8)
 111ef2f:	mov    %cl,0x5(%r8)
 111ef33:	mov    -0x30(%rbp),%rcx
 111ef37:	mov    (%rcx),%rcx
 111ef3a:	mov    %r14d,%r11d
 111ef3d:	movzwl 0x6(%r8),%ebx
 111ef42:	movzwl 0x2(%r8),%r14d
 111ef47:	mov    %ebx,%r13d
 111ef4a:	shl    $0x4,%r13d
 111ef4e:	mov    (%rcx,%r13,1),%r12
 111ef52:	mov    %r14d,%esi
 111ef55:	shl    $0x4,%esi
 111ef58:	mov    (%rcx,%rsi,1),%rdi
 111ef5c:	mov    %r14d,%r15d
 111ef5f:	shr    $0x8,%r15d
 111ef63:	cmp    %rdi,%r12
 111ef66:	jne    111ef81 <sort.block.block__anon_39129+0x1c41>
 111ef68:	add    %rcx,%r13
 111ef6b:	add    %rcx,%rsi
 111ef6e:	movzwl 0xe(%r13),%edi
 111ef73:	cmp    0xe(%rsi),%di
 111ef77:	mov    %r9,%r13
 111ef7a:	jb     111ef86 <sort.block.block__anon_39129+0x1c46>
 111ef7c:	mov    %r12,%rdi
 111ef7f:	jmp    111efba <sort.block.block__anon_39129+0x1c7a>
 111ef81:	mov    %r9,%r13
 111ef84:	jae    111efba <sort.block.block__anon_39129+0x1c7a>
 111ef86:	mov    %ebx,%ecx
 111ef88:	shr    $0x8,%ecx
 111ef8b:	mov    %bl,0x2(%r8)
 111ef8f:	mov    %r14b,0x6(%r8)
 111ef93:	mov    %cl,0x3(%r8)
 111ef97:	mov    %r15b,0x7(%r8)
 111ef9b:	mov    -0x30(%rbp),%rcx
 111ef9f:	mov    (%rcx),%rcx
 111efa2:	movzwl 0x2(%r8),%r14d
 111efa7:	mov    %r14d,%esi
 111efaa:	shl    $0x4,%esi
 111efad:	mov    (%rcx,%rsi,1),%rdi
 111efb1:	mov    %r14d,%r15d
 111efb4:	shr    $0x8,%r15d
 111efb8:	jmp    111efc0 <sort.block.block__anon_39129+0x1c80>
 111efba:	mov    -0x48(%rbp),%esi
 111efbd:	mov    %esi,%r10d
 111efc0:	movzwl 0x4(%r8),%r9d
 111efc5:	mov    %r9d,%esi
 111efc8:	shl    $0x4,%esi
 111efcb:	mov    (%rcx,%rsi,1),%rbx
 111efcf:	cmp    %rdi,%rbx
 111efd2:	jne    111f006 <sort.block.block__anon_39129+0x1cc6>
 111efd4:	add    %rcx,%rsi
 111efd7:	mov    %r14d,%edi
 111efda:	shl    $0x4,%edi
 111efdd:	movzwl 0xe(%rcx,%rdi,1),%ecx
 111efe2:	movzwl 0xe(%rsi),%esi
 111efe6:	cmp    %cx,%si
 111efe9:	jb     111d410 <sort.block.block__anon_39129+0xd0>
 111efef:	cmp    %r11b,%r10b
 111eff2:	jbe    111d431 <sort.block.block__anon_39129+0xf1>
 111eff8:	cmp    %si,%cx
 111effb:	jae    111d410 <sort.block.block__anon_39129+0xd0>
 111f001:	jmp    111d431 <sort.block.block__anon_39129+0xf1>
 111f006:	jb     111d410 <sort.block.block__anon_39129+0xd0>
 111f00c:	cmp    %r11b,%r10b
 111f00f:	jbe    111d431 <sort.block.block__anon_39129+0xf1>
 111f015:	cmp    %rbx,%rdi
 111f018:	jae    111d410 <sort.block.block__anon_39129+0xd0>
 111f01e:	jmp    111d431 <sort.block.block__anon_39129+0xf1>
 111f023:	mov    -0x50(%rbp),%ebx
 111f026:	jmp    111ee87 <sort.block.block__anon_39129+0x1b47>
 111f02b:	cmp    $0x8,%rsi
 111f02f:	mov    -0x38(%rbp),%r10
 111f033:	jb     112698d <sort.block.block__anon_39129+0x964d>
 111f039:	mov    %rdi,%rdx
 111f03c:	lea    -0x2(%r10),%r13
 111f040:	lea    0x60(%r10),%rax
 111f044:	mov    %rax,-0xc8(%rbp)
 111f04b:	lea    -0x3e(%r10),%rax
 111f04f:	mov    %rax,-0x228(%rbp)
 111f056:	lea    -0x1e(%r10),%rax
 111f05a:	mov    %rax,-0x1b8(%rbp)
 111f061:	lea    0x1(%r10),%rax
 111f065:	mov    %rax,-0x50(%rbp)
 111f069:	lea    0x7(%r10),%rax
 111f06d:	mov    %rax,-0x80(%rbp)
 111f071:	lea    -0x42(%r10),%rax
 111f075:	mov    %rax,-0x250(%rbp)
 111f07c:	lea    0x22(%r10),%rax
 111f080:	mov    %rax,-0x220(%rbp)
 111f087:	lea    0x2(%r10),%rax
 111f08b:	mov    %rax,-0x138(%rbp)
 111f092:	lea    -0x3(%r10),%rax
 111f096:	mov    %rax,-0x148(%rbp)
 111f09d:	lea    0x4(%r10),%rax
 111f0a1:	mov    %rax,-0x218(%rbp)
 111f0a8:	lea    -0x22(%r10),%rax
 111f0ac:	mov    %rax,-0x1e0(%rbp)
 111f0b3:	vmovdqa -0x11c89b(%rip),%ymm2        # 1002820 <__anon_38908+0x60>
 111f0bb:	lea    0x62(%r10),%rax
 111f0bf:	mov    %rax,-0x1d8(%rbp)
 111f0c6:	lea    -0x20(%r10),%rax
 111f0ca:	mov    %rax,-0x58(%rbp)
 111f0ce:	lea    -0x1(%r10),%rax
 111f0d2:	mov    %rax,-0x48(%rbp)
 111f0d6:	lea    0x3(%r10),%rax
 111f0da:	mov    %rax,-0x1c0(%rbp)
 111f0e1:	lea    0x9(%r10),%rax
 111f0e5:	mov    %rax,-0x1b0(%rbp)
 111f0ec:	lea    -0x3c(%r10),%rax
 111f0f0:	mov    %rax,-0x210(%rbp)
 111f0f7:	lea    -0x1c(%r10),%rax
 111f0fb:	mov    %rax,-0x208(%rbp)
 111f102:	mov    %r13,-0x98(%rbp)
 111f109:	jmp    111f158 <sort.block.block__anon_39129+0x1e18>
 111f10b:	nopl   0x0(%rax,%rax,1)
 111f110:	mov    -0xf8(%rbp),%rax
 111f117:	mov    -0x38(%rbp),%r10
 111f11b:	add    %rax,%rax
 111f11e:	xor    %ecx,%ecx
 111f120:	mov    -0x120(%rbp),%rsi
 111f127:	cmp    %rsi,%rax
 111f12a:	setae  %cl
 111f12d:	mov    $0x0,%edx
 111f132:	cmovae %rsi,%rdx
 111f136:	sub    %rdx,%rax
 111f139:	mov    -0xb8(%rbp),%rdx
 111f140:	lea    (%rcx,%rdx,2),%rdx
 111f144:	mov    %rax,-0xf8(%rbp)
 111f14b:	cmp    -0x118(%rbp),%rdx
 111f152:	jae    112698d <sort.block.block__anon_39129+0x964d>
 111f158:	cmp    $0x200,%rdx
 111f15f:	mov    %rdx,-0xb8(%rbp)
 111f166:	jae    111f3f0 <sort.block.block__anon_39129+0x20b0>
 111f16c:	lea    0x0(,%rdx,4),%rsi
 111f174:	cmp    $0x7f,%rdx
 111f178:	seta   %al
 111f17b:	cmp    -0x118(%rbp),%rsi
 111f182:	seta   %cl
 111f185:	or     %al,%cl
 111f187:	je     111f480 <sort.block.block__anon_39129+0x2140>
 111f18d:	xor    %r8d,%r8d
 111f190:	xor    %edi,%edi
 111f192:	jmp    111f214 <sort.block.block__anon_39129+0x1ed4>
 111f197:	nopw   0x0(%rax,%rax,1)
 111f1a0:	mov    %r8,%r14
 111f1a3:	sub    %r12,%r14
 111f1a6:	mov    %r15,%r13
 111f1a9:	sub    %r12,%r13
 111f1ac:	mov    %rdi,-0x40(%rbp)
 111f1b0:	mov    %r9,%rdi
 111f1b3:	mov    %rsi,-0x68(%rbp)
 111f1b7:	mov    %r13,%rsi
 111f1ba:	mov    %r8,%r12
 111f1bd:	mov    %r9,%rbx
 111f1c0:	vzeroupper 
 111f1c3:	call   10fd040 <mem.reverse__anon_36385>
 111f1c8:	mov    -0x38(%rbp),%rax
 111f1cc:	lea    (%rax,%r15,2),%rdi
 111f1d0:	mov    %r14,%rsi
 111f1d3:	sub    %r13,%rsi
 111f1d6:	call   10fd040 <mem.reverse__anon_36385>
 111f1db:	mov    %rbx,%rdi
 111f1de:	mov    %r14,%rsi
 111f1e1:	call   10fd040 <mem.reverse__anon_36385>
 111f1e6:	mov    -0x68(%rbp),%rsi
 111f1ea:	mov    %r12,%r8
 111f1ed:	mov    -0x40(%rbp),%rdi
 111f1f1:	vmovdqa -0x11c9d9(%rip),%ymm2        # 1002820 <__anon_38908+0x60>
 111f1f9:	mov    -0x38(%rbp),%r10
 111f1fd:	sub    %rsi,%rdi
 111f200:	cmp    -0x118(%rbp),%r8
 111f207:	mov    -0xb8(%rbp),%rdx
 111f20e:	jae    111fd50 <sort.block.block__anon_39129+0x2a10>
 111f214:	mov    %r8,%r12
 111f217:	lea    (%r8,%rdx,1),%r15
 111f21b:	mov    -0xf8(%rbp),%rsi
 111f222:	add    %rsi,%rdi
 111f225:	mov    -0x120(%rbp),%rcx
 111f22c:	cmp    %rcx,%rdi
 111f22f:	mov    $0x0,%eax
 111f234:	cmovae %rcx,%rax
 111f238:	sbb    $0xffffffffffffffff,%r15
 111f23c:	sub    %rax,%rdi
 111f23f:	lea    (%r15,%rdx,1),%r8
 111f243:	add    %rsi,%rdi
 111f246:	cmp    %rcx,%rdi
 111f249:	mov    $0x0,%esi
 111f24e:	cmovae %rcx,%rsi
 111f252:	sbb    $0xffffffffffffffff,%r8
 111f256:	movzwl -0x2(%r10,%r8,2),%eax
 111f25c:	lea    (%r10,%r12,2),%r9
 111f260:	movzwl (%r10,%r12,2),%ecx
 111f265:	mov    -0x30(%rbp),%rdx
 111f269:	mov    (%rdx),%r13
 111f26c:	shl    $0x4,%eax
 111f26f:	shl    $0x4,%ecx
 111f272:	mov    0x0(%r13,%rcx,1),%rdx
 111f277:	cmp    %rdx,0x0(%r13,%rax,1)
 111f27c:	jne    111f28c <sort.block.block__anon_39129+0x1f4c>
 111f27e:	add    %r13,%rax
 111f281:	add    %r13,%rcx
 111f284:	movzwl 0xe(%rax),%eax
 111f288:	cmp    0xe(%rcx),%ax
 111f28c:	jb     111f1a0 <sort.block.block__anon_39129+0x1e60>
 111f292:	movzwl (%r10,%r15,2),%r14d
 111f297:	movzwl -0x2(%r10,%r15,2),%eax
 111f29d:	mov    %r14d,%ecx
 111f2a0:	shl    $0x4,%ecx
 111f2a3:	mov    0x0(%r13,%rcx,1),%rbx
 111f2a8:	shl    $0x4,%eax
 111f2ab:	cmp    0x0(%r13,%rax,1),%rbx
 111f2b0:	jne    111f2d0 <sort.block.block__anon_39129+0x1f90>
 111f2b2:	add    %r13,%rcx
 111f2b5:	add    %r13,%rax
 111f2b8:	movzwl 0xe(%rcx),%ecx
 111f2bc:	cmp    0xe(%rax),%cx
 111f2c0:	jae    111f1fd <sort.block.block__anon_39129+0x1ebd>
 111f2c6:	jmp    111f2d6 <sort.block.block__anon_39129+0x1f96>
 111f2c8:	nopl   0x0(%rax,%rax,1)
 111f2d0:	jae    111f1fd <sort.block.block__anon_39129+0x1ebd>
 111f2d6:	mov    %rsi,-0x68(%rbp)
 111f2da:	mov    %rdi,-0x40(%rbp)
 111f2de:	mov    %r15,%rax
 111f2e1:	sub    %r12,%rax
 111f2e4:	sete   -0x70(%rbp)
 111f2e8:	mov    %rax,-0x78(%rbp)
 111f2ec:	lea    (%rax,%rax,1),%rdx
 111f2f0:	lea    -0x650(%rbp),%rdi
 111f2f7:	mov    %r9,%rsi
 111f2fa:	mov    %r8,-0x60(%rbp)
 111f2fe:	vzeroupper 
 111f301:	call   119d8c0 <compiler_rt.memcpy.memcpyFast>
 111f306:	mov    -0x60(%rbp),%r9
 111f30a:	cmp    %r15,%r9
 111f30d:	sete   %al
 111f310:	or     -0x70(%rbp),%al
 111f313:	je     111f324 <sort.block.block__anon_39129+0x1fe4>
 111f315:	xor    %eax,%eax
 111f317:	mov    -0x38(%rbp),%r8
 111f31b:	mov    -0x78(%rbp),%r10
 111f31f:	jmp    111f3ab <sort.block.block__anon_39129+0x206b>
 111f324:	lea    0x1(%r12),%rcx
 111f329:	xor    %eax,%eax
 111f32b:	mov    -0x38(%rbp),%r8
 111f32f:	mov    -0x78(%rbp),%r10
 111f333:	jmp    111f36b <sort.block.block__anon_39129+0x202b>
 111f335:	data16 cs nopw 0x0(%rax,%rax,1)
 111f340:	mov    %dx,-0x2(%r8,%rcx,2)
 111f346:	inc    %rax
 111f349:	cmp    %r10,%rax
 111f34c:	je     111f3a5 <sort.block.block__anon_39129+0x2065>
 111f34e:	inc    %r12
 111f351:	movzwl (%r8,%r15,2),%r14d
 111f356:	mov    -0x30(%rbp),%rdx
 111f35a:	mov    (%rdx),%r13
 111f35d:	mov    %r14d,%edx
 111f360:	shl    $0x4,%edx
 111f363:	mov    0x0(%r13,%rdx,1),%rbx
 111f368:	inc    %rcx
 111f36b:	movzwl -0x650(%rbp,%rax,2),%edx
 111f373:	mov    %edx,%esi
 111f375:	shl    $0x4,%esi
 111f378:	cmp    0x0(%r13,%rsi,1),%rbx
 111f37d:	jne    111f393 <sort.block.block__anon_39129+0x2053>
 111f37f:	add    %r13,%rsi
 111f382:	movzwl %r14w,%edi
 111f386:	shl    $0x4,%edi
 111f389:	movzwl 0xe(%r13,%rdi,1),%edi
 111f38f:	cmp    0xe(%rsi),%di
 111f393:	jae    111f340 <sort.block.block__anon_39129+0x2000>
 111f395:	mov    %r14w,-0x2(%r8,%rcx,2)
 111f39b:	inc    %r15
 111f39e:	cmp    %r9,%r15
 111f3a1:	jne    111f34e <sort.block.block__anon_39129+0x200e>
 111f3a3:	jmp    111f3a8 <sort.block.block__anon_39129+0x2068>
 111f3a5:	mov    %r10,%rax
 111f3a8:	mov    %rcx,%r12
 111f3ab:	lea    -0x650(,%rax,2),%rsi
 111f3b3:	add    %rbp,%rsi
 111f3b6:	sub    %rax,%r10
 111f3b9:	lea    (%r8,%r12,2),%rdi
 111f3bd:	add    %r10,%r10
 111f3c0:	mov    %r10,%rdx
 111f3c3:	call   119d8c0 <compiler_rt.memcpy.memcpyFast>
 111f3c8:	mov    -0x38(%rbp),%r10
 111f3cc:	vmovdqa -0x11cbb4(%rip),%ymm2        # 1002820 <__anon_38908+0x60>
 111f3d4:	mov    -0x40(%rbp),%rdi
 111f3d8:	mov    -0x60(%rbp),%r8
 111f3dc:	mov    -0x68(%rbp),%rsi
 111f3e0:	jmp    111f1fd <sort.block.block__anon_39129+0x1ebd>
 111f3e5:	data16 cs nopw 0x0(%rax,%rax,1)
 111f3f0:	movabs $0x4000000000000000,%rcx
 111f3fa:	nopw   0x0(%rax,%rax,1)
 111f400:	mov    %rcx,%rax
 111f403:	shr    $0x2,%rcx
 111f407:	cmp    %rdx,%rax
 111f40a:	ja     111f400 <sort.block.block__anon_39129+0x20c0>
 111f40c:	mov    %rdx,%rcx
 111f40f:	xor    %esi,%esi
 111f411:	mov    %rax,%rdx
 111f414:	xor    %r9d,%r9d
 111f417:	nopw   0x0(%rax,%rax,1)
 111f420:	lea    (%rax,%rsi,1),%rdi
 111f424:	mov    %rsi,%r8
 111f427:	shr    %r8
 111f42a:	cmp    %rdi,%rcx
 111f42d:	mov    %rax,%rsi
 111f430:	cmovb  %r9,%rsi
 111f434:	cmovb  %r9,%rdi
 111f438:	add    %r8,%rsi
 111f43b:	sub    %rdi,%rcx
 111f43e:	shr    $0x2,%rdx
 111f442:	cmp    $0x3,%rax
 111f446:	mov    %rdx,%rax
 111f449:	ja     111f420 <sort.block.block__anon_39129+0x20e0>
 111f44b:	mov    -0xb8(%rbp),%rax
 111f452:	mov    %rax,%rcx
 111f455:	or     %rsi,%rcx
 111f458:	shr    $0x20,%rcx
 111f45c:	je     111fd99 <sort.block.block__anon_39129+0x2a59>
 111f462:	mov    %rax,%rcx
 111f465:	xor    %edx,%edx
 111f467:	div    %rsi
 111f46a:	mov    %rax,%r8
 111f46d:	jmp    111fda3 <sort.block.block__anon_39129+0x2a63>
 111f472:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 111f480:	lea    (%rdx,%rdx,1),%rax
 111f484:	mov    $0x1,%ecx
 111f489:	mov    %rax,-0xd8(%rbp)
 111f490:	sub    %rax,%rcx
 111f493:	mov    %rcx,-0x130(%rbp)
 111f49a:	mov    $0x1,%eax
 111f49f:	mov    %rsi,-0x108(%rbp)
 111f4a6:	sub    %rsi,%rax
 111f4a9:	mov    %rax,-0x128(%rbp)
 111f4b0:	xor    %r15d,%r15d
 111f4b3:	xor    %r11d,%r11d
 111f4b6:	jmp    111f4d4 <sort.block.block__anon_39129+0x2194>
 111f4b8:	nopl   0x0(%rax,%rax,1)
 111f4c0:	sub    -0xe0(%rbp),%r11
 111f4c7:	cmp    -0x118(%rbp),%r15
 111f4ce:	jae    111fd70 <sort.block.block__anon_39129+0x2a30>
 111f4d4:	mov    %r15,%rbx
 111f4d7:	lea    (%r15,%rdx,1),%r12
 111f4db:	mov    -0xf8(%rbp),%rsi
 111f4e2:	add    %rsi,%r11
 111f4e5:	xor    %edi,%edi
 111f4e7:	mov    -0x120(%rbp),%rcx
 111f4ee:	cmp    %rcx,%r11
 111f4f1:	setae  %dil
 111f4f5:	mov    $0x0,%eax
 111f4fa:	cmovae %rcx,%rax
 111f4fe:	sub    %rax,%r11
 111f501:	mov    %rdi,-0xe8(%rbp)
 111f508:	add    %rdi,%r12
 111f50b:	lea    (%r12,%rdx,1),%r14
 111f50f:	add    %rsi,%r11
 111f512:	xor    %r9d,%r9d
 111f515:	cmp    %rcx,%r11
 111f518:	setae  %r9b
 111f51c:	mov    $0x0,%eax
 111f521:	cmovae %rcx,%rax
 111f525:	sub    %rax,%r11
 111f528:	add    %r9,%r14
 111f52b:	lea    (%r14,%rdx,1),%rdi
 111f52f:	add    %rsi,%r11
 111f532:	xor    %r8d,%r8d
 111f535:	cmp    %rcx,%r11
 111f538:	setae  %r8b
 111f53c:	mov    $0x0,%eax
 111f541:	cmovae %rcx,%rax
 111f545:	sub    %rax,%r11
 111f548:	mov    %r8,-0x100(%rbp)
 111f54f:	add    %r8,%rdi
 111f552:	mov    %rdi,-0x78(%rbp)
 111f556:	lea    (%rdi,%rdx,1),%r15
 111f55a:	add    %rsi,%r11
 111f55d:	xor    %edx,%edx
 111f55f:	cmp    %rcx,%r11
 111f562:	setae  %dl
 111f565:	mov    $0x0,%eax
 111f56a:	cmovae %rcx,%rax
 111f56e:	mov    %rax,-0xe0(%rbp)
 111f575:	mov    %rdx,-0xb0(%rbp)
 111f57c:	add    %rdx,%r15
 111f57f:	movzwl -0x2(%r10,%r14,2),%eax
 111f585:	mov    -0x30(%rbp),%rcx
 111f589:	mov    (%rcx),%r13
 111f58c:	shl    $0x4,%eax
 111f58f:	lea    (%rax,%r13,1),%rdi
 111f593:	mov    0x0(%r13,%rax,1),%r8
 111f598:	movzwl (%r10,%rbx,2),%eax
 111f59d:	mov    %eax,%edx
 111f59f:	shl    $0x4,%edx
 111f5a2:	lea    (%r10,%rbx,2),%rcx
 111f5a6:	mov    %rcx,-0x90(%rbp)
 111f5ad:	mov    0x0(%r13,%rdx,1),%rcx
 111f5b2:	cmp    %rcx,%r8
 111f5b5:	mov    %rbx,-0x60(%rbp)
 111f5b9:	mov    %r14,-0x68(%rbp)
 111f5bd:	mov    %r11,-0xc0(%rbp)
 111f5c4:	mov    %r9,-0x88(%rbp)
 111f5cb:	mov    %r15,-0x70(%rbp)
 111f5cf:	jne    111f5dc <sort.block.block__anon_39129+0x229c>
 111f5d1:	add    %r13,%rdx
 111f5d4:	movzwl 0xe(%rdi),%esi
 111f5d8:	cmp    0xe(%rdx),%si
 111f5dc:	jae    111f630 <sort.block.block__anon_39129+0x22f0>
 111f5de:	mov    %r12,%rdx
 111f5e1:	sub    %rbx,%rdx
 111f5e4:	mov    -0x68(%rbp),%r14
 111f5e8:	sub    %r12,%r14
 111f5eb:	lea    -0x650(,%r14,2),%rdi
 111f5f3:	add    %rbp,%rdi
 111f5f6:	add    %rdx,%rdx
 111f5f9:	mov    -0x90(%rbp),%rsi
 111f600:	mov    %r10,%rbx
 111f603:	vzeroupper 
 111f606:	call   119d8c0 <compiler_rt.memcpy.memcpyFast>
 111f60b:	lea    (%rbx,%r12,2),%rsi
 111f60f:	add    %r14,%r14
 111f612:	lea    -0x650(%rbp),%rdi
 111f619:	mov    %r14,%rdx
 111f61c:	mov    -0x68(%rbp),%r14
 111f620:	jmp    111f83c <sort.block.block__anon_39129+0x24fc>
 111f625:	data16 cs nopw 0x0(%rax,%rax,1)
 111f630:	movzwl (%r10,%r12,2),%edx
 111f635:	movzwl -0x2(%r10,%r12,2),%r9d
 111f63b:	mov    %edx,%r10d
 111f63e:	shl    $0x4,%r10d
 111f642:	mov    0x0(%r13,%r10,1),%rsi
 111f647:	shl    $0x4,%r9d
 111f64b:	cmp    0x0(%r13,%r9,1),%rsi
 111f650:	jne    111f662 <sort.block.block__anon_39129+0x2322>
 111f652:	add    %r13,%r10
 111f655:	add    %r13,%r9
 111f658:	movzwl 0xe(%r10),%r10d
 111f65d:	cmp    0xe(%r9),%r10w
 111f662:	jae    111f760 <sort.block.block__anon_39129+0x2420>
 111f668:	mov    -0x130(%rbp),%r11
 111f66f:	sub    %rbx,%r11
 111f672:	sub    -0xe8(%rbp),%r11
 111f679:	sub    -0x88(%rbp),%r11
 111f680:	mov    %rbx,%r9
 111f683:	mov    %r12,%r15
 111f686:	xor    %r8d,%r8d
 111f689:	mov    -0x38(%rbp),%r10
 111f68d:	mov    %r11,-0x110(%rbp)
 111f694:	movzwl %ax,%edi
 111f697:	shl    $0x4,%edi
 111f69a:	lea    (%rdi,%r13,1),%rbx
 111f69e:	add    $0xe,%rbx
 111f6a2:	mov    -0x138(%rbp),%rdi
 111f6a9:	lea    (%rdi,%r15,2),%r14
 111f6ad:	lea    (%r11,%r15,1),%rdi
 111f6b1:	mov    %r8,-0x40(%rbp)
 111f6b5:	lea    -0x650(,%r8,2),%r8
 111f6bd:	add    %rbp,%r8
 111f6c0:	xor    %r11d,%r11d
 111f6c3:	cmp    %rcx,%rsi
 111f6c6:	jne    111f6e6 <sort.block.block__anon_39129+0x23a6>
 111f6c8:	nopl   0x0(%rax,%rax,1)
 111f6d0:	movzwl %dx,%r10d
 111f6d4:	shl    $0x4,%r10d
 111f6d8:	movzwl 0xe(%r13,%r10,1),%r10d
 111f6de:	cmp    (%rbx),%r10w
 111f6e2:	mov    -0x38(%rbp),%r10
 111f6e6:	jae    111f720 <sort.block.block__anon_39129+0x23e0>
 111f6e8:	mov    %dx,(%r8,%r11,2)
 111f6ed:	mov    %rdi,%rdx
 111f6f0:	add    %r11,%rdx
 111f6f3:	je     111f7c0 <sort.block.block__anon_39129+0x2480>
 111f6f9:	movzwl (%r14,%r11,2),%edx
 111f6fe:	mov    %edx,%esi
 111f700:	shl    $0x4,%esi
 111f703:	mov    0x0(%r13,%rsi,1),%rsi
 111f708:	inc    %r11
 111f70b:	cmp    %rcx,%rsi
 111f70e:	je     111f6d0 <sort.block.block__anon_39129+0x2390>
 111f710:	jmp    111f6e6 <sort.block.block__anon_39129+0x23a6>
 111f712:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 111f720:	mov    %ax,(%r8,%r11,2)
 111f725:	inc    %r9
 111f728:	cmp    %r12,%r9
 111f72b:	je     111fcd0 <sort.block.block__anon_39129+0x2990>
 111f731:	mov    -0x40(%rbp),%r8
 111f735:	add    %r11,%r8
 111f738:	inc    %r8
 111f73b:	add    %r11,%r15
 111f73e:	movzwl (%r10,%r9,2),%eax
 111f743:	mov    %eax,%ecx
 111f745:	shl    $0x4,%ecx
 111f748:	mov    0x0(%r13,%rcx,1),%rcx
 111f74d:	mov    -0x110(%rbp),%r11
 111f754:	jmp    111f694 <sort.block.block__anon_39129+0x2354>
 111f759:	nopl   0x0(%rax)
 111f760:	mov    -0x38(%rbp),%r10
 111f764:	mov    -0x78(%rbp),%rcx
 111f768:	movzwl (%r10,%rcx,2),%eax
 111f76d:	movzwl -0x2(%r10,%rcx,2),%ecx
 111f773:	shl    $0x4,%eax
 111f776:	shl    $0x4,%ecx
 111f779:	mov    0x0(%r13,%rcx,1),%rdx
 111f77e:	cmp    %rdx,0x0(%r13,%rax,1)
 111f783:	jne    111f793 <sort.block.block__anon_39129+0x2453>
 111f785:	add    %r13,%rax
 111f788:	add    %r13,%rcx
 111f78b:	movzwl 0xe(%rax),%eax
 111f78f:	cmp    0xe(%rcx),%ax
 111f793:	mov    -0xb8(%rbp),%rdx
 111f79a:	jb     111f7f9 <sort.block.block__anon_39129+0x24b9>
 111f79c:	movzwl (%r10,%r14,2),%eax
 111f7a1:	shl    $0x4,%eax
 111f7a4:	cmp    %r8,0x0(%r13,%rax,1)
 111f7a9:	jne    111f7f3 <sort.block.block__anon_39129+0x24b3>
 111f7ab:	add    %r13,%rax
 111f7ae:	movzwl 0xe(%rax),%eax
 111f7b2:	cmp    0xe(%rdi),%ax
 111f7b6:	jae    111f4c0 <sort.block.block__anon_39129+0x2180>
 111f7bc:	jmp    111f7f9 <sort.block.block__anon_39129+0x24b9>
 111f7be:	xchg   %ax,%ax
 111f7c0:	sub    %r9,%r12
 111f7c3:	mov    -0x40(%rbp),%rax
 111f7c7:	add    %r11,%rax
 111f7ca:	inc    %rax
 111f7cd:	lea    (%r10,%r9,2),%rsi
 111f7d1:	lea    -0x650(,%rax,2),%rdi
 111f7d9:	add    %rbp,%rdi
 111f7dc:	add    %r12,%r12
 111f7df:	mov    %r12,%rdx
 111f7e2:	mov    %r10,%rbx
 111f7e5:	vzeroupper 
 111f7e8:	call   119d8c0 <compiler_rt.memcpy.memcpyFast>
 111f7ed:	mov    -0x68(%rbp),%r14
 111f7f1:	jmp    111f841 <sort.block.block__anon_39129+0x2501>
 111f7f3:	jae    111f4c0 <sort.block.block__anon_39129+0x2180>
 111f7f9:	lea    (%r10,%r12,2),%r15
 111f7fd:	mov    %r12,%r14
 111f800:	sub    %rbx,%r14
 111f803:	lea    (%r14,%r14,1),%rdx
 111f807:	lea    -0x650(%rbp),%rdi
 111f80e:	mov    -0x90(%rbp),%rsi
 111f815:	mov    %r10,%rbx
 111f818:	vzeroupper 
 111f81b:	call   119d8c0 <compiler_rt.memcpy.memcpyFast>
 111f820:	mov    -0x68(%rbp),%rdx
 111f824:	sub    %r12,%rdx
 111f827:	lea    -0x650(,%r14,2),%rdi
 111f82f:	add    %rbp,%rdi
 111f832:	mov    -0x68(%rbp),%r14
 111f836:	add    %rdx,%rdx
 111f839:	mov    %r15,%rsi
 111f83c:	call   119d8c0 <compiler_rt.memcpy.memcpyFast>
 111f841:	mov    -0x70(%rbp),%rax
 111f845:	movzwl -0x2(%rbx,%rax,2),%ecx
 111f84a:	lea    (%rbx,%r14,2),%rsi
 111f84e:	movzwl (%rbx,%r14,2),%eax
 111f853:	shl    $0x4,%ecx
 111f856:	mov    %eax,%edi
 111f858:	shl    $0x4,%edi
 111f85b:	mov    0x0(%r13,%rdi,1),%rdx
 111f860:	cmp    %rdx,0x0(%r13,%rcx,1)
 111f865:	mov    %rbx,%r9
 111f868:	mov    %rsi,-0x110(%rbp)
 111f86f:	jne    111f87f <sort.block.block__anon_39129+0x253f>
 111f871:	add    %r13,%rcx
 111f874:	add    %r13,%rdi
 111f877:	movzwl 0xe(%rcx),%ecx
 111f87b:	cmp    0xe(%rdi),%cx
 111f87f:	mov    -0x60(%rbp),%r11
 111f883:	jae    111f8e0 <sort.block.block__anon_39129+0x25a0>
 111f885:	mov    -0x78(%rbp),%rbx
 111f889:	mov    %rbx,%rdx
 111f88c:	sub    %r14,%rdx
 111f88f:	mov    %r14,%rax
 111f892:	sub    %r11,%rax
 111f895:	mov    -0x70(%rbp),%r15
 111f899:	mov    %r15,%r14
 111f89c:	sub    %rbx,%r14
 111f89f:	mov    %rax,-0x40(%rbp)
 111f8a3:	lea    -0x650(,%rax,2),%r12
 111f8ab:	add    %rbp,%r12
 111f8ae:	lea    (%r12,%r14,2),%rdi
 111f8b2:	add    %rdx,%rdx
 111f8b5:	call   119d8c0 <compiler_rt.memcpy.memcpyFast>
 111f8ba:	mov    -0x38(%rbp),%rax
 111f8be:	lea    (%rax,%rbx,2),%rsi
 111f8c2:	mov    -0x60(%rbp),%rbx
 111f8c6:	add    %r14,%r14
 111f8c9:	mov    %r12,%rdi
 111f8cc:	mov    %r14,%rdx
 111f8cf:	jmp    111fa85 <sort.block.block__anon_39129+0x2745>
 111f8d4:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 111f8e0:	mov    -0x78(%rbp),%rcx
 111f8e4:	movzwl (%r9,%rcx,2),%r10d
 111f8e9:	movzwl -0x2(%r9,%rcx,2),%ecx
 111f8ef:	mov    %r10d,%r8d
 111f8f2:	shl    $0x4,%r8d
 111f8f6:	mov    0x0(%r13,%r8,1),%rdi
 111f8fb:	shl    $0x4,%ecx
 111f8fe:	cmp    0x0(%r13,%rcx,1),%rdi
 111f903:	jne    111f915 <sort.block.block__anon_39129+0x25d5>
 111f905:	add    %r13,%r8
 111f908:	add    %r13,%rcx
 111f90b:	movzwl 0xe(%r8),%r8d
 111f910:	cmp    0xe(%rcx),%r8w
 111f915:	jae    111fa30 <sort.block.block__anon_39129+0x26f0>
 111f91b:	mov    %r14,%rcx
 111f91e:	sub    %r11,%rcx
 111f921:	mov    %rcx,-0x40(%rbp)
 111f925:	lea    -0x650(,%rcx,2),%rsi
 111f92d:	add    %rbp,%rsi
 111f930:	mov    -0x128(%rbp),%r15
 111f937:	sub    %r11,%r15
 111f93a:	sub    -0xe8(%rbp),%r15
 111f941:	sub    -0x88(%rbp),%r15
 111f948:	sub    -0x100(%rbp),%r15
 111f94f:	sub    -0xb0(%rbp),%r15
 111f956:	mov    %r14,%r11
 111f959:	mov    -0x78(%rbp),%r8
 111f95d:	xor    %ebx,%ebx
 111f95f:	mov    %rsi,-0x140(%rbp)
 111f966:	movzwl %ax,%ecx
 111f969:	shl    $0x4,%ecx
 111f96c:	lea    (%rcx,%r13,1),%r14
 111f970:	add    $0xe,%r14
 111f974:	mov    -0x138(%rbp),%rcx
 111f97b:	lea    (%rcx,%r8,2),%r12
 111f97f:	mov    %r8,-0xa8(%rbp)
 111f986:	lea    (%r15,%r8,1),%r9
 111f98a:	mov    %rbx,-0xa0(%rbp)
 111f991:	lea    (%rsi,%rbx,2),%rcx
 111f995:	xor    %ebx,%ebx
 111f997:	cmp    %rdx,%rdi
 111f99a:	jne    111f9b2 <sort.block.block__anon_39129+0x2672>
 111f99c:	nopl   0x0(%rax)
 111f9a0:	movzwl %r10w,%r8d
 111f9a4:	shl    $0x4,%r8d
 111f9a8:	movzwl 0xe(%r13,%r8,1),%r8d
 111f9ae:	cmp    (%r14),%r8w
 111f9b2:	jae    111f9e0 <sort.block.block__anon_39129+0x26a0>
 111f9b4:	mov    %r10w,(%rcx,%rbx,2)
 111f9b9:	mov    %r9,%rsi
 111f9bc:	add    %rbx,%rsi
 111f9bf:	je     111fa90 <sort.block.block__anon_39129+0x2750>
 111f9c5:	movzwl (%r12,%rbx,2),%r10d
 111f9ca:	mov    %r10d,%edi
 111f9cd:	shl    $0x4,%edi
 111f9d0:	mov    0x0(%r13,%rdi,1),%rdi
 111f9d5:	inc    %rbx
 111f9d8:	cmp    %rdx,%rdi
 111f9db:	je     111f9a0 <sort.block.block__anon_39129+0x2660>
 111f9dd:	jmp    111f9b2 <sort.block.block__anon_39129+0x2672>
 111f9df:	nop
 111f9e0:	mov    %ax,(%rcx,%rbx,2)
 111f9e4:	inc    %r11
 111f9e7:	cmp    -0x78(%rbp),%r11
 111f9eb:	je     111fd08 <sort.block.block__anon_39129+0x29c8>
 111f9f1:	mov    -0xa0(%rbp),%rax
 111f9f8:	add    %rbx,%rax
 111f9fb:	inc    %rax
 111f9fe:	mov    -0xa8(%rbp),%r8
 111fa05:	add    %rbx,%r8
 111fa08:	mov    %rax,%rbx
 111fa0b:	mov    -0x38(%rbp),%rax
 111fa0f:	movzwl (%rax,%r11,2),%eax
 111fa14:	mov    %eax,%ecx
 111fa16:	shl    $0x4,%ecx
 111fa19:	mov    0x0(%r13,%rcx,1),%rdx
 111fa1e:	mov    -0x140(%rbp),%rsi
 111fa25:	jmp    111f966 <sort.block.block__anon_39129+0x2626>
 111fa2a:	nopw   0x0(%rax,%rax,1)
 111fa30:	mov    -0x78(%rbp),%r14
 111fa34:	lea    (%r9,%r14,2),%rax
 111fa38:	mov    %rax,-0x88(%rbp)
 111fa3f:	mov    %r14,%rbx
 111fa42:	sub    -0x68(%rbp),%rbx
 111fa46:	mov    -0x68(%rbp),%rax
 111fa4a:	sub    -0x60(%rbp),%rax
 111fa4e:	mov    %rax,-0x40(%rbp)
 111fa52:	lea    -0x650(,%rax,2),%r12
 111fa5a:	add    %rbp,%r12
 111fa5d:	lea    (%rbx,%rbx,1),%rdx
 111fa61:	mov    %r12,%rdi
 111fa64:	call   119d8c0 <compiler_rt.memcpy.memcpyFast>
 111fa69:	mov    -0x70(%rbp),%r15
 111fa6d:	mov    %r15,%rdx
 111fa70:	sub    %r14,%rdx
 111fa73:	lea    (%r12,%rbx,2),%rdi
 111fa77:	mov    -0x60(%rbp),%rbx
 111fa7b:	add    %rdx,%rdx
 111fa7e:	mov    -0x88(%rbp),%rsi
 111fa85:	mov    -0x68(%rbp),%r14
 111fa89:	call   119d8c0 <compiler_rt.memcpy.memcpyFast>
 111fa8e:	jmp    111facb <sort.block.block__anon_39129+0x278b>
 111fa90:	mov    -0x78(%rbp),%rdx
 111fa94:	sub    %r11,%rdx
 111fa97:	mov    -0xa0(%rbp),%rax
 111fa9e:	add    %rbx,%rax
 111faa1:	inc    %rax
 111faa4:	mov    -0x38(%rbp),%rcx
 111faa8:	lea    (%rcx,%r11,2),%rsi
 111faac:	mov    -0x140(%rbp),%rcx
 111fab3:	lea    (%rcx,%rax,2),%rdi
 111fab7:	add    %rdx,%rdx
 111faba:	call   119d8c0 <compiler_rt.memcpy.memcpyFast>
 111fabf:	mov    -0x70(%rbp),%r15
 111fac3:	mov    -0x60(%rbp),%rbx
 111fac7:	mov    -0x68(%rbp),%r14
 111facb:	mov    %r15,%r12
 111face:	sub    %r14,%r12
 111fad1:	mov    %r15,%rdx
 111fad4:	sub    %rbx,%rdx
 111fad7:	movzwl -0x652(%rbp,%rdx,2),%ecx
 111fadf:	movzwl -0x650(%rbp),%eax
 111fae6:	shl    $0x4,%ecx
 111fae9:	mov    %eax,%esi
 111faeb:	shl    $0x4,%esi
 111faee:	mov    0x0(%r13,%rsi,1),%r10
 111faf3:	cmp    %r10,0x0(%r13,%rcx,1)
 111faf8:	jne    111fb08 <sort.block.block__anon_39129+0x27c8>
 111fafa:	add    %r13,%rcx
 111fafd:	add    %r13,%rsi
 111fb00:	movzwl 0xe(%rcx),%ecx
 111fb04:	cmp    0xe(%rsi),%cx
 111fb08:	jae    111fb40 <sort.block.block__anon_39129+0x2800>
 111fb0a:	mov    -0x90(%rbp),%rbx
 111fb11:	lea    (%rbx,%r12,2),%rdi
 111fb15:	mov    -0x40(%rbp),%r14
 111fb19:	lea    (%r14,%r14,1),%rdx
 111fb1d:	lea    -0x650(%rbp),%rsi
 111fb24:	call   119d8c0 <compiler_rt.memcpy.memcpyFast>
 111fb29:	lea    -0x650(,%r14,2),%rsi
 111fb31:	add    %rbp,%rsi
 111fb34:	add    %r12,%r12
 111fb37:	mov    %rbx,%rdi
 111fb3a:	jmp    111fc72 <sort.block.block__anon_39129+0x2932>
 111fb3f:	nop
 111fb40:	mov    -0x40(%rbp),%rsi
 111fb44:	movzwl -0x650(%rbp,%rsi,2),%ecx
 111fb4c:	movzwl -0x652(%rbp,%rsi,2),%esi
 111fb54:	mov    %ecx,%edi
 111fb56:	shl    $0x4,%edi
 111fb59:	mov    0x0(%r13,%rdi,1),%r14
 111fb5e:	shl    $0x4,%esi
 111fb61:	cmp    0x0(%r13,%rsi,1),%r14
 111fb66:	jne    111fb76 <sort.block.block__anon_39129+0x2836>
 111fb68:	add    %r13,%rdi
 111fb6b:	add    %r13,%rsi
 111fb6e:	movzwl 0xe(%rdi),%edi
 111fb72:	cmp    0xe(%rsi),%di
 111fb76:	jae    111fc40 <sort.block.block__anon_39129+0x2900>
 111fb7c:	mov    $0x1,%edi
 111fb81:	xor    %r9d,%r9d
 111fb84:	mov    -0x40(%rbp),%rsi
 111fb88:	xor    %r8d,%r8d
 111fb8b:	mov    -0x90(%rbp),%r12
 111fb92:	jmp    111fbbb <sort.block.block__anon_39129+0x287b>
 111fb94:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 111fba0:	mov    -0x30(%rbp),%r10
 111fba4:	mov    (%r10),%r13
 111fba7:	shl    $0x4,%ebx
 111fbaa:	mov    0x0(%r13,%rbx,1),%r14
 111fbaf:	shl    $0x4,%r11d
 111fbb3:	mov    0x0(%r13,%r11,1),%r10
 111fbb8:	inc    %rdi
 111fbbb:	movzwl %cx,%ebx
 111fbbe:	movzwl %ax,%r11d
 111fbc2:	cmp    %r10,%r14
 111fbc5:	jne    111fbe1 <sort.block.block__anon_39129+0x28a1>
 111fbc7:	mov    %r11d,%r10d
 111fbca:	shl    $0x4,%r10d
 111fbce:	mov    %ebx,%r14d
 111fbd1:	shl    $0x4,%r14d
 111fbd5:	movzwl 0xe(%r13,%r14,1),%r14d
 111fbdb:	cmp    0xe(%r13,%r10,1),%r14w
 111fbe1:	jae    111fc10 <sort.block.block__anon_39129+0x28d0>
 111fbe3:	mov    %cx,-0x2(%r12,%rdi,2)
 111fbe9:	lea    0x1(%rsi),%r10
 111fbed:	cmp    %rdx,%r10
 111fbf0:	je     111fc77 <sort.block.block__anon_39129+0x2937>
 111fbf6:	inc    %r8
 111fbf9:	movzwl -0x64e(%rbp,%rsi,2),%ecx
 111fc01:	movzwl %cx,%ebx
 111fc04:	mov    %r10,%rsi
 111fc07:	jmp    111fba0 <sort.block.block__anon_39129+0x2860>
 111fc09:	nopl   0x0(%rax)
 111fc10:	mov    %ax,-0x2(%r12,%rdi,2)
 111fc16:	lea    0x1(%r9),%r10
 111fc1a:	cmp    -0x40(%rbp),%r10
 111fc1e:	je     111fc83 <sort.block.block__anon_39129+0x2943>
 111fc20:	inc    %r8
 111fc23:	movzwl -0x64e(%rbp,%r9,2),%eax
 111fc2c:	movzwl %ax,%r11d
 111fc30:	mov    %r10,%r9
 111fc33:	jmp    111fba0 <sort.block.block__anon_39129+0x2860>
 111fc38:	nopl   0x0(%rax,%rax,1)
 111fc40:	mov    -0x40(%rbp),%rdx
 111fc44:	lea    -0x650(,%rdx,2),%r14
 111fc4c:	add    %rbp,%r14
 111fc4f:	add    %rdx,%rdx
 111fc52:	mov    -0x90(%rbp),%rdi
 111fc59:	lea    -0x650(%rbp),%rsi
 111fc60:	call   119d8c0 <compiler_rt.memcpy.memcpyFast>
 111fc65:	add    %r12,%r12
 111fc68:	mov    -0x110(%rbp),%rdi
 111fc6f:	mov    %r14,%rsi
 111fc72:	mov    %r12,%rdx
 111fc75:	jmp    111fc98 <sort.block.block__anon_39129+0x2958>
 111fc77:	mov    -0x40(%rbp),%rdx
 111fc7b:	sub    %r9,%rdx
 111fc7e:	mov    %r9,%rsi
 111fc81:	jmp    111fc86 <sort.block.block__anon_39129+0x2946>
 111fc83:	sub    %rsi,%rdx
 111fc86:	lea    -0x650(,%rsi,2),%rsi
 111fc8e:	add    %rbp,%rsi
 111fc91:	lea    (%r12,%rdi,2),%rdi
 111fc95:	add    %rdx,%rdx
 111fc98:	call   119d8c0 <compiler_rt.memcpy.memcpyFast>
 111fc9d:	mov    -0x38(%rbp),%r10
 111fca1:	mov    -0xb8(%rbp),%rdx
 111fca8:	vmovdqa -0x11d490(%rip),%ymm2        # 1002820 <__anon_38908+0x60>
 111fcb0:	mov    -0xc0(%rbp),%r11
 111fcb7:	sub    -0xe0(%rbp),%r11
 111fcbe:	cmp    -0x118(%rbp),%r15
 111fcc5:	jb     111f4d4 <sort.block.block__anon_39129+0x2194>
 111fccb:	jmp    111fd70 <sort.block.block__anon_39129+0x2a30>
 111fcd0:	mov    -0xd8(%rbp),%rax
 111fcd7:	mov    -0x60(%rbp),%rcx
 111fcdb:	lea    (%rax,%rcx,1),%r12
 111fcdf:	add    -0x88(%rbp),%r12
 111fce6:	add    -0xe8(%rbp),%r12
 111fced:	sub    %r15,%r12
 111fcf0:	add    %r11,%r15
 111fcf3:	sub    %r11,%r12
 111fcf6:	mov    -0x40(%rbp),%rax
 111fcfa:	add    %r11,%rax
 111fcfd:	inc    %rax
 111fd00:	mov    %r15,%r9
 111fd03:	jmp    111f7cd <sort.block.block__anon_39129+0x248d>
 111fd08:	mov    -0x108(%rbp),%rax
 111fd0f:	mov    -0x60(%rbp),%rcx
 111fd13:	add    %rcx,%rax
 111fd16:	mov    -0x88(%rbp),%rdx
 111fd1d:	add    %rax,%rdx
 111fd20:	add    -0x100(%rbp),%rdx
 111fd27:	add    -0xb0(%rbp),%rdx
 111fd2e:	add    -0xe8(%rbp),%rdx
 111fd35:	mov    -0xa8(%rbp),%r11
 111fd3c:	sub    %r11,%rdx
 111fd3f:	add    %rbx,%r11
 111fd42:	sub    %rbx,%rdx
 111fd45:	jmp    111fa97 <sort.block.block__anon_39129+0x2757>
 111fd4a:	nopw   0x0(%rax,%rax,1)
 111fd50:	mov    -0xf8(%rbp),%rax
 111fd57:	mov    -0x98(%rbp),%r13
 111fd5e:	jmp    111f11b <sort.block.block__anon_39129+0x1ddb>
 111fd63:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 111fd70:	mov    -0xf8(%rbp),%rcx
 111fd77:	add    %rcx,%rcx
 111fd7a:	mov    %rcx,%rax
 111fd7d:	sub    -0x120(%rbp),%rax
 111fd84:	jae    1120532 <sort.block.block__anon_39129+0x31f2>
 111fd8a:	mov    %rcx,%rax
 111fd8d:	mov    -0xd8(%rbp),%rcx
 111fd94:	jmp    112053d <sort.block.block__anon_39129+0x31fd>
 111fd99:	mov    %rax,%rcx
 111fd9c:	xor    %edx,%edx
 111fd9e:	div    %esi
 111fda0:	mov    %eax,%r8d
 111fda3:	lea    0x2(,%r8,2),%rdx
 111fdab:	cmp    %rcx,%rdx
 111fdae:	seta   %al
 111fdb1:	lea    0x1(%r8),%rdi
 111fdb5:	mov    %rdx,-0xe0(%rbp)
 111fdbc:	cmova  %rdi,%rdx
 111fdc0:	cmp    $0x201,%rsi
 111fdc7:	setae  %r9b
 111fdcb:	mov    %rdi,-0x88(%rbp)
 111fdd2:	cmovb  %rdi,%rdx
 111fdd6:	mov    %rdx,-0x40(%rbp)
 111fdda:	vpxor  %xmm0,%xmm0,%xmm0
 111fdde:	vmovdqu %ymm0,-0x1a0(%rbp)
 111fde6:	vmovdqu %ymm0,-0x180(%rbp)
 111fdee:	vmovdqu %ymm0,-0x170(%rbp)
 111fdf6:	and    %al,%r9b
 111fdf9:	mov    %r9d,-0xc0(%rbp)
 111fe00:	movq   $0x0,-0xb0(%rbp)
 111fe0b:	movq   $0x0,-0xd0(%rbp)
 111fe16:	xor    %r12d,%r12d
 111fe19:	xor    %edi,%edi
 111fe1b:	xor    %r9d,%r9d
 111fe1e:	mov    %rcx,%rdx
 111fe21:	mov    %r8,-0x68(%rbp)
 111fe25:	jmp    111fe49 <sort.block.block__anon_39129+0x2b09>
 111fe27:	xor    %r12d,%r12d
 111fe2a:	mov    -0xa0(%rbp),%rdi
 111fe31:	mov    -0x78(%rbp),%rax
 111fe35:	mov    -0x60(%rbp),%r9
 111fe39:	sub    %rax,%r9
 111fe3c:	cmp    -0x118(%rbp),%rdi
 111fe43:	jae    11205e0 <sort.block.block__anon_39129+0x32a0>
 111fe49:	mov    %rdi,%r11
 111fe4c:	lea    (%rdi,%rdx,1),%r15
 111fe50:	mov    -0xf8(%rbp),%rdi
 111fe57:	add    %rdi,%r9
 111fe5a:	mov    -0x120(%rbp),%rcx
 111fe61:	cmp    %rcx,%r9
 111fe64:	mov    $0x0,%eax
 111fe69:	cmovae %rcx,%rax
 111fe6d:	sbb    $0xffffffffffffffff,%r15
 111fe71:	sub    %rax,%r9
 111fe74:	lea    (%r15,%rdx,1),%rax
 111fe78:	add    %rdi,%r9
 111fe7b:	mov    %r9,-0x60(%rbp)
 111fe7f:	cmp    %rcx,%r9
 111fe82:	mov    $0x0,%edi
 111fe87:	cmovae %rcx,%rdi
 111fe8b:	mov    %rdi,-0x78(%rbp)
 111fe8f:	sbb    $0xffffffffffffffff,%rax
 111fe93:	mov    %rax,-0xa0(%rbp)
 111fe9a:	mov    $0x1,%r9d
 111fea0:	mov    %r11,-0xa8(%rbp)
 111fea7:	cmpq   $0x2,-0x40(%rbp)
 111feac:	jb     112006a <sort.block.block__anon_39129+0x2d2a>
 111feb2:	mov    -0xa8(%rbp),%r11
 111feb9:	nopl   0x0(%rax)
 111fec0:	lea    0x1(%r11),%rbx
 111fec4:	mov    %r15,%rax
 111fec7:	sub    %rbx,%rax
 111feca:	je     1120063 <sort.block.block__anon_39129+0x2d23>
 111fed0:	mov    -0x40(%rbp),%rcx
 111fed4:	sub    %r9,%rcx
 111fed7:	movzwl (%r10,%r11,2),%edi
 111fedc:	mov    %rax,%rdx
 111fedf:	or     %rcx,%rdx
 111fee2:	shr    $0x20,%rdx
 111fee6:	je     111fef0 <sort.block.block__anon_39129+0x2bb0>
 111fee8:	xor    %edx,%edx
 111feea:	div    %rcx
 111feed:	jmp    111fef4 <sort.block.block__anon_39129+0x2bb4>
 111feef:	nop
 111fef0:	xor    %edx,%edx
 111fef2:	div    %ecx
 111fef4:	cmp    $0x1,%rax
 111fef8:	adc    $0x0,%rax
 111fefc:	mov    -0x30(%rbp),%rcx
 111ff00:	mov    (%rcx),%rcx
 111ff03:	shl    $0x4,%edi
 111ff06:	lea    (%rcx,%rdi,1),%r13
 111ff0a:	mov    (%rcx,%rdi,1),%rdi
 111ff0e:	mov    %r15,%r10
 111ff11:	sub    %rax,%r10
 111ff14:	jmp    111ff3b <sort.block.block__anon_39129+0x2bfb>
 111ff16:	cs nopw 0x0(%rax,%rax,1)
 111ff20:	add    %rcx,%r8
 111ff23:	movzwl 0xe(%r13),%r14d
 111ff28:	cmp    0xe(%r8),%r14w
 111ff2d:	jb     111ff57 <sort.block.block__anon_39129+0x2c17>
 111ff2f:	mov    %rdx,%rbx
 111ff32:	cmp    %r10,%rdx
 111ff35:	jae    111ffc0 <sort.block.block__anon_39129+0x2c80>
 111ff3b:	lea    (%rbx,%rax,1),%rdx
 111ff3f:	mov    -0x98(%rbp),%r8
 111ff46:	movzwl (%r8,%rdx,2),%r8d
 111ff4b:	shl    $0x4,%r8d
 111ff4f:	cmp    (%rcx,%r8,1),%rdi
 111ff53:	je     111ff20 <sort.block.block__anon_39129+0x2be0>
 111ff55:	jae    111ff2f <sort.block.block__anon_39129+0x2bef>
 111ff57:	mov    %rbx,%rdx
 111ff5a:	mov    -0x38(%rbp),%r10
 111ff5e:	jmp    111ff7e <sort.block.block__anon_39129+0x2c3e>
 111ff60:	mov    %eax,%r8d
 111ff63:	and    $0x1,%r8d
 111ff67:	add    %r10,%r8
 111ff6a:	add    %r8,%rdx
 111ff6d:	cmp    $0x2,%rax
 111ff71:	mov    %r10,%rax
 111ff74:	mov    -0x38(%rbp),%r10
 111ff78:	jb     1120040 <sort.block.block__anon_39129+0x2d00>
 111ff7e:	lea    (%r10,%rdx,2),%r8
 111ff82:	mov    %rax,%r10
 111ff85:	and    $0xfffffffffffffffe,%r10
 111ff89:	movzwl (%r10,%r8,1),%r8d
 111ff8e:	shl    $0x4,%r8d
 111ff92:	cmp    (%rcx,%r8,1),%rdi
 111ff96:	jne    111ffa5 <sort.block.block__anon_39129+0x2c65>
 111ff98:	add    %rcx,%r8
 111ff9b:	movzwl 0xe(%r13),%r10d
 111ffa0:	cmp    0xe(%r8),%r10w
 111ffa5:	setb   %r8b
 111ffa9:	mov    %rax,%r10
 111ffac:	shr    %r10
 111ffaf:	test   %r8b,%r8b
 111ffb2:	je     111ff60 <sort.block.block__anon_39129+0x2c20>
 111ffb4:	xor    %r8d,%r8d
 111ffb7:	jmp    111ff6a <sort.block.block__anon_39129+0x2c2a>
 111ffb9:	nopl   0x0(%rax)
 111ffc0:	mov    %r15,%rax
 111ffc3:	sub    %rdx,%rax
 111ffc6:	mov    -0x38(%rbp),%r10
 111ffca:	ja     111fffa <sort.block.block__anon_39129+0x2cba>
 111ffcc:	jmp    1120153 <sort.block.block__anon_39129+0x2e13>
 111ffd1:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 111ffe0:	mov    %eax,%r8d
 111ffe3:	and    $0x1,%r8d
 111ffe7:	add    %r10,%r8
 111ffea:	add    %r8,%rdx
 111ffed:	cmp    $0x1,%rax
 111fff1:	mov    %r10,%rax
 111fff4:	mov    -0x38(%rbp),%r10
 111fff8:	jbe    1120040 <sort.block.block__anon_39129+0x2d00>
 111fffa:	lea    (%r10,%rdx,2),%r8
 111fffe:	mov    %rax,%r10
 1120001:	and    $0xfffffffffffffffe,%r10
 1120005:	movzwl (%r10,%r8,1),%r8d
 112000a:	shl    $0x4,%r8d
 112000e:	cmp    (%rcx,%r8,1),%rdi
 1120012:	jne    1120021 <sort.block.block__anon_39129+0x2ce1>
 1120014:	add    %rcx,%r8
 1120017:	movzwl 0xe(%r13),%r10d
 112001c:	cmp    0xe(%r8),%r10w
 1120021:	setb   %r8b
 1120025:	mov    %rax,%r10
 1120028:	shr    %r10
 112002b:	test   %r8b,%r8b
 112002e:	je     111ffe0 <sort.block.block__anon_39129+0x2ca0>
 1120030:	xor    %r8d,%r8d
 1120033:	jmp    111ffea <sort.block.block__anon_39129+0x2caa>
 1120035:	data16 cs nopw 0x0(%rax,%rax,1)
 1120040:	cmp    %r15,%rdx
 1120043:	mov    -0x98(%rbp),%r13
 112004a:	je     1120063 <sort.block.block__anon_39129+0x2d23>
 112004c:	inc    %r9
 112004f:	mov    %rdx,%r11
 1120052:	cmp    -0x40(%rbp),%r9
 1120056:	jne    111fec0 <sort.block.block__anon_39129+0x2b80>
 112005c:	mov    %rdx,%r11
 112005f:	mov    -0x40(%rbp),%r9
 1120063:	mov    -0xb8(%rbp),%rdx
 112006a:	cmp    -0x68(%rbp),%r9
 112006e:	jbe    1120170 <sort.block.block__anon_39129+0x2e30>
 1120074:	lea    (%r12,%r12,4),%rax
 1120078:	mov    %r11,-0x1a0(%rbp,%rax,8)
 1120080:	mov    -0xa8(%rbp),%rdi
 1120087:	mov    %rdi,-0x198(%rbp,%rax,8)
 112008f:	mov    %r9,-0x190(%rbp,%rax,8)
 1120097:	mov    %rdi,-0x188(%rbp,%rax,8)
 112009f:	mov    -0xa0(%rbp),%rcx
 11200a6:	mov    %rcx,-0x180(%rbp,%rax,8)
 11200ae:	mov    -0xe0(%rbp),%rcx
 11200b5:	cmp    %rcx,%r9
 11200b8:	je     1120550 <sort.block.block__anon_39129+0x3210>
 11200be:	add    %rdi,%r9
 11200c1:	cmp    %rcx,-0x40(%rbp)
 11200c5:	jne    1120100 <sort.block.block__anon_39129+0x2dc0>
 11200c7:	movl   $0x0,-0x70(%rbp)
 11200ce:	mov    -0x88(%rbp),%rax
 11200d5:	mov    %rax,-0x40(%rbp)
 11200d9:	lea    -0x178(%rbp),%rax
 11200e0:	mov    %rax,-0x90(%rbp)
 11200e7:	mov    %rdi,-0xd0(%rbp)
 11200ee:	mov    %r9,-0xb0(%rbp)
 11200f5:	jmp    11201fd <sort.block.block__anon_39129+0x2ebd>
 11200fa:	nopw   0x0(%rax,%rax,1)
 1120100:	cmp    $0x201,%rsi
 1120107:	jb     11205a9 <sort.block.block__anon_39129+0x3269>
 112010d:	testb  $0x1,-0xc0(%rbp)
 1120114:	je     1126832 <sort.block.block__anon_39129+0x94f2>
 112011a:	movl   $0x0,-0x70(%rbp)
 1120121:	lea    -0x178(%rbp),%rax
 1120128:	mov    %rax,-0x90(%rbp)
 112012f:	mov    -0xa8(%rbp),%rax
 1120136:	mov    %rax,-0xd0(%rbp)
 112013d:	mov    %r9,-0xb0(%rbp)
 1120144:	movl   $0x0,-0xc0(%rbp)
 112014e:	jmp    11201fd <sort.block.block__anon_39129+0x2ebd>
 1120153:	mov    -0xb8(%rbp),%rdx
 112015a:	mov    -0x98(%rbp),%r13
 1120161:	cmp    -0x68(%rbp),%r9
 1120165:	ja     1120074 <sort.block.block__anon_39129+0x2d34>
 112016b:	nopl   0x0(%rax,%rax,1)
 1120170:	test   %r12,%r12
 1120173:	je     1120185 <sort.block.block__anon_39129+0x2e45>
 1120175:	movl   $0x0,-0x70(%rbp)
 112017c:	lea    -0x178(%rbp),%rax
 1120183:	jmp    11201f6 <sort.block.block__anon_39129+0x2eb6>
 1120185:	mov    -0xb0(%rbp),%rax
 112018c:	sub    -0xd0(%rbp),%rax
 1120193:	mov    $0x1,%cl
 1120195:	mov    %ecx,-0x70(%rbp)
 1120198:	cmp    %rax,%r9
 112019b:	jbe    11201ef <sort.block.block__anon_39129+0x2eaf>
 112019d:	mov    %r11,-0x1a0(%rbp)
 11201a4:	mov    -0xa8(%rbp),%rcx
 11201ab:	mov    %rcx,-0x198(%rbp)
 11201b2:	mov    %r9,-0x190(%rbp)
 11201b9:	add    %rcx,%r9
 11201bc:	mov    %rcx,-0x188(%rbp)
 11201c3:	mov    -0xa0(%rbp),%rax
 11201ca:	mov    %rax,-0x180(%rbp)
 11201d1:	lea    -0x1a0(%rbp),%rax
 11201d8:	mov    %rax,-0x90(%rbp)
 11201df:	mov    %rcx,-0xd0(%rbp)
 11201e6:	mov    %r9,-0xb0(%rbp)
 11201ed:	jmp    11201fd <sort.block.block__anon_39129+0x2ebd>
 11201ef:	lea    -0x1a0(%rbp),%rax
 11201f6:	mov    %rax,-0x90(%rbp)
 11201fd:	mov    -0xa0(%rbp),%rax
 1120204:	lea    -0x1(%rax),%r11
 1120208:	mov    $0x1,%r9d
 112020e:	cmpq   $0x2,-0x40(%rbp)
 1120213:	jb     11203e6 <sort.block.block__anon_39129+0x30a6>
 1120219:	nopl   0x0(%rax)
 1120220:	mov    %r11,%rax
 1120223:	sub    %r15,%rax
 1120226:	je     11203df <sort.block.block__anon_39129+0x309f>
 112022c:	mov    -0x40(%rbp),%rcx
 1120230:	sub    %r9,%rcx
 1120233:	movzwl (%r10,%r11,2),%r13d
 1120238:	mov    %rax,%rdx
 112023b:	or     %rcx,%rdx
 112023e:	shr    $0x20,%rdx
 1120242:	je     1120250 <sort.block.block__anon_39129+0x2f10>
 1120244:	xor    %edx,%edx
 1120246:	div    %rcx
 1120249:	jmp    1120254 <sort.block.block__anon_39129+0x2f14>
 112024b:	nopl   0x0(%rax,%rax,1)
 1120250:	xor    %edx,%edx
 1120252:	div    %ecx
 1120254:	cmp    $0x1,%rax
 1120258:	adc    $0x0,%rax
 112025c:	lea    (%rax,%r15,1),%r10
 1120260:	mov    -0x30(%rbp),%rcx
 1120264:	mov    (%rcx),%rcx
 1120267:	mov    %r13d,%edi
 112026a:	shl    $0x4,%edi
 112026d:	add    %rcx,%rdi
 1120270:	mov    %r11,%rdx
 1120273:	jmp    1120298 <sort.block.block__anon_39129+0x2f58>
 1120275:	data16 cs nopw 0x0(%rax,%rax,1)
 1120280:	add    %rcx,%r8
 1120283:	movzwl 0xe(%r8),%r8d
 1120288:	cmp    0xe(%rdi),%r8w
 112028d:	jb     11202d3 <sort.block.block__anon_39129+0x2f93>
 112028f:	cmp    %r10,%rdx
 1120292:	jb     1120350 <sort.block.block__anon_39129+0x3010>
 1120298:	sub    %rax,%rdx
 112029b:	mov    %rdx,%r14
 112029e:	sub    %r15,%r14
 11202a1:	jbe    11202d0 <sort.block.block__anon_39129+0x2f90>
 11202a3:	mov    -0x98(%rbp),%r8
 11202aa:	movzwl (%r8,%rdx,2),%r8d
 11202af:	shl    $0x4,%r8d
 11202b3:	mov    (%rcx,%r8,1),%r12
 11202b7:	mov    (%rdi),%rbx
 11202ba:	cmp    %rbx,%r12
 11202bd:	je     1120280 <sort.block.block__anon_39129+0x2f40>
 11202bf:	jae    112028f <sort.block.block__anon_39129+0x2f4f>
 11202c1:	mov    %rbx,%r12
 11202c4:	jmp    11202d3 <sort.block.block__anon_39129+0x2f93>
 11202c6:	cs nopw 0x0(%rax,%rax,1)
 11202d0:	mov    (%rdi),%r12
 11202d3:	shl    $0x4,%r13d
 11202d7:	lea    (%rcx,%r13,1),%rdi
 11202db:	add    $0xe,%rdi
 11202df:	mov    -0x38(%rbp),%r10
 11202e3:	mov    -0x98(%rbp),%r13
 11202ea:	jmp    1120307 <sort.block.block__anon_39129+0x2fc7>
 11202ec:	nopl   0x0(%rax)
 11202f0:	xor    %r8d,%r8d
 11202f3:	add    %r8,%rdx
 11202f6:	cmp    $0x2,%rax
 11202fa:	mov    %r10,%rax
 11202fd:	mov    -0x38(%rbp),%r10
 1120301:	jb     11203c0 <sort.block.block__anon_39129+0x3080>
 1120307:	lea    (%r10,%rdx,2),%r8
 112030b:	mov    %rax,%r10
 112030e:	and    $0xfffffffffffffffe,%r10
 1120312:	movzwl (%r10,%r8,1),%r8d
 1120317:	shl    $0x4,%r8d
 112031b:	cmp    %r12,(%rcx,%r8,1)
 112031f:	jne    112032d <sort.block.block__anon_39129+0x2fed>
 1120321:	add    %rcx,%r8
 1120324:	movzwl 0xe(%r8),%r8d
 1120329:	cmp    (%rdi),%r8w
 112032d:	setb   %r8b
 1120331:	mov    %rax,%r10
 1120334:	shr    %r10
 1120337:	test   %r8b,%r8b
 112033a:	je     11202f0 <sort.block.block__anon_39129+0x2fb0>
 112033c:	mov    %eax,%r8d
 112033f:	and    $0x1,%r8d
 1120343:	add    %r10,%r8
 1120346:	jmp    11202f3 <sort.block.block__anon_39129+0x2fb3>
 1120348:	nopl   0x0(%rax,%rax,1)
 1120350:	mov    %r15,%rdx
 1120353:	mov    -0x38(%rbp),%r10
 1120357:	mov    -0x98(%rbp),%r13
 112035e:	jmp    112036f <sort.block.block__anon_39129+0x302f>
 1120360:	xor    %r8d,%r8d
 1120363:	add    %r8,%rdx
 1120366:	cmp    $0x1,%r14
 112036a:	mov    %rax,%r14
 112036d:	jbe    11203c0 <sort.block.block__anon_39129+0x3080>
 112036f:	lea    (%r10,%rdx,2),%rax
 1120373:	mov    %r14,%r8
 1120376:	and    $0xfffffffffffffffe,%r8
 112037a:	movzwl (%r8,%rax,1),%eax
 112037f:	shl    $0x4,%eax
 1120382:	cmp    %rbx,(%rcx,%rax,1)
 1120386:	jne    1120393 <sort.block.block__anon_39129+0x3053>
 1120388:	add    %rcx,%rax
 112038b:	movzwl 0xe(%rax),%eax
 112038f:	cmp    0xe(%rdi),%ax
 1120393:	setb   %r8b
 1120397:	mov    %r14,%rax
 112039a:	shr    %rax
 112039d:	test   %r8b,%r8b
 11203a0:	je     1120360 <sort.block.block__anon_39129+0x3020>
 11203a2:	mov    %r14d,%r8d
 11203a5:	and    $0x1,%r8d
 11203a9:	add    %rax,%r8
 11203ac:	add    %r8,%rdx
 11203af:	cmp    $0x1,%r14
 11203b3:	mov    %rax,%r14
 11203b6:	ja     112036f <sort.block.block__anon_39129+0x302f>
 11203b8:	nopl   0x0(%rax,%rax,1)
 11203c0:	cmp    %r15,%rdx
 11203c3:	je     11203df <sort.block.block__anon_39129+0x309f>
 11203c5:	inc    %r9
 11203c8:	dec    %rdx
 11203cb:	mov    %rdx,%r11
 11203ce:	cmp    -0x40(%rbp),%r9
 11203d2:	jne    1120220 <sort.block.block__anon_39129+0x2ee0>
 11203d8:	mov    -0x40(%rbp),%r9
 11203dc:	mov    %rdx,%r11
 11203df:	mov    -0xb8(%rbp),%rdx
 11203e6:	mov    -0x68(%rbp),%r8
 11203ea:	cmp    %r8,%r9
 11203ed:	jbe    1120460 <sort.block.block__anon_39129+0x3120>
 11203ef:	mov    -0x90(%rbp),%rdi
 11203f6:	mov    %r11,(%rdi)
 11203f9:	mov    -0xa0(%rbp),%rax
 1120400:	mov    %rax,0x8(%rdi)
 1120404:	mov    %r9,0x10(%rdi)
 1120408:	mov    -0xa8(%rbp),%rcx
 112040f:	mov    %rcx,0x18(%rdi)
 1120413:	mov    %rax,0x20(%rdi)
 1120417:	mov    -0xe0(%rbp),%rax
 112041e:	cmp    %rax,%r9
 1120421:	je     112057b <sort.block.block__anon_39129+0x323b>
 1120427:	cmp    %rax,-0x40(%rbp)
 112042b:	jne    11204d0 <sort.block.block__anon_39129+0x3190>
 1120431:	mov    -0xa0(%rbp),%rdi
 1120438:	mov    %rdi,%rax
 112043b:	sub    %r9,%rax
 112043e:	mov    %rax,-0xd0(%rbp)
 1120445:	mov    $0x1,%r12d
 112044b:	mov    -0x88(%rbp),%rax
 1120452:	mov    %rax,-0x40(%rbp)
 1120456:	jmp    112050e <sort.block.block__anon_39129+0x31ce>
 112045b:	nopl   0x0(%rax,%rax,1)
 1120460:	mov    $0x1,%r12d
 1120466:	cmpb   $0x0,-0x70(%rbp)
 112046a:	je     111fe2a <sort.block.block__anon_39129+0x2aea>
 1120470:	mov    -0xb0(%rbp),%rax
 1120477:	sub    -0xd0(%rbp),%rax
 112047e:	cmp    %rax,%r9
 1120481:	jbe    111fe27 <sort.block.block__anon_39129+0x2ae7>
 1120487:	mov    -0xa0(%rbp),%rdi
 112048e:	mov    %rdi,%rax
 1120491:	sub    %r9,%rax
 1120494:	mov    %rax,-0xd0(%rbp)
 112049b:	mov    %r11,-0x1a0(%rbp)
 11204a2:	mov    %rdi,-0x198(%rbp)
 11204a9:	mov    %r9,-0x190(%rbp)
 11204b0:	mov    -0xa8(%rbp),%rax
 11204b7:	mov    %rax,-0x188(%rbp)
 11204be:	mov    %rdi,-0x180(%rbp)
 11204c5:	xor    %r12d,%r12d
 11204c8:	jmp    112050e <sort.block.block__anon_39129+0x31ce>
 11204ca:	nopw   0x0(%rax,%rax,1)
 11204d0:	cmp    $0x200,%rsi
 11204d7:	jbe    11205c0 <sort.block.block__anon_39129+0x3280>
 11204dd:	testb  $0x1,-0xc0(%rbp)
 11204e4:	je     112683e <sort.block.block__anon_39129+0x94fe>
 11204ea:	mov    -0xa0(%rbp),%rdi
 11204f1:	mov    %rdi,%rax
 11204f4:	sub    %r9,%rax
 11204f7:	mov    %rax,-0xd0(%rbp)
 11204fe:	mov    $0x1,%r12d
 1120504:	movl   $0x0,-0xc0(%rbp)
 112050e:	mov    %rdi,-0xb0(%rbp)
 1120515:	mov    -0x78(%rbp),%rax
 1120519:	mov    -0x60(%rbp),%r9
 112051d:	sub    %rax,%r9
 1120520:	cmp    -0x118(%rbp),%rdi
 1120527:	jb     111fe49 <sort.block.block__anon_39129+0x2b09>
 112052d:	jmp    11205e0 <sort.block.block__anon_39129+0x32a0>
 1120532:	mov    -0xd8(%rbp),%rcx
 1120539:	or     $0x1,%rcx
 112053d:	mov    %rcx,-0xb8(%rbp)
 1120544:	mov    -0x98(%rbp),%r13
 112054b:	jmp    111f11b <sort.block.block__anon_39129+0x1ddb>
 1120550:	mov    -0x88(%rbp),%rsi
 1120557:	add    %rdi,%rsi
 112055a:	add    %rdi,%rcx
 112055d:	mov    %rdi,-0xd0(%rbp)
 1120564:	mov    %rsi,-0xb0(%rbp)
 112056b:	mov    %rsi,-0xa8(%rbp)
 1120572:	mov    %rcx,-0xa0(%rbp)
 1120579:	jmp    11205f6 <sort.block.block__anon_39129+0x32b6>
 112057b:	mov    %rax,%rsi
 112057e:	mov    -0xa0(%rbp),%rcx
 1120585:	mov    %rcx,%rax
 1120588:	sub    %rsi,%rax
 112058b:	mov    %rax,-0xd0(%rbp)
 1120592:	sub    -0x88(%rbp),%rcx
 1120599:	mov    %rcx,-0xb0(%rbp)
 11205a0:	mov    %rcx,-0xa8(%rbp)
 11205a7:	jmp    11205f6 <sort.block.block__anon_39129+0x32b6>
 11205a9:	mov    -0xa8(%rbp),%rax
 11205b0:	mov    %rax,-0xd0(%rbp)
 11205b7:	mov    %r9,-0xb0(%rbp)
 11205be:	jmp    11205e0 <sort.block.block__anon_39129+0x32a0>
 11205c0:	mov    -0xa0(%rbp),%rcx
 11205c7:	mov    %rcx,%rax
 11205ca:	sub    %r9,%rax
 11205cd:	mov    %rax,-0xd0(%rbp)
 11205d4:	mov    %rcx,-0xb0(%rbp)
 11205db:	nopl   0x0(%rax,%rax,1)
 11205e0:	movq   $0x0,-0xa8(%rbp)
 11205eb:	movq   $0x0,-0xa0(%rbp)
 11205f6:	mov    $0x1,%sil
 11205f9:	lea    -0x1a0(%rbp),%rdi
 1120600:	jmp    1120641 <sort.block.block__anon_39129+0x3301>
 1120602:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1120610:	mov    -0x100(%rbp),%rax
 1120617:	mov    %r9,(%rax)
 112061a:	mov    -0x38(%rbp),%r10
 112061e:	mov    -0xb8(%rbp),%rdx
 1120625:	mov    -0xe8(%rbp),%esi
 112062b:	lea    -0x178(%rbp),%rdi
 1120632:	test   $0x1,%sil
 1120636:	mov    $0x0,%esi
 112063b:	je     1121e20 <sort.block.block__anon_39129+0x4ae0>
 1120641:	mov    0x10(%rdi),%r11
 1120645:	mov    (%rdi),%r9
 1120648:	cmp    %r9,0x8(%rdi)
 112064c:	mov    %r11,-0x40(%rbp)
 1120650:	jae    1121230 <sort.block.block__anon_39129+0x3ef0>
 1120656:	cmp    $0x2,%r11
 112065a:	jb     112062b <sort.block.block__anon_39129+0x32eb>
 112065c:	mov    %esi,-0xe8(%rbp)
 1120662:	mov    %rdi,-0x100(%rbp)
 1120669:	mov    0x8(%rdi),%r12
 112066d:	mov    $0x1,%r15d
 1120673:	mov    $0xffffffffffffffff,%r14
 112067a:	mov    -0x80(%rbp),%rax
 112067e:	mov    %rax,-0x90(%rbp)
 1120685:	mov    %r10,-0x60(%rbp)
 1120689:	mov    -0x208(%rbp),%rax
 1120690:	mov    %rax,-0x78(%rbp)
 1120694:	mov    -0x210(%rbp),%rax
 112069b:	mov    %rax,-0xe0(%rbp)
 11206a2:	mov    %r13,-0xc0(%rbp)
 11206a9:	mov    -0x48(%rbp),%rax
 11206ad:	mov    %rax,-0x70(%rbp)
 11206b1:	mov    -0x58(%rbp),%rax
 11206b5:	mov    %rax,-0x68(%rbp)
 11206b9:	mov    %r9,%r10
 11206bc:	mov    %r12,-0x88(%rbp)
 11206c3:	jmp    1120710 <sort.block.block__anon_39129+0x33d0>
 11206c5:	data16 cs nopw 0x0(%rax,%rax,1)
 11206d0:	lea    (%r10,%r15,1),%r9
 11206d4:	inc    %r15
 11206d7:	dec    %r14
 11206da:	addq   $0xfffffffffffffffe,-0x68(%rbp)
 11206df:	addq   $0xfffffffffffffffe,-0x70(%rbp)
 11206e4:	addq   $0xfffffffffffffffe,-0xc0(%rbp)
 11206ec:	addq   $0x2,-0xe0(%rbp)
 11206f4:	addq   $0x2,-0x78(%rbp)
 11206f9:	addq   $0xfffffffffffffffe,-0x60(%rbp)
 11206fe:	addq   $0xfffffffffffffffe,-0x90(%rbp)
 1120706:	cmp    -0x40(%rbp),%r15
 112070a:	je     1120610 <sort.block.block__anon_39129+0x32d0>
 1120710:	mov    %r10,%rcx
 1120713:	mov    %r9,%rbx
 1120716:	sub    %r15,%rbx
 1120719:	inc    %rbx
 112071c:	mov    %rbx,%rax
 112071f:	mov    %r12,%r10
 1120722:	sub    %r12,%rax
 1120725:	je     11208b0 <sort.block.block__anon_39129+0x3570>
 112072b:	mov    -0x40(%rbp),%rsi
 112072f:	sub    %r15,%rsi
 1120732:	mov    -0x98(%rbp),%r8
 1120739:	movzwl (%r8,%rcx,2),%ecx
 112073e:	mov    %rax,%rdx
 1120741:	or     %rsi,%rdx
 1120744:	shr    $0x20,%rdx
 1120748:	je     1120751 <sort.block.block__anon_39129+0x3411>
 112074a:	xor    %edx,%edx
 112074c:	div    %rsi
 112074f:	jmp    1120755 <sort.block.block__anon_39129+0x3415>
 1120751:	xor    %edx,%edx
 1120753:	div    %esi
 1120755:	cmp    $0x1,%rax
 1120759:	adc    $0x0,%rax
 112075d:	lea    (%rax,%r12,1),%rdi
 1120761:	mov    -0x30(%rbp),%rdx
 1120765:	mov    (%rdx),%rsi
 1120768:	mov    %ecx,%r11d
 112076b:	shl    $0x4,%r11d
 112076f:	add    %rsi,%r11
 1120772:	mov    %rbx,%r10
 1120775:	jmp    112079f <sort.block.block__anon_39129+0x345f>
 1120777:	nopw   0x0(%rax,%rax,1)
 1120780:	add    %rsi,%r8
 1120783:	movzwl 0xe(%r8),%r8d
 1120788:	cmp    0xe(%r11),%r8w
 112078d:	jb     11207c9 <sort.block.block__anon_39129+0x3489>
 112078f:	cmp    %rdi,%r10
 1120792:	mov    -0x98(%rbp),%r8
 1120799:	jb     112083d <sort.block.block__anon_39129+0x34fd>
 112079f:	sub    %rax,%r10
 11207a2:	mov    %r10,%rdx
 11207a5:	sub    %r12,%rdx
 11207a8:	jbe    11207c6 <sort.block.block__anon_39129+0x3486>
 11207aa:	movzwl (%r8,%r10,2),%r8d
 11207af:	shl    $0x4,%r8d
 11207b3:	mov    (%rsi,%r8,1),%r13
 11207b7:	mov    (%r11),%rbx
 11207ba:	cmp    %rbx,%r13
 11207bd:	je     1120780 <sort.block.block__anon_39129+0x3440>
 11207bf:	jae    112078f <sort.block.block__anon_39129+0x344f>
 11207c1:	mov    %rbx,%r13
 11207c4:	jmp    11207c9 <sort.block.block__anon_39129+0x3489>
 11207c6:	mov    (%r11),%r13
 11207c9:	shl    $0x4,%ecx
 11207cc:	add    %rsi,%rcx
 11207cf:	add    $0xe,%rcx
 11207d3:	jmp    11207f2 <sort.block.block__anon_39129+0x34b2>
 11207d5:	data16 cs nopw 0x0(%rax,%rax,1)
 11207e0:	xor    %edi,%edi
 11207e2:	add    %rdi,%r10
 11207e5:	cmp    $0x2,%rax
 11207e9:	mov    %rdx,%rax
 11207ec:	jb     11208b0 <sort.block.block__anon_39129+0x3570>
 11207f2:	mov    -0x38(%rbp),%rdx
 11207f6:	lea    (%rdx,%r10,2),%rdx
 11207fa:	mov    %rax,%rdi
 11207fd:	and    $0xfffffffffffffffe,%rdi
 1120801:	movzwl (%rdi,%rdx,1),%edx
 1120805:	shl    $0x4,%edx
 1120808:	cmp    %r13,(%rsi,%rdx,1)
 112080c:	jne    1120818 <sort.block.block__anon_39129+0x34d8>
 112080e:	add    %rsi,%rdx
 1120811:	movzwl 0xe(%rdx),%edx
 1120815:	cmp    (%rcx),%dx
 1120818:	setb   %dil
 112081c:	mov    %rax,%rdx
 112081f:	shr    %rdx
 1120822:	test   %dil,%dil
 1120825:	je     11207e0 <sort.block.block__anon_39129+0x34a0>
 1120827:	mov    %eax,%edi
 1120829:	and    $0x1,%edi
 112082c:	add    %rdx,%rdi
 112082f:	add    %rdi,%r10
 1120832:	cmp    $0x2,%rax
 1120836:	mov    %rdx,%rax
 1120839:	jae    11207f2 <sort.block.block__anon_39129+0x34b2>
 112083b:	jmp    11208b0 <sort.block.block__anon_39129+0x3570>
 112083d:	mov    %r12,%r10
 1120840:	jmp    112085e <sort.block.block__anon_39129+0x351e>
 1120842:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1120850:	xor    %ecx,%ecx
 1120852:	add    %rcx,%r10
 1120855:	cmp    $0x1,%rdx
 1120859:	mov    %rax,%rdx
 112085c:	jbe    11208b0 <sort.block.block__anon_39129+0x3570>
 112085e:	mov    -0x38(%rbp),%rax
 1120862:	lea    (%rax,%r10,2),%rax
 1120866:	mov    %rdx,%rcx
 1120869:	and    $0xfffffffffffffffe,%rcx
 112086d:	movzwl (%rcx,%rax,1),%eax
 1120871:	shl    $0x4,%eax
 1120874:	cmp    %rbx,(%rsi,%rax,1)
 1120878:	jne    1120886 <sort.block.block__anon_39129+0x3546>
 112087a:	add    %rsi,%rax
 112087d:	movzwl 0xe(%rax),%eax
 1120881:	cmp    0xe(%r11),%ax
 1120886:	setb   %cl
 1120889:	mov    %rdx,%rax
 112088c:	shr    %rax
 112088f:	test   %cl,%cl
 1120891:	je     1120850 <sort.block.block__anon_39129+0x3510>
 1120893:	mov    %edx,%ecx
 1120895:	and    $0x1,%ecx
 1120898:	add    %rax,%rcx
 112089b:	add    %rcx,%r10
 112089e:	cmp    $0x1,%rdx
 11208a2:	mov    %rax,%rdx
 11208a5:	ja     112085e <sort.block.block__anon_39129+0x351e>
 11208a7:	nopw   0x0(%rax,%rax,1)
 11208b0:	mov    %r9,%rax
 11208b3:	sub    %r10,%rax
 11208b6:	mov    %rax,%rcx
 11208b9:	sub    %r15,%rcx
 11208bc:	mov    %rcx,%rsi
 11208bf:	shr    %rsi
 11208c2:	cmp    $0x20,%rcx
 11208c6:	setb   %cl
 11208c9:	cmp    $0xf,%rsi
 11208cd:	sete   %dl
 11208d0:	or     %cl,%dl
 11208d2:	je     11208f0 <sort.block.block__anon_39129+0x35b0>
 11208d4:	xor    %r11d,%r11d
 11208d7:	mov    -0x98(%rbp),%r13
 11208de:	jmp    1120a9f <sort.block.block__anon_39129+0x375f>
 11208e3:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11208f0:	lea    -0x10(%rsi),%rcx
 11208f4:	cmp    $0x30,%rcx
 11208f8:	jae    1120910 <sort.block.block__anon_39129+0x35d0>
 11208fa:	xor    %r11d,%r11d
 11208fd:	jmp    1120a09 <sort.block.block__anon_39129+0x36c9>
 1120902:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1120910:	mov    -0x1d8(%rbp),%rdx
 1120917:	lea    (%rdx,%r10,2),%rdx
 112091b:	lea    (%r9,%r14,1),%rbx
 112091f:	sub    %r10,%rbx
 1120922:	shr    %rbx
 1120925:	add    $0xfffffffffffffff0,%rbx
 1120929:	shr    $0x4,%rbx
 112092d:	inc    %rbx
 1120930:	and    $0xfffffffffffffffc,%rbx
 1120934:	mov    -0x68(%rbp),%rdi
 1120938:	lea    (%rdi,%r9,2),%rdi
 112093c:	xor    %r11d,%r11d
 112093f:	nop
 1120940:	vmovdqu (%rdi,%r11,2),%ymm0
 1120946:	vmovdqu -0x60(%rdx),%ymm1
 112094b:	vpshufb %ymm2,%ymm1,%ymm1
 1120950:	vpermq $0x4e,%ymm1,%ymm1
 1120956:	vmovdqu %ymm1,(%rdi,%r11,2)
 112095c:	vpshufb %ymm2,%ymm0,%ymm0
 1120961:	vpermq $0x4e,%ymm0,%ymm0
 1120967:	vmovdqu %ymm0,-0x60(%rdx)
 112096c:	vmovdqu -0x20(%rdi,%r11,2),%ymm0
 1120973:	vmovdqu -0x40(%rdx),%ymm1
 1120978:	vpshufb %ymm2,%ymm1,%ymm1
 112097d:	vpermq $0x4e,%ymm1,%ymm1
 1120983:	vmovdqu %ymm1,-0x20(%rdi,%r11,2)
 112098a:	vpshufb %ymm2,%ymm0,%ymm0
 112098f:	vpermq $0x4e,%ymm0,%ymm0
 1120995:	vmovdqu %ymm0,-0x40(%rdx)
 112099a:	vmovdqu -0x40(%rdi,%r11,2),%ymm0
 11209a1:	vmovdqu -0x20(%rdx),%ymm1
 11209a6:	vpshufb %ymm2,%ymm1,%ymm1
 11209ab:	vpermq $0x4e,%ymm1,%ymm1
 11209b1:	vmovdqu %ymm1,-0x40(%rdi,%r11,2)
 11209b8:	vpshufb %ymm2,%ymm0,%ymm0
 11209bd:	vpermq $0x4e,%ymm0,%ymm0
 11209c3:	vmovdqu %ymm0,-0x20(%rdx)
 11209c8:	vmovdqu -0x60(%rdi,%r11,2),%ymm0
 11209cf:	vmovdqu (%rdx),%ymm1
 11209d3:	vpshufb %ymm2,%ymm1,%ymm1
 11209d8:	vpermq $0x4e,%ymm1,%ymm1
 11209de:	vmovdqu %ymm1,-0x60(%rdi,%r11,2)
 11209e5:	vpshufb %ymm2,%ymm0,%ymm0
 11209ea:	vpermq $0x4e,%ymm0,%ymm0
 11209f0:	vmovdqu %ymm0,(%rdx)
 11209f4:	sub    $0xffffffffffffff80,%rdx
 11209f8:	add    $0xffffffffffffffc0,%r11
 11209fc:	add    $0xfffffffffffffffc,%rbx
 1120a00:	jne    1120940 <sort.block.block__anon_39129+0x3600>
 1120a06:	neg    %r11
 1120a09:	mov    -0x98(%rbp),%r13
 1120a10:	shr    $0x4,%rcx
 1120a14:	inc    %rcx
 1120a17:	test   $0x3,%cl
 1120a1a:	je     1120a9f <sort.block.block__anon_39129+0x375f>
 1120a20:	mov    -0x68(%rbp),%rcx
 1120a24:	lea    (%rcx,%r9,2),%rdx
 1120a28:	mov    %r11,%rcx
 1120a2b:	neg    %rcx
 1120a2e:	add    %r11,%r11
 1120a31:	lea    (%r11,%r10,2),%rdi
 1120a35:	add    -0x138(%rbp),%rdi
 1120a3c:	lea    (%r9,%r14,1),%r8d
 1120a40:	sub    %r10d,%r8d
 1120a43:	shr    %r8b
 1120a46:	add    $0xf0,%r8b
 1120a4a:	shr    $0x4,%r8b
 1120a4e:	inc    %r8b
 1120a51:	movzbl %r8b,%r8d
 1120a55:	and    $0x3,%r8d
 1120a59:	shl    $0x5,%r8d
 1120a5d:	xor    %r11d,%r11d
 1120a60:	vmovdqu (%rdx,%rcx,2),%ymm0
 1120a65:	vmovdqu (%rdi,%r11,1),%ymm1
 1120a6b:	vpshufb %ymm2,%ymm1,%ymm1
 1120a70:	vpermq $0x4e,%ymm1,%ymm1
 1120a76:	vmovdqu %ymm1,(%rdx,%rcx,2)
 1120a7b:	vpshufb %ymm2,%ymm0,%ymm0
 1120a80:	vpermq $0x4e,%ymm0,%ymm0
 1120a86:	vmovdqu %ymm0,(%rdi,%r11,1)
 1120a8c:	add    $0xfffffffffffffff0,%rcx
 1120a90:	add    $0x20,%r11
 1120a94:	cmp    %r11,%r8
 1120a97:	jne    1120a60 <sort.block.block__anon_39129+0x3720>
 1120a99:	neg    %rcx
 1120a9c:	mov    %rcx,%r11
 1120a9f:	mov    %r11,%rcx
 1120aa2:	sub    %rsi,%rcx
 1120aa5:	jae    1120c0d <sort.block.block__anon_39129+0x38cd>
 1120aab:	sub    %r11d,%esi
 1120aae:	test   $0x3,%sil
 1120ab2:	je     1120b28 <sort.block.block__anon_39129+0x37e8>
 1120ab4:	lea    (%r11,%r11,1),%rsi
 1120ab8:	mov    -0x70(%rbp),%rdx
 1120abc:	lea    (%rdx,%r9,2),%rdx
 1120ac0:	sub    %rsi,%rdx
 1120ac3:	lea    (%rsi,%r10,2),%rsi
 1120ac7:	add    -0x1c0(%rbp),%rsi
 1120ace:	lea    (%r9,%r14,1),%edi
 1120ad2:	sub    %r10d,%edi
 1120ad5:	shr    %dil
 1120ad8:	sub    %r11b,%dil
 1120adb:	movzbl %dil,%edi
 1120adf:	and    $0x3,%edi
 1120ae2:	neg    %rdi
 1120ae5:	xor    %r8d,%r8d
 1120ae8:	nopl   0x0(%rax,%rax,1)
 1120af0:	movzbl -0x1(%rsi),%ebx
 1120af4:	movzbl -0x1(%rdx,%r8,2),%r13d
 1120afa:	mov    %r13b,-0x1(%rsi)
 1120afe:	mov    %bl,-0x1(%rdx,%r8,2)
 1120b03:	movzbl (%rsi),%ebx
 1120b06:	movzbl (%rdx,%r8,2),%r13d
 1120b0b:	mov    %r13b,(%rsi)
 1120b0e:	mov    %bl,(%rdx,%r8,2)
 1120b12:	dec    %r8
 1120b15:	add    $0x2,%rsi
 1120b19:	cmp    %r8,%rdi
 1120b1c:	jne    1120af0 <sort.block.block__anon_39129+0x37b0>
 1120b1e:	sub    %r8,%r11
 1120b21:	mov    -0x98(%rbp),%r13
 1120b28:	cmp    $0xfffffffffffffffc,%rcx
 1120b2c:	ja     1120c0d <sort.block.block__anon_39129+0x38cd>
 1120b32:	mov    -0x1b0(%rbp),%rcx
 1120b39:	lea    (%rcx,%r10,2),%rcx
 1120b3d:	lea    (%r9,%r14,1),%rdx
 1120b41:	mov    -0x38(%rbp),%rsi
 1120b45:	lea    (%rsi,%rdx,2),%rsi
 1120b49:	sub    %r11,%rsi
 1120b4c:	sub    %r11,%rsi
 1120b4f:	sub    %r10,%rdx
 1120b52:	shr    %rdx
 1120b55:	data16 cs nopw 0x0(%rax,%rax,1)
 1120b60:	movzbl -0x7(%rcx,%r11,2),%edi
 1120b66:	movzbl (%rsi),%r8d
 1120b6a:	mov    %r8b,-0x7(%rcx,%r11,2)
 1120b6f:	mov    %dil,(%rsi)
 1120b72:	movzbl -0x6(%rcx,%r11,2),%edi
 1120b78:	movzbl 0x1(%rsi),%r8d
 1120b7d:	mov    %r8b,-0x6(%rcx,%r11,2)
 1120b82:	mov    %dil,0x1(%rsi)
 1120b86:	movzbl -0x5(%rcx,%r11,2),%edi
 1120b8c:	movzbl -0x2(%rsi),%r8d
 1120b91:	mov    %r8b,-0x5(%rcx,%r11,2)
 1120b96:	mov    %dil,-0x2(%rsi)
 1120b9a:	movzbl -0x4(%rcx,%r11,2),%edi
 1120ba0:	movzbl -0x1(%rsi),%r8d
 1120ba5:	mov    %r8b,-0x4(%rcx,%r11,2)
 1120baa:	mov    %dil,-0x1(%rsi)
 1120bae:	movzbl -0x3(%rcx,%r11,2),%edi
 1120bb4:	movzbl -0x4(%rsi),%r8d
 1120bb9:	mov    %r8b,-0x3(%rcx,%r11,2)
 1120bbe:	mov    %dil,-0x4(%rsi)
 1120bc2:	movzbl -0x2(%rcx,%r11,2),%edi
 1120bc8:	movzbl -0x3(%rsi),%r8d
 1120bcd:	mov    %r8b,-0x2(%rcx,%r11,2)
 1120bd2:	mov    %dil,-0x3(%rsi)
 1120bd6:	movzbl -0x1(%rcx,%r11,2),%edi
 1120bdc:	movzbl -0x6(%rsi),%r8d
 1120be1:	mov    %r8b,-0x1(%rcx,%r11,2)
 1120be6:	mov    %dil,-0x6(%rsi)
 1120bea:	movzbl (%rcx,%r11,2),%edi
 1120bef:	movzbl -0x5(%rsi),%r8d
 1120bf4:	mov    %r8b,(%rcx,%r11,2)
 1120bf8:	mov    %dil,-0x5(%rsi)
 1120bfc:	add    $0x4,%r11
 1120c00:	add    $0xfffffffffffffff8,%rsi
 1120c04:	cmp    %r11,%rdx
 1120c07:	jne    1120b60 <sort.block.block__anon_39129+0x3820>
 1120c0d:	mov    %r15,%r11
 1120c10:	shr    %r11
 1120c13:	cmp    $0x20,%r15
 1120c17:	setb   %cl
 1120c1a:	cmp    $0xf,%r11
 1120c1e:	sete   %dl
 1120c21:	or     %cl,%dl
 1120c23:	je     1120c30 <sort.block.block__anon_39129+0x38f0>
 1120c25:	xor    %r8d,%r8d
 1120c28:	jmp    1120dbc <sort.block.block__anon_39129+0x3a7c>
 1120c2d:	nopl   (%rax)
 1120c30:	lea    -0x10(%r11),%rsi
 1120c34:	mov    %rsi,%rcx
 1120c37:	shr    $0x4,%rcx
 1120c3b:	lea    0x1(%rcx),%rdx
 1120c3f:	cmp    $0x30,%rsi
 1120c43:	jae    1120c50 <sort.block.block__anon_39129+0x3910>
 1120c45:	xor    %r8d,%r8d
 1120c48:	jmp    1120d4b <sort.block.block__anon_39129+0x3a0b>
 1120c4d:	nopl   (%rax)
 1120c50:	mov    %rdx,%rbx
 1120c53:	and    $0xfffffffffffffffc,%rbx
 1120c57:	mov    -0xc0(%rbp),%rsi
 1120c5e:	lea    (%rsi,%r9,2),%r13
 1120c62:	lea    (%r9,%r14,1),%rsi
 1120c66:	mov    -0xe0(%rbp),%rdi
 1120c6d:	lea    (%rdi,%rsi,2),%rdi
 1120c71:	xor    %esi,%esi
 1120c73:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1120c80:	vmovdqu 0x20(%rdi),%ymm0
 1120c85:	vmovdqu 0x2(%r13,%rsi,2),%ymm1
 1120c8c:	vpshufb %ymm2,%ymm1,%ymm1
 1120c91:	vpermq $0x4e,%ymm1,%ymm1
 1120c97:	vmovdqu %ymm1,0x20(%rdi)
 1120c9c:	vpshufb %ymm2,%ymm0,%ymm0
 1120ca1:	vpermq $0x4e,%ymm0,%ymm0
 1120ca7:	vmovdqu %ymm0,0x2(%r13,%rsi,2)
 1120cae:	vmovdqu (%rdi),%ymm0
 1120cb2:	vmovdqu 0x22(%r13,%rsi,2),%ymm1
 1120cb9:	vpshufb %ymm2,%ymm1,%ymm1
 1120cbe:	vpermq $0x4e,%ymm1,%ymm1
 1120cc4:	vmovdqu %ymm1,(%rdi)
 1120cc8:	vpshufb %ymm2,%ymm0,%ymm0
 1120ccd:	vpermq $0x4e,%ymm0,%ymm0
 1120cd3:	vmovdqu %ymm0,0x22(%r13,%rsi,2)
 1120cda:	vmovdqu -0x20(%rdi),%ymm0
 1120cdf:	vmovdqu 0x42(%r13,%rsi,2),%ymm1
 1120ce6:	vpshufb %ymm2,%ymm1,%ymm1
 1120ceb:	vpermq $0x4e,%ymm1,%ymm1
 1120cf1:	vmovdqu %ymm1,-0x20(%rdi)
 1120cf6:	vpshufb %ymm2,%ymm0,%ymm0
 1120cfb:	vpermq $0x4e,%ymm0,%ymm0
 1120d01:	vmovdqu %ymm0,0x42(%r13,%rsi,2)
 1120d08:	lea    0x40(%rsi),%r8
 1120d0c:	vmovdqu -0x40(%rdi),%ymm0
 1120d11:	vmovdqu 0x62(%r13,%rsi,2),%ymm1
 1120d18:	vpshufb %ymm2,%ymm1,%ymm1
 1120d1d:	vpermq $0x4e,%ymm1,%ymm1
 1120d23:	vmovdqu %ymm1,-0x40(%rdi)
 1120d28:	vpshufb %ymm2,%ymm0,%ymm0
 1120d2d:	vpermq $0x4e,%ymm0,%ymm0
 1120d33:	vmovdqu %ymm0,0x62(%r13,%rsi,2)
 1120d3a:	add    $0xffffffffffffff80,%rdi
 1120d3e:	mov    %r8,%rsi
 1120d41:	add    $0xfffffffffffffffc,%rbx
 1120d45:	jne    1120c80 <sort.block.block__anon_39129+0x3940>
 1120d4b:	test   $0x3,%dl
 1120d4e:	mov    -0x98(%rbp),%r13
 1120d55:	je     1120dbc <sort.block.block__anon_39129+0x3a7c>
 1120d57:	inc    %cl
 1120d59:	movzbl %cl,%ecx
 1120d5c:	and    $0x3,%ecx
 1120d5f:	shl    $0x5,%ecx
 1120d62:	lea    (%r9,%r14,1),%rdx
 1120d66:	mov    -0x78(%rbp),%rsi
 1120d6a:	lea    (%rsi,%rdx,2),%rdx
 1120d6e:	lea    (%r9,%r9,1),%rsi
 1120d72:	lea    (%rsi,%r8,2),%rsi
 1120d76:	neg    %r8
 1120d79:	add    -0x60(%rbp),%rsi
 1120d7d:	xor    %edi,%edi
 1120d7f:	nop
 1120d80:	vmovdqu (%rdx,%r8,2),%ymm0
 1120d86:	vmovdqu (%rsi,%rdi,1),%ymm1
 1120d8b:	vpshufb %ymm2,%ymm1,%ymm1
 1120d90:	vpermq $0x4e,%ymm1,%ymm1
 1120d96:	vmovdqu %ymm1,(%rdx,%r8,2)
 1120d9c:	vpshufb %ymm2,%ymm0,%ymm0
 1120da1:	vpermq $0x4e,%ymm0,%ymm0
 1120da7:	vmovdqu %ymm0,(%rsi,%rdi,1)
 1120dac:	add    $0xfffffffffffffff0,%r8
 1120db0:	add    $0x20,%rdi
 1120db4:	cmp    %rdi,%rcx
 1120db7:	jne    1120d80 <sort.block.block__anon_39129+0x3a40>
 1120db9:	neg    %r8
 1120dbc:	mov    %r8,%rcx
 1120dbf:	sub    %r11,%rcx
 1120dc2:	jae    1120f25 <sort.block.block__anon_39129+0x3be5>
 1120dc8:	mov    %r11d,%edx
 1120dcb:	sub    %r8d,%edx
 1120dce:	test   $0x3,%dl
 1120dd1:	je     1120e54 <sort.block.block__anon_39129+0x3b14>
 1120dd7:	mov    -0x50(%rbp),%rdx
 1120ddb:	lea    (%rdx,%r9,2),%rdx
 1120ddf:	sub    %r8,%rdx
 1120de2:	sub    %r8,%rdx
 1120de5:	mov    %r14,%r12
 1120de8:	lea    (%r9,%r14,1),%rsi
 1120dec:	add    %rsi,%rsi
 1120def:	lea    (%rsi,%r8,2),%rsi
 1120df3:	add    -0x1c0(%rbp),%rsi
 1120dfa:	mov    %r11d,%edi
 1120dfd:	sub    %r8b,%dil
 1120e00:	movzbl %dil,%edi
 1120e04:	and    $0x3,%edi
 1120e07:	neg    %rdi
 1120e0a:	xor    %ebx,%ebx
 1120e0c:	nopl   0x0(%rax)
 1120e10:	movzbl -0x1(%rsi),%r13d
 1120e15:	movzbl -0x1(%rdx,%rbx,2),%r14d
 1120e1b:	mov    %r14b,-0x1(%rsi)
 1120e1f:	mov    %r13b,-0x1(%rdx,%rbx,2)
 1120e24:	movzbl (%rsi),%r14d
 1120e28:	movzbl (%rdx,%rbx,2),%r13d
 1120e2d:	mov    %r13b,(%rsi)
 1120e30:	mov    %r14b,(%rdx,%rbx,2)
 1120e34:	dec    %rbx
 1120e37:	add    $0x2,%rsi
 1120e3b:	cmp    %rbx,%rdi
 1120e3e:	jne    1120e10 <sort.block.block__anon_39129+0x3ad0>
 1120e40:	sub    %rbx,%r8
 1120e43:	mov    -0x98(%rbp),%r13
 1120e4a:	mov    %r12,%r14
 1120e4d:	mov    -0x88(%rbp),%r12
 1120e54:	cmp    $0xfffffffffffffffc,%rcx
 1120e58:	ja     1120f25 <sort.block.block__anon_39129+0x3be5>
 1120e5e:	mov    -0x90(%rbp),%rcx
 1120e65:	lea    (%rcx,%r9,2),%rcx
 1120e69:	mov    -0x38(%rbp),%rdx
 1120e6d:	lea    (%rdx,%r9,2),%rdx
 1120e71:	sub    %r8,%rdx
 1120e74:	sub    %r8,%rdx
 1120e77:	nopw   0x0(%rax,%rax,1)
 1120e80:	movzbl -0x7(%rcx,%r8,2),%esi
 1120e86:	movzbl (%rdx),%edi
 1120e89:	mov    %dil,-0x7(%rcx,%r8,2)
 1120e8e:	mov    %sil,(%rdx)
 1120e91:	movzbl -0x6(%rcx,%r8,2),%esi
 1120e97:	movzbl 0x1(%rdx),%edi
 1120e9b:	mov    %dil,-0x6(%rcx,%r8,2)
 1120ea0:	mov    %sil,0x1(%rdx)
 1120ea4:	movzbl -0x5(%rcx,%r8,2),%esi
 1120eaa:	movzbl -0x2(%rdx),%edi
 1120eae:	mov    %dil,-0x5(%rcx,%r8,2)
 1120eb3:	mov    %sil,-0x2(%rdx)
 1120eb7:	movzbl -0x4(%rcx,%r8,2),%esi
 1120ebd:	movzbl -0x1(%rdx),%edi
 1120ec1:	mov    %dil,-0x4(%rcx,%r8,2)
 1120ec6:	mov    %sil,-0x1(%rdx)
 1120eca:	movzbl -0x3(%rcx,%r8,2),%esi
 1120ed0:	movzbl -0x4(%rdx),%edi
 1120ed4:	mov    %dil,-0x3(%rcx,%r8,2)
 1120ed9:	mov    %sil,-0x4(%rdx)
 1120edd:	movzbl -0x2(%rcx,%r8,2),%esi
 1120ee3:	movzbl -0x3(%rdx),%edi
 1120ee7:	mov    %dil,-0x2(%rcx,%r8,2)
 1120eec:	mov    %sil,-0x3(%rdx)
 1120ef0:	movzbl -0x1(%rcx,%r8,2),%esi
 1120ef6:	movzbl -0x6(%rdx),%edi
 1120efa:	mov    %dil,-0x1(%rcx,%r8,2)
 1120eff:	mov    %sil,-0x6(%rdx)
 1120f03:	movzbl (%rcx,%r8,2),%esi
 1120f08:	movzbl -0x5(%rdx),%edi
 1120f0c:	mov    %dil,(%rcx,%r8,2)
 1120f10:	mov    %sil,-0x5(%rdx)
 1120f14:	add    $0x4,%r8
 1120f18:	add    $0xfffffffffffffff8,%rdx
 1120f1c:	cmp    %r8,%r11
 1120f1f:	jne    1120e80 <sort.block.block__anon_39129+0x3b40>
 1120f25:	mov    %rax,%r11
 1120f28:	shr    %r11
 1120f2b:	cmp    $0x20,%rax
 1120f2f:	setb   %al
 1120f32:	cmp    $0xf,%r11
 1120f36:	sete   %cl
 1120f39:	or     %al,%cl
 1120f3b:	je     1120f50 <sort.block.block__anon_39129+0x3c10>
 1120f3d:	xor    %eax,%eax
 1120f3f:	jmp    11210dd <sort.block.block__anon_39129+0x3d9d>
 1120f44:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1120f50:	lea    -0x10(%r11),%rax
 1120f54:	mov    %rax,%rsi
 1120f57:	shr    $0x4,%rsi
 1120f5b:	inc    %rsi
 1120f5e:	cmp    $0x30,%rax
 1120f62:	jae    1120f80 <sort.block.block__anon_39129+0x3c40>
 1120f64:	xor    %eax,%eax
 1120f66:	and    $0x3,%esi
 1120f69:	jne    1121076 <sort.block.block__anon_39129+0x3d36>
 1120f6f:	jmp    11210dd <sort.block.block__anon_39129+0x3d9d>
 1120f74:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1120f80:	mov    %rsi,%rcx
 1120f83:	movabs $0x1ffffffffffffffc,%rax
 1120f8d:	and    %rax,%rcx
 1120f90:	mov    -0x1d8(%rbp),%rax
 1120f97:	lea    (%rax,%r10,2),%rdx
 1120f9b:	mov    -0x1b8(%rbp),%rax
 1120fa2:	lea    (%rax,%r9,2),%rdi
 1120fa6:	xor    %eax,%eax
 1120fa8:	nopl   0x0(%rax,%rax,1)
 1120fb0:	vmovdqu (%rdi,%rax,2),%ymm0
 1120fb5:	vmovdqu -0x60(%rdx),%ymm1
 1120fba:	vpshufb %ymm2,%ymm1,%ymm1
 1120fbf:	vpermq $0x4e,%ymm1,%ymm1
 1120fc5:	vmovdqu %ymm1,(%rdi,%rax,2)
 1120fca:	vpshufb %ymm2,%ymm0,%ymm0
 1120fcf:	vpermq $0x4e,%ymm0,%ymm0
 1120fd5:	vmovdqu %ymm0,-0x60(%rdx)
 1120fda:	vmovdqu -0x20(%rdi,%rax,2),%ymm0
 1120fe0:	vmovdqu -0x40(%rdx),%ymm1
 1120fe5:	vpshufb %ymm2,%ymm1,%ymm1
 1120fea:	vpermq $0x4e,%ymm1,%ymm1
 1120ff0:	vmovdqu %ymm1,-0x20(%rdi,%rax,2)
 1120ff6:	vpshufb %ymm2,%ymm0,%ymm0
 1120ffb:	vpermq $0x4e,%ymm0,%ymm0
 1121001:	vmovdqu %ymm0,-0x40(%rdx)
 1121006:	vmovdqu -0x40(%rdi,%rax,2),%ymm0
 112100c:	vmovdqu -0x20(%rdx),%ymm1
 1121011:	vpshufb %ymm2,%ymm1,%ymm1
 1121016:	vpermq $0x4e,%ymm1,%ymm1
 112101c:	vmovdqu %ymm1,-0x40(%rdi,%rax,2)
 1121022:	vpshufb %ymm2,%ymm0,%ymm0
 1121027:	vpermq $0x4e,%ymm0,%ymm0
 112102d:	vmovdqu %ymm0,-0x20(%rdx)
 1121032:	vmovdqu -0x60(%rdi,%rax,2),%ymm0
 1121038:	vmovdqu (%rdx),%ymm1
 112103c:	vpshufb %ymm2,%ymm1,%ymm1
 1121041:	vpermq $0x4e,%ymm1,%ymm1
 1121047:	vmovdqu %ymm1,-0x60(%rdi,%rax,2)
 112104d:	vpshufb %ymm2,%ymm0,%ymm0
 1121052:	vpermq $0x4e,%ymm0,%ymm0
 1121058:	vmovdqu %ymm0,(%rdx)
 112105c:	sub    $0xffffffffffffff80,%rdx
 1121060:	add    $0xffffffffffffffc0,%rax
 1121064:	add    $0xfffffffffffffffc,%rcx
 1121068:	jne    1120fb0 <sort.block.block__anon_39129+0x3c70>
 112106e:	neg    %rax
 1121071:	and    $0x3,%esi
 1121074:	je     11210dd <sort.block.block__anon_39129+0x3d9d>
 1121076:	mov    -0x1b8(%rbp),%rcx
 112107d:	lea    (%rcx,%r9,2),%rdx
 1121081:	mov    %rax,%rcx
 1121084:	neg    %rcx
 1121087:	add    %rax,%rax
 112108a:	lea    (%rax,%r10,2),%rax
 112108e:	add    -0x138(%rbp),%rax
 1121095:	shl    $0x5,%esi
 1121098:	xor    %edi,%edi
 112109a:	nopw   0x0(%rax,%rax,1)
 11210a0:	vmovdqu (%rdx,%rcx,2),%ymm0
 11210a5:	vmovdqu (%rax,%rdi,1),%ymm1
 11210aa:	vpshufb %ymm2,%ymm1,%ymm1
 11210af:	vpermq $0x4e,%ymm1,%ymm1
 11210b5:	vmovdqu %ymm1,(%rdx,%rcx,2)
 11210ba:	vpshufb %ymm2,%ymm0,%ymm0
 11210bf:	vpermq $0x4e,%ymm0,%ymm0
 11210c5:	vmovdqu %ymm0,(%rax,%rdi,1)
 11210ca:	add    $0xfffffffffffffff0,%rcx
 11210ce:	add    $0x20,%rdi
 11210d2:	cmp    %rdi,%rsi
 11210d5:	jne    11210a0 <sort.block.block__anon_39129+0x3d60>
 11210d7:	neg    %rcx
 11210da:	mov    %rcx,%rax
 11210dd:	mov    %rax,%rcx
 11210e0:	sub    %r11,%rcx
 11210e3:	jae    11206d0 <sort.block.block__anon_39129+0x3390>
 11210e9:	mov    %r11d,%edx
 11210ec:	sub    %eax,%edx
 11210ee:	and    $0x3,%edx
 11210f1:	je     112115b <sort.block.block__anon_39129+0x3e1b>
 11210f3:	mov    %r14,%r12
 11210f6:	lea    (%rax,%rax,1),%rdi
 11210fa:	mov    -0x50(%rbp),%rsi
 11210fe:	lea    (%rsi,%r9,2),%rsi
 1121102:	sub    %rdi,%rsi
 1121105:	lea    (%rdi,%r10,2),%rdi
 1121109:	add    -0x1c0(%rbp),%rdi
 1121110:	neg    %rdx
 1121113:	xor    %r8d,%r8d
 1121116:	cs nopw 0x0(%rax,%rax,1)
 1121120:	movzbl -0x1(%rdi),%ebx
 1121124:	movzbl -0x1(%rsi,%r8,2),%r14d
 112112a:	mov    %r14b,-0x1(%rdi)
 112112e:	mov    %bl,-0x1(%rsi,%r8,2)
 1121133:	movzbl (%rdi),%ebx
 1121136:	movzbl (%rsi,%r8,2),%r14d
 112113b:	mov    %r14b,(%rdi)
 112113e:	mov    %bl,(%rsi,%r8,2)
 1121142:	dec    %r8
 1121145:	add    $0x2,%rdi
 1121149:	cmp    %r8,%rdx
 112114c:	jne    1121120 <sort.block.block__anon_39129+0x3de0>
 112114e:	sub    %r8,%rax
 1121151:	mov    %r12,%r14
 1121154:	mov    -0x88(%rbp),%r12
 112115b:	cmp    $0xfffffffffffffffc,%rcx
 112115f:	ja     11206d0 <sort.block.block__anon_39129+0x3390>
 1121165:	mov    -0x1b0(%rbp),%rcx
 112116c:	lea    (%rcx,%r10,2),%rcx
 1121170:	mov    -0x38(%rbp),%rdx
 1121174:	lea    (%rdx,%r9,2),%rdx
 1121178:	sub    %rax,%rdx
 112117b:	sub    %rax,%rdx
 112117e:	xchg   %ax,%ax
 1121180:	movzbl -0x7(%rcx,%rax,2),%esi
 1121185:	movzbl (%rdx),%edi
 1121188:	mov    %dil,-0x7(%rcx,%rax,2)
 112118d:	mov    %sil,(%rdx)
 1121190:	movzbl -0x6(%rcx,%rax,2),%esi
 1121195:	movzbl 0x1(%rdx),%edi
 1121199:	mov    %dil,-0x6(%rcx,%rax,2)
 112119e:	mov    %sil,0x1(%rdx)
 11211a2:	movzbl -0x5(%rcx,%rax,2),%esi
 11211a7:	movzbl -0x2(%rdx),%edi
 11211ab:	mov    %dil,-0x5(%rcx,%rax,2)
 11211b0:	mov    %sil,-0x2(%rdx)
 11211b4:	movzbl -0x4(%rcx,%rax,2),%esi
 11211b9:	movzbl -0x1(%rdx),%edi
 11211bd:	mov    %dil,-0x4(%rcx,%rax,2)
 11211c2:	mov    %sil,-0x1(%rdx)
 11211c6:	movzbl -0x3(%rcx,%rax,2),%esi
 11211cb:	movzbl -0x4(%rdx),%edi
 11211cf:	mov    %dil,-0x3(%rcx,%rax,2)
 11211d4:	mov    %sil,-0x4(%rdx)
 11211d8:	movzbl -0x2(%rcx,%rax,2),%esi
 11211dd:	movzbl -0x3(%rdx),%edi
 11211e1:	mov    %dil,-0x2(%rcx,%rax,2)
 11211e6:	mov    %sil,-0x3(%rdx)
 11211ea:	movzbl -0x1(%rcx,%rax,2),%esi
 11211ef:	movzbl -0x6(%rdx),%edi
 11211f3:	mov    %dil,-0x1(%rcx,%rax,2)
 11211f8:	mov    %sil,-0x6(%rdx)
 11211fc:	movzbl (%rcx,%rax,2),%esi
 1121200:	movzbl -0x5(%rdx),%edi
 1121204:	mov    %dil,(%rcx,%rax,2)
 1121208:	mov    %sil,-0x5(%rdx)
 112120c:	add    $0x4,%rax
 1121210:	add    $0xfffffffffffffff8,%rdx
 1121214:	cmp    %rax,%r11
 1121217:	jne    1121180 <sort.block.block__anon_39129+0x3e40>
 112121d:	jmp    11206d0 <sort.block.block__anon_39129+0x3390>
 1121222:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1121230:	seta   %al
 1121233:	cmp    $0x2,%r11
 1121237:	setae  %cl
 112123a:	test   %cl,%al
 112123c:	je     112062b <sort.block.block__anon_39129+0x32eb>
 1121242:	mov    %esi,-0xe8(%rbp)
 1121248:	lea    0x1(%r9),%r14
 112124c:	mov    %rdi,-0x100(%rbp)
 1121253:	mov    0x8(%rdi),%rax
 1121257:	mov    %rax,-0x68(%rbp)
 112125b:	mov    $0x1,%esi
 1121260:	mov    $0xfffffffffffffffe,%rdi
 1121267:	mov    -0x218(%rbp),%rax
 112126e:	mov    %rax,-0x90(%rbp)
 1121275:	mov    -0x138(%rbp),%rax
 112127c:	mov    %rax,-0x60(%rbp)
 1121280:	mov    -0x220(%rbp),%rax
 1121287:	mov    %rax,-0xe0(%rbp)
 112128e:	mov    %r13,-0xc0(%rbp)
 1121295:	mov    %r10,-0x70(%rbp)
 1121299:	mov    -0x1b8(%rbp),%rax
 11212a0:	mov    %rax,-0x78(%rbp)
 11212a4:	mov    -0x228(%rbp),%rax
 11212ab:	mov    %rax,-0x88(%rbp)
 11212b2:	mov    %r9,%r8
 11212b5:	jmp    1121308 <sort.block.block__anon_39129+0x3fc8>
 11212b7:	nopw   0x0(%rax,%rax,1)
 11212c0:	sub    %rsi,%r9
 11212c3:	inc    %rsi
 11212c6:	addq   $0x2,-0x88(%rbp)
 11212ce:	addq   $0x2,-0x78(%rbp)
 11212d3:	addq   $0x2,-0x70(%rbp)
 11212d8:	addq   $0x2,-0xc0(%rbp)
 11212e0:	dec    %rdi
 11212e3:	addq   $0x2,-0xe0(%rbp)
 11212eb:	addq   $0x2,-0x60(%rbp)
 11212f0:	addq   $0x2,-0x90(%rbp)
 11212f8:	mov    %r9,%r8
 11212fb:	mov    -0x40(%rbp),%r11
 11212ff:	cmp    %r11,%rsi
 1121302:	je     1120610 <sort.block.block__anon_39129+0x32d0>
 1121308:	mov    -0x68(%rbp),%rax
 112130c:	sub    %r14,%rax
 112130f:	jne    1121320 <sort.block.block__anon_39129+0x3fe0>
 1121311:	mov    -0x38(%rbp),%r10
 1121315:	jmp    1121490 <sort.block.block__anon_39129+0x4150>
 112131a:	nopw   0x0(%rax,%rax,1)
 1121320:	mov    %r11,%r9
 1121323:	sub    %rsi,%r9
 1121326:	mov    -0x38(%rbp),%r10
 112132a:	movzwl (%r10,%r14,2),%ecx
 112132f:	mov    %rax,%rdx
 1121332:	or     %r9,%rdx
 1121335:	shr    $0x20,%rdx
 1121339:	je     1121342 <sort.block.block__anon_39129+0x4002>
 112133b:	xor    %edx,%edx
 112133d:	div    %r9
 1121340:	jmp    1121347 <sort.block.block__anon_39129+0x4007>
 1121342:	xor    %edx,%edx
 1121344:	div    %r9d
 1121347:	cmp    $0x1,%rax
 112134b:	adc    $0x0,%rax
 112134f:	mov    -0x30(%rbp),%rdx
 1121353:	mov    (%rdx),%rdx
 1121356:	shl    $0x4,%ecx
 1121359:	lea    (%rdx,%rcx,1),%r9
 112135d:	mov    (%rdx,%rcx,1),%r11
 1121361:	mov    -0x68(%rbp),%rbx
 1121365:	sub    %rax,%rbx
 1121368:	jmp    112137e <sort.block.block__anon_39129+0x403e>
 112136a:	nopw   0x0(%rax,%rax,1)
 1121370:	jb     11213c8 <sort.block.block__anon_39129+0x4088>
 1121372:	mov    %rcx,%r14
 1121375:	cmp    %rbx,%rcx
 1121378:	jae    1121410 <sort.block.block__anon_39129+0x40d0>
 112137e:	lea    (%r14,%rax,1),%rcx
 1121382:	movzwl 0x0(%r13,%rcx,2),%r15d
 1121388:	shl    $0x4,%r15d
 112138c:	cmp    (%rdx,%r15,1),%r11
 1121390:	jne    1121370 <sort.block.block__anon_39129+0x4030>
 1121392:	add    %rdx,%r15
 1121395:	movzwl 0xe(%r9),%r12d
 112139a:	cmp    0xe(%r15),%r12w
 112139f:	jae    1121372 <sort.block.block__anon_39129+0x4032>
 11213a1:	jmp    11213c8 <sort.block.block__anon_39129+0x4088>
 11213a3:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11213b0:	mov    %eax,%ebx
 11213b2:	and    $0x1,%ebx
 11213b5:	add    %rcx,%rbx
 11213b8:	add    %rbx,%r14
 11213bb:	cmp    $0x2,%rax
 11213bf:	mov    %rcx,%rax
 11213c2:	jb     1121490 <sort.block.block__anon_39129+0x4150>
 11213c8:	lea    (%r10,%r14,2),%rcx
 11213cc:	mov    %rax,%rbx
 11213cf:	and    $0xfffffffffffffffe,%rbx
 11213d3:	movzwl (%rbx,%rcx,1),%ecx
 11213d7:	shl    $0x4,%ecx
 11213da:	cmp    (%rdx,%rcx,1),%r11
 11213de:	jne    11213ec <sort.block.block__anon_39129+0x40ac>
 11213e0:	add    %rdx,%rcx
 11213e3:	movzwl 0xe(%r9),%ebx
 11213e8:	cmp    0xe(%rcx),%bx
 11213ec:	setb   %bl
 11213ef:	mov    %rax,%rcx
 11213f2:	shr    %rcx
 11213f5:	test   %bl,%bl
 11213f7:	je     11213b0 <sort.block.block__anon_39129+0x4070>
 11213f9:	xor    %ebx,%ebx
 11213fb:	add    %rbx,%r14
 11213fe:	cmp    $0x2,%rax
 1121402:	mov    %rcx,%rax
 1121405:	jae    11213c8 <sort.block.block__anon_39129+0x4088>
 1121407:	jmp    1121490 <sort.block.block__anon_39129+0x4150>
 112140c:	nopl   0x0(%rax)
 1121410:	mov    -0x68(%rbp),%r14
 1121414:	mov    %r14,%rax
 1121417:	sub    %rcx,%rax
 112141a:	jbe    1121490 <sort.block.block__anon_39129+0x4150>
 112141c:	mov    %rcx,%r14
 112141f:	jmp    1121444 <sort.block.block__anon_39129+0x4104>
 1121421:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1121430:	mov    %eax,%ebx
 1121432:	and    $0x1,%ebx
 1121435:	add    %rcx,%rbx
 1121438:	add    %rbx,%r14
 112143b:	cmp    $0x1,%rax
 112143f:	mov    %rcx,%rax
 1121442:	jbe    1121490 <sort.block.block__anon_39129+0x4150>
 1121444:	lea    (%r10,%r14,2),%rcx
 1121448:	mov    %rax,%rbx
 112144b:	and    $0xfffffffffffffffe,%rbx
 112144f:	movzwl (%rbx,%rcx,1),%ecx
 1121453:	shl    $0x4,%ecx
 1121456:	cmp    (%rdx,%rcx,1),%r11
 112145a:	jne    1121468 <sort.block.block__anon_39129+0x4128>
 112145c:	add    %rdx,%rcx
 112145f:	movzwl 0xe(%r9),%ebx
 1121464:	cmp    0xe(%rcx),%bx
 1121468:	setb   %bl
 112146b:	mov    %rax,%rcx
 112146e:	shr    %rcx
 1121471:	test   %bl,%bl
 1121473:	je     1121430 <sort.block.block__anon_39129+0x40f0>
 1121475:	xor    %ebx,%ebx
 1121477:	add    %rbx,%r14
 112147a:	cmp    $0x1,%rax
 112147e:	mov    %rcx,%rax
 1121481:	ja     1121444 <sort.block.block__anon_39129+0x4104>
 1121483:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1121490:	mov    %rsi,%rax
 1121493:	shr    %rax
 1121496:	cmp    $0x20,%rsi
 112149a:	setb   %cl
 112149d:	cmp    $0xf,%rax
 11214a1:	sete   %dl
 11214a4:	or     %cl,%dl
 11214a6:	je     11214b0 <sort.block.block__anon_39129+0x4170>
 11214a8:	xor    %edx,%edx
 11214aa:	jmp    112163f <sort.block.block__anon_39129+0x42ff>
 11214af:	nop
 11214b0:	lea    -0x10(%rax),%rcx
 11214b4:	mov    %rcx,%r9
 11214b7:	shr    $0x4,%r9
 11214bb:	lea    0x1(%r9),%r11
 11214bf:	cmp    $0x30,%rcx
 11214c3:	jae    11214e0 <sort.block.block__anon_39129+0x41a0>
 11214c5:	xor    %edx,%edx
 11214c7:	test   $0x3,%r11b
 11214cb:	jne    11215cf <sort.block.block__anon_39129+0x428f>
 11214d1:	jmp    112163f <sort.block.block__anon_39129+0x42ff>
 11214d6:	cs nopw 0x0(%rax,%rax,1)
 11214e0:	mov    %r11,%rbx
 11214e3:	and    $0xfffffffffffffffc,%rbx
 11214e7:	mov    -0xc8(%rbp),%rcx
 11214ee:	lea    (%rcx,%r8,2),%rcx
 11214f2:	mov    -0x88(%rbp),%rdx
 11214f9:	lea    (%rdx,%r8,2),%r15
 11214fd:	xor    %edx,%edx
 11214ff:	nop
 1121500:	vmovdqu 0x20(%r15,%rdx,2),%ymm0
 1121507:	vmovdqu -0x60(%rcx),%ymm1
 112150c:	vpshufb %ymm2,%ymm1,%ymm1
 1121511:	vpermq $0x4e,%ymm1,%ymm1
 1121517:	vmovdqu %ymm1,0x20(%r15,%rdx,2)
 112151e:	vpshufb %ymm2,%ymm0,%ymm0
 1121523:	vpermq $0x4e,%ymm0,%ymm0
 1121529:	vmovdqu %ymm0,-0x60(%rcx)
 112152e:	vmovdqu (%r15,%rdx,2),%ymm0
 1121534:	vmovdqu -0x40(%rcx),%ymm1
 1121539:	vpshufb %ymm2,%ymm1,%ymm1
 112153e:	vpermq $0x4e,%ymm1,%ymm1
 1121544:	vmovdqu %ymm1,(%r15,%rdx,2)
 112154a:	vpshufb %ymm2,%ymm0,%ymm0
 112154f:	vpermq $0x4e,%ymm0,%ymm0
 1121555:	vmovdqu %ymm0,-0x40(%rcx)
 112155a:	vmovdqu -0x20(%r15,%rdx,2),%ymm0
 1121561:	vmovdqu -0x20(%rcx),%ymm1
 1121566:	vpshufb %ymm2,%ymm1,%ymm1
 112156b:	vpermq $0x4e,%ymm1,%ymm1
 1121571:	vmovdqu %ymm1,-0x20(%r15,%rdx,2)
 1121578:	vpshufb %ymm2,%ymm0,%ymm0
 112157d:	vpermq $0x4e,%ymm0,%ymm0
 1121583:	vmovdqu %ymm0,-0x20(%rcx)
 1121588:	vmovdqu -0x40(%r15,%rdx,2),%ymm0
 112158f:	vmovdqu (%rcx),%ymm1
 1121593:	vpshufb %ymm2,%ymm1,%ymm1
 1121598:	vpermq $0x4e,%ymm1,%ymm1
 112159e:	vmovdqu %ymm1,-0x40(%r15,%rdx,2)
 11215a5:	vpshufb %ymm2,%ymm0,%ymm0
 11215aa:	vpermq $0x4e,%ymm0,%ymm0
 11215b0:	vmovdqu %ymm0,(%rcx)
 11215b4:	sub    $0xffffffffffffff80,%rcx
 11215b8:	add    $0xffffffffffffffc0,%rdx
 11215bc:	add    $0xfffffffffffffffc,%rbx
 11215c0:	jne    1121500 <sort.block.block__anon_39129+0x41c0>
 11215c6:	neg    %rdx
 11215c9:	test   $0x3,%r11b
 11215cd:	je     112163f <sort.block.block__anon_39129+0x42ff>
 11215cf:	inc    %r9b
 11215d2:	movzbl %r9b,%ecx
 11215d6:	and    $0x3,%ecx
 11215d9:	shl    $0x5,%ecx
 11215dc:	mov    -0x78(%rbp),%r9
 11215e0:	lea    (%r9,%r8,2),%r11
 11215e4:	mov    %rdx,%r9
 11215e7:	neg    %r9
 11215ea:	add    %rdx,%rdx
 11215ed:	lea    (%rdx,%r8,2),%rdx
 11215f1:	add    %r10,%rdx
 11215f4:	xor    %ebx,%ebx
 11215f6:	cs nopw 0x0(%rax,%rax,1)
 1121600:	vmovdqu (%r11,%r9,2),%ymm0
 1121606:	vmovdqu (%rdx,%rbx,1),%ymm1
 112160b:	vpshufb %ymm2,%ymm1,%ymm1
 1121610:	vpermq $0x4e,%ymm1,%ymm1
 1121616:	vmovdqu %ymm1,(%r11,%r9,2)
 112161c:	vpshufb %ymm2,%ymm0,%ymm0
 1121621:	vpermq $0x4e,%ymm0,%ymm0
 1121627:	vmovdqu %ymm0,(%rdx,%rbx,1)
 112162c:	add    $0xfffffffffffffff0,%r9
 1121630:	add    $0x20,%rbx
 1121634:	cmp    %rbx,%rcx
 1121637:	jne    1121600 <sort.block.block__anon_39129+0x42c0>
 1121639:	neg    %r9
 112163c:	mov    %r9,%rdx
 112163f:	mov    %rdx,%r9
 1121642:	sub    %rax,%r9
 1121645:	jae    112178d <sort.block.block__anon_39129+0x444d>
 112164b:	mov    %eax,%ecx
 112164d:	sub    %edx,%ecx
 112164f:	test   $0x3,%cl
 1121652:	je     11216b3 <sort.block.block__anon_39129+0x4373>
 1121654:	mov    %eax,%ecx
 1121656:	sub    %dl,%cl
 1121658:	movzbl %cl,%ecx
 112165b:	and    $0x3,%ecx
 112165e:	neg    %rcx
 1121661:	lea    (%r8,%r8,1),%rbx
 1121665:	mov    -0x70(%rbp),%r10
 1121669:	lea    (%r10,%r8,2),%r11
 112166d:	sub    %rdx,%r11
 1121670:	sub    %rdx,%r11
 1121673:	lea    (%rbx,%rdx,2),%rbx
 1121677:	add    -0x50(%rbp),%rbx
 112167b:	xor    %r15d,%r15d
 112167e:	xchg   %ax,%ax
 1121680:	movzbl -0x1(%rbx),%r12d
 1121685:	movzbl (%r11,%r15,2),%r10d
 112168a:	mov    %r10b,-0x1(%rbx)
 112168e:	mov    %r12b,(%r11,%r15,2)
 1121692:	movzbl (%rbx),%r10d
 1121696:	movzbl 0x1(%r11,%r15,2),%r12d
 112169c:	mov    %r12b,(%rbx)
 112169f:	mov    %r10b,0x1(%r11,%r15,2)
 11216a4:	dec    %r15
 11216a7:	add    $0x2,%rbx
 11216ab:	cmp    %r15,%rcx
 11216ae:	jne    1121680 <sort.block.block__anon_39129+0x4340>
 11216b0:	sub    %r15,%rdx
 11216b3:	cmp    $0xfffffffffffffffc,%r9
 11216b7:	ja     112178d <sort.block.block__anon_39129+0x444d>
 11216bd:	mov    -0x80(%rbp),%rcx
 11216c1:	lea    (%rcx,%r8,2),%rcx
 11216c5:	mov    -0xc0(%rbp),%r9
 11216cc:	lea    (%r9,%r8,2),%r9
 11216d0:	sub    %rdx,%r9
 11216d3:	sub    %rdx,%r9
 11216d6:	cs nopw 0x0(%rax,%rax,1)
 11216e0:	movzbl -0x7(%rcx,%rdx,2),%r10d
 11216e6:	movzbl 0x2(%r9),%r11d
 11216eb:	mov    %r11b,-0x7(%rcx,%rdx,2)
 11216f0:	mov    %r10b,0x2(%r9)
 11216f4:	movzbl -0x6(%rcx,%rdx,2),%r10d
 11216fa:	movzbl 0x3(%r9),%r11d
 11216ff:	mov    %r11b,-0x6(%rcx,%rdx,2)
 1121704:	mov    %r10b,0x3(%r9)
 1121708:	movzbl -0x5(%rcx,%rdx,2),%r10d
 112170e:	movzbl (%r9),%r11d
 1121712:	mov    %r11b,-0x5(%rcx,%rdx,2)
 1121717:	mov    %r10b,(%r9)
 112171a:	movzbl -0x4(%rcx,%rdx,2),%r10d
 1121720:	movzbl 0x1(%r9),%r11d
 1121725:	mov    %r11b,-0x4(%rcx,%rdx,2)
 112172a:	mov    %r10b,0x1(%r9)
 112172e:	movzbl -0x3(%rcx,%rdx,2),%r10d
 1121734:	movzbl -0x2(%r9),%r11d
 1121739:	mov    %r11b,-0x3(%rcx,%rdx,2)
 112173e:	mov    %r10b,-0x2(%r9)
 1121742:	movzbl -0x2(%rcx,%rdx,2),%r10d
 1121748:	movzbl -0x1(%r9),%r11d
 112174d:	mov    %r11b,-0x2(%rcx,%rdx,2)
 1121752:	mov    %r10b,-0x1(%r9)
 1121756:	movzbl -0x1(%rcx,%rdx,2),%r10d
 112175c:	movzbl -0x4(%r9),%r11d
 1121761:	mov    %r11b,-0x1(%rcx,%rdx,2)
 1121766:	mov    %r10b,-0x4(%r9)
 112176a:	movzbl (%rcx,%rdx,2),%r10d
 112176f:	movzbl -0x3(%r9),%r11d
 1121774:	mov    %r11b,(%rcx,%rdx,2)
 1121778:	mov    %r10b,-0x3(%r9)
 112177c:	add    $0x4,%rdx
 1121780:	add    $0xfffffffffffffff8,%r9
 1121784:	cmp    %rdx,%rax
 1121787:	jne    11216e0 <sort.block.block__anon_39129+0x43a0>
 112178d:	lea    -0x1(%r14),%r9
 1121791:	mov    %r9,%rax
 1121794:	sub    %r8,%rax
 1121797:	mov    %rax,%rcx
 112179a:	sub    %rsi,%rcx
 112179d:	mov    %rcx,%r11
 11217a0:	shr    %r11
 11217a3:	cmp    $0x20,%rcx
 11217a7:	setb   %cl
 11217aa:	cmp    $0xf,%r11
 11217ae:	sete   %dl
 11217b1:	or     %cl,%dl
 11217b3:	je     11217c0 <sort.block.block__anon_39129+0x4480>
 11217b5:	xor    %edx,%edx
 11217b7:	jmp    112198f <sort.block.block__anon_39129+0x464f>
 11217bc:	nopl   0x0(%rax)
 11217c0:	lea    -0x10(%r11),%r15
 11217c4:	cmp    $0x30,%r15
 11217c8:	jae    11217f0 <sort.block.block__anon_39129+0x44b0>
 11217ca:	xor    %edx,%edx
 11217cc:	shr    $0x4,%r15
 11217d0:	inc    %r15
 11217d3:	test   $0x3,%r15b
 11217d7:	jne    1121912 <sort.block.block__anon_39129+0x45d2>
 11217dd:	jmp    112198f <sort.block.block__anon_39129+0x464f>
 11217e2:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11217f0:	lea    (%r14,%rdi,1),%rbx
 11217f4:	sub    %r8,%rbx
 11217f7:	shr    %rbx
 11217fa:	add    $0xfffffffffffffff0,%rbx
 11217fe:	shr    $0x4,%rbx
 1121802:	inc    %rbx
 1121805:	and    $0xfffffffffffffffc,%rbx
 1121809:	mov    -0x250(%rbp),%rcx
 1121810:	lea    (%rcx,%r14,2),%rcx
 1121814:	mov    -0xe0(%rbp),%rdx
 112181b:	lea    (%rdx,%r8,2),%r12
 112181f:	xor    %edx,%edx
 1121821:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1121830:	vmovdqu 0x20(%rcx,%rdx,2),%ymm0
 1121836:	vmovdqu -0x20(%r12),%ymm1
 112183d:	vpshufb %ymm2,%ymm1,%ymm1
 1121842:	vpermq $0x4e,%ymm1,%ymm1
 1121848:	vmovdqu %ymm1,0x20(%rcx,%rdx,2)
 112184e:	vpshufb %ymm2,%ymm0,%ymm0
 1121853:	vpermq $0x4e,%ymm0,%ymm0
 1121859:	vmovdqu %ymm0,-0x20(%r12)
 1121860:	vmovdqu (%rcx,%rdx,2),%ymm0
 1121865:	vmovdqu (%r12),%ymm1
 112186b:	vpshufb %ymm2,%ymm1,%ymm1
 1121870:	vpermq $0x4e,%ymm1,%ymm1
 1121876:	vmovdqu %ymm1,(%rcx,%rdx,2)
 112187b:	vpshufb %ymm2,%ymm0,%ymm0
 1121880:	vpermq $0x4e,%ymm0,%ymm0
 1121886:	vmovdqu %ymm0,(%r12)
 112188c:	vmovdqu -0x20(%rcx,%rdx,2),%ymm0
 1121892:	vmovdqu 0x20(%r12),%ymm1
 1121899:	vpshufb %ymm2,%ymm1,%ymm1
 112189e:	vpermq $0x4e,%ymm1,%ymm1
 11218a4:	vmovdqu %ymm1,-0x20(%rcx,%rdx,2)
 11218aa:	vpshufb %ymm2,%ymm0,%ymm0
 11218af:	vpermq $0x4e,%ymm0,%ymm0
 11218b5:	vmovdqu %ymm0,0x20(%r12)
 11218bc:	vmovdqu -0x40(%rcx,%rdx,2),%ymm0
 11218c2:	vmovdqu 0x40(%r12),%ymm1
 11218c9:	vpshufb %ymm2,%ymm1,%ymm1
 11218ce:	vpermq $0x4e,%ymm1,%ymm1
 11218d4:	vmovdqu %ymm1,-0x40(%rcx,%rdx,2)
 11218da:	vpshufb %ymm2,%ymm0,%ymm0
 11218df:	vpermq $0x4e,%ymm0,%ymm0
 11218e5:	vmovdqu %ymm0,0x40(%r12)
 11218ec:	add    $0xffffffffffffffc0,%rdx
 11218f0:	sub    $0xffffffffffffff80,%r12
 11218f4:	add    $0xfffffffffffffffc,%rbx
 11218f8:	jne    1121830 <sort.block.block__anon_39129+0x44f0>
 11218fe:	neg    %rdx
 1121901:	shr    $0x4,%r15
 1121905:	inc    %r15
 1121908:	test   $0x3,%r15b
 112190c:	je     112198f <sort.block.block__anon_39129+0x464f>
 1121912:	lea    (%r14,%rdi,1),%r10
 1121916:	mov    -0x78(%rbp),%rcx
 112191a:	lea    (%rcx,%r10,2),%rbx
 112191e:	mov    %rdx,%rcx
 1121921:	neg    %rcx
 1121924:	add    %rdx,%rdx
 1121927:	lea    (%rdx,%r8,2),%rdx
 112192b:	add    -0x60(%rbp),%rdx
 112192f:	sub    %r8d,%r10d
 1121932:	shr    %r10b
 1121935:	add    $0xf0,%r10b
 1121939:	shr    $0x4,%r10b
 112193d:	inc    %r10b
 1121940:	movzbl %r10b,%r15d
 1121944:	and    $0x3,%r15d
 1121948:	shl    $0x5,%r15d
 112194c:	xor    %r12d,%r12d
 112194f:	nop
 1121950:	vmovdqu (%rbx,%rcx,2),%ymm0
 1121955:	vmovdqu (%rdx,%r12,1),%ymm1
 112195b:	vpshufb %ymm2,%ymm1,%ymm1
 1121960:	vpermq $0x4e,%ymm1,%ymm1
 1121966:	vmovdqu %ymm1,(%rbx,%rcx,2)
 112196b:	vpshufb %ymm2,%ymm0,%ymm0
 1121970:	vpermq $0x4e,%ymm0,%ymm0
 1121976:	vmovdqu %ymm0,(%rdx,%r12,1)
 112197c:	add    $0xfffffffffffffff0,%rcx
 1121980:	add    $0x20,%r12
 1121984:	cmp    %r12,%r15
 1121987:	jne    1121950 <sort.block.block__anon_39129+0x4610>
 1121989:	neg    %rcx
 112198c:	mov    %rcx,%rdx
 112198f:	mov    %rdx,%rbx
 1121992:	sub    %r11,%rbx
 1121995:	jae    1121afd <sort.block.block__anon_39129+0x47bd>
 112199b:	sub    %edx,%r11d
 112199e:	test   $0x3,%r11b
 11219a2:	je     1121a1a <sort.block.block__anon_39129+0x46da>
 11219a4:	mov    -0x148(%rbp),%rcx
 11219ab:	lea    (%rcx,%r14,2),%rcx
 11219af:	sub    %rdx,%rcx
 11219b2:	sub    %rdx,%rcx
 11219b5:	lea    (%r14,%rdi,1),%r10d
 11219b9:	sub    %r8d,%r10d
 11219bc:	shr    %r10b
 11219bf:	sub    %dl,%r10b
 11219c2:	movzbl %r10b,%r11d
 11219c6:	and    $0x3,%r11d
 11219ca:	neg    %r11
 11219cd:	lea    (%r8,%r8,1),%r10
 11219d1:	lea    (%r10,%rdx,2),%r15
 11219d5:	add    -0x60(%rbp),%r15
 11219d9:	xor    %r12d,%r12d
 11219dc:	nopl   0x0(%rax)
 11219e0:	movzbl (%r15),%r10d
 11219e4:	movzbl -0x1(%rcx,%r12,2),%r13d
 11219ea:	mov    %r13b,(%r15)
 11219ed:	mov    %r10b,-0x1(%rcx,%r12,2)
 11219f2:	movzbl 0x1(%r15),%r10d
 11219f7:	movzbl (%rcx,%r12,2),%r13d
 11219fc:	mov    %r13b,0x1(%r15)
 1121a00:	mov    %r10b,(%rcx,%r12,2)
 1121a04:	dec    %r12
 1121a07:	add    $0x2,%r15
 1121a0b:	cmp    %r12,%r11
 1121a0e:	jne    11219e0 <sort.block.block__anon_39129+0x46a0>
 1121a10:	sub    %r12,%rdx
 1121a13:	mov    -0x98(%rbp),%r13
 1121a1a:	cmp    $0xfffffffffffffffc,%rbx
 1121a1e:	ja     1121afd <sort.block.block__anon_39129+0x47bd>
 1121a24:	lea    (%r14,%rdi,1),%r11
 1121a28:	sub    %r8,%r11
 1121a2b:	shr    %r11
 1121a2e:	mov    -0x90(%rbp),%rcx
 1121a35:	lea    (%rcx,%r8,2),%rcx
 1121a39:	mov    -0x148(%rbp),%rbx
 1121a40:	lea    (%rbx,%r14,2),%rbx
 1121a44:	sub    %rdx,%rbx
 1121a47:	sub    %rdx,%rbx
 1121a4a:	nopw   0x0(%rax,%rax,1)
 1121a50:	movzbl -0x2(%rcx,%rdx,2),%r10d
 1121a56:	movzbl -0x1(%rbx),%r15d
 1121a5b:	mov    %r15b,-0x2(%rcx,%rdx,2)
 1121a60:	mov    %r10b,-0x1(%rbx)
 1121a64:	movzbl -0x1(%rcx,%rdx,2),%r10d
 1121a6a:	movzbl (%rbx),%r15d
 1121a6e:	mov    %r15b,-0x1(%rcx,%rdx,2)
 1121a73:	mov    %r10b,(%rbx)
 1121a76:	movzbl (%rcx,%rdx,2),%r10d
 1121a7b:	movzbl -0x3(%rbx),%r15d
 1121a80:	mov    %r15b,(%rcx,%rdx,2)
 1121a84:	mov    %r10b,-0x3(%rbx)
 1121a88:	movzbl 0x1(%rcx,%rdx,2),%r10d
 1121a8e:	movzbl -0x2(%rbx),%r15d
 1121a93:	mov    %r15b,0x1(%rcx,%rdx,2)
 1121a98:	mov    %r10b,-0x2(%rbx)
 1121a9c:	movzbl 0x2(%rcx,%rdx,2),%r10d
 1121aa2:	movzbl -0x5(%rbx),%r15d
 1121aa7:	mov    %r15b,0x2(%rcx,%rdx,2)
 1121aac:	mov    %r10b,-0x5(%rbx)
 1121ab0:	movzbl 0x3(%rcx,%rdx,2),%r10d
 1121ab6:	movzbl -0x4(%rbx),%r15d
 1121abb:	mov    %r15b,0x3(%rcx,%rdx,2)
 1121ac0:	mov    %r10b,-0x4(%rbx)
 1121ac4:	movzbl 0x4(%rcx,%rdx,2),%r10d
 1121aca:	movzbl -0x7(%rbx),%r15d
 1121acf:	mov    %r15b,0x4(%rcx,%rdx,2)
 1121ad4:	mov    %r10b,-0x7(%rbx)
 1121ad8:	movzbl 0x5(%rcx,%rdx,2),%r10d
 1121ade:	movzbl -0x6(%rbx),%r15d
 1121ae3:	mov    %r15b,0x5(%rcx,%rdx,2)
 1121ae8:	mov    %r10b,-0x6(%rbx)
 1121aec:	add    $0x4,%rdx
 1121af0:	add    $0xfffffffffffffff8,%rbx
 1121af4:	cmp    %rdx,%r11
 1121af7:	jne    1121a50 <sort.block.block__anon_39129+0x4710>
 1121afd:	mov    %rax,%rdx
 1121b00:	shr    %rdx
 1121b03:	cmp    $0x20,%rax
 1121b07:	setb   %al
 1121b0a:	cmp    $0xf,%rdx
 1121b0e:	sete   %cl
 1121b11:	or     %al,%cl
 1121b13:	je     1121b20 <sort.block.block__anon_39129+0x47e0>
 1121b15:	xor    %eax,%eax
 1121b17:	jmp    1121cbf <sort.block.block__anon_39129+0x497f>
 1121b1c:	nopl   0x0(%rax)
 1121b20:	lea    -0x10(%rdx),%rax
 1121b24:	mov    %rax,%r11
 1121b27:	shr    $0x4,%r11
 1121b2b:	inc    %r11
 1121b2e:	cmp    $0x30,%rax
 1121b32:	mov    -0x38(%rbp),%r10
 1121b36:	jae    1121b50 <sort.block.block__anon_39129+0x4810>
 1121b38:	xor    %eax,%eax
 1121b3a:	and    $0x3,%r11d
 1121b3e:	jne    1121c4f <sort.block.block__anon_39129+0x490f>
 1121b44:	jmp    1121cbf <sort.block.block__anon_39129+0x497f>
 1121b49:	nopl   0x0(%rax)
 1121b50:	mov    %r11,%rbx
 1121b53:	movabs $0x1ffffffffffffffc,%rax
 1121b5d:	and    %rax,%rbx
 1121b60:	mov    -0xc8(%rbp),%rax
 1121b67:	lea    (%rax,%r8,2),%rcx
 1121b6b:	mov    -0x1e0(%rbp),%rax
 1121b72:	lea    (%rax,%r14,2),%r15
 1121b76:	xor    %eax,%eax
 1121b78:	nopl   0x0(%rax,%rax,1)
 1121b80:	vmovdqu (%r15,%rax,2),%ymm0
 1121b86:	vmovdqu -0x60(%rcx),%ymm1
 1121b8b:	vpshufb %ymm2,%ymm1,%ymm1
 1121b90:	vpermq $0x4e,%ymm1,%ymm1
 1121b96:	vmovdqu %ymm1,(%r15,%rax,2)
 1121b9c:	vpshufb %ymm2,%ymm0,%ymm0
 1121ba1:	vpermq $0x4e,%ymm0,%ymm0
 1121ba7:	vmovdqu %ymm0,-0x60(%rcx)
 1121bac:	vmovdqu -0x20(%r15,%rax,2),%ymm0
 1121bb3:	vmovdqu -0x40(%rcx),%ymm1
 1121bb8:	vpshufb %ymm2,%ymm1,%ymm1
 1121bbd:	vpermq $0x4e,%ymm1,%ymm1
 1121bc3:	vmovdqu %ymm1,-0x20(%r15,%rax,2)
 1121bca:	vpshufb %ymm2,%ymm0,%ymm0
 1121bcf:	vpermq $0x4e,%ymm0,%ymm0
 1121bd5:	vmovdqu %ymm0,-0x40(%rcx)
 1121bda:	vmovdqu -0x40(%r15,%rax,2),%ymm0
 1121be1:	vmovdqu -0x20(%rcx),%ymm1
 1121be6:	vpshufb %ymm2,%ymm1,%ymm1
 1121beb:	vpermq $0x4e,%ymm1,%ymm1
 1121bf1:	vmovdqu %ymm1,-0x40(%r15,%rax,2)
 1121bf8:	vpshufb %ymm2,%ymm0,%ymm0
 1121bfd:	vpermq $0x4e,%ymm0,%ymm0
 1121c03:	vmovdqu %ymm0,-0x20(%rcx)
 1121c08:	vmovdqu -0x60(%r15,%rax,2),%ymm0
 1121c0f:	vmovdqu (%rcx),%ymm1
 1121c13:	vpshufb %ymm2,%ymm1,%ymm1
 1121c18:	vpermq $0x4e,%ymm1,%ymm1
 1121c1e:	vmovdqu %ymm1,-0x60(%r15,%rax,2)
 1121c25:	vpshufb %ymm2,%ymm0,%ymm0
 1121c2a:	vpermq $0x4e,%ymm0,%ymm0
 1121c30:	vmovdqu %ymm0,(%rcx)
 1121c34:	sub    $0xffffffffffffff80,%rcx
 1121c38:	add    $0xffffffffffffffc0,%rax
 1121c3c:	add    $0xfffffffffffffffc,%rbx
 1121c40:	jne    1121b80 <sort.block.block__anon_39129+0x4840>
 1121c46:	neg    %rax
 1121c49:	and    $0x3,%r11d
 1121c4d:	je     1121cbf <sort.block.block__anon_39129+0x497f>
 1121c4f:	mov    -0x1e0(%rbp),%rcx
 1121c56:	lea    (%rcx,%r14,2),%rbx
 1121c5a:	mov    %rax,%rcx
 1121c5d:	neg    %rcx
 1121c60:	add    %rax,%rax
 1121c63:	lea    (%rax,%r8,2),%rax
 1121c67:	add    %r10,%rax
 1121c6a:	shl    $0x5,%r11d
 1121c6e:	xor    %r15d,%r15d
 1121c71:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1121c80:	vmovdqu (%rbx,%rcx,2),%ymm0
 1121c85:	vmovdqu (%rax,%r15,1),%ymm1
 1121c8b:	vpshufb %ymm2,%ymm1,%ymm1
 1121c90:	vpermq $0x4e,%ymm1,%ymm1
 1121c96:	vmovdqu %ymm1,(%rbx,%rcx,2)
 1121c9b:	vpshufb %ymm2,%ymm0,%ymm0
 1121ca0:	vpermq $0x4e,%ymm0,%ymm0
 1121ca6:	vmovdqu %ymm0,(%rax,%r15,1)
 1121cac:	add    $0xfffffffffffffff0,%rcx
 1121cb0:	add    $0x20,%r15
 1121cb4:	cmp    %r15,%r11
 1121cb7:	jne    1121c80 <sort.block.block__anon_39129+0x4940>
 1121cb9:	neg    %rcx
 1121cbc:	mov    %rcx,%rax
 1121cbf:	mov    %rax,%r11
 1121cc2:	sub    %rdx,%r11
 1121cc5:	jae    11212c0 <sort.block.block__anon_39129+0x3f80>
 1121ccb:	mov    %edx,%ecx
 1121ccd:	sub    %eax,%ecx
 1121ccf:	and    $0x3,%ecx
 1121cd2:	je     1121d3a <sort.block.block__anon_39129+0x49fa>
 1121cd4:	mov    -0x148(%rbp),%rbx
 1121cdb:	lea    (%rbx,%r14,2),%rbx
 1121cdf:	sub    %rax,%rbx
 1121ce2:	sub    %rax,%rbx
 1121ce5:	lea    (%r8,%r8,1),%r10
 1121ce9:	lea    (%r10,%rax,2),%r15
 1121ced:	add    -0x50(%rbp),%r15
 1121cf1:	neg    %rcx
 1121cf4:	xor    %r12d,%r12d
 1121cf7:	nopw   0x0(%rax,%rax,1)
 1121d00:	movzbl -0x1(%r15),%r10d
 1121d05:	movzbl -0x1(%rbx,%r12,2),%r13d
 1121d0b:	mov    %r13b,-0x1(%r15)
 1121d0f:	mov    %r10b,-0x1(%rbx,%r12,2)
 1121d14:	movzbl (%r15),%r10d
 1121d18:	movzbl (%rbx,%r12,2),%r13d
 1121d1d:	mov    %r13b,(%r15)
 1121d20:	mov    %r10b,(%rbx,%r12,2)
 1121d24:	dec    %r12
 1121d27:	add    $0x2,%r15
 1121d2b:	cmp    %r12,%rcx
 1121d2e:	jne    1121d00 <sort.block.block__anon_39129+0x49c0>
 1121d30:	sub    %r12,%rax
 1121d33:	mov    -0x98(%rbp),%r13
 1121d3a:	cmp    $0xfffffffffffffffc,%r11
 1121d3e:	ja     11212c0 <sort.block.block__anon_39129+0x3f80>
 1121d44:	mov    -0x80(%rbp),%rcx
 1121d48:	lea    (%rcx,%r8,2),%rcx
 1121d4c:	mov    -0x148(%rbp),%r8
 1121d53:	lea    (%r8,%r14,2),%r8
 1121d57:	sub    %rax,%r8
 1121d5a:	sub    %rax,%r8
 1121d5d:	nopl   (%rax)
 1121d60:	movzbl -0x7(%rcx,%rax,2),%r10d
 1121d66:	movzbl -0x1(%r8),%r11d
 1121d6b:	mov    %r11b,-0x7(%rcx,%rax,2)
 1121d70:	mov    %r10b,-0x1(%r8)
 1121d74:	movzbl -0x6(%rcx,%rax,2),%r10d
 1121d7a:	movzbl (%r8),%r11d
 1121d7e:	mov    %r11b,-0x6(%rcx,%rax,2)
 1121d83:	mov    %r10b,(%r8)
 1121d86:	movzbl -0x5(%rcx,%rax,2),%r10d
 1121d8c:	movzbl -0x3(%r8),%r11d
 1121d91:	mov    %r11b,-0x5(%rcx,%rax,2)
 1121d96:	mov    %r10b,-0x3(%r8)
 1121d9a:	movzbl -0x4(%rcx,%rax,2),%r10d
 1121da0:	movzbl -0x2(%r8),%r11d
 1121da5:	mov    %r11b,-0x4(%rcx,%rax,2)
 1121daa:	mov    %r10b,-0x2(%r8)
 1121dae:	movzbl -0x3(%rcx,%rax,2),%r10d
 1121db4:	movzbl -0x5(%r8),%r11d
 1121db9:	mov    %r11b,-0x3(%rcx,%rax,2)
 1121dbe:	mov    %r10b,-0x5(%r8)
 1121dc2:	movzbl -0x2(%rcx,%rax,2),%r10d
 1121dc8:	movzbl -0x4(%r8),%r11d
 1121dcd:	mov    %r11b,-0x2(%rcx,%rax,2)
 1121dd2:	mov    %r10b,-0x4(%r8)
 1121dd6:	movzbl -0x1(%rcx,%rax,2),%r10d
 1121ddc:	movzbl -0x7(%r8),%r11d
 1121de1:	mov    %r11b,-0x1(%rcx,%rax,2)
 1121de6:	mov    %r10b,-0x7(%r8)
 1121dea:	movzbl (%rcx,%rax,2),%r10d
 1121def:	movzbl -0x6(%r8),%r11d
 1121df4:	mov    %r11b,(%rcx,%rax,2)
 1121df8:	mov    %r10b,-0x6(%r8)
 1121dfc:	add    $0x4,%rax
 1121e00:	add    $0xfffffffffffffff8,%r8
 1121e04:	cmp    %rax,%rdx
 1121e07:	jne    1121d60 <sort.block.block__anon_39129+0x4a20>
 1121e0d:	jmp    11212c0 <sort.block.block__anon_39129+0x3f80>
 1121e12:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1121e20:	mov    -0xb0(%rbp),%rsi
 1121e27:	sub    -0xd0(%rbp),%rsi
 1121e2e:	mov    %rdx,%rax
 1121e31:	or     %rsi,%rax
 1121e34:	shr    $0x20,%rax
 1121e38:	je     1121e4a <sort.block.block__anon_39129+0x4b0a>
 1121e3a:	mov    %rdx,%rax
 1121e3d:	mov    %rdx,%rcx
 1121e40:	xor    %edx,%edx
 1121e42:	div    %rsi
 1121e45:	mov    %rax,%rdi
 1121e48:	jmp    1121e55 <sort.block.block__anon_39129+0x4b15>
 1121e4a:	mov    %edx,%eax
 1121e4c:	mov    %rdx,%rcx
 1121e4f:	xor    %edx,%edx
 1121e51:	div    %esi
 1121e53:	mov    %eax,%edi
 1121e55:	mov    -0xa0(%rbp),%rax
 1121e5c:	mov    -0xa8(%rbp),%rsi
 1121e63:	lea    0x1(%rdi),%r8
 1121e67:	lea    (%r10,%rsi,2),%rdx
 1121e6b:	mov    %rdx,-0x68(%rbp)
 1121e6f:	sub    %rsi,%rax
 1121e72:	mov    %rax,-0x1e8(%rbp)
 1121e79:	setne  %al
 1121e7c:	cmp    $0x200,%rdi
 1121e83:	setb   %dl
 1121e86:	or     %al,%dl
 1121e88:	mov    %dl,-0x140(%rbp)
 1121e8e:	mov    %rdi,-0x100(%rbp)
 1121e95:	lea    0x2(,%rdi,2),%rax
 1121e9d:	mov    %rax,-0x238(%rbp)
 1121ea4:	lea    -0x1(%rcx),%rax
 1121ea8:	mov    %rax,-0x1f0(%rbp)
 1121eaf:	mov    %r8d,%eax
 1121eb2:	and    $0x3,%eax
 1121eb5:	mov    %rax,-0xb0(%rbp)
 1121ebc:	mov    %r8,%r9
 1121ebf:	and    $0xfffffffffffffffc,%r9
 1121ec3:	mov    -0x50(%rbp),%rax
 1121ec7:	mov    -0xd0(%rbp),%rdx
 1121ece:	lea    (%rax,%rdx,2),%rdx
 1121ed2:	mov    %rdx,-0x200(%rbp)
 1121ed9:	mov    -0x80(%rbp),%rdx
 1121edd:	lea    (%rdx,%rsi,2),%rdx
 1121ee1:	mov    %rdx,-0x1d0(%rbp)
 1121ee8:	lea    (%rax,%rsi,2),%rax
 1121eec:	mov    %rax,-0x1a8(%rbp)
 1121ef3:	mov    -0x1b0(%rbp),%rax
 1121efa:	lea    (%rax,%rsi,2),%rax
 1121efe:	mov    %rax,-0x230(%rbp)
 1121f05:	xor    %esi,%esi
 1121f07:	xor    %r11d,%r11d
 1121f0a:	mov    %rcx,%rax
 1121f0d:	mov    -0xf8(%rbp),%rdx
 1121f14:	mov    %r8,-0x88(%rbp)
 1121f1b:	mov    %r9,-0x110(%rbp)
 1121f22:	jmp    1121fa8 <sort.block.block__anon_39129+0x4c68>
 1121f27:	nopw   0x0(%rax,%rax,1)
 1121f30:	mov    -0xf0(%rbp),%rbx
 1121f37:	sub    %r13,%rbx
 1121f3a:	mov    %r12,%r14
 1121f3d:	sub    %r13,%r14
 1121f40:	mov    %r15,%rdi
 1121f43:	mov    %r14,%rsi
 1121f46:	vzeroupper 
 1121f49:	call   10fd040 <mem.reverse__anon_36385>
 1121f4e:	mov    -0x38(%rbp),%rax
 1121f52:	lea    (%rax,%r12,2),%rdi
 1121f56:	mov    %rbx,%rsi
 1121f59:	sub    %r14,%rsi
 1121f5c:	call   10fd040 <mem.reverse__anon_36385>
 1121f61:	mov    %r15,%rdi
 1121f64:	mov    %rbx,%rsi
 1121f67:	call   10fd040 <mem.reverse__anon_36385>
 1121f6c:	mov    -0x38(%rbp),%r10
 1121f70:	vmovdqa -0x11f758(%rip),%ymm2        # 1002820 <__anon_38908+0x60>
 1121f78:	mov    -0x248(%rbp),%r11
 1121f7f:	sub    -0x240(%rbp),%r11
 1121f86:	mov    -0x130(%rbp),%rsi
 1121f8d:	cmp    -0x118(%rbp),%rsi
 1121f94:	mov    -0xb8(%rbp),%rax
 1121f9b:	mov    -0xf8(%rbp),%rdx
 1121fa2:	jae    1125150 <sort.block.block__anon_39129+0x7e10>
 1121fa8:	mov    %rsi,%rcx
 1121fab:	lea    (%rsi,%rax,1),%rbx
 1121faf:	add    %rdx,%r11
 1121fb2:	xor    %esi,%esi
 1121fb4:	mov    %rax,%rdi
 1121fb7:	mov    %rdx,%r8
 1121fba:	mov    -0x120(%rbp),%rdx
 1121fc1:	cmp    %rdx,%r11
 1121fc4:	setae  %sil
 1121fc8:	mov    $0x0,%eax
 1121fcd:	cmovae %rdx,%rax
 1121fd1:	sub    %rax,%r11
 1121fd4:	add    %rsi,%rbx
 1121fd7:	mov    %rbx,%r12
 1121fda:	lea    (%rbx,%rdi,1),%rax
 1121fde:	add    %r8,%r11
 1121fe1:	mov    %r11,-0x248(%rbp)
 1121fe8:	cmp    %rdx,%r11
 1121feb:	mov    $0x0,%edi
 1121ff0:	cmovae %rdx,%rdi
 1121ff4:	mov    %rdi,-0x240(%rbp)
 1121ffb:	sbb    $0xffffffffffffffff,%rax
 1121fff:	mov    %rcx,%r13
 1122002:	mov    %rax,-0x130(%rbp)
 1122009:	mov    %rax,%rdx
 112200c:	cmp    -0x188(%rbp),%rcx
 1122013:	jne    1122080 <sort.block.block__anon_39129+0x4d40>
 1122015:	mov    -0x198(%rbp),%rax
 112201c:	cmp    %rax,-0x1a0(%rbp)
 1122023:	jbe    1122050 <sort.block.block__anon_39129+0x4d10>
 1122025:	mov    -0x190(%rbp),%r13
 112202c:	add    %rcx,%r13
 112202f:	mov    -0x130(%rbp),%rdx
 1122036:	cmp    %r13,%r12
 1122039:	je     1121f78 <sort.block.block__anon_39129+0x4c38>
 112203f:	jmp    1122080 <sort.block.block__anon_39129+0x4d40>
 1122041:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1122050:	mov    %rcx,%r13
 1122053:	mov    -0x130(%rbp),%rdx
 112205a:	jae    1122080 <sort.block.block__anon_39129+0x4d40>
 112205c:	mov    -0x130(%rbp),%rdx
 1122063:	sub    -0x190(%rbp),%rdx
 112206a:	mov    %rcx,%r13
 112206d:	cmp    %r12,%rdx
 1122070:	je     1121f78 <sort.block.block__anon_39129+0x4c38>
 1122076:	cs nopw 0x0(%rax,%rax,1)
 1122080:	cmp    -0x160(%rbp),%rcx
 1122087:	jne    11220d0 <sort.block.block__anon_39129+0x4d90>
 1122089:	mov    -0x170(%rbp),%rax
 1122090:	cmp    %rax,-0x178(%rbp)
 1122097:	jbe    11220b0 <sort.block.block__anon_39129+0x4d70>
 1122099:	add    -0x168(%rbp),%r13
 11220a0:	cmp    %r13,%r12
 11220a3:	je     1121f78 <sort.block.block__anon_39129+0x4c38>
 11220a9:	jmp    11220d0 <sort.block.block__anon_39129+0x4d90>
 11220ab:	nopl   0x0(%rax,%rax,1)
 11220b0:	jae    11220d0 <sort.block.block__anon_39129+0x4d90>
 11220b2:	sub    -0x168(%rbp),%rdx
 11220b9:	cmp    %r12,%rdx
 11220bc:	je     1121f78 <sort.block.block__anon_39129+0x4c38>
 11220c2:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11220d0:	mov    %rdx,-0xf0(%rbp)
 11220d7:	movzwl -0x2(%r10,%rdx,2),%edx
 11220dd:	lea    (%r10,%r13,2),%r15
 11220e1:	movzwl (%r10,%r13,2),%edi
 11220e6:	mov    -0x30(%rbp),%rax
 11220ea:	mov    (%rax),%rax
 11220ed:	shl    $0x4,%edx
 11220f0:	shl    $0x4,%edi
 11220f3:	mov    (%rax,%rdi,1),%r8
 11220f7:	cmp    %r8,(%rax,%rdx,1)
 11220fb:	jne    112210b <sort.block.block__anon_39129+0x4dcb>
 11220fd:	add    %rax,%rdx
 1122100:	add    %rax,%rdi
 1122103:	movzwl 0xe(%rdx),%edx
 1122107:	cmp    0xe(%rdi),%dx
 112210b:	jb     1121f30 <sort.block.block__anon_39129+0x4bf0>
 1122111:	movzwl (%r10,%r12,2),%edx
 1122116:	movzwl -0x2(%r10,%r12,2),%edi
 112211c:	shl    $0x4,%edx
 112211f:	shl    $0x4,%edi
 1122122:	mov    (%rax,%rdi,1),%r8
 1122126:	cmp    %r8,(%rax,%rdx,1)
 112212a:	jne    112213a <sort.block.block__anon_39129+0x4dfa>
 112212c:	add    %rax,%rdx
 112212f:	add    %rax,%rdi
 1122132:	movzwl 0xe(%rdx),%eax
 1122136:	cmp    0xe(%rdi),%ax
 112213a:	vmovdqa -0x11f922(%rip),%ymm2        # 1002820 <__anon_38908+0x60>
 1122142:	jae    1121f78 <sort.block.block__anon_39129+0x4c38>
 1122148:	mov    %r15,%rbx
 112214b:	mov    %r12,%rax
 112214e:	sub    %r13,%rax
 1122151:	mov    %rax,%rdi
 1122154:	mov    -0x88(%rbp),%r15
 112215b:	or     %r15,%rdi
 112215e:	shr    $0x20,%rdi
 1122162:	mov    %rax,-0x60(%rbp)
 1122166:	je     112216f <sort.block.block__anon_39129+0x4e2f>
 1122168:	xor    %edx,%edx
 112216a:	div    %r15
 112216d:	jmp    1122174 <sort.block.block__anon_39129+0x4e34>
 112216f:	xor    %edx,%edx
 1122171:	div    %r15d
 1122174:	lea    (%rdx,%r13,1),%rax
 1122178:	mov    %r12,%r11
 112217b:	mov    %rax,-0x78(%rbp)
 112217f:	cmp    %r12,%rax
 1122182:	jae    11221d0 <sort.block.block__anon_39129+0x4e90>
 1122184:	mov    -0x200(%rbp),%rax
 112218b:	mov    -0x78(%rbp),%r8
 112218f:	nop
 1122190:	movzbl -0x1(%rax),%r9d
 1122195:	mov    -0x38(%rbp),%r10
 1122199:	movzbl (%r10,%r8,2),%r10d
 112219e:	mov    %r10b,-0x1(%rax)
 11221a2:	mov    -0x38(%rbp),%r10
 11221a6:	mov    %r9b,(%r10,%r8,2)
 11221aa:	movzbl (%rax),%r9d
 11221ae:	mov    -0x38(%rbp),%r10
 11221b2:	movzbl 0x1(%r10,%r8,2),%r10d
 11221b8:	mov    %r10b,(%rax)
 11221bb:	mov    -0x38(%rbp),%r10
 11221bf:	mov    %r9b,0x1(%r10,%r8,2)
 11221c4:	add    %r15,%r8
 11221c7:	add    $0x2,%rax
 11221cb:	cmp    %r11,%r8
 11221ce:	jb     1122190 <sort.block.block__anon_39129+0x4e50>
 11221d0:	mov    -0xf0(%rbp),%r14
 11221d7:	sub    %r11,%r14
 11221da:	cmp    %r14,%r15
 11221dd:	cmovb  %r15,%r14
 11221e1:	cmp    $0x201,%rdx
 11221e8:	jae    1122210 <sort.block.block__anon_39129+0x4ed0>
 11221ea:	add    %rdx,%rdx
 11221ed:	lea    -0x650(%rbp),%rdi
 11221f4:	mov    %rbx,%rsi
 11221f7:	vzeroupper 
 11221fa:	call   119d8c0 <compiler_rt.memcpy.memcpyFast>
 11221ff:	vmovdqa -0x11f9e7(%rip),%ymm2        # 1002820 <__anon_38908+0x60>
 1122207:	mov    -0x38(%rbp),%r10
 112220b:	jmp    112237e <sort.block.block__anon_39129+0x503e>
 1122210:	mov    -0xa8(%rbp),%rax
 1122217:	cmp    %rax,-0xa0(%rbp)
 112221e:	je     112237e <sort.block.block__anon_39129+0x503e>
 1122224:	mov    %rdx,%r8
 1122227:	test   %rdi,%rdi
 112222a:	je     112223a <sort.block.block__anon_39129+0x4efa>
 112222c:	mov    -0x60(%rbp),%rdi
 1122230:	mov    %rdi,%rax
 1122233:	xor    %edx,%edx
 1122235:	div    %r15
 1122238:	jmp    1122245 <sort.block.block__anon_39129+0x4f05>
 112223a:	mov    -0x60(%rbp),%rdi
 112223e:	mov    %edi,%eax
 1122240:	xor    %edx,%edx
 1122242:	div    %r15d
 1122245:	add    -0x1f0(%rbp),%rcx
 112224c:	add    %rsi,%rcx
 112224f:	add    %rdx,%rcx
 1122252:	sub    %rdi,%rcx
 1122255:	sub    %r13,%rcx
 1122258:	cmp    $0x3,%rcx
 112225c:	mov    %r8,%rax
 112225f:	jae    1122268 <sort.block.block__anon_39129+0x4f28>
 1122261:	xor    %ecx,%ecx
 1122263:	jmp    1122331 <sort.block.block__anon_39129+0x4ff1>
 1122268:	mov    %rax,%rdx
 112226b:	and    $0xfffffffffffffffc,%rdx
 112226f:	mov    -0x80(%rbp),%rcx
 1122273:	lea    (%rcx,%r13,2),%rsi
 1122277:	xor    %ecx,%ecx
 1122279:	mov    -0x1d0(%rbp),%r11
 1122280:	movzbl -0x7(%rsi,%rcx,2),%edi
 1122285:	movzbl -0x7(%r11,%rcx,2),%r8d
 112228b:	mov    %r8b,-0x7(%rsi,%rcx,2)
 1122290:	mov    %dil,-0x7(%r11,%rcx,2)
 1122295:	movzbl -0x6(%rsi,%rcx,2),%edi
 112229a:	movzbl -0x6(%r11,%rcx,2),%r8d
 11222a0:	mov    %r8b,-0x6(%rsi,%rcx,2)
 11222a5:	mov    %dil,-0x6(%r11,%rcx,2)
 11222aa:	movzbl -0x5(%rsi,%rcx,2),%edi
 11222af:	movzbl -0x5(%r11,%rcx,2),%r8d
 11222b5:	mov    %r8b,-0x5(%rsi,%rcx,2)
 11222ba:	mov    %dil,-0x5(%r11,%rcx,2)
 11222bf:	movzbl -0x4(%rsi,%rcx,2),%edi
 11222c4:	movzbl -0x4(%r11,%rcx,2),%r8d
 11222ca:	mov    %r8b,-0x4(%rsi,%rcx,2)
 11222cf:	mov    %dil,-0x4(%r11,%rcx,2)
 11222d4:	movzbl -0x3(%rsi,%rcx,2),%edi
 11222d9:	movzbl -0x3(%r11,%rcx,2),%r8d
 11222df:	mov    %r8b,-0x3(%rsi,%rcx,2)
 11222e4:	mov    %dil,-0x3(%r11,%rcx,2)
 11222e9:	movzbl -0x2(%rsi,%rcx,2),%edi
 11222ee:	movzbl -0x2(%r11,%rcx,2),%r8d
 11222f4:	mov    %r8b,-0x2(%rsi,%rcx,2)
 11222f9:	mov    %dil,-0x2(%r11,%rcx,2)
 11222fe:	movzbl -0x1(%rsi,%rcx,2),%edi
 1122303:	movzbl -0x1(%r11,%rcx,2),%r8d
 1122309:	mov    %r8b,-0x1(%rsi,%rcx,2)
 112230e:	mov    %dil,-0x1(%r11,%rcx,2)
 1122313:	movzbl (%rsi,%rcx,2),%edi
 1122317:	movzbl (%r11,%rcx,2),%r8d
 112231c:	mov    %r8b,(%rsi,%rcx,2)
 1122320:	mov    %dil,(%r11,%rcx,2)
 1122324:	add    $0x4,%rcx
 1122328:	cmp    %rcx,%rdx
 112232b:	jne    1122280 <sort.block.block__anon_39129+0x4f40>
 1122331:	and    $0x3,%eax
 1122334:	je     112237e <sort.block.block__anon_39129+0x503e>
 1122336:	mov    -0x1a8(%rbp),%rdx
 112233d:	lea    (%rdx,%rcx,2),%rdx
 1122341:	add    %rcx,%rcx
 1122344:	lea    (%rcx,%r13,2),%rcx
 1122348:	add    -0x50(%rbp),%rcx
 112234c:	xor    %esi,%esi
 112234e:	xchg   %ax,%ax
 1122350:	movzbl -0x1(%rcx,%rsi,2),%edi
 1122355:	movzbl -0x1(%rdx,%rsi,2),%r8d
 112235b:	mov    %r8b,-0x1(%rcx,%rsi,2)
 1122360:	mov    %dil,-0x1(%rdx,%rsi,2)
 1122365:	movzbl (%rcx,%rsi,2),%edi
 1122369:	movzbl (%rdx,%rsi,2),%r8d
 112236e:	mov    %r8b,(%rcx,%rsi,2)
 1122372:	mov    %dil,(%rdx,%rsi,2)
 1122376:	inc    %rsi
 1122379:	cmp    %rsi,%rax
 112237c:	jne    1122350 <sort.block.block__anon_39129+0x5010>
 112237e:	mov    -0x78(%rbp),%rdx
 1122382:	cmp    %rdx,%r12
 1122385:	jne    1122563 <sort.block.block__anon_39129+0x5223>
 112238b:	mov    %r13,%rbx
 112238e:	mov    %r12,%r11
 1122391:	mov    -0xf0(%rbp),%r14
 1122398:	mov    -0x60(%rbp),%r12
 112239c:	cmp    $0x201,%r12
 11223a3:	mov    -0xa0(%rbp),%rax
 11223aa:	mov    -0xa8(%rbp),%rcx
 11223b1:	jb     1124ed9 <sort.block.block__anon_39129+0x7b99>
 11223b7:	cmp    %rcx,%rax
 11223ba:	jne    1124fbd <sort.block.block__anon_39129+0x7c7d>
 11223c0:	cmp    %r11,%r14
 11223c3:	jne    11223e3 <sort.block.block__anon_39129+0x50a3>
 11223c5:	jmp    1121f78 <sort.block.block__anon_39129+0x4c38>
 11223ca:	nopw   0x0(%rax,%rax,1)
 11223d0:	mov    %r14,%r11
 11223d3:	cmp    %rbx,%r14
 11223d6:	mov    -0xf0(%rbp),%r14
 11223dd:	je     1121f78 <sort.block.block__anon_39129+0x4c38>
 11223e3:	lea    (%r10,%rbx,2),%rdi
 11223e7:	mov    %r14,%rax
 11223ea:	sub    %r11,%rax
 11223ed:	jbe    112246b <sort.block.block__anon_39129+0x512b>
 11223f3:	movzwl (%rdi),%esi
 11223f6:	mov    -0x30(%rbp),%rcx
 11223fa:	mov    (%rcx),%rcx
 11223fd:	shl    $0x4,%esi
 1122400:	lea    (%rcx,%rsi,1),%rdx
 1122404:	mov    (%rcx,%rsi,1),%rsi
 1122408:	mov    %r11,%r14
 112240b:	jmp    112241f <sort.block.block__anon_39129+0x50df>
 112240d:	nopl   (%rax)
 1122410:	xor    %r8d,%r8d
 1122413:	add    %r8,%r14
 1122416:	cmp    $0x1,%rax
 112241a:	mov    %r9,%rax
 112241d:	jbe    112246b <sort.block.block__anon_39129+0x512b>
 112241f:	lea    (%r10,%r14,2),%r9
 1122423:	mov    %rax,%r8
 1122426:	and    $0xfffffffffffffffe,%r8
 112242a:	movzwl (%r8,%r9,1),%r8d
 112242f:	shl    $0x4,%r8d
 1122433:	cmp    %rsi,(%rcx,%r8,1)
 1122437:	jne    1122446 <sort.block.block__anon_39129+0x5106>
 1122439:	add    %rcx,%r8
 112243c:	movzwl 0xe(%r8),%r8d
 1122441:	cmp    0xe(%rdx),%r8w
 1122446:	setb   %r8b
 112244a:	mov    %rax,%r9
 112244d:	shr    %r9
 1122450:	test   %r8b,%r8b
 1122453:	je     1122410 <sort.block.block__anon_39129+0x50d0>
 1122455:	mov    %eax,%r8d
 1122458:	and    $0x1,%r8d
 112245c:	add    %r9,%r8
 112245f:	add    %r8,%r14
 1122462:	cmp    $0x1,%rax
 1122466:	mov    %r9,%rax
 1122469:	ja     112241f <sort.block.block__anon_39129+0x50df>
 112246b:	mov    %r14,%r12
 112246e:	sub    %rbx,%r12
 1122471:	mov    %r11,%r13
 1122474:	sub    %rbx,%r13
 1122477:	mov    %r13,%rsi
 112247a:	mov    %r11,%r15
 112247d:	mov    %rdi,-0x40(%rbp)
 1122481:	vzeroupper 
 1122484:	call   10fd040 <mem.reverse__anon_36385>
 1122489:	mov    -0x38(%rbp),%rax
 112248d:	lea    (%rax,%r15,2),%rdi
 1122491:	mov    %r12,%rsi
 1122494:	sub    %r13,%rsi
 1122497:	call   10fd040 <mem.reverse__anon_36385>
 112249c:	mov    -0x40(%rbp),%rdi
 11224a0:	mov    %r12,%rsi
 11224a3:	call   10fd040 <mem.reverse__anon_36385>
 11224a8:	mov    -0x38(%rbp),%r10
 11224ac:	cmp    %r14,-0xf0(%rbp)
 11224b3:	vmovdqa -0x11fc9b(%rip),%ymm2        # 1002820 <__anon_38908+0x60>
 11224bb:	je     1121f78 <sort.block.block__anon_39129+0x4c38>
 11224c1:	mov    %r14,%rdi
 11224c4:	sub    %r15,%rdi
 11224c7:	add    %rbx,%rdi
 11224ca:	mov    %r14,%rax
 11224cd:	mov    %r14,%rbx
 11224d0:	sub    %rdi,%rax
 11224d3:	jbe    11223d0 <sort.block.block__anon_39129+0x5090>
 11224d9:	movzwl (%r10,%rdi,2),%esi
 11224de:	mov    -0x30(%rbp),%rcx
 11224e2:	mov    (%rcx),%rcx
 11224e5:	shl    $0x4,%esi
 11224e8:	lea    (%rcx,%rsi,1),%rdx
 11224ec:	mov    (%rcx,%rsi,1),%rsi
 11224f0:	mov    %rdi,%rbx
 11224f3:	jmp    112251a <sort.block.block__anon_39129+0x51da>
 11224f5:	data16 cs nopw 0x0(%rax,%rax,1)
 1122500:	mov    %eax,%r8d
 1122503:	and    $0x1,%r8d
 1122507:	add    %rdi,%r8
 112250a:	add    %r8,%rbx
 112250d:	cmp    $0x1,%rax
 1122511:	mov    %rdi,%rax
 1122514:	jbe    11223d0 <sort.block.block__anon_39129+0x5090>
 112251a:	lea    (%r10,%rbx,2),%rdi
 112251e:	mov    %rax,%r8
 1122521:	and    $0xfffffffffffffffe,%r8
 1122525:	movzwl (%r8,%rdi,1),%edi
 112252a:	shl    $0x4,%edi
 112252d:	cmp    (%rcx,%rdi,1),%rsi
 1122531:	jne    1122540 <sort.block.block__anon_39129+0x5200>
 1122533:	add    %rcx,%rdi
 1122536:	movzwl 0xe(%rdx),%r8d
 112253b:	cmp    0xe(%rdi),%r8w
 1122540:	setb   %r8b
 1122544:	mov    %rax,%rdi
 1122547:	shr    %rdi
 112254a:	test   %r8b,%r8b
 112254d:	je     1122500 <sort.block.block__anon_39129+0x51c0>
 112254f:	xor    %r8d,%r8d
 1122552:	add    %r8,%rbx
 1122555:	cmp    $0x1,%rax
 1122559:	mov    %rdi,%rax
 112255c:	ja     112251a <sort.block.block__anon_39129+0x51da>
 112255e:	jmp    11223d0 <sort.block.block__anon_39129+0x5090>
 1122563:	add    %r12,%r14
 1122566:	mov    -0xf0(%rbp),%rax
 112256d:	sub    %r15,%rax
 1122570:	mov    %rax,-0x1f8(%rbp)
 1122577:	mov    -0xd0(%rbp),%rax
 112257e:	mov    %rax,-0xc0(%rbp)
 1122585:	mov    %rdx,%r11
 1122588:	xor    %ebx,%ebx
 112258a:	xor    %esi,%esi
 112258c:	mov    %r12,%rax
 112258f:	mov    %rbx,%rcx
 1122592:	mov    %rax,-0x108(%rbp)
 1122599:	lea    (%r10,%rax,2),%rax
 112259d:	mov    %rax,-0x70(%rbp)
 11225a1:	mov    %r14,-0xd8(%rbp)
 11225a8:	mov    %r13,%rbx
 11225ab:	jmp    11225d1 <sort.block.block__anon_39129+0x5291>
 11225ad:	nopl   (%rax)
 11225b0:	incq   -0xc0(%rbp)
 11225b7:	sub    %r13,%rbx
 11225ba:	lea    (%rbx,%r15,1),%r11
 11225be:	mov    %r11,%rcx
 11225c1:	mov    -0x78(%rbp),%rdx
 11225c5:	mov    %rdx,%rsi
 11225c8:	cmp    %rdx,%r12
 11225cb:	je     1124eb4 <sort.block.block__anon_39129+0x7b74>
 11225d1:	mov    %rbx,%r13
 11225d4:	mov    %rdx,%rbx
 11225d7:	mov    %rsi,%rax
 11225da:	sub    %rcx,%rax
 11225dd:	mov    %rdx,-0x40(%rbp)
 11225e1:	mov    %rsi,-0xe0(%rbp)
 11225e8:	mov    %r12,-0xe8(%rbp)
 11225ef:	je     11226b0 <sort.block.block__anon_39129+0x5370>
 11225f5:	movzwl -0x2(%r10,%rsi,2),%edx
 11225fb:	mov    -0xc0(%rbp),%rsi
 1122602:	movzwl (%r10,%rsi,2),%esi
 1122607:	mov    -0x30(%rbp),%rdi
 112260b:	mov    (%rdi),%rdi
 112260e:	shl    $0x4,%edx
 1122611:	shl    $0x4,%esi
 1122614:	mov    (%rdi,%rsi,1),%r8
 1122618:	cmp    %r8,(%rdi,%rdx,1)
 112261c:	jne    112262c <sort.block.block__anon_39129+0x52ec>
 112261e:	add    %rdi,%rdx
 1122621:	add    %rdi,%rsi
 1122624:	movzwl 0xe(%rdx),%edx
 1122628:	cmp    0xe(%rsi),%dx
 112262c:	mov    -0x110(%rbp),%r9
 1122633:	mov    -0xe0(%rbp),%rsi
 112263a:	jae    11226c7 <sort.block.block__anon_39129+0x5387>
 1122640:	mov    -0xd8(%rbp),%rdx
 1122647:	cmp    -0x108(%rbp),%rdx
 112264e:	je     11226c7 <sort.block.block__anon_39129+0x5387>
 1122650:	mov    -0xd8(%rbp),%rcx
 1122657:	mov    -0x108(%rbp),%rsi
 112265e:	sub    %rsi,%rcx
 1122661:	lea    (%r10,%rbx,2),%rax
 1122665:	mov    -0x100(%rbp),%rdx
 112266c:	cmp    %rdx,%rcx
 112266f:	mov    %r11,-0x90(%rbp)
 1122676:	ja     1124d58 <sort.block.block__anon_39129+0x7a18>
 112267c:	mov    %rcx,-0x60(%rbp)
 1122680:	sub    %rbx,%rsi
 1122683:	mov    %rsi,%rdx
 1122686:	shr    %rdx
 1122689:	cmp    $0x20,%rsi
 112268d:	setb   %dil
 1122691:	cmp    $0xf,%rdx
 1122695:	sete   %r8b
 1122699:	or     %dil,%r8b
 112269c:	mov    -0x70(%rbp),%r14
 11226a0:	je     112439c <sort.block.block__anon_39129+0x705c>
 11226a6:	xor    %edi,%edi
 11226a8:	jmp    1124539 <sort.block.block__anon_39129+0x71f9>
 11226ad:	nopl   (%rax)
 11226b0:	mov    -0xd8(%rbp),%rdx
 11226b7:	cmp    -0x108(%rbp),%rdx
 11226be:	mov    -0x110(%rbp),%r9
 11226c5:	jne    1122650 <sort.block.block__anon_39129+0x5310>
 11226c7:	cmp    %rsi,%rcx
 11226ca:	mov    %rsi,%r14
 11226cd:	cmovb  %rcx,%r14
 11226d1:	jae    1122758 <sort.block.block__anon_39129+0x5418>
 11226d7:	mov    -0xc0(%rbp),%rdx
 11226de:	movzwl (%r10,%rdx,2),%edi
 11226e3:	mov    -0x30(%rbp),%rdx
 11226e7:	mov    (%rdx),%rdx
 11226ea:	shl    $0x4,%edi
 11226ed:	lea    (%rdx,%rdi,1),%rsi
 11226f1:	mov    (%rdx,%rdi,1),%rdi
 11226f5:	mov    %rcx,%r14
 11226f8:	jmp    112270f <sort.block.block__anon_39129+0x53cf>
 11226fa:	nopw   0x0(%rax,%rax,1)
 1122700:	xor    %r8d,%r8d
 1122703:	add    %r8,%r14
 1122706:	cmp    $0x1,%rax
 112270a:	mov    %rcx,%rax
 112270d:	jbe    1122758 <sort.block.block__anon_39129+0x5418>
 112270f:	lea    (%r10,%r14,2),%rcx
 1122713:	mov    %rax,%r8
 1122716:	and    $0xfffffffffffffffe,%r8
 112271a:	movzwl (%r8,%rcx,1),%ecx
 112271f:	shl    $0x4,%ecx
 1122722:	cmp    %rdi,(%rdx,%rcx,1)
 1122726:	jne    1122733 <sort.block.block__anon_39129+0x53f3>
 1122728:	add    %rdx,%rcx
 112272b:	movzwl 0xe(%rcx),%ecx
 112272f:	cmp    0xe(%rsi),%cx
 1122733:	setb   %r8b
 1122737:	mov    %rax,%rcx
 112273a:	shr    %rcx
 112273d:	test   %r8b,%r8b
 1122740:	je     1122700 <sort.block.block__anon_39129+0x53c0>
 1122742:	mov    %eax,%r8d
 1122745:	and    $0x1,%r8d
 1122749:	add    %rcx,%r8
 112274c:	add    %r8,%r14
 112274f:	cmp    $0x1,%rax
 1122753:	mov    %rcx,%rax
 1122756:	ja     112270f <sort.block.block__anon_39129+0x53cf>
 1122758:	lea    (%rbx,%r15,1),%rdx
 112275c:	mov    %rbx,%rax
 112275f:	mov    %rdx,-0x78(%rbp)
 1122763:	cmp    %r12,%rdx
 1122766:	jae    11227f0 <sort.block.block__anon_39129+0x54b0>
 112276c:	mov    -0x30(%rbp),%rax
 1122770:	mov    (%rax),%rcx
 1122773:	mov    %rbx,%rsi
 1122776:	mov    -0x78(%rbp),%rdx
 112277a:	jmp    112278b <sort.block.block__anon_39129+0x544b>
 112277c:	nopl   0x0(%rax)
 1122780:	add    %r15,%rdx
 1122783:	mov    %rax,%rsi
 1122786:	cmp    %r12,%rdx
 1122789:	jae    11227f0 <sort.block.block__anon_39129+0x54b0>
 112278b:	movzwl (%r10,%rdx,2),%eax
 1122790:	movzwl (%r10,%rsi,2),%edi
 1122795:	shl    $0x4,%eax
 1122798:	shl    $0x4,%edi
 112279b:	mov    (%rcx,%rdi,1),%r8
 112279f:	cmp    %r8,(%rcx,%rax,1)
 11227a3:	jne    11227d0 <sort.block.block__anon_39129+0x5490>
 11227a5:	add    %rcx,%rax
 11227a8:	add    %rcx,%rdi
 11227ab:	movzwl 0xe(%rax),%eax
 11227af:	cmp    0xe(%rdi),%ax
 11227b3:	setb   %dil
 11227b7:	mov    %rdx,%rax
 11227ba:	test   %dil,%dil
 11227bd:	jne    1122780 <sort.block.block__anon_39129+0x5440>
 11227bf:	jmp    11227dc <sort.block.block__anon_39129+0x549c>
 11227c1:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11227d0:	setb   %dil
 11227d4:	mov    %rdx,%rax
 11227d7:	test   %dil,%dil
 11227da:	jne    1122780 <sort.block.block__anon_39129+0x5440>
 11227dc:	mov    %rsi,%rax
 11227df:	jmp    1122780 <sort.block.block__anon_39129+0x5440>
 11227e1:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11227f0:	lea    (%r10,%rbx,2),%r12
 11227f4:	cmpq   $0x3,-0x100(%rbp)
 11227fc:	mov    -0xb0(%rbp),%r8
 1122803:	jae    1122810 <sort.block.block__anon_39129+0x54d0>
 1122805:	xor    %ecx,%ecx
 1122807:	jmp    11228d1 <sort.block.block__anon_39129+0x5591>
 112280c:	nopl   0x0(%rax)
 1122810:	mov    -0x80(%rbp),%rcx
 1122814:	lea    (%rcx,%rax,2),%rdx
 1122818:	xor    %ecx,%ecx
 112281a:	nopw   0x0(%rax,%rax,1)
 1122820:	movzbl (%r12,%rcx,2),%esi
 1122825:	movzbl -0x7(%rdx,%rcx,2),%edi
 112282a:	mov    %dil,(%r12,%rcx,2)
 112282e:	mov    %sil,-0x7(%rdx,%rcx,2)
 1122833:	movzbl 0x1(%r12,%rcx,2),%esi
 1122839:	movzbl -0x6(%rdx,%rcx,2),%edi
 112283e:	mov    %dil,0x1(%r12,%rcx,2)
 1122843:	mov    %sil,-0x6(%rdx,%rcx,2)
 1122848:	movzbl 0x2(%r12,%rcx,2),%esi
 112284e:	movzbl -0x5(%rdx,%rcx,2),%edi
 1122853:	mov    %dil,0x2(%r12,%rcx,2)
 1122858:	mov    %sil,-0x5(%rdx,%rcx,2)
 112285d:	movzbl 0x3(%r12,%rcx,2),%esi
 1122863:	movzbl -0x4(%rdx,%rcx,2),%edi
 1122868:	mov    %dil,0x3(%r12,%rcx,2)
 112286d:	mov    %sil,-0x4(%rdx,%rcx,2)
 1122872:	movzbl 0x4(%r12,%rcx,2),%esi
 1122878:	movzbl -0x3(%rdx,%rcx,2),%edi
 112287d:	mov    %dil,0x4(%r12,%rcx,2)
 1122882:	mov    %sil,-0x3(%rdx,%rcx,2)
 1122887:	movzbl 0x5(%r12,%rcx,2),%esi
 112288d:	movzbl -0x2(%rdx,%rcx,2),%edi
 1122892:	mov    %dil,0x5(%r12,%rcx,2)
 1122897:	mov    %sil,-0x2(%rdx,%rcx,2)
 112289c:	movzbl 0x6(%r12,%rcx,2),%esi
 11228a2:	movzbl -0x1(%rdx,%rcx,2),%edi
 11228a7:	mov    %dil,0x6(%r12,%rcx,2)
 11228ac:	mov    %sil,-0x1(%rdx,%rcx,2)
 11228b1:	movzbl 0x7(%r12,%rcx,2),%esi
 11228b7:	movzbl (%rdx,%rcx,2),%edi
 11228bb:	mov    %dil,0x7(%r12,%rcx,2)
 11228c0:	mov    %sil,(%rdx,%rcx,2)
 11228c4:	add    $0x4,%rcx
 11228c8:	cmp    %rcx,%r9
 11228cb:	jne    1122820 <sort.block.block__anon_39129+0x54e0>
 11228d1:	test   %r8,%r8
 11228d4:	je     1122921 <sort.block.block__anon_39129+0x55e1>
 11228d6:	add    %rax,%rax
 11228d9:	lea    (%rax,%rcx,2),%rax
 11228dd:	add    -0x50(%rbp),%rax
 11228e1:	xor    %edx,%edx
 11228e3:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11228f0:	movzbl (%r12,%rcx,2),%esi
 11228f5:	movzbl -0x1(%rax,%rdx,2),%edi
 11228fa:	mov    %dil,(%r12,%rcx,2)
 11228fe:	mov    %sil,-0x1(%rax,%rdx,2)
 1122903:	movzbl 0x1(%r12,%rcx,2),%esi
 1122909:	movzbl (%rax,%rdx,2),%edi
 112290d:	mov    %dil,0x1(%r12,%rcx,2)
 1122912:	mov    %sil,(%rax,%rdx,2)
 1122916:	inc    %rcx
 1122919:	inc    %rdx
 112291c:	cmp    %rdx,%r8
 112291f:	jne    11228f0 <sort.block.block__anon_39129+0x55b0>
 1122921:	movzbl (%r12),%eax
 1122926:	mov    -0xc0(%rbp),%rdx
 112292d:	movzbl (%r10,%rdx,2),%ecx
 1122932:	mov    %cl,(%r12)
 1122936:	mov    %al,(%r10,%rdx,2)
 112293a:	movzbl 0x1(%r12),%eax
 1122940:	movzbl 0x1(%r10,%rdx,2),%ecx
 1122946:	mov    %cl,0x1(%r12)
 112294b:	mov    %al,0x1(%r10,%rdx,2)
 1122950:	mov    %r11,%rdx
 1122953:	sub    %r13,%rdx
 1122956:	cmp    $0x201,%rdx
 112295d:	jae    1122a60 <sort.block.block__anon_39129+0x5720>
 1122963:	cmp    %r11,%r14
 1122966:	je     1123570 <sort.block.block__anon_39129+0x6230>
 112296c:	cmp    %r13,%r11
 112296f:	je     1123570 <sort.block.block__anon_39129+0x6230>
 1122975:	mov    %r14,%rcx
 1122978:	neg    %rcx
 112297b:	xor    %eax,%eax
 112297d:	mov    %rdx,-0x128(%rbp)
 1122984:	mov    %rcx,-0x60(%rbp)
 1122988:	mov    %r13,%rsi
 112298b:	movzwl -0x650(%rbp,%rax,2),%r8d
 1122994:	movzwl %r8w,%r9d
 1122998:	lea    (%rcx,%r11,1),%r10
 112299c:	mov    -0x38(%rbp),%rcx
 11229a0:	mov    %r11,-0x90(%rbp)
 11229a7:	lea    (%rcx,%r11,2),%rbx
 11229ab:	lea    (%rcx,%r13,2),%r11
 11229af:	shl    $0x4,%r9d
 11229b3:	xor    %edi,%edi
 11229b5:	data16 cs nopw 0x0(%rax,%rax,1)
 11229c0:	movzwl (%rbx,%rdi,2),%r13d
 11229c5:	mov    -0x30(%rbp),%rcx
 11229c9:	mov    (%rcx),%r15
 11229cc:	mov    %r13d,%edx
 11229cf:	shl    $0x4,%edx
 11229d2:	mov    (%r15,%r9,1),%rcx
 11229d6:	cmp    %rcx,(%r15,%rdx,1)
 11229da:	jne    11229eb <sort.block.block__anon_39129+0x56ab>
 11229dc:	add    %r15,%rdx
 11229df:	add    %r9,%r15
 11229e2:	movzwl 0xe(%rdx),%ecx
 11229e6:	cmp    0xe(%r15),%cx
 11229eb:	jae    1122a10 <sort.block.block__anon_39129+0x56d0>
 11229ed:	mov    %r13w,(%r11,%rdi,2)
 11229f2:	inc    %rdi
 11229f5:	mov    %r10,%rcx
 11229f8:	add    %rdi,%rcx
 11229fb:	jne    11229c0 <sort.block.block__anon_39129+0x5680>
 11229fd:	jmp    11235b0 <sort.block.block__anon_39129+0x6270>
 1122a02:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1122a10:	mov    %r8w,(%r11,%rdi,2)
 1122a15:	inc    %rax
 1122a18:	lea    (%rsi,%rdi,1),%r13
 1122a1c:	inc    %r13
 1122a1f:	mov    -0x90(%rbp),%r11
 1122a26:	add    %rdi,%r11
 1122a29:	mov    -0x128(%rbp),%rdx
 1122a30:	cmp    %rdx,%rax
 1122a33:	mov    -0x60(%rbp),%rcx
 1122a37:	jne    1122988 <sort.block.block__anon_39129+0x5648>
 1122a3d:	lea    (%rsi,%rdi,1),%r13
 1122a41:	inc    %r13
 1122a44:	mov    %rdx,%rax
 1122a47:	mov    -0x38(%rbp),%r10
 1122a4b:	mov    -0x88(%rbp),%r15
 1122a52:	mov    -0x40(%rbp),%rbx
 1122a56:	jmp    11235cc <sort.block.block__anon_39129+0x628c>
 1122a5b:	nopl   0x0(%rax,%rax,1)
 1122a60:	mov    -0xa8(%rbp),%rax
 1122a67:	cmp    %rax,-0xa0(%rbp)
 1122a6e:	jne    1123580 <sort.block.block__anon_39129+0x6240>
 1122a74:	cmp    %r11,%r14
 1122a77:	jne    1122a8c <sort.block.block__anon_39129+0x574c>
 1122a79:	jmp    11235f5 <sort.block.block__anon_39129+0x62b5>
 1122a7e:	xchg   %ax,%ax
 1122a80:	mov    %rax,%r11
 1122a83:	cmp    %r13,%rax
 1122a86:	je     11235f5 <sort.block.block__anon_39129+0x62b5>
 1122a8c:	mov    %r14,%rcx
 1122a8f:	mov    %r14,%rax
 1122a92:	sub    %r11,%rcx
 1122a95:	jbe    1122b1b <sort.block.block__anon_39129+0x57db>
 1122a9b:	movzwl (%r10,%r13,2),%eax
 1122aa0:	mov    -0x30(%rbp),%rdx
 1122aa4:	mov    (%rdx),%rdx
 1122aa7:	shl    $0x4,%eax
 1122aaa:	lea    (%rdx,%rax,1),%rsi
 1122aae:	mov    (%rdx,%rax,1),%rdi
 1122ab2:	mov    %r11,%rax
 1122ab5:	jmp    1122acf <sort.block.block__anon_39129+0x578f>
 1122ab7:	nopw   0x0(%rax,%rax,1)
 1122ac0:	xor    %r9d,%r9d
 1122ac3:	add    %r9,%rax
 1122ac6:	cmp    $0x1,%rcx
 1122aca:	mov    %r8,%rcx
 1122acd:	jbe    1122b1b <sort.block.block__anon_39129+0x57db>
 1122acf:	lea    (%r10,%rax,2),%r8
 1122ad3:	mov    %rcx,%r9
 1122ad6:	and    $0xfffffffffffffffe,%r9
 1122ada:	movzwl (%r9,%r8,1),%r8d
 1122adf:	shl    $0x4,%r8d
 1122ae3:	cmp    %rdi,(%rdx,%r8,1)
 1122ae7:	jne    1122af6 <sort.block.block__anon_39129+0x57b6>
 1122ae9:	add    %rdx,%r8
 1122aec:	movzwl 0xe(%r8),%r8d
 1122af1:	cmp    0xe(%rsi),%r8w
 1122af6:	setb   %r9b
 1122afa:	mov    %rcx,%r8
 1122afd:	shr    %r8
 1122b00:	test   %r9b,%r9b
 1122b03:	je     1122ac0 <sort.block.block__anon_39129+0x5780>
 1122b05:	mov    %ecx,%r9d
 1122b08:	and    $0x1,%r9d
 1122b0c:	add    %r8,%r9
 1122b0f:	add    %r9,%rax
 1122b12:	cmp    $0x1,%rcx
 1122b16:	mov    %r8,%rcx
 1122b19:	ja     1122acf <sort.block.block__anon_39129+0x578f>
 1122b1b:	mov    %r11,%rdx
 1122b1e:	sub    %r13,%rdx
 1122b21:	mov    %rdx,%rcx
 1122b24:	shr    %rcx
 1122b27:	cmp    $0x20,%rdx
 1122b2b:	setb   %sil
 1122b2f:	cmp    $0xf,%rcx
 1122b33:	sete   %dil
 1122b37:	or     %sil,%dil
 1122b3a:	je     1122b50 <sort.block.block__anon_39129+0x5810>
 1122b3c:	xor    %esi,%esi
 1122b3e:	jmp    1122cf1 <sort.block.block__anon_39129+0x59b1>
 1122b43:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1122b50:	lea    -0x10(%rcx),%rsi
 1122b54:	mov    %rsi,%rdi
 1122b57:	shr    $0x4,%rdi
 1122b5b:	inc    %rdi
 1122b5e:	cmp    $0x30,%rsi
 1122b62:	jae    1122b80 <sort.block.block__anon_39129+0x5840>
 1122b64:	xor    %esi,%esi
 1122b66:	and    $0x3,%edi
 1122b69:	jne    1122c86 <sort.block.block__anon_39129+0x5946>
 1122b6f:	jmp    1122cf1 <sort.block.block__anon_39129+0x59b1>
 1122b74:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1122b80:	mov    %rdi,%r8
 1122b83:	movabs $0x1ffffffffffffffc,%rsi
 1122b8d:	and    %rsi,%r8
 1122b90:	mov    -0xc8(%rbp),%rsi
 1122b97:	lea    (%rsi,%r13,2),%r9
 1122b9b:	mov    -0x58(%rbp),%rsi
 1122b9f:	lea    (%rsi,%r11,2),%r10
 1122ba3:	xor    %esi,%esi
 1122ba5:	data16 cs nopw 0x0(%rax,%rax,1)
 1122bb0:	vmovdqu (%r10,%rsi,2),%ymm0
 1122bb6:	vmovdqu -0x60(%r9),%ymm1
 1122bbc:	vpshufb %ymm2,%ymm1,%ymm1
 1122bc1:	vpermq $0x4e,%ymm1,%ymm1
 1122bc7:	vmovdqu %ymm1,(%r10,%rsi,2)
 1122bcd:	vpshufb %ymm2,%ymm0,%ymm0
 1122bd2:	vpermq $0x4e,%ymm0,%ymm0
 1122bd8:	vmovdqu %ymm0,-0x60(%r9)
 1122bde:	vmovdqu -0x20(%r10,%rsi,2),%ymm0
 1122be5:	vmovdqu -0x40(%r9),%ymm1
 1122beb:	vpshufb %ymm2,%ymm1,%ymm1
 1122bf0:	vpermq $0x4e,%ymm1,%ymm1
 1122bf6:	vmovdqu %ymm1,-0x20(%r10,%rsi,2)
 1122bfd:	vpshufb %ymm2,%ymm0,%ymm0
 1122c02:	vpermq $0x4e,%ymm0,%ymm0
 1122c08:	vmovdqu %ymm0,-0x40(%r9)
 1122c0e:	vmovdqu -0x40(%r10,%rsi,2),%ymm0
 1122c15:	vmovdqu -0x20(%r9),%ymm1
 1122c1b:	vpshufb %ymm2,%ymm1,%ymm1
 1122c20:	vpermq $0x4e,%ymm1,%ymm1
 1122c26:	vmovdqu %ymm1,-0x40(%r10,%rsi,2)
 1122c2d:	vpshufb %ymm2,%ymm0,%ymm0
 1122c32:	vpermq $0x4e,%ymm0,%ymm0
 1122c38:	vmovdqu %ymm0,-0x20(%r9)
 1122c3e:	vmovdqu -0x60(%r10,%rsi,2),%ymm0
 1122c45:	vmovdqu (%r9),%ymm1
 1122c4a:	vpshufb %ymm2,%ymm1,%ymm1
 1122c4f:	vpermq $0x4e,%ymm1,%ymm1
 1122c55:	vmovdqu %ymm1,-0x60(%r10,%rsi,2)
 1122c5c:	vpshufb %ymm2,%ymm0,%ymm0
 1122c61:	vpermq $0x4e,%ymm0,%ymm0
 1122c67:	vmovdqu %ymm0,(%r9)
 1122c6c:	sub    $0xffffffffffffff80,%r9
 1122c70:	add    $0xffffffffffffffc0,%rsi
 1122c74:	add    $0xfffffffffffffffc,%r8
 1122c78:	jne    1122bb0 <sort.block.block__anon_39129+0x5870>
 1122c7e:	neg    %rsi
 1122c81:	and    $0x3,%edi
 1122c84:	je     1122cf1 <sort.block.block__anon_39129+0x59b1>
 1122c86:	mov    -0x58(%rbp),%r8
 1122c8a:	lea    (%r8,%r11,2),%r9
 1122c8e:	mov    %rsi,%r8
 1122c91:	neg    %r8
 1122c94:	add    %rsi,%rsi
 1122c97:	lea    (%rsi,%r13,2),%rsi
 1122c9b:	add    -0x38(%rbp),%rsi
 1122c9f:	shl    $0x5,%edi
 1122ca2:	xor    %r10d,%r10d
 1122ca5:	data16 cs nopw 0x0(%rax,%rax,1)
 1122cb0:	vmovdqu (%r9,%r8,2),%ymm0
 1122cb6:	vmovdqu (%rsi,%r10,1),%ymm1
 1122cbc:	vpshufb %ymm2,%ymm1,%ymm1
 1122cc1:	vpermq $0x4e,%ymm1,%ymm1
 1122cc7:	vmovdqu %ymm1,(%r9,%r8,2)
 1122ccd:	vpshufb %ymm2,%ymm0,%ymm0
 1122cd2:	vpermq $0x4e,%ymm0,%ymm0
 1122cd8:	vmovdqu %ymm0,(%rsi,%r10,1)
 1122cde:	add    $0xfffffffffffffff0,%r8
 1122ce2:	add    $0x20,%r10
 1122ce6:	cmp    %r10,%rdi
 1122ce9:	jne    1122cb0 <sort.block.block__anon_39129+0x5970>
 1122ceb:	neg    %r8
 1122cee:	mov    %r8,%rsi
 1122cf1:	mov    %rsi,%rdi
 1122cf4:	sub    %rcx,%rdi
 1122cf7:	jae    1122e5d <sort.block.block__anon_39129+0x5b1d>
 1122cfd:	mov    %ecx,%r8d
 1122d00:	sub    %esi,%r8d
 1122d03:	and    $0x3,%r8d
 1122d07:	je     1122d85 <sort.block.block__anon_39129+0x5a45>
 1122d09:	mov    -0x48(%rbp),%r9
 1122d0d:	mov    %r11,-0x90(%rbp)
 1122d14:	lea    (%r9,%r11,2),%r9
 1122d18:	sub    %rsi,%r9
 1122d1b:	sub    %rsi,%r9
 1122d1e:	lea    0x0(,%r13,2),%r10
 1122d26:	lea    (%r10,%rsi,2),%r10
 1122d2a:	add    -0x50(%rbp),%r10
 1122d2e:	neg    %r8
 1122d31:	xor    %r11d,%r11d
 1122d34:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1122d40:	movzbl -0x1(%r10),%ebx
 1122d45:	movzbl -0x1(%r9,%r11,2),%r15d
 1122d4b:	mov    %r15b,-0x1(%r10)
 1122d4f:	mov    %bl,-0x1(%r9,%r11,2)
 1122d54:	movzbl (%r10),%ebx
 1122d58:	movzbl (%r9,%r11,2),%r15d
 1122d5d:	mov    %r15b,(%r10)
 1122d60:	mov    %bl,(%r9,%r11,2)
 1122d64:	dec    %r11
 1122d67:	add    $0x2,%r10
 1122d6b:	cmp    %r11,%r8
 1122d6e:	jne    1122d40 <sort.block.block__anon_39129+0x5a00>
 1122d70:	sub    %r11,%rsi
 1122d73:	mov    -0x88(%rbp),%r15
 1122d7a:	mov    -0x40(%rbp),%rbx
 1122d7e:	mov    -0x90(%rbp),%r11
 1122d85:	cmp    $0xfffffffffffffffc,%rdi
 1122d89:	ja     1122e5d <sort.block.block__anon_39129+0x5b1d>
 1122d8f:	mov    -0x80(%rbp),%rdi
 1122d93:	lea    (%rdi,%r13,2),%rdi
 1122d97:	mov    -0x48(%rbp),%r8
 1122d9b:	lea    (%r8,%r11,2),%r8
 1122d9f:	sub    %rsi,%r8
 1122da2:	sub    %rsi,%r8
 1122da5:	data16 cs nopw 0x0(%rax,%rax,1)
 1122db0:	movzbl -0x7(%rdi,%rsi,2),%r9d
 1122db6:	movzbl -0x1(%r8),%r10d
 1122dbb:	mov    %r10b,-0x7(%rdi,%rsi,2)
 1122dc0:	mov    %r9b,-0x1(%r8)
 1122dc4:	movzbl -0x6(%rdi,%rsi,2),%r9d
 1122dca:	movzbl (%r8),%r10d
 1122dce:	mov    %r10b,-0x6(%rdi,%rsi,2)
 1122dd3:	mov    %r9b,(%r8)
 1122dd6:	movzbl -0x5(%rdi,%rsi,2),%r9d
 1122ddc:	movzbl -0x3(%r8),%r10d
 1122de1:	mov    %r10b,-0x5(%rdi,%rsi,2)
 1122de6:	mov    %r9b,-0x3(%r8)
 1122dea:	movzbl -0x4(%rdi,%rsi,2),%r9d
 1122df0:	movzbl -0x2(%r8),%r10d
 1122df5:	mov    %r10b,-0x4(%rdi,%rsi,2)
 1122dfa:	mov    %r9b,-0x2(%r8)
 1122dfe:	movzbl -0x3(%rdi,%rsi,2),%r9d
 1122e04:	movzbl -0x5(%r8),%r10d
 1122e09:	mov    %r10b,-0x3(%rdi,%rsi,2)
 1122e0e:	mov    %r9b,-0x5(%r8)
 1122e12:	movzbl -0x2(%rdi,%rsi,2),%r9d
 1122e18:	movzbl -0x4(%r8),%r10d
 1122e1d:	mov    %r10b,-0x2(%rdi,%rsi,2)
 1122e22:	mov    %r9b,-0x4(%r8)
 1122e26:	movzbl -0x1(%rdi,%rsi,2),%r9d
 1122e2c:	movzbl -0x7(%r8),%r10d
 1122e31:	mov    %r10b,-0x1(%rdi,%rsi,2)
 1122e36:	mov    %r9b,-0x7(%r8)
 1122e3a:	movzbl (%rdi,%rsi,2),%r9d
 1122e3f:	movzbl -0x6(%r8),%r10d
 1122e44:	mov    %r10b,(%rdi,%rsi,2)
 1122e48:	mov    %r9b,-0x6(%r8)
 1122e4c:	add    $0x4,%rsi
 1122e50:	add    $0xfffffffffffffff8,%r8
 1122e54:	cmp    %rsi,%rcx
 1122e57:	jne    1122db0 <sort.block.block__anon_39129+0x5a70>
 1122e5d:	mov    %rax,%rcx
 1122e60:	sub    %r13,%rcx
 1122e63:	mov    %rcx,%rsi
 1122e66:	sub    %rdx,%rsi
 1122e69:	mov    %rsi,%rdx
 1122e6c:	shr    %rdx
 1122e6f:	cmp    $0x20,%rsi
 1122e73:	setb   %sil
 1122e77:	cmp    $0xf,%rdx
 1122e7b:	sete   %dil
 1122e7f:	or     %sil,%dil
 1122e82:	je     1122e90 <sort.block.block__anon_39129+0x5b50>
 1122e84:	xor    %esi,%esi
 1122e86:	jmp    1123031 <sort.block.block__anon_39129+0x5cf1>
 1122e8b:	nopl   0x0(%rax,%rax,1)
 1122e90:	lea    -0x10(%rdx),%rsi
 1122e94:	mov    %rsi,%rdi
 1122e97:	shr    $0x4,%rdi
 1122e9b:	inc    %rdi
 1122e9e:	cmp    $0x30,%rsi
 1122ea2:	jae    1122ec0 <sort.block.block__anon_39129+0x5b80>
 1122ea4:	xor    %esi,%esi
 1122ea6:	and    $0x3,%edi
 1122ea9:	jne    1122fc6 <sort.block.block__anon_39129+0x5c86>
 1122eaf:	jmp    1123031 <sort.block.block__anon_39129+0x5cf1>
 1122eb4:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1122ec0:	mov    %rdi,%r8
 1122ec3:	movabs $0x1ffffffffffffffc,%rsi
 1122ecd:	and    %rsi,%r8
 1122ed0:	mov    -0xc8(%rbp),%rsi
 1122ed7:	lea    (%rsi,%r11,2),%r9
 1122edb:	mov    -0x58(%rbp),%rsi
 1122edf:	lea    (%rsi,%rax,2),%r10
 1122ee3:	xor    %esi,%esi
 1122ee5:	data16 cs nopw 0x0(%rax,%rax,1)
 1122ef0:	vmovdqu (%r10,%rsi,2),%ymm0
 1122ef6:	vmovdqu -0x60(%r9),%ymm1
 1122efc:	vpshufb %ymm2,%ymm1,%ymm1
 1122f01:	vpermq $0x4e,%ymm1,%ymm1
 1122f07:	vmovdqu %ymm1,(%r10,%rsi,2)
 1122f0d:	vpshufb %ymm2,%ymm0,%ymm0
 1122f12:	vpermq $0x4e,%ymm0,%ymm0
 1122f18:	vmovdqu %ymm0,-0x60(%r9)
 1122f1e:	vmovdqu -0x20(%r10,%rsi,2),%ymm0
 1122f25:	vmovdqu -0x40(%r9),%ymm1
 1122f2b:	vpshufb %ymm2,%ymm1,%ymm1
 1122f30:	vpermq $0x4e,%ymm1,%ymm1
 1122f36:	vmovdqu %ymm1,-0x20(%r10,%rsi,2)
 1122f3d:	vpshufb %ymm2,%ymm0,%ymm0
 1122f42:	vpermq $0x4e,%ymm0,%ymm0
 1122f48:	vmovdqu %ymm0,-0x40(%r9)
 1122f4e:	vmovdqu -0x40(%r10,%rsi,2),%ymm0
 1122f55:	vmovdqu -0x20(%r9),%ymm1
 1122f5b:	vpshufb %ymm2,%ymm1,%ymm1
 1122f60:	vpermq $0x4e,%ymm1,%ymm1
 1122f66:	vmovdqu %ymm1,-0x40(%r10,%rsi,2)
 1122f6d:	vpshufb %ymm2,%ymm0,%ymm0
 1122f72:	vpermq $0x4e,%ymm0,%ymm0
 1122f78:	vmovdqu %ymm0,-0x20(%r9)
 1122f7e:	vmovdqu -0x60(%r10,%rsi,2),%ymm0
 1122f85:	vmovdqu (%r9),%ymm1
 1122f8a:	vpshufb %ymm2,%ymm1,%ymm1
 1122f8f:	vpermq $0x4e,%ymm1,%ymm1
 1122f95:	vmovdqu %ymm1,-0x60(%r10,%rsi,2)
 1122f9c:	vpshufb %ymm2,%ymm0,%ymm0
 1122fa1:	vpermq $0x4e,%ymm0,%ymm0
 1122fa7:	vmovdqu %ymm0,(%r9)
 1122fac:	sub    $0xffffffffffffff80,%r9
 1122fb0:	add    $0xffffffffffffffc0,%rsi
 1122fb4:	add    $0xfffffffffffffffc,%r8
 1122fb8:	jne    1122ef0 <sort.block.block__anon_39129+0x5bb0>
 1122fbe:	neg    %rsi
 1122fc1:	and    $0x3,%edi
 1122fc4:	je     1123031 <sort.block.block__anon_39129+0x5cf1>
 1122fc6:	mov    -0x58(%rbp),%r8
 1122fca:	lea    (%r8,%rax,2),%r9
 1122fce:	mov    %rsi,%r8
 1122fd1:	neg    %r8
 1122fd4:	add    %rsi,%rsi
 1122fd7:	lea    (%rsi,%r11,2),%rsi
 1122fdb:	add    -0x38(%rbp),%rsi
 1122fdf:	shl    $0x5,%edi
 1122fe2:	xor    %r10d,%r10d
 1122fe5:	data16 cs nopw 0x0(%rax,%rax,1)
 1122ff0:	vmovdqu (%r9,%r8,2),%ymm0
 1122ff6:	vmovdqu (%rsi,%r10,1),%ymm1
 1122ffc:	vpshufb %ymm2,%ymm1,%ymm1
 1123001:	vpermq $0x4e,%ymm1,%ymm1
 1123007:	vmovdqu %ymm1,(%r9,%r8,2)
 112300d:	vpshufb %ymm2,%ymm0,%ymm0
 1123012:	vpermq $0x4e,%ymm0,%ymm0
 1123018:	vmovdqu %ymm0,(%rsi,%r10,1)
 112301e:	add    $0xfffffffffffffff0,%r8
 1123022:	add    $0x20,%r10
 1123026:	cmp    %r10,%rdi
 1123029:	jne    1122ff0 <sort.block.block__anon_39129+0x5cb0>
 112302b:	neg    %r8
 112302e:	mov    %r8,%rsi
 1123031:	mov    %rsi,%rdi
 1123034:	sub    %rdx,%rdi
 1123037:	jae    112318d <sort.block.block__anon_39129+0x5e4d>
 112303d:	mov    %edx,%r8d
 1123040:	sub    %esi,%r8d
 1123043:	and    $0x3,%r8d
 1123047:	je     11230b5 <sort.block.block__anon_39129+0x5d75>
 1123049:	mov    -0x48(%rbp),%r9
 112304d:	lea    (%r9,%rax,2),%r9
 1123051:	sub    %rsi,%r9
 1123054:	sub    %rsi,%r9
 1123057:	mov    %r11,-0x90(%rbp)
 112305e:	lea    (%r11,%r11,1),%r10
 1123062:	lea    (%r10,%rsi,2),%r10
 1123066:	add    -0x50(%rbp),%r10
 112306a:	neg    %r8
 112306d:	xor    %r11d,%r11d
 1123070:	movzbl -0x1(%r10),%ebx
 1123075:	movzbl -0x1(%r9,%r11,2),%r15d
 112307b:	mov    %r15b,-0x1(%r10)
 112307f:	mov    %bl,-0x1(%r9,%r11,2)
 1123084:	movzbl (%r10),%ebx
 1123088:	movzbl (%r9,%r11,2),%r15d
 112308d:	mov    %r15b,(%r10)
 1123090:	mov    %bl,(%r9,%r11,2)
 1123094:	dec    %r11
 1123097:	add    $0x2,%r10
 112309b:	cmp    %r11,%r8
 112309e:	jne    1123070 <sort.block.block__anon_39129+0x5d30>
 11230a0:	sub    %r11,%rsi
 11230a3:	mov    -0x88(%rbp),%r15
 11230aa:	mov    -0x40(%rbp),%rbx
 11230ae:	mov    -0x90(%rbp),%r11
 11230b5:	cmp    $0xfffffffffffffffc,%rdi
 11230b9:	ja     112318d <sort.block.block__anon_39129+0x5e4d>
 11230bf:	mov    -0x80(%rbp),%rdi
 11230c3:	lea    (%rdi,%r11,2),%rdi
 11230c7:	mov    -0x48(%rbp),%r8
 11230cb:	lea    (%r8,%rax,2),%r8
 11230cf:	sub    %rsi,%r8
 11230d2:	sub    %rsi,%r8
 11230d5:	data16 cs nopw 0x0(%rax,%rax,1)
 11230e0:	movzbl -0x7(%rdi,%rsi,2),%r9d
 11230e6:	movzbl -0x1(%r8),%r10d
 11230eb:	mov    %r10b,-0x7(%rdi,%rsi,2)
 11230f0:	mov    %r9b,-0x1(%r8)
 11230f4:	movzbl -0x6(%rdi,%rsi,2),%r9d
 11230fa:	movzbl (%r8),%r10d
 11230fe:	mov    %r10b,-0x6(%rdi,%rsi,2)
 1123103:	mov    %r9b,(%r8)
 1123106:	movzbl -0x5(%rdi,%rsi,2),%r9d
 112310c:	movzbl -0x3(%r8),%r10d
 1123111:	mov    %r10b,-0x5(%rdi,%rsi,2)
 1123116:	mov    %r9b,-0x3(%r8)
 112311a:	movzbl -0x4(%rdi,%rsi,2),%r9d
 1123120:	movzbl -0x2(%r8),%r10d
 1123125:	mov    %r10b,-0x4(%rdi,%rsi,2)
 112312a:	mov    %r9b,-0x2(%r8)
 112312e:	movzbl -0x3(%rdi,%rsi,2),%r9d
 1123134:	movzbl -0x5(%r8),%r10d
 1123139:	mov    %r10b,-0x3(%rdi,%rsi,2)
 112313e:	mov    %r9b,-0x5(%r8)
 1123142:	movzbl -0x2(%rdi,%rsi,2),%r9d
 1123148:	movzbl -0x4(%r8),%r10d
 112314d:	mov    %r10b,-0x2(%rdi,%rsi,2)
 1123152:	mov    %r9b,-0x4(%r8)
 1123156:	movzbl -0x1(%rdi,%rsi,2),%r9d
 112315c:	movzbl -0x7(%r8),%r10d
 1123161:	mov    %r10b,-0x1(%rdi,%rsi,2)
 1123166:	mov    %r9b,-0x7(%r8)
 112316a:	movzbl (%rdi,%rsi,2),%r9d
 112316f:	movzbl -0x6(%r8),%r10d
 1123174:	mov    %r10b,(%rdi,%rsi,2)
 1123178:	mov    %r9b,-0x6(%r8)
 112317c:	add    $0x4,%rsi
 1123180:	add    $0xfffffffffffffff8,%r8
 1123184:	cmp    %rsi,%rdx
 1123187:	jne    11230e0 <sort.block.block__anon_39129+0x5da0>
 112318d:	mov    %rcx,%rdx
 1123190:	shr    %rdx
 1123193:	cmp    $0x20,%rcx
 1123197:	setb   %cl
 112319a:	cmp    $0xf,%rdx
 112319e:	sete   %sil
 11231a2:	or     %cl,%sil
 11231a5:	je     11231c0 <sort.block.block__anon_39129+0x5e80>
 11231a7:	xor    %ecx,%ecx
 11231a9:	mov    -0x38(%rbp),%r10
 11231ad:	jmp    1123361 <sort.block.block__anon_39129+0x6021>
 11231b2:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11231c0:	lea    -0x10(%rdx),%rcx
 11231c4:	mov    %rcx,%rsi
 11231c7:	shr    $0x4,%rsi
 11231cb:	inc    %rsi
 11231ce:	cmp    $0x30,%rcx
 11231d2:	jae    11231f0 <sort.block.block__anon_39129+0x5eb0>
 11231d4:	xor    %ecx,%ecx
 11231d6:	mov    -0x38(%rbp),%r10
 11231da:	and    $0x3,%esi
 11231dd:	jne    11232fa <sort.block.block__anon_39129+0x5fba>
 11231e3:	jmp    1123361 <sort.block.block__anon_39129+0x6021>
 11231e8:	nopl   0x0(%rax,%rax,1)
 11231f0:	mov    %rsi,%rdi
 11231f3:	movabs $0x1ffffffffffffffc,%rcx
 11231fd:	and    %rcx,%rdi
 1123200:	mov    -0xc8(%rbp),%rcx
 1123207:	lea    (%rcx,%r13,2),%r8
 112320b:	mov    -0x58(%rbp),%rcx
 112320f:	lea    (%rcx,%rax,2),%r9
 1123213:	xor    %ecx,%ecx
 1123215:	data16 cs nopw 0x0(%rax,%rax,1)
 1123220:	vmovdqu (%r9,%rcx,2),%ymm0
 1123226:	vmovdqu -0x60(%r8),%ymm1
 112322c:	vpshufb %ymm2,%ymm1,%ymm1
 1123231:	vpermq $0x4e,%ymm1,%ymm1
 1123237:	vmovdqu %ymm1,(%r9,%rcx,2)
 112323d:	vpshufb %ymm2,%ymm0,%ymm0
 1123242:	vpermq $0x4e,%ymm0,%ymm0
 1123248:	vmovdqu %ymm0,-0x60(%r8)
 112324e:	vmovdqu -0x20(%r9,%rcx,2),%ymm0
 1123255:	vmovdqu -0x40(%r8),%ymm1
 112325b:	vpshufb %ymm2,%ymm1,%ymm1
 1123260:	vpermq $0x4e,%ymm1,%ymm1
 1123266:	vmovdqu %ymm1,-0x20(%r9,%rcx,2)
 112326d:	vpshufb %ymm2,%ymm0,%ymm0
 1123272:	vpermq $0x4e,%ymm0,%ymm0
 1123278:	vmovdqu %ymm0,-0x40(%r8)
 112327e:	vmovdqu -0x40(%r9,%rcx,2),%ymm0
 1123285:	vmovdqu -0x20(%r8),%ymm1
 112328b:	vpshufb %ymm2,%ymm1,%ymm1
 1123290:	vpermq $0x4e,%ymm1,%ymm1
 1123296:	vmovdqu %ymm1,-0x40(%r9,%rcx,2)
 112329d:	vpshufb %ymm2,%ymm0,%ymm0
 11232a2:	vpermq $0x4e,%ymm0,%ymm0
 11232a8:	vmovdqu %ymm0,-0x20(%r8)
 11232ae:	vmovdqu -0x60(%r9,%rcx,2),%ymm0
 11232b5:	vmovdqu (%r8),%ymm1
 11232ba:	vpshufb %ymm2,%ymm1,%ymm1
 11232bf:	vpermq $0x4e,%ymm1,%ymm1
 11232c5:	vmovdqu %ymm1,-0x60(%r9,%rcx,2)
 11232cc:	vpshufb %ymm2,%ymm0,%ymm0
 11232d1:	vpermq $0x4e,%ymm0,%ymm0
 11232d7:	vmovdqu %ymm0,(%r8)
 11232dc:	sub    $0xffffffffffffff80,%r8
 11232e0:	add    $0xffffffffffffffc0,%rcx
 11232e4:	add    $0xfffffffffffffffc,%rdi
 11232e8:	jne    1123220 <sort.block.block__anon_39129+0x5ee0>
 11232ee:	neg    %rcx
 11232f1:	mov    -0x38(%rbp),%r10
 11232f5:	and    $0x3,%esi
 11232f8:	je     1123361 <sort.block.block__anon_39129+0x6021>
 11232fa:	mov    -0x58(%rbp),%rdi
 11232fe:	lea    (%rdi,%rax,2),%r8
 1123302:	mov    %rcx,%rdi
 1123305:	neg    %rdi
 1123308:	add    %rcx,%rcx
 112330b:	lea    (%rcx,%r13,2),%rcx
 112330f:	add    %r10,%rcx
 1123312:	shl    $0x5,%esi
 1123315:	xor    %r9d,%r9d
 1123318:	nopl   0x0(%rax,%rax,1)
 1123320:	vmovdqu (%r8,%rdi,2),%ymm0
 1123326:	vmovdqu (%rcx,%r9,1),%ymm1
 112332c:	vpshufb %ymm2,%ymm1,%ymm1
 1123331:	vpermq $0x4e,%ymm1,%ymm1
 1123337:	vmovdqu %ymm1,(%r8,%rdi,2)
 112333d:	vpshufb %ymm2,%ymm0,%ymm0
 1123342:	vpermq $0x4e,%ymm0,%ymm0
 1123348:	vmovdqu %ymm0,(%rcx,%r9,1)
 112334e:	add    $0xfffffffffffffff0,%rdi
 1123352:	add    $0x20,%r9
 1123356:	cmp    %r9,%rsi
 1123359:	jne    1123320 <sort.block.block__anon_39129+0x5fe0>
 112335b:	neg    %rdi
 112335e:	mov    %rdi,%rcx
 1123361:	mov    %rcx,%rsi
 1123364:	sub    %rdx,%rsi
 1123367:	jae    11234bd <sort.block.block__anon_39129+0x617d>
 112336d:	mov    %edx,%edi
 112336f:	sub    %ecx,%edi
 1123371:	and    $0x3,%edi
 1123374:	je     11233e5 <sort.block.block__anon_39129+0x60a5>
 1123376:	mov    %r11,%r15
 1123379:	mov    -0x48(%rbp),%r8
 112337d:	lea    (%r8,%rax,2),%r8
 1123381:	sub    %rcx,%r8
 1123384:	sub    %rcx,%r8
 1123387:	lea    0x0(,%r13,2),%r9
 112338f:	lea    (%r9,%rcx,2),%r9
 1123393:	add    -0x50(%rbp),%r9
 1123397:	neg    %rdi
 112339a:	xor    %r10d,%r10d
 112339d:	nopl   (%rax)
 11233a0:	movzbl -0x1(%r9),%r11d
 11233a5:	movzbl -0x1(%r8,%r10,2),%ebx
 11233ab:	mov    %bl,-0x1(%r9)
 11233af:	mov    %r11b,-0x1(%r8,%r10,2)
 11233b4:	movzbl (%r9),%r11d
 11233b8:	movzbl (%r8,%r10,2),%ebx
 11233bd:	mov    %bl,(%r9)
 11233c0:	mov    %r11b,(%r8,%r10,2)
 11233c4:	dec    %r10
 11233c7:	add    $0x2,%r9
 11233cb:	cmp    %r10,%rdi
 11233ce:	jne    11233a0 <sort.block.block__anon_39129+0x6060>
 11233d0:	sub    %r10,%rcx
 11233d3:	mov    -0x38(%rbp),%r10
 11233d7:	mov    -0x40(%rbp),%rbx
 11233db:	mov    %r15,%r11
 11233de:	mov    -0x88(%rbp),%r15
 11233e5:	cmp    $0xfffffffffffffffc,%rsi
 11233e9:	ja     11234bd <sort.block.block__anon_39129+0x617d>
 11233ef:	mov    -0x80(%rbp),%rsi
 11233f3:	lea    (%rsi,%r13,2),%rsi
 11233f7:	mov    -0x48(%rbp),%rdi
 11233fb:	lea    (%rdi,%rax,2),%rdi
 11233ff:	sub    %rcx,%rdi
 1123402:	sub    %rcx,%rdi
 1123405:	data16 cs nopw 0x0(%rax,%rax,1)
 1123410:	movzbl -0x7(%rsi,%rcx,2),%r8d
 1123416:	movzbl -0x1(%rdi),%r9d
 112341b:	mov    %r9b,-0x7(%rsi,%rcx,2)
 1123420:	mov    %r8b,-0x1(%rdi)
 1123424:	movzbl -0x6(%rsi,%rcx,2),%r8d
 112342a:	movzbl (%rdi),%r9d
 112342e:	mov    %r9b,-0x6(%rsi,%rcx,2)
 1123433:	mov    %r8b,(%rdi)
 1123436:	movzbl -0x5(%rsi,%rcx,2),%r8d
 112343c:	movzbl -0x3(%rdi),%r9d
 1123441:	mov    %r9b,-0x5(%rsi,%rcx,2)
 1123446:	mov    %r8b,-0x3(%rdi)
 112344a:	movzbl -0x4(%rsi,%rcx,2),%r8d
 1123450:	movzbl -0x2(%rdi),%r9d
 1123455:	mov    %r9b,-0x4(%rsi,%rcx,2)
 112345a:	mov    %r8b,-0x2(%rdi)
 112345e:	movzbl -0x3(%rsi,%rcx,2),%r8d
 1123464:	movzbl -0x5(%rdi),%r9d
 1123469:	mov    %r9b,-0x3(%rsi,%rcx,2)
 112346e:	mov    %r8b,-0x5(%rdi)
 1123472:	movzbl -0x2(%rsi,%rcx,2),%r8d
 1123478:	movzbl -0x4(%rdi),%r9d
 112347d:	mov    %r9b,-0x2(%rsi,%rcx,2)
 1123482:	mov    %r8b,-0x4(%rdi)
 1123486:	movzbl -0x1(%rsi,%rcx,2),%r8d
 112348c:	movzbl -0x7(%rdi),%r9d
 1123491:	mov    %r9b,-0x1(%rsi,%rcx,2)
 1123496:	mov    %r8b,-0x7(%rdi)
 112349a:	movzbl (%rsi,%rcx,2),%r8d
 112349f:	movzbl -0x6(%rdi),%r9d
 11234a4:	mov    %r9b,(%rsi,%rcx,2)
 11234a8:	mov    %r8b,-0x6(%rdi)
 11234ac:	add    $0x4,%rcx
 11234b0:	add    $0xfffffffffffffff8,%rdi
 11234b4:	cmp    %rcx,%rdx
 11234b7:	jne    1123410 <sort.block.block__anon_39129+0x60d0>
 11234bd:	cmp    %rax,%r14
 11234c0:	je     11235f5 <sort.block.block__anon_39129+0x62b5>
 11234c6:	mov    %rax,%r8
 11234c9:	sub    %r11,%r8
 11234cc:	add    %r13,%r8
 11234cf:	mov    %rax,%rcx
 11234d2:	mov    %rax,%r13
 11234d5:	sub    %r8,%rcx
 11234d8:	jbe    1122a80 <sort.block.block__anon_39129+0x5740>
 11234de:	movzwl (%r10,%r8,2),%edi
 11234e3:	mov    -0x30(%rbp),%rdx
 11234e7:	mov    (%rdx),%rdx
 11234ea:	shl    $0x4,%edi
 11234ed:	lea    (%rdx,%rdi,1),%rsi
 11234f1:	mov    (%rdx,%rdi,1),%rdi
 11234f5:	mov    %r8,%r13
 11234f8:	jmp    112351a <sort.block.block__anon_39129+0x61da>
 11234fa:	nopw   0x0(%rax,%rax,1)
 1123500:	mov    %ecx,%r9d
 1123503:	and    $0x1,%r9d
 1123507:	add    %r8,%r9
 112350a:	add    %r9,%r13
 112350d:	cmp    $0x1,%rcx
 1123511:	mov    %r8,%rcx
 1123514:	jbe    1122a80 <sort.block.block__anon_39129+0x5740>
 112351a:	lea    (%r10,%r13,2),%r8
 112351e:	mov    %rcx,%r9
 1123521:	and    $0xfffffffffffffffe,%r9
 1123525:	movzwl (%r9,%r8,1),%r8d
 112352a:	shl    $0x4,%r8d
 112352e:	cmp    (%rdx,%r8,1),%rdi
 1123532:	jne    1123541 <sort.block.block__anon_39129+0x6201>
 1123534:	add    %rdx,%r8
 1123537:	movzwl 0xe(%rsi),%r9d
 112353c:	cmp    0xe(%r8),%r9w
 1123541:	setb   %r9b
 1123545:	mov    %rcx,%r8
 1123548:	shr    %r8
 112354b:	test   %r9b,%r9b
 112354e:	je     1123500 <sort.block.block__anon_39129+0x61c0>
 1123550:	xor    %r9d,%r9d
 1123553:	add    %r9,%r13
 1123556:	cmp    $0x1,%rcx
 112355a:	mov    %r8,%rcx
 112355d:	ja     112351a <sort.block.block__anon_39129+0x61da>
 112355f:	jmp    1122a80 <sort.block.block__anon_39129+0x5740>
 1123564:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1123570:	xor    %eax,%eax
 1123572:	jmp    11235cc <sort.block.block__anon_39129+0x628c>
 1123574:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1123580:	mov    %r14,%rax
 1123583:	sub    %r11,%rax
 1123586:	mov    %rax,-0x60(%rbp)
 112358a:	jne    11237f0 <sort.block.block__anon_39129+0x64b0>
 1123590:	xor    %esi,%esi
 1123592:	xor    %ecx,%ecx
 1123594:	lea    (%rsi,%r13,1),%rax
 1123598:	sub    %rax,%r11
 112359b:	je     11235f5 <sort.block.block__anon_39129+0x62b5>
 112359d:	jmp    11238fd <sort.block.block__anon_39129+0x65bd>
 11235a2:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11235b0:	add    %rdi,%rsi
 11235b3:	mov    %rsi,%r13
 11235b6:	mov    -0x38(%rbp),%r10
 11235ba:	mov    -0x88(%rbp),%r15
 11235c1:	mov    -0x40(%rbp),%rbx
 11235c5:	mov    -0x128(%rbp),%rdx
 11235cc:	lea    -0x650(,%rax,2),%rsi
 11235d4:	add    %rbp,%rsi
 11235d7:	sub    %rax,%rdx
 11235da:	lea    (%r10,%r13,2),%rdi
 11235de:	add    %rdx,%rdx
 11235e1:	vzeroupper 
 11235e4:	call   119d8c0 <compiler_rt.memcpy.memcpyFast>
 11235e9:	mov    -0x38(%rbp),%r10
 11235ed:	vmovdqa -0x120dd5(%rip),%ymm2        # 1002820 <__anon_38908+0x60>
 11235f5:	mov    -0xe0(%rbp),%r13
 11235fc:	sub    %r14,%r13
 11235ff:	cmpb   $0x0,-0x140(%rbp)
 1123606:	je     1123640 <sort.block.block__anon_39129+0x6300>
 1123608:	cmpq   $0x200,-0x100(%rbp)
 1123613:	jae    1123670 <sort.block.block__anon_39129+0x6330>
 1123615:	lea    -0x650(%rbp),%rdi
 112361c:	mov    %r12,%rsi
 112361f:	mov    -0x238(%rbp),%rdx
 1123626:	vzeroupper 
 1123629:	call   119d8c0 <compiler_rt.memcpy.memcpyFast>
 112362e:	vmovdqa -0x120e16(%rip),%ymm2        # 1002820 <__anon_38908+0x60>
 1123636:	mov    -0x38(%rbp),%r10
 112363a:	jmp    112378e <sort.block.block__anon_39129+0x644e>
 112363f:	nop
 1123640:	lea    (%r10,%r14,2),%rax
 1123644:	mov    %rbx,%rdx
 1123647:	sub    %r14,%rdx
 112364a:	mov    %rdx,%rcx
 112364d:	shr    %rcx
 1123650:	cmp    $0x20,%rdx
 1123654:	setb   %sil
 1123658:	cmp    $0xf,%rcx
 112365c:	sete   %dil
 1123660:	or     %sil,%dil
 1123663:	je     11237d0 <sort.block.block__anon_39129+0x6490>
 1123669:	xor    %esi,%esi
 112366b:	jmp    1123bf0 <sort.block.block__anon_39129+0x68b0>
 1123670:	mov    -0x230(%rbp),%rdx
 1123677:	xor    %eax,%eax
 1123679:	mov    -0xb0(%rbp),%rdi
 1123680:	mov    -0x110(%rbp),%r8
 1123687:	mov    -0x1d0(%rbp),%r9
 112368e:	xchg   %ax,%ax
 1123690:	mov    %rdx,%rcx
 1123693:	movzbl (%r12,%rax,2),%edx
 1123698:	movzbl -0x7(%r9,%rax,2),%esi
 112369e:	mov    %sil,(%r12,%rax,2)
 11236a2:	mov    %dl,-0x7(%r9,%rax,2)
 11236a7:	movzbl 0x1(%r12,%rax,2),%edx
 11236ad:	movzbl -0x6(%r9,%rax,2),%esi
 11236b3:	mov    %sil,0x1(%r12,%rax,2)
 11236b8:	mov    %dl,-0x6(%r9,%rax,2)
 11236bd:	movzbl 0x2(%r12,%rax,2),%edx
 11236c3:	movzbl -0x5(%r9,%rax,2),%esi
 11236c9:	mov    %sil,0x2(%r12,%rax,2)
 11236ce:	mov    %dl,-0x5(%r9,%rax,2)
 11236d3:	movzbl 0x3(%r12,%rax,2),%edx
 11236d9:	movzbl -0x4(%r9,%rax,2),%esi
 11236df:	mov    %sil,0x3(%r12,%rax,2)
 11236e4:	mov    %dl,-0x4(%r9,%rax,2)
 11236e9:	movzbl 0x4(%r12,%rax,2),%edx
 11236ef:	movzbl -0x3(%r9,%rax,2),%esi
 11236f5:	mov    %sil,0x4(%r12,%rax,2)
 11236fa:	mov    %dl,-0x3(%r9,%rax,2)
 11236ff:	movzbl 0x5(%r12,%rax,2),%edx
 1123705:	movzbl -0x2(%r9,%rax,2),%esi
 112370b:	mov    %sil,0x5(%r12,%rax,2)
 1123710:	mov    %dl,-0x2(%r9,%rax,2)
 1123715:	movzbl 0x6(%r12,%rax,2),%edx
 112371b:	movzbl -0x1(%r9,%rax,2),%esi
 1123721:	mov    %sil,0x6(%r12,%rax,2)
 1123726:	mov    %dl,-0x1(%r9,%rax,2)
 112372b:	movzbl 0x7(%r12,%rax,2),%edx
 1123731:	movzbl (%r9,%rax,2),%esi
 1123736:	mov    %sil,0x7(%r12,%rax,2)
 112373b:	mov    %dl,(%r9,%rax,2)
 112373f:	add    $0x4,%rax
 1123743:	lea    0x8(%rcx),%rdx
 1123747:	cmp    %rax,%r8
 112374a:	jne    1123690 <sort.block.block__anon_39129+0x6350>
 1123750:	test   %rdi,%rdi
 1123753:	je     112378e <sort.block.block__anon_39129+0x644e>
 1123755:	mov    -0xb0(%rbp),%rdx
 112375c:	nopl   0x0(%rax)
 1123760:	movzbl (%r12,%rax,2),%esi
 1123765:	movzbl -0x1(%rcx),%edi
 1123769:	mov    %dil,(%r12,%rax,2)
 112376d:	mov    %sil,-0x1(%rcx)
 1123771:	movzbl 0x1(%r12,%rax,2),%esi
 1123777:	movzbl (%rcx),%edi
 112377a:	mov    %dil,0x1(%r12,%rax,2)
 112377f:	mov    %sil,(%rcx)
 1123782:	inc    %rax
 1123785:	add    $0x2,%rcx
 1123789:	dec    %rdx
 112378c:	jne    1123760 <sort.block.block__anon_39129+0x6420>
 112378e:	mov    -0xe0(%rbp),%rdx
 1123795:	cmp    %r14,%rdx
 1123798:	mov    -0xe8(%rbp),%r12
 112379f:	je     11225b0 <sort.block.block__anon_39129+0x5270>
 11237a5:	mov    -0x78(%rbp),%rax
 11237a9:	sub    %r13,%rax
 11237ac:	lea    (%r10,%rax,2),%rax
 11237b0:	mov    %r14,%rcx
 11237b3:	sub    %rdx,%rcx
 11237b6:	cmp    $0xfffffffffffffffc,%rcx
 11237ba:	jbe    1123951 <sort.block.block__anon_39129+0x6611>
 11237c0:	xor    %ecx,%ecx
 11237c2:	jmp    1123a21 <sort.block.block__anon_39129+0x66e1>
 11237c7:	nopw   0x0(%rax,%rax,1)
 11237d0:	lea    -0x10(%rcx),%rsi
 11237d4:	mov    %rsi,%rdi
 11237d7:	shr    $0x4,%rdi
 11237db:	inc    %rdi
 11237de:	cmp    $0x30,%rsi
 11237e2:	jae    1123a78 <sort.block.block__anon_39129+0x6738>
 11237e8:	xor    %r10d,%r10d
 11237eb:	jmp    1123ba0 <sort.block.block__anon_39129+0x6860>
 11237f0:	mov    %r14,-0x1c8(%rbp)
 11237f7:	lea    (%r10,%r11,2),%rdi
 11237fb:	mov    -0x50(%rbp),%rax
 11237ff:	lea    (%rax,%r13,2),%rbx
 1123803:	xor    %esi,%esi
 1123805:	xor    %r8d,%r8d
 1123808:	xor    %eax,%eax
 112380a:	mov    %rdx,-0x128(%rbp)
 1123811:	mov    %rax,%rcx
 1123814:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1123820:	mov    %r11,%r9
 1123823:	movzwl (%rdi,%r8,2),%r10d
 1123828:	mov    -0x68(%rbp),%rax
 112382c:	mov    %rsi,%r14
 112382f:	movzwl (%rax,%rsi,2),%eax
 1123833:	mov    -0x30(%rbp),%rdx
 1123837:	mov    (%rdx),%r15
 112383a:	mov    %r10d,%r11d
 112383d:	shl    $0x4,%r11d
 1123841:	mov    %eax,%esi
 1123843:	shl    $0x4,%esi
 1123846:	mov    (%r15,%rsi,1),%rdx
 112384a:	cmp    %rdx,(%r15,%r11,1)
 112384e:	jne    112385f <sort.block.block__anon_39129+0x651f>
 1123850:	add    %r15,%r11
 1123853:	add    %r15,%rsi
 1123856:	movzwl 0xe(%r11),%edx
 112385b:	cmp    0xe(%rsi),%dx
 112385f:	mov    %r9,%r11
 1123862:	jae    11238a0 <sort.block.block__anon_39129+0x6560>
 1123864:	mov    %r10d,%eax
 1123867:	shr    $0x8,%eax
 112386a:	movzbl -0x1(%rbx,%rcx,2),%edx
 112386f:	mov    %r10b,-0x1(%rbx,%rcx,2)
 1123874:	mov    %dl,(%rdi,%r8,2)
 1123878:	movzbl (%rbx,%rcx,2),%edx
 112387c:	mov    %al,(%rbx,%rcx,2)
 112387f:	mov    %dl,0x1(%rdi,%r8,2)
 1123884:	inc    %r8
 1123887:	inc    %rcx
 112388a:	cmp    -0x60(%rbp),%r8
 112388e:	mov    %r14,%rsi
 1123891:	jb     1123820 <sort.block.block__anon_39129+0x64e0>
 1123893:	jmp    11238da <sort.block.block__anon_39129+0x659a>
 1123895:	data16 cs nopw 0x0(%rax,%rax,1)
 11238a0:	movzbl -0x1(%rbx,%rcx,2),%edx
 11238a5:	mov    %al,-0x1(%rbx,%rcx,2)
 11238a9:	mov    -0x68(%rbp),%rsi
 11238ad:	mov    %dl,(%rsi,%r14,2)
 11238b1:	movzbl (%rbx,%rcx,2),%edx
 11238b5:	mov    %ah,(%rbx,%rcx,2)
 11238b8:	mov    %dl,0x1(%rsi,%r14,2)
 11238bd:	mov    %r14,%rsi
 11238c0:	inc    %rsi
 11238c3:	lea    0x1(%rcx),%rax
 11238c7:	mov    -0x128(%rbp),%rdx
 11238ce:	cmp    %rdx,%rsi
 11238d1:	jb     1123811 <sort.block.block__anon_39129+0x64d1>
 11238d7:	inc    %rcx
 11238da:	mov    -0x38(%rbp),%r10
 11238de:	mov    -0x88(%rbp),%r15
 11238e5:	mov    -0x40(%rbp),%rbx
 11238e9:	mov    -0x1c8(%rbp),%r14
 11238f0:	lea    (%rsi,%r13,1),%rax
 11238f4:	sub    %rax,%r11
 11238f7:	je     11235f5 <sort.block.block__anon_39129+0x62b5>
 11238fd:	add    %r13,%r13
 1123900:	lea    0x0(,%rcx,2),%rax
 1123908:	add    %r13,%rax
 112390b:	add    -0x50(%rbp),%rax
 112390f:	mov    -0x1a8(%rbp),%rcx
 1123916:	lea    (%rcx,%rsi,2),%rcx
 112391a:	xor    %edx,%edx
 112391c:	nopl   0x0(%rax)
 1123920:	movzbl -0x1(%rcx,%rdx,2),%esi
 1123925:	movzbl -0x1(%rax,%rdx,2),%edi
 112392a:	mov    %dil,-0x1(%rcx,%rdx,2)
 112392f:	mov    %sil,-0x1(%rax,%rdx,2)
 1123934:	movzbl (%rcx,%rdx,2),%esi
 1123938:	movzbl (%rax,%rdx,2),%edi
 112393c:	mov    %dil,(%rcx,%rdx,2)
 1123940:	mov    %sil,(%rax,%rdx,2)
 1123944:	inc    %rdx
 1123947:	cmp    %rdx,%r11
 112394a:	jne    1123920 <sort.block.block__anon_39129+0x65e0>
 112394c:	jmp    11235f5 <sort.block.block__anon_39129+0x62b5>
 1123951:	mov    %r13,%rdx
 1123954:	and    $0xfffffffffffffffc,%rdx
 1123958:	mov    -0x80(%rbp),%rcx
 112395c:	lea    (%rcx,%r14,2),%rsi
 1123960:	xor    %ecx,%ecx
 1123962:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1123970:	movzbl -0x7(%rsi,%rcx,2),%edi
 1123975:	movzbl (%rax,%rcx,2),%r8d
 112397a:	mov    %r8b,-0x7(%rsi,%rcx,2)
 112397f:	mov    %dil,(%rax,%rcx,2)
 1123983:	movzbl -0x6(%rsi,%rcx,2),%edi
 1123988:	movzbl 0x1(%rax,%rcx,2),%r8d
 112398e:	mov    %r8b,-0x6(%rsi,%rcx,2)
 1123993:	mov    %dil,0x1(%rax,%rcx,2)
 1123998:	movzbl -0x5(%rsi,%rcx,2),%edi
 112399d:	movzbl 0x2(%rax,%rcx,2),%r8d
 11239a3:	mov    %r8b,-0x5(%rsi,%rcx,2)
 11239a8:	mov    %dil,0x2(%rax,%rcx,2)
 11239ad:	movzbl -0x4(%rsi,%rcx,2),%edi
 11239b2:	movzbl 0x3(%rax,%rcx,2),%r8d
 11239b8:	mov    %r8b,-0x4(%rsi,%rcx,2)
 11239bd:	mov    %dil,0x3(%rax,%rcx,2)
 11239c2:	movzbl -0x3(%rsi,%rcx,2),%edi
 11239c7:	movzbl 0x4(%rax,%rcx,2),%r8d
 11239cd:	mov    %r8b,-0x3(%rsi,%rcx,2)
 11239d2:	mov    %dil,0x4(%rax,%rcx,2)
 11239d7:	movzbl -0x2(%rsi,%rcx,2),%edi
 11239dc:	movzbl 0x5(%rax,%rcx,2),%r8d
 11239e2:	mov    %r8b,-0x2(%rsi,%rcx,2)
 11239e7:	mov    %dil,0x5(%rax,%rcx,2)
 11239ec:	movzbl -0x1(%rsi,%rcx,2),%edi
 11239f1:	movzbl 0x6(%rax,%rcx,2),%r8d
 11239f7:	mov    %r8b,-0x1(%rsi,%rcx,2)
 11239fc:	mov    %dil,0x6(%rax,%rcx,2)
 1123a01:	movzbl (%rsi,%rcx,2),%edi
 1123a05:	movzbl 0x7(%rax,%rcx,2),%r8d
 1123a0b:	mov    %r8b,(%rsi,%rcx,2)
 1123a0f:	mov    %dil,0x7(%rax,%rcx,2)
 1123a14:	add    $0x4,%rcx
 1123a18:	cmp    %rcx,%rdx
 1123a1b:	jne    1123970 <sort.block.block__anon_39129+0x6630>
 1123a21:	mov    %r13d,%edx
 1123a24:	and    $0x3,%edx
 1123a27:	je     11225b0 <sort.block.block__anon_39129+0x5270>
 1123a2d:	add    %r14,%r14
 1123a30:	lea    (%r14,%rcx,2),%rsi
 1123a34:	add    -0x50(%rbp),%rsi
 1123a38:	xor    %edi,%edi
 1123a3a:	nopw   0x0(%rax,%rax,1)
 1123a40:	movzbl -0x1(%rsi,%rdi,2),%r8d
 1123a46:	movzbl (%rax,%rcx,2),%r9d
 1123a4b:	mov    %r9b,-0x1(%rsi,%rdi,2)
 1123a50:	mov    %r8b,(%rax,%rcx,2)
 1123a54:	movzbl (%rsi,%rdi,2),%r8d
 1123a59:	movzbl 0x1(%rax,%rcx,2),%r9d
 1123a5f:	mov    %r9b,(%rsi,%rdi,2)
 1123a63:	mov    %r8b,0x1(%rax,%rcx,2)
 1123a68:	inc    %rcx
 1123a6b:	inc    %rdi
 1123a6e:	cmp    %rdi,%rdx
 1123a71:	jne    1123a40 <sort.block.block__anon_39129+0x6700>
 1123a73:	jmp    11225b0 <sort.block.block__anon_39129+0x5270>
 1123a78:	mov    %rdi,%rsi
 1123a7b:	movabs $0x1ffffffffffffffc,%r8
 1123a85:	and    %r8,%rsi
 1123a88:	mov    -0xc8(%rbp),%r8
 1123a8f:	lea    (%r8,%r14,2),%r8
 1123a93:	xor    %r9d,%r9d
 1123a96:	cs nopw 0x0(%rax,%rax,1)
 1123aa0:	mov    %r9,%r10
 1123aa3:	mov    %rdx,%r11
 1123aa6:	sub    %r9,%r11
 1123aa9:	vmovdqu -0x20(%rax,%r11,2),%ymm0
 1123ab0:	vmovdqu -0x60(%r8,%r9,2),%ymm1
 1123ab7:	vpshufb %ymm2,%ymm1,%ymm1
 1123abc:	vpermq $0x4e,%ymm1,%ymm1
 1123ac2:	vmovdqu %ymm1,-0x20(%rax,%r11,2)
 1123ac9:	or     $0x10,%r10
 1123acd:	vpshufb %ymm2,%ymm0,%ymm0
 1123ad2:	vpermq $0x4e,%ymm0,%ymm0
 1123ad8:	vmovdqu %ymm0,-0x60(%r8,%r9,2)
 1123adf:	mov    %r9,%r11
 1123ae2:	mov    %rdx,%rbx
 1123ae5:	sub    %r10,%rbx
 1123ae8:	vmovdqu -0x20(%rax,%rbx,2),%ymm0
 1123aee:	vmovdqu -0x40(%r8,%r9,2),%ymm1
 1123af5:	vpshufb %ymm2,%ymm1,%ymm1
 1123afa:	vpermq $0x4e,%ymm1,%ymm1
 1123b00:	vmovdqu %ymm1,-0x20(%rax,%rbx,2)
 1123b06:	or     $0x20,%r11
 1123b0a:	vpshufb %ymm2,%ymm0,%ymm0
 1123b0f:	vpermq $0x4e,%ymm0,%ymm0
 1123b15:	vmovdqu %ymm0,-0x40(%r8,%r9,2)
 1123b1c:	mov    %r9,%r10
 1123b1f:	mov    %rdx,%rbx
 1123b22:	sub    %r11,%rbx
 1123b25:	vmovdqu -0x20(%rax,%rbx,2),%ymm0
 1123b2b:	vmovdqu -0x20(%r8,%r9,2),%ymm1
 1123b32:	vpshufb %ymm2,%ymm1,%ymm1
 1123b37:	vpermq $0x4e,%ymm1,%ymm1
 1123b3d:	vmovdqu %ymm1,-0x20(%rax,%rbx,2)
 1123b43:	or     $0x30,%r10
 1123b47:	vpshufb %ymm2,%ymm0,%ymm0
 1123b4c:	vpermq $0x4e,%ymm0,%ymm0
 1123b52:	vmovdqu %ymm0,-0x20(%r8,%r9,2)
 1123b59:	mov    %rdx,%r11
 1123b5c:	sub    %r10,%r11
 1123b5f:	vmovdqu -0x20(%rax,%r11,2),%ymm0
 1123b66:	vmovdqu (%r8,%r9,2),%ymm1
 1123b6c:	vpshufb %ymm2,%ymm1,%ymm1
 1123b71:	vpermq $0x4e,%ymm1,%ymm1
 1123b77:	vmovdqu %ymm1,-0x20(%rax,%r11,2)
 1123b7e:	lea    0x40(%r9),%r10
 1123b82:	vpshufb %ymm2,%ymm0,%ymm0
 1123b87:	vpermq $0x4e,%ymm0,%ymm0
 1123b8d:	vmovdqu %ymm0,(%r8,%r9,2)
 1123b93:	mov    %r10,%r9
 1123b96:	add    $0xfffffffffffffffc,%rsi
 1123b9a:	jne    1123aa0 <sort.block.block__anon_39129+0x6760>
 1123ba0:	mov    %r10,%rsi
 1123ba3:	and    $0x3,%edi
 1123ba6:	mov    -0x40(%rbp),%rbx
 1123baa:	je     1123bf0 <sort.block.block__anon_39129+0x68b0>
 1123bac:	nopl   0x0(%rax)
 1123bb0:	mov    %rdx,%rsi
 1123bb3:	sub    %r10,%rsi
 1123bb6:	vmovdqu -0x20(%rax,%rsi,2),%ymm0
 1123bbc:	vmovdqu (%rax,%r10,2),%ymm1
 1123bc2:	vpshufb %ymm2,%ymm1,%ymm1
 1123bc7:	vpermq $0x4e,%ymm1,%ymm1
 1123bcd:	vmovdqu %ymm1,-0x20(%rax,%rsi,2)
 1123bd3:	lea    0x10(%r10),%rsi
 1123bd7:	vpshufb %ymm2,%ymm0,%ymm0
 1123bdc:	vpermq $0x4e,%ymm0,%ymm0
 1123be2:	vmovdqu %ymm0,(%rax,%r10,2)
 1123be8:	mov    %rsi,%r10
 1123beb:	dec    %rdi
 1123bee:	jne    1123bb0 <sort.block.block__anon_39129+0x6870>
 1123bf0:	mov    %rsi,%rdi
 1123bf3:	sub    %rcx,%rdi
 1123bf6:	jae    1123d37 <sort.block.block__anon_39129+0x69f7>
 1123bfc:	mov    %ecx,%r8d
 1123bff:	sub    %esi,%r8d
 1123c02:	and    $0x3,%r8d
 1123c06:	je     1123c46 <sort.block.block__anon_39129+0x6906>
 1123c08:	mov    -0x50(%rbp),%r9
 1123c0c:	lea    (%r9,%r14,2),%r9
 1123c10:	mov    %rsi,%r10
 1123c13:	not    %r10
 1123c16:	movzbl -0x1(%r9,%rsi,2),%r11d
 1123c1c:	movzbl (%r12,%r10,2),%ebx
 1123c21:	mov    %bl,-0x1(%r9,%rsi,2)
 1123c26:	mov    %r11b,(%r12,%r10,2)
 1123c2a:	movzbl (%r9,%rsi,2),%r11d
 1123c2f:	movzbl 0x1(%r12,%r10,2),%ebx
 1123c35:	mov    %bl,(%r9,%rsi,2)
 1123c39:	mov    %r11b,0x1(%r12,%r10,2)
 1123c3e:	inc    %rsi
 1123c41:	dec    %r8
 1123c44:	jne    1123c10 <sort.block.block__anon_39129+0x68d0>
 1123c46:	cmp    $0xfffffffffffffffc,%rdi
 1123c4a:	mov    -0x40(%rbp),%rbx
 1123c4e:	ja     1123d37 <sort.block.block__anon_39129+0x69f7>
 1123c54:	mov    -0x80(%rbp),%rdi
 1123c58:	lea    (%rdi,%r14,2),%rdi
 1123c5c:	nopl   0x0(%rax)
 1123c60:	mov    %rsi,%r8
 1123c63:	not    %r8
 1123c66:	movzbl -0x7(%rdi,%rsi,2),%r9d
 1123c6c:	movzbl (%r12,%r8,2),%r10d
 1123c71:	mov    %r10b,-0x7(%rdi,%rsi,2)
 1123c76:	mov    %r9b,(%r12,%r8,2)
 1123c7a:	movzbl -0x6(%rdi,%rsi,2),%r9d
 1123c80:	movzbl 0x1(%r12,%r8,2),%r10d
 1123c86:	mov    %r10b,-0x6(%rdi,%rsi,2)
 1123c8b:	mov    %r9b,0x1(%r12,%r8,2)
 1123c90:	mov    $0xfffffffffffffffe,%r8
 1123c97:	sub    %rsi,%r8
 1123c9a:	movzbl -0x5(%rdi,%rsi,2),%r9d
 1123ca0:	movzbl (%r12,%r8,2),%r10d
 1123ca5:	mov    %r10b,-0x5(%rdi,%rsi,2)
 1123caa:	mov    %r9b,(%r12,%r8,2)
 1123cae:	movzbl -0x4(%rdi,%rsi,2),%r9d
 1123cb4:	movzbl 0x1(%r12,%r8,2),%r10d
 1123cba:	mov    %r10b,-0x4(%rdi,%rsi,2)
 1123cbf:	mov    %r9b,0x1(%r12,%r8,2)
 1123cc4:	mov    $0xfffffffffffffffd,%r8
 1123ccb:	sub    %rsi,%r8
 1123cce:	movzbl -0x3(%rdi,%rsi,2),%r9d
 1123cd4:	movzbl (%r12,%r8,2),%r10d
 1123cd9:	mov    %r10b,-0x3(%rdi,%rsi,2)
 1123cde:	mov    %r9b,(%r12,%r8,2)
 1123ce2:	movzbl -0x2(%rdi,%rsi,2),%r9d
 1123ce8:	movzbl 0x1(%r12,%r8,2),%r10d
 1123cee:	mov    %r10b,-0x2(%rdi,%rsi,2)
 1123cf3:	mov    %r9b,0x1(%r12,%r8,2)
 1123cf8:	mov    $0xfffffffffffffffc,%r8
 1123cff:	sub    %rsi,%r8
 1123d02:	movzbl -0x1(%rdi,%rsi,2),%r9d
 1123d08:	movzbl (%r12,%r8,2),%r10d
 1123d0d:	mov    %r10b,-0x1(%rdi,%rsi,2)
 1123d12:	mov    %r9b,(%r12,%r8,2)
 1123d16:	movzbl (%rdi,%rsi,2),%r9d
 1123d1b:	movzbl 0x1(%r12,%r8,2),%r10d
 1123d21:	mov    %r10b,(%rdi,%rsi,2)
 1123d25:	mov    %r9b,0x1(%r12,%r8,2)
 1123d2a:	add    $0x4,%rsi
 1123d2e:	cmp    %rsi,%rcx
 1123d31:	jne    1123c60 <sort.block.block__anon_39129+0x6920>
 1123d37:	mov    -0x78(%rbp),%rcx
 1123d3b:	sub    %r14,%rcx
 1123d3e:	mov    %rcx,%rdi
 1123d41:	sub    %rdx,%rdi
 1123d44:	mov    %rdi,%rdx
 1123d47:	shr    %rdx
 1123d4a:	cmp    $0xf,%rdx
 1123d4e:	jne    1123d60 <sort.block.block__anon_39129+0x6a20>
 1123d50:	xor    %esi,%esi
 1123d52:	jmp    1123ef9 <sort.block.block__anon_39129+0x6bb9>
 1123d57:	nopw   0x0(%rax,%rax,1)
 1123d60:	lea    -0x10(%rdx),%rsi
 1123d64:	mov    %rsi,%r8
 1123d67:	shr    $0x4,%r8
 1123d6b:	inc    %r8
 1123d6e:	cmp    $0x30,%rsi
 1123d72:	jae    1123d7b <sort.block.block__anon_39129+0x6a3b>
 1123d74:	xor    %esi,%esi
 1123d76:	jmp    1123e94 <sort.block.block__anon_39129+0x6b54>
 1123d7b:	mov    %r8,%r9
 1123d7e:	movabs $0x1ffffffffffffffc,%rsi
 1123d88:	and    %rsi,%r9
 1123d8b:	xor    %r10d,%r10d
 1123d8e:	xchg   %ax,%ax
 1123d90:	mov    %r10,%rsi
 1123d93:	mov    %rdi,%r11
 1123d96:	sub    %r10,%r11
 1123d99:	vmovdqu -0x20(%r12,%r11,2),%ymm0
 1123da0:	vmovdqu (%r12,%r10,2),%ymm1
 1123da6:	vpshufb %ymm2,%ymm1,%ymm1
 1123dab:	vpermq $0x4e,%ymm1,%ymm1
 1123db1:	vmovdqu %ymm1,-0x20(%r12,%r11,2)
 1123db8:	or     $0x10,%rsi
 1123dbc:	vpshufb %ymm2,%ymm0,%ymm0
 1123dc1:	vpermq $0x4e,%ymm0,%ymm0
 1123dc7:	vmovdqu %ymm0,(%r12,%r10,2)
 1123dcd:	mov    %r10,%r11
 1123dd0:	mov    %rdi,%rbx
 1123dd3:	sub    %rsi,%rbx
 1123dd6:	vmovdqu -0x20(%r12,%rbx,2),%ymm0
 1123ddd:	vmovdqu 0x20(%r12,%r10,2),%ymm1
 1123de4:	vpshufb %ymm2,%ymm1,%ymm1
 1123de9:	vpermq $0x4e,%ymm1,%ymm1
 1123def:	vmovdqu %ymm1,-0x20(%r12,%rbx,2)
 1123df6:	or     $0x20,%r11
 1123dfa:	vpshufb %ymm2,%ymm0,%ymm0
 1123dff:	vpermq $0x4e,%ymm0,%ymm0
 1123e05:	vmovdqu %ymm0,0x20(%r12,%r10,2)
 1123e0c:	mov    %r10,%rsi
 1123e0f:	mov    %rdi,%rbx
 1123e12:	sub    %r11,%rbx
 1123e15:	vmovdqu -0x20(%r12,%rbx,2),%ymm0
 1123e1c:	vmovdqu 0x40(%r12,%r10,2),%ymm1
 1123e23:	vpshufb %ymm2,%ymm1,%ymm1
 1123e28:	vpermq $0x4e,%ymm1,%ymm1
 1123e2e:	vmovdqu %ymm1,-0x20(%r12,%rbx,2)
 1123e35:	or     $0x30,%rsi
 1123e39:	vpshufb %ymm2,%ymm0,%ymm0
 1123e3e:	vpermq $0x4e,%ymm0,%ymm0
 1123e44:	vmovdqu %ymm0,0x40(%r12,%r10,2)
 1123e4b:	mov    %rdi,%r11
 1123e4e:	sub    %rsi,%r11
 1123e51:	vmovdqu -0x20(%r12,%r11,2),%ymm0
 1123e58:	vmovdqu 0x60(%r12,%r10,2),%ymm1
 1123e5f:	vpshufb %ymm2,%ymm1,%ymm1
 1123e64:	vpermq $0x4e,%ymm1,%ymm1
 1123e6a:	vmovdqu %ymm1,-0x20(%r12,%r11,2)
 1123e71:	lea    0x40(%r10),%rsi
 1123e75:	vpshufb %ymm2,%ymm0,%ymm0
 1123e7a:	vpermq $0x4e,%ymm0,%ymm0
 1123e80:	vmovdqu %ymm0,0x60(%r12,%r10,2)
 1123e87:	mov    %rsi,%r10
 1123e8a:	add    $0xfffffffffffffffc,%r9
 1123e8e:	jne    1123d90 <sort.block.block__anon_39129+0x6a50>
 1123e94:	and    $0x3,%r8d
 1123e98:	mov    -0x40(%rbp),%rbx
 1123e9c:	je     1123ef9 <sort.block.block__anon_39129+0x6bb9>
 1123e9e:	shl    $0x4,%r8d
 1123ea2:	xor    %r9d,%r9d
 1123ea5:	mov    %rsi,%r10
 1123ea8:	nopl   0x0(%rax,%rax,1)
 1123eb0:	mov    %rdi,%r11
 1123eb3:	sub    %r10,%r11
 1123eb6:	vmovdqu -0x20(%r12,%r11,2),%ymm0
 1123ebd:	vmovdqu (%r12,%r10,2),%ymm1
 1123ec3:	vpshufb %ymm2,%ymm1,%ymm1
 1123ec8:	vpermq $0x4e,%ymm1,%ymm1
 1123ece:	vmovdqu %ymm1,-0x20(%r12,%r11,2)
 1123ed5:	vpshufb %ymm2,%ymm0,%ymm0
 1123eda:	vpermq $0x4e,%ymm0,%ymm0
 1123ee0:	vmovdqu %ymm0,(%r12,%r10,2)
 1123ee6:	add    $0x10,%r10
 1123eea:	add    $0xfffffffffffffff0,%r9
 1123eee:	mov    %r8,%r11
 1123ef1:	add    %r9,%r11
 1123ef4:	jne    1123eb0 <sort.block.block__anon_39129+0x6b70>
 1123ef6:	sub    %r9,%rsi
 1123ef9:	mov    %rsi,%r8
 1123efc:	sub    %rdx,%r8
 1123eff:	jae    1124068 <sort.block.block__anon_39129+0x6d28>
 1123f05:	lea    (%r12,%rdi,2),%rdi
 1123f09:	mov    %edx,%r9d
 1123f0c:	sub    %esi,%r9d
 1123f0f:	and    $0x3,%r9d
 1123f13:	je     1123f7b <sort.block.block__anon_39129+0x6c3b>
 1123f15:	mov    %r13,-0x60(%rbp)
 1123f19:	neg    %r9
 1123f1c:	xor    %r10d,%r10d
 1123f1f:	mov    %rsi,%r11
 1123f22:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1123f30:	mov    %r11,%rbx
 1123f33:	not    %rbx
 1123f36:	movzbl (%r12,%r11,2),%r15d
 1123f3b:	movzbl (%rdi,%rbx,2),%r13d
 1123f40:	mov    %r13b,(%r12,%r11,2)
 1123f44:	mov    %r15b,(%rdi,%rbx,2)
 1123f48:	movzbl 0x1(%r12,%r11,2),%r15d
 1123f4e:	movzbl 0x1(%rdi,%rbx,2),%r13d
 1123f54:	mov    %r13b,0x1(%r12,%r11,2)
 1123f59:	mov    %r15b,0x1(%rdi,%rbx,2)
 1123f5e:	inc    %r11
 1123f61:	dec    %r10
 1123f64:	cmp    %r10,%r9
 1123f67:	jne    1123f30 <sort.block.block__anon_39129+0x6bf0>
 1123f69:	sub    %r10,%rsi
 1123f6c:	mov    -0x88(%rbp),%r15
 1123f73:	mov    -0x40(%rbp),%rbx
 1123f77:	mov    -0x60(%rbp),%r13
 1123f7b:	cmp    $0xfffffffffffffffc,%r8
 1123f7f:	ja     1124068 <sort.block.block__anon_39129+0x6d28>
 1123f85:	sub    %rsi,%rdx
 1123f88:	nopl   0x0(%rax,%rax,1)
 1123f90:	mov    %rsi,%r8
 1123f93:	not    %r8
 1123f96:	movzbl (%r12,%rsi,2),%r9d
 1123f9b:	movzbl (%rdi,%r8,2),%r10d
 1123fa0:	mov    %r10b,(%r12,%rsi,2)
 1123fa4:	mov    %r9b,(%rdi,%r8,2)
 1123fa8:	movzbl 0x1(%r12,%rsi,2),%r9d
 1123fae:	movzbl 0x1(%rdi,%r8,2),%r10d
 1123fb4:	mov    %r10b,0x1(%r12,%rsi,2)
 1123fb9:	mov    %r9b,0x1(%rdi,%r8,2)
 1123fbe:	mov    $0xfffffffffffffffe,%r8
 1123fc5:	sub    %rsi,%r8
 1123fc8:	movzbl 0x2(%r12,%rsi,2),%r9d
 1123fce:	movzbl (%rdi,%r8,2),%r10d
 1123fd3:	mov    %r10b,0x2(%r12,%rsi,2)
 1123fd8:	mov    %r9b,(%rdi,%r8,2)
 1123fdc:	movzbl 0x3(%r12,%rsi,2),%r9d
 1123fe2:	movzbl 0x1(%rdi,%r8,2),%r10d
 1123fe8:	mov    %r10b,0x3(%r12,%rsi,2)
 1123fed:	mov    %r9b,0x1(%rdi,%r8,2)
 1123ff2:	mov    $0xfffffffffffffffd,%r8
 1123ff9:	sub    %rsi,%r8
 1123ffc:	movzbl 0x4(%r12,%rsi,2),%r9d
 1124002:	movzbl (%rdi,%r8,2),%r10d
 1124007:	mov    %r10b,0x4(%r12,%rsi,2)
 112400c:	mov    %r9b,(%rdi,%r8,2)
 1124010:	movzbl 0x5(%r12,%rsi,2),%r9d
 1124016:	movzbl 0x1(%rdi,%r8,2),%r10d
 112401c:	mov    %r10b,0x5(%r12,%rsi,2)
 1124021:	mov    %r9b,0x1(%rdi,%r8,2)
 1124026:	mov    $0xfffffffffffffffc,%r8
 112402d:	sub    %rsi,%r8
 1124030:	movzbl 0x6(%r12,%rsi,2),%r9d
 1124036:	movzbl (%rdi,%r8,2),%r10d
 112403b:	mov    %r10b,0x6(%r12,%rsi,2)
 1124040:	mov    %r9b,(%rdi,%r8,2)
 1124044:	movzbl 0x7(%r12,%rsi,2),%r9d
 112404a:	movzbl 0x1(%rdi,%r8,2),%r10d
 1124050:	mov    %r10b,0x7(%r12,%rsi,2)
 1124055:	mov    %r9b,0x1(%rdi,%r8,2)
 112405a:	add    $0x4,%rsi
 112405e:	add    $0xfffffffffffffffc,%rdx
 1124062:	jne    1123f90 <sort.block.block__anon_39129+0x6c50>
 1124068:	mov    %rcx,%rdx
 112406b:	shr    %rdx
 112406e:	cmp    $0x20,%rcx
 1124072:	setb   %sil
 1124076:	cmp    $0xf,%rdx
 112407a:	sete   %dil
 112407e:	or     %sil,%dil
 1124081:	je     11240a0 <sort.block.block__anon_39129+0x6d60>
 1124083:	xor    %esi,%esi
 1124085:	mov    -0xe8(%rbp),%r12
 112408c:	jmp    1124240 <sort.block.block__anon_39129+0x6f00>
 1124091:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11240a0:	lea    -0x10(%rdx),%rsi
 11240a4:	mov    %rsi,%rdi
 11240a7:	shr    $0x4,%rdi
 11240ab:	inc    %rdi
 11240ae:	cmp    $0x30,%rsi
 11240b2:	mov    -0xe8(%rbp),%r12
 11240b9:	jae    11240c3 <sort.block.block__anon_39129+0x6d83>
 11240bb:	xor    %r10d,%r10d
 11240be:	jmp    11241f0 <sort.block.block__anon_39129+0x6eb0>
 11240c3:	mov    %rdi,%rsi
 11240c6:	movabs $0x1ffffffffffffffc,%r8
 11240d0:	and    %r8,%rsi
 11240d3:	mov    -0xc8(%rbp),%r8
 11240da:	lea    (%r8,%r14,2),%r8
 11240de:	xor    %r9d,%r9d
 11240e1:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11240f0:	mov    %r9,%r10
 11240f3:	mov    %rcx,%r11
 11240f6:	sub    %r9,%r11
 11240f9:	vmovdqu -0x20(%rax,%r11,2),%ymm0
 1124100:	vmovdqu -0x60(%r8,%r9,2),%ymm1
 1124107:	vpshufb %ymm2,%ymm1,%ymm1
 112410c:	vpermq $0x4e,%ymm1,%ymm1
 1124112:	vmovdqu %ymm1,-0x20(%rax,%r11,2)
 1124119:	or     $0x10,%r10
 112411d:	vpshufb %ymm2,%ymm0,%ymm0
 1124122:	vpermq $0x4e,%ymm0,%ymm0
 1124128:	vmovdqu %ymm0,-0x60(%r8,%r9,2)
 112412f:	mov    %r9,%r11
 1124132:	mov    %rcx,%rbx
 1124135:	sub    %r10,%rbx
 1124138:	vmovdqu -0x20(%rax,%rbx,2),%ymm0
 112413e:	vmovdqu -0x40(%r8,%r9,2),%ymm1
 1124145:	vpshufb %ymm2,%ymm1,%ymm1
 112414a:	vpermq $0x4e,%ymm1,%ymm1
 1124150:	vmovdqu %ymm1,-0x20(%rax,%rbx,2)
 1124156:	or     $0x20,%r11
 112415a:	vpshufb %ymm2,%ymm0,%ymm0
 112415f:	vpermq $0x4e,%ymm0,%ymm0
 1124165:	vmovdqu %ymm0,-0x40(%r8,%r9,2)
 112416c:	mov    %r9,%r10
 112416f:	mov    %rcx,%rbx
 1124172:	sub    %r11,%rbx
 1124175:	vmovdqu -0x20(%rax,%rbx,2),%ymm0
 112417b:	vmovdqu -0x20(%r8,%r9,2),%ymm1
 1124182:	vpshufb %ymm2,%ymm1,%ymm1
 1124187:	vpermq $0x4e,%ymm1,%ymm1
 112418d:	vmovdqu %ymm1,-0x20(%rax,%rbx,2)
 1124193:	or     $0x30,%r10
 1124197:	vpshufb %ymm2,%ymm0,%ymm0
 112419c:	vpermq $0x4e,%ymm0,%ymm0
 11241a2:	vmovdqu %ymm0,-0x20(%r8,%r9,2)
 11241a9:	mov    %rcx,%r11
 11241ac:	sub    %r10,%r11
 11241af:	vmovdqu -0x20(%rax,%r11,2),%ymm0
 11241b6:	vmovdqu (%r8,%r9,2),%ymm1
 11241bc:	vpshufb %ymm2,%ymm1,%ymm1
 11241c1:	vpermq $0x4e,%ymm1,%ymm1
 11241c7:	vmovdqu %ymm1,-0x20(%rax,%r11,2)
 11241ce:	lea    0x40(%r9),%r10
 11241d2:	vpshufb %ymm2,%ymm0,%ymm0
 11241d7:	vpermq $0x4e,%ymm0,%ymm0
 11241dd:	vmovdqu %ymm0,(%r8,%r9,2)
 11241e3:	mov    %r10,%r9
 11241e6:	add    $0xfffffffffffffffc,%rsi
 11241ea:	jne    11240f0 <sort.block.block__anon_39129+0x6db0>
 11241f0:	mov    %r10,%rsi
 11241f3:	and    $0x3,%edi
 11241f6:	mov    -0x40(%rbp),%rbx
 11241fa:	je     1124240 <sort.block.block__anon_39129+0x6f00>
 11241fc:	nopl   0x0(%rax)
 1124200:	mov    %rcx,%rsi
 1124203:	sub    %r10,%rsi
 1124206:	vmovdqu -0x20(%rax,%rsi,2),%ymm0
 112420c:	vmovdqu (%rax,%r10,2),%ymm1
 1124212:	vpshufb %ymm2,%ymm1,%ymm1
 1124217:	vpermq $0x4e,%ymm1,%ymm1
 112421d:	vmovdqu %ymm1,-0x20(%rax,%rsi,2)
 1124223:	lea    0x10(%r10),%rsi
 1124227:	vpshufb %ymm2,%ymm0,%ymm0
 112422c:	vpermq $0x4e,%ymm0,%ymm0
 1124232:	vmovdqu %ymm0,(%rax,%r10,2)
 1124238:	mov    %rsi,%r10
 112423b:	dec    %rdi
 112423e:	jne    1124200 <sort.block.block__anon_39129+0x6ec0>
 1124240:	mov    %rsi,%rcx
 1124243:	sub    %rdx,%rcx
 1124246:	mov    -0x38(%rbp),%r10
 112424a:	jae    11225b0 <sort.block.block__anon_39129+0x5270>
 1124250:	mov    -0x78(%rbp),%rax
 1124254:	lea    (%r10,%rax,2),%rax
 1124258:	mov    %edx,%edi
 112425a:	sub    %esi,%edi
 112425c:	and    $0x3,%edi
 112425f:	je     11242a6 <sort.block.block__anon_39129+0x6f66>
 1124261:	mov    -0x50(%rbp),%r8
 1124265:	lea    (%r8,%r14,2),%r8
 1124269:	nopl   0x0(%rax)
 1124270:	mov    %rsi,%r9
 1124273:	not    %r9
 1124276:	movzbl -0x1(%r8,%rsi,2),%r10d
 112427c:	movzbl (%rax,%r9,2),%r11d
 1124281:	mov    %r11b,-0x1(%r8,%rsi,2)
 1124286:	mov    %r10b,(%rax,%r9,2)
 112428a:	movzbl (%r8,%rsi,2),%r10d
 112428f:	movzbl 0x1(%rax,%r9,2),%r11d
 1124295:	mov    %r11b,(%r8,%rsi,2)
 1124299:	mov    %r10b,0x1(%rax,%r9,2)
 112429e:	inc    %rsi
 11242a1:	dec    %rdi
 11242a4:	jne    1124270 <sort.block.block__anon_39129+0x6f30>
 11242a6:	cmp    $0xfffffffffffffffc,%rcx
 11242aa:	mov    -0x38(%rbp),%r10
 11242ae:	ja     11225b0 <sort.block.block__anon_39129+0x5270>
 11242b4:	mov    -0x80(%rbp),%rcx
 11242b8:	lea    (%rcx,%r14,2),%rcx
 11242bc:	nopl   0x0(%rax)
 11242c0:	mov    %rsi,%rdi
 11242c3:	not    %rdi
 11242c6:	movzbl -0x7(%rcx,%rsi,2),%r8d
 11242cc:	movzbl (%rax,%rdi,2),%r9d
 11242d1:	mov    %r9b,-0x7(%rcx,%rsi,2)
 11242d6:	mov    %r8b,(%rax,%rdi,2)
 11242da:	movzbl -0x6(%rcx,%rsi,2),%r8d
 11242e0:	movzbl 0x1(%rax,%rdi,2),%r9d
 11242e6:	mov    %r9b,-0x6(%rcx,%rsi,2)
 11242eb:	mov    %r8b,0x1(%rax,%rdi,2)
 11242f0:	mov    $0xfffffffffffffffe,%rdi
 11242f7:	sub    %rsi,%rdi
 11242fa:	movzbl -0x5(%rcx,%rsi,2),%r8d
 1124300:	movzbl (%rax,%rdi,2),%r9d
 1124305:	mov    %r9b,-0x5(%rcx,%rsi,2)
 112430a:	mov    %r8b,(%rax,%rdi,2)
 112430e:	movzbl -0x4(%rcx,%rsi,2),%r8d
 1124314:	movzbl 0x1(%rax,%rdi,2),%r9d
 112431a:	mov    %r9b,-0x4(%rcx,%rsi,2)
 112431f:	mov    %r8b,0x1(%rax,%rdi,2)
 1124324:	mov    $0xfffffffffffffffd,%rdi
 112432b:	sub    %rsi,%rdi
 112432e:	movzbl -0x3(%rcx,%rsi,2),%r8d
 1124334:	movzbl (%rax,%rdi,2),%r9d
 1124339:	mov    %r9b,-0x3(%rcx,%rsi,2)
 112433e:	mov    %r8b,(%rax,%rdi,2)
 1124342:	movzbl -0x2(%rcx,%rsi,2),%r8d
 1124348:	movzbl 0x1(%rax,%rdi,2),%r9d
 112434e:	mov    %r9b,-0x2(%rcx,%rsi,2)
 1124353:	mov    %r8b,0x1(%rax,%rdi,2)
 1124358:	mov    $0xfffffffffffffffc,%rdi
 112435f:	sub    %rsi,%rdi
 1124362:	movzbl -0x1(%rcx,%rsi,2),%r8d
 1124368:	movzbl (%rax,%rdi,2),%r9d
 112436d:	mov    %r9b,-0x1(%rcx,%rsi,2)
 1124372:	mov    %r8b,(%rax,%rdi,2)
 1124376:	movzbl (%rcx,%rsi,2),%r8d
 112437b:	movzbl 0x1(%rax,%rdi,2),%r9d
 1124381:	mov    %r9b,(%rcx,%rsi,2)
 1124385:	mov    %r8b,0x1(%rax,%rdi,2)
 112438a:	add    $0x4,%rsi
 112438e:	cmp    %rsi,%rdx
 1124391:	jne    11242c0 <sort.block.block__anon_39129+0x6f80>
 1124397:	jmp    11225b0 <sort.block.block__anon_39129+0x5270>
 112439c:	lea    -0x10(%rdx),%rdi
 11243a0:	mov    %rdi,%r8
 11243a3:	shr    $0x4,%r8
 11243a7:	inc    %r8
 11243aa:	cmp    $0x30,%rdi
 11243ae:	jae    11243b7 <sort.block.block__anon_39129+0x7077>
 11243b0:	xor    %edi,%edi
 11243b2:	jmp    11244d0 <sort.block.block__anon_39129+0x7190>
 11243b7:	mov    %r8,%r9
 11243ba:	movabs $0x1ffffffffffffffc,%rdi
 11243c4:	and    %rdi,%r9
 11243c7:	xor    %r10d,%r10d
 11243ca:	nopw   0x0(%rax,%rax,1)
 11243d0:	mov    %r10,%rdi
 11243d3:	mov    %rsi,%r11
 11243d6:	sub    %r10,%r11
 11243d9:	vmovdqu -0x20(%rax,%r11,2),%ymm0
 11243e0:	vmovdqu (%rax,%r10,2),%ymm1
 11243e6:	vpshufb %ymm2,%ymm1,%ymm1
 11243eb:	vpermq $0x4e,%ymm1,%ymm1
 11243f1:	vmovdqu %ymm1,-0x20(%rax,%r11,2)
 11243f8:	or     $0x10,%rdi
 11243fc:	vpshufb %ymm2,%ymm0,%ymm0
 1124401:	vpermq $0x4e,%ymm0,%ymm0
 1124407:	vmovdqu %ymm0,(%rax,%r10,2)
 112440d:	mov    %r10,%r11
 1124410:	mov    %rsi,%rbx
 1124413:	sub    %rdi,%rbx
 1124416:	vmovdqu -0x20(%rax,%rbx,2),%ymm0
 112441c:	vmovdqu 0x20(%rax,%r10,2),%ymm1
 1124423:	vpshufb %ymm2,%ymm1,%ymm1
 1124428:	vpermq $0x4e,%ymm1,%ymm1
 112442e:	vmovdqu %ymm1,-0x20(%rax,%rbx,2)
 1124434:	or     $0x20,%r11
 1124438:	vpshufb %ymm2,%ymm0,%ymm0
 112443d:	vpermq $0x4e,%ymm0,%ymm0
 1124443:	vmovdqu %ymm0,0x20(%rax,%r10,2)
 112444a:	mov    %r10,%rdi
 112444d:	mov    %rsi,%rbx
 1124450:	sub    %r11,%rbx
 1124453:	vmovdqu -0x20(%rax,%rbx,2),%ymm0
 1124459:	vmovdqu 0x40(%rax,%r10,2),%ymm1
 1124460:	vpshufb %ymm2,%ymm1,%ymm1
 1124465:	vpermq $0x4e,%ymm1,%ymm1
 112446b:	vmovdqu %ymm1,-0x20(%rax,%rbx,2)
 1124471:	or     $0x30,%rdi
 1124475:	vpshufb %ymm2,%ymm0,%ymm0
 112447a:	vpermq $0x4e,%ymm0,%ymm0
 1124480:	vmovdqu %ymm0,0x40(%rax,%r10,2)
 1124487:	mov    %rsi,%r11
 112448a:	sub    %rdi,%r11
 112448d:	vmovdqu -0x20(%rax,%r11,2),%ymm0
 1124494:	vmovdqu 0x60(%rax,%r10,2),%ymm1
 112449b:	vpshufb %ymm2,%ymm1,%ymm1
 11244a0:	vpermq $0x4e,%ymm1,%ymm1
 11244a6:	vmovdqu %ymm1,-0x20(%rax,%r11,2)
 11244ad:	lea    0x40(%r10),%rdi
 11244b1:	vpshufb %ymm2,%ymm0,%ymm0
 11244b6:	vpermq $0x4e,%ymm0,%ymm0
 11244bc:	vmovdqu %ymm0,0x60(%rax,%r10,2)
 11244c3:	mov    %rdi,%r10
 11244c6:	add    $0xfffffffffffffffc,%r9
 11244ca:	jne    11243d0 <sort.block.block__anon_39129+0x7090>
 11244d0:	and    $0x3,%r8d
 11244d4:	mov    -0x40(%rbp),%rbx
 11244d8:	je     1124539 <sort.block.block__anon_39129+0x71f9>
 11244da:	shl    $0x4,%r8d
 11244de:	xor    %r9d,%r9d
 11244e1:	mov    %rdi,%r10
 11244e4:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 11244f0:	mov    %rsi,%r11
 11244f3:	sub    %r10,%r11
 11244f6:	vmovdqu -0x20(%rax,%r11,2),%ymm0
 11244fd:	vmovdqu (%rax,%r10,2),%ymm1
 1124503:	vpshufb %ymm2,%ymm1,%ymm1
 1124508:	vpermq $0x4e,%ymm1,%ymm1
 112450e:	vmovdqu %ymm1,-0x20(%rax,%r11,2)
 1124515:	vpshufb %ymm2,%ymm0,%ymm0
 112451a:	vpermq $0x4e,%ymm0,%ymm0
 1124520:	vmovdqu %ymm0,(%rax,%r10,2)
 1124526:	add    $0x10,%r10
 112452a:	add    $0xfffffffffffffff0,%r9
 112452e:	mov    %r8,%r11
 1124531:	add    %r9,%r11
 1124534:	jne    11244f0 <sort.block.block__anon_39129+0x71b0>
 1124536:	sub    %r9,%rdi
 1124539:	mov    %rdi,%r8
 112453c:	sub    %rdx,%r8
 112453f:	jae    11246a8 <sort.block.block__anon_39129+0x7368>
 1124545:	mov    %edx,%r9d
 1124548:	sub    %edi,%r9d
 112454b:	and    $0x3,%r9d
 112454f:	je     11245bb <sort.block.block__anon_39129+0x727b>
 1124551:	neg    %r9
 1124554:	xor    %r10d,%r10d
 1124557:	mov    %rdi,%r11
 112455a:	nopw   0x0(%rax,%rax,1)
 1124560:	mov    %r11,%rbx
 1124563:	not    %rbx
 1124566:	movzbl (%rax,%r11,2),%r14d
 112456b:	mov    -0x70(%rbp),%rcx
 112456f:	movzbl (%rcx,%rbx,2),%r15d
 1124574:	mov    %r15b,(%rax,%r11,2)
 1124578:	mov    -0x70(%rbp),%rcx
 112457c:	mov    %r14b,(%rcx,%rbx,2)
 1124580:	movzbl 0x1(%rax,%r11,2),%r14d
 1124586:	mov    -0x70(%rbp),%rcx
 112458a:	movzbl 0x1(%rcx,%rbx,2),%r15d
 1124590:	mov    %r15b,0x1(%rax,%r11,2)
 1124595:	mov    -0x70(%rbp),%rcx
 1124599:	mov    %r14b,0x1(%rcx,%rbx,2)
 112459e:	mov    -0x70(%rbp),%r14
 11245a2:	inc    %r11
 11245a5:	dec    %r10
 11245a8:	cmp    %r10,%r9
 11245ab:	jne    1124560 <sort.block.block__anon_39129+0x7220>
 11245ad:	sub    %r10,%rdi
 11245b0:	mov    -0x88(%rbp),%r15
 11245b7:	mov    -0x40(%rbp),%rbx
 11245bb:	cmp    $0xfffffffffffffffc,%r8
 11245bf:	ja     11246a8 <sort.block.block__anon_39129+0x7368>
 11245c5:	sub    %rdi,%rdx
 11245c8:	nopl   0x0(%rax,%rax,1)
 11245d0:	mov    %rdi,%r8
 11245d3:	not    %r8
 11245d6:	movzbl (%rax,%rdi,2),%r9d
 11245db:	movzbl (%r14,%r8,2),%r10d
 11245e0:	mov    %r10b,(%rax,%rdi,2)
 11245e4:	mov    %r9b,(%r14,%r8,2)
 11245e8:	movzbl 0x1(%rax,%rdi,2),%r9d
 11245ee:	movzbl 0x1(%r14,%r8,2),%r10d
 11245f4:	mov    %r10b,0x1(%rax,%rdi,2)
 11245f9:	mov    %r9b,0x1(%r14,%r8,2)
 11245fe:	mov    $0xfffffffffffffffe,%r8
 1124605:	sub    %rdi,%r8
 1124608:	movzbl 0x2(%rax,%rdi,2),%r9d
 112460e:	movzbl (%r14,%r8,2),%r10d
 1124613:	mov    %r10b,0x2(%rax,%rdi,2)
 1124618:	mov    %r9b,(%r14,%r8,2)
 112461c:	movzbl 0x3(%rax,%rdi,2),%r9d
 1124622:	movzbl 0x1(%r14,%r8,2),%r10d
 1124628:	mov    %r10b,0x3(%rax,%rdi,2)
 112462d:	mov    %r9b,0x1(%r14,%r8,2)
 1124632:	mov    $0xfffffffffffffffd,%r8
 1124639:	sub    %rdi,%r8
 112463c:	movzbl 0x4(%rax,%rdi,2),%r9d
 1124642:	movzbl (%r14,%r8,2),%r10d
 1124647:	mov    %r10b,0x4(%rax,%rdi,2)
 112464c:	mov    %r9b,(%r14,%r8,2)
 1124650:	movzbl 0x5(%rax,%rdi,2),%r9d
 1124656:	movzbl 0x1(%r14,%r8,2),%r10d
 112465c:	mov    %r10b,0x5(%rax,%rdi,2)
 1124661:	mov    %r9b,0x1(%r14,%r8,2)
 1124666:	mov    $0xfffffffffffffffc,%r8
 112466d:	sub    %rdi,%r8
 1124670:	movzbl 0x6(%rax,%rdi,2),%r9d
 1124676:	movzbl (%r14,%r8,2),%r10d
 112467b:	mov    %r10b,0x6(%rax,%rdi,2)
 1124680:	mov    %r9b,(%r14,%r8,2)
 1124684:	movzbl 0x7(%rax,%rdi,2),%r9d
 112468a:	movzbl 0x1(%r14,%r8,2),%r10d
 1124690:	mov    %r10b,0x7(%rax,%rdi,2)
 1124695:	mov    %r9b,0x1(%r14,%r8,2)
 112469a:	add    $0x4,%rdi
 112469e:	add    $0xfffffffffffffffc,%rdx
 11246a2:	jne    11245d0 <sort.block.block__anon_39129+0x7290>
 11246a8:	mov    -0xd8(%rbp),%rdx
 11246af:	sub    %rbx,%rdx
 11246b2:	mov    %rdx,%r8
 11246b5:	sub    %rsi,%r8
 11246b8:	mov    %r8,%rsi
 11246bb:	shr    %rsi
 11246be:	cmp    $0x20,%r8
 11246c2:	setb   %dil
 11246c6:	cmp    $0xf,%rsi
 11246ca:	sete   %r9b
 11246ce:	or     %dil,%r9b
 11246d1:	je     11246da <sort.block.block__anon_39129+0x739a>
 11246d3:	xor    %edi,%edi
 11246d5:	jmp    112489d <sort.block.block__anon_39129+0x755d>
 11246da:	lea    -0x10(%rsi),%rdi
 11246de:	mov    %rdi,%r9
 11246e1:	shr    $0x4,%r9
 11246e5:	inc    %r9
 11246e8:	cmp    $0x30,%rdi
 11246ec:	jae    11246f5 <sort.block.block__anon_39129+0x73b5>
 11246ee:	xor    %edi,%edi
 11246f0:	jmp    1124834 <sort.block.block__anon_39129+0x74f4>
 11246f5:	mov    %r9,%r10
 11246f8:	movabs $0x1ffffffffffffffc,%rdi
 1124702:	and    %rdi,%r10
 1124705:	xor    %r11d,%r11d
 1124708:	nopl   0x0(%rax,%rax,1)
 1124710:	mov    %r11,%rdi
 1124713:	mov    %r8,%rbx
 1124716:	sub    %r11,%rbx
 1124719:	vmovdqu -0x20(%r14,%rbx,2),%ymm0
 1124720:	vmovdqu (%r14,%r11,2),%ymm1
 1124726:	vpshufb %ymm2,%ymm1,%ymm1
 112472b:	vpermq $0x4e,%ymm1,%ymm1
 1124731:	vmovdqu %ymm1,-0x20(%r14,%rbx,2)
 1124738:	or     $0x10,%rdi
 112473c:	vpshufb %ymm2,%ymm0,%ymm0
 1124741:	vpermq $0x4e,%ymm0,%ymm0
 1124747:	vmovdqu %ymm0,(%r14,%r11,2)
 112474d:	mov    %r11,%rbx
 1124750:	mov    %r8,%r14
 1124753:	sub    %rdi,%r14
 1124756:	mov    -0x70(%rbp),%rcx
 112475a:	vmovdqu -0x20(%rcx,%r14,2),%ymm0
 1124761:	mov    -0x70(%rbp),%rcx
 1124765:	vmovdqu 0x20(%rcx,%r11,2),%ymm1
 112476c:	vpshufb %ymm2,%ymm1,%ymm1
 1124771:	vpermq $0x4e,%ymm1,%ymm1
 1124777:	mov    -0x70(%rbp),%rcx
 112477b:	vmovdqu %ymm1,-0x20(%rcx,%r14,2)
 1124782:	or     $0x20,%rbx
 1124786:	vpshufb %ymm2,%ymm0,%ymm0
 112478b:	vpermq $0x4e,%ymm0,%ymm0
 1124791:	mov    -0x70(%rbp),%rcx
 1124795:	vmovdqu %ymm0,0x20(%rcx,%r11,2)
 112479c:	mov    %r11,%rdi
 112479f:	mov    %r8,%r14
 11247a2:	sub    %rbx,%r14
 11247a5:	mov    -0x70(%rbp),%rcx
 11247a9:	vmovdqu -0x20(%rcx,%r14,2),%ymm0
 11247b0:	mov    -0x70(%rbp),%rcx
 11247b4:	vmovdqu 0x40(%rcx,%r11,2),%ymm1
 11247bb:	vpshufb %ymm2,%ymm1,%ymm1
 11247c0:	vpermq $0x4e,%ymm1,%ymm1
 11247c6:	mov    -0x70(%rbp),%rcx
 11247ca:	vmovdqu %ymm1,-0x20(%rcx,%r14,2)
 11247d1:	mov    -0x70(%rbp),%r14
 11247d5:	or     $0x30,%rdi
 11247d9:	vpshufb %ymm2,%ymm0,%ymm0
 11247de:	vpermq $0x4e,%ymm0,%ymm0
 11247e4:	vmovdqu %ymm0,0x40(%r14,%r11,2)
 11247eb:	mov    %r8,%rbx
 11247ee:	sub    %rdi,%rbx
 11247f1:	vmovdqu -0x20(%r14,%rbx,2),%ymm0
 11247f8:	vmovdqu 0x60(%r14,%r11,2),%ymm1
 11247ff:	vpshufb %ymm2,%ymm1,%ymm1
 1124804:	vpermq $0x4e,%ymm1,%ymm1
 112480a:	vmovdqu %ymm1,-0x20(%r14,%rbx,2)
 1124811:	lea    0x40(%r11),%rdi
 1124815:	vpshufb %ymm2,%ymm0,%ymm0
 112481a:	vpermq $0x4e,%ymm0,%ymm0
 1124820:	vmovdqu %ymm0,0x60(%r14,%r11,2)
 1124827:	mov    %rdi,%r11
 112482a:	add    $0xfffffffffffffffc,%r10
 112482e:	jne    1124710 <sort.block.block__anon_39129+0x73d0>
 1124834:	and    $0x3,%r9d
 1124838:	mov    -0x40(%rbp),%rbx
 112483c:	je     112489d <sort.block.block__anon_39129+0x755d>
 112483e:	shl    $0x4,%r9d
 1124842:	xor    %r10d,%r10d
 1124845:	mov    %rdi,%r11
 1124848:	nopl   0x0(%rax,%rax,1)
 1124850:	mov    %r8,%rbx
 1124853:	sub    %r11,%rbx
 1124856:	vmovdqu -0x20(%r14,%rbx,2),%ymm0
 112485d:	vmovdqu (%r14,%r11,2),%ymm1
 1124863:	vpshufb %ymm2,%ymm1,%ymm1
 1124868:	vpermq $0x4e,%ymm1,%ymm1
 112486e:	vmovdqu %ymm1,-0x20(%r14,%rbx,2)
 1124875:	vpshufb %ymm2,%ymm0,%ymm0
 112487a:	vpermq $0x4e,%ymm0,%ymm0
 1124880:	vmovdqu %ymm0,(%r14,%r11,2)
 1124886:	add    $0x10,%r11
 112488a:	add    $0xfffffffffffffff0,%r10
 112488e:	mov    %r9,%rbx
 1124891:	add    %r10,%rbx
 1124894:	jne    1124850 <sort.block.block__anon_39129+0x7510>
 1124896:	sub    %r10,%rdi
 1124899:	mov    -0x40(%rbp),%rbx
 112489d:	mov    %rdi,%r9
 11248a0:	sub    %rsi,%r9
 11248a3:	jae    1124a08 <sort.block.block__anon_39129+0x76c8>
 11248a9:	lea    (%r14,%r8,2),%r8
 11248ad:	mov    %esi,%r10d
 11248b0:	sub    %edi,%r10d
 11248b3:	and    $0x3,%r10d
 11248b7:	je     1124921 <sort.block.block__anon_39129+0x75e1>
 11248b9:	neg    %r10
 11248bc:	xor    %r11d,%r11d
 11248bf:	mov    %rdi,%rbx
 11248c2:	mov    %r14,%rcx
 11248c5:	data16 cs nopw 0x0(%rax,%rax,1)
 11248d0:	mov    %rbx,%r14
 11248d3:	not    %r14
 11248d6:	movzbl (%rcx,%rbx,2),%r15d
 11248db:	movzbl (%r8,%r14,2),%r12d
 11248e0:	mov    %r12b,(%rcx,%rbx,2)
 11248e4:	mov    %r15b,(%r8,%r14,2)
 11248e8:	movzbl 0x1(%rcx,%rbx,2),%r15d
 11248ee:	movzbl 0x1(%r8,%r14,2),%r12d
 11248f4:	mov    %r12b,0x1(%rcx,%rbx,2)
 11248f9:	mov    %r15b,0x1(%r8,%r14,2)
 11248fe:	inc    %rbx
 1124901:	dec    %r11
 1124904:	cmp    %r11,%r10
 1124907:	jne    11248d0 <sort.block.block__anon_39129+0x7590>
 1124909:	sub    %r11,%rdi
 112490c:	mov    -0x88(%rbp),%r15
 1124913:	mov    -0xe8(%rbp),%r12
 112491a:	mov    -0x40(%rbp),%rbx
 112491e:	mov    %rcx,%r14
 1124921:	cmp    $0xfffffffffffffffc,%r9
 1124925:	ja     1124a08 <sort.block.block__anon_39129+0x76c8>
 112492b:	sub    %rdi,%rsi
 112492e:	xchg   %ax,%ax
 1124930:	mov    %rdi,%r9
 1124933:	not    %r9
 1124936:	movzbl (%r14,%rdi,2),%r10d
 112493b:	movzbl (%r8,%r9,2),%r11d
 1124940:	mov    %r11b,(%r14,%rdi,2)
 1124944:	mov    %r10b,(%r8,%r9,2)
 1124948:	movzbl 0x1(%r14,%rdi,2),%r10d
 112494e:	movzbl 0x1(%r8,%r9,2),%r11d
 1124954:	mov    %r11b,0x1(%r14,%rdi,2)
 1124959:	mov    %r10b,0x1(%r8,%r9,2)
 112495e:	mov    $0xfffffffffffffffe,%r9
 1124965:	sub    %rdi,%r9
 1124968:	movzbl 0x2(%r14,%rdi,2),%r10d
 112496e:	movzbl (%r8,%r9,2),%r11d
 1124973:	mov    %r11b,0x2(%r14,%rdi,2)
 1124978:	mov    %r10b,(%r8,%r9,2)
 112497c:	movzbl 0x3(%r14,%rdi,2),%r10d
 1124982:	movzbl 0x1(%r8,%r9,2),%r11d
 1124988:	mov    %r11b,0x3(%r14,%rdi,2)
 112498d:	mov    %r10b,0x1(%r8,%r9,2)
 1124992:	mov    $0xfffffffffffffffd,%r9
 1124999:	sub    %rdi,%r9
 112499c:	movzbl 0x4(%r14,%rdi,2),%r10d
 11249a2:	movzbl (%r8,%r9,2),%r11d
 11249a7:	mov    %r11b,0x4(%r14,%rdi,2)
 11249ac:	mov    %r10b,(%r8,%r9,2)
 11249b0:	movzbl 0x5(%r14,%rdi,2),%r10d
 11249b6:	movzbl 0x1(%r8,%r9,2),%r11d
 11249bc:	mov    %r11b,0x5(%r14,%rdi,2)
 11249c1:	mov    %r10b,0x1(%r8,%r9,2)
 11249c6:	mov    $0xfffffffffffffffc,%r9
 11249cd:	sub    %rdi,%r9
 11249d0:	movzbl 0x6(%r14,%rdi,2),%r10d
 11249d6:	movzbl (%r8,%r9,2),%r11d
 11249db:	mov    %r11b,0x6(%r14,%rdi,2)
 11249e0:	mov    %r10b,(%r8,%r9,2)
 11249e4:	movzbl 0x7(%r14,%rdi,2),%r10d
 11249ea:	movzbl 0x1(%r8,%r9,2),%r11d
 11249f0:	mov    %r11b,0x7(%r14,%rdi,2)
 11249f5:	mov    %r10b,0x1(%r8,%r9,2)
 11249fa:	add    $0x4,%rdi
 11249fe:	add    $0xfffffffffffffffc,%rsi
 1124a02:	jne    1124930 <sort.block.block__anon_39129+0x75f0>
 1124a08:	mov    %rdx,%rsi
 1124a0b:	shr    %rsi
 1124a0e:	cmp    $0x20,%rdx
 1124a12:	setb   %dl
 1124a15:	cmp    $0xf,%rsi
 1124a19:	sete   %dil
 1124a1d:	or     %dl,%dil
 1124a20:	je     1124a30 <sort.block.block__anon_39129+0x76f0>
 1124a22:	xor    %edx,%edx
 1124a24:	mov    -0x90(%rbp),%r11
 1124a2b:	jmp    1124bc4 <sort.block.block__anon_39129+0x7884>
 1124a30:	lea    -0x10(%rsi),%rdx
 1124a34:	mov    %rdx,%rdi
 1124a37:	shr    $0x4,%rdi
 1124a3b:	inc    %rdi
 1124a3e:	cmp    $0x30,%rdx
 1124a42:	mov    -0x90(%rbp),%r11
 1124a49:	jae    1124a5b <sort.block.block__anon_39129+0x771b>
 1124a4b:	xor    %edx,%edx
 1124a4d:	and    $0x3,%edi
 1124a50:	jne    1124b5e <sort.block.block__anon_39129+0x781e>
 1124a56:	jmp    1124bc4 <sort.block.block__anon_39129+0x7884>
 1124a5b:	mov    %rdi,%r8
 1124a5e:	movabs $0x1ffffffffffffffc,%rdx
 1124a68:	and    %rdx,%r8
 1124a6b:	mov    -0x58(%rbp),%rdx
 1124a6f:	mov    -0xd8(%rbp),%rcx
 1124a76:	lea    (%rdx,%rcx,2),%r9
 1124a7a:	xor    %edx,%edx
 1124a7c:	xor    %r10d,%r10d
 1124a7f:	nop
 1124a80:	vmovdqu (%r9,%rdx,2),%ymm0
 1124a86:	vmovdqu (%rax,%r10,2),%ymm1
 1124a8c:	vpshufb %ymm2,%ymm1,%ymm1
 1124a91:	vpermq $0x4e,%ymm1,%ymm1
 1124a97:	vmovdqu %ymm1,(%r9,%rdx,2)
 1124a9d:	vpshufb %ymm2,%ymm0,%ymm0
 1124aa2:	vpermq $0x4e,%ymm0,%ymm0
 1124aa8:	vmovdqu %ymm0,(%rax,%r10,2)
 1124aae:	vmovdqu -0x20(%r9,%rdx,2),%ymm0
 1124ab5:	vmovdqu 0x20(%rax,%r10,2),%ymm1
 1124abc:	vpshufb %ymm2,%ymm1,%ymm1
 1124ac1:	vpermq $0x4e,%ymm1,%ymm1
 1124ac7:	vmovdqu %ymm1,-0x20(%r9,%rdx,2)
 1124ace:	vpshufb %ymm2,%ymm0,%ymm0
 1124ad3:	vpermq $0x4e,%ymm0,%ymm0
 1124ad9:	vmovdqu %ymm0,0x20(%rax,%r10,2)
 1124ae0:	vmovdqu -0x40(%r9,%rdx,2),%ymm0
 1124ae7:	vmovdqu 0x40(%rax,%r10,2),%ymm1
 1124aee:	vpshufb %ymm2,%ymm1,%ymm1
 1124af3:	vpermq $0x4e,%ymm1,%ymm1
 1124af9:	vmovdqu %ymm1,-0x40(%r9,%rdx,2)
 1124b00:	vpshufb %ymm2,%ymm0,%ymm0
 1124b05:	vpermq $0x4e,%ymm0,%ymm0
 1124b0b:	vmovdqu %ymm0,0x40(%rax,%r10,2)
 1124b12:	vmovdqu -0x60(%r9,%rdx,2),%ymm0
 1124b19:	vmovdqu 0x60(%rax,%r10,2),%ymm1
 1124b20:	vpshufb %ymm2,%ymm1,%ymm1
 1124b25:	vpermq $0x4e,%ymm1,%ymm1
 1124b2b:	vmovdqu %ymm1,-0x60(%r9,%rdx,2)
 1124b32:	vpshufb %ymm2,%ymm0,%ymm0
 1124b37:	vpermq $0x4e,%ymm0,%ymm0
 1124b3d:	vmovdqu %ymm0,0x60(%rax,%r10,2)
 1124b44:	add    $0x40,%r10
 1124b48:	add    $0xffffffffffffffc0,%rdx
 1124b4c:	add    $0xfffffffffffffffc,%r8
 1124b50:	jne    1124a80 <sort.block.block__anon_39129+0x7740>
 1124b56:	neg    %rdx
 1124b59:	and    $0x3,%edi
 1124b5c:	je     1124bc4 <sort.block.block__anon_39129+0x7884>
 1124b5e:	mov    %r11,%r14
 1124b61:	mov    -0x58(%rbp),%r8
 1124b65:	mov    -0xd8(%rbp),%rcx
 1124b6c:	lea    (%r8,%rcx,2),%r8
 1124b70:	sub    %rdx,%r8
 1124b73:	sub    %rdx,%r8
 1124b76:	shl    $0x4,%edi
 1124b79:	xor    %r9d,%r9d
 1124b7c:	mov    %rdx,%r10
 1124b7f:	nop
 1124b80:	vmovdqu (%r8,%r9,2),%ymm0
 1124b86:	vmovdqu (%rax,%r10,2),%ymm1
 1124b8c:	vpshufb %ymm2,%ymm1,%ymm1
 1124b91:	vpermq $0x4e,%ymm1,%ymm1
 1124b97:	vmovdqu %ymm1,(%r8,%r9,2)
 1124b9d:	vpshufb %ymm2,%ymm0,%ymm0
 1124ba2:	vpermq $0x4e,%ymm0,%ymm0
 1124ba8:	vmovdqu %ymm0,(%rax,%r10,2)
 1124bae:	add    $0x10,%r10
 1124bb2:	add    $0xfffffffffffffff0,%r9
 1124bb6:	mov    %rdi,%r11
 1124bb9:	add    %r9,%r11
 1124bbc:	jne    1124b80 <sort.block.block__anon_39129+0x7840>
 1124bbe:	sub    %r9,%rdx
 1124bc1:	mov    %r14,%r11
 1124bc4:	mov    %rdx,%rdi
 1124bc7:	sub    %rsi,%rdi
 1124bca:	jae    1124d2d <sort.block.block__anon_39129+0x79ed>
 1124bd0:	mov    %esi,%r8d
 1124bd3:	sub    %edx,%r8d
 1124bd6:	and    $0x3,%r8d
 1124bda:	je     1124c44 <sort.block.block__anon_39129+0x7904>
 1124bdc:	mov    %r11,%r15
 1124bdf:	mov    -0x48(%rbp),%r9
 1124be3:	mov    -0xd8(%rbp),%rcx
 1124bea:	lea    (%r9,%rcx,2),%r9
 1124bee:	sub    %rdx,%r9
 1124bf1:	sub    %rdx,%r9
 1124bf4:	neg    %r8
 1124bf7:	xor    %r10d,%r10d
 1124bfa:	mov    %rdx,%r11
 1124bfd:	nopl   (%rax)
 1124c00:	movzbl (%rax,%r11,2),%ebx
 1124c05:	movzbl -0x1(%r9,%r10,2),%r14d
 1124c0b:	mov    %r14b,(%rax,%r11,2)
 1124c0f:	mov    %bl,-0x1(%r9,%r10,2)
 1124c14:	movzbl 0x1(%rax,%r11,2),%ebx
 1124c1a:	movzbl (%r9,%r10,2),%r14d
 1124c1f:	mov    %r14b,0x1(%rax,%r11,2)
 1124c24:	mov    %bl,(%r9,%r10,2)
 1124c28:	inc    %r11
 1124c2b:	dec    %r10
 1124c2e:	cmp    %r10,%r8
 1124c31:	jne    1124c00 <sort.block.block__anon_39129+0x78c0>
 1124c33:	sub    %r10,%rdx
 1124c36:	mov    -0x40(%rbp),%rbx
 1124c3a:	mov    %r15,%r11
 1124c3d:	mov    -0x88(%rbp),%r15
 1124c44:	cmp    $0xfffffffffffffffc,%rdi
 1124c48:	ja     1124d2d <sort.block.block__anon_39129+0x79ed>
 1124c4e:	mov    -0x48(%rbp),%rdi
 1124c52:	mov    -0xd8(%rbp),%rcx
 1124c59:	lea    (%rdi,%rcx,2),%rdi
 1124c5d:	mov    %rdx,%r8
 1124c60:	neg    %r8
 1124c63:	neg    %rsi
 1124c66:	cs nopw 0x0(%rax,%rax,1)
 1124c70:	movzbl (%rax,%rdx,2),%r9d
 1124c75:	movzbl -0x1(%rdi,%r8,2),%r10d
 1124c7b:	mov    %r10b,(%rax,%rdx,2)
 1124c7f:	mov    %r9b,-0x1(%rdi,%r8,2)
 1124c84:	movzbl 0x1(%rax,%rdx,2),%r9d
 1124c8a:	movzbl (%rdi,%r8,2),%r10d
 1124c8f:	mov    %r10b,0x1(%rax,%rdx,2)
 1124c94:	mov    %r9b,(%rdi,%r8,2)
 1124c98:	movzbl 0x2(%rax,%rdx,2),%r9d
 1124c9e:	movzbl -0x3(%rdi,%r8,2),%r10d
 1124ca4:	mov    %r10b,0x2(%rax,%rdx,2)
 1124ca9:	mov    %r9b,-0x3(%rdi,%r8,2)
 1124cae:	movzbl 0x3(%rax,%rdx,2),%r9d
 1124cb4:	movzbl -0x2(%rdi,%r8,2),%r10d
 1124cba:	mov    %r10b,0x3(%rax,%rdx,2)
 1124cbf:	mov    %r9b,-0x2(%rdi,%r8,2)
 1124cc4:	movzbl 0x4(%rax,%rdx,2),%r9d
 1124cca:	movzbl -0x5(%rdi,%r8,2),%r10d
 1124cd0:	mov    %r10b,0x4(%rax,%rdx,2)
 1124cd5:	mov    %r9b,-0x5(%rdi,%r8,2)
 1124cda:	movzbl 0x5(%rax,%rdx,2),%r9d
 1124ce0:	movzbl -0x4(%rdi,%r8,2),%r10d
 1124ce6:	mov    %r10b,0x5(%rax,%rdx,2)
 1124ceb:	mov    %r9b,-0x4(%rdi,%r8,2)
 1124cf0:	movzbl 0x6(%rax,%rdx,2),%r9d
 1124cf6:	movzbl -0x7(%rdi,%r8,2),%r10d
 1124cfc:	mov    %r10b,0x6(%rax,%rdx,2)
 1124d01:	mov    %r9b,-0x7(%rdi,%r8,2)
 1124d06:	movzbl 0x7(%rax,%rdx,2),%r9d
 1124d0c:	movzbl -0x6(%rdi,%r8,2),%r10d
 1124d12:	mov    %r10b,0x7(%rax,%rdx,2)
 1124d17:	mov    %r9b,-0x6(%rdi,%r8,2)
 1124d1c:	add    $0x4,%rdx
 1124d20:	add    $0xfffffffffffffffc,%r8
 1124d24:	cmp    %r8,%rsi
 1124d27:	jne    1124c70 <sort.block.block__anon_39129+0x7930>
 1124d2d:	mov    -0x60(%rbp),%rax
 1124d31:	lea    (%rax,%rbx,1),%rdx
 1124d35:	add    %rax,%r12
 1124d38:	mov    %rbx,%rcx
 1124d3b:	mov    -0x108(%rbp),%rax
 1124d42:	mov    %rax,-0xd8(%rbp)
 1124d49:	mov    %r13,%rbx
 1124d4c:	mov    %rdx,%rsi
 1124d4f:	mov    -0x38(%rbp),%r10
 1124d53:	jmp    11225d1 <sort.block.block__anon_39129+0x5291>
 1124d58:	cmp    $0x3,%rdx
 1124d5c:	mov    -0x70(%rbp),%r11
 1124d60:	jae    1124d77 <sort.block.block__anon_39129+0x7a37>
 1124d62:	xor    %ecx,%ecx
 1124d64:	mov    -0xb0(%rbp),%rdi
 1124d6b:	mov    -0xf0(%rbp),%r8
 1124d72:	jmp    1124e41 <sort.block.block__anon_39129+0x7b01>
 1124d77:	xor    %ecx,%ecx
 1124d79:	mov    -0xb0(%rbp),%rdi
 1124d80:	mov    -0xf0(%rbp),%r8
 1124d87:	nopw   0x0(%rax,%rax,1)
 1124d90:	movzbl (%rax,%rcx,2),%edx
 1124d94:	movzbl (%r11,%rcx,2),%esi
 1124d99:	mov    %sil,(%rax,%rcx,2)
 1124d9d:	mov    %dl,(%r11,%rcx,2)
 1124da1:	movzbl 0x1(%rax,%rcx,2),%edx
 1124da6:	movzbl 0x1(%r11,%rcx,2),%esi
 1124dac:	mov    %sil,0x1(%rax,%rcx,2)
 1124db1:	mov    %dl,0x1(%r11,%rcx,2)
 1124db6:	movzbl 0x2(%rax,%rcx,2),%edx
 1124dbb:	movzbl 0x2(%r11,%rcx,2),%esi
 1124dc1:	mov    %sil,0x2(%rax,%rcx,2)
 1124dc6:	mov    %dl,0x2(%r11,%rcx,2)
 1124dcb:	movzbl 0x3(%rax,%rcx,2),%edx
 1124dd0:	movzbl 0x3(%r11,%rcx,2),%esi
 1124dd6:	mov    %sil,0x3(%rax,%rcx,2)
 1124ddb:	mov    %dl,0x3(%r11,%rcx,2)
 1124de0:	movzbl 0x4(%rax,%rcx,2),%edx
 1124de5:	movzbl 0x4(%r11,%rcx,2),%esi
 1124deb:	mov    %sil,0x4(%rax,%rcx,2)
 1124df0:	mov    %dl,0x4(%r11,%rcx,2)
 1124df5:	movzbl 0x5(%rax,%rcx,2),%edx
 1124dfa:	movzbl 0x5(%r11,%rcx,2),%esi
 1124e00:	mov    %sil,0x5(%rax,%rcx,2)
 1124e05:	mov    %dl,0x5(%r11,%rcx,2)
 1124e0a:	movzbl 0x6(%rax,%rcx,2),%edx
 1124e0f:	movzbl 0x6(%r11,%rcx,2),%esi
 1124e15:	mov    %sil,0x6(%rax,%rcx,2)
 1124e1a:	mov    %dl,0x6(%r11,%rcx,2)
 1124e1f:	movzbl 0x7(%rax,%rcx,2),%edx
 1124e24:	movzbl 0x7(%r11,%rcx,2),%esi
 1124e2a:	mov    %sil,0x7(%rax,%rcx,2)
 1124e2f:	mov    %dl,0x7(%r11,%rcx,2)
 1124e34:	add    $0x4,%rcx
 1124e38:	cmp    %rcx,%r9
 1124e3b:	jne    1124d90 <sort.block.block__anon_39129+0x7a50>
 1124e41:	test   %rdi,%rdi
 1124e44:	je     1124e7e <sort.block.block__anon_39129+0x7b3e>
 1124e46:	mov    %rdi,%rdx
 1124e49:	nopl   0x0(%rax)
 1124e50:	movzbl (%rax,%rcx,2),%esi
 1124e54:	movzbl (%r11,%rcx,2),%edi
 1124e59:	mov    %dil,(%rax,%rcx,2)
 1124e5d:	mov    %sil,(%r11,%rcx,2)
 1124e61:	movzbl 0x1(%rax,%rcx,2),%esi
 1124e66:	movzbl 0x1(%r11,%rcx,2),%edi
 1124e6c:	mov    %dil,0x1(%rax,%rcx,2)
 1124e71:	mov    %sil,0x1(%r11,%rcx,2)
 1124e76:	inc    %rcx
 1124e79:	dec    %rdx
 1124e7c:	jne    1124e50 <sort.block.block__anon_39129+0x7b10>
 1124e7e:	lea    (%rbx,%r15,1),%rdx
 1124e82:	add    %r15,%r12
 1124e85:	mov    -0x108(%rbp),%rax
 1124e8c:	add    %r15,%rax
 1124e8f:	mov    -0xd8(%rbp),%rcx
 1124e96:	lea    (%rcx,%r15,1),%r14
 1124e9a:	cmp    -0x1f8(%rbp),%rcx
 1124ea1:	cmova  %r8,%r14
 1124ea5:	mov    %rdx,%rsi
 1124ea8:	mov    -0x90(%rbp),%r11
 1124eaf:	jmp    112258f <sort.block.block__anon_39129+0x524f>
 1124eb4:	mov    %r15,%r12
 1124eb7:	mov    -0xf0(%rbp),%r14
 1124ebe:	cmp    $0x201,%r12
 1124ec5:	mov    -0xa0(%rbp),%rax
 1124ecc:	mov    -0xa8(%rbp),%rcx
 1124ed3:	jae    11223b7 <sort.block.block__anon_39129+0x5077>
 1124ed9:	cmp    %r11,%r14
 1124edc:	je     1124fb9 <sort.block.block__anon_39129+0x7c79>
 1124ee2:	cmp    %rbx,%r11
 1124ee5:	je     1124fb9 <sort.block.block__anon_39129+0x7c79>
 1124eeb:	neg    %r14
 1124eee:	xor    %eax,%eax
 1124ef0:	mov    %r14,-0xf0(%rbp)
 1124ef7:	mov    %rbx,%rcx
 1124efa:	movzwl -0x650(%rbp,%rax,2),%esi
 1124f02:	movzwl %si,%edi
 1124f05:	lea    (%r14,%r11,1),%r8
 1124f09:	mov    %r10,%rdx
 1124f0c:	mov    %r11,-0x90(%rbp)
 1124f13:	lea    (%r10,%r11,2),%r10
 1124f17:	lea    (%rdx,%rbx,2),%r9
 1124f1b:	shl    $0x4,%edi
 1124f1e:	xor    %r13d,%r13d
 1124f21:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1124f30:	movzwl (%r10,%r13,2),%r11d
 1124f35:	mov    -0x30(%rbp),%rbx
 1124f39:	mov    (%rbx),%rbx
 1124f3c:	mov    %r11d,%r14d
 1124f3f:	shl    $0x4,%r14d
 1124f43:	mov    (%rbx,%rdi,1),%r15
 1124f47:	cmp    %r15,(%rbx,%r14,1)
 1124f4b:	jne    1124f5d <sort.block.block__anon_39129+0x7c1d>
 1124f4d:	add    %rbx,%r14
 1124f50:	add    %rdi,%rbx
 1124f53:	movzwl 0xe(%r14),%r14d
 1124f58:	cmp    0xe(%rbx),%r14w
 1124f5d:	jae    1124f80 <sort.block.block__anon_39129+0x7c40>
 1124f5f:	mov    %r11w,(%r9,%r13,2)
 1124f64:	inc    %r13
 1124f67:	mov    %r8,%r11
 1124f6a:	add    %r13,%r11
 1124f6d:	jne    1124f30 <sort.block.block__anon_39129+0x7bf0>
 1124f6f:	jmp    1124fdc <sort.block.block__anon_39129+0x7c9c>
 1124f71:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1124f80:	mov    %si,(%r9,%r13,2)
 1124f85:	inc    %rax
 1124f88:	lea    (%rcx,%r13,1),%rbx
 1124f8c:	inc    %rbx
 1124f8f:	mov    -0x90(%rbp),%r11
 1124f96:	add    %r13,%r11
 1124f99:	cmp    %r12,%rax
 1124f9c:	mov    -0x38(%rbp),%r10
 1124fa0:	mov    -0xf0(%rbp),%r14
 1124fa7:	jne    1124ef7 <sort.block.block__anon_39129+0x7bb7>
 1124fad:	lea    (%rcx,%r13,1),%rbx
 1124fb1:	inc    %rbx
 1124fb4:	mov    %r12,%rax
 1124fb7:	jmp    1124fe6 <sort.block.block__anon_39129+0x7ca6>
 1124fb9:	xor    %eax,%eax
 1124fbb:	jmp    1124fe6 <sort.block.block__anon_39129+0x7ca6>
 1124fbd:	sub    %r11,%r14
 1124fc0:	mov    -0x68(%rbp),%r15
 1124fc4:	jne    112500b <sort.block.block__anon_39129+0x7ccb>
 1124fc6:	xor    %eax,%eax
 1124fc8:	xor    %ecx,%ecx
 1124fca:	lea    (%rax,%rbx,1),%rdx
 1124fce:	sub    %rdx,%r11
 1124fd1:	je     1121f78 <sort.block.block__anon_39129+0x4c38>
 1124fd7:	jmp    11250f4 <sort.block.block__anon_39129+0x7db4>
 1124fdc:	add    %r13,%rcx
 1124fdf:	mov    %rcx,%rbx
 1124fe2:	mov    -0x38(%rbp),%r10
 1124fe6:	lea    -0x650(,%rax,2),%rsi
 1124fee:	add    %rbp,%rsi
 1124ff1:	sub    %rax,%r12
 1124ff4:	lea    (%r10,%rbx,2),%rdi
 1124ff8:	add    %r12,%r12
 1124ffb:	mov    %r12,%rdx
 1124ffe:	vzeroupper 
 1125001:	call   119d8c0 <compiler_rt.memcpy.memcpyFast>
 1125006:	jmp    1121f6c <sort.block.block__anon_39129+0x4c2c>
 112500b:	mov    %r12,-0x60(%rbp)
 112500f:	mov    %r14,%r12
 1125012:	lea    (%r10,%r11,2),%rdx
 1125016:	mov    -0x50(%rbp),%rax
 112501a:	mov    %rbx,-0x40(%rbp)
 112501e:	lea    (%rax,%rbx,2),%rsi
 1125022:	xor    %eax,%eax
 1125024:	xor    %edi,%edi
 1125026:	xor    %r8d,%r8d
 1125029:	mov    %r8,%rcx
 112502c:	nopl   0x0(%rax)
 1125030:	mov    %r11,%r13
 1125033:	movzwl (%rdx,%rdi,2),%r8d
 1125038:	movzwl (%r15,%rax,2),%ebx
 112503d:	mov    -0x30(%rbp),%r9
 1125041:	mov    (%r9),%r10
 1125044:	mov    %r8d,%r9d
 1125047:	shl    $0x4,%r9d
 112504b:	mov    %ebx,%r11d
 112504e:	shl    $0x4,%r11d
 1125052:	mov    (%r10,%r11,1),%r14
 1125056:	cmp    %r14,(%r10,%r9,1)
 112505a:	jne    112506c <sort.block.block__anon_39129+0x7d2c>
 112505c:	add    %r10,%r9
 112505f:	add    %r10,%r11
 1125062:	movzwl 0xe(%r9),%r9d
 1125067:	cmp    0xe(%r11),%r9w
 112506c:	mov    %r13,%r11
 112506f:	jae    11250b0 <sort.block.block__anon_39129+0x7d70>
 1125071:	mov    %r8d,%r9d
 1125074:	shr    $0x8,%r9d
 1125078:	movzbl -0x1(%rsi,%rcx,2),%r10d
 112507e:	mov    %r8b,-0x1(%rsi,%rcx,2)
 1125083:	mov    %r10b,(%rdx,%rdi,2)
 1125087:	movzbl (%rsi,%rcx,2),%r8d
 112508c:	mov    %r9b,(%rsi,%rcx,2)
 1125090:	mov    %r8b,0x1(%rdx,%rdi,2)
 1125095:	inc    %rdi
 1125098:	inc    %rcx
 112509b:	cmp    %r12,%rdi
 112509e:	jb     1125030 <sort.block.block__anon_39129+0x7cf0>
 11250a0:	jmp    11250df <sort.block.block__anon_39129+0x7d9f>
 11250a2:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11250b0:	movzbl -0x1(%rsi,%rcx,2),%r8d
 11250b6:	mov    %bl,-0x1(%rsi,%rcx,2)
 11250ba:	mov    %r8b,(%r15,%rax,2)
 11250be:	movzbl (%rsi,%rcx,2),%r8d
 11250c3:	mov    %bh,(%rsi,%rcx,2)
 11250c6:	mov    %r8b,0x1(%r15,%rax,2)
 11250cb:	inc    %rax
 11250ce:	lea    0x1(%rcx),%r8
 11250d2:	cmp    -0x60(%rbp),%rax
 11250d6:	jb     1125029 <sort.block.block__anon_39129+0x7ce9>
 11250dc:	inc    %rcx
 11250df:	mov    -0x38(%rbp),%r10
 11250e3:	mov    -0x40(%rbp),%rbx
 11250e7:	lea    (%rax,%rbx,1),%rdx
 11250eb:	sub    %rdx,%r11
 11250ee:	je     1121f78 <sort.block.block__anon_39129+0x4c38>
 11250f4:	add    %rbx,%rbx
 11250f7:	lea    (%rbx,%rcx,2),%rcx
 11250fb:	add    -0x50(%rbp),%rcx
 11250ff:	mov    -0x1a8(%rbp),%rdx
 1125106:	lea    (%rdx,%rax,2),%rax
 112510a:	xor    %edx,%edx
 112510c:	nopl   0x0(%rax)
 1125110:	movzbl -0x1(%rax,%rdx,2),%esi
 1125115:	movzbl -0x1(%rcx,%rdx,2),%edi
 112511a:	mov    %dil,-0x1(%rax,%rdx,2)
 112511f:	mov    %sil,-0x1(%rcx,%rdx,2)
 1125124:	movzbl (%rax,%rdx,2),%esi
 1125128:	movzbl (%rcx,%rdx,2),%edi
 112512c:	mov    %dil,(%rax,%rdx,2)
 1125130:	mov    %sil,(%rcx,%rdx,2)
 1125134:	inc    %rdx
 1125137:	cmp    %rdx,%r11
 112513a:	jne    1125110 <sort.block.block__anon_39129+0x7dd0>
 112513c:	jmp    1121f78 <sort.block.block__anon_39129+0x4c38>
 1125141:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1125150:	mov    -0x1e8(%rbp),%r14
 1125157:	cmp    $0x2,%r14
 112515b:	mov    -0x98(%rbp),%r13
 1125162:	mov    -0x68(%rbp),%rbx
 1125166:	jb     11251f0 <sort.block.block__anon_39129+0x7eb0>
 112516c:	mov    -0x30(%rbp),%rax
 1125170:	mov    (%rax),%rax
 1125173:	mov    $0x1,%ecx
 1125178:	jmp    1125188 <sort.block.block__anon_39129+0x7e48>
 112517a:	nopw   0x0(%rax,%rax,1)
 1125180:	inc    %rcx
 1125183:	cmp    %r14,%rcx
 1125186:	je     11251f0 <sort.block.block__anon_39129+0x7eb0>
 1125188:	mov    %rcx,%rdx
 112518b:	nopl   0x0(%rax,%rax,1)
 1125190:	movzwl (%rbx,%rdx,2),%esi
 1125194:	movzwl -0x2(%rbx,%rdx,2),%edi
 1125199:	mov    %esi,%r8d
 112519c:	shl    $0x4,%r8d
 11251a0:	mov    (%rax,%r8,1),%r10
 11251a4:	mov    %edi,%r9d
 11251a7:	shl    $0x4,%r9d
 11251ab:	mov    (%rax,%r9,1),%r11
 11251af:	cmp    %r11,%r10
 11251b2:	jne    11251c4 <sort.block.block__anon_39129+0x7e84>
 11251b4:	add    %rax,%r8
 11251b7:	add    %rax,%r9
 11251ba:	movzwl 0xe(%r8),%r8d
 11251bf:	cmp    0xe(%r9),%r8w
 11251c4:	jae    1125180 <sort.block.block__anon_39129+0x7e40>
 11251c6:	mov    %esi,%r8d
 11251c9:	shr    $0x8,%r8d
 11251cd:	mov    %edi,%r9d
 11251d0:	shr    $0x8,%r9d
 11251d4:	mov    %dil,(%rbx,%rdx,2)
 11251d8:	dec    %rdx
 11251db:	mov    %sil,(%rbx,%rdx,2)
 11251df:	mov    %r9b,0x3(%rbx,%rdx,2)
 11251e4:	mov    %r8b,0x1(%rbx,%rdx,2)
 11251e9:	test   %rdx,%rdx
 11251ec:	jne    1125190 <sort.block.block__anon_39129+0x7e50>
 11251ee:	jmp    1125180 <sort.block.block__anon_39129+0x7e40>
 11251f0:	mov    $0x1,%cl
 11251f2:	lea    -0x1a0(%rbp),%rax
 11251f9:	jmp    1125216 <sort.block.block__anon_39129+0x7ed6>
 11251fb:	nopl   0x0(%rax,%rax,1)
 1125200:	lea    -0x178(%rbp),%rax
 1125207:	testb  $0x1,-0x60(%rbp)
 112520b:	mov    $0x0,%ecx
 1125210:	je     111f110 <sort.block.block__anon_39129+0x1dd0>
 1125216:	mov    %ecx,-0x60(%rbp)
 1125219:	mov    0x10(%rax),%r10
 112521d:	lea    (%r10,%r10,1),%rsi
 1125221:	mov    0x8(%rax),%rcx
 1125225:	cmp    %rcx,(%rax)
 1125228:	jbe    1125d60 <sort.block.block__anon_39129+0x8a20>
 112522e:	test   %r10,%r10
 1125231:	je     1125200 <sort.block.block__anon_39129+0x7ec0>
 1125233:	mov    0x18(%rax),%rdi
 1125237:	mov    0x20(%rax),%rax
 112523b:	mov    %rax,-0x68(%rbp)
 112523f:	lea    (%rdi,%r10,1),%rdx
 1125243:	jmp    112526d <sort.block.block__anon_39129+0x7f2d>
 1125245:	data16 cs nopw 0x0(%rax,%rax,1)
 1125250:	inc    %rdi
 1125253:	mov    -0x40(%rbp),%rsi
 1125257:	add    $0xfffffffffffffffe,%rsi
 112525b:	mov    %rdi,%r10
 112525e:	sub    %r9,%r10
 1125261:	neg    %r10
 1125264:	sub    %r9,%rdi
 1125267:	lea    (%rdi,%rdx,1),%rdi
 112526b:	je     1125200 <sort.block.block__anon_39129+0x7ec0>
 112526d:	mov    %rsi,-0x40(%rbp)
 1125271:	mov    %rdx,%r9
 1125274:	mov    -0x68(%rbp),%rax
 1125278:	sub    %rdx,%rax
 112527b:	je     11253f0 <sort.block.block__anon_39129+0x80b0>
 1125281:	mov    -0x38(%rbp),%rcx
 1125285:	movzwl (%rcx,%rdi,2),%ecx
 1125289:	mov    %rax,%rdx
 112528c:	mov    -0x40(%rbp),%rsi
 1125290:	or     %rsi,%rdx
 1125293:	shr    $0x20,%rdx
 1125297:	je     11252a0 <sort.block.block__anon_39129+0x7f60>
 1125299:	xor    %edx,%edx
 112529b:	div    %rsi
 112529e:	jmp    11252a4 <sort.block.block__anon_39129+0x7f64>
 11252a0:	xor    %edx,%edx
 11252a2:	div    %esi
 11252a4:	cmp    $0x1,%rax
 11252a8:	adc    $0x0,%rax
 11252ac:	mov    -0x30(%rbp),%rdx
 11252b0:	mov    (%rdx),%r11
 11252b3:	shl    $0x4,%ecx
 11252b6:	lea    (%r11,%rcx,1),%r14
 11252ba:	mov    (%r11,%rcx,1),%r15
 11252be:	mov    -0x68(%rbp),%rbx
 11252c2:	sub    %rax,%rbx
 11252c5:	mov    %r9,%rdx
 11252c8:	jmp    11252de <sort.block.block__anon_39129+0x7f9e>
 11252ca:	nopw   0x0(%rax,%rax,1)
 11252d0:	jae    1125322 <sort.block.block__anon_39129+0x7fe2>
 11252d2:	mov    %rcx,%rdx
 11252d5:	cmp    %rbx,%rcx
 11252d8:	jae    1125370 <sort.block.block__anon_39129+0x8030>
 11252de:	lea    (%rdx,%rax,1),%rcx
 11252e2:	movzwl 0x0(%r13,%rcx,2),%r12d
 11252e8:	shl    $0x4,%r12d
 11252ec:	cmp    %r15,(%r11,%r12,1)
 11252f0:	jne    11252d0 <sort.block.block__anon_39129+0x7f90>
 11252f2:	add    %r11,%r12
 11252f5:	movzwl 0xe(%r12),%r12d
 11252fb:	cmp    0xe(%r14),%r12w
 1125300:	jb     11252d2 <sort.block.block__anon_39129+0x7f92>
 1125302:	jmp    1125322 <sort.block.block__anon_39129+0x7fe2>
 1125304:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1125310:	xor    %ebx,%ebx
 1125312:	add    %rbx,%rdx
 1125315:	cmp    $0x2,%rax
 1125319:	mov    %rcx,%rax
 112531c:	jb     11253f0 <sort.block.block__anon_39129+0x80b0>
 1125322:	mov    -0x38(%rbp),%rcx
 1125326:	lea    (%rcx,%rdx,2),%rcx
 112532a:	mov    %rax,%rbx
 112532d:	and    $0xfffffffffffffffe,%rbx
 1125331:	movzwl (%rbx,%rcx,1),%ecx
 1125335:	shl    $0x4,%ecx
 1125338:	cmp    %r15,(%r11,%rcx,1)
 112533c:	jne    112534a <sort.block.block__anon_39129+0x800a>
 112533e:	add    %r11,%rcx
 1125341:	movzwl 0xe(%rcx),%ecx
 1125345:	cmp    0xe(%r14),%cx
 112534a:	setb   %bl
 112534d:	mov    %rax,%rcx
 1125350:	shr    %rcx
 1125353:	test   %bl,%bl
 1125355:	je     1125310 <sort.block.block__anon_39129+0x7fd0>
 1125357:	mov    %eax,%ebx
 1125359:	and    $0x1,%ebx
 112535c:	add    %rcx,%rbx
 112535f:	add    %rbx,%rdx
 1125362:	cmp    $0x2,%rax
 1125366:	mov    %rcx,%rax
 1125369:	jae    1125322 <sort.block.block__anon_39129+0x7fe2>
 112536b:	jmp    11253f0 <sort.block.block__anon_39129+0x80b0>
 1125370:	mov    -0x68(%rbp),%rdx
 1125374:	mov    %rdx,%rax
 1125377:	sub    %rcx,%rax
 112537a:	jbe    11253f0 <sort.block.block__anon_39129+0x80b0>
 112537c:	mov    %rcx,%rdx
 112537f:	jmp    112539e <sort.block.block__anon_39129+0x805e>
 1125381:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1125390:	xor    %ebx,%ebx
 1125392:	add    %rbx,%rdx
 1125395:	cmp    $0x1,%rax
 1125399:	mov    %rcx,%rax
 112539c:	jbe    11253f0 <sort.block.block__anon_39129+0x80b0>
 112539e:	mov    -0x38(%rbp),%rcx
 11253a2:	lea    (%rcx,%rdx,2),%rcx
 11253a6:	mov    %rax,%rbx
 11253a9:	and    $0xfffffffffffffffe,%rbx
 11253ad:	movzwl (%rbx,%rcx,1),%ecx
 11253b1:	shl    $0x4,%ecx
 11253b4:	cmp    %r15,(%r11,%rcx,1)
 11253b8:	jne    11253c6 <sort.block.block__anon_39129+0x8086>
 11253ba:	add    %r11,%rcx
 11253bd:	movzwl 0xe(%rcx),%ecx
 11253c1:	cmp    0xe(%r14),%cx
 11253c6:	setb   %bl
 11253c9:	mov    %rax,%rcx
 11253cc:	shr    %rcx
 11253cf:	test   %bl,%bl
 11253d1:	je     1125390 <sort.block.block__anon_39129+0x8050>
 11253d3:	mov    %eax,%ebx
 11253d5:	and    $0x1,%ebx
 11253d8:	add    %rcx,%rbx
 11253db:	add    %rbx,%rdx
 11253de:	cmp    $0x1,%rax
 11253e2:	mov    %rcx,%rax
 11253e5:	ja     112539e <sort.block.block__anon_39129+0x805e>
 11253e7:	nopw   0x0(%rax,%rax,1)
 11253f0:	mov    %r10,%rax
 11253f3:	shr    %rax
 11253f6:	cmp    $0x20,%r10
 11253fa:	setb   %cl
 11253fd:	cmp    $0xf,%rax
 1125401:	sete   %r11b
 1125405:	or     %cl,%r11b
 1125408:	je     1125420 <sort.block.block__anon_39129+0x80e0>
 112540a:	xor    %r11d,%r11d
 112540d:	jmp    11255bf <sort.block.block__anon_39129+0x827f>
 1125412:	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1125420:	lea    -0x10(%rax),%rcx
 1125424:	mov    %rcx,%r14
 1125427:	shr    $0x4,%r14
 112542b:	inc    %r14
 112542e:	cmp    $0x30,%rcx
 1125432:	jae    1125450 <sort.block.block__anon_39129+0x8110>
 1125434:	xor    %r11d,%r11d
 1125437:	and    $0x3,%r14d
 112543b:	jne    112554f <sort.block.block__anon_39129+0x820f>
 1125441:	jmp    11255bf <sort.block.block__anon_39129+0x827f>
 1125446:	cs nopw 0x0(%rax,%rax,1)
 1125450:	mov    %r14,%rcx
 1125453:	movabs $0x1ffffffffffffffc,%rsi
 112545d:	and    %rsi,%rcx
 1125460:	lea    (%rdi,%rdi,1),%r8
 1125464:	mov    -0xc8(%rbp),%rsi
 112546b:	lea    (%rsi,%rdi,2),%rbx
 112546f:	lea    (%r8,%r10,2),%r15
 1125473:	add    -0x58(%rbp),%r15
 1125477:	xor    %r11d,%r11d
 112547a:	nopw   0x0(%rax,%rax,1)
 1125480:	vmovdqu (%r15,%r11,2),%ymm0
 1125486:	vmovdqu -0x60(%rbx),%ymm1
 112548b:	vpshufb %ymm2,%ymm1,%ymm1
 1125490:	vpermq $0x4e,%ymm1,%ymm1
 1125496:	vmovdqu %ymm1,(%r15,%r11,2)
 112549c:	vpshufb %ymm2,%ymm0,%ymm0
 11254a1:	vpermq $0x4e,%ymm0,%ymm0
 11254a7:	vmovdqu %ymm0,-0x60(%rbx)
 11254ac:	vmovdqu -0x20(%r15,%r11,2),%ymm0
 11254b3:	vmovdqu -0x40(%rbx),%ymm1
 11254b8:	vpshufb %ymm2,%ymm1,%ymm1
 11254bd:	vpermq $0x4e,%ymm1,%ymm1
 11254c3:	vmovdqu %ymm1,-0x20(%r15,%r11,2)
 11254ca:	vpshufb %ymm2,%ymm0,%ymm0
 11254cf:	vpermq $0x4e,%ymm0,%ymm0
 11254d5:	vmovdqu %ymm0,-0x40(%rbx)
 11254da:	vmovdqu -0x40(%r15,%r11,2),%ymm0
 11254e1:	vmovdqu -0x20(%rbx),%ymm1
 11254e6:	vpshufb %ymm2,%ymm1,%ymm1
 11254eb:	vpermq $0x4e,%ymm1,%ymm1
 11254f1:	vmovdqu %ymm1,-0x40(%r15,%r11,2)
 11254f8:	vpshufb %ymm2,%ymm0,%ymm0
 11254fd:	vpermq $0x4e,%ymm0,%ymm0
 1125503:	vmovdqu %ymm0,-0x20(%rbx)
 1125508:	vmovdqu -0x60(%r15,%r11,2),%ymm0
 112550f:	vmovdqu (%rbx),%ymm1
 1125513:	vpshufb %ymm2,%ymm1,%ymm1
 1125518:	vpermq $0x4e,%ymm1,%ymm1
 112551e:	vmovdqu %ymm1,-0x60(%r15,%r11,2)
 1125525:	vpshufb %ymm2,%ymm0,%ymm0
 112552a:	vpermq $0x4e,%ymm0,%ymm0
 1125530:	vmovdqu %ymm0,(%rbx)
 1125534:	sub    $0xffffffffffffff80,%rbx
 1125538:	add    $0xffffffffffffffc0,%r11
 112553c:	add    $0xfffffffffffffffc,%rcx
 1125540:	jne    1125480 <sort.block.block__anon_39129+0x8140>
 1125546:	neg    %r11
 1125549:	and    $0x3,%r14d
 112554d:	je     11255bf <sort.block.block__anon_39129+0x827f>
 112554f:	lea    (%r10,%r10,1),%rcx
 1125553:	lea    (%rcx,%rdi,2),%rbx
 1125557:	add    -0x58(%rbp),%rbx
 112555b:	mov    %r11,%rcx
 112555e:	neg    %rcx
 1125561:	add    %r11,%r11
 1125564:	lea    (%r11,%rdi,2),%r11
 1125568:	add    -0x38(%rbp),%r11
 112556c:	shl    $0x5,%r14d
 1125570:	xor    %r15d,%r15d
 1125573:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1125580:	vmovdqu (%rbx,%rcx,2),%ymm0
 1125585:	vmovdqu (%r11,%r15,1),%ymm1
 112558b:	vpshufb %ymm2,%ymm1,%ymm1
 1125590:	vpermq $0x4e,%ymm1,%ymm1
 1125596:	vmovdqu %ymm1,(%rbx,%rcx,2)
 112559b:	vpshufb %ymm2,%ymm0,%ymm0
 11255a0:	vpermq $0x4e,%ymm0,%ymm0
 11255a6:	vmovdqu %ymm0,(%r11,%r15,1)
 11255ac:	add    $0xfffffffffffffff0,%rcx
 11255b0:	add    $0x20,%r15
 11255b4:	cmp    %r15,%r14
 11255b7:	jne    1125580 <sort.block.block__anon_39129+0x8240>
 11255b9:	neg    %rcx
 11255bc:	mov    %rcx,%r11
 11255bf:	mov    %r11,%rcx
 11255c2:	sub    %rax,%rcx
 11255c5:	jae    112570d <sort.block.block__anon_39129+0x83cd>
 11255cb:	mov    %eax,%ebx
 11255cd:	sub    %r11d,%ebx
 11255d0:	and    $0x3,%ebx
 11255d3:	je     112563a <sort.block.block__anon_39129+0x82fa>
 11255d5:	mov    -0x48(%rbp),%rsi
 11255d9:	lea    (%rsi,%r9,2),%r14
 11255dd:	sub    %r11,%r14
 11255e0:	sub    %r11,%r14
 11255e3:	lea    (%rdi,%rdi,1),%r15
 11255e7:	lea    (%r15,%r11,2),%r15
 11255eb:	add    -0x50(%rbp),%r15
 11255ef:	neg    %rbx
 11255f2:	xor    %r12d,%r12d
 11255f5:	data16 cs nopw 0x0(%rax,%rax,1)
 1125600:	movzbl -0x1(%r15),%r13d
 1125605:	movzbl -0x1(%r14,%r12,2),%r8d
 112560b:	mov    %r8b,-0x1(%r15)
 112560f:	mov    %r13b,-0x1(%r14,%r12,2)
 1125614:	movzbl (%r15),%r8d
 1125618:	movzbl (%r14,%r12,2),%r13d
 112561d:	mov    %r13b,(%r15)
 1125620:	mov    %r8b,(%r14,%r12,2)
 1125624:	dec    %r12
 1125627:	add    $0x2,%r15
 112562b:	cmp    %r12,%rbx
 112562e:	jne    1125600 <sort.block.block__anon_39129+0x82c0>
 1125630:	sub    %r12,%r11
 1125633:	mov    -0x98(%rbp),%r13
 112563a:	cmp    $0xfffffffffffffffc,%rcx
 112563e:	ja     112570d <sort.block.block__anon_39129+0x83cd>
 1125644:	mov    -0x80(%rbp),%rcx
 1125648:	lea    (%rcx,%rdi,2),%rcx
 112564c:	mov    -0x48(%rbp),%rsi
 1125650:	lea    (%rsi,%r9,2),%rbx
 1125654:	sub    %r11,%rbx
 1125657:	sub    %r11,%rbx
 112565a:	nopw   0x0(%rax,%rax,1)
 1125660:	movzbl -0x7(%rcx,%r11,2),%r8d
 1125666:	movzbl -0x1(%rbx),%r14d
 112566b:	mov    %r14b,-0x7(%rcx,%r11,2)
 1125670:	mov    %r8b,-0x1(%rbx)
 1125674:	movzbl -0x6(%rcx,%r11,2),%r8d
 112567a:	movzbl (%rbx),%r14d
 112567e:	mov    %r14b,-0x6(%rcx,%r11,2)
 1125683:	mov    %r8b,(%rbx)
 1125686:	movzbl -0x5(%rcx,%r11,2),%r8d
 112568c:	movzbl -0x3(%rbx),%r14d
 1125691:	mov    %r14b,-0x5(%rcx,%r11,2)
 1125696:	mov    %r8b,-0x3(%rbx)
 112569a:	movzbl -0x4(%rcx,%r11,2),%r8d
 11256a0:	movzbl -0x2(%rbx),%r14d
 11256a5:	mov    %r14b,-0x4(%rcx,%r11,2)
 11256aa:	mov    %r8b,-0x2(%rbx)
 11256ae:	movzbl -0x3(%rcx,%r11,2),%r8d
 11256b4:	movzbl -0x5(%rbx),%r14d
 11256b9:	mov    %r14b,-0x3(%rcx,%r11,2)
 11256be:	mov    %r8b,-0x5(%rbx)
 11256c2:	movzbl -0x2(%rcx,%r11,2),%r8d
 11256c8:	movzbl -0x4(%rbx),%r14d
 11256cd:	mov    %r14b,-0x2(%rcx,%r11,2)
 11256d2:	mov    %r8b,-0x4(%rbx)
 11256d6:	movzbl -0x1(%rcx,%r11,2),%r8d
 11256dc:	movzbl -0x7(%rbx),%r14d
 11256e1:	mov    %r14b,-0x1(%rcx,%r11,2)
 11256e6:	mov    %r8b,-0x7(%rbx)
 11256ea:	movzbl (%rcx,%r11,2),%r8d
 11256ef:	movzbl -0x6(%rbx),%r14d
 11256f4:	mov    %r14b,(%rcx,%r11,2)
 11256f8:	mov    %r8b,-0x6(%rbx)
 11256fc:	add    $0x4,%r11
 1125700:	add    $0xfffffffffffffff8,%rbx
 1125704:	cmp    %r11,%rax
 1125707:	jne    1125660 <sort.block.block__anon_39129+0x8320>
 112570d:	mov    %rdx,%rax
 1125710:	sub    %rdi,%rax
 1125713:	mov    %rax,%r15
 1125716:	sub    %r10,%r15
 1125719:	mov    %r15,%r11
 112571c:	shr    %r11
 112571f:	cmp    $0x20,%r15
 1125723:	setb   %cl
 1125726:	cmp    $0xf,%r11
 112572a:	sete   %r8b
 112572e:	or     %cl,%r8b
 1125731:	je     1125740 <sort.block.block__anon_39129+0x8400>
 1125733:	xor    %r14d,%r14d
 1125736:	jmp    1125904 <sort.block.block__anon_39129+0x85c4>
 112573b:	nopl   0x0(%rax,%rax,1)
 1125740:	lea    -0x10(%r11),%rcx
 1125744:	mov    %rcx,%r12
 1125747:	shr    $0x4,%r12
 112574b:	inc    %r12
 112574e:	cmp    $0x30,%rcx
 1125752:	jae    1125770 <sort.block.block__anon_39129+0x8430>
 1125754:	xor    %r14d,%r14d
 1125757:	and    $0x3,%r12d
 112575b:	jne    1125892 <sort.block.block__anon_39129+0x8552>
 1125761:	jmp    1125904 <sort.block.block__anon_39129+0x85c4>
 1125766:	cs nopw 0x0(%rax,%rax,1)
 1125770:	mov    %r12,%rbx
 1125773:	movabs $0x1ffffffffffffffc,%rcx
 112577d:	and    %rcx,%rbx
 1125780:	lea    (%r9,%r9,1),%rcx
 1125784:	mov    -0xc8(%rbp),%rsi
 112578b:	lea    (%rsi,%r9,2),%r13
 112578f:	lea    (%rcx,%rdx,2),%rcx
 1125793:	sub    %rdi,%rcx
 1125796:	sub    %rdi,%rcx
 1125799:	sub    %r10,%rcx
 112579c:	sub    %r10,%rcx
 112579f:	add    -0x38(%rbp),%rcx
 11257a3:	xor    %r14d,%r14d
 11257a6:	cs nopw 0x0(%rax,%rax,1)
 11257b0:	vmovdqu -0x20(%rcx,%r14,2),%ymm0
 11257b7:	vmovdqu -0x60(%r13),%ymm1
 11257bd:	vpshufb %ymm2,%ymm1,%ymm1
 11257c2:	vpermq $0x4e,%ymm1,%ymm1
 11257c8:	vmovdqu %ymm1,-0x20(%rcx,%r14,2)
 11257cf:	vpshufb %ymm2,%ymm0,%ymm0
 11257d4:	vpermq $0x4e,%ymm0,%ymm0
 11257da:	vmovdqu %ymm0,-0x60(%r13)
 11257e0:	vmovdqu -0x40(%rcx,%r14,2),%ymm0
 11257e7:	vmovdqu -0x40(%r13),%ymm1
 11257ed:	vpshufb %ymm2,%ymm1,%ymm1
 11257f2:	vpermq $0x4e,%ymm1,%ymm1
 11257f8:	vmovdqu %ymm1,-0x40(%rcx,%r14,2)
 11257ff:	vpshufb %ymm2,%ymm0,%ymm0
 1125804:	vpermq $0x4e,%ymm0,%ymm0
 112580a:	vmovdqu %ymm0,-0x40(%r13)
 1125810:	vmovdqu -0x60(%rcx,%r14,2),%ymm0
 1125817:	vmovdqu -0x20(%r13),%ymm1
 112581d:	vpshufb %ymm2,%ymm1,%ymm1
 1125822:	vpermq $0x4e,%ymm1,%ymm1
 1125828:	vmovdqu %ymm1,-0x60(%rcx,%r14,2)
 112582f:	vpshufb %ymm2,%ymm0,%ymm0
 1125834:	vpermq $0x4e,%ymm0,%ymm0
 112583a:	vmovdqu %ymm0,-0x20(%r13)
 1125840:	vmovdqu -0x80(%rcx,%r14,2),%ymm0
 1125847:	vmovdqu 0x0(%r13),%ymm1
 112584d:	vpshufb %ymm2,%ymm1,%ymm1
 1125852:	vpermq $0x4e,%ymm1,%ymm1
 1125858:	vmovdqu %ymm1,-0x80(%rcx,%r14,2)
 112585f:	vpshufb %ymm2,%ymm0,%ymm0
 1125864:	vpermq $0x4e,%ymm0,%ymm0
 112586a:	vmovdqu %ymm0,0x0(%r13)
 1125870:	sub    $0xffffffffffffff80,%r13
 1125874:	add    $0xffffffffffffffc0,%r14
 1125878:	add    $0xfffffffffffffffc,%rbx
 112587c:	jne    11257b0 <sort.block.block__anon_39129+0x8470>
 1125882:	neg    %r14
 1125885:	mov    -0x98(%rbp),%r13
 112588c:	and    $0x3,%r12d
 1125890:	je     1125904 <sort.block.block__anon_39129+0x85c4>
 1125892:	lea    (%r9,%r9,1),%rcx
 1125896:	lea    (%rcx,%rdx,2),%rcx
 112589a:	sub    %rdi,%rcx
 112589d:	sub    %rdi,%rcx
 11258a0:	lea    (%r14,%r14,1),%r8
 11258a4:	sub    %r8,%rcx
 11258a7:	sub    %r10,%rcx
 11258aa:	sub    %r10,%rcx
 11258ad:	add    -0x58(%rbp),%rcx
 11258b1:	lea    (%r8,%r9,2),%rbx
 11258b5:	add    -0x38(%rbp),%rbx
 11258b9:	shl    $0x4,%r12d
 11258bd:	xor    %r13d,%r13d
 11258c0:	vmovdqu (%rcx,%r13,2),%ymm0
 11258c6:	vmovdqu (%rbx),%ymm1
 11258ca:	vpshufb %ymm2,%ymm1,%ymm1
 11258cf:	vpermq $0x4e,%ymm1,%ymm1
 11258d5:	vmovdqu %ymm1,(%rcx,%r13,2)
 11258db:	vpshufb %ymm2,%ymm0,%ymm0
 11258e0:	vpermq $0x4e,%ymm0,%ymm0
 11258e6:	vmovdqu %ymm0,(%rbx)
 11258ea:	add    $0xfffffffffffffff0,%r13
 11258ee:	add    $0x20,%rbx
 11258f2:	mov    %r12,%r8
 11258f5:	add    %r13,%r8
 11258f8:	jne    11258c0 <sort.block.block__anon_39129+0x8580>
 11258fa:	sub    %r13,%r14
 11258fd:	mov    -0x98(%rbp),%r13
 1125904:	mov    %r14,%rbx
 1125907:	sub    %r11,%rbx
 112590a:	jae    1125a5d <sort.block.block__anon_39129+0x871d>
 1125910:	mov    %r11d,%ecx
 1125913:	sub    %r14d,%ecx
 1125916:	and    $0x3,%ecx
 1125919:	je     112598a <sort.block.block__anon_39129+0x864a>
 112591b:	lea    (%r9,%r9,1),%r8
 112591f:	lea    (%r8,%rdx,2),%r12
 1125923:	sub    %r14,%r12
 1125926:	sub    %r14,%r12
 1125929:	sub    %rdi,%r12
 112592c:	sub    %rdi,%r12
 112592f:	add    %r10,%r10
 1125932:	sub    %r10,%r12
 1125935:	add    -0x48(%rbp),%r12
 1125939:	lea    (%r8,%r14,2),%r10
 112593d:	add    -0x50(%rbp),%r10
 1125941:	neg    %rcx
 1125944:	xor    %r13d,%r13d
 1125947:	nopw   0x0(%rax,%rax,1)
 1125950:	movzbl -0x1(%r10),%r8d
 1125955:	movzbl -0x1(%r12,%r13,2),%esi
 112595b:	mov    %sil,-0x1(%r10)
 112595f:	mov    %r8b,-0x1(%r12,%r13,2)
 1125964:	movzbl (%r10),%esi
 1125968:	movzbl (%r12,%r13,2),%r8d
 112596d:	mov    %r8b,(%r10)
 1125970:	mov    %sil,(%r12,%r13,2)
 1125974:	dec    %r13
 1125977:	add    $0x2,%r10
 112597b:	cmp    %r13,%rcx
 112597e:	jne    1125950 <sort.block.block__anon_39129+0x8610>
 1125980:	sub    %r13,%r14
 1125983:	mov    -0x98(%rbp),%r13
 112598a:	cmp    $0xfffffffffffffffc,%rbx
 112598e:	ja     1125a5d <sort.block.block__anon_39129+0x871d>
 1125994:	mov    -0x80(%rbp),%rcx
 1125998:	lea    (%rcx,%r9,2),%rcx
 112599c:	add    %r15,%r15
 112599f:	lea    (%r15,%r9,2),%r10
 11259a3:	sub    %r14,%r10
 11259a6:	sub    %r14,%r10
 11259a9:	add    -0x48(%rbp),%r10
 11259ad:	nopl   (%rax)
 11259b0:	movzbl -0x7(%rcx,%r14,2),%esi
 11259b6:	movzbl -0x1(%r10),%r8d
 11259bb:	mov    %r8b,-0x7(%rcx,%r14,2)
 11259c0:	mov    %sil,-0x1(%r10)
 11259c4:	movzbl -0x6(%rcx,%r14,2),%esi
 11259ca:	movzbl (%r10),%r8d
 11259ce:	mov    %r8b,-0x6(%rcx,%r14,2)
 11259d3:	mov    %sil,(%r10)
 11259d6:	movzbl -0x5(%rcx,%r14,2),%esi
 11259dc:	movzbl -0x3(%r10),%r8d
 11259e1:	mov    %r8b,-0x5(%rcx,%r14,2)
 11259e6:	mov    %sil,-0x3(%r10)
 11259ea:	movzbl -0x4(%rcx,%r14,2),%esi
 11259f0:	movzbl -0x2(%r10),%r8d
 11259f5:	mov    %r8b,-0x4(%rcx,%r14,2)
 11259fa:	mov    %sil,-0x2(%r10)
 11259fe:	movzbl -0x3(%rcx,%r14,2),%esi
 1125a04:	movzbl -0x5(%r10),%r8d
 1125a09:	mov    %r8b,-0x3(%rcx,%r14,2)
 1125a0e:	mov    %sil,-0x5(%r10)
 1125a12:	movzbl -0x2(%rcx,%r14,2),%esi
 1125a18:	movzbl -0x4(%r10),%r8d
 1125a1d:	mov    %r8b,-0x2(%rcx,%r14,2)
 1125a22:	mov    %sil,-0x4(%r10)
 1125a26:	movzbl -0x1(%rcx,%r14,2),%esi
 1125a2c:	movzbl -0x7(%r10),%r8d
 1125a31:	mov    %r8b,-0x1(%rcx,%r14,2)
 1125a36:	mov    %sil,-0x7(%r10)
 1125a3a:	movzbl (%rcx,%r14,2),%esi
 1125a3f:	movzbl -0x6(%r10),%r8d
 1125a44:	mov    %r8b,(%rcx,%r14,2)
 1125a48:	mov    %sil,-0x6(%r10)
 1125a4c:	add    $0x4,%r14
 1125a50:	add    $0xfffffffffffffff8,%r10
 1125a54:	cmp    %r14,%r11
 1125a57:	jne    11259b0 <sort.block.block__anon_39129+0x8670>
 1125a5d:	mov    %rax,%r10
 1125a60:	shr    %r10
 1125a63:	cmp    $0x20,%rax
 1125a67:	setb   %al
 1125a6a:	cmp    $0xf,%r10
 1125a6e:	sete   %cl
 1125a71:	or     %al,%cl
 1125a73:	je     1125a80 <sort.block.block__anon_39129+0x8740>
 1125a75:	xor    %eax,%eax
 1125a77:	jmp    1125c0f <sort.block.block__anon_39129+0x88cf>
 1125a7c:	nopl   0x0(%rax)
 1125a80:	lea    -0x10(%r10),%rax
 1125a84:	mov    %rax,%r11
 1125a87:	shr    $0x4,%r11
 1125a8b:	inc    %r11
 1125a8e:	cmp    $0x30,%rax
 1125a92:	jae    1125ab0 <sort.block.block__anon_39129+0x8770>
 1125a94:	xor    %eax,%eax
 1125a96:	and    $0x3,%r11d
 1125a9a:	jne    1125baf <sort.block.block__anon_39129+0x886f>
 1125aa0:	jmp    1125c0f <sort.block.block__anon_39129+0x88cf>
 1125aa5:	data16 cs nopw 0x0(%rax,%rax,1)
 1125ab0:	mov    %r11,%rcx
 1125ab3:	movabs $0x1ffffffffffffffc,%rax
 1125abd:	and    %rax,%rcx
 1125ac0:	mov    -0xc8(%rbp),%rax
 1125ac7:	lea    (%rax,%rdi,2),%rbx
 1125acb:	mov    -0x58(%rbp),%rax
 1125acf:	lea    (%rax,%rdx,2),%r14
 1125ad3:	xor    %eax,%eax
 1125ad5:	data16 cs nopw 0x0(%rax,%rax,1)
 1125ae0:	vmovdqu (%r14,%rax,2),%ymm0
 1125ae6:	vmovdqu -0x60(%rbx),%ymm1
 1125aeb:	vpshufb %ymm2,%ymm1,%ymm1
 1125af0:	vpermq $0x4e,%ymm1,%ymm1
 1125af6:	vmovdqu %ymm1,(%r14,%rax,2)
 1125afc:	vpshufb %ymm2,%ymm0,%ymm0
 1125b01:	vpermq $0x4e,%ymm0,%ymm0
 1125b07:	vmovdqu %ymm0,-0x60(%rbx)
 1125b0c:	vmovdqu -0x20(%r14,%rax,2),%ymm0
 1125b13:	vmovdqu -0x40(%rbx),%ymm1
 1125b18:	vpshufb %ymm2,%ymm1,%ymm1
 1125b1d:	vpermq $0x4e,%ymm1,%ymm1
 1125b23:	vmovdqu %ymm1,-0x20(%r14,%rax,2)
 1125b2a:	vpshufb %ymm2,%ymm0,%ymm0
 1125b2f:	vpermq $0x4e,%ymm0,%ymm0
 1125b35:	vmovdqu %ymm0,-0x40(%rbx)
 1125b3a:	vmovdqu -0x40(%r14,%rax,2),%ymm0
 1125b41:	vmovdqu -0x20(%rbx),%ymm1
 1125b46:	vpshufb %ymm2,%ymm1,%ymm1
 1125b4b:	vpermq $0x4e,%ymm1,%ymm1
 1125b51:	vmovdqu %ymm1,-0x40(%r14,%rax,2)
 1125b58:	vpshufb %ymm2,%ymm0,%ymm0
 1125b5d:	vpermq $0x4e,%ymm0,%ymm0
 1125b63:	vmovdqu %ymm0,-0x20(%rbx)
 1125b68:	vmovdqu -0x60(%r14,%rax,2),%ymm0
 1125b6f:	vmovdqu (%rbx),%ymm1
 1125b73:	vpshufb %ymm2,%ymm1,%ymm1
 1125b78:	vpermq $0x4e,%ymm1,%ymm1
 1125b7e:	vmovdqu %ymm1,-0x60(%r14,%rax,2)
 1125b85:	vpshufb %ymm2,%ymm0,%ymm0
 1125b8a:	vpermq $0x4e,%ymm0,%ymm0
 1125b90:	vmovdqu %ymm0,(%rbx)
 1125b94:	sub    $0xffffffffffffff80,%rbx
 1125b98:	add    $0xffffffffffffffc0,%rax
 1125b9c:	add    $0xfffffffffffffffc,%rcx
 1125ba0:	jne    1125ae0 <sort.block.block__anon_39129+0x87a0>
 1125ba6:	neg    %rax
 1125ba9:	and    $0x3,%r11d
 1125bad:	je     1125c0f <sort.block.block__anon_39129+0x88cf>
 1125baf:	mov    -0x58(%rbp),%rcx
 1125bb3:	lea    (%rcx,%rdx,2),%rbx
 1125bb7:	mov    %rax,%rcx
 1125bba:	neg    %rcx
 1125bbd:	add    %rax,%rax
 1125bc0:	lea    (%rax,%rdi,2),%rax
 1125bc4:	add    -0x38(%rbp),%rax
 1125bc8:	shl    $0x5,%r11d
 1125bcc:	xor    %r14d,%r14d
 1125bcf:	nop
 1125bd0:	vmovdqu (%rbx,%rcx,2),%ymm0
 1125bd5:	vmovdqu (%rax,%r14,1),%ymm1
 1125bdb:	vpshufb %ymm2,%ymm1,%ymm1
 1125be0:	vpermq $0x4e,%ymm1,%ymm1
 1125be6:	vmovdqu %ymm1,(%rbx,%rcx,2)
 1125beb:	vpshufb %ymm2,%ymm0,%ymm0
 1125bf0:	vpermq $0x4e,%ymm0,%ymm0
 1125bf6:	vmovdqu %ymm0,(%rax,%r14,1)
 1125bfc:	add    $0xfffffffffffffff0,%rcx
 1125c00:	add    $0x20,%r14
 1125c04:	cmp    %r14,%r11
 1125c07:	jne    1125bd0 <sort.block.block__anon_39129+0x8890>
 1125c09:	neg    %rcx
 1125c0c:	mov    %rcx,%rax
 1125c0f:	mov    %rax,%rcx
 1125c12:	sub    %r10,%rcx
 1125c15:	jae    1125250 <sort.block.block__anon_39129+0x7f10>
 1125c1b:	mov    %r10d,%r11d
 1125c1e:	sub    %eax,%r11d
 1125c21:	and    $0x3,%r11d
 1125c25:	je     1125c83 <sort.block.block__anon_39129+0x8943>
 1125c27:	mov    -0x48(%rbp),%r8
 1125c2b:	lea    (%r8,%rdx,2),%rbx
 1125c2f:	sub    %rax,%rbx
 1125c32:	sub    %rax,%rbx
 1125c35:	lea    (%rdi,%rdi,1),%rsi
 1125c39:	lea    (%rsi,%rax,2),%r14
 1125c3d:	add    -0x50(%rbp),%r14
 1125c41:	neg    %r11
 1125c44:	xor    %r15d,%r15d
 1125c47:	nopw   0x0(%rax,%rax,1)
 1125c50:	movzbl -0x1(%r14),%esi
 1125c55:	movzbl -0x1(%rbx,%r15,2),%r8d
 1125c5b:	mov    %r8b,-0x1(%r14)
 1125c5f:	mov    %sil,-0x1(%rbx,%r15,2)
 1125c64:	movzbl (%r14),%esi
 1125c68:	movzbl (%rbx,%r15,2),%r8d
 1125c6d:	mov    %r8b,(%r14)
 1125c70:	mov    %sil,(%rbx,%r15,2)
 1125c74:	dec    %r15
 1125c77:	add    $0x2,%r14
 1125c7b:	cmp    %r15,%r11
 1125c7e:	jne    1125c50 <sort.block.block__anon_39129+0x8910>
 1125c80:	sub    %r15,%rax
 1125c83:	cmp    $0xfffffffffffffffc,%rcx
 1125c87:	ja     1125250 <sort.block.block__anon_39129+0x7f10>
 1125c8d:	mov    -0x80(%rbp),%rcx
 1125c91:	lea    (%rcx,%rdi,2),%rcx
 1125c95:	mov    -0x48(%rbp),%r8
 1125c99:	lea    (%r8,%rdx,2),%r11
 1125c9d:	sub    %rax,%r11
 1125ca0:	sub    %rax,%r11
 1125ca3:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1125cb0:	movzbl -0x7(%rcx,%rax,2),%esi
 1125cb5:	movzbl -0x1(%r11),%r8d
 1125cba:	mov    %r8b,-0x7(%rcx,%rax,2)
 1125cbf:	mov    %sil,-0x1(%r11)
 1125cc3:	movzbl -0x6(%rcx,%rax,2),%esi
 1125cc8:	movzbl (%r11),%r8d
 1125ccc:	mov    %r8b,-0x6(%rcx,%rax,2)
 1125cd1:	mov    %sil,(%r11)
 1125cd4:	movzbl -0x5(%rcx,%rax,2),%esi
 1125cd9:	movzbl -0x3(%r11),%r8d
 1125cde:	mov    %r8b,-0x5(%rcx,%rax,2)
 1125ce3:	mov    %sil,-0x3(%r11)
 1125ce7:	movzbl -0x4(%rcx,%rax,2),%esi
 1125cec:	movzbl -0x2(%r11),%r8d
 1125cf1:	mov    %r8b,-0x4(%rcx,%rax,2)
 1125cf6:	mov    %sil,-0x2(%r11)
 1125cfa:	movzbl -0x3(%rcx,%rax,2),%esi
 1125cff:	movzbl -0x5(%r11),%r8d
 1125d04:	mov    %r8b,-0x3(%rcx,%rax,2)
 1125d09:	mov    %sil,-0x5(%r11)
 1125d0d:	movzbl -0x2(%rcx,%rax,2),%esi
 1125d12:	movzbl -0x4(%r11),%r8d
 1125d17:	mov    %r8b,-0x2(%rcx,%rax,2)
 1125d1c:	mov    %sil,-0x4(%r11)
 1125d20:	movzbl -0x1(%rcx,%rax,2),%esi
 1125d25:	movzbl -0x7(%r11),%r8d
 1125d2a:	mov    %r8b,-0x1(%rcx,%rax,2)
 1125d2f:	mov    %sil,-0x7(%r11)
 1125d33:	movzbl (%rcx,%rax,2),%esi
 1125d37:	movzbl -0x6(%r11),%r8d
 1125d3c:	mov    %r8b,(%rcx,%rax,2)
 1125d40:	mov    %sil,-0x6(%r11)
 1125d44:	add    $0x4,%rax
 1125d48:	add    $0xfffffffffffffff8,%r11
 1125d4c:	cmp    %rax,%r10
 1125d4f:	jne    1125cb0 <sort.block.block__anon_39129+0x8970>
 1125d55:	jmp    1125250 <sort.block.block__anon_39129+0x7f10>
 1125d5a:	nopw   0x0(%rax,%rax,1)
 1125d60:	jae    1125200 <sort.block.block__anon_39129+0x7ec0>
 1125d66:	test   %r10,%r10
 1125d69:	je     1125200 <sort.block.block__anon_39129+0x7ec0>
 1125d6f:	mov    0x18(%rax),%rdi
 1125d73:	mov    0x20(%rax),%r8
 1125d77:	mov    %r8,%rdx
 1125d7a:	sub    %r10,%rdx
 1125d7d:	mov    %rdi,-0x68(%rbp)
 1125d81:	jmp    1125dab <sort.block.block__anon_39129+0x8a6b>
 1125d83:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1125d90:	not    %rax
 1125d93:	add    %rax,%r8
 1125d96:	mov    -0x40(%rbp),%rsi
 1125d9a:	add    $0xfffffffffffffffe,%rsi
 1125d9e:	cmp    %rdx,%r8
 1125da1:	mov    -0x68(%rbp),%rdi
 1125da5:	je     1125200 <sort.block.block__anon_39129+0x7ec0>
 1125dab:	mov    %rsi,-0x40(%rbp)
 1125daf:	mov    %rdx,%r9
 1125db2:	mov    %rdx,%rax
 1125db5:	sub    %rdi,%rax
 1125db8:	je     1125f10 <sort.block.block__anon_39129+0x8bd0>
 1125dbe:	movzwl 0x0(%r13,%r8,2),%r15d
 1125dc4:	mov    %rax,%rcx
 1125dc7:	mov    -0x40(%rbp),%rsi
 1125dcb:	or     %rsi,%rcx
 1125dce:	shr    $0x20,%rcx
 1125dd2:	je     1125ddb <sort.block.block__anon_39129+0x8a9b>
 1125dd4:	xor    %edx,%edx
 1125dd6:	div    %rsi
 1125dd9:	jmp    1125ddf <sort.block.block__anon_39129+0x8a9f>
 1125ddb:	xor    %edx,%edx
 1125ddd:	div    %esi
 1125ddf:	cmp    $0x1,%rax
 1125de3:	adc    $0x0,%rax
 1125de7:	lea    (%rax,%rdi,1),%rcx
 1125deb:	mov    -0x30(%rbp),%rdx
 1125def:	mov    (%rdx),%r10
 1125df2:	mov    %r15d,%r14d
 1125df5:	shl    $0x4,%r14d
 1125df9:	add    %r10,%r14
 1125dfc:	mov    %r9,%rdx
 1125dff:	nop
 1125e00:	sub    %rax,%rdx
 1125e03:	mov    %rdx,%r12
 1125e06:	sub    %rdi,%r12
 1125e09:	jbe    1125e9e <sort.block.block__anon_39129+0x8b5e>
 1125e0f:	movzwl 0x0(%r13,%rdx,2),%ebx
 1125e15:	mov    (%r14),%r11
 1125e18:	shl    $0x4,%ebx
 1125e1b:	cmp    (%r10,%rbx,1),%r11
 1125e1f:	jne    1125e2d <sort.block.block__anon_39129+0x8aed>
 1125e21:	add    %r10,%rbx
 1125e24:	movzwl 0xe(%r14),%esi
 1125e29:	cmp    0xe(%rbx),%si
 1125e2d:	jae    1125ea1 <sort.block.block__anon_39129+0x8b61>
 1125e2f:	cmp    %rcx,%rdx
 1125e32:	jae    1125e00 <sort.block.block__anon_39129+0x8ac0>
 1125e34:	mov    %rdi,%rdx
 1125e37:	jmp    1125e59 <sort.block.block__anon_39129+0x8b19>
 1125e39:	nopl   0x0(%rax)
 1125e40:	mov    %r12d,%ecx
 1125e43:	and    $0x1,%ecx
 1125e46:	add    %rax,%rcx
 1125e49:	add    %rcx,%rdx
 1125e4c:	cmp    $0x1,%r12
 1125e50:	mov    %rax,%r12
 1125e53:	jbe    1125f10 <sort.block.block__anon_39129+0x8bd0>
 1125e59:	mov    -0x38(%rbp),%rax
 1125e5d:	lea    (%rax,%rdx,2),%rax
 1125e61:	mov    %r12,%rcx
 1125e64:	and    $0xfffffffffffffffe,%rcx
 1125e68:	movzwl (%rcx,%rax,1),%eax
 1125e6c:	shl    $0x4,%eax
 1125e6f:	cmp    (%r10,%rax,1),%r11
 1125e73:	jne    1125e81 <sort.block.block__anon_39129+0x8b41>
 1125e75:	add    %r10,%rax
 1125e78:	movzwl 0xe(%r14),%ecx
 1125e7d:	cmp    0xe(%rax),%cx
 1125e81:	setb   %cl
 1125e84:	mov    %r12,%rax
 1125e87:	shr    %rax
 1125e8a:	test   %cl,%cl
 1125e8c:	je     1125e40 <sort.block.block__anon_39129+0x8b00>
 1125e8e:	xor    %ecx,%ecx
 1125e90:	add    %rcx,%rdx
 1125e93:	cmp    $0x1,%r12
 1125e97:	mov    %rax,%r12
 1125e9a:	ja     1125e59 <sort.block.block__anon_39129+0x8b19>
 1125e9c:	jmp    1125f10 <sort.block.block__anon_39129+0x8bd0>
 1125e9e:	mov    (%r14),%r11
 1125ea1:	shl    $0x4,%r15d
 1125ea5:	lea    (%r10,%r15,1),%rcx
 1125ea9:	add    $0xe,%rcx
 1125ead:	jmp    1125ec6 <sort.block.block__anon_39129+0x8b86>
 1125eaf:	nop
 1125eb0:	mov    %eax,%r14d
 1125eb3:	and    $0x1,%r14d
 1125eb7:	add    %rbx,%r14
 1125eba:	add    %r14,%rdx
 1125ebd:	cmp    $0x2,%rax
 1125ec1:	mov    %rbx,%rax
 1125ec4:	jb     1125f10 <sort.block.block__anon_39129+0x8bd0>
 1125ec6:	mov    -0x38(%rbp),%rsi
 1125eca:	lea    (%rsi,%rdx,2),%rsi
 1125ece:	mov    %rax,%rbx
 1125ed1:	and    $0xfffffffffffffffe,%rbx
 1125ed5:	movzwl (%rbx,%rsi,1),%ebx
 1125ed9:	shl    $0x4,%ebx
 1125edc:	cmp    (%r10,%rbx,1),%r11
 1125ee0:	jne    1125eec <sort.block.block__anon_39129+0x8bac>
 1125ee2:	add    %r10,%rbx
 1125ee5:	movzwl (%rcx),%esi
 1125ee8:	cmp    0xe(%rbx),%si
 1125eec:	setb   %r14b
 1125ef0:	mov    %rax,%rbx
 1125ef3:	shr    %rbx
 1125ef6:	test   %r14b,%r14b
 1125ef9:	je     1125eb0 <sort.block.block__anon_39129+0x8b70>
 1125efb:	xor    %r14d,%r14d
 1125efe:	add    %r14,%rdx
 1125f01:	cmp    $0x2,%rax
 1125f05:	mov    %rbx,%rax
 1125f08:	jae    1125ec6 <sort.block.block__anon_39129+0x8b86>
 1125f0a:	nopw   0x0(%rax,%rax,1)
 1125f10:	mov    %r9,%rax
 1125f13:	sub    %rdx,%rax
 1125f16:	mov    %rax,%r10
 1125f19:	shr    %r10
 1125f1c:	cmp    $0x20,%rax
 1125f20:	setb   %cl
 1125f23:	cmp    $0xf,%r10
 1125f27:	sete   %sil
 1125f2b:	or     %cl,%sil
 1125f2e:	je     1125f40 <sort.block.block__anon_39129+0x8c00>
 1125f30:	xor    %r11d,%r11d
 1125f33:	jmp    11260cf <sort.block.block__anon_39129+0x8d8f>
 1125f38:	nopl   0x0(%rax,%rax,1)
 1125f40:	lea    -0x10(%r10),%rcx
 1125f44:	mov    %rcx,%r14
 1125f47:	shr    $0x4,%r14
 1125f4b:	inc    %r14
 1125f4e:	cmp    $0x30,%rcx
 1125f52:	jae    1125f70 <sort.block.block__anon_39129+0x8c30>
 1125f54:	xor    %r11d,%r11d
 1125f57:	and    $0x3,%r14d
 1125f5b:	jne    112606f <sort.block.block__anon_39129+0x8d2f>
 1125f61:	jmp    11260cf <sort.block.block__anon_39129+0x8d8f>
 1125f66:	cs nopw 0x0(%rax,%rax,1)
 1125f70:	mov    %r14,%rcx
 1125f73:	movabs $0x1ffffffffffffffc,%rsi
 1125f7d:	and    %rsi,%rcx
 1125f80:	mov    -0xc8(%rbp),%rsi
 1125f87:	lea    (%rsi,%rdx,2),%rbx
 1125f8b:	mov    -0x58(%rbp),%rsi
 1125f8f:	lea    (%rsi,%r9,2),%r15
 1125f93:	xor    %r11d,%r11d
 1125f96:	cs nopw 0x0(%rax,%rax,1)
 1125fa0:	vmovdqu (%r15,%r11,2),%ymm0
 1125fa6:	vmovdqu -0x60(%rbx),%ymm1
 1125fab:	vpshufb %ymm2,%ymm1,%ymm1
 1125fb0:	vpermq $0x4e,%ymm1,%ymm1
 1125fb6:	vmovdqu %ymm1,(%r15,%r11,2)
 1125fbc:	vpshufb %ymm2,%ymm0,%ymm0
 1125fc1:	vpermq $0x4e,%ymm0,%ymm0
 1125fc7:	vmovdqu %ymm0,-0x60(%rbx)
 1125fcc:	vmovdqu -0x20(%r15,%r11,2),%ymm0
 1125fd3:	vmovdqu -0x40(%rbx),%ymm1
 1125fd8:	vpshufb %ymm2,%ymm1,%ymm1
 1125fdd:	vpermq $0x4e,%ymm1,%ymm1
 1125fe3:	vmovdqu %ymm1,-0x20(%r15,%r11,2)
 1125fea:	vpshufb %ymm2,%ymm0,%ymm0
 1125fef:	vpermq $0x4e,%ymm0,%ymm0
 1125ff5:	vmovdqu %ymm0,-0x40(%rbx)
 1125ffa:	vmovdqu -0x40(%r15,%r11,2),%ymm0
 1126001:	vmovdqu -0x20(%rbx),%ymm1
 1126006:	vpshufb %ymm2,%ymm1,%ymm1
 112600b:	vpermq $0x4e,%ymm1,%ymm1
 1126011:	vmovdqu %ymm1,-0x40(%r15,%r11,2)
 1126018:	vpshufb %ymm2,%ymm0,%ymm0
 112601d:	vpermq $0x4e,%ymm0,%ymm0
 1126023:	vmovdqu %ymm0,-0x20(%rbx)
 1126028:	vmovdqu -0x60(%r15,%r11,2),%ymm0
 112602f:	vmovdqu (%rbx),%ymm1
 1126033:	vpshufb %ymm2,%ymm1,%ymm1
 1126038:	vpermq $0x4e,%ymm1,%ymm1
 112603e:	vmovdqu %ymm1,-0x60(%r15,%r11,2)
 1126045:	vpshufb %ymm2,%ymm0,%ymm0
 112604a:	vpermq $0x4e,%ymm0,%ymm0
 1126050:	vmovdqu %ymm0,(%rbx)
 1126054:	sub    $0xffffffffffffff80,%rbx
 1126058:	add    $0xffffffffffffffc0,%r11
 112605c:	add    $0xfffffffffffffffc,%rcx
 1126060:	jne    1125fa0 <sort.block.block__anon_39129+0x8c60>
 1126066:	neg    %r11
 1126069:	and    $0x3,%r14d
 112606d:	je     11260cf <sort.block.block__anon_39129+0x8d8f>
 112606f:	mov    -0x58(%rbp),%rcx
 1126073:	lea    (%rcx,%r9,2),%rbx
 1126077:	mov    %r11,%rcx
 112607a:	neg    %rcx
 112607d:	add    %r11,%r11
 1126080:	lea    (%r11,%rdx,2),%r11
 1126084:	add    -0x38(%rbp),%r11
 1126088:	shl    $0x5,%r14d
 112608c:	xor    %r15d,%r15d
 112608f:	nop
 1126090:	vmovdqu (%rbx,%rcx,2),%ymm0
 1126095:	vmovdqu (%r11,%r15,1),%ymm1
 112609b:	vpshufb %ymm2,%ymm1,%ymm1
 11260a0:	vpermq $0x4e,%ymm1,%ymm1
 11260a6:	vmovdqu %ymm1,(%rbx,%rcx,2)
 11260ab:	vpshufb %ymm2,%ymm0,%ymm0
 11260b0:	vpermq $0x4e,%ymm0,%ymm0
 11260b6:	vmovdqu %ymm0,(%r11,%r15,1)
 11260bc:	add    $0xfffffffffffffff0,%rcx
 11260c0:	add    $0x20,%r15
 11260c4:	cmp    %r15,%r14
 11260c7:	jne    1126090 <sort.block.block__anon_39129+0x8d50>
 11260c9:	neg    %rcx
 11260cc:	mov    %rcx,%r11
 11260cf:	mov    %r11,%rcx
 11260d2:	sub    %r10,%rcx
 11260d5:	jae    112621d <sort.block.block__anon_39129+0x8edd>
 11260db:	mov    %r10d,%ebx
 11260de:	sub    %r11d,%ebx
 11260e1:	and    $0x3,%ebx
 11260e4:	je     112614a <sort.block.block__anon_39129+0x8e0a>
 11260e6:	lea    (%r11,%r11,1),%rsi
 11260ea:	mov    -0x48(%rbp),%rdi
 11260ee:	lea    (%rdi,%r9,2),%r14
 11260f2:	sub    %rsi,%r14
 11260f5:	lea    (%rsi,%rdx,2),%r15
 11260f9:	add    -0x50(%rbp),%r15
 11260fd:	neg    %rbx
 1126100:	xor    %r12d,%r12d
 1126103:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1126110:	movzbl -0x1(%r15),%esi
 1126115:	movzbl -0x1(%r14,%r12,2),%r13d
 112611b:	mov    %r13b,-0x1(%r15)
 112611f:	mov    %sil,-0x1(%r14,%r12,2)
 1126124:	movzbl (%r15),%esi
 1126128:	movzbl (%r14,%r12,2),%r13d
 112612d:	mov    %r13b,(%r15)
 1126130:	mov    %sil,(%r14,%r12,2)
 1126134:	dec    %r12
 1126137:	add    $0x2,%r15
 112613b:	cmp    %r12,%rbx
 112613e:	jne    1126110 <sort.block.block__anon_39129+0x8dd0>
 1126140:	sub    %r12,%r11
 1126143:	mov    -0x98(%rbp),%r13
 112614a:	cmp    $0xfffffffffffffffc,%rcx
 112614e:	ja     112621d <sort.block.block__anon_39129+0x8edd>
 1126154:	mov    -0x80(%rbp),%rcx
 1126158:	lea    (%rcx,%rdx,2),%rcx
 112615c:	mov    -0x48(%rbp),%rdi
 1126160:	lea    (%rdi,%r9,2),%rbx
 1126164:	sub    %r11,%rbx
 1126167:	sub    %r11,%rbx
 112616a:	nopw   0x0(%rax,%rax,1)
 1126170:	movzbl -0x7(%rcx,%r11,2),%esi
 1126176:	movzbl -0x1(%rbx),%r14d
 112617b:	mov    %r14b,-0x7(%rcx,%r11,2)
 1126180:	mov    %sil,-0x1(%rbx)
 1126184:	movzbl -0x6(%rcx,%r11,2),%esi
 112618a:	movzbl (%rbx),%r14d
 112618e:	mov    %r14b,-0x6(%rcx,%r11,2)
 1126193:	mov    %sil,(%rbx)
 1126196:	movzbl -0x5(%rcx,%r11,2),%esi
 112619c:	movzbl -0x3(%rbx),%r14d
 11261a1:	mov    %r14b,-0x5(%rcx,%r11,2)
 11261a6:	mov    %sil,-0x3(%rbx)
 11261aa:	movzbl -0x4(%rcx,%r11,2),%esi
 11261b0:	movzbl -0x2(%rbx),%r14d
 11261b5:	mov    %r14b,-0x4(%rcx,%r11,2)
 11261ba:	mov    %sil,-0x2(%rbx)
 11261be:	movzbl -0x3(%rcx,%r11,2),%esi
 11261c4:	movzbl -0x5(%rbx),%r14d
 11261c9:	mov    %r14b,-0x3(%rcx,%r11,2)
 11261ce:	mov    %sil,-0x5(%rbx)
 11261d2:	movzbl -0x2(%rcx,%r11,2),%esi
 11261d8:	movzbl -0x4(%rbx),%r14d
 11261dd:	mov    %r14b,-0x2(%rcx,%r11,2)
 11261e2:	mov    %sil,-0x4(%rbx)
 11261e6:	movzbl -0x1(%rcx,%r11,2),%esi
 11261ec:	movzbl -0x7(%rbx),%r14d
 11261f1:	mov    %r14b,-0x1(%rcx,%r11,2)
 11261f6:	mov    %sil,-0x7(%rbx)
 11261fa:	movzbl (%rcx,%r11,2),%esi
 11261ff:	movzbl -0x6(%rbx),%r14d
 1126204:	mov    %r14b,(%rcx,%r11,2)
 1126208:	mov    %sil,-0x6(%rbx)
 112620c:	add    $0x4,%r11
 1126210:	add    $0xfffffffffffffff8,%rbx
 1126214:	cmp    %r11,%r10
 1126217:	jne    1126170 <sort.block.block__anon_39129+0x8e30>
 112621d:	mov    %r8,%r10
 1126220:	sub    %rdx,%r10
 1126223:	mov    %r10,%rcx
 1126226:	sub    %rax,%rcx
 1126229:	mov    %rcx,%r11
 112622c:	shr    %r11
 112622f:	cmp    $0x20,%rcx
 1126233:	setb   %cl
 1126236:	cmp    $0xf,%r11
 112623a:	sete   %sil
 112623e:	or     %cl,%sil
 1126241:	je     1126250 <sort.block.block__anon_39129+0x8f10>
 1126243:	xor    %r14d,%r14d
 1126246:	jmp    11263df <sort.block.block__anon_39129+0x909f>
 112624b:	nopl   0x0(%rax,%rax,1)
 1126250:	lea    -0x10(%r11),%rcx
 1126254:	mov    %rcx,%r15
 1126257:	shr    $0x4,%r15
 112625b:	inc    %r15
 112625e:	cmp    $0x30,%rcx
 1126262:	jae    1126280 <sort.block.block__anon_39129+0x8f40>
 1126264:	xor    %r14d,%r14d
 1126267:	and    $0x3,%r15d
 112626b:	jne    112637f <sort.block.block__anon_39129+0x903f>
 1126271:	jmp    11263df <sort.block.block__anon_39129+0x909f>
 1126276:	cs nopw 0x0(%rax,%rax,1)
 1126280:	mov    %r15,%rcx
 1126283:	movabs $0x1ffffffffffffffc,%rsi
 112628d:	and    %rsi,%rcx
 1126290:	mov    -0xc8(%rbp),%rsi
 1126297:	lea    (%rsi,%r9,2),%rbx
 112629b:	mov    -0x58(%rbp),%rsi
 112629f:	lea    (%rsi,%r8,2),%r12
 11262a3:	xor    %r14d,%r14d
 11262a6:	cs nopw 0x0(%rax,%rax,1)
 11262b0:	vmovdqu (%r12,%r14,2),%ymm0
 11262b6:	vmovdqu -0x60(%rbx),%ymm1
 11262bb:	vpshufb %ymm2,%ymm1,%ymm1
 11262c0:	vpermq $0x4e,%ymm1,%ymm1
 11262c6:	vmovdqu %ymm1,(%r12,%r14,2)
 11262cc:	vpshufb %ymm2,%ymm0,%ymm0
 11262d1:	vpermq $0x4e,%ymm0,%ymm0
 11262d7:	vmovdqu %ymm0,-0x60(%rbx)
 11262dc:	vmovdqu -0x20(%r12,%r14,2),%ymm0
 11262e3:	vmovdqu -0x40(%rbx),%ymm1
 11262e8:	vpshufb %ymm2,%ymm1,%ymm1
 11262ed:	vpermq $0x4e,%ymm1,%ymm1
 11262f3:	vmovdqu %ymm1,-0x20(%r12,%r14,2)
 11262fa:	vpshufb %ymm2,%ymm0,%ymm0
 11262ff:	vpermq $0x4e,%ymm0,%ymm0
 1126305:	vmovdqu %ymm0,-0x40(%rbx)
 112630a:	vmovdqu -0x40(%r12,%r14,2),%ymm0
 1126311:	vmovdqu -0x20(%rbx),%ymm1
 1126316:	vpshufb %ymm2,%ymm1,%ymm1
 112631b:	vpermq $0x4e,%ymm1,%ymm1
 1126321:	vmovdqu %ymm1,-0x40(%r12,%r14,2)
 1126328:	vpshufb %ymm2,%ymm0,%ymm0
 112632d:	vpermq $0x4e,%ymm0,%ymm0
 1126333:	vmovdqu %ymm0,-0x20(%rbx)
 1126338:	vmovdqu -0x60(%r12,%r14,2),%ymm0
 112633f:	vmovdqu (%rbx),%ymm1
 1126343:	vpshufb %ymm2,%ymm1,%ymm1
 1126348:	vpermq $0x4e,%ymm1,%ymm1
 112634e:	vmovdqu %ymm1,-0x60(%r12,%r14,2)
 1126355:	vpshufb %ymm2,%ymm0,%ymm0
 112635a:	vpermq $0x4e,%ymm0,%ymm0
 1126360:	vmovdqu %ymm0,(%rbx)
 1126364:	sub    $0xffffffffffffff80,%rbx
 1126368:	add    $0xffffffffffffffc0,%r14
 112636c:	add    $0xfffffffffffffffc,%rcx
 1126370:	jne    11262b0 <sort.block.block__anon_39129+0x8f70>
 1126376:	neg    %r14
 1126379:	and    $0x3,%r15d
 112637d:	je     11263df <sort.block.block__anon_39129+0x909f>
 112637f:	mov    -0x58(%rbp),%rcx
 1126383:	lea    (%rcx,%r8,2),%rbx
 1126387:	mov    %r14,%rcx
 112638a:	neg    %rcx
 112638d:	add    %r14,%r14
 1126390:	lea    (%r14,%r9,2),%r14
 1126394:	add    -0x38(%rbp),%r14
 1126398:	shl    $0x5,%r15d
 112639c:	xor    %r12d,%r12d
 112639f:	nop
 11263a0:	vmovdqu (%rbx,%rcx,2),%ymm0
 11263a5:	vmovdqu (%r14,%r12,1),%ymm1
 11263ab:	vpshufb %ymm2,%ymm1,%ymm1
 11263b0:	vpermq $0x4e,%ymm1,%ymm1
 11263b6:	vmovdqu %ymm1,(%rbx,%rcx,2)
 11263bb:	vpshufb %ymm2,%ymm0,%ymm0
 11263c0:	vpermq $0x4e,%ymm0,%ymm0
 11263c6:	vmovdqu %ymm0,(%r14,%r12,1)
 11263cc:	add    $0xfffffffffffffff0,%rcx
 11263d0:	add    $0x20,%r12
 11263d4:	cmp    %r12,%r15
 11263d7:	jne    11263a0 <sort.block.block__anon_39129+0x9060>
 11263d9:	neg    %rcx
 11263dc:	mov    %rcx,%r14
 11263df:	mov    %r14,%rcx
 11263e2:	sub    %r11,%rcx
 11263e5:	jae    112652d <sort.block.block__anon_39129+0x91ed>
 11263eb:	mov    %r11d,%ebx
 11263ee:	sub    %r14d,%ebx
 11263f1:	and    $0x3,%ebx
 11263f4:	je     112645e <sort.block.block__anon_39129+0x911e>
 11263f6:	mov    -0x48(%rbp),%rdi
 11263fa:	lea    (%rdi,%r8,2),%r15
 11263fe:	sub    %r14,%r15
 1126401:	sub    %r14,%r15
 1126404:	lea    (%r9,%r9,1),%rsi
 1126408:	lea    (%rsi,%r14,2),%r12
 112640c:	add    -0x50(%rbp),%r12
 1126410:	neg    %rbx
 1126413:	xor    %r13d,%r13d
 1126416:	cs nopw 0x0(%rax,%rax,1)
 1126420:	movzbl -0x1(%r12),%esi
 1126426:	movzbl -0x1(%r15,%r13,2),%edi
 112642c:	mov    %dil,-0x1(%r12)
 1126431:	mov    %sil,-0x1(%r15,%r13,2)
 1126436:	movzbl (%r12),%esi
 112643b:	movzbl (%r15,%r13,2),%edi
 1126440:	mov    %dil,(%r12)
 1126444:	mov    %sil,(%r15,%r13,2)
 1126448:	dec    %r13
 112644b:	add    $0x2,%r12
 112644f:	cmp    %r13,%rbx
 1126452:	jne    1126420 <sort.block.block__anon_39129+0x90e0>
 1126454:	sub    %r13,%r14
 1126457:	mov    -0x98(%rbp),%r13
 112645e:	cmp    $0xfffffffffffffffc,%rcx
 1126462:	ja     112652d <sort.block.block__anon_39129+0x91ed>
 1126468:	mov    -0x80(%rbp),%rcx
 112646c:	lea    (%rcx,%r9,2),%rcx
 1126470:	mov    -0x48(%rbp),%rdi
 1126474:	lea    (%rdi,%r8,2),%r9
 1126478:	sub    %r14,%r9
 112647b:	sub    %r14,%r9
 112647e:	xchg   %ax,%ax
 1126480:	movzbl -0x7(%rcx,%r14,2),%esi
 1126486:	movzbl -0x1(%r9),%edi
 112648b:	mov    %dil,-0x7(%rcx,%r14,2)
 1126490:	mov    %sil,-0x1(%r9)
 1126494:	movzbl -0x6(%rcx,%r14,2),%esi
 112649a:	movzbl (%r9),%edi
 112649e:	mov    %dil,-0x6(%rcx,%r14,2)
 11264a3:	mov    %sil,(%r9)
 11264a6:	movzbl -0x5(%rcx,%r14,2),%esi
 11264ac:	movzbl -0x3(%r9),%edi
 11264b1:	mov    %dil,-0x5(%rcx,%r14,2)
 11264b6:	mov    %sil,-0x3(%r9)
 11264ba:	movzbl -0x4(%rcx,%r14,2),%esi
 11264c0:	movzbl -0x2(%r9),%edi
 11264c5:	mov    %dil,-0x4(%rcx,%r14,2)
 11264ca:	mov    %sil,-0x2(%r9)
 11264ce:	movzbl -0x3(%rcx,%r14,2),%esi
 11264d4:	movzbl -0x5(%r9),%edi
 11264d9:	mov    %dil,-0x3(%rcx,%r14,2)
 11264de:	mov    %sil,-0x5(%r9)
 11264e2:	movzbl -0x2(%rcx,%r14,2),%esi
 11264e8:	movzbl -0x4(%r9),%edi
 11264ed:	mov    %dil,-0x2(%rcx,%r14,2)
 11264f2:	mov    %sil,-0x4(%r9)
 11264f6:	movzbl -0x1(%rcx,%r14,2),%esi
 11264fc:	movzbl -0x7(%r9),%edi
 1126501:	mov    %dil,-0x1(%rcx,%r14,2)
 1126506:	mov    %sil,-0x7(%r9)
 112650a:	movzbl (%rcx,%r14,2),%esi
 112650f:	movzbl -0x6(%r9),%edi
 1126514:	mov    %dil,(%rcx,%r14,2)
 1126518:	mov    %sil,-0x6(%r9)
 112651c:	add    $0x4,%r14
 1126520:	add    $0xfffffffffffffff8,%r9
 1126524:	cmp    %r14,%r11
 1126527:	jne    1126480 <sort.block.block__anon_39129+0x9140>
 112652d:	mov    %r10,%r9
 1126530:	shr    %r9
 1126533:	cmp    $0x20,%r10
 1126537:	setb   %cl
 112653a:	cmp    $0xf,%r9
 112653e:	sete   %sil
 1126542:	or     %cl,%sil
 1126545:	je     1126550 <sort.block.block__anon_39129+0x9210>
 1126547:	xor    %r10d,%r10d
 112654a:	jmp    11266df <sort.block.block__anon_39129+0x939f>
 112654f:	nop
 1126550:	lea    -0x10(%r9),%rcx
 1126554:	mov    %rcx,%r11
 1126557:	shr    $0x4,%r11
 112655b:	inc    %r11
 112655e:	cmp    $0x30,%rcx
 1126562:	jae    1126580 <sort.block.block__anon_39129+0x9240>
 1126564:	xor    %r10d,%r10d
 1126567:	and    $0x3,%r11d
 112656b:	jne    112667f <sort.block.block__anon_39129+0x933f>
 1126571:	jmp    11266df <sort.block.block__anon_39129+0x939f>
 1126576:	cs nopw 0x0(%rax,%rax,1)
 1126580:	mov    %r11,%rcx
 1126583:	movabs $0x1ffffffffffffffc,%rsi
 112658d:	and    %rsi,%rcx
 1126590:	mov    -0xc8(%rbp),%rsi
 1126597:	lea    (%rsi,%rdx,2),%rbx
 112659b:	mov    -0x58(%rbp),%rsi
 112659f:	lea    (%rsi,%r8,2),%r14
 11265a3:	xor    %r10d,%r10d
 11265a6:	cs nopw 0x0(%rax,%rax,1)
 11265b0:	vmovdqu (%r14,%r10,2),%ymm0
 11265b6:	vmovdqu -0x60(%rbx),%ymm1
 11265bb:	vpshufb %ymm2,%ymm1,%ymm1
 11265c0:	vpermq $0x4e,%ymm1,%ymm1
 11265c6:	vmovdqu %ymm1,(%r14,%r10,2)
 11265cc:	vpshufb %ymm2,%ymm0,%ymm0
 11265d1:	vpermq $0x4e,%ymm0,%ymm0
 11265d7:	vmovdqu %ymm0,-0x60(%rbx)
 11265dc:	vmovdqu -0x20(%r14,%r10,2),%ymm0
 11265e3:	vmovdqu -0x40(%rbx),%ymm1
 11265e8:	vpshufb %ymm2,%ymm1,%ymm1
 11265ed:	vpermq $0x4e,%ymm1,%ymm1
 11265f3:	vmovdqu %ymm1,-0x20(%r14,%r10,2)
 11265fa:	vpshufb %ymm2,%ymm0,%ymm0
 11265ff:	vpermq $0x4e,%ymm0,%ymm0
 1126605:	vmovdqu %ymm0,-0x40(%rbx)
 112660a:	vmovdqu -0x40(%r14,%r10,2),%ymm0
 1126611:	vmovdqu -0x20(%rbx),%ymm1
 1126616:	vpshufb %ymm2,%ymm1,%ymm1
 112661b:	vpermq $0x4e,%ymm1,%ymm1
 1126621:	vmovdqu %ymm1,-0x40(%r14,%r10,2)
 1126628:	vpshufb %ymm2,%ymm0,%ymm0
 112662d:	vpermq $0x4e,%ymm0,%ymm0
 1126633:	vmovdqu %ymm0,-0x20(%rbx)
 1126638:	vmovdqu -0x60(%r14,%r10,2),%ymm0
 112663f:	vmovdqu (%rbx),%ymm1
 1126643:	vpshufb %ymm2,%ymm1,%ymm1
 1126648:	vpermq $0x4e,%ymm1,%ymm1
 112664e:	vmovdqu %ymm1,-0x60(%r14,%r10,2)
 1126655:	vpshufb %ymm2,%ymm0,%ymm0
 112665a:	vpermq $0x4e,%ymm0,%ymm0
 1126660:	vmovdqu %ymm0,(%rbx)
 1126664:	sub    $0xffffffffffffff80,%rbx
 1126668:	add    $0xffffffffffffffc0,%r10
 112666c:	add    $0xfffffffffffffffc,%rcx
 1126670:	jne    11265b0 <sort.block.block__anon_39129+0x9270>
 1126676:	neg    %r10
 1126679:	and    $0x3,%r11d
 112667d:	je     11266df <sort.block.block__anon_39129+0x939f>
 112667f:	mov    -0x58(%rbp),%rcx
 1126683:	lea    (%rcx,%r8,2),%rbx
 1126687:	mov    %r10,%rcx
 112668a:	neg    %rcx
 112668d:	add    %r10,%r10
 1126690:	lea    (%r10,%rdx,2),%r10
 1126694:	add    -0x38(%rbp),%r10
 1126698:	shl    $0x5,%r11d
 112669c:	xor    %r14d,%r14d
 112669f:	nop
 11266a0:	vmovdqu (%rbx,%rcx,2),%ymm0
 11266a5:	vmovdqu (%r10,%r14,1),%ymm1
 11266ab:	vpshufb %ymm2,%ymm1,%ymm1
 11266b0:	vpermq $0x4e,%ymm1,%ymm1
 11266b6:	vmovdqu %ymm1,(%rbx,%rcx,2)
 11266bb:	vpshufb %ymm2,%ymm0,%ymm0
 11266c0:	vpermq $0x4e,%ymm0,%ymm0
 11266c6:	vmovdqu %ymm0,(%r10,%r14,1)
 11266cc:	add    $0xfffffffffffffff0,%rcx
 11266d0:	add    $0x20,%r14
 11266d4:	cmp    %r14,%r11
 11266d7:	jne    11266a0 <sort.block.block__anon_39129+0x9360>
 11266d9:	neg    %rcx
 11266dc:	mov    %rcx,%r10
 11266df:	mov    %r10,%rcx
 11266e2:	sub    %r9,%rcx
 11266e5:	jae    1125d90 <sort.block.block__anon_39129+0x8a50>
 11266eb:	mov    %r9d,%r11d
 11266ee:	sub    %r10d,%r11d
 11266f1:	and    $0x3,%r11d
 11266f5:	je     1126753 <sort.block.block__anon_39129+0x9413>
 11266f7:	lea    (%r10,%r10,1),%rsi
 11266fb:	mov    -0x48(%rbp),%rdi
 11266ff:	lea    (%rdi,%r8,2),%rbx
 1126703:	sub    %rsi,%rbx
 1126706:	lea    (%rsi,%rdx,2),%r14
 112670a:	add    -0x50(%rbp),%r14
 112670e:	neg    %r11
 1126711:	xor    %r15d,%r15d
 1126714:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1126720:	movzbl -0x1(%r14),%esi
 1126725:	movzbl -0x1(%rbx,%r15,2),%edi
 112672b:	mov    %dil,-0x1(%r14)
 112672f:	mov    %sil,-0x1(%rbx,%r15,2)
 1126734:	movzbl (%r14),%esi
 1126738:	movzbl (%rbx,%r15,2),%edi
 112673d:	mov    %dil,(%r14)
 1126740:	mov    %sil,(%rbx,%r15,2)
 1126744:	dec    %r15
 1126747:	add    $0x2,%r14
 112674b:	cmp    %r15,%r11
 112674e:	jne    1126720 <sort.block.block__anon_39129+0x93e0>
 1126750:	sub    %r15,%r10
 1126753:	cmp    $0xfffffffffffffffc,%rcx
 1126757:	ja     1125d90 <sort.block.block__anon_39129+0x8a50>
 112675d:	mov    -0x80(%rbp),%rcx
 1126761:	lea    (%rcx,%rdx,2),%rcx
 1126765:	mov    -0x48(%rbp),%rdi
 1126769:	lea    (%rdi,%r8,2),%r11
 112676d:	sub    %r10,%r11
 1126770:	sub    %r10,%r11
 1126773:	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1126780:	movzbl -0x7(%rcx,%r10,2),%esi
 1126786:	movzbl -0x1(%r11),%edi
 112678b:	mov    %dil,-0x7(%rcx,%r10,2)
 1126790:	mov    %sil,-0x1(%r11)
 1126794:	movzbl -0x6(%rcx,%r10,2),%esi
 112679a:	movzbl (%r11),%edi
 112679e:	mov    %dil,-0x6(%rcx,%r10,2)
 11267a3:	mov    %sil,(%r11)
 11267a6:	movzbl -0x5(%rcx,%r10,2),%esi
 11267ac:	movzbl -0x3(%r11),%edi
 11267b1:	mov    %dil,-0x5(%rcx,%r10,2)
 11267b6:	mov    %sil,-0x3(%r11)
 11267ba:	movzbl -0x4(%rcx,%r10,2),%esi
 11267c0:	movzbl -0x2(%r11),%edi
 11267c5:	mov    %dil,-0x4(%rcx,%r10,2)
 11267ca:	mov    %sil,-0x2(%r11)
 11267ce:	movzbl -0x3(%rcx,%r10,2),%esi
 11267d4:	movzbl -0x5(%r11),%edi
 11267d9:	mov    %dil,-0x3(%rcx,%r10,2)
 11267de:	mov    %sil,-0x5(%r11)
 11267e2:	movzbl -0x2(%rcx,%r10,2),%esi
 11267e8:	movzbl -0x4(%r11),%edi
 11267ed:	mov    %dil,-0x2(%rcx,%r10,2)
 11267f2:	mov    %sil,-0x4(%r11)
 11267f6:	movzbl -0x1(%rcx,%r10,2),%esi
 11267fc:	movzbl -0x7(%r11),%edi
 1126801:	mov    %dil,-0x1(%rcx,%r10,2)
 1126806:	mov    %sil,-0x7(%r11)
 112680a:	movzbl (%rcx,%r10,2),%esi
 112680f:	movzbl -0x6(%r11),%edi
 1126814:	mov    %dil,(%rcx,%r10,2)
 1126818:	mov    %sil,-0x6(%r11)
 112681c:	add    $0x4,%r10
 1126820:	add    $0xfffffffffffffff8,%r11
 1126824:	cmp    %r10,%r9
 1126827:	jne    1126780 <sort.block.block__anon_39129+0x9440>
 112682d:	jmp    1125d90 <sort.block.block__anon_39129+0x8a50>
 1126832:	mov    %r9,-0xa0(%rbp)
 1126839:	jmp    11205f6 <sort.block.block__anon_39129+0x32b6>
 112683e:	mov    -0xa8(%rbp),%rax
 1126845:	cmp    %rax,-0x188(%rbp)
 112684c:	jne    112685c <sort.block.block__anon_39129+0x951c>
 112684e:	mov    -0x168(%rbp),%rax
 1126855:	sub    %rax,-0x180(%rbp)
 112685c:	mov    -0xa0(%rbp),%rax
 1126863:	sub    %r9,%rax
 1126866:	mov    %rax,-0xa8(%rbp)
 112686d:	jmp    11205f6 <sort.block.block__anon_39129+0x32b6>
 1126872:	movzwl 0x2(%rdi),%eax
 1126876:	movzwl (%rdi),%ecx
 1126879:	mov    -0x30(%rbp),%rdx
 112687d:	mov    (%rdx),%rsi
 1126880:	mov    %eax,%edx
 1126882:	shl    $0x4,%edx
 1126885:	mov    (%rsi,%rdx,1),%r8
 1126889:	mov    %ecx,%r10d
 112688c:	shl    $0x4,%r10d
 1126890:	mov    (%rsi,%r10,1),%r9
 1126894:	cmp    %r9,%r8
 1126897:	jne    11268a8 <sort.block.block__anon_39129+0x9568>
 1126899:	add    %rsi,%rdx
 112689c:	add    %rsi,%r10
 112689f:	movzwl 0xe(%rdx),%edx
 11268a3:	cmp    0xe(%r10),%dx
 11268a8:	jae    112698d <sort.block.block__anon_39129+0x964d>
 11268ae:	mov    %ecx,%edx
 11268b0:	shr    $0x8,%edx
 11268b3:	mov    %eax,%esi
 11268b5:	shr    $0x8,%esi
 11268b8:	mov    %al,(%rdi)
 11268ba:	mov    %cl,0x2(%rdi)
 11268bd:	mov    %sil,0x1(%rdi)
 11268c1:	mov    %dl,0x3(%rdi)
 11268c4:	jmp    112698d <sort.block.block__anon_39129+0x964d>
 11268c9:	jae    111d3c1 <sort.block.block__anon_39129+0x81>
 11268cf:	mov    %r8d,%ecx
 11268d2:	shr    $0x8,%ecx
 11268d5:	mov    -0x38(%rbp),%r10
 11268d9:	mov    %sil,(%r10)
 11268dc:	mov    %r8b,0x2(%r10)
 11268e0:	mov    %al,0x1(%r10)
 11268e4:	mov    %cl,0x3(%r10)
 11268e8:	movzwl 0x2(%r10),%ecx
 11268ed:	mov    -0x30(%rbp),%rax
 11268f1:	mov    (%rax),%rdx
 11268f4:	mov    %ecx,%eax
 11268f6:	shl    $0x4,%eax
 11268f9:	mov    (%rdx,%rax,1),%rdi
 11268fd:	mov    %ecx,%eax
 11268ff:	shr    $0x8,%eax
 1126902:	mov    %ecx,%esi
 1126904:	movzwl 0x4(%r10),%r8d
 1126909:	mov    %r8d,%r9d
 112690c:	shl    $0x4,%r9d
 1126910:	cmp    %rdi,(%rdx,%r9,1)
 1126914:	jne    1126926 <sort.block.block__anon_39129+0x95e6>
 1126916:	add    %rdx,%r9
 1126919:	shl    $0x4,%ecx
 112691c:	movzwl 0xe(%r9),%edi
 1126921:	cmp    0xe(%rdx,%rcx,1),%di
 1126926:	jae    112698d <sort.block.block__anon_39129+0x964d>
 1126928:	mov    %r8d,%ecx
 112692b:	shr    $0x8,%ecx
 112692e:	mov    %r8b,0x2(%r10)
 1126932:	mov    %sil,0x4(%r10)
 1126936:	mov    %cl,0x3(%r10)
 112693a:	mov    %al,0x5(%r10)
 112693e:	movzwl 0x2(%r10),%eax
 1126943:	movzwl (%r10),%edx
 1126947:	mov    -0x30(%rbp),%rsi
 112694b:	mov    (%rsi),%rdi
 112694e:	mov    %eax,%esi
 1126950:	shl    $0x4,%esi
 1126953:	mov    (%rdi,%rsi,1),%r9
 1126957:	mov    %edx,%r8d
 112695a:	shl    $0x4,%r8d
 112695e:	mov    (%rdi,%r8,1),%r10
 1126962:	cmp    %r10,%r9
 1126965:	jne    1126976 <sort.block.block__anon_39129+0x9636>
 1126967:	add    %rdi,%rsi
 112696a:	add    %rdi,%r8
 112696d:	movzwl 0xe(%rsi),%esi
 1126971:	cmp    0xe(%r8),%si
 1126976:	mov    -0x38(%rbp),%rdi
 112697a:	jae    112698d <sort.block.block__anon_39129+0x964d>
 112697c:	mov    %edx,%esi
 112697e:	shr    $0x8,%esi
 1126981:	mov    %al,(%rdi)
 1126983:	mov    %dl,0x2(%rdi)
 1126986:	mov    %cl,0x1(%rdi)
 1126989:	mov    %sil,0x3(%rdi)
 112698d:	add    $0x628,%rsp
 1126994:	pop    %rbx
 1126995:	pop    %r12
 1126997:	pop    %r13
 1126999:	pop    %r14
 112699b:	pop    %r15
 112699d:	pop    %rbp
 112699e:	vzeroupper 
 11269a1:	ret    

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
