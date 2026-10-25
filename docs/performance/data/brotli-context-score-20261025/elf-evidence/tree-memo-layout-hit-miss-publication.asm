 120c71b:	89 f0                	mov    %esi,%eax
 120c71d:	c1 e8 03             	shr    $0x3,%eax
 120c720:	83 e0 08             	and    $0x8,%eax
 120c723:	48 8b 84 01 00 08 02 	mov    0x20800(%rcx,%rax,1),%rax
 120c72a:	00 
 120c72b:	48 0f a3 f0          	bt     %rsi,%rax
 120c72f:	0f 83 5c 03 00 00    	jae    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c735:	89 f0                	mov    %esi,%eax
 120c737:	83 e0 7f             	and    $0x7f,%eax
 120c73a:	48 69 c0 10 04 00 00 	imul   $0x410,%rax,%rax
 120c741:	48 39 34 01          	cmp    %rsi,(%rcx,%rax,1)
 120c745:	0f 85 46 03 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c74b:	48 01 c8             	add    %rcx,%rax
 120c74e:	48 8d 70 10          	lea    0x10(%rax),%rsi
 120c752:	4c 39 f6             	cmp    %r14,%rsi
 120c755:	0f 84 39 0a 00 00    	je     120d194 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0xb24>

 120ca75:	c5 fe 6f 80 d0 03 00 	vmovdqu 0x3d0(%rax),%ymm0
 120ca7c:	00 
 120ca7d:	c4 c1 7d ef 86 c0 03 	vpxor  0x3c0(%r14),%ymm0,%ymm0
 120ca84:	00 00 
 120ca86:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120ca8b:	0f 84 e7 06 00 00    	je     120d178 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0xb08>
 120ca91:	48 ff 81 18 08 02 00 	incq   0x20818(%rcx)
 120ca98:	48 c7 85 00 f9 ff ff 	movq   $0x0,-0x700(%rbp)
 120ca9f:	00 00 00 00 
 120caa3:	0f b7 32             	movzwl (%rdx),%esi
 120caa6:	66 b8 1f 00          	mov    $0x1f,%ax
 120caaa:	48 85 f6             	test   %rsi,%rsi

 120cd9b:	4c 01 eb             	add    %r13,%rbx
 120cd9e:	44 89 e0             	mov    %r12d,%eax
 120cda1:	83 e0 7f             	and    $0x7f,%eax
 120cda4:	4c 69 f8 10 04 00 00 	imul   $0x410,%rax,%r15
 120cdab:	4e 89 24 39          	mov    %r12,(%rcx,%r15,1)
 120cdaf:	4a 8d 3c 39          	lea    (%rcx,%r15,1),%rdi
 120cdb3:	48 83 c7 10          	add    $0x10,%rdi
 120cdb7:	ba 00 04 00 00       	mov    $0x400,%edx
 120cdbc:	4c 89 f6             	mov    %r14,%rsi
 120cdbf:	49 89 ce             	mov    %rcx,%r14
 120cdc2:	c5 f8 77             	vzeroupper 
 120cdc5:	e8 c6 90 08 00       	call   1295e90 <compiler_rt.memmove.memmoveFast>
 120cdca:	4b 89 5c 3e 08       	mov    %rbx,0x8(%r14,%r15,1)
 120cdcf:	44 89 e0             	mov    %r12d,%eax
 120cdd2:	c1 e8 03             	shr    $0x3,%eax
 120cdd5:	83 e0 08             	and    $0x8,%eax
 120cdd8:	b9 01 00 00 00       	mov    $0x1,%ecx
 120cddd:	c4 e2 99 f7 c9       	shlx   %r12,%rcx,%rcx
 120cde2:	49 09 8c 06 00 08 02 	or     %rcx,0x20800(%r14,%rax,1)
 120cde9:	00 
 120cdea:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 120cdee:	66 c7 40 08 00 00    	movw   $0x0,0x8(%rax)
 120cdf4:	48 89 18             	mov    %rbx,(%rax)
 120cdf7:	e9 67 03 00 00       	jmp    120d163 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0xaf3>
 120cdfc:	48 c7 45 80 02 00 00 	movq   $0x2,-0x80(%rbp)
 120ce03:	00 
 120ce04:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0

 120d178:	c5 fe 6f 80 f0 03 00 	vmovdqu 0x3f0(%rax),%ymm0
 120d17f:	00 
 120d180:	c4 c1 7d ef 86 e0 03 	vpxor  0x3e0(%r14),%ymm0,%ymm0
 120d187:	00 00 
 120d189:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120d18e:	0f 85 fd f8 ff ff    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120d194:	48 ff 81 10 08 02 00 	incq   0x20810(%rcx)
 120d19b:	48 8b 40 08          	mov    0x8(%rax),%rax
 120d19f:	66 41 c7 43 08 00 00 	movw   $0x0,0x8(%r11)
 120d1a6:	49 89 03             	mov    %rax,(%r11)
 120d1a9:	eb b8                	jmp    120d163 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0xaf3>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
