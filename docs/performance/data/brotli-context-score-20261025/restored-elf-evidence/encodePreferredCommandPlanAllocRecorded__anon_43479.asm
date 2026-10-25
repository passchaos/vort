
/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/ee59b567d9fa359fa365d21c6dd4ba7f/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000120fe10 <br.encodePreferredCommandPlanAllocRecorded__anon_43479>:
 120fe10:	55                   	push   %rbp
 120fe11:	48 89 e5             	mov    %rsp,%rbp
 120fe14:	41 57                	push   %r15
 120fe16:	41 56                	push   %r14
 120fe18:	41 55                	push   %r13
 120fe1a:	41 54                	push   %r12
 120fe1c:	53                   	push   %rbx
 120fe1d:	48 83 e4 e0          	and    $0xffffffffffffffe0,%rsp
 120fe21:	48 81 ec c0 10 00 00 	sub    $0x10c0,%rsp
 120fe28:	4c 89 84 24 b0 00 00 	mov    %r8,0xb0(%rsp)
 120fe2f:	00 
 120fe30:	48 89 8c 24 a8 00 00 	mov    %rcx,0xa8(%rsp)
 120fe37:	00 
 120fe38:	48 89 94 24 c8 00 00 	mov    %rdx,0xc8(%rsp)
 120fe3f:	00 
 120fe40:	48 89 74 24 48       	mov    %rsi,0x48(%rsp)
 120fe45:	48 89 7c 24 50       	mov    %rdi,0x50(%rsp)
 120fe4a:	48 8b 45 18          	mov    0x18(%rbp),%rax
 120fe4e:	48 8b 08             	mov    (%rax),%rcx
 120fe51:	48 89 8c 24 f0 00 00 	mov    %rcx,0xf0(%rsp)
 120fe58:	00 
 120fe59:	48 8b 48 08          	mov    0x8(%rax),%rcx
 120fe5d:	48 89 8c 24 e8 00 00 	mov    %rcx,0xe8(%rsp)
 120fe64:	00 
 120fe65:	48 8b 48 10          	mov    0x10(%rax),%rcx
 120fe69:	48 89 8c 24 e0 00 00 	mov    %rcx,0xe0(%rsp)
 120fe70:	00 
 120fe71:	48 8b 48 18          	mov    0x18(%rax),%rcx
 120fe75:	48 89 8c 24 d8 00 00 	mov    %rcx,0xd8(%rsp)
 120fe7c:	00 
 120fe7d:	c5 fe 6f 40 20       	vmovdqu 0x20(%rax),%ymm0
 120fe82:	c5 fe 7f 84 24 f0 03 	vmovdqu %ymm0,0x3f0(%rsp)
 120fe89:	00 00 
 120fe8b:	0f b6 50 40          	movzbl 0x40(%rax),%edx
 120fe8f:	88 54 24 20          	mov    %dl,0x20(%rsp)
 120fe93:	44 0f b6 40 41       	movzbl 0x41(%rax),%r8d
 120fe98:	44 0f b6 50 42       	movzbl 0x42(%rax),%r10d
 120fe9d:	44 0f b6 58 43       	movzbl 0x43(%rax),%r11d
 120fea2:	0f b6 48 44          	movzbl 0x44(%rax),%ecx
 120fea6:	88 8c 24 80 01 00 00 	mov    %cl,0x180(%rsp)
 120fead:	0f b6 70 46          	movzbl 0x46(%rax),%esi
 120feb1:	0f b6 78 47          	movzbl 0x47(%rax),%edi
 120feb5:	0f b6 48 4e          	movzbl 0x4e(%rax),%ecx
 120feb9:	41 f6 c0 01          	test   $0x1,%r8b
 120febd:	4c 89 8c 24 d0 00 00 	mov    %r9,0xd0(%rsp)
 120fec4:	00 
 120fec5:	88 4c 24 1f          	mov    %cl,0x1f(%rsp)
 120fec9:	0f 84 bd 01 00 00    	je     121008c <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x27c>
 120fecf:	48 83 c0 20          	add    $0x20,%rax
 120fed3:	c5 fe 6f 00          	vmovdqu (%rax),%ymm0
 120fed7:	c5 fe 7f 84 24 20 01 	vmovdqu %ymm0,0x120(%rsp)
 120fede:	00 00 
 120fee0:	89 c8                	mov    %ecx,%eax
 120fee2:	24 1f                	and    $0x1f,%al
 120fee4:	88 44 24 47          	mov    %al,0x47(%rsp)
 120fee8:	4d 85 c9             	test   %r9,%r9
 120feeb:	0f 84 9b 01 00 00    	je     121008c <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x27c>
 120fef1:	44 88 9c 24 00 01 00 	mov    %r11b,0x100(%rsp)
 120fef8:	00 
 120fef9:	44 88 54 24 60       	mov    %r10b,0x60(%rsp)
 120fefe:	44 88 44 24 68       	mov    %r8b,0x68(%rsp)
 120ff03:	40 88 bc 24 88 00 00 	mov    %dil,0x88(%rsp)
 120ff0a:	00 
 120ff0b:	40 88 b4 24 60 01 00 	mov    %sil,0x160(%rsp)
 120ff12:	00 
 120ff13:	88 54 24 38          	mov    %dl,0x38(%rsp)
 120ff17:	0f b6 05 6a 2c e0 ff 	movzbl -0x1fd396(%rip),%eax        # 1012b88 <__anon_35632>
 120ff1e:	48 8b 9c 24 28 01 00 	mov    0x128(%rsp),%rbx
 120ff25:	00 
 120ff26:	4c 8b bc 24 30 01 00 	mov    0x130(%rsp),%r15
 120ff2d:	00 
 120ff2e:	4c 8b a4 24 38 01 00 	mov    0x138(%rsp),%r12
 120ff35:	00 
 120ff36:	31 f6                	xor    %esi,%esi
 120ff38:	0f b6 4c 24 47       	movzbl 0x47(%rsp),%ecx
 120ff3d:	89 4c 24 28          	mov    %ecx,0x28(%rsp)
 120ff41:	24 0f                	and    $0xf,%al
 120ff43:	88 44 24 1e          	mov    %al,0x1e(%rsp)
 120ff47:	4c 8b ac 24 b0 00 00 	mov    0xb0(%rsp),%r13
 120ff4e:	00 
 120ff4f:	4d 89 ce             	mov    %r9,%r14
 120ff52:	eb 2b                	jmp    120ff7f <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x16f>
 120ff54:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 120ff5b:	00 00 00 00 00 
 120ff60:	4c 89 e1             	mov    %r12,%rcx
 120ff63:	4d 89 fc             	mov    %r15,%r12
 120ff66:	49 89 df             	mov    %rbx,%r15
 120ff69:	4c 89 fb             	mov    %r15,%rbx
 120ff6c:	4d 89 e7             	mov    %r12,%r15
 120ff6f:	49 83 c5 60          	add    $0x60,%r13
 120ff73:	49 89 cc             	mov    %rcx,%r12
 120ff76:	49 ff ce             	dec    %r14
 120ff79:	0f 84 17 01 00 00    	je     1210096 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x286>
 120ff7f:	c4 c1 7e 6f 45 00    	vmovdqu 0x0(%r13),%ymm0
 120ff85:	c4 c1 7c 10 4d 20    	vmovups 0x20(%r13),%ymm1
 120ff8b:	c4 c1 7c 10 55 40    	vmovups 0x40(%r13),%ymm2
 120ff91:	c5 fc 11 94 24 00 02 	vmovups %ymm2,0x200(%rsp)
 120ff98:	00 00 
 120ff9a:	c5 fc 11 8c 24 e0 01 	vmovups %ymm1,0x1e0(%rsp)
 120ffa1:	00 00 
 120ffa3:	c5 fe 7f 84 24 c0 01 	vmovdqu %ymm0,0x1c0(%rsp)
 120ffaa:	00 00 
 120ffac:	f6 84 24 18 02 00 00 	testb  $0x1,0x218(%rsp)
 120ffb3:	01 
 120ffb4:	74 aa                	je     120ff60 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x150>
 120ffb6:	0f b6 84 24 19 02 00 	movzbl 0x219(%rsp),%eax
 120ffbd:	00 
 120ffbe:	24 03                	and    $0x3,%al
 120ffc0:	3c 02                	cmp    $0x2,%al
 120ffc2:	74 9c                	je     120ff60 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x150>
 120ffc4:	48 89 b4 24 90 00 00 	mov    %rsi,0x90(%rsp)
 120ffcb:	00 
 120ffcc:	48 8d bc 24 b0 01 00 	lea    0x1b0(%rsp),%rdi
 120ffd3:	00 
 120ffd4:	48 8d b4 24 c0 01 00 	lea    0x1c0(%rsp),%rsi
 120ffdb:	00 
 120ffdc:	8b 54 24 28          	mov    0x28(%rsp),%edx
 120ffe0:	48 8b 8c 24 e0 00 00 	mov    0xe0(%rsp),%rcx
 120ffe7:	00 
 120ffe8:	4c 8b 84 24 d8 00 00 	mov    0xd8(%rsp),%r8
 120ffef:	00 
 120fff0:	c5 f8 77             	vzeroupper 
 120fff3:	e8 28 f4 fa ff       	call   11bf420 <br.commandWireDistance>
 120fff8:	0f b7 84 24 b8 01 00 	movzwl 0x1b8(%rsp),%eax
 120ffff:	00 
 1210000:	66 85 c0             	test   %ax,%ax
 1210003:	0f 85 b0 16 00 00    	jne    12116b9 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x18a9>
 1210009:	48 8b b4 24 b0 01 00 	mov    0x1b0(%rsp),%rsi
 1210010:	00 
 1210011:	48 8d 7c 24 5e       	lea    0x5e(%rsp),%rdi
 1210016:	48 89 74 24 78       	mov    %rsi,0x78(%rsp)
 121001b:	48 8d 94 24 20 01 00 	lea    0x120(%rsp),%rdx
 1210022:	00 
 1210023:	e8 c8 ed fa ff       	call   11bedf0 <br.decoder.distance_history.symbolForDistance>
 1210028:	0f b6 4c 24 5f       	movzbl 0x5f(%rsp),%ecx
 121002d:	48 8b b4 24 90 00 00 	mov    0x90(%rsp),%rsi
 1210034:	00 
 1210035:	48 8d 46 01          	lea    0x1(%rsi),%rax
 1210039:	84 c9                	test   %cl,%cl
 121003b:	74 1f                	je     121005c <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x24c>
 121003d:	0f b6 54 24 5e       	movzbl 0x5e(%rsp),%edx
 1210042:	80 e2 0f             	and    $0xf,%dl
 1210045:	3a 54 24 1e          	cmp    0x1e(%rsp),%dl
 1210049:	75 11                	jne    121005c <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x24c>
 121004b:	4c 89 e1             	mov    %r12,%rcx
 121004e:	4d 89 fc             	mov    %r15,%r12
 1210051:	49 89 df             	mov    %rbx,%r15
 1210054:	48 89 c6             	mov    %rax,%rsi
 1210057:	e9 0d ff ff ff       	jmp    120ff69 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x159>
 121005c:	84 c9                	test   %cl,%cl
 121005e:	48 0f 45 f0          	cmovne %rax,%rsi
 1210062:	48 89 9c 24 20 01 00 	mov    %rbx,0x120(%rsp)
 1210069:	00 
 121006a:	4c 89 bc 24 28 01 00 	mov    %r15,0x128(%rsp)
 1210071:	00 
 1210072:	4c 89 a4 24 30 01 00 	mov    %r12,0x130(%rsp)
 1210079:	00 
 121007a:	48 8b 4c 24 78       	mov    0x78(%rsp),%rcx
 121007f:	48 89 8c 24 38 01 00 	mov    %rcx,0x138(%rsp)
 1210086:	00 
 1210087:	e9 dd fe ff ff       	jmp    120ff69 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x159>
 121008c:	c7 44 24 40 00 00 00 	movl   $0x0,0x40(%rsp)
 1210093:	00 
 1210094:	eb 35                	jmp    12100cb <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x2bb>
 1210096:	48 83 fe 40          	cmp    $0x40,%rsi
 121009a:	0f 93 c0             	setae  %al
 121009d:	89 44 24 40          	mov    %eax,0x40(%rsp)
 12100a1:	0f b6 54 24 38       	movzbl 0x38(%rsp),%edx
 12100a6:	0f b6 b4 24 60 01 00 	movzbl 0x160(%rsp),%esi
 12100ad:	00 
 12100ae:	0f b6 bc 24 88 00 00 	movzbl 0x88(%rsp),%edi
 12100b5:	00 
 12100b6:	44 0f b6 44 24 68    	movzbl 0x68(%rsp),%r8d
 12100bc:	44 0f b6 54 24 60    	movzbl 0x60(%rsp),%r10d
 12100c2:	44 0f b6 9c 24 00 01 	movzbl 0x100(%rsp),%r11d
 12100c9:	00 00 
 12100cb:	45 84 db             	test   %r11b,%r11b
 12100ce:	0f 95 c0             	setne  %al
 12100d1:	41 0f b6 ca          	movzbl %r10b,%ecx
 12100d5:	41 0f b6 d8          	movzbl %r8b,%ebx
 12100d9:	0f 45 d9             	cmovne %ecx,%ebx
 12100dc:	20 c1                	and    %al,%cl
 12100de:	89 8c 24 f8 00 00 00 	mov    %ecx,0xf8(%rsp)
 12100e5:	75 21                	jne    1210108 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x2f8>
 12100e7:	80 7c 24 40 00       	cmpb   $0x0,0x40(%rsp)
 12100ec:	75 1a                	jne    1210108 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x2f8>
 12100ee:	4c 8d 3d 3b 22 e0 ff 	lea    -0x1fddc5(%rip),%r15        # 1012330 <__anon_35262>
 12100f5:	4c 8d 2d 3d 22 e0 ff 	lea    -0x1fddc3(%rip),%r13        # 1012339 <__anon_35262+0x9>
 12100fc:	4c 8d 25 7e 22 e0 ff 	lea    -0x1fdd82(%rip),%r12        # 1012381 <__anon_35262+0x51>
 1210103:	e9 d6 00 00 00       	jmp    12101de <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x3ce>
 1210108:	4c 8d a4 24 f9 04 00 	lea    0x4f9(%rsp),%r12
 121010f:	00 
 1210110:	4c 8d ac 24 b1 04 00 	lea    0x4b1(%rsp),%r13
 1210117:	00 
 1210118:	31 c0                	xor    %eax,%eax
 121011a:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 1210120:	48 83 f8 38          	cmp    $0x38,%rax
 1210124:	0f 93 84 04 c0 01 00 	setae  0x1c0(%rsp,%rax,1)
 121012b:	00 
 121012c:	0f 93 84 04 c1 01 00 	setae  0x1c1(%rsp,%rax,1)
 1210133:	00 
 1210134:	0f 93 84 04 c2 01 00 	setae  0x1c2(%rsp,%rax,1)
 121013b:	00 
 121013c:	0f 93 84 04 c3 01 00 	setae  0x1c3(%rsp,%rax,1)
 1210143:	00 
 1210144:	0f 93 84 04 c4 01 00 	setae  0x1c4(%rsp,%rax,1)
 121014b:	00 
 121014c:	0f 93 84 04 c5 01 00 	setae  0x1c5(%rsp,%rax,1)
 1210153:	00 
 1210154:	0f 93 84 04 c6 01 00 	setae  0x1c6(%rsp,%rax,1)
 121015b:	00 
 121015c:	0f 93 84 04 c7 01 00 	setae  0x1c7(%rsp,%rax,1)
 1210163:	00 
 1210164:	48 83 c0 08          	add    $0x8,%rax
 1210168:	48 83 f8 40          	cmp    $0x40,%rax
 121016c:	75 b2                	jne    1210120 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x310>
 121016e:	40 84 ff             	test   %dil,%dil
 1210171:	40 0f b6 c6          	movzbl %sil,%eax
 1210175:	b9 02 00 00 00       	mov    $0x2,%ecx
 121017a:	0f 45 c8             	cmovne %eax,%ecx
 121017d:	80 e1 03             	and    $0x3,%cl
 1210180:	88 8c 24 98 00 00 00 	mov    %cl,0x98(%rsp)
 1210187:	c5 fe 6f 84 24 c0 01 	vmovdqu 0x1c0(%rsp),%ymm0
 121018e:	00 00 
 1210190:	c5 fc 10 8c 24 e0 01 	vmovups 0x1e0(%rsp),%ymm1
 1210197:	00 00 
 1210199:	c5 fe 7f 84 24 b2 04 	vmovdqu %ymm0,0x4b2(%rsp)
 12101a0:	00 00 
 12101a2:	c5 fc 11 8c 24 d2 04 	vmovups %ymm1,0x4d2(%rsp)
 12101a9:	00 00 
 12101ab:	c6 84 24 a5 00 00 00 	movb   $0x2,0xa5(%rsp)
 12101b2:	02 
 12101b3:	48 c7 84 24 a8 04 00 	movq   $0x0,0x4a8(%rsp)
 12101ba:	00 00 00 00 00 
 12101bf:	88 8c 24 b0 04 00 00 	mov    %cl,0x4b0(%rsp)
 12101c6:	c6 84 24 b1 04 00 00 	movb   $0x2,0x4b1(%rsp)
 12101cd:	02 
 12101ce:	c6 84 24 f8 04 00 00 	movb   $0x1,0x4f8(%rsp)
 12101d5:	01 
 12101d6:	4c 8d bc 24 a8 04 00 	lea    0x4a8(%rsp),%r15
 12101dd:	00 
 12101de:	c5 fc 10 84 24 f0 03 	vmovups 0x3f0(%rsp),%ymm0
 12101e5:	00 00 
 12101e7:	c5 fc 11 84 24 28 07 	vmovups %ymm0,0x728(%rsp)
 12101ee:	00 00 
 12101f0:	80 e2 01             	and    $0x1,%dl
 12101f3:	88 94 24 29 09 00 00 	mov    %dl,0x929(%rsp)
 12101fa:	48 c7 84 24 18 07 00 	movq   $0x0,0x718(%rsp)
 1210201:	00 00 00 00 00 
 1210206:	8b 44 24 40          	mov    0x40(%rsp),%eax
 121020a:	88 84 24 2d 09 00 00 	mov    %al,0x92d(%rsp)
 1210211:	c6 84 24 2c 09 00 00 	movb   $0x0,0x92c(%rsp)
 1210218:	00 
 1210219:	c4 c1 7c 10 07       	vmovups (%r15),%ymm0
 121021e:	c4 c1 7c 10 4f 20    	vmovups 0x20(%r15),%ymm1
 1210224:	c5 fc 11 84 24 48 07 	vmovups %ymm0,0x748(%rsp)
 121022b:	00 00 
 121022d:	c5 fc 11 8c 24 68 07 	vmovups %ymm1,0x768(%rsp)
 1210234:	00 00 
 1210236:	c4 c1 7c 10 47 38    	vmovups 0x38(%r15),%ymm0
 121023c:	c5 fc 11 84 24 80 07 	vmovups %ymm0,0x780(%rsp)
 1210243:	00 00 
 1210245:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1210249:	c5 fc 11 84 24 f0 08 	vmovups %ymm0,0x8f0(%rsp)
 1210250:	00 00 
 1210252:	c5 fc 11 84 24 e0 08 	vmovups %ymm0,0x8e0(%rsp)
 1210259:	00 00 
 121025b:	c5 fc 11 84 24 c0 08 	vmovups %ymm0,0x8c0(%rsp)
 1210262:	00 00 
 1210264:	c5 fc 11 84 24 a0 08 	vmovups %ymm0,0x8a0(%rsp)
 121026b:	00 00 
 121026d:	c5 fc 11 84 24 80 08 	vmovups %ymm0,0x880(%rsp)
 1210274:	00 00 
 1210276:	c5 fc 11 84 24 60 08 	vmovups %ymm0,0x860(%rsp)
 121027d:	00 00 
 121027f:	c5 fc 11 84 24 40 08 	vmovups %ymm0,0x840(%rsp)
 1210286:	00 00 
 1210288:	c5 fc 11 84 24 20 08 	vmovups %ymm0,0x820(%rsp)
 121028f:	00 00 
 1210291:	c5 fc 11 84 24 00 08 	vmovups %ymm0,0x800(%rsp)
 1210298:	00 00 
 121029a:	c5 fc 11 84 24 e0 07 	vmovups %ymm0,0x7e0(%rsp)
 12102a1:	00 00 
 12102a3:	c5 fc 11 84 24 c0 07 	vmovups %ymm0,0x7c0(%rsp)
 12102aa:	00 00 
 12102ac:	c5 fc 11 84 24 a0 07 	vmovups %ymm0,0x7a0(%rsp)
 12102b3:	00 00 
 12102b5:	c6 84 24 20 09 00 00 	movb   $0x38,0x920(%rsp)
 12102bc:	38 
 12102bd:	c6 84 24 28 09 00 00 	movb   $0x0,0x928(%rsp)
 12102c4:	00 
 12102c5:	0f b7 05 7c ac e2 ff 	movzwl -0x1d5384(%rip),%eax        # 103af48 <__anon_35281>
 12102cc:	66 89 84 24 22 09 00 	mov    %ax,0x922(%rsp)
 12102d3:	00 
 12102d4:	0f b6 44 24 1f       	movzbl 0x1f(%rsp),%eax
 12102d9:	24 1f                	and    $0x1f,%al
 12102db:	88 44 24 1f          	mov    %al,0x1f(%rsp)
 12102df:	88 84 24 21 09 00 00 	mov    %al,0x921(%rsp)
 12102e6:	48 8b 84 24 f0 00 00 	mov    0xf0(%rsp),%rax
 12102ed:	00 
 12102ee:	48 89 84 24 08 07 00 	mov    %rax,0x708(%rsp)
 12102f5:	00 
 12102f6:	48 8b 84 24 e8 00 00 	mov    0xe8(%rsp),%rax
 12102fd:	00 
 12102fe:	48 89 84 24 10 07 00 	mov    %rax,0x710(%rsp)
 1210305:	00 
 1210306:	c7 84 24 24 09 00 00 	movl   $0x1000101,0x924(%rsp)
 121030d:	01 01 00 01 
 1210311:	48 8b 84 24 e0 00 00 	mov    0xe0(%rsp),%rax
 1210318:	00 
 1210319:	48 89 84 24 18 09 00 	mov    %rax,0x918(%rsp)
 1210320:	00 
 1210321:	48 8b 84 24 d8 00 00 	mov    0xd8(%rsp),%rax
 1210328:	00 
 1210329:	48 89 84 24 10 09 00 	mov    %rax,0x910(%rsp)
 1210330:	00 
 1210331:	66 c7 84 24 2a 09 00 	movw   $0x0,0x92a(%rsp)
 1210338:	00 00 00 
 121033b:	48 c7 84 24 20 07 00 	movq   $0x0,0x720(%rsp)
 1210342:	00 00 00 00 00 
 1210347:	48 8b 45 10          	mov    0x10(%rbp),%rax
 121034b:	c5 fc 10 40 70       	vmovups 0x70(%rax),%ymm0
 1210350:	c5 fc 11 84 24 80 04 	vmovups %ymm0,0x480(%rsp)
 1210357:	00 00 
 1210359:	c5 fc 10 00          	vmovups (%rax),%ymm0
 121035d:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 1210362:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 1210367:	c5 fc 10 58 60       	vmovups 0x60(%rax),%ymm3
 121036c:	c5 fc 11 9c 24 70 04 	vmovups %ymm3,0x470(%rsp)
 1210373:	00 00 
 1210375:	c5 fc 11 94 24 50 04 	vmovups %ymm2,0x450(%rsp)
 121037c:	00 00 
 121037e:	c5 fc 11 8c 24 30 04 	vmovups %ymm1,0x430(%rsp)
 1210385:	00 00 
 1210387:	c5 fc 11 84 24 10 04 	vmovups %ymm0,0x410(%rsp)
 121038e:	00 00 
 1210390:	c5 fc 10 00          	vmovups (%rax),%ymm0
 1210394:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 1210399:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 121039e:	c5 fc 10 58 60       	vmovups 0x60(%rax),%ymm3
 12103a3:	c5 fc 11 84 24 50 05 	vmovups %ymm0,0x550(%rsp)
 12103aa:	00 00 
 12103ac:	c5 fc 11 8c 24 70 05 	vmovups %ymm1,0x570(%rsp)
 12103b3:	00 00 
 12103b5:	c5 fc 11 94 24 90 05 	vmovups %ymm2,0x590(%rsp)
 12103bc:	00 00 
 12103be:	c5 fc 11 9c 24 b0 05 	vmovups %ymm3,0x5b0(%rsp)
 12103c5:	00 00 
 12103c7:	c5 fe 6f 40 70       	vmovdqu 0x70(%rax),%ymm0
 12103cc:	c5 fe 7f 84 24 c0 05 	vmovdqu %ymm0,0x5c0(%rsp)
 12103d3:	00 00 
 12103d5:	48 8d 84 24 08 07 00 	lea    0x708(%rsp),%rax
 12103dc:	00 
 12103dd:	4c 8d 94 24 50 05 00 	lea    0x550(%rsp),%r10
 12103e4:	00 
 12103e5:	48 8d bc 24 a8 03 00 	lea    0x3a8(%rsp),%rdi
 12103ec:	00 
 12103ed:	48 8b 74 24 48       	mov    0x48(%rsp),%rsi
 12103f2:	48 8b 94 24 c8 00 00 	mov    0xc8(%rsp),%rdx
 12103f9:	00 
 12103fa:	48 8b 8c 24 a8 00 00 	mov    0xa8(%rsp),%rcx
 1210401:	00 
 1210402:	4c 8b 84 24 b0 00 00 	mov    0xb0(%rsp),%r8
 1210409:	00 
 121040a:	4c 8b 8c 24 d0 00 00 	mov    0xd0(%rsp),%r9
 1210411:	00 
 1210412:	50                   	push   %rax
 1210413:	41 52                	push   %r10
 1210415:	c5 f8 77             	vzeroupper 
 1210418:	e8 e3 45 f6 ff       	call   1174a00 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307>
 121041d:	48 83 c4 10          	add    $0x10,%rsp
 1210421:	0f b7 84 24 b8 03 00 	movzwl 0x3b8(%rsp),%eax
 1210428:	00 
 1210429:	66 85 c0             	test   %ax,%ax
 121042c:	0f 85 87 12 00 00    	jne    12116b9 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x18a9>
 1210432:	48 8b 84 24 a8 03 00 	mov    0x3a8(%rsp),%rax
 1210439:	00 
 121043a:	48 89 44 24 60       	mov    %rax,0x60(%rsp)
 121043f:	48 8b 84 24 b0 03 00 	mov    0x3b0(%rsp),%rax
 1210446:	00 
 1210447:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 121044c:	c5 fc 10 84 24 50 05 	vmovups 0x550(%rsp),%ymm0
 1210453:	00 00 
 1210455:	c5 fc 10 8c 24 70 05 	vmovups 0x570(%rsp),%ymm1
 121045c:	00 00 
 121045e:	c5 fc 10 94 24 90 05 	vmovups 0x590(%rsp),%ymm2
 1210465:	00 00 
 1210467:	c5 fc 10 9c 24 b0 05 	vmovups 0x5b0(%rsp),%ymm3
 121046e:	00 00 
 1210470:	c5 fc 11 84 24 20 02 	vmovups %ymm0,0x220(%rsp)
 1210477:	00 00 
 1210479:	c5 fc 11 8c 24 40 02 	vmovups %ymm1,0x240(%rsp)
 1210480:	00 00 
 1210482:	c5 fc 11 94 24 60 02 	vmovups %ymm2,0x260(%rsp)
 1210489:	00 00 
 121048b:	c5 fc 11 9c 24 80 02 	vmovups %ymm3,0x280(%rsp)
 1210492:	00 00 
 1210494:	c5 fe 6f 84 24 c0 05 	vmovdqu 0x5c0(%rsp),%ymm0
 121049b:	00 00 
 121049d:	c5 fe 7f 84 24 90 02 	vmovdqu %ymm0,0x290(%rsp)
 12104a4:	00 00 
 12104a6:	49 8b 07             	mov    (%r15),%rax
 12104a9:	48 89 44 24 68       	mov    %rax,0x68(%rsp)
 12104ae:	41 0f b6 47 08       	movzbl 0x8(%r15),%eax
 12104b3:	88 44 24 28          	mov    %al,0x28(%rsp)
 12104b7:	41 0f b6 47 09       	movzbl 0x9(%r15),%eax
 12104bc:	88 44 24 1e          	mov    %al,0x1e(%rsp)
 12104c0:	c4 c1 7e 6f 6d 01    	vmovdqu 0x1(%r13),%ymm5
 12104c6:	c4 c1 7e 6f 65 21    	vmovdqu 0x21(%r13),%ymm4
 12104cc:	41 0f b7 45 45       	movzwl 0x45(%r13),%eax
 12104d1:	66 89 44 24 34       	mov    %ax,0x34(%rsp)
 12104d6:	41 8b 45 41          	mov    0x41(%r13),%eax
 12104da:	89 44 24 30          	mov    %eax,0x30(%rsp)
 12104de:	45 0f b6 5f 50       	movzbl 0x50(%r15),%r11d
 12104e3:	41 8b 04 24          	mov    (%r12),%eax
 12104e7:	41 8b 4c 24 03       	mov    0x3(%r12),%ecx
 12104ec:	89 84 24 80 00 00 00 	mov    %eax,0x80(%rsp)
 12104f3:	89 8c 24 83 00 00 00 	mov    %ecx,0x83(%rsp)
 12104fa:	45 84 db             	test   %r11b,%r11b
 12104fd:	c5 fd 7f a4 24 00 01 	vmovdqa %ymm4,0x100(%rsp)
 1210504:	00 00 
 1210506:	c5 fd 7f ac 24 40 01 	vmovdqa %ymm5,0x140(%rsp)
 121050d:	00 00 
 121050f:	74 30                	je     1210541 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x731>
 1210511:	4c 8d b4 24 fe 00 00 	lea    0xfe(%rsp),%r14
 1210518:	00 
 1210519:	4c 89 f7             	mov    %r14,%rdi
 121051c:	4c 89 fe             	mov    %r15,%rsi
 121051f:	45 89 df             	mov    %r11d,%r15d
 1210522:	c5 f8 77             	vzeroupper 
 1210525:	e8 16 12 00 00       	call   1211740 <br.encoder.literal_context_split.Candidate.suffixCutoff>
 121052a:	c5 fd 6f ac 24 40 01 	vmovdqa 0x140(%rsp),%ymm5
 1210531:	00 00 
 1210533:	c5 fd 6f a4 24 00 01 	vmovdqa 0x100(%rsp),%ymm4
 121053a:	00 00 
 121053c:	45 89 fb             	mov    %r15d,%r11d
 121053f:	eb 07                	jmp    1210548 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x738>
 1210541:	4c 8d 35 18 ee e2 ff 	lea    -0x1d11e8(%rip),%r14        # 103f360 <__anon_46045>
 1210548:	45 0f b7 3e          	movzwl (%r14),%r15d
 121054c:	0f b6 84 24 80 01 00 	movzbl 0x180(%rsp),%eax
 1210553:	00 
 1210554:	20 d8                	and    %bl,%al
 1210556:	a8 01                	test   $0x1,%al
 1210558:	66 44 89 7c 24 2e    	mov    %r15w,0x2e(%rsp)
 121055e:	0f 84 ac 00 00 00    	je     1210610 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x800>
 1210564:	45 89 dd             	mov    %r11d,%r13d
 1210567:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 121056c:	48 8b 30             	mov    (%rax),%rsi
 121056f:	48 8b 50 08          	mov    0x8(%rax),%rdx
 1210573:	48 83 ec 08          	sub    $0x8,%rsp
 1210577:	48 8d bc 24 98 0f 00 	lea    0xf98(%rsp),%rdi
 121057e:	00 
 121057f:	48 8b 8c 24 d0 00 00 	mov    0xd0(%rsp),%rcx
 1210586:	00 
 1210587:	4c 8b 84 24 b0 00 00 	mov    0xb0(%rsp),%r8
 121058e:	00 
 121058f:	4c 8b 8c 24 b8 00 00 	mov    0xb8(%rsp),%r9
 1210596:	00 
 1210597:	ff b4 24 d8 00 00 00 	push   0xd8(%rsp)
 121059e:	c5 f8 77             	vzeroupper 
 12105a1:	e8 aa e8 ff ff       	call   120ee50 <br.encoder.literal_context_split.chooseProposals>
 12105a6:	48 83 c4 10          	add    $0x10,%rsp
 12105aa:	44 0f b7 b4 24 98 10 	movzwl 0x1098(%rsp),%r14d
 12105b1:	00 00 
 12105b3:	66 45 85 f6          	test   %r14w,%r14w
 12105b7:	0f 85 0d 11 00 00    	jne    12116ca <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x18ba>
 12105bd:	4c 8d a4 24 e0 0e 00 	lea    0xee0(%rsp),%r12
 12105c4:	00 
 12105c5:	4c 8d bc 24 38 0f 00 	lea    0xf38(%rsp),%r15
 12105cc:	00 
 12105cd:	4c 8d b4 24 88 0e 00 	lea    0xe88(%rsp),%r14
 12105d4:	00 
 12105d5:	48 8d b4 24 90 0f 00 	lea    0xf90(%rsp),%rsi
 12105dc:	00 
 12105dd:	ba 08 01 00 00       	mov    $0x108,%edx
 12105e2:	4c 89 f7             	mov    %r14,%rdi
 12105e5:	e8 76 5c 08 00       	call   1296260 <compiler_rt.memcpy.memcpyFast>
 12105ea:	45 89 eb             	mov    %r13d,%r11d
 12105ed:	c5 fd 6f a4 24 00 01 	vmovdqa 0x100(%rsp),%ymm4
 12105f4:	00 00 
 12105f6:	c5 fd 6f ac 24 40 01 	vmovdqa 0x140(%rsp),%ymm5
 12105fd:	00 00 
 12105ff:	f6 c3 01             	test   $0x1,%bl
 1210602:	75 26                	jne    121062a <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x81a>
 1210604:	48 8d 0d 5d ed e2 ff 	lea    -0x1d12a3(%rip),%rcx        # 103f368 <__anon_46329>
 121060b:	e9 a9 00 00 00       	jmp    12106b9 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x8a9>
 1210610:	4c 8d 35 41 ec e2 ff 	lea    -0x1d13bf(%rip),%r14        # 103f258 <__anon_46105>
 1210617:	4c 8d 3d ea ec e2 ff 	lea    -0x1d1316(%rip),%r15        # 103f308 <__anon_46105+0xb0>
 121061e:	4c 8d 25 8b ec e2 ff 	lea    -0x1d1375(%rip),%r12        # 103f2b0 <__anon_46105+0x58>
 1210625:	f6 c3 01             	test   $0x1,%bl
 1210628:	74 da                	je     1210604 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x7f4>
 121062a:	c4 c1 7c 10 06       	vmovups (%r14),%ymm0
 121062f:	c4 c1 7c 10 4e 38    	vmovups 0x38(%r14),%ymm1
 1210635:	c5 fc 11 8c 24 b8 0d 	vmovups %ymm1,0xdb8(%rsp)
 121063c:	00 00 
 121063e:	c4 c1 7c 10 4e 20    	vmovups 0x20(%r14),%ymm1
 1210644:	c5 fc 11 8c 24 a0 0d 	vmovups %ymm1,0xda0(%rsp)
 121064b:	00 00 
 121064d:	c5 fc 11 84 24 80 0d 	vmovups %ymm0,0xd80(%rsp)
 1210654:	00 00 
 1210656:	c4 c1 7c 10 04 24    	vmovups (%r12),%ymm0
 121065c:	c4 c1 7c 10 4c 24 20 	vmovups 0x20(%r12),%ymm1
 1210663:	c4 c1 7c 10 54 24 38 	vmovups 0x38(%r12),%ymm2
 121066a:	c5 fc 11 84 24 d8 0d 	vmovups %ymm0,0xdd8(%rsp)
 1210671:	00 00 
 1210673:	c5 fc 11 8c 24 f8 0d 	vmovups %ymm1,0xdf8(%rsp)
 121067a:	00 00 
 121067c:	c5 fc 11 94 24 10 0e 	vmovups %ymm2,0xe10(%rsp)
 1210683:	00 00 
 1210685:	c4 c1 7c 10 07       	vmovups (%r15),%ymm0
 121068a:	c4 c1 7c 10 4f 20    	vmovups 0x20(%r15),%ymm1
 1210690:	c5 fc 11 84 24 30 0e 	vmovups %ymm0,0xe30(%rsp)
 1210697:	00 00 
 1210699:	c4 c1 7e 6f 47 38    	vmovdqu 0x38(%r15),%ymm0
 121069f:	c5 fc 11 8c 24 50 0e 	vmovups %ymm1,0xe50(%rsp)
 12106a6:	00 00 
 12106a8:	c5 fe 7f 84 24 68 0e 	vmovdqu %ymm0,0xe68(%rsp)
 12106af:	00 00 
 12106b1:	48 8d 8c 24 80 0d 00 	lea    0xd80(%rsp),%rcx
 12106b8:	00 
 12106b9:	4c 8b 54 24 60       	mov    0x60(%rsp),%r10
 12106be:	45 31 ed             	xor    %r13d,%r13d
 12106c1:	48 c7 84 24 c0 00 00 	movq   $0x0,0xc0(%rsp)
 12106c8:	00 00 00 00 00 
 12106cd:	45 31 ff             	xor    %r15d,%r15d
 12106d0:	48 89 8c 24 88 00 00 	mov    %rcx,0x88(%rsp)
 12106d7:	00 
 12106d8:	eb 2c                	jmp    1210706 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x8f6>
 12106da:	48 8b 8c 24 88 00 00 	mov    0x88(%rsp),%rcx
 12106e1:	00 
 12106e2:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 12106e9:	1f 84 00 00 00 00 00 
 12106f0:	4d 85 ed             	test   %r13,%r13
 12106f3:	0f 84 b7 06 00 00    	je     1210db0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xfa0>
 12106f9:	49 ff c5             	inc    %r13
 12106fc:	49 83 fd 03          	cmp    $0x3,%r13
 1210700:	0f 84 8d 08 00 00    	je     1210f93 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1183>
 1210706:	49 6b c5 58          	imul   $0x58,%r13,%rax
 121070a:	80 7c 01 50 00       	cmpb   $0x0,0x50(%rcx,%rax,1)
 121070f:	74 df                	je     12106f0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x8e0>
 1210711:	4c 8b 04 01          	mov    (%rcx,%rax,1),%r8
 1210715:	44 0f b6 74 01 08    	movzbl 0x8(%rcx,%rax,1),%r14d
 121071b:	44 0f b6 64 01 09    	movzbl 0x9(%rcx,%rax,1),%r12d
 1210721:	c5 fe 6f 74 01 0a    	vmovdqu 0xa(%rcx,%rax,1),%ymm6
 1210727:	c5 fe 6f 7c 01 2a    	vmovdqu 0x2a(%rcx,%rax,1),%ymm7
 121072d:	48 8d 44 01 4a       	lea    0x4a(%rcx,%rax,1),%rax
 1210732:	0f b7 48 04          	movzwl 0x4(%rax),%ecx
 1210736:	66 89 4c 24 74       	mov    %cx,0x74(%rsp)
 121073b:	8b 08                	mov    (%rax),%ecx
 121073d:	89 4c 24 70          	mov    %ecx,0x70(%rsp)
 1210741:	45 84 db             	test   %r11b,%r11b
 1210744:	74 5a                	je     12107a0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x990>
 1210746:	44 89 f2             	mov    %r14d,%edx
 1210749:	80 e2 03             	and    $0x3,%dl
 121074c:	0f b6 74 24 28       	movzbl 0x28(%rsp),%esi
 1210751:	40 80 e6 03          	and    $0x3,%sil
 1210755:	31 c9                	xor    %ecx,%ecx
 1210757:	40 38 f2             	cmp    %sil,%dl
 121075a:	75 2e                	jne    121078a <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x97a>
 121075c:	0f b6 54 24 1e       	movzbl 0x1e(%rsp),%edx
 1210761:	80 e2 7f             	and    $0x7f,%dl
 1210764:	44 89 e6             	mov    %r12d,%esi
 1210767:	40 80 e6 7f          	and    $0x7f,%sil
 121076b:	40 38 d6             	cmp    %dl,%sil
 121076e:	75 1a                	jne    121078a <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x97a>
 1210770:	c5 cd 74 c5          	vpcmpeqb %ymm5,%ymm6,%ymm0
 1210774:	c5 fd d7 d0          	vpmovmskb %ymm0,%edx
 1210778:	f7 d2                	not    %edx
 121077a:	85 d2                	test   %edx,%edx
 121077c:	75 0c                	jne    121078a <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x97a>
 121077e:	c5 c5 ef c4          	vpxor  %ymm4,%ymm7,%ymm0
 1210782:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 1210787:	0f 94 c1             	sete   %cl
 121078a:	4d 85 ff             	test   %r15,%r15
 121078d:	44 89 9c 24 90 00 00 	mov    %r11d,0x90(%rsp)
 1210794:	00 
 1210795:	75 18                	jne    12107af <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x99f>
 1210797:	eb 3c                	jmp    12107d5 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x9c5>
 1210799:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)
 12107a0:	31 c9                	xor    %ecx,%ecx
 12107a2:	4d 85 ff             	test   %r15,%r15
 12107a5:	44 89 9c 24 90 00 00 	mov    %r11d,0x90(%rsp)
 12107ac:	00 
 12107ad:	74 26                	je     12107d5 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x9c5>
 12107af:	4d 89 d3             	mov    %r10,%r11
 12107b2:	4c 89 c3             	mov    %r8,%rbx
 12107b5:	49 83 ff 01          	cmp    $0x1,%r15
 12107b9:	75 39                	jne    12107f4 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x9e4>
 12107bb:	31 d2                	xor    %edx,%edx
 12107bd:	41 f6 c7 01          	test   $0x1,%r15b
 12107c1:	49 89 d8             	mov    %rbx,%r8
 12107c4:	4d 89 da             	mov    %r11,%r10
 12107c7:	44 8b 9c 24 90 00 00 	mov    0x90(%rsp),%r11d
 12107ce:	00 
 12107cf:	0f 85 00 01 00 00    	jne    12108d5 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xac5>
 12107d5:	f6 c1 01             	test   $0x1,%cl
 12107d8:	0f 84 72 01 00 00    	je     1210950 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xb40>
 12107de:	48 8b 8c 24 88 00 00 	mov    0x88(%rsp),%rcx
 12107e5:	00 
 12107e6:	4d 85 ed             	test   %r13,%r13
 12107e9:	0f 85 0a ff ff ff    	jne    12106f9 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x8e9>
 12107ef:	e9 bc 05 00 00       	jmp    1210db0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xfa0>
 12107f4:	4c 89 fe             	mov    %r15,%rsi
 12107f7:	48 83 e6 fe          	and    $0xfffffffffffffffe,%rsi
 12107fb:	48 8d bc 24 c0 02 00 	lea    0x2c0(%rsp),%rdi
 1210802:	00 
 1210803:	31 d2                	xor    %edx,%edx
 1210805:	eb 19                	jmp    1210820 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xa10>
 1210807:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 121080e:	00 00 
 1210810:	48 83 c2 02          	add    $0x2,%rdx
 1210814:	48 81 c7 a0 00 00 00 	add    $0xa0,%rdi
 121081b:	48 39 d6             	cmp    %rdx,%rsi
 121081e:	74 9d                	je     12107bd <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x9ad>
 1210820:	41 b0 01             	mov    $0x1,%r8b
 1210823:	f6 c1 01             	test   $0x1,%cl
 1210826:	b1 01                	mov    $0x1,%cl
 1210828:	75 4b                	jne    1210875 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xa65>
 121082a:	45 89 f1             	mov    %r14d,%r9d
 121082d:	41 80 e1 03          	and    $0x3,%r9b
 1210831:	44 0f b6 17          	movzbl (%rdi),%r10d
 1210835:	41 80 e2 03          	and    $0x3,%r10b
 1210839:	45 31 c0             	xor    %r8d,%r8d
 121083c:	45 38 d1             	cmp    %r10b,%r9b
 121083f:	75 34                	jne    1210875 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xa65>
 1210841:	44 0f b6 4f 01       	movzbl 0x1(%rdi),%r9d
 1210846:	41 80 e1 7f          	and    $0x7f,%r9b
 121084a:	45 89 e2             	mov    %r12d,%r10d
 121084d:	41 80 e2 7f          	and    $0x7f,%r10b
 1210851:	45 38 ca             	cmp    %r9b,%r10b
 1210854:	75 1f                	jne    1210875 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xa65>
 1210856:	c5 cd 74 47 02       	vpcmpeqb 0x2(%rdi),%ymm6,%ymm0
 121085b:	c5 7d d7 c8          	vpmovmskb %ymm0,%r9d
 121085f:	41 f7 d1             	not    %r9d
 1210862:	45 85 c9             	test   %r9d,%r9d
 1210865:	75 0e                	jne    1210875 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xa65>
 1210867:	c5 c5 ef 47 22       	vpxor  0x22(%rdi),%ymm7,%ymm0
 121086c:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 1210871:	41 0f 94 c0          	sete   %r8b
 1210875:	45 84 c0             	test   %r8b,%r8b
 1210878:	75 96                	jne    1210810 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xa00>
 121087a:	45 89 f0             	mov    %r14d,%r8d
 121087d:	41 80 e0 03          	and    $0x3,%r8b
 1210881:	44 0f b6 4f 50       	movzbl 0x50(%rdi),%r9d
 1210886:	41 80 e1 03          	and    $0x3,%r9b
 121088a:	31 c9                	xor    %ecx,%ecx
 121088c:	45 38 c8             	cmp    %r9b,%r8b
 121088f:	0f 85 7b ff ff ff    	jne    1210810 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xa00>
 1210895:	44 0f b6 47 51       	movzbl 0x51(%rdi),%r8d
 121089a:	41 80 e0 7f          	and    $0x7f,%r8b
 121089e:	45 89 e1             	mov    %r12d,%r9d
 12108a1:	41 80 e1 7f          	and    $0x7f,%r9b
 12108a5:	45 38 c1             	cmp    %r8b,%r9b
 12108a8:	0f 85 62 ff ff ff    	jne    1210810 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xa00>
 12108ae:	c5 cd 74 47 52       	vpcmpeqb 0x52(%rdi),%ymm6,%ymm0
 12108b3:	c5 7d d7 c0          	vpmovmskb %ymm0,%r8d
 12108b7:	41 f7 d0             	not    %r8d
 12108ba:	45 85 c0             	test   %r8d,%r8d
 12108bd:	0f 85 4d ff ff ff    	jne    1210810 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xa00>
 12108c3:	c5 c5 ef 47 72       	vpxor  0x72(%rdi),%ymm7,%ymm0
 12108c8:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 12108cd:	0f 94 c1             	sete   %cl
 12108d0:	e9 3b ff ff ff       	jmp    1210810 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xa00>
 12108d5:	84 c9                	test   %cl,%cl
 12108d7:	0f 85 fd fd ff ff    	jne    12106da <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x8ca>
 12108dd:	48 8d 0c 92          	lea    (%rdx,%rdx,4),%rcx
 12108e1:	48 c1 e1 04          	shl    $0x4,%rcx
 12108e5:	48 8d 14 0c          	lea    (%rsp,%rcx,1),%rdx
 12108e9:	48 81 c2 b8 02 00 00 	add    $0x2b8,%rdx
 12108f0:	44 89 f6             	mov    %r14d,%esi
 12108f3:	40 80 e6 03          	and    $0x3,%sil
 12108f7:	0f b6 7a 08          	movzbl 0x8(%rdx),%edi
 12108fb:	40 80 e7 03          	and    $0x3,%dil
 12108ff:	40 38 fe             	cmp    %dil,%sil
 1210902:	75 4c                	jne    1210950 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xb40>
 1210904:	0f b6 72 09          	movzbl 0x9(%rdx),%esi
 1210908:	40 80 e6 7f          	and    $0x7f,%sil
 121090c:	44 89 e7             	mov    %r12d,%edi
 121090f:	40 80 e7 7f          	and    $0x7f,%dil
 1210913:	40 38 f7             	cmp    %sil,%dil
 1210916:	75 38                	jne    1210950 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xb40>
 1210918:	c5 cd 74 42 0a       	vpcmpeqb 0xa(%rdx),%ymm6,%ymm0
 121091d:	c5 fd d7 d0          	vpmovmskb %ymm0,%edx
 1210921:	f7 d2                	not    %edx
 1210923:	85 d2                	test   %edx,%edx
 1210925:	75 29                	jne    1210950 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xb40>
 1210927:	c5 c5 ef 84 0c e2 02 	vpxor  0x2e2(%rsp,%rcx,1),%ymm7,%ymm0
 121092e:	00 00 
 1210930:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 1210935:	0f 94 c1             	sete   %cl
 1210938:	f6 c1 01             	test   $0x1,%cl
 121093b:	0f 85 9d fe ff ff    	jne    12107de <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x9ce>
 1210941:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1210948:	0f 1f 84 00 00 00 00 
 121094f:	00 
 1210950:	c5 fd 7f ac 24 40 01 	vmovdqa %ymm5,0x140(%rsp)
 1210957:	00 00 
 1210959:	c5 fd 7f a4 24 00 01 	vmovdqa %ymm4,0x100(%rsp)
 1210960:	00 00 
 1210962:	4c 89 54 24 60       	mov    %r10,0x60(%rsp)
 1210967:	4c 89 7c 24 78       	mov    %r15,0x78(%rsp)
 121096c:	c5 fc 10 84 24 80 04 	vmovups 0x480(%rsp),%ymm0
 1210973:	00 00 
 1210975:	c5 fc 11 84 24 50 06 	vmovups %ymm0,0x650(%rsp)
 121097c:	00 00 
 121097e:	c5 fc 10 84 24 10 04 	vmovups 0x410(%rsp),%ymm0
 1210985:	00 00 
 1210987:	c5 fc 10 8c 24 30 04 	vmovups 0x430(%rsp),%ymm1
 121098e:	00 00 
 1210990:	c5 fc 10 94 24 50 04 	vmovups 0x450(%rsp),%ymm2
 1210997:	00 00 
 1210999:	c5 fc 10 9c 24 70 04 	vmovups 0x470(%rsp),%ymm3
 12109a0:	00 00 
 12109a2:	c5 fc 11 9c 24 40 06 	vmovups %ymm3,0x640(%rsp)
 12109a9:	00 00 
 12109ab:	c5 fc 11 94 24 20 06 	vmovups %ymm2,0x620(%rsp)
 12109b2:	00 00 
 12109b4:	c5 fc 11 8c 24 00 06 	vmovups %ymm1,0x600(%rsp)
 12109bb:	00 00 
 12109bd:	c5 fc 11 84 24 e0 05 	vmovups %ymm0,0x5e0(%rsp)
 12109c4:	00 00 
 12109c6:	0f b6 4c 24 20       	movzbl 0x20(%rsp),%ecx
 12109cb:	c5 fe 6f 84 24 f0 03 	vmovdqu 0x3f0(%rsp),%ymm0
 12109d2:	00 00 
 12109d4:	48 8d b4 24 e2 0b 00 	lea    0xbe2(%rsp),%rsi
 12109db:	00 
 12109dc:	c5 fe 7f 46 96       	vmovdqu %ymm0,-0x6a(%rsi)
 12109e1:	0f b7 50 04          	movzwl 0x4(%rax),%edx
 12109e5:	66 89 56 04          	mov    %dx,0x4(%rsi)
 12109e9:	8b 00                	mov    (%rax),%eax
 12109eb:	89 06                	mov    %eax,(%rsi)
 12109ed:	88 8c 24 79 0d 00 00 	mov    %cl,0xd79(%rsp)
 12109f4:	48 c7 84 24 68 0b 00 	movq   $0x0,0xb68(%rsp)
 12109fb:	00 00 00 00 00 
 1210a00:	8b 44 24 40          	mov    0x40(%rsp),%eax
 1210a04:	88 84 24 7d 0d 00 00 	mov    %al,0xd7d(%rsp)
 1210a0b:	c6 84 24 7c 0d 00 00 	movb   $0x0,0xd7c(%rsp)
 1210a12:	00 
 1210a13:	4c 89 c3             	mov    %r8,%rbx
 1210a16:	4c 89 84 24 98 0b 00 	mov    %r8,0xb98(%rsp)
 1210a1d:	00 
 1210a1e:	44 88 b4 24 a0 0b 00 	mov    %r14b,0xba0(%rsp)
 1210a25:	00 
 1210a26:	44 88 a4 24 a1 0b 00 	mov    %r12b,0xba1(%rsp)
 1210a2d:	00 
 1210a2e:	c5 fd 7f b4 24 80 01 	vmovdqa %ymm6,0x180(%rsp)
 1210a35:	00 00 
 1210a37:	c5 fe 7f b4 24 a2 0b 	vmovdqu %ymm6,0xba2(%rsp)
 1210a3e:	00 00 
 1210a40:	c5 fd 7f bc 24 60 01 	vmovdqa %ymm7,0x160(%rsp)
 1210a47:	00 00 
 1210a49:	c5 fe 7f bc 24 c2 0b 	vmovdqu %ymm7,0xbc2(%rsp)
 1210a50:	00 00 
 1210a52:	c6 84 24 e8 0b 00 00 	movb   $0x1,0xbe8(%rsp)
 1210a59:	01 
 1210a5a:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 1210a5e:	c5 fe 7f 86 5e 01 00 	vmovdqu %ymm0,0x15e(%rsi)
 1210a65:	00 
 1210a66:	c5 fe 7f 86 4e 01 00 	vmovdqu %ymm0,0x14e(%rsi)
 1210a6d:	00 
 1210a6e:	c5 fe 7f 86 2e 01 00 	vmovdqu %ymm0,0x12e(%rsi)
 1210a75:	00 
 1210a76:	c5 fe 7f 86 0e 01 00 	vmovdqu %ymm0,0x10e(%rsi)
 1210a7d:	00 
 1210a7e:	c5 fe 7f 86 ee 00 00 	vmovdqu %ymm0,0xee(%rsi)
 1210a85:	00 
 1210a86:	c5 fe 7f 86 ce 00 00 	vmovdqu %ymm0,0xce(%rsi)
 1210a8d:	00 
 1210a8e:	c5 fe 7f 86 ae 00 00 	vmovdqu %ymm0,0xae(%rsi)
 1210a95:	00 
 1210a96:	c5 fe 7f 86 8e 00 00 	vmovdqu %ymm0,0x8e(%rsi)
 1210a9d:	00 
 1210a9e:	c5 fe 7f 46 6e       	vmovdqu %ymm0,0x6e(%rsi)
 1210aa3:	c5 fe 7f 46 4e       	vmovdqu %ymm0,0x4e(%rsi)
 1210aa8:	c5 fe 7f 46 2e       	vmovdqu %ymm0,0x2e(%rsi)
 1210aad:	c5 fe 7f 46 0e       	vmovdqu %ymm0,0xe(%rsi)
 1210ab2:	c6 84 24 70 0d 00 00 	movb   $0x38,0xd70(%rsp)
 1210ab9:	38 
 1210aba:	c6 84 24 78 0d 00 00 	movb   $0x0,0xd78(%rsp)
 1210ac1:	00 
 1210ac2:	0f b7 05 7f a4 e2 ff 	movzwl -0x1d5b81(%rip),%eax        # 103af48 <__anon_35281>
 1210ac9:	66 89 84 24 72 0d 00 	mov    %ax,0xd72(%rsp)
 1210ad0:	00 
 1210ad1:	0f b6 44 24 1f       	movzbl 0x1f(%rsp),%eax
 1210ad6:	88 84 24 71 0d 00 00 	mov    %al,0xd71(%rsp)
 1210add:	48 8b 84 24 f0 00 00 	mov    0xf0(%rsp),%rax
 1210ae4:	00 
 1210ae5:	48 89 84 24 58 0b 00 	mov    %rax,0xb58(%rsp)
 1210aec:	00 
 1210aed:	48 8b 84 24 e8 00 00 	mov    0xe8(%rsp),%rax
 1210af4:	00 
 1210af5:	48 89 84 24 60 0b 00 	mov    %rax,0xb60(%rsp)
 1210afc:	00 
 1210afd:	c7 84 24 74 0d 00 00 	movl   $0x1000101,0xd74(%rsp)
 1210b04:	01 01 00 01 
 1210b08:	48 8b 84 24 e0 00 00 	mov    0xe0(%rsp),%rax
 1210b0f:	00 
 1210b10:	48 89 84 24 68 0d 00 	mov    %rax,0xd68(%rsp)
 1210b17:	00 
 1210b18:	48 8b 84 24 d8 00 00 	mov    0xd8(%rsp),%rax
 1210b1f:	00 
 1210b20:	48 89 84 24 60 0d 00 	mov    %rax,0xd60(%rsp)
 1210b27:	00 
 1210b28:	66 c7 84 24 7a 0d 00 	movw   $0x0,0xd7a(%rsp)
 1210b2f:	00 00 00 
 1210b32:	48 c7 84 24 70 0b 00 	movq   $0x0,0xb70(%rsp)
 1210b39:	00 00 00 00 00 
 1210b3e:	48 8d bc 24 c0 03 00 	lea    0x3c0(%rsp),%rdi
 1210b45:	00 
 1210b46:	48 8b 74 24 48       	mov    0x48(%rsp),%rsi
 1210b4b:	48 8b 94 24 c8 00 00 	mov    0xc8(%rsp),%rdx
 1210b52:	00 
 1210b53:	48 8b 8c 24 a8 00 00 	mov    0xa8(%rsp),%rcx
 1210b5a:	00 
 1210b5b:	4c 8b 84 24 b0 00 00 	mov    0xb0(%rsp),%r8
 1210b62:	00 
 1210b63:	4c 8b 8c 24 d0 00 00 	mov    0xd0(%rsp),%r9
 1210b6a:	00 
 1210b6b:	48 8d 84 24 58 0b 00 	lea    0xb58(%rsp),%rax
 1210b72:	00 
 1210b73:	50                   	push   %rax
 1210b74:	48 8d 84 24 e8 05 00 	lea    0x5e8(%rsp),%rax
 1210b7b:	00 
 1210b7c:	50                   	push   %rax
 1210b7d:	c5 f8 77             	vzeroupper 
 1210b80:	e8 7b 3e f6 ff       	call   1174a00 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307>
 1210b85:	48 83 c4 10          	add    $0x10,%rsp
 1210b89:	44 0f b7 bc 24 d0 03 	movzwl 0x3d0(%rsp),%r15d
 1210b90:	00 00 
 1210b92:	66 45 85 ff          	test   %r15w,%r15w
 1210b96:	0f 85 e7 0a 00 00    	jne    1211683 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1873>
 1210b9c:	48 8b b4 24 c0 03 00 	mov    0x3c0(%rsp),%rsi
 1210ba3:	00 
 1210ba4:	4c 8b bc 24 c8 03 00 	mov    0x3c8(%rsp),%r15
 1210bab:	00 
 1210bac:	48 8b 54 24 38       	mov    0x38(%rsp),%rdx
 1210bb1:	49 39 d7             	cmp    %rdx,%r15
 1210bb4:	0f 83 2c 01 00 00    	jae    1210ce6 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xed6>
 1210bba:	48 89 b4 24 b8 00 00 	mov    %rsi,0xb8(%rsp)
 1210bc1:	00 
 1210bc2:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 1210bc7:	48 8b 38             	mov    (%rax),%rdi
 1210bca:	48 8b 40 08          	mov    0x8(%rax),%rax
 1210bce:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1210bd2:	48 8b 74 24 60       	mov    0x60(%rsp),%rsi
 1210bd7:	31 c9                	xor    %ecx,%ecx
 1210bd9:	4c 89 44 24 38       	mov    %r8,0x38(%rsp)
 1210bde:	ff 50 18             	call   *0x18(%rax)
 1210be1:	c5 fc 10 84 24 50 06 	vmovups 0x650(%rsp),%ymm0
 1210be8:	00 00 
 1210bea:	c5 fc 11 84 24 90 02 	vmovups %ymm0,0x290(%rsp)
 1210bf1:	00 00 
 1210bf3:	c5 fe 6f 84 24 e0 05 	vmovdqu 0x5e0(%rsp),%ymm0
 1210bfa:	00 00 
 1210bfc:	c5 fc 10 8c 24 00 06 	vmovups 0x600(%rsp),%ymm1
 1210c03:	00 00 
 1210c05:	c5 fc 10 94 24 20 06 	vmovups 0x620(%rsp),%ymm2
 1210c0c:	00 00 
 1210c0e:	c5 fc 10 9c 24 40 06 	vmovups 0x640(%rsp),%ymm3
 1210c15:	00 00 
 1210c17:	c5 fc 11 9c 24 80 02 	vmovups %ymm3,0x280(%rsp)
 1210c1e:	00 00 
 1210c20:	c5 fc 11 94 24 60 02 	vmovups %ymm2,0x260(%rsp)
 1210c27:	00 00 
 1210c29:	c5 fc 11 8c 24 40 02 	vmovups %ymm1,0x240(%rsp)
 1210c30:	00 00 
 1210c32:	c5 fe 7f 84 24 20 02 	vmovdqu %ymm0,0x220(%rsp)
 1210c39:	00 00 
 1210c3b:	80 bc 24 90 00 00 00 	cmpb   $0x0,0x90(%rsp)
 1210c42:	00 
 1210c43:	41 b3 01             	mov    $0x1,%r11b
 1210c46:	0f 84 8e 02 00 00    	je     1210eda <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x10ca>
 1210c4c:	48 8b 54 24 78       	mov    0x78(%rsp),%rdx
 1210c51:	48 83 fa 03          	cmp    $0x3,%rdx
 1210c55:	c5 fd 6f ac 24 80 01 	vmovdqa 0x180(%rsp),%ymm5
 1210c5c:	00 00 
 1210c5e:	c5 fd 6f a4 24 60 01 	vmovdqa 0x160(%rsp),%ymm4
 1210c65:	00 00 
 1210c67:	0f 83 50 09 00 00    	jae    12115bd <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17ad>
 1210c6d:	49 89 d8             	mov    %rbx,%r8
 1210c70:	48 8d 04 92          	lea    (%rdx,%rdx,4),%rax
 1210c74:	48 c1 e0 04          	shl    $0x4,%rax
 1210c78:	48 8b 4c 24 68       	mov    0x68(%rsp),%rcx
 1210c7d:	48 89 8c 04 b8 02 00 	mov    %rcx,0x2b8(%rsp,%rax,1)
 1210c84:	00 
 1210c85:	0f b6 4c 24 28       	movzbl 0x28(%rsp),%ecx
 1210c8a:	88 8c 04 c0 02 00 00 	mov    %cl,0x2c0(%rsp,%rax,1)
 1210c91:	0f b6 4c 24 1e       	movzbl 0x1e(%rsp),%ecx
 1210c96:	88 8c 04 c1 02 00 00 	mov    %cl,0x2c1(%rsp,%rax,1)
 1210c9d:	c5 fc 28 84 24 40 01 	vmovaps 0x140(%rsp),%ymm0
 1210ca4:	00 00 
 1210ca6:	c5 fc 11 84 04 c2 02 	vmovups %ymm0,0x2c2(%rsp,%rax,1)
 1210cad:	00 00 
 1210caf:	c5 fd 6f 84 24 00 01 	vmovdqa 0x100(%rsp),%ymm0
 1210cb6:	00 00 
 1210cb8:	c5 fe 7f 84 04 e2 02 	vmovdqu %ymm0,0x2e2(%rsp,%rax,1)
 1210cbf:	00 00 
 1210cc1:	8b 4c 24 30          	mov    0x30(%rsp),%ecx
 1210cc5:	89 8c 04 02 03 00 00 	mov    %ecx,0x302(%rsp,%rax,1)
 1210ccc:	0f b7 4c 24 34       	movzwl 0x34(%rsp),%ecx
 1210cd1:	66 89 8c 04 06 03 00 	mov    %cx,0x306(%rsp,%rax,1)
 1210cd8:	00 
 1210cd9:	48 ff c2             	inc    %rdx
 1210cdc:	48 89 54 24 78       	mov    %rdx,0x78(%rsp)
 1210ce1:	e9 13 02 00 00       	jmp    1210ef9 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x10e9>
 1210ce6:	4d 85 ff             	test   %r15,%r15
 1210ce9:	74 1d                	je     1210d08 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xef8>
 1210ceb:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 1210cf0:	48 8b 38             	mov    (%rax),%rdi
 1210cf3:	48 8b 40 08          	mov    0x8(%rax),%rax
 1210cf7:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1210cfb:	4c 89 fa             	mov    %r15,%rdx
 1210cfe:	31 c9                	xor    %ecx,%ecx
 1210d00:	ff 50 18             	call   *0x18(%rax)
 1210d03:	48 8b 54 24 38       	mov    0x38(%rsp),%rdx
 1210d08:	4c 8b 7c 24 78       	mov    0x78(%rsp),%r15
 1210d0d:	49 83 ff 02          	cmp    $0x2,%r15
 1210d11:	0f 87 88 08 00 00    	ja     121159f <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x178f>
 1210d17:	4b 8d 04 bf          	lea    (%r15,%r15,4),%rax
 1210d1b:	48 c1 e0 04          	shl    $0x4,%rax
 1210d1f:	48 89 9c 04 b8 02 00 	mov    %rbx,0x2b8(%rsp,%rax,1)
 1210d26:	00 
 1210d27:	44 88 b4 04 c0 02 00 	mov    %r14b,0x2c0(%rsp,%rax,1)
 1210d2e:	00 
 1210d2f:	44 88 a4 04 c1 02 00 	mov    %r12b,0x2c1(%rsp,%rax,1)
 1210d36:	00 
 1210d37:	c5 fc 28 84 24 80 01 	vmovaps 0x180(%rsp),%ymm0
 1210d3e:	00 00 
 1210d40:	c5 fc 11 84 04 c2 02 	vmovups %ymm0,0x2c2(%rsp,%rax,1)
 1210d47:	00 00 
 1210d49:	c5 fd 6f 84 24 60 01 	vmovdqa 0x160(%rsp),%ymm0
 1210d50:	00 00 
 1210d52:	c5 fe 7f 84 04 e2 02 	vmovdqu %ymm0,0x2e2(%rsp,%rax,1)
 1210d59:	00 00 
 1210d5b:	8b 4c 24 70          	mov    0x70(%rsp),%ecx
 1210d5f:	89 8c 04 02 03 00 00 	mov    %ecx,0x302(%rsp,%rax,1)
 1210d66:	0f b7 4c 24 74       	movzwl 0x74(%rsp),%ecx
 1210d6b:	66 89 8c 04 06 03 00 	mov    %cx,0x306(%rsp,%rax,1)
 1210d72:	00 
 1210d73:	49 ff c7             	inc    %r15
 1210d76:	44 8b 9c 24 90 00 00 	mov    0x90(%rsp),%r11d
 1210d7d:	00 
 1210d7e:	4c 8b 54 24 60       	mov    0x60(%rsp),%r10
 1210d83:	c5 fd 6f a4 24 00 01 	vmovdqa 0x100(%rsp),%ymm4
 1210d8a:	00 00 
 1210d8c:	c5 fd 6f ac 24 40 01 	vmovdqa 0x140(%rsp),%ymm5
 1210d93:	00 00 
 1210d95:	48 8b 8c 24 88 00 00 	mov    0x88(%rsp),%rcx
 1210d9c:	00 
 1210d9d:	4d 85 ed             	test   %r13,%r13
 1210da0:	0f 85 53 f9 ff ff    	jne    12106f9 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x8e9>
 1210da6:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 1210dad:	00 00 00 
 1210db0:	0f b7 44 24 34       	movzwl 0x34(%rsp),%eax
 1210db5:	66 89 84 24 a0 00 00 	mov    %ax,0xa0(%rsp)
 1210dbc:	00 
 1210dbd:	8b 44 24 30          	mov    0x30(%rsp),%eax
 1210dc1:	89 84 24 9c 00 00 00 	mov    %eax,0x9c(%rsp)
 1210dc8:	45 84 db             	test   %r11b,%r11b
 1210dcb:	0f 84 fa 00 00 00    	je     1210ecb <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x10bb>
 1210dd1:	4c 89 7c 24 78       	mov    %r15,0x78(%rsp)
 1210dd6:	44 0f b6 64 24 1e    	movzbl 0x1e(%rsp),%r12d
 1210ddc:	4c 8b 7c 24 38       	mov    0x38(%rsp),%r15
 1210de1:	4c 8b 44 24 68       	mov    0x68(%rsp),%r8
 1210de6:	44 0f b6 74 24 28    	movzbl 0x28(%rsp),%r14d
 1210dec:	44 89 f0             	mov    %r14d,%eax
 1210def:	24 03                	and    $0x3,%al
 1210df1:	3c 02                	cmp    $0x2,%al
 1210df3:	0f 85 6d 01 00 00    	jne    1210f66 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1156>
 1210df9:	4c 89 84 24 00 05 00 	mov    %r8,0x500(%rsp)
 1210e00:	00 
 1210e01:	44 88 b4 24 08 05 00 	mov    %r14b,0x508(%rsp)
 1210e08:	00 
 1210e09:	44 88 a4 24 09 05 00 	mov    %r12b,0x509(%rsp)
 1210e10:	00 
 1210e11:	c5 fe 7f ac 24 0a 05 	vmovdqu %ymm5,0x50a(%rsp)
 1210e18:	00 00 
 1210e1a:	c5 fe 7f a4 24 2a 05 	vmovdqu %ymm4,0x52a(%rsp)
 1210e21:	00 00 
 1210e23:	0f b7 84 24 a0 00 00 	movzwl 0xa0(%rsp),%eax
 1210e2a:	00 
 1210e2b:	48 8d 8c 24 4a 05 00 	lea    0x54a(%rsp),%rcx
 1210e32:	00 
 1210e33:	66 89 41 04          	mov    %ax,0x4(%rcx)
 1210e37:	8b 84 24 9c 00 00 00 	mov    0x9c(%rsp),%eax
 1210e3e:	89 01                	mov    %eax,(%rcx)
 1210e40:	48 8d bc 24 a6 00 00 	lea    0xa6(%rsp),%rdi
 1210e47:	00 
 1210e48:	4c 89 94 24 b8 00 00 	mov    %r10,0xb8(%rsp)
 1210e4f:	00 
 1210e50:	48 8d b4 24 00 05 00 	lea    0x500(%rsp),%rsi
 1210e57:	00 
 1210e58:	44 89 db             	mov    %r11d,%ebx
 1210e5b:	4c 89 84 24 90 00 00 	mov    %r8,0x90(%rsp)
 1210e62:	00 
 1210e63:	c5 fd 7f ac 24 80 01 	vmovdqa %ymm5,0x180(%rsp)
 1210e6a:	00 00 
 1210e6c:	c5 fd 7f a4 24 60 01 	vmovdqa %ymm4,0x160(%rsp)
 1210e73:	00 00 
 1210e75:	c5 f8 77             	vzeroupper 
 1210e78:	e8 c3 08 00 00       	call   1211740 <br.encoder.literal_context_split.Candidate.suffixCutoff>
 1210e7d:	48 8b 8c 24 88 00 00 	mov    0x88(%rsp),%rcx
 1210e84:	00 
 1210e85:	41 89 db             	mov    %ebx,%r11d
 1210e88:	44 88 64 24 1e       	mov    %r12b,0x1e(%rsp)
 1210e8d:	c5 fd 6f ac 24 80 01 	vmovdqa 0x180(%rsp),%ymm5
 1210e94:	00 00 
 1210e96:	c5 fd 6f a4 24 60 01 	vmovdqa 0x160(%rsp),%ymm4
 1210e9d:	00 00 
 1210e9f:	4c 8b 94 24 b8 00 00 	mov    0xb8(%rsp),%r10
 1210ea6:	00 
 1210ea7:	4c 89 7c 24 38       	mov    %r15,0x38(%rsp)
 1210eac:	48 8b 84 24 90 00 00 	mov    0x90(%rsp),%rax
 1210eb3:	00 
 1210eb4:	48 89 44 24 68       	mov    %rax,0x68(%rsp)
 1210eb9:	44 88 74 24 28       	mov    %r14b,0x28(%rsp)
 1210ebe:	48 8d 84 24 a6 00 00 	lea    0xa6(%rsp),%rax
 1210ec5:	00 
 1210ec6:	e9 b6 00 00 00       	jmp    1210f81 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1171>
 1210ecb:	45 31 db             	xor    %r11d,%r11d
 1210ece:	48 8d 05 8b e4 e2 ff 	lea    -0x1d1b75(%rip),%rax        # 103f360 <__anon_46045>
 1210ed5:	e9 ac 00 00 00       	jmp    1210f86 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1176>
 1210eda:	b0 01                	mov    $0x1,%al
 1210edc:	48 89 84 24 c0 00 00 	mov    %rax,0xc0(%rsp)
 1210ee3:	00 
 1210ee4:	49 89 d8             	mov    %rbx,%r8
 1210ee7:	c5 fd 6f ac 24 80 01 	vmovdqa 0x180(%rsp),%ymm5
 1210eee:	00 00 
 1210ef0:	c5 fd 6f a4 24 60 01 	vmovdqa 0x160(%rsp),%ymm4
 1210ef7:	00 00 
 1210ef9:	4c 8b 94 24 b8 00 00 	mov    0xb8(%rsp),%r10
 1210f00:	00 
 1210f01:	0f b7 44 24 74       	movzwl 0x74(%rsp),%eax
 1210f06:	66 89 44 24 34       	mov    %ax,0x34(%rsp)
 1210f0b:	8b 44 24 70          	mov    0x70(%rsp),%eax
 1210f0f:	89 44 24 30          	mov    %eax,0x30(%rsp)
 1210f13:	4d 85 ed             	test   %r13,%r13
 1210f16:	48 8b 8c 24 88 00 00 	mov    0x88(%rsp),%rcx
 1210f1d:	00 
 1210f1e:	74 1e                	je     1210f3e <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x112e>
 1210f20:	44 88 74 24 28       	mov    %r14b,0x28(%rsp)
 1210f25:	4c 89 44 24 68       	mov    %r8,0x68(%rsp)
 1210f2a:	4c 89 7c 24 38       	mov    %r15,0x38(%rsp)
 1210f2f:	44 88 64 24 1e       	mov    %r12b,0x1e(%rsp)
 1210f34:	4c 8b 7c 24 78       	mov    0x78(%rsp),%r15
 1210f39:	e9 bb f7 ff ff       	jmp    12106f9 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x8e9>
 1210f3e:	0f b7 44 24 74       	movzwl 0x74(%rsp),%eax
 1210f43:	66 89 84 24 a0 00 00 	mov    %ax,0xa0(%rsp)
 1210f4a:	00 
 1210f4b:	8b 44 24 70          	mov    0x70(%rsp),%eax
 1210f4f:	89 84 24 9c 00 00 00 	mov    %eax,0x9c(%rsp)
 1210f56:	41 b3 01             	mov    $0x1,%r11b
 1210f59:	44 89 f0             	mov    %r14d,%eax
 1210f5c:	24 03                	and    $0x3,%al
 1210f5e:	3c 02                	cmp    $0x2,%al
 1210f60:	0f 84 93 fe ff ff    	je     1210df9 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0xfe9>
 1210f66:	44 88 64 24 1e       	mov    %r12b,0x1e(%rsp)
 1210f6b:	4c 89 7c 24 38       	mov    %r15,0x38(%rsp)
 1210f70:	4c 89 44 24 68       	mov    %r8,0x68(%rsp)
 1210f75:	44 88 74 24 28       	mov    %r14b,0x28(%rsp)
 1210f7a:	48 8d 05 df e3 e2 ff 	lea    -0x1d1c21(%rip),%rax        # 103f360 <__anon_46045>
 1210f81:	4c 8b 7c 24 78       	mov    0x78(%rsp),%r15
 1210f86:	0f b7 00             	movzwl (%rax),%eax
 1210f89:	66 89 44 24 2e       	mov    %ax,0x2e(%rsp)
 1210f8e:	e9 66 f7 ff ff       	jmp    12106f9 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x8e9>
 1210f93:	8b 44 24 40          	mov    0x40(%rsp),%eax
 1210f97:	8b 8c 24 f8 00 00 00 	mov    0xf8(%rsp),%ecx
 1210f9e:	08 c8                	or     %cl,%al
 1210fa0:	0f 84 ef 03 00 00    	je     1211395 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1585>
 1210fa6:	84 c9                	test   %cl,%cl
 1210fa8:	4c 8b 8c 24 d0 00 00 	mov    0xd0(%rsp),%r9
 1210faf:	00 
 1210fb0:	0f b6 74 24 1f       	movzbl 0x1f(%rsp),%esi
 1210fb5:	75 36                	jne    1210fed <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x11dd>
 1210fb7:	b9 64 00 00 00       	mov    $0x64,%ecx
 1210fbc:	48 8b 44 24 38       	mov    0x38(%rsp),%rax
 1210fc1:	48 f7 e1             	mul    %rcx
 1210fc4:	70 27                	jo     1210fed <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x11dd>
 1210fc6:	c6 84 24 c0 01 00 00 	movb   $0x0,0x1c0(%rsp)
 1210fcd:	00 
 1210fce:	31 c9                	xor    %ecx,%ecx
 1210fd0:	84 c9                	test   %cl,%cl
 1210fd2:	75 19                	jne    1210fed <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x11dd>
 1210fd4:	48 8b 8c 24 a8 00 00 	mov    0xa8(%rsp),%rcx
 1210fdb:	00 
 1210fdc:	48 c1 e1 04          	shl    $0x4,%rcx
 1210fe0:	48 8d 0c 89          	lea    (%rcx,%rcx,4),%rcx
 1210fe4:	48 39 c8             	cmp    %rcx,%rax
 1210fe7:	0f 86 24 06 00 00    	jbe    1211611 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1801>
 1210fed:	c5 fd 7f ac 24 40 01 	vmovdqa %ymm5,0x140(%rsp)
 1210ff4:	00 00 
 1210ff6:	c5 fd 7f a4 24 00 01 	vmovdqa %ymm4,0x100(%rsp)
 1210ffd:	00 00 
 1210fff:	4d 89 d5             	mov    %r10,%r13
 1211002:	45 89 de             	mov    %r11d,%r14d
 1211005:	c5 fc 10 84 24 80 04 	vmovups 0x480(%rsp),%ymm0
 121100c:	00 00 
 121100e:	c5 fc 11 84 24 e0 06 	vmovups %ymm0,0x6e0(%rsp)
 1211015:	00 00 
 1211017:	c5 fc 10 84 24 10 04 	vmovups 0x410(%rsp),%ymm0
 121101e:	00 00 
 1211020:	c5 fc 10 8c 24 30 04 	vmovups 0x430(%rsp),%ymm1
 1211027:	00 00 
 1211029:	c5 fc 10 94 24 50 04 	vmovups 0x450(%rsp),%ymm2
 1211030:	00 00 
 1211032:	c5 fc 10 9c 24 70 04 	vmovups 0x470(%rsp),%ymm3
 1211039:	00 00 
 121103b:	c5 fc 11 9c 24 d0 06 	vmovups %ymm3,0x6d0(%rsp)
 1211042:	00 00 
 1211044:	c5 fc 11 94 24 b0 06 	vmovups %ymm2,0x6b0(%rsp)
 121104b:	00 00 
 121104d:	c5 fc 11 8c 24 90 06 	vmovups %ymm1,0x690(%rsp)
 1211054:	00 00 
 1211056:	c5 fc 11 84 24 70 06 	vmovups %ymm0,0x670(%rsp)
 121105d:	00 00 
 121105f:	0f b6 44 24 20       	movzbl 0x20(%rsp),%eax
 1211064:	c5 fe 6f 84 24 f0 03 	vmovdqu 0x3f0(%rsp),%ymm0
 121106b:	00 00 
 121106d:	c5 fe 7f 84 24 50 09 	vmovdqu %ymm0,0x950(%rsp)
 1211074:	00 00 
 1211076:	88 84 24 51 0b 00 00 	mov    %al,0xb51(%rsp)
 121107d:	48 c7 84 24 40 09 00 	movq   $0x0,0x940(%rsp)
 1211084:	00 00 00 00 00 
 1211089:	66 c7 84 24 54 0b 00 	movw   $0x0,0xb54(%rsp)
 1211090:	00 00 00 
 1211093:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 1211097:	c5 fe 7f 84 24 70 09 	vmovdqu %ymm0,0x970(%rsp)
 121109e:	00 00 
 12110a0:	c5 fe 7f 84 24 90 09 	vmovdqu %ymm0,0x990(%rsp)
 12110a7:	00 00 
 12110a9:	c5 fe 7f 84 24 b0 09 	vmovdqu %ymm0,0x9b0(%rsp)
 12110b0:	00 00 
 12110b2:	c5 fe 7f 84 24 d0 09 	vmovdqu %ymm0,0x9d0(%rsp)
 12110b9:	00 00 
 12110bb:	c5 fe 7f 84 24 f0 09 	vmovdqu %ymm0,0x9f0(%rsp)
 12110c2:	00 00 
 12110c4:	c5 fe 7f 84 24 10 0a 	vmovdqu %ymm0,0xa10(%rsp)
 12110cb:	00 00 
 12110cd:	c5 fe 7f 84 24 30 0a 	vmovdqu %ymm0,0xa30(%rsp)
 12110d4:	00 00 
 12110d6:	c5 fe 7f 84 24 50 0a 	vmovdqu %ymm0,0xa50(%rsp)
 12110dd:	00 00 
 12110df:	c5 fe 7f 84 24 70 0a 	vmovdqu %ymm0,0xa70(%rsp)
 12110e6:	00 00 
 12110e8:	c5 fe 7f 84 24 90 0a 	vmovdqu %ymm0,0xa90(%rsp)
 12110ef:	00 00 
 12110f1:	c5 fe 7f 84 24 b0 0a 	vmovdqu %ymm0,0xab0(%rsp)
 12110f8:	00 00 
 12110fa:	c5 fe 7f 84 24 d0 0a 	vmovdqu %ymm0,0xad0(%rsp)
 1211101:	00 00 
 1211103:	c5 fe 7f 84 24 f0 0a 	vmovdqu %ymm0,0xaf0(%rsp)
 121110a:	00 00 
 121110c:	c5 fe 7f 84 24 10 0b 	vmovdqu %ymm0,0xb10(%rsp)
 1211113:	00 00 
 1211115:	48 c7 84 24 30 0b 00 	movq   $0x0,0xb30(%rsp)
 121111c:	00 00 00 00 00 
 1211121:	c6 84 24 48 0b 00 00 	movb   $0x38,0xb48(%rsp)
 1211128:	38 
 1211129:	c6 84 24 50 0b 00 00 	movb   $0x0,0xb50(%rsp)
 1211130:	00 
 1211131:	0f b7 05 10 9e e2 ff 	movzwl -0x1d61f0(%rip),%eax        # 103af48 <__anon_35281>
 1211138:	66 89 84 24 4a 0b 00 	mov    %ax,0xb4a(%rsp)
 121113f:	00 
 1211140:	40 88 b4 24 49 0b 00 	mov    %sil,0xb49(%rsp)
 1211147:	00 
 1211148:	48 8b 84 24 f0 00 00 	mov    0xf0(%rsp),%rax
 121114f:	00 
 1211150:	48 89 84 24 30 09 00 	mov    %rax,0x930(%rsp)
 1211157:	00 
 1211158:	48 8b 84 24 e8 00 00 	mov    0xe8(%rsp),%rax
 121115f:	00 
 1211160:	48 89 84 24 38 09 00 	mov    %rax,0x938(%rsp)
 1211167:	00 
 1211168:	c7 84 24 4c 0b 00 00 	movl   $0x1000101,0xb4c(%rsp)
 121116f:	01 01 00 01 
 1211173:	48 8b 84 24 e0 00 00 	mov    0xe0(%rsp),%rax
 121117a:	00 
 121117b:	48 89 84 24 40 0b 00 	mov    %rax,0xb40(%rsp)
 1211182:	00 
 1211183:	48 8b 84 24 d8 00 00 	mov    0xd8(%rsp),%rax
 121118a:	00 
 121118b:	48 89 84 24 38 0b 00 	mov    %rax,0xb38(%rsp)
 1211192:	00 
 1211193:	66 c7 84 24 52 0b 00 	movw   $0x0,0xb52(%rsp)
 121119a:	00 00 00 
 121119d:	48 c7 84 24 48 09 00 	movq   $0x0,0x948(%rsp)
 12111a4:	00 00 00 00 00 
 12111a9:	48 8d 84 24 30 09 00 	lea    0x930(%rsp),%rax
 12111b0:	00 
 12111b1:	4c 8d 94 24 70 06 00 	lea    0x670(%rsp),%r10
 12111b8:	00 
 12111b9:	48 8d bc 24 d8 03 00 	lea    0x3d8(%rsp),%rdi
 12111c0:	00 
 12111c1:	48 8b 74 24 48       	mov    0x48(%rsp),%rsi
 12111c6:	48 8b 94 24 c8 00 00 	mov    0xc8(%rsp),%rdx
 12111cd:	00 
 12111ce:	48 8b 8c 24 a8 00 00 	mov    0xa8(%rsp),%rcx
 12111d5:	00 
 12111d6:	4c 8b 84 24 b0 00 00 	mov    0xb0(%rsp),%r8
 12111dd:	00 
 12111de:	50                   	push   %rax
 12111df:	41 52                	push   %r10
 12111e1:	c5 f8 77             	vzeroupper 
 12111e4:	e8 17 38 f6 ff       	call   1174a00 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_35307>
 12111e9:	48 83 c4 10          	add    $0x10,%rsp
 12111ed:	0f b7 9c 24 e8 03 00 	movzwl 0x3e8(%rsp),%ebx
 12111f4:	00 
 12111f5:	66 85 db             	test   %bx,%bx
 12111f8:	0f 85 02 05 00 00    	jne    1211700 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x18f0>
 12111fe:	4c 89 fb             	mov    %r15,%rbx
 1211201:	4c 8b a4 24 d8 03 00 	mov    0x3d8(%rsp),%r12
 1211208:	00 
 1211209:	4c 8b bc 24 e0 03 00 	mov    0x3e0(%rsp),%r15
 1211210:	00 
 1211211:	4c 8b 4c 24 38       	mov    0x38(%rsp),%r9
 1211216:	4d 39 f9             	cmp    %r15,%r9
 1211219:	0f 83 dc 02 00 00    	jae    12114fb <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x16eb>
 121121f:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 1211224:	48 8b 38             	mov    (%rax),%rdi
 1211227:	48 8b 40 08          	mov    0x8(%rax),%rax
 121122b:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 121122f:	4c 89 e6             	mov    %r12,%rsi
 1211232:	4c 89 fa             	mov    %r15,%rdx
 1211235:	31 c9                	xor    %ecx,%ecx
 1211237:	4d 89 cf             	mov    %r9,%r15
 121123a:	ff 50 18             	call   *0x18(%rax)
 121123d:	c5 fc 10 84 24 90 02 	vmovups 0x290(%rsp),%ymm0
 1211244:	00 00 
 1211246:	48 8b 45 10          	mov    0x10(%rbp),%rax
 121124a:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 121124f:	c5 fc 10 84 24 20 02 	vmovups 0x220(%rsp),%ymm0
 1211256:	00 00 
 1211258:	c5 fc 10 8c 24 40 02 	vmovups 0x240(%rsp),%ymm1
 121125f:	00 00 
 1211261:	c5 fc 10 94 24 60 02 	vmovups 0x260(%rsp),%ymm2
 1211268:	00 00 
 121126a:	c5 fc 10 9c 24 80 02 	vmovups 0x280(%rsp),%ymm3
 1211271:	00 00 
 1211273:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1211278:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 121127d:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1211282:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1211286:	48 8b 54 24 50       	mov    0x50(%rsp),%rdx
 121128b:	66 c7 82 60 01 00 00 	movw   $0x0,0x160(%rdx)
 1211292:	00 00 
 1211294:	4c 89 2a             	mov    %r13,(%rdx)
 1211297:	4c 89 7a 08          	mov    %r15,0x8(%rdx)
 121129b:	8b 44 24 40          	mov    0x40(%rsp),%eax
 121129f:	88 82 58 01 00 00    	mov    %al,0x158(%rdx)
 12112a5:	48 8b 44 24 68       	mov    0x68(%rsp),%rax
 12112aa:	48 89 42 10          	mov    %rax,0x10(%rdx)
 12112ae:	0f b6 44 24 28       	movzbl 0x28(%rsp),%eax
 12112b3:	88 42 18             	mov    %al,0x18(%rdx)
 12112b6:	0f b6 44 24 1e       	movzbl 0x1e(%rsp),%eax
 12112bb:	88 42 19             	mov    %al,0x19(%rdx)
 12112be:	c5 fc 28 84 24 40 01 	vmovaps 0x140(%rsp),%ymm0
 12112c5:	00 00 
 12112c7:	c5 fc 11 42 1a       	vmovups %ymm0,0x1a(%rdx)
 12112cc:	c5 fc 28 84 24 00 01 	vmovaps 0x100(%rsp),%ymm0
 12112d3:	00 00 
 12112d5:	c5 fc 11 42 3a       	vmovups %ymm0,0x3a(%rdx)
 12112da:	8b 44 24 30          	mov    0x30(%rsp),%eax
 12112de:	89 42 5a             	mov    %eax,0x5a(%rdx)
 12112e1:	0f b7 44 24 34       	movzwl 0x34(%rsp),%eax
 12112e6:	66 89 42 5e          	mov    %ax,0x5e(%rdx)
 12112ea:	44 88 72 60          	mov    %r14b,0x60(%rdx)
 12112ee:	8b 84 24 80 00 00 00 	mov    0x80(%rsp),%eax
 12112f5:	8b 8c 24 83 00 00 00 	mov    0x83(%rsp),%ecx
 12112fc:	89 42 61             	mov    %eax,0x61(%rdx)
 12112ff:	89 4a 64             	mov    %ecx,0x64(%rdx)
 1211302:	c5 fc 10 84 24 b8 02 	vmovups 0x2b8(%rsp),%ymm0
 1211309:	00 00 
 121130b:	c5 fc 10 8c 24 d8 02 	vmovups 0x2d8(%rsp),%ymm1
 1211312:	00 00 
 1211314:	c5 fc 10 94 24 f8 02 	vmovups 0x2f8(%rsp),%ymm2
 121131b:	00 00 
 121131d:	c5 fc 10 9c 24 18 03 	vmovups 0x318(%rsp),%ymm3
 1211324:	00 00 
 1211326:	c5 fc 11 42 68       	vmovups %ymm0,0x68(%rdx)
 121132b:	c5 fc 11 8a 88 00 00 	vmovups %ymm1,0x88(%rdx)
 1211332:	00 
 1211333:	c5 fc 11 92 a8 00 00 	vmovups %ymm2,0xa8(%rdx)
 121133a:	00 
 121133b:	c5 fc 11 9a c8 00 00 	vmovups %ymm3,0xc8(%rdx)
 1211342:	00 
 1211343:	c5 fc 10 84 24 38 03 	vmovups 0x338(%rsp),%ymm0
 121134a:	00 00 
 121134c:	c5 fc 11 82 e8 00 00 	vmovups %ymm0,0xe8(%rdx)
 1211353:	00 
 1211354:	c5 fc 10 84 24 58 03 	vmovups 0x358(%rsp),%ymm0
 121135b:	00 00 
 121135d:	c5 fc 11 82 08 01 00 	vmovups %ymm0,0x108(%rdx)
 1211364:	00 
 1211365:	c5 fc 10 84 24 78 03 	vmovups 0x378(%rsp),%ymm0
 121136c:	00 00 
 121136e:	c5 fc 11 82 28 01 00 	vmovups %ymm0,0x128(%rdx)
 1211375:	00 
 1211376:	c5 fe 6f 84 24 88 03 	vmovdqu 0x388(%rsp),%ymm0
 121137d:	00 00 
 121137f:	c5 fe 7f 82 38 01 00 	vmovdqu %ymm0,0x138(%rdx)
 1211386:	00 
 1211387:	80 e3 03             	and    $0x3,%bl
 121138a:	88 9a 59 01 00 00    	mov    %bl,0x159(%rdx)
 1211390:	e9 45 01 00 00       	jmp    12114da <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x16ca>
 1211395:	c5 fc 10 84 24 90 02 	vmovups 0x290(%rsp),%ymm0
 121139c:	00 00 
 121139e:	48 8b 45 10          	mov    0x10(%rbp),%rax
 12113a2:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 12113a7:	c5 fc 10 84 24 20 02 	vmovups 0x220(%rsp),%ymm0
 12113ae:	00 00 
 12113b0:	c5 fc 10 8c 24 40 02 	vmovups 0x240(%rsp),%ymm1
 12113b7:	00 00 
 12113b9:	c5 fc 10 94 24 60 02 	vmovups 0x260(%rsp),%ymm2
 12113c0:	00 00 
 12113c2:	c5 fc 10 9c 24 80 02 	vmovups 0x280(%rsp),%ymm3
 12113c9:	00 00 
 12113cb:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 12113d0:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 12113d5:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 12113da:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 12113de:	48 8b 54 24 50       	mov    0x50(%rsp),%rdx
 12113e3:	66 c7 82 60 01 00 00 	movw   $0x0,0x160(%rdx)
 12113ea:	00 00 
 12113ec:	4c 89 12             	mov    %r10,(%rdx)
 12113ef:	48 8b 44 24 38       	mov    0x38(%rsp),%rax
 12113f4:	48 89 42 08          	mov    %rax,0x8(%rdx)
 12113f8:	c6 82 58 01 00 00 00 	movb   $0x0,0x158(%rdx)
 12113ff:	48 8b 44 24 68       	mov    0x68(%rsp),%rax
 1211404:	48 89 42 10          	mov    %rax,0x10(%rdx)
 1211408:	0f b6 44 24 28       	movzbl 0x28(%rsp),%eax
 121140d:	88 42 18             	mov    %al,0x18(%rdx)
 1211410:	0f b6 44 24 1e       	movzbl 0x1e(%rsp),%eax
 1211415:	88 42 19             	mov    %al,0x19(%rdx)
 1211418:	c5 fe 7f 6a 1a       	vmovdqu %ymm5,0x1a(%rdx)
 121141d:	c5 fe 7f 62 3a       	vmovdqu %ymm4,0x3a(%rdx)
 1211422:	8b 44 24 30          	mov    0x30(%rsp),%eax
 1211426:	89 42 5a             	mov    %eax,0x5a(%rdx)
 1211429:	0f b7 44 24 34       	movzwl 0x34(%rsp),%eax
 121142e:	66 89 42 5e          	mov    %ax,0x5e(%rdx)
 1211432:	44 88 5a 60          	mov    %r11b,0x60(%rdx)
 1211436:	8b 84 24 80 00 00 00 	mov    0x80(%rsp),%eax
 121143d:	8b 8c 24 83 00 00 00 	mov    0x83(%rsp),%ecx
 1211444:	89 42 61             	mov    %eax,0x61(%rdx)
 1211447:	89 4a 64             	mov    %ecx,0x64(%rdx)
 121144a:	c5 fc 10 84 24 b8 02 	vmovups 0x2b8(%rsp),%ymm0
 1211451:	00 00 
 1211453:	c5 fc 10 8c 24 d8 02 	vmovups 0x2d8(%rsp),%ymm1
 121145a:	00 00 
 121145c:	c5 fc 10 94 24 f8 02 	vmovups 0x2f8(%rsp),%ymm2
 1211463:	00 00 
 1211465:	c5 fc 10 9c 24 18 03 	vmovups 0x318(%rsp),%ymm3
 121146c:	00 00 
 121146e:	c5 fc 11 42 68       	vmovups %ymm0,0x68(%rdx)
 1211473:	c5 fc 11 8a 88 00 00 	vmovups %ymm1,0x88(%rdx)
 121147a:	00 
 121147b:	c5 fc 11 92 a8 00 00 	vmovups %ymm2,0xa8(%rdx)
 1211482:	00 
 1211483:	c5 fc 11 9a c8 00 00 	vmovups %ymm3,0xc8(%rdx)
 121148a:	00 
 121148b:	c5 fc 10 84 24 38 03 	vmovups 0x338(%rsp),%ymm0
 1211492:	00 00 
 1211494:	c5 fc 11 82 e8 00 00 	vmovups %ymm0,0xe8(%rdx)
 121149b:	00 
 121149c:	c5 fc 10 84 24 58 03 	vmovups 0x358(%rsp),%ymm0
 12114a3:	00 00 
 12114a5:	c5 fc 11 82 08 01 00 	vmovups %ymm0,0x108(%rdx)
 12114ac:	00 
 12114ad:	c5 fc 10 84 24 78 03 	vmovups 0x378(%rsp),%ymm0
 12114b4:	00 00 
 12114b6:	c5 fc 11 82 28 01 00 	vmovups %ymm0,0x128(%rdx)
 12114bd:	00 
 12114be:	c5 fe 6f 84 24 88 03 	vmovdqu 0x388(%rsp),%ymm0
 12114c5:	00 00 
 12114c7:	c5 fe 7f 82 38 01 00 	vmovdqu %ymm0,0x138(%rdx)
 12114ce:	00 
 12114cf:	41 80 e7 03          	and    $0x3,%r15b
 12114d3:	44 88 ba 59 01 00 00 	mov    %r15b,0x159(%rdx)
 12114da:	48 8b 84 24 c0 00 00 	mov    0xc0(%rsp),%rax
 12114e1:	00 
 12114e2:	24 01                	and    $0x1,%al
 12114e4:	88 82 5a 01 00 00    	mov    %al,0x15a(%rdx)
 12114ea:	0f b7 44 24 2e       	movzwl 0x2e(%rsp),%eax
 12114ef:	66 89 82 5b 01 00 00 	mov    %ax,0x15b(%rdx)
 12114f6:	e9 04 01 00 00       	jmp    12115ff <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17ef>
 12114fb:	4d 85 c9             	test   %r9,%r9
 12114fe:	74 1b                	je     121151b <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x170b>
 1211500:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 1211505:	48 8b 38             	mov    (%rax),%rdi
 1211508:	48 8b 40 08          	mov    0x8(%rax),%rax
 121150c:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1211510:	4c 89 ee             	mov    %r13,%rsi
 1211513:	4c 89 ca             	mov    %r9,%rdx
 1211516:	31 c9                	xor    %ecx,%ecx
 1211518:	ff 50 18             	call   *0x18(%rax)
 121151b:	c5 fc 10 84 24 e0 06 	vmovups 0x6e0(%rsp),%ymm0
 1211522:	00 00 
 1211524:	48 8b 45 10          	mov    0x10(%rbp),%rax
 1211528:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 121152d:	c5 fe 6f 84 24 70 06 	vmovdqu 0x670(%rsp),%ymm0
 1211534:	00 00 
 1211536:	c5 fc 10 8c 24 90 06 	vmovups 0x690(%rsp),%ymm1
 121153d:	00 00 
 121153f:	c5 fc 10 94 24 b0 06 	vmovups 0x6b0(%rsp),%ymm2
 1211546:	00 00 
 1211548:	c5 fc 10 9c 24 d0 06 	vmovups 0x6d0(%rsp),%ymm3
 121154f:	00 00 
 1211551:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1211556:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 121155b:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1211560:	c5 fe 7f 00          	vmovdqu %ymm0,(%rax)
 1211564:	48 8b 44 24 50       	mov    0x50(%rsp),%rax
 1211569:	66 c7 80 60 01 00 00 	movw   $0x0,0x160(%rax)
 1211570:	00 00 
 1211572:	4c 89 20             	mov    %r12,(%rax)
 1211575:	4c 89 78 08          	mov    %r15,0x8(%rax)
 1211579:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 121157d:	c5 fe 7f 40 10       	vmovdqu %ymm0,0x10(%rax)
 1211582:	c5 fe 7f 40 30       	vmovdqu %ymm0,0x30(%rax)
 1211587:	c5 fe 7f 40 48       	vmovdqu %ymm0,0x48(%rax)
 121158c:	c7 80 58 01 00 00 00 	movl   $0x0,0x158(%rax)
 1211593:	00 00 00 
 1211596:	c6 80 5c 01 00 00 00 	movb   $0x0,0x15c(%rax)
 121159d:	eb 60                	jmp    12115ff <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17ef>
 121159f:	48 85 d2             	test   %rdx,%rdx
 12115a2:	74 42                	je     12115e6 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17d6>
 12115a4:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 12115a9:	48 8b 38             	mov    (%rax),%rdi
 12115ac:	48 8b 40 08          	mov    0x8(%rax),%rax
 12115b0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12115b4:	48 8b 74 24 60       	mov    0x60(%rsp),%rsi
 12115b9:	31 c9                	xor    %ecx,%ecx
 12115bb:	eb 23                	jmp    12115e0 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17d0>
 12115bd:	4d 85 ff             	test   %r15,%r15
 12115c0:	48 8b b4 24 b8 00 00 	mov    0xb8(%rsp),%rsi
 12115c7:	00 
 12115c8:	74 1c                	je     12115e6 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17d6>
 12115ca:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 12115cf:	48 8b 38             	mov    (%rax),%rdi
 12115d2:	48 8b 40 08          	mov    0x8(%rax),%rax
 12115d6:	4c 89 fa             	mov    %r15,%rdx
 12115d9:	31 c9                	xor    %ecx,%ecx
 12115db:	4c 8b 44 24 38       	mov    0x38(%rsp),%r8
 12115e0:	c5 f8 77             	vzeroupper 
 12115e3:	ff 50 18             	call   *0x18(%rax)
 12115e6:	48 8d 35 83 de e2 ff 	lea    -0x1d217d(%rip),%rsi        # 103f470 <__anon_46336>
 12115ed:	ba 68 01 00 00       	mov    $0x168,%edx
 12115f2:	48 8b 7c 24 50       	mov    0x50(%rsp),%rdi
 12115f7:	c5 f8 77             	vzeroupper 
 12115fa:	e8 61 4c 08 00       	call   1296260 <compiler_rt.memcpy.memcpyFast>
 12115ff:	48 8d 65 d8          	lea    -0x28(%rbp),%rsp
 1211603:	5b                   	pop    %rbx
 1211604:	41 5c                	pop    %r12
 1211606:	41 5d                	pop    %r13
 1211608:	41 5e                	pop    %r14
 121160a:	41 5f                	pop    %r15
 121160c:	5d                   	pop    %rbp
 121160d:	c5 f8 77             	vzeroupper 
 1211610:	c3                   	ret    
 1211611:	c5 fc 10 84 24 90 02 	vmovups 0x290(%rsp),%ymm0
 1211618:	00 00 
 121161a:	48 8b 45 10          	mov    0x10(%rbp),%rax
 121161e:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1211623:	c5 fc 10 84 24 20 02 	vmovups 0x220(%rsp),%ymm0
 121162a:	00 00 
 121162c:	c5 fc 10 8c 24 40 02 	vmovups 0x240(%rsp),%ymm1
 1211633:	00 00 
 1211635:	c5 fc 10 94 24 60 02 	vmovups 0x260(%rsp),%ymm2
 121163c:	00 00 
 121163e:	c5 fc 10 9c 24 80 02 	vmovups 0x280(%rsp),%ymm3
 1211645:	00 00 
 1211647:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 121164c:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1211651:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1211656:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 121165a:	48 8b 54 24 50       	mov    0x50(%rsp),%rdx
 121165f:	66 c7 82 60 01 00 00 	movw   $0x0,0x160(%rdx)
 1211666:	00 00 
 1211668:	4c 89 12             	mov    %r10,(%rdx)
 121166b:	48 8b 44 24 38       	mov    0x38(%rsp),%rax
 1211670:	48 89 42 08          	mov    %rax,0x8(%rdx)
 1211674:	8b 44 24 40          	mov    0x40(%rsp),%eax
 1211678:	88 82 58 01 00 00    	mov    %al,0x158(%rdx)
 121167e:	e9 7c fd ff ff       	jmp    12113ff <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x15ef>
 1211683:	48 8b 54 24 38       	mov    0x38(%rsp),%rdx
 1211688:	48 85 d2             	test   %rdx,%rdx
 121168b:	74 1a                	je     12116a7 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1897>
 121168d:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 1211692:	48 8b 38             	mov    (%rax),%rdi
 1211695:	48 8b 40 08          	mov    0x8(%rax),%rax
 1211699:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 121169d:	48 8b 74 24 60       	mov    0x60(%rsp),%rsi
 12116a2:	31 c9                	xor    %ecx,%ecx
 12116a4:	ff 50 18             	call   *0x18(%rax)
 12116a7:	48 8b 44 24 50       	mov    0x50(%rsp),%rax
 12116ac:	66 44 89 b8 60 01 00 	mov    %r15w,0x160(%rax)
 12116b3:	00 
 12116b4:	e9 46 ff ff ff       	jmp    12115ff <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17ef>
 12116b9:	48 8b 4c 24 50       	mov    0x50(%rsp),%rcx
 12116be:	66 89 81 60 01 00 00 	mov    %ax,0x160(%rcx)
 12116c5:	e9 35 ff ff ff       	jmp    12115ff <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17ef>
 12116ca:	48 8b 54 24 38       	mov    0x38(%rsp),%rdx
 12116cf:	48 85 d2             	test   %rdx,%rdx
 12116d2:	74 1a                	je     12116ee <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x18de>
 12116d4:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 12116d9:	48 8b 38             	mov    (%rax),%rdi
 12116dc:	48 8b 40 08          	mov    0x8(%rax),%rax
 12116e0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12116e4:	48 8b 74 24 60       	mov    0x60(%rsp),%rsi
 12116e9:	31 c9                	xor    %ecx,%ecx
 12116eb:	ff 50 18             	call   *0x18(%rax)
 12116ee:	48 8b 44 24 50       	mov    0x50(%rsp),%rax
 12116f3:	66 44 89 b0 60 01 00 	mov    %r14w,0x160(%rax)
 12116fa:	00 
 12116fb:	e9 ff fe ff ff       	jmp    12115ff <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17ef>
 1211700:	48 8b 54 24 38       	mov    0x38(%rsp),%rdx
 1211705:	48 85 d2             	test   %rdx,%rdx
 1211708:	74 18                	je     1211722 <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x1912>
 121170a:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 121170f:	48 8b 38             	mov    (%rax),%rdi
 1211712:	48 8b 40 08          	mov    0x8(%rax),%rax
 1211716:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 121171a:	4c 89 ee             	mov    %r13,%rsi
 121171d:	31 c9                	xor    %ecx,%ecx
 121171f:	ff 50 18             	call   *0x18(%rax)
 1211722:	48 8b 44 24 50       	mov    0x50(%rsp),%rax
 1211727:	66 89 98 60 01 00 00 	mov    %bx,0x160(%rax)
 121172e:	e9 cc fe ff ff       	jmp    12115ff <br.encodePreferredCommandPlanAllocRecorded__anon_43479+0x17ef>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
