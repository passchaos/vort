
/tmp/vort-zstd-anchor-cache-20261025/count-free/anchor-count-free:     file format elf64-x86-64


Disassembly of section .text:

00000000010f4aa0 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085>:
 10f4aa0:	55                   	push   %rbp
 10f4aa1:	48 89 e5             	mov    %rsp,%rbp
 10f4aa4:	41 57                	push   %r15
 10f4aa6:	41 56                	push   %r14
 10f4aa8:	41 55                	push   %r13
 10f4aaa:	41 54                	push   %r12
 10f4aac:	53                   	push   %rbx
 10f4aad:	48 81 ec b8 b0 02 00 	sub    $0x2b0b8,%rsp
 10f4ab4:	49 89 ce             	mov    %rcx,%r14
 10f4ab7:	48 89 bd 48 ff ff ff 	mov    %rdi,-0xb8(%rbp)
 10f4abe:	49 8d 88 ff ff fd ff 	lea    -0x20001(%r8),%rcx
 10f4ac5:	b8 4d 00 00 00       	mov    $0x4d,%eax
 10f4aca:	48 81 f9 fe ff fe ff 	cmp    $0xfffffffffffefffe,%rcx
 10f4ad1:	0f 86 c3 05 00 00    	jbe    10f509a <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x5fa>
 10f4ad7:	4c 89 c3             	mov    %r8,%rbx
 10f4ada:	41 0f b6 06          	movzbl (%r14),%eax
 10f4ade:	b9 01 00 00 00       	mov    $0x1,%ecx
 10f4ae3:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 10f4aea:	84 00 00 00 00 00 
 10f4af0:	41 38 04 0e          	cmp    %al,(%r14,%rcx,1)
 10f4af4:	75 0d                	jne    10f4b03 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x63>
 10f4af6:	48 ff c1             	inc    %rcx
 10f4af9:	48 39 cb             	cmp    %rcx,%rbx
 10f4afc:	75 f2                	jne    10f4af0 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x50>
 10f4afe:	e9 4b 04 00 00       	jmp    10f4f4e <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x4ae>
 10f4b03:	48 89 b5 50 ff ff ff 	mov    %rsi,-0xb0(%rbp)
 10f4b0a:	48 89 95 58 ff ff ff 	mov    %rdx,-0xa8(%rbp)
 10f4b11:	48 8d bd 48 cf ff ff 	lea    -0x30b8(%rbp),%rdi
 10f4b18:	ba 50 10 00 00       	mov    $0x1050,%edx
 10f4b1d:	31 f6                	xor    %esi,%esi
 10f4b1f:	e8 7c 85 00 00       	call   10fd0a0 <compiler_rt.memset>
 10f4b24:	48 8d bd a8 df ff ff 	lea    -0x2058(%rbp),%rdi
 10f4b2b:	ba 10 07 00 00       	mov    $0x710,%edx
 10f4b30:	31 f6                	xor    %esi,%esi
 10f4b32:	e8 69 85 00 00       	call   10fd0a0 <compiler_rt.memset>
 10f4b37:	45 31 db             	xor    %r11d,%r11d
 10f4b3a:	4c 89 b5 28 cf ff ff 	mov    %r14,-0x30d8(%rbp)
 10f4b41:	48 89 9d 30 cf ff ff 	mov    %rbx,-0x30d0(%rbp)
 10f4b48:	48 c7 85 38 cf ff ff 	movq   $0x0,-0x30c8(%rbp)
 10f4b4f:	00 00 00 00 
 10f4b53:	48 c7 85 40 cf ff ff 	movq   $0x1,-0x30c0(%rbp)
 10f4b5a:	01 00 00 00 
 10f4b5e:	4c 89 b5 98 df ff ff 	mov    %r14,-0x2068(%rbp)
 10f4b65:	48 89 9d a0 df ff ff 	mov    %rbx,-0x2060(%rbp)
 10f4b6c:	c6 85 b8 e6 ff ff 01 	movb   $0x1,-0x1948(%rbp)
 10f4b73:	48 8d 43 f8          	lea    -0x8(%rbx),%rax
 10f4b77:	48 89 85 30 ff ff ff 	mov    %rax,-0xd0(%rbp)
 10f4b7e:	b8 07 00 00 00       	mov    $0x7,%eax
 10f4b83:	48 29 d8             	sub    %rbx,%rax
 10f4b86:	48 89 85 38 ff ff ff 	mov    %rax,-0xc8(%rbp)
 10f4b8d:	45 31 ff             	xor    %r15d,%r15d
 10f4b90:	48 89 5d 88          	mov    %rbx,-0x78(%rbp)
 10f4b94:	4c 89 75 90          	mov    %r14,-0x70(%rbp)
 10f4b98:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 10f4b9f:	00 
 10f4ba0:	80 bd b8 e6 ff ff 00 	cmpb   $0x0,-0x1948(%rbp)
 10f4ba7:	4c 89 5d d0          	mov    %r11,-0x30(%rbp)
 10f4bab:	0f 84 7f 02 00 00    	je     10f4e30 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x390>
 10f4bb1:	ba 00 80 00 00       	mov    $0x8000,%edx
 10f4bb6:	48 8d bd 28 4f ff ff 	lea    -0xb0d8(%rbp),%rdi
 10f4bbd:	31 f6                	xor    %esi,%esi
 10f4bbf:	c5 f8 77             	vzeroupper 
 10f4bc2:	e8 d9 84 00 00       	call   10fd0a0 <compiler_rt.memset>
 10f4bc7:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 10f4bcb:	4c 3b 9d 30 ff ff ff 	cmp    -0xd0(%rbp),%r11
 10f4bd2:	0f 87 42 03 00 00    	ja     10f4f1a <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x47a>
 10f4bd8:	4c 89 bd 78 ff ff ff 	mov    %r15,-0x88(%rbp)
 10f4bdf:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 10f4be6:	4a 8d 34 18          	lea    (%rax,%r11,1),%rsi
 10f4bea:	4f 8d 04 1e          	lea    (%r14,%r11,1),%r8
 10f4bee:	49 89 de             	mov    %rbx,%r14
 10f4bf1:	4d 29 de             	sub    %r11,%r14
 10f4bf4:	48 c7 45 b0 ff ff ff 	movq   $0xffffffffffffffff,-0x50(%rbp)
 10f4bfb:	ff 
 10f4bfc:	45 31 ed             	xor    %r13d,%r13d
 10f4bff:	45 31 d2             	xor    %r10d,%r10d
 10f4c02:	48 ba 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%rdx
 10f4c09:	79 37 9e 
 10f4c0c:	48 89 75 a0          	mov    %rsi,-0x60(%rbp)
 10f4c10:	4c 89 45 a8          	mov    %r8,-0x58(%rbp)
 10f4c14:	eb 2f                	jmp    10f4c45 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x1a5>
 10f4c16:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 10f4c1d:	00 00 00 
 10f4c20:	43 8d 0c 2b          	lea    (%r11,%r13,1),%ecx
 10f4c24:	89 8c 85 28 4f fd ff 	mov    %ecx,-0x2b0d8(%rbp,%rax,4)
 10f4c2b:	c6 84 05 28 4f ff ff 	movb   $0x1,-0xb0d8(%rbp,%rax,1)
 10f4c32:	01 
 10f4c33:	49 ff c5             	inc    %r13
 10f4c36:	49 ff ce             	dec    %r14
 10f4c39:	48 89 f0             	mov    %rsi,%rax
 10f4c3c:	4c 01 e8             	add    %r13,%rax
 10f4c3f:	0f 84 4b 02 00 00    	je     10f4e90 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x3f0>
 10f4c45:	45 84 d2             	test   %r10b,%r10b
 10f4c48:	74 09                	je     10f4c53 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x1b3>
 10f4c4a:	49 39 fe             	cmp    %rdi,%r14
 10f4c4d:	0f 82 46 02 00 00    	jb     10f4e99 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x3f9>
 10f4c53:	4b 8b 04 28          	mov    (%r8,%r13,1),%rax
 10f4c57:	48 0f af c2          	imul   %rdx,%rax
 10f4c5b:	48 c1 e8 31          	shr    $0x31,%rax
 10f4c5f:	80 bc 05 28 4f ff ff 	cmpb   $0x0,-0xb0d8(%rbp,%rax,1)
 10f4c66:	00 
 10f4c67:	74 b7                	je     10f4c20 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x180>
 10f4c69:	8b 9c 85 28 4f fd ff 	mov    -0x2b0d8(%rbp,%rax,4),%ebx
 10f4c70:	c6 84 05 28 4f ff ff 	movb   $0x0,-0xb0d8(%rbp,%rax,1)
 10f4c77:	00 
 10f4c78:	49 39 db             	cmp    %rbx,%r11
 10f4c7b:	77 b6                	ja     10f4c33 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x193>
 10f4c7d:	4f 8d 24 2b          	lea    (%r11,%r13,1),%r12
 10f4c81:	4d 89 e7             	mov    %r12,%r15
 10f4c84:	49 29 df             	sub    %rbx,%r15
 10f4c87:	76 aa                	jbe    10f4c33 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x193>
 10f4c89:	45 84 d2             	test   %r10b,%r10b
 10f4c8c:	74 0a                	je     10f4c98 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x1f8>
 10f4c8e:	49 39 fe             	cmp    %rdi,%r14
 10f4c91:	77 05                	ja     10f4c98 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x1f8>
 10f4c93:	41 b2 01             	mov    $0x1,%r10b
 10f4c96:	eb 9b                	jmp    10f4c33 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x193>
 10f4c98:	4c 89 55 c0          	mov    %r10,-0x40(%rbp)
 10f4c9c:	48 89 7d b8          	mov    %rdi,-0x48(%rbp)
 10f4ca0:	48 8b 7d 90          	mov    -0x70(%rbp),%rdi
 10f4ca4:	48 8b 75 88          	mov    -0x78(%rbp),%rsi
 10f4ca8:	48 89 da             	mov    %rbx,%rdx
 10f4cab:	4c 89 e1             	mov    %r12,%rcx
 10f4cae:	e8 fd ee ff ff       	call   10f3bb0 <zstd.duplicateMatchLength>
 10f4cb3:	48 83 f8 08          	cmp    $0x8,%rax
 10f4cb7:	0f 82 a5 00 00 00    	jb     10f4d62 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x2c2>
 10f4cbd:	4c 8b 55 c0          	mov    -0x40(%rbp),%r10
 10f4cc1:	45 84 d2             	test   %r10b,%r10b
 10f4cc4:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 10f4cc8:	48 ba 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%rdx
 10f4ccf:	79 37 9e 
 10f4cd2:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 10f4cd6:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 10f4cda:	4c 8b 45 a8          	mov    -0x58(%rbp),%r8
 10f4cde:	74 0f                	je     10f4cef <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x24f>
 10f4ce0:	48 39 f8             	cmp    %rdi,%rax
 10f4ce3:	0f 82 4a ff ff ff    	jb     10f4c33 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x193>
 10f4ce9:	0f 86 04 01 00 00    	jbe    10f4df3 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x353>
 10f4cef:	4f 8d 0c 2b          	lea    (%r11,%r13,1),%r9
 10f4cf3:	4c 89 c9             	mov    %r9,%rcx
 10f4cf6:	48 29 d9             	sub    %rbx,%rcx
 10f4cf9:	49 01 c1             	add    %rax,%r9
 10f4cfc:	45 84 d2             	test   %r10b,%r10b
 10f4cff:	49 89 c7             	mov    %rax,%r15
 10f4d02:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 10f4d06:	48 89 85 60 ff ff ff 	mov    %rax,-0xa0(%rbp)
 10f4d0d:	48 89 bd 68 ff ff ff 	mov    %rdi,-0x98(%rbp)
 10f4d14:	0f 95 85 70 ff ff ff 	setne  -0x90(%rbp)
 10f4d1b:	48 8d 85 71 ff ff ff 	lea    -0x8f(%rbp),%rax
 10f4d22:	c7 40 03 00 00 00 00 	movl   $0x0,0x3(%rax)
 10f4d29:	c7 00 00 00 00 00    	movl   $0x0,(%rax)
 10f4d2f:	48 83 ec 08          	sub    $0x8,%rsp
 10f4d33:	48 8d bd c0 fa ff ff 	lea    -0x540(%rbp),%rdi
 10f4d3a:	48 8d b5 28 cf ff ff 	lea    -0x30d8(%rbp),%rsi
 10f4d41:	4c 89 ea             	mov    %r13,%rdx
 10f4d44:	4d 89 f8             	mov    %r15,%r8
 10f4d47:	48 8d 85 60 ff ff ff 	lea    -0xa0(%rbp),%rax
 10f4d4e:	50                   	push   %rax
 10f4d4f:	e8 ec ca ff ff       	call   10f1840 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner>
 10f4d54:	48 83 c4 10          	add    $0x10,%rsp
 10f4d58:	66 83 bd d0 fa ff ff 	cmpw   $0x0,-0x530(%rbp)
 10f4d5f:	00 
 10f4d60:	74 23                	je     10f4d85 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x2e5>
 10f4d62:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 10f4d66:	48 ba 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%rdx
 10f4d6d:	79 37 9e 
 10f4d70:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 10f4d74:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 10f4d78:	4c 8b 45 a8          	mov    -0x58(%rbp),%r8
 10f4d7c:	4c 8b 55 c0          	mov    -0x40(%rbp),%r10
 10f4d80:	e9 ae fe ff ff       	jmp    10f4c33 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x193>
 10f4d85:	80 bd c8 fa ff ff 00 	cmpb   $0x0,-0x538(%rbp)
 10f4d8c:	48 ba 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%rdx
 10f4d93:	79 37 9e 
 10f4d96:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 10f4d9a:	4c 8b 45 a8          	mov    -0x58(%rbp),%r8
 10f4d9e:	74 79                	je     10f4e19 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x379>
 10f4da0:	48 8b 85 c0 fa ff ff 	mov    -0x540(%rbp),%rax
 10f4da7:	48 3b 45 b0          	cmp    -0x50(%rbp),%rax
 10f4dab:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 10f4daf:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 10f4db3:	4c 8b 55 c0          	mov    -0x40(%rbp),%r10
 10f4db7:	72 1c                	jb     10f4dd5 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x335>
 10f4db9:	45 84 d2             	test   %r10b,%r10b
 10f4dbc:	0f 84 71 fe ff ff    	je     10f4c33 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x193>
 10f4dc2:	48 3b 45 b0          	cmp    -0x50(%rbp),%rax
 10f4dc6:	0f 85 67 fe ff ff    	jne    10f4c33 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x193>
 10f4dcc:	4c 39 ff             	cmp    %r15,%rdi
 10f4dcf:	0f 83 5e fe ff ff    	jae    10f4c33 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x193>
 10f4dd5:	48 89 45 b0          	mov    %rax,-0x50(%rbp)
 10f4dd9:	4c 89 ff             	mov    %r15,%rdi
 10f4ddc:	41 b2 01             	mov    $0x1,%r10b
 10f4ddf:	48 89 85 40 ff ff ff 	mov    %rax,-0xc0(%rbp)
 10f4de6:	48 89 5d 80          	mov    %rbx,-0x80(%rbp)
 10f4dea:	4c 89 65 98          	mov    %r12,-0x68(%rbp)
 10f4dee:	e9 40 fe ff ff       	jmp    10f4c33 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x193>
 10f4df3:	4c 3b 65 98          	cmp    -0x68(%rbp),%r12
 10f4df7:	0f 82 f2 fe ff ff    	jb     10f4cef <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x24f>
 10f4dfd:	48 89 c1             	mov    %rax,%rcx
 10f4e00:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 10f4e04:	48 2b 45 80          	sub    -0x80(%rbp),%rax
 10f4e08:	49 39 c7             	cmp    %rax,%r15
 10f4e0b:	48 89 c8             	mov    %rcx,%rax
 10f4e0e:	0f 83 1f fe ff ff    	jae    10f4c33 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x193>
 10f4e14:	e9 d6 fe ff ff       	jmp    10f4cef <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x24f>
 10f4e19:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 10f4e1d:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 10f4e21:	4c 8b 55 c0          	mov    -0x40(%rbp),%r10
 10f4e25:	e9 09 fe ff ff       	jmp    10f4c33 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x193>
 10f4e2a:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 10f4e30:	48 8d bd c0 fe ff ff 	lea    -0x140(%rbp),%rdi
 10f4e37:	4c 89 f6             	mov    %r14,%rsi
 10f4e3a:	48 89 da             	mov    %rbx,%rdx
 10f4e3d:	4c 89 d9             	mov    %r11,%rcx
 10f4e40:	c5 f8 77             	vzeroupper 
 10f4e43:	e8 88 b6 ff ff       	call   10f04d0 <zstd.findBestDuplicateMatchIn>
 10f4e48:	0f b7 85 e8 fe ff ff 	movzwl -0x118(%rbp),%eax
 10f4e4f:	66 85 c0             	test   %ax,%ax
 10f4e52:	0f 85 37 02 00 00    	jne    10f508f <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x5ef>
 10f4e58:	80 bd e0 fe ff ff 00 	cmpb   $0x0,-0x120(%rbp)
 10f4e5f:	0f 84 ce 00 00 00    	je     10f4f33 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x493>
 10f4e65:	c5 fc 10 85 c0 fe ff 	vmovups -0x140(%rbp),%ymm0
 10f4e6c:	ff 
 10f4e6d:	c5 fc 11 85 f0 fe ff 	vmovups %ymm0,-0x110(%rbp)
 10f4e74:	ff 
 10f4e75:	48 8b b5 f8 fe ff ff 	mov    -0x108(%rbp),%rsi
 10f4e7c:	48 8b bd 00 ff ff ff 	mov    -0x100(%rbp),%rdi
 10f4e83:	48 8d 85 f0 fe ff ff 	lea    -0x110(%rbp),%rax
 10f4e8a:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 10f4e8e:	eb 4a                	jmp    10f4eda <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x43a>
 10f4e90:	45 84 d2             	test   %r10b,%r10b
 10f4e93:	0f 84 c1 00 00 00    	je     10f4f5a <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x4ba>
 10f4e99:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 10f4e9d:	48 89 85 10 ff ff ff 	mov    %rax,-0xf0(%rbp)
 10f4ea4:	48 8b 75 98          	mov    -0x68(%rbp),%rsi
 10f4ea8:	48 89 b5 18 ff ff ff 	mov    %rsi,-0xe8(%rbp)
 10f4eaf:	48 89 bd 20 ff ff ff 	mov    %rdi,-0xe0(%rbp)
 10f4eb6:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 10f4ebd:	48 89 85 28 ff ff ff 	mov    %rax,-0xd8(%rbp)
 10f4ec4:	48 8d 85 10 ff ff ff 	lea    -0xf0(%rbp),%rax
 10f4ecb:	48 8b 5d 88          	mov    -0x78(%rbp),%rbx
 10f4ecf:	4c 8b 75 90          	mov    -0x70(%rbp),%r14
 10f4ed3:	4c 8b bd 78 ff ff ff 	mov    -0x88(%rbp),%r15
 10f4eda:	48 89 f1             	mov    %rsi,%rcx
 10f4edd:	4c 29 d9             	sub    %r11,%rcx
 10f4ee0:	4c 89 fa             	mov    %r15,%rdx
 10f4ee3:	48 c1 e2 05          	shl    $0x5,%rdx
 10f4ee7:	c5 fc 10 00          	vmovups (%rax),%ymm0
 10f4eeb:	c5 fc 11 84 15 c0 ea 	vmovups %ymm0,-0x1540(%rbp,%rdx,1)
 10f4ef2:	ff ff 
 10f4ef4:	4a 89 8c fd c0 e6 ff 	mov    %rcx,-0x1940(%rbp,%r15,8)
 10f4efb:	ff 
 10f4efc:	49 8d 47 01          	lea    0x1(%r15),%rax
 10f4f00:	49 89 fb             	mov    %rdi,%r11
 10f4f03:	49 01 f3             	add    %rsi,%r11
 10f4f06:	49 83 ff 7e          	cmp    $0x7e,%r15
 10f4f0a:	77 2e                	ja     10f4f3a <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x49a>
 10f4f0c:	49 89 c7             	mov    %rax,%r15
 10f4f0f:	49 39 db             	cmp    %rbx,%r11
 10f4f12:	0f 82 88 fc ff ff    	jb     10f4ba0 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x100>
 10f4f18:	eb 20                	jmp    10f4f3a <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x49a>
 10f4f1a:	4c 89 f8             	mov    %r15,%rax
 10f4f1d:	48 83 f8 02          	cmp    $0x2,%rax
 10f4f21:	48 8b 95 58 ff ff ff 	mov    -0xa8(%rbp),%rdx
 10f4f28:	48 8b b5 50 ff ff ff 	mov    -0xb0(%rbp),%rsi
 10f4f2f:	72 1d                	jb     10f4f4e <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x4ae>
 10f4f31:	eb 4a                	jmp    10f4f7d <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x4dd>
 10f4f33:	4c 89 f8             	mov    %r15,%rax
 10f4f36:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 10f4f3a:	48 83 f8 02          	cmp    $0x2,%rax
 10f4f3e:	48 8b 95 58 ff ff ff 	mov    -0xa8(%rbp),%rdx
 10f4f45:	48 8b b5 50 ff ff ff 	mov    -0xb0(%rbp),%rsi
 10f4f4c:	73 2f                	jae    10f4f7d <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x4dd>
 10f4f4e:	0f b6 0d 6d b0 f4 ff 	movzbl -0xb4f93(%rip),%ecx        # 103ffc2 <__anon_14421+0x2>
 10f4f55:	e9 33 01 00 00       	jmp    10f508d <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x5ed>
 10f4f5a:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 10f4f61:	48 8b 5d 88          	mov    -0x78(%rbp),%rbx
 10f4f65:	4c 8b 75 90          	mov    -0x70(%rbp),%r14
 10f4f69:	48 83 f8 02          	cmp    $0x2,%rax
 10f4f6d:	48 8b 95 58 ff ff ff 	mov    -0xa8(%rbp),%rdx
 10f4f74:	48 8b b5 50 ff ff ff 	mov    -0xb0(%rbp),%rsi
 10f4f7b:	72 d1                	jb     10f4f4e <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x4ae>
 10f4f7d:	48 8d 3c c5 00 00 00 	lea    0x0(,%rax,8),%rdi
 10f4f84:	00 
 10f4f85:	48 83 e7 f0          	and    $0xfffffffffffffff0,%rdi
 10f4f89:	31 c9                	xor    %ecx,%ecx
 10f4f8b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 10f4f90:	4c 8b 84 8d c8 ea ff 	mov    -0x1538(%rbp,%rcx,4),%r8
 10f4f97:	ff 
 10f4f98:	4c 8b 8c 8d d0 ea ff 	mov    -0x1530(%rbp,%rcx,4),%r9
 10f4f9f:	ff 
 10f4fa0:	4c 89 8c 0d 28 4f ff 	mov    %r9,-0xb0d8(%rbp,%rcx,1)
 10f4fa7:	ff 
 10f4fa8:	4d 01 c1             	add    %r8,%r9
 10f4fab:	4c 2b 84 8d c0 ea ff 	sub    -0x1540(%rbp,%rcx,4),%r8
 10f4fb2:	ff 
 10f4fb3:	4c 89 84 0d c0 fa ff 	mov    %r8,-0x540(%rbp,%rcx,1)
 10f4fba:	ff 
 10f4fbb:	4c 89 8c 0d 28 4f fd 	mov    %r9,-0x2b0d8(%rbp,%rcx,1)
 10f4fc2:	ff 
 10f4fc3:	4c 8b 84 8d e8 ea ff 	mov    -0x1518(%rbp,%rcx,4),%r8
 10f4fca:	ff 
 10f4fcb:	4c 8b 8c 8d f0 ea ff 	mov    -0x1510(%rbp,%rcx,4),%r9
 10f4fd2:	ff 
 10f4fd3:	4c 89 8c 0d 30 4f ff 	mov    %r9,-0xb0d0(%rbp,%rcx,1)
 10f4fda:	ff 
 10f4fdb:	4d 01 c1             	add    %r8,%r9
 10f4fde:	4c 2b 84 8d e0 ea ff 	sub    -0x1520(%rbp,%rcx,4),%r8
 10f4fe5:	ff 
 10f4fe6:	4c 89 84 0d c8 fa ff 	mov    %r8,-0x538(%rbp,%rcx,1)
 10f4fed:	ff 
 10f4fee:	4c 89 8c 0d 30 4f fd 	mov    %r9,-0x2b0d0(%rbp,%rcx,1)
 10f4ff5:	ff 
 10f4ff6:	48 83 c1 10          	add    $0x10,%rcx
 10f4ffa:	48 39 cf             	cmp    %rcx,%rdi
 10f4ffd:	75 91                	jne    10f4f90 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x4f0>
 10f4fff:	a8 01                	test   $0x1,%al
 10f5001:	74 33                	je     10f5036 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x596>
 10f5003:	48 8b bc 8d c8 ea ff 	mov    -0x1538(%rbp,%rcx,4),%rdi
 10f500a:	ff 
 10f500b:	4c 8b 84 8d d0 ea ff 	mov    -0x1530(%rbp,%rcx,4),%r8
 10f5012:	ff 
 10f5013:	4c 89 84 0d 28 4f ff 	mov    %r8,-0xb0d8(%rbp,%rcx,1)
 10f501a:	ff 
 10f501b:	49 01 f8             	add    %rdi,%r8
 10f501e:	48 2b bc 8d c0 ea ff 	sub    -0x1540(%rbp,%rcx,4),%rdi
 10f5025:	ff 
 10f5026:	48 89 bc 0d c0 fa ff 	mov    %rdi,-0x540(%rbp,%rcx,1)
 10f502d:	ff 
 10f502e:	4c 89 84 0d 28 4f fd 	mov    %r8,-0x2b0d8(%rbp,%rcx,1)
 10f5035:	ff 
 10f5036:	4c 8d 95 28 4f fd ff 	lea    -0x2b0d8(%rbp),%r10
 10f503d:	48 8d bd 60 ff ff ff 	lea    -0xa0(%rbp),%rdi
 10f5044:	4c 8d 8d c0 e6 ff ff 	lea    -0x1940(%rbp),%r9
 10f504b:	4c 89 f1             	mov    %r14,%rcx
 10f504e:	49 89 d8             	mov    %rbx,%r8
 10f5051:	41 53                	push   %r11
 10f5053:	50                   	push   %rax
 10f5054:	41 52                	push   %r10
 10f5056:	50                   	push   %rax
 10f5057:	4c 8d 95 28 4f ff ff 	lea    -0xb0d8(%rbp),%r10
 10f505e:	41 52                	push   %r10
 10f5060:	50                   	push   %rax
 10f5061:	4c 8d 95 c0 fa ff ff 	lea    -0x540(%rbp),%r10
 10f5068:	41 52                	push   %r10
 10f506a:	50                   	push   %rax
 10f506b:	c5 f8 77             	vzeroupper 
 10f506e:	e8 cd a7 fc ff       	call   10bf840 <zstd.emitBestSequenceCompressedBlock>
 10f5073:	48 83 c4 40          	add    $0x40,%rsp
 10f5077:	0f b7 85 60 ff ff ff 	movzwl -0xa0(%rbp),%eax
 10f507e:	66 85 c0             	test   %ax,%ax
 10f5081:	75 35                	jne    10f50b8 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x618>
 10f5083:	0f b6 8d 62 ff ff ff 	movzbl -0x9e(%rbp),%ecx
 10f508a:	88 4d ce             	mov    %cl,-0x32(%rbp)
 10f508d:	31 c0                	xor    %eax,%eax
 10f508f:	0f b6 c9             	movzbl %cl,%ecx
 10f5092:	c1 e1 10             	shl    $0x10,%ecx
 10f5095:	0f b7 c0             	movzwl %ax,%eax
 10f5098:	09 c8                	or     %ecx,%eax
 10f509a:	48 8b 8d 48 ff ff ff 	mov    -0xb8(%rbp),%rcx
 10f50a1:	89 01                	mov    %eax,(%rcx)
 10f50a3:	48 81 c4 b8 b0 02 00 	add    $0x2b0b8,%rsp
 10f50aa:	5b                   	pop    %rbx
 10f50ab:	41 5c                	pop    %r12
 10f50ad:	41 5d                	pop    %r13
 10f50af:	41 5e                	pop    %r14
 10f50b1:	41 5f                	pop    %r15
 10f50b3:	5d                   	pop    %rbp
 10f50b4:	c5 f8 77             	vzeroupper 
 10f50b7:	c3                   	ret    
 10f50b8:	eb d5                	jmp    10f508f <zstd.benchmarkUnprofiledAnchorCandidate__anon_3085+0x5ef>

Disassembly of section .vort_zstd_multi_sequence_winner:

Disassembly of section .vort_zstd_wide_sequence:

Disassembly of section .vort_zstd_fse_encode:

Disassembly of section .vort_zstd_dominance:

Disassembly of section .vort_zstd_dense_huffman:
