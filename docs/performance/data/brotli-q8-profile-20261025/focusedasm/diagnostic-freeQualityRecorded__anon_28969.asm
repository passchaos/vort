
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

00000000012765a0 <br.freeQualityRecorded__anon_28969>:
 12765a0:	55                   	push   %rbp
 12765a1:	48 89 e5             	mov    %rsp,%rbp
 12765a4:	53                   	push   %rbx
 12765a5:	4c 8b 47 10          	mov    0x10(%rdi),%r8
 12765a9:	48 8b 3e             	mov    (%rsi),%rdi
 12765ac:	48 8b 46 08          	mov    0x8(%rsi),%rax
 12765b0:	4d 8b 88 20 30 02 00 	mov    0x23020(%r8),%r9
 12765b7:	4d 85 c9             	test   %r9,%r9
 12765ba:	74 4f                	je     127660b <br.freeQualityRecorded__anon_28969+0x6b>
 12765bc:	49 83 f9 01          	cmp    $0x1,%r9
 12765c0:	75 65                	jne    1276627 <br.freeQualityRecorded__anon_28969+0x87>
 12765c2:	31 f6                	xor    %esi,%esi
 12765c4:	41 f6 c1 01          	test   $0x1,%r9b
 12765c8:	74 41                	je     127660b <br.freeQualityRecorded__anon_28969+0x6b>
 12765ca:	4d 8d 48 20          	lea    0x20(%r8),%r9
 12765ce:	4c 69 d6 18 01 00 00 	imul   $0x118,%rsi,%r10
 12765d5:	47 0f b6 9c 11 10 01 	movzbl 0x110(%r9,%r10,1),%r11d
 12765dc:	00 00 
 12765de:	41 80 e3 0f          	and    $0xf,%r11b
 12765e2:	41 80 fb 07          	cmp    $0x7,%r11b
 12765e6:	75 23                	jne    127660b <br.freeQualityRecorded__anon_28969+0x6b>
 12765e8:	4d 01 d1             	add    %r10,%r9
 12765eb:	41 80 79 40 00       	cmpb   $0x0,0x40(%r9)
 12765f0:	74 19                	je     127660b <br.freeQualityRecorded__anon_28969+0x6b>
 12765f2:	49 39 49 38          	cmp    %rcx,0x38(%r9)
 12765f6:	75 13                	jne    127660b <br.freeQualityRecorded__anon_28969+0x6b>
 12765f8:	49 39 94 f0 d0 32 02 	cmp    %rdx,0x232d0(%r8,%rsi,8)
 12765ff:	00 
 1276600:	75 09                	jne    127660b <br.freeQualityRecorded__anon_28969+0x6b>
 1276602:	41 c6 84 30 d3 42 02 	movb   $0x0,0x242d3(%r8,%rsi,1)
 1276609:	00 00 
 127660b:	48 85 c9             	test   %rcx,%rcx
 127660e:	74 14                	je     1276624 <br.freeQualityRecorded__anon_28969+0x84>
 1276610:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1276614:	48 8b 40 18          	mov    0x18(%rax),%rax
 1276618:	48 89 d6             	mov    %rdx,%rsi
 127661b:	48 89 ca             	mov    %rcx,%rdx
 127661e:	31 c9                	xor    %ecx,%ecx
 1276620:	5b                   	pop    %rbx
 1276621:	5d                   	pop    %rbp
 1276622:	ff e0                	jmp    *%rax
 1276624:	5b                   	pop    %rbx
 1276625:	5d                   	pop    %rbp
 1276626:	c3                   	ret    
 1276627:	4d 89 ca             	mov    %r9,%r10
 127662a:	49 83 e2 fe          	and    $0xfffffffffffffffe,%r10
 127662e:	4d 8d 58 58          	lea    0x58(%r8),%r11
 1276632:	31 f6                	xor    %esi,%esi
 1276634:	eb 1e                	jmp    1276654 <br.freeQualityRecorded__anon_28969+0xb4>
 1276636:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 127663d:	00 00 00 
 1276640:	48 83 c6 02          	add    $0x2,%rsi
 1276644:	49 81 c3 30 02 00 00 	add    $0x230,%r11
 127664b:	49 39 f2             	cmp    %rsi,%r10
 127664e:	0f 84 70 ff ff ff    	je     12765c4 <br.freeQualityRecorded__anon_28969+0x24>
 1276654:	41 0f b6 9b d8 00 00 	movzbl 0xd8(%r11),%ebx
 127665b:	00 
 127665c:	80 e3 0f             	and    $0xf,%bl
 127665f:	80 fb 07             	cmp    $0x7,%bl
 1276662:	75 2c                	jne    1276690 <br.freeQualityRecorded__anon_28969+0xf0>
 1276664:	41 80 7b 08 00       	cmpb   $0x0,0x8(%r11)
 1276669:	74 25                	je     1276690 <br.freeQualityRecorded__anon_28969+0xf0>
 127666b:	49 39 0b             	cmp    %rcx,(%r11)
 127666e:	75 20                	jne    1276690 <br.freeQualityRecorded__anon_28969+0xf0>
 1276670:	49 39 94 f0 d0 32 02 	cmp    %rdx,0x232d0(%r8,%rsi,8)
 1276677:	00 
 1276678:	75 16                	jne    1276690 <br.freeQualityRecorded__anon_28969+0xf0>
 127667a:	41 c6 84 30 d3 42 02 	movb   $0x0,0x242d3(%r8,%rsi,1)
 1276681:	00 00 
 1276683:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 127668a:	84 00 00 00 00 00 
 1276690:	41 0f b6 9b f0 01 00 	movzbl 0x1f0(%r11),%ebx
 1276697:	00 
 1276698:	80 e3 0f             	and    $0xf,%bl
 127669b:	80 fb 07             	cmp    $0x7,%bl
 127669e:	75 a0                	jne    1276640 <br.freeQualityRecorded__anon_28969+0xa0>
 12766a0:	41 80 bb 20 01 00 00 	cmpb   $0x0,0x120(%r11)
 12766a7:	00 
 12766a8:	74 96                	je     1276640 <br.freeQualityRecorded__anon_28969+0xa0>
 12766aa:	49 39 8b 18 01 00 00 	cmp    %rcx,0x118(%r11)
 12766b1:	75 8d                	jne    1276640 <br.freeQualityRecorded__anon_28969+0xa0>
 12766b3:	49 39 94 f0 d8 32 02 	cmp    %rdx,0x232d8(%r8,%rsi,8)
 12766ba:	00 
 12766bb:	75 83                	jne    1276640 <br.freeQualityRecorded__anon_28969+0xa0>
 12766bd:	41 c6 84 30 d4 42 02 	movb   $0x0,0x242d4(%r8,%rsi,1)
 12766c4:	00 00 
 12766c6:	e9 75 ff ff ff       	jmp    1276640 <br.freeQualityRecorded__anon_28969+0xa0>

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
