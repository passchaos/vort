
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/d54ab236499589e8c9225c90450b9b10/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

00000000012898f0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589>:
 12898f0:	55                   	push   %rbp
 12898f1:	48 89 e5             	mov    %rsp,%rbp
 12898f4:	41 57                	push   %r15
 12898f6:	41 56                	push   %r14
 12898f8:	41 55                	push   %r13
 12898fa:	41 54                	push   %r12
 12898fc:	53                   	push   %rbx
 12898fd:	48 81 ec e8 0b 00 00 	sub    $0xbe8,%rsp
 1289904:	4d 89 c7             	mov    %r8,%r15
 1289907:	49 89 ce             	mov    %rcx,%r14
 128990a:	48 89 95 78 ff ff ff 	mov    %rdx,-0x88(%rbp)
 1289911:	48 89 75 d0          	mov    %rsi,-0x30(%rbp)
 1289915:	48 89 fb             	mov    %rdi,%rbx
 1289918:	49 8b 40 58          	mov    0x58(%r8),%rax
 128991c:	48 89 85 28 ff ff ff 	mov    %rax,-0xd8(%rbp)
 1289923:	49 8b 40 60          	mov    0x60(%r8),%rax
 1289927:	48 89 85 30 ff ff ff 	mov    %rax,-0xd0(%rbp)
 128992e:	41 0f b7 80 80 00 00 	movzwl 0x80(%r8),%eax
 1289935:	00 
 1289936:	89 85 c0 fe ff ff    	mov    %eax,-0x140(%rbp)
 128993c:	41 0f b6 80 85 00 00 	movzbl 0x85(%r8),%eax
 1289943:	00 
 1289944:	88 85 20 ff ff ff    	mov    %al,-0xe0(%rbp)
 128994a:	88 45 c6             	mov    %al,-0x3a(%rbp)
 128994d:	4d 8b a0 86 00 00 00 	mov    0x86(%r8),%r12
 1289954:	45 0f b6 a8 8e 00 00 	movzbl 0x8e(%r8),%r13d
 128995b:	00 
 128995c:	48 8d bd c8 fe ff ff 	lea    -0x138(%rbp),%rdi
 1289963:	4c 89 c6             	mov    %r8,%rsi
 1289966:	e8 55 32 fa ff       	call   122cbc0 <br.resolvedQualitySchedule>
 128996b:	0f b7 85 fc fe ff ff 	movzwl -0x104(%rbp),%eax
 1289972:	66 85 c0             	test   %ax,%ax
 1289975:	0f 85 ef 14 00 00    	jne    128ae6a <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x157a>
 128997b:	44 88 6d 90          	mov    %r13b,-0x70(%rbp)
 128997f:	4c 89 b5 50 ff ff ff 	mov    %r14,-0xb0(%rbp)
 1289986:	48 89 5d a0          	mov    %rbx,-0x60(%rbp)
 128998a:	4c 89 e3             	mov    %r12,%rbx
 128998d:	48 c1 eb 08          	shr    $0x8,%rbx
 1289991:	4c 89 a5 68 fe ff ff 	mov    %r12,-0x198(%rbp)
 1289998:	41 c1 ec 10          	shr    $0x10,%r12d
 128999c:	8b 85 cc fe ff ff    	mov    -0x134(%rbp),%eax
 12899a2:	48 89 85 70 fe ff ff 	mov    %rax,-0x190(%rbp)
 12899a9:	8b 85 d0 fe ff ff    	mov    -0x130(%rbp),%eax
 12899af:	c5 fb 10 85 c8 fe ff 	vmovsd -0x138(%rbp),%xmm0
 12899b6:	ff 
 12899b7:	c5 f8 29 85 60 fc ff 	vmovaps %xmm0,-0x3a0(%rbp)
 12899be:	ff 
 12899bf:	89 85 08 ff ff ff    	mov    %eax,-0xf8(%rbp)
 12899c5:	0f b7 85 d4 fe ff ff 	movzwl -0x12c(%rbp),%eax
 12899cc:	66 89 85 0c ff ff ff 	mov    %ax,-0xf4(%rbp)
 12899d3:	0f b6 b5 d6 fe ff ff 	movzbl -0x12a(%rbp),%esi
 12899da:	0f b6 85 d7 fe ff ff 	movzbl -0x129(%rbp),%eax
 12899e1:	88 45 92             	mov    %al,-0x6e(%rbp)
 12899e4:	0f b7 85 dc fe ff ff 	movzwl -0x124(%rbp),%eax
 12899eb:	48 89 85 58 ff ff ff 	mov    %rax,-0xa8(%rbp)
 12899f2:	0f b7 85 de fe ff ff 	movzwl -0x122(%rbp),%eax
 12899f9:	48 89 45 b0          	mov    %rax,-0x50(%rbp)
 12899fd:	0f b6 85 e4 fe ff ff 	movzbl -0x11c(%rbp),%eax
 1289a04:	0f b6 8d e5 fe ff ff 	movzbl -0x11b(%rbp),%ecx
 1289a0b:	44 0f b6 ad e6 fe ff 	movzbl -0x11a(%rbp),%r13d
 1289a12:	ff 
 1289a13:	0f b6 95 e7 fe ff ff 	movzbl -0x119(%rbp),%edx
 1289a1a:	88 55 c7             	mov    %dl,-0x39(%rbp)
 1289a1d:	0f b6 95 e8 fe ff ff 	movzbl -0x118(%rbp),%edx
 1289a24:	88 95 10 ff ff ff    	mov    %dl,-0xf0(%rbp)
 1289a2a:	0f b6 95 ee fe ff ff 	movzbl -0x112(%rbp),%edx
 1289a31:	88 55 88             	mov    %dl,-0x78(%rbp)
 1289a34:	0f b6 95 ef fe ff ff 	movzbl -0x111(%rbp),%edx
 1289a3b:	88 55 8d             	mov    %dl,-0x73(%rbp)
 1289a3e:	0f b6 95 f0 fe ff ff 	movzbl -0x110(%rbp),%edx
 1289a45:	88 55 8e             	mov    %dl,-0x72(%rbp)
 1289a48:	0f b6 95 f1 fe ff ff 	movzbl -0x10f(%rbp),%edx
 1289a4f:	88 55 8b             	mov    %dl,-0x75(%rbp)
 1289a52:	0f b6 95 f2 fe ff ff 	movzbl -0x10e(%rbp),%edx
 1289a59:	88 55 8a             	mov    %dl,-0x76(%rbp)
 1289a5c:	0f b6 95 f3 fe ff ff 	movzbl -0x10d(%rbp),%edx
 1289a63:	88 55 89             	mov    %dl,-0x77(%rbp)
 1289a66:	44 0f b6 b5 f4 fe ff 	movzbl -0x10c(%rbp),%r14d
 1289a6d:	ff 
 1289a6e:	0f b6 95 f5 fe ff ff 	movzbl -0x10b(%rbp),%edx
 1289a75:	88 55 8f             	mov    %dl,-0x71(%rbp)
 1289a78:	0f b6 95 f6 fe ff ff 	movzbl -0x10a(%rbp),%edx
 1289a7f:	88 55 8c             	mov    %dl,-0x74(%rbp)
 1289a82:	88 45 94             	mov    %al,-0x6c(%rbp)
 1289a85:	0f b6 85 f7 fe ff ff 	movzbl -0x109(%rbp),%eax
 1289a8c:	88 4d 86             	mov    %cl,-0x7a(%rbp)
 1289a8f:	0f b6 8d f8 fe ff ff 	movzbl -0x108(%rbp),%ecx
 1289a96:	88 4d 91             	mov    %cl,-0x6f(%rbp)
 1289a99:	40 88 75 c5          	mov    %sil,-0x3b(%rbp)
 1289a9d:	40 88 75 ae          	mov    %sil,-0x52(%rbp)
 1289aa1:	88 45 ac             	mov    %al,-0x54(%rbp)
 1289aa4:	88 45 87             	mov    %al,-0x79(%rbp)
 1289aa7:	41 80 bf 84 00 00 00 	cmpb   $0x0,0x84(%r15)
 1289aae:	00 
 1289aaf:	0f b6 85 e0 fe ff ff 	movzbl -0x120(%rbp),%eax
 1289ab6:	48 89 85 38 ff ff ff 	mov    %rax,-0xc8(%rbp)
 1289abd:	0f b7 85 e2 fe ff ff 	movzwl -0x11e(%rbp),%eax
 1289ac4:	89 85 c4 fe ff ff    	mov    %eax,-0x13c(%rbp)
 1289aca:	74 4f                	je     1289b1b <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x22b>
 1289acc:	48 8d bd 78 fe ff ff 	lea    -0x188(%rbp),%rdi
 1289ad3:	4c 89 fe             	mov    %r15,%rsi
 1289ad6:	e8 e5 30 fa ff       	call   122cbc0 <br.resolvedQualitySchedule>
 1289adb:	0f b7 85 ac fe ff ff 	movzwl -0x154(%rbp),%eax
 1289ae2:	66 85 c0             	test   %ax,%ax
 1289ae5:	0f 85 1e 03 00 00    	jne    1289e09 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x519>
 1289aeb:	0f b6 85 9b fe ff ff 	movzbl -0x165(%rbp),%eax
 1289af2:	f6 85 20 ff ff ff 01 	testb  $0x1,-0xe0(%rbp)
 1289af9:	74 5d                	je     1289b58 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x268>
 1289afb:	45 84 e4             	test   %r12b,%r12b
 1289afe:	0f b6 c0             	movzbl %al,%eax
 1289b01:	0f b6 f3             	movzbl %bl,%esi
 1289b04:	0f 44 f0             	cmove  %eax,%esi
 1289b07:	8d 4e 01             	lea    0x1(%rsi),%ecx
 1289b0a:	80 e1 1f             	and    $0x1f,%cl
 1289b0d:	66 b8 1f 00          	mov    $0x1f,%ax
 1289b11:	80 f9 0b             	cmp    $0xb,%cl
 1289b14:	73 7a                	jae    1289b90 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x2a0>
 1289b16:	e9 ee 02 00 00       	jmp    1289e09 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x519>
 1289b1b:	45 84 e4             	test   %r12b,%r12b
 1289b1e:	be 10 00 00 00       	mov    $0x10,%esi
 1289b23:	0f 45 f3             	cmovne %ebx,%esi
 1289b26:	89 f1                	mov    %esi,%ecx
 1289b28:	80 e1 1f             	and    $0x1f,%cl
 1289b2b:	f6 85 20 ff ff ff 01 	testb  $0x1,-0xe0(%rbp)
 1289b32:	b8 fe 00 00 00       	mov    $0xfe,%eax
 1289b37:	ba f8 00 00 00       	mov    $0xf8,%edx
 1289b3c:	0f 45 d0             	cmovne %eax,%edx
 1289b3f:	66 b8 1f 00          	mov    $0x1f,%ax
 1289b43:	80 f9 0a             	cmp    $0xa,%cl
 1289b46:	0f 82 bd 02 00 00    	jb     1289e09 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x519>
 1289b4c:	80 e2 1f             	and    $0x1f,%dl
 1289b4f:	38 d1                	cmp    %dl,%cl
 1289b51:	76 3d                	jbe    1289b90 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x2a0>
 1289b53:	e9 b1 02 00 00       	jmp    1289e09 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x519>
 1289b58:	0f b7 8d 9c fe ff ff 	movzwl -0x164(%rbp),%ecx
 1289b5f:	45 84 e4             	test   %r12b,%r12b
 1289b62:	0f b6 c0             	movzbl %al,%eax
 1289b65:	0f b6 f3             	movzbl %bl,%esi
 1289b68:	0f 44 f0             	cmove  %eax,%esi
 1289b6b:	40 80 e6 1f          	and    $0x1f,%sil
 1289b6f:	89 ca                	mov    %ecx,%edx
 1289b71:	80 e2 1f             	and    $0x1f,%dl
 1289b74:	66 b8 1f 00          	mov    $0x1f,%ax
 1289b78:	40 38 d6             	cmp    %dl,%sil
 1289b7b:	0f 82 88 02 00 00    	jb     1289e09 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x519>
 1289b81:	c1 e9 08             	shr    $0x8,%ecx
 1289b84:	80 e1 1f             	and    $0x1f,%cl
 1289b87:	40 38 ce             	cmp    %cl,%sil
 1289b8a:	0f 87 79 02 00 00    	ja     1289e09 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x519>
 1289b90:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1289b94:	c5 f8 29 85 e0 fd ff 	vmovaps %xmm0,-0x220(%rbp)
 1289b9b:	ff 
 1289b9c:	48 c7 85 f0 fd ff ff 	movq   $0x0,-0x210(%rbp)
 1289ba3:	00 00 00 00 
 1289ba7:	0f b6 8d 20 ff ff ff 	movzbl -0xe0(%rbp),%ecx
 1289bae:	80 e1 01             	and    $0x1,%cl
 1289bb1:	88 8d 08 fe ff ff    	mov    %cl,-0x1f8(%rbp)
 1289bb7:	48 89 b5 00 ff ff ff 	mov    %rsi,-0x100(%rbp)
 1289bbe:	40 80 e6 1f          	and    $0x1f,%sil
 1289bc2:	48 89 b5 18 ff ff ff 	mov    %rsi,-0xe8(%rbp)
 1289bc9:	40 88 b5 09 fe ff ff 	mov    %sil,-0x1f7(%rbp)
 1289bd0:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 1289bd7:	48 89 85 f8 fd ff ff 	mov    %rax,-0x208(%rbp)
 1289bde:	48 8b 85 30 ff ff ff 	mov    -0xd0(%rbp),%rax
 1289be5:	48 89 85 00 fe ff ff 	mov    %rax,-0x200(%rbp)
 1289bec:	4c 8b a5 50 ff ff ff 	mov    -0xb0(%rbp),%r12
 1289bf3:	49 83 fc 04          	cmp    $0x4,%r12
 1289bf7:	77 4c                	ja     1289c45 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x355>
 1289bf9:	48 8d bd 78 fe ff ff 	lea    -0x188(%rbp),%rdi
 1289c00:	4c 8d 85 e0 fd ff ff 	lea    -0x220(%rbp),%r8
 1289c07:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1289c0b:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 1289c12:	4c 89 e1             	mov    %r12,%rcx
 1289c15:	e8 66 f4 f5 ff       	call   11e9080 <br.encodeStoredStreamWithOptionsAlloc>
 1289c1a:	0f b7 85 88 fe ff ff 	movzwl -0x178(%rbp),%eax
 1289c21:	66 85 c0             	test   %ax,%ax
 1289c24:	48 8b 4d a0          	mov    -0x60(%rbp),%rcx
 1289c28:	0f 85 df 01 00 00    	jne    1289e0d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x51d>
 1289c2e:	c5 f8 10 85 78 fe ff 	vmovups -0x188(%rbp),%xmm0
 1289c35:	ff 
 1289c36:	c5 f8 11 01          	vmovups %xmm0,(%rcx)
 1289c3a:	66 c7 41 10 00 00    	movw   $0x0,0x10(%rcx)
 1289c40:	e9 9e 10 00 00       	jmp    128ace3 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x13f3>
 1289c45:	88 4d 93             	mov    %cl,-0x6d(%rbp)
 1289c48:	41 80 e5 0f          	and    $0xf,%r13b
 1289c4c:	48 c7 45 c8 00 00 00 	movq   $0x0,-0x38(%rbp)
 1289c53:	00 
 1289c54:	b8 00 00 00 00       	mov    $0x0,%eax
 1289c59:	44 88 6d ad          	mov    %r13b,-0x53(%rbp)
 1289c5d:	41 80 fd 0b          	cmp    $0xb,%r13b
 1289c61:	0f 85 af 00 00 00    	jne    1289d16 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x426>
 1289c67:	49 8d 87 85 00 00 00 	lea    0x85(%r15),%rax
 1289c6e:	41 8b 4f 7f          	mov    0x7f(%r15),%ecx
 1289c72:	89 8d 9f fb ff ff    	mov    %ecx,-0x461(%rbp)
 1289c78:	c4 c1 7c 10 07       	vmovups (%r15),%ymm0
 1289c7d:	c4 c1 7c 10 4f 20    	vmovups 0x20(%r15),%ymm1
 1289c83:	c4 c1 7c 10 57 40    	vmovups 0x40(%r15),%ymm2
 1289c89:	c4 c1 7c 10 5f 60    	vmovups 0x60(%r15),%ymm3
 1289c8f:	c5 fc 11 9d 80 fb ff 	vmovups %ymm3,-0x480(%rbp)
 1289c96:	ff 
 1289c97:	c5 fc 11 95 60 fb ff 	vmovups %ymm2,-0x4a0(%rbp)
 1289c9e:	ff 
 1289c9f:	c5 fc 11 8d 40 fb ff 	vmovups %ymm1,-0x4c0(%rbp)
 1289ca6:	ff 
 1289ca7:	c5 fc 11 85 20 fb ff 	vmovups %ymm0,-0x4e0(%rbp)
 1289cae:	ff 
 1289caf:	0f b7 0d 0a db e2 ff 	movzwl -0x1d24f6(%rip),%ecx        # 10b77c0 <__anon_250458>
 1289cb6:	66 89 8d a3 fb ff ff 	mov    %cx,-0x45d(%rbp)
 1289cbd:	48 8b 08             	mov    (%rax),%rcx
 1289cc0:	48 89 8d a5 fb ff ff 	mov    %rcx,-0x45b(%rbp)
 1289cc7:	8b 40 07             	mov    0x7(%rax),%eax
 1289cca:	89 85 ac fb ff ff    	mov    %eax,-0x454(%rbp)
 1289cd0:	48 8d bd c8 fd ff ff 	lea    -0x238(%rbp),%rdi
 1289cd7:	4c 8d 85 20 fb ff ff 	lea    -0x4e0(%rbp),%r8
 1289cde:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1289ce2:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 1289ce9:	4c 89 e1             	mov    %r12,%rcx
 1289cec:	c5 f8 77             	vzeroupper 
 1289cef:	e8 fc fb ff ff       	call   12898f0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589>
 1289cf4:	0f b7 85 d8 fd ff ff 	movzwl -0x228(%rbp),%eax
 1289cfb:	66 85 c0             	test   %ax,%ax
 1289cfe:	0f 85 05 01 00 00    	jne    1289e09 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x519>
 1289d04:	48 8b 85 c8 fd ff ff 	mov    -0x238(%rbp),%rax
 1289d0b:	48 89 45 c8          	mov    %rax,-0x38(%rbp)
 1289d0f:	48 8b 85 d0 fd ff ff 	mov    -0x230(%rbp),%rax
 1289d16:	48 89 45 b8          	mov    %rax,-0x48(%rbp)
 1289d1a:	b8 01 00 00 00       	mov    $0x1,%eax
 1289d1f:	48 8b 8d 18 ff ff ff 	mov    -0xe8(%rbp),%rcx
 1289d26:	c4 e2 f1 f7 c0       	shlx   %rcx,%rax,%rax
 1289d2b:	48 83 c0 f0          	add    $0xfffffffffffffff0,%rax
 1289d2f:	4c 39 e0             	cmp    %r12,%rax
 1289d32:	4c 89 e1             	mov    %r12,%rcx
 1289d35:	48 89 85 60 fe ff ff 	mov    %rax,-0x1a0(%rbp)
 1289d3c:	48 0f 42 c8          	cmovb  %rax,%rcx
 1289d40:	48 81 f9 ff ff 00 00 	cmp    $0xffff,%rcx
 1289d47:	b8 ff ff 00 00       	mov    $0xffff,%eax
 1289d4c:	48 0f 42 c1          	cmovb  %rcx,%rax
 1289d50:	f6 85 10 ff ff ff 03 	testb  $0x3,-0xf0(%rbp)
 1289d57:	0f 84 b9 00 00 00    	je     1289e16 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x526>
 1289d5d:	48 89 85 78 fc ff ff 	mov    %rax,-0x388(%rbp)
 1289d64:	48 8b 85 58 ff ff ff 	mov    -0xa8(%rbp),%rax
 1289d6b:	48 89 85 80 fc ff ff 	mov    %rax,-0x380(%rbp)
 1289d72:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 1289d76:	48 89 85 88 fc ff ff 	mov    %rax,-0x378(%rbp)
 1289d7d:	48 c7 85 90 fc ff ff 	movq   $0x1,-0x370(%rbp)
 1289d84:	01 00 00 00 
 1289d88:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 1289d8f:	48 89 85 98 fc ff ff 	mov    %rax,-0x368(%rbp)
 1289d96:	48 c7 85 a0 fc ff ff 	movq   $0x3,-0x360(%rbp)
 1289d9d:	03 00 00 00 
 1289da1:	48 c7 85 a8 fc ff ff 	movq   $0x102,-0x358(%rbp)
 1289da8:	02 01 00 00 
 1289dac:	48 c7 85 b0 fc ff ff 	movq   $0x0,-0x350(%rbp)
 1289db3:	00 00 00 00 
 1289db7:	c6 85 b8 fc ff ff 00 	movb   $0x0,-0x348(%rbp)
 1289dbe:	48 8d bd 10 fc ff ff 	lea    -0x3f0(%rbp),%rdi
 1289dc5:	4c 8d 85 78 fc ff ff 	lea    -0x388(%rbp),%r8
 1289dcc:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1289dd0:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 1289dd7:	4c 89 e1             	mov    %r12,%rcx
 1289dda:	e8 81 b7 f8 ff       	call   1215560 <lz77.lazyGreedyPlanAlloc>
 1289ddf:	0f b7 9d 38 fc ff ff 	movzwl -0x3c8(%rbp),%ebx
 1289de6:	66 85 db             	test   %bx,%bx
 1289de9:	0f 85 dd 10 00 00    	jne    128aecc <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x15dc>
 1289def:	4c 8b 85 10 fc ff ff 	mov    -0x3f0(%rbp),%r8
 1289df6:	4c 8b 8d 18 fc ff ff 	mov    -0x3e8(%rbp),%r9
 1289dfd:	48 8b 85 28 fc ff ff 	mov    -0x3d8(%rbp),%rax
 1289e04:	e9 b4 00 00 00       	jmp    1289ebd <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x5cd>
 1289e09:	48 8b 4d a0          	mov    -0x60(%rbp),%rcx
 1289e0d:	66 89 41 10          	mov    %ax,0x10(%rcx)
 1289e11:	e9 cd 0e 00 00       	jmp    128ace3 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x13f3>
 1289e16:	48 89 85 c0 fc ff ff 	mov    %rax,-0x340(%rbp)
 1289e1d:	48 8b 85 58 ff ff ff 	mov    -0xa8(%rbp),%rax
 1289e24:	48 89 85 c8 fc ff ff 	mov    %rax,-0x338(%rbp)
 1289e2b:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 1289e2f:	48 89 85 d0 fc ff ff 	mov    %rax,-0x330(%rbp)
 1289e36:	48 c7 85 d8 fc ff ff 	movq   $0x1,-0x328(%rbp)
 1289e3d:	01 00 00 00 
 1289e41:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 1289e48:	48 89 85 e0 fc ff ff 	mov    %rax,-0x320(%rbp)
 1289e4f:	48 c7 85 e8 fc ff ff 	movq   $0x3,-0x318(%rbp)
 1289e56:	03 00 00 00 
 1289e5a:	48 c7 85 f0 fc ff ff 	movq   $0x102,-0x310(%rbp)
 1289e61:	02 01 00 00 
 1289e65:	48 c7 85 f8 fc ff ff 	movq   $0x0,-0x308(%rbp)
 1289e6c:	00 00 00 00 
 1289e70:	c6 85 00 fd ff ff 00 	movb   $0x0,-0x300(%rbp)
 1289e77:	48 8d bd 78 fe ff ff 	lea    -0x188(%rbp),%rdi
 1289e7e:	4c 8d 85 c0 fc ff ff 	lea    -0x340(%rbp),%r8
 1289e85:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1289e89:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 1289e90:	4c 89 e1             	mov    %r12,%rcx
 1289e93:	e8 28 a6 f8 ff       	call   12144c0 <lz77.hashGreedyPlanAllocWithAnchor__anon_72932>
 1289e98:	0f b7 9d a0 fe ff ff 	movzwl -0x160(%rbp),%ebx
 1289e9f:	66 85 db             	test   %bx,%bx
 1289ea2:	0f 85 7c 11 00 00    	jne    128b024 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1734>
 1289ea8:	4c 8b 85 78 fe ff ff 	mov    -0x188(%rbp),%r8
 1289eaf:	4c 8b 8d 80 fe ff ff 	mov    -0x180(%rbp),%r9
 1289eb6:	48 8b 85 90 fe ff ff 	mov    -0x170(%rbp),%rax
 1289ebd:	48 89 85 38 ff ff ff 	mov    %rax,-0xc8(%rbp)
 1289ec4:	48 8d bd 40 fc ff ff 	lea    -0x3c0(%rbp),%rdi
 1289ecb:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1289ecf:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 1289ed6:	4c 89 e1             	mov    %r12,%rcx
 1289ed9:	4c 89 85 70 ff ff ff 	mov    %r8,-0x90(%rbp)
 1289ee0:	4c 89 4d 98          	mov    %r9,-0x68(%rbp)
 1289ee4:	e8 e7 c9 f8 ff       	call   12168d0 <br.encoder.command_plan.buildAlloc>
 1289ee9:	0f b7 9d 58 fc ff ff 	movzwl -0x3a8(%rbp),%ebx
 1289ef0:	66 85 db             	test   %bx,%bx
 1289ef3:	0f 85 a5 0f 00 00    	jne    128ae9e <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x15ae>
 1289ef9:	48 8b 85 40 fc ff ff 	mov    -0x3c0(%rbp),%rax
 1289f00:	48 89 85 58 ff ff ff 	mov    %rax,-0xa8(%rbp)
 1289f07:	4c 8b 8d 48 fc ff ff 	mov    -0x3b8(%rbp),%r9
 1289f0e:	c4 c1 78 10 47 58    	vmovups 0x58(%r15),%xmm0
 1289f14:	41 0f b6 87 85 00 00 	movzbl 0x85(%r15),%eax
 1289f1b:	00 
 1289f1c:	0f b6 4d ac          	movzbl -0x54(%rbp),%ecx
 1289f20:	80 e1 01             	and    $0x1,%cl
 1289f23:	0f b6 75 88          	movzbl -0x78(%rbp),%esi
 1289f27:	40 80 e6 01          	and    $0x1,%sil
 1289f2b:	44 0f b6 5d 8d       	movzbl -0x73(%rbp),%r11d
 1289f30:	41 80 e3 01          	and    $0x1,%r11b
 1289f34:	0f b6 5d 8e          	movzbl -0x72(%rbp),%ebx
 1289f38:	80 e3 01             	and    $0x1,%bl
 1289f3b:	44 0f b6 55 8b       	movzbl -0x75(%rbp),%r10d
 1289f40:	41 80 e2 01          	and    $0x1,%r10b
 1289f44:	45 0a b7 8a 00 00 00 	or     0x8a(%r15),%r14b
 1289f4b:	41 80 e6 01          	and    $0x1,%r14b
 1289f4f:	44 0f b6 45 8a       	movzbl -0x76(%rbp),%r8d
 1289f54:	41 80 e0 01          	and    $0x1,%r8b
 1289f58:	45 89 f5             	mov    %r14d,%r13d
 1289f5b:	44 0f b6 75 8f       	movzbl -0x71(%rbp),%r14d
 1289f60:	45 0a b7 89 00 00 00 	or     0x89(%r15),%r14b
 1289f67:	41 80 e6 01          	and    $0x1,%r14b
 1289f6b:	0f b6 7d 89          	movzbl -0x77(%rbp),%edi
 1289f6f:	40 80 e7 01          	and    $0x1,%dil
 1289f73:	41 80 bf 8c 00 00 00 	cmpb   $0x0,0x8c(%r15)
 1289f7a:	00 
 1289f7b:	41 0f b6 97 8b 00 00 	movzbl 0x8b(%r15),%edx
 1289f82:	00 
 1289f83:	88 8d 51 fe ff ff    	mov    %cl,-0x1af(%rbp)
 1289f89:	40 88 b5 52 fe ff ff 	mov    %sil,-0x1ae(%rbp)
 1289f90:	c6 85 53 fe ff ff 01 	movb   $0x1,-0x1ad(%rbp)
 1289f97:	44 88 9d 54 fe ff ff 	mov    %r11b,-0x1ac(%rbp)
 1289f9e:	88 9d 55 fe ff ff    	mov    %bl,-0x1ab(%rbp)
 1289fa4:	66 c7 85 56 fe ff ff 	movw   $0x0,-0x1aa(%rbp)
 1289fab:	00 00 
 1289fad:	44 88 95 58 fe ff ff 	mov    %r10b,-0x1a8(%rbp)
 1289fb4:	44 88 ad 59 fe ff ff 	mov    %r13b,-0x1a7(%rbp)
 1289fbb:	44 88 85 5a fe ff ff 	mov    %r8b,-0x1a6(%rbp)
 1289fc2:	44 88 b5 5b fe ff ff 	mov    %r14b,-0x1a5(%rbp)
 1289fc9:	40 88 bd 5c fe ff ff 	mov    %dil,-0x1a4(%rbp)
 1289fd0:	0f b6 4d 8c          	movzbl -0x74(%rbp),%ecx
 1289fd4:	0f 45 ca             	cmovne %edx,%ecx
 1289fd7:	80 e1 01             	and    $0x1,%cl
 1289fda:	88 8d 5d fe ff ff    	mov    %cl,-0x1a3(%rbp)
 1289fe0:	24 01                	and    $0x1,%al
 1289fe2:	88 85 50 fe ff ff    	mov    %al,-0x1b0(%rbp)
 1289fe8:	48 8b 85 18 ff ff ff 	mov    -0xe8(%rbp),%rax
 1289fef:	88 85 5e fe ff ff    	mov    %al,-0x1a2(%rbp)
 1289ff5:	c5 f8 11 85 10 fe ff 	vmovups %xmm0,-0x1f0(%rbp)
 1289ffc:	ff 
 1289ffd:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 128a001:	c5 f8 11 85 20 fe ff 	vmovups %xmm0,-0x1e0(%rbp)
 128a008:	ff 
 128a009:	c5 fc 10 05 cf 80 d7 	vmovups -0x287f31(%rip),%ymm0        # 10020e0 <__anon_35167>
 128a010:	ff 
 128a011:	c5 fc 11 85 30 fe ff 	vmovups %ymm0,-0x1d0(%rbp)
 128a018:	ff 
 128a019:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 128a01d:	c5 fc 11 85 b0 f6 ff 	vmovups %ymm0,-0x950(%rbp)
 128a024:	ff 
 128a025:	c5 fc 11 85 a0 f6 ff 	vmovups %ymm0,-0x960(%rbp)
 128a02c:	ff 
 128a02d:	c5 fc 11 85 80 f6 ff 	vmovups %ymm0,-0x980(%rbp)
 128a034:	ff 
 128a035:	40 88 b5 78 fe ff ff 	mov    %sil,-0x188(%rbp)
 128a03c:	c5 fc 11 85 60 f6 ff 	vmovups %ymm0,-0x9a0(%rbp)
 128a043:	ff 
 128a044:	c5 fc 11 85 40 f6 ff 	vmovups %ymm0,-0x9c0(%rbp)
 128a04b:	ff 
 128a04c:	48 83 bd 38 ff ff ff 	cmpq   $0x0,-0xc8(%rbp)
 128a053:	00 
 128a054:	4c 89 4d b0          	mov    %r9,-0x50(%rbp)
 128a058:	74 5f                	je     128a0b9 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x7c9>
 128a05a:	48 8d 85 10 fe ff ff 	lea    -0x1f0(%rbp),%rax
 128a061:	4c 8d 95 40 f6 ff ff 	lea    -0x9c0(%rbp),%r10
 128a068:	48 8d bd b0 fd ff ff 	lea    -0x250(%rbp),%rdi
 128a06f:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 128a073:	4c 8b bd 78 ff ff ff 	mov    -0x88(%rbp),%r15
 128a07a:	4c 89 fa             	mov    %r15,%rdx
 128a07d:	4c 89 e1             	mov    %r12,%rcx
 128a080:	4c 8b ad 58 ff ff ff 	mov    -0xa8(%rbp),%r13
 128a087:	4d 89 e8             	mov    %r13,%r8
 128a08a:	50                   	push   %rax
 128a08b:	41 52                	push   %r10
 128a08d:	c5 f8 77             	vzeroupper 
 128a090:	e8 3b 03 f6 ff       	call   11ea3d0 <br.encodeLazyCommandPlanAllocRecorded__anon_43465>
 128a095:	48 83 c4 10          	add    $0x10,%rsp
 128a099:	0f b7 9d c0 fd ff ff 	movzwl -0x240(%rbp),%ebx
 128a0a0:	66 85 db             	test   %bx,%bx
 128a0a3:	0f 85 ca 0d 00 00    	jne    128ae73 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1583>
 128a0a9:	4c 8b b5 b0 fd ff ff 	mov    -0x250(%rbp),%r14
 128a0b0:	48 8b 9d b8 fd ff ff 	mov    -0x248(%rbp),%rbx
 128a0b7:	eb 4c                	jmp    128a105 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x815>
 128a0b9:	4c 8b ad 58 ff ff ff 	mov    -0xa8(%rbp),%r13
 128a0c0:	48 8d bd 78 fe ff ff 	lea    -0x188(%rbp),%rdi
 128a0c7:	4c 8d 85 e0 fd ff ff 	lea    -0x220(%rbp),%r8
 128a0ce:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 128a0d2:	4c 8b bd 78 ff ff ff 	mov    -0x88(%rbp),%r15
 128a0d9:	4c 89 fa             	mov    %r15,%rdx
 128a0dc:	4c 89 e1             	mov    %r12,%rcx
 128a0df:	c5 f8 77             	vzeroupper 
 128a0e2:	e8 99 ef f5 ff       	call   11e9080 <br.encodeStoredStreamWithOptionsAlloc>
 128a0e7:	0f b7 9d 88 fe ff ff 	movzwl -0x178(%rbp),%ebx
 128a0ee:	66 85 db             	test   %bx,%bx
 128a0f1:	0f 85 49 0f 00 00    	jne    128b040 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1750>
 128a0f7:	4c 8b b5 78 fe ff ff 	mov    -0x188(%rbp),%r14
 128a0fe:	48 8b 9d 80 fe ff ff 	mov    -0x180(%rbp),%rbx
 128a105:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 128a109:	4c 89 b5 60 ff ff ff 	mov    %r14,-0xa0(%rbp)
 128a110:	48 89 9d 68 ff ff ff 	mov    %rbx,-0x98(%rbp)
 128a117:	48 83 7d c8 00       	cmpq   $0x0,-0x38(%rbp)
 128a11c:	74 56                	je     128a174 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x884>
 128a11e:	48 39 d9             	cmp    %rbx,%rcx
 128a121:	73 31                	jae    128a154 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x864>
 128a123:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128a127:	48 8b 38             	mov    (%rax),%rdi
 128a12a:	48 8b 40 08          	mov    0x8(%rax),%rax
 128a12e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128a132:	4c 89 f6             	mov    %r14,%rsi
 128a135:	48 89 da             	mov    %rbx,%rdx
 128a138:	48 89 cb             	mov    %rcx,%rbx
 128a13b:	31 c9                	xor    %ecx,%ecx
 128a13d:	ff 50 18             	call   *0x18(%rax)
 128a140:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 128a144:	48 89 85 60 ff ff ff 	mov    %rax,-0xa0(%rbp)
 128a14b:	48 89 9d 68 ff ff ff 	mov    %rbx,-0x98(%rbp)
 128a152:	eb 28                	jmp    128a17c <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x88c>
 128a154:	48 85 c9             	test   %rcx,%rcx
 128a157:	74 1b                	je     128a174 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x884>
 128a159:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128a15d:	48 8b 38             	mov    (%rax),%rdi
 128a160:	48 8b 40 08          	mov    0x8(%rax),%rax
 128a164:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128a168:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 128a16c:	48 89 ca             	mov    %rcx,%rdx
 128a16f:	31 c9                	xor    %ecx,%ecx
 128a171:	ff 50 18             	call   *0x18(%rax)
 128a174:	4c 89 75 c8          	mov    %r14,-0x38(%rbp)
 128a178:	48 89 5d b8          	mov    %rbx,-0x48(%rbp)
 128a17c:	0f b6 85 10 ff ff ff 	movzbl -0xf0(%rbp),%eax
 128a183:	24 03                	and    $0x3,%al
 128a185:	3c 02                	cmp    $0x2,%al
 128a187:	0f 94 c0             	sete   %al
 128a18a:	80 bd 18 ff ff ff 11 	cmpb   $0x11,-0xe8(%rbp)
 128a191:	0f 93 c1             	setae  %cl
 128a194:	49 81 fc f2 ff 00 00 	cmp    $0xfff2,%r12
 128a19b:	0f 93 c2             	setae  %dl
 128a19e:	20 ca                	and    %cl,%dl
 128a1a0:	84 c2                	test   %al,%dl
 128a1a2:	74 7c                	je     128a220 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x930>
 128a1a4:	c6 85 48 ff ff ff 00 	movb   $0x0,-0xb8(%rbp)
 128a1ab:	48 c7 85 b0 fb ff ff 	movq   $0x0,-0x450(%rbp)
 128a1b2:	00 00 00 00 
 128a1b6:	4c 89 a5 b8 fb ff ff 	mov    %r12,-0x448(%rbp)
 128a1bd:	48 c7 85 c0 fb ff ff 	movq   $0x2,-0x440(%rbp)
 128a1c4:	02 00 00 00 
 128a1c8:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 128a1cc:	c5 fc 11 85 c8 fb ff 	vmovups %ymm0,-0x438(%rbp)
 128a1d3:	ff 
 128a1d4:	c6 85 47 ff ff ff 00 	movb   $0x0,-0xb9(%rbp)
 128a1db:	c5 fc 11 85 e8 fb ff 	vmovups %ymm0,-0x418(%rbp)
 128a1e2:	ff 
 128a1e3:	66 c7 85 08 fc ff ff 	movw   $0x0,-0x3f8(%rbp)
 128a1ea:	00 00 
 128a1ec:	b8 01 00 00 00       	mov    $0x1,%eax
 128a1f1:	48 89 85 10 ff ff ff 	mov    %rax,-0xf0(%rbp)
 128a1f8:	48 83 7d b0 00       	cmpq   $0x0,-0x50(%rbp)
 128a1fd:	74 36                	je     128a235 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x945>
 128a1ff:	49 8d 45 58          	lea    0x58(%r13),%rax
 128a203:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 128a207:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 128a20e:	00 00 
 128a210:	f6 00 01             	testb  $0x1,(%rax)
 128a213:	75 14                	jne    128a229 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x939>
 128a215:	48 83 c0 60          	add    $0x60,%rax
 128a219:	48 ff c9             	dec    %rcx
 128a21c:	75 f2                	jne    128a210 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x920>
 128a21e:	eb 15                	jmp    128a235 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x945>
 128a220:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 128a224:	e9 10 02 00 00       	jmp    128a439 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xb49>
 128a229:	b8 02 00 00 00       	mov    $0x2,%eax
 128a22e:	48 89 85 10 ff ff ff 	mov    %rax,-0xf0(%rbp)
 128a235:	31 db                	xor    %ebx,%ebx
 128a237:	0f b6 85 20 ff ff ff 	movzbl -0xe0(%rbp),%eax
 128a23e:	48 89 85 20 ff ff ff 	mov    %rax,-0xe0(%rbp)
 128a245:	eb 20                	jmp    128a267 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x977>
 128a247:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 128a24e:	00 00 
 128a250:	4c 8b ad 58 ff ff ff 	mov    -0xa8(%rbp),%r13
 128a257:	48 ff c3             	inc    %rbx
 128a25a:	48 39 9d 10 ff ff ff 	cmp    %rbx,-0xf0(%rbp)
 128a261:	0f 84 bc 01 00 00    	je     128a423 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xb33>
 128a267:	48 85 db             	test   %rbx,%rbx
 128a26a:	48 8d 85 b0 fb ff ff 	lea    -0x450(%rbp),%rax
 128a271:	49 0f 44 c5          	cmove  %r13,%rax
 128a275:	41 ba 01 00 00 00    	mov    $0x1,%r10d
 128a27b:	4c 0f 44 55 b0       	cmove  -0x50(%rbp),%r10
 128a280:	48 8d bd 78 fe ff ff 	lea    -0x188(%rbp),%rdi
 128a287:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 128a28b:	48 8d 15 8b 32 e6 ff 	lea    -0x19cd75(%rip),%rdx        # 10ed51d <__anon_11996>
 128a292:	31 c9                	xor    %ecx,%ecx
 128a294:	4d 89 f8             	mov    %r15,%r8
 128a297:	4d 89 e1             	mov    %r12,%r9
 128a29a:	ff b5 20 ff ff ff    	push   -0xe0(%rbp)
 128a2a0:	ff b5 60 fe ff ff    	push   -0x1a0(%rbp)
 128a2a6:	41 52                	push   %r10
 128a2a8:	50                   	push   %rax
 128a2a9:	c5 f8 77             	vzeroupper 
 128a2ac:	e8 cf 19 f9 ff       	call   121bc80 <br.encoder.long_distance.augmentAllocWithHistoryAndMaxDistanceForFormat>
 128a2b1:	48 83 c4 20          	add    $0x20,%rsp
 128a2b5:	44 0f b7 b5 88 fe ff 	movzwl -0x178(%rbp),%r14d
 128a2bc:	ff 
 128a2bd:	66 45 85 f6          	test   %r14w,%r14w
 128a2c1:	0f 85 68 0a 00 00    	jne    128ad2f <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x143f>
 128a2c7:	4c 8b ad 78 fe ff ff 	mov    -0x188(%rbp),%r13
 128a2ce:	4d 85 ed             	test   %r13,%r13
 128a2d1:	0f 84 79 ff ff ff    	je     128a250 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x960>
 128a2d7:	4c 8b b5 80 fe ff ff 	mov    -0x180(%rbp),%r14
 128a2de:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 128a2e2:	c5 fc 11 85 20 f6 ff 	vmovups %ymm0,-0x9e0(%rbp)
 128a2e9:	ff 
 128a2ea:	c5 fc 11 85 10 f6 ff 	vmovups %ymm0,-0x9f0(%rbp)
 128a2f1:	ff 
 128a2f2:	c5 fc 11 85 f0 f5 ff 	vmovups %ymm0,-0xa10(%rbp)
 128a2f9:	ff 
 128a2fa:	c5 fc 11 85 d0 f5 ff 	vmovups %ymm0,-0xa30(%rbp)
 128a301:	ff 
 128a302:	c5 fc 11 85 b0 f5 ff 	vmovups %ymm0,-0xa50(%rbp)
 128a309:	ff 
 128a30a:	48 8d bd 98 fd ff ff 	lea    -0x268(%rbp),%rdi
 128a311:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 128a315:	4c 89 fa             	mov    %r15,%rdx
 128a318:	4c 89 e1             	mov    %r12,%rcx
 128a31b:	4d 89 e8             	mov    %r13,%r8
 128a31e:	4d 89 f1             	mov    %r14,%r9
 128a321:	48 8d 85 10 fe ff ff 	lea    -0x1f0(%rbp),%rax
 128a328:	50                   	push   %rax
 128a329:	48 8d 85 b0 f5 ff ff 	lea    -0xa50(%rbp),%rax
 128a330:	50                   	push   %rax
 128a331:	c5 f8 77             	vzeroupper 
 128a334:	e8 97 00 f6 ff       	call   11ea3d0 <br.encodeLazyCommandPlanAllocRecorded__anon_43465>
 128a339:	48 83 c4 10          	add    $0x10,%rsp
 128a33d:	44 0f b7 bd a8 fd ff 	movzwl -0x258(%rbp),%r15d
 128a344:	ff 
 128a345:	66 45 85 ff          	test   %r15w,%r15w
 128a349:	0f 85 68 0a 00 00    	jne    128adb7 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x14c7>
 128a34f:	4c 8b a5 98 fd ff ff 	mov    -0x268(%rbp),%r12
 128a356:	4c 8b bd a0 fd ff ff 	mov    -0x260(%rbp),%r15
 128a35d:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 128a361:	49 39 cf             	cmp    %rcx,%r15
 128a364:	73 7a                	jae    128a3e0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xaf0>
 128a366:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128a36a:	48 8b 38             	mov    (%rax),%rdi
 128a36d:	48 8b 40 08          	mov    0x8(%rax),%rax
 128a371:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128a375:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 128a379:	48 89 ca             	mov    %rcx,%rdx
 128a37c:	31 c9                	xor    %ecx,%ecx
 128a37e:	ff 50 18             	call   *0x18(%rax)
 128a381:	4d 85 f6             	test   %r14,%r14
 128a384:	74 22                	je     128a3a8 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xab8>
 128a386:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128a38a:	48 8b 38             	mov    (%rax),%rdi
 128a38d:	48 8b 40 08          	mov    0x8(%rax),%rax
 128a391:	49 c1 e6 05          	shl    $0x5,%r14
 128a395:	4b 8d 14 76          	lea    (%r14,%r14,2),%rdx
 128a399:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128a39d:	4c 89 ee             	mov    %r13,%rsi
 128a3a0:	b9 03 00 00 00       	mov    $0x3,%ecx
 128a3a5:	ff 50 18             	call   *0x18(%rax)
 128a3a8:	4c 89 65 c8          	mov    %r12,-0x38(%rbp)
 128a3ac:	4c 89 7d b8          	mov    %r15,-0x48(%rbp)
 128a3b0:	4c 8b a5 50 ff ff ff 	mov    -0xb0(%rbp),%r12
 128a3b7:	4c 8b bd 78 ff ff ff 	mov    -0x88(%rbp),%r15
 128a3be:	4c 8b ad 58 ff ff ff 	mov    -0xa8(%rbp),%r13
 128a3c5:	48 ff c3             	inc    %rbx
 128a3c8:	48 39 9d 10 ff ff ff 	cmp    %rbx,-0xf0(%rbp)
 128a3cf:	0f 85 92 fe ff ff    	jne    128a267 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x977>
 128a3d5:	eb 4c                	jmp    128a423 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xb33>
 128a3d7:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 128a3de:	00 00 
 128a3e0:	4d 85 ff             	test   %r15,%r15
 128a3e3:	74 2c                	je     128a411 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xb21>
 128a3e5:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128a3e9:	48 8b 38             	mov    (%rax),%rdi
 128a3ec:	48 8b 40 08          	mov    0x8(%rax),%rax
 128a3f0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128a3f4:	4c 89 e6             	mov    %r12,%rsi
 128a3f7:	4c 89 fa             	mov    %r15,%rdx
 128a3fa:	49 89 cf             	mov    %rcx,%r15
 128a3fd:	31 c9                	xor    %ecx,%ecx
 128a3ff:	ff 50 18             	call   *0x18(%rax)
 128a402:	4c 8b 65 c8          	mov    -0x38(%rbp),%r12
 128a406:	4d 85 f6             	test   %r14,%r14
 128a409:	0f 85 77 ff ff ff    	jne    128a386 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xa96>
 128a40f:	eb 97                	jmp    128a3a8 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xab8>
 128a411:	4c 8b 65 c8          	mov    -0x38(%rbp),%r12
 128a415:	49 89 cf             	mov    %rcx,%r15
 128a418:	4d 85 f6             	test   %r14,%r14
 128a41b:	0f 85 65 ff ff ff    	jne    128a386 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xa96>
 128a421:	eb 85                	jmp    128a3a8 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xab8>
 128a423:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 128a427:	48 89 95 68 ff ff ff 	mov    %rdx,-0x98(%rbp)
 128a42e:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 128a432:	48 89 85 60 ff ff ff 	mov    %rax,-0xa0(%rbp)
 128a439:	48 8b 85 68 fe ff ff 	mov    -0x198(%rbp),%rax
 128a440:	48 c1 e8 38          	shr    $0x38,%rax
 128a444:	83 e0 01             	and    $0x1,%eax
 128a447:	80 7d 90 00          	cmpb   $0x0,-0x70(%rbp)
 128a44b:	44 0f b6 65 91       	movzbl -0x6f(%rbp),%r12d
 128a450:	44 0f 45 e0          	cmovne %eax,%r12d
 128a454:	0f b6 4d ac          	movzbl -0x54(%rbp),%ecx
 128a458:	44 20 e1             	and    %r12b,%cl
 128a45b:	48 83 bd 38 ff ff ff 	cmpq   $0x0,-0xc8(%rbp)
 128a462:	00 
 128a463:	0f 95 c0             	setne  %al
 128a466:	84 c1                	test   %al,%cl
 128a468:	0f 84 1d 02 00 00    	je     128a68b <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xd9b>
 128a46e:	48 89 55 b8          	mov    %rdx,-0x48(%rbp)
 128a472:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 128a476:	c5 fc 11 85 90 f5 ff 	vmovups %ymm0,-0xa70(%rbp)
 128a47d:	ff 
 128a47e:	c5 fc 11 85 80 f5 ff 	vmovups %ymm0,-0xa80(%rbp)
 128a485:	ff 
 128a486:	c5 fc 11 85 60 f5 ff 	vmovups %ymm0,-0xaa0(%rbp)
 128a48d:	ff 
 128a48e:	c5 fc 11 85 40 f5 ff 	vmovups %ymm0,-0xac0(%rbp)
 128a495:	ff 
 128a496:	c5 fc 11 85 20 f5 ff 	vmovups %ymm0,-0xae0(%rbp)
 128a49d:	ff 
 128a49e:	c6 45 84 00          	movb   $0x0,-0x7c(%rbp)
 128a4a2:	c6 45 85 00          	movb   $0x0,-0x7b(%rbp)
 128a4a6:	0f b6 45 93          	movzbl -0x6d(%rbp),%eax
 128a4aa:	88 85 f1 f8 ff ff    	mov    %al,-0x70f(%rbp)
 128a4b0:	48 c7 85 e0 f6 ff ff 	movq   $0x0,-0x920(%rbp)
 128a4b7:	00 00 00 00 
 128a4bb:	66 c7 85 f4 f8 ff ff 	movw   $0x100,-0x70c(%rbp)
 128a4c2:	00 01 
 128a4c4:	c5 fc 11 85 10 f7 ff 	vmovups %ymm0,-0x8f0(%rbp)
 128a4cb:	ff 
 128a4cc:	c5 fc 11 85 30 f7 ff 	vmovups %ymm0,-0x8d0(%rbp)
 128a4d3:	ff 
 128a4d4:	c5 fc 11 85 50 f7 ff 	vmovups %ymm0,-0x8b0(%rbp)
 128a4db:	ff 
 128a4dc:	c5 fc 11 85 70 f7 ff 	vmovups %ymm0,-0x890(%rbp)
 128a4e3:	ff 
 128a4e4:	c5 fc 11 85 90 f7 ff 	vmovups %ymm0,-0x870(%rbp)
 128a4eb:	ff 
 128a4ec:	c5 fc 11 85 b0 f7 ff 	vmovups %ymm0,-0x850(%rbp)
 128a4f3:	ff 
 128a4f4:	c5 fc 11 85 d0 f7 ff 	vmovups %ymm0,-0x830(%rbp)
 128a4fb:	ff 
 128a4fc:	c5 fc 11 85 f0 f7 ff 	vmovups %ymm0,-0x810(%rbp)
 128a503:	ff 
 128a504:	c5 fc 11 85 10 f8 ff 	vmovups %ymm0,-0x7f0(%rbp)
 128a50b:	ff 
 128a50c:	c5 fc 11 85 30 f8 ff 	vmovups %ymm0,-0x7d0(%rbp)
 128a513:	ff 
 128a514:	c5 fc 11 85 50 f8 ff 	vmovups %ymm0,-0x7b0(%rbp)
 128a51b:	ff 
 128a51c:	c5 fc 11 85 70 f8 ff 	vmovups %ymm0,-0x790(%rbp)
 128a523:	ff 
 128a524:	c5 fc 11 85 90 f8 ff 	vmovups %ymm0,-0x770(%rbp)
 128a52b:	ff 
 128a52c:	c5 fc 11 85 b0 f8 ff 	vmovups %ymm0,-0x750(%rbp)
 128a533:	ff 
 128a534:	48 c7 85 d0 f8 ff ff 	movq   $0x0,-0x730(%rbp)
 128a53b:	00 00 00 00 
 128a53f:	c6 85 e8 f8 ff ff 38 	movb   $0x38,-0x718(%rbp)
 128a546:	c6 85 f0 f8 ff ff 00 	movb   $0x0,-0x710(%rbp)
 128a54d:	0f b6 45 84          	movzbl -0x7c(%rbp),%eax
 128a551:	0f b6 4d 85          	movzbl -0x7b(%rbp),%ecx
 128a555:	88 85 ea f8 ff ff    	mov    %al,-0x716(%rbp)
 128a55b:	88 8d eb f8 ff ff    	mov    %cl,-0x715(%rbp)
 128a561:	48 8b 85 18 ff ff ff 	mov    -0xe8(%rbp),%rax
 128a568:	88 85 e9 f8 ff ff    	mov    %al,-0x717(%rbp)
 128a56e:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 128a575:	48 89 85 d0 f6 ff ff 	mov    %rax,-0x930(%rbp)
 128a57c:	48 8b 85 30 ff ff ff 	mov    -0xd0(%rbp),%rax
 128a583:	48 89 85 d8 f6 ff ff 	mov    %rax,-0x928(%rbp)
 128a58a:	c7 85 ec f8 ff ff 01 	movl   $0x1000101,-0x714(%rbp)
 128a591:	01 00 01 
 128a594:	66 c7 85 f2 f8 ff ff 	movw   $0x0,-0x70e(%rbp)
 128a59b:	00 00 
 128a59d:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 128a5a1:	c5 f8 11 85 d8 f8 ff 	vmovups %xmm0,-0x728(%rbp)
 128a5a8:	ff 
 128a5a9:	c5 fc 10 05 2f 7b d7 	vmovups -0x2884d1(%rip),%ymm0        # 10020e0 <__anon_35167>
 128a5b0:	ff 
 128a5b1:	c5 fc 11 85 f0 f6 ff 	vmovups %ymm0,-0x910(%rbp)
 128a5b8:	ff 
 128a5b9:	48 c7 85 e8 f6 ff ff 	movq   $0x0,-0x918(%rbp)
 128a5c0:	00 00 00 00 
 128a5c4:	48 83 ec 08          	sub    $0x8,%rsp
 128a5c8:	48 8d 85 d0 f6 ff ff 	lea    -0x930(%rbp),%rax
 128a5cf:	4c 8d 95 20 f5 ff ff 	lea    -0xae0(%rbp),%r10
 128a5d6:	48 8d bd 80 fd ff ff 	lea    -0x280(%rbp),%rdi
 128a5dd:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 128a5e1:	4c 89 fa             	mov    %r15,%rdx
 128a5e4:	48 8b 8d 50 ff ff ff 	mov    -0xb0(%rbp),%rcx
 128a5eb:	4d 89 e8             	mov    %r13,%r8
 128a5ee:	4c 8b 4d b0          	mov    -0x50(%rbp),%r9
 128a5f2:	50                   	push   %rax
 128a5f3:	41 52                	push   %r10
 128a5f5:	6a 01                	push   $0x1
 128a5f7:	c5 f8 77             	vzeroupper 
 128a5fa:	e8 01 75 f9 ff       	call   1221b00 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_77106>
 128a5ff:	48 83 c4 20          	add    $0x20,%rsp
 128a603:	0f b7 9d 90 fd ff ff 	movzwl -0x270(%rbp),%ebx
 128a60a:	66 85 db             	test   %bx,%bx
 128a60d:	0f 85 e9 08 00 00    	jne    128aefc <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x160c>
 128a613:	4c 8b b5 80 fd ff ff 	mov    -0x280(%rbp),%r14
 128a61a:	48 8b 9d 88 fd ff ff 	mov    -0x278(%rbp),%rbx
 128a621:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 128a625:	48 39 d3             	cmp    %rdx,%rbx
 128a628:	73 3e                	jae    128a668 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xd78>
 128a62a:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128a62e:	48 8b 38             	mov    (%rax),%rdi
 128a631:	48 8b 40 08          	mov    0x8(%rax),%rax
 128a635:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128a639:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 128a63d:	31 c9                	xor    %ecx,%ecx
 128a63f:	ff 50 18             	call   *0x18(%rax)
 128a642:	4c 89 b5 60 ff ff ff 	mov    %r14,-0xa0(%rbp)
 128a649:	48 89 9d 68 ff ff ff 	mov    %rbx,-0x98(%rbp)
 128a650:	0f b6 45 ae          	movzbl -0x52(%rbp),%eax
 128a654:	4c 89 75 c8          	mov    %r14,-0x38(%rbp)
 128a658:	48 89 da             	mov    %rbx,%rdx
 128a65b:	a8 01                	test   $0x1,%al
 128a65d:	75 34                	jne    128a693 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xda3>
 128a65f:	4c 8b 7d c8          	mov    -0x38(%rbp),%r15
 128a663:	e9 42 01 00 00       	jmp    128a7aa <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xeba>
 128a668:	48 85 db             	test   %rbx,%rbx
 128a66b:	74 1e                	je     128a68b <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xd9b>
 128a66d:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128a671:	48 8b 38             	mov    (%rax),%rdi
 128a674:	48 8b 40 08          	mov    0x8(%rax),%rax
 128a678:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128a67c:	4c 89 f6             	mov    %r14,%rsi
 128a67f:	48 89 da             	mov    %rbx,%rdx
 128a682:	31 c9                	xor    %ecx,%ecx
 128a684:	ff 50 18             	call   *0x18(%rax)
 128a687:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 128a68b:	0f b6 45 c5          	movzbl -0x3b(%rbp),%eax
 128a68f:	a8 01                	test   $0x1,%al
 128a691:	74 cc                	je     128a65f <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xd6f>
 128a693:	49 89 d6             	mov    %rdx,%r14
 128a696:	48 8b 8d 50 ff ff ff 	mov    -0xb0(%rbp),%rcx
 128a69d:	48 81 f9 00 10 00 00 	cmp    $0x1000,%rcx
 128a6a4:	0f 82 c8 00 00 00    	jb     128a772 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xe82>
 128a6aa:	48 3b 8d 70 fe ff ff 	cmp    -0x190(%rbp),%rcx
 128a6b1:	0f 87 bb 00 00 00    	ja     128a772 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xe82>
 128a6b7:	c5 f8 28 85 60 fc ff 	vmovaps -0x3a0(%rbp),%xmm0
 128a6be:	ff 
 128a6bf:	c5 f8 13 85 b0 fe ff 	vmovlps %xmm0,-0x150(%rbp)
 128a6c6:	ff 
 128a6c7:	8b 85 08 ff ff ff    	mov    -0xf8(%rbp),%eax
 128a6cd:	89 85 b8 fe ff ff    	mov    %eax,-0x148(%rbp)
 128a6d3:	0f b7 85 0c ff ff ff 	movzwl -0xf4(%rbp),%eax
 128a6da:	66 89 85 bc fe ff ff 	mov    %ax,-0x144(%rbp)
 128a6e1:	0f b6 45 ae          	movzbl -0x52(%rbp),%eax
 128a6e5:	88 85 be fe ff ff    	mov    %al,-0x142(%rbp)
 128a6eb:	0f b6 45 92          	movzbl -0x6e(%rbp),%eax
 128a6ef:	88 85 bf fe ff ff    	mov    %al,-0x141(%rbp)
 128a6f5:	48 8d bd 68 fd ff ff 	lea    -0x298(%rbp),%rdi
 128a6fc:	4c 8d 85 b0 fe ff ff 	lea    -0x150(%rbp),%r8
 128a703:	4c 8d 8d 10 fe ff ff 	lea    -0x1f0(%rbp),%r9
 128a70a:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 128a70e:	4c 89 fa             	mov    %r15,%rdx
 128a711:	e8 5a 0a 00 00       	call   128b170 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613>
 128a716:	0f b7 9d 78 fd ff ff 	movzwl -0x288(%rbp),%ebx
 128a71d:	66 85 db             	test   %bx,%bx
 128a720:	0f 85 e1 07 00 00    	jne    128af07 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1617>
 128a726:	4c 8b bd 68 fd ff ff 	mov    -0x298(%rbp),%r15
 128a72d:	4d 85 ff             	test   %r15,%r15
 128a730:	4c 89 f1             	mov    %r14,%rcx
 128a733:	74 6e                	je     128a7a3 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xeb3>
 128a735:	48 8b 95 70 fd ff ff 	mov    -0x290(%rbp),%rdx
 128a73c:	48 39 ca             	cmp    %rcx,%rdx
 128a73f:	73 3a                	jae    128a77b <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xe8b>
 128a741:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128a745:	48 8b 38             	mov    (%rax),%rdi
 128a748:	48 8b 40 08          	mov    0x8(%rax),%rax
 128a74c:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128a750:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 128a754:	48 89 d3             	mov    %rdx,%rbx
 128a757:	48 89 ca             	mov    %rcx,%rdx
 128a75a:	31 c9                	xor    %ecx,%ecx
 128a75c:	ff 50 18             	call   *0x18(%rax)
 128a75f:	48 89 da             	mov    %rbx,%rdx
 128a762:	4c 89 bd 60 ff ff ff 	mov    %r15,-0xa0(%rbp)
 128a769:	48 89 9d 68 ff ff ff 	mov    %rbx,-0x98(%rbp)
 128a770:	eb 38                	jmp    128a7aa <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xeba>
 128a772:	4c 8b 7d c8          	mov    -0x38(%rbp),%r15
 128a776:	4c 89 f2             	mov    %r14,%rdx
 128a779:	eb 2f                	jmp    128a7aa <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xeba>
 128a77b:	48 85 d2             	test   %rdx,%rdx
 128a77e:	74 23                	je     128a7a3 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xeb3>
 128a780:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128a784:	48 8b 38             	mov    (%rax),%rdi
 128a787:	48 8b 40 08          	mov    0x8(%rax),%rax
 128a78b:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128a78f:	4c 89 fe             	mov    %r15,%rsi
 128a792:	48 89 cb             	mov    %rcx,%rbx
 128a795:	31 c9                	xor    %ecx,%ecx
 128a797:	ff 50 18             	call   *0x18(%rax)
 128a79a:	4c 8b 7d c8          	mov    -0x38(%rbp),%r15
 128a79e:	48 89 da             	mov    %rbx,%rdx
 128a7a1:	eb 07                	jmp    128a7aa <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xeba>
 128a7a3:	4c 8b 7d c8          	mov    -0x38(%rbp),%r15
 128a7a7:	48 89 ca             	mov    %rcx,%rdx
 128a7aa:	80 7d ad 0a          	cmpb   $0xa,-0x53(%rbp)
 128a7ae:	0f 93 c0             	setae  %al
 128a7b1:	f6 85 00 ff ff ff 10 	testb  $0x10,-0x100(%rbp)
 128a7b8:	0f 95 c1             	setne  %cl
 128a7bb:	20 c1                	and    %al,%cl
 128a7bd:	4c 8b b5 50 ff ff ff 	mov    -0xb0(%rbp),%r14
 128a7c4:	49 8d 86 00 f0 ff ff 	lea    -0x1000(%r14),%rax
 128a7cb:	48 3d 01 f0 00 00    	cmp    $0xf001,%rax
 128a7d1:	0f 92 c0             	setb   %al
 128a7d4:	84 c1                	test   %al,%cl
 128a7d6:	0f 84 02 01 00 00    	je     128a8de <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xfee>
 128a7dc:	48 8b 9d 78 ff ff ff 	mov    -0x88(%rbp),%rbx
 128a7e3:	42 80 7c 33 ff 0a    	cmpb   $0xa,-0x1(%rbx,%r14,1)
 128a7e9:	0f 85 ef 00 00 00    	jne    128a8de <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xfee>
 128a7ef:	48 89 55 b8          	mov    %rdx,-0x48(%rbp)
 128a7f3:	48 89 df             	mov    %rbx,%rdi
 128a7f6:	4c 89 f6             	mov    %r14,%rsi
 128a7f9:	e8 92 00 e7 ff       	call   10fa890 <vortBrStableFixedWidthRecord>
 128a7fe:	84 c0                	test   %al,%al
 128a800:	0f 84 ef 04 00 00    	je     128acf5 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1405>
 128a806:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 128a80a:	c5 fc 11 85 00 f5 ff 	vmovups %ymm0,-0xb00(%rbp)
 128a811:	ff 
 128a812:	c5 fc 11 85 f0 f4 ff 	vmovups %ymm0,-0xb10(%rbp)
 128a819:	ff 
 128a81a:	c5 fc 11 85 d0 f4 ff 	vmovups %ymm0,-0xb30(%rbp)
 128a821:	ff 
 128a822:	c5 fc 11 85 b0 f4 ff 	vmovups %ymm0,-0xb50(%rbp)
 128a829:	ff 
 128a82a:	c5 fc 11 85 90 f4 ff 	vmovups %ymm0,-0xb70(%rbp)
 128a831:	ff 
 128a832:	44 0f b6 4d c6       	movzbl -0x3a(%rbp),%r9d
 128a837:	48 8d 85 90 f4 ff ff 	lea    -0xb70(%rbp),%rax
 128a83e:	45 0f b6 d4          	movzbl %r12b,%r10d
 128a842:	44 0f b6 85 00 ff ff 	movzbl -0x100(%rbp),%r8d
 128a849:	ff 
 128a84a:	48 8d bd 50 fd ff ff 	lea    -0x2b0(%rbp),%rdi
 128a851:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 128a855:	48 89 da             	mov    %rbx,%rdx
 128a858:	4c 89 f1             	mov    %r14,%rcx
 128a85b:	50                   	push   %rax
 128a85c:	41 52                	push   %r10
 128a85e:	ff b5 30 ff ff ff    	push   -0xd0(%rbp)
 128a864:	ff b5 28 ff ff ff    	push   -0xd8(%rbp)
 128a86a:	c5 f8 77             	vzeroupper 
 128a86d:	e8 1e e7 ff ff       	call   1288f90 <br.encodeRecordOptimalCandidateWithOptionsAlloc>
 128a872:	48 83 c4 20          	add    $0x20,%rsp
 128a876:	0f b7 9d 60 fd ff ff 	movzwl -0x2a0(%rbp),%ebx
 128a87d:	66 85 db             	test   %bx,%bx
 128a880:	0f 85 54 08 00 00    	jne    128b0da <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x17ea>
 128a886:	48 8b 85 50 fd ff ff 	mov    -0x2b0(%rbp),%rax
 128a88d:	48 89 45 c8          	mov    %rax,-0x38(%rbp)
 128a891:	48 85 c0             	test   %rax,%rax
 128a894:	44 0f b6 65 c7       	movzbl -0x39(%rbp),%r12d
 128a899:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 128a89d:	0f 84 84 04 00 00    	je     128ad27 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1437>
 128a8a3:	48 8b 9d 58 fd ff ff 	mov    -0x2a8(%rbp),%rbx
 128a8aa:	48 39 d3             	cmp    %rdx,%rbx
 128a8ad:	0f 83 4b 04 00 00    	jae    128acfe <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x140e>
 128a8b3:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128a8b7:	48 8b 38             	mov    (%rax),%rdi
 128a8ba:	48 8b 40 08          	mov    0x8(%rax),%rax
 128a8be:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128a8c2:	4c 89 fe             	mov    %r15,%rsi
 128a8c5:	31 c9                	xor    %ecx,%ecx
 128a8c7:	ff 50 18             	call   *0x18(%rax)
 128a8ca:	4c 8b 7d c8          	mov    -0x38(%rbp),%r15
 128a8ce:	4c 89 bd 60 ff ff ff 	mov    %r15,-0xa0(%rbp)
 128a8d5:	48 89 9d 68 ff ff ff 	mov    %rbx,-0x98(%rbp)
 128a8dc:	eb 08                	jmp    128a8e6 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xff6>
 128a8de:	48 89 d3             	mov    %rdx,%rbx
 128a8e1:	44 0f b6 65 c7       	movzbl -0x39(%rbp),%r12d
 128a8e6:	41 80 e4 03          	and    $0x3,%r12b
 128a8ea:	41 80 fc 02          	cmp    $0x2,%r12b
 128a8ee:	0f 94 c0             	sete   %al
 128a8f1:	80 7d ad 04          	cmpb   $0x4,-0x53(%rbp)
 128a8f5:	0f 93 c1             	setae  %cl
 128a8f8:	84 c8                	test   %cl,%al
 128a8fa:	0f 84 eb 01 00 00    	je     128aaeb <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x11fb>
 128a900:	4c 89 7d c8          	mov    %r15,-0x38(%rbp)
 128a904:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 128a908:	c5 fc 11 85 70 f4 ff 	vmovups %ymm0,-0xb90(%rbp)
 128a90f:	ff 
 128a910:	c5 fc 11 85 60 f4 ff 	vmovups %ymm0,-0xba0(%rbp)
 128a917:	ff 
 128a918:	c5 fc 11 85 40 f4 ff 	vmovups %ymm0,-0xbc0(%rbp)
 128a91f:	ff 
 128a920:	c5 fc 11 85 20 f4 ff 	vmovups %ymm0,-0xbe0(%rbp)
 128a927:	ff 
 128a928:	c5 fc 11 85 00 f4 ff 	vmovups %ymm0,-0xc00(%rbp)
 128a92f:	ff 
 128a930:	0f b6 45 87          	movzbl -0x79(%rbp),%eax
 128a934:	c6 45 82 01          	movb   $0x1,-0x7e(%rbp)
 128a938:	c6 45 83 06          	movb   $0x6,-0x7d(%rbp)
 128a93c:	0f b6 4d c6          	movzbl -0x3a(%rbp),%ecx
 128a940:	88 8d 19 fb ff ff    	mov    %cl,-0x4e7(%rbp)
 128a946:	48 c7 85 08 f9 ff ff 	movq   $0x0,-0x6f8(%rbp)
 128a94d:	00 00 00 00 
 128a951:	88 85 1d fb ff ff    	mov    %al,-0x4e3(%rbp)
 128a957:	c6 85 1c fb ff ff 00 	movb   $0x0,-0x4e4(%rbp)
 128a95e:	c5 fc 11 85 38 f9 ff 	vmovups %ymm0,-0x6c8(%rbp)
 128a965:	ff 
 128a966:	c5 fc 11 85 58 f9 ff 	vmovups %ymm0,-0x6a8(%rbp)
 128a96d:	ff 
 128a96e:	c5 fc 11 85 78 f9 ff 	vmovups %ymm0,-0x688(%rbp)
 128a975:	ff 
 128a976:	c5 fc 11 85 98 f9 ff 	vmovups %ymm0,-0x668(%rbp)
 128a97d:	ff 
 128a97e:	c5 fc 11 85 b8 f9 ff 	vmovups %ymm0,-0x648(%rbp)
 128a985:	ff 
 128a986:	c5 fc 11 85 d8 f9 ff 	vmovups %ymm0,-0x628(%rbp)
 128a98d:	ff 
 128a98e:	c5 fc 11 85 f8 f9 ff 	vmovups %ymm0,-0x608(%rbp)
 128a995:	ff 
 128a996:	c5 fc 11 85 18 fa ff 	vmovups %ymm0,-0x5e8(%rbp)
 128a99d:	ff 
 128a99e:	c5 fc 11 85 38 fa ff 	vmovups %ymm0,-0x5c8(%rbp)
 128a9a5:	ff 
 128a9a6:	c5 fc 11 85 58 fa ff 	vmovups %ymm0,-0x5a8(%rbp)
 128a9ad:	ff 
 128a9ae:	c5 fc 11 85 78 fa ff 	vmovups %ymm0,-0x588(%rbp)
 128a9b5:	ff 
 128a9b6:	c5 fc 11 85 98 fa ff 	vmovups %ymm0,-0x568(%rbp)
 128a9bd:	ff 
 128a9be:	c5 fc 11 85 b8 fa ff 	vmovups %ymm0,-0x548(%rbp)
 128a9c5:	ff 
 128a9c6:	c5 fc 11 85 d8 fa ff 	vmovups %ymm0,-0x528(%rbp)
 128a9cd:	ff 
 128a9ce:	48 c7 85 f8 fa ff ff 	movq   $0x0,-0x508(%rbp)
 128a9d5:	00 00 00 00 
 128a9d9:	c6 85 10 fb ff ff 38 	movb   $0x38,-0x4f0(%rbp)
 128a9e0:	c6 85 18 fb ff ff 00 	movb   $0x0,-0x4e8(%rbp)
 128a9e7:	0f b6 45 82          	movzbl -0x7e(%rbp),%eax
 128a9eb:	0f b6 4d 83          	movzbl -0x7d(%rbp),%ecx
 128a9ef:	88 85 12 fb ff ff    	mov    %al,-0x4ee(%rbp)
 128a9f5:	88 8d 13 fb ff ff    	mov    %cl,-0x4ed(%rbp)
 128a9fb:	48 8b 85 18 ff ff ff 	mov    -0xe8(%rbp),%rax
 128aa02:	88 85 11 fb ff ff    	mov    %al,-0x4ef(%rbp)
 128aa08:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 128aa0f:	48 89 85 f8 f8 ff ff 	mov    %rax,-0x708(%rbp)
 128aa16:	48 8b 85 30 ff ff ff 	mov    -0xd0(%rbp),%rax
 128aa1d:	48 89 85 00 f9 ff ff 	mov    %rax,-0x700(%rbp)
 128aa24:	c7 85 14 fb ff ff 01 	movl   $0x101,-0x4ec(%rbp)
 128aa2b:	01 00 00 
 128aa2e:	66 c7 85 1a fb ff ff 	movw   $0x0,-0x4e6(%rbp)
 128aa35:	00 00 
 128aa37:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 128aa3b:	c5 f8 11 85 00 fb ff 	vmovups %xmm0,-0x500(%rbp)
 128aa42:	ff 
 128aa43:	c5 fc 10 05 95 76 d7 	vmovups -0x28896b(%rip),%ymm0        # 10020e0 <__anon_35167>
 128aa4a:	ff 
 128aa4b:	c5 fc 11 85 18 f9 ff 	vmovups %ymm0,-0x6e8(%rbp)
 128aa52:	ff 
 128aa53:	48 c7 85 10 f9 ff ff 	movq   $0x0,-0x6f0(%rbp)
 128aa5a:	00 00 00 00 
 128aa5e:	48 8d 85 f8 f8 ff ff 	lea    -0x708(%rbp),%rax
 128aa65:	4c 8d 95 00 f4 ff ff 	lea    -0xc00(%rbp),%r10
 128aa6c:	48 8d bd 38 fd ff ff 	lea    -0x2c8(%rbp),%rdi
 128aa73:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 128aa77:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 128aa7e:	4c 89 f1             	mov    %r14,%rcx
 128aa81:	4d 89 e8             	mov    %r13,%r8
 128aa84:	4c 8b 4d b0          	mov    -0x50(%rbp),%r9
 128aa88:	50                   	push   %rax
 128aa89:	41 52                	push   %r10
 128aa8b:	c5 f8 77             	vzeroupper 
 128aa8e:	e8 6d 9f ee ff       	call   1174a00 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307>
 128aa93:	48 83 c4 10          	add    $0x10,%rsp
 128aa97:	44 0f b7 b5 48 fd ff 	movzwl -0x2b8(%rbp),%r14d
 128aa9e:	ff 
 128aa9f:	45 85 f6             	test   %r14d,%r14d
 128aaa2:	0f 85 de 04 00 00    	jne    128af86 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1696>
 128aaa8:	4c 8b bd 38 fd ff ff 	mov    -0x2c8(%rbp),%r15
 128aaaf:	4c 8b a5 40 fd ff ff 	mov    -0x2c0(%rbp),%r12
 128aab6:	4d 85 ff             	test   %r15,%r15
 128aab9:	74 54                	je     128ab0f <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x121f>
 128aabb:	49 39 dc             	cmp    %rbx,%r12
 128aabe:	73 30                	jae    128aaf0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1200>
 128aac0:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128aac4:	48 8b 38             	mov    (%rax),%rdi
 128aac7:	48 8b 40 08          	mov    0x8(%rax),%rax
 128aacb:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128aacf:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 128aad3:	48 89 da             	mov    %rbx,%rdx
 128aad6:	31 c9                	xor    %ecx,%ecx
 128aad8:	ff 50 18             	call   *0x18(%rax)
 128aadb:	4c 89 bd 60 ff ff ff 	mov    %r15,-0xa0(%rbp)
 128aae2:	4c 89 a5 68 ff ff ff 	mov    %r12,-0x98(%rbp)
 128aae9:	eb 2b                	jmp    128ab16 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1226>
 128aaeb:	49 89 dc             	mov    %rbx,%r12
 128aaee:	eb 26                	jmp    128ab16 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1226>
 128aaf0:	4d 85 e4             	test   %r12,%r12
 128aaf3:	74 1a                	je     128ab0f <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x121f>
 128aaf5:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128aaf9:	48 8b 38             	mov    (%rax),%rdi
 128aafc:	48 8b 40 08          	mov    0x8(%rax),%rax
 128ab00:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128ab04:	4c 89 fe             	mov    %r15,%rsi
 128ab07:	4c 89 e2             	mov    %r12,%rdx
 128ab0a:	31 c9                	xor    %ecx,%ecx
 128ab0c:	ff 50 18             	call   *0x18(%rax)
 128ab0f:	49 89 dc             	mov    %rbx,%r12
 128ab12:	4c 8b 7d c8          	mov    -0x38(%rbp),%r15
 128ab16:	48 8b 8d 50 ff ff ff 	mov    -0xb0(%rbp),%rcx
 128ab1d:	48 81 f9 01 01 00 00 	cmp    $0x101,%rcx
 128ab24:	0f 92 c0             	setb   %al
 128ab27:	84 45 94             	test   %al,-0x6c(%rbp)
 128ab2a:	74 72                	je     128ab9e <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x12ae>
 128ab2c:	0f b6 45 c6          	movzbl -0x3a(%rbp),%eax
 128ab30:	44 0f b6 95 00 ff ff 	movzbl -0x100(%rbp),%r10d
 128ab37:	ff 
 128ab38:	48 8d bd 20 fd ff ff 	lea    -0x2e0(%rbp),%rdi
 128ab3f:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 128ab43:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 128ab4a:	4d 89 e8             	mov    %r13,%r8
 128ab4d:	4c 8b 4d b0          	mov    -0x50(%rbp),%r9
 128ab51:	ff b5 30 ff ff ff    	push   -0xd0(%rbp)
 128ab57:	ff b5 28 ff ff ff    	push   -0xd8(%rbp)
 128ab5d:	50                   	push   %rax
 128ab5e:	41 52                	push   %r10
 128ab60:	41 54                	push   %r12
 128ab62:	41 57                	push   %r15
 128ab64:	e8 47 cb ff ff       	call   12876b0 <br.selectRatioStaticDictionaryAlloc>
 128ab69:	48 83 c4 30          	add    $0x30,%rsp
 128ab6d:	0f b7 9d 30 fd ff ff 	movzwl -0x2d0(%rbp),%ebx
 128ab74:	66 85 db             	test   %bx,%bx
 128ab77:	0f 85 aa 03 00 00    	jne    128af27 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1637>
 128ab7d:	4c 8b bd 20 fd ff ff 	mov    -0x2e0(%rbp),%r15
 128ab84:	4c 8b a5 28 fd ff ff 	mov    -0x2d8(%rbp),%r12
 128ab8b:	4c 89 bd 60 ff ff ff 	mov    %r15,-0xa0(%rbp)
 128ab92:	4c 89 a5 68 ff ff ff 	mov    %r12,-0x98(%rbp)
 128ab99:	e9 89 00 00 00       	jmp    128ac27 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1337>
 128ab9e:	48 81 f9 01 10 00 00 	cmp    $0x1001,%rcx
 128aba5:	0f 92 c0             	setb   %al
 128aba8:	84 45 86             	test   %al,-0x7a(%rbp)
 128abab:	74 7a                	je     128ac27 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1337>
 128abad:	8b 85 c0 fe ff ff    	mov    -0x140(%rbp),%eax
 128abb3:	66 85 c0             	test   %ax,%ax
 128abb6:	0f 44 85 c4 fe ff ff 	cmove  -0x13c(%rbp),%eax
 128abbd:	66 85 c0             	test   %ax,%ax
 128abc0:	74 65                	je     128ac27 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1337>
 128abc2:	0f b7 c0             	movzwl %ax,%eax
 128abc5:	44 0f b6 55 c6       	movzbl -0x3a(%rbp),%r10d
 128abca:	48 83 ec 08          	sub    $0x8,%rsp
 128abce:	4c 8d 9d 60 ff ff ff 	lea    -0xa0(%rbp),%r11
 128abd5:	44 0f b6 8d 00 ff ff 	movzbl -0x100(%rbp),%r9d
 128abdc:	ff 
 128abdd:	48 8b 7d d0          	mov    -0x30(%rbp),%rdi
 128abe1:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 128abe8:	48 8b 95 50 ff ff ff 	mov    -0xb0(%rbp),%rdx
 128abef:	4c 89 e9             	mov    %r13,%rcx
 128abf2:	4c 8b 45 b0          	mov    -0x50(%rbp),%r8
 128abf6:	41 53                	push   %r11
 128abf8:	50                   	push   %rax
 128abf9:	ff b5 30 ff ff ff    	push   -0xd0(%rbp)
 128abff:	ff b5 28 ff ff ff    	push   -0xd8(%rbp)
 128ac05:	41 52                	push   %r10
 128ac07:	e8 f4 e0 ff ff       	call   1288d00 <br.selectExtendedRatioStaticDictionary>
 128ac0c:	48 83 c4 30          	add    $0x30,%rsp
 128ac10:	66 85 c0             	test   %ax,%ax
 128ac13:	0f 85 e0 04 00 00    	jne    128b0f9 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1809>
 128ac19:	4c 8b bd 60 ff ff ff 	mov    -0xa0(%rbp),%r15
 128ac20:	4c 8b a5 68 ff ff ff 	mov    -0x98(%rbp),%r12
 128ac27:	48 83 ec 08          	sub    $0x8,%rsp
 128ac2b:	48 8d 85 e0 fd ff ff 	lea    -0x220(%rbp),%rax
 128ac32:	48 8d bd 08 fd ff ff 	lea    -0x2f8(%rbp),%rdi
 128ac39:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 128ac3d:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 128ac44:	48 8b 8d 50 ff ff ff 	mov    -0xb0(%rbp),%rcx
 128ac4b:	4d 89 f8             	mov    %r15,%r8
 128ac4e:	4d 89 e1             	mov    %r12,%r9
 128ac51:	50                   	push   %rax
 128ac52:	e8 b9 9c ee ff       	call   1174910 <br.chooseStoredIfSmallerWithOptionsRecorded__anon_35219>
 128ac57:	48 83 c4 10          	add    $0x10,%rsp
 128ac5b:	0f b7 9d 18 fd ff ff 	movzwl -0x2e8(%rbp),%ebx
 128ac62:	66 85 db             	test   %bx,%bx
 128ac65:	0f 85 bc 02 00 00    	jne    128af27 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1637>
 128ac6b:	48 8b 9d 08 fd ff ff 	mov    -0x2f8(%rbp),%rbx
 128ac72:	4c 8b b5 10 fd ff ff 	mov    -0x2f0(%rbp),%r14
 128ac79:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 128ac7d:	48 85 c9             	test   %rcx,%rcx
 128ac80:	74 22                	je     128aca4 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x13b4>
 128ac82:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128ac86:	48 8b 38             	mov    (%rax),%rdi
 128ac89:	48 8b 40 08          	mov    0x8(%rax),%rax
 128ac8d:	48 c1 e1 05          	shl    $0x5,%rcx
 128ac91:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128ac95:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128ac99:	4c 89 ee             	mov    %r13,%rsi
 128ac9c:	b9 03 00 00 00       	mov    $0x3,%ecx
 128aca1:	ff 50 18             	call   *0x18(%rax)
 128aca4:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 128aca8:	48 85 c9             	test   %rcx,%rcx
 128acab:	74 25                	je     128acd2 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x13e2>
 128acad:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128acb1:	48 8b 38             	mov    (%rax),%rdi
 128acb4:	48 8b 40 08          	mov    0x8(%rax),%rax
 128acb8:	48 01 c9             	add    %rcx,%rcx
 128acbb:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128acbf:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128acc3:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 128acca:	b9 01 00 00 00       	mov    $0x1,%ecx
 128accf:	ff 50 18             	call   *0x18(%rax)
 128acd2:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 128acd6:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 128acdc:	48 89 18             	mov    %rbx,(%rax)
 128acdf:	4c 89 70 08          	mov    %r14,0x8(%rax)
 128ace3:	48 81 c4 e8 0b 00 00 	add    $0xbe8,%rsp
 128acea:	5b                   	pop    %rbx
 128aceb:	41 5c                	pop    %r12
 128aced:	41 5d                	pop    %r13
 128acef:	41 5e                	pop    %r14
 128acf1:	41 5f                	pop    %r15
 128acf3:	5d                   	pop    %rbp
 128acf4:	c3                   	ret    
 128acf5:	48 8b 5d b8          	mov    -0x48(%rbp),%rbx
 128acf9:	e9 e3 fb ff ff       	jmp    128a8e1 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xff1>
 128acfe:	48 85 db             	test   %rbx,%rbx
 128ad01:	74 24                	je     128ad27 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1437>
 128ad03:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128ad07:	48 8b 38             	mov    (%rax),%rdi
 128ad0a:	48 8b 40 08          	mov    0x8(%rax),%rax
 128ad0e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128ad12:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 128ad16:	48 89 da             	mov    %rbx,%rdx
 128ad19:	31 c9                	xor    %ecx,%ecx
 128ad1b:	ff 50 18             	call   *0x18(%rax)
 128ad1e:	48 8b 5d b8          	mov    -0x48(%rbp),%rbx
 128ad22:	e9 bf fb ff ff       	jmp    128a8e6 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xff6>
 128ad27:	48 89 d3             	mov    %rdx,%rbx
 128ad2a:	e9 b7 fb ff ff       	jmp    128a8e6 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0xff6>
 128ad2f:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 128ad33:	48 85 d2             	test   %rdx,%rdx
 128ad36:	74 18                	je     128ad50 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1460>
 128ad38:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128ad3c:	48 8b 38             	mov    (%rax),%rdi
 128ad3f:	48 8b 40 08          	mov    0x8(%rax),%rax
 128ad43:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128ad47:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 128ad4b:	31 c9                	xor    %ecx,%ecx
 128ad4d:	ff 50 18             	call   *0x18(%rax)
 128ad50:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 128ad54:	48 85 c9             	test   %rcx,%rcx
 128ad57:	48 8b 5d a0          	mov    -0x60(%rbp),%rbx
 128ad5b:	74 22                	je     128ad7f <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x148f>
 128ad5d:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128ad61:	48 8b 38             	mov    (%rax),%rdi
 128ad64:	48 8b 40 08          	mov    0x8(%rax),%rax
 128ad68:	48 c1 e1 05          	shl    $0x5,%rcx
 128ad6c:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128ad70:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128ad74:	4c 89 ee             	mov    %r13,%rsi
 128ad77:	b9 03 00 00 00       	mov    $0x3,%ecx
 128ad7c:	ff 50 18             	call   *0x18(%rax)
 128ad7f:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 128ad83:	48 85 c9             	test   %rcx,%rcx
 128ad86:	74 25                	je     128adad <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x14bd>
 128ad88:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128ad8c:	48 8b 38             	mov    (%rax),%rdi
 128ad8f:	48 8b 40 08          	mov    0x8(%rax),%rax
 128ad93:	48 01 c9             	add    %rcx,%rcx
 128ad96:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128ad9a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128ad9e:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 128ada5:	b9 01 00 00 00       	mov    $0x1,%ecx
 128adaa:	ff 50 18             	call   *0x18(%rax)
 128adad:	66 44 89 73 10       	mov    %r14w,0x10(%rbx)
 128adb2:	e9 2c ff ff ff       	jmp    128ace3 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x13f3>
 128adb7:	4d 85 f6             	test   %r14,%r14
 128adba:	74 22                	je     128adde <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x14ee>
 128adbc:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128adc0:	48 8b 38             	mov    (%rax),%rdi
 128adc3:	48 8b 40 08          	mov    0x8(%rax),%rax
 128adc7:	49 c1 e6 05          	shl    $0x5,%r14
 128adcb:	4b 8d 14 76          	lea    (%r14,%r14,2),%rdx
 128adcf:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128add3:	4c 89 ee             	mov    %r13,%rsi
 128add6:	b9 03 00 00 00       	mov    $0x3,%ecx
 128addb:	ff 50 18             	call   *0x18(%rax)
 128adde:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 128ade2:	48 85 d2             	test   %rdx,%rdx
 128ade5:	48 8b 5d a0          	mov    -0x60(%rbp),%rbx
 128ade9:	74 18                	je     128ae03 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1513>
 128adeb:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128adef:	48 8b 38             	mov    (%rax),%rdi
 128adf2:	48 8b 40 08          	mov    0x8(%rax),%rax
 128adf6:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128adfa:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 128adfe:	31 c9                	xor    %ecx,%ecx
 128ae00:	ff 50 18             	call   *0x18(%rax)
 128ae03:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 128ae07:	48 85 c9             	test   %rcx,%rcx
 128ae0a:	48 8b b5 58 ff ff ff 	mov    -0xa8(%rbp),%rsi
 128ae11:	74 1f                	je     128ae32 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1542>
 128ae13:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128ae17:	48 8b 38             	mov    (%rax),%rdi
 128ae1a:	48 8b 40 08          	mov    0x8(%rax),%rax
 128ae1e:	48 c1 e1 05          	shl    $0x5,%rcx
 128ae22:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128ae26:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128ae2a:	b9 03 00 00 00       	mov    $0x3,%ecx
 128ae2f:	ff 50 18             	call   *0x18(%rax)
 128ae32:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 128ae36:	48 85 c9             	test   %rcx,%rcx
 128ae39:	74 25                	je     128ae60 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1570>
 128ae3b:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128ae3f:	48 8b 38             	mov    (%rax),%rdi
 128ae42:	48 8b 40 08          	mov    0x8(%rax),%rax
 128ae46:	48 01 c9             	add    %rcx,%rcx
 128ae49:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128ae4d:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128ae51:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 128ae58:	b9 01 00 00 00       	mov    $0x1,%ecx
 128ae5d:	ff 50 18             	call   *0x18(%rax)
 128ae60:	66 44 89 7b 10       	mov    %r15w,0x10(%rbx)
 128ae65:	e9 79 fe ff ff       	jmp    128ace3 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x13f3>
 128ae6a:	66 89 43 10          	mov    %ax,0x10(%rbx)
 128ae6e:	e9 70 fe ff ff       	jmp    128ace3 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x13f3>
 128ae73:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 128ae77:	48 85 c9             	test   %rcx,%rcx
 128ae7a:	74 22                	je     128ae9e <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x15ae>
 128ae7c:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128ae80:	48 8b 38             	mov    (%rax),%rdi
 128ae83:	48 8b 40 08          	mov    0x8(%rax),%rax
 128ae87:	48 c1 e1 05          	shl    $0x5,%rcx
 128ae8b:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128ae8f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128ae93:	4c 89 ee             	mov    %r13,%rsi
 128ae96:	b9 03 00 00 00       	mov    $0x3,%ecx
 128ae9b:	ff 50 18             	call   *0x18(%rax)
 128ae9e:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 128aea2:	48 85 c9             	test   %rcx,%rcx
 128aea5:	74 25                	je     128aecc <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x15dc>
 128aea7:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128aeab:	48 8b 38             	mov    (%rax),%rdi
 128aeae:	48 8b 40 08          	mov    0x8(%rax),%rax
 128aeb2:	48 01 c9             	add    %rcx,%rcx
 128aeb5:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128aeb9:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128aebd:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 128aec4:	b9 01 00 00 00       	mov    $0x1,%ecx
 128aec9:	ff 50 18             	call   *0x18(%rax)
 128aecc:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 128aed0:	48 85 f6             	test   %rsi,%rsi
 128aed3:	0f 94 c0             	sete   %al
 128aed6:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 128aeda:	48 85 d2             	test   %rdx,%rdx
 128aedd:	0f 94 c1             	sete   %cl
 128aee0:	08 c1                	or     %al,%cl
 128aee2:	0f 85 e5 01 00 00    	jne    128b0cd <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x17dd>
 128aee8:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128aeec:	48 8b 38             	mov    (%rax),%rdi
 128aeef:	48 8b 40 08          	mov    0x8(%rax),%rax
 128aef3:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128aef7:	e9 cc 01 00 00       	jmp    128b0c8 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x17d8>
 128aefc:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 128af00:	48 85 d2             	test   %rdx,%rdx
 128af03:	75 0a                	jne    128af0f <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x161f>
 128af05:	eb 20                	jmp    128af27 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1637>
 128af07:	4d 85 f6             	test   %r14,%r14
 128af0a:	74 1b                	je     128af27 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1637>
 128af0c:	4c 89 f2             	mov    %r14,%rdx
 128af0f:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128af13:	48 8b 38             	mov    (%rax),%rdi
 128af16:	48 8b 40 08          	mov    0x8(%rax),%rax
 128af1a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128af1e:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 128af22:	31 c9                	xor    %ecx,%ecx
 128af24:	ff 50 18             	call   *0x18(%rax)
 128af27:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 128af2b:	48 85 c9             	test   %rcx,%rcx
 128af2e:	74 22                	je     128af52 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1662>
 128af30:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128af34:	48 8b 38             	mov    (%rax),%rdi
 128af37:	48 8b 40 08          	mov    0x8(%rax),%rax
 128af3b:	48 c1 e1 05          	shl    $0x5,%rcx
 128af3f:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128af43:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128af47:	4c 89 ee             	mov    %r13,%rsi
 128af4a:	b9 03 00 00 00       	mov    $0x3,%ecx
 128af4f:	ff 50 18             	call   *0x18(%rax)
 128af52:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 128af56:	48 85 c9             	test   %rcx,%rcx
 128af59:	0f 84 6e 01 00 00    	je     128b0cd <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x17dd>
 128af5f:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128af63:	48 8b 38             	mov    (%rax),%rdi
 128af66:	48 8b 40 08          	mov    0x8(%rax),%rax
 128af6a:	48 01 c9             	add    %rcx,%rcx
 128af6d:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128af71:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128af75:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 128af7c:	b9 01 00 00 00       	mov    $0x1,%ecx
 128af81:	e9 44 01 00 00       	jmp    128b0ca <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x17da>
 128af86:	45 31 ff             	xor    %r15d,%r15d
 128af89:	41 bc 00 00 00 00    	mov    $0x0,%r12d
 128af8f:	41 83 fe 1f          	cmp    $0x1f,%r14d
 128af93:	0f 84 1d fb ff ff    	je     128aab6 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x11c6>
 128af99:	48 85 db             	test   %rbx,%rbx
 128af9c:	74 1b                	je     128afb9 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x16c9>
 128af9e:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128afa2:	48 8b 38             	mov    (%rax),%rdi
 128afa5:	48 8b 40 08          	mov    0x8(%rax),%rax
 128afa9:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128afad:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 128afb1:	48 89 da             	mov    %rbx,%rdx
 128afb4:	31 c9                	xor    %ecx,%ecx
 128afb6:	ff 50 18             	call   *0x18(%rax)
 128afb9:	48 83 7d b0 00       	cmpq   $0x0,-0x50(%rbp)
 128afbe:	74 26                	je     128afe6 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x16f6>
 128afc0:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128afc4:	48 8b 38             	mov    (%rax),%rdi
 128afc7:	48 8b 40 08          	mov    0x8(%rax),%rax
 128afcb:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 128afcf:	48 c1 e1 05          	shl    $0x5,%rcx
 128afd3:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128afd7:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128afdb:	4c 89 ee             	mov    %r13,%rsi
 128afde:	b9 03 00 00 00       	mov    $0x3,%ecx
 128afe3:	ff 50 18             	call   *0x18(%rax)
 128afe6:	48 83 7d 98 00       	cmpq   $0x0,-0x68(%rbp)
 128afeb:	74 29                	je     128b016 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1726>
 128afed:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128aff1:	48 8b 38             	mov    (%rax),%rdi
 128aff4:	48 8b 40 08          	mov    0x8(%rax),%rax
 128aff8:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 128affc:	48 01 c9             	add    %rcx,%rcx
 128afff:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128b003:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b007:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 128b00e:	b9 01 00 00 00       	mov    $0x1,%ecx
 128b013:	ff 50 18             	call   *0x18(%rax)
 128b016:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 128b01a:	66 44 89 70 10       	mov    %r14w,0x10(%rax)
 128b01f:	e9 bf fc ff ff       	jmp    128ace3 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x13f3>
 128b024:	48 83 7d c8 00       	cmpq   $0x0,-0x38(%rbp)
 128b029:	0f 94 c0             	sete   %al
 128b02c:	48 83 7d b8 00       	cmpq   $0x0,-0x48(%rbp)
 128b031:	0f 94 c1             	sete   %cl
 128b034:	08 c1                	or     %al,%cl
 128b036:	80 f9 01             	cmp    $0x1,%cl
 128b039:	75 76                	jne    128b0b1 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x17c1>
 128b03b:	e9 8d 00 00 00       	jmp    128b0cd <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x17dd>
 128b040:	48 83 7d b0 00       	cmpq   $0x0,-0x50(%rbp)
 128b045:	74 26                	je     128b06d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x177d>
 128b047:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b04b:	48 8b 38             	mov    (%rax),%rdi
 128b04e:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b052:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 128b056:	48 c1 e1 05          	shl    $0x5,%rcx
 128b05a:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128b05e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b062:	4c 89 ee             	mov    %r13,%rsi
 128b065:	b9 03 00 00 00       	mov    $0x3,%ecx
 128b06a:	ff 50 18             	call   *0x18(%rax)
 128b06d:	48 83 7d 98 00       	cmpq   $0x0,-0x68(%rbp)
 128b072:	74 29                	je     128b09d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x17ad>
 128b074:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b078:	48 8b 38             	mov    (%rax),%rdi
 128b07b:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b07f:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 128b083:	48 01 c9             	add    %rcx,%rcx
 128b086:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128b08a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b08e:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 128b095:	b9 01 00 00 00       	mov    $0x1,%ecx
 128b09a:	ff 50 18             	call   *0x18(%rax)
 128b09d:	48 83 7d c8 00       	cmpq   $0x0,-0x38(%rbp)
 128b0a2:	0f 94 c0             	sete   %al
 128b0a5:	48 83 7d b8 00       	cmpq   $0x0,-0x48(%rbp)
 128b0aa:	0f 94 c1             	sete   %cl
 128b0ad:	08 c1                	or     %al,%cl
 128b0af:	75 1c                	jne    128b0cd <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x17dd>
 128b0b1:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b0b5:	48 8b 38             	mov    (%rax),%rdi
 128b0b8:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b0bc:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b0c0:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 128b0c4:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 128b0c8:	31 c9                	xor    %ecx,%ecx
 128b0ca:	ff 50 18             	call   *0x18(%rax)
 128b0cd:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 128b0d1:	66 89 58 10          	mov    %bx,0x10(%rax)
 128b0d5:	e9 09 fc ff ff       	jmp    128ace3 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x13f3>
 128b0da:	48 83 7d b8 00       	cmpq   $0x0,-0x48(%rbp)
 128b0df:	74 41                	je     128b122 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1832>
 128b0e1:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b0e5:	48 8b 38             	mov    (%rax),%rdi
 128b0e8:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b0ec:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b0f0:	4c 89 fe             	mov    %r15,%rsi
 128b0f3:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 128b0f7:	eb 24                	jmp    128b11d <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x182d>
 128b0f9:	89 c3                	mov    %eax,%ebx
 128b0fb:	48 8b 95 68 ff ff ff 	mov    -0x98(%rbp),%rdx
 128b102:	48 85 d2             	test   %rdx,%rdx
 128b105:	74 1b                	je     128b122 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x1832>
 128b107:	48 8b b5 60 ff ff ff 	mov    -0xa0(%rbp),%rsi
 128b10e:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b112:	48 8b 38             	mov    (%rax),%rdi
 128b115:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b119:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b11d:	31 c9                	xor    %ecx,%ecx
 128b11f:	ff 50 18             	call   *0x18(%rax)
 128b122:	48 83 7d b0 00       	cmpq   $0x0,-0x50(%rbp)
 128b127:	74 26                	je     128b14f <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x185f>
 128b129:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b12d:	48 8b 38             	mov    (%rax),%rdi
 128b130:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b134:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 128b138:	48 c1 e1 05          	shl    $0x5,%rcx
 128b13c:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128b140:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b144:	4c 89 ee             	mov    %r13,%rsi
 128b147:	b9 03 00 00 00       	mov    $0x3,%ecx
 128b14c:	ff 50 18             	call   *0x18(%rax)
 128b14f:	48 83 7d 98 00       	cmpq   $0x0,-0x68(%rbp)
 128b154:	0f 84 73 ff ff ff    	je     128b0cd <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x17dd>
 128b15a:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b15e:	48 8b 38             	mov    (%rax),%rdi
 128b161:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b165:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 128b169:	e9 fc fd ff ff       	jmp    128af6a <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_253589+0x167a>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
