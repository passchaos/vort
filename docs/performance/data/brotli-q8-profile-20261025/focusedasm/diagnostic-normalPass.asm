
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

0000000001146f10 <quality_stage_profile.normalPass>:
 1146f10:	55                   	push   %rbp
 1146f11:	48 89 e5             	mov    %rsp,%rbp
 1146f14:	41 57                	push   %r15
 1146f16:	41 56                	push   %r14
 1146f18:	41 55                	push   %r13
 1146f1a:	41 54                	push   %r12
 1146f1c:	53                   	push   %rbx
 1146f1d:	48 83 ec 48          	sub    $0x48,%rsp
 1146f21:	4d 89 cf             	mov    %r9,%r15
 1146f24:	4d 89 c4             	mov    %r8,%r12
 1146f27:	48 89 cb             	mov    %rcx,%rbx
 1146f2a:	49 89 d5             	mov    %rdx,%r13
 1146f2d:	49 89 f6             	mov    %rsi,%r14
 1146f30:	48 89 7d d0          	mov    %rdi,-0x30(%rbp)
 1146f34:	48 8b 01             	mov    (%rcx),%rax
 1146f37:	48 89 45 c8          	mov    %rax,-0x38(%rbp)
 1146f3b:	48 8b 41 08          	mov    0x8(%rcx),%rax
 1146f3f:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 1146f43:	48 8d 7d b0          	lea    -0x50(%rbp),%rdi
 1146f47:	ba 01 00 00 00       	mov    $0x1,%edx
 1146f4c:	41 ff 95 c0 02 00 00 	call   *0x2c0(%r13)
 1146f53:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 1146f57:	48 89 45 a8          	mov    %rax,-0x58(%rbp)
 1146f5b:	48 8d 7d 90          	lea    -0x70(%rbp),%rdi
 1146f5f:	48 89 de             	mov    %rbx,%rsi
 1146f62:	4c 89 e2             	mov    %r12,%rdx
 1146f65:	4c 89 f9             	mov    %r15,%rcx
 1146f68:	e8 f3 27 15 00       	call   1299760 <br.encodePlannedStreamWithOptionsAlloc>
 1146f6d:	0f b7 45 a0          	movzwl -0x60(%rbp),%eax
 1146f71:	66 85 c0             	test   %ax,%ax
 1146f74:	0f 85 b6 00 00 00    	jne    1147030 <quality_stage_profile.normalPass+0x120>
 1146f7a:	48 8b 5d 10          	mov    0x10(%rbp),%rbx
 1146f7e:	4c 8b 65 90          	mov    -0x70(%rbp),%r12
 1146f82:	4c 8b 7d 98          	mov    -0x68(%rbp),%r15
 1146f86:	48 8d 7d b0          	lea    -0x50(%rbp),%rdi
 1146f8a:	4c 89 f6             	mov    %r14,%rsi
 1146f8d:	ba 01 00 00 00       	mov    $0x1,%edx
 1146f92:	41 ff 95 c0 02 00 00 	call   *0x2c0(%r13)
 1146f99:	4c 8b 75 b0          	mov    -0x50(%rbp),%r14
 1146f9d:	4d 85 ff             	test   %r15,%r15
 1146fa0:	b8 01 00 00 00       	mov    $0x1,%eax
 1146fa5:	4c 89 e7             	mov    %r12,%rdi
 1146fa8:	48 0f 44 f8          	cmove  %rax,%rdi
 1146fac:	48 8b 4d 18          	mov    0x18(%rbp),%rcx
 1146fb0:	48 85 c9             	test   %rcx,%rcx
 1146fb3:	48 0f 44 d8          	cmove  %rax,%rbx
 1146fb7:	4c 89 fe             	mov    %r15,%rsi
 1146fba:	48 89 da             	mov    %rbx,%rdx
 1146fbd:	e8 1e f7 0b 00       	call   12066e0 <mem.eqlBytes>
 1146fc2:	a8 01                	test   $0x1,%al
 1146fc4:	74 2f                	je     1146ff5 <quality_stage_profile.normalPass+0xe5>
 1146fc6:	4c 2b 75 a8          	sub    -0x58(%rbp),%r14
 1146fca:	4d 85 ff             	test   %r15,%r15
 1146fcd:	74 17                	je     1146fe6 <quality_stage_profile.normalPass+0xd6>
 1146fcf:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1146fd3:	48 8b 7d c8          	mov    -0x38(%rbp),%rdi
 1146fd7:	4c 89 e6             	mov    %r12,%rsi
 1146fda:	4c 89 fa             	mov    %r15,%rdx
 1146fdd:	31 c9                	xor    %ecx,%ecx
 1146fdf:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 1146fe3:	ff 50 18             	call   *0x18(%rax)
 1146fe6:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1146fea:	66 c7 40 08 00 00    	movw   $0x0,0x8(%rax)
 1146ff0:	4c 89 30             	mov    %r14,(%rax)
 1146ff3:	eb 2c                	jmp    1147021 <quality_stage_profile.normalPass+0x111>
 1146ff5:	4d 85 ff             	test   %r15,%r15
 1146ff8:	74 17                	je     1147011 <quality_stage_profile.normalPass+0x101>
 1146ffa:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1146ffe:	48 8b 7d c8          	mov    -0x38(%rbp),%rdi
 1147002:	4c 89 e6             	mov    %r12,%rsi
 1147005:	4c 89 fa             	mov    %r15,%rdx
 1147008:	31 c9                	xor    %ecx,%ecx
 114700a:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 114700e:	ff 50 18             	call   *0x18(%rax)
 1147011:	c5 f8 10 05 77 97 eb 	vmovups -0x146889(%rip),%xmm0        # 1000790 <__anon_3305>
 1147018:	ff 
 1147019:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 114701d:	c5 f8 11 00          	vmovups %xmm0,(%rax)
 1147021:	48 83 c4 48          	add    $0x48,%rsp
 1147025:	5b                   	pop    %rbx
 1147026:	41 5c                	pop    %r12
 1147028:	41 5d                	pop    %r13
 114702a:	41 5e                	pop    %r14
 114702c:	41 5f                	pop    %r15
 114702e:	5d                   	pop    %rbp
 114702f:	c3                   	ret    
 1147030:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 1147034:	66 89 41 08          	mov    %ax,0x8(%rcx)
 1147038:	eb e7                	jmp    1147021 <quality_stage_profile.normalPass+0x111>

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
