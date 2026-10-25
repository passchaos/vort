
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/d54ab236499589e8c9225c90450b9b10/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

0000000001282c90 <br.encodePlannedStreamWithOptionsAlloc>:
 1282c90:	55                   	push   %rbp
 1282c91:	48 89 e5             	mov    %rsp,%rbp
 1282c94:	41 57                	push   %r15
 1282c96:	41 56                	push   %r14
 1282c98:	41 55                	push   %r13
 1282c9a:	41 54                	push   %r12
 1282c9c:	53                   	push   %rbx
 1282c9d:	48 81 ec 28 06 00 00 	sub    $0x628,%rsp
 1282ca4:	4d 89 c7             	mov    %r8,%r15
 1282ca7:	48 89 55 80          	mov    %rdx,-0x80(%rbp)
 1282cab:	48 89 75 90          	mov    %rsi,-0x70(%rbp)
 1282caf:	48 89 7d d0          	mov    %rdi,-0x30(%rbp)
 1282cb3:	45 0f b6 68 50       	movzbl 0x50(%r8),%r13d
 1282cb8:	4d 8b 70 68          	mov    0x68(%r8),%r14
 1282cbc:	49 8b 58 70          	mov    0x70(%r8),%rbx
 1282cc0:	49 8b 40 78          	mov    0x78(%r8),%rax
 1282cc4:	48 89 85 68 ff ff ff 	mov    %rax,-0x98(%rbp)
 1282ccb:	41 0f b6 80 82 00 00 	movzbl 0x82(%r8),%eax
 1282cd2:	00 
 1282cd3:	88 45 88             	mov    %al,-0x78(%rbp)
 1282cd6:	45 0f b6 a0 83 00 00 	movzbl 0x83(%r8),%r12d
 1282cdd:	00 
 1282cde:	41 0f b6 80 84 00 00 	movzbl 0x84(%r8),%eax
 1282ce5:	00 
 1282ce6:	88 45 98             	mov    %al,-0x68(%rbp)
 1282ce9:	48 89 8d 60 ff ff ff 	mov    %rcx,-0xa0(%rbp)
 1282cf0:	48 89 cf             	mov    %rcx,%rdi
 1282cf3:	4c 89 c6             	mov    %r8,%rsi
 1282cf6:	e8 55 c6 ff ff       	call   127f350 <br.validatePlannedEncodeOptions>
 1282cfb:	66 85 c0             	test   %ax,%ax
 1282cfe:	0f 85 4d 10 00 00    	jne    1283d51 <br.encodePlannedStreamWithOptionsAlloc+0x10c1>
 1282d04:	41 80 7f 08 00       	cmpb   $0x0,0x8(%r15)
 1282d09:	49 8b 4f 10          	mov    0x10(%r15),%rcx
 1282d0d:	0f 95 c0             	setne  %al
 1282d10:	48 85 c9             	test   %rcx,%rcx
 1282d13:	0f 95 c2             	setne  %dl
 1282d16:	08 c2                	or     %al,%dl
 1282d18:	80 fa 01             	cmp    $0x1,%dl
 1282d1b:	0f 85 a8 00 00 00    	jne    1282dc9 <br.encodePlannedStreamWithOptionsAlloc+0x139>
 1282d21:	48 8d 85 10 ff ff ff 	lea    -0xf0(%rbp),%rax
 1282d28:	45 84 ed             	test   %r13b,%r13b
 1282d2b:	0f 84 4b 02 00 00    	je     1282f7c <br.encodePlannedStreamWithOptionsAlloc+0x2ec>
 1282d31:	49 8b 5f 28          	mov    0x28(%r15),%rbx
 1282d35:	48 89 9d 08 ff ff ff 	mov    %rbx,-0xf8(%rbp)
 1282d3c:	48 85 db             	test   %rbx,%rbx
 1282d3f:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 1282d43:	0f 84 42 02 00 00    	je     1282f8b <br.encodePlannedStreamWithOptionsAlloc+0x2fb>
 1282d49:	4c 8b 93 c8 00 00 00 	mov    0xc8(%rbx),%r10
 1282d50:	4c 8b 8b d0 00 00 00 	mov    0xd0(%rbx),%r9
 1282d57:	4c 8b 83 d8 00 00 00 	mov    0xd8(%rbx),%r8
 1282d5e:	48 8b bb e0 00 00 00 	mov    0xe0(%rbx),%rdi
 1282d65:	48 8b 93 e8 00 00 00 	mov    0xe8(%rbx),%rdx
 1282d6c:	48 8b 83 f0 00 00 00 	mov    0xf0(%rbx),%rax
 1282d73:	4c 89 95 58 ff ff ff 	mov    %r10,-0xa8(%rbp)
 1282d7a:	4c 89 95 10 ff ff ff 	mov    %r10,-0xf0(%rbp)
 1282d81:	4c 89 8d 50 ff ff ff 	mov    %r9,-0xb0(%rbp)
 1282d88:	4c 89 8d 18 ff ff ff 	mov    %r9,-0xe8(%rbp)
 1282d8f:	4c 89 85 48 ff ff ff 	mov    %r8,-0xb8(%rbp)
 1282d96:	4c 89 85 20 ff ff ff 	mov    %r8,-0xe0(%rbp)
 1282d9d:	48 89 bd 40 ff ff ff 	mov    %rdi,-0xc0(%rbp)
 1282da4:	48 89 bd 28 ff ff ff 	mov    %rdi,-0xd8(%rbp)
 1282dab:	48 89 95 68 ff ff ff 	mov    %rdx,-0x98(%rbp)
 1282db2:	48 89 95 30 ff ff ff 	mov    %rdx,-0xd0(%rbp)
 1282db9:	48 89 45 98          	mov    %rax,-0x68(%rbp)
 1282dbd:	48 89 85 38 ff ff ff 	mov    %rax,-0xc8(%rbp)
 1282dc4:	e9 22 02 00 00       	jmp    1282feb <br.encodePlannedStreamWithOptionsAlloc+0x35b>
 1282dc9:	49 8d 7f 68          	lea    0x68(%r15),%rdi
 1282dcd:	45 84 ed             	test   %r13b,%r13b
 1282dd0:	0f 84 7e 02 00 00    	je     1283054 <br.encodePlannedStreamWithOptionsAlloc+0x3c4>
 1282dd6:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 1282dda:	48 89 85 d0 fe ff ff 	mov    %rax,-0x130(%rbp)
 1282de1:	48 8b 85 60 ff ff ff 	mov    -0xa0(%rbp),%rax
 1282de8:	48 89 85 d8 fe ff ff 	mov    %rax,-0x128(%rbp)
 1282def:	4d 8b 57 58          	mov    0x58(%r15),%r10
 1282df3:	49 8b 5f 60          	mov    0x60(%r15),%rbx
 1282df7:	45 0f b7 8f 83 00 00 	movzwl 0x83(%r15),%r9d
 1282dfe:	00 
 1282dff:	45 0f b6 b7 85 00 00 	movzbl 0x85(%r15),%r14d
 1282e06:	00 
 1282e07:	41 0f b6 87 86 00 00 	movzbl 0x86(%r15),%eax
 1282e0e:	00 
 1282e0f:	45 0f b6 a7 8f 00 00 	movzbl 0x8f(%r15),%r12d
 1282e16:	00 
 1282e17:	0f b6 4d 88          	movzbl -0x78(%rbp),%ecx
 1282e1b:	80 e1 03             	and    $0x3,%cl
 1282e1e:	88 4d c0             	mov    %cl,-0x40(%rbp)
 1282e21:	44 89 f1             	mov    %r14d,%ecx
 1282e24:	80 e1 01             	and    $0x1,%cl
 1282e27:	88 4d a7             	mov    %cl,-0x59(%rbp)
 1282e2a:	24 03                	and    $0x3,%al
 1282e2c:	88 45 ac             	mov    %al,-0x54(%rbp)
 1282e2f:	41 0f b6 87 87 00 00 	movzbl 0x87(%r15),%eax
 1282e36:	00 
 1282e37:	45 0f b6 af 88 00 00 	movzbl 0x88(%r15),%r13d
 1282e3e:	00 
 1282e3f:	41 81 f9 00 01 00 00 	cmp    $0x100,%r9d
 1282e46:	0f 83 0f 06 00 00    	jae    128345b <br.encodePlannedStreamWithOptionsAlloc+0x7cb>
 1282e4c:	45 84 ed             	test   %r13b,%r13b
 1282e4f:	0f b6 c8             	movzbl %al,%ecx
 1282e52:	b8 10 00 00 00       	mov    $0x10,%eax
 1282e57:	0f 45 c1             	cmovne %ecx,%eax
 1282e5a:	89 c2                	mov    %eax,%edx
 1282e5c:	80 e2 1f             	and    $0x1f,%dl
 1282e5f:	41 f6 c6 01          	test   $0x1,%r14b
 1282e63:	b9 fe 00 00 00       	mov    $0xfe,%ecx
 1282e68:	be f8 00 00 00       	mov    $0xf8,%esi
 1282e6d:	0f 45 f1             	cmovne %ecx,%esi
 1282e70:	66 b9 1f 00          	mov    $0x1f,%cx
 1282e74:	80 fa 0a             	cmp    $0xa,%dl
 1282e77:	0f 82 0a 09 00 00    	jb     1283787 <br.encodePlannedStreamWithOptionsAlloc+0xaf7>
 1282e7d:	40 80 e6 1f          	and    $0x1f,%sil
 1282e81:	40 38 f2             	cmp    %sil,%dl
 1282e84:	0f 87 fd 08 00 00    	ja     1283787 <br.encodePlannedStreamWithOptionsAlloc+0xaf7>
 1282e8a:	24 1f                	and    $0x1f,%al
 1282e8c:	88 45 c8             	mov    %al,-0x38(%rbp)
 1282e8f:	c5 f8 10 07          	vmovups (%rdi),%xmm0
 1282e93:	c5 f8 29 85 30 fd ff 	vmovaps %xmm0,-0x2d0(%rbp)
 1282e9a:	ff 
 1282e9b:	48 8b 47 10          	mov    0x10(%rdi),%rax
 1282e9f:	48 89 85 40 fd ff ff 	mov    %rax,-0x2c0(%rbp)
 1282ea6:	c4 c1 78 10 07       	vmovups (%r15),%xmm0
 1282eab:	49 83 c7 18          	add    $0x18,%r15
 1282eaf:	c5 f8 29 85 c0 fc ff 	vmovaps %xmm0,-0x340(%rbp)
 1282eb6:	ff 
 1282eb7:	48 c7 85 d0 fc ff ff 	movq   $0x0,-0x330(%rbp)
 1282ebe:	00 00 00 00 
 1282ec2:	c4 c1 7c 10 07       	vmovups (%r15),%ymm0
 1282ec7:	c4 c1 7c 10 4f 20    	vmovups 0x20(%r15),%ymm1
 1282ecd:	c5 fc 11 85 d8 fc ff 	vmovups %ymm0,-0x328(%rbp)
 1282ed4:	ff 
 1282ed5:	c5 fc 11 8d f8 fc ff 	vmovups %ymm1,-0x308(%rbp)
 1282edc:	ff 
 1282edd:	48 c7 85 18 fd ff ff 	movq   $0x0,-0x2e8(%rbp)
 1282ee4:	00 00 00 00 
 1282ee8:	4c 89 95 20 fd ff ff 	mov    %r10,-0x2e0(%rbp)
 1282eef:	48 89 9d 28 fd ff ff 	mov    %rbx,-0x2d8(%rbp)
 1282ef6:	0f b6 45 c0          	movzbl -0x40(%rbp),%eax
 1282efa:	88 85 48 fd ff ff    	mov    %al,-0x2b8(%rbp)
 1282f00:	66 44 89 8d 49 fd ff 	mov    %r9w,-0x2b7(%rbp)
 1282f07:	ff 
 1282f08:	0f b6 45 a7          	movzbl -0x59(%rbp),%eax
 1282f0c:	88 85 4b fd ff ff    	mov    %al,-0x2b5(%rbp)
 1282f12:	0f b6 45 ac          	movzbl -0x54(%rbp),%eax
 1282f16:	88 85 4c fd ff ff    	mov    %al,-0x2b4(%rbp)
 1282f1c:	66 c7 85 4d fd ff ff 	movw   $0x0,-0x2b3(%rbp)
 1282f23:	00 00 
 1282f25:	44 88 a5 4f fd ff ff 	mov    %r12b,-0x2b1(%rbp)
 1282f2c:	0f b6 45 c8          	movzbl -0x38(%rbp),%eax
 1282f30:	88 85 50 fd ff ff    	mov    %al,-0x2b0(%rbp)
 1282f36:	48 8d bd a8 fd ff ff 	lea    -0x258(%rbp),%rdi
 1282f3d:	48 8d 95 d0 fe ff ff 	lea    -0x130(%rbp),%rdx
 1282f44:	4c 8d 85 c0 fc ff ff 	lea    -0x340(%rbp),%r8
 1282f4b:	b9 01 00 00 00       	mov    $0x1,%ecx
 1282f50:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 1282f54:	c5 f8 77             	vzeroupper 
 1282f57:	e8 04 d7 fd ff       	call   1260660 <br.encodeHqWholeStreamAlloc>
 1282f5c:	48 8b 85 b8 fd ff ff 	mov    -0x248(%rbp),%rax
 1282f63:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 1282f67:	48 89 41 10          	mov    %rax,0x10(%rcx)
 1282f6b:	c5 f8 10 85 a8 fd ff 	vmovups -0x258(%rbp),%xmm0
 1282f72:	ff 
 1282f73:	c5 f8 11 01          	vmovups %xmm0,(%rcx)
 1282f77:	e9 3c 08 00 00       	jmp    12837b8 <br.encodePlannedStreamWithOptionsAlloc+0xb28>
 1282f7c:	48 c7 85 08 ff ff ff 	movq   $0x0,-0xf8(%rbp)
 1282f83:	00 00 00 00 
 1282f87:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 1282f8b:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1282f8f:	c5 fc 11 40 10       	vmovups %ymm0,0x10(%rax)
 1282f94:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1282f98:	48 8b 85 10 ff ff ff 	mov    -0xf0(%rbp),%rax
 1282f9f:	48 89 85 58 ff ff ff 	mov    %rax,-0xa8(%rbp)
 1282fa6:	48 8b 85 18 ff ff ff 	mov    -0xe8(%rbp),%rax
 1282fad:	48 89 85 50 ff ff ff 	mov    %rax,-0xb0(%rbp)
 1282fb4:	48 8b 85 20 ff ff ff 	mov    -0xe0(%rbp),%rax
 1282fbb:	48 89 85 48 ff ff ff 	mov    %rax,-0xb8(%rbp)
 1282fc2:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 1282fc9:	48 89 85 40 ff ff ff 	mov    %rax,-0xc0(%rbp)
 1282fd0:	48 8b 85 30 ff ff ff 	mov    -0xd0(%rbp),%rax
 1282fd7:	48 89 85 68 ff ff ff 	mov    %rax,-0x98(%rbp)
 1282fde:	31 db                	xor    %ebx,%ebx
 1282fe0:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 1282fe7:	48 89 45 98          	mov    %rax,-0x68(%rbp)
 1282feb:	c4 c1 78 10 07       	vmovups (%r15),%xmm0
 1282ff0:	c5 f8 29 85 c0 fd ff 	vmovaps %xmm0,-0x240(%rbp)
 1282ff7:	ff 
 1282ff8:	48 8d bd d8 fd ff ff 	lea    -0x228(%rbp),%rdi
 1282fff:	48 8d 95 c0 fd ff ff 	lea    -0x240(%rbp),%rdx
 1283006:	45 31 c0             	xor    %r8d,%r8d
 1283009:	c5 f8 77             	vzeroupper 
 128300c:	e8 8f 6c f6 ff       	call   11e9ca0 <br.encoder.total_budget.Lease.init>
 1283011:	44 0f b7 b5 f8 fd ff 	movzwl -0x208(%rbp),%r14d
 1283018:	ff 
 1283019:	66 45 85 f6          	test   %r14w,%r14w
 128301d:	0f 85 13 06 00 00    	jne    1283636 <br.encodePlannedStreamWithOptionsAlloc+0x9a6>
 1283023:	48 8b 85 e8 fd ff ff 	mov    -0x218(%rbp),%rax
 128302a:	48 85 c0             	test   %rax,%rax
 128302d:	48 89 5d 88          	mov    %rbx,-0x78(%rbp)
 1283031:	0f 84 e0 01 00 00    	je     1283217 <br.encodePlannedStreamWithOptionsAlloc+0x587>
 1283037:	49 89 c4             	mov    %rax,%r12
 128303a:	48 89 85 30 fe ff ff 	mov    %rax,-0x1d0(%rbp)
 1283041:	48 8d 05 b0 14 06 00 	lea    0x614b0(%rip),%rax        # 12e44f8 <br.encoder.total_budget.state.State.vtable>
 1283048:	48 89 85 38 fe ff ff 	mov    %rax,-0x1c8(%rbp)
 128304f:	e9 d6 01 00 00       	jmp    128322a <br.encodePlannedStreamWithOptionsAlloc+0x59a>
 1283054:	4c 8b ad 60 ff ff ff 	mov    -0xa0(%rbp),%r13
 128305b:	49 81 fd 00 00 00 01 	cmp    $0x1000000,%r13
 1283062:	77 14                	ja     1283078 <br.encodePlannedStreamWithOptionsAlloc+0x3e8>
 1283064:	80 7d 98 00          	cmpb   $0x0,-0x68(%rbp)
 1283068:	0f 84 cd 06 00 00    	je     128373b <br.encodePlannedStreamWithOptionsAlloc+0xaab>
 128306e:	41 80 e4 0c          	and    $0xc,%r12b
 1283072:	0f 85 c3 06 00 00    	jne    128373b <br.encodePlannedStreamWithOptionsAlloc+0xaab>
 1283078:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 128307c:	48 89 85 c0 fe ff ff 	mov    %rax,-0x140(%rbp)
 1283083:	4c 89 ad c8 fe ff ff 	mov    %r13,-0x138(%rbp)
 128308a:	4d 8b 57 58          	mov    0x58(%r15),%r10
 128308e:	49 8b 5f 60          	mov    0x60(%r15),%rbx
 1283092:	45 0f b7 8f 83 00 00 	movzwl 0x83(%r15),%r9d
 1283099:	00 
 128309a:	45 0f b6 b7 85 00 00 	movzbl 0x85(%r15),%r14d
 12830a1:	00 
 12830a2:	41 0f b6 87 86 00 00 	movzbl 0x86(%r15),%eax
 12830a9:	00 
 12830aa:	45 0f b6 a7 8f 00 00 	movzbl 0x8f(%r15),%r12d
 12830b1:	00 
 12830b2:	0f b6 4d 88          	movzbl -0x78(%rbp),%ecx
 12830b6:	80 e1 03             	and    $0x3,%cl
 12830b9:	88 4d b0             	mov    %cl,-0x50(%rbp)
 12830bc:	44 89 f1             	mov    %r14d,%ecx
 12830bf:	80 e1 01             	and    $0x1,%cl
 12830c2:	88 4d a6             	mov    %cl,-0x5a(%rbp)
 12830c5:	24 03                	and    $0x3,%al
 12830c7:	88 45 a8             	mov    %al,-0x58(%rbp)
 12830ca:	41 0f b6 87 87 00 00 	movzbl 0x87(%r15),%eax
 12830d1:	00 
 12830d2:	45 0f b6 af 88 00 00 	movzbl 0x88(%r15),%r13d
 12830d9:	00 
 12830da:	41 81 f9 00 01 00 00 	cmp    $0x100,%r9d
 12830e1:	0f 83 22 04 00 00    	jae    1283509 <br.encodePlannedStreamWithOptionsAlloc+0x879>
 12830e7:	45 84 ed             	test   %r13b,%r13b
 12830ea:	0f b6 c8             	movzbl %al,%ecx
 12830ed:	b8 10 00 00 00       	mov    $0x10,%eax
 12830f2:	0f 45 c1             	cmovne %ecx,%eax
 12830f5:	89 c2                	mov    %eax,%edx
 12830f7:	80 e2 1f             	and    $0x1f,%dl
 12830fa:	41 f6 c6 01          	test   $0x1,%r14b
 12830fe:	b9 fe 00 00 00       	mov    $0xfe,%ecx
 1283103:	be f8 00 00 00       	mov    $0xf8,%esi
 1283108:	0f 45 f1             	cmovne %ecx,%esi
 128310b:	66 b9 1f 00          	mov    $0x1f,%cx
 128310f:	80 fa 0a             	cmp    $0xa,%dl
 1283112:	0f 82 6f 06 00 00    	jb     1283787 <br.encodePlannedStreamWithOptionsAlloc+0xaf7>
 1283118:	40 80 e6 1f          	and    $0x1f,%sil
 128311c:	40 38 f2             	cmp    %sil,%dl
 128311f:	0f 87 62 06 00 00    	ja     1283787 <br.encodePlannedStreamWithOptionsAlloc+0xaf7>
 1283125:	24 1f                	and    $0x1f,%al
 1283127:	88 45 b8             	mov    %al,-0x48(%rbp)
 128312a:	c5 f8 10 07          	vmovups (%rdi),%xmm0
 128312e:	c5 f8 29 85 90 fc ff 	vmovaps %xmm0,-0x370(%rbp)
 1283135:	ff 
 1283136:	48 8b 47 10          	mov    0x10(%rdi),%rax
 128313a:	48 89 85 a0 fc ff ff 	mov    %rax,-0x360(%rbp)
 1283141:	c4 c1 78 10 07       	vmovups (%r15),%xmm0
 1283146:	49 83 c7 18          	add    $0x18,%r15
 128314a:	c5 f8 29 85 20 fc ff 	vmovaps %xmm0,-0x3e0(%rbp)
 1283151:	ff 
 1283152:	48 c7 85 30 fc ff ff 	movq   $0x0,-0x3d0(%rbp)
 1283159:	00 00 00 00 
 128315d:	c4 c1 7c 10 07       	vmovups (%r15),%ymm0
 1283162:	c4 c1 7c 10 4f 20    	vmovups 0x20(%r15),%ymm1
 1283168:	c5 fc 11 85 38 fc ff 	vmovups %ymm0,-0x3c8(%rbp)
 128316f:	ff 
 1283170:	c5 fc 11 8d 58 fc ff 	vmovups %ymm1,-0x3a8(%rbp)
 1283177:	ff 
 1283178:	48 c7 85 78 fc ff ff 	movq   $0x0,-0x388(%rbp)
 128317f:	00 00 00 00 
 1283183:	4c 89 95 80 fc ff ff 	mov    %r10,-0x380(%rbp)
 128318a:	48 89 9d 88 fc ff ff 	mov    %rbx,-0x378(%rbp)
 1283191:	0f b6 45 b0          	movzbl -0x50(%rbp),%eax
 1283195:	88 85 a8 fc ff ff    	mov    %al,-0x358(%rbp)
 128319b:	66 44 89 8d a9 fc ff 	mov    %r9w,-0x357(%rbp)
 12831a2:	ff 
 12831a3:	0f b6 45 a6          	movzbl -0x5a(%rbp),%eax
 12831a7:	88 85 ab fc ff ff    	mov    %al,-0x355(%rbp)
 12831ad:	0f b6 45 a8          	movzbl -0x58(%rbp),%eax
 12831b1:	88 85 ac fc ff ff    	mov    %al,-0x354(%rbp)
 12831b7:	66 c7 85 ad fc ff ff 	movw   $0x0,-0x353(%rbp)
 12831be:	00 00 
 12831c0:	44 88 a5 af fc ff ff 	mov    %r12b,-0x351(%rbp)
 12831c7:	0f b6 45 b8          	movzbl -0x48(%rbp),%eax
 12831cb:	88 85 b0 fc ff ff    	mov    %al,-0x350(%rbp)
 12831d1:	48 8d bd 90 fd ff ff 	lea    -0x270(%rbp),%rdi
 12831d8:	48 8d 95 c0 fe ff ff 	lea    -0x140(%rbp),%rdx
 12831df:	4c 8d 85 20 fc ff ff 	lea    -0x3e0(%rbp),%r8
 12831e6:	b9 01 00 00 00       	mov    $0x1,%ecx
 12831eb:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 12831ef:	c5 f8 77             	vzeroupper 
 12831f2:	e8 89 9e ff ff       	call   127d080 <br.encodePlannedStreamChunksWithOptionsAlloc>
 12831f7:	48 8b 85 a0 fd ff ff 	mov    -0x260(%rbp),%rax
 12831fe:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 1283202:	48 89 41 10          	mov    %rax,0x10(%rcx)
 1283206:	c5 f8 10 85 90 fd ff 	vmovups -0x270(%rbp),%xmm0
 128320d:	ff 
 128320e:	c5 f8 11 01          	vmovups %xmm0,(%rcx)
 1283212:	e9 a1 05 00 00       	jmp    12837b8 <br.encodePlannedStreamWithOptionsAlloc+0xb28>
 1283217:	49 89 c4             	mov    %rax,%r12
 128321a:	c5 f8 10 85 d8 fd ff 	vmovups -0x228(%rbp),%xmm0
 1283221:	ff 
 1283222:	c5 f8 29 85 30 fe ff 	vmovaps %xmm0,-0x1d0(%rbp)
 1283229:	ff 
 128322a:	48 8d 85 30 fe ff ff 	lea    -0x1d0(%rbp),%rax
 1283231:	48 8b 8d d8 fd ff ff 	mov    -0x228(%rbp),%rcx
 1283238:	48 89 8d e8 fe ff ff 	mov    %rcx,-0x118(%rbp)
 128323f:	4c 8b ad e0 fd ff ff 	mov    -0x220(%rbp),%r13
 1283246:	c5 f8 10 00          	vmovups (%rax),%xmm0
 128324a:	c5 f8 29 85 f0 fe ff 	vmovaps %xmm0,-0x110(%rbp)
 1283251:	ff 
 1283252:	48 8b 85 f0 fe ff ff 	mov    -0x110(%rbp),%rax
 1283259:	48 89 85 e0 fe ff ff 	mov    %rax,-0x120(%rbp)
 1283260:	48 8b 9d f8 fe ff ff 	mov    -0x108(%rbp),%rbx
 1283267:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 128326b:	c5 f8 29 85 30 fe ff 	vmovaps %xmm0,-0x1d0(%rbp)
 1283272:	ff 
 1283273:	48 c7 85 40 fe ff ff 	movq   $0x0,-0x1c0(%rbp)
 128327a:	00 00 00 00 
 128327e:	c4 c1 7c 10 47 18    	vmovups 0x18(%r15),%ymm0
 1283284:	c4 c1 7c 10 4f 38    	vmovups 0x38(%r15),%ymm1
 128328a:	c4 c1 7c 10 57 58    	vmovups 0x58(%r15),%ymm2
 1283290:	c4 c1 7c 10 5f 70    	vmovups 0x70(%r15),%ymm3
 1283296:	c5 fc 11 85 48 fe ff 	vmovups %ymm0,-0x1b8(%rbp)
 128329d:	ff 
 128329e:	c5 fc 11 8d 68 fe ff 	vmovups %ymm1,-0x198(%rbp)
 12832a5:	ff 
 12832a6:	c5 fc 11 95 88 fe ff 	vmovups %ymm2,-0x178(%rbp)
 12832ad:	ff 
 12832ae:	c5 fc 11 9d a0 fe ff 	vmovups %ymm3,-0x160(%rbp)
 12832b5:	ff 
 12832b6:	48 8d bd 00 fe ff ff 	lea    -0x200(%rbp),%rdi
 12832bd:	48 8d b5 f0 fe ff ff 	lea    -0x110(%rbp),%rsi
 12832c4:	4c 8d 85 30 fe ff ff 	lea    -0x1d0(%rbp),%r8
 12832cb:	48 8b 55 80          	mov    -0x80(%rbp),%rdx
 12832cf:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 12832d6:	c5 f8 77             	vzeroupper 
 12832d9:	e8 b2 f9 ff ff       	call   1282c90 <br.encodePlannedStreamWithOptionsAlloc>
 12832de:	44 0f b7 b5 10 fe ff 	movzwl -0x1f0(%rbp),%r14d
 12832e5:	ff 
 12832e6:	41 83 fe 1a          	cmp    $0x1a,%r14d
 12832ea:	74 4c                	je     1283338 <br.encodePlannedStreamWithOptionsAlloc+0x6a8>
 12832ec:	45 85 f6             	test   %r14d,%r14d
 12832ef:	0f 85 df 00 00 00    	jne    12833d4 <br.encodePlannedStreamWithOptionsAlloc+0x744>
 12832f5:	49 89 da             	mov    %rbx,%r10
 12832f8:	48 8b 9d 00 fe ff ff 	mov    -0x200(%rbp),%rbx
 12832ff:	4c 8b bd 08 fe ff ff 	mov    -0x1f8(%rbp),%r15
 1283306:	4d 85 e4             	test   %r12,%r12
 1283309:	0f 84 70 02 00 00    	je     128357f <br.encodePlannedStreamWithOptionsAlloc+0x8ef>
 128330f:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 1283313:	48 8b 46 08          	mov    0x8(%rsi),%rax
 1283317:	48 8d 0d da 11 06 00 	lea    0x611da(%rip),%rcx        # 12e44f8 <br.encoder.total_budget.state.State.vtable>
 128331e:	48 39 c8             	cmp    %rcx,%rax
 1283321:	0f 85 c6 02 00 00    	jne    12835ed <br.encodePlannedStreamWithOptionsAlloc+0x95d>
 1283327:	48 8b 0e             	mov    (%rsi),%rcx
 128332a:	4c 39 e1             	cmp    %r12,%rcx
 128332d:	0f 85 c5 02 00 00    	jne    12835f8 <br.encodePlannedStreamWithOptionsAlloc+0x968>
 1283333:	e9 66 04 00 00       	jmp    128379e <br.encodePlannedStreamWithOptionsAlloc+0xb0e>
 1283338:	4d 85 e4             	test   %r12,%r12
 128333b:	48 8b 5d 88          	mov    -0x78(%rbp),%rbx
 128333f:	0f 84 44 02 00 00    	je     1283589 <br.encodePlannedStreamWithOptionsAlloc+0x8f9>
 1283345:	41 80 7c 24 49 00    	cmpb   $0x0,0x49(%r12)
 128334b:	b8 65 00 00 00       	mov    $0x65,%eax
 1283350:	41 be 1a 00 00 00    	mov    $0x1a,%r14d
 1283356:	44 0f 45 f0          	cmovne %eax,%r14d
 128335a:	49 ff 4c 24 40       	decq   0x40(%r12)
 128335f:	0f 85 29 02 00 00    	jne    128358e <br.encodePlannedStreamWithOptionsAlloc+0x8fe>
 1283365:	49 8b 44 24 28       	mov    0x28(%r12),%rax
 128336a:	48 83 f8 50          	cmp    $0x50,%rax
 128336e:	0f 85 c1 04 00 00    	jne    1283835 <br.encodePlannedStreamWithOptionsAlloc+0xba5>
 1283374:	49 83 7c 24 38 00    	cmpq   $0x0,0x38(%r12)
 128337a:	0f 85 0e 02 00 00    	jne    128358e <br.encodePlannedStreamWithOptionsAlloc+0x8fe>
 1283380:	49 8b 3c 24          	mov    (%r12),%rdi
 1283384:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 1283389:	49 8b 4c 24 20       	mov    0x20(%r12),%rcx
 128338e:	48 85 c9             	test   %rcx,%rcx
 1283391:	74 28                	je     12833bb <br.encodePlannedStreamWithOptionsAlloc+0x72b>
 1283393:	c4 c1 78 10 44 24 10 	vmovups 0x10(%r12),%xmm0
 128339a:	c5 f8 29 85 70 ff ff 	vmovaps %xmm0,-0x90(%rbp)
 12833a1:	ff 
 12833a2:	c6 41 20 01          	movb   $0x1,0x20(%rcx)
 12833a6:	48 c7 41 08 00 00 00 	movq   $0x0,0x8(%rcx)
 12833ad:	00 
 12833ae:	c5 f8 28 85 70 ff ff 	vmovaps -0x90(%rbp),%xmm0
 12833b5:	ff 
 12833b6:	c5 f8 11 41 10       	vmovups %xmm0,0x10(%rcx)
 12833bb:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12833bf:	ba 50 00 00 00       	mov    $0x50,%edx
 12833c4:	4c 89 e6             	mov    %r12,%rsi
 12833c7:	b9 03 00 00 00       	mov    $0x3,%ecx
 12833cc:	ff 50 18             	call   *0x18(%rax)
 12833cf:	e9 ba 01 00 00       	jmp    128358e <br.encodePlannedStreamWithOptionsAlloc+0x8fe>
 12833d4:	4d 85 e4             	test   %r12,%r12
 12833d7:	48 8b 5d 88          	mov    -0x78(%rbp),%rbx
 12833db:	0f 84 55 02 00 00    	je     1283636 <br.encodePlannedStreamWithOptionsAlloc+0x9a6>
 12833e1:	49 ff 4c 24 40       	decq   0x40(%r12)
 12833e6:	0f 85 4a 02 00 00    	jne    1283636 <br.encodePlannedStreamWithOptionsAlloc+0x9a6>
 12833ec:	49 8b 44 24 28       	mov    0x28(%r12),%rax
 12833f1:	48 83 f8 50          	cmp    $0x50,%rax
 12833f5:	0f 85 9f 04 00 00    	jne    128389a <br.encodePlannedStreamWithOptionsAlloc+0xc0a>
 12833fb:	49 83 7c 24 38 00    	cmpq   $0x0,0x38(%r12)
 1283401:	0f 85 2f 02 00 00    	jne    1283636 <br.encodePlannedStreamWithOptionsAlloc+0x9a6>
 1283407:	49 8b 3c 24          	mov    (%r12),%rdi
 128340b:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 1283410:	49 8b 4c 24 20       	mov    0x20(%r12),%rcx
 1283415:	48 85 c9             	test   %rcx,%rcx
 1283418:	74 28                	je     1283442 <br.encodePlannedStreamWithOptionsAlloc+0x7b2>
 128341a:	c4 c1 78 10 44 24 10 	vmovups 0x10(%r12),%xmm0
 1283421:	c5 f8 29 85 70 ff ff 	vmovaps %xmm0,-0x90(%rbp)
 1283428:	ff 
 1283429:	c6 41 20 01          	movb   $0x1,0x20(%rcx)
 128342d:	48 c7 41 08 00 00 00 	movq   $0x0,0x8(%rcx)
 1283434:	00 
 1283435:	c5 f8 28 85 70 ff ff 	vmovaps -0x90(%rbp),%xmm0
 128343c:	ff 
 128343d:	c5 f8 11 41 10       	vmovups %xmm0,0x10(%rcx)
 1283442:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1283446:	ba 50 00 00 00       	mov    $0x50,%edx
 128344b:	4c 89 e6             	mov    %r12,%rsi
 128344e:	b9 03 00 00 00       	mov    $0x3,%ecx
 1283453:	ff 50 18             	call   *0x18(%rax)
 1283456:	e9 db 01 00 00       	jmp    1283636 <br.encodePlannedStreamWithOptionsAlloc+0x9a6>
 128345b:	88 45 98             	mov    %al,-0x68(%rbp)
 128345e:	48 89 bd 60 ff ff ff 	mov    %rdi,-0xa0(%rbp)
 1283465:	48 8d bd 30 fe ff ff 	lea    -0x1d0(%rbp),%rdi
 128346c:	4c 89 fe             	mov    %r15,%rsi
 128346f:	44 89 4d 88          	mov    %r9d,-0x78(%rbp)
 1283473:	4c 89 55 80          	mov    %r10,-0x80(%rbp)
 1283477:	e8 44 97 fa ff       	call   122cbc0 <br.resolvedQualitySchedule>
 128347c:	4c 8b 55 80          	mov    -0x80(%rbp),%r10
 1283480:	44 8b 4d 88          	mov    -0x78(%rbp),%r9d
 1283484:	48 8b bd 60 ff ff ff 	mov    -0xa0(%rbp),%rdi
 128348b:	0f b7 8d 64 fe ff ff 	movzwl -0x19c(%rbp),%ecx
 1283492:	66 85 c9             	test   %cx,%cx
 1283495:	0f 85 ec 02 00 00    	jne    1283787 <br.encodePlannedStreamWithOptionsAlloc+0xaf7>
 128349b:	0f b6 85 53 fe ff ff 	movzbl -0x1ad(%rbp),%eax
 12834a2:	41 f6 c6 01          	test   $0x1,%r14b
 12834a6:	74 25                	je     12834cd <br.encodePlannedStreamWithOptionsAlloc+0x83d>
 12834a8:	45 84 ed             	test   %r13b,%r13b
 12834ab:	0f b6 c8             	movzbl %al,%ecx
 12834ae:	0f b6 45 98          	movzbl -0x68(%rbp),%eax
 12834b2:	0f 44 c1             	cmove  %ecx,%eax
 12834b5:	8d 50 01             	lea    0x1(%rax),%edx
 12834b8:	80 e2 1f             	and    $0x1f,%dl
 12834bb:	66 b9 1f 00          	mov    $0x1f,%cx
 12834bf:	80 fa 0b             	cmp    $0xb,%dl
 12834c2:	0f 83 c2 f9 ff ff    	jae    1282e8a <br.encodePlannedStreamWithOptionsAlloc+0x1fa>
 12834c8:	e9 ba 02 00 00       	jmp    1283787 <br.encodePlannedStreamWithOptionsAlloc+0xaf7>
 12834cd:	0f b7 95 54 fe ff ff 	movzwl -0x1ac(%rbp),%edx
 12834d4:	45 84 ed             	test   %r13b,%r13b
 12834d7:	0f b6 c8             	movzbl %al,%ecx
 12834da:	0f b6 45 98          	movzbl -0x68(%rbp),%eax
 12834de:	0f 44 c1             	cmove  %ecx,%eax
 12834e1:	24 1f                	and    $0x1f,%al
 12834e3:	89 d6                	mov    %edx,%esi
 12834e5:	40 80 e6 1f          	and    $0x1f,%sil
 12834e9:	66 b9 1f 00          	mov    $0x1f,%cx
 12834ed:	40 38 f0             	cmp    %sil,%al
 12834f0:	0f 82 91 02 00 00    	jb     1283787 <br.encodePlannedStreamWithOptionsAlloc+0xaf7>
 12834f6:	c1 ea 08             	shr    $0x8,%edx
 12834f9:	80 e2 1f             	and    $0x1f,%dl
 12834fc:	38 d0                	cmp    %dl,%al
 12834fe:	0f 86 86 f9 ff ff    	jbe    1282e8a <br.encodePlannedStreamWithOptionsAlloc+0x1fa>
 1283504:	e9 7e 02 00 00       	jmp    1283787 <br.encodePlannedStreamWithOptionsAlloc+0xaf7>
 1283509:	88 45 98             	mov    %al,-0x68(%rbp)
 128350c:	48 89 bd 60 ff ff ff 	mov    %rdi,-0xa0(%rbp)
 1283513:	48 8d bd 30 fe ff ff 	lea    -0x1d0(%rbp),%rdi
 128351a:	4c 89 fe             	mov    %r15,%rsi
 128351d:	44 89 4d 88          	mov    %r9d,-0x78(%rbp)
 1283521:	4c 89 55 80          	mov    %r10,-0x80(%rbp)
 1283525:	e8 96 96 fa ff       	call   122cbc0 <br.resolvedQualitySchedule>
 128352a:	4c 8b 55 80          	mov    -0x80(%rbp),%r10
 128352e:	44 8b 4d 88          	mov    -0x78(%rbp),%r9d
 1283532:	48 8b bd 60 ff ff ff 	mov    -0xa0(%rbp),%rdi
 1283539:	0f b7 8d 64 fe ff ff 	movzwl -0x19c(%rbp),%ecx
 1283540:	66 85 c9             	test   %cx,%cx
 1283543:	0f 85 3e 02 00 00    	jne    1283787 <br.encodePlannedStreamWithOptionsAlloc+0xaf7>
 1283549:	0f b6 85 53 fe ff ff 	movzbl -0x1ad(%rbp),%eax
 1283550:	41 f6 c6 01          	test   $0x1,%r14b
 1283554:	0f 84 fa 01 00 00    	je     1283754 <br.encodePlannedStreamWithOptionsAlloc+0xac4>
 128355a:	45 84 ed             	test   %r13b,%r13b
 128355d:	0f b6 c8             	movzbl %al,%ecx
 1283560:	0f b6 45 98          	movzbl -0x68(%rbp),%eax
 1283564:	0f 44 c1             	cmove  %ecx,%eax
 1283567:	8d 50 01             	lea    0x1(%rax),%edx
 128356a:	80 e2 1f             	and    $0x1f,%dl
 128356d:	66 b9 1f 00          	mov    $0x1f,%cx
 1283571:	80 fa 0b             	cmp    $0xb,%dl
 1283574:	0f 83 ab fb ff ff    	jae    1283125 <br.encodePlannedStreamWithOptionsAlloc+0x495>
 128357a:	e9 08 02 00 00       	jmp    1283787 <br.encodePlannedStreamWithOptionsAlloc+0xaf7>
 128357f:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 1283583:	48 8b 46 08          	mov    0x8(%rsi),%rax
 1283587:	eb 6f                	jmp    12835f8 <br.encodePlannedStreamWithOptionsAlloc+0x968>
 1283589:	66 41 be 1a 00       	mov    $0x1a,%r14w
 128358e:	48 85 db             	test   %rbx,%rbx
 1283591:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1283595:	74 51                	je     12835e8 <br.encodePlannedStreamWithOptionsAlloc+0x958>
 1283597:	48 8b 8d 58 ff ff ff 	mov    -0xa8(%rbp),%rcx
 128359e:	48 89 8b c8 00 00 00 	mov    %rcx,0xc8(%rbx)
 12835a5:	48 8b 8d 50 ff ff ff 	mov    -0xb0(%rbp),%rcx
 12835ac:	48 89 8b d0 00 00 00 	mov    %rcx,0xd0(%rbx)
 12835b3:	48 8b 8d 48 ff ff ff 	mov    -0xb8(%rbp),%rcx
 12835ba:	48 89 8b d8 00 00 00 	mov    %rcx,0xd8(%rbx)
 12835c1:	48 8b 8d 40 ff ff ff 	mov    -0xc0(%rbp),%rcx
 12835c8:	48 89 8b e0 00 00 00 	mov    %rcx,0xe0(%rbx)
 12835cf:	48 8b 8d 68 ff ff ff 	mov    -0x98(%rbp),%rcx
 12835d6:	48 89 8b e8 00 00 00 	mov    %rcx,0xe8(%rbx)
 12835dd:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 12835e1:	48 89 8b f0 00 00 00 	mov    %rcx,0xf0(%rbx)
 12835e8:	e9 bf 01 00 00       	jmp    12837ac <br.encodePlannedStreamWithOptionsAlloc+0xb1c>
 12835ed:	31 c9                	xor    %ecx,%ecx
 12835ef:	4c 39 e1             	cmp    %r12,%rcx
 12835f2:	0f 84 a6 01 00 00    	je     128379e <br.encodePlannedStreamWithOptionsAlloc+0xb0e>
 12835f8:	49 39 c5             	cmp    %rax,%r13
 12835fb:	0f 84 90 00 00 00    	je     1283691 <br.encodePlannedStreamWithOptionsAlloc+0xa01>
 1283601:	4d 85 ff             	test   %r15,%r15
 1283604:	74 17                	je     128361d <br.encodePlannedStreamWithOptionsAlloc+0x98d>
 1283606:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128360a:	48 8b bd e0 fe ff ff 	mov    -0x120(%rbp),%rdi
 1283611:	48 89 de             	mov    %rbx,%rsi
 1283614:	4c 89 fa             	mov    %r15,%rdx
 1283617:	31 c9                	xor    %ecx,%ecx
 1283619:	41 ff 52 18          	call   *0x18(%r10)
 128361d:	4d 85 e4             	test   %r12,%r12
 1283620:	48 8b 5d 88          	mov    -0x78(%rbp),%rbx
 1283624:	74 0b                	je     1283631 <br.encodePlannedStreamWithOptionsAlloc+0x9a1>
 1283626:	49 ff 4c 24 40       	decq   0x40(%r12)
 128362b:	0f 84 ce 02 00 00    	je     12838ff <br.encodePlannedStreamWithOptionsAlloc+0xc6f>
 1283631:	66 41 be 1f 00       	mov    $0x1f,%r14w
 1283636:	48 85 db             	test   %rbx,%rbx
 1283639:	74 51                	je     128368c <br.encodePlannedStreamWithOptionsAlloc+0x9fc>
 128363b:	48 8b 85 58 ff ff ff 	mov    -0xa8(%rbp),%rax
 1283642:	48 89 83 c8 00 00 00 	mov    %rax,0xc8(%rbx)
 1283649:	48 8b 85 50 ff ff ff 	mov    -0xb0(%rbp),%rax
 1283650:	48 89 83 d0 00 00 00 	mov    %rax,0xd0(%rbx)
 1283657:	48 8b 85 48 ff ff ff 	mov    -0xb8(%rbp),%rax
 128365e:	48 89 83 d8 00 00 00 	mov    %rax,0xd8(%rbx)
 1283665:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 128366c:	48 89 83 e0 00 00 00 	mov    %rax,0xe0(%rbx)
 1283673:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 128367a:	48 89 83 e8 00 00 00 	mov    %rax,0xe8(%rbx)
 1283681:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 1283685:	48 89 83 f0 00 00 00 	mov    %rax,0xf0(%rbx)
 128368c:	e9 17 01 00 00       	jmp    12837a8 <br.encodePlannedStreamWithOptionsAlloc+0xb18>
 1283691:	48 8d 05 80 0e 06 00 	lea    0x60e80(%rip),%rax        # 12e4518 <heap.PageAllocator.vtable>
 1283698:	49 39 c5             	cmp    %rax,%r13
 128369b:	0f 95 c0             	setne  %al
 128369e:	48 8d 0d 73 0d 06 00 	lea    0x60d73(%rip),%rcx        # 12e4418 <heap.SmpAllocator.vtable>
 12836a5:	49 39 cd             	cmp    %rcx,%r13
 12836a8:	0f 95 c1             	setne  %cl
 12836ab:	20 c1                	and    %al,%cl
 12836ad:	48 8d 05 84 0e 06 00 	lea    0x60e84(%rip),%rax        # 12e4538 <heap.c_allocator_impl.vtable>
 12836b4:	49 39 c5             	cmp    %rax,%r13
 12836b7:	0f 95 c2             	setne  %dl
 12836ba:	48 8b 85 e8 fe ff ff 	mov    -0x118(%rbp),%rax
 12836c1:	48 3b 06             	cmp    (%rsi),%rax
 12836c4:	0f 95 c0             	setne  %al
 12836c7:	20 d0                	and    %dl,%al
 12836c9:	20 c8                	and    %cl,%al
 12836cb:	4d 85 e4             	test   %r12,%r12
 12836ce:	0f 84 bd 00 00 00    	je     1283791 <br.encodePlannedStreamWithOptionsAlloc+0xb01>
 12836d4:	84 c0                	test   %al,%al
 12836d6:	0f 85 b5 00 00 00    	jne    1283791 <br.encodePlannedStreamWithOptionsAlloc+0xb01>
 12836dc:	49 8b 44 24 28       	mov    0x28(%r12),%rax
 12836e1:	49 8b 4c 24 30       	mov    0x30(%r12),%rcx
 12836e6:	4c 29 f8             	sub    %r15,%rax
 12836e9:	49 89 44 24 28       	mov    %rax,0x28(%r12)
 12836ee:	48 39 c1             	cmp    %rax,%rcx
 12836f1:	48 0f 46 c8          	cmovbe %rax,%rcx
 12836f5:	49 89 4c 24 30       	mov    %rcx,0x30(%r12)
 12836fa:	49 8b 4c 24 20       	mov    0x20(%r12),%rcx
 12836ff:	48 85 c9             	test   %rcx,%rcx
 1283702:	0f 84 96 00 00 00    	je     128379e <br.encodePlannedStreamWithOptionsAlloc+0xb0e>
 1283708:	c4 c1 78 10 44 24 10 	vmovups 0x10(%r12),%xmm0
 128370f:	c5 f8 29 85 70 ff ff 	vmovaps %xmm0,-0x90(%rbp)
 1283716:	ff 
 1283717:	c6 41 20 01          	movb   $0x1,0x20(%rcx)
 128371b:	48 89 41 08          	mov    %rax,0x8(%rcx)
 128371f:	48 8b 11             	mov    (%rcx),%rdx
 1283722:	48 39 c2             	cmp    %rax,%rdx
 1283725:	48 0f 47 c2          	cmova  %rdx,%rax
 1283729:	48 89 01             	mov    %rax,(%rcx)
 128372c:	c5 f8 28 85 70 ff ff 	vmovaps -0x90(%rbp),%xmm0
 1283733:	ff 
 1283734:	c5 f8 11 41 10       	vmovups %xmm0,0x10(%rcx)
 1283739:	eb 63                	jmp    128379e <br.encodePlannedStreamWithOptionsAlloc+0xb0e>
 128373b:	4c 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%r8
 1283742:	4d 85 c0             	test   %r8,%r8
 1283745:	0f 84 23 02 00 00    	je     128396e <br.encodePlannedStreamWithOptionsAlloc+0xcde>
 128374b:	49 8b 48 18          	mov    0x18(%r8),%rcx
 128374f:	e9 1c 02 00 00       	jmp    1283970 <br.encodePlannedStreamWithOptionsAlloc+0xce0>
 1283754:	0f b7 95 54 fe ff ff 	movzwl -0x1ac(%rbp),%edx
 128375b:	45 84 ed             	test   %r13b,%r13b
 128375e:	0f b6 c8             	movzbl %al,%ecx
 1283761:	0f b6 45 98          	movzbl -0x68(%rbp),%eax
 1283765:	0f 44 c1             	cmove  %ecx,%eax
 1283768:	24 1f                	and    $0x1f,%al
 128376a:	89 d6                	mov    %edx,%esi
 128376c:	40 80 e6 1f          	and    $0x1f,%sil
 1283770:	66 b9 1f 00          	mov    $0x1f,%cx
 1283774:	40 38 f0             	cmp    %sil,%al
 1283777:	72 0e                	jb     1283787 <br.encodePlannedStreamWithOptionsAlloc+0xaf7>
 1283779:	c1 ea 08             	shr    $0x8,%edx
 128377c:	80 e2 1f             	and    $0x1f,%dl
 128377f:	38 d0                	cmp    %dl,%al
 1283781:	0f 86 9e f9 ff ff    	jbe    1283125 <br.encodePlannedStreamWithOptionsAlloc+0x495>
 1283787:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128378b:	66 89 48 10          	mov    %cx,0x10(%rax)
 128378f:	eb 27                	jmp    12837b8 <br.encodePlannedStreamWithOptionsAlloc+0xb28>
 1283791:	84 c0                	test   %al,%al
 1283793:	0f 85 68 fe ff ff    	jne    1283601 <br.encodePlannedStreamWithOptionsAlloc+0x971>
 1283799:	4d 85 e4             	test   %r12,%r12
 128379c:	74 07                	je     12837a5 <br.encodePlannedStreamWithOptionsAlloc+0xb15>
 128379e:	49 ff 4c 24 40       	decq   0x40(%r12)
 12837a3:	74 25                	je     12837ca <br.encodePlannedStreamWithOptionsAlloc+0xb3a>
 12837a5:	45 31 f6             	xor    %r14d,%r14d
 12837a8:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 12837ac:	48 89 18             	mov    %rbx,(%rax)
 12837af:	4c 89 78 08          	mov    %r15,0x8(%rax)
 12837b3:	66 44 89 70 10       	mov    %r14w,0x10(%rax)
 12837b8:	48 81 c4 28 06 00 00 	add    $0x628,%rsp
 12837bf:	5b                   	pop    %rbx
 12837c0:	41 5c                	pop    %r12
 12837c2:	41 5d                	pop    %r13
 12837c4:	41 5e                	pop    %r14
 12837c6:	41 5f                	pop    %r15
 12837c8:	5d                   	pop    %rbp
 12837c9:	c3                   	ret    
 12837ca:	49 8b 44 24 28       	mov    0x28(%r12),%rax
 12837cf:	48 83 f8 50          	cmp    $0x50,%rax
 12837d3:	0f 85 be 02 00 00    	jne    1283a97 <br.encodePlannedStreamWithOptionsAlloc+0xe07>
 12837d9:	49 83 7c 24 38 00    	cmpq   $0x0,0x38(%r12)
 12837df:	75 c4                	jne    12837a5 <br.encodePlannedStreamWithOptionsAlloc+0xb15>
 12837e1:	49 8b 3c 24          	mov    (%r12),%rdi
 12837e5:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 12837ea:	49 8b 4c 24 20       	mov    0x20(%r12),%rcx
 12837ef:	48 85 c9             	test   %rcx,%rcx
 12837f2:	74 28                	je     128381c <br.encodePlannedStreamWithOptionsAlloc+0xb8c>
 12837f4:	c4 c1 78 10 44 24 10 	vmovups 0x10(%r12),%xmm0
 12837fb:	c5 f8 29 85 70 ff ff 	vmovaps %xmm0,-0x90(%rbp)
 1283802:	ff 
 1283803:	c6 41 20 01          	movb   $0x1,0x20(%rcx)
 1283807:	48 c7 41 08 00 00 00 	movq   $0x0,0x8(%rcx)
 128380e:	00 
 128380f:	c5 f8 28 85 70 ff ff 	vmovaps -0x90(%rbp),%xmm0
 1283816:	ff 
 1283817:	c5 f8 11 41 10       	vmovups %xmm0,0x10(%rcx)
 128381c:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1283820:	ba 50 00 00 00       	mov    $0x50,%edx
 1283825:	4c 89 e6             	mov    %r12,%rsi
 1283828:	b9 03 00 00 00       	mov    $0x3,%ecx
 128382d:	ff 50 18             	call   *0x18(%rax)
 1283830:	e9 70 ff ff ff       	jmp    12837a5 <br.encodePlannedStreamWithOptionsAlloc+0xb15>
 1283835:	49 8b 4c 24 20       	mov    0x20(%r12),%rcx
 128383a:	48 85 c9             	test   %rcx,%rcx
 128383d:	0f 84 4b fd ff ff    	je     128358e <br.encodePlannedStreamWithOptionsAlloc+0x8fe>
 1283843:	c4 c1 78 10 44 24 10 	vmovups 0x10(%r12),%xmm0
 128384a:	c5 f8 29 85 70 ff ff 	vmovaps %xmm0,-0x90(%rbp)
 1283851:	ff 
 1283852:	c6 41 20 01          	movb   $0x1,0x20(%rcx)
 1283856:	48 89 41 08          	mov    %rax,0x8(%rcx)
 128385a:	48 8b 11             	mov    (%rcx),%rdx
 128385d:	48 39 c2             	cmp    %rax,%rdx
 1283860:	48 0f 47 c2          	cmova  %rdx,%rax
 1283864:	48 89 01             	mov    %rax,(%rcx)
 1283867:	c5 f8 28 85 70 ff ff 	vmovaps -0x90(%rbp),%xmm0
 128386e:	ff 
 128386f:	c5 f8 11 41 10       	vmovups %xmm0,0x10(%rcx)
 1283874:	49 83 7c 24 40 00    	cmpq   $0x0,0x40(%r12)
 128387a:	49 c7 44 24 20 00 00 	movq   $0x0,0x20(%r12)
 1283881:	00 00 
 1283883:	0f 85 05 fd ff ff    	jne    128358e <br.encodePlannedStreamWithOptionsAlloc+0x8fe>
 1283889:	49 83 7c 24 28 50    	cmpq   $0x50,0x28(%r12)
 128388f:	0f 84 df fa ff ff    	je     1283374 <br.encodePlannedStreamWithOptionsAlloc+0x6e4>
 1283895:	e9 f4 fc ff ff       	jmp    128358e <br.encodePlannedStreamWithOptionsAlloc+0x8fe>
 128389a:	49 8b 4c 24 20       	mov    0x20(%r12),%rcx
 128389f:	48 85 c9             	test   %rcx,%rcx
 12838a2:	0f 84 8e fd ff ff    	je     1283636 <br.encodePlannedStreamWithOptionsAlloc+0x9a6>
 12838a8:	c4 c1 78 10 44 24 10 	vmovups 0x10(%r12),%xmm0
 12838af:	c5 f8 29 85 70 ff ff 	vmovaps %xmm0,-0x90(%rbp)
 12838b6:	ff 
 12838b7:	c6 41 20 01          	movb   $0x1,0x20(%rcx)
 12838bb:	48 89 41 08          	mov    %rax,0x8(%rcx)
 12838bf:	48 8b 11             	mov    (%rcx),%rdx
 12838c2:	48 39 c2             	cmp    %rax,%rdx
 12838c5:	48 0f 47 c2          	cmova  %rdx,%rax
 12838c9:	48 89 01             	mov    %rax,(%rcx)
 12838cc:	c5 f8 28 85 70 ff ff 	vmovaps -0x90(%rbp),%xmm0
 12838d3:	ff 
 12838d4:	c5 f8 11 41 10       	vmovups %xmm0,0x10(%rcx)
 12838d9:	49 83 7c 24 40 00    	cmpq   $0x0,0x40(%r12)
 12838df:	49 c7 44 24 20 00 00 	movq   $0x0,0x20(%r12)
 12838e6:	00 00 
 12838e8:	0f 85 48 fd ff ff    	jne    1283636 <br.encodePlannedStreamWithOptionsAlloc+0x9a6>
 12838ee:	49 83 7c 24 28 50    	cmpq   $0x50,0x28(%r12)
 12838f4:	0f 84 01 fb ff ff    	je     12833fb <br.encodePlannedStreamWithOptionsAlloc+0x76b>
 12838fa:	e9 37 fd ff ff       	jmp    1283636 <br.encodePlannedStreamWithOptionsAlloc+0x9a6>
 12838ff:	49 8b 44 24 28       	mov    0x28(%r12),%rax
 1283904:	48 83 f8 50          	cmp    $0x50,%rax
 1283908:	0f 85 34 03 00 00    	jne    1283c42 <br.encodePlannedStreamWithOptionsAlloc+0xfb2>
 128390e:	49 83 7c 24 38 00    	cmpq   $0x0,0x38(%r12)
 1283914:	0f 85 17 fd ff ff    	jne    1283631 <br.encodePlannedStreamWithOptionsAlloc+0x9a1>
 128391a:	49 8b 3c 24          	mov    (%r12),%rdi
 128391e:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 1283923:	49 8b 4c 24 20       	mov    0x20(%r12),%rcx
 1283928:	48 85 c9             	test   %rcx,%rcx
 128392b:	74 28                	je     1283955 <br.encodePlannedStreamWithOptionsAlloc+0xcc5>
 128392d:	c4 c1 78 10 44 24 10 	vmovups 0x10(%r12),%xmm0
 1283934:	c5 f8 29 85 70 ff ff 	vmovaps %xmm0,-0x90(%rbp)
 128393b:	ff 
 128393c:	c6 41 20 01          	movb   $0x1,0x20(%rcx)
 1283940:	48 c7 41 08 00 00 00 	movq   $0x0,0x8(%rcx)
 1283947:	00 
 1283948:	c5 f8 28 85 70 ff ff 	vmovaps -0x90(%rbp),%xmm0
 128394f:	ff 
 1283950:	c5 f8 11 41 10       	vmovups %xmm0,0x10(%rcx)
 1283955:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1283959:	ba 50 00 00 00       	mov    $0x50,%edx
 128395e:	4c 89 e6             	mov    %r12,%rsi
 1283961:	b9 03 00 00 00       	mov    $0x3,%ecx
 1283966:	ff 50 18             	call   *0x18(%rax)
 1283969:	e9 c3 fc ff ff       	jmp    1283631 <br.encodePlannedStreamWithOptionsAlloc+0x9a1>
 128396e:	31 c9                	xor    %ecx,%ecx
 1283970:	31 d2                	xor    %edx,%edx
 1283972:	48 85 c9             	test   %rcx,%rcx
 1283975:	0f 95 c2             	setne  %dl
 1283978:	48 01 da             	add    %rbx,%rdx
 128397b:	0f 92 85 30 fe ff ff 	setb   -0x1d0(%rbp)
 1283982:	73 09                	jae    128398d <br.encodePlannedStreamWithOptionsAlloc+0xcfd>
 1283984:	48 8d 05 75 ea d7 ff 	lea    -0x28158b(%rip),%rax        # 1002400 <__anon_78351>
 128398b:	eb 11                	jmp    128399e <br.encodePlannedStreamWithOptionsAlloc+0xd0e>
 128398d:	48 8d 05 8c ef d7 ff 	lea    -0x281074(%rip),%rax        # 1002920 <__anon_242136>
 1283994:	48 83 fa 0f          	cmp    $0xf,%rdx
 1283998:	0f 86 32 02 00 00    	jbe    1283bd0 <br.encodePlannedStreamWithOptionsAlloc+0xf40>
 128399e:	0f b7 48 08          	movzwl 0x8(%rax),%ecx
 12839a2:	66 85 c9             	test   %cx,%cx
 12839a5:	0f 85 dc fd ff ff    	jne    1283787 <br.encodePlannedStreamWithOptionsAlloc+0xaf7>
 12839ab:	4c 8b 20             	mov    (%rax),%r12
 12839ae:	4d 85 e4             	test   %r12,%r12
 12839b1:	74 7f                	je     1283a32 <br.encodePlannedStreamWithOptionsAlloc+0xda2>
 12839b3:	48 8b 45 90          	mov    -0x70(%rbp),%rax
 12839b7:	c5 f8 10 00          	vmovups (%rax),%xmm0
 12839bb:	c5 f8 29 85 f0 fa ff 	vmovaps %xmm0,-0x510(%rbp)
 12839c2:	ff 
 12839c3:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 12839c7:	c5 f8 11 85 a8 fa ff 	vmovups %xmm0,-0x558(%rbp)
 12839ce:	ff 
 12839cf:	c6 85 b8 fa ff ff 00 	movb   $0x0,-0x548(%rbp)
 12839d6:	48 c7 85 00 fb ff ff 	movq   $0x8,-0x500(%rbp)
 12839dd:	08 00 00 00 
 12839e1:	48 c7 85 08 fb ff ff 	movq   $0x0,-0x4f8(%rbp)
 12839e8:	00 00 00 00 
 12839ec:	48 8d bd 10 fb ff ff 	lea    -0x4f0(%rbp),%rdi
 12839f3:	48 8d b5 b8 f9 ff ff 	lea    -0x648(%rbp),%rsi
 12839fa:	ba 01 01 00 00       	mov    $0x101,%edx
 12839ff:	e8 bc 26 01 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 1283a04:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 1283a0b:	4c 89 b5 18 fe ff ff 	mov    %r14,-0x1e8(%rbp)
 1283a12:	48 89 9d 20 fe ff ff 	mov    %rbx,-0x1e0(%rbp)
 1283a19:	48 89 85 28 fe ff ff 	mov    %rax,-0x1d8(%rbp)
 1283a20:	48 85 c0             	test   %rax,%rax
 1283a23:	0f 84 d3 00 00 00    	je     1283afc <br.encodePlannedStreamWithOptionsAlloc+0xe6c>
 1283a29:	48 8b 48 18          	mov    0x18(%rax),%rcx
 1283a2d:	e9 cc 00 00 00       	jmp    1283afe <br.encodePlannedStreamWithOptionsAlloc+0xe6e>
 1283a32:	4d 85 c0             	test   %r8,%r8
 1283a35:	74 1c                	je     1283a53 <br.encodePlannedStreamWithOptionsAlloc+0xdc3>
 1283a37:	41 f6 80 20 3a 00 00 	testb  $0x7f,0x3a20(%r8)
 1283a3e:	7f 
 1283a3f:	0f 85 6e ff ff ff    	jne    12839b3 <br.encodePlannedStreamWithOptionsAlloc+0xd23>
 1283a45:	41 f6 80 21 3a 00 00 	testb  $0x7f,0x3a21(%r8)
 1283a4c:	7f 
 1283a4d:	0f 85 60 ff ff ff    	jne    12839b3 <br.encodePlannedStreamWithOptionsAlloc+0xd23>
 1283a53:	80 7d 98 00          	cmpb   $0x0,-0x68(%rbp)
 1283a57:	0f 84 99 02 00 00    	je     1283cf6 <br.encodePlannedStreamWithOptionsAlloc+0x1066>
 1283a5d:	48 8d bd 60 fd ff ff 	lea    -0x2a0(%rbp),%rdi
 1283a64:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 1283a68:	48 8b 55 80          	mov    -0x80(%rbp),%rdx
 1283a6c:	4c 89 e9             	mov    %r13,%rcx
 1283a6f:	4d 89 f8             	mov    %r15,%r8
 1283a72:	e8 79 5e 00 00       	call   12898f0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589>
 1283a77:	48 8b 85 70 fd ff ff 	mov    -0x290(%rbp),%rax
 1283a7e:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 1283a82:	48 89 41 10          	mov    %rax,0x10(%rcx)
 1283a86:	c5 f8 10 85 60 fd ff 	vmovups -0x2a0(%rbp),%xmm0
 1283a8d:	ff 
 1283a8e:	c5 f8 11 01          	vmovups %xmm0,(%rcx)
 1283a92:	e9 21 fd ff ff       	jmp    12837b8 <br.encodePlannedStreamWithOptionsAlloc+0xb28>
 1283a97:	49 8b 4c 24 20       	mov    0x20(%r12),%rcx
 1283a9c:	48 85 c9             	test   %rcx,%rcx
 1283a9f:	0f 84 00 fd ff ff    	je     12837a5 <br.encodePlannedStreamWithOptionsAlloc+0xb15>
 1283aa5:	c4 c1 78 10 44 24 10 	vmovups 0x10(%r12),%xmm0
 1283aac:	c5 f8 29 85 70 ff ff 	vmovaps %xmm0,-0x90(%rbp)
 1283ab3:	ff 
 1283ab4:	c6 41 20 01          	movb   $0x1,0x20(%rcx)
 1283ab8:	48 89 41 08          	mov    %rax,0x8(%rcx)
 1283abc:	48 8b 11             	mov    (%rcx),%rdx
 1283abf:	48 39 c2             	cmp    %rax,%rdx
 1283ac2:	48 0f 47 c2          	cmova  %rdx,%rax
 1283ac6:	48 89 01             	mov    %rax,(%rcx)
 1283ac9:	c5 f8 28 85 70 ff ff 	vmovaps -0x90(%rbp),%xmm0
 1283ad0:	ff 
 1283ad1:	c5 f8 11 41 10       	vmovups %xmm0,0x10(%rcx)
 1283ad6:	49 83 7c 24 40 00    	cmpq   $0x0,0x40(%r12)
 1283adc:	49 c7 44 24 20 00 00 	movq   $0x0,0x20(%r12)
 1283ae3:	00 00 
 1283ae5:	0f 85 ba fc ff ff    	jne    12837a5 <br.encodePlannedStreamWithOptionsAlloc+0xb15>
 1283aeb:	49 83 7c 24 28 50    	cmpq   $0x50,0x28(%r12)
 1283af1:	0f 85 ae fc ff ff    	jne    12837a5 <br.encodePlannedStreamWithOptionsAlloc+0xb15>
 1283af7:	e9 dd fc ff ff       	jmp    12837d9 <br.encodePlannedStreamWithOptionsAlloc+0xb49>
 1283afc:	31 c9                	xor    %ecx,%ecx
 1283afe:	31 d2                	xor    %edx,%edx
 1283b00:	48 85 c9             	test   %rcx,%rcx
 1283b03:	0f 95 c2             	setne  %dl
 1283b06:	48 01 da             	add    %rbx,%rdx
 1283b09:	0f 92 85 30 fe ff ff 	setb   -0x1d0(%rbp)
 1283b10:	73 09                	jae    1283b1b <br.encodePlannedStreamWithOptionsAlloc+0xe8b>
 1283b12:	48 8d 05 ef e8 d7 ff 	lea    -0x281711(%rip),%rax        # 1002408 <__anon_78351+0x8>
 1283b19:	eb 11                	jmp    1283b2c <br.encodePlannedStreamWithOptionsAlloc+0xe9c>
 1283b1b:	48 8d 05 06 ee d7 ff 	lea    -0x2811fa(%rip),%rax        # 1002928 <__anon_242136+0x8>
 1283b22:	48 83 fa 0f          	cmp    $0xf,%rdx
 1283b26:	0f 86 df 00 00 00    	jbe    1283c0b <br.encodePlannedStreamWithOptionsAlloc+0xf7b>
 1283b2c:	4c 8b 75 90          	mov    -0x70(%rbp),%r14
 1283b30:	0f b7 18             	movzwl (%rax),%ebx
 1283b33:	66 85 db             	test   %bx,%bx
 1283b36:	0f 85 3f 02 00 00    	jne    1283d7b <br.encodePlannedStreamWithOptionsAlloc+0x10eb>
 1283b3c:	48 8d bd f0 fa ff ff 	lea    -0x510(%rbp),%rdi
 1283b43:	48 8d b5 18 fe ff ff 	lea    -0x1e8(%rbp),%rsi
 1283b4a:	e8 f1 90 fd ff       	call   125cc40 <br.encoder.compound_dictionary_matcher.Matcher.prepare>
 1283b4f:	84 c0                	test   %al,%al
 1283b51:	0f 85 07 02 00 00    	jne    1283d5e <br.encodePlannedStreamWithOptionsAlloc+0x10ce>
 1283b57:	48 8d bd 78 fd ff ff 	lea    -0x288(%rbp),%rdi
 1283b5e:	4c 8d 8d f0 fa ff ff 	lea    -0x510(%rbp),%r9
 1283b65:	4c 89 f6             	mov    %r14,%rsi
 1283b68:	48 8b 55 80          	mov    -0x80(%rbp),%rdx
 1283b6c:	4c 89 e9             	mov    %r13,%rcx
 1283b6f:	4d 89 f8             	mov    %r15,%r8
 1283b72:	41 54                	push   %r12
 1283b74:	6a 00                	push   $0x0
 1283b76:	e8 a5 8e f9 ff       	call   121ca20 <br.encodePlannedStreamWithPreparedSharedDictionaryAlloc>
 1283b7b:	48 83 c4 10          	add    $0x10,%rsp
 1283b7f:	48 8b 95 08 fb ff ff 	mov    -0x4f8(%rbp),%rdx
 1283b86:	48 85 d2             	test   %rdx,%rdx
 1283b89:	48 8b 5d d0          	mov    -0x30(%rbp),%rbx
 1283b8d:	74 25                	je     1283bb4 <br.encodePlannedStreamWithOptionsAlloc+0xf24>
 1283b8f:	48 8b bd f0 fa ff ff 	mov    -0x510(%rbp),%rdi
 1283b96:	48 8b 85 f8 fa ff ff 	mov    -0x508(%rbp),%rax
 1283b9d:	48 8b b5 00 fb ff ff 	mov    -0x500(%rbp),%rsi
 1283ba4:	48 c1 e2 05          	shl    $0x5,%rdx
 1283ba8:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1283bac:	b9 03 00 00 00       	mov    $0x3,%ecx
 1283bb1:	ff 50 18             	call   *0x18(%rax)
 1283bb4:	48 8b 85 88 fd ff ff 	mov    -0x278(%rbp),%rax
 1283bbb:	48 89 43 10          	mov    %rax,0x10(%rbx)
 1283bbf:	c5 f8 10 85 78 fd ff 	vmovups -0x288(%rbp),%xmm0
 1283bc6:	ff 
 1283bc7:	c5 f8 11 03          	vmovups %xmm0,(%rbx)
 1283bcb:	e9 e8 fb ff ff       	jmp    12837b8 <br.encodePlannedStreamWithOptionsAlloc+0xb28>
 1283bd0:	48 85 db             	test   %rbx,%rbx
 1283bd3:	0f 84 ce 00 00 00    	je     1283ca7 <br.encodePlannedStreamWithOptionsAlloc+0x1017>
 1283bd9:	49 8d 56 08          	lea    0x8(%r14),%rdx
 1283bdd:	45 31 e4             	xor    %r12d,%r12d
 1283be0:	48 89 de             	mov    %rbx,%rsi
 1283be3:	eb 0d                	jmp    1283bf2 <br.encodePlannedStreamWithOptionsAlloc+0xf62>
 1283be5:	48 83 c2 10          	add    $0x10,%rdx
 1283be9:	48 ff ce             	dec    %rsi
 1283bec:	0f 84 b8 00 00 00    	je     1283caa <br.encodePlannedStreamWithOptionsAlloc+0x101a>
 1283bf2:	48 8b 3a             	mov    (%rdx),%rdi
 1283bf5:	48 85 ff             	test   %rdi,%rdi
 1283bf8:	74 eb                	je     1283be5 <br.encodePlannedStreamWithOptionsAlloc+0xf55>
 1283bfa:	49 01 fc             	add    %rdi,%r12
 1283bfd:	0f 92 85 30 fe ff ff 	setb   -0x1d0(%rbp)
 1283c04:	73 df                	jae    1283be5 <br.encodePlannedStreamWithOptionsAlloc+0xf55>
 1283c06:	e9 79 fd ff ff       	jmp    1283984 <br.encodePlannedStreamWithOptionsAlloc+0xcf4>
 1283c0b:	48 85 db             	test   %rbx,%rbx
 1283c0e:	0f 84 b9 00 00 00    	je     1283ccd <br.encodePlannedStreamWithOptionsAlloc+0x103d>
 1283c14:	49 83 c6 08          	add    $0x8,%r14
 1283c18:	31 d2                	xor    %edx,%edx
 1283c1a:	eb 0d                	jmp    1283c29 <br.encodePlannedStreamWithOptionsAlloc+0xf99>
 1283c1c:	49 83 c6 10          	add    $0x10,%r14
 1283c20:	48 ff cb             	dec    %rbx
 1283c23:	0f 84 a6 00 00 00    	je     1283ccf <br.encodePlannedStreamWithOptionsAlloc+0x103f>
 1283c29:	49 8b 36             	mov    (%r14),%rsi
 1283c2c:	48 85 f6             	test   %rsi,%rsi
 1283c2f:	74 eb                	je     1283c1c <br.encodePlannedStreamWithOptionsAlloc+0xf8c>
 1283c31:	48 01 f2             	add    %rsi,%rdx
 1283c34:	0f 92 85 30 fe ff ff 	setb   -0x1d0(%rbp)
 1283c3b:	73 df                	jae    1283c1c <br.encodePlannedStreamWithOptionsAlloc+0xf8c>
 1283c3d:	e9 d0 fe ff ff       	jmp    1283b12 <br.encodePlannedStreamWithOptionsAlloc+0xe82>
 1283c42:	49 8b 4c 24 20       	mov    0x20(%r12),%rcx
 1283c47:	48 85 c9             	test   %rcx,%rcx
 1283c4a:	0f 84 e1 f9 ff ff    	je     1283631 <br.encodePlannedStreamWithOptionsAlloc+0x9a1>
 1283c50:	c4 c1 78 10 44 24 10 	vmovups 0x10(%r12),%xmm0
 1283c57:	c5 f8 29 85 70 ff ff 	vmovaps %xmm0,-0x90(%rbp)
 1283c5e:	ff 
 1283c5f:	c6 41 20 01          	movb   $0x1,0x20(%rcx)
 1283c63:	48 89 41 08          	mov    %rax,0x8(%rcx)
 1283c67:	48 8b 11             	mov    (%rcx),%rdx
 1283c6a:	48 39 c2             	cmp    %rax,%rdx
 1283c6d:	48 0f 47 c2          	cmova  %rdx,%rax
 1283c71:	48 89 01             	mov    %rax,(%rcx)
 1283c74:	c5 f8 28 85 70 ff ff 	vmovaps -0x90(%rbp),%xmm0
 1283c7b:	ff 
 1283c7c:	c5 f8 11 41 10       	vmovups %xmm0,0x10(%rcx)
 1283c81:	49 83 7c 24 40 00    	cmpq   $0x0,0x40(%r12)
 1283c87:	49 c7 44 24 20 00 00 	movq   $0x0,0x20(%r12)
 1283c8e:	00 00 
 1283c90:	0f 85 9b f9 ff ff    	jne    1283631 <br.encodePlannedStreamWithOptionsAlloc+0x9a1>
 1283c96:	49 83 7c 24 28 50    	cmpq   $0x50,0x28(%r12)
 1283c9c:	0f 85 8f f9 ff ff    	jne    1283631 <br.encodePlannedStreamWithOptionsAlloc+0x9a1>
 1283ca2:	e9 67 fc ff ff       	jmp    128390e <br.encodePlannedStreamWithOptionsAlloc+0xc7e>
 1283ca7:	45 31 e4             	xor    %r12d,%r12d
 1283caa:	49 01 cc             	add    %rcx,%r12
 1283cad:	0f 92 85 30 fe ff ff 	setb   -0x1d0(%rbp)
 1283cb4:	0f 82 ca fc ff ff    	jb     1283984 <br.encodePlannedStreamWithOptionsAlloc+0xcf4>
 1283cba:	b9 00 00 00 80       	mov    $0x80000000,%ecx
 1283cbf:	49 39 cc             	cmp    %rcx,%r12
 1283cc2:	0f 87 d6 fc ff ff    	ja     128399e <br.encodePlannedStreamWithOptionsAlloc+0xd0e>
 1283cc8:	e9 e1 fc ff ff       	jmp    12839ae <br.encodePlannedStreamWithOptionsAlloc+0xd1e>
 1283ccd:	31 d2                	xor    %edx,%edx
 1283ccf:	48 01 ca             	add    %rcx,%rdx
 1283cd2:	0f 92 85 30 fe ff ff 	setb   -0x1d0(%rbp)
 1283cd9:	0f 82 33 fe ff ff    	jb     1283b12 <br.encodePlannedStreamWithOptionsAlloc+0xe82>
 1283cdf:	b9 00 00 00 80       	mov    $0x80000000,%ecx
 1283ce4:	48 39 ca             	cmp    %rcx,%rdx
 1283ce7:	4c 8b 75 90          	mov    -0x70(%rbp),%r14
 1283ceb:	0f 87 3f fe ff ff    	ja     1283b30 <br.encodePlannedStreamWithOptionsAlloc+0xea0>
 1283cf1:	e9 46 fe ff ff       	jmp    1283b3c <br.encodePlannedStreamWithOptionsAlloc+0xeac>
 1283cf6:	0f b6 45 88          	movzbl -0x78(%rbp),%eax
 1283cfa:	24 03                	and    $0x3,%al
 1283cfc:	3c 02                	cmp    $0x2,%al
 1283cfe:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 1283d02:	75 1b                	jne    1283d1f <br.encodePlannedStreamWithOptionsAlloc+0x108f>
 1283d04:	48 8d 9d d8 fa ff ff 	lea    -0x528(%rbp),%rbx
 1283d0b:	48 89 df             	mov    %rbx,%rdi
 1283d0e:	48 8b 55 80          	mov    -0x80(%rbp),%rdx
 1283d12:	4c 89 e9             	mov    %r13,%rcx
 1283d15:	4d 89 f8             	mov    %r15,%r8
 1283d18:	e8 c3 13 00 00       	call   12850e0 <br.encodePlannedStreamRatioWithOptionsAlloc>
 1283d1d:	eb 19                	jmp    1283d38 <br.encodePlannedStreamWithOptionsAlloc+0x10a8>
 1283d1f:	48 8d 9d c0 fa ff ff 	lea    -0x540(%rbp),%rbx
 1283d26:	48 89 df             	mov    %rbx,%rdi
 1283d29:	48 8b 55 80          	mov    -0x80(%rbp),%rdx
 1283d2d:	4c 89 e9             	mov    %r13,%rcx
 1283d30:	4d 89 f8             	mov    %r15,%r8
 1283d33:	e8 88 00 00 00       	call   1283dc0 <br.encodePlannedStreamOrStoredAlloc>
 1283d38:	48 8b 43 10          	mov    0x10(%rbx),%rax
 1283d3c:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 1283d40:	48 89 41 10          	mov    %rax,0x10(%rcx)
 1283d44:	c5 f8 10 03          	vmovups (%rbx),%xmm0
 1283d48:	c5 f8 11 01          	vmovups %xmm0,(%rcx)
 1283d4c:	e9 67 fa ff ff       	jmp    12837b8 <br.encodePlannedStreamWithOptionsAlloc+0xb28>
 1283d51:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 1283d55:	66 89 41 10          	mov    %ax,0x10(%rcx)
 1283d59:	e9 5a fa ff ff       	jmp    12837b8 <br.encodePlannedStreamWithOptionsAlloc+0xb28>
 1283d5e:	0f b7 c0             	movzwl %ax,%eax
 1283d61:	83 f8 1a             	cmp    $0x1a,%eax
 1283d64:	74 0b                	je     1283d71 <br.encodePlannedStreamWithOptionsAlloc+0x10e1>
 1283d66:	83 f8 4f             	cmp    $0x4f,%eax
 1283d69:	75 0c                	jne    1283d77 <br.encodePlannedStreamWithOptionsAlloc+0x10e7>
 1283d6b:	66 bb 4f 00          	mov    $0x4f,%bx
 1283d6f:	eb 0a                	jmp    1283d7b <br.encodePlannedStreamWithOptionsAlloc+0x10eb>
 1283d71:	66 bb 1a 00          	mov    $0x1a,%bx
 1283d75:	eb 04                	jmp    1283d7b <br.encodePlannedStreamWithOptionsAlloc+0x10eb>
 1283d77:	66 bb 1f 00          	mov    $0x1f,%bx
 1283d7b:	48 8b 95 08 fb ff ff 	mov    -0x4f8(%rbp),%rdx
 1283d82:	48 85 d2             	test   %rdx,%rdx
 1283d85:	74 25                	je     1283dac <br.encodePlannedStreamWithOptionsAlloc+0x111c>
 1283d87:	48 8b bd f0 fa ff ff 	mov    -0x510(%rbp),%rdi
 1283d8e:	48 8b 85 f8 fa ff ff 	mov    -0x508(%rbp),%rax
 1283d95:	48 8b b5 00 fb ff ff 	mov    -0x500(%rbp),%rsi
 1283d9c:	48 c1 e2 05          	shl    $0x5,%rdx
 1283da0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1283da4:	b9 03 00 00 00       	mov    $0x3,%ecx
 1283da9:	ff 50 18             	call   *0x18(%rax)
 1283dac:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1283db0:	66 89 58 10          	mov    %bx,0x10(%rax)
 1283db4:	e9 ff f9 ff ff       	jmp    12837b8 <br.encodePlannedStreamWithOptionsAlloc+0xb28>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
