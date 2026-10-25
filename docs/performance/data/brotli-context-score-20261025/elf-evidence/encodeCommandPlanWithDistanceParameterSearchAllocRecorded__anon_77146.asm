
/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/78f0aed58c7f51384364cb890565eb73/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

0000000001221c10 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77146>:
 1221c10:	55                   	push   %rbp
 1221c11:	48 89 e5             	mov    %rsp,%rbp
 1221c14:	41 57                	push   %r15
 1221c16:	41 56                	push   %r14
 1221c18:	41 55                	push   %r13
 1221c1a:	41 54                	push   %r12
 1221c1c:	53                   	push   %rbx
 1221c1d:	48 81 ec 68 04 00 00 	sub    $0x468,%rsp
 1221c24:	4c 8b 7d 20          	mov    0x20(%rbp),%r15
 1221c28:	41 f6 87 1a 02 00 00 	testb  $0x3,0x21a(%r15)
 1221c2f:	03 
 1221c30:	0f 85 d7 02 00 00    	jne    1221f0d <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77146+0x2fd>
 1221c36:	41 0f b6 87 1b 02 00 	movzbl 0x21b(%r15),%eax
 1221c3d:	00 
 1221c3e:	24 0f                	and    $0xf,%al
 1221c40:	0f 85 c7 02 00 00    	jne    1221f0d <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77146+0x2fd>
 1221c46:	41 f6 87 25 02 00 00 	testb  $0x1,0x225(%r15)
 1221c4d:	01 
 1221c4e:	0f 84 b9 02 00 00    	je     1221f0d <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77146+0x2fd>
 1221c54:	41 80 bf f8 01 00 00 	cmpb   $0x0,0x1f8(%r15)
 1221c5b:	00 
 1221c5c:	0f 85 ab 02 00 00    	jne    1221f0d <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77146+0x2fd>
 1221c62:	49 83 bf 00 02 00 00 	cmpq   $0x0,0x200(%r15)
 1221c69:	00 
 1221c6a:	0f 85 9d 02 00 00    	jne    1221f0d <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77146+0x2fd>
 1221c70:	48 89 7d c8          	mov    %rdi,-0x38(%rbp)
 1221c74:	4c 8b 65 18          	mov    0x18(%rbp),%r12
 1221c78:	f6 45 10 01          	testb  $0x1,0x10(%rbp)
 1221c7c:	0f 84 b4 02 00 00    	je     1221f36 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77146+0x326>
 1221c82:	c4 c1 7c 10 44 24 70 	vmovups 0x70(%r12),%ymm0
 1221c89:	c5 fc 11 85 10 fe ff 	vmovups %ymm0,-0x1f0(%rbp)
 1221c90:	ff 
 1221c91:	c4 c1 7c 10 04 24    	vmovups (%r12),%ymm0
 1221c97:	c4 c1 7c 10 4c 24 20 	vmovups 0x20(%r12),%ymm1
 1221c9e:	c4 c1 7c 10 54 24 40 	vmovups 0x40(%r12),%ymm2
 1221ca5:	c4 c1 7c 10 5c 24 60 	vmovups 0x60(%r12),%ymm3
 1221cac:	c5 fc 11 9d 00 fe ff 	vmovups %ymm3,-0x200(%rbp)
 1221cb3:	ff 
 1221cb4:	c5 fc 11 95 e0 fd ff 	vmovups %ymm2,-0x220(%rbp)
 1221cbb:	ff 
 1221cbc:	c5 fc 11 8d c0 fd ff 	vmovups %ymm1,-0x240(%rbp)
 1221cc3:	ff 
 1221cc4:	c5 fc 11 85 a0 fd ff 	vmovups %ymm0,-0x260(%rbp)
 1221ccb:	ff 
 1221ccc:	c4 c1 7c 10 04 24    	vmovups (%r12),%ymm0
 1221cd2:	c4 c1 7c 10 4c 24 20 	vmovups 0x20(%r12),%ymm1
 1221cd9:	c4 c1 7c 10 54 24 40 	vmovups 0x40(%r12),%ymm2
 1221ce0:	c4 c1 7c 10 5c 24 60 	vmovups 0x60(%r12),%ymm3
 1221ce7:	c5 fc 11 85 c0 fe ff 	vmovups %ymm0,-0x140(%rbp)
 1221cee:	ff 
 1221cef:	c5 fc 11 8d e0 fe ff 	vmovups %ymm1,-0x120(%rbp)
 1221cf6:	ff 
 1221cf7:	c5 fc 11 95 00 ff ff 	vmovups %ymm2,-0x100(%rbp)
 1221cfe:	ff 
 1221cff:	c5 fc 11 9d 20 ff ff 	vmovups %ymm3,-0xe0(%rbp)
 1221d06:	ff 
 1221d07:	c4 c1 7c 10 44 24 70 	vmovups 0x70(%r12),%ymm0
 1221d0e:	c5 fc 11 85 30 ff ff 	vmovups %ymm0,-0xd0(%rbp)
 1221d15:	ff 
 1221d16:	48 8d 85 c0 fe ff ff 	lea    -0x140(%rbp),%rax
 1221d1d:	48 8d 7d 80          	lea    -0x80(%rbp),%rdi
 1221d21:	48 89 75 b8          	mov    %rsi,-0x48(%rbp)
 1221d25:	48 89 55 98          	mov    %rdx,-0x68(%rbp)
 1221d29:	48 89 4d a0          	mov    %rcx,-0x60(%rbp)
 1221d2d:	4d 89 c6             	mov    %r8,%r14
 1221d30:	4d 89 cd             	mov    %r9,%r13
 1221d33:	41 57                	push   %r15
 1221d35:	50                   	push   %rax
 1221d36:	c5 f8 77             	vzeroupper 
 1221d39:	e8 c2 2c f5 ff       	call   1174a00 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307>
 1221d3e:	48 83 c4 10          	add    $0x10,%rsp
 1221d42:	0f b7 45 90          	movzwl -0x70(%rbp),%eax
 1221d46:	66 85 c0             	test   %ax,%ax
 1221d49:	0f 85 33 03 00 00    	jne    1222082 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77146+0x472>
 1221d4f:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 1221d53:	48 89 45 b0          	mov    %rax,-0x50(%rbp)
 1221d57:	48 8b 45 88          	mov    -0x78(%rbp),%rax
 1221d5b:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 1221d5f:	48 8d 7d aa          	lea    -0x56(%rbp),%rdi
 1221d63:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 1221d67:	4c 89 f2             	mov    %r14,%rdx
 1221d6a:	4c 89 e9             	mov    %r13,%rcx
 1221d6d:	4d 89 f8             	mov    %r15,%r8
 1221d70:	e8 ab 12 00 00       	call   1223020 <br.chooseDistanceParameterAlternativeAlloc>
 1221d75:	0f b7 5d aa          	movzwl -0x56(%rbp),%ebx
 1221d79:	66 85 db             	test   %bx,%bx
 1221d7c:	0f 85 d0 02 00 00    	jne    1222052 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77146+0x442>
 1221d82:	80 7d ae 00          	cmpb   $0x0,-0x52(%rbp)
 1221d86:	0f 84 db 01 00 00    	je     1221f67 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77146+0x357>
 1221d8c:	0f b7 5d ac          	movzwl -0x54(%rbp),%ebx
 1221d90:	48 8d bd 78 fb ff ff 	lea    -0x488(%rbp),%rdi
 1221d97:	ba 1a 02 00 00       	mov    $0x21a,%edx
 1221d9c:	4c 89 fe             	mov    %r15,%rsi
 1221d9f:	e8 7c 44 07 00       	call   1296220 <compiler_rt.memcpy.memcpyFast>
 1221da4:	41 0f b7 87 1c 02 00 	movzwl 0x21c(%r15),%eax
 1221dab:	00 
 1221dac:	66 89 85 94 fd ff ff 	mov    %ax,-0x26c(%rbp)
 1221db3:	41 0f b6 87 1e 02 00 	movzbl 0x21e(%r15),%eax
 1221dba:	00 
 1221dbb:	88 85 96 fd ff ff    	mov    %al,-0x26a(%rbp)
 1221dc1:	49 8b 87 20 02 00 00 	mov    0x220(%r15),%rax
 1221dc8:	c6 45 d7 00          	movb   $0x0,-0x29(%rbp)
 1221dcc:	c5 fc 10 85 a0 fd ff 	vmovups -0x260(%rbp),%ymm0
 1221dd3:	ff 
 1221dd4:	c5 fc 10 8d c0 fd ff 	vmovups -0x240(%rbp),%ymm1
 1221ddb:	ff 
 1221ddc:	c5 fc 10 95 e0 fd ff 	vmovups -0x220(%rbp),%ymm2
 1221de3:	ff 
 1221de4:	c5 fc 11 85 30 fe ff 	vmovups %ymm0,-0x1d0(%rbp)
 1221deb:	ff 
 1221dec:	c5 fc 11 8d 50 fe ff 	vmovups %ymm1,-0x1b0(%rbp)
 1221df3:	ff 
 1221df4:	c5 fc 10 85 00 fe ff 	vmovups -0x200(%rbp),%ymm0
 1221dfb:	ff 
 1221dfc:	c5 fc 11 95 70 fe ff 	vmovups %ymm2,-0x190(%rbp)
 1221e03:	ff 
 1221e04:	c5 fc 11 85 90 fe ff 	vmovups %ymm0,-0x170(%rbp)
 1221e0b:	ff 
 1221e0c:	c5 fc 10 85 10 fe ff 	vmovups -0x1f0(%rbp),%ymm0
 1221e13:	ff 
 1221e14:	c5 fc 11 85 a0 fe ff 	vmovups %ymm0,-0x160(%rbp)
 1221e1b:	ff 
 1221e1c:	66 89 9d 92 fd ff ff 	mov    %bx,-0x26e(%rbp)
 1221e23:	0f b6 4d d7          	movzbl -0x29(%rbp),%ecx
 1221e27:	88 8d 97 fd ff ff    	mov    %cl,-0x269(%rbp)
 1221e2d:	48 89 85 98 fd ff ff 	mov    %rax,-0x268(%rbp)
 1221e34:	48 8d 85 30 fe ff ff 	lea    -0x1d0(%rbp),%rax
 1221e3b:	48 8d bd 68 ff ff ff 	lea    -0x98(%rbp),%rdi
 1221e42:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 1221e46:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 1221e4a:	48 8b 4d a0          	mov    -0x60(%rbp),%rcx
 1221e4e:	4d 89 f0             	mov    %r14,%r8
 1221e51:	4d 89 e9             	mov    %r13,%r9
 1221e54:	4c 8d 95 78 fb ff ff 	lea    -0x488(%rbp),%r10
 1221e5b:	41 52                	push   %r10
 1221e5d:	50                   	push   %rax
 1221e5e:	c5 f8 77             	vzeroupper 
 1221e61:	e8 9a 2b f5 ff       	call   1174a00 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307>
 1221e66:	48 83 c4 10          	add    $0x10,%rsp
 1221e6a:	0f b7 9d 78 ff ff ff 	movzwl -0x88(%rbp),%ebx
 1221e71:	66 85 db             	test   %bx,%bx
 1221e74:	0f 85 d8 01 00 00    	jne    1222052 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77146+0x442>
 1221e7a:	4c 8b b5 68 ff ff ff 	mov    -0x98(%rbp),%r14
 1221e81:	48 8b 9d 70 ff ff ff 	mov    -0x90(%rbp),%rbx
 1221e88:	4c 8b 7d c0          	mov    -0x40(%rbp),%r15
 1221e8c:	4c 39 fb             	cmp    %r15,%rbx
 1221e8f:	0f 83 3a 01 00 00    	jae    1221fcf <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77146+0x3bf>
 1221e95:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 1221e99:	48 8b 38             	mov    (%rax),%rdi
 1221e9c:	48 8b 40 08          	mov    0x8(%rax),%rax
 1221ea0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1221ea4:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 1221ea8:	4c 89 fa             	mov    %r15,%rdx
 1221eab:	31 c9                	xor    %ecx,%ecx
 1221ead:	ff 50 18             	call   *0x18(%rax)
 1221eb0:	c5 fc 10 85 a0 fe ff 	vmovups -0x160(%rbp),%ymm0
 1221eb7:	ff 
 1221eb8:	c4 c1 7c 11 44 24 70 	vmovups %ymm0,0x70(%r12)
 1221ebf:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 1221ec6:	ff 
 1221ec7:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 1221ece:	ff 
 1221ecf:	c5 fc 10 95 70 fe ff 	vmovups -0x190(%rbp),%ymm2
 1221ed6:	ff 
 1221ed7:	c5 fc 10 9d 90 fe ff 	vmovups -0x170(%rbp),%ymm3
 1221ede:	ff 
 1221edf:	c4 c1 7c 11 5c 24 60 	vmovups %ymm3,0x60(%r12)
 1221ee6:	c4 c1 7c 11 54 24 40 	vmovups %ymm2,0x40(%r12)
 1221eed:	c4 c1 7c 11 4c 24 20 	vmovups %ymm1,0x20(%r12)
 1221ef4:	c4 c1 7c 11 04 24    	vmovups %ymm0,(%r12)
 1221efa:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 1221efe:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 1221f04:	4c 89 30             	mov    %r14,(%rax)
 1221f07:	48 89 58 08          	mov    %rbx,0x8(%rax)
 1221f0b:	eb 14                	jmp    1221f21 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77146+0x311>
 1221f0d:	c5 f8 10 05 53 f7 e1 	vmovups -0x1e08ad(%rip),%xmm0        # 1041668 <__anon_72923>
 1221f14:	ff 
 1221f15:	c5 f8 11 07          	vmovups %xmm0,(%rdi)
 1221f19:	48 c7 47 10 1f 00 00 	movq   $0x1f,0x10(%rdi)
 1221f20:	00 
 1221f21:	48 81 c4 68 04 00 00 	add    $0x468,%rsp
 1221f28:	5b                   	pop    %rbx
 1221f29:	41 5c                	pop    %r12
 1221f2b:	41 5d                	pop    %r13
 1221f2d:	41 5e                	pop    %r14
 1221f2f:	41 5f                	pop    %r15
 1221f31:	5d                   	pop    %rbp
 1221f32:	c5 f8 77             	vzeroupper 
 1221f35:	c3                   	ret    
 1221f36:	48 8d bd 50 ff ff ff 	lea    -0xb0(%rbp),%rdi
 1221f3d:	41 57                	push   %r15
 1221f3f:	41 54                	push   %r12
 1221f41:	e8 ba 2a f5 ff       	call   1174a00 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307>
 1221f46:	48 83 c4 10          	add    $0x10,%rsp
 1221f4a:	48 8b 85 60 ff ff ff 	mov    -0xa0(%rbp),%rax
 1221f51:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 1221f55:	48 89 41 10          	mov    %rax,0x10(%rcx)
 1221f59:	c5 f8 10 85 50 ff ff 	vmovups -0xb0(%rbp),%xmm0
 1221f60:	ff 
 1221f61:	c5 f8 11 01          	vmovups %xmm0,(%rcx)
 1221f65:	eb ba                	jmp    1221f21 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77146+0x311>
 1221f67:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 1221f6e:	ff 
 1221f6f:	c4 c1 7c 11 44 24 70 	vmovups %ymm0,0x70(%r12)
 1221f76:	c5 fc 10 85 c0 fe ff 	vmovups -0x140(%rbp),%ymm0
 1221f7d:	ff 
 1221f7e:	c5 fc 10 8d e0 fe ff 	vmovups -0x120(%rbp),%ymm1
 1221f85:	ff 
 1221f86:	c5 fc 10 95 00 ff ff 	vmovups -0x100(%rbp),%ymm2
 1221f8d:	ff 
 1221f8e:	c5 fc 10 9d 20 ff ff 	vmovups -0xe0(%rbp),%ymm3
 1221f95:	ff 
 1221f96:	c4 c1 7c 11 5c 24 60 	vmovups %ymm3,0x60(%r12)
 1221f9d:	c4 c1 7c 11 54 24 40 	vmovups %ymm2,0x40(%r12)
 1221fa4:	c4 c1 7c 11 4c 24 20 	vmovups %ymm1,0x20(%r12)
 1221fab:	c4 c1 7c 11 04 24    	vmovups %ymm0,(%r12)
 1221fb1:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 1221fb5:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 1221fbb:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 1221fbf:	48 89 08             	mov    %rcx,(%rax)
 1221fc2:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 1221fc6:	48 89 48 08          	mov    %rcx,0x8(%rax)
 1221fca:	e9 52 ff ff ff       	jmp    1221f21 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77146+0x311>
 1221fcf:	48 85 db             	test   %rbx,%rbx
 1221fd2:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 1221fd6:	74 16                	je     1221fee <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77146+0x3de>
 1221fd8:	48 8b 38             	mov    (%rax),%rdi
 1221fdb:	48 8b 40 08          	mov    0x8(%rax),%rax
 1221fdf:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1221fe3:	4c 89 f6             	mov    %r14,%rsi
 1221fe6:	48 89 da             	mov    %rbx,%rdx
 1221fe9:	31 c9                	xor    %ecx,%ecx
 1221feb:	ff 50 18             	call   *0x18(%rax)
 1221fee:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 1221ff5:	ff 
 1221ff6:	c4 c1 7c 11 44 24 70 	vmovups %ymm0,0x70(%r12)
 1221ffd:	c5 fc 10 85 c0 fe ff 	vmovups -0x140(%rbp),%ymm0
 1222004:	ff 
 1222005:	c5 fc 10 8d e0 fe ff 	vmovups -0x120(%rbp),%ymm1
 122200c:	ff 
 122200d:	c5 fc 10 95 00 ff ff 	vmovups -0x100(%rbp),%ymm2
 1222014:	ff 
 1222015:	c5 fc 10 9d 20 ff ff 	vmovups -0xe0(%rbp),%ymm3
 122201c:	ff 
 122201d:	c4 c1 7c 11 5c 24 60 	vmovups %ymm3,0x60(%r12)
 1222024:	c4 c1 7c 11 54 24 40 	vmovups %ymm2,0x40(%r12)
 122202b:	c4 c1 7c 11 4c 24 20 	vmovups %ymm1,0x20(%r12)
 1222032:	c4 c1 7c 11 04 24    	vmovups %ymm0,(%r12)
 1222038:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 122203c:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 1222042:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 1222046:	48 89 08             	mov    %rcx,(%rax)
 1222049:	4c 89 78 08          	mov    %r15,0x8(%rax)
 122204d:	e9 cf fe ff ff       	jmp    1221f21 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77146+0x311>
 1222052:	48 83 7d c0 00       	cmpq   $0x0,-0x40(%rbp)
 1222057:	74 1c                	je     1222075 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77146+0x465>
 1222059:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 122205d:	48 8b 38             	mov    (%rax),%rdi
 1222060:	48 8b 40 08          	mov    0x8(%rax),%rax
 1222064:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1222068:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 122206c:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 1222070:	31 c9                	xor    %ecx,%ecx
 1222072:	ff 50 18             	call   *0x18(%rax)
 1222075:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 1222079:	66 89 58 10          	mov    %bx,0x10(%rax)
 122207d:	e9 9f fe ff ff       	jmp    1221f21 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77146+0x311>
 1222082:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 1222086:	66 89 41 10          	mov    %ax,0x10(%rcx)
 122208a:	e9 92 fe ff ff       	jmp    1221f21 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77146+0x311>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
