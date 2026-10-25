
/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/1928ccf0f65566cb15f468f5a8857ce6/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

00000000012131e0 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625>:
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
 1213228:	48 ff ca             	dec    %rdx
 121322b:	49 89 d3             	mov    %rdx,%r11
 121322e:	49 83 e3 fe          	and    $0xfffffffffffffffe,%r11
 1213232:	b1 01                	mov    $0x1,%cl
 1213234:	45 31 d2             	xor    %r10d,%r10d
 1213237:	eb 29                	jmp    1213262 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x82>
 1213239:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)
 1213240:	44 0f b7 e0          	movzwl %ax,%r12d
 1213244:	47 88 7c 20 02       	mov    %r15b,0x2(%r8,%r12,1)
 1213249:	ff c0                	inc    %eax
 121324b:	66 41 89 00          	mov    %ax,(%r8)
 121324f:	45 39 f1             	cmp    %r14d,%r9d
 1213252:	41 0f 96 c6          	setbe  %r14b
 1213256:	44 20 f1             	and    %r14b,%cl
 1213259:	49 83 c2 02          	add    $0x2,%r10
 121325d:	4d 39 d3             	cmp    %r10,%r11
 1213260:	74 5c                	je     12132be <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0xde>
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
 121329b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 12132a0:	45 89 ce             	mov    %r9d,%r14d
 12132a3:	46 0f b6 7c 16 02    	movzbl 0x2(%rsi,%r10,1),%r15d
 12132a9:	46 8b 0c bf          	mov    (%rdi,%r15,4),%r9d
 12132ad:	45 85 c9             	test   %r9d,%r9d
 12132b0:	75 8e                	jne    1213240 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x60>
 12132b2:	45 89 f1             	mov    %r14d,%r9d
 12132b5:	49 83 c2 02          	add    $0x2,%r10
 12132b9:	4d 39 d3             	cmp    %r10,%r11
 12132bc:	75 a4                	jne    1213262 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x82>
 12132be:	f6 c2 01             	test   $0x1,%dl
 12132c1:	74 24                	je     12132e7 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x107>
 12132c3:	42 0f b6 74 16 01    	movzbl 0x1(%rsi,%r10,1),%esi
 12132c9:	8b 14 b7             	mov    (%rdi,%rsi,4),%edx
 12132cc:	85 d2                	test   %edx,%edx
 12132ce:	74 17                	je     12132e7 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x107>
 12132d0:	44 0f b7 d0          	movzwl %ax,%r10d
 12132d4:	43 88 74 10 02       	mov    %sil,0x2(%r8,%r10,1)
 12132d9:	ff c0                	inc    %eax
 12132db:	66 41 89 00          	mov    %ax,(%r8)
 12132df:	44 39 ca             	cmp    %r9d,%edx
 12132e2:	0f 96 c2             	setbe  %dl
 12132e5:	20 d1                	and    %dl,%cl
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
 121332c:	41 f6 c3 01          	test   $0x1,%r11b
 1213330:	0f 84 b3 0f 00 00    	je     12142e9 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x1109>
 1213336:	41 0f b6 4c 08 02    	movzbl 0x2(%r8,%rcx,1),%ecx
 121333c:	48 85 c0             	test   %rax,%rax
 121333f:	74 23                	je     1213364 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x184>
 1213341:	8b 14 8f             	mov    (%rdi,%rcx,4),%edx
 1213344:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 121334b:	00 00 00 00 00 
 1213350:	0f b7 74 43 06       	movzwl 0x6(%rbx,%rax,2),%esi
 1213355:	3b 14 b7             	cmp    (%rdi,%rsi,4),%edx
 1213358:	76 0c                	jbe    1213366 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x186>
 121335a:	48 ff c8             	dec    %rax
 121335d:	66 89 74 43 0a       	mov    %si,0xa(%rbx,%rax,2)
 1213362:	75 ec                	jne    1213350 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x170>
 1213364:	31 c0                	xor    %eax,%eax
 1213366:	66 89 4c 43 08       	mov    %cx,0x8(%rbx,%rax,2)
 121336b:	48 ff 03             	incq   (%rbx)
 121336e:	e9 76 0f 00 00       	jmp    12142e9 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x1109>
 1213373:	44 89 da             	mov    %r11d,%edx
 1213376:	83 e2 f8             	and    $0xfffffff8,%edx
 1213379:	31 c9                	xor    %ecx,%ecx
 121337b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 1213380:	41 0f b6 74 08 02    	movzbl 0x2(%r8,%rcx,1),%esi
 1213386:	66 89 74 4b 08       	mov    %si,0x8(%rbx,%rcx,2)
 121338b:	41 0f b6 74 08 03    	movzbl 0x3(%r8,%rcx,1),%esi
 1213391:	66 89 74 4b 0a       	mov    %si,0xa(%rbx,%rcx,2)
 1213396:	41 0f b6 74 08 04    	movzbl 0x4(%r8,%rcx,1),%esi
 121339c:	66 89 74 4b 0c       	mov    %si,0xc(%rbx,%rcx,2)
 12133a1:	41 0f b6 74 08 05    	movzbl 0x5(%r8,%rcx,1),%esi
 12133a7:	66 89 74 4b 0e       	mov    %si,0xe(%rbx,%rcx,2)
 12133ac:	41 0f b6 74 08 06    	movzbl 0x6(%r8,%rcx,1),%esi
 12133b2:	66 89 74 4b 10       	mov    %si,0x10(%rbx,%rcx,2)
 12133b7:	41 0f b6 74 08 07    	movzbl 0x7(%r8,%rcx,1),%esi
 12133bd:	66 89 74 4b 12       	mov    %si,0x12(%rbx,%rcx,2)
 12133c2:	41 0f b6 74 08 08    	movzbl 0x8(%r8,%rcx,1),%esi
 12133c8:	66 89 74 4b 14       	mov    %si,0x14(%rbx,%rcx,2)
 12133cd:	41 0f b6 74 08 09    	movzbl 0x9(%r8,%rcx,1),%esi
 12133d3:	66 89 74 4b 16       	mov    %si,0x16(%rbx,%rcx,2)
 12133d8:	48 83 c1 08          	add    $0x8,%rcx
 12133dc:	48 39 ca             	cmp    %rcx,%rdx
 12133df:	75 9f                	jne    1213380 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x1a0>
 12133e1:	48 85 c0             	test   %rax,%rax
 12133e4:	0f 84 fc 0e 00 00    	je     12142e6 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x1106>
 12133ea:	48 8d 14 4b          	lea    (%rbx,%rcx,2),%rdx
 12133ee:	48 83 c2 08          	add    $0x8,%rdx
 12133f2:	4c 01 c1             	add    %r8,%rcx
 12133f5:	48 83 c1 02          	add    $0x2,%rcx
 12133f9:	31 f6                	xor    %esi,%esi
 12133fb:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 1213400:	0f b6 3c 31          	movzbl (%rcx,%rsi,1),%edi
 1213404:	66 89 3c 72          	mov    %di,(%rdx,%rsi,2)
 1213408:	48 ff c6             	inc    %rsi
 121340b:	48 39 f0             	cmp    %rsi,%rax
 121340e:	75 f0                	jne    1213400 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x220>
 1213410:	e9 d1 0e 00 00       	jmp    12142e6 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x1106>
 1213415:	49 8d 43 ff          	lea    -0x1(%r11),%rax
 1213419:	44 89 d9             	mov    %r11d,%ecx
 121341c:	83 e1 03             	and    $0x3,%ecx
 121341f:	44 89 de             	mov    %r11d,%esi
 1213422:	83 e6 fc             	and    $0xfffffffc,%esi
 1213425:	31 d2                	xor    %edx,%edx
 1213427:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 121342e:	00 00 
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
 1213468:	45 0f b6 4c 10 04    	movzbl 0x4(%r8,%rdx,1),%r9d
 121346e:	46 8b 14 8f          	mov    (%rdi,%r9,4),%r10d
 1213472:	41 f7 d2             	not    %r10d
 1213475:	49 c1 e2 08          	shl    $0x8,%r10
 1213479:	4d 09 ca             	or     %r9,%r10
 121347c:	4c 89 94 d5 d0 f1 ff 	mov    %r10,-0xe30(%rbp,%rdx,8)
 1213483:	ff 
 1213484:	45 0f b6 4c 10 05    	movzbl 0x5(%r8,%rdx,1),%r9d
 121348a:	46 8b 14 8f          	mov    (%rdi,%r9,4),%r10d
 121348e:	41 f7 d2             	not    %r10d
 1213491:	49 c1 e2 08          	shl    $0x8,%r10
 1213495:	4d 09 ca             	or     %r9,%r10
 1213498:	4c 89 94 d5 d8 f1 ff 	mov    %r10,-0xe28(%rbp,%rdx,8)
 121349f:	ff 
 12134a0:	48 83 c2 04          	add    $0x4,%rdx
 12134a4:	48 39 d6             	cmp    %rdx,%rsi
 12134a7:	75 87                	jne    1213430 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x250>
 12134a9:	48 85 c9             	test   %rcx,%rcx
 12134ac:	74 26                	je     12134d4 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x2f4>
 12134ae:	66 90                	xchg   %ax,%ax
 12134b0:	41 0f b6 74 10 02    	movzbl 0x2(%r8,%rdx,1),%esi
 12134b6:	44 8b 0c b7          	mov    (%rdi,%rsi,4),%r9d
 12134ba:	41 f7 d1             	not    %r9d
 12134bd:	49 c1 e1 08          	shl    $0x8,%r9
 12134c1:	49 09 f1             	or     %rsi,%r9
 12134c4:	4c 89 8c d5 c0 f1 ff 	mov    %r9,-0xe40(%rbp,%rdx,8)
 12134cb:	ff 
 12134cc:	48 ff c2             	inc    %rdx
 12134cf:	48 ff c9             	dec    %rcx
 12134d2:	75 dc                	jne    12134b0 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x2d0>
 12134d4:	48 8b 8d c0 f1 ff ff 	mov    -0xe40(%rbp),%rcx
 12134db:	89 c2                	mov    %eax,%edx
 12134dd:	83 e2 07             	and    $0x7,%edx
 12134e0:	41 8d 73 fe          	lea    -0x2(%r11),%esi
 12134e4:	66 83 fe 07          	cmp    $0x7,%si
 12134e8:	0f 83 b3 00 00 00    	jae    12135a1 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x3c1>
 12134ee:	45 31 ff             	xor    %r15d,%r15d
 12134f1:	31 f6                	xor    %esi,%esi
 12134f3:	e9 31 01 00 00       	jmp    1213629 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x449>
 12134f8:	44 89 da             	mov    %r11d,%edx
 12134fb:	83 e2 3e             	and    $0x3e,%edx
 12134fe:	31 c9                	xor    %ecx,%ecx
 1213500:	eb 2d                	jmp    121352f <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x34f>
 1213502:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1213509:	1f 84 00 00 00 00 00 
 1213510:	48 83 c0 fc          	add    $0xfffffffffffffffc,%rax
 1213514:	66 89 74 43 08       	mov    %si,0x8(%rbx,%rax,2)
 1213519:	48 8b 03             	mov    (%rbx),%rax
 121351c:	48 ff c0             	inc    %rax
 121351f:	48 89 03             	mov    %rax,(%rbx)
 1213522:	48 83 c1 02          	add    $0x2,%rcx
 1213526:	48 39 d1             	cmp    %rdx,%rcx
 1213529:	0f 84 fd fd ff ff    	je     121332c <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x14c>
 121352f:	41 0f b6 74 08 02    	movzbl 0x2(%r8,%rcx,1),%esi
 1213535:	48 85 c0             	test   %rax,%rax
 1213538:	74 1d                	je     1213557 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x377>
 121353a:	44 8b 0c b7          	mov    (%rdi,%rsi,4),%r9d
 121353e:	66 90                	xchg   %ax,%ax
 1213540:	44 0f b7 54 43 06    	movzwl 0x6(%rbx,%rax,2),%r10d
 1213546:	46 3b 0c 97          	cmp    (%rdi,%r10,4),%r9d
 121354a:	76 0d                	jbe    1213559 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x379>
 121354c:	48 ff c8             	dec    %rax
 121354f:	66 44 89 54 43 0a    	mov    %r10w,0xa(%rbx,%rax,2)
 1213555:	75 e9                	jne    1213540 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x360>
 1213557:	31 c0                	xor    %eax,%eax
 1213559:	66 89 74 43 08       	mov    %si,0x8(%rbx,%rax,2)
 121355e:	48 8b 03             	mov    (%rbx),%rax
 1213561:	48 8d 70 01          	lea    0x1(%rax),%rsi
 1213565:	48 89 33             	mov    %rsi,(%rbx)
 1213568:	41 0f b6 74 08 03    	movzbl 0x3(%r8,%rcx,1),%esi
 121356e:	44 8b 0c b7          	mov    (%rdi,%rsi,4),%r9d
 1213572:	48 83 c0 05          	add    $0x5,%rax
 1213576:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 121357d:	00 00 00 
 1213580:	44 0f b7 54 43 fe    	movzwl -0x2(%rbx,%rax,2),%r10d
 1213586:	46 3b 0c 97          	cmp    (%rdi,%r10,4),%r9d
 121358a:	76 84                	jbe    1213510 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x330>
 121358c:	66 44 89 14 43       	mov    %r10w,(%rbx,%rax,2)
 1213591:	48 ff c8             	dec    %rax
 1213594:	48 83 f8 04          	cmp    $0x4,%rax
 1213598:	75 e6                	jne    1213580 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x3a0>
 121359a:	31 c0                	xor    %eax,%eax
 121359c:	e9 73 ff ff ff       	jmp    1213514 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x334>
 12135a1:	48 83 e0 f8          	and    $0xfffffffffffffff8,%rax
 12135a5:	45 31 ff             	xor    %r15d,%r15d
 12135a8:	31 f6                	xor    %esi,%esi
 12135aa:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 12135b0:	48 8b bc f5 c8 f1 ff 	mov    -0xe38(%rbp,%rsi,8),%rdi
 12135b7:	ff 
 12135b8:	48 31 cf             	xor    %rcx,%rdi
 12135bb:	4c 09 ff             	or     %r15,%rdi
 12135be:	4c 8b 84 f5 d0 f1 ff 	mov    -0xe30(%rbp,%rsi,8),%r8
 12135c5:	ff 
 12135c6:	49 31 c8             	xor    %rcx,%r8
 12135c9:	4c 8b 8c f5 d8 f1 ff 	mov    -0xe28(%rbp,%rsi,8),%r9
 12135d0:	ff 
 12135d1:	49 31 c9             	xor    %rcx,%r9
 12135d4:	4d 09 c1             	or     %r8,%r9
 12135d7:	49 09 f9             	or     %rdi,%r9
 12135da:	48 8b bc f5 e0 f1 ff 	mov    -0xe20(%rbp,%rsi,8),%rdi
 12135e1:	ff 
 12135e2:	48 31 cf             	xor    %rcx,%rdi
 12135e5:	4c 8b 84 f5 e8 f1 ff 	mov    -0xe18(%rbp,%rsi,8),%r8
 12135ec:	ff 
 12135ed:	49 31 c8             	xor    %rcx,%r8
 12135f0:	49 09 f8             	or     %rdi,%r8
 12135f3:	48 8b bc f5 f0 f1 ff 	mov    -0xe10(%rbp,%rsi,8),%rdi
 12135fa:	ff 
 12135fb:	48 31 cf             	xor    %rcx,%rdi
 12135fe:	4c 09 c7             	or     %r8,%rdi
 1213601:	4c 09 cf             	or     %r9,%rdi
 1213604:	4c 8b 84 f5 f8 f1 ff 	mov    -0xe08(%rbp,%rsi,8),%r8
 121360b:	ff 
 121360c:	49 31 c8             	xor    %rcx,%r8
 121360f:	4c 8b bc f5 00 f2 ff 	mov    -0xe00(%rbp,%rsi,8),%r15
 1213616:	ff 
 1213617:	49 31 cf             	xor    %rcx,%r15
 121361a:	4d 09 c7             	or     %r8,%r15
 121361d:	49 09 ff             	or     %rdi,%r15
 1213620:	48 83 c6 08          	add    $0x8,%rsi
 1213624:	48 39 f0             	cmp    %rsi,%rax
 1213627:	75 87                	jne    12135b0 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x3d0>
 1213629:	48 85 d2             	test   %rdx,%rdx
 121362c:	74 24                	je     1213652 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x472>
 121362e:	48 8d 04 f5 c8 f1 ff 	lea    -0xe38(,%rsi,8),%rax
 1213635:	ff 
 1213636:	48 01 e8             	add    %rbp,%rax
 1213639:	31 f6                	xor    %esi,%esi
 121363b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 1213640:	48 8b 3c f0          	mov    (%rax,%rsi,8),%rdi
 1213644:	48 31 cf             	xor    %rcx,%rdi
 1213647:	49 09 ff             	or     %rdi,%r15
 121364a:	48 ff c6             	inc    %rsi
 121364d:	48 39 f2             	cmp    %rsi,%rdx
 1213650:	75 ee                	jne    1213640 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x460>
 1213652:	44 0f b6 2d a6 f3 de 	movzbl -0x210c5a(%rip),%r13d        # 1002a00 <__anon_72634>
 1213659:	ff 
 121365a:	41 83 e5 3f          	and    $0x3f,%r13d
 121365e:	b8 ff 00 00 00       	mov    $0xff,%eax
 1213663:	c4 62 91 f7 c8       	shlx   %r13,%rax,%r9
 1213668:	4d 85 f9             	test   %r15,%r9
 121366b:	41 0f 94 c0          	sete   %r8b
 121366f:	4c 89 5d d0          	mov    %r11,-0x30(%rbp)
 1213673:	0f 84 d6 02 00 00    	je     121394f <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x76f>
 1213679:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 121367d:	c5 fc 11 45 a0       	vmovups %ymm0,-0x60(%rbp)
 1213682:	c5 fc 11 45 80       	vmovups %ymm0,-0x80(%rbp)
 1213687:	c5 fc 11 85 60 ff ff 	vmovups %ymm0,-0xa0(%rbp)
 121368e:	ff 
 121368f:	c5 fc 11 85 40 ff ff 	vmovups %ymm0,-0xc0(%rbp)
 1213696:	ff 
 1213697:	c5 fc 11 85 20 ff ff 	vmovups %ymm0,-0xe0(%rbp)
 121369e:	ff 
 121369f:	c5 fc 11 85 00 ff ff 	vmovups %ymm0,-0x100(%rbp)
 12136a6:	ff 
 12136a7:	c5 fc 11 85 e0 fe ff 	vmovups %ymm0,-0x120(%rbp)
 12136ae:	ff 
 12136af:	c5 fc 11 85 c0 fe ff 	vmovups %ymm0,-0x140(%rbp)
 12136b6:	ff 
 12136b7:	c5 fc 11 85 a0 fe ff 	vmovups %ymm0,-0x160(%rbp)
 12136be:	ff 
 12136bf:	c5 fc 11 85 80 fe ff 	vmovups %ymm0,-0x180(%rbp)
 12136c6:	ff 
 12136c7:	c5 fc 11 85 60 fe ff 	vmovups %ymm0,-0x1a0(%rbp)
 12136ce:	ff 
 12136cf:	c5 fc 11 85 40 fe ff 	vmovups %ymm0,-0x1c0(%rbp)
 12136d6:	ff 
 12136d7:	c5 fc 11 85 20 fe ff 	vmovups %ymm0,-0x1e0(%rbp)
 12136de:	ff 
 12136df:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 12136e6:	ff 
 12136e7:	c5 fc 11 85 e0 fd ff 	vmovups %ymm0,-0x220(%rbp)
 12136ee:	ff 
 12136ef:	c5 fc 11 85 c0 fd ff 	vmovups %ymm0,-0x240(%rbp)
 12136f6:	ff 
 12136f7:	44 89 d8             	mov    %r11d,%eax
 12136fa:	83 e0 03             	and    $0x3,%eax
 12136fd:	44 89 da             	mov    %r11d,%edx
 1213700:	81 e2 fc 01 00 00    	and    $0x1fc,%edx
 1213706:	48 8d 8d c0 f1 ff ff 	lea    -0xe40(%rbp),%rcx
 121370d:	0f 1f 00             	nopl   (%rax)
 1213710:	c4 e2 93 f7 31       	shrx   %r13,(%rcx),%rsi
 1213715:	40 0f b6 f6          	movzbl %sil,%esi
 1213719:	66 ff 84 75 c0 fd ff 	incw   -0x240(%rbp,%rsi,2)
 1213720:	ff 
 1213721:	c4 e2 93 f7 71 08    	shrx   %r13,0x8(%rcx),%rsi
 1213727:	40 0f b6 f6          	movzbl %sil,%esi
 121372b:	66 ff 84 75 c0 fd ff 	incw   -0x240(%rbp,%rsi,2)
 1213732:	ff 
 1213733:	c4 e2 93 f7 71 10    	shrx   %r13,0x10(%rcx),%rsi
 1213739:	40 0f b6 f6          	movzbl %sil,%esi
 121373d:	66 ff 84 75 c0 fd ff 	incw   -0x240(%rbp,%rsi,2)
 1213744:	ff 
 1213745:	c4 e2 93 f7 71 18    	shrx   %r13,0x18(%rcx),%rsi
 121374b:	40 0f b6 f6          	movzbl %sil,%esi
 121374f:	66 ff 84 75 c0 fd ff 	incw   -0x240(%rbp,%rsi,2)
 1213756:	ff 
 1213757:	48 83 c1 20          	add    $0x20,%rcx
 121375b:	48 83 c2 fc          	add    $0xfffffffffffffffc,%rdx
 121375f:	75 af                	jne    1213710 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x530>
 1213761:	4d 89 cc             	mov    %r9,%r12
 1213764:	45 89 c6             	mov    %r8d,%r14d
 1213767:	48 85 c0             	test   %rax,%rax
 121376a:	74 1d                	je     1213789 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x5a9>
 121376c:	0f 1f 40 00          	nopl   0x0(%rax)
 1213770:	c4 e2 93 f7 11       	shrx   %r13,(%rcx),%rdx
 1213775:	0f b6 d2             	movzbl %dl,%edx
 1213778:	66 ff 84 55 c0 fd ff 	incw   -0x240(%rbp,%rdx,2)
 121377f:	ff 
 1213780:	48 83 c1 08          	add    $0x8,%rcx
 1213784:	48 ff c8             	dec    %rax
 1213787:	75 e7                	jne    1213770 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x590>
 1213789:	48 8d bd c0 f9 ff ff 	lea    -0x640(%rbp),%rdi
 1213790:	48 8d b5 c0 fd ff ff 	lea    -0x240(%rbp),%rsi
 1213797:	ba 00 02 00 00       	mov    $0x200,%edx
 121379c:	c5 f8 77             	vzeroupper 
 121379f:	e8 8c 56 08 00       	call   1298e30 <compiler_rt.memcpy.memcpyFast>
 12137a4:	31 c0                	xor    %eax,%eax
 12137a6:	31 c9                	xor    %ecx,%ecx
 12137a8:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 12137af:	00 
 12137b0:	66 89 8c 45 c0 fb ff 	mov    %cx,-0x440(%rbp,%rax,2)
 12137b7:	ff 
 12137b8:	66 03 8c 45 c0 f9 ff 	add    -0x640(%rbp,%rax,2),%cx
 12137bf:	ff 
 12137c0:	66 89 8c 45 c2 fb ff 	mov    %cx,-0x43e(%rbp,%rax,2)
 12137c7:	ff 
 12137c8:	66 03 8c 45 c2 f9 ff 	add    -0x63e(%rbp,%rax,2),%cx
 12137cf:	ff 
 12137d0:	66 89 8c 45 c4 fb ff 	mov    %cx,-0x43c(%rbp,%rax,2)
 12137d7:	ff 
 12137d8:	66 03 8c 45 c4 f9 ff 	add    -0x63c(%rbp,%rax,2),%cx
 12137df:	ff 
 12137e0:	66 89 8c 45 c6 fb ff 	mov    %cx,-0x43a(%rbp,%rax,2)
 12137e7:	ff 
 12137e8:	66 03 8c 45 c6 f9 ff 	add    -0x63a(%rbp,%rax,2),%cx
 12137ef:	ff 
 12137f0:	66 89 8c 45 c8 fb ff 	mov    %cx,-0x438(%rbp,%rax,2)
 12137f7:	ff 
 12137f8:	66 03 8c 45 c8 f9 ff 	add    -0x638(%rbp,%rax,2),%cx
 12137ff:	ff 
 1213800:	66 89 8c 45 ca fb ff 	mov    %cx,-0x436(%rbp,%rax,2)
 1213807:	ff 
 1213808:	66 03 8c 45 ca f9 ff 	add    -0x636(%rbp,%rax,2),%cx
 121380f:	ff 
 1213810:	66 89 8c 45 cc fb ff 	mov    %cx,-0x434(%rbp,%rax,2)
 1213817:	ff 
 1213818:	66 03 8c 45 cc f9 ff 	add    -0x634(%rbp,%rax,2),%cx
 121381f:	ff 
 1213820:	66 89 8c 45 ce fb ff 	mov    %cx,-0x432(%rbp,%rax,2)
 1213827:	ff 
 1213828:	66 03 8c 45 ce f9 ff 	add    -0x632(%rbp,%rax,2),%cx
 121382f:	ff 
 1213830:	48 83 c0 08          	add    $0x8,%rax
 1213834:	48 3d 00 01 00 00    	cmp    $0x100,%rax
 121383a:	0f 85 70 ff ff ff    	jne    12137b0 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x5d0>
 1213840:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 1213844:	44 89 d8             	mov    %r11d,%eax
 1213847:	83 e0 03             	and    $0x3,%eax
 121384a:	44 89 da             	mov    %r11d,%edx
 121384d:	81 e2 fc 01 00 00    	and    $0x1fc,%edx
 1213853:	48 8d 8d c0 f1 ff ff 	lea    -0xe40(%rbp),%rcx
 121385a:	4d 89 e1             	mov    %r12,%r9
 121385d:	0f 1f 00             	nopl   (%rax)
 1213860:	48 8b 31             	mov    (%rcx),%rsi
 1213863:	c4 e2 93 f7 fe       	shrx   %r13,%rsi,%rdi
 1213868:	40 0f b6 ff          	movzbl %dil,%edi
 121386c:	44 0f b7 84 7d c0 fb 	movzwl -0x440(%rbp,%rdi,2),%r8d
 1213873:	ff ff 
 1213875:	4a 89 b4 c5 c0 e9 ff 	mov    %rsi,-0x1640(%rbp,%r8,8)
 121387c:	ff 
 121387d:	41 ff c0             	inc    %r8d
 1213880:	66 44 89 84 7d c0 fb 	mov    %r8w,-0x440(%rbp,%rdi,2)
 1213887:	ff ff 
 1213889:	48 8b 71 08          	mov    0x8(%rcx),%rsi
 121388d:	c4 e2 93 f7 fe       	shrx   %r13,%rsi,%rdi
 1213892:	40 0f b6 ff          	movzbl %dil,%edi
 1213896:	44 0f b7 84 7d c0 fb 	movzwl -0x440(%rbp,%rdi,2),%r8d
 121389d:	ff ff 
 121389f:	4a 89 b4 c5 c0 e9 ff 	mov    %rsi,-0x1640(%rbp,%r8,8)
 12138a6:	ff 
 12138a7:	41 ff c0             	inc    %r8d
 12138aa:	66 44 89 84 7d c0 fb 	mov    %r8w,-0x440(%rbp,%rdi,2)
 12138b1:	ff ff 
 12138b3:	48 8b 71 10          	mov    0x10(%rcx),%rsi
 12138b7:	c4 e2 93 f7 fe       	shrx   %r13,%rsi,%rdi
 12138bc:	40 0f b6 ff          	movzbl %dil,%edi
 12138c0:	44 0f b7 84 7d c0 fb 	movzwl -0x440(%rbp,%rdi,2),%r8d
 12138c7:	ff ff 
 12138c9:	4a 89 b4 c5 c0 e9 ff 	mov    %rsi,-0x1640(%rbp,%r8,8)
 12138d0:	ff 
 12138d1:	41 ff c0             	inc    %r8d
 12138d4:	66 44 89 84 7d c0 fb 	mov    %r8w,-0x440(%rbp,%rdi,2)
 12138db:	ff ff 
 12138dd:	48 8b 71 18          	mov    0x18(%rcx),%rsi
 12138e1:	c4 e2 93 f7 fe       	shrx   %r13,%rsi,%rdi
 12138e6:	40 0f b6 ff          	movzbl %dil,%edi
 12138ea:	44 0f b7 84 7d c0 fb 	movzwl -0x440(%rbp,%rdi,2),%r8d
 12138f1:	ff ff 
 12138f3:	4a 89 b4 c5 c0 e9 ff 	mov    %rsi,-0x1640(%rbp,%r8,8)
 12138fa:	ff 
 12138fb:	41 ff c0             	inc    %r8d
 12138fe:	66 44 89 84 7d c0 fb 	mov    %r8w,-0x440(%rbp,%rdi,2)
 1213905:	ff ff 
 1213907:	48 83 c1 20          	add    $0x20,%rcx
 121390b:	48 83 c2 fc          	add    $0xfffffffffffffffc,%rdx
 121390f:	0f 85 4b ff ff ff    	jne    1213860 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x680>
 1213915:	48 85 c0             	test   %rax,%rax
 1213918:	45 89 f0             	mov    %r14d,%r8d
 121391b:	74 32                	je     121394f <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x76f>
 121391d:	0f 1f 00             	nopl   (%rax)
 1213920:	48 8b 11             	mov    (%rcx),%rdx
 1213923:	c4 e2 93 f7 f2       	shrx   %r13,%rdx,%rsi
 1213928:	40 0f b6 f6          	movzbl %sil,%esi
 121392c:	0f b7 bc 75 c0 fb ff 	movzwl -0x440(%rbp,%rsi,2),%edi
 1213933:	ff 
 1213934:	48 89 94 fd c0 e9 ff 	mov    %rdx,-0x1640(%rbp,%rdi,8)
 121393b:	ff 
 121393c:	ff c7                	inc    %edi
 121393e:	66 89 bc 75 c0 fb ff 	mov    %di,-0x440(%rbp,%rsi,2)
 1213945:	ff 
 1213946:	48 83 c1 08          	add    $0x8,%rcx
 121394a:	48 ff c8             	dec    %rax
 121394d:	75 d1                	jne    1213920 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x740>
 121394f:	44 0f b6 2d aa f0 de 	movzbl -0x210f56(%rip),%r13d        # 1002a01 <__anon_72634+0x1>
 1213956:	ff 
 1213957:	41 83 e5 3f          	and    $0x3f,%r13d
 121395b:	c4 c2 93 f7 c7       	shrx   %r13,%r15,%rax
 1213960:	84 c0                	test   %al,%al
 1213962:	0f 84 d9 02 00 00    	je     1213c41 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0xa61>
 1213968:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 121396c:	c5 fc 11 45 a0       	vmovups %ymm0,-0x60(%rbp)
 1213971:	c5 fc 11 45 80       	vmovups %ymm0,-0x80(%rbp)
 1213976:	c5 fc 11 85 60 ff ff 	vmovups %ymm0,-0xa0(%rbp)
 121397d:	ff 
 121397e:	c5 fc 11 85 40 ff ff 	vmovups %ymm0,-0xc0(%rbp)
 1213985:	ff 
 1213986:	c5 fc 11 85 20 ff ff 	vmovups %ymm0,-0xe0(%rbp)
 121398d:	ff 
 121398e:	c5 fc 11 85 00 ff ff 	vmovups %ymm0,-0x100(%rbp)
 1213995:	ff 
 1213996:	c5 fc 11 85 e0 fe ff 	vmovups %ymm0,-0x120(%rbp)
 121399d:	ff 
 121399e:	c5 fc 11 85 c0 fe ff 	vmovups %ymm0,-0x140(%rbp)
 12139a5:	ff 
 12139a6:	c5 fc 11 85 a0 fe ff 	vmovups %ymm0,-0x160(%rbp)
 12139ad:	ff 
 12139ae:	c5 fc 11 85 80 fe ff 	vmovups %ymm0,-0x180(%rbp)
 12139b5:	ff 
 12139b6:	c5 fc 11 85 60 fe ff 	vmovups %ymm0,-0x1a0(%rbp)
 12139bd:	ff 
 12139be:	c5 fc 11 85 40 fe ff 	vmovups %ymm0,-0x1c0(%rbp)
 12139c5:	ff 
 12139c6:	c5 fc 11 85 20 fe ff 	vmovups %ymm0,-0x1e0(%rbp)
 12139cd:	ff 
 12139ce:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 12139d5:	ff 
 12139d6:	c5 fc 11 85 e0 fd ff 	vmovups %ymm0,-0x220(%rbp)
 12139dd:	ff 
 12139de:	c5 fc 11 85 c0 fd ff 	vmovups %ymm0,-0x240(%rbp)
 12139e5:	ff 
 12139e6:	4d 85 f9             	test   %r15,%r9
 12139e9:	4c 8d a5 c0 f1 ff ff 	lea    -0xe40(%rbp),%r12
 12139f0:	4c 8d b5 c0 e9 ff ff 	lea    -0x1640(%rbp),%r14
 12139f7:	4d 0f 44 f4          	cmove  %r12,%r14
 12139fb:	44 89 d8             	mov    %r11d,%eax
 12139fe:	83 e0 03             	and    $0x3,%eax
 1213a01:	44 89 da             	mov    %r11d,%edx
 1213a04:	81 e2 fc 01 00 00    	and    $0x1fc,%edx
 1213a0a:	4c 89 f1             	mov    %r14,%rcx
 1213a0d:	0f 1f 00             	nopl   (%rax)
 1213a10:	c4 e2 93 f7 31       	shrx   %r13,(%rcx),%rsi
 1213a15:	40 0f b6 f6          	movzbl %sil,%esi
 1213a19:	66 ff 84 75 c0 fd ff 	incw   -0x240(%rbp,%rsi,2)
 1213a20:	ff 
 1213a21:	c4 e2 93 f7 71 08    	shrx   %r13,0x8(%rcx),%rsi
 1213a27:	40 0f b6 f6          	movzbl %sil,%esi
 1213a2b:	66 ff 84 75 c0 fd ff 	incw   -0x240(%rbp,%rsi,2)
 1213a32:	ff 
 1213a33:	c4 e2 93 f7 71 10    	shrx   %r13,0x10(%rcx),%rsi
 1213a39:	40 0f b6 f6          	movzbl %sil,%esi
 1213a3d:	66 ff 84 75 c0 fd ff 	incw   -0x240(%rbp,%rsi,2)
 1213a44:	ff 
 1213a45:	c4 e2 93 f7 71 18    	shrx   %r13,0x18(%rcx),%rsi
 1213a4b:	40 0f b6 f6          	movzbl %sil,%esi
 1213a4f:	66 ff 84 75 c0 fd ff 	incw   -0x240(%rbp,%rsi,2)
 1213a56:	ff 
 1213a57:	48 83 c1 20          	add    $0x20,%rcx
 1213a5b:	48 83 c2 fc          	add    $0xfffffffffffffffc,%rdx
 1213a5f:	75 af                	jne    1213a10 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x830>
 1213a61:	4c 89 4d c8          	mov    %r9,-0x38(%rbp)
 1213a65:	48 85 c0             	test   %rax,%rax
 1213a68:	74 1f                	je     1213a89 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x8a9>
 1213a6a:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 1213a70:	c4 e2 93 f7 11       	shrx   %r13,(%rcx),%rdx
 1213a75:	0f b6 d2             	movzbl %dl,%edx
 1213a78:	66 ff 84 55 c0 fd ff 	incw   -0x240(%rbp,%rdx,2)
 1213a7f:	ff 
 1213a80:	48 83 c1 08          	add    $0x8,%rcx
 1213a84:	48 ff c8             	dec    %rax
 1213a87:	75 e7                	jne    1213a70 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x890>
 1213a89:	48 8d bd c0 f9 ff ff 	lea    -0x640(%rbp),%rdi
 1213a90:	48 8d b5 c0 fd ff ff 	lea    -0x240(%rbp),%rsi
 1213a97:	ba 00 02 00 00       	mov    $0x200,%edx
 1213a9c:	c5 f8 77             	vzeroupper 
 1213a9f:	e8 8c 53 08 00       	call   1298e30 <compiler_rt.memcpy.memcpyFast>
 1213aa4:	31 c0                	xor    %eax,%eax
 1213aa6:	31 c9                	xor    %ecx,%ecx
 1213aa8:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 1213aaf:	00 
 1213ab0:	66 89 8c 45 c0 fb ff 	mov    %cx,-0x440(%rbp,%rax,2)
 1213ab7:	ff 
 1213ab8:	66 03 8c 45 c0 f9 ff 	add    -0x640(%rbp,%rax,2),%cx
 1213abf:	ff 
 1213ac0:	66 89 8c 45 c2 fb ff 	mov    %cx,-0x43e(%rbp,%rax,2)
 1213ac7:	ff 
 1213ac8:	66 03 8c 45 c2 f9 ff 	add    -0x63e(%rbp,%rax,2),%cx
 1213acf:	ff 
 1213ad0:	66 89 8c 45 c4 fb ff 	mov    %cx,-0x43c(%rbp,%rax,2)
 1213ad7:	ff 
 1213ad8:	66 03 8c 45 c4 f9 ff 	add    -0x63c(%rbp,%rax,2),%cx
 1213adf:	ff 
 1213ae0:	66 89 8c 45 c6 fb ff 	mov    %cx,-0x43a(%rbp,%rax,2)
 1213ae7:	ff 
 1213ae8:	66 03 8c 45 c6 f9 ff 	add    -0x63a(%rbp,%rax,2),%cx
 1213aef:	ff 
 1213af0:	66 89 8c 45 c8 fb ff 	mov    %cx,-0x438(%rbp,%rax,2)
 1213af7:	ff 
 1213af8:	66 03 8c 45 c8 f9 ff 	add    -0x638(%rbp,%rax,2),%cx
 1213aff:	ff 
 1213b00:	66 89 8c 45 ca fb ff 	mov    %cx,-0x436(%rbp,%rax,2)
 1213b07:	ff 
 1213b08:	66 03 8c 45 ca f9 ff 	add    -0x636(%rbp,%rax,2),%cx
 1213b0f:	ff 
 1213b10:	66 89 8c 45 cc fb ff 	mov    %cx,-0x434(%rbp,%rax,2)
 1213b17:	ff 
 1213b18:	66 03 8c 45 cc f9 ff 	add    -0x634(%rbp,%rax,2),%cx
 1213b1f:	ff 
 1213b20:	66 89 8c 45 ce fb ff 	mov    %cx,-0x432(%rbp,%rax,2)
 1213b27:	ff 
 1213b28:	66 03 8c 45 ce f9 ff 	add    -0x632(%rbp,%rax,2),%cx
 1213b2f:	ff 
 1213b30:	48 83 c0 08          	add    $0x8,%rax
 1213b34:	48 3d 00 01 00 00    	cmp    $0x100,%rax
 1213b3a:	0f 85 70 ff ff ff    	jne    1213ab0 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x8d0>
 1213b40:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 1213b44:	4d 85 f8             	test   %r15,%r8
 1213b47:	48 8d 85 c0 e9 ff ff 	lea    -0x1640(%rbp),%rax
 1213b4e:	4c 0f 44 e0          	cmove  %rax,%r12
 1213b52:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 1213b56:	44 89 d8             	mov    %r11d,%eax
 1213b59:	83 e0 03             	and    $0x3,%eax
 1213b5c:	44 89 d9             	mov    %r11d,%ecx
 1213b5f:	81 e1 fc 01 00 00    	and    $0x1fc,%ecx
 1213b65:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 1213b6c:	00 00 00 00 
 1213b70:	49 8b 16             	mov    (%r14),%rdx
 1213b73:	c4 e2 93 f7 f2       	shrx   %r13,%rdx,%rsi
 1213b78:	40 0f b6 f6          	movzbl %sil,%esi
 1213b7c:	0f b7 bc 75 c0 fb ff 	movzwl -0x440(%rbp,%rsi,2),%edi
 1213b83:	ff 
 1213b84:	49 89 14 fc          	mov    %rdx,(%r12,%rdi,8)
 1213b88:	ff c7                	inc    %edi
 1213b8a:	66 89 bc 75 c0 fb ff 	mov    %di,-0x440(%rbp,%rsi,2)
 1213b91:	ff 
 1213b92:	49 8b 56 08          	mov    0x8(%r14),%rdx
 1213b96:	c4 e2 93 f7 f2       	shrx   %r13,%rdx,%rsi
 1213b9b:	40 0f b6 f6          	movzbl %sil,%esi
 1213b9f:	0f b7 bc 75 c0 fb ff 	movzwl -0x440(%rbp,%rsi,2),%edi
 1213ba6:	ff 
 1213ba7:	49 89 14 fc          	mov    %rdx,(%r12,%rdi,8)
 1213bab:	ff c7                	inc    %edi
 1213bad:	66 89 bc 75 c0 fb ff 	mov    %di,-0x440(%rbp,%rsi,2)
 1213bb4:	ff 
 1213bb5:	49 8b 56 10          	mov    0x10(%r14),%rdx
 1213bb9:	c4 e2 93 f7 f2       	shrx   %r13,%rdx,%rsi
 1213bbe:	40 0f b6 f6          	movzbl %sil,%esi
 1213bc2:	0f b7 bc 75 c0 fb ff 	movzwl -0x440(%rbp,%rsi,2),%edi
 1213bc9:	ff 
 1213bca:	49 89 14 fc          	mov    %rdx,(%r12,%rdi,8)
 1213bce:	ff c7                	inc    %edi
 1213bd0:	66 89 bc 75 c0 fb ff 	mov    %di,-0x440(%rbp,%rsi,2)
 1213bd7:	ff 
 1213bd8:	49 8b 56 18          	mov    0x18(%r14),%rdx
 1213bdc:	c4 e2 93 f7 f2       	shrx   %r13,%rdx,%rsi
 1213be1:	40 0f b6 f6          	movzbl %sil,%esi
 1213be5:	0f b7 bc 75 c0 fb ff 	movzwl -0x440(%rbp,%rsi,2),%edi
 1213bec:	ff 
 1213bed:	49 89 14 fc          	mov    %rdx,(%r12,%rdi,8)
 1213bf1:	ff c7                	inc    %edi
 1213bf3:	66 89 bc 75 c0 fb ff 	mov    %di,-0x440(%rbp,%rsi,2)
 1213bfa:	ff 
 1213bfb:	49 83 c6 20          	add    $0x20,%r14
 1213bff:	48 83 c1 fc          	add    $0xfffffffffffffffc,%rcx
 1213c03:	0f 85 67 ff ff ff    	jne    1213b70 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x990>
 1213c09:	48 85 c0             	test   %rax,%rax
 1213c0c:	74 2c                	je     1213c3a <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0xa5a>
 1213c0e:	66 90                	xchg   %ax,%ax
 1213c10:	49 8b 0e             	mov    (%r14),%rcx
 1213c13:	c4 e2 93 f7 d1       	shrx   %r13,%rcx,%rdx
 1213c18:	0f b6 d2             	movzbl %dl,%edx
 1213c1b:	0f b7 b4 55 c0 fb ff 	movzwl -0x440(%rbp,%rdx,2),%esi
 1213c22:	ff 
 1213c23:	49 89 0c f4          	mov    %rcx,(%r12,%rsi,8)
 1213c27:	ff c6                	inc    %esi
 1213c29:	66 89 b4 55 c0 fb ff 	mov    %si,-0x440(%rbp,%rdx,2)
 1213c30:	ff 
 1213c31:	49 83 c6 08          	add    $0x8,%r14
 1213c35:	48 ff c8             	dec    %rax
 1213c38:	75 d6                	jne    1213c10 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0xa30>
 1213c3a:	4d 85 f8             	test   %r15,%r8
 1213c3d:	41 0f 95 c0          	setne  %r8b
 1213c41:	44 0f b6 2d b9 ed de 	movzbl -0x211247(%rip),%r13d        # 1002a02 <__anon_72634+0x2>
 1213c48:	ff 
 1213c49:	41 83 e5 3f          	and    $0x3f,%r13d
 1213c4d:	c4 c2 93 f7 c7       	shrx   %r13,%r15,%rax
 1213c52:	84 c0                	test   %al,%al
 1213c54:	0f 84 d4 02 00 00    	je     1213f2e <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0xd4e>
 1213c5a:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1213c5e:	c5 fc 11 45 a0       	vmovups %ymm0,-0x60(%rbp)
 1213c63:	c5 fc 11 45 80       	vmovups %ymm0,-0x80(%rbp)
 1213c68:	c5 fc 11 85 60 ff ff 	vmovups %ymm0,-0xa0(%rbp)
 1213c6f:	ff 
 1213c70:	c5 fc 11 85 40 ff ff 	vmovups %ymm0,-0xc0(%rbp)
 1213c77:	ff 
 1213c78:	c5 fc 11 85 20 ff ff 	vmovups %ymm0,-0xe0(%rbp)
 1213c7f:	ff 
 1213c80:	c5 fc 11 85 00 ff ff 	vmovups %ymm0,-0x100(%rbp)
 1213c87:	ff 
 1213c88:	c5 fc 11 85 e0 fe ff 	vmovups %ymm0,-0x120(%rbp)
 1213c8f:	ff 
 1213c90:	c5 fc 11 85 c0 fe ff 	vmovups %ymm0,-0x140(%rbp)
 1213c97:	ff 
 1213c98:	c5 fc 11 85 a0 fe ff 	vmovups %ymm0,-0x160(%rbp)
 1213c9f:	ff 
 1213ca0:	c5 fc 11 85 80 fe ff 	vmovups %ymm0,-0x180(%rbp)
 1213ca7:	ff 
 1213ca8:	c5 fc 11 85 60 fe ff 	vmovups %ymm0,-0x1a0(%rbp)
 1213caf:	ff 
 1213cb0:	c5 fc 11 85 40 fe ff 	vmovups %ymm0,-0x1c0(%rbp)
 1213cb7:	ff 
 1213cb8:	c5 fc 11 85 20 fe ff 	vmovups %ymm0,-0x1e0(%rbp)
 1213cbf:	ff 
 1213cc0:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 1213cc7:	ff 
 1213cc8:	c5 fc 11 85 e0 fd ff 	vmovups %ymm0,-0x220(%rbp)
 1213ccf:	ff 
 1213cd0:	c5 fc 11 85 c0 fd ff 	vmovups %ymm0,-0x240(%rbp)
 1213cd7:	ff 
 1213cd8:	45 84 c0             	test   %r8b,%r8b
 1213cdb:	4c 8d a5 c0 f1 ff ff 	lea    -0xe40(%rbp),%r12
 1213ce2:	4c 8d b5 c0 e9 ff ff 	lea    -0x1640(%rbp),%r14
 1213ce9:	4d 0f 45 f4          	cmovne %r12,%r14
 1213ced:	44 89 d8             	mov    %r11d,%eax
 1213cf0:	83 e0 03             	and    $0x3,%eax
 1213cf3:	44 89 da             	mov    %r11d,%edx
 1213cf6:	81 e2 fc 01 00 00    	and    $0x1fc,%edx
 1213cfc:	4c 89 f1             	mov    %r14,%rcx
 1213cff:	90                   	nop
 1213d00:	c4 e2 93 f7 31       	shrx   %r13,(%rcx),%rsi
 1213d05:	40 0f b6 f6          	movzbl %sil,%esi
 1213d09:	66 ff 84 75 c0 fd ff 	incw   -0x240(%rbp,%rsi,2)
 1213d10:	ff 
 1213d11:	c4 e2 93 f7 71 08    	shrx   %r13,0x8(%rcx),%rsi
 1213d17:	40 0f b6 f6          	movzbl %sil,%esi
 1213d1b:	66 ff 84 75 c0 fd ff 	incw   -0x240(%rbp,%rsi,2)
 1213d22:	ff 
 1213d23:	c4 e2 93 f7 71 10    	shrx   %r13,0x10(%rcx),%rsi
 1213d29:	40 0f b6 f6          	movzbl %sil,%esi
 1213d2d:	66 ff 84 75 c0 fd ff 	incw   -0x240(%rbp,%rsi,2)
 1213d34:	ff 
 1213d35:	c4 e2 93 f7 71 18    	shrx   %r13,0x18(%rcx),%rsi
 1213d3b:	40 0f b6 f6          	movzbl %sil,%esi
 1213d3f:	66 ff 84 75 c0 fd ff 	incw   -0x240(%rbp,%rsi,2)
 1213d46:	ff 
 1213d47:	48 83 c1 20          	add    $0x20,%rcx
 1213d4b:	48 83 c2 fc          	add    $0xfffffffffffffffc,%rdx
 1213d4f:	75 af                	jne    1213d00 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0xb20>
 1213d51:	44 88 45 c8          	mov    %r8b,-0x38(%rbp)
 1213d55:	48 85 c0             	test   %rax,%rax
 1213d58:	74 1f                	je     1213d79 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0xb99>
 1213d5a:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 1213d60:	c4 e2 93 f7 11       	shrx   %r13,(%rcx),%rdx
 1213d65:	0f b6 d2             	movzbl %dl,%edx
 1213d68:	66 ff 84 55 c0 fd ff 	incw   -0x240(%rbp,%rdx,2)
 1213d6f:	ff 
 1213d70:	48 83 c1 08          	add    $0x8,%rcx
 1213d74:	48 ff c8             	dec    %rax
 1213d77:	75 e7                	jne    1213d60 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0xb80>
 1213d79:	48 8d bd c0 f9 ff ff 	lea    -0x640(%rbp),%rdi
 1213d80:	48 8d b5 c0 fd ff ff 	lea    -0x240(%rbp),%rsi
 1213d87:	ba 00 02 00 00       	mov    $0x200,%edx
 1213d8c:	c5 f8 77             	vzeroupper 
 1213d8f:	e8 9c 50 08 00       	call   1298e30 <compiler_rt.memcpy.memcpyFast>
 1213d94:	31 c0                	xor    %eax,%eax
 1213d96:	31 c9                	xor    %ecx,%ecx
 1213d98:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 1213d9f:	00 
 1213da0:	66 89 8c 45 c0 fb ff 	mov    %cx,-0x440(%rbp,%rax,2)
 1213da7:	ff 
 1213da8:	66 03 8c 45 c0 f9 ff 	add    -0x640(%rbp,%rax,2),%cx
 1213daf:	ff 
 1213db0:	66 89 8c 45 c2 fb ff 	mov    %cx,-0x43e(%rbp,%rax,2)
 1213db7:	ff 
 1213db8:	66 03 8c 45 c2 f9 ff 	add    -0x63e(%rbp,%rax,2),%cx
 1213dbf:	ff 
 1213dc0:	66 89 8c 45 c4 fb ff 	mov    %cx,-0x43c(%rbp,%rax,2)
 1213dc7:	ff 
 1213dc8:	66 03 8c 45 c4 f9 ff 	add    -0x63c(%rbp,%rax,2),%cx
 1213dcf:	ff 
 1213dd0:	66 89 8c 45 c6 fb ff 	mov    %cx,-0x43a(%rbp,%rax,2)
 1213dd7:	ff 
 1213dd8:	66 03 8c 45 c6 f9 ff 	add    -0x63a(%rbp,%rax,2),%cx
 1213ddf:	ff 
 1213de0:	66 89 8c 45 c8 fb ff 	mov    %cx,-0x438(%rbp,%rax,2)
 1213de7:	ff 
 1213de8:	66 03 8c 45 c8 f9 ff 	add    -0x638(%rbp,%rax,2),%cx
 1213def:	ff 
 1213df0:	66 89 8c 45 ca fb ff 	mov    %cx,-0x436(%rbp,%rax,2)
 1213df7:	ff 
 1213df8:	66 03 8c 45 ca f9 ff 	add    -0x636(%rbp,%rax,2),%cx
 1213dff:	ff 
 1213e00:	66 89 8c 45 cc fb ff 	mov    %cx,-0x434(%rbp,%rax,2)
 1213e07:	ff 
 1213e08:	66 03 8c 45 cc f9 ff 	add    -0x634(%rbp,%rax,2),%cx
 1213e0f:	ff 
 1213e10:	66 89 8c 45 ce fb ff 	mov    %cx,-0x432(%rbp,%rax,2)
 1213e17:	ff 
 1213e18:	66 03 8c 45 ce f9 ff 	add    -0x632(%rbp,%rax,2),%cx
 1213e1f:	ff 
 1213e20:	48 83 c0 08          	add    $0x8,%rax
 1213e24:	48 3d 00 01 00 00    	cmp    $0x100,%rax
 1213e2a:	0f 85 70 ff ff ff    	jne    1213da0 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0xbc0>
 1213e30:	44 0f b6 45 c8       	movzbl -0x38(%rbp),%r8d
 1213e35:	45 84 c0             	test   %r8b,%r8b
 1213e38:	48 8d 85 c0 e9 ff ff 	lea    -0x1640(%rbp),%rax
 1213e3f:	4c 0f 45 e0          	cmovne %rax,%r12
 1213e43:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 1213e47:	44 89 d8             	mov    %r11d,%eax
 1213e4a:	83 e0 03             	and    $0x3,%eax
 1213e4d:	44 89 d9             	mov    %r11d,%ecx
 1213e50:	81 e1 fc 01 00 00    	and    $0x1fc,%ecx
 1213e56:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 1213e5d:	00 00 00 
 1213e60:	49 8b 16             	mov    (%r14),%rdx
 1213e63:	c4 e2 93 f7 f2       	shrx   %r13,%rdx,%rsi
 1213e68:	40 0f b6 f6          	movzbl %sil,%esi
 1213e6c:	0f b7 bc 75 c0 fb ff 	movzwl -0x440(%rbp,%rsi,2),%edi
 1213e73:	ff 
 1213e74:	49 89 14 fc          	mov    %rdx,(%r12,%rdi,8)
 1213e78:	ff c7                	inc    %edi
 1213e7a:	66 89 bc 75 c0 fb ff 	mov    %di,-0x440(%rbp,%rsi,2)
 1213e81:	ff 
 1213e82:	49 8b 56 08          	mov    0x8(%r14),%rdx
 1213e86:	c4 e2 93 f7 f2       	shrx   %r13,%rdx,%rsi
 1213e8b:	40 0f b6 f6          	movzbl %sil,%esi
 1213e8f:	0f b7 bc 75 c0 fb ff 	movzwl -0x440(%rbp,%rsi,2),%edi
 1213e96:	ff 
 1213e97:	49 89 14 fc          	mov    %rdx,(%r12,%rdi,8)
 1213e9b:	ff c7                	inc    %edi
 1213e9d:	66 89 bc 75 c0 fb ff 	mov    %di,-0x440(%rbp,%rsi,2)
 1213ea4:	ff 
 1213ea5:	49 8b 56 10          	mov    0x10(%r14),%rdx
 1213ea9:	c4 e2 93 f7 f2       	shrx   %r13,%rdx,%rsi
 1213eae:	40 0f b6 f6          	movzbl %sil,%esi
 1213eb2:	0f b7 bc 75 c0 fb ff 	movzwl -0x440(%rbp,%rsi,2),%edi
 1213eb9:	ff 
 1213eba:	49 89 14 fc          	mov    %rdx,(%r12,%rdi,8)
 1213ebe:	ff c7                	inc    %edi
 1213ec0:	66 89 bc 75 c0 fb ff 	mov    %di,-0x440(%rbp,%rsi,2)
 1213ec7:	ff 
 1213ec8:	49 8b 56 18          	mov    0x18(%r14),%rdx
 1213ecc:	c4 e2 93 f7 f2       	shrx   %r13,%rdx,%rsi
 1213ed1:	40 0f b6 f6          	movzbl %sil,%esi
 1213ed5:	0f b7 bc 75 c0 fb ff 	movzwl -0x440(%rbp,%rsi,2),%edi
 1213edc:	ff 
 1213edd:	49 89 14 fc          	mov    %rdx,(%r12,%rdi,8)
 1213ee1:	ff c7                	inc    %edi
 1213ee3:	66 89 bc 75 c0 fb ff 	mov    %di,-0x440(%rbp,%rsi,2)
 1213eea:	ff 
 1213eeb:	49 83 c6 20          	add    $0x20,%r14
 1213eef:	48 83 c1 fc          	add    $0xfffffffffffffffc,%rcx
 1213ef3:	0f 85 67 ff ff ff    	jne    1213e60 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0xc80>
 1213ef9:	48 85 c0             	test   %rax,%rax
 1213efc:	74 2c                	je     1213f2a <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0xd4a>
 1213efe:	66 90                	xchg   %ax,%ax
 1213f00:	49 8b 0e             	mov    (%r14),%rcx
 1213f03:	c4 e2 93 f7 d1       	shrx   %r13,%rcx,%rdx
 1213f08:	0f b6 d2             	movzbl %dl,%edx
 1213f0b:	0f b7 b4 55 c0 fb ff 	movzwl -0x440(%rbp,%rdx,2),%esi
 1213f12:	ff 
 1213f13:	49 89 0c f4          	mov    %rcx,(%r12,%rsi,8)
 1213f17:	ff c6                	inc    %esi
 1213f19:	66 89 b4 55 c0 fb ff 	mov    %si,-0x440(%rbp,%rdx,2)
 1213f20:	ff 
 1213f21:	49 83 c6 08          	add    $0x8,%r14
 1213f25:	48 ff c8             	dec    %rax
 1213f28:	75 d6                	jne    1213f00 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0xd20>
 1213f2a:	41 80 f0 01          	xor    $0x1,%r8b
 1213f2e:	44 0f b6 2d cd ea de 	movzbl -0x211533(%rip),%r13d        # 1002a03 <__anon_72634+0x3>
 1213f35:	ff 
 1213f36:	41 83 e5 3f          	and    $0x3f,%r13d
 1213f3a:	c4 c2 93 f7 c7       	shrx   %r13,%r15,%rax
 1213f3f:	84 c0                	test   %al,%al
 1213f41:	0f 84 b6 03 00 00    	je     12142fd <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x111d>
 1213f47:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1213f4b:	c5 fc 11 45 a0       	vmovups %ymm0,-0x60(%rbp)
 1213f50:	c5 fc 11 45 80       	vmovups %ymm0,-0x80(%rbp)
 1213f55:	c5 fc 11 85 60 ff ff 	vmovups %ymm0,-0xa0(%rbp)
 1213f5c:	ff 
 1213f5d:	c5 fc 11 85 40 ff ff 	vmovups %ymm0,-0xc0(%rbp)
 1213f64:	ff 
 1213f65:	c5 fc 11 85 20 ff ff 	vmovups %ymm0,-0xe0(%rbp)
 1213f6c:	ff 
 1213f6d:	c5 fc 11 85 00 ff ff 	vmovups %ymm0,-0x100(%rbp)
 1213f74:	ff 
 1213f75:	c5 fc 11 85 e0 fe ff 	vmovups %ymm0,-0x120(%rbp)
 1213f7c:	ff 
 1213f7d:	c5 fc 11 85 c0 fe ff 	vmovups %ymm0,-0x140(%rbp)
 1213f84:	ff 
 1213f85:	c5 fc 11 85 a0 fe ff 	vmovups %ymm0,-0x160(%rbp)
 1213f8c:	ff 
 1213f8d:	c5 fc 11 85 80 fe ff 	vmovups %ymm0,-0x180(%rbp)
 1213f94:	ff 
 1213f95:	c5 fc 11 85 60 fe ff 	vmovups %ymm0,-0x1a0(%rbp)
 1213f9c:	ff 
 1213f9d:	c5 fc 11 85 40 fe ff 	vmovups %ymm0,-0x1c0(%rbp)
 1213fa4:	ff 
 1213fa5:	c5 fc 11 85 20 fe ff 	vmovups %ymm0,-0x1e0(%rbp)
 1213fac:	ff 
 1213fad:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 1213fb4:	ff 
 1213fb5:	c5 fc 11 85 e0 fd ff 	vmovups %ymm0,-0x220(%rbp)
 1213fbc:	ff 
 1213fbd:	c5 fc 11 85 c0 fd ff 	vmovups %ymm0,-0x240(%rbp)
 1213fc4:	ff 
 1213fc5:	45 84 c0             	test   %r8b,%r8b
 1213fc8:	4c 8d bd c0 f1 ff ff 	lea    -0xe40(%rbp),%r15
 1213fcf:	4c 8d b5 c0 e9 ff ff 	lea    -0x1640(%rbp),%r14
 1213fd6:	4d 0f 45 f7          	cmovne %r15,%r14
 1213fda:	44 89 d8             	mov    %r11d,%eax
 1213fdd:	83 e0 03             	and    $0x3,%eax
 1213fe0:	44 89 da             	mov    %r11d,%edx
 1213fe3:	81 e2 fc 01 00 00    	and    $0x1fc,%edx
 1213fe9:	4c 89 f1             	mov    %r14,%rcx
 1213fec:	0f 1f 40 00          	nopl   0x0(%rax)
 1213ff0:	c4 e2 93 f7 31       	shrx   %r13,(%rcx),%rsi
 1213ff5:	40 0f b6 f6          	movzbl %sil,%esi
 1213ff9:	66 ff 84 75 c0 fd ff 	incw   -0x240(%rbp,%rsi,2)
 1214000:	ff 
 1214001:	c4 e2 93 f7 71 08    	shrx   %r13,0x8(%rcx),%rsi
 1214007:	40 0f b6 f6          	movzbl %sil,%esi
 121400b:	66 ff 84 75 c0 fd ff 	incw   -0x240(%rbp,%rsi,2)
 1214012:	ff 
 1214013:	c4 e2 93 f7 71 10    	shrx   %r13,0x10(%rcx),%rsi
 1214019:	40 0f b6 f6          	movzbl %sil,%esi
 121401d:	66 ff 84 75 c0 fd ff 	incw   -0x240(%rbp,%rsi,2)
 1214024:	ff 
 1214025:	c4 e2 93 f7 71 18    	shrx   %r13,0x18(%rcx),%rsi
 121402b:	40 0f b6 f6          	movzbl %sil,%esi
 121402f:	66 ff 84 75 c0 fd ff 	incw   -0x240(%rbp,%rsi,2)
 1214036:	ff 
 1214037:	48 83 c1 20          	add    $0x20,%rcx
 121403b:	48 83 c2 fc          	add    $0xfffffffffffffffc,%rdx
 121403f:	75 af                	jne    1213ff0 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0xe10>
 1214041:	45 89 c4             	mov    %r8d,%r12d
 1214044:	48 85 c0             	test   %rax,%rax
 1214047:	74 20                	je     1214069 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0xe89>
 1214049:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)
 1214050:	c4 e2 93 f7 11       	shrx   %r13,(%rcx),%rdx
 1214055:	0f b6 d2             	movzbl %dl,%edx
 1214058:	66 ff 84 55 c0 fd ff 	incw   -0x240(%rbp,%rdx,2)
 121405f:	ff 
 1214060:	48 83 c1 08          	add    $0x8,%rcx
 1214064:	48 ff c8             	dec    %rax
 1214067:	75 e7                	jne    1214050 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0xe70>
 1214069:	48 8d bd c0 f9 ff ff 	lea    -0x640(%rbp),%rdi
 1214070:	48 8d b5 c0 fd ff ff 	lea    -0x240(%rbp),%rsi
 1214077:	ba 00 02 00 00       	mov    $0x200,%edx
 121407c:	c5 f8 77             	vzeroupper 
 121407f:	e8 ac 4d 08 00       	call   1298e30 <compiler_rt.memcpy.memcpyFast>
 1214084:	31 c0                	xor    %eax,%eax
 1214086:	31 c9                	xor    %ecx,%ecx
 1214088:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 121408f:	00 
 1214090:	66 89 8c 45 c0 fb ff 	mov    %cx,-0x440(%rbp,%rax,2)
 1214097:	ff 
 1214098:	66 03 8c 45 c0 f9 ff 	add    -0x640(%rbp,%rax,2),%cx
 121409f:	ff 
 12140a0:	66 89 8c 45 c2 fb ff 	mov    %cx,-0x43e(%rbp,%rax,2)
 12140a7:	ff 
 12140a8:	66 03 8c 45 c2 f9 ff 	add    -0x63e(%rbp,%rax,2),%cx
 12140af:	ff 
 12140b0:	66 89 8c 45 c4 fb ff 	mov    %cx,-0x43c(%rbp,%rax,2)
 12140b7:	ff 
 12140b8:	66 03 8c 45 c4 f9 ff 	add    -0x63c(%rbp,%rax,2),%cx
 12140bf:	ff 
 12140c0:	66 89 8c 45 c6 fb ff 	mov    %cx,-0x43a(%rbp,%rax,2)
 12140c7:	ff 
 12140c8:	66 03 8c 45 c6 f9 ff 	add    -0x63a(%rbp,%rax,2),%cx
 12140cf:	ff 
 12140d0:	66 89 8c 45 c8 fb ff 	mov    %cx,-0x438(%rbp,%rax,2)
 12140d7:	ff 
 12140d8:	66 03 8c 45 c8 f9 ff 	add    -0x638(%rbp,%rax,2),%cx
 12140df:	ff 
 12140e0:	66 89 8c 45 ca fb ff 	mov    %cx,-0x436(%rbp,%rax,2)
 12140e7:	ff 
 12140e8:	66 03 8c 45 ca f9 ff 	add    -0x636(%rbp,%rax,2),%cx
 12140ef:	ff 
 12140f0:	66 89 8c 45 cc fb ff 	mov    %cx,-0x434(%rbp,%rax,2)
 12140f7:	ff 
 12140f8:	66 03 8c 45 cc f9 ff 	add    -0x634(%rbp,%rax,2),%cx
 12140ff:	ff 
 1214100:	66 89 8c 45 ce fb ff 	mov    %cx,-0x432(%rbp,%rax,2)
 1214107:	ff 
 1214108:	66 03 8c 45 ce f9 ff 	add    -0x632(%rbp,%rax,2),%cx
 121410f:	ff 
 1214110:	48 83 c0 08          	add    $0x8,%rax
 1214114:	48 3d 00 01 00 00    	cmp    $0x100,%rax
 121411a:	0f 85 70 ff ff ff    	jne    1214090 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0xeb0>
 1214120:	45 84 e4             	test   %r12b,%r12b
 1214123:	48 8d 85 c0 e9 ff ff 	lea    -0x1640(%rbp),%rax
 121412a:	4c 0f 45 f8          	cmovne %rax,%r15
 121412e:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 1214132:	44 89 d8             	mov    %r11d,%eax
 1214135:	83 e0 03             	and    $0x3,%eax
 1214138:	44 89 d9             	mov    %r11d,%ecx
 121413b:	81 e1 fc 01 00 00    	and    $0x1fc,%ecx
 1214141:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1214148:	0f 1f 84 00 00 00 00 
 121414f:	00 
 1214150:	49 8b 16             	mov    (%r14),%rdx
 1214153:	c4 e2 93 f7 f2       	shrx   %r13,%rdx,%rsi
 1214158:	40 0f b6 f6          	movzbl %sil,%esi
 121415c:	0f b7 bc 75 c0 fb ff 	movzwl -0x440(%rbp,%rsi,2),%edi
 1214163:	ff 
 1214164:	49 89 14 ff          	mov    %rdx,(%r15,%rdi,8)
 1214168:	ff c7                	inc    %edi
 121416a:	66 89 bc 75 c0 fb ff 	mov    %di,-0x440(%rbp,%rsi,2)
 1214171:	ff 
 1214172:	49 8b 56 08          	mov    0x8(%r14),%rdx
 1214176:	c4 e2 93 f7 f2       	shrx   %r13,%rdx,%rsi
 121417b:	40 0f b6 f6          	movzbl %sil,%esi
 121417f:	0f b7 bc 75 c0 fb ff 	movzwl -0x440(%rbp,%rsi,2),%edi
 1214186:	ff 
 1214187:	49 89 14 ff          	mov    %rdx,(%r15,%rdi,8)
 121418b:	ff c7                	inc    %edi
 121418d:	66 89 bc 75 c0 fb ff 	mov    %di,-0x440(%rbp,%rsi,2)
 1214194:	ff 
 1214195:	49 8b 56 10          	mov    0x10(%r14),%rdx
 1214199:	c4 e2 93 f7 f2       	shrx   %r13,%rdx,%rsi
 121419e:	40 0f b6 f6          	movzbl %sil,%esi
 12141a2:	0f b7 bc 75 c0 fb ff 	movzwl -0x440(%rbp,%rsi,2),%edi
 12141a9:	ff 
 12141aa:	49 89 14 ff          	mov    %rdx,(%r15,%rdi,8)
 12141ae:	ff c7                	inc    %edi
 12141b0:	66 89 bc 75 c0 fb ff 	mov    %di,-0x440(%rbp,%rsi,2)
 12141b7:	ff 
 12141b8:	49 8b 56 18          	mov    0x18(%r14),%rdx
 12141bc:	c4 e2 93 f7 f2       	shrx   %r13,%rdx,%rsi
 12141c1:	40 0f b6 f6          	movzbl %sil,%esi
 12141c5:	0f b7 bc 75 c0 fb ff 	movzwl -0x440(%rbp,%rsi,2),%edi
 12141cc:	ff 
 12141cd:	49 89 14 ff          	mov    %rdx,(%r15,%rdi,8)
 12141d1:	ff c7                	inc    %edi
 12141d3:	66 89 bc 75 c0 fb ff 	mov    %di,-0x440(%rbp,%rsi,2)
 12141da:	ff 
 12141db:	49 83 c6 20          	add    $0x20,%r14
 12141df:	48 83 c1 fc          	add    $0xfffffffffffffffc,%rcx
 12141e3:	0f 85 67 ff ff ff    	jne    1214150 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0xf70>
 12141e9:	48 85 c0             	test   %rax,%rax
 12141ec:	74 2c                	je     121421a <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x103a>
 12141ee:	66 90                	xchg   %ax,%ax
 12141f0:	49 8b 0e             	mov    (%r14),%rcx
 12141f3:	c4 e2 93 f7 d1       	shrx   %r13,%rcx,%rdx
 12141f8:	0f b6 d2             	movzbl %dl,%edx
 12141fb:	0f b7 b4 55 c0 fb ff 	movzwl -0x440(%rbp,%rdx,2),%esi
 1214202:	ff 
 1214203:	49 89 0c f7          	mov    %rcx,(%r15,%rsi,8)
 1214207:	ff c6                	inc    %esi
 1214209:	66 89 b4 55 c0 fb ff 	mov    %si,-0x440(%rbp,%rdx,2)
 1214210:	ff 
 1214211:	49 83 c6 08          	add    $0x8,%r14
 1214215:	48 ff c8             	dec    %rax
 1214218:	75 d6                	jne    12141f0 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x1010>
 121421a:	45 84 e4             	test   %r12b,%r12b
 121421d:	74 1f                	je     121423e <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x105e>
 121421f:	42 8d 14 dd 00 00 00 	lea    0x0(,%r11,8),%edx
 1214226:	00 
 1214227:	48 8d bd c0 f1 ff ff 	lea    -0xe40(%rbp),%rdi
 121422e:	48 8d b5 c0 e9 ff ff 	lea    -0x1640(%rbp),%rsi
 1214235:	e8 f6 4b 08 00       	call   1298e30 <compiler_rt.memcpy.memcpyFast>
 121423a:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 121423e:	44 89 d8             	mov    %r11d,%eax
 1214241:	83 e0 07             	and    $0x7,%eax
 1214244:	43 8d 14 1b          	lea    (%r11,%r11,1),%edx
 1214248:	81 e2 f0 03 00 00    	and    $0x3f0,%edx
 121424e:	31 c9                	xor    %ecx,%ecx
 1214250:	0f b6 b4 8d c0 f1 ff 	movzbl -0xe40(%rbp,%rcx,4),%esi
 1214257:	ff 
 1214258:	66 89 74 0b 08       	mov    %si,0x8(%rbx,%rcx,1)
 121425d:	0f b6 b4 8d c8 f1 ff 	movzbl -0xe38(%rbp,%rcx,4),%esi
 1214264:	ff 
 1214265:	66 89 74 0b 0a       	mov    %si,0xa(%rbx,%rcx,1)
 121426a:	0f b6 b4 8d d0 f1 ff 	movzbl -0xe30(%rbp,%rcx,4),%esi
 1214271:	ff 
 1214272:	66 89 74 0b 0c       	mov    %si,0xc(%rbx,%rcx,1)
 1214277:	0f b6 b4 8d d8 f1 ff 	movzbl -0xe28(%rbp,%rcx,4),%esi
 121427e:	ff 
 121427f:	66 89 74 0b 0e       	mov    %si,0xe(%rbx,%rcx,1)
 1214284:	0f b6 b4 8d e0 f1 ff 	movzbl -0xe20(%rbp,%rcx,4),%esi
 121428b:	ff 
 121428c:	66 89 74 0b 10       	mov    %si,0x10(%rbx,%rcx,1)
 1214291:	0f b6 b4 8d e8 f1 ff 	movzbl -0xe18(%rbp,%rcx,4),%esi
 1214298:	ff 
 1214299:	66 89 74 0b 12       	mov    %si,0x12(%rbx,%rcx,1)
 121429e:	0f b6 b4 8d f0 f1 ff 	movzbl -0xe10(%rbp,%rcx,4),%esi
 12142a5:	ff 
 12142a6:	66 89 74 0b 14       	mov    %si,0x14(%rbx,%rcx,1)
 12142ab:	0f b6 b4 8d f8 f1 ff 	movzbl -0xe08(%rbp,%rcx,4),%esi
 12142b2:	ff 
 12142b3:	66 89 74 0b 16       	mov    %si,0x16(%rbx,%rcx,1)
 12142b8:	48 83 c1 10          	add    $0x10,%rcx
 12142bc:	48 39 ca             	cmp    %rcx,%rdx
 12142bf:	75 8f                	jne    1214250 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x1070>
 12142c1:	48 85 c0             	test   %rax,%rax
 12142c4:	74 20                	je     12142e6 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x1106>
 12142c6:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 12142cd:	00 00 00 
 12142d0:	0f b6 94 8d c0 f1 ff 	movzbl -0xe40(%rbp,%rcx,4),%edx
 12142d7:	ff 
 12142d8:	66 89 54 0b 08       	mov    %dx,0x8(%rbx,%rcx,1)
 12142dd:	48 83 c1 02          	add    $0x2,%rcx
 12142e1:	48 ff c8             	dec    %rax
 12142e4:	75 ea                	jne    12142d0 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x10f0>
 12142e6:	4c 89 1b             	mov    %r11,(%rbx)
 12142e9:	31 c0                	xor    %eax,%eax
 12142eb:	48 81 c4 18 16 00 00 	add    $0x1618,%rsp
 12142f2:	5b                   	pop    %rbx
 12142f3:	41 5c                	pop    %r12
 12142f5:	41 5d                	pop    %r13
 12142f7:	41 5e                	pop    %r14
 12142f9:	41 5f                	pop    %r15
 12142fb:	5d                   	pop    %rbp
 12142fc:	c3                   	ret    
 12142fd:	45 84 c0             	test   %r8b,%r8b
 1214300:	0f 84 19 ff ff ff    	je     121421f <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x103f>
 1214306:	e9 33 ff ff ff       	jmp    121423e <br.encoder.literal_alphabet.buildLargeSupport__anon_72625+0x105e>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
