
/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/78f0aed58c7f51384364cb890565eb73/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000120c670 <br.encoder.literal_context_split.treeBitCostCached__anon_46145>:
 120c670:	55                   	push   %rbp
 120c671:	48 89 e5             	mov    %rsp,%rbp
 120c674:	41 57                	push   %r15
 120c676:	41 56                	push   %r14
 120c678:	41 55                	push   %r13
 120c67a:	41 54                	push   %r12
 120c67c:	53                   	push   %rbx
 120c67d:	48 81 ec d8 06 00 00 	sub    $0x6d8,%rsp
 120c684:	49 89 f6             	mov    %rsi,%r14
 120c687:	49 89 fb             	mov    %rdi,%r11
 120c68a:	49 bc 25 23 22 84 e4 	movabs $0xcbf29ce484222325,%r12
 120c691:	9c f2 cb 
 120c694:	49 bf b3 01 00 00 00 	movabs $0x100000001b3,%r15
 120c69b:	01 00 00 
 120c69e:	b8 07 00 00 00       	mov    $0x7,%eax
 120c6a3:	4c 89 e6             	mov    %r12,%rsi
 120c6a6:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 120c6ad:	00 00 00 
 120c6b0:	41 8b 7c 86 e4       	mov    -0x1c(%r14,%rax,4),%edi
 120c6b5:	45 8b 44 86 e8       	mov    -0x18(%r14,%rax,4),%r8d
 120c6ba:	48 31 f7             	xor    %rsi,%rdi
 120c6bd:	49 0f af ff          	imul   %r15,%rdi
 120c6c1:	49 31 f8             	xor    %rdi,%r8
 120c6c4:	4d 0f af c7          	imul   %r15,%r8
 120c6c8:	41 8b 74 86 ec       	mov    -0x14(%r14,%rax,4),%esi
 120c6cd:	4c 31 c6             	xor    %r8,%rsi
 120c6d0:	49 0f af f7          	imul   %r15,%rsi
 120c6d4:	41 8b 7c 86 f0       	mov    -0x10(%r14,%rax,4),%edi
 120c6d9:	48 31 f7             	xor    %rsi,%rdi
 120c6dc:	49 0f af ff          	imul   %r15,%rdi
 120c6e0:	41 8b 74 86 f4       	mov    -0xc(%r14,%rax,4),%esi
 120c6e5:	48 31 fe             	xor    %rdi,%rsi
 120c6e8:	49 0f af f7          	imul   %r15,%rsi
 120c6ec:	41 8b 7c 86 f8       	mov    -0x8(%r14,%rax,4),%edi
 120c6f1:	48 31 f7             	xor    %rsi,%rdi
 120c6f4:	49 0f af ff          	imul   %r15,%rdi
 120c6f8:	45 8b 44 86 fc       	mov    -0x4(%r14,%rax,4),%r8d
 120c6fd:	49 31 f8             	xor    %rdi,%r8
 120c700:	4d 0f af c7          	imul   %r15,%r8
 120c704:	41 8b 34 86          	mov    (%r14,%rax,4),%esi
 120c708:	4c 31 c6             	xor    %r8,%rsi
 120c70b:	49 0f af f7          	imul   %r15,%rsi
 120c70f:	48 83 c0 08          	add    $0x8,%rax
 120c713:	48 3d 07 01 00 00    	cmp    $0x107,%rax
 120c719:	75 95                	jne    120c6b0 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x40>
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
 120c75b:	c5 fe 6f 06          	vmovdqu (%rsi),%ymm0
 120c75f:	c4 c1 7d ef 06       	vpxor  (%r14),%ymm0,%ymm0
 120c764:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120c769:	0f 85 22 03 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c76f:	c5 fe 6f 40 30       	vmovdqu 0x30(%rax),%ymm0
 120c774:	c4 c1 7d ef 46 20    	vpxor  0x20(%r14),%ymm0,%ymm0
 120c77a:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120c77f:	0f 85 0c 03 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c785:	c5 fe 6f 40 50       	vmovdqu 0x50(%rax),%ymm0
 120c78a:	c4 c1 7d ef 46 40    	vpxor  0x40(%r14),%ymm0,%ymm0
 120c790:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120c795:	0f 85 f6 02 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c79b:	c5 fe 6f 40 70       	vmovdqu 0x70(%rax),%ymm0
 120c7a0:	c4 c1 7d ef 46 60    	vpxor  0x60(%r14),%ymm0,%ymm0
 120c7a6:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120c7ab:	0f 85 e0 02 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c7b1:	c5 fe 6f 80 90 00 00 	vmovdqu 0x90(%rax),%ymm0
 120c7b8:	00 
 120c7b9:	c4 c1 7d ef 86 80 00 	vpxor  0x80(%r14),%ymm0,%ymm0
 120c7c0:	00 00 
 120c7c2:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120c7c7:	0f 85 c4 02 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c7cd:	c5 fe 6f 80 b0 00 00 	vmovdqu 0xb0(%rax),%ymm0
 120c7d4:	00 
 120c7d5:	c4 c1 7d ef 86 a0 00 	vpxor  0xa0(%r14),%ymm0,%ymm0
 120c7dc:	00 00 
 120c7de:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120c7e3:	0f 85 a8 02 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c7e9:	c5 fe 6f 80 d0 00 00 	vmovdqu 0xd0(%rax),%ymm0
 120c7f0:	00 
 120c7f1:	c4 c1 7d ef 86 c0 00 	vpxor  0xc0(%r14),%ymm0,%ymm0
 120c7f8:	00 00 
 120c7fa:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120c7ff:	0f 85 8c 02 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c805:	c5 fe 6f 80 f0 00 00 	vmovdqu 0xf0(%rax),%ymm0
 120c80c:	00 
 120c80d:	c4 c1 7d ef 86 e0 00 	vpxor  0xe0(%r14),%ymm0,%ymm0
 120c814:	00 00 
 120c816:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120c81b:	0f 85 70 02 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c821:	c5 fe 6f 80 10 01 00 	vmovdqu 0x110(%rax),%ymm0
 120c828:	00 
 120c829:	c4 c1 7d ef 86 00 01 	vpxor  0x100(%r14),%ymm0,%ymm0
 120c830:	00 00 
 120c832:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120c837:	0f 85 54 02 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c83d:	c5 fe 6f 80 30 01 00 	vmovdqu 0x130(%rax),%ymm0
 120c844:	00 
 120c845:	c4 c1 7d ef 86 20 01 	vpxor  0x120(%r14),%ymm0,%ymm0
 120c84c:	00 00 
 120c84e:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120c853:	0f 85 38 02 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c859:	c5 fe 6f 80 50 01 00 	vmovdqu 0x150(%rax),%ymm0
 120c860:	00 
 120c861:	c4 c1 7d ef 86 40 01 	vpxor  0x140(%r14),%ymm0,%ymm0
 120c868:	00 00 
 120c86a:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120c86f:	0f 85 1c 02 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c875:	c5 fe 6f 80 70 01 00 	vmovdqu 0x170(%rax),%ymm0
 120c87c:	00 
 120c87d:	c4 c1 7d ef 86 60 01 	vpxor  0x160(%r14),%ymm0,%ymm0
 120c884:	00 00 
 120c886:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120c88b:	0f 85 00 02 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c891:	c5 fe 6f 80 90 01 00 	vmovdqu 0x190(%rax),%ymm0
 120c898:	00 
 120c899:	c4 c1 7d ef 86 80 01 	vpxor  0x180(%r14),%ymm0,%ymm0
 120c8a0:	00 00 
 120c8a2:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120c8a7:	0f 85 e4 01 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c8ad:	c5 fe 6f 80 b0 01 00 	vmovdqu 0x1b0(%rax),%ymm0
 120c8b4:	00 
 120c8b5:	c4 c1 7d ef 86 a0 01 	vpxor  0x1a0(%r14),%ymm0,%ymm0
 120c8bc:	00 00 
 120c8be:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120c8c3:	0f 85 c8 01 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c8c9:	c5 fe 6f 80 d0 01 00 	vmovdqu 0x1d0(%rax),%ymm0
 120c8d0:	00 
 120c8d1:	c4 c1 7d ef 86 c0 01 	vpxor  0x1c0(%r14),%ymm0,%ymm0
 120c8d8:	00 00 
 120c8da:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120c8df:	0f 85 ac 01 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c8e5:	c5 fe 6f 80 f0 01 00 	vmovdqu 0x1f0(%rax),%ymm0
 120c8ec:	00 
 120c8ed:	c4 c1 7d ef 86 e0 01 	vpxor  0x1e0(%r14),%ymm0,%ymm0
 120c8f4:	00 00 
 120c8f6:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120c8fb:	0f 85 90 01 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c901:	c5 fe 6f 80 10 02 00 	vmovdqu 0x210(%rax),%ymm0
 120c908:	00 
 120c909:	c4 c1 7d ef 86 00 02 	vpxor  0x200(%r14),%ymm0,%ymm0
 120c910:	00 00 
 120c912:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120c917:	0f 85 74 01 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c91d:	c5 fe 6f 80 30 02 00 	vmovdqu 0x230(%rax),%ymm0
 120c924:	00 
 120c925:	c4 c1 7d ef 86 20 02 	vpxor  0x220(%r14),%ymm0,%ymm0
 120c92c:	00 00 
 120c92e:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120c933:	0f 85 58 01 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c939:	c5 fe 6f 80 50 02 00 	vmovdqu 0x250(%rax),%ymm0
 120c940:	00 
 120c941:	c4 c1 7d ef 86 40 02 	vpxor  0x240(%r14),%ymm0,%ymm0
 120c948:	00 00 
 120c94a:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120c94f:	0f 85 3c 01 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c955:	c5 fe 6f 80 70 02 00 	vmovdqu 0x270(%rax),%ymm0
 120c95c:	00 
 120c95d:	c4 c1 7d ef 86 60 02 	vpxor  0x260(%r14),%ymm0,%ymm0
 120c964:	00 00 
 120c966:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120c96b:	0f 85 20 01 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c971:	c5 fe 6f 80 90 02 00 	vmovdqu 0x290(%rax),%ymm0
 120c978:	00 
 120c979:	c4 c1 7d ef 86 80 02 	vpxor  0x280(%r14),%ymm0,%ymm0
 120c980:	00 00 
 120c982:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120c987:	0f 85 04 01 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c98d:	c5 fe 6f 80 b0 02 00 	vmovdqu 0x2b0(%rax),%ymm0
 120c994:	00 
 120c995:	c4 c1 7d ef 86 a0 02 	vpxor  0x2a0(%r14),%ymm0,%ymm0
 120c99c:	00 00 
 120c99e:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120c9a3:	0f 85 e8 00 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c9a9:	c5 fe 6f 80 d0 02 00 	vmovdqu 0x2d0(%rax),%ymm0
 120c9b0:	00 
 120c9b1:	c4 c1 7d ef 86 c0 02 	vpxor  0x2c0(%r14),%ymm0,%ymm0
 120c9b8:	00 00 
 120c9ba:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120c9bf:	0f 85 cc 00 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c9c5:	c5 fe 6f 80 f0 02 00 	vmovdqu 0x2f0(%rax),%ymm0
 120c9cc:	00 
 120c9cd:	c4 c1 7d ef 86 e0 02 	vpxor  0x2e0(%r14),%ymm0,%ymm0
 120c9d4:	00 00 
 120c9d6:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120c9db:	0f 85 b0 00 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c9e1:	c5 fe 6f 80 10 03 00 	vmovdqu 0x310(%rax),%ymm0
 120c9e8:	00 
 120c9e9:	c4 c1 7d ef 86 00 03 	vpxor  0x300(%r14),%ymm0,%ymm0
 120c9f0:	00 00 
 120c9f2:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120c9f7:	0f 85 94 00 00 00    	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120c9fd:	c5 fe 6f 80 30 03 00 	vmovdqu 0x330(%rax),%ymm0
 120ca04:	00 
 120ca05:	c4 c1 7d ef 86 20 03 	vpxor  0x320(%r14),%ymm0,%ymm0
 120ca0c:	00 00 
 120ca0e:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120ca13:	75 7c                	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120ca15:	c5 fe 6f 80 50 03 00 	vmovdqu 0x350(%rax),%ymm0
 120ca1c:	00 
 120ca1d:	c4 c1 7d ef 86 40 03 	vpxor  0x340(%r14),%ymm0,%ymm0
 120ca24:	00 00 
 120ca26:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120ca2b:	75 64                	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120ca2d:	c5 fe 6f 80 70 03 00 	vmovdqu 0x370(%rax),%ymm0
 120ca34:	00 
 120ca35:	c4 c1 7d ef 86 60 03 	vpxor  0x360(%r14),%ymm0,%ymm0
 120ca3c:	00 00 
 120ca3e:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120ca43:	75 4c                	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120ca45:	c5 fe 6f 80 90 03 00 	vmovdqu 0x390(%rax),%ymm0
 120ca4c:	00 
 120ca4d:	c4 c1 7d ef 86 80 03 	vpxor  0x380(%r14),%ymm0,%ymm0
 120ca54:	00 00 
 120ca56:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120ca5b:	75 34                	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
 120ca5d:	c5 fe 6f 80 b0 03 00 	vmovdqu 0x3b0(%rax),%ymm0
 120ca64:	00 
 120ca65:	c4 c1 7d ef 86 a0 03 	vpxor  0x3a0(%r14),%ymm0,%ymm0
 120ca6c:	00 00 
 120ca6e:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 120ca73:	75 1c                	jne    120ca91 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x421>
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
 120caad:	0f 84 ab 06 00 00    	je     120d15e <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0xaee>
 120cab3:	31 db                	xor    %ebx,%ebx
 120cab5:	45 31 ed             	xor    %r13d,%r13d
 120cab8:	31 ff                	xor    %edi,%edi
 120caba:	eb 27                	jmp    120cae3 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x473>
 120cabc:	31 db                	xor    %ebx,%ebx
 120cabe:	41 ff c5             	inc    %r13d
 120cac1:	66 44 89 84 5d 08 f9 	mov    %r8w,-0x6f8(%rbp,%rbx,2)
 120cac8:	ff ff 
 120caca:	48 8b 9d 00 f9 ff ff 	mov    -0x700(%rbp),%rbx
 120cad1:	48 ff c3             	inc    %rbx
 120cad4:	48 89 9d 00 f9 ff ff 	mov    %rbx,-0x700(%rbp)
 120cadb:	48 ff c7             	inc    %rdi
 120cade:	48 39 f7             	cmp    %rsi,%rdi
 120cae1:	74 4c                	je     120cb2f <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x4bf>
 120cae3:	44 0f b6 44 3a 02    	movzbl 0x2(%rdx,%rdi,1),%r8d
 120cae9:	47 8b 0c 86          	mov    (%r14,%r8,4),%r9d
 120caed:	45 85 c9             	test   %r9d,%r9d
 120caf0:	74 e9                	je     120cadb <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x46b>
 120caf2:	45 0f b7 d5          	movzwl %r13w,%r10d
 120caf6:	46 88 84 15 0e fb ff 	mov    %r8b,-0x4f2(%rbp,%r10,1)
 120cafd:	ff 
 120cafe:	48 85 db             	test   %rbx,%rbx
 120cb01:	74 bb                	je     120cabe <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x44e>
 120cb03:	48 81 fb 00 01 00 00 	cmp    $0x100,%rbx
 120cb0a:	0f 84 4e 06 00 00    	je     120d15e <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0xaee>
 120cb10:	44 0f b7 94 5d 06 f9 	movzwl -0x6fa(%rbp,%rbx,2),%r10d
 120cb17:	ff ff 
 120cb19:	47 3b 0c 96          	cmp    (%r14,%r10,4),%r9d
 120cb1d:	76 9f                	jbe    120cabe <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x44e>
 120cb1f:	48 ff cb             	dec    %rbx
 120cb22:	66 44 89 94 5d 0a f9 	mov    %r10w,-0x6f6(%rbp,%rbx,2)
 120cb29:	ff ff 
 120cb2b:	75 e3                	jne    120cb10 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x4a0>
 120cb2d:	eb 8d                	jmp    120cabc <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x44c>
 120cb2f:	48 85 db             	test   %rbx,%rbx
 120cb32:	0f 84 26 06 00 00    	je     120d15e <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0xaee>
 120cb38:	48 89 4d b0          	mov    %rcx,-0x50(%rbp)
 120cb3c:	48 8d bd 0e fc ff ff 	lea    -0x3f2(%rbp),%rdi
 120cb43:	48 8d b5 00 f9 ff ff 	lea    -0x700(%rbp),%rsi
 120cb4a:	4c 89 f2             	mov    %r14,%rdx
 120cb4d:	4c 89 5d c0          	mov    %r11,-0x40(%rbp)
 120cb51:	c5 f8 77             	vzeroupper 
 120cb54:	e8 77 86 f6 ff       	call   11751d0 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths>
 120cb59:	4c 8b 5d c0          	mov    -0x40(%rbp),%r11
 120cb5d:	0f b7 85 0e fc ff ff 	movzwl -0x3f2(%rbp),%eax
 120cb64:	66 85 c0             	test   %ax,%ax
 120cb67:	0f 85 f1 05 00 00    	jne    120d15e <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0xaee>
 120cb6d:	c5 fc 10 85 f0 fc ff 	vmovups -0x310(%rbp),%ymm0
 120cb74:	ff 
 120cb75:	c5 fc 11 85 a0 fe ff 	vmovups %ymm0,-0x160(%rbp)
 120cb7c:	ff 
 120cb7d:	c5 fc 10 85 d0 fc ff 	vmovups -0x330(%rbp),%ymm0
 120cb84:	ff 
 120cb85:	c5 fc 11 85 80 fe ff 	vmovups %ymm0,-0x180(%rbp)
 120cb8c:	ff 
 120cb8d:	c5 fc 10 85 b0 fc ff 	vmovups -0x350(%rbp),%ymm0
 120cb94:	ff 
 120cb95:	c5 fc 11 85 60 fe ff 	vmovups %ymm0,-0x1a0(%rbp)
 120cb9c:	ff 
 120cb9d:	c5 fc 10 85 90 fc ff 	vmovups -0x370(%rbp),%ymm0
 120cba4:	ff 
 120cba5:	c5 fc 11 85 40 fe ff 	vmovups %ymm0,-0x1c0(%rbp)
 120cbac:	ff 
 120cbad:	c5 fe 6f 85 10 fc ff 	vmovdqu -0x3f0(%rbp),%ymm0
 120cbb4:	ff 
 120cbb5:	c5 fc 10 8d 50 fc ff 	vmovups -0x3b0(%rbp),%ymm1
 120cbbc:	ff 
 120cbbd:	c5 fc 10 95 70 fc ff 	vmovups -0x390(%rbp),%ymm2
 120cbc4:	ff 
 120cbc5:	c5 fc 11 95 20 fe ff 	vmovups %ymm2,-0x1e0(%rbp)
 120cbcc:	ff 
 120cbcd:	c5 fc 11 8d 00 fe ff 	vmovups %ymm1,-0x200(%rbp)
 120cbd4:	ff 
 120cbd5:	c5 fc 10 8d 30 fc ff 	vmovups -0x3d0(%rbp),%ymm1
 120cbdc:	ff 
 120cbdd:	c5 fc 11 8d e0 fd ff 	vmovups %ymm1,-0x220(%rbp)
 120cbe4:	ff 
 120cbe5:	c5 fe 7f 85 c0 fd ff 	vmovdqu %ymm0,-0x240(%rbp)
 120cbec:	ff 
 120cbed:	66 45 85 ed          	test   %r13w,%r13w
 120cbf1:	74 1e                	je     120cc11 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x5a1>
 120cbf3:	41 0f b7 c5          	movzwl %r13w,%eax
 120cbf7:	89 c2                	mov    %eax,%edx
 120cbf9:	83 e2 03             	and    $0x3,%edx
 120cbfc:	66 41 83 fd 04       	cmp    $0x4,%r13w
 120cc01:	48 89 45 d0          	mov    %rax,-0x30(%rbp)
 120cc05:	73 20                	jae    120cc27 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x5b7>
 120cc07:	31 f6                	xor    %esi,%esi
 120cc09:	45 31 ed             	xor    %r13d,%r13d
 120cc0c:	e9 a9 00 00 00       	jmp    120ccba <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x64a>
 120cc11:	48 83 fb 04          	cmp    $0x4,%rbx
 120cc15:	0f 87 3f 05 00 00    	ja     120d15a <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0xaea>
 120cc1b:	45 31 ed             	xor    %r13d,%r13d
 120cc1e:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 120cc22:	e9 e5 00 00 00       	jmp    120cd0c <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x69c>
 120cc27:	83 e0 fc             	and    $0xfffffffc,%eax
 120cc2a:	31 f6                	xor    %esi,%esi
 120cc2c:	45 31 ed             	xor    %r13d,%r13d
 120cc2f:	90                   	nop
 120cc30:	0f b6 8c 35 0e fb ff 	movzbl -0x4f2(%rbp,%rsi,1),%ecx
 120cc37:	ff 
 120cc38:	41 8b 3c 8e          	mov    (%r14,%rcx,4),%edi
 120cc3c:	0f b6 8c 0d c0 fd ff 	movzbl -0x240(%rbp,%rcx,1),%ecx
 120cc43:	ff 
 120cc44:	83 e1 0f             	and    $0xf,%ecx
 120cc47:	48 0f af cf          	imul   %rdi,%rcx
 120cc4b:	4c 01 e9             	add    %r13,%rcx
 120cc4e:	0f b6 bc 35 0f fb ff 	movzbl -0x4f1(%rbp,%rsi,1),%edi
 120cc55:	ff 
 120cc56:	45 8b 04 be          	mov    (%r14,%rdi,4),%r8d
 120cc5a:	0f b6 bc 3d c0 fd ff 	movzbl -0x240(%rbp,%rdi,1),%edi
 120cc61:	ff 
 120cc62:	83 e7 0f             	and    $0xf,%edi
 120cc65:	49 0f af f8          	imul   %r8,%rdi
 120cc69:	44 0f b6 84 35 10 fb 	movzbl -0x4f0(%rbp,%rsi,1),%r8d
 120cc70:	ff ff 
 120cc72:	47 8b 0c 86          	mov    (%r14,%r8,4),%r9d
 120cc76:	46 0f b6 84 05 c0 fd 	movzbl -0x240(%rbp,%r8,1),%r8d
 120cc7d:	ff ff 
 120cc7f:	41 83 e0 0f          	and    $0xf,%r8d
 120cc83:	4d 0f af c1          	imul   %r9,%r8
 120cc87:	49 01 f8             	add    %rdi,%r8
 120cc8a:	49 01 c8             	add    %rcx,%r8
 120cc8d:	0f b6 8c 35 11 fb ff 	movzbl -0x4ef(%rbp,%rsi,1),%ecx
 120cc94:	ff 
 120cc95:	41 8b 3c 8e          	mov    (%r14,%rcx,4),%edi
 120cc99:	44 0f b6 ac 0d c0 fd 	movzbl -0x240(%rbp,%rcx,1),%r13d
 120cca0:	ff ff 
 120cca2:	41 83 e5 0f          	and    $0xf,%r13d
 120cca6:	4c 0f af ef          	imul   %rdi,%r13
 120ccaa:	4d 01 c5             	add    %r8,%r13
 120ccad:	48 83 c6 04          	add    $0x4,%rsi
 120ccb1:	48 39 f0             	cmp    %rsi,%rax
 120ccb4:	0f 85 76 ff ff ff    	jne    120cc30 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x5c0>
 120ccba:	48 85 d2             	test   %rdx,%rdx
 120ccbd:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 120ccc1:	74 3f                	je     120cd02 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x692>
 120ccc3:	48 8d 85 0c fb ff ff 	lea    -0x4f4(%rbp),%rax
 120ccca:	48 01 f0             	add    %rsi,%rax
 120cccd:	48 83 c0 02          	add    $0x2,%rax
 120ccd1:	31 f6                	xor    %esi,%esi
 120ccd3:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120ccda:	84 00 00 00 00 00 
 120cce0:	0f b6 3c 30          	movzbl (%rax,%rsi,1),%edi
 120cce4:	45 8b 04 be          	mov    (%r14,%rdi,4),%r8d
 120cce8:	0f b6 bc 3d c0 fd ff 	movzbl -0x240(%rbp,%rdi,1),%edi
 120ccef:	ff 
 120ccf0:	83 e7 0f             	and    $0xf,%edi
 120ccf3:	49 0f af f8          	imul   %r8,%rdi
 120ccf7:	49 01 fd             	add    %rdi,%r13
 120ccfa:	48 ff c6             	inc    %rsi
 120ccfd:	48 39 f2             	cmp    %rsi,%rdx
 120cd00:	75 de                	jne    120cce0 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x670>
 120cd02:	48 83 fb 05          	cmp    $0x5,%rbx
 120cd06:	0f 83 f0 00 00 00    	jae    120cdfc <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x78c>
 120cd0c:	31 c0                	xor    %eax,%eax
 120cd0e:	48 83 fb 04          	cmp    $0x4,%rbx
 120cd12:	0f 94 c0             	sete   %al
 120cd15:	48 8d 1c d8          	lea    (%rax,%rbx,8),%rbx
 120cd19:	48 83 c3 04          	add    $0x4,%rbx
 120cd1d:	b8 07 00 00 00       	mov    $0x7,%eax
 120cd22:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120cd29:	1f 84 00 00 00 00 00 
 120cd30:	41 8b 54 86 e4       	mov    -0x1c(%r14,%rax,4),%edx
 120cd35:	41 8b 74 86 e8       	mov    -0x18(%r14,%rax,4),%esi
 120cd3a:	4c 31 e2             	xor    %r12,%rdx
 120cd3d:	49 0f af d7          	imul   %r15,%rdx
 120cd41:	48 31 d6             	xor    %rdx,%rsi
 120cd44:	49 0f af f7          	imul   %r15,%rsi
 120cd48:	41 8b 54 86 ec       	mov    -0x14(%r14,%rax,4),%edx
 120cd4d:	48 31 f2             	xor    %rsi,%rdx
 120cd50:	49 0f af d7          	imul   %r15,%rdx
 120cd54:	41 8b 74 86 f0       	mov    -0x10(%r14,%rax,4),%esi
 120cd59:	48 31 d6             	xor    %rdx,%rsi
 120cd5c:	49 0f af f7          	imul   %r15,%rsi
 120cd60:	41 8b 54 86 f4       	mov    -0xc(%r14,%rax,4),%edx
 120cd65:	48 31 f2             	xor    %rsi,%rdx
 120cd68:	49 0f af d7          	imul   %r15,%rdx
 120cd6c:	41 8b 74 86 f8       	mov    -0x8(%r14,%rax,4),%esi
 120cd71:	48 31 d6             	xor    %rdx,%rsi
 120cd74:	49 0f af f7          	imul   %r15,%rsi
 120cd78:	41 8b 54 86 fc       	mov    -0x4(%r14,%rax,4),%edx
 120cd7d:	48 31 f2             	xor    %rsi,%rdx
 120cd80:	49 0f af d7          	imul   %r15,%rdx
 120cd84:	45 8b 24 86          	mov    (%r14,%rax,4),%r12d
 120cd88:	49 31 d4             	xor    %rdx,%r12
 120cd8b:	4d 0f af e7          	imul   %r15,%r12
 120cd8f:	48 83 c0 08          	add    $0x8,%rax
 120cd93:	48 3d 07 01 00 00    	cmp    $0x107,%rax
 120cd99:	75 95                	jne    120cd30 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x6c0>
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
 120ce08:	c5 fe 7f 85 50 ff ff 	vmovdqu %ymm0,-0xb0(%rbp)
 120ce0f:	ff 
 120ce10:	c5 fe 7f 85 40 ff ff 	vmovdqu %ymm0,-0xc0(%rbp)
 120ce17:	ff 
 120ce18:	c5 fe 7f 85 20 ff ff 	vmovdqu %ymm0,-0xe0(%rbp)
 120ce1f:	ff 
 120ce20:	c5 fe 7f 85 00 ff ff 	vmovdqu %ymm0,-0x100(%rbp)
 120ce27:	ff 
 120ce28:	c5 fe 7f 85 e0 fe ff 	vmovdqu %ymm0,-0x120(%rbp)
 120ce2f:	ff 
 120ce30:	c5 fe 7f 85 c0 fe ff 	vmovdqu %ymm0,-0x140(%rbp)
 120ce37:	ff 
 120ce38:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 120ce3c:	48 f7 d8             	neg    %rax
 120ce3f:	48 89 45 88          	mov    %rax,-0x78(%rbp)
 120ce43:	48 c7 45 b8 00 00 00 	movq   $0x0,-0x48(%rbp)
 120ce4a:	00 
 120ce4b:	48 c7 45 a8 00 00 00 	movq   $0x0,-0x58(%rbp)
 120ce52:	00 
 120ce53:	c7 45 cc 00 00 00 00 	movl   $0x0,-0x34(%rbp)
 120ce5a:	48 c7 45 a0 00 00 00 	movq   $0x0,-0x60(%rbp)
 120ce61:	00 
 120ce62:	c7 45 c8 00 00 00 00 	movl   $0x0,-0x38(%rbp)
 120ce69:	31 ff                	xor    %edi,%edi
 120ce6b:	31 f6                	xor    %esi,%esi
 120ce6d:	31 db                	xor    %ebx,%ebx
 120ce6f:	eb 12                	jmp    120ce83 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x813>
 120ce71:	48 89 d3             	mov    %rdx,%rbx
 120ce74:	49 ff c2             	inc    %r10
 120ce77:	4c 89 d6             	mov    %r10,%rsi
 120ce7a:	48 39 cf             	cmp    %rcx,%rdi
 120ce7d:	0f 83 d2 01 00 00    	jae    120d055 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x9e5>
 120ce83:	44 0f b6 94 3d 0e fb 	movzbl -0x4f2(%rbp,%rdi,1),%r10d
 120ce8a:	ff ff 
 120ce8c:	49 39 f2             	cmp    %rsi,%r10
 120ce8f:	0f 82 bb 02 00 00    	jb     120d150 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0xae0>
 120ce95:	42 0f b6 94 15 c0 fd 	movzbl -0x240(%rbp,%r10,1),%edx
 120ce9c:	ff ff 
 120ce9e:	49 89 d0             	mov    %rdx,%r8
 120cea1:	49 83 e0 0f          	and    $0xf,%r8
 120cea5:	0f 84 a5 02 00 00    	je     120d150 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0xae0>
 120ceab:	4c 89 d0             	mov    %r10,%rax
 120ceae:	48 29 f0             	sub    %rsi,%rax
 120ceb1:	76 5c                	jbe    120cf0f <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x89f>
 120ceb3:	48 83 f8 02          	cmp    $0x2,%rax
 120ceb7:	77 0f                	ja     120cec8 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x858>
 120ceb9:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 120cebd:	01 c1                	add    %eax,%ecx
 120cebf:	48 89 4d b8          	mov    %rcx,-0x48(%rbp)
 120cec3:	48 01 c3             	add    %rax,%rbx
 120cec6:	eb 47                	jmp    120cf0f <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x89f>
 120cec8:	41 b9 01 00 00 00    	mov    $0x1,%r9d
 120cece:	83 f8 0b             	cmp    $0xb,%eax
 120ced1:	72 31                	jb     120cf04 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x894>
 120ced3:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120ceda:	84 00 00 00 00 00 
 120cee0:	8d 48 05             	lea    0x5(%rax),%ecx
 120cee3:	83 e1 07             	and    $0x7,%ecx
 120cee6:	48 29 c8             	sub    %rcx,%rax
 120cee9:	48 83 c0 fd          	add    $0xfffffffffffffffd,%rax
 120ceed:	48 89 c1             	mov    %rax,%rcx
 120cef0:	48 c1 e9 03          	shr    $0x3,%rcx
 120cef4:	48 83 c1 02          	add    $0x2,%rcx
 120cef8:	49 ff c1             	inc    %r9
 120cefb:	48 83 f8 47          	cmp    $0x47,%rax
 120ceff:	48 89 c8             	mov    %rcx,%rax
 120cf02:	77 dc                	ja     120cee0 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x870>
 120cf04:	44 01 4d c8          	add    %r9d,-0x38(%rbp)
 120cf08:	4c 01 cb             	add    %r9,%rbx
 120cf0b:	4c 01 4d a0          	add    %r9,-0x60(%rbp)
 120cf0f:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 120cf13:	48 8d 77 01          	lea    0x1(%rdi),%rsi
 120cf17:	41 b9 01 00 00 00    	mov    $0x1,%r9d
 120cf1d:	48 39 ce             	cmp    %rcx,%rsi
 120cf20:	73 7c                	jae    120cf9e <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x92e>
 120cf22:	48 89 5d 98          	mov    %rbx,-0x68(%rbp)
 120cf26:	49 89 c9             	mov    %rcx,%r9
 120cf29:	49 29 f9             	sub    %rdi,%r9
 120cf2c:	48 8d 85 0f fb ff ff 	lea    -0x4f1(%rbp),%rax
 120cf33:	48 01 c7             	add    %rax,%rdi
 120cf36:	48 8b 45 88          	mov    -0x78(%rbp),%rax
 120cf3a:	48 89 75 90          	mov    %rsi,-0x70(%rbp)
 120cf3e:	48 01 c6             	add    %rax,%rsi
 120cf41:	80 e2 0f             	and    $0xf,%dl
 120cf44:	31 c0                	xor    %eax,%eax
 120cf46:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 120cf4d:	00 00 00 
 120cf50:	0f b6 1c 07          	movzbl (%rdi,%rax,1),%ebx
 120cf54:	49 39 da             	cmp    %rbx,%r10
 120cf57:	0f 83 f3 01 00 00    	jae    120d150 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0xae0>
 120cf5d:	0f b6 8c 1d c0 fd ff 	movzbl -0x240(%rbp,%rbx,1),%ecx
 120cf64:	ff 
 120cf65:	f6 c1 0f             	test   $0xf,%cl
 120cf68:	0f 84 e2 01 00 00    	je     120d150 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0xae0>
 120cf6e:	49 89 fb             	mov    %rdi,%r11
 120cf71:	49 8d 7a 01          	lea    0x1(%r10),%rdi
 120cf75:	48 39 df             	cmp    %rbx,%rdi
 120cf78:	75 29                	jne    120cfa3 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x933>
 120cf7a:	80 e1 0f             	and    $0xf,%cl
 120cf7d:	38 d1                	cmp    %dl,%cl
 120cf7f:	75 22                	jne    120cfa3 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x933>
 120cf81:	48 ff c0             	inc    %rax
 120cf84:	48 89 f1             	mov    %rsi,%rcx
 120cf87:	49 89 da             	mov    %rbx,%r10
 120cf8a:	48 01 c1             	add    %rax,%rcx
 120cf8d:	4c 89 df             	mov    %r11,%rdi
 120cf90:	75 be                	jne    120cf50 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x8e0>
 120cf92:	49 89 da             	mov    %rbx,%r10
 120cf95:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 120cf99:	48 89 cf             	mov    %rcx,%rdi
 120cf9c:	eb 16                	jmp    120cfb4 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x944>
 120cf9e:	48 89 f7             	mov    %rsi,%rdi
 120cfa1:	eb 15                	jmp    120cfb8 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x948>
 120cfa3:	48 8b 7d 90          	mov    -0x70(%rbp),%rdi
 120cfa7:	48 01 c7             	add    %rax,%rdi
 120cfaa:	48 ff c0             	inc    %rax
 120cfad:	49 89 c1             	mov    %rax,%r9
 120cfb0:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 120cfb4:	48 8b 5d 98          	mov    -0x68(%rbp),%rbx
 120cfb8:	42 8b 84 85 28 ff ff 	mov    -0xd8(%rbp,%r8,4),%eax
 120cfbf:	ff 
 120cfc0:	ff c0                	inc    %eax
 120cfc2:	42 89 84 85 28 ff ff 	mov    %eax,-0xd8(%rbp,%r8,4)
 120cfc9:	ff 
 120cfca:	48 8d 53 01          	lea    0x1(%rbx),%rdx
 120cfce:	49 83 f9 02          	cmp    $0x2,%r9
 120cfd2:	0f 82 99 fe ff ff    	jb     120ce71 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x801>
 120cfd8:	4d 8d 59 ff          	lea    -0x1(%r9),%r11
 120cfdc:	49 83 f9 03          	cmp    $0x3,%r9
 120cfe0:	77 1f                	ja     120d001 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x991>
 120cfe2:	44 01 d8             	add    %r11d,%eax
 120cfe5:	42 89 84 85 28 ff ff 	mov    %eax,-0xd8(%rbp,%r8,4)
 120cfec:	ff 
 120cfed:	4c 01 cb             	add    %r9,%rbx
 120cff0:	49 ff c2             	inc    %r10
 120cff3:	4c 89 d6             	mov    %r10,%rsi
 120cff6:	48 39 cf             	cmp    %rcx,%rdi
 120cff9:	0f 82 84 fe ff ff    	jb     120ce83 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x813>
 120cfff:	eb 54                	jmp    120d055 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x9e5>
 120d001:	b8 01 00 00 00       	mov    $0x1,%eax
 120d006:	49 83 fb 07          	cmp    $0x7,%r11
 120d00a:	72 29                	jb     120d035 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x9c5>
 120d00c:	0f 1f 40 00          	nopl   0x0(%rax)
 120d010:	41 8d 4b 01          	lea    0x1(%r11),%ecx
 120d014:	83 e1 03             	and    $0x3,%ecx
 120d017:	49 29 cb             	sub    %rcx,%r11
 120d01a:	49 83 c3 fd          	add    $0xfffffffffffffffd,%r11
 120d01e:	4c 89 d9             	mov    %r11,%rcx
 120d021:	48 c1 e9 02          	shr    $0x2,%rcx
 120d025:	48 83 c1 02          	add    $0x2,%rcx
 120d029:	48 ff c0             	inc    %rax
 120d02c:	49 83 fb 13          	cmp    $0x13,%r11
 120d030:	49 89 cb             	mov    %rcx,%r11
 120d033:	77 db                	ja     120d010 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x9a0>
 120d035:	01 45 cc             	add    %eax,-0x34(%rbp)
 120d038:	48 01 c2             	add    %rax,%rdx
 120d03b:	48 01 45 a8          	add    %rax,-0x58(%rbp)
 120d03f:	48 89 d3             	mov    %rdx,%rbx
 120d042:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 120d046:	49 ff c2             	inc    %r10
 120d049:	4c 89 d6             	mov    %r10,%rsi
 120d04c:	48 39 cf             	cmp    %rcx,%rdi
 120d04f:	0f 82 2e fe ff ff    	jb     120ce83 <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x813>
 120d055:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 120d059:	89 85 28 ff ff ff    	mov    %eax,-0xd8(%rbp)
 120d05f:	8b 45 c8             	mov    -0x38(%rbp),%eax
 120d062:	89 85 6c ff ff ff    	mov    %eax,-0x94(%rbp)
 120d068:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 120d06c:	48 89 85 d0 fe ff ff 	mov    %rax,-0x130(%rbp)
 120d073:	8b 45 cc             	mov    -0x34(%rbp),%eax
 120d076:	89 85 68 ff ff ff    	mov    %eax,-0x98(%rbp)
 120d07c:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 120d080:	48 89 85 c8 fe ff ff 	mov    %rax,-0x138(%rbp)
 120d087:	48 89 9d c0 fe ff ff 	mov    %rbx,-0x140(%rbp)
 120d08e:	c5 fc 10 85 e0 fe ff 	vmovups -0x120(%rbp),%ymm0
 120d095:	ff 
 120d096:	c5 fc 10 8d 00 ff ff 	vmovups -0x100(%rbp),%ymm1
 120d09d:	ff 
 120d09e:	c5 fc 10 95 40 ff ff 	vmovups -0xc0(%rbp),%ymm2
 120d0a5:	ff 
 120d0a6:	c5 fc 11 85 30 fd ff 	vmovups %ymm0,-0x2d0(%rbp)
 120d0ad:	ff 
 120d0ae:	c5 fc 11 8d 50 fd ff 	vmovups %ymm1,-0x2b0(%rbp)
 120d0b5:	ff 
 120d0b6:	c5 fc 11 95 90 fd ff 	vmovups %ymm2,-0x270(%rbp)
 120d0bd:	ff 
 120d0be:	48 8b 85 c0 fe ff ff 	mov    -0x140(%rbp),%rax
 120d0c5:	48 89 85 10 fd ff ff 	mov    %rax,-0x2f0(%rbp)
 120d0cc:	48 8b 85 c8 fe ff ff 	mov    -0x138(%rbp),%rax
 120d0d3:	48 89 85 18 fd ff ff 	mov    %rax,-0x2e8(%rbp)
 120d0da:	48 8b 85 d0 fe ff ff 	mov    -0x130(%rbp),%rax
 120d0e1:	48 89 85 20 fd ff ff 	mov    %rax,-0x2e0(%rbp)
 120d0e8:	48 8b 85 d8 fe ff ff 	mov    -0x128(%rbp),%rax
 120d0ef:	48 89 85 28 fd ff ff 	mov    %rax,-0x2d8(%rbp)
 120d0f6:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 120d0fd:	ff 
 120d0fe:	c5 fc 11 85 70 fd ff 	vmovups %ymm0,-0x290(%rbp)
 120d105:	ff 
 120d106:	c5 fe 6f 85 50 ff ff 	vmovdqu -0xb0(%rbp),%ymm0
 120d10d:	ff 
 120d10e:	c5 fe 7f 85 a0 fd ff 	vmovdqu %ymm0,-0x260(%rbp)
 120d115:	ff 
 120d116:	48 8d bd 70 ff ff ff 	lea    -0x90(%rbp),%rdi
 120d11d:	48 8d 75 80          	lea    -0x80(%rbp),%rsi
 120d121:	48 8d 95 10 fd ff ff 	lea    -0x2f0(%rbp),%rdx
 120d128:	c5 f8 77             	vzeroupper 
 120d12b:	e8 d0 9a f6 ff       	call   1176c00 <br.encoder.complex_prefix.finishBitCost__anon_36314>
 120d130:	0f b7 85 78 ff ff ff 	movzwl -0x88(%rbp),%eax
 120d137:	66 85 c0             	test   %ax,%ax
 120d13a:	4c 8b 5d c0          	mov    -0x40(%rbp),%r11
 120d13e:	75 1e                	jne    120d15e <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0xaee>
 120d140:	48 8b 9d 70 ff ff ff 	mov    -0x90(%rbp),%rbx
 120d147:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 120d14b:	e9 cd fb ff ff       	jmp    120cd1d <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0x6ad>
 120d150:	66 b8 1f 00          	mov    $0x1f,%ax
 120d154:	4c 8b 5d c0          	mov    -0x40(%rbp),%r11
 120d158:	eb 04                	jmp    120d15e <br.encoder.literal_context_split.treeBitCostCached__anon_46145+0xaee>
 120d15a:	66 b8 1f 00          	mov    $0x1f,%ax
 120d15e:	66 41 89 43 08       	mov    %ax,0x8(%r11)
 120d163:	48 81 c4 d8 06 00 00 	add    $0x6d8,%rsp
 120d16a:	5b                   	pop    %rbx
 120d16b:	41 5c                	pop    %r12
 120d16d:	41 5d                	pop    %r13
 120d16f:	41 5e                	pop    %r14
 120d171:	41 5f                	pop    %r15
 120d173:	5d                   	pop    %rbp
 120d174:	c5 f8 77             	vzeroupper 
 120d177:	c3                   	ret    
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
