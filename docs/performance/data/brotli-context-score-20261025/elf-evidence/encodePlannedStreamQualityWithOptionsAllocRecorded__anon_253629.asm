
/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/78f0aed58c7f51384364cb890565eb73/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

0000000001289a50 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629>:
 1289a50:	55                   	push   %rbp
 1289a51:	48 89 e5             	mov    %rsp,%rbp
 1289a54:	41 57                	push   %r15
 1289a56:	41 56                	push   %r14
 1289a58:	41 55                	push   %r13
 1289a5a:	41 54                	push   %r12
 1289a5c:	53                   	push   %rbx
 1289a5d:	48 81 ec e8 0b 00 00 	sub    $0xbe8,%rsp
 1289a64:	4d 89 c7             	mov    %r8,%r15
 1289a67:	49 89 ce             	mov    %rcx,%r14
 1289a6a:	48 89 95 78 ff ff ff 	mov    %rdx,-0x88(%rbp)
 1289a71:	48 89 75 d0          	mov    %rsi,-0x30(%rbp)
 1289a75:	48 89 fb             	mov    %rdi,%rbx
 1289a78:	49 8b 40 58          	mov    0x58(%r8),%rax
 1289a7c:	48 89 85 28 ff ff ff 	mov    %rax,-0xd8(%rbp)
 1289a83:	49 8b 40 60          	mov    0x60(%r8),%rax
 1289a87:	48 89 85 30 ff ff ff 	mov    %rax,-0xd0(%rbp)
 1289a8e:	41 0f b7 80 80 00 00 	movzwl 0x80(%r8),%eax
 1289a95:	00 
 1289a96:	89 85 c0 fe ff ff    	mov    %eax,-0x140(%rbp)
 1289a9c:	41 0f b6 80 85 00 00 	movzbl 0x85(%r8),%eax
 1289aa3:	00 
 1289aa4:	88 85 20 ff ff ff    	mov    %al,-0xe0(%rbp)
 1289aaa:	88 45 c6             	mov    %al,-0x3a(%rbp)
 1289aad:	4d 8b a0 86 00 00 00 	mov    0x86(%r8),%r12
 1289ab4:	45 0f b6 a8 8e 00 00 	movzbl 0x8e(%r8),%r13d
 1289abb:	00 
 1289abc:	48 8d bd c8 fe ff ff 	lea    -0x138(%rbp),%rdi
 1289ac3:	4c 89 c6             	mov    %r8,%rsi
 1289ac6:	e8 05 32 fa ff       	call   122ccd0 <br.resolvedQualitySchedule>
 1289acb:	0f b7 85 fc fe ff ff 	movzwl -0x104(%rbp),%eax
 1289ad2:	66 85 c0             	test   %ax,%ax
 1289ad5:	0f 85 ef 14 00 00    	jne    128afca <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x157a>
 1289adb:	44 88 6d 90          	mov    %r13b,-0x70(%rbp)
 1289adf:	4c 89 b5 50 ff ff ff 	mov    %r14,-0xb0(%rbp)
 1289ae6:	48 89 5d a0          	mov    %rbx,-0x60(%rbp)
 1289aea:	4c 89 e3             	mov    %r12,%rbx
 1289aed:	48 c1 eb 08          	shr    $0x8,%rbx
 1289af1:	4c 89 a5 68 fe ff ff 	mov    %r12,-0x198(%rbp)
 1289af8:	41 c1 ec 10          	shr    $0x10,%r12d
 1289afc:	8b 85 cc fe ff ff    	mov    -0x134(%rbp),%eax
 1289b02:	48 89 85 70 fe ff ff 	mov    %rax,-0x190(%rbp)
 1289b09:	8b 85 d0 fe ff ff    	mov    -0x130(%rbp),%eax
 1289b0f:	c5 fb 10 85 c8 fe ff 	vmovsd -0x138(%rbp),%xmm0
 1289b16:	ff 
 1289b17:	c5 f8 29 85 60 fc ff 	vmovaps %xmm0,-0x3a0(%rbp)
 1289b1e:	ff 
 1289b1f:	89 85 08 ff ff ff    	mov    %eax,-0xf8(%rbp)
 1289b25:	0f b7 85 d4 fe ff ff 	movzwl -0x12c(%rbp),%eax
 1289b2c:	66 89 85 0c ff ff ff 	mov    %ax,-0xf4(%rbp)
 1289b33:	0f b6 b5 d6 fe ff ff 	movzbl -0x12a(%rbp),%esi
 1289b3a:	0f b6 85 d7 fe ff ff 	movzbl -0x129(%rbp),%eax
 1289b41:	88 45 92             	mov    %al,-0x6e(%rbp)
 1289b44:	0f b7 85 dc fe ff ff 	movzwl -0x124(%rbp),%eax
 1289b4b:	48 89 85 58 ff ff ff 	mov    %rax,-0xa8(%rbp)
 1289b52:	0f b7 85 de fe ff ff 	movzwl -0x122(%rbp),%eax
 1289b59:	48 89 45 b0          	mov    %rax,-0x50(%rbp)
 1289b5d:	0f b6 85 e4 fe ff ff 	movzbl -0x11c(%rbp),%eax
 1289b64:	0f b6 8d e5 fe ff ff 	movzbl -0x11b(%rbp),%ecx
 1289b6b:	44 0f b6 ad e6 fe ff 	movzbl -0x11a(%rbp),%r13d
 1289b72:	ff 
 1289b73:	0f b6 95 e7 fe ff ff 	movzbl -0x119(%rbp),%edx
 1289b7a:	88 55 c7             	mov    %dl,-0x39(%rbp)
 1289b7d:	0f b6 95 e8 fe ff ff 	movzbl -0x118(%rbp),%edx
 1289b84:	88 95 10 ff ff ff    	mov    %dl,-0xf0(%rbp)
 1289b8a:	0f b6 95 ee fe ff ff 	movzbl -0x112(%rbp),%edx
 1289b91:	88 55 88             	mov    %dl,-0x78(%rbp)
 1289b94:	0f b6 95 ef fe ff ff 	movzbl -0x111(%rbp),%edx
 1289b9b:	88 55 8d             	mov    %dl,-0x73(%rbp)
 1289b9e:	0f b6 95 f0 fe ff ff 	movzbl -0x110(%rbp),%edx
 1289ba5:	88 55 8e             	mov    %dl,-0x72(%rbp)
 1289ba8:	0f b6 95 f1 fe ff ff 	movzbl -0x10f(%rbp),%edx
 1289baf:	88 55 8b             	mov    %dl,-0x75(%rbp)
 1289bb2:	0f b6 95 f2 fe ff ff 	movzbl -0x10e(%rbp),%edx
 1289bb9:	88 55 8a             	mov    %dl,-0x76(%rbp)
 1289bbc:	0f b6 95 f3 fe ff ff 	movzbl -0x10d(%rbp),%edx
 1289bc3:	88 55 89             	mov    %dl,-0x77(%rbp)
 1289bc6:	44 0f b6 b5 f4 fe ff 	movzbl -0x10c(%rbp),%r14d
 1289bcd:	ff 
 1289bce:	0f b6 95 f5 fe ff ff 	movzbl -0x10b(%rbp),%edx
 1289bd5:	88 55 8f             	mov    %dl,-0x71(%rbp)
 1289bd8:	0f b6 95 f6 fe ff ff 	movzbl -0x10a(%rbp),%edx
 1289bdf:	88 55 8c             	mov    %dl,-0x74(%rbp)
 1289be2:	88 45 94             	mov    %al,-0x6c(%rbp)
 1289be5:	0f b6 85 f7 fe ff ff 	movzbl -0x109(%rbp),%eax
 1289bec:	88 4d 86             	mov    %cl,-0x7a(%rbp)
 1289bef:	0f b6 8d f8 fe ff ff 	movzbl -0x108(%rbp),%ecx
 1289bf6:	88 4d 91             	mov    %cl,-0x6f(%rbp)
 1289bf9:	40 88 75 c5          	mov    %sil,-0x3b(%rbp)
 1289bfd:	40 88 75 ae          	mov    %sil,-0x52(%rbp)
 1289c01:	88 45 ac             	mov    %al,-0x54(%rbp)
 1289c04:	88 45 87             	mov    %al,-0x79(%rbp)
 1289c07:	41 80 bf 84 00 00 00 	cmpb   $0x0,0x84(%r15)
 1289c0e:	00 
 1289c0f:	0f b6 85 e0 fe ff ff 	movzbl -0x120(%rbp),%eax
 1289c16:	48 89 85 38 ff ff ff 	mov    %rax,-0xc8(%rbp)
 1289c1d:	0f b7 85 e2 fe ff ff 	movzwl -0x11e(%rbp),%eax
 1289c24:	89 85 c4 fe ff ff    	mov    %eax,-0x13c(%rbp)
 1289c2a:	74 4f                	je     1289c7b <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x22b>
 1289c2c:	48 8d bd 78 fe ff ff 	lea    -0x188(%rbp),%rdi
 1289c33:	4c 89 fe             	mov    %r15,%rsi
 1289c36:	e8 95 30 fa ff       	call   122ccd0 <br.resolvedQualitySchedule>
 1289c3b:	0f b7 85 ac fe ff ff 	movzwl -0x154(%rbp),%eax
 1289c42:	66 85 c0             	test   %ax,%ax
 1289c45:	0f 85 1e 03 00 00    	jne    1289f69 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x519>
 1289c4b:	0f b6 85 9b fe ff ff 	movzbl -0x165(%rbp),%eax
 1289c52:	f6 85 20 ff ff ff 01 	testb  $0x1,-0xe0(%rbp)
 1289c59:	74 5d                	je     1289cb8 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x268>
 1289c5b:	45 84 e4             	test   %r12b,%r12b
 1289c5e:	0f b6 c0             	movzbl %al,%eax
 1289c61:	0f b6 f3             	movzbl %bl,%esi
 1289c64:	0f 44 f0             	cmove  %eax,%esi
 1289c67:	8d 4e 01             	lea    0x1(%rsi),%ecx
 1289c6a:	80 e1 1f             	and    $0x1f,%cl
 1289c6d:	66 b8 1f 00          	mov    $0x1f,%ax
 1289c71:	80 f9 0b             	cmp    $0xb,%cl
 1289c74:	73 7a                	jae    1289cf0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x2a0>
 1289c76:	e9 ee 02 00 00       	jmp    1289f69 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x519>
 1289c7b:	45 84 e4             	test   %r12b,%r12b
 1289c7e:	be 10 00 00 00       	mov    $0x10,%esi
 1289c83:	0f 45 f3             	cmovne %ebx,%esi
 1289c86:	89 f1                	mov    %esi,%ecx
 1289c88:	80 e1 1f             	and    $0x1f,%cl
 1289c8b:	f6 85 20 ff ff ff 01 	testb  $0x1,-0xe0(%rbp)
 1289c92:	b8 fe 00 00 00       	mov    $0xfe,%eax
 1289c97:	ba f8 00 00 00       	mov    $0xf8,%edx
 1289c9c:	0f 45 d0             	cmovne %eax,%edx
 1289c9f:	66 b8 1f 00          	mov    $0x1f,%ax
 1289ca3:	80 f9 0a             	cmp    $0xa,%cl
 1289ca6:	0f 82 bd 02 00 00    	jb     1289f69 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x519>
 1289cac:	80 e2 1f             	and    $0x1f,%dl
 1289caf:	38 d1                	cmp    %dl,%cl
 1289cb1:	76 3d                	jbe    1289cf0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x2a0>
 1289cb3:	e9 b1 02 00 00       	jmp    1289f69 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x519>
 1289cb8:	0f b7 8d 9c fe ff ff 	movzwl -0x164(%rbp),%ecx
 1289cbf:	45 84 e4             	test   %r12b,%r12b
 1289cc2:	0f b6 c0             	movzbl %al,%eax
 1289cc5:	0f b6 f3             	movzbl %bl,%esi
 1289cc8:	0f 44 f0             	cmove  %eax,%esi
 1289ccb:	40 80 e6 1f          	and    $0x1f,%sil
 1289ccf:	89 ca                	mov    %ecx,%edx
 1289cd1:	80 e2 1f             	and    $0x1f,%dl
 1289cd4:	66 b8 1f 00          	mov    $0x1f,%ax
 1289cd8:	40 38 d6             	cmp    %dl,%sil
 1289cdb:	0f 82 88 02 00 00    	jb     1289f69 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x519>
 1289ce1:	c1 e9 08             	shr    $0x8,%ecx
 1289ce4:	80 e1 1f             	and    $0x1f,%cl
 1289ce7:	40 38 ce             	cmp    %cl,%sil
 1289cea:	0f 87 79 02 00 00    	ja     1289f69 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x519>
 1289cf0:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1289cf4:	c5 f8 29 85 e0 fd ff 	vmovaps %xmm0,-0x220(%rbp)
 1289cfb:	ff 
 1289cfc:	48 c7 85 f0 fd ff ff 	movq   $0x0,-0x210(%rbp)
 1289d03:	00 00 00 00 
 1289d07:	0f b6 8d 20 ff ff ff 	movzbl -0xe0(%rbp),%ecx
 1289d0e:	80 e1 01             	and    $0x1,%cl
 1289d11:	88 8d 08 fe ff ff    	mov    %cl,-0x1f8(%rbp)
 1289d17:	48 89 b5 00 ff ff ff 	mov    %rsi,-0x100(%rbp)
 1289d1e:	40 80 e6 1f          	and    $0x1f,%sil
 1289d22:	48 89 b5 18 ff ff ff 	mov    %rsi,-0xe8(%rbp)
 1289d29:	40 88 b5 09 fe ff ff 	mov    %sil,-0x1f7(%rbp)
 1289d30:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 1289d37:	48 89 85 f8 fd ff ff 	mov    %rax,-0x208(%rbp)
 1289d3e:	48 8b 85 30 ff ff ff 	mov    -0xd0(%rbp),%rax
 1289d45:	48 89 85 00 fe ff ff 	mov    %rax,-0x200(%rbp)
 1289d4c:	4c 8b a5 50 ff ff ff 	mov    -0xb0(%rbp),%r12
 1289d53:	49 83 fc 04          	cmp    $0x4,%r12
 1289d57:	77 4c                	ja     1289da5 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x355>
 1289d59:	48 8d bd 78 fe ff ff 	lea    -0x188(%rbp),%rdi
 1289d60:	4c 8d 85 e0 fd ff ff 	lea    -0x220(%rbp),%r8
 1289d67:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1289d6b:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 1289d72:	4c 89 e1             	mov    %r12,%rcx
 1289d75:	e8 06 f3 f5 ff       	call   11e9080 <br.encodeStoredStreamWithOptionsAlloc>
 1289d7a:	0f b7 85 88 fe ff ff 	movzwl -0x178(%rbp),%eax
 1289d81:	66 85 c0             	test   %ax,%ax
 1289d84:	48 8b 4d a0          	mov    -0x60(%rbp),%rcx
 1289d88:	0f 85 df 01 00 00    	jne    1289f6d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x51d>
 1289d8e:	c5 f8 10 85 78 fe ff 	vmovups -0x188(%rbp),%xmm0
 1289d95:	ff 
 1289d96:	c5 f8 11 01          	vmovups %xmm0,(%rcx)
 1289d9a:	66 c7 41 10 00 00    	movw   $0x0,0x10(%rcx)
 1289da0:	e9 9e 10 00 00       	jmp    128ae43 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x13f3>
 1289da5:	88 4d 93             	mov    %cl,-0x6d(%rbp)
 1289da8:	41 80 e5 0f          	and    $0xf,%r13b
 1289dac:	48 c7 45 c8 00 00 00 	movq   $0x0,-0x38(%rbp)
 1289db3:	00 
 1289db4:	b8 00 00 00 00       	mov    $0x0,%eax
 1289db9:	44 88 6d ad          	mov    %r13b,-0x53(%rbp)
 1289dbd:	41 80 fd 0b          	cmp    $0xb,%r13b
 1289dc1:	0f 85 af 00 00 00    	jne    1289e76 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x426>
 1289dc7:	49 8d 87 85 00 00 00 	lea    0x85(%r15),%rax
 1289dce:	41 8b 4f 7f          	mov    0x7f(%r15),%ecx
 1289dd2:	89 8d 9f fb ff ff    	mov    %ecx,-0x461(%rbp)
 1289dd8:	c4 c1 7c 10 07       	vmovups (%r15),%ymm0
 1289ddd:	c4 c1 7c 10 4f 20    	vmovups 0x20(%r15),%ymm1
 1289de3:	c4 c1 7c 10 57 40    	vmovups 0x40(%r15),%ymm2
 1289de9:	c4 c1 7c 10 5f 60    	vmovups 0x60(%r15),%ymm3
 1289def:	c5 fc 11 9d 80 fb ff 	vmovups %ymm3,-0x480(%rbp)
 1289df6:	ff 
 1289df7:	c5 fc 11 95 60 fb ff 	vmovups %ymm2,-0x4a0(%rbp)
 1289dfe:	ff 
 1289dff:	c5 fc 11 8d 40 fb ff 	vmovups %ymm1,-0x4c0(%rbp)
 1289e06:	ff 
 1289e07:	c5 fc 11 85 20 fb ff 	vmovups %ymm0,-0x4e0(%rbp)
 1289e0e:	ff 
 1289e0f:	0f b7 0d aa d9 e2 ff 	movzwl -0x1d2656(%rip),%ecx        # 10b77c0 <__anon_250498>
 1289e16:	66 89 8d a3 fb ff ff 	mov    %cx,-0x45d(%rbp)
 1289e1d:	48 8b 08             	mov    (%rax),%rcx
 1289e20:	48 89 8d a5 fb ff ff 	mov    %rcx,-0x45b(%rbp)
 1289e27:	8b 40 07             	mov    0x7(%rax),%eax
 1289e2a:	89 85 ac fb ff ff    	mov    %eax,-0x454(%rbp)
 1289e30:	48 8d bd c8 fd ff ff 	lea    -0x238(%rbp),%rdi
 1289e37:	4c 8d 85 20 fb ff ff 	lea    -0x4e0(%rbp),%r8
 1289e3e:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1289e42:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 1289e49:	4c 89 e1             	mov    %r12,%rcx
 1289e4c:	c5 f8 77             	vzeroupper 
 1289e4f:	e8 fc fb ff ff       	call   1289a50 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629>
 1289e54:	0f b7 85 d8 fd ff ff 	movzwl -0x228(%rbp),%eax
 1289e5b:	66 85 c0             	test   %ax,%ax
 1289e5e:	0f 85 05 01 00 00    	jne    1289f69 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x519>
 1289e64:	48 8b 85 c8 fd ff ff 	mov    -0x238(%rbp),%rax
 1289e6b:	48 89 45 c8          	mov    %rax,-0x38(%rbp)
 1289e6f:	48 8b 85 d0 fd ff ff 	mov    -0x230(%rbp),%rax
 1289e76:	48 89 45 b8          	mov    %rax,-0x48(%rbp)
 1289e7a:	b8 01 00 00 00       	mov    $0x1,%eax
 1289e7f:	48 8b 8d 18 ff ff ff 	mov    -0xe8(%rbp),%rcx
 1289e86:	c4 e2 f1 f7 c0       	shlx   %rcx,%rax,%rax
 1289e8b:	48 83 c0 f0          	add    $0xfffffffffffffff0,%rax
 1289e8f:	4c 39 e0             	cmp    %r12,%rax
 1289e92:	4c 89 e1             	mov    %r12,%rcx
 1289e95:	48 89 85 60 fe ff ff 	mov    %rax,-0x1a0(%rbp)
 1289e9c:	48 0f 42 c8          	cmovb  %rax,%rcx
 1289ea0:	48 81 f9 ff ff 00 00 	cmp    $0xffff,%rcx
 1289ea7:	b8 ff ff 00 00       	mov    $0xffff,%eax
 1289eac:	48 0f 42 c1          	cmovb  %rcx,%rax
 1289eb0:	f6 85 10 ff ff ff 03 	testb  $0x3,-0xf0(%rbp)
 1289eb7:	0f 84 b9 00 00 00    	je     1289f76 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x526>
 1289ebd:	48 89 85 78 fc ff ff 	mov    %rax,-0x388(%rbp)
 1289ec4:	48 8b 85 58 ff ff ff 	mov    -0xa8(%rbp),%rax
 1289ecb:	48 89 85 80 fc ff ff 	mov    %rax,-0x380(%rbp)
 1289ed2:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 1289ed6:	48 89 85 88 fc ff ff 	mov    %rax,-0x378(%rbp)
 1289edd:	48 c7 85 90 fc ff ff 	movq   $0x1,-0x370(%rbp)
 1289ee4:	01 00 00 00 
 1289ee8:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 1289eef:	48 89 85 98 fc ff ff 	mov    %rax,-0x368(%rbp)
 1289ef6:	48 c7 85 a0 fc ff ff 	movq   $0x3,-0x360(%rbp)
 1289efd:	03 00 00 00 
 1289f01:	48 c7 85 a8 fc ff ff 	movq   $0x102,-0x358(%rbp)
 1289f08:	02 01 00 00 
 1289f0c:	48 c7 85 b0 fc ff ff 	movq   $0x0,-0x350(%rbp)
 1289f13:	00 00 00 00 
 1289f17:	c6 85 b8 fc ff ff 00 	movb   $0x0,-0x348(%rbp)
 1289f1e:	48 8d bd 10 fc ff ff 	lea    -0x3f0(%rbp),%rdi
 1289f25:	4c 8d 85 78 fc ff ff 	lea    -0x388(%rbp),%r8
 1289f2c:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1289f30:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 1289f37:	4c 89 e1             	mov    %r12,%rcx
 1289f3a:	e8 21 b7 f8 ff       	call   1215660 <lz77.lazyGreedyPlanAlloc>
 1289f3f:	0f b7 9d 38 fc ff ff 	movzwl -0x3c8(%rbp),%ebx
 1289f46:	66 85 db             	test   %bx,%bx
 1289f49:	0f 85 dd 10 00 00    	jne    128b02c <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x15dc>
 1289f4f:	4c 8b 85 10 fc ff ff 	mov    -0x3f0(%rbp),%r8
 1289f56:	4c 8b 8d 18 fc ff ff 	mov    -0x3e8(%rbp),%r9
 1289f5d:	48 8b 85 28 fc ff ff 	mov    -0x3d8(%rbp),%rax
 1289f64:	e9 b4 00 00 00       	jmp    128a01d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x5cd>
 1289f69:	48 8b 4d a0          	mov    -0x60(%rbp),%rcx
 1289f6d:	66 89 41 10          	mov    %ax,0x10(%rcx)
 1289f71:	e9 cd 0e 00 00       	jmp    128ae43 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x13f3>
 1289f76:	48 89 85 c0 fc ff ff 	mov    %rax,-0x340(%rbp)
 1289f7d:	48 8b 85 58 ff ff ff 	mov    -0xa8(%rbp),%rax
 1289f84:	48 89 85 c8 fc ff ff 	mov    %rax,-0x338(%rbp)
 1289f8b:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 1289f8f:	48 89 85 d0 fc ff ff 	mov    %rax,-0x330(%rbp)
 1289f96:	48 c7 85 d8 fc ff ff 	movq   $0x1,-0x328(%rbp)
 1289f9d:	01 00 00 00 
 1289fa1:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 1289fa8:	48 89 85 e0 fc ff ff 	mov    %rax,-0x320(%rbp)
 1289faf:	48 c7 85 e8 fc ff ff 	movq   $0x3,-0x318(%rbp)
 1289fb6:	03 00 00 00 
 1289fba:	48 c7 85 f0 fc ff ff 	movq   $0x102,-0x310(%rbp)
 1289fc1:	02 01 00 00 
 1289fc5:	48 c7 85 f8 fc ff ff 	movq   $0x0,-0x308(%rbp)
 1289fcc:	00 00 00 00 
 1289fd0:	c6 85 00 fd ff ff 00 	movb   $0x0,-0x300(%rbp)
 1289fd7:	48 8d bd 78 fe ff ff 	lea    -0x188(%rbp),%rdi
 1289fde:	4c 8d 85 c0 fc ff ff 	lea    -0x340(%rbp),%r8
 1289fe5:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1289fe9:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 1289ff0:	4c 89 e1             	mov    %r12,%rcx
 1289ff3:	e8 c8 a5 f8 ff       	call   12145c0 <lz77.hashGreedyPlanAllocWithAnchor__anon_72972>
 1289ff8:	0f b7 9d a0 fe ff ff 	movzwl -0x160(%rbp),%ebx
 1289fff:	66 85 db             	test   %bx,%bx
 128a002:	0f 85 7c 11 00 00    	jne    128b184 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1734>
 128a008:	4c 8b 85 78 fe ff ff 	mov    -0x188(%rbp),%r8
 128a00f:	4c 8b 8d 80 fe ff ff 	mov    -0x180(%rbp),%r9
 128a016:	48 8b 85 90 fe ff ff 	mov    -0x170(%rbp),%rax
 128a01d:	48 89 85 38 ff ff ff 	mov    %rax,-0xc8(%rbp)
 128a024:	48 8d bd 40 fc ff ff 	lea    -0x3c0(%rbp),%rdi
 128a02b:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 128a02f:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 128a036:	4c 89 e1             	mov    %r12,%rcx
 128a039:	4c 89 85 70 ff ff ff 	mov    %r8,-0x90(%rbp)
 128a040:	4c 89 4d 98          	mov    %r9,-0x68(%rbp)
 128a044:	e8 87 c9 f8 ff       	call   12169d0 <br.encoder.command_plan.buildAlloc>
 128a049:	0f b7 9d 58 fc ff ff 	movzwl -0x3a8(%rbp),%ebx
 128a050:	66 85 db             	test   %bx,%bx
 128a053:	0f 85 a5 0f 00 00    	jne    128affe <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x15ae>
 128a059:	48 8b 85 40 fc ff ff 	mov    -0x3c0(%rbp),%rax
 128a060:	48 89 85 58 ff ff ff 	mov    %rax,-0xa8(%rbp)
 128a067:	4c 8b 8d 48 fc ff ff 	mov    -0x3b8(%rbp),%r9
 128a06e:	c4 c1 78 10 47 58    	vmovups 0x58(%r15),%xmm0
 128a074:	41 0f b6 87 85 00 00 	movzbl 0x85(%r15),%eax
 128a07b:	00 
 128a07c:	0f b6 4d ac          	movzbl -0x54(%rbp),%ecx
 128a080:	80 e1 01             	and    $0x1,%cl
 128a083:	0f b6 75 88          	movzbl -0x78(%rbp),%esi
 128a087:	40 80 e6 01          	and    $0x1,%sil
 128a08b:	44 0f b6 5d 8d       	movzbl -0x73(%rbp),%r11d
 128a090:	41 80 e3 01          	and    $0x1,%r11b
 128a094:	0f b6 5d 8e          	movzbl -0x72(%rbp),%ebx
 128a098:	80 e3 01             	and    $0x1,%bl
 128a09b:	44 0f b6 55 8b       	movzbl -0x75(%rbp),%r10d
 128a0a0:	41 80 e2 01          	and    $0x1,%r10b
 128a0a4:	45 0a b7 8a 00 00 00 	or     0x8a(%r15),%r14b
 128a0ab:	41 80 e6 01          	and    $0x1,%r14b
 128a0af:	44 0f b6 45 8a       	movzbl -0x76(%rbp),%r8d
 128a0b4:	41 80 e0 01          	and    $0x1,%r8b
 128a0b8:	45 89 f5             	mov    %r14d,%r13d
 128a0bb:	44 0f b6 75 8f       	movzbl -0x71(%rbp),%r14d
 128a0c0:	45 0a b7 89 00 00 00 	or     0x89(%r15),%r14b
 128a0c7:	41 80 e6 01          	and    $0x1,%r14b
 128a0cb:	0f b6 7d 89          	movzbl -0x77(%rbp),%edi
 128a0cf:	40 80 e7 01          	and    $0x1,%dil
 128a0d3:	41 80 bf 8c 00 00 00 	cmpb   $0x0,0x8c(%r15)
 128a0da:	00 
 128a0db:	41 0f b6 97 8b 00 00 	movzbl 0x8b(%r15),%edx
 128a0e2:	00 
 128a0e3:	88 8d 51 fe ff ff    	mov    %cl,-0x1af(%rbp)
 128a0e9:	40 88 b5 52 fe ff ff 	mov    %sil,-0x1ae(%rbp)
 128a0f0:	c6 85 53 fe ff ff 01 	movb   $0x1,-0x1ad(%rbp)
 128a0f7:	44 88 9d 54 fe ff ff 	mov    %r11b,-0x1ac(%rbp)
 128a0fe:	88 9d 55 fe ff ff    	mov    %bl,-0x1ab(%rbp)
 128a104:	66 c7 85 56 fe ff ff 	movw   $0x0,-0x1aa(%rbp)
 128a10b:	00 00 
 128a10d:	44 88 95 58 fe ff ff 	mov    %r10b,-0x1a8(%rbp)
 128a114:	44 88 ad 59 fe ff ff 	mov    %r13b,-0x1a7(%rbp)
 128a11b:	44 88 85 5a fe ff ff 	mov    %r8b,-0x1a6(%rbp)
 128a122:	44 88 b5 5b fe ff ff 	mov    %r14b,-0x1a5(%rbp)
 128a129:	40 88 bd 5c fe ff ff 	mov    %dil,-0x1a4(%rbp)
 128a130:	0f b6 4d 8c          	movzbl -0x74(%rbp),%ecx
 128a134:	0f 45 ca             	cmovne %edx,%ecx
 128a137:	80 e1 01             	and    $0x1,%cl
 128a13a:	88 8d 5d fe ff ff    	mov    %cl,-0x1a3(%rbp)
 128a140:	24 01                	and    $0x1,%al
 128a142:	88 85 50 fe ff ff    	mov    %al,-0x1b0(%rbp)
 128a148:	48 8b 85 18 ff ff ff 	mov    -0xe8(%rbp),%rax
 128a14f:	88 85 5e fe ff ff    	mov    %al,-0x1a2(%rbp)
 128a155:	c5 f8 11 85 10 fe ff 	vmovups %xmm0,-0x1f0(%rbp)
 128a15c:	ff 
 128a15d:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 128a161:	c5 f8 11 85 20 fe ff 	vmovups %xmm0,-0x1e0(%rbp)
 128a168:	ff 
 128a169:	c5 fc 10 05 6f 7f d7 	vmovups -0x288091(%rip),%ymm0        # 10020e0 <__anon_35167>
 128a170:	ff 
 128a171:	c5 fc 11 85 30 fe ff 	vmovups %ymm0,-0x1d0(%rbp)
 128a178:	ff 
 128a179:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 128a17d:	c5 fc 11 85 b0 f6 ff 	vmovups %ymm0,-0x950(%rbp)
 128a184:	ff 
 128a185:	c5 fc 11 85 a0 f6 ff 	vmovups %ymm0,-0x960(%rbp)
 128a18c:	ff 
 128a18d:	c5 fc 11 85 80 f6 ff 	vmovups %ymm0,-0x980(%rbp)
 128a194:	ff 
 128a195:	40 88 b5 78 fe ff ff 	mov    %sil,-0x188(%rbp)
 128a19c:	c5 fc 11 85 60 f6 ff 	vmovups %ymm0,-0x9a0(%rbp)
 128a1a3:	ff 
 128a1a4:	c5 fc 11 85 40 f6 ff 	vmovups %ymm0,-0x9c0(%rbp)
 128a1ab:	ff 
 128a1ac:	48 83 bd 38 ff ff ff 	cmpq   $0x0,-0xc8(%rbp)
 128a1b3:	00 
 128a1b4:	4c 89 4d b0          	mov    %r9,-0x50(%rbp)
 128a1b8:	74 5f                	je     128a219 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x7c9>
 128a1ba:	48 8d 85 10 fe ff ff 	lea    -0x1f0(%rbp),%rax
 128a1c1:	4c 8d 95 40 f6 ff ff 	lea    -0x9c0(%rbp),%r10
 128a1c8:	48 8d bd b0 fd ff ff 	lea    -0x250(%rbp),%rdi
 128a1cf:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 128a1d3:	4c 8b bd 78 ff ff ff 	mov    -0x88(%rbp),%r15
 128a1da:	4c 89 fa             	mov    %r15,%rdx
 128a1dd:	4c 89 e1             	mov    %r12,%rcx
 128a1e0:	4c 8b ad 58 ff ff ff 	mov    -0xa8(%rbp),%r13
 128a1e7:	4d 89 e8             	mov    %r13,%r8
 128a1ea:	50                   	push   %rax
 128a1eb:	41 52                	push   %r10
 128a1ed:	c5 f8 77             	vzeroupper 
 128a1f0:	e8 db 01 f6 ff       	call   11ea3d0 <br.encodeLazyCommandPlanAllocRecorded__anon_43465>
 128a1f5:	48 83 c4 10          	add    $0x10,%rsp
 128a1f9:	0f b7 9d c0 fd ff ff 	movzwl -0x240(%rbp),%ebx
 128a200:	66 85 db             	test   %bx,%bx
 128a203:	0f 85 ca 0d 00 00    	jne    128afd3 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1583>
 128a209:	4c 8b b5 b0 fd ff ff 	mov    -0x250(%rbp),%r14
 128a210:	48 8b 9d b8 fd ff ff 	mov    -0x248(%rbp),%rbx
 128a217:	eb 4c                	jmp    128a265 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x815>
 128a219:	4c 8b ad 58 ff ff ff 	mov    -0xa8(%rbp),%r13
 128a220:	48 8d bd 78 fe ff ff 	lea    -0x188(%rbp),%rdi
 128a227:	4c 8d 85 e0 fd ff ff 	lea    -0x220(%rbp),%r8
 128a22e:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 128a232:	4c 8b bd 78 ff ff ff 	mov    -0x88(%rbp),%r15
 128a239:	4c 89 fa             	mov    %r15,%rdx
 128a23c:	4c 89 e1             	mov    %r12,%rcx
 128a23f:	c5 f8 77             	vzeroupper 
 128a242:	e8 39 ee f5 ff       	call   11e9080 <br.encodeStoredStreamWithOptionsAlloc>
 128a247:	0f b7 9d 88 fe ff ff 	movzwl -0x178(%rbp),%ebx
 128a24e:	66 85 db             	test   %bx,%bx
 128a251:	0f 85 49 0f 00 00    	jne    128b1a0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1750>
 128a257:	4c 8b b5 78 fe ff ff 	mov    -0x188(%rbp),%r14
 128a25e:	48 8b 9d 80 fe ff ff 	mov    -0x180(%rbp),%rbx
 128a265:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 128a269:	4c 89 b5 60 ff ff ff 	mov    %r14,-0xa0(%rbp)
 128a270:	48 89 9d 68 ff ff ff 	mov    %rbx,-0x98(%rbp)
 128a277:	48 83 7d c8 00       	cmpq   $0x0,-0x38(%rbp)
 128a27c:	74 56                	je     128a2d4 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x884>
 128a27e:	48 39 d9             	cmp    %rbx,%rcx
 128a281:	73 31                	jae    128a2b4 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x864>
 128a283:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128a287:	48 8b 38             	mov    (%rax),%rdi
 128a28a:	48 8b 40 08          	mov    0x8(%rax),%rax
 128a28e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128a292:	4c 89 f6             	mov    %r14,%rsi
 128a295:	48 89 da             	mov    %rbx,%rdx
 128a298:	48 89 cb             	mov    %rcx,%rbx
 128a29b:	31 c9                	xor    %ecx,%ecx
 128a29d:	ff 50 18             	call   *0x18(%rax)
 128a2a0:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 128a2a4:	48 89 85 60 ff ff ff 	mov    %rax,-0xa0(%rbp)
 128a2ab:	48 89 9d 68 ff ff ff 	mov    %rbx,-0x98(%rbp)
 128a2b2:	eb 28                	jmp    128a2dc <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x88c>
 128a2b4:	48 85 c9             	test   %rcx,%rcx
 128a2b7:	74 1b                	je     128a2d4 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x884>
 128a2b9:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128a2bd:	48 8b 38             	mov    (%rax),%rdi
 128a2c0:	48 8b 40 08          	mov    0x8(%rax),%rax
 128a2c4:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128a2c8:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 128a2cc:	48 89 ca             	mov    %rcx,%rdx
 128a2cf:	31 c9                	xor    %ecx,%ecx
 128a2d1:	ff 50 18             	call   *0x18(%rax)
 128a2d4:	4c 89 75 c8          	mov    %r14,-0x38(%rbp)
 128a2d8:	48 89 5d b8          	mov    %rbx,-0x48(%rbp)
 128a2dc:	0f b6 85 10 ff ff ff 	movzbl -0xf0(%rbp),%eax
 128a2e3:	24 03                	and    $0x3,%al
 128a2e5:	3c 02                	cmp    $0x2,%al
 128a2e7:	0f 94 c0             	sete   %al
 128a2ea:	80 bd 18 ff ff ff 11 	cmpb   $0x11,-0xe8(%rbp)
 128a2f1:	0f 93 c1             	setae  %cl
 128a2f4:	49 81 fc f2 ff 00 00 	cmp    $0xfff2,%r12
 128a2fb:	0f 93 c2             	setae  %dl
 128a2fe:	20 ca                	and    %cl,%dl
 128a300:	84 c2                	test   %al,%dl
 128a302:	74 7c                	je     128a380 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x930>
 128a304:	c6 85 48 ff ff ff 00 	movb   $0x0,-0xb8(%rbp)
 128a30b:	48 c7 85 b0 fb ff ff 	movq   $0x0,-0x450(%rbp)
 128a312:	00 00 00 00 
 128a316:	4c 89 a5 b8 fb ff ff 	mov    %r12,-0x448(%rbp)
 128a31d:	48 c7 85 c0 fb ff ff 	movq   $0x2,-0x440(%rbp)
 128a324:	02 00 00 00 
 128a328:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 128a32c:	c5 fc 11 85 c8 fb ff 	vmovups %ymm0,-0x438(%rbp)
 128a333:	ff 
 128a334:	c6 85 47 ff ff ff 00 	movb   $0x0,-0xb9(%rbp)
 128a33b:	c5 fc 11 85 e8 fb ff 	vmovups %ymm0,-0x418(%rbp)
 128a342:	ff 
 128a343:	66 c7 85 08 fc ff ff 	movw   $0x0,-0x3f8(%rbp)
 128a34a:	00 00 
 128a34c:	b8 01 00 00 00       	mov    $0x1,%eax
 128a351:	48 89 85 10 ff ff ff 	mov    %rax,-0xf0(%rbp)
 128a358:	48 83 7d b0 00       	cmpq   $0x0,-0x50(%rbp)
 128a35d:	74 36                	je     128a395 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x945>
 128a35f:	49 8d 45 58          	lea    0x58(%r13),%rax
 128a363:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 128a367:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 128a36e:	00 00 
 128a370:	f6 00 01             	testb  $0x1,(%rax)
 128a373:	75 14                	jne    128a389 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x939>
 128a375:	48 83 c0 60          	add    $0x60,%rax
 128a379:	48 ff c9             	dec    %rcx
 128a37c:	75 f2                	jne    128a370 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x920>
 128a37e:	eb 15                	jmp    128a395 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x945>
 128a380:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 128a384:	e9 10 02 00 00       	jmp    128a599 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xb49>
 128a389:	b8 02 00 00 00       	mov    $0x2,%eax
 128a38e:	48 89 85 10 ff ff ff 	mov    %rax,-0xf0(%rbp)
 128a395:	31 db                	xor    %ebx,%ebx
 128a397:	0f b6 85 20 ff ff ff 	movzbl -0xe0(%rbp),%eax
 128a39e:	48 89 85 20 ff ff ff 	mov    %rax,-0xe0(%rbp)
 128a3a5:	eb 20                	jmp    128a3c7 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x977>
 128a3a7:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 128a3ae:	00 00 
 128a3b0:	4c 8b ad 58 ff ff ff 	mov    -0xa8(%rbp),%r13
 128a3b7:	48 ff c3             	inc    %rbx
 128a3ba:	48 39 9d 10 ff ff ff 	cmp    %rbx,-0xf0(%rbp)
 128a3c1:	0f 84 bc 01 00 00    	je     128a583 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xb33>
 128a3c7:	48 85 db             	test   %rbx,%rbx
 128a3ca:	48 8d 85 b0 fb ff ff 	lea    -0x450(%rbp),%rax
 128a3d1:	49 0f 44 c5          	cmove  %r13,%rax
 128a3d5:	41 ba 01 00 00 00    	mov    $0x1,%r10d
 128a3db:	4c 0f 44 55 b0       	cmove  -0x50(%rbp),%r10
 128a3e0:	48 8d bd 78 fe ff ff 	lea    -0x188(%rbp),%rdi
 128a3e7:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 128a3eb:	48 8d 15 2b 31 e6 ff 	lea    -0x19ced5(%rip),%rdx        # 10ed51d <__anon_11996>
 128a3f2:	31 c9                	xor    %ecx,%ecx
 128a3f4:	4d 89 f8             	mov    %r15,%r8
 128a3f7:	4d 89 e1             	mov    %r12,%r9
 128a3fa:	ff b5 20 ff ff ff    	push   -0xe0(%rbp)
 128a400:	ff b5 60 fe ff ff    	push   -0x1a0(%rbp)
 128a406:	41 52                	push   %r10
 128a408:	50                   	push   %rax
 128a409:	c5 f8 77             	vzeroupper 
 128a40c:	e8 7f 19 f9 ff       	call   121bd90 <br.encoder.long_distance.augmentAllocWithHistoryAndMaxDistanceForFormat>
 128a411:	48 83 c4 20          	add    $0x20,%rsp
 128a415:	44 0f b7 b5 88 fe ff 	movzwl -0x178(%rbp),%r14d
 128a41c:	ff 
 128a41d:	66 45 85 f6          	test   %r14w,%r14w
 128a421:	0f 85 68 0a 00 00    	jne    128ae8f <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x143f>
 128a427:	4c 8b ad 78 fe ff ff 	mov    -0x188(%rbp),%r13
 128a42e:	4d 85 ed             	test   %r13,%r13
 128a431:	0f 84 79 ff ff ff    	je     128a3b0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x960>
 128a437:	4c 8b b5 80 fe ff ff 	mov    -0x180(%rbp),%r14
 128a43e:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 128a442:	c5 fc 11 85 20 f6 ff 	vmovups %ymm0,-0x9e0(%rbp)
 128a449:	ff 
 128a44a:	c5 fc 11 85 10 f6 ff 	vmovups %ymm0,-0x9f0(%rbp)
 128a451:	ff 
 128a452:	c5 fc 11 85 f0 f5 ff 	vmovups %ymm0,-0xa10(%rbp)
 128a459:	ff 
 128a45a:	c5 fc 11 85 d0 f5 ff 	vmovups %ymm0,-0xa30(%rbp)
 128a461:	ff 
 128a462:	c5 fc 11 85 b0 f5 ff 	vmovups %ymm0,-0xa50(%rbp)
 128a469:	ff 
 128a46a:	48 8d bd 98 fd ff ff 	lea    -0x268(%rbp),%rdi
 128a471:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 128a475:	4c 89 fa             	mov    %r15,%rdx
 128a478:	4c 89 e1             	mov    %r12,%rcx
 128a47b:	4d 89 e8             	mov    %r13,%r8
 128a47e:	4d 89 f1             	mov    %r14,%r9
 128a481:	48 8d 85 10 fe ff ff 	lea    -0x1f0(%rbp),%rax
 128a488:	50                   	push   %rax
 128a489:	48 8d 85 b0 f5 ff ff 	lea    -0xa50(%rbp),%rax
 128a490:	50                   	push   %rax
 128a491:	c5 f8 77             	vzeroupper 
 128a494:	e8 37 ff f5 ff       	call   11ea3d0 <br.encodeLazyCommandPlanAllocRecorded__anon_43465>
 128a499:	48 83 c4 10          	add    $0x10,%rsp
 128a49d:	44 0f b7 bd a8 fd ff 	movzwl -0x258(%rbp),%r15d
 128a4a4:	ff 
 128a4a5:	66 45 85 ff          	test   %r15w,%r15w
 128a4a9:	0f 85 68 0a 00 00    	jne    128af17 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x14c7>
 128a4af:	4c 8b a5 98 fd ff ff 	mov    -0x268(%rbp),%r12
 128a4b6:	4c 8b bd a0 fd ff ff 	mov    -0x260(%rbp),%r15
 128a4bd:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 128a4c1:	49 39 cf             	cmp    %rcx,%r15
 128a4c4:	73 7a                	jae    128a540 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xaf0>
 128a4c6:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128a4ca:	48 8b 38             	mov    (%rax),%rdi
 128a4cd:	48 8b 40 08          	mov    0x8(%rax),%rax
 128a4d1:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128a4d5:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 128a4d9:	48 89 ca             	mov    %rcx,%rdx
 128a4dc:	31 c9                	xor    %ecx,%ecx
 128a4de:	ff 50 18             	call   *0x18(%rax)
 128a4e1:	4d 85 f6             	test   %r14,%r14
 128a4e4:	74 22                	je     128a508 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xab8>
 128a4e6:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128a4ea:	48 8b 38             	mov    (%rax),%rdi
 128a4ed:	48 8b 40 08          	mov    0x8(%rax),%rax
 128a4f1:	49 c1 e6 05          	shl    $0x5,%r14
 128a4f5:	4b 8d 14 76          	lea    (%r14,%r14,2),%rdx
 128a4f9:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128a4fd:	4c 89 ee             	mov    %r13,%rsi
 128a500:	b9 03 00 00 00       	mov    $0x3,%ecx
 128a505:	ff 50 18             	call   *0x18(%rax)
 128a508:	4c 89 65 c8          	mov    %r12,-0x38(%rbp)
 128a50c:	4c 89 7d b8          	mov    %r15,-0x48(%rbp)
 128a510:	4c 8b a5 50 ff ff ff 	mov    -0xb0(%rbp),%r12
 128a517:	4c 8b bd 78 ff ff ff 	mov    -0x88(%rbp),%r15
 128a51e:	4c 8b ad 58 ff ff ff 	mov    -0xa8(%rbp),%r13
 128a525:	48 ff c3             	inc    %rbx
 128a528:	48 39 9d 10 ff ff ff 	cmp    %rbx,-0xf0(%rbp)
 128a52f:	0f 85 92 fe ff ff    	jne    128a3c7 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x977>
 128a535:	eb 4c                	jmp    128a583 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xb33>
 128a537:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 128a53e:	00 00 
 128a540:	4d 85 ff             	test   %r15,%r15
 128a543:	74 2c                	je     128a571 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xb21>
 128a545:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128a549:	48 8b 38             	mov    (%rax),%rdi
 128a54c:	48 8b 40 08          	mov    0x8(%rax),%rax
 128a550:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128a554:	4c 89 e6             	mov    %r12,%rsi
 128a557:	4c 89 fa             	mov    %r15,%rdx
 128a55a:	49 89 cf             	mov    %rcx,%r15
 128a55d:	31 c9                	xor    %ecx,%ecx
 128a55f:	ff 50 18             	call   *0x18(%rax)
 128a562:	4c 8b 65 c8          	mov    -0x38(%rbp),%r12
 128a566:	4d 85 f6             	test   %r14,%r14
 128a569:	0f 85 77 ff ff ff    	jne    128a4e6 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xa96>
 128a56f:	eb 97                	jmp    128a508 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xab8>
 128a571:	4c 8b 65 c8          	mov    -0x38(%rbp),%r12
 128a575:	49 89 cf             	mov    %rcx,%r15
 128a578:	4d 85 f6             	test   %r14,%r14
 128a57b:	0f 85 65 ff ff ff    	jne    128a4e6 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xa96>
 128a581:	eb 85                	jmp    128a508 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xab8>
 128a583:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 128a587:	48 89 95 68 ff ff ff 	mov    %rdx,-0x98(%rbp)
 128a58e:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 128a592:	48 89 85 60 ff ff ff 	mov    %rax,-0xa0(%rbp)
 128a599:	48 8b 85 68 fe ff ff 	mov    -0x198(%rbp),%rax
 128a5a0:	48 c1 e8 38          	shr    $0x38,%rax
 128a5a4:	83 e0 01             	and    $0x1,%eax
 128a5a7:	80 7d 90 00          	cmpb   $0x0,-0x70(%rbp)
 128a5ab:	44 0f b6 65 91       	movzbl -0x6f(%rbp),%r12d
 128a5b0:	44 0f 45 e0          	cmovne %eax,%r12d
 128a5b4:	0f b6 4d ac          	movzbl -0x54(%rbp),%ecx
 128a5b8:	44 20 e1             	and    %r12b,%cl
 128a5bb:	48 83 bd 38 ff ff ff 	cmpq   $0x0,-0xc8(%rbp)
 128a5c2:	00 
 128a5c3:	0f 95 c0             	setne  %al
 128a5c6:	84 c1                	test   %al,%cl
 128a5c8:	0f 84 1d 02 00 00    	je     128a7eb <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xd9b>
 128a5ce:	48 89 55 b8          	mov    %rdx,-0x48(%rbp)
 128a5d2:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 128a5d6:	c5 fc 11 85 90 f5 ff 	vmovups %ymm0,-0xa70(%rbp)
 128a5dd:	ff 
 128a5de:	c5 fc 11 85 80 f5 ff 	vmovups %ymm0,-0xa80(%rbp)
 128a5e5:	ff 
 128a5e6:	c5 fc 11 85 60 f5 ff 	vmovups %ymm0,-0xaa0(%rbp)
 128a5ed:	ff 
 128a5ee:	c5 fc 11 85 40 f5 ff 	vmovups %ymm0,-0xac0(%rbp)
 128a5f5:	ff 
 128a5f6:	c5 fc 11 85 20 f5 ff 	vmovups %ymm0,-0xae0(%rbp)
 128a5fd:	ff 
 128a5fe:	c6 45 84 00          	movb   $0x0,-0x7c(%rbp)
 128a602:	c6 45 85 00          	movb   $0x0,-0x7b(%rbp)
 128a606:	0f b6 45 93          	movzbl -0x6d(%rbp),%eax
 128a60a:	88 85 f1 f8 ff ff    	mov    %al,-0x70f(%rbp)
 128a610:	48 c7 85 e0 f6 ff ff 	movq   $0x0,-0x920(%rbp)
 128a617:	00 00 00 00 
 128a61b:	66 c7 85 f4 f8 ff ff 	movw   $0x100,-0x70c(%rbp)
 128a622:	00 01 
 128a624:	c5 fc 11 85 10 f7 ff 	vmovups %ymm0,-0x8f0(%rbp)
 128a62b:	ff 
 128a62c:	c5 fc 11 85 30 f7 ff 	vmovups %ymm0,-0x8d0(%rbp)
 128a633:	ff 
 128a634:	c5 fc 11 85 50 f7 ff 	vmovups %ymm0,-0x8b0(%rbp)
 128a63b:	ff 
 128a63c:	c5 fc 11 85 70 f7 ff 	vmovups %ymm0,-0x890(%rbp)
 128a643:	ff 
 128a644:	c5 fc 11 85 90 f7 ff 	vmovups %ymm0,-0x870(%rbp)
 128a64b:	ff 
 128a64c:	c5 fc 11 85 b0 f7 ff 	vmovups %ymm0,-0x850(%rbp)
 128a653:	ff 
 128a654:	c5 fc 11 85 d0 f7 ff 	vmovups %ymm0,-0x830(%rbp)
 128a65b:	ff 
 128a65c:	c5 fc 11 85 f0 f7 ff 	vmovups %ymm0,-0x810(%rbp)
 128a663:	ff 
 128a664:	c5 fc 11 85 10 f8 ff 	vmovups %ymm0,-0x7f0(%rbp)
 128a66b:	ff 
 128a66c:	c5 fc 11 85 30 f8 ff 	vmovups %ymm0,-0x7d0(%rbp)
 128a673:	ff 
 128a674:	c5 fc 11 85 50 f8 ff 	vmovups %ymm0,-0x7b0(%rbp)
 128a67b:	ff 
 128a67c:	c5 fc 11 85 70 f8 ff 	vmovups %ymm0,-0x790(%rbp)
 128a683:	ff 
 128a684:	c5 fc 11 85 90 f8 ff 	vmovups %ymm0,-0x770(%rbp)
 128a68b:	ff 
 128a68c:	c5 fc 11 85 b0 f8 ff 	vmovups %ymm0,-0x750(%rbp)
 128a693:	ff 
 128a694:	48 c7 85 d0 f8 ff ff 	movq   $0x0,-0x730(%rbp)
 128a69b:	00 00 00 00 
 128a69f:	c6 85 e8 f8 ff ff 38 	movb   $0x38,-0x718(%rbp)
 128a6a6:	c6 85 f0 f8 ff ff 00 	movb   $0x0,-0x710(%rbp)
 128a6ad:	0f b6 45 84          	movzbl -0x7c(%rbp),%eax
 128a6b1:	0f b6 4d 85          	movzbl -0x7b(%rbp),%ecx
 128a6b5:	88 85 ea f8 ff ff    	mov    %al,-0x716(%rbp)
 128a6bb:	88 8d eb f8 ff ff    	mov    %cl,-0x715(%rbp)
 128a6c1:	48 8b 85 18 ff ff ff 	mov    -0xe8(%rbp),%rax
 128a6c8:	88 85 e9 f8 ff ff    	mov    %al,-0x717(%rbp)
 128a6ce:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 128a6d5:	48 89 85 d0 f6 ff ff 	mov    %rax,-0x930(%rbp)
 128a6dc:	48 8b 85 30 ff ff ff 	mov    -0xd0(%rbp),%rax
 128a6e3:	48 89 85 d8 f6 ff ff 	mov    %rax,-0x928(%rbp)
 128a6ea:	c7 85 ec f8 ff ff 01 	movl   $0x1000101,-0x714(%rbp)
 128a6f1:	01 00 01 
 128a6f4:	66 c7 85 f2 f8 ff ff 	movw   $0x0,-0x70e(%rbp)
 128a6fb:	00 00 
 128a6fd:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 128a701:	c5 f8 11 85 d8 f8 ff 	vmovups %xmm0,-0x728(%rbp)
 128a708:	ff 
 128a709:	c5 fc 10 05 cf 79 d7 	vmovups -0x288631(%rip),%ymm0        # 10020e0 <__anon_35167>
 128a710:	ff 
 128a711:	c5 fc 11 85 f0 f6 ff 	vmovups %ymm0,-0x910(%rbp)
 128a718:	ff 
 128a719:	48 c7 85 e8 f6 ff ff 	movq   $0x0,-0x918(%rbp)
 128a720:	00 00 00 00 
 128a724:	48 83 ec 08          	sub    $0x8,%rsp
 128a728:	48 8d 85 d0 f6 ff ff 	lea    -0x930(%rbp),%rax
 128a72f:	4c 8d 95 20 f5 ff ff 	lea    -0xae0(%rbp),%r10
 128a736:	48 8d bd 80 fd ff ff 	lea    -0x280(%rbp),%rdi
 128a73d:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 128a741:	4c 89 fa             	mov    %r15,%rdx
 128a744:	48 8b 8d 50 ff ff ff 	mov    -0xb0(%rbp),%rcx
 128a74b:	4d 89 e8             	mov    %r13,%r8
 128a74e:	4c 8b 4d b0          	mov    -0x50(%rbp),%r9
 128a752:	50                   	push   %rax
 128a753:	41 52                	push   %r10
 128a755:	6a 01                	push   $0x1
 128a757:	c5 f8 77             	vzeroupper 
 128a75a:	e8 b1 74 f9 ff       	call   1221c10 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77146>
 128a75f:	48 83 c4 20          	add    $0x20,%rsp
 128a763:	0f b7 9d 90 fd ff ff 	movzwl -0x270(%rbp),%ebx
 128a76a:	66 85 db             	test   %bx,%bx
 128a76d:	0f 85 e9 08 00 00    	jne    128b05c <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x160c>
 128a773:	4c 8b b5 80 fd ff ff 	mov    -0x280(%rbp),%r14
 128a77a:	48 8b 9d 88 fd ff ff 	mov    -0x278(%rbp),%rbx
 128a781:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 128a785:	48 39 d3             	cmp    %rdx,%rbx
 128a788:	73 3e                	jae    128a7c8 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xd78>
 128a78a:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128a78e:	48 8b 38             	mov    (%rax),%rdi
 128a791:	48 8b 40 08          	mov    0x8(%rax),%rax
 128a795:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128a799:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 128a79d:	31 c9                	xor    %ecx,%ecx
 128a79f:	ff 50 18             	call   *0x18(%rax)
 128a7a2:	4c 89 b5 60 ff ff ff 	mov    %r14,-0xa0(%rbp)
 128a7a9:	48 89 9d 68 ff ff ff 	mov    %rbx,-0x98(%rbp)
 128a7b0:	0f b6 45 ae          	movzbl -0x52(%rbp),%eax
 128a7b4:	4c 89 75 c8          	mov    %r14,-0x38(%rbp)
 128a7b8:	48 89 da             	mov    %rbx,%rdx
 128a7bb:	a8 01                	test   $0x1,%al
 128a7bd:	75 34                	jne    128a7f3 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xda3>
 128a7bf:	4c 8b 7d c8          	mov    -0x38(%rbp),%r15
 128a7c3:	e9 42 01 00 00       	jmp    128a90a <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xeba>
 128a7c8:	48 85 db             	test   %rbx,%rbx
 128a7cb:	74 1e                	je     128a7eb <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xd9b>
 128a7cd:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128a7d1:	48 8b 38             	mov    (%rax),%rdi
 128a7d4:	48 8b 40 08          	mov    0x8(%rax),%rax
 128a7d8:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128a7dc:	4c 89 f6             	mov    %r14,%rsi
 128a7df:	48 89 da             	mov    %rbx,%rdx
 128a7e2:	31 c9                	xor    %ecx,%ecx
 128a7e4:	ff 50 18             	call   *0x18(%rax)
 128a7e7:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 128a7eb:	0f b6 45 c5          	movzbl -0x3b(%rbp),%eax
 128a7ef:	a8 01                	test   $0x1,%al
 128a7f1:	74 cc                	je     128a7bf <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xd6f>
 128a7f3:	49 89 d6             	mov    %rdx,%r14
 128a7f6:	48 8b 8d 50 ff ff ff 	mov    -0xb0(%rbp),%rcx
 128a7fd:	48 81 f9 00 10 00 00 	cmp    $0x1000,%rcx
 128a804:	0f 82 c8 00 00 00    	jb     128a8d2 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xe82>
 128a80a:	48 3b 8d 70 fe ff ff 	cmp    -0x190(%rbp),%rcx
 128a811:	0f 87 bb 00 00 00    	ja     128a8d2 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xe82>
 128a817:	c5 f8 28 85 60 fc ff 	vmovaps -0x3a0(%rbp),%xmm0
 128a81e:	ff 
 128a81f:	c5 f8 13 85 b0 fe ff 	vmovlps %xmm0,-0x150(%rbp)
 128a826:	ff 
 128a827:	8b 85 08 ff ff ff    	mov    -0xf8(%rbp),%eax
 128a82d:	89 85 b8 fe ff ff    	mov    %eax,-0x148(%rbp)
 128a833:	0f b7 85 0c ff ff ff 	movzwl -0xf4(%rbp),%eax
 128a83a:	66 89 85 bc fe ff ff 	mov    %ax,-0x144(%rbp)
 128a841:	0f b6 45 ae          	movzbl -0x52(%rbp),%eax
 128a845:	88 85 be fe ff ff    	mov    %al,-0x142(%rbp)
 128a84b:	0f b6 45 92          	movzbl -0x6e(%rbp),%eax
 128a84f:	88 85 bf fe ff ff    	mov    %al,-0x141(%rbp)
 128a855:	48 8d bd 68 fd ff ff 	lea    -0x298(%rbp),%rdi
 128a85c:	4c 8d 85 b0 fe ff ff 	lea    -0x150(%rbp),%r8
 128a863:	4c 8d 8d 10 fe ff ff 	lea    -0x1f0(%rbp),%r9
 128a86a:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 128a86e:	4c 89 fa             	mov    %r15,%rdx
 128a871:	e8 5a 0a 00 00       	call   128b2d0 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653>
 128a876:	0f b7 9d 78 fd ff ff 	movzwl -0x288(%rbp),%ebx
 128a87d:	66 85 db             	test   %bx,%bx
 128a880:	0f 85 e1 07 00 00    	jne    128b067 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1617>
 128a886:	4c 8b bd 68 fd ff ff 	mov    -0x298(%rbp),%r15
 128a88d:	4d 85 ff             	test   %r15,%r15
 128a890:	4c 89 f1             	mov    %r14,%rcx
 128a893:	74 6e                	je     128a903 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xeb3>
 128a895:	48 8b 95 70 fd ff ff 	mov    -0x290(%rbp),%rdx
 128a89c:	48 39 ca             	cmp    %rcx,%rdx
 128a89f:	73 3a                	jae    128a8db <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xe8b>
 128a8a1:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128a8a5:	48 8b 38             	mov    (%rax),%rdi
 128a8a8:	48 8b 40 08          	mov    0x8(%rax),%rax
 128a8ac:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128a8b0:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 128a8b4:	48 89 d3             	mov    %rdx,%rbx
 128a8b7:	48 89 ca             	mov    %rcx,%rdx
 128a8ba:	31 c9                	xor    %ecx,%ecx
 128a8bc:	ff 50 18             	call   *0x18(%rax)
 128a8bf:	48 89 da             	mov    %rbx,%rdx
 128a8c2:	4c 89 bd 60 ff ff ff 	mov    %r15,-0xa0(%rbp)
 128a8c9:	48 89 9d 68 ff ff ff 	mov    %rbx,-0x98(%rbp)
 128a8d0:	eb 38                	jmp    128a90a <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xeba>
 128a8d2:	4c 8b 7d c8          	mov    -0x38(%rbp),%r15
 128a8d6:	4c 89 f2             	mov    %r14,%rdx
 128a8d9:	eb 2f                	jmp    128a90a <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xeba>
 128a8db:	48 85 d2             	test   %rdx,%rdx
 128a8de:	74 23                	je     128a903 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xeb3>
 128a8e0:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128a8e4:	48 8b 38             	mov    (%rax),%rdi
 128a8e7:	48 8b 40 08          	mov    0x8(%rax),%rax
 128a8eb:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128a8ef:	4c 89 fe             	mov    %r15,%rsi
 128a8f2:	48 89 cb             	mov    %rcx,%rbx
 128a8f5:	31 c9                	xor    %ecx,%ecx
 128a8f7:	ff 50 18             	call   *0x18(%rax)
 128a8fa:	4c 8b 7d c8          	mov    -0x38(%rbp),%r15
 128a8fe:	48 89 da             	mov    %rbx,%rdx
 128a901:	eb 07                	jmp    128a90a <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xeba>
 128a903:	4c 8b 7d c8          	mov    -0x38(%rbp),%r15
 128a907:	48 89 ca             	mov    %rcx,%rdx
 128a90a:	80 7d ad 0a          	cmpb   $0xa,-0x53(%rbp)
 128a90e:	0f 93 c0             	setae  %al
 128a911:	f6 85 00 ff ff ff 10 	testb  $0x10,-0x100(%rbp)
 128a918:	0f 95 c1             	setne  %cl
 128a91b:	20 c1                	and    %al,%cl
 128a91d:	4c 8b b5 50 ff ff ff 	mov    -0xb0(%rbp),%r14
 128a924:	49 8d 86 00 f0 ff ff 	lea    -0x1000(%r14),%rax
 128a92b:	48 3d 01 f0 00 00    	cmp    $0xf001,%rax
 128a931:	0f 92 c0             	setb   %al
 128a934:	84 c1                	test   %al,%cl
 128a936:	0f 84 02 01 00 00    	je     128aa3e <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xfee>
 128a93c:	48 8b 9d 78 ff ff ff 	mov    -0x88(%rbp),%rbx
 128a943:	42 80 7c 33 ff 0a    	cmpb   $0xa,-0x1(%rbx,%r14,1)
 128a949:	0f 85 ef 00 00 00    	jne    128aa3e <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xfee>
 128a94f:	48 89 55 b8          	mov    %rdx,-0x48(%rbp)
 128a953:	48 89 df             	mov    %rbx,%rdi
 128a956:	4c 89 f6             	mov    %r14,%rsi
 128a959:	e8 32 ff e6 ff       	call   10fa890 <vortBrStableFixedWidthRecord>
 128a95e:	84 c0                	test   %al,%al
 128a960:	0f 84 ef 04 00 00    	je     128ae55 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1405>
 128a966:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 128a96a:	c5 fc 11 85 00 f5 ff 	vmovups %ymm0,-0xb00(%rbp)
 128a971:	ff 
 128a972:	c5 fc 11 85 f0 f4 ff 	vmovups %ymm0,-0xb10(%rbp)
 128a979:	ff 
 128a97a:	c5 fc 11 85 d0 f4 ff 	vmovups %ymm0,-0xb30(%rbp)
 128a981:	ff 
 128a982:	c5 fc 11 85 b0 f4 ff 	vmovups %ymm0,-0xb50(%rbp)
 128a989:	ff 
 128a98a:	c5 fc 11 85 90 f4 ff 	vmovups %ymm0,-0xb70(%rbp)
 128a991:	ff 
 128a992:	44 0f b6 4d c6       	movzbl -0x3a(%rbp),%r9d
 128a997:	48 8d 85 90 f4 ff ff 	lea    -0xb70(%rbp),%rax
 128a99e:	45 0f b6 d4          	movzbl %r12b,%r10d
 128a9a2:	44 0f b6 85 00 ff ff 	movzbl -0x100(%rbp),%r8d
 128a9a9:	ff 
 128a9aa:	48 8d bd 50 fd ff ff 	lea    -0x2b0(%rbp),%rdi
 128a9b1:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 128a9b5:	48 89 da             	mov    %rbx,%rdx
 128a9b8:	4c 89 f1             	mov    %r14,%rcx
 128a9bb:	50                   	push   %rax
 128a9bc:	41 52                	push   %r10
 128a9be:	ff b5 30 ff ff ff    	push   -0xd0(%rbp)
 128a9c4:	ff b5 28 ff ff ff    	push   -0xd8(%rbp)
 128a9ca:	c5 f8 77             	vzeroupper 
 128a9cd:	e8 1e e7 ff ff       	call   12890f0 <br.encodeRecordOptimalCandidateWithOptionsAlloc>
 128a9d2:	48 83 c4 20          	add    $0x20,%rsp
 128a9d6:	0f b7 9d 60 fd ff ff 	movzwl -0x2a0(%rbp),%ebx
 128a9dd:	66 85 db             	test   %bx,%bx
 128a9e0:	0f 85 54 08 00 00    	jne    128b23a <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x17ea>
 128a9e6:	48 8b 85 50 fd ff ff 	mov    -0x2b0(%rbp),%rax
 128a9ed:	48 89 45 c8          	mov    %rax,-0x38(%rbp)
 128a9f1:	48 85 c0             	test   %rax,%rax
 128a9f4:	44 0f b6 65 c7       	movzbl -0x39(%rbp),%r12d
 128a9f9:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 128a9fd:	0f 84 84 04 00 00    	je     128ae87 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1437>
 128aa03:	48 8b 9d 58 fd ff ff 	mov    -0x2a8(%rbp),%rbx
 128aa0a:	48 39 d3             	cmp    %rdx,%rbx
 128aa0d:	0f 83 4b 04 00 00    	jae    128ae5e <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x140e>
 128aa13:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128aa17:	48 8b 38             	mov    (%rax),%rdi
 128aa1a:	48 8b 40 08          	mov    0x8(%rax),%rax
 128aa1e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128aa22:	4c 89 fe             	mov    %r15,%rsi
 128aa25:	31 c9                	xor    %ecx,%ecx
 128aa27:	ff 50 18             	call   *0x18(%rax)
 128aa2a:	4c 8b 7d c8          	mov    -0x38(%rbp),%r15
 128aa2e:	4c 89 bd 60 ff ff ff 	mov    %r15,-0xa0(%rbp)
 128aa35:	48 89 9d 68 ff ff ff 	mov    %rbx,-0x98(%rbp)
 128aa3c:	eb 08                	jmp    128aa46 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xff6>
 128aa3e:	48 89 d3             	mov    %rdx,%rbx
 128aa41:	44 0f b6 65 c7       	movzbl -0x39(%rbp),%r12d
 128aa46:	41 80 e4 03          	and    $0x3,%r12b
 128aa4a:	41 80 fc 02          	cmp    $0x2,%r12b
 128aa4e:	0f 94 c0             	sete   %al
 128aa51:	80 7d ad 04          	cmpb   $0x4,-0x53(%rbp)
 128aa55:	0f 93 c1             	setae  %cl
 128aa58:	84 c8                	test   %cl,%al
 128aa5a:	0f 84 eb 01 00 00    	je     128ac4b <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x11fb>
 128aa60:	4c 89 7d c8          	mov    %r15,-0x38(%rbp)
 128aa64:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 128aa68:	c5 fc 11 85 70 f4 ff 	vmovups %ymm0,-0xb90(%rbp)
 128aa6f:	ff 
 128aa70:	c5 fc 11 85 60 f4 ff 	vmovups %ymm0,-0xba0(%rbp)
 128aa77:	ff 
 128aa78:	c5 fc 11 85 40 f4 ff 	vmovups %ymm0,-0xbc0(%rbp)
 128aa7f:	ff 
 128aa80:	c5 fc 11 85 20 f4 ff 	vmovups %ymm0,-0xbe0(%rbp)
 128aa87:	ff 
 128aa88:	c5 fc 11 85 00 f4 ff 	vmovups %ymm0,-0xc00(%rbp)
 128aa8f:	ff 
 128aa90:	0f b6 45 87          	movzbl -0x79(%rbp),%eax
 128aa94:	c6 45 82 01          	movb   $0x1,-0x7e(%rbp)
 128aa98:	c6 45 83 06          	movb   $0x6,-0x7d(%rbp)
 128aa9c:	0f b6 4d c6          	movzbl -0x3a(%rbp),%ecx
 128aaa0:	88 8d 19 fb ff ff    	mov    %cl,-0x4e7(%rbp)
 128aaa6:	48 c7 85 08 f9 ff ff 	movq   $0x0,-0x6f8(%rbp)
 128aaad:	00 00 00 00 
 128aab1:	88 85 1d fb ff ff    	mov    %al,-0x4e3(%rbp)
 128aab7:	c6 85 1c fb ff ff 00 	movb   $0x0,-0x4e4(%rbp)
 128aabe:	c5 fc 11 85 38 f9 ff 	vmovups %ymm0,-0x6c8(%rbp)
 128aac5:	ff 
 128aac6:	c5 fc 11 85 58 f9 ff 	vmovups %ymm0,-0x6a8(%rbp)
 128aacd:	ff 
 128aace:	c5 fc 11 85 78 f9 ff 	vmovups %ymm0,-0x688(%rbp)
 128aad5:	ff 
 128aad6:	c5 fc 11 85 98 f9 ff 	vmovups %ymm0,-0x668(%rbp)
 128aadd:	ff 
 128aade:	c5 fc 11 85 b8 f9 ff 	vmovups %ymm0,-0x648(%rbp)
 128aae5:	ff 
 128aae6:	c5 fc 11 85 d8 f9 ff 	vmovups %ymm0,-0x628(%rbp)
 128aaed:	ff 
 128aaee:	c5 fc 11 85 f8 f9 ff 	vmovups %ymm0,-0x608(%rbp)
 128aaf5:	ff 
 128aaf6:	c5 fc 11 85 18 fa ff 	vmovups %ymm0,-0x5e8(%rbp)
 128aafd:	ff 
 128aafe:	c5 fc 11 85 38 fa ff 	vmovups %ymm0,-0x5c8(%rbp)
 128ab05:	ff 
 128ab06:	c5 fc 11 85 58 fa ff 	vmovups %ymm0,-0x5a8(%rbp)
 128ab0d:	ff 
 128ab0e:	c5 fc 11 85 78 fa ff 	vmovups %ymm0,-0x588(%rbp)
 128ab15:	ff 
 128ab16:	c5 fc 11 85 98 fa ff 	vmovups %ymm0,-0x568(%rbp)
 128ab1d:	ff 
 128ab1e:	c5 fc 11 85 b8 fa ff 	vmovups %ymm0,-0x548(%rbp)
 128ab25:	ff 
 128ab26:	c5 fc 11 85 d8 fa ff 	vmovups %ymm0,-0x528(%rbp)
 128ab2d:	ff 
 128ab2e:	48 c7 85 f8 fa ff ff 	movq   $0x0,-0x508(%rbp)
 128ab35:	00 00 00 00 
 128ab39:	c6 85 10 fb ff ff 38 	movb   $0x38,-0x4f0(%rbp)
 128ab40:	c6 85 18 fb ff ff 00 	movb   $0x0,-0x4e8(%rbp)
 128ab47:	0f b6 45 82          	movzbl -0x7e(%rbp),%eax
 128ab4b:	0f b6 4d 83          	movzbl -0x7d(%rbp),%ecx
 128ab4f:	88 85 12 fb ff ff    	mov    %al,-0x4ee(%rbp)
 128ab55:	88 8d 13 fb ff ff    	mov    %cl,-0x4ed(%rbp)
 128ab5b:	48 8b 85 18 ff ff ff 	mov    -0xe8(%rbp),%rax
 128ab62:	88 85 11 fb ff ff    	mov    %al,-0x4ef(%rbp)
 128ab68:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 128ab6f:	48 89 85 f8 f8 ff ff 	mov    %rax,-0x708(%rbp)
 128ab76:	48 8b 85 30 ff ff ff 	mov    -0xd0(%rbp),%rax
 128ab7d:	48 89 85 00 f9 ff ff 	mov    %rax,-0x700(%rbp)
 128ab84:	c7 85 14 fb ff ff 01 	movl   $0x101,-0x4ec(%rbp)
 128ab8b:	01 00 00 
 128ab8e:	66 c7 85 1a fb ff ff 	movw   $0x0,-0x4e6(%rbp)
 128ab95:	00 00 
 128ab97:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 128ab9b:	c5 f8 11 85 00 fb ff 	vmovups %xmm0,-0x500(%rbp)
 128aba2:	ff 
 128aba3:	c5 fc 10 05 35 75 d7 	vmovups -0x288acb(%rip),%ymm0        # 10020e0 <__anon_35167>
 128abaa:	ff 
 128abab:	c5 fc 11 85 18 f9 ff 	vmovups %ymm0,-0x6e8(%rbp)
 128abb2:	ff 
 128abb3:	48 c7 85 10 f9 ff ff 	movq   $0x0,-0x6f0(%rbp)
 128abba:	00 00 00 00 
 128abbe:	48 8d 85 f8 f8 ff ff 	lea    -0x708(%rbp),%rax
 128abc5:	4c 8d 95 00 f4 ff ff 	lea    -0xc00(%rbp),%r10
 128abcc:	48 8d bd 38 fd ff ff 	lea    -0x2c8(%rbp),%rdi
 128abd3:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 128abd7:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 128abde:	4c 89 f1             	mov    %r14,%rcx
 128abe1:	4d 89 e8             	mov    %r13,%r8
 128abe4:	4c 8b 4d b0          	mov    -0x50(%rbp),%r9
 128abe8:	50                   	push   %rax
 128abe9:	41 52                	push   %r10
 128abeb:	c5 f8 77             	vzeroupper 
 128abee:	e8 0d 9e ee ff       	call   1174a00 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307>
 128abf3:	48 83 c4 10          	add    $0x10,%rsp
 128abf7:	44 0f b7 b5 48 fd ff 	movzwl -0x2b8(%rbp),%r14d
 128abfe:	ff 
 128abff:	45 85 f6             	test   %r14d,%r14d
 128ac02:	0f 85 de 04 00 00    	jne    128b0e6 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1696>
 128ac08:	4c 8b bd 38 fd ff ff 	mov    -0x2c8(%rbp),%r15
 128ac0f:	4c 8b a5 40 fd ff ff 	mov    -0x2c0(%rbp),%r12
 128ac16:	4d 85 ff             	test   %r15,%r15
 128ac19:	74 54                	je     128ac6f <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x121f>
 128ac1b:	49 39 dc             	cmp    %rbx,%r12
 128ac1e:	73 30                	jae    128ac50 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1200>
 128ac20:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128ac24:	48 8b 38             	mov    (%rax),%rdi
 128ac27:	48 8b 40 08          	mov    0x8(%rax),%rax
 128ac2b:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128ac2f:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 128ac33:	48 89 da             	mov    %rbx,%rdx
 128ac36:	31 c9                	xor    %ecx,%ecx
 128ac38:	ff 50 18             	call   *0x18(%rax)
 128ac3b:	4c 89 bd 60 ff ff ff 	mov    %r15,-0xa0(%rbp)
 128ac42:	4c 89 a5 68 ff ff ff 	mov    %r12,-0x98(%rbp)
 128ac49:	eb 2b                	jmp    128ac76 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1226>
 128ac4b:	49 89 dc             	mov    %rbx,%r12
 128ac4e:	eb 26                	jmp    128ac76 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1226>
 128ac50:	4d 85 e4             	test   %r12,%r12
 128ac53:	74 1a                	je     128ac6f <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x121f>
 128ac55:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128ac59:	48 8b 38             	mov    (%rax),%rdi
 128ac5c:	48 8b 40 08          	mov    0x8(%rax),%rax
 128ac60:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128ac64:	4c 89 fe             	mov    %r15,%rsi
 128ac67:	4c 89 e2             	mov    %r12,%rdx
 128ac6a:	31 c9                	xor    %ecx,%ecx
 128ac6c:	ff 50 18             	call   *0x18(%rax)
 128ac6f:	49 89 dc             	mov    %rbx,%r12
 128ac72:	4c 8b 7d c8          	mov    -0x38(%rbp),%r15
 128ac76:	48 8b 8d 50 ff ff ff 	mov    -0xb0(%rbp),%rcx
 128ac7d:	48 81 f9 01 01 00 00 	cmp    $0x101,%rcx
 128ac84:	0f 92 c0             	setb   %al
 128ac87:	84 45 94             	test   %al,-0x6c(%rbp)
 128ac8a:	74 72                	je     128acfe <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x12ae>
 128ac8c:	0f b6 45 c6          	movzbl -0x3a(%rbp),%eax
 128ac90:	44 0f b6 95 00 ff ff 	movzbl -0x100(%rbp),%r10d
 128ac97:	ff 
 128ac98:	48 8d bd 20 fd ff ff 	lea    -0x2e0(%rbp),%rdi
 128ac9f:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 128aca3:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 128acaa:	4d 89 e8             	mov    %r13,%r8
 128acad:	4c 8b 4d b0          	mov    -0x50(%rbp),%r9
 128acb1:	ff b5 30 ff ff ff    	push   -0xd0(%rbp)
 128acb7:	ff b5 28 ff ff ff    	push   -0xd8(%rbp)
 128acbd:	50                   	push   %rax
 128acbe:	41 52                	push   %r10
 128acc0:	41 54                	push   %r12
 128acc2:	41 57                	push   %r15
 128acc4:	e8 47 cb ff ff       	call   1287810 <br.selectRatioStaticDictionaryAlloc>
 128acc9:	48 83 c4 30          	add    $0x30,%rsp
 128accd:	0f b7 9d 30 fd ff ff 	movzwl -0x2d0(%rbp),%ebx
 128acd4:	66 85 db             	test   %bx,%bx
 128acd7:	0f 85 aa 03 00 00    	jne    128b087 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1637>
 128acdd:	4c 8b bd 20 fd ff ff 	mov    -0x2e0(%rbp),%r15
 128ace4:	4c 8b a5 28 fd ff ff 	mov    -0x2d8(%rbp),%r12
 128aceb:	4c 89 bd 60 ff ff ff 	mov    %r15,-0xa0(%rbp)
 128acf2:	4c 89 a5 68 ff ff ff 	mov    %r12,-0x98(%rbp)
 128acf9:	e9 89 00 00 00       	jmp    128ad87 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1337>
 128acfe:	48 81 f9 01 10 00 00 	cmp    $0x1001,%rcx
 128ad05:	0f 92 c0             	setb   %al
 128ad08:	84 45 86             	test   %al,-0x7a(%rbp)
 128ad0b:	74 7a                	je     128ad87 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1337>
 128ad0d:	8b 85 c0 fe ff ff    	mov    -0x140(%rbp),%eax
 128ad13:	66 85 c0             	test   %ax,%ax
 128ad16:	0f 44 85 c4 fe ff ff 	cmove  -0x13c(%rbp),%eax
 128ad1d:	66 85 c0             	test   %ax,%ax
 128ad20:	74 65                	je     128ad87 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1337>
 128ad22:	0f b7 c0             	movzwl %ax,%eax
 128ad25:	44 0f b6 55 c6       	movzbl -0x3a(%rbp),%r10d
 128ad2a:	48 83 ec 08          	sub    $0x8,%rsp
 128ad2e:	4c 8d 9d 60 ff ff ff 	lea    -0xa0(%rbp),%r11
 128ad35:	44 0f b6 8d 00 ff ff 	movzbl -0x100(%rbp),%r9d
 128ad3c:	ff 
 128ad3d:	48 8b 7d d0          	mov    -0x30(%rbp),%rdi
 128ad41:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 128ad48:	48 8b 95 50 ff ff ff 	mov    -0xb0(%rbp),%rdx
 128ad4f:	4c 89 e9             	mov    %r13,%rcx
 128ad52:	4c 8b 45 b0          	mov    -0x50(%rbp),%r8
 128ad56:	41 53                	push   %r11
 128ad58:	50                   	push   %rax
 128ad59:	ff b5 30 ff ff ff    	push   -0xd0(%rbp)
 128ad5f:	ff b5 28 ff ff ff    	push   -0xd8(%rbp)
 128ad65:	41 52                	push   %r10
 128ad67:	e8 f4 e0 ff ff       	call   1288e60 <br.selectExtendedRatioStaticDictionary>
 128ad6c:	48 83 c4 30          	add    $0x30,%rsp
 128ad70:	66 85 c0             	test   %ax,%ax
 128ad73:	0f 85 e0 04 00 00    	jne    128b259 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1809>
 128ad79:	4c 8b bd 60 ff ff ff 	mov    -0xa0(%rbp),%r15
 128ad80:	4c 8b a5 68 ff ff ff 	mov    -0x98(%rbp),%r12
 128ad87:	48 83 ec 08          	sub    $0x8,%rsp
 128ad8b:	48 8d 85 e0 fd ff ff 	lea    -0x220(%rbp),%rax
 128ad92:	48 8d bd 08 fd ff ff 	lea    -0x2f8(%rbp),%rdi
 128ad99:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 128ad9d:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 128ada4:	48 8b 8d 50 ff ff ff 	mov    -0xb0(%rbp),%rcx
 128adab:	4d 89 f8             	mov    %r15,%r8
 128adae:	4d 89 e1             	mov    %r12,%r9
 128adb1:	50                   	push   %rax
 128adb2:	e8 59 9b ee ff       	call   1174910 <br.chooseStoredIfSmallerWithOptionsRecorded__anon_35219>
 128adb7:	48 83 c4 10          	add    $0x10,%rsp
 128adbb:	0f b7 9d 18 fd ff ff 	movzwl -0x2e8(%rbp),%ebx
 128adc2:	66 85 db             	test   %bx,%bx
 128adc5:	0f 85 bc 02 00 00    	jne    128b087 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1637>
 128adcb:	48 8b 9d 08 fd ff ff 	mov    -0x2f8(%rbp),%rbx
 128add2:	4c 8b b5 10 fd ff ff 	mov    -0x2f0(%rbp),%r14
 128add9:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 128addd:	48 85 c9             	test   %rcx,%rcx
 128ade0:	74 22                	je     128ae04 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x13b4>
 128ade2:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128ade6:	48 8b 38             	mov    (%rax),%rdi
 128ade9:	48 8b 40 08          	mov    0x8(%rax),%rax
 128aded:	48 c1 e1 05          	shl    $0x5,%rcx
 128adf1:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128adf5:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128adf9:	4c 89 ee             	mov    %r13,%rsi
 128adfc:	b9 03 00 00 00       	mov    $0x3,%ecx
 128ae01:	ff 50 18             	call   *0x18(%rax)
 128ae04:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 128ae08:	48 85 c9             	test   %rcx,%rcx
 128ae0b:	74 25                	je     128ae32 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x13e2>
 128ae0d:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128ae11:	48 8b 38             	mov    (%rax),%rdi
 128ae14:	48 8b 40 08          	mov    0x8(%rax),%rax
 128ae18:	48 01 c9             	add    %rcx,%rcx
 128ae1b:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128ae1f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128ae23:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 128ae2a:	b9 01 00 00 00       	mov    $0x1,%ecx
 128ae2f:	ff 50 18             	call   *0x18(%rax)
 128ae32:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 128ae36:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 128ae3c:	48 89 18             	mov    %rbx,(%rax)
 128ae3f:	4c 89 70 08          	mov    %r14,0x8(%rax)
 128ae43:	48 81 c4 e8 0b 00 00 	add    $0xbe8,%rsp
 128ae4a:	5b                   	pop    %rbx
 128ae4b:	41 5c                	pop    %r12
 128ae4d:	41 5d                	pop    %r13
 128ae4f:	41 5e                	pop    %r14
 128ae51:	41 5f                	pop    %r15
 128ae53:	5d                   	pop    %rbp
 128ae54:	c3                   	ret    
 128ae55:	48 8b 5d b8          	mov    -0x48(%rbp),%rbx
 128ae59:	e9 e3 fb ff ff       	jmp    128aa41 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xff1>
 128ae5e:	48 85 db             	test   %rbx,%rbx
 128ae61:	74 24                	je     128ae87 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1437>
 128ae63:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128ae67:	48 8b 38             	mov    (%rax),%rdi
 128ae6a:	48 8b 40 08          	mov    0x8(%rax),%rax
 128ae6e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128ae72:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 128ae76:	48 89 da             	mov    %rbx,%rdx
 128ae79:	31 c9                	xor    %ecx,%ecx
 128ae7b:	ff 50 18             	call   *0x18(%rax)
 128ae7e:	48 8b 5d b8          	mov    -0x48(%rbp),%rbx
 128ae82:	e9 bf fb ff ff       	jmp    128aa46 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xff6>
 128ae87:	48 89 d3             	mov    %rdx,%rbx
 128ae8a:	e9 b7 fb ff ff       	jmp    128aa46 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0xff6>
 128ae8f:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 128ae93:	48 85 d2             	test   %rdx,%rdx
 128ae96:	74 18                	je     128aeb0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1460>
 128ae98:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128ae9c:	48 8b 38             	mov    (%rax),%rdi
 128ae9f:	48 8b 40 08          	mov    0x8(%rax),%rax
 128aea3:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128aea7:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 128aeab:	31 c9                	xor    %ecx,%ecx
 128aead:	ff 50 18             	call   *0x18(%rax)
 128aeb0:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 128aeb4:	48 85 c9             	test   %rcx,%rcx
 128aeb7:	48 8b 5d a0          	mov    -0x60(%rbp),%rbx
 128aebb:	74 22                	je     128aedf <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x148f>
 128aebd:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128aec1:	48 8b 38             	mov    (%rax),%rdi
 128aec4:	48 8b 40 08          	mov    0x8(%rax),%rax
 128aec8:	48 c1 e1 05          	shl    $0x5,%rcx
 128aecc:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128aed0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128aed4:	4c 89 ee             	mov    %r13,%rsi
 128aed7:	b9 03 00 00 00       	mov    $0x3,%ecx
 128aedc:	ff 50 18             	call   *0x18(%rax)
 128aedf:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 128aee3:	48 85 c9             	test   %rcx,%rcx
 128aee6:	74 25                	je     128af0d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x14bd>
 128aee8:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128aeec:	48 8b 38             	mov    (%rax),%rdi
 128aeef:	48 8b 40 08          	mov    0x8(%rax),%rax
 128aef3:	48 01 c9             	add    %rcx,%rcx
 128aef6:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128aefa:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128aefe:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 128af05:	b9 01 00 00 00       	mov    $0x1,%ecx
 128af0a:	ff 50 18             	call   *0x18(%rax)
 128af0d:	66 44 89 73 10       	mov    %r14w,0x10(%rbx)
 128af12:	e9 2c ff ff ff       	jmp    128ae43 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x13f3>
 128af17:	4d 85 f6             	test   %r14,%r14
 128af1a:	74 22                	je     128af3e <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x14ee>
 128af1c:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128af20:	48 8b 38             	mov    (%rax),%rdi
 128af23:	48 8b 40 08          	mov    0x8(%rax),%rax
 128af27:	49 c1 e6 05          	shl    $0x5,%r14
 128af2b:	4b 8d 14 76          	lea    (%r14,%r14,2),%rdx
 128af2f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128af33:	4c 89 ee             	mov    %r13,%rsi
 128af36:	b9 03 00 00 00       	mov    $0x3,%ecx
 128af3b:	ff 50 18             	call   *0x18(%rax)
 128af3e:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 128af42:	48 85 d2             	test   %rdx,%rdx
 128af45:	48 8b 5d a0          	mov    -0x60(%rbp),%rbx
 128af49:	74 18                	je     128af63 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1513>
 128af4b:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128af4f:	48 8b 38             	mov    (%rax),%rdi
 128af52:	48 8b 40 08          	mov    0x8(%rax),%rax
 128af56:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128af5a:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 128af5e:	31 c9                	xor    %ecx,%ecx
 128af60:	ff 50 18             	call   *0x18(%rax)
 128af63:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 128af67:	48 85 c9             	test   %rcx,%rcx
 128af6a:	48 8b b5 58 ff ff ff 	mov    -0xa8(%rbp),%rsi
 128af71:	74 1f                	je     128af92 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1542>
 128af73:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128af77:	48 8b 38             	mov    (%rax),%rdi
 128af7a:	48 8b 40 08          	mov    0x8(%rax),%rax
 128af7e:	48 c1 e1 05          	shl    $0x5,%rcx
 128af82:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128af86:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128af8a:	b9 03 00 00 00       	mov    $0x3,%ecx
 128af8f:	ff 50 18             	call   *0x18(%rax)
 128af92:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 128af96:	48 85 c9             	test   %rcx,%rcx
 128af99:	74 25                	je     128afc0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1570>
 128af9b:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128af9f:	48 8b 38             	mov    (%rax),%rdi
 128afa2:	48 8b 40 08          	mov    0x8(%rax),%rax
 128afa6:	48 01 c9             	add    %rcx,%rcx
 128afa9:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128afad:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128afb1:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 128afb8:	b9 01 00 00 00       	mov    $0x1,%ecx
 128afbd:	ff 50 18             	call   *0x18(%rax)
 128afc0:	66 44 89 7b 10       	mov    %r15w,0x10(%rbx)
 128afc5:	e9 79 fe ff ff       	jmp    128ae43 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x13f3>
 128afca:	66 89 43 10          	mov    %ax,0x10(%rbx)
 128afce:	e9 70 fe ff ff       	jmp    128ae43 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x13f3>
 128afd3:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 128afd7:	48 85 c9             	test   %rcx,%rcx
 128afda:	74 22                	je     128affe <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x15ae>
 128afdc:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128afe0:	48 8b 38             	mov    (%rax),%rdi
 128afe3:	48 8b 40 08          	mov    0x8(%rax),%rax
 128afe7:	48 c1 e1 05          	shl    $0x5,%rcx
 128afeb:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128afef:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128aff3:	4c 89 ee             	mov    %r13,%rsi
 128aff6:	b9 03 00 00 00       	mov    $0x3,%ecx
 128affb:	ff 50 18             	call   *0x18(%rax)
 128affe:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 128b002:	48 85 c9             	test   %rcx,%rcx
 128b005:	74 25                	je     128b02c <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x15dc>
 128b007:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b00b:	48 8b 38             	mov    (%rax),%rdi
 128b00e:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b012:	48 01 c9             	add    %rcx,%rcx
 128b015:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128b019:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b01d:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 128b024:	b9 01 00 00 00       	mov    $0x1,%ecx
 128b029:	ff 50 18             	call   *0x18(%rax)
 128b02c:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 128b030:	48 85 f6             	test   %rsi,%rsi
 128b033:	0f 94 c0             	sete   %al
 128b036:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 128b03a:	48 85 d2             	test   %rdx,%rdx
 128b03d:	0f 94 c1             	sete   %cl
 128b040:	08 c1                	or     %al,%cl
 128b042:	0f 85 e5 01 00 00    	jne    128b22d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x17dd>
 128b048:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b04c:	48 8b 38             	mov    (%rax),%rdi
 128b04f:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b053:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b057:	e9 cc 01 00 00       	jmp    128b228 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x17d8>
 128b05c:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 128b060:	48 85 d2             	test   %rdx,%rdx
 128b063:	75 0a                	jne    128b06f <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x161f>
 128b065:	eb 20                	jmp    128b087 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1637>
 128b067:	4d 85 f6             	test   %r14,%r14
 128b06a:	74 1b                	je     128b087 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1637>
 128b06c:	4c 89 f2             	mov    %r14,%rdx
 128b06f:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b073:	48 8b 38             	mov    (%rax),%rdi
 128b076:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b07a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b07e:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 128b082:	31 c9                	xor    %ecx,%ecx
 128b084:	ff 50 18             	call   *0x18(%rax)
 128b087:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 128b08b:	48 85 c9             	test   %rcx,%rcx
 128b08e:	74 22                	je     128b0b2 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1662>
 128b090:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b094:	48 8b 38             	mov    (%rax),%rdi
 128b097:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b09b:	48 c1 e1 05          	shl    $0x5,%rcx
 128b09f:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128b0a3:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b0a7:	4c 89 ee             	mov    %r13,%rsi
 128b0aa:	b9 03 00 00 00       	mov    $0x3,%ecx
 128b0af:	ff 50 18             	call   *0x18(%rax)
 128b0b2:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 128b0b6:	48 85 c9             	test   %rcx,%rcx
 128b0b9:	0f 84 6e 01 00 00    	je     128b22d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x17dd>
 128b0bf:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b0c3:	48 8b 38             	mov    (%rax),%rdi
 128b0c6:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b0ca:	48 01 c9             	add    %rcx,%rcx
 128b0cd:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128b0d1:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b0d5:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 128b0dc:	b9 01 00 00 00       	mov    $0x1,%ecx
 128b0e1:	e9 44 01 00 00       	jmp    128b22a <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x17da>
 128b0e6:	45 31 ff             	xor    %r15d,%r15d
 128b0e9:	41 bc 00 00 00 00    	mov    $0x0,%r12d
 128b0ef:	41 83 fe 1f          	cmp    $0x1f,%r14d
 128b0f3:	0f 84 1d fb ff ff    	je     128ac16 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x11c6>
 128b0f9:	48 85 db             	test   %rbx,%rbx
 128b0fc:	74 1b                	je     128b119 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x16c9>
 128b0fe:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b102:	48 8b 38             	mov    (%rax),%rdi
 128b105:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b109:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b10d:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 128b111:	48 89 da             	mov    %rbx,%rdx
 128b114:	31 c9                	xor    %ecx,%ecx
 128b116:	ff 50 18             	call   *0x18(%rax)
 128b119:	48 83 7d b0 00       	cmpq   $0x0,-0x50(%rbp)
 128b11e:	74 26                	je     128b146 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x16f6>
 128b120:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b124:	48 8b 38             	mov    (%rax),%rdi
 128b127:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b12b:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 128b12f:	48 c1 e1 05          	shl    $0x5,%rcx
 128b133:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128b137:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b13b:	4c 89 ee             	mov    %r13,%rsi
 128b13e:	b9 03 00 00 00       	mov    $0x3,%ecx
 128b143:	ff 50 18             	call   *0x18(%rax)
 128b146:	48 83 7d 98 00       	cmpq   $0x0,-0x68(%rbp)
 128b14b:	74 29                	je     128b176 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1726>
 128b14d:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b151:	48 8b 38             	mov    (%rax),%rdi
 128b154:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b158:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 128b15c:	48 01 c9             	add    %rcx,%rcx
 128b15f:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128b163:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b167:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 128b16e:	b9 01 00 00 00       	mov    $0x1,%ecx
 128b173:	ff 50 18             	call   *0x18(%rax)
 128b176:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 128b17a:	66 44 89 70 10       	mov    %r14w,0x10(%rax)
 128b17f:	e9 bf fc ff ff       	jmp    128ae43 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x13f3>
 128b184:	48 83 7d c8 00       	cmpq   $0x0,-0x38(%rbp)
 128b189:	0f 94 c0             	sete   %al
 128b18c:	48 83 7d b8 00       	cmpq   $0x0,-0x48(%rbp)
 128b191:	0f 94 c1             	sete   %cl
 128b194:	08 c1                	or     %al,%cl
 128b196:	80 f9 01             	cmp    $0x1,%cl
 128b199:	75 76                	jne    128b211 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x17c1>
 128b19b:	e9 8d 00 00 00       	jmp    128b22d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x17dd>
 128b1a0:	48 83 7d b0 00       	cmpq   $0x0,-0x50(%rbp)
 128b1a5:	74 26                	je     128b1cd <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x177d>
 128b1a7:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b1ab:	48 8b 38             	mov    (%rax),%rdi
 128b1ae:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b1b2:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 128b1b6:	48 c1 e1 05          	shl    $0x5,%rcx
 128b1ba:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128b1be:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b1c2:	4c 89 ee             	mov    %r13,%rsi
 128b1c5:	b9 03 00 00 00       	mov    $0x3,%ecx
 128b1ca:	ff 50 18             	call   *0x18(%rax)
 128b1cd:	48 83 7d 98 00       	cmpq   $0x0,-0x68(%rbp)
 128b1d2:	74 29                	je     128b1fd <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x17ad>
 128b1d4:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b1d8:	48 8b 38             	mov    (%rax),%rdi
 128b1db:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b1df:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 128b1e3:	48 01 c9             	add    %rcx,%rcx
 128b1e6:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128b1ea:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b1ee:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 128b1f5:	b9 01 00 00 00       	mov    $0x1,%ecx
 128b1fa:	ff 50 18             	call   *0x18(%rax)
 128b1fd:	48 83 7d c8 00       	cmpq   $0x0,-0x38(%rbp)
 128b202:	0f 94 c0             	sete   %al
 128b205:	48 83 7d b8 00       	cmpq   $0x0,-0x48(%rbp)
 128b20a:	0f 94 c1             	sete   %cl
 128b20d:	08 c1                	or     %al,%cl
 128b20f:	75 1c                	jne    128b22d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x17dd>
 128b211:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b215:	48 8b 38             	mov    (%rax),%rdi
 128b218:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b21c:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b220:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 128b224:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 128b228:	31 c9                	xor    %ecx,%ecx
 128b22a:	ff 50 18             	call   *0x18(%rax)
 128b22d:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 128b231:	66 89 58 10          	mov    %bx,0x10(%rax)
 128b235:	e9 09 fc ff ff       	jmp    128ae43 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x13f3>
 128b23a:	48 83 7d b8 00       	cmpq   $0x0,-0x48(%rbp)
 128b23f:	74 41                	je     128b282 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1832>
 128b241:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b245:	48 8b 38             	mov    (%rax),%rdi
 128b248:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b24c:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b250:	4c 89 fe             	mov    %r15,%rsi
 128b253:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 128b257:	eb 24                	jmp    128b27d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x182d>
 128b259:	89 c3                	mov    %eax,%ebx
 128b25b:	48 8b 95 68 ff ff ff 	mov    -0x98(%rbp),%rdx
 128b262:	48 85 d2             	test   %rdx,%rdx
 128b265:	74 1b                	je     128b282 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x1832>
 128b267:	48 8b b5 60 ff ff ff 	mov    -0xa0(%rbp),%rsi
 128b26e:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b272:	48 8b 38             	mov    (%rax),%rdi
 128b275:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b279:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b27d:	31 c9                	xor    %ecx,%ecx
 128b27f:	ff 50 18             	call   *0x18(%rax)
 128b282:	48 83 7d b0 00       	cmpq   $0x0,-0x50(%rbp)
 128b287:	74 26                	je     128b2af <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x185f>
 128b289:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b28d:	48 8b 38             	mov    (%rax),%rdi
 128b290:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b294:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 128b298:	48 c1 e1 05          	shl    $0x5,%rcx
 128b29c:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128b2a0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b2a4:	4c 89 ee             	mov    %r13,%rsi
 128b2a7:	b9 03 00 00 00       	mov    $0x3,%ecx
 128b2ac:	ff 50 18             	call   *0x18(%rax)
 128b2af:	48 83 7d 98 00       	cmpq   $0x0,-0x68(%rbp)
 128b2b4:	0f 84 73 ff ff ff    	je     128b22d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x17dd>
 128b2ba:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b2be:	48 8b 38             	mov    (%rax),%rdi
 128b2c1:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b2c5:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 128b2c9:	e9 fc fd ff ff       	jmp    128b0ca <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253629+0x167a>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
