
/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/78f0aed58c7f51384364cb890565eb73/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000120fdc0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479>:
 120fdc0:	55                   	push   %rbp
 120fdc1:	48 89 e5             	mov    %rsp,%rbp
 120fdc4:	41 57                	push   %r15
 120fdc6:	41 56                	push   %r14
 120fdc8:	41 55                	push   %r13
 120fdca:	41 54                	push   %r12
 120fdcc:	53                   	push   %rbx
 120fdcd:	48 83 e4 e0          	and    $0xffffffffffffffe0,%rsp
 120fdd1:	48 81 ec c0 10 00 00 	sub    $0x10c0,%rsp
 120fdd8:	4c 89 84 24 b0 00 00 	mov    %r8,0xb0(%rsp)
 120fddf:	00 
 120fde0:	48 89 8c 24 a8 00 00 	mov    %rcx,0xa8(%rsp)
 120fde7:	00 
 120fde8:	48 89 94 24 c8 00 00 	mov    %rdx,0xc8(%rsp)
 120fdef:	00 
 120fdf0:	48 89 74 24 48       	mov    %rsi,0x48(%rsp)
 120fdf5:	48 89 7c 24 50       	mov    %rdi,0x50(%rsp)
 120fdfa:	48 8b 45 18          	mov    0x18(%rbp),%rax
 120fdfe:	48 8b 08             	mov    (%rax),%rcx
 120fe01:	48 89 8c 24 f0 00 00 	mov    %rcx,0xf0(%rsp)
 120fe08:	00 
 120fe09:	48 8b 48 08          	mov    0x8(%rax),%rcx
 120fe0d:	48 89 8c 24 e8 00 00 	mov    %rcx,0xe8(%rsp)
 120fe14:	00 
 120fe15:	48 8b 48 10          	mov    0x10(%rax),%rcx
 120fe19:	48 89 8c 24 e0 00 00 	mov    %rcx,0xe0(%rsp)
 120fe20:	00 
 120fe21:	48 8b 48 18          	mov    0x18(%rax),%rcx
 120fe25:	48 89 8c 24 d8 00 00 	mov    %rcx,0xd8(%rsp)
 120fe2c:	00 
 120fe2d:	c5 fe 6f 40 20       	vmovdqu 0x20(%rax),%ymm0
 120fe32:	c5 fe 7f 84 24 f0 03 	vmovdqu %ymm0,0x3f0(%rsp)
 120fe39:	00 00 
 120fe3b:	0f b6 50 40          	movzbl 0x40(%rax),%edx
 120fe3f:	88 54 24 20          	mov    %dl,0x20(%rsp)
 120fe43:	44 0f b6 40 41       	movzbl 0x41(%rax),%r8d
 120fe48:	44 0f b6 50 42       	movzbl 0x42(%rax),%r10d
 120fe4d:	44 0f b6 58 43       	movzbl 0x43(%rax),%r11d
 120fe52:	0f b6 48 44          	movzbl 0x44(%rax),%ecx
 120fe56:	88 8c 24 80 01 00 00 	mov    %cl,0x180(%rsp)
 120fe5d:	0f b6 70 46          	movzbl 0x46(%rax),%esi
 120fe61:	0f b6 78 47          	movzbl 0x47(%rax),%edi
 120fe65:	0f b6 48 4e          	movzbl 0x4e(%rax),%ecx
 120fe69:	41 f6 c0 01          	test   $0x1,%r8b
 120fe6d:	4c 89 8c 24 d0 00 00 	mov    %r9,0xd0(%rsp)
 120fe74:	00 
 120fe75:	88 4c 24 1f          	mov    %cl,0x1f(%rsp)
 120fe79:	0f 84 bd 01 00 00    	je     121003c <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x27c>
 120fe7f:	48 83 c0 20          	add    $0x20,%rax
 120fe83:	c5 fe 6f 00          	vmovdqu (%rax),%ymm0
 120fe87:	c5 fe 7f 84 24 20 01 	vmovdqu %ymm0,0x120(%rsp)
 120fe8e:	00 00 
 120fe90:	89 c8                	mov    %ecx,%eax
 120fe92:	24 1f                	and    $0x1f,%al
 120fe94:	88 44 24 47          	mov    %al,0x47(%rsp)
 120fe98:	4d 85 c9             	test   %r9,%r9
 120fe9b:	0f 84 9b 01 00 00    	je     121003c <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x27c>
 120fea1:	44 88 9c 24 00 01 00 	mov    %r11b,0x100(%rsp)
 120fea8:	00 
 120fea9:	44 88 54 24 60       	mov    %r10b,0x60(%rsp)
 120feae:	44 88 44 24 68       	mov    %r8b,0x68(%rsp)
 120feb3:	40 88 bc 24 88 00 00 	mov    %dil,0x88(%rsp)
 120feba:	00 
 120febb:	40 88 b4 24 60 01 00 	mov    %sil,0x160(%rsp)
 120fec2:	00 
 120fec3:	88 54 24 38          	mov    %dl,0x38(%rsp)
 120fec7:	0f b6 05 ba 2c e0 ff 	movzbl -0x1fd346(%rip),%eax        # 1012b88 <__anon_35632>
 120fece:	48 8b 9c 24 28 01 00 	mov    0x128(%rsp),%rbx
 120fed5:	00 
 120fed6:	4c 8b bc 24 30 01 00 	mov    0x130(%rsp),%r15
 120fedd:	00 
 120fede:	4c 8b a4 24 38 01 00 	mov    0x138(%rsp),%r12
 120fee5:	00 
 120fee6:	31 f6                	xor    %esi,%esi
 120fee8:	0f b6 4c 24 47       	movzbl 0x47(%rsp),%ecx
 120feed:	89 4c 24 28          	mov    %ecx,0x28(%rsp)
 120fef1:	24 0f                	and    $0xf,%al
 120fef3:	88 44 24 1e          	mov    %al,0x1e(%rsp)
 120fef7:	4c 8b ac 24 b0 00 00 	mov    0xb0(%rsp),%r13
 120fefe:	00 
 120feff:	4d 89 ce             	mov    %r9,%r14
 120ff02:	eb 2b                	jmp    120ff2f <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x16f>
 120ff04:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 120ff0b:	00 00 00 00 00 
 120ff10:	4c 89 e1             	mov    %r12,%rcx
 120ff13:	4d 89 fc             	mov    %r15,%r12
 120ff16:	49 89 df             	mov    %rbx,%r15
 120ff19:	4c 89 fb             	mov    %r15,%rbx
 120ff1c:	4d 89 e7             	mov    %r12,%r15
 120ff1f:	49 83 c5 60          	add    $0x60,%r13
 120ff23:	49 89 cc             	mov    %rcx,%r12
 120ff26:	49 ff ce             	dec    %r14
 120ff29:	0f 84 17 01 00 00    	je     1210046 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x286>
 120ff2f:	c4 c1 7e 6f 45 00    	vmovdqu 0x0(%r13),%ymm0
 120ff35:	c4 c1 7c 10 4d 20    	vmovups 0x20(%r13),%ymm1
 120ff3b:	c4 c1 7c 10 55 40    	vmovups 0x40(%r13),%ymm2
 120ff41:	c5 fc 11 94 24 00 02 	vmovups %ymm2,0x200(%rsp)
 120ff48:	00 00 
 120ff4a:	c5 fc 11 8c 24 e0 01 	vmovups %ymm1,0x1e0(%rsp)
 120ff51:	00 00 
 120ff53:	c5 fe 7f 84 24 c0 01 	vmovdqu %ymm0,0x1c0(%rsp)
 120ff5a:	00 00 
 120ff5c:	f6 84 24 18 02 00 00 	testb  $0x1,0x218(%rsp)
 120ff63:	01 
 120ff64:	74 aa                	je     120ff10 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x150>
 120ff66:	0f b6 84 24 19 02 00 	movzbl 0x219(%rsp),%eax
 120ff6d:	00 
 120ff6e:	24 03                	and    $0x3,%al
 120ff70:	3c 02                	cmp    $0x2,%al
 120ff72:	74 9c                	je     120ff10 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x150>
 120ff74:	48 89 b4 24 90 00 00 	mov    %rsi,0x90(%rsp)
 120ff7b:	00 
 120ff7c:	48 8d bc 24 b0 01 00 	lea    0x1b0(%rsp),%rdi
 120ff83:	00 
 120ff84:	48 8d b4 24 c0 01 00 	lea    0x1c0(%rsp),%rsi
 120ff8b:	00 
 120ff8c:	8b 54 24 28          	mov    0x28(%rsp),%edx
 120ff90:	48 8b 8c 24 e0 00 00 	mov    0xe0(%rsp),%rcx
 120ff97:	00 
 120ff98:	4c 8b 84 24 d8 00 00 	mov    0xd8(%rsp),%r8
 120ff9f:	00 
 120ffa0:	c5 f8 77             	vzeroupper 
 120ffa3:	e8 78 f4 fa ff       	call   11bf420 <br.commandWireDistance>
 120ffa8:	0f b7 84 24 b8 01 00 	movzwl 0x1b8(%rsp),%eax
 120ffaf:	00 
 120ffb0:	66 85 c0             	test   %ax,%ax
 120ffb3:	0f 85 b0 16 00 00    	jne    1211669 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x18a9>
 120ffb9:	48 8b b4 24 b0 01 00 	mov    0x1b0(%rsp),%rsi
 120ffc0:	00 
 120ffc1:	48 8d 7c 24 5e       	lea    0x5e(%rsp),%rdi
 120ffc6:	48 89 74 24 78       	mov    %rsi,0x78(%rsp)
 120ffcb:	48 8d 94 24 20 01 00 	lea    0x120(%rsp),%rdx
 120ffd2:	00 
 120ffd3:	e8 18 ee fa ff       	call   11bedf0 <br.decoder.distance_history.symbolForDistance>
 120ffd8:	0f b6 4c 24 5f       	movzbl 0x5f(%rsp),%ecx
 120ffdd:	48 8b b4 24 90 00 00 	mov    0x90(%rsp),%rsi
 120ffe4:	00 
 120ffe5:	48 8d 46 01          	lea    0x1(%rsi),%rax
 120ffe9:	84 c9                	test   %cl,%cl
 120ffeb:	74 1f                	je     121000c <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x24c>
 120ffed:	0f b6 54 24 5e       	movzbl 0x5e(%rsp),%edx
 120fff2:	80 e2 0f             	and    $0xf,%dl
 120fff5:	3a 54 24 1e          	cmp    0x1e(%rsp),%dl
 120fff9:	75 11                	jne    121000c <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x24c>
 120fffb:	4c 89 e1             	mov    %r12,%rcx
 120fffe:	4d 89 fc             	mov    %r15,%r12
 1210001:	49 89 df             	mov    %rbx,%r15
 1210004:	48 89 c6             	mov    %rax,%rsi
 1210007:	e9 0d ff ff ff       	jmp    120ff19 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x159>
 121000c:	84 c9                	test   %cl,%cl
 121000e:	48 0f 45 f0          	cmovne %rax,%rsi
 1210012:	48 89 9c 24 20 01 00 	mov    %rbx,0x120(%rsp)
 1210019:	00 
 121001a:	4c 89 bc 24 28 01 00 	mov    %r15,0x128(%rsp)
 1210021:	00 
 1210022:	4c 89 a4 24 30 01 00 	mov    %r12,0x130(%rsp)
 1210029:	00 
 121002a:	48 8b 4c 24 78       	mov    0x78(%rsp),%rcx
 121002f:	48 89 8c 24 38 01 00 	mov    %rcx,0x138(%rsp)
 1210036:	00 
 1210037:	e9 dd fe ff ff       	jmp    120ff19 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x159>
 121003c:	c7 44 24 40 00 00 00 	movl   $0x0,0x40(%rsp)
 1210043:	00 
 1210044:	eb 35                	jmp    121007b <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x2bb>
 1210046:	48 83 fe 40          	cmp    $0x40,%rsi
 121004a:	0f 93 c0             	setae  %al
 121004d:	89 44 24 40          	mov    %eax,0x40(%rsp)
 1210051:	0f b6 54 24 38       	movzbl 0x38(%rsp),%edx
 1210056:	0f b6 b4 24 60 01 00 	movzbl 0x160(%rsp),%esi
 121005d:	00 
 121005e:	0f b6 bc 24 88 00 00 	movzbl 0x88(%rsp),%edi
 1210065:	00 
 1210066:	44 0f b6 44 24 68    	movzbl 0x68(%rsp),%r8d
 121006c:	44 0f b6 54 24 60    	movzbl 0x60(%rsp),%r10d
 1210072:	44 0f b6 9c 24 00 01 	movzbl 0x100(%rsp),%r11d
 1210079:	00 00 
 121007b:	45 84 db             	test   %r11b,%r11b
 121007e:	0f 95 c0             	setne  %al
 1210081:	41 0f b6 ca          	movzbl %r10b,%ecx
 1210085:	41 0f b6 d8          	movzbl %r8b,%ebx
 1210089:	0f 45 d9             	cmovne %ecx,%ebx
 121008c:	20 c1                	and    %al,%cl
 121008e:	89 8c 24 f8 00 00 00 	mov    %ecx,0xf8(%rsp)
 1210095:	75 21                	jne    12100b8 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x2f8>
 1210097:	80 7c 24 40 00       	cmpb   $0x0,0x40(%rsp)
 121009c:	75 1a                	jne    12100b8 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x2f8>
 121009e:	4c 8d 3d 8b 22 e0 ff 	lea    -0x1fdd75(%rip),%r15        # 1012330 <__anon_35262>
 12100a5:	4c 8d 2d 8d 22 e0 ff 	lea    -0x1fdd73(%rip),%r13        # 1012339 <__anon_35262+0x9>
 12100ac:	4c 8d 25 ce 22 e0 ff 	lea    -0x1fdd32(%rip),%r12        # 1012381 <__anon_35262+0x51>
 12100b3:	e9 d6 00 00 00       	jmp    121018e <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x3ce>
 12100b8:	4c 8d a4 24 f9 04 00 	lea    0x4f9(%rsp),%r12
 12100bf:	00 
 12100c0:	4c 8d ac 24 b1 04 00 	lea    0x4b1(%rsp),%r13
 12100c7:	00 
 12100c8:	31 c0                	xor    %eax,%eax
 12100ca:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 12100d0:	48 83 f8 38          	cmp    $0x38,%rax
 12100d4:	0f 93 84 04 c0 01 00 	setae  0x1c0(%rsp,%rax,1)
 12100db:	00 
 12100dc:	0f 93 84 04 c1 01 00 	setae  0x1c1(%rsp,%rax,1)
 12100e3:	00 
 12100e4:	0f 93 84 04 c2 01 00 	setae  0x1c2(%rsp,%rax,1)
 12100eb:	00 
 12100ec:	0f 93 84 04 c3 01 00 	setae  0x1c3(%rsp,%rax,1)
 12100f3:	00 
 12100f4:	0f 93 84 04 c4 01 00 	setae  0x1c4(%rsp,%rax,1)
 12100fb:	00 
 12100fc:	0f 93 84 04 c5 01 00 	setae  0x1c5(%rsp,%rax,1)
 1210103:	00 
 1210104:	0f 93 84 04 c6 01 00 	setae  0x1c6(%rsp,%rax,1)
 121010b:	00 
 121010c:	0f 93 84 04 c7 01 00 	setae  0x1c7(%rsp,%rax,1)
 1210113:	00 
 1210114:	48 83 c0 08          	add    $0x8,%rax
 1210118:	48 83 f8 40          	cmp    $0x40,%rax
 121011c:	75 b2                	jne    12100d0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x310>
 121011e:	40 84 ff             	test   %dil,%dil
 1210121:	40 0f b6 c6          	movzbl %sil,%eax
 1210125:	b9 02 00 00 00       	mov    $0x2,%ecx
 121012a:	0f 45 c8             	cmovne %eax,%ecx
 121012d:	80 e1 03             	and    $0x3,%cl
 1210130:	88 8c 24 98 00 00 00 	mov    %cl,0x98(%rsp)
 1210137:	c5 fe 6f 84 24 c0 01 	vmovdqu 0x1c0(%rsp),%ymm0
 121013e:	00 00 
 1210140:	c5 fc 10 8c 24 e0 01 	vmovups 0x1e0(%rsp),%ymm1
 1210147:	00 00 
 1210149:	c5 fe 7f 84 24 b2 04 	vmovdqu %ymm0,0x4b2(%rsp)
 1210150:	00 00 
 1210152:	c5 fc 11 8c 24 d2 04 	vmovups %ymm1,0x4d2(%rsp)
 1210159:	00 00 
 121015b:	c6 84 24 a5 00 00 00 	movb   $0x2,0xa5(%rsp)
 1210162:	02 
 1210163:	48 c7 84 24 a8 04 00 	movq   $0x0,0x4a8(%rsp)
 121016a:	00 00 00 00 00 
 121016f:	88 8c 24 b0 04 00 00 	mov    %cl,0x4b0(%rsp)
 1210176:	c6 84 24 b1 04 00 00 	movb   $0x2,0x4b1(%rsp)
 121017d:	02 
 121017e:	c6 84 24 f8 04 00 00 	movb   $0x1,0x4f8(%rsp)
 1210185:	01 
 1210186:	4c 8d bc 24 a8 04 00 	lea    0x4a8(%rsp),%r15
 121018d:	00 
 121018e:	c5 fc 10 84 24 f0 03 	vmovups 0x3f0(%rsp),%ymm0
 1210195:	00 00 
 1210197:	c5 fc 11 84 24 28 07 	vmovups %ymm0,0x728(%rsp)
 121019e:	00 00 
 12101a0:	80 e2 01             	and    $0x1,%dl
 12101a3:	88 94 24 29 09 00 00 	mov    %dl,0x929(%rsp)
 12101aa:	48 c7 84 24 18 07 00 	movq   $0x0,0x718(%rsp)
 12101b1:	00 00 00 00 00 
 12101b6:	8b 44 24 40          	mov    0x40(%rsp),%eax
 12101ba:	88 84 24 2d 09 00 00 	mov    %al,0x92d(%rsp)
 12101c1:	c6 84 24 2c 09 00 00 	movb   $0x0,0x92c(%rsp)
 12101c8:	00 
 12101c9:	c4 c1 7c 10 07       	vmovups (%r15),%ymm0
 12101ce:	c4 c1 7c 10 4f 20    	vmovups 0x20(%r15),%ymm1
 12101d4:	c5 fc 11 84 24 48 07 	vmovups %ymm0,0x748(%rsp)
 12101db:	00 00 
 12101dd:	c5 fc 11 8c 24 68 07 	vmovups %ymm1,0x768(%rsp)
 12101e4:	00 00 
 12101e6:	c4 c1 7c 10 47 38    	vmovups 0x38(%r15),%ymm0
 12101ec:	c5 fc 11 84 24 80 07 	vmovups %ymm0,0x780(%rsp)
 12101f3:	00 00 
 12101f5:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 12101f9:	c5 fc 11 84 24 f0 08 	vmovups %ymm0,0x8f0(%rsp)
 1210200:	00 00 
 1210202:	c5 fc 11 84 24 e0 08 	vmovups %ymm0,0x8e0(%rsp)
 1210209:	00 00 
 121020b:	c5 fc 11 84 24 c0 08 	vmovups %ymm0,0x8c0(%rsp)
 1210212:	00 00 
 1210214:	c5 fc 11 84 24 a0 08 	vmovups %ymm0,0x8a0(%rsp)
 121021b:	00 00 
 121021d:	c5 fc 11 84 24 80 08 	vmovups %ymm0,0x880(%rsp)
 1210224:	00 00 
 1210226:	c5 fc 11 84 24 60 08 	vmovups %ymm0,0x860(%rsp)
 121022d:	00 00 
 121022f:	c5 fc 11 84 24 40 08 	vmovups %ymm0,0x840(%rsp)
 1210236:	00 00 
 1210238:	c5 fc 11 84 24 20 08 	vmovups %ymm0,0x820(%rsp)
 121023f:	00 00 
 1210241:	c5 fc 11 84 24 00 08 	vmovups %ymm0,0x800(%rsp)
 1210248:	00 00 
 121024a:	c5 fc 11 84 24 e0 07 	vmovups %ymm0,0x7e0(%rsp)
 1210251:	00 00 
 1210253:	c5 fc 11 84 24 c0 07 	vmovups %ymm0,0x7c0(%rsp)
 121025a:	00 00 
 121025c:	c5 fc 11 84 24 a0 07 	vmovups %ymm0,0x7a0(%rsp)
 1210263:	00 00 
 1210265:	c6 84 24 20 09 00 00 	movb   $0x38,0x920(%rsp)
 121026c:	38 
 121026d:	c6 84 24 28 09 00 00 	movb   $0x0,0x928(%rsp)
 1210274:	00 
 1210275:	0f b7 05 cc ac e2 ff 	movzwl -0x1d5334(%rip),%eax        # 103af48 <__anon_35281>
 121027c:	66 89 84 24 22 09 00 	mov    %ax,0x922(%rsp)
 1210283:	00 
 1210284:	0f b6 44 24 1f       	movzbl 0x1f(%rsp),%eax
 1210289:	24 1f                	and    $0x1f,%al
 121028b:	88 44 24 1f          	mov    %al,0x1f(%rsp)
 121028f:	88 84 24 21 09 00 00 	mov    %al,0x921(%rsp)
 1210296:	48 8b 84 24 f0 00 00 	mov    0xf0(%rsp),%rax
 121029d:	00 
 121029e:	48 89 84 24 08 07 00 	mov    %rax,0x708(%rsp)
 12102a5:	00 
 12102a6:	48 8b 84 24 e8 00 00 	mov    0xe8(%rsp),%rax
 12102ad:	00 
 12102ae:	48 89 84 24 10 07 00 	mov    %rax,0x710(%rsp)
 12102b5:	00 
 12102b6:	c7 84 24 24 09 00 00 	movl   $0x1000101,0x924(%rsp)
 12102bd:	01 01 00 01 
 12102c1:	48 8b 84 24 e0 00 00 	mov    0xe0(%rsp),%rax
 12102c8:	00 
 12102c9:	48 89 84 24 18 09 00 	mov    %rax,0x918(%rsp)
 12102d0:	00 
 12102d1:	48 8b 84 24 d8 00 00 	mov    0xd8(%rsp),%rax
 12102d8:	00 
 12102d9:	48 89 84 24 10 09 00 	mov    %rax,0x910(%rsp)
 12102e0:	00 
 12102e1:	66 c7 84 24 2a 09 00 	movw   $0x0,0x92a(%rsp)
 12102e8:	00 00 00 
 12102eb:	48 c7 84 24 20 07 00 	movq   $0x0,0x720(%rsp)
 12102f2:	00 00 00 00 00 
 12102f7:	48 8b 45 10          	mov    0x10(%rbp),%rax
 12102fb:	c5 fc 10 40 70       	vmovups 0x70(%rax),%ymm0
 1210300:	c5 fc 11 84 24 80 04 	vmovups %ymm0,0x480(%rsp)
 1210307:	00 00 
 1210309:	c5 fc 10 00          	vmovups (%rax),%ymm0
 121030d:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 1210312:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 1210317:	c5 fc 10 58 60       	vmovups 0x60(%rax),%ymm3
 121031c:	c5 fc 11 9c 24 70 04 	vmovups %ymm3,0x470(%rsp)
 1210323:	00 00 
 1210325:	c5 fc 11 94 24 50 04 	vmovups %ymm2,0x450(%rsp)
 121032c:	00 00 
 121032e:	c5 fc 11 8c 24 30 04 	vmovups %ymm1,0x430(%rsp)
 1210335:	00 00 
 1210337:	c5 fc 11 84 24 10 04 	vmovups %ymm0,0x410(%rsp)
 121033e:	00 00 
 1210340:	c5 fc 10 00          	vmovups (%rax),%ymm0
 1210344:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 1210349:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 121034e:	c5 fc 10 58 60       	vmovups 0x60(%rax),%ymm3
 1210353:	c5 fc 11 84 24 50 05 	vmovups %ymm0,0x550(%rsp)
 121035a:	00 00 
 121035c:	c5 fc 11 8c 24 70 05 	vmovups %ymm1,0x570(%rsp)
 1210363:	00 00 
 1210365:	c5 fc 11 94 24 90 05 	vmovups %ymm2,0x590(%rsp)
 121036c:	00 00 
 121036e:	c5 fc 11 9c 24 b0 05 	vmovups %ymm3,0x5b0(%rsp)
 1210375:	00 00 
 1210377:	c5 fe 6f 40 70       	vmovdqu 0x70(%rax),%ymm0
 121037c:	c5 fe 7f 84 24 c0 05 	vmovdqu %ymm0,0x5c0(%rsp)
 1210383:	00 00 
 1210385:	48 8d 84 24 08 07 00 	lea    0x708(%rsp),%rax
 121038c:	00 
 121038d:	4c 8d 94 24 50 05 00 	lea    0x550(%rsp),%r10
 1210394:	00 
 1210395:	48 8d bc 24 a8 03 00 	lea    0x3a8(%rsp),%rdi
 121039c:	00 
 121039d:	48 8b 74 24 48       	mov    0x48(%rsp),%rsi
 12103a2:	48 8b 94 24 c8 00 00 	mov    0xc8(%rsp),%rdx
 12103a9:	00 
 12103aa:	48 8b 8c 24 a8 00 00 	mov    0xa8(%rsp),%rcx
 12103b1:	00 
 12103b2:	4c 8b 84 24 b0 00 00 	mov    0xb0(%rsp),%r8
 12103b9:	00 
 12103ba:	4c 8b 8c 24 d0 00 00 	mov    0xd0(%rsp),%r9
 12103c1:	00 
 12103c2:	50                   	push   %rax
 12103c3:	41 52                	push   %r10
 12103c5:	c5 f8 77             	vzeroupper 
 12103c8:	e8 33 46 f6 ff       	call   1174a00 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307>
 12103cd:	48 83 c4 10          	add    $0x10,%rsp
 12103d1:	0f b7 84 24 b8 03 00 	movzwl 0x3b8(%rsp),%eax
 12103d8:	00 
 12103d9:	66 85 c0             	test   %ax,%ax
 12103dc:	0f 85 87 12 00 00    	jne    1211669 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x18a9>
 12103e2:	48 8b 84 24 a8 03 00 	mov    0x3a8(%rsp),%rax
 12103e9:	00 
 12103ea:	48 89 44 24 60       	mov    %rax,0x60(%rsp)
 12103ef:	48 8b 84 24 b0 03 00 	mov    0x3b0(%rsp),%rax
 12103f6:	00 
 12103f7:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 12103fc:	c5 fc 10 84 24 50 05 	vmovups 0x550(%rsp),%ymm0
 1210403:	00 00 
 1210405:	c5 fc 10 8c 24 70 05 	vmovups 0x570(%rsp),%ymm1
 121040c:	00 00 
 121040e:	c5 fc 10 94 24 90 05 	vmovups 0x590(%rsp),%ymm2
 1210415:	00 00 
 1210417:	c5 fc 10 9c 24 b0 05 	vmovups 0x5b0(%rsp),%ymm3
 121041e:	00 00 
 1210420:	c5 fc 11 84 24 20 02 	vmovups %ymm0,0x220(%rsp)
 1210427:	00 00 
 1210429:	c5 fc 11 8c 24 40 02 	vmovups %ymm1,0x240(%rsp)
 1210430:	00 00 
 1210432:	c5 fc 11 94 24 60 02 	vmovups %ymm2,0x260(%rsp)
 1210439:	00 00 
 121043b:	c5 fc 11 9c 24 80 02 	vmovups %ymm3,0x280(%rsp)
 1210442:	00 00 
 1210444:	c5 fe 6f 84 24 c0 05 	vmovdqu 0x5c0(%rsp),%ymm0
 121044b:	00 00 
 121044d:	c5 fe 7f 84 24 90 02 	vmovdqu %ymm0,0x290(%rsp)
 1210454:	00 00 
 1210456:	49 8b 07             	mov    (%r15),%rax
 1210459:	48 89 44 24 68       	mov    %rax,0x68(%rsp)
 121045e:	41 0f b6 47 08       	movzbl 0x8(%r15),%eax
 1210463:	88 44 24 28          	mov    %al,0x28(%rsp)
 1210467:	41 0f b6 47 09       	movzbl 0x9(%r15),%eax
 121046c:	88 44 24 1e          	mov    %al,0x1e(%rsp)
 1210470:	c4 c1 7e 6f 6d 01    	vmovdqu 0x1(%r13),%ymm5
 1210476:	c4 c1 7e 6f 65 21    	vmovdqu 0x21(%r13),%ymm4
 121047c:	41 0f b7 45 45       	movzwl 0x45(%r13),%eax
 1210481:	66 89 44 24 34       	mov    %ax,0x34(%rsp)
 1210486:	41 8b 45 41          	mov    0x41(%r13),%eax
 121048a:	89 44 24 30          	mov    %eax,0x30(%rsp)
 121048e:	45 0f b6 5f 50       	movzbl 0x50(%r15),%r11d
 1210493:	41 8b 04 24          	mov    (%r12),%eax
 1210497:	41 8b 4c 24 03       	mov    0x3(%r12),%ecx
 121049c:	89 84 24 80 00 00 00 	mov    %eax,0x80(%rsp)
 12104a3:	89 8c 24 83 00 00 00 	mov    %ecx,0x83(%rsp)
 12104aa:	45 84 db             	test   %r11b,%r11b
 12104ad:	c5 fd 7f a4 24 00 01 	vmovdqa %ymm4,0x100(%rsp)
 12104b4:	00 00 
 12104b6:	c5 fd 7f ac 24 40 01 	vmovdqa %ymm5,0x140(%rsp)
 12104bd:	00 00 
 12104bf:	74 30                	je     12104f1 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x731>
 12104c1:	4c 8d b4 24 fe 00 00 	lea    0xfe(%rsp),%r14
 12104c8:	00 
 12104c9:	4c 89 f7             	mov    %r14,%rdi
 12104cc:	4c 89 fe             	mov    %r15,%rsi
 12104cf:	45 89 df             	mov    %r11d,%r15d
 12104d2:	c5 f8 77             	vzeroupper 
 12104d5:	e8 16 12 00 00       	call   12116f0 <br.encoder.literal_context_split.Candidate.suffixCutoff>
 12104da:	c5 fd 6f ac 24 40 01 	vmovdqa 0x140(%rsp),%ymm5
 12104e1:	00 00 
 12104e3:	c5 fd 6f a4 24 00 01 	vmovdqa 0x100(%rsp),%ymm4
 12104ea:	00 00 
 12104ec:	45 89 fb             	mov    %r15d,%r11d
 12104ef:	eb 07                	jmp    12104f8 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x738>
 12104f1:	4c 8d 35 68 ee e2 ff 	lea    -0x1d1198(%rip),%r14        # 103f360 <__anon_46045>
 12104f8:	45 0f b7 3e          	movzwl (%r14),%r15d
 12104fc:	0f b6 84 24 80 01 00 	movzbl 0x180(%rsp),%eax
 1210503:	00 
 1210504:	20 d8                	and    %bl,%al
 1210506:	a8 01                	test   $0x1,%al
 1210508:	66 44 89 7c 24 2e    	mov    %r15w,0x2e(%rsp)
 121050e:	0f 84 ac 00 00 00    	je     12105c0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x800>
 1210514:	45 89 dd             	mov    %r11d,%r13d
 1210517:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 121051c:	48 8b 30             	mov    (%rax),%rsi
 121051f:	48 8b 50 08          	mov    0x8(%rax),%rdx
 1210523:	48 83 ec 08          	sub    $0x8,%rsp
 1210527:	48 8d bc 24 98 0f 00 	lea    0xf98(%rsp),%rdi
 121052e:	00 
 121052f:	48 8b 8c 24 d0 00 00 	mov    0xd0(%rsp),%rcx
 1210536:	00 
 1210537:	4c 8b 84 24 b0 00 00 	mov    0xb0(%rsp),%r8
 121053e:	00 
 121053f:	4c 8b 8c 24 b8 00 00 	mov    0xb8(%rsp),%r9
 1210546:	00 
 1210547:	ff b4 24 d8 00 00 00 	push   0xd8(%rsp)
 121054e:	c5 f8 77             	vzeroupper 
 1210551:	e8 aa e8 ff ff       	call   120ee00 <br.encoder.literal_context_split.chooseProposals>
 1210556:	48 83 c4 10          	add    $0x10,%rsp
 121055a:	44 0f b7 b4 24 98 10 	movzwl 0x1098(%rsp),%r14d
 1210561:	00 00 
 1210563:	66 45 85 f6          	test   %r14w,%r14w
 1210567:	0f 85 0d 11 00 00    	jne    121167a <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x18ba>
 121056d:	4c 8d a4 24 e0 0e 00 	lea    0xee0(%rsp),%r12
 1210574:	00 
 1210575:	4c 8d bc 24 38 0f 00 	lea    0xf38(%rsp),%r15
 121057c:	00 
 121057d:	4c 8d b4 24 88 0e 00 	lea    0xe88(%rsp),%r14
 1210584:	00 
 1210585:	48 8d b4 24 90 0f 00 	lea    0xf90(%rsp),%rsi
 121058c:	00 
 121058d:	ba 08 01 00 00       	mov    $0x108,%edx
 1210592:	4c 89 f7             	mov    %r14,%rdi
 1210595:	e8 86 5c 08 00       	call   1296220 <compiler_rt.memcpy.memcpyFast>
 121059a:	45 89 eb             	mov    %r13d,%r11d
 121059d:	c5 fd 6f a4 24 00 01 	vmovdqa 0x100(%rsp),%ymm4
 12105a4:	00 00 
 12105a6:	c5 fd 6f ac 24 40 01 	vmovdqa 0x140(%rsp),%ymm5
 12105ad:	00 00 
 12105af:	f6 c3 01             	test   $0x1,%bl
 12105b2:	75 26                	jne    12105da <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x81a>
 12105b4:	48 8d 0d ad ed e2 ff 	lea    -0x1d1253(%rip),%rcx        # 103f368 <__anon_46339>
 12105bb:	e9 a9 00 00 00       	jmp    1210669 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x8a9>
 12105c0:	4c 8d 35 91 ec e2 ff 	lea    -0x1d136f(%rip),%r14        # 103f258 <__anon_46105>
 12105c7:	4c 8d 3d 3a ed e2 ff 	lea    -0x1d12c6(%rip),%r15        # 103f308 <__anon_46105+0xb0>
 12105ce:	4c 8d 25 db ec e2 ff 	lea    -0x1d1325(%rip),%r12        # 103f2b0 <__anon_46105+0x58>
 12105d5:	f6 c3 01             	test   $0x1,%bl
 12105d8:	74 da                	je     12105b4 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x7f4>
 12105da:	c4 c1 7c 10 06       	vmovups (%r14),%ymm0
 12105df:	c4 c1 7c 10 4e 38    	vmovups 0x38(%r14),%ymm1
 12105e5:	c5 fc 11 8c 24 b8 0d 	vmovups %ymm1,0xdb8(%rsp)
 12105ec:	00 00 
 12105ee:	c4 c1 7c 10 4e 20    	vmovups 0x20(%r14),%ymm1
 12105f4:	c5 fc 11 8c 24 a0 0d 	vmovups %ymm1,0xda0(%rsp)
 12105fb:	00 00 
 12105fd:	c5 fc 11 84 24 80 0d 	vmovups %ymm0,0xd80(%rsp)
 1210604:	00 00 
 1210606:	c4 c1 7c 10 04 24    	vmovups (%r12),%ymm0
 121060c:	c4 c1 7c 10 4c 24 20 	vmovups 0x20(%r12),%ymm1
 1210613:	c4 c1 7c 10 54 24 38 	vmovups 0x38(%r12),%ymm2
 121061a:	c5 fc 11 84 24 d8 0d 	vmovups %ymm0,0xdd8(%rsp)
 1210621:	00 00 
 1210623:	c5 fc 11 8c 24 f8 0d 	vmovups %ymm1,0xdf8(%rsp)
 121062a:	00 00 
 121062c:	c5 fc 11 94 24 10 0e 	vmovups %ymm2,0xe10(%rsp)
 1210633:	00 00 
 1210635:	c4 c1 7c 10 07       	vmovups (%r15),%ymm0
 121063a:	c4 c1 7c 10 4f 20    	vmovups 0x20(%r15),%ymm1
 1210640:	c5 fc 11 84 24 30 0e 	vmovups %ymm0,0xe30(%rsp)
 1210647:	00 00 
 1210649:	c4 c1 7e 6f 47 38    	vmovdqu 0x38(%r15),%ymm0
 121064f:	c5 fc 11 8c 24 50 0e 	vmovups %ymm1,0xe50(%rsp)
 1210656:	00 00 
 1210658:	c5 fe 7f 84 24 68 0e 	vmovdqu %ymm0,0xe68(%rsp)
 121065f:	00 00 
 1210661:	48 8d 8c 24 80 0d 00 	lea    0xd80(%rsp),%rcx
 1210668:	00 
 1210669:	4c 8b 54 24 60       	mov    0x60(%rsp),%r10
 121066e:	45 31 ed             	xor    %r13d,%r13d
 1210671:	48 c7 84 24 c0 00 00 	movq   $0x0,0xc0(%rsp)
 1210678:	00 00 00 00 00 
 121067d:	45 31 ff             	xor    %r15d,%r15d
 1210680:	48 89 8c 24 88 00 00 	mov    %rcx,0x88(%rsp)
 1210687:	00 
 1210688:	eb 2c                	jmp    12106b6 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x8f6>
 121068a:	48 8b 8c 24 88 00 00 	mov    0x88(%rsp),%rcx
 1210691:	00 
 1210692:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1210699:	1f 84 00 00 00 00 00 
 12106a0:	4d 85 ed             	test   %r13,%r13
 12106a3:	0f 84 b7 06 00 00    	je     1210d60 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xfa0>
 12106a9:	49 ff c5             	inc    %r13
 12106ac:	49 83 fd 03          	cmp    $0x3,%r13
 12106b0:	0f 84 8d 08 00 00    	je     1210f43 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1183>
 12106b6:	49 6b c5 58          	imul   $0x58,%r13,%rax
 12106ba:	80 7c 01 50 00       	cmpb   $0x0,0x50(%rcx,%rax,1)
 12106bf:	74 df                	je     12106a0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x8e0>
 12106c1:	4c 8b 04 01          	mov    (%rcx,%rax,1),%r8
 12106c5:	44 0f b6 74 01 08    	movzbl 0x8(%rcx,%rax,1),%r14d
 12106cb:	44 0f b6 64 01 09    	movzbl 0x9(%rcx,%rax,1),%r12d
 12106d1:	c5 fe 6f 74 01 0a    	vmovdqu 0xa(%rcx,%rax,1),%ymm6
 12106d7:	c5 fe 6f 7c 01 2a    	vmovdqu 0x2a(%rcx,%rax,1),%ymm7
 12106dd:	48 8d 44 01 4a       	lea    0x4a(%rcx,%rax,1),%rax
 12106e2:	0f b7 48 04          	movzwl 0x4(%rax),%ecx
 12106e6:	66 89 4c 24 74       	mov    %cx,0x74(%rsp)
 12106eb:	8b 08                	mov    (%rax),%ecx
 12106ed:	89 4c 24 70          	mov    %ecx,0x70(%rsp)
 12106f1:	45 84 db             	test   %r11b,%r11b
 12106f4:	74 5a                	je     1210750 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x990>
 12106f6:	44 89 f2             	mov    %r14d,%edx
 12106f9:	80 e2 03             	and    $0x3,%dl
 12106fc:	0f b6 74 24 28       	movzbl 0x28(%rsp),%esi
 1210701:	40 80 e6 03          	and    $0x3,%sil
 1210705:	31 c9                	xor    %ecx,%ecx
 1210707:	40 38 f2             	cmp    %sil,%dl
 121070a:	75 2e                	jne    121073a <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x97a>
 121070c:	0f b6 54 24 1e       	movzbl 0x1e(%rsp),%edx
 1210711:	80 e2 7f             	and    $0x7f,%dl
 1210714:	44 89 e6             	mov    %r12d,%esi
 1210717:	40 80 e6 7f          	and    $0x7f,%sil
 121071b:	40 38 d6             	cmp    %dl,%sil
 121071e:	75 1a                	jne    121073a <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x97a>
 1210720:	c5 cd 74 c5          	vpcmpeqb %ymm5,%ymm6,%ymm0
 1210724:	c5 fd d7 d0          	vpmovmskb %ymm0,%edx
 1210728:	f7 d2                	not    %edx
 121072a:	85 d2                	test   %edx,%edx
 121072c:	75 0c                	jne    121073a <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x97a>
 121072e:	c5 c5 ef c4          	vpxor  %ymm4,%ymm7,%ymm0
 1210732:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 1210737:	0f 94 c1             	sete   %cl
 121073a:	4d 85 ff             	test   %r15,%r15
 121073d:	44 89 9c 24 90 00 00 	mov    %r11d,0x90(%rsp)
 1210744:	00 
 1210745:	75 18                	jne    121075f <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x99f>
 1210747:	eb 3c                	jmp    1210785 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x9c5>
 1210749:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)
 1210750:	31 c9                	xor    %ecx,%ecx
 1210752:	4d 85 ff             	test   %r15,%r15
 1210755:	44 89 9c 24 90 00 00 	mov    %r11d,0x90(%rsp)
 121075c:	00 
 121075d:	74 26                	je     1210785 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x9c5>
 121075f:	4d 89 d3             	mov    %r10,%r11
 1210762:	4c 89 c3             	mov    %r8,%rbx
 1210765:	49 83 ff 01          	cmp    $0x1,%r15
 1210769:	75 39                	jne    12107a4 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x9e4>
 121076b:	31 d2                	xor    %edx,%edx
 121076d:	41 f6 c7 01          	test   $0x1,%r15b
 1210771:	49 89 d8             	mov    %rbx,%r8
 1210774:	4d 89 da             	mov    %r11,%r10
 1210777:	44 8b 9c 24 90 00 00 	mov    0x90(%rsp),%r11d
 121077e:	00 
 121077f:	0f 85 00 01 00 00    	jne    1210885 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xac5>
 1210785:	f6 c1 01             	test   $0x1,%cl
 1210788:	0f 84 72 01 00 00    	je     1210900 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xb40>
 121078e:	48 8b 8c 24 88 00 00 	mov    0x88(%rsp),%rcx
 1210795:	00 
 1210796:	4d 85 ed             	test   %r13,%r13
 1210799:	0f 85 0a ff ff ff    	jne    12106a9 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x8e9>
 121079f:	e9 bc 05 00 00       	jmp    1210d60 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xfa0>
 12107a4:	4c 89 fe             	mov    %r15,%rsi
 12107a7:	48 83 e6 fe          	and    $0xfffffffffffffffe,%rsi
 12107ab:	48 8d bc 24 c0 02 00 	lea    0x2c0(%rsp),%rdi
 12107b2:	00 
 12107b3:	31 d2                	xor    %edx,%edx
 12107b5:	eb 19                	jmp    12107d0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xa10>
 12107b7:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 12107be:	00 00 
 12107c0:	48 83 c2 02          	add    $0x2,%rdx
 12107c4:	48 81 c7 a0 00 00 00 	add    $0xa0,%rdi
 12107cb:	48 39 d6             	cmp    %rdx,%rsi
 12107ce:	74 9d                	je     121076d <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x9ad>
 12107d0:	41 b0 01             	mov    $0x1,%r8b
 12107d3:	f6 c1 01             	test   $0x1,%cl
 12107d6:	b1 01                	mov    $0x1,%cl
 12107d8:	75 4b                	jne    1210825 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xa65>
 12107da:	45 89 f1             	mov    %r14d,%r9d
 12107dd:	41 80 e1 03          	and    $0x3,%r9b
 12107e1:	44 0f b6 17          	movzbl (%rdi),%r10d
 12107e5:	41 80 e2 03          	and    $0x3,%r10b
 12107e9:	45 31 c0             	xor    %r8d,%r8d
 12107ec:	45 38 d1             	cmp    %r10b,%r9b
 12107ef:	75 34                	jne    1210825 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xa65>
 12107f1:	44 0f b6 4f 01       	movzbl 0x1(%rdi),%r9d
 12107f6:	41 80 e1 7f          	and    $0x7f,%r9b
 12107fa:	45 89 e2             	mov    %r12d,%r10d
 12107fd:	41 80 e2 7f          	and    $0x7f,%r10b
 1210801:	45 38 ca             	cmp    %r9b,%r10b
 1210804:	75 1f                	jne    1210825 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xa65>
 1210806:	c5 cd 74 47 02       	vpcmpeqb 0x2(%rdi),%ymm6,%ymm0
 121080b:	c5 7d d7 c8          	vpmovmskb %ymm0,%r9d
 121080f:	41 f7 d1             	not    %r9d
 1210812:	45 85 c9             	test   %r9d,%r9d
 1210815:	75 0e                	jne    1210825 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xa65>
 1210817:	c5 c5 ef 47 22       	vpxor  0x22(%rdi),%ymm7,%ymm0
 121081c:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 1210821:	41 0f 94 c0          	sete   %r8b
 1210825:	45 84 c0             	test   %r8b,%r8b
 1210828:	75 96                	jne    12107c0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xa00>
 121082a:	45 89 f0             	mov    %r14d,%r8d
 121082d:	41 80 e0 03          	and    $0x3,%r8b
 1210831:	44 0f b6 4f 50       	movzbl 0x50(%rdi),%r9d
 1210836:	41 80 e1 03          	and    $0x3,%r9b
 121083a:	31 c9                	xor    %ecx,%ecx
 121083c:	45 38 c8             	cmp    %r9b,%r8b
 121083f:	0f 85 7b ff ff ff    	jne    12107c0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xa00>
 1210845:	44 0f b6 47 51       	movzbl 0x51(%rdi),%r8d
 121084a:	41 80 e0 7f          	and    $0x7f,%r8b
 121084e:	45 89 e1             	mov    %r12d,%r9d
 1210851:	41 80 e1 7f          	and    $0x7f,%r9b
 1210855:	45 38 c1             	cmp    %r8b,%r9b
 1210858:	0f 85 62 ff ff ff    	jne    12107c0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xa00>
 121085e:	c5 cd 74 47 52       	vpcmpeqb 0x52(%rdi),%ymm6,%ymm0
 1210863:	c5 7d d7 c0          	vpmovmskb %ymm0,%r8d
 1210867:	41 f7 d0             	not    %r8d
 121086a:	45 85 c0             	test   %r8d,%r8d
 121086d:	0f 85 4d ff ff ff    	jne    12107c0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xa00>
 1210873:	c5 c5 ef 47 72       	vpxor  0x72(%rdi),%ymm7,%ymm0
 1210878:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 121087d:	0f 94 c1             	sete   %cl
 1210880:	e9 3b ff ff ff       	jmp    12107c0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xa00>
 1210885:	84 c9                	test   %cl,%cl
 1210887:	0f 85 fd fd ff ff    	jne    121068a <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x8ca>
 121088d:	48 8d 0c 92          	lea    (%rdx,%rdx,4),%rcx
 1210891:	48 c1 e1 04          	shl    $0x4,%rcx
 1210895:	48 8d 14 0c          	lea    (%rsp,%rcx,1),%rdx
 1210899:	48 81 c2 b8 02 00 00 	add    $0x2b8,%rdx
 12108a0:	44 89 f6             	mov    %r14d,%esi
 12108a3:	40 80 e6 03          	and    $0x3,%sil
 12108a7:	0f b6 7a 08          	movzbl 0x8(%rdx),%edi
 12108ab:	40 80 e7 03          	and    $0x3,%dil
 12108af:	40 38 fe             	cmp    %dil,%sil
 12108b2:	75 4c                	jne    1210900 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xb40>
 12108b4:	0f b6 72 09          	movzbl 0x9(%rdx),%esi
 12108b8:	40 80 e6 7f          	and    $0x7f,%sil
 12108bc:	44 89 e7             	mov    %r12d,%edi
 12108bf:	40 80 e7 7f          	and    $0x7f,%dil
 12108c3:	40 38 f7             	cmp    %sil,%dil
 12108c6:	75 38                	jne    1210900 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xb40>
 12108c8:	c5 cd 74 42 0a       	vpcmpeqb 0xa(%rdx),%ymm6,%ymm0
 12108cd:	c5 fd d7 d0          	vpmovmskb %ymm0,%edx
 12108d1:	f7 d2                	not    %edx
 12108d3:	85 d2                	test   %edx,%edx
 12108d5:	75 29                	jne    1210900 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xb40>
 12108d7:	c5 c5 ef 84 0c e2 02 	vpxor  0x2e2(%rsp,%rcx,1),%ymm7,%ymm0
 12108de:	00 00 
 12108e0:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 12108e5:	0f 94 c1             	sete   %cl
 12108e8:	f6 c1 01             	test   $0x1,%cl
 12108eb:	0f 85 9d fe ff ff    	jne    121078e <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x9ce>
 12108f1:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 12108f8:	0f 1f 84 00 00 00 00 
 12108ff:	00 
 1210900:	c5 fd 7f ac 24 40 01 	vmovdqa %ymm5,0x140(%rsp)
 1210907:	00 00 
 1210909:	c5 fd 7f a4 24 00 01 	vmovdqa %ymm4,0x100(%rsp)
 1210910:	00 00 
 1210912:	4c 89 54 24 60       	mov    %r10,0x60(%rsp)
 1210917:	4c 89 7c 24 78       	mov    %r15,0x78(%rsp)
 121091c:	c5 fc 10 84 24 80 04 	vmovups 0x480(%rsp),%ymm0
 1210923:	00 00 
 1210925:	c5 fc 11 84 24 50 06 	vmovups %ymm0,0x650(%rsp)
 121092c:	00 00 
 121092e:	c5 fc 10 84 24 10 04 	vmovups 0x410(%rsp),%ymm0
 1210935:	00 00 
 1210937:	c5 fc 10 8c 24 30 04 	vmovups 0x430(%rsp),%ymm1
 121093e:	00 00 
 1210940:	c5 fc 10 94 24 50 04 	vmovups 0x450(%rsp),%ymm2
 1210947:	00 00 
 1210949:	c5 fc 10 9c 24 70 04 	vmovups 0x470(%rsp),%ymm3
 1210950:	00 00 
 1210952:	c5 fc 11 9c 24 40 06 	vmovups %ymm3,0x640(%rsp)
 1210959:	00 00 
 121095b:	c5 fc 11 94 24 20 06 	vmovups %ymm2,0x620(%rsp)
 1210962:	00 00 
 1210964:	c5 fc 11 8c 24 00 06 	vmovups %ymm1,0x600(%rsp)
 121096b:	00 00 
 121096d:	c5 fc 11 84 24 e0 05 	vmovups %ymm0,0x5e0(%rsp)
 1210974:	00 00 
 1210976:	0f b6 4c 24 20       	movzbl 0x20(%rsp),%ecx
 121097b:	c5 fe 6f 84 24 f0 03 	vmovdqu 0x3f0(%rsp),%ymm0
 1210982:	00 00 
 1210984:	48 8d b4 24 e2 0b 00 	lea    0xbe2(%rsp),%rsi
 121098b:	00 
 121098c:	c5 fe 7f 46 96       	vmovdqu %ymm0,-0x6a(%rsi)
 1210991:	0f b7 50 04          	movzwl 0x4(%rax),%edx
 1210995:	66 89 56 04          	mov    %dx,0x4(%rsi)
 1210999:	8b 00                	mov    (%rax),%eax
 121099b:	89 06                	mov    %eax,(%rsi)
 121099d:	88 8c 24 79 0d 00 00 	mov    %cl,0xd79(%rsp)
 12109a4:	48 c7 84 24 68 0b 00 	movq   $0x0,0xb68(%rsp)
 12109ab:	00 00 00 00 00 
 12109b0:	8b 44 24 40          	mov    0x40(%rsp),%eax
 12109b4:	88 84 24 7d 0d 00 00 	mov    %al,0xd7d(%rsp)
 12109bb:	c6 84 24 7c 0d 00 00 	movb   $0x0,0xd7c(%rsp)
 12109c2:	00 
 12109c3:	4c 89 c3             	mov    %r8,%rbx
 12109c6:	4c 89 84 24 98 0b 00 	mov    %r8,0xb98(%rsp)
 12109cd:	00 
 12109ce:	44 88 b4 24 a0 0b 00 	mov    %r14b,0xba0(%rsp)
 12109d5:	00 
 12109d6:	44 88 a4 24 a1 0b 00 	mov    %r12b,0xba1(%rsp)
 12109dd:	00 
 12109de:	c5 fd 7f b4 24 80 01 	vmovdqa %ymm6,0x180(%rsp)
 12109e5:	00 00 
 12109e7:	c5 fe 7f b4 24 a2 0b 	vmovdqu %ymm6,0xba2(%rsp)
 12109ee:	00 00 
 12109f0:	c5 fd 7f bc 24 60 01 	vmovdqa %ymm7,0x160(%rsp)
 12109f7:	00 00 
 12109f9:	c5 fe 7f bc 24 c2 0b 	vmovdqu %ymm7,0xbc2(%rsp)
 1210a00:	00 00 
 1210a02:	c6 84 24 e8 0b 00 00 	movb   $0x1,0xbe8(%rsp)
 1210a09:	01 
 1210a0a:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 1210a0e:	c5 fe 7f 86 5e 01 00 	vmovdqu %ymm0,0x15e(%rsi)
 1210a15:	00 
 1210a16:	c5 fe 7f 86 4e 01 00 	vmovdqu %ymm0,0x14e(%rsi)
 1210a1d:	00 
 1210a1e:	c5 fe 7f 86 2e 01 00 	vmovdqu %ymm0,0x12e(%rsi)
 1210a25:	00 
 1210a26:	c5 fe 7f 86 0e 01 00 	vmovdqu %ymm0,0x10e(%rsi)
 1210a2d:	00 
 1210a2e:	c5 fe 7f 86 ee 00 00 	vmovdqu %ymm0,0xee(%rsi)
 1210a35:	00 
 1210a36:	c5 fe 7f 86 ce 00 00 	vmovdqu %ymm0,0xce(%rsi)
 1210a3d:	00 
 1210a3e:	c5 fe 7f 86 ae 00 00 	vmovdqu %ymm0,0xae(%rsi)
 1210a45:	00 
 1210a46:	c5 fe 7f 86 8e 00 00 	vmovdqu %ymm0,0x8e(%rsi)
 1210a4d:	00 
 1210a4e:	c5 fe 7f 46 6e       	vmovdqu %ymm0,0x6e(%rsi)
 1210a53:	c5 fe 7f 46 4e       	vmovdqu %ymm0,0x4e(%rsi)
 1210a58:	c5 fe 7f 46 2e       	vmovdqu %ymm0,0x2e(%rsi)
 1210a5d:	c5 fe 7f 46 0e       	vmovdqu %ymm0,0xe(%rsi)
 1210a62:	c6 84 24 70 0d 00 00 	movb   $0x38,0xd70(%rsp)
 1210a69:	38 
 1210a6a:	c6 84 24 78 0d 00 00 	movb   $0x0,0xd78(%rsp)
 1210a71:	00 
 1210a72:	0f b7 05 cf a4 e2 ff 	movzwl -0x1d5b31(%rip),%eax        # 103af48 <__anon_35281>
 1210a79:	66 89 84 24 72 0d 00 	mov    %ax,0xd72(%rsp)
 1210a80:	00 
 1210a81:	0f b6 44 24 1f       	movzbl 0x1f(%rsp),%eax
 1210a86:	88 84 24 71 0d 00 00 	mov    %al,0xd71(%rsp)
 1210a8d:	48 8b 84 24 f0 00 00 	mov    0xf0(%rsp),%rax
 1210a94:	00 
 1210a95:	48 89 84 24 58 0b 00 	mov    %rax,0xb58(%rsp)
 1210a9c:	00 
 1210a9d:	48 8b 84 24 e8 00 00 	mov    0xe8(%rsp),%rax
 1210aa4:	00 
 1210aa5:	48 89 84 24 60 0b 00 	mov    %rax,0xb60(%rsp)
 1210aac:	00 
 1210aad:	c7 84 24 74 0d 00 00 	movl   $0x1000101,0xd74(%rsp)
 1210ab4:	01 01 00 01 
 1210ab8:	48 8b 84 24 e0 00 00 	mov    0xe0(%rsp),%rax
 1210abf:	00 
 1210ac0:	48 89 84 24 68 0d 00 	mov    %rax,0xd68(%rsp)
 1210ac7:	00 
 1210ac8:	48 8b 84 24 d8 00 00 	mov    0xd8(%rsp),%rax
 1210acf:	00 
 1210ad0:	48 89 84 24 60 0d 00 	mov    %rax,0xd60(%rsp)
 1210ad7:	00 
 1210ad8:	66 c7 84 24 7a 0d 00 	movw   $0x0,0xd7a(%rsp)
 1210adf:	00 00 00 
 1210ae2:	48 c7 84 24 70 0b 00 	movq   $0x0,0xb70(%rsp)
 1210ae9:	00 00 00 00 00 
 1210aee:	48 8d bc 24 c0 03 00 	lea    0x3c0(%rsp),%rdi
 1210af5:	00 
 1210af6:	48 8b 74 24 48       	mov    0x48(%rsp),%rsi
 1210afb:	48 8b 94 24 c8 00 00 	mov    0xc8(%rsp),%rdx
 1210b02:	00 
 1210b03:	48 8b 8c 24 a8 00 00 	mov    0xa8(%rsp),%rcx
 1210b0a:	00 
 1210b0b:	4c 8b 84 24 b0 00 00 	mov    0xb0(%rsp),%r8
 1210b12:	00 
 1210b13:	4c 8b 8c 24 d0 00 00 	mov    0xd0(%rsp),%r9
 1210b1a:	00 
 1210b1b:	48 8d 84 24 58 0b 00 	lea    0xb58(%rsp),%rax
 1210b22:	00 
 1210b23:	50                   	push   %rax
 1210b24:	48 8d 84 24 e8 05 00 	lea    0x5e8(%rsp),%rax
 1210b2b:	00 
 1210b2c:	50                   	push   %rax
 1210b2d:	c5 f8 77             	vzeroupper 
 1210b30:	e8 cb 3e f6 ff       	call   1174a00 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307>
 1210b35:	48 83 c4 10          	add    $0x10,%rsp
 1210b39:	44 0f b7 bc 24 d0 03 	movzwl 0x3d0(%rsp),%r15d
 1210b40:	00 00 
 1210b42:	66 45 85 ff          	test   %r15w,%r15w
 1210b46:	0f 85 e7 0a 00 00    	jne    1211633 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1873>
 1210b4c:	48 8b b4 24 c0 03 00 	mov    0x3c0(%rsp),%rsi
 1210b53:	00 
 1210b54:	4c 8b bc 24 c8 03 00 	mov    0x3c8(%rsp),%r15
 1210b5b:	00 
 1210b5c:	48 8b 54 24 38       	mov    0x38(%rsp),%rdx
 1210b61:	49 39 d7             	cmp    %rdx,%r15
 1210b64:	0f 83 2c 01 00 00    	jae    1210c96 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xed6>
 1210b6a:	48 89 b4 24 b8 00 00 	mov    %rsi,0xb8(%rsp)
 1210b71:	00 
 1210b72:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 1210b77:	48 8b 38             	mov    (%rax),%rdi
 1210b7a:	48 8b 40 08          	mov    0x8(%rax),%rax
 1210b7e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1210b82:	48 8b 74 24 60       	mov    0x60(%rsp),%rsi
 1210b87:	31 c9                	xor    %ecx,%ecx
 1210b89:	4c 89 44 24 38       	mov    %r8,0x38(%rsp)
 1210b8e:	ff 50 18             	call   *0x18(%rax)
 1210b91:	c5 fc 10 84 24 50 06 	vmovups 0x650(%rsp),%ymm0
 1210b98:	00 00 
 1210b9a:	c5 fc 11 84 24 90 02 	vmovups %ymm0,0x290(%rsp)
 1210ba1:	00 00 
 1210ba3:	c5 fe 6f 84 24 e0 05 	vmovdqu 0x5e0(%rsp),%ymm0
 1210baa:	00 00 
 1210bac:	c5 fc 10 8c 24 00 06 	vmovups 0x600(%rsp),%ymm1
 1210bb3:	00 00 
 1210bb5:	c5 fc 10 94 24 20 06 	vmovups 0x620(%rsp),%ymm2
 1210bbc:	00 00 
 1210bbe:	c5 fc 10 9c 24 40 06 	vmovups 0x640(%rsp),%ymm3
 1210bc5:	00 00 
 1210bc7:	c5 fc 11 9c 24 80 02 	vmovups %ymm3,0x280(%rsp)
 1210bce:	00 00 
 1210bd0:	c5 fc 11 94 24 60 02 	vmovups %ymm2,0x260(%rsp)
 1210bd7:	00 00 
 1210bd9:	c5 fc 11 8c 24 40 02 	vmovups %ymm1,0x240(%rsp)
 1210be0:	00 00 
 1210be2:	c5 fe 7f 84 24 20 02 	vmovdqu %ymm0,0x220(%rsp)
 1210be9:	00 00 
 1210beb:	80 bc 24 90 00 00 00 	cmpb   $0x0,0x90(%rsp)
 1210bf2:	00 
 1210bf3:	41 b3 01             	mov    $0x1,%r11b
 1210bf6:	0f 84 8e 02 00 00    	je     1210e8a <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x10ca>
 1210bfc:	48 8b 54 24 78       	mov    0x78(%rsp),%rdx
 1210c01:	48 83 fa 03          	cmp    $0x3,%rdx
 1210c05:	c5 fd 6f ac 24 80 01 	vmovdqa 0x180(%rsp),%ymm5
 1210c0c:	00 00 
 1210c0e:	c5 fd 6f a4 24 60 01 	vmovdqa 0x160(%rsp),%ymm4
 1210c15:	00 00 
 1210c17:	0f 83 50 09 00 00    	jae    121156d <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17ad>
 1210c1d:	49 89 d8             	mov    %rbx,%r8
 1210c20:	48 8d 04 92          	lea    (%rdx,%rdx,4),%rax
 1210c24:	48 c1 e0 04          	shl    $0x4,%rax
 1210c28:	48 8b 4c 24 68       	mov    0x68(%rsp),%rcx
 1210c2d:	48 89 8c 04 b8 02 00 	mov    %rcx,0x2b8(%rsp,%rax,1)
 1210c34:	00 
 1210c35:	0f b6 4c 24 28       	movzbl 0x28(%rsp),%ecx
 1210c3a:	88 8c 04 c0 02 00 00 	mov    %cl,0x2c0(%rsp,%rax,1)
 1210c41:	0f b6 4c 24 1e       	movzbl 0x1e(%rsp),%ecx
 1210c46:	88 8c 04 c1 02 00 00 	mov    %cl,0x2c1(%rsp,%rax,1)
 1210c4d:	c5 fc 28 84 24 40 01 	vmovaps 0x140(%rsp),%ymm0
 1210c54:	00 00 
 1210c56:	c5 fc 11 84 04 c2 02 	vmovups %ymm0,0x2c2(%rsp,%rax,1)
 1210c5d:	00 00 
 1210c5f:	c5 fd 6f 84 24 00 01 	vmovdqa 0x100(%rsp),%ymm0
 1210c66:	00 00 
 1210c68:	c5 fe 7f 84 04 e2 02 	vmovdqu %ymm0,0x2e2(%rsp,%rax,1)
 1210c6f:	00 00 
 1210c71:	8b 4c 24 30          	mov    0x30(%rsp),%ecx
 1210c75:	89 8c 04 02 03 00 00 	mov    %ecx,0x302(%rsp,%rax,1)
 1210c7c:	0f b7 4c 24 34       	movzwl 0x34(%rsp),%ecx
 1210c81:	66 89 8c 04 06 03 00 	mov    %cx,0x306(%rsp,%rax,1)
 1210c88:	00 
 1210c89:	48 ff c2             	inc    %rdx
 1210c8c:	48 89 54 24 78       	mov    %rdx,0x78(%rsp)
 1210c91:	e9 13 02 00 00       	jmp    1210ea9 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x10e9>
 1210c96:	4d 85 ff             	test   %r15,%r15
 1210c99:	74 1d                	je     1210cb8 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xef8>
 1210c9b:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 1210ca0:	48 8b 38             	mov    (%rax),%rdi
 1210ca3:	48 8b 40 08          	mov    0x8(%rax),%rax
 1210ca7:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1210cab:	4c 89 fa             	mov    %r15,%rdx
 1210cae:	31 c9                	xor    %ecx,%ecx
 1210cb0:	ff 50 18             	call   *0x18(%rax)
 1210cb3:	48 8b 54 24 38       	mov    0x38(%rsp),%rdx
 1210cb8:	4c 8b 7c 24 78       	mov    0x78(%rsp),%r15
 1210cbd:	49 83 ff 02          	cmp    $0x2,%r15
 1210cc1:	0f 87 88 08 00 00    	ja     121154f <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x178f>
 1210cc7:	4b 8d 04 bf          	lea    (%r15,%r15,4),%rax
 1210ccb:	48 c1 e0 04          	shl    $0x4,%rax
 1210ccf:	48 89 9c 04 b8 02 00 	mov    %rbx,0x2b8(%rsp,%rax,1)
 1210cd6:	00 
 1210cd7:	44 88 b4 04 c0 02 00 	mov    %r14b,0x2c0(%rsp,%rax,1)
 1210cde:	00 
 1210cdf:	44 88 a4 04 c1 02 00 	mov    %r12b,0x2c1(%rsp,%rax,1)
 1210ce6:	00 
 1210ce7:	c5 fc 28 84 24 80 01 	vmovaps 0x180(%rsp),%ymm0
 1210cee:	00 00 
 1210cf0:	c5 fc 11 84 04 c2 02 	vmovups %ymm0,0x2c2(%rsp,%rax,1)
 1210cf7:	00 00 
 1210cf9:	c5 fd 6f 84 24 60 01 	vmovdqa 0x160(%rsp),%ymm0
 1210d00:	00 00 
 1210d02:	c5 fe 7f 84 04 e2 02 	vmovdqu %ymm0,0x2e2(%rsp,%rax,1)
 1210d09:	00 00 
 1210d0b:	8b 4c 24 70          	mov    0x70(%rsp),%ecx
 1210d0f:	89 8c 04 02 03 00 00 	mov    %ecx,0x302(%rsp,%rax,1)
 1210d16:	0f b7 4c 24 74       	movzwl 0x74(%rsp),%ecx
 1210d1b:	66 89 8c 04 06 03 00 	mov    %cx,0x306(%rsp,%rax,1)
 1210d22:	00 
 1210d23:	49 ff c7             	inc    %r15
 1210d26:	44 8b 9c 24 90 00 00 	mov    0x90(%rsp),%r11d
 1210d2d:	00 
 1210d2e:	4c 8b 54 24 60       	mov    0x60(%rsp),%r10
 1210d33:	c5 fd 6f a4 24 00 01 	vmovdqa 0x100(%rsp),%ymm4
 1210d3a:	00 00 
 1210d3c:	c5 fd 6f ac 24 40 01 	vmovdqa 0x140(%rsp),%ymm5
 1210d43:	00 00 
 1210d45:	48 8b 8c 24 88 00 00 	mov    0x88(%rsp),%rcx
 1210d4c:	00 
 1210d4d:	4d 85 ed             	test   %r13,%r13
 1210d50:	0f 85 53 f9 ff ff    	jne    12106a9 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x8e9>
 1210d56:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 1210d5d:	00 00 00 
 1210d60:	0f b7 44 24 34       	movzwl 0x34(%rsp),%eax
 1210d65:	66 89 84 24 a0 00 00 	mov    %ax,0xa0(%rsp)
 1210d6c:	00 
 1210d6d:	8b 44 24 30          	mov    0x30(%rsp),%eax
 1210d71:	89 84 24 9c 00 00 00 	mov    %eax,0x9c(%rsp)
 1210d78:	45 84 db             	test   %r11b,%r11b
 1210d7b:	0f 84 fa 00 00 00    	je     1210e7b <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x10bb>
 1210d81:	4c 89 7c 24 78       	mov    %r15,0x78(%rsp)
 1210d86:	44 0f b6 64 24 1e    	movzbl 0x1e(%rsp),%r12d
 1210d8c:	4c 8b 7c 24 38       	mov    0x38(%rsp),%r15
 1210d91:	4c 8b 44 24 68       	mov    0x68(%rsp),%r8
 1210d96:	44 0f b6 74 24 28    	movzbl 0x28(%rsp),%r14d
 1210d9c:	44 89 f0             	mov    %r14d,%eax
 1210d9f:	24 03                	and    $0x3,%al
 1210da1:	3c 02                	cmp    $0x2,%al
 1210da3:	0f 85 6d 01 00 00    	jne    1210f16 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1156>
 1210da9:	4c 89 84 24 00 05 00 	mov    %r8,0x500(%rsp)
 1210db0:	00 
 1210db1:	44 88 b4 24 08 05 00 	mov    %r14b,0x508(%rsp)
 1210db8:	00 
 1210db9:	44 88 a4 24 09 05 00 	mov    %r12b,0x509(%rsp)
 1210dc0:	00 
 1210dc1:	c5 fe 7f ac 24 0a 05 	vmovdqu %ymm5,0x50a(%rsp)
 1210dc8:	00 00 
 1210dca:	c5 fe 7f a4 24 2a 05 	vmovdqu %ymm4,0x52a(%rsp)
 1210dd1:	00 00 
 1210dd3:	0f b7 84 24 a0 00 00 	movzwl 0xa0(%rsp),%eax
 1210dda:	00 
 1210ddb:	48 8d 8c 24 4a 05 00 	lea    0x54a(%rsp),%rcx
 1210de2:	00 
 1210de3:	66 89 41 04          	mov    %ax,0x4(%rcx)
 1210de7:	8b 84 24 9c 00 00 00 	mov    0x9c(%rsp),%eax
 1210dee:	89 01                	mov    %eax,(%rcx)
 1210df0:	48 8d bc 24 a6 00 00 	lea    0xa6(%rsp),%rdi
 1210df7:	00 
 1210df8:	4c 89 94 24 b8 00 00 	mov    %r10,0xb8(%rsp)
 1210dff:	00 
 1210e00:	48 8d b4 24 00 05 00 	lea    0x500(%rsp),%rsi
 1210e07:	00 
 1210e08:	44 89 db             	mov    %r11d,%ebx
 1210e0b:	4c 89 84 24 90 00 00 	mov    %r8,0x90(%rsp)
 1210e12:	00 
 1210e13:	c5 fd 7f ac 24 80 01 	vmovdqa %ymm5,0x180(%rsp)
 1210e1a:	00 00 
 1210e1c:	c5 fd 7f a4 24 60 01 	vmovdqa %ymm4,0x160(%rsp)
 1210e23:	00 00 
 1210e25:	c5 f8 77             	vzeroupper 
 1210e28:	e8 c3 08 00 00       	call   12116f0 <br.encoder.literal_context_split.Candidate.suffixCutoff>
 1210e2d:	48 8b 8c 24 88 00 00 	mov    0x88(%rsp),%rcx
 1210e34:	00 
 1210e35:	41 89 db             	mov    %ebx,%r11d
 1210e38:	44 88 64 24 1e       	mov    %r12b,0x1e(%rsp)
 1210e3d:	c5 fd 6f ac 24 80 01 	vmovdqa 0x180(%rsp),%ymm5
 1210e44:	00 00 
 1210e46:	c5 fd 6f a4 24 60 01 	vmovdqa 0x160(%rsp),%ymm4
 1210e4d:	00 00 
 1210e4f:	4c 8b 94 24 b8 00 00 	mov    0xb8(%rsp),%r10
 1210e56:	00 
 1210e57:	4c 89 7c 24 38       	mov    %r15,0x38(%rsp)
 1210e5c:	48 8b 84 24 90 00 00 	mov    0x90(%rsp),%rax
 1210e63:	00 
 1210e64:	48 89 44 24 68       	mov    %rax,0x68(%rsp)
 1210e69:	44 88 74 24 28       	mov    %r14b,0x28(%rsp)
 1210e6e:	48 8d 84 24 a6 00 00 	lea    0xa6(%rsp),%rax
 1210e75:	00 
 1210e76:	e9 b6 00 00 00       	jmp    1210f31 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1171>
 1210e7b:	45 31 db             	xor    %r11d,%r11d
 1210e7e:	48 8d 05 db e4 e2 ff 	lea    -0x1d1b25(%rip),%rax        # 103f360 <__anon_46045>
 1210e85:	e9 ac 00 00 00       	jmp    1210f36 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1176>
 1210e8a:	b0 01                	mov    $0x1,%al
 1210e8c:	48 89 84 24 c0 00 00 	mov    %rax,0xc0(%rsp)
 1210e93:	00 
 1210e94:	49 89 d8             	mov    %rbx,%r8
 1210e97:	c5 fd 6f ac 24 80 01 	vmovdqa 0x180(%rsp),%ymm5
 1210e9e:	00 00 
 1210ea0:	c5 fd 6f a4 24 60 01 	vmovdqa 0x160(%rsp),%ymm4
 1210ea7:	00 00 
 1210ea9:	4c 8b 94 24 b8 00 00 	mov    0xb8(%rsp),%r10
 1210eb0:	00 
 1210eb1:	0f b7 44 24 74       	movzwl 0x74(%rsp),%eax
 1210eb6:	66 89 44 24 34       	mov    %ax,0x34(%rsp)
 1210ebb:	8b 44 24 70          	mov    0x70(%rsp),%eax
 1210ebf:	89 44 24 30          	mov    %eax,0x30(%rsp)
 1210ec3:	4d 85 ed             	test   %r13,%r13
 1210ec6:	48 8b 8c 24 88 00 00 	mov    0x88(%rsp),%rcx
 1210ecd:	00 
 1210ece:	74 1e                	je     1210eee <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x112e>
 1210ed0:	44 88 74 24 28       	mov    %r14b,0x28(%rsp)
 1210ed5:	4c 89 44 24 68       	mov    %r8,0x68(%rsp)
 1210eda:	4c 89 7c 24 38       	mov    %r15,0x38(%rsp)
 1210edf:	44 88 64 24 1e       	mov    %r12b,0x1e(%rsp)
 1210ee4:	4c 8b 7c 24 78       	mov    0x78(%rsp),%r15
 1210ee9:	e9 bb f7 ff ff       	jmp    12106a9 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x8e9>
 1210eee:	0f b7 44 24 74       	movzwl 0x74(%rsp),%eax
 1210ef3:	66 89 84 24 a0 00 00 	mov    %ax,0xa0(%rsp)
 1210efa:	00 
 1210efb:	8b 44 24 70          	mov    0x70(%rsp),%eax
 1210eff:	89 84 24 9c 00 00 00 	mov    %eax,0x9c(%rsp)
 1210f06:	41 b3 01             	mov    $0x1,%r11b
 1210f09:	44 89 f0             	mov    %r14d,%eax
 1210f0c:	24 03                	and    $0x3,%al
 1210f0e:	3c 02                	cmp    $0x2,%al
 1210f10:	0f 84 93 fe ff ff    	je     1210da9 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xfe9>
 1210f16:	44 88 64 24 1e       	mov    %r12b,0x1e(%rsp)
 1210f1b:	4c 89 7c 24 38       	mov    %r15,0x38(%rsp)
 1210f20:	4c 89 44 24 68       	mov    %r8,0x68(%rsp)
 1210f25:	44 88 74 24 28       	mov    %r14b,0x28(%rsp)
 1210f2a:	48 8d 05 2f e4 e2 ff 	lea    -0x1d1bd1(%rip),%rax        # 103f360 <__anon_46045>
 1210f31:	4c 8b 7c 24 78       	mov    0x78(%rsp),%r15
 1210f36:	0f b7 00             	movzwl (%rax),%eax
 1210f39:	66 89 44 24 2e       	mov    %ax,0x2e(%rsp)
 1210f3e:	e9 66 f7 ff ff       	jmp    12106a9 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x8e9>
 1210f43:	8b 44 24 40          	mov    0x40(%rsp),%eax
 1210f47:	8b 8c 24 f8 00 00 00 	mov    0xf8(%rsp),%ecx
 1210f4e:	08 c8                	or     %cl,%al
 1210f50:	0f 84 ef 03 00 00    	je     1211345 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1585>
 1210f56:	84 c9                	test   %cl,%cl
 1210f58:	4c 8b 8c 24 d0 00 00 	mov    0xd0(%rsp),%r9
 1210f5f:	00 
 1210f60:	0f b6 74 24 1f       	movzbl 0x1f(%rsp),%esi
 1210f65:	75 36                	jne    1210f9d <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x11dd>
 1210f67:	b9 64 00 00 00       	mov    $0x64,%ecx
 1210f6c:	48 8b 44 24 38       	mov    0x38(%rsp),%rax
 1210f71:	48 f7 e1             	mul    %rcx
 1210f74:	70 27                	jo     1210f9d <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x11dd>
 1210f76:	c6 84 24 c0 01 00 00 	movb   $0x0,0x1c0(%rsp)
 1210f7d:	00 
 1210f7e:	31 c9                	xor    %ecx,%ecx
 1210f80:	84 c9                	test   %cl,%cl
 1210f82:	75 19                	jne    1210f9d <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x11dd>
 1210f84:	48 8b 8c 24 a8 00 00 	mov    0xa8(%rsp),%rcx
 1210f8b:	00 
 1210f8c:	48 c1 e1 04          	shl    $0x4,%rcx
 1210f90:	48 8d 0c 89          	lea    (%rcx,%rcx,4),%rcx
 1210f94:	48 39 c8             	cmp    %rcx,%rax
 1210f97:	0f 86 24 06 00 00    	jbe    12115c1 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1801>
 1210f9d:	c5 fd 7f ac 24 40 01 	vmovdqa %ymm5,0x140(%rsp)
 1210fa4:	00 00 
 1210fa6:	c5 fd 7f a4 24 00 01 	vmovdqa %ymm4,0x100(%rsp)
 1210fad:	00 00 
 1210faf:	4d 89 d5             	mov    %r10,%r13
 1210fb2:	45 89 de             	mov    %r11d,%r14d
 1210fb5:	c5 fc 10 84 24 80 04 	vmovups 0x480(%rsp),%ymm0
 1210fbc:	00 00 
 1210fbe:	c5 fc 11 84 24 e0 06 	vmovups %ymm0,0x6e0(%rsp)
 1210fc5:	00 00 
 1210fc7:	c5 fc 10 84 24 10 04 	vmovups 0x410(%rsp),%ymm0
 1210fce:	00 00 
 1210fd0:	c5 fc 10 8c 24 30 04 	vmovups 0x430(%rsp),%ymm1
 1210fd7:	00 00 
 1210fd9:	c5 fc 10 94 24 50 04 	vmovups 0x450(%rsp),%ymm2
 1210fe0:	00 00 
 1210fe2:	c5 fc 10 9c 24 70 04 	vmovups 0x470(%rsp),%ymm3
 1210fe9:	00 00 
 1210feb:	c5 fc 11 9c 24 d0 06 	vmovups %ymm3,0x6d0(%rsp)
 1210ff2:	00 00 
 1210ff4:	c5 fc 11 94 24 b0 06 	vmovups %ymm2,0x6b0(%rsp)
 1210ffb:	00 00 
 1210ffd:	c5 fc 11 8c 24 90 06 	vmovups %ymm1,0x690(%rsp)
 1211004:	00 00 
 1211006:	c5 fc 11 84 24 70 06 	vmovups %ymm0,0x670(%rsp)
 121100d:	00 00 
 121100f:	0f b6 44 24 20       	movzbl 0x20(%rsp),%eax
 1211014:	c5 fe 6f 84 24 f0 03 	vmovdqu 0x3f0(%rsp),%ymm0
 121101b:	00 00 
 121101d:	c5 fe 7f 84 24 50 09 	vmovdqu %ymm0,0x950(%rsp)
 1211024:	00 00 
 1211026:	88 84 24 51 0b 00 00 	mov    %al,0xb51(%rsp)
 121102d:	48 c7 84 24 40 09 00 	movq   $0x0,0x940(%rsp)
 1211034:	00 00 00 00 00 
 1211039:	66 c7 84 24 54 0b 00 	movw   $0x0,0xb54(%rsp)
 1211040:	00 00 00 
 1211043:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 1211047:	c5 fe 7f 84 24 70 09 	vmovdqu %ymm0,0x970(%rsp)
 121104e:	00 00 
 1211050:	c5 fe 7f 84 24 90 09 	vmovdqu %ymm0,0x990(%rsp)
 1211057:	00 00 
 1211059:	c5 fe 7f 84 24 b0 09 	vmovdqu %ymm0,0x9b0(%rsp)
 1211060:	00 00 
 1211062:	c5 fe 7f 84 24 d0 09 	vmovdqu %ymm0,0x9d0(%rsp)
 1211069:	00 00 
 121106b:	c5 fe 7f 84 24 f0 09 	vmovdqu %ymm0,0x9f0(%rsp)
 1211072:	00 00 
 1211074:	c5 fe 7f 84 24 10 0a 	vmovdqu %ymm0,0xa10(%rsp)
 121107b:	00 00 
 121107d:	c5 fe 7f 84 24 30 0a 	vmovdqu %ymm0,0xa30(%rsp)
 1211084:	00 00 
 1211086:	c5 fe 7f 84 24 50 0a 	vmovdqu %ymm0,0xa50(%rsp)
 121108d:	00 00 
 121108f:	c5 fe 7f 84 24 70 0a 	vmovdqu %ymm0,0xa70(%rsp)
 1211096:	00 00 
 1211098:	c5 fe 7f 84 24 90 0a 	vmovdqu %ymm0,0xa90(%rsp)
 121109f:	00 00 
 12110a1:	c5 fe 7f 84 24 b0 0a 	vmovdqu %ymm0,0xab0(%rsp)
 12110a8:	00 00 
 12110aa:	c5 fe 7f 84 24 d0 0a 	vmovdqu %ymm0,0xad0(%rsp)
 12110b1:	00 00 
 12110b3:	c5 fe 7f 84 24 f0 0a 	vmovdqu %ymm0,0xaf0(%rsp)
 12110ba:	00 00 
 12110bc:	c5 fe 7f 84 24 10 0b 	vmovdqu %ymm0,0xb10(%rsp)
 12110c3:	00 00 
 12110c5:	48 c7 84 24 30 0b 00 	movq   $0x0,0xb30(%rsp)
 12110cc:	00 00 00 00 00 
 12110d1:	c6 84 24 48 0b 00 00 	movb   $0x38,0xb48(%rsp)
 12110d8:	38 
 12110d9:	c6 84 24 50 0b 00 00 	movb   $0x0,0xb50(%rsp)
 12110e0:	00 
 12110e1:	0f b7 05 60 9e e2 ff 	movzwl -0x1d61a0(%rip),%eax        # 103af48 <__anon_35281>
 12110e8:	66 89 84 24 4a 0b 00 	mov    %ax,0xb4a(%rsp)
 12110ef:	00 
 12110f0:	40 88 b4 24 49 0b 00 	mov    %sil,0xb49(%rsp)
 12110f7:	00 
 12110f8:	48 8b 84 24 f0 00 00 	mov    0xf0(%rsp),%rax
 12110ff:	00 
 1211100:	48 89 84 24 30 09 00 	mov    %rax,0x930(%rsp)
 1211107:	00 
 1211108:	48 8b 84 24 e8 00 00 	mov    0xe8(%rsp),%rax
 121110f:	00 
 1211110:	48 89 84 24 38 09 00 	mov    %rax,0x938(%rsp)
 1211117:	00 
 1211118:	c7 84 24 4c 0b 00 00 	movl   $0x1000101,0xb4c(%rsp)
 121111f:	01 01 00 01 
 1211123:	48 8b 84 24 e0 00 00 	mov    0xe0(%rsp),%rax
 121112a:	00 
 121112b:	48 89 84 24 40 0b 00 	mov    %rax,0xb40(%rsp)
 1211132:	00 
 1211133:	48 8b 84 24 d8 00 00 	mov    0xd8(%rsp),%rax
 121113a:	00 
 121113b:	48 89 84 24 38 0b 00 	mov    %rax,0xb38(%rsp)
 1211142:	00 
 1211143:	66 c7 84 24 52 0b 00 	movw   $0x0,0xb52(%rsp)
 121114a:	00 00 00 
 121114d:	48 c7 84 24 48 09 00 	movq   $0x0,0x948(%rsp)
 1211154:	00 00 00 00 00 
 1211159:	48 8d 84 24 30 09 00 	lea    0x930(%rsp),%rax
 1211160:	00 
 1211161:	4c 8d 94 24 70 06 00 	lea    0x670(%rsp),%r10
 1211168:	00 
 1211169:	48 8d bc 24 d8 03 00 	lea    0x3d8(%rsp),%rdi
 1211170:	00 
 1211171:	48 8b 74 24 48       	mov    0x48(%rsp),%rsi
 1211176:	48 8b 94 24 c8 00 00 	mov    0xc8(%rsp),%rdx
 121117d:	00 
 121117e:	48 8b 8c 24 a8 00 00 	mov    0xa8(%rsp),%rcx
 1211185:	00 
 1211186:	4c 8b 84 24 b0 00 00 	mov    0xb0(%rsp),%r8
 121118d:	00 
 121118e:	50                   	push   %rax
 121118f:	41 52                	push   %r10
 1211191:	c5 f8 77             	vzeroupper 
 1211194:	e8 67 38 f6 ff       	call   1174a00 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307>
 1211199:	48 83 c4 10          	add    $0x10,%rsp
 121119d:	0f b7 9c 24 e8 03 00 	movzwl 0x3e8(%rsp),%ebx
 12111a4:	00 
 12111a5:	66 85 db             	test   %bx,%bx
 12111a8:	0f 85 02 05 00 00    	jne    12116b0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x18f0>
 12111ae:	4c 89 fb             	mov    %r15,%rbx
 12111b1:	4c 8b a4 24 d8 03 00 	mov    0x3d8(%rsp),%r12
 12111b8:	00 
 12111b9:	4c 8b bc 24 e0 03 00 	mov    0x3e0(%rsp),%r15
 12111c0:	00 
 12111c1:	4c 8b 4c 24 38       	mov    0x38(%rsp),%r9
 12111c6:	4d 39 f9             	cmp    %r15,%r9
 12111c9:	0f 83 dc 02 00 00    	jae    12114ab <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x16eb>
 12111cf:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 12111d4:	48 8b 38             	mov    (%rax),%rdi
 12111d7:	48 8b 40 08          	mov    0x8(%rax),%rax
 12111db:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12111df:	4c 89 e6             	mov    %r12,%rsi
 12111e2:	4c 89 fa             	mov    %r15,%rdx
 12111e5:	31 c9                	xor    %ecx,%ecx
 12111e7:	4d 89 cf             	mov    %r9,%r15
 12111ea:	ff 50 18             	call   *0x18(%rax)
 12111ed:	c5 fc 10 84 24 90 02 	vmovups 0x290(%rsp),%ymm0
 12111f4:	00 00 
 12111f6:	48 8b 45 10          	mov    0x10(%rbp),%rax
 12111fa:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 12111ff:	c5 fc 10 84 24 20 02 	vmovups 0x220(%rsp),%ymm0
 1211206:	00 00 
 1211208:	c5 fc 10 8c 24 40 02 	vmovups 0x240(%rsp),%ymm1
 121120f:	00 00 
 1211211:	c5 fc 10 94 24 60 02 	vmovups 0x260(%rsp),%ymm2
 1211218:	00 00 
 121121a:	c5 fc 10 9c 24 80 02 	vmovups 0x280(%rsp),%ymm3
 1211221:	00 00 
 1211223:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1211228:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 121122d:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1211232:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1211236:	48 8b 54 24 50       	mov    0x50(%rsp),%rdx
 121123b:	66 c7 82 60 01 00 00 	movw   $0x0,0x160(%rdx)
 1211242:	00 00 
 1211244:	4c 89 2a             	mov    %r13,(%rdx)
 1211247:	4c 89 7a 08          	mov    %r15,0x8(%rdx)
 121124b:	8b 44 24 40          	mov    0x40(%rsp),%eax
 121124f:	88 82 58 01 00 00    	mov    %al,0x158(%rdx)
 1211255:	48 8b 44 24 68       	mov    0x68(%rsp),%rax
 121125a:	48 89 42 10          	mov    %rax,0x10(%rdx)
 121125e:	0f b6 44 24 28       	movzbl 0x28(%rsp),%eax
 1211263:	88 42 18             	mov    %al,0x18(%rdx)
 1211266:	0f b6 44 24 1e       	movzbl 0x1e(%rsp),%eax
 121126b:	88 42 19             	mov    %al,0x19(%rdx)
 121126e:	c5 fc 28 84 24 40 01 	vmovaps 0x140(%rsp),%ymm0
 1211275:	00 00 
 1211277:	c5 fc 11 42 1a       	vmovups %ymm0,0x1a(%rdx)
 121127c:	c5 fc 28 84 24 00 01 	vmovaps 0x100(%rsp),%ymm0
 1211283:	00 00 
 1211285:	c5 fc 11 42 3a       	vmovups %ymm0,0x3a(%rdx)
 121128a:	8b 44 24 30          	mov    0x30(%rsp),%eax
 121128e:	89 42 5a             	mov    %eax,0x5a(%rdx)
 1211291:	0f b7 44 24 34       	movzwl 0x34(%rsp),%eax
 1211296:	66 89 42 5e          	mov    %ax,0x5e(%rdx)
 121129a:	44 88 72 60          	mov    %r14b,0x60(%rdx)
 121129e:	8b 84 24 80 00 00 00 	mov    0x80(%rsp),%eax
 12112a5:	8b 8c 24 83 00 00 00 	mov    0x83(%rsp),%ecx
 12112ac:	89 42 61             	mov    %eax,0x61(%rdx)
 12112af:	89 4a 64             	mov    %ecx,0x64(%rdx)
 12112b2:	c5 fc 10 84 24 b8 02 	vmovups 0x2b8(%rsp),%ymm0
 12112b9:	00 00 
 12112bb:	c5 fc 10 8c 24 d8 02 	vmovups 0x2d8(%rsp),%ymm1
 12112c2:	00 00 
 12112c4:	c5 fc 10 94 24 f8 02 	vmovups 0x2f8(%rsp),%ymm2
 12112cb:	00 00 
 12112cd:	c5 fc 10 9c 24 18 03 	vmovups 0x318(%rsp),%ymm3
 12112d4:	00 00 
 12112d6:	c5 fc 11 42 68       	vmovups %ymm0,0x68(%rdx)
 12112db:	c5 fc 11 8a 88 00 00 	vmovups %ymm1,0x88(%rdx)
 12112e2:	00 
 12112e3:	c5 fc 11 92 a8 00 00 	vmovups %ymm2,0xa8(%rdx)
 12112ea:	00 
 12112eb:	c5 fc 11 9a c8 00 00 	vmovups %ymm3,0xc8(%rdx)
 12112f2:	00 
 12112f3:	c5 fc 10 84 24 38 03 	vmovups 0x338(%rsp),%ymm0
 12112fa:	00 00 
 12112fc:	c5 fc 11 82 e8 00 00 	vmovups %ymm0,0xe8(%rdx)
 1211303:	00 
 1211304:	c5 fc 10 84 24 58 03 	vmovups 0x358(%rsp),%ymm0
 121130b:	00 00 
 121130d:	c5 fc 11 82 08 01 00 	vmovups %ymm0,0x108(%rdx)
 1211314:	00 
 1211315:	c5 fc 10 84 24 78 03 	vmovups 0x378(%rsp),%ymm0
 121131c:	00 00 
 121131e:	c5 fc 11 82 28 01 00 	vmovups %ymm0,0x128(%rdx)
 1211325:	00 
 1211326:	c5 fe 6f 84 24 88 03 	vmovdqu 0x388(%rsp),%ymm0
 121132d:	00 00 
 121132f:	c5 fe 7f 82 38 01 00 	vmovdqu %ymm0,0x138(%rdx)
 1211336:	00 
 1211337:	80 e3 03             	and    $0x3,%bl
 121133a:	88 9a 59 01 00 00    	mov    %bl,0x159(%rdx)
 1211340:	e9 45 01 00 00       	jmp    121148a <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x16ca>
 1211345:	c5 fc 10 84 24 90 02 	vmovups 0x290(%rsp),%ymm0
 121134c:	00 00 
 121134e:	48 8b 45 10          	mov    0x10(%rbp),%rax
 1211352:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1211357:	c5 fc 10 84 24 20 02 	vmovups 0x220(%rsp),%ymm0
 121135e:	00 00 
 1211360:	c5 fc 10 8c 24 40 02 	vmovups 0x240(%rsp),%ymm1
 1211367:	00 00 
 1211369:	c5 fc 10 94 24 60 02 	vmovups 0x260(%rsp),%ymm2
 1211370:	00 00 
 1211372:	c5 fc 10 9c 24 80 02 	vmovups 0x280(%rsp),%ymm3
 1211379:	00 00 
 121137b:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1211380:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1211385:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 121138a:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 121138e:	48 8b 54 24 50       	mov    0x50(%rsp),%rdx
 1211393:	66 c7 82 60 01 00 00 	movw   $0x0,0x160(%rdx)
 121139a:	00 00 
 121139c:	4c 89 12             	mov    %r10,(%rdx)
 121139f:	48 8b 44 24 38       	mov    0x38(%rsp),%rax
 12113a4:	48 89 42 08          	mov    %rax,0x8(%rdx)
 12113a8:	c6 82 58 01 00 00 00 	movb   $0x0,0x158(%rdx)
 12113af:	48 8b 44 24 68       	mov    0x68(%rsp),%rax
 12113b4:	48 89 42 10          	mov    %rax,0x10(%rdx)
 12113b8:	0f b6 44 24 28       	movzbl 0x28(%rsp),%eax
 12113bd:	88 42 18             	mov    %al,0x18(%rdx)
 12113c0:	0f b6 44 24 1e       	movzbl 0x1e(%rsp),%eax
 12113c5:	88 42 19             	mov    %al,0x19(%rdx)
 12113c8:	c5 fe 7f 6a 1a       	vmovdqu %ymm5,0x1a(%rdx)
 12113cd:	c5 fe 7f 62 3a       	vmovdqu %ymm4,0x3a(%rdx)
 12113d2:	8b 44 24 30          	mov    0x30(%rsp),%eax
 12113d6:	89 42 5a             	mov    %eax,0x5a(%rdx)
 12113d9:	0f b7 44 24 34       	movzwl 0x34(%rsp),%eax
 12113de:	66 89 42 5e          	mov    %ax,0x5e(%rdx)
 12113e2:	44 88 5a 60          	mov    %r11b,0x60(%rdx)
 12113e6:	8b 84 24 80 00 00 00 	mov    0x80(%rsp),%eax
 12113ed:	8b 8c 24 83 00 00 00 	mov    0x83(%rsp),%ecx
 12113f4:	89 42 61             	mov    %eax,0x61(%rdx)
 12113f7:	89 4a 64             	mov    %ecx,0x64(%rdx)
 12113fa:	c5 fc 10 84 24 b8 02 	vmovups 0x2b8(%rsp),%ymm0
 1211401:	00 00 
 1211403:	c5 fc 10 8c 24 d8 02 	vmovups 0x2d8(%rsp),%ymm1
 121140a:	00 00 
 121140c:	c5 fc 10 94 24 f8 02 	vmovups 0x2f8(%rsp),%ymm2
 1211413:	00 00 
 1211415:	c5 fc 10 9c 24 18 03 	vmovups 0x318(%rsp),%ymm3
 121141c:	00 00 
 121141e:	c5 fc 11 42 68       	vmovups %ymm0,0x68(%rdx)
 1211423:	c5 fc 11 8a 88 00 00 	vmovups %ymm1,0x88(%rdx)
 121142a:	00 
 121142b:	c5 fc 11 92 a8 00 00 	vmovups %ymm2,0xa8(%rdx)
 1211432:	00 
 1211433:	c5 fc 11 9a c8 00 00 	vmovups %ymm3,0xc8(%rdx)
 121143a:	00 
 121143b:	c5 fc 10 84 24 38 03 	vmovups 0x338(%rsp),%ymm0
 1211442:	00 00 
 1211444:	c5 fc 11 82 e8 00 00 	vmovups %ymm0,0xe8(%rdx)
 121144b:	00 
 121144c:	c5 fc 10 84 24 58 03 	vmovups 0x358(%rsp),%ymm0
 1211453:	00 00 
 1211455:	c5 fc 11 82 08 01 00 	vmovups %ymm0,0x108(%rdx)
 121145c:	00 
 121145d:	c5 fc 10 84 24 78 03 	vmovups 0x378(%rsp),%ymm0
 1211464:	00 00 
 1211466:	c5 fc 11 82 28 01 00 	vmovups %ymm0,0x128(%rdx)
 121146d:	00 
 121146e:	c5 fe 6f 84 24 88 03 	vmovdqu 0x388(%rsp),%ymm0
 1211475:	00 00 
 1211477:	c5 fe 7f 82 38 01 00 	vmovdqu %ymm0,0x138(%rdx)
 121147e:	00 
 121147f:	41 80 e7 03          	and    $0x3,%r15b
 1211483:	44 88 ba 59 01 00 00 	mov    %r15b,0x159(%rdx)
 121148a:	48 8b 84 24 c0 00 00 	mov    0xc0(%rsp),%rax
 1211491:	00 
 1211492:	24 01                	and    $0x1,%al
 1211494:	88 82 5a 01 00 00    	mov    %al,0x15a(%rdx)
 121149a:	0f b7 44 24 2e       	movzwl 0x2e(%rsp),%eax
 121149f:	66 89 82 5b 01 00 00 	mov    %ax,0x15b(%rdx)
 12114a6:	e9 04 01 00 00       	jmp    12115af <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17ef>
 12114ab:	4d 85 c9             	test   %r9,%r9
 12114ae:	74 1b                	je     12114cb <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x170b>
 12114b0:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 12114b5:	48 8b 38             	mov    (%rax),%rdi
 12114b8:	48 8b 40 08          	mov    0x8(%rax),%rax
 12114bc:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12114c0:	4c 89 ee             	mov    %r13,%rsi
 12114c3:	4c 89 ca             	mov    %r9,%rdx
 12114c6:	31 c9                	xor    %ecx,%ecx
 12114c8:	ff 50 18             	call   *0x18(%rax)
 12114cb:	c5 fc 10 84 24 e0 06 	vmovups 0x6e0(%rsp),%ymm0
 12114d2:	00 00 
 12114d4:	48 8b 45 10          	mov    0x10(%rbp),%rax
 12114d8:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 12114dd:	c5 fe 6f 84 24 70 06 	vmovdqu 0x670(%rsp),%ymm0
 12114e4:	00 00 
 12114e6:	c5 fc 10 8c 24 90 06 	vmovups 0x690(%rsp),%ymm1
 12114ed:	00 00 
 12114ef:	c5 fc 10 94 24 b0 06 	vmovups 0x6b0(%rsp),%ymm2
 12114f6:	00 00 
 12114f8:	c5 fc 10 9c 24 d0 06 	vmovups 0x6d0(%rsp),%ymm3
 12114ff:	00 00 
 1211501:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1211506:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 121150b:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1211510:	c5 fe 7f 00          	vmovdqu %ymm0,(%rax)
 1211514:	48 8b 44 24 50       	mov    0x50(%rsp),%rax
 1211519:	66 c7 80 60 01 00 00 	movw   $0x0,0x160(%rax)
 1211520:	00 00 
 1211522:	4c 89 20             	mov    %r12,(%rax)
 1211525:	4c 89 78 08          	mov    %r15,0x8(%rax)
 1211529:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 121152d:	c5 fe 7f 40 10       	vmovdqu %ymm0,0x10(%rax)
 1211532:	c5 fe 7f 40 30       	vmovdqu %ymm0,0x30(%rax)
 1211537:	c5 fe 7f 40 48       	vmovdqu %ymm0,0x48(%rax)
 121153c:	c7 80 58 01 00 00 00 	movl   $0x0,0x158(%rax)
 1211543:	00 00 00 
 1211546:	c6 80 5c 01 00 00 00 	movb   $0x0,0x15c(%rax)
 121154d:	eb 60                	jmp    12115af <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17ef>
 121154f:	48 85 d2             	test   %rdx,%rdx
 1211552:	74 42                	je     1211596 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17d6>
 1211554:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 1211559:	48 8b 38             	mov    (%rax),%rdi
 121155c:	48 8b 40 08          	mov    0x8(%rax),%rax
 1211560:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1211564:	48 8b 74 24 60       	mov    0x60(%rsp),%rsi
 1211569:	31 c9                	xor    %ecx,%ecx
 121156b:	eb 23                	jmp    1211590 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17d0>
 121156d:	4d 85 ff             	test   %r15,%r15
 1211570:	48 8b b4 24 b8 00 00 	mov    0xb8(%rsp),%rsi
 1211577:	00 
 1211578:	74 1c                	je     1211596 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17d6>
 121157a:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 121157f:	48 8b 38             	mov    (%rax),%rdi
 1211582:	48 8b 40 08          	mov    0x8(%rax),%rax
 1211586:	4c 89 fa             	mov    %r15,%rdx
 1211589:	31 c9                	xor    %ecx,%ecx
 121158b:	4c 8b 44 24 38       	mov    0x38(%rsp),%r8
 1211590:	c5 f8 77             	vzeroupper 
 1211593:	ff 50 18             	call   *0x18(%rax)
 1211596:	48 8d 35 d3 de e2 ff 	lea    -0x1d212d(%rip),%rsi        # 103f470 <__anon_46346>
 121159d:	ba 68 01 00 00       	mov    $0x168,%edx
 12115a2:	48 8b 7c 24 50       	mov    0x50(%rsp),%rdi
 12115a7:	c5 f8 77             	vzeroupper 
 12115aa:	e8 71 4c 08 00       	call   1296220 <compiler_rt.memcpy.memcpyFast>
 12115af:	48 8d 65 d8          	lea    -0x28(%rbp),%rsp
 12115b3:	5b                   	pop    %rbx
 12115b4:	41 5c                	pop    %r12
 12115b6:	41 5d                	pop    %r13
 12115b8:	41 5e                	pop    %r14
 12115ba:	41 5f                	pop    %r15
 12115bc:	5d                   	pop    %rbp
 12115bd:	c5 f8 77             	vzeroupper 
 12115c0:	c3                   	ret    
 12115c1:	c5 fc 10 84 24 90 02 	vmovups 0x290(%rsp),%ymm0
 12115c8:	00 00 
 12115ca:	48 8b 45 10          	mov    0x10(%rbp),%rax
 12115ce:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 12115d3:	c5 fc 10 84 24 20 02 	vmovups 0x220(%rsp),%ymm0
 12115da:	00 00 
 12115dc:	c5 fc 10 8c 24 40 02 	vmovups 0x240(%rsp),%ymm1
 12115e3:	00 00 
 12115e5:	c5 fc 10 94 24 60 02 	vmovups 0x260(%rsp),%ymm2
 12115ec:	00 00 
 12115ee:	c5 fc 10 9c 24 80 02 	vmovups 0x280(%rsp),%ymm3
 12115f5:	00 00 
 12115f7:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 12115fc:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1211601:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1211606:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 121160a:	48 8b 54 24 50       	mov    0x50(%rsp),%rdx
 121160f:	66 c7 82 60 01 00 00 	movw   $0x0,0x160(%rdx)
 1211616:	00 00 
 1211618:	4c 89 12             	mov    %r10,(%rdx)
 121161b:	48 8b 44 24 38       	mov    0x38(%rsp),%rax
 1211620:	48 89 42 08          	mov    %rax,0x8(%rdx)
 1211624:	8b 44 24 40          	mov    0x40(%rsp),%eax
 1211628:	88 82 58 01 00 00    	mov    %al,0x158(%rdx)
 121162e:	e9 7c fd ff ff       	jmp    12113af <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x15ef>
 1211633:	48 8b 54 24 38       	mov    0x38(%rsp),%rdx
 1211638:	48 85 d2             	test   %rdx,%rdx
 121163b:	74 1a                	je     1211657 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1897>
 121163d:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 1211642:	48 8b 38             	mov    (%rax),%rdi
 1211645:	48 8b 40 08          	mov    0x8(%rax),%rax
 1211649:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 121164d:	48 8b 74 24 60       	mov    0x60(%rsp),%rsi
 1211652:	31 c9                	xor    %ecx,%ecx
 1211654:	ff 50 18             	call   *0x18(%rax)
 1211657:	48 8b 44 24 50       	mov    0x50(%rsp),%rax
 121165c:	66 44 89 b8 60 01 00 	mov    %r15w,0x160(%rax)
 1211663:	00 
 1211664:	e9 46 ff ff ff       	jmp    12115af <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17ef>
 1211669:	48 8b 4c 24 50       	mov    0x50(%rsp),%rcx
 121166e:	66 89 81 60 01 00 00 	mov    %ax,0x160(%rcx)
 1211675:	e9 35 ff ff ff       	jmp    12115af <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17ef>
 121167a:	48 8b 54 24 38       	mov    0x38(%rsp),%rdx
 121167f:	48 85 d2             	test   %rdx,%rdx
 1211682:	74 1a                	je     121169e <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x18de>
 1211684:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 1211689:	48 8b 38             	mov    (%rax),%rdi
 121168c:	48 8b 40 08          	mov    0x8(%rax),%rax
 1211690:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1211694:	48 8b 74 24 60       	mov    0x60(%rsp),%rsi
 1211699:	31 c9                	xor    %ecx,%ecx
 121169b:	ff 50 18             	call   *0x18(%rax)
 121169e:	48 8b 44 24 50       	mov    0x50(%rsp),%rax
 12116a3:	66 44 89 b0 60 01 00 	mov    %r14w,0x160(%rax)
 12116aa:	00 
 12116ab:	e9 ff fe ff ff       	jmp    12115af <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17ef>
 12116b0:	48 8b 54 24 38       	mov    0x38(%rsp),%rdx
 12116b5:	48 85 d2             	test   %rdx,%rdx
 12116b8:	74 18                	je     12116d2 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1912>
 12116ba:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 12116bf:	48 8b 38             	mov    (%rax),%rdi
 12116c2:	48 8b 40 08          	mov    0x8(%rax),%rax
 12116c6:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12116ca:	4c 89 ee             	mov    %r13,%rsi
 12116cd:	31 c9                	xor    %ecx,%ecx
 12116cf:	ff 50 18             	call   *0x18(%rax)
 12116d2:	48 8b 44 24 50       	mov    0x50(%rsp),%rax
 12116d7:	66 89 98 60 01 00 00 	mov    %bx,0x160(%rax)
 12116de:	e9 cc fe ff ff       	jmp    12115af <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17ef>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
