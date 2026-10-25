 12131e0:	55                   	push   %rbp
 12131e1:	48 89 e5             	mov    %rsp,%rbp
 12131e4:	41 57                	push   %r15
 12131e6:	41 56                	push   %r14
 12131e8:	41 55                	push   %r13
 12131ea:	41 54                	push   %r12
 12131ec:	53                   	push   %rbx
 12131ed:	48 81 ec 18 16 00 00 	sub    $0x1618,%rsp
 12131f4:	48 89 cb             	mov    %rcx,%rbx
 12131f7:	48 c7 01 00 00 00 00 	movq   $0x0,(%rcx)
 12131fe:	66 41 c7 00 00 00    	movw   $0x0,(%r8)
 1213204:	0f b6 06             	movzbl (%rsi),%eax
 1213207:	44 8b 0c 87          	mov    (%rdi,%rax,4),%r9d
 121320b:	45 85 c9             	test   %r9d,%r9d
 121320e:	74 10                	je     1213220 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x40>
 1213210:	41 88 40 02          	mov    %al,0x2(%r8)
 1213214:	66 41 c7 00 01 00    	movw   $0x1,(%r8)
 121321a:	66 b8 01 00          	mov    $0x1,%ax
 121321e:	eb 08                	jmp    1213228 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x48>
 1213220:	41 b9 ff ff ff ff    	mov    $0xffffffff,%r9d
 1213226:	31 c0                	xor    %eax,%eax

 1213262:	46 0f b6 7c 16 01    	movzbl 0x1(%rsi,%r10,1),%r15d
 1213268:	46 8b 34 bf          	mov    (%rdi,%r15,4),%r14d
 121326c:	45 85 f6             	test   %r14d,%r14d
 121326f:	74 2f                	je     12132a0 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0xc0>
 1213271:	44 0f b7 e0          	movzwl %ax,%r12d
 1213275:	47 88 7c 20 02       	mov    %r15b,0x2(%r8,%r12,1)
 121327a:	ff c0                	inc    %eax
 121327c:	66 41 89 00          	mov    %ax,(%r8)
 1213280:	45 39 ce             	cmp    %r9d,%r14d
 1213283:	41 0f 96 c1          	setbe  %r9b
 1213287:	44 20 c9             	and    %r9b,%cl
 121328a:	46 0f b6 7c 16 02    	movzbl 0x2(%rsi,%r10,1),%r15d
 1213290:	46 8b 0c bf          	mov    (%rdi,%r15,4),%r9d
 1213294:	45 85 c9             	test   %r9d,%r9d
 1213297:	75 a7                	jne    1213240 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x60>
 1213299:	eb 17                	jmp    12132b2 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0xd2>

 12132e7:	66 85 c0             	test   %ax,%ax
 12132ea:	74 1d                	je     1213309 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x129>
 12132ec:	44 0f b7 d8          	movzwl %ax,%r11d
 12132f0:	f6 c1 01             	test   $0x1,%cl
 12132f3:	74 1d                	je     1213312 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x132>
 12132f5:	44 89 d8             	mov    %r11d,%eax
 12132f8:	83 e0 07             	and    $0x7,%eax
 12132fb:	66 41 83 fb 08       	cmp    $0x8,%r11w
 1213300:	73 71                	jae    1213373 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x193>
 1213302:	31 c9                	xor    %ecx,%ecx
 1213304:	e9 d8 00 00 00       	jmp    12133e1 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x201>
 1213309:	66 b8 1f 00          	mov    $0x1f,%ax
 121330d:	e9 d9 0f 00 00       	jmp    12142eb <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x110b>
 1213312:	66 41 83 fb 40       	cmp    $0x40,%r11w
 1213317:	0f 83 f8 00 00 00    	jae    1213415 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x235>
 121331d:	48 8b 03             	mov    (%rbx),%rax
 1213320:	41 83 fb 01          	cmp    $0x1,%r11d
 1213324:	0f 85 ce 01 00 00    	jne    12134f8 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x318>
 121332a:	31 c9                	xor    %ecx,%ecx

 1213430:	45 0f b6 4c 10 02    	movzbl 0x2(%r8,%rdx,1),%r9d
 1213436:	46 8b 14 8f          	mov    (%rdi,%r9,4),%r10d
 121343a:	41 f7 d2             	not    %r10d
 121343d:	49 c1 e2 08          	shl    $0x8,%r10
 1213441:	4d 09 ca             	or     %r9,%r10
 1213444:	4c 89 94 d5 c0 f1 ff 	mov    %r10,-0xe40(%rbp,%rdx,8)
 121344b:	ff 
 121344c:	45 0f b6 4c 10 03    	movzbl 0x3(%r8,%rdx,1),%r9d
 1213452:	46 8b 14 8f          	mov    (%rdi,%r9,4),%r10d
 1213456:	41 f7 d2             	not    %r10d
 1213459:	49 c1 e2 08          	shl    $0x8,%r10
 121345d:	4d 09 ca             	or     %r9,%r10
 1213460:	4c 89 94 d5 c8 f1 ff 	mov    %r10,-0xe38(%rbp,%rdx,8)
 1213467:	ff 
