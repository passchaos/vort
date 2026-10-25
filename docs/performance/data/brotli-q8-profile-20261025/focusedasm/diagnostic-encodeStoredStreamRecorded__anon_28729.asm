
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

00000000012768a0 <br.encodeStoredStreamRecorded__anon_28729>:
 12768a0:	55                   	push   %rbp
 12768a1:	48 89 e5             	mov    %rsp,%rbp
 12768a4:	41 57                	push   %r15
 12768a6:	41 56                	push   %r14
 12768a8:	41 55                	push   %r13
 12768aa:	41 54                	push   %r12
 12768ac:	53                   	push   %rbx
 12768ad:	48 81 ec 98 00 00 00 	sub    $0x98,%rsp
 12768b4:	4d 89 ce             	mov    %r9,%r14
 12768b7:	4d 89 c7             	mov    %r8,%r15
 12768ba:	49 89 cc             	mov    %rcx,%r12
 12768bd:	49 89 d5             	mov    %rdx,%r13
 12768c0:	48 89 fb             	mov    %rdi,%rbx
 12768c3:	c5 fc 10 06          	vmovups (%rsi),%ymm0
 12768c7:	c5 fc 11 85 40 ff ff 	vmovups %ymm0,-0xc0(%rbp)
 12768ce:	ff 
 12768cf:	48 8d bd 60 ff ff ff 	lea    -0xa0(%rbp),%rdi
 12768d6:	48 8d b5 40 ff ff ff 	lea    -0xc0(%rbp),%rsi
 12768dd:	ba 07 00 00 00       	mov    $0x7,%edx
 12768e2:	4c 89 c1             	mov    %r8,%rcx
 12768e5:	45 31 c0             	xor    %r8d,%r8d
 12768e8:	c5 f8 77             	vzeroupper 
 12768eb:	e8 a0 0c 00 00       	call   1277590 <br.encoder.quality_profile.Active.begin>
 12768f0:	48 8d 7d c0          	lea    -0x40(%rbp),%rdi
 12768f4:	4c 89 ee             	mov    %r13,%rsi
 12768f7:	4c 89 e2             	mov    %r12,%rdx
 12768fa:	4c 89 f9             	mov    %r15,%rcx
 12768fd:	4d 89 f0             	mov    %r14,%r8
 1276900:	e8 cb 74 fb ff       	call   122ddd0 <br.encodeStoredStreamWithOptionsAlloc>
 1276905:	44 0f b7 75 d0       	movzwl -0x30(%rbp),%r14d
 127690a:	4d 85 f6             	test   %r14,%r14
 127690d:	75 6c                	jne    127697b <br.encodeStoredStreamRecorded__anon_28729+0xdb>
 127690f:	4c 8b 75 c0          	mov    -0x40(%rbp),%r14
 1276913:	4c 8b 7d c8          	mov    -0x38(%rbp),%r15
 1276917:	80 7d 98 00          	cmpb   $0x0,-0x68(%rbp)
 127691b:	74 33                	je     1276950 <br.encodeStoredStreamRecorded__anon_28729+0xb0>
 127691d:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 1276921:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 1276925:	48 69 d1 18 01 00 00 	imul   $0x118,%rcx,%rdx
 127692c:	4c 89 7c 10 58       	mov    %r15,0x58(%rax,%rdx,1)
 1276931:	c6 44 10 60 01       	movb   $0x1,0x60(%rax,%rdx,1)
 1276936:	4c 89 b4 c8 d0 32 02 	mov    %r14,0x232d0(%rax,%rcx,8)
 127693d:	00 
 127693e:	0f b6 55 b0          	movzbl -0x50(%rbp),%edx
 1276942:	80 e2 0f             	and    $0xf,%dl
 1276945:	80 fa 07             	cmp    $0x7,%dl
 1276948:	0f 94 84 08 d3 42 02 	sete   0x242d3(%rax,%rcx,1)
 127694f:	00 
 1276950:	48 8d bd 60 ff ff ff 	lea    -0xa0(%rbp),%rdi
 1276957:	e8 14 08 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 127695c:	66 c7 43 10 00 00    	movw   $0x0,0x10(%rbx)
 1276962:	4c 89 33             	mov    %r14,(%rbx)
 1276965:	4c 89 7b 08          	mov    %r15,0x8(%rbx)
 1276969:	48 81 c4 98 00 00 00 	add    $0x98,%rsp
 1276970:	5b                   	pop    %rbx
 1276971:	41 5c                	pop    %r12
 1276973:	41 5d                	pop    %r13
 1276975:	41 5e                	pop    %r14
 1276977:	41 5f                	pop    %r15
 1276979:	5d                   	pop    %rbp
 127697a:	c3                   	ret    
 127697b:	80 7d 98 00          	cmpb   $0x0,-0x68(%rbp)
 127697f:	74 20                	je     12769a1 <br.encodeStoredStreamRecorded__anon_28729+0x101>
 1276981:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 1276985:	48 69 4d 90 18 01 00 	imul   $0x118,-0x70(%rbp),%rcx
 127698c:	00 
 127698d:	44 89 f2             	mov    %r14d,%edx
 1276990:	c1 e2 04             	shl    $0x4,%edx
 1276993:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 127699a:	01 
 127699b:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 12769a1:	48 8d bd 60 ff ff ff 	lea    -0xa0(%rbp),%rdi
 12769a8:	e8 c3 07 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 12769ad:	66 44 89 73 10       	mov    %r14w,0x10(%rbx)
 12769b2:	eb b5                	jmp    1276969 <br.encodeStoredStreamRecorded__anon_28729+0xc9>

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
