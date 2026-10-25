
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

0000000001273b10 <br.encodePreferredCommandPlanAllocRecorded__anon_231663>:
 1273b10:	55                   	push   %rbp
 1273b11:	48 89 e5             	mov    %rsp,%rbp
 1273b14:	41 57                	push   %r15
 1273b16:	41 56                	push   %r14
 1273b18:	41 55                	push   %r13
 1273b1a:	41 54                	push   %r12
 1273b1c:	53                   	push   %rbx
 1273b1d:	48 83 e4 e0          	and    $0xffffffffffffffe0,%rsp
 1273b21:	48 81 ec 60 11 00 00 	sub    $0x1160,%rsp
 1273b28:	4c 89 8c 24 b0 00 00 	mov    %r9,0xb0(%rsp)
 1273b2f:	00 
 1273b30:	48 89 8c 24 c8 00 00 	mov    %rcx,0xc8(%rsp)
 1273b37:	00 
 1273b38:	49 89 d6             	mov    %rdx,%r14
 1273b3b:	48 89 b4 24 98 00 00 	mov    %rsi,0x98(%rsp)
 1273b42:	00 
 1273b43:	48 89 7c 24 50       	mov    %rdi,0x50(%rsp)
 1273b48:	48 8b 45 20          	mov    0x20(%rbp),%rax
 1273b4c:	c5 fc 10 06          	vmovups (%rsi),%ymm0
 1273b50:	c5 fc 11 84 24 60 05 	vmovups %ymm0,0x560(%rsp)
 1273b57:	00 00 
 1273b59:	48 8b 08             	mov    (%rax),%rcx
 1273b5c:	48 89 8c 24 e8 00 00 	mov    %rcx,0xe8(%rsp)
 1273b63:	00 
 1273b64:	48 8b 48 08          	mov    0x8(%rax),%rcx
 1273b68:	48 89 8c 24 e0 00 00 	mov    %rcx,0xe0(%rsp)
 1273b6f:	00 
 1273b70:	48 8b 48 10          	mov    0x10(%rax),%rcx
 1273b74:	48 89 8c 24 d8 00 00 	mov    %rcx,0xd8(%rsp)
 1273b7b:	00 
 1273b7c:	48 8b 48 18          	mov    0x18(%rax),%rcx
 1273b80:	48 89 8c 24 d0 00 00 	mov    %rcx,0xd0(%rsp)
 1273b87:	00 
 1273b88:	c5 fc 10 40 20       	vmovups 0x20(%rax),%ymm0
 1273b8d:	c5 fc 11 84 24 50 04 	vmovups %ymm0,0x450(%rsp)
 1273b94:	00 00 
 1273b96:	0f b6 48 40          	movzbl 0x40(%rax),%ecx
 1273b9a:	88 4c 24 40          	mov    %cl,0x40(%rsp)
 1273b9e:	88 4c 24 08          	mov    %cl,0x8(%rsp)
 1273ba2:	44 0f b6 60 41       	movzbl 0x41(%rax),%r12d
 1273ba7:	0f b6 48 42          	movzbl 0x42(%rax),%ecx
 1273bab:	88 8c 24 e0 01 00 00 	mov    %cl,0x1e0(%rsp)
 1273bb2:	0f b6 48 43          	movzbl 0x43(%rax),%ecx
 1273bb6:	88 8c 24 c0 01 00 00 	mov    %cl,0x1c0(%rsp)
 1273bbd:	44 0f b6 68 44       	movzbl 0x44(%rax),%r13d
 1273bc2:	0f b6 48 46          	movzbl 0x46(%rax),%ecx
 1273bc6:	88 4c 24 68          	mov    %cl,0x68(%rsp)
 1273bca:	0f b6 48 47          	movzbl 0x47(%rax),%ecx
 1273bce:	88 8c 24 20 01 00 00 	mov    %cl,0x120(%rsp)
 1273bd5:	44 0f b6 78 4e       	movzbl 0x4e(%rax),%r15d
 1273bda:	c5 fe 6f 06          	vmovdqu (%rsi),%ymm0
 1273bde:	c5 fe 7f 84 24 80 07 	vmovdqu %ymm0,0x780(%rsp)
 1273be5:	00 00 
 1273be7:	48 8b 5d 10          	mov    0x10(%rbp),%rbx
 1273beb:	48 8d bc 24 40 01 00 	lea    0x140(%rsp),%rdi
 1273bf2:	00 
 1273bf3:	48 8d b4 24 80 07 00 	lea    0x780(%rsp),%rsi
 1273bfa:	00 
 1273bfb:	ba 05 00 00 00       	mov    $0x5,%edx
 1273c00:	4c 89 84 24 a8 00 00 	mov    %r8,0xa8(%rsp)
 1273c07:	00 
 1273c08:	4c 89 c1             	mov    %r8,%rcx
 1273c0b:	49 89 d8             	mov    %rbx,%r8
 1273c0e:	c5 f8 77             	vzeroupper 
 1273c11:	e8 7a 39 00 00       	call   1277590 <br.encoder.quality_profile.Active.begin>
 1273c16:	41 f6 c4 01          	test   $0x1,%r12b
 1273c1a:	4c 89 b4 24 80 00 00 	mov    %r14,0x80(%rsp)
 1273c21:	00 
 1273c22:	0f 84 9d 01 00 00    	je     1273dc5 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x2b5>
 1273c28:	c5 fe 6f 84 24 50 04 	vmovdqu 0x450(%rsp),%ymm0
 1273c2f:	00 00 
 1273c31:	c5 fe 7f 84 24 a0 01 	vmovdqu %ymm0,0x1a0(%rsp)
 1273c38:	00 00 
 1273c3a:	44 89 f8             	mov    %r15d,%eax
 1273c3d:	24 1f                	and    $0x1f,%al
 1273c3f:	88 44 24 2f          	mov    %al,0x2f(%rsp)
 1273c43:	48 85 db             	test   %rbx,%rbx
 1273c46:	0f 84 79 01 00 00    	je     1273dc5 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x2b5>
 1273c4c:	48 89 d8             	mov    %rbx,%rax
 1273c4f:	44 88 64 24 60       	mov    %r12b,0x60(%rsp)
 1273c54:	44 88 ac 24 00 01 00 	mov    %r13b,0x100(%rsp)
 1273c5b:	00 
 1273c5c:	44 88 7c 24 06       	mov    %r15b,0x6(%rsp)
 1273c61:	0f b6 0d 78 8a dc ff 	movzbl -0x237588(%rip),%ecx        # 103c6e0 <__anon_30440>
 1273c68:	48 8b 9c 24 a8 01 00 	mov    0x1a8(%rsp),%rbx
 1273c6f:	00 
 1273c70:	4c 8b ac 24 b0 01 00 	mov    0x1b0(%rsp),%r13
 1273c77:	00 
 1273c78:	4c 8b a4 24 b8 01 00 	mov    0x1b8(%rsp),%r12
 1273c7f:	00 
 1273c80:	31 f6                	xor    %esi,%esi
 1273c82:	0f b6 54 24 2f       	movzbl 0x2f(%rsp),%edx
 1273c87:	89 54 24 10          	mov    %edx,0x10(%rsp)
 1273c8b:	80 e1 0f             	and    $0xf,%cl
 1273c8e:	88 4c 24 30          	mov    %cl,0x30(%rsp)
 1273c92:	4c 8b bc 24 b0 00 00 	mov    0xb0(%rsp),%r15
 1273c99:	00 
 1273c9a:	49 89 c6             	mov    %rax,%r14
 1273c9d:	eb 20                	jmp    1273cbf <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1af>
 1273c9f:	90                   	nop
 1273ca0:	4c 89 e1             	mov    %r12,%rcx
 1273ca3:	4d 89 ec             	mov    %r13,%r12
 1273ca6:	49 89 dd             	mov    %rbx,%r13
 1273ca9:	4c 89 eb             	mov    %r13,%rbx
 1273cac:	4d 89 e5             	mov    %r12,%r13
 1273caf:	49 83 c7 60          	add    $0x60,%r15
 1273cb3:	49 89 cc             	mov    %rcx,%r12
 1273cb6:	49 ff ce             	dec    %r14
 1273cb9:	0f 84 10 01 00 00    	je     1273dcf <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x2bf>
 1273cbf:	c4 c1 7e 6f 07       	vmovdqu (%r15),%ymm0
 1273cc4:	c4 c1 7c 10 4f 20    	vmovups 0x20(%r15),%ymm1
 1273cca:	c4 c1 7c 10 57 40    	vmovups 0x40(%r15),%ymm2
 1273cd0:	c5 fc 11 94 24 60 02 	vmovups %ymm2,0x260(%rsp)
 1273cd7:	00 00 
 1273cd9:	c5 fc 11 8c 24 40 02 	vmovups %ymm1,0x240(%rsp)
 1273ce0:	00 00 
 1273ce2:	c5 fe 7f 84 24 20 02 	vmovdqu %ymm0,0x220(%rsp)
 1273ce9:	00 00 
 1273ceb:	f6 84 24 78 02 00 00 	testb  $0x1,0x278(%rsp)
 1273cf2:	01 
 1273cf3:	74 ab                	je     1273ca0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x190>
 1273cf5:	0f b6 84 24 79 02 00 	movzbl 0x279(%rsp),%eax
 1273cfc:	00 
 1273cfd:	24 03                	and    $0x3,%al
 1273cff:	3c 02                	cmp    $0x2,%al
 1273d01:	74 9d                	je     1273ca0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x190>
 1273d03:	48 89 74 24 48       	mov    %rsi,0x48(%rsp)
 1273d08:	48 8d bc 24 10 02 00 	lea    0x210(%rsp),%rdi
 1273d0f:	00 
 1273d10:	48 8d b4 24 20 02 00 	lea    0x220(%rsp),%rsi
 1273d17:	00 
 1273d18:	8b 54 24 10          	mov    0x10(%rsp),%edx
 1273d1c:	48 8b 8c 24 d8 00 00 	mov    0xd8(%rsp),%rcx
 1273d23:	00 
 1273d24:	4c 8b 84 24 d0 00 00 	mov    0xd0(%rsp),%r8
 1273d2b:	00 
 1273d2c:	c5 f8 77             	vzeroupper 
 1273d2f:	e8 9c db f8 ff       	call   12018d0 <br.commandWireDistance>
 1273d34:	0f b7 b4 24 18 02 00 	movzwl 0x218(%rsp),%esi
 1273d3b:	00 
 1273d3c:	48 85 f6             	test   %rsi,%rsi
 1273d3f:	0f 85 ce 1e 00 00    	jne    1275c13 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x2103>
 1273d45:	48 8b b4 24 10 02 00 	mov    0x210(%rsp),%rsi
 1273d4c:	00 
 1273d4d:	48 8d 7c 24 5e       	lea    0x5e(%rsp),%rdi
 1273d52:	48 89 74 24 38       	mov    %rsi,0x38(%rsp)
 1273d57:	48 8d 94 24 a0 01 00 	lea    0x1a0(%rsp),%rdx
 1273d5e:	00 
 1273d5f:	e8 3c d5 f8 ff       	call   12012a0 <br.decoder.distance_history.symbolForDistance>
 1273d64:	0f b6 4c 24 5f       	movzbl 0x5f(%rsp),%ecx
 1273d69:	48 8b 74 24 48       	mov    0x48(%rsp),%rsi
 1273d6e:	48 8d 46 01          	lea    0x1(%rsi),%rax
 1273d72:	84 c9                	test   %cl,%cl
 1273d74:	74 1f                	je     1273d95 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x285>
 1273d76:	0f b6 54 24 5e       	movzbl 0x5e(%rsp),%edx
 1273d7b:	80 e2 0f             	and    $0xf,%dl
 1273d7e:	3a 54 24 30          	cmp    0x30(%rsp),%dl
 1273d82:	75 11                	jne    1273d95 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x285>
 1273d84:	4c 89 e1             	mov    %r12,%rcx
 1273d87:	4d 89 ec             	mov    %r13,%r12
 1273d8a:	49 89 dd             	mov    %rbx,%r13
 1273d8d:	48 89 c6             	mov    %rax,%rsi
 1273d90:	e9 14 ff ff ff       	jmp    1273ca9 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x199>
 1273d95:	84 c9                	test   %cl,%cl
 1273d97:	48 0f 45 f0          	cmovne %rax,%rsi
 1273d9b:	48 89 9c 24 a0 01 00 	mov    %rbx,0x1a0(%rsp)
 1273da2:	00 
 1273da3:	4c 89 ac 24 a8 01 00 	mov    %r13,0x1a8(%rsp)
 1273daa:	00 
 1273dab:	4c 89 a4 24 b0 01 00 	mov    %r12,0x1b0(%rsp)
 1273db2:	00 
 1273db3:	48 8b 4c 24 38       	mov    0x38(%rsp),%rcx
 1273db8:	48 89 8c 24 b8 01 00 	mov    %rcx,0x1b8(%rsp)
 1273dbf:	00 
 1273dc0:	e9 e4 fe ff ff       	jmp    1273ca9 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x199>
 1273dc5:	c7 44 24 28 00 00 00 	movl   $0x0,0x28(%rsp)
 1273dcc:	00 
 1273dcd:	eb 28                	jmp    1273df7 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x2e7>
 1273dcf:	48 83 fe 40          	cmp    $0x40,%rsi
 1273dd3:	0f 93 c0             	setae  %al
 1273dd6:	89 44 24 28          	mov    %eax,0x28(%rsp)
 1273dda:	4c 8b b4 24 80 00 00 	mov    0x80(%rsp),%r14
 1273de1:	00 
 1273de2:	44 0f b6 7c 24 06    	movzbl 0x6(%rsp),%r15d
 1273de8:	44 0f b6 ac 24 00 01 	movzbl 0x100(%rsp),%r13d
 1273def:	00 00 
 1273df1:	44 0f b6 64 24 60    	movzbl 0x60(%rsp),%r12d
 1273df7:	44 89 fe             	mov    %r15d,%esi
 1273dfa:	48 8b 55 18          	mov    0x18(%rbp),%rdx
 1273dfe:	80 bc 24 c0 01 00 00 	cmpb   $0x0,0x1c0(%rsp)
 1273e05:	00 
 1273e06:	0f 95 c0             	setne  %al
 1273e09:	0f b6 8c 24 e0 01 00 	movzbl 0x1e0(%rsp),%ecx
 1273e10:	00 
 1273e11:	41 0f b6 fc          	movzbl %r12b,%edi
 1273e15:	0f 45 f9             	cmovne %ecx,%edi
 1273e18:	89 7c 24 48          	mov    %edi,0x48(%rsp)
 1273e1c:	20 c1                	and    %al,%cl
 1273e1e:	89 8c 24 f8 00 00 00 	mov    %ecx,0xf8(%rsp)
 1273e25:	75 31                	jne    1273e58 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x348>
 1273e27:	80 7c 24 28 00       	cmpb   $0x0,0x28(%rsp)
 1273e2c:	75 2a                	jne    1273e58 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x348>
 1273e2e:	bb 30 ad 03 01       	mov    $0x103ad30,%ebx
 1273e33:	41 bc 39 ad 03 01    	mov    $0x103ad39,%r12d
 1273e39:	b8 38 ad 03 01       	mov    $0x103ad38,%eax
 1273e3e:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 1273e43:	41 bf 81 ad 03 01    	mov    $0x103ad81,%r15d
 1273e49:	b8 80 ad 03 01       	mov    $0x103ad80,%eax
 1273e4e:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 1273e53:	e9 fc 00 00 00       	jmp    1273f54 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x444>
 1273e58:	48 8d 84 24 c8 04 00 	lea    0x4c8(%rsp),%rax
 1273e5f:	00 
 1273e60:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 1273e65:	4c 8d bc 24 c9 04 00 	lea    0x4c9(%rsp),%r15
 1273e6c:	00 
 1273e6d:	48 8d 84 24 80 04 00 	lea    0x480(%rsp),%rax
 1273e74:	00 
 1273e75:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 1273e7a:	4c 8d a4 24 81 04 00 	lea    0x481(%rsp),%r12
 1273e81:	00 
 1273e82:	31 c0                	xor    %eax,%eax
 1273e84:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1273e8b:	00 00 00 00 00 
 1273e90:	48 83 f8 38          	cmp    $0x38,%rax
 1273e94:	0f 93 84 04 20 02 00 	setae  0x220(%rsp,%rax,1)
 1273e9b:	00 
 1273e9c:	0f 93 84 04 21 02 00 	setae  0x221(%rsp,%rax,1)
 1273ea3:	00 
 1273ea4:	0f 93 84 04 22 02 00 	setae  0x222(%rsp,%rax,1)
 1273eab:	00 
 1273eac:	0f 93 84 04 23 02 00 	setae  0x223(%rsp,%rax,1)
 1273eb3:	00 
 1273eb4:	0f 93 84 04 24 02 00 	setae  0x224(%rsp,%rax,1)
 1273ebb:	00 
 1273ebc:	0f 93 84 04 25 02 00 	setae  0x225(%rsp,%rax,1)
 1273ec3:	00 
 1273ec4:	0f 93 84 04 26 02 00 	setae  0x226(%rsp,%rax,1)
 1273ecb:	00 
 1273ecc:	0f 93 84 04 27 02 00 	setae  0x227(%rsp,%rax,1)
 1273ed3:	00 
 1273ed4:	48 83 c0 08          	add    $0x8,%rax
 1273ed8:	48 83 f8 40          	cmp    $0x40,%rax
 1273edc:	75 b2                	jne    1273e90 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x380>
 1273ede:	80 bc 24 20 01 00 00 	cmpb   $0x0,0x120(%rsp)
 1273ee5:	00 
 1273ee6:	0f b6 44 24 68       	movzbl 0x68(%rsp),%eax
 1273eeb:	b9 02 00 00 00       	mov    $0x2,%ecx
 1273ef0:	0f 45 c8             	cmovne %eax,%ecx
 1273ef3:	80 e1 03             	and    $0x3,%cl
 1273ef6:	88 8c 24 88 00 00 00 	mov    %cl,0x88(%rsp)
 1273efd:	c5 fe 6f 84 24 20 02 	vmovdqu 0x220(%rsp),%ymm0
 1273f04:	00 00 
 1273f06:	c5 fc 10 8c 24 40 02 	vmovups 0x240(%rsp),%ymm1
 1273f0d:	00 00 
 1273f0f:	c5 fe 7f 84 24 82 04 	vmovdqu %ymm0,0x482(%rsp)
 1273f16:	00 00 
 1273f18:	c5 fc 11 8c 24 a2 04 	vmovups %ymm1,0x4a2(%rsp)
 1273f1f:	00 00 
 1273f21:	c6 84 24 95 00 00 00 	movb   $0x2,0x95(%rsp)
 1273f28:	02 
 1273f29:	48 c7 84 24 78 04 00 	movq   $0x0,0x478(%rsp)
 1273f30:	00 00 00 00 00 
 1273f35:	88 8c 24 80 04 00 00 	mov    %cl,0x480(%rsp)
 1273f3c:	c6 84 24 81 04 00 00 	movb   $0x2,0x481(%rsp)
 1273f43:	02 
 1273f44:	c6 84 24 c8 04 00 00 	movb   $0x1,0x4c8(%rsp)
 1273f4b:	01 
 1273f4c:	48 8d 9c 24 78 04 00 	lea    0x478(%rsp),%rbx
 1273f53:	00 
 1273f54:	c5 fc 10 84 24 50 04 	vmovups 0x450(%rsp),%ymm0
 1273f5b:	00 00 
 1273f5d:	c5 fc 11 84 24 c8 07 	vmovups %ymm0,0x7c8(%rsp)
 1273f64:	00 00 
 1273f66:	0f b6 44 24 40       	movzbl 0x40(%rsp),%eax
 1273f6b:	24 01                	and    $0x1,%al
 1273f6d:	88 84 24 c9 09 00 00 	mov    %al,0x9c9(%rsp)
 1273f74:	48 c7 84 24 b8 07 00 	movq   $0x0,0x7b8(%rsp)
 1273f7b:	00 00 00 00 00 
 1273f80:	8b 44 24 28          	mov    0x28(%rsp),%eax
 1273f84:	88 84 24 cd 09 00 00 	mov    %al,0x9cd(%rsp)
 1273f8b:	c6 84 24 cc 09 00 00 	movb   $0x0,0x9cc(%rsp)
 1273f92:	00 
 1273f93:	c5 fc 10 03          	vmovups (%rbx),%ymm0
 1273f97:	c5 fc 10 4b 20       	vmovups 0x20(%rbx),%ymm1
 1273f9c:	c5 fc 11 84 24 e8 07 	vmovups %ymm0,0x7e8(%rsp)
 1273fa3:	00 00 
 1273fa5:	c5 fc 11 8c 24 08 08 	vmovups %ymm1,0x808(%rsp)
 1273fac:	00 00 
 1273fae:	c5 fc 10 43 38       	vmovups 0x38(%rbx),%ymm0
 1273fb3:	c5 fc 11 84 24 20 08 	vmovups %ymm0,0x820(%rsp)
 1273fba:	00 00 
 1273fbc:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1273fc0:	c5 fc 11 84 24 90 09 	vmovups %ymm0,0x990(%rsp)
 1273fc7:	00 00 
 1273fc9:	c5 fc 11 84 24 80 09 	vmovups %ymm0,0x980(%rsp)
 1273fd0:	00 00 
 1273fd2:	c5 fc 11 84 24 60 09 	vmovups %ymm0,0x960(%rsp)
 1273fd9:	00 00 
 1273fdb:	c5 fc 11 84 24 40 09 	vmovups %ymm0,0x940(%rsp)
 1273fe2:	00 00 
 1273fe4:	c5 fc 11 84 24 20 09 	vmovups %ymm0,0x920(%rsp)
 1273feb:	00 00 
 1273fed:	c5 fc 11 84 24 00 09 	vmovups %ymm0,0x900(%rsp)
 1273ff4:	00 00 
 1273ff6:	c5 fc 11 84 24 e0 08 	vmovups %ymm0,0x8e0(%rsp)
 1273ffd:	00 00 
 1273fff:	c5 fc 11 84 24 c0 08 	vmovups %ymm0,0x8c0(%rsp)
 1274006:	00 00 
 1274008:	c5 fc 11 84 24 a0 08 	vmovups %ymm0,0x8a0(%rsp)
 127400f:	00 00 
 1274011:	c5 fc 11 84 24 80 08 	vmovups %ymm0,0x880(%rsp)
 1274018:	00 00 
 127401a:	c5 fc 11 84 24 60 08 	vmovups %ymm0,0x860(%rsp)
 1274021:	00 00 
 1274023:	c5 fc 11 84 24 40 08 	vmovups %ymm0,0x840(%rsp)
 127402a:	00 00 
 127402c:	c6 84 24 c0 09 00 00 	movb   $0x38,0x9c0(%rsp)
 1274033:	38 
 1274034:	c6 84 24 c8 09 00 00 	movb   $0x0,0x9c8(%rsp)
 127403b:	00 
 127403c:	0f b7 05 ed 6e dc ff 	movzwl -0x239113(%rip),%eax        # 103af30 <__anon_29470>
 1274043:	66 89 84 24 c2 09 00 	mov    %ax,0x9c2(%rsp)
 127404a:	00 
 127404b:	40 80 e6 1f          	and    $0x1f,%sil
 127404f:	40 88 74 24 06       	mov    %sil,0x6(%rsp)
 1274054:	40 88 b4 24 c1 09 00 	mov    %sil,0x9c1(%rsp)
 127405b:	00 
 127405c:	48 8b 84 24 e8 00 00 	mov    0xe8(%rsp),%rax
 1274063:	00 
 1274064:	48 89 84 24 a8 07 00 	mov    %rax,0x7a8(%rsp)
 127406b:	00 
 127406c:	48 8b 84 24 e0 00 00 	mov    0xe0(%rsp),%rax
 1274073:	00 
 1274074:	48 89 84 24 b0 07 00 	mov    %rax,0x7b0(%rsp)
 127407b:	00 
 127407c:	c7 84 24 c4 09 00 00 	movl   $0x1000101,0x9c4(%rsp)
 1274083:	01 01 00 01 
 1274087:	48 8b 84 24 d8 00 00 	mov    0xd8(%rsp),%rax
 127408e:	00 
 127408f:	48 89 84 24 b8 09 00 	mov    %rax,0x9b8(%rsp)
 1274096:	00 
 1274097:	48 8b 84 24 d0 00 00 	mov    0xd0(%rsp),%rax
 127409e:	00 
 127409f:	48 89 84 24 b0 09 00 	mov    %rax,0x9b0(%rsp)
 12740a6:	00 
 12740a7:	66 c7 84 24 ca 09 00 	movw   $0x0,0x9ca(%rsp)
 12740ae:	00 00 00 
 12740b1:	48 c7 84 24 c0 07 00 	movq   $0x0,0x7c0(%rsp)
 12740b8:	00 00 00 00 00 
 12740bd:	c5 fc 10 42 70       	vmovups 0x70(%rdx),%ymm0
 12740c2:	c5 fc 11 84 24 40 05 	vmovups %ymm0,0x540(%rsp)
 12740c9:	00 00 
 12740cb:	c5 fc 10 02          	vmovups (%rdx),%ymm0
 12740cf:	c5 fc 10 4a 20       	vmovups 0x20(%rdx),%ymm1
 12740d4:	c5 fc 10 52 40       	vmovups 0x40(%rdx),%ymm2
 12740d9:	c5 fc 10 5a 60       	vmovups 0x60(%rdx),%ymm3
 12740de:	c5 fc 11 9c 24 30 05 	vmovups %ymm3,0x530(%rsp)
 12740e5:	00 00 
 12740e7:	c5 fc 11 94 24 10 05 	vmovups %ymm2,0x510(%rsp)
 12740ee:	00 00 
 12740f0:	c5 fc 11 8c 24 f0 04 	vmovups %ymm1,0x4f0(%rsp)
 12740f7:	00 00 
 12740f9:	c5 fc 11 84 24 d0 04 	vmovups %ymm0,0x4d0(%rsp)
 1274100:	00 00 
 1274102:	c5 fc 10 02          	vmovups (%rdx),%ymm0
 1274106:	c5 fc 10 4a 20       	vmovups 0x20(%rdx),%ymm1
 127410b:	c5 fc 10 52 40       	vmovups 0x40(%rdx),%ymm2
 1274110:	c5 fc 10 5a 60       	vmovups 0x60(%rdx),%ymm3
 1274115:	c5 fc 11 84 24 d0 05 	vmovups %ymm0,0x5d0(%rsp)
 127411c:	00 00 
 127411e:	c5 fc 11 8c 24 f0 05 	vmovups %ymm1,0x5f0(%rsp)
 1274125:	00 00 
 1274127:	c5 fc 11 94 24 10 06 	vmovups %ymm2,0x610(%rsp)
 127412e:	00 00 
 1274130:	c5 fc 11 9c 24 30 06 	vmovups %ymm3,0x630(%rsp)
 1274137:	00 00 
 1274139:	c5 fe 6f 42 70       	vmovdqu 0x70(%rdx),%ymm0
 127413e:	c5 fe 7f 84 24 40 06 	vmovdqu %ymm0,0x640(%rsp)
 1274145:	00 00 
 1274147:	48 83 ec 08          	sub    $0x8,%rsp
 127414b:	48 8d 84 24 b0 07 00 	lea    0x7b0(%rsp),%rax
 1274152:	00 
 1274153:	4c 8d 94 24 d8 05 00 	lea    0x5d8(%rsp),%r10
 127415a:	00 
 127415b:	48 8d bc 24 10 04 00 	lea    0x410(%rsp),%rdi
 1274162:	00 
 1274163:	48 8b b4 24 a0 00 00 	mov    0xa0(%rsp),%rsi
 127416a:	00 
 127416b:	4c 89 f2             	mov    %r14,%rdx
 127416e:	48 8b 8c 24 d0 00 00 	mov    0xd0(%rsp),%rcx
 1274175:	00 
 1274176:	4c 8b 84 24 b0 00 00 	mov    0xb0(%rsp),%r8
 127417d:	00 
 127417e:	4c 8b 8c 24 b8 00 00 	mov    0xb8(%rsp),%r9
 1274185:	00 
 1274186:	50                   	push   %rax
 1274187:	41 52                	push   %r10
 1274189:	ff 75 10             	push   0x10(%rbp)
 127418c:	c5 f8 77             	vzeroupper 
 127418f:	e8 9c a9 fb ff       	call   122eb30 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509>
 1274194:	48 83 c4 20          	add    $0x20,%rsp
 1274198:	44 0f b7 b4 24 18 04 	movzwl 0x418(%rsp),%r14d
 127419f:	00 00 
 12741a1:	4d 85 f6             	test   %r14,%r14
 12741a4:	0f 85 bb 1a 00 00    	jne    1275c65 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x2155>
 12741aa:	48 8b 84 24 08 04 00 	mov    0x408(%rsp),%rax
 12741b1:	00 
 12741b2:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 12741b7:	48 8b 84 24 10 04 00 	mov    0x410(%rsp),%rax
 12741be:	00 
 12741bf:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 12741c4:	c5 fc 10 84 24 d0 05 	vmovups 0x5d0(%rsp),%ymm0
 12741cb:	00 00 
 12741cd:	c5 fc 10 8c 24 f0 05 	vmovups 0x5f0(%rsp),%ymm1
 12741d4:	00 00 
 12741d6:	c5 fc 10 94 24 10 06 	vmovups 0x610(%rsp),%ymm2
 12741dd:	00 00 
 12741df:	c5 fc 10 9c 24 30 06 	vmovups 0x630(%rsp),%ymm3
 12741e6:	00 00 
 12741e8:	c5 fc 11 84 24 80 02 	vmovups %ymm0,0x280(%rsp)
 12741ef:	00 00 
 12741f1:	c5 fc 11 8c 24 a0 02 	vmovups %ymm1,0x2a0(%rsp)
 12741f8:	00 00 
 12741fa:	c5 fc 11 94 24 c0 02 	vmovups %ymm2,0x2c0(%rsp)
 1274201:	00 00 
 1274203:	c5 fc 11 9c 24 e0 02 	vmovups %ymm3,0x2e0(%rsp)
 127420a:	00 00 
 127420c:	c5 fc 10 84 24 40 06 	vmovups 0x640(%rsp),%ymm0
 1274213:	00 00 
 1274215:	c5 fc 11 84 24 f0 02 	vmovups %ymm0,0x2f0(%rsp)
 127421c:	00 00 
 127421e:	48 8b 03             	mov    (%rbx),%rax
 1274221:	48 89 44 24 60       	mov    %rax,0x60(%rsp)
 1274226:	48 8b 44 24 30       	mov    0x30(%rsp),%rax
 127422b:	0f b6 00             	movzbl (%rax),%eax
 127422e:	88 44 24 30          	mov    %al,0x30(%rsp)
 1274232:	45 0f b6 1c 24       	movzbl (%r12),%r11d
 1274237:	c4 c1 7c 10 44 24 01 	vmovups 0x1(%r12),%ymm0
 127423e:	c5 fc 29 84 24 00 01 	vmovaps %ymm0,0x100(%rsp)
 1274245:	00 00 
 1274247:	c4 c1 7e 6f 44 24 21 	vmovdqu 0x21(%r12),%ymm0
 127424e:	c5 fd 7f 84 24 20 01 	vmovdqa %ymm0,0x120(%rsp)
 1274255:	00 00 
 1274257:	41 0f b7 44 24 45    	movzwl 0x45(%r12),%eax
 127425d:	66 89 44 24 24       	mov    %ax,0x24(%rsp)
 1274262:	41 8b 44 24 41       	mov    0x41(%r12),%eax
 1274267:	89 44 24 20          	mov    %eax,0x20(%rsp)
 127426b:	48 8b 44 24 38       	mov    0x38(%rsp),%rax
 1274270:	0f b6 10             	movzbl (%rax),%edx
 1274273:	41 8b 07             	mov    (%r15),%eax
 1274276:	41 8b 4f 03          	mov    0x3(%r15),%ecx
 127427a:	89 44 24 78          	mov    %eax,0x78(%rsp)
 127427e:	89 4c 24 7b          	mov    %ecx,0x7b(%rsp)
 1274282:	89 54 24 38          	mov    %edx,0x38(%rsp)
 1274286:	84 d2                	test   %dl,%dl
 1274288:	74 1e                	je     12742a8 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x798>
 127428a:	4c 8d a4 24 fe 00 00 	lea    0xfe(%rsp),%r12
 1274291:	00 
 1274292:	4c 89 e7             	mov    %r12,%rdi
 1274295:	48 89 de             	mov    %rbx,%rsi
 1274298:	44 89 db             	mov    %r11d,%ebx
 127429b:	c5 f8 77             	vzeroupper 
 127429e:	e8 cd bf fb ff       	call   1230270 <br.encoder.literal_context_split.Candidate.suffixCutoff>
 12742a3:	41 89 db             	mov    %ebx,%r11d
 12742a6:	eb 06                	jmp    12742ae <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x79e>
 12742a8:	41 bc 8a 38 08 01    	mov    $0x108388a,%r12d
 12742ae:	4c 8b b4 24 80 00 00 	mov    0x80(%rsp),%r14
 12742b5:	00 
 12742b6:	44 8b 7c 24 48       	mov    0x48(%rsp),%r15d
 12742bb:	45 0f b7 24 24       	movzwl (%r12),%r12d
 12742c0:	45 20 fd             	and    %r15b,%r13b
 12742c3:	41 f6 c5 01          	test   $0x1,%r13b
 12742c7:	66 44 89 64 24 1e    	mov    %r12w,0x1e(%rsp)
 12742cd:	74 75                	je     1274344 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x834>
 12742cf:	45 89 dd             	mov    %r11d,%r13d
 12742d2:	48 8d bc 24 30 10 00 	lea    0x1030(%rsp),%rdi
 12742d9:	00 
 12742da:	4c 89 f6             	mov    %r14,%rsi
 12742dd:	48 8b 94 24 c8 00 00 	mov    0xc8(%rsp),%rdx
 12742e4:	00 
 12742e5:	48 8b 8c 24 a8 00 00 	mov    0xa8(%rsp),%rcx
 12742ec:	00 
 12742ed:	4c 8b 84 24 b0 00 00 	mov    0xb0(%rsp),%r8
 12742f4:	00 
 12742f5:	4c 8b 4d 10          	mov    0x10(%rbp),%r9
 12742f9:	c5 f8 77             	vzeroupper 
 12742fc:	e8 2f 07 ff ff       	call   1264a30 <br.encoder.literal_context_split.chooseProposals>
 1274301:	0f b7 9c 24 38 11 00 	movzwl 0x1138(%rsp),%ebx
 1274308:	00 
 1274309:	48 85 db             	test   %rbx,%rbx
 127430c:	0f 85 a4 19 00 00    	jne    1275cb6 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x21a6>
 1274312:	4c 8d a4 24 80 0f 00 	lea    0xf80(%rsp),%r12
 1274319:	00 
 127431a:	4c 8d b4 24 d8 0f 00 	lea    0xfd8(%rsp),%r14
 1274321:	00 
 1274322:	48 8d 9c 24 28 0f 00 	lea    0xf28(%rsp),%rbx
 1274329:	00 
 127432a:	48 8d b4 24 30 10 00 	lea    0x1030(%rsp),%rsi
 1274331:	00 
 1274332:	ba 08 01 00 00       	mov    $0x108,%edx
 1274337:	48 89 df             	mov    %rbx,%rdi
 127433a:	e8 21 b4 06 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 127433f:	45 89 eb             	mov    %r13d,%r11d
 1274342:	eb 11                	jmp    1274355 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x845>
 1274344:	bb 30 37 09 01       	mov    $0x1093730,%ebx
 1274349:	41 be e0 37 09 01    	mov    $0x10937e0,%r14d
 127434f:	41 bc 88 37 09 01    	mov    $0x1093788,%r12d
 1274355:	b8 38 38 09 01       	mov    $0x1093838,%eax
 127435a:	48 89 84 24 a0 00 00 	mov    %rax,0xa0(%rsp)
 1274361:	00 
 1274362:	41 f6 c7 01          	test   $0x1,%r15b
 1274366:	c5 fd 6f a4 24 20 01 	vmovdqa 0x120(%rsp),%ymm4
 127436d:	00 00 
 127436f:	c5 fd 6f ac 24 00 01 	vmovdqa 0x100(%rsp),%ymm5
 1274376:	00 00 
 1274378:	0f 84 94 00 00 00    	je     1274412 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x902>
 127437e:	c5 fc 10 03          	vmovups (%rbx),%ymm0
 1274382:	c5 fc 10 4b 38       	vmovups 0x38(%rbx),%ymm1
 1274387:	c5 fc 11 8c 24 58 0e 	vmovups %ymm1,0xe58(%rsp)
 127438e:	00 00 
 1274390:	c5 fc 10 4b 20       	vmovups 0x20(%rbx),%ymm1
 1274395:	c5 fc 11 8c 24 40 0e 	vmovups %ymm1,0xe40(%rsp)
 127439c:	00 00 
 127439e:	c5 fc 11 84 24 20 0e 	vmovups %ymm0,0xe20(%rsp)
 12743a5:	00 00 
 12743a7:	c4 c1 7c 10 04 24    	vmovups (%r12),%ymm0
 12743ad:	c4 c1 7c 10 4c 24 20 	vmovups 0x20(%r12),%ymm1
 12743b4:	c4 c1 7c 10 54 24 38 	vmovups 0x38(%r12),%ymm2
 12743bb:	c5 fc 11 84 24 78 0e 	vmovups %ymm0,0xe78(%rsp)
 12743c2:	00 00 
 12743c4:	c5 fc 11 8c 24 98 0e 	vmovups %ymm1,0xe98(%rsp)
 12743cb:	00 00 
 12743cd:	c5 fc 11 94 24 b0 0e 	vmovups %ymm2,0xeb0(%rsp)
 12743d4:	00 00 
 12743d6:	c4 c1 7c 10 06       	vmovups (%r14),%ymm0
 12743db:	c4 c1 7c 10 4e 20    	vmovups 0x20(%r14),%ymm1
 12743e1:	c5 fc 11 84 24 d0 0e 	vmovups %ymm0,0xed0(%rsp)
 12743e8:	00 00 
 12743ea:	c4 c1 7e 6f 46 38    	vmovdqu 0x38(%r14),%ymm0
 12743f0:	c5 fc 11 8c 24 f0 0e 	vmovups %ymm1,0xef0(%rsp)
 12743f7:	00 00 
 12743f9:	c5 fe 7f 84 24 08 0f 	vmovdqu %ymm0,0xf08(%rsp)
 1274400:	00 00 
 1274402:	48 8d 84 24 20 0e 00 	lea    0xe20(%rsp),%rax
 1274409:	00 
 127440a:	48 89 84 24 a0 00 00 	mov    %rax,0xa0(%rsp)
 1274411:	00 
 1274412:	45 31 e4             	xor    %r12d,%r12d
 1274415:	48 c7 84 24 c0 00 00 	movq   $0x0,0xc0(%rsp)
 127441c:	00 00 00 00 00 
 1274421:	45 31 d2             	xor    %r10d,%r10d
 1274424:	48 8b 9c 24 a0 00 00 	mov    0xa0(%rsp),%rbx
 127442b:	00 
 127442c:	e9 b5 00 00 00       	jmp    12744e6 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x9d6>
 1274431:	4c 8b 94 24 b8 00 00 	mov    0xb8(%rsp),%r10
 1274438:	00 
 1274439:	49 83 fa 02          	cmp    $0x2,%r10
 127443d:	0f b6 54 24 0f       	movzbl 0xf(%rsp),%edx
 1274442:	0f 87 0f 12 00 00    	ja     1275657 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1b47>
 1274448:	4c 89 64 24 10       	mov    %r12,0x10(%rsp)
 127444d:	4b 8d 04 92          	lea    (%r10,%r10,4),%rax
 1274451:	48 c1 e0 04          	shl    $0x4,%rax
 1274455:	48 8b 4c 24 48       	mov    0x48(%rsp),%rcx
 127445a:	48 89 8c 04 18 03 00 	mov    %rcx,0x318(%rsp,%rax,1)
 1274461:	00 
 1274462:	44 88 ac 04 20 03 00 	mov    %r13b,0x320(%rsp,%rax,1)
 1274469:	00 
 127446a:	88 94 04 21 03 00 00 	mov    %dl,0x321(%rsp,%rax,1)
 1274471:	c5 fc 28 84 24 e0 01 	vmovaps 0x1e0(%rsp),%ymm0
 1274478:	00 00 
 127447a:	c5 fc 11 84 04 22 03 	vmovups %ymm0,0x322(%rsp,%rax,1)
 1274481:	00 00 
 1274483:	c5 fd 6f 84 24 c0 01 	vmovdqa 0x1c0(%rsp),%ymm0
 127448a:	00 00 
 127448c:	c5 fe 7f 84 04 42 03 	vmovdqu %ymm0,0x342(%rsp,%rax,1)
 1274493:	00 00 
 1274495:	8b 4c 24 70          	mov    0x70(%rsp),%ecx
 1274499:	89 8c 04 62 03 00 00 	mov    %ecx,0x362(%rsp,%rax,1)
 12744a0:	0f b7 4c 24 74       	movzwl 0x74(%rsp),%ecx
 12744a5:	66 89 8c 04 66 03 00 	mov    %cx,0x366(%rsp,%rax,1)
 12744ac:	00 
 12744ad:	49 ff c2             	inc    %r10
 12744b0:	44 0f b6 5c 24 07    	movzbl 0x7(%rsp),%r11d
 12744b6:	48 8b 9c 24 a0 00 00 	mov    0xa0(%rsp),%rbx
 12744bd:	00 
 12744be:	4c 8b a4 24 f0 00 00 	mov    0xf0(%rsp),%r12
 12744c5:	00 
 12744c6:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 12744cd:	00 00 00 
 12744d0:	4d 85 e4             	test   %r12,%r12
 12744d3:	0f 84 a7 00 00 00    	je     1274580 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xa70>
 12744d9:	49 ff c4             	inc    %r12
 12744dc:	49 83 fc 03          	cmp    $0x3,%r12
 12744e0:	0f 84 46 0a 00 00    	je     1274f2c <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x141c>
 12744e6:	49 6b c4 58          	imul   $0x58,%r12,%rax
 12744ea:	80 7c 03 50 00       	cmpb   $0x0,0x50(%rbx,%rax,1)
 12744ef:	74 df                	je     12744d0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x9c0>
 12744f1:	48 8b 0c 03          	mov    (%rbx,%rax,1),%rcx
 12744f5:	48 89 4c 24 48       	mov    %rcx,0x48(%rsp)
 12744fa:	44 0f b6 6c 03 08    	movzbl 0x8(%rbx,%rax,1),%r13d
 1274500:	44 0f b6 74 03 09    	movzbl 0x9(%rbx,%rax,1),%r14d
 1274506:	c5 fe 6f 74 03 0a    	vmovdqu 0xa(%rbx,%rax,1),%ymm6
 127450c:	c5 fe 6f 7c 03 2a    	vmovdqu 0x2a(%rbx,%rax,1),%ymm7
 1274512:	48 8d 44 03 4a       	lea    0x4a(%rbx,%rax,1),%rax
 1274517:	0f b7 48 04          	movzwl 0x4(%rax),%ecx
 127451b:	66 89 4c 24 74       	mov    %cx,0x74(%rsp)
 1274520:	8b 08                	mov    (%rax),%ecx
 1274522:	89 4c 24 70          	mov    %ecx,0x70(%rsp)
 1274526:	80 7c 24 38 00       	cmpb   $0x0,0x38(%rsp)
 127452b:	0f 84 9f 00 00 00    	je     12745d0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xac0>
 1274531:	44 89 ea             	mov    %r13d,%edx
 1274534:	80 e2 03             	and    $0x3,%dl
 1274537:	0f b6 74 24 30       	movzbl 0x30(%rsp),%esi
 127453c:	40 80 e6 03          	and    $0x3,%sil
 1274540:	31 c9                	xor    %ecx,%ecx
 1274542:	40 38 f2             	cmp    %sil,%dl
 1274545:	75 2c                	jne    1274573 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xa63>
 1274547:	44 89 da             	mov    %r11d,%edx
 127454a:	80 e2 7f             	and    $0x7f,%dl
 127454d:	44 89 f6             	mov    %r14d,%esi
 1274550:	40 80 e6 7f          	and    $0x7f,%sil
 1274554:	40 38 d6             	cmp    %dl,%sil
 1274557:	75 1a                	jne    1274573 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xa63>
 1274559:	c5 cd 74 c5          	vpcmpeqb %ymm5,%ymm6,%ymm0
 127455d:	c5 fd d7 d0          	vpmovmskb %ymm0,%edx
 1274561:	f7 d2                	not    %edx
 1274563:	85 d2                	test   %edx,%edx
 1274565:	75 0c                	jne    1274573 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xa63>
 1274567:	c5 c5 ef c4          	vpxor  %ymm4,%ymm7,%ymm0
 127456b:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 1274570:	0f 94 c1             	sete   %cl
 1274573:	4d 85 d2             	test   %r10,%r10
 1274576:	75 5f                	jne    12745d7 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xac7>
 1274578:	eb 7f                	jmp    12745f9 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xae9>
 127457a:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 1274580:	0f b7 44 24 24       	movzwl 0x24(%rsp),%eax
 1274585:	66 89 84 24 90 00 00 	mov    %ax,0x90(%rsp)
 127458c:	00 
 127458d:	8b 44 24 20          	mov    0x20(%rsp),%eax
 1274591:	89 84 24 8c 00 00 00 	mov    %eax,0x8c(%rsp)
 1274598:	80 7c 24 38 00       	cmpb   $0x0,0x38(%rsp)
 127459d:	0f 84 b7 06 00 00    	je     1274c5a <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x114a>
 12745a3:	48 8b 74 24 10       	mov    0x10(%rsp),%rsi
 12745a8:	4c 8b 74 24 40       	mov    0x40(%rsp),%r14
 12745ad:	48 8b 44 24 60       	mov    0x60(%rsp),%rax
 12745b2:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 12745b7:	44 0f b6 6c 24 30    	movzbl 0x30(%rsp),%r13d
 12745bd:	e9 1f 07 00 00       	jmp    1274ce1 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x11d1>
 12745c2:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 12745c9:	1f 84 00 00 00 00 00 
 12745d0:	31 c9                	xor    %ecx,%ecx
 12745d2:	4d 85 d2             	test   %r10,%r10
 12745d5:	74 22                	je     12745f9 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xae9>
 12745d7:	45 89 df             	mov    %r11d,%r15d
 12745da:	49 83 fa 01          	cmp    $0x1,%r10
 12745de:	0f 85 6a 04 00 00    	jne    1274a4e <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xf3e>
 12745e4:	4d 89 d3             	mov    %r10,%r11
 12745e7:	31 d2                	xor    %edx,%edx
 12745e9:	4d 89 da             	mov    %r11,%r10
 12745ec:	41 f6 c2 01          	test   $0x1,%r10b
 12745f0:	45 89 fb             	mov    %r15d,%r11d
 12745f3:	0f 85 40 05 00 00    	jne    1274b39 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1029>
 12745f9:	f6 c1 01             	test   $0x1,%cl
 12745fc:	0f 85 ce fe ff ff    	jne    12744d0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x9c0>
 1274602:	4c 89 a4 24 f0 00 00 	mov    %r12,0xf0(%rsp)
 1274609:	00 
 127460a:	44 88 5c 24 07       	mov    %r11b,0x7(%rsp)
 127460f:	c5 fd 7f ac 24 00 01 	vmovdqa %ymm5,0x100(%rsp)
 1274616:	00 00 
 1274618:	c5 fd 7f a4 24 20 01 	vmovdqa %ymm4,0x120(%rsp)
 127461f:	00 00 
 1274621:	4c 89 94 24 b8 00 00 	mov    %r10,0xb8(%rsp)
 1274628:	00 
 1274629:	4c 8b 64 24 40       	mov    0x40(%rsp),%r12
 127462e:	c5 fc 10 84 24 40 05 	vmovups 0x540(%rsp),%ymm0
 1274635:	00 00 
 1274637:	c5 fc 11 84 24 d0 06 	vmovups %ymm0,0x6d0(%rsp)
 127463e:	00 00 
 1274640:	c5 fc 10 84 24 d0 04 	vmovups 0x4d0(%rsp),%ymm0
 1274647:	00 00 
 1274649:	c5 fc 10 8c 24 f0 04 	vmovups 0x4f0(%rsp),%ymm1
 1274650:	00 00 
 1274652:	c5 fc 10 94 24 10 05 	vmovups 0x510(%rsp),%ymm2
 1274659:	00 00 
 127465b:	c5 fc 10 9c 24 30 05 	vmovups 0x530(%rsp),%ymm3
 1274662:	00 00 
 1274664:	c5 fc 11 9c 24 c0 06 	vmovups %ymm3,0x6c0(%rsp)
 127466b:	00 00 
 127466d:	c5 fc 11 94 24 a0 06 	vmovups %ymm2,0x6a0(%rsp)
 1274674:	00 00 
 1274676:	c5 fc 11 8c 24 80 06 	vmovups %ymm1,0x680(%rsp)
 127467d:	00 00 
 127467f:	c5 fc 11 84 24 60 06 	vmovups %ymm0,0x660(%rsp)
 1274686:	00 00 
 1274688:	0f b6 4c 24 08       	movzbl 0x8(%rsp),%ecx
 127468d:	c5 fe 6f 84 24 50 04 	vmovdqu 0x450(%rsp),%ymm0
 1274694:	00 00 
 1274696:	48 8d b4 24 82 0c 00 	lea    0xc82(%rsp),%rsi
 127469d:	00 
 127469e:	c5 fe 7f 46 96       	vmovdqu %ymm0,-0x6a(%rsi)
 12746a3:	0f b7 50 04          	movzwl 0x4(%rax),%edx
 12746a7:	66 89 56 04          	mov    %dx,0x4(%rsi)
 12746ab:	8b 00                	mov    (%rax),%eax
 12746ad:	89 06                	mov    %eax,(%rsi)
 12746af:	88 8c 24 19 0e 00 00 	mov    %cl,0xe19(%rsp)
 12746b6:	48 c7 84 24 08 0c 00 	movq   $0x0,0xc08(%rsp)
 12746bd:	00 00 00 00 00 
 12746c2:	8b 44 24 28          	mov    0x28(%rsp),%eax
 12746c6:	88 84 24 1d 0e 00 00 	mov    %al,0xe1d(%rsp)
 12746cd:	c6 84 24 1c 0e 00 00 	movb   $0x0,0xe1c(%rsp)
 12746d4:	00 
 12746d5:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 12746da:	48 89 84 24 38 0c 00 	mov    %rax,0xc38(%rsp)
 12746e1:	00 
 12746e2:	44 88 ac 24 40 0c 00 	mov    %r13b,0xc40(%rsp)
 12746e9:	00 
 12746ea:	44 88 74 24 0f       	mov    %r14b,0xf(%rsp)
 12746ef:	44 88 b4 24 41 0c 00 	mov    %r14b,0xc41(%rsp)
 12746f6:	00 
 12746f7:	c5 fd 7f b4 24 e0 01 	vmovdqa %ymm6,0x1e0(%rsp)
 12746fe:	00 00 
 1274700:	c5 fe 7f b4 24 42 0c 	vmovdqu %ymm6,0xc42(%rsp)
 1274707:	00 00 
 1274709:	c5 fd 7f bc 24 c0 01 	vmovdqa %ymm7,0x1c0(%rsp)
 1274710:	00 00 
 1274712:	c5 fe 7f bc 24 62 0c 	vmovdqu %ymm7,0xc62(%rsp)
 1274719:	00 00 
 127471b:	c6 84 24 88 0c 00 00 	movb   $0x1,0xc88(%rsp)
 1274722:	01 
 1274723:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 1274727:	c5 fe 7f 86 5e 01 00 	vmovdqu %ymm0,0x15e(%rsi)
 127472e:	00 
 127472f:	c5 fe 7f 86 4e 01 00 	vmovdqu %ymm0,0x14e(%rsi)
 1274736:	00 
 1274737:	c5 fe 7f 86 2e 01 00 	vmovdqu %ymm0,0x12e(%rsi)
 127473e:	00 
 127473f:	c5 fe 7f 86 0e 01 00 	vmovdqu %ymm0,0x10e(%rsi)
 1274746:	00 
 1274747:	c5 fe 7f 86 ee 00 00 	vmovdqu %ymm0,0xee(%rsi)
 127474e:	00 
 127474f:	c5 fe 7f 86 ce 00 00 	vmovdqu %ymm0,0xce(%rsi)
 1274756:	00 
 1274757:	c5 fe 7f 86 ae 00 00 	vmovdqu %ymm0,0xae(%rsi)
 127475e:	00 
 127475f:	c5 fe 7f 86 8e 00 00 	vmovdqu %ymm0,0x8e(%rsi)
 1274766:	00 
 1274767:	c5 fe 7f 46 6e       	vmovdqu %ymm0,0x6e(%rsi)
 127476c:	c5 fe 7f 46 4e       	vmovdqu %ymm0,0x4e(%rsi)
 1274771:	c5 fe 7f 46 2e       	vmovdqu %ymm0,0x2e(%rsi)
 1274776:	c5 fe 7f 46 0e       	vmovdqu %ymm0,0xe(%rsi)
 127477b:	c6 84 24 10 0e 00 00 	movb   $0x38,0xe10(%rsp)
 1274782:	38 
 1274783:	c6 84 24 18 0e 00 00 	movb   $0x0,0xe18(%rsp)
 127478a:	00 
 127478b:	0f b7 05 9e 67 dc ff 	movzwl -0x239862(%rip),%eax        # 103af30 <__anon_29470>
 1274792:	66 89 84 24 12 0e 00 	mov    %ax,0xe12(%rsp)
 1274799:	00 
 127479a:	0f b6 44 24 06       	movzbl 0x6(%rsp),%eax
 127479f:	88 84 24 11 0e 00 00 	mov    %al,0xe11(%rsp)
 12747a6:	48 8b 84 24 e8 00 00 	mov    0xe8(%rsp),%rax
 12747ad:	00 
 12747ae:	48 89 84 24 f8 0b 00 	mov    %rax,0xbf8(%rsp)
 12747b5:	00 
 12747b6:	48 8b 84 24 e0 00 00 	mov    0xe0(%rsp),%rax
 12747bd:	00 
 12747be:	48 89 84 24 00 0c 00 	mov    %rax,0xc00(%rsp)
 12747c5:	00 
 12747c6:	c7 84 24 14 0e 00 00 	movl   $0x1000101,0xe14(%rsp)
 12747cd:	01 01 00 01 
 12747d1:	48 8b 84 24 d8 00 00 	mov    0xd8(%rsp),%rax
 12747d8:	00 
 12747d9:	48 89 84 24 08 0e 00 	mov    %rax,0xe08(%rsp)
 12747e0:	00 
 12747e1:	48 8b 84 24 d0 00 00 	mov    0xd0(%rsp),%rax
 12747e8:	00 
 12747e9:	48 89 84 24 00 0e 00 	mov    %rax,0xe00(%rsp)
 12747f0:	00 
 12747f1:	66 c7 84 24 1a 0e 00 	movw   $0x0,0xe1a(%rsp)
 12747f8:	00 00 00 
 12747fb:	48 c7 84 24 10 0c 00 	movq   $0x0,0xc10(%rsp)
 1274802:	00 00 00 00 00 
 1274807:	48 83 ec 08          	sub    $0x8,%rsp
 127480b:	48 8d bc 24 28 04 00 	lea    0x428(%rsp),%rdi
 1274812:	00 
 1274813:	4c 8b b4 24 a0 00 00 	mov    0xa0(%rsp),%r14
 127481a:	00 
 127481b:	4c 89 f6             	mov    %r14,%rsi
 127481e:	4c 8b bc 24 88 00 00 	mov    0x88(%rsp),%r15
 1274825:	00 
 1274826:	4c 89 fa             	mov    %r15,%rdx
 1274829:	48 8b 8c 24 d0 00 00 	mov    0xd0(%rsp),%rcx
 1274830:	00 
 1274831:	4c 8b 84 24 b0 00 00 	mov    0xb0(%rsp),%r8
 1274838:	00 
 1274839:	4c 8b 8c 24 b8 00 00 	mov    0xb8(%rsp),%r9
 1274840:	00 
 1274841:	48 8d 84 24 00 0c 00 	lea    0xc00(%rsp),%rax
 1274848:	00 
 1274849:	50                   	push   %rax
 127484a:	48 8d 84 24 70 06 00 	lea    0x670(%rsp),%rax
 1274851:	00 
 1274852:	50                   	push   %rax
 1274853:	ff 75 10             	push   0x10(%rbp)
 1274856:	c5 f8 77             	vzeroupper 
 1274859:	e8 d2 a2 fb ff       	call   122eb30 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509>
 127485e:	48 83 c4 20          	add    $0x20,%rsp
 1274862:	0f b7 9c 24 30 04 00 	movzwl 0x430(%rsp),%ebx
 1274869:	00 
 127486a:	48 85 db             	test   %rbx,%rbx
 127486d:	0f 85 52 13 00 00    	jne    1275bc5 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x20b5>
 1274873:	48 8b b4 24 20 04 00 	mov    0x420(%rsp),%rsi
 127487a:	00 
 127487b:	48 8b 94 24 28 04 00 	mov    0x428(%rsp),%rdx
 1274882:	00 
 1274883:	48 8d bc 24 60 05 00 	lea    0x560(%rsp),%rdi
 127488a:	00 
 127488b:	48 89 74 24 68       	mov    %rsi,0x68(%rsp)
 1274890:	48 89 d3             	mov    %rdx,%rbx
 1274893:	48 8b 4c 24 10       	mov    0x10(%rsp),%rcx
 1274898:	4d 89 e0             	mov    %r12,%r8
 127489b:	e8 40 97 fc ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 12748a0:	49 8b 4e 10          	mov    0x10(%r14),%rcx
 12748a4:	49 8b 3f             	mov    (%r15),%rdi
 12748a7:	4d 8b 4f 08          	mov    0x8(%r15),%r9
 12748ab:	4c 8d 79 20          	lea    0x20(%rcx),%r15
 12748af:	4c 8b b1 20 30 02 00 	mov    0x23020(%rcx),%r14
 12748b6:	a8 01                	test   $0x1,%al
 12748b8:	0f 84 f8 02 00 00    	je     1274bb6 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x10a6>
 12748be:	4d 85 f6             	test   %r14,%r14
 12748c1:	48 8b 74 24 10       	mov    0x10(%rsp),%rsi
 12748c6:	c5 fd 6f ac 24 e0 01 	vmovdqa 0x1e0(%rsp),%ymm5
 12748cd:	00 00 
 12748cf:	c5 fd 6f a4 24 c0 01 	vmovdqa 0x1c0(%rsp),%ymm4
 12748d6:	00 00 
 12748d8:	74 4e                	je     1274928 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xe18>
 12748da:	49 83 fe 01          	cmp    $0x1,%r14
 12748de:	0f 85 00 05 00 00    	jne    1274de4 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x12d4>
 12748e4:	31 c0                	xor    %eax,%eax
 12748e6:	41 f6 c6 01          	test   $0x1,%r14b
 12748ea:	74 3c                	je     1274928 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xe18>
 12748ec:	4c 69 d0 18 01 00 00 	imul   $0x118,%rax,%r10
 12748f3:	47 0f b6 84 17 10 01 	movzbl 0x110(%r15,%r10,1),%r8d
 12748fa:	00 00 
 12748fc:	41 80 e0 0f          	and    $0xf,%r8b
 1274900:	41 80 f8 07          	cmp    $0x7,%r8b
 1274904:	75 22                	jne    1274928 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xe18>
 1274906:	4d 01 d7             	add    %r10,%r15
 1274909:	41 80 7f 40 00       	cmpb   $0x0,0x40(%r15)
 127490e:	74 18                	je     1274928 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xe18>
 1274910:	4d 39 67 38          	cmp    %r12,0x38(%r15)
 1274914:	75 12                	jne    1274928 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xe18>
 1274916:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 127491d:	00 
 127491e:	75 08                	jne    1274928 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xe18>
 1274920:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1274927:	00 
 1274928:	4d 85 e4             	test   %r12,%r12
 127492b:	74 22                	je     127494f <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xe3f>
 127492d:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1274931:	4c 89 e2             	mov    %r12,%rdx
 1274934:	31 c9                	xor    %ecx,%ecx
 1274936:	c5 f8 77             	vzeroupper 
 1274939:	41 ff 51 18          	call   *0x18(%r9)
 127493d:	c5 fd 6f a4 24 c0 01 	vmovdqa 0x1c0(%rsp),%ymm4
 1274944:	00 00 
 1274946:	c5 fd 6f ac 24 e0 01 	vmovdqa 0x1e0(%rsp),%ymm5
 127494d:	00 00 
 127494f:	c5 fc 10 84 24 d0 06 	vmovups 0x6d0(%rsp),%ymm0
 1274956:	00 00 
 1274958:	c5 fc 11 84 24 f0 02 	vmovups %ymm0,0x2f0(%rsp)
 127495f:	00 00 
 1274961:	c5 fe 6f 84 24 60 06 	vmovdqu 0x660(%rsp),%ymm0
 1274968:	00 00 
 127496a:	c5 fc 10 8c 24 80 06 	vmovups 0x680(%rsp),%ymm1
 1274971:	00 00 
 1274973:	c5 fc 10 94 24 a0 06 	vmovups 0x6a0(%rsp),%ymm2
 127497a:	00 00 
 127497c:	c5 fc 10 9c 24 c0 06 	vmovups 0x6c0(%rsp),%ymm3
 1274983:	00 00 
 1274985:	c5 fc 11 9c 24 e0 02 	vmovups %ymm3,0x2e0(%rsp)
 127498c:	00 00 
 127498e:	c5 fc 11 94 24 c0 02 	vmovups %ymm2,0x2c0(%rsp)
 1274995:	00 00 
 1274997:	c5 fc 11 8c 24 a0 02 	vmovups %ymm1,0x2a0(%rsp)
 127499e:	00 00 
 12749a0:	c5 fe 7f 84 24 80 02 	vmovdqu %ymm0,0x280(%rsp)
 12749a7:	00 00 
 12749a9:	80 7c 24 38 00       	cmpb   $0x0,0x38(%rsp)
 12749ae:	b0 01                	mov    $0x1,%al
 12749b0:	89 44 24 38          	mov    %eax,0x38(%rsp)
 12749b4:	4c 8b 94 24 b8 00 00 	mov    0xb8(%rsp),%r10
 12749bb:	00 
 12749bc:	44 0f b6 5c 24 0f    	movzbl 0xf(%rsp),%r11d
 12749c2:	0f 84 a4 02 00 00    	je     1274c6c <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x115c>
 12749c8:	49 83 fa 03          	cmp    $0x3,%r10
 12749cc:	4c 8b a4 24 f0 00 00 	mov    0xf0(%rsp),%r12
 12749d3:	00 
 12749d4:	0f 83 10 0d 00 00    	jae    12756ea <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1bda>
 12749da:	49 89 de             	mov    %rbx,%r14
 12749dd:	4b 8d 04 92          	lea    (%r10,%r10,4),%rax
 12749e1:	48 c1 e0 04          	shl    $0x4,%rax
 12749e5:	48 8b 4c 24 60       	mov    0x60(%rsp),%rcx
 12749ea:	48 89 8c 04 18 03 00 	mov    %rcx,0x318(%rsp,%rax,1)
 12749f1:	00 
 12749f2:	0f b6 4c 24 30       	movzbl 0x30(%rsp),%ecx
 12749f7:	88 8c 04 20 03 00 00 	mov    %cl,0x320(%rsp,%rax,1)
 12749fe:	0f b6 4c 24 07       	movzbl 0x7(%rsp),%ecx
 1274a03:	88 8c 04 21 03 00 00 	mov    %cl,0x321(%rsp,%rax,1)
 1274a0a:	c5 fc 28 84 24 00 01 	vmovaps 0x100(%rsp),%ymm0
 1274a11:	00 00 
 1274a13:	c5 fc 11 84 04 22 03 	vmovups %ymm0,0x322(%rsp,%rax,1)
 1274a1a:	00 00 
 1274a1c:	c5 fd 6f 84 24 20 01 	vmovdqa 0x120(%rsp),%ymm0
 1274a23:	00 00 
 1274a25:	c5 fe 7f 84 04 42 03 	vmovdqu %ymm0,0x342(%rsp,%rax,1)
 1274a2c:	00 00 
 1274a2e:	8b 4c 24 20          	mov    0x20(%rsp),%ecx
 1274a32:	89 8c 04 62 03 00 00 	mov    %ecx,0x362(%rsp,%rax,1)
 1274a39:	0f b7 4c 24 24       	movzwl 0x24(%rsp),%ecx
 1274a3e:	66 89 8c 04 66 03 00 	mov    %cx,0x366(%rsp,%rax,1)
 1274a45:	00 
 1274a46:	49 ff c2             	inc    %r10
 1274a49:	e9 33 02 00 00       	jmp    1274c81 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1171>
 1274a4e:	4d 89 d3             	mov    %r10,%r11
 1274a51:	4c 89 d6             	mov    %r10,%rsi
 1274a54:	48 83 e6 fe          	and    $0xfffffffffffffffe,%rsi
 1274a58:	48 8d bc 24 20 03 00 	lea    0x320(%rsp),%rdi
 1274a5f:	00 
 1274a60:	31 d2                	xor    %edx,%edx
 1274a62:	eb 20                	jmp    1274a84 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xf74>
 1274a64:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1274a6b:	00 00 00 00 00 
 1274a70:	48 83 c2 02          	add    $0x2,%rdx
 1274a74:	48 81 c7 a0 00 00 00 	add    $0xa0,%rdi
 1274a7b:	48 39 d6             	cmp    %rdx,%rsi
 1274a7e:	0f 84 65 fb ff ff    	je     12745e9 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xad9>
 1274a84:	41 b0 01             	mov    $0x1,%r8b
 1274a87:	f6 c1 01             	test   $0x1,%cl
 1274a8a:	b1 01                	mov    $0x1,%cl
 1274a8c:	75 4b                	jne    1274ad9 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xfc9>
 1274a8e:	45 89 e9             	mov    %r13d,%r9d
 1274a91:	41 80 e1 03          	and    $0x3,%r9b
 1274a95:	44 0f b6 17          	movzbl (%rdi),%r10d
 1274a99:	41 80 e2 03          	and    $0x3,%r10b
 1274a9d:	45 31 c0             	xor    %r8d,%r8d
 1274aa0:	45 38 d1             	cmp    %r10b,%r9b
 1274aa3:	75 34                	jne    1274ad9 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xfc9>
 1274aa5:	44 0f b6 4f 01       	movzbl 0x1(%rdi),%r9d
 1274aaa:	41 80 e1 7f          	and    $0x7f,%r9b
 1274aae:	45 89 f2             	mov    %r14d,%r10d
 1274ab1:	41 80 e2 7f          	and    $0x7f,%r10b
 1274ab5:	45 38 ca             	cmp    %r9b,%r10b
 1274ab8:	75 1f                	jne    1274ad9 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xfc9>
 1274aba:	c5 cd 74 47 02       	vpcmpeqb 0x2(%rdi),%ymm6,%ymm0
 1274abf:	c5 7d d7 c8          	vpmovmskb %ymm0,%r9d
 1274ac3:	41 f7 d1             	not    %r9d
 1274ac6:	45 85 c9             	test   %r9d,%r9d
 1274ac9:	75 0e                	jne    1274ad9 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xfc9>
 1274acb:	c5 c5 ef 47 22       	vpxor  0x22(%rdi),%ymm7,%ymm0
 1274ad0:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 1274ad5:	41 0f 94 c0          	sete   %r8b
 1274ad9:	45 84 c0             	test   %r8b,%r8b
 1274adc:	75 92                	jne    1274a70 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xf60>
 1274ade:	45 89 e8             	mov    %r13d,%r8d
 1274ae1:	41 80 e0 03          	and    $0x3,%r8b
 1274ae5:	44 0f b6 4f 50       	movzbl 0x50(%rdi),%r9d
 1274aea:	41 80 e1 03          	and    $0x3,%r9b
 1274aee:	31 c9                	xor    %ecx,%ecx
 1274af0:	45 38 c8             	cmp    %r9b,%r8b
 1274af3:	0f 85 77 ff ff ff    	jne    1274a70 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xf60>
 1274af9:	44 0f b6 47 51       	movzbl 0x51(%rdi),%r8d
 1274afe:	41 80 e0 7f          	and    $0x7f,%r8b
 1274b02:	45 89 f1             	mov    %r14d,%r9d
 1274b05:	41 80 e1 7f          	and    $0x7f,%r9b
 1274b09:	45 38 c1             	cmp    %r8b,%r9b
 1274b0c:	0f 85 5e ff ff ff    	jne    1274a70 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xf60>
 1274b12:	c5 cd 74 47 52       	vpcmpeqb 0x52(%rdi),%ymm6,%ymm0
 1274b17:	c5 7d d7 c0          	vpmovmskb %ymm0,%r8d
 1274b1b:	41 f7 d0             	not    %r8d
 1274b1e:	45 85 c0             	test   %r8d,%r8d
 1274b21:	0f 85 49 ff ff ff    	jne    1274a70 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xf60>
 1274b27:	c5 c5 ef 47 72       	vpxor  0x72(%rdi),%ymm7,%ymm0
 1274b2c:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 1274b31:	0f 94 c1             	sete   %cl
 1274b34:	e9 37 ff ff ff       	jmp    1274a70 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xf60>
 1274b39:	84 c9                	test   %cl,%cl
 1274b3b:	0f 85 8f f9 ff ff    	jne    12744d0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x9c0>
 1274b41:	48 8d 0c 92          	lea    (%rdx,%rdx,4),%rcx
 1274b45:	48 c1 e1 04          	shl    $0x4,%rcx
 1274b49:	48 8d 14 0c          	lea    (%rsp,%rcx,1),%rdx
 1274b4d:	48 81 c2 18 03 00 00 	add    $0x318,%rdx
 1274b54:	44 89 ee             	mov    %r13d,%esi
 1274b57:	40 80 e6 03          	and    $0x3,%sil
 1274b5b:	0f b6 7a 08          	movzbl 0x8(%rdx),%edi
 1274b5f:	40 80 e7 03          	and    $0x3,%dil
 1274b63:	40 38 fe             	cmp    %dil,%sil
 1274b66:	0f 85 96 fa ff ff    	jne    1274602 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xaf2>
 1274b6c:	0f b6 72 09          	movzbl 0x9(%rdx),%esi
 1274b70:	40 80 e6 7f          	and    $0x7f,%sil
 1274b74:	44 89 f7             	mov    %r14d,%edi
 1274b77:	40 80 e7 7f          	and    $0x7f,%dil
 1274b7b:	40 38 f7             	cmp    %sil,%dil
 1274b7e:	0f 85 7e fa ff ff    	jne    1274602 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xaf2>
 1274b84:	c5 cd 74 42 0a       	vpcmpeqb 0xa(%rdx),%ymm6,%ymm0
 1274b89:	c5 fd d7 d0          	vpmovmskb %ymm0,%edx
 1274b8d:	f7 d2                	not    %edx
 1274b8f:	85 d2                	test   %edx,%edx
 1274b91:	0f 85 6b fa ff ff    	jne    1274602 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xaf2>
 1274b97:	c5 c5 ef 84 0c 42 03 	vpxor  0x342(%rsp,%rcx,1),%ymm7,%ymm0
 1274b9e:	00 00 
 1274ba0:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 1274ba5:	0f 94 c1             	sete   %cl
 1274ba8:	f6 c1 01             	test   $0x1,%cl
 1274bab:	0f 84 51 fa ff ff    	je     1274602 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xaf2>
 1274bb1:	e9 1a f9 ff ff       	jmp    12744d0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x9c0>
 1274bb6:	4d 85 f6             	test   %r14,%r14
 1274bb9:	4c 89 64 24 40       	mov    %r12,0x40(%rsp)
 1274bbe:	4c 8b 64 24 10       	mov    0x10(%rsp),%r12
 1274bc3:	c5 fd 6f a4 24 20 01 	vmovdqa 0x120(%rsp),%ymm4
 1274bca:	00 00 
 1274bcc:	c5 fd 6f ac 24 00 01 	vmovdqa 0x100(%rsp),%ymm5
 1274bd3:	00 00 
 1274bd5:	48 8b 74 24 68       	mov    0x68(%rsp),%rsi
 1274bda:	74 4e                	je     1274c2a <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x111a>
 1274bdc:	49 83 fe 01          	cmp    $0x1,%r14
 1274be0:	0f 85 a6 02 00 00    	jne    1274e8c <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x137c>
 1274be6:	31 c0                	xor    %eax,%eax
 1274be8:	41 f6 c6 01          	test   $0x1,%r14b
 1274bec:	74 3c                	je     1274c2a <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x111a>
 1274bee:	4c 69 d0 18 01 00 00 	imul   $0x118,%rax,%r10
 1274bf5:	47 0f b6 84 17 10 01 	movzbl 0x110(%r15,%r10,1),%r8d
 1274bfc:	00 00 
 1274bfe:	41 80 e0 0f          	and    $0xf,%r8b
 1274c02:	41 80 f8 07          	cmp    $0x7,%r8b
 1274c06:	75 22                	jne    1274c2a <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x111a>
 1274c08:	4d 01 d7             	add    %r10,%r15
 1274c0b:	41 80 7f 40 00       	cmpb   $0x0,0x40(%r15)
 1274c10:	74 18                	je     1274c2a <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x111a>
 1274c12:	49 39 5f 38          	cmp    %rbx,0x38(%r15)
 1274c16:	75 12                	jne    1274c2a <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x111a>
 1274c18:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 1274c1f:	00 
 1274c20:	75 08                	jne    1274c2a <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x111a>
 1274c22:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1274c29:	00 
 1274c2a:	48 85 db             	test   %rbx,%rbx
 1274c2d:	0f 84 fe f7 ff ff    	je     1274431 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x921>
 1274c33:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1274c37:	48 89 da             	mov    %rbx,%rdx
 1274c3a:	31 c9                	xor    %ecx,%ecx
 1274c3c:	c5 f8 77             	vzeroupper 
 1274c3f:	41 ff 51 18          	call   *0x18(%r9)
 1274c43:	c5 fd 6f ac 24 00 01 	vmovdqa 0x100(%rsp),%ymm5
 1274c4a:	00 00 
 1274c4c:	c5 fd 6f a4 24 20 01 	vmovdqa 0x120(%rsp),%ymm4
 1274c53:	00 00 
 1274c55:	e9 d7 f7 ff ff       	jmp    1274431 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x921>
 1274c5a:	b8 8a 38 08 01       	mov    $0x108388a,%eax
 1274c5f:	c7 44 24 38 00 00 00 	movl   $0x0,0x38(%rsp)
 1274c66:	00 
 1274c67:	e9 6b 01 00 00       	jmp    1274dd7 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x12c7>
 1274c6c:	b0 01                	mov    $0x1,%al
 1274c6e:	48 89 84 24 c0 00 00 	mov    %rax,0xc0(%rsp)
 1274c75:	00 
 1274c76:	4c 8b a4 24 f0 00 00 	mov    0xf0(%rsp),%r12
 1274c7d:	00 
 1274c7e:	49 89 de             	mov    %rbx,%r14
 1274c81:	0f b7 44 24 74       	movzwl 0x74(%rsp),%eax
 1274c86:	66 89 44 24 24       	mov    %ax,0x24(%rsp)
 1274c8b:	8b 44 24 70          	mov    0x70(%rsp),%eax
 1274c8f:	89 44 24 20          	mov    %eax,0x20(%rsp)
 1274c93:	4d 85 e4             	test   %r12,%r12
 1274c96:	48 8b 74 24 68       	mov    0x68(%rsp),%rsi
 1274c9b:	74 26                	je     1274cc3 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x11b3>
 1274c9d:	44 88 6c 24 30       	mov    %r13b,0x30(%rsp)
 1274ca2:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 1274ca7:	48 89 44 24 60       	mov    %rax,0x60(%rsp)
 1274cac:	4c 89 74 24 40       	mov    %r14,0x40(%rsp)
 1274cb1:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 1274cb6:	48 8b 9c 24 a0 00 00 	mov    0xa0(%rsp),%rbx
 1274cbd:	00 
 1274cbe:	e9 16 f8 ff ff       	jmp    12744d9 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x9c9>
 1274cc3:	0f b7 44 24 74       	movzwl 0x74(%rsp),%eax
 1274cc8:	66 89 84 24 90 00 00 	mov    %ax,0x90(%rsp)
 1274ccf:	00 
 1274cd0:	8b 44 24 70          	mov    0x70(%rsp),%eax
 1274cd4:	89 84 24 8c 00 00 00 	mov    %eax,0x8c(%rsp)
 1274cdb:	b0 01                	mov    $0x1,%al
 1274cdd:	89 44 24 38          	mov    %eax,0x38(%rsp)
 1274ce1:	44 89 e9             	mov    %r13d,%ecx
 1274ce4:	80 e1 03             	and    $0x3,%cl
 1274ce7:	b8 8a 38 08 01       	mov    $0x108388a,%eax
 1274cec:	80 f9 02             	cmp    $0x2,%cl
 1274cef:	0f 85 c1 00 00 00    	jne    1274db6 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x12a6>
 1274cf5:	48 89 74 24 68       	mov    %rsi,0x68(%rsp)
 1274cfa:	44 89 db             	mov    %r11d,%ebx
 1274cfd:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 1274d02:	48 89 84 24 80 05 00 	mov    %rax,0x580(%rsp)
 1274d09:	00 
 1274d0a:	44 88 ac 24 88 05 00 	mov    %r13b,0x588(%rsp)
 1274d11:	00 
 1274d12:	44 88 9c 24 89 05 00 	mov    %r11b,0x589(%rsp)
 1274d19:	00 
 1274d1a:	c5 fe 7f ac 24 8a 05 	vmovdqu %ymm5,0x58a(%rsp)
 1274d21:	00 00 
 1274d23:	c5 fe 7f a4 24 aa 05 	vmovdqu %ymm4,0x5aa(%rsp)
 1274d2a:	00 00 
 1274d2c:	0f b7 84 24 90 00 00 	movzwl 0x90(%rsp),%eax
 1274d33:	00 
 1274d34:	48 8d 8c 24 ca 05 00 	lea    0x5ca(%rsp),%rcx
 1274d3b:	00 
 1274d3c:	66 89 41 04          	mov    %ax,0x4(%rcx)
 1274d40:	8b 84 24 8c 00 00 00 	mov    0x8c(%rsp),%eax
 1274d47:	89 01                	mov    %eax,(%rcx)
 1274d49:	48 8d bc 24 96 00 00 	lea    0x96(%rsp),%rdi
 1274d50:	00 
 1274d51:	4d 89 d7             	mov    %r10,%r15
 1274d54:	48 8d b4 24 80 05 00 	lea    0x580(%rsp),%rsi
 1274d5b:	00 
 1274d5c:	c5 fd 7f ac 24 e0 01 	vmovdqa %ymm5,0x1e0(%rsp)
 1274d63:	00 00 
 1274d65:	c5 fd 7f a4 24 c0 01 	vmovdqa %ymm4,0x1c0(%rsp)
 1274d6c:	00 00 
 1274d6e:	c5 f8 77             	vzeroupper 
 1274d71:	e8 fa b4 fb ff       	call   1230270 <br.encoder.literal_context_split.Candidate.suffixCutoff>
 1274d76:	4d 89 fa             	mov    %r15,%r10
 1274d79:	41 89 db             	mov    %ebx,%r11d
 1274d7c:	c5 fd 6f ac 24 e0 01 	vmovdqa 0x1e0(%rsp),%ymm5
 1274d83:	00 00 
 1274d85:	c5 fd 6f a4 24 c0 01 	vmovdqa 0x1c0(%rsp),%ymm4
 1274d8c:	00 00 
 1274d8e:	48 8b 44 24 68       	mov    0x68(%rsp),%rax
 1274d93:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 1274d98:	4c 89 74 24 40       	mov    %r14,0x40(%rsp)
 1274d9d:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 1274da2:	48 89 44 24 60       	mov    %rax,0x60(%rsp)
 1274da7:	44 88 6c 24 30       	mov    %r13b,0x30(%rsp)
 1274dac:	48 8d 84 24 96 00 00 	lea    0x96(%rsp),%rax
 1274db3:	00 
 1274db4:	eb 19                	jmp    1274dcf <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x12bf>
 1274db6:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 1274dbb:	4c 89 74 24 40       	mov    %r14,0x40(%rsp)
 1274dc0:	48 8b 4c 24 48       	mov    0x48(%rsp),%rcx
 1274dc5:	48 89 4c 24 60       	mov    %rcx,0x60(%rsp)
 1274dca:	44 88 6c 24 30       	mov    %r13b,0x30(%rsp)
 1274dcf:	48 8b 9c 24 a0 00 00 	mov    0xa0(%rsp),%rbx
 1274dd6:	00 
 1274dd7:	0f b7 00             	movzwl (%rax),%eax
 1274dda:	66 89 44 24 1e       	mov    %ax,0x1e(%rsp)
 1274ddf:	e9 f5 f6 ff ff       	jmp    12744d9 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x9c9>
 1274de4:	4d 89 f0             	mov    %r14,%r8
 1274de7:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1274deb:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 1274def:	31 c0                	xor    %eax,%eax
 1274df1:	eb 21                	jmp    1274e14 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1304>
 1274df3:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1274dfa:	84 00 00 00 00 00 
 1274e00:	48 83 c0 02          	add    $0x2,%rax
 1274e04:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 1274e0b:	49 39 c0             	cmp    %rax,%r8
 1274e0e:	0f 84 d2 fa ff ff    	je     12748e6 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0xdd6>
 1274e14:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 1274e1b:	00 
 1274e1c:	41 80 e3 0f          	and    $0xf,%r11b
 1274e20:	41 80 fb 07          	cmp    $0x7,%r11b
 1274e24:	75 2a                	jne    1274e50 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1340>
 1274e26:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 1274e2b:	74 23                	je     1274e50 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1340>
 1274e2d:	4d 39 22             	cmp    %r12,(%r10)
 1274e30:	75 1e                	jne    1274e50 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1340>
 1274e32:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 1274e39:	00 
 1274e3a:	75 14                	jne    1274e50 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1340>
 1274e3c:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1274e43:	00 
 1274e44:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1274e4b:	00 00 00 00 00 
 1274e50:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1274e57:	00 
 1274e58:	41 80 e3 0f          	and    $0xf,%r11b
 1274e5c:	41 80 fb 07          	cmp    $0x7,%r11b
 1274e60:	75 9e                	jne    1274e00 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x12f0>
 1274e62:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1274e69:	00 
 1274e6a:	74 94                	je     1274e00 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x12f0>
 1274e6c:	4d 39 a2 18 01 00 00 	cmp    %r12,0x118(%r10)
 1274e73:	75 8b                	jne    1274e00 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x12f0>
 1274e75:	48 39 b4 c1 d8 32 02 	cmp    %rsi,0x232d8(%rcx,%rax,8)
 1274e7c:	00 
 1274e7d:	75 81                	jne    1274e00 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x12f0>
 1274e7f:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 1274e86:	00 
 1274e87:	e9 74 ff ff ff       	jmp    1274e00 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x12f0>
 1274e8c:	4d 89 f0             	mov    %r14,%r8
 1274e8f:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1274e93:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 1274e97:	31 c0                	xor    %eax,%eax
 1274e99:	eb 19                	jmp    1274eb4 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x13a4>
 1274e9b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 1274ea0:	48 83 c0 02          	add    $0x2,%rax
 1274ea4:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 1274eab:	49 39 c0             	cmp    %rax,%r8
 1274eae:	0f 84 34 fd ff ff    	je     1274be8 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x10d8>
 1274eb4:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 1274ebb:	00 
 1274ebc:	41 80 e3 0f          	and    $0xf,%r11b
 1274ec0:	41 80 fb 07          	cmp    $0x7,%r11b
 1274ec4:	75 2a                	jne    1274ef0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x13e0>
 1274ec6:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 1274ecb:	74 23                	je     1274ef0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x13e0>
 1274ecd:	49 39 1a             	cmp    %rbx,(%r10)
 1274ed0:	75 1e                	jne    1274ef0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x13e0>
 1274ed2:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 1274ed9:	00 
 1274eda:	75 14                	jne    1274ef0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x13e0>
 1274edc:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1274ee3:	00 
 1274ee4:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1274eeb:	00 00 00 00 00 
 1274ef0:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1274ef7:	00 
 1274ef8:	41 80 e3 0f          	and    $0xf,%r11b
 1274efc:	41 80 fb 07          	cmp    $0x7,%r11b
 1274f00:	75 9e                	jne    1274ea0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1390>
 1274f02:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1274f09:	00 
 1274f0a:	74 94                	je     1274ea0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1390>
 1274f0c:	49 39 9a 18 01 00 00 	cmp    %rbx,0x118(%r10)
 1274f13:	75 8b                	jne    1274ea0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1390>
 1274f15:	48 39 b4 c1 d8 32 02 	cmp    %rsi,0x232d8(%rcx,%rax,8)
 1274f1c:	00 
 1274f1d:	75 81                	jne    1274ea0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1390>
 1274f1f:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 1274f26:	00 
 1274f27:	e9 74 ff ff ff       	jmp    1274ea0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1390>
 1274f2c:	8b 44 24 28          	mov    0x28(%rsp),%eax
 1274f30:	8b 8c 24 f8 00 00 00 	mov    0xf8(%rsp),%ecx
 1274f37:	08 c8                	or     %cl,%al
 1274f39:	0f 84 a5 04 00 00    	je     12753e4 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x18d4>
 1274f3f:	4c 8b 64 24 40       	mov    0x40(%rsp),%r12
 1274f44:	84 c9                	test   %cl,%cl
 1274f46:	4c 89 94 24 b8 00 00 	mov    %r10,0xb8(%rsp)
 1274f4d:	00 
 1274f4e:	4c 8b 75 18          	mov    0x18(%rbp),%r14
 1274f52:	48 8b b4 24 b8 00 00 	mov    0xb8(%rsp),%rsi
 1274f59:	00 
 1274f5a:	75 34                	jne    1274f90 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1480>
 1274f5c:	b9 64 00 00 00       	mov    $0x64,%ecx
 1274f61:	4c 89 e0             	mov    %r12,%rax
 1274f64:	48 f7 e1             	mul    %rcx
 1274f67:	70 27                	jo     1274f90 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1480>
 1274f69:	c6 84 24 20 02 00 00 	movb   $0x0,0x220(%rsp)
 1274f70:	00 
 1274f71:	31 c9                	xor    %ecx,%ecx
 1274f73:	84 c9                	test   %cl,%cl
 1274f75:	75 19                	jne    1274f90 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1480>
 1274f77:	48 8b 8c 24 a8 00 00 	mov    0xa8(%rsp),%rcx
 1274f7e:	00 
 1274f7f:	48 c1 e1 04          	shl    $0x4,%rcx
 1274f83:	48 8d 0c 89          	lea    (%rcx,%rcx,4),%rcx
 1274f87:	48 39 c8             	cmp    %rcx,%rax
 1274f8a:	0f 86 3c 0a 00 00    	jbe    12759cc <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1ebc>
 1274f90:	44 88 5c 24 07       	mov    %r11b,0x7(%rsp)
 1274f95:	c5 fd 7f ac 24 00 01 	vmovdqa %ymm5,0x100(%rsp)
 1274f9c:	00 00 
 1274f9e:	c5 fd 7f a4 24 20 01 	vmovdqa %ymm4,0x120(%rsp)
 1274fa5:	00 00 
 1274fa7:	c5 fc 10 84 24 40 05 	vmovups 0x540(%rsp),%ymm0
 1274fae:	00 00 
 1274fb0:	c5 fc 11 84 24 60 07 	vmovups %ymm0,0x760(%rsp)
 1274fb7:	00 00 
 1274fb9:	c5 fc 10 84 24 d0 04 	vmovups 0x4d0(%rsp),%ymm0
 1274fc0:	00 00 
 1274fc2:	c5 fc 10 8c 24 f0 04 	vmovups 0x4f0(%rsp),%ymm1
 1274fc9:	00 00 
 1274fcb:	c5 fc 10 94 24 10 05 	vmovups 0x510(%rsp),%ymm2
 1274fd2:	00 00 
 1274fd4:	c5 fc 10 9c 24 30 05 	vmovups 0x530(%rsp),%ymm3
 1274fdb:	00 00 
 1274fdd:	c5 fc 11 9c 24 50 07 	vmovups %ymm3,0x750(%rsp)
 1274fe4:	00 00 
 1274fe6:	c5 fc 11 94 24 30 07 	vmovups %ymm2,0x730(%rsp)
 1274fed:	00 00 
 1274fef:	c5 fc 11 8c 24 10 07 	vmovups %ymm1,0x710(%rsp)
 1274ff6:	00 00 
 1274ff8:	c5 fc 11 84 24 f0 06 	vmovups %ymm0,0x6f0(%rsp)
 1274fff:	00 00 
 1275001:	0f b6 44 24 08       	movzbl 0x8(%rsp),%eax
 1275006:	c5 fe 6f 84 24 50 04 	vmovdqu 0x450(%rsp),%ymm0
 127500d:	00 00 
 127500f:	c5 fe 7f 84 24 f0 09 	vmovdqu %ymm0,0x9f0(%rsp)
 1275016:	00 00 
 1275018:	88 84 24 f1 0b 00 00 	mov    %al,0xbf1(%rsp)
 127501f:	48 c7 84 24 e0 09 00 	movq   $0x0,0x9e0(%rsp)
 1275026:	00 00 00 00 00 
 127502b:	66 c7 84 24 f4 0b 00 	movw   $0x0,0xbf4(%rsp)
 1275032:	00 00 00 
 1275035:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 1275039:	c5 fe 7f 84 24 10 0a 	vmovdqu %ymm0,0xa10(%rsp)
 1275040:	00 00 
 1275042:	c5 fe 7f 84 24 30 0a 	vmovdqu %ymm0,0xa30(%rsp)
 1275049:	00 00 
 127504b:	c5 fe 7f 84 24 50 0a 	vmovdqu %ymm0,0xa50(%rsp)
 1275052:	00 00 
 1275054:	c5 fe 7f 84 24 70 0a 	vmovdqu %ymm0,0xa70(%rsp)
 127505b:	00 00 
 127505d:	c5 fe 7f 84 24 90 0a 	vmovdqu %ymm0,0xa90(%rsp)
 1275064:	00 00 
 1275066:	c5 fe 7f 84 24 b0 0a 	vmovdqu %ymm0,0xab0(%rsp)
 127506d:	00 00 
 127506f:	c5 fe 7f 84 24 d0 0a 	vmovdqu %ymm0,0xad0(%rsp)
 1275076:	00 00 
 1275078:	c5 fe 7f 84 24 f0 0a 	vmovdqu %ymm0,0xaf0(%rsp)
 127507f:	00 00 
 1275081:	c5 fe 7f 84 24 10 0b 	vmovdqu %ymm0,0xb10(%rsp)
 1275088:	00 00 
 127508a:	c5 fe 7f 84 24 30 0b 	vmovdqu %ymm0,0xb30(%rsp)
 1275091:	00 00 
 1275093:	c5 fe 7f 84 24 50 0b 	vmovdqu %ymm0,0xb50(%rsp)
 127509a:	00 00 
 127509c:	c5 fe 7f 84 24 70 0b 	vmovdqu %ymm0,0xb70(%rsp)
 12750a3:	00 00 
 12750a5:	c5 fe 7f 84 24 90 0b 	vmovdqu %ymm0,0xb90(%rsp)
 12750ac:	00 00 
 12750ae:	c5 fe 7f 84 24 b0 0b 	vmovdqu %ymm0,0xbb0(%rsp)
 12750b5:	00 00 
 12750b7:	48 c7 84 24 d0 0b 00 	movq   $0x0,0xbd0(%rsp)
 12750be:	00 00 00 00 00 
 12750c3:	c6 84 24 e8 0b 00 00 	movb   $0x38,0xbe8(%rsp)
 12750ca:	38 
 12750cb:	c6 84 24 f0 0b 00 00 	movb   $0x0,0xbf0(%rsp)
 12750d2:	00 
 12750d3:	0f b7 05 56 5e dc ff 	movzwl -0x23a1aa(%rip),%eax        # 103af30 <__anon_29470>
 12750da:	66 89 84 24 ea 0b 00 	mov    %ax,0xbea(%rsp)
 12750e1:	00 
 12750e2:	0f b6 44 24 06       	movzbl 0x6(%rsp),%eax
 12750e7:	88 84 24 e9 0b 00 00 	mov    %al,0xbe9(%rsp)
 12750ee:	48 8b 84 24 e8 00 00 	mov    0xe8(%rsp),%rax
 12750f5:	00 
 12750f6:	48 89 84 24 d0 09 00 	mov    %rax,0x9d0(%rsp)
 12750fd:	00 
 12750fe:	48 8b 84 24 e0 00 00 	mov    0xe0(%rsp),%rax
 1275105:	00 
 1275106:	48 89 84 24 d8 09 00 	mov    %rax,0x9d8(%rsp)
 127510d:	00 
 127510e:	c7 84 24 ec 0b 00 00 	movl   $0x1000101,0xbec(%rsp)
 1275115:	01 01 00 01 
 1275119:	48 8b 84 24 d8 00 00 	mov    0xd8(%rsp),%rax
 1275120:	00 
 1275121:	48 89 84 24 e0 0b 00 	mov    %rax,0xbe0(%rsp)
 1275128:	00 
 1275129:	48 8b 84 24 d0 00 00 	mov    0xd0(%rsp),%rax
 1275130:	00 
 1275131:	48 89 84 24 d8 0b 00 	mov    %rax,0xbd8(%rsp)
 1275138:	00 
 1275139:	66 c7 84 24 f2 0b 00 	movw   $0x0,0xbf2(%rsp)
 1275140:	00 00 00 
 1275143:	48 c7 84 24 e8 09 00 	movq   $0x0,0x9e8(%rsp)
 127514a:	00 00 00 00 00 
 127514f:	48 83 ec 08          	sub    $0x8,%rsp
 1275153:	48 8d 84 24 d8 09 00 	lea    0x9d8(%rsp),%rax
 127515a:	00 
 127515b:	4c 8d 94 24 f8 06 00 	lea    0x6f8(%rsp),%r10
 1275162:	00 
 1275163:	48 8d bc 24 40 04 00 	lea    0x440(%rsp),%rdi
 127516a:	00 
 127516b:	4c 8b ac 24 a0 00 00 	mov    0xa0(%rsp),%r13
 1275172:	00 
 1275173:	4c 89 ee             	mov    %r13,%rsi
 1275176:	4c 8b bc 24 88 00 00 	mov    0x88(%rsp),%r15
 127517d:	00 
 127517e:	4c 89 fa             	mov    %r15,%rdx
 1275181:	48 8b 8c 24 d0 00 00 	mov    0xd0(%rsp),%rcx
 1275188:	00 
 1275189:	4c 8b 84 24 b0 00 00 	mov    0xb0(%rsp),%r8
 1275190:	00 
 1275191:	4c 8b 8c 24 b8 00 00 	mov    0xb8(%rsp),%r9
 1275198:	00 
 1275199:	50                   	push   %rax
 127519a:	41 52                	push   %r10
 127519c:	ff 75 10             	push   0x10(%rbp)
 127519f:	c5 f8 77             	vzeroupper 
 12751a2:	e8 89 99 fb ff       	call   122eb30 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509>
 12751a7:	48 83 c4 20          	add    $0x20,%rsp
 12751ab:	0f b7 9c 24 48 04 00 	movzwl 0x448(%rsp),%ebx
 12751b2:	00 
 12751b3:	48 85 db             	test   %rbx,%rbx
 12751b6:	0f 85 27 0b 00 00    	jne    1275ce3 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x21d3>
 12751bc:	4c 8b b4 24 38 04 00 	mov    0x438(%rsp),%r14
 12751c3:	00 
 12751c4:	48 8b 9c 24 40 04 00 	mov    0x440(%rsp),%rbx
 12751cb:	00 
 12751cc:	48 8d bc 24 60 05 00 	lea    0x560(%rsp),%rdi
 12751d3:	00 
 12751d4:	48 8b 74 24 10       	mov    0x10(%rsp),%rsi
 12751d9:	4c 89 e2             	mov    %r12,%rdx
 12751dc:	4c 89 f1             	mov    %r14,%rcx
 12751df:	49 89 d8             	mov    %rbx,%r8
 12751e2:	e8 f9 8d fc ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 12751e7:	49 8b 4d 10          	mov    0x10(%r13),%rcx
 12751eb:	49 8b 3f             	mov    (%r15),%rdi
 12751ee:	4d 8b 4f 08          	mov    0x8(%r15),%r9
 12751f2:	48 8d 51 20          	lea    0x20(%rcx),%rdx
 12751f6:	48 8b b1 20 30 02 00 	mov    0x23020(%rcx),%rsi
 12751fd:	a8 01                	test   $0x1,%al
 12751ff:	0f 84 43 03 00 00    	je     1275548 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1a38>
 1275205:	48 85 f6             	test   %rsi,%rsi
 1275208:	44 8b 7c 24 38       	mov    0x38(%rsp),%r15d
 127520d:	c5 fd 6f a4 24 20 01 	vmovdqa 0x120(%rsp),%ymm4
 1275214:	00 00 
 1275216:	c5 fd 6f ac 24 00 01 	vmovdqa 0x100(%rsp),%ymm5
 127521d:	00 00 
 127521f:	74 4d                	je     127526e <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x175e>
 1275221:	48 83 fe 01          	cmp    $0x1,%rsi
 1275225:	0f 85 ae 05 00 00    	jne    12757d9 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1cc9>
 127522b:	31 c0                	xor    %eax,%eax
 127522d:	40 f6 c6 01          	test   $0x1,%sil
 1275231:	74 3b                	je     127526e <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x175e>
 1275233:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 127523a:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 1275241:	00 00 
 1275243:	41 80 e0 0f          	and    $0xf,%r8b
 1275247:	41 80 f8 07          	cmp    $0x7,%r8b
 127524b:	75 21                	jne    127526e <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x175e>
 127524d:	48 01 f2             	add    %rsi,%rdx
 1275250:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 1275254:	74 18                	je     127526e <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x175e>
 1275256:	48 39 5a 38          	cmp    %rbx,0x38(%rdx)
 127525a:	75 12                	jne    127526e <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x175e>
 127525c:	4c 39 b4 c1 d0 32 02 	cmp    %r14,0x232d0(%rcx,%rax,8)
 1275263:	00 
 1275264:	75 08                	jne    127526e <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x175e>
 1275266:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 127526d:	00 
 127526e:	48 85 db             	test   %rbx,%rbx
 1275271:	74 25                	je     1275298 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1788>
 1275273:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1275277:	4c 89 f6             	mov    %r14,%rsi
 127527a:	48 89 da             	mov    %rbx,%rdx
 127527d:	31 c9                	xor    %ecx,%ecx
 127527f:	c5 f8 77             	vzeroupper 
 1275282:	41 ff 51 18          	call   *0x18(%r9)
 1275286:	c5 fd 6f ac 24 00 01 	vmovdqa 0x100(%rsp),%ymm5
 127528d:	00 00 
 127528f:	c5 fd 6f a4 24 20 01 	vmovdqa 0x120(%rsp),%ymm4
 1275296:	00 00 
 1275298:	c5 fc 10 84 24 f0 02 	vmovups 0x2f0(%rsp),%ymm0
 127529f:	00 00 
 12752a1:	48 8b 45 18          	mov    0x18(%rbp),%rax
 12752a5:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 12752aa:	c5 fc 10 84 24 80 02 	vmovups 0x280(%rsp),%ymm0
 12752b1:	00 00 
 12752b3:	c5 fc 10 8c 24 a0 02 	vmovups 0x2a0(%rsp),%ymm1
 12752ba:	00 00 
 12752bc:	c5 fc 10 94 24 c0 02 	vmovups 0x2c0(%rsp),%ymm2
 12752c3:	00 00 
 12752c5:	c5 fc 10 9c 24 e0 02 	vmovups 0x2e0(%rsp),%ymm3
 12752cc:	00 00 
 12752ce:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 12752d3:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 12752d8:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 12752dd:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 12752e1:	48 8b 54 24 50       	mov    0x50(%rsp),%rdx
 12752e6:	66 c7 82 60 01 00 00 	movw   $0x0,0x160(%rdx)
 12752ed:	00 00 
 12752ef:	48 8b 44 24 10       	mov    0x10(%rsp),%rax
 12752f4:	48 89 02             	mov    %rax,(%rdx)
 12752f7:	4c 89 62 08          	mov    %r12,0x8(%rdx)
 12752fb:	8b 44 24 28          	mov    0x28(%rsp),%eax
 12752ff:	88 82 58 01 00 00    	mov    %al,0x158(%rdx)
 1275305:	48 8b 44 24 60       	mov    0x60(%rsp),%rax
 127530a:	48 89 42 10          	mov    %rax,0x10(%rdx)
 127530e:	0f b6 44 24 30       	movzbl 0x30(%rsp),%eax
 1275313:	88 42 18             	mov    %al,0x18(%rdx)
 1275316:	0f b6 44 24 07       	movzbl 0x7(%rsp),%eax
 127531b:	88 42 19             	mov    %al,0x19(%rdx)
 127531e:	c5 fe 7f 6a 1a       	vmovdqu %ymm5,0x1a(%rdx)
 1275323:	c5 fe 7f 62 3a       	vmovdqu %ymm4,0x3a(%rdx)
 1275328:	8b 44 24 20          	mov    0x20(%rsp),%eax
 127532c:	89 42 5a             	mov    %eax,0x5a(%rdx)
 127532f:	0f b7 44 24 24       	movzwl 0x24(%rsp),%eax
 1275334:	66 89 42 5e          	mov    %ax,0x5e(%rdx)
 1275338:	44 88 7a 60          	mov    %r15b,0x60(%rdx)
 127533c:	8b 44 24 78          	mov    0x78(%rsp),%eax
 1275340:	8b 4c 24 7b          	mov    0x7b(%rsp),%ecx
 1275344:	89 42 61             	mov    %eax,0x61(%rdx)
 1275347:	89 4a 64             	mov    %ecx,0x64(%rdx)
 127534a:	c5 fc 10 84 24 18 03 	vmovups 0x318(%rsp),%ymm0
 1275351:	00 00 
 1275353:	c5 fc 10 8c 24 38 03 	vmovups 0x338(%rsp),%ymm1
 127535a:	00 00 
 127535c:	c5 fc 10 94 24 58 03 	vmovups 0x358(%rsp),%ymm2
 1275363:	00 00 
 1275365:	c5 fc 10 9c 24 78 03 	vmovups 0x378(%rsp),%ymm3
 127536c:	00 00 
 127536e:	c5 fc 11 42 68       	vmovups %ymm0,0x68(%rdx)
 1275373:	c5 fc 11 8a 88 00 00 	vmovups %ymm1,0x88(%rdx)
 127537a:	00 
 127537b:	c5 fc 11 92 a8 00 00 	vmovups %ymm2,0xa8(%rdx)
 1275382:	00 
 1275383:	c5 fc 11 9a c8 00 00 	vmovups %ymm3,0xc8(%rdx)
 127538a:	00 
 127538b:	c5 fc 10 84 24 98 03 	vmovups 0x398(%rsp),%ymm0
 1275392:	00 00 
 1275394:	c5 fc 11 82 e8 00 00 	vmovups %ymm0,0xe8(%rdx)
 127539b:	00 
 127539c:	c5 fc 10 84 24 b8 03 	vmovups 0x3b8(%rsp),%ymm0
 12753a3:	00 00 
 12753a5:	c5 fc 11 82 08 01 00 	vmovups %ymm0,0x108(%rdx)
 12753ac:	00 
 12753ad:	c5 fc 10 84 24 d8 03 	vmovups 0x3d8(%rsp),%ymm0
 12753b4:	00 00 
 12753b6:	c5 fc 11 82 28 01 00 	vmovups %ymm0,0x128(%rdx)
 12753bd:	00 
 12753be:	c5 fe 6f 84 24 e8 03 	vmovdqu 0x3e8(%rsp),%ymm0
 12753c5:	00 00 
 12753c7:	c5 fe 7f 82 38 01 00 	vmovdqu %ymm0,0x138(%rdx)
 12753ce:	00 
 12753cf:	48 8b 84 24 b8 00 00 	mov    0xb8(%rsp),%rax
 12753d6:	00 
 12753d7:	24 03                	and    $0x3,%al
 12753d9:	88 82 59 01 00 00    	mov    %al,0x159(%rdx)
 12753df:	e9 43 01 00 00       	jmp    1275527 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1a17>
 12753e4:	c5 fc 10 84 24 f0 02 	vmovups 0x2f0(%rsp),%ymm0
 12753eb:	00 00 
 12753ed:	48 8b 45 18          	mov    0x18(%rbp),%rax
 12753f1:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 12753f6:	c5 fc 10 84 24 80 02 	vmovups 0x280(%rsp),%ymm0
 12753fd:	00 00 
 12753ff:	c5 fc 10 8c 24 a0 02 	vmovups 0x2a0(%rsp),%ymm1
 1275406:	00 00 
 1275408:	c5 fc 10 94 24 c0 02 	vmovups 0x2c0(%rsp),%ymm2
 127540f:	00 00 
 1275411:	c5 fc 10 9c 24 e0 02 	vmovups 0x2e0(%rsp),%ymm3
 1275418:	00 00 
 127541a:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 127541f:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1275424:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1275429:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 127542d:	48 8b 54 24 50       	mov    0x50(%rsp),%rdx
 1275432:	66 c7 82 60 01 00 00 	movw   $0x0,0x160(%rdx)
 1275439:	00 00 
 127543b:	48 8b 44 24 10       	mov    0x10(%rsp),%rax
 1275440:	48 89 02             	mov    %rax,(%rdx)
 1275443:	48 8b 44 24 40       	mov    0x40(%rsp),%rax
 1275448:	48 89 42 08          	mov    %rax,0x8(%rdx)
 127544c:	c6 82 58 01 00 00 00 	movb   $0x0,0x158(%rdx)
 1275453:	48 8b 44 24 60       	mov    0x60(%rsp),%rax
 1275458:	48 89 42 10          	mov    %rax,0x10(%rdx)
 127545c:	0f b6 44 24 30       	movzbl 0x30(%rsp),%eax
 1275461:	88 42 18             	mov    %al,0x18(%rdx)
 1275464:	44 88 5a 19          	mov    %r11b,0x19(%rdx)
 1275468:	c5 fe 7f 6a 1a       	vmovdqu %ymm5,0x1a(%rdx)
 127546d:	c5 fe 7f 62 3a       	vmovdqu %ymm4,0x3a(%rdx)
 1275472:	8b 44 24 20          	mov    0x20(%rsp),%eax
 1275476:	89 42 5a             	mov    %eax,0x5a(%rdx)
 1275479:	0f b7 44 24 24       	movzwl 0x24(%rsp),%eax
 127547e:	66 89 42 5e          	mov    %ax,0x5e(%rdx)
 1275482:	8b 44 24 38          	mov    0x38(%rsp),%eax
 1275486:	88 42 60             	mov    %al,0x60(%rdx)
 1275489:	8b 44 24 78          	mov    0x78(%rsp),%eax
 127548d:	8b 4c 24 7b          	mov    0x7b(%rsp),%ecx
 1275491:	89 42 61             	mov    %eax,0x61(%rdx)
 1275494:	89 4a 64             	mov    %ecx,0x64(%rdx)
 1275497:	c5 fc 10 84 24 18 03 	vmovups 0x318(%rsp),%ymm0
 127549e:	00 00 
 12754a0:	c5 fc 10 8c 24 38 03 	vmovups 0x338(%rsp),%ymm1
 12754a7:	00 00 
 12754a9:	c5 fc 10 94 24 58 03 	vmovups 0x358(%rsp),%ymm2
 12754b0:	00 00 
 12754b2:	c5 fc 10 9c 24 78 03 	vmovups 0x378(%rsp),%ymm3
 12754b9:	00 00 
 12754bb:	c5 fc 11 42 68       	vmovups %ymm0,0x68(%rdx)
 12754c0:	c5 fc 11 8a 88 00 00 	vmovups %ymm1,0x88(%rdx)
 12754c7:	00 
 12754c8:	c5 fc 11 92 a8 00 00 	vmovups %ymm2,0xa8(%rdx)
 12754cf:	00 
 12754d0:	c5 fc 11 9a c8 00 00 	vmovups %ymm3,0xc8(%rdx)
 12754d7:	00 
 12754d8:	c5 fc 10 84 24 98 03 	vmovups 0x398(%rsp),%ymm0
 12754df:	00 00 
 12754e1:	c5 fc 11 82 e8 00 00 	vmovups %ymm0,0xe8(%rdx)
 12754e8:	00 
 12754e9:	c5 fc 10 84 24 b8 03 	vmovups 0x3b8(%rsp),%ymm0
 12754f0:	00 00 
 12754f2:	c5 fc 11 82 08 01 00 	vmovups %ymm0,0x108(%rdx)
 12754f9:	00 
 12754fa:	c5 fc 10 84 24 d8 03 	vmovups 0x3d8(%rsp),%ymm0
 1275501:	00 00 
 1275503:	c5 fc 11 82 28 01 00 	vmovups %ymm0,0x128(%rdx)
 127550a:	00 
 127550b:	c5 fe 6f 84 24 e8 03 	vmovdqu 0x3e8(%rsp),%ymm0
 1275512:	00 00 
 1275514:	c5 fe 7f 82 38 01 00 	vmovdqu %ymm0,0x138(%rdx)
 127551b:	00 
 127551c:	41 80 e2 03          	and    $0x3,%r10b
 1275520:	44 88 92 59 01 00 00 	mov    %r10b,0x159(%rdx)
 1275527:	48 8b 84 24 c0 00 00 	mov    0xc0(%rsp),%rax
 127552e:	00 
 127552f:	24 01                	and    $0x1,%al
 1275531:	88 82 5a 01 00 00    	mov    %al,0x15a(%rdx)
 1275537:	0f b7 44 24 1e       	movzwl 0x1e(%rsp),%eax
 127553c:	66 89 82 5b 01 00 00 	mov    %ax,0x15b(%rdx)
 1275543:	e9 f0 00 00 00       	jmp    1275638 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1b28>
 1275548:	48 85 f6             	test   %rsi,%rsi
 127554b:	74 52                	je     127559f <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1a8f>
 127554d:	48 83 fe 01          	cmp    $0x1,%rsi
 1275551:	0f 85 25 03 00 00    	jne    127587c <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1d6c>
 1275557:	31 c0                	xor    %eax,%eax
 1275559:	40 f6 c6 01          	test   $0x1,%sil
 127555d:	74 40                	je     127559f <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1a8f>
 127555f:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 1275566:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 127556d:	00 00 
 127556f:	41 80 e0 0f          	and    $0xf,%r8b
 1275573:	41 80 f8 07          	cmp    $0x7,%r8b
 1275577:	75 26                	jne    127559f <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1a8f>
 1275579:	48 01 f2             	add    %rsi,%rdx
 127557c:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 1275580:	74 1d                	je     127559f <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1a8f>
 1275582:	4c 39 62 38          	cmp    %r12,0x38(%rdx)
 1275586:	75 17                	jne    127559f <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1a8f>
 1275588:	48 8b 54 24 10       	mov    0x10(%rsp),%rdx
 127558d:	48 39 94 c1 d0 32 02 	cmp    %rdx,0x232d0(%rcx,%rax,8)
 1275594:	00 
 1275595:	75 08                	jne    127559f <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1a8f>
 1275597:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 127559e:	00 
 127559f:	4d 85 e4             	test   %r12,%r12
 12755a2:	74 12                	je     12755b6 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1aa6>
 12755a4:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12755a8:	48 8b 74 24 10       	mov    0x10(%rsp),%rsi
 12755ad:	4c 89 e2             	mov    %r12,%rdx
 12755b0:	31 c9                	xor    %ecx,%ecx
 12755b2:	41 ff 51 18          	call   *0x18(%r9)
 12755b6:	c5 fc 10 84 24 60 07 	vmovups 0x760(%rsp),%ymm0
 12755bd:	00 00 
 12755bf:	48 8b 45 18          	mov    0x18(%rbp),%rax
 12755c3:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 12755c8:	c5 fe 6f 84 24 f0 06 	vmovdqu 0x6f0(%rsp),%ymm0
 12755cf:	00 00 
 12755d1:	c5 fc 10 8c 24 10 07 	vmovups 0x710(%rsp),%ymm1
 12755d8:	00 00 
 12755da:	c5 fc 10 94 24 30 07 	vmovups 0x730(%rsp),%ymm2
 12755e1:	00 00 
 12755e3:	c5 fc 10 9c 24 50 07 	vmovups 0x750(%rsp),%ymm3
 12755ea:	00 00 
 12755ec:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 12755f1:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 12755f6:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 12755fb:	c5 fe 7f 00          	vmovdqu %ymm0,(%rax)
 12755ff:	48 8b 44 24 50       	mov    0x50(%rsp),%rax
 1275604:	66 c7 80 60 01 00 00 	movw   $0x0,0x160(%rax)
 127560b:	00 00 
 127560d:	4c 89 30             	mov    %r14,(%rax)
 1275610:	48 89 58 08          	mov    %rbx,0x8(%rax)
 1275614:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 1275618:	c5 fe 7f 40 10       	vmovdqu %ymm0,0x10(%rax)
 127561d:	c5 fe 7f 40 30       	vmovdqu %ymm0,0x30(%rax)
 1275622:	c5 fe 7f 40 48       	vmovdqu %ymm0,0x48(%rax)
 1275627:	c7 80 58 01 00 00 00 	movl   $0x0,0x158(%rax)
 127562e:	00 00 00 
 1275631:	c6 80 5c 01 00 00 00 	movb   $0x0,0x15c(%rax)
 1275638:	48 8d bc 24 40 01 00 	lea    0x140(%rsp),%rdi
 127563f:	00 
 1275640:	c5 f8 77             	vzeroupper 
 1275643:	e8 28 1b 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 1275648:	48 8d 65 d8          	lea    -0x28(%rbp),%rsp
 127564c:	5b                   	pop    %rbx
 127564d:	41 5c                	pop    %r12
 127564f:	41 5d                	pop    %r13
 1275651:	41 5e                	pop    %r14
 1275653:	41 5f                	pop    %r15
 1275655:	5d                   	pop    %rbp
 1275656:	c3                   	ret    
 1275657:	48 8b 84 24 98 00 00 	mov    0x98(%rsp),%rax
 127565e:	00 
 127565f:	48 8b 48 10          	mov    0x10(%rax),%rcx
 1275663:	48 8b 84 24 80 00 00 	mov    0x80(%rsp),%rax
 127566a:	00 
 127566b:	48 8b 38             	mov    (%rax),%rdi
 127566e:	48 8b 40 08          	mov    0x8(%rax),%rax
 1275672:	4c 8b 99 20 30 02 00 	mov    0x23020(%rcx),%r11
 1275679:	4d 85 db             	test   %r11,%r11
 127567c:	48 8b 54 24 40       	mov    0x40(%rsp),%rdx
 1275681:	74 52                	je     12756d5 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1bc5>
 1275683:	49 83 fb 01          	cmp    $0x1,%r11
 1275687:	0f 85 98 02 00 00    	jne    1275925 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1e15>
 127568d:	31 db                	xor    %ebx,%ebx
 127568f:	41 f6 c3 01          	test   $0x1,%r11b
 1275693:	74 40                	je     12756d5 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1bc5>
 1275695:	4c 8d 51 20          	lea    0x20(%rcx),%r10
 1275699:	4c 69 c3 18 01 00 00 	imul   $0x118,%rbx,%r8
 12756a0:	47 0f b6 8c 02 10 01 	movzbl 0x110(%r10,%r8,1),%r9d
 12756a7:	00 00 
 12756a9:	41 80 e1 0f          	and    $0xf,%r9b
 12756ad:	41 80 f9 07          	cmp    $0x7,%r9b
 12756b1:	75 22                	jne    12756d5 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1bc5>
 12756b3:	4d 01 c2             	add    %r8,%r10
 12756b6:	41 80 7a 40 00       	cmpb   $0x0,0x40(%r10)
 12756bb:	74 18                	je     12756d5 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1bc5>
 12756bd:	49 39 52 38          	cmp    %rdx,0x38(%r10)
 12756c1:	75 12                	jne    12756d5 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1bc5>
 12756c3:	4c 39 a4 d9 d0 32 02 	cmp    %r12,0x232d0(%rcx,%rbx,8)
 12756ca:	00 
 12756cb:	75 08                	jne    12756d5 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1bc5>
 12756cd:	c6 84 19 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rbx,1)
 12756d4:	00 
 12756d5:	48 85 d2             	test   %rdx,%rdx
 12756d8:	0f 84 a2 00 00 00    	je     1275780 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1c70>
 12756de:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12756e2:	4c 89 e6             	mov    %r12,%rsi
 12756e5:	e9 8e 00 00 00       	jmp    1275778 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1c68>
 12756ea:	48 8b 84 24 98 00 00 	mov    0x98(%rsp),%rax
 12756f1:	00 
 12756f2:	48 8b 48 10          	mov    0x10(%rax),%rcx
 12756f6:	48 8b 84 24 80 00 00 	mov    0x80(%rsp),%rax
 12756fd:	00 
 12756fe:	48 8b 38             	mov    (%rax),%rdi
 1275701:	48 8b 40 08          	mov    0x8(%rax),%rax
 1275705:	48 8b b1 20 30 02 00 	mov    0x23020(%rcx),%rsi
 127570c:	48 85 f6             	test   %rsi,%rsi
 127570f:	74 56                	je     1275767 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1c57>
 1275711:	48 83 fe 01          	cmp    $0x1,%rsi
 1275715:	0f 85 f8 03 00 00    	jne    1275b13 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x2003>
 127571b:	31 d2                	xor    %edx,%edx
 127571d:	40 f6 c6 01          	test   $0x1,%sil
 1275721:	74 44                	je     1275767 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1c57>
 1275723:	48 8d 71 20          	lea    0x20(%rcx),%rsi
 1275727:	4c 69 c2 18 01 00 00 	imul   $0x118,%rdx,%r8
 127572e:	46 0f b6 8c 06 10 01 	movzbl 0x110(%rsi,%r8,1),%r9d
 1275735:	00 00 
 1275737:	41 80 e1 0f          	and    $0xf,%r9b
 127573b:	41 80 f9 07          	cmp    $0x7,%r9b
 127573f:	75 26                	jne    1275767 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1c57>
 1275741:	4c 01 c6             	add    %r8,%rsi
 1275744:	80 7e 40 00          	cmpb   $0x0,0x40(%rsi)
 1275748:	74 1d                	je     1275767 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1c57>
 127574a:	48 39 5e 38          	cmp    %rbx,0x38(%rsi)
 127574e:	75 17                	jne    1275767 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1c57>
 1275750:	48 8b 74 24 68       	mov    0x68(%rsp),%rsi
 1275755:	48 39 b4 d1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rdx,8)
 127575c:	00 
 127575d:	75 08                	jne    1275767 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1c57>
 127575f:	c6 84 11 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rdx,1)
 1275766:	00 
 1275767:	48 85 db             	test   %rbx,%rbx
 127576a:	74 14                	je     1275780 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1c70>
 127576c:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1275770:	48 8b 74 24 68       	mov    0x68(%rsp),%rsi
 1275775:	48 89 da             	mov    %rbx,%rdx
 1275778:	31 c9                	xor    %ecx,%ecx
 127577a:	c5 f8 77             	vzeroupper 
 127577d:	ff 50 18             	call   *0x18(%rax)
 1275780:	80 bc 24 78 01 00 00 	cmpb   $0x0,0x178(%rsp)
 1275787:	00 
 1275788:	74 26                	je     12757b0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1ca0>
 127578a:	48 8b 84 24 60 01 00 	mov    0x160(%rsp),%rax
 1275791:	00 
 1275792:	48 69 8c 24 70 01 00 	imul   $0x118,0x170(%rsp),%rcx
 1275799:	00 18 01 00 00 
 127579e:	48 c7 44 08 68 24 bb 	movq   $0x112bb24,0x68(%rax,%rcx,1)
 12757a5:	12 01 
 12757a7:	48 c7 44 08 70 10 00 	movq   $0x10,0x70(%rax,%rcx,1)
 12757ae:	00 00 
 12757b0:	48 8d bc 24 40 01 00 	lea    0x140(%rsp),%rdi
 12757b7:	00 
 12757b8:	c5 f8 77             	vzeroupper 
 12757bb:	e8 b0 19 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 12757c0:	be 40 39 09 01       	mov    $0x1093940,%esi
 12757c5:	ba 68 01 00 00       	mov    $0x168,%edx
 12757ca:	48 8b 7c 24 50       	mov    0x50(%rsp),%rdi
 12757cf:	e8 8c 9f 06 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 12757d4:	e9 6f fe ff ff       	jmp    1275648 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1b38>
 12757d9:	49 89 f0             	mov    %rsi,%r8
 12757dc:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 12757e0:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 12757e4:	31 c0                	xor    %eax,%eax
 12757e6:	eb 1c                	jmp    1275804 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1cf4>
 12757e8:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 12757ef:	00 
 12757f0:	48 83 c0 02          	add    $0x2,%rax
 12757f4:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 12757fb:	49 39 c0             	cmp    %rax,%r8
 12757fe:	0f 84 29 fa ff ff    	je     127522d <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x171d>
 1275804:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 127580b:	00 
 127580c:	41 80 e3 0f          	and    $0xf,%r11b
 1275810:	41 80 fb 07          	cmp    $0x7,%r11b
 1275814:	75 2a                	jne    1275840 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1d30>
 1275816:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 127581b:	74 23                	je     1275840 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1d30>
 127581d:	49 39 1a             	cmp    %rbx,(%r10)
 1275820:	75 1e                	jne    1275840 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1d30>
 1275822:	4c 39 b4 c1 d0 32 02 	cmp    %r14,0x232d0(%rcx,%rax,8)
 1275829:	00 
 127582a:	75 14                	jne    1275840 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1d30>
 127582c:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1275833:	00 
 1275834:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 127583b:	00 00 00 00 00 
 1275840:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1275847:	00 
 1275848:	41 80 e3 0f          	and    $0xf,%r11b
 127584c:	41 80 fb 07          	cmp    $0x7,%r11b
 1275850:	75 9e                	jne    12757f0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1ce0>
 1275852:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1275859:	00 
 127585a:	74 94                	je     12757f0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1ce0>
 127585c:	49 39 9a 18 01 00 00 	cmp    %rbx,0x118(%r10)
 1275863:	75 8b                	jne    12757f0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1ce0>
 1275865:	4c 39 b4 c1 d8 32 02 	cmp    %r14,0x232d8(%rcx,%rax,8)
 127586c:	00 
 127586d:	75 81                	jne    12757f0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1ce0>
 127586f:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 1275876:	00 
 1275877:	e9 74 ff ff ff       	jmp    12757f0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1ce0>
 127587c:	49 89 f0             	mov    %rsi,%r8
 127587f:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1275883:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 1275887:	31 c0                	xor    %eax,%eax
 1275889:	eb 19                	jmp    12758a4 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1d94>
 127588b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 1275890:	48 83 c0 02          	add    $0x2,%rax
 1275894:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 127589b:	49 39 c0             	cmp    %rax,%r8
 127589e:	0f 84 b5 fc ff ff    	je     1275559 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1a49>
 12758a4:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 12758ab:	00 
 12758ac:	41 80 e3 0f          	and    $0xf,%r11b
 12758b0:	41 80 fb 07          	cmp    $0x7,%r11b
 12758b4:	75 2a                	jne    12758e0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1dd0>
 12758b6:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 12758bb:	74 23                	je     12758e0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1dd0>
 12758bd:	4d 39 22             	cmp    %r12,(%r10)
 12758c0:	75 1e                	jne    12758e0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1dd0>
 12758c2:	4c 8b 5c 24 10       	mov    0x10(%rsp),%r11
 12758c7:	4c 39 9c c1 d0 32 02 	cmp    %r11,0x232d0(%rcx,%rax,8)
 12758ce:	00 
 12758cf:	75 0f                	jne    12758e0 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1dd0>
 12758d1:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 12758d8:	00 
 12758d9:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)
 12758e0:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 12758e7:	00 
 12758e8:	41 80 e3 0f          	and    $0xf,%r11b
 12758ec:	41 80 fb 07          	cmp    $0x7,%r11b
 12758f0:	75 9e                	jne    1275890 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1d80>
 12758f2:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 12758f9:	00 
 12758fa:	74 94                	je     1275890 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1d80>
 12758fc:	4d 39 a2 18 01 00 00 	cmp    %r12,0x118(%r10)
 1275903:	75 8b                	jne    1275890 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1d80>
 1275905:	4c 8b 5c 24 10       	mov    0x10(%rsp),%r11
 127590a:	4c 39 9c c1 d8 32 02 	cmp    %r11,0x232d8(%rcx,%rax,8)
 1275911:	00 
 1275912:	0f 85 78 ff ff ff    	jne    1275890 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1d80>
 1275918:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 127591f:	00 
 1275920:	e9 6b ff ff ff       	jmp    1275890 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1d80>
 1275925:	4d 89 d8             	mov    %r11,%r8
 1275928:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 127592c:	4c 8d 49 58          	lea    0x58(%rcx),%r9
 1275930:	31 db                	xor    %ebx,%ebx
 1275932:	eb 20                	jmp    1275954 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1e44>
 1275934:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 127593b:	00 00 00 00 00 
 1275940:	48 83 c3 02          	add    $0x2,%rbx
 1275944:	49 81 c1 30 02 00 00 	add    $0x230,%r9
 127594b:	49 39 d8             	cmp    %rbx,%r8
 127594e:	0f 84 3b fd ff ff    	je     127568f <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1b7f>
 1275954:	45 0f b6 91 d8 00 00 	movzbl 0xd8(%r9),%r10d
 127595b:	00 
 127595c:	41 80 e2 0f          	and    $0xf,%r10b
 1275960:	41 80 fa 07          	cmp    $0x7,%r10b
 1275964:	75 2a                	jne    1275990 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1e80>
 1275966:	41 80 79 08 00       	cmpb   $0x0,0x8(%r9)
 127596b:	74 23                	je     1275990 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1e80>
 127596d:	49 39 11             	cmp    %rdx,(%r9)
 1275970:	75 1e                	jne    1275990 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1e80>
 1275972:	4c 39 a4 d9 d0 32 02 	cmp    %r12,0x232d0(%rcx,%rbx,8)
 1275979:	00 
 127597a:	75 14                	jne    1275990 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1e80>
 127597c:	c6 84 19 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rbx,1)
 1275983:	00 
 1275984:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 127598b:	00 00 00 00 00 
 1275990:	45 0f b6 91 f0 01 00 	movzbl 0x1f0(%r9),%r10d
 1275997:	00 
 1275998:	41 80 e2 0f          	and    $0xf,%r10b
 127599c:	41 80 fa 07          	cmp    $0x7,%r10b
 12759a0:	75 9e                	jne    1275940 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1e30>
 12759a2:	41 80 b9 20 01 00 00 	cmpb   $0x0,0x120(%r9)
 12759a9:	00 
 12759aa:	74 94                	je     1275940 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1e30>
 12759ac:	49 39 91 18 01 00 00 	cmp    %rdx,0x118(%r9)
 12759b3:	75 8b                	jne    1275940 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1e30>
 12759b5:	4c 39 a4 d9 d8 32 02 	cmp    %r12,0x232d8(%rcx,%rbx,8)
 12759bc:	00 
 12759bd:	75 81                	jne    1275940 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1e30>
 12759bf:	c6 84 19 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rbx,1)
 12759c6:	00 
 12759c7:	e9 74 ff ff ff       	jmp    1275940 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1e30>
 12759cc:	c5 fc 10 84 24 f0 02 	vmovups 0x2f0(%rsp),%ymm0
 12759d3:	00 00 
 12759d5:	c4 c1 7c 11 46 70    	vmovups %ymm0,0x70(%r14)
 12759db:	c5 fc 10 84 24 80 02 	vmovups 0x280(%rsp),%ymm0
 12759e2:	00 00 
 12759e4:	c5 fc 10 8c 24 a0 02 	vmovups 0x2a0(%rsp),%ymm1
 12759eb:	00 00 
 12759ed:	c5 fc 10 94 24 c0 02 	vmovups 0x2c0(%rsp),%ymm2
 12759f4:	00 00 
 12759f6:	c5 fc 10 9c 24 e0 02 	vmovups 0x2e0(%rsp),%ymm3
 12759fd:	00 00 
 12759ff:	c4 c1 7c 11 5e 60    	vmovups %ymm3,0x60(%r14)
 1275a05:	c4 c1 7c 11 56 40    	vmovups %ymm2,0x40(%r14)
 1275a0b:	c4 c1 7c 11 4e 20    	vmovups %ymm1,0x20(%r14)
 1275a11:	c4 c1 7c 11 06       	vmovups %ymm0,(%r14)
 1275a16:	48 8b 54 24 50       	mov    0x50(%rsp),%rdx
 1275a1b:	66 c7 82 60 01 00 00 	movw   $0x0,0x160(%rdx)
 1275a22:	00 00 
 1275a24:	48 8b 44 24 10       	mov    0x10(%rsp),%rax
 1275a29:	48 89 02             	mov    %rax,(%rdx)
 1275a2c:	4c 89 62 08          	mov    %r12,0x8(%rdx)
 1275a30:	8b 44 24 28          	mov    0x28(%rsp),%eax
 1275a34:	88 82 58 01 00 00    	mov    %al,0x158(%rdx)
 1275a3a:	48 8b 44 24 60       	mov    0x60(%rsp),%rax
 1275a3f:	48 89 42 10          	mov    %rax,0x10(%rdx)
 1275a43:	0f b6 44 24 30       	movzbl 0x30(%rsp),%eax
 1275a48:	88 42 18             	mov    %al,0x18(%rdx)
 1275a4b:	44 88 5a 19          	mov    %r11b,0x19(%rdx)
 1275a4f:	c5 fe 7f 6a 1a       	vmovdqu %ymm5,0x1a(%rdx)
 1275a54:	c5 fe 7f 62 3a       	vmovdqu %ymm4,0x3a(%rdx)
 1275a59:	8b 44 24 20          	mov    0x20(%rsp),%eax
 1275a5d:	89 42 5a             	mov    %eax,0x5a(%rdx)
 1275a60:	0f b7 44 24 24       	movzwl 0x24(%rsp),%eax
 1275a65:	66 89 42 5e          	mov    %ax,0x5e(%rdx)
 1275a69:	8b 44 24 38          	mov    0x38(%rsp),%eax
 1275a6d:	88 42 60             	mov    %al,0x60(%rdx)
 1275a70:	8b 44 24 78          	mov    0x78(%rsp),%eax
 1275a74:	8b 4c 24 7b          	mov    0x7b(%rsp),%ecx
 1275a78:	89 42 61             	mov    %eax,0x61(%rdx)
 1275a7b:	89 4a 64             	mov    %ecx,0x64(%rdx)
 1275a7e:	c5 fc 10 84 24 18 03 	vmovups 0x318(%rsp),%ymm0
 1275a85:	00 00 
 1275a87:	c5 fc 10 8c 24 38 03 	vmovups 0x338(%rsp),%ymm1
 1275a8e:	00 00 
 1275a90:	c5 fc 10 94 24 58 03 	vmovups 0x358(%rsp),%ymm2
 1275a97:	00 00 
 1275a99:	c5 fc 10 9c 24 78 03 	vmovups 0x378(%rsp),%ymm3
 1275aa0:	00 00 
 1275aa2:	c5 fc 11 42 68       	vmovups %ymm0,0x68(%rdx)
 1275aa7:	c5 fc 11 8a 88 00 00 	vmovups %ymm1,0x88(%rdx)
 1275aae:	00 
 1275aaf:	c5 fc 11 92 a8 00 00 	vmovups %ymm2,0xa8(%rdx)
 1275ab6:	00 
 1275ab7:	c5 fc 11 9a c8 00 00 	vmovups %ymm3,0xc8(%rdx)
 1275abe:	00 
 1275abf:	c5 fc 10 84 24 98 03 	vmovups 0x398(%rsp),%ymm0
 1275ac6:	00 00 
 1275ac8:	c5 fc 11 82 e8 00 00 	vmovups %ymm0,0xe8(%rdx)
 1275acf:	00 
 1275ad0:	c5 fc 10 84 24 b8 03 	vmovups 0x3b8(%rsp),%ymm0
 1275ad7:	00 00 
 1275ad9:	c5 fc 11 82 08 01 00 	vmovups %ymm0,0x108(%rdx)
 1275ae0:	00 
 1275ae1:	c5 fc 10 84 24 d8 03 	vmovups 0x3d8(%rsp),%ymm0
 1275ae8:	00 00 
 1275aea:	c5 fc 11 82 28 01 00 	vmovups %ymm0,0x128(%rdx)
 1275af1:	00 
 1275af2:	c5 fe 6f 84 24 e8 03 	vmovdqu 0x3e8(%rsp),%ymm0
 1275af9:	00 00 
 1275afb:	c5 fe 7f 82 38 01 00 	vmovdqu %ymm0,0x138(%rdx)
 1275b02:	00 
 1275b03:	40 80 e6 03          	and    $0x3,%sil
 1275b07:	40 88 b2 59 01 00 00 	mov    %sil,0x159(%rdx)
 1275b0e:	e9 14 fa ff ff       	jmp    1275527 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1a17>
 1275b13:	49 89 f0             	mov    %rsi,%r8
 1275b16:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1275b1a:	4c 8d 49 58          	lea    0x58(%rcx),%r9
 1275b1e:	31 d2                	xor    %edx,%edx
 1275b20:	eb 22                	jmp    1275b44 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x2034>
 1275b22:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1275b29:	1f 84 00 00 00 00 00 
 1275b30:	48 83 c2 02          	add    $0x2,%rdx
 1275b34:	49 81 c1 30 02 00 00 	add    $0x230,%r9
 1275b3b:	49 39 d0             	cmp    %rdx,%r8
 1275b3e:	0f 84 d9 fb ff ff    	je     127571d <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1c0d>
 1275b44:	45 0f b6 91 d8 00 00 	movzbl 0xd8(%r9),%r10d
 1275b4b:	00 
 1275b4c:	41 80 e2 0f          	and    $0xf,%r10b
 1275b50:	41 80 fa 07          	cmp    $0x7,%r10b
 1275b54:	75 2a                	jne    1275b80 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x2070>
 1275b56:	41 80 79 08 00       	cmpb   $0x0,0x8(%r9)
 1275b5b:	74 23                	je     1275b80 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x2070>
 1275b5d:	49 39 19             	cmp    %rbx,(%r9)
 1275b60:	75 1e                	jne    1275b80 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x2070>
 1275b62:	4c 8b 54 24 68       	mov    0x68(%rsp),%r10
 1275b67:	4c 39 94 d1 d0 32 02 	cmp    %r10,0x232d0(%rcx,%rdx,8)
 1275b6e:	00 
 1275b6f:	75 0f                	jne    1275b80 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x2070>
 1275b71:	c6 84 11 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rdx,1)
 1275b78:	00 
 1275b79:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)
 1275b80:	45 0f b6 91 f0 01 00 	movzbl 0x1f0(%r9),%r10d
 1275b87:	00 
 1275b88:	41 80 e2 0f          	and    $0xf,%r10b
 1275b8c:	41 80 fa 07          	cmp    $0x7,%r10b
 1275b90:	75 9e                	jne    1275b30 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x2020>
 1275b92:	41 80 b9 20 01 00 00 	cmpb   $0x0,0x120(%r9)
 1275b99:	00 
 1275b9a:	74 94                	je     1275b30 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x2020>
 1275b9c:	49 39 99 18 01 00 00 	cmp    %rbx,0x118(%r9)
 1275ba3:	75 8b                	jne    1275b30 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x2020>
 1275ba5:	4c 8b 54 24 68       	mov    0x68(%rsp),%r10
 1275baa:	4c 39 94 d1 d8 32 02 	cmp    %r10,0x232d8(%rcx,%rdx,8)
 1275bb1:	00 
 1275bb2:	0f 85 78 ff ff ff    	jne    1275b30 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x2020>
 1275bb8:	c6 84 11 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rdx,1)
 1275bbf:	00 
 1275bc0:	e9 6b ff ff ff       	jmp    1275b30 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x2020>
 1275bc5:	4c 89 f7             	mov    %r14,%rdi
 1275bc8:	4c 89 fe             	mov    %r15,%rsi
 1275bcb:	48 8b 54 24 10       	mov    0x10(%rsp),%rdx
 1275bd0:	4c 89 e1             	mov    %r12,%rcx
 1275bd3:	e8 c8 09 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 1275bd8:	80 bc 24 78 01 00 00 	cmpb   $0x0,0x178(%rsp)
 1275bdf:	00 
 1275be0:	74 27                	je     1275c09 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x20f9>
 1275be2:	48 8b 84 24 60 01 00 	mov    0x160(%rsp),%rax
 1275be9:	00 
 1275bea:	48 69 8c 24 70 01 00 	imul   $0x118,0x170(%rsp),%rcx
 1275bf1:	00 18 01 00 00 
 1275bf6:	89 da                	mov    %ebx,%edx
 1275bf8:	c1 e2 04             	shl    $0x4,%edx
 1275bfb:	c5 fa 6f 82 f0 5d 03 	vmovdqu 0x1035df0(%rdx),%xmm0
 1275c02:	01 
 1275c03:	c5 fa 7f 44 08 68    	vmovdqu %xmm0,0x68(%rax,%rcx,1)
 1275c09:	48 8d bc 24 40 01 00 	lea    0x140(%rsp),%rdi
 1275c10:	00 
 1275c11:	eb 3c                	jmp    1275c4f <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x213f>
 1275c13:	80 bc 24 78 01 00 00 	cmpb   $0x0,0x178(%rsp)
 1275c1a:	00 
 1275c1b:	74 27                	je     1275c44 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x2134>
 1275c1d:	48 8b 84 24 60 01 00 	mov    0x160(%rsp),%rax
 1275c24:	00 
 1275c25:	48 69 8c 24 70 01 00 	imul   $0x118,0x170(%rsp),%rcx
 1275c2c:	00 18 01 00 00 
 1275c31:	89 f2                	mov    %esi,%edx
 1275c33:	c1 e2 04             	shl    $0x4,%edx
 1275c36:	c5 fa 6f 82 f0 5d 03 	vmovdqu 0x1035df0(%rdx),%xmm0
 1275c3d:	01 
 1275c3e:	c5 fa 7f 44 08 68    	vmovdqu %xmm0,0x68(%rax,%rcx,1)
 1275c44:	48 8d bc 24 40 01 00 	lea    0x140(%rsp),%rdi
 1275c4b:	00 
 1275c4c:	48 89 f3             	mov    %rsi,%rbx
 1275c4f:	e8 1c 15 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 1275c54:	48 8b 44 24 50       	mov    0x50(%rsp),%rax
 1275c59:	66 89 98 60 01 00 00 	mov    %bx,0x160(%rax)
 1275c60:	e9 e3 f9 ff ff       	jmp    1275648 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1b38>
 1275c65:	80 bc 24 78 01 00 00 	cmpb   $0x0,0x178(%rsp)
 1275c6c:	00 
 1275c6d:	74 28                	je     1275c97 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x2187>
 1275c6f:	48 8b 84 24 60 01 00 	mov    0x160(%rsp),%rax
 1275c76:	00 
 1275c77:	48 69 8c 24 70 01 00 	imul   $0x118,0x170(%rsp),%rcx
 1275c7e:	00 18 01 00 00 
 1275c83:	44 89 f2             	mov    %r14d,%edx
 1275c86:	c1 e2 04             	shl    $0x4,%edx
 1275c89:	c5 fa 6f 82 f0 5d 03 	vmovdqu 0x1035df0(%rdx),%xmm0
 1275c90:	01 
 1275c91:	c5 fa 7f 44 08 68    	vmovdqu %xmm0,0x68(%rax,%rcx,1)
 1275c97:	48 8d bc 24 40 01 00 	lea    0x140(%rsp),%rdi
 1275c9e:	00 
 1275c9f:	e8 cc 14 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 1275ca4:	48 8b 44 24 50       	mov    0x50(%rsp),%rax
 1275ca9:	66 44 89 b0 60 01 00 	mov    %r14w,0x160(%rax)
 1275cb0:	00 
 1275cb1:	e9 92 f9 ff ff       	jmp    1275648 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x1b38>
 1275cb6:	48 8b bc 24 98 00 00 	mov    0x98(%rsp),%rdi
 1275cbd:	00 
 1275cbe:	4c 89 f6             	mov    %r14,%rsi
 1275cc1:	48 8b 54 24 10       	mov    0x10(%rsp),%rdx
 1275cc6:	48 8b 4c 24 40       	mov    0x40(%rsp),%rcx
 1275ccb:	e8 d0 08 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 1275cd0:	80 bc 24 78 01 00 00 	cmpb   $0x0,0x178(%rsp)
 1275cd7:	00 
 1275cd8:	0f 85 04 ff ff ff    	jne    1275be2 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x20d2>
 1275cde:	e9 26 ff ff ff       	jmp    1275c09 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x20f9>
 1275ce3:	4c 89 ef             	mov    %r13,%rdi
 1275ce6:	e9 dd fe ff ff       	jmp    1275bc8 <br.encodePreferredCommandPlanAllocRecorded__anon_231663+0x20b8>

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
