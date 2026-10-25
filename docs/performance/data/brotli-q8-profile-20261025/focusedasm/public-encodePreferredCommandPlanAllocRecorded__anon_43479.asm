
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/d54ab236499589e8c9225c90450b9b10/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000120fcd0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479>:
 120fcd0:	55                   	push   %rbp
 120fcd1:	48 89 e5             	mov    %rsp,%rbp
 120fcd4:	41 57                	push   %r15
 120fcd6:	41 56                	push   %r14
 120fcd8:	41 55                	push   %r13
 120fcda:	41 54                	push   %r12
 120fcdc:	53                   	push   %rbx
 120fcdd:	48 83 e4 e0          	and    $0xffffffffffffffe0,%rsp
 120fce1:	48 81 ec c0 10 00 00 	sub    $0x10c0,%rsp
 120fce8:	4c 89 84 24 b0 00 00 	mov    %r8,0xb0(%rsp)
 120fcef:	00 
 120fcf0:	48 89 8c 24 a8 00 00 	mov    %rcx,0xa8(%rsp)
 120fcf7:	00 
 120fcf8:	48 89 94 24 c8 00 00 	mov    %rdx,0xc8(%rsp)
 120fcff:	00 
 120fd00:	48 89 74 24 48       	mov    %rsi,0x48(%rsp)
 120fd05:	48 89 7c 24 50       	mov    %rdi,0x50(%rsp)
 120fd0a:	48 8b 45 18          	mov    0x18(%rbp),%rax
 120fd0e:	48 8b 08             	mov    (%rax),%rcx
 120fd11:	48 89 8c 24 f0 00 00 	mov    %rcx,0xf0(%rsp)
 120fd18:	00 
 120fd19:	48 8b 48 08          	mov    0x8(%rax),%rcx
 120fd1d:	48 89 8c 24 e8 00 00 	mov    %rcx,0xe8(%rsp)
 120fd24:	00 
 120fd25:	48 8b 48 10          	mov    0x10(%rax),%rcx
 120fd29:	48 89 8c 24 e0 00 00 	mov    %rcx,0xe0(%rsp)
 120fd30:	00 
 120fd31:	48 8b 48 18          	mov    0x18(%rax),%rcx
 120fd35:	48 89 8c 24 d8 00 00 	mov    %rcx,0xd8(%rsp)
 120fd3c:	00 
 120fd3d:	c5 fe 6f 40 20       	vmovdqu 0x20(%rax),%ymm0
 120fd42:	c5 fe 7f 84 24 f0 03 	vmovdqu %ymm0,0x3f0(%rsp)
 120fd49:	00 00 
 120fd4b:	0f b6 50 40          	movzbl 0x40(%rax),%edx
 120fd4f:	88 54 24 20          	mov    %dl,0x20(%rsp)
 120fd53:	44 0f b6 40 41       	movzbl 0x41(%rax),%r8d
 120fd58:	44 0f b6 50 42       	movzbl 0x42(%rax),%r10d
 120fd5d:	44 0f b6 58 43       	movzbl 0x43(%rax),%r11d
 120fd62:	0f b6 48 44          	movzbl 0x44(%rax),%ecx
 120fd66:	88 8c 24 80 01 00 00 	mov    %cl,0x180(%rsp)
 120fd6d:	0f b6 70 46          	movzbl 0x46(%rax),%esi
 120fd71:	0f b6 78 47          	movzbl 0x47(%rax),%edi
 120fd75:	0f b6 48 4e          	movzbl 0x4e(%rax),%ecx
 120fd79:	41 f6 c0 01          	test   $0x1,%r8b
 120fd7d:	4c 89 8c 24 d0 00 00 	mov    %r9,0xd0(%rsp)
 120fd84:	00 
 120fd85:	88 4c 24 1f          	mov    %cl,0x1f(%rsp)
 120fd89:	0f 84 bd 01 00 00    	je     120ff4c <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x27c>
 120fd8f:	48 83 c0 20          	add    $0x20,%rax
 120fd93:	c5 fe 6f 00          	vmovdqu (%rax),%ymm0
 120fd97:	c5 fe 7f 84 24 20 01 	vmovdqu %ymm0,0x120(%rsp)
 120fd9e:	00 00 
 120fda0:	89 c8                	mov    %ecx,%eax
 120fda2:	24 1f                	and    $0x1f,%al
 120fda4:	88 44 24 47          	mov    %al,0x47(%rsp)
 120fda8:	4d 85 c9             	test   %r9,%r9
 120fdab:	0f 84 9b 01 00 00    	je     120ff4c <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x27c>
 120fdb1:	44 88 9c 24 00 01 00 	mov    %r11b,0x100(%rsp)
 120fdb8:	00 
 120fdb9:	44 88 54 24 60       	mov    %r10b,0x60(%rsp)
 120fdbe:	44 88 44 24 68       	mov    %r8b,0x68(%rsp)
 120fdc3:	40 88 bc 24 88 00 00 	mov    %dil,0x88(%rsp)
 120fdca:	00 
 120fdcb:	40 88 b4 24 60 01 00 	mov    %sil,0x160(%rsp)
 120fdd2:	00 
 120fdd3:	88 54 24 38          	mov    %dl,0x38(%rsp)
 120fdd7:	0f b6 05 aa 2d e0 ff 	movzbl -0x1fd256(%rip),%eax        # 1012b88 <__anon_35632>
 120fdde:	48 8b 9c 24 28 01 00 	mov    0x128(%rsp),%rbx
 120fde5:	00 
 120fde6:	4c 8b bc 24 30 01 00 	mov    0x130(%rsp),%r15
 120fded:	00 
 120fdee:	4c 8b a4 24 38 01 00 	mov    0x138(%rsp),%r12
 120fdf5:	00 
 120fdf6:	31 f6                	xor    %esi,%esi
 120fdf8:	0f b6 4c 24 47       	movzbl 0x47(%rsp),%ecx
 120fdfd:	89 4c 24 28          	mov    %ecx,0x28(%rsp)
 120fe01:	24 0f                	and    $0xf,%al
 120fe03:	88 44 24 1e          	mov    %al,0x1e(%rsp)
 120fe07:	4c 8b ac 24 b0 00 00 	mov    0xb0(%rsp),%r13
 120fe0e:	00 
 120fe0f:	4d 89 ce             	mov    %r9,%r14
 120fe12:	eb 2b                	jmp    120fe3f <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x16f>
 120fe14:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 120fe1b:	00 00 00 00 00 
 120fe20:	4c 89 e1             	mov    %r12,%rcx
 120fe23:	4d 89 fc             	mov    %r15,%r12
 120fe26:	49 89 df             	mov    %rbx,%r15
 120fe29:	4c 89 fb             	mov    %r15,%rbx
 120fe2c:	4d 89 e7             	mov    %r12,%r15
 120fe2f:	49 83 c5 60          	add    $0x60,%r13
 120fe33:	49 89 cc             	mov    %rcx,%r12
 120fe36:	49 ff ce             	dec    %r14
 120fe39:	0f 84 17 01 00 00    	je     120ff56 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x286>
 120fe3f:	c4 c1 7e 6f 45 00    	vmovdqu 0x0(%r13),%ymm0
 120fe45:	c4 c1 7c 10 4d 20    	vmovups 0x20(%r13),%ymm1
 120fe4b:	c4 c1 7c 10 55 40    	vmovups 0x40(%r13),%ymm2
 120fe51:	c5 fc 11 94 24 00 02 	vmovups %ymm2,0x200(%rsp)
 120fe58:	00 00 
 120fe5a:	c5 fc 11 8c 24 e0 01 	vmovups %ymm1,0x1e0(%rsp)
 120fe61:	00 00 
 120fe63:	c5 fe 7f 84 24 c0 01 	vmovdqu %ymm0,0x1c0(%rsp)
 120fe6a:	00 00 
 120fe6c:	f6 84 24 18 02 00 00 	testb  $0x1,0x218(%rsp)
 120fe73:	01 
 120fe74:	74 aa                	je     120fe20 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x150>
 120fe76:	0f b6 84 24 19 02 00 	movzbl 0x219(%rsp),%eax
 120fe7d:	00 
 120fe7e:	24 03                	and    $0x3,%al
 120fe80:	3c 02                	cmp    $0x2,%al
 120fe82:	74 9c                	je     120fe20 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x150>
 120fe84:	48 89 b4 24 90 00 00 	mov    %rsi,0x90(%rsp)
 120fe8b:	00 
 120fe8c:	48 8d bc 24 b0 01 00 	lea    0x1b0(%rsp),%rdi
 120fe93:	00 
 120fe94:	48 8d b4 24 c0 01 00 	lea    0x1c0(%rsp),%rsi
 120fe9b:	00 
 120fe9c:	8b 54 24 28          	mov    0x28(%rsp),%edx
 120fea0:	48 8b 8c 24 e0 00 00 	mov    0xe0(%rsp),%rcx
 120fea7:	00 
 120fea8:	4c 8b 84 24 d8 00 00 	mov    0xd8(%rsp),%r8
 120feaf:	00 
 120feb0:	c5 f8 77             	vzeroupper 
 120feb3:	e8 68 f5 fa ff       	call   11bf420 <br.commandWireDistance>
 120feb8:	0f b7 84 24 b8 01 00 	movzwl 0x1b8(%rsp),%eax
 120febf:	00 
 120fec0:	66 85 c0             	test   %ax,%ax
 120fec3:	0f 85 a0 16 00 00    	jne    1211569 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1899>
 120fec9:	48 8b b4 24 b0 01 00 	mov    0x1b0(%rsp),%rsi
 120fed0:	00 
 120fed1:	48 8d 7c 24 5e       	lea    0x5e(%rsp),%rdi
 120fed6:	48 89 74 24 78       	mov    %rsi,0x78(%rsp)
 120fedb:	48 8d 94 24 20 01 00 	lea    0x120(%rsp),%rdx
 120fee2:	00 
 120fee3:	e8 08 ef fa ff       	call   11bedf0 <br.decoder.distance_history.symbolForDistance>
 120fee8:	0f b6 4c 24 5f       	movzbl 0x5f(%rsp),%ecx
 120feed:	48 8b b4 24 90 00 00 	mov    0x90(%rsp),%rsi
 120fef4:	00 
 120fef5:	48 8d 46 01          	lea    0x1(%rsi),%rax
 120fef9:	84 c9                	test   %cl,%cl
 120fefb:	74 1f                	je     120ff1c <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x24c>
 120fefd:	0f b6 54 24 5e       	movzbl 0x5e(%rsp),%edx
 120ff02:	80 e2 0f             	and    $0xf,%dl
 120ff05:	3a 54 24 1e          	cmp    0x1e(%rsp),%dl
 120ff09:	75 11                	jne    120ff1c <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x24c>
 120ff0b:	4c 89 e1             	mov    %r12,%rcx
 120ff0e:	4d 89 fc             	mov    %r15,%r12
 120ff11:	49 89 df             	mov    %rbx,%r15
 120ff14:	48 89 c6             	mov    %rax,%rsi
 120ff17:	e9 0d ff ff ff       	jmp    120fe29 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x159>
 120ff1c:	84 c9                	test   %cl,%cl
 120ff1e:	48 0f 45 f0          	cmovne %rax,%rsi
 120ff22:	48 89 9c 24 20 01 00 	mov    %rbx,0x120(%rsp)
 120ff29:	00 
 120ff2a:	4c 89 bc 24 28 01 00 	mov    %r15,0x128(%rsp)
 120ff31:	00 
 120ff32:	4c 89 a4 24 30 01 00 	mov    %r12,0x130(%rsp)
 120ff39:	00 
 120ff3a:	48 8b 4c 24 78       	mov    0x78(%rsp),%rcx
 120ff3f:	48 89 8c 24 38 01 00 	mov    %rcx,0x138(%rsp)
 120ff46:	00 
 120ff47:	e9 dd fe ff ff       	jmp    120fe29 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x159>
 120ff4c:	c7 44 24 40 00 00 00 	movl   $0x0,0x40(%rsp)
 120ff53:	00 
 120ff54:	eb 35                	jmp    120ff8b <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x2bb>
 120ff56:	48 83 fe 40          	cmp    $0x40,%rsi
 120ff5a:	0f 93 c0             	setae  %al
 120ff5d:	89 44 24 40          	mov    %eax,0x40(%rsp)
 120ff61:	0f b6 54 24 38       	movzbl 0x38(%rsp),%edx
 120ff66:	0f b6 b4 24 60 01 00 	movzbl 0x160(%rsp),%esi
 120ff6d:	00 
 120ff6e:	0f b6 bc 24 88 00 00 	movzbl 0x88(%rsp),%edi
 120ff75:	00 
 120ff76:	44 0f b6 44 24 68    	movzbl 0x68(%rsp),%r8d
 120ff7c:	44 0f b6 54 24 60    	movzbl 0x60(%rsp),%r10d
 120ff82:	44 0f b6 9c 24 00 01 	movzbl 0x100(%rsp),%r11d
 120ff89:	00 00 
 120ff8b:	45 84 db             	test   %r11b,%r11b
 120ff8e:	0f 95 c0             	setne  %al
 120ff91:	41 0f b6 ca          	movzbl %r10b,%ecx
 120ff95:	41 0f b6 d8          	movzbl %r8b,%ebx
 120ff99:	0f 45 d9             	cmovne %ecx,%ebx
 120ff9c:	20 c1                	and    %al,%cl
 120ff9e:	89 8c 24 f8 00 00 00 	mov    %ecx,0xf8(%rsp)
 120ffa5:	75 21                	jne    120ffc8 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x2f8>
 120ffa7:	80 7c 24 40 00       	cmpb   $0x0,0x40(%rsp)
 120ffac:	75 1a                	jne    120ffc8 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x2f8>
 120ffae:	4c 8d 3d 7b 23 e0 ff 	lea    -0x1fdc85(%rip),%r15        # 1012330 <__anon_35262>
 120ffb5:	4c 8d 2d 7d 23 e0 ff 	lea    -0x1fdc83(%rip),%r13        # 1012339 <__anon_35262+0x9>
 120ffbc:	4c 8d 25 be 23 e0 ff 	lea    -0x1fdc42(%rip),%r12        # 1012381 <__anon_35262+0x51>
 120ffc3:	e9 d6 00 00 00       	jmp    121009e <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x3ce>
 120ffc8:	4c 8d a4 24 f9 04 00 	lea    0x4f9(%rsp),%r12
 120ffcf:	00 
 120ffd0:	4c 8d ac 24 b1 04 00 	lea    0x4b1(%rsp),%r13
 120ffd7:	00 
 120ffd8:	31 c0                	xor    %eax,%eax
 120ffda:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 120ffe0:	48 83 f8 38          	cmp    $0x38,%rax
 120ffe4:	0f 93 84 04 c0 01 00 	setae  0x1c0(%rsp,%rax,1)
 120ffeb:	00 
 120ffec:	0f 93 84 04 c1 01 00 	setae  0x1c1(%rsp,%rax,1)
 120fff3:	00 
 120fff4:	0f 93 84 04 c2 01 00 	setae  0x1c2(%rsp,%rax,1)
 120fffb:	00 
 120fffc:	0f 93 84 04 c3 01 00 	setae  0x1c3(%rsp,%rax,1)
 1210003:	00 
 1210004:	0f 93 84 04 c4 01 00 	setae  0x1c4(%rsp,%rax,1)
 121000b:	00 
 121000c:	0f 93 84 04 c5 01 00 	setae  0x1c5(%rsp,%rax,1)
 1210013:	00 
 1210014:	0f 93 84 04 c6 01 00 	setae  0x1c6(%rsp,%rax,1)
 121001b:	00 
 121001c:	0f 93 84 04 c7 01 00 	setae  0x1c7(%rsp,%rax,1)
 1210023:	00 
 1210024:	48 83 c0 08          	add    $0x8,%rax
 1210028:	48 83 f8 40          	cmp    $0x40,%rax
 121002c:	75 b2                	jne    120ffe0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x310>
 121002e:	40 84 ff             	test   %dil,%dil
 1210031:	40 0f b6 c6          	movzbl %sil,%eax
 1210035:	b9 02 00 00 00       	mov    $0x2,%ecx
 121003a:	0f 45 c8             	cmovne %eax,%ecx
 121003d:	80 e1 03             	and    $0x3,%cl
 1210040:	88 8c 24 98 00 00 00 	mov    %cl,0x98(%rsp)
 1210047:	c5 fe 6f 84 24 c0 01 	vmovdqu 0x1c0(%rsp),%ymm0
 121004e:	00 00 
 1210050:	c5 fc 10 8c 24 e0 01 	vmovups 0x1e0(%rsp),%ymm1
 1210057:	00 00 
 1210059:	c5 fe 7f 84 24 b2 04 	vmovdqu %ymm0,0x4b2(%rsp)
 1210060:	00 00 
 1210062:	c5 fc 11 8c 24 d2 04 	vmovups %ymm1,0x4d2(%rsp)
 1210069:	00 00 
 121006b:	c6 84 24 a5 00 00 00 	movb   $0x2,0xa5(%rsp)
 1210072:	02 
 1210073:	48 c7 84 24 a8 04 00 	movq   $0x0,0x4a8(%rsp)
 121007a:	00 00 00 00 00 
 121007f:	88 8c 24 b0 04 00 00 	mov    %cl,0x4b0(%rsp)
 1210086:	c6 84 24 b1 04 00 00 	movb   $0x2,0x4b1(%rsp)
 121008d:	02 
 121008e:	c6 84 24 f8 04 00 00 	movb   $0x1,0x4f8(%rsp)
 1210095:	01 
 1210096:	4c 8d bc 24 a8 04 00 	lea    0x4a8(%rsp),%r15
 121009d:	00 
 121009e:	c5 fc 10 84 24 f0 03 	vmovups 0x3f0(%rsp),%ymm0
 12100a5:	00 00 
 12100a7:	c5 fc 11 84 24 28 07 	vmovups %ymm0,0x728(%rsp)
 12100ae:	00 00 
 12100b0:	80 e2 01             	and    $0x1,%dl
 12100b3:	88 94 24 29 09 00 00 	mov    %dl,0x929(%rsp)
 12100ba:	48 c7 84 24 18 07 00 	movq   $0x0,0x718(%rsp)
 12100c1:	00 00 00 00 00 
 12100c6:	8b 44 24 40          	mov    0x40(%rsp),%eax
 12100ca:	88 84 24 2d 09 00 00 	mov    %al,0x92d(%rsp)
 12100d1:	c6 84 24 2c 09 00 00 	movb   $0x0,0x92c(%rsp)
 12100d8:	00 
 12100d9:	c4 c1 7c 10 07       	vmovups (%r15),%ymm0
 12100de:	c4 c1 7c 10 4f 20    	vmovups 0x20(%r15),%ymm1
 12100e4:	c5 fc 11 84 24 48 07 	vmovups %ymm0,0x748(%rsp)
 12100eb:	00 00 
 12100ed:	c5 fc 11 8c 24 68 07 	vmovups %ymm1,0x768(%rsp)
 12100f4:	00 00 
 12100f6:	c4 c1 7c 10 47 38    	vmovups 0x38(%r15),%ymm0
 12100fc:	c5 fc 11 84 24 80 07 	vmovups %ymm0,0x780(%rsp)
 1210103:	00 00 
 1210105:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1210109:	c5 fc 11 84 24 f0 08 	vmovups %ymm0,0x8f0(%rsp)
 1210110:	00 00 
 1210112:	c5 fc 11 84 24 e0 08 	vmovups %ymm0,0x8e0(%rsp)
 1210119:	00 00 
 121011b:	c5 fc 11 84 24 c0 08 	vmovups %ymm0,0x8c0(%rsp)
 1210122:	00 00 
 1210124:	c5 fc 11 84 24 a0 08 	vmovups %ymm0,0x8a0(%rsp)
 121012b:	00 00 
 121012d:	c5 fc 11 84 24 80 08 	vmovups %ymm0,0x880(%rsp)
 1210134:	00 00 
 1210136:	c5 fc 11 84 24 60 08 	vmovups %ymm0,0x860(%rsp)
 121013d:	00 00 
 121013f:	c5 fc 11 84 24 40 08 	vmovups %ymm0,0x840(%rsp)
 1210146:	00 00 
 1210148:	c5 fc 11 84 24 20 08 	vmovups %ymm0,0x820(%rsp)
 121014f:	00 00 
 1210151:	c5 fc 11 84 24 00 08 	vmovups %ymm0,0x800(%rsp)
 1210158:	00 00 
 121015a:	c5 fc 11 84 24 e0 07 	vmovups %ymm0,0x7e0(%rsp)
 1210161:	00 00 
 1210163:	c5 fc 11 84 24 c0 07 	vmovups %ymm0,0x7c0(%rsp)
 121016a:	00 00 
 121016c:	c5 fc 11 84 24 a0 07 	vmovups %ymm0,0x7a0(%rsp)
 1210173:	00 00 
 1210175:	c6 84 24 20 09 00 00 	movb   $0x38,0x920(%rsp)
 121017c:	38 
 121017d:	c6 84 24 28 09 00 00 	movb   $0x0,0x928(%rsp)
 1210184:	00 
 1210185:	0f b7 05 bc ad e2 ff 	movzwl -0x1d5244(%rip),%eax        # 103af48 <__anon_35281>
 121018c:	66 89 84 24 22 09 00 	mov    %ax,0x922(%rsp)
 1210193:	00 
 1210194:	0f b6 44 24 1f       	movzbl 0x1f(%rsp),%eax
 1210199:	24 1f                	and    $0x1f,%al
 121019b:	88 44 24 1f          	mov    %al,0x1f(%rsp)
 121019f:	88 84 24 21 09 00 00 	mov    %al,0x921(%rsp)
 12101a6:	48 8b 84 24 f0 00 00 	mov    0xf0(%rsp),%rax
 12101ad:	00 
 12101ae:	48 89 84 24 08 07 00 	mov    %rax,0x708(%rsp)
 12101b5:	00 
 12101b6:	48 8b 84 24 e8 00 00 	mov    0xe8(%rsp),%rax
 12101bd:	00 
 12101be:	48 89 84 24 10 07 00 	mov    %rax,0x710(%rsp)
 12101c5:	00 
 12101c6:	c7 84 24 24 09 00 00 	movl   $0x1000101,0x924(%rsp)
 12101cd:	01 01 00 01 
 12101d1:	48 8b 84 24 e0 00 00 	mov    0xe0(%rsp),%rax
 12101d8:	00 
 12101d9:	48 89 84 24 18 09 00 	mov    %rax,0x918(%rsp)
 12101e0:	00 
 12101e1:	48 8b 84 24 d8 00 00 	mov    0xd8(%rsp),%rax
 12101e8:	00 
 12101e9:	48 89 84 24 10 09 00 	mov    %rax,0x910(%rsp)
 12101f0:	00 
 12101f1:	66 c7 84 24 2a 09 00 	movw   $0x0,0x92a(%rsp)
 12101f8:	00 00 00 
 12101fb:	48 c7 84 24 20 07 00 	movq   $0x0,0x720(%rsp)
 1210202:	00 00 00 00 00 
 1210207:	48 8b 45 10          	mov    0x10(%rbp),%rax
 121020b:	c5 fc 10 40 70       	vmovups 0x70(%rax),%ymm0
 1210210:	c5 fc 11 84 24 80 04 	vmovups %ymm0,0x480(%rsp)
 1210217:	00 00 
 1210219:	c5 fc 10 00          	vmovups (%rax),%ymm0
 121021d:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 1210222:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 1210227:	c5 fc 10 58 60       	vmovups 0x60(%rax),%ymm3
 121022c:	c5 fc 11 9c 24 70 04 	vmovups %ymm3,0x470(%rsp)
 1210233:	00 00 
 1210235:	c5 fc 11 94 24 50 04 	vmovups %ymm2,0x450(%rsp)
 121023c:	00 00 
 121023e:	c5 fc 11 8c 24 30 04 	vmovups %ymm1,0x430(%rsp)
 1210245:	00 00 
 1210247:	c5 fc 11 84 24 10 04 	vmovups %ymm0,0x410(%rsp)
 121024e:	00 00 
 1210250:	c5 fc 10 00          	vmovups (%rax),%ymm0
 1210254:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 1210259:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 121025e:	c5 fc 10 58 60       	vmovups 0x60(%rax),%ymm3
 1210263:	c5 fc 11 84 24 50 05 	vmovups %ymm0,0x550(%rsp)
 121026a:	00 00 
 121026c:	c5 fc 11 8c 24 70 05 	vmovups %ymm1,0x570(%rsp)
 1210273:	00 00 
 1210275:	c5 fc 11 94 24 90 05 	vmovups %ymm2,0x590(%rsp)
 121027c:	00 00 
 121027e:	c5 fc 11 9c 24 b0 05 	vmovups %ymm3,0x5b0(%rsp)
 1210285:	00 00 
 1210287:	c5 fe 6f 40 70       	vmovdqu 0x70(%rax),%ymm0
 121028c:	c5 fe 7f 84 24 c0 05 	vmovdqu %ymm0,0x5c0(%rsp)
 1210293:	00 00 
 1210295:	48 8d 84 24 08 07 00 	lea    0x708(%rsp),%rax
 121029c:	00 
 121029d:	4c 8d 94 24 50 05 00 	lea    0x550(%rsp),%r10
 12102a4:	00 
 12102a5:	48 8d bc 24 a8 03 00 	lea    0x3a8(%rsp),%rdi
 12102ac:	00 
 12102ad:	48 8b 74 24 48       	mov    0x48(%rsp),%rsi
 12102b2:	48 8b 94 24 c8 00 00 	mov    0xc8(%rsp),%rdx
 12102b9:	00 
 12102ba:	48 8b 8c 24 a8 00 00 	mov    0xa8(%rsp),%rcx
 12102c1:	00 
 12102c2:	4c 8b 84 24 b0 00 00 	mov    0xb0(%rsp),%r8
 12102c9:	00 
 12102ca:	4c 8b 8c 24 d0 00 00 	mov    0xd0(%rsp),%r9
 12102d1:	00 
 12102d2:	50                   	push   %rax
 12102d3:	41 52                	push   %r10
 12102d5:	c5 f8 77             	vzeroupper 
 12102d8:	e8 23 47 f6 ff       	call   1174a00 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307>
 12102dd:	48 83 c4 10          	add    $0x10,%rsp
 12102e1:	0f b7 84 24 b8 03 00 	movzwl 0x3b8(%rsp),%eax
 12102e8:	00 
 12102e9:	66 85 c0             	test   %ax,%ax
 12102ec:	0f 85 77 12 00 00    	jne    1211569 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1899>
 12102f2:	48 8b 84 24 a8 03 00 	mov    0x3a8(%rsp),%rax
 12102f9:	00 
 12102fa:	48 89 44 24 60       	mov    %rax,0x60(%rsp)
 12102ff:	48 8b 84 24 b0 03 00 	mov    0x3b0(%rsp),%rax
 1210306:	00 
 1210307:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 121030c:	c5 fc 10 84 24 50 05 	vmovups 0x550(%rsp),%ymm0
 1210313:	00 00 
 1210315:	c5 fc 10 8c 24 70 05 	vmovups 0x570(%rsp),%ymm1
 121031c:	00 00 
 121031e:	c5 fc 10 94 24 90 05 	vmovups 0x590(%rsp),%ymm2
 1210325:	00 00 
 1210327:	c5 fc 10 9c 24 b0 05 	vmovups 0x5b0(%rsp),%ymm3
 121032e:	00 00 
 1210330:	c5 fc 11 84 24 20 02 	vmovups %ymm0,0x220(%rsp)
 1210337:	00 00 
 1210339:	c5 fc 11 8c 24 40 02 	vmovups %ymm1,0x240(%rsp)
 1210340:	00 00 
 1210342:	c5 fc 11 94 24 60 02 	vmovups %ymm2,0x260(%rsp)
 1210349:	00 00 
 121034b:	c5 fc 11 9c 24 80 02 	vmovups %ymm3,0x280(%rsp)
 1210352:	00 00 
 1210354:	c5 fe 6f 84 24 c0 05 	vmovdqu 0x5c0(%rsp),%ymm0
 121035b:	00 00 
 121035d:	c5 fe 7f 84 24 90 02 	vmovdqu %ymm0,0x290(%rsp)
 1210364:	00 00 
 1210366:	49 8b 07             	mov    (%r15),%rax
 1210369:	48 89 44 24 68       	mov    %rax,0x68(%rsp)
 121036e:	41 0f b6 47 08       	movzbl 0x8(%r15),%eax
 1210373:	88 44 24 28          	mov    %al,0x28(%rsp)
 1210377:	41 0f b6 47 09       	movzbl 0x9(%r15),%eax
 121037c:	88 44 24 1e          	mov    %al,0x1e(%rsp)
 1210380:	c4 c1 7e 6f 6d 01    	vmovdqu 0x1(%r13),%ymm5
 1210386:	c4 c1 7e 6f 65 21    	vmovdqu 0x21(%r13),%ymm4
 121038c:	41 0f b7 45 45       	movzwl 0x45(%r13),%eax
 1210391:	66 89 44 24 34       	mov    %ax,0x34(%rsp)
 1210396:	41 8b 45 41          	mov    0x41(%r13),%eax
 121039a:	89 44 24 30          	mov    %eax,0x30(%rsp)
 121039e:	45 0f b6 5f 50       	movzbl 0x50(%r15),%r11d
 12103a3:	41 8b 04 24          	mov    (%r12),%eax
 12103a7:	41 8b 4c 24 03       	mov    0x3(%r12),%ecx
 12103ac:	89 84 24 80 00 00 00 	mov    %eax,0x80(%rsp)
 12103b3:	89 8c 24 83 00 00 00 	mov    %ecx,0x83(%rsp)
 12103ba:	45 84 db             	test   %r11b,%r11b
 12103bd:	c5 fd 7f a4 24 00 01 	vmovdqa %ymm4,0x100(%rsp)
 12103c4:	00 00 
 12103c6:	c5 fd 7f ac 24 40 01 	vmovdqa %ymm5,0x140(%rsp)
 12103cd:	00 00 
 12103cf:	74 30                	je     1210401 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x731>
 12103d1:	4c 8d b4 24 fe 00 00 	lea    0xfe(%rsp),%r14
 12103d8:	00 
 12103d9:	4c 89 f7             	mov    %r14,%rdi
 12103dc:	4c 89 fe             	mov    %r15,%rsi
 12103df:	45 89 df             	mov    %r11d,%r15d
 12103e2:	c5 f8 77             	vzeroupper 
 12103e5:	e8 06 12 00 00       	call   12115f0 <br.encoder.literal_context_split.Candidate.suffixCutoff>
 12103ea:	c5 fd 6f ac 24 40 01 	vmovdqa 0x140(%rsp),%ymm5
 12103f1:	00 00 
 12103f3:	c5 fd 6f a4 24 00 01 	vmovdqa 0x100(%rsp),%ymm4
 12103fa:	00 00 
 12103fc:	45 89 fb             	mov    %r15d,%r11d
 12103ff:	eb 07                	jmp    1210408 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x738>
 1210401:	4c 8d 35 58 ef e2 ff 	lea    -0x1d10a8(%rip),%r14        # 103f360 <__anon_46044>
 1210408:	45 0f b7 3e          	movzwl (%r14),%r15d
 121040c:	0f b6 84 24 80 01 00 	movzbl 0x180(%rsp),%eax
 1210413:	00 
 1210414:	20 d8                	and    %bl,%al
 1210416:	a8 01                	test   $0x1,%al
 1210418:	66 44 89 7c 24 2e    	mov    %r15w,0x2e(%rsp)
 121041e:	0f 84 9e 00 00 00    	je     12104c2 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x7f2>
 1210424:	45 89 dd             	mov    %r11d,%r13d
 1210427:	48 8d bc 24 90 0f 00 	lea    0xf90(%rsp),%rdi
 121042e:	00 
 121042f:	48 8b 74 24 48       	mov    0x48(%rsp),%rsi
 1210434:	48 8b 94 24 c8 00 00 	mov    0xc8(%rsp),%rdx
 121043b:	00 
 121043c:	48 8b 8c 24 a8 00 00 	mov    0xa8(%rsp),%rcx
 1210443:	00 
 1210444:	4c 8b 84 24 b0 00 00 	mov    0xb0(%rsp),%r8
 121044b:	00 
 121044c:	4c 8b 8c 24 d0 00 00 	mov    0xd0(%rsp),%r9
 1210453:	00 
 1210454:	c5 f8 77             	vzeroupper 
 1210457:	e8 f4 e9 ff ff       	call   120ee50 <br.encoder.literal_context_split.chooseProposals>
 121045c:	44 0f b7 b4 24 98 10 	movzwl 0x1098(%rsp),%r14d
 1210463:	00 00 
 1210465:	66 45 85 f6          	test   %r14w,%r14w
 1210469:	0f 85 0b 11 00 00    	jne    121157a <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x18aa>
 121046f:	4c 8d a4 24 e0 0e 00 	lea    0xee0(%rsp),%r12
 1210476:	00 
 1210477:	4c 8d bc 24 38 0f 00 	lea    0xf38(%rsp),%r15
 121047e:	00 
 121047f:	4c 8d b4 24 88 0e 00 	lea    0xe88(%rsp),%r14
 1210486:	00 
 1210487:	48 8d b4 24 90 0f 00 	lea    0xf90(%rsp),%rsi
 121048e:	00 
 121048f:	ba 08 01 00 00       	mov    $0x108,%edx
 1210494:	4c 89 f7             	mov    %r14,%rdi
 1210497:	e8 24 5c 08 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 121049c:	45 89 eb             	mov    %r13d,%r11d
 121049f:	c5 fd 6f a4 24 00 01 	vmovdqa 0x100(%rsp),%ymm4
 12104a6:	00 00 
 12104a8:	c5 fd 6f ac 24 40 01 	vmovdqa 0x140(%rsp),%ymm5
 12104af:	00 00 
 12104b1:	f6 c3 01             	test   $0x1,%bl
 12104b4:	75 26                	jne    12104dc <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x80c>
 12104b6:	48 8d 0d ab ee e2 ff 	lea    -0x1d1155(%rip),%rcx        # 103f368 <__anon_46304>
 12104bd:	e9 a9 00 00 00       	jmp    121056b <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x89b>
 12104c2:	4c 8d 35 8f ed e2 ff 	lea    -0x1d1271(%rip),%r14        # 103f258 <__anon_46093>
 12104c9:	4c 8d 3d 38 ee e2 ff 	lea    -0x1d11c8(%rip),%r15        # 103f308 <__anon_46093+0xb0>
 12104d0:	4c 8d 25 d9 ed e2 ff 	lea    -0x1d1227(%rip),%r12        # 103f2b0 <__anon_46093+0x58>
 12104d7:	f6 c3 01             	test   $0x1,%bl
 12104da:	74 da                	je     12104b6 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x7e6>
 12104dc:	c4 c1 7c 10 06       	vmovups (%r14),%ymm0
 12104e1:	c4 c1 7c 10 4e 38    	vmovups 0x38(%r14),%ymm1
 12104e7:	c5 fc 11 8c 24 b8 0d 	vmovups %ymm1,0xdb8(%rsp)
 12104ee:	00 00 
 12104f0:	c4 c1 7c 10 4e 20    	vmovups 0x20(%r14),%ymm1
 12104f6:	c5 fc 11 8c 24 a0 0d 	vmovups %ymm1,0xda0(%rsp)
 12104fd:	00 00 
 12104ff:	c5 fc 11 84 24 80 0d 	vmovups %ymm0,0xd80(%rsp)
 1210506:	00 00 
 1210508:	c4 c1 7c 10 04 24    	vmovups (%r12),%ymm0
 121050e:	c4 c1 7c 10 4c 24 20 	vmovups 0x20(%r12),%ymm1
 1210515:	c4 c1 7c 10 54 24 38 	vmovups 0x38(%r12),%ymm2
 121051c:	c5 fc 11 84 24 d8 0d 	vmovups %ymm0,0xdd8(%rsp)
 1210523:	00 00 
 1210525:	c5 fc 11 8c 24 f8 0d 	vmovups %ymm1,0xdf8(%rsp)
 121052c:	00 00 
 121052e:	c5 fc 11 94 24 10 0e 	vmovups %ymm2,0xe10(%rsp)
 1210535:	00 00 
 1210537:	c4 c1 7c 10 07       	vmovups (%r15),%ymm0
 121053c:	c4 c1 7c 10 4f 20    	vmovups 0x20(%r15),%ymm1
 1210542:	c5 fc 11 84 24 30 0e 	vmovups %ymm0,0xe30(%rsp)
 1210549:	00 00 
 121054b:	c4 c1 7e 6f 47 38    	vmovdqu 0x38(%r15),%ymm0
 1210551:	c5 fc 11 8c 24 50 0e 	vmovups %ymm1,0xe50(%rsp)
 1210558:	00 00 
 121055a:	c5 fe 7f 84 24 68 0e 	vmovdqu %ymm0,0xe68(%rsp)
 1210561:	00 00 
 1210563:	48 8d 8c 24 80 0d 00 	lea    0xd80(%rsp),%rcx
 121056a:	00 
 121056b:	4c 8b 54 24 60       	mov    0x60(%rsp),%r10
 1210570:	45 31 ed             	xor    %r13d,%r13d
 1210573:	48 c7 84 24 c0 00 00 	movq   $0x0,0xc0(%rsp)
 121057a:	00 00 00 00 00 
 121057f:	45 31 ff             	xor    %r15d,%r15d
 1210582:	48 89 8c 24 88 00 00 	mov    %rcx,0x88(%rsp)
 1210589:	00 
 121058a:	eb 2a                	jmp    12105b6 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x8e6>
 121058c:	48 8b 8c 24 88 00 00 	mov    0x88(%rsp),%rcx
 1210593:	00 
 1210594:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 121059b:	00 00 00 00 00 
 12105a0:	4d 85 ed             	test   %r13,%r13
 12105a3:	0f 84 b7 06 00 00    	je     1210c60 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xf90>
 12105a9:	49 ff c5             	inc    %r13
 12105ac:	49 83 fd 03          	cmp    $0x3,%r13
 12105b0:	0f 84 8d 08 00 00    	je     1210e43 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1173>
 12105b6:	49 6b c5 58          	imul   $0x58,%r13,%rax
 12105ba:	80 7c 01 50 00       	cmpb   $0x0,0x50(%rcx,%rax,1)
 12105bf:	74 df                	je     12105a0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x8d0>
 12105c1:	4c 8b 04 01          	mov    (%rcx,%rax,1),%r8
 12105c5:	44 0f b6 74 01 08    	movzbl 0x8(%rcx,%rax,1),%r14d
 12105cb:	44 0f b6 64 01 09    	movzbl 0x9(%rcx,%rax,1),%r12d
 12105d1:	c5 fe 6f 74 01 0a    	vmovdqu 0xa(%rcx,%rax,1),%ymm6
 12105d7:	c5 fe 6f 7c 01 2a    	vmovdqu 0x2a(%rcx,%rax,1),%ymm7
 12105dd:	48 8d 44 01 4a       	lea    0x4a(%rcx,%rax,1),%rax
 12105e2:	0f b7 48 04          	movzwl 0x4(%rax),%ecx
 12105e6:	66 89 4c 24 74       	mov    %cx,0x74(%rsp)
 12105eb:	8b 08                	mov    (%rax),%ecx
 12105ed:	89 4c 24 70          	mov    %ecx,0x70(%rsp)
 12105f1:	45 84 db             	test   %r11b,%r11b
 12105f4:	74 5a                	je     1210650 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x980>
 12105f6:	44 89 f2             	mov    %r14d,%edx
 12105f9:	80 e2 03             	and    $0x3,%dl
 12105fc:	0f b6 74 24 28       	movzbl 0x28(%rsp),%esi
 1210601:	40 80 e6 03          	and    $0x3,%sil
 1210605:	31 c9                	xor    %ecx,%ecx
 1210607:	40 38 f2             	cmp    %sil,%dl
 121060a:	75 2e                	jne    121063a <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x96a>
 121060c:	0f b6 54 24 1e       	movzbl 0x1e(%rsp),%edx
 1210611:	80 e2 7f             	and    $0x7f,%dl
 1210614:	44 89 e6             	mov    %r12d,%esi
 1210617:	40 80 e6 7f          	and    $0x7f,%sil
 121061b:	40 38 d6             	cmp    %dl,%sil
 121061e:	75 1a                	jne    121063a <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x96a>
 1210620:	c5 cd 74 c5          	vpcmpeqb %ymm5,%ymm6,%ymm0
 1210624:	c5 fd d7 d0          	vpmovmskb %ymm0,%edx
 1210628:	f7 d2                	not    %edx
 121062a:	85 d2                	test   %edx,%edx
 121062c:	75 0c                	jne    121063a <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x96a>
 121062e:	c5 c5 ef c4          	vpxor  %ymm4,%ymm7,%ymm0
 1210632:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 1210637:	0f 94 c1             	sete   %cl
 121063a:	4d 85 ff             	test   %r15,%r15
 121063d:	44 89 9c 24 90 00 00 	mov    %r11d,0x90(%rsp)
 1210644:	00 
 1210645:	75 18                	jne    121065f <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x98f>
 1210647:	eb 3c                	jmp    1210685 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x9b5>
 1210649:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)
 1210650:	31 c9                	xor    %ecx,%ecx
 1210652:	4d 85 ff             	test   %r15,%r15
 1210655:	44 89 9c 24 90 00 00 	mov    %r11d,0x90(%rsp)
 121065c:	00 
 121065d:	74 26                	je     1210685 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x9b5>
 121065f:	4d 89 d3             	mov    %r10,%r11
 1210662:	4c 89 c3             	mov    %r8,%rbx
 1210665:	49 83 ff 01          	cmp    $0x1,%r15
 1210669:	75 39                	jne    12106a4 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x9d4>
 121066b:	31 d2                	xor    %edx,%edx
 121066d:	41 f6 c7 01          	test   $0x1,%r15b
 1210671:	49 89 d8             	mov    %rbx,%r8
 1210674:	4d 89 da             	mov    %r11,%r10
 1210677:	44 8b 9c 24 90 00 00 	mov    0x90(%rsp),%r11d
 121067e:	00 
 121067f:	0f 85 00 01 00 00    	jne    1210785 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xab5>
 1210685:	f6 c1 01             	test   $0x1,%cl
 1210688:	0f 84 72 01 00 00    	je     1210800 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xb30>
 121068e:	48 8b 8c 24 88 00 00 	mov    0x88(%rsp),%rcx
 1210695:	00 
 1210696:	4d 85 ed             	test   %r13,%r13
 1210699:	0f 85 0a ff ff ff    	jne    12105a9 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x8d9>
 121069f:	e9 bc 05 00 00       	jmp    1210c60 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xf90>
 12106a4:	4c 89 fe             	mov    %r15,%rsi
 12106a7:	48 83 e6 fe          	and    $0xfffffffffffffffe,%rsi
 12106ab:	48 8d bc 24 c0 02 00 	lea    0x2c0(%rsp),%rdi
 12106b2:	00 
 12106b3:	31 d2                	xor    %edx,%edx
 12106b5:	eb 19                	jmp    12106d0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xa00>
 12106b7:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 12106be:	00 00 
 12106c0:	48 83 c2 02          	add    $0x2,%rdx
 12106c4:	48 81 c7 a0 00 00 00 	add    $0xa0,%rdi
 12106cb:	48 39 d6             	cmp    %rdx,%rsi
 12106ce:	74 9d                	je     121066d <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x99d>
 12106d0:	41 b0 01             	mov    $0x1,%r8b
 12106d3:	f6 c1 01             	test   $0x1,%cl
 12106d6:	b1 01                	mov    $0x1,%cl
 12106d8:	75 4b                	jne    1210725 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xa55>
 12106da:	45 89 f1             	mov    %r14d,%r9d
 12106dd:	41 80 e1 03          	and    $0x3,%r9b
 12106e1:	44 0f b6 17          	movzbl (%rdi),%r10d
 12106e5:	41 80 e2 03          	and    $0x3,%r10b
 12106e9:	45 31 c0             	xor    %r8d,%r8d
 12106ec:	45 38 d1             	cmp    %r10b,%r9b
 12106ef:	75 34                	jne    1210725 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xa55>
 12106f1:	44 0f b6 4f 01       	movzbl 0x1(%rdi),%r9d
 12106f6:	41 80 e1 7f          	and    $0x7f,%r9b
 12106fa:	45 89 e2             	mov    %r12d,%r10d
 12106fd:	41 80 e2 7f          	and    $0x7f,%r10b
 1210701:	45 38 ca             	cmp    %r9b,%r10b
 1210704:	75 1f                	jne    1210725 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xa55>
 1210706:	c5 cd 74 47 02       	vpcmpeqb 0x2(%rdi),%ymm6,%ymm0
 121070b:	c5 7d d7 c8          	vpmovmskb %ymm0,%r9d
 121070f:	41 f7 d1             	not    %r9d
 1210712:	45 85 c9             	test   %r9d,%r9d
 1210715:	75 0e                	jne    1210725 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xa55>
 1210717:	c5 c5 ef 47 22       	vpxor  0x22(%rdi),%ymm7,%ymm0
 121071c:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 1210721:	41 0f 94 c0          	sete   %r8b
 1210725:	45 84 c0             	test   %r8b,%r8b
 1210728:	75 96                	jne    12106c0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x9f0>
 121072a:	45 89 f0             	mov    %r14d,%r8d
 121072d:	41 80 e0 03          	and    $0x3,%r8b
 1210731:	44 0f b6 4f 50       	movzbl 0x50(%rdi),%r9d
 1210736:	41 80 e1 03          	and    $0x3,%r9b
 121073a:	31 c9                	xor    %ecx,%ecx
 121073c:	45 38 c8             	cmp    %r9b,%r8b
 121073f:	0f 85 7b ff ff ff    	jne    12106c0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x9f0>
 1210745:	44 0f b6 47 51       	movzbl 0x51(%rdi),%r8d
 121074a:	41 80 e0 7f          	and    $0x7f,%r8b
 121074e:	45 89 e1             	mov    %r12d,%r9d
 1210751:	41 80 e1 7f          	and    $0x7f,%r9b
 1210755:	45 38 c1             	cmp    %r8b,%r9b
 1210758:	0f 85 62 ff ff ff    	jne    12106c0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x9f0>
 121075e:	c5 cd 74 47 52       	vpcmpeqb 0x52(%rdi),%ymm6,%ymm0
 1210763:	c5 7d d7 c0          	vpmovmskb %ymm0,%r8d
 1210767:	41 f7 d0             	not    %r8d
 121076a:	45 85 c0             	test   %r8d,%r8d
 121076d:	0f 85 4d ff ff ff    	jne    12106c0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x9f0>
 1210773:	c5 c5 ef 47 72       	vpxor  0x72(%rdi),%ymm7,%ymm0
 1210778:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 121077d:	0f 94 c1             	sete   %cl
 1210780:	e9 3b ff ff ff       	jmp    12106c0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x9f0>
 1210785:	84 c9                	test   %cl,%cl
 1210787:	0f 85 ff fd ff ff    	jne    121058c <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x8bc>
 121078d:	48 8d 0c 92          	lea    (%rdx,%rdx,4),%rcx
 1210791:	48 c1 e1 04          	shl    $0x4,%rcx
 1210795:	48 8d 14 0c          	lea    (%rsp,%rcx,1),%rdx
 1210799:	48 81 c2 b8 02 00 00 	add    $0x2b8,%rdx
 12107a0:	44 89 f6             	mov    %r14d,%esi
 12107a3:	40 80 e6 03          	and    $0x3,%sil
 12107a7:	0f b6 7a 08          	movzbl 0x8(%rdx),%edi
 12107ab:	40 80 e7 03          	and    $0x3,%dil
 12107af:	40 38 fe             	cmp    %dil,%sil
 12107b2:	75 4c                	jne    1210800 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xb30>
 12107b4:	0f b6 72 09          	movzbl 0x9(%rdx),%esi
 12107b8:	40 80 e6 7f          	and    $0x7f,%sil
 12107bc:	44 89 e7             	mov    %r12d,%edi
 12107bf:	40 80 e7 7f          	and    $0x7f,%dil
 12107c3:	40 38 f7             	cmp    %sil,%dil
 12107c6:	75 38                	jne    1210800 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xb30>
 12107c8:	c5 cd 74 42 0a       	vpcmpeqb 0xa(%rdx),%ymm6,%ymm0
 12107cd:	c5 fd d7 d0          	vpmovmskb %ymm0,%edx
 12107d1:	f7 d2                	not    %edx
 12107d3:	85 d2                	test   %edx,%edx
 12107d5:	75 29                	jne    1210800 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xb30>
 12107d7:	c5 c5 ef 84 0c e2 02 	vpxor  0x2e2(%rsp,%rcx,1),%ymm7,%ymm0
 12107de:	00 00 
 12107e0:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 12107e5:	0f 94 c1             	sete   %cl
 12107e8:	f6 c1 01             	test   $0x1,%cl
 12107eb:	0f 85 9d fe ff ff    	jne    121068e <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x9be>
 12107f1:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 12107f8:	0f 1f 84 00 00 00 00 
 12107ff:	00 
 1210800:	c5 fd 7f ac 24 40 01 	vmovdqa %ymm5,0x140(%rsp)
 1210807:	00 00 
 1210809:	c5 fd 7f a4 24 00 01 	vmovdqa %ymm4,0x100(%rsp)
 1210810:	00 00 
 1210812:	4c 89 54 24 60       	mov    %r10,0x60(%rsp)
 1210817:	4c 89 7c 24 78       	mov    %r15,0x78(%rsp)
 121081c:	c5 fc 10 84 24 80 04 	vmovups 0x480(%rsp),%ymm0
 1210823:	00 00 
 1210825:	c5 fc 11 84 24 50 06 	vmovups %ymm0,0x650(%rsp)
 121082c:	00 00 
 121082e:	c5 fc 10 84 24 10 04 	vmovups 0x410(%rsp),%ymm0
 1210835:	00 00 
 1210837:	c5 fc 10 8c 24 30 04 	vmovups 0x430(%rsp),%ymm1
 121083e:	00 00 
 1210840:	c5 fc 10 94 24 50 04 	vmovups 0x450(%rsp),%ymm2
 1210847:	00 00 
 1210849:	c5 fc 10 9c 24 70 04 	vmovups 0x470(%rsp),%ymm3
 1210850:	00 00 
 1210852:	c5 fc 11 9c 24 40 06 	vmovups %ymm3,0x640(%rsp)
 1210859:	00 00 
 121085b:	c5 fc 11 94 24 20 06 	vmovups %ymm2,0x620(%rsp)
 1210862:	00 00 
 1210864:	c5 fc 11 8c 24 00 06 	vmovups %ymm1,0x600(%rsp)
 121086b:	00 00 
 121086d:	c5 fc 11 84 24 e0 05 	vmovups %ymm0,0x5e0(%rsp)
 1210874:	00 00 
 1210876:	0f b6 4c 24 20       	movzbl 0x20(%rsp),%ecx
 121087b:	c5 fe 6f 84 24 f0 03 	vmovdqu 0x3f0(%rsp),%ymm0
 1210882:	00 00 
 1210884:	48 8d b4 24 e2 0b 00 	lea    0xbe2(%rsp),%rsi
 121088b:	00 
 121088c:	c5 fe 7f 46 96       	vmovdqu %ymm0,-0x6a(%rsi)
 1210891:	0f b7 50 04          	movzwl 0x4(%rax),%edx
 1210895:	66 89 56 04          	mov    %dx,0x4(%rsi)
 1210899:	8b 00                	mov    (%rax),%eax
 121089b:	89 06                	mov    %eax,(%rsi)
 121089d:	88 8c 24 79 0d 00 00 	mov    %cl,0xd79(%rsp)
 12108a4:	48 c7 84 24 68 0b 00 	movq   $0x0,0xb68(%rsp)
 12108ab:	00 00 00 00 00 
 12108b0:	8b 44 24 40          	mov    0x40(%rsp),%eax
 12108b4:	88 84 24 7d 0d 00 00 	mov    %al,0xd7d(%rsp)
 12108bb:	c6 84 24 7c 0d 00 00 	movb   $0x0,0xd7c(%rsp)
 12108c2:	00 
 12108c3:	4c 89 c3             	mov    %r8,%rbx
 12108c6:	4c 89 84 24 98 0b 00 	mov    %r8,0xb98(%rsp)
 12108cd:	00 
 12108ce:	44 88 b4 24 a0 0b 00 	mov    %r14b,0xba0(%rsp)
 12108d5:	00 
 12108d6:	44 88 a4 24 a1 0b 00 	mov    %r12b,0xba1(%rsp)
 12108dd:	00 
 12108de:	c5 fd 7f b4 24 80 01 	vmovdqa %ymm6,0x180(%rsp)
 12108e5:	00 00 
 12108e7:	c5 fe 7f b4 24 a2 0b 	vmovdqu %ymm6,0xba2(%rsp)
 12108ee:	00 00 
 12108f0:	c5 fd 7f bc 24 60 01 	vmovdqa %ymm7,0x160(%rsp)
 12108f7:	00 00 
 12108f9:	c5 fe 7f bc 24 c2 0b 	vmovdqu %ymm7,0xbc2(%rsp)
 1210900:	00 00 
 1210902:	c6 84 24 e8 0b 00 00 	movb   $0x1,0xbe8(%rsp)
 1210909:	01 
 121090a:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 121090e:	c5 fe 7f 86 5e 01 00 	vmovdqu %ymm0,0x15e(%rsi)
 1210915:	00 
 1210916:	c5 fe 7f 86 4e 01 00 	vmovdqu %ymm0,0x14e(%rsi)
 121091d:	00 
 121091e:	c5 fe 7f 86 2e 01 00 	vmovdqu %ymm0,0x12e(%rsi)
 1210925:	00 
 1210926:	c5 fe 7f 86 0e 01 00 	vmovdqu %ymm0,0x10e(%rsi)
 121092d:	00 
 121092e:	c5 fe 7f 86 ee 00 00 	vmovdqu %ymm0,0xee(%rsi)
 1210935:	00 
 1210936:	c5 fe 7f 86 ce 00 00 	vmovdqu %ymm0,0xce(%rsi)
 121093d:	00 
 121093e:	c5 fe 7f 86 ae 00 00 	vmovdqu %ymm0,0xae(%rsi)
 1210945:	00 
 1210946:	c5 fe 7f 86 8e 00 00 	vmovdqu %ymm0,0x8e(%rsi)
 121094d:	00 
 121094e:	c5 fe 7f 46 6e       	vmovdqu %ymm0,0x6e(%rsi)
 1210953:	c5 fe 7f 46 4e       	vmovdqu %ymm0,0x4e(%rsi)
 1210958:	c5 fe 7f 46 2e       	vmovdqu %ymm0,0x2e(%rsi)
 121095d:	c5 fe 7f 46 0e       	vmovdqu %ymm0,0xe(%rsi)
 1210962:	c6 84 24 70 0d 00 00 	movb   $0x38,0xd70(%rsp)
 1210969:	38 
 121096a:	c6 84 24 78 0d 00 00 	movb   $0x0,0xd78(%rsp)
 1210971:	00 
 1210972:	0f b7 05 cf a5 e2 ff 	movzwl -0x1d5a31(%rip),%eax        # 103af48 <__anon_35281>
 1210979:	66 89 84 24 72 0d 00 	mov    %ax,0xd72(%rsp)
 1210980:	00 
 1210981:	0f b6 44 24 1f       	movzbl 0x1f(%rsp),%eax
 1210986:	88 84 24 71 0d 00 00 	mov    %al,0xd71(%rsp)
 121098d:	48 8b 84 24 f0 00 00 	mov    0xf0(%rsp),%rax
 1210994:	00 
 1210995:	48 89 84 24 58 0b 00 	mov    %rax,0xb58(%rsp)
 121099c:	00 
 121099d:	48 8b 84 24 e8 00 00 	mov    0xe8(%rsp),%rax
 12109a4:	00 
 12109a5:	48 89 84 24 60 0b 00 	mov    %rax,0xb60(%rsp)
 12109ac:	00 
 12109ad:	c7 84 24 74 0d 00 00 	movl   $0x1000101,0xd74(%rsp)
 12109b4:	01 01 00 01 
 12109b8:	48 8b 84 24 e0 00 00 	mov    0xe0(%rsp),%rax
 12109bf:	00 
 12109c0:	48 89 84 24 68 0d 00 	mov    %rax,0xd68(%rsp)
 12109c7:	00 
 12109c8:	48 8b 84 24 d8 00 00 	mov    0xd8(%rsp),%rax
 12109cf:	00 
 12109d0:	48 89 84 24 60 0d 00 	mov    %rax,0xd60(%rsp)
 12109d7:	00 
 12109d8:	66 c7 84 24 7a 0d 00 	movw   $0x0,0xd7a(%rsp)
 12109df:	00 00 00 
 12109e2:	48 c7 84 24 70 0b 00 	movq   $0x0,0xb70(%rsp)
 12109e9:	00 00 00 00 00 
 12109ee:	48 8d bc 24 c0 03 00 	lea    0x3c0(%rsp),%rdi
 12109f5:	00 
 12109f6:	48 8b 74 24 48       	mov    0x48(%rsp),%rsi
 12109fb:	48 8b 94 24 c8 00 00 	mov    0xc8(%rsp),%rdx
 1210a02:	00 
 1210a03:	48 8b 8c 24 a8 00 00 	mov    0xa8(%rsp),%rcx
 1210a0a:	00 
 1210a0b:	4c 8b 84 24 b0 00 00 	mov    0xb0(%rsp),%r8
 1210a12:	00 
 1210a13:	4c 8b 8c 24 d0 00 00 	mov    0xd0(%rsp),%r9
 1210a1a:	00 
 1210a1b:	48 8d 84 24 58 0b 00 	lea    0xb58(%rsp),%rax
 1210a22:	00 
 1210a23:	50                   	push   %rax
 1210a24:	48 8d 84 24 e8 05 00 	lea    0x5e8(%rsp),%rax
 1210a2b:	00 
 1210a2c:	50                   	push   %rax
 1210a2d:	c5 f8 77             	vzeroupper 
 1210a30:	e8 cb 3f f6 ff       	call   1174a00 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307>
 1210a35:	48 83 c4 10          	add    $0x10,%rsp
 1210a39:	44 0f b7 bc 24 d0 03 	movzwl 0x3d0(%rsp),%r15d
 1210a40:	00 00 
 1210a42:	66 45 85 ff          	test   %r15w,%r15w
 1210a46:	0f 85 e7 0a 00 00    	jne    1211533 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1863>
 1210a4c:	48 8b b4 24 c0 03 00 	mov    0x3c0(%rsp),%rsi
 1210a53:	00 
 1210a54:	4c 8b bc 24 c8 03 00 	mov    0x3c8(%rsp),%r15
 1210a5b:	00 
 1210a5c:	48 8b 54 24 38       	mov    0x38(%rsp),%rdx
 1210a61:	49 39 d7             	cmp    %rdx,%r15
 1210a64:	0f 83 2c 01 00 00    	jae    1210b96 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xec6>
 1210a6a:	48 89 b4 24 b8 00 00 	mov    %rsi,0xb8(%rsp)
 1210a71:	00 
 1210a72:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 1210a77:	48 8b 38             	mov    (%rax),%rdi
 1210a7a:	48 8b 40 08          	mov    0x8(%rax),%rax
 1210a7e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1210a82:	48 8b 74 24 60       	mov    0x60(%rsp),%rsi
 1210a87:	31 c9                	xor    %ecx,%ecx
 1210a89:	4c 89 44 24 38       	mov    %r8,0x38(%rsp)
 1210a8e:	ff 50 18             	call   *0x18(%rax)
 1210a91:	c5 fc 10 84 24 50 06 	vmovups 0x650(%rsp),%ymm0
 1210a98:	00 00 
 1210a9a:	c5 fc 11 84 24 90 02 	vmovups %ymm0,0x290(%rsp)
 1210aa1:	00 00 
 1210aa3:	c5 fe 6f 84 24 e0 05 	vmovdqu 0x5e0(%rsp),%ymm0
 1210aaa:	00 00 
 1210aac:	c5 fc 10 8c 24 00 06 	vmovups 0x600(%rsp),%ymm1
 1210ab3:	00 00 
 1210ab5:	c5 fc 10 94 24 20 06 	vmovups 0x620(%rsp),%ymm2
 1210abc:	00 00 
 1210abe:	c5 fc 10 9c 24 40 06 	vmovups 0x640(%rsp),%ymm3
 1210ac5:	00 00 
 1210ac7:	c5 fc 11 9c 24 80 02 	vmovups %ymm3,0x280(%rsp)
 1210ace:	00 00 
 1210ad0:	c5 fc 11 94 24 60 02 	vmovups %ymm2,0x260(%rsp)
 1210ad7:	00 00 
 1210ad9:	c5 fc 11 8c 24 40 02 	vmovups %ymm1,0x240(%rsp)
 1210ae0:	00 00 
 1210ae2:	c5 fe 7f 84 24 20 02 	vmovdqu %ymm0,0x220(%rsp)
 1210ae9:	00 00 
 1210aeb:	80 bc 24 90 00 00 00 	cmpb   $0x0,0x90(%rsp)
 1210af2:	00 
 1210af3:	41 b3 01             	mov    $0x1,%r11b
 1210af6:	0f 84 8e 02 00 00    	je     1210d8a <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x10ba>
 1210afc:	48 8b 54 24 78       	mov    0x78(%rsp),%rdx
 1210b01:	48 83 fa 03          	cmp    $0x3,%rdx
 1210b05:	c5 fd 6f ac 24 80 01 	vmovdqa 0x180(%rsp),%ymm5
 1210b0c:	00 00 
 1210b0e:	c5 fd 6f a4 24 60 01 	vmovdqa 0x160(%rsp),%ymm4
 1210b15:	00 00 
 1210b17:	0f 83 50 09 00 00    	jae    121146d <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x179d>
 1210b1d:	49 89 d8             	mov    %rbx,%r8
 1210b20:	48 8d 04 92          	lea    (%rdx,%rdx,4),%rax
 1210b24:	48 c1 e0 04          	shl    $0x4,%rax
 1210b28:	48 8b 4c 24 68       	mov    0x68(%rsp),%rcx
 1210b2d:	48 89 8c 04 b8 02 00 	mov    %rcx,0x2b8(%rsp,%rax,1)
 1210b34:	00 
 1210b35:	0f b6 4c 24 28       	movzbl 0x28(%rsp),%ecx
 1210b3a:	88 8c 04 c0 02 00 00 	mov    %cl,0x2c0(%rsp,%rax,1)
 1210b41:	0f b6 4c 24 1e       	movzbl 0x1e(%rsp),%ecx
 1210b46:	88 8c 04 c1 02 00 00 	mov    %cl,0x2c1(%rsp,%rax,1)
 1210b4d:	c5 fc 28 84 24 40 01 	vmovaps 0x140(%rsp),%ymm0
 1210b54:	00 00 
 1210b56:	c5 fc 11 84 04 c2 02 	vmovups %ymm0,0x2c2(%rsp,%rax,1)
 1210b5d:	00 00 
 1210b5f:	c5 fd 6f 84 24 00 01 	vmovdqa 0x100(%rsp),%ymm0
 1210b66:	00 00 
 1210b68:	c5 fe 7f 84 04 e2 02 	vmovdqu %ymm0,0x2e2(%rsp,%rax,1)
 1210b6f:	00 00 
 1210b71:	8b 4c 24 30          	mov    0x30(%rsp),%ecx
 1210b75:	89 8c 04 02 03 00 00 	mov    %ecx,0x302(%rsp,%rax,1)
 1210b7c:	0f b7 4c 24 34       	movzwl 0x34(%rsp),%ecx
 1210b81:	66 89 8c 04 06 03 00 	mov    %cx,0x306(%rsp,%rax,1)
 1210b88:	00 
 1210b89:	48 ff c2             	inc    %rdx
 1210b8c:	48 89 54 24 78       	mov    %rdx,0x78(%rsp)
 1210b91:	e9 13 02 00 00       	jmp    1210da9 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x10d9>
 1210b96:	4d 85 ff             	test   %r15,%r15
 1210b99:	74 1d                	je     1210bb8 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xee8>
 1210b9b:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 1210ba0:	48 8b 38             	mov    (%rax),%rdi
 1210ba3:	48 8b 40 08          	mov    0x8(%rax),%rax
 1210ba7:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1210bab:	4c 89 fa             	mov    %r15,%rdx
 1210bae:	31 c9                	xor    %ecx,%ecx
 1210bb0:	ff 50 18             	call   *0x18(%rax)
 1210bb3:	48 8b 54 24 38       	mov    0x38(%rsp),%rdx
 1210bb8:	4c 8b 7c 24 78       	mov    0x78(%rsp),%r15
 1210bbd:	49 83 ff 02          	cmp    $0x2,%r15
 1210bc1:	0f 87 88 08 00 00    	ja     121144f <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x177f>
 1210bc7:	4b 8d 04 bf          	lea    (%r15,%r15,4),%rax
 1210bcb:	48 c1 e0 04          	shl    $0x4,%rax
 1210bcf:	48 89 9c 04 b8 02 00 	mov    %rbx,0x2b8(%rsp,%rax,1)
 1210bd6:	00 
 1210bd7:	44 88 b4 04 c0 02 00 	mov    %r14b,0x2c0(%rsp,%rax,1)
 1210bde:	00 
 1210bdf:	44 88 a4 04 c1 02 00 	mov    %r12b,0x2c1(%rsp,%rax,1)
 1210be6:	00 
 1210be7:	c5 fc 28 84 24 80 01 	vmovaps 0x180(%rsp),%ymm0
 1210bee:	00 00 
 1210bf0:	c5 fc 11 84 04 c2 02 	vmovups %ymm0,0x2c2(%rsp,%rax,1)
 1210bf7:	00 00 
 1210bf9:	c5 fd 6f 84 24 60 01 	vmovdqa 0x160(%rsp),%ymm0
 1210c00:	00 00 
 1210c02:	c5 fe 7f 84 04 e2 02 	vmovdqu %ymm0,0x2e2(%rsp,%rax,1)
 1210c09:	00 00 
 1210c0b:	8b 4c 24 70          	mov    0x70(%rsp),%ecx
 1210c0f:	89 8c 04 02 03 00 00 	mov    %ecx,0x302(%rsp,%rax,1)
 1210c16:	0f b7 4c 24 74       	movzwl 0x74(%rsp),%ecx
 1210c1b:	66 89 8c 04 06 03 00 	mov    %cx,0x306(%rsp,%rax,1)
 1210c22:	00 
 1210c23:	49 ff c7             	inc    %r15
 1210c26:	44 8b 9c 24 90 00 00 	mov    0x90(%rsp),%r11d
 1210c2d:	00 
 1210c2e:	4c 8b 54 24 60       	mov    0x60(%rsp),%r10
 1210c33:	c5 fd 6f a4 24 00 01 	vmovdqa 0x100(%rsp),%ymm4
 1210c3a:	00 00 
 1210c3c:	c5 fd 6f ac 24 40 01 	vmovdqa 0x140(%rsp),%ymm5
 1210c43:	00 00 
 1210c45:	48 8b 8c 24 88 00 00 	mov    0x88(%rsp),%rcx
 1210c4c:	00 
 1210c4d:	4d 85 ed             	test   %r13,%r13
 1210c50:	0f 85 53 f9 ff ff    	jne    12105a9 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x8d9>
 1210c56:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 1210c5d:	00 00 00 
 1210c60:	0f b7 44 24 34       	movzwl 0x34(%rsp),%eax
 1210c65:	66 89 84 24 a0 00 00 	mov    %ax,0xa0(%rsp)
 1210c6c:	00 
 1210c6d:	8b 44 24 30          	mov    0x30(%rsp),%eax
 1210c71:	89 84 24 9c 00 00 00 	mov    %eax,0x9c(%rsp)
 1210c78:	45 84 db             	test   %r11b,%r11b
 1210c7b:	0f 84 fa 00 00 00    	je     1210d7b <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x10ab>
 1210c81:	4c 89 7c 24 78       	mov    %r15,0x78(%rsp)
 1210c86:	44 0f b6 64 24 1e    	movzbl 0x1e(%rsp),%r12d
 1210c8c:	4c 8b 7c 24 38       	mov    0x38(%rsp),%r15
 1210c91:	4c 8b 44 24 68       	mov    0x68(%rsp),%r8
 1210c96:	44 0f b6 74 24 28    	movzbl 0x28(%rsp),%r14d
 1210c9c:	44 89 f0             	mov    %r14d,%eax
 1210c9f:	24 03                	and    $0x3,%al
 1210ca1:	3c 02                	cmp    $0x2,%al
 1210ca3:	0f 85 6d 01 00 00    	jne    1210e16 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1146>
 1210ca9:	4c 89 84 24 00 05 00 	mov    %r8,0x500(%rsp)
 1210cb0:	00 
 1210cb1:	44 88 b4 24 08 05 00 	mov    %r14b,0x508(%rsp)
 1210cb8:	00 
 1210cb9:	44 88 a4 24 09 05 00 	mov    %r12b,0x509(%rsp)
 1210cc0:	00 
 1210cc1:	c5 fe 7f ac 24 0a 05 	vmovdqu %ymm5,0x50a(%rsp)
 1210cc8:	00 00 
 1210cca:	c5 fe 7f a4 24 2a 05 	vmovdqu %ymm4,0x52a(%rsp)
 1210cd1:	00 00 
 1210cd3:	0f b7 84 24 a0 00 00 	movzwl 0xa0(%rsp),%eax
 1210cda:	00 
 1210cdb:	48 8d 8c 24 4a 05 00 	lea    0x54a(%rsp),%rcx
 1210ce2:	00 
 1210ce3:	66 89 41 04          	mov    %ax,0x4(%rcx)
 1210ce7:	8b 84 24 9c 00 00 00 	mov    0x9c(%rsp),%eax
 1210cee:	89 01                	mov    %eax,(%rcx)
 1210cf0:	48 8d bc 24 a6 00 00 	lea    0xa6(%rsp),%rdi
 1210cf7:	00 
 1210cf8:	4c 89 94 24 b8 00 00 	mov    %r10,0xb8(%rsp)
 1210cff:	00 
 1210d00:	48 8d b4 24 00 05 00 	lea    0x500(%rsp),%rsi
 1210d07:	00 
 1210d08:	44 89 db             	mov    %r11d,%ebx
 1210d0b:	4c 89 84 24 90 00 00 	mov    %r8,0x90(%rsp)
 1210d12:	00 
 1210d13:	c5 fd 7f ac 24 80 01 	vmovdqa %ymm5,0x180(%rsp)
 1210d1a:	00 00 
 1210d1c:	c5 fd 7f a4 24 60 01 	vmovdqa %ymm4,0x160(%rsp)
 1210d23:	00 00 
 1210d25:	c5 f8 77             	vzeroupper 
 1210d28:	e8 c3 08 00 00       	call   12115f0 <br.encoder.literal_context_split.Candidate.suffixCutoff>
 1210d2d:	48 8b 8c 24 88 00 00 	mov    0x88(%rsp),%rcx
 1210d34:	00 
 1210d35:	41 89 db             	mov    %ebx,%r11d
 1210d38:	44 88 64 24 1e       	mov    %r12b,0x1e(%rsp)
 1210d3d:	c5 fd 6f ac 24 80 01 	vmovdqa 0x180(%rsp),%ymm5
 1210d44:	00 00 
 1210d46:	c5 fd 6f a4 24 60 01 	vmovdqa 0x160(%rsp),%ymm4
 1210d4d:	00 00 
 1210d4f:	4c 8b 94 24 b8 00 00 	mov    0xb8(%rsp),%r10
 1210d56:	00 
 1210d57:	4c 89 7c 24 38       	mov    %r15,0x38(%rsp)
 1210d5c:	48 8b 84 24 90 00 00 	mov    0x90(%rsp),%rax
 1210d63:	00 
 1210d64:	48 89 44 24 68       	mov    %rax,0x68(%rsp)
 1210d69:	44 88 74 24 28       	mov    %r14b,0x28(%rsp)
 1210d6e:	48 8d 84 24 a6 00 00 	lea    0xa6(%rsp),%rax
 1210d75:	00 
 1210d76:	e9 b6 00 00 00       	jmp    1210e31 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1161>
 1210d7b:	45 31 db             	xor    %r11d,%r11d
 1210d7e:	48 8d 05 db e5 e2 ff 	lea    -0x1d1a25(%rip),%rax        # 103f360 <__anon_46044>
 1210d85:	e9 ac 00 00 00       	jmp    1210e36 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1166>
 1210d8a:	b0 01                	mov    $0x1,%al
 1210d8c:	48 89 84 24 c0 00 00 	mov    %rax,0xc0(%rsp)
 1210d93:	00 
 1210d94:	49 89 d8             	mov    %rbx,%r8
 1210d97:	c5 fd 6f ac 24 80 01 	vmovdqa 0x180(%rsp),%ymm5
 1210d9e:	00 00 
 1210da0:	c5 fd 6f a4 24 60 01 	vmovdqa 0x160(%rsp),%ymm4
 1210da7:	00 00 
 1210da9:	4c 8b 94 24 b8 00 00 	mov    0xb8(%rsp),%r10
 1210db0:	00 
 1210db1:	0f b7 44 24 74       	movzwl 0x74(%rsp),%eax
 1210db6:	66 89 44 24 34       	mov    %ax,0x34(%rsp)
 1210dbb:	8b 44 24 70          	mov    0x70(%rsp),%eax
 1210dbf:	89 44 24 30          	mov    %eax,0x30(%rsp)
 1210dc3:	4d 85 ed             	test   %r13,%r13
 1210dc6:	48 8b 8c 24 88 00 00 	mov    0x88(%rsp),%rcx
 1210dcd:	00 
 1210dce:	74 1e                	je     1210dee <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x111e>
 1210dd0:	44 88 74 24 28       	mov    %r14b,0x28(%rsp)
 1210dd5:	4c 89 44 24 68       	mov    %r8,0x68(%rsp)
 1210dda:	4c 89 7c 24 38       	mov    %r15,0x38(%rsp)
 1210ddf:	44 88 64 24 1e       	mov    %r12b,0x1e(%rsp)
 1210de4:	4c 8b 7c 24 78       	mov    0x78(%rsp),%r15
 1210de9:	e9 bb f7 ff ff       	jmp    12105a9 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x8d9>
 1210dee:	0f b7 44 24 74       	movzwl 0x74(%rsp),%eax
 1210df3:	66 89 84 24 a0 00 00 	mov    %ax,0xa0(%rsp)
 1210dfa:	00 
 1210dfb:	8b 44 24 70          	mov    0x70(%rsp),%eax
 1210dff:	89 84 24 9c 00 00 00 	mov    %eax,0x9c(%rsp)
 1210e06:	41 b3 01             	mov    $0x1,%r11b
 1210e09:	44 89 f0             	mov    %r14d,%eax
 1210e0c:	24 03                	and    $0x3,%al
 1210e0e:	3c 02                	cmp    $0x2,%al
 1210e10:	0f 84 93 fe ff ff    	je     1210ca9 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xfd9>
 1210e16:	44 88 64 24 1e       	mov    %r12b,0x1e(%rsp)
 1210e1b:	4c 89 7c 24 38       	mov    %r15,0x38(%rsp)
 1210e20:	4c 89 44 24 68       	mov    %r8,0x68(%rsp)
 1210e25:	44 88 74 24 28       	mov    %r14b,0x28(%rsp)
 1210e2a:	48 8d 05 2f e5 e2 ff 	lea    -0x1d1ad1(%rip),%rax        # 103f360 <__anon_46044>
 1210e31:	4c 8b 7c 24 78       	mov    0x78(%rsp),%r15
 1210e36:	0f b7 00             	movzwl (%rax),%eax
 1210e39:	66 89 44 24 2e       	mov    %ax,0x2e(%rsp)
 1210e3e:	e9 66 f7 ff ff       	jmp    12105a9 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x8d9>
 1210e43:	8b 44 24 40          	mov    0x40(%rsp),%eax
 1210e47:	8b 8c 24 f8 00 00 00 	mov    0xf8(%rsp),%ecx
 1210e4e:	08 c8                	or     %cl,%al
 1210e50:	0f 84 ef 03 00 00    	je     1211245 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1575>
 1210e56:	84 c9                	test   %cl,%cl
 1210e58:	4c 8b 8c 24 d0 00 00 	mov    0xd0(%rsp),%r9
 1210e5f:	00 
 1210e60:	0f b6 74 24 1f       	movzbl 0x1f(%rsp),%esi
 1210e65:	75 36                	jne    1210e9d <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x11cd>
 1210e67:	b9 64 00 00 00       	mov    $0x64,%ecx
 1210e6c:	48 8b 44 24 38       	mov    0x38(%rsp),%rax
 1210e71:	48 f7 e1             	mul    %rcx
 1210e74:	70 27                	jo     1210e9d <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x11cd>
 1210e76:	c6 84 24 c0 01 00 00 	movb   $0x0,0x1c0(%rsp)
 1210e7d:	00 
 1210e7e:	31 c9                	xor    %ecx,%ecx
 1210e80:	84 c9                	test   %cl,%cl
 1210e82:	75 19                	jne    1210e9d <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x11cd>
 1210e84:	48 8b 8c 24 a8 00 00 	mov    0xa8(%rsp),%rcx
 1210e8b:	00 
 1210e8c:	48 c1 e1 04          	shl    $0x4,%rcx
 1210e90:	48 8d 0c 89          	lea    (%rcx,%rcx,4),%rcx
 1210e94:	48 39 c8             	cmp    %rcx,%rax
 1210e97:	0f 86 24 06 00 00    	jbe    12114c1 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17f1>
 1210e9d:	c5 fd 7f ac 24 40 01 	vmovdqa %ymm5,0x140(%rsp)
 1210ea4:	00 00 
 1210ea6:	c5 fd 7f a4 24 00 01 	vmovdqa %ymm4,0x100(%rsp)
 1210ead:	00 00 
 1210eaf:	4d 89 d5             	mov    %r10,%r13
 1210eb2:	45 89 de             	mov    %r11d,%r14d
 1210eb5:	c5 fc 10 84 24 80 04 	vmovups 0x480(%rsp),%ymm0
 1210ebc:	00 00 
 1210ebe:	c5 fc 11 84 24 e0 06 	vmovups %ymm0,0x6e0(%rsp)
 1210ec5:	00 00 
 1210ec7:	c5 fc 10 84 24 10 04 	vmovups 0x410(%rsp),%ymm0
 1210ece:	00 00 
 1210ed0:	c5 fc 10 8c 24 30 04 	vmovups 0x430(%rsp),%ymm1
 1210ed7:	00 00 
 1210ed9:	c5 fc 10 94 24 50 04 	vmovups 0x450(%rsp),%ymm2
 1210ee0:	00 00 
 1210ee2:	c5 fc 10 9c 24 70 04 	vmovups 0x470(%rsp),%ymm3
 1210ee9:	00 00 
 1210eeb:	c5 fc 11 9c 24 d0 06 	vmovups %ymm3,0x6d0(%rsp)
 1210ef2:	00 00 
 1210ef4:	c5 fc 11 94 24 b0 06 	vmovups %ymm2,0x6b0(%rsp)
 1210efb:	00 00 
 1210efd:	c5 fc 11 8c 24 90 06 	vmovups %ymm1,0x690(%rsp)
 1210f04:	00 00 
 1210f06:	c5 fc 11 84 24 70 06 	vmovups %ymm0,0x670(%rsp)
 1210f0d:	00 00 
 1210f0f:	0f b6 44 24 20       	movzbl 0x20(%rsp),%eax
 1210f14:	c5 fe 6f 84 24 f0 03 	vmovdqu 0x3f0(%rsp),%ymm0
 1210f1b:	00 00 
 1210f1d:	c5 fe 7f 84 24 50 09 	vmovdqu %ymm0,0x950(%rsp)
 1210f24:	00 00 
 1210f26:	88 84 24 51 0b 00 00 	mov    %al,0xb51(%rsp)
 1210f2d:	48 c7 84 24 40 09 00 	movq   $0x0,0x940(%rsp)
 1210f34:	00 00 00 00 00 
 1210f39:	66 c7 84 24 54 0b 00 	movw   $0x0,0xb54(%rsp)
 1210f40:	00 00 00 
 1210f43:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 1210f47:	c5 fe 7f 84 24 70 09 	vmovdqu %ymm0,0x970(%rsp)
 1210f4e:	00 00 
 1210f50:	c5 fe 7f 84 24 90 09 	vmovdqu %ymm0,0x990(%rsp)
 1210f57:	00 00 
 1210f59:	c5 fe 7f 84 24 b0 09 	vmovdqu %ymm0,0x9b0(%rsp)
 1210f60:	00 00 
 1210f62:	c5 fe 7f 84 24 d0 09 	vmovdqu %ymm0,0x9d0(%rsp)
 1210f69:	00 00 
 1210f6b:	c5 fe 7f 84 24 f0 09 	vmovdqu %ymm0,0x9f0(%rsp)
 1210f72:	00 00 
 1210f74:	c5 fe 7f 84 24 10 0a 	vmovdqu %ymm0,0xa10(%rsp)
 1210f7b:	00 00 
 1210f7d:	c5 fe 7f 84 24 30 0a 	vmovdqu %ymm0,0xa30(%rsp)
 1210f84:	00 00 
 1210f86:	c5 fe 7f 84 24 50 0a 	vmovdqu %ymm0,0xa50(%rsp)
 1210f8d:	00 00 
 1210f8f:	c5 fe 7f 84 24 70 0a 	vmovdqu %ymm0,0xa70(%rsp)
 1210f96:	00 00 
 1210f98:	c5 fe 7f 84 24 90 0a 	vmovdqu %ymm0,0xa90(%rsp)
 1210f9f:	00 00 
 1210fa1:	c5 fe 7f 84 24 b0 0a 	vmovdqu %ymm0,0xab0(%rsp)
 1210fa8:	00 00 
 1210faa:	c5 fe 7f 84 24 d0 0a 	vmovdqu %ymm0,0xad0(%rsp)
 1210fb1:	00 00 
 1210fb3:	c5 fe 7f 84 24 f0 0a 	vmovdqu %ymm0,0xaf0(%rsp)
 1210fba:	00 00 
 1210fbc:	c5 fe 7f 84 24 10 0b 	vmovdqu %ymm0,0xb10(%rsp)
 1210fc3:	00 00 
 1210fc5:	48 c7 84 24 30 0b 00 	movq   $0x0,0xb30(%rsp)
 1210fcc:	00 00 00 00 00 
 1210fd1:	c6 84 24 48 0b 00 00 	movb   $0x38,0xb48(%rsp)
 1210fd8:	38 
 1210fd9:	c6 84 24 50 0b 00 00 	movb   $0x0,0xb50(%rsp)
 1210fe0:	00 
 1210fe1:	0f b7 05 60 9f e2 ff 	movzwl -0x1d60a0(%rip),%eax        # 103af48 <__anon_35281>
 1210fe8:	66 89 84 24 4a 0b 00 	mov    %ax,0xb4a(%rsp)
 1210fef:	00 
 1210ff0:	40 88 b4 24 49 0b 00 	mov    %sil,0xb49(%rsp)
 1210ff7:	00 
 1210ff8:	48 8b 84 24 f0 00 00 	mov    0xf0(%rsp),%rax
 1210fff:	00 
 1211000:	48 89 84 24 30 09 00 	mov    %rax,0x930(%rsp)
 1211007:	00 
 1211008:	48 8b 84 24 e8 00 00 	mov    0xe8(%rsp),%rax
 121100f:	00 
 1211010:	48 89 84 24 38 09 00 	mov    %rax,0x938(%rsp)
 1211017:	00 
 1211018:	c7 84 24 4c 0b 00 00 	movl   $0x1000101,0xb4c(%rsp)
 121101f:	01 01 00 01 
 1211023:	48 8b 84 24 e0 00 00 	mov    0xe0(%rsp),%rax
 121102a:	00 
 121102b:	48 89 84 24 40 0b 00 	mov    %rax,0xb40(%rsp)
 1211032:	00 
 1211033:	48 8b 84 24 d8 00 00 	mov    0xd8(%rsp),%rax
 121103a:	00 
 121103b:	48 89 84 24 38 0b 00 	mov    %rax,0xb38(%rsp)
 1211042:	00 
 1211043:	66 c7 84 24 52 0b 00 	movw   $0x0,0xb52(%rsp)
 121104a:	00 00 00 
 121104d:	48 c7 84 24 48 09 00 	movq   $0x0,0x948(%rsp)
 1211054:	00 00 00 00 00 
 1211059:	48 8d 84 24 30 09 00 	lea    0x930(%rsp),%rax
 1211060:	00 
 1211061:	4c 8d 94 24 70 06 00 	lea    0x670(%rsp),%r10
 1211068:	00 
 1211069:	48 8d bc 24 d8 03 00 	lea    0x3d8(%rsp),%rdi
 1211070:	00 
 1211071:	48 8b 74 24 48       	mov    0x48(%rsp),%rsi
 1211076:	48 8b 94 24 c8 00 00 	mov    0xc8(%rsp),%rdx
 121107d:	00 
 121107e:	48 8b 8c 24 a8 00 00 	mov    0xa8(%rsp),%rcx
 1211085:	00 
 1211086:	4c 8b 84 24 b0 00 00 	mov    0xb0(%rsp),%r8
 121108d:	00 
 121108e:	50                   	push   %rax
 121108f:	41 52                	push   %r10
 1211091:	c5 f8 77             	vzeroupper 
 1211094:	e8 67 39 f6 ff       	call   1174a00 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307>
 1211099:	48 83 c4 10          	add    $0x10,%rsp
 121109d:	0f b7 9c 24 e8 03 00 	movzwl 0x3e8(%rsp),%ebx
 12110a4:	00 
 12110a5:	66 85 db             	test   %bx,%bx
 12110a8:	0f 85 02 05 00 00    	jne    12115b0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x18e0>
 12110ae:	4c 89 fb             	mov    %r15,%rbx
 12110b1:	4c 8b a4 24 d8 03 00 	mov    0x3d8(%rsp),%r12
 12110b8:	00 
 12110b9:	4c 8b bc 24 e0 03 00 	mov    0x3e0(%rsp),%r15
 12110c0:	00 
 12110c1:	4c 8b 4c 24 38       	mov    0x38(%rsp),%r9
 12110c6:	4d 39 f9             	cmp    %r15,%r9
 12110c9:	0f 83 dc 02 00 00    	jae    12113ab <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x16db>
 12110cf:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 12110d4:	48 8b 38             	mov    (%rax),%rdi
 12110d7:	48 8b 40 08          	mov    0x8(%rax),%rax
 12110db:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12110df:	4c 89 e6             	mov    %r12,%rsi
 12110e2:	4c 89 fa             	mov    %r15,%rdx
 12110e5:	31 c9                	xor    %ecx,%ecx
 12110e7:	4d 89 cf             	mov    %r9,%r15
 12110ea:	ff 50 18             	call   *0x18(%rax)
 12110ed:	c5 fc 10 84 24 90 02 	vmovups 0x290(%rsp),%ymm0
 12110f4:	00 00 
 12110f6:	48 8b 45 10          	mov    0x10(%rbp),%rax
 12110fa:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 12110ff:	c5 fc 10 84 24 20 02 	vmovups 0x220(%rsp),%ymm0
 1211106:	00 00 
 1211108:	c5 fc 10 8c 24 40 02 	vmovups 0x240(%rsp),%ymm1
 121110f:	00 00 
 1211111:	c5 fc 10 94 24 60 02 	vmovups 0x260(%rsp),%ymm2
 1211118:	00 00 
 121111a:	c5 fc 10 9c 24 80 02 	vmovups 0x280(%rsp),%ymm3
 1211121:	00 00 
 1211123:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1211128:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 121112d:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1211132:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1211136:	48 8b 54 24 50       	mov    0x50(%rsp),%rdx
 121113b:	66 c7 82 60 01 00 00 	movw   $0x0,0x160(%rdx)
 1211142:	00 00 
 1211144:	4c 89 2a             	mov    %r13,(%rdx)
 1211147:	4c 89 7a 08          	mov    %r15,0x8(%rdx)
 121114b:	8b 44 24 40          	mov    0x40(%rsp),%eax
 121114f:	88 82 58 01 00 00    	mov    %al,0x158(%rdx)
 1211155:	48 8b 44 24 68       	mov    0x68(%rsp),%rax
 121115a:	48 89 42 10          	mov    %rax,0x10(%rdx)
 121115e:	0f b6 44 24 28       	movzbl 0x28(%rsp),%eax
 1211163:	88 42 18             	mov    %al,0x18(%rdx)
 1211166:	0f b6 44 24 1e       	movzbl 0x1e(%rsp),%eax
 121116b:	88 42 19             	mov    %al,0x19(%rdx)
 121116e:	c5 fc 28 84 24 40 01 	vmovaps 0x140(%rsp),%ymm0
 1211175:	00 00 
 1211177:	c5 fc 11 42 1a       	vmovups %ymm0,0x1a(%rdx)
 121117c:	c5 fc 28 84 24 00 01 	vmovaps 0x100(%rsp),%ymm0
 1211183:	00 00 
 1211185:	c5 fc 11 42 3a       	vmovups %ymm0,0x3a(%rdx)
 121118a:	8b 44 24 30          	mov    0x30(%rsp),%eax
 121118e:	89 42 5a             	mov    %eax,0x5a(%rdx)
 1211191:	0f b7 44 24 34       	movzwl 0x34(%rsp),%eax
 1211196:	66 89 42 5e          	mov    %ax,0x5e(%rdx)
 121119a:	44 88 72 60          	mov    %r14b,0x60(%rdx)
 121119e:	8b 84 24 80 00 00 00 	mov    0x80(%rsp),%eax
 12111a5:	8b 8c 24 83 00 00 00 	mov    0x83(%rsp),%ecx
 12111ac:	89 42 61             	mov    %eax,0x61(%rdx)
 12111af:	89 4a 64             	mov    %ecx,0x64(%rdx)
 12111b2:	c5 fc 10 84 24 b8 02 	vmovups 0x2b8(%rsp),%ymm0
 12111b9:	00 00 
 12111bb:	c5 fc 10 8c 24 d8 02 	vmovups 0x2d8(%rsp),%ymm1
 12111c2:	00 00 
 12111c4:	c5 fc 10 94 24 f8 02 	vmovups 0x2f8(%rsp),%ymm2
 12111cb:	00 00 
 12111cd:	c5 fc 10 9c 24 18 03 	vmovups 0x318(%rsp),%ymm3
 12111d4:	00 00 
 12111d6:	c5 fc 11 42 68       	vmovups %ymm0,0x68(%rdx)
 12111db:	c5 fc 11 8a 88 00 00 	vmovups %ymm1,0x88(%rdx)
 12111e2:	00 
 12111e3:	c5 fc 11 92 a8 00 00 	vmovups %ymm2,0xa8(%rdx)
 12111ea:	00 
 12111eb:	c5 fc 11 9a c8 00 00 	vmovups %ymm3,0xc8(%rdx)
 12111f2:	00 
 12111f3:	c5 fc 10 84 24 38 03 	vmovups 0x338(%rsp),%ymm0
 12111fa:	00 00 
 12111fc:	c5 fc 11 82 e8 00 00 	vmovups %ymm0,0xe8(%rdx)
 1211203:	00 
 1211204:	c5 fc 10 84 24 58 03 	vmovups 0x358(%rsp),%ymm0
 121120b:	00 00 
 121120d:	c5 fc 11 82 08 01 00 	vmovups %ymm0,0x108(%rdx)
 1211214:	00 
 1211215:	c5 fc 10 84 24 78 03 	vmovups 0x378(%rsp),%ymm0
 121121c:	00 00 
 121121e:	c5 fc 11 82 28 01 00 	vmovups %ymm0,0x128(%rdx)
 1211225:	00 
 1211226:	c5 fe 6f 84 24 88 03 	vmovdqu 0x388(%rsp),%ymm0
 121122d:	00 00 
 121122f:	c5 fe 7f 82 38 01 00 	vmovdqu %ymm0,0x138(%rdx)
 1211236:	00 
 1211237:	80 e3 03             	and    $0x3,%bl
 121123a:	88 9a 59 01 00 00    	mov    %bl,0x159(%rdx)
 1211240:	e9 45 01 00 00       	jmp    121138a <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x16ba>
 1211245:	c5 fc 10 84 24 90 02 	vmovups 0x290(%rsp),%ymm0
 121124c:	00 00 
 121124e:	48 8b 45 10          	mov    0x10(%rbp),%rax
 1211252:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1211257:	c5 fc 10 84 24 20 02 	vmovups 0x220(%rsp),%ymm0
 121125e:	00 00 
 1211260:	c5 fc 10 8c 24 40 02 	vmovups 0x240(%rsp),%ymm1
 1211267:	00 00 
 1211269:	c5 fc 10 94 24 60 02 	vmovups 0x260(%rsp),%ymm2
 1211270:	00 00 
 1211272:	c5 fc 10 9c 24 80 02 	vmovups 0x280(%rsp),%ymm3
 1211279:	00 00 
 121127b:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1211280:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1211285:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 121128a:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 121128e:	48 8b 54 24 50       	mov    0x50(%rsp),%rdx
 1211293:	66 c7 82 60 01 00 00 	movw   $0x0,0x160(%rdx)
 121129a:	00 00 
 121129c:	4c 89 12             	mov    %r10,(%rdx)
 121129f:	48 8b 44 24 38       	mov    0x38(%rsp),%rax
 12112a4:	48 89 42 08          	mov    %rax,0x8(%rdx)
 12112a8:	c6 82 58 01 00 00 00 	movb   $0x0,0x158(%rdx)
 12112af:	48 8b 44 24 68       	mov    0x68(%rsp),%rax
 12112b4:	48 89 42 10          	mov    %rax,0x10(%rdx)
 12112b8:	0f b6 44 24 28       	movzbl 0x28(%rsp),%eax
 12112bd:	88 42 18             	mov    %al,0x18(%rdx)
 12112c0:	0f b6 44 24 1e       	movzbl 0x1e(%rsp),%eax
 12112c5:	88 42 19             	mov    %al,0x19(%rdx)
 12112c8:	c5 fe 7f 6a 1a       	vmovdqu %ymm5,0x1a(%rdx)
 12112cd:	c5 fe 7f 62 3a       	vmovdqu %ymm4,0x3a(%rdx)
 12112d2:	8b 44 24 30          	mov    0x30(%rsp),%eax
 12112d6:	89 42 5a             	mov    %eax,0x5a(%rdx)
 12112d9:	0f b7 44 24 34       	movzwl 0x34(%rsp),%eax
 12112de:	66 89 42 5e          	mov    %ax,0x5e(%rdx)
 12112e2:	44 88 5a 60          	mov    %r11b,0x60(%rdx)
 12112e6:	8b 84 24 80 00 00 00 	mov    0x80(%rsp),%eax
 12112ed:	8b 8c 24 83 00 00 00 	mov    0x83(%rsp),%ecx
 12112f4:	89 42 61             	mov    %eax,0x61(%rdx)
 12112f7:	89 4a 64             	mov    %ecx,0x64(%rdx)
 12112fa:	c5 fc 10 84 24 b8 02 	vmovups 0x2b8(%rsp),%ymm0
 1211301:	00 00 
 1211303:	c5 fc 10 8c 24 d8 02 	vmovups 0x2d8(%rsp),%ymm1
 121130a:	00 00 
 121130c:	c5 fc 10 94 24 f8 02 	vmovups 0x2f8(%rsp),%ymm2
 1211313:	00 00 
 1211315:	c5 fc 10 9c 24 18 03 	vmovups 0x318(%rsp),%ymm3
 121131c:	00 00 
 121131e:	c5 fc 11 42 68       	vmovups %ymm0,0x68(%rdx)
 1211323:	c5 fc 11 8a 88 00 00 	vmovups %ymm1,0x88(%rdx)
 121132a:	00 
 121132b:	c5 fc 11 92 a8 00 00 	vmovups %ymm2,0xa8(%rdx)
 1211332:	00 
 1211333:	c5 fc 11 9a c8 00 00 	vmovups %ymm3,0xc8(%rdx)
 121133a:	00 
 121133b:	c5 fc 10 84 24 38 03 	vmovups 0x338(%rsp),%ymm0
 1211342:	00 00 
 1211344:	c5 fc 11 82 e8 00 00 	vmovups %ymm0,0xe8(%rdx)
 121134b:	00 
 121134c:	c5 fc 10 84 24 58 03 	vmovups 0x358(%rsp),%ymm0
 1211353:	00 00 
 1211355:	c5 fc 11 82 08 01 00 	vmovups %ymm0,0x108(%rdx)
 121135c:	00 
 121135d:	c5 fc 10 84 24 78 03 	vmovups 0x378(%rsp),%ymm0
 1211364:	00 00 
 1211366:	c5 fc 11 82 28 01 00 	vmovups %ymm0,0x128(%rdx)
 121136d:	00 
 121136e:	c5 fe 6f 84 24 88 03 	vmovdqu 0x388(%rsp),%ymm0
 1211375:	00 00 
 1211377:	c5 fe 7f 82 38 01 00 	vmovdqu %ymm0,0x138(%rdx)
 121137e:	00 
 121137f:	41 80 e7 03          	and    $0x3,%r15b
 1211383:	44 88 ba 59 01 00 00 	mov    %r15b,0x159(%rdx)
 121138a:	48 8b 84 24 c0 00 00 	mov    0xc0(%rsp),%rax
 1211391:	00 
 1211392:	24 01                	and    $0x1,%al
 1211394:	88 82 5a 01 00 00    	mov    %al,0x15a(%rdx)
 121139a:	0f b7 44 24 2e       	movzwl 0x2e(%rsp),%eax
 121139f:	66 89 82 5b 01 00 00 	mov    %ax,0x15b(%rdx)
 12113a6:	e9 04 01 00 00       	jmp    12114af <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17df>
 12113ab:	4d 85 c9             	test   %r9,%r9
 12113ae:	74 1b                	je     12113cb <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x16fb>
 12113b0:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 12113b5:	48 8b 38             	mov    (%rax),%rdi
 12113b8:	48 8b 40 08          	mov    0x8(%rax),%rax
 12113bc:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12113c0:	4c 89 ee             	mov    %r13,%rsi
 12113c3:	4c 89 ca             	mov    %r9,%rdx
 12113c6:	31 c9                	xor    %ecx,%ecx
 12113c8:	ff 50 18             	call   *0x18(%rax)
 12113cb:	c5 fc 10 84 24 e0 06 	vmovups 0x6e0(%rsp),%ymm0
 12113d2:	00 00 
 12113d4:	48 8b 45 10          	mov    0x10(%rbp),%rax
 12113d8:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 12113dd:	c5 fe 6f 84 24 70 06 	vmovdqu 0x670(%rsp),%ymm0
 12113e4:	00 00 
 12113e6:	c5 fc 10 8c 24 90 06 	vmovups 0x690(%rsp),%ymm1
 12113ed:	00 00 
 12113ef:	c5 fc 10 94 24 b0 06 	vmovups 0x6b0(%rsp),%ymm2
 12113f6:	00 00 
 12113f8:	c5 fc 10 9c 24 d0 06 	vmovups 0x6d0(%rsp),%ymm3
 12113ff:	00 00 
 1211401:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1211406:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 121140b:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1211410:	c5 fe 7f 00          	vmovdqu %ymm0,(%rax)
 1211414:	48 8b 44 24 50       	mov    0x50(%rsp),%rax
 1211419:	66 c7 80 60 01 00 00 	movw   $0x0,0x160(%rax)
 1211420:	00 00 
 1211422:	4c 89 20             	mov    %r12,(%rax)
 1211425:	4c 89 78 08          	mov    %r15,0x8(%rax)
 1211429:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 121142d:	c5 fe 7f 40 10       	vmovdqu %ymm0,0x10(%rax)
 1211432:	c5 fe 7f 40 30       	vmovdqu %ymm0,0x30(%rax)
 1211437:	c5 fe 7f 40 48       	vmovdqu %ymm0,0x48(%rax)
 121143c:	c7 80 58 01 00 00 00 	movl   $0x0,0x158(%rax)
 1211443:	00 00 00 
 1211446:	c6 80 5c 01 00 00 00 	movb   $0x0,0x15c(%rax)
 121144d:	eb 60                	jmp    12114af <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17df>
 121144f:	48 85 d2             	test   %rdx,%rdx
 1211452:	74 42                	je     1211496 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17c6>
 1211454:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 1211459:	48 8b 38             	mov    (%rax),%rdi
 121145c:	48 8b 40 08          	mov    0x8(%rax),%rax
 1211460:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1211464:	48 8b 74 24 60       	mov    0x60(%rsp),%rsi
 1211469:	31 c9                	xor    %ecx,%ecx
 121146b:	eb 23                	jmp    1211490 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17c0>
 121146d:	4d 85 ff             	test   %r15,%r15
 1211470:	48 8b b4 24 b8 00 00 	mov    0xb8(%rsp),%rsi
 1211477:	00 
 1211478:	74 1c                	je     1211496 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17c6>
 121147a:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 121147f:	48 8b 38             	mov    (%rax),%rdi
 1211482:	48 8b 40 08          	mov    0x8(%rax),%rax
 1211486:	4c 89 fa             	mov    %r15,%rdx
 1211489:	31 c9                	xor    %ecx,%ecx
 121148b:	4c 8b 44 24 38       	mov    0x38(%rsp),%r8
 1211490:	c5 f8 77             	vzeroupper 
 1211493:	ff 50 18             	call   *0x18(%rax)
 1211496:	48 8d 35 d3 df e2 ff 	lea    -0x1d202d(%rip),%rsi        # 103f470 <__anon_46311>
 121149d:	ba 68 01 00 00       	mov    $0x168,%edx
 12114a2:	48 8b 7c 24 50       	mov    0x50(%rsp),%rdi
 12114a7:	c5 f8 77             	vzeroupper 
 12114aa:	e8 11 4c 08 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 12114af:	48 8d 65 d8          	lea    -0x28(%rbp),%rsp
 12114b3:	5b                   	pop    %rbx
 12114b4:	41 5c                	pop    %r12
 12114b6:	41 5d                	pop    %r13
 12114b8:	41 5e                	pop    %r14
 12114ba:	41 5f                	pop    %r15
 12114bc:	5d                   	pop    %rbp
 12114bd:	c5 f8 77             	vzeroupper 
 12114c0:	c3                   	ret    
 12114c1:	c5 fc 10 84 24 90 02 	vmovups 0x290(%rsp),%ymm0
 12114c8:	00 00 
 12114ca:	48 8b 45 10          	mov    0x10(%rbp),%rax
 12114ce:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 12114d3:	c5 fc 10 84 24 20 02 	vmovups 0x220(%rsp),%ymm0
 12114da:	00 00 
 12114dc:	c5 fc 10 8c 24 40 02 	vmovups 0x240(%rsp),%ymm1
 12114e3:	00 00 
 12114e5:	c5 fc 10 94 24 60 02 	vmovups 0x260(%rsp),%ymm2
 12114ec:	00 00 
 12114ee:	c5 fc 10 9c 24 80 02 	vmovups 0x280(%rsp),%ymm3
 12114f5:	00 00 
 12114f7:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 12114fc:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1211501:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1211506:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 121150a:	48 8b 54 24 50       	mov    0x50(%rsp),%rdx
 121150f:	66 c7 82 60 01 00 00 	movw   $0x0,0x160(%rdx)
 1211516:	00 00 
 1211518:	4c 89 12             	mov    %r10,(%rdx)
 121151b:	48 8b 44 24 38       	mov    0x38(%rsp),%rax
 1211520:	48 89 42 08          	mov    %rax,0x8(%rdx)
 1211524:	8b 44 24 40          	mov    0x40(%rsp),%eax
 1211528:	88 82 58 01 00 00    	mov    %al,0x158(%rdx)
 121152e:	e9 7c fd ff ff       	jmp    12112af <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x15df>
 1211533:	48 8b 54 24 38       	mov    0x38(%rsp),%rdx
 1211538:	48 85 d2             	test   %rdx,%rdx
 121153b:	74 1a                	je     1211557 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1887>
 121153d:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 1211542:	48 8b 38             	mov    (%rax),%rdi
 1211545:	48 8b 40 08          	mov    0x8(%rax),%rax
 1211549:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 121154d:	48 8b 74 24 60       	mov    0x60(%rsp),%rsi
 1211552:	31 c9                	xor    %ecx,%ecx
 1211554:	ff 50 18             	call   *0x18(%rax)
 1211557:	48 8b 44 24 50       	mov    0x50(%rsp),%rax
 121155c:	66 44 89 b8 60 01 00 	mov    %r15w,0x160(%rax)
 1211563:	00 
 1211564:	e9 46 ff ff ff       	jmp    12114af <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17df>
 1211569:	48 8b 4c 24 50       	mov    0x50(%rsp),%rcx
 121156e:	66 89 81 60 01 00 00 	mov    %ax,0x160(%rcx)
 1211575:	e9 35 ff ff ff       	jmp    12114af <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17df>
 121157a:	48 8b 54 24 38       	mov    0x38(%rsp),%rdx
 121157f:	48 85 d2             	test   %rdx,%rdx
 1211582:	74 1a                	je     121159e <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x18ce>
 1211584:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 1211589:	48 8b 38             	mov    (%rax),%rdi
 121158c:	48 8b 40 08          	mov    0x8(%rax),%rax
 1211590:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1211594:	48 8b 74 24 60       	mov    0x60(%rsp),%rsi
 1211599:	31 c9                	xor    %ecx,%ecx
 121159b:	ff 50 18             	call   *0x18(%rax)
 121159e:	48 8b 44 24 50       	mov    0x50(%rsp),%rax
 12115a3:	66 44 89 b0 60 01 00 	mov    %r14w,0x160(%rax)
 12115aa:	00 
 12115ab:	e9 ff fe ff ff       	jmp    12114af <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17df>
 12115b0:	48 8b 54 24 38       	mov    0x38(%rsp),%rdx
 12115b5:	48 85 d2             	test   %rdx,%rdx
 12115b8:	74 18                	je     12115d2 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1902>
 12115ba:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 12115bf:	48 8b 38             	mov    (%rax),%rdi
 12115c2:	48 8b 40 08          	mov    0x8(%rax),%rax
 12115c6:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12115ca:	4c 89 ee             	mov    %r13,%rsi
 12115cd:	31 c9                	xor    %ecx,%ecx
 12115cf:	ff 50 18             	call   *0x18(%rax)
 12115d2:	48 8b 44 24 50       	mov    0x50(%rsp),%rax
 12115d7:	66 89 98 60 01 00 00 	mov    %bx,0x160(%rax)
 12115de:	e9 cc fe ff ff       	jmp    12114af <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17df>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
