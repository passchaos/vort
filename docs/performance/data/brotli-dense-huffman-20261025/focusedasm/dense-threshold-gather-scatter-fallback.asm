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

 1175521:	48 81 fb 01 01 00 00 	cmp    $0x101,%rbx
 1175528:	0f 83 c7 02 00 00    	jae    11757f5 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x5d5>
 117552e:	89 d8                	mov    %ebx,%eax
 1175530:	83 e0 07             	and    $0x7,%eax
 1175533:	49 83 fc 07          	cmp    $0x7,%r12
 1175537:	0f 83 26 05 00 00    	jae    1175a63 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x843>
 117553d:	31 c9                	xor    %ecx,%ecx
 117553f:	e9 c9 05 00 00       	jmp    1175b0d <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths+0x8ed>

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
