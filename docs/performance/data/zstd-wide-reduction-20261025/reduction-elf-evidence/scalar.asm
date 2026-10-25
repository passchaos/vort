
/tmp/vort-zstd-wide-reduction-20261025/kernel-bench:     file format elf64-x86-64


Disassembly of section .text:

00000000010bc600 <weighted_bound_bench.query__anon_2994>:
 10bc600:	push   %rbp
 10bc601:	mov    %rsp,%rbp
 10bc604:	push   %r15
 10bc606:	push   %r14
 10bc608:	push   %r13
 10bc60a:	push   %r12
 10bc60c:	push   %rbx
 10bc60d:	mov    $0x1,%r9b
 10bc610:	xor    %r10d,%r10d
 10bc613:	xor    %r11d,%r11d
 10bc616:	xor    %eax,%eax
 10bc618:	xor    %r8d,%r8d
 10bc61b:	xor    %ecx,%ecx
 10bc61d:	jmp    10bc638 <weighted_bound_bench.query__anon_2994+0x38>
 10bc61f:	nop
 10bc620:	mov    %r15b,%bl
 10bc623:	add    %rbx,%r8
 10bc626:	xor    %r14b,%bl
 10bc629:	and    %bl,%r9b
 10bc62c:	inc    %r11
 10bc62f:	cmp    $0x100,%r11
 10bc636:	je     10bc67e <weighted_bound_bench.query__anon_2994+0x7e>
 10bc638:	mov    (%rdx,%r11,4),%r12d
 10bc63c:	movb   $0x0,-0x30(%rbp)
 10bc640:	test   %r10b,%r10b
 10bc643:	jne    10bc68f <weighted_bound_bench.query__anon_2994+0x8f>
 10bc645:	add    %r12,%rax
 10bc648:	cmp    $0x20000,%rax
 10bc64e:	ja     10bc678 <weighted_bound_bench.query__anon_2994+0x78>
 10bc650:	xor    %ebx,%ebx
 10bc652:	test   %r12,%r12
 10bc655:	setne  %r15b
 10bc659:	mov    0x10(%rsi,%r11,4),%r13d
 10bc65e:	test   %r13d,%r13d
 10bc661:	sete   %r14b
 10bc665:	cmp    %r12d,%r13d
 10bc668:	jbe    10bc620 <weighted_bound_bench.query__anon_2994+0x20>
 10bc66a:	sub    %r12d,%r13d
 10bc66d:	add    %r13,%rcx
 10bc670:	setb   -0x30(%rbp)
 10bc674:	jae    10bc620 <weighted_bound_bench.query__anon_2994+0x20>
 10bc676:	jmp    10bc68f <weighted_bound_bench.query__anon_2994+0x8f>
 10bc678:	mov    $0x38,%dx
 10bc67c:	jmp    10bc693 <weighted_bound_bench.query__anon_2994+0x93>
 10bc67e:	and    $0x1,%r9b
 10bc682:	mov    %r9b,-0x40(%rbp)
 10bc686:	mov    %rcx,%rdx
 10bc689:	shr    $0x20,%rdx
 10bc68d:	je     10bc6e1 <weighted_bound_bench.query__anon_2994+0xe1>
 10bc68f:	mov    $0x3a,%dx
 10bc693:	mov    %r8,(%rdi)
 10bc696:	mov    %r9,0x8(%rdi)
 10bc69a:	mov    %r10b,0x10(%rdi)
 10bc69e:	mov    -0x48(%rbp),%r8d
 10bc6a2:	mov    -0x45(%rbp),%r9d
 10bc6a6:	mov    %r8d,0x11(%rdi)
 10bc6aa:	mov    %r9d,0x14(%rdi)
 10bc6ae:	mov    %eax,0x18(%rdi)
 10bc6b1:	mov    %ecx,0x1c(%rdi)
 10bc6b4:	mov    %sil,0x20(%rdi)
 10bc6b8:	mov    -0x58(%rbp),%eax
 10bc6bb:	mov    -0x55(%rbp),%ecx
 10bc6be:	mov    %eax,0x21(%rdi)
 10bc6c1:	mov    %ecx,0x24(%rdi)
 10bc6c4:	mov    %dx,0x28(%rdi)
 10bc6c8:	mov    -0x50(%rbp),%eax
 10bc6cb:	mov    %eax,0x2a(%rdi)
 10bc6ce:	movzwl -0x4c(%rbp),%eax
 10bc6d2:	mov    %ax,0x2e(%rdi)
 10bc6d6:	pop    %rbx
 10bc6d7:	pop    %r12
 10bc6d9:	pop    %r13
 10bc6db:	pop    %r14
 10bc6dd:	pop    %r15
 10bc6df:	pop    %rbp
 10bc6e0:	ret    
 10bc6e1:	movzbl -0x40(%rbp),%edx
 10bc6e5:	and    $0x1,%dl
 10bc6e8:	mov    %dl,-0x38(%rbp)
 10bc6eb:	je     10bc70c <weighted_bound_bench.query__anon_2994+0x10c>
 10bc6ed:	mov    0x8(%rsi),%r9
 10bc6f1:	test   %r9,%r9
 10bc6f4:	js     10bc6fc <weighted_bound_bench.query__anon_2994+0xfc>
 10bc6f6:	xor    %edx,%edx
 10bc6f8:	test   %dl,%dl
 10bc6fa:	je     10bc728 <weighted_bound_bench.query__anon_2994+0x128>
 10bc6fc:	movl   $0x0,-0x45(%rbp)
 10bc703:	movl   $0x0,-0x48(%rbp)
 10bc70a:	jmp    10bc75e <weighted_bound_bench.query__anon_2994+0x15e>
 10bc70c:	movzbl -0x38(%rbp),%esi
 10bc710:	movl   $0x0,-0x48(%rbp)
 10bc717:	movl   $0x0,-0x45(%rbp)
 10bc71e:	xor    %r10d,%r10d
 10bc721:	xor    %edx,%edx
 10bc723:	jmp    10bc693 <weighted_bound_bench.query__anon_2994+0x93>
 10bc728:	mov    0x410(%rsi),%edx
 10bc72e:	mov    %rax,%rsi
 10bc731:	sub    %rdx,%rsi
 10bc734:	add    %rsi,%r9
 10bc737:	seto   -0x30(%rbp)
 10bc73b:	jo     10bc750 <weighted_bound_bench.query__anon_2994+0x150>
 10bc73d:	mov    %rcx,%rdx
 10bc740:	add    %rcx,%rdx
 10bc743:	lea    (%rdx,%rdx,4),%rdx
 10bc747:	sub    %rdx,%r9
 10bc74a:	seto   -0x30(%rbp)
 10bc74e:	jno    10bc784 <weighted_bound_bench.query__anon_2994+0x184>
 10bc750:	movl   $0x0,-0x48(%rbp)
 10bc757:	movl   $0x0,-0x45(%rbp)
 10bc75e:	movl   $0x0,-0x58(%rbp)
 10bc765:	movl   $0x0,-0x55(%rbp)
 10bc76c:	movl   $0x0,-0x50(%rbp)
 10bc773:	movw   $0x0,-0x4c(%rbp)
 10bc779:	mov    $0x3a,%dx
 10bc77d:	xor    %esi,%esi
 10bc77f:	jmp    10bc693 <weighted_bound_bench.query__anon_2994+0x93>
 10bc784:	cmp    %r9,%rax
 10bc787:	cmovg  %rax,%r9
 10bc78b:	movzbl -0x38(%rbp),%esi
 10bc78f:	movl   $0x0,-0x48(%rbp)
 10bc796:	movl   $0x0,-0x45(%rbp)
 10bc79d:	mov    $0x1,%r10b
 10bc7a0:	jmp    10bc721 <weighted_bound_bench.query__anon_2994+0x121>
