
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/d54ab236499589e8c9225c90450b9b10/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

00000000011e9ca0 <br.encoder.total_budget.Lease.init>:
 11e9ca0:	55                   	push   %rbp
 11e9ca1:	48 89 e5             	mov    %rsp,%rbp
 11e9ca4:	41 57                	push   %r15
 11e9ca6:	41 56                	push   %r14
 11e9ca8:	41 55                	push   %r13
 11e9caa:	41 54                	push   %r12
 11e9cac:	53                   	push   %rbx
 11e9cad:	48 83 ec 18          	sub    $0x18,%rsp
 11e9cb1:	48 8b 06             	mov    (%rsi),%rax
 11e9cb4:	4c 8b 4e 08          	mov    0x8(%rsi),%r9
 11e9cb8:	4c 8d 15 39 a8 0f 00 	lea    0xfa839(%rip),%r10        # 12e44f8 <br.encoder.total_budget.state.State.vtable>
 11e9cbf:	4d 39 d1             	cmp    %r10,%r9
 11e9cc2:	41 0f 95 c2          	setne  %r10b
 11e9cc6:	48 85 c0             	test   %rax,%rax
 11e9cc9:	41 0f 94 c3          	sete   %r11b
 11e9ccd:	45 08 d3             	or     %r10b,%r11b
 11e9cd0:	74 33                	je     11e9d05 <br.encoder.total_budget.Lease.init+0x65>
 11e9cd2:	80 7a 08 00          	cmpb   $0x0,0x8(%rdx)
 11e9cd6:	41 0f 94 c2          	sete   %r10b
 11e9cda:	48 85 c9             	test   %rcx,%rcx
 11e9cdd:	41 0f 94 c3          	sete   %r11b
 11e9ce1:	45 84 da             	test   %r11b,%r10b
 11e9ce4:	74 46                	je     11e9d2c <br.encoder.total_budget.Lease.init+0x8c>
 11e9ce6:	66 c7 47 20 00 00    	movw   $0x0,0x20(%rdi)
 11e9cec:	c5 f8 10 06          	vmovups (%rsi),%xmm0
 11e9cf0:	c5 f8 11 07          	vmovups %xmm0,(%rdi)
 11e9cf4:	48 c7 47 10 00 00 00 	movq   $0x0,0x10(%rdi)
 11e9cfb:	00 
 11e9cfc:	c6 47 18 01          	movb   $0x1,0x18(%rdi)
 11e9d00:	e9 98 01 00 00       	jmp    11e9e9d <br.encoder.total_budget.Lease.init+0x1fd>
 11e9d05:	48 8b 70 40          	mov    0x40(%rax),%rsi
 11e9d09:	48 85 f6             	test   %rsi,%rsi
 11e9d0c:	74 05                	je     11e9d13 <br.encoder.total_budget.Lease.init+0x73>
 11e9d0e:	4d 85 c0             	test   %r8,%r8
 11e9d11:	74 6a                	je     11e9d7d <br.encoder.total_budget.Lease.init+0xdd>
 11e9d13:	c5 fc 10 05 bd 0c e5 	vmovups -0x1af343(%rip),%ymm0        # 103a9d8 <__anon_43424>
 11e9d1a:	ff 
 11e9d1b:	c5 fc 11 07          	vmovups %ymm0,(%rdi)
 11e9d1f:	48 c7 47 20 1f 00 00 	movq   $0x1f,0x20(%rdi)
 11e9d26:	00 
 11e9d27:	e9 71 01 00 00       	jmp    11e9e9d <br.encoder.total_budget.Lease.init+0x1fd>
 11e9d2c:	48 85 c9             	test   %rcx,%rcx
 11e9d2f:	74 1e                	je     11e9d4f <br.encoder.total_budget.Lease.init+0xaf>
 11e9d31:	c6 41 20 01          	movb   $0x1,0x20(%rcx)
 11e9d35:	4c 89 41 08          	mov    %r8,0x8(%rcx)
 11e9d39:	4c 8b 11             	mov    (%rcx),%r10
 11e9d3c:	4d 39 c2             	cmp    %r8,%r10
 11e9d3f:	4d 0f 46 d0          	cmovbe %r8,%r10
 11e9d43:	4c 89 11             	mov    %r10,(%rcx)
 11e9d46:	c5 f8 10 02          	vmovups (%rdx),%xmm0
 11e9d4a:	c5 f8 11 41 10       	vmovups %xmm0,0x10(%rcx)
 11e9d4f:	49 83 c0 50          	add    $0x50,%r8
 11e9d53:	0f 92 45 c0          	setb   -0x40(%rbp)
 11e9d57:	72 46                	jb     11e9d9f <br.encoder.total_budget.Lease.init+0xff>
 11e9d59:	80 7a 08 00          	cmpb   $0x0,0x8(%rdx)
 11e9d5d:	74 59                	je     11e9db8 <br.encoder.total_budget.Lease.init+0x118>
 11e9d5f:	4c 3b 02             	cmp    (%rdx),%r8
 11e9d62:	76 54                	jbe    11e9db8 <br.encoder.total_budget.Lease.init+0x118>
 11e9d64:	c5 fc 10 05 bc 0c e5 	vmovups -0x1af344(%rip),%ymm0        # 103aa28 <__anon_43428>
 11e9d6b:	ff 
 11e9d6c:	c5 fc 11 07          	vmovups %ymm0,(%rdi)
 11e9d70:	48 c7 47 20 65 00 00 	movq   $0x65,0x20(%rdi)
 11e9d77:	00 
 11e9d78:	e9 20 01 00 00       	jmp    11e9e9d <br.encoder.total_budget.Lease.init+0x1fd>
 11e9d7d:	80 7a 08 00          	cmpb   $0x0,0x8(%rdx)
 11e9d81:	74 0f                	je     11e9d92 <br.encoder.total_budget.Lease.init+0xf2>
 11e9d83:	80 78 18 00          	cmpb   $0x0,0x18(%rax)
 11e9d87:	74 8a                	je     11e9d13 <br.encoder.total_budget.Lease.init+0x73>
 11e9d89:	48 8b 12             	mov    (%rdx),%rdx
 11e9d8c:	48 3b 50 10          	cmp    0x10(%rax),%rdx
 11e9d90:	75 81                	jne    11e9d13 <br.encoder.total_budget.Lease.init+0x73>
 11e9d92:	48 ff c6             	inc    %rsi
 11e9d95:	0f 94 45 c0          	sete   -0x40(%rbp)
 11e9d99:	0f 85 cd 00 00 00    	jne    11e9e6c <br.encoder.total_budget.Lease.init+0x1cc>
 11e9d9f:	c5 fc 10 05 59 0c e5 	vmovups -0x1af3a7(%rip),%ymm0        # 103aa00 <__anon_43426>
 11e9da6:	ff 
 11e9da7:	c5 fc 11 07          	vmovups %ymm0,(%rdi)
 11e9dab:	48 c7 47 20 4f 00 00 	movq   $0x4f,0x20(%rdi)
 11e9db2:	00 
 11e9db3:	e9 e5 00 00 00       	jmp    11e9e9d <br.encoder.total_budget.Lease.init+0x1fd>
 11e9db8:	49 89 d4             	mov    %rdx,%r12
 11e9dbb:	49 89 f5             	mov    %rsi,%r13
 11e9dbe:	4d 89 c6             	mov    %r8,%r14
 11e9dc1:	49 89 cf             	mov    %rcx,%r15
 11e9dc4:	48 89 fb             	mov    %rdi,%rbx
 11e9dc7:	48 8b 4d 08          	mov    0x8(%rbp),%rcx
 11e9dcb:	be 50 00 00 00       	mov    $0x50,%esi
 11e9dd0:	48 89 c7             	mov    %rax,%rdi
 11e9dd3:	ba 03 00 00 00       	mov    $0x3,%edx
 11e9dd8:	41 ff 11             	call   *(%r9)
 11e9ddb:	48 85 c0             	test   %rax,%rax
 11e9dde:	0f 84 b3 00 00 00    	je     11e9e97 <br.encoder.total_budget.Lease.init+0x1f7>
 11e9de4:	4c 89 e9             	mov    %r13,%rcx
 11e9de7:	c4 c1 78 10 45 00    	vmovups 0x0(%r13),%xmm0
 11e9ded:	c5 f8 11 00          	vmovups %xmm0,(%rax)
 11e9df1:	c4 c1 78 10 04 24    	vmovups (%r12),%xmm0
 11e9df7:	c5 f8 11 40 10       	vmovups %xmm0,0x10(%rax)
 11e9dfc:	4c 89 78 20          	mov    %r15,0x20(%rax)
 11e9e00:	4c 89 70 28          	mov    %r14,0x28(%rax)
 11e9e04:	4c 89 70 30          	mov    %r14,0x30(%rax)
 11e9e08:	48 c7 40 38 00 00 00 	movq   $0x0,0x38(%rax)
 11e9e0f:	00 
 11e9e10:	48 c7 40 40 01 00 00 	movq   $0x1,0x40(%rax)
 11e9e17:	00 
 11e9e18:	66 c7 40 48 00 00    	movw   $0x0,0x48(%rax)
 11e9e1e:	4d 85 ff             	test   %r15,%r15
 11e9e21:	74 31                	je     11e9e54 <br.encoder.total_budget.Lease.init+0x1b4>
 11e9e23:	48 89 c6             	mov    %rax,%rsi
 11e9e26:	48 83 c6 10          	add    $0x10,%rsi
 11e9e2a:	c5 f8 10 06          	vmovups (%rsi),%xmm0
 11e9e2e:	c5 f8 29 45 c0       	vmovaps %xmm0,-0x40(%rbp)
 11e9e33:	41 c6 47 20 01       	movb   $0x1,0x20(%r15)
 11e9e38:	4d 89 77 08          	mov    %r14,0x8(%r15)
 11e9e3c:	49 8b 37             	mov    (%r15),%rsi
 11e9e3f:	4c 39 f6             	cmp    %r14,%rsi
 11e9e42:	4c 0f 47 f6          	cmova  %rsi,%r14
 11e9e46:	4d 89 37             	mov    %r14,(%r15)
 11e9e49:	c5 f8 28 45 c0       	vmovaps -0x40(%rbp),%xmm0
 11e9e4e:	c4 c1 78 11 47 10    	vmovups %xmm0,0x10(%r15)
 11e9e54:	66 c7 43 20 00 00    	movw   $0x0,0x20(%rbx)
 11e9e5a:	c5 f8 10 01          	vmovups (%rcx),%xmm0
 11e9e5e:	c5 f8 11 03          	vmovups %xmm0,(%rbx)
 11e9e62:	48 89 43 10          	mov    %rax,0x10(%rbx)
 11e9e66:	c6 43 18 01          	movb   $0x1,0x18(%rbx)
 11e9e6a:	eb 31                	jmp    11e9e9d <br.encoder.total_budget.Lease.init+0x1fd>
 11e9e6c:	48 85 c9             	test   %rcx,%rcx
 11e9e6f:	74 0a                	je     11e9e7b <br.encoder.total_budget.Lease.init+0x1db>
 11e9e71:	48 39 48 20          	cmp    %rcx,0x20(%rax)
 11e9e75:	0f 85 98 fe ff ff    	jne    11e9d13 <br.encoder.total_budget.Lease.init+0x73>
 11e9e7b:	48 89 70 40          	mov    %rsi,0x40(%rax)
 11e9e7f:	66 c7 47 20 00 00    	movw   $0x0,0x20(%rdi)
 11e9e85:	c5 f8 10 00          	vmovups (%rax),%xmm0
 11e9e89:	c5 f8 11 07          	vmovups %xmm0,(%rdi)
 11e9e8d:	48 89 47 10          	mov    %rax,0x10(%rdi)
 11e9e91:	c6 47 18 00          	movb   $0x0,0x18(%rdi)
 11e9e95:	eb 06                	jmp    11e9e9d <br.encoder.total_budget.Lease.init+0x1fd>
 11e9e97:	66 c7 43 20 1a 00    	movw   $0x1a,0x20(%rbx)
 11e9e9d:	48 83 c4 18          	add    $0x18,%rsp
 11e9ea1:	5b                   	pop    %rbx
 11e9ea2:	41 5c                	pop    %r12
 11e9ea4:	41 5d                	pop    %r13
 11e9ea6:	41 5e                	pop    %r14
 11e9ea8:	41 5f                	pop    %r15
 11e9eaa:	5d                   	pop    %rbp
 11e9eab:	c5 f8 77             	vzeroupper 
 11e9eae:	c3                   	ret    

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
