
/tmp/vort-zstd-single-price-20261025/micro-bench:     file format elf64-x86-64


Disassembly of section .text:

00000000010bd6f0 <zstd.sequenceCodeForValue>:
 10bd6f0:	mov    $0x10157b0,%eax
 10bd6f5:	xor    %rdx,%rax
 10bd6f8:	mov    $0x1014be0,%r9d
 10bd6fe:	xor    %r8,%r9
 10bd701:	or     %rax,%r9
 10bd704:	jne    10bd72c <zstd.sequenceCodeForValue+0x3c>
 10bd706:	cmp    $0xf,%rsi
 10bd70a:	jbe    10bd9ab <zstd.sequenceCodeForValue+0x2bb>
 10bd710:	cmp    $0x17,%rsi
 10bd714:	ja     10bd7d5 <zstd.sequenceCodeForValue+0xe5>
 10bd71a:	add    $0x1f0,%rsi
 10bd721:	shr    %rsi
 10bd724:	add    $0x10,%esi
 10bd727:	jmp    10bd9ab <zstd.sequenceCodeForValue+0x2bb>
 10bd72c:	mov    $0x1015608,%eax
 10bd731:	xor    %rdx,%rax
 10bd734:	mov    $0x1014c04,%r9d
 10bd73a:	xor    %r8,%r9
 10bd73d:	or     %rax,%r9
 10bd740:	jne    10bd768 <zstd.sequenceCodeForValue+0x78>
 10bd742:	mov    $0x3c,%eax
 10bd747:	xor    %ecx,%ecx
 10bd749:	cmp    $0x3,%rsi
 10bd74d:	jb     10bd9af <zstd.sequenceCodeForValue+0x2bf>
 10bd753:	cmp    $0x22,%rsi
 10bd757:	ja     10bd8dc <zstd.sequenceCodeForValue+0x1ec>
 10bd75d:	add    $0xfd,%esi
 10bd763:	jmp    10bd9ab <zstd.sequenceCodeForValue+0x2bb>
 10bd768:	mov    $0x1015508,%eax
 10bd76d:	xor    %rdx,%rax
 10bd770:	mov    $0x1000860,%r9d
 10bd776:	xor    %r8,%r9
 10bd779:	or     %rax,%r9
 10bd77c:	jne    10bd7f2 <zstd.sequenceCodeForValue+0x102>
 10bd77e:	test   %rsi,%rsi
 10bd781:	je     10bd90d <zstd.sequenceCodeForValue+0x21d>
 10bd787:	mov    $0x3c,%ecx
 10bd78c:	cmp    $0xfffffffffffffffc,%rsi
 10bd790:	ja     10bd8d9 <zstd.sequenceCodeForValue+0x1e9>
 10bd796:	mov    $0xfffffffc,%eax
 10bd79b:	cmp    %rax,%rsi
 10bd79e:	ja     10bd8d9 <zstd.sequenceCodeForValue+0x1e9>
 10bd7a4:	lea    0x3(%rsi),%rax
 10bd7a8:	bsr    %rax,%rax
 10bd7ac:	sub    0x1015508(,%rax,8),%rsi
 10bd7b4:	jb     10bd8d9 <zstd.sequenceCodeForValue+0x1e9>
 10bd7ba:	movzbl 0x1000860(%rax),%edx
 10bd7c1:	shrx   %rdx,%rsi,%rdx
 10bd7c6:	test   %rdx,%rdx
 10bd7c9:	jne    10bd8d9 <zstd.sequenceCodeForValue+0x1e9>
 10bd7cf:	shl    $0x10,%eax
 10bd7d2:	mov    %eax,(%rdi)
 10bd7d4:	ret    
 10bd7d5:	cmp    $0x1f,%rsi
 10bd7d9:	ja     10bd8f4 <zstd.sequenceCodeForValue+0x204>
 10bd7df:	add    $0x3e8,%rsi
 10bd7e6:	shr    $0x2,%rsi
 10bd7ea:	add    $0x14,%esi
 10bd7ed:	jmp    10bd9ab <zstd.sequenceCodeForValue+0x2bb>
 10bd7f2:	push   %rbp
 10bd7f3:	mov    %rsp,%rbp
 10bd7f6:	push   %r15
 10bd7f8:	push   %r14
 10bd7fa:	push   %rbx
 10bd7fb:	mov    %ecx,%r11d
 10bd7fe:	and    $0x3e,%r11d
 10bd802:	xor    %r9d,%r9d
 10bd805:	xor    %r10d,%r10d
 10bd808:	jmp    10bd829 <zstd.sequenceCodeForValue+0x139>
 10bd80a:	lea    0x1(%r10),%rax
 10bd80e:	mov    $0x1,%r9b
 10bd811:	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 10bd820:	add    $0x2,%r10
 10bd824:	cmp    %r10,%r11
 10bd827:	je     10bd891 <zstd.sequenceCodeForValue+0x1a1>
 10bd829:	mov    (%rdx,%r10,8),%rbx
 10bd82d:	mov    %rsi,%r14
 10bd830:	sub    %rbx,%r14
 10bd833:	jb     10bd860 <zstd.sequenceCodeForValue+0x170>
 10bd835:	movzbl (%r8,%r10,1),%r15d
 10bd83a:	shrx   %r15,%r14,%r14
 10bd83f:	test   %r14,%r14
 10bd842:	jne    10bd860 <zstd.sequenceCodeForValue+0x170>
 10bd844:	test   %r9b,%r9b
 10bd847:	je     10bd852 <zstd.sequenceCodeForValue+0x162>
 10bd849:	mov    $0x1,%r9b
 10bd84c:	cmp    (%rdx,%rax,8),%rbx
 10bd850:	jb     10bd860 <zstd.sequenceCodeForValue+0x170>
 10bd852:	mov    $0x1,%r9b
 10bd855:	mov    %r10,%rax
 10bd858:	nopl   0x0(%rax,%rax,1)
 10bd860:	mov    0x8(%rdx,%r10,8),%rbx
 10bd865:	mov    %rsi,%r14
 10bd868:	sub    %rbx,%r14
 10bd86b:	jb     10bd820 <zstd.sequenceCodeForValue+0x130>
 10bd86d:	movzbl 0x1(%r8,%r10,1),%r15d
 10bd873:	shrx   %r15,%r14,%r14
 10bd878:	test   %r14,%r14
 10bd87b:	jne    10bd820 <zstd.sequenceCodeForValue+0x130>
 10bd87d:	test   %r9b,%r9b
 10bd880:	je     10bd80a <zstd.sequenceCodeForValue+0x11a>
 10bd882:	mov    $0x1,%r9b
 10bd885:	cmp    (%rdx,%rax,8),%rbx
 10bd889:	jae    10bd80a <zstd.sequenceCodeForValue+0x11a>
 10bd88f:	jmp    10bd820 <zstd.sequenceCodeForValue+0x130>
 10bd891:	test   $0x1,%cl
 10bd894:	pop    %rbx
 10bd895:	pop    %r14
 10bd897:	pop    %r15
 10bd899:	pop    %rbp
 10bd89a:	je     10bd8c8 <zstd.sequenceCodeForValue+0x1d8>
 10bd89c:	mov    (%rdx,%r10,8),%rcx
 10bd8a0:	sub    %rcx,%rsi
 10bd8a3:	jb     10bd8c8 <zstd.sequenceCodeForValue+0x1d8>
 10bd8a5:	movzbl (%r8,%r10,1),%r8d
 10bd8aa:	shrx   %r8,%rsi,%rsi
 10bd8af:	test   %rsi,%rsi
 10bd8b2:	jne    10bd8c8 <zstd.sequenceCodeForValue+0x1d8>
 10bd8b4:	test   %r9b,%r9b
 10bd8b7:	je     10bd8c2 <zstd.sequenceCodeForValue+0x1d2>
 10bd8b9:	mov    $0x1,%r9b
 10bd8bc:	cmp    (%rdx,%rax,8),%rcx
 10bd8c0:	jb     10bd8c8 <zstd.sequenceCodeForValue+0x1d8>
 10bd8c2:	mov    $0x1,%r9b
 10bd8c5:	mov    %r10,%rax
 10bd8c8:	movzbl %al,%eax
 10bd8cb:	shl    $0x10,%eax
 10bd8ce:	test   %r9b,%r9b
 10bd8d1:	mov    $0x3c,%ecx
 10bd8d6:	cmovne %eax,%ecx
 10bd8d9:	mov    %ecx,(%rdi)
 10bd8db:	ret    
 10bd8dc:	cmp    $0x2a,%rsi
 10bd8e0:	ja     10bd912 <zstd.sequenceCodeForValue+0x222>
 10bd8e2:	add    $0x1dd,%rsi
 10bd8e9:	shr    %rsi
 10bd8ec:	add    $0x20,%esi
 10bd8ef:	jmp    10bd9ab <zstd.sequenceCodeForValue+0x2bb>
 10bd8f4:	cmp    $0x2f,%rsi
 10bd8f8:	ja     10bd92b <zstd.sequenceCodeForValue+0x23b>
 10bd8fa:	add    $0x7e0,%rsi
 10bd901:	shr    $0x3,%rsi
 10bd905:	add    $0x16,%esi
 10bd908:	jmp    10bd9ab <zstd.sequenceCodeForValue+0x2bb>
 10bd90d:	xor    %ecx,%ecx
 10bd90f:	mov    %ecx,(%rdi)
 10bd911:	ret    
 10bd912:	cmp    $0x32,%rsi
 10bd916:	ja     10bd93a <zstd.sequenceCodeForValue+0x24a>
 10bd918:	add    $0x3d5,%rsi
 10bd91f:	shr    $0x2,%rsi
 10bd923:	add    $0x24,%esi
 10bd926:	jmp    10bd9ab <zstd.sequenceCodeForValue+0x2bb>
 10bd92b:	cmp    $0x40,%rsi
 10bd92f:	jae    10bd950 <zstd.sequenceCodeForValue+0x260>
 10bd931:	xor    %eax,%eax
 10bd933:	mov    $0x18,%ecx
 10bd938:	jmp    10bd9af <zstd.sequenceCodeForValue+0x2bf>
 10bd93a:	cmp    $0x42,%rsi
 10bd93e:	ja     10bd997 <zstd.sequenceCodeForValue+0x2a7>
 10bd940:	add    $0x7cd,%rsi
 10bd947:	shr    $0x3,%rsi
 10bd94b:	add    $0x26,%esi
 10bd94e:	jmp    10bd9ab <zstd.sequenceCodeForValue+0x2bb>
 10bd950:	mov    $0x3c,%eax
 10bd955:	xor    %ecx,%ecx
 10bd957:	cmp    $0x1ffff,%rsi
 10bd95e:	ja     10bd9af <zstd.sequenceCodeForValue+0x2bf>
 10bd960:	lzcnt  %rsi,%r8
 10bd965:	mov    $0x52,%edx
 10bd96a:	sub    %r8,%rdx
 10bd96d:	sub    0x10157b0(,%rdx,8),%rsi
 10bd975:	jb     10bd9af <zstd.sequenceCodeForValue+0x2bf>
 10bd977:	movzbl 0x1014be0(%rdx),%eax
 10bd97e:	shrx   %rax,%rsi,%rax
 10bd983:	xor    %ecx,%ecx
 10bd985:	test   %rax,%rax
 10bd988:	cmovne %ecx,%edx
 10bd98b:	mov    $0x3c,%eax
 10bd990:	cmove  %ecx,%eax
 10bd993:	mov    %edx,%ecx
 10bd995:	jmp    10bd9af <zstd.sequenceCodeForValue+0x2bf>
 10bd997:	cmp    $0x62,%rsi
 10bd99b:	ja     10bd9ba <zstd.sequenceCodeForValue+0x2ca>
 10bd99d:	add    $0xfbd,%rsi
 10bd9a4:	shr    $0x4,%rsi
 10bd9a8:	add    $0x28,%esi
 10bd9ab:	xor    %eax,%eax
 10bd9ad:	mov    %esi,%ecx
 10bd9af:	movzbl %cl,%ecx
 10bd9b2:	shl    $0x10,%ecx
 10bd9b5:	or     %eax,%ecx
 10bd9b7:	mov    %ecx,(%rdi)
 10bd9b9:	ret    
 10bd9ba:	cmp    $0x83,%rsi
 10bd9c1:	jae    10bd9cc <zstd.sequenceCodeForValue+0x2dc>
 10bd9c3:	xor    %eax,%eax
 10bd9c5:	mov    $0x2a,%ecx
 10bd9ca:	jmp    10bd9af <zstd.sequenceCodeForValue+0x2bf>
 10bd9cc:	lea    -0x3(%rsi),%rdx
 10bd9d0:	xor    %ecx,%ecx
 10bd9d2:	cmp    $0x1ffff,%rdx
 10bd9d9:	ja     10bd9af <zstd.sequenceCodeForValue+0x2bf>
 10bd9db:	lzcnt  %rdx,%r8
 10bd9e0:	mov    $0x63,%edx
 10bd9e5:	sub    %r8,%rdx
 10bd9e8:	sub    0x1015608(,%rdx,8),%rsi
 10bd9f0:	jb     10bd9af <zstd.sequenceCodeForValue+0x2bf>
 10bd9f2:	movzbl 0x1014c04(%rdx),%eax
 10bd9f9:	jmp    10bd97e <zstd.sequenceCodeForValue+0x28e>
