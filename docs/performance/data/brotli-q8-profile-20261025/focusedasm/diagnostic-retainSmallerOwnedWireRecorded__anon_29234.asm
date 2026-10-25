
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

0000000001268d20 <br.retainSmallerOwnedWireRecorded__anon_29234>:
 1268d20:	55                   	push   %rbp
 1268d21:	48 89 e5             	mov    %rsp,%rbp
 1268d24:	41 57                	push   %r15
 1268d26:	41 56                	push   %r14
 1268d28:	41 55                	push   %r13
 1268d2a:	41 54                	push   %r12
 1268d2c:	53                   	push   %rbx
 1268d2d:	48 83 ec 28          	sub    $0x28,%rsp
 1268d31:	4c 89 c3             	mov    %r8,%rbx
 1268d34:	49 89 ce             	mov    %rcx,%r14
 1268d37:	49 89 d7             	mov    %rdx,%r15
 1268d3a:	49 89 f4             	mov    %rsi,%r12
 1268d3d:	49 89 fd             	mov    %rdi,%r13
 1268d40:	c5 fc 10 07          	vmovups (%rdi),%ymm0
 1268d44:	c5 fc 11 45 b0       	vmovups %ymm0,-0x50(%rbp)
 1268d49:	48 8b 0a             	mov    (%rdx),%rcx
 1268d4c:	4c 8b 42 08          	mov    0x8(%rdx),%r8
 1268d50:	48 8d 7d b0          	lea    -0x50(%rbp),%rdi
 1268d54:	4c 89 f6             	mov    %r14,%rsi
 1268d57:	48 89 da             	mov    %rbx,%rdx
 1268d5a:	c5 f8 77             	vzeroupper 
 1268d5d:	e8 7e 52 fd ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 1268d62:	a8 01                	test   $0x1,%al
 1268d64:	0f 84 8e 00 00 00    	je     1268df8 <br.retainSmallerOwnedWireRecorded__anon_29234+0xd8>
 1268d6a:	49 8b 37             	mov    (%r15),%rsi
 1268d6d:	49 8b 57 08          	mov    0x8(%r15),%rdx
 1268d71:	49 8b 4d 10          	mov    0x10(%r13),%rcx
 1268d75:	49 8b 3c 24          	mov    (%r12),%rdi
 1268d79:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 1268d7e:	4c 8b 89 20 30 02 00 	mov    0x23020(%rcx),%r9
 1268d85:	4d 85 c9             	test   %r9,%r9
 1268d88:	74 54                	je     1268dde <br.retainSmallerOwnedWireRecorded__anon_29234+0xbe>
 1268d8a:	49 83 f9 01          	cmp    $0x1,%r9
 1268d8e:	0f 85 02 01 00 00    	jne    1268e96 <br.retainSmallerOwnedWireRecorded__anon_29234+0x176>
 1268d94:	45 31 c0             	xor    %r8d,%r8d
 1268d97:	41 f6 c1 01          	test   $0x1,%r9b
 1268d9b:	74 41                	je     1268dde <br.retainSmallerOwnedWireRecorded__anon_29234+0xbe>
 1268d9d:	4c 8d 49 20          	lea    0x20(%rcx),%r9
 1268da1:	4d 69 d0 18 01 00 00 	imul   $0x118,%r8,%r10
 1268da8:	47 0f b6 9c 11 10 01 	movzbl 0x110(%r9,%r10,1),%r11d
 1268daf:	00 00 
 1268db1:	41 80 e3 0f          	and    $0xf,%r11b
 1268db5:	41 80 fb 07          	cmp    $0x7,%r11b
 1268db9:	75 23                	jne    1268dde <br.retainSmallerOwnedWireRecorded__anon_29234+0xbe>
 1268dbb:	4d 01 d1             	add    %r10,%r9
 1268dbe:	41 80 79 40 00       	cmpb   $0x0,0x40(%r9)
 1268dc3:	74 19                	je     1268dde <br.retainSmallerOwnedWireRecorded__anon_29234+0xbe>
 1268dc5:	49 39 51 38          	cmp    %rdx,0x38(%r9)
 1268dc9:	75 13                	jne    1268dde <br.retainSmallerOwnedWireRecorded__anon_29234+0xbe>
 1268dcb:	4a 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%r8,8)
 1268dd2:	00 
 1268dd3:	75 09                	jne    1268dde <br.retainSmallerOwnedWireRecorded__anon_29234+0xbe>
 1268dd5:	42 c6 84 01 d3 42 02 	movb   $0x0,0x242d3(%rcx,%r8,1)
 1268ddc:	00 00 
 1268dde:	48 85 d2             	test   %rdx,%rdx
 1268de1:	74 09                	je     1268dec <br.retainSmallerOwnedWireRecorded__anon_29234+0xcc>
 1268de3:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1268de7:	31 c9                	xor    %ecx,%ecx
 1268de9:	ff 50 18             	call   *0x18(%rax)
 1268dec:	4d 89 37             	mov    %r14,(%r15)
 1268def:	49 89 5f 08          	mov    %rbx,0x8(%r15)
 1268df3:	e9 8f 00 00 00       	jmp    1268e87 <br.retainSmallerOwnedWireRecorded__anon_29234+0x167>
 1268df8:	49 8b 4d 10          	mov    0x10(%r13),%rcx
 1268dfc:	49 8b 3c 24          	mov    (%r12),%rdi
 1268e00:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 1268e05:	48 8b b1 20 30 02 00 	mov    0x23020(%rcx),%rsi
 1268e0c:	48 85 f6             	test   %rsi,%rsi
 1268e0f:	74 51                	je     1268e62 <br.retainSmallerOwnedWireRecorded__anon_29234+0x142>
 1268e11:	48 83 fe 01          	cmp    $0x1,%rsi
 1268e15:	0f 85 22 01 00 00    	jne    1268f3d <br.retainSmallerOwnedWireRecorded__anon_29234+0x21d>
 1268e1b:	31 d2                	xor    %edx,%edx
 1268e1d:	40 f6 c6 01          	test   $0x1,%sil
 1268e21:	74 3f                	je     1268e62 <br.retainSmallerOwnedWireRecorded__anon_29234+0x142>
 1268e23:	48 8d 71 20          	lea    0x20(%rcx),%rsi
 1268e27:	4c 69 c2 18 01 00 00 	imul   $0x118,%rdx,%r8
 1268e2e:	46 0f b6 8c 06 10 01 	movzbl 0x110(%rsi,%r8,1),%r9d
 1268e35:	00 00 
 1268e37:	41 80 e1 0f          	and    $0xf,%r9b
 1268e3b:	41 80 f9 07          	cmp    $0x7,%r9b
 1268e3f:	75 21                	jne    1268e62 <br.retainSmallerOwnedWireRecorded__anon_29234+0x142>
 1268e41:	4c 01 c6             	add    %r8,%rsi
 1268e44:	80 7e 40 00          	cmpb   $0x0,0x40(%rsi)
 1268e48:	74 18                	je     1268e62 <br.retainSmallerOwnedWireRecorded__anon_29234+0x142>
 1268e4a:	48 39 5e 38          	cmp    %rbx,0x38(%rsi)
 1268e4e:	75 12                	jne    1268e62 <br.retainSmallerOwnedWireRecorded__anon_29234+0x142>
 1268e50:	4c 39 b4 d1 d0 32 02 	cmp    %r14,0x232d0(%rcx,%rdx,8)
 1268e57:	00 
 1268e58:	75 08                	jne    1268e62 <br.retainSmallerOwnedWireRecorded__anon_29234+0x142>
 1268e5a:	c6 84 11 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rdx,1)
 1268e61:	00 
 1268e62:	48 85 db             	test   %rbx,%rbx
 1268e65:	74 20                	je     1268e87 <br.retainSmallerOwnedWireRecorded__anon_29234+0x167>
 1268e67:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1268e6b:	48 8b 40 18          	mov    0x18(%rax),%rax
 1268e6f:	4c 89 f6             	mov    %r14,%rsi
 1268e72:	48 89 da             	mov    %rbx,%rdx
 1268e75:	31 c9                	xor    %ecx,%ecx
 1268e77:	48 83 c4 28          	add    $0x28,%rsp
 1268e7b:	5b                   	pop    %rbx
 1268e7c:	41 5c                	pop    %r12
 1268e7e:	41 5d                	pop    %r13
 1268e80:	41 5e                	pop    %r14
 1268e82:	41 5f                	pop    %r15
 1268e84:	5d                   	pop    %rbp
 1268e85:	ff e0                	jmp    *%rax
 1268e87:	48 83 c4 28          	add    $0x28,%rsp
 1268e8b:	5b                   	pop    %rbx
 1268e8c:	41 5c                	pop    %r12
 1268e8e:	41 5d                	pop    %r13
 1268e90:	41 5e                	pop    %r14
 1268e92:	41 5f                	pop    %r15
 1268e94:	5d                   	pop    %rbp
 1268e95:	c3                   	ret    
 1268e96:	4d 89 ca             	mov    %r9,%r10
 1268e99:	49 83 e2 fe          	and    $0xfffffffffffffffe,%r10
 1268e9d:	4c 8d 59 58          	lea    0x58(%rcx),%r11
 1268ea1:	45 31 c0             	xor    %r8d,%r8d
 1268ea4:	eb 1e                	jmp    1268ec4 <br.retainSmallerOwnedWireRecorded__anon_29234+0x1a4>
 1268ea6:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 1268ead:	00 00 00 
 1268eb0:	49 83 c0 02          	add    $0x2,%r8
 1268eb4:	49 81 c3 30 02 00 00 	add    $0x230,%r11
 1268ebb:	4d 39 c2             	cmp    %r8,%r10
 1268ebe:	0f 84 d3 fe ff ff    	je     1268d97 <br.retainSmallerOwnedWireRecorded__anon_29234+0x77>
 1268ec4:	45 0f b6 a3 d8 00 00 	movzbl 0xd8(%r11),%r12d
 1268ecb:	00 
 1268ecc:	41 80 e4 0f          	and    $0xf,%r12b
 1268ed0:	41 80 fc 07          	cmp    $0x7,%r12b
 1268ed4:	75 2a                	jne    1268f00 <br.retainSmallerOwnedWireRecorded__anon_29234+0x1e0>
 1268ed6:	41 80 7b 08 00       	cmpb   $0x0,0x8(%r11)
 1268edb:	74 23                	je     1268f00 <br.retainSmallerOwnedWireRecorded__anon_29234+0x1e0>
 1268edd:	49 39 13             	cmp    %rdx,(%r11)
 1268ee0:	75 1e                	jne    1268f00 <br.retainSmallerOwnedWireRecorded__anon_29234+0x1e0>
 1268ee2:	4a 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%r8,8)
 1268ee9:	00 
 1268eea:	75 14                	jne    1268f00 <br.retainSmallerOwnedWireRecorded__anon_29234+0x1e0>
 1268eec:	42 c6 84 01 d3 42 02 	movb   $0x0,0x242d3(%rcx,%r8,1)
 1268ef3:	00 00 
 1268ef5:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 1268efc:	00 00 00 00 
 1268f00:	45 0f b6 a3 f0 01 00 	movzbl 0x1f0(%r11),%r12d
 1268f07:	00 
 1268f08:	41 80 e4 0f          	and    $0xf,%r12b
 1268f0c:	41 80 fc 07          	cmp    $0x7,%r12b
 1268f10:	75 9e                	jne    1268eb0 <br.retainSmallerOwnedWireRecorded__anon_29234+0x190>
 1268f12:	41 80 bb 20 01 00 00 	cmpb   $0x0,0x120(%r11)
 1268f19:	00 
 1268f1a:	74 94                	je     1268eb0 <br.retainSmallerOwnedWireRecorded__anon_29234+0x190>
 1268f1c:	49 39 93 18 01 00 00 	cmp    %rdx,0x118(%r11)
 1268f23:	75 8b                	jne    1268eb0 <br.retainSmallerOwnedWireRecorded__anon_29234+0x190>
 1268f25:	4a 39 b4 c1 d8 32 02 	cmp    %rsi,0x232d8(%rcx,%r8,8)
 1268f2c:	00 
 1268f2d:	75 81                	jne    1268eb0 <br.retainSmallerOwnedWireRecorded__anon_29234+0x190>
 1268f2f:	42 c6 84 01 d4 42 02 	movb   $0x0,0x242d4(%rcx,%r8,1)
 1268f36:	00 00 
 1268f38:	e9 73 ff ff ff       	jmp    1268eb0 <br.retainSmallerOwnedWireRecorded__anon_29234+0x190>
 1268f3d:	49 89 f0             	mov    %rsi,%r8
 1268f40:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1268f44:	4c 8d 49 58          	lea    0x58(%rcx),%r9
 1268f48:	31 d2                	xor    %edx,%edx
 1268f4a:	eb 18                	jmp    1268f64 <br.retainSmallerOwnedWireRecorded__anon_29234+0x244>
 1268f4c:	0f 1f 40 00          	nopl   0x0(%rax)
 1268f50:	48 83 c2 02          	add    $0x2,%rdx
 1268f54:	49 81 c1 30 02 00 00 	add    $0x230,%r9
 1268f5b:	49 39 d0             	cmp    %rdx,%r8
 1268f5e:	0f 84 b9 fe ff ff    	je     1268e1d <br.retainSmallerOwnedWireRecorded__anon_29234+0xfd>
 1268f64:	45 0f b6 91 d8 00 00 	movzbl 0xd8(%r9),%r10d
 1268f6b:	00 
 1268f6c:	41 80 e2 0f          	and    $0xf,%r10b
 1268f70:	41 80 fa 07          	cmp    $0x7,%r10b
 1268f74:	75 2a                	jne    1268fa0 <br.retainSmallerOwnedWireRecorded__anon_29234+0x280>
 1268f76:	41 80 79 08 00       	cmpb   $0x0,0x8(%r9)
 1268f7b:	74 23                	je     1268fa0 <br.retainSmallerOwnedWireRecorded__anon_29234+0x280>
 1268f7d:	49 39 19             	cmp    %rbx,(%r9)
 1268f80:	75 1e                	jne    1268fa0 <br.retainSmallerOwnedWireRecorded__anon_29234+0x280>
 1268f82:	4c 39 b4 d1 d0 32 02 	cmp    %r14,0x232d0(%rcx,%rdx,8)
 1268f89:	00 
 1268f8a:	75 14                	jne    1268fa0 <br.retainSmallerOwnedWireRecorded__anon_29234+0x280>
 1268f8c:	c6 84 11 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rdx,1)
 1268f93:	00 
 1268f94:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1268f9b:	00 00 00 00 00 
 1268fa0:	45 0f b6 91 f0 01 00 	movzbl 0x1f0(%r9),%r10d
 1268fa7:	00 
 1268fa8:	41 80 e2 0f          	and    $0xf,%r10b
 1268fac:	41 80 fa 07          	cmp    $0x7,%r10b
 1268fb0:	75 9e                	jne    1268f50 <br.retainSmallerOwnedWireRecorded__anon_29234+0x230>
 1268fb2:	41 80 b9 20 01 00 00 	cmpb   $0x0,0x120(%r9)
 1268fb9:	00 
 1268fba:	74 94                	je     1268f50 <br.retainSmallerOwnedWireRecorded__anon_29234+0x230>
 1268fbc:	49 39 99 18 01 00 00 	cmp    %rbx,0x118(%r9)
 1268fc3:	75 8b                	jne    1268f50 <br.retainSmallerOwnedWireRecorded__anon_29234+0x230>
 1268fc5:	4c 39 b4 d1 d8 32 02 	cmp    %r14,0x232d8(%rcx,%rdx,8)
 1268fcc:	00 
 1268fcd:	75 81                	jne    1268f50 <br.retainSmallerOwnedWireRecorded__anon_29234+0x230>
 1268fcf:	c6 84 11 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rdx,1)
 1268fd6:	00 
 1268fd7:	e9 74 ff ff ff       	jmp    1268f50 <br.retainSmallerOwnedWireRecorded__anon_29234+0x230>

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
