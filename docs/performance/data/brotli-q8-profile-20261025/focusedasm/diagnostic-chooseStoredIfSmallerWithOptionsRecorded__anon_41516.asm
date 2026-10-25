
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

000000000122dce0 <br.chooseStoredIfSmallerWithOptionsRecorded__anon_41516>:
 122dce0:	55                   	push   %rbp
 122dce1:	48 89 e5             	mov    %rsp,%rbp
 122dce4:	41 57                	push   %r15
 122dce6:	41 56                	push   %r14
 122dce8:	41 55                	push   %r13
 122dcea:	41 54                	push   %r12
 122dcec:	53                   	push   %rbx
 122dced:	48 83 ec 48          	sub    $0x48,%rsp
 122dcf1:	4d 89 ce             	mov    %r9,%r14
 122dcf4:	4c 89 45 d0          	mov    %r8,-0x30(%rbp)
 122dcf8:	49 89 cd             	mov    %rcx,%r13
 122dcfb:	48 89 55 c0          	mov    %rdx,-0x40(%rbp)
 122dcff:	49 89 f4             	mov    %rsi,%r12
 122dd02:	48 89 fb             	mov    %rdi,%rbx
 122dd05:	48 8b 55 10          	mov    0x10(%rbp),%rdx
 122dd09:	48 8d 7d b0          	lea    -0x50(%rbp),%rdi
 122dd0d:	48 89 ce             	mov    %rcx,%rsi
 122dd10:	e8 7b 92 f8 ff       	call   11b6f90 <br.encodedStoredStreamBoundWithOptions>
 122dd15:	44 0f b7 7d b8       	movzwl -0x48(%rbp),%r15d
 122dd1a:	66 45 85 ff          	test   %r15w,%r15w
 122dd1e:	75 7c                	jne    122dd9c <br.chooseStoredIfSmallerWithOptionsRecorded__anon_41516+0xbc>
 122dd20:	4c 3b 75 b0          	cmp    -0x50(%rbp),%r14
 122dd24:	76 56                	jbe    122dd7c <br.chooseStoredIfSmallerWithOptionsRecorded__anon_41516+0x9c>
 122dd26:	48 8d 7d 98          	lea    -0x68(%rbp),%rdi
 122dd2a:	4c 89 e6             	mov    %r12,%rsi
 122dd2d:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 122dd31:	4c 89 e9             	mov    %r13,%rcx
 122dd34:	4c 8b 45 10          	mov    0x10(%rbp),%r8
 122dd38:	e8 93 00 00 00       	call   122ddd0 <br.encodeStoredStreamWithOptionsAlloc>
 122dd3d:	44 0f b7 7d a8       	movzwl -0x58(%rbp),%r15d
 122dd42:	66 45 85 ff          	test   %r15w,%r15w
 122dd46:	75 59                	jne    122dda1 <br.chooseStoredIfSmallerWithOptionsRecorded__anon_41516+0xc1>
 122dd48:	c5 f8 10 45 98       	vmovups -0x68(%rbp),%xmm0
 122dd4d:	c5 f8 29 45 c0       	vmovaps %xmm0,-0x40(%rbp)
 122dd52:	49 8b 3c 24          	mov    (%r12),%rdi
 122dd56:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 122dd5b:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 122dd5f:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 122dd63:	4c 89 f2             	mov    %r14,%rdx
 122dd66:	31 c9                	xor    %ecx,%ecx
 122dd68:	ff 50 18             	call   *0x18(%rax)
 122dd6b:	66 c7 43 10 00 00    	movw   $0x0,0x10(%rbx)
 122dd71:	c5 f8 28 45 c0       	vmovaps -0x40(%rbp),%xmm0
 122dd76:	c5 f8 11 03          	vmovups %xmm0,(%rbx)
 122dd7a:	eb 11                	jmp    122dd8d <br.chooseStoredIfSmallerWithOptionsRecorded__anon_41516+0xad>
 122dd7c:	66 c7 43 10 00 00    	movw   $0x0,0x10(%rbx)
 122dd82:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 122dd86:	48 89 03             	mov    %rax,(%rbx)
 122dd89:	4c 89 73 08          	mov    %r14,0x8(%rbx)
 122dd8d:	48 83 c4 48          	add    $0x48,%rsp
 122dd91:	5b                   	pop    %rbx
 122dd92:	41 5c                	pop    %r12
 122dd94:	41 5d                	pop    %r13
 122dd96:	41 5e                	pop    %r14
 122dd98:	41 5f                	pop    %r15
 122dd9a:	5d                   	pop    %rbp
 122dd9b:	c3                   	ret    
 122dd9c:	4d 85 f6             	test   %r14,%r14
 122dd9f:	74 19                	je     122ddba <br.chooseStoredIfSmallerWithOptionsRecorded__anon_41516+0xda>
 122dda1:	49 8b 3c 24          	mov    (%r12),%rdi
 122dda5:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 122ddaa:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 122ddae:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 122ddb2:	4c 89 f2             	mov    %r14,%rdx
 122ddb5:	31 c9                	xor    %ecx,%ecx
 122ddb7:	ff 50 18             	call   *0x18(%rax)
 122ddba:	66 44 89 7b 10       	mov    %r15w,0x10(%rbx)
 122ddbf:	eb cc                	jmp    122dd8d <br.chooseStoredIfSmallerWithOptionsRecorded__anon_41516+0xad>

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
