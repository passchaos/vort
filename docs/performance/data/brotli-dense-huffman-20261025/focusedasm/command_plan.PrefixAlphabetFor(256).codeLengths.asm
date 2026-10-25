
/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/7cab685de62cdb93856431f8e3ddb813/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

0000000001175220 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths>:
 1175220:	55                   	push   %rbp
 1175221:	48 89 e5             	mov    %rsp,%rbp
 1175224:	41 57                	push   %r15
 1175226:	41 56                	push   %r14
 1175228:	41 55                	push   %r13
 117522a:	41 54                	push   %r12
 117522c:	53                   	push   %rbx
 117522d:	48 81 ec 88 06 00 00 	sub    $0x688,%rsp
 1175234:	48 8b 1e             	mov    (%rsi),%rbx
 1175237:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 117523b:	48 85 db             	test   %rbx,%rbx
 117523e:	74 75                	je     11752b5 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x95>
 1175240:	c5 fc 11 45 b0       	vmovups %ymm0,-0x50(%rbp)
 1175245:	c5 fc 11 45 90       	vmovups %ymm0,-0x70(%rbp)
 117524a:	c5 fc 11 85 70 ff ff 	vmovups %ymm0,-0x90(%rbp)
 1175251:	ff 
 1175252:	c5 fc 11 85 50 ff ff 	vmovups %ymm0,-0xb0(%rbp)
 1175259:	ff 
 117525a:	c5 fc 11 85 30 ff ff 	vmovups %ymm0,-0xd0(%rbp)
 1175261:	ff 
 1175262:	c5 fc 11 85 10 ff ff 	vmovups %ymm0,-0xf0(%rbp)
 1175269:	ff 
 117526a:	c5 fc 11 85 f0 fe ff 	vmovups %ymm0,-0x110(%rbp)
 1175271:	ff 
 1175272:	c5 fc 11 85 d0 fe ff 	vmovups %ymm0,-0x130(%rbp)
 1175279:	ff 
 117527a:	4c 8d 63 ff          	lea    -0x1(%rbx),%r12
 117527e:	49 83 fc 03          	cmp    $0x3,%r12
 1175282:	0f 87 43 01 00 00    	ja     11753cb <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x1ab>
 1175288:	48 8d 05 39 4a e9 ff 	lea    -0x16b5c7(%rip),%rax        # 1009cc8 <__anon_240407+0x7268>
 117528f:	4a 63 0c a0          	movslq (%rax,%r12,4),%rcx
 1175293:	48 01 c1             	add    %rax,%rcx
 1175296:	ff e1                	jmp    *%rcx
 1175298:	0f b7 46 08          	movzwl 0x8(%rsi),%eax
 117529c:	c6 84 05 d0 fe ff ff 	movb   $0x1,-0x130(%rbp,%rax,1)
 11752a3:	01 
 11752a4:	0f b7 46 0a          	movzwl 0xa(%rsi),%eax
 11752a8:	c6 84 05 d0 fe ff ff 	movb   $0x1,-0x130(%rbp,%rax,1)
 11752af:	01 
 11752b0:	e9 8e 00 00 00       	jmp    1175343 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x123>
 11752b5:	c5 fc 11 45 b0       	vmovups %ymm0,-0x50(%rbp)
 11752ba:	c5 fc 11 45 90       	vmovups %ymm0,-0x70(%rbp)
 11752bf:	c5 fc 11 85 70 ff ff 	vmovups %ymm0,-0x90(%rbp)
 11752c6:	ff 
 11752c7:	c5 fc 11 85 50 ff ff 	vmovups %ymm0,-0xb0(%rbp)
 11752ce:	ff 
 11752cf:	c5 fc 11 85 30 ff ff 	vmovups %ymm0,-0xd0(%rbp)
 11752d6:	ff 
 11752d7:	c5 fc 11 85 10 ff ff 	vmovups %ymm0,-0xf0(%rbp)
 11752de:	ff 
 11752df:	c5 fc 11 85 f0 fe ff 	vmovups %ymm0,-0x110(%rbp)
 11752e6:	ff 
 11752e7:	c5 fc 11 85 d0 fe ff 	vmovups %ymm0,-0x130(%rbp)
 11752ee:	ff 
 11752ef:	66 b9 1f 00          	mov    $0x1f,%cx
 11752f3:	eb 50                	jmp    1175345 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x125>
 11752f5:	0f b7 46 08          	movzwl 0x8(%rsi),%eax
 11752f9:	c6 84 05 d0 fe ff ff 	movb   $0x1,-0x130(%rbp,%rax,1)
 1175300:	01 
 1175301:	0f b7 46 0a          	movzwl 0xa(%rsi),%eax
 1175305:	c6 84 05 d0 fe ff ff 	movb   $0x2,-0x130(%rbp,%rax,1)
 117530c:	02 
 117530d:	0f b7 46 0c          	movzwl 0xc(%rsi),%eax
 1175311:	eb 28                	jmp    117533b <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x11b>
 1175313:	0f b7 46 08          	movzwl 0x8(%rsi),%eax
 1175317:	c6 84 05 d0 fe ff ff 	movb   $0x2,-0x130(%rbp,%rax,1)
 117531e:	02 
 117531f:	0f b7 46 0a          	movzwl 0xa(%rsi),%eax
 1175323:	c6 84 05 d0 fe ff ff 	movb   $0x2,-0x130(%rbp,%rax,1)
 117532a:	02 
 117532b:	0f b7 46 0c          	movzwl 0xc(%rsi),%eax
 117532f:	c6 84 05 d0 fe ff ff 	movb   $0x2,-0x130(%rbp,%rax,1)
 1175336:	02 
 1175337:	0f b7 46 0e          	movzwl 0xe(%rsi),%eax
 117533b:	c6 84 05 d0 fe ff ff 	movb   $0x2,-0x130(%rbp,%rax,1)
 1175342:	02 
 1175343:	31 c9                	xor    %ecx,%ecx
 1175345:	66 89 0f             	mov    %cx,(%rdi)
 1175348:	c5 fc 10 85 d0 fe ff 	vmovups -0x130(%rbp),%ymm0
 117534f:	ff 
 1175350:	c5 fc 10 8d f0 fe ff 	vmovups -0x110(%rbp),%ymm1
 1175357:	ff 
 1175358:	c5 fc 10 95 10 ff ff 	vmovups -0xf0(%rbp),%ymm2
 117535f:	ff 
 1175360:	c5 fc 10 9d 30 ff ff 	vmovups -0xd0(%rbp),%ymm3
 1175367:	ff 
 1175368:	c5 fc 11 47 02       	vmovups %ymm0,0x2(%rdi)
 117536d:	c5 fc 11 4f 22       	vmovups %ymm1,0x22(%rdi)
 1175372:	c5 fc 11 57 42       	vmovups %ymm2,0x42(%rdi)
 1175377:	c5 fc 11 5f 62       	vmovups %ymm3,0x62(%rdi)
 117537c:	c5 fc 10 85 50 ff ff 	vmovups -0xb0(%rbp),%ymm0
 1175383:	ff 
 1175384:	c5 fc 11 87 82 00 00 	vmovups %ymm0,0x82(%rdi)
 117538b:	00 
 117538c:	c5 fc 10 85 70 ff ff 	vmovups -0x90(%rbp),%ymm0
 1175393:	ff 
 1175394:	c5 fc 11 87 a2 00 00 	vmovups %ymm0,0xa2(%rdi)
 117539b:	00 
 117539c:	c5 fc 10 45 90       	vmovups -0x70(%rbp),%ymm0
 11753a1:	c5 fc 11 87 c2 00 00 	vmovups %ymm0,0xc2(%rdi)
 11753a8:	00 
 11753a9:	c5 fc 10 45 b0       	vmovups -0x50(%rbp),%ymm0
 11753ae:	c5 fc 11 87 e2 00 00 	vmovups %ymm0,0xe2(%rdi)
 11753b5:	00 
 11753b6:	48 81 c4 88 06 00 00 	add    $0x688,%rsp
 11753bd:	5b                   	pop    %rbx
 11753be:	41 5c                	pop    %r12
 11753c0:	41 5d                	pop    %r13
 11753c2:	41 5e                	pop    %r14
 11753c4:	41 5f                	pop    %r15
 11753c6:	5d                   	pop    %rbp
 11753c7:	c5 f8 77             	vzeroupper 
 11753ca:	c3                   	ret    
 11753cb:	48 83 fb 40          	cmp    $0x40,%rbx
 11753cf:	77 12                	ja     11753e3 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x1c3>
 11753d1:	89 d8                	mov    %ebx,%eax
 11753d3:	83 e0 07             	and    $0x7,%eax
 11753d6:	49 83 fc 07          	cmp    $0x7,%r12
 11753da:	73 2a                	jae    1175406 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x1e6>
 11753dc:	31 c9                	xor    %ecx,%ecx
 11753de:	e9 ca 00 00 00       	jmp    11754ad <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x28d>
 11753e3:	48 81 fb 81 00 00 00 	cmp    $0x81,%rbx
 11753ea:	0f 83 31 01 00 00    	jae    1175521 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x301>
 11753f0:	89 d8                	mov    %ebx,%eax
 11753f2:	83 e0 07             	and    $0x7,%eax
 11753f5:	49 83 fc 07          	cmp    $0x7,%r12
 11753f9:	0f 83 a5 01 00 00    	jae    11755a4 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x384>
 11753ff:	31 c9                	xor    %ecx,%ecx
 1175401:	e9 47 02 00 00       	jmp    117564d <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x42d>
 1175406:	41 89 d8             	mov    %ebx,%r8d
 1175409:	41 83 e0 78          	and    $0x78,%r8d
 117540d:	31 c9                	xor    %ecx,%ecx
 117540f:	90                   	nop
 1175410:	44 0f b7 4c 4e 08    	movzwl 0x8(%rsi,%rcx,2),%r9d
 1175416:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 117541a:	44 89 8c 8d 50 fd ff 	mov    %r9d,-0x2b0(%rbp,%rcx,4)
 1175421:	ff 
 1175422:	44 0f b7 4c 4e 0a    	movzwl 0xa(%rsi,%rcx,2),%r9d
 1175428:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 117542c:	44 89 8c 8d 54 fd ff 	mov    %r9d,-0x2ac(%rbp,%rcx,4)
 1175433:	ff 
 1175434:	44 0f b7 4c 4e 0c    	movzwl 0xc(%rsi,%rcx,2),%r9d
 117543a:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 117543e:	44 89 8c 8d 58 fd ff 	mov    %r9d,-0x2a8(%rbp,%rcx,4)
 1175445:	ff 
 1175446:	44 0f b7 4c 4e 0e    	movzwl 0xe(%rsi,%rcx,2),%r9d
 117544c:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 1175450:	44 89 8c 8d 5c fd ff 	mov    %r9d,-0x2a4(%rbp,%rcx,4)
 1175457:	ff 
 1175458:	44 0f b7 4c 4e 10    	movzwl 0x10(%rsi,%rcx,2),%r9d
 117545e:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 1175462:	44 89 8c 8d 60 fd ff 	mov    %r9d,-0x2a0(%rbp,%rcx,4)
 1175469:	ff 
 117546a:	44 0f b7 4c 4e 12    	movzwl 0x12(%rsi,%rcx,2),%r9d
 1175470:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 1175474:	44 89 8c 8d 64 fd ff 	mov    %r9d,-0x29c(%rbp,%rcx,4)
 117547b:	ff 
 117547c:	44 0f b7 4c 4e 14    	movzwl 0x14(%rsi,%rcx,2),%r9d
 1175482:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 1175486:	44 89 8c 8d 68 fd ff 	mov    %r9d,-0x298(%rbp,%rcx,4)
 117548d:	ff 
 117548e:	44 0f b7 4c 4e 16    	movzwl 0x16(%rsi,%rcx,2),%r9d
 1175494:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 1175498:	44 89 8c 8d 6c fd ff 	mov    %r9d,-0x294(%rbp,%rcx,4)
 117549f:	ff 
 11754a0:	48 83 c1 08          	add    $0x8,%rcx
 11754a4:	49 39 c8             	cmp    %rcx,%r8
 11754a7:	0f 85 63 ff ff ff    	jne    1175410 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x1f0>
 11754ad:	49 89 fe             	mov    %rdi,%r14
 11754b0:	48 85 c0             	test   %rax,%rax
 11754b3:	74 30                	je     11754e5 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x2c5>
 11754b5:	48 8d 3c 8d 50 fd ff 	lea    -0x2b0(,%rcx,4),%rdi
 11754bc:	ff 
 11754bd:	48 01 ef             	add    %rbp,%rdi
 11754c0:	48 8d 0c 4e          	lea    (%rsi,%rcx,2),%rcx
 11754c4:	48 83 c1 08          	add    $0x8,%rcx
 11754c8:	45 31 c0             	xor    %r8d,%r8d
 11754cb:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 11754d0:	46 0f b7 0c 41       	movzwl (%rcx,%r8,2),%r9d
 11754d5:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 11754d9:	46 89 0c 87          	mov    %r9d,(%rdi,%r8,4)
 11754dd:	49 ff c0             	inc    %r8
 11754e0:	4c 39 c0             	cmp    %r8,%rax
 11754e3:	75 eb                	jne    11754d0 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x2b0>
 11754e5:	49 89 d5             	mov    %rdx,%r13
 11754e8:	49 89 f7             	mov    %rsi,%r15
 11754eb:	48 8d bd 50 fd ff ff 	lea    -0x2b0(%rbp),%rdi
 11754f2:	48 8d 95 90 fe ff ff 	lea    -0x170(%rbp),%rdx
 11754f9:	48 89 de             	mov    %rbx,%rsi
 11754fc:	c5 f8 77             	vzeroupper 
 11754ff:	e8 5c 5f 04 00       	call   11bb460 <br.encoder.small_huffman.build__anon_35926>
 1175504:	a8 01                	test   $0x1,%al
 1175506:	74 3c                	je     1175544 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x324>
 1175508:	89 d8                	mov    %ebx,%eax
 117550a:	83 e0 07             	and    $0x7,%eax
 117550d:	49 83 fc 07          	cmp    $0x7,%r12
 1175511:	4c 89 f7             	mov    %r14,%rdi
 1175514:	0f 83 ab 01 00 00    	jae    11756c5 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x4a5>
 117551a:	31 c9                	xor    %ecx,%ecx
 117551c:	e9 8d 02 00 00       	jmp    11757ae <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x58e>
 1175521:	48 81 fb 01 01 00 00 	cmp    $0x101,%rbx
 1175528:	0f 83 c7 02 00 00    	jae    11757f5 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x5d5>
 117552e:	89 d8                	mov    %ebx,%eax
 1175530:	83 e0 07             	and    $0x7,%eax
 1175533:	49 83 fc 07          	cmp    $0x7,%r12
 1175537:	0f 83 26 05 00 00    	jae    1175a63 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x843>
 117553d:	31 c9                	xor    %ecx,%ecx
 117553f:	e9 c9 05 00 00       	jmp    1175b0d <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x8ed>
 1175544:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1175548:	c5 fc 11 85 30 fa ff 	vmovups %ymm0,-0x5d0(%rbp)
 117554f:	ff 
 1175550:	c5 fc 11 85 10 fa ff 	vmovups %ymm0,-0x5f0(%rbp)
 1175557:	ff 
 1175558:	c5 fc 11 85 f0 f9 ff 	vmovups %ymm0,-0x610(%rbp)
 117555f:	ff 
 1175560:	c5 fc 11 85 d0 f9 ff 	vmovups %ymm0,-0x630(%rbp)
 1175567:	ff 
 1175568:	c5 fc 11 85 b0 f9 ff 	vmovups %ymm0,-0x650(%rbp)
 117556f:	ff 
 1175570:	c5 fc 11 85 90 f9 ff 	vmovups %ymm0,-0x670(%rbp)
 1175577:	ff 
 1175578:	c5 fc 11 85 70 f9 ff 	vmovups %ymm0,-0x690(%rbp)
 117557f:	ff 
 1175580:	c5 fc 11 85 50 f9 ff 	vmovups %ymm0,-0x6b0(%rbp)
 1175587:	ff 
 1175588:	89 d8                	mov    %ebx,%eax
 117558a:	83 e0 07             	and    $0x7,%eax
 117558d:	49 83 fc 07          	cmp    $0x7,%r12
 1175591:	0f 83 81 02 00 00    	jae    1175818 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x5f8>
 1175597:	31 d2                	xor    %edx,%edx
 1175599:	4c 89 fe             	mov    %r15,%rsi
 117559c:	4c 89 e9             	mov    %r13,%rcx
 117559f:	e9 11 03 00 00       	jmp    11758b5 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x695>
 11755a4:	41 89 d8             	mov    %ebx,%r8d
 11755a7:	41 81 e0 f8 00 00 00 	and    $0xf8,%r8d
 11755ae:	31 c9                	xor    %ecx,%ecx
 11755b0:	44 0f b7 4c 4e 08    	movzwl 0x8(%rsi,%rcx,2),%r9d
 11755b6:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 11755ba:	44 89 8c 8d 50 f9 ff 	mov    %r9d,-0x6b0(%rbp,%rcx,4)
 11755c1:	ff 
 11755c2:	44 0f b7 4c 4e 0a    	movzwl 0xa(%rsi,%rcx,2),%r9d
 11755c8:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 11755cc:	44 89 8c 8d 54 f9 ff 	mov    %r9d,-0x6ac(%rbp,%rcx,4)
 11755d3:	ff 
 11755d4:	44 0f b7 4c 4e 0c    	movzwl 0xc(%rsi,%rcx,2),%r9d
 11755da:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 11755de:	44 89 8c 8d 58 f9 ff 	mov    %r9d,-0x6a8(%rbp,%rcx,4)
 11755e5:	ff 
 11755e6:	44 0f b7 4c 4e 0e    	movzwl 0xe(%rsi,%rcx,2),%r9d
 11755ec:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 11755f0:	44 89 8c 8d 5c f9 ff 	mov    %r9d,-0x6a4(%rbp,%rcx,4)
 11755f7:	ff 
 11755f8:	44 0f b7 4c 4e 10    	movzwl 0x10(%rsi,%rcx,2),%r9d
 11755fe:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 1175602:	44 89 8c 8d 60 f9 ff 	mov    %r9d,-0x6a0(%rbp,%rcx,4)
 1175609:	ff 
 117560a:	44 0f b7 4c 4e 12    	movzwl 0x12(%rsi,%rcx,2),%r9d
 1175610:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 1175614:	44 89 8c 8d 64 f9 ff 	mov    %r9d,-0x69c(%rbp,%rcx,4)
 117561b:	ff 
 117561c:	44 0f b7 4c 4e 14    	movzwl 0x14(%rsi,%rcx,2),%r9d
 1175622:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 1175626:	44 89 8c 8d 68 f9 ff 	mov    %r9d,-0x698(%rbp,%rcx,4)
 117562d:	ff 
 117562e:	44 0f b7 4c 4e 16    	movzwl 0x16(%rsi,%rcx,2),%r9d
 1175634:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 1175638:	44 89 8c 8d 6c f9 ff 	mov    %r9d,-0x694(%rbp,%rcx,4)
 117563f:	ff 
 1175640:	48 83 c1 08          	add    $0x8,%rcx
 1175644:	49 39 c8             	cmp    %rcx,%r8
 1175647:	0f 85 63 ff ff ff    	jne    11755b0 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x390>
 117564d:	49 89 fd             	mov    %rdi,%r13
 1175650:	48 85 c0             	test   %rax,%rax
 1175653:	74 30                	je     1175685 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x465>
 1175655:	48 8d 3c 8d 50 f9 ff 	lea    -0x6b0(,%rcx,4),%rdi
 117565c:	ff 
 117565d:	48 01 ef             	add    %rbp,%rdi
 1175660:	48 8d 0c 4e          	lea    (%rsi,%rcx,2),%rcx
 1175664:	48 83 c1 08          	add    $0x8,%rcx
 1175668:	45 31 c0             	xor    %r8d,%r8d
 117566b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 1175670:	46 0f b7 0c 41       	movzwl (%rcx,%r8,2),%r9d
 1175675:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 1175679:	46 89 0c 87          	mov    %r9d,(%rdi,%r8,4)
 117567d:	49 ff c0             	inc    %r8
 1175680:	4c 39 c0             	cmp    %r8,%rax
 1175683:	75 eb                	jne    1175670 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x450>
 1175685:	49 89 d7             	mov    %rdx,%r15
 1175688:	49 89 f6             	mov    %rsi,%r14
 117568b:	48 8d bd 50 f9 ff ff 	lea    -0x6b0(%rbp),%rdi
 1175692:	48 8d 95 50 fd ff ff 	lea    -0x2b0(%rbp),%rdx
 1175699:	48 89 de             	mov    %rbx,%rsi
 117569c:	c5 f8 77             	vzeroupper 
 117569f:	e8 dc 58 04 00       	call   11baf80 <br.encoder.small_huffman.build__anon_35942>
 11756a4:	a8 01                	test   $0x1,%al
 11756a6:	0f 84 d5 04 00 00    	je     1175b81 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x961>
 11756ac:	89 d8                	mov    %ebx,%eax
 11756ae:	83 e0 07             	and    $0x7,%eax
 11756b1:	49 83 fc 07          	cmp    $0x7,%r12
 11756b5:	0f 83 e2 04 00 00    	jae    1175b9d <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x97d>
 11756bb:	31 c9                	xor    %ecx,%ecx
 11756bd:	4c 89 ef             	mov    %r13,%rdi
 11756c0:	e9 c9 05 00 00       	jmp    1175c8e <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0xa6e>
 11756c5:	83 e3 78             	and    $0x78,%ebx
 11756c8:	31 c9                	xor    %ecx,%ecx
 11756ca:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 11756d0:	41 0f b7 54 4f 08    	movzwl 0x8(%r15,%rcx,2),%edx
 11756d6:	0f b6 b4 0d 90 fe ff 	movzbl -0x170(%rbp,%rcx,1),%esi
 11756dd:	ff 
 11756de:	44 0f b6 84 0d 91 fe 	movzbl -0x16f(%rbp,%rcx,1),%r8d
 11756e5:	ff ff 
 11756e7:	40 80 e6 0f          	and    $0xf,%sil
 11756eb:	40 88 b4 15 d0 fe ff 	mov    %sil,-0x130(%rbp,%rdx,1)
 11756f2:	ff 
 11756f3:	41 0f b7 54 4f 0a    	movzwl 0xa(%r15,%rcx,2),%edx
 11756f9:	41 80 e0 0f          	and    $0xf,%r8b
 11756fd:	44 88 84 15 d0 fe ff 	mov    %r8b,-0x130(%rbp,%rdx,1)
 1175704:	ff 
 1175705:	41 0f b7 54 4f 0c    	movzwl 0xc(%r15,%rcx,2),%edx
 117570b:	0f b6 b4 0d 92 fe ff 	movzbl -0x16e(%rbp,%rcx,1),%esi
 1175712:	ff 
 1175713:	40 80 e6 0f          	and    $0xf,%sil
 1175717:	40 88 b4 15 d0 fe ff 	mov    %sil,-0x130(%rbp,%rdx,1)
 117571e:	ff 
 117571f:	41 0f b7 54 4f 0e    	movzwl 0xe(%r15,%rcx,2),%edx
 1175725:	0f b6 b4 0d 93 fe ff 	movzbl -0x16d(%rbp,%rcx,1),%esi
 117572c:	ff 
 117572d:	40 80 e6 0f          	and    $0xf,%sil
 1175731:	40 88 b4 15 d0 fe ff 	mov    %sil,-0x130(%rbp,%rdx,1)
 1175738:	ff 
 1175739:	41 0f b7 54 4f 10    	movzwl 0x10(%r15,%rcx,2),%edx
 117573f:	0f b6 b4 0d 94 fe ff 	movzbl -0x16c(%rbp,%rcx,1),%esi
 1175746:	ff 
 1175747:	40 80 e6 0f          	and    $0xf,%sil
 117574b:	40 88 b4 15 d0 fe ff 	mov    %sil,-0x130(%rbp,%rdx,1)
 1175752:	ff 
 1175753:	41 0f b7 54 4f 12    	movzwl 0x12(%r15,%rcx,2),%edx
 1175759:	0f b6 b4 0d 95 fe ff 	movzbl -0x16b(%rbp,%rcx,1),%esi
 1175760:	ff 
 1175761:	40 80 e6 0f          	and    $0xf,%sil
 1175765:	40 88 b4 15 d0 fe ff 	mov    %sil,-0x130(%rbp,%rdx,1)
 117576c:	ff 
 117576d:	41 0f b7 54 4f 14    	movzwl 0x14(%r15,%rcx,2),%edx
 1175773:	0f b6 b4 0d 96 fe ff 	movzbl -0x16a(%rbp,%rcx,1),%esi
 117577a:	ff 
 117577b:	40 80 e6 0f          	and    $0xf,%sil
 117577f:	40 88 b4 15 d0 fe ff 	mov    %sil,-0x130(%rbp,%rdx,1)
 1175786:	ff 
 1175787:	41 0f b7 54 4f 16    	movzwl 0x16(%r15,%rcx,2),%edx
 117578d:	0f b6 b4 0d 97 fe ff 	movzbl -0x169(%rbp,%rcx,1),%esi
 1175794:	ff 
 1175795:	40 80 e6 0f          	and    $0xf,%sil
 1175799:	40 88 b4 15 d0 fe ff 	mov    %sil,-0x130(%rbp,%rdx,1)
 11757a0:	ff 
 11757a1:	48 83 c1 08          	add    $0x8,%rcx
 11757a5:	48 39 cb             	cmp    %rcx,%rbx
 11757a8:	0f 85 22 ff ff ff    	jne    11756d0 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x4b0>
 11757ae:	48 85 c0             	test   %rax,%rax
 11757b1:	0f 84 8c fb ff ff    	je     1175343 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x123>
 11757b7:	48 8d 14 29          	lea    (%rcx,%rbp,1),%rdx
 11757bb:	48 81 c2 90 fe ff ff 	add    $0xfffffffffffffe90,%rdx
 11757c2:	49 8d 34 4f          	lea    (%r15,%rcx,2),%rsi
 11757c6:	48 83 c6 08          	add    $0x8,%rsi
 11757ca:	45 31 c0             	xor    %r8d,%r8d
 11757cd:	0f 1f 00             	nopl   (%rax)
 11757d0:	42 0f b7 0c 46       	movzwl (%rsi,%r8,2),%ecx
 11757d5:	46 0f b6 0c 02       	movzbl (%rdx,%r8,1),%r9d
 11757da:	41 80 e1 0f          	and    $0xf,%r9b
 11757de:	44 88 8c 0d d0 fe ff 	mov    %r9b,-0x130(%rbp,%rcx,1)
 11757e5:	ff 
 11757e6:	49 ff c0             	inc    %r8
 11757e9:	31 c9                	xor    %ecx,%ecx
 11757eb:	4c 39 c0             	cmp    %r8,%rax
 11757ee:	75 e0                	jne    11757d0 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x5b0>
 11757f0:	e9 50 fb ff ff       	jmp    1175345 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x125>
 11757f5:	48 8d 85 d0 fe ff ff 	lea    -0x130(%rbp),%rax
 11757fc:	48 89 fb             	mov    %rdi,%rbx
 11757ff:	48 89 f7             	mov    %rsi,%rdi
 1175802:	48 89 d6             	mov    %rdx,%rsi
 1175805:	48 89 c2             	mov    %rax,%rdx
 1175808:	c5 f8 77             	vzeroupper 
 117580b:	e8 10 4d 04 00       	call   11ba520 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35946>
 1175810:	48 89 df             	mov    %rbx,%rdi
 1175813:	e9 2b fb ff ff       	jmp    1175343 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x123>
 1175818:	83 e3 78             	and    $0x78,%ebx
 117581b:	31 d2                	xor    %edx,%edx
 117581d:	4c 89 fe             	mov    %r15,%rsi
 1175820:	4c 89 e9             	mov    %r13,%rcx
 1175823:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 117582a:	84 00 00 00 00 00 
 1175830:	0f b7 7c 56 08       	movzwl 0x8(%rsi,%rdx,2),%edi
 1175835:	8b 3c b9             	mov    (%rcx,%rdi,4),%edi
 1175838:	89 bc 95 50 f9 ff ff 	mov    %edi,-0x6b0(%rbp,%rdx,4)
 117583f:	0f b7 7c 56 0a       	movzwl 0xa(%rsi,%rdx,2),%edi
 1175844:	8b 3c b9             	mov    (%rcx,%rdi,4),%edi
 1175847:	89 bc 95 54 f9 ff ff 	mov    %edi,-0x6ac(%rbp,%rdx,4)
 117584e:	0f b7 7c 56 0c       	movzwl 0xc(%rsi,%rdx,2),%edi
 1175853:	8b 3c b9             	mov    (%rcx,%rdi,4),%edi
 1175856:	89 bc 95 58 f9 ff ff 	mov    %edi,-0x6a8(%rbp,%rdx,4)
 117585d:	0f b7 7c 56 0e       	movzwl 0xe(%rsi,%rdx,2),%edi
 1175862:	8b 3c b9             	mov    (%rcx,%rdi,4),%edi
 1175865:	89 bc 95 5c f9 ff ff 	mov    %edi,-0x6a4(%rbp,%rdx,4)
 117586c:	0f b7 7c 56 10       	movzwl 0x10(%rsi,%rdx,2),%edi
 1175871:	8b 3c b9             	mov    (%rcx,%rdi,4),%edi
 1175874:	89 bc 95 60 f9 ff ff 	mov    %edi,-0x6a0(%rbp,%rdx,4)
 117587b:	0f b7 7c 56 12       	movzwl 0x12(%rsi,%rdx,2),%edi
 1175880:	8b 3c b9             	mov    (%rcx,%rdi,4),%edi
 1175883:	89 bc 95 64 f9 ff ff 	mov    %edi,-0x69c(%rbp,%rdx,4)
 117588a:	0f b7 7c 56 14       	movzwl 0x14(%rsi,%rdx,2),%edi
 117588f:	8b 3c b9             	mov    (%rcx,%rdi,4),%edi
 1175892:	89 bc 95 68 f9 ff ff 	mov    %edi,-0x698(%rbp,%rdx,4)
 1175899:	0f b7 7c 56 16       	movzwl 0x16(%rsi,%rdx,2),%edi
 117589e:	8b 3c b9             	mov    (%rcx,%rdi,4),%edi
 11758a1:	89 bc 95 6c f9 ff ff 	mov    %edi,-0x694(%rbp,%rdx,4)
 11758a8:	48 83 c2 08          	add    $0x8,%rdx
 11758ac:	48 39 d3             	cmp    %rdx,%rbx
 11758af:	0f 85 7b ff ff ff    	jne    1175830 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x610>
 11758b5:	48 85 c0             	test   %rax,%rax
 11758b8:	74 2b                	je     11758e5 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x6c5>
 11758ba:	48 8d 3c 95 50 f9 ff 	lea    -0x6b0(,%rdx,4),%rdi
 11758c1:	ff 
 11758c2:	48 01 ef             	add    %rbp,%rdi
 11758c5:	48 8d 14 56          	lea    (%rsi,%rdx,2),%rdx
 11758c9:	48 83 c2 08          	add    $0x8,%rdx
 11758cd:	31 f6                	xor    %esi,%esi
 11758cf:	90                   	nop
 11758d0:	44 0f b7 04 72       	movzwl (%rdx,%rsi,2),%r8d
 11758d5:	46 8b 04 81          	mov    (%rcx,%r8,4),%r8d
 11758d9:	44 89 04 b7          	mov    %r8d,(%rdi,%rsi,4)
 11758dd:	48 ff c6             	inc    %rsi
 11758e0:	48 39 f0             	cmp    %rsi,%rax
 11758e3:	75 eb                	jne    11758d0 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x6b0>
 11758e5:	48 8d bd 50 fe ff ff 	lea    -0x1b0(%rbp),%rdi
 11758ec:	48 8d b5 50 f9 ff ff 	lea    -0x6b0(%rbp),%rsi
 11758f3:	ba 0f 00 00 00       	mov    $0xf,%edx
 11758f8:	c5 f8 77             	vzeroupper 
 11758fb:	e8 e0 2e 03 00       	call   11a87e0 <huffman.treeCodeLengths__anon_41185>
 1175900:	49 8b 0f             	mov    (%r15),%rcx
 1175903:	48 85 c9             	test   %rcx,%rcx
 1175906:	4c 89 f7             	mov    %r14,%rdi
 1175909:	0f 84 34 fa ff ff    	je     1175343 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x123>
 117590f:	89 c8                	mov    %ecx,%eax
 1175911:	83 e0 07             	and    $0x7,%eax
 1175914:	48 83 f9 08          	cmp    $0x8,%rcx
 1175918:	73 07                	jae    1175921 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x701>
 117591a:	31 d2                	xor    %edx,%edx
 117591c:	e9 f4 00 00 00       	jmp    1175a15 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x7f5>
 1175921:	48 83 e1 f8          	and    $0xfffffffffffffff8,%rcx
 1175925:	31 d2                	xor    %edx,%edx
 1175927:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 117592e:	00 00 
 1175930:	41 0f b7 74 57 08    	movzwl 0x8(%r15,%rdx,2),%esi
 1175936:	44 0f b6 84 15 50 fe 	movzbl -0x1b0(%rbp,%rdx,1),%r8d
 117593d:	ff ff 
 117593f:	44 0f b6 8c 15 51 fe 	movzbl -0x1af(%rbp,%rdx,1),%r9d
 1175946:	ff ff 
 1175948:	41 80 e0 0f          	and    $0xf,%r8b
 117594c:	44 88 84 35 d0 fe ff 	mov    %r8b,-0x130(%rbp,%rsi,1)
 1175953:	ff 
 1175954:	41 0f b7 74 57 0a    	movzwl 0xa(%r15,%rdx,2),%esi
 117595a:	41 80 e1 0f          	and    $0xf,%r9b
 117595e:	44 88 8c 35 d0 fe ff 	mov    %r9b,-0x130(%rbp,%rsi,1)
 1175965:	ff 
 1175966:	41 0f b7 74 57 0c    	movzwl 0xc(%r15,%rdx,2),%esi
 117596c:	44 0f b6 84 15 52 fe 	movzbl -0x1ae(%rbp,%rdx,1),%r8d
 1175973:	ff ff 
 1175975:	41 80 e0 0f          	and    $0xf,%r8b
 1175979:	44 88 84 35 d0 fe ff 	mov    %r8b,-0x130(%rbp,%rsi,1)
 1175980:	ff 
 1175981:	41 0f b7 74 57 0e    	movzwl 0xe(%r15,%rdx,2),%esi
 1175987:	44 0f b6 84 15 53 fe 	movzbl -0x1ad(%rbp,%rdx,1),%r8d
 117598e:	ff ff 
 1175990:	41 80 e0 0f          	and    $0xf,%r8b
 1175994:	44 88 84 35 d0 fe ff 	mov    %r8b,-0x130(%rbp,%rsi,1)
 117599b:	ff 
 117599c:	41 0f b7 74 57 10    	movzwl 0x10(%r15,%rdx,2),%esi
 11759a2:	44 0f b6 84 15 54 fe 	movzbl -0x1ac(%rbp,%rdx,1),%r8d
 11759a9:	ff ff 
 11759ab:	41 80 e0 0f          	and    $0xf,%r8b
 11759af:	44 88 84 35 d0 fe ff 	mov    %r8b,-0x130(%rbp,%rsi,1)
 11759b6:	ff 
 11759b7:	41 0f b7 74 57 12    	movzwl 0x12(%r15,%rdx,2),%esi
 11759bd:	44 0f b6 84 15 55 fe 	movzbl -0x1ab(%rbp,%rdx,1),%r8d
 11759c4:	ff ff 
 11759c6:	41 80 e0 0f          	and    $0xf,%r8b
 11759ca:	44 88 84 35 d0 fe ff 	mov    %r8b,-0x130(%rbp,%rsi,1)
 11759d1:	ff 
 11759d2:	41 0f b7 74 57 14    	movzwl 0x14(%r15,%rdx,2),%esi
 11759d8:	44 0f b6 84 15 56 fe 	movzbl -0x1aa(%rbp,%rdx,1),%r8d
 11759df:	ff ff 
 11759e1:	41 80 e0 0f          	and    $0xf,%r8b
 11759e5:	44 88 84 35 d0 fe ff 	mov    %r8b,-0x130(%rbp,%rsi,1)
 11759ec:	ff 
 11759ed:	41 0f b7 74 57 16    	movzwl 0x16(%r15,%rdx,2),%esi
 11759f3:	44 0f b6 84 15 57 fe 	movzbl -0x1a9(%rbp,%rdx,1),%r8d
 11759fa:	ff ff 
 11759fc:	41 80 e0 0f          	and    $0xf,%r8b
 1175a00:	44 88 84 35 d0 fe ff 	mov    %r8b,-0x130(%rbp,%rsi,1)
 1175a07:	ff 
 1175a08:	48 83 c2 08          	add    $0x8,%rdx
 1175a0c:	48 39 d1             	cmp    %rdx,%rcx
 1175a0f:	0f 85 1b ff ff ff    	jne    1175930 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x710>
 1175a15:	48 85 c0             	test   %rax,%rax
 1175a18:	0f 84 25 f9 ff ff    	je     1175343 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x123>
 1175a1e:	48 8d 0c 2a          	lea    (%rdx,%rbp,1),%rcx
 1175a22:	48 81 c1 50 fe ff ff 	add    $0xfffffffffffffe50,%rcx
 1175a29:	49 8d 14 57          	lea    (%r15,%rdx,2),%rdx
 1175a2d:	48 83 c2 08          	add    $0x8,%rdx
 1175a31:	31 f6                	xor    %esi,%esi
 1175a33:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1175a3a:	84 00 00 00 00 00 
 1175a40:	44 0f b7 04 72       	movzwl (%rdx,%rsi,2),%r8d
 1175a45:	44 0f b6 0c 31       	movzbl (%rcx,%rsi,1),%r9d
 1175a4a:	41 80 e1 0f          	and    $0xf,%r9b
 1175a4e:	46 88 8c 05 d0 fe ff 	mov    %r9b,-0x130(%rbp,%r8,1)
 1175a55:	ff 
 1175a56:	48 ff c6             	inc    %rsi
 1175a59:	48 39 f0             	cmp    %rsi,%rax
 1175a5c:	75 e2                	jne    1175a40 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x820>
 1175a5e:	e9 e0 f8 ff ff       	jmp    1175343 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x123>
 1175a63:	41 89 d8             	mov    %ebx,%r8d
 1175a66:	41 81 e0 f8 01 00 00 	and    $0x1f8,%r8d
 1175a6d:	31 c9                	xor    %ecx,%ecx
 1175a6f:	90                   	nop
 1175a70:	44 0f b7 4c 4e 08    	movzwl 0x8(%rsi,%rcx,2),%r9d
 1175a76:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 1175a7a:	44 89 8c 8d 50 f9 ff 	mov    %r9d,-0x6b0(%rbp,%rcx,4)
 1175a81:	ff 
 1175a82:	44 0f b7 4c 4e 0a    	movzwl 0xa(%rsi,%rcx,2),%r9d
 1175a88:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 1175a8c:	44 89 8c 8d 54 f9 ff 	mov    %r9d,-0x6ac(%rbp,%rcx,4)
 1175a93:	ff 
 1175a94:	44 0f b7 4c 4e 0c    	movzwl 0xc(%rsi,%rcx,2),%r9d
 1175a9a:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 1175a9e:	44 89 8c 8d 58 f9 ff 	mov    %r9d,-0x6a8(%rbp,%rcx,4)
 1175aa5:	ff 
 1175aa6:	44 0f b7 4c 4e 0e    	movzwl 0xe(%rsi,%rcx,2),%r9d
 1175aac:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 1175ab0:	44 89 8c 8d 5c f9 ff 	mov    %r9d,-0x6a4(%rbp,%rcx,4)
 1175ab7:	ff 
 1175ab8:	44 0f b7 4c 4e 10    	movzwl 0x10(%rsi,%rcx,2),%r9d
 1175abe:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 1175ac2:	44 89 8c 8d 60 f9 ff 	mov    %r9d,-0x6a0(%rbp,%rcx,4)
 1175ac9:	ff 
 1175aca:	44 0f b7 4c 4e 12    	movzwl 0x12(%rsi,%rcx,2),%r9d
 1175ad0:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 1175ad4:	44 89 8c 8d 64 f9 ff 	mov    %r9d,-0x69c(%rbp,%rcx,4)
 1175adb:	ff 
 1175adc:	44 0f b7 4c 4e 14    	movzwl 0x14(%rsi,%rcx,2),%r9d
 1175ae2:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 1175ae6:	44 89 8c 8d 68 f9 ff 	mov    %r9d,-0x698(%rbp,%rcx,4)
 1175aed:	ff 
 1175aee:	44 0f b7 4c 4e 16    	movzwl 0x16(%rsi,%rcx,2),%r9d
 1175af4:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 1175af8:	44 89 8c 8d 6c f9 ff 	mov    %r9d,-0x694(%rbp,%rcx,4)
 1175aff:	ff 
 1175b00:	48 83 c1 08          	add    $0x8,%rcx
 1175b04:	49 39 c8             	cmp    %rcx,%r8
 1175b07:	0f 85 63 ff ff ff    	jne    1175a70 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x850>
 1175b0d:	49 89 fd             	mov    %rdi,%r13
 1175b10:	48 85 c0             	test   %rax,%rax
 1175b13:	74 30                	je     1175b45 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x925>
 1175b15:	48 8d 3c 8d 50 f9 ff 	lea    -0x6b0(,%rcx,4),%rdi
 1175b1c:	ff 
 1175b1d:	48 01 ef             	add    %rbp,%rdi
 1175b20:	48 8d 0c 4e          	lea    (%rsi,%rcx,2),%rcx
 1175b24:	48 83 c1 08          	add    $0x8,%rcx
 1175b28:	45 31 c0             	xor    %r8d,%r8d
 1175b2b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 1175b30:	46 0f b7 0c 41       	movzwl (%rcx,%r8,2),%r9d
 1175b35:	46 8b 0c 8a          	mov    (%rdx,%r9,4),%r9d
 1175b39:	46 89 0c 87          	mov    %r9d,(%rdi,%r8,4)
 1175b3d:	49 ff c0             	inc    %r8
 1175b40:	4c 39 c0             	cmp    %r8,%rax
 1175b43:	75 eb                	jne    1175b30 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x910>
 1175b45:	49 89 d7             	mov    %rdx,%r15
 1175b48:	49 89 f6             	mov    %rsi,%r14
 1175b4b:	48 8d bd 50 f9 ff ff 	lea    -0x6b0(%rbp),%rdi
 1175b52:	48 8d 95 50 fd ff ff 	lea    -0x2b0(%rbp),%rdx
 1175b59:	48 89 de             	mov    %rbx,%rsi
 1175b5c:	c5 f8 77             	vzeroupper 
 1175b5f:	e8 5c 4c 04 00       	call   11ba7c0 <br.encoder.small_huffman.build__anon_35945>
 1175b64:	a8 01                	test   $0x1,%al
 1175b66:	74 19                	je     1175b81 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x961>
 1175b68:	89 d8                	mov    %ebx,%eax
 1175b6a:	83 e0 07             	and    $0x7,%eax
 1175b6d:	49 83 fc 07          	cmp    $0x7,%r12
 1175b71:	0f 83 5e 01 00 00    	jae    1175cd5 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0xab5>
 1175b77:	31 c9                	xor    %ecx,%ecx
 1175b79:	4c 89 ef             	mov    %r13,%rdi
 1175b7c:	e9 3d 02 00 00       	jmp    1175dbe <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0xb9e>
 1175b81:	48 8d 95 d0 fe ff ff 	lea    -0x130(%rbp),%rdx
 1175b88:	4c 89 f7             	mov    %r14,%rdi
 1175b8b:	4c 89 fe             	mov    %r15,%rsi
 1175b8e:	e8 ed 50 04 00       	call   11bac80 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35943>
 1175b93:	31 c9                	xor    %ecx,%ecx
 1175b95:	4c 89 ef             	mov    %r13,%rdi
 1175b98:	e9 a8 f7 ff ff       	jmp    1175345 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x125>
 1175b9d:	81 e3 f8 00 00 00    	and    $0xf8,%ebx
 1175ba3:	31 c9                	xor    %ecx,%ecx
 1175ba5:	4c 89 ef             	mov    %r13,%rdi
 1175ba8:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 1175baf:	00 
 1175bb0:	41 0f b7 54 4e 08    	movzwl 0x8(%r14,%rcx,2),%edx
 1175bb6:	0f b6 b4 0d 50 fd ff 	movzbl -0x2b0(%rbp,%rcx,1),%esi
 1175bbd:	ff 
 1175bbe:	44 0f b6 84 0d 51 fd 	movzbl -0x2af(%rbp,%rcx,1),%r8d
 1175bc5:	ff ff 
 1175bc7:	40 80 e6 0f          	and    $0xf,%sil
 1175bcb:	40 88 b4 15 d0 fe ff 	mov    %sil,-0x130(%rbp,%rdx,1)
 1175bd2:	ff 
 1175bd3:	41 0f b7 54 4e 0a    	movzwl 0xa(%r14,%rcx,2),%edx
 1175bd9:	41 80 e0 0f          	and    $0xf,%r8b
 1175bdd:	44 88 84 15 d0 fe ff 	mov    %r8b,-0x130(%rbp,%rdx,1)
 1175be4:	ff 
 1175be5:	41 0f b7 54 4e 0c    	movzwl 0xc(%r14,%rcx,2),%edx
 1175beb:	0f b6 b4 0d 52 fd ff 	movzbl -0x2ae(%rbp,%rcx,1),%esi
 1175bf2:	ff 
 1175bf3:	40 80 e6 0f          	and    $0xf,%sil
 1175bf7:	40 88 b4 15 d0 fe ff 	mov    %sil,-0x130(%rbp,%rdx,1)
 1175bfe:	ff 
 1175bff:	41 0f b7 54 4e 0e    	movzwl 0xe(%r14,%rcx,2),%edx
 1175c05:	0f b6 b4 0d 53 fd ff 	movzbl -0x2ad(%rbp,%rcx,1),%esi
 1175c0c:	ff 
 1175c0d:	40 80 e6 0f          	and    $0xf,%sil
 1175c11:	40 88 b4 15 d0 fe ff 	mov    %sil,-0x130(%rbp,%rdx,1)
 1175c18:	ff 
 1175c19:	41 0f b7 54 4e 10    	movzwl 0x10(%r14,%rcx,2),%edx
 1175c1f:	0f b6 b4 0d 54 fd ff 	movzbl -0x2ac(%rbp,%rcx,1),%esi
 1175c26:	ff 
 1175c27:	40 80 e6 0f          	and    $0xf,%sil
 1175c2b:	40 88 b4 15 d0 fe ff 	mov    %sil,-0x130(%rbp,%rdx,1)
 1175c32:	ff 
 1175c33:	41 0f b7 54 4e 12    	movzwl 0x12(%r14,%rcx,2),%edx
 1175c39:	0f b6 b4 0d 55 fd ff 	movzbl -0x2ab(%rbp,%rcx,1),%esi
 1175c40:	ff 
 1175c41:	40 80 e6 0f          	and    $0xf,%sil
 1175c45:	40 88 b4 15 d0 fe ff 	mov    %sil,-0x130(%rbp,%rdx,1)
 1175c4c:	ff 
 1175c4d:	41 0f b7 54 4e 14    	movzwl 0x14(%r14,%rcx,2),%edx
 1175c53:	0f b6 b4 0d 56 fd ff 	movzbl -0x2aa(%rbp,%rcx,1),%esi
 1175c5a:	ff 
 1175c5b:	40 80 e6 0f          	and    $0xf,%sil
 1175c5f:	40 88 b4 15 d0 fe ff 	mov    %sil,-0x130(%rbp,%rdx,1)
 1175c66:	ff 
 1175c67:	41 0f b7 54 4e 16    	movzwl 0x16(%r14,%rcx,2),%edx
 1175c6d:	0f b6 b4 0d 57 fd ff 	movzbl -0x2a9(%rbp,%rcx,1),%esi
 1175c74:	ff 
 1175c75:	40 80 e6 0f          	and    $0xf,%sil
 1175c79:	40 88 b4 15 d0 fe ff 	mov    %sil,-0x130(%rbp,%rdx,1)
 1175c80:	ff 
 1175c81:	48 83 c1 08          	add    $0x8,%rcx
 1175c85:	48 39 cb             	cmp    %rcx,%rbx
 1175c88:	0f 85 22 ff ff ff    	jne    1175bb0 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x990>
 1175c8e:	48 85 c0             	test   %rax,%rax
 1175c91:	0f 84 ac f6 ff ff    	je     1175343 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x123>
 1175c97:	48 8d 14 29          	lea    (%rcx,%rbp,1),%rdx
 1175c9b:	48 81 c2 50 fd ff ff 	add    $0xfffffffffffffd50,%rdx
 1175ca2:	49 8d 34 4e          	lea    (%r14,%rcx,2),%rsi
 1175ca6:	48 83 c6 08          	add    $0x8,%rsi
 1175caa:	45 31 c0             	xor    %r8d,%r8d
 1175cad:	0f 1f 00             	nopl   (%rax)
 1175cb0:	42 0f b7 0c 46       	movzwl (%rsi,%r8,2),%ecx
 1175cb5:	46 0f b6 0c 02       	movzbl (%rdx,%r8,1),%r9d
 1175cba:	41 80 e1 0f          	and    $0xf,%r9b
 1175cbe:	44 88 8c 0d d0 fe ff 	mov    %r9b,-0x130(%rbp,%rcx,1)
 1175cc5:	ff 
 1175cc6:	49 ff c0             	inc    %r8
 1175cc9:	31 c9                	xor    %ecx,%ecx
 1175ccb:	4c 39 c0             	cmp    %r8,%rax
 1175cce:	75 e0                	jne    1175cb0 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0xa90>
 1175cd0:	e9 70 f6 ff ff       	jmp    1175345 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x125>
 1175cd5:	81 e3 f8 01 00 00    	and    $0x1f8,%ebx
 1175cdb:	31 c9                	xor    %ecx,%ecx
 1175cdd:	4c 89 ef             	mov    %r13,%rdi
 1175ce0:	41 0f b7 54 4e 08    	movzwl 0x8(%r14,%rcx,2),%edx
 1175ce6:	0f b6 b4 0d 50 fd ff 	movzbl -0x2b0(%rbp,%rcx,1),%esi
 1175ced:	ff 
 1175cee:	44 0f b6 84 0d 51 fd 	movzbl -0x2af(%rbp,%rcx,1),%r8d
 1175cf5:	ff ff 
 1175cf7:	40 80 e6 0f          	and    $0xf,%sil
 1175cfb:	40 88 b4 15 d0 fe ff 	mov    %sil,-0x130(%rbp,%rdx,1)
 1175d02:	ff 
 1175d03:	41 0f b7 54 4e 0a    	movzwl 0xa(%r14,%rcx,2),%edx
 1175d09:	41 80 e0 0f          	and    $0xf,%r8b
 1175d0d:	44 88 84 15 d0 fe ff 	mov    %r8b,-0x130(%rbp,%rdx,1)
 1175d14:	ff 
 1175d15:	41 0f b7 54 4e 0c    	movzwl 0xc(%r14,%rcx,2),%edx
 1175d1b:	0f b6 b4 0d 52 fd ff 	movzbl -0x2ae(%rbp,%rcx,1),%esi
 1175d22:	ff 
 1175d23:	40 80 e6 0f          	and    $0xf,%sil
 1175d27:	40 88 b4 15 d0 fe ff 	mov    %sil,-0x130(%rbp,%rdx,1)
 1175d2e:	ff 
 1175d2f:	41 0f b7 54 4e 0e    	movzwl 0xe(%r14,%rcx,2),%edx
 1175d35:	0f b6 b4 0d 53 fd ff 	movzbl -0x2ad(%rbp,%rcx,1),%esi
 1175d3c:	ff 
 1175d3d:	40 80 e6 0f          	and    $0xf,%sil
 1175d41:	40 88 b4 15 d0 fe ff 	mov    %sil,-0x130(%rbp,%rdx,1)
 1175d48:	ff 
 1175d49:	41 0f b7 54 4e 10    	movzwl 0x10(%r14,%rcx,2),%edx
 1175d4f:	0f b6 b4 0d 54 fd ff 	movzbl -0x2ac(%rbp,%rcx,1),%esi
 1175d56:	ff 
 1175d57:	40 80 e6 0f          	and    $0xf,%sil
 1175d5b:	40 88 b4 15 d0 fe ff 	mov    %sil,-0x130(%rbp,%rdx,1)
 1175d62:	ff 
 1175d63:	41 0f b7 54 4e 12    	movzwl 0x12(%r14,%rcx,2),%edx
 1175d69:	0f b6 b4 0d 55 fd ff 	movzbl -0x2ab(%rbp,%rcx,1),%esi
 1175d70:	ff 
 1175d71:	40 80 e6 0f          	and    $0xf,%sil
 1175d75:	40 88 b4 15 d0 fe ff 	mov    %sil,-0x130(%rbp,%rdx,1)
 1175d7c:	ff 
 1175d7d:	41 0f b7 54 4e 14    	movzwl 0x14(%r14,%rcx,2),%edx
 1175d83:	0f b6 b4 0d 56 fd ff 	movzbl -0x2aa(%rbp,%rcx,1),%esi
 1175d8a:	ff 
 1175d8b:	40 80 e6 0f          	and    $0xf,%sil
 1175d8f:	40 88 b4 15 d0 fe ff 	mov    %sil,-0x130(%rbp,%rdx,1)
 1175d96:	ff 
 1175d97:	41 0f b7 54 4e 16    	movzwl 0x16(%r14,%rcx,2),%edx
 1175d9d:	0f b6 b4 0d 57 fd ff 	movzbl -0x2a9(%rbp,%rcx,1),%esi
 1175da4:	ff 
 1175da5:	40 80 e6 0f          	and    $0xf,%sil
 1175da9:	40 88 b4 15 d0 fe ff 	mov    %sil,-0x130(%rbp,%rdx,1)
 1175db0:	ff 
 1175db1:	48 83 c1 08          	add    $0x8,%rcx
 1175db5:	48 39 cb             	cmp    %rcx,%rbx
 1175db8:	0f 85 22 ff ff ff    	jne    1175ce0 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0xac0>
 1175dbe:	48 85 c0             	test   %rax,%rax
 1175dc1:	0f 84 7c f5 ff ff    	je     1175343 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x123>
 1175dc7:	48 8d 14 29          	lea    (%rcx,%rbp,1),%rdx
 1175dcb:	48 81 c2 50 fd ff ff 	add    $0xfffffffffffffd50,%rdx
 1175dd2:	49 8d 34 4e          	lea    (%r14,%rcx,2),%rsi
 1175dd6:	48 83 c6 08          	add    $0x8,%rsi
 1175dda:	45 31 c0             	xor    %r8d,%r8d
 1175ddd:	42 0f b7 0c 46       	movzwl (%rsi,%r8,2),%ecx
 1175de2:	46 0f b6 0c 02       	movzbl (%rdx,%r8,1),%r9d
 1175de7:	41 80 e1 0f          	and    $0xf,%r9b
 1175deb:	44 88 8c 0d d0 fe ff 	mov    %r9b,-0x130(%rbp,%rcx,1)
 1175df2:	ff 
 1175df3:	49 ff c0             	inc    %r8
 1175df6:	31 c9                	xor    %ecx,%ecx
 1175df8:	4c 39 c0             	cmp    %r8,%rax
 1175dfb:	75 e0                	jne    1175ddd <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0xbbd>
 1175dfd:	e9 43 f5 ff ff       	jmp    1175345 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x125>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
