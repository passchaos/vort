
/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/78f0aed58c7f51384364cb890565eb73/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

00000000012177e0 <br.encoder.literal_context_split.chooseModeProposals>:
 12177e0:	55                   	push   %rbp
 12177e1:	48 89 e5             	mov    %rsp,%rbp
 12177e4:	41 57                	push   %r15
 12177e6:	41 56                	push   %r14
 12177e8:	41 55                	push   %r13
 12177ea:	41 54                	push   %r12
 12177ec:	53                   	push   %rbx
 12177ed:	48 81 ec 28 10 03 00 	sub    $0x31028,%rsp
 12177f4:	45 89 cc             	mov    %r9d,%r12d
 12177f7:	4d 89 c7             	mov    %r8,%r15
 12177fa:	48 89 4d 90          	mov    %rcx,-0x70(%rbp)
 12177fe:	48 89 55 98          	mov    %rdx,-0x68(%rbp)
 1217802:	48 89 75 b0          	mov    %rsi,-0x50(%rbp)
 1217806:	48 89 fb             	mov    %rdi,%rbx
 1217809:	4c 8d b5 74 fa ff ff 	lea    -0x58c(%rbp),%r14
 1217810:	48 8d bd 60 f9 fe ff 	lea    -0x106a0(%rbp),%rdi
 1217817:	ba 00 00 01 00       	mov    $0x10000,%edx
 121781c:	31 f6                	xor    %esi,%esi
 121781e:	e8 dd e5 07 00       	call   1295e00 <compiler_rt.memset>
 1217823:	ba 00 04 00 00       	mov    $0x400,%edx
 1217828:	4c 89 f7             	mov    %r14,%rdi
 121782b:	31 f6                	xor    %esi,%esi
 121782d:	e8 ce e5 07 00       	call   1295e00 <compiler_rt.memset>
 1217832:	4d 85 ff             	test   %r15,%r15
 1217835:	0f 84 58 01 00 00    	je     1217993 <br.encoder.literal_context_split.chooseModeProposals+0x1b3>
 121783b:	48 89 5d c8          	mov    %rbx,-0x38(%rbp)
 121783f:	31 d2                	xor    %edx,%edx
 1217841:	41 0f b6 c4          	movzbl %r12b,%eax
 1217845:	89 45 c4             	mov    %eax,-0x3c(%rbp)
 1217848:	45 31 ed             	xor    %r13d,%r13d
 121784b:	4c 89 7d b8          	mov    %r15,-0x48(%rbp)
 121784f:	eb 2a                	jmp    121787b <br.encoder.literal_context_split.chooseModeProposals+0x9b>
 1217851:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1217858:	0f 1f 84 00 00 00 00 
 121785f:	00 
 1217860:	4c 8b 6d a0          	mov    -0x60(%rbp),%r13
 1217864:	4d 01 f5             	add    %r14,%r13
 1217867:	4c 8b 7d b8          	mov    -0x48(%rbp),%r15
 121786b:	48 8b 55 a8          	mov    -0x58(%rbp),%rdx
 121786f:	48 ff c2             	inc    %rdx
 1217872:	4c 39 fa             	cmp    %r15,%rdx
 1217875:	0f 84 0b 01 00 00    	je     1217986 <br.encoder.literal_context_split.chooseModeProposals+0x1a6>
 121787b:	48 8d 04 52          	lea    (%rdx,%rdx,2),%rax
 121787f:	48 c1 e0 05          	shl    $0x5,%rax
 1217883:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 1217887:	4c 8b 24 01          	mov    (%rcx,%rax,1),%r12
 121788b:	4c 8b 74 01 08       	mov    0x8(%rcx,%rax,1),%r14
 1217890:	4c 89 e0             	mov    %r12,%rax
 1217893:	4c 01 f0             	add    %r14,%rax
 1217896:	0f 92 45 d0          	setb   -0x30(%rbp)
 121789a:	0f 82 a1 00 00 00    	jb     1217941 <br.encoder.literal_context_split.chooseModeProposals+0x161>
 12178a0:	48 3b 45 98          	cmp    -0x68(%rbp),%rax
 12178a4:	0f 87 97 00 00 00    	ja     1217941 <br.encoder.literal_context_split.chooseModeProposals+0x161>
 12178aa:	4c 39 e0             	cmp    %r12,%rax
 12178ad:	74 c0                	je     121786f <br.encoder.literal_context_split.chooseModeProposals+0x8f>
 12178af:	48 89 55 a8          	mov    %rdx,-0x58(%rbp)
 12178b3:	4c 89 6d a0          	mov    %r13,-0x60(%rbp)
 12178b7:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 12178bb:	4a 8d 1c 20          	lea    (%rax,%r12,1),%rbx
 12178bf:	49 83 fe 01          	cmp    $0x1,%r14
 12178c3:	49 83 d6 00          	adc    $0x0,%r14
 12178c7:	b8 01 00 00 00       	mov    $0x1,%eax
 12178cc:	4c 29 e0             	sub    %r12,%rax
 12178cf:	48 89 45 88          	mov    %rax,-0x78(%rbp)
 12178d3:	49 f7 dc             	neg    %r12
 12178d6:	45 31 ff             	xor    %r15d,%r15d
 12178d9:	eb 47                	jmp    1217922 <br.encoder.literal_context_split.chooseModeProposals+0x142>
 12178db:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 12178e0:	42 0f b6 4c 3b fe    	movzbl -0x2(%rbx,%r15,1),%ecx
 12178e6:	46 0f b6 2c 3b       	movzbl (%rbx,%r15,1),%r13d
 12178eb:	0f b6 f0             	movzbl %al,%esi
 12178ee:	0f b6 d1             	movzbl %cl,%edx
 12178f1:	8b 7d c4             	mov    -0x3c(%rbp),%edi
 12178f4:	e8 b7 6a fa ff       	call   11be3b0 <br.encoder.literal_context.value>
 12178f9:	c1 e0 0a             	shl    $0xa,%eax
 12178fc:	48 01 e8             	add    %rbp,%rax
 12178ff:	48 05 60 f9 fe ff    	add    $0xfffffffffffef960,%rax
 1217905:	41 c1 e5 02          	shl    $0x2,%r13d
 1217909:	41 ff 44 05 00       	incl   0x0(%r13,%rax,1)
 121790e:	42 ff 84 2d 74 fa ff 	incl   -0x58c(%rbp,%r13,1)
 1217915:	ff 
 1217916:	49 ff c7             	inc    %r15
 1217919:	4d 39 fe             	cmp    %r15,%r14
 121791c:	0f 84 3e ff ff ff    	je     1217860 <br.encoder.literal_context_split.chooseModeProposals+0x80>
 1217922:	0f b6 45 18          	movzbl 0x18(%rbp),%eax
 1217926:	0f b6 4d 10          	movzbl 0x10(%rbp),%ecx
 121792a:	4d 39 fc             	cmp    %r15,%r12
 121792d:	74 b7                	je     12178e6 <br.encoder.literal_context_split.chooseModeProposals+0x106>
 121792f:	42 0f b6 44 3b ff    	movzbl -0x1(%rbx,%r15,1),%eax
 1217935:	4c 39 7d 88          	cmp    %r15,-0x78(%rbp)
 1217939:	75 a5                	jne    12178e0 <br.encoder.literal_context_split.chooseModeProposals+0x100>
 121793b:	0f b6 4d 18          	movzbl 0x18(%rbp),%ecx
 121793f:	eb a5                	jmp    12178e6 <br.encoder.literal_context_split.chooseModeProposals+0x106>
 1217941:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1217945:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 1217949:	c5 fc 11 80 f0 00 00 	vmovups %ymm0,0xf0(%rax)
 1217950:	00 
 1217951:	c5 fc 11 80 e0 00 00 	vmovups %ymm0,0xe0(%rax)
 1217958:	00 
 1217959:	c5 fc 11 80 c0 00 00 	vmovups %ymm0,0xc0(%rax)
 1217960:	00 
 1217961:	c5 fc 11 80 a0 00 00 	vmovups %ymm0,0xa0(%rax)
 1217968:	00 
 1217969:	c5 fc 11 80 80 00 00 	vmovups %ymm0,0x80(%rax)
 1217970:	00 
 1217971:	c5 fc 11 40 60       	vmovups %ymm0,0x60(%rax)
 1217976:	c5 fc 11 40 40       	vmovups %ymm0,0x40(%rax)
 121797b:	c5 fc 11 40 20       	vmovups %ymm0,0x20(%rax)
 1217980:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1217984:	eb 4c                	jmp    12179d2 <br.encoder.literal_context_split.chooseModeProposals+0x1f2>
 1217986:	49 81 fd 80 00 00 00 	cmp    $0x80,%r13
 121798d:	48 8b 5d c8          	mov    -0x38(%rbp),%rbx
 1217991:	73 54                	jae    12179e7 <br.encoder.literal_context_split.chooseModeProposals+0x207>
 1217993:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1217997:	c5 fc 11 83 f0 00 00 	vmovups %ymm0,0xf0(%rbx)
 121799e:	00 
 121799f:	c5 fc 11 83 e0 00 00 	vmovups %ymm0,0xe0(%rbx)
 12179a6:	00 
 12179a7:	c5 fc 11 83 c0 00 00 	vmovups %ymm0,0xc0(%rbx)
 12179ae:	00 
 12179af:	c5 fc 11 83 a0 00 00 	vmovups %ymm0,0xa0(%rbx)
 12179b6:	00 
 12179b7:	c5 fc 11 83 80 00 00 	vmovups %ymm0,0x80(%rbx)
 12179be:	00 
 12179bf:	c5 fc 11 43 60       	vmovups %ymm0,0x60(%rbx)
 12179c4:	c5 fc 11 43 40       	vmovups %ymm0,0x40(%rbx)
 12179c9:	c5 fc 11 43 20       	vmovups %ymm0,0x20(%rbx)
 12179ce:	c5 fc 11 03          	vmovups %ymm0,(%rbx)
 12179d2:	48 81 c4 28 10 03 00 	add    $0x31028,%rsp
 12179d9:	5b                   	pop    %rbx
 12179da:	41 5c                	pop    %r12
 12179dc:	41 5d                	pop    %r13
 12179de:	41 5e                	pop    %r14
 12179e0:	41 5f                	pop    %r15
 12179e2:	5d                   	pop    %rbp
 12179e3:	c5 f8 77             	vzeroupper 
 12179e6:	c3                   	ret    
 12179e7:	31 c0                	xor    %eax,%eax
 12179e9:	31 c9                	xor    %ecx,%ecx
 12179eb:	eb 10                	jmp    12179fd <br.encoder.literal_context_split.chooseModeProposals+0x21d>
 12179ed:	0f 1f 00             	nopl   (%rax)
 12179f0:	48 83 c1 04          	add    $0x4,%rcx
 12179f4:	48 81 f9 00 01 00 00 	cmp    $0x100,%rcx
 12179fb:	74 66                	je     1217a63 <br.encoder.literal_context_split.chooseModeProposals+0x283>
 12179fd:	83 bc 8d 74 fa ff ff 	cmpl   $0x0,-0x58c(%rbp,%rcx,4)
 1217a04:	00 
 1217a05:	74 0c                	je     1217a13 <br.encoder.literal_context_split.chooseModeProposals+0x233>
 1217a07:	0f b7 d0             	movzwl %ax,%edx
 1217a0a:	88 8c 15 78 fe ff ff 	mov    %cl,-0x188(%rbp,%rdx,1)
 1217a11:	ff c0                	inc    %eax
 1217a13:	83 bc 8d 78 fa ff ff 	cmpl   $0x0,-0x588(%rbp,%rcx,4)
 1217a1a:	00 
 1217a1b:	74 10                	je     1217a2d <br.encoder.literal_context_split.chooseModeProposals+0x24d>
 1217a1d:	0f b7 d0             	movzwl %ax,%edx
 1217a20:	8d 71 01             	lea    0x1(%rcx),%esi
 1217a23:	40 88 b4 15 78 fe ff 	mov    %sil,-0x188(%rbp,%rdx,1)
 1217a2a:	ff 
 1217a2b:	ff c0                	inc    %eax
 1217a2d:	83 bc 8d 7c fa ff ff 	cmpl   $0x0,-0x584(%rbp,%rcx,4)
 1217a34:	00 
 1217a35:	74 10                	je     1217a47 <br.encoder.literal_context_split.chooseModeProposals+0x267>
 1217a37:	0f b7 d0             	movzwl %ax,%edx
 1217a3a:	8d 71 02             	lea    0x2(%rcx),%esi
 1217a3d:	40 88 b4 15 78 fe ff 	mov    %sil,-0x188(%rbp,%rdx,1)
 1217a44:	ff 
 1217a45:	ff c0                	inc    %eax
 1217a47:	83 bc 8d 80 fa ff ff 	cmpl   $0x0,-0x580(%rbp,%rcx,4)
 1217a4e:	00 
 1217a4f:	74 9f                	je     12179f0 <br.encoder.literal_context_split.chooseModeProposals+0x210>
 1217a51:	0f b7 d0             	movzwl %ax,%edx
 1217a54:	8d 71 03             	lea    0x3(%rcx),%esi
 1217a57:	40 88 b4 15 78 fe ff 	mov    %sil,-0x188(%rbp,%rdx,1)
 1217a5e:	ff 
 1217a5f:	ff c0                	inc    %eax
 1217a61:	eb 8d                	jmp    12179f0 <br.encoder.literal_context_split.chooseModeProposals+0x210>
 1217a63:	66 89 85 76 fe ff ff 	mov    %ax,-0x18a(%rbp)
 1217a6a:	48 8d 9d b0 ef fc ff 	lea    -0x31050(%rbp),%rbx
 1217a71:	ba b0 09 02 00       	mov    $0x209b0,%edx
 1217a76:	48 89 df             	mov    %rbx,%rdi
 1217a79:	31 f6                	xor    %esi,%esi
 1217a7b:	e8 80 e3 07 00       	call   1295e00 <compiler_rt.memset>
 1217a80:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 1217a87:	48 8d b5 74 fa ff ff 	lea    -0x58c(%rbp),%rsi
 1217a8e:	4c 8d b5 76 fe ff ff 	lea    -0x18a(%rbp),%r14
 1217a95:	4c 89 f2             	mov    %r14,%rdx
 1217a98:	48 89 d9             	mov    %rbx,%rcx
 1217a9b:	e8 d0 4b ff ff       	call   120c670 <br.encoder.literal_context_split.treeBitCostCached__anon_46145>
 1217aa0:	0f b7 45 80          	movzwl -0x80(%rbp),%eax
 1217aa4:	66 85 c0             	test   %ax,%ax
 1217aa7:	75 47                	jne    1217af0 <br.encoder.literal_context_split.chooseModeProposals+0x310>
 1217aa9:	4c 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%r9
 1217ab0:	4c 8d bd 60 f9 ff ff 	lea    -0x6a0(%rbp),%r15
 1217ab7:	48 8d 95 60 f9 fe ff 	lea    -0x106a0(%rbp),%rdx
 1217abe:	4c 89 ff             	mov    %r15,%rdi
 1217ac1:	8b 75 c4             	mov    -0x3c(%rbp),%esi
 1217ac4:	48 8d 8d 74 fa ff ff 	lea    -0x58c(%rbp),%rcx
 1217acb:	4d 89 e8             	mov    %r13,%r8
 1217ace:	53                   	push   %rbx
 1217acf:	41 56                	push   %r14
 1217ad1:	e8 da 56 ff ff       	call   120d1b0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230>
 1217ad6:	48 83 c4 10          	add    $0x10,%rsp
 1217ada:	ba 10 01 00 00       	mov    $0x110,%edx
 1217adf:	48 8b 7d c8          	mov    -0x38(%rbp),%rdi
 1217ae3:	4c 89 fe             	mov    %r15,%rsi
 1217ae6:	e8 35 e7 07 00       	call   1296220 <compiler_rt.memcpy.memcpyFast>
 1217aeb:	e9 e2 fe ff ff       	jmp    12179d2 <br.encoder.literal_context_split.chooseModeProposals+0x1f2>
 1217af0:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 1217af4:	66 89 81 08 01 00 00 	mov    %ax,0x108(%rcx)
 1217afb:	e9 d2 fe ff ff       	jmp    12179d2 <br.encoder.literal_context_split.chooseModeProposals+0x1f2>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
