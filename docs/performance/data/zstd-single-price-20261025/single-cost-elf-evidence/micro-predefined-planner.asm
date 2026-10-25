
/tmp/vort-zstd-single-price-20261025/micro-bench:     file format elf64-x86-64


Disassembly of section .text:

00000000010bda00 <zstd.planPredefinedSequenceValues>:
 10bda00:	push   %rbp
 10bda01:	mov    %rsp,%rbp
 10bda04:	push   %r15
 10bda06:	push   %r14
 10bda08:	push   %r13
 10bda0a:	push   %r12
 10bda0c:	push   %rbx
 10bda0d:	sub    $0x18,%rsp
 10bda11:	mov    %rdi,%rbx
 10bda14:	mov    (%rsi),%rsi
 10bda17:	cmp    $0x1014c3c,%rdx
 10bda1e:	sete   %r9b
 10bda22:	test   %r8b,%r8b
 10bda25:	sete   %al
 10bda28:	and    %al,%r9b
 10bda2b:	cmp    $0x1014f3c,%rdx
 10bda32:	sete   %dil
 10bda36:	cmp    $0x1,%r9b
 10bda3a:	jne    10bda94 <zstd.planPredefinedSequenceValues+0x94>
 10bda3c:	lea    -0x2c(%rbp),%rdi
 10bda40:	mov    $0x10157b0,%edx
 10bda45:	mov    $0x24,%ecx
 10bda4a:	mov    $0x1014be0,%r8d
 10bda50:	call   10bd6f0 <zstd.sequenceCodeForValue>
 10bda55:	cmpw   $0x0,-0x2c(%rbp)
 10bda5a:	jne    10bdc92 <zstd.planPredefinedSequenceValues+0x292>
 10bda60:	movzbl -0x2a(%rbp),%eax
 10bda64:	mov    0x1015140(,%rax,8),%rax
 10bda6c:	test   %rax,%rax
 10bda6f:	je     10bdc92 <zstd.planPredefinedSequenceValues+0x292>
 10bda75:	xor    %ecx,%ecx
 10bda77:	nopw   0x0(%rax,%rax,1)
 10bda80:	blsi   %rax,%rdx
 10bda85:	or     %rdx,%rcx
 10bda88:	blsr   %rax,%rax
 10bda8d:	jne    10bda80 <zstd.planPredefinedSequenceValues+0x80>
 10bda8f:	jmp    10bdc5f <zstd.planPredefinedSequenceValues+0x25f>
 10bda94:	cmp    $0x1014e3c,%rdx
 10bda9b:	sete   %r9b
 10bda9f:	cmp    $0x2,%r8b
 10bdaa3:	sete   %r10b
 10bdaa7:	and    %r9b,%r10b
 10bdaaa:	cmp    $0x1,%r10b
 10bdaae:	jne    10bdb04 <zstd.planPredefinedSequenceValues+0x104>
 10bdab0:	lea    -0x30(%rbp),%rdi
 10bdab4:	mov    $0x1015508,%edx
 10bdab9:	mov    $0x20,%ecx
 10bdabe:	mov    $0x1000860,%r8d
 10bdac4:	call   10bd6f0 <zstd.sequenceCodeForValue>
 10bdac9:	cmpw   $0x0,-0x30(%rbp)
 10bdace:	jne    10bdc92 <zstd.planPredefinedSequenceValues+0x292>
 10bdad4:	movzbl -0x2e(%rbp),%eax
 10bdad8:	mov    0x1015260(,%rax,8),%rax
 10bdae0:	test   %rax,%rax
 10bdae3:	je     10bdc92 <zstd.planPredefinedSequenceValues+0x292>
 10bdae9:	xor    %ecx,%ecx
 10bdaeb:	nopl   0x0(%rax,%rax,1)
 10bdaf0:	blsi   %rax,%rdx
 10bdaf5:	or     %rdx,%rcx
 10bdaf8:	blsr   %rax,%rax
 10bdafd:	jne    10bdaf0 <zstd.planPredefinedSequenceValues+0xf0>
 10bdaff:	jmp    10bdc5f <zstd.planPredefinedSequenceValues+0x25f>
 10bdb04:	and    %al,%dil
 10bdb07:	je     10bdb64 <zstd.planPredefinedSequenceValues+0x164>
 10bdb09:	lea    -0x34(%rbp),%rdi
 10bdb0d:	mov    $0x1015608,%edx
 10bdb12:	mov    $0x35,%ecx
 10bdb17:	mov    $0x1014c04,%r8d
 10bdb1d:	call   10bd6f0 <zstd.sequenceCodeForValue>
 10bdb22:	cmpw   $0x0,-0x34(%rbp)
 10bdb27:	jne    10bdc92 <zstd.planPredefinedSequenceValues+0x292>
 10bdb2d:	movzbl -0x32(%rbp),%eax
 10bdb31:	mov    0x1015360(,%rax,8),%rax
 10bdb39:	test   %rax,%rax
 10bdb3c:	je     10bdc92 <zstd.planPredefinedSequenceValues+0x292>
 10bdb42:	xor    %ecx,%ecx
 10bdb44:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 10bdb50:	blsi   %rax,%rdx
 10bdb55:	or     %rdx,%rcx
 10bdb58:	blsr   %rax,%rax
 10bdb5d:	jne    10bdb50 <zstd.planPredefinedSequenceValues+0x150>
 10bdb5f:	jmp    10bdc5f <zstd.planPredefinedSequenceValues+0x25f>
 10bdb64:	mov    %rbx,-0x40(%rbp)
 10bdb68:	mov    %ecx,%r9d
 10bdb6b:	and    $0x7e,%r9d
 10bdb6f:	xor    %r10d,%r10d
 10bdb72:	mov    $0x2,%r11d
 10bdb78:	mov    $0x1,%r14d
 10bdb7e:	xor    %edi,%edi
 10bdb80:	xor    %eax,%eax
 10bdb82:	jmp    10bdb99 <zstd.planPredefinedSequenceValues+0x199>
 10bdb84:	data16 data16 cs nopw 0x0(%rax,%rax,1)
 10bdb90:	add    $0x2,%rdi
 10bdb94:	cmp    %rdi,%r9
 10bdb97:	je     10bdc04 <zstd.planPredefinedSequenceValues+0x204>
 10bdb99:	mov    (%rdx,%rdi,8),%r15
 10bdb9d:	mov    %r15d,%r13d
 10bdba0:	shr    $0x30,%r15
 10bdba4:	cmp    %r15b,%r8b
 10bdba7:	seta   %bl
 10bdbaa:	mov    %rsi,%r12
 10bdbad:	sub    %r13,%r12
 10bdbb0:	setb   %r13b
 10bdbb4:	or     %bl,%r13b
 10bdbb7:	jne    10bdbcd <zstd.planPredefinedSequenceValues+0x1cd>
 10bdbb9:	shrx   %r15,%r12,%rbx
 10bdbbe:	test   %rbx,%rbx
 10bdbc1:	shlx   %rdi,%r14,%rbx
 10bdbc6:	cmovne %r10,%rbx
 10bdbca:	or     %rbx,%rax
 10bdbcd:	mov    0x8(%rdx,%rdi,8),%r15
 10bdbd2:	mov    %r15d,%ebx
 10bdbd5:	shr    $0x30,%r15
 10bdbd9:	cmp    %r15b,%r8b
 10bdbdc:	seta   %r13b
 10bdbe0:	mov    %rsi,%r12
 10bdbe3:	sub    %rbx,%r12
 10bdbe6:	setb   %bl
 10bdbe9:	or     %r13b,%bl
 10bdbec:	jne    10bdb90 <zstd.planPredefinedSequenceValues+0x190>
 10bdbee:	shrx   %r15,%r12,%rbx
 10bdbf3:	test   %rbx,%rbx
 10bdbf6:	shlx   %rdi,%r11,%rbx
 10bdbfb:	cmovne %r10,%rbx
 10bdbff:	or     %rbx,%rax
 10bdc02:	jmp    10bdb90 <zstd.planPredefinedSequenceValues+0x190>
 10bdc04:	test   $0x1,%cl
 10bdc07:	mov    -0x40(%rbp),%rbx
 10bdc0b:	je     10bdc44 <zstd.planPredefinedSequenceValues+0x244>
 10bdc0d:	mov    (%rdx,%rdi,8),%rcx
 10bdc11:	mov    %ecx,%edx
 10bdc13:	shr    $0x30,%rcx
 10bdc17:	cmp    %cl,%r8b
 10bdc1a:	seta   %r8b
 10bdc1e:	sub    %rdx,%rsi
 10bdc21:	setb   %dl
 10bdc24:	or     %r8b,%dl
 10bdc27:	jne    10bdc44 <zstd.planPredefinedSequenceValues+0x244>
 10bdc29:	shrx   %rcx,%rsi,%rcx
 10bdc2e:	xor    %edx,%edx
 10bdc30:	test   %rcx,%rcx
 10bdc33:	mov    $0x1,%ecx
 10bdc38:	shlx   %rdi,%rcx,%rcx
 10bdc3d:	cmove  %rcx,%rdx
 10bdc41:	or     %rdx,%rax
 10bdc44:	test   %rax,%rax
 10bdc47:	je     10bdc92 <zstd.planPredefinedSequenceValues+0x292>
 10bdc49:	xor    %ecx,%ecx
 10bdc4b:	nopl   0x0(%rax,%rax,1)
 10bdc50:	blsi   %rax,%rdx
 10bdc55:	or     %rdx,%rcx
 10bdc58:	blsr   %rax,%rax
 10bdc5d:	jne    10bdc50 <zstd.planPredefinedSequenceValues+0x250>
 10bdc5f:	test   %rcx,%rcx
 10bdc62:	je     10bdc92 <zstd.planPredefinedSequenceValues+0x292>
 10bdc64:	tzcnt  %rcx,%rax
 10bdc69:	movw   $0x0,0x210(%rbx)
 10bdc72:	movq   $0x1,(%rbx)
 10bdc79:	mov    %al,0x8(%rbx)
 10bdc7c:	movb   $0x1,0x208(%rbx)
 10bdc83:	add    $0x18,%rsp
 10bdc87:	pop    %rbx
 10bdc88:	pop    %r12
 10bdc8a:	pop    %r13
 10bdc8c:	pop    %r14
 10bdc8e:	pop    %r15
 10bdc90:	pop    %rbp
 10bdc91:	ret    
 10bdc92:	mov    $0x218,%edx
 10bdc97:	mov    %rbx,%rdi
 10bdc9a:	xor    %esi,%esi
 10bdc9c:	add    $0x18,%rsp
 10bdca0:	pop    %rbx
 10bdca1:	pop    %r12
 10bdca3:	pop    %r13
 10bdca5:	pop    %r14
 10bdca7:	pop    %r15
 10bdca9:	pop    %rbp
 10bdcaa:	jmp    10c7690 <compiler_rt.memset>
