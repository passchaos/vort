
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/d54ab236499589e8c9225c90450b9b10/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

00000000011793a0 <br.encodeCommandPlanWithOptionsWrite>:
 11793a0:	55                   	push   %rbp
 11793a1:	48 89 e5             	mov    %rsp,%rbp
 11793a4:	41 57                	push   %r15
 11793a6:	41 56                	push   %r14
 11793a8:	41 55                	push   %r13
 11793aa:	41 54                	push   %r12
 11793ac:	53                   	push   %rbx
 11793ad:	48 81 ec 08 f7 06 00 	sub    $0x6f708,%rsp
 11793b4:	49 89 ce             	mov    %rcx,%r14
 11793b7:	4c 8b 5d 18          	mov    0x18(%rbp),%r11
 11793bb:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11793bf:	48 89 85 50 fe ff ff 	mov    %rax,-0x1b0(%rbp)
 11793c6:	4d 8b bb 08 01 00 00 	mov    0x108(%r11),%r15
 11793cd:	49 8b 9b 88 01 00 00 	mov    0x188(%r11),%rbx
 11793d4:	4d 8b 93 00 02 00 00 	mov    0x200(%r11),%r10
 11793db:	4d 8b a3 08 02 00 00 	mov    0x208(%r11),%r12
 11793e2:	41 0f b7 8b 1a 02 00 	movzwl 0x21a(%r11),%ecx
 11793e9:	00 
 11793ea:	41 0f b6 83 21 02 00 	movzbl 0x221(%r11),%eax
 11793f1:	00 
 11793f2:	4c 89 a5 18 fc ff ff 	mov    %r12,-0x3e8(%rbp)
 11793f9:	4d 01 f4             	add    %r14,%r12
 11793fc:	0f 92 85 50 fc ff ff 	setb   -0x3b0(%rbp)
 1179403:	41 0f 92 c5          	setb   %r13b
 1179407:	73 0d                	jae    1179416 <br.encodeCommandPlanWithOptionsWrite+0x76>
 1179409:	66 b8 4f 00          	mov    $0x4f,%ax
 117940d:	48 81 c4 08 f7 06 00 	add    $0x6f708,%rsp
 1179414:	eb 66                	jmp    117947c <br.encodeCommandPlanWithOptionsWrite+0xdc>
 1179416:	a8 01                	test   $0x1,%al
 1179418:	74 12                	je     117942c <br.encodeCommandPlanWithOptionsWrite+0x8c>
 117941a:	4c 89 f1             	mov    %r14,%rcx
 117941d:	41 53                	push   %r11
 117941f:	ff b5 50 fe ff ff    	push   -0x1b0(%rbp)
 1179425:	e8 46 e1 04 00       	call   11c7570 <br.encodeCommandPlanWithLargeWindowWrite>
 117942a:	eb 49                	jmp    1179475 <br.encodeCommandPlanWithOptionsWrite+0xd5>
 117942c:	44 88 ad 3b ff ff ff 	mov    %r13b,-0xc5(%rbp)
 1179433:	4c 89 a5 60 fa ff ff 	mov    %r12,-0x5a0(%rbp)
 117943a:	41 89 cd             	mov    %ecx,%r13d
 117943d:	41 c1 ed 08          	shr    $0x8,%r13d
 1179441:	41 80 e5 0f          	and    $0xf,%r13b
 1179445:	80 e1 03             	and    $0x3,%cl
 1179448:	41 d2 e5             	shl    %cl,%r13b
 117944b:	45 0f b6 ed          	movzbl %r13b,%r13d
 117944f:	41 bc 30 00 00 00    	mov    $0x30,%r12d
 1179455:	c4 c2 71 f7 cc       	shlx   %ecx,%r12d,%ecx
 117945a:	44 01 e9             	add    %r13d,%ecx
 117945d:	83 c1 10             	add    $0x10,%ecx
 1179460:	83 f9 50             	cmp    $0x50,%ecx
 1179463:	72 25                	jb     117948a <br.encodeCommandPlanWithOptionsWrite+0xea>
 1179465:	4c 89 f1             	mov    %r14,%rcx
 1179468:	41 53                	push   %r11
 117946a:	ff b5 50 fe ff ff    	push   -0x1b0(%rbp)
 1179470:	e8 fb 0a 13 00       	call   12a9f70 <br.encodeCommandPlanWithWideDistanceWrite>
 1179475:	48 81 c4 18 f7 06 00 	add    $0x6f718,%rsp
 117947c:	5b                   	pop    %rbx
 117947d:	41 5c                	pop    %r12
 117947f:	41 5d                	pop    %r13
 1179481:	41 5e                	pop    %r14
 1179483:	41 5f                	pop    %r15
 1179485:	5d                   	pop    %rbp
 1179486:	c5 f8 77             	vzeroupper 
 1179489:	c3                   	ret    
 117948a:	4d 85 ff             	test   %r15,%r15
 117948d:	0f 85 e8 05 00 00    	jne    1179a7b <br.encodeCommandPlanWithOptionsWrite+0x6db>
 1179493:	48 85 db             	test   %rbx,%rbx
 1179496:	0f 85 df 05 00 00    	jne    1179a7b <br.encodeCommandPlanWithOptionsWrite+0x6db>
 117949c:	4d 85 d2             	test   %r10,%r10
 117949f:	0f 85 d6 05 00 00    	jne    1179a7b <br.encodeCommandPlanWithOptionsWrite+0x6db>
 11794a5:	49 8b 0b             	mov    (%r11),%rcx
 11794a8:	48 89 8d 80 fd ff ff 	mov    %rcx,-0x280(%rbp)
 11794af:	49 8b 4b 08          	mov    0x8(%r11),%rcx
 11794b3:	48 89 8d e0 fd ff ff 	mov    %rcx,-0x220(%rbp)
 11794ba:	49 8b 4b 10          	mov    0x10(%r11),%rcx
 11794be:	48 89 8d e8 fd ff ff 	mov    %rcx,-0x218(%rbp)
 11794c5:	49 8b 4b 18          	mov    0x18(%r11),%rcx
 11794c9:	48 89 8d 08 fd ff ff 	mov    %rcx,-0x2f8(%rbp)
 11794d0:	c4 c1 7c 10 43 20    	vmovups 0x20(%r11),%ymm0
 11794d6:	c5 fc 11 85 b0 f0 ff 	vmovups %ymm0,-0xf50(%rbp)
 11794dd:	ff 
 11794de:	41 0f b6 8b 90 00 00 	movzbl 0x90(%r11),%ecx
 11794e5:	00 
 11794e6:	88 8d 58 ff ff ff    	mov    %cl,-0xa8(%rbp)
 11794ec:	49 8b 8b 98 00 00 00 	mov    0x98(%r11),%rcx
 11794f3:	48 89 8d 60 ff ff ff 	mov    %rcx,-0xa0(%rbp)
 11794fa:	49 8b 8b a0 00 00 00 	mov    0xa0(%r11),%rcx
 1179501:	48 89 8d 10 ff ff ff 	mov    %rcx,-0xf0(%rbp)
 1179508:	41 0f b6 8b a8 00 00 	movzbl 0xa8(%r11),%ecx
 117950f:	00 
 1179510:	88 4d c5             	mov    %cl,-0x3b(%rbp)
 1179513:	41 8b 8b ac 00 00 00 	mov    0xac(%r11),%ecx
 117951a:	89 8d 07 fe ff ff    	mov    %ecx,-0x1f9(%rbp)
 1179520:	41 8b 8b a9 00 00 00 	mov    0xa9(%r11),%ecx
 1179527:	89 8d 04 fe ff ff    	mov    %ecx,-0x1fc(%rbp)
 117952d:	49 8b 8b b0 00 00 00 	mov    0xb0(%r11),%rcx
 1179534:	48 89 8d 18 ff ff ff 	mov    %rcx,-0xe8(%rbp)
 117953b:	41 0f b6 8b b8 00 00 	movzbl 0xb8(%r11),%ecx
 1179542:	00 
 1179543:	88 4d cf             	mov    %cl,-0x31(%rbp)
 1179546:	41 8b 8b bc 00 00 00 	mov    0xbc(%r11),%ecx
 117954d:	89 8d 0f fe ff ff    	mov    %ecx,-0x1f1(%rbp)
 1179553:	41 8b 8b b9 00 00 00 	mov    0xb9(%r11),%ecx
 117955a:	89 8d 0c fe ff ff    	mov    %ecx,-0x1f4(%rbp)
 1179560:	49 8b 8b c0 00 00 00 	mov    0xc0(%r11),%rcx
 1179567:	48 89 8d 20 ff ff ff 	mov    %rcx,-0xe0(%rbp)
 117956e:	41 0f b6 8b c8 00 00 	movzbl 0xc8(%r11),%ecx
 1179575:	00 
 1179576:	88 4d d1             	mov    %cl,-0x2f(%rbp)
 1179579:	41 8b 8b cc 00 00 00 	mov    0xcc(%r11),%ecx
 1179580:	89 8d 17 fe ff ff    	mov    %ecx,-0x1e9(%rbp)
 1179586:	41 8b 8b c9 00 00 00 	mov    0xc9(%r11),%ecx
 117958d:	89 8d 14 fe ff ff    	mov    %ecx,-0x1ec(%rbp)
 1179593:	49 8b 8b d0 00 00 00 	mov    0xd0(%r11),%rcx
 117959a:	48 89 8d f0 fe ff ff 	mov    %rcx,-0x110(%rbp)
 11795a1:	41 0f b6 8b d8 00 00 	movzbl 0xd8(%r11),%ecx
 11795a8:	00 
 11795a9:	88 4d ca             	mov    %cl,-0x36(%rbp)
 11795ac:	41 8b 8b dc 00 00 00 	mov    0xdc(%r11),%ecx
 11795b3:	89 8d 1f fe ff ff    	mov    %ecx,-0x1e1(%rbp)
 11795b9:	41 8b 8b d9 00 00 00 	mov    0xd9(%r11),%ecx
 11795c0:	89 8d 1c fe ff ff    	mov    %ecx,-0x1e4(%rbp)
 11795c6:	49 8b 8b e0 00 00 00 	mov    0xe0(%r11),%rcx
 11795cd:	48 89 8d 28 ff ff ff 	mov    %rcx,-0xd8(%rbp)
 11795d4:	41 0f b6 8b e8 00 00 	movzbl 0xe8(%r11),%ecx
 11795db:	00 
 11795dc:	88 4d c0             	mov    %cl,-0x40(%rbp)
 11795df:	41 8b 8b ec 00 00 00 	mov    0xec(%r11),%ecx
 11795e6:	89 8d 27 fe ff ff    	mov    %ecx,-0x1d9(%rbp)
 11795ec:	41 8b 8b e9 00 00 00 	mov    0xe9(%r11),%ecx
 11795f3:	89 8d 24 fe ff ff    	mov    %ecx,-0x1dc(%rbp)
 11795f9:	41 0f b6 8b f8 00 00 	movzbl 0xf8(%r11),%ecx
 1179600:	00 
 1179601:	88 4d c9             	mov    %cl,-0x37(%rbp)
 1179604:	41 0f b6 8b f9 00 00 	movzbl 0xf9(%r11),%ecx
 117960b:	00 
 117960c:	88 4d c2             	mov    %cl,-0x3e(%rbp)
 117960f:	49 8b 8b f0 00 00 00 	mov    0xf0(%r11),%rcx
 1179616:	48 89 8d 00 fd ff ff 	mov    %rcx,-0x300(%rbp)
 117961d:	41 0f b7 8b fe 00 00 	movzwl 0xfe(%r11),%ecx
 1179624:	00 
 1179625:	66 89 8d 4c fe ff ff 	mov    %cx,-0x1b4(%rbp)
 117962c:	41 8b 8b fa 00 00 00 	mov    0xfa(%r11),%ecx
 1179633:	89 8d 48 fe ff ff    	mov    %ecx,-0x1b8(%rbp)
 1179639:	41 0f b6 8b 00 01 00 	movzbl 0x100(%r11),%ecx
 1179640:	00 
 1179641:	88 4d c6             	mov    %cl,-0x3a(%rbp)
 1179644:	41 0f b6 8b 28 01 00 	movzbl 0x128(%r11),%ecx
 117964b:	00 
 117964c:	88 4d cb             	mov    %cl,-0x35(%rbp)
 117964f:	49 8b 8b 10 01 00 00 	mov    0x110(%r11),%rcx
 1179656:	48 89 8d 70 ff ff ff 	mov    %rcx,-0x90(%rbp)
 117965d:	49 8b 8b 18 01 00 00 	mov    0x118(%r11),%rcx
 1179664:	48 89 8d 38 fe ff ff 	mov    %rcx,-0x1c8(%rbp)
 117966b:	49 8b 8b 20 01 00 00 	mov    0x120(%r11),%rcx
 1179672:	48 89 8d c0 fd ff ff 	mov    %rcx,-0x240(%rbp)
 1179679:	41 8b 8b 2c 01 00 00 	mov    0x12c(%r11),%ecx
 1179680:	89 8d 7b fe ff ff    	mov    %ecx,-0x185(%rbp)
 1179686:	41 8b 8b 29 01 00 00 	mov    0x129(%r11),%ecx
 117968d:	89 8d 78 fe ff ff    	mov    %ecx,-0x188(%rbp)
 1179693:	41 0f b6 8b 38 01 00 	movzbl 0x138(%r11),%ecx
 117969a:	00 
 117969b:	88 4d d0             	mov    %cl,-0x30(%rbp)
 117969e:	49 8b 8b 30 01 00 00 	mov    0x130(%r11),%rcx
 11796a5:	48 89 8d c8 fd ff ff 	mov    %rcx,-0x238(%rbp)
 11796ac:	41 8b 8b 3c 01 00 00 	mov    0x13c(%r11),%ecx
 11796b3:	89 8d 83 fe ff ff    	mov    %ecx,-0x17d(%rbp)
 11796b9:	41 8b 8b 39 01 00 00 	mov    0x139(%r11),%ecx
 11796c0:	89 8d 80 fe ff ff    	mov    %ecx,-0x180(%rbp)
 11796c6:	41 0f b6 8b 48 01 00 	movzbl 0x148(%r11),%ecx
 11796cd:	00 
 11796ce:	88 4d d6             	mov    %cl,-0x2a(%rbp)
 11796d1:	49 8b 8b 40 01 00 00 	mov    0x140(%r11),%rcx
 11796d8:	48 89 8d d0 fd ff ff 	mov    %rcx,-0x230(%rbp)
 11796df:	41 8b 8b 4c 01 00 00 	mov    0x14c(%r11),%ecx
 11796e6:	89 8d 8b fe ff ff    	mov    %ecx,-0x175(%rbp)
 11796ec:	41 8b 8b 49 01 00 00 	mov    0x149(%r11),%ecx
 11796f3:	89 8d 88 fe ff ff    	mov    %ecx,-0x178(%rbp)
 11796f9:	41 0f b6 8b 58 01 00 	movzbl 0x158(%r11),%ecx
 1179700:	00 
 1179701:	88 4d cd             	mov    %cl,-0x33(%rbp)
 1179704:	49 8b 8b 50 01 00 00 	mov    0x150(%r11),%rcx
 117970b:	48 89 8d d8 fd ff ff 	mov    %rcx,-0x228(%rbp)
 1179712:	41 8b 8b 5c 01 00 00 	mov    0x15c(%r11),%ecx
 1179719:	89 8d 93 fe ff ff    	mov    %ecx,-0x16d(%rbp)
 117971f:	41 8b 8b 59 01 00 00 	mov    0x159(%r11),%ecx
 1179726:	89 8d 90 fe ff ff    	mov    %ecx,-0x170(%rbp)
 117972c:	41 0f b6 8b 68 01 00 	movzbl 0x168(%r11),%ecx
 1179733:	00 
 1179734:	88 4d c1             	mov    %cl,-0x3f(%rbp)
 1179737:	49 8b 8b 60 01 00 00 	mov    0x160(%r11),%rcx
 117973e:	48 89 8d 68 ff ff ff 	mov    %rcx,-0x98(%rbp)
 1179745:	41 8b 8b 6c 01 00 00 	mov    0x16c(%r11),%ecx
 117974c:	89 8d 9b fe ff ff    	mov    %ecx,-0x165(%rbp)
 1179752:	41 8b 8b 69 01 00 00 	mov    0x169(%r11),%ecx
 1179759:	89 8d 98 fe ff ff    	mov    %ecx,-0x168(%rbp)
 117975f:	41 0f b6 8b 78 01 00 	movzbl 0x178(%r11),%ecx
 1179766:	00 
 1179767:	88 4d d2             	mov    %cl,-0x2e(%rbp)
 117976a:	49 8b 8b 70 01 00 00 	mov    0x170(%r11),%rcx
 1179771:	48 89 8d 18 fd ff ff 	mov    %rcx,-0x2e8(%rbp)
 1179778:	41 0f b7 8b 7e 01 00 	movzwl 0x17e(%r11),%ecx
 117977f:	00 
 1179780:	45 0f b6 93 79 01 00 	movzbl 0x179(%r11),%r10d
 1179787:	00 
 1179788:	44 88 55 c7          	mov    %r10b,-0x39(%rbp)
 117978c:	66 89 8d e0 fe ff ff 	mov    %cx,-0x120(%rbp)
 1179793:	41 8b 8b 7a 01 00 00 	mov    0x17a(%r11),%ecx
 117979a:	89 8d dc fe ff ff    	mov    %ecx,-0x124(%rbp)
 11797a0:	49 8b 8b 90 01 00 00 	mov    0x190(%r11),%rcx
 11797a7:	48 89 8d c8 fe ff ff 	mov    %rcx,-0x138(%rbp)
 11797ae:	49 8b 8b 98 01 00 00 	mov    0x198(%r11),%rcx
 11797b5:	48 89 8d 58 fe ff ff 	mov    %rcx,-0x1a8(%rbp)
 11797bc:	41 8b 8b a4 01 00 00 	mov    0x1a4(%r11),%ecx
 11797c3:	45 0f b6 93 80 01 00 	movzbl 0x180(%r11),%r10d
 11797ca:	00 
 11797cb:	44 88 55 c3          	mov    %r10b,-0x3d(%rbp)
 11797cf:	45 0f b6 bb a0 01 00 	movzbl 0x1a0(%r11),%r15d
 11797d6:	00 
 11797d7:	89 8d a3 fe ff ff    	mov    %ecx,-0x15d(%rbp)
 11797dd:	41 8b 8b a1 01 00 00 	mov    0x1a1(%r11),%ecx
 11797e4:	89 8d a0 fe ff ff    	mov    %ecx,-0x160(%rbp)
 11797ea:	49 8b 8b a8 01 00 00 	mov    0x1a8(%r11),%rcx
 11797f1:	48 89 8d 60 fe ff ff 	mov    %rcx,-0x1a0(%rbp)
 11797f8:	41 8b 8b b4 01 00 00 	mov    0x1b4(%r11),%ecx
 11797ff:	45 0f b6 93 b0 01 00 	movzbl 0x1b0(%r11),%r10d
 1179806:	00 
 1179807:	44 88 55 d4          	mov    %r10b,-0x2c(%rbp)
 117980b:	89 8d ab fe ff ff    	mov    %ecx,-0x155(%rbp)
 1179811:	41 8b 8b b1 01 00 00 	mov    0x1b1(%r11),%ecx
 1179818:	89 8d a8 fe ff ff    	mov    %ecx,-0x158(%rbp)
 117981e:	49 8b 8b b8 01 00 00 	mov    0x1b8(%r11),%rcx
 1179825:	48 89 8d 68 fe ff ff 	mov    %rcx,-0x198(%rbp)
 117982c:	41 8b 8b c4 01 00 00 	mov    0x1c4(%r11),%ecx
 1179833:	45 0f b6 93 c0 01 00 	movzbl 0x1c0(%r11),%r10d
 117983a:	00 
 117983b:	44 88 55 d7          	mov    %r10b,-0x29(%rbp)
 117983f:	89 8d b3 fe ff ff    	mov    %ecx,-0x14d(%rbp)
 1179845:	41 8b 8b c1 01 00 00 	mov    0x1c1(%r11),%ecx
 117984c:	89 8d b0 fe ff ff    	mov    %ecx,-0x150(%rbp)
 1179852:	49 8b 8b c8 01 00 00 	mov    0x1c8(%r11),%rcx
 1179859:	48 89 8d 70 fe ff ff 	mov    %rcx,-0x190(%rbp)
 1179860:	41 8b 8b d4 01 00 00 	mov    0x1d4(%r11),%ecx
 1179867:	45 0f b6 93 d0 01 00 	movzbl 0x1d0(%r11),%r10d
 117986e:	00 
 117986f:	44 88 55 ce          	mov    %r10b,-0x32(%rbp)
 1179873:	89 8d bb fe ff ff    	mov    %ecx,-0x145(%rbp)
 1179879:	41 8b 8b d1 01 00 00 	mov    0x1d1(%r11),%ecx
 1179880:	89 8d b8 fe ff ff    	mov    %ecx,-0x148(%rbp)
 1179886:	49 8b 9b d8 01 00 00 	mov    0x1d8(%r11),%rbx
 117988d:	41 8b 8b e4 01 00 00 	mov    0x1e4(%r11),%ecx
 1179894:	45 0f b6 93 e0 01 00 	movzbl 0x1e0(%r11),%r10d
 117989b:	00 
 117989c:	44 88 55 c4          	mov    %r10b,-0x3c(%rbp)
 11798a0:	89 8d c3 fe ff ff    	mov    %ecx,-0x13d(%rbp)
 11798a6:	41 8b 8b e1 01 00 00 	mov    0x1e1(%r11),%ecx
 11798ad:	89 8d c0 fe ff ff    	mov    %ecx,-0x140(%rbp)
 11798b3:	49 8b 8b e8 01 00 00 	mov    0x1e8(%r11),%rcx
 11798ba:	48 89 8d 20 fd ff ff 	mov    %rcx,-0x2e0(%rbp)
 11798c1:	41 0f b7 8b f6 01 00 	movzwl 0x1f6(%r11),%ecx
 11798c8:	00 
 11798c9:	45 0f b6 93 f0 01 00 	movzbl 0x1f0(%r11),%r10d
 11798d0:	00 
 11798d1:	44 88 55 d3          	mov    %r10b,-0x2d(%rbp)
 11798d5:	45 0f b6 93 f1 01 00 	movzbl 0x1f1(%r11),%r10d
 11798dc:	00 
 11798dd:	44 88 55 c8          	mov    %r10b,-0x38(%rbp)
 11798e1:	66 89 8d e8 fe ff ff 	mov    %cx,-0x118(%rbp)
 11798e8:	41 8b 8b f2 01 00 00 	mov    0x1f2(%r11),%ecx
 11798ef:	89 8d e4 fe ff ff    	mov    %ecx,-0x11c(%rbp)
 11798f5:	49 8b 8b 10 02 00 00 	mov    0x210(%r11),%rcx
 11798fc:	48 89 8d 20 fc ff ff 	mov    %rcx,-0x3e0(%rbp)
 1179903:	45 0f b6 93 18 02 00 	movzbl 0x218(%r11),%r10d
 117990a:	00 
 117990b:	45 0f b7 ab 1a 02 00 	movzwl 0x21a(%r11),%r13d
 1179912:	00 
 1179913:	41 0f b6 8b f8 01 00 	movzbl 0x1f8(%r11),%ecx
 117991a:	00 
 117991b:	88 4d cc             	mov    %cl,-0x34(%rbp)
 117991e:	41 0f b6 8b 19 02 00 	movzbl 0x219(%r11),%ecx
 1179925:	00 
 1179926:	88 8d f8 fe ff ff    	mov    %cl,-0x108(%rbp)
 117992c:	41 0f b6 8b 1c 02 00 	movzbl 0x21c(%r11),%ecx
 1179933:	00 
 1179934:	88 8d 40 ff ff ff    	mov    %cl,-0xc0(%rbp)
 117993a:	41 0f b6 8b 1d 02 00 	movzbl 0x21d(%r11),%ecx
 1179941:	00 
 1179942:	88 4d 9c             	mov    %cl,-0x64(%rbp)
 1179945:	41 0f b6 8b 1e 02 00 	movzbl 0x21e(%r11),%ecx
 117994c:	00 
 117994d:	88 4d 90             	mov    %cl,-0x70(%rbp)
 1179950:	88 8d 3e ff ff ff    	mov    %cl,-0xc2(%rbp)
 1179956:	41 0f b6 8b 1f 02 00 	movzbl 0x21f(%r11),%ecx
 117995d:	00 
 117995e:	89 8d 78 fd ff ff    	mov    %ecx,-0x288(%rbp)
 1179964:	41 0f b6 8b 20 02 00 	movzbl 0x220(%r11),%ecx
 117996b:	00 
 117996c:	88 85 3a ff ff ff    	mov    %al,-0xc6(%rbp)
 1179972:	41 0f b7 83 22 02 00 	movzwl 0x222(%r11),%eax
 1179979:	00 
 117997a:	89 85 b4 fd ff ff    	mov    %eax,-0x24c(%rbp)
 1179980:	41 0f b6 83 24 02 00 	movzbl 0x224(%r11),%eax
 1179987:	00 
 1179988:	45 0f b6 a3 25 02 00 	movzbl 0x225(%r11),%r12d
 117998f:	00 
 1179990:	44 88 a5 ec fe ff ff 	mov    %r12b,-0x114(%rbp)
 1179997:	44 88 65 9d          	mov    %r12b,-0x63(%rbp)
 117999b:	4d 85 c9             	test   %r9,%r9
 117999e:	0f 84 f3 01 00 00    	je     1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 11799a4:	88 4d 9e             	mov    %cl,-0x62(%rbp)
 11799a7:	44 88 7d d5          	mov    %r15b,-0x2b(%rbp)
 11799ab:	48 89 9d 78 ff ff ff 	mov    %rbx,-0x88(%rbp)
 11799b2:	45 89 ec             	mov    %r13d,%r12d
 11799b5:	41 c1 ec 08          	shr    $0x8,%r12d
 11799b9:	44 89 e3             	mov    %r12d,%ebx
 11799bc:	80 e3 0f             	and    $0xf,%bl
 11799bf:	44 89 ad 44 ff ff ff 	mov    %r13d,-0xbc(%rbp)
 11799c6:	44 89 e9             	mov    %r13d,%ecx
 11799c9:	80 e1 03             	and    $0x3,%cl
 11799cc:	d2 e3                	shl    %cl,%bl
 11799ce:	0f b6 db             	movzbl %bl,%ebx
 11799d1:	41 bf 30 00 00 00    	mov    $0x30,%r15d
 11799d7:	c4 c2 f1 f7 cf       	shlx   %rcx,%r15,%rcx
 11799dc:	48 01 d9             	add    %rbx,%rcx
 11799df:	48 83 c1 10          	add    $0x10,%rcx
 11799e3:	48 83 f9 4f          	cmp    $0x4f,%rcx
 11799e7:	0f 87 aa 01 00 00    	ja     1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 11799ed:	44 89 a5 00 ff ff ff 	mov    %r12d,-0x100(%rbp)
 11799f4:	48 89 8d f0 fd ff ff 	mov    %rcx,-0x210(%rbp)
 11799fb:	4c 8d a5 09 f0 ff ff 	lea    -0xff7(%rbp),%r12
 1179a02:	48 8d 8d 0a f0 ff ff 	lea    -0xff6(%rbp),%rcx
 1179a09:	49 83 c3 40          	add    $0x40,%r11
 1179a0d:	4d 8d 68 50          	lea    0x50(%r8),%r13
 1179a11:	41 bf 01 00 00 00    	mov    $0x1,%r15d
 1179a17:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 1179a1e:	00 00 
 1179a20:	41 0f b6 5d 00       	movzbl 0x0(%r13),%ebx
 1179a25:	84 db                	test   %bl,%bl
 1179a27:	75 0d                	jne    1179a36 <br.encodeCommandPlanWithOptionsWrite+0x696>
 1179a29:	49 83 c5 60          	add    $0x60,%r13
 1179a2d:	4d 39 f9             	cmp    %r15,%r9
 1179a30:	4d 8d 7f 01          	lea    0x1(%r15),%r15
 1179a34:	75 ea                	jne    1179a20 <br.encodeCommandPlanWithOptionsWrite+0x680>
 1179a36:	80 bd 58 ff ff ff 00 	cmpb   $0x0,-0xa8(%rbp)
 1179a3d:	74 55                	je     1179a94 <br.encodeCommandPlanWithOptionsWrite+0x6f4>
 1179a3f:	c4 c1 7c 10 03       	vmovups (%r11),%ymm0
 1179a44:	c4 c1 7c 10 4b 20    	vmovups 0x20(%r11),%ymm1
 1179a4a:	c4 c1 7c 10 53 30    	vmovups 0x30(%r11),%ymm2
 1179a50:	c5 fc 11 95 30 f0 ff 	vmovups %ymm2,-0xfd0(%rbp)
 1179a57:	ff 
 1179a58:	c5 fc 11 8d 20 f0 ff 	vmovups %ymm1,-0xfe0(%rbp)
 1179a5f:	ff 
 1179a60:	c5 fc 11 85 00 f0 ff 	vmovups %ymm0,-0x1000(%rbp)
 1179a67:	ff 
 1179a68:	c6 85 50 f0 ff ff 01 	movb   $0x1,-0xfb0(%rbp)
 1179a6f:	4c 8d ad 00 f0 ff ff 	lea    -0x1000(%rbp),%r13
 1179a76:	e9 0d 01 00 00       	jmp    1179b88 <br.encodeCommandPlanWithOptionsWrite+0x7e8>
 1179a7b:	4c 89 f1             	mov    %r14,%rcx
 1179a7e:	48 81 c4 08 f7 06 00 	add    $0x6f708,%rsp
 1179a85:	5b                   	pop    %rbx
 1179a86:	41 5c                	pop    %r12
 1179a88:	41 5d                	pop    %r13
 1179a8a:	41 5e                	pop    %r14
 1179a8c:	41 5f                	pop    %r15
 1179a8e:	5d                   	pop    %rbp
 1179a8f:	e9 dc c9 11 00       	jmp    1296470 <br.encodeCommandPlanWithAdaptiveSplitWrite>
 1179a94:	a8 01                	test   $0x1,%al
 1179a96:	0f 84 2c 02 00 00    	je     1179cc8 <br.encodeCommandPlanWithOptionsWrite+0x928>
 1179a9c:	41 83 e2 3f          	and    $0x3f,%r10d
 1179aa0:	31 c0                	xor    %eax,%eax
 1179aa2:	4c 39 d0             	cmp    %r10,%rax
 1179aa5:	0f 93 84 05 50 fc ff 	setae  -0x3b0(%rbp,%rax,1)
 1179aac:	ff 
 1179aad:	48 8d 48 01          	lea    0x1(%rax),%rcx
 1179ab1:	4c 39 d1             	cmp    %r10,%rcx
 1179ab4:	0f 93 84 05 51 fc ff 	setae  -0x3af(%rbp,%rax,1)
 1179abb:	ff 
 1179abc:	48 8d 48 02          	lea    0x2(%rax),%rcx
 1179ac0:	4c 39 d1             	cmp    %r10,%rcx
 1179ac3:	0f 93 84 05 52 fc ff 	setae  -0x3ae(%rbp,%rax,1)
 1179aca:	ff 
 1179acb:	48 8d 48 03          	lea    0x3(%rax),%rcx
 1179acf:	4c 39 d1             	cmp    %r10,%rcx
 1179ad2:	0f 93 84 05 53 fc ff 	setae  -0x3ad(%rbp,%rax,1)
 1179ad9:	ff 
 1179ada:	48 8d 48 04          	lea    0x4(%rax),%rcx
 1179ade:	4c 39 d1             	cmp    %r10,%rcx
 1179ae1:	0f 93 84 05 54 fc ff 	setae  -0x3ac(%rbp,%rax,1)
 1179ae8:	ff 
 1179ae9:	48 8d 48 05          	lea    0x5(%rax),%rcx
 1179aed:	4c 39 d1             	cmp    %r10,%rcx
 1179af0:	0f 93 84 05 55 fc ff 	setae  -0x3ab(%rbp,%rax,1)
 1179af7:	ff 
 1179af8:	48 8d 48 06          	lea    0x6(%rax),%rcx
 1179afc:	4c 39 d1             	cmp    %r10,%rcx
 1179aff:	0f 93 84 05 56 fc ff 	setae  -0x3aa(%rbp,%rax,1)
 1179b06:	ff 
 1179b07:	48 8d 48 07          	lea    0x7(%rax),%rcx
 1179b0b:	4c 39 d1             	cmp    %r10,%rcx
 1179b0e:	0f 93 84 05 57 fc ff 	setae  -0x3a9(%rbp,%rax,1)
 1179b15:	ff 
 1179b16:	48 83 c0 08          	add    $0x8,%rax
 1179b1a:	48 83 f8 40          	cmp    $0x40,%rax
 1179b1e:	75 82                	jne    1179aa2 <br.encodeCommandPlanWithOptionsWrite+0x702>
 1179b20:	c6 85 50 ff ff ff 02 	movb   $0x2,-0xb0(%rbp)
 1179b27:	c6 85 39 ff ff ff 02 	movb   $0x2,-0xc7(%rbp)
 1179b2e:	c5 fc 10 85 50 fc ff 	vmovups -0x3b0(%rbp),%ymm0
 1179b35:	ff 
 1179b36:	c5 fc 10 8d 70 fc ff 	vmovups -0x390(%rbp),%ymm1
 1179b3d:	ff 
 1179b3e:	48 8d 8d b2 ef ff ff 	lea    -0x104e(%rbp),%rcx
 1179b45:	c5 fc 11 49 20       	vmovups %ymm1,0x20(%rcx)
 1179b4a:	c5 fc 11 01          	vmovups %ymm0,(%rcx)
 1179b4e:	48 c7 85 a8 ef ff ff 	movq   $0x0,-0x1058(%rbp)
 1179b55:	00 00 00 00 
 1179b59:	0f b6 85 50 ff ff ff 	movzbl -0xb0(%rbp),%eax
 1179b60:	88 85 b0 ef ff ff    	mov    %al,-0x1050(%rbp)
 1179b66:	0f b6 85 39 ff ff ff 	movzbl -0xc7(%rbp),%eax
 1179b6d:	88 85 b1 ef ff ff    	mov    %al,-0x104f(%rbp)
 1179b73:	c6 85 f8 ef ff ff 01 	movb   $0x1,-0x1008(%rbp)
 1179b7a:	4c 8d ad a8 ef ff ff 	lea    -0x1058(%rbp),%r13
 1179b81:	4c 8d a5 b1 ef ff ff 	lea    -0x104f(%rbp),%r12
 1179b88:	45 0f b6 7d 09       	movzbl 0x9(%r13),%r15d
 1179b8d:	41 8d 47 3f          	lea    0x3f(%r15),%eax
 1179b91:	24 7f                	and    $0x7f,%al
 1179b93:	3c 41                	cmp    $0x41,%al
 1179b95:	73 09                	jae    1179ba0 <br.encodeCommandPlanWithOptionsWrite+0x800>
 1179b97:	66 b8 1f 00          	mov    $0x1f,%ax
 1179b9b:	e9 6d f8 ff ff       	jmp    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 1179ba0:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1179ba4:	c5 fc 11 85 00 f8 ff 	vmovups %ymm0,-0x800(%rbp)
 1179bab:	ff 
 1179bac:	c5 fc 11 85 e0 f7 ff 	vmovups %ymm0,-0x820(%rbp)
 1179bb3:	ff 
 1179bb4:	c5 fc 10 01          	vmovups (%rcx),%ymm0
 1179bb8:	c5 fc 10 49 20       	vmovups 0x20(%rcx),%ymm1
 1179bbd:	c5 fc 11 85 90 f7 ff 	vmovups %ymm0,-0x870(%rbp)
 1179bc4:	ff 
 1179bc5:	c5 fc 11 8d b0 f7 ff 	vmovups %ymm1,-0x850(%rbp)
 1179bcc:	ff 
 1179bcd:	44 89 f9             	mov    %r15d,%ecx
 1179bd0:	83 e1 7f             	and    $0x7f,%ecx
 1179bd3:	45 31 d2             	xor    %r10d,%r10d
 1179bd6:	44 8b 9d 44 ff ff ff 	mov    -0xbc(%rbp),%r11d
 1179bdd:	42 0f b6 84 15 90 f7 	movzbl -0x870(%rbp,%r10,1),%eax
 1179be4:	ff ff 
 1179be6:	38 c8                	cmp    %cl,%al
 1179be8:	73 ad                	jae    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 1179bea:	c6 84 05 e0 f7 ff ff 	movb   $0x1,-0x820(%rbp,%rax,1)
 1179bf1:	01 
 1179bf2:	42 0f b6 84 15 91 f7 	movzbl -0x86f(%rbp,%r10,1),%eax
 1179bf9:	ff ff 
 1179bfb:	38 c8                	cmp    %cl,%al
 1179bfd:	73 98                	jae    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 1179bff:	c6 84 05 e0 f7 ff ff 	movb   $0x1,-0x820(%rbp,%rax,1)
 1179c06:	01 
 1179c07:	42 0f b6 84 15 92 f7 	movzbl -0x86e(%rbp,%r10,1),%eax
 1179c0e:	ff ff 
 1179c10:	38 c8                	cmp    %cl,%al
 1179c12:	73 83                	jae    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 1179c14:	c6 84 05 e0 f7 ff ff 	movb   $0x1,-0x820(%rbp,%rax,1)
 1179c1b:	01 
 1179c1c:	42 0f b6 84 15 93 f7 	movzbl -0x86d(%rbp,%r10,1),%eax
 1179c23:	ff ff 
 1179c25:	38 c8                	cmp    %cl,%al
 1179c27:	0f 83 6a ff ff ff    	jae    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 1179c2d:	c6 84 05 e0 f7 ff ff 	movb   $0x1,-0x820(%rbp,%rax,1)
 1179c34:	01 
 1179c35:	42 0f b6 84 15 94 f7 	movzbl -0x86c(%rbp,%r10,1),%eax
 1179c3c:	ff ff 
 1179c3e:	38 c8                	cmp    %cl,%al
 1179c40:	0f 83 51 ff ff ff    	jae    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 1179c46:	c6 84 05 e0 f7 ff ff 	movb   $0x1,-0x820(%rbp,%rax,1)
 1179c4d:	01 
 1179c4e:	42 0f b6 84 15 95 f7 	movzbl -0x86b(%rbp,%r10,1),%eax
 1179c55:	ff ff 
 1179c57:	38 c8                	cmp    %cl,%al
 1179c59:	0f 83 38 ff ff ff    	jae    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 1179c5f:	c6 84 05 e0 f7 ff ff 	movb   $0x1,-0x820(%rbp,%rax,1)
 1179c66:	01 
 1179c67:	42 0f b6 84 15 96 f7 	movzbl -0x86a(%rbp,%r10,1),%eax
 1179c6e:	ff ff 
 1179c70:	38 c8                	cmp    %cl,%al
 1179c72:	0f 83 1f ff ff ff    	jae    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 1179c78:	c6 84 05 e0 f7 ff ff 	movb   $0x1,-0x820(%rbp,%rax,1)
 1179c7f:	01 
 1179c80:	42 0f b6 84 15 97 f7 	movzbl -0x869(%rbp,%r10,1),%eax
 1179c87:	ff ff 
 1179c89:	38 c8                	cmp    %cl,%al
 1179c8b:	0f 83 06 ff ff ff    	jae    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 1179c91:	c6 84 05 e0 f7 ff ff 	movb   $0x1,-0x820(%rbp,%rax,1)
 1179c98:	01 
 1179c99:	49 83 c2 08          	add    $0x8,%r10
 1179c9d:	49 83 fa 40          	cmp    $0x40,%r10
 1179ca1:	0f 85 36 ff ff ff    	jne    1179bdd <br.encodeCommandPlanWithOptionsWrite+0x83d>
 1179ca7:	31 c0                	xor    %eax,%eax
 1179ca9:	80 bc 05 e0 f7 ff ff 	cmpb   $0x0,-0x820(%rbp,%rax,1)
 1179cb0:	00 
 1179cb1:	0f 84 e0 fe ff ff    	je     1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 1179cb7:	48 ff c0             	inc    %rax
 1179cba:	48 39 c1             	cmp    %rax,%rcx
 1179cbd:	75 ea                	jne    1179ca9 <br.encodeCommandPlanWithOptionsWrite+0x909>
 1179cbf:	41 80 e7 7f          	and    $0x7f,%r15b
 1179cc3:	45 31 d2             	xor    %r10d,%r10d
 1179cc6:	eb 1b                	jmp    1179ce3 <br.encodeCommandPlanWithOptionsWrite+0x943>
 1179cc8:	41 b2 01             	mov    $0x1,%r10b
 1179ccb:	4c 8d 25 67 86 e9 ff 	lea    -0x167999(%rip),%r12        # 1012339 <__anon_35262+0x9>
 1179cd2:	4c 8d 2d 57 86 e9 ff 	lea    -0x1679a9(%rip),%r13        # 1012330 <__anon_35262>
 1179cd9:	45 31 ff             	xor    %r15d,%r15d
 1179cdc:	44 8b 9d 44 ff ff ff 	mov    -0xbc(%rbp),%r11d
 1179ce3:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 1179ce7:	4c 89 8d 58 ff ff ff 	mov    %r9,-0xa8(%rbp)
 1179cee:	48 89 95 88 fd ff ff 	mov    %rdx,-0x278(%rbp)
 1179cf5:	0f 84 8b 00 00 00    	je     1179d86 <br.encodeCommandPlanWithOptionsWrite+0x9e6>
 1179cfb:	48 83 bd 70 ff ff ff 	cmpq   $0x0,-0x90(%rbp)
 1179d02:	00 
 1179d03:	0f 94 c0             	sete   %al
 1179d06:	41 84 c2             	test   %al,%r10b
 1179d09:	0f 84 88 fe ff ff    	je     1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 1179d0f:	48 83 bd 60 ff ff ff 	cmpq   $0x0,-0xa0(%rbp)
 1179d16:	00 
 1179d17:	0f 84 7a fe ff ff    	je     1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 1179d1d:	44 0f b6 4d c0       	movzbl -0x40(%rbp),%r9d
 1179d22:	45 84 c9             	test   %r9b,%r9b
 1179d25:	0f 95 c0             	setne  %al
 1179d28:	48 8b 95 28 ff ff ff 	mov    -0xd8(%rbp),%rdx
 1179d2f:	48 83 fa 02          	cmp    $0x2,%rdx
 1179d33:	0f 92 c1             	setb   %cl
 1179d36:	84 c8                	test   %cl,%al
 1179d38:	0f 85 59 fe ff ff    	jne    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 1179d3e:	48 89 d1             	mov    %rdx,%rcx
 1179d41:	45 84 c9             	test   %r9b,%r9b
 1179d44:	4c 89 6d 80          	mov    %r13,-0x80(%rbp)
 1179d48:	4c 89 bd b8 fd ff ff 	mov    %r15,-0x248(%rbp)
 1179d4f:	44 89 55 8c          	mov    %r10d,-0x74(%rbp)
 1179d53:	75 1b                	jne    1179d70 <br.encodeCommandPlanWithOptionsWrite+0x9d0>
 1179d55:	0f b6 4d c9          	movzbl -0x37(%rbp),%ecx
 1179d59:	89 c8                	mov    %ecx,%eax
 1179d5b:	0a 45 c2             	or     -0x3e(%rbp),%al
 1179d5e:	a8 01                	test   $0x1,%al
 1179d60:	0f 84 35 01 00 00    	je     1179e9b <br.encodeCommandPlanWithOptionsWrite+0xafb>
 1179d66:	0f b6 c9             	movzbl %cl,%ecx
 1179d69:	83 e1 01             	and    $0x1,%ecx
 1179d6c:	48 83 f1 03          	xor    $0x3,%rcx
 1179d70:	80 7d ca 00          	cmpb   $0x0,-0x36(%rbp)
 1179d74:	0f 84 cf 00 00 00    	je     1179e49 <br.encodeCommandPlanWithOptionsWrite+0xaa9>
 1179d7a:	b8 06 00 00 00       	mov    $0x6,%eax
 1179d7f:	31 d2                	xor    %edx,%edx
 1179d81:	e9 f2 00 00 00       	jmp    1179e78 <br.encodeCommandPlanWithOptionsWrite+0xad8>
 1179d86:	44 89 55 8c          	mov    %r10d,-0x74(%rbp)
 1179d8a:	48 83 bd 70 ff ff ff 	cmpq   $0x0,-0x90(%rbp)
 1179d91:	00 
 1179d92:	0f 85 ff fd ff ff    	jne    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 1179d98:	4c 89 85 f8 fd ff ff 	mov    %r8,-0x208(%rbp)
 1179d9f:	48 89 7d a0          	mov    %rdi,-0x60(%rbp)
 1179da3:	48 89 75 b8          	mov    %rsi,-0x48(%rbp)
 1179da7:	41 0f b6 fb          	movzbl %r11b,%edi
 1179dab:	0f b6 b5 00 ff ff ff 	movzbl -0x100(%rbp),%esi
 1179db2:	89 bd 2c fe ff ff    	mov    %edi,-0x1d4(%rbp)
 1179db8:	89 b5 30 fe ff ff    	mov    %esi,-0x1d0(%rbp)
 1179dbe:	31 d2                	xor    %edx,%edx
 1179dc0:	c5 f8 77             	vzeroupper 
 1179dc3:	e8 58 5c 04 00       	call   11bfa20 <br.encoder.distance.Parameters.activeAlphabetSize>
 1179dc8:	48 83 f8 4f          	cmp    $0x4f,%rax
 1179dcc:	0f 87 c5 fd ff ff    	ja     1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 1179dd2:	48 89 85 68 fa ff ff 	mov    %rax,-0x598(%rbp)
 1179dd9:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 1179ddd:	0f 84 17 05 00 00    	je     117a2fa <br.encodeCommandPlanWithOptionsWrite+0xf5a>
 1179de3:	48 83 bd 38 fe ff ff 	cmpq   $0x0,-0x1c8(%rbp)
 1179dea:	00 
 1179deb:	0f 84 a6 fd ff ff    	je     1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 1179df1:	0f b6 75 c1          	movzbl -0x3f(%rbp),%esi
 1179df5:	40 84 f6             	test   %sil,%sil
 1179df8:	0f 95 c0             	setne  %al
 1179dfb:	48 8b 95 68 ff ff ff 	mov    -0x98(%rbp),%rdx
 1179e02:	48 83 fa 02          	cmp    $0x2,%rdx
 1179e06:	0f 92 c1             	setb   %cl
 1179e09:	84 c8                	test   %cl,%al
 1179e0b:	0f 85 86 fd ff ff    	jne    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 1179e11:	48 89 d0             	mov    %rdx,%rax
 1179e14:	40 84 f6             	test   %sil,%sil
 1179e17:	75 1a                	jne    1179e33 <br.encodeCommandPlanWithOptionsWrite+0xa93>
 1179e19:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 1179e1d:	0a 45 c7             	or     -0x39(%rbp),%al
 1179e20:	a8 01                	test   $0x1,%al
 1179e22:	0f 84 39 02 00 00    	je     117a061 <br.encodeCommandPlanWithOptionsWrite+0xcc1>
 1179e28:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 1179e2c:	83 e0 01             	and    $0x1,%eax
 1179e2f:	48 83 f0 03          	xor    $0x3,%rax
 1179e33:	80 7d cd 00          	cmpb   $0x0,-0x33(%rbp)
 1179e37:	0f 84 51 02 00 00    	je     117a08e <br.encodeCommandPlanWithOptionsWrite+0xcee>
 1179e3d:	ba 06 00 00 00       	mov    $0x6,%edx
 1179e42:	31 c9                	xor    %ecx,%ecx
 1179e44:	e9 6a 02 00 00       	jmp    117a0b3 <br.encodeCommandPlanWithOptionsWrite+0xd13>
 1179e49:	4d 89 e5             	mov    %r12,%r13
 1179e4c:	44 0f b6 4d d1       	movzbl -0x2f(%rbp),%r9d
 1179e51:	b8 05 00 00 00       	mov    $0x5,%eax
 1179e56:	b2 01                	mov    $0x1,%dl
 1179e58:	45 84 c9             	test   %r9b,%r9b
 1179e5b:	75 18                	jne    1179e75 <br.encodeCommandPlanWithOptionsWrite+0xad5>
 1179e5d:	b8 04 00 00 00       	mov    $0x4,%eax
 1179e62:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 1179e66:	75 0d                	jne    1179e75 <br.encodeCommandPlanWithOptionsWrite+0xad5>
 1179e68:	80 7d c5 01          	cmpb   $0x1,-0x3b(%rbp)
 1179e6c:	b8 03 00 00 00       	mov    $0x3,%eax
 1179e71:	48 83 d8 00          	sbb    $0x0,%rax
 1179e75:	4d 89 ec             	mov    %r13,%r12
 1179e78:	48 39 c1             	cmp    %rax,%rcx
 1179e7b:	0f 87 16 fd ff ff    	ja     1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 1179e81:	4d 89 e5             	mov    %r12,%r13
 1179e84:	80 7d c0 00          	cmpb   $0x0,-0x40(%rbp)
 1179e88:	74 20                	je     1179eaa <br.encodeCommandPlanWithOptionsWrite+0xb0a>
 1179e8a:	0f b6 45 c9          	movzbl -0x37(%rbp),%eax
 1179e8e:	0a 45 c2             	or     -0x3e(%rbp),%al
 1179e91:	a8 01                	test   $0x1,%al
 1179e93:	0f 85 fe fc ff ff    	jne    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 1179e99:	eb 51                	jmp    1179eec <br.encodeCommandPlanWithOptionsWrite+0xb4c>
 1179e9b:	4d 89 e5             	mov    %r12,%r13
 1179e9e:	80 7d ca 00          	cmpb   $0x0,-0x36(%rbp)
 1179ea2:	0f 84 f0 00 00 00    	je     1179f98 <br.encodeCommandPlanWithOptionsWrite+0xbf8>
 1179ea8:	31 d2                	xor    %edx,%edx
 1179eaa:	f6 45 c9 01          	testb  $0x1,-0x37(%rbp)
 1179eae:	74 19                	je     1179ec9 <br.encodeCommandPlanWithOptionsWrite+0xb29>
 1179eb0:	0f b6 45 c2          	movzbl -0x3e(%rbp),%eax
 1179eb4:	f6 d0                	not    %al
 1179eb6:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 1179eba:	0f 94 c1             	sete   %cl
 1179ebd:	20 d0                	and    %dl,%al
 1179ebf:	20 c8                	and    %cl,%al
 1179ec1:	3c 01                	cmp    $0x1,%al
 1179ec3:	0f 85 ce fc ff ff    	jne    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 1179ec9:	f6 45 c2 01          	testb  $0x1,-0x3e(%rbp)
 1179ecd:	74 1d                	je     1179eec <br.encodeCommandPlanWithOptionsWrite+0xb4c>
 1179ecf:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 1179ed3:	0f 95 c0             	setne  %al
 1179ed6:	89 d1                	mov    %edx,%ecx
 1179ed8:	80 f1 01             	xor    $0x1,%cl
 1179edb:	08 c1                	or     %al,%cl
 1179edd:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 1179ee1:	0f 94 c0             	sete   %al
 1179ee4:	08 c8                	or     %cl,%al
 1179ee6:	0f 85 ab fc ff ff    	jne    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 1179eec:	80 7d c5 00          	cmpb   $0x0,-0x3b(%rbp)
 1179ef0:	74 23                	je     1179f15 <br.encodeCommandPlanWithOptionsWrite+0xb75>
 1179ef2:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 1179ef6:	0f 84 d0 00 00 00    	je     1179fcc <br.encodeCommandPlanWithOptionsWrite+0xc2c>
 1179efc:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 1179f00:	0f 94 c0             	sete   %al
 1179f03:	89 d1                	mov    %edx,%ecx
 1179f05:	80 f1 01             	xor    $0x1,%cl
 1179f08:	84 c8                	test   %cl,%al
 1179f0a:	0f 85 87 fc ff ff    	jne    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 1179f10:	e9 c4 00 00 00       	jmp    1179fd9 <br.encodeCommandPlanWithOptionsWrite+0xc39>
 1179f15:	0f b6 45 ca          	movzbl -0x36(%rbp),%eax
 1179f19:	0a 45 d1             	or     -0x2f(%rbp),%al
 1179f1c:	0a 45 cf             	or     -0x31(%rbp),%al
 1179f1f:	0f 85 72 fc ff ff    	jne    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 1179f25:	80 f2 01             	xor    $0x1,%dl
 1179f28:	0f b6 c2             	movzbl %dl,%eax
 1179f2b:	48 8d 0c 85 01 00 00 	lea    0x1(,%rax,4),%rcx
 1179f32:	00 
 1179f33:	31 d2                	xor    %edx,%edx
 1179f35:	48 8b 85 10 ff ff ff 	mov    -0xf0(%rbp),%rax
 1179f3c:	48 89 85 70 fd ff ff 	mov    %rax,-0x290(%rbp)
 1179f43:	48 8b 85 18 ff ff ff 	mov    -0xe8(%rbp),%rax
 1179f4a:	48 89 85 e8 fc ff ff 	mov    %rax,-0x318(%rbp)
 1179f51:	48 8b 85 20 ff ff ff 	mov    -0xe0(%rbp),%rax
 1179f58:	48 89 85 f0 fc ff ff 	mov    %rax,-0x310(%rbp)
 1179f5f:	48 8b 85 f0 fe ff ff 	mov    -0x110(%rbp),%rax
 1179f66:	48 89 85 f8 fc ff ff 	mov    %rax,-0x308(%rbp)
 1179f6d:	4c 8d 95 70 fd ff ff 	lea    -0x290(%rbp),%r10
 1179f74:	48 8d 05 9d fd e8 ff 	lea    -0x170263(%rip),%rax        # 1009d18 <__anon_240364+0x72b8>
 1179f7b:	4c 63 3c 90          	movslq (%rax,%rdx,4),%r15
 1179f7f:	49 01 c7             	add    %rax,%r15
 1179f82:	45 31 c9             	xor    %r9d,%r9d
 1179f85:	31 c0                	xor    %eax,%eax
 1179f87:	4c 8b 9d 60 ff ff ff 	mov    -0xa0(%rbp),%r11
 1179f8e:	4d 89 ec             	mov    %r13,%r12
 1179f91:	4c 8b 6d 80          	mov    -0x80(%rbp),%r13
 1179f95:	41 ff e7             	jmp    *%r15
 1179f98:	b9 05 00 00 00       	mov    $0x5,%ecx
 1179f9d:	44 0f b6 4d d1       	movzbl -0x2f(%rbp),%r9d
 1179fa2:	45 84 c9             	test   %r9b,%r9b
 1179fa5:	0f 85 a6 fe ff ff    	jne    1179e51 <br.encodeCommandPlanWithOptionsWrite+0xab1>
 1179fab:	b9 04 00 00 00       	mov    $0x4,%ecx
 1179fb0:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 1179fb4:	0f 85 97 fe ff ff    	jne    1179e51 <br.encodeCommandPlanWithOptionsWrite+0xab1>
 1179fba:	80 7d c5 01          	cmpb   $0x1,-0x3b(%rbp)
 1179fbe:	b9 03 00 00 00       	mov    $0x3,%ecx
 1179fc3:	48 83 d9 00          	sbb    $0x0,%rcx
 1179fc7:	e9 85 fe ff ff       	jmp    1179e51 <br.encodeCommandPlanWithOptionsWrite+0xab1>
 1179fcc:	0f b6 45 ca          	movzbl -0x36(%rbp),%eax
 1179fd0:	0a 45 d1             	or     -0x2f(%rbp),%al
 1179fd3:	0f 85 be fb ff ff    	jne    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 1179fd9:	b9 05 00 00 00       	mov    $0x5,%ecx
 1179fde:	84 d2                	test   %dl,%dl
 1179fe0:	74 1a                	je     1179ffc <br.encodeCommandPlanWithOptionsWrite+0xc5c>
 1179fe2:	80 7d cf 01          	cmpb   $0x1,-0x31(%rbp)
 1179fe6:	b8 03 00 00 00       	mov    $0x3,%eax
 1179feb:	48 83 d8 00          	sbb    $0x0,%rax
 1179fef:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 1179ff3:	b9 04 00 00 00       	mov    $0x4,%ecx
 1179ff8:	48 0f 44 c8          	cmove  %rax,%rcx
 1179ffc:	31 d2                	xor    %edx,%edx
 1179ffe:	48 8b 85 10 ff ff ff 	mov    -0xf0(%rbp),%rax
 117a005:	48 89 85 70 fd ff ff 	mov    %rax,-0x290(%rbp)
 117a00c:	48 8b 85 18 ff ff ff 	mov    -0xe8(%rbp),%rax
 117a013:	48 89 85 e8 fc ff ff 	mov    %rax,-0x318(%rbp)
 117a01a:	48 8b 85 20 ff ff ff 	mov    -0xe0(%rbp),%rax
 117a021:	48 89 85 f0 fc ff ff 	mov    %rax,-0x310(%rbp)
 117a028:	48 8b 85 f0 fe ff ff 	mov    -0x110(%rbp),%rax
 117a02f:	48 89 85 f8 fc ff ff 	mov    %rax,-0x308(%rbp)
 117a036:	4c 8d 95 70 fd ff ff 	lea    -0x290(%rbp),%r10
 117a03d:	48 8d 05 d4 fc e8 ff 	lea    -0x17032c(%rip),%rax        # 1009d18 <__anon_240364+0x72b8>
 117a044:	4c 63 3c 90          	movslq (%rax,%rdx,4),%r15
 117a048:	49 01 c7             	add    %rax,%r15
 117a04b:	45 31 c9             	xor    %r9d,%r9d
 117a04e:	31 c0                	xor    %eax,%eax
 117a050:	4c 8b 9d 60 ff ff ff 	mov    -0xa0(%rbp),%r11
 117a057:	4d 89 ec             	mov    %r13,%r12
 117a05a:	4c 8b 6d 80          	mov    -0x80(%rbp),%r13
 117a05e:	41 ff e7             	jmp    *%r15
 117a061:	80 7d cd 00          	cmpb   $0x0,-0x33(%rbp)
 117a065:	74 04                	je     117a06b <br.encodeCommandPlanWithOptionsWrite+0xccb>
 117a067:	31 c9                	xor    %ecx,%ecx
 117a069:	eb 68                	jmp    117a0d3 <br.encodeCommandPlanWithOptionsWrite+0xd33>
 117a06b:	b8 05 00 00 00       	mov    $0x5,%eax
 117a070:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 117a074:	75 18                	jne    117a08e <br.encodeCommandPlanWithOptionsWrite+0xcee>
 117a076:	b8 04 00 00 00       	mov    $0x4,%eax
 117a07b:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 117a07f:	75 0d                	jne    117a08e <br.encodeCommandPlanWithOptionsWrite+0xcee>
 117a081:	80 7d cb 01          	cmpb   $0x1,-0x35(%rbp)
 117a085:	b8 03 00 00 00       	mov    $0x3,%eax
 117a08a:	48 83 d8 00          	sbb    $0x0,%rax
 117a08e:	ba 05 00 00 00       	mov    $0x5,%edx
 117a093:	b1 01                	mov    $0x1,%cl
 117a095:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 117a099:	75 18                	jne    117a0b3 <br.encodeCommandPlanWithOptionsWrite+0xd13>
 117a09b:	ba 04 00 00 00       	mov    $0x4,%edx
 117a0a0:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 117a0a4:	75 0d                	jne    117a0b3 <br.encodeCommandPlanWithOptionsWrite+0xd13>
 117a0a6:	80 7d cb 01          	cmpb   $0x1,-0x35(%rbp)
 117a0aa:	ba 03 00 00 00       	mov    $0x3,%edx
 117a0af:	48 83 da 00          	sbb    $0x0,%rdx
 117a0b3:	48 39 d0             	cmp    %rdx,%rax
 117a0b6:	0f 87 db fa ff ff    	ja     1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117a0bc:	80 7d c1 00          	cmpb   $0x0,-0x3f(%rbp)
 117a0c0:	74 11                	je     117a0d3 <br.encodeCommandPlanWithOptionsWrite+0xd33>
 117a0c2:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 117a0c6:	0a 45 c7             	or     -0x39(%rbp),%al
 117a0c9:	a8 01                	test   $0x1,%al
 117a0cb:	0f 85 c6 fa ff ff    	jne    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117a0d1:	eb 42                	jmp    117a115 <br.encodeCommandPlanWithOptionsWrite+0xd75>
 117a0d3:	f6 45 d2 01          	testb  $0x1,-0x2e(%rbp)
 117a0d7:	74 19                	je     117a0f2 <br.encodeCommandPlanWithOptionsWrite+0xd52>
 117a0d9:	0f b6 45 c7          	movzbl -0x39(%rbp),%eax
 117a0dd:	f6 d0                	not    %al
 117a0df:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 117a0e3:	0f 94 c2             	sete   %dl
 117a0e6:	20 c8                	and    %cl,%al
 117a0e8:	20 d0                	and    %dl,%al
 117a0ea:	3c 01                	cmp    $0x1,%al
 117a0ec:	0f 85 a5 fa ff ff    	jne    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117a0f2:	f6 45 c7 01          	testb  $0x1,-0x39(%rbp)
 117a0f6:	74 1d                	je     117a115 <br.encodeCommandPlanWithOptionsWrite+0xd75>
 117a0f8:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 117a0fc:	0f 95 c0             	setne  %al
 117a0ff:	89 ca                	mov    %ecx,%edx
 117a101:	80 f2 01             	xor    $0x1,%dl
 117a104:	08 c2                	or     %al,%dl
 117a106:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 117a10a:	0f 94 c0             	sete   %al
 117a10d:	08 d0                	or     %dl,%al
 117a10f:	0f 85 82 fa ff ff    	jne    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117a115:	80 7d cb 00          	cmpb   $0x0,-0x35(%rbp)
 117a119:	74 23                	je     117a13e <br.encodeCommandPlanWithOptionsWrite+0xd9e>
 117a11b:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 117a11f:	0f 84 9c 00 00 00    	je     117a1c1 <br.encodeCommandPlanWithOptionsWrite+0xe21>
 117a125:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 117a129:	0f 94 c0             	sete   %al
 117a12c:	89 ca                	mov    %ecx,%edx
 117a12e:	80 f2 01             	xor    $0x1,%dl
 117a131:	84 d0                	test   %dl,%al
 117a133:	0f 85 5e fa ff ff    	jne    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117a139:	e9 90 00 00 00       	jmp    117a1ce <br.encodeCommandPlanWithOptionsWrite+0xe2e>
 117a13e:	0f b6 45 cd          	movzbl -0x33(%rbp),%eax
 117a142:	0a 45 d6             	or     -0x2a(%rbp),%al
 117a145:	0a 45 d0             	or     -0x30(%rbp),%al
 117a148:	0f 85 49 fa ff ff    	jne    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117a14e:	80 f1 01             	xor    $0x1,%cl
 117a151:	0f b6 c1             	movzbl %cl,%eax
 117a154:	48 8d 04 85 01 00 00 	lea    0x1(,%rax,4),%rax
 117a15b:	00 
 117a15c:	31 c9                	xor    %ecx,%ecx
 117a15e:	48 8b 95 c0 fd ff ff 	mov    -0x240(%rbp),%rdx
 117a165:	48 89 95 68 fd ff ff 	mov    %rdx,-0x298(%rbp)
 117a16c:	48 8b 95 c8 fd ff ff 	mov    -0x238(%rbp),%rdx
 117a173:	48 89 95 d0 fc ff ff 	mov    %rdx,-0x330(%rbp)
 117a17a:	48 8b 95 d0 fd ff ff 	mov    -0x230(%rbp),%rdx
 117a181:	48 89 95 d8 fc ff ff 	mov    %rdx,-0x328(%rbp)
 117a188:	48 8b 95 d8 fd ff ff 	mov    -0x228(%rbp),%rdx
 117a18f:	48 89 95 e0 fc ff ff 	mov    %rdx,-0x320(%rbp)
 117a196:	48 8d bd 68 fd ff ff 	lea    -0x298(%rbp),%rdi
 117a19d:	48 8d 15 88 fb e8 ff 	lea    -0x170478(%rip),%rdx        # 1009d2c <__anon_240364+0x72cc>
 117a1a4:	4c 63 14 8a          	movslq (%rdx,%rcx,4),%r10
 117a1a8:	49 01 d2             	add    %rdx,%r10
 117a1ab:	31 d2                	xor    %edx,%edx
 117a1ad:	45 31 c0             	xor    %r8d,%r8d
 117a1b0:	4c 8b 8d 38 fe ff ff 	mov    -0x1c8(%rbp),%r9
 117a1b7:	48 8b b5 58 ff ff ff 	mov    -0xa8(%rbp),%rsi
 117a1be:	41 ff e2             	jmp    *%r10
 117a1c1:	0f b6 45 cd          	movzbl -0x33(%rbp),%eax
 117a1c5:	0a 45 d6             	or     -0x2a(%rbp),%al
 117a1c8:	0f 85 c9 f9 ff ff    	jne    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117a1ce:	b8 05 00 00 00       	mov    $0x5,%eax
 117a1d3:	84 c9                	test   %cl,%cl
 117a1d5:	74 1a                	je     117a1f1 <br.encodeCommandPlanWithOptionsWrite+0xe51>
 117a1d7:	80 7d d0 01          	cmpb   $0x1,-0x30(%rbp)
 117a1db:	b9 03 00 00 00       	mov    $0x3,%ecx
 117a1e0:	48 83 d9 00          	sbb    $0x0,%rcx
 117a1e4:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 117a1e8:	b8 04 00 00 00       	mov    $0x4,%eax
 117a1ed:	48 0f 44 c1          	cmove  %rcx,%rax
 117a1f1:	31 c9                	xor    %ecx,%ecx
 117a1f3:	48 8b 95 c0 fd ff ff 	mov    -0x240(%rbp),%rdx
 117a1fa:	48 89 95 68 fd ff ff 	mov    %rdx,-0x298(%rbp)
 117a201:	48 8b 95 c8 fd ff ff 	mov    -0x238(%rbp),%rdx
 117a208:	48 89 95 d0 fc ff ff 	mov    %rdx,-0x330(%rbp)
 117a20f:	48 8b 95 d0 fd ff ff 	mov    -0x230(%rbp),%rdx
 117a216:	48 89 95 d8 fc ff ff 	mov    %rdx,-0x328(%rbp)
 117a21d:	48 8b 95 d8 fd ff ff 	mov    -0x228(%rbp),%rdx
 117a224:	48 89 95 e0 fc ff ff 	mov    %rdx,-0x320(%rbp)
 117a22b:	48 8d bd 68 fd ff ff 	lea    -0x298(%rbp),%rdi
 117a232:	48 8d 15 f3 fa e8 ff 	lea    -0x17050d(%rip),%rdx        # 1009d2c <__anon_240364+0x72cc>
 117a239:	4c 63 14 8a          	movslq (%rdx,%rcx,4),%r10
 117a23d:	49 01 d2             	add    %rdx,%r10
 117a240:	31 d2                	xor    %edx,%edx
 117a242:	45 31 c0             	xor    %r8d,%r8d
 117a245:	4c 8b 8d 38 fe ff ff 	mov    -0x1c8(%rbp),%r9
 117a24c:	48 8b b5 58 ff ff ff 	mov    -0xa8(%rbp),%rsi
 117a253:	41 ff e2             	jmp    *%r10
 117a256:	49 39 c3             	cmp    %rax,%r11
 117a259:	0f 86 38 f9 ff ff    	jbe    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117a25f:	4c 89 da             	mov    %r11,%rdx
 117a262:	49 ff c1             	inc    %r9
 117a265:	4c 39 c9             	cmp    %r9,%rcx
 117a268:	4c 8b 95 f0 fe ff ff 	mov    -0x110(%rbp),%r10
 117a26f:	44 8b 9d 44 ff ff ff 	mov    -0xbc(%rbp),%r11d
 117a276:	4c 8b bd b8 fd ff ff 	mov    -0x248(%rbp),%r15
 117a27d:	0f 84 15 fb ff ff    	je     1179d98 <br.encodeCommandPlanWithOptionsWrite+0x9f8>
 117a283:	48 8b 85 10 ff ff ff 	mov    -0xf0(%rbp),%rax
 117a28a:	48 89 85 70 fd ff ff 	mov    %rax,-0x290(%rbp)
 117a291:	48 8b 85 18 ff ff ff 	mov    -0xe8(%rbp),%rax
 117a298:	48 89 85 e8 fc ff ff 	mov    %rax,-0x318(%rbp)
 117a29f:	48 8b 85 20 ff ff ff 	mov    -0xe0(%rbp),%rax
 117a2a6:	48 89 85 f0 fc ff ff 	mov    %rax,-0x310(%rbp)
 117a2ad:	4c 89 95 f8 fc ff ff 	mov    %r10,-0x308(%rbp)
 117a2b4:	4c 8d 95 70 fd ff ff 	lea    -0x290(%rbp),%r10
 117a2bb:	48 8d 05 56 fa e8 ff 	lea    -0x1705aa(%rip),%rax        # 1009d18 <__anon_240364+0x72b8>
 117a2c2:	4e 63 3c 88          	movslq (%rax,%r9,4),%r15
 117a2c6:	49 01 c7             	add    %rax,%r15
 117a2c9:	48 89 d0             	mov    %rdx,%rax
 117a2cc:	4c 8b 9d 60 ff ff ff 	mov    -0xa0(%rbp),%r11
 117a2d3:	41 ff e7             	jmp    *%r15
 117a2d6:	4c 8d 95 e8 fc ff ff 	lea    -0x318(%rbp),%r10
 117a2dd:	eb 10                	jmp    117a2ef <br.encodeCommandPlanWithOptionsWrite+0xf4f>
 117a2df:	4c 8d 95 f0 fc ff ff 	lea    -0x310(%rbp),%r10
 117a2e6:	eb 07                	jmp    117a2ef <br.encodeCommandPlanWithOptionsWrite+0xf4f>
 117a2e8:	4c 8d 95 f8 fc ff ff 	lea    -0x308(%rbp),%r10
 117a2ef:	4d 8b 1a             	mov    (%r10),%r11
 117a2f2:	48 89 d0             	mov    %rdx,%rax
 117a2f5:	e9 5c ff ff ff       	jmp    117a256 <br.encodeCommandPlanWithOptionsWrite+0xeb6>
 117a2fa:	4c 89 bd b8 fd ff ff 	mov    %r15,-0x248(%rbp)
 117a301:	4c 89 6d 80          	mov    %r13,-0x80(%rbp)
 117a305:	4c 89 a5 28 fc ff ff 	mov    %r12,-0x3d8(%rbp)
 117a30c:	80 7d cc 00          	cmpb   $0x0,-0x34(%rbp)
 117a310:	0f 84 3f 02 00 00    	je     117a555 <br.encodeCommandPlanWithOptionsWrite+0x11b5>
 117a316:	48 83 bd c8 fe ff ff 	cmpq   $0x0,-0x138(%rbp)
 117a31d:	00 
 117a31e:	0f 84 73 f8 ff ff    	je     1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117a324:	80 7d c4 00          	cmpb   $0x0,-0x3c(%rbp)
 117a328:	0f 95 c0             	setne  %al
 117a32b:	48 83 bd 78 ff ff ff 	cmpq   $0x2,-0x88(%rbp)
 117a332:	02 
 117a333:	0f 92 c1             	setb   %cl
 117a336:	84 c8                	test   %cl,%al
 117a338:	0f 85 59 f8 ff ff    	jne    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117a33e:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 117a345:	80 7d c4 00          	cmpb   $0x0,-0x3c(%rbp)
 117a349:	75 16                	jne    117a361 <br.encodeCommandPlanWithOptionsWrite+0xfc1>
 117a34b:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 117a34f:	0a 45 c8             	or     -0x38(%rbp),%al
 117a352:	a8 01                	test   $0x1,%al
 117a354:	74 1a                	je     117a370 <br.encodeCommandPlanWithOptionsWrite+0xfd0>
 117a356:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 117a35a:	83 e0 01             	and    $0x1,%eax
 117a35d:	48 83 f0 03          	xor    $0x3,%rax
 117a361:	80 7d ce 00          	cmpb   $0x0,-0x32(%rbp)
 117a365:	74 36                	je     117a39d <br.encodeCommandPlanWithOptionsWrite+0xffd>
 117a367:	ba 06 00 00 00       	mov    $0x6,%edx
 117a36c:	31 c9                	xor    %ecx,%ecx
 117a36e:	eb 52                	jmp    117a3c2 <br.encodeCommandPlanWithOptionsWrite+0x1022>
 117a370:	80 7d ce 00          	cmpb   $0x0,-0x32(%rbp)
 117a374:	74 04                	je     117a37a <br.encodeCommandPlanWithOptionsWrite+0xfda>
 117a376:	31 c9                	xor    %ecx,%ecx
 117a378:	eb 68                	jmp    117a3e2 <br.encodeCommandPlanWithOptionsWrite+0x1042>
 117a37a:	b8 05 00 00 00       	mov    $0x5,%eax
 117a37f:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 117a383:	75 18                	jne    117a39d <br.encodeCommandPlanWithOptionsWrite+0xffd>
 117a385:	b8 04 00 00 00       	mov    $0x4,%eax
 117a38a:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 117a38e:	75 0d                	jne    117a39d <br.encodeCommandPlanWithOptionsWrite+0xffd>
 117a390:	80 7d d5 01          	cmpb   $0x1,-0x2b(%rbp)
 117a394:	b8 03 00 00 00       	mov    $0x3,%eax
 117a399:	48 83 d8 00          	sbb    $0x0,%rax
 117a39d:	ba 05 00 00 00       	mov    $0x5,%edx
 117a3a2:	b1 01                	mov    $0x1,%cl
 117a3a4:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 117a3a8:	75 18                	jne    117a3c2 <br.encodeCommandPlanWithOptionsWrite+0x1022>
 117a3aa:	ba 04 00 00 00       	mov    $0x4,%edx
 117a3af:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 117a3b3:	75 0d                	jne    117a3c2 <br.encodeCommandPlanWithOptionsWrite+0x1022>
 117a3b5:	80 7d d5 01          	cmpb   $0x1,-0x2b(%rbp)
 117a3b9:	ba 03 00 00 00       	mov    $0x3,%edx
 117a3be:	48 83 da 00          	sbb    $0x0,%rdx
 117a3c2:	48 39 d0             	cmp    %rdx,%rax
 117a3c5:	0f 87 cc f7 ff ff    	ja     1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117a3cb:	80 7d c4 00          	cmpb   $0x0,-0x3c(%rbp)
 117a3cf:	74 11                	je     117a3e2 <br.encodeCommandPlanWithOptionsWrite+0x1042>
 117a3d1:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 117a3d5:	0a 45 c8             	or     -0x38(%rbp),%al
 117a3d8:	a8 01                	test   $0x1,%al
 117a3da:	0f 85 b7 f7 ff ff    	jne    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117a3e0:	eb 42                	jmp    117a424 <br.encodeCommandPlanWithOptionsWrite+0x1084>
 117a3e2:	f6 45 d3 01          	testb  $0x1,-0x2d(%rbp)
 117a3e6:	74 19                	je     117a401 <br.encodeCommandPlanWithOptionsWrite+0x1061>
 117a3e8:	0f b6 45 c8          	movzbl -0x38(%rbp),%eax
 117a3ec:	f6 d0                	not    %al
 117a3ee:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 117a3f2:	0f 94 c2             	sete   %dl
 117a3f5:	20 c8                	and    %cl,%al
 117a3f7:	20 d0                	and    %dl,%al
 117a3f9:	3c 01                	cmp    $0x1,%al
 117a3fb:	0f 85 96 f7 ff ff    	jne    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117a401:	f6 45 c8 01          	testb  $0x1,-0x38(%rbp)
 117a405:	74 1d                	je     117a424 <br.encodeCommandPlanWithOptionsWrite+0x1084>
 117a407:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 117a40b:	0f 95 c0             	setne  %al
 117a40e:	89 ca                	mov    %ecx,%edx
 117a410:	80 f2 01             	xor    $0x1,%dl
 117a413:	08 c2                	or     %al,%dl
 117a415:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 117a419:	0f 94 c0             	sete   %al
 117a41c:	08 d0                	or     %dl,%al
 117a41e:	0f 85 73 f7 ff ff    	jne    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117a424:	80 7d d5 00          	cmpb   $0x0,-0x2b(%rbp)
 117a428:	74 23                	je     117a44d <br.encodeCommandPlanWithOptionsWrite+0x10ad>
 117a42a:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 117a42e:	0f 84 94 00 00 00    	je     117a4c8 <br.encodeCommandPlanWithOptionsWrite+0x1128>
 117a434:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 117a438:	0f 94 c0             	sete   %al
 117a43b:	89 ca                	mov    %ecx,%edx
 117a43d:	80 f2 01             	xor    $0x1,%dl
 117a440:	84 d0                	test   %dl,%al
 117a442:	0f 85 4f f7 ff ff    	jne    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117a448:	e9 88 00 00 00       	jmp    117a4d5 <br.encodeCommandPlanWithOptionsWrite+0x1135>
 117a44d:	0f b6 45 ce          	movzbl -0x32(%rbp),%eax
 117a451:	0a 45 d7             	or     -0x29(%rbp),%al
 117a454:	0a 45 d4             	or     -0x2c(%rbp),%al
 117a457:	0f 85 3a f7 ff ff    	jne    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117a45d:	80 f1 01             	xor    $0x1,%cl
 117a460:	0f b6 c1             	movzbl %cl,%eax
 117a463:	48 8d 04 85 01 00 00 	lea    0x1(,%rax,4),%rax
 117a46a:	00 
 117a46b:	31 c9                	xor    %ecx,%ecx
 117a46d:	48 8b 95 58 fe ff ff 	mov    -0x1a8(%rbp),%rdx
 117a474:	48 89 95 60 fd ff ff 	mov    %rdx,-0x2a0(%rbp)
 117a47b:	48 8b 95 60 fe ff ff 	mov    -0x1a0(%rbp),%rdx
 117a482:	48 89 95 b8 fc ff ff 	mov    %rdx,-0x348(%rbp)
 117a489:	48 8b 95 68 fe ff ff 	mov    -0x198(%rbp),%rdx
 117a490:	48 89 95 c0 fc ff ff 	mov    %rdx,-0x340(%rbp)
 117a497:	48 8b 95 70 fe ff ff 	mov    -0x190(%rbp),%rdx
 117a49e:	48 89 95 c8 fc ff ff 	mov    %rdx,-0x338(%rbp)
 117a4a5:	48 8d b5 60 fd ff ff 	lea    -0x2a0(%rbp),%rsi
 117a4ac:	48 8d 15 8d f8 e8 ff 	lea    -0x170773(%rip),%rdx        # 1009d40 <__anon_240364+0x72e0>
 117a4b3:	4c 63 0c 8a          	movslq (%rdx,%rcx,4),%r9
 117a4b7:	49 01 d1             	add    %rdx,%r9
 117a4ba:	31 d2                	xor    %edx,%edx
 117a4bc:	31 ff                	xor    %edi,%edi
 117a4be:	4c 8b 85 c8 fe ff ff 	mov    -0x138(%rbp),%r8
 117a4c5:	41 ff e1             	jmp    *%r9
 117a4c8:	0f b6 45 ce          	movzbl -0x32(%rbp),%eax
 117a4cc:	0a 45 d7             	or     -0x29(%rbp),%al
 117a4cf:	0f 85 c2 f6 ff ff    	jne    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117a4d5:	b8 05 00 00 00       	mov    $0x5,%eax
 117a4da:	84 c9                	test   %cl,%cl
 117a4dc:	74 1a                	je     117a4f8 <br.encodeCommandPlanWithOptionsWrite+0x1158>
 117a4de:	80 7d d4 01          	cmpb   $0x1,-0x2c(%rbp)
 117a4e2:	b9 03 00 00 00       	mov    $0x3,%ecx
 117a4e7:	48 83 d9 00          	sbb    $0x0,%rcx
 117a4eb:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 117a4ef:	b8 04 00 00 00       	mov    $0x4,%eax
 117a4f4:	48 0f 44 c1          	cmove  %rcx,%rax
 117a4f8:	31 c9                	xor    %ecx,%ecx
 117a4fa:	48 8b 95 58 fe ff ff 	mov    -0x1a8(%rbp),%rdx
 117a501:	48 89 95 60 fd ff ff 	mov    %rdx,-0x2a0(%rbp)
 117a508:	48 8b 95 60 fe ff ff 	mov    -0x1a0(%rbp),%rdx
 117a50f:	48 89 95 b8 fc ff ff 	mov    %rdx,-0x348(%rbp)
 117a516:	48 8b 95 68 fe ff ff 	mov    -0x198(%rbp),%rdx
 117a51d:	48 89 95 c0 fc ff ff 	mov    %rdx,-0x340(%rbp)
 117a524:	48 8b 95 70 fe ff ff 	mov    -0x190(%rbp),%rdx
 117a52b:	48 89 95 c8 fc ff ff 	mov    %rdx,-0x338(%rbp)
 117a532:	48 8d b5 60 fd ff ff 	lea    -0x2a0(%rbp),%rsi
 117a539:	48 8d 15 00 f8 e8 ff 	lea    -0x170800(%rip),%rdx        # 1009d40 <__anon_240364+0x72e0>
 117a540:	4c 63 0c 8a          	movslq (%rdx,%rcx,4),%r9
 117a544:	49 01 d1             	add    %rdx,%r9
 117a547:	31 d2                	xor    %edx,%edx
 117a549:	31 ff                	xor    %edi,%edi
 117a54b:	4c 8b 85 c8 fe ff ff 	mov    -0x138(%rbp),%r8
 117a552:	41 ff e1             	jmp    *%r9
 117a555:	48 8d 05 2c 7e e9 ff 	lea    -0x1681d4(%rip),%rax        # 1012388 <__anon_35510>
 117a55c:	48 8d 35 25 82 e9 ff 	lea    -0x167ddb(%rip),%rsi        # 1012788 <__anon_16727>
 117a563:	f6 45 90 01          	testb  $0x1,-0x70(%rbp)
 117a567:	48 0f 45 f0          	cmovne %rax,%rsi
 117a56b:	48 8d bd b0 c0 ff ff 	lea    -0x3f50(%rbp),%rdi
 117a572:	ba 00 04 00 00       	mov    $0x400,%edx
 117a577:	e8 44 bb 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117a57c:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 117a580:	c5 fc 11 85 a0 f3 ff 	vmovups %ymm0,-0xc60(%rbp)
 117a587:	ff 
 117a588:	48 c7 85 c8 d5 ff ff 	movq   $0x0,-0x2a38(%rbp)
 117a58f:	00 00 00 00 
 117a593:	80 7d 8c 00          	cmpb   $0x0,-0x74(%rbp)
 117a597:	75 16                	jne    117a5af <br.encodeCommandPlanWithOptionsWrite+0x120f>
 117a599:	48 8d bd 50 ba fb ff 	lea    -0x445b0(%rbp),%rdi
 117a5a0:	ba 00 00 01 00       	mov    $0x10000,%edx
 117a5a5:	31 f6                	xor    %esi,%esi
 117a5a7:	c5 f8 77             	vzeroupper 
 117a5aa:	e8 f1 b6 11 00       	call   1295ca0 <compiler_rt.memset>
 117a5af:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 117a5b3:	74 16                	je     117a5cb <br.encodeCommandPlanWithOptionsWrite+0x122b>
 117a5b5:	48 8d bd e8 e4 fe ff 	lea    -0x11b18(%rbp),%rdi
 117a5bc:	ba 00 18 00 00       	mov    $0x1800,%edx
 117a5c1:	31 f6                	xor    %esi,%esi
 117a5c3:	c5 f8 77             	vzeroupper 
 117a5c6:	e8 d5 b6 11 00       	call   1295ca0 <compiler_rt.memset>
 117a5cb:	48 c7 85 b0 c5 ff ff 	movq   $0x0,-0x3a50(%rbp)
 117a5d2:	00 00 00 00 
 117a5d6:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 117a5da:	74 16                	je     117a5f2 <br.encodeCommandPlanWithOptionsWrite+0x1252>
 117a5dc:	48 8d bd d4 01 fe ff 	lea    -0x1fe2c(%rbp),%rdi
 117a5e3:	ba 00 42 00 00       	mov    $0x4200,%edx
 117a5e8:	31 f6                	xor    %esi,%esi
 117a5ea:	c5 f8 77             	vzeroupper 
 117a5ed:	e8 ae b6 11 00       	call   1295ca0 <compiler_rt.memset>
 117a5f2:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 117a5f6:	c5 fc 11 85 3c ec ff 	vmovups %ymm0,-0x13c4(%rbp)
 117a5fd:	ff 
 117a5fe:	c5 fc 11 85 20 ec ff 	vmovups %ymm0,-0x13e0(%rbp)
 117a605:	ff 
 117a606:	c5 fc 11 85 00 ec ff 	vmovups %ymm0,-0x1400(%rbp)
 117a60d:	ff 
 117a60e:	c5 fc 11 85 e0 eb ff 	vmovups %ymm0,-0x1420(%rbp)
 117a615:	ff 
 117a616:	c5 fc 11 85 c0 eb ff 	vmovups %ymm0,-0x1440(%rbp)
 117a61d:	ff 
 117a61e:	c5 fc 11 85 a0 eb ff 	vmovups %ymm0,-0x1460(%rbp)
 117a625:	ff 
 117a626:	c5 fc 11 85 80 eb ff 	vmovups %ymm0,-0x1480(%rbp)
 117a62d:	ff 
 117a62e:	c5 fc 11 85 60 eb ff 	vmovups %ymm0,-0x14a0(%rbp)
 117a635:	ff 
 117a636:	c5 fc 11 85 40 eb ff 	vmovups %ymm0,-0x14c0(%rbp)
 117a63d:	ff 
 117a63e:	c5 fc 11 85 20 eb ff 	vmovups %ymm0,-0x14e0(%rbp)
 117a645:	ff 
 117a646:	80 7d cc 00          	cmpb   $0x0,-0x34(%rbp)
 117a64a:	74 16                	je     117a662 <br.encodeCommandPlanWithOptionsWrite+0x12c2>
 117a64c:	48 8d bd a0 9e ff ff 	lea    -0x6160(%rbp),%rdi
 117a653:	ba 68 07 00 00       	mov    $0x768,%edx
 117a658:	31 f6                	xor    %esi,%esi
 117a65a:	c5 f8 77             	vzeroupper 
 117a65d:	e8 3e b6 11 00       	call   1295ca0 <compiler_rt.memset>
 117a662:	84 db                	test   %bl,%bl
 117a664:	74 04                	je     117a66a <br.encodeCommandPlanWithOptionsWrite+0x12ca>
 117a666:	31 c0                	xor    %eax,%eax
 117a668:	eb 1c                	jmp    117a686 <br.encodeCommandPlanWithOptionsWrite+0x12e6>
 117a66a:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 117a66e:	0f 94 c0             	sete   %al
 117a671:	0f b6 95 ec fe ff ff 	movzbl -0x114(%rbp),%edx
 117a678:	f6 d2                	not    %dl
 117a67a:	8b 8d 78 fd ff ff    	mov    -0x288(%rbp),%ecx
 117a680:	20 d1                	and    %dl,%cl
 117a682:	20 c1                	and    %al,%cl
 117a684:	89 c8                	mov    %ecx,%eax
 117a686:	80 7d cc 00          	cmpb   $0x0,-0x34(%rbp)
 117a68a:	0f 94 c1             	sete   %cl
 117a68d:	20 c1                	and    %al,%cl
 117a68f:	88 8d 30 fd ff ff    	mov    %cl,-0x2d0(%rbp)
 117a695:	48 8d bd 98 37 ff ff 	lea    -0xc868(%rbp),%rdi
 117a69c:	45 31 e4             	xor    %r12d,%r12d
 117a69f:	ba 00 09 00 00       	mov    $0x900,%edx
 117a6a4:	31 f6                	xor    %esi,%esi
 117a6a6:	c5 f8 77             	vzeroupper 
 117a6a9:	e8 f2 b5 11 00       	call   1295ca0 <compiler_rt.memset>
 117a6ae:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 117a6b2:	c5 fc 11 85 f0 dc ff 	vmovups %ymm0,-0x2310(%rbp)
 117a6b9:	ff 
 117a6ba:	c5 fc 11 85 10 dd ff 	vmovups %ymm0,-0x22f0(%rbp)
 117a6c1:	ff 
 117a6c2:	c5 fc 11 85 30 dd ff 	vmovups %ymm0,-0x22d0(%rbp)
 117a6c9:	ff 
 117a6ca:	c5 fc 11 85 50 dd ff 	vmovups %ymm0,-0x22b0(%rbp)
 117a6d1:	ff 
 117a6d2:	c5 fc 11 85 70 dd ff 	vmovups %ymm0,-0x2290(%rbp)
 117a6d9:	ff 
 117a6da:	c5 fc 11 85 90 dd ff 	vmovups %ymm0,-0x2270(%rbp)
 117a6e1:	ff 
 117a6e2:	c5 fc 11 85 b0 dd ff 	vmovups %ymm0,-0x2250(%rbp)
 117a6e9:	ff 
 117a6ea:	c5 fc 11 85 d0 dd ff 	vmovups %ymm0,-0x2230(%rbp)
 117a6f1:	ff 
 117a6f2:	c5 fc 11 85 f0 dd ff 	vmovups %ymm0,-0x2210(%rbp)
 117a6f9:	ff 
 117a6fa:	c5 fc 11 85 0c de ff 	vmovups %ymm0,-0x21f4(%rbp)
 117a701:	ff 
 117a702:	c5 fc 10 85 b0 f0 ff 	vmovups -0xf50(%rbp),%ymm0
 117a709:	ff 
 117a70a:	c5 fc 11 85 40 fd ff 	vmovups %ymm0,-0x2c0(%rbp)
 117a711:	ff 
 117a712:	0f b6 05 6f 84 e9 ff 	movzbl -0x167b91(%rip),%eax        # 1012b88 <__anon_35632>
 117a719:	88 45 9f             	mov    %al,-0x61(%rbp)
 117a71c:	8b 85 b4 fd ff ff    	mov    -0x24c(%rbp),%eax
 117a722:	c1 e8 08             	shr    $0x8,%eax
 117a725:	89 85 ec fe ff ff    	mov    %eax,-0x114(%rbp)
 117a72b:	48 8d 85 c8 d5 ff ff 	lea    -0x2a38(%rbp),%rax
 117a732:	48 89 85 48 fc ff ff 	mov    %rax,-0x3b8(%rbp)
 117a739:	48 8d 85 b0 c0 ff ff 	lea    -0x3f50(%rbp),%rax
 117a740:	48 89 85 40 fc ff ff 	mov    %rax,-0x3c0(%rbp)
 117a747:	48 8d 85 8c 7f ff ff 	lea    -0x8074(%rbp),%rax
 117a74e:	48 89 85 38 fc ff ff 	mov    %rax,-0x3c8(%rbp)
 117a755:	48 c7 85 38 fd ff ff 	movq   $0x0,-0x2c8(%rbp)
 117a75c:	00 00 00 00 
 117a760:	48 c7 45 90 00 00 00 	movq   $0x0,-0x70(%rbp)
 117a767:	00 
 117a768:	48 c7 85 08 ff ff ff 	movq   $0x0,-0xf8(%rbp)
 117a76f:	00 00 00 00 
 117a773:	48 c7 85 30 fc ff ff 	movq   $0x0,-0x3d0(%rbp)
 117a77a:	00 00 00 00 
 117a77e:	48 8b 8d f8 fd ff ff 	mov    -0x208(%rbp),%rcx
 117a785:	e9 83 01 00 00       	jmp    117a90d <br.encodeCommandPlanWithOptionsWrite+0x156d>
 117a78a:	8b 85 a3 fe ff ff    	mov    -0x15d(%rbp),%eax
 117a790:	48 8d 8d 69 f6 ff ff 	lea    -0x997(%rbp),%rcx
 117a797:	89 41 03             	mov    %eax,0x3(%rcx)
 117a79a:	8b 85 a0 fe ff ff    	mov    -0x160(%rbp),%eax
 117a7a0:	89 01                	mov    %eax,(%rcx)
 117a7a2:	8b 85 ab fe ff ff    	mov    -0x155(%rbp),%eax
 117a7a8:	89 41 13             	mov    %eax,0x13(%rcx)
 117a7ab:	8b 85 a8 fe ff ff    	mov    -0x158(%rbp),%eax
 117a7b1:	89 41 10             	mov    %eax,0x10(%rcx)
 117a7b4:	8b 85 b3 fe ff ff    	mov    -0x14d(%rbp),%eax
 117a7ba:	89 41 23             	mov    %eax,0x23(%rcx)
 117a7bd:	8b 85 b0 fe ff ff    	mov    -0x150(%rbp),%eax
 117a7c3:	89 41 20             	mov    %eax,0x20(%rcx)
 117a7c6:	8b 85 bb fe ff ff    	mov    -0x145(%rbp),%eax
 117a7cc:	89 41 33             	mov    %eax,0x33(%rcx)
 117a7cf:	8b 85 b8 fe ff ff    	mov    -0x148(%rbp),%eax
 117a7d5:	89 41 30             	mov    %eax,0x30(%rcx)
 117a7d8:	8b 85 c3 fe ff ff    	mov    -0x13d(%rbp),%eax
 117a7de:	89 41 43             	mov    %eax,0x43(%rcx)
 117a7e1:	8b 85 c0 fe ff ff    	mov    -0x140(%rbp),%eax
 117a7e7:	89 41 40             	mov    %eax,0x40(%rcx)
 117a7ea:	0f b7 85 e8 fe ff ff 	movzwl -0x118(%rbp),%eax
 117a7f1:	66 89 41 55          	mov    %ax,0x55(%rcx)
 117a7f5:	8b 85 e4 fe ff ff    	mov    -0x11c(%rbp),%eax
 117a7fb:	89 41 51             	mov    %eax,0x51(%rcx)
 117a7fe:	48 8b 85 c8 fe ff ff 	mov    -0x138(%rbp),%rax
 117a805:	48 89 85 58 f6 ff ff 	mov    %rax,-0x9a8(%rbp)
 117a80c:	48 8b 85 58 fe ff ff 	mov    -0x1a8(%rbp),%rax
 117a813:	48 89 85 60 f6 ff ff 	mov    %rax,-0x9a0(%rbp)
 117a81a:	40 88 b5 68 f6 ff ff 	mov    %sil,-0x998(%rbp)
 117a821:	48 8b 85 60 fe ff ff 	mov    -0x1a0(%rbp),%rax
 117a828:	48 89 85 70 f6 ff ff 	mov    %rax,-0x990(%rbp)
 117a82f:	0f b6 45 d4          	movzbl -0x2c(%rbp),%eax
 117a833:	88 85 78 f6 ff ff    	mov    %al,-0x988(%rbp)
 117a839:	48 8b 85 68 fe ff ff 	mov    -0x198(%rbp),%rax
 117a840:	48 89 85 80 f6 ff ff 	mov    %rax,-0x980(%rbp)
 117a847:	0f b6 45 d7          	movzbl -0x29(%rbp),%eax
 117a84b:	88 85 88 f6 ff ff    	mov    %al,-0x978(%rbp)
 117a851:	48 8b 85 70 fe ff ff 	mov    -0x190(%rbp),%rax
 117a858:	48 89 85 90 f6 ff ff 	mov    %rax,-0x970(%rbp)
 117a85f:	0f b6 45 ce          	movzbl -0x32(%rbp),%eax
 117a863:	88 85 98 f6 ff ff    	mov    %al,-0x968(%rbp)
 117a869:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 117a870:	48 89 85 a0 f6 ff ff 	mov    %rax,-0x960(%rbp)
 117a877:	0f b6 45 c4          	movzbl -0x3c(%rbp),%eax
 117a87b:	88 85 a8 f6 ff ff    	mov    %al,-0x958(%rbp)
 117a881:	48 8b 85 20 fd ff ff 	mov    -0x2e0(%rbp),%rax
 117a888:	48 89 85 b0 f6 ff ff 	mov    %rax,-0x950(%rbp)
 117a88f:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 117a893:	88 85 b8 f6 ff ff    	mov    %al,-0x948(%rbp)
 117a899:	0f b6 45 c8          	movzbl -0x38(%rbp),%eax
 117a89d:	88 85 b9 f6 ff ff    	mov    %al,-0x947(%rbp)
 117a8a3:	48 8d bd 58 f6 ff ff 	lea    -0x9a8(%rbp),%rdi
 117a8aa:	4c 8b bd 38 fd ff ff 	mov    -0x2c8(%rbp),%r15
 117a8b1:	4c 89 fe             	mov    %r15,%rsi
 117a8b4:	c5 f8 77             	vzeroupper 
 117a8b7:	e8 94 36 04 00       	call   11bdf50 <br.encoder.distance_block_split.Result.blockIndex>
 117a8bc:	48 8b 8d f8 fd ff ff 	mov    -0x208(%rbp),%rcx
 117a8c3:	48 8b 95 58 ff ff ff 	mov    -0xa8(%rbp),%rdx
 117a8ca:	48 69 c0 3c 01 00 00 	imul   $0x13c,%rax,%rax
 117a8d1:	48 01 e8             	add    %rbp,%rax
 117a8d4:	48 05 a0 9e ff ff    	add    $0xffffffffffff9ea0,%rax
 117a8da:	ff 04 98             	incl   (%rax,%rbx,4)
 117a8dd:	49 ff c7             	inc    %r15
 117a8e0:	4c 89 bd 38 fd ff ff 	mov    %r15,-0x2c8(%rbp)
 117a8e7:	80 7d 8c 00          	cmpb   $0x0,-0x74(%rbp)
 117a8eb:	0f 84 7e 02 00 00    	je     117ab6f <br.encodeCommandPlanWithOptionsWrite+0x17cf>
 117a8f1:	c5 fc 10 85 70 ef ff 	vmovups -0x1090(%rbp),%ymm0
 117a8f8:	ff 
 117a8f9:	c5 fc 11 85 40 fd ff 	vmovups %ymm0,-0x2c0(%rbp)
 117a900:	ff 
 117a901:	49 ff c4             	inc    %r12
 117a904:	49 39 d4             	cmp    %rdx,%r12
 117a907:	0f 84 7b 09 00 00    	je     117b288 <br.encodeCommandPlanWithOptionsWrite+0x1ee8>
 117a90d:	4c 89 a5 00 ff ff ff 	mov    %r12,-0x100(%rbp)
 117a914:	4b 8d 04 64          	lea    (%r12,%r12,2),%rax
 117a918:	48 c1 e0 05          	shl    $0x5,%rax
 117a91c:	c5 fc 10 04 01       	vmovups (%rcx,%rax,1),%ymm0
 117a921:	c5 fc 10 4c 01 20    	vmovups 0x20(%rcx,%rax,1),%ymm1
 117a927:	c5 fc 10 54 01 40    	vmovups 0x40(%rcx,%rax,1),%ymm2
 117a92d:	c5 fc 11 85 d0 f2 ff 	vmovups %ymm0,-0xd30(%rbp)
 117a934:	ff 
 117a935:	c5 fc 11 95 10 f3 ff 	vmovups %ymm2,-0xcf0(%rbp)
 117a93c:	ff 
 117a93d:	c5 fc 11 8d f0 f2 ff 	vmovups %ymm1,-0xd10(%rbp)
 117a944:	ff 
 117a945:	48 8b 85 d0 f2 ff ff 	mov    -0xd30(%rbp),%rax
 117a94c:	48 89 85 70 ff ff ff 	mov    %rax,-0x90(%rbp)
 117a953:	4c 8b a5 d8 f2 ff ff 	mov    -0xd28(%rbp),%r12
 117a95a:	4c 8b ad e0 f2 ff ff 	mov    -0xd20(%rbp),%r13
 117a961:	0f b6 8d 28 f3 ff ff 	movzbl -0xcd8(%rbp),%ecx
 117a968:	0f b6 85 29 f3 ff ff 	movzbl -0xcd7(%rbp),%eax
 117a96f:	88 45 b7             	mov    %al,-0x49(%rbp)
 117a972:	88 8d 40 fe ff ff    	mov    %cl,-0x1c0(%rbp)
 117a978:	f6 c1 01             	test   $0x1,%cl
 117a97b:	74 44                	je     117a9c1 <br.encodeCommandPlanWithOptionsWrite+0x1621>
 117a97d:	0f b6 95 f8 fe ff ff 	movzbl -0x108(%rbp),%edx
 117a984:	48 8d bd c8 f9 ff ff 	lea    -0x638(%rbp),%rdi
 117a98b:	48 8d b5 d0 f2 ff ff 	lea    -0xd30(%rbp),%rsi
 117a992:	48 8b 8d 20 fc ff ff 	mov    -0x3e0(%rbp),%rcx
 117a999:	4c 8b 85 18 fc ff ff 	mov    -0x3e8(%rbp),%r8
 117a9a0:	c5 f8 77             	vzeroupper 
 117a9a3:	e8 78 4a 04 00       	call   11bf420 <br.commandWireDistance>
 117a9a8:	0f b7 85 d0 f9 ff ff 	movzwl -0x630(%rbp),%eax
 117a9af:	66 85 c0             	test   %ax,%ax
 117a9b2:	0f 85 55 ea ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117a9b8:	48 8b 95 c8 f9 ff ff 	mov    -0x638(%rbp),%rdx
 117a9bf:	eb 02                	jmp    117a9c3 <br.encodeCommandPlanWithOptionsWrite+0x1623>
 117a9c1:	31 d2                	xor    %edx,%edx
 117a9c3:	48 83 ec 08          	sub    $0x8,%rsp
 117a9c7:	48 8d bd c8 f3 ff ff 	lea    -0xc38(%rbp),%rdi
 117a9ce:	48 8d b5 d0 f2 ff ff 	lea    -0xd30(%rbp),%rsi
 117a9d5:	48 89 95 d0 fe ff ff 	mov    %rdx,-0x130(%rbp)
 117a9dc:	8b 8d 2c fe ff ff    	mov    -0x1d4(%rbp),%ecx
 117a9e2:	44 8b 85 30 fe ff ff 	mov    -0x1d0(%rbp),%r8d
 117a9e9:	4c 8d 8d 40 fd ff ff 	lea    -0x2c0(%rbp),%r9
 117a9f0:	6a 00                	push   $0x0
 117a9f2:	c5 f8 77             	vzeroupper 
 117a9f5:	e8 76 45 04 00       	call   11bef70 <br.resolveHqCommand>
 117a9fa:	48 83 c4 10          	add    $0x10,%rsp
 117a9fe:	0f b7 85 10 f4 ff ff 	movzwl -0xbf0(%rbp),%eax
 117aa05:	66 85 c0             	test   %ax,%ax
 117aa08:	0f 85 ff e9 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117aa0e:	c5 fc 10 85 c8 f3 ff 	vmovups -0xc38(%rbp),%ymm0
 117aa15:	ff 
 117aa16:	c5 fc 10 8d d2 f3 ff 	vmovups -0xc2e(%rbp),%ymm1
 117aa1d:	ff 
 117aa1e:	c5 fc 11 8d 7a ef ff 	vmovups %ymm1,-0x1086(%rbp)
 117aa25:	ff 
 117aa26:	c5 fc 11 85 70 ef ff 	vmovups %ymm0,-0x1090(%rbp)
 117aa2d:	ff 
 117aa2e:	0f b6 85 f2 f3 ff ff 	movzbl -0xc0e(%rbp),%eax
 117aa35:	88 45 b6             	mov    %al,-0x4a(%rbp)
 117aa38:	0f b7 9d f4 f3 ff ff 	movzwl -0xc0c(%rbp),%ebx
 117aa3f:	48 8b 85 f8 f3 ff ff 	mov    -0xc08(%rbp),%rax
 117aa46:	48 89 85 90 fd ff ff 	mov    %rax,-0x270(%rbp)
 117aa4d:	0f b6 85 00 f4 ff ff 	movzbl -0xc00(%rbp),%eax
 117aa54:	88 85 10 fd ff ff    	mov    %al,-0x2f0(%rbp)
 117aa5a:	0f b6 85 08 f4 ff ff 	movzbl -0xbf8(%rbp),%eax
 117aa61:	88 45 8c             	mov    %al,-0x74(%rbp)
 117aa64:	84 c0                	test   %al,%al
 117aa66:	74 31                	je     117aa99 <br.encodeCommandPlanWithOptionsWrite+0x16f9>
 117aa68:	0f b6 8d 04 f4 ff ff 	movzbl -0xbfc(%rbp),%ecx
 117aa6f:	0f b6 85 05 f4 ff ff 	movzbl -0xbfb(%rbp),%eax
 117aa76:	88 8d 37 ff ff ff    	mov    %cl,-0xc9(%rbp)
 117aa7c:	88 85 38 ff ff ff    	mov    %al,-0xc8(%rbp)
 117aa82:	48 8d 8d 38 ff ff ff 	lea    -0xc8(%rbp),%rcx
 117aa89:	48 89 8d 98 fd ff ff 	mov    %rcx,-0x268(%rbp)
 117aa90:	48 8d 8d 37 ff ff ff 	lea    -0xc9(%rbp),%rcx
 117aa97:	eb 6b                	jmp    117ab04 <br.encodeCommandPlanWithOptionsWrite+0x1764>
 117aa99:	0f b6 45 9d          	movzbl -0x63(%rbp),%eax
 117aa9d:	22 85 40 fe ff ff    	and    -0x1c0(%rbp),%al
 117aaa3:	0f b6 4d b7          	movzbl -0x49(%rbp),%ecx
 117aaa7:	80 e1 03             	and    $0x3,%cl
 117aaaa:	80 f9 02             	cmp    $0x2,%cl
 117aaad:	0f 95 c1             	setne  %cl
 117aab0:	20 c1                	and    %al,%cl
 117aab2:	48 8d 05 c8 fe e8 ff 	lea    -0x170138(%rip),%rax        # 100a981 <__anon_2888+0x1>
 117aab9:	48 89 85 98 fd ff ff 	mov    %rax,-0x268(%rbp)
 117aac0:	48 8d 05 b9 fe e8 ff 	lea    -0x170147(%rip),%rax        # 100a980 <__anon_2888>
 117aac7:	80 f9 01             	cmp    $0x1,%cl
 117aaca:	48 89 c1             	mov    %rax,%rcx
 117aacd:	75 31                	jne    117ab00 <br.encodeCommandPlanWithOptionsWrite+0x1760>
 117aacf:	4c 8d bd a8 fd ff ff 	lea    -0x258(%rbp),%r15
 117aad6:	4c 89 ff             	mov    %r15,%rdi
 117aad9:	48 8b b5 d0 fe ff ff 	mov    -0x130(%rbp),%rsi
 117aae0:	48 8d 95 40 fd ff ff 	lea    -0x2c0(%rbp),%rdx
 117aae7:	c5 f8 77             	vzeroupper 
 117aaea:	e8 01 43 04 00       	call   11bedf0 <br.decoder.distance_history.symbolForDistance>
 117aaef:	48 8d 85 a9 fd ff ff 	lea    -0x257(%rbp),%rax
 117aaf6:	48 89 85 98 fd ff ff 	mov    %rax,-0x268(%rbp)
 117aafd:	4c 89 f9             	mov    %r15,%rcx
 117ab00:	0f b6 41 01          	movzbl 0x1(%rcx),%eax
 117ab04:	84 c0                	test   %al,%al
 117ab06:	48 89 8d 28 fd ff ff 	mov    %rcx,-0x2d8(%rbp)
 117ab0d:	74 16                	je     117ab25 <br.encodeCommandPlanWithOptionsWrite+0x1785>
 117ab0f:	0f b6 05 72 80 e9 ff 	movzbl -0x167f8e(%rip),%eax        # 1012b88 <__anon_35632>
 117ab16:	24 0f                	and    $0xf,%al
 117ab18:	0f b6 09             	movzbl (%rcx),%ecx
 117ab1b:	80 e1 0f             	and    $0xf,%cl
 117ab1e:	38 c1                	cmp    %al,%cl
 117ab20:	0f 94 c0             	sete   %al
 117ab23:	eb 02                	jmp    117ab27 <br.encodeCommandPlanWithOptionsWrite+0x1787>
 117ab25:	31 c0                	xor    %eax,%eax
 117ab27:	80 7d 8c 00          	cmpb   $0x0,-0x74(%rbp)
 117ab2b:	0f 85 a3 00 00 00    	jne    117abd4 <br.encodeCommandPlanWithOptionsWrite+0x1834>
 117ab31:	0f b6 c8             	movzbl %al,%ecx
 117ab34:	48 8d bd ec f9 ff ff 	lea    -0x614(%rbp),%rdi
 117ab3b:	4c 89 e6             	mov    %r12,%rsi
 117ab3e:	4c 89 ea             	mov    %r13,%rdx
 117ab41:	c5 f8 77             	vzeroupper 
 117ab44:	e8 b7 41 04 00       	call   11bed00 <br.commandEntryForLengthsAndDistance>
 117ab49:	80 bd fc f9 ff ff 00 	cmpb   $0x0,-0x604(%rbp)
 117ab50:	74 4f                	je     117aba1 <br.encodeCommandPlanWithOptionsWrite+0x1801>
 117ab52:	0f b6 85 f6 f9 ff ff 	movzbl -0x60a(%rbp),%eax
 117ab59:	0f b7 9d f8 f9 ff ff 	movzwl -0x608(%rbp),%ebx
 117ab60:	88 85 3c ff ff ff    	mov    %al,-0xc4(%rbp)
 117ab66:	48 8d 85 3c ff ff ff 	lea    -0xc4(%rbp),%rax
 117ab6d:	eb 5f                	jmp    117abce <br.encodeCommandPlanWithOptionsWrite+0x182e>
 117ab6f:	48 8b 85 98 fd ff ff 	mov    -0x268(%rbp),%rax
 117ab76:	80 38 00             	cmpb   $0x0,(%rax)
 117ab79:	0f 84 54 06 00 00    	je     117b1d3 <br.encodeCommandPlanWithOptionsWrite+0x1e33>
 117ab7f:	0f b6 05 02 80 e9 ff 	movzbl -0x167ffe(%rip),%eax        # 1012b88 <__anon_35632>
 117ab86:	24 0f                	and    $0xf,%al
 117ab88:	48 8b b5 28 fd ff ff 	mov    -0x2d8(%rbp),%rsi
 117ab8f:	0f b6 36             	movzbl (%rsi),%esi
 117ab92:	40 80 e6 0f          	and    $0xf,%sil
 117ab96:	40 38 c6             	cmp    %al,%sil
 117ab99:	0f 95 c0             	setne  %al
 117ab9c:	e9 34 06 00 00       	jmp    117b1d5 <br.encodeCommandPlanWithOptionsWrite+0x1e35>
 117aba1:	48 8d bd d8 f9 ff ff 	lea    -0x628(%rbp),%rdi
 117aba8:	4c 89 e6             	mov    %r12,%rsi
 117abab:	4c 89 ea             	mov    %r13,%rdx
 117abae:	e8 dd 3c 04 00       	call   11be890 <br.commandEntryForLengths>
 117abb3:	80 bd e8 f9 ff ff 00 	cmpb   $0x0,-0x618(%rbp)
 117abba:	0f 84 d7 ef ff ff    	je     1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117abc0:	0f b7 9d e4 f9 ff ff 	movzwl -0x61c(%rbp),%ebx
 117abc7:	48 8d 85 e2 f9 ff ff 	lea    -0x61e(%rbp),%rax
 117abce:	0f b6 00             	movzbl (%rax),%eax
 117abd1:	88 45 b6             	mov    %al,-0x4a(%rbp)
 117abd4:	48 8d 0d af 7f e9 ff 	lea    -0x168051(%rip),%rcx        # 1012b8a <__anon_35653>
 117abdb:	80 bd 30 fd ff ff 00 	cmpb   $0x0,-0x2d0(%rbp)
 117abe2:	74 2a                	je     117ac0e <br.encodeCommandPlanWithOptionsWrite+0x186e>
 117abe4:	48 8b 8d 58 fd ff ff 	mov    -0x2a8(%rbp),%rcx
 117abeb:	4c 8d bd bd fb ff ff 	lea    -0x443(%rbp),%r15
 117abf2:	4c 89 ff             	mov    %r15,%rdi
 117abf5:	48 8d b5 d0 f2 ff ff 	lea    -0xd30(%rbp),%rsi
 117abfc:	48 8b 95 d0 fe ff ff 	mov    -0x130(%rbp),%rdx
 117ac03:	c5 f8 77             	vzeroupper 
 117ac06:	e8 c5 3b 04 00       	call   11be7d0 <br.sameLastDistanceShape>
 117ac0b:	4c 89 f9             	mov    %r15,%rcx
 117ac0e:	0f b6 41 02          	movzbl 0x2(%rcx),%eax
 117ac12:	88 85 34 fe ff ff    	mov    %al,-0x1cc(%rbp)
 117ac18:	84 c0                	test   %al,%al
 117ac1a:	48 8b 85 58 ff ff ff 	mov    -0xa8(%rbp),%rax
 117ac21:	74 2a                	je     117ac4d <br.encodeCommandPlanWithOptionsWrite+0x18ad>
 117ac23:	0f b6 11             	movzbl (%rcx),%edx
 117ac26:	0f b6 49 01          	movzbl 0x1(%rcx),%ecx
 117ac2a:	83 e2 1f             	and    $0x1f,%edx
 117ac2d:	48 8d 14 52          	lea    (%rdx,%rdx,2),%rdx
 117ac31:	c1 e2 05             	shl    $0x5,%edx
 117ac34:	48 01 ea             	add    %rbp,%rdx
 117ac37:	48 81 c2 98 37 ff ff 	add    $0xffffffffffff3798,%rdx
 117ac3e:	83 e1 1f             	and    $0x1f,%ecx
 117ac41:	ff 04 8a             	incl   (%rdx,%rcx,4)
 117ac44:	b1 01                	mov    $0x1,%cl
 117ac46:	48 89 8d 08 ff ff ff 	mov    %rcx,-0xf8(%rbp)
 117ac4d:	48 3d 80 00 00 00    	cmp    $0x80,%rax
 117ac53:	77 0f                	ja     117ac64 <br.encodeCommandPlanWithOptionsWrite+0x18c4>
 117ac55:	48 8b 85 00 ff ff ff 	mov    -0x100(%rbp),%rax
 117ac5c:	66 89 9c 45 b0 c4 ff 	mov    %bx,-0x3b50(%rbp,%rax,2)
 117ac63:	ff 
 117ac64:	44 0f b7 fb          	movzwl %bx,%r15d
 117ac68:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 117ac6c:	0f 84 4f 01 00 00    	je     117adc1 <br.encodeCommandPlanWithOptionsWrite+0x1a21>
 117ac72:	8b 85 7b fe ff ff    	mov    -0x185(%rbp),%eax
 117ac78:	48 8d 8d 39 f7 ff ff 	lea    -0x8c7(%rbp),%rcx
 117ac7f:	89 41 03             	mov    %eax,0x3(%rcx)
 117ac82:	8b 85 78 fe ff ff    	mov    -0x188(%rbp),%eax
 117ac88:	89 01                	mov    %eax,(%rcx)
 117ac8a:	8b 85 83 fe ff ff    	mov    -0x17d(%rbp),%eax
 117ac90:	89 41 13             	mov    %eax,0x13(%rcx)
 117ac93:	8b 85 80 fe ff ff    	mov    -0x180(%rbp),%eax
 117ac99:	89 41 10             	mov    %eax,0x10(%rcx)
 117ac9c:	8b 85 8b fe ff ff    	mov    -0x175(%rbp),%eax
 117aca2:	89 41 23             	mov    %eax,0x23(%rcx)
 117aca5:	8b 85 88 fe ff ff    	mov    -0x178(%rbp),%eax
 117acab:	89 41 20             	mov    %eax,0x20(%rcx)
 117acae:	8b 85 93 fe ff ff    	mov    -0x16d(%rbp),%eax
 117acb4:	89 41 33             	mov    %eax,0x33(%rcx)
 117acb7:	8b 85 90 fe ff ff    	mov    -0x170(%rbp),%eax
 117acbd:	89 41 30             	mov    %eax,0x30(%rcx)
 117acc0:	8b 85 9b fe ff ff    	mov    -0x165(%rbp),%eax
 117acc6:	89 41 43             	mov    %eax,0x43(%rcx)
 117acc9:	8b 85 98 fe ff ff    	mov    -0x168(%rbp),%eax
 117accf:	89 41 40             	mov    %eax,0x40(%rcx)
 117acd2:	0f b7 85 e0 fe ff ff 	movzwl -0x120(%rbp),%eax
 117acd9:	66 89 41 55          	mov    %ax,0x55(%rcx)
 117acdd:	8b 85 dc fe ff ff    	mov    -0x124(%rbp),%eax
 117ace3:	89 41 51             	mov    %eax,0x51(%rcx)
 117ace6:	48 8b 85 38 fe ff ff 	mov    -0x1c8(%rbp),%rax
 117aced:	48 89 85 28 f7 ff ff 	mov    %rax,-0x8d8(%rbp)
 117acf4:	48 8b 85 c0 fd ff ff 	mov    -0x240(%rbp),%rax
 117acfb:	48 89 85 30 f7 ff ff 	mov    %rax,-0x8d0(%rbp)
 117ad02:	0f b6 45 cb          	movzbl -0x35(%rbp),%eax
 117ad06:	88 85 38 f7 ff ff    	mov    %al,-0x8c8(%rbp)
 117ad0c:	48 8b 85 c8 fd ff ff 	mov    -0x238(%rbp),%rax
 117ad13:	48 89 85 40 f7 ff ff 	mov    %rax,-0x8c0(%rbp)
 117ad1a:	0f b6 45 d0          	movzbl -0x30(%rbp),%eax
 117ad1e:	88 85 48 f7 ff ff    	mov    %al,-0x8b8(%rbp)
 117ad24:	48 8b 85 d0 fd ff ff 	mov    -0x230(%rbp),%rax
 117ad2b:	48 89 85 50 f7 ff ff 	mov    %rax,-0x8b0(%rbp)
 117ad32:	0f b6 45 d6          	movzbl -0x2a(%rbp),%eax
 117ad36:	88 85 58 f7 ff ff    	mov    %al,-0x8a8(%rbp)
 117ad3c:	48 8b 85 d8 fd ff ff 	mov    -0x228(%rbp),%rax
 117ad43:	48 89 85 60 f7 ff ff 	mov    %rax,-0x8a0(%rbp)
 117ad4a:	0f b6 45 cd          	movzbl -0x33(%rbp),%eax
 117ad4e:	88 85 68 f7 ff ff    	mov    %al,-0x898(%rbp)
 117ad54:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 117ad5b:	48 89 85 70 f7 ff ff 	mov    %rax,-0x890(%rbp)
 117ad62:	0f b6 45 c1          	movzbl -0x3f(%rbp),%eax
 117ad66:	88 85 78 f7 ff ff    	mov    %al,-0x888(%rbp)
 117ad6c:	48 8b 85 18 fd ff ff 	mov    -0x2e8(%rbp),%rax
 117ad73:	48 89 85 80 f7 ff ff 	mov    %rax,-0x880(%rbp)
 117ad7a:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 117ad7e:	88 85 88 f7 ff ff    	mov    %al,-0x878(%rbp)
 117ad84:	0f b6 45 c7          	movzbl -0x39(%rbp),%eax
 117ad88:	88 85 89 f7 ff ff    	mov    %al,-0x877(%rbp)
 117ad8e:	48 8d bd 28 f7 ff ff 	lea    -0x8d8(%rbp),%rdi
 117ad95:	48 8b b5 00 ff ff ff 	mov    -0x100(%rbp),%rsi
 117ad9c:	c5 f8 77             	vzeroupper 
 117ad9f:	e8 9c 38 04 00       	call   11be640 <br.encoder.command_block_split.Result.blockIndex>
 117ada4:	48 69 c0 00 0b 00 00 	imul   $0xb00,%rax,%rax
 117adab:	48 01 e8             	add    %rbp,%rax
 117adae:	48 05 d4 01 fe ff    	add    $0xfffffffffffe01d4,%rax
 117adb4:	42 ff 04 b8          	incl   (%rax,%r15,4)
 117adb8:	48 8b 9d 70 ff ff ff 	mov    -0x90(%rbp),%rbx
 117adbf:	eb 29                	jmp    117adea <br.encodeCommandPlanWithOptionsWrite+0x1a4a>
 117adc1:	48 8d bd b0 c5 ff ff 	lea    -0x3a50(%rbp),%rdi
 117adc8:	48 8d b5 8c 7f ff ff 	lea    -0x8074(%rbp),%rsi
 117adcf:	4c 89 fa             	mov    %r15,%rdx
 117add2:	c5 f8 77             	vzeroupper 
 117add5:	e8 56 9f ff ff       	call   1174d30 <br.encoder.command_plan.PrefixAlphabetFor(704).recordFrequency>
 117adda:	66 85 c0             	test   %ax,%ax
 117addd:	48 8b 9d 70 ff ff ff 	mov    -0x90(%rbp),%rbx
 117ade4:	0f 85 23 e6 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117adea:	4d 85 e4             	test   %r12,%r12
 117aded:	48 8b 8d f8 fd ff ff 	mov    -0x208(%rbp),%rcx
 117adf4:	48 8b 85 88 fd ff ff 	mov    -0x278(%rbp),%rax
 117adfb:	0f b6 75 d5          	movzbl -0x2b(%rbp),%esi
 117adff:	0f 84 08 03 00 00    	je     117b10d <br.encodeCommandPlanWithOptionsWrite+0x1d6d>
 117ae05:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 117ae09:	0f 84 36 02 00 00    	je     117b045 <br.encodeCommandPlanWithOptionsWrite+0x1ca5>
 117ae0f:	48 01 c3             	add    %rax,%rbx
 117ae12:	48 89 9d 70 ff ff ff 	mov    %rbx,-0x90(%rbp)
 117ae19:	31 db                	xor    %ebx,%ebx
 117ae1b:	4c 89 a5 78 fd ff ff 	mov    %r12,-0x288(%rbp)
 117ae22:	44 0f b6 65 ca       	movzbl -0x36(%rbp),%r12d
 117ae27:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 117ae2b:	4c 8d ad d1 f6 ff ff 	lea    -0x92f(%rbp),%r13
 117ae32:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 117ae39:	44 0f b6 3c 18       	movzbl (%rax,%rbx,1),%r15d
 117ae3e:	8b 85 07 fe ff ff    	mov    -0x1f9(%rbp),%eax
 117ae44:	41 89 45 03          	mov    %eax,0x3(%r13)
 117ae48:	8b 85 04 fe ff ff    	mov    -0x1fc(%rbp),%eax
 117ae4e:	41 89 45 00          	mov    %eax,0x0(%r13)
 117ae52:	8b 85 0f fe ff ff    	mov    -0x1f1(%rbp),%eax
 117ae58:	41 89 45 13          	mov    %eax,0x13(%r13)
 117ae5c:	8b 85 0c fe ff ff    	mov    -0x1f4(%rbp),%eax
 117ae62:	41 89 45 10          	mov    %eax,0x10(%r13)
 117ae66:	8b 85 17 fe ff ff    	mov    -0x1e9(%rbp),%eax
 117ae6c:	41 89 45 23          	mov    %eax,0x23(%r13)
 117ae70:	8b 85 14 fe ff ff    	mov    -0x1ec(%rbp),%eax
 117ae76:	41 89 45 20          	mov    %eax,0x20(%r13)
 117ae7a:	8b 85 1f fe ff ff    	mov    -0x1e1(%rbp),%eax
 117ae80:	41 89 45 33          	mov    %eax,0x33(%r13)
 117ae84:	8b 85 1c fe ff ff    	mov    -0x1e4(%rbp),%eax
 117ae8a:	41 89 45 30          	mov    %eax,0x30(%r13)
 117ae8e:	8b 85 27 fe ff ff    	mov    -0x1d9(%rbp),%eax
 117ae94:	41 89 45 43          	mov    %eax,0x43(%r13)
 117ae98:	8b 85 24 fe ff ff    	mov    -0x1dc(%rbp),%eax
 117ae9e:	41 89 45 40          	mov    %eax,0x40(%r13)
 117aea2:	0f b7 85 4c fe ff ff 	movzwl -0x1b4(%rbp),%eax
 117aea9:	66 41 89 45 55       	mov    %ax,0x55(%r13)
 117aeae:	8b 85 48 fe ff ff    	mov    -0x1b8(%rbp),%eax
 117aeb4:	41 89 45 51          	mov    %eax,0x51(%r13)
 117aeb8:	48 8d 34 19          	lea    (%rcx,%rbx,1),%rsi
 117aebc:	48 8b 85 60 ff ff ff 	mov    -0xa0(%rbp),%rax
 117aec3:	48 89 85 c0 f6 ff ff 	mov    %rax,-0x940(%rbp)
 117aeca:	48 8b 85 10 ff ff ff 	mov    -0xf0(%rbp),%rax
 117aed1:	48 89 85 c8 f6 ff ff 	mov    %rax,-0x938(%rbp)
 117aed8:	0f b6 45 c5          	movzbl -0x3b(%rbp),%eax
 117aedc:	88 85 d0 f6 ff ff    	mov    %al,-0x930(%rbp)
 117aee2:	48 8b 85 18 ff ff ff 	mov    -0xe8(%rbp),%rax
 117aee9:	48 89 85 d8 f6 ff ff 	mov    %rax,-0x928(%rbp)
 117aef0:	0f b6 45 cf          	movzbl -0x31(%rbp),%eax
 117aef4:	88 85 e0 f6 ff ff    	mov    %al,-0x920(%rbp)
 117aefa:	48 8b 85 20 ff ff ff 	mov    -0xe0(%rbp),%rax
 117af01:	48 89 85 e8 f6 ff ff 	mov    %rax,-0x918(%rbp)
 117af08:	0f b6 45 d1          	movzbl -0x2f(%rbp),%eax
 117af0c:	88 85 f0 f6 ff ff    	mov    %al,-0x910(%rbp)
 117af12:	48 8b 85 f0 fe ff ff 	mov    -0x110(%rbp),%rax
 117af19:	48 89 85 f8 f6 ff ff 	mov    %rax,-0x908(%rbp)
 117af20:	44 88 a5 00 f7 ff ff 	mov    %r12b,-0x900(%rbp)
 117af27:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 117af2e:	48 89 85 08 f7 ff ff 	mov    %rax,-0x8f8(%rbp)
 117af35:	0f b6 45 c0          	movzbl -0x40(%rbp),%eax
 117af39:	88 85 10 f7 ff ff    	mov    %al,-0x8f0(%rbp)
 117af3f:	48 8b 85 00 fd ff ff 	mov    -0x300(%rbp),%rax
 117af46:	48 89 85 18 f7 ff ff 	mov    %rax,-0x8e8(%rbp)
 117af4d:	0f b6 45 c9          	movzbl -0x37(%rbp),%eax
 117af51:	88 85 20 f7 ff ff    	mov    %al,-0x8e0(%rbp)
 117af57:	0f b6 45 c2          	movzbl -0x3e(%rbp),%eax
 117af5b:	88 85 21 f7 ff ff    	mov    %al,-0x8df(%rbp)
 117af61:	48 8d bd c0 f6 ff ff 	lea    -0x940(%rbp),%rdi
 117af68:	e8 e3 2f 04 00       	call   11bdf50 <br.encoder.distance_block_split.Result.blockIndex>
 117af6d:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 117af71:	c1 e0 0a             	shl    $0xa,%eax
 117af74:	48 01 e8             	add    %rbp,%rax
 117af77:	48 05 e8 e4 fe ff    	add    $0xfffffffffffee4e8,%rax
 117af7d:	42 ff 04 b8          	incl   (%rax,%r15,4)
 117af81:	48 ff c3             	inc    %rbx
 117af84:	48 39 9d 78 fd ff ff 	cmp    %rbx,-0x288(%rbp)
 117af8b:	0f 85 a1 fe ff ff    	jne    117ae32 <br.encodeCommandPlanWithOptionsWrite+0x1a92>
 117af91:	48 01 d9             	add    %rbx,%rcx
 117af94:	48 89 4d 90          	mov    %rcx,-0x70(%rbp)
 117af98:	48 8b 95 58 ff ff ff 	mov    -0xa8(%rbp),%rdx
 117af9f:	48 8b 8d f8 fd ff ff 	mov    -0x208(%rbp),%rcx
 117afa6:	0f b6 75 d5          	movzbl -0x2b(%rbp),%esi
 117afaa:	e9 65 01 00 00       	jmp    117b114 <br.encodeCommandPlanWithOptionsWrite+0x1d74>
 117afaf:	0f b6 0e             	movzbl (%rsi),%ecx
 117afb2:	8b 95 ec fe ff ff    	mov    -0x114(%rbp),%edx
 117afb8:	49 89 dc             	mov    %rbx,%r12
 117afbb:	0f b6 d8             	movzbl %al,%ebx
 117afbe:	0f b6 f1             	movzbl %cl,%esi
 117afc1:	0f b6 d2             	movzbl %dl,%edx
 117afc4:	89 df                	mov    %ebx,%edi
 117afc6:	c5 f8 77             	vzeroupper 
 117afc9:	e8 e2 33 04 00       	call   11be3b0 <br.encoder.literal_context.value>
 117afce:	48 8b 8d 70 ff ff ff 	mov    -0x90(%rbp),%rcx
 117afd5:	48 89 8d 50 fc ff ff 	mov    %rcx,-0x3b0(%rbp)
 117afdc:	88 9d 58 fc ff ff    	mov    %bl,-0x3a8(%rbp)
 117afe2:	4c 89 e3             	mov    %r12,%rbx
 117afe5:	48 8b 8d 0f f2 ff ff 	mov    -0xdf1(%rbp),%rcx
 117afec:	48 8d 95 59 fc ff ff 	lea    -0x3a7(%rbp),%rdx
 117aff3:	48 89 4a 3f          	mov    %rcx,0x3f(%rdx)
 117aff7:	c5 fc 10 85 d0 f1 ff 	vmovups -0xe30(%rbp),%ymm0
 117affe:	ff 
 117afff:	c5 fc 10 8d f0 f1 ff 	vmovups -0xe10(%rbp),%ymm1
 117b006:	ff 
 117b007:	c5 fc 11 4a 20       	vmovups %ymm1,0x20(%rdx)
 117b00c:	c5 fc 11 02          	vmovups %ymm0,(%rdx)
 117b010:	0f b6 84 05 5a fc ff 	movzbl -0x3a6(%rbp,%rax,1),%eax
 117b017:	ff 
 117b018:	c1 e0 0a             	shl    $0xa,%eax
 117b01b:	48 01 e8             	add    %rbp,%rax
 117b01e:	48 05 50 ba fb ff    	add    $0xfffffffffffbba50,%rax
 117b024:	42 ff 04 b8          	incl   (%rax,%r15,4)
 117b028:	48 8b 95 58 ff ff ff 	mov    -0xa8(%rbp),%rdx
 117b02f:	4d 89 ec             	mov    %r13,%r12
 117b032:	48 ff c3             	inc    %rbx
 117b035:	49 ff cc             	dec    %r12
 117b038:	48 8b 85 88 fd ff ff 	mov    -0x278(%rbp),%rax
 117b03f:	0f 84 5a ff ff ff    	je     117af9f <br.encodeCommandPlanWithOptionsWrite+0x1bff>
 117b045:	44 0f b6 3c 18       	movzbl (%rax,%rbx,1),%r15d
 117b04a:	48 8d bd c8 d5 ff ff 	lea    -0x2a38(%rbp),%rdi
 117b051:	48 8d b5 b0 c0 ff ff 	lea    -0x3f50(%rbp),%rsi
 117b058:	48 8d 95 a0 f3 ff ff 	lea    -0xc60(%rbp),%rdx
 117b05f:	44 89 f9             	mov    %r15d,%ecx
 117b062:	c5 f8 77             	vzeroupper 
 117b065:	e8 26 9d ff ff       	call   1174d90 <br.encoder.command_plan.PrefixAlphabetFor(256).recordByteFrequency>
 117b06a:	66 85 c0             	test   %ax,%ax
 117b06d:	0f 85 9a e3 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117b073:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 117b077:	80 78 50 00          	cmpb   $0x0,0x50(%rax)
 117b07b:	48 8b 95 58 ff ff ff 	mov    -0xa8(%rbp),%rdx
 117b082:	74 ae                	je     117b032 <br.encodeCommandPlanWithOptionsWrite+0x1c92>
 117b084:	4d 89 e5             	mov    %r12,%r13
 117b087:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 117b08b:	48 8b 08             	mov    (%rax),%rcx
 117b08e:	48 89 8d 70 ff ff ff 	mov    %rcx,-0x90(%rbp)
 117b095:	0f b6 40 08          	movzbl 0x8(%rax),%eax
 117b099:	48 8b b5 28 fc ff ff 	mov    -0x3d8(%rbp),%rsi
 117b0a0:	c5 fc 10 06          	vmovups (%rsi),%ymm0
 117b0a4:	c5 fc 10 4e 20       	vmovups 0x20(%rsi),%ymm1
 117b0a9:	8b 4e 40             	mov    0x40(%rsi),%ecx
 117b0ac:	0f b7 56 44          	movzwl 0x44(%rsi),%edx
 117b0b0:	0f b6 76 46          	movzbl 0x46(%rsi),%esi
 117b0b4:	40 88 b5 16 f2 ff ff 	mov    %sil,-0xdea(%rbp)
 117b0bb:	66 89 95 14 f2 ff ff 	mov    %dx,-0xdec(%rbp)
 117b0c2:	89 8d 10 f2 ff ff    	mov    %ecx,-0xdf0(%rbp)
 117b0c8:	c5 fc 11 8d f0 f1 ff 	vmovups %ymm1,-0xe10(%rbp)
 117b0cf:	ff 
 117b0d0:	c5 fc 11 85 d0 f1 ff 	vmovups %ymm0,-0xe30(%rbp)
 117b0d7:	ff 
 117b0d8:	8b 8d ec fe ff ff    	mov    -0x114(%rbp),%ecx
 117b0de:	8b 95 b4 fd ff ff    	mov    -0x24c(%rbp),%edx
 117b0e4:	48 85 db             	test   %rbx,%rbx
 117b0e7:	48 8b b5 88 fd ff ff 	mov    -0x278(%rbp),%rsi
 117b0ee:	0f 84 c4 fe ff ff    	je     117afb8 <br.encodeCommandPlanWithOptionsWrite+0x1c18>
 117b0f4:	48 83 fb 01          	cmp    $0x1,%rbx
 117b0f8:	0f 84 b1 fe ff ff    	je     117afaf <br.encodeCommandPlanWithOptionsWrite+0x1c0f>
 117b0fe:	0f b6 54 1e fe       	movzbl -0x2(%rsi,%rbx,1),%edx
 117b103:	0f b6 4c 1e ff       	movzbl -0x1(%rsi,%rbx,1),%ecx
 117b108:	e9 ab fe ff ff       	jmp    117afb8 <br.encodeCommandPlanWithOptionsWrite+0x1c18>
 117b10d:	48 8b 95 58 ff ff ff 	mov    -0xa8(%rbp),%rdx
 117b114:	f6 85 40 fe ff ff 01 	testb  $0x1,-0x1c0(%rbp)
 117b11b:	4c 8b a5 00 ff ff ff 	mov    -0x100(%rbp),%r12
 117b122:	48 8b bd 90 fd ff ff 	mov    -0x270(%rbp),%rdi
 117b129:	0f 84 d2 f7 ff ff    	je     117a901 <br.encodeCommandPlanWithOptionsWrite+0x1561>
 117b12f:	0f b6 45 b6          	movzbl -0x4a(%rbp),%eax
 117b133:	f6 d0                	not    %al
 117b135:	a8 03                	test   $0x3,%al
 117b137:	0f 85 aa f7 ff ff    	jne    117a8e7 <br.encodeCommandPlanWithOptionsWrite+0x1547>
 117b13d:	80 7d 8c 00          	cmpb   $0x0,-0x74(%rbp)
 117b141:	74 24                	je     117b167 <br.encodeCommandPlanWithOptionsWrite+0x1dc7>
 117b143:	80 bd 10 fd ff ff 00 	cmpb   $0x0,-0x2f0(%rbp)
 117b14a:	0f 84 47 ea ff ff    	je     1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117b150:	48 89 f8             	mov    %rdi,%rax
 117b153:	48 c1 e8 20          	shr    $0x20,%rax
 117b157:	66 83 f8 4e          	cmp    $0x4e,%ax
 117b15b:	0f 87 36 ea ff ff    	ja     1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117b161:	48 c1 ef 30          	shr    $0x30,%rdi
 117b165:	eb 34                	jmp    117b19b <br.encodeCommandPlanWithOptionsWrite+0x1dfb>
 117b167:	48 8b 85 98 fd ff ff 	mov    -0x268(%rbp),%rax
 117b16e:	80 38 00             	cmpb   $0x0,(%rax)
 117b171:	0f 84 a9 00 00 00    	je     117b220 <br.encodeCommandPlanWithOptionsWrite+0x1e80>
 117b177:	48 8b 85 28 fd ff ff 	mov    -0x2d8(%rbp),%rax
 117b17e:	0f b6 00             	movzbl (%rax),%eax
 117b181:	83 e0 0f             	and    $0xf,%eax
 117b184:	c6 85 b2 fd ff ff 00 	movb   $0x0,-0x24e(%rbp)
 117b18b:	31 ff                	xor    %edi,%edi
 117b18d:	48 8b 95 58 ff ff ff 	mov    -0xa8(%rbp),%rdx
 117b194:	48 8b 8d f8 fd ff ff 	mov    -0x208(%rbp),%rcx
 117b19b:	0f b7 d8             	movzwl %ax,%ebx
 117b19e:	80 bd 34 fe ff ff 00 	cmpb   $0x0,-0x1cc(%rbp)
 117b1a5:	74 16                	je     117b1bd <br.encodeCommandPlanWithOptionsWrite+0x1e1d>
 117b1a7:	ff 84 9d f0 dc ff ff 	incl   -0x2310(%rbp,%rbx,4)
 117b1ae:	40 80 e7 1f          	and    $0x1f,%dil
 117b1b2:	40 0f b6 c7          	movzbl %dil,%eax
 117b1b6:	48 01 85 30 fc ff ff 	add    %rax,-0x3d0(%rbp)
 117b1bd:	80 7d cc 00          	cmpb   $0x0,-0x34(%rbp)
 117b1c1:	0f 85 c3 f5 ff ff    	jne    117a78a <br.encodeCommandPlanWithOptionsWrite+0x13ea>
 117b1c7:	ff 84 9d 20 eb ff ff 	incl   -0x14e0(%rbp,%rbx,4)
 117b1ce:	e9 14 f7 ff ff       	jmp    117a8e7 <br.encodeCommandPlanWithOptionsWrite+0x1547>
 117b1d3:	b0 01                	mov    $0x1,%al
 117b1d5:	0f b6 75 b7          	movzbl -0x49(%rbp),%esi
 117b1d9:	40 80 e6 03          	and    $0x3,%sil
 117b1dd:	40 80 fe 02          	cmp    $0x2,%sil
 117b1e1:	0f 84 1a f7 ff ff    	je     117a901 <br.encodeCommandPlanWithOptionsWrite+0x1561>
 117b1e7:	84 c0                	test   %al,%al
 117b1e9:	0f 84 12 f7 ff ff    	je     117a901 <br.encodeCommandPlanWithOptionsWrite+0x1561>
 117b1ef:	c5 f8 10 85 48 fd ff 	vmovups -0x2b8(%rbp),%xmm0
 117b1f6:	ff 
 117b1f7:	c5 f8 29 85 40 fd ff 	vmovaps %xmm0,-0x2c0(%rbp)
 117b1fe:	ff 
 117b1ff:	48 8b 85 58 fd ff ff 	mov    -0x2a8(%rbp),%rax
 117b206:	48 89 85 50 fd ff ff 	mov    %rax,-0x2b0(%rbp)
 117b20d:	48 8b 85 d0 fe ff ff 	mov    -0x130(%rbp),%rax
 117b214:	48 89 85 58 fd ff ff 	mov    %rax,-0x2a8(%rbp)
 117b21b:	e9 e1 f6 ff ff       	jmp    117a901 <br.encodeCommandPlanWithOptionsWrite+0x1561>
 117b220:	48 8d bd 50 fa ff ff 	lea    -0x5b0(%rbp),%rdi
 117b227:	48 8b b5 d0 fe ff ff 	mov    -0x130(%rbp),%rsi
 117b22e:	8b 95 2c fe ff ff    	mov    -0x1d4(%rbp),%edx
 117b234:	8b 8d 30 fe ff ff    	mov    -0x1d0(%rbp),%ecx
 117b23a:	45 31 c0             	xor    %r8d,%r8d
 117b23d:	c5 f8 77             	vzeroupper 
 117b240:	e8 9b 2e 04 00       	call   11be0e0 <br.encoder.distance.encodeWithFormat>
 117b245:	80 bd 58 fa ff ff 00 	cmpb   $0x0,-0x5a8(%rbp)
 117b24c:	0f 84 45 e9 ff ff    	je     1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117b252:	48 8b bd 50 fa ff ff 	mov    -0x5b0(%rbp),%rdi
 117b259:	48 8b 95 58 ff ff ff 	mov    -0xa8(%rbp),%rdx
 117b260:	48 8b 8d f8 fd ff ff 	mov    -0x208(%rbp),%rcx
 117b267:	0f b6 75 d5          	movzbl -0x2b(%rbp),%esi
 117b26b:	4c 8b a5 00 ff ff ff 	mov    -0x100(%rbp),%r12
 117b272:	48 89 f8             	mov    %rdi,%rax
 117b275:	48 c1 e8 20          	shr    $0x20,%rax
 117b279:	66 83 f8 4e          	cmp    $0x4e,%ax
 117b27d:	0f 86 de fe ff ff    	jbe    117b161 <br.encodeCommandPlanWithOptionsWrite+0x1dc1>
 117b283:	e9 0f e9 ff ff       	jmp    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117b288:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 117b28c:	75 47                	jne    117b2d5 <br.encodeCommandPlanWithOptionsWrite+0x1f35>
 117b28e:	48 83 bd c8 d5 ff ff 	cmpq   $0x0,-0x2a38(%rbp)
 117b295:	00 
 117b296:	75 3d                	jne    117b2d5 <br.encodeCommandPlanWithOptionsWrite+0x1f35>
 117b298:	48 8b 85 a0 f3 ff ff 	mov    -0xc60(%rbp),%rax
 117b29f:	a8 01                	test   $0x1,%al
 117b2a1:	0f 85 c2 00 00 00    	jne    117b369 <br.encodeCommandPlanWithOptionsWrite+0x1fc9>
 117b2a7:	48 83 c8 01          	or     $0x1,%rax
 117b2ab:	48 89 85 a0 f3 ff ff 	mov    %rax,-0xc60(%rbp)
 117b2b2:	c7 85 b0 c0 ff ff 01 	movl   $0x1,-0x3f50(%rbp)
 117b2b9:	00 00 00 
 117b2bc:	66 c7 85 d0 d5 ff ff 	movw   $0x0,-0x2a30(%rbp)
 117b2c3:	00 00 
 117b2c5:	48 c7 85 c8 d5 ff ff 	movq   $0x1,-0x2a38(%rbp)
 117b2cc:	01 00 00 00 
 117b2d0:	e9 9a 00 00 00       	jmp    117b36f <br.encodeCommandPlanWithOptionsWrite+0x1fcf>
 117b2d5:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 117b2d9:	0f 84 90 00 00 00    	je     117b36f <br.encodeCommandPlanWithOptionsWrite+0x1fcf>
 117b2df:	b8 05 00 00 00       	mov    $0x5,%eax
 117b2e4:	80 7d ca 00          	cmpb   $0x0,-0x36(%rbp)
 117b2e8:	75 23                	jne    117b30d <br.encodeCommandPlanWithOptionsWrite+0x1f6d>
 117b2ea:	b8 04 00 00 00       	mov    $0x4,%eax
 117b2ef:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 117b2f3:	75 18                	jne    117b30d <br.encodeCommandPlanWithOptionsWrite+0x1f6d>
 117b2f5:	b8 03 00 00 00       	mov    $0x3,%eax
 117b2fa:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 117b2fe:	75 0d                	jne    117b30d <br.encodeCommandPlanWithOptionsWrite+0x1f6d>
 117b300:	80 7d c5 01          	cmpb   $0x1,-0x3b(%rbp)
 117b304:	b8 02 00 00 00       	mov    $0x2,%eax
 117b309:	48 83 d8 00          	sbb    $0x0,%rax
 117b30d:	31 c9                	xor    %ecx,%ecx
 117b30f:	48 8b 95 10 ff ff ff 	mov    -0xf0(%rbp),%rdx
 117b316:	48 89 95 f8 fb ff ff 	mov    %rdx,-0x408(%rbp)
 117b31d:	48 8b 95 18 ff ff ff 	mov    -0xe8(%rbp),%rdx
 117b324:	48 89 95 00 fc ff ff 	mov    %rdx,-0x400(%rbp)
 117b32b:	48 8b 95 20 ff ff ff 	mov    -0xe0(%rbp),%rdx
 117b332:	48 89 95 08 fc ff ff 	mov    %rdx,-0x3f8(%rbp)
 117b339:	4c 8b 95 f0 fe ff ff 	mov    -0x110(%rbp),%r10
 117b340:	4c 89 95 10 fc ff ff 	mov    %r10,-0x3f0(%rbp)
 117b347:	48 8d 95 f8 fb ff ff 	lea    -0x408(%rbp),%rdx
 117b34e:	48 8d 35 ff e9 e8 ff 	lea    -0x171601(%rip),%rsi        # 1009d54 <__anon_240364+0x72f4>
 117b355:	4c 63 0c 8e          	movslq (%rsi,%rcx,4),%r9
 117b359:	49 01 f1             	add    %rsi,%r9
 117b35c:	48 89 d7             	mov    %rdx,%rdi
 117b35f:	4c 8b 85 60 ff ff ff 	mov    -0xa0(%rbp),%r8
 117b366:	41 ff e1             	jmp    *%r9
 117b369:	ff 85 b0 c0 ff ff    	incl   -0x3f50(%rbp)
 117b36f:	f6 85 08 ff ff ff 01 	testb  $0x1,-0xf8(%rbp)
 117b376:	0f 84 94 00 00 00    	je     117b410 <br.encodeCommandPlanWithOptionsWrite+0x2070>
 117b37c:	48 83 ec 08          	sub    $0x8,%rsp
 117b380:	48 8d 85 e1 e9 ff ff 	lea    -0x161f(%rbp),%rax
 117b387:	4c 8d 95 a8 e4 ff ff 	lea    -0x1b58(%rbp),%r10
 117b38e:	4c 8d 9d 0a a6 ff ff 	lea    -0x59f6(%rbp),%r11
 117b395:	48 8d 95 b0 c5 ff ff 	lea    -0x3a50(%rbp),%rdx
 117b39c:	48 8d bd 2a bc ff ff 	lea    -0x43d6(%rbp),%rdi
 117b3a3:	48 8d b5 8c 7f ff ff 	lea    -0x8074(%rbp),%rsi
 117b3aa:	48 8d 8d 20 eb ff ff 	lea    -0x14e0(%rbp),%rcx
 117b3b1:	4c 8d 85 98 37 ff ff 	lea    -0xc868(%rbp),%r8
 117b3b8:	4c 8d 8d f0 dc ff ff 	lea    -0x2310(%rbp),%r9
 117b3bf:	50                   	push   %rax
 117b3c0:	41 52                	push   %r10
 117b3c2:	41 53                	push   %r11
 117b3c4:	52                   	push   %rdx
 117b3c5:	ff b5 f0 fd ff ff    	push   -0x210(%rbp)
 117b3cb:	ff b5 68 fa ff ff    	push   -0x598(%rbp)
 117b3d1:	ff b5 30 fc ff ff    	push   -0x3d0(%rbp)
 117b3d7:	c5 f8 77             	vzeroupper 
 117b3da:	e8 21 12 04 00       	call   11bc600 <br.chooseSameLastDistancePlan__anon_35746>
 117b3df:	48 83 c4 40          	add    $0x40,%rsp
 117b3e3:	0f b7 85 2a bc ff ff 	movzwl -0x43d6(%rbp),%eax
 117b3ea:	66 85 c0             	test   %ax,%ax
 117b3ed:	0f 85 1a e0 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117b3f3:	48 8d b5 2c bc ff ff 	lea    -0x43d4(%rbp),%rsi
 117b3fa:	4c 8d bd 4b 7d ff ff 	lea    -0x82b5(%rbp),%r15
 117b401:	ba 41 02 00 00       	mov    $0x241,%edx
 117b406:	4c 89 ff             	mov    %r15,%rdi
 117b409:	e8 b2 ac 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117b40e:	eb 07                	jmp    117b417 <br.encodeCommandPlanWithOptionsWrite+0x2077>
 117b410:	4c 8d 3d 76 77 e9 ff 	lea    -0x16888a(%rip),%r15        # 1012b8d <__anon_35749>
 117b417:	48 8d bd 6f be ff ff 	lea    -0x4191(%rbp),%rdi
 117b41e:	ba 41 02 00 00       	mov    $0x241,%edx
 117b423:	4c 89 fe             	mov    %r15,%rsi
 117b426:	c5 f8 77             	vzeroupper 
 117b429:	e8 92 ac 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117b42e:	80 7d cc 00          	cmpb   $0x0,-0x34(%rbp)
 117b432:	0f 84 8a 00 00 00    	je     117b4c2 <br.encodeCommandPlanWithOptionsWrite+0x2122>
 117b438:	b8 05 00 00 00       	mov    $0x5,%eax
 117b43d:	80 7d ce 00          	cmpb   $0x0,-0x32(%rbp)
 117b441:	75 23                	jne    117b466 <br.encodeCommandPlanWithOptionsWrite+0x20c6>
 117b443:	b8 04 00 00 00       	mov    $0x4,%eax
 117b448:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 117b44c:	75 18                	jne    117b466 <br.encodeCommandPlanWithOptionsWrite+0x20c6>
 117b44e:	b8 03 00 00 00       	mov    $0x3,%eax
 117b453:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 117b457:	75 0d                	jne    117b466 <br.encodeCommandPlanWithOptionsWrite+0x20c6>
 117b459:	80 7d d5 01          	cmpb   $0x1,-0x2b(%rbp)
 117b45d:	b8 02 00 00 00       	mov    $0x2,%eax
 117b462:	48 83 d8 00          	sbb    $0x0,%rax
 117b466:	31 c9                	xor    %ecx,%ecx
 117b468:	48 8b 95 58 fe ff ff 	mov    -0x1a8(%rbp),%rdx
 117b46f:	48 89 95 d8 fb ff ff 	mov    %rdx,-0x428(%rbp)
 117b476:	48 8b 95 60 fe ff ff 	mov    -0x1a0(%rbp),%rdx
 117b47d:	48 89 95 e0 fb ff ff 	mov    %rdx,-0x420(%rbp)
 117b484:	48 8b 95 68 fe ff ff 	mov    -0x198(%rbp),%rdx
 117b48b:	48 89 95 e8 fb ff ff 	mov    %rdx,-0x418(%rbp)
 117b492:	48 8b 95 70 fe ff ff 	mov    -0x190(%rbp),%rdx
 117b499:	48 89 95 f0 fb ff ff 	mov    %rdx,-0x410(%rbp)
 117b4a0:	48 8d 95 d8 fb ff ff 	lea    -0x428(%rbp),%rdx
 117b4a7:	48 8d 35 ba e8 e8 ff 	lea    -0x171746(%rip),%rsi        # 1009d68 <__anon_240364+0x7308>
 117b4ae:	4c 63 0c 8e          	movslq (%rsi,%rcx,4),%r9
 117b4b2:	49 01 f1             	add    %rsi,%r9
 117b4b5:	48 89 d7             	mov    %rdx,%rdi
 117b4b8:	4c 8b 85 c8 fe ff ff 	mov    -0x138(%rbp),%r8
 117b4bf:	41 ff e1             	jmp    *%r9
 117b4c2:	31 c0                	xor    %eax,%eax
 117b4c4:	8b 8c 85 20 eb ff ff 	mov    -0x14e0(%rbp,%rax,4),%ecx
 117b4cb:	85 c9                	test   %ecx,%ecx
 117b4cd:	75 0a                	jne    117b4d9 <br.encodeCommandPlanWithOptionsWrite+0x2139>
 117b4cf:	48 83 f8 4e          	cmp    $0x4e,%rax
 117b4d3:	48 8d 40 01          	lea    0x1(%rax),%rax
 117b4d7:	75 eb                	jne    117b4c4 <br.encodeCommandPlanWithOptionsWrite+0x2124>
 117b4d9:	85 c9                	test   %ecx,%ecx
 117b4db:	75 0a                	jne    117b4e7 <br.encodeCommandPlanWithOptionsWrite+0x2147>
 117b4dd:	c7 85 20 eb ff ff 01 	movl   $0x1,-0x14e0(%rbp)
 117b4e4:	00 00 00 
 117b4e7:	f6 85 08 ff ff ff 01 	testb  $0x1,-0xf8(%rbp)
 117b4ee:	74 67                	je     117b557 <br.encodeCommandPlanWithOptionsWrite+0x21b7>
 117b4f0:	48 8b 85 48 e5 ff ff 	mov    -0x1ab8(%rbp),%rax
 117b4f7:	48 89 85 f0 e5 ff ff 	mov    %rax,-0x1a10(%rbp)
 117b4fe:	c5 fc 10 85 28 e5 ff 	vmovups -0x1ad8(%rbp),%ymm0
 117b505:	ff 
 117b506:	c5 fc 11 85 d0 e5 ff 	vmovups %ymm0,-0x1a30(%rbp)
 117b50d:	ff 
 117b50e:	c5 fc 10 85 a8 e4 ff 	vmovups -0x1b58(%rbp),%ymm0
 117b515:	ff 
 117b516:	c5 fc 10 8d e8 e4 ff 	vmovups -0x1b18(%rbp),%ymm1
 117b51d:	ff 
 117b51e:	c5 fc 10 95 08 e5 ff 	vmovups -0x1af8(%rbp),%ymm2
 117b525:	ff 
 117b526:	c5 fc 11 95 b0 e5 ff 	vmovups %ymm2,-0x1a50(%rbp)
 117b52d:	ff 
 117b52e:	c5 fc 11 8d 90 e5 ff 	vmovups %ymm1,-0x1a70(%rbp)
 117b535:	ff 
 117b536:	c5 fc 10 8d c8 e4 ff 	vmovups -0x1b38(%rbp),%ymm1
 117b53d:	ff 
 117b53e:	c5 fc 11 8d 70 e5 ff 	vmovups %ymm1,-0x1a90(%rbp)
 117b545:	ff 
 117b546:	c5 fc 11 85 50 e5 ff 	vmovups %ymm0,-0x1ab0(%rbp)
 117b54d:	ff 
 117b54e:	48 8d 85 50 e5 ff ff 	lea    -0x1ab0(%rbp),%rax
 117b555:	eb 07                	jmp    117b55e <br.encodeCommandPlanWithOptionsWrite+0x21be>
 117b557:	48 8d 05 72 78 e9 ff 	lea    -0x16878e(%rip),%rax        # 1012dd0 <__anon_35580>
 117b55e:	48 8b 88 a0 00 00 00 	mov    0xa0(%rax),%rcx
 117b565:	48 89 8d 70 f1 ff ff 	mov    %rcx,-0xe90(%rbp)
 117b56c:	c5 fc 10 80 80 00 00 	vmovups 0x80(%rax),%ymm0
 117b573:	00 
 117b574:	c5 fc 11 85 50 f1 ff 	vmovups %ymm0,-0xeb0(%rbp)
 117b57b:	ff 
 117b57c:	c5 fc 10 00          	vmovups (%rax),%ymm0
 117b580:	c5 fc 10 48 40       	vmovups 0x40(%rax),%ymm1
 117b585:	c5 fc 10 50 60       	vmovups 0x60(%rax),%ymm2
 117b58a:	c5 fc 11 95 30 f1 ff 	vmovups %ymm2,-0xed0(%rbp)
 117b591:	ff 
 117b592:	c5 fc 11 8d 10 f1 ff 	vmovups %ymm1,-0xef0(%rbp)
 117b599:	ff 
 117b59a:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 117b59f:	c5 fc 11 8d f0 f0 ff 	vmovups %ymm1,-0xf10(%rbp)
 117b5a6:	ff 
 117b5a7:	c5 fc 11 85 d0 f0 ff 	vmovups %ymm0,-0xf30(%rbp)
 117b5ae:	ff 
 117b5af:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 117b5b3:	75 1f                	jne    117b5d4 <br.encodeCommandPlanWithOptionsWrite+0x2234>
 117b5b5:	48 8d bd c8 d5 ff ff 	lea    -0x2a38(%rbp),%rdi
 117b5bc:	48 8d b5 b0 c0 ff ff 	lea    -0x3f50(%rbp),%rsi
 117b5c3:	c5 f8 77             	vzeroupper 
 117b5c6:	e8 25 98 ff ff       	call   1174df0 <br.encoder.command_plan.PrefixAlphabetFor(256).sortByFrequencies>
 117b5cb:	66 85 c0             	test   %ax,%ax
 117b5ce:	0f 85 39 de ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117b5d4:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 117b5d8:	44 0f b6 60 50       	movzbl 0x50(%rax),%r12d
 117b5dd:	45 84 e4             	test   %r12b,%r12b
 117b5e0:	0f 84 80 00 00 00    	je     117b666 <br.encodeCommandPlanWithOptionsWrite+0x22c6>
 117b5e6:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 117b5ea:	44 0f b6 68 09       	movzbl 0x9(%rax),%r13d
 117b5ef:	49 83 e5 7f          	and    $0x7f,%r13
 117b5f3:	74 71                	je     117b666 <br.encodeCommandPlanWithOptionsWrite+0x22c6>
 117b5f5:	4c 8d bd 50 ba fb ff 	lea    -0x445b0(%rbp),%r15
 117b5fc:	31 db                	xor    %ebx,%ebx
 117b5fe:	48 89 d8             	mov    %rbx,%rax
 117b601:	48 c1 e0 0a          	shl    $0xa,%rax
 117b605:	48 8d 34 28          	lea    (%rax,%rbp,1),%rsi
 117b609:	48 81 c6 50 ba fb ff 	add    $0xfffffffffffbba50,%rsi
 117b610:	31 c0                	xor    %eax,%eax
 117b612:	41 8b 0c 87          	mov    (%r15,%rax,4),%ecx
 117b616:	85 c9                	test   %ecx,%ecx
 117b618:	75 0c                	jne    117b626 <br.encodeCommandPlanWithOptionsWrite+0x2286>
 117b61a:	48 3d ff 00 00 00    	cmp    $0xff,%rax
 117b620:	48 8d 40 01          	lea    0x1(%rax),%rax
 117b624:	75 ec                	jne    117b612 <br.encodeCommandPlanWithOptionsWrite+0x2272>
 117b626:	85 c9                	test   %ecx,%ecx
 117b628:	75 06                	jne    117b630 <br.encodeCommandPlanWithOptionsWrite+0x2290>
 117b62a:	c7 06 01 00 00 00    	movl   $0x1,(%rsi)
 117b630:	48 89 d8             	mov    %rbx,%rax
 117b633:	48 c1 e0 09          	shl    $0x9,%rax
 117b637:	48 8d 04 d8          	lea    (%rax,%rbx,8),%rax
 117b63b:	48 8d 3c 28          	lea    (%rax,%rbp,1),%rdi
 117b63f:	48 81 c7 50 1d fd ff 	add    $0xfffffffffffd1d50,%rdi
 117b646:	c5 f8 77             	vzeroupper 
 117b649:	e8 12 99 ff ff       	call   1174f60 <br.encoder.command_plan.alphabetFromFrequenciesInto__anon_35804>
 117b64e:	66 85 c0             	test   %ax,%ax
 117b651:	0f 85 b6 dd ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117b657:	48 ff c3             	inc    %rbx
 117b65a:	49 81 c7 00 04 00 00 	add    $0x400,%r15
 117b661:	4c 39 eb             	cmp    %r13,%rbx
 117b664:	75 98                	jne    117b5fe <br.encodeCommandPlanWithOptionsWrite+0x225e>
 117b666:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 117b66a:	0f 84 9e 00 00 00    	je     117b70e <br.encodeCommandPlanWithOptionsWrite+0x236e>
 117b670:	80 7d c0 00          	cmpb   $0x0,-0x40(%rbp)
 117b674:	74 14                	je     117b68a <br.encodeCommandPlanWithOptionsWrite+0x22ea>
 117b676:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 117b67d:	49 89 c5             	mov    %rax,%r13
 117b680:	48 85 c0             	test   %rax,%rax
 117b683:	75 51                	jne    117b6d6 <br.encodeCommandPlanWithOptionsWrite+0x2336>
 117b685:	e9 84 00 00 00       	jmp    117b70e <br.encodeCommandPlanWithOptionsWrite+0x236e>
 117b68a:	0f b6 45 c9          	movzbl -0x37(%rbp),%eax
 117b68e:	0a 45 c2             	or     -0x3e(%rbp),%al
 117b691:	a8 01                	test   $0x1,%al
 117b693:	74 0f                	je     117b6a4 <br.encodeCommandPlanWithOptionsWrite+0x2304>
 117b695:	44 0f b6 6d c9       	movzbl -0x37(%rbp),%r13d
 117b69a:	41 83 e5 01          	and    $0x1,%r13d
 117b69e:	49 83 f5 03          	xor    $0x3,%r13
 117b6a2:	eb 32                	jmp    117b6d6 <br.encodeCommandPlanWithOptionsWrite+0x2336>
 117b6a4:	41 bd 06 00 00 00    	mov    $0x6,%r13d
 117b6aa:	80 7d ca 00          	cmpb   $0x0,-0x36(%rbp)
 117b6ae:	75 26                	jne    117b6d6 <br.encodeCommandPlanWithOptionsWrite+0x2336>
 117b6b0:	41 bd 05 00 00 00    	mov    $0x5,%r13d
 117b6b6:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 117b6ba:	75 1a                	jne    117b6d6 <br.encodeCommandPlanWithOptionsWrite+0x2336>
 117b6bc:	41 bd 04 00 00 00    	mov    $0x4,%r13d
 117b6c2:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 117b6c6:	75 0e                	jne    117b6d6 <br.encodeCommandPlanWithOptionsWrite+0x2336>
 117b6c8:	80 7d c5 01          	cmpb   $0x1,-0x3b(%rbp)
 117b6cc:	41 bd 03 00 00 00    	mov    $0x3,%r13d
 117b6d2:	49 83 dd 00          	sbb    $0x0,%r13
 117b6d6:	4c 8d bd e8 e4 fe ff 	lea    -0x11b18(%rbp),%r15
 117b6dd:	48 8d 9d 68 8c ff ff 	lea    -0x7398(%rbp),%rbx
 117b6e4:	48 89 df             	mov    %rbx,%rdi
 117b6e7:	4c 89 fe             	mov    %r15,%rsi
 117b6ea:	c5 f8 77             	vzeroupper 
 117b6ed:	e8 6e 98 ff ff       	call   1174f60 <br.encoder.command_plan.alphabetFromFrequenciesInto__anon_35804>
 117b6f2:	66 85 c0             	test   %ax,%ax
 117b6f5:	0f 85 12 dd ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117b6fb:	49 81 c7 00 04 00 00 	add    $0x400,%r15
 117b702:	48 81 c3 08 02 00 00 	add    $0x208,%rbx
 117b709:	49 ff cd             	dec    %r13
 117b70c:	75 d6                	jne    117b6e4 <br.encodeCommandPlanWithOptionsWrite+0x2344>
 117b70e:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 117b712:	74 1e                	je     117b732 <br.encodeCommandPlanWithOptionsWrite+0x2392>
 117b714:	80 7d c1 00          	cmpb   $0x0,-0x3f(%rbp)
 117b718:	74 39                	je     117b753 <br.encodeCommandPlanWithOptionsWrite+0x23b3>
 117b71a:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 117b721:	49 89 c5             	mov    %rax,%r13
 117b724:	48 85 c0             	test   %rax,%rax
 117b727:	0f 85 9c 00 00 00    	jne    117b7c9 <br.encodeCommandPlanWithOptionsWrite+0x2429>
 117b72d:	e9 cf 00 00 00       	jmp    117b801 <br.encodeCommandPlanWithOptionsWrite+0x2461>
 117b732:	f6 85 08 ff ff ff 01 	testb  $0x1,-0xf8(%rbp)
 117b739:	74 32                	je     117b76d <br.encodeCommandPlanWithOptionsWrite+0x23cd>
 117b73b:	80 7d cc 00          	cmpb   $0x0,-0x34(%rbp)
 117b73f:	0f 85 c2 00 00 00    	jne    117b807 <br.encodeCommandPlanWithOptionsWrite+0x2467>
 117b745:	b0 01                	mov    $0x1,%al
 117b747:	48 89 85 08 ff ff ff 	mov    %rax,-0xf8(%rbp)
 117b74e:	e9 98 01 00 00       	jmp    117b8eb <br.encodeCommandPlanWithOptionsWrite+0x254b>
 117b753:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 117b757:	0a 45 c7             	or     -0x39(%rbp),%al
 117b75a:	a8 01                	test   $0x1,%al
 117b75c:	74 39                	je     117b797 <br.encodeCommandPlanWithOptionsWrite+0x23f7>
 117b75e:	44 0f b6 6d d2       	movzbl -0x2e(%rbp),%r13d
 117b763:	41 83 e5 01          	and    $0x1,%r13d
 117b767:	49 83 f5 03          	xor    $0x3,%r13
 117b76b:	eb 5c                	jmp    117b7c9 <br.encodeCommandPlanWithOptionsWrite+0x2429>
 117b76d:	48 8d bd b0 c5 ff ff 	lea    -0x3a50(%rbp),%rdi
 117b774:	48 8d b5 8c 7f ff ff 	lea    -0x8074(%rbp),%rsi
 117b77b:	c5 f8 77             	vzeroupper 
 117b77e:	e8 6d 96 ff ff       	call   1174df0 <br.encoder.command_plan.PrefixAlphabetFor(256).sortByFrequencies>
 117b783:	66 85 c0             	test   %ax,%ax
 117b786:	0f 85 81 dc ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117b78c:	80 7d cc 00          	cmpb   $0x0,-0x34(%rbp)
 117b790:	75 75                	jne    117b807 <br.encodeCommandPlanWithOptionsWrite+0x2467>
 117b792:	e9 be 00 00 00       	jmp    117b855 <br.encodeCommandPlanWithOptionsWrite+0x24b5>
 117b797:	41 bd 06 00 00 00    	mov    $0x6,%r13d
 117b79d:	80 7d cd 00          	cmpb   $0x0,-0x33(%rbp)
 117b7a1:	75 26                	jne    117b7c9 <br.encodeCommandPlanWithOptionsWrite+0x2429>
 117b7a3:	41 bd 05 00 00 00    	mov    $0x5,%r13d
 117b7a9:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 117b7ad:	75 1a                	jne    117b7c9 <br.encodeCommandPlanWithOptionsWrite+0x2429>
 117b7af:	41 bd 04 00 00 00    	mov    $0x4,%r13d
 117b7b5:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 117b7b9:	75 0e                	jne    117b7c9 <br.encodeCommandPlanWithOptionsWrite+0x2429>
 117b7bb:	80 7d cb 01          	cmpb   $0x1,-0x35(%rbp)
 117b7bf:	41 bd 03 00 00 00    	mov    $0x3,%r13d
 117b7c5:	49 83 dd 00          	sbb    $0x0,%r13
 117b7c9:	4c 8d bd d4 01 fe ff 	lea    -0x1fe2c(%rbp),%r15
 117b7d0:	48 8d 9d e8 fc fe ff 	lea    -0x10318(%rbp),%rbx
 117b7d7:	48 89 df             	mov    %rbx,%rdi
 117b7da:	4c 89 fe             	mov    %r15,%rsi
 117b7dd:	c5 f8 77             	vzeroupper 
 117b7e0:	e8 4b 98 ff ff       	call   1175030 <br.encoder.command_plan.alphabetFromFrequenciesInto__anon_35817>
 117b7e5:	66 85 c0             	test   %ax,%ax
 117b7e8:	0f 85 1f dc ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117b7ee:	49 81 c7 00 0b 00 00 	add    $0xb00,%r15
 117b7f5:	48 81 c3 88 05 00 00 	add    $0x588,%rbx
 117b7fc:	49 ff cd             	dec    %r13
 117b7ff:	75 d6                	jne    117b7d7 <br.encodeCommandPlanWithOptionsWrite+0x2437>
 117b801:	80 7d cc 00          	cmpb   $0x0,-0x34(%rbp)
 117b805:	74 38                	je     117b83f <br.encodeCommandPlanWithOptionsWrite+0x249f>
 117b807:	80 7d c4 00          	cmpb   $0x0,-0x3c(%rbp)
 117b80b:	74 18                	je     117b825 <br.encodeCommandPlanWithOptionsWrite+0x2485>
 117b80d:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 117b814:	49 89 c5             	mov    %rax,%r13
 117b817:	48 85 c0             	test   %rax,%rax
 117b81a:	0f 85 93 00 00 00    	jne    117b8b3 <br.encodeCommandPlanWithOptionsWrite+0x2513>
 117b820:	e9 c6 00 00 00       	jmp    117b8eb <br.encodeCommandPlanWithOptionsWrite+0x254b>
 117b825:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 117b829:	0a 45 c8             	or     -0x38(%rbp),%al
 117b82c:	a8 01                	test   $0x1,%al
 117b82e:	74 51                	je     117b881 <br.encodeCommandPlanWithOptionsWrite+0x24e1>
 117b830:	44 0f b6 6d d3       	movzbl -0x2d(%rbp),%r13d
 117b835:	41 83 e5 01          	and    $0x1,%r13d
 117b839:	49 83 f5 03          	xor    $0x3,%r13
 117b83d:	eb 74                	jmp    117b8b3 <br.encodeCommandPlanWithOptionsWrite+0x2513>
 117b83f:	f6 85 08 ff ff ff 01 	testb  $0x1,-0xf8(%rbp)
 117b846:	b0 01                	mov    $0x1,%al
 117b848:	48 89 85 08 ff ff ff 	mov    %rax,-0xf8(%rbp)
 117b84f:	0f 85 96 00 00 00    	jne    117b8eb <br.encodeCommandPlanWithOptionsWrite+0x254b>
 117b855:	48 8d bd d0 f0 ff ff 	lea    -0xf30(%rbp),%rdi
 117b85c:	48 8d b5 20 eb ff ff 	lea    -0x14e0(%rbp),%rsi
 117b863:	c5 f8 77             	vzeroupper 
 117b866:	e8 95 98 ff ff       	call   1175100 <br.encoder.command_plan.alphabetFromFrequenciesInto__anon_35842>
 117b86b:	66 85 c0             	test   %ax,%ax
 117b86e:	0f 85 99 db ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117b874:	48 c7 85 08 ff ff ff 	movq   $0x0,-0xf8(%rbp)
 117b87b:	00 00 00 00 
 117b87f:	eb 6a                	jmp    117b8eb <br.encodeCommandPlanWithOptionsWrite+0x254b>
 117b881:	41 bd 06 00 00 00    	mov    $0x6,%r13d
 117b887:	80 7d ce 00          	cmpb   $0x0,-0x32(%rbp)
 117b88b:	75 26                	jne    117b8b3 <br.encodeCommandPlanWithOptionsWrite+0x2513>
 117b88d:	41 bd 05 00 00 00    	mov    $0x5,%r13d
 117b893:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 117b897:	75 1a                	jne    117b8b3 <br.encodeCommandPlanWithOptionsWrite+0x2513>
 117b899:	41 bd 04 00 00 00    	mov    $0x4,%r13d
 117b89f:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 117b8a3:	75 0e                	jne    117b8b3 <br.encodeCommandPlanWithOptionsWrite+0x2513>
 117b8a5:	80 7d d5 01          	cmpb   $0x1,-0x2b(%rbp)
 117b8a9:	41 bd 03 00 00 00    	mov    $0x3,%r13d
 117b8af:	49 83 dd 00          	sbb    $0x0,%r13
 117b8b3:	4c 8d bd a0 9e ff ff 	lea    -0x6160(%rbp),%r15
 117b8ba:	48 8d 9d 38 cb ff ff 	lea    -0x34c8(%rbp),%rbx
 117b8c1:	48 89 df             	mov    %rbx,%rdi
 117b8c4:	4c 89 fe             	mov    %r15,%rsi
 117b8c7:	c5 f8 77             	vzeroupper 
 117b8ca:	e8 31 98 ff ff       	call   1175100 <br.encoder.command_plan.alphabetFromFrequenciesInto__anon_35842>
 117b8cf:	66 85 c0             	test   %ax,%ax
 117b8d2:	0f 85 35 db ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117b8d8:	49 81 c7 3c 01 00 00 	add    $0x13c,%r15
 117b8df:	48 81 c3 a8 00 00 00 	add    $0xa8,%rbx
 117b8e6:	49 ff cd             	dec    %r13
 117b8e9:	75 d6                	jne    117b8c1 <br.encodeCommandPlanWithOptionsWrite+0x2521>
 117b8eb:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 117b8ef:	74 1b                	je     117b90c <br.encodeCommandPlanWithOptionsWrite+0x256c>
 117b8f1:	80 7d c0 00          	cmpb   $0x0,-0x40(%rbp)
 117b8f5:	74 3e                	je     117b935 <br.encodeCommandPlanWithOptionsWrite+0x2595>
 117b8f7:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 117b8fe:	48 89 c1             	mov    %rax,%rcx
 117b901:	48 85 c0             	test   %rax,%rax
 117b904:	0f 85 84 00 00 00    	jne    117b98e <br.encodeCommandPlanWithOptionsWrite+0x25ee>
 117b90a:	eb 41                	jmp    117b94d <br.encodeCommandPlanWithOptionsWrite+0x25ad>
 117b90c:	45 84 e4             	test   %r12b,%r12b
 117b90f:	74 43                	je     117b954 <br.encodeCommandPlanWithOptionsWrite+0x25b4>
 117b911:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 117b915:	0f b6 50 09          	movzbl 0x9(%rax),%edx
 117b919:	83 e2 7f             	and    $0x7f,%edx
 117b91c:	74 2f                	je     117b94d <br.encodeCommandPlanWithOptionsWrite+0x25ad>
 117b91e:	89 d1                	mov    %edx,%ecx
 117b920:	83 e1 07             	and    $0x7,%ecx
 117b923:	80 fa 08             	cmp    $0x8,%dl
 117b926:	0f 83 03 01 00 00    	jae    117ba2f <br.encodeCommandPlanWithOptionsWrite+0x268f>
 117b92c:	31 f6                	xor    %esi,%esi
 117b92e:	31 c0                	xor    %eax,%eax
 117b930:	e9 4c 01 00 00       	jmp    117ba81 <br.encodeCommandPlanWithOptionsWrite+0x26e1>
 117b935:	0f b6 45 c9          	movzbl -0x37(%rbp),%eax
 117b939:	0a 45 c2             	or     -0x3e(%rbp),%al
 117b93c:	a8 01                	test   $0x1,%al
 117b93e:	74 20                	je     117b960 <br.encodeCommandPlanWithOptionsWrite+0x25c0>
 117b940:	0f b6 4d c9          	movzbl -0x37(%rbp),%ecx
 117b944:	83 e1 01             	and    $0x1,%ecx
 117b947:	48 83 f1 03          	xor    $0x3,%rcx
 117b94b:	eb 41                	jmp    117b98e <br.encodeCommandPlanWithOptionsWrite+0x25ee>
 117b94d:	31 c0                	xor    %eax,%eax
 117b94f:	e9 61 01 00 00       	jmp    117bab5 <br.encodeCommandPlanWithOptionsWrite+0x2715>
 117b954:	48 8b 85 c8 d5 ff ff 	mov    -0x2a38(%rbp),%rax
 117b95b:	e9 55 01 00 00       	jmp    117bab5 <br.encodeCommandPlanWithOptionsWrite+0x2715>
 117b960:	b9 06 00 00 00       	mov    $0x6,%ecx
 117b965:	80 7d ca 00          	cmpb   $0x0,-0x36(%rbp)
 117b969:	75 23                	jne    117b98e <br.encodeCommandPlanWithOptionsWrite+0x25ee>
 117b96b:	b9 05 00 00 00       	mov    $0x5,%ecx
 117b970:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 117b974:	75 18                	jne    117b98e <br.encodeCommandPlanWithOptionsWrite+0x25ee>
 117b976:	b9 04 00 00 00       	mov    $0x4,%ecx
 117b97b:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 117b97f:	75 0d                	jne    117b98e <br.encodeCommandPlanWithOptionsWrite+0x25ee>
 117b981:	80 7d c5 01          	cmpb   $0x1,-0x3b(%rbp)
 117b985:	b9 03 00 00 00       	mov    $0x3,%ecx
 117b98a:	48 83 d9 00          	sbb    $0x0,%rcx
 117b98e:	89 ca                	mov    %ecx,%edx
 117b990:	83 e2 07             	and    $0x7,%edx
 117b993:	48 83 f9 08          	cmp    $0x8,%rcx
 117b997:	73 06                	jae    117b99f <br.encodeCommandPlanWithOptionsWrite+0x25ff>
 117b999:	31 f6                	xor    %esi,%esi
 117b99b:	31 c0                	xor    %eax,%eax
 117b99d:	eb 53                	jmp    117b9f2 <br.encodeCommandPlanWithOptionsWrite+0x2652>
 117b99f:	48 83 e1 f8          	and    $0xfffffffffffffff8,%rcx
 117b9a3:	48 8d bd 68 8c ff ff 	lea    -0x7398(%rbp),%rdi
 117b9aa:	31 f6                	xor    %esi,%esi
 117b9ac:	31 c0                	xor    %eax,%eax
 117b9ae:	48 03 07             	add    (%rdi),%rax
 117b9b1:	48 03 87 08 02 00 00 	add    0x208(%rdi),%rax
 117b9b8:	48 03 87 10 04 00 00 	add    0x410(%rdi),%rax
 117b9bf:	48 03 87 18 06 00 00 	add    0x618(%rdi),%rax
 117b9c6:	48 03 87 20 08 00 00 	add    0x820(%rdi),%rax
 117b9cd:	48 03 87 28 0a 00 00 	add    0xa28(%rdi),%rax
 117b9d4:	48 03 87 30 0c 00 00 	add    0xc30(%rdi),%rax
 117b9db:	48 03 87 38 0e 00 00 	add    0xe38(%rdi),%rax
 117b9e2:	48 83 c6 08          	add    $0x8,%rsi
 117b9e6:	48 81 c7 40 10 00 00 	add    $0x1040,%rdi
 117b9ed:	48 39 f1             	cmp    %rsi,%rcx
 117b9f0:	75 bc                	jne    117b9ae <br.encodeCommandPlanWithOptionsWrite+0x260e>
 117b9f2:	48 85 d2             	test   %rdx,%rdx
 117b9f5:	0f 84 ba 00 00 00    	je     117bab5 <br.encodeCommandPlanWithOptionsWrite+0x2715>
 117b9fb:	48 89 f1             	mov    %rsi,%rcx
 117b9fe:	48 c1 e1 09          	shl    $0x9,%rcx
 117ba02:	48 8d 0c f1          	lea    (%rcx,%rsi,8),%rcx
 117ba06:	48 01 e9             	add    %rbp,%rcx
 117ba09:	48 81 c1 68 8c ff ff 	add    $0xffffffffffff8c68,%rcx
 117ba10:	89 d6                	mov    %edx,%esi
 117ba12:	c1 e6 09             	shl    $0x9,%esi
 117ba15:	8d 14 d6             	lea    (%rsi,%rdx,8),%edx
 117ba18:	31 f6                	xor    %esi,%esi
 117ba1a:	48 03 04 31          	add    (%rcx,%rsi,1),%rax
 117ba1e:	48 81 c6 08 02 00 00 	add    $0x208,%rsi
 117ba25:	48 39 f2             	cmp    %rsi,%rdx
 117ba28:	75 f0                	jne    117ba1a <br.encodeCommandPlanWithOptionsWrite+0x267a>
 117ba2a:	e9 86 00 00 00       	jmp    117bab5 <br.encodeCommandPlanWithOptionsWrite+0x2715>
 117ba2f:	83 e2 f8             	and    $0xfffffff8,%edx
 117ba32:	48 8d bd 50 1d fd ff 	lea    -0x2e2b0(%rbp),%rdi
 117ba39:	31 f6                	xor    %esi,%esi
 117ba3b:	31 c0                	xor    %eax,%eax
 117ba3d:	48 03 07             	add    (%rdi),%rax
 117ba40:	48 03 87 08 02 00 00 	add    0x208(%rdi),%rax
 117ba47:	48 03 87 10 04 00 00 	add    0x410(%rdi),%rax
 117ba4e:	48 03 87 18 06 00 00 	add    0x618(%rdi),%rax
 117ba55:	48 03 87 20 08 00 00 	add    0x820(%rdi),%rax
 117ba5c:	48 03 87 28 0a 00 00 	add    0xa28(%rdi),%rax
 117ba63:	48 03 87 30 0c 00 00 	add    0xc30(%rdi),%rax
 117ba6a:	48 03 87 38 0e 00 00 	add    0xe38(%rdi),%rax
 117ba71:	48 83 c6 08          	add    $0x8,%rsi
 117ba75:	48 81 c7 40 10 00 00 	add    $0x1040,%rdi
 117ba7c:	48 39 f2             	cmp    %rsi,%rdx
 117ba7f:	75 bc                	jne    117ba3d <br.encodeCommandPlanWithOptionsWrite+0x269d>
 117ba81:	48 85 c9             	test   %rcx,%rcx
 117ba84:	74 2f                	je     117bab5 <br.encodeCommandPlanWithOptionsWrite+0x2715>
 117ba86:	48 89 f2             	mov    %rsi,%rdx
 117ba89:	48 c1 e2 09          	shl    $0x9,%rdx
 117ba8d:	48 8d 14 f2          	lea    (%rdx,%rsi,8),%rdx
 117ba91:	48 01 ea             	add    %rbp,%rdx
 117ba94:	48 81 c2 50 1d fd ff 	add    $0xfffffffffffd1d50,%rdx
 117ba9b:	89 ce                	mov    %ecx,%esi
 117ba9d:	c1 e6 09             	shl    $0x9,%esi
 117baa0:	8d 0c ce             	lea    (%rsi,%rcx,8),%ecx
 117baa3:	31 f6                	xor    %esi,%esi
 117baa5:	48 03 04 32          	add    (%rdx,%rsi,1),%rax
 117baa9:	48 81 c6 08 02 00 00 	add    $0x208,%rsi
 117bab0:	48 39 f1             	cmp    %rsi,%rcx
 117bab3:	75 f0                	jne    117baa5 <br.encodeCommandPlanWithOptionsWrite+0x2705>
 117bab5:	48 8b 8d 50 fe ff ff 	mov    -0x1b0(%rbp),%rcx
 117babc:	48 89 41 18          	mov    %rax,0x18(%rcx)
 117bac0:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 117bac4:	74 1c                	je     117bae2 <br.encodeCommandPlanWithOptionsWrite+0x2742>
 117bac6:	80 7d c1 00          	cmpb   $0x0,-0x3f(%rbp)
 117baca:	74 22                	je     117baee <br.encodeCommandPlanWithOptionsWrite+0x274e>
 117bacc:	48 8b 8d 68 ff ff ff 	mov    -0x98(%rbp),%rcx
 117bad3:	48 89 c8             	mov    %rcx,%rax
 117bad6:	48 85 c9             	test   %rcx,%rcx
 117bad9:	75 59                	jne    117bb34 <br.encodeCommandPlanWithOptionsWrite+0x2794>
 117badb:	31 c9                	xor    %ecx,%ecx
 117badd:	e9 e4 00 00 00       	jmp    117bbc6 <br.encodeCommandPlanWithOptionsWrite+0x2826>
 117bae2:	48 8b 8d b0 c5 ff ff 	mov    -0x3a50(%rbp),%rcx
 117bae9:	e9 d8 00 00 00       	jmp    117bbc6 <br.encodeCommandPlanWithOptionsWrite+0x2826>
 117baee:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 117baf2:	0a 45 c7             	or     -0x39(%rbp),%al
 117baf5:	a8 01                	test   $0x1,%al
 117baf7:	74 0d                	je     117bb06 <br.encodeCommandPlanWithOptionsWrite+0x2766>
 117baf9:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 117bafd:	83 e0 01             	and    $0x1,%eax
 117bb00:	48 83 f0 03          	xor    $0x3,%rax
 117bb04:	eb 2e                	jmp    117bb34 <br.encodeCommandPlanWithOptionsWrite+0x2794>
 117bb06:	b8 06 00 00 00       	mov    $0x6,%eax
 117bb0b:	80 7d cd 00          	cmpb   $0x0,-0x33(%rbp)
 117bb0f:	75 23                	jne    117bb34 <br.encodeCommandPlanWithOptionsWrite+0x2794>
 117bb11:	b8 05 00 00 00       	mov    $0x5,%eax
 117bb16:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 117bb1a:	75 18                	jne    117bb34 <br.encodeCommandPlanWithOptionsWrite+0x2794>
 117bb1c:	b8 04 00 00 00       	mov    $0x4,%eax
 117bb21:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 117bb25:	75 0d                	jne    117bb34 <br.encodeCommandPlanWithOptionsWrite+0x2794>
 117bb27:	80 7d cb 01          	cmpb   $0x1,-0x35(%rbp)
 117bb2b:	b8 03 00 00 00       	mov    $0x3,%eax
 117bb30:	48 83 d8 00          	sbb    $0x0,%rax
 117bb34:	89 c2                	mov    %eax,%edx
 117bb36:	83 e2 07             	and    $0x7,%edx
 117bb39:	48 83 f8 08          	cmp    $0x8,%rax
 117bb3d:	73 06                	jae    117bb45 <br.encodeCommandPlanWithOptionsWrite+0x27a5>
 117bb3f:	31 f6                	xor    %esi,%esi
 117bb41:	31 c9                	xor    %ecx,%ecx
 117bb43:	eb 53                	jmp    117bb98 <br.encodeCommandPlanWithOptionsWrite+0x27f8>
 117bb45:	48 83 e0 f8          	and    $0xfffffffffffffff8,%rax
 117bb49:	48 8d bd e8 fc fe ff 	lea    -0x10318(%rbp),%rdi
 117bb50:	31 f6                	xor    %esi,%esi
 117bb52:	31 c9                	xor    %ecx,%ecx
 117bb54:	48 03 0f             	add    (%rdi),%rcx
 117bb57:	48 03 8f 88 05 00 00 	add    0x588(%rdi),%rcx
 117bb5e:	48 03 8f 10 0b 00 00 	add    0xb10(%rdi),%rcx
 117bb65:	48 03 8f 98 10 00 00 	add    0x1098(%rdi),%rcx
 117bb6c:	48 03 8f 20 16 00 00 	add    0x1620(%rdi),%rcx
 117bb73:	48 03 8f a8 1b 00 00 	add    0x1ba8(%rdi),%rcx
 117bb7a:	48 03 8f 30 21 00 00 	add    0x2130(%rdi),%rcx
 117bb81:	48 03 8f b8 26 00 00 	add    0x26b8(%rdi),%rcx
 117bb88:	48 83 c6 08          	add    $0x8,%rsi
 117bb8c:	48 81 c7 40 2c 00 00 	add    $0x2c40,%rdi
 117bb93:	48 39 f0             	cmp    %rsi,%rax
 117bb96:	75 bc                	jne    117bb54 <br.encodeCommandPlanWithOptionsWrite+0x27b4>
 117bb98:	48 85 d2             	test   %rdx,%rdx
 117bb9b:	74 29                	je     117bbc6 <br.encodeCommandPlanWithOptionsWrite+0x2826>
 117bb9d:	48 69 c6 88 05 00 00 	imul   $0x588,%rsi,%rax
 117bba4:	48 01 e8             	add    %rbp,%rax
 117bba7:	48 05 e8 fc fe ff    	add    $0xfffffffffffefce8,%rax
 117bbad:	48 69 d2 88 05 00 00 	imul   $0x588,%rdx,%rdx
 117bbb4:	31 f6                	xor    %esi,%esi
 117bbb6:	48 03 0c 30          	add    (%rax,%rsi,1),%rcx
 117bbba:	48 81 c6 88 05 00 00 	add    $0x588,%rsi
 117bbc1:	48 39 f2             	cmp    %rsi,%rdx
 117bbc4:	75 f0                	jne    117bbb6 <br.encodeCommandPlanWithOptionsWrite+0x2816>
 117bbc6:	48 8b 85 50 fe ff ff 	mov    -0x1b0(%rbp),%rax
 117bbcd:	48 89 48 20          	mov    %rcx,0x20(%rax)
 117bbd1:	80 7d cc 00          	cmpb   $0x0,-0x34(%rbp)
 117bbd5:	74 1c                	je     117bbf3 <br.encodeCommandPlanWithOptionsWrite+0x2853>
 117bbd7:	80 7d c4 00          	cmpb   $0x0,-0x3c(%rbp)
 117bbdb:	74 22                	je     117bbff <br.encodeCommandPlanWithOptionsWrite+0x285f>
 117bbdd:	48 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%rcx
 117bbe4:	48 89 c8             	mov    %rcx,%rax
 117bbe7:	48 85 c9             	test   %rcx,%rcx
 117bbea:	75 59                	jne    117bc45 <br.encodeCommandPlanWithOptionsWrite+0x28a5>
 117bbec:	31 c9                	xor    %ecx,%ecx
 117bbee:	e9 e4 00 00 00       	jmp    117bcd7 <br.encodeCommandPlanWithOptionsWrite+0x2937>
 117bbf3:	48 8b 8d d0 f0 ff ff 	mov    -0xf30(%rbp),%rcx
 117bbfa:	e9 d8 00 00 00       	jmp    117bcd7 <br.encodeCommandPlanWithOptionsWrite+0x2937>
 117bbff:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 117bc03:	0a 45 c8             	or     -0x38(%rbp),%al
 117bc06:	a8 01                	test   $0x1,%al
 117bc08:	74 0d                	je     117bc17 <br.encodeCommandPlanWithOptionsWrite+0x2877>
 117bc0a:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 117bc0e:	83 e0 01             	and    $0x1,%eax
 117bc11:	48 83 f0 03          	xor    $0x3,%rax
 117bc15:	eb 2e                	jmp    117bc45 <br.encodeCommandPlanWithOptionsWrite+0x28a5>
 117bc17:	b8 06 00 00 00       	mov    $0x6,%eax
 117bc1c:	80 7d ce 00          	cmpb   $0x0,-0x32(%rbp)
 117bc20:	75 23                	jne    117bc45 <br.encodeCommandPlanWithOptionsWrite+0x28a5>
 117bc22:	b8 05 00 00 00       	mov    $0x5,%eax
 117bc27:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 117bc2b:	75 18                	jne    117bc45 <br.encodeCommandPlanWithOptionsWrite+0x28a5>
 117bc2d:	b8 04 00 00 00       	mov    $0x4,%eax
 117bc32:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 117bc36:	75 0d                	jne    117bc45 <br.encodeCommandPlanWithOptionsWrite+0x28a5>
 117bc38:	80 7d d5 01          	cmpb   $0x1,-0x2b(%rbp)
 117bc3c:	b8 03 00 00 00       	mov    $0x3,%eax
 117bc41:	48 83 d8 00          	sbb    $0x0,%rax
 117bc45:	89 c2                	mov    %eax,%edx
 117bc47:	83 e2 07             	and    $0x7,%edx
 117bc4a:	48 83 f8 08          	cmp    $0x8,%rax
 117bc4e:	73 06                	jae    117bc56 <br.encodeCommandPlanWithOptionsWrite+0x28b6>
 117bc50:	31 f6                	xor    %esi,%esi
 117bc52:	31 c9                	xor    %ecx,%ecx
 117bc54:	eb 53                	jmp    117bca9 <br.encodeCommandPlanWithOptionsWrite+0x2909>
 117bc56:	48 83 e0 f8          	and    $0xfffffffffffffff8,%rax
 117bc5a:	48 8d bd 38 cb ff ff 	lea    -0x34c8(%rbp),%rdi
 117bc61:	31 f6                	xor    %esi,%esi
 117bc63:	31 c9                	xor    %ecx,%ecx
 117bc65:	48 03 0f             	add    (%rdi),%rcx
 117bc68:	48 03 8f a8 00 00 00 	add    0xa8(%rdi),%rcx
 117bc6f:	48 03 8f 50 01 00 00 	add    0x150(%rdi),%rcx
 117bc76:	48 03 8f f8 01 00 00 	add    0x1f8(%rdi),%rcx
 117bc7d:	48 03 8f a0 02 00 00 	add    0x2a0(%rdi),%rcx
 117bc84:	48 03 8f 48 03 00 00 	add    0x348(%rdi),%rcx
 117bc8b:	48 03 8f f0 03 00 00 	add    0x3f0(%rdi),%rcx
 117bc92:	48 03 8f 98 04 00 00 	add    0x498(%rdi),%rcx
 117bc99:	48 83 c6 08          	add    $0x8,%rsi
 117bc9d:	48 81 c7 40 05 00 00 	add    $0x540,%rdi
 117bca4:	48 39 f0             	cmp    %rsi,%rax
 117bca7:	75 bc                	jne    117bc65 <br.encodeCommandPlanWithOptionsWrite+0x28c5>
 117bca9:	48 85 d2             	test   %rdx,%rdx
 117bcac:	74 29                	je     117bcd7 <br.encodeCommandPlanWithOptionsWrite+0x2937>
 117bcae:	48 69 c6 a8 00 00 00 	imul   $0xa8,%rsi,%rax
 117bcb5:	48 01 e8             	add    %rbp,%rax
 117bcb8:	48 05 38 cb ff ff    	add    $0xffffffffffffcb38,%rax
 117bcbe:	48 69 d2 a8 00 00 00 	imul   $0xa8,%rdx,%rdx
 117bcc5:	31 f6                	xor    %esi,%esi
 117bcc7:	48 03 0c 30          	add    (%rax,%rsi,1),%rcx
 117bccb:	48 81 c6 a8 00 00 00 	add    $0xa8,%rsi
 117bcd2:	48 39 f2             	cmp    %rsi,%rdx
 117bcd5:	75 f0                	jne    117bcc7 <br.encodeCommandPlanWithOptionsWrite+0x2927>
 117bcd7:	48 8b 85 50 fe ff ff 	mov    -0x1b0(%rbp),%rax
 117bcde:	48 89 48 28          	mov    %rcx,0x28(%rax)
 117bce2:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117bce6:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 117bcea:	75 40                	jne    117bd2c <br.encodeCommandPlanWithOptionsWrite+0x298c>
 117bcec:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117bcf0:	48 8b 38             	mov    (%rax),%rdi
 117bcf3:	4c 89 f0             	mov    %r14,%rax
 117bcf6:	48 c1 e8 03          	shr    $0x3,%rax
 117bcfa:	48 83 f8 41          	cmp    $0x41,%rax
 117bcfe:	b9 40 00 00 00       	mov    $0x40,%ecx
 117bd03:	48 0f 43 c8          	cmovae %rax,%rcx
 117bd07:	48 81 f9 00 10 00 00 	cmp    $0x1000,%rcx
 117bd0e:	ba 00 10 00 00       	mov    $0x1000,%edx
 117bd13:	48 0f 42 d1          	cmovb  %rcx,%rdx
 117bd17:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 117bd1b:	c5 f8 77             	vzeroupper 
 117bd1e:	e8 0d 07 04 00       	call   11bc430 <array_list.Aligned(u8,null).ensureUnusedCapacity>
 117bd23:	66 85 c0             	test   %ax,%ax
 117bd26:	0f 85 e1 d6 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117bd2c:	80 bd 40 ff ff ff 00 	cmpb   $0x0,-0xc0(%rbp)
 117bd33:	0f b6 85 f8 fe ff ff 	movzbl -0x108(%rbp),%eax
 117bd3a:	89 85 34 fe ff ff    	mov    %eax,-0x1cc(%rbp)
 117bd40:	74 55                	je     117bd97 <br.encodeCommandPlanWithOptionsWrite+0x29f7>
 117bd42:	0f b6 8d 3a ff ff ff 	movzbl -0xc6(%rbp),%ecx
 117bd49:	48 8b 7d a0          	mov    -0x60(%rbp),%rdi
 117bd4d:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 117bd51:	8b 95 34 fe ff ff    	mov    -0x1cc(%rbp),%edx
 117bd57:	c5 f8 77             	vzeroupper 
 117bd5a:	e8 21 ff 03 00       	call   11bbc80 <br.writePlannedWindowBits>
 117bd5f:	66 85 c0             	test   %ax,%ax
 117bd62:	0f 85 a5 d6 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117bd68:	48 83 bd e0 fd ff ff 	cmpq   $0x0,-0x220(%rbp)
 117bd6f:	00 
 117bd70:	74 33                	je     117bda5 <br.encodeCommandPlanWithOptionsWrite+0x2a05>
 117bd72:	48 8b 7d a0          	mov    -0x60(%rbp),%rdi
 117bd76:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 117bd7a:	48 8b 95 80 fd ff ff 	mov    -0x280(%rbp),%rdx
 117bd81:	48 8b 8d e0 fd ff ff 	mov    -0x220(%rbp),%rcx
 117bd88:	e8 f3 fa 03 00       	call   11bb880 <br.writeMetadataMetaBlock>
 117bd8d:	66 85 c0             	test   %ax,%ax
 117bd90:	74 13                	je     117bda5 <br.encodeCommandPlanWithOptionsWrite+0x2a05>
 117bd92:	e9 76 d6 ff ff       	jmp    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117bd97:	48 83 bd e0 fd ff ff 	cmpq   $0x0,-0x220(%rbp)
 117bd9e:	00 
 117bd9f:	0f 85 f2 dd ff ff    	jne    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117bda5:	0f b6 4d 9c          	movzbl -0x64(%rbp),%ecx
 117bda9:	48 8b 7d a0          	mov    -0x60(%rbp),%rdi
 117bdad:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 117bdb1:	4c 89 f2             	mov    %r14,%rdx
 117bdb4:	c5 f8 77             	vzeroupper 
 117bdb7:	e8 04 f8 03 00       	call   11bb5c0 <br.writeCompressedMetaBlockHeader>
 117bdbc:	66 85 c0             	test   %ax,%ax
 117bdbf:	0f 85 48 d6 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117bdc5:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 117bdc9:	74 0c                	je     117bdd7 <br.encodeCommandPlanWithOptionsWrite+0x2a37>
 117bdcb:	48 8d 05 a6 70 e9 ff 	lea    -0x168f5a(%rip),%rax        # 1012e78 <__anon_35879>
 117bdd2:	e9 b8 00 00 00       	jmp    117be8f <br.encodeCommandPlanWithOptionsWrite+0x2aef>
 117bdd7:	0f b6 8d 3e ff ff ff 	movzbl -0xc2(%rbp),%ecx
 117bdde:	48 8d bd 0e df ff ff 	lea    -0x20f2(%rbp),%rdi
 117bde5:	48 8d b5 b0 c0 ff ff 	lea    -0x3f50(%rbp),%rsi
 117bdec:	48 8d 95 c8 d5 ff ff 	lea    -0x2a38(%rbp),%rdx
 117bdf3:	e8 08 e8 03 00       	call   11ba600 <br.chooseLiteralTreeLengths>
 117bdf8:	0f b7 85 0e df ff ff 	movzwl -0x20f2(%rbp),%eax
 117bdff:	66 85 c0             	test   %ax,%ax
 117be02:	0f 85 05 d6 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117be08:	c5 fc 10 85 f0 df ff 	vmovups -0x2010(%rbp),%ymm0
 117be0f:	ff 
 117be10:	c5 fc 11 85 b0 d8 ff 	vmovups %ymm0,-0x2750(%rbp)
 117be17:	ff 
 117be18:	c5 fc 10 85 d0 df ff 	vmovups -0x2030(%rbp),%ymm0
 117be1f:	ff 
 117be20:	c5 fc 11 85 90 d8 ff 	vmovups %ymm0,-0x2770(%rbp)
 117be27:	ff 
 117be28:	c5 fc 10 85 b0 df ff 	vmovups -0x2050(%rbp),%ymm0
 117be2f:	ff 
 117be30:	c5 fc 11 85 70 d8 ff 	vmovups %ymm0,-0x2790(%rbp)
 117be37:	ff 
 117be38:	c5 fc 10 85 90 df ff 	vmovups -0x2070(%rbp),%ymm0
 117be3f:	ff 
 117be40:	c5 fc 11 85 50 d8 ff 	vmovups %ymm0,-0x27b0(%rbp)
 117be47:	ff 
 117be48:	c5 fc 10 85 10 df ff 	vmovups -0x20f0(%rbp),%ymm0
 117be4f:	ff 
 117be50:	c5 fc 10 8d 50 df ff 	vmovups -0x20b0(%rbp),%ymm1
 117be57:	ff 
 117be58:	c5 fc 10 95 70 df ff 	vmovups -0x2090(%rbp),%ymm2
 117be5f:	ff 
 117be60:	c5 fc 11 95 30 d8 ff 	vmovups %ymm2,-0x27d0(%rbp)
 117be67:	ff 
 117be68:	c5 fc 11 8d 10 d8 ff 	vmovups %ymm1,-0x27f0(%rbp)
 117be6f:	ff 
 117be70:	c5 fc 10 8d 30 df ff 	vmovups -0x20d0(%rbp),%ymm1
 117be77:	ff 
 117be78:	c5 fc 11 8d f0 d7 ff 	vmovups %ymm1,-0x2810(%rbp)
 117be7f:	ff 
 117be80:	c5 fc 11 85 d0 d7 ff 	vmovups %ymm0,-0x2830(%rbp)
 117be87:	ff 
 117be88:	48 8d 85 d0 d7 ff ff 	lea    -0x2830(%rbp),%rax
 117be8f:	c5 fc 10 80 e0 00 00 	vmovups 0xe0(%rax),%ymm0
 117be96:	00 
 117be97:	c5 fc 11 85 e0 e6 ff 	vmovups %ymm0,-0x1920(%rbp)
 117be9e:	ff 
 117be9f:	c5 fc 10 80 c0 00 00 	vmovups 0xc0(%rax),%ymm0
 117bea6:	00 
 117bea7:	c5 fc 11 85 c0 e6 ff 	vmovups %ymm0,-0x1940(%rbp)
 117beae:	ff 
 117beaf:	c5 fc 10 80 a0 00 00 	vmovups 0xa0(%rax),%ymm0
 117beb6:	00 
 117beb7:	c5 fc 11 85 a0 e6 ff 	vmovups %ymm0,-0x1960(%rbp)
 117bebe:	ff 
 117bebf:	c5 fc 10 80 80 00 00 	vmovups 0x80(%rax),%ymm0
 117bec6:	00 
 117bec7:	c5 fc 11 85 80 e6 ff 	vmovups %ymm0,-0x1980(%rbp)
 117bece:	ff 
 117becf:	c5 fc 10 00          	vmovups (%rax),%ymm0
 117bed3:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 117bed8:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 117bedd:	c5 fc 10 58 60       	vmovups 0x60(%rax),%ymm3
 117bee2:	c5 fc 11 9d 60 e6 ff 	vmovups %ymm3,-0x19a0(%rbp)
 117bee9:	ff 
 117beea:	c5 fc 11 95 40 e6 ff 	vmovups %ymm2,-0x19c0(%rbp)
 117bef1:	ff 
 117bef2:	c5 fc 11 8d 20 e6 ff 	vmovups %ymm1,-0x19e0(%rbp)
 117bef9:	ff 
 117befa:	c5 fc 11 85 00 e6 ff 	vmovups %ymm0,-0x1a00(%rbp)
 117bf01:	ff 
 117bf02:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 117bf06:	80 78 50 00          	cmpb   $0x0,0x50(%rax)
 117bf0a:	0f 84 1f 01 00 00    	je     117c02f <br.encodeCommandPlanWithOptionsWrite+0x2c8f>
 117bf10:	80 bd b8 fd ff ff 00 	cmpb   $0x0,-0x248(%rbp)
 117bf17:	0f 84 f2 00 00 00    	je     117c00f <br.encodeCommandPlanWithOptionsWrite+0x2c6f>
 117bf1d:	44 0f b6 ad b8 fd ff 	movzbl -0x248(%rbp),%r13d
 117bf24:	ff 
 117bf25:	4c 8d bd c8 d4 ff ff 	lea    -0x2b38(%rbp),%r15
 117bf2c:	41 c1 e5 08          	shl    $0x8,%r13d
 117bf30:	48 8d 9d 50 ba fb ff 	lea    -0x445b0(%rbp),%rbx
 117bf37:	4c 8d b5 50 1d fd ff 	lea    -0x2e2b0(%rbp),%r14
 117bf3e:	45 31 e4             	xor    %r12d,%r12d
 117bf41:	48 8d bd c6 d4 ff ff 	lea    -0x2b3a(%rbp),%rdi
 117bf48:	4c 89 f6             	mov    %r14,%rsi
 117bf4b:	48 89 da             	mov    %rbx,%rdx
 117bf4e:	c5 f8 77             	vzeroupper 
 117bf51:	e8 7a 92 ff ff       	call   11751d0 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths>
 117bf56:	0f b7 85 c6 d4 ff ff 	movzwl -0x2b3a(%rbp),%eax
 117bf5d:	66 85 c0             	test   %ax,%ax
 117bf60:	0f 85 a7 d4 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117bf66:	c4 c1 7c 10 87 e0 00 	vmovups 0xe0(%r15),%ymm0
 117bf6d:	00 00 
 117bf6f:	c4 a1 7c 11 84 25 34 	vmovups %ymm0,-0x165cc(%rbp,%r12,1)
 117bf76:	9a fe ff 
 117bf79:	c4 c1 7c 10 87 c0 00 	vmovups 0xc0(%r15),%ymm0
 117bf80:	00 00 
 117bf82:	c4 a1 7c 11 84 25 14 	vmovups %ymm0,-0x165ec(%rbp,%r12,1)
 117bf89:	9a fe ff 
 117bf8c:	c4 c1 7c 10 87 a0 00 	vmovups 0xa0(%r15),%ymm0
 117bf93:	00 00 
 117bf95:	c4 a1 7c 11 84 25 f4 	vmovups %ymm0,-0x1660c(%rbp,%r12,1)
 117bf9c:	99 fe ff 
 117bf9f:	c4 c1 7c 10 87 80 00 	vmovups 0x80(%r15),%ymm0
 117bfa6:	00 00 
 117bfa8:	c4 a1 7c 11 84 25 d4 	vmovups %ymm0,-0x1662c(%rbp,%r12,1)
 117bfaf:	99 fe ff 
 117bfb2:	c4 c1 7c 10 07       	vmovups (%r15),%ymm0
 117bfb7:	c4 c1 7c 10 4f 20    	vmovups 0x20(%r15),%ymm1
 117bfbd:	c4 c1 7c 10 57 40    	vmovups 0x40(%r15),%ymm2
 117bfc3:	c4 c1 7c 10 5f 60    	vmovups 0x60(%r15),%ymm3
 117bfc9:	c4 a1 7c 11 9c 25 b4 	vmovups %ymm3,-0x1664c(%rbp,%r12,1)
 117bfd0:	99 fe ff 
 117bfd3:	c4 a1 7c 11 94 25 94 	vmovups %ymm2,-0x1666c(%rbp,%r12,1)
 117bfda:	99 fe ff 
 117bfdd:	c4 a1 7c 11 8c 25 74 	vmovups %ymm1,-0x1668c(%rbp,%r12,1)
 117bfe4:	99 fe ff 
 117bfe7:	c4 a1 7c 11 84 25 54 	vmovups %ymm0,-0x166ac(%rbp,%r12,1)
 117bfee:	99 fe ff 
 117bff1:	49 81 c4 00 01 00 00 	add    $0x100,%r12
 117bff8:	48 81 c3 00 04 00 00 	add    $0x400,%rbx
 117bfff:	49 81 c6 08 02 00 00 	add    $0x208,%r14
 117c006:	4d 39 e5             	cmp    %r12,%r13
 117c009:	0f 85 32 ff ff ff    	jne    117bf41 <br.encodeCommandPlanWithOptionsWrite+0x2ba1>
 117c00f:	48 8d 9d d0 48 fb ff 	lea    -0x4b730(%rbp),%rbx
 117c016:	48 8d b5 54 99 fe ff 	lea    -0x166ac(%rbp),%rsi
 117c01d:	ba 00 40 00 00       	mov    $0x4000,%edx
 117c022:	48 89 df             	mov    %rbx,%rdi
 117c025:	c5 f8 77             	vzeroupper 
 117c028:	e8 93 a0 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117c02d:	eb 07                	jmp    117c036 <br.encodeCommandPlanWithOptionsWrite+0x2c96>
 117c02f:	48 8d 1d 42 6f e9 ff 	lea    -0x1690be(%rip),%rbx        # 1012f78 <__anon_35884>
 117c036:	48 8d bd d4 c1 fd ff 	lea    -0x23e2c(%rbp),%rdi
 117c03d:	ba 00 40 00 00       	mov    $0x4000,%edx
 117c042:	48 89 de             	mov    %rbx,%rsi
 117c045:	c5 f8 77             	vzeroupper 
 117c048:	e8 73 a0 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117c04d:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 117c051:	74 1a                	je     117c06d <br.encodeCommandPlanWithOptionsWrite+0x2ccd>
 117c053:	80 7d c0 00          	cmpb   $0x0,-0x40(%rbp)
 117c057:	74 20                	je     117c079 <br.encodeCommandPlanWithOptionsWrite+0x2cd9>
 117c059:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 117c060:	49 89 c4             	mov    %rax,%r12
 117c063:	48 85 c0             	test   %rax,%rax
 117c066:	75 5d                	jne    117c0c5 <br.encodeCommandPlanWithOptionsWrite+0x2d25>
 117c068:	e9 2e 01 00 00       	jmp    117c19b <br.encodeCommandPlanWithOptionsWrite+0x2dfb>
 117c06d:	48 8d 1d 04 af e9 ff 	lea    -0x1650fc(%rip),%rbx        # 1016f78 <__anon_35948>
 117c074:	e9 40 01 00 00       	jmp    117c1b9 <br.encodeCommandPlanWithOptionsWrite+0x2e19>
 117c079:	0f b6 45 c9          	movzbl -0x37(%rbp),%eax
 117c07d:	0a 45 c2             	or     -0x3e(%rbp),%al
 117c080:	a8 01                	test   $0x1,%al
 117c082:	74 0f                	je     117c093 <br.encodeCommandPlanWithOptionsWrite+0x2cf3>
 117c084:	44 0f b6 65 c9       	movzbl -0x37(%rbp),%r12d
 117c089:	41 83 e4 01          	and    $0x1,%r12d
 117c08d:	49 83 f4 03          	xor    $0x3,%r12
 117c091:	eb 32                	jmp    117c0c5 <br.encodeCommandPlanWithOptionsWrite+0x2d25>
 117c093:	41 bc 06 00 00 00    	mov    $0x6,%r12d
 117c099:	80 7d ca 00          	cmpb   $0x0,-0x36(%rbp)
 117c09d:	75 26                	jne    117c0c5 <br.encodeCommandPlanWithOptionsWrite+0x2d25>
 117c09f:	41 bc 05 00 00 00    	mov    $0x5,%r12d
 117c0a5:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 117c0a9:	75 1a                	jne    117c0c5 <br.encodeCommandPlanWithOptionsWrite+0x2d25>
 117c0ab:	41 bc 04 00 00 00    	mov    $0x4,%r12d
 117c0b1:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 117c0b5:	75 0e                	jne    117c0c5 <br.encodeCommandPlanWithOptionsWrite+0x2d25>
 117c0b7:	80 7d c5 01          	cmpb   $0x1,-0x3b(%rbp)
 117c0bb:	41 bc 03 00 00 00    	mov    $0x3,%r12d
 117c0c1:	49 83 dc 00          	sbb    $0x0,%r12
 117c0c5:	48 8d 9d e8 e4 fe ff 	lea    -0x11b18(%rbp),%rbx
 117c0cc:	4c 8d b5 68 8c ff ff 	lea    -0x7398(%rbp),%r14
 117c0d3:	4c 8d bd 98 2e ff ff 	lea    -0xd168(%rbp),%r15
 117c0da:	4c 8d ad c6 d3 ff ff 	lea    -0x2c3a(%rbp),%r13
 117c0e1:	48 8d bd c4 d3 ff ff 	lea    -0x2c3c(%rbp),%rdi
 117c0e8:	4c 89 f6             	mov    %r14,%rsi
 117c0eb:	48 89 da             	mov    %rbx,%rdx
 117c0ee:	c5 f8 77             	vzeroupper 
 117c0f1:	e8 da 90 ff ff       	call   11751d0 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths>
 117c0f6:	0f b7 85 c4 d3 ff ff 	movzwl -0x2c3c(%rbp),%eax
 117c0fd:	66 85 c0             	test   %ax,%ax
 117c100:	0f 85 07 d3 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117c106:	c4 c1 7c 10 85 e0 00 	vmovups 0xe0(%r13),%ymm0
 117c10d:	00 00 
 117c10f:	c4 c1 7c 11 87 e0 00 	vmovups %ymm0,0xe0(%r15)
 117c116:	00 00 
 117c118:	c4 c1 7c 10 85 c0 00 	vmovups 0xc0(%r13),%ymm0
 117c11f:	00 00 
 117c121:	c4 c1 7c 11 87 c0 00 	vmovups %ymm0,0xc0(%r15)
 117c128:	00 00 
 117c12a:	c4 c1 7c 10 85 a0 00 	vmovups 0xa0(%r13),%ymm0
 117c131:	00 00 
 117c133:	c4 c1 7c 11 87 a0 00 	vmovups %ymm0,0xa0(%r15)
 117c13a:	00 00 
 117c13c:	c4 c1 7c 10 85 80 00 	vmovups 0x80(%r13),%ymm0
 117c143:	00 00 
 117c145:	c4 c1 7c 11 87 80 00 	vmovups %ymm0,0x80(%r15)
 117c14c:	00 00 
 117c14e:	c4 c1 7c 10 45 00    	vmovups 0x0(%r13),%ymm0
 117c154:	c4 c1 7c 10 4d 20    	vmovups 0x20(%r13),%ymm1
 117c15a:	c4 c1 7c 10 55 40    	vmovups 0x40(%r13),%ymm2
 117c160:	c4 c1 7c 10 5d 60    	vmovups 0x60(%r13),%ymm3
 117c166:	c4 c1 7c 11 5f 60    	vmovups %ymm3,0x60(%r15)
 117c16c:	c4 c1 7c 11 57 40    	vmovups %ymm2,0x40(%r15)
 117c172:	c4 c1 7c 11 4f 20    	vmovups %ymm1,0x20(%r15)
 117c178:	c4 c1 7c 11 07       	vmovups %ymm0,(%r15)
 117c17d:	48 81 c3 00 04 00 00 	add    $0x400,%rbx
 117c184:	49 81 c6 08 02 00 00 	add    $0x208,%r14
 117c18b:	49 81 c7 00 01 00 00 	add    $0x100,%r15
 117c192:	49 ff cc             	dec    %r12
 117c195:	0f 85 46 ff ff ff    	jne    117c0e1 <br.encodeCommandPlanWithOptionsWrite+0x2d41>
 117c19b:	48 8d 9d 54 d9 fe ff 	lea    -0x126ac(%rbp),%rbx
 117c1a2:	48 8d b5 98 2e ff ff 	lea    -0xd168(%rbp),%rsi
 117c1a9:	ba 00 06 00 00       	mov    $0x600,%edx
 117c1ae:	48 89 df             	mov    %rbx,%rdi
 117c1b1:	c5 f8 77             	vzeroupper 
 117c1b4:	e8 07 9f 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117c1b9:	48 8d bd cc ab ff ff 	lea    -0x5434(%rbp),%rdi
 117c1c0:	ba 00 06 00 00       	mov    $0x600,%edx
 117c1c5:	48 89 de             	mov    %rbx,%rsi
 117c1c8:	e8 f3 9e 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117c1cd:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 117c1d1:	74 39                	je     117c20c <br.encodeCommandPlanWithOptionsWrite+0x2e6c>
 117c1d3:	80 7d c1 00          	cmpb   $0x0,-0x3f(%rbp)
 117c1d7:	74 4f                	je     117c228 <br.encodeCommandPlanWithOptionsWrite+0x2e88>
 117c1d9:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 117c1e0:	49 89 c6             	mov    %rax,%r14
 117c1e3:	48 85 c0             	test   %rax,%rax
 117c1e6:	0f 85 a2 00 00 00    	jne    117c28e <br.encodeCommandPlanWithOptionsWrite+0x2eee>
 117c1ec:	48 8d 9d 54 b1 fd ff 	lea    -0x24eac(%rbp),%rbx
 117c1f3:	48 8d b5 d4 67 fe ff 	lea    -0x1982c(%rbp),%rsi
 117c1fa:	ba 80 10 00 00       	mov    $0x1080,%edx
 117c1ff:	48 89 df             	mov    %rbx,%rdi
 117c202:	e8 b9 9e 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117c207:	e9 74 01 00 00       	jmp    117c380 <br.encodeCommandPlanWithOptionsWrite+0x2fe0>
 117c20c:	f6 85 08 ff ff ff 01 	testb  $0x1,-0xf8(%rbp)
 117c213:	74 2d                	je     117c242 <br.encodeCommandPlanWithOptionsWrite+0x2ea2>
 117c215:	48 8d 9d 4a 72 ff ff 	lea    -0x8db6(%rbp),%rbx
 117c21c:	48 8d b5 0a a6 ff ff 	lea    -0x59f6(%rbp),%rsi
 117c223:	e9 30 01 00 00       	jmp    117c358 <br.encodeCommandPlanWithOptionsWrite+0x2fb8>
 117c228:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 117c22c:	0a 45 c7             	or     -0x39(%rbp),%al
 117c22f:	a8 01                	test   $0x1,%al
 117c231:	74 29                	je     117c25c <br.encodeCommandPlanWithOptionsWrite+0x2ebc>
 117c233:	44 0f b6 75 d2       	movzbl -0x2e(%rbp),%r14d
 117c238:	41 83 e6 01          	and    $0x1,%r14d
 117c23c:	49 83 f6 03          	xor    $0x3,%r14
 117c240:	eb 4c                	jmp    117c28e <br.encodeCommandPlanWithOptionsWrite+0x2eee>
 117c242:	48 83 bd b0 c5 ff ff 	cmpq   $0x5,-0x3a50(%rbp)
 117c249:	05 
 117c24a:	0f 83 d0 00 00 00    	jae    117c320 <br.encodeCommandPlanWithOptionsWrite+0x2f80>
 117c250:	48 8d 1d 0d 56 e9 ff 	lea    -0x16a9f3(%rip),%rbx        # 1011864 <__anon_35957>
 117c257:	e9 09 01 00 00       	jmp    117c365 <br.encodeCommandPlanWithOptionsWrite+0x2fc5>
 117c25c:	41 be 06 00 00 00    	mov    $0x6,%r14d
 117c262:	80 7d cd 00          	cmpb   $0x0,-0x33(%rbp)
 117c266:	75 26                	jne    117c28e <br.encodeCommandPlanWithOptionsWrite+0x2eee>
 117c268:	41 be 05 00 00 00    	mov    $0x5,%r14d
 117c26e:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 117c272:	75 1a                	jne    117c28e <br.encodeCommandPlanWithOptionsWrite+0x2eee>
 117c274:	41 be 04 00 00 00    	mov    $0x4,%r14d
 117c27a:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 117c27e:	75 0e                	jne    117c28e <br.encodeCommandPlanWithOptionsWrite+0x2eee>
 117c280:	80 7d cb 01          	cmpb   $0x1,-0x35(%rbp)
 117c284:	41 be 03 00 00 00    	mov    $0x3,%r14d
 117c28a:	49 83 de 00          	sbb    $0x0,%r14
 117c28e:	4c 8d bd d4 01 fe ff 	lea    -0x1fe2c(%rbp),%r15
 117c295:	4c 8d a5 e8 fc fe ff 	lea    -0x10318(%rbp),%r12
 117c29c:	48 8d 9d d4 67 fe ff 	lea    -0x1982c(%rbp),%rbx
 117c2a3:	eb 2b                	jmp    117c2d0 <br.encodeCommandPlanWithOptionsWrite+0x2f30>
 117c2a5:	ba c0 02 00 00       	mov    $0x2c0,%edx
 117c2aa:	48 89 df             	mov    %rbx,%rdi
 117c2ad:	e8 0e 9e 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117c2b2:	49 81 c7 00 0b 00 00 	add    $0xb00,%r15
 117c2b9:	49 81 c4 88 05 00 00 	add    $0x588,%r12
 117c2c0:	48 81 c3 c0 02 00 00 	add    $0x2c0,%rbx
 117c2c7:	49 ff ce             	dec    %r14
 117c2ca:	0f 84 1c ff ff ff    	je     117c1ec <br.encodeCommandPlanWithOptionsWrite+0x2e4c>
 117c2d0:	49 83 3c 24 05       	cmpq   $0x5,(%r12)
 117c2d5:	48 8d 35 88 55 e9 ff 	lea    -0x16aa78(%rip),%rsi        # 1011864 <__anon_35957>
 117c2dc:	72 c7                	jb     117c2a5 <br.encodeCommandPlanWithOptionsWrite+0x2f05>
 117c2de:	48 8d bd a6 b6 ff ff 	lea    -0x495a(%rbp),%rdi
 117c2e5:	4c 89 e6             	mov    %r12,%rsi
 117c2e8:	4c 89 fa             	mov    %r15,%rdx
 117c2eb:	e8 50 98 ff ff       	call   1175b40 <br.encoder.command_plan.PrefixAlphabetFor(704).codeLengths>
 117c2f0:	0f b7 85 a6 b6 ff ff 	movzwl -0x495a(%rbp),%eax
 117c2f7:	66 85 c0             	test   %ax,%ax
 117c2fa:	0f 85 0d d1 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117c300:	ba c0 02 00 00       	mov    $0x2c0,%edx
 117c305:	4c 8d ad ca 6c ff ff 	lea    -0x9336(%rbp),%r13
 117c30c:	4c 89 ef             	mov    %r13,%rdi
 117c30f:	48 8d b5 a8 b6 ff ff 	lea    -0x4958(%rbp),%rsi
 117c316:	e8 a5 9d 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117c31b:	4c 89 ee             	mov    %r13,%rsi
 117c31e:	eb 85                	jmp    117c2a5 <br.encodeCommandPlanWithOptionsWrite+0x2f05>
 117c320:	48 8d bd 68 b9 ff ff 	lea    -0x4698(%rbp),%rdi
 117c327:	48 8d b5 b0 c5 ff ff 	lea    -0x3a50(%rbp),%rsi
 117c32e:	48 8d 95 8c 7f ff ff 	lea    -0x8074(%rbp),%rdx
 117c335:	e8 06 98 ff ff       	call   1175b40 <br.encoder.command_plan.PrefixAlphabetFor(704).codeLengths>
 117c33a:	0f b7 85 68 b9 ff ff 	movzwl -0x4698(%rbp),%eax
 117c341:	66 85 c0             	test   %ax,%ax
 117c344:	0f 85 c3 d0 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117c34a:	48 8d b5 6a b9 ff ff 	lea    -0x4696(%rbp),%rsi
 117c351:	48 8d 9d 8a 6f ff ff 	lea    -0x9076(%rbp),%rbx
 117c358:	ba c0 02 00 00       	mov    $0x2c0,%edx
 117c35d:	48 89 df             	mov    %rbx,%rdi
 117c360:	e8 5b 9d 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117c365:	48 8d bd 2a cf ff ff 	lea    -0x30d6(%rbp),%rdi
 117c36c:	ba c0 02 00 00       	mov    $0x2c0,%edx
 117c371:	48 89 de             	mov    %rbx,%rsi
 117c374:	e8 47 9d 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117c379:	48 8d 1d f8 b1 e9 ff 	lea    -0x164e08(%rip),%rbx        # 1017578 <__anon_35990>
 117c380:	48 8d bd 18 1e ff ff 	lea    -0xe1e8(%rbp),%rdi
 117c387:	ba 80 10 00 00       	mov    $0x1080,%edx
 117c38c:	48 89 bd 30 fd ff ff 	mov    %rdi,-0x2d0(%rbp)
 117c393:	48 89 de             	mov    %rbx,%rsi
 117c396:	e8 25 9d 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117c39b:	80 7d cc 00          	cmpb   $0x0,-0x34(%rbp)
 117c39f:	74 3c                	je     117c3dd <br.encodeCommandPlanWithOptionsWrite+0x303d>
 117c3a1:	80 7d c4 00          	cmpb   $0x0,-0x3c(%rbp)
 117c3a5:	74 7b                	je     117c422 <br.encodeCommandPlanWithOptionsWrite+0x3082>
 117c3a7:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 117c3ae:	49 89 c4             	mov    %rax,%r12
 117c3b1:	48 85 c0             	test   %rax,%rax
 117c3b4:	0f 85 ce 00 00 00    	jne    117c488 <br.encodeCommandPlanWithOptionsWrite+0x30e8>
 117c3ba:	48 8d 9d 8e 8a ff ff 	lea    -0x7572(%rbp),%rbx
 117c3c1:	48 8d b5 cc b4 ff ff 	lea    -0x4b34(%rbp),%rsi
 117c3c8:	ba da 01 00 00       	mov    $0x1da,%edx
 117c3cd:	48 89 df             	mov    %rbx,%rdi
 117c3d0:	c5 f8 77             	vzeroupper 
 117c3d3:	e8 e8 9c 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117c3d8:	e9 f8 01 00 00       	jmp    117c5d5 <br.encodeCommandPlanWithOptionsWrite+0x3235>
 117c3dd:	f6 85 08 ff ff ff 01 	testb  $0x1,-0xf8(%rbp)
 117c3e4:	74 56                	je     117c43c <br.encodeCommandPlanWithOptionsWrite+0x309c>
 117c3e6:	c5 fc 10 85 e1 e9 ff 	vmovups -0x161f(%rbp),%ymm0
 117c3ed:	ff 
 117c3ee:	c5 fc 10 8d 10 ea ff 	vmovups -0x15f0(%rbp),%ymm1
 117c3f5:	ff 
 117c3f6:	c5 fc 11 8d ff ea ff 	vmovups %ymm1,-0x1501(%rbp)
 117c3fd:	ff 
 117c3fe:	c5 fc 10 8d 01 ea ff 	vmovups -0x15ff(%rbp),%ymm1
 117c405:	ff 
 117c406:	c5 fc 11 8d f0 ea ff 	vmovups %ymm1,-0x1510(%rbp)
 117c40d:	ff 
 117c40e:	c5 fc 11 85 d0 ea ff 	vmovups %ymm0,-0x1530(%rbp)
 117c415:	ff 
 117c416:	48 8d 85 d0 ea ff ff 	lea    -0x1530(%rbp),%rax
 117c41d:	e9 86 01 00 00       	jmp    117c5a8 <br.encodeCommandPlanWithOptionsWrite+0x3208>
 117c422:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 117c426:	0a 45 c8             	or     -0x38(%rbp),%al
 117c429:	a8 01                	test   $0x1,%al
 117c42b:	74 29                	je     117c456 <br.encodeCommandPlanWithOptionsWrite+0x30b6>
 117c42d:	44 0f b6 65 d3       	movzbl -0x2d(%rbp),%r12d
 117c432:	41 83 e4 01          	and    $0x1,%r12d
 117c436:	49 83 f4 03          	xor    $0x3,%r12
 117c43a:	eb 4c                	jmp    117c488 <br.encodeCommandPlanWithOptionsWrite+0x30e8>
 117c43c:	48 83 bd d0 f0 ff ff 	cmpq   $0x5,-0xf30(%rbp)
 117c443:	05 
 117c444:	0f 83 fd 00 00 00    	jae    117c547 <br.encodeCommandPlanWithOptionsWrite+0x31a7>
 117c44a:	48 8d 05 25 57 e9 ff 	lea    -0x16a8db(%rip),%rax        # 1011b76 <__anon_35994>
 117c451:	e9 52 01 00 00       	jmp    117c5a8 <br.encodeCommandPlanWithOptionsWrite+0x3208>
 117c456:	41 bc 06 00 00 00    	mov    $0x6,%r12d
 117c45c:	80 7d ce 00          	cmpb   $0x0,-0x32(%rbp)
 117c460:	75 26                	jne    117c488 <br.encodeCommandPlanWithOptionsWrite+0x30e8>
 117c462:	41 bc 05 00 00 00    	mov    $0x5,%r12d
 117c468:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 117c46c:	75 1a                	jne    117c488 <br.encodeCommandPlanWithOptionsWrite+0x30e8>
 117c46e:	41 bc 04 00 00 00    	mov    $0x4,%r12d
 117c474:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 117c478:	75 0e                	jne    117c488 <br.encodeCommandPlanWithOptionsWrite+0x30e8>
 117c47a:	80 7d d5 01          	cmpb   $0x1,-0x2b(%rbp)
 117c47e:	41 bc 03 00 00 00    	mov    $0x3,%r12d
 117c484:	49 83 dc 00          	sbb    $0x0,%r12
 117c488:	48 8d 9d a0 9e ff ff 	lea    -0x6160(%rbp),%rbx
 117c48f:	4c 8d bd 38 cb ff ff 	lea    -0x34c8(%rbp),%r15
 117c496:	4c 8d b5 cc b4 ff ff 	lea    -0x4b34(%rbp),%r14
 117c49d:	4c 8d 2d d2 56 e9 ff 	lea    -0x16a92e(%rip),%r13        # 1011b76 <__anon_35994>
 117c4a4:	eb 3a                	jmp    117c4e0 <br.encodeCommandPlanWithOptionsWrite+0x3140>
 117c4a6:	c5 fc 10 00          	vmovups (%rax),%ymm0
 117c4aa:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 117c4af:	c5 fc 10 50 2f       	vmovups 0x2f(%rax),%ymm2
 117c4b4:	c4 c1 7c 11 56 2f    	vmovups %ymm2,0x2f(%r14)
 117c4ba:	c4 c1 7c 11 4e 20    	vmovups %ymm1,0x20(%r14)
 117c4c0:	c4 c1 7c 11 06       	vmovups %ymm0,(%r14)
 117c4c5:	48 81 c3 3c 01 00 00 	add    $0x13c,%rbx
 117c4cc:	49 81 c7 a8 00 00 00 	add    $0xa8,%r15
 117c4d3:	49 83 c6 4f          	add    $0x4f,%r14
 117c4d7:	49 ff cc             	dec    %r12
 117c4da:	0f 84 da fe ff ff    	je     117c3ba <br.encodeCommandPlanWithOptionsWrite+0x301a>
 117c4e0:	49 83 3f 05          	cmpq   $0x5,(%r15)
 117c4e4:	4c 89 e8             	mov    %r13,%rax
 117c4e7:	72 bd                	jb     117c4a6 <br.encodeCommandPlanWithOptionsWrite+0x3106>
 117c4e9:	48 8d bd de d8 ff ff 	lea    -0x2722(%rbp),%rdi
 117c4f0:	4c 89 fe             	mov    %r15,%rsi
 117c4f3:	48 89 da             	mov    %rbx,%rdx
 117c4f6:	c5 f8 77             	vzeroupper 
 117c4f9:	e8 c2 9e ff ff       	call   11763c0 <br.encoder.command_plan.PrefixAlphabetFor(79).codeLengths>
 117c4fe:	0f b7 85 de d8 ff ff 	movzwl -0x2722(%rbp),%eax
 117c505:	66 85 c0             	test   %ax,%ax
 117c508:	0f 85 ff ce ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117c50e:	48 8d 85 e0 d8 ff ff 	lea    -0x2720(%rbp),%rax
 117c515:	c5 fc 10 00          	vmovups (%rax),%ymm0
 117c519:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 117c51e:	c5 fc 10 50 2f       	vmovups 0x2f(%rax),%ymm2
 117c523:	c5 fc 11 95 5f ea ff 	vmovups %ymm2,-0x15a1(%rbp)
 117c52a:	ff 
 117c52b:	c5 fc 11 8d 50 ea ff 	vmovups %ymm1,-0x15b0(%rbp)
 117c532:	ff 
 117c533:	c5 fc 11 85 30 ea ff 	vmovups %ymm0,-0x15d0(%rbp)
 117c53a:	ff 
 117c53b:	48 8d 85 30 ea ff ff 	lea    -0x15d0(%rbp),%rax
 117c542:	e9 5f ff ff ff       	jmp    117c4a6 <br.encodeCommandPlanWithOptionsWrite+0x3106>
 117c547:	48 8d bd fe ed ff ff 	lea    -0x1202(%rbp),%rdi
 117c54e:	48 8d b5 d0 f0 ff ff 	lea    -0xf30(%rbp),%rsi
 117c555:	48 8d 95 20 eb ff ff 	lea    -0x14e0(%rbp),%rdx
 117c55c:	e8 5f 9e ff ff       	call   11763c0 <br.encoder.command_plan.PrefixAlphabetFor(79).codeLengths>
 117c561:	0f b7 85 fe ed ff ff 	movzwl -0x1202(%rbp),%eax
 117c568:	66 85 c0             	test   %ax,%ax
 117c56b:	0f 85 9c ce ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117c571:	c5 fc 10 85 00 ee ff 	vmovups -0x1200(%rbp),%ymm0
 117c578:	ff 
 117c579:	c5 fc 10 8d 2f ee ff 	vmovups -0x11d1(%rbp),%ymm1
 117c580:	ff 
 117c581:	c5 fc 11 8d af ea ff 	vmovups %ymm1,-0x1551(%rbp)
 117c588:	ff 
 117c589:	c5 fc 10 8d 20 ee ff 	vmovups -0x11e0(%rbp),%ymm1
 117c590:	ff 
 117c591:	c5 fc 11 8d a0 ea ff 	vmovups %ymm1,-0x1560(%rbp)
 117c598:	ff 
 117c599:	c5 fc 11 85 80 ea ff 	vmovups %ymm0,-0x1580(%rbp)
 117c5a0:	ff 
 117c5a1:	48 8d 85 80 ea ff ff 	lea    -0x1580(%rbp),%rax
 117c5a8:	c5 fc 10 00          	vmovups (%rax),%ymm0
 117c5ac:	c5 fc 10 48 2f       	vmovups 0x2f(%rax),%ymm1
 117c5b1:	c5 fc 11 8d 4f f2 ff 	vmovups %ymm1,-0xdb1(%rbp)
 117c5b8:	ff 
 117c5b9:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 117c5be:	c5 fc 11 8d 40 f2 ff 	vmovups %ymm1,-0xdc0(%rbp)
 117c5c5:	ff 
 117c5c6:	c5 fc 11 85 20 f2 ff 	vmovups %ymm0,-0xde0(%rbp)
 117c5cd:	ff 
 117c5ce:	48 8d 1d 23 c0 e9 ff 	lea    -0x163fdd(%rip),%rbx        # 10185f8 <__anon_36028>
 117c5d5:	48 8d bd ea d1 ff ff 	lea    -0x2e16(%rbp),%rdi
 117c5dc:	ba da 01 00 00       	mov    $0x1da,%edx
 117c5e1:	48 89 bd 08 ff ff ff 	mov    %rdi,-0xf8(%rbp)
 117c5e8:	48 89 de             	mov    %rbx,%rsi
 117c5eb:	c5 f8 77             	vzeroupper 
 117c5ee:	e8 cd 9a 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117c5f3:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 117c5f7:	0f 84 da 01 00 00    	je     117c7d7 <br.encodeCommandPlanWithOptionsWrite+0x3437>
 117c5fd:	48 8b 85 60 ff ff ff 	mov    -0xa0(%rbp),%rax
 117c604:	48 89 85 40 fb ff ff 	mov    %rax,-0x4c0(%rbp)
 117c60b:	48 8b 85 10 ff ff ff 	mov    -0xf0(%rbp),%rax
 117c612:	48 89 85 48 fb ff ff 	mov    %rax,-0x4b8(%rbp)
 117c619:	0f b6 45 c5          	movzbl -0x3b(%rbp),%eax
 117c61d:	88 85 50 fb ff ff    	mov    %al,-0x4b0(%rbp)
 117c623:	8b 85 04 fe ff ff    	mov    -0x1fc(%rbp),%eax
 117c629:	8b 8d 07 fe ff ff    	mov    -0x1f9(%rbp),%ecx
 117c62f:	89 85 51 fb ff ff    	mov    %eax,-0x4af(%rbp)
 117c635:	89 8d 54 fb ff ff    	mov    %ecx,-0x4ac(%rbp)
 117c63b:	48 8b 85 18 ff ff ff 	mov    -0xe8(%rbp),%rax
 117c642:	48 89 85 58 fb ff ff 	mov    %rax,-0x4a8(%rbp)
 117c649:	0f b6 45 cf          	movzbl -0x31(%rbp),%eax
 117c64d:	88 85 60 fb ff ff    	mov    %al,-0x4a0(%rbp)
 117c653:	8b 85 0c fe ff ff    	mov    -0x1f4(%rbp),%eax
 117c659:	8b 8d 0f fe ff ff    	mov    -0x1f1(%rbp),%ecx
 117c65f:	89 85 61 fb ff ff    	mov    %eax,-0x49f(%rbp)
 117c665:	89 8d 64 fb ff ff    	mov    %ecx,-0x49c(%rbp)
 117c66b:	48 8b 85 20 ff ff ff 	mov    -0xe0(%rbp),%rax
 117c672:	48 89 85 68 fb ff ff 	mov    %rax,-0x498(%rbp)
 117c679:	0f b6 45 d1          	movzbl -0x2f(%rbp),%eax
 117c67d:	88 85 70 fb ff ff    	mov    %al,-0x490(%rbp)
 117c683:	8b 85 14 fe ff ff    	mov    -0x1ec(%rbp),%eax
 117c689:	8b 8d 17 fe ff ff    	mov    -0x1e9(%rbp),%ecx
 117c68f:	89 85 71 fb ff ff    	mov    %eax,-0x48f(%rbp)
 117c695:	89 8d 74 fb ff ff    	mov    %ecx,-0x48c(%rbp)
 117c69b:	48 8b 85 f0 fe ff ff 	mov    -0x110(%rbp),%rax
 117c6a2:	48 89 85 78 fb ff ff 	mov    %rax,-0x488(%rbp)
 117c6a9:	0f b6 45 ca          	movzbl -0x36(%rbp),%eax
 117c6ad:	88 85 80 fb ff ff    	mov    %al,-0x480(%rbp)
 117c6b3:	8b 85 1c fe ff ff    	mov    -0x1e4(%rbp),%eax
 117c6b9:	8b 8d 1f fe ff ff    	mov    -0x1e1(%rbp),%ecx
 117c6bf:	89 85 81 fb ff ff    	mov    %eax,-0x47f(%rbp)
 117c6c5:	89 8d 84 fb ff ff    	mov    %ecx,-0x47c(%rbp)
 117c6cb:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 117c6d2:	48 89 85 88 fb ff ff 	mov    %rax,-0x478(%rbp)
 117c6d9:	0f b6 45 c0          	movzbl -0x40(%rbp),%eax
 117c6dd:	88 85 90 fb ff ff    	mov    %al,-0x470(%rbp)
 117c6e3:	8b 85 24 fe ff ff    	mov    -0x1dc(%rbp),%eax
 117c6e9:	8b 8d 27 fe ff ff    	mov    -0x1d9(%rbp),%ecx
 117c6ef:	89 85 91 fb ff ff    	mov    %eax,-0x46f(%rbp)
 117c6f5:	89 8d 94 fb ff ff    	mov    %ecx,-0x46c(%rbp)
 117c6fb:	48 8b 85 00 fd ff ff 	mov    -0x300(%rbp),%rax
 117c702:	48 89 85 98 fb ff ff 	mov    %rax,-0x468(%rbp)
 117c709:	0f b6 45 c9          	movzbl -0x37(%rbp),%eax
 117c70d:	88 85 a0 fb ff ff    	mov    %al,-0x460(%rbp)
 117c713:	0f b6 45 c2          	movzbl -0x3e(%rbp),%eax
 117c717:	88 85 a1 fb ff ff    	mov    %al,-0x45f(%rbp)
 117c71d:	0f b7 85 4c fe ff ff 	movzwl -0x1b4(%rbp),%eax
 117c724:	66 89 85 a6 fb ff ff 	mov    %ax,-0x45a(%rbp)
 117c72b:	8b 85 48 fe ff ff    	mov    -0x1b8(%rbp),%eax
 117c731:	89 85 a2 fb ff ff    	mov    %eax,-0x45e(%rbp)
 117c737:	48 8d bd d0 e3 ff ff 	lea    -0x1c30(%rbp),%rdi
 117c73e:	48 8d b5 40 fb ff ff 	lea    -0x4c0(%rbp),%rsi
 117c745:	48 8b 55 90          	mov    -0x70(%rbp),%rdx
 117c749:	e8 32 c9 03 00       	call   11b9080 <br.LiteralBlockLengthCode.init>
 117c74e:	0f b7 85 a0 e4 ff ff 	movzwl -0x1b60(%rbp),%eax
 117c755:	66 85 c0             	test   %ax,%ax
 117c758:	0f 85 af cc ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117c75e:	c5 fc 10 85 80 e4 ff 	vmovups -0x1b80(%rbp),%ymm0
 117c765:	ff 
 117c766:	c5 fc 11 85 e0 de ff 	vmovups %ymm0,-0x2120(%rbp)
 117c76d:	ff 
 117c76e:	c5 fc 10 85 70 e4 ff 	vmovups -0x1b90(%rbp),%ymm0
 117c775:	ff 
 117c776:	c5 fc 11 85 d0 de ff 	vmovups %ymm0,-0x2130(%rbp)
 117c77d:	ff 
 117c77e:	c5 fc 10 85 50 e4 ff 	vmovups -0x1bb0(%rbp),%ymm0
 117c785:	ff 
 117c786:	c5 fc 11 85 b0 de ff 	vmovups %ymm0,-0x2150(%rbp)
 117c78d:	ff 
 117c78e:	c5 fc 10 85 d0 e3 ff 	vmovups -0x1c30(%rbp),%ymm0
 117c795:	ff 
 117c796:	c5 fc 10 8d 10 e4 ff 	vmovups -0x1bf0(%rbp),%ymm1
 117c79d:	ff 
 117c79e:	c5 fc 10 95 30 e4 ff 	vmovups -0x1bd0(%rbp),%ymm2
 117c7a5:	ff 
 117c7a6:	c5 fc 11 95 90 de ff 	vmovups %ymm2,-0x2170(%rbp)
 117c7ad:	ff 
 117c7ae:	c5 fc 11 8d 70 de ff 	vmovups %ymm1,-0x2190(%rbp)
 117c7b5:	ff 
 117c7b6:	c5 fc 10 8d f0 e3 ff 	vmovups -0x1c10(%rbp),%ymm1
 117c7bd:	ff 
 117c7be:	c5 fc 11 8d 50 de ff 	vmovups %ymm1,-0x21b0(%rbp)
 117c7c5:	ff 
 117c7c6:	c5 fc 11 85 30 de ff 	vmovups %ymm0,-0x21d0(%rbp)
 117c7cd:	ff 
 117c7ce:	48 8d 85 30 de ff ff 	lea    -0x21d0(%rbp),%rax
 117c7d5:	eb 07                	jmp    117c7de <br.encodeCommandPlanWithOptionsWrite+0x343e>
 117c7d7:	48 8d 05 fa bf e9 ff 	lea    -0x164006(%rip),%rax        # 10187d8 <__anon_36046>
 117c7de:	c5 fc 10 80 b0 00 00 	vmovups 0xb0(%rax),%ymm0
 117c7e5:	00 
 117c7e6:	c5 fc 11 85 50 e9 ff 	vmovups %ymm0,-0x16b0(%rbp)
 117c7ed:	ff 
 117c7ee:	c5 fc 10 80 a0 00 00 	vmovups 0xa0(%rax),%ymm0
 117c7f5:	00 
 117c7f6:	c5 fc 11 85 40 e9 ff 	vmovups %ymm0,-0x16c0(%rbp)
 117c7fd:	ff 
 117c7fe:	c5 fc 10 80 80 00 00 	vmovups 0x80(%rax),%ymm0
 117c805:	00 
 117c806:	c5 fc 11 85 20 e9 ff 	vmovups %ymm0,-0x16e0(%rbp)
 117c80d:	ff 
 117c80e:	c5 fc 10 00          	vmovups (%rax),%ymm0
 117c812:	c5 fc 10 48 40       	vmovups 0x40(%rax),%ymm1
 117c817:	c5 fc 10 50 60       	vmovups 0x60(%rax),%ymm2
 117c81c:	c5 fc 11 95 00 e9 ff 	vmovups %ymm2,-0x1700(%rbp)
 117c823:	ff 
 117c824:	c5 fc 11 8d e0 e8 ff 	vmovups %ymm1,-0x1720(%rbp)
 117c82b:	ff 
 117c82c:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 117c831:	c5 fc 11 8d c0 e8 ff 	vmovups %ymm1,-0x1740(%rbp)
 117c838:	ff 
 117c839:	c5 fc 11 85 a0 e8 ff 	vmovups %ymm0,-0x1760(%rbp)
 117c840:	ff 
 117c841:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 117c845:	0f 84 ea 01 00 00    	je     117ca35 <br.encodeCommandPlanWithOptionsWrite+0x3695>
 117c84b:	48 8b 85 38 fe ff ff 	mov    -0x1c8(%rbp),%rax
 117c852:	48 89 85 d8 fa ff ff 	mov    %rax,-0x528(%rbp)
 117c859:	48 8b 85 c0 fd ff ff 	mov    -0x240(%rbp),%rax
 117c860:	48 89 85 e0 fa ff ff 	mov    %rax,-0x520(%rbp)
 117c867:	0f b6 45 cb          	movzbl -0x35(%rbp),%eax
 117c86b:	88 85 e8 fa ff ff    	mov    %al,-0x518(%rbp)
 117c871:	8b 85 78 fe ff ff    	mov    -0x188(%rbp),%eax
 117c877:	8b 8d 7b fe ff ff    	mov    -0x185(%rbp),%ecx
 117c87d:	89 85 e9 fa ff ff    	mov    %eax,-0x517(%rbp)
 117c883:	89 8d ec fa ff ff    	mov    %ecx,-0x514(%rbp)
 117c889:	48 8b 85 c8 fd ff ff 	mov    -0x238(%rbp),%rax
 117c890:	48 89 85 f0 fa ff ff 	mov    %rax,-0x510(%rbp)
 117c897:	0f b6 45 d0          	movzbl -0x30(%rbp),%eax
 117c89b:	88 85 f8 fa ff ff    	mov    %al,-0x508(%rbp)
 117c8a1:	8b 85 80 fe ff ff    	mov    -0x180(%rbp),%eax
 117c8a7:	8b 8d 83 fe ff ff    	mov    -0x17d(%rbp),%ecx
 117c8ad:	89 85 f9 fa ff ff    	mov    %eax,-0x507(%rbp)
 117c8b3:	89 8d fc fa ff ff    	mov    %ecx,-0x504(%rbp)
 117c8b9:	48 8b 85 d0 fd ff ff 	mov    -0x230(%rbp),%rax
 117c8c0:	48 89 85 00 fb ff ff 	mov    %rax,-0x500(%rbp)
 117c8c7:	0f b6 45 d6          	movzbl -0x2a(%rbp),%eax
 117c8cb:	88 85 08 fb ff ff    	mov    %al,-0x4f8(%rbp)
 117c8d1:	8b 85 88 fe ff ff    	mov    -0x178(%rbp),%eax
 117c8d7:	8b 8d 8b fe ff ff    	mov    -0x175(%rbp),%ecx
 117c8dd:	89 85 09 fb ff ff    	mov    %eax,-0x4f7(%rbp)
 117c8e3:	89 8d 0c fb ff ff    	mov    %ecx,-0x4f4(%rbp)
 117c8e9:	48 8b 85 d8 fd ff ff 	mov    -0x228(%rbp),%rax
 117c8f0:	48 89 85 10 fb ff ff 	mov    %rax,-0x4f0(%rbp)
 117c8f7:	0f b6 45 cd          	movzbl -0x33(%rbp),%eax
 117c8fb:	88 85 18 fb ff ff    	mov    %al,-0x4e8(%rbp)
 117c901:	8b 85 90 fe ff ff    	mov    -0x170(%rbp),%eax
 117c907:	8b 8d 93 fe ff ff    	mov    -0x16d(%rbp),%ecx
 117c90d:	89 85 19 fb ff ff    	mov    %eax,-0x4e7(%rbp)
 117c913:	89 8d 1c fb ff ff    	mov    %ecx,-0x4e4(%rbp)
 117c919:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 117c920:	48 89 85 20 fb ff ff 	mov    %rax,-0x4e0(%rbp)
 117c927:	0f b6 45 c1          	movzbl -0x3f(%rbp),%eax
 117c92b:	88 85 28 fb ff ff    	mov    %al,-0x4d8(%rbp)
 117c931:	8b 85 98 fe ff ff    	mov    -0x168(%rbp),%eax
 117c937:	8b 8d 9b fe ff ff    	mov    -0x165(%rbp),%ecx
 117c93d:	89 85 29 fb ff ff    	mov    %eax,-0x4d7(%rbp)
 117c943:	89 8d 2c fb ff ff    	mov    %ecx,-0x4d4(%rbp)
 117c949:	48 8b 85 18 fd ff ff 	mov    -0x2e8(%rbp),%rax
 117c950:	48 89 85 30 fb ff ff 	mov    %rax,-0x4d0(%rbp)
 117c957:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 117c95b:	88 85 38 fb ff ff    	mov    %al,-0x4c8(%rbp)
 117c961:	0f b6 45 c7          	movzbl -0x39(%rbp),%eax
 117c965:	88 85 39 fb ff ff    	mov    %al,-0x4c7(%rbp)
 117c96b:	0f b7 85 e0 fe ff ff 	movzwl -0x120(%rbp),%eax
 117c972:	66 89 85 3e fb ff ff 	mov    %ax,-0x4c2(%rbp)
 117c979:	8b 85 dc fe ff ff    	mov    -0x124(%rbp),%eax
 117c97f:	89 85 3a fb ff ff    	mov    %eax,-0x4c6(%rbp)
 117c985:	48 8d bd d0 e7 ff ff 	lea    -0x1830(%rbp),%rdi
 117c98c:	48 8d b5 d8 fa ff ff 	lea    -0x528(%rbp),%rsi
 117c993:	48 8b 95 58 ff ff ff 	mov    -0xa8(%rbp),%rdx
 117c99a:	c5 f8 77             	vzeroupper 
 117c99d:	e8 5e 3f 03 00       	call   11b0900 <br.CommandBlockLengthCode.init>
 117c9a2:	0f b7 85 98 e8 ff ff 	movzwl -0x1768(%rbp),%eax
 117c9a9:	66 85 c0             	test   %ax,%ax
 117c9ac:	0f 85 5b ca ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117c9b2:	48 8b 85 90 e8 ff ff 	mov    -0x1770(%rbp),%rax
 117c9b9:	48 89 85 f0 ed ff ff 	mov    %rax,-0x1210(%rbp)
 117c9c0:	c5 fc 10 85 70 e8 ff 	vmovups -0x1790(%rbp),%ymm0
 117c9c7:	ff 
 117c9c8:	c5 fc 11 85 d0 ed ff 	vmovups %ymm0,-0x1230(%rbp)
 117c9cf:	ff 
 117c9d0:	c5 fc 10 85 50 e8 ff 	vmovups -0x17b0(%rbp),%ymm0
 117c9d7:	ff 
 117c9d8:	c5 fc 11 85 b0 ed ff 	vmovups %ymm0,-0x1250(%rbp)
 117c9df:	ff 
 117c9e0:	c5 fc 10 85 f0 e7 ff 	vmovups -0x1810(%rbp),%ymm0
 117c9e7:	ff 
 117c9e8:	c5 fc 10 8d 10 e8 ff 	vmovups -0x17f0(%rbp),%ymm1
 117c9ef:	ff 
 117c9f0:	c5 fc 10 95 30 e8 ff 	vmovups -0x17d0(%rbp),%ymm2
 117c9f7:	ff 
 117c9f8:	c5 fc 11 95 90 ed ff 	vmovups %ymm2,-0x1270(%rbp)
 117c9ff:	ff 
 117ca00:	c5 fc 11 8d 70 ed ff 	vmovups %ymm1,-0x1290(%rbp)
 117ca07:	ff 
 117ca08:	c5 fc 11 85 50 ed ff 	vmovups %ymm0,-0x12b0(%rbp)
 117ca0f:	ff 
 117ca10:	c5 fc 10 85 d0 e7 ff 	vmovups -0x1830(%rbp),%ymm0
 117ca17:	ff 
 117ca18:	c5 fc 11 85 30 ed ff 	vmovups %ymm0,-0x12d0(%rbp)
 117ca1f:	ff 
 117ca20:	c6 45 b0 00          	movb   $0x0,-0x50(%rbp)
 117ca24:	b3 01                	mov    $0x1,%bl
 117ca26:	80 7d c1 00          	cmpb   $0x0,-0x3f(%rbp)
 117ca2a:	74 11                	je     117ca3d <br.encodeCommandPlanWithOptionsWrite+0x369d>
 117ca2c:	4c 8b b5 68 ff ff ff 	mov    -0x98(%rbp),%r14
 117ca33:	eb 54                	jmp    117ca89 <br.encodeCommandPlanWithOptionsWrite+0x36e9>
 117ca35:	c6 45 b0 00          	movb   $0x0,-0x50(%rbp)
 117ca39:	31 db                	xor    %ebx,%ebx
 117ca3b:	eb 4c                	jmp    117ca89 <br.encodeCommandPlanWithOptionsWrite+0x36e9>
 117ca3d:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 117ca41:	0a 45 c7             	or     -0x39(%rbp),%al
 117ca44:	a8 01                	test   $0x1,%al
 117ca46:	74 0f                	je     117ca57 <br.encodeCommandPlanWithOptionsWrite+0x36b7>
 117ca48:	44 0f b6 75 d2       	movzbl -0x2e(%rbp),%r14d
 117ca4d:	41 83 e6 01          	and    $0x1,%r14d
 117ca51:	49 83 f6 03          	xor    $0x3,%r14
 117ca55:	eb 32                	jmp    117ca89 <br.encodeCommandPlanWithOptionsWrite+0x36e9>
 117ca57:	41 be 06 00 00 00    	mov    $0x6,%r14d
 117ca5d:	80 7d cd 00          	cmpb   $0x0,-0x33(%rbp)
 117ca61:	75 26                	jne    117ca89 <br.encodeCommandPlanWithOptionsWrite+0x36e9>
 117ca63:	41 be 05 00 00 00    	mov    $0x5,%r14d
 117ca69:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 117ca6d:	75 1a                	jne    117ca89 <br.encodeCommandPlanWithOptionsWrite+0x36e9>
 117ca6f:	41 be 04 00 00 00    	mov    $0x4,%r14d
 117ca75:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 117ca79:	75 0e                	jne    117ca89 <br.encodeCommandPlanWithOptionsWrite+0x36e9>
 117ca7b:	80 7d cb 01          	cmpb   $0x1,-0x35(%rbp)
 117ca7f:	41 be 03 00 00 00    	mov    $0x3,%r14d
 117ca85:	49 83 de 00          	sbb    $0x0,%r14
 117ca89:	80 7d cc 00          	cmpb   $0x0,-0x34(%rbp)
 117ca8d:	0f 84 ea 01 00 00    	je     117cc7d <br.encodeCommandPlanWithOptionsWrite+0x38dd>
 117ca93:	48 8b 85 c8 fe ff ff 	mov    -0x138(%rbp),%rax
 117ca9a:	48 89 85 70 fa ff ff 	mov    %rax,-0x590(%rbp)
 117caa1:	48 8b 85 58 fe ff ff 	mov    -0x1a8(%rbp),%rax
 117caa8:	48 89 85 78 fa ff ff 	mov    %rax,-0x588(%rbp)
 117caaf:	0f b6 45 d5          	movzbl -0x2b(%rbp),%eax
 117cab3:	88 85 80 fa ff ff    	mov    %al,-0x580(%rbp)
 117cab9:	8b 85 a0 fe ff ff    	mov    -0x160(%rbp),%eax
 117cabf:	8b 8d a3 fe ff ff    	mov    -0x15d(%rbp),%ecx
 117cac5:	89 85 81 fa ff ff    	mov    %eax,-0x57f(%rbp)
 117cacb:	89 8d 84 fa ff ff    	mov    %ecx,-0x57c(%rbp)
 117cad1:	48 8b 85 60 fe ff ff 	mov    -0x1a0(%rbp),%rax
 117cad8:	48 89 85 88 fa ff ff 	mov    %rax,-0x578(%rbp)
 117cadf:	0f b6 45 d4          	movzbl -0x2c(%rbp),%eax
 117cae3:	88 85 90 fa ff ff    	mov    %al,-0x570(%rbp)
 117cae9:	8b 85 a8 fe ff ff    	mov    -0x158(%rbp),%eax
 117caef:	8b 8d ab fe ff ff    	mov    -0x155(%rbp),%ecx
 117caf5:	89 85 91 fa ff ff    	mov    %eax,-0x56f(%rbp)
 117cafb:	89 8d 94 fa ff ff    	mov    %ecx,-0x56c(%rbp)
 117cb01:	48 8b 85 68 fe ff ff 	mov    -0x198(%rbp),%rax
 117cb08:	48 89 85 98 fa ff ff 	mov    %rax,-0x568(%rbp)
 117cb0f:	0f b6 45 d7          	movzbl -0x29(%rbp),%eax
 117cb13:	88 85 a0 fa ff ff    	mov    %al,-0x560(%rbp)
 117cb19:	8b 85 b0 fe ff ff    	mov    -0x150(%rbp),%eax
 117cb1f:	8b 8d b3 fe ff ff    	mov    -0x14d(%rbp),%ecx
 117cb25:	89 85 a1 fa ff ff    	mov    %eax,-0x55f(%rbp)
 117cb2b:	89 8d a4 fa ff ff    	mov    %ecx,-0x55c(%rbp)
 117cb31:	48 8b 85 70 fe ff ff 	mov    -0x190(%rbp),%rax
 117cb38:	48 89 85 a8 fa ff ff 	mov    %rax,-0x558(%rbp)
 117cb3f:	0f b6 45 ce          	movzbl -0x32(%rbp),%eax
 117cb43:	88 85 b0 fa ff ff    	mov    %al,-0x550(%rbp)
 117cb49:	8b 85 b8 fe ff ff    	mov    -0x148(%rbp),%eax
 117cb4f:	8b 8d bb fe ff ff    	mov    -0x145(%rbp),%ecx
 117cb55:	89 85 b1 fa ff ff    	mov    %eax,-0x54f(%rbp)
 117cb5b:	89 8d b4 fa ff ff    	mov    %ecx,-0x54c(%rbp)
 117cb61:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 117cb68:	48 89 85 b8 fa ff ff 	mov    %rax,-0x548(%rbp)
 117cb6f:	0f b6 45 c4          	movzbl -0x3c(%rbp),%eax
 117cb73:	88 85 c0 fa ff ff    	mov    %al,-0x540(%rbp)
 117cb79:	8b 85 c0 fe ff ff    	mov    -0x140(%rbp),%eax
 117cb7f:	8b 8d c3 fe ff ff    	mov    -0x13d(%rbp),%ecx
 117cb85:	89 85 c1 fa ff ff    	mov    %eax,-0x53f(%rbp)
 117cb8b:	89 8d c4 fa ff ff    	mov    %ecx,-0x53c(%rbp)
 117cb91:	48 8b 85 20 fd ff ff 	mov    -0x2e0(%rbp),%rax
 117cb98:	48 89 85 c8 fa ff ff 	mov    %rax,-0x538(%rbp)
 117cb9f:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 117cba3:	88 85 d0 fa ff ff    	mov    %al,-0x530(%rbp)
 117cba9:	0f b6 45 c8          	movzbl -0x38(%rbp),%eax
 117cbad:	88 85 d1 fa ff ff    	mov    %al,-0x52f(%rbp)
 117cbb3:	0f b7 85 e8 fe ff ff 	movzwl -0x118(%rbp),%eax
 117cbba:	66 89 85 d6 fa ff ff 	mov    %ax,-0x52a(%rbp)
 117cbc1:	8b 85 e4 fe ff ff    	mov    -0x11c(%rbp),%eax
 117cbc7:	89 85 d2 fa ff ff    	mov    %eax,-0x52e(%rbp)
 117cbcd:	48 8d bd 00 e7 ff ff 	lea    -0x1900(%rbp),%rdi
 117cbd4:	48 8d b5 70 fa ff ff 	lea    -0x590(%rbp),%rsi
 117cbdb:	48 8b 95 38 fd ff ff 	mov    -0x2c8(%rbp),%rdx
 117cbe2:	c5 f8 77             	vzeroupper 
 117cbe5:	e8 96 20 03 00       	call   11aec80 <br.DistanceBlockLengthCode.init>
 117cbea:	0f b7 85 c8 e7 ff ff 	movzwl -0x1838(%rbp),%eax
 117cbf1:	66 85 c0             	test   %ax,%ax
 117cbf4:	0f 85 13 c8 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117cbfa:	48 8b 85 c0 e7 ff ff 	mov    -0x1840(%rbp),%rax
 117cc01:	48 89 85 20 ed ff ff 	mov    %rax,-0x12e0(%rbp)
 117cc08:	c5 fc 10 85 a0 e7 ff 	vmovups -0x1860(%rbp),%ymm0
 117cc0f:	ff 
 117cc10:	c5 fc 11 85 00 ed ff 	vmovups %ymm0,-0x1300(%rbp)
 117cc17:	ff 
 117cc18:	c5 fc 10 85 80 e7 ff 	vmovups -0x1880(%rbp),%ymm0
 117cc1f:	ff 
 117cc20:	c5 fc 11 85 e0 ec ff 	vmovups %ymm0,-0x1320(%rbp)
 117cc27:	ff 
 117cc28:	c5 fc 10 85 20 e7 ff 	vmovups -0x18e0(%rbp),%ymm0
 117cc2f:	ff 
 117cc30:	c5 fc 10 8d 40 e7 ff 	vmovups -0x18c0(%rbp),%ymm1
 117cc37:	ff 
 117cc38:	c5 fc 10 95 60 e7 ff 	vmovups -0x18a0(%rbp),%ymm2
 117cc3f:	ff 
 117cc40:	c5 fc 11 95 c0 ec ff 	vmovups %ymm2,-0x1340(%rbp)
 117cc47:	ff 
 117cc48:	c5 fc 11 8d a0 ec ff 	vmovups %ymm1,-0x1360(%rbp)
 117cc4f:	ff 
 117cc50:	c5 fc 11 85 80 ec ff 	vmovups %ymm0,-0x1380(%rbp)
 117cc57:	ff 
 117cc58:	c5 fc 10 85 00 e7 ff 	vmovups -0x1900(%rbp),%ymm0
 117cc5f:	ff 
 117cc60:	c5 fc 11 85 60 ec ff 	vmovups %ymm0,-0x13a0(%rbp)
 117cc67:	ff 
 117cc68:	c6 45 a8 00          	movb   $0x0,-0x58(%rbp)
 117cc6c:	b0 01                	mov    $0x1,%al
 117cc6e:	80 7d c4 00          	cmpb   $0x0,-0x3c(%rbp)
 117cc72:	74 11                	je     117cc85 <br.encodeCommandPlanWithOptionsWrite+0x38e5>
 117cc74:	48 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%rcx
 117cc7b:	eb 4f                	jmp    117cccc <br.encodeCommandPlanWithOptionsWrite+0x392c>
 117cc7d:	c6 45 a8 00          	movb   $0x0,-0x58(%rbp)
 117cc81:	31 c0                	xor    %eax,%eax
 117cc83:	eb 47                	jmp    117cccc <br.encodeCommandPlanWithOptionsWrite+0x392c>
 117cc85:	0f b6 4d d3          	movzbl -0x2d(%rbp),%ecx
 117cc89:	0a 4d c8             	or     -0x38(%rbp),%cl
 117cc8c:	f6 c1 01             	test   $0x1,%cl
 117cc8f:	74 0d                	je     117cc9e <br.encodeCommandPlanWithOptionsWrite+0x38fe>
 117cc91:	0f b6 4d d3          	movzbl -0x2d(%rbp),%ecx
 117cc95:	83 e1 01             	and    $0x1,%ecx
 117cc98:	48 83 f1 03          	xor    $0x3,%rcx
 117cc9c:	eb 2e                	jmp    117cccc <br.encodeCommandPlanWithOptionsWrite+0x392c>
 117cc9e:	b9 06 00 00 00       	mov    $0x6,%ecx
 117cca3:	80 7d ce 00          	cmpb   $0x0,-0x32(%rbp)
 117cca7:	75 23                	jne    117cccc <br.encodeCommandPlanWithOptionsWrite+0x392c>
 117cca9:	b9 05 00 00 00       	mov    $0x5,%ecx
 117ccae:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 117ccb2:	75 18                	jne    117cccc <br.encodeCommandPlanWithOptionsWrite+0x392c>
 117ccb4:	b9 04 00 00 00       	mov    $0x4,%ecx
 117ccb9:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 117ccbd:	75 0d                	jne    117cccc <br.encodeCommandPlanWithOptionsWrite+0x392c>
 117ccbf:	80 7d d5 01          	cmpb   $0x1,-0x2b(%rbp)
 117ccc3:	b9 03 00 00 00       	mov    $0x3,%ecx
 117ccc8:	48 83 d9 00          	sbb    $0x0,%rcx
 117cccc:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 117ccd0:	0f 84 80 01 00 00    	je     117ce56 <br.encodeCommandPlanWithOptionsWrite+0x3ab6>
 117ccd6:	4c 89 b5 88 f9 ff ff 	mov    %r14,-0x678(%rbp)
 117ccdd:	48 8d 95 e8 fc fe ff 	lea    -0x10318(%rbp),%rdx
 117cce4:	48 89 95 90 f9 ff ff 	mov    %rdx,-0x670(%rbp)
 117cceb:	48 8d 95 18 1e ff ff 	lea    -0xe1e8(%rbp),%rdx
 117ccf2:	48 89 95 98 f9 ff ff 	mov    %rdx,-0x668(%rbp)
 117ccf9:	48 8d 95 30 ed ff ff 	lea    -0x12d0(%rbp),%rdx
 117cd00:	48 89 95 a0 f9 ff ff 	mov    %rdx,-0x660(%rbp)
 117cd07:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 117cd0b:	c5 f8 11 85 a8 f9 ff 	vmovups %xmm0,-0x658(%rbp)
 117cd12:	ff 
 117cd13:	8b 95 44 ff ff ff    	mov    -0xbc(%rbp),%edx
 117cd19:	66 89 95 b0 fd ff ff 	mov    %dx,-0x250(%rbp)
 117cd20:	0f b6 55 b0          	movzbl -0x50(%rbp),%edx
 117cd24:	88 95 b8 f9 ff ff    	mov    %dl,-0x648(%rbp)
 117cd2a:	c7 85 b9 f9 ff ff 00 	movl   $0x0,-0x647(%rbp)
 117cd31:	00 00 00 
 117cd34:	c7 85 bc f9 ff ff 00 	movl   $0x0,-0x644(%rbp)
 117cd3b:	00 00 00 
 117cd3e:	88 9d c0 f9 ff ff    	mov    %bl,-0x640(%rbp)
 117cd44:	c7 85 c1 f9 ff ff 00 	movl   $0x0,-0x63f(%rbp)
 117cd4b:	00 00 00 
 117cd4e:	c7 85 c4 f9 ff ff 00 	movl   $0x0,-0x63c(%rbp)
 117cd55:	00 00 00 
 117cd58:	48 89 8d b0 f8 ff ff 	mov    %rcx,-0x750(%rbp)
 117cd5f:	48 8d 8d 38 cb ff ff 	lea    -0x34c8(%rbp),%rcx
 117cd66:	48 89 8d b8 f8 ff ff 	mov    %rcx,-0x748(%rbp)
 117cd6d:	48 8d 8d ea d1 ff ff 	lea    -0x2e16(%rbp),%rcx
 117cd74:	48 89 8d c0 f8 ff ff 	mov    %rcx,-0x740(%rbp)
 117cd7b:	48 8d 8d 60 ec ff ff 	lea    -0x13a0(%rbp),%rcx
 117cd82:	48 89 8d c8 f8 ff ff 	mov    %rcx,-0x738(%rbp)
 117cd89:	c5 f8 11 85 d0 f8 ff 	vmovups %xmm0,-0x730(%rbp)
 117cd90:	ff 
 117cd91:	48 c7 85 e0 f8 ff ff 	movq   $0x0,-0x720(%rbp)
 117cd98:	00 00 00 00 
 117cd9c:	0f b6 4d a8          	movzbl -0x58(%rbp),%ecx
 117cda0:	88 8d e8 f8 ff ff    	mov    %cl,-0x718(%rbp)
 117cda6:	c7 85 e9 f8 ff ff 00 	movl   $0x0,-0x717(%rbp)
 117cdad:	00 00 00 
 117cdb0:	c7 85 ec f8 ff ff 00 	movl   $0x0,-0x714(%rbp)
 117cdb7:	00 00 00 
 117cdba:	88 85 f0 f8 ff ff    	mov    %al,-0x710(%rbp)
 117cdc0:	c7 85 f1 f8 ff ff 00 	movl   $0x0,-0x70f(%rbp)
 117cdc7:	00 00 00 
 117cdca:	c7 85 f4 f8 ff ff 00 	movl   $0x0,-0x70c(%rbp)
 117cdd1:	00 00 00 
 117cdd4:	48 83 ec 08          	sub    $0x8,%rsp
 117cdd8:	48 8d 85 20 f2 ff ff 	lea    -0xde0(%rbp),%rax
 117cddf:	4c 8d 95 2a cf ff ff 	lea    -0x30d6(%rbp),%r10
 117cde6:	4c 8d 9d b0 f8 ff ff 	lea    -0x750(%rbp),%r11
 117cded:	48 8d 9d d0 f0 ff ff 	lea    -0xf30(%rbp),%rbx
 117cdf4:	4c 8d b5 88 f9 ff ff 	lea    -0x678(%rbp),%r14
 117cdfb:	48 8d 95 68 8c ff ff 	lea    -0x7398(%rbp),%rdx
 117ce02:	48 8d 8d cc ab ff ff 	lea    -0x5434(%rbp),%rcx
 117ce09:	4c 8d 85 a0 e8 ff ff 	lea    -0x1760(%rbp),%r8
 117ce10:	4c 8d 8d b0 fd ff ff 	lea    -0x250(%rbp),%r9
 117ce17:	48 8b 7d a0          	mov    -0x60(%rbp),%rdi
 117ce1b:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 117ce1f:	50                   	push   %rax
 117ce20:	41 52                	push   %r10
 117ce22:	ff b5 f0 fd ff ff    	push   -0x210(%rbp)
 117ce28:	41 53                	push   %r11
 117ce2a:	53                   	push   %rbx
 117ce2b:	41 56                	push   %r14
 117ce2d:	48 8d 85 b0 c5 ff ff 	lea    -0x3a50(%rbp),%rax
 117ce34:	50                   	push   %rax
 117ce35:	c5 f8 77             	vzeroupper 
 117ce38:	e8 83 10 03 00       	call   11adec0 <br.writePlannedCompressedHeaderLiteralBlocks__anon_36456>
 117ce3d:	48 83 c4 40          	add    $0x40,%rsp
 117ce41:	66 85 c0             	test   %ax,%ax
 117ce44:	0f 85 c3 c5 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117ce4a:	48 8d 1d 4f c2 e9 ff 	lea    -0x163db1(%rip),%rbx        # 10190a0 <__anon_36476>
 117ce51:	e9 5c 03 00 00       	jmp    117d1b2 <br.encodeCommandPlanWithOptionsWrite+0x3e12>
 117ce56:	48 8b 55 80          	mov    -0x80(%rbp),%rdx
 117ce5a:	80 7a 50 00          	cmpb   $0x0,0x50(%rdx)
 117ce5e:	0f 84 97 01 00 00    	je     117cffb <br.encodeCommandPlanWithOptionsWrite+0x3c5b>
 117ce64:	48 8b 55 80          	mov    -0x80(%rbp),%rdx
 117ce68:	c5 fc 10 02          	vmovups (%rdx),%ymm0
 117ce6c:	c5 fc 10 4a 20       	vmovups 0x20(%rdx),%ymm1
 117ce71:	c5 fc 10 52 30       	vmovups 0x30(%rdx),%ymm2
 117ce76:	c5 fc 11 95 c0 e9 ff 	vmovups %ymm2,-0x1640(%rbp)
 117ce7d:	ff 
 117ce7e:	c5 fc 11 8d b0 e9 ff 	vmovups %ymm1,-0x1650(%rbp)
 117ce85:	ff 
 117ce86:	c5 fc 11 85 90 e9 ff 	vmovups %ymm0,-0x1670(%rbp)
 117ce8d:	ff 
 117ce8e:	8b 95 44 ff ff ff    	mov    -0xbc(%rbp),%edx
 117ce94:	66 89 95 ae fd ff ff 	mov    %dx,-0x252(%rbp)
 117ce9b:	4c 89 b5 48 f9 ff ff 	mov    %r14,-0x6b8(%rbp)
 117cea2:	48 8d 95 e8 fc fe ff 	lea    -0x10318(%rbp),%rdx
 117cea9:	48 89 95 50 f9 ff ff 	mov    %rdx,-0x6b0(%rbp)
 117ceb0:	48 8d 95 18 1e ff ff 	lea    -0xe1e8(%rbp),%rdx
 117ceb7:	48 89 95 58 f9 ff ff 	mov    %rdx,-0x6a8(%rbp)
 117cebe:	48 8d 95 30 ed ff ff 	lea    -0x12d0(%rbp),%rdx
 117cec5:	48 89 95 60 f9 ff ff 	mov    %rdx,-0x6a0(%rbp)
 117cecc:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 117ced0:	c5 f8 11 85 68 f9 ff 	vmovups %xmm0,-0x698(%rbp)
 117ced7:	ff 
 117ced8:	0f b6 55 b0          	movzbl -0x50(%rbp),%edx
 117cedc:	88 95 78 f9 ff ff    	mov    %dl,-0x688(%rbp)
 117cee2:	c7 85 79 f9 ff ff 00 	movl   $0x0,-0x687(%rbp)
 117cee9:	00 00 00 
 117ceec:	c7 85 7c f9 ff ff 00 	movl   $0x0,-0x684(%rbp)
 117cef3:	00 00 00 
 117cef6:	88 9d 80 f9 ff ff    	mov    %bl,-0x680(%rbp)
 117cefc:	c7 85 81 f9 ff ff 00 	movl   $0x0,-0x67f(%rbp)
 117cf03:	00 00 00 
 117cf06:	c7 85 84 f9 ff ff 00 	movl   $0x0,-0x67c(%rbp)
 117cf0d:	00 00 00 
 117cf10:	48 89 8d 68 f8 ff ff 	mov    %rcx,-0x798(%rbp)
 117cf17:	48 8d 8d 38 cb ff ff 	lea    -0x34c8(%rbp),%rcx
 117cf1e:	48 89 8d 70 f8 ff ff 	mov    %rcx,-0x790(%rbp)
 117cf25:	48 8d 8d ea d1 ff ff 	lea    -0x2e16(%rbp),%rcx
 117cf2c:	48 89 8d 78 f8 ff ff 	mov    %rcx,-0x788(%rbp)
 117cf33:	48 8d 8d 60 ec ff ff 	lea    -0x13a0(%rbp),%rcx
 117cf3a:	48 89 8d 80 f8 ff ff 	mov    %rcx,-0x780(%rbp)
 117cf41:	c5 f8 11 85 88 f8 ff 	vmovups %xmm0,-0x778(%rbp)
 117cf48:	ff 
 117cf49:	48 c7 85 98 f8 ff ff 	movq   $0x0,-0x768(%rbp)
 117cf50:	00 00 00 00 
 117cf54:	0f b6 4d a8          	movzbl -0x58(%rbp),%ecx
 117cf58:	88 8d a0 f8 ff ff    	mov    %cl,-0x760(%rbp)
 117cf5e:	c7 85 a1 f8 ff ff 00 	movl   $0x0,-0x75f(%rbp)
 117cf65:	00 00 00 
 117cf68:	c7 85 a4 f8 ff ff 00 	movl   $0x0,-0x75c(%rbp)
 117cf6f:	00 00 00 
 117cf72:	88 85 a8 f8 ff ff    	mov    %al,-0x758(%rbp)
 117cf78:	c7 85 a9 f8 ff ff 00 	movl   $0x0,-0x757(%rbp)
 117cf7f:	00 00 00 
 117cf82:	c7 85 ac f8 ff ff 00 	movl   $0x0,-0x754(%rbp)
 117cf89:	00 00 00 
 117cf8c:	48 83 ec 08          	sub    $0x8,%rsp
 117cf90:	48 8d 85 20 f2 ff ff 	lea    -0xde0(%rbp),%rax
 117cf97:	4c 8d 95 2a cf ff ff 	lea    -0x30d6(%rbp),%r10
 117cf9e:	4c 8d 9d 68 f8 ff ff 	lea    -0x798(%rbp),%r11
 117cfa5:	48 8d 9d d0 f0 ff ff 	lea    -0xf30(%rbp),%rbx
 117cfac:	4c 8d b5 48 f9 ff ff 	lea    -0x6b8(%rbp),%r14
 117cfb3:	4c 8d bd b0 c5 ff ff 	lea    -0x3a50(%rbp),%r15
 117cfba:	48 8d 95 50 1d fd ff 	lea    -0x2e2b0(%rbp),%rdx
 117cfc1:	48 8d 8d d4 c1 fd ff 	lea    -0x23e2c(%rbp),%rcx
 117cfc8:	4c 8d 85 90 e9 ff ff 	lea    -0x1670(%rbp),%r8
 117cfcf:	4c 8d 8d ae fd ff ff 	lea    -0x252(%rbp),%r9
 117cfd6:	48 8b 7d a0          	mov    -0x60(%rbp),%rdi
 117cfda:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 117cfde:	50                   	push   %rax
 117cfdf:	41 52                	push   %r10
 117cfe1:	ff b5 f0 fd ff ff    	push   -0x210(%rbp)
 117cfe7:	41 53                	push   %r11
 117cfe9:	53                   	push   %rbx
 117cfea:	41 56                	push   %r14
 117cfec:	41 57                	push   %r15
 117cfee:	c5 f8 77             	vzeroupper 
 117cff1:	e8 9a 67 00 00       	call   1183790 <br.writePlannedCompressedHeaderLiteralContexts__anon_36463>
 117cff6:	e9 65 01 00 00       	jmp    117d160 <br.encodeCommandPlanWithOptionsWrite+0x3dc0>
 117cffb:	4c 89 b5 08 f9 ff ff 	mov    %r14,-0x6f8(%rbp)
 117d002:	48 8d 95 e8 fc fe ff 	lea    -0x10318(%rbp),%rdx
 117d009:	48 89 95 10 f9 ff ff 	mov    %rdx,-0x6f0(%rbp)
 117d010:	48 8d 95 18 1e ff ff 	lea    -0xe1e8(%rbp),%rdx
 117d017:	48 89 95 18 f9 ff ff 	mov    %rdx,-0x6e8(%rbp)
 117d01e:	48 8d 95 30 ed ff ff 	lea    -0x12d0(%rbp),%rdx
 117d025:	48 89 95 20 f9 ff ff 	mov    %rdx,-0x6e0(%rbp)
 117d02c:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 117d030:	c5 f8 11 85 28 f9 ff 	vmovups %xmm0,-0x6d8(%rbp)
 117d037:	ff 
 117d038:	0f b6 55 b0          	movzbl -0x50(%rbp),%edx
 117d03c:	88 95 38 f9 ff ff    	mov    %dl,-0x6c8(%rbp)
 117d042:	c7 85 39 f9 ff ff 00 	movl   $0x0,-0x6c7(%rbp)
 117d049:	00 00 00 
 117d04c:	c7 85 3c f9 ff ff 00 	movl   $0x0,-0x6c4(%rbp)
 117d053:	00 00 00 
 117d056:	88 9d 40 f9 ff ff    	mov    %bl,-0x6c0(%rbp)
 117d05c:	c7 85 41 f9 ff ff 00 	movl   $0x0,-0x6bf(%rbp)
 117d063:	00 00 00 
 117d066:	c7 85 44 f9 ff ff 00 	movl   $0x0,-0x6bc(%rbp)
 117d06d:	00 00 00 
 117d070:	48 89 8d 20 f8 ff ff 	mov    %rcx,-0x7e0(%rbp)
 117d077:	48 8d 8d 38 cb ff ff 	lea    -0x34c8(%rbp),%rcx
 117d07e:	48 89 8d 28 f8 ff ff 	mov    %rcx,-0x7d8(%rbp)
 117d085:	48 8d 8d ea d1 ff ff 	lea    -0x2e16(%rbp),%rcx
 117d08c:	48 89 8d 30 f8 ff ff 	mov    %rcx,-0x7d0(%rbp)
 117d093:	48 8d 8d 60 ec ff ff 	lea    -0x13a0(%rbp),%rcx
 117d09a:	48 89 8d 38 f8 ff ff 	mov    %rcx,-0x7c8(%rbp)
 117d0a1:	c5 f8 11 85 40 f8 ff 	vmovups %xmm0,-0x7c0(%rbp)
 117d0a8:	ff 
 117d0a9:	48 c7 85 50 f8 ff ff 	movq   $0x0,-0x7b0(%rbp)
 117d0b0:	00 00 00 00 
 117d0b4:	0f b6 4d a8          	movzbl -0x58(%rbp),%ecx
 117d0b8:	88 8d 58 f8 ff ff    	mov    %cl,-0x7a8(%rbp)
 117d0be:	c7 85 59 f8 ff ff 00 	movl   $0x0,-0x7a7(%rbp)
 117d0c5:	00 00 00 
 117d0c8:	c7 85 5c f8 ff ff 00 	movl   $0x0,-0x7a4(%rbp)
 117d0cf:	00 00 00 
 117d0d2:	88 85 60 f8 ff ff    	mov    %al,-0x7a0(%rbp)
 117d0d8:	c7 85 61 f8 ff ff 00 	movl   $0x0,-0x79f(%rbp)
 117d0df:	00 00 00 
 117d0e2:	c7 85 64 f8 ff ff 00 	movl   $0x0,-0x79c(%rbp)
 117d0e9:	00 00 00 
 117d0ec:	8b 85 44 ff ff ff    	mov    -0xbc(%rbp),%eax
 117d0f2:	66 89 85 ac fd ff ff 	mov    %ax,-0x254(%rbp)
 117d0f9:	48 83 ec 08          	sub    $0x8,%rsp
 117d0fd:	48 8d 85 20 f2 ff ff 	lea    -0xde0(%rbp),%rax
 117d104:	4c 8d 95 2a cf ff ff 	lea    -0x30d6(%rbp),%r10
 117d10b:	4c 8d 9d 00 e6 ff ff 	lea    -0x1a00(%rbp),%r11
 117d112:	48 8d 9d ac fd ff ff 	lea    -0x254(%rbp),%rbx
 117d119:	4c 8d b5 20 f8 ff ff 	lea    -0x7e0(%rbp),%r14
 117d120:	4c 8d bd d0 f0 ff ff 	lea    -0xf30(%rbp),%r15
 117d127:	0f b6 55 9e          	movzbl -0x62(%rbp),%edx
 117d12b:	48 8d 8d c8 d5 ff ff 	lea    -0x2a38(%rbp),%rcx
 117d132:	4c 8d 85 b0 c5 ff ff 	lea    -0x3a50(%rbp),%r8
 117d139:	4c 8d 8d 08 f9 ff ff 	lea    -0x6f8(%rbp),%r9
 117d140:	48 8b 7d a0          	mov    -0x60(%rbp),%rdi
 117d144:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 117d148:	50                   	push   %rax
 117d149:	41 52                	push   %r10
 117d14b:	41 53                	push   %r11
 117d14d:	ff b5 f0 fd ff ff    	push   -0x210(%rbp)
 117d153:	53                   	push   %rbx
 117d154:	41 56                	push   %r14
 117d156:	41 57                	push   %r15
 117d158:	c5 f8 77             	vzeroupper 
 117d15b:	e8 e0 62 00 00       	call   1183440 <br.writePlannedCompressedHeader__anon_36469>
 117d160:	48 83 c4 40          	add    $0x40,%rsp
 117d164:	66 85 c0             	test   %ax,%ax
 117d167:	0f 85 a0 c2 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117d16d:	48 8d bd ca a8 ff ff 	lea    -0x5736(%rbp),%rdi
 117d174:	48 8d b5 00 e6 ff ff 	lea    -0x1a00(%rbp),%rsi
 117d17b:	48 8d 95 c8 d5 ff ff 	lea    -0x2a38(%rbp),%rdx
 117d182:	e8 39 5b 00 00       	call   1182cc0 <br.initPlannedLiteralEncoder>
 117d187:	0f b7 85 ca ab ff ff 	movzwl -0x5436(%rbp),%eax
 117d18e:	66 85 c0             	test   %ax,%ax
 117d191:	0f 85 76 c2 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117d197:	48 8d 9d 98 34 ff ff 	lea    -0xcb68(%rbp),%rbx
 117d19e:	48 8d b5 ca a8 ff ff 	lea    -0x5736(%rbp),%rsi
 117d1a5:	ba 00 03 00 00       	mov    $0x300,%edx
 117d1aa:	48 89 df             	mov    %rbx,%rdi
 117d1ad:	e8 0e 8f 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117d1b2:	48 8d bd cc b1 ff ff 	lea    -0x4e34(%rbp),%rdi
 117d1b9:	ba 00 03 00 00       	mov    $0x300,%edx
 117d1be:	48 89 de             	mov    %rbx,%rsi
 117d1c1:	e8 fa 8e 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117d1c6:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 117d1ca:	80 78 50 00          	cmpb   $0x0,0x50(%rax)
 117d1ce:	0f 84 9d 00 00 00    	je     117d271 <br.encodeCommandPlanWithOptionsWrite+0x3ed1>
 117d1d4:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 117d1d8:	0f b6 40 09          	movzbl 0x9(%rax),%eax
 117d1dc:	48 83 e0 7f          	and    $0x7f,%rax
 117d1e0:	48 8d b5 d4 c1 fd ff 	lea    -0x23e2c(%rbp),%rsi
 117d1e7:	74 6b                	je     117d254 <br.encodeCommandPlanWithOptionsWrite+0x3eb4>
 117d1e9:	c1 e0 08             	shl    $0x8,%eax
 117d1ec:	4c 8d 3c 40          	lea    (%rax,%rax,2),%r15
 117d1f0:	48 8d 9d 50 1d fd ff 	lea    -0x2e2b0(%rbp),%rbx
 117d1f7:	45 31 e4             	xor    %r12d,%r12d
 117d1fa:	4c 8d b5 9e 9b ff ff 	lea    -0x6462(%rbp),%r14
 117d201:	4c 89 f7             	mov    %r14,%rdi
 117d204:	49 89 f5             	mov    %rsi,%r13
 117d207:	48 89 da             	mov    %rbx,%rdx
 117d20a:	e8 b1 5a 00 00       	call   1182cc0 <br.initPlannedLiteralEncoder>
 117d20f:	0f b7 85 9e 9e ff ff 	movzwl -0x6162(%rbp),%eax
 117d216:	66 85 c0             	test   %ax,%ax
 117d219:	0f 85 ee c1 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117d21f:	49 8d 3c 2c          	lea    (%r12,%rbp,1),%rdi
 117d223:	48 81 c7 d0 88 fa ff 	add    $0xfffffffffffa88d0,%rdi
 117d22a:	ba 00 03 00 00       	mov    $0x300,%edx
 117d22f:	4c 89 f6             	mov    %r14,%rsi
 117d232:	e8 89 8e 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117d237:	49 81 c4 00 03 00 00 	add    $0x300,%r12
 117d23e:	48 81 c3 08 02 00 00 	add    $0x208,%rbx
 117d245:	4c 89 ee             	mov    %r13,%rsi
 117d248:	48 81 c6 00 01 00 00 	add    $0x100,%rsi
 117d24f:	4d 39 e7             	cmp    %r12,%r15
 117d252:	75 ad                	jne    117d201 <br.encodeCommandPlanWithOptionsWrite+0x3e61>
 117d254:	48 8d 9d d0 08 f9 ff 	lea    -0x6f730(%rbp),%rbx
 117d25b:	48 8d b5 d0 88 fa ff 	lea    -0x57730(%rbp),%rsi
 117d262:	ba 00 c0 00 00       	mov    $0xc000,%edx
 117d267:	48 89 df             	mov    %rbx,%rdi
 117d26a:	e8 51 8e 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117d26f:	eb 07                	jmp    117d278 <br.encodeCommandPlanWithOptionsWrite+0x3ed8>
 117d271:	48 8d 1d 28 c1 e9 ff 	lea    -0x163ed8(%rip),%rbx        # 10193a0 <__anon_36481>
 117d278:	48 8d bd d0 c8 f9 ff 	lea    -0x63730(%rbp),%rdi
 117d27f:	ba 00 c0 00 00       	mov    $0xc000,%edx
 117d284:	48 89 de             	mov    %rbx,%rsi
 117d287:	e8 34 8e 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117d28c:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 117d290:	74 21                	je     117d2b3 <br.encodeCommandPlanWithOptionsWrite+0x3f13>
 117d292:	80 7d c0 00          	cmpb   $0x0,-0x40(%rbp)
 117d296:	74 27                	je     117d2bf <br.encodeCommandPlanWithOptionsWrite+0x3f1f>
 117d298:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 117d29f:	49 89 c4             	mov    %rax,%r12
 117d2a2:	48 85 c0             	test   %rax,%rax
 117d2a5:	48 8d b5 cc ab ff ff 	lea    -0x5434(%rbp),%rsi
 117d2ac:	75 6b                	jne    117d319 <br.encodeCommandPlanWithOptionsWrite+0x3f79>
 117d2ae:	e9 c6 00 00 00       	jmp    117d379 <br.encodeCommandPlanWithOptionsWrite+0x3fd9>
 117d2b3:	48 8d 1d e6 80 ea ff 	lea    -0x157f1a(%rip),%rbx        # 10253a0 <__anon_36489>
 117d2ba:	e9 d5 00 00 00       	jmp    117d394 <br.encodeCommandPlanWithOptionsWrite+0x3ff4>
 117d2bf:	0f b6 45 c9          	movzbl -0x37(%rbp),%eax
 117d2c3:	0a 45 c2             	or     -0x3e(%rbp),%al
 117d2c6:	a8 01                	test   $0x1,%al
 117d2c8:	74 16                	je     117d2e0 <br.encodeCommandPlanWithOptionsWrite+0x3f40>
 117d2ca:	44 0f b6 65 c9       	movzbl -0x37(%rbp),%r12d
 117d2cf:	41 83 e4 01          	and    $0x1,%r12d
 117d2d3:	49 83 f4 03          	xor    $0x3,%r12
 117d2d7:	48 8d b5 cc ab ff ff 	lea    -0x5434(%rbp),%rsi
 117d2de:	eb 39                	jmp    117d319 <br.encodeCommandPlanWithOptionsWrite+0x3f79>
 117d2e0:	41 bc 06 00 00 00    	mov    $0x6,%r12d
 117d2e6:	80 7d ca 00          	cmpb   $0x0,-0x36(%rbp)
 117d2ea:	48 8d b5 cc ab ff ff 	lea    -0x5434(%rbp),%rsi
 117d2f1:	75 26                	jne    117d319 <br.encodeCommandPlanWithOptionsWrite+0x3f79>
 117d2f3:	41 bc 05 00 00 00    	mov    $0x5,%r12d
 117d2f9:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 117d2fd:	75 1a                	jne    117d319 <br.encodeCommandPlanWithOptionsWrite+0x3f79>
 117d2ff:	41 bc 04 00 00 00    	mov    $0x4,%r12d
 117d305:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 117d309:	75 0e                	jne    117d319 <br.encodeCommandPlanWithOptionsWrite+0x3f79>
 117d30b:	80 7d c5 01          	cmpb   $0x1,-0x3b(%rbp)
 117d30f:	41 bc 03 00 00 00    	mov    $0x3,%r12d
 117d315:	49 83 dc 00          	sbb    $0x0,%r12
 117d319:	48 8d 9d 68 8c ff ff 	lea    -0x7398(%rbp),%rbx
 117d320:	4c 8d b5 d4 55 fe ff 	lea    -0x1aa2c(%rbp),%r14
 117d327:	4c 8d bd 9c 98 ff ff 	lea    -0x6764(%rbp),%r15
 117d32e:	4c 89 ff             	mov    %r15,%rdi
 117d331:	49 89 f5             	mov    %rsi,%r13
 117d334:	48 89 da             	mov    %rbx,%rdx
 117d337:	e8 84 59 00 00       	call   1182cc0 <br.initPlannedLiteralEncoder>
 117d33c:	0f b7 85 9c 9b ff ff 	movzwl -0x6464(%rbp),%eax
 117d343:	66 85 c0             	test   %ax,%ax
 117d346:	0f 85 c1 c0 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117d34c:	ba 00 03 00 00       	mov    $0x300,%edx
 117d351:	4c 89 f7             	mov    %r14,%rdi
 117d354:	4c 89 fe             	mov    %r15,%rsi
 117d357:	e8 64 8d 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117d35c:	48 81 c3 08 02 00 00 	add    $0x208,%rbx
 117d363:	4c 89 ee             	mov    %r13,%rsi
 117d366:	48 81 c6 00 01 00 00 	add    $0x100,%rsi
 117d36d:	49 81 c6 00 03 00 00 	add    $0x300,%r14
 117d374:	49 ff cc             	dec    %r12
 117d377:	75 b5                	jne    117d32e <br.encodeCommandPlanWithOptionsWrite+0x3f8e>
 117d379:	48 8d 9d 54 9f fd ff 	lea    -0x260ac(%rbp),%rbx
 117d380:	48 8d b5 d4 55 fe ff 	lea    -0x1aa2c(%rbp),%rsi
 117d387:	ba 00 12 00 00       	mov    $0x1200,%edx
 117d38c:	48 89 df             	mov    %rbx,%rdi
 117d38f:	e8 2c 8d 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117d394:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 117d398:	41 0f 95 c6          	setne  %r14b
 117d39c:	48 8d bd d4 43 fe ff 	lea    -0x1bc2c(%rbp),%rdi
 117d3a3:	ba 00 12 00 00       	mov    $0x1200,%edx
 117d3a8:	48 89 de             	mov    %rbx,%rsi
 117d3ab:	e8 10 8d 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117d3b0:	48 8b 8d b0 c5 ff ff 	mov    -0x3a50(%rbp),%rcx
 117d3b7:	48 83 f9 05          	cmp    $0x5,%rcx
 117d3bb:	0f 92 c0             	setb   %al
 117d3be:	44 08 f0             	or     %r14b,%al
 117d3c1:	74 5a                	je     117d41d <br.encodeCommandPlanWithOptionsWrite+0x407d>
 117d3c3:	48 8d bd 0a 75 ff ff 	lea    -0x8af6(%rbp),%rdi
 117d3ca:	ba 40 08 00 00       	mov    $0x840,%edx
 117d3cf:	31 f6                	xor    %esi,%esi
 117d3d1:	e8 ca 88 11 00       	call   1295ca0 <compiler_rt.memset>
 117d3d6:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 117d3da:	0f 84 cf 00 00 00    	je     117d4af <br.encodeCommandPlanWithOptionsWrite+0x410f>
 117d3e0:	80 7d c1 00          	cmpb   $0x0,-0x3f(%rbp)
 117d3e4:	0f 84 88 1e 00 00    	je     117f272 <br.encodeCommandPlanWithOptionsWrite+0x5ed2>
 117d3ea:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 117d3f1:	49 89 c4             	mov    %rax,%r12
 117d3f4:	48 85 c0             	test   %rax,%rax
 117d3f7:	0f 85 e2 1e 00 00    	jne    117f2df <br.encodeCommandPlanWithOptionsWrite+0x5f3f>
 117d3fd:	48 8d 9d d0 88 fb ff 	lea    -0x47730(%rbp),%rbx
 117d404:	48 8d b5 d0 eb fc ff 	lea    -0x31430(%rbp),%rsi
 117d40b:	ba 80 31 00 00       	mov    $0x3180,%edx
 117d410:	48 89 df             	mov    %rbx,%rdi
 117d413:	e8 a8 8c 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117d418:	e9 99 00 00 00       	jmp    117d4b6 <br.encodeCommandPlanWithOptionsWrite+0x4116>
 117d41d:	48 83 f9 40          	cmp    $0x40,%rcx
 117d421:	77 3a                	ja     117d45d <br.encodeCommandPlanWithOptionsWrite+0x40bd>
 117d423:	48 8d 95 b8 c5 ff ff 	lea    -0x3a48(%rbp),%rdx
 117d42a:	48 8d bd 88 64 ff ff 	lea    -0x9b78(%rbp),%rdi
 117d431:	48 8d b5 2a cf ff ff 	lea    -0x30d6(%rbp),%rsi
 117d438:	e8 23 54 00 00       	call   1182860 <huffman.HuffmanTable(704).Encoder.initSparseTrusted>
 117d43d:	0f b7 85 c8 6c ff ff 	movzwl -0x9338(%rbp),%eax
 117d444:	66 85 c0             	test   %ax,%ax
 117d447:	0f 85 c0 bf ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117d44d:	48 8d 9d 14 91 fe ff 	lea    -0x16eec(%rbp),%rbx
 117d454:	48 8d b5 88 64 ff ff 	lea    -0x9b78(%rbp),%rsi
 117d45b:	eb 31                	jmp    117d48e <br.encodeCommandPlanWithOptionsWrite+0x40ee>
 117d45d:	48 8d bd 46 5c ff ff 	lea    -0xa3ba(%rbp),%rdi
 117d464:	48 8d b5 2a cf ff ff 	lea    -0x30d6(%rbp),%rsi
 117d46b:	e8 c0 50 00 00       	call   1182530 <huffman.HuffmanTable(704).Encoder.init>
 117d470:	0f b7 85 86 64 ff ff 	movzwl -0x9b7a(%rbp),%eax
 117d477:	66 85 c0             	test   %ax,%ax
 117d47a:	0f 85 8d bf ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117d480:	48 8d 9d d4 88 fe ff 	lea    -0x1772c(%rbp),%rbx
 117d487:	48 8d b5 46 5c ff ff 	lea    -0xa3ba(%rbp),%rsi
 117d48e:	ba 40 08 00 00       	mov    $0x840,%edx
 117d493:	48 89 df             	mov    %rbx,%rdi
 117d496:	e8 25 8c 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117d49b:	48 8d bd 0a 75 ff ff 	lea    -0x8af6(%rbp),%rdi
 117d4a2:	ba 40 08 00 00       	mov    $0x840,%edx
 117d4a7:	48 89 de             	mov    %rbx,%rsi
 117d4aa:	e8 11 8c 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117d4af:	48 8d 1d 2a 99 ea ff 	lea    -0x1566d6(%rip),%rbx        # 1026de0 <__anon_36522>
 117d4b6:	80 7d cc 00          	cmpb   $0x0,-0x34(%rbp)
 117d4ba:	41 0f 95 c6          	setne  %r14b
 117d4be:	48 8d bd 50 ba fc ff 	lea    -0x345b0(%rbp),%rdi
 117d4c5:	ba 80 31 00 00       	mov    $0x3180,%edx
 117d4ca:	48 89 de             	mov    %rbx,%rsi
 117d4cd:	e8 ee 8b 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117d4d2:	48 8b 8d d0 f0 ff ff 	mov    -0xf30(%rbp),%rcx
 117d4d9:	48 83 f9 05          	cmp    $0x5,%rcx
 117d4dd:	0f 92 c0             	setb   %al
 117d4e0:	44 08 f0             	or     %r14b,%al
 117d4e3:	0f 84 8e 00 00 00    	je     117d577 <br.encodeCommandPlanWithOptionsWrite+0x41d7>
 117d4e9:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 117d4ed:	c5 fc 11 85 4e ef ff 	vmovups %ymm0,-0x10b2(%rbp)
 117d4f4:	ff 
 117d4f5:	c5 fc 11 85 40 ef ff 	vmovups %ymm0,-0x10c0(%rbp)
 117d4fc:	ff 
 117d4fd:	c5 fc 11 85 20 ef ff 	vmovups %ymm0,-0x10e0(%rbp)
 117d504:	ff 
 117d505:	c5 fc 11 85 00 ef ff 	vmovups %ymm0,-0x1100(%rbp)
 117d50c:	ff 
 117d50d:	c5 fc 11 85 e0 ee ff 	vmovups %ymm0,-0x1120(%rbp)
 117d514:	ff 
 117d515:	c5 fc 11 85 c0 ee ff 	vmovups %ymm0,-0x1140(%rbp)
 117d51c:	ff 
 117d51d:	c5 fc 11 85 a0 ee ff 	vmovups %ymm0,-0x1160(%rbp)
 117d524:	ff 
 117d525:	c5 fc 11 85 80 ee ff 	vmovups %ymm0,-0x1180(%rbp)
 117d52c:	ff 
 117d52d:	80 7d cc 00          	cmpb   $0x0,-0x34(%rbp)
 117d531:	0f 84 1d 02 00 00    	je     117d754 <br.encodeCommandPlanWithOptionsWrite+0x43b4>
 117d537:	80 7d c4 00          	cmpb   $0x0,-0x3c(%rbp)
 117d53b:	0f 84 4b 1d 00 00    	je     117f28c <br.encodeCommandPlanWithOptionsWrite+0x5eec>
 117d541:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 117d548:	49 89 c7             	mov    %rax,%r15
 117d54b:	48 85 c0             	test   %rax,%rax
 117d54e:	0f 85 9a 1e 00 00    	jne    117f3ee <br.encodeCommandPlanWithOptionsWrite+0x604e>
 117d554:	48 8d 9d 54 df fe ff 	lea    -0x120ac(%rbp),%rbx
 117d55b:	48 8d b5 2e 46 ff ff 	lea    -0xb9d2(%rbp),%rsi
 117d562:	ba 94 05 00 00       	mov    $0x594,%edx
 117d567:	48 89 df             	mov    %rbx,%rdi
 117d56a:	c5 f8 77             	vzeroupper 
 117d56d:	e8 4e 8b 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117d572:	e9 e4 01 00 00       	jmp    117d75b <br.encodeCommandPlanWithOptionsWrite+0x43bb>
 117d577:	48 83 f9 40          	cmp    $0x40,%rcx
 117d57b:	0f 87 b6 00 00 00    	ja     117d637 <br.encodeCommandPlanWithOptionsWrite+0x4297>
 117d581:	48 8d 95 d8 f0 ff ff 	lea    -0xf28(%rbp),%rdx
 117d588:	48 8d bd e0 e2 ff ff 	lea    -0x1d20(%rbp),%rdi
 117d58f:	48 8d b5 20 f2 ff ff 	lea    -0xde0(%rbp),%rsi
 117d596:	e8 95 4a 00 00       	call   1182030 <huffman.HuffmanTable(79).Encoder.initSparseTrusted>
 117d59b:	0f b7 85 ce e3 ff ff 	movzwl -0x1c32(%rbp),%eax
 117d5a2:	66 85 c0             	test   %ax,%ax
 117d5a5:	0f 85 62 be ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117d5ab:	c5 fc 10 85 ae e3 ff 	vmovups -0x1c52(%rbp),%ymm0
 117d5b2:	ff 
 117d5b3:	c5 fc 11 85 ce dc ff 	vmovups %ymm0,-0x2332(%rbp)
 117d5ba:	ff 
 117d5bb:	c5 fc 10 85 a0 e3 ff 	vmovups -0x1c60(%rbp),%ymm0
 117d5c2:	ff 
 117d5c3:	c5 fc 11 85 c0 dc ff 	vmovups %ymm0,-0x2340(%rbp)
 117d5ca:	ff 
 117d5cb:	c5 fc 10 85 80 e3 ff 	vmovups -0x1c80(%rbp),%ymm0
 117d5d2:	ff 
 117d5d3:	c5 fc 11 85 a0 dc ff 	vmovups %ymm0,-0x2360(%rbp)
 117d5da:	ff 
 117d5db:	c5 fc 10 85 60 e3 ff 	vmovups -0x1ca0(%rbp),%ymm0
 117d5e2:	ff 
 117d5e3:	c5 fc 11 85 80 dc ff 	vmovups %ymm0,-0x2380(%rbp)
 117d5ea:	ff 
 117d5eb:	c5 fc 10 85 e0 e2 ff 	vmovups -0x1d20(%rbp),%ymm0
 117d5f2:	ff 
 117d5f3:	c5 fc 10 8d 20 e3 ff 	vmovups -0x1ce0(%rbp),%ymm1
 117d5fa:	ff 
 117d5fb:	c5 fc 10 95 40 e3 ff 	vmovups -0x1cc0(%rbp),%ymm2
 117d602:	ff 
 117d603:	c5 fc 11 95 60 dc ff 	vmovups %ymm2,-0x23a0(%rbp)
 117d60a:	ff 
 117d60b:	c5 fc 11 8d 40 dc ff 	vmovups %ymm1,-0x23c0(%rbp)
 117d612:	ff 
 117d613:	c5 fc 10 8d 00 e3 ff 	vmovups -0x1d00(%rbp),%ymm1
 117d61a:	ff 
 117d61b:	c5 fc 11 8d 20 dc ff 	vmovups %ymm1,-0x23e0(%rbp)
 117d622:	ff 
 117d623:	c5 fc 11 85 00 dc ff 	vmovups %ymm0,-0x2400(%rbp)
 117d62a:	ff 
 117d62b:	48 8d 85 00 dc ff ff 	lea    -0x2400(%rbp),%rax
 117d632:	e9 aa 00 00 00       	jmp    117d6e1 <br.encodeCommandPlanWithOptionsWrite+0x4341>
 117d637:	48 8d bd f0 e1 ff ff 	lea    -0x1e10(%rbp),%rdi
 117d63e:	48 8d b5 20 f2 ff ff 	lea    -0xde0(%rbp),%rsi
 117d645:	e8 c6 45 00 00       	call   1181c10 <huffman.HuffmanTable(79).Encoder.init>
 117d64a:	0f b7 85 de e2 ff ff 	movzwl -0x1d22(%rbp),%eax
 117d651:	66 85 c0             	test   %ax,%ax
 117d654:	0f 85 b3 bd ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117d65a:	c5 fc 10 85 be e2 ff 	vmovups -0x1d42(%rbp),%ymm0
 117d661:	ff 
 117d662:	c5 fc 11 85 de db ff 	vmovups %ymm0,-0x2422(%rbp)
 117d669:	ff 
 117d66a:	c5 fc 10 85 b0 e2 ff 	vmovups -0x1d50(%rbp),%ymm0
 117d671:	ff 
 117d672:	c5 fc 11 85 d0 db ff 	vmovups %ymm0,-0x2430(%rbp)
 117d679:	ff 
 117d67a:	c5 fc 10 85 90 e2 ff 	vmovups -0x1d70(%rbp),%ymm0
 117d681:	ff 
 117d682:	c5 fc 11 85 b0 db ff 	vmovups %ymm0,-0x2450(%rbp)
 117d689:	ff 
 117d68a:	c5 fc 10 85 70 e2 ff 	vmovups -0x1d90(%rbp),%ymm0
 117d691:	ff 
 117d692:	c5 fc 11 85 90 db ff 	vmovups %ymm0,-0x2470(%rbp)
 117d699:	ff 
 117d69a:	c5 fc 10 85 f0 e1 ff 	vmovups -0x1e10(%rbp),%ymm0
 117d6a1:	ff 
 117d6a2:	c5 fc 10 8d 30 e2 ff 	vmovups -0x1dd0(%rbp),%ymm1
 117d6a9:	ff 
 117d6aa:	c5 fc 10 95 50 e2 ff 	vmovups -0x1db0(%rbp),%ymm2
 117d6b1:	ff 
 117d6b2:	c5 fc 11 95 70 db ff 	vmovups %ymm2,-0x2490(%rbp)
 117d6b9:	ff 
 117d6ba:	c5 fc 11 8d 50 db ff 	vmovups %ymm1,-0x24b0(%rbp)
 117d6c1:	ff 
 117d6c2:	c5 fc 10 8d 10 e2 ff 	vmovups -0x1df0(%rbp),%ymm1
 117d6c9:	ff 
 117d6ca:	c5 fc 11 8d 30 db ff 	vmovups %ymm1,-0x24d0(%rbp)
 117d6d1:	ff 
 117d6d2:	c5 fc 11 85 10 db ff 	vmovups %ymm0,-0x24f0(%rbp)
 117d6d9:	ff 
 117d6da:	48 8d 85 10 db ff ff 	lea    -0x24f0(%rbp),%rax
 117d6e1:	c5 fc 10 80 ce 00 00 	vmovups 0xce(%rax),%ymm0
 117d6e8:	00 
 117d6e9:	c5 fc 11 85 4e ef ff 	vmovups %ymm0,-0x10b2(%rbp)
 117d6f0:	ff 
 117d6f1:	c5 fc 10 80 c0 00 00 	vmovups 0xc0(%rax),%ymm0
 117d6f8:	00 
 117d6f9:	c5 fc 11 85 40 ef ff 	vmovups %ymm0,-0x10c0(%rbp)
 117d700:	ff 
 117d701:	c5 fc 10 80 a0 00 00 	vmovups 0xa0(%rax),%ymm0
 117d708:	00 
 117d709:	c5 fc 11 85 20 ef ff 	vmovups %ymm0,-0x10e0(%rbp)
 117d710:	ff 
 117d711:	c5 fc 10 80 80 00 00 	vmovups 0x80(%rax),%ymm0
 117d718:	00 
 117d719:	c5 fc 11 85 00 ef ff 	vmovups %ymm0,-0x1100(%rbp)
 117d720:	ff 
 117d721:	c5 fc 10 00          	vmovups (%rax),%ymm0
 117d725:	c5 fc 10 48 40       	vmovups 0x40(%rax),%ymm1
 117d72a:	c5 fc 10 50 60       	vmovups 0x60(%rax),%ymm2
 117d72f:	c5 fc 11 95 e0 ee ff 	vmovups %ymm2,-0x1120(%rbp)
 117d736:	ff 
 117d737:	c5 fc 11 8d c0 ee ff 	vmovups %ymm1,-0x1140(%rbp)
 117d73e:	ff 
 117d73f:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 117d744:	c5 fc 11 8d a0 ee ff 	vmovups %ymm1,-0x1160(%rbp)
 117d74b:	ff 
 117d74c:	c5 fc 11 85 80 ee ff 	vmovups %ymm0,-0x1180(%rbp)
 117d753:	ff 
 117d754:	48 8d 1d 05 c8 ea ff 	lea    -0x1537fb(%rip),%rbx        # 1029f60 <__anon_36546>
 117d75b:	48 8d bd 9a 40 ff ff 	lea    -0xbf66(%rbp),%rdi
 117d762:	ba 94 05 00 00       	mov    $0x594,%edx
 117d767:	48 89 de             	mov    %rbx,%rsi
 117d76a:	c5 f8 77             	vzeroupper 
 117d76d:	e8 4e 89 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117d772:	c5 fc 10 85 b0 f0 ff 	vmovups -0xf50(%rbp),%ymm0
 117d779:	ff 
 117d77a:	c5 fc 11 85 40 fd ff 	vmovups %ymm0,-0x2c0(%rbp)
 117d781:	ff 
 117d782:	80 7d cb 01          	cmpb   $0x1,-0x35(%rbp)
 117d786:	be 02 00 00 00       	mov    $0x2,%esi
 117d78b:	bf 02 00 00 00       	mov    $0x2,%edi
 117d790:	48 83 df 00          	sbb    $0x0,%rdi
 117d794:	80 7d c5 01          	cmpb   $0x1,-0x3b(%rbp)
 117d798:	41 b8 02 00 00 00    	mov    $0x2,%r8d
 117d79e:	49 83 d8 00          	sbb    $0x0,%r8
 117d7a2:	80 7d d5 01          	cmpb   $0x1,-0x2b(%rbp)
 117d7a6:	48 83 de 00          	sbb    $0x0,%rsi
 117d7aa:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 117d7ae:	b8 03 00 00 00       	mov    $0x3,%eax
 117d7b3:	48 0f 45 f8          	cmovne %rax,%rdi
 117d7b7:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 117d7bb:	b9 04 00 00 00       	mov    $0x4,%ecx
 117d7c0:	48 0f 45 f9          	cmovne %rcx,%rdi
 117d7c4:	80 7d cd 00          	cmpb   $0x0,-0x33(%rbp)
 117d7c8:	ba 05 00 00 00       	mov    $0x5,%edx
 117d7cd:	48 0f 45 fa          	cmovne %rdx,%rdi
 117d7d1:	48 89 bd 28 fd ff ff 	mov    %rdi,-0x2d8(%rbp)
 117d7d8:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 117d7dc:	4c 0f 45 c0          	cmovne %rax,%r8
 117d7e0:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 117d7e4:	4c 0f 45 c1          	cmovne %rcx,%r8
 117d7e8:	80 7d ca 00          	cmpb   $0x0,-0x36(%rbp)
 117d7ec:	4c 0f 45 c2          	cmovne %rdx,%r8
 117d7f0:	4c 89 85 50 fe ff ff 	mov    %r8,-0x1b0(%rbp)
 117d7f7:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 117d7fb:	48 0f 45 f0          	cmovne %rax,%rsi
 117d7ff:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 117d803:	48 0f 45 f1          	cmovne %rcx,%rsi
 117d807:	80 7d ce 00          	cmpb   $0x0,-0x32(%rbp)
 117d80b:	48 0f 45 f2          	cmovne %rdx,%rsi
 117d80f:	48 89 b5 10 fd ff ff 	mov    %rsi,-0x2f0(%rbp)
 117d816:	80 65 9f 0f          	andb   $0xf,-0x61(%rbp)
 117d81a:	48 c7 85 70 ff ff ff 	movq   $0x0,-0x90(%rbp)
 117d821:	00 00 00 00 
 117d825:	48 c7 85 e0 fd ff ff 	movq   $0x0,-0x220(%rbp)
 117d82c:	00 00 00 00 
 117d830:	45 31 ff             	xor    %r15d,%r15d
 117d833:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 117d83a:	48 8d 04 40          	lea    (%rax,%rax,2),%rax
 117d83e:	48 c1 e0 05          	shl    $0x5,%rax
 117d842:	48 8b 8d f8 fd ff ff 	mov    -0x208(%rbp),%rcx
 117d849:	c5 fc 10 04 01       	vmovups (%rcx,%rax,1),%ymm0
 117d84e:	c5 fc 10 4c 01 20    	vmovups 0x20(%rcx,%rax,1),%ymm1
 117d854:	c5 fc 10 54 01 40    	vmovups 0x40(%rcx,%rax,1),%ymm2
 117d85a:	c5 fc 11 85 70 f2 ff 	vmovups %ymm0,-0xd90(%rbp)
 117d861:	ff 
 117d862:	c5 fc 11 95 b0 f2 ff 	vmovups %ymm2,-0xd50(%rbp)
 117d869:	ff 
 117d86a:	c5 fc 11 8d 90 f2 ff 	vmovups %ymm1,-0xd70(%rbp)
 117d871:	ff 
 117d872:	48 8b 85 70 f2 ff ff 	mov    -0xd90(%rbp),%rax
 117d879:	48 89 85 78 fd ff ff 	mov    %rax,-0x288(%rbp)
 117d880:	48 8b 85 78 f2 ff ff 	mov    -0xd88(%rbp),%rax
 117d887:	48 89 85 f8 fe ff ff 	mov    %rax,-0x108(%rbp)
 117d88e:	48 8b 85 80 f2 ff ff 	mov    -0xd80(%rbp),%rax
 117d895:	48 89 85 f0 fd ff ff 	mov    %rax,-0x210(%rbp)
 117d89c:	0f b6 8d c8 f2 ff ff 	movzbl -0xd38(%rbp),%ecx
 117d8a3:	0f b6 85 c9 f2 ff ff 	movzbl -0xd37(%rbp),%eax
 117d8aa:	88 45 b7             	mov    %al,-0x49(%rbp)
 117d8ad:	88 8d 48 ff ff ff    	mov    %cl,-0xb8(%rbp)
 117d8b3:	88 4d 8c             	mov    %cl,-0x74(%rbp)
 117d8b6:	f6 c1 01             	test   $0x1,%cl
 117d8b9:	74 4a                	je     117d905 <br.encodeCommandPlanWithOptionsWrite+0x4565>
 117d8bb:	48 8d bd f8 f8 ff ff 	lea    -0x708(%rbp),%rdi
 117d8c2:	48 8d b5 70 f2 ff ff 	lea    -0xd90(%rbp),%rsi
 117d8c9:	8b 95 34 fe ff ff    	mov    -0x1cc(%rbp),%edx
 117d8cf:	48 8b 8d 20 fc ff ff 	mov    -0x3e0(%rbp),%rcx
 117d8d6:	4c 8b 85 18 fc ff ff 	mov    -0x3e8(%rbp),%r8
 117d8dd:	c5 f8 77             	vzeroupper 
 117d8e0:	e8 3b 1b 04 00       	call   11bf420 <br.commandWireDistance>
 117d8e5:	0f b7 85 00 f9 ff ff 	movzwl -0x700(%rbp),%eax
 117d8ec:	66 85 c0             	test   %ax,%ax
 117d8ef:	0f 85 18 bb ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117d8f5:	48 8b 85 f8 f8 ff ff 	mov    -0x708(%rbp),%rax
 117d8fc:	48 89 85 00 ff ff ff 	mov    %rax,-0x100(%rbp)
 117d903:	eb 0b                	jmp    117d910 <br.encodeCommandPlanWithOptionsWrite+0x4570>
 117d905:	48 c7 85 00 ff ff ff 	movq   $0x0,-0x100(%rbp)
 117d90c:	00 00 00 00 
 117d910:	48 83 ec 08          	sub    $0x8,%rsp
 117d914:	48 8d bd 30 f3 ff ff 	lea    -0xcd0(%rbp),%rdi
 117d91b:	48 8d b5 70 f2 ff ff 	lea    -0xd90(%rbp),%rsi
 117d922:	48 8b 95 00 ff ff ff 	mov    -0x100(%rbp),%rdx
 117d929:	8b 8d 2c fe ff ff    	mov    -0x1d4(%rbp),%ecx
 117d92f:	44 8b 85 30 fe ff ff 	mov    -0x1d0(%rbp),%r8d
 117d936:	4c 8d 8d 40 fd ff ff 	lea    -0x2c0(%rbp),%r9
 117d93d:	6a 00                	push   $0x0
 117d93f:	c5 f8 77             	vzeroupper 
 117d942:	e8 29 16 04 00       	call   11bef70 <br.resolveHqCommand>
 117d947:	48 83 c4 10          	add    $0x10,%rsp
 117d94b:	0f b7 85 78 f3 ff ff 	movzwl -0xc88(%rbp),%eax
 117d952:	66 85 c0             	test   %ax,%ax
 117d955:	0f 85 b2 ba ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117d95b:	c5 fc 10 85 30 f3 ff 	vmovups -0xcd0(%rbp),%ymm0
 117d962:	ff 
 117d963:	c5 fc 10 8d 40 f3 ff 	vmovups -0xcc0(%rbp),%ymm1
 117d96a:	ff 
 117d96b:	c5 fc 11 8d 60 ee ff 	vmovups %ymm1,-0x11a0(%rbp)
 117d972:	ff 
 117d973:	c5 fc 11 85 50 ee ff 	vmovups %ymm0,-0x11b0(%rbp)
 117d97a:	ff 
 117d97b:	48 8b 85 60 f3 ff ff 	mov    -0xca0(%rbp),%rax
 117d982:	48 89 85 90 fd ff ff 	mov    %rax,-0x270(%rbp)
 117d989:	0f b6 85 68 f3 ff ff 	movzbl -0xc98(%rbp),%eax
 117d990:	88 85 98 fd ff ff    	mov    %al,-0x268(%rbp)
 117d996:	44 0f b6 a5 6c f3 ff 	movzbl -0xc94(%rbp),%r12d
 117d99d:	ff 
 117d99e:	0f b6 9d 6d f3 ff ff 	movzbl -0xc93(%rbp),%ebx
 117d9a5:	0f b6 85 70 f3 ff ff 	movzbl -0xc90(%rbp),%eax
 117d9ac:	88 85 80 fd ff ff    	mov    %al,-0x280(%rbp)
 117d9b2:	44 0f b6 ad 6f be ff 	movzbl -0x4191(%rbp),%r13d
 117d9b9:	ff 
 117d9ba:	4c 8d 35 c9 51 e9 ff 	lea    -0x16ae37(%rip),%r14        # 1012b8a <__anon_35653>
 117d9c1:	45 84 ed             	test   %r13b,%r13b
 117d9c4:	74 27                	je     117d9ed <br.encodeCommandPlanWithOptionsWrite+0x464d>
 117d9c6:	48 8b 8d 58 fd ff ff 	mov    -0x2a8(%rbp),%rcx
 117d9cd:	4c 8d b5 ba fb ff ff 	lea    -0x446(%rbp),%r14
 117d9d4:	4c 89 f7             	mov    %r14,%rdi
 117d9d7:	48 8d b5 70 f2 ff ff 	lea    -0xd90(%rbp),%rsi
 117d9de:	48 8b 95 00 ff ff ff 	mov    -0x100(%rbp),%rdx
 117d9e5:	c5 f8 77             	vzeroupper 
 117d9e8:	e8 e3 0d 04 00       	call   11be7d0 <br.sameLastDistanceShape>
 117d9ed:	80 bd 80 fd ff ff 00 	cmpb   $0x0,-0x280(%rbp)
 117d9f4:	0f 84 d4 00 00 00    	je     117dace <br.encodeCommandPlanWithOptionsWrite+0x472e>
 117d9fa:	44 88 a5 35 ff ff ff 	mov    %r12b,-0xcb(%rbp)
 117da01:	88 9d 36 ff ff ff    	mov    %bl,-0xca(%rbp)
 117da07:	48 8d 85 36 ff ff ff 	lea    -0xca(%rbp),%rax
 117da0e:	48 89 85 40 fe ff ff 	mov    %rax,-0x1c0(%rbp)
 117da15:	48 8d 85 35 ff ff ff 	lea    -0xcb(%rbp),%rax
 117da1c:	48 89 85 d0 fe ff ff 	mov    %rax,-0x130(%rbp)
 117da23:	41 80 7e 02 00       	cmpb   $0x0,0x2(%r14)
 117da28:	0f 85 c7 00 00 00    	jne    117daf5 <br.encodeCommandPlanWithOptionsWrite+0x4755>
 117da2e:	b1 01                	mov    $0x1,%cl
 117da30:	48 8b 85 40 fe ff ff 	mov    -0x1c0(%rbp),%rax
 117da37:	80 38 00             	cmpb   $0x0,(%rax)
 117da3a:	0f 84 bc 01 00 00    	je     117dbfc <br.encodeCommandPlanWithOptionsWrite+0x485c>
 117da40:	48 8b 85 d0 fe ff ff 	mov    -0x130(%rbp),%rax
 117da47:	0f b6 00             	movzbl (%rax),%eax
 117da4a:	24 0f                	and    $0xf,%al
 117da4c:	3a 45 9f             	cmp    -0x61(%rbp),%al
 117da4f:	0f 94 c0             	sete   %al
 117da52:	80 bd 80 fd ff ff 00 	cmpb   $0x0,-0x280(%rbp)
 117da59:	0f 85 c7 00 00 00    	jne    117db26 <br.encodeCommandPlanWithOptionsWrite+0x4786>
 117da5f:	48 81 bd 58 ff ff ff 	cmpq   $0x81,-0xa8(%rbp)
 117da66:	81 00 00 00 
 117da6a:	0f 93 c2             	setae  %dl
 117da6d:	44 08 ea             	or     %r13b,%dl
 117da70:	0f 84 cf 00 00 00    	je     117db45 <br.encodeCommandPlanWithOptionsWrite+0x47a5>
 117da76:	84 c9                	test   %cl,%cl
 117da78:	0f 84 92 01 00 00    	je     117dc10 <br.encodeCommandPlanWithOptionsWrite+0x4870>
 117da7e:	0f b6 c8             	movzbl %al,%ecx
 117da81:	48 8d bd 1c f4 ff ff 	lea    -0xbe4(%rbp),%rdi
 117da88:	48 8b b5 f8 fe ff ff 	mov    -0x108(%rbp),%rsi
 117da8f:	48 8b 95 f0 fd ff ff 	mov    -0x210(%rbp),%rdx
 117da96:	c5 f8 77             	vzeroupper 
 117da99:	e8 62 12 04 00       	call   11bed00 <br.commandEntryForLengthsAndDistance>
 117da9e:	80 bd 2c f4 ff ff 00 	cmpb   $0x0,-0xbd4(%rbp)
 117daa5:	0f 84 c0 01 00 00    	je     117dc6b <br.encodeCommandPlanWithOptionsWrite+0x48cb>
 117daab:	c5 f8 10 85 1c f4 ff 	vmovups -0xbe4(%rbp),%xmm0
 117dab2:	ff 
 117dab3:	c5 f8 29 85 30 f4 ff 	vmovaps %xmm0,-0xbd0(%rbp)
 117daba:	ff 
 117dabb:	c6 85 40 f4 ff ff 01 	movb   $0x1,-0xbc0(%rbp)
 117dac2:	48 8d 85 30 f4 ff ff 	lea    -0xbd0(%rbp),%rax
 117dac9:	e9 bd 01 00 00       	jmp    117dc8b <br.encodeCommandPlanWithOptionsWrite+0x48eb>
 117dace:	41 80 7e 02 00       	cmpb   $0x0,0x2(%r14)
 117dad3:	48 8d 05 ae 50 e9 ff 	lea    -0x16af52(%rip),%rax        # 1012b88 <__anon_35632>
 117dada:	48 89 85 d0 fe ff ff 	mov    %rax,-0x130(%rbp)
 117dae1:	48 8d 05 a1 50 e9 ff 	lea    -0x16af5f(%rip),%rax        # 1012b89 <__anon_35632+0x1>
 117dae8:	48 89 85 40 fe ff ff 	mov    %rax,-0x1c0(%rbp)
 117daef:	0f 84 92 00 00 00    	je     117db87 <br.encodeCommandPlanWithOptionsWrite+0x47e7>
 117daf5:	41 0f b6 06          	movzbl (%r14),%eax
 117daf9:	41 0f b6 4e 01       	movzbl 0x1(%r14),%ecx
 117dafe:	83 e0 1f             	and    $0x1f,%eax
 117db01:	48 8d 04 40          	lea    (%rax,%rax,2),%rax
 117db05:	48 8d 95 70 be ff ff 	lea    -0x4190(%rbp),%rdx
 117db0c:	48 8d 04 c2          	lea    (%rdx,%rax,8),%rax
 117db10:	83 e1 1f             	and    $0x1f,%ecx
 117db13:	0f b6 04 01          	movzbl (%rcx,%rax,1),%eax
 117db17:	31 c9                	xor    %ecx,%ecx
 117db19:	80 bd 80 fd ff ff 00 	cmpb   $0x0,-0x280(%rbp)
 117db20:	0f 84 39 ff ff ff    	je     117da5f <br.encodeCommandPlanWithOptionsWrite+0x46bf>
 117db26:	48 8d 85 50 f3 ff ff 	lea    -0xcb0(%rbp),%rax
 117db2d:	c5 f8 10 00          	vmovups (%rax),%xmm0
 117db31:	c5 f8 29 85 90 f3 ff 	vmovaps %xmm0,-0xc70(%rbp)
 117db38:	ff 
 117db39:	48 8d 85 90 f3 ff ff 	lea    -0xc70(%rbp),%rax
 117db40:	e9 a3 01 00 00       	jmp    117dce8 <br.encodeCommandPlanWithOptionsWrite+0x4948>
 117db45:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 117db4c:	0f b7 84 45 b0 c4 ff 	movzwl -0x3b50(%rbp,%rax,2),%eax
 117db53:	ff 
 117db54:	48 8d 0c 40          	lea    (%rax,%rax,2),%rcx
 117db58:	48 8d 35 95 c9 ea ff 	lea    -0x15366b(%rip),%rsi        # 102a4f4 <__anon_37277>
 117db5f:	48 8b 14 8e          	mov    (%rsi,%rcx,4),%rdx
 117db63:	48 89 95 40 fa ff ff 	mov    %rdx,-0x5c0(%rbp)
 117db6a:	8b 4c 8e 08          	mov    0x8(%rsi,%rcx,4),%ecx
 117db6e:	89 8d 48 fa ff ff    	mov    %ecx,-0x5b8(%rbp)
 117db74:	66 89 85 4c fa ff ff 	mov    %ax,-0x5b4(%rbp)
 117db7b:	48 8d 85 40 fa ff ff 	lea    -0x5c0(%rbp),%rax
 117db82:	e9 61 01 00 00       	jmp    117dce8 <br.encodeCommandPlanWithOptionsWrite+0x4948>
 117db87:	0f b6 45 9d          	movzbl -0x63(%rbp),%eax
 117db8b:	22 45 8c             	and    -0x74(%rbp),%al
 117db8e:	0f b6 4d b7          	movzbl -0x49(%rbp),%ecx
 117db92:	80 e1 03             	and    $0x3,%cl
 117db95:	80 f9 02             	cmp    $0x2,%cl
 117db98:	0f 95 c1             	setne  %cl
 117db9b:	20 c1                	and    %al,%cl
 117db9d:	48 8d 05 dd cd e8 ff 	lea    -0x173223(%rip),%rax        # 100a981 <__anon_2888+0x1>
 117dba4:	48 89 85 40 fe ff ff 	mov    %rax,-0x1c0(%rbp)
 117dbab:	48 8d 05 ce cd e8 ff 	lea    -0x173232(%rip),%rax        # 100a980 <__anon_2888>
 117dbb2:	48 89 85 d0 fe ff ff 	mov    %rax,-0x130(%rbp)
 117dbb9:	80 f9 01             	cmp    $0x1,%cl
 117dbbc:	0f 85 61 fe ff ff    	jne    117da23 <br.encodeCommandPlanWithOptionsWrite+0x4683>
 117dbc2:	48 8d 9d a6 fd ff ff 	lea    -0x25a(%rbp),%rbx
 117dbc9:	48 89 df             	mov    %rbx,%rdi
 117dbcc:	48 8b b5 00 ff ff ff 	mov    -0x100(%rbp),%rsi
 117dbd3:	48 8d 95 40 fd ff ff 	lea    -0x2c0(%rbp),%rdx
 117dbda:	c5 f8 77             	vzeroupper 
 117dbdd:	e8 0e 12 04 00       	call   11bedf0 <br.decoder.distance_history.symbolForDistance>
 117dbe2:	48 8d 85 a7 fd ff ff 	lea    -0x259(%rbp),%rax
 117dbe9:	48 89 85 40 fe ff ff 	mov    %rax,-0x1c0(%rbp)
 117dbf0:	48 89 9d d0 fe ff ff 	mov    %rbx,-0x130(%rbp)
 117dbf7:	e9 27 fe ff ff       	jmp    117da23 <br.encodeCommandPlanWithOptionsWrite+0x4683>
 117dbfc:	31 c0                	xor    %eax,%eax
 117dbfe:	80 bd 80 fd ff ff 00 	cmpb   $0x0,-0x280(%rbp)
 117dc05:	0f 85 1b ff ff ff    	jne    117db26 <br.encodeCommandPlanWithOptionsWrite+0x4786>
 117dc0b:	e9 4f fe ff ff       	jmp    117da5f <br.encodeCommandPlanWithOptionsWrite+0x46bf>
 117dc10:	41 0f b6 0e          	movzbl (%r14),%ecx
 117dc14:	41 0f b6 56 01       	movzbl 0x1(%r14),%edx
 117dc19:	a8 01                	test   $0x1,%al
 117dc1b:	48 8d 05 ee 08 eb ff 	lea    -0x14f712(%rip),%rax        # 102e510 <br.encoder.command_encoding.explicit_symbol_index>
 117dc22:	48 8d 35 67 04 eb ff 	lea    -0x14fb99(%rip),%rsi        # 102e090 <br.encoder.command_encoding.last_distance_symbol_index>
 117dc29:	48 0f 45 c6          	cmovne %rsi,%rax
 117dc2d:	83 e1 1f             	and    $0x1f,%ecx
 117dc30:	48 8d 0c 49          	lea    (%rcx,%rcx,2),%rcx
 117dc34:	c1 e1 04             	shl    $0x4,%ecx
 117dc37:	48 01 c1             	add    %rax,%rcx
 117dc3a:	83 e2 1f             	and    $0x1f,%edx
 117dc3d:	0f b7 04 51          	movzwl (%rcx,%rdx,2),%eax
 117dc41:	48 3d ff ff 00 00    	cmp    $0xffff,%rax
 117dc47:	74 57                	je     117dca0 <br.encodeCommandPlanWithOptionsWrite+0x4900>
 117dc49:	48 8d 0c 40          	lea    (%rax,%rax,2),%rcx
 117dc4d:	48 8d 35 a0 c8 ea ff 	lea    -0x153760(%rip),%rsi        # 102a4f4 <__anon_37277>
 117dc54:	8b 54 8e 08          	mov    0x8(%rsi,%rcx,4),%edx
 117dc58:	89 95 58 fc ff ff    	mov    %edx,-0x3a8(%rbp)
 117dc5e:	48 8b 0c 8e          	mov    (%rsi,%rcx,4),%rcx
 117dc62:	48 89 8d 50 fc ff ff 	mov    %rcx,-0x3b0(%rbp)
 117dc69:	eb 4c                	jmp    117dcb7 <br.encodeCommandPlanWithOptionsWrite+0x4917>
 117dc6b:	48 8d 9d 7c e9 ff ff 	lea    -0x1684(%rbp),%rbx
 117dc72:	48 89 df             	mov    %rbx,%rdi
 117dc75:	48 8b b5 f8 fe ff ff 	mov    -0x108(%rbp),%rsi
 117dc7c:	48 8b 95 f0 fd ff ff 	mov    -0x210(%rbp),%rdx
 117dc83:	e8 08 0c 04 00       	call   11be890 <br.commandEntryForLengths>
 117dc88:	48 89 d8             	mov    %rbx,%rax
 117dc8b:	c5 f8 10 00          	vmovups (%rax),%xmm0
 117dc8f:	c5 f8 29 85 80 f3 ff 	vmovaps %xmm0,-0xc80(%rbp)
 117dc96:	ff 
 117dc97:	48 8d 85 80 f3 ff ff 	lea    -0xc80(%rbp),%rax
 117dc9e:	eb 48                	jmp    117dce8 <br.encodeCommandPlanWithOptionsWrite+0x4948>
 117dca0:	c7 85 58 fc ff ff 00 	movl   $0x0,-0x3a8(%rbp)
 117dca7:	00 00 00 
 117dcaa:	48 c7 85 50 fc ff ff 	movq   $0x0,-0x3b0(%rbp)
 117dcb1:	00 00 00 00 
 117dcb5:	31 c0                	xor    %eax,%eax
 117dcb7:	8b 8d 58 fc ff ff    	mov    -0x3a8(%rbp),%ecx
 117dcbd:	89 8d b0 fb ff ff    	mov    %ecx,-0x450(%rbp)
 117dcc3:	48 8b 8d 50 fc ff ff 	mov    -0x3b0(%rbp),%rcx
 117dcca:	48 89 8d a8 fb ff ff 	mov    %rcx,-0x458(%rbp)
 117dcd1:	66 89 85 b4 fb ff ff 	mov    %ax,-0x44c(%rbp)
 117dcd8:	66 c7 85 b6 fb ff ff 	movw   $0x0,-0x44a(%rbp)
 117dcdf:	00 00 
 117dce1:	48 8d 85 a8 fb ff ff 	lea    -0x458(%rbp),%rax
 117dce8:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 117dcec:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 117dcf0:	0f b6 41 0a          	movzbl 0xa(%rcx),%eax
 117dcf4:	88 45 b6             	mov    %al,-0x4a(%rbp)
 117dcf7:	0f b7 41 0c          	movzwl 0xc(%rcx),%eax
 117dcfb:	48 89 85 b8 fd ff ff 	mov    %rax,-0x248(%rbp)
 117dd02:	4c 8d a5 b0 c5 ff ff 	lea    -0x3a50(%rbp),%r12
 117dd09:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 117dd0d:	0f 84 44 01 00 00    	je     117de57 <br.encodeCommandPlanWithOptionsWrite+0x4ab7>
 117dd13:	8b 85 7b fe ff ff    	mov    -0x185(%rbp),%eax
 117dd19:	48 8d 8d 01 f6 ff ff 	lea    -0x9ff(%rbp),%rcx
 117dd20:	89 41 03             	mov    %eax,0x3(%rcx)
 117dd23:	8b 85 78 fe ff ff    	mov    -0x188(%rbp),%eax
 117dd29:	89 01                	mov    %eax,(%rcx)
 117dd2b:	8b 85 83 fe ff ff    	mov    -0x17d(%rbp),%eax
 117dd31:	89 41 13             	mov    %eax,0x13(%rcx)
 117dd34:	8b 85 80 fe ff ff    	mov    -0x180(%rbp),%eax
 117dd3a:	89 41 10             	mov    %eax,0x10(%rcx)
 117dd3d:	8b 85 8b fe ff ff    	mov    -0x175(%rbp),%eax
 117dd43:	89 41 23             	mov    %eax,0x23(%rcx)
 117dd46:	8b 85 88 fe ff ff    	mov    -0x178(%rbp),%eax
 117dd4c:	89 41 20             	mov    %eax,0x20(%rcx)
 117dd4f:	8b 85 93 fe ff ff    	mov    -0x16d(%rbp),%eax
 117dd55:	89 41 33             	mov    %eax,0x33(%rcx)
 117dd58:	8b 85 90 fe ff ff    	mov    -0x170(%rbp),%eax
 117dd5e:	89 41 30             	mov    %eax,0x30(%rcx)
 117dd61:	8b 85 9b fe ff ff    	mov    -0x165(%rbp),%eax
 117dd67:	89 41 43             	mov    %eax,0x43(%rcx)
 117dd6a:	8b 85 98 fe ff ff    	mov    -0x168(%rbp),%eax
 117dd70:	89 41 40             	mov    %eax,0x40(%rcx)
 117dd73:	0f b7 85 e0 fe ff ff 	movzwl -0x120(%rbp),%eax
 117dd7a:	66 89 41 55          	mov    %ax,0x55(%rcx)
 117dd7e:	8b 85 dc fe ff ff    	mov    -0x124(%rbp),%eax
 117dd84:	89 41 51             	mov    %eax,0x51(%rcx)
 117dd87:	48 8b 85 38 fe ff ff 	mov    -0x1c8(%rbp),%rax
 117dd8e:	48 89 85 f0 f5 ff ff 	mov    %rax,-0xa10(%rbp)
 117dd95:	48 8b 85 c0 fd ff ff 	mov    -0x240(%rbp),%rax
 117dd9c:	48 89 85 f8 f5 ff ff 	mov    %rax,-0xa08(%rbp)
 117dda3:	0f b6 45 cb          	movzbl -0x35(%rbp),%eax
 117dda7:	88 85 00 f6 ff ff    	mov    %al,-0xa00(%rbp)
 117ddad:	48 8b 85 c8 fd ff ff 	mov    -0x238(%rbp),%rax
 117ddb4:	48 89 85 08 f6 ff ff 	mov    %rax,-0x9f8(%rbp)
 117ddbb:	0f b6 45 d0          	movzbl -0x30(%rbp),%eax
 117ddbf:	88 85 10 f6 ff ff    	mov    %al,-0x9f0(%rbp)
 117ddc5:	48 8b 85 d0 fd ff ff 	mov    -0x230(%rbp),%rax
 117ddcc:	48 89 85 18 f6 ff ff 	mov    %rax,-0x9e8(%rbp)
 117ddd3:	0f b6 45 d6          	movzbl -0x2a(%rbp),%eax
 117ddd7:	88 85 20 f6 ff ff    	mov    %al,-0x9e0(%rbp)
 117dddd:	48 8b 85 d8 fd ff ff 	mov    -0x228(%rbp),%rax
 117dde4:	48 89 85 28 f6 ff ff 	mov    %rax,-0x9d8(%rbp)
 117ddeb:	0f b6 45 cd          	movzbl -0x33(%rbp),%eax
 117ddef:	88 85 30 f6 ff ff    	mov    %al,-0x9d0(%rbp)
 117ddf5:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 117ddfc:	48 89 85 38 f6 ff ff 	mov    %rax,-0x9c8(%rbp)
 117de03:	0f b6 45 c1          	movzbl -0x3f(%rbp),%eax
 117de07:	88 85 40 f6 ff ff    	mov    %al,-0x9c0(%rbp)
 117de0d:	48 8b 85 18 fd ff ff 	mov    -0x2e8(%rbp),%rax
 117de14:	48 89 85 48 f6 ff ff 	mov    %rax,-0x9b8(%rbp)
 117de1b:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 117de1f:	88 85 50 f6 ff ff    	mov    %al,-0x9b0(%rbp)
 117de25:	0f b6 45 c7          	movzbl -0x39(%rbp),%eax
 117de29:	88 85 51 f6 ff ff    	mov    %al,-0x9af(%rbp)
 117de2f:	48 8d bd f0 f5 ff ff 	lea    -0xa10(%rbp),%rdi
 117de36:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 117de3d:	c5 f8 77             	vzeroupper 
 117de40:	e8 fb 07 04 00       	call   11be640 <br.encoder.command_block_split.Result.blockIndex>
 117de45:	48 69 c0 88 05 00 00 	imul   $0x588,%rax,%rax
 117de4c:	4c 8d 24 28          	lea    (%rax,%rbp,1),%r12
 117de50:	49 81 c4 e8 fc fe ff 	add    $0xfffffffffffefce8,%r12
 117de57:	4c 8d b5 0a 75 ff ff 	lea    -0x8af6(%rbp),%r14
 117de5e:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 117de62:	0f 84 ff 01 00 00    	je     117e067 <br.encodeCommandPlanWithOptionsWrite+0x4cc7>
 117de68:	8b 85 7b fe ff ff    	mov    -0x185(%rbp),%eax
 117de6e:	48 8d 8d 99 f5 ff ff 	lea    -0xa67(%rbp),%rcx
 117de75:	89 41 03             	mov    %eax,0x3(%rcx)
 117de78:	8b 85 78 fe ff ff    	mov    -0x188(%rbp),%eax
 117de7e:	89 01                	mov    %eax,(%rcx)
 117de80:	8b 85 83 fe ff ff    	mov    -0x17d(%rbp),%eax
 117de86:	89 41 13             	mov    %eax,0x13(%rcx)
 117de89:	8b 85 80 fe ff ff    	mov    -0x180(%rbp),%eax
 117de8f:	89 41 10             	mov    %eax,0x10(%rcx)
 117de92:	8b 85 8b fe ff ff    	mov    -0x175(%rbp),%eax
 117de98:	89 41 23             	mov    %eax,0x23(%rcx)
 117de9b:	8b 85 88 fe ff ff    	mov    -0x178(%rbp),%eax
 117dea1:	89 41 20             	mov    %eax,0x20(%rcx)
 117dea4:	8b 85 93 fe ff ff    	mov    -0x16d(%rbp),%eax
 117deaa:	89 41 33             	mov    %eax,0x33(%rcx)
 117dead:	8b 85 90 fe ff ff    	mov    -0x170(%rbp),%eax
 117deb3:	89 41 30             	mov    %eax,0x30(%rcx)
 117deb6:	8b 85 9b fe ff ff    	mov    -0x165(%rbp),%eax
 117debc:	89 41 43             	mov    %eax,0x43(%rcx)
 117debf:	8b 85 98 fe ff ff    	mov    -0x168(%rbp),%eax
 117dec5:	89 41 40             	mov    %eax,0x40(%rcx)
 117dec8:	0f b7 85 e0 fe ff ff 	movzwl -0x120(%rbp),%eax
 117decf:	66 89 41 55          	mov    %ax,0x55(%rcx)
 117ded3:	8b 85 dc fe ff ff    	mov    -0x124(%rbp),%eax
 117ded9:	89 41 51             	mov    %eax,0x51(%rcx)
 117dedc:	48 8b 85 38 fe ff ff 	mov    -0x1c8(%rbp),%rax
 117dee3:	48 89 85 88 f5 ff ff 	mov    %rax,-0xa78(%rbp)
 117deea:	48 8b 85 c0 fd ff ff 	mov    -0x240(%rbp),%rax
 117def1:	48 89 85 90 f5 ff ff 	mov    %rax,-0xa70(%rbp)
 117def8:	0f b6 45 cb          	movzbl -0x35(%rbp),%eax
 117defc:	88 85 98 f5 ff ff    	mov    %al,-0xa68(%rbp)
 117df02:	48 8b 85 c8 fd ff ff 	mov    -0x238(%rbp),%rax
 117df09:	48 89 85 a0 f5 ff ff 	mov    %rax,-0xa60(%rbp)
 117df10:	0f b6 45 d0          	movzbl -0x30(%rbp),%eax
 117df14:	88 85 a8 f5 ff ff    	mov    %al,-0xa58(%rbp)
 117df1a:	48 8b 85 d0 fd ff ff 	mov    -0x230(%rbp),%rax
 117df21:	48 89 85 b0 f5 ff ff 	mov    %rax,-0xa50(%rbp)
 117df28:	0f b6 45 d6          	movzbl -0x2a(%rbp),%eax
 117df2c:	88 85 b8 f5 ff ff    	mov    %al,-0xa48(%rbp)
 117df32:	48 8b 85 d8 fd ff ff 	mov    -0x228(%rbp),%rax
 117df39:	48 89 85 c0 f5 ff ff 	mov    %rax,-0xa40(%rbp)
 117df40:	0f b6 45 cd          	movzbl -0x33(%rbp),%eax
 117df44:	88 85 c8 f5 ff ff    	mov    %al,-0xa38(%rbp)
 117df4a:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 117df51:	48 89 85 d0 f5 ff ff 	mov    %rax,-0xa30(%rbp)
 117df58:	0f b6 45 c1          	movzbl -0x3f(%rbp),%eax
 117df5c:	88 85 d8 f5 ff ff    	mov    %al,-0xa28(%rbp)
 117df62:	48 8b 85 18 fd ff ff 	mov    -0x2e8(%rbp),%rax
 117df69:	48 89 85 e0 f5 ff ff 	mov    %rax,-0xa20(%rbp)
 117df70:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 117df74:	88 85 e8 f5 ff ff    	mov    %al,-0xa18(%rbp)
 117df7a:	0f b6 45 c7          	movzbl -0x39(%rbp),%eax
 117df7e:	88 85 e9 f5 ff ff    	mov    %al,-0xa17(%rbp)
 117df84:	48 8d bd 88 f5 ff ff 	lea    -0xa78(%rbp),%rdi
 117df8b:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 117df92:	c5 f8 77             	vzeroupper 
 117df95:	e8 a6 06 04 00       	call   11be640 <br.encoder.command_block_split.Result.blockIndex>
 117df9a:	48 69 c0 40 08 00 00 	imul   $0x840,%rax,%rax
 117dfa1:	4c 8d 34 28          	lea    (%rax,%rbp,1),%r14
 117dfa5:	49 81 c6 50 ba fc ff 	add    $0xfffffffffffcba50,%r14
 117dfac:	31 db                	xor    %ebx,%ebx
 117dfae:	4c 8b ad 28 fd ff ff 	mov    -0x2d8(%rbp),%r13
 117dfb5:	eb 09                	jmp    117dfc0 <br.encodeCommandPlanWithOptionsWrite+0x4c20>
 117dfb7:	49 39 dd             	cmp    %rbx,%r13
 117dfba:	0f 84 a7 00 00 00    	je     117e067 <br.encodeCommandPlanWithOptionsWrite+0x4cc7>
 117dfc0:	48 8b 85 c0 fd ff ff 	mov    -0x240(%rbp),%rax
 117dfc7:	48 89 85 20 fa ff ff 	mov    %rax,-0x5e0(%rbp)
 117dfce:	48 8b 85 c8 fd ff ff 	mov    -0x238(%rbp),%rax
 117dfd5:	48 89 85 28 fa ff ff 	mov    %rax,-0x5d8(%rbp)
 117dfdc:	48 8b 85 d0 fd ff ff 	mov    -0x230(%rbp),%rax
 117dfe3:	48 89 85 30 fa ff ff 	mov    %rax,-0x5d0(%rbp)
 117dfea:	48 8b 85 d8 fd ff ff 	mov    -0x228(%rbp),%rax
 117dff1:	48 89 85 38 fa ff ff 	mov    %rax,-0x5c8(%rbp)
 117dff8:	48 8d 05 7d bd e8 ff 	lea    -0x174283(%rip),%rax        # 1009d7c <__anon_240364+0x731c>
 117dfff:	48 63 14 98          	movslq (%rax,%rbx,4),%rdx
 117e003:	48 01 c2             	add    %rax,%rdx
 117e006:	48 8d 85 20 fa ff ff 	lea    -0x5e0(%rbp),%rax
 117e00d:	48 8b 8d 38 fe ff ff 	mov    -0x1c8(%rbp),%rcx
 117e014:	ff e2                	jmp    *%rdx
 117e016:	48 8d 85 28 fa ff ff 	lea    -0x5d8(%rbp),%rax
 117e01d:	eb 10                	jmp    117e02f <br.encodeCommandPlanWithOptionsWrite+0x4c8f>
 117e01f:	48 8d 85 38 fa ff ff 	lea    -0x5c8(%rbp),%rax
 117e026:	eb 07                	jmp    117e02f <br.encodeCommandPlanWithOptionsWrite+0x4c8f>
 117e028:	48 8d 85 30 fa ff ff 	lea    -0x5d0(%rbp),%rax
 117e02f:	48 8b 08             	mov    (%rax),%rcx
 117e032:	48 ff c3             	inc    %rbx
 117e035:	48 39 8d 70 ff ff ff 	cmp    %rcx,-0x90(%rbp)
 117e03c:	0f 85 75 ff ff ff    	jne    117dfb7 <br.encodeCommandPlanWithOptionsWrite+0x4c17>
 117e042:	48 8d bd 30 ed ff ff 	lea    -0x12d0(%rbp),%rdi
 117e049:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 117e04d:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 117e051:	48 89 d9             	mov    %rbx,%rcx
 117e054:	e8 b7 37 00 00       	call   1181810 <br.CommandBlockLengthCode.writeLength>
 117e059:	66 85 c0             	test   %ax,%ax
 117e05c:	0f 84 55 ff ff ff    	je     117dfb7 <br.encodeCommandPlanWithOptionsWrite+0x4c17>
 117e062:	e9 a6 b3 ff ff       	jmp    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117e067:	49 8b 04 24          	mov    (%r12),%rax
 117e06b:	48 83 f8 01          	cmp    $0x1,%rax
 117e06f:	0f 86 f7 01 00 00    	jbe    117e26c <br.encodeCommandPlanWithOptionsWrite+0x4ecc>
 117e075:	48 83 f8 04          	cmp    $0x4,%rax
 117e079:	77 58                	ja     117e0d3 <br.encodeCommandPlanWithOptionsWrite+0x4d33>
 117e07b:	48 8d bd aa fc ff ff 	lea    -0x356(%rbp),%rdi
 117e082:	4c 89 e6             	mov    %r12,%rsi
 117e085:	48 8b 95 b8 fd ff ff 	mov    -0x248(%rbp),%rdx
 117e08c:	c5 f8 77             	vzeroupper 
 117e08f:	e8 cc 75 04 00       	call   11c5660 <br.encoder.command_plan.PrefixAlphabetFor(520).simpleCode>
 117e094:	44 0f b7 b5 aa fc ff 	movzwl -0x356(%rbp),%r14d
 117e09b:	ff 
 117e09c:	0f b6 9d ac fc ff ff 	movzbl -0x354(%rbp),%ebx
 117e0a3:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117e0a7:	f6 40 08 07          	testb  $0x7,0x8(%rax)
 117e0ab:	0f 85 85 00 00 00    	jne    117e136 <br.encodeCommandPlanWithOptionsWrite+0x4d96>
 117e0b1:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117e0b5:	48 8b 38             	mov    (%rax),%rdi
 117e0b8:	48 8b 47 08          	mov    0x8(%rdi),%rax
 117e0bc:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 117e0c0:	73 52                	jae    117e114 <br.encodeCommandPlanWithOptionsWrite+0x4d74>
 117e0c2:	48 8d 48 01          	lea    0x1(%rax),%rcx
 117e0c6:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 117e0ca:	48 8b 0f             	mov    (%rdi),%rcx
 117e0cd:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 117e0d1:	eb 63                	jmp    117e136 <br.encodeCommandPlanWithOptionsWrite+0x4d96>
 117e0d3:	48 8b 85 b8 fd ff ff 	mov    -0x248(%rbp),%rax
 117e0da:	45 0f b7 24 46       	movzwl (%r14,%rax,2),%r12d
 117e0df:	41 0f b6 9c 06 80 05 	movzbl 0x580(%r14,%rax,1),%ebx
 117e0e6:	00 00 
 117e0e8:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117e0ec:	f6 40 08 07          	testb  $0x7,0x8(%rax)
 117e0f0:	75 7b                	jne    117e16d <br.encodeCommandPlanWithOptionsWrite+0x4dcd>
 117e0f2:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117e0f6:	48 8b 38             	mov    (%rax),%rdi
 117e0f9:	48 8b 47 08          	mov    0x8(%rdi),%rax
 117e0fd:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 117e101:	73 45                	jae    117e148 <br.encodeCommandPlanWithOptionsWrite+0x4da8>
 117e103:	48 8d 48 01          	lea    0x1(%rax),%rcx
 117e107:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 117e10b:	48 8b 0f             	mov    (%rdi),%rcx
 117e10e:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 117e112:	eb 59                	jmp    117e16d <br.encodeCommandPlanWithOptionsWrite+0x4dcd>
 117e114:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117e118:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 117e11c:	0f 85 47 11 00 00    	jne    117f269 <br.encodeCommandPlanWithOptionsWrite+0x5ec9>
 117e122:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 117e126:	31 d2                	xor    %edx,%edx
 117e128:	e8 73 34 00 00       	call   11815a0 <array_list.Aligned(u8,null).append>
 117e12d:	66 85 c0             	test   %ax,%ax
 117e130:	0f 85 d7 b2 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117e136:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117e13a:	0f b6 48 08          	movzbl 0x8(%rax),%ecx
 117e13e:	80 e1 07             	and    $0x7,%cl
 117e141:	c4 c2 71 f7 f6       	shlx   %ecx,%r14d,%esi
 117e146:	eb 35                	jmp    117e17d <br.encodeCommandPlanWithOptionsWrite+0x4ddd>
 117e148:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117e14c:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 117e150:	0f 85 13 11 00 00    	jne    117f269 <br.encodeCommandPlanWithOptionsWrite+0x5ec9>
 117e156:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 117e15a:	31 d2                	xor    %edx,%edx
 117e15c:	c5 f8 77             	vzeroupper 
 117e15f:	e8 3c 34 00 00       	call   11815a0 <array_list.Aligned(u8,null).append>
 117e164:	66 85 c0             	test   %ax,%ax
 117e167:	0f 85 a0 b2 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117e16d:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117e171:	0f b6 48 08          	movzbl 0x8(%rax),%ecx
 117e175:	80 e1 07             	and    $0x7,%cl
 117e178:	c4 c2 71 f7 f4       	shlx   %ecx,%r12d,%esi
 117e17d:	48 8b 08             	mov    (%rax),%rcx
 117e180:	48 8b 11             	mov    (%rcx),%rdx
 117e183:	48 8b 49 08          	mov    0x8(%rcx),%rcx
 117e187:	40 08 74 0a ff       	or     %sil,-0x1(%rdx,%rcx,1)
 117e18c:	0f b6 40 08          	movzbl 0x8(%rax),%eax
 117e190:	24 07                	and    $0x7,%al
 117e192:	80 e3 0f             	and    $0xf,%bl
 117e195:	00 c3                	add    %al,%bl
 117e197:	80 fb 08             	cmp    $0x8,%bl
 117e19a:	0f 86 c2 00 00 00    	jbe    117e262 <br.encodeCommandPlanWithOptionsWrite+0x4ec2>
 117e1a0:	41 89 f6             	mov    %esi,%r14d
 117e1a3:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117e1a7:	48 8b 38             	mov    (%rax),%rdi
 117e1aa:	48 8b 47 08          	mov    0x8(%rdi),%rax
 117e1ae:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 117e1b2:	73 11                	jae    117e1c5 <br.encodeCommandPlanWithOptionsWrite+0x4e25>
 117e1b4:	48 8d 48 01          	lea    0x1(%rax),%rcx
 117e1b8:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 117e1bc:	48 8b 0f             	mov    (%rdi),%rcx
 117e1bf:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 117e1c3:	eb 25                	jmp    117e1ea <br.encodeCommandPlanWithOptionsWrite+0x4e4a>
 117e1c5:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117e1c9:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 117e1cd:	0f 85 96 10 00 00    	jne    117f269 <br.encodeCommandPlanWithOptionsWrite+0x5ec9>
 117e1d3:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 117e1d7:	31 d2                	xor    %edx,%edx
 117e1d9:	c5 f8 77             	vzeroupper 
 117e1dc:	e8 bf 33 00 00       	call   11815a0 <array_list.Aligned(u8,null).append>
 117e1e1:	66 85 c0             	test   %ax,%ax
 117e1e4:	0f 85 23 b2 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117e1ea:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117e1ee:	48 8b 00             	mov    (%rax),%rax
 117e1f1:	48 8b 08             	mov    (%rax),%rcx
 117e1f4:	48 8b 40 08          	mov    0x8(%rax),%rax
 117e1f8:	44 89 f2             	mov    %r14d,%edx
 117e1fb:	88 74 01 ff          	mov    %dh,-0x1(%rcx,%rax,1)
 117e1ff:	80 fb 11             	cmp    $0x11,%bl
 117e202:	72 5e                	jb     117e262 <br.encodeCommandPlanWithOptionsWrite+0x4ec2>
 117e204:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117e208:	48 8b 38             	mov    (%rax),%rdi
 117e20b:	48 8b 47 08          	mov    0x8(%rdi),%rax
 117e20f:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 117e213:	73 11                	jae    117e226 <br.encodeCommandPlanWithOptionsWrite+0x4e86>
 117e215:	48 8d 48 01          	lea    0x1(%rax),%rcx
 117e219:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 117e21d:	48 8b 0f             	mov    (%rdi),%rcx
 117e220:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 117e224:	eb 25                	jmp    117e24b <br.encodeCommandPlanWithOptionsWrite+0x4eab>
 117e226:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117e22a:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 117e22e:	0f 85 35 10 00 00    	jne    117f269 <br.encodeCommandPlanWithOptionsWrite+0x5ec9>
 117e234:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 117e238:	31 d2                	xor    %edx,%edx
 117e23a:	c5 f8 77             	vzeroupper 
 117e23d:	e8 5e 33 00 00       	call   11815a0 <array_list.Aligned(u8,null).append>
 117e242:	66 85 c0             	test   %ax,%ax
 117e245:	0f 85 c2 b1 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117e24b:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117e24f:	48 8b 00             	mov    (%rax),%rax
 117e252:	48 8b 08             	mov    (%rax),%rcx
 117e255:	48 8b 40 08          	mov    0x8(%rax),%rax
 117e259:	41 c1 ee 10          	shr    $0x10,%r14d
 117e25d:	44 88 74 01 ff       	mov    %r14b,-0x1(%rcx,%rax,1)
 117e262:	80 e3 07             	and    $0x7,%bl
 117e265:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117e269:	88 58 08             	mov    %bl,0x8(%rax)
 117e26c:	48 8b 7d a0          	mov    -0x60(%rbp),%rdi
 117e270:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 117e274:	48 8b 55 90          	mov    -0x70(%rbp),%rdx
 117e278:	48 8b 8d f8 fe ff ff 	mov    -0x108(%rbp),%rcx
 117e27f:	4c 8b 85 f0 fd ff ff 	mov    -0x210(%rbp),%r8
 117e286:	c5 f8 77             	vzeroupper 
 117e289:	e8 72 31 00 00       	call   1181400 <br.writeCommandLengthExtras>
 117e28e:	66 85 c0             	test   %ax,%ax
 117e291:	0f 85 76 b1 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117e297:	48 83 bd f8 fe ff ff 	cmpq   $0x0,-0x108(%rbp)
 117e29e:	00 
 117e29f:	0f 84 5c 07 00 00    	je     117ea01 <br.encodeCommandPlanWithOptionsWrite+0x5661>
 117e2a5:	48 8b 85 88 fd ff ff 	mov    -0x278(%rbp),%rax
 117e2ac:	48 8b 8d 78 fd ff ff 	mov    -0x288(%rbp),%rcx
 117e2b3:	48 01 c8             	add    %rcx,%rax
 117e2b6:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 117e2ba:	45 31 f6             	xor    %r14d,%r14d
 117e2bd:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 117e2c1:	0f b6 5d cf          	movzbl -0x31(%rbp),%ebx
 117e2c5:	48 8b b5 60 ff ff ff 	mov    -0xa0(%rbp),%rsi
 117e2cc:	48 8b bd 10 ff ff ff 	mov    -0xf0(%rbp),%rdi
 117e2d3:	4c 8b 85 18 ff ff ff 	mov    -0xe8(%rbp),%r8
 117e2da:	4c 8b 8d 20 ff ff ff 	mov    -0xe0(%rbp),%r9
 117e2e1:	4c 8b 95 f0 fe ff ff 	mov    -0x110(%rbp),%r10
 117e2e8:	eb 66                	jmp    117e350 <br.encodeCommandPlanWithOptionsWrite+0x4fb0>
 117e2ea:	48 8d 48 01          	lea    0x1(%rax),%rcx
 117e2ee:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 117e2f2:	48 8b 0f             	mov    (%rdi),%rcx
 117e2f5:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 117e2f9:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 117e2fd:	48 8b 01             	mov    (%rcx),%rax
 117e300:	48 8b 10             	mov    (%rax),%rdx
 117e303:	48 8b 40 08          	mov    0x8(%rax),%rax
 117e307:	41 c1 ec 10          	shr    $0x10,%r12d
 117e30b:	44 88 64 02 ff       	mov    %r12b,-0x1(%rdx,%rax,1)
 117e310:	80 e3 07             	and    $0x7,%bl
 117e313:	88 59 08             	mov    %bl,0x8(%rcx)
 117e316:	49 ff c7             	inc    %r15
 117e319:	48 8b b5 60 ff ff ff 	mov    -0xa0(%rbp),%rsi
 117e320:	48 8b bd 10 ff ff ff 	mov    -0xf0(%rbp),%rdi
 117e327:	4c 8b 85 18 ff ff ff 	mov    -0xe8(%rbp),%r8
 117e32e:	4c 8b 8d 20 ff ff ff 	mov    -0xe0(%rbp),%r9
 117e335:	4c 8b 95 f0 fe ff ff 	mov    -0x110(%rbp),%r10
 117e33c:	49 ff c6             	inc    %r14
 117e33f:	4c 3b b5 f8 fe ff ff 	cmp    -0x108(%rbp),%r14
 117e346:	0f b6 5d cf          	movzbl -0x31(%rbp),%ebx
 117e34a:	0f 84 b1 06 00 00    	je     117ea01 <br.encodeCommandPlanWithOptionsWrite+0x5661>
 117e350:	48 8b 45 90          	mov    -0x70(%rbp),%rax
 117e354:	46 0f b6 2c 30       	movzbl (%rax,%r14,1),%r13d
 117e359:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 117e35d:	74 3b                	je     117e39a <br.encodeCommandPlanWithOptionsWrite+0x4ffa>
 117e35f:	48 89 bd b0 fc ff ff 	mov    %rdi,-0x350(%rbp)
 117e366:	4c 89 85 c0 fb ff ff 	mov    %r8,-0x440(%rbp)
 117e36d:	4c 89 8d c8 fb ff ff 	mov    %r9,-0x438(%rbp)
 117e374:	4c 89 95 d0 fb ff ff 	mov    %r10,-0x430(%rbp)
 117e37b:	31 c0                	xor    %eax,%eax
 117e37d:	48 8d 0d 0c ba e8 ff 	lea    -0x1745f4(%rip),%rcx        # 1009d90 <__anon_240364+0x7330>
 117e384:	48 63 14 81          	movslq (%rcx,%rax,4),%rdx
 117e388:	48 01 ca             	add    %rcx,%rdx
 117e38b:	45 31 e4             	xor    %r12d,%r12d
 117e38e:	48 8d 85 b0 fc ff ff 	lea    -0x350(%rbp),%rax
 117e395:	48 89 f1             	mov    %rsi,%rcx
 117e398:	ff e2                	jmp    *%rdx
 117e39a:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 117e39e:	80 78 50 00          	cmpb   $0x0,0x50(%rax)
 117e3a2:	74 7a                	je     117e41e <br.encodeCommandPlanWithOptionsWrite+0x507e>
 117e3a4:	4c 89 f1             	mov    %r14,%rcx
 117e3a7:	4c 8b 20             	mov    (%rax),%r12
 117e3aa:	0f b6 40 08          	movzbl 0x8(%rax),%eax
 117e3ae:	48 8b bd 28 fc ff ff 	mov    -0x3d8(%rbp),%rdi
 117e3b5:	c5 fc 10 07          	vmovups (%rdi),%ymm0
 117e3b9:	c5 fc 10 4f 20       	vmovups 0x20(%rdi),%ymm1
 117e3be:	8b 57 40             	mov    0x40(%rdi),%edx
 117e3c1:	0f b7 77 44          	movzwl 0x44(%rdi),%esi
 117e3c5:	0f b6 7f 46          	movzbl 0x46(%rdi),%edi
 117e3c9:	40 88 bd c6 f1 ff ff 	mov    %dil,-0xe3a(%rbp)
 117e3d0:	66 89 b5 c4 f1 ff ff 	mov    %si,-0xe3c(%rbp)
 117e3d7:	89 95 c0 f1 ff ff    	mov    %edx,-0xe40(%rbp)
 117e3dd:	c5 fc 11 8d a0 f1 ff 	vmovups %ymm1,-0xe60(%rbp)
 117e3e4:	ff 
 117e3e5:	c5 fc 11 85 80 f1 ff 	vmovups %ymm0,-0xe80(%rbp)
 117e3ec:	ff 
 117e3ed:	8b 95 ec fe ff ff    	mov    -0x114(%rbp),%edx
 117e3f3:	8b b5 b4 fd ff ff    	mov    -0x24c(%rbp),%esi
 117e3f9:	89 f7                	mov    %esi,%edi
 117e3fb:	48 03 8d 78 fd ff ff 	add    -0x288(%rbp),%rcx
 117e402:	74 7e                	je     117e482 <br.encodeCommandPlanWithOptionsWrite+0x50e2>
 117e404:	48 83 f9 01          	cmp    $0x1,%rcx
 117e408:	75 67                	jne    117e471 <br.encodeCommandPlanWithOptionsWrite+0x50d1>
 117e40a:	48 8b 8d 88 fd ff ff 	mov    -0x278(%rbp),%rcx
 117e411:	0f b6 11             	movzbl (%rcx),%edx
 117e414:	8b 8d ec fe ff ff    	mov    -0x114(%rbp),%ecx
 117e41a:	89 cf                	mov    %ecx,%edi
 117e41c:	eb 64                	jmp    117e482 <br.encodeCommandPlanWithOptionsWrite+0x50e2>
 117e41e:	48 83 bd c8 d5 ff ff 	cmpq   $0x1,-0x2a38(%rbp)
 117e425:	01 
 117e426:	0f 86 ed fe ff ff    	jbe    117e319 <br.encodeCommandPlanWithOptionsWrite+0x4f79>
 117e42c:	46 0f b7 a4 6d cc b1 	movzwl -0x4e34(%rbp,%r13,2),%r12d
 117e433:	ff ff 
 117e435:	42 0f b6 9c 2d cc b3 	movzbl -0x4c34(%rbp,%r13,1),%ebx
 117e43c:	ff ff 
 117e43e:	f6 41 08 07          	testb  $0x7,0x8(%rcx)
 117e442:	0f 85 eb 01 00 00    	jne    117e633 <br.encodeCommandPlanWithOptionsWrite+0x5293>
 117e448:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117e44c:	48 8b 38             	mov    (%rax),%rdi
 117e44f:	48 8b 47 08          	mov    0x8(%rdi),%rax
 117e453:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 117e457:	0f 83 b1 01 00 00    	jae    117e60e <br.encodeCommandPlanWithOptionsWrite+0x526e>
 117e45d:	48 8d 48 01          	lea    0x1(%rax),%rcx
 117e461:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 117e465:	48 8b 0f             	mov    (%rdi),%rcx
 117e468:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 117e46c:	e9 c2 01 00 00       	jmp    117e633 <br.encodeCommandPlanWithOptionsWrite+0x5293>
 117e471:	48 8b 95 88 fd ff ff 	mov    -0x278(%rbp),%rdx
 117e478:	0f b6 7c 0a fe       	movzbl -0x2(%rdx,%rcx,1),%edi
 117e47d:	0f b6 54 0a ff       	movzbl -0x1(%rdx,%rcx,1),%edx
 117e482:	0f b6 d8             	movzbl %al,%ebx
 117e485:	0f b6 f2             	movzbl %dl,%esi
 117e488:	40 0f b6 d7          	movzbl %dil,%edx
 117e48c:	89 df                	mov    %ebx,%edi
 117e48e:	c5 f8 77             	vzeroupper 
 117e491:	e8 1a ff 03 00       	call   11be3b0 <br.encoder.literal_context.value>
 117e496:	4c 89 a5 50 fc ff ff 	mov    %r12,-0x3b0(%rbp)
 117e49d:	88 9d 58 fc ff ff    	mov    %bl,-0x3a8(%rbp)
 117e4a3:	48 8b 8d bf f1 ff ff 	mov    -0xe41(%rbp),%rcx
 117e4aa:	48 8d 95 59 fc ff ff 	lea    -0x3a7(%rbp),%rdx
 117e4b1:	48 89 4a 3f          	mov    %rcx,0x3f(%rdx)
 117e4b5:	c5 fc 10 85 80 f1 ff 	vmovups -0xe80(%rbp),%ymm0
 117e4bc:	ff 
 117e4bd:	c5 fc 10 8d a0 f1 ff 	vmovups -0xe60(%rbp),%ymm1
 117e4c4:	ff 
 117e4c5:	c5 fc 11 4a 20       	vmovups %ymm1,0x20(%rdx)
 117e4ca:	c5 fc 11 02          	vmovups %ymm0,(%rdx)
 117e4ce:	0f b6 84 05 5a fc ff 	movzbl -0x3a6(%rbp,%rax,1),%eax
 117e4d5:	ff 
 117e4d6:	48 8d 04 40          	lea    (%rax,%rax,2),%rax
 117e4da:	c1 e0 08             	shl    $0x8,%eax
 117e4dd:	48 01 e8             	add    %rbp,%rax
 117e4e0:	48 05 d0 c8 f9 ff    	add    $0xfffffffffff9c8d0,%rax
 117e4e6:	41 0f b6 9c 05 00 02 	movzbl 0x200(%r13,%rax,1),%ebx
 117e4ed:	00 00 
 117e4ef:	f6 c3 0f             	test   $0xf,%bl
 117e4f2:	74 31                	je     117e525 <br.encodeCommandPlanWithOptionsWrite+0x5185>
 117e4f4:	46 0f b7 24 68       	movzwl (%rax,%r13,2),%r12d
 117e4f9:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 117e4fd:	f6 41 08 07          	testb  $0x7,0x8(%rcx)
 117e501:	75 54                	jne    117e557 <br.encodeCommandPlanWithOptionsWrite+0x51b7>
 117e503:	48 8b 39             	mov    (%rcx),%rdi
 117e506:	48 8b 47 08          	mov    0x8(%rdi),%rax
 117e50a:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 117e50e:	73 1e                	jae    117e52e <br.encodeCommandPlanWithOptionsWrite+0x518e>
 117e510:	48 8d 48 01          	lea    0x1(%rax),%rcx
 117e514:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 117e518:	48 8b 0f             	mov    (%rdi),%rcx
 117e51b:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 117e51f:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 117e523:	eb 32                	jmp    117e557 <br.encodeCommandPlanWithOptionsWrite+0x51b7>
 117e525:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 117e529:	e9 eb fd ff ff       	jmp    117e319 <br.encodeCommandPlanWithOptionsWrite+0x4f79>
 117e52e:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117e532:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 117e536:	0f 85 2d 0d 00 00    	jne    117f269 <br.encodeCommandPlanWithOptionsWrite+0x5ec9>
 117e53c:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 117e540:	31 d2                	xor    %edx,%edx
 117e542:	c5 f8 77             	vzeroupper 
 117e545:	e8 56 30 00 00       	call   11815a0 <array_list.Aligned(u8,null).append>
 117e54a:	66 85 c0             	test   %ax,%ax
 117e54d:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 117e551:	0f 85 b6 ae ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117e557:	0f b6 41 08          	movzbl 0x8(%rcx),%eax
 117e55b:	24 07                	and    $0x7,%al
 117e55d:	c4 c2 79 f7 f4       	shlx   %eax,%r12d,%esi
 117e562:	48 8b 01             	mov    (%rcx),%rax
 117e565:	48 8b 10             	mov    (%rax),%rdx
 117e568:	48 8b 40 08          	mov    0x8(%rax),%rax
 117e56c:	40 08 74 02 ff       	or     %sil,-0x1(%rdx,%rax,1)
 117e571:	0f b6 41 08          	movzbl 0x8(%rcx),%eax
 117e575:	24 07                	and    $0x7,%al
 117e577:	80 e3 0f             	and    $0xf,%bl
 117e57a:	00 c3                	add    %al,%bl
 117e57c:	80 fb 08             	cmp    $0x8,%bl
 117e57f:	0f 86 8d 01 00 00    	jbe    117e712 <br.encodeCommandPlanWithOptionsWrite+0x5372>
 117e585:	41 89 f4             	mov    %esi,%r12d
 117e588:	48 8b 39             	mov    (%rcx),%rdi
 117e58b:	48 8b 47 08          	mov    0x8(%rdi),%rax
 117e58f:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 117e593:	73 11                	jae    117e5a6 <br.encodeCommandPlanWithOptionsWrite+0x5206>
 117e595:	48 8d 48 01          	lea    0x1(%rax),%rcx
 117e599:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 117e59d:	48 8b 0f             	mov    (%rdi),%rcx
 117e5a0:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 117e5a4:	eb 25                	jmp    117e5cb <br.encodeCommandPlanWithOptionsWrite+0x522b>
 117e5a6:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117e5aa:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 117e5ae:	0f 85 b5 0c 00 00    	jne    117f269 <br.encodeCommandPlanWithOptionsWrite+0x5ec9>
 117e5b4:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 117e5b8:	31 d2                	xor    %edx,%edx
 117e5ba:	c5 f8 77             	vzeroupper 
 117e5bd:	e8 de 2f 00 00       	call   11815a0 <array_list.Aligned(u8,null).append>
 117e5c2:	66 85 c0             	test   %ax,%ax
 117e5c5:	0f 85 42 ae ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117e5cb:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 117e5cf:	48 8b 01             	mov    (%rcx),%rax
 117e5d2:	48 8b 30             	mov    (%rax),%rsi
 117e5d5:	48 8b 40 08          	mov    0x8(%rax),%rax
 117e5d9:	44 89 e2             	mov    %r12d,%edx
 117e5dc:	88 74 06 ff          	mov    %dh,-0x1(%rsi,%rax,1)
 117e5e0:	80 fb 11             	cmp    $0x11,%bl
 117e5e3:	0f 82 29 01 00 00    	jb     117e712 <br.encodeCommandPlanWithOptionsWrite+0x5372>
 117e5e9:	48 8b 39             	mov    (%rcx),%rdi
 117e5ec:	48 8b 47 08          	mov    0x8(%rdi),%rax
 117e5f0:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 117e5f4:	0f 83 dc 00 00 00    	jae    117e6d6 <br.encodeCommandPlanWithOptionsWrite+0x5336>
 117e5fa:	48 8d 48 01          	lea    0x1(%rax),%rcx
 117e5fe:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 117e602:	48 8b 0f             	mov    (%rdi),%rcx
 117e605:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 117e609:	e9 ed 00 00 00       	jmp    117e6fb <br.encodeCommandPlanWithOptionsWrite+0x535b>
 117e60e:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117e612:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 117e616:	0f 85 4d 0c 00 00    	jne    117f269 <br.encodeCommandPlanWithOptionsWrite+0x5ec9>
 117e61c:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 117e620:	31 d2                	xor    %edx,%edx
 117e622:	c5 f8 77             	vzeroupper 
 117e625:	e8 76 2f 00 00       	call   11815a0 <array_list.Aligned(u8,null).append>
 117e62a:	66 85 c0             	test   %ax,%ax
 117e62d:	0f 85 da ad ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117e633:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 117e637:	0f b6 41 08          	movzbl 0x8(%rcx),%eax
 117e63b:	24 07                	and    $0x7,%al
 117e63d:	c4 c2 79 f7 f4       	shlx   %eax,%r12d,%esi
 117e642:	48 8b 01             	mov    (%rcx),%rax
 117e645:	48 8b 10             	mov    (%rax),%rdx
 117e648:	48 8b 40 08          	mov    0x8(%rax),%rax
 117e64c:	40 08 74 02 ff       	or     %sil,-0x1(%rdx,%rax,1)
 117e651:	0f b6 41 08          	movzbl 0x8(%rcx),%eax
 117e655:	24 07                	and    $0x7,%al
 117e657:	80 e3 0f             	and    $0xf,%bl
 117e65a:	00 c3                	add    %al,%bl
 117e65c:	80 fb 08             	cmp    $0x8,%bl
 117e65f:	0f 86 ad 00 00 00    	jbe    117e712 <br.encodeCommandPlanWithOptionsWrite+0x5372>
 117e665:	41 89 f4             	mov    %esi,%r12d
 117e668:	48 8b 39             	mov    (%rcx),%rdi
 117e66b:	48 8b 47 08          	mov    0x8(%rdi),%rax
 117e66f:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 117e673:	73 11                	jae    117e686 <br.encodeCommandPlanWithOptionsWrite+0x52e6>
 117e675:	48 8d 48 01          	lea    0x1(%rax),%rcx
 117e679:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 117e67d:	48 8b 0f             	mov    (%rdi),%rcx
 117e680:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 117e684:	eb 25                	jmp    117e6ab <br.encodeCommandPlanWithOptionsWrite+0x530b>
 117e686:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117e68a:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 117e68e:	0f 85 d5 0b 00 00    	jne    117f269 <br.encodeCommandPlanWithOptionsWrite+0x5ec9>
 117e694:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 117e698:	31 d2                	xor    %edx,%edx
 117e69a:	c5 f8 77             	vzeroupper 
 117e69d:	e8 fe 2e 00 00       	call   11815a0 <array_list.Aligned(u8,null).append>
 117e6a2:	66 85 c0             	test   %ax,%ax
 117e6a5:	0f 85 62 ad ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117e6ab:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 117e6af:	48 8b 01             	mov    (%rcx),%rax
 117e6b2:	48 8b 30             	mov    (%rax),%rsi
 117e6b5:	48 8b 40 08          	mov    0x8(%rax),%rax
 117e6b9:	44 89 e2             	mov    %r12d,%edx
 117e6bc:	88 74 06 ff          	mov    %dh,-0x1(%rsi,%rax,1)
 117e6c0:	80 fb 11             	cmp    $0x11,%bl
 117e6c3:	72 4d                	jb     117e712 <br.encodeCommandPlanWithOptionsWrite+0x5372>
 117e6c5:	48 8b 39             	mov    (%rcx),%rdi
 117e6c8:	48 8b 47 08          	mov    0x8(%rdi),%rax
 117e6cc:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 117e6d0:	0f 82 24 ff ff ff    	jb     117e5fa <br.encodeCommandPlanWithOptionsWrite+0x525a>
 117e6d6:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117e6da:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 117e6de:	0f 85 85 0b 00 00    	jne    117f269 <br.encodeCommandPlanWithOptionsWrite+0x5ec9>
 117e6e4:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 117e6e8:	31 d2                	xor    %edx,%edx
 117e6ea:	c5 f8 77             	vzeroupper 
 117e6ed:	e8 ae 2e 00 00       	call   11815a0 <array_list.Aligned(u8,null).append>
 117e6f2:	66 85 c0             	test   %ax,%ax
 117e6f5:	0f 85 12 ad ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117e6fb:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 117e6ff:	48 8b 01             	mov    (%rcx),%rax
 117e702:	48 8b 10             	mov    (%rax),%rdx
 117e705:	48 8b 40 08          	mov    0x8(%rax),%rax
 117e709:	41 c1 ec 10          	shr    $0x10,%r12d
 117e70d:	44 88 64 02 ff       	mov    %r12b,-0x1(%rdx,%rax,1)
 117e712:	80 e3 07             	and    $0x7,%bl
 117e715:	88 59 08             	mov    %bl,0x8(%rcx)
 117e718:	e9 fc fb ff ff       	jmp    117e319 <br.encodeCommandPlanWithOptionsWrite+0x4f79>
 117e71d:	48 8d 85 c0 fb ff ff 	lea    -0x440(%rbp),%rax
 117e724:	eb 10                	jmp    117e736 <br.encodeCommandPlanWithOptionsWrite+0x5396>
 117e726:	48 8d 85 c8 fb ff ff 	lea    -0x438(%rbp),%rax
 117e72d:	eb 07                	jmp    117e736 <br.encodeCommandPlanWithOptionsWrite+0x5396>
 117e72f:	48 8d 85 d0 fb ff ff 	lea    -0x430(%rbp),%rax
 117e736:	48 8b 08             	mov    (%rax),%rcx
 117e739:	49 ff c4             	inc    %r12
 117e73c:	49 39 cf             	cmp    %rcx,%r15
 117e73f:	75 46                	jne    117e787 <br.encodeCommandPlanWithOptionsWrite+0x53e7>
 117e741:	48 8d bd a0 e8 ff ff 	lea    -0x1760(%rbp),%rdi
 117e748:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 117e74c:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 117e750:	4c 89 e1             	mov    %r12,%rcx
 117e753:	c5 f8 77             	vzeroupper 
 117e756:	e8 b5 30 00 00       	call   1181810 <br.CommandBlockLengthCode.writeLength>
 117e75b:	4c 8b 95 f0 fe ff ff 	mov    -0x110(%rbp),%r10
 117e762:	4c 8b 8d 20 ff ff ff 	mov    -0xe0(%rbp),%r9
 117e769:	4c 8b 85 18 ff ff ff 	mov    -0xe8(%rbp),%r8
 117e770:	48 8b bd 10 ff ff ff 	mov    -0xf0(%rbp),%rdi
 117e777:	48 8b b5 60 ff ff ff 	mov    -0xa0(%rbp),%rsi
 117e77e:	66 85 c0             	test   %ax,%ax
 117e781:	0f 85 86 ac ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117e787:	4c 39 a5 50 fe ff ff 	cmp    %r12,-0x1b0(%rbp)
 117e78e:	74 36                	je     117e7c6 <br.encodeCommandPlanWithOptionsWrite+0x5426>
 117e790:	48 89 bd b0 fc ff ff 	mov    %rdi,-0x350(%rbp)
 117e797:	4c 89 85 c0 fb ff ff 	mov    %r8,-0x440(%rbp)
 117e79e:	4c 89 8d c8 fb ff ff 	mov    %r9,-0x438(%rbp)
 117e7a5:	4c 89 95 d0 fb ff ff 	mov    %r10,-0x430(%rbp)
 117e7ac:	48 8d 05 dd b5 e8 ff 	lea    -0x174a23(%rip),%rax        # 1009d90 <__anon_240364+0x7330>
 117e7b3:	4a 63 14 a0          	movslq (%rax,%r12,4),%rdx
 117e7b7:	48 01 c2             	add    %rax,%rdx
 117e7ba:	48 8d 85 b0 fc ff ff 	lea    -0x350(%rbp),%rax
 117e7c1:	48 89 f1             	mov    %rsi,%rcx
 117e7c4:	ff e2                	jmp    *%rdx
 117e7c6:	48 89 b5 20 f5 ff ff 	mov    %rsi,-0xae0(%rbp)
 117e7cd:	48 89 bd 28 f5 ff ff 	mov    %rdi,-0xad8(%rbp)
 117e7d4:	0f b6 45 c5          	movzbl -0x3b(%rbp),%eax
 117e7d8:	88 85 30 f5 ff ff    	mov    %al,-0xad0(%rbp)
 117e7de:	8b 85 07 fe ff ff    	mov    -0x1f9(%rbp),%eax
 117e7e4:	48 8d 8d 31 f5 ff ff 	lea    -0xacf(%rbp),%rcx
 117e7eb:	89 41 03             	mov    %eax,0x3(%rcx)
 117e7ee:	8b 85 04 fe ff ff    	mov    -0x1fc(%rbp),%eax
 117e7f4:	89 01                	mov    %eax,(%rcx)
 117e7f6:	4c 89 85 38 f5 ff ff 	mov    %r8,-0xac8(%rbp)
 117e7fd:	88 9d 40 f5 ff ff    	mov    %bl,-0xac0(%rbp)
 117e803:	8b 85 0f fe ff ff    	mov    -0x1f1(%rbp),%eax
 117e809:	89 41 13             	mov    %eax,0x13(%rcx)
 117e80c:	8b 85 0c fe ff ff    	mov    -0x1f4(%rbp),%eax
 117e812:	89 41 10             	mov    %eax,0x10(%rcx)
 117e815:	4c 89 8d 48 f5 ff ff 	mov    %r9,-0xab8(%rbp)
 117e81c:	0f b6 45 d1          	movzbl -0x2f(%rbp),%eax
 117e820:	88 85 50 f5 ff ff    	mov    %al,-0xab0(%rbp)
 117e826:	8b 85 17 fe ff ff    	mov    -0x1e9(%rbp),%eax
 117e82c:	89 41 23             	mov    %eax,0x23(%rcx)
 117e82f:	8b 85 14 fe ff ff    	mov    -0x1ec(%rbp),%eax
 117e835:	89 41 20             	mov    %eax,0x20(%rcx)
 117e838:	4c 89 95 58 f5 ff ff 	mov    %r10,-0xaa8(%rbp)
 117e83f:	0f b6 45 ca          	movzbl -0x36(%rbp),%eax
 117e843:	88 85 60 f5 ff ff    	mov    %al,-0xaa0(%rbp)
 117e849:	8b 85 1f fe ff ff    	mov    -0x1e1(%rbp),%eax
 117e84f:	89 41 33             	mov    %eax,0x33(%rcx)
 117e852:	8b 85 1c fe ff ff    	mov    -0x1e4(%rbp),%eax
 117e858:	89 41 30             	mov    %eax,0x30(%rcx)
 117e85b:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 117e862:	48 89 85 68 f5 ff ff 	mov    %rax,-0xa98(%rbp)
 117e869:	0f b6 45 c0          	movzbl -0x40(%rbp),%eax
 117e86d:	88 85 70 f5 ff ff    	mov    %al,-0xa90(%rbp)
 117e873:	8b 85 27 fe ff ff    	mov    -0x1d9(%rbp),%eax
 117e879:	89 41 43             	mov    %eax,0x43(%rcx)
 117e87c:	8b 85 24 fe ff ff    	mov    -0x1dc(%rbp),%eax
 117e882:	89 41 40             	mov    %eax,0x40(%rcx)
 117e885:	48 8b 85 00 fd ff ff 	mov    -0x300(%rbp),%rax
 117e88c:	48 89 85 78 f5 ff ff 	mov    %rax,-0xa88(%rbp)
 117e893:	0f b6 45 c9          	movzbl -0x37(%rbp),%eax
 117e897:	88 85 80 f5 ff ff    	mov    %al,-0xa80(%rbp)
 117e89d:	0f b6 45 c2          	movzbl -0x3e(%rbp),%eax
 117e8a1:	88 85 81 f5 ff ff    	mov    %al,-0xa7f(%rbp)
 117e8a7:	0f b7 85 4c fe ff ff 	movzwl -0x1b4(%rbp),%eax
 117e8ae:	66 89 41 55          	mov    %ax,0x55(%rcx)
 117e8b2:	8b 85 48 fe ff ff    	mov    -0x1b8(%rbp),%eax
 117e8b8:	89 41 51             	mov    %eax,0x51(%rcx)
 117e8bb:	48 8d bd 20 f5 ff ff 	lea    -0xae0(%rbp),%rdi
 117e8c2:	4c 89 fe             	mov    %r15,%rsi
 117e8c5:	c5 f8 77             	vzeroupper 
 117e8c8:	e8 83 f6 03 00       	call   11bdf50 <br.encoder.distance_block_split.Result.blockIndex>
 117e8cd:	48 8d 04 40          	lea    (%rax,%rax,2),%rax
 117e8d1:	c1 e0 08             	shl    $0x8,%eax
 117e8d4:	48 01 e8             	add    %rbp,%rax
 117e8d7:	48 05 d4 43 fe ff    	add    $0xfffffffffffe43d4,%rax
 117e8dd:	41 0f b6 9c 05 00 02 	movzbl 0x200(%r13,%rax,1),%ebx
 117e8e4:	00 00 
 117e8e6:	f6 c3 0f             	test   $0xf,%bl
 117e8e9:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 117e8ed:	0f 84 23 fa ff ff    	je     117e316 <br.encodeCommandPlanWithOptionsWrite+0x4f76>
 117e8f3:	46 0f b7 24 68       	movzwl (%rax,%r13,2),%r12d
 117e8f8:	f6 41 08 07          	testb  $0x7,0x8(%rcx)
 117e8fc:	75 40                	jne    117e93e <br.encodeCommandPlanWithOptionsWrite+0x559e>
 117e8fe:	48 8b 39             	mov    (%rcx),%rdi
 117e901:	48 8b 47 08          	mov    0x8(%rdi),%rax
 117e905:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 117e909:	73 11                	jae    117e91c <br.encodeCommandPlanWithOptionsWrite+0x557c>
 117e90b:	48 8d 50 01          	lea    0x1(%rax),%rdx
 117e90f:	48 89 57 08          	mov    %rdx,0x8(%rdi)
 117e913:	48 8b 17             	mov    (%rdi),%rdx
 117e916:	c6 04 02 00          	movb   $0x0,(%rdx,%rax,1)
 117e91a:	eb 22                	jmp    117e93e <br.encodeCommandPlanWithOptionsWrite+0x559e>
 117e91c:	80 79 09 00          	cmpb   $0x0,0x9(%rcx)
 117e920:	0f 85 43 09 00 00    	jne    117f269 <br.encodeCommandPlanWithOptionsWrite+0x5ec9>
 117e926:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 117e92a:	31 d2                	xor    %edx,%edx
 117e92c:	e8 6f 2c 00 00       	call   11815a0 <array_list.Aligned(u8,null).append>
 117e931:	66 85 c0             	test   %ax,%ax
 117e934:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 117e938:	0f 85 cf aa ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117e93e:	0f b6 41 08          	movzbl 0x8(%rcx),%eax
 117e942:	24 07                	and    $0x7,%al
 117e944:	c4 c2 79 f7 f4       	shlx   %eax,%r12d,%esi
 117e949:	48 8b 01             	mov    (%rcx),%rax
 117e94c:	48 8b 10             	mov    (%rax),%rdx
 117e94f:	48 8b 40 08          	mov    0x8(%rax),%rax
 117e953:	40 08 74 02 ff       	or     %sil,-0x1(%rdx,%rax,1)
 117e958:	0f b6 41 08          	movzbl 0x8(%rcx),%eax
 117e95c:	24 07                	and    $0x7,%al
 117e95e:	80 e3 0f             	and    $0xf,%bl
 117e961:	00 c3                	add    %al,%bl
 117e963:	80 fb 08             	cmp    $0x8,%bl
 117e966:	0f 86 a4 f9 ff ff    	jbe    117e310 <br.encodeCommandPlanWithOptionsWrite+0x4f70>
 117e96c:	41 89 f4             	mov    %esi,%r12d
 117e96f:	48 8b 39             	mov    (%rcx),%rdi
 117e972:	48 8b 47 08          	mov    0x8(%rdi),%rax
 117e976:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 117e97a:	73 11                	jae    117e98d <br.encodeCommandPlanWithOptionsWrite+0x55ed>
 117e97c:	48 8d 48 01          	lea    0x1(%rax),%rcx
 117e980:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 117e984:	48 8b 0f             	mov    (%rdi),%rcx
 117e987:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 117e98b:	eb 1e                	jmp    117e9ab <br.encodeCommandPlanWithOptionsWrite+0x560b>
 117e98d:	80 79 09 00          	cmpb   $0x0,0x9(%rcx)
 117e991:	0f 85 d2 08 00 00    	jne    117f269 <br.encodeCommandPlanWithOptionsWrite+0x5ec9>
 117e997:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 117e99b:	31 d2                	xor    %edx,%edx
 117e99d:	e8 fe 2b 00 00       	call   11815a0 <array_list.Aligned(u8,null).append>
 117e9a2:	66 85 c0             	test   %ax,%ax
 117e9a5:	0f 85 62 aa ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117e9ab:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 117e9af:	48 8b 01             	mov    (%rcx),%rax
 117e9b2:	48 8b 30             	mov    (%rax),%rsi
 117e9b5:	48 8b 40 08          	mov    0x8(%rax),%rax
 117e9b9:	44 89 e2             	mov    %r12d,%edx
 117e9bc:	88 74 06 ff          	mov    %dh,-0x1(%rsi,%rax,1)
 117e9c0:	80 fb 11             	cmp    $0x11,%bl
 117e9c3:	0f 82 47 f9 ff ff    	jb     117e310 <br.encodeCommandPlanWithOptionsWrite+0x4f70>
 117e9c9:	48 8b 39             	mov    (%rcx),%rdi
 117e9cc:	48 8b 47 08          	mov    0x8(%rdi),%rax
 117e9d0:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 117e9d4:	0f 82 10 f9 ff ff    	jb     117e2ea <br.encodeCommandPlanWithOptionsWrite+0x4f4a>
 117e9da:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117e9de:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 117e9e2:	0f 85 81 08 00 00    	jne    117f269 <br.encodeCommandPlanWithOptionsWrite+0x5ec9>
 117e9e8:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 117e9ec:	31 d2                	xor    %edx,%edx
 117e9ee:	e8 ad 2b 00 00       	call   11815a0 <array_list.Aligned(u8,null).append>
 117e9f3:	66 85 c0             	test   %ax,%ax
 117e9f6:	0f 84 fd f8 ff ff    	je     117e2f9 <br.encodeCommandPlanWithOptionsWrite+0x4f59>
 117e9fc:	e9 0c aa ff ff       	jmp    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117ea01:	f6 45 8c 01          	testb  $0x1,-0x74(%rbp)
 117ea05:	0f 84 6a 06 00 00    	je     117f075 <br.encodeCommandPlanWithOptionsWrite+0x5cd5>
 117ea0b:	0f b6 45 b6          	movzbl -0x4a(%rbp),%eax
 117ea0f:	24 03                	and    $0x3,%al
 117ea11:	3c 03                	cmp    $0x3,%al
 117ea13:	0f 85 5c 06 00 00    	jne    117f075 <br.encodeCommandPlanWithOptionsWrite+0x5cd5>
 117ea19:	80 bd 80 fd ff ff 00 	cmpb   $0x0,-0x280(%rbp)
 117ea20:	74 2f                	je     117ea51 <br.encodeCommandPlanWithOptionsWrite+0x56b1>
 117ea22:	80 bd 98 fd ff ff 00 	cmpb   $0x0,-0x268(%rbp)
 117ea29:	0f 84 68 b1 ff ff    	je     1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117ea2f:	48 8b 85 90 fd ff ff 	mov    -0x270(%rbp),%rax
 117ea36:	48 89 c1             	mov    %rax,%rcx
 117ea39:	48 c1 e9 30          	shr    $0x30,%rcx
 117ea3d:	48 89 8d f8 fe ff ff 	mov    %rcx,-0x108(%rbp)
 117ea44:	48 c1 e8 20          	shr    $0x20,%rax
 117ea48:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 117ea4c:	e9 85 00 00 00       	jmp    117ead6 <br.encodeCommandPlanWithOptionsWrite+0x5736>
 117ea51:	48 8b 85 40 fe ff ff 	mov    -0x1c0(%rbp),%rax
 117ea58:	80 38 00             	cmpb   $0x0,(%rax)
 117ea5b:	74 30                	je     117ea8d <br.encodeCommandPlanWithOptionsWrite+0x56ed>
 117ea5d:	48 8b 85 d0 fe ff ff 	mov    -0x130(%rbp),%rax
 117ea64:	0f b6 00             	movzbl (%rax),%eax
 117ea67:	83 e0 0f             	and    $0xf,%eax
 117ea6a:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 117ea6e:	c6 85 aa fd ff ff 00 	movb   $0x0,-0x256(%rbp)
 117ea75:	48 c7 85 f8 fe ff ff 	movq   $0x0,-0x108(%rbp)
 117ea7c:	00 00 00 00 
 117ea80:	48 c7 85 90 fd ff ff 	movq   $0x0,-0x270(%rbp)
 117ea87:	00 00 00 00 
 117ea8b:	eb 49                	jmp    117ead6 <br.encodeCommandPlanWithOptionsWrite+0x5736>
 117ea8d:	48 8d bd d0 f7 ff ff 	lea    -0x830(%rbp),%rdi
 117ea94:	48 8b b5 00 ff ff ff 	mov    -0x100(%rbp),%rsi
 117ea9b:	8b 95 2c fe ff ff    	mov    -0x1d4(%rbp),%edx
 117eaa1:	8b 8d 30 fe ff ff    	mov    -0x1d0(%rbp),%ecx
 117eaa7:	45 31 c0             	xor    %r8d,%r8d
 117eaaa:	c5 f8 77             	vzeroupper 
 117eaad:	e8 2e f6 03 00       	call   11be0e0 <br.encoder.distance.encodeWithFormat>
 117eab2:	48 8b 8d d0 f7 ff ff 	mov    -0x830(%rbp),%rcx
 117eab9:	48 89 c8             	mov    %rcx,%rax
 117eabc:	48 c1 e8 20          	shr    $0x20,%rax
 117eac0:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 117eac4:	48 89 8d 90 fd ff ff 	mov    %rcx,-0x270(%rbp)
 117eacb:	48 c1 e9 30          	shr    $0x30,%rcx
 117eacf:	48 89 8d f8 fe ff ff 	mov    %rcx,-0x108(%rbp)
 117ead6:	4c 8d a5 d0 f0 ff ff 	lea    -0xf30(%rbp),%r12
 117eadd:	80 7d cc 00          	cmpb   $0x0,-0x34(%rbp)
 117eae1:	0f 84 44 01 00 00    	je     117ec2b <br.encodeCommandPlanWithOptionsWrite+0x588b>
 117eae7:	8b 85 a3 fe ff ff    	mov    -0x15d(%rbp),%eax
 117eaed:	48 8d 8d c9 f4 ff ff 	lea    -0xb37(%rbp),%rcx
 117eaf4:	89 41 03             	mov    %eax,0x3(%rcx)
 117eaf7:	8b 85 a0 fe ff ff    	mov    -0x160(%rbp),%eax
 117eafd:	89 01                	mov    %eax,(%rcx)
 117eaff:	8b 85 ab fe ff ff    	mov    -0x155(%rbp),%eax
 117eb05:	89 41 13             	mov    %eax,0x13(%rcx)
 117eb08:	8b 85 a8 fe ff ff    	mov    -0x158(%rbp),%eax
 117eb0e:	89 41 10             	mov    %eax,0x10(%rcx)
 117eb11:	8b 85 b3 fe ff ff    	mov    -0x14d(%rbp),%eax
 117eb17:	89 41 23             	mov    %eax,0x23(%rcx)
 117eb1a:	8b 85 b0 fe ff ff    	mov    -0x150(%rbp),%eax
 117eb20:	89 41 20             	mov    %eax,0x20(%rcx)
 117eb23:	8b 85 bb fe ff ff    	mov    -0x145(%rbp),%eax
 117eb29:	89 41 33             	mov    %eax,0x33(%rcx)
 117eb2c:	8b 85 b8 fe ff ff    	mov    -0x148(%rbp),%eax
 117eb32:	89 41 30             	mov    %eax,0x30(%rcx)
 117eb35:	8b 85 c3 fe ff ff    	mov    -0x13d(%rbp),%eax
 117eb3b:	89 41 43             	mov    %eax,0x43(%rcx)
 117eb3e:	8b 85 c0 fe ff ff    	mov    -0x140(%rbp),%eax
 117eb44:	89 41 40             	mov    %eax,0x40(%rcx)
 117eb47:	0f b7 85 e8 fe ff ff 	movzwl -0x118(%rbp),%eax
 117eb4e:	66 89 41 55          	mov    %ax,0x55(%rcx)
 117eb52:	8b 85 e4 fe ff ff    	mov    -0x11c(%rbp),%eax
 117eb58:	89 41 51             	mov    %eax,0x51(%rcx)
 117eb5b:	48 8b 85 c8 fe ff ff 	mov    -0x138(%rbp),%rax
 117eb62:	48 89 85 b8 f4 ff ff 	mov    %rax,-0xb48(%rbp)
 117eb69:	48 8b 85 58 fe ff ff 	mov    -0x1a8(%rbp),%rax
 117eb70:	48 89 85 c0 f4 ff ff 	mov    %rax,-0xb40(%rbp)
 117eb77:	0f b6 45 d5          	movzbl -0x2b(%rbp),%eax
 117eb7b:	88 85 c8 f4 ff ff    	mov    %al,-0xb38(%rbp)
 117eb81:	48 8b 85 60 fe ff ff 	mov    -0x1a0(%rbp),%rax
 117eb88:	48 89 85 d0 f4 ff ff 	mov    %rax,-0xb30(%rbp)
 117eb8f:	0f b6 45 d4          	movzbl -0x2c(%rbp),%eax
 117eb93:	88 85 d8 f4 ff ff    	mov    %al,-0xb28(%rbp)
 117eb99:	48 8b 85 68 fe ff ff 	mov    -0x198(%rbp),%rax
 117eba0:	48 89 85 e0 f4 ff ff 	mov    %rax,-0xb20(%rbp)
 117eba7:	0f b6 45 d7          	movzbl -0x29(%rbp),%eax
 117ebab:	88 85 e8 f4 ff ff    	mov    %al,-0xb18(%rbp)
 117ebb1:	48 8b 85 70 fe ff ff 	mov    -0x190(%rbp),%rax
 117ebb8:	48 89 85 f0 f4 ff ff 	mov    %rax,-0xb10(%rbp)
 117ebbf:	0f b6 45 ce          	movzbl -0x32(%rbp),%eax
 117ebc3:	88 85 f8 f4 ff ff    	mov    %al,-0xb08(%rbp)
 117ebc9:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 117ebd0:	48 89 85 00 f5 ff ff 	mov    %rax,-0xb00(%rbp)
 117ebd7:	0f b6 45 c4          	movzbl -0x3c(%rbp),%eax
 117ebdb:	88 85 08 f5 ff ff    	mov    %al,-0xaf8(%rbp)
 117ebe1:	48 8b 85 20 fd ff ff 	mov    -0x2e0(%rbp),%rax
 117ebe8:	48 89 85 10 f5 ff ff 	mov    %rax,-0xaf0(%rbp)
 117ebef:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 117ebf3:	88 85 18 f5 ff ff    	mov    %al,-0xae8(%rbp)
 117ebf9:	0f b6 45 c8          	movzbl -0x38(%rbp),%eax
 117ebfd:	88 85 19 f5 ff ff    	mov    %al,-0xae7(%rbp)
 117ec03:	48 8d bd b8 f4 ff ff 	lea    -0xb48(%rbp),%rdi
 117ec0a:	48 8b b5 e0 fd ff ff 	mov    -0x220(%rbp),%rsi
 117ec11:	c5 f8 77             	vzeroupper 
 117ec14:	e8 37 f3 03 00       	call   11bdf50 <br.encoder.distance_block_split.Result.blockIndex>
 117ec19:	48 69 c0 a8 00 00 00 	imul   $0xa8,%rax,%rax
 117ec20:	4c 8d 24 28          	lea    (%rax,%rbp,1),%r12
 117ec24:	49 81 c4 38 cb ff ff 	add    $0xffffffffffffcb38,%r12
 117ec2b:	4c 8d b5 80 ee ff ff 	lea    -0x1180(%rbp),%r14
 117ec32:	80 7d cc 00          	cmpb   $0x0,-0x34(%rbp)
 117ec36:	0f 84 ff 01 00 00    	je     117ee3b <br.encodeCommandPlanWithOptionsWrite+0x5a9b>
 117ec3c:	8b 85 a3 fe ff ff    	mov    -0x15d(%rbp),%eax
 117ec42:	48 8d 8d 61 f4 ff ff 	lea    -0xb9f(%rbp),%rcx
 117ec49:	89 41 03             	mov    %eax,0x3(%rcx)
 117ec4c:	8b 85 a0 fe ff ff    	mov    -0x160(%rbp),%eax
 117ec52:	89 01                	mov    %eax,(%rcx)
 117ec54:	8b 85 ab fe ff ff    	mov    -0x155(%rbp),%eax
 117ec5a:	89 41 13             	mov    %eax,0x13(%rcx)
 117ec5d:	8b 85 a8 fe ff ff    	mov    -0x158(%rbp),%eax
 117ec63:	89 41 10             	mov    %eax,0x10(%rcx)
 117ec66:	8b 85 b3 fe ff ff    	mov    -0x14d(%rbp),%eax
 117ec6c:	89 41 23             	mov    %eax,0x23(%rcx)
 117ec6f:	8b 85 b0 fe ff ff    	mov    -0x150(%rbp),%eax
 117ec75:	89 41 20             	mov    %eax,0x20(%rcx)
 117ec78:	8b 85 bb fe ff ff    	mov    -0x145(%rbp),%eax
 117ec7e:	89 41 33             	mov    %eax,0x33(%rcx)
 117ec81:	8b 85 b8 fe ff ff    	mov    -0x148(%rbp),%eax
 117ec87:	89 41 30             	mov    %eax,0x30(%rcx)
 117ec8a:	8b 85 c3 fe ff ff    	mov    -0x13d(%rbp),%eax
 117ec90:	89 41 43             	mov    %eax,0x43(%rcx)
 117ec93:	8b 85 c0 fe ff ff    	mov    -0x140(%rbp),%eax
 117ec99:	89 41 40             	mov    %eax,0x40(%rcx)
 117ec9c:	0f b7 85 e8 fe ff ff 	movzwl -0x118(%rbp),%eax
 117eca3:	66 89 41 55          	mov    %ax,0x55(%rcx)
 117eca7:	8b 85 e4 fe ff ff    	mov    -0x11c(%rbp),%eax
 117ecad:	89 41 51             	mov    %eax,0x51(%rcx)
 117ecb0:	48 8b 85 c8 fe ff ff 	mov    -0x138(%rbp),%rax
 117ecb7:	48 89 85 50 f4 ff ff 	mov    %rax,-0xbb0(%rbp)
 117ecbe:	48 8b 85 58 fe ff ff 	mov    -0x1a8(%rbp),%rax
 117ecc5:	48 89 85 58 f4 ff ff 	mov    %rax,-0xba8(%rbp)
 117eccc:	0f b6 45 d5          	movzbl -0x2b(%rbp),%eax
 117ecd0:	88 85 60 f4 ff ff    	mov    %al,-0xba0(%rbp)
 117ecd6:	48 8b 85 60 fe ff ff 	mov    -0x1a0(%rbp),%rax
 117ecdd:	48 89 85 68 f4 ff ff 	mov    %rax,-0xb98(%rbp)
 117ece4:	0f b6 45 d4          	movzbl -0x2c(%rbp),%eax
 117ece8:	88 85 70 f4 ff ff    	mov    %al,-0xb90(%rbp)
 117ecee:	48 8b 85 68 fe ff ff 	mov    -0x198(%rbp),%rax
 117ecf5:	48 89 85 78 f4 ff ff 	mov    %rax,-0xb88(%rbp)
 117ecfc:	0f b6 45 d7          	movzbl -0x29(%rbp),%eax
 117ed00:	88 85 80 f4 ff ff    	mov    %al,-0xb80(%rbp)
 117ed06:	48 8b 85 70 fe ff ff 	mov    -0x190(%rbp),%rax
 117ed0d:	48 89 85 88 f4 ff ff 	mov    %rax,-0xb78(%rbp)
 117ed14:	0f b6 45 ce          	movzbl -0x32(%rbp),%eax
 117ed18:	88 85 90 f4 ff ff    	mov    %al,-0xb70(%rbp)
 117ed1e:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 117ed25:	48 89 85 98 f4 ff ff 	mov    %rax,-0xb68(%rbp)
 117ed2c:	0f b6 45 c4          	movzbl -0x3c(%rbp),%eax
 117ed30:	88 85 a0 f4 ff ff    	mov    %al,-0xb60(%rbp)
 117ed36:	48 8b 85 20 fd ff ff 	mov    -0x2e0(%rbp),%rax
 117ed3d:	48 89 85 a8 f4 ff ff 	mov    %rax,-0xb58(%rbp)
 117ed44:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 117ed48:	88 85 b0 f4 ff ff    	mov    %al,-0xb50(%rbp)
 117ed4e:	0f b6 45 c8          	movzbl -0x38(%rbp),%eax
 117ed52:	88 85 b1 f4 ff ff    	mov    %al,-0xb4f(%rbp)
 117ed58:	48 8d bd 50 f4 ff ff 	lea    -0xbb0(%rbp),%rdi
 117ed5f:	48 8b b5 e0 fd ff ff 	mov    -0x220(%rbp),%rsi
 117ed66:	c5 f8 77             	vzeroupper 
 117ed69:	e8 e2 f1 03 00       	call   11bdf50 <br.encoder.distance_block_split.Result.blockIndex>
 117ed6e:	48 69 c0 ee 00 00 00 	imul   $0xee,%rax,%rax
 117ed75:	4c 8d 34 28          	lea    (%rax,%rbp,1),%r14
 117ed79:	49 81 c6 9a 40 ff ff 	add    $0xffffffffffff409a,%r14
 117ed80:	31 db                	xor    %ebx,%ebx
 117ed82:	4c 8b ad 10 fd ff ff 	mov    -0x2f0(%rbp),%r13
 117ed89:	eb 09                	jmp    117ed94 <br.encodeCommandPlanWithOptionsWrite+0x59f4>
 117ed8b:	49 39 dd             	cmp    %rbx,%r13
 117ed8e:	0f 84 a7 00 00 00    	je     117ee3b <br.encodeCommandPlanWithOptionsWrite+0x5a9b>
 117ed94:	48 8b 85 58 fe ff ff 	mov    -0x1a8(%rbp),%rax
 117ed9b:	48 89 85 00 fa ff ff 	mov    %rax,-0x600(%rbp)
 117eda2:	48 8b 85 60 fe ff ff 	mov    -0x1a0(%rbp),%rax
 117eda9:	48 89 85 08 fa ff ff 	mov    %rax,-0x5f8(%rbp)
 117edb0:	48 8b 85 68 fe ff ff 	mov    -0x198(%rbp),%rax
 117edb7:	48 89 85 10 fa ff ff 	mov    %rax,-0x5f0(%rbp)
 117edbe:	48 8b 85 70 fe ff ff 	mov    -0x190(%rbp),%rax
 117edc5:	48 89 85 18 fa ff ff 	mov    %rax,-0x5e8(%rbp)
 117edcc:	48 8d 05 d1 af e8 ff 	lea    -0x17502f(%rip),%rax        # 1009da4 <__anon_240364+0x7344>
 117edd3:	48 63 14 98          	movslq (%rax,%rbx,4),%rdx
 117edd7:	48 01 c2             	add    %rax,%rdx
 117edda:	48 8d 85 00 fa ff ff 	lea    -0x600(%rbp),%rax
 117ede1:	48 8b 8d c8 fe ff ff 	mov    -0x138(%rbp),%rcx
 117ede8:	ff e2                	jmp    *%rdx
 117edea:	48 8d 85 08 fa ff ff 	lea    -0x5f8(%rbp),%rax
 117edf1:	eb 10                	jmp    117ee03 <br.encodeCommandPlanWithOptionsWrite+0x5a63>
 117edf3:	48 8d 85 18 fa ff ff 	lea    -0x5e8(%rbp),%rax
 117edfa:	eb 07                	jmp    117ee03 <br.encodeCommandPlanWithOptionsWrite+0x5a63>
 117edfc:	48 8d 85 10 fa ff ff 	lea    -0x5f0(%rbp),%rax
 117ee03:	48 8b 08             	mov    (%rax),%rcx
 117ee06:	48 ff c3             	inc    %rbx
 117ee09:	48 39 8d e0 fd ff ff 	cmp    %rcx,-0x220(%rbp)
 117ee10:	0f 85 75 ff ff ff    	jne    117ed8b <br.encodeCommandPlanWithOptionsWrite+0x59eb>
 117ee16:	48 8d bd 60 ec ff ff 	lea    -0x13a0(%rbp),%rdi
 117ee1d:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 117ee21:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 117ee25:	48 89 d9             	mov    %rbx,%rcx
 117ee28:	e8 e3 29 00 00       	call   1181810 <br.CommandBlockLengthCode.writeLength>
 117ee2d:	66 85 c0             	test   %ax,%ax
 117ee30:	0f 84 55 ff ff ff    	je     117ed8b <br.encodeCommandPlanWithOptionsWrite+0x59eb>
 117ee36:	e9 d2 a5 ff ff       	jmp    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117ee3b:	49 8b 04 24          	mov    (%r12),%rax
 117ee3f:	48 83 f8 01          	cmp    $0x1,%rax
 117ee43:	0f 86 f1 01 00 00    	jbe    117f03a <br.encodeCommandPlanWithOptionsWrite+0x5c9a>
 117ee49:	48 83 f8 04          	cmp    $0x4,%rax
 117ee4d:	77 55                	ja     117eea4 <br.encodeCommandPlanWithOptionsWrite+0x5b04>
 117ee4f:	48 8d bd a4 fc ff ff 	lea    -0x35c(%rbp),%rdi
 117ee56:	4c 89 e6             	mov    %r12,%rsi
 117ee59:	48 8b 55 90          	mov    -0x70(%rbp),%rdx
 117ee5d:	c5 f8 77             	vzeroupper 
 117ee60:	e8 fb 67 04 00       	call   11c5660 <br.encoder.command_plan.PrefixAlphabetFor(520).simpleCode>
 117ee65:	44 0f b7 b5 a4 fc ff 	movzwl -0x35c(%rbp),%r14d
 117ee6c:	ff 
 117ee6d:	0f b6 9d a6 fc ff ff 	movzbl -0x35a(%rbp),%ebx
 117ee74:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117ee78:	f6 40 08 07          	testb  $0x7,0x8(%rax)
 117ee7c:	0f 85 82 00 00 00    	jne    117ef04 <br.encodeCommandPlanWithOptionsWrite+0x5b64>
 117ee82:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117ee86:	48 8b 38             	mov    (%rax),%rdi
 117ee89:	48 8b 47 08          	mov    0x8(%rdi),%rax
 117ee8d:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 117ee91:	73 4f                	jae    117eee2 <br.encodeCommandPlanWithOptionsWrite+0x5b42>
 117ee93:	48 8d 48 01          	lea    0x1(%rax),%rcx
 117ee97:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 117ee9b:	48 8b 0f             	mov    (%rdi),%rcx
 117ee9e:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 117eea2:	eb 60                	jmp    117ef04 <br.encodeCommandPlanWithOptionsWrite+0x5b64>
 117eea4:	0f b7 45 90          	movzwl -0x70(%rbp),%eax
 117eea8:	45 0f b7 24 46       	movzwl (%r14,%rax,2),%r12d
 117eead:	41 0f b6 9c 06 9e 00 	movzbl 0x9e(%r14,%rax,1),%ebx
 117eeb4:	00 00 
 117eeb6:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117eeba:	f6 40 08 07          	testb  $0x7,0x8(%rax)
 117eebe:	75 7b                	jne    117ef3b <br.encodeCommandPlanWithOptionsWrite+0x5b9b>
 117eec0:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117eec4:	48 8b 38             	mov    (%rax),%rdi
 117eec7:	48 8b 47 08          	mov    0x8(%rdi),%rax
 117eecb:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 117eecf:	73 45                	jae    117ef16 <br.encodeCommandPlanWithOptionsWrite+0x5b76>
 117eed1:	48 8d 48 01          	lea    0x1(%rax),%rcx
 117eed5:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 117eed9:	48 8b 0f             	mov    (%rdi),%rcx
 117eedc:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 117eee0:	eb 59                	jmp    117ef3b <br.encodeCommandPlanWithOptionsWrite+0x5b9b>
 117eee2:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117eee6:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 117eeea:	0f 85 79 03 00 00    	jne    117f269 <br.encodeCommandPlanWithOptionsWrite+0x5ec9>
 117eef0:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 117eef4:	31 d2                	xor    %edx,%edx
 117eef6:	e8 a5 26 00 00       	call   11815a0 <array_list.Aligned(u8,null).append>
 117eefb:	66 85 c0             	test   %ax,%ax
 117eefe:	0f 85 09 a5 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117ef04:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117ef08:	0f b6 48 08          	movzbl 0x8(%rax),%ecx
 117ef0c:	80 e1 07             	and    $0x7,%cl
 117ef0f:	c4 c2 71 f7 f6       	shlx   %ecx,%r14d,%esi
 117ef14:	eb 35                	jmp    117ef4b <br.encodeCommandPlanWithOptionsWrite+0x5bab>
 117ef16:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117ef1a:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 117ef1e:	0f 85 45 03 00 00    	jne    117f269 <br.encodeCommandPlanWithOptionsWrite+0x5ec9>
 117ef24:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 117ef28:	31 d2                	xor    %edx,%edx
 117ef2a:	c5 f8 77             	vzeroupper 
 117ef2d:	e8 6e 26 00 00       	call   11815a0 <array_list.Aligned(u8,null).append>
 117ef32:	66 85 c0             	test   %ax,%ax
 117ef35:	0f 85 d2 a4 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117ef3b:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117ef3f:	0f b6 48 08          	movzbl 0x8(%rax),%ecx
 117ef43:	80 e1 07             	and    $0x7,%cl
 117ef46:	c4 c2 71 f7 f4       	shlx   %ecx,%r12d,%esi
 117ef4b:	48 8b 08             	mov    (%rax),%rcx
 117ef4e:	48 8b 11             	mov    (%rcx),%rdx
 117ef51:	48 8b 49 08          	mov    0x8(%rcx),%rcx
 117ef55:	40 08 74 0a ff       	or     %sil,-0x1(%rdx,%rcx,1)
 117ef5a:	0f b6 40 08          	movzbl 0x8(%rax),%eax
 117ef5e:	24 07                	and    $0x7,%al
 117ef60:	80 e3 0f             	and    $0xf,%bl
 117ef63:	00 c3                	add    %al,%bl
 117ef65:	80 fb 08             	cmp    $0x8,%bl
 117ef68:	0f 86 c2 00 00 00    	jbe    117f030 <br.encodeCommandPlanWithOptionsWrite+0x5c90>
 117ef6e:	41 89 f6             	mov    %esi,%r14d
 117ef71:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117ef75:	48 8b 38             	mov    (%rax),%rdi
 117ef78:	48 8b 47 08          	mov    0x8(%rdi),%rax
 117ef7c:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 117ef80:	73 11                	jae    117ef93 <br.encodeCommandPlanWithOptionsWrite+0x5bf3>
 117ef82:	48 8d 48 01          	lea    0x1(%rax),%rcx
 117ef86:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 117ef8a:	48 8b 0f             	mov    (%rdi),%rcx
 117ef8d:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 117ef91:	eb 25                	jmp    117efb8 <br.encodeCommandPlanWithOptionsWrite+0x5c18>
 117ef93:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117ef97:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 117ef9b:	0f 85 c8 02 00 00    	jne    117f269 <br.encodeCommandPlanWithOptionsWrite+0x5ec9>
 117efa1:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 117efa5:	31 d2                	xor    %edx,%edx
 117efa7:	c5 f8 77             	vzeroupper 
 117efaa:	e8 f1 25 00 00       	call   11815a0 <array_list.Aligned(u8,null).append>
 117efaf:	66 85 c0             	test   %ax,%ax
 117efb2:	0f 85 55 a4 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117efb8:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117efbc:	48 8b 00             	mov    (%rax),%rax
 117efbf:	48 8b 08             	mov    (%rax),%rcx
 117efc2:	48 8b 40 08          	mov    0x8(%rax),%rax
 117efc6:	44 89 f2             	mov    %r14d,%edx
 117efc9:	88 74 01 ff          	mov    %dh,-0x1(%rcx,%rax,1)
 117efcd:	80 fb 11             	cmp    $0x11,%bl
 117efd0:	72 5e                	jb     117f030 <br.encodeCommandPlanWithOptionsWrite+0x5c90>
 117efd2:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117efd6:	48 8b 38             	mov    (%rax),%rdi
 117efd9:	48 8b 47 08          	mov    0x8(%rdi),%rax
 117efdd:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 117efe1:	73 11                	jae    117eff4 <br.encodeCommandPlanWithOptionsWrite+0x5c54>
 117efe3:	48 8d 48 01          	lea    0x1(%rax),%rcx
 117efe7:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 117efeb:	48 8b 0f             	mov    (%rdi),%rcx
 117efee:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 117eff2:	eb 25                	jmp    117f019 <br.encodeCommandPlanWithOptionsWrite+0x5c79>
 117eff4:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117eff8:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 117effc:	0f 85 67 02 00 00    	jne    117f269 <br.encodeCommandPlanWithOptionsWrite+0x5ec9>
 117f002:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 117f006:	31 d2                	xor    %edx,%edx
 117f008:	c5 f8 77             	vzeroupper 
 117f00b:	e8 90 25 00 00       	call   11815a0 <array_list.Aligned(u8,null).append>
 117f010:	66 85 c0             	test   %ax,%ax
 117f013:	0f 85 f4 a3 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117f019:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117f01d:	48 8b 00             	mov    (%rax),%rax
 117f020:	48 8b 08             	mov    (%rax),%rcx
 117f023:	48 8b 40 08          	mov    0x8(%rax),%rax
 117f027:	41 c1 ee 10          	shr    $0x10,%r14d
 117f02b:	44 88 74 01 ff       	mov    %r14b,-0x1(%rcx,%rax,1)
 117f030:	80 e3 07             	and    $0x7,%bl
 117f033:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117f037:	88 58 08             	mov    %bl,0x8(%rax)
 117f03a:	f6 85 f8 fe ff ff 1f 	testb  $0x1f,-0x108(%rbp)
 117f041:	74 2b                	je     117f06e <br.encodeCommandPlanWithOptionsWrite+0x5cce>
 117f043:	8b 95 90 fd ff ff    	mov    -0x270(%rbp),%edx
 117f049:	48 8b 85 f8 fe ff ff 	mov    -0x108(%rbp),%rax
 117f050:	24 1f                	and    $0x1f,%al
 117f052:	0f b6 c8             	movzbl %al,%ecx
 117f055:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 117f059:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 117f05d:	c5 f8 77             	vzeroupper 
 117f060:	e8 cb 22 00 00       	call   1181330 <br.BitWriter.writeBits>
 117f065:	66 85 c0             	test   %ax,%ax
 117f068:	0f 85 9f a3 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117f06e:	48 ff 85 e0 fd ff ff 	incq   -0x220(%rbp)
 117f075:	80 bd 80 fd ff ff 00 	cmpb   $0x0,-0x280(%rbp)
 117f07c:	74 12                	je     117f090 <br.encodeCommandPlanWithOptionsWrite+0x5cf0>
 117f07e:	c5 fc 10 85 50 ee ff 	vmovups -0x11b0(%rbp),%ymm0
 117f085:	ff 
 117f086:	c5 fc 11 85 40 fd ff 	vmovups %ymm0,-0x2c0(%rbp)
 117f08d:	ff 
 117f08e:	eb 67                	jmp    117f0f7 <br.encodeCommandPlanWithOptionsWrite+0x5d57>
 117f090:	80 bd 48 ff ff ff 01 	cmpb   $0x1,-0xb8(%rbp)
 117f097:	75 5e                	jne    117f0f7 <br.encodeCommandPlanWithOptionsWrite+0x5d57>
 117f099:	48 8b 85 40 fe ff ff 	mov    -0x1c0(%rbp),%rax
 117f0a0:	80 38 00             	cmpb   $0x0,(%rax)
 117f0a3:	74 14                	je     117f0b9 <br.encodeCommandPlanWithOptionsWrite+0x5d19>
 117f0a5:	48 8b 85 d0 fe ff ff 	mov    -0x130(%rbp),%rax
 117f0ac:	0f b6 00             	movzbl (%rax),%eax
 117f0af:	24 0f                	and    $0xf,%al
 117f0b1:	3a 45 9f             	cmp    -0x61(%rbp),%al
 117f0b4:	0f 95 c0             	setne  %al
 117f0b7:	eb 02                	jmp    117f0bb <br.encodeCommandPlanWithOptionsWrite+0x5d1b>
 117f0b9:	b0 01                	mov    $0x1,%al
 117f0bb:	0f b6 4d b7          	movzbl -0x49(%rbp),%ecx
 117f0bf:	80 e1 03             	and    $0x3,%cl
 117f0c2:	80 f9 02             	cmp    $0x2,%cl
 117f0c5:	74 30                	je     117f0f7 <br.encodeCommandPlanWithOptionsWrite+0x5d57>
 117f0c7:	84 c0                	test   %al,%al
 117f0c9:	74 2c                	je     117f0f7 <br.encodeCommandPlanWithOptionsWrite+0x5d57>
 117f0cb:	c5 f8 10 85 48 fd ff 	vmovups -0x2b8(%rbp),%xmm0
 117f0d2:	ff 
 117f0d3:	c5 f8 29 85 40 fd ff 	vmovaps %xmm0,-0x2c0(%rbp)
 117f0da:	ff 
 117f0db:	48 8b 85 58 fd ff ff 	mov    -0x2a8(%rbp),%rax
 117f0e2:	48 89 85 50 fd ff ff 	mov    %rax,-0x2b0(%rbp)
 117f0e9:	48 8b 85 00 ff ff ff 	mov    -0x100(%rbp),%rax
 117f0f0:	48 89 85 58 fd ff ff 	mov    %rax,-0x2a8(%rbp)
 117f0f7:	48 8b 8d 70 ff ff ff 	mov    -0x90(%rbp),%rcx
 117f0fe:	48 ff c1             	inc    %rcx
 117f101:	48 89 8d 70 ff ff ff 	mov    %rcx,-0x90(%rbp)
 117f108:	48 3b 8d 58 ff ff ff 	cmp    -0xa8(%rbp),%rcx
 117f10f:	0f 85 1e e7 ff ff    	jne    117d833 <br.encodeCommandPlanWithOptionsWrite+0x4493>
 117f115:	48 83 bd e8 fd ff ff 	cmpq   $0x0,-0x218(%rbp)
 117f11c:	00 
 117f11d:	0f 84 ba 0a 00 00    	je     117fbdd <br.encodeCommandPlanWithOptionsWrite+0x683d>
 117f123:	48 8b 85 e8 fd ff ff 	mov    -0x218(%rbp),%rax
 117f12a:	c6 80 12 27 02 00 00 	movb   $0x0,0x22712(%rax)
 117f131:	8b 8d 44 ff ff ff    	mov    -0xbc(%rbp),%ecx
 117f137:	66 89 88 10 27 02 00 	mov    %cx,0x22710(%rax)
 117f13e:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 117f142:	80 78 50 00          	cmpb   $0x0,0x50(%rax)
 117f146:	74 0b                	je     117f153 <br.encodeCommandPlanWithOptionsWrite+0x5db3>
 117f148:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 117f14c:	0f b6 40 08          	movzbl 0x8(%rax),%eax
 117f150:	88 45 9e             	mov    %al,-0x62(%rbp)
 117f153:	0f b6 4d 9e          	movzbl -0x62(%rbp),%ecx
 117f157:	80 e1 03             	and    $0x3,%cl
 117f15a:	48 8b 85 e8 fd ff ff 	mov    -0x218(%rbp),%rax
 117f161:	88 88 13 27 02 00    	mov    %cl,0x22713(%rax)
 117f167:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 117f16b:	c5 f8 11 00          	vmovups %xmm0,(%rax)
 117f16f:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 117f173:	80 78 50 00          	cmpb   $0x0,0x50(%rax)
 117f177:	0f 84 d0 04 00 00    	je     117f64d <br.encodeCommandPlanWithOptionsWrite+0x62ad>
 117f17d:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 117f181:	c5 f8 10 40 40       	vmovups 0x40(%rax),%xmm0
 117f186:	c5 fc 10 08          	vmovups (%rax),%ymm1
 117f18a:	c5 fc 10 50 20       	vmovups 0x20(%rax),%ymm2
 117f18f:	c5 fc 11 95 80 f0 ff 	vmovups %ymm2,-0xf80(%rbp)
 117f196:	ff 
 117f197:	c5 f8 29 85 a0 f0 ff 	vmovaps %xmm0,-0xf60(%rbp)
 117f19e:	ff 
 117f19f:	c5 fc 11 8d 60 f0 ff 	vmovups %ymm1,-0xfa0(%rbp)
 117f1a6:	ff 
 117f1a7:	48 8b 85 e8 fd ff ff 	mov    -0x218(%rbp),%rax
 117f1ae:	48 8d 98 90 13 01 00 	lea    0x11390(%rax),%rbx
 117f1b5:	41 be 0a 00 00 00    	mov    $0xa,%r14d
 117f1bb:	48 8d bb 80 ec fe ff 	lea    -0x11380(%rbx),%rdi
 117f1c2:	c5 fc 10 85 60 f0 ff 	vmovups -0xfa0(%rbp),%ymm0
 117f1c9:	ff 
 117f1ca:	c5 fc 10 8d 80 f0 ff 	vmovups -0xf80(%rbp),%ymm1
 117f1d1:	ff 
 117f1d2:	c5 f8 10 95 90 f0 ff 	vmovups -0xf70(%rbp),%xmm2
 117f1d9:	ff 
 117f1da:	c5 f8 11 95 80 fc ff 	vmovups %xmm2,-0x380(%rbp)
 117f1e1:	ff 
 117f1e2:	c5 f8 10 95 a0 f0 ff 	vmovups -0xf60(%rbp),%xmm2
 117f1e9:	ff 
 117f1ea:	c5 f8 11 95 90 fc ff 	vmovups %xmm2,-0x370(%rbp)
 117f1f1:	ff 
 117f1f2:	c5 fc 11 8d 70 fc ff 	vmovups %ymm1,-0x390(%rbp)
 117f1f9:	ff 
 117f1fa:	c5 fc 11 85 50 fc ff 	vmovups %ymm0,-0x3b0(%rbp)
 117f201:	ff 
 117f202:	42 0f b6 84 35 50 fc 	movzbl -0x3b0(%rbp,%r14,1),%eax
 117f209:	ff ff 
 117f20b:	89 c1                	mov    %eax,%ecx
 117f20d:	c1 e1 09             	shl    $0x9,%ecx
 117f210:	48 8d 0c c1          	lea    (%rcx,%rax,8),%rcx
 117f214:	48 8d 14 29          	lea    (%rcx,%rbp,1),%rdx
 117f218:	48 81 c2 50 1d fd ff 	add    $0xfffffffffffd1d50,%rdx
 117f21f:	89 c1                	mov    %eax,%ecx
 117f221:	c1 e1 08             	shl    $0x8,%ecx
 117f224:	48 01 e9             	add    %rbp,%rcx
 117f227:	48 81 c1 d4 c1 fd ff 	add    $0xfffffffffffdc1d4,%rcx
 117f22e:	c1 e0 0a             	shl    $0xa,%eax
 117f231:	4c 8d 04 28          	lea    (%rax,%rbp,1),%r8
 117f235:	49 81 c0 50 ba fb ff 	add    $0xfffffffffffbba50,%r8
 117f23c:	48 89 de             	mov    %rbx,%rsi
 117f23f:	c5 f8 77             	vzeroupper 
 117f242:	e8 49 1f 00 00       	call   1181190 <br.encoder.hq_codec.huffman_model.table__anon_37357>
 117f247:	66 85 c0             	test   %ax,%ax
 117f24a:	0f 85 bd a1 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117f250:	49 ff c6             	inc    %r14
 117f253:	48 81 c3 00 04 00 00 	add    $0x400,%rbx
 117f25a:	49 83 fe 4a          	cmp    $0x4a,%r14
 117f25e:	0f 85 57 ff ff ff    	jne    117f1bb <br.encodeCommandPlanWithOptionsWrite+0x5e1b>
 117f264:	e9 23 06 00 00       	jmp    117f88c <br.encodeCommandPlanWithOptionsWrite+0x64ec>
 117f269:	66 b8 1a 00          	mov    $0x1a,%ax
 117f26d:	e9 9b a1 ff ff       	jmp    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117f272:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 117f276:	0a 45 c7             	or     -0x39(%rbp),%al
 117f279:	a8 01                	test   $0x1,%al
 117f27b:	74 30                	je     117f2ad <br.encodeCommandPlanWithOptionsWrite+0x5f0d>
 117f27d:	44 0f b6 65 d2       	movzbl -0x2e(%rbp),%r12d
 117f282:	41 83 e4 01          	and    $0x1,%r12d
 117f286:	49 83 f4 03          	xor    $0x3,%r12
 117f28a:	eb 53                	jmp    117f2df <br.encodeCommandPlanWithOptionsWrite+0x5f3f>
 117f28c:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 117f290:	0a 45 c8             	or     -0x38(%rbp),%al
 117f293:	a8 01                	test   $0x1,%al
 117f295:	0f 84 21 01 00 00    	je     117f3bc <br.encodeCommandPlanWithOptionsWrite+0x601c>
 117f29b:	44 0f b6 7d d3       	movzbl -0x2d(%rbp),%r15d
 117f2a0:	41 83 e7 01          	and    $0x1,%r15d
 117f2a4:	49 83 f7 03          	xor    $0x3,%r15
 117f2a8:	e9 41 01 00 00       	jmp    117f3ee <br.encodeCommandPlanWithOptionsWrite+0x604e>
 117f2ad:	41 bc 06 00 00 00    	mov    $0x6,%r12d
 117f2b3:	80 7d cd 00          	cmpb   $0x0,-0x33(%rbp)
 117f2b7:	75 26                	jne    117f2df <br.encodeCommandPlanWithOptionsWrite+0x5f3f>
 117f2b9:	41 bc 05 00 00 00    	mov    $0x5,%r12d
 117f2bf:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 117f2c3:	75 1a                	jne    117f2df <br.encodeCommandPlanWithOptionsWrite+0x5f3f>
 117f2c5:	41 bc 04 00 00 00    	mov    $0x4,%r12d
 117f2cb:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 117f2cf:	75 0e                	jne    117f2df <br.encodeCommandPlanWithOptionsWrite+0x5f3f>
 117f2d1:	80 7d cb 01          	cmpb   $0x1,-0x35(%rbp)
 117f2d5:	41 bc 03 00 00 00    	mov    $0x3,%r12d
 117f2db:	49 83 dc 00          	sbb    $0x0,%r12
 117f2df:	48 8d 9d 18 1e ff ff 	lea    -0xe1e8(%rbp),%rbx
 117f2e6:	4c 8d b5 d0 eb fc ff 	lea    -0x31430(%rbp),%r14
 117f2ed:	4c 8d bd f0 fc fe ff 	lea    -0x10310(%rbp),%r15
 117f2f4:	eb 2d                	jmp    117f323 <br.encodeCommandPlanWithOptionsWrite+0x5f83>
 117f2f6:	ba 40 08 00 00       	mov    $0x840,%edx
 117f2fb:	4c 89 f7             	mov    %r14,%rdi
 117f2fe:	31 f6                	xor    %esi,%esi
 117f300:	e8 9b 69 11 00       	call   1295ca0 <compiler_rt.memset>
 117f305:	48 81 c3 c0 02 00 00 	add    $0x2c0,%rbx
 117f30c:	49 81 c7 88 05 00 00 	add    $0x588,%r15
 117f313:	49 81 c6 40 08 00 00 	add    $0x840,%r14
 117f31a:	49 ff cc             	dec    %r12
 117f31d:	0f 84 da e0 ff ff    	je     117d3fd <br.encodeCommandPlanWithOptionsWrite+0x405d>
 117f323:	49 8b 4f f8          	mov    -0x8(%r15),%rcx
 117f327:	48 83 f9 05          	cmp    $0x5,%rcx
 117f32b:	72 c9                	jb     117f2f6 <br.encodeCommandPlanWithOptionsWrite+0x5f56>
 117f32d:	48 83 f9 41          	cmp    $0x41,%rcx
 117f331:	73 3a                	jae    117f36d <br.encodeCommandPlanWithOptionsWrite+0x5fcd>
 117f333:	48 8d bd 04 54 ff ff 	lea    -0xabfc(%rbp),%rdi
 117f33a:	48 89 de             	mov    %rbx,%rsi
 117f33d:	4c 89 fa             	mov    %r15,%rdx
 117f340:	e8 1b 35 00 00       	call   1182860 <huffman.HuffmanTable(704).Encoder.initSparseTrusted>
 117f345:	0f b7 85 44 5c ff ff 	movzwl -0xa3bc(%rbp),%eax
 117f34c:	66 85 c0             	test   %ax,%ax
 117f34f:	0f 85 b8 a0 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117f355:	ba 40 08 00 00       	mov    $0x840,%edx
 117f35a:	4c 8d ad 94 80 fe ff 	lea    -0x17f6c(%rbp),%r13
 117f361:	4c 89 ef             	mov    %r13,%rdi
 117f364:	48 8d b5 04 54 ff ff 	lea    -0xabfc(%rbp),%rsi
 117f36b:	eb 35                	jmp    117f3a2 <br.encodeCommandPlanWithOptionsWrite+0x6002>
 117f36d:	48 8d bd c2 4b ff ff 	lea    -0xb43e(%rbp),%rdi
 117f374:	48 89 de             	mov    %rbx,%rsi
 117f377:	e8 b4 31 00 00       	call   1182530 <huffman.HuffmanTable(704).Encoder.init>
 117f37c:	0f b7 85 02 54 ff ff 	movzwl -0xabfe(%rbp),%eax
 117f383:	66 85 c0             	test   %ax,%ax
 117f386:	0f 85 81 a0 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117f38c:	ba 40 08 00 00       	mov    $0x840,%edx
 117f391:	4c 8d ad 54 78 fe ff 	lea    -0x187ac(%rbp),%r13
 117f398:	4c 89 ef             	mov    %r13,%rdi
 117f39b:	48 8d b5 c2 4b ff ff 	lea    -0xb43e(%rbp),%rsi
 117f3a2:	e8 19 6d 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117f3a7:	4c 89 ee             	mov    %r13,%rsi
 117f3aa:	ba 40 08 00 00       	mov    $0x840,%edx
 117f3af:	4c 89 f7             	mov    %r14,%rdi
 117f3b2:	e8 09 6d 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117f3b7:	e9 49 ff ff ff       	jmp    117f305 <br.encodeCommandPlanWithOptionsWrite+0x5f65>
 117f3bc:	41 bf 06 00 00 00    	mov    $0x6,%r15d
 117f3c2:	80 7d ce 00          	cmpb   $0x0,-0x32(%rbp)
 117f3c6:	75 26                	jne    117f3ee <br.encodeCommandPlanWithOptionsWrite+0x604e>
 117f3c8:	41 bf 05 00 00 00    	mov    $0x5,%r15d
 117f3ce:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 117f3d2:	75 1a                	jne    117f3ee <br.encodeCommandPlanWithOptionsWrite+0x604e>
 117f3d4:	41 bf 04 00 00 00    	mov    $0x4,%r15d
 117f3da:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 117f3de:	75 0e                	jne    117f3ee <br.encodeCommandPlanWithOptionsWrite+0x604e>
 117f3e0:	80 7d d5 01          	cmpb   $0x1,-0x2b(%rbp)
 117f3e4:	41 bf 03 00 00 00    	mov    $0x3,%r15d
 117f3ea:	49 83 df 00          	sbb    $0x0,%r15
 117f3ee:	48 8d 9d ea d1 ff ff 	lea    -0x2e16(%rbp),%rbx
 117f3f5:	4c 8d a5 2e 46 ff ff 	lea    -0xb9d2(%rbp),%r12
 117f3fc:	4c 8d b5 40 cb ff ff 	lea    -0x34c0(%rbp),%r14
 117f403:	4c 8d ad 00 e1 ff ff 	lea    -0x1f00(%rbp),%r13
 117f40a:	eb 62                	jmp    117f46e <br.encodeCommandPlanWithOptionsWrite+0x60ce>
 117f40c:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 117f410:	c4 c1 7c 11 84 24 ce 	vmovups %ymm0,0xce(%r12)
 117f417:	00 00 00 
 117f41a:	c4 c1 7c 11 84 24 c0 	vmovups %ymm0,0xc0(%r12)
 117f421:	00 00 00 
 117f424:	c4 c1 7c 11 84 24 a0 	vmovups %ymm0,0xa0(%r12)
 117f42b:	00 00 00 
 117f42e:	c4 c1 7c 11 84 24 80 	vmovups %ymm0,0x80(%r12)
 117f435:	00 00 00 
 117f438:	c4 c1 7c 11 44 24 60 	vmovups %ymm0,0x60(%r12)
 117f43f:	c4 c1 7c 11 44 24 40 	vmovups %ymm0,0x40(%r12)
 117f446:	c4 c1 7c 11 44 24 20 	vmovups %ymm0,0x20(%r12)
 117f44d:	c4 c1 7c 11 04 24    	vmovups %ymm0,(%r12)
 117f453:	48 83 c3 4f          	add    $0x4f,%rbx
 117f457:	49 81 c6 a8 00 00 00 	add    $0xa8,%r14
 117f45e:	49 81 c4 ee 00 00 00 	add    $0xee,%r12
 117f465:	49 ff cf             	dec    %r15
 117f468:	0f 84 e6 e0 ff ff    	je     117d554 <br.encodeCommandPlanWithOptionsWrite+0x41b4>
 117f46e:	49 8b 4e f8          	mov    -0x8(%r14),%rcx
 117f472:	48 83 f9 05          	cmp    $0x5,%rcx
 117f476:	72 94                	jb     117f40c <br.encodeCommandPlanWithOptionsWrite+0x606c>
 117f478:	48 83 f9 41          	cmp    $0x41,%rcx
 117f47c:	0f 83 ad 00 00 00    	jae    117f52f <br.encodeCommandPlanWithOptionsWrite+0x618f>
 117f482:	4c 89 ef             	mov    %r13,%rdi
 117f485:	48 89 de             	mov    %rbx,%rsi
 117f488:	4c 89 f2             	mov    %r14,%rdx
 117f48b:	c5 f8 77             	vzeroupper 
 117f48e:	e8 9d 2b 00 00       	call   1182030 <huffman.HuffmanTable(79).Encoder.initSparseTrusted>
 117f493:	0f b7 85 ee e1 ff ff 	movzwl -0x1e12(%rbp),%eax
 117f49a:	66 85 c0             	test   %ax,%ax
 117f49d:	0f 85 6a 9f ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117f4a3:	c5 fc 10 85 ce e1 ff 	vmovups -0x1e32(%rbp),%ymm0
 117f4aa:	ff 
 117f4ab:	c5 fc 11 85 ee da ff 	vmovups %ymm0,-0x2512(%rbp)
 117f4b2:	ff 
 117f4b3:	c5 fc 10 85 c0 e1 ff 	vmovups -0x1e40(%rbp),%ymm0
 117f4ba:	ff 
 117f4bb:	c5 fc 11 85 e0 da ff 	vmovups %ymm0,-0x2520(%rbp)
 117f4c2:	ff 
 117f4c3:	c5 fc 10 85 a0 e1 ff 	vmovups -0x1e60(%rbp),%ymm0
 117f4ca:	ff 
 117f4cb:	c5 fc 11 85 c0 da ff 	vmovups %ymm0,-0x2540(%rbp)
 117f4d2:	ff 
 117f4d3:	c5 fc 10 85 80 e1 ff 	vmovups -0x1e80(%rbp),%ymm0
 117f4da:	ff 
 117f4db:	c5 fc 11 85 a0 da ff 	vmovups %ymm0,-0x2560(%rbp)
 117f4e2:	ff 
 117f4e3:	c5 fc 10 85 00 e1 ff 	vmovups -0x1f00(%rbp),%ymm0
 117f4ea:	ff 
 117f4eb:	c5 fc 10 8d 20 e1 ff 	vmovups -0x1ee0(%rbp),%ymm1
 117f4f2:	ff 
 117f4f3:	c5 fc 10 95 40 e1 ff 	vmovups -0x1ec0(%rbp),%ymm2
 117f4fa:	ff 
 117f4fb:	c5 fc 10 9d 60 e1 ff 	vmovups -0x1ea0(%rbp),%ymm3
 117f502:	ff 
 117f503:	c5 fc 11 9d 80 da ff 	vmovups %ymm3,-0x2580(%rbp)
 117f50a:	ff 
 117f50b:	c5 fc 11 95 60 da ff 	vmovups %ymm2,-0x25a0(%rbp)
 117f512:	ff 
 117f513:	c5 fc 11 8d 40 da ff 	vmovups %ymm1,-0x25c0(%rbp)
 117f51a:	ff 
 117f51b:	c5 fc 11 85 20 da ff 	vmovups %ymm0,-0x25e0(%rbp)
 117f522:	ff 
 117f523:	48 8d 85 20 da ff ff 	lea    -0x25e0(%rbp),%rax
 117f52a:	e9 a9 00 00 00       	jmp    117f5d8 <br.encodeCommandPlanWithOptionsWrite+0x6238>
 117f52f:	48 8d bd 10 e0 ff ff 	lea    -0x1ff0(%rbp),%rdi
 117f536:	48 89 de             	mov    %rbx,%rsi
 117f539:	c5 f8 77             	vzeroupper 
 117f53c:	e8 cf 26 00 00       	call   1181c10 <huffman.HuffmanTable(79).Encoder.init>
 117f541:	0f b7 85 fe e0 ff ff 	movzwl -0x1f02(%rbp),%eax
 117f548:	66 85 c0             	test   %ax,%ax
 117f54b:	0f 85 bc 9e ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117f551:	c5 fc 10 85 de e0 ff 	vmovups -0x1f22(%rbp),%ymm0
 117f558:	ff 
 117f559:	c5 fc 11 85 fe d9 ff 	vmovups %ymm0,-0x2602(%rbp)
 117f560:	ff 
 117f561:	c5 fc 10 85 d0 e0 ff 	vmovups -0x1f30(%rbp),%ymm0
 117f568:	ff 
 117f569:	c5 fc 11 85 f0 d9 ff 	vmovups %ymm0,-0x2610(%rbp)
 117f570:	ff 
 117f571:	c5 fc 10 85 b0 e0 ff 	vmovups -0x1f50(%rbp),%ymm0
 117f578:	ff 
 117f579:	c5 fc 11 85 d0 d9 ff 	vmovups %ymm0,-0x2630(%rbp)
 117f580:	ff 
 117f581:	c5 fc 10 85 90 e0 ff 	vmovups -0x1f70(%rbp),%ymm0
 117f588:	ff 
 117f589:	c5 fc 11 85 b0 d9 ff 	vmovups %ymm0,-0x2650(%rbp)
 117f590:	ff 
 117f591:	c5 fc 10 85 10 e0 ff 	vmovups -0x1ff0(%rbp),%ymm0
 117f598:	ff 
 117f599:	c5 fc 10 8d 30 e0 ff 	vmovups -0x1fd0(%rbp),%ymm1
 117f5a0:	ff 
 117f5a1:	c5 fc 10 95 50 e0 ff 	vmovups -0x1fb0(%rbp),%ymm2
 117f5a8:	ff 
 117f5a9:	c5 fc 10 9d 70 e0 ff 	vmovups -0x1f90(%rbp),%ymm3
 117f5b0:	ff 
 117f5b1:	c5 fc 11 9d 90 d9 ff 	vmovups %ymm3,-0x2670(%rbp)
 117f5b8:	ff 
 117f5b9:	c5 fc 11 95 70 d9 ff 	vmovups %ymm2,-0x2690(%rbp)
 117f5c0:	ff 
 117f5c1:	c5 fc 11 8d 50 d9 ff 	vmovups %ymm1,-0x26b0(%rbp)
 117f5c8:	ff 
 117f5c9:	c5 fc 11 85 30 d9 ff 	vmovups %ymm0,-0x26d0(%rbp)
 117f5d0:	ff 
 117f5d1:	48 8d 85 30 d9 ff ff 	lea    -0x26d0(%rbp),%rax
 117f5d8:	c5 fc 10 80 ce 00 00 	vmovups 0xce(%rax),%ymm0
 117f5df:	00 
 117f5e0:	c4 c1 7c 11 84 24 ce 	vmovups %ymm0,0xce(%r12)
 117f5e7:	00 00 00 
 117f5ea:	c5 fc 10 80 c0 00 00 	vmovups 0xc0(%rax),%ymm0
 117f5f1:	00 
 117f5f2:	c4 c1 7c 11 84 24 c0 	vmovups %ymm0,0xc0(%r12)
 117f5f9:	00 00 00 
 117f5fc:	c5 fc 10 80 a0 00 00 	vmovups 0xa0(%rax),%ymm0
 117f603:	00 
 117f604:	c4 c1 7c 11 84 24 a0 	vmovups %ymm0,0xa0(%r12)
 117f60b:	00 00 00 
 117f60e:	c5 fc 10 80 80 00 00 	vmovups 0x80(%rax),%ymm0
 117f615:	00 
 117f616:	c4 c1 7c 11 84 24 80 	vmovups %ymm0,0x80(%r12)
 117f61d:	00 00 00 
 117f620:	c5 fc 10 00          	vmovups (%rax),%ymm0
 117f624:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 117f629:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 117f62e:	c5 fc 10 58 60       	vmovups 0x60(%rax),%ymm3
 117f633:	c4 c1 7c 11 5c 24 60 	vmovups %ymm3,0x60(%r12)
 117f63a:	c4 c1 7c 11 54 24 40 	vmovups %ymm2,0x40(%r12)
 117f641:	c4 c1 7c 11 4c 24 20 	vmovups %ymm1,0x20(%r12)
 117f648:	e9 00 fe ff ff       	jmp    117f44d <br.encodeCommandPlanWithOptionsWrite+0x60ad>
 117f64d:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 117f651:	74 38                	je     117f68b <br.encodeCommandPlanWithOptionsWrite+0x62eb>
 117f653:	48 8d 85 e8 e4 fe ff 	lea    -0x11b18(%rbp),%rax
 117f65a:	48 89 85 40 fc ff ff 	mov    %rax,-0x3c0(%rbp)
 117f661:	48 8d 85 68 8c ff ff 	lea    -0x7398(%rbp),%rax
 117f668:	48 89 85 48 fc ff ff 	mov    %rax,-0x3b8(%rbp)
 117f66f:	4c 8d 85 cc ab ff ff 	lea    -0x5434(%rbp),%r8
 117f676:	80 7d c0 00          	cmpb   $0x0,-0x40(%rbp)
 117f67a:	74 2c                	je     117f6a8 <br.encodeCommandPlanWithOptionsWrite+0x6308>
 117f67c:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 117f683:	48 89 c1             	mov    %rax,%rcx
 117f686:	e9 0d 01 00 00       	jmp    117f798 <br.encodeCommandPlanWithOptionsWrite+0x63f8>
 117f68b:	4c 8d 85 00 e6 ff ff 	lea    -0x1a00(%rbp),%r8
 117f692:	b8 01 00 00 00       	mov    $0x1,%eax
 117f697:	48 89 85 28 ff ff ff 	mov    %rax,-0xd8(%rbp)
 117f69e:	b9 01 00 00 00       	mov    $0x1,%ecx
 117f6a3:	e9 f0 00 00 00       	jmp    117f798 <br.encodeCommandPlanWithOptionsWrite+0x63f8>
 117f6a8:	0f b6 45 c9          	movzbl -0x37(%rbp),%eax
 117f6ac:	89 c2                	mov    %eax,%edx
 117f6ae:	0a 55 c2             	or     -0x3e(%rbp),%dl
 117f6b1:	0f b6 c0             	movzbl %al,%eax
 117f6b4:	f6 c2 01             	test   $0x1,%dl
 117f6b7:	0f 84 82 00 00 00    	je     117f73f <br.encodeCommandPlanWithOptionsWrite+0x639f>
 117f6bd:	89 c1                	mov    %eax,%ecx
 117f6bf:	83 e1 01             	and    $0x1,%ecx
 117f6c2:	48 83 f1 03          	xor    $0x3,%rcx
 117f6c6:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 117f6ca:	40 0f 95 c6          	setne  %sil
 117f6ce:	80 7d ca 00          	cmpb   $0x0,-0x36(%rbp)
 117f6d2:	40 0f 95 c7          	setne  %dil
 117f6d6:	40 08 d7             	or     %dl,%dil
 117f6d9:	44 0f b6 4d c2       	movzbl -0x3e(%rbp),%r9d
 117f6de:	41 f6 d1             	not    %r9b
 117f6e1:	45 0f b6 c9          	movzbl %r9b,%r9d
 117f6e5:	41 83 e1 01          	and    $0x1,%r9d
 117f6e9:	4f 8d 0c 49          	lea    (%r9,%r9,2),%r9
 117f6ed:	49 83 c1 03          	add    $0x3,%r9
 117f6f1:	f6 45 c9 01          	testb  $0x1,-0x37(%rbp)
 117f6f5:	41 ba 02 00 00 00    	mov    $0x2,%r10d
 117f6fb:	4d 0f 44 d1          	cmove  %r9,%r10
 117f6ff:	40 08 fe             	or     %dil,%sil
 117f702:	40 f6 c7 01          	test   $0x1,%dil
 117f706:	bf 05 00 00 00       	mov    $0x5,%edi
 117f70b:	49 0f 45 fa          	cmovne %r10,%rdi
 117f70f:	48 89 bd 28 ff ff ff 	mov    %rdi,-0xd8(%rbp)
 117f716:	40 f6 c6 01          	test   $0x1,%sil
 117f71a:	75 3e                	jne    117f75a <br.encodeCommandPlanWithOptionsWrite+0x63ba>
 117f71c:	80 7d c5 01          	cmpb   $0x1,-0x3b(%rbp)
 117f720:	be 03 00 00 00       	mov    $0x3,%esi
 117f725:	48 83 de 00          	sbb    $0x0,%rsi
 117f729:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 117f72d:	bf 04 00 00 00       	mov    $0x4,%edi
 117f732:	48 0f 44 fe          	cmove  %rsi,%rdi
 117f736:	48 89 bd 28 ff ff ff 	mov    %rdi,-0xd8(%rbp)
 117f73d:	eb 1b                	jmp    117f75a <br.encodeCommandPlanWithOptionsWrite+0x63ba>
 117f73f:	b9 06 00 00 00       	mov    $0x6,%ecx
 117f744:	be 06 00 00 00       	mov    $0x6,%esi
 117f749:	48 89 b5 28 ff ff ff 	mov    %rsi,-0xd8(%rbp)
 117f750:	80 7d ca 00          	cmpb   $0x0,-0x36(%rbp)
 117f754:	0f 84 44 05 00 00    	je     117fc9e <br.encodeCommandPlanWithOptionsWrite+0x68fe>
 117f75a:	f6 c2 01             	test   $0x1,%dl
 117f75d:	74 09                	je     117f768 <br.encodeCommandPlanWithOptionsWrite+0x63c8>
 117f75f:	83 e0 01             	and    $0x1,%eax
 117f762:	48 83 f0 03          	xor    $0x3,%rax
 117f766:	eb 30                	jmp    117f798 <br.encodeCommandPlanWithOptionsWrite+0x63f8>
 117f768:	b8 06 00 00 00       	mov    $0x6,%eax
 117f76d:	80 7d ca 00          	cmpb   $0x0,-0x36(%rbp)
 117f771:	75 25                	jne    117f798 <br.encodeCommandPlanWithOptionsWrite+0x63f8>
 117f773:	b8 05 00 00 00       	mov    $0x5,%eax
 117f778:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 117f77c:	75 1a                	jne    117f798 <br.encodeCommandPlanWithOptionsWrite+0x63f8>
 117f77e:	80 7d c5 01          	cmpb   $0x1,-0x3b(%rbp)
 117f782:	ba 03 00 00 00       	mov    $0x3,%edx
 117f787:	48 83 da 00          	sbb    $0x0,%rdx
 117f78b:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 117f78f:	b8 04 00 00 00       	mov    $0x4,%eax
 117f794:	48 0f 44 c2          	cmove  %rdx,%rax
 117f798:	48 8b 95 e8 fd ff ff 	mov    -0x218(%rbp),%rdx
 117f79f:	48 8d 5a 10          	lea    0x10(%rdx),%rbx
 117f7a3:	4c 8d b2 90 13 01 00 	lea    0x11390(%rdx),%r14
 117f7aa:	48 89 df             	mov    %rbx,%rdi
 117f7ad:	4c 89 f6             	mov    %r14,%rsi
 117f7b0:	48 8b 95 48 fc ff ff 	mov    -0x3b8(%rbp),%rdx
 117f7b7:	4c 8b 8d 28 ff ff ff 	mov    -0xd8(%rbp),%r9
 117f7be:	50                   	push   %rax
 117f7bf:	ff b5 40 fc ff ff    	push   -0x3c0(%rbp)
 117f7c5:	c5 f8 77             	vzeroupper 
 117f7c8:	e8 c3 13 00 00       	call   1180b90 <br.encoder.hq_codec.huffman_model.tables__anon_37371>
 117f7cd:	48 83 c4 10          	add    $0x10,%rsp
 117f7d1:	66 85 c0             	test   %ax,%ax
 117f7d4:	0f 85 33 9c ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117f7da:	48 8b 85 e8 fd ff ff 	mov    -0x218(%rbp),%rax
 117f7e1:	4c 8d b8 90 1f 01 00 	lea    0x11f90(%rax),%r15
 117f7e8:	49 c7 c4 00 04 ff ff 	mov    $0xffffffffffff0400,%r12
 117f7ef:	4b 8d 3c 27          	lea    (%r15,%r12,1),%rdi
 117f7f3:	48 81 c7 80 e0 ff ff 	add    $0xffffffffffffe080,%rdi
 117f7fa:	ba 00 04 00 00       	mov    $0x400,%edx
 117f7ff:	48 89 de             	mov    %rbx,%rsi
 117f802:	e8 b9 68 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117f807:	4b 8d 3c 27          	lea    (%r15,%r12,1),%rdi
 117f80b:	48 81 c7 00 f4 00 00 	add    $0xf400,%rdi
 117f812:	ba 00 04 00 00       	mov    $0x400,%edx
 117f817:	4c 89 f6             	mov    %r14,%rsi
 117f81a:	e8 a1 68 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117f81f:	4b 8d 3c 27          	lea    (%r15,%r12,1),%rdi
 117f823:	48 81 c7 80 e4 ff ff 	add    $0xffffffffffffe480,%rdi
 117f82a:	ba 00 04 00 00       	mov    $0x400,%edx
 117f82f:	48 89 de             	mov    %rbx,%rsi
 117f832:	e8 89 68 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117f837:	4b 8d 3c 27          	lea    (%r15,%r12,1),%rdi
 117f83b:	48 81 c7 00 f8 00 00 	add    $0xf800,%rdi
 117f842:	ba 00 04 00 00       	mov    $0x400,%edx
 117f847:	4c 89 f6             	mov    %r14,%rsi
 117f84a:	e8 71 68 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117f84f:	4b 8d 3c 27          	lea    (%r15,%r12,1),%rdi
 117f853:	48 81 c7 80 e8 ff ff 	add    $0xffffffffffffe880,%rdi
 117f85a:	ba 00 04 00 00       	mov    $0x400,%edx
 117f85f:	48 89 de             	mov    %rbx,%rsi
 117f862:	e8 59 68 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117f867:	4b 8d 3c 27          	lea    (%r15,%r12,1),%rdi
 117f86b:	48 81 c7 00 fc 00 00 	add    $0xfc00,%rdi
 117f872:	ba 00 04 00 00       	mov    $0x400,%edx
 117f877:	4c 89 f6             	mov    %r14,%rsi
 117f87a:	e8 41 68 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117f87f:	49 81 c4 00 0c 00 00 	add    $0xc00,%r12
 117f886:	0f 85 63 ff ff ff    	jne    117f7ef <br.encodeCommandPlanWithOptionsWrite+0x644f>
 117f88c:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 117f890:	74 2a                	je     117f8bc <br.encodeCommandPlanWithOptionsWrite+0x651c>
 117f892:	48 8d 85 d4 01 fe ff 	lea    -0x1fe2c(%rbp),%rax
 117f899:	48 89 85 38 fc ff ff 	mov    %rax,-0x3c8(%rbp)
 117f8a0:	48 8d 95 e8 fc fe ff 	lea    -0x10318(%rbp),%rdx
 117f8a7:	80 7d c1 00          	cmpb   $0x0,-0x3f(%rbp)
 117f8ab:	74 3a                	je     117f8e7 <br.encodeCommandPlanWithOptionsWrite+0x6547>
 117f8ad:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 117f8b4:	48 89 c1             	mov    %rax,%rcx
 117f8b7:	e9 20 01 00 00       	jmp    117f9dc <br.encodeCommandPlanWithOptionsWrite+0x663c>
 117f8bc:	48 8d 95 b0 c5 ff ff 	lea    -0x3a50(%rbp),%rdx
 117f8c3:	48 8d 85 2a cf ff ff 	lea    -0x30d6(%rbp),%rax
 117f8ca:	48 89 85 30 fd ff ff 	mov    %rax,-0x2d0(%rbp)
 117f8d1:	b8 01 00 00 00       	mov    $0x1,%eax
 117f8d6:	48 89 85 68 ff ff ff 	mov    %rax,-0x98(%rbp)
 117f8dd:	b9 01 00 00 00       	mov    $0x1,%ecx
 117f8e2:	e9 f5 00 00 00       	jmp    117f9dc <br.encodeCommandPlanWithOptionsWrite+0x663c>
 117f8e7:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 117f8eb:	89 c6                	mov    %eax,%esi
 117f8ed:	40 0a 75 c7          	or     -0x39(%rbp),%sil
 117f8f1:	0f b6 c0             	movzbl %al,%eax
 117f8f4:	40 f6 c6 01          	test   $0x1,%sil
 117f8f8:	0f 84 84 00 00 00    	je     117f982 <br.encodeCommandPlanWithOptionsWrite+0x65e2>
 117f8fe:	89 c1                	mov    %eax,%ecx
 117f900:	83 e1 01             	and    $0x1,%ecx
 117f903:	48 83 f1 03          	xor    $0x3,%rcx
 117f907:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 117f90b:	40 0f 95 c7          	setne  %dil
 117f90f:	80 7d cd 00          	cmpb   $0x0,-0x33(%rbp)
 117f913:	41 0f 95 c0          	setne  %r8b
 117f917:	41 08 f0             	or     %sil,%r8b
 117f91a:	44 0f b6 4d c7       	movzbl -0x39(%rbp),%r9d
 117f91f:	41 f6 d1             	not    %r9b
 117f922:	45 0f b6 c9          	movzbl %r9b,%r9d
 117f926:	41 83 e1 01          	and    $0x1,%r9d
 117f92a:	4f 8d 0c 49          	lea    (%r9,%r9,2),%r9
 117f92e:	49 83 c1 03          	add    $0x3,%r9
 117f932:	f6 45 d2 01          	testb  $0x1,-0x2e(%rbp)
 117f936:	41 ba 02 00 00 00    	mov    $0x2,%r10d
 117f93c:	4d 0f 44 d1          	cmove  %r9,%r10
 117f940:	44 08 c7             	or     %r8b,%dil
 117f943:	41 f6 c0 01          	test   $0x1,%r8b
 117f947:	41 b8 05 00 00 00    	mov    $0x5,%r8d
 117f94d:	4d 0f 45 c2          	cmovne %r10,%r8
 117f951:	4c 89 85 68 ff ff ff 	mov    %r8,-0x98(%rbp)
 117f958:	40 f6 c7 01          	test   $0x1,%dil
 117f95c:	75 3f                	jne    117f99d <br.encodeCommandPlanWithOptionsWrite+0x65fd>
 117f95e:	80 7d cb 01          	cmpb   $0x1,-0x35(%rbp)
 117f962:	bf 03 00 00 00       	mov    $0x3,%edi
 117f967:	48 83 df 00          	sbb    $0x0,%rdi
 117f96b:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 117f96f:	41 b8 04 00 00 00    	mov    $0x4,%r8d
 117f975:	4c 0f 44 c7          	cmove  %rdi,%r8
 117f979:	4c 89 85 68 ff ff ff 	mov    %r8,-0x98(%rbp)
 117f980:	eb 1b                	jmp    117f99d <br.encodeCommandPlanWithOptionsWrite+0x65fd>
 117f982:	b9 06 00 00 00       	mov    $0x6,%ecx
 117f987:	bf 06 00 00 00       	mov    $0x6,%edi
 117f98c:	48 89 bd 68 ff ff ff 	mov    %rdi,-0x98(%rbp)
 117f993:	80 7d cd 00          	cmpb   $0x0,-0x33(%rbp)
 117f997:	0f 84 a3 02 00 00    	je     117fc40 <br.encodeCommandPlanWithOptionsWrite+0x68a0>
 117f99d:	40 f6 c6 01          	test   $0x1,%sil
 117f9a1:	74 09                	je     117f9ac <br.encodeCommandPlanWithOptionsWrite+0x660c>
 117f9a3:	83 e0 01             	and    $0x1,%eax
 117f9a6:	48 83 f0 03          	xor    $0x3,%rax
 117f9aa:	eb 30                	jmp    117f9dc <br.encodeCommandPlanWithOptionsWrite+0x663c>
 117f9ac:	b8 06 00 00 00       	mov    $0x6,%eax
 117f9b1:	80 7d cd 00          	cmpb   $0x0,-0x33(%rbp)
 117f9b5:	75 25                	jne    117f9dc <br.encodeCommandPlanWithOptionsWrite+0x663c>
 117f9b7:	b8 05 00 00 00       	mov    $0x5,%eax
 117f9bc:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 117f9c0:	75 1a                	jne    117f9dc <br.encodeCommandPlanWithOptionsWrite+0x663c>
 117f9c2:	80 7d cb 01          	cmpb   $0x1,-0x35(%rbp)
 117f9c6:	be 03 00 00 00       	mov    $0x3,%esi
 117f9cb:	48 83 de 00          	sbb    $0x0,%rsi
 117f9cf:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 117f9d3:	b8 04 00 00 00       	mov    $0x4,%eax
 117f9d8:	48 0f 44 c6          	cmove  %rsi,%rax
 117f9dc:	48 8b b5 e8 fd ff ff 	mov    -0x218(%rbp),%rsi
 117f9e3:	48 8d be 10 00 01 00 	lea    0x10010(%rsi),%rdi
 117f9ea:	48 81 c6 90 13 02 00 	add    $0x21390,%rsi
 117f9f1:	4c 8b 85 30 fd ff ff 	mov    -0x2d0(%rbp),%r8
 117f9f8:	4c 8b 8d 68 ff ff ff 	mov    -0x98(%rbp),%r9
 117f9ff:	50                   	push   %rax
 117fa00:	ff b5 38 fc ff ff    	push   -0x3c8(%rbp)
 117fa06:	e8 85 0b 00 00       	call   1180590 <br.encoder.hq_codec.huffman_model.tables__anon_37381>
 117fa0b:	48 83 c4 10          	add    $0x10,%rsp
 117fa0f:	66 85 c0             	test   %ax,%ax
 117fa12:	0f 85 f5 99 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117fa18:	80 7d cc 00          	cmpb   $0x0,-0x34(%rbp)
 117fa1c:	74 2a                	je     117fa48 <br.encodeCommandPlanWithOptionsWrite+0x66a8>
 117fa1e:	4c 8d ad a0 9e ff ff 	lea    -0x6160(%rbp),%r13
 117fa25:	48 8d 85 38 cb ff ff 	lea    -0x34c8(%rbp),%rax
 117fa2c:	48 89 85 50 fe ff ff 	mov    %rax,-0x1b0(%rbp)
 117fa33:	80 7d c4 00          	cmpb   $0x0,-0x3c(%rbp)
 117fa37:	74 4f                	je     117fa88 <br.encodeCommandPlanWithOptionsWrite+0x66e8>
 117fa39:	4c 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%r14
 117fa40:	4d 89 f4             	mov    %r14,%r12
 117fa43:	e9 29 01 00 00       	jmp    117fb71 <br.encodeCommandPlanWithOptionsWrite+0x67d1>
 117fa48:	4c 8d ad 20 eb ff ff 	lea    -0x14e0(%rbp),%r13
 117fa4f:	48 8d 85 d0 f0 ff ff 	lea    -0xf30(%rbp),%rax
 117fa56:	48 89 85 50 fe ff ff 	mov    %rax,-0x1b0(%rbp)
 117fa5d:	48 8d 85 20 f2 ff ff 	lea    -0xde0(%rbp),%rax
 117fa64:	48 89 85 08 ff ff ff 	mov    %rax,-0xf8(%rbp)
 117fa6b:	b8 01 00 00 00       	mov    $0x1,%eax
 117fa70:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 117fa77:	41 bc 01 00 00 00    	mov    $0x1,%r12d
 117fa7d:	41 be 01 00 00 00    	mov    $0x1,%r14d
 117fa83:	e9 e9 00 00 00       	jmp    117fb71 <br.encodeCommandPlanWithOptionsWrite+0x67d1>
 117fa88:	0f b6 4d d3          	movzbl -0x2d(%rbp),%ecx
 117fa8c:	89 c8                	mov    %ecx,%eax
 117fa8e:	0a 45 c8             	or     -0x38(%rbp),%al
 117fa91:	44 0f b6 f1          	movzbl %cl,%r14d
 117fa95:	a8 01                	test   $0x1,%al
 117fa97:	74 7b                	je     117fb14 <br.encodeCommandPlanWithOptionsWrite+0x6774>
 117fa99:	45 89 f4             	mov    %r14d,%r12d
 117fa9c:	41 83 e4 01          	and    $0x1,%r12d
 117faa0:	49 83 f4 03          	xor    $0x3,%r12
 117faa4:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 117faa8:	0f 95 c1             	setne  %cl
 117faab:	80 7d ce 00          	cmpb   $0x0,-0x32(%rbp)
 117faaf:	0f 95 c2             	setne  %dl
 117fab2:	08 c2                	or     %al,%dl
 117fab4:	0f b6 75 c8          	movzbl -0x38(%rbp),%esi
 117fab8:	40 f6 d6             	not    %sil
 117fabb:	40 0f b6 f6          	movzbl %sil,%esi
 117fabf:	83 e6 01             	and    $0x1,%esi
 117fac2:	48 8d 34 76          	lea    (%rsi,%rsi,2),%rsi
 117fac6:	48 83 c6 03          	add    $0x3,%rsi
 117faca:	f6 45 d3 01          	testb  $0x1,-0x2d(%rbp)
 117face:	bf 02 00 00 00       	mov    $0x2,%edi
 117fad3:	48 0f 44 fe          	cmove  %rsi,%rdi
 117fad7:	08 d1                	or     %dl,%cl
 117fad9:	f6 c2 01             	test   $0x1,%dl
 117fadc:	ba 05 00 00 00       	mov    $0x5,%edx
 117fae1:	48 0f 45 d7          	cmovne %rdi,%rdx
 117fae5:	48 89 95 78 ff ff ff 	mov    %rdx,-0x88(%rbp)
 117faec:	f6 c1 01             	test   $0x1,%cl
 117faef:	75 3f                	jne    117fb30 <br.encodeCommandPlanWithOptionsWrite+0x6790>
 117faf1:	80 7d d5 01          	cmpb   $0x1,-0x2b(%rbp)
 117faf5:	b9 03 00 00 00       	mov    $0x3,%ecx
 117fafa:	48 83 d9 00          	sbb    $0x0,%rcx
 117fafe:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 117fb02:	ba 04 00 00 00       	mov    $0x4,%edx
 117fb07:	48 0f 44 d1          	cmove  %rcx,%rdx
 117fb0b:	48 89 95 78 ff ff ff 	mov    %rdx,-0x88(%rbp)
 117fb12:	eb 1c                	jmp    117fb30 <br.encodeCommandPlanWithOptionsWrite+0x6790>
 117fb14:	41 bc 06 00 00 00    	mov    $0x6,%r12d
 117fb1a:	b9 06 00 00 00       	mov    $0x6,%ecx
 117fb1f:	48 89 8d 78 ff ff ff 	mov    %rcx,-0x88(%rbp)
 117fb26:	80 7d ce 00          	cmpb   $0x0,-0x32(%rbp)
 117fb2a:	0f 84 3e 01 00 00    	je     117fc6e <br.encodeCommandPlanWithOptionsWrite+0x68ce>
 117fb30:	a8 01                	test   $0x1,%al
 117fb32:	74 0a                	je     117fb3e <br.encodeCommandPlanWithOptionsWrite+0x679e>
 117fb34:	41 83 e6 01          	and    $0x1,%r14d
 117fb38:	49 83 f6 03          	xor    $0x3,%r14
 117fb3c:	eb 33                	jmp    117fb71 <br.encodeCommandPlanWithOptionsWrite+0x67d1>
 117fb3e:	41 be 06 00 00 00    	mov    $0x6,%r14d
 117fb44:	80 7d ce 00          	cmpb   $0x0,-0x32(%rbp)
 117fb48:	75 27                	jne    117fb71 <br.encodeCommandPlanWithOptionsWrite+0x67d1>
 117fb4a:	41 be 05 00 00 00    	mov    $0x5,%r14d
 117fb50:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 117fb54:	75 1b                	jne    117fb71 <br.encodeCommandPlanWithOptionsWrite+0x67d1>
 117fb56:	80 7d d5 01          	cmpb   $0x1,-0x2b(%rbp)
 117fb5a:	b8 03 00 00 00       	mov    $0x3,%eax
 117fb5f:	48 83 d8 00          	sbb    $0x0,%rax
 117fb63:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 117fb67:	41 be 04 00 00 00    	mov    $0x4,%r14d
 117fb6d:	4c 0f 44 f0          	cmove  %rax,%r14
 117fb71:	48 8b 9d e8 fd ff ff 	mov    -0x218(%rbp),%rbx
 117fb78:	4c 8d bb 10 0b 01 00 	lea    0x10b10(%rbx),%r15
 117fb7f:	48 8d 35 6e ca ea ff 	lea    -0x153592(%rip),%rsi        # 102c5f4 <__anon_37393>
 117fb86:	ba 80 08 00 00       	mov    $0x880,%edx
 117fb8b:	4c 89 ff             	mov    %r15,%rdi
 117fb8e:	e8 2d 65 11 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 117fb93:	48 81 c3 90 1e 02 00 	add    $0x21e90,%rbx
 117fb9a:	ba 80 08 00 00       	mov    $0x880,%edx
 117fb9f:	48 89 df             	mov    %rbx,%rdi
 117fba2:	31 f6                	xor    %esi,%esi
 117fba4:	e8 f7 60 11 00       	call   1295ca0 <compiler_rt.memset>
 117fba9:	4c 89 ff             	mov    %r15,%rdi
 117fbac:	48 89 de             	mov    %rbx,%rsi
 117fbaf:	48 8b 95 50 fe ff ff 	mov    -0x1b0(%rbp),%rdx
 117fbb6:	4c 89 e1             	mov    %r12,%rcx
 117fbb9:	4c 8b 85 08 ff ff ff 	mov    -0xf8(%rbp),%r8
 117fbc0:	4c 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%r9
 117fbc7:	41 56                	push   %r14
 117fbc9:	41 55                	push   %r13
 117fbcb:	e8 30 03 00 00       	call   117ff00 <br.encoder.hq_codec.huffman_model.tables__anon_37396>
 117fbd0:	48 83 c4 10          	add    $0x10,%rsp
 117fbd4:	66 85 c0             	test   %ax,%ax
 117fbd7:	0f 85 30 98 ff ff    	jne    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117fbdd:	48 83 bd 08 fd ff ff 	cmpq   $0x0,-0x2f8(%rbp)
 117fbe4:	00 
 117fbe5:	74 3a                	je     117fc21 <br.encodeCommandPlanWithOptionsWrite+0x6881>
 117fbe7:	c5 fc 10 85 40 fd ff 	vmovups -0x2c0(%rbp),%ymm0
 117fbee:	ff 
 117fbef:	48 8b 85 08 fd ff ff 	mov    -0x2f8(%rbp),%rax
 117fbf6:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 117fbfa:	0f b6 85 3b ff ff ff 	movzbl -0xc5(%rbp),%eax
 117fc01:	88 85 50 fc ff ff    	mov    %al,-0x3b0(%rbp)
 117fc07:	84 c0                	test   %al,%al
 117fc09:	0f 85 fa 97 ff ff    	jne    1179409 <br.encodeCommandPlanWithOptionsWrite+0x69>
 117fc0f:	48 8b 85 60 fa ff ff 	mov    -0x5a0(%rbp),%rax
 117fc16:	48 8b 8d 08 fd ff ff 	mov    -0x2f8(%rbp),%rcx
 117fc1d:	48 89 41 20          	mov    %rax,0x20(%rcx)
 117fc21:	80 7d 9c 00          	cmpb   $0x0,-0x64(%rbp)
 117fc25:	74 12                	je     117fc39 <br.encodeCommandPlanWithOptionsWrite+0x6899>
 117fc27:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117fc2b:	f6 40 08 07          	testb  $0x7,0x8(%rax)
 117fc2f:	74 08                	je     117fc39 <br.encodeCommandPlanWithOptionsWrite+0x6899>
 117fc31:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 117fc35:	c6 40 08 00          	movb   $0x0,0x8(%rax)
 117fc39:	31 c0                	xor    %eax,%eax
 117fc3b:	e9 cd 97 ff ff       	jmp    117940d <br.encodeCommandPlanWithOptionsWrite+0x6d>
 117fc40:	b9 05 00 00 00       	mov    $0x5,%ecx
 117fc45:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 117fc49:	0f 85 b8 fc ff ff    	jne    117f907 <br.encodeCommandPlanWithOptionsWrite+0x6567>
 117fc4f:	80 7d cb 01          	cmpb   $0x1,-0x35(%rbp)
 117fc53:	bf 03 00 00 00       	mov    $0x3,%edi
 117fc58:	48 83 df 00          	sbb    $0x0,%rdi
 117fc5c:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 117fc60:	b9 04 00 00 00       	mov    $0x4,%ecx
 117fc65:	48 0f 44 cf          	cmove  %rdi,%rcx
 117fc69:	e9 99 fc ff ff       	jmp    117f907 <br.encodeCommandPlanWithOptionsWrite+0x6567>
 117fc6e:	41 bc 05 00 00 00    	mov    $0x5,%r12d
 117fc74:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 117fc78:	0f 85 26 fe ff ff    	jne    117faa4 <br.encodeCommandPlanWithOptionsWrite+0x6704>
 117fc7e:	80 7d d5 01          	cmpb   $0x1,-0x2b(%rbp)
 117fc82:	b9 03 00 00 00       	mov    $0x3,%ecx
 117fc87:	48 83 d9 00          	sbb    $0x0,%rcx
 117fc8b:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 117fc8f:	41 bc 04 00 00 00    	mov    $0x4,%r12d
 117fc95:	4c 0f 44 e1          	cmove  %rcx,%r12
 117fc99:	e9 06 fe ff ff       	jmp    117faa4 <br.encodeCommandPlanWithOptionsWrite+0x6704>
 117fc9e:	b9 05 00 00 00       	mov    $0x5,%ecx
 117fca3:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 117fca7:	0f 85 19 fa ff ff    	jne    117f6c6 <br.encodeCommandPlanWithOptionsWrite+0x6326>
 117fcad:	80 7d c5 01          	cmpb   $0x1,-0x3b(%rbp)
 117fcb1:	be 03 00 00 00       	mov    $0x3,%esi
 117fcb6:	48 83 de 00          	sbb    $0x0,%rsi
 117fcba:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 117fcbe:	b9 04 00 00 00       	mov    $0x4,%ecx
 117fcc3:	48 0f 44 ce          	cmove  %rsi,%rcx
 117fcc7:	e9 fa f9 ff ff       	jmp    117f6c6 <br.encodeCommandPlanWithOptionsWrite+0x6326>
 117fccc:	4d 39 c1             	cmp    %r8,%r9
 117fccf:	0f 86 c2 9e ff ff    	jbe    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117fcd5:	4c 89 c9             	mov    %r9,%rcx
 117fcd8:	49 39 f1             	cmp    %rsi,%r9
 117fcdb:	0f 83 b6 9e ff ff    	jae    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117fce1:	48 ff c2             	inc    %rdx
 117fce4:	48 39 d0             	cmp    %rdx,%rax
 117fce7:	0f 84 0d a6 ff ff    	je     117a2fa <br.encodeCommandPlanWithOptionsWrite+0xf5a>
 117fced:	48 8b bd c0 fd ff ff 	mov    -0x240(%rbp),%rdi
 117fcf4:	48 89 bd 68 fd ff ff 	mov    %rdi,-0x298(%rbp)
 117fcfb:	48 8b bd c8 fd ff ff 	mov    -0x238(%rbp),%rdi
 117fd02:	48 89 bd d0 fc ff ff 	mov    %rdi,-0x330(%rbp)
 117fd09:	48 8b bd d0 fd ff ff 	mov    -0x230(%rbp),%rdi
 117fd10:	48 89 bd d8 fc ff ff 	mov    %rdi,-0x328(%rbp)
 117fd17:	48 8b bd d8 fd ff ff 	mov    -0x228(%rbp),%rdi
 117fd1e:	48 89 bd e0 fc ff ff 	mov    %rdi,-0x320(%rbp)
 117fd25:	48 8d bd 68 fd ff ff 	lea    -0x298(%rbp),%rdi
 117fd2c:	4c 8d 05 f9 9f e8 ff 	lea    -0x176007(%rip),%r8        # 1009d2c <__anon_240364+0x72cc>
 117fd33:	4d 63 14 90          	movslq (%r8,%rdx,4),%r10
 117fd37:	4d 01 c2             	add    %r8,%r10
 117fd3a:	49 89 c8             	mov    %rcx,%r8
 117fd3d:	4c 8b 8d 38 fe ff ff 	mov    -0x1c8(%rbp),%r9
 117fd44:	41 ff e2             	jmp    *%r10
 117fd47:	48 8d bd d0 fc ff ff 	lea    -0x330(%rbp),%rdi
 117fd4e:	eb 10                	jmp    117fd60 <br.encodeCommandPlanWithOptionsWrite+0x69c0>
 117fd50:	48 8d bd d8 fc ff ff 	lea    -0x328(%rbp),%rdi
 117fd57:	eb 07                	jmp    117fd60 <br.encodeCommandPlanWithOptionsWrite+0x69c0>
 117fd59:	48 8d bd e0 fc ff ff 	lea    -0x320(%rbp),%rdi
 117fd60:	4c 8b 0f             	mov    (%rdi),%r9
 117fd63:	49 89 c8             	mov    %rcx,%r8
 117fd66:	e9 61 ff ff ff       	jmp    117fccc <br.encodeCommandPlanWithOptionsWrite+0x692c>
 117fd6b:	49 39 f8             	cmp    %rdi,%r8
 117fd6e:	0f 86 23 9e ff ff    	jbe    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117fd74:	4c 89 c1             	mov    %r8,%rcx
 117fd77:	48 ff c2             	inc    %rdx
 117fd7a:	48 39 d0             	cmp    %rdx,%rax
 117fd7d:	0f 84 d2 a7 ff ff    	je     117a555 <br.encodeCommandPlanWithOptionsWrite+0x11b5>
 117fd83:	48 8b b5 58 fe ff ff 	mov    -0x1a8(%rbp),%rsi
 117fd8a:	48 89 b5 60 fd ff ff 	mov    %rsi,-0x2a0(%rbp)
 117fd91:	48 8b b5 60 fe ff ff 	mov    -0x1a0(%rbp),%rsi
 117fd98:	48 89 b5 b8 fc ff ff 	mov    %rsi,-0x348(%rbp)
 117fd9f:	48 8b b5 68 fe ff ff 	mov    -0x198(%rbp),%rsi
 117fda6:	48 89 b5 c0 fc ff ff 	mov    %rsi,-0x340(%rbp)
 117fdad:	48 8b b5 70 fe ff ff 	mov    -0x190(%rbp),%rsi
 117fdb4:	48 89 b5 c8 fc ff ff 	mov    %rsi,-0x338(%rbp)
 117fdbb:	48 8d b5 60 fd ff ff 	lea    -0x2a0(%rbp),%rsi
 117fdc2:	48 8d 3d 77 9f e8 ff 	lea    -0x176089(%rip),%rdi        # 1009d40 <__anon_240364+0x72e0>
 117fdc9:	4c 63 0c 97          	movslq (%rdi,%rdx,4),%r9
 117fdcd:	49 01 f9             	add    %rdi,%r9
 117fdd0:	48 89 cf             	mov    %rcx,%rdi
 117fdd3:	4c 8b 85 c8 fe ff ff 	mov    -0x138(%rbp),%r8
 117fdda:	41 ff e1             	jmp    *%r9
 117fddd:	48 8d b5 b8 fc ff ff 	lea    -0x348(%rbp),%rsi
 117fde4:	eb 10                	jmp    117fdf6 <br.encodeCommandPlanWithOptionsWrite+0x6a56>
 117fde6:	48 8d b5 c0 fc ff ff 	lea    -0x340(%rbp),%rsi
 117fded:	eb 07                	jmp    117fdf6 <br.encodeCommandPlanWithOptionsWrite+0x6a56>
 117fdef:	48 8d b5 c8 fc ff ff 	lea    -0x338(%rbp),%rsi
 117fdf6:	4c 8b 06             	mov    (%rsi),%r8
 117fdf9:	48 89 cf             	mov    %rcx,%rdi
 117fdfc:	e9 6a ff ff ff       	jmp    117fd6b <br.encodeCommandPlanWithOptionsWrite+0x69cb>
 117fe01:	4c 39 45 90          	cmp    %r8,-0x70(%rbp)
 117fe05:	0f 86 8c 9d ff ff    	jbe    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117fe0b:	48 ff c1             	inc    %rcx
 117fe0e:	48 39 c8             	cmp    %rcx,%rax
 117fe11:	48 8b bd 10 ff ff ff 	mov    -0xf0(%rbp),%rdi
 117fe18:	4c 8b 85 18 ff ff ff 	mov    -0xe8(%rbp),%r8
 117fe1f:	4c 8b 8d 20 ff ff ff 	mov    -0xe0(%rbp),%r9
 117fe26:	0f 84 43 b5 ff ff    	je     117b36f <br.encodeCommandPlanWithOptionsWrite+0x1fcf>
 117fe2c:	48 89 bd f8 fb ff ff 	mov    %rdi,-0x408(%rbp)
 117fe33:	4c 89 85 00 fc ff ff 	mov    %r8,-0x400(%rbp)
 117fe3a:	4c 89 8d 08 fc ff ff 	mov    %r9,-0x3f8(%rbp)
 117fe41:	4c 89 95 10 fc ff ff 	mov    %r10,-0x3f0(%rbp)
 117fe48:	4c 63 0c 8e          	movslq (%rsi,%rcx,4),%r9
 117fe4c:	49 01 f1             	add    %rsi,%r9
 117fe4f:	48 89 d7             	mov    %rdx,%rdi
 117fe52:	4c 8b 85 60 ff ff ff 	mov    -0xa0(%rbp),%r8
 117fe59:	41 ff e1             	jmp    *%r9
 117fe5c:	48 8d bd 00 fc ff ff 	lea    -0x400(%rbp),%rdi
 117fe63:	eb 10                	jmp    117fe75 <br.encodeCommandPlanWithOptionsWrite+0x6ad5>
 117fe65:	48 8d bd 08 fc ff ff 	lea    -0x3f8(%rbp),%rdi
 117fe6c:	eb 07                	jmp    117fe75 <br.encodeCommandPlanWithOptionsWrite+0x6ad5>
 117fe6e:	48 8d bd 10 fc ff ff 	lea    -0x3f0(%rbp),%rdi
 117fe75:	4c 8b 07             	mov    (%rdi),%r8
 117fe78:	eb 87                	jmp    117fe01 <br.encodeCommandPlanWithOptionsWrite+0x6a61>
 117fe7a:	4c 39 85 38 fd ff ff 	cmp    %r8,-0x2c8(%rbp)
 117fe81:	0f 86 10 9d ff ff    	jbe    1179b97 <br.encodeCommandPlanWithOptionsWrite+0x7f7>
 117fe87:	48 ff c1             	inc    %rcx
 117fe8a:	48 39 c8             	cmp    %rcx,%rax
 117fe8d:	0f 84 54 b6 ff ff    	je     117b4e7 <br.encodeCommandPlanWithOptionsWrite+0x2147>
 117fe93:	48 8b bd 58 fe ff ff 	mov    -0x1a8(%rbp),%rdi
 117fe9a:	48 89 bd d8 fb ff ff 	mov    %rdi,-0x428(%rbp)
 117fea1:	48 8b bd 60 fe ff ff 	mov    -0x1a0(%rbp),%rdi
 117fea8:	48 89 bd e0 fb ff ff 	mov    %rdi,-0x420(%rbp)
 117feaf:	48 8b bd 68 fe ff ff 	mov    -0x198(%rbp),%rdi
 117feb6:	48 89 bd e8 fb ff ff 	mov    %rdi,-0x418(%rbp)
 117febd:	48 8b bd 70 fe ff ff 	mov    -0x190(%rbp),%rdi
 117fec4:	48 89 bd f0 fb ff ff 	mov    %rdi,-0x410(%rbp)
 117fecb:	4c 63 0c 8e          	movslq (%rsi,%rcx,4),%r9
 117fecf:	49 01 f1             	add    %rsi,%r9
 117fed2:	48 89 d7             	mov    %rdx,%rdi
 117fed5:	4c 8b 85 c8 fe ff ff 	mov    -0x138(%rbp),%r8
 117fedc:	41 ff e1             	jmp    *%r9
 117fedf:	48 8d bd e0 fb ff ff 	lea    -0x420(%rbp),%rdi
 117fee6:	eb 10                	jmp    117fef8 <br.encodeCommandPlanWithOptionsWrite+0x6b58>
 117fee8:	48 8d bd e8 fb ff ff 	lea    -0x418(%rbp),%rdi
 117feef:	eb 07                	jmp    117fef8 <br.encodeCommandPlanWithOptionsWrite+0x6b58>
 117fef1:	48 8d bd f0 fb ff ff 	lea    -0x410(%rbp),%rdi
 117fef8:	4c 8b 07             	mov    (%rdi),%r8
 117fefb:	e9 7a ff ff ff       	jmp    117fe7a <br.encodeCommandPlanWithOptionsWrite+0x6ada>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
