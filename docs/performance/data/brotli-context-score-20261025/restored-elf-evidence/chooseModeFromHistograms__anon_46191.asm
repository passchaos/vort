
/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/ee59b567d9fa359fa365d21c6dd4ba7f/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000120cc80 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191>:
 120cc80:	55                   	push   %rbp
 120cc81:	48 89 e5             	mov    %rsp,%rbp
 120cc84:	41 57                	push   %r15
 120cc86:	41 56                	push   %r14
 120cc88:	41 55                	push   %r13
 120cc8a:	41 54                	push   %r12
 120cc8c:	53                   	push   %rbx
 120cc8d:	48 81 ec d8 dd 04 00 	sub    $0x4ddd8,%rsp
 120cc94:	4c 89 8d f0 fe ff ff 	mov    %r9,-0x110(%rbp)
 120cc9b:	4c 89 c3             	mov    %r8,%rbx
 120cc9e:	49 89 cf             	mov    %rcx,%r15
 120cca1:	49 89 d6             	mov    %rdx,%r14
 120cca4:	89 b5 3c ff ff ff    	mov    %esi,-0xc4(%rbp)
 120ccaa:	48 89 bd 28 ff ff ff 	mov    %rdi,-0xd8(%rbp)
 120ccb1:	4c 8b 65 10          	mov    0x10(%rbp),%r12
 120ccb5:	48 8d bd b0 f6 ff ff 	lea    -0x950(%rbp),%rdi
 120ccbc:	ba 00 04 00 00       	mov    $0x400,%edx
 120ccc1:	31 f6                	xor    %esi,%esi
 120ccc3:	e8 78 91 08 00       	call   1295e40 <compiler_rt.memset>
 120ccc8:	45 31 c9             	xor    %r9d,%r9d
 120cccb:	49 89 d8             	mov    %rbx,%r8
 120ccce:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 120ccd2:	c5 fe 7f 85 20 fd ff 	vmovdqu %ymm0,-0x2e0(%rbp)
 120ccd9:	ff 
 120ccda:	c5 fe 7f 85 40 fd ff 	vmovdqu %ymm0,-0x2c0(%rbp)
 120cce1:	ff 
 120cce2:	48 c7 85 5e fd ff ff 	movq   $0x0,-0x2a2(%rbp)
 120cce9:	00 00 00 00 
 120cced:	49 8d 44 24 02       	lea    0x2(%r12),%rax
 120ccf2:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 120ccf9:	48 8d 3d 08 2c ec ff 	lea    -0x13d3f8(%rip),%rdi        # 10cf908 <br.encoder.literal_context_split.precomputed_suffix_map_costs>
 120cd00:	4c 89 f3             	mov    %r14,%rbx
 120cd03:	45 31 d2             	xor    %r10d,%r10d
 120cd06:	48 c7 85 58 ff ff ff 	movq   $0x0,-0xa8(%rbp)
 120cd0d:	00 00 00 00 
 120cd11:	31 c0                	xor    %eax,%eax
 120cd13:	48 c7 85 18 ff ff ff 	movq   $0x0,-0xe8(%rbp)
 120cd1a:	00 00 00 00 
 120cd1e:	48 c7 85 20 ff ff ff 	movq   $0x0,-0xe0(%rbp)
 120cd25:	00 00 00 00 
 120cd29:	4c 89 85 48 ff ff ff 	mov    %r8,-0xb8(%rbp)
 120cd30:	eb 5f                	jmp    120cd91 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x111>
 120cd32:	0f b6 55 d0          	movzbl -0x30(%rbp),%edx
 120cd36:	48 89 95 20 ff ff ff 	mov    %rdx,-0xe0(%rbp)
 120cd3d:	0f b6 55 c7          	movzbl -0x39(%rbp),%edx
 120cd41:	48 89 95 18 ff ff ff 	mov    %rdx,-0xe8(%rbp)
 120cd48:	c5 fe 6f 85 b0 fb ff 	vmovdqu -0x450(%rbp),%ymm0
 120cd4f:	ff 
 120cd50:	c5 fe 6f 8d d0 fb ff 	vmovdqu -0x430(%rbp),%ymm1
 120cd57:	ff 
 120cd58:	c5 fe 7f 85 20 fd ff 	vmovdqu %ymm0,-0x2e0(%rbp)
 120cd5f:	ff 
 120cd60:	c5 fe 7f 8d 40 fd ff 	vmovdqu %ymm1,-0x2c0(%rbp)
 120cd67:	ff 
 120cd68:	b2 01                	mov    $0x1,%dl
 120cd6a:	48 89 95 58 ff ff ff 	mov    %rdx,-0xa8(%rbp)
 120cd71:	48 89 8d 10 ff ff ff 	mov    %rcx,-0xf0(%rbp)
 120cd78:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 120cd7f:	00 
 120cd80:	48 81 c3 00 04 00 00 	add    $0x400,%rbx
 120cd87:	49 83 fa 3f          	cmp    $0x3f,%r10
 120cd8b:	0f 84 fb 02 00 00    	je     120d08c <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x40c>
 120cd91:	4d 89 d5             	mov    %r10,%r13
 120cd94:	ba 03 00 00 00       	mov    $0x3,%edx
 120cd99:	31 c9                	xor    %ecx,%ecx
 120cd9b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 120cda0:	8b 74 93 f4          	mov    -0xc(%rbx,%rdx,4),%esi
 120cda4:	01 b4 95 a4 f6 ff ff 	add    %esi,-0x95c(%rbp,%rdx,4)
 120cdab:	48 01 f1             	add    %rsi,%rcx
 120cdae:	8b 74 93 f8          	mov    -0x8(%rbx,%rdx,4),%esi
 120cdb2:	01 b4 95 a8 f6 ff ff 	add    %esi,-0x958(%rbp,%rdx,4)
 120cdb9:	44 8b 54 93 fc       	mov    -0x4(%rbx,%rdx,4),%r10d
 120cdbe:	44 01 94 95 ac f6 ff 	add    %r10d,-0x954(%rbp,%rdx,4)
 120cdc5:	ff 
 120cdc6:	4c 01 d6             	add    %r10,%rsi
 120cdc9:	48 01 f1             	add    %rsi,%rcx
 120cdcc:	8b 34 93             	mov    (%rbx,%rdx,4),%esi
 120cdcf:	01 b4 95 b0 f6 ff ff 	add    %esi,-0x950(%rbp,%rdx,4)
 120cdd6:	48 01 f1             	add    %rsi,%rcx
 120cdd9:	48 83 c2 04          	add    $0x4,%rdx
 120cddd:	48 81 fa 03 01 00 00 	cmp    $0x103,%rdx
 120cde4:	75 ba                	jne    120cda0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x120>
 120cde6:	4d 8d 55 01          	lea    0x1(%r13),%r10
 120cdea:	49 01 c9             	add    %rcx,%r9
 120cded:	0f 94 c2             	sete   %dl
 120cdf0:	4d 39 c1             	cmp    %r8,%r9
 120cdf3:	40 0f 94 c6          	sete   %sil
 120cdf7:	40 08 d6             	or     %dl,%sil
 120cdfa:	75 84                	jne    120cd80 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x100>
 120cdfc:	48 85 c9             	test   %rcx,%rcx
 120cdff:	0f 95 c1             	setne  %cl
 120ce02:	84 c0                	test   %al,%al
 120ce04:	0f 94 c0             	sete   %al
 120ce07:	08 c8                	or     %cl,%al
 120ce09:	4c 89 da             	mov    %r11,%rdx
 120ce0c:	0f 84 6f 01 00 00    	je     120cf81 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x301>
 120ce12:	4c 89 95 40 ff ff ff 	mov    %r10,-0xc0(%rbp)
 120ce19:	41 0f b7 04 24       	movzwl (%r12),%eax
 120ce1e:	48 85 c0             	test   %rax,%rax
 120ce21:	0f 84 cc 00 00 00    	je     120cef3 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x273>
 120ce27:	66 83 f8 04          	cmp    $0x4,%ax
 120ce2b:	73 07                	jae    120ce34 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1b4>
 120ce2d:	31 c9                	xor    %ecx,%ecx
 120ce2f:	e9 89 00 00 00       	jmp    120cebd <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x23d>
 120ce34:	89 c2                	mov    %eax,%edx
 120ce36:	83 e2 fc             	and    $0xfffffffc,%edx
 120ce39:	31 c9                	xor    %ecx,%ecx
 120ce3b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 120ce40:	41 0f b6 74 0c 02    	movzbl 0x2(%r12,%rcx,1),%esi
 120ce46:	c1 e6 02             	shl    $0x2,%esi
 120ce49:	45 8b 14 37          	mov    (%r15,%rsi,1),%r10d
 120ce4d:	44 2b 94 35 b0 f6 ff 	sub    -0x950(%rbp,%rsi,1),%r10d
 120ce54:	ff 
 120ce55:	44 89 94 35 38 6c fe 	mov    %r10d,-0x193c8(%rbp,%rsi,1)
 120ce5c:	ff 
 120ce5d:	41 0f b6 74 0c 03    	movzbl 0x3(%r12,%rcx,1),%esi
 120ce63:	c1 e6 02             	shl    $0x2,%esi
 120ce66:	45 8b 14 37          	mov    (%r15,%rsi,1),%r10d
 120ce6a:	44 2b 94 35 b0 f6 ff 	sub    -0x950(%rbp,%rsi,1),%r10d
 120ce71:	ff 
 120ce72:	44 89 94 35 38 6c fe 	mov    %r10d,-0x193c8(%rbp,%rsi,1)
 120ce79:	ff 
 120ce7a:	41 0f b6 74 0c 04    	movzbl 0x4(%r12,%rcx,1),%esi
 120ce80:	c1 e6 02             	shl    $0x2,%esi
 120ce83:	45 8b 14 37          	mov    (%r15,%rsi,1),%r10d
 120ce87:	44 2b 94 35 b0 f6 ff 	sub    -0x950(%rbp,%rsi,1),%r10d
 120ce8e:	ff 
 120ce8f:	44 89 94 35 38 6c fe 	mov    %r10d,-0x193c8(%rbp,%rsi,1)
 120ce96:	ff 
 120ce97:	41 0f b6 74 0c 05    	movzbl 0x5(%r12,%rcx,1),%esi
 120ce9d:	c1 e6 02             	shl    $0x2,%esi
 120cea0:	45 8b 14 37          	mov    (%r15,%rsi,1),%r10d
 120cea4:	44 2b 94 35 b0 f6 ff 	sub    -0x950(%rbp,%rsi,1),%r10d
 120ceab:	ff 
 120ceac:	44 89 94 35 38 6c fe 	mov    %r10d,-0x193c8(%rbp,%rsi,1)
 120ceb3:	ff 
 120ceb4:	48 83 c1 04          	add    $0x4,%rcx
 120ceb8:	48 39 ca             	cmp    %rcx,%rdx
 120cebb:	75 83                	jne    120ce40 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c0>
 120cebd:	83 e0 03             	and    $0x3,%eax
 120cec0:	74 31                	je     120cef3 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x273>
 120cec2:	48 03 8d 78 ff ff ff 	add    -0x88(%rbp),%rcx
 120cec9:	31 d2                	xor    %edx,%edx
 120cecb:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 120ced0:	0f b6 34 11          	movzbl (%rcx,%rdx,1),%esi
 120ced4:	c1 e6 02             	shl    $0x2,%esi
 120ced7:	45 8b 14 37          	mov    (%r15,%rsi,1),%r10d
 120cedb:	44 2b 94 35 b0 f6 ff 	sub    -0x950(%rbp,%rsi,1),%r10d
 120cee2:	ff 
 120cee3:	44 89 94 35 38 6c fe 	mov    %r10d,-0x193c8(%rbp,%rsi,1)
 120ceea:	ff 
 120ceeb:	48 ff c2             	inc    %rdx
 120ceee:	48 39 d0             	cmp    %rdx,%rax
 120cef1:	75 dd                	jne    120ced0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x250>
 120cef3:	4c 89 8d 30 ff ff ff 	mov    %r9,-0xd0(%rbp)
 120cefa:	48 8d bd 38 6c ff ff 	lea    -0x93c8(%rbp),%rdi
 120cf01:	48 8d b5 b0 f6 ff ff 	lea    -0x950(%rbp),%rsi
 120cf08:	4c 89 e2             	mov    %r12,%rdx
 120cf0b:	c5 f8 77             	vzeroupper 
 120cf0e:	e8 5d f7 ff ff       	call   120c670 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46128>
 120cf13:	0f b7 85 40 6c ff ff 	movzwl -0x93c0(%rbp),%eax
 120cf1a:	66 85 c0             	test   %ax,%ax
 120cf1d:	0f 85 c4 1d 00 00    	jne    120ece7 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x2067>
 120cf23:	48 8b 85 38 6c ff ff 	mov    -0x93c8(%rbp),%rax
 120cf2a:	48 89 85 70 ff ff ff 	mov    %rax,-0x90(%rbp)
 120cf31:	48 8d bd 38 6c ff ff 	lea    -0x93c8(%rbp),%rdi
 120cf38:	48 8d b5 38 6c fe ff 	lea    -0x193c8(%rbp),%rsi
 120cf3f:	4c 89 e2             	mov    %r12,%rdx
 120cf42:	e8 29 f7 ff ff       	call   120c670 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46128>
 120cf47:	0f b7 85 40 6c ff ff 	movzwl -0x93c0(%rbp),%eax
 120cf4e:	66 85 c0             	test   %ax,%ax
 120cf51:	0f 85 90 1d 00 00    	jne    120ece7 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x2067>
 120cf57:	48 8b 95 70 ff ff ff 	mov    -0x90(%rbp),%rdx
 120cf5e:	48 03 95 38 6c ff ff 	add    -0x93c8(%rbp),%rdx
 120cf65:	4c 8b 85 48 ff ff ff 	mov    -0xb8(%rbp),%r8
 120cf6c:	4c 8b 8d 30 ff ff ff 	mov    -0xd0(%rbp),%r9
 120cf73:	48 8d 3d 8e 29 ec ff 	lea    -0x13d672(%rip),%rdi        # 10cf908 <br.encoder.literal_context_split.precomputed_suffix_map_costs>
 120cf7a:	4c 8b 95 40 ff ff ff 	mov    -0xc0(%rbp),%r10
 120cf81:	31 c0                	xor    %eax,%eax
 120cf83:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120cf8a:	84 00 00 00 00 00 
 120cf90:	4c 39 e8             	cmp    %r13,%rax
 120cf93:	0f 97 84 05 38 6c fe 	seta   -0x193c8(%rbp,%rax,1)
 120cf9a:	ff 
 120cf9b:	0f 93 84 05 39 6c fe 	setae  -0x193c7(%rbp,%rax,1)
 120cfa2:	ff 
 120cfa3:	48 8d 48 02          	lea    0x2(%rax),%rcx
 120cfa7:	4c 39 e9             	cmp    %r13,%rcx
 120cfaa:	0f 97 84 05 3a 6c fe 	seta   -0x193c6(%rbp,%rax,1)
 120cfb1:	ff 
 120cfb2:	48 8d 48 03          	lea    0x3(%rax),%rcx
 120cfb6:	4c 39 e9             	cmp    %r13,%rcx
 120cfb9:	0f 97 84 05 3b 6c fe 	seta   -0x193c5(%rbp,%rax,1)
 120cfc0:	ff 
 120cfc1:	48 8d 48 04          	lea    0x4(%rax),%rcx
 120cfc5:	4c 39 e9             	cmp    %r13,%rcx
 120cfc8:	0f 97 84 05 3c 6c fe 	seta   -0x193c4(%rbp,%rax,1)
 120cfcf:	ff 
 120cfd0:	48 8d 48 05          	lea    0x5(%rax),%rcx
 120cfd4:	4c 39 e9             	cmp    %r13,%rcx
 120cfd7:	0f 97 84 05 3d 6c fe 	seta   -0x193c3(%rbp,%rax,1)
 120cfde:	ff 
 120cfdf:	48 8d 48 06          	lea    0x6(%rax),%rcx
 120cfe3:	4c 39 e9             	cmp    %r13,%rcx
 120cfe6:	0f 97 84 05 3e 6c fe 	seta   -0x193c2(%rbp,%rax,1)
 120cfed:	ff 
 120cfee:	48 8d 48 07          	lea    0x7(%rax),%rcx
 120cff2:	4c 39 e9             	cmp    %r13,%rcx
 120cff5:	0f 97 84 05 3f 6c fe 	seta   -0x193c1(%rbp,%rax,1)
 120cffc:	ff 
 120cffd:	48 83 c0 08          	add    $0x8,%rax
 120d001:	48 83 f8 40          	cmp    $0x40,%rax
 120d005:	75 89                	jne    120cf90 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x310>
 120d007:	8b 85 3c ff ff ff    	mov    -0xc4(%rbp),%eax
 120d00d:	24 03                	and    $0x3,%al
 120d00f:	88 45 d0             	mov    %al,-0x30(%rbp)
 120d012:	c6 45 c7 02          	movb   $0x2,-0x39(%rbp)
 120d016:	c5 fe 6f 85 38 6c fe 	vmovdqu -0x193c8(%rbp),%ymm0
 120d01d:	ff 
 120d01e:	c5 fe 6f 8d 58 6c fe 	vmovdqu -0x193a8(%rbp),%ymm1
 120d025:	ff 
 120d026:	c5 fe 7f 85 b0 fb ff 	vmovdqu %ymm0,-0x450(%rbp)
 120d02d:	ff 
 120d02e:	c5 fe 7f 8d d0 fb ff 	vmovdqu %ymm1,-0x430(%rbp)
 120d035:	ff 
 120d036:	4a 8b 04 d7          	mov    (%rdi,%r10,8),%rax
 120d03a:	49 89 d3             	mov    %rdx,%r11
 120d03d:	48 01 d0             	add    %rdx,%rax
 120d040:	48 8b 95 f0 fe ff ff 	mov    -0x110(%rbp),%rdx
 120d047:	48 29 c2             	sub    %rax,%rdx
 120d04a:	b9 00 00 00 00       	mov    $0x0,%ecx
 120d04f:	48 0f 43 ca          	cmovae %rdx,%rcx
 120d053:	b0 01                	mov    $0x1,%al
 120d055:	48 81 f9 80 00 00 00 	cmp    $0x80,%rcx
 120d05c:	0f 82 1e fd ff ff    	jb     120cd80 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x100>
 120d062:	b0 01                	mov    $0x1,%al
 120d064:	80 bd 58 ff ff ff 00 	cmpb   $0x0,-0xa8(%rbp)
 120d06b:	0f 84 c1 fc ff ff    	je     120cd32 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xb2>
 120d071:	48 3b 8d 10 ff ff ff 	cmp    -0xf0(%rbp),%rcx
 120d078:	0f 87 b4 fc ff ff    	ja     120cd32 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xb2>
 120d07e:	b1 01                	mov    $0x1,%cl
 120d080:	48 89 8d 58 ff ff ff 	mov    %rcx,-0xa8(%rbp)
 120d087:	e9 f4 fc ff ff       	jmp    120cd80 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x100>
 120d08c:	48 8b 85 5e fd ff ff 	mov    -0x2a2(%rbp),%rax
 120d093:	48 89 85 ce fc ff ff 	mov    %rax,-0x332(%rbp)
 120d09a:	c5 fe 6f 85 20 fd ff 	vmovdqu -0x2e0(%rbp),%ymm0
 120d0a1:	ff 
 120d0a2:	c5 fe 6f 8d 40 fd ff 	vmovdqu -0x2c0(%rbp),%ymm1
 120d0a9:	ff 
 120d0aa:	c5 fe 7f 8d b0 fc ff 	vmovdqu %ymm1,-0x350(%rbp)
 120d0b1:	ff 
 120d0b2:	c5 fe 7f 85 90 fc ff 	vmovdqu %ymm0,-0x370(%rbp)
 120d0b9:	ff 
 120d0ba:	c5 fe 7f 85 70 fd ff 	vmovdqu %ymm0,-0x290(%rbp)
 120d0c1:	ff 
 120d0c2:	c5 fe 7f 8d 90 fd ff 	vmovdqu %ymm1,-0x270(%rbp)
 120d0c9:	ff 
 120d0ca:	c5 fe 7f 85 c0 fd ff 	vmovdqu %ymm0,-0x240(%rbp)
 120d0d1:	ff 
 120d0d2:	48 89 85 ae fd ff ff 	mov    %rax,-0x252(%rbp)
 120d0d9:	c5 fe 7f 8d e0 fd ff 	vmovdqu %ymm1,-0x220(%rbp)
 120d0e0:	ff 
 120d0e1:	48 89 85 fe fd ff ff 	mov    %rax,-0x202(%rbp)
 120d0e8:	49 83 c6 04          	add    $0x4,%r14
 120d0ec:	31 c0                	xor    %eax,%eax
 120d0ee:	eb 14                	jmp    120d104 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x484>
 120d0f0:	48 ff c0             	inc    %rax
 120d0f3:	49 81 c6 00 04 00 00 	add    $0x400,%r14
 120d0fa:	48 83 f8 40          	cmp    $0x40,%rax
 120d0fe:	0f 84 a5 00 00 00    	je     120d1a9 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x529>
 120d104:	48 69 d0 08 05 00 00 	imul   $0x508,%rax,%rdx
 120d10b:	48 8d 0c 2a          	lea    (%rdx,%rbp,1),%rcx
 120d10f:	48 81 c1 38 2a fd ff 	add    $0xfffffffffffd2a38,%rcx
 120d116:	66 c7 84 15 3c 2e fd 	movw   $0x0,-0x2d1c4(%rbp,%rdx,1)
 120d11d:	ff 00 00 
 120d120:	c7 84 15 38 2e fd ff 	movl   $0x0,-0x2d1c8(%rbp,%rdx,1)
 120d127:	00 00 00 00 
 120d12b:	31 f6                	xor    %esi,%esi
 120d12d:	31 d2                	xor    %edx,%edx
 120d12f:	eb 1c                	jmp    120d14d <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x4cd>
 120d131:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120d138:	0f 1f 84 00 00 00 00 
 120d13f:	00 
 120d140:	48 83 c2 02          	add    $0x2,%rdx
 120d144:	48 81 fa 00 01 00 00 	cmp    $0x100,%rdx
 120d14b:	74 a3                	je     120d0f0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x470>
 120d14d:	41 8b 7c 96 fc       	mov    -0x4(%r14,%rdx,4),%edi
 120d152:	85 ff                	test   %edi,%edi
 120d154:	74 22                	je     120d178 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x4f8>
 120d156:	0f b7 f6             	movzwl %si,%esi
 120d159:	88 94 31 06 04 00 00 	mov    %dl,0x406(%rcx,%rsi,1)
 120d160:	89 3c b1             	mov    %edi,(%rcx,%rsi,4)
 120d163:	8b b1 04 04 00 00    	mov    0x404(%rcx),%esi
 120d169:	ff c6                	inc    %esi
 120d16b:	66 89 b1 04 04 00 00 	mov    %si,0x404(%rcx)
 120d172:	01 b9 00 04 00 00    	add    %edi,0x400(%rcx)
 120d178:	41 8b 3c 96          	mov    (%r14,%rdx,4),%edi
 120d17c:	85 ff                	test   %edi,%edi
 120d17e:	74 c0                	je     120d140 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x4c0>
 120d180:	0f b7 f6             	movzwl %si,%esi
 120d183:	44 8d 42 01          	lea    0x1(%rdx),%r8d
 120d187:	44 88 84 31 06 04 00 	mov    %r8b,0x406(%rcx,%rsi,1)
 120d18e:	00 
 120d18f:	89 3c b1             	mov    %edi,(%rcx,%rsi,4)
 120d192:	8b b1 04 04 00 00    	mov    0x404(%rcx),%esi
 120d198:	ff c6                	inc    %esi
 120d19a:	66 89 b1 04 04 00 00 	mov    %si,0x404(%rcx)
 120d1a1:	01 b9 00 04 00 00    	add    %edi,0x400(%rcx)
 120d1a7:	eb 97                	jmp    120d140 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x4c0>
 120d1a9:	48 8d bd 10 ef ff ff 	lea    -0x10f0(%rbp),%rdi
 120d1b0:	ba a0 07 00 00       	mov    $0x7a0,%edx
 120d1b5:	31 f6                	xor    %esi,%esi
 120d1b7:	c5 f8 77             	vzeroupper 
 120d1ba:	e8 81 8c 08 00       	call   1295e40 <compiler_rt.memset>
 120d1bf:	48 8d bd 08 22 fb ff 	lea    -0x4ddf8(%rbp),%rdi
 120d1c6:	ba 30 08 02 00       	mov    $0x20830,%edx
 120d1cb:	31 f6                	xor    %esi,%esi
 120d1cd:	e8 6e 8c 08 00       	call   1295e40 <compiler_rt.memset>
 120d1d2:	48 8b 8d 20 ff ff ff 	mov    -0xe0(%rbp),%rcx
 120d1d9:	88 4d d3             	mov    %cl,-0x2d(%rbp)
 120d1dc:	48 8b 85 18 ff ff ff 	mov    -0xe8(%rbp),%rax
 120d1e3:	88 45 d7             	mov    %al,-0x29(%rbp)
 120d1e6:	48 8b 95 58 ff ff ff 	mov    -0xa8(%rbp),%rdx
 120d1ed:	88 55 d6             	mov    %dl,-0x2a(%rbp)
 120d1f0:	88 4d d2             	mov    %cl,-0x2e(%rbp)
 120d1f3:	88 45 d5             	mov    %al,-0x2b(%rbp)
 120d1f6:	88 55 d4             	mov    %dl,-0x2c(%rbp)
 120d1f9:	48 8b 85 10 ff ff ff 	mov    -0xf0(%rbp),%rax
 120d200:	48 89 85 08 ff ff ff 	mov    %rax,-0xf8(%rbp)
 120d207:	48 89 85 00 ff ff ff 	mov    %rax,-0x100(%rbp)
 120d20e:	31 c0                	xor    %eax,%eax
 120d210:	eb 22                	jmp    120d234 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x5b4>
 120d212:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120d219:	1f 84 00 00 00 00 00 
 120d220:	48 8b 85 d8 fe ff ff 	mov    -0x128(%rbp),%rax
 120d227:	48 ff c0             	inc    %rax
 120d22a:	48 83 f8 0b          	cmp    $0xb,%rax
 120d22e:	0f 84 c6 1a 00 00    	je     120ecfa <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x207a>
 120d234:	48 89 85 d8 fe ff ff 	mov    %rax,-0x128(%rbp)
 120d23b:	48 8d 0d b6 1f e3 ff 	lea    -0x1ce04a(%rip),%rcx        # 103f1f8 <__anon_46239>
 120d242:	4c 8b 34 c1          	mov    (%rcx,%rax,8),%r14
 120d246:	49 83 fe 40          	cmp    $0x40,%r14
 120d24a:	77 d4                	ja     120d220 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x5a0>
 120d24c:	4c 89 f0             	mov    %r14,%rax
 120d24f:	48 c1 e0 0a          	shl    $0xa,%rax
 120d253:	48 89 85 d0 fe ff ff 	mov    %rax,-0x130(%rbp)
 120d25a:	4a 8d 04 b5 00 00 00 	lea    0x0(,%r14,4),%rax
 120d261:	00 
 120d262:	48 89 85 e8 fe ff ff 	mov    %rax,-0x118(%rbp)
 120d269:	49 83 fe 21          	cmp    $0x21,%r14
 120d26d:	b9 00 00 00 00       	mov    $0x0,%ecx
 120d272:	48 83 d1 01          	adc    $0x1,%rcx
 120d276:	49 83 fe 11          	cmp    $0x11,%r14
 120d27a:	b8 04 00 00 00       	mov    $0x4,%eax
 120d27f:	48 0f 42 c8          	cmovb  %rax,%rcx
 120d283:	48 89 8d b0 fe ff ff 	mov    %rcx,-0x150(%rbp)
 120d28a:	49 8d 46 ff          	lea    -0x1(%r14),%rax
 120d28e:	48 89 85 30 ff ff ff 	mov    %rax,-0xd0(%rbp)
 120d295:	44 89 f0             	mov    %r14d,%eax
 120d298:	83 e0 7e             	and    $0x7e,%eax
 120d29b:	48 89 85 b8 fe ff ff 	mov    %rax,-0x148(%rbp)
 120d2a2:	4b 8d 04 76          	lea    (%r14,%r14,2),%rax
 120d2a6:	48 89 85 c0 fe ff ff 	mov    %rax,-0x140(%rbp)
 120d2ad:	4b 8d 04 36          	lea    (%r14,%r14,1),%rax
 120d2b1:	48 89 85 c8 fe ff ff 	mov    %rax,-0x138(%rbp)
 120d2b8:	40 b7 01             	mov    $0x1,%dil
 120d2bb:	31 c0                	xor    %eax,%eax
 120d2bd:	4c 89 b5 60 ff ff ff 	mov    %r14,-0xa0(%rbp)
 120d2c4:	eb 53                	jmp    120d319 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x699>
 120d2c6:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 120d2cd:	00 00 00 
 120d2d0:	c6 45 c8 00          	movb   $0x0,-0x38(%rbp)
 120d2d4:	c6 45 c6 00          	movb   $0x0,-0x3a(%rbp)
 120d2d8:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 120d2dc:	c5 fe 7f 85 e0 fc ff 	vmovdqu %ymm0,-0x320(%rbp)
 120d2e3:	ff 
 120d2e4:	c5 fe 7f 85 00 fd ff 	vmovdqu %ymm0,-0x300(%rbp)
 120d2eb:	ff 
 120d2ec:	c7 85 68 ff ff ff 00 	movl   $0x0,-0x98(%rbp)
 120d2f3:	00 00 00 
 120d2f6:	66 c7 85 6c ff ff ff 	movw   $0x0,-0x94(%rbp)
 120d2fd:	00 00 
 120d2ff:	8b bd 38 ff ff ff    	mov    -0xc8(%rbp),%edi
 120d305:	b8 01 00 00 00       	mov    $0x1,%eax
 120d30a:	40 f6 c7 01          	test   $0x1,%dil
 120d30e:	bf 00 00 00 00       	mov    $0x0,%edi
 120d313:	0f 84 07 ff ff ff    	je     120d220 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x5a0>
 120d319:	48 8d 0d 30 1f e3 ff 	lea    -0x1ce0d0(%rip),%rcx        # 103f250 <__anon_46245>
 120d320:	0f b6 04 08          	movzbl (%rax,%rcx,1),%eax
 120d324:	48 8d 8d 38 2e fd ff 	lea    -0x2d1c8(%rbp),%rcx
 120d32b:	45 31 d2             	xor    %r10d,%r10d
 120d32e:	31 d2                	xor    %edx,%edx
 120d330:	eb 1f                	jmp    120d351 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x6d1>
 120d332:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120d339:	1f 84 00 00 00 00 00 
 120d340:	48 83 c2 04          	add    $0x4,%rdx
 120d344:	48 81 c1 20 14 00 00 	add    $0x1420,%rcx
 120d34b:	48 83 fa 40          	cmp    $0x40,%rdx
 120d34f:	74 5f                	je     120d3b0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x730>
 120d351:	83 39 00             	cmpl   $0x0,(%rcx)
 120d354:	74 0b                	je     120d361 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x6e1>
 120d356:	42 88 94 15 60 fe ff 	mov    %dl,-0x1a0(%rbp,%r10,1)
 120d35d:	ff 
 120d35e:	49 ff c2             	inc    %r10
 120d361:	83 b9 08 05 00 00 00 	cmpl   $0x0,0x508(%rcx)
 120d368:	74 0e                	je     120d378 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x6f8>
 120d36a:	8d 72 01             	lea    0x1(%rdx),%esi
 120d36d:	42 88 b4 15 60 fe ff 	mov    %sil,-0x1a0(%rbp,%r10,1)
 120d374:	ff 
 120d375:	49 ff c2             	inc    %r10
 120d378:	83 b9 10 0a 00 00 00 	cmpl   $0x0,0xa10(%rcx)
 120d37f:	74 0e                	je     120d38f <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x70f>
 120d381:	8d 72 02             	lea    0x2(%rdx),%esi
 120d384:	42 88 b4 15 60 fe ff 	mov    %sil,-0x1a0(%rbp,%r10,1)
 120d38b:	ff 
 120d38c:	49 ff c2             	inc    %r10
 120d38f:	83 b9 18 0f 00 00 00 	cmpl   $0x0,0xf18(%rcx)
 120d396:	74 a8                	je     120d340 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x6c0>
 120d398:	8d 72 03             	lea    0x3(%rdx),%esi
 120d39b:	42 88 b4 15 60 fe ff 	mov    %sil,-0x1a0(%rbp,%r10,1)
 120d3a2:	ff 
 120d3a3:	49 ff c2             	inc    %r10
 120d3a6:	eb 98                	jmp    120d340 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x6c0>
 120d3a8:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 120d3af:	00 
 120d3b0:	89 bd 38 ff ff ff    	mov    %edi,-0xc8(%rbp)
 120d3b6:	4d 39 f2             	cmp    %r14,%r10
 120d3b9:	0f 82 11 ff ff ff    	jb     120d2d0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x650>
 120d3bf:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 120d3c3:	c5 fe 7f 45 a0       	vmovdqu %ymm0,-0x60(%rbp)
 120d3c8:	c5 fe 7f 45 80       	vmovdqu %ymm0,-0x80(%rbp)
 120d3cd:	4d 85 d2             	test   %r10,%r10
 120d3d0:	0f 84 8a 01 00 00    	je     120d560 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x8e0>
 120d3d6:	a8 01                	test   $0x1,%al
 120d3d8:	74 0d                	je     120d3e7 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x767>
 120d3da:	49 83 fa 04          	cmp    $0x4,%r10
 120d3de:	73 76                	jae    120d456 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x7d6>
 120d3e0:	31 c9                	xor    %ecx,%ecx
 120d3e2:	e9 64 01 00 00       	jmp    120d54b <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x8cb>
 120d3e7:	49 83 fa 04          	cmp    $0x4,%r10
 120d3eb:	0f 83 0e 18 00 00    	jae    120ebff <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1f7f>
 120d3f1:	31 f6                	xor    %esi,%esi
 120d3f3:	44 89 d7             	mov    %r10d,%edi
 120d3f6:	83 e7 03             	and    $0x3,%edi
 120d3f9:	0f 84 61 01 00 00    	je     120d560 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x8e0>
 120d3ff:	4c 89 f1             	mov    %r14,%rcx
 120d402:	48 0f af ce          	imul   %rsi,%rcx
 120d406:	48 01 ee             	add    %rbp,%rsi
 120d409:	48 81 c6 60 fe ff ff 	add    $0xfffffffffffffe60,%rsi
 120d410:	45 31 c0             	xor    %r8d,%r8d
 120d413:	eb 27                	jmp    120d43c <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x7bc>
 120d415:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 120d41c:	00 00 00 00 
 120d420:	48 89 c8             	mov    %rcx,%rax
 120d423:	31 d2                	xor    %edx,%edx
 120d425:	49 f7 f2             	div    %r10
 120d428:	42 88 44 0d 80       	mov    %al,-0x80(%rbp,%r9,1)
 120d42d:	49 ff c0             	inc    %r8
 120d430:	4c 01 f1             	add    %r14,%rcx
 120d433:	4c 39 c7             	cmp    %r8,%rdi
 120d436:	0f 84 24 01 00 00    	je     120d560 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x8e0>
 120d43c:	46 0f b6 0c 06       	movzbl (%rsi,%r8,1),%r9d
 120d441:	48 89 c8             	mov    %rcx,%rax
 120d444:	4c 09 d0             	or     %r10,%rax
 120d447:	48 c1 e8 20          	shr    $0x20,%rax
 120d44b:	75 d3                	jne    120d420 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x7a0>
 120d44d:	89 c8                	mov    %ecx,%eax
 120d44f:	31 d2                	xor    %edx,%edx
 120d451:	41 f7 f2             	div    %r10d
 120d454:	eb d2                	jmp    120d428 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x7a8>
 120d456:	4c 89 d6             	mov    %r10,%rsi
 120d459:	48 83 e6 fc          	and    $0xfffffffffffffffc,%rsi
 120d45d:	31 c9                	xor    %ecx,%ecx
 120d45f:	eb 25                	jmp    120d486 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x806>
 120d461:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120d468:	0f 1f 84 00 00 00 00 
 120d46f:	00 
 120d470:	31 d2                	xor    %edx,%edx
 120d472:	49 f7 f6             	div    %r14
 120d475:	88 54 3d 80          	mov    %dl,-0x80(%rbp,%rdi,1)
 120d479:	48 83 c1 04          	add    $0x4,%rcx
 120d47d:	48 39 ce             	cmp    %rcx,%rsi
 120d480:	0f 84 c5 00 00 00    	je     120d54b <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x8cb>
 120d486:	0f b6 bc 0d 60 fe ff 	movzbl -0x1a0(%rbp,%rcx,1),%edi
 120d48d:	ff 
 120d48e:	48 89 c8             	mov    %rcx,%rax
 120d491:	4c 09 f0             	or     %r14,%rax
 120d494:	48 c1 e8 20          	shr    $0x20,%rax
 120d498:	74 16                	je     120d4b0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x830>
 120d49a:	48 89 c8             	mov    %rcx,%rax
 120d49d:	31 d2                	xor    %edx,%edx
 120d49f:	49 f7 f6             	div    %r14
 120d4a2:	eb 13                	jmp    120d4b7 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x837>
 120d4a4:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 120d4ab:	00 00 00 00 00 
 120d4b0:	89 c8                	mov    %ecx,%eax
 120d4b2:	31 d2                	xor    %edx,%edx
 120d4b4:	41 f7 f6             	div    %r14d
 120d4b7:	88 54 3d 80          	mov    %dl,-0x80(%rbp,%rdi,1)
 120d4bb:	48 8d 41 01          	lea    0x1(%rcx),%rax
 120d4bf:	0f b6 bc 0d 61 fe ff 	movzbl -0x19f(%rbp,%rcx,1),%edi
 120d4c6:	ff 
 120d4c7:	48 89 c2             	mov    %rax,%rdx
 120d4ca:	4c 09 f2             	or     %r14,%rdx
 120d4cd:	48 c1 ea 20          	shr    $0x20,%rdx
 120d4d1:	74 0d                	je     120d4e0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x860>
 120d4d3:	31 d2                	xor    %edx,%edx
 120d4d5:	49 f7 f6             	div    %r14
 120d4d8:	eb 0b                	jmp    120d4e5 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x865>
 120d4da:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 120d4e0:	31 d2                	xor    %edx,%edx
 120d4e2:	41 f7 f6             	div    %r14d
 120d4e5:	88 54 3d 80          	mov    %dl,-0x80(%rbp,%rdi,1)
 120d4e9:	48 8d 41 02          	lea    0x2(%rcx),%rax
 120d4ed:	0f b6 bc 0d 62 fe ff 	movzbl -0x19e(%rbp,%rcx,1),%edi
 120d4f4:	ff 
 120d4f5:	48 89 c2             	mov    %rax,%rdx
 120d4f8:	4c 09 f2             	or     %r14,%rdx
 120d4fb:	48 c1 ea 20          	shr    $0x20,%rdx
 120d4ff:	74 0f                	je     120d510 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x890>
 120d501:	31 d2                	xor    %edx,%edx
 120d503:	49 f7 f6             	div    %r14
 120d506:	eb 0d                	jmp    120d515 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x895>
 120d508:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 120d50f:	00 
 120d510:	31 d2                	xor    %edx,%edx
 120d512:	41 f7 f6             	div    %r14d
 120d515:	88 54 3d 80          	mov    %dl,-0x80(%rbp,%rdi,1)
 120d519:	48 8d 41 03          	lea    0x3(%rcx),%rax
 120d51d:	0f b6 bc 0d 63 fe ff 	movzbl -0x19d(%rbp,%rcx,1),%edi
 120d524:	ff 
 120d525:	48 89 c2             	mov    %rax,%rdx
 120d528:	4c 09 f2             	or     %r14,%rdx
 120d52b:	48 c1 ea 20          	shr    $0x20,%rdx
 120d52f:	0f 85 3b ff ff ff    	jne    120d470 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x7f0>
 120d535:	31 d2                	xor    %edx,%edx
 120d537:	41 f7 f6             	div    %r14d
 120d53a:	88 54 3d 80          	mov    %dl,-0x80(%rbp,%rdi,1)
 120d53e:	48 83 c1 04          	add    $0x4,%rcx
 120d542:	48 39 ce             	cmp    %rcx,%rsi
 120d545:	0f 85 3b ff ff ff    	jne    120d486 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x806>
 120d54b:	44 89 d6             	mov    %r10d,%esi
 120d54e:	83 e6 03             	and    $0x3,%esi
 120d551:	0f 85 81 01 00 00    	jne    120d6d8 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xa58>
 120d557:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 120d55e:	00 00 
 120d560:	4c 89 95 a0 fe ff ff 	mov    %r10,-0x160(%rbp)
 120d567:	48 8d bd 38 6c fe ff 	lea    -0x193c8(%rbp),%rdi
 120d56e:	31 f6                	xor    %esi,%esi
 120d570:	48 8b 95 d0 fe ff ff 	mov    -0x130(%rbp),%rdx
 120d577:	c5 f8 77             	vzeroupper 
 120d57a:	e8 c1 88 08 00       	call   1295e40 <compiler_rt.memset>
 120d57f:	48 8d bd b0 fa ff ff 	lea    -0x550(%rbp),%rdi
 120d586:	31 f6                	xor    %esi,%esi
 120d588:	48 8b 95 e8 fe ff ff 	mov    -0x118(%rbp),%rdx
 120d58f:	e8 ac 88 08 00       	call   1295e40 <compiler_rt.memset>
 120d594:	48 8d 85 3e 2e fd ff 	lea    -0x2d1c2(%rbp),%rax
 120d59b:	48 8d 8d 38 2a fd ff 	lea    -0x2d5c8(%rbp),%rcx
 120d5a2:	31 d2                	xor    %edx,%edx
 120d5a4:	eb 3b                	jmp    120d5e1 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x961>
 120d5a6:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 120d5ad:	00 00 00 
 120d5b0:	48 01 ef             	add    %rbp,%rdi
 120d5b3:	48 81 c7 38 2a fd ff 	add    $0xfffffffffffd2a38,%rdi
 120d5ba:	8b bf 00 04 00 00    	mov    0x400(%rdi),%edi
 120d5c0:	01 bc b5 b0 fa ff ff 	add    %edi,-0x550(%rbp,%rsi,4)
 120d5c7:	48 ff c2             	inc    %rdx
 120d5ca:	48 81 c1 08 05 00 00 	add    $0x508,%rcx
 120d5d1:	48 05 08 05 00 00    	add    $0x508,%rax
 120d5d7:	48 83 fa 40          	cmp    $0x40,%rdx
 120d5db:	0f 84 1f 01 00 00    	je     120d700 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xa80>
 120d5e1:	48 69 fa 08 05 00 00 	imul   $0x508,%rdx,%rdi
 120d5e8:	0f b6 74 15 80       	movzbl -0x80(%rbp,%rdx,1),%esi
 120d5ed:	44 0f b7 84 3d 3c 2e 	movzwl -0x2d1c4(%rbp,%rdi,1),%r8d
 120d5f4:	fd ff 
 120d5f6:	4d 85 c0             	test   %r8,%r8
 120d5f9:	74 b5                	je     120d5b0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x930>
 120d5fb:	41 89 f1             	mov    %esi,%r9d
 120d5fe:	41 c1 e1 0a          	shl    $0xa,%r9d
 120d602:	49 01 e9             	add    %rbp,%r9
 120d605:	49 81 c1 38 6c fe ff 	add    $0xfffffffffffe6c38,%r9
 120d60c:	66 41 83 f8 04       	cmp    $0x4,%r8w
 120d611:	73 0d                	jae    120d620 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x9a0>
 120d613:	45 31 d2             	xor    %r10d,%r10d
 120d616:	eb 68                	jmp    120d680 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xa00>
 120d618:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 120d61f:	00 
 120d620:	45 89 c3             	mov    %r8d,%r11d
 120d623:	41 83 e3 fc          	and    $0xfffffffc,%r11d
 120d627:	45 31 d2             	xor    %r10d,%r10d
 120d62a:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 120d630:	42 0f b6 9c 11 06 04 	movzbl 0x406(%rcx,%r10,1),%ebx
 120d637:	00 00 
 120d639:	46 8b 34 91          	mov    (%rcx,%r10,4),%r14d
 120d63d:	45 01 34 99          	add    %r14d,(%r9,%rbx,4)
 120d641:	42 0f b6 9c 11 07 04 	movzbl 0x407(%rcx,%r10,1),%ebx
 120d648:	00 00 
 120d64a:	46 8b 74 91 04       	mov    0x4(%rcx,%r10,4),%r14d
 120d64f:	45 01 34 99          	add    %r14d,(%r9,%rbx,4)
 120d653:	42 0f b6 9c 11 08 04 	movzbl 0x408(%rcx,%r10,1),%ebx
 120d65a:	00 00 
 120d65c:	46 8b 74 91 08       	mov    0x8(%rcx,%r10,4),%r14d
 120d661:	45 01 34 99          	add    %r14d,(%r9,%rbx,4)
 120d665:	42 0f b6 9c 11 09 04 	movzbl 0x409(%rcx,%r10,1),%ebx
 120d66c:	00 00 
 120d66e:	46 8b 74 91 0c       	mov    0xc(%rcx,%r10,4),%r14d
 120d673:	45 01 34 99          	add    %r14d,(%r9,%rbx,4)
 120d677:	49 83 c2 04          	add    $0x4,%r10
 120d67b:	4d 39 d3             	cmp    %r10,%r11
 120d67e:	75 b0                	jne    120d630 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x9b0>
 120d680:	41 83 e0 03          	and    $0x3,%r8d
 120d684:	0f 84 26 ff ff ff    	je     120d5b0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x930>
 120d68a:	4e 8d 1c 91          	lea    (%rcx,%r10,4),%r11
 120d68e:	49 01 c2             	add    %rax,%r10
 120d691:	31 db                	xor    %ebx,%ebx
 120d693:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120d69a:	84 00 00 00 00 00 
 120d6a0:	45 0f b6 34 1a       	movzbl (%r10,%rbx,1),%r14d
 120d6a5:	45 8b 3c 9b          	mov    (%r11,%rbx,4),%r15d
 120d6a9:	47 01 3c b1          	add    %r15d,(%r9,%r14,4)
 120d6ad:	48 ff c3             	inc    %rbx
 120d6b0:	49 39 d8             	cmp    %rbx,%r8
 120d6b3:	75 eb                	jne    120d6a0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xa20>
 120d6b5:	e9 f6 fe ff ff       	jmp    120d5b0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x930>
 120d6ba:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 120d6c0:	48 89 c8             	mov    %rcx,%rax
 120d6c3:	31 d2                	xor    %edx,%edx
 120d6c5:	49 f7 f6             	div    %r14
 120d6c8:	88 54 3d 80          	mov    %dl,-0x80(%rbp,%rdi,1)
 120d6cc:	48 ff c1             	inc    %rcx
 120d6cf:	48 ff ce             	dec    %rsi
 120d6d2:	0f 84 88 fe ff ff    	je     120d560 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x8e0>
 120d6d8:	0f b6 bc 0d 60 fe ff 	movzbl -0x1a0(%rbp,%rcx,1),%edi
 120d6df:	ff 
 120d6e0:	48 89 c8             	mov    %rcx,%rax
 120d6e3:	4c 09 f0             	or     %r14,%rax
 120d6e6:	48 c1 e8 20          	shr    $0x20,%rax
 120d6ea:	75 d4                	jne    120d6c0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xa40>
 120d6ec:	89 c8                	mov    %ecx,%eax
 120d6ee:	31 d2                	xor    %edx,%edx
 120d6f0:	41 f7 f6             	div    %r14d
 120d6f3:	eb d3                	jmp    120d6c8 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xa48>
 120d6f5:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 120d6fc:	00 00 00 00 
 120d700:	41 0f b7 04 24       	movzwl (%r12),%eax
 120d705:	48 89 85 50 ff ff ff 	mov    %rax,-0xb0(%rbp)
 120d70c:	41 89 c7             	mov    %eax,%r15d
 120d70f:	41 83 e7 fe          	and    $0xfffffffe,%r15d
 120d713:	31 c9                	xor    %ecx,%ecx
 120d715:	48 c7 c3 ff ff ff ff 	mov    $0xffffffffffffffff,%rbx
 120d71c:	4c 8d 35 b5 1e e3 ff 	lea    -0x1ce14b(%rip),%r14        # 103f5d8 <__anon_72593>
 120d723:	4c 89 bd 78 ff ff ff 	mov    %r15,-0x88(%rbp)
 120d72a:	eb 24                	jmp    120d750 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xad0>
 120d72c:	0f 1f 40 00          	nopl   0x0(%rax)
 120d730:	48 8b 8d a8 fe ff ff 	mov    -0x158(%rbp),%rcx
 120d737:	48 ff c1             	inc    %rcx
 120d73a:	48 3b 8d b0 fe ff ff 	cmp    -0x150(%rbp),%rcx
 120d741:	0f 95 c0             	setne  %al
 120d744:	84 85 e0 fe ff ff    	test   %al,-0x120(%rbp)
 120d74a:	0f 84 c0 06 00 00    	je     120de10 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1190>
 120d750:	48 89 8d a8 fe ff ff 	mov    %rcx,-0x158(%rbp)
 120d757:	48 83 bd 50 ff ff ff 	cmpq   $0x0,-0xb0(%rbp)
 120d75e:	00 
 120d75f:	0f 84 8b 01 00 00    	je     120d8f0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xc70>
 120d765:	31 d2                	xor    %edx,%edx
 120d767:	eb 25                	jmp    120d78e <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xb0e>
 120d769:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)
 120d770:	89 c9                	mov    %ecx,%ecx
 120d772:	41 0f b7 3c 4e       	movzwl (%r14,%rcx,2),%edi
 120d777:	29 f8                	sub    %edi,%eax
 120d779:	66 42 89 04 46       	mov    %ax,(%rsi,%r8,2)
 120d77e:	48 ff c2             	inc    %rdx
 120d781:	48 3b 95 60 ff ff ff 	cmp    -0xa0(%rbp),%rdx
 120d788:	0f 84 62 01 00 00    	je     120d8f0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xc70>
 120d78e:	48 89 d1             	mov    %rdx,%rcx
 120d791:	48 c1 e1 0a          	shl    $0xa,%rcx
 120d795:	8b b4 95 b0 fa ff ff 	mov    -0x550(%rbp,%rdx,4),%esi
 120d79c:	49 89 d0             	mov    %rdx,%r8
 120d79f:	49 c1 e0 09          	shl    $0x9,%r8
 120d7a3:	48 8d 86 00 01 00 00 	lea    0x100(%rsi),%rax
 120d7aa:	0f bd c0             	bsr    %eax,%eax
 120d7ad:	c4 e2 f9 f7 fb       	shlx   %rax,%rbx,%rdi
 120d7b2:	48 01 fe             	add    %rdi,%rsi
 120d7b5:	48 81 c6 00 01 00 00 	add    $0x100,%rsi
 120d7bc:	48 c1 e6 08          	shl    $0x8,%rsi
 120d7c0:	c4 e2 fb f7 f6       	shrx   %rax,%rsi,%rsi
 120d7c5:	c1 e0 08             	shl    $0x8,%eax
 120d7c8:	48 01 f0             	add    %rsi,%rax
 120d7cb:	48 8d 3c 29          	lea    (%rcx,%rbp,1),%rdi
 120d7cf:	48 81 c7 38 6c fe ff 	add    $0xfffffffffffe6c38,%rdi
 120d7d6:	49 8d 34 28          	lea    (%r8,%rbp,1),%rsi
 120d7da:	48 81 c6 38 6c ff ff 	add    $0xffffffffffff6c38,%rsi
 120d7e1:	83 bd 50 ff ff ff 01 	cmpl   $0x1,-0xb0(%rbp)
 120d7e8:	75 46                	jne    120d830 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xbb0>
 120d7ea:	45 31 c0             	xor    %r8d,%r8d
 120d7ed:	f6 85 50 ff ff ff 01 	testb  $0x1,-0xb0(%rbp)
 120d7f4:	74 88                	je     120d77e <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xafe>
 120d7f6:	47 0f b6 44 04 02    	movzbl 0x2(%r12,%r8,1),%r8d
 120d7fc:	42 8b 3c 87          	mov    (%rdi,%r8,4),%edi
 120d800:	48 8d 4f 01          	lea    0x1(%rdi),%rcx
 120d804:	48 81 ff 00 10 00 00 	cmp    $0x1000,%rdi
 120d80b:	0f 82 5f ff ff ff    	jb     120d770 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xaf0>
 120d811:	0f bd f9             	bsr    %ecx,%edi
 120d814:	c4 62 c1 f7 cb       	shlx   %rdi,%rbx,%r9
 120d819:	49 01 c9             	add    %rcx,%r9
 120d81c:	49 c1 e1 08          	shl    $0x8,%r9
 120d820:	c4 c2 c3 f7 c9       	shrx   %rdi,%r9,%rcx
 120d825:	c1 e7 08             	shl    $0x8,%edi
 120d828:	48 01 cf             	add    %rcx,%rdi
 120d82b:	e9 47 ff ff ff       	jmp    120d777 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xaf7>
 120d830:	45 31 c0             	xor    %r8d,%r8d
 120d833:	eb 25                	jmp    120d85a <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xbda>
 120d835:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 120d83c:	00 00 00 00 
 120d840:	89 c9                	mov    %ecx,%ecx
 120d842:	45 0f b7 14 4e       	movzwl (%r14,%rcx,2),%r10d
 120d847:	89 c1                	mov    %eax,%ecx
 120d849:	44 29 d1             	sub    %r10d,%ecx
 120d84c:	66 42 89 0c 4e       	mov    %cx,(%rsi,%r9,2)
 120d851:	49 83 c0 02          	add    $0x2,%r8
 120d855:	4d 39 c7             	cmp    %r8,%r15
 120d858:	74 93                	je     120d7ed <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xb6d>
 120d85a:	47 0f b6 4c 04 02    	movzbl 0x2(%r12,%r8,1),%r9d
 120d860:	42 8b 0c 8f          	mov    (%rdi,%r9,4),%ecx
 120d864:	48 81 f9 ff 0f 00 00 	cmp    $0xfff,%rcx
 120d86b:	77 13                	ja     120d880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xc00>
 120d86d:	45 0f b7 54 4e 02    	movzwl 0x2(%r14,%rcx,2),%r10d
 120d873:	eb 2b                	jmp    120d8a0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xc20>
 120d875:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 120d87c:	00 00 00 00 
 120d880:	ff c1                	inc    %ecx
 120d882:	44 0f bd d1          	bsr    %ecx,%r10d
 120d886:	c4 62 a9 f7 db       	shlx   %r10,%rbx,%r11
 120d88b:	89 c9                	mov    %ecx,%ecx
 120d88d:	4c 01 d9             	add    %r11,%rcx
 120d890:	48 c1 e1 08          	shl    $0x8,%rcx
 120d894:	c4 e2 ab f7 c9       	shrx   %r10,%rcx,%rcx
 120d899:	41 c1 e2 08          	shl    $0x8,%r10d
 120d89d:	49 01 ca             	add    %rcx,%r10
 120d8a0:	89 c1                	mov    %eax,%ecx
 120d8a2:	44 29 d1             	sub    %r10d,%ecx
 120d8a5:	66 42 89 0c 4e       	mov    %cx,(%rsi,%r9,2)
 120d8aa:	47 0f b6 4c 04 03    	movzbl 0x3(%r12,%r8,1),%r9d
 120d8b0:	46 8b 14 8f          	mov    (%rdi,%r9,4),%r10d
 120d8b4:	49 8d 4a 01          	lea    0x1(%r10),%rcx
 120d8b8:	49 81 fa 00 10 00 00 	cmp    $0x1000,%r10
 120d8bf:	0f 82 7b ff ff ff    	jb     120d840 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xbc0>
 120d8c5:	44 0f bd d1          	bsr    %ecx,%r10d
 120d8c9:	c4 62 a9 f7 db       	shlx   %r10,%rbx,%r11
 120d8ce:	49 01 cb             	add    %rcx,%r11
 120d8d1:	49 c1 e3 08          	shl    $0x8,%r11
 120d8d5:	c4 c2 ab f7 cb       	shrx   %r10,%r11,%rcx
 120d8da:	41 c1 e2 08          	shl    $0x8,%r10d
 120d8de:	49 01 ca             	add    %rcx,%r10
 120d8e1:	e9 61 ff ff ff       	jmp    120d847 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xbc7>
 120d8e6:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 120d8ed:	00 00 00 
 120d8f0:	48 c7 85 e0 fe ff ff 	movq   $0x0,-0x120(%rbp)
 120d8f7:	00 00 00 00 
 120d8fb:	31 c9                	xor    %ecx,%ecx
 120d8fd:	eb 4e                	jmp    120d94d <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xccd>
 120d8ff:	90                   	nop
 120d900:	48 c7 c3 ff ff ff ff 	mov    $0xffffffffffffffff,%rbx
 120d907:	4c 8d 35 ca 1c e3 ff 	lea    -0x1ce336(%rip),%r14        # 103f5d8 <__anon_72593>
 120d90e:	4c 8b bd 78 ff ff ff 	mov    -0x88(%rbp),%r15
 120d915:	8b 87 00 04 00 00    	mov    0x400(%rdi),%eax
 120d91b:	42 29 84 85 b0 fa ff 	sub    %eax,-0x550(%rbp,%r8,4)
 120d922:	ff 
 120d923:	01 84 95 b0 fa ff ff 	add    %eax,-0x550(%rbp,%rdx,4)
 120d92a:	41 88 12             	mov    %dl,(%r10)
 120d92d:	b0 01                	mov    $0x1,%al
 120d92f:	48 89 85 e0 fe ff ff 	mov    %rax,-0x120(%rbp)
 120d936:	48 8b 8d 48 ff ff ff 	mov    -0xb8(%rbp),%rcx
 120d93d:	48 ff c1             	inc    %rcx
 120d940:	48 3b 8d a0 fe ff ff 	cmp    -0x160(%rbp),%rcx
 120d947:	0f 84 e3 fd ff ff    	je     120d730 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xab0>
 120d94d:	0f b6 94 0d 60 fe ff 	movzbl -0x1a0(%rbp,%rcx,1),%edx
 120d954:	ff 
 120d955:	48 69 f2 08 05 00 00 	imul   $0x508,%rdx,%rsi
 120d95c:	48 8d 3c 2e          	lea    (%rsi,%rbp,1),%rdi
 120d960:	48 81 c7 38 2a fd ff 	add    $0xfffffffffffd2a38,%rdi
 120d967:	0f b7 84 35 3c 2e fd 	movzwl -0x2d1c4(%rbp,%rsi,1),%eax
 120d96e:	ff 
 120d96f:	48 85 c0             	test   %rax,%rax
 120d972:	48 89 8d 48 ff ff ff 	mov    %rcx,-0xb8(%rbp)
 120d979:	48 89 b5 f8 fe ff ff 	mov    %rsi,-0x108(%rbp)
 120d980:	48 89 95 70 ff ff ff 	mov    %rdx,-0x90(%rbp)
 120d987:	74 17                	je     120d9a0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xd20>
 120d989:	66 83 f8 08          	cmp    $0x8,%ax
 120d98d:	73 61                	jae    120d9f0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xd70>
 120d98f:	31 d2                	xor    %edx,%edx
 120d991:	45 31 ff             	xor    %r15d,%r15d
 120d994:	e9 5d 01 00 00       	jmp    120daf6 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xe76>
 120d999:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)
 120d9a0:	31 d2                	xor    %edx,%edx
 120d9a2:	48 8b 8d 70 ff ff ff 	mov    -0x90(%rbp),%rcx
 120d9a9:	44 0f b6 44 0d 80    	movzbl -0x80(%rbp,%rcx,1),%r8d
 120d9af:	4c 39 c2             	cmp    %r8,%rdx
 120d9b2:	4c 8b 65 10          	mov    0x10(%rbp),%r12
 120d9b6:	48 c7 c3 ff ff ff ff 	mov    $0xffffffffffffffff,%rbx
 120d9bd:	4c 8d 35 14 1c e3 ff 	lea    -0x1ce3ec(%rip),%r14        # 103f5d8 <__anon_72593>
 120d9c4:	4c 8b bd 78 ff ff ff 	mov    -0x88(%rbp),%r15
 120d9cb:	0f 84 65 ff ff ff    	je     120d936 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xcb6>
 120d9d1:	4c 8d 14 29          	lea    (%rcx,%rbp,1),%r10
 120d9d5:	49 83 c2 80          	add    $0xffffffffffffff80,%r10
 120d9d9:	48 85 c0             	test   %rax,%rax
 120d9dc:	0f 85 1c 03 00 00    	jne    120dcfe <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x107e>
 120d9e2:	e9 2e ff ff ff       	jmp    120d915 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xc95>
 120d9e7:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 120d9ee:	00 00 
 120d9f0:	41 89 c0             	mov    %eax,%r8d
 120d9f3:	41 83 e0 f8          	and    $0xfffffff8,%r8d
 120d9f7:	31 d2                	xor    %edx,%edx
 120d9f9:	45 31 ff             	xor    %r15d,%r15d
 120d9fc:	0f 1f 40 00          	nopl   0x0(%rax)
 120da00:	0f b6 8c 17 06 04 00 	movzbl 0x406(%rdi,%rdx,1),%ecx
 120da07:	00 
 120da08:	44 8b 0c 97          	mov    (%rdi,%rdx,4),%r9d
 120da0c:	44 8b 54 97 04       	mov    0x4(%rdi,%rdx,4),%r10d
 120da11:	0f b7 8c 4d 38 6c ff 	movzwl -0x93c8(%rbp,%rcx,2),%ecx
 120da18:	ff 
 120da19:	49 0f af c9          	imul   %r9,%rcx
 120da1d:	4c 01 f9             	add    %r15,%rcx
 120da20:	44 0f b6 8c 17 07 04 	movzbl 0x407(%rdi,%rdx,1),%r9d
 120da27:	00 00 
 120da29:	46 0f b7 8c 4d 38 6c 	movzwl -0x93c8(%rbp,%r9,2),%r9d
 120da30:	ff ff 
 120da32:	4d 0f af ca          	imul   %r10,%r9
 120da36:	44 0f b6 94 17 08 04 	movzbl 0x408(%rdi,%rdx,1),%r10d
 120da3d:	00 00 
 120da3f:	44 8b 5c 97 08       	mov    0x8(%rdi,%rdx,4),%r11d
 120da44:	46 0f b7 94 55 38 6c 	movzwl -0x93c8(%rbp,%r10,2),%r10d
 120da4b:	ff ff 
 120da4d:	4d 0f af d3          	imul   %r11,%r10
 120da51:	4d 01 ca             	add    %r9,%r10
 120da54:	49 01 ca             	add    %rcx,%r10
 120da57:	0f b6 8c 17 09 04 00 	movzbl 0x409(%rdi,%rdx,1),%ecx
 120da5e:	00 
 120da5f:	44 8b 4c 97 0c       	mov    0xc(%rdi,%rdx,4),%r9d
 120da64:	0f b7 8c 4d 38 6c ff 	movzwl -0x93c8(%rbp,%rcx,2),%ecx
 120da6b:	ff 
 120da6c:	49 0f af c9          	imul   %r9,%rcx
 120da70:	44 0f b6 8c 17 0a 04 	movzbl 0x40a(%rdi,%rdx,1),%r9d
 120da77:	00 00 
 120da79:	44 8b 5c 97 10       	mov    0x10(%rdi,%rdx,4),%r11d
 120da7e:	46 0f b7 8c 4d 38 6c 	movzwl -0x93c8(%rbp,%r9,2),%r9d
 120da85:	ff ff 
 120da87:	4d 0f af cb          	imul   %r11,%r9
 120da8b:	49 01 c9             	add    %rcx,%r9
 120da8e:	0f b6 8c 17 0b 04 00 	movzbl 0x40b(%rdi,%rdx,1),%ecx
 120da95:	00 
 120da96:	44 8b 5c 97 14       	mov    0x14(%rdi,%rdx,4),%r11d
 120da9b:	0f b7 8c 4d 38 6c ff 	movzwl -0x93c8(%rbp,%rcx,2),%ecx
 120daa2:	ff 
 120daa3:	49 0f af cb          	imul   %r11,%rcx
 120daa7:	4c 01 c9             	add    %r9,%rcx
 120daaa:	4c 01 d1             	add    %r10,%rcx
 120daad:	44 0f b6 8c 17 0c 04 	movzbl 0x40c(%rdi,%rdx,1),%r9d
 120dab4:	00 00 
 120dab6:	44 8b 54 97 18       	mov    0x18(%rdi,%rdx,4),%r10d
 120dabb:	46 0f b7 8c 4d 38 6c 	movzwl -0x93c8(%rbp,%r9,2),%r9d
 120dac2:	ff ff 
 120dac4:	4d 0f af ca          	imul   %r10,%r9
 120dac8:	44 0f b6 94 17 0d 04 	movzbl 0x40d(%rdi,%rdx,1),%r10d
 120dacf:	00 00 
 120dad1:	44 8b 5c 97 1c       	mov    0x1c(%rdi,%rdx,4),%r11d
 120dad6:	46 0f b7 bc 55 38 6c 	movzwl -0x93c8(%rbp,%r10,2),%r15d
 120dadd:	ff ff 
 120dadf:	4d 0f af fb          	imul   %r11,%r15
 120dae3:	4d 01 cf             	add    %r9,%r15
 120dae6:	49 01 cf             	add    %rcx,%r15
 120dae9:	48 83 c2 08          	add    $0x8,%rdx
 120daed:	49 39 d0             	cmp    %rdx,%r8
 120daf0:	0f 85 0a ff ff ff    	jne    120da00 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xd80>
 120daf6:	41 89 c0             	mov    %eax,%r8d
 120daf9:	41 83 e0 07          	and    $0x7,%r8d
 120dafd:	74 41                	je     120db40 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xec0>
 120daff:	48 8d 0c 96          	lea    (%rsi,%rdx,4),%rcx
 120db03:	4c 8d 14 29          	lea    (%rcx,%rbp,1),%r10
 120db07:	49 81 c2 38 2a fd ff 	add    $0xfffffffffffd2a38,%r10
 120db0e:	48 8d 8d 3e 2e fd ff 	lea    -0x2d1c2(%rbp),%rcx
 120db15:	48 01 ca             	add    %rcx,%rdx
 120db18:	48 01 f2             	add    %rsi,%rdx
 120db1b:	45 31 c9             	xor    %r9d,%r9d
 120db1e:	66 90                	xchg   %ax,%ax
 120db20:	42 0f b6 0c 0a       	movzbl (%rdx,%r9,1),%ecx
 120db25:	47 8b 1c 8a          	mov    (%r10,%r9,4),%r11d
 120db29:	0f b7 8c 4d 38 6c ff 	movzwl -0x93c8(%rbp,%rcx,2),%ecx
 120db30:	ff 
 120db31:	49 0f af cb          	imul   %r11,%rcx
 120db35:	49 01 cf             	add    %rcx,%r15
 120db38:	49 ff c1             	inc    %r9
 120db3b:	4d 39 c8             	cmp    %r9,%r8
 120db3e:	75 e0                	jne    120db20 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xea0>
 120db40:	48 83 bd 30 ff ff ff 	cmpq   $0x0,-0xd0(%rbp)
 120db47:	00 
 120db48:	0f 84 82 01 00 00    	je     120dcd0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1050>
 120db4e:	41 89 c2             	mov    %eax,%r10d
 120db51:	41 83 e2 f8          	and    $0xfffffff8,%r10d
 120db55:	48 8d 8d 3e 2e fd ff 	lea    -0x2d1c2(%rbp),%rcx
 120db5c:	48 01 f1             	add    %rsi,%rcx
 120db5f:	48 89 8d 40 ff ff ff 	mov    %rcx,-0xc0(%rbp)
 120db66:	31 d2                	xor    %edx,%edx
 120db68:	45 31 f6             	xor    %r14d,%r14d
 120db6b:	eb 1b                	jmp    120db88 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xf08>
 120db6d:	0f 1f 00             	nopl   (%rax)
 120db70:	4d 39 fb             	cmp    %r15,%r11
 120db73:	4d 0f 42 fb          	cmovb  %r11,%r15
 120db77:	49 0f 42 d6          	cmovb  %r14,%rdx
 120db7b:	4c 3b b5 30 ff ff ff 	cmp    -0xd0(%rbp),%r14
 120db82:	0f 84 1a fe ff ff    	je     120d9a2 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xd22>
 120db88:	49 ff c6             	inc    %r14
 120db8b:	4c 89 f1             	mov    %r14,%rcx
 120db8e:	48 c1 e1 09          	shl    $0x9,%rcx
 120db92:	4c 8d 24 29          	lea    (%rcx,%rbp,1),%r12
 120db96:	49 81 c4 38 6c ff ff 	add    $0xffffffffffff6c38,%r12
 120db9d:	31 db                	xor    %ebx,%ebx
 120db9f:	45 31 db             	xor    %r11d,%r11d
 120dba2:	66 83 f8 08          	cmp    $0x8,%ax
 120dba6:	0f 82 d8 00 00 00    	jb     120dc84 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1004>
 120dbac:	0f 1f 40 00          	nopl   0x0(%rax)
 120dbb0:	0f b6 8c 1f 06 04 00 	movzbl 0x406(%rdi,%rbx,1),%ecx
 120dbb7:	00 
 120dbb8:	44 8b 0c 9f          	mov    (%rdi,%rbx,4),%r9d
 120dbbc:	8b 74 9f 04          	mov    0x4(%rdi,%rbx,4),%esi
 120dbc0:	41 0f b7 0c 4c       	movzwl (%r12,%rcx,2),%ecx
 120dbc5:	49 0f af c9          	imul   %r9,%rcx
 120dbc9:	4c 01 d9             	add    %r11,%rcx
 120dbcc:	44 0f b6 8c 1f 07 04 	movzbl 0x407(%rdi,%rbx,1),%r9d
 120dbd3:	00 00 
 120dbd5:	47 0f b7 0c 4c       	movzwl (%r12,%r9,2),%r9d
 120dbda:	4c 0f af ce          	imul   %rsi,%r9
 120dbde:	0f b6 b4 1f 08 04 00 	movzbl 0x408(%rdi,%rbx,1),%esi
 120dbe5:	00 
 120dbe6:	44 8b 6c 9f 08       	mov    0x8(%rdi,%rbx,4),%r13d
 120dbeb:	45 0f b7 1c 74       	movzwl (%r12,%rsi,2),%r11d
 120dbf0:	4d 0f af dd          	imul   %r13,%r11
 120dbf4:	4d 01 cb             	add    %r9,%r11
 120dbf7:	49 01 cb             	add    %rcx,%r11
 120dbfa:	0f b6 8c 1f 09 04 00 	movzbl 0x409(%rdi,%rbx,1),%ecx
 120dc01:	00 
 120dc02:	8b 74 9f 0c          	mov    0xc(%rdi,%rbx,4),%esi
 120dc06:	41 0f b7 0c 4c       	movzwl (%r12,%rcx,2),%ecx
 120dc0b:	48 0f af ce          	imul   %rsi,%rcx
 120dc0f:	0f b6 b4 1f 0a 04 00 	movzbl 0x40a(%rdi,%rbx,1),%esi
 120dc16:	00 
 120dc17:	44 8b 4c 9f 10       	mov    0x10(%rdi,%rbx,4),%r9d
 120dc1c:	41 0f b7 34 74       	movzwl (%r12,%rsi,2),%esi
 120dc21:	49 0f af f1          	imul   %r9,%rsi
 120dc25:	48 01 ce             	add    %rcx,%rsi
 120dc28:	0f b6 8c 1f 0b 04 00 	movzbl 0x40b(%rdi,%rbx,1),%ecx
 120dc2f:	00 
 120dc30:	44 8b 4c 9f 14       	mov    0x14(%rdi,%rbx,4),%r9d
 120dc35:	41 0f b7 0c 4c       	movzwl (%r12,%rcx,2),%ecx
 120dc3a:	49 0f af c9          	imul   %r9,%rcx
 120dc3e:	48 01 f1             	add    %rsi,%rcx
 120dc41:	4c 01 d9             	add    %r11,%rcx
 120dc44:	0f b6 b4 1f 0c 04 00 	movzbl 0x40c(%rdi,%rbx,1),%esi
 120dc4b:	00 
 120dc4c:	44 8b 4c 9f 18       	mov    0x18(%rdi,%rbx,4),%r9d
 120dc51:	41 0f b7 34 74       	movzwl (%r12,%rsi,2),%esi
 120dc56:	49 0f af f1          	imul   %r9,%rsi
 120dc5a:	44 0f b6 8c 1f 0d 04 	movzbl 0x40d(%rdi,%rbx,1),%r9d
 120dc61:	00 00 
 120dc63:	44 8b 6c 9f 1c       	mov    0x1c(%rdi,%rbx,4),%r13d
 120dc68:	47 0f b7 1c 4c       	movzwl (%r12,%r9,2),%r11d
 120dc6d:	4d 0f af dd          	imul   %r13,%r11
 120dc71:	49 01 f3             	add    %rsi,%r11
 120dc74:	49 01 cb             	add    %rcx,%r11
 120dc77:	48 83 c3 08          	add    $0x8,%rbx
 120dc7b:	49 39 da             	cmp    %rbx,%r10
 120dc7e:	0f 85 2c ff ff ff    	jne    120dbb0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xf30>
 120dc84:	a8 07                	test   $0x7,%al
 120dc86:	0f 84 e4 fe ff ff    	je     120db70 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xef0>
 120dc8c:	4c 8d 0c 9f          	lea    (%rdi,%rbx,4),%r9
 120dc90:	48 03 9d 40 ff ff ff 	add    -0xc0(%rbp),%rbx
 120dc97:	31 c9                	xor    %ecx,%ecx
 120dc99:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)
 120dca0:	0f b6 34 0b          	movzbl (%rbx,%rcx,1),%esi
 120dca4:	45 8b 2c 89          	mov    (%r9,%rcx,4),%r13d
 120dca8:	41 0f b7 34 74       	movzwl (%r12,%rsi,2),%esi
 120dcad:	49 0f af f5          	imul   %r13,%rsi
 120dcb1:	49 01 f3             	add    %rsi,%r11
 120dcb4:	48 ff c1             	inc    %rcx
 120dcb7:	49 39 c8             	cmp    %rcx,%r8
 120dcba:	75 e4                	jne    120dca0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1020>
 120dcbc:	e9 af fe ff ff       	jmp    120db70 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xef0>
 120dcc1:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120dcc8:	0f 1f 84 00 00 00 00 
 120dccf:	00 
 120dcd0:	48 8b 8d 70 ff ff ff 	mov    -0x90(%rbp),%rcx
 120dcd7:	44 0f b6 44 0d 80    	movzbl -0x80(%rbp,%rcx,1),%r8d
 120dcdd:	4d 85 c0             	test   %r8,%r8
 120dce0:	4c 8d 35 f1 18 e3 ff 	lea    -0x1ce70f(%rip),%r14        # 103f5d8 <__anon_72593>
 120dce7:	4c 8b bd 78 ff ff ff 	mov    -0x88(%rbp),%r15
 120dcee:	0f 84 42 fc ff ff    	je     120d936 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xcb6>
 120dcf4:	4c 8d 14 29          	lea    (%rcx,%rbp,1),%r10
 120dcf8:	49 83 c2 80          	add    $0xffffffffffffff80,%r10
 120dcfc:	31 d2                	xor    %edx,%edx
 120dcfe:	44 89 c1             	mov    %r8d,%ecx
 120dd01:	c1 e1 0a             	shl    $0xa,%ecx
 120dd04:	4c 8d 1c 29          	lea    (%rcx,%rbp,1),%r11
 120dd08:	49 81 c3 38 6c fe ff 	add    $0xfffffffffffe6c38,%r11
 120dd0f:	48 89 d1             	mov    %rdx,%rcx
 120dd12:	48 c1 e1 0a          	shl    $0xa,%rcx
 120dd16:	48 8d 1c 29          	lea    (%rcx,%rbp,1),%rbx
 120dd1a:	48 81 c3 38 6c fe ff 	add    $0xfffffffffffe6c38,%rbx
 120dd21:	8d 48 ff             	lea    -0x1(%rax),%ecx
 120dd24:	66 83 f9 03          	cmp    $0x3,%cx
 120dd28:	73 05                	jae    120dd2f <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x10af>
 120dd2a:	45 31 f6             	xor    %r14d,%r14d
 120dd2d:	eb 79                	jmp    120dda8 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1128>
 120dd2f:	41 89 c7             	mov    %eax,%r15d
 120dd32:	41 83 e7 fc          	and    $0xfffffffc,%r15d
 120dd36:	45 31 f6             	xor    %r14d,%r14d
 120dd39:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)
 120dd40:	42 0f b6 8c 37 06 04 	movzbl 0x406(%rdi,%r14,1),%ecx
 120dd47:	00 00 
 120dd49:	42 8b 34 b7          	mov    (%rdi,%r14,4),%esi
 120dd4d:	c1 e1 02             	shl    $0x2,%ecx
 120dd50:	41 29 34 0b          	sub    %esi,(%r11,%rcx,1)
 120dd54:	01 34 0b             	add    %esi,(%rbx,%rcx,1)
 120dd57:	42 0f b6 8c 37 07 04 	movzbl 0x407(%rdi,%r14,1),%ecx
 120dd5e:	00 00 
 120dd60:	42 8b 74 b7 04       	mov    0x4(%rdi,%r14,4),%esi
 120dd65:	c1 e1 02             	shl    $0x2,%ecx
 120dd68:	41 29 34 0b          	sub    %esi,(%r11,%rcx,1)
 120dd6c:	01 34 0b             	add    %esi,(%rbx,%rcx,1)
 120dd6f:	42 0f b6 8c 37 08 04 	movzbl 0x408(%rdi,%r14,1),%ecx
 120dd76:	00 00 
 120dd78:	42 8b 74 b7 08       	mov    0x8(%rdi,%r14,4),%esi
 120dd7d:	c1 e1 02             	shl    $0x2,%ecx
 120dd80:	41 29 34 0b          	sub    %esi,(%r11,%rcx,1)
 120dd84:	01 34 0b             	add    %esi,(%rbx,%rcx,1)
 120dd87:	42 0f b6 8c 37 09 04 	movzbl 0x409(%rdi,%r14,1),%ecx
 120dd8e:	00 00 
 120dd90:	42 8b 74 b7 0c       	mov    0xc(%rdi,%r14,4),%esi
 120dd95:	c1 e1 02             	shl    $0x2,%ecx
 120dd98:	41 29 34 0b          	sub    %esi,(%r11,%rcx,1)
 120dd9c:	01 34 0b             	add    %esi,(%rbx,%rcx,1)
 120dd9f:	49 83 c6 04          	add    $0x4,%r14
 120dda3:	4d 39 f7             	cmp    %r14,%r15
 120dda6:	75 98                	jne    120dd40 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x10c0>
 120dda8:	83 e0 03             	and    $0x3,%eax
 120ddab:	0f 84 4f fb ff ff    	je     120d900 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xc80>
 120ddb1:	4c 8b 8d f8 fe ff ff 	mov    -0x108(%rbp),%r9
 120ddb8:	4b 8d 0c b1          	lea    (%r9,%r14,4),%rcx
 120ddbc:	48 01 e9             	add    %rbp,%rcx
 120ddbf:	48 81 c1 38 2a fd ff 	add    $0xfffffffffffd2a38,%rcx
 120ddc6:	48 8d b5 3e 2e fd ff 	lea    -0x2d1c2(%rbp),%rsi
 120ddcd:	49 01 f6             	add    %rsi,%r14
 120ddd0:	4d 01 ce             	add    %r9,%r14
 120ddd3:	45 31 c9             	xor    %r9d,%r9d
 120ddd6:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 120dddd:	00 00 00 
 120dde0:	43 0f b6 34 0e       	movzbl (%r14,%r9,1),%esi
 120dde5:	46 8b 3c 89          	mov    (%rcx,%r9,4),%r15d
 120dde9:	c1 e6 02             	shl    $0x2,%esi
 120ddec:	45 29 3c 33          	sub    %r15d,(%r11,%rsi,1)
 120ddf0:	44 01 3c 33          	add    %r15d,(%rbx,%rsi,1)
 120ddf4:	49 ff c1             	inc    %r9
 120ddf7:	4c 39 c8             	cmp    %r9,%rax
 120ddfa:	75 e4                	jne    120dde0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1160>
 120ddfc:	e9 ff fa ff ff       	jmp    120d900 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0xc80>
 120de01:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120de08:	0f 1f 84 00 00 00 00 
 120de0f:	00 
 120de10:	c5 fd 76 c0          	vpcmpeqd %ymm0,%ymm0,%ymm0
 120de14:	c5 fe 7f 85 30 fe ff 	vmovdqu %ymm0,-0x1d0(%rbp)
 120de1b:	ff 
 120de1c:	c5 fe 7f 85 10 fe ff 	vmovdqu %ymm0,-0x1f0(%rbp)
 120de23:	ff 
 120de24:	48 83 bd 60 ff ff ff 	cmpq   $0x1,-0xa0(%rbp)
 120de2b:	01 
 120de2c:	0f 85 8e 01 00 00    	jne    120dfc0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1340>
 120de32:	31 db                	xor    %ebx,%ebx
 120de34:	45 31 ed             	xor    %r13d,%r13d
 120de37:	48 bf b3 01 00 00 00 	movabs $0x100000001b3,%rdi
 120de3e:	01 00 00 
 120de41:	4c 8b b5 60 ff ff ff 	mov    -0xa0(%rbp),%r14
 120de48:	41 f6 c6 01          	test   $0x1,%r14b
 120de4c:	74 64                	je     120deb2 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1232>
 120de4e:	44 8b b4 9d b0 fa ff 	mov    -0x550(%rbp,%rbx,4),%r14d
 120de55:	ff 
 120de56:	45 85 f6             	test   %r14d,%r14d
 120de59:	74 50                	je     120deab <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x122b>
 120de5b:	44 88 ac 1d 10 fe ff 	mov    %r13b,-0x1f0(%rbp,%rbx,1)
 120de62:	ff 
 120de63:	49 39 dd             	cmp    %rbx,%r13
 120de66:	74 40                	je     120dea8 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1228>
 120de68:	4c 89 e8             	mov    %r13,%rax
 120de6b:	48 c1 e0 0a          	shl    $0xa,%rax
 120de6f:	48 8d 3c 28          	lea    (%rax,%rbp,1),%rdi
 120de73:	48 81 c7 38 6c fe ff 	add    $0xfffffffffffe6c38,%rdi
 120de7a:	48 c1 e3 0a          	shl    $0xa,%rbx
 120de7e:	48 8d 34 2b          	lea    (%rbx,%rbp,1),%rsi
 120de82:	48 81 c6 38 6c fe ff 	add    $0xfffffffffffe6c38,%rsi
 120de89:	ba 00 04 00 00       	mov    $0x400,%edx
 120de8e:	c5 f8 77             	vzeroupper 
 120de91:	e8 3a 80 08 00       	call   1295ed0 <compiler_rt.memmove.memmoveFast>
 120de96:	48 bf b3 01 00 00 00 	movabs $0x100000001b3,%rdi
 120de9d:	01 00 00 
 120dea0:	46 89 b4 ad b0 fa ff 	mov    %r14d,-0x550(%rbp,%r13,4)
 120dea7:	ff 
 120dea8:	49 ff c5             	inc    %r13
 120deab:	4c 8b b5 60 ff ff ff 	mov    -0xa0(%rbp),%r14
 120deb2:	49 83 fd 02          	cmp    $0x2,%r13
 120deb6:	0f 82 14 f4 ff ff    	jb     120d2d0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x650>
 120debc:	b8 03 00 00 00       	mov    $0x3,%eax
 120dec1:	48 8d 8d 38 2e fd ff 	lea    -0x2d1c8(%rbp),%rcx
 120dec8:	eb 2c                	jmp    120def6 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1276>
 120deca:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 120ded0:	0f b6 54 05 80       	movzbl -0x80(%rbp,%rax,1),%edx
 120ded5:	0f b6 94 15 10 fe ff 	movzbl -0x1f0(%rbp,%rdx,1),%edx
 120dedc:	ff 
 120dedd:	88 54 05 80          	mov    %dl,-0x80(%rbp,%rax,1)
 120dee1:	48 83 c0 04          	add    $0x4,%rax
 120dee5:	48 81 c1 20 14 00 00 	add    $0x1420,%rcx
 120deec:	48 83 f8 43          	cmp    $0x43,%rax
 120def0:	0f 84 da 01 00 00    	je     120e0d0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1450>
 120def6:	83 39 00             	cmpl   $0x0,(%rcx)
 120def9:	74 75                	je     120df70 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x12f0>
 120defb:	0f b6 94 05 7d ff ff 	movzbl -0x83(%rbp,%rax,1),%edx
 120df02:	ff 
 120df03:	0f b6 94 15 10 fe ff 	movzbl -0x1f0(%rbp,%rdx,1),%edx
 120df0a:	ff 
 120df0b:	88 94 05 7d ff ff ff 	mov    %dl,-0x83(%rbp,%rax,1)
 120df12:	83 b9 08 05 00 00 00 	cmpl   $0x0,0x508(%rcx)
 120df19:	74 67                	je     120df82 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1302>
 120df1b:	0f b6 94 05 7e ff ff 	movzbl -0x82(%rbp,%rax,1),%edx
 120df22:	ff 
 120df23:	0f b6 94 15 10 fe ff 	movzbl -0x1f0(%rbp,%rdx,1),%edx
 120df2a:	ff 
 120df2b:	88 94 05 7e ff ff ff 	mov    %dl,-0x82(%rbp,%rax,1)
 120df32:	83 b9 10 0a 00 00 00 	cmpl   $0x0,0xa10(%rcx)
 120df39:	74 59                	je     120df94 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1314>
 120df3b:	0f b6 94 05 7f ff ff 	movzbl -0x81(%rbp,%rax,1),%edx
 120df42:	ff 
 120df43:	0f b6 94 15 10 fe ff 	movzbl -0x1f0(%rbp,%rdx,1),%edx
 120df4a:	ff 
 120df4b:	88 94 05 7f ff ff ff 	mov    %dl,-0x81(%rbp,%rax,1)
 120df52:	83 b9 18 0f 00 00 00 	cmpl   $0x0,0xf18(%rcx)
 120df59:	0f 85 71 ff ff ff    	jne    120ded0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1250>
 120df5f:	eb 49                	jmp    120dfaa <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x132a>
 120df61:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120df68:	0f 1f 84 00 00 00 00 
 120df6f:	00 
 120df70:	31 d2                	xor    %edx,%edx
 120df72:	88 94 05 7d ff ff ff 	mov    %dl,-0x83(%rbp,%rax,1)
 120df79:	83 b9 08 05 00 00 00 	cmpl   $0x0,0x508(%rcx)
 120df80:	75 99                	jne    120df1b <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x129b>
 120df82:	31 d2                	xor    %edx,%edx
 120df84:	88 94 05 7e ff ff ff 	mov    %dl,-0x82(%rbp,%rax,1)
 120df8b:	83 b9 10 0a 00 00 00 	cmpl   $0x0,0xa10(%rcx)
 120df92:	75 a7                	jne    120df3b <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x12bb>
 120df94:	31 d2                	xor    %edx,%edx
 120df96:	88 94 05 7f ff ff ff 	mov    %dl,-0x81(%rbp,%rax,1)
 120df9d:	83 b9 18 0f 00 00 00 	cmpl   $0x0,0xf18(%rcx)
 120dfa4:	0f 85 26 ff ff ff    	jne    120ded0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1250>
 120dfaa:	31 d2                	xor    %edx,%edx
 120dfac:	e9 2c ff ff ff       	jmp    120dedd <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x125d>
 120dfb1:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120dfb8:	0f 1f 84 00 00 00 00 
 120dfbf:	00 
 120dfc0:	4c 8d bd 38 70 fe ff 	lea    -0x18fc8(%rbp),%r15
 120dfc7:	31 db                	xor    %ebx,%ebx
 120dfc9:	45 31 ed             	xor    %r13d,%r13d
 120dfcc:	48 bf b3 01 00 00 00 	movabs $0x100000001b3,%rdi
 120dfd3:	01 00 00 
 120dfd6:	eb 23                	jmp    120dffb <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x137b>
 120dfd8:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 120dfdf:	00 
 120dfe0:	49 ff c5             	inc    %r13
 120dfe3:	48 83 c3 02          	add    $0x2,%rbx
 120dfe7:	49 81 c7 00 08 00 00 	add    $0x800,%r15
 120dfee:	48 39 9d b8 fe ff ff 	cmp    %rbx,-0x148(%rbp)
 120dff5:	0f 84 46 fe ff ff    	je     120de41 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x11c1>
 120dffb:	44 8b b4 9d b0 fa ff 	mov    -0x550(%rbp,%rbx,4),%r14d
 120e002:	ff 
 120e003:	45 85 f6             	test   %r14d,%r14d
 120e006:	74 10                	je     120e018 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1398>
 120e008:	44 88 ac 1d 10 fe ff 	mov    %r13b,-0x1f0(%rbp,%rbx,1)
 120e00f:	ff 
 120e010:	4c 39 eb             	cmp    %r13,%rbx
 120e013:	75 1b                	jne    120e030 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x13b0>
 120e015:	49 ff c5             	inc    %r13
 120e018:	44 8b b4 9d b4 fa ff 	mov    -0x54c(%rbp,%rbx,4),%r14d
 120e01f:	ff 
 120e020:	45 85 f6             	test   %r14d,%r14d
 120e023:	75 57                	jne    120e07c <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x13fc>
 120e025:	eb bc                	jmp    120dfe3 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1363>
 120e027:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 120e02e:	00 00 
 120e030:	4c 89 e8             	mov    %r13,%rax
 120e033:	48 c1 e0 0a          	shl    $0xa,%rax
 120e037:	48 8d 3c 28          	lea    (%rax,%rbp,1),%rdi
 120e03b:	48 81 c7 38 6c fe ff 	add    $0xfffffffffffe6c38,%rdi
 120e042:	49 8d b7 00 fc ff ff 	lea    -0x400(%r15),%rsi
 120e049:	ba 00 04 00 00       	mov    $0x400,%edx
 120e04e:	c5 f8 77             	vzeroupper 
 120e051:	e8 7a 7e 08 00       	call   1295ed0 <compiler_rt.memmove.memmoveFast>
 120e056:	48 bf b3 01 00 00 00 	movabs $0x100000001b3,%rdi
 120e05d:	01 00 00 
 120e060:	46 89 b4 ad b0 fa ff 	mov    %r14d,-0x550(%rbp,%r13,4)
 120e067:	ff 
 120e068:	49 ff c5             	inc    %r13
 120e06b:	44 8b b4 9d b4 fa ff 	mov    -0x54c(%rbp,%rbx,4),%r14d
 120e072:	ff 
 120e073:	45 85 f6             	test   %r14d,%r14d
 120e076:	0f 84 67 ff ff ff    	je     120dfe3 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1363>
 120e07c:	48 8d 43 01          	lea    0x1(%rbx),%rax
 120e080:	44 88 ac 1d 11 fe ff 	mov    %r13b,-0x1ef(%rbp,%rbx,1)
 120e087:	ff 
 120e088:	4c 39 e8             	cmp    %r13,%rax
 120e08b:	0f 84 4f ff ff ff    	je     120dfe0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1360>
 120e091:	4c 89 e8             	mov    %r13,%rax
 120e094:	48 c1 e0 0a          	shl    $0xa,%rax
 120e098:	48 8d 3c 28          	lea    (%rax,%rbp,1),%rdi
 120e09c:	48 81 c7 38 6c fe ff 	add    $0xfffffffffffe6c38,%rdi
 120e0a3:	ba 00 04 00 00       	mov    $0x400,%edx
 120e0a8:	4c 89 fe             	mov    %r15,%rsi
 120e0ab:	c5 f8 77             	vzeroupper 
 120e0ae:	e8 1d 7e 08 00       	call   1295ed0 <compiler_rt.memmove.memmoveFast>
 120e0b3:	48 bf b3 01 00 00 00 	movabs $0x100000001b3,%rdi
 120e0ba:	01 00 00 
 120e0bd:	46 89 b4 ad b0 fa ff 	mov    %r14d,-0x550(%rbp,%r13,4)
 120e0c4:	ff 
 120e0c5:	e9 16 ff ff ff       	jmp    120dfe0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1360>
 120e0ca:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 120e0d0:	4c 89 e8             	mov    %r13,%rax
 120e0d3:	48 b9 25 23 22 84 e4 	movabs $0xcbf29ce484222325,%rcx
 120e0da:	9c f2 cb 
 120e0dd:	48 31 c8             	xor    %rcx,%rax
 120e0e0:	48 0f af c7          	imul   %rdi,%rax
 120e0e4:	0f b6 4d 80          	movzbl -0x80(%rbp),%ecx
 120e0e8:	48 31 c1             	xor    %rax,%rcx
 120e0eb:	48 0f af cf          	imul   %rdi,%rcx
 120e0ef:	0f b6 45 81          	movzbl -0x7f(%rbp),%eax
 120e0f3:	48 31 c8             	xor    %rcx,%rax
 120e0f6:	48 0f af c7          	imul   %rdi,%rax
 120e0fa:	0f b6 4d 82          	movzbl -0x7e(%rbp),%ecx
 120e0fe:	48 31 c1             	xor    %rax,%rcx
 120e101:	48 0f af cf          	imul   %rdi,%rcx
 120e105:	0f b6 45 83          	movzbl -0x7d(%rbp),%eax
 120e109:	48 31 c8             	xor    %rcx,%rax
 120e10c:	48 0f af c7          	imul   %rdi,%rax
 120e110:	0f b6 4d 84          	movzbl -0x7c(%rbp),%ecx
 120e114:	48 31 c1             	xor    %rax,%rcx
 120e117:	48 0f af cf          	imul   %rdi,%rcx
 120e11b:	0f b6 45 85          	movzbl -0x7b(%rbp),%eax
 120e11f:	48 31 c8             	xor    %rcx,%rax
 120e122:	48 0f af c7          	imul   %rdi,%rax
 120e126:	0f b6 4d 86          	movzbl -0x7a(%rbp),%ecx
 120e12a:	48 31 c1             	xor    %rax,%rcx
 120e12d:	48 0f af cf          	imul   %rdi,%rcx
 120e131:	0f b6 45 87          	movzbl -0x79(%rbp),%eax
 120e135:	48 31 c8             	xor    %rcx,%rax
 120e138:	48 0f af c7          	imul   %rdi,%rax
 120e13c:	0f b6 4d 88          	movzbl -0x78(%rbp),%ecx
 120e140:	48 31 c1             	xor    %rax,%rcx
 120e143:	48 0f af cf          	imul   %rdi,%rcx
 120e147:	0f b6 45 89          	movzbl -0x77(%rbp),%eax
 120e14b:	48 31 c8             	xor    %rcx,%rax
 120e14e:	48 0f af c7          	imul   %rdi,%rax
 120e152:	0f b6 4d 8a          	movzbl -0x76(%rbp),%ecx
 120e156:	48 31 c1             	xor    %rax,%rcx
 120e159:	48 0f af cf          	imul   %rdi,%rcx
 120e15d:	0f b6 45 8b          	movzbl -0x75(%rbp),%eax
 120e161:	48 31 c8             	xor    %rcx,%rax
 120e164:	48 0f af c7          	imul   %rdi,%rax
 120e168:	0f b6 4d 8c          	movzbl -0x74(%rbp),%ecx
 120e16c:	48 31 c1             	xor    %rax,%rcx
 120e16f:	48 0f af cf          	imul   %rdi,%rcx
 120e173:	0f b6 45 8d          	movzbl -0x73(%rbp),%eax
 120e177:	48 31 c8             	xor    %rcx,%rax
 120e17a:	48 0f af c7          	imul   %rdi,%rax
 120e17e:	0f b6 4d 8e          	movzbl -0x72(%rbp),%ecx
 120e182:	48 31 c1             	xor    %rax,%rcx
 120e185:	48 0f af cf          	imul   %rdi,%rcx
 120e189:	0f b6 45 8f          	movzbl -0x71(%rbp),%eax
 120e18d:	48 31 c8             	xor    %rcx,%rax
 120e190:	48 0f af c7          	imul   %rdi,%rax
 120e194:	0f b6 4d 90          	movzbl -0x70(%rbp),%ecx
 120e198:	48 31 c1             	xor    %rax,%rcx
 120e19b:	48 0f af cf          	imul   %rdi,%rcx
 120e19f:	0f b6 45 91          	movzbl -0x6f(%rbp),%eax
 120e1a3:	48 31 c8             	xor    %rcx,%rax
 120e1a6:	48 0f af c7          	imul   %rdi,%rax
 120e1aa:	0f b6 4d 92          	movzbl -0x6e(%rbp),%ecx
 120e1ae:	48 31 c1             	xor    %rax,%rcx
 120e1b1:	48 0f af cf          	imul   %rdi,%rcx
 120e1b5:	0f b6 45 93          	movzbl -0x6d(%rbp),%eax
 120e1b9:	48 31 c8             	xor    %rcx,%rax
 120e1bc:	48 0f af c7          	imul   %rdi,%rax
 120e1c0:	0f b6 4d 94          	movzbl -0x6c(%rbp),%ecx
 120e1c4:	48 31 c1             	xor    %rax,%rcx
 120e1c7:	48 0f af cf          	imul   %rdi,%rcx
 120e1cb:	0f b6 45 95          	movzbl -0x6b(%rbp),%eax
 120e1cf:	48 31 c8             	xor    %rcx,%rax
 120e1d2:	48 0f af c7          	imul   %rdi,%rax
 120e1d6:	0f b6 4d 96          	movzbl -0x6a(%rbp),%ecx
 120e1da:	48 31 c1             	xor    %rax,%rcx
 120e1dd:	48 0f af cf          	imul   %rdi,%rcx
 120e1e1:	0f b6 45 97          	movzbl -0x69(%rbp),%eax
 120e1e5:	48 31 c8             	xor    %rcx,%rax
 120e1e8:	48 0f af c7          	imul   %rdi,%rax
 120e1ec:	0f b6 4d 98          	movzbl -0x68(%rbp),%ecx
 120e1f0:	48 31 c1             	xor    %rax,%rcx
 120e1f3:	48 0f af cf          	imul   %rdi,%rcx
 120e1f7:	0f b6 45 99          	movzbl -0x67(%rbp),%eax
 120e1fb:	48 31 c8             	xor    %rcx,%rax
 120e1fe:	48 0f af c7          	imul   %rdi,%rax
 120e202:	0f b6 4d 9a          	movzbl -0x66(%rbp),%ecx
 120e206:	48 31 c1             	xor    %rax,%rcx
 120e209:	48 0f af cf          	imul   %rdi,%rcx
 120e20d:	0f b6 45 9b          	movzbl -0x65(%rbp),%eax
 120e211:	48 31 c8             	xor    %rcx,%rax
 120e214:	48 0f af c7          	imul   %rdi,%rax
 120e218:	0f b6 4d 9c          	movzbl -0x64(%rbp),%ecx
 120e21c:	48 31 c1             	xor    %rax,%rcx
 120e21f:	48 0f af cf          	imul   %rdi,%rcx
 120e223:	0f b6 45 9d          	movzbl -0x63(%rbp),%eax
 120e227:	48 31 c8             	xor    %rcx,%rax
 120e22a:	48 0f af c7          	imul   %rdi,%rax
 120e22e:	0f b6 4d 9e          	movzbl -0x62(%rbp),%ecx
 120e232:	48 31 c1             	xor    %rax,%rcx
 120e235:	48 0f af cf          	imul   %rdi,%rcx
 120e239:	0f b6 45 9f          	movzbl -0x61(%rbp),%eax
 120e23d:	48 31 c8             	xor    %rcx,%rax
 120e240:	48 0f af c7          	imul   %rdi,%rax
 120e244:	0f b6 4d a0          	movzbl -0x60(%rbp),%ecx
 120e248:	48 31 c1             	xor    %rax,%rcx
 120e24b:	48 0f af cf          	imul   %rdi,%rcx
 120e24f:	0f b6 45 a1          	movzbl -0x5f(%rbp),%eax
 120e253:	48 31 c8             	xor    %rcx,%rax
 120e256:	48 0f af c7          	imul   %rdi,%rax
 120e25a:	0f b6 4d a2          	movzbl -0x5e(%rbp),%ecx
 120e25e:	48 31 c1             	xor    %rax,%rcx
 120e261:	48 0f af cf          	imul   %rdi,%rcx
 120e265:	0f b6 45 a3          	movzbl -0x5d(%rbp),%eax
 120e269:	48 31 c8             	xor    %rcx,%rax
 120e26c:	48 0f af c7          	imul   %rdi,%rax
 120e270:	0f b6 4d a4          	movzbl -0x5c(%rbp),%ecx
 120e274:	48 31 c1             	xor    %rax,%rcx
 120e277:	48 0f af cf          	imul   %rdi,%rcx
 120e27b:	0f b6 45 a5          	movzbl -0x5b(%rbp),%eax
 120e27f:	48 31 c8             	xor    %rcx,%rax
 120e282:	48 0f af c7          	imul   %rdi,%rax
 120e286:	0f b6 4d a6          	movzbl -0x5a(%rbp),%ecx
 120e28a:	48 31 c1             	xor    %rax,%rcx
 120e28d:	48 0f af cf          	imul   %rdi,%rcx
 120e291:	0f b6 45 a7          	movzbl -0x59(%rbp),%eax
 120e295:	48 31 c8             	xor    %rcx,%rax
 120e298:	48 0f af c7          	imul   %rdi,%rax
 120e29c:	0f b6 4d a8          	movzbl -0x58(%rbp),%ecx
 120e2a0:	48 31 c1             	xor    %rax,%rcx
 120e2a3:	48 0f af cf          	imul   %rdi,%rcx
 120e2a7:	0f b6 45 a9          	movzbl -0x57(%rbp),%eax
 120e2ab:	48 31 c8             	xor    %rcx,%rax
 120e2ae:	48 0f af c7          	imul   %rdi,%rax
 120e2b2:	0f b6 4d aa          	movzbl -0x56(%rbp),%ecx
 120e2b6:	48 31 c1             	xor    %rax,%rcx
 120e2b9:	48 0f af cf          	imul   %rdi,%rcx
 120e2bd:	0f b6 45 ab          	movzbl -0x55(%rbp),%eax
 120e2c1:	48 31 c8             	xor    %rcx,%rax
 120e2c4:	48 0f af c7          	imul   %rdi,%rax
 120e2c8:	0f b6 4d ac          	movzbl -0x54(%rbp),%ecx
 120e2cc:	48 31 c1             	xor    %rax,%rcx
 120e2cf:	48 0f af cf          	imul   %rdi,%rcx
 120e2d3:	0f b6 45 ad          	movzbl -0x53(%rbp),%eax
 120e2d7:	48 31 c8             	xor    %rcx,%rax
 120e2da:	48 0f af c7          	imul   %rdi,%rax
 120e2de:	0f b6 4d ae          	movzbl -0x52(%rbp),%ecx
 120e2e2:	48 31 c1             	xor    %rax,%rcx
 120e2e5:	48 0f af cf          	imul   %rdi,%rcx
 120e2e9:	0f b6 45 af          	movzbl -0x51(%rbp),%eax
 120e2ed:	48 31 c8             	xor    %rcx,%rax
 120e2f0:	48 0f af c7          	imul   %rdi,%rax
 120e2f4:	0f b6 4d b0          	movzbl -0x50(%rbp),%ecx
 120e2f8:	48 31 c1             	xor    %rax,%rcx
 120e2fb:	48 0f af cf          	imul   %rdi,%rcx
 120e2ff:	0f b6 45 b1          	movzbl -0x4f(%rbp),%eax
 120e303:	48 31 c8             	xor    %rcx,%rax
 120e306:	48 0f af c7          	imul   %rdi,%rax
 120e30a:	0f b6 4d b2          	movzbl -0x4e(%rbp),%ecx
 120e30e:	48 31 c1             	xor    %rax,%rcx
 120e311:	48 0f af cf          	imul   %rdi,%rcx
 120e315:	0f b6 45 b3          	movzbl -0x4d(%rbp),%eax
 120e319:	48 31 c8             	xor    %rcx,%rax
 120e31c:	48 0f af c7          	imul   %rdi,%rax
 120e320:	0f b6 4d b4          	movzbl -0x4c(%rbp),%ecx
 120e324:	48 31 c1             	xor    %rax,%rcx
 120e327:	48 0f af cf          	imul   %rdi,%rcx
 120e32b:	0f b6 45 b5          	movzbl -0x4b(%rbp),%eax
 120e32f:	48 31 c8             	xor    %rcx,%rax
 120e332:	48 0f af c7          	imul   %rdi,%rax
 120e336:	0f b6 4d b6          	movzbl -0x4a(%rbp),%ecx
 120e33a:	48 31 c1             	xor    %rax,%rcx
 120e33d:	48 0f af cf          	imul   %rdi,%rcx
 120e341:	0f b6 45 b7          	movzbl -0x49(%rbp),%eax
 120e345:	48 31 c8             	xor    %rcx,%rax
 120e348:	48 0f af c7          	imul   %rdi,%rax
 120e34c:	0f b6 4d b8          	movzbl -0x48(%rbp),%ecx
 120e350:	48 31 c1             	xor    %rax,%rcx
 120e353:	48 0f af cf          	imul   %rdi,%rcx
 120e357:	0f b6 45 b9          	movzbl -0x47(%rbp),%eax
 120e35b:	48 31 c8             	xor    %rcx,%rax
 120e35e:	48 0f af c7          	imul   %rdi,%rax
 120e362:	0f b6 4d ba          	movzbl -0x46(%rbp),%ecx
 120e366:	48 31 c1             	xor    %rax,%rcx
 120e369:	48 0f af cf          	imul   %rdi,%rcx
 120e36d:	0f b6 45 bb          	movzbl -0x45(%rbp),%eax
 120e371:	48 31 c8             	xor    %rcx,%rax
 120e374:	48 0f af c7          	imul   %rdi,%rax
 120e378:	0f b6 4d bc          	movzbl -0x44(%rbp),%ecx
 120e37c:	48 31 c1             	xor    %rax,%rcx
 120e37f:	48 0f af cf          	imul   %rdi,%rcx
 120e383:	0f b6 45 bd          	movzbl -0x43(%rbp),%eax
 120e387:	48 31 c8             	xor    %rcx,%rax
 120e38a:	48 0f af c7          	imul   %rdi,%rax
 120e38e:	0f b6 4d be          	movzbl -0x42(%rbp),%ecx
 120e392:	48 31 c1             	xor    %rax,%rcx
 120e395:	48 0f af cf          	imul   %rdi,%rcx
 120e399:	44 0f b6 45 bf       	movzbl -0x41(%rbp),%r8d
 120e39e:	49 31 c8             	xor    %rcx,%r8
 120e3a1:	4c 0f af c7          	imul   %rdi,%r8
 120e3a5:	48 8b b5 a0 f6 ff ff 	mov    -0x960(%rbp),%rsi
 120e3ac:	48 85 f6             	test   %rsi,%rsi
 120e3af:	74 5e                	je     120e40f <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x178f>
 120e3b1:	c5 fe 6f 45 80       	vmovdqu -0x80(%rbp),%ymm0
 120e3b6:	c5 fe 6f 4d a0       	vmovdqu -0x60(%rbp),%ymm1
 120e3bb:	48 8d 85 10 ef ff ff 	lea    -0x10f0(%rbp),%rax
 120e3c2:	48 89 f1             	mov    %rsi,%rcx
 120e3c5:	eb 12                	jmp    120e3d9 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1759>
 120e3c7:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 120e3ce:	00 00 
 120e3d0:	48 83 c0 58          	add    $0x58,%rax
 120e3d4:	48 ff c9             	dec    %rcx
 120e3d7:	74 36                	je     120e40f <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x178f>
 120e3d9:	4c 39 00             	cmp    %r8,(%rax)
 120e3dc:	75 f2                	jne    120e3d0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1750>
 120e3de:	0f b6 50 10          	movzbl 0x10(%rax),%edx
 120e3e2:	83 e2 7f             	and    $0x7f,%edx
 120e3e5:	49 39 d5             	cmp    %rdx,%r13
 120e3e8:	75 e6                	jne    120e3d0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1750>
 120e3ea:	c5 fd ef 50 11       	vpxor  0x11(%rax),%ymm0,%ymm2
 120e3ef:	c5 f5 ef 58 31       	vpxor  0x31(%rax),%ymm1,%ymm3
 120e3f4:	c5 ed eb d3          	vpor   %ymm3,%ymm2,%ymm2
 120e3f8:	c4 e2 7d 17 d2       	vptest %ymm2,%ymm2
 120e3fd:	75 d1                	jne    120e3d0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1750>
 120e3ff:	48 8b 58 08          	mov    0x8(%rax),%rbx
 120e403:	48 ff 85 a8 f6 ff ff 	incq   -0x958(%rbp)
 120e40a:	e9 68 06 00 00       	jmp    120ea77 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1df7>
 120e40f:	4c 89 85 f8 fe ff ff 	mov    %r8,-0x108(%rbp)
 120e416:	48 89 b5 50 ff ff ff 	mov    %rsi,-0xb0(%rbp)
 120e41d:	48 8b 85 18 2a fd ff 	mov    -0x2d5e8(%rbp),%rax
 120e424:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 120e42b:	48 8b 85 20 2a fd ff 	mov    -0x2d5e0(%rbp),%rax
 120e432:	48 89 85 70 ff ff ff 	mov    %rax,-0x90(%rbp)
 120e439:	4c 8d bd 54 6c fe ff 	lea    -0x193ac(%rbp),%r15
 120e440:	31 c0                	xor    %eax,%eax
 120e442:	31 db                	xor    %ebx,%ebx
 120e444:	4c 89 ad 48 ff ff ff 	mov    %r13,-0xb8(%rbp)
 120e44b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 120e450:	48 89 85 40 ff ff ff 	mov    %rax,-0xc0(%rbp)
 120e457:	48 c1 e0 0a          	shl    $0xa,%rax
 120e45b:	4c 8d 34 28          	lea    (%rax,%rbp,1),%r14
 120e45f:	49 81 c6 38 6c fe ff 	add    $0xfffffffffffe6c38,%r14
 120e466:	48 b9 25 23 22 84 e4 	movabs $0xcbf29ce484222325,%rcx
 120e46d:	9c f2 cb 
 120e470:	31 c0                	xor    %eax,%eax
 120e472:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120e479:	1f 84 00 00 00 00 00 
 120e480:	41 8b 54 87 e4       	mov    -0x1c(%r15,%rax,4),%edx
 120e485:	41 8b 74 87 e8       	mov    -0x18(%r15,%rax,4),%esi
 120e48a:	48 31 ca             	xor    %rcx,%rdx
 120e48d:	48 0f af d7          	imul   %rdi,%rdx
 120e491:	48 31 d6             	xor    %rdx,%rsi
 120e494:	48 0f af f7          	imul   %rdi,%rsi
 120e498:	41 8b 4c 87 ec       	mov    -0x14(%r15,%rax,4),%ecx
 120e49d:	48 31 f1             	xor    %rsi,%rcx
 120e4a0:	48 0f af cf          	imul   %rdi,%rcx
 120e4a4:	41 8b 54 87 f0       	mov    -0x10(%r15,%rax,4),%edx
 120e4a9:	48 31 ca             	xor    %rcx,%rdx
 120e4ac:	48 0f af d7          	imul   %rdi,%rdx
 120e4b0:	41 8b 4c 87 f4       	mov    -0xc(%r15,%rax,4),%ecx
 120e4b5:	48 31 d1             	xor    %rdx,%rcx
 120e4b8:	48 0f af cf          	imul   %rdi,%rcx
 120e4bc:	41 8b 54 87 f8       	mov    -0x8(%r15,%rax,4),%edx
 120e4c1:	48 31 ca             	xor    %rcx,%rdx
 120e4c4:	48 0f af d7          	imul   %rdi,%rdx
 120e4c8:	41 8b 74 87 fc       	mov    -0x4(%r15,%rax,4),%esi
 120e4cd:	48 31 d6             	xor    %rdx,%rsi
 120e4d0:	48 0f af f7          	imul   %rdi,%rsi
 120e4d4:	41 8b 0c 87          	mov    (%r15,%rax,4),%ecx
 120e4d8:	48 31 f1             	xor    %rsi,%rcx
 120e4db:	48 0f af cf          	imul   %rdi,%rcx
 120e4df:	48 83 c0 08          	add    $0x8,%rax
 120e4e3:	48 3d 00 01 00 00    	cmp    $0x100,%rax
 120e4e9:	75 95                	jne    120e480 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1800>
 120e4eb:	89 c8                	mov    %ecx,%eax
 120e4ed:	c1 e8 03             	shr    $0x3,%eax
 120e4f0:	83 e0 08             	and    $0x8,%eax
 120e4f3:	48 8b 84 05 08 2a fd 	mov    -0x2d5f8(%rbp,%rax,1),%rax
 120e4fa:	ff 
 120e4fb:	48 0f a3 c8          	bt     %rcx,%rax
 120e4ff:	0f 83 7b 03 00 00    	jae    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e505:	89 c8                	mov    %ecx,%eax
 120e507:	83 e0 7f             	and    $0x7f,%eax
 120e50a:	48 69 c0 10 04 00 00 	imul   $0x410,%rax,%rax
 120e511:	48 39 8c 05 08 22 fb 	cmp    %rcx,-0x4ddf8(%rbp,%rax,1)
 120e518:	ff 
 120e519:	0f 85 61 03 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e51f:	48 01 e8             	add    %rbp,%rax
 120e522:	48 05 08 22 fb ff    	add    $0xfffffffffffb2208,%rax
 120e528:	c5 fe 6f 40 10       	vmovdqu 0x10(%rax),%ymm0
 120e52d:	c4 c1 7d ef 06       	vpxor  (%r14),%ymm0,%ymm0
 120e532:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e537:	0f 85 43 03 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e53d:	c5 fe 6f 40 30       	vmovdqu 0x30(%rax),%ymm0
 120e542:	c4 c1 7d ef 46 20    	vpxor  0x20(%r14),%ymm0,%ymm0
 120e548:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e54d:	0f 85 2d 03 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e553:	c5 fe 6f 40 50       	vmovdqu 0x50(%rax),%ymm0
 120e558:	c4 c1 7d ef 46 40    	vpxor  0x40(%r14),%ymm0,%ymm0
 120e55e:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e563:	0f 85 17 03 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e569:	c5 fe 6f 40 70       	vmovdqu 0x70(%rax),%ymm0
 120e56e:	c4 c1 7d ef 46 60    	vpxor  0x60(%r14),%ymm0,%ymm0
 120e574:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e579:	0f 85 01 03 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e57f:	c5 fe 6f 80 90 00 00 	vmovdqu 0x90(%rax),%ymm0
 120e586:	00 
 120e587:	c4 c1 7d ef 86 80 00 	vpxor  0x80(%r14),%ymm0,%ymm0
 120e58e:	00 00 
 120e590:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e595:	0f 85 e5 02 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e59b:	c5 fe 6f 80 b0 00 00 	vmovdqu 0xb0(%rax),%ymm0
 120e5a2:	00 
 120e5a3:	c4 c1 7d ef 86 a0 00 	vpxor  0xa0(%r14),%ymm0,%ymm0
 120e5aa:	00 00 
 120e5ac:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e5b1:	0f 85 c9 02 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e5b7:	c5 fe 6f 80 d0 00 00 	vmovdqu 0xd0(%rax),%ymm0
 120e5be:	00 
 120e5bf:	c4 c1 7d ef 86 c0 00 	vpxor  0xc0(%r14),%ymm0,%ymm0
 120e5c6:	00 00 
 120e5c8:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e5cd:	0f 85 ad 02 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e5d3:	c5 fe 6f 80 f0 00 00 	vmovdqu 0xf0(%rax),%ymm0
 120e5da:	00 
 120e5db:	c4 c1 7d ef 86 e0 00 	vpxor  0xe0(%r14),%ymm0,%ymm0
 120e5e2:	00 00 
 120e5e4:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e5e9:	0f 85 91 02 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e5ef:	c5 fe 6f 80 10 01 00 	vmovdqu 0x110(%rax),%ymm0
 120e5f6:	00 
 120e5f7:	c4 c1 7d ef 86 00 01 	vpxor  0x100(%r14),%ymm0,%ymm0
 120e5fe:	00 00 
 120e600:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e605:	0f 85 75 02 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e60b:	c5 fe 6f 80 30 01 00 	vmovdqu 0x130(%rax),%ymm0
 120e612:	00 
 120e613:	c4 c1 7d ef 86 20 01 	vpxor  0x120(%r14),%ymm0,%ymm0
 120e61a:	00 00 
 120e61c:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e621:	0f 85 59 02 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e627:	c5 fe 6f 80 50 01 00 	vmovdqu 0x150(%rax),%ymm0
 120e62e:	00 
 120e62f:	c4 c1 7d ef 86 40 01 	vpxor  0x140(%r14),%ymm0,%ymm0
 120e636:	00 00 
 120e638:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e63d:	0f 85 3d 02 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e643:	c5 fe 6f 80 70 01 00 	vmovdqu 0x170(%rax),%ymm0
 120e64a:	00 
 120e64b:	c4 c1 7d ef 86 60 01 	vpxor  0x160(%r14),%ymm0,%ymm0
 120e652:	00 00 
 120e654:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e659:	0f 85 21 02 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e65f:	c5 fe 6f 80 90 01 00 	vmovdqu 0x190(%rax),%ymm0
 120e666:	00 
 120e667:	c4 c1 7d ef 86 80 01 	vpxor  0x180(%r14),%ymm0,%ymm0
 120e66e:	00 00 
 120e670:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e675:	0f 85 05 02 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e67b:	c5 fe 6f 80 b0 01 00 	vmovdqu 0x1b0(%rax),%ymm0
 120e682:	00 
 120e683:	c4 c1 7d ef 86 a0 01 	vpxor  0x1a0(%r14),%ymm0,%ymm0
 120e68a:	00 00 
 120e68c:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e691:	0f 85 e9 01 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e697:	c5 fe 6f 80 d0 01 00 	vmovdqu 0x1d0(%rax),%ymm0
 120e69e:	00 
 120e69f:	c4 c1 7d ef 86 c0 01 	vpxor  0x1c0(%r14),%ymm0,%ymm0
 120e6a6:	00 00 
 120e6a8:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e6ad:	0f 85 cd 01 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e6b3:	c5 fe 6f 80 f0 01 00 	vmovdqu 0x1f0(%rax),%ymm0
 120e6ba:	00 
 120e6bb:	c4 c1 7d ef 86 e0 01 	vpxor  0x1e0(%r14),%ymm0,%ymm0
 120e6c2:	00 00 
 120e6c4:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e6c9:	0f 85 b1 01 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e6cf:	c5 fe 6f 80 10 02 00 	vmovdqu 0x210(%rax),%ymm0
 120e6d6:	00 
 120e6d7:	c4 c1 7d ef 86 00 02 	vpxor  0x200(%r14),%ymm0,%ymm0
 120e6de:	00 00 
 120e6e0:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e6e5:	0f 85 95 01 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e6eb:	c5 fe 6f 80 30 02 00 	vmovdqu 0x230(%rax),%ymm0
 120e6f2:	00 
 120e6f3:	c4 c1 7d ef 86 20 02 	vpxor  0x220(%r14),%ymm0,%ymm0
 120e6fa:	00 00 
 120e6fc:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e701:	0f 85 79 01 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e707:	c5 fe 6f 80 50 02 00 	vmovdqu 0x250(%rax),%ymm0
 120e70e:	00 
 120e70f:	c4 c1 7d ef 86 40 02 	vpxor  0x240(%r14),%ymm0,%ymm0
 120e716:	00 00 
 120e718:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e71d:	0f 85 5d 01 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e723:	c5 fe 6f 80 70 02 00 	vmovdqu 0x270(%rax),%ymm0
 120e72a:	00 
 120e72b:	c4 c1 7d ef 86 60 02 	vpxor  0x260(%r14),%ymm0,%ymm0
 120e732:	00 00 
 120e734:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e739:	0f 85 41 01 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e73f:	c5 fe 6f 80 90 02 00 	vmovdqu 0x290(%rax),%ymm0
 120e746:	00 
 120e747:	c4 c1 7d ef 86 80 02 	vpxor  0x280(%r14),%ymm0,%ymm0
 120e74e:	00 00 
 120e750:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e755:	0f 85 25 01 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e75b:	c5 fe 6f 80 b0 02 00 	vmovdqu 0x2b0(%rax),%ymm0
 120e762:	00 
 120e763:	c4 c1 7d ef 86 a0 02 	vpxor  0x2a0(%r14),%ymm0,%ymm0
 120e76a:	00 00 
 120e76c:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e771:	0f 85 09 01 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e777:	c5 fe 6f 80 d0 02 00 	vmovdqu 0x2d0(%rax),%ymm0
 120e77e:	00 
 120e77f:	c4 c1 7d ef 86 c0 02 	vpxor  0x2c0(%r14),%ymm0,%ymm0
 120e786:	00 00 
 120e788:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e78d:	0f 85 ed 00 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e793:	c5 fe 6f 80 f0 02 00 	vmovdqu 0x2f0(%rax),%ymm0
 120e79a:	00 
 120e79b:	c4 c1 7d ef 86 e0 02 	vpxor  0x2e0(%r14),%ymm0,%ymm0
 120e7a2:	00 00 
 120e7a4:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e7a9:	0f 85 d1 00 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e7af:	c5 fe 6f 80 10 03 00 	vmovdqu 0x310(%rax),%ymm0
 120e7b6:	00 
 120e7b7:	c4 c1 7d ef 86 00 03 	vpxor  0x300(%r14),%ymm0,%ymm0
 120e7be:	00 00 
 120e7c0:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e7c5:	0f 85 b5 00 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e7cb:	c5 fe 6f 80 30 03 00 	vmovdqu 0x330(%rax),%ymm0
 120e7d2:	00 
 120e7d3:	c4 c1 7d ef 86 20 03 	vpxor  0x320(%r14),%ymm0,%ymm0
 120e7da:	00 00 
 120e7dc:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e7e1:	0f 85 99 00 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e7e7:	c5 fe 6f 80 50 03 00 	vmovdqu 0x350(%rax),%ymm0
 120e7ee:	00 
 120e7ef:	c4 c1 7d ef 86 40 03 	vpxor  0x340(%r14),%ymm0,%ymm0
 120e7f6:	00 00 
 120e7f8:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e7fd:	0f 85 7d 00 00 00    	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e803:	c5 fe 6f 80 70 03 00 	vmovdqu 0x370(%rax),%ymm0
 120e80a:	00 
 120e80b:	c4 c1 7d ef 86 60 03 	vpxor  0x360(%r14),%ymm0,%ymm0
 120e812:	00 00 
 120e814:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e819:	75 65                	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e81b:	c5 fe 6f 80 90 03 00 	vmovdqu 0x390(%rax),%ymm0
 120e822:	00 
 120e823:	c4 c1 7d ef 86 80 03 	vpxor  0x380(%r14),%ymm0,%ymm0
 120e82a:	00 00 
 120e82c:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e831:	75 4d                	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e833:	c5 fe 6f 80 b0 03 00 	vmovdqu 0x3b0(%rax),%ymm0
 120e83a:	00 
 120e83b:	c4 c1 7d ef 86 a0 03 	vpxor  0x3a0(%r14),%ymm0,%ymm0
 120e842:	00 00 
 120e844:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e849:	75 35                	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e84b:	c5 fe 6f 80 d0 03 00 	vmovdqu 0x3d0(%rax),%ymm0
 120e852:	00 
 120e853:	c4 c1 7d ef 86 c0 03 	vpxor  0x3c0(%r14),%ymm0,%ymm0
 120e85a:	00 00 
 120e85c:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e861:	75 1d                	jne    120e880 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c00>
 120e863:	c5 fe 6f 80 f0 03 00 	vmovdqu 0x3f0(%rax),%ymm0
 120e86a:	00 
 120e86b:	c4 c1 7d ef 86 e0 03 	vpxor  0x3e0(%r14),%ymm0,%ymm0
 120e872:	00 00 
 120e874:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120e879:	0f 84 4a 01 00 00    	je     120e9c9 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1d49>
 120e87f:	90                   	nop
 120e880:	48 8d bd 50 fe ff ff 	lea    -0x1b0(%rbp),%rdi
 120e887:	4c 89 f6             	mov    %r14,%rsi
 120e88a:	4c 89 e2             	mov    %r12,%rdx
 120e88d:	c5 f8 77             	vzeroupper 
 120e890:	e8 db dd ff ff       	call   120c670 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46128>
 120e895:	0f b7 85 58 fe ff ff 	movzwl -0x1a8(%rbp),%eax
 120e89c:	66 85 c0             	test   %ax,%ax
 120e89f:	0f 85 42 04 00 00    	jne    120ece7 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x2067>
 120e8a5:	4d 89 f0             	mov    %r14,%r8
 120e8a8:	49 89 dd             	mov    %rbx,%r13
 120e8ab:	48 ff 85 70 ff ff ff 	incq   -0x90(%rbp)
 120e8b2:	48 8b 9d 50 fe ff ff 	mov    -0x1b0(%rbp),%rbx
 120e8b9:	49 be 25 23 22 84 e4 	movabs $0xcbf29ce484222325,%r14
 120e8c0:	9c f2 cb 
 120e8c3:	31 c0                	xor    %eax,%eax
 120e8c5:	48 be b3 01 00 00 00 	movabs $0x100000001b3,%rsi
 120e8cc:	01 00 00 
 120e8cf:	90                   	nop
 120e8d0:	41 8b 4c 87 e4       	mov    -0x1c(%r15,%rax,4),%ecx
 120e8d5:	41 8b 54 87 e8       	mov    -0x18(%r15,%rax,4),%edx
 120e8da:	4c 31 f1             	xor    %r14,%rcx
 120e8dd:	48 0f af ce          	imul   %rsi,%rcx
 120e8e1:	48 31 ca             	xor    %rcx,%rdx
 120e8e4:	48 0f af d6          	imul   %rsi,%rdx
 120e8e8:	41 8b 4c 87 ec       	mov    -0x14(%r15,%rax,4),%ecx
 120e8ed:	48 31 d1             	xor    %rdx,%rcx
 120e8f0:	48 0f af ce          	imul   %rsi,%rcx
 120e8f4:	41 8b 54 87 f0       	mov    -0x10(%r15,%rax,4),%edx
 120e8f9:	48 31 ca             	xor    %rcx,%rdx
 120e8fc:	48 0f af d6          	imul   %rsi,%rdx
 120e900:	41 8b 4c 87 f4       	mov    -0xc(%r15,%rax,4),%ecx
 120e905:	48 31 d1             	xor    %rdx,%rcx
 120e908:	48 0f af ce          	imul   %rsi,%rcx
 120e90c:	41 8b 54 87 f8       	mov    -0x8(%r15,%rax,4),%edx
 120e911:	48 31 ca             	xor    %rcx,%rdx
 120e914:	48 0f af d6          	imul   %rsi,%rdx
 120e918:	41 8b 4c 87 fc       	mov    -0x4(%r15,%rax,4),%ecx
 120e91d:	48 31 d1             	xor    %rdx,%rcx
 120e920:	48 0f af ce          	imul   %rsi,%rcx
 120e924:	45 8b 34 87          	mov    (%r15,%rax,4),%r14d
 120e928:	49 31 ce             	xor    %rcx,%r14
 120e92b:	4c 0f af f6          	imul   %rsi,%r14
 120e92f:	48 83 c0 08          	add    $0x8,%rax
 120e933:	48 3d 00 01 00 00    	cmp    $0x100,%rax
 120e939:	75 95                	jne    120e8d0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1c50>
 120e93b:	44 89 f0             	mov    %r14d,%eax
 120e93e:	83 e0 7f             	and    $0x7f,%eax
 120e941:	4c 69 e0 10 04 00 00 	imul   $0x410,%rax,%r12
 120e948:	4e 89 b4 25 08 22 fb 	mov    %r14,-0x4ddf8(%rbp,%r12,1)
 120e94f:	ff 
 120e950:	49 8d 3c 2c          	lea    (%r12,%rbp,1),%rdi
 120e954:	48 81 c7 18 22 fb ff 	add    $0xfffffffffffb2218,%rdi
 120e95b:	ba 00 04 00 00       	mov    $0x400,%edx
 120e960:	4c 89 c6             	mov    %r8,%rsi
 120e963:	e8 f8 78 08 00       	call   1296260 <compiler_rt.memcpy.memcpyFast>
 120e968:	4a 89 9c 25 10 22 fb 	mov    %rbx,-0x4ddf0(%rbp,%r12,1)
 120e96f:	ff 
 120e970:	44 89 f0             	mov    %r14d,%eax
 120e973:	c1 e8 03             	shr    $0x3,%eax
 120e976:	83 e0 08             	and    $0x8,%eax
 120e979:	b9 01 00 00 00       	mov    $0x1,%ecx
 120e97e:	c4 e2 89 f7 c9       	shlx   %r14,%rcx,%rcx
 120e983:	48 09 8c 05 08 2a fd 	or     %rcx,-0x2d5f8(%rbp,%rax,1)
 120e98a:	ff 
 120e98b:	49 01 dd             	add    %rbx,%r13
 120e98e:	4c 89 eb             	mov    %r13,%rbx
 120e991:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 120e998:	48 ff c0             	inc    %rax
 120e99b:	49 81 c7 00 04 00 00 	add    $0x400,%r15
 120e9a2:	4c 8b ad 48 ff ff ff 	mov    -0xb8(%rbp),%r13
 120e9a9:	4c 39 e8             	cmp    %r13,%rax
 120e9ac:	4c 8b 65 10          	mov    0x10(%rbp),%r12
 120e9b0:	48 bf b3 01 00 00 00 	movabs $0x100000001b3,%rdi
 120e9b7:	01 00 00 
 120e9ba:	4c 8b b5 60 ff ff ff 	mov    -0xa0(%rbp),%r14
 120e9c1:	0f 85 89 fa ff ff    	jne    120e450 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x17d0>
 120e9c7:	eb 10                	jmp    120e9d9 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1d59>
 120e9c9:	49 89 dd             	mov    %rbx,%r13
 120e9cc:	48 ff 85 78 ff ff ff 	incq   -0x88(%rbp)
 120e9d3:	48 8b 58 08          	mov    0x8(%rax),%rbx
 120e9d7:	eb b2                	jmp    120e98b <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1d0b>
 120e9d9:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 120e9e0:	48 89 85 18 2a fd ff 	mov    %rax,-0x2d5e8(%rbp)
 120e9e7:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 120e9ee:	48 89 85 20 2a fd ff 	mov    %rax,-0x2d5e0(%rbp)
 120e9f5:	48 8d bd 38 ec ff ff 	lea    -0x13c8(%rbp),%rdi
 120e9fc:	48 8d 75 80          	lea    -0x80(%rbp),%rsi
 120ea00:	4c 89 ea             	mov    %r13,%rdx
 120ea03:	c5 f8 77             	vzeroupper 
 120ea06:	e8 55 64 f7 ff       	call   1184e60 <br.encoder.context_map.choose>
 120ea0b:	0f b7 85 08 ef ff ff 	movzwl -0x10f8(%rbp),%eax
 120ea12:	66 85 c0             	test   %ax,%ax
 120ea15:	0f 85 cc 02 00 00    	jne    120ece7 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x2067>
 120ea1b:	48 03 9d e0 ec ff ff 	add    -0x1320(%rbp),%rbx
 120ea22:	48 8b 95 50 ff ff ff 	mov    -0xb0(%rbp),%rdx
 120ea29:	48 6b c2 58          	imul   $0x58,%rdx,%rax
 120ea2d:	48 8b 8d f8 fe ff ff 	mov    -0x108(%rbp),%rcx
 120ea34:	48 89 8c 05 10 ef ff 	mov    %rcx,-0x10f0(%rbp,%rax,1)
 120ea3b:	ff 
 120ea3c:	44 89 e9             	mov    %r13d,%ecx
 120ea3f:	80 e1 7f             	and    $0x7f,%cl
 120ea42:	88 8c 05 20 ef ff ff 	mov    %cl,-0x10e0(%rbp,%rax,1)
 120ea49:	c5 fc 10 45 80       	vmovups -0x80(%rbp),%ymm0
 120ea4e:	c5 fc 11 84 05 21 ef 	vmovups %ymm0,-0x10df(%rbp,%rax,1)
 120ea55:	ff ff 
 120ea57:	c5 fe 6f 45 a0       	vmovdqu -0x60(%rbp),%ymm0
 120ea5c:	c5 fe 7f 84 05 41 ef 	vmovdqu %ymm0,-0x10bf(%rbp,%rax,1)
 120ea63:	ff ff 
 120ea65:	48 89 9c 05 18 ef ff 	mov    %rbx,-0x10e8(%rbp,%rax,1)
 120ea6c:	ff 
 120ea6d:	48 ff c2             	inc    %rdx
 120ea70:	48 89 95 a0 f6 ff ff 	mov    %rdx,-0x960(%rbp)
 120ea77:	48 8b 8d f0 fe ff ff 	mov    -0x110(%rbp),%rcx
 120ea7e:	48 29 d9             	sub    %rbx,%rcx
 120ea81:	b8 00 00 00 00       	mov    $0x0,%eax
 120ea86:	48 0f 43 c1          	cmovae %rcx,%rax
 120ea8a:	48 3d 80 00 00 00    	cmp    $0x80,%rax
 120ea90:	0f 82 3a e8 ff ff    	jb     120d2d0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x650>
 120ea96:	8b 8d 3c ff ff ff    	mov    -0xc4(%rbp),%ecx
 120ea9c:	80 e1 03             	and    $0x3,%cl
 120ea9f:	88 4d c8             	mov    %cl,-0x38(%rbp)
 120eaa2:	41 80 e5 7f          	and    $0x7f,%r13b
 120eaa6:	c5 fe 6f 45 80       	vmovdqu -0x80(%rbp),%ymm0
 120eaab:	c5 fe 6f 4d a0       	vmovdqu -0x60(%rbp),%ymm1
 120eab0:	c5 fe 7f 85 e0 fc ff 	vmovdqu %ymm0,-0x320(%rbp)
 120eab7:	ff 
 120eab8:	c5 fe 7f 8d 00 fd ff 	vmovdqu %ymm1,-0x300(%rbp)
 120eabf:	ff 
 120eac0:	c5 fe 7f 85 40 fc ff 	vmovdqu %ymm0,-0x3c0(%rbp)
 120eac7:	ff 
 120eac8:	c5 fe 7f 8d 60 fc ff 	vmovdqu %ymm1,-0x3a0(%rbp)
 120eacf:	ff 
 120ead0:	44 88 6d c6          	mov    %r13b,-0x3a(%rbp)
 120ead4:	0f b7 95 6c ff ff ff 	movzwl -0x94(%rbp),%edx
 120eadb:	48 8d b5 80 fc ff ff 	lea    -0x380(%rbp),%rsi
 120eae2:	66 89 56 04          	mov    %dx,0x4(%rsi)
 120eae6:	8b 95 68 ff ff ff    	mov    -0x98(%rbp),%edx
 120eaec:	89 16                	mov    %edx,(%rsi)
 120eaee:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 120eaf2:	74 17                	je     120eb0b <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1e8b>
 120eaf4:	48 3b 85 00 ff ff ff 	cmp    -0x100(%rbp),%rax
 120eafb:	77 0e                	ja     120eb0b <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1e8b>
 120eafd:	75 4c                	jne    120eb4b <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1ecb>
 120eaff:	0f b6 55 d5          	movzbl -0x2b(%rbp),%edx
 120eb03:	80 e2 7f             	and    $0x7f,%dl
 120eb06:	41 38 d5             	cmp    %dl,%r13b
 120eb09:	73 40                	jae    120eb4b <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1ecb>
 120eb0b:	48 8b 95 7e fc ff ff 	mov    -0x382(%rbp),%rdx
 120eb12:	48 89 95 fe fd ff ff 	mov    %rdx,-0x202(%rbp)
 120eb19:	c5 fe 6f 85 40 fc ff 	vmovdqu -0x3c0(%rbp),%ymm0
 120eb20:	ff 
 120eb21:	c5 fe 6f 8d 60 fc ff 	vmovdqu -0x3a0(%rbp),%ymm1
 120eb28:	ff 
 120eb29:	c5 fe 7f 8d e0 fd ff 	vmovdqu %ymm1,-0x220(%rbp)
 120eb30:	ff 
 120eb31:	c5 fe 7f 85 c0 fd ff 	vmovdqu %ymm0,-0x240(%rbp)
 120eb38:	ff 
 120eb39:	c6 45 d4 01          	movb   $0x1,-0x2c(%rbp)
 120eb3d:	44 88 6d d5          	mov    %r13b,-0x2b(%rbp)
 120eb41:	88 4d d2             	mov    %cl,-0x2e(%rbp)
 120eb44:	48 89 85 00 ff ff ff 	mov    %rax,-0x100(%rbp)
 120eb4b:	49 83 fe 10          	cmp    $0x10,%r14
 120eb4f:	8b bd 38 ff ff ff    	mov    -0xc8(%rbp),%edi
 120eb55:	0f 87 aa e7 ff ff    	ja     120d305 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x685>
 120eb5b:	c5 fe 6f 85 e0 fc ff 	vmovdqu -0x320(%rbp),%ymm0
 120eb62:	ff 
 120eb63:	c5 fe 6f 8d 00 fd ff 	vmovdqu -0x300(%rbp),%ymm1
 120eb6a:	ff 
 120eb6b:	c5 fe 7f 8d 10 fc ff 	vmovdqu %ymm1,-0x3f0(%rbp)
 120eb72:	ff 
 120eb73:	c5 fe 7f 85 f0 fb ff 	vmovdqu %ymm0,-0x410(%rbp)
 120eb7a:	ff 
 120eb7b:	0f b7 95 6c ff ff ff 	movzwl -0x94(%rbp),%edx
 120eb82:	48 8d b5 30 fc ff ff 	lea    -0x3d0(%rbp),%rsi
 120eb89:	66 89 56 04          	mov    %dx,0x4(%rsi)
 120eb8d:	8b 95 68 ff ff ff    	mov    -0x98(%rbp),%edx
 120eb93:	89 16                	mov    %edx,(%rsi)
 120eb95:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 120eb99:	74 1f                	je     120ebba <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1f3a>
 120eb9b:	48 3b 85 08 ff ff ff 	cmp    -0xf8(%rbp),%rax
 120eba2:	77 16                	ja     120ebba <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1f3a>
 120eba4:	0f 85 5b e7 ff ff    	jne    120d305 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x685>
 120ebaa:	0f b6 55 d7          	movzbl -0x29(%rbp),%edx
 120ebae:	80 e2 7f             	and    $0x7f,%dl
 120ebb1:	41 38 d5             	cmp    %dl,%r13b
 120ebb4:	0f 83 4b e7 ff ff    	jae    120d305 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x685>
 120ebba:	48 8b 95 2e fc ff ff 	mov    -0x3d2(%rbp),%rdx
 120ebc1:	48 89 95 ae fd ff ff 	mov    %rdx,-0x252(%rbp)
 120ebc8:	c5 fe 6f 85 f0 fb ff 	vmovdqu -0x410(%rbp),%ymm0
 120ebcf:	ff 
 120ebd0:	c5 fe 6f 8d 10 fc ff 	vmovdqu -0x3f0(%rbp),%ymm1
 120ebd7:	ff 
 120ebd8:	c5 fe 7f 8d 90 fd ff 	vmovdqu %ymm1,-0x270(%rbp)
 120ebdf:	ff 
 120ebe0:	c5 fe 7f 85 70 fd ff 	vmovdqu %ymm0,-0x290(%rbp)
 120ebe7:	ff 
 120ebe8:	c6 45 d6 01          	movb   $0x1,-0x2a(%rbp)
 120ebec:	44 88 6d d7          	mov    %r13b,-0x29(%rbp)
 120ebf0:	88 4d d3             	mov    %cl,-0x2d(%rbp)
 120ebf3:	48 89 85 08 ff ff ff 	mov    %rax,-0xf8(%rbp)
 120ebfa:	e9 06 e7 ff ff       	jmp    120d305 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x685>
 120ebff:	4c 89 d7             	mov    %r10,%rdi
 120ec02:	48 83 e7 fc          	and    $0xfffffffffffffffc,%rdi
 120ec06:	31 c9                	xor    %ecx,%ecx
 120ec08:	31 f6                	xor    %esi,%esi
 120ec0a:	eb 22                	jmp    120ec2e <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1fae>
 120ec0c:	0f 1f 40 00          	nopl   0x0(%rax)
 120ec10:	31 d2                	xor    %edx,%edx
 120ec12:	49 f7 f2             	div    %r10
 120ec15:	42 88 44 05 80       	mov    %al,-0x80(%rbp,%r8,1)
 120ec1a:	48 83 c6 04          	add    $0x4,%rsi
 120ec1e:	48 03 8d e8 fe ff ff 	add    -0x118(%rbp),%rcx
 120ec25:	48 39 f7             	cmp    %rsi,%rdi
 120ec28:	0f 84 c5 e7 ff ff    	je     120d3f3 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x773>
 120ec2e:	44 0f b6 84 35 60 fe 	movzbl -0x1a0(%rbp,%rsi,1),%r8d
 120ec35:	ff ff 
 120ec37:	48 89 c8             	mov    %rcx,%rax
 120ec3a:	4c 09 d0             	or     %r10,%rax
 120ec3d:	48 c1 e8 20          	shr    $0x20,%rax
 120ec41:	74 0d                	je     120ec50 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1fd0>
 120ec43:	48 89 c8             	mov    %rcx,%rax
 120ec46:	31 d2                	xor    %edx,%edx
 120ec48:	49 f7 f2             	div    %r10
 120ec4b:	eb 0a                	jmp    120ec57 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1fd7>
 120ec4d:	0f 1f 00             	nopl   (%rax)
 120ec50:	89 c8                	mov    %ecx,%eax
 120ec52:	31 d2                	xor    %edx,%edx
 120ec54:	41 f7 f2             	div    %r10d
 120ec57:	42 88 44 05 80       	mov    %al,-0x80(%rbp,%r8,1)
 120ec5c:	44 0f b6 84 35 61 fe 	movzbl -0x19f(%rbp,%rsi,1),%r8d
 120ec63:	ff ff 
 120ec65:	49 8d 04 0e          	lea    (%r14,%rcx,1),%rax
 120ec69:	48 89 c2             	mov    %rax,%rdx
 120ec6c:	4c 09 d2             	or     %r10,%rdx
 120ec6f:	48 c1 ea 20          	shr    $0x20,%rdx
 120ec73:	74 0b                	je     120ec80 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x2000>
 120ec75:	31 d2                	xor    %edx,%edx
 120ec77:	49 f7 f2             	div    %r10
 120ec7a:	eb 09                	jmp    120ec85 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x2005>
 120ec7c:	0f 1f 40 00          	nopl   0x0(%rax)
 120ec80:	31 d2                	xor    %edx,%edx
 120ec82:	41 f7 f2             	div    %r10d
 120ec85:	42 88 44 05 80       	mov    %al,-0x80(%rbp,%r8,1)
 120ec8a:	44 0f b6 84 35 62 fe 	movzbl -0x19e(%rbp,%rsi,1),%r8d
 120ec91:	ff ff 
 120ec93:	48 8b 85 c8 fe ff ff 	mov    -0x138(%rbp),%rax
 120ec9a:	48 01 c8             	add    %rcx,%rax
 120ec9d:	48 89 c2             	mov    %rax,%rdx
 120eca0:	4c 09 d2             	or     %r10,%rdx
 120eca3:	48 c1 ea 20          	shr    $0x20,%rdx
 120eca7:	74 07                	je     120ecb0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x2030>
 120eca9:	31 d2                	xor    %edx,%edx
 120ecab:	49 f7 f2             	div    %r10
 120ecae:	eb 05                	jmp    120ecb5 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x2035>
 120ecb0:	31 d2                	xor    %edx,%edx
 120ecb2:	41 f7 f2             	div    %r10d
 120ecb5:	42 88 44 05 80       	mov    %al,-0x80(%rbp,%r8,1)
 120ecba:	44 0f b6 84 35 63 fe 	movzbl -0x19d(%rbp,%rsi,1),%r8d
 120ecc1:	ff ff 
 120ecc3:	48 8b 85 c0 fe ff ff 	mov    -0x140(%rbp),%rax
 120ecca:	48 01 c8             	add    %rcx,%rax
 120eccd:	48 89 c2             	mov    %rax,%rdx
 120ecd0:	4c 09 d2             	or     %r10,%rdx
 120ecd3:	48 c1 ea 20          	shr    $0x20,%rdx
 120ecd7:	0f 85 33 ff ff ff    	jne    120ec10 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1f90>
 120ecdd:	31 d2                	xor    %edx,%edx
 120ecdf:	41 f7 f2             	div    %r10d
 120ece2:	e9 2e ff ff ff       	jmp    120ec15 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x1f95>
 120ece7:	48 8b 8d 28 ff ff ff 	mov    -0xd8(%rbp),%rcx
 120ecee:	66 89 81 08 01 00 00 	mov    %ax,0x108(%rcx)
 120ecf5:	e9 3b 01 00 00       	jmp    120ee35 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191+0x21b5>
 120ecfa:	48 8b 8d 28 ff ff ff 	mov    -0xd8(%rbp),%rcx
 120ed01:	66 c7 81 08 01 00 00 	movw   $0x0,0x108(%rcx)
 120ed08:	00 00 
 120ed0a:	48 8b 85 10 ff ff ff 	mov    -0xf0(%rbp),%rax
 120ed11:	48 89 01             	mov    %rax,(%rcx)
 120ed14:	48 8b 85 20 ff ff ff 	mov    -0xe0(%rbp),%rax
 120ed1b:	88 41 08             	mov    %al,0x8(%rcx)
 120ed1e:	48 8b 85 18 ff ff ff 	mov    -0xe8(%rbp),%rax
 120ed25:	88 41 09             	mov    %al,0x9(%rcx)
 120ed28:	c5 fc 10 85 90 fc ff 	vmovups -0x370(%rbp),%ymm0
 120ed2f:	ff 
 120ed30:	c5 fc 11 41 0a       	vmovups %ymm0,0xa(%rcx)
 120ed35:	c5 fc 10 85 b0 fc ff 	vmovups -0x350(%rbp),%ymm0
 120ed3c:	ff 
 120ed3d:	c5 fc 11 41 2a       	vmovups %ymm0,0x2a(%rcx)
 120ed42:	48 8b 85 ce fc ff ff 	mov    -0x332(%rbp),%rax
 120ed49:	48 89 41 48          	mov    %rax,0x48(%rcx)
 120ed4d:	48 8b 85 58 ff ff ff 	mov    -0xa8(%rbp),%rax
 120ed54:	88 41 50             	mov    %al,0x50(%rcx)
 120ed57:	c7 41 51 00 00 00 00 	movl   $0x0,0x51(%rcx)
 120ed5e:	c7 41 54 00 00 00 00 	movl   $0x0,0x54(%rcx)
 120ed65:	48 8b 85 08 ff ff ff 	mov    -0xf8(%rbp),%rax
 120ed6c:	48 89 41 58          	mov    %rax,0x58(%rcx)
 120ed70:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 120ed74:	88 41 60             	mov    %al,0x60(%rcx)
 120ed77:	0f b6 45 d7          	movzbl -0x29(%rbp),%eax
 120ed7b:	88 41 61             	mov    %al,0x61(%rcx)
 120ed7e:	c5 fc 10 85 70 fd ff 	vmovups -0x290(%rbp),%ymm0
 120ed85:	ff 
 120ed86:	c5 fe 6f 8d 90 fd ff 	vmovdqu -0x270(%rbp),%ymm1
 120ed8d:	ff 
 120ed8e:	c5 fc 11 41 62       	vmovups %ymm0,0x62(%rcx)
 120ed93:	c5 fe 7f 89 82 00 00 	vmovdqu %ymm1,0x82(%rcx)
 120ed9a:	00 
 120ed9b:	48 8b 85 ae fd ff ff 	mov    -0x252(%rbp),%rax
 120eda2:	48 89 81 a0 00 00 00 	mov    %rax,0xa0(%rcx)
 120eda9:	0f b6 45 d6          	movzbl -0x2a(%rbp),%eax
 120edad:	88 81 a8 00 00 00    	mov    %al,0xa8(%rcx)
 120edb3:	c7 81 ac 00 00 00 00 	movl   $0x0,0xac(%rcx)
 120edba:	00 00 00 
 120edbd:	c7 81 a9 00 00 00 00 	movl   $0x0,0xa9(%rcx)
 120edc4:	00 00 00 
 120edc7:	48 8b 85 00 ff ff ff 	mov    -0x100(%rbp),%rax
 120edce:	48 89 81 b0 00 00 00 	mov    %rax,0xb0(%rcx)
 120edd5:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 120edd9:	88 81 b8 00 00 00    	mov    %al,0xb8(%rcx)
 120eddf:	0f b6 45 d5          	movzbl -0x2b(%rbp),%eax
 120ede3:	88 81 b9 00 00 00    	mov    %al,0xb9(%rcx)
 120ede9:	48 8b 85 fe fd ff ff 	mov    -0x202(%rbp),%rax
 120edf0:	48 89 81 f8 00 00 00 	mov    %rax,0xf8(%rcx)
 120edf7:	c5 fc 10 85 e0 fd ff 	vmovups -0x220(%rbp),%ymm0
 120edfe:	ff 
 120edff:	c5 fc 11 81 da 00 00 	vmovups %ymm0,0xda(%rcx)
 120ee06:	00 
 120ee07:	c5 fe 6f 85 c0 fd ff 	vmovdqu -0x240(%rbp),%ymm0
 120ee0e:	ff 
 120ee0f:	c5 fe 7f 81 ba 00 00 	vmovdqu %ymm0,0xba(%rcx)
 120ee16:	00 
 120ee17:	0f b6 45 d4          	movzbl -0x2c(%rbp),%eax
 120ee1b:	88 81 00 01 00 00    	mov    %al,0x100(%rcx)
 120ee21:	c7 81 04 01 00 00 00 	movl   $0x0,0x104(%rcx)
 120ee28:	00 00 00 
 120ee2b:	c7 81 01 01 00 00 00 	movl   $0x0,0x101(%rcx)
 120ee32:	00 00 00 
 120ee35:	48 81 c4 d8 dd 04 00 	add    $0x4ddd8,%rsp
 120ee3c:	5b                   	pop    %rbx
 120ee3d:	41 5c                	pop    %r12
 120ee3f:	41 5d                	pop    %r13
 120ee41:	41 5e                	pop    %r14
 120ee43:	41 5f                	pop    %r15
 120ee45:	5d                   	pop    %rbp
 120ee46:	c5 f8 77             	vzeroupper 
 120ee49:	c3                   	ret    

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
