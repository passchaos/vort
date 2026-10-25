
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

0000000001268fe0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228>:
 1268fe0:	55                   	push   %rbp
 1268fe1:	48 89 e5             	mov    %rsp,%rbp
 1268fe4:	41 57                	push   %r15
 1268fe6:	41 56                	push   %r14
 1268fe8:	41 55                	push   %r13
 1268fea:	41 54                	push   %r12
 1268fec:	53                   	push   %rbx
 1268fed:	48 81 ec 68 1e 00 00 	sub    $0x1e68,%rsp
 1268ff4:	4c 89 cb             	mov    %r9,%rbx
 1268ff7:	4d 89 c6             	mov    %r8,%r14
 1268ffa:	48 89 4d b0          	mov    %rcx,-0x50(%rbp)
 1268ffe:	49 89 d5             	mov    %rdx,%r13
 1269001:	48 89 7d b8          	mov    %rdi,-0x48(%rbp)
 1269005:	4c 8b 7d 18          	mov    0x18(%rbp),%r15
 1269009:	4c 8b 65 10          	mov    0x10(%rbp),%r12
 126900d:	c5 fc 10 06          	vmovups (%rsi),%ymm0
 1269011:	c5 fc 11 85 00 ff ff 	vmovups %ymm0,-0x100(%rbp)
 1269018:	ff 
 1269019:	48 89 75 c0          	mov    %rsi,-0x40(%rbp)
 126901d:	c5 fc 10 06          	vmovups (%rsi),%ymm0
 1269021:	c5 fc 11 85 60 fd ff 	vmovups %ymm0,-0x2a0(%rbp)
 1269028:	ff 
 1269029:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 1269030:	48 8d b5 60 fd ff ff 	lea    -0x2a0(%rbp),%rsi
 1269037:	ba 0a 00 00 00       	mov    $0xa,%edx
 126903c:	4c 89 c1             	mov    %r8,%rcx
 126903f:	4d 89 e0             	mov    %r12,%r8
 1269042:	c5 f8 77             	vzeroupper 
 1269045:	e8 46 e5 00 00       	call   1277590 <br.encoder.quality_profile.Active.begin>
 126904a:	49 83 fc 02          	cmp    $0x2,%r12
 126904e:	4c 89 6d a8          	mov    %r13,-0x58(%rbp)
 1269052:	4c 89 75 90          	mov    %r14,-0x70(%rbp)
 1269056:	48 89 5d 98          	mov    %rbx,-0x68(%rbp)
 126905a:	0f 85 b5 02 00 00    	jne    1269315 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x335>
 1269060:	80 7b 58 01          	cmpb   $0x1,0x58(%rbx)
 1269064:	0f 85 ab 02 00 00    	jne    1269315 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x335>
 126906a:	f6 43 59 03          	testb  $0x3,0x59(%rbx)
 126906e:	0f 85 a1 02 00 00    	jne    1269315 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x335>
 1269074:	48 83 7b 10 03       	cmpq   $0x3,0x10(%rbx)
 1269079:	0f 85 96 02 00 00    	jne    1269315 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x335>
 126907f:	48 83 ec 08          	sub    $0x8,%rsp
 1269083:	48 8d bd 58 f2 ff ff 	lea    -0xda8(%rbp),%rdi
 126908a:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 126908e:	4c 89 ea             	mov    %r13,%rdx
 1269091:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 1269095:	4d 89 f0             	mov    %r14,%r8
 1269098:	49 89 d9             	mov    %rbx,%r9
 126909b:	ff 75 20             	push   0x20(%rbp)
 126909e:	41 57                	push   %r15
 12690a0:	6a 02                	push   $0x2
 12690a2:	e8 69 aa 00 00       	call   1273b10 <br.encodePreferredCommandPlanAllocRecorded__anon_231663>
 12690a7:	48 83 c4 20          	add    $0x20,%rsp
 12690ab:	0f b7 85 b8 f3 ff ff 	movzwl -0xc48(%rbp),%eax
 12690b2:	48 85 c0             	test   %rax,%rax
 12690b5:	0f 85 50 10 00 00    	jne    126a10b <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x112b>
 12690bb:	48 8d bd 30 f9 ff ff 	lea    -0x6d0(%rbp),%rdi
 12690c2:	48 8d b5 58 f2 ff ff 	lea    -0xda8(%rbp),%rsi
 12690c9:	ba 60 01 00 00       	mov    $0x160,%edx
 12690ce:	e8 8d 66 07 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 12690d3:	48 8b 85 30 f9 ff ff 	mov    -0x6d0(%rbp),%rax
 12690da:	48 89 45 c8          	mov    %rax,-0x38(%rbp)
 12690de:	48 8b 85 38 f9 ff ff 	mov    -0x6c8(%rbp),%rax
 12690e5:	48 89 45 d0          	mov    %rax,-0x30(%rbp)
 12690e9:	48 c7 85 b8 fe ff ff 	movq   $0x0,-0x148(%rbp)
 12690f0:	00 00 00 00 
 12690f4:	48 8d 85 b8 fe ff ff 	lea    -0x148(%rbp),%rax
 12690fb:	48 8d bd d0 fe ff ff 	lea    -0x130(%rbp),%rdi
 1269102:	48 8d b5 78 ed ff ff 	lea    -0x1288(%rbp),%rsi
 1269109:	ba 02 00 00 00       	mov    $0x2,%edx
 126910e:	41 b9 02 00 00 00    	mov    $0x2,%r9d
 1269114:	4c 89 f1             	mov    %r14,%rcx
 1269117:	49 89 d8             	mov    %rbx,%r8
 126911a:	6a 01                	push   $0x1
 126911c:	50                   	push   %rax
 126911d:	e8 0e 52 fd ff       	call   123e330 <br.encoder.command_plan.withoutCopiesInto>
 1269122:	48 83 c4 10          	add    $0x10,%rsp
 1269126:	0f b7 9d e0 fe ff ff 	movzwl -0x120(%rbp),%ebx
 126912d:	48 85 db             	test   %rbx,%rbx
 1269130:	0f 85 21 10 00 00    	jne    126a157 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x1177>
 1269136:	4c 8b a5 d0 fe ff ff 	mov    -0x130(%rbp),%r12
 126913d:	4c 8b 95 d8 fe ff ff 	mov    -0x128(%rbp),%r10
 1269144:	c5 f8 28 85 00 ff ff 	vmovaps -0x100(%rbp),%xmm0
 126914b:	ff 
 126914c:	c5 f8 29 85 90 fe ff 	vmovaps %xmm0,-0x170(%rbp)
 1269153:	ff 
 1269154:	c5 f8 10 85 09 ff ff 	vmovups -0xf7(%rbp),%xmm0
 126915b:	ff 
 126915c:	c5 f8 11 85 99 fe ff 	vmovups %xmm0,-0x167(%rbp)
 1269163:	ff 
 1269164:	c6 85 d0 fe ff ff 01 	movb   $0x1,-0x130(%rbp)
 126916b:	c6 85 a9 fe ff ff 01 	movb   $0x1,-0x157(%rbp)
 1269172:	8b 85 1a ff ff ff    	mov    -0xe6(%rbp),%eax
 1269178:	89 85 aa fe ff ff    	mov    %eax,-0x156(%rbp)
 126917e:	0f b7 85 1e ff ff ff 	movzwl -0xe2(%rbp),%eax
 1269185:	66 89 85 ae fe ff ff 	mov    %ax,-0x152(%rbp)
 126918c:	48 83 ec 08          	sub    $0x8,%rsp
 1269190:	48 8d bd f0 f0 ff ff 	lea    -0xf10(%rbp),%rdi
 1269197:	48 8d b5 90 fe ff ff 	lea    -0x170(%rbp),%rsi
 126919e:	4c 89 ea             	mov    %r13,%rdx
 12691a1:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 12691a5:	4d 89 f0             	mov    %r14,%r8
 12691a8:	4d 89 e1             	mov    %r12,%r9
 12691ab:	ff 75 20             	push   0x20(%rbp)
 12691ae:	41 57                	push   %r15
 12691b0:	4c 89 55 a0          	mov    %r10,-0x60(%rbp)
 12691b4:	41 52                	push   %r10
 12691b6:	e8 55 a9 00 00       	call   1273b10 <br.encodePreferredCommandPlanAllocRecorded__anon_231663>
 12691bb:	48 83 c4 20          	add    $0x20,%rsp
 12691bf:	0f b7 9d 50 f2 ff ff 	movzwl -0xdb0(%rbp),%ebx
 12691c6:	48 85 db             	test   %rbx,%rbx
 12691c9:	0f 85 91 0f 00 00    	jne    126a160 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x1180>
 12691cf:	48 8d 9d 20 f5 ff ff 	lea    -0xae0(%rbp),%rbx
 12691d6:	48 8d b5 f0 f0 ff ff 	lea    -0xf10(%rbp),%rsi
 12691dd:	ba 60 01 00 00       	mov    $0x160,%edx
 12691e2:	48 89 df             	mov    %rbx,%rdi
 12691e5:	e8 76 65 07 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 12691ea:	4c 8b b5 20 f5 ff ff 	mov    -0xae0(%rbp),%r14
 12691f1:	4c 8b ad 28 f5 ff ff 	mov    -0xad8(%rbp),%r13
 12691f8:	48 8d bd 00 ff ff ff 	lea    -0x100(%rbp),%rdi
 12691ff:	4c 89 f6             	mov    %r14,%rsi
 1269202:	4c 89 ea             	mov    %r13,%rdx
 1269205:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 1269209:	4c 8b 45 d0          	mov    -0x30(%rbp),%r8
 126920d:	e8 ce 4d fd ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 1269212:	a8 01                	test   $0x1,%al
 1269214:	0f 84 e2 0a 00 00    	je     1269cfc <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xd1c>
 126921a:	c5 f8 28 85 00 ff ff 	vmovaps -0x100(%rbp),%xmm0
 1269221:	ff 
 1269222:	c5 f8 29 85 70 fe ff 	vmovaps %xmm0,-0x190(%rbp)
 1269229:	ff 
 126922a:	c5 f8 10 85 09 ff ff 	vmovups -0xf7(%rbp),%xmm0
 1269231:	ff 
 1269232:	c5 f8 11 85 79 fe ff 	vmovups %xmm0,-0x187(%rbp)
 1269239:	ff 
 126923a:	c6 85 d0 fe ff ff 01 	movb   $0x1,-0x130(%rbp)
 1269241:	c6 85 89 fe ff ff 01 	movb   $0x1,-0x177(%rbp)
 1269248:	8b 85 1a ff ff ff    	mov    -0xe6(%rbp),%eax
 126924e:	89 85 8a fe ff ff    	mov    %eax,-0x176(%rbp)
 1269254:	0f b7 85 1e ff ff ff 	movzwl -0xe2(%rbp),%eax
 126925b:	66 89 85 8e fe ff ff 	mov    %ax,-0x172(%rbp)
 1269262:	48 8d bd 38 fe ff ff 	lea    -0x1c8(%rbp),%rdi
 1269269:	48 8d b5 70 fe ff ff 	lea    -0x190(%rbp),%rsi
 1269270:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 1269274:	4c 89 fa             	mov    %r15,%rdx
 1269277:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 126927b:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 126927f:	4d 89 e1             	mov    %r12,%r9
 1269282:	53                   	push   %rbx
 1269283:	ff 75 20             	push   0x20(%rbp)
 1269286:	ff 75 18             	push   0x18(%rbp)
 1269289:	ff 75 a0             	push   -0x60(%rbp)
 126928c:	e8 ff 0e 00 00       	call   126a190 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669>
 1269291:	48 83 c4 20          	add    $0x20,%rsp
 1269295:	0f b7 9d 48 fe ff ff 	movzwl -0x1b8(%rbp),%ebx
 126929c:	48 85 db             	test   %rbx,%rbx
 126929f:	0f 84 0d 0c 00 00    	je     1269eb2 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xed2>
 12692a5:	4c 8b 65 c0          	mov    -0x40(%rbp),%r12
 12692a9:	4c 89 e7             	mov    %r12,%rdi
 12692ac:	4c 89 fe             	mov    %r15,%rsi
 12692af:	4c 89 f2             	mov    %r14,%rdx
 12692b2:	4c 89 e9             	mov    %r13,%rcx
 12692b5:	e8 e6 d2 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 12692ba:	4c 89 e7             	mov    %r12,%rdi
 12692bd:	4c 89 fe             	mov    %r15,%rsi
 12692c0:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 12692c4:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 12692c8:	e8 d3 d2 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 12692cd:	80 bd 58 ff ff ff 00 	cmpb   $0x0,-0xa8(%rbp)
 12692d4:	4c 8b 75 b8          	mov    -0x48(%rbp),%r14
 12692d8:	74 25                	je     12692ff <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x31f>
 12692da:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 12692e1:	48 69 8d 50 ff ff ff 	imul   $0x118,-0xb0(%rbp),%rcx
 12692e8:	18 01 00 00 
 12692ec:	89 da                	mov    %ebx,%edx
 12692ee:	c1 e2 04             	shl    $0x4,%edx
 12692f1:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 12692f8:	01 
 12692f9:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 12692ff:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 1269306:	e8 65 de 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 126930b:	66 41 89 5e 10       	mov    %bx,0x10(%r14)
 1269310:	e9 86 08 00 00       	jmp    1269b9b <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xbbb>
 1269315:	48 8d bd 88 fd ff ff 	lea    -0x278(%rbp),%rdi
 126931c:	48 89 de             	mov    %rbx,%rsi
 126931f:	4c 89 e2             	mov    %r12,%rdx
 1269322:	e8 d9 5b fd ff       	call   123ef00 <br.encoder.short_match_candidates.collect>
 1269327:	48 8b 85 88 fd ff ff 	mov    -0x278(%rbp),%rax
 126932e:	48 89 85 c0 fe ff ff 	mov    %rax,-0x140(%rbp)
 1269335:	48 83 ec 08          	sub    $0x8,%rsp
 1269339:	48 85 c0             	test   %rax,%rax
 126933c:	0f 84 b2 06 00 00    	je     12699f4 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xa14>
 1269342:	48 8d bd f8 fb ff ff 	lea    -0x408(%rbp),%rdi
 1269349:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 126934d:	4c 89 ea             	mov    %r13,%rdx
 1269350:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 1269354:	4d 89 f0             	mov    %r14,%r8
 1269357:	49 89 d9             	mov    %rbx,%r9
 126935a:	ff 75 20             	push   0x20(%rbp)
 126935d:	41 57                	push   %r15
 126935f:	ff 75 10             	push   0x10(%rbp)
 1269362:	e8 a9 a7 00 00       	call   1273b10 <br.encodePreferredCommandPlanAllocRecorded__anon_231663>
 1269367:	48 83 c4 20          	add    $0x20,%rsp
 126936b:	44 0f b7 a5 58 fd ff 	movzwl -0x2a8(%rbp),%r12d
 1269372:	ff 
 1269373:	4d 85 e4             	test   %r12,%r12
 1269376:	0f 85 8d 0c 00 00    	jne    126a009 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x1029>
 126937c:	48 8b 85 f8 fb ff ff 	mov    -0x408(%rbp),%rax
 1269383:	48 89 45 d0          	mov    %rax,-0x30(%rbp)
 1269387:	48 8b 85 00 fc ff ff 	mov    -0x400(%rbp),%rax
 126938e:	48 89 45 c8          	mov    %rax,-0x38(%rbp)
 1269392:	48 8d b5 08 fc ff ff 	lea    -0x3f8(%rbp),%rsi
 1269399:	48 8d bd 80 f6 ff ff 	lea    -0x980(%rbp),%rdi
 12693a0:	ba 50 01 00 00       	mov    $0x150,%edx
 12693a5:	e8 b6 63 07 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 12693aa:	4c 8b 4d 10          	mov    0x10(%rbp),%r9
 12693ae:	44 89 c8             	mov    %r9d,%eax
 12693b1:	83 e0 03             	and    $0x3,%eax
 12693b4:	48 89 85 e8 fe ff ff 	mov    %rax,-0x118(%rbp)
 12693bb:	4d 89 cc             	mov    %r9,%r12
 12693be:	49 83 e4 fc          	and    $0xfffffffffffffffc,%r12
 12693c2:	31 c0                	xor    %eax,%eax
 12693c4:	4c 89 8d f0 fe ff ff 	mov    %r9,-0x110(%rbp)
 12693cb:	48 89 9d f8 fe ff ff 	mov    %rbx,-0x108(%rbp)
 12693d2:	49 89 d8             	mov    %rbx,%r8
 12693d5:	4c 89 a5 c8 fe ff ff 	mov    %r12,-0x138(%rbp)
 12693dc:	e9 8d 00 00 00       	jmp    126946e <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x48e>
 12693e1:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 12693e8:	0f 1f 84 00 00 00 00 
 12693ef:	00 
 12693f0:	ba 50 01 00 00       	mov    $0x150,%edx
 12693f5:	48 8d bd 80 f6 ff ff 	lea    -0x980(%rbp),%rdi
 12693fc:	48 8d b5 38 ee ff ff 	lea    -0x11c8(%rbp),%rsi
 1269403:	e8 58 63 07 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 1269408:	48 89 d8             	mov    %rbx,%rax
 126940b:	48 c1 e0 05          	shl    $0x5,%rax
 126940f:	48 8d 14 40          	lea    (%rax,%rax,2),%rdx
 1269413:	4c 8d ad 78 e7 ff ff 	lea    -0x1888(%rbp),%r13
 126941a:	4c 89 ef             	mov    %r13,%rdi
 126941d:	4c 89 f6             	mov    %r14,%rsi
 1269420:	e8 3b 63 07 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 1269425:	48 8b 45 88          	mov    -0x78(%rbp),%rax
 1269429:	48 89 45 d0          	mov    %rax,-0x30(%rbp)
 126942d:	4c 89 7d c8          	mov    %r15,-0x38(%rbp)
 1269431:	4c 89 ad f8 fe ff ff 	mov    %r13,-0x108(%rbp)
 1269438:	48 89 9d f0 fe ff ff 	mov    %rbx,-0x110(%rbp)
 126943f:	4c 8b 75 90          	mov    -0x70(%rbp),%r14
 1269443:	4c 8b 45 98          	mov    -0x68(%rbp),%r8
 1269447:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 126944b:	48 ff c0             	inc    %rax
 126944e:	48 3b 85 c0 fe ff ff 	cmp    -0x140(%rbp),%rax
 1269455:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 1269459:	4c 8b 7d 18          	mov    0x18(%rbp),%r15
 126945d:	4c 8b 4d 10          	mov    0x10(%rbp),%r9
 1269461:	4c 8b a5 c8 fe ff ff 	mov    -0x138(%rbp),%r12
 1269468:	0f 84 4e 04 00 00    	je     12698bc <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x8dc>
 126946e:	4d 85 c9             	test   %r9,%r9
 1269471:	48 89 45 a0          	mov    %rax,-0x60(%rbp)
 1269475:	0f 84 b5 00 00 00    	je     1269530 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x550>
 126947b:	0f b7 84 45 90 fd ff 	movzwl -0x270(%rbp,%rax,2),%eax
 1269482:	ff 
 1269483:	31 c9                	xor    %ecx,%ecx
 1269485:	45 31 d2             	xor    %r10d,%r10d
 1269488:	49 83 f9 04          	cmp    $0x4,%r9
 126948c:	73 4b                	jae    12694d9 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x4f9>
 126948e:	48 83 bd e8 fe ff ff 	cmpq   $0x0,-0x118(%rbp)
 1269495:	00 
 1269496:	0f 84 97 00 00 00    	je     1269533 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x553>
 126949c:	48 8b 95 e8 fe ff ff 	mov    -0x118(%rbp),%rdx
 12694a3:	eb 13                	jmp    12694b8 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x4d8>
 12694a5:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 12694ac:	00 00 00 00 
 12694b0:	48 ff c1             	inc    %rcx
 12694b3:	48 ff ca             	dec    %rdx
 12694b6:	74 7b                	je     1269533 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x553>
 12694b8:	0f a3 c8             	bt     %ecx,%eax
 12694bb:	73 f3                	jae    12694b0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x4d0>
 12694bd:	4a 89 8c d5 50 fe ff 	mov    %rcx,-0x1b0(%rbp,%r10,8)
 12694c4:	ff 
 12694c5:	49 ff c2             	inc    %r10
 12694c8:	eb e6                	jmp    12694b0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x4d0>
 12694ca:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 12694d0:	48 83 c1 04          	add    $0x4,%rcx
 12694d4:	49 39 cc             	cmp    %rcx,%r12
 12694d7:	74 b5                	je     126948e <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x4ae>
 12694d9:	0f a3 c8             	bt     %ecx,%eax
 12694dc:	73 0b                	jae    12694e9 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x509>
 12694de:	4a 89 8c d5 50 fe ff 	mov    %rcx,-0x1b0(%rbp,%r10,8)
 12694e5:	ff 
 12694e6:	49 ff c2             	inc    %r10
 12694e9:	48 8d 51 01          	lea    0x1(%rcx),%rdx
 12694ed:	0f a3 d0             	bt     %edx,%eax
 12694f0:	73 0b                	jae    12694fd <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x51d>
 12694f2:	4a 89 94 d5 50 fe ff 	mov    %rdx,-0x1b0(%rbp,%r10,8)
 12694f9:	ff 
 12694fa:	49 ff c2             	inc    %r10
 12694fd:	48 8d 51 02          	lea    0x2(%rcx),%rdx
 1269501:	0f a3 d0             	bt     %edx,%eax
 1269504:	73 0b                	jae    1269511 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x531>
 1269506:	4a 89 94 d5 50 fe ff 	mov    %rdx,-0x1b0(%rbp,%r10,8)
 126950d:	ff 
 126950e:	49 ff c2             	inc    %r10
 1269511:	48 8d 51 03          	lea    0x3(%rcx),%rdx
 1269515:	0f a3 d0             	bt     %edx,%eax
 1269518:	73 b6                	jae    12694d0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x4f0>
 126951a:	4a 89 94 d5 50 fe ff 	mov    %rdx,-0x1b0(%rbp,%r10,8)
 1269521:	ff 
 1269522:	49 ff c2             	inc    %r10
 1269525:	eb a9                	jmp    12694d0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x4f0>
 1269527:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 126952e:	00 00 
 1269530:	45 31 d2             	xor    %r10d,%r10d
 1269533:	ba 10 00 00 00       	mov    $0x10,%edx
 1269538:	48 8d bd 08 fe ff ff 	lea    -0x1f8(%rbp),%rdi
 126953f:	48 8d b5 78 e1 ff ff 	lea    -0x1e88(%rbp),%rsi
 1269546:	4c 89 f1             	mov    %r14,%rcx
 1269549:	41 52                	push   %r10
 126954b:	48 8d 85 50 fe ff ff 	lea    -0x1b0(%rbp),%rax
 1269552:	50                   	push   %rax
 1269553:	e8 d8 4d fd ff       	call   123e330 <br.encoder.command_plan.withoutCopiesInto>
 1269558:	48 83 c4 10          	add    $0x10,%rsp
 126955c:	0f b7 9d 18 fe ff ff 	movzwl -0x1e8(%rbp),%ebx
 1269563:	48 85 db             	test   %rbx,%rbx
 1269566:	0f 85 8e 08 00 00    	jne    1269dfa <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xe1a>
 126956c:	4d 89 f0             	mov    %r14,%r8
 126956f:	4c 8b b5 08 fe ff ff 	mov    -0x1f8(%rbp),%r14
 1269576:	48 8b 9d 10 fe ff ff 	mov    -0x1f0(%rbp),%rbx
 126957d:	c5 f8 10 85 09 ff ff 	vmovups -0xf7(%rbp),%xmm0
 1269584:	ff 
 1269585:	c5 f8 11 85 b9 fd ff 	vmovups %xmm0,-0x247(%rbp)
 126958c:	ff 
 126958d:	c5 f8 28 85 00 ff ff 	vmovaps -0x100(%rbp),%xmm0
 1269594:	ff 
 1269595:	c5 f8 29 85 b0 fd ff 	vmovaps %xmm0,-0x250(%rbp)
 126959c:	ff 
 126959d:	c6 85 d0 fe ff ff 01 	movb   $0x1,-0x130(%rbp)
 12695a4:	c6 85 c9 fd ff ff 01 	movb   $0x1,-0x237(%rbp)
 12695ab:	48 8d 95 1a ff ff ff 	lea    -0xe6(%rbp),%rdx
 12695b2:	0f b7 42 04          	movzwl 0x4(%rdx),%eax
 12695b6:	48 8d 8d ca fd ff ff 	lea    -0x236(%rbp),%rcx
 12695bd:	66 89 41 04          	mov    %ax,0x4(%rcx)
 12695c1:	8b 02                	mov    (%rdx),%eax
 12695c3:	89 01                	mov    %eax,(%rcx)
 12695c5:	48 83 ec 08          	sub    $0x8,%rsp
 12695c9:	48 8d bd 90 fa ff ff 	lea    -0x570(%rbp),%rdi
 12695d0:	48 8d b5 b0 fd ff ff 	lea    -0x250(%rbp),%rsi
 12695d7:	4c 89 ea             	mov    %r13,%rdx
 12695da:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 12695de:	4d 89 f1             	mov    %r14,%r9
 12695e1:	ff 75 20             	push   0x20(%rbp)
 12695e4:	41 57                	push   %r15
 12695e6:	53                   	push   %rbx
 12695e7:	e8 24 a5 00 00       	call   1273b10 <br.encodePreferredCommandPlanAllocRecorded__anon_231663>
 12695ec:	48 83 c4 20          	add    $0x20,%rsp
 12695f0:	44 0f b7 bd f0 fb ff 	movzwl -0x410(%rbp),%r15d
 12695f7:	ff 
 12695f8:	4d 85 ff             	test   %r15,%r15
 12695fb:	0f 85 54 08 00 00    	jne    1269e55 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xe75>
 1269601:	4c 8b a5 90 fa ff ff 	mov    -0x570(%rbp),%r12
 1269608:	4c 8b bd 98 fa ff ff 	mov    -0x568(%rbp),%r15
 126960f:	ba 50 01 00 00       	mov    $0x150,%edx
 1269614:	48 8d bd 38 ee ff ff 	lea    -0x11c8(%rbp),%rdi
 126961b:	48 8d b5 a0 fa ff ff 	lea    -0x560(%rbp),%rsi
 1269622:	e8 39 61 07 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 1269627:	48 8d bd 00 ff ff ff 	lea    -0x100(%rbp),%rdi
 126962e:	4c 89 65 88          	mov    %r12,-0x78(%rbp)
 1269632:	4c 89 e6             	mov    %r12,%rsi
 1269635:	4c 89 fa             	mov    %r15,%rdx
 1269638:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 126963c:	4c 8b 45 c8          	mov    -0x38(%rbp),%r8
 1269640:	e8 9b 49 fd ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 1269645:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 1269649:	48 8b 49 10          	mov    0x10(%rcx),%rcx
 126964d:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 1269651:	4d 8b 65 08          	mov    0x8(%r13),%r12
 1269655:	4c 8d 69 20          	lea    0x20(%rcx),%r13
 1269659:	4c 8b 89 20 30 02 00 	mov    0x23020(%rcx),%r9
 1269660:	a8 01                	test   $0x1,%al
 1269662:	0f 84 88 00 00 00    	je     12696f0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x710>
 1269668:	4d 85 c9             	test   %r9,%r9
 126966b:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 126966f:	74 5f                	je     12696d0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x6f0>
 1269671:	49 83 f9 01          	cmp    $0x1,%r9
 1269675:	0f 85 f1 00 00 00    	jne    126976c <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x78c>
 126967b:	31 c0                	xor    %eax,%eax
 126967d:	41 f6 c1 01          	test   $0x1,%r9b
 1269681:	74 4d                	je     12696d0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x6f0>
 1269683:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126968a:	45 0f b6 84 35 10 01 	movzbl 0x110(%r13,%rsi,1),%r8d
 1269691:	00 00 
 1269693:	41 80 e0 0f          	and    $0xf,%r8b
 1269697:	41 80 f8 07          	cmp    $0x7,%r8b
 126969b:	75 33                	jne    12696d0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x6f0>
 126969d:	49 01 f5             	add    %rsi,%r13
 12696a0:	41 80 7d 40 00       	cmpb   $0x0,0x40(%r13)
 12696a5:	74 29                	je     12696d0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x6f0>
 12696a7:	49 39 55 38          	cmp    %rdx,0x38(%r13)
 12696ab:	75 23                	jne    12696d0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x6f0>
 12696ad:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12696b1:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 12696b8:	00 
 12696b9:	75 15                	jne    12696d0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x6f0>
 12696bb:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 12696c2:	00 
 12696c3:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 12696ca:	84 00 00 00 00 00 
 12696d0:	48 85 d2             	test   %rdx,%rdx
 12696d3:	0f 84 17 fd ff ff    	je     12693f0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x410>
 12696d9:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12696dd:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12696e1:	31 c9                	xor    %ecx,%ecx
 12696e3:	41 ff 54 24 18       	call   *0x18(%r12)
 12696e8:	e9 03 fd ff ff       	jmp    12693f0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x410>
 12696ed:	0f 1f 00             	nopl   (%rax)
 12696f0:	4d 85 c9             	test   %r9,%r9
 12696f3:	4c 8b 75 90          	mov    -0x70(%rbp),%r14
 12696f7:	48 8b 75 88          	mov    -0x78(%rbp),%rsi
 12696fb:	74 53                	je     1269750 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x770>
 12696fd:	49 83 f9 01          	cmp    $0x1,%r9
 1269701:	0f 85 0d 01 00 00    	jne    1269814 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x834>
 1269707:	31 c0                	xor    %eax,%eax
 1269709:	41 f6 c1 01          	test   $0x1,%r9b
 126970d:	74 41                	je     1269750 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x770>
 126970f:	48 69 d0 18 01 00 00 	imul   $0x118,%rax,%rdx
 1269716:	45 0f b6 84 15 10 01 	movzbl 0x110(%r13,%rdx,1),%r8d
 126971d:	00 00 
 126971f:	41 80 e0 0f          	and    $0xf,%r8b
 1269723:	41 80 f8 07          	cmp    $0x7,%r8b
 1269727:	75 27                	jne    1269750 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x770>
 1269729:	49 01 d5             	add    %rdx,%r13
 126972c:	41 80 7d 40 00       	cmpb   $0x0,0x40(%r13)
 1269731:	74 1d                	je     1269750 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x770>
 1269733:	4d 39 7d 38          	cmp    %r15,0x38(%r13)
 1269737:	75 17                	jne    1269750 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x770>
 1269739:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 1269740:	00 
 1269741:	75 0d                	jne    1269750 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x770>
 1269743:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126974a:	00 
 126974b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 1269750:	4d 85 ff             	test   %r15,%r15
 1269753:	0f 84 ea fc ff ff    	je     1269443 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x463>
 1269759:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126975d:	4c 89 fa             	mov    %r15,%rdx
 1269760:	31 c9                	xor    %ecx,%ecx
 1269762:	41 ff 54 24 18       	call   *0x18(%r12)
 1269767:	e9 d7 fc ff ff       	jmp    1269443 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x463>
 126976c:	4d 89 c8             	mov    %r9,%r8
 126976f:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1269773:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 1269777:	31 c0                	xor    %eax,%eax
 1269779:	eb 19                	jmp    1269794 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x7b4>
 126977b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 1269780:	48 83 c0 02          	add    $0x2,%rax
 1269784:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 126978b:	49 39 c0             	cmp    %rax,%r8
 126978e:	0f 84 e9 fe ff ff    	je     126967d <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x69d>
 1269794:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 126979b:	00 
 126979c:	41 80 e3 0f          	and    $0xf,%r11b
 12697a0:	41 80 fb 07          	cmp    $0x7,%r11b
 12697a4:	75 2a                	jne    12697d0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x7f0>
 12697a6:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 12697ab:	74 23                	je     12697d0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x7f0>
 12697ad:	49 39 12             	cmp    %rdx,(%r10)
 12697b0:	75 1e                	jne    12697d0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x7f0>
 12697b2:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 12697b6:	4c 39 9c c1 d0 32 02 	cmp    %r11,0x232d0(%rcx,%rax,8)
 12697bd:	00 
 12697be:	75 10                	jne    12697d0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x7f0>
 12697c0:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 12697c7:	00 
 12697c8:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 12697cf:	00 
 12697d0:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 12697d7:	00 
 12697d8:	41 80 e3 0f          	and    $0xf,%r11b
 12697dc:	41 80 fb 07          	cmp    $0x7,%r11b
 12697e0:	75 9e                	jne    1269780 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x7a0>
 12697e2:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 12697e9:	00 
 12697ea:	74 94                	je     1269780 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x7a0>
 12697ec:	49 39 92 18 01 00 00 	cmp    %rdx,0x118(%r10)
 12697f3:	75 8b                	jne    1269780 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x7a0>
 12697f5:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 12697f9:	4c 39 9c c1 d8 32 02 	cmp    %r11,0x232d8(%rcx,%rax,8)
 1269800:	00 
 1269801:	0f 85 79 ff ff ff    	jne    1269780 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x7a0>
 1269807:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 126980e:	00 
 126980f:	e9 6c ff ff ff       	jmp    1269780 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x7a0>
 1269814:	4d 89 c8             	mov    %r9,%r8
 1269817:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 126981b:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 126981f:	31 c0                	xor    %eax,%eax
 1269821:	eb 21                	jmp    1269844 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x864>
 1269823:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 126982a:	84 00 00 00 00 00 
 1269830:	48 83 c0 02          	add    $0x2,%rax
 1269834:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 126983b:	49 39 c0             	cmp    %rax,%r8
 126983e:	0f 84 c5 fe ff ff    	je     1269709 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x729>
 1269844:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 126984b:	00 
 126984c:	41 80 e3 0f          	and    $0xf,%r11b
 1269850:	41 80 fb 07          	cmp    $0x7,%r11b
 1269854:	75 2a                	jne    1269880 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x8a0>
 1269856:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 126985b:	74 23                	je     1269880 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x8a0>
 126985d:	4d 39 3a             	cmp    %r15,(%r10)
 1269860:	75 1e                	jne    1269880 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x8a0>
 1269862:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 1269869:	00 
 126986a:	75 14                	jne    1269880 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x8a0>
 126986c:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1269873:	00 
 1269874:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 126987b:	00 00 00 00 00 
 1269880:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1269887:	00 
 1269888:	41 80 e3 0f          	and    $0xf,%r11b
 126988c:	41 80 fb 07          	cmp    $0x7,%r11b
 1269890:	75 9e                	jne    1269830 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x850>
 1269892:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1269899:	00 
 126989a:	74 94                	je     1269830 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x850>
 126989c:	4d 39 ba 18 01 00 00 	cmp    %r15,0x118(%r10)
 12698a3:	75 8b                	jne    1269830 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x850>
 12698a5:	48 39 b4 c1 d8 32 02 	cmp    %rsi,0x232d8(%rcx,%rax,8)
 12698ac:	00 
 12698ad:	75 81                	jne    1269830 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x850>
 12698af:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 12698b6:	00 
 12698b7:	e9 74 ff ff ff       	jmp    1269830 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x850>
 12698bc:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 12698c0:	48 89 85 d0 f7 ff ff 	mov    %rax,-0x830(%rbp)
 12698c7:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 12698cb:	48 89 85 d8 f7 ff ff 	mov    %rax,-0x828(%rbp)
 12698d2:	48 8d bd e0 f7 ff ff 	lea    -0x820(%rbp),%rdi
 12698d9:	48 8d b5 80 f6 ff ff 	lea    -0x980(%rbp),%rsi
 12698e0:	ba 50 01 00 00       	mov    $0x150,%edx
 12698e5:	e8 76 5e 07 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 12698ea:	48 8d 85 d0 f7 ff ff 	lea    -0x830(%rbp),%rax
 12698f1:	48 8d bd f0 fd ff ff 	lea    -0x210(%rbp),%rdi
 12698f8:	4d 89 f0             	mov    %r14,%r8
 12698fb:	4c 8b 75 c0          	mov    -0x40(%rbp),%r14
 12698ff:	4c 89 f6             	mov    %r14,%rsi
 1269902:	4c 89 ea             	mov    %r13,%rdx
 1269905:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 1269909:	4c 8b 8d f8 fe ff ff 	mov    -0x108(%rbp),%r9
 1269910:	50                   	push   %rax
 1269911:	ff 75 20             	push   0x20(%rbp)
 1269914:	41 57                	push   %r15
 1269916:	ff b5 f0 fe ff ff    	push   -0x110(%rbp)
 126991c:	e8 6f 08 00 00       	call   126a190 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669>
 1269921:	48 83 c4 20          	add    $0x20,%rsp
 1269925:	0f b7 9d 00 fe ff ff 	movzwl -0x200(%rbp),%ebx
 126992c:	48 85 db             	test   %rbx,%rbx
 126992f:	4c 8b 7d b8          	mov    -0x48(%rbp),%r15
 1269933:	0f 85 19 07 00 00    	jne    126a052 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x1072>
 1269939:	48 8b 9d f0 fd ff ff 	mov    -0x210(%rbp),%rbx
 1269940:	48 85 db             	test   %rbx,%rbx
 1269943:	0f 84 0d 02 00 00    	je     1269b56 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xb76>
 1269949:	49 8b 4e 10          	mov    0x10(%r14),%rcx
 126994d:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 1269951:	49 8b 45 08          	mov    0x8(%r13),%rax
 1269955:	48 8b b1 20 30 02 00 	mov    0x23020(%rcx),%rsi
 126995c:	48 85 f6             	test   %rsi,%rsi
 126995f:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 1269963:	74 57                	je     12699bc <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x9dc>
 1269965:	48 83 fe 01          	cmp    $0x1,%rsi
 1269969:	0f 85 3e 02 00 00    	jne    1269bad <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xbcd>
 126996f:	45 31 db             	xor    %r11d,%r11d
 1269972:	40 f6 c6 01          	test   $0x1,%sil
 1269976:	74 44                	je     12699bc <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x9dc>
 1269978:	48 8d 71 20          	lea    0x20(%rcx),%rsi
 126997c:	4d 69 c3 18 01 00 00 	imul   $0x118,%r11,%r8
 1269983:	46 0f b6 8c 06 10 01 	movzbl 0x110(%rsi,%r8,1),%r9d
 126998a:	00 00 
 126998c:	41 80 e1 0f          	and    $0xf,%r9b
 1269990:	41 80 f9 07          	cmp    $0x7,%r9b
 1269994:	75 26                	jne    12699bc <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x9dc>
 1269996:	4c 01 c6             	add    %r8,%rsi
 1269999:	80 7e 40 00          	cmpb   $0x0,0x40(%rsi)
 126999d:	74 1d                	je     12699bc <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x9dc>
 126999f:	48 39 56 38          	cmp    %rdx,0x38(%rsi)
 12699a3:	75 17                	jne    12699bc <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x9dc>
 12699a5:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12699a9:	4a 39 b4 d9 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%r11,8)
 12699b0:	00 
 12699b1:	75 09                	jne    12699bc <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x9dc>
 12699b3:	42 c6 84 19 d3 42 02 	movb   $0x0,0x242d3(%rcx,%r11,1)
 12699ba:	00 00 
 12699bc:	4c 8b b5 f8 fd ff ff 	mov    -0x208(%rbp),%r14
 12699c3:	48 85 d2             	test   %rdx,%rdx
 12699c6:	74 0d                	je     12699d5 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x9f5>
 12699c8:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12699cc:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12699d0:	31 c9                	xor    %ecx,%ecx
 12699d2:	ff 50 18             	call   *0x18(%rax)
 12699d5:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 12699dc:	e8 8f d7 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 12699e1:	66 41 c7 47 10 00 00 	movw   $0x0,0x10(%r15)
 12699e8:	49 89 1f             	mov    %rbx,(%r15)
 12699eb:	4d 89 77 08          	mov    %r14,0x8(%r15)
 12699ef:	e9 a7 01 00 00       	jmp    1269b9b <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xbbb>
 12699f4:	48 8d bd 88 ef ff ff 	lea    -0x1078(%rbp),%rdi
 12699fb:	48 8b 45 20          	mov    0x20(%rbp),%rax
 12699ff:	4c 8b 65 c0          	mov    -0x40(%rbp),%r12
 1269a03:	4c 89 e6             	mov    %r12,%rsi
 1269a06:	4c 89 ea             	mov    %r13,%rdx
 1269a09:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 1269a0d:	4d 89 f0             	mov    %r14,%r8
 1269a10:	49 89 d9             	mov    %rbx,%r9
 1269a13:	50                   	push   %rax
 1269a14:	41 57                	push   %r15
 1269a16:	ff 75 10             	push   0x10(%rbp)
 1269a19:	e8 f2 a0 00 00       	call   1273b10 <br.encodePreferredCommandPlanAllocRecorded__anon_231663>
 1269a1e:	48 83 c4 20          	add    $0x20,%rsp
 1269a22:	0f b7 b5 e8 f0 ff ff 	movzwl -0xf18(%rbp),%esi
 1269a29:	48 85 f6             	test   %rsi,%rsi
 1269a2c:	0f 85 77 06 00 00    	jne    126a0a9 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x10c9>
 1269a32:	4c 8d bd c0 f3 ff ff 	lea    -0xc40(%rbp),%r15
 1269a39:	48 8d b5 88 ef ff ff 	lea    -0x1078(%rbp),%rsi
 1269a40:	ba 60 01 00 00       	mov    $0x160,%edx
 1269a45:	4c 89 ff             	mov    %r15,%rdi
 1269a48:	e8 13 5d 07 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 1269a4d:	4d 89 f0             	mov    %r14,%r8
 1269a50:	48 8b 85 c0 f3 ff ff 	mov    -0xc40(%rbp),%rax
 1269a57:	48 89 45 d0          	mov    %rax,-0x30(%rbp)
 1269a5b:	4c 8b b5 c8 f3 ff ff 	mov    -0xc38(%rbp),%r14
 1269a62:	48 8d bd d8 fd ff ff 	lea    -0x228(%rbp),%rdi
 1269a69:	4c 89 e6             	mov    %r12,%rsi
 1269a6c:	4c 89 ea             	mov    %r13,%rdx
 1269a6f:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 1269a73:	49 89 d9             	mov    %rbx,%r9
 1269a76:	41 57                	push   %r15
 1269a78:	ff 75 20             	push   0x20(%rbp)
 1269a7b:	ff 75 18             	push   0x18(%rbp)
 1269a7e:	ff 75 10             	push   0x10(%rbp)
 1269a81:	e8 0a 07 00 00       	call   126a190 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669>
 1269a86:	48 83 c4 20          	add    $0x20,%rsp
 1269a8a:	44 0f b7 bd e8 fd ff 	movzwl -0x218(%rbp),%r15d
 1269a91:	ff 
 1269a92:	4d 85 ff             	test   %r15,%r15
 1269a95:	0f 85 4b 06 00 00    	jne    126a0e6 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x1106>
 1269a9b:	4c 8b bd d8 fd ff ff 	mov    -0x228(%rbp),%r15
 1269aa2:	4d 85 ff             	test   %r15,%r15
 1269aa5:	0f 84 cf 00 00 00    	je     1269b7a <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xb9a>
 1269aab:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 1269aaf:	48 8b 48 10          	mov    0x10(%rax),%rcx
 1269ab3:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 1269ab7:	49 8b 45 08          	mov    0x8(%r13),%rax
 1269abb:	4c 8b 99 20 30 02 00 	mov    0x23020(%rcx),%r11
 1269ac2:	4d 85 db             	test   %r11,%r11
 1269ac5:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1269ac9:	74 52                	je     1269b1d <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xb3d>
 1269acb:	49 83 fb 01          	cmp    $0x1,%r11
 1269acf:	0f 85 80 01 00 00    	jne    1269c55 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xc75>
 1269ad5:	31 d2                	xor    %edx,%edx
 1269ad7:	41 f6 c3 01          	test   $0x1,%r11b
 1269adb:	74 40                	je     1269b1d <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xb3d>
 1269add:	4c 8d 51 20          	lea    0x20(%rcx),%r10
 1269ae1:	4c 69 c2 18 01 00 00 	imul   $0x118,%rdx,%r8
 1269ae8:	47 0f b6 8c 02 10 01 	movzbl 0x110(%r10,%r8,1),%r9d
 1269aef:	00 00 
 1269af1:	41 80 e1 0f          	and    $0xf,%r9b
 1269af5:	41 80 f9 07          	cmp    $0x7,%r9b
 1269af9:	75 22                	jne    1269b1d <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xb3d>
 1269afb:	4d 01 c2             	add    %r8,%r10
 1269afe:	41 80 7a 40 00       	cmpb   $0x0,0x40(%r10)
 1269b03:	74 18                	je     1269b1d <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xb3d>
 1269b05:	4d 39 72 38          	cmp    %r14,0x38(%r10)
 1269b09:	75 12                	jne    1269b1d <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xb3d>
 1269b0b:	48 39 b4 d1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rdx,8)
 1269b12:	00 
 1269b13:	75 08                	jne    1269b1d <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xb3d>
 1269b15:	c6 84 11 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rdx,1)
 1269b1c:	00 
 1269b1d:	4c 8b 6d b8          	mov    -0x48(%rbp),%r13
 1269b21:	4c 8b a5 e0 fd ff ff 	mov    -0x220(%rbp),%r12
 1269b28:	4d 85 f6             	test   %r14,%r14
 1269b2b:	74 0c                	je     1269b39 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xb59>
 1269b2d:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1269b31:	4c 89 f2             	mov    %r14,%rdx
 1269b34:	31 c9                	xor    %ecx,%ecx
 1269b36:	ff 50 18             	call   *0x18(%rax)
 1269b39:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 1269b40:	e8 2b d6 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 1269b45:	66 41 c7 45 10 00 00 	movw   $0x0,0x10(%r13)
 1269b4c:	4d 89 7d 00          	mov    %r15,0x0(%r13)
 1269b50:	4d 89 65 08          	mov    %r12,0x8(%r13)
 1269b54:	eb 45                	jmp    1269b9b <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xbbb>
 1269b56:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 1269b5d:	e8 0e d6 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 1269b62:	66 41 c7 47 10 00 00 	movw   $0x0,0x10(%r15)
 1269b69:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1269b6d:	49 89 07             	mov    %rax,(%r15)
 1269b70:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 1269b74:	49 89 47 08          	mov    %rax,0x8(%r15)
 1269b78:	eb 21                	jmp    1269b9b <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xbbb>
 1269b7a:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 1269b81:	e8 ea d5 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 1269b86:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 1269b8a:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 1269b90:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 1269b94:	48 89 08             	mov    %rcx,(%rax)
 1269b97:	4c 89 70 08          	mov    %r14,0x8(%rax)
 1269b9b:	48 81 c4 68 1e 00 00 	add    $0x1e68,%rsp
 1269ba2:	5b                   	pop    %rbx
 1269ba3:	41 5c                	pop    %r12
 1269ba5:	41 5d                	pop    %r13
 1269ba7:	41 5e                	pop    %r14
 1269ba9:	41 5f                	pop    %r15
 1269bab:	5d                   	pop    %rbp
 1269bac:	c3                   	ret    
 1269bad:	49 89 f0             	mov    %rsi,%r8
 1269bb0:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1269bb4:	4c 8d 49 58          	lea    0x58(%rcx),%r9
 1269bb8:	45 31 db             	xor    %r11d,%r11d
 1269bbb:	eb 17                	jmp    1269bd4 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xbf4>
 1269bbd:	0f 1f 00             	nopl   (%rax)
 1269bc0:	49 83 c3 02          	add    $0x2,%r11
 1269bc4:	49 81 c1 30 02 00 00 	add    $0x230,%r9
 1269bcb:	4d 39 d8             	cmp    %r11,%r8
 1269bce:	0f 84 9e fd ff ff    	je     1269972 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x992>
 1269bd4:	45 0f b6 91 d8 00 00 	movzbl 0xd8(%r9),%r10d
 1269bdb:	00 
 1269bdc:	41 80 e2 0f          	and    $0xf,%r10b
 1269be0:	41 80 fa 07          	cmp    $0x7,%r10b
 1269be4:	75 2a                	jne    1269c10 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xc30>
 1269be6:	41 80 79 08 00       	cmpb   $0x0,0x8(%r9)
 1269beb:	74 23                	je     1269c10 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xc30>
 1269bed:	49 39 11             	cmp    %rdx,(%r9)
 1269bf0:	75 1e                	jne    1269c10 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xc30>
 1269bf2:	4c 8b 55 d0          	mov    -0x30(%rbp),%r10
 1269bf6:	4e 39 94 d9 d0 32 02 	cmp    %r10,0x232d0(%rcx,%r11,8)
 1269bfd:	00 
 1269bfe:	75 10                	jne    1269c10 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xc30>
 1269c00:	42 c6 84 19 d3 42 02 	movb   $0x0,0x242d3(%rcx,%r11,1)
 1269c07:	00 00 
 1269c09:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)
 1269c10:	45 0f b6 91 f0 01 00 	movzbl 0x1f0(%r9),%r10d
 1269c17:	00 
 1269c18:	41 80 e2 0f          	and    $0xf,%r10b
 1269c1c:	41 80 fa 07          	cmp    $0x7,%r10b
 1269c20:	75 9e                	jne    1269bc0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xbe0>
 1269c22:	41 80 b9 20 01 00 00 	cmpb   $0x0,0x120(%r9)
 1269c29:	00 
 1269c2a:	74 94                	je     1269bc0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xbe0>
 1269c2c:	49 39 91 18 01 00 00 	cmp    %rdx,0x118(%r9)
 1269c33:	75 8b                	jne    1269bc0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xbe0>
 1269c35:	4c 8b 55 d0          	mov    -0x30(%rbp),%r10
 1269c39:	4e 39 94 d9 d8 32 02 	cmp    %r10,0x232d8(%rcx,%r11,8)
 1269c40:	00 
 1269c41:	0f 85 79 ff ff ff    	jne    1269bc0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xbe0>
 1269c47:	42 c6 84 19 d4 42 02 	movb   $0x0,0x242d4(%rcx,%r11,1)
 1269c4e:	00 00 
 1269c50:	e9 6b ff ff ff       	jmp    1269bc0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xbe0>
 1269c55:	4d 89 d8             	mov    %r11,%r8
 1269c58:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1269c5c:	4c 8d 49 58          	lea    0x58(%rcx),%r9
 1269c60:	31 d2                	xor    %edx,%edx
 1269c62:	eb 20                	jmp    1269c84 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xca4>
 1269c64:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1269c6b:	00 00 00 00 00 
 1269c70:	48 83 c2 02          	add    $0x2,%rdx
 1269c74:	49 81 c1 30 02 00 00 	add    $0x230,%r9
 1269c7b:	49 39 d0             	cmp    %rdx,%r8
 1269c7e:	0f 84 53 fe ff ff    	je     1269ad7 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xaf7>
 1269c84:	45 0f b6 91 d8 00 00 	movzbl 0xd8(%r9),%r10d
 1269c8b:	00 
 1269c8c:	41 80 e2 0f          	and    $0xf,%r10b
 1269c90:	41 80 fa 07          	cmp    $0x7,%r10b
 1269c94:	75 2a                	jne    1269cc0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xce0>
 1269c96:	41 80 79 08 00       	cmpb   $0x0,0x8(%r9)
 1269c9b:	74 23                	je     1269cc0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xce0>
 1269c9d:	4d 39 31             	cmp    %r14,(%r9)
 1269ca0:	75 1e                	jne    1269cc0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xce0>
 1269ca2:	48 39 b4 d1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rdx,8)
 1269ca9:	00 
 1269caa:	75 14                	jne    1269cc0 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xce0>
 1269cac:	c6 84 11 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rdx,1)
 1269cb3:	00 
 1269cb4:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1269cbb:	00 00 00 00 00 
 1269cc0:	45 0f b6 91 f0 01 00 	movzbl 0x1f0(%r9),%r10d
 1269cc7:	00 
 1269cc8:	41 80 e2 0f          	and    $0xf,%r10b
 1269ccc:	41 80 fa 07          	cmp    $0x7,%r10b
 1269cd0:	75 9e                	jne    1269c70 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xc90>
 1269cd2:	41 80 b9 20 01 00 00 	cmpb   $0x0,0x120(%r9)
 1269cd9:	00 
 1269cda:	74 94                	je     1269c70 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xc90>
 1269cdc:	4d 39 b1 18 01 00 00 	cmp    %r14,0x118(%r9)
 1269ce3:	75 8b                	jne    1269c70 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xc90>
 1269ce5:	48 39 b4 d1 d8 32 02 	cmp    %rsi,0x232d8(%rcx,%rdx,8)
 1269cec:	00 
 1269ced:	75 81                	jne    1269c70 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xc90>
 1269cef:	c6 84 11 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rdx,1)
 1269cf6:	00 
 1269cf7:	e9 74 ff ff ff       	jmp    1269c70 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xc90>
 1269cfc:	48 8b 5d c0          	mov    -0x40(%rbp),%rbx
 1269d00:	48 8b 4b 10          	mov    0x10(%rbx),%rcx
 1269d04:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 1269d08:	48 8b 38             	mov    (%rax),%rdi
 1269d0b:	48 8b 40 08          	mov    0x8(%rax),%rax
 1269d0f:	48 8b b1 20 30 02 00 	mov    0x23020(%rcx),%rsi
 1269d16:	48 85 f6             	test   %rsi,%rsi
 1269d19:	4c 8b 7d b8          	mov    -0x48(%rbp),%r15
 1269d1d:	74 51                	je     1269d70 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xd90>
 1269d1f:	48 83 fe 01          	cmp    $0x1,%rsi
 1269d23:	0f 85 f9 01 00 00    	jne    1269f22 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xf42>
 1269d29:	31 d2                	xor    %edx,%edx
 1269d2b:	40 f6 c6 01          	test   $0x1,%sil
 1269d2f:	74 3f                	je     1269d70 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xd90>
 1269d31:	48 8d 71 20          	lea    0x20(%rcx),%rsi
 1269d35:	4c 69 c2 18 01 00 00 	imul   $0x118,%rdx,%r8
 1269d3c:	46 0f b6 8c 06 10 01 	movzbl 0x110(%rsi,%r8,1),%r9d
 1269d43:	00 00 
 1269d45:	41 80 e1 0f          	and    $0xf,%r9b
 1269d49:	41 80 f9 07          	cmp    $0x7,%r9b
 1269d4d:	75 21                	jne    1269d70 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xd90>
 1269d4f:	4c 01 c6             	add    %r8,%rsi
 1269d52:	80 7e 40 00          	cmpb   $0x0,0x40(%rsi)
 1269d56:	74 18                	je     1269d70 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xd90>
 1269d58:	4c 39 6e 38          	cmp    %r13,0x38(%rsi)
 1269d5c:	75 12                	jne    1269d70 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xd90>
 1269d5e:	4c 39 b4 d1 d0 32 02 	cmp    %r14,0x232d0(%rcx,%rdx,8)
 1269d65:	00 
 1269d66:	75 08                	jne    1269d70 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xd90>
 1269d68:	c6 84 11 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rdx,1)
 1269d6f:	00 
 1269d70:	4d 85 ed             	test   %r13,%r13
 1269d73:	74 0f                	je     1269d84 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xda4>
 1269d75:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1269d79:	4c 89 f6             	mov    %r14,%rsi
 1269d7c:	4c 89 ea             	mov    %r13,%rdx
 1269d7f:	31 c9                	xor    %ecx,%ecx
 1269d81:	ff 50 18             	call   *0x18(%rax)
 1269d84:	48 8d bd 20 fe ff ff 	lea    -0x1e0(%rbp),%rdi
 1269d8b:	48 89 de             	mov    %rbx,%rsi
 1269d8e:	4c 8b 65 a8          	mov    -0x58(%rbp),%r12
 1269d92:	4c 89 e2             	mov    %r12,%rdx
 1269d95:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 1269d99:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 1269d9d:	4c 8b 4d 98          	mov    -0x68(%rbp),%r9
 1269da1:	48 8d 85 30 f9 ff ff 	lea    -0x6d0(%rbp),%rax
 1269da8:	50                   	push   %rax
 1269da9:	ff 75 20             	push   0x20(%rbp)
 1269dac:	ff 75 18             	push   0x18(%rbp)
 1269daf:	6a 02                	push   $0x2
 1269db1:	e8 da 03 00 00       	call   126a190 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669>
 1269db6:	48 83 c4 20          	add    $0x20,%rsp
 1269dba:	0f b7 9d 30 fe ff ff 	movzwl -0x1d0(%rbp),%ebx
 1269dc1:	48 85 db             	test   %rbx,%rbx
 1269dc4:	0f 85 a0 03 00 00    	jne    126a16a <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x118a>
 1269dca:	48 8b 9d 20 fe ff ff 	mov    -0x1e0(%rbp),%rbx
 1269dd1:	48 85 db             	test   %rbx,%rbx
 1269dd4:	0f 84 21 01 00 00    	je     1269efb <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xf1b>
 1269dda:	4c 8b b5 28 fe ff ff 	mov    -0x1d8(%rbp),%r14
 1269de1:	48 8b 7d c0          	mov    -0x40(%rbp),%rdi
 1269de5:	4c 89 e6             	mov    %r12,%rsi
 1269de8:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 1269dec:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 1269df0:	e8 ab c7 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 1269df5:	e9 db fb ff ff       	jmp    12699d5 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x9f5>
 1269dfa:	48 8b 7d c0          	mov    -0x40(%rbp),%rdi
 1269dfe:	4c 89 ee             	mov    %r13,%rsi
 1269e01:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 1269e05:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 1269e09:	e8 92 c7 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 1269e0e:	80 bd 58 ff ff ff 00 	cmpb   $0x0,-0xa8(%rbp)
 1269e15:	74 25                	je     1269e3c <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xe5c>
 1269e17:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 1269e1e:	48 69 8d 50 ff ff ff 	imul   $0x118,-0xb0(%rbp),%rcx
 1269e25:	18 01 00 00 
 1269e29:	89 da                	mov    %ebx,%edx
 1269e2b:	c1 e2 04             	shl    $0x4,%edx
 1269e2e:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 1269e35:	01 
 1269e36:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 1269e3c:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 1269e43:	e8 28 d3 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 1269e48:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 1269e4c:	66 89 58 10          	mov    %bx,0x10(%rax)
 1269e50:	e9 46 fd ff ff       	jmp    1269b9b <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xbbb>
 1269e55:	48 8b 7d c0          	mov    -0x40(%rbp),%rdi
 1269e59:	4c 89 ee             	mov    %r13,%rsi
 1269e5c:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 1269e60:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 1269e64:	e8 37 c7 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 1269e69:	80 bd 58 ff ff ff 00 	cmpb   $0x0,-0xa8(%rbp)
 1269e70:	74 26                	je     1269e98 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xeb8>
 1269e72:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 1269e79:	48 69 8d 50 ff ff ff 	imul   $0x118,-0xb0(%rbp),%rcx
 1269e80:	18 01 00 00 
 1269e84:	44 89 fa             	mov    %r15d,%edx
 1269e87:	c1 e2 04             	shl    $0x4,%edx
 1269e8a:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 1269e91:	01 
 1269e92:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 1269e98:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 1269e9f:	e8 cc d2 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 1269ea4:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 1269ea8:	66 44 89 78 10       	mov    %r15w,0x10(%rax)
 1269ead:	e9 e9 fc ff ff       	jmp    1269b9b <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xbbb>
 1269eb2:	48 8b 85 38 fe ff ff 	mov    -0x1c8(%rbp),%rax
 1269eb9:	48 89 45 a0          	mov    %rax,-0x60(%rbp)
 1269ebd:	48 85 c0             	test   %rax,%rax
 1269ec0:	4c 8b 65 b8          	mov    -0x48(%rbp),%r12
 1269ec4:	0f 84 02 01 00 00    	je     1269fcc <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xfec>
 1269eca:	48 8b 85 40 fe ff ff 	mov    -0x1c0(%rbp),%rax
 1269ed1:	48 89 45 88          	mov    %rax,-0x78(%rbp)
 1269ed5:	48 8b 5d c0          	mov    -0x40(%rbp),%rbx
 1269ed9:	48 89 df             	mov    %rbx,%rdi
 1269edc:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 1269ee0:	4c 89 fe             	mov    %r15,%rsi
 1269ee3:	4c 89 f2             	mov    %r14,%rdx
 1269ee6:	4c 89 e9             	mov    %r13,%rcx
 1269ee9:	e8 b2 c6 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 1269eee:	4c 8b 6d 88          	mov    -0x78(%rbp),%r13
 1269ef2:	4c 8b 75 a0          	mov    -0x60(%rbp),%r14
 1269ef6:	e9 d9 00 00 00       	jmp    1269fd4 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xff4>
 1269efb:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 1269f02:	e8 69 d2 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 1269f07:	66 41 c7 47 10 00 00 	movw   $0x0,0x10(%r15)
 1269f0e:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 1269f12:	49 89 07             	mov    %rax,(%r15)
 1269f15:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1269f19:	49 89 47 08          	mov    %rax,0x8(%r15)
 1269f1d:	e9 79 fc ff ff       	jmp    1269b9b <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xbbb>
 1269f22:	49 89 f0             	mov    %rsi,%r8
 1269f25:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1269f29:	4c 8d 49 58          	lea    0x58(%rcx),%r9
 1269f2d:	31 d2                	xor    %edx,%edx
 1269f2f:	eb 23                	jmp    1269f54 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xf74>
 1269f31:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1269f38:	0f 1f 84 00 00 00 00 
 1269f3f:	00 
 1269f40:	48 83 c2 02          	add    $0x2,%rdx
 1269f44:	49 81 c1 30 02 00 00 	add    $0x230,%r9
 1269f4b:	49 39 d0             	cmp    %rdx,%r8
 1269f4e:	0f 84 d7 fd ff ff    	je     1269d2b <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xd4b>
 1269f54:	45 0f b6 91 d8 00 00 	movzbl 0xd8(%r9),%r10d
 1269f5b:	00 
 1269f5c:	41 80 e2 0f          	and    $0xf,%r10b
 1269f60:	41 80 fa 07          	cmp    $0x7,%r10b
 1269f64:	75 2a                	jne    1269f90 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xfb0>
 1269f66:	41 80 79 08 00       	cmpb   $0x0,0x8(%r9)
 1269f6b:	74 23                	je     1269f90 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xfb0>
 1269f6d:	4d 39 29             	cmp    %r13,(%r9)
 1269f70:	75 1e                	jne    1269f90 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xfb0>
 1269f72:	4c 39 b4 d1 d0 32 02 	cmp    %r14,0x232d0(%rcx,%rdx,8)
 1269f79:	00 
 1269f7a:	75 14                	jne    1269f90 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xfb0>
 1269f7c:	c6 84 11 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rdx,1)
 1269f83:	00 
 1269f84:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1269f8b:	00 00 00 00 00 
 1269f90:	45 0f b6 91 f0 01 00 	movzbl 0x1f0(%r9),%r10d
 1269f97:	00 
 1269f98:	41 80 e2 0f          	and    $0xf,%r10b
 1269f9c:	41 80 fa 07          	cmp    $0x7,%r10b
 1269fa0:	75 9e                	jne    1269f40 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xf60>
 1269fa2:	41 80 b9 20 01 00 00 	cmpb   $0x0,0x120(%r9)
 1269fa9:	00 
 1269faa:	74 94                	je     1269f40 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xf60>
 1269fac:	4d 39 a9 18 01 00 00 	cmp    %r13,0x118(%r9)
 1269fb3:	75 8b                	jne    1269f40 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xf60>
 1269fb5:	4c 39 b4 d1 d8 32 02 	cmp    %r14,0x232d8(%rcx,%rdx,8)
 1269fbc:	00 
 1269fbd:	75 81                	jne    1269f40 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xf60>
 1269fbf:	c6 84 11 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rdx,1)
 1269fc6:	00 
 1269fc7:	e9 74 ff ff ff       	jmp    1269f40 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xf60>
 1269fcc:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 1269fd0:	48 8b 5d c0          	mov    -0x40(%rbp),%rbx
 1269fd4:	48 89 df             	mov    %rbx,%rdi
 1269fd7:	4c 89 fe             	mov    %r15,%rsi
 1269fda:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 1269fde:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 1269fe2:	e8 b9 c5 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 1269fe7:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 1269fee:	e8 7d d1 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 1269ff3:	66 41 c7 44 24 10 00 	movw   $0x0,0x10(%r12)
 1269ffa:	00 
 1269ffb:	4d 89 34 24          	mov    %r14,(%r12)
 1269fff:	4d 89 6c 24 08       	mov    %r13,0x8(%r12)
 126a004:	e9 92 fb ff ff       	jmp    1269b9b <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xbbb>
 126a009:	80 bd 58 ff ff ff 00 	cmpb   $0x0,-0xa8(%rbp)
 126a010:	74 26                	je     126a038 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x1058>
 126a012:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 126a019:	48 69 8d 50 ff ff ff 	imul   $0x118,-0xb0(%rbp),%rcx
 126a020:	18 01 00 00 
 126a024:	44 89 e2             	mov    %r12d,%edx
 126a027:	c1 e2 04             	shl    $0x4,%edx
 126a02a:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 126a031:	01 
 126a032:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 126a038:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 126a03f:	e8 2c d1 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 126a044:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 126a048:	66 44 89 60 10       	mov    %r12w,0x10(%rax)
 126a04d:	e9 49 fb ff ff       	jmp    1269b9b <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xbbb>
 126a052:	4c 89 f7             	mov    %r14,%rdi
 126a055:	4c 89 ee             	mov    %r13,%rsi
 126a058:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 126a05c:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 126a060:	e8 3b c5 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 126a065:	80 bd 58 ff ff ff 00 	cmpb   $0x0,-0xa8(%rbp)
 126a06c:	74 25                	je     126a093 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x10b3>
 126a06e:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 126a075:	48 69 8d 50 ff ff ff 	imul   $0x118,-0xb0(%rbp),%rcx
 126a07c:	18 01 00 00 
 126a080:	89 da                	mov    %ebx,%edx
 126a082:	c1 e2 04             	shl    $0x4,%edx
 126a085:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 126a08c:	01 
 126a08d:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 126a093:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 126a09a:	e8 d1 d0 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 126a09f:	66 41 89 5f 10       	mov    %bx,0x10(%r15)
 126a0a4:	e9 f2 fa ff ff       	jmp    1269b9b <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xbbb>
 126a0a9:	80 bd 58 ff ff ff 00 	cmpb   $0x0,-0xa8(%rbp)
 126a0b0:	74 25                	je     126a0d7 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x10f7>
 126a0b2:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 126a0b9:	48 69 8d 50 ff ff ff 	imul   $0x118,-0xb0(%rbp),%rcx
 126a0c0:	18 01 00 00 
 126a0c4:	89 f2                	mov    %esi,%edx
 126a0c6:	c1 e2 04             	shl    $0x4,%edx
 126a0c9:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 126a0d0:	01 
 126a0d1:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 126a0d7:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 126a0de:	48 89 f3             	mov    %rsi,%rbx
 126a0e1:	e9 5d fd ff ff       	jmp    1269e43 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xe63>
 126a0e6:	48 8b 7d c0          	mov    -0x40(%rbp),%rdi
 126a0ea:	4c 89 ee             	mov    %r13,%rsi
 126a0ed:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 126a0f1:	4c 89 f1             	mov    %r14,%rcx
 126a0f4:	e8 a7 c4 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 126a0f9:	80 bd 58 ff ff ff 00 	cmpb   $0x0,-0xa8(%rbp)
 126a100:	0f 85 6c fd ff ff    	jne    1269e72 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xe92>
 126a106:	e9 8d fd ff ff       	jmp    1269e98 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xeb8>
 126a10b:	48 89 c3             	mov    %rax,%rbx
 126a10e:	4c 8b 65 b8          	mov    -0x48(%rbp),%r12
 126a112:	80 bd 58 ff ff ff 00 	cmpb   $0x0,-0xa8(%rbp)
 126a119:	74 25                	je     126a140 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x1160>
 126a11b:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 126a122:	48 69 8d 50 ff ff ff 	imul   $0x118,-0xb0(%rbp),%rcx
 126a129:	18 01 00 00 
 126a12d:	89 da                	mov    %ebx,%edx
 126a12f:	c1 e2 04             	shl    $0x4,%edx
 126a132:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 126a139:	01 
 126a13a:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 126a140:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 126a147:	e8 24 d0 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 126a14c:	66 41 89 5c 24 10    	mov    %bx,0x10(%r12)
 126a152:	e9 44 fa ff ff       	jmp    1269b9b <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xbbb>
 126a157:	48 8b 7d c0          	mov    -0x40(%rbp),%rdi
 126a15b:	4c 89 ee             	mov    %r13,%rsi
 126a15e:	eb 11                	jmp    126a171 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x1191>
 126a160:	48 8b 7d c0          	mov    -0x40(%rbp),%rdi
 126a164:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 126a168:	eb 07                	jmp    126a171 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0x1191>
 126a16a:	48 8b 7d c0          	mov    -0x40(%rbp),%rdi
 126a16e:	4c 89 e6             	mov    %r12,%rsi
 126a171:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 126a175:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 126a179:	e8 22 c4 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 126a17e:	80 bd 58 ff ff ff 00 	cmpb   $0x0,-0xa8(%rbp)
 126a185:	0f 85 8c fc ff ff    	jne    1269e17 <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xe37>
 126a18b:	e9 ac fc ff ff       	jmp    1269e3c <br.encodeLazyCommandPlanAllocRecorded__anon_29228+0xe5c>

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
