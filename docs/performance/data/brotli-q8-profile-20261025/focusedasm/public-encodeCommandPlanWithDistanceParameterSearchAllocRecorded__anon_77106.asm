
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/d54ab236499589e8c9225c90450b9b10/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

0000000001221b00 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77106>:
 1221b00:	55                   	push   %rbp
 1221b01:	48 89 e5             	mov    %rsp,%rbp
 1221b04:	41 57                	push   %r15
 1221b06:	41 56                	push   %r14
 1221b08:	41 55                	push   %r13
 1221b0a:	41 54                	push   %r12
 1221b0c:	53                   	push   %rbx
 1221b0d:	48 81 ec 68 04 00 00 	sub    $0x468,%rsp
 1221b14:	4c 8b 7d 20          	mov    0x20(%rbp),%r15
 1221b18:	41 f6 87 1a 02 00 00 	testb  $0x3,0x21a(%r15)
 1221b1f:	03 
 1221b20:	0f 85 d7 02 00 00    	jne    1221dfd <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77106+0x2fd>
 1221b26:	41 0f b6 87 1b 02 00 	movzbl 0x21b(%r15),%eax
 1221b2d:	00 
 1221b2e:	24 0f                	and    $0xf,%al
 1221b30:	0f 85 c7 02 00 00    	jne    1221dfd <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77106+0x2fd>
 1221b36:	41 f6 87 25 02 00 00 	testb  $0x1,0x225(%r15)
 1221b3d:	01 
 1221b3e:	0f 84 b9 02 00 00    	je     1221dfd <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77106+0x2fd>
 1221b44:	41 80 bf f8 01 00 00 	cmpb   $0x0,0x1f8(%r15)
 1221b4b:	00 
 1221b4c:	0f 85 ab 02 00 00    	jne    1221dfd <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77106+0x2fd>
 1221b52:	49 83 bf 00 02 00 00 	cmpq   $0x0,0x200(%r15)
 1221b59:	00 
 1221b5a:	0f 85 9d 02 00 00    	jne    1221dfd <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77106+0x2fd>
 1221b60:	48 89 7d c8          	mov    %rdi,-0x38(%rbp)
 1221b64:	4c 8b 65 18          	mov    0x18(%rbp),%r12
 1221b68:	f6 45 10 01          	testb  $0x1,0x10(%rbp)
 1221b6c:	0f 84 b4 02 00 00    	je     1221e26 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77106+0x326>
 1221b72:	c4 c1 7c 10 44 24 70 	vmovups 0x70(%r12),%ymm0
 1221b79:	c5 fc 11 85 10 fe ff 	vmovups %ymm0,-0x1f0(%rbp)
 1221b80:	ff 
 1221b81:	c4 c1 7c 10 04 24    	vmovups (%r12),%ymm0
 1221b87:	c4 c1 7c 10 4c 24 20 	vmovups 0x20(%r12),%ymm1
 1221b8e:	c4 c1 7c 10 54 24 40 	vmovups 0x40(%r12),%ymm2
 1221b95:	c4 c1 7c 10 5c 24 60 	vmovups 0x60(%r12),%ymm3
 1221b9c:	c5 fc 11 9d 00 fe ff 	vmovups %ymm3,-0x200(%rbp)
 1221ba3:	ff 
 1221ba4:	c5 fc 11 95 e0 fd ff 	vmovups %ymm2,-0x220(%rbp)
 1221bab:	ff 
 1221bac:	c5 fc 11 8d c0 fd ff 	vmovups %ymm1,-0x240(%rbp)
 1221bb3:	ff 
 1221bb4:	c5 fc 11 85 a0 fd ff 	vmovups %ymm0,-0x260(%rbp)
 1221bbb:	ff 
 1221bbc:	c4 c1 7c 10 04 24    	vmovups (%r12),%ymm0
 1221bc2:	c4 c1 7c 10 4c 24 20 	vmovups 0x20(%r12),%ymm1
 1221bc9:	c4 c1 7c 10 54 24 40 	vmovups 0x40(%r12),%ymm2
 1221bd0:	c4 c1 7c 10 5c 24 60 	vmovups 0x60(%r12),%ymm3
 1221bd7:	c5 fc 11 85 c0 fe ff 	vmovups %ymm0,-0x140(%rbp)
 1221bde:	ff 
 1221bdf:	c5 fc 11 8d e0 fe ff 	vmovups %ymm1,-0x120(%rbp)
 1221be6:	ff 
 1221be7:	c5 fc 11 95 00 ff ff 	vmovups %ymm2,-0x100(%rbp)
 1221bee:	ff 
 1221bef:	c5 fc 11 9d 20 ff ff 	vmovups %ymm3,-0xe0(%rbp)
 1221bf6:	ff 
 1221bf7:	c4 c1 7c 10 44 24 70 	vmovups 0x70(%r12),%ymm0
 1221bfe:	c5 fc 11 85 30 ff ff 	vmovups %ymm0,-0xd0(%rbp)
 1221c05:	ff 
 1221c06:	48 8d 85 c0 fe ff ff 	lea    -0x140(%rbp),%rax
 1221c0d:	48 8d 7d 80          	lea    -0x80(%rbp),%rdi
 1221c11:	48 89 75 b8          	mov    %rsi,-0x48(%rbp)
 1221c15:	48 89 55 98          	mov    %rdx,-0x68(%rbp)
 1221c19:	48 89 4d a0          	mov    %rcx,-0x60(%rbp)
 1221c1d:	4d 89 c6             	mov    %r8,%r14
 1221c20:	4d 89 cd             	mov    %r9,%r13
 1221c23:	41 57                	push   %r15
 1221c25:	50                   	push   %rax
 1221c26:	c5 f8 77             	vzeroupper 
 1221c29:	e8 d2 2d f5 ff       	call   1174a00 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307>
 1221c2e:	48 83 c4 10          	add    $0x10,%rsp
 1221c32:	0f b7 45 90          	movzwl -0x70(%rbp),%eax
 1221c36:	66 85 c0             	test   %ax,%ax
 1221c39:	0f 85 33 03 00 00    	jne    1221f72 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77106+0x472>
 1221c3f:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 1221c43:	48 89 45 b0          	mov    %rax,-0x50(%rbp)
 1221c47:	48 8b 45 88          	mov    -0x78(%rbp),%rax
 1221c4b:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 1221c4f:	48 8d 7d aa          	lea    -0x56(%rbp),%rdi
 1221c53:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 1221c57:	4c 89 f2             	mov    %r14,%rdx
 1221c5a:	4c 89 e9             	mov    %r13,%rcx
 1221c5d:	4d 89 f8             	mov    %r15,%r8
 1221c60:	e8 ab 12 00 00       	call   1222f10 <br.chooseDistanceParameterAlternativeAlloc>
 1221c65:	0f b7 5d aa          	movzwl -0x56(%rbp),%ebx
 1221c69:	66 85 db             	test   %bx,%bx
 1221c6c:	0f 85 d0 02 00 00    	jne    1221f42 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77106+0x442>
 1221c72:	80 7d ae 00          	cmpb   $0x0,-0x52(%rbp)
 1221c76:	0f 84 db 01 00 00    	je     1221e57 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77106+0x357>
 1221c7c:	0f b7 5d ac          	movzwl -0x54(%rbp),%ebx
 1221c80:	48 8d bd 78 fb ff ff 	lea    -0x488(%rbp),%rdi
 1221c87:	ba 1a 02 00 00       	mov    $0x21a,%edx
 1221c8c:	4c 89 fe             	mov    %r15,%rsi
 1221c8f:	e8 2c 44 07 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 1221c94:	41 0f b7 87 1c 02 00 	movzwl 0x21c(%r15),%eax
 1221c9b:	00 
 1221c9c:	66 89 85 94 fd ff ff 	mov    %ax,-0x26c(%rbp)
 1221ca3:	41 0f b6 87 1e 02 00 	movzbl 0x21e(%r15),%eax
 1221caa:	00 
 1221cab:	88 85 96 fd ff ff    	mov    %al,-0x26a(%rbp)
 1221cb1:	49 8b 87 20 02 00 00 	mov    0x220(%r15),%rax
 1221cb8:	c6 45 d7 00          	movb   $0x0,-0x29(%rbp)
 1221cbc:	c5 fc 10 85 a0 fd ff 	vmovups -0x260(%rbp),%ymm0
 1221cc3:	ff 
 1221cc4:	c5 fc 10 8d c0 fd ff 	vmovups -0x240(%rbp),%ymm1
 1221ccb:	ff 
 1221ccc:	c5 fc 10 95 e0 fd ff 	vmovups -0x220(%rbp),%ymm2
 1221cd3:	ff 
 1221cd4:	c5 fc 11 85 30 fe ff 	vmovups %ymm0,-0x1d0(%rbp)
 1221cdb:	ff 
 1221cdc:	c5 fc 11 8d 50 fe ff 	vmovups %ymm1,-0x1b0(%rbp)
 1221ce3:	ff 
 1221ce4:	c5 fc 10 85 00 fe ff 	vmovups -0x200(%rbp),%ymm0
 1221ceb:	ff 
 1221cec:	c5 fc 11 95 70 fe ff 	vmovups %ymm2,-0x190(%rbp)
 1221cf3:	ff 
 1221cf4:	c5 fc 11 85 90 fe ff 	vmovups %ymm0,-0x170(%rbp)
 1221cfb:	ff 
 1221cfc:	c5 fc 10 85 10 fe ff 	vmovups -0x1f0(%rbp),%ymm0
 1221d03:	ff 
 1221d04:	c5 fc 11 85 a0 fe ff 	vmovups %ymm0,-0x160(%rbp)
 1221d0b:	ff 
 1221d0c:	66 89 9d 92 fd ff ff 	mov    %bx,-0x26e(%rbp)
 1221d13:	0f b6 4d d7          	movzbl -0x29(%rbp),%ecx
 1221d17:	88 8d 97 fd ff ff    	mov    %cl,-0x269(%rbp)
 1221d1d:	48 89 85 98 fd ff ff 	mov    %rax,-0x268(%rbp)
 1221d24:	48 8d 85 30 fe ff ff 	lea    -0x1d0(%rbp),%rax
 1221d2b:	48 8d bd 68 ff ff ff 	lea    -0x98(%rbp),%rdi
 1221d32:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 1221d36:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 1221d3a:	48 8b 4d a0          	mov    -0x60(%rbp),%rcx
 1221d3e:	4d 89 f0             	mov    %r14,%r8
 1221d41:	4d 89 e9             	mov    %r13,%r9
 1221d44:	4c 8d 95 78 fb ff ff 	lea    -0x488(%rbp),%r10
 1221d4b:	41 52                	push   %r10
 1221d4d:	50                   	push   %rax
 1221d4e:	c5 f8 77             	vzeroupper 
 1221d51:	e8 aa 2c f5 ff       	call   1174a00 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307>
 1221d56:	48 83 c4 10          	add    $0x10,%rsp
 1221d5a:	0f b7 9d 78 ff ff ff 	movzwl -0x88(%rbp),%ebx
 1221d61:	66 85 db             	test   %bx,%bx
 1221d64:	0f 85 d8 01 00 00    	jne    1221f42 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77106+0x442>
 1221d6a:	4c 8b b5 68 ff ff ff 	mov    -0x98(%rbp),%r14
 1221d71:	48 8b 9d 70 ff ff ff 	mov    -0x90(%rbp),%rbx
 1221d78:	4c 8b 7d c0          	mov    -0x40(%rbp),%r15
 1221d7c:	4c 39 fb             	cmp    %r15,%rbx
 1221d7f:	0f 83 3a 01 00 00    	jae    1221ebf <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77106+0x3bf>
 1221d85:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 1221d89:	48 8b 38             	mov    (%rax),%rdi
 1221d8c:	48 8b 40 08          	mov    0x8(%rax),%rax
 1221d90:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1221d94:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 1221d98:	4c 89 fa             	mov    %r15,%rdx
 1221d9b:	31 c9                	xor    %ecx,%ecx
 1221d9d:	ff 50 18             	call   *0x18(%rax)
 1221da0:	c5 fc 10 85 a0 fe ff 	vmovups -0x160(%rbp),%ymm0
 1221da7:	ff 
 1221da8:	c4 c1 7c 11 44 24 70 	vmovups %ymm0,0x70(%r12)
 1221daf:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 1221db6:	ff 
 1221db7:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 1221dbe:	ff 
 1221dbf:	c5 fc 10 95 70 fe ff 	vmovups -0x190(%rbp),%ymm2
 1221dc6:	ff 
 1221dc7:	c5 fc 10 9d 90 fe ff 	vmovups -0x170(%rbp),%ymm3
 1221dce:	ff 
 1221dcf:	c4 c1 7c 11 5c 24 60 	vmovups %ymm3,0x60(%r12)
 1221dd6:	c4 c1 7c 11 54 24 40 	vmovups %ymm2,0x40(%r12)
 1221ddd:	c4 c1 7c 11 4c 24 20 	vmovups %ymm1,0x20(%r12)
 1221de4:	c4 c1 7c 11 04 24    	vmovups %ymm0,(%r12)
 1221dea:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 1221dee:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 1221df4:	4c 89 30             	mov    %r14,(%rax)
 1221df7:	48 89 58 08          	mov    %rbx,0x8(%rax)
 1221dfb:	eb 14                	jmp    1221e11 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77106+0x311>
 1221dfd:	c5 f8 10 05 63 f8 e1 	vmovups -0x1e079d(%rip),%xmm0        # 1041668 <__anon_72883>
 1221e04:	ff 
 1221e05:	c5 f8 11 07          	vmovups %xmm0,(%rdi)
 1221e09:	48 c7 47 10 1f 00 00 	movq   $0x1f,0x10(%rdi)
 1221e10:	00 
 1221e11:	48 81 c4 68 04 00 00 	add    $0x468,%rsp
 1221e18:	5b                   	pop    %rbx
 1221e19:	41 5c                	pop    %r12
 1221e1b:	41 5d                	pop    %r13
 1221e1d:	41 5e                	pop    %r14
 1221e1f:	41 5f                	pop    %r15
 1221e21:	5d                   	pop    %rbp
 1221e22:	c5 f8 77             	vzeroupper 
 1221e25:	c3                   	ret    
 1221e26:	48 8d bd 50 ff ff ff 	lea    -0xb0(%rbp),%rdi
 1221e2d:	41 57                	push   %r15
 1221e2f:	41 54                	push   %r12
 1221e31:	e8 ca 2b f5 ff       	call   1174a00 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307>
 1221e36:	48 83 c4 10          	add    $0x10,%rsp
 1221e3a:	48 8b 85 60 ff ff ff 	mov    -0xa0(%rbp),%rax
 1221e41:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 1221e45:	48 89 41 10          	mov    %rax,0x10(%rcx)
 1221e49:	c5 f8 10 85 50 ff ff 	vmovups -0xb0(%rbp),%xmm0
 1221e50:	ff 
 1221e51:	c5 f8 11 01          	vmovups %xmm0,(%rcx)
 1221e55:	eb ba                	jmp    1221e11 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77106+0x311>
 1221e57:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 1221e5e:	ff 
 1221e5f:	c4 c1 7c 11 44 24 70 	vmovups %ymm0,0x70(%r12)
 1221e66:	c5 fc 10 85 c0 fe ff 	vmovups -0x140(%rbp),%ymm0
 1221e6d:	ff 
 1221e6e:	c5 fc 10 8d e0 fe ff 	vmovups -0x120(%rbp),%ymm1
 1221e75:	ff 
 1221e76:	c5 fc 10 95 00 ff ff 	vmovups -0x100(%rbp),%ymm2
 1221e7d:	ff 
 1221e7e:	c5 fc 10 9d 20 ff ff 	vmovups -0xe0(%rbp),%ymm3
 1221e85:	ff 
 1221e86:	c4 c1 7c 11 5c 24 60 	vmovups %ymm3,0x60(%r12)
 1221e8d:	c4 c1 7c 11 54 24 40 	vmovups %ymm2,0x40(%r12)
 1221e94:	c4 c1 7c 11 4c 24 20 	vmovups %ymm1,0x20(%r12)
 1221e9b:	c4 c1 7c 11 04 24    	vmovups %ymm0,(%r12)
 1221ea1:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 1221ea5:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 1221eab:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 1221eaf:	48 89 08             	mov    %rcx,(%rax)
 1221eb2:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 1221eb6:	48 89 48 08          	mov    %rcx,0x8(%rax)
 1221eba:	e9 52 ff ff ff       	jmp    1221e11 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77106+0x311>
 1221ebf:	48 85 db             	test   %rbx,%rbx
 1221ec2:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 1221ec6:	74 16                	je     1221ede <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77106+0x3de>
 1221ec8:	48 8b 38             	mov    (%rax),%rdi
 1221ecb:	48 8b 40 08          	mov    0x8(%rax),%rax
 1221ecf:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1221ed3:	4c 89 f6             	mov    %r14,%rsi
 1221ed6:	48 89 da             	mov    %rbx,%rdx
 1221ed9:	31 c9                	xor    %ecx,%ecx
 1221edb:	ff 50 18             	call   *0x18(%rax)
 1221ede:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 1221ee5:	ff 
 1221ee6:	c4 c1 7c 11 44 24 70 	vmovups %ymm0,0x70(%r12)
 1221eed:	c5 fc 10 85 c0 fe ff 	vmovups -0x140(%rbp),%ymm0
 1221ef4:	ff 
 1221ef5:	c5 fc 10 8d e0 fe ff 	vmovups -0x120(%rbp),%ymm1
 1221efc:	ff 
 1221efd:	c5 fc 10 95 00 ff ff 	vmovups -0x100(%rbp),%ymm2
 1221f04:	ff 
 1221f05:	c5 fc 10 9d 20 ff ff 	vmovups -0xe0(%rbp),%ymm3
 1221f0c:	ff 
 1221f0d:	c4 c1 7c 11 5c 24 60 	vmovups %ymm3,0x60(%r12)
 1221f14:	c4 c1 7c 11 54 24 40 	vmovups %ymm2,0x40(%r12)
 1221f1b:	c4 c1 7c 11 4c 24 20 	vmovups %ymm1,0x20(%r12)
 1221f22:	c4 c1 7c 11 04 24    	vmovups %ymm0,(%r12)
 1221f28:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 1221f2c:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 1221f32:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 1221f36:	48 89 08             	mov    %rcx,(%rax)
 1221f39:	4c 89 78 08          	mov    %r15,0x8(%rax)
 1221f3d:	e9 cf fe ff ff       	jmp    1221e11 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77106+0x311>
 1221f42:	48 83 7d c0 00       	cmpq   $0x0,-0x40(%rbp)
 1221f47:	74 1c                	je     1221f65 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77106+0x465>
 1221f49:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 1221f4d:	48 8b 38             	mov    (%rax),%rdi
 1221f50:	48 8b 40 08          	mov    0x8(%rax),%rax
 1221f54:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1221f58:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 1221f5c:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 1221f60:	31 c9                	xor    %ecx,%ecx
 1221f62:	ff 50 18             	call   *0x18(%rax)
 1221f65:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 1221f69:	66 89 58 10          	mov    %bx,0x10(%rax)
 1221f6d:	e9 9f fe ff ff       	jmp    1221e11 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77106+0x311>
 1221f72:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 1221f76:	66 89 41 10          	mov    %ax,0x10(%rcx)
 1221f7a:	e9 92 fe ff ff       	jmp    1221e11 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77106+0x311>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
