
/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/7cab685de62cdb93856431f8e3ddb813/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

00000000011bac80 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35943>:
 11bac80:	55                   	push   %rbp
 11bac81:	48 89 e5             	mov    %rsp,%rbp
 11bac84:	41 57                	push   %r15
 11bac86:	41 56                	push   %r14
 11bac88:	41 54                	push   %r12
 11bac8a:	53                   	push   %rbx
 11bac8b:	48 81 ec 00 06 00 00 	sub    $0x600,%rsp
 11bac92:	48 89 d3             	mov    %rdx,%rbx
 11bac95:	49 89 f7             	mov    %rsi,%r15
 11bac98:	49 89 fe             	mov    %rdi,%r14
 11bac9b:	4c 8b 27             	mov    (%rdi),%r12
 11bac9e:	48 8d bd e0 f9 ff ff 	lea    -0x620(%rbp),%rdi
 11baca5:	ba 00 04 00 00       	mov    $0x400,%edx
 11bacaa:	31 f6                	xor    %esi,%esi
 11bacac:	e8 cf cb 0d 00       	call   1297880 <compiler_rt.memset>
 11bacb1:	4d 85 e4             	test   %r12,%r12
 11bacb4:	74 13                	je     11bacc9 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35943+0x49>
 11bacb6:	44 89 e0             	mov    %r12d,%eax
 11bacb9:	83 e0 07             	and    $0x7,%eax
 11bacbc:	49 83 fc 08          	cmp    $0x8,%r12
 11bacc0:	73 24                	jae    11bace6 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35943+0x66>
 11bacc2:	31 c9                	xor    %ecx,%ecx
 11bacc4:	e9 cc 00 00 00       	jmp    11bad95 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35943+0x115>
 11bacc9:	48 8d bd e0 fd ff ff 	lea    -0x220(%rbp),%rdi
 11bacd0:	48 8d b5 e0 f9 ff ff 	lea    -0x620(%rbp),%rsi
 11bacd7:	ba 0f 00 00 00       	mov    $0xf,%edx
 11bacdc:	e8 5f fd fc ff       	call   118aa40 <huffman.treeCodeLengths__anon_40857>
 11bace1:	e9 83 02 00 00       	jmp    11baf69 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35943+0x2e9>
 11bace6:	44 89 e2             	mov    %r12d,%edx
 11bace9:	81 e2 f8 01 00 00    	and    $0x1f8,%edx
 11bacef:	31 c9                	xor    %ecx,%ecx
 11bacf1:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 11bacf8:	0f 1f 84 00 00 00 00 
 11bacff:	00 
 11bad00:	41 0f b7 74 4e 08    	movzwl 0x8(%r14,%rcx,2),%esi
 11bad06:	41 8b 34 b7          	mov    (%r15,%rsi,4),%esi
 11bad0a:	89 b4 8d e0 f9 ff ff 	mov    %esi,-0x620(%rbp,%rcx,4)
 11bad11:	41 0f b7 74 4e 0a    	movzwl 0xa(%r14,%rcx,2),%esi
 11bad17:	41 8b 34 b7          	mov    (%r15,%rsi,4),%esi
 11bad1b:	89 b4 8d e4 f9 ff ff 	mov    %esi,-0x61c(%rbp,%rcx,4)
 11bad22:	41 0f b7 74 4e 0c    	movzwl 0xc(%r14,%rcx,2),%esi
 11bad28:	41 8b 34 b7          	mov    (%r15,%rsi,4),%esi
 11bad2c:	89 b4 8d e8 f9 ff ff 	mov    %esi,-0x618(%rbp,%rcx,4)
 11bad33:	41 0f b7 74 4e 0e    	movzwl 0xe(%r14,%rcx,2),%esi
 11bad39:	41 8b 34 b7          	mov    (%r15,%rsi,4),%esi
 11bad3d:	89 b4 8d ec f9 ff ff 	mov    %esi,-0x614(%rbp,%rcx,4)
 11bad44:	41 0f b7 74 4e 10    	movzwl 0x10(%r14,%rcx,2),%esi
 11bad4a:	41 8b 34 b7          	mov    (%r15,%rsi,4),%esi
 11bad4e:	89 b4 8d f0 f9 ff ff 	mov    %esi,-0x610(%rbp,%rcx,4)
 11bad55:	41 0f b7 74 4e 12    	movzwl 0x12(%r14,%rcx,2),%esi
 11bad5b:	41 8b 34 b7          	mov    (%r15,%rsi,4),%esi
 11bad5f:	89 b4 8d f4 f9 ff ff 	mov    %esi,-0x60c(%rbp,%rcx,4)
 11bad66:	41 0f b7 74 4e 14    	movzwl 0x14(%r14,%rcx,2),%esi
 11bad6c:	41 8b 34 b7          	mov    (%r15,%rsi,4),%esi
 11bad70:	89 b4 8d f8 f9 ff ff 	mov    %esi,-0x608(%rbp,%rcx,4)
 11bad77:	41 0f b7 74 4e 16    	movzwl 0x16(%r14,%rcx,2),%esi
 11bad7d:	41 8b 34 b7          	mov    (%r15,%rsi,4),%esi
 11bad81:	89 b4 8d fc f9 ff ff 	mov    %esi,-0x604(%rbp,%rcx,4)
 11bad88:	48 83 c1 08          	add    $0x8,%rcx
 11bad8c:	48 39 ca             	cmp    %rcx,%rdx
 11bad8f:	0f 85 6b ff ff ff    	jne    11bad00 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35943+0x80>
 11bad95:	48 85 c0             	test   %rax,%rax
 11bad98:	74 29                	je     11badc3 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35943+0x143>
 11bad9a:	48 8d 14 8d e0 f9 ff 	lea    -0x620(,%rcx,4),%rdx
 11bada1:	ff 
 11bada2:	48 01 ea             	add    %rbp,%rdx
 11bada5:	49 8d 0c 4e          	lea    (%r14,%rcx,2),%rcx
 11bada9:	48 83 c1 08          	add    $0x8,%rcx
 11badad:	31 f6                	xor    %esi,%esi
 11badaf:	90                   	nop
 11badb0:	0f b7 3c 71          	movzwl (%rcx,%rsi,2),%edi
 11badb4:	41 8b 3c bf          	mov    (%r15,%rdi,4),%edi
 11badb8:	89 3c b2             	mov    %edi,(%rdx,%rsi,4)
 11badbb:	48 ff c6             	inc    %rsi
 11badbe:	48 39 f0             	cmp    %rsi,%rax
 11badc1:	75 ed                	jne    11badb0 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35943+0x130>
 11badc3:	48 8d bd e0 fd ff ff 	lea    -0x220(%rbp),%rdi
 11badca:	48 8d b5 e0 f9 ff ff 	lea    -0x620(%rbp),%rsi
 11badd1:	ba 0f 00 00 00       	mov    $0xf,%edx
 11badd6:	e8 65 fc fc ff       	call   118aa40 <huffman.treeCodeLengths__anon_40857>
 11baddb:	c5 fc 10 85 c0 fe ff 	vmovups -0x140(%rbp),%ymm0
 11bade2:	ff 
 11bade3:	c5 fc 11 45 c0       	vmovups %ymm0,-0x40(%rbp)
 11bade8:	c5 fc 10 85 a0 fe ff 	vmovups -0x160(%rbp),%ymm0
 11badef:	ff 
 11badf0:	c5 fc 11 45 a0       	vmovups %ymm0,-0x60(%rbp)
 11badf5:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 11badfc:	ff 
 11badfd:	c5 fc 11 45 80       	vmovups %ymm0,-0x80(%rbp)
 11bae02:	c5 fc 10 85 60 fe ff 	vmovups -0x1a0(%rbp),%ymm0
 11bae09:	ff 
 11bae0a:	c5 fc 11 85 60 ff ff 	vmovups %ymm0,-0xa0(%rbp)
 11bae11:	ff 
 11bae12:	c5 fc 10 85 e0 fd ff 	vmovups -0x220(%rbp),%ymm0
 11bae19:	ff 
 11bae1a:	c5 fc 10 8d 00 fe ff 	vmovups -0x200(%rbp),%ymm1
 11bae21:	ff 
 11bae22:	c5 fc 10 95 20 fe ff 	vmovups -0x1e0(%rbp),%ymm2
 11bae29:	ff 
 11bae2a:	c5 fc 10 9d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm3
 11bae31:	ff 
 11bae32:	c5 fc 11 9d 40 ff ff 	vmovups %ymm3,-0xc0(%rbp)
 11bae39:	ff 
 11bae3a:	c5 fc 11 95 20 ff ff 	vmovups %ymm2,-0xe0(%rbp)
 11bae41:	ff 
 11bae42:	c5 fc 11 8d 00 ff ff 	vmovups %ymm1,-0x100(%rbp)
 11bae49:	ff 
 11bae4a:	c5 fc 11 85 e0 fe ff 	vmovups %ymm0,-0x120(%rbp)
 11bae51:	ff 
 11bae52:	44 89 e0             	mov    %r12d,%eax
 11bae55:	83 e0 07             	and    $0x7,%eax
 11bae58:	49 83 fc 08          	cmp    $0x8,%r12
 11bae5c:	73 07                	jae    11bae65 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35943+0x1e5>
 11bae5e:	31 c9                	xor    %ecx,%ecx
 11bae60:	e9 c8 00 00 00       	jmp    11baf2d <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35943+0x2ad>
 11bae65:	41 81 e4 f8 01 00 00 	and    $0x1f8,%r12d
 11bae6c:	31 c9                	xor    %ecx,%ecx
 11bae6e:	66 90                	xchg   %ax,%ax
 11bae70:	41 0f b7 54 4e 08    	movzwl 0x8(%r14,%rcx,2),%edx
 11bae76:	0f b6 b4 0d e0 fe ff 	movzbl -0x120(%rbp,%rcx,1),%esi
 11bae7d:	ff 
 11bae7e:	40 80 e6 0f          	and    $0xf,%sil
 11bae82:	40 88 34 13          	mov    %sil,(%rbx,%rdx,1)
 11bae86:	41 0f b7 54 4e 0a    	movzwl 0xa(%r14,%rcx,2),%edx
 11bae8c:	0f b6 b4 0d e1 fe ff 	movzbl -0x11f(%rbp,%rcx,1),%esi
 11bae93:	ff 
 11bae94:	40 80 e6 0f          	and    $0xf,%sil
 11bae98:	40 88 34 13          	mov    %sil,(%rbx,%rdx,1)
 11bae9c:	41 0f b7 54 4e 0c    	movzwl 0xc(%r14,%rcx,2),%edx
 11baea2:	0f b6 b4 0d e2 fe ff 	movzbl -0x11e(%rbp,%rcx,1),%esi
 11baea9:	ff 
 11baeaa:	40 80 e6 0f          	and    $0xf,%sil
 11baeae:	40 88 34 13          	mov    %sil,(%rbx,%rdx,1)
 11baeb2:	41 0f b7 54 4e 0e    	movzwl 0xe(%r14,%rcx,2),%edx
 11baeb8:	0f b6 b4 0d e3 fe ff 	movzbl -0x11d(%rbp,%rcx,1),%esi
 11baebf:	ff 
 11baec0:	40 80 e6 0f          	and    $0xf,%sil
 11baec4:	40 88 34 13          	mov    %sil,(%rbx,%rdx,1)
 11baec8:	41 0f b7 54 4e 10    	movzwl 0x10(%r14,%rcx,2),%edx
 11baece:	0f b6 b4 0d e4 fe ff 	movzbl -0x11c(%rbp,%rcx,1),%esi
 11baed5:	ff 
 11baed6:	40 80 e6 0f          	and    $0xf,%sil
 11baeda:	40 88 34 13          	mov    %sil,(%rbx,%rdx,1)
 11baede:	41 0f b7 54 4e 12    	movzwl 0x12(%r14,%rcx,2),%edx
 11baee4:	0f b6 b4 0d e5 fe ff 	movzbl -0x11b(%rbp,%rcx,1),%esi
 11baeeb:	ff 
 11baeec:	40 80 e6 0f          	and    $0xf,%sil
 11baef0:	40 88 34 13          	mov    %sil,(%rbx,%rdx,1)
 11baef4:	41 0f b7 54 4e 14    	movzwl 0x14(%r14,%rcx,2),%edx
 11baefa:	0f b6 b4 0d e6 fe ff 	movzbl -0x11a(%rbp,%rcx,1),%esi
 11baf01:	ff 
 11baf02:	40 80 e6 0f          	and    $0xf,%sil
 11baf06:	40 88 34 13          	mov    %sil,(%rbx,%rdx,1)
 11baf0a:	41 0f b7 54 4e 16    	movzwl 0x16(%r14,%rcx,2),%edx
 11baf10:	0f b6 b4 0d e7 fe ff 	movzbl -0x119(%rbp,%rcx,1),%esi
 11baf17:	ff 
 11baf18:	40 80 e6 0f          	and    $0xf,%sil
 11baf1c:	40 88 34 13          	mov    %sil,(%rbx,%rdx,1)
 11baf20:	48 83 c1 08          	add    $0x8,%rcx
 11baf24:	49 39 cc             	cmp    %rcx,%r12
 11baf27:	0f 85 43 ff ff ff    	jne    11bae70 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35943+0x1f0>
 11baf2d:	48 85 c0             	test   %rax,%rax
 11baf30:	74 37                	je     11baf69 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35943+0x2e9>
 11baf32:	48 8d 14 29          	lea    (%rcx,%rbp,1),%rdx
 11baf36:	48 81 c2 e0 fe ff ff 	add    $0xfffffffffffffee0,%rdx
 11baf3d:	49 8d 0c 4e          	lea    (%r14,%rcx,2),%rcx
 11baf41:	48 83 c1 08          	add    $0x8,%rcx
 11baf45:	31 f6                	xor    %esi,%esi
 11baf47:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 11baf4e:	00 00 
 11baf50:	0f b7 3c 71          	movzwl (%rcx,%rsi,2),%edi
 11baf54:	44 0f b6 04 32       	movzbl (%rdx,%rsi,1),%r8d
 11baf59:	41 80 e0 0f          	and    $0xf,%r8b
 11baf5d:	44 88 04 3b          	mov    %r8b,(%rbx,%rdi,1)
 11baf61:	48 ff c6             	inc    %rsi
 11baf64:	48 39 f0             	cmp    %rsi,%rax
 11baf67:	75 e7                	jne    11baf50 <br.encoder.command_plan.PrefixAlphabetFor(256).fillTreeLengths__anon_35943+0x2d0>
 11baf69:	48 81 c4 00 06 00 00 	add    $0x600,%rsp
 11baf70:	5b                   	pop    %rbx
 11baf71:	41 5c                	pop    %r12
 11baf73:	41 5e                	pop    %r14
 11baf75:	41 5f                	pop    %r15
 11baf77:	5d                   	pop    %rbp
 11baf78:	c5 f8 77             	vzeroupper 
 11baf7b:	c3                   	ret    

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
