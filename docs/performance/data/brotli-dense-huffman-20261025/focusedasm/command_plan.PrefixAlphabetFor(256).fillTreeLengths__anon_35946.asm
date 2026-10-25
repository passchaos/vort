
/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/7cab685de62cdb93856431f8e3ddb813/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

00000000011ba520 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35946>:
 11ba520:	55                   	push   %rbp
 11ba521:	48 89 e5             	mov    %rsp,%rbp
 11ba524:	41 57                	push   %r15
 11ba526:	41 56                	push   %r14
 11ba528:	41 54                	push   %r12
 11ba52a:	53                   	push   %rbx
 11ba52b:	48 81 ec 80 10 00 00 	sub    $0x1080,%rsp
 11ba532:	48 89 d3             	mov    %rdx,%rbx
 11ba535:	49 89 f7             	mov    %rsi,%r15
 11ba538:	49 89 fe             	mov    %rdi,%r14
 11ba53b:	4c 8b 27             	mov    (%rdi),%r12
 11ba53e:	48 8d bd 20 f2 ff ff 	lea    -0xde0(%rbp),%rdi
 11ba545:	ba 00 0b 00 00       	mov    $0xb00,%edx
 11ba54a:	31 f6                	xor    %esi,%esi
 11ba54c:	e8 2f d3 0d 00       	call   1297880 <compiler_rt.memset>
 11ba551:	4d 85 e4             	test   %r12,%r12
 11ba554:	74 13                	je     11ba569 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35946+0x49>
 11ba556:	44 89 e0             	mov    %r12d,%eax
 11ba559:	83 e0 07             	and    $0x7,%eax
 11ba55c:	49 83 fc 08          	cmp    $0x8,%r12
 11ba560:	73 24                	jae    11ba586 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35946+0x66>
 11ba562:	31 c9                	xor    %ecx,%ecx
 11ba564:	e9 cc 00 00 00       	jmp    11ba635 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35946+0x115>
 11ba569:	48 8d bd 60 ef ff ff 	lea    -0x10a0(%rbp),%rdi
 11ba570:	48 8d b5 20 f2 ff ff 	lea    -0xde0(%rbp),%rsi
 11ba577:	ba 0f 00 00 00       	mov    $0xf,%edx
 11ba57c:	e8 ef f2 fc ff       	call   1189870 <huffman.treeCodeLengths__anon_40855>
 11ba581:	e9 23 02 00 00       	jmp    11ba7a9 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35946+0x289>
 11ba586:	44 89 e2             	mov    %r12d,%edx
 11ba589:	81 e2 f8 03 00 00    	and    $0x3f8,%edx
 11ba58f:	31 c9                	xor    %ecx,%ecx
 11ba591:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11ba598:	0f 1f 84 00 00 00 00 
 11ba59f:	00 
 11ba5a0:	41 0f b7 74 4e 08    	movzwl 0x8(%r14,%rcx,2),%esi
 11ba5a6:	41 8b 34 b7          	mov    (%r15,%rsi,4),%esi
 11ba5aa:	89 b4 8d 20 f2 ff ff 	mov    %esi,-0xde0(%rbp,%rcx,4)
 11ba5b1:	41 0f b7 74 4e 0a    	movzwl 0xa(%r14,%rcx,2),%esi
 11ba5b7:	41 8b 34 b7          	mov    (%r15,%rsi,4),%esi
 11ba5bb:	89 b4 8d 24 f2 ff ff 	mov    %esi,-0xddc(%rbp,%rcx,4)
 11ba5c2:	41 0f b7 74 4e 0c    	movzwl 0xc(%r14,%rcx,2),%esi
 11ba5c8:	41 8b 34 b7          	mov    (%r15,%rsi,4),%esi
 11ba5cc:	89 b4 8d 28 f2 ff ff 	mov    %esi,-0xdd8(%rbp,%rcx,4)
 11ba5d3:	41 0f b7 74 4e 0e    	movzwl 0xe(%r14,%rcx,2),%esi
 11ba5d9:	41 8b 34 b7          	mov    (%r15,%rsi,4),%esi
 11ba5dd:	89 b4 8d 2c f2 ff ff 	mov    %esi,-0xdd4(%rbp,%rcx,4)
 11ba5e4:	41 0f b7 74 4e 10    	movzwl 0x10(%r14,%rcx,2),%esi
 11ba5ea:	41 8b 34 b7          	mov    (%r15,%rsi,4),%esi
 11ba5ee:	89 b4 8d 30 f2 ff ff 	mov    %esi,-0xdd0(%rbp,%rcx,4)
 11ba5f5:	41 0f b7 74 4e 12    	movzwl 0x12(%r14,%rcx,2),%esi
 11ba5fb:	41 8b 34 b7          	mov    (%r15,%rsi,4),%esi
 11ba5ff:	89 b4 8d 34 f2 ff ff 	mov    %esi,-0xdcc(%rbp,%rcx,4)
 11ba606:	41 0f b7 74 4e 14    	movzwl 0x14(%r14,%rcx,2),%esi
 11ba60c:	41 8b 34 b7          	mov    (%r15,%rsi,4),%esi
 11ba610:	89 b4 8d 38 f2 ff ff 	mov    %esi,-0xdc8(%rbp,%rcx,4)
 11ba617:	41 0f b7 74 4e 16    	movzwl 0x16(%r14,%rcx,2),%esi
 11ba61d:	41 8b 34 b7          	mov    (%r15,%rsi,4),%esi
 11ba621:	89 b4 8d 3c f2 ff ff 	mov    %esi,-0xdc4(%rbp,%rcx,4)
 11ba628:	48 83 c1 08          	add    $0x8,%rcx
 11ba62c:	48 39 ca             	cmp    %rcx,%rdx
 11ba62f:	0f 85 6b ff ff ff    	jne    11ba5a0 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35946+0x80>
 11ba635:	48 85 c0             	test   %rax,%rax
 11ba638:	74 29                	je     11ba663 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35946+0x143>
 11ba63a:	48 8d 14 8d 20 f2 ff 	lea    -0xde0(,%rcx,4),%rdx
 11ba641:	ff 
 11ba642:	48 01 ea             	add    %rbp,%rdx
 11ba645:	49 8d 0c 4e          	lea    (%r14,%rcx,2),%rcx
 11ba649:	48 83 c1 08          	add    $0x8,%rcx
 11ba64d:	31 f6                	xor    %esi,%esi
 11ba64f:	90                   	nop
 11ba650:	0f b7 3c 71          	movzwl (%rcx,%rsi,2),%edi
 11ba654:	41 8b 3c bf          	mov    (%r15,%rdi,4),%edi
 11ba658:	89 3c b2             	mov    %edi,(%rdx,%rsi,4)
 11ba65b:	48 ff c6             	inc    %rsi
 11ba65e:	48 39 f0             	cmp    %rsi,%rax
 11ba661:	75 ed                	jne    11ba650 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35946+0x130>
 11ba663:	4c 8d bd 60 ef ff ff 	lea    -0x10a0(%rbp),%r15
 11ba66a:	48 8d b5 20 f2 ff ff 	lea    -0xde0(%rbp),%rsi
 11ba671:	4c 89 ff             	mov    %r15,%rdi
 11ba674:	ba 0f 00 00 00       	mov    $0xf,%edx
 11ba679:	e8 f2 f1 fc ff       	call   1189870 <huffman.treeCodeLengths__anon_40855>
 11ba67e:	48 8d bd 20 fd ff ff 	lea    -0x2e0(%rbp),%rdi
 11ba685:	ba c0 02 00 00       	mov    $0x2c0,%edx
 11ba68a:	4c 89 fe             	mov    %r15,%rsi
 11ba68d:	e8 0e d6 0d 00       	call   1297ca0 <compiler_rt.memcpy.memcpyFast>
 11ba692:	44 89 e0             	mov    %r12d,%eax
 11ba695:	83 e0 07             	and    $0x7,%eax
 11ba698:	49 83 fc 08          	cmp    $0x8,%r12
 11ba69c:	73 07                	jae    11ba6a5 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35946+0x185>
 11ba69e:	31 c9                	xor    %ecx,%ecx
 11ba6a0:	e9 c8 00 00 00       	jmp    11ba76d <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35946+0x24d>
 11ba6a5:	41 81 e4 f8 03 00 00 	and    $0x3f8,%r12d
 11ba6ac:	31 c9                	xor    %ecx,%ecx
 11ba6ae:	66 90                	xchg   %ax,%ax
 11ba6b0:	41 0f b7 54 4e 08    	movzwl 0x8(%r14,%rcx,2),%edx
 11ba6b6:	0f b6 b4 0d 20 fd ff 	movzbl -0x2e0(%rbp,%rcx,1),%esi
 11ba6bd:	ff 
 11ba6be:	40 80 e6 0f          	and    $0xf,%sil
 11ba6c2:	40 88 34 13          	mov    %sil,(%rbx,%rdx,1)
 11ba6c6:	41 0f b7 54 4e 0a    	movzwl 0xa(%r14,%rcx,2),%edx
 11ba6cc:	0f b6 b4 0d 21 fd ff 	movzbl -0x2df(%rbp,%rcx,1),%esi
 11ba6d3:	ff 
 11ba6d4:	40 80 e6 0f          	and    $0xf,%sil
 11ba6d8:	40 88 34 13          	mov    %sil,(%rbx,%rdx,1)
 11ba6dc:	41 0f b7 54 4e 0c    	movzwl 0xc(%r14,%rcx,2),%edx
 11ba6e2:	0f b6 b4 0d 22 fd ff 	movzbl -0x2de(%rbp,%rcx,1),%esi
 11ba6e9:	ff 
 11ba6ea:	40 80 e6 0f          	and    $0xf,%sil
 11ba6ee:	40 88 34 13          	mov    %sil,(%rbx,%rdx,1)
 11ba6f2:	41 0f b7 54 4e 0e    	movzwl 0xe(%r14,%rcx,2),%edx
 11ba6f8:	0f b6 b4 0d 23 fd ff 	movzbl -0x2dd(%rbp,%rcx,1),%esi
 11ba6ff:	ff 
 11ba700:	40 80 e6 0f          	and    $0xf,%sil
 11ba704:	40 88 34 13          	mov    %sil,(%rbx,%rdx,1)
 11ba708:	41 0f b7 54 4e 10    	movzwl 0x10(%r14,%rcx,2),%edx
 11ba70e:	0f b6 b4 0d 24 fd ff 	movzbl -0x2dc(%rbp,%rcx,1),%esi
 11ba715:	ff 
 11ba716:	40 80 e6 0f          	and    $0xf,%sil
 11ba71a:	40 88 34 13          	mov    %sil,(%rbx,%rdx,1)
 11ba71e:	41 0f b7 54 4e 12    	movzwl 0x12(%r14,%rcx,2),%edx
 11ba724:	0f b6 b4 0d 25 fd ff 	movzbl -0x2db(%rbp,%rcx,1),%esi
 11ba72b:	ff 
 11ba72c:	40 80 e6 0f          	and    $0xf,%sil
 11ba730:	40 88 34 13          	mov    %sil,(%rbx,%rdx,1)
 11ba734:	41 0f b7 54 4e 14    	movzwl 0x14(%r14,%rcx,2),%edx
 11ba73a:	0f b6 b4 0d 26 fd ff 	movzbl -0x2da(%rbp,%rcx,1),%esi
 11ba741:	ff 
 11ba742:	40 80 e6 0f          	and    $0xf,%sil
 11ba746:	40 88 34 13          	mov    %sil,(%rbx,%rdx,1)
 11ba74a:	41 0f b7 54 4e 16    	movzwl 0x16(%r14,%rcx,2),%edx
 11ba750:	0f b6 b4 0d 27 fd ff 	movzbl -0x2d9(%rbp,%rcx,1),%esi
 11ba757:	ff 
 11ba758:	40 80 e6 0f          	and    $0xf,%sil
 11ba75c:	40 88 34 13          	mov    %sil,(%rbx,%rdx,1)
 11ba760:	48 83 c1 08          	add    $0x8,%rcx
 11ba764:	49 39 cc             	cmp    %rcx,%r12
 11ba767:	0f 85 43 ff ff ff    	jne    11ba6b0 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35946+0x190>
 11ba76d:	48 85 c0             	test   %rax,%rax
 11ba770:	74 37                	je     11ba7a9 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35946+0x289>
 11ba772:	48 8d 14 29          	lea    (%rcx,%rbp,1),%rdx
 11ba776:	48 81 c2 20 fd ff ff 	add    $0xfffffffffffffd20,%rdx
 11ba77d:	49 8d 0c 4e          	lea    (%r14,%rcx,2),%rcx
 11ba781:	48 83 c1 08          	add    $0x8,%rcx
 11ba785:	31 f6                	xor    %esi,%esi
 11ba787:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 11ba78e:	00 00 
 11ba790:	0f b7 3c 71          	movzwl (%rcx,%rsi,2),%edi
 11ba794:	44 0f b6 04 32       	movzbl (%rdx,%rsi,1),%r8d
 11ba799:	41 80 e0 0f          	and    $0xf,%r8b
 11ba79d:	44 88 04 3b          	mov    %r8b,(%rbx,%rdi,1)
 11ba7a1:	48 ff c6             	inc    %rsi
 11ba7a4:	48 39 f0             	cmp    %rsi,%rax
 11ba7a7:	75 e7                	jne    11ba790 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35946+0x270>
 11ba7a9:	48 81 c4 80 10 00 00 	add    $0x1080,%rsp
 11ba7b0:	5b                   	pop    %rbx
 11ba7b1:	41 5c                	pop    %r12
 11ba7b3:	41 5e                	pop    %r14
 11ba7b5:	41 5f                	pop    %r15
 11ba7b7:	5d                   	pop    %rbp
 11ba7b8:	c3                   	ret    

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
