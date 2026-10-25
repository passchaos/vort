
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

00000000011bba40 <br.encodeCommandPlanWithOptionsWrite>:
 11bba40:	55                   	push   %rbp
 11bba41:	48 89 e5             	mov    %rsp,%rbp
 11bba44:	41 57                	push   %r15
 11bba46:	41 56                	push   %r14
 11bba48:	41 55                	push   %r13
 11bba4a:	41 54                	push   %r12
 11bba4c:	53                   	push   %rbx
 11bba4d:	48 81 ec 18 f7 06 00 	sub    $0x6f718,%rsp
 11bba54:	49 89 ce             	mov    %rcx,%r14
 11bba57:	4c 8b 5d 18          	mov    0x18(%rbp),%r11
 11bba5b:	48 8b 45 10          	mov    0x10(%rbp),%rax
 11bba5f:	48 89 85 58 fe ff ff 	mov    %rax,-0x1a8(%rbp)
 11bba66:	4d 8b bb 08 01 00 00 	mov    0x108(%r11),%r15
 11bba6d:	49 8b 9b 88 01 00 00 	mov    0x188(%r11),%rbx
 11bba74:	4d 8b 93 00 02 00 00 	mov    0x200(%r11),%r10
 11bba7b:	4d 8b a3 08 02 00 00 	mov    0x208(%r11),%r12
 11bba82:	41 0f b7 8b 1a 02 00 	movzwl 0x21a(%r11),%ecx
 11bba89:	00 
 11bba8a:	41 0f b6 83 21 02 00 	movzbl 0x221(%r11),%eax
 11bba91:	00 
 11bba92:	4c 89 a5 f0 fb ff ff 	mov    %r12,-0x410(%rbp)
 11bba99:	4d 01 f4             	add    %r14,%r12
 11bba9c:	0f 92 85 20 fc ff ff 	setb   -0x3e0(%rbp)
 11bbaa3:	41 0f 92 c5          	setb   %r13b
 11bbaa7:	73 0d                	jae    11bbab6 <br.encodeCommandPlanWithOptionsWrite+0x76>
 11bbaa9:	66 b8 43 00          	mov    $0x43,%ax
 11bbaad:	48 81 c4 18 f7 06 00 	add    $0x6f718,%rsp
 11bbab4:	eb 66                	jmp    11bbb1c <br.encodeCommandPlanWithOptionsWrite+0xdc>
 11bbab6:	a8 01                	test   $0x1,%al
 11bbab8:	74 12                	je     11bbacc <br.encodeCommandPlanWithOptionsWrite+0x8c>
 11bbaba:	4c 89 f1             	mov    %r14,%rcx
 11bbabd:	41 53                	push   %r11
 11bbabf:	ff b5 58 fe ff ff    	push   -0x1a8(%rbp)
 11bbac5:	e8 a6 de 04 00       	call   1209970 <br.encodeCommandPlanWithLargeWindowWrite>
 11bbaca:	eb 49                	jmp    11bbb15 <br.encodeCommandPlanWithOptionsWrite+0xd5>
 11bbacc:	44 88 ad 53 ff ff ff 	mov    %r13b,-0xad(%rbp)
 11bbad3:	4c 89 a5 48 fa ff ff 	mov    %r12,-0x5b8(%rbp)
 11bbada:	41 89 cd             	mov    %ecx,%r13d
 11bbadd:	41 c1 ed 08          	shr    $0x8,%r13d
 11bbae1:	41 80 e5 0f          	and    $0xf,%r13b
 11bbae5:	80 e1 03             	and    $0x3,%cl
 11bbae8:	41 d2 e5             	shl    %cl,%r13b
 11bbaeb:	45 0f b6 ed          	movzbl %r13b,%r13d
 11bbaef:	41 bc 30 00 00 00    	mov    $0x30,%r12d
 11bbaf5:	c4 c2 71 f7 cc       	shlx   %ecx,%r12d,%ecx
 11bbafa:	44 01 e9             	add    %r13d,%ecx
 11bbafd:	83 c1 10             	add    $0x10,%ecx
 11bbb00:	83 f9 50             	cmp    $0x50,%ecx
 11bbb03:	72 25                	jb     11bbb2a <br.encodeCommandPlanWithOptionsWrite+0xea>
 11bbb05:	4c 89 f1             	mov    %r14,%rcx
 11bbb08:	41 53                	push   %r11
 11bbb0a:	ff b5 58 fe ff ff    	push   -0x1a8(%rbp)
 11bbb10:	e8 fb 84 13 00       	call   12f4010 <br.encodeCommandPlanWithWideDistanceWrite>
 11bbb15:	48 81 c4 28 f7 06 00 	add    $0x6f728,%rsp
 11bbb1c:	5b                   	pop    %rbx
 11bbb1d:	41 5c                	pop    %r12
 11bbb1f:	41 5d                	pop    %r13
 11bbb21:	41 5e                	pop    %r14
 11bbb23:	41 5f                	pop    %r15
 11bbb25:	5d                   	pop    %rbp
 11bbb26:	c5 f8 77             	vzeroupper 
 11bbb29:	c3                   	ret    
 11bbb2a:	4d 85 ff             	test   %r15,%r15
 11bbb2d:	0f 85 f4 05 00 00    	jne    11bc127 <br.encodeCommandPlanWithOptionsWrite+0x6e7>
 11bbb33:	48 85 db             	test   %rbx,%rbx
 11bbb36:	0f 85 eb 05 00 00    	jne    11bc127 <br.encodeCommandPlanWithOptionsWrite+0x6e7>
 11bbb3c:	4d 85 d2             	test   %r10,%r10
 11bbb3f:	0f 85 e2 05 00 00    	jne    11bc127 <br.encodeCommandPlanWithOptionsWrite+0x6e7>
 11bbb45:	49 8b 0b             	mov    (%r11),%rcx
 11bbb48:	48 89 8d e8 fd ff ff 	mov    %rcx,-0x218(%rbp)
 11bbb4f:	49 8b 4b 08          	mov    0x8(%r11),%rcx
 11bbb53:	48 89 8d 70 fd ff ff 	mov    %rcx,-0x290(%rbp)
 11bbb5a:	49 8b 4b 10          	mov    0x10(%r11),%rcx
 11bbb5e:	48 89 8d f0 fd ff ff 	mov    %rcx,-0x210(%rbp)
 11bbb65:	49 8b 4b 18          	mov    0x18(%r11),%rcx
 11bbb69:	48 89 8d e0 fc ff ff 	mov    %rcx,-0x320(%rbp)
 11bbb70:	c4 c1 7c 10 43 20    	vmovups 0x20(%r11),%ymm0
 11bbb76:	c5 fc 11 85 e0 ef ff 	vmovups %ymm0,-0x1020(%rbp)
 11bbb7d:	ff 
 11bbb7e:	41 0f b6 8b 90 00 00 	movzbl 0x90(%r11),%ecx
 11bbb85:	00 
 11bbb86:	88 4d 80             	mov    %cl,-0x80(%rbp)
 11bbb89:	49 8b 8b 98 00 00 00 	mov    0x98(%r11),%rcx
 11bbb90:	48 89 8d 18 ff ff ff 	mov    %rcx,-0xe8(%rbp)
 11bbb97:	49 8b 8b a0 00 00 00 	mov    0xa0(%r11),%rcx
 11bbb9e:	48 89 8d 00 ff ff ff 	mov    %rcx,-0x100(%rbp)
 11bbba5:	41 0f b6 8b a8 00 00 	movzbl 0xa8(%r11),%ecx
 11bbbac:	00 
 11bbbad:	88 4d c5             	mov    %cl,-0x3b(%rbp)
 11bbbb0:	41 8b 8b ac 00 00 00 	mov    0xac(%r11),%ecx
 11bbbb7:	89 8d 0b fe ff ff    	mov    %ecx,-0x1f5(%rbp)
 11bbbbd:	41 8b 8b a9 00 00 00 	mov    0xa9(%r11),%ecx
 11bbbc4:	89 8d 08 fe ff ff    	mov    %ecx,-0x1f8(%rbp)
 11bbbca:	49 8b 8b b0 00 00 00 	mov    0xb0(%r11),%rcx
 11bbbd1:	48 89 8d 20 ff ff ff 	mov    %rcx,-0xe0(%rbp)
 11bbbd8:	41 0f b6 8b b8 00 00 	movzbl 0xb8(%r11),%ecx
 11bbbdf:	00 
 11bbbe0:	88 4d cf             	mov    %cl,-0x31(%rbp)
 11bbbe3:	41 8b 8b bc 00 00 00 	mov    0xbc(%r11),%ecx
 11bbbea:	89 8d 13 fe ff ff    	mov    %ecx,-0x1ed(%rbp)
 11bbbf0:	41 8b 8b b9 00 00 00 	mov    0xb9(%r11),%ecx
 11bbbf7:	89 8d 10 fe ff ff    	mov    %ecx,-0x1f0(%rbp)
 11bbbfd:	49 8b 8b c0 00 00 00 	mov    0xc0(%r11),%rcx
 11bbc04:	48 89 8d 28 ff ff ff 	mov    %rcx,-0xd8(%rbp)
 11bbc0b:	41 0f b6 8b c8 00 00 	movzbl 0xc8(%r11),%ecx
 11bbc12:	00 
 11bbc13:	88 4d d1             	mov    %cl,-0x2f(%rbp)
 11bbc16:	41 8b 8b cc 00 00 00 	mov    0xcc(%r11),%ecx
 11bbc1d:	89 8d 1b fe ff ff    	mov    %ecx,-0x1e5(%rbp)
 11bbc23:	41 8b 8b c9 00 00 00 	mov    0xc9(%r11),%ecx
 11bbc2a:	89 8d 18 fe ff ff    	mov    %ecx,-0x1e8(%rbp)
 11bbc30:	49 8b 8b d0 00 00 00 	mov    0xd0(%r11),%rcx
 11bbc37:	48 89 8d 30 ff ff ff 	mov    %rcx,-0xd0(%rbp)
 11bbc3e:	41 0f b6 8b d8 00 00 	movzbl 0xd8(%r11),%ecx
 11bbc45:	00 
 11bbc46:	88 4d c7             	mov    %cl,-0x39(%rbp)
 11bbc49:	41 8b 8b dc 00 00 00 	mov    0xdc(%r11),%ecx
 11bbc50:	89 8d 23 fe ff ff    	mov    %ecx,-0x1dd(%rbp)
 11bbc56:	41 8b 8b d9 00 00 00 	mov    0xd9(%r11),%ecx
 11bbc5d:	89 8d 20 fe ff ff    	mov    %ecx,-0x1e0(%rbp)
 11bbc63:	49 8b 8b e0 00 00 00 	mov    0xe0(%r11),%rcx
 11bbc6a:	48 89 8d 38 ff ff ff 	mov    %rcx,-0xc8(%rbp)
 11bbc71:	41 0f b6 8b e8 00 00 	movzbl 0xe8(%r11),%ecx
 11bbc78:	00 
 11bbc79:	88 4d c0             	mov    %cl,-0x40(%rbp)
 11bbc7c:	41 8b 8b ec 00 00 00 	mov    0xec(%r11),%ecx
 11bbc83:	89 8d 2b fe ff ff    	mov    %ecx,-0x1d5(%rbp)
 11bbc89:	41 8b 8b e9 00 00 00 	mov    0xe9(%r11),%ecx
 11bbc90:	89 8d 28 fe ff ff    	mov    %ecx,-0x1d8(%rbp)
 11bbc96:	41 0f b6 8b f8 00 00 	movzbl 0xf8(%r11),%ecx
 11bbc9d:	00 
 11bbc9e:	88 4d cc             	mov    %cl,-0x34(%rbp)
 11bbca1:	41 0f b6 8b f9 00 00 	movzbl 0xf9(%r11),%ecx
 11bbca8:	00 
 11bbca9:	88 4d c2             	mov    %cl,-0x3e(%rbp)
 11bbcac:	49 8b 8b f0 00 00 00 	mov    0xf0(%r11),%rcx
 11bbcb3:	48 89 8d d8 fc ff ff 	mov    %rcx,-0x328(%rbp)
 11bbcba:	41 0f b7 8b fe 00 00 	movzwl 0xfe(%r11),%ecx
 11bbcc1:	00 
 11bbcc2:	66 89 8d 54 fe ff ff 	mov    %cx,-0x1ac(%rbp)
 11bbcc9:	41 8b 8b fa 00 00 00 	mov    0xfa(%r11),%ecx
 11bbcd0:	89 8d 50 fe ff ff    	mov    %ecx,-0x1b0(%rbp)
 11bbcd6:	41 0f b6 8b 00 01 00 	movzbl 0x100(%r11),%ecx
 11bbcdd:	00 
 11bbcde:	88 4d c6             	mov    %cl,-0x3a(%rbp)
 11bbce1:	41 0f b6 8b 28 01 00 	movzbl 0x128(%r11),%ecx
 11bbce8:	00 
 11bbce9:	88 4d ca             	mov    %cl,-0x36(%rbp)
 11bbcec:	49 8b 8b 10 01 00 00 	mov    0x110(%r11),%rcx
 11bbcf3:	48 89 4d 90          	mov    %rcx,-0x70(%rbp)
 11bbcf7:	49 8b 8b 18 01 00 00 	mov    0x118(%r11),%rcx
 11bbcfe:	48 89 8d 38 fe ff ff 	mov    %rcx,-0x1c8(%rbp)
 11bbd05:	49 8b 8b 20 01 00 00 	mov    0x120(%r11),%rcx
 11bbd0c:	48 89 8d c0 fd ff ff 	mov    %rcx,-0x240(%rbp)
 11bbd13:	41 8b 8b 2c 01 00 00 	mov    0x12c(%r11),%ecx
 11bbd1a:	89 8d 8b fe ff ff    	mov    %ecx,-0x175(%rbp)
 11bbd20:	41 8b 8b 29 01 00 00 	mov    0x129(%r11),%ecx
 11bbd27:	89 8d 88 fe ff ff    	mov    %ecx,-0x178(%rbp)
 11bbd2d:	41 0f b6 8b 38 01 00 	movzbl 0x138(%r11),%ecx
 11bbd34:	00 
 11bbd35:	88 4d d0             	mov    %cl,-0x30(%rbp)
 11bbd38:	49 8b 8b 30 01 00 00 	mov    0x130(%r11),%rcx
 11bbd3f:	48 89 8d c8 fd ff ff 	mov    %rcx,-0x238(%rbp)
 11bbd46:	41 8b 8b 3c 01 00 00 	mov    0x13c(%r11),%ecx
 11bbd4d:	89 8d 93 fe ff ff    	mov    %ecx,-0x16d(%rbp)
 11bbd53:	41 8b 8b 39 01 00 00 	mov    0x139(%r11),%ecx
 11bbd5a:	89 8d 90 fe ff ff    	mov    %ecx,-0x170(%rbp)
 11bbd60:	41 0f b6 8b 48 01 00 	movzbl 0x148(%r11),%ecx
 11bbd67:	00 
 11bbd68:	88 4d d6             	mov    %cl,-0x2a(%rbp)
 11bbd6b:	49 8b 8b 40 01 00 00 	mov    0x140(%r11),%rcx
 11bbd72:	48 89 8d d0 fd ff ff 	mov    %rcx,-0x230(%rbp)
 11bbd79:	41 8b 8b 4c 01 00 00 	mov    0x14c(%r11),%ecx
 11bbd80:	89 8d 9b fe ff ff    	mov    %ecx,-0x165(%rbp)
 11bbd86:	41 8b 8b 49 01 00 00 	mov    0x149(%r11),%ecx
 11bbd8d:	89 8d 98 fe ff ff    	mov    %ecx,-0x168(%rbp)
 11bbd93:	41 0f b6 8b 58 01 00 	movzbl 0x158(%r11),%ecx
 11bbd9a:	00 
 11bbd9b:	88 4d cd             	mov    %cl,-0x33(%rbp)
 11bbd9e:	49 8b 8b 50 01 00 00 	mov    0x150(%r11),%rcx
 11bbda5:	48 89 8d d8 fd ff ff 	mov    %rcx,-0x228(%rbp)
 11bbdac:	41 8b 8b 5c 01 00 00 	mov    0x15c(%r11),%ecx
 11bbdb3:	89 8d a3 fe ff ff    	mov    %ecx,-0x15d(%rbp)
 11bbdb9:	41 8b 8b 59 01 00 00 	mov    0x159(%r11),%ecx
 11bbdc0:	89 8d a0 fe ff ff    	mov    %ecx,-0x160(%rbp)
 11bbdc6:	41 0f b6 8b 68 01 00 	movzbl 0x168(%r11),%ecx
 11bbdcd:	00 
 11bbdce:	88 4d c1             	mov    %cl,-0x3f(%rbp)
 11bbdd1:	49 8b 8b 60 01 00 00 	mov    0x160(%r11),%rcx
 11bbdd8:	48 89 8d 70 ff ff ff 	mov    %rcx,-0x90(%rbp)
 11bbddf:	41 8b 8b 6c 01 00 00 	mov    0x16c(%r11),%ecx
 11bbde6:	89 8d ab fe ff ff    	mov    %ecx,-0x155(%rbp)
 11bbdec:	41 8b 8b 69 01 00 00 	mov    0x169(%r11),%ecx
 11bbdf3:	89 8d a8 fe ff ff    	mov    %ecx,-0x158(%rbp)
 11bbdf9:	41 0f b6 8b 78 01 00 	movzbl 0x178(%r11),%ecx
 11bbe00:	00 
 11bbe01:	88 4d d2             	mov    %cl,-0x2e(%rbp)
 11bbe04:	49 8b 8b 70 01 00 00 	mov    0x170(%r11),%rcx
 11bbe0b:	48 89 8d f8 fc ff ff 	mov    %rcx,-0x308(%rbp)
 11bbe12:	41 0f b7 8b 7e 01 00 	movzwl 0x17e(%r11),%ecx
 11bbe19:	00 
 11bbe1a:	45 0f b6 93 79 01 00 	movzbl 0x179(%r11),%r10d
 11bbe21:	00 
 11bbe22:	44 88 55 c8          	mov    %r10b,-0x38(%rbp)
 11bbe26:	66 89 8d f0 fe ff ff 	mov    %cx,-0x110(%rbp)
 11bbe2d:	41 8b 8b 7a 01 00 00 	mov    0x17a(%r11),%ecx
 11bbe34:	89 8d ec fe ff ff    	mov    %ecx,-0x114(%rbp)
 11bbe3a:	49 8b 8b 90 01 00 00 	mov    0x190(%r11),%rcx
 11bbe41:	48 89 8d d8 fe ff ff 	mov    %rcx,-0x128(%rbp)
 11bbe48:	49 8b 8b 98 01 00 00 	mov    0x198(%r11),%rcx
 11bbe4f:	48 89 8d 60 fe ff ff 	mov    %rcx,-0x1a0(%rbp)
 11bbe56:	41 8b 8b a4 01 00 00 	mov    0x1a4(%r11),%ecx
 11bbe5d:	45 0f b6 93 80 01 00 	movzbl 0x180(%r11),%r10d
 11bbe64:	00 
 11bbe65:	44 88 55 c3          	mov    %r10b,-0x3d(%rbp)
 11bbe69:	45 0f b6 bb a0 01 00 	movzbl 0x1a0(%r11),%r15d
 11bbe70:	00 
 11bbe71:	89 8d b3 fe ff ff    	mov    %ecx,-0x14d(%rbp)
 11bbe77:	41 8b 8b a1 01 00 00 	mov    0x1a1(%r11),%ecx
 11bbe7e:	89 8d b0 fe ff ff    	mov    %ecx,-0x150(%rbp)
 11bbe84:	49 8b 8b a8 01 00 00 	mov    0x1a8(%r11),%rcx
 11bbe8b:	48 89 8d 68 fe ff ff 	mov    %rcx,-0x198(%rbp)
 11bbe92:	41 8b 8b b4 01 00 00 	mov    0x1b4(%r11),%ecx
 11bbe99:	45 0f b6 93 b0 01 00 	movzbl 0x1b0(%r11),%r10d
 11bbea0:	00 
 11bbea1:	44 88 55 d4          	mov    %r10b,-0x2c(%rbp)
 11bbea5:	89 8d bb fe ff ff    	mov    %ecx,-0x145(%rbp)
 11bbeab:	41 8b 8b b1 01 00 00 	mov    0x1b1(%r11),%ecx
 11bbeb2:	89 8d b8 fe ff ff    	mov    %ecx,-0x148(%rbp)
 11bbeb8:	49 8b 8b b8 01 00 00 	mov    0x1b8(%r11),%rcx
 11bbebf:	48 89 8d 70 fe ff ff 	mov    %rcx,-0x190(%rbp)
 11bbec6:	41 8b 8b c4 01 00 00 	mov    0x1c4(%r11),%ecx
 11bbecd:	45 0f b6 93 c0 01 00 	movzbl 0x1c0(%r11),%r10d
 11bbed4:	00 
 11bbed5:	44 88 55 d7          	mov    %r10b,-0x29(%rbp)
 11bbed9:	89 8d c3 fe ff ff    	mov    %ecx,-0x13d(%rbp)
 11bbedf:	41 8b 8b c1 01 00 00 	mov    0x1c1(%r11),%ecx
 11bbee6:	89 8d c0 fe ff ff    	mov    %ecx,-0x140(%rbp)
 11bbeec:	49 8b 8b c8 01 00 00 	mov    0x1c8(%r11),%rcx
 11bbef3:	48 89 8d 78 fe ff ff 	mov    %rcx,-0x188(%rbp)
 11bbefa:	41 8b 8b d4 01 00 00 	mov    0x1d4(%r11),%ecx
 11bbf01:	45 0f b6 93 d0 01 00 	movzbl 0x1d0(%r11),%r10d
 11bbf08:	00 
 11bbf09:	44 88 55 ce          	mov    %r10b,-0x32(%rbp)
 11bbf0d:	89 8d cb fe ff ff    	mov    %ecx,-0x135(%rbp)
 11bbf13:	41 8b 8b d1 01 00 00 	mov    0x1d1(%r11),%ecx
 11bbf1a:	89 8d c8 fe ff ff    	mov    %ecx,-0x138(%rbp)
 11bbf20:	49 8b 9b d8 01 00 00 	mov    0x1d8(%r11),%rbx
 11bbf27:	41 8b 8b e4 01 00 00 	mov    0x1e4(%r11),%ecx
 11bbf2e:	45 0f b6 93 e0 01 00 	movzbl 0x1e0(%r11),%r10d
 11bbf35:	00 
 11bbf36:	44 88 55 c4          	mov    %r10b,-0x3c(%rbp)
 11bbf3a:	89 8d d3 fe ff ff    	mov    %ecx,-0x12d(%rbp)
 11bbf40:	41 8b 8b e1 01 00 00 	mov    0x1e1(%r11),%ecx
 11bbf47:	89 8d d0 fe ff ff    	mov    %ecx,-0x130(%rbp)
 11bbf4d:	49 8b 8b e8 01 00 00 	mov    0x1e8(%r11),%rcx
 11bbf54:	48 89 8d 00 fd ff ff 	mov    %rcx,-0x300(%rbp)
 11bbf5b:	41 0f b7 8b f6 01 00 	movzwl 0x1f6(%r11),%ecx
 11bbf62:	00 
 11bbf63:	45 0f b6 93 f0 01 00 	movzbl 0x1f0(%r11),%r10d
 11bbf6a:	00 
 11bbf6b:	44 88 55 d3          	mov    %r10b,-0x2d(%rbp)
 11bbf6f:	45 0f b6 93 f1 01 00 	movzbl 0x1f1(%r11),%r10d
 11bbf76:	00 
 11bbf77:	44 88 55 c9          	mov    %r10b,-0x37(%rbp)
 11bbf7b:	66 89 8d f8 fe ff ff 	mov    %cx,-0x108(%rbp)
 11bbf82:	41 8b 8b f2 01 00 00 	mov    0x1f2(%r11),%ecx
 11bbf89:	89 8d f4 fe ff ff    	mov    %ecx,-0x10c(%rbp)
 11bbf8f:	49 8b 8b 10 02 00 00 	mov    0x210(%r11),%rcx
 11bbf96:	48 89 8d f8 fb ff ff 	mov    %rcx,-0x408(%rbp)
 11bbf9d:	45 0f b6 93 18 02 00 	movzbl 0x218(%r11),%r10d
 11bbfa4:	00 
 11bbfa5:	45 0f b7 ab 1a 02 00 	movzwl 0x21a(%r11),%r13d
 11bbfac:	00 
 11bbfad:	41 0f b6 8b f8 01 00 	movzbl 0x1f8(%r11),%ecx
 11bbfb4:	00 
 11bbfb5:	88 4d cb             	mov    %cl,-0x35(%rbp)
 11bbfb8:	41 0f b6 8b 19 02 00 	movzbl 0x219(%r11),%ecx
 11bbfbf:	00 
 11bbfc0:	88 4d 88             	mov    %cl,-0x78(%rbp)
 11bbfc3:	41 0f b6 8b 1c 02 00 	movzbl 0x21c(%r11),%ecx
 11bbfca:	00 
 11bbfcb:	88 8d 58 ff ff ff    	mov    %cl,-0xa8(%rbp)
 11bbfd1:	41 0f b6 8b 1d 02 00 	movzbl 0x21d(%r11),%ecx
 11bbfd8:	00 
 11bbfd9:	88 4d 9b             	mov    %cl,-0x65(%rbp)
 11bbfdc:	41 0f b6 8b 1e 02 00 	movzbl 0x21e(%r11),%ecx
 11bbfe3:	00 
 11bbfe4:	88 8d e0 fd ff ff    	mov    %cl,-0x220(%rbp)
 11bbfea:	88 8d 56 ff ff ff    	mov    %cl,-0xaa(%rbp)
 11bbff0:	41 0f b6 8b 1f 02 00 	movzbl 0x21f(%r11),%ecx
 11bbff7:	00 
 11bbff8:	89 8d fc fe ff ff    	mov    %ecx,-0x104(%rbp)
 11bbffe:	41 0f b6 8b 20 02 00 	movzbl 0x220(%r11),%ecx
 11bc005:	00 
 11bc006:	88 85 52 ff ff ff    	mov    %al,-0xae(%rbp)
 11bc00c:	41 0f b7 83 22 02 00 	movzwl 0x222(%r11),%eax
 11bc013:	00 
 11bc014:	89 85 9c fd ff ff    	mov    %eax,-0x264(%rbp)
 11bc01a:	41 0f b6 83 24 02 00 	movzbl 0x224(%r11),%eax
 11bc021:	00 
 11bc022:	45 0f b6 a3 25 02 00 	movzbl 0x225(%r11),%r12d
 11bc029:	00 
 11bc02a:	44 88 a5 e0 fe ff ff 	mov    %r12b,-0x120(%rbp)
 11bc031:	44 88 65 9c          	mov    %r12b,-0x64(%rbp)
 11bc035:	4d 85 c9             	test   %r9,%r9
 11bc038:	0f 84 21 02 00 00    	je     11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc03e:	88 4d 9d             	mov    %cl,-0x63(%rbp)
 11bc041:	44 88 7d d5          	mov    %r15b,-0x2b(%rbp)
 11bc045:	48 89 9d 78 ff ff ff 	mov    %rbx,-0x88(%rbp)
 11bc04c:	45 89 ec             	mov    %r13d,%r12d
 11bc04f:	41 c1 ec 08          	shr    $0x8,%r12d
 11bc053:	44 89 e3             	mov    %r12d,%ebx
 11bc056:	80 e3 0f             	and    $0xf,%bl
 11bc059:	44 89 ad 5c ff ff ff 	mov    %r13d,-0xa4(%rbp)
 11bc060:	44 89 e9             	mov    %r13d,%ecx
 11bc063:	80 e1 03             	and    $0x3,%cl
 11bc066:	d2 e3                	shl    %cl,%bl
 11bc068:	0f b6 db             	movzbl %bl,%ebx
 11bc06b:	41 bf 30 00 00 00    	mov    $0x30,%r15d
 11bc071:	c4 c2 f1 f7 cf       	shlx   %rcx,%r15,%rcx
 11bc076:	48 01 d9             	add    %rbx,%rcx
 11bc079:	48 83 c1 10          	add    $0x10,%rcx
 11bc07d:	48 83 f9 4f          	cmp    $0x4f,%rcx
 11bc081:	0f 87 d8 01 00 00    	ja     11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc087:	44 89 a5 40 fe ff ff 	mov    %r12d,-0x1c0(%rbp)
 11bc08e:	48 89 8d a8 fd ff ff 	mov    %rcx,-0x258(%rbp)
 11bc095:	48 8d 8d 09 f1 ff ff 	lea    -0xef7(%rbp),%rcx
 11bc09c:	48 89 8d a0 fd ff ff 	mov    %rcx,-0x260(%rbp)
 11bc0a3:	48 8d 8d 0a f1 ff ff 	lea    -0xef6(%rbp),%rcx
 11bc0aa:	48 8d 9d 08 f1 ff ff 	lea    -0xef8(%rbp),%rbx
 11bc0b1:	48 89 9d 58 fd ff ff 	mov    %rbx,-0x2a8(%rbp)
 11bc0b8:	4c 8d a5 50 f1 ff ff 	lea    -0xeb0(%rbp),%r12
 11bc0bf:	49 83 c3 40          	add    $0x40,%r11
 11bc0c3:	4d 8d 78 50          	lea    0x50(%r8),%r15
 11bc0c7:	41 bd 01 00 00 00    	mov    $0x1,%r13d
 11bc0cd:	0f 1f 00             	nopl   (%rax)
 11bc0d0:	41 0f b6 1f          	movzbl (%r15),%ebx
 11bc0d4:	84 db                	test   %bl,%bl
 11bc0d6:	75 0d                	jne    11bc0e5 <br.encodeCommandPlanWithOptionsWrite+0x6a5>
 11bc0d8:	49 83 c7 60          	add    $0x60,%r15
 11bc0dc:	4d 39 e9             	cmp    %r13,%r9
 11bc0df:	4d 8d 6d 01          	lea    0x1(%r13),%r13
 11bc0e3:	75 eb                	jne    11bc0d0 <br.encodeCommandPlanWithOptionsWrite+0x690>
 11bc0e5:	80 7d 80 00          	cmpb   $0x0,-0x80(%rbp)
 11bc0e9:	74 55                	je     11bc140 <br.encodeCommandPlanWithOptionsWrite+0x700>
 11bc0eb:	c4 c1 7c 10 03       	vmovups (%r11),%ymm0
 11bc0f0:	c4 c1 7c 10 4b 20    	vmovups 0x20(%r11),%ymm1
 11bc0f6:	c4 c1 7c 10 53 30    	vmovups 0x30(%r11),%ymm2
 11bc0fc:	c5 fc 11 95 30 f1 ff 	vmovups %ymm2,-0xed0(%rbp)
 11bc103:	ff 
 11bc104:	c5 fc 11 8d 20 f1 ff 	vmovups %ymm1,-0xee0(%rbp)
 11bc10b:	ff 
 11bc10c:	c5 fc 11 85 00 f1 ff 	vmovups %ymm0,-0xf00(%rbp)
 11bc113:	ff 
 11bc114:	c6 85 50 f1 ff ff 01 	movb   $0x1,-0xeb0(%rbp)
 11bc11b:	4c 8d ad 00 f1 ff ff 	lea    -0xf00(%rbp),%r13
 11bc122:	e9 29 01 00 00       	jmp    11bc250 <br.encodeCommandPlanWithOptionsWrite+0x810>
 11bc127:	4c 89 f1             	mov    %r14,%rcx
 11bc12a:	48 81 c4 18 f7 06 00 	add    $0x6f718,%rsp
 11bc131:	5b                   	pop    %rbx
 11bc132:	41 5c                	pop    %r12
 11bc134:	41 5d                	pop    %r13
 11bc136:	41 5e                	pop    %r14
 11bc138:	41 5f                	pop    %r15
 11bc13a:	5d                   	pop    %rbp
 11bc13b:	e9 d0 4d 12 00       	jmp    12e0f10 <br.encodeCommandPlanWithAdaptiveSplitWrite>
 11bc140:	a8 01                	test   $0x1,%al
 11bc142:	0f 84 57 02 00 00    	je     11bc39f <br.encodeCommandPlanWithOptionsWrite+0x95f>
 11bc148:	41 83 e2 3f          	and    $0x3f,%r10d
 11bc14c:	31 c0                	xor    %eax,%eax
 11bc14e:	4c 39 d0             	cmp    %r10,%rax
 11bc151:	0f 93 84 05 20 fc ff 	setae  -0x3e0(%rbp,%rax,1)
 11bc158:	ff 
 11bc159:	48 8d 48 01          	lea    0x1(%rax),%rcx
 11bc15d:	4c 39 d1             	cmp    %r10,%rcx
 11bc160:	0f 93 84 05 21 fc ff 	setae  -0x3df(%rbp,%rax,1)
 11bc167:	ff 
 11bc168:	48 8d 48 02          	lea    0x2(%rax),%rcx
 11bc16c:	4c 39 d1             	cmp    %r10,%rcx
 11bc16f:	0f 93 84 05 22 fc ff 	setae  -0x3de(%rbp,%rax,1)
 11bc176:	ff 
 11bc177:	48 8d 48 03          	lea    0x3(%rax),%rcx
 11bc17b:	4c 39 d1             	cmp    %r10,%rcx
 11bc17e:	0f 93 84 05 23 fc ff 	setae  -0x3dd(%rbp,%rax,1)
 11bc185:	ff 
 11bc186:	48 8d 48 04          	lea    0x4(%rax),%rcx
 11bc18a:	4c 39 d1             	cmp    %r10,%rcx
 11bc18d:	0f 93 84 05 24 fc ff 	setae  -0x3dc(%rbp,%rax,1)
 11bc194:	ff 
 11bc195:	48 8d 48 05          	lea    0x5(%rax),%rcx
 11bc199:	4c 39 d1             	cmp    %r10,%rcx
 11bc19c:	0f 93 84 05 25 fc ff 	setae  -0x3db(%rbp,%rax,1)
 11bc1a3:	ff 
 11bc1a4:	48 8d 48 06          	lea    0x6(%rax),%rcx
 11bc1a8:	4c 39 d1             	cmp    %r10,%rcx
 11bc1ab:	0f 93 84 05 26 fc ff 	setae  -0x3da(%rbp,%rax,1)
 11bc1b2:	ff 
 11bc1b3:	48 8d 48 07          	lea    0x7(%rax),%rcx
 11bc1b7:	4c 39 d1             	cmp    %r10,%rcx
 11bc1ba:	0f 93 84 05 27 fc ff 	setae  -0x3d9(%rbp,%rax,1)
 11bc1c1:	ff 
 11bc1c2:	48 83 c0 08          	add    $0x8,%rax
 11bc1c6:	48 83 f8 40          	cmp    $0x40,%rax
 11bc1ca:	75 82                	jne    11bc14e <br.encodeCommandPlanWithOptionsWrite+0x70e>
 11bc1cc:	c6 85 68 ff ff ff 02 	movb   $0x2,-0x98(%rbp)
 11bc1d3:	c6 85 51 ff ff ff 02 	movb   $0x2,-0xaf(%rbp)
 11bc1da:	c5 fc 10 85 20 fc ff 	vmovups -0x3e0(%rbp),%ymm0
 11bc1e1:	ff 
 11bc1e2:	c5 fc 10 8d 40 fc ff 	vmovups -0x3c0(%rbp),%ymm1
 11bc1e9:	ff 
 11bc1ea:	48 8d 8d b2 f0 ff ff 	lea    -0xf4e(%rbp),%rcx
 11bc1f1:	c5 fc 11 49 20       	vmovups %ymm1,0x20(%rcx)
 11bc1f6:	c5 fc 11 01          	vmovups %ymm0,(%rcx)
 11bc1fa:	48 c7 85 a8 f0 ff ff 	movq   $0x0,-0xf58(%rbp)
 11bc201:	00 00 00 00 
 11bc205:	0f b6 85 68 ff ff ff 	movzbl -0x98(%rbp),%eax
 11bc20c:	88 85 b0 f0 ff ff    	mov    %al,-0xf50(%rbp)
 11bc212:	0f b6 85 51 ff ff ff 	movzbl -0xaf(%rbp),%eax
 11bc219:	88 85 b1 f0 ff ff    	mov    %al,-0xf4f(%rbp)
 11bc21f:	c6 85 f8 f0 ff ff 01 	movb   $0x1,-0xf08(%rbp)
 11bc226:	4c 8d ad a8 f0 ff ff 	lea    -0xf58(%rbp),%r13
 11bc22d:	4c 8d a5 f8 f0 ff ff 	lea    -0xf08(%rbp),%r12
 11bc234:	48 8d 85 b1 f0 ff ff 	lea    -0xf4f(%rbp),%rax
 11bc23b:	48 89 85 a0 fd ff ff 	mov    %rax,-0x260(%rbp)
 11bc242:	48 8d 85 b0 f0 ff ff 	lea    -0xf50(%rbp),%rax
 11bc249:	48 89 85 58 fd ff ff 	mov    %rax,-0x2a8(%rbp)
 11bc250:	45 0f b6 7d 09       	movzbl 0x9(%r13),%r15d
 11bc255:	41 8d 47 3f          	lea    0x3f(%r15),%eax
 11bc259:	24 7f                	and    $0x7f,%al
 11bc25b:	3c 41                	cmp    $0x41,%al
 11bc25d:	73 09                	jae    11bc268 <br.encodeCommandPlanWithOptionsWrite+0x828>
 11bc25f:	66 b8 52 00          	mov    $0x52,%ax
 11bc263:	e9 45 f8 ff ff       	jmp    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bc268:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11bc26c:	c5 fc 11 85 e0 f7 ff 	vmovups %ymm0,-0x820(%rbp)
 11bc273:	ff 
 11bc274:	c5 fc 11 85 c0 f7 ff 	vmovups %ymm0,-0x840(%rbp)
 11bc27b:	ff 
 11bc27c:	c5 fc 10 01          	vmovups (%rcx),%ymm0
 11bc280:	c5 fc 10 49 20       	vmovups 0x20(%rcx),%ymm1
 11bc285:	c5 fc 11 85 70 f7 ff 	vmovups %ymm0,-0x890(%rbp)
 11bc28c:	ff 
 11bc28d:	c5 fc 11 8d 90 f7 ff 	vmovups %ymm1,-0x870(%rbp)
 11bc294:	ff 
 11bc295:	44 89 f9             	mov    %r15d,%ecx
 11bc298:	83 e1 7f             	and    $0x7f,%ecx
 11bc29b:	31 c0                	xor    %eax,%eax
 11bc29d:	44 0f b6 94 05 70 f7 	movzbl -0x890(%rbp,%rax,1),%r10d
 11bc2a4:	ff ff 
 11bc2a6:	41 38 ca             	cmp    %cl,%r10b
 11bc2a9:	73 b4                	jae    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc2ab:	42 c6 84 15 c0 f7 ff 	movb   $0x1,-0x840(%rbp,%r10,1)
 11bc2b2:	ff 01 
 11bc2b4:	44 0f b6 94 05 71 f7 	movzbl -0x88f(%rbp,%rax,1),%r10d
 11bc2bb:	ff ff 
 11bc2bd:	41 38 ca             	cmp    %cl,%r10b
 11bc2c0:	73 9d                	jae    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc2c2:	42 c6 84 15 c0 f7 ff 	movb   $0x1,-0x840(%rbp,%r10,1)
 11bc2c9:	ff 01 
 11bc2cb:	44 0f b6 94 05 72 f7 	movzbl -0x88e(%rbp,%rax,1),%r10d
 11bc2d2:	ff ff 
 11bc2d4:	41 38 ca             	cmp    %cl,%r10b
 11bc2d7:	73 86                	jae    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc2d9:	42 c6 84 15 c0 f7 ff 	movb   $0x1,-0x840(%rbp,%r10,1)
 11bc2e0:	ff 01 
 11bc2e2:	44 0f b6 94 05 73 f7 	movzbl -0x88d(%rbp,%rax,1),%r10d
 11bc2e9:	ff ff 
 11bc2eb:	41 38 ca             	cmp    %cl,%r10b
 11bc2ee:	0f 83 6b ff ff ff    	jae    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc2f4:	42 c6 84 15 c0 f7 ff 	movb   $0x1,-0x840(%rbp,%r10,1)
 11bc2fb:	ff 01 
 11bc2fd:	44 0f b6 94 05 74 f7 	movzbl -0x88c(%rbp,%rax,1),%r10d
 11bc304:	ff ff 
 11bc306:	41 38 ca             	cmp    %cl,%r10b
 11bc309:	0f 83 50 ff ff ff    	jae    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc30f:	42 c6 84 15 c0 f7 ff 	movb   $0x1,-0x840(%rbp,%r10,1)
 11bc316:	ff 01 
 11bc318:	44 0f b6 94 05 75 f7 	movzbl -0x88b(%rbp,%rax,1),%r10d
 11bc31f:	ff ff 
 11bc321:	41 38 ca             	cmp    %cl,%r10b
 11bc324:	0f 83 35 ff ff ff    	jae    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc32a:	42 c6 84 15 c0 f7 ff 	movb   $0x1,-0x840(%rbp,%r10,1)
 11bc331:	ff 01 
 11bc333:	44 0f b6 94 05 76 f7 	movzbl -0x88a(%rbp,%rax,1),%r10d
 11bc33a:	ff ff 
 11bc33c:	41 38 ca             	cmp    %cl,%r10b
 11bc33f:	0f 83 1a ff ff ff    	jae    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc345:	42 c6 84 15 c0 f7 ff 	movb   $0x1,-0x840(%rbp,%r10,1)
 11bc34c:	ff 01 
 11bc34e:	44 0f b6 94 05 77 f7 	movzbl -0x889(%rbp,%rax,1),%r10d
 11bc355:	ff ff 
 11bc357:	41 38 ca             	cmp    %cl,%r10b
 11bc35a:	0f 83 ff fe ff ff    	jae    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc360:	42 c6 84 15 c0 f7 ff 	movb   $0x1,-0x840(%rbp,%r10,1)
 11bc367:	ff 01 
 11bc369:	48 83 c0 08          	add    $0x8,%rax
 11bc36d:	48 83 f8 40          	cmp    $0x40,%rax
 11bc371:	0f 85 26 ff ff ff    	jne    11bc29d <br.encodeCommandPlanWithOptionsWrite+0x85d>
 11bc377:	31 c0                	xor    %eax,%eax
 11bc379:	44 8b 95 5c ff ff ff 	mov    -0xa4(%rbp),%r10d
 11bc380:	80 bc 05 c0 f7 ff ff 	cmpb   $0x0,-0x840(%rbp,%rax,1)
 11bc387:	00 
 11bc388:	0f 84 d1 fe ff ff    	je     11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc38e:	48 ff c0             	inc    %rax
 11bc391:	48 39 c1             	cmp    %rax,%rcx
 11bc394:	75 ea                	jne    11bc380 <br.encodeCommandPlanWithOptionsWrite+0x940>
 11bc396:	41 80 e7 7f          	and    $0x7f,%r15b
 11bc39a:	45 31 db             	xor    %r11d,%r11d
 11bc39d:	eb 31                	jmp    11bc3d0 <br.encodeCommandPlanWithOptionsWrite+0x990>
 11bc39f:	41 b3 01             	mov    $0x1,%r11b
 11bc3a2:	41 bc 80 ad 03 01    	mov    $0x103ad80,%r12d
 11bc3a8:	b8 39 ad 03 01       	mov    $0x103ad39,%eax
 11bc3ad:	48 89 85 a0 fd ff ff 	mov    %rax,-0x260(%rbp)
 11bc3b4:	b8 38 ad 03 01       	mov    $0x103ad38,%eax
 11bc3b9:	48 89 85 58 fd ff ff 	mov    %rax,-0x2a8(%rbp)
 11bc3c0:	41 bd 30 ad 03 01    	mov    $0x103ad30,%r13d
 11bc3c6:	45 31 ff             	xor    %r15d,%r15d
 11bc3c9:	44 8b 95 5c ff ff ff 	mov    -0xa4(%rbp),%r10d
 11bc3d0:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 11bc3d4:	4c 89 8d 40 ff ff ff 	mov    %r9,-0xc0(%rbp)
 11bc3db:	48 89 95 78 fd ff ff 	mov    %rdx,-0x288(%rbp)
 11bc3e2:	0f 84 85 00 00 00    	je     11bc46d <br.encodeCommandPlanWithOptionsWrite+0xa2d>
 11bc3e8:	48 83 7d 90 00       	cmpq   $0x0,-0x70(%rbp)
 11bc3ed:	0f 94 c0             	sete   %al
 11bc3f0:	41 84 c3             	test   %al,%r11b
 11bc3f3:	0f 84 66 fe ff ff    	je     11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc3f9:	48 83 bd 18 ff ff ff 	cmpq   $0x0,-0xe8(%rbp)
 11bc400:	00 
 11bc401:	0f 84 58 fe ff ff    	je     11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc407:	44 0f b6 4d c0       	movzbl -0x40(%rbp),%r9d
 11bc40c:	45 84 c9             	test   %r9b,%r9b
 11bc40f:	0f 95 c0             	setne  %al
 11bc412:	48 8b 95 38 ff ff ff 	mov    -0xc8(%rbp),%rdx
 11bc419:	48 83 fa 02          	cmp    $0x2,%rdx
 11bc41d:	0f 92 c1             	setb   %cl
 11bc420:	84 c8                	test   %cl,%al
 11bc422:	0f 85 37 fe ff ff    	jne    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc428:	48 89 d0             	mov    %rdx,%rax
 11bc42b:	45 84 c9             	test   %r9b,%r9b
 11bc42e:	0f b6 4d c7          	movzbl -0x39(%rbp),%ecx
 11bc432:	4c 89 bd 00 fe ff ff 	mov    %r15,-0x200(%rbp)
 11bc439:	44 89 5d 80          	mov    %r11d,-0x80(%rbp)
 11bc43d:	75 1a                	jne    11bc459 <br.encodeCommandPlanWithOptionsWrite+0xa19>
 11bc43f:	0f b6 45 cc          	movzbl -0x34(%rbp),%eax
 11bc443:	0a 45 c2             	or     -0x3e(%rbp),%al
 11bc446:	a8 01                	test   $0x1,%al
 11bc448:	0f 84 31 01 00 00    	je     11bc57f <br.encodeCommandPlanWithOptionsWrite+0xb3f>
 11bc44e:	0f b6 45 cc          	movzbl -0x34(%rbp),%eax
 11bc452:	83 e0 01             	and    $0x1,%eax
 11bc455:	48 83 f0 03          	xor    $0x3,%rax
 11bc459:	84 c9                	test   %cl,%cl
 11bc45b:	0f 84 cc 00 00 00    	je     11bc52d <br.encodeCommandPlanWithOptionsWrite+0xaed>
 11bc461:	b9 06 00 00 00       	mov    $0x6,%ecx
 11bc466:	31 d2                	xor    %edx,%edx
 11bc468:	e9 ef 00 00 00       	jmp    11bc55c <br.encodeCommandPlanWithOptionsWrite+0xb1c>
 11bc46d:	44 89 5d 80          	mov    %r11d,-0x80(%rbp)
 11bc471:	48 83 7d 90 00       	cmpq   $0x0,-0x70(%rbp)
 11bc476:	0f 85 e3 fd ff ff    	jne    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc47c:	4c 89 85 f8 fd ff ff 	mov    %r8,-0x208(%rbp)
 11bc483:	48 89 7d a0          	mov    %rdi,-0x60(%rbp)
 11bc487:	48 89 75 b8          	mov    %rsi,-0x48(%rbp)
 11bc48b:	41 0f b6 fa          	movzbl %r10b,%edi
 11bc48f:	0f b6 b5 40 fe ff ff 	movzbl -0x1c0(%rbp),%esi
 11bc496:	89 bd 30 fe ff ff    	mov    %edi,-0x1d0(%rbp)
 11bc49c:	89 b5 34 fe ff ff    	mov    %esi,-0x1cc(%rbp)
 11bc4a2:	31 d2                	xor    %edx,%edx
 11bc4a4:	c5 f8 77             	vzeroupper 
 11bc4a7:	e8 34 5a 04 00       	call   1201ee0 <br.encoder.distance.Parameters.activeAlphabetSize>
 11bc4ac:	48 83 f8 4f          	cmp    $0x4f,%rax
 11bc4b0:	0f 87 a9 fd ff ff    	ja     11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc4b6:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 11bc4ba:	0f 84 fc 04 00 00    	je     11bc9bc <br.encodeCommandPlanWithOptionsWrite+0xf7c>
 11bc4c0:	48 83 bd 38 fe ff ff 	cmpq   $0x0,-0x1c8(%rbp)
 11bc4c7:	00 
 11bc4c8:	0f 84 91 fd ff ff    	je     11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc4ce:	48 89 85 18 fd ff ff 	mov    %rax,-0x2e8(%rbp)
 11bc4d5:	0f b6 75 c1          	movzbl -0x3f(%rbp),%esi
 11bc4d9:	40 84 f6             	test   %sil,%sil
 11bc4dc:	0f 95 c0             	setne  %al
 11bc4df:	48 8b 95 70 ff ff ff 	mov    -0x90(%rbp),%rdx
 11bc4e6:	48 83 fa 02          	cmp    $0x2,%rdx
 11bc4ea:	0f 92 c1             	setb   %cl
 11bc4ed:	84 c8                	test   %cl,%al
 11bc4ef:	0f 85 6a fd ff ff    	jne    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc4f5:	48 89 d0             	mov    %rdx,%rax
 11bc4f8:	40 84 f6             	test   %sil,%sil
 11bc4fb:	75 1a                	jne    11bc517 <br.encodeCommandPlanWithOptionsWrite+0xad7>
 11bc4fd:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 11bc501:	0a 45 c8             	or     -0x38(%rbp),%al
 11bc504:	a8 01                	test   $0x1,%al
 11bc506:	0f 84 2b 02 00 00    	je     11bc737 <br.encodeCommandPlanWithOptionsWrite+0xcf7>
 11bc50c:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 11bc510:	83 e0 01             	and    $0x1,%eax
 11bc513:	48 83 f0 03          	xor    $0x3,%rax
 11bc517:	80 7d cd 00          	cmpb   $0x0,-0x33(%rbp)
 11bc51b:	0f 84 43 02 00 00    	je     11bc764 <br.encodeCommandPlanWithOptionsWrite+0xd24>
 11bc521:	ba 06 00 00 00       	mov    $0x6,%edx
 11bc526:	31 c9                	xor    %ecx,%ecx
 11bc528:	e9 5c 02 00 00       	jmp    11bc789 <br.encodeCommandPlanWithOptionsWrite+0xd49>
 11bc52d:	4d 89 e7             	mov    %r12,%r15
 11bc530:	44 0f b6 4d d1       	movzbl -0x2f(%rbp),%r9d
 11bc535:	b9 05 00 00 00       	mov    $0x5,%ecx
 11bc53a:	b2 01                	mov    $0x1,%dl
 11bc53c:	45 84 c9             	test   %r9b,%r9b
 11bc53f:	75 18                	jne    11bc559 <br.encodeCommandPlanWithOptionsWrite+0xb19>
 11bc541:	b9 04 00 00 00       	mov    $0x4,%ecx
 11bc546:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 11bc54a:	75 0d                	jne    11bc559 <br.encodeCommandPlanWithOptionsWrite+0xb19>
 11bc54c:	80 7d c5 01          	cmpb   $0x1,-0x3b(%rbp)
 11bc550:	b9 03 00 00 00       	mov    $0x3,%ecx
 11bc555:	48 83 d9 00          	sbb    $0x0,%rcx
 11bc559:	4d 89 fc             	mov    %r15,%r12
 11bc55c:	48 39 c8             	cmp    %rcx,%rax
 11bc55f:	0f 87 fa fc ff ff    	ja     11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc565:	4d 89 e7             	mov    %r12,%r15
 11bc568:	80 7d c0 00          	cmpb   $0x0,-0x40(%rbp)
 11bc56c:	74 1e                	je     11bc58c <br.encodeCommandPlanWithOptionsWrite+0xb4c>
 11bc56e:	0f b6 45 cc          	movzbl -0x34(%rbp),%eax
 11bc572:	0a 45 c2             	or     -0x3e(%rbp),%al
 11bc575:	a8 01                	test   $0x1,%al
 11bc577:	0f 85 e2 fc ff ff    	jne    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc57d:	eb 4f                	jmp    11bc5ce <br.encodeCommandPlanWithOptionsWrite+0xb8e>
 11bc57f:	4d 89 e7             	mov    %r12,%r15
 11bc582:	84 c9                	test   %cl,%cl
 11bc584:	0f 84 ea 00 00 00    	je     11bc674 <br.encodeCommandPlanWithOptionsWrite+0xc34>
 11bc58a:	31 d2                	xor    %edx,%edx
 11bc58c:	f6 45 cc 01          	testb  $0x1,-0x34(%rbp)
 11bc590:	74 19                	je     11bc5ab <br.encodeCommandPlanWithOptionsWrite+0xb6b>
 11bc592:	0f b6 45 c2          	movzbl -0x3e(%rbp),%eax
 11bc596:	f6 d0                	not    %al
 11bc598:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 11bc59c:	0f 94 c1             	sete   %cl
 11bc59f:	20 d0                	and    %dl,%al
 11bc5a1:	20 c8                	and    %cl,%al
 11bc5a3:	3c 01                	cmp    $0x1,%al
 11bc5a5:	0f 85 b4 fc ff ff    	jne    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc5ab:	f6 45 c2 01          	testb  $0x1,-0x3e(%rbp)
 11bc5af:	74 1d                	je     11bc5ce <br.encodeCommandPlanWithOptionsWrite+0xb8e>
 11bc5b1:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 11bc5b5:	0f 95 c0             	setne  %al
 11bc5b8:	89 d1                	mov    %edx,%ecx
 11bc5ba:	80 f1 01             	xor    $0x1,%cl
 11bc5bd:	08 c1                	or     %al,%cl
 11bc5bf:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 11bc5c3:	0f 94 c0             	sete   %al
 11bc5c6:	08 c8                	or     %cl,%al
 11bc5c8:	0f 85 91 fc ff ff    	jne    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc5ce:	80 7d c5 00          	cmpb   $0x0,-0x3b(%rbp)
 11bc5d2:	74 23                	je     11bc5f7 <br.encodeCommandPlanWithOptionsWrite+0xbb7>
 11bc5d4:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 11bc5d8:	0f 84 ca 00 00 00    	je     11bc6a8 <br.encodeCommandPlanWithOptionsWrite+0xc68>
 11bc5de:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 11bc5e2:	0f 94 c0             	sete   %al
 11bc5e5:	89 d1                	mov    %edx,%ecx
 11bc5e7:	80 f1 01             	xor    $0x1,%cl
 11bc5ea:	84 c8                	test   %cl,%al
 11bc5ec:	0f 85 6d fc ff ff    	jne    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc5f2:	e9 be 00 00 00       	jmp    11bc6b5 <br.encodeCommandPlanWithOptionsWrite+0xc75>
 11bc5f7:	0f b6 45 c7          	movzbl -0x39(%rbp),%eax
 11bc5fb:	0a 45 d1             	or     -0x2f(%rbp),%al
 11bc5fe:	0a 45 cf             	or     -0x31(%rbp),%al
 11bc601:	0f 85 58 fc ff ff    	jne    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc607:	80 f2 01             	xor    $0x1,%dl
 11bc60a:	0f b6 c2             	movzbl %dl,%eax
 11bc60d:	48 8d 0c 85 01 00 00 	lea    0x1(,%rax,4),%rcx
 11bc614:	00 
 11bc615:	31 d2                	xor    %edx,%edx
 11bc617:	48 8b 85 00 ff ff ff 	mov    -0x100(%rbp),%rax
 11bc61e:	48 89 85 50 fd ff ff 	mov    %rax,-0x2b0(%rbp)
 11bc625:	48 8b 85 20 ff ff ff 	mov    -0xe0(%rbp),%rax
 11bc62c:	48 89 85 c0 fc ff ff 	mov    %rax,-0x340(%rbp)
 11bc633:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 11bc63a:	48 89 85 c8 fc ff ff 	mov    %rax,-0x338(%rbp)
 11bc641:	48 8b 85 30 ff ff ff 	mov    -0xd0(%rbp),%rax
 11bc648:	48 89 85 d0 fc ff ff 	mov    %rax,-0x330(%rbp)
 11bc64f:	48 8d 85 50 fd ff ff 	lea    -0x2b0(%rbp),%rax
 11bc656:	45 31 c9             	xor    %r9d,%r9d
 11bc659:	45 31 d2             	xor    %r10d,%r10d
 11bc65c:	4c 8b 9d 18 ff ff ff 	mov    -0xe8(%rbp),%r11
 11bc663:	4d 89 fc             	mov    %r15,%r12
 11bc666:	4c 8b bd 00 fe ff ff 	mov    -0x200(%rbp),%r15
 11bc66d:	ff 24 d5 60 ff 00 01 	jmp    *0x100ff60(,%rdx,8)
 11bc674:	b8 05 00 00 00       	mov    $0x5,%eax
 11bc679:	44 0f b6 4d d1       	movzbl -0x2f(%rbp),%r9d
 11bc67e:	45 84 c9             	test   %r9b,%r9b
 11bc681:	0f 85 ae fe ff ff    	jne    11bc535 <br.encodeCommandPlanWithOptionsWrite+0xaf5>
 11bc687:	b8 04 00 00 00       	mov    $0x4,%eax
 11bc68c:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 11bc690:	0f 85 9f fe ff ff    	jne    11bc535 <br.encodeCommandPlanWithOptionsWrite+0xaf5>
 11bc696:	80 7d c5 01          	cmpb   $0x1,-0x3b(%rbp)
 11bc69a:	b8 03 00 00 00       	mov    $0x3,%eax
 11bc69f:	48 83 d8 00          	sbb    $0x0,%rax
 11bc6a3:	e9 8d fe ff ff       	jmp    11bc535 <br.encodeCommandPlanWithOptionsWrite+0xaf5>
 11bc6a8:	0f b6 45 c7          	movzbl -0x39(%rbp),%eax
 11bc6ac:	0a 45 d1             	or     -0x2f(%rbp),%al
 11bc6af:	0f 85 aa fb ff ff    	jne    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc6b5:	b9 05 00 00 00       	mov    $0x5,%ecx
 11bc6ba:	84 d2                	test   %dl,%dl
 11bc6bc:	74 1a                	je     11bc6d8 <br.encodeCommandPlanWithOptionsWrite+0xc98>
 11bc6be:	80 7d cf 01          	cmpb   $0x1,-0x31(%rbp)
 11bc6c2:	b8 03 00 00 00       	mov    $0x3,%eax
 11bc6c7:	48 83 d8 00          	sbb    $0x0,%rax
 11bc6cb:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 11bc6cf:	b9 04 00 00 00       	mov    $0x4,%ecx
 11bc6d4:	48 0f 44 c8          	cmove  %rax,%rcx
 11bc6d8:	31 d2                	xor    %edx,%edx
 11bc6da:	48 8b 85 00 ff ff ff 	mov    -0x100(%rbp),%rax
 11bc6e1:	48 89 85 50 fd ff ff 	mov    %rax,-0x2b0(%rbp)
 11bc6e8:	48 8b 85 20 ff ff ff 	mov    -0xe0(%rbp),%rax
 11bc6ef:	48 89 85 c0 fc ff ff 	mov    %rax,-0x340(%rbp)
 11bc6f6:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 11bc6fd:	48 89 85 c8 fc ff ff 	mov    %rax,-0x338(%rbp)
 11bc704:	48 8b 85 30 ff ff ff 	mov    -0xd0(%rbp),%rax
 11bc70b:	48 89 85 d0 fc ff ff 	mov    %rax,-0x330(%rbp)
 11bc712:	48 8d 85 50 fd ff ff 	lea    -0x2b0(%rbp),%rax
 11bc719:	45 31 c9             	xor    %r9d,%r9d
 11bc71c:	45 31 d2             	xor    %r10d,%r10d
 11bc71f:	4c 8b 9d 18 ff ff ff 	mov    -0xe8(%rbp),%r11
 11bc726:	4d 89 fc             	mov    %r15,%r12
 11bc729:	4c 8b bd 00 fe ff ff 	mov    -0x200(%rbp),%r15
 11bc730:	ff 24 d5 60 ff 00 01 	jmp    *0x100ff60(,%rdx,8)
 11bc737:	80 7d cd 00          	cmpb   $0x0,-0x33(%rbp)
 11bc73b:	74 04                	je     11bc741 <br.encodeCommandPlanWithOptionsWrite+0xd01>
 11bc73d:	31 c9                	xor    %ecx,%ecx
 11bc73f:	eb 68                	jmp    11bc7a9 <br.encodeCommandPlanWithOptionsWrite+0xd69>
 11bc741:	b8 05 00 00 00       	mov    $0x5,%eax
 11bc746:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 11bc74a:	75 18                	jne    11bc764 <br.encodeCommandPlanWithOptionsWrite+0xd24>
 11bc74c:	b8 04 00 00 00       	mov    $0x4,%eax
 11bc751:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 11bc755:	75 0d                	jne    11bc764 <br.encodeCommandPlanWithOptionsWrite+0xd24>
 11bc757:	80 7d ca 01          	cmpb   $0x1,-0x36(%rbp)
 11bc75b:	b8 03 00 00 00       	mov    $0x3,%eax
 11bc760:	48 83 d8 00          	sbb    $0x0,%rax
 11bc764:	ba 05 00 00 00       	mov    $0x5,%edx
 11bc769:	b1 01                	mov    $0x1,%cl
 11bc76b:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 11bc76f:	75 18                	jne    11bc789 <br.encodeCommandPlanWithOptionsWrite+0xd49>
 11bc771:	ba 04 00 00 00       	mov    $0x4,%edx
 11bc776:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 11bc77a:	75 0d                	jne    11bc789 <br.encodeCommandPlanWithOptionsWrite+0xd49>
 11bc77c:	80 7d ca 01          	cmpb   $0x1,-0x36(%rbp)
 11bc780:	ba 03 00 00 00       	mov    $0x3,%edx
 11bc785:	48 83 da 00          	sbb    $0x0,%rdx
 11bc789:	48 39 d0             	cmp    %rdx,%rax
 11bc78c:	0f 87 cd fa ff ff    	ja     11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc792:	80 7d c1 00          	cmpb   $0x0,-0x3f(%rbp)
 11bc796:	74 11                	je     11bc7a9 <br.encodeCommandPlanWithOptionsWrite+0xd69>
 11bc798:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 11bc79c:	0a 45 c8             	or     -0x38(%rbp),%al
 11bc79f:	a8 01                	test   $0x1,%al
 11bc7a1:	0f 85 b8 fa ff ff    	jne    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc7a7:	eb 42                	jmp    11bc7eb <br.encodeCommandPlanWithOptionsWrite+0xdab>
 11bc7a9:	f6 45 d2 01          	testb  $0x1,-0x2e(%rbp)
 11bc7ad:	74 19                	je     11bc7c8 <br.encodeCommandPlanWithOptionsWrite+0xd88>
 11bc7af:	0f b6 45 c8          	movzbl -0x38(%rbp),%eax
 11bc7b3:	f6 d0                	not    %al
 11bc7b5:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 11bc7b9:	0f 94 c2             	sete   %dl
 11bc7bc:	20 c8                	and    %cl,%al
 11bc7be:	20 d0                	and    %dl,%al
 11bc7c0:	3c 01                	cmp    $0x1,%al
 11bc7c2:	0f 85 97 fa ff ff    	jne    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc7c8:	f6 45 c8 01          	testb  $0x1,-0x38(%rbp)
 11bc7cc:	74 1d                	je     11bc7eb <br.encodeCommandPlanWithOptionsWrite+0xdab>
 11bc7ce:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 11bc7d2:	0f 95 c0             	setne  %al
 11bc7d5:	89 ca                	mov    %ecx,%edx
 11bc7d7:	80 f2 01             	xor    $0x1,%dl
 11bc7da:	08 c2                	or     %al,%dl
 11bc7dc:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 11bc7e0:	0f 94 c0             	sete   %al
 11bc7e3:	08 d0                	or     %dl,%al
 11bc7e5:	0f 85 74 fa ff ff    	jne    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc7eb:	80 7d ca 00          	cmpb   $0x0,-0x36(%rbp)
 11bc7ef:	74 23                	je     11bc814 <br.encodeCommandPlanWithOptionsWrite+0xdd4>
 11bc7f1:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 11bc7f5:	0f 84 99 00 00 00    	je     11bc894 <br.encodeCommandPlanWithOptionsWrite+0xe54>
 11bc7fb:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 11bc7ff:	0f 94 c0             	sete   %al
 11bc802:	89 ca                	mov    %ecx,%edx
 11bc804:	80 f2 01             	xor    $0x1,%dl
 11bc807:	84 d0                	test   %dl,%al
 11bc809:	0f 85 50 fa ff ff    	jne    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc80f:	e9 8d 00 00 00       	jmp    11bc8a1 <br.encodeCommandPlanWithOptionsWrite+0xe61>
 11bc814:	0f b6 45 cd          	movzbl -0x33(%rbp),%eax
 11bc818:	0a 45 d6             	or     -0x2a(%rbp),%al
 11bc81b:	0a 45 d0             	or     -0x30(%rbp),%al
 11bc81e:	0f 85 3b fa ff ff    	jne    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc824:	80 f1 01             	xor    $0x1,%cl
 11bc827:	0f b6 c1             	movzbl %cl,%eax
 11bc82a:	4c 8d 1c 85 01 00 00 	lea    0x1(,%rax,4),%r11
 11bc831:	00 
 11bc832:	31 c9                	xor    %ecx,%ecx
 11bc834:	48 8b 95 c0 fd ff ff 	mov    -0x240(%rbp),%rdx
 11bc83b:	48 89 95 48 fd ff ff 	mov    %rdx,-0x2b8(%rbp)
 11bc842:	48 8b 95 c8 fd ff ff 	mov    -0x238(%rbp),%rdx
 11bc849:	48 89 95 a8 fc ff ff 	mov    %rdx,-0x358(%rbp)
 11bc850:	48 8b 95 d0 fd ff ff 	mov    -0x230(%rbp),%rdx
 11bc857:	48 89 95 b0 fc ff ff 	mov    %rdx,-0x350(%rbp)
 11bc85e:	48 8b 95 d8 fd ff ff 	mov    -0x228(%rbp),%rdx
 11bc865:	48 89 95 b8 fc ff ff 	mov    %rdx,-0x348(%rbp)
 11bc86c:	48 8d bd 48 fd ff ff 	lea    -0x2b8(%rbp),%rdi
 11bc873:	31 d2                	xor    %edx,%edx
 11bc875:	45 31 c0             	xor    %r8d,%r8d
 11bc878:	4c 8b 8d 38 fe ff ff 	mov    -0x1c8(%rbp),%r9
 11bc87f:	48 8b b5 40 ff ff ff 	mov    -0xc0(%rbp),%rsi
 11bc886:	48 8b 85 18 fd ff ff 	mov    -0x2e8(%rbp),%rax
 11bc88d:	ff 24 cd 88 ff 00 01 	jmp    *0x100ff88(,%rcx,8)
 11bc894:	0f b6 45 cd          	movzbl -0x33(%rbp),%eax
 11bc898:	0a 45 d6             	or     -0x2a(%rbp),%al
 11bc89b:	0f 85 be f9 ff ff    	jne    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc8a1:	41 bb 05 00 00 00    	mov    $0x5,%r11d
 11bc8a7:	84 c9                	test   %cl,%cl
 11bc8a9:	74 1b                	je     11bc8c6 <br.encodeCommandPlanWithOptionsWrite+0xe86>
 11bc8ab:	80 7d d0 01          	cmpb   $0x1,-0x30(%rbp)
 11bc8af:	b9 03 00 00 00       	mov    $0x3,%ecx
 11bc8b4:	48 83 d9 00          	sbb    $0x0,%rcx
 11bc8b8:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 11bc8bc:	41 bb 04 00 00 00    	mov    $0x4,%r11d
 11bc8c2:	4c 0f 44 d9          	cmove  %rcx,%r11
 11bc8c6:	31 c9                	xor    %ecx,%ecx
 11bc8c8:	48 8b 95 c0 fd ff ff 	mov    -0x240(%rbp),%rdx
 11bc8cf:	48 89 95 48 fd ff ff 	mov    %rdx,-0x2b8(%rbp)
 11bc8d6:	48 8b 95 c8 fd ff ff 	mov    -0x238(%rbp),%rdx
 11bc8dd:	48 89 95 a8 fc ff ff 	mov    %rdx,-0x358(%rbp)
 11bc8e4:	48 8b 95 d0 fd ff ff 	mov    -0x230(%rbp),%rdx
 11bc8eb:	48 89 95 b0 fc ff ff 	mov    %rdx,-0x350(%rbp)
 11bc8f2:	48 8b 95 d8 fd ff ff 	mov    -0x228(%rbp),%rdx
 11bc8f9:	48 89 95 b8 fc ff ff 	mov    %rdx,-0x348(%rbp)
 11bc900:	48 8d bd 48 fd ff ff 	lea    -0x2b8(%rbp),%rdi
 11bc907:	31 d2                	xor    %edx,%edx
 11bc909:	45 31 c0             	xor    %r8d,%r8d
 11bc90c:	4c 8b 8d 38 fe ff ff 	mov    -0x1c8(%rbp),%r9
 11bc913:	48 8b b5 40 ff ff ff 	mov    -0xc0(%rbp),%rsi
 11bc91a:	48 8b 85 18 fd ff ff 	mov    -0x2e8(%rbp),%rax
 11bc921:	ff 24 cd 88 ff 00 01 	jmp    *0x100ff88(,%rcx,8)
 11bc928:	4d 39 d3             	cmp    %r10,%r11
 11bc92b:	0f 86 2e f9 ff ff    	jbe    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc931:	4c 89 da             	mov    %r11,%rdx
 11bc934:	49 ff c1             	inc    %r9
 11bc937:	4c 39 c9             	cmp    %r9,%rcx
 11bc93a:	44 8b 95 5c ff ff ff 	mov    -0xa4(%rbp),%r10d
 11bc941:	0f 84 35 fb ff ff    	je     11bc47c <br.encodeCommandPlanWithOptionsWrite+0xa3c>
 11bc947:	48 8b 85 00 ff ff ff 	mov    -0x100(%rbp),%rax
 11bc94e:	48 89 85 50 fd ff ff 	mov    %rax,-0x2b0(%rbp)
 11bc955:	48 8b 85 20 ff ff ff 	mov    -0xe0(%rbp),%rax
 11bc95c:	48 89 85 c0 fc ff ff 	mov    %rax,-0x340(%rbp)
 11bc963:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 11bc96a:	48 89 85 c8 fc ff ff 	mov    %rax,-0x338(%rbp)
 11bc971:	48 8b 85 30 ff ff ff 	mov    -0xd0(%rbp),%rax
 11bc978:	48 89 85 d0 fc ff ff 	mov    %rax,-0x330(%rbp)
 11bc97f:	48 8d 85 50 fd ff ff 	lea    -0x2b0(%rbp),%rax
 11bc986:	49 89 d2             	mov    %rdx,%r10
 11bc989:	4c 8b 9d 18 ff ff ff 	mov    -0xe8(%rbp),%r11
 11bc990:	42 ff 24 cd 60 ff 00 	jmp    *0x100ff60(,%r9,8)
 11bc997:	01 
 11bc998:	48 8d 85 c0 fc ff ff 	lea    -0x340(%rbp),%rax
 11bc99f:	eb 10                	jmp    11bc9b1 <br.encodeCommandPlanWithOptionsWrite+0xf71>
 11bc9a1:	48 8d 85 c8 fc ff ff 	lea    -0x338(%rbp),%rax
 11bc9a8:	eb 07                	jmp    11bc9b1 <br.encodeCommandPlanWithOptionsWrite+0xf71>
 11bc9aa:	48 8d 85 d0 fc ff ff 	lea    -0x330(%rbp),%rax
 11bc9b1:	4c 8b 18             	mov    (%rax),%r11
 11bc9b4:	49 89 d2             	mov    %rdx,%r10
 11bc9b7:	e9 6c ff ff ff       	jmp    11bc928 <br.encodeCommandPlanWithOptionsWrite+0xee8>
 11bc9bc:	48 89 85 18 fd ff ff 	mov    %rax,-0x2e8(%rbp)
 11bc9c3:	4c 89 bd 00 fe ff ff 	mov    %r15,-0x200(%rbp)
 11bc9ca:	4c 89 ad 08 fd ff ff 	mov    %r13,-0x2f8(%rbp)
 11bc9d1:	4c 89 a5 08 ff ff ff 	mov    %r12,-0xf8(%rbp)
 11bc9d8:	80 7d cb 00          	cmpb   $0x0,-0x35(%rbp)
 11bc9dc:	0f 84 28 02 00 00    	je     11bcc0a <br.encodeCommandPlanWithOptionsWrite+0x11ca>
 11bc9e2:	48 83 bd d8 fe ff ff 	cmpq   $0x0,-0x128(%rbp)
 11bc9e9:	00 
 11bc9ea:	0f 84 6f f8 ff ff    	je     11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bc9f0:	80 7d c4 00          	cmpb   $0x0,-0x3c(%rbp)
 11bc9f4:	0f 95 c0             	setne  %al
 11bc9f7:	48 83 bd 78 ff ff ff 	cmpq   $0x2,-0x88(%rbp)
 11bc9fe:	02 
 11bc9ff:	0f 92 c1             	setb   %cl
 11bca02:	84 c8                	test   %cl,%al
 11bca04:	0f 85 55 f8 ff ff    	jne    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bca0a:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 11bca11:	80 7d c4 00          	cmpb   $0x0,-0x3c(%rbp)
 11bca15:	75 16                	jne    11bca2d <br.encodeCommandPlanWithOptionsWrite+0xfed>
 11bca17:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 11bca1b:	0a 45 c9             	or     -0x37(%rbp),%al
 11bca1e:	a8 01                	test   $0x1,%al
 11bca20:	74 1a                	je     11bca3c <br.encodeCommandPlanWithOptionsWrite+0xffc>
 11bca22:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 11bca26:	83 e0 01             	and    $0x1,%eax
 11bca29:	48 83 f0 03          	xor    $0x3,%rax
 11bca2d:	80 7d ce 00          	cmpb   $0x0,-0x32(%rbp)
 11bca31:	74 36                	je     11bca69 <br.encodeCommandPlanWithOptionsWrite+0x1029>
 11bca33:	ba 06 00 00 00       	mov    $0x6,%edx
 11bca38:	31 c9                	xor    %ecx,%ecx
 11bca3a:	eb 52                	jmp    11bca8e <br.encodeCommandPlanWithOptionsWrite+0x104e>
 11bca3c:	80 7d ce 00          	cmpb   $0x0,-0x32(%rbp)
 11bca40:	74 04                	je     11bca46 <br.encodeCommandPlanWithOptionsWrite+0x1006>
 11bca42:	31 c9                	xor    %ecx,%ecx
 11bca44:	eb 68                	jmp    11bcaae <br.encodeCommandPlanWithOptionsWrite+0x106e>
 11bca46:	b8 05 00 00 00       	mov    $0x5,%eax
 11bca4b:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 11bca4f:	75 18                	jne    11bca69 <br.encodeCommandPlanWithOptionsWrite+0x1029>
 11bca51:	b8 04 00 00 00       	mov    $0x4,%eax
 11bca56:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 11bca5a:	75 0d                	jne    11bca69 <br.encodeCommandPlanWithOptionsWrite+0x1029>
 11bca5c:	80 7d d5 01          	cmpb   $0x1,-0x2b(%rbp)
 11bca60:	b8 03 00 00 00       	mov    $0x3,%eax
 11bca65:	48 83 d8 00          	sbb    $0x0,%rax
 11bca69:	ba 05 00 00 00       	mov    $0x5,%edx
 11bca6e:	b1 01                	mov    $0x1,%cl
 11bca70:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 11bca74:	75 18                	jne    11bca8e <br.encodeCommandPlanWithOptionsWrite+0x104e>
 11bca76:	ba 04 00 00 00       	mov    $0x4,%edx
 11bca7b:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 11bca7f:	75 0d                	jne    11bca8e <br.encodeCommandPlanWithOptionsWrite+0x104e>
 11bca81:	80 7d d5 01          	cmpb   $0x1,-0x2b(%rbp)
 11bca85:	ba 03 00 00 00       	mov    $0x3,%edx
 11bca8a:	48 83 da 00          	sbb    $0x0,%rdx
 11bca8e:	48 39 d0             	cmp    %rdx,%rax
 11bca91:	0f 87 c8 f7 ff ff    	ja     11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bca97:	80 7d c4 00          	cmpb   $0x0,-0x3c(%rbp)
 11bca9b:	74 11                	je     11bcaae <br.encodeCommandPlanWithOptionsWrite+0x106e>
 11bca9d:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 11bcaa1:	0a 45 c9             	or     -0x37(%rbp),%al
 11bcaa4:	a8 01                	test   $0x1,%al
 11bcaa6:	0f 85 b3 f7 ff ff    	jne    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bcaac:	eb 42                	jmp    11bcaf0 <br.encodeCommandPlanWithOptionsWrite+0x10b0>
 11bcaae:	f6 45 d3 01          	testb  $0x1,-0x2d(%rbp)
 11bcab2:	74 19                	je     11bcacd <br.encodeCommandPlanWithOptionsWrite+0x108d>
 11bcab4:	0f b6 45 c9          	movzbl -0x37(%rbp),%eax
 11bcab8:	f6 d0                	not    %al
 11bcaba:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 11bcabe:	0f 94 c2             	sete   %dl
 11bcac1:	20 c8                	and    %cl,%al
 11bcac3:	20 d0                	and    %dl,%al
 11bcac5:	3c 01                	cmp    $0x1,%al
 11bcac7:	0f 85 92 f7 ff ff    	jne    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bcacd:	f6 45 c9 01          	testb  $0x1,-0x37(%rbp)
 11bcad1:	74 1d                	je     11bcaf0 <br.encodeCommandPlanWithOptionsWrite+0x10b0>
 11bcad3:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 11bcad7:	0f 95 c0             	setne  %al
 11bcada:	89 ca                	mov    %ecx,%edx
 11bcadc:	80 f2 01             	xor    $0x1,%dl
 11bcadf:	08 c2                	or     %al,%dl
 11bcae1:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 11bcae5:	0f 94 c0             	sete   %al
 11bcae8:	08 d0                	or     %dl,%al
 11bcaea:	0f 85 6f f7 ff ff    	jne    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bcaf0:	80 7d d5 00          	cmpb   $0x0,-0x2b(%rbp)
 11bcaf4:	74 20                	je     11bcb16 <br.encodeCommandPlanWithOptionsWrite+0x10d6>
 11bcaf6:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 11bcafa:	0f 84 87 00 00 00    	je     11bcb87 <br.encodeCommandPlanWithOptionsWrite+0x1147>
 11bcb00:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 11bcb04:	0f 94 c0             	sete   %al
 11bcb07:	89 ca                	mov    %ecx,%edx
 11bcb09:	80 f2 01             	xor    $0x1,%dl
 11bcb0c:	84 d0                	test   %dl,%al
 11bcb0e:	0f 85 4b f7 ff ff    	jne    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bcb14:	eb 7e                	jmp    11bcb94 <br.encodeCommandPlanWithOptionsWrite+0x1154>
 11bcb16:	0f b6 45 ce          	movzbl -0x32(%rbp),%eax
 11bcb1a:	0a 45 d7             	or     -0x29(%rbp),%al
 11bcb1d:	0a 45 d4             	or     -0x2c(%rbp),%al
 11bcb20:	0f 85 39 f7 ff ff    	jne    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bcb26:	80 f1 01             	xor    $0x1,%cl
 11bcb29:	0f b6 c1             	movzbl %cl,%eax
 11bcb2c:	48 8d 04 85 01 00 00 	lea    0x1(,%rax,4),%rax
 11bcb33:	00 
 11bcb34:	31 c9                	xor    %ecx,%ecx
 11bcb36:	48 8b 95 60 fe ff ff 	mov    -0x1a0(%rbp),%rdx
 11bcb3d:	48 89 95 40 fd ff ff 	mov    %rdx,-0x2c0(%rbp)
 11bcb44:	48 8b 95 68 fe ff ff 	mov    -0x198(%rbp),%rdx
 11bcb4b:	48 89 95 90 fc ff ff 	mov    %rdx,-0x370(%rbp)
 11bcb52:	48 8b 95 70 fe ff ff 	mov    -0x190(%rbp),%rdx
 11bcb59:	48 89 95 98 fc ff ff 	mov    %rdx,-0x368(%rbp)
 11bcb60:	48 8b 95 78 fe ff ff 	mov    -0x188(%rbp),%rdx
 11bcb67:	48 89 95 a0 fc ff ff 	mov    %rdx,-0x360(%rbp)
 11bcb6e:	48 8d b5 40 fd ff ff 	lea    -0x2c0(%rbp),%rsi
 11bcb75:	31 d2                	xor    %edx,%edx
 11bcb77:	31 ff                	xor    %edi,%edi
 11bcb79:	4c 8b 85 d8 fe ff ff 	mov    -0x128(%rbp),%r8
 11bcb80:	ff 24 cd b0 ff 00 01 	jmp    *0x100ffb0(,%rcx,8)
 11bcb87:	0f b6 45 ce          	movzbl -0x32(%rbp),%eax
 11bcb8b:	0a 45 d7             	or     -0x29(%rbp),%al
 11bcb8e:	0f 85 cb f6 ff ff    	jne    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bcb94:	b8 05 00 00 00       	mov    $0x5,%eax
 11bcb99:	84 c9                	test   %cl,%cl
 11bcb9b:	74 1a                	je     11bcbb7 <br.encodeCommandPlanWithOptionsWrite+0x1177>
 11bcb9d:	80 7d d4 01          	cmpb   $0x1,-0x2c(%rbp)
 11bcba1:	b9 03 00 00 00       	mov    $0x3,%ecx
 11bcba6:	48 83 d9 00          	sbb    $0x0,%rcx
 11bcbaa:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 11bcbae:	b8 04 00 00 00       	mov    $0x4,%eax
 11bcbb3:	48 0f 44 c1          	cmove  %rcx,%rax
 11bcbb7:	31 c9                	xor    %ecx,%ecx
 11bcbb9:	48 8b 95 60 fe ff ff 	mov    -0x1a0(%rbp),%rdx
 11bcbc0:	48 89 95 40 fd ff ff 	mov    %rdx,-0x2c0(%rbp)
 11bcbc7:	48 8b 95 68 fe ff ff 	mov    -0x198(%rbp),%rdx
 11bcbce:	48 89 95 90 fc ff ff 	mov    %rdx,-0x370(%rbp)
 11bcbd5:	48 8b 95 70 fe ff ff 	mov    -0x190(%rbp),%rdx
 11bcbdc:	48 89 95 98 fc ff ff 	mov    %rdx,-0x368(%rbp)
 11bcbe3:	48 8b 95 78 fe ff ff 	mov    -0x188(%rbp),%rdx
 11bcbea:	48 89 95 a0 fc ff ff 	mov    %rdx,-0x360(%rbp)
 11bcbf1:	48 8d b5 40 fd ff ff 	lea    -0x2c0(%rbp),%rsi
 11bcbf8:	31 d2                	xor    %edx,%edx
 11bcbfa:	31 ff                	xor    %edi,%edi
 11bcbfc:	4c 8b 85 d8 fe ff ff 	mov    -0x128(%rbp),%r8
 11bcc03:	ff 24 cd b0 ff 00 01 	jmp    *0x100ffb0(,%rcx,8)
 11bcc0a:	b8 e0 be 03 01       	mov    $0x103bee0,%eax
 11bcc0f:	be e0 c2 03 01       	mov    $0x103c2e0,%esi
 11bcc14:	f6 85 e0 fd ff ff 01 	testb  $0x1,-0x220(%rbp)
 11bcc1b:	48 0f 45 f0          	cmovne %rax,%rsi
 11bcc1f:	48 8d bd a0 c0 ff ff 	lea    -0x3f60(%rbp),%rdi
 11bcc26:	ba 00 04 00 00       	mov    $0x400,%edx
 11bcc2b:	e8 30 2b 12 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11bcc30:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11bcc34:	c5 fc 11 85 80 f3 ff 	vmovups %ymm0,-0xc80(%rbp)
 11bcc3b:	ff 
 11bcc3c:	48 c7 85 b8 d5 ff ff 	movq   $0x0,-0x2a48(%rbp)
 11bcc43:	00 00 00 00 
 11bcc47:	80 7d 80 00          	cmpb   $0x0,-0x80(%rbp)
 11bcc4b:	75 16                	jne    11bcc63 <br.encodeCommandPlanWithOptionsWrite+0x1223>
 11bcc4d:	48 8d bd 40 ba fb ff 	lea    -0x445c0(%rbp),%rdi
 11bcc54:	ba 00 00 01 00       	mov    $0x10000,%edx
 11bcc59:	31 f6                	xor    %esi,%esi
 11bcc5b:	c5 f8 77             	vzeroupper 
 11bcc5e:	e8 dd 26 12 00       	call   12df340 <compiler_rt.memset>
 11bcc63:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 11bcc67:	74 16                	je     11bcc7f <br.encodeCommandPlanWithOptionsWrite+0x123f>
 11bcc69:	48 8d bd d8 e4 fe ff 	lea    -0x11b28(%rbp),%rdi
 11bcc70:	ba 00 18 00 00       	mov    $0x1800,%edx
 11bcc75:	31 f6                	xor    %esi,%esi
 11bcc77:	c5 f8 77             	vzeroupper 
 11bcc7a:	e8 c1 26 12 00       	call   12df340 <compiler_rt.memset>
 11bcc7f:	48 c7 85 a0 c5 ff ff 	movq   $0x0,-0x3a60(%rbp)
 11bcc86:	00 00 00 00 
 11bcc8a:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 11bcc8e:	74 16                	je     11bcca6 <br.encodeCommandPlanWithOptionsWrite+0x1266>
 11bcc90:	48 8d bd c4 01 fe ff 	lea    -0x1fe3c(%rbp),%rdi
 11bcc97:	ba 00 42 00 00       	mov    $0x4200,%edx
 11bcc9c:	31 f6                	xor    %esi,%esi
 11bcc9e:	c5 f8 77             	vzeroupper 
 11bcca1:	e8 9a 26 12 00       	call   12df340 <compiler_rt.memset>
 11bcca6:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11bccaa:	c5 fc 11 85 2c ec ff 	vmovups %ymm0,-0x13d4(%rbp)
 11bccb1:	ff 
 11bccb2:	c5 fc 11 85 10 ec ff 	vmovups %ymm0,-0x13f0(%rbp)
 11bccb9:	ff 
 11bccba:	c5 fc 11 85 f0 eb ff 	vmovups %ymm0,-0x1410(%rbp)
 11bccc1:	ff 
 11bccc2:	c5 fc 11 85 d0 eb ff 	vmovups %ymm0,-0x1430(%rbp)
 11bccc9:	ff 
 11bccca:	c5 fc 11 85 b0 eb ff 	vmovups %ymm0,-0x1450(%rbp)
 11bccd1:	ff 
 11bccd2:	c5 fc 11 85 90 eb ff 	vmovups %ymm0,-0x1470(%rbp)
 11bccd9:	ff 
 11bccda:	c5 fc 11 85 70 eb ff 	vmovups %ymm0,-0x1490(%rbp)
 11bcce1:	ff 
 11bcce2:	c5 fc 11 85 50 eb ff 	vmovups %ymm0,-0x14b0(%rbp)
 11bcce9:	ff 
 11bccea:	c5 fc 11 85 30 eb ff 	vmovups %ymm0,-0x14d0(%rbp)
 11bccf1:	ff 
 11bccf2:	c5 fc 11 85 10 eb ff 	vmovups %ymm0,-0x14f0(%rbp)
 11bccf9:	ff 
 11bccfa:	80 7d cb 00          	cmpb   $0x0,-0x35(%rbp)
 11bccfe:	74 16                	je     11bcd16 <br.encodeCommandPlanWithOptionsWrite+0x12d6>
 11bcd00:	48 8d bd 90 9e ff ff 	lea    -0x6170(%rbp),%rdi
 11bcd07:	ba 68 07 00 00       	mov    $0x768,%edx
 11bcd0c:	31 f6                	xor    %esi,%esi
 11bcd0e:	c5 f8 77             	vzeroupper 
 11bcd11:	e8 2a 26 12 00       	call   12df340 <compiler_rt.memset>
 11bcd16:	84 db                	test   %bl,%bl
 11bcd18:	74 04                	je     11bcd1e <br.encodeCommandPlanWithOptionsWrite+0x12de>
 11bcd1a:	31 c0                	xor    %eax,%eax
 11bcd1c:	eb 1c                	jmp    11bcd3a <br.encodeCommandPlanWithOptionsWrite+0x12fa>
 11bcd1e:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 11bcd22:	0f 94 c0             	sete   %al
 11bcd25:	0f b6 95 e0 fe ff ff 	movzbl -0x120(%rbp),%edx
 11bcd2c:	f6 d2                	not    %dl
 11bcd2e:	8b 8d fc fe ff ff    	mov    -0x104(%rbp),%ecx
 11bcd34:	20 d1                	and    %dl,%cl
 11bcd36:	20 c1                	and    %al,%cl
 11bcd38:	89 c8                	mov    %ecx,%eax
 11bcd3a:	80 7d cb 00          	cmpb   $0x0,-0x35(%rbp)
 11bcd3e:	0f 94 c1             	sete   %cl
 11bcd41:	20 c1                	and    %al,%cl
 11bcd43:	88 8d f0 fc ff ff    	mov    %cl,-0x310(%rbp)
 11bcd49:	48 8d bd 88 37 ff ff 	lea    -0xc878(%rbp),%rdi
 11bcd50:	45 31 e4             	xor    %r12d,%r12d
 11bcd53:	ba 00 09 00 00       	mov    $0x900,%edx
 11bcd58:	31 f6                	xor    %esi,%esi
 11bcd5a:	c5 f8 77             	vzeroupper 
 11bcd5d:	e8 de 25 12 00       	call   12df340 <compiler_rt.memset>
 11bcd62:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11bcd66:	c5 fc 11 85 e0 dc ff 	vmovups %ymm0,-0x2320(%rbp)
 11bcd6d:	ff 
 11bcd6e:	c5 fc 11 85 00 dd ff 	vmovups %ymm0,-0x2300(%rbp)
 11bcd75:	ff 
 11bcd76:	c5 fc 11 85 20 dd ff 	vmovups %ymm0,-0x22e0(%rbp)
 11bcd7d:	ff 
 11bcd7e:	c5 fc 11 85 40 dd ff 	vmovups %ymm0,-0x22c0(%rbp)
 11bcd85:	ff 
 11bcd86:	c5 fc 11 85 60 dd ff 	vmovups %ymm0,-0x22a0(%rbp)
 11bcd8d:	ff 
 11bcd8e:	c5 fc 11 85 80 dd ff 	vmovups %ymm0,-0x2280(%rbp)
 11bcd95:	ff 
 11bcd96:	c5 fc 11 85 a0 dd ff 	vmovups %ymm0,-0x2260(%rbp)
 11bcd9d:	ff 
 11bcd9e:	c5 fc 11 85 c0 dd ff 	vmovups %ymm0,-0x2240(%rbp)
 11bcda5:	ff 
 11bcda6:	c5 fc 11 85 e0 dd ff 	vmovups %ymm0,-0x2220(%rbp)
 11bcdad:	ff 
 11bcdae:	c5 fc 11 85 fc dd ff 	vmovups %ymm0,-0x2204(%rbp)
 11bcdb5:	ff 
 11bcdb6:	c5 fc 10 85 e0 ef ff 	vmovups -0x1020(%rbp),%ymm0
 11bcdbd:	ff 
 11bcdbe:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 11bcdc5:	ff 
 11bcdc6:	0f b6 05 13 f9 e7 ff 	movzbl -0x1806ed(%rip),%eax        # 103c6e0 <__anon_30440>
 11bcdcd:	88 45 9f             	mov    %al,-0x61(%rbp)
 11bcdd0:	8b 85 9c fd ff ff    	mov    -0x264(%rbp),%eax
 11bcdd6:	c1 e8 08             	shr    $0x8,%eax
 11bcdd9:	89 85 fc fe ff ff    	mov    %eax,-0x104(%rbp)
 11bcddf:	48 8d 85 b8 d5 ff ff 	lea    -0x2a48(%rbp),%rax
 11bcde6:	48 89 85 18 fc ff ff 	mov    %rax,-0x3e8(%rbp)
 11bcded:	48 8d 85 a0 c0 ff ff 	lea    -0x3f60(%rbp),%rax
 11bcdf4:	48 89 85 10 fc ff ff 	mov    %rax,-0x3f0(%rbp)
 11bcdfb:	48 8d 85 7c 7f ff ff 	lea    -0x8084(%rbp),%rax
 11bce02:	48 89 85 08 fc ff ff 	mov    %rax,-0x3f8(%rbp)
 11bce09:	48 c7 85 10 fd ff ff 	movq   $0x0,-0x2f0(%rbp)
 11bce10:	00 00 00 00 
 11bce14:	48 c7 45 80 00 00 00 	movq   $0x0,-0x80(%rbp)
 11bce1b:	00 
 11bce1c:	48 c7 85 10 ff ff ff 	movq   $0x0,-0xf0(%rbp)
 11bce23:	00 00 00 00 
 11bce27:	48 c7 85 00 fc ff ff 	movq   $0x0,-0x400(%rbp)
 11bce2e:	00 00 00 00 
 11bce32:	48 8b 8d f8 fd ff ff 	mov    -0x208(%rbp),%rcx
 11bce39:	e9 86 01 00 00       	jmp    11bcfc4 <br.encodeCommandPlanWithOptionsWrite+0x1584>
 11bce3e:	8b 85 b3 fe ff ff    	mov    -0x14d(%rbp),%eax
 11bce44:	48 8d 8d 49 f6 ff ff 	lea    -0x9b7(%rbp),%rcx
 11bce4b:	89 41 03             	mov    %eax,0x3(%rcx)
 11bce4e:	8b 85 b0 fe ff ff    	mov    -0x150(%rbp),%eax
 11bce54:	89 01                	mov    %eax,(%rcx)
 11bce56:	8b 85 bb fe ff ff    	mov    -0x145(%rbp),%eax
 11bce5c:	89 41 13             	mov    %eax,0x13(%rcx)
 11bce5f:	8b 85 b8 fe ff ff    	mov    -0x148(%rbp),%eax
 11bce65:	89 41 10             	mov    %eax,0x10(%rcx)
 11bce68:	8b 85 c3 fe ff ff    	mov    -0x13d(%rbp),%eax
 11bce6e:	89 41 23             	mov    %eax,0x23(%rcx)
 11bce71:	8b 85 c0 fe ff ff    	mov    -0x140(%rbp),%eax
 11bce77:	89 41 20             	mov    %eax,0x20(%rcx)
 11bce7a:	8b 85 cb fe ff ff    	mov    -0x135(%rbp),%eax
 11bce80:	89 41 33             	mov    %eax,0x33(%rcx)
 11bce83:	8b 85 c8 fe ff ff    	mov    -0x138(%rbp),%eax
 11bce89:	89 41 30             	mov    %eax,0x30(%rcx)
 11bce8c:	8b 85 d3 fe ff ff    	mov    -0x12d(%rbp),%eax
 11bce92:	89 41 43             	mov    %eax,0x43(%rcx)
 11bce95:	8b 85 d0 fe ff ff    	mov    -0x130(%rbp),%eax
 11bce9b:	89 41 40             	mov    %eax,0x40(%rcx)
 11bce9e:	0f b7 85 f8 fe ff ff 	movzwl -0x108(%rbp),%eax
 11bcea5:	66 89 41 55          	mov    %ax,0x55(%rcx)
 11bcea9:	8b 85 f4 fe ff ff    	mov    -0x10c(%rbp),%eax
 11bceaf:	89 41 51             	mov    %eax,0x51(%rcx)
 11bceb2:	48 8b 85 d8 fe ff ff 	mov    -0x128(%rbp),%rax
 11bceb9:	48 89 85 38 f6 ff ff 	mov    %rax,-0x9c8(%rbp)
 11bcec0:	48 8b 85 60 fe ff ff 	mov    -0x1a0(%rbp),%rax
 11bcec7:	48 89 85 40 f6 ff ff 	mov    %rax,-0x9c0(%rbp)
 11bcece:	40 88 b5 48 f6 ff ff 	mov    %sil,-0x9b8(%rbp)
 11bced5:	48 8b 85 68 fe ff ff 	mov    -0x198(%rbp),%rax
 11bcedc:	48 89 85 50 f6 ff ff 	mov    %rax,-0x9b0(%rbp)
 11bcee3:	0f b6 45 d4          	movzbl -0x2c(%rbp),%eax
 11bcee7:	88 85 58 f6 ff ff    	mov    %al,-0x9a8(%rbp)
 11bceed:	48 8b 85 70 fe ff ff 	mov    -0x190(%rbp),%rax
 11bcef4:	48 89 85 60 f6 ff ff 	mov    %rax,-0x9a0(%rbp)
 11bcefb:	0f b6 45 d7          	movzbl -0x29(%rbp),%eax
 11bceff:	88 85 68 f6 ff ff    	mov    %al,-0x998(%rbp)
 11bcf05:	48 8b 85 78 fe ff ff 	mov    -0x188(%rbp),%rax
 11bcf0c:	48 89 85 70 f6 ff ff 	mov    %rax,-0x990(%rbp)
 11bcf13:	0f b6 45 ce          	movzbl -0x32(%rbp),%eax
 11bcf17:	88 85 78 f6 ff ff    	mov    %al,-0x988(%rbp)
 11bcf1d:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 11bcf24:	48 89 85 80 f6 ff ff 	mov    %rax,-0x980(%rbp)
 11bcf2b:	0f b6 45 c4          	movzbl -0x3c(%rbp),%eax
 11bcf2f:	88 85 88 f6 ff ff    	mov    %al,-0x978(%rbp)
 11bcf35:	48 8b 85 00 fd ff ff 	mov    -0x300(%rbp),%rax
 11bcf3c:	48 89 85 90 f6 ff ff 	mov    %rax,-0x970(%rbp)
 11bcf43:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 11bcf47:	88 85 98 f6 ff ff    	mov    %al,-0x968(%rbp)
 11bcf4d:	0f b6 45 c9          	movzbl -0x37(%rbp),%eax
 11bcf51:	88 85 99 f6 ff ff    	mov    %al,-0x967(%rbp)
 11bcf57:	48 8d bd 38 f6 ff ff 	lea    -0x9c8(%rbp),%rdi
 11bcf5e:	4c 8b bd 10 fd ff ff 	mov    -0x2f0(%rbp),%r15
 11bcf65:	4c 89 fe             	mov    %r15,%rsi
 11bcf68:	c5 f8 77             	vzeroupper 
 11bcf6b:	e8 f0 34 04 00       	call   1200460 <br.encoder.distance_block_split.Result.blockIndex>
 11bcf70:	48 8b 8d f8 fd ff ff 	mov    -0x208(%rbp),%rcx
 11bcf77:	48 8b 95 40 ff ff ff 	mov    -0xc0(%rbp),%rdx
 11bcf7e:	48 69 c0 3c 01 00 00 	imul   $0x13c,%rax,%rax
 11bcf85:	48 01 e8             	add    %rbp,%rax
 11bcf88:	48 05 90 9e ff ff    	add    $0xffffffffffff9e90,%rax
 11bcf8e:	ff 04 98             	incl   (%rax,%rbx,4)
 11bcf91:	49 ff c7             	inc    %r15
 11bcf94:	4c 89 bd 10 fd ff ff 	mov    %r15,-0x2f0(%rbp)
 11bcf9b:	80 bd 40 fe ff ff 00 	cmpb   $0x0,-0x1c0(%rbp)
 11bcfa2:	0f 84 72 02 00 00    	je     11bd21a <br.encodeCommandPlanWithOptionsWrite+0x17da>
 11bcfa8:	c5 fc 10 85 60 ef ff 	vmovups -0x10a0(%rbp),%ymm0
 11bcfaf:	ff 
 11bcfb0:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 11bcfb7:	ff 
 11bcfb8:	49 ff c4             	inc    %r12
 11bcfbb:	49 39 d4             	cmp    %rdx,%r12
 11bcfbe:	0f 84 8c 09 00 00    	je     11bd950 <br.encodeCommandPlanWithOptionsWrite+0x1f10>
 11bcfc4:	4c 89 a5 e0 fe ff ff 	mov    %r12,-0x120(%rbp)
 11bcfcb:	4b 8d 04 64          	lea    (%r12,%r12,2),%rax
 11bcfcf:	48 c1 e0 05          	shl    $0x5,%rax
 11bcfd3:	c5 fc 10 04 01       	vmovups (%rcx,%rax,1),%ymm0
 11bcfd8:	c5 fc 10 4c 01 20    	vmovups 0x20(%rcx,%rax,1),%ymm1
 11bcfde:	c5 fc 10 54 01 40    	vmovups 0x40(%rcx,%rax,1),%ymm2
 11bcfe4:	c5 fc 11 85 b0 f2 ff 	vmovups %ymm0,-0xd50(%rbp)
 11bcfeb:	ff 
 11bcfec:	c5 fc 11 95 f0 f2 ff 	vmovups %ymm2,-0xd10(%rbp)
 11bcff3:	ff 
 11bcff4:	c5 fc 11 8d d0 f2 ff 	vmovups %ymm1,-0xd30(%rbp)
 11bcffb:	ff 
 11bcffc:	48 8b 85 b0 f2 ff ff 	mov    -0xd50(%rbp),%rax
 11bd003:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 11bd007:	4c 8b a5 b8 f2 ff ff 	mov    -0xd48(%rbp),%r12
 11bd00e:	4c 8b ad c0 f2 ff ff 	mov    -0xd40(%rbp),%r13
 11bd015:	0f b6 8d 08 f3 ff ff 	movzbl -0xcf8(%rbp),%ecx
 11bd01c:	0f b6 85 09 f3 ff ff 	movzbl -0xcf7(%rbp),%eax
 11bd023:	88 85 48 fe ff ff    	mov    %al,-0x1b8(%rbp)
 11bd029:	88 8d b0 fd ff ff    	mov    %cl,-0x250(%rbp)
 11bd02f:	f6 c1 01             	test   $0x1,%cl
 11bd032:	74 41                	je     11bd075 <br.encodeCommandPlanWithOptionsWrite+0x1635>
 11bd034:	0f b6 55 88          	movzbl -0x78(%rbp),%edx
 11bd038:	48 8d bd b0 f9 ff ff 	lea    -0x650(%rbp),%rdi
 11bd03f:	48 8d b5 b0 f2 ff ff 	lea    -0xd50(%rbp),%rsi
 11bd046:	48 8b 8d f8 fb ff ff 	mov    -0x408(%rbp),%rcx
 11bd04d:	4c 8b 85 f0 fb ff ff 	mov    -0x410(%rbp),%r8
 11bd054:	c5 f8 77             	vzeroupper 
 11bd057:	e8 74 48 04 00       	call   12018d0 <br.commandWireDistance>
 11bd05c:	0f b7 85 b8 f9 ff ff 	movzwl -0x648(%rbp),%eax
 11bd063:	66 85 c0             	test   %ax,%ax
 11bd066:	0f 85 41 ea ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bd06c:	48 8b 95 b0 f9 ff ff 	mov    -0x650(%rbp),%rdx
 11bd073:	eb 02                	jmp    11bd077 <br.encodeCommandPlanWithOptionsWrite+0x1637>
 11bd075:	31 d2                	xor    %edx,%edx
 11bd077:	48 83 ec 08          	sub    $0x8,%rsp
 11bd07b:	48 8d bd a8 f3 ff ff 	lea    -0xc58(%rbp),%rdi
 11bd082:	48 8d b5 b0 f2 ff ff 	lea    -0xd50(%rbp),%rsi
 11bd089:	48 89 95 b8 fd ff ff 	mov    %rdx,-0x248(%rbp)
 11bd090:	8b 8d 30 fe ff ff    	mov    -0x1d0(%rbp),%ecx
 11bd096:	44 8b 85 34 fe ff ff 	mov    -0x1cc(%rbp),%r8d
 11bd09d:	4c 8d 8d 20 fd ff ff 	lea    -0x2e0(%rbp),%r9
 11bd0a4:	6a 00                	push   $0x0
 11bd0a6:	c5 f8 77             	vzeroupper 
 11bd0a9:	e8 72 43 04 00       	call   1201420 <br.resolveHqCommand>
 11bd0ae:	48 83 c4 10          	add    $0x10,%rsp
 11bd0b2:	0f b7 85 f0 f3 ff ff 	movzwl -0xc10(%rbp),%eax
 11bd0b9:	66 85 c0             	test   %ax,%ax
 11bd0bc:	0f 85 eb e9 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bd0c2:	c5 fc 10 85 a8 f3 ff 	vmovups -0xc58(%rbp),%ymm0
 11bd0c9:	ff 
 11bd0ca:	c5 fc 10 8d b2 f3 ff 	vmovups -0xc4e(%rbp),%ymm1
 11bd0d1:	ff 
 11bd0d2:	c5 fc 11 8d 6a ef ff 	vmovups %ymm1,-0x1096(%rbp)
 11bd0d9:	ff 
 11bd0da:	c5 fc 11 85 60 ef ff 	vmovups %ymm0,-0x10a0(%rbp)
 11bd0e1:	ff 
 11bd0e2:	0f b6 85 d2 f3 ff ff 	movzbl -0xc2e(%rbp),%eax
 11bd0e9:	88 85 80 fe ff ff    	mov    %al,-0x180(%rbp)
 11bd0ef:	0f b7 9d d4 f3 ff ff 	movzwl -0xc2c(%rbp),%ebx
 11bd0f6:	48 8b 85 d8 f3 ff ff 	mov    -0xc28(%rbp),%rax
 11bd0fd:	48 89 85 60 fd ff ff 	mov    %rax,-0x2a0(%rbp)
 11bd104:	0f b6 85 e0 f3 ff ff 	movzbl -0xc20(%rbp),%eax
 11bd10b:	88 85 e8 fc ff ff    	mov    %al,-0x318(%rbp)
 11bd111:	0f b6 85 e8 f3 ff ff 	movzbl -0xc18(%rbp),%eax
 11bd118:	88 85 40 fe ff ff    	mov    %al,-0x1c0(%rbp)
 11bd11e:	84 c0                	test   %al,%al
 11bd120:	74 31                	je     11bd153 <br.encodeCommandPlanWithOptionsWrite+0x1713>
 11bd122:	0f b6 8d e4 f3 ff ff 	movzbl -0xc1c(%rbp),%ecx
 11bd129:	0f b6 85 e5 f3 ff ff 	movzbl -0xc1b(%rbp),%eax
 11bd130:	88 8d 4f ff ff ff    	mov    %cl,-0xb1(%rbp)
 11bd136:	88 85 50 ff ff ff    	mov    %al,-0xb0(%rbp)
 11bd13c:	48 8d 8d 50 ff ff ff 	lea    -0xb0(%rbp),%rcx
 11bd143:	48 89 8d 80 fd ff ff 	mov    %rcx,-0x280(%rbp)
 11bd14a:	4c 8d bd 4f ff ff ff 	lea    -0xb1(%rbp),%r15
 11bd151:	eb 5f                	jmp    11bd1b2 <br.encodeCommandPlanWithOptionsWrite+0x1772>
 11bd153:	0f b6 45 9c          	movzbl -0x64(%rbp),%eax
 11bd157:	22 85 b0 fd ff ff    	and    -0x250(%rbp),%al
 11bd15d:	0f b6 8d 48 fe ff ff 	movzbl -0x1b8(%rbp),%ecx
 11bd164:	80 e1 03             	and    $0x3,%cl
 11bd167:	80 f9 02             	cmp    $0x2,%cl
 11bd16a:	0f 95 c1             	setne  %cl
 11bd16d:	20 c1                	and    %al,%cl
 11bd16f:	80 f9 01             	cmp    $0x1,%cl
 11bd172:	75 29                	jne    11bd19d <br.encodeCommandPlanWithOptionsWrite+0x175d>
 11bd174:	4c 8d bd 90 fd ff ff 	lea    -0x270(%rbp),%r15
 11bd17b:	4c 89 ff             	mov    %r15,%rdi
 11bd17e:	48 8b b5 b8 fd ff ff 	mov    -0x248(%rbp),%rsi
 11bd185:	48 8d 95 20 fd ff ff 	lea    -0x2e0(%rbp),%rdx
 11bd18c:	c5 f8 77             	vzeroupper 
 11bd18f:	e8 0c 41 04 00       	call   12012a0 <br.decoder.distance_history.symbolForDistance>
 11bd194:	48 8d 85 91 fd ff ff 	lea    -0x26f(%rbp),%rax
 11bd19b:	eb 0b                	jmp    11bd1a8 <br.encodeCommandPlanWithOptionsWrite+0x1768>
 11bd19d:	41 bf d4 6e 03 01    	mov    $0x1036ed4,%r15d
 11bd1a3:	b8 d5 6e 03 01       	mov    $0x1036ed5,%eax
 11bd1a8:	48 89 85 80 fd ff ff 	mov    %rax,-0x280(%rbp)
 11bd1af:	0f b6 00             	movzbl (%rax),%eax
 11bd1b2:	84 c0                	test   %al,%al
 11bd1b4:	74 17                	je     11bd1cd <br.encodeCommandPlanWithOptionsWrite+0x178d>
 11bd1b6:	0f b6 05 23 f5 e7 ff 	movzbl -0x180add(%rip),%eax        # 103c6e0 <__anon_30440>
 11bd1bd:	24 0f                	and    $0xf,%al
 11bd1bf:	41 0f b6 0f          	movzbl (%r15),%ecx
 11bd1c3:	80 e1 0f             	and    $0xf,%cl
 11bd1c6:	38 c1                	cmp    %al,%cl
 11bd1c8:	0f 94 c0             	sete   %al
 11bd1cb:	eb 02                	jmp    11bd1cf <br.encodeCommandPlanWithOptionsWrite+0x178f>
 11bd1cd:	31 c0                	xor    %eax,%eax
 11bd1cf:	80 bd 40 fe ff ff 00 	cmpb   $0x0,-0x1c0(%rbp)
 11bd1d6:	0f 85 a6 00 00 00    	jne    11bd282 <br.encodeCommandPlanWithOptionsWrite+0x1842>
 11bd1dc:	0f b6 c8             	movzbl %al,%ecx
 11bd1df:	48 8d bd d4 f9 ff ff 	lea    -0x62c(%rbp),%rdi
 11bd1e6:	4c 89 e6             	mov    %r12,%rsi
 11bd1e9:	4c 89 ea             	mov    %r13,%rdx
 11bd1ec:	c5 f8 77             	vzeroupper 
 11bd1ef:	e8 bc 3f 04 00       	call   12011b0 <br.commandEntryForLengthsAndDistance>
 11bd1f4:	80 bd e4 f9 ff ff 00 	cmpb   $0x0,-0x61c(%rbp)
 11bd1fb:	74 4f                	je     11bd24c <br.encodeCommandPlanWithOptionsWrite+0x180c>
 11bd1fd:	0f b6 85 de f9 ff ff 	movzbl -0x622(%rbp),%eax
 11bd204:	0f b7 9d e0 f9 ff ff 	movzwl -0x620(%rbp),%ebx
 11bd20b:	88 85 54 ff ff ff    	mov    %al,-0xac(%rbp)
 11bd211:	48 8d 85 54 ff ff ff 	lea    -0xac(%rbp),%rax
 11bd218:	eb 5f                	jmp    11bd279 <br.encodeCommandPlanWithOptionsWrite+0x1839>
 11bd21a:	48 8b 85 80 fd ff ff 	mov    -0x280(%rbp),%rax
 11bd221:	80 38 00             	cmpb   $0x0,(%rax)
 11bd224:	0f 84 6e 06 00 00    	je     11bd898 <br.encodeCommandPlanWithOptionsWrite+0x1e58>
 11bd22a:	0f b6 05 af f4 e7 ff 	movzbl -0x180b51(%rip),%eax        # 103c6e0 <__anon_30440>
 11bd231:	24 0f                	and    $0xf,%al
 11bd233:	48 8b b5 68 fd ff ff 	mov    -0x298(%rbp),%rsi
 11bd23a:	0f b6 36             	movzbl (%rsi),%esi
 11bd23d:	40 80 e6 0f          	and    $0xf,%sil
 11bd241:	40 38 c6             	cmp    %al,%sil
 11bd244:	0f 95 c0             	setne  %al
 11bd247:	e9 4e 06 00 00       	jmp    11bd89a <br.encodeCommandPlanWithOptionsWrite+0x1e5a>
 11bd24c:	48 8d bd c0 f9 ff ff 	lea    -0x640(%rbp),%rdi
 11bd253:	4c 89 e6             	mov    %r12,%rsi
 11bd256:	4c 89 ea             	mov    %r13,%rdx
 11bd259:	e8 32 3b 04 00       	call   1200d90 <br.commandEntryForLengths>
 11bd25e:	80 bd d0 f9 ff ff 00 	cmpb   $0x0,-0x630(%rbp)
 11bd265:	0f 84 f4 ef ff ff    	je     11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bd26b:	0f b7 9d cc f9 ff ff 	movzwl -0x634(%rbp),%ebx
 11bd272:	48 8d 85 ca f9 ff ff 	lea    -0x636(%rbp),%rax
 11bd279:	0f b6 00             	movzbl (%rax),%eax
 11bd27c:	88 85 80 fe ff ff    	mov    %al,-0x180(%rbp)
 11bd282:	80 bd f0 fc ff ff 00 	cmpb   $0x0,-0x310(%rbp)
 11bd289:	4c 89 bd 68 fd ff ff 	mov    %r15,-0x298(%rbp)
 11bd290:	74 37                	je     11bd2c9 <br.encodeCommandPlanWithOptionsWrite+0x1889>
 11bd292:	48 8b 8d 38 fd ff ff 	mov    -0x2c8(%rbp),%rcx
 11bd299:	4c 8d bd 8d fd ff ff 	lea    -0x273(%rbp),%r15
 11bd2a0:	4c 89 ff             	mov    %r15,%rdi
 11bd2a3:	48 8d b5 b0 f2 ff ff 	lea    -0xd50(%rbp),%rsi
 11bd2aa:	48 8b 95 b8 fd ff ff 	mov    -0x248(%rbp),%rdx
 11bd2b1:	c5 f8 77             	vzeroupper 
 11bd2b4:	e8 17 3a 04 00       	call   1200cd0 <br.sameLastDistanceShape>
 11bd2b9:	48 8d b5 8f fd ff ff 	lea    -0x271(%rbp),%rsi
 11bd2c0:	48 8d 8d 8e fd ff ff 	lea    -0x272(%rbp),%rcx
 11bd2c7:	eb 10                	jmp    11bd2d9 <br.encodeCommandPlanWithOptionsWrite+0x1899>
 11bd2c9:	41 bf e2 c6 03 01    	mov    $0x103c6e2,%r15d
 11bd2cf:	b9 e3 c6 03 01       	mov    $0x103c6e3,%ecx
 11bd2d4:	be e4 c6 03 01       	mov    $0x103c6e4,%esi
 11bd2d9:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 11bd2e0:	0f b6 36             	movzbl (%rsi),%esi
 11bd2e3:	40 88 75 9e          	mov    %sil,-0x62(%rbp)
 11bd2e7:	40 84 f6             	test   %sil,%sil
 11bd2ea:	74 2a                	je     11bd316 <br.encodeCommandPlanWithOptionsWrite+0x18d6>
 11bd2ec:	41 0f b6 17          	movzbl (%r15),%edx
 11bd2f0:	0f b6 09             	movzbl (%rcx),%ecx
 11bd2f3:	83 e2 1f             	and    $0x1f,%edx
 11bd2f6:	48 8d 14 52          	lea    (%rdx,%rdx,2),%rdx
 11bd2fa:	c1 e2 05             	shl    $0x5,%edx
 11bd2fd:	48 01 ea             	add    %rbp,%rdx
 11bd300:	48 81 c2 88 37 ff ff 	add    $0xffffffffffff3788,%rdx
 11bd307:	83 e1 1f             	and    $0x1f,%ecx
 11bd30a:	ff 04 8a             	incl   (%rdx,%rcx,4)
 11bd30d:	b1 01                	mov    $0x1,%cl
 11bd30f:	48 89 8d 10 ff ff ff 	mov    %rcx,-0xf0(%rbp)
 11bd316:	48 3d 80 00 00 00    	cmp    $0x80,%rax
 11bd31c:	77 0f                	ja     11bd32d <br.encodeCommandPlanWithOptionsWrite+0x18ed>
 11bd31e:	48 8b 85 e0 fe ff ff 	mov    -0x120(%rbp),%rax
 11bd325:	66 89 9c 45 a0 c4 ff 	mov    %bx,-0x3b60(%rbp,%rax,2)
 11bd32c:	ff 
 11bd32d:	44 0f b7 fb          	movzwl %bx,%r15d
 11bd331:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 11bd335:	0f 84 4c 01 00 00    	je     11bd487 <br.encodeCommandPlanWithOptionsWrite+0x1a47>
 11bd33b:	8b 85 8b fe ff ff    	mov    -0x175(%rbp),%eax
 11bd341:	48 8d 8d 19 f7 ff ff 	lea    -0x8e7(%rbp),%rcx
 11bd348:	89 41 03             	mov    %eax,0x3(%rcx)
 11bd34b:	8b 85 88 fe ff ff    	mov    -0x178(%rbp),%eax
 11bd351:	89 01                	mov    %eax,(%rcx)
 11bd353:	8b 85 93 fe ff ff    	mov    -0x16d(%rbp),%eax
 11bd359:	89 41 13             	mov    %eax,0x13(%rcx)
 11bd35c:	8b 85 90 fe ff ff    	mov    -0x170(%rbp),%eax
 11bd362:	89 41 10             	mov    %eax,0x10(%rcx)
 11bd365:	8b 85 9b fe ff ff    	mov    -0x165(%rbp),%eax
 11bd36b:	89 41 23             	mov    %eax,0x23(%rcx)
 11bd36e:	8b 85 98 fe ff ff    	mov    -0x168(%rbp),%eax
 11bd374:	89 41 20             	mov    %eax,0x20(%rcx)
 11bd377:	8b 85 a3 fe ff ff    	mov    -0x15d(%rbp),%eax
 11bd37d:	89 41 33             	mov    %eax,0x33(%rcx)
 11bd380:	8b 85 a0 fe ff ff    	mov    -0x160(%rbp),%eax
 11bd386:	89 41 30             	mov    %eax,0x30(%rcx)
 11bd389:	8b 85 ab fe ff ff    	mov    -0x155(%rbp),%eax
 11bd38f:	89 41 43             	mov    %eax,0x43(%rcx)
 11bd392:	8b 85 a8 fe ff ff    	mov    -0x158(%rbp),%eax
 11bd398:	89 41 40             	mov    %eax,0x40(%rcx)
 11bd39b:	0f b7 85 f0 fe ff ff 	movzwl -0x110(%rbp),%eax
 11bd3a2:	66 89 41 55          	mov    %ax,0x55(%rcx)
 11bd3a6:	8b 85 ec fe ff ff    	mov    -0x114(%rbp),%eax
 11bd3ac:	89 41 51             	mov    %eax,0x51(%rcx)
 11bd3af:	48 8b 85 38 fe ff ff 	mov    -0x1c8(%rbp),%rax
 11bd3b6:	48 89 85 08 f7 ff ff 	mov    %rax,-0x8f8(%rbp)
 11bd3bd:	48 8b 85 c0 fd ff ff 	mov    -0x240(%rbp),%rax
 11bd3c4:	48 89 85 10 f7 ff ff 	mov    %rax,-0x8f0(%rbp)
 11bd3cb:	0f b6 45 ca          	movzbl -0x36(%rbp),%eax
 11bd3cf:	88 85 18 f7 ff ff    	mov    %al,-0x8e8(%rbp)
 11bd3d5:	48 8b 85 c8 fd ff ff 	mov    -0x238(%rbp),%rax
 11bd3dc:	48 89 85 20 f7 ff ff 	mov    %rax,-0x8e0(%rbp)
 11bd3e3:	0f b6 45 d0          	movzbl -0x30(%rbp),%eax
 11bd3e7:	88 85 28 f7 ff ff    	mov    %al,-0x8d8(%rbp)
 11bd3ed:	48 8b 85 d0 fd ff ff 	mov    -0x230(%rbp),%rax
 11bd3f4:	48 89 85 30 f7 ff ff 	mov    %rax,-0x8d0(%rbp)
 11bd3fb:	0f b6 45 d6          	movzbl -0x2a(%rbp),%eax
 11bd3ff:	88 85 38 f7 ff ff    	mov    %al,-0x8c8(%rbp)
 11bd405:	48 8b 85 d8 fd ff ff 	mov    -0x228(%rbp),%rax
 11bd40c:	48 89 85 40 f7 ff ff 	mov    %rax,-0x8c0(%rbp)
 11bd413:	0f b6 45 cd          	movzbl -0x33(%rbp),%eax
 11bd417:	88 85 48 f7 ff ff    	mov    %al,-0x8b8(%rbp)
 11bd41d:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 11bd424:	48 89 85 50 f7 ff ff 	mov    %rax,-0x8b0(%rbp)
 11bd42b:	0f b6 45 c1          	movzbl -0x3f(%rbp),%eax
 11bd42f:	88 85 58 f7 ff ff    	mov    %al,-0x8a8(%rbp)
 11bd435:	48 8b 85 f8 fc ff ff 	mov    -0x308(%rbp),%rax
 11bd43c:	48 89 85 60 f7 ff ff 	mov    %rax,-0x8a0(%rbp)
 11bd443:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 11bd447:	88 85 68 f7 ff ff    	mov    %al,-0x898(%rbp)
 11bd44d:	0f b6 45 c8          	movzbl -0x38(%rbp),%eax
 11bd451:	88 85 69 f7 ff ff    	mov    %al,-0x897(%rbp)
 11bd457:	48 8d bd 08 f7 ff ff 	lea    -0x8f8(%rbp),%rdi
 11bd45e:	48 8b b5 e0 fe ff ff 	mov    -0x120(%rbp),%rsi
 11bd465:	c5 f8 77             	vzeroupper 
 11bd468:	e8 d3 36 04 00       	call   1200b40 <br.encoder.command_block_split.Result.blockIndex>
 11bd46d:	48 69 c0 00 0b 00 00 	imul   $0xb00,%rax,%rax
 11bd474:	48 01 e8             	add    %rbp,%rax
 11bd477:	48 05 c4 01 fe ff    	add    $0xfffffffffffe01c4,%rax
 11bd47d:	42 ff 04 b8          	incl   (%rax,%r15,4)
 11bd481:	48 8b 5d 90          	mov    -0x70(%rbp),%rbx
 11bd485:	eb 26                	jmp    11bd4ad <br.encodeCommandPlanWithOptionsWrite+0x1a6d>
 11bd487:	48 8d bd a0 c5 ff ff 	lea    -0x3a60(%rbp),%rdi
 11bd48e:	48 8d b5 7c 7f ff ff 	lea    -0x8084(%rbp),%rsi
 11bd495:	4c 89 fa             	mov    %r15,%rdx
 11bd498:	c5 f8 77             	vzeroupper 
 11bd49b:	e8 70 9f ff ff       	call   11b7410 <br.encoder.command_plan.PrefixAlphabetFor(704).recordFrequency>
 11bd4a0:	66 85 c0             	test   %ax,%ax
 11bd4a3:	48 8b 5d 90          	mov    -0x70(%rbp),%rbx
 11bd4a7:	0f 85 00 e6 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bd4ad:	4d 85 e4             	test   %r12,%r12
 11bd4b0:	48 8b 8d f8 fd ff ff 	mov    -0x208(%rbp),%rcx
 11bd4b7:	48 8b 85 78 fd ff ff 	mov    -0x288(%rbp),%rax
 11bd4be:	0f b6 75 d5          	movzbl -0x2b(%rbp),%esi
 11bd4c2:	0f 84 07 03 00 00    	je     11bd7cf <br.encodeCommandPlanWithOptionsWrite+0x1d8f>
 11bd4c8:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 11bd4cc:	0f 84 2d 02 00 00    	je     11bd6ff <br.encodeCommandPlanWithOptionsWrite+0x1cbf>
 11bd4d2:	48 01 c3             	add    %rax,%rbx
 11bd4d5:	48 89 5d 90          	mov    %rbx,-0x70(%rbp)
 11bd4d9:	31 db                	xor    %ebx,%ebx
 11bd4db:	4c 89 a5 e0 fd ff ff 	mov    %r12,-0x220(%rbp)
 11bd4e2:	44 0f b6 65 c7       	movzbl -0x39(%rbp),%r12d
 11bd4e7:	4c 8d ad b1 f6 ff ff 	lea    -0x94f(%rbp),%r13
 11bd4ee:	48 8b 45 90          	mov    -0x70(%rbp),%rax
 11bd4f2:	44 0f b6 3c 18       	movzbl (%rax,%rbx,1),%r15d
 11bd4f7:	8b 85 0b fe ff ff    	mov    -0x1f5(%rbp),%eax
 11bd4fd:	41 89 45 03          	mov    %eax,0x3(%r13)
 11bd501:	8b 85 08 fe ff ff    	mov    -0x1f8(%rbp),%eax
 11bd507:	41 89 45 00          	mov    %eax,0x0(%r13)
 11bd50b:	8b 85 13 fe ff ff    	mov    -0x1ed(%rbp),%eax
 11bd511:	41 89 45 13          	mov    %eax,0x13(%r13)
 11bd515:	8b 85 10 fe ff ff    	mov    -0x1f0(%rbp),%eax
 11bd51b:	41 89 45 10          	mov    %eax,0x10(%r13)
 11bd51f:	8b 85 1b fe ff ff    	mov    -0x1e5(%rbp),%eax
 11bd525:	41 89 45 23          	mov    %eax,0x23(%r13)
 11bd529:	8b 85 18 fe ff ff    	mov    -0x1e8(%rbp),%eax
 11bd52f:	41 89 45 20          	mov    %eax,0x20(%r13)
 11bd533:	8b 85 23 fe ff ff    	mov    -0x1dd(%rbp),%eax
 11bd539:	41 89 45 33          	mov    %eax,0x33(%r13)
 11bd53d:	8b 85 20 fe ff ff    	mov    -0x1e0(%rbp),%eax
 11bd543:	41 89 45 30          	mov    %eax,0x30(%r13)
 11bd547:	8b 85 2b fe ff ff    	mov    -0x1d5(%rbp),%eax
 11bd54d:	41 89 45 43          	mov    %eax,0x43(%r13)
 11bd551:	8b 85 28 fe ff ff    	mov    -0x1d8(%rbp),%eax
 11bd557:	41 89 45 40          	mov    %eax,0x40(%r13)
 11bd55b:	0f b7 85 54 fe ff ff 	movzwl -0x1ac(%rbp),%eax
 11bd562:	66 41 89 45 55       	mov    %ax,0x55(%r13)
 11bd567:	8b 85 50 fe ff ff    	mov    -0x1b0(%rbp),%eax
 11bd56d:	41 89 45 51          	mov    %eax,0x51(%r13)
 11bd571:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 11bd575:	48 8d 34 18          	lea    (%rax,%rbx,1),%rsi
 11bd579:	48 8b 85 18 ff ff ff 	mov    -0xe8(%rbp),%rax
 11bd580:	48 89 85 a0 f6 ff ff 	mov    %rax,-0x960(%rbp)
 11bd587:	48 8b 85 00 ff ff ff 	mov    -0x100(%rbp),%rax
 11bd58e:	48 89 85 a8 f6 ff ff 	mov    %rax,-0x958(%rbp)
 11bd595:	0f b6 45 c5          	movzbl -0x3b(%rbp),%eax
 11bd599:	88 85 b0 f6 ff ff    	mov    %al,-0x950(%rbp)
 11bd59f:	48 8b 85 20 ff ff ff 	mov    -0xe0(%rbp),%rax
 11bd5a6:	48 89 85 b8 f6 ff ff 	mov    %rax,-0x948(%rbp)
 11bd5ad:	0f b6 45 cf          	movzbl -0x31(%rbp),%eax
 11bd5b1:	88 85 c0 f6 ff ff    	mov    %al,-0x940(%rbp)
 11bd5b7:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 11bd5be:	48 89 85 c8 f6 ff ff 	mov    %rax,-0x938(%rbp)
 11bd5c5:	0f b6 45 d1          	movzbl -0x2f(%rbp),%eax
 11bd5c9:	88 85 d0 f6 ff ff    	mov    %al,-0x930(%rbp)
 11bd5cf:	48 8b 85 30 ff ff ff 	mov    -0xd0(%rbp),%rax
 11bd5d6:	48 89 85 d8 f6 ff ff 	mov    %rax,-0x928(%rbp)
 11bd5dd:	44 88 a5 e0 f6 ff ff 	mov    %r12b,-0x920(%rbp)
 11bd5e4:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 11bd5eb:	48 89 85 e8 f6 ff ff 	mov    %rax,-0x918(%rbp)
 11bd5f2:	0f b6 45 c0          	movzbl -0x40(%rbp),%eax
 11bd5f6:	88 85 f0 f6 ff ff    	mov    %al,-0x910(%rbp)
 11bd5fc:	48 8b 85 d8 fc ff ff 	mov    -0x328(%rbp),%rax
 11bd603:	48 89 85 f8 f6 ff ff 	mov    %rax,-0x908(%rbp)
 11bd60a:	0f b6 45 cc          	movzbl -0x34(%rbp),%eax
 11bd60e:	88 85 00 f7 ff ff    	mov    %al,-0x900(%rbp)
 11bd614:	0f b6 45 c2          	movzbl -0x3e(%rbp),%eax
 11bd618:	88 85 01 f7 ff ff    	mov    %al,-0x8ff(%rbp)
 11bd61e:	48 8d bd a0 f6 ff ff 	lea    -0x960(%rbp),%rdi
 11bd625:	e8 36 2e 04 00       	call   1200460 <br.encoder.distance_block_split.Result.blockIndex>
 11bd62a:	48 8b 4d 80          	mov    -0x80(%rbp),%rcx
 11bd62e:	c1 e0 0a             	shl    $0xa,%eax
 11bd631:	48 01 e8             	add    %rbp,%rax
 11bd634:	48 05 d8 e4 fe ff    	add    $0xfffffffffffee4d8,%rax
 11bd63a:	42 ff 04 b8          	incl   (%rax,%r15,4)
 11bd63e:	48 ff c3             	inc    %rbx
 11bd641:	48 39 9d e0 fd ff ff 	cmp    %rbx,-0x220(%rbp)
 11bd648:	0f 85 a0 fe ff ff    	jne    11bd4ee <br.encodeCommandPlanWithOptionsWrite+0x1aae>
 11bd64e:	48 01 d9             	add    %rbx,%rcx
 11bd651:	48 89 4d 80          	mov    %rcx,-0x80(%rbp)
 11bd655:	48 8b 95 40 ff ff ff 	mov    -0xc0(%rbp),%rdx
 11bd65c:	48 8b 8d f8 fd ff ff 	mov    -0x208(%rbp),%rcx
 11bd663:	0f b6 75 d5          	movzbl -0x2b(%rbp),%esi
 11bd667:	e9 6a 01 00 00       	jmp    11bd7d6 <br.encodeCommandPlanWithOptionsWrite+0x1d96>
 11bd66c:	0f b6 0e             	movzbl (%rsi),%ecx
 11bd66f:	8b 95 fc fe ff ff    	mov    -0x104(%rbp),%edx
 11bd675:	49 89 dc             	mov    %rbx,%r12
 11bd678:	0f b6 d8             	movzbl %al,%ebx
 11bd67b:	0f b6 f1             	movzbl %cl,%esi
 11bd67e:	0f b6 d2             	movzbl %dl,%edx
 11bd681:	89 df                	mov    %ebx,%edi
 11bd683:	c5 f8 77             	vzeroupper 
 11bd686:	e8 35 32 04 00       	call   12008c0 <br.encoder.literal_context.value>
 11bd68b:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 11bd68f:	48 89 8d 20 fc ff ff 	mov    %rcx,-0x3e0(%rbp)
 11bd696:	88 9d 28 fc ff ff    	mov    %bl,-0x3d8(%rbp)
 11bd69c:	4c 89 e3             	mov    %r12,%rbx
 11bd69f:	48 8b 8d ef f1 ff ff 	mov    -0xe11(%rbp),%rcx
 11bd6a6:	48 8d 95 29 fc ff ff 	lea    -0x3d7(%rbp),%rdx
 11bd6ad:	48 89 4a 3f          	mov    %rcx,0x3f(%rdx)
 11bd6b1:	c5 fc 10 85 b0 f1 ff 	vmovups -0xe50(%rbp),%ymm0
 11bd6b8:	ff 
 11bd6b9:	c5 fc 10 8d d0 f1 ff 	vmovups -0xe30(%rbp),%ymm1
 11bd6c0:	ff 
 11bd6c1:	c5 fc 11 4a 20       	vmovups %ymm1,0x20(%rdx)
 11bd6c6:	c5 fc 11 02          	vmovups %ymm0,(%rdx)
 11bd6ca:	0f b6 84 05 2a fc ff 	movzbl -0x3d6(%rbp,%rax,1),%eax
 11bd6d1:	ff 
 11bd6d2:	c1 e0 0a             	shl    $0xa,%eax
 11bd6d5:	48 01 e8             	add    %rbp,%rax
 11bd6d8:	48 05 40 ba fb ff    	add    $0xfffffffffffbba40,%rax
 11bd6de:	42 ff 04 b8          	incl   (%rax,%r15,4)
 11bd6e2:	48 8b 95 40 ff ff ff 	mov    -0xc0(%rbp),%rdx
 11bd6e9:	4d 89 ec             	mov    %r13,%r12
 11bd6ec:	48 ff c3             	inc    %rbx
 11bd6ef:	49 ff cc             	dec    %r12
 11bd6f2:	48 8b 85 78 fd ff ff 	mov    -0x288(%rbp),%rax
 11bd6f9:	0f 84 5d ff ff ff    	je     11bd65c <br.encodeCommandPlanWithOptionsWrite+0x1c1c>
 11bd6ff:	44 0f b6 3c 18       	movzbl (%rax,%rbx,1),%r15d
 11bd704:	48 8d bd b8 d5 ff ff 	lea    -0x2a48(%rbp),%rdi
 11bd70b:	48 8d b5 a0 c0 ff ff 	lea    -0x3f60(%rbp),%rsi
 11bd712:	48 8d 95 80 f3 ff ff 	lea    -0xc80(%rbp),%rdx
 11bd719:	44 89 f9             	mov    %r15d,%ecx
 11bd71c:	c5 f8 77             	vzeroupper 
 11bd71f:	e8 4c 9d ff ff       	call   11b7470 <br.encoder.command_plan.PrefixAlphabetFor(256).recordByteFrequency>
 11bd724:	66 85 c0             	test   %ax,%ax
 11bd727:	0f 85 80 e3 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bd72d:	48 8b 85 08 ff ff ff 	mov    -0xf8(%rbp),%rax
 11bd734:	80 38 00             	cmpb   $0x0,(%rax)
 11bd737:	48 8b 95 40 ff ff ff 	mov    -0xc0(%rbp),%rdx
 11bd73e:	74 ac                	je     11bd6ec <br.encodeCommandPlanWithOptionsWrite+0x1cac>
 11bd740:	4d 89 e5             	mov    %r12,%r13
 11bd743:	48 8b 85 08 fd ff ff 	mov    -0x2f8(%rbp),%rax
 11bd74a:	48 8b 00             	mov    (%rax),%rax
 11bd74d:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 11bd751:	48 8b 85 58 fd ff ff 	mov    -0x2a8(%rbp),%rax
 11bd758:	0f b6 00             	movzbl (%rax),%eax
 11bd75b:	48 8b b5 a0 fd ff ff 	mov    -0x260(%rbp),%rsi
 11bd762:	c5 fc 10 06          	vmovups (%rsi),%ymm0
 11bd766:	c5 fc 10 4e 20       	vmovups 0x20(%rsi),%ymm1
 11bd76b:	8b 4e 40             	mov    0x40(%rsi),%ecx
 11bd76e:	0f b7 56 44          	movzwl 0x44(%rsi),%edx
 11bd772:	0f b6 76 46          	movzbl 0x46(%rsi),%esi
 11bd776:	40 88 b5 f6 f1 ff ff 	mov    %sil,-0xe0a(%rbp)
 11bd77d:	66 89 95 f4 f1 ff ff 	mov    %dx,-0xe0c(%rbp)
 11bd784:	89 8d f0 f1 ff ff    	mov    %ecx,-0xe10(%rbp)
 11bd78a:	c5 fc 11 8d d0 f1 ff 	vmovups %ymm1,-0xe30(%rbp)
 11bd791:	ff 
 11bd792:	c5 fc 11 85 b0 f1 ff 	vmovups %ymm0,-0xe50(%rbp)
 11bd799:	ff 
 11bd79a:	8b 8d fc fe ff ff    	mov    -0x104(%rbp),%ecx
 11bd7a0:	8b 95 9c fd ff ff    	mov    -0x264(%rbp),%edx
 11bd7a6:	48 85 db             	test   %rbx,%rbx
 11bd7a9:	48 8b b5 78 fd ff ff 	mov    -0x288(%rbp),%rsi
 11bd7b0:	0f 84 bf fe ff ff    	je     11bd675 <br.encodeCommandPlanWithOptionsWrite+0x1c35>
 11bd7b6:	48 83 fb 01          	cmp    $0x1,%rbx
 11bd7ba:	0f 84 ac fe ff ff    	je     11bd66c <br.encodeCommandPlanWithOptionsWrite+0x1c2c>
 11bd7c0:	0f b6 54 1e fe       	movzbl -0x2(%rsi,%rbx,1),%edx
 11bd7c5:	0f b6 4c 1e ff       	movzbl -0x1(%rsi,%rbx,1),%ecx
 11bd7ca:	e9 a6 fe ff ff       	jmp    11bd675 <br.encodeCommandPlanWithOptionsWrite+0x1c35>
 11bd7cf:	48 8b 95 40 ff ff ff 	mov    -0xc0(%rbp),%rdx
 11bd7d6:	f6 85 b0 fd ff ff 01 	testb  $0x1,-0x250(%rbp)
 11bd7dd:	4c 8b a5 e0 fe ff ff 	mov    -0x120(%rbp),%r12
 11bd7e4:	48 8b bd 60 fd ff ff 	mov    -0x2a0(%rbp),%rdi
 11bd7eb:	0f 84 c7 f7 ff ff    	je     11bcfb8 <br.encodeCommandPlanWithOptionsWrite+0x1578>
 11bd7f1:	0f b6 85 80 fe ff ff 	movzbl -0x180(%rbp),%eax
 11bd7f8:	f6 d0                	not    %al
 11bd7fa:	a8 03                	test   $0x3,%al
 11bd7fc:	0f 85 99 f7 ff ff    	jne    11bcf9b <br.encodeCommandPlanWithOptionsWrite+0x155b>
 11bd802:	80 bd 40 fe ff ff 00 	cmpb   $0x0,-0x1c0(%rbp)
 11bd809:	74 24                	je     11bd82f <br.encodeCommandPlanWithOptionsWrite+0x1def>
 11bd80b:	80 bd e8 fc ff ff 00 	cmpb   $0x0,-0x318(%rbp)
 11bd812:	0f 84 47 ea ff ff    	je     11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bd818:	48 89 f8             	mov    %rdi,%rax
 11bd81b:	48 c1 e8 20          	shr    $0x20,%rax
 11bd81f:	66 83 f8 4e          	cmp    $0x4e,%ax
 11bd823:	0f 87 36 ea ff ff    	ja     11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bd829:	48 c1 ef 30          	shr    $0x30,%rdi
 11bd82d:	eb 34                	jmp    11bd863 <br.encodeCommandPlanWithOptionsWrite+0x1e23>
 11bd82f:	48 8b 85 80 fd ff ff 	mov    -0x280(%rbp),%rax
 11bd836:	80 38 00             	cmpb   $0x0,(%rax)
 11bd839:	0f 84 a9 00 00 00    	je     11bd8e8 <br.encodeCommandPlanWithOptionsWrite+0x1ea8>
 11bd83f:	48 8b 85 68 fd ff ff 	mov    -0x298(%rbp),%rax
 11bd846:	0f b6 00             	movzbl (%rax),%eax
 11bd849:	83 e0 0f             	and    $0xf,%eax
 11bd84c:	c6 85 9a fd ff ff 00 	movb   $0x0,-0x266(%rbp)
 11bd853:	31 ff                	xor    %edi,%edi
 11bd855:	48 8b 95 40 ff ff ff 	mov    -0xc0(%rbp),%rdx
 11bd85c:	48 8b 8d f8 fd ff ff 	mov    -0x208(%rbp),%rcx
 11bd863:	0f b7 d8             	movzwl %ax,%ebx
 11bd866:	80 7d 9e 00          	cmpb   $0x0,-0x62(%rbp)
 11bd86a:	74 16                	je     11bd882 <br.encodeCommandPlanWithOptionsWrite+0x1e42>
 11bd86c:	ff 84 9d e0 dc ff ff 	incl   -0x2320(%rbp,%rbx,4)
 11bd873:	40 80 e7 1f          	and    $0x1f,%dil
 11bd877:	40 0f b6 c7          	movzbl %dil,%eax
 11bd87b:	48 01 85 00 fc ff ff 	add    %rax,-0x400(%rbp)
 11bd882:	80 7d cb 00          	cmpb   $0x0,-0x35(%rbp)
 11bd886:	0f 85 b2 f5 ff ff    	jne    11bce3e <br.encodeCommandPlanWithOptionsWrite+0x13fe>
 11bd88c:	ff 84 9d 10 eb ff ff 	incl   -0x14f0(%rbp,%rbx,4)
 11bd893:	e9 03 f7 ff ff       	jmp    11bcf9b <br.encodeCommandPlanWithOptionsWrite+0x155b>
 11bd898:	b0 01                	mov    $0x1,%al
 11bd89a:	0f b6 b5 48 fe ff ff 	movzbl -0x1b8(%rbp),%esi
 11bd8a1:	40 80 e6 03          	and    $0x3,%sil
 11bd8a5:	40 80 fe 02          	cmp    $0x2,%sil
 11bd8a9:	0f 84 09 f7 ff ff    	je     11bcfb8 <br.encodeCommandPlanWithOptionsWrite+0x1578>
 11bd8af:	84 c0                	test   %al,%al
 11bd8b1:	0f 84 01 f7 ff ff    	je     11bcfb8 <br.encodeCommandPlanWithOptionsWrite+0x1578>
 11bd8b7:	c5 f8 10 85 28 fd ff 	vmovups -0x2d8(%rbp),%xmm0
 11bd8be:	ff 
 11bd8bf:	c5 f8 29 85 20 fd ff 	vmovaps %xmm0,-0x2e0(%rbp)
 11bd8c6:	ff 
 11bd8c7:	48 8b 85 38 fd ff ff 	mov    -0x2c8(%rbp),%rax
 11bd8ce:	48 89 85 30 fd ff ff 	mov    %rax,-0x2d0(%rbp)
 11bd8d5:	48 8b 85 b8 fd ff ff 	mov    -0x248(%rbp),%rax
 11bd8dc:	48 89 85 38 fd ff ff 	mov    %rax,-0x2c8(%rbp)
 11bd8e3:	e9 d0 f6 ff ff       	jmp    11bcfb8 <br.encodeCommandPlanWithOptionsWrite+0x1578>
 11bd8e8:	48 8d bd 38 fa ff ff 	lea    -0x5c8(%rbp),%rdi
 11bd8ef:	48 8b b5 b8 fd ff ff 	mov    -0x248(%rbp),%rsi
 11bd8f6:	8b 95 30 fe ff ff    	mov    -0x1d0(%rbp),%edx
 11bd8fc:	8b 8d 34 fe ff ff    	mov    -0x1cc(%rbp),%ecx
 11bd902:	45 31 c0             	xor    %r8d,%r8d
 11bd905:	c5 f8 77             	vzeroupper 
 11bd908:	e8 e3 2c 04 00       	call   12005f0 <br.encoder.distance.encodeWithFormat>
 11bd90d:	80 bd 40 fa ff ff 00 	cmpb   $0x0,-0x5c0(%rbp)
 11bd914:	0f 84 45 e9 ff ff    	je     11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bd91a:	48 8b bd 38 fa ff ff 	mov    -0x5c8(%rbp),%rdi
 11bd921:	48 8b 95 40 ff ff ff 	mov    -0xc0(%rbp),%rdx
 11bd928:	48 8b 8d f8 fd ff ff 	mov    -0x208(%rbp),%rcx
 11bd92f:	0f b6 75 d5          	movzbl -0x2b(%rbp),%esi
 11bd933:	4c 8b a5 e0 fe ff ff 	mov    -0x120(%rbp),%r12
 11bd93a:	48 89 f8             	mov    %rdi,%rax
 11bd93d:	48 c1 e8 20          	shr    $0x20,%rax
 11bd941:	66 83 f8 4e          	cmp    $0x4e,%ax
 11bd945:	0f 86 de fe ff ff    	jbe    11bd829 <br.encodeCommandPlanWithOptionsWrite+0x1de9>
 11bd94b:	e9 0f e9 ff ff       	jmp    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11bd950:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 11bd954:	75 47                	jne    11bd99d <br.encodeCommandPlanWithOptionsWrite+0x1f5d>
 11bd956:	48 83 bd b8 d5 ff ff 	cmpq   $0x0,-0x2a48(%rbp)
 11bd95d:	00 
 11bd95e:	75 3d                	jne    11bd99d <br.encodeCommandPlanWithOptionsWrite+0x1f5d>
 11bd960:	48 8b 85 80 f3 ff ff 	mov    -0xc80(%rbp),%rax
 11bd967:	a8 01                	test   $0x1,%al
 11bd969:	0f 85 bb 00 00 00    	jne    11bda2a <br.encodeCommandPlanWithOptionsWrite+0x1fea>
 11bd96f:	48 83 c8 01          	or     $0x1,%rax
 11bd973:	48 89 85 80 f3 ff ff 	mov    %rax,-0xc80(%rbp)
 11bd97a:	c7 85 a0 c0 ff ff 01 	movl   $0x1,-0x3f60(%rbp)
 11bd981:	00 00 00 
 11bd984:	66 c7 85 c0 d5 ff ff 	movw   $0x0,-0x2a40(%rbp)
 11bd98b:	00 00 
 11bd98d:	48 c7 85 b8 d5 ff ff 	movq   $0x1,-0x2a48(%rbp)
 11bd994:	01 00 00 00 
 11bd998:	e9 93 00 00 00       	jmp    11bda30 <br.encodeCommandPlanWithOptionsWrite+0x1ff0>
 11bd99d:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 11bd9a1:	0f 84 89 00 00 00    	je     11bda30 <br.encodeCommandPlanWithOptionsWrite+0x1ff0>
 11bd9a7:	b8 05 00 00 00       	mov    $0x5,%eax
 11bd9ac:	80 7d c7 00          	cmpb   $0x0,-0x39(%rbp)
 11bd9b0:	75 23                	jne    11bd9d5 <br.encodeCommandPlanWithOptionsWrite+0x1f95>
 11bd9b2:	b8 04 00 00 00       	mov    $0x4,%eax
 11bd9b7:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 11bd9bb:	75 18                	jne    11bd9d5 <br.encodeCommandPlanWithOptionsWrite+0x1f95>
 11bd9bd:	b8 03 00 00 00       	mov    $0x3,%eax
 11bd9c2:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 11bd9c6:	75 0d                	jne    11bd9d5 <br.encodeCommandPlanWithOptionsWrite+0x1f95>
 11bd9c8:	80 7d c5 01          	cmpb   $0x1,-0x3b(%rbp)
 11bd9cc:	b8 02 00 00 00       	mov    $0x2,%eax
 11bd9d1:	48 83 d8 00          	sbb    $0x0,%rax
 11bd9d5:	31 c9                	xor    %ecx,%ecx
 11bd9d7:	4c 8b 8d 00 ff ff ff 	mov    -0x100(%rbp),%r9
 11bd9de:	4c 89 8d d0 fb ff ff 	mov    %r9,-0x430(%rbp)
 11bd9e5:	48 8b 95 20 ff ff ff 	mov    -0xe0(%rbp),%rdx
 11bd9ec:	48 89 95 d8 fb ff ff 	mov    %rdx,-0x428(%rbp)
 11bd9f3:	48 8b 95 28 ff ff ff 	mov    -0xd8(%rbp),%rdx
 11bd9fa:	48 89 95 e0 fb ff ff 	mov    %rdx,-0x420(%rbp)
 11bda01:	48 8b 95 30 ff ff ff 	mov    -0xd0(%rbp),%rdx
 11bda08:	48 89 95 e8 fb ff ff 	mov    %rdx,-0x418(%rbp)
 11bda0f:	48 8d 95 d0 fb ff ff 	lea    -0x430(%rbp),%rdx
 11bda16:	48 89 d6             	mov    %rdx,%rsi
 11bda19:	4c 8b 85 18 ff ff ff 	mov    -0xe8(%rbp),%r8
 11bda20:	4c 89 c7             	mov    %r8,%rdi
 11bda23:	ff 24 cd d8 ff 00 01 	jmp    *0x100ffd8(,%rcx,8)
 11bda2a:	ff 85 a0 c0 ff ff    	incl   -0x3f60(%rbp)
 11bda30:	41 bf e5 c6 03 01    	mov    $0x103c6e5,%r15d
 11bda36:	f6 85 10 ff ff ff 01 	testb  $0x1,-0xf0(%rbp)
 11bda3d:	0f 84 92 00 00 00    	je     11bdad5 <br.encodeCommandPlanWithOptionsWrite+0x2095>
 11bda43:	48 83 ec 08          	sub    $0x8,%rsp
 11bda47:	48 8d 85 d1 e9 ff ff 	lea    -0x162f(%rbp),%rax
 11bda4e:	4c 8d 95 98 e4 ff ff 	lea    -0x1b68(%rbp),%r10
 11bda55:	4c 8d 9d fa a5 ff ff 	lea    -0x5a06(%rbp),%r11
 11bda5c:	48 8d 95 a0 c5 ff ff 	lea    -0x3a60(%rbp),%rdx
 11bda63:	48 8d bd 1a bc ff ff 	lea    -0x43e6(%rbp),%rdi
 11bda6a:	48 8d b5 7c 7f ff ff 	lea    -0x8084(%rbp),%rsi
 11bda71:	48 8d 8d 10 eb ff ff 	lea    -0x14f0(%rbp),%rcx
 11bda78:	4c 8d 85 88 37 ff ff 	lea    -0xc878(%rbp),%r8
 11bda7f:	4c 8d 8d e0 dc ff ff 	lea    -0x2320(%rbp),%r9
 11bda86:	50                   	push   %rax
 11bda87:	41 52                	push   %r10
 11bda89:	41 53                	push   %r11
 11bda8b:	52                   	push   %rdx
 11bda8c:	ff b5 a8 fd ff ff    	push   -0x258(%rbp)
 11bda92:	ff b5 18 fd ff ff    	push   -0x2e8(%rbp)
 11bda98:	ff b5 00 fc ff ff    	push   -0x400(%rbp)
 11bda9e:	c5 f8 77             	vzeroupper 
 11bdaa1:	e8 7a 10 04 00       	call   11feb20 <br.chooseSameLastDistancePlan__anon_30553>
 11bdaa6:	48 83 c4 40          	add    $0x40,%rsp
 11bdaaa:	0f b7 85 1a bc ff ff 	movzwl -0x43e6(%rbp),%eax
 11bdab1:	66 85 c0             	test   %ax,%ax
 11bdab4:	0f 85 f3 df ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bdaba:	48 8d b5 1c bc ff ff 	lea    -0x43e4(%rbp),%rsi
 11bdac1:	4c 8d bd 3b 7d ff ff 	lea    -0x82c5(%rbp),%r15
 11bdac8:	ba 41 02 00 00       	mov    $0x241,%edx
 11bdacd:	4c 89 ff             	mov    %r15,%rdi
 11bdad0:	e8 8b 1c 12 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11bdad5:	48 8d bd 5f be ff ff 	lea    -0x41a1(%rbp),%rdi
 11bdadc:	ba 41 02 00 00       	mov    $0x241,%edx
 11bdae1:	4c 89 fe             	mov    %r15,%rsi
 11bdae4:	c5 f8 77             	vzeroupper 
 11bdae7:	e8 74 1c 12 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11bdaec:	80 7d cb 00          	cmpb   $0x0,-0x35(%rbp)
 11bdaf0:	0f 84 80 00 00 00    	je     11bdb76 <br.encodeCommandPlanWithOptionsWrite+0x2136>
 11bdaf6:	b8 05 00 00 00       	mov    $0x5,%eax
 11bdafb:	80 7d ce 00          	cmpb   $0x0,-0x32(%rbp)
 11bdaff:	75 23                	jne    11bdb24 <br.encodeCommandPlanWithOptionsWrite+0x20e4>
 11bdb01:	b8 04 00 00 00       	mov    $0x4,%eax
 11bdb06:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 11bdb0a:	75 18                	jne    11bdb24 <br.encodeCommandPlanWithOptionsWrite+0x20e4>
 11bdb0c:	b8 03 00 00 00       	mov    $0x3,%eax
 11bdb11:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 11bdb15:	75 0d                	jne    11bdb24 <br.encodeCommandPlanWithOptionsWrite+0x20e4>
 11bdb17:	80 7d d5 01          	cmpb   $0x1,-0x2b(%rbp)
 11bdb1b:	b8 02 00 00 00       	mov    $0x2,%eax
 11bdb20:	48 83 d8 00          	sbb    $0x0,%rax
 11bdb24:	31 c9                	xor    %ecx,%ecx
 11bdb26:	48 8b 95 60 fe ff ff 	mov    -0x1a0(%rbp),%rdx
 11bdb2d:	48 89 95 b0 fb ff ff 	mov    %rdx,-0x450(%rbp)
 11bdb34:	48 8b 95 68 fe ff ff 	mov    -0x198(%rbp),%rdx
 11bdb3b:	48 89 95 b8 fb ff ff 	mov    %rdx,-0x448(%rbp)
 11bdb42:	48 8b 95 70 fe ff ff 	mov    -0x190(%rbp),%rdx
 11bdb49:	48 89 95 c0 fb ff ff 	mov    %rdx,-0x440(%rbp)
 11bdb50:	48 8b 95 78 fe ff ff 	mov    -0x188(%rbp),%rdx
 11bdb57:	48 89 95 c8 fb ff ff 	mov    %rdx,-0x438(%rbp)
 11bdb5e:	48 8d 95 b0 fb ff ff 	lea    -0x450(%rbp),%rdx
 11bdb65:	48 89 d6             	mov    %rdx,%rsi
 11bdb68:	48 8b bd d8 fe ff ff 	mov    -0x128(%rbp),%rdi
 11bdb6f:	ff 24 cd 00 00 01 01 	jmp    *0x1010000(,%rcx,8)
 11bdb76:	31 c0                	xor    %eax,%eax
 11bdb78:	8b 8c 85 10 eb ff ff 	mov    -0x14f0(%rbp,%rax,4),%ecx
 11bdb7f:	85 c9                	test   %ecx,%ecx
 11bdb81:	75 0a                	jne    11bdb8d <br.encodeCommandPlanWithOptionsWrite+0x214d>
 11bdb83:	48 83 f8 4e          	cmp    $0x4e,%rax
 11bdb87:	48 8d 40 01          	lea    0x1(%rax),%rax
 11bdb8b:	75 eb                	jne    11bdb78 <br.encodeCommandPlanWithOptionsWrite+0x2138>
 11bdb8d:	85 c9                	test   %ecx,%ecx
 11bdb8f:	75 0a                	jne    11bdb9b <br.encodeCommandPlanWithOptionsWrite+0x215b>
 11bdb91:	c7 85 10 eb ff ff 01 	movl   $0x1,-0x14f0(%rbp)
 11bdb98:	00 00 00 
 11bdb9b:	b8 28 c9 03 01       	mov    $0x103c928,%eax
 11bdba0:	f6 85 10 ff ff ff 01 	testb  $0x1,-0xf0(%rbp)
 11bdba7:	74 65                	je     11bdc0e <br.encodeCommandPlanWithOptionsWrite+0x21ce>
 11bdba9:	48 8b 85 38 e5 ff ff 	mov    -0x1ac8(%rbp),%rax
 11bdbb0:	48 89 85 e0 e5 ff ff 	mov    %rax,-0x1a20(%rbp)
 11bdbb7:	c5 fc 10 85 18 e5 ff 	vmovups -0x1ae8(%rbp),%ymm0
 11bdbbe:	ff 
 11bdbbf:	c5 fc 11 85 c0 e5 ff 	vmovups %ymm0,-0x1a40(%rbp)
 11bdbc6:	ff 
 11bdbc7:	c5 fc 10 85 98 e4 ff 	vmovups -0x1b68(%rbp),%ymm0
 11bdbce:	ff 
 11bdbcf:	c5 fc 10 8d d8 e4 ff 	vmovups -0x1b28(%rbp),%ymm1
 11bdbd6:	ff 
 11bdbd7:	c5 fc 10 95 f8 e4 ff 	vmovups -0x1b08(%rbp),%ymm2
 11bdbde:	ff 
 11bdbdf:	c5 fc 11 95 a0 e5 ff 	vmovups %ymm2,-0x1a60(%rbp)
 11bdbe6:	ff 
 11bdbe7:	c5 fc 11 8d 80 e5 ff 	vmovups %ymm1,-0x1a80(%rbp)
 11bdbee:	ff 
 11bdbef:	c5 fc 10 8d b8 e4 ff 	vmovups -0x1b48(%rbp),%ymm1
 11bdbf6:	ff 
 11bdbf7:	c5 fc 11 8d 60 e5 ff 	vmovups %ymm1,-0x1aa0(%rbp)
 11bdbfe:	ff 
 11bdbff:	c5 fc 11 85 40 e5 ff 	vmovups %ymm0,-0x1ac0(%rbp)
 11bdc06:	ff 
 11bdc07:	48 8d 85 40 e5 ff ff 	lea    -0x1ac0(%rbp),%rax
 11bdc0e:	48 8b 88 a0 00 00 00 	mov    0xa0(%rax),%rcx
 11bdc15:	48 89 8d a0 f0 ff ff 	mov    %rcx,-0xf60(%rbp)
 11bdc1c:	c5 fc 10 80 80 00 00 	vmovups 0x80(%rax),%ymm0
 11bdc23:	00 
 11bdc24:	c5 fc 11 85 80 f0 ff 	vmovups %ymm0,-0xf80(%rbp)
 11bdc2b:	ff 
 11bdc2c:	c5 fc 10 00          	vmovups (%rax),%ymm0
 11bdc30:	c5 fc 10 48 40       	vmovups 0x40(%rax),%ymm1
 11bdc35:	c5 fc 10 50 60       	vmovups 0x60(%rax),%ymm2
 11bdc3a:	c5 fc 11 95 60 f0 ff 	vmovups %ymm2,-0xfa0(%rbp)
 11bdc41:	ff 
 11bdc42:	c5 fc 11 8d 40 f0 ff 	vmovups %ymm1,-0xfc0(%rbp)
 11bdc49:	ff 
 11bdc4a:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 11bdc4f:	c5 fc 11 8d 20 f0 ff 	vmovups %ymm1,-0xfe0(%rbp)
 11bdc56:	ff 
 11bdc57:	c5 fc 11 85 00 f0 ff 	vmovups %ymm0,-0x1000(%rbp)
 11bdc5e:	ff 
 11bdc5f:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 11bdc63:	75 1f                	jne    11bdc84 <br.encodeCommandPlanWithOptionsWrite+0x2244>
 11bdc65:	48 8d bd b8 d5 ff ff 	lea    -0x2a48(%rbp),%rdi
 11bdc6c:	48 8d b5 a0 c0 ff ff 	lea    -0x3f60(%rbp),%rsi
 11bdc73:	c5 f8 77             	vzeroupper 
 11bdc76:	e8 55 98 ff ff       	call   11b74d0 <br.encoder.command_plan.PrefixAlphabetFor(256).sortByFrequencies>
 11bdc7b:	66 85 c0             	test   %ax,%ax
 11bdc7e:	0f 85 29 de ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bdc84:	48 8b 85 08 ff ff ff 	mov    -0xf8(%rbp),%rax
 11bdc8b:	44 0f b6 20          	movzbl (%rax),%r12d
 11bdc8f:	45 84 e4             	test   %r12b,%r12b
 11bdc92:	0f 84 82 00 00 00    	je     11bdd1a <br.encodeCommandPlanWithOptionsWrite+0x22da>
 11bdc98:	48 8b 85 a0 fd ff ff 	mov    -0x260(%rbp),%rax
 11bdc9f:	44 0f b6 28          	movzbl (%rax),%r13d
 11bdca3:	49 83 e5 7f          	and    $0x7f,%r13
 11bdca7:	74 71                	je     11bdd1a <br.encodeCommandPlanWithOptionsWrite+0x22da>
 11bdca9:	4c 8d bd 40 ba fb ff 	lea    -0x445c0(%rbp),%r15
 11bdcb0:	31 db                	xor    %ebx,%ebx
 11bdcb2:	48 89 d8             	mov    %rbx,%rax
 11bdcb5:	48 c1 e0 0a          	shl    $0xa,%rax
 11bdcb9:	48 8d 34 28          	lea    (%rax,%rbp,1),%rsi
 11bdcbd:	48 81 c6 40 ba fb ff 	add    $0xfffffffffffbba40,%rsi
 11bdcc4:	31 c0                	xor    %eax,%eax
 11bdcc6:	41 8b 0c 87          	mov    (%r15,%rax,4),%ecx
 11bdcca:	85 c9                	test   %ecx,%ecx
 11bdccc:	75 0c                	jne    11bdcda <br.encodeCommandPlanWithOptionsWrite+0x229a>
 11bdcce:	48 3d ff 00 00 00    	cmp    $0xff,%rax
 11bdcd4:	48 8d 40 01          	lea    0x1(%rax),%rax
 11bdcd8:	75 ec                	jne    11bdcc6 <br.encodeCommandPlanWithOptionsWrite+0x2286>
 11bdcda:	85 c9                	test   %ecx,%ecx
 11bdcdc:	75 06                	jne    11bdce4 <br.encodeCommandPlanWithOptionsWrite+0x22a4>
 11bdcde:	c7 06 01 00 00 00    	movl   $0x1,(%rsi)
 11bdce4:	48 89 d8             	mov    %rbx,%rax
 11bdce7:	48 c1 e0 09          	shl    $0x9,%rax
 11bdceb:	48 8d 04 d8          	lea    (%rax,%rbx,8),%rax
 11bdcef:	48 8d 3c 28          	lea    (%rax,%rbp,1),%rdi
 11bdcf3:	48 81 c7 40 1d fd ff 	add    $0xfffffffffffd1d40,%rdi
 11bdcfa:	c5 f8 77             	vzeroupper 
 11bdcfd:	e8 3e 99 ff ff       	call   11b7640 <br.encoder.command_plan.alphabetFromFrequenciesInto__anon_30613>
 11bdd02:	66 85 c0             	test   %ax,%ax
 11bdd05:	0f 85 a2 dd ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bdd0b:	48 ff c3             	inc    %rbx
 11bdd0e:	49 81 c7 00 04 00 00 	add    $0x400,%r15
 11bdd15:	4c 39 eb             	cmp    %r13,%rbx
 11bdd18:	75 98                	jne    11bdcb2 <br.encodeCommandPlanWithOptionsWrite+0x2272>
 11bdd1a:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 11bdd1e:	0f 84 9e 00 00 00    	je     11bddc2 <br.encodeCommandPlanWithOptionsWrite+0x2382>
 11bdd24:	80 7d c0 00          	cmpb   $0x0,-0x40(%rbp)
 11bdd28:	74 14                	je     11bdd3e <br.encodeCommandPlanWithOptionsWrite+0x22fe>
 11bdd2a:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 11bdd31:	49 89 c5             	mov    %rax,%r13
 11bdd34:	48 85 c0             	test   %rax,%rax
 11bdd37:	75 51                	jne    11bdd8a <br.encodeCommandPlanWithOptionsWrite+0x234a>
 11bdd39:	e9 84 00 00 00       	jmp    11bddc2 <br.encodeCommandPlanWithOptionsWrite+0x2382>
 11bdd3e:	0f b6 45 cc          	movzbl -0x34(%rbp),%eax
 11bdd42:	0a 45 c2             	or     -0x3e(%rbp),%al
 11bdd45:	a8 01                	test   $0x1,%al
 11bdd47:	74 0f                	je     11bdd58 <br.encodeCommandPlanWithOptionsWrite+0x2318>
 11bdd49:	44 0f b6 6d cc       	movzbl -0x34(%rbp),%r13d
 11bdd4e:	41 83 e5 01          	and    $0x1,%r13d
 11bdd52:	49 83 f5 03          	xor    $0x3,%r13
 11bdd56:	eb 32                	jmp    11bdd8a <br.encodeCommandPlanWithOptionsWrite+0x234a>
 11bdd58:	41 bd 06 00 00 00    	mov    $0x6,%r13d
 11bdd5e:	80 7d c7 00          	cmpb   $0x0,-0x39(%rbp)
 11bdd62:	75 26                	jne    11bdd8a <br.encodeCommandPlanWithOptionsWrite+0x234a>
 11bdd64:	41 bd 05 00 00 00    	mov    $0x5,%r13d
 11bdd6a:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 11bdd6e:	75 1a                	jne    11bdd8a <br.encodeCommandPlanWithOptionsWrite+0x234a>
 11bdd70:	41 bd 04 00 00 00    	mov    $0x4,%r13d
 11bdd76:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 11bdd7a:	75 0e                	jne    11bdd8a <br.encodeCommandPlanWithOptionsWrite+0x234a>
 11bdd7c:	80 7d c5 01          	cmpb   $0x1,-0x3b(%rbp)
 11bdd80:	41 bd 03 00 00 00    	mov    $0x3,%r13d
 11bdd86:	49 83 dd 00          	sbb    $0x0,%r13
 11bdd8a:	4c 8d bd d8 e4 fe ff 	lea    -0x11b28(%rbp),%r15
 11bdd91:	48 8d 9d 58 8c ff ff 	lea    -0x73a8(%rbp),%rbx
 11bdd98:	48 89 df             	mov    %rbx,%rdi
 11bdd9b:	4c 89 fe             	mov    %r15,%rsi
 11bdd9e:	c5 f8 77             	vzeroupper 
 11bdda1:	e8 9a 98 ff ff       	call   11b7640 <br.encoder.command_plan.alphabetFromFrequenciesInto__anon_30613>
 11bdda6:	66 85 c0             	test   %ax,%ax
 11bdda9:	0f 85 fe dc ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bddaf:	49 81 c7 00 04 00 00 	add    $0x400,%r15
 11bddb6:	48 81 c3 08 02 00 00 	add    $0x208,%rbx
 11bddbd:	49 ff cd             	dec    %r13
 11bddc0:	75 d6                	jne    11bdd98 <br.encodeCommandPlanWithOptionsWrite+0x2358>
 11bddc2:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 11bddc6:	74 1e                	je     11bdde6 <br.encodeCommandPlanWithOptionsWrite+0x23a6>
 11bddc8:	80 7d c1 00          	cmpb   $0x0,-0x3f(%rbp)
 11bddcc:	74 39                	je     11bde07 <br.encodeCommandPlanWithOptionsWrite+0x23c7>
 11bddce:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 11bddd5:	49 89 c5             	mov    %rax,%r13
 11bddd8:	48 85 c0             	test   %rax,%rax
 11bdddb:	0f 85 9c 00 00 00    	jne    11bde7d <br.encodeCommandPlanWithOptionsWrite+0x243d>
 11bdde1:	e9 cf 00 00 00       	jmp    11bdeb5 <br.encodeCommandPlanWithOptionsWrite+0x2475>
 11bdde6:	f6 85 10 ff ff ff 01 	testb  $0x1,-0xf0(%rbp)
 11bdded:	74 32                	je     11bde21 <br.encodeCommandPlanWithOptionsWrite+0x23e1>
 11bddef:	80 7d cb 00          	cmpb   $0x0,-0x35(%rbp)
 11bddf3:	0f 85 c2 00 00 00    	jne    11bdebb <br.encodeCommandPlanWithOptionsWrite+0x247b>
 11bddf9:	b0 01                	mov    $0x1,%al
 11bddfb:	48 89 85 10 ff ff ff 	mov    %rax,-0xf0(%rbp)
 11bde02:	e9 98 01 00 00       	jmp    11bdf9f <br.encodeCommandPlanWithOptionsWrite+0x255f>
 11bde07:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 11bde0b:	0a 45 c8             	or     -0x38(%rbp),%al
 11bde0e:	a8 01                	test   $0x1,%al
 11bde10:	74 39                	je     11bde4b <br.encodeCommandPlanWithOptionsWrite+0x240b>
 11bde12:	44 0f b6 6d d2       	movzbl -0x2e(%rbp),%r13d
 11bde17:	41 83 e5 01          	and    $0x1,%r13d
 11bde1b:	49 83 f5 03          	xor    $0x3,%r13
 11bde1f:	eb 5c                	jmp    11bde7d <br.encodeCommandPlanWithOptionsWrite+0x243d>
 11bde21:	48 8d bd a0 c5 ff ff 	lea    -0x3a60(%rbp),%rdi
 11bde28:	48 8d b5 7c 7f ff ff 	lea    -0x8084(%rbp),%rsi
 11bde2f:	c5 f8 77             	vzeroupper 
 11bde32:	e8 99 96 ff ff       	call   11b74d0 <br.encoder.command_plan.PrefixAlphabetFor(256).sortByFrequencies>
 11bde37:	66 85 c0             	test   %ax,%ax
 11bde3a:	0f 85 6d dc ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bde40:	80 7d cb 00          	cmpb   $0x0,-0x35(%rbp)
 11bde44:	75 75                	jne    11bdebb <br.encodeCommandPlanWithOptionsWrite+0x247b>
 11bde46:	e9 be 00 00 00       	jmp    11bdf09 <br.encodeCommandPlanWithOptionsWrite+0x24c9>
 11bde4b:	41 bd 06 00 00 00    	mov    $0x6,%r13d
 11bde51:	80 7d cd 00          	cmpb   $0x0,-0x33(%rbp)
 11bde55:	75 26                	jne    11bde7d <br.encodeCommandPlanWithOptionsWrite+0x243d>
 11bde57:	41 bd 05 00 00 00    	mov    $0x5,%r13d
 11bde5d:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 11bde61:	75 1a                	jne    11bde7d <br.encodeCommandPlanWithOptionsWrite+0x243d>
 11bde63:	41 bd 04 00 00 00    	mov    $0x4,%r13d
 11bde69:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 11bde6d:	75 0e                	jne    11bde7d <br.encodeCommandPlanWithOptionsWrite+0x243d>
 11bde6f:	80 7d ca 01          	cmpb   $0x1,-0x36(%rbp)
 11bde73:	41 bd 03 00 00 00    	mov    $0x3,%r13d
 11bde79:	49 83 dd 00          	sbb    $0x0,%r13
 11bde7d:	4c 8d bd c4 01 fe ff 	lea    -0x1fe3c(%rbp),%r15
 11bde84:	48 8d 9d d8 fc fe ff 	lea    -0x10328(%rbp),%rbx
 11bde8b:	48 89 df             	mov    %rbx,%rdi
 11bde8e:	4c 89 fe             	mov    %r15,%rsi
 11bde91:	c5 f8 77             	vzeroupper 
 11bde94:	e8 77 98 ff ff       	call   11b7710 <br.encoder.command_plan.alphabetFromFrequenciesInto__anon_30626>
 11bde99:	66 85 c0             	test   %ax,%ax
 11bde9c:	0f 85 0b dc ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bdea2:	49 81 c7 00 0b 00 00 	add    $0xb00,%r15
 11bdea9:	48 81 c3 88 05 00 00 	add    $0x588,%rbx
 11bdeb0:	49 ff cd             	dec    %r13
 11bdeb3:	75 d6                	jne    11bde8b <br.encodeCommandPlanWithOptionsWrite+0x244b>
 11bdeb5:	80 7d cb 00          	cmpb   $0x0,-0x35(%rbp)
 11bdeb9:	74 38                	je     11bdef3 <br.encodeCommandPlanWithOptionsWrite+0x24b3>
 11bdebb:	80 7d c4 00          	cmpb   $0x0,-0x3c(%rbp)
 11bdebf:	74 18                	je     11bded9 <br.encodeCommandPlanWithOptionsWrite+0x2499>
 11bdec1:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 11bdec8:	49 89 c5             	mov    %rax,%r13
 11bdecb:	48 85 c0             	test   %rax,%rax
 11bdece:	0f 85 93 00 00 00    	jne    11bdf67 <br.encodeCommandPlanWithOptionsWrite+0x2527>
 11bded4:	e9 c6 00 00 00       	jmp    11bdf9f <br.encodeCommandPlanWithOptionsWrite+0x255f>
 11bded9:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 11bdedd:	0a 45 c9             	or     -0x37(%rbp),%al
 11bdee0:	a8 01                	test   $0x1,%al
 11bdee2:	74 51                	je     11bdf35 <br.encodeCommandPlanWithOptionsWrite+0x24f5>
 11bdee4:	44 0f b6 6d d3       	movzbl -0x2d(%rbp),%r13d
 11bdee9:	41 83 e5 01          	and    $0x1,%r13d
 11bdeed:	49 83 f5 03          	xor    $0x3,%r13
 11bdef1:	eb 74                	jmp    11bdf67 <br.encodeCommandPlanWithOptionsWrite+0x2527>
 11bdef3:	f6 85 10 ff ff ff 01 	testb  $0x1,-0xf0(%rbp)
 11bdefa:	b0 01                	mov    $0x1,%al
 11bdefc:	48 89 85 10 ff ff ff 	mov    %rax,-0xf0(%rbp)
 11bdf03:	0f 85 96 00 00 00    	jne    11bdf9f <br.encodeCommandPlanWithOptionsWrite+0x255f>
 11bdf09:	48 8d bd 00 f0 ff ff 	lea    -0x1000(%rbp),%rdi
 11bdf10:	48 8d b5 10 eb ff ff 	lea    -0x14f0(%rbp),%rsi
 11bdf17:	c5 f8 77             	vzeroupper 
 11bdf1a:	e8 c1 98 ff ff       	call   11b77e0 <br.encoder.command_plan.alphabetFromFrequenciesInto__anon_30651>
 11bdf1f:	66 85 c0             	test   %ax,%ax
 11bdf22:	0f 85 85 db ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bdf28:	48 c7 85 10 ff ff ff 	movq   $0x0,-0xf0(%rbp)
 11bdf2f:	00 00 00 00 
 11bdf33:	eb 6a                	jmp    11bdf9f <br.encodeCommandPlanWithOptionsWrite+0x255f>
 11bdf35:	41 bd 06 00 00 00    	mov    $0x6,%r13d
 11bdf3b:	80 7d ce 00          	cmpb   $0x0,-0x32(%rbp)
 11bdf3f:	75 26                	jne    11bdf67 <br.encodeCommandPlanWithOptionsWrite+0x2527>
 11bdf41:	41 bd 05 00 00 00    	mov    $0x5,%r13d
 11bdf47:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 11bdf4b:	75 1a                	jne    11bdf67 <br.encodeCommandPlanWithOptionsWrite+0x2527>
 11bdf4d:	41 bd 04 00 00 00    	mov    $0x4,%r13d
 11bdf53:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 11bdf57:	75 0e                	jne    11bdf67 <br.encodeCommandPlanWithOptionsWrite+0x2527>
 11bdf59:	80 7d d5 01          	cmpb   $0x1,-0x2b(%rbp)
 11bdf5d:	41 bd 03 00 00 00    	mov    $0x3,%r13d
 11bdf63:	49 83 dd 00          	sbb    $0x0,%r13
 11bdf67:	4c 8d bd 90 9e ff ff 	lea    -0x6170(%rbp),%r15
 11bdf6e:	48 8d 9d 28 cb ff ff 	lea    -0x34d8(%rbp),%rbx
 11bdf75:	48 89 df             	mov    %rbx,%rdi
 11bdf78:	4c 89 fe             	mov    %r15,%rsi
 11bdf7b:	c5 f8 77             	vzeroupper 
 11bdf7e:	e8 5d 98 ff ff       	call   11b77e0 <br.encoder.command_plan.alphabetFromFrequenciesInto__anon_30651>
 11bdf83:	66 85 c0             	test   %ax,%ax
 11bdf86:	0f 85 21 db ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bdf8c:	49 81 c7 3c 01 00 00 	add    $0x13c,%r15
 11bdf93:	48 81 c3 a8 00 00 00 	add    $0xa8,%rbx
 11bdf9a:	49 ff cd             	dec    %r13
 11bdf9d:	75 d6                	jne    11bdf75 <br.encodeCommandPlanWithOptionsWrite+0x2535>
 11bdf9f:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 11bdfa3:	74 1b                	je     11bdfc0 <br.encodeCommandPlanWithOptionsWrite+0x2580>
 11bdfa5:	80 7d c0 00          	cmpb   $0x0,-0x40(%rbp)
 11bdfa9:	74 40                	je     11bdfeb <br.encodeCommandPlanWithOptionsWrite+0x25ab>
 11bdfab:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 11bdfb2:	48 89 c1             	mov    %rax,%rcx
 11bdfb5:	48 85 c0             	test   %rax,%rax
 11bdfb8:	0f 85 86 00 00 00    	jne    11be044 <br.encodeCommandPlanWithOptionsWrite+0x2604>
 11bdfbe:	eb 43                	jmp    11be003 <br.encodeCommandPlanWithOptionsWrite+0x25c3>
 11bdfc0:	45 84 e4             	test   %r12b,%r12b
 11bdfc3:	74 45                	je     11be00a <br.encodeCommandPlanWithOptionsWrite+0x25ca>
 11bdfc5:	48 8b 85 a0 fd ff ff 	mov    -0x260(%rbp),%rax
 11bdfcc:	0f b6 10             	movzbl (%rax),%edx
 11bdfcf:	83 e2 7f             	and    $0x7f,%edx
 11bdfd2:	74 2f                	je     11be003 <br.encodeCommandPlanWithOptionsWrite+0x25c3>
 11bdfd4:	89 d1                	mov    %edx,%ecx
 11bdfd6:	83 e1 07             	and    $0x7,%ecx
 11bdfd9:	80 fa 08             	cmp    $0x8,%dl
 11bdfdc:	0f 83 03 01 00 00    	jae    11be0e5 <br.encodeCommandPlanWithOptionsWrite+0x26a5>
 11bdfe2:	31 f6                	xor    %esi,%esi
 11bdfe4:	31 c0                	xor    %eax,%eax
 11bdfe6:	e9 4c 01 00 00       	jmp    11be137 <br.encodeCommandPlanWithOptionsWrite+0x26f7>
 11bdfeb:	0f b6 45 cc          	movzbl -0x34(%rbp),%eax
 11bdfef:	0a 45 c2             	or     -0x3e(%rbp),%al
 11bdff2:	a8 01                	test   $0x1,%al
 11bdff4:	74 20                	je     11be016 <br.encodeCommandPlanWithOptionsWrite+0x25d6>
 11bdff6:	0f b6 4d cc          	movzbl -0x34(%rbp),%ecx
 11bdffa:	83 e1 01             	and    $0x1,%ecx
 11bdffd:	48 83 f1 03          	xor    $0x3,%rcx
 11be001:	eb 41                	jmp    11be044 <br.encodeCommandPlanWithOptionsWrite+0x2604>
 11be003:	31 c0                	xor    %eax,%eax
 11be005:	e9 61 01 00 00       	jmp    11be16b <br.encodeCommandPlanWithOptionsWrite+0x272b>
 11be00a:	48 8b 85 b8 d5 ff ff 	mov    -0x2a48(%rbp),%rax
 11be011:	e9 55 01 00 00       	jmp    11be16b <br.encodeCommandPlanWithOptionsWrite+0x272b>
 11be016:	b9 06 00 00 00       	mov    $0x6,%ecx
 11be01b:	80 7d c7 00          	cmpb   $0x0,-0x39(%rbp)
 11be01f:	75 23                	jne    11be044 <br.encodeCommandPlanWithOptionsWrite+0x2604>
 11be021:	b9 05 00 00 00       	mov    $0x5,%ecx
 11be026:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 11be02a:	75 18                	jne    11be044 <br.encodeCommandPlanWithOptionsWrite+0x2604>
 11be02c:	b9 04 00 00 00       	mov    $0x4,%ecx
 11be031:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 11be035:	75 0d                	jne    11be044 <br.encodeCommandPlanWithOptionsWrite+0x2604>
 11be037:	80 7d c5 01          	cmpb   $0x1,-0x3b(%rbp)
 11be03b:	b9 03 00 00 00       	mov    $0x3,%ecx
 11be040:	48 83 d9 00          	sbb    $0x0,%rcx
 11be044:	89 ca                	mov    %ecx,%edx
 11be046:	83 e2 07             	and    $0x7,%edx
 11be049:	48 83 f9 08          	cmp    $0x8,%rcx
 11be04d:	73 06                	jae    11be055 <br.encodeCommandPlanWithOptionsWrite+0x2615>
 11be04f:	31 f6                	xor    %esi,%esi
 11be051:	31 c0                	xor    %eax,%eax
 11be053:	eb 53                	jmp    11be0a8 <br.encodeCommandPlanWithOptionsWrite+0x2668>
 11be055:	48 83 e1 f8          	and    $0xfffffffffffffff8,%rcx
 11be059:	48 8d bd 58 8c ff ff 	lea    -0x73a8(%rbp),%rdi
 11be060:	31 f6                	xor    %esi,%esi
 11be062:	31 c0                	xor    %eax,%eax
 11be064:	48 03 07             	add    (%rdi),%rax
 11be067:	48 03 87 08 02 00 00 	add    0x208(%rdi),%rax
 11be06e:	48 03 87 10 04 00 00 	add    0x410(%rdi),%rax
 11be075:	48 03 87 18 06 00 00 	add    0x618(%rdi),%rax
 11be07c:	48 03 87 20 08 00 00 	add    0x820(%rdi),%rax
 11be083:	48 03 87 28 0a 00 00 	add    0xa28(%rdi),%rax
 11be08a:	48 03 87 30 0c 00 00 	add    0xc30(%rdi),%rax
 11be091:	48 03 87 38 0e 00 00 	add    0xe38(%rdi),%rax
 11be098:	48 83 c6 08          	add    $0x8,%rsi
 11be09c:	48 81 c7 40 10 00 00 	add    $0x1040,%rdi
 11be0a3:	48 39 f1             	cmp    %rsi,%rcx
 11be0a6:	75 bc                	jne    11be064 <br.encodeCommandPlanWithOptionsWrite+0x2624>
 11be0a8:	48 85 d2             	test   %rdx,%rdx
 11be0ab:	0f 84 ba 00 00 00    	je     11be16b <br.encodeCommandPlanWithOptionsWrite+0x272b>
 11be0b1:	48 89 f1             	mov    %rsi,%rcx
 11be0b4:	48 c1 e1 09          	shl    $0x9,%rcx
 11be0b8:	48 8d 0c f1          	lea    (%rcx,%rsi,8),%rcx
 11be0bc:	48 01 e9             	add    %rbp,%rcx
 11be0bf:	48 81 c1 58 8c ff ff 	add    $0xffffffffffff8c58,%rcx
 11be0c6:	89 d6                	mov    %edx,%esi
 11be0c8:	c1 e6 09             	shl    $0x9,%esi
 11be0cb:	8d 14 d6             	lea    (%rsi,%rdx,8),%edx
 11be0ce:	31 f6                	xor    %esi,%esi
 11be0d0:	48 03 04 31          	add    (%rcx,%rsi,1),%rax
 11be0d4:	48 81 c6 08 02 00 00 	add    $0x208,%rsi
 11be0db:	48 39 f2             	cmp    %rsi,%rdx
 11be0de:	75 f0                	jne    11be0d0 <br.encodeCommandPlanWithOptionsWrite+0x2690>
 11be0e0:	e9 86 00 00 00       	jmp    11be16b <br.encodeCommandPlanWithOptionsWrite+0x272b>
 11be0e5:	83 e2 f8             	and    $0xfffffff8,%edx
 11be0e8:	48 8d bd 40 1d fd ff 	lea    -0x2e2c0(%rbp),%rdi
 11be0ef:	31 f6                	xor    %esi,%esi
 11be0f1:	31 c0                	xor    %eax,%eax
 11be0f3:	48 03 07             	add    (%rdi),%rax
 11be0f6:	48 03 87 08 02 00 00 	add    0x208(%rdi),%rax
 11be0fd:	48 03 87 10 04 00 00 	add    0x410(%rdi),%rax
 11be104:	48 03 87 18 06 00 00 	add    0x618(%rdi),%rax
 11be10b:	48 03 87 20 08 00 00 	add    0x820(%rdi),%rax
 11be112:	48 03 87 28 0a 00 00 	add    0xa28(%rdi),%rax
 11be119:	48 03 87 30 0c 00 00 	add    0xc30(%rdi),%rax
 11be120:	48 03 87 38 0e 00 00 	add    0xe38(%rdi),%rax
 11be127:	48 83 c6 08          	add    $0x8,%rsi
 11be12b:	48 81 c7 40 10 00 00 	add    $0x1040,%rdi
 11be132:	48 39 f2             	cmp    %rsi,%rdx
 11be135:	75 bc                	jne    11be0f3 <br.encodeCommandPlanWithOptionsWrite+0x26b3>
 11be137:	48 85 c9             	test   %rcx,%rcx
 11be13a:	74 2f                	je     11be16b <br.encodeCommandPlanWithOptionsWrite+0x272b>
 11be13c:	48 89 f2             	mov    %rsi,%rdx
 11be13f:	48 c1 e2 09          	shl    $0x9,%rdx
 11be143:	48 8d 14 f2          	lea    (%rdx,%rsi,8),%rdx
 11be147:	48 01 ea             	add    %rbp,%rdx
 11be14a:	48 81 c2 40 1d fd ff 	add    $0xfffffffffffd1d40,%rdx
 11be151:	89 ce                	mov    %ecx,%esi
 11be153:	c1 e6 09             	shl    $0x9,%esi
 11be156:	8d 0c ce             	lea    (%rsi,%rcx,8),%ecx
 11be159:	31 f6                	xor    %esi,%esi
 11be15b:	48 03 04 32          	add    (%rdx,%rsi,1),%rax
 11be15f:	48 81 c6 08 02 00 00 	add    $0x208,%rsi
 11be166:	48 39 f1             	cmp    %rsi,%rcx
 11be169:	75 f0                	jne    11be15b <br.encodeCommandPlanWithOptionsWrite+0x271b>
 11be16b:	48 8b 8d 58 fe ff ff 	mov    -0x1a8(%rbp),%rcx
 11be172:	48 89 41 18          	mov    %rax,0x18(%rcx)
 11be176:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 11be17a:	74 1c                	je     11be198 <br.encodeCommandPlanWithOptionsWrite+0x2758>
 11be17c:	80 7d c1 00          	cmpb   $0x0,-0x3f(%rbp)
 11be180:	74 22                	je     11be1a4 <br.encodeCommandPlanWithOptionsWrite+0x2764>
 11be182:	48 8b 8d 70 ff ff ff 	mov    -0x90(%rbp),%rcx
 11be189:	48 89 c8             	mov    %rcx,%rax
 11be18c:	48 85 c9             	test   %rcx,%rcx
 11be18f:	75 59                	jne    11be1ea <br.encodeCommandPlanWithOptionsWrite+0x27aa>
 11be191:	31 c9                	xor    %ecx,%ecx
 11be193:	e9 e4 00 00 00       	jmp    11be27c <br.encodeCommandPlanWithOptionsWrite+0x283c>
 11be198:	48 8b 8d a0 c5 ff ff 	mov    -0x3a60(%rbp),%rcx
 11be19f:	e9 d8 00 00 00       	jmp    11be27c <br.encodeCommandPlanWithOptionsWrite+0x283c>
 11be1a4:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 11be1a8:	0a 45 c8             	or     -0x38(%rbp),%al
 11be1ab:	a8 01                	test   $0x1,%al
 11be1ad:	74 0d                	je     11be1bc <br.encodeCommandPlanWithOptionsWrite+0x277c>
 11be1af:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 11be1b3:	83 e0 01             	and    $0x1,%eax
 11be1b6:	48 83 f0 03          	xor    $0x3,%rax
 11be1ba:	eb 2e                	jmp    11be1ea <br.encodeCommandPlanWithOptionsWrite+0x27aa>
 11be1bc:	b8 06 00 00 00       	mov    $0x6,%eax
 11be1c1:	80 7d cd 00          	cmpb   $0x0,-0x33(%rbp)
 11be1c5:	75 23                	jne    11be1ea <br.encodeCommandPlanWithOptionsWrite+0x27aa>
 11be1c7:	b8 05 00 00 00       	mov    $0x5,%eax
 11be1cc:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 11be1d0:	75 18                	jne    11be1ea <br.encodeCommandPlanWithOptionsWrite+0x27aa>
 11be1d2:	b8 04 00 00 00       	mov    $0x4,%eax
 11be1d7:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 11be1db:	75 0d                	jne    11be1ea <br.encodeCommandPlanWithOptionsWrite+0x27aa>
 11be1dd:	80 7d ca 01          	cmpb   $0x1,-0x36(%rbp)
 11be1e1:	b8 03 00 00 00       	mov    $0x3,%eax
 11be1e6:	48 83 d8 00          	sbb    $0x0,%rax
 11be1ea:	89 c2                	mov    %eax,%edx
 11be1ec:	83 e2 07             	and    $0x7,%edx
 11be1ef:	48 83 f8 08          	cmp    $0x8,%rax
 11be1f3:	73 06                	jae    11be1fb <br.encodeCommandPlanWithOptionsWrite+0x27bb>
 11be1f5:	31 f6                	xor    %esi,%esi
 11be1f7:	31 c9                	xor    %ecx,%ecx
 11be1f9:	eb 53                	jmp    11be24e <br.encodeCommandPlanWithOptionsWrite+0x280e>
 11be1fb:	48 83 e0 f8          	and    $0xfffffffffffffff8,%rax
 11be1ff:	48 8d bd d8 fc fe ff 	lea    -0x10328(%rbp),%rdi
 11be206:	31 f6                	xor    %esi,%esi
 11be208:	31 c9                	xor    %ecx,%ecx
 11be20a:	48 03 0f             	add    (%rdi),%rcx
 11be20d:	48 03 8f 88 05 00 00 	add    0x588(%rdi),%rcx
 11be214:	48 03 8f 10 0b 00 00 	add    0xb10(%rdi),%rcx
 11be21b:	48 03 8f 98 10 00 00 	add    0x1098(%rdi),%rcx
 11be222:	48 03 8f 20 16 00 00 	add    0x1620(%rdi),%rcx
 11be229:	48 03 8f a8 1b 00 00 	add    0x1ba8(%rdi),%rcx
 11be230:	48 03 8f 30 21 00 00 	add    0x2130(%rdi),%rcx
 11be237:	48 03 8f b8 26 00 00 	add    0x26b8(%rdi),%rcx
 11be23e:	48 83 c6 08          	add    $0x8,%rsi
 11be242:	48 81 c7 40 2c 00 00 	add    $0x2c40,%rdi
 11be249:	48 39 f0             	cmp    %rsi,%rax
 11be24c:	75 bc                	jne    11be20a <br.encodeCommandPlanWithOptionsWrite+0x27ca>
 11be24e:	48 85 d2             	test   %rdx,%rdx
 11be251:	74 29                	je     11be27c <br.encodeCommandPlanWithOptionsWrite+0x283c>
 11be253:	48 69 c6 88 05 00 00 	imul   $0x588,%rsi,%rax
 11be25a:	48 01 e8             	add    %rbp,%rax
 11be25d:	48 05 d8 fc fe ff    	add    $0xfffffffffffefcd8,%rax
 11be263:	48 69 d2 88 05 00 00 	imul   $0x588,%rdx,%rdx
 11be26a:	31 f6                	xor    %esi,%esi
 11be26c:	48 03 0c 30          	add    (%rax,%rsi,1),%rcx
 11be270:	48 81 c6 88 05 00 00 	add    $0x588,%rsi
 11be277:	48 39 f2             	cmp    %rsi,%rdx
 11be27a:	75 f0                	jne    11be26c <br.encodeCommandPlanWithOptionsWrite+0x282c>
 11be27c:	48 8b 85 58 fe ff ff 	mov    -0x1a8(%rbp),%rax
 11be283:	48 89 48 20          	mov    %rcx,0x20(%rax)
 11be287:	80 7d cb 00          	cmpb   $0x0,-0x35(%rbp)
 11be28b:	74 1c                	je     11be2a9 <br.encodeCommandPlanWithOptionsWrite+0x2869>
 11be28d:	80 7d c4 00          	cmpb   $0x0,-0x3c(%rbp)
 11be291:	74 22                	je     11be2b5 <br.encodeCommandPlanWithOptionsWrite+0x2875>
 11be293:	48 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%rcx
 11be29a:	48 89 c8             	mov    %rcx,%rax
 11be29d:	48 85 c9             	test   %rcx,%rcx
 11be2a0:	75 59                	jne    11be2fb <br.encodeCommandPlanWithOptionsWrite+0x28bb>
 11be2a2:	31 c9                	xor    %ecx,%ecx
 11be2a4:	e9 e4 00 00 00       	jmp    11be38d <br.encodeCommandPlanWithOptionsWrite+0x294d>
 11be2a9:	48 8b 8d 00 f0 ff ff 	mov    -0x1000(%rbp),%rcx
 11be2b0:	e9 d8 00 00 00       	jmp    11be38d <br.encodeCommandPlanWithOptionsWrite+0x294d>
 11be2b5:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 11be2b9:	0a 45 c9             	or     -0x37(%rbp),%al
 11be2bc:	a8 01                	test   $0x1,%al
 11be2be:	74 0d                	je     11be2cd <br.encodeCommandPlanWithOptionsWrite+0x288d>
 11be2c0:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 11be2c4:	83 e0 01             	and    $0x1,%eax
 11be2c7:	48 83 f0 03          	xor    $0x3,%rax
 11be2cb:	eb 2e                	jmp    11be2fb <br.encodeCommandPlanWithOptionsWrite+0x28bb>
 11be2cd:	b8 06 00 00 00       	mov    $0x6,%eax
 11be2d2:	80 7d ce 00          	cmpb   $0x0,-0x32(%rbp)
 11be2d6:	75 23                	jne    11be2fb <br.encodeCommandPlanWithOptionsWrite+0x28bb>
 11be2d8:	b8 05 00 00 00       	mov    $0x5,%eax
 11be2dd:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 11be2e1:	75 18                	jne    11be2fb <br.encodeCommandPlanWithOptionsWrite+0x28bb>
 11be2e3:	b8 04 00 00 00       	mov    $0x4,%eax
 11be2e8:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 11be2ec:	75 0d                	jne    11be2fb <br.encodeCommandPlanWithOptionsWrite+0x28bb>
 11be2ee:	80 7d d5 01          	cmpb   $0x1,-0x2b(%rbp)
 11be2f2:	b8 03 00 00 00       	mov    $0x3,%eax
 11be2f7:	48 83 d8 00          	sbb    $0x0,%rax
 11be2fb:	89 c2                	mov    %eax,%edx
 11be2fd:	83 e2 07             	and    $0x7,%edx
 11be300:	48 83 f8 08          	cmp    $0x8,%rax
 11be304:	73 06                	jae    11be30c <br.encodeCommandPlanWithOptionsWrite+0x28cc>
 11be306:	31 f6                	xor    %esi,%esi
 11be308:	31 c9                	xor    %ecx,%ecx
 11be30a:	eb 53                	jmp    11be35f <br.encodeCommandPlanWithOptionsWrite+0x291f>
 11be30c:	48 83 e0 f8          	and    $0xfffffffffffffff8,%rax
 11be310:	48 8d bd 28 cb ff ff 	lea    -0x34d8(%rbp),%rdi
 11be317:	31 f6                	xor    %esi,%esi
 11be319:	31 c9                	xor    %ecx,%ecx
 11be31b:	48 03 0f             	add    (%rdi),%rcx
 11be31e:	48 03 8f a8 00 00 00 	add    0xa8(%rdi),%rcx
 11be325:	48 03 8f 50 01 00 00 	add    0x150(%rdi),%rcx
 11be32c:	48 03 8f f8 01 00 00 	add    0x1f8(%rdi),%rcx
 11be333:	48 03 8f a0 02 00 00 	add    0x2a0(%rdi),%rcx
 11be33a:	48 03 8f 48 03 00 00 	add    0x348(%rdi),%rcx
 11be341:	48 03 8f f0 03 00 00 	add    0x3f0(%rdi),%rcx
 11be348:	48 03 8f 98 04 00 00 	add    0x498(%rdi),%rcx
 11be34f:	48 83 c6 08          	add    $0x8,%rsi
 11be353:	48 81 c7 40 05 00 00 	add    $0x540,%rdi
 11be35a:	48 39 f0             	cmp    %rsi,%rax
 11be35d:	75 bc                	jne    11be31b <br.encodeCommandPlanWithOptionsWrite+0x28db>
 11be35f:	48 85 d2             	test   %rdx,%rdx
 11be362:	74 29                	je     11be38d <br.encodeCommandPlanWithOptionsWrite+0x294d>
 11be364:	48 69 c6 a8 00 00 00 	imul   $0xa8,%rsi,%rax
 11be36b:	48 01 e8             	add    %rbp,%rax
 11be36e:	48 05 28 cb ff ff    	add    $0xffffffffffffcb28,%rax
 11be374:	48 69 d2 a8 00 00 00 	imul   $0xa8,%rdx,%rdx
 11be37b:	31 f6                	xor    %esi,%esi
 11be37d:	48 03 0c 30          	add    (%rax,%rsi,1),%rcx
 11be381:	48 81 c6 a8 00 00 00 	add    $0xa8,%rsi
 11be388:	48 39 f2             	cmp    %rsi,%rdx
 11be38b:	75 f0                	jne    11be37d <br.encodeCommandPlanWithOptionsWrite+0x293d>
 11be38d:	48 8b 85 58 fe ff ff 	mov    -0x1a8(%rbp),%rax
 11be394:	48 89 48 28          	mov    %rcx,0x28(%rax)
 11be398:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11be39c:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 11be3a0:	75 40                	jne    11be3e2 <br.encodeCommandPlanWithOptionsWrite+0x29a2>
 11be3a2:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11be3a6:	48 8b 38             	mov    (%rax),%rdi
 11be3a9:	4c 89 f0             	mov    %r14,%rax
 11be3ac:	48 c1 e8 03          	shr    $0x3,%rax
 11be3b0:	48 83 f8 41          	cmp    $0x41,%rax
 11be3b4:	b9 40 00 00 00       	mov    $0x40,%ecx
 11be3b9:	48 0f 43 c8          	cmovae %rax,%rcx
 11be3bd:	48 81 f9 00 10 00 00 	cmp    $0x1000,%rcx
 11be3c4:	ba 00 10 00 00       	mov    $0x1000,%edx
 11be3c9:	48 0f 42 d1          	cmovb  %rcx,%rdx
 11be3cd:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 11be3d1:	c5 f8 77             	vzeroupper 
 11be3d4:	e8 77 05 04 00       	call   11fe950 <array_list.Aligned(u8,null).ensureUnusedCapacity>
 11be3d9:	66 85 c0             	test   %ax,%ax
 11be3dc:	0f 85 cb d6 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11be3e2:	80 bd 58 ff ff ff 00 	cmpb   $0x0,-0xa8(%rbp)
 11be3e9:	0f b6 45 88          	movzbl -0x78(%rbp),%eax
 11be3ed:	89 85 68 fd ff ff    	mov    %eax,-0x298(%rbp)
 11be3f3:	74 55                	je     11be44a <br.encodeCommandPlanWithOptionsWrite+0x2a0a>
 11be3f5:	0f b6 8d 52 ff ff ff 	movzbl -0xae(%rbp),%ecx
 11be3fc:	48 8b 7d a0          	mov    -0x60(%rbp),%rdi
 11be400:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 11be404:	8b 95 68 fd ff ff    	mov    -0x298(%rbp),%edx
 11be40a:	c5 f8 77             	vzeroupper 
 11be40d:	e8 8e fd 03 00       	call   11fe1a0 <br.writePlannedWindowBits>
 11be412:	66 85 c0             	test   %ax,%ax
 11be415:	0f 85 92 d6 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11be41b:	48 83 bd 70 fd ff ff 	cmpq   $0x0,-0x290(%rbp)
 11be422:	00 
 11be423:	74 33                	je     11be458 <br.encodeCommandPlanWithOptionsWrite+0x2a18>
 11be425:	48 8b 7d a0          	mov    -0x60(%rbp),%rdi
 11be429:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 11be42d:	48 8b 95 e8 fd ff ff 	mov    -0x218(%rbp),%rdx
 11be434:	48 8b 8d 70 fd ff ff 	mov    -0x290(%rbp),%rcx
 11be43b:	e8 60 f9 03 00       	call   11fdda0 <br.writeMetadataMetaBlock>
 11be440:	66 85 c0             	test   %ax,%ax
 11be443:	74 13                	je     11be458 <br.encodeCommandPlanWithOptionsWrite+0x2a18>
 11be445:	e9 63 d6 ff ff       	jmp    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11be44a:	48 83 bd 70 fd ff ff 	cmpq   $0x0,-0x290(%rbp)
 11be451:	00 
 11be452:	0f 85 07 de ff ff    	jne    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11be458:	0f b6 4d 9b          	movzbl -0x65(%rbp),%ecx
 11be45c:	48 8b 7d a0          	mov    -0x60(%rbp),%rdi
 11be460:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 11be464:	4c 89 f2             	mov    %r14,%rdx
 11be467:	c5 f8 77             	vzeroupper 
 11be46a:	e8 71 f6 03 00       	call   11fdae0 <br.writeCompressedMetaBlockHeader>
 11be46f:	66 85 c0             	test   %ax,%ax
 11be472:	0f 85 35 d6 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11be478:	b8 d0 c9 03 01       	mov    $0x103c9d0,%eax
 11be47d:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 11be481:	0f 85 b8 00 00 00    	jne    11be53f <br.encodeCommandPlanWithOptionsWrite+0x2aff>
 11be487:	0f b6 8d 56 ff ff ff 	movzbl -0xaa(%rbp),%ecx
 11be48e:	48 8d bd fe de ff ff 	lea    -0x2102(%rbp),%rdi
 11be495:	48 8d b5 a0 c0 ff ff 	lea    -0x3f60(%rbp),%rsi
 11be49c:	48 8d 95 b8 d5 ff ff 	lea    -0x2a48(%rbp),%rdx
 11be4a3:	e8 78 e6 03 00       	call   11fcb20 <br.chooseLiteralTreeLengths>
 11be4a8:	0f b7 85 fe de ff ff 	movzwl -0x2102(%rbp),%eax
 11be4af:	66 85 c0             	test   %ax,%ax
 11be4b2:	0f 85 f5 d5 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11be4b8:	c5 fc 10 85 e0 df ff 	vmovups -0x2020(%rbp),%ymm0
 11be4bf:	ff 
 11be4c0:	c5 fc 11 85 a0 d8 ff 	vmovups %ymm0,-0x2760(%rbp)
 11be4c7:	ff 
 11be4c8:	c5 fc 10 85 c0 df ff 	vmovups -0x2040(%rbp),%ymm0
 11be4cf:	ff 
 11be4d0:	c5 fc 11 85 80 d8 ff 	vmovups %ymm0,-0x2780(%rbp)
 11be4d7:	ff 
 11be4d8:	c5 fc 10 85 a0 df ff 	vmovups -0x2060(%rbp),%ymm0
 11be4df:	ff 
 11be4e0:	c5 fc 11 85 60 d8 ff 	vmovups %ymm0,-0x27a0(%rbp)
 11be4e7:	ff 
 11be4e8:	c5 fc 10 85 80 df ff 	vmovups -0x2080(%rbp),%ymm0
 11be4ef:	ff 
 11be4f0:	c5 fc 11 85 40 d8 ff 	vmovups %ymm0,-0x27c0(%rbp)
 11be4f7:	ff 
 11be4f8:	c5 fc 10 85 00 df ff 	vmovups -0x2100(%rbp),%ymm0
 11be4ff:	ff 
 11be500:	c5 fc 10 8d 40 df ff 	vmovups -0x20c0(%rbp),%ymm1
 11be507:	ff 
 11be508:	c5 fc 10 95 60 df ff 	vmovups -0x20a0(%rbp),%ymm2
 11be50f:	ff 
 11be510:	c5 fc 11 95 20 d8 ff 	vmovups %ymm2,-0x27e0(%rbp)
 11be517:	ff 
 11be518:	c5 fc 11 8d 00 d8 ff 	vmovups %ymm1,-0x2800(%rbp)
 11be51f:	ff 
 11be520:	c5 fc 10 8d 20 df ff 	vmovups -0x20e0(%rbp),%ymm1
 11be527:	ff 
 11be528:	c5 fc 11 8d e0 d7 ff 	vmovups %ymm1,-0x2820(%rbp)
 11be52f:	ff 
 11be530:	c5 fc 11 85 c0 d7 ff 	vmovups %ymm0,-0x2840(%rbp)
 11be537:	ff 
 11be538:	48 8d 85 c0 d7 ff ff 	lea    -0x2840(%rbp),%rax
 11be53f:	c5 fc 10 80 e0 00 00 	vmovups 0xe0(%rax),%ymm0
 11be546:	00 
 11be547:	c5 fc 11 85 d0 e6 ff 	vmovups %ymm0,-0x1930(%rbp)
 11be54e:	ff 
 11be54f:	c5 fc 10 80 c0 00 00 	vmovups 0xc0(%rax),%ymm0
 11be556:	00 
 11be557:	c5 fc 11 85 b0 e6 ff 	vmovups %ymm0,-0x1950(%rbp)
 11be55e:	ff 
 11be55f:	c5 fc 10 80 a0 00 00 	vmovups 0xa0(%rax),%ymm0
 11be566:	00 
 11be567:	c5 fc 11 85 90 e6 ff 	vmovups %ymm0,-0x1970(%rbp)
 11be56e:	ff 
 11be56f:	c5 fc 10 80 80 00 00 	vmovups 0x80(%rax),%ymm0
 11be576:	00 
 11be577:	c5 fc 11 85 70 e6 ff 	vmovups %ymm0,-0x1990(%rbp)
 11be57e:	ff 
 11be57f:	c5 fc 10 00          	vmovups (%rax),%ymm0
 11be583:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 11be588:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 11be58d:	c5 fc 10 58 60       	vmovups 0x60(%rax),%ymm3
 11be592:	c5 fc 11 9d 50 e6 ff 	vmovups %ymm3,-0x19b0(%rbp)
 11be599:	ff 
 11be59a:	c5 fc 11 95 30 e6 ff 	vmovups %ymm2,-0x19d0(%rbp)
 11be5a1:	ff 
 11be5a2:	c5 fc 11 8d 10 e6 ff 	vmovups %ymm1,-0x19f0(%rbp)
 11be5a9:	ff 
 11be5aa:	c5 fc 11 85 f0 e5 ff 	vmovups %ymm0,-0x1a10(%rbp)
 11be5b1:	ff 
 11be5b2:	48 8b 85 08 ff ff ff 	mov    -0xf8(%rbp),%rax
 11be5b9:	80 38 00             	cmpb   $0x0,(%rax)
 11be5bc:	0f 84 1f 01 00 00    	je     11be6e1 <br.encodeCommandPlanWithOptionsWrite+0x2ca1>
 11be5c2:	80 bd 00 fe ff ff 00 	cmpb   $0x0,-0x200(%rbp)
 11be5c9:	0f 84 f2 00 00 00    	je     11be6c1 <br.encodeCommandPlanWithOptionsWrite+0x2c81>
 11be5cf:	44 0f b6 ad 00 fe ff 	movzbl -0x200(%rbp),%r13d
 11be5d6:	ff 
 11be5d7:	4c 8d bd b8 d4 ff ff 	lea    -0x2b48(%rbp),%r15
 11be5de:	41 c1 e5 08          	shl    $0x8,%r13d
 11be5e2:	48 8d 9d 40 ba fb ff 	lea    -0x445c0(%rbp),%rbx
 11be5e9:	4c 8d b5 40 1d fd ff 	lea    -0x2e2c0(%rbp),%r14
 11be5f0:	45 31 e4             	xor    %r12d,%r12d
 11be5f3:	48 8d bd b6 d4 ff ff 	lea    -0x2b4a(%rbp),%rdi
 11be5fa:	4c 89 f6             	mov    %r14,%rsi
 11be5fd:	48 89 da             	mov    %rbx,%rdx
 11be600:	c5 f8 77             	vzeroupper 
 11be603:	e8 a8 92 ff ff       	call   11b78b0 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths>
 11be608:	0f b7 85 b6 d4 ff ff 	movzwl -0x2b4a(%rbp),%eax
 11be60f:	66 85 c0             	test   %ax,%ax
 11be612:	0f 85 95 d4 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11be618:	c4 c1 7c 10 87 e0 00 	vmovups 0xe0(%r15),%ymm0
 11be61f:	00 00 
 11be621:	c4 a1 7c 11 84 25 24 	vmovups %ymm0,-0x165dc(%rbp,%r12,1)
 11be628:	9a fe ff 
 11be62b:	c4 c1 7c 10 87 c0 00 	vmovups 0xc0(%r15),%ymm0
 11be632:	00 00 
 11be634:	c4 a1 7c 11 84 25 04 	vmovups %ymm0,-0x165fc(%rbp,%r12,1)
 11be63b:	9a fe ff 
 11be63e:	c4 c1 7c 10 87 a0 00 	vmovups 0xa0(%r15),%ymm0
 11be645:	00 00 
 11be647:	c4 a1 7c 11 84 25 e4 	vmovups %ymm0,-0x1661c(%rbp,%r12,1)
 11be64e:	99 fe ff 
 11be651:	c4 c1 7c 10 87 80 00 	vmovups 0x80(%r15),%ymm0
 11be658:	00 00 
 11be65a:	c4 a1 7c 11 84 25 c4 	vmovups %ymm0,-0x1663c(%rbp,%r12,1)
 11be661:	99 fe ff 
 11be664:	c4 c1 7c 10 07       	vmovups (%r15),%ymm0
 11be669:	c4 c1 7c 10 4f 20    	vmovups 0x20(%r15),%ymm1
 11be66f:	c4 c1 7c 10 57 40    	vmovups 0x40(%r15),%ymm2
 11be675:	c4 c1 7c 10 5f 60    	vmovups 0x60(%r15),%ymm3
 11be67b:	c4 a1 7c 11 9c 25 a4 	vmovups %ymm3,-0x1665c(%rbp,%r12,1)
 11be682:	99 fe ff 
 11be685:	c4 a1 7c 11 94 25 84 	vmovups %ymm2,-0x1667c(%rbp,%r12,1)
 11be68c:	99 fe ff 
 11be68f:	c4 a1 7c 11 8c 25 64 	vmovups %ymm1,-0x1669c(%rbp,%r12,1)
 11be696:	99 fe ff 
 11be699:	c4 a1 7c 11 84 25 44 	vmovups %ymm0,-0x166bc(%rbp,%r12,1)
 11be6a0:	99 fe ff 
 11be6a3:	49 81 c4 00 01 00 00 	add    $0x100,%r12
 11be6aa:	48 81 c3 00 04 00 00 	add    $0x400,%rbx
 11be6b1:	49 81 c6 08 02 00 00 	add    $0x208,%r14
 11be6b8:	4d 39 e5             	cmp    %r12,%r13
 11be6bb:	0f 85 32 ff ff ff    	jne    11be5f3 <br.encodeCommandPlanWithOptionsWrite+0x2bb3>
 11be6c1:	48 8d 9d c0 48 fb ff 	lea    -0x4b740(%rbp),%rbx
 11be6c8:	48 8d b5 44 99 fe ff 	lea    -0x166bc(%rbp),%rsi
 11be6cf:	ba 00 40 00 00       	mov    $0x4000,%edx
 11be6d4:	48 89 df             	mov    %rbx,%rdi
 11be6d7:	c5 f8 77             	vzeroupper 
 11be6da:	e8 81 10 12 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11be6df:	eb 05                	jmp    11be6e6 <br.encodeCommandPlanWithOptionsWrite+0x2ca6>
 11be6e1:	bb d0 ca 03 01       	mov    $0x103cad0,%ebx
 11be6e6:	48 8d bd c4 c1 fd ff 	lea    -0x23e3c(%rbp),%rdi
 11be6ed:	ba 00 40 00 00       	mov    $0x4000,%edx
 11be6f2:	48 89 de             	mov    %rbx,%rsi
 11be6f5:	c5 f8 77             	vzeroupper 
 11be6f8:	e8 63 10 12 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11be6fd:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 11be701:	74 1a                	je     11be71d <br.encodeCommandPlanWithOptionsWrite+0x2cdd>
 11be703:	80 7d c0 00          	cmpb   $0x0,-0x40(%rbp)
 11be707:	74 1e                	je     11be727 <br.encodeCommandPlanWithOptionsWrite+0x2ce7>
 11be709:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 11be710:	49 89 c4             	mov    %rax,%r12
 11be713:	48 85 c0             	test   %rax,%rax
 11be716:	75 5b                	jne    11be773 <br.encodeCommandPlanWithOptionsWrite+0x2d33>
 11be718:	e9 2c 01 00 00       	jmp    11be849 <br.encodeCommandPlanWithOptionsWrite+0x2e09>
 11be71d:	bb d0 0a 04 01       	mov    $0x1040ad0,%ebx
 11be722:	e9 40 01 00 00       	jmp    11be867 <br.encodeCommandPlanWithOptionsWrite+0x2e27>
 11be727:	0f b6 45 cc          	movzbl -0x34(%rbp),%eax
 11be72b:	0a 45 c2             	or     -0x3e(%rbp),%al
 11be72e:	a8 01                	test   $0x1,%al
 11be730:	74 0f                	je     11be741 <br.encodeCommandPlanWithOptionsWrite+0x2d01>
 11be732:	44 0f b6 65 cc       	movzbl -0x34(%rbp),%r12d
 11be737:	41 83 e4 01          	and    $0x1,%r12d
 11be73b:	49 83 f4 03          	xor    $0x3,%r12
 11be73f:	eb 32                	jmp    11be773 <br.encodeCommandPlanWithOptionsWrite+0x2d33>
 11be741:	41 bc 06 00 00 00    	mov    $0x6,%r12d
 11be747:	80 7d c7 00          	cmpb   $0x0,-0x39(%rbp)
 11be74b:	75 26                	jne    11be773 <br.encodeCommandPlanWithOptionsWrite+0x2d33>
 11be74d:	41 bc 05 00 00 00    	mov    $0x5,%r12d
 11be753:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 11be757:	75 1a                	jne    11be773 <br.encodeCommandPlanWithOptionsWrite+0x2d33>
 11be759:	41 bc 04 00 00 00    	mov    $0x4,%r12d
 11be75f:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 11be763:	75 0e                	jne    11be773 <br.encodeCommandPlanWithOptionsWrite+0x2d33>
 11be765:	80 7d c5 01          	cmpb   $0x1,-0x3b(%rbp)
 11be769:	41 bc 03 00 00 00    	mov    $0x3,%r12d
 11be76f:	49 83 dc 00          	sbb    $0x0,%r12
 11be773:	48 8d 9d d8 e4 fe ff 	lea    -0x11b28(%rbp),%rbx
 11be77a:	4c 8d b5 58 8c ff ff 	lea    -0x73a8(%rbp),%r14
 11be781:	4c 8d bd 88 2e ff ff 	lea    -0xd178(%rbp),%r15
 11be788:	4c 8d ad b6 d3 ff ff 	lea    -0x2c4a(%rbp),%r13
 11be78f:	48 8d bd b4 d3 ff ff 	lea    -0x2c4c(%rbp),%rdi
 11be796:	4c 89 f6             	mov    %r14,%rsi
 11be799:	48 89 da             	mov    %rbx,%rdx
 11be79c:	c5 f8 77             	vzeroupper 
 11be79f:	e8 0c 91 ff ff       	call   11b78b0 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths>
 11be7a4:	0f b7 85 b4 d3 ff ff 	movzwl -0x2c4c(%rbp),%eax
 11be7ab:	66 85 c0             	test   %ax,%ax
 11be7ae:	0f 85 f9 d2 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11be7b4:	c4 c1 7c 10 85 e0 00 	vmovups 0xe0(%r13),%ymm0
 11be7bb:	00 00 
 11be7bd:	c4 c1 7c 11 87 e0 00 	vmovups %ymm0,0xe0(%r15)
 11be7c4:	00 00 
 11be7c6:	c4 c1 7c 10 85 c0 00 	vmovups 0xc0(%r13),%ymm0
 11be7cd:	00 00 
 11be7cf:	c4 c1 7c 11 87 c0 00 	vmovups %ymm0,0xc0(%r15)
 11be7d6:	00 00 
 11be7d8:	c4 c1 7c 10 85 a0 00 	vmovups 0xa0(%r13),%ymm0
 11be7df:	00 00 
 11be7e1:	c4 c1 7c 11 87 a0 00 	vmovups %ymm0,0xa0(%r15)
 11be7e8:	00 00 
 11be7ea:	c4 c1 7c 10 85 80 00 	vmovups 0x80(%r13),%ymm0
 11be7f1:	00 00 
 11be7f3:	c4 c1 7c 11 87 80 00 	vmovups %ymm0,0x80(%r15)
 11be7fa:	00 00 
 11be7fc:	c4 c1 7c 10 45 00    	vmovups 0x0(%r13),%ymm0
 11be802:	c4 c1 7c 10 4d 20    	vmovups 0x20(%r13),%ymm1
 11be808:	c4 c1 7c 10 55 40    	vmovups 0x40(%r13),%ymm2
 11be80e:	c4 c1 7c 10 5d 60    	vmovups 0x60(%r13),%ymm3
 11be814:	c4 c1 7c 11 5f 60    	vmovups %ymm3,0x60(%r15)
 11be81a:	c4 c1 7c 11 57 40    	vmovups %ymm2,0x40(%r15)
 11be820:	c4 c1 7c 11 4f 20    	vmovups %ymm1,0x20(%r15)
 11be826:	c4 c1 7c 11 07       	vmovups %ymm0,(%r15)
 11be82b:	48 81 c3 00 04 00 00 	add    $0x400,%rbx
 11be832:	49 81 c6 08 02 00 00 	add    $0x208,%r14
 11be839:	49 81 c7 00 01 00 00 	add    $0x100,%r15
 11be840:	49 ff cc             	dec    %r12
 11be843:	0f 85 46 ff ff ff    	jne    11be78f <br.encodeCommandPlanWithOptionsWrite+0x2d4f>
 11be849:	48 8d 9d 44 d9 fe ff 	lea    -0x126bc(%rbp),%rbx
 11be850:	48 8d b5 88 2e ff ff 	lea    -0xd178(%rbp),%rsi
 11be857:	ba 00 06 00 00       	mov    $0x600,%edx
 11be85c:	48 89 df             	mov    %rbx,%rdi
 11be85f:	c5 f8 77             	vzeroupper 
 11be862:	e8 f9 0e 12 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11be867:	48 8d bd bc ab ff ff 	lea    -0x5444(%rbp),%rdi
 11be86e:	ba 00 06 00 00       	mov    $0x600,%edx
 11be873:	48 89 de             	mov    %rbx,%rsi
 11be876:	e8 e5 0e 12 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11be87b:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 11be87f:	74 39                	je     11be8ba <br.encodeCommandPlanWithOptionsWrite+0x2e7a>
 11be881:	80 7d c1 00          	cmpb   $0x0,-0x3f(%rbp)
 11be885:	74 4c                	je     11be8d3 <br.encodeCommandPlanWithOptionsWrite+0x2e93>
 11be887:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 11be88e:	49 89 c6             	mov    %rax,%r14
 11be891:	48 85 c0             	test   %rax,%rax
 11be894:	0f 85 e4 06 00 00    	jne    11bef7e <br.encodeCommandPlanWithOptionsWrite+0x353e>
 11be89a:	48 8d 9d 44 b1 fd ff 	lea    -0x24ebc(%rbp),%rbx
 11be8a1:	48 8d b5 c4 67 fe ff 	lea    -0x1983c(%rbp),%rsi
 11be8a8:	ba 80 10 00 00       	mov    $0x1080,%edx
 11be8ad:	48 89 df             	mov    %rbx,%rdi
 11be8b0:	e8 ab 0e 12 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11be8b5:	e9 a7 00 00 00       	jmp    11be961 <br.encodeCommandPlanWithOptionsWrite+0x2f21>
 11be8ba:	f6 85 10 ff ff ff 01 	testb  $0x1,-0xf0(%rbp)
 11be8c1:	74 31                	je     11be8f4 <br.encodeCommandPlanWithOptionsWrite+0x2eb4>
 11be8c3:	48 8d 9d 3a 72 ff ff 	lea    -0x8dc6(%rbp),%rbx
 11be8ca:	48 8d b5 fa a5 ff ff 	lea    -0x5a06(%rbp),%rsi
 11be8d1:	eb 68                	jmp    11be93b <br.encodeCommandPlanWithOptionsWrite+0x2efb>
 11be8d3:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 11be8d7:	0a 45 c8             	or     -0x38(%rbp),%al
 11be8da:	a8 01                	test   $0x1,%al
 11be8dc:	0f 84 6a 06 00 00    	je     11bef4c <br.encodeCommandPlanWithOptionsWrite+0x350c>
 11be8e2:	44 0f b6 75 d2       	movzbl -0x2e(%rbp),%r14d
 11be8e7:	41 83 e6 01          	and    $0x1,%r14d
 11be8eb:	49 83 f6 03          	xor    $0x3,%r14
 11be8ef:	e9 8a 06 00 00       	jmp    11bef7e <br.encodeCommandPlanWithOptionsWrite+0x353e>
 11be8f4:	bb 14 b4 03 01       	mov    $0x103b414,%ebx
 11be8f9:	48 83 bd a0 c5 ff ff 	cmpq   $0x5,-0x3a60(%rbp)
 11be900:	05 
 11be901:	72 45                	jb     11be948 <br.encodeCommandPlanWithOptionsWrite+0x2f08>
 11be903:	48 8d bd 58 b9 ff ff 	lea    -0x46a8(%rbp),%rdi
 11be90a:	48 8d b5 a0 c5 ff ff 	lea    -0x3a60(%rbp),%rsi
 11be911:	48 8d 95 7c 7f ff ff 	lea    -0x8084(%rbp),%rdx
 11be918:	e8 f3 98 ff ff       	call   11b8210 <br.encoder.command_plan.PrefixAlphabetFor(704).codeLengths>
 11be91d:	0f b7 85 58 b9 ff ff 	movzwl -0x46a8(%rbp),%eax
 11be924:	66 85 c0             	test   %ax,%ax
 11be927:	0f 85 80 d1 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11be92d:	48 8d b5 5a b9 ff ff 	lea    -0x46a6(%rbp),%rsi
 11be934:	48 8d 9d 7a 6f ff ff 	lea    -0x9086(%rbp),%rbx
 11be93b:	ba c0 02 00 00       	mov    $0x2c0,%edx
 11be940:	48 89 df             	mov    %rbx,%rdi
 11be943:	e8 18 0e 12 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11be948:	48 8d bd 1a cf ff ff 	lea    -0x30e6(%rbp),%rdi
 11be94f:	ba c0 02 00 00       	mov    $0x2c0,%edx
 11be954:	48 89 de             	mov    %rbx,%rsi
 11be957:	e8 04 0e 12 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11be95c:	bb d0 10 04 01       	mov    $0x10410d0,%ebx
 11be961:	48 8d bd 08 1e ff ff 	lea    -0xe1f8(%rbp),%rdi
 11be968:	ba 80 10 00 00       	mov    $0x1080,%edx
 11be96d:	48 89 bd 00 fe ff ff 	mov    %rdi,-0x200(%rbp)
 11be974:	48 89 de             	mov    %rbx,%rsi
 11be977:	e8 e4 0d 12 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11be97c:	80 7d cb 00          	cmpb   $0x0,-0x35(%rbp)
 11be980:	74 3c                	je     11be9be <br.encodeCommandPlanWithOptionsWrite+0x2f7e>
 11be982:	80 7d c4 00          	cmpb   $0x0,-0x3c(%rbp)
 11be986:	74 7b                	je     11bea03 <br.encodeCommandPlanWithOptionsWrite+0x2fc3>
 11be988:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 11be98f:	49 89 c4             	mov    %rax,%r12
 11be992:	48 85 c0             	test   %rax,%rax
 11be995:	0f 85 a5 06 00 00    	jne    11bf040 <br.encodeCommandPlanWithOptionsWrite+0x3600>
 11be99b:	48 8d 9d 7e 8a ff ff 	lea    -0x7582(%rbp),%rbx
 11be9a2:	48 8d b5 bc b4 ff ff 	lea    -0x4b44(%rbp),%rsi
 11be9a9:	ba da 01 00 00       	mov    $0x1da,%edx
 11be9ae:	48 89 df             	mov    %rbx,%rdi
 11be9b1:	c5 f8 77             	vzeroupper 
 11be9b4:	e8 a7 0d 12 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11be9b9:	e9 01 01 00 00       	jmp    11beabf <br.encodeCommandPlanWithOptionsWrite+0x307f>
 11be9be:	f6 85 10 ff ff ff 01 	testb  $0x1,-0xf0(%rbp)
 11be9c5:	74 5d                	je     11bea24 <br.encodeCommandPlanWithOptionsWrite+0x2fe4>
 11be9c7:	c5 fc 10 85 d1 e9 ff 	vmovups -0x162f(%rbp),%ymm0
 11be9ce:	ff 
 11be9cf:	c5 fc 10 8d 00 ea ff 	vmovups -0x1600(%rbp),%ymm1
 11be9d6:	ff 
 11be9d7:	c5 fc 11 8d ef ea ff 	vmovups %ymm1,-0x1511(%rbp)
 11be9de:	ff 
 11be9df:	c5 fc 10 8d f1 e9 ff 	vmovups -0x160f(%rbp),%ymm1
 11be9e6:	ff 
 11be9e7:	c5 fc 11 8d e0 ea ff 	vmovups %ymm1,-0x1520(%rbp)
 11be9ee:	ff 
 11be9ef:	c5 fc 11 85 c0 ea ff 	vmovups %ymm0,-0x1540(%rbp)
 11be9f6:	ff 
 11be9f7:	48 8d 85 c0 ea ff ff 	lea    -0x1540(%rbp),%rax
 11be9fe:	e9 91 00 00 00       	jmp    11bea94 <br.encodeCommandPlanWithOptionsWrite+0x3054>
 11bea03:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 11bea07:	0a 45 c9             	or     -0x37(%rbp),%al
 11bea0a:	a8 01                	test   $0x1,%al
 11bea0c:	0f 84 fc 05 00 00    	je     11bf00e <br.encodeCommandPlanWithOptionsWrite+0x35ce>
 11bea12:	44 0f b6 65 d3       	movzbl -0x2d(%rbp),%r12d
 11bea17:	41 83 e4 01          	and    $0x1,%r12d
 11bea1b:	49 83 f4 03          	xor    $0x3,%r12
 11bea1f:	e9 1c 06 00 00       	jmp    11bf040 <br.encodeCommandPlanWithOptionsWrite+0x3600>
 11bea24:	b8 26 b7 03 01       	mov    $0x103b726,%eax
 11bea29:	48 83 bd 00 f0 ff ff 	cmpq   $0x5,-0x1000(%rbp)
 11bea30:	05 
 11bea31:	72 61                	jb     11bea94 <br.encodeCommandPlanWithOptionsWrite+0x3054>
 11bea33:	48 8d bd ee ed ff ff 	lea    -0x1212(%rbp),%rdi
 11bea3a:	48 8d b5 00 f0 ff ff 	lea    -0x1000(%rbp),%rsi
 11bea41:	48 8d 95 10 eb ff ff 	lea    -0x14f0(%rbp),%rdx
 11bea48:	e8 43 a0 ff ff       	call   11b8a90 <br.encoder.command_plan.PrefixAlphabetFor(79).codeLengths>
 11bea4d:	0f b7 85 ee ed ff ff 	movzwl -0x1212(%rbp),%eax
 11bea54:	66 85 c0             	test   %ax,%ax
 11bea57:	0f 85 50 d0 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bea5d:	c5 fc 10 85 f0 ed ff 	vmovups -0x1210(%rbp),%ymm0
 11bea64:	ff 
 11bea65:	c5 fc 10 8d 1f ee ff 	vmovups -0x11e1(%rbp),%ymm1
 11bea6c:	ff 
 11bea6d:	c5 fc 11 8d 9f ea ff 	vmovups %ymm1,-0x1561(%rbp)
 11bea74:	ff 
 11bea75:	c5 fc 10 8d 10 ee ff 	vmovups -0x11f0(%rbp),%ymm1
 11bea7c:	ff 
 11bea7d:	c5 fc 11 8d 90 ea ff 	vmovups %ymm1,-0x1570(%rbp)
 11bea84:	ff 
 11bea85:	c5 fc 11 85 70 ea ff 	vmovups %ymm0,-0x1590(%rbp)
 11bea8c:	ff 
 11bea8d:	48 8d 85 70 ea ff ff 	lea    -0x1590(%rbp),%rax
 11bea94:	c5 fc 10 00          	vmovups (%rax),%ymm0
 11bea98:	c5 fc 10 48 2f       	vmovups 0x2f(%rax),%ymm1
 11bea9d:	c5 fc 11 8d 2f f2 ff 	vmovups %ymm1,-0xdd1(%rbp)
 11beaa4:	ff 
 11beaa5:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 11beaaa:	c5 fc 11 8d 20 f2 ff 	vmovups %ymm1,-0xde0(%rbp)
 11beab1:	ff 
 11beab2:	c5 fc 11 85 00 f2 ff 	vmovups %ymm0,-0xe00(%rbp)
 11beab9:	ff 
 11beaba:	bb 50 21 04 01       	mov    $0x1042150,%ebx
 11beabf:	48 8d bd da d1 ff ff 	lea    -0x2e26(%rbp),%rdi
 11beac6:	ba da 01 00 00       	mov    $0x1da,%edx
 11beacb:	48 89 bd 10 ff ff ff 	mov    %rdi,-0xf0(%rbp)
 11bead2:	48 89 de             	mov    %rbx,%rsi
 11bead5:	c5 f8 77             	vzeroupper 
 11bead8:	e8 83 0c 12 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11beadd:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 11beae1:	0f 84 da 01 00 00    	je     11becc1 <br.encodeCommandPlanWithOptionsWrite+0x3281>
 11beae7:	48 8b 85 18 ff ff ff 	mov    -0xe8(%rbp),%rax
 11beaee:	48 89 85 20 fb ff ff 	mov    %rax,-0x4e0(%rbp)
 11beaf5:	48 8b 85 00 ff ff ff 	mov    -0x100(%rbp),%rax
 11beafc:	48 89 85 28 fb ff ff 	mov    %rax,-0x4d8(%rbp)
 11beb03:	0f b6 45 c5          	movzbl -0x3b(%rbp),%eax
 11beb07:	88 85 30 fb ff ff    	mov    %al,-0x4d0(%rbp)
 11beb0d:	8b 85 08 fe ff ff    	mov    -0x1f8(%rbp),%eax
 11beb13:	8b 8d 0b fe ff ff    	mov    -0x1f5(%rbp),%ecx
 11beb19:	89 85 31 fb ff ff    	mov    %eax,-0x4cf(%rbp)
 11beb1f:	89 8d 34 fb ff ff    	mov    %ecx,-0x4cc(%rbp)
 11beb25:	48 8b 85 20 ff ff ff 	mov    -0xe0(%rbp),%rax
 11beb2c:	48 89 85 38 fb ff ff 	mov    %rax,-0x4c8(%rbp)
 11beb33:	0f b6 45 cf          	movzbl -0x31(%rbp),%eax
 11beb37:	88 85 40 fb ff ff    	mov    %al,-0x4c0(%rbp)
 11beb3d:	8b 85 10 fe ff ff    	mov    -0x1f0(%rbp),%eax
 11beb43:	8b 8d 13 fe ff ff    	mov    -0x1ed(%rbp),%ecx
 11beb49:	89 85 41 fb ff ff    	mov    %eax,-0x4bf(%rbp)
 11beb4f:	89 8d 44 fb ff ff    	mov    %ecx,-0x4bc(%rbp)
 11beb55:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 11beb5c:	48 89 85 48 fb ff ff 	mov    %rax,-0x4b8(%rbp)
 11beb63:	0f b6 45 d1          	movzbl -0x2f(%rbp),%eax
 11beb67:	88 85 50 fb ff ff    	mov    %al,-0x4b0(%rbp)
 11beb6d:	8b 85 18 fe ff ff    	mov    -0x1e8(%rbp),%eax
 11beb73:	8b 8d 1b fe ff ff    	mov    -0x1e5(%rbp),%ecx
 11beb79:	89 85 51 fb ff ff    	mov    %eax,-0x4af(%rbp)
 11beb7f:	89 8d 54 fb ff ff    	mov    %ecx,-0x4ac(%rbp)
 11beb85:	48 8b 85 30 ff ff ff 	mov    -0xd0(%rbp),%rax
 11beb8c:	48 89 85 58 fb ff ff 	mov    %rax,-0x4a8(%rbp)
 11beb93:	0f b6 45 c7          	movzbl -0x39(%rbp),%eax
 11beb97:	88 85 60 fb ff ff    	mov    %al,-0x4a0(%rbp)
 11beb9d:	8b 85 20 fe ff ff    	mov    -0x1e0(%rbp),%eax
 11beba3:	8b 8d 23 fe ff ff    	mov    -0x1dd(%rbp),%ecx
 11beba9:	89 85 61 fb ff ff    	mov    %eax,-0x49f(%rbp)
 11bebaf:	89 8d 64 fb ff ff    	mov    %ecx,-0x49c(%rbp)
 11bebb5:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 11bebbc:	48 89 85 68 fb ff ff 	mov    %rax,-0x498(%rbp)
 11bebc3:	0f b6 45 c0          	movzbl -0x40(%rbp),%eax
 11bebc7:	88 85 70 fb ff ff    	mov    %al,-0x490(%rbp)
 11bebcd:	8b 85 28 fe ff ff    	mov    -0x1d8(%rbp),%eax
 11bebd3:	8b 8d 2b fe ff ff    	mov    -0x1d5(%rbp),%ecx
 11bebd9:	89 85 71 fb ff ff    	mov    %eax,-0x48f(%rbp)
 11bebdf:	89 8d 74 fb ff ff    	mov    %ecx,-0x48c(%rbp)
 11bebe5:	48 8b 85 d8 fc ff ff 	mov    -0x328(%rbp),%rax
 11bebec:	48 89 85 78 fb ff ff 	mov    %rax,-0x488(%rbp)
 11bebf3:	0f b6 45 cc          	movzbl -0x34(%rbp),%eax
 11bebf7:	88 85 80 fb ff ff    	mov    %al,-0x480(%rbp)
 11bebfd:	0f b6 45 c2          	movzbl -0x3e(%rbp),%eax
 11bec01:	88 85 81 fb ff ff    	mov    %al,-0x47f(%rbp)
 11bec07:	0f b7 85 54 fe ff ff 	movzwl -0x1ac(%rbp),%eax
 11bec0e:	66 89 85 86 fb ff ff 	mov    %ax,-0x47a(%rbp)
 11bec15:	8b 85 50 fe ff ff    	mov    -0x1b0(%rbp),%eax
 11bec1b:	89 85 82 fb ff ff    	mov    %eax,-0x47e(%rbp)
 11bec21:	48 8d bd c0 e3 ff ff 	lea    -0x1c40(%rbp),%rdi
 11bec28:	48 8d b5 20 fb ff ff 	lea    -0x4e0(%rbp),%rsi
 11bec2f:	48 8b 55 80          	mov    -0x80(%rbp),%rdx
 11bec33:	e8 68 c9 03 00       	call   11fb5a0 <br.LiteralBlockLengthCode.init>
 11bec38:	0f b7 85 90 e4 ff ff 	movzwl -0x1b70(%rbp),%eax
 11bec3f:	66 85 c0             	test   %ax,%ax
 11bec42:	0f 85 65 ce ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bec48:	c5 fc 10 85 70 e4 ff 	vmovups -0x1b90(%rbp),%ymm0
 11bec4f:	ff 
 11bec50:	c5 fc 11 85 d0 de ff 	vmovups %ymm0,-0x2130(%rbp)
 11bec57:	ff 
 11bec58:	c5 fc 10 85 60 e4 ff 	vmovups -0x1ba0(%rbp),%ymm0
 11bec5f:	ff 
 11bec60:	c5 fc 11 85 c0 de ff 	vmovups %ymm0,-0x2140(%rbp)
 11bec67:	ff 
 11bec68:	c5 fc 10 85 40 e4 ff 	vmovups -0x1bc0(%rbp),%ymm0
 11bec6f:	ff 
 11bec70:	c5 fc 11 85 a0 de ff 	vmovups %ymm0,-0x2160(%rbp)
 11bec77:	ff 
 11bec78:	c5 fc 10 85 c0 e3 ff 	vmovups -0x1c40(%rbp),%ymm0
 11bec7f:	ff 
 11bec80:	c5 fc 10 8d 00 e4 ff 	vmovups -0x1c00(%rbp),%ymm1
 11bec87:	ff 
 11bec88:	c5 fc 10 95 20 e4 ff 	vmovups -0x1be0(%rbp),%ymm2
 11bec8f:	ff 
 11bec90:	c5 fc 11 95 80 de ff 	vmovups %ymm2,-0x2180(%rbp)
 11bec97:	ff 
 11bec98:	c5 fc 11 8d 60 de ff 	vmovups %ymm1,-0x21a0(%rbp)
 11bec9f:	ff 
 11beca0:	c5 fc 10 8d e0 e3 ff 	vmovups -0x1c20(%rbp),%ymm1
 11beca7:	ff 
 11beca8:	c5 fc 11 8d 40 de ff 	vmovups %ymm1,-0x21c0(%rbp)
 11becaf:	ff 
 11becb0:	c5 fc 11 85 20 de ff 	vmovups %ymm0,-0x21e0(%rbp)
 11becb7:	ff 
 11becb8:	48 8d 85 20 de ff ff 	lea    -0x21e0(%rbp),%rax
 11becbf:	eb 05                	jmp    11becc6 <br.encodeCommandPlanWithOptionsWrite+0x3286>
 11becc1:	b8 30 23 04 01       	mov    $0x1042330,%eax
 11becc6:	c5 fc 10 80 b0 00 00 	vmovups 0xb0(%rax),%ymm0
 11beccd:	00 
 11becce:	c5 fc 11 85 40 e9 ff 	vmovups %ymm0,-0x16c0(%rbp)
 11becd5:	ff 
 11becd6:	c5 fc 10 80 a0 00 00 	vmovups 0xa0(%rax),%ymm0
 11becdd:	00 
 11becde:	c5 fc 11 85 30 e9 ff 	vmovups %ymm0,-0x16d0(%rbp)
 11bece5:	ff 
 11bece6:	c5 fc 10 80 80 00 00 	vmovups 0x80(%rax),%ymm0
 11beced:	00 
 11becee:	c5 fc 11 85 10 e9 ff 	vmovups %ymm0,-0x16f0(%rbp)
 11becf5:	ff 
 11becf6:	c5 fc 10 00          	vmovups (%rax),%ymm0
 11becfa:	c5 fc 10 48 40       	vmovups 0x40(%rax),%ymm1
 11becff:	c5 fc 10 50 60       	vmovups 0x60(%rax),%ymm2
 11bed04:	c5 fc 11 95 f0 e8 ff 	vmovups %ymm2,-0x1710(%rbp)
 11bed0b:	ff 
 11bed0c:	c5 fc 11 8d d0 e8 ff 	vmovups %ymm1,-0x1730(%rbp)
 11bed13:	ff 
 11bed14:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 11bed19:	c5 fc 11 8d b0 e8 ff 	vmovups %ymm1,-0x1750(%rbp)
 11bed20:	ff 
 11bed21:	c5 fc 11 85 90 e8 ff 	vmovups %ymm0,-0x1770(%rbp)
 11bed28:	ff 
 11bed29:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 11bed2d:	0f 84 ed 01 00 00    	je     11bef20 <br.encodeCommandPlanWithOptionsWrite+0x34e0>
 11bed33:	48 8b 85 38 fe ff ff 	mov    -0x1c8(%rbp),%rax
 11bed3a:	48 89 85 b8 fa ff ff 	mov    %rax,-0x548(%rbp)
 11bed41:	48 8b 85 c0 fd ff ff 	mov    -0x240(%rbp),%rax
 11bed48:	48 89 85 c0 fa ff ff 	mov    %rax,-0x540(%rbp)
 11bed4f:	0f b6 45 ca          	movzbl -0x36(%rbp),%eax
 11bed53:	88 85 c8 fa ff ff    	mov    %al,-0x538(%rbp)
 11bed59:	8b 85 88 fe ff ff    	mov    -0x178(%rbp),%eax
 11bed5f:	8b 8d 8b fe ff ff    	mov    -0x175(%rbp),%ecx
 11bed65:	89 85 c9 fa ff ff    	mov    %eax,-0x537(%rbp)
 11bed6b:	89 8d cc fa ff ff    	mov    %ecx,-0x534(%rbp)
 11bed71:	48 8b 85 c8 fd ff ff 	mov    -0x238(%rbp),%rax
 11bed78:	48 89 85 d0 fa ff ff 	mov    %rax,-0x530(%rbp)
 11bed7f:	0f b6 45 d0          	movzbl -0x30(%rbp),%eax
 11bed83:	88 85 d8 fa ff ff    	mov    %al,-0x528(%rbp)
 11bed89:	8b 85 90 fe ff ff    	mov    -0x170(%rbp),%eax
 11bed8f:	8b 8d 93 fe ff ff    	mov    -0x16d(%rbp),%ecx
 11bed95:	89 85 d9 fa ff ff    	mov    %eax,-0x527(%rbp)
 11bed9b:	89 8d dc fa ff ff    	mov    %ecx,-0x524(%rbp)
 11beda1:	48 8b 85 d0 fd ff ff 	mov    -0x230(%rbp),%rax
 11beda8:	48 89 85 e0 fa ff ff 	mov    %rax,-0x520(%rbp)
 11bedaf:	0f b6 45 d6          	movzbl -0x2a(%rbp),%eax
 11bedb3:	88 85 e8 fa ff ff    	mov    %al,-0x518(%rbp)
 11bedb9:	8b 85 98 fe ff ff    	mov    -0x168(%rbp),%eax
 11bedbf:	8b 8d 9b fe ff ff    	mov    -0x165(%rbp),%ecx
 11bedc5:	89 85 e9 fa ff ff    	mov    %eax,-0x517(%rbp)
 11bedcb:	89 8d ec fa ff ff    	mov    %ecx,-0x514(%rbp)
 11bedd1:	48 8b 85 d8 fd ff ff 	mov    -0x228(%rbp),%rax
 11bedd8:	48 89 85 f0 fa ff ff 	mov    %rax,-0x510(%rbp)
 11beddf:	0f b6 45 cd          	movzbl -0x33(%rbp),%eax
 11bede3:	88 85 f8 fa ff ff    	mov    %al,-0x508(%rbp)
 11bede9:	8b 85 a0 fe ff ff    	mov    -0x160(%rbp),%eax
 11bedef:	8b 8d a3 fe ff ff    	mov    -0x15d(%rbp),%ecx
 11bedf5:	89 85 f9 fa ff ff    	mov    %eax,-0x507(%rbp)
 11bedfb:	89 8d fc fa ff ff    	mov    %ecx,-0x504(%rbp)
 11bee01:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 11bee08:	48 89 85 00 fb ff ff 	mov    %rax,-0x500(%rbp)
 11bee0f:	0f b6 45 c1          	movzbl -0x3f(%rbp),%eax
 11bee13:	88 85 08 fb ff ff    	mov    %al,-0x4f8(%rbp)
 11bee19:	8b 85 a8 fe ff ff    	mov    -0x158(%rbp),%eax
 11bee1f:	8b 8d ab fe ff ff    	mov    -0x155(%rbp),%ecx
 11bee25:	89 85 09 fb ff ff    	mov    %eax,-0x4f7(%rbp)
 11bee2b:	89 8d 0c fb ff ff    	mov    %ecx,-0x4f4(%rbp)
 11bee31:	48 8b 85 f8 fc ff ff 	mov    -0x308(%rbp),%rax
 11bee38:	48 89 85 10 fb ff ff 	mov    %rax,-0x4f0(%rbp)
 11bee3f:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 11bee43:	88 85 18 fb ff ff    	mov    %al,-0x4e8(%rbp)
 11bee49:	0f b6 45 c8          	movzbl -0x38(%rbp),%eax
 11bee4d:	88 85 19 fb ff ff    	mov    %al,-0x4e7(%rbp)
 11bee53:	0f b7 85 f0 fe ff ff 	movzwl -0x110(%rbp),%eax
 11bee5a:	66 89 85 1e fb ff ff 	mov    %ax,-0x4e2(%rbp)
 11bee61:	8b 85 ec fe ff ff    	mov    -0x114(%rbp),%eax
 11bee67:	89 85 1a fb ff ff    	mov    %eax,-0x4e6(%rbp)
 11bee6d:	48 8d bd c0 e7 ff ff 	lea    -0x1840(%rbp),%rdi
 11bee74:	48 8d b5 b8 fa ff ff 	lea    -0x548(%rbp),%rsi
 11bee7b:	48 8b 95 40 ff ff ff 	mov    -0xc0(%rbp),%rdx
 11bee82:	c5 f8 77             	vzeroupper 
 11bee85:	e8 a6 3f 03 00       	call   11f2e30 <br.CommandBlockLengthCode.init>
 11bee8a:	0f b7 85 88 e8 ff ff 	movzwl -0x1778(%rbp),%eax
 11bee91:	66 85 c0             	test   %ax,%ax
 11bee94:	0f 85 13 cc ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bee9a:	48 8b 85 80 e8 ff ff 	mov    -0x1780(%rbp),%rax
 11beea1:	48 89 85 e0 ed ff ff 	mov    %rax,-0x1220(%rbp)
 11beea8:	c5 fc 10 85 60 e8 ff 	vmovups -0x17a0(%rbp),%ymm0
 11beeaf:	ff 
 11beeb0:	c5 fc 11 85 c0 ed ff 	vmovups %ymm0,-0x1240(%rbp)
 11beeb7:	ff 
 11beeb8:	c5 fc 10 85 40 e8 ff 	vmovups -0x17c0(%rbp),%ymm0
 11beebf:	ff 
 11beec0:	c5 fc 11 85 a0 ed ff 	vmovups %ymm0,-0x1260(%rbp)
 11beec7:	ff 
 11beec8:	c5 fc 10 85 e0 e7 ff 	vmovups -0x1820(%rbp),%ymm0
 11beecf:	ff 
 11beed0:	c5 fc 10 8d 00 e8 ff 	vmovups -0x1800(%rbp),%ymm1
 11beed7:	ff 
 11beed8:	c5 fc 10 95 20 e8 ff 	vmovups -0x17e0(%rbp),%ymm2
 11beedf:	ff 
 11beee0:	c5 fc 11 95 80 ed ff 	vmovups %ymm2,-0x1280(%rbp)
 11beee7:	ff 
 11beee8:	c5 fc 11 8d 60 ed ff 	vmovups %ymm1,-0x12a0(%rbp)
 11beeef:	ff 
 11beef0:	c5 fc 11 85 40 ed ff 	vmovups %ymm0,-0x12c0(%rbp)
 11beef7:	ff 
 11beef8:	c5 fc 10 85 c0 e7 ff 	vmovups -0x1840(%rbp),%ymm0
 11beeff:	ff 
 11bef00:	c5 fc 11 85 20 ed ff 	vmovups %ymm0,-0x12e0(%rbp)
 11bef07:	ff 
 11bef08:	c6 45 b0 00          	movb   $0x0,-0x50(%rbp)
 11bef0c:	b3 01                	mov    $0x1,%bl
 11bef0e:	80 7d c1 00          	cmpb   $0x0,-0x3f(%rbp)
 11bef12:	74 17                	je     11bef2b <br.encodeCommandPlanWithOptionsWrite+0x34eb>
 11bef14:	4c 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%r14
 11bef1b:	e9 10 02 00 00       	jmp    11bf130 <br.encodeCommandPlanWithOptionsWrite+0x36f0>
 11bef20:	c6 45 b0 00          	movb   $0x0,-0x50(%rbp)
 11bef24:	31 db                	xor    %ebx,%ebx
 11bef26:	e9 05 02 00 00       	jmp    11bf130 <br.encodeCommandPlanWithOptionsWrite+0x36f0>
 11bef2b:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 11bef2f:	0a 45 c8             	or     -0x38(%rbp),%al
 11bef32:	a8 01                	test   $0x1,%al
 11bef34:	0f 84 c4 01 00 00    	je     11bf0fe <br.encodeCommandPlanWithOptionsWrite+0x36be>
 11bef3a:	44 0f b6 75 d2       	movzbl -0x2e(%rbp),%r14d
 11bef3f:	41 83 e6 01          	and    $0x1,%r14d
 11bef43:	49 83 f6 03          	xor    $0x3,%r14
 11bef47:	e9 e4 01 00 00       	jmp    11bf130 <br.encodeCommandPlanWithOptionsWrite+0x36f0>
 11bef4c:	41 be 06 00 00 00    	mov    $0x6,%r14d
 11bef52:	80 7d cd 00          	cmpb   $0x0,-0x33(%rbp)
 11bef56:	75 26                	jne    11bef7e <br.encodeCommandPlanWithOptionsWrite+0x353e>
 11bef58:	41 be 05 00 00 00    	mov    $0x5,%r14d
 11bef5e:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 11bef62:	75 1a                	jne    11bef7e <br.encodeCommandPlanWithOptionsWrite+0x353e>
 11bef64:	41 be 04 00 00 00    	mov    $0x4,%r14d
 11bef6a:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 11bef6e:	75 0e                	jne    11bef7e <br.encodeCommandPlanWithOptionsWrite+0x353e>
 11bef70:	80 7d ca 01          	cmpb   $0x1,-0x36(%rbp)
 11bef74:	41 be 03 00 00 00    	mov    $0x3,%r14d
 11bef7a:	49 83 de 00          	sbb    $0x0,%r14
 11bef7e:	4c 8d bd c4 01 fe ff 	lea    -0x1fe3c(%rbp),%r15
 11bef85:	4c 8d a5 d8 fc fe ff 	lea    -0x10328(%rbp),%r12
 11bef8c:	48 8d 9d c4 67 fe ff 	lea    -0x1983c(%rbp),%rbx
 11bef93:	eb 2b                	jmp    11befc0 <br.encodeCommandPlanWithOptionsWrite+0x3580>
 11bef95:	ba c0 02 00 00       	mov    $0x2c0,%edx
 11bef9a:	48 89 df             	mov    %rbx,%rdi
 11bef9d:	e8 be 07 12 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11befa2:	49 81 c7 00 0b 00 00 	add    $0xb00,%r15
 11befa9:	49 81 c4 88 05 00 00 	add    $0x588,%r12
 11befb0:	48 81 c3 c0 02 00 00 	add    $0x2c0,%rbx
 11befb7:	49 ff ce             	dec    %r14
 11befba:	0f 84 da f8 ff ff    	je     11be89a <br.encodeCommandPlanWithOptionsWrite+0x2e5a>
 11befc0:	be 14 b4 03 01       	mov    $0x103b414,%esi
 11befc5:	49 83 3c 24 05       	cmpq   $0x5,(%r12)
 11befca:	72 c9                	jb     11bef95 <br.encodeCommandPlanWithOptionsWrite+0x3555>
 11befcc:	48 8d bd 96 b6 ff ff 	lea    -0x496a(%rbp),%rdi
 11befd3:	4c 89 e6             	mov    %r12,%rsi
 11befd6:	4c 89 fa             	mov    %r15,%rdx
 11befd9:	e8 32 92 ff ff       	call   11b8210 <br.encoder.command_plan.PrefixAlphabetFor(704).codeLengths>
 11befde:	0f b7 85 96 b6 ff ff 	movzwl -0x496a(%rbp),%eax
 11befe5:	66 85 c0             	test   %ax,%ax
 11befe8:	0f 85 bf ca ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11befee:	ba c0 02 00 00       	mov    $0x2c0,%edx
 11beff3:	4c 8d ad ba 6c ff ff 	lea    -0x9346(%rbp),%r13
 11beffa:	4c 89 ef             	mov    %r13,%rdi
 11beffd:	48 8d b5 98 b6 ff ff 	lea    -0x4968(%rbp),%rsi
 11bf004:	e8 57 07 12 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11bf009:	4c 89 ee             	mov    %r13,%rsi
 11bf00c:	eb 87                	jmp    11bef95 <br.encodeCommandPlanWithOptionsWrite+0x3555>
 11bf00e:	41 bc 06 00 00 00    	mov    $0x6,%r12d
 11bf014:	80 7d ce 00          	cmpb   $0x0,-0x32(%rbp)
 11bf018:	75 26                	jne    11bf040 <br.encodeCommandPlanWithOptionsWrite+0x3600>
 11bf01a:	41 bc 05 00 00 00    	mov    $0x5,%r12d
 11bf020:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 11bf024:	75 1a                	jne    11bf040 <br.encodeCommandPlanWithOptionsWrite+0x3600>
 11bf026:	41 bc 04 00 00 00    	mov    $0x4,%r12d
 11bf02c:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 11bf030:	75 0e                	jne    11bf040 <br.encodeCommandPlanWithOptionsWrite+0x3600>
 11bf032:	80 7d d5 01          	cmpb   $0x1,-0x2b(%rbp)
 11bf036:	41 bc 03 00 00 00    	mov    $0x3,%r12d
 11bf03c:	49 83 dc 00          	sbb    $0x0,%r12
 11bf040:	48 8d 9d 90 9e ff ff 	lea    -0x6170(%rbp),%rbx
 11bf047:	4c 8d bd 28 cb ff ff 	lea    -0x34d8(%rbp),%r15
 11bf04e:	4c 8d b5 bc b4 ff ff 	lea    -0x4b44(%rbp),%r14
 11bf055:	4c 8d ad d0 d8 ff ff 	lea    -0x2730(%rbp),%r13
 11bf05c:	eb 3a                	jmp    11bf098 <br.encodeCommandPlanWithOptionsWrite+0x3658>
 11bf05e:	c5 fc 10 00          	vmovups (%rax),%ymm0
 11bf062:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 11bf067:	c5 fc 10 50 2f       	vmovups 0x2f(%rax),%ymm2
 11bf06c:	c4 c1 7c 11 56 2f    	vmovups %ymm2,0x2f(%r14)
 11bf072:	c4 c1 7c 11 4e 20    	vmovups %ymm1,0x20(%r14)
 11bf078:	c4 c1 7c 11 06       	vmovups %ymm0,(%r14)
 11bf07d:	48 81 c3 3c 01 00 00 	add    $0x13c,%rbx
 11bf084:	49 81 c7 a8 00 00 00 	add    $0xa8,%r15
 11bf08b:	49 83 c6 4f          	add    $0x4f,%r14
 11bf08f:	49 ff cc             	dec    %r12
 11bf092:	0f 84 03 f9 ff ff    	je     11be99b <br.encodeCommandPlanWithOptionsWrite+0x2f5b>
 11bf098:	b8 26 b7 03 01       	mov    $0x103b726,%eax
 11bf09d:	49 83 3f 05          	cmpq   $0x5,(%r15)
 11bf0a1:	72 bb                	jb     11bf05e <br.encodeCommandPlanWithOptionsWrite+0x361e>
 11bf0a3:	48 8d bd ce d8 ff ff 	lea    -0x2732(%rbp),%rdi
 11bf0aa:	4c 89 fe             	mov    %r15,%rsi
 11bf0ad:	48 89 da             	mov    %rbx,%rdx
 11bf0b0:	c5 f8 77             	vzeroupper 
 11bf0b3:	e8 d8 99 ff ff       	call   11b8a90 <br.encoder.command_plan.PrefixAlphabetFor(79).codeLengths>
 11bf0b8:	0f b7 85 ce d8 ff ff 	movzwl -0x2732(%rbp),%eax
 11bf0bf:	66 85 c0             	test   %ax,%ax
 11bf0c2:	0f 85 e5 c9 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bf0c8:	c4 c1 7c 10 45 00    	vmovups 0x0(%r13),%ymm0
 11bf0ce:	c4 c1 7c 10 4d 20    	vmovups 0x20(%r13),%ymm1
 11bf0d4:	c4 c1 7c 10 55 2f    	vmovups 0x2f(%r13),%ymm2
 11bf0da:	c5 fc 11 95 4f ea ff 	vmovups %ymm2,-0x15b1(%rbp)
 11bf0e1:	ff 
 11bf0e2:	c5 fc 11 8d 40 ea ff 	vmovups %ymm1,-0x15c0(%rbp)
 11bf0e9:	ff 
 11bf0ea:	c5 fc 11 85 20 ea ff 	vmovups %ymm0,-0x15e0(%rbp)
 11bf0f1:	ff 
 11bf0f2:	48 8d 85 20 ea ff ff 	lea    -0x15e0(%rbp),%rax
 11bf0f9:	e9 60 ff ff ff       	jmp    11bf05e <br.encodeCommandPlanWithOptionsWrite+0x361e>
 11bf0fe:	41 be 06 00 00 00    	mov    $0x6,%r14d
 11bf104:	80 7d cd 00          	cmpb   $0x0,-0x33(%rbp)
 11bf108:	75 26                	jne    11bf130 <br.encodeCommandPlanWithOptionsWrite+0x36f0>
 11bf10a:	41 be 05 00 00 00    	mov    $0x5,%r14d
 11bf110:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 11bf114:	75 1a                	jne    11bf130 <br.encodeCommandPlanWithOptionsWrite+0x36f0>
 11bf116:	41 be 04 00 00 00    	mov    $0x4,%r14d
 11bf11c:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 11bf120:	75 0e                	jne    11bf130 <br.encodeCommandPlanWithOptionsWrite+0x36f0>
 11bf122:	80 7d ca 01          	cmpb   $0x1,-0x36(%rbp)
 11bf126:	41 be 03 00 00 00    	mov    $0x3,%r14d
 11bf12c:	49 83 de 00          	sbb    $0x0,%r14
 11bf130:	80 7d cb 00          	cmpb   $0x0,-0x35(%rbp)
 11bf134:	0f 84 ea 01 00 00    	je     11bf324 <br.encodeCommandPlanWithOptionsWrite+0x38e4>
 11bf13a:	48 8b 85 d8 fe ff ff 	mov    -0x128(%rbp),%rax
 11bf141:	48 89 85 50 fa ff ff 	mov    %rax,-0x5b0(%rbp)
 11bf148:	48 8b 85 60 fe ff ff 	mov    -0x1a0(%rbp),%rax
 11bf14f:	48 89 85 58 fa ff ff 	mov    %rax,-0x5a8(%rbp)
 11bf156:	0f b6 45 d5          	movzbl -0x2b(%rbp),%eax
 11bf15a:	88 85 60 fa ff ff    	mov    %al,-0x5a0(%rbp)
 11bf160:	8b 85 b0 fe ff ff    	mov    -0x150(%rbp),%eax
 11bf166:	8b 8d b3 fe ff ff    	mov    -0x14d(%rbp),%ecx
 11bf16c:	89 85 61 fa ff ff    	mov    %eax,-0x59f(%rbp)
 11bf172:	89 8d 64 fa ff ff    	mov    %ecx,-0x59c(%rbp)
 11bf178:	48 8b 85 68 fe ff ff 	mov    -0x198(%rbp),%rax
 11bf17f:	48 89 85 68 fa ff ff 	mov    %rax,-0x598(%rbp)
 11bf186:	0f b6 45 d4          	movzbl -0x2c(%rbp),%eax
 11bf18a:	88 85 70 fa ff ff    	mov    %al,-0x590(%rbp)
 11bf190:	8b 85 b8 fe ff ff    	mov    -0x148(%rbp),%eax
 11bf196:	8b 8d bb fe ff ff    	mov    -0x145(%rbp),%ecx
 11bf19c:	89 85 71 fa ff ff    	mov    %eax,-0x58f(%rbp)
 11bf1a2:	89 8d 74 fa ff ff    	mov    %ecx,-0x58c(%rbp)
 11bf1a8:	48 8b 85 70 fe ff ff 	mov    -0x190(%rbp),%rax
 11bf1af:	48 89 85 78 fa ff ff 	mov    %rax,-0x588(%rbp)
 11bf1b6:	0f b6 45 d7          	movzbl -0x29(%rbp),%eax
 11bf1ba:	88 85 80 fa ff ff    	mov    %al,-0x580(%rbp)
 11bf1c0:	8b 85 c0 fe ff ff    	mov    -0x140(%rbp),%eax
 11bf1c6:	8b 8d c3 fe ff ff    	mov    -0x13d(%rbp),%ecx
 11bf1cc:	89 85 81 fa ff ff    	mov    %eax,-0x57f(%rbp)
 11bf1d2:	89 8d 84 fa ff ff    	mov    %ecx,-0x57c(%rbp)
 11bf1d8:	48 8b 85 78 fe ff ff 	mov    -0x188(%rbp),%rax
 11bf1df:	48 89 85 88 fa ff ff 	mov    %rax,-0x578(%rbp)
 11bf1e6:	0f b6 45 ce          	movzbl -0x32(%rbp),%eax
 11bf1ea:	88 85 90 fa ff ff    	mov    %al,-0x570(%rbp)
 11bf1f0:	8b 85 c8 fe ff ff    	mov    -0x138(%rbp),%eax
 11bf1f6:	8b 8d cb fe ff ff    	mov    -0x135(%rbp),%ecx
 11bf1fc:	89 85 91 fa ff ff    	mov    %eax,-0x56f(%rbp)
 11bf202:	89 8d 94 fa ff ff    	mov    %ecx,-0x56c(%rbp)
 11bf208:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 11bf20f:	48 89 85 98 fa ff ff 	mov    %rax,-0x568(%rbp)
 11bf216:	0f b6 45 c4          	movzbl -0x3c(%rbp),%eax
 11bf21a:	88 85 a0 fa ff ff    	mov    %al,-0x560(%rbp)
 11bf220:	8b 85 d0 fe ff ff    	mov    -0x130(%rbp),%eax
 11bf226:	8b 8d d3 fe ff ff    	mov    -0x12d(%rbp),%ecx
 11bf22c:	89 85 a1 fa ff ff    	mov    %eax,-0x55f(%rbp)
 11bf232:	89 8d a4 fa ff ff    	mov    %ecx,-0x55c(%rbp)
 11bf238:	48 8b 85 00 fd ff ff 	mov    -0x300(%rbp),%rax
 11bf23f:	48 89 85 a8 fa ff ff 	mov    %rax,-0x558(%rbp)
 11bf246:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 11bf24a:	88 85 b0 fa ff ff    	mov    %al,-0x550(%rbp)
 11bf250:	0f b6 45 c9          	movzbl -0x37(%rbp),%eax
 11bf254:	88 85 b1 fa ff ff    	mov    %al,-0x54f(%rbp)
 11bf25a:	0f b7 85 f8 fe ff ff 	movzwl -0x108(%rbp),%eax
 11bf261:	66 89 85 b6 fa ff ff 	mov    %ax,-0x54a(%rbp)
 11bf268:	8b 85 f4 fe ff ff    	mov    -0x10c(%rbp),%eax
 11bf26e:	89 85 b2 fa ff ff    	mov    %eax,-0x54e(%rbp)
 11bf274:	48 8d bd f0 e6 ff ff 	lea    -0x1910(%rbp),%rdi
 11bf27b:	48 8d b5 50 fa ff ff 	lea    -0x5b0(%rbp),%rsi
 11bf282:	48 8b 95 10 fd ff ff 	mov    -0x2f0(%rbp),%rdx
 11bf289:	c5 f8 77             	vzeroupper 
 11bf28c:	e8 3f 1f 03 00       	call   11f11d0 <br.DistanceBlockLengthCode.init>
 11bf291:	0f b7 85 b8 e7 ff ff 	movzwl -0x1848(%rbp),%eax
 11bf298:	66 85 c0             	test   %ax,%ax
 11bf29b:	0f 85 0c c8 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bf2a1:	48 8b 85 b0 e7 ff ff 	mov    -0x1850(%rbp),%rax
 11bf2a8:	48 89 85 10 ed ff ff 	mov    %rax,-0x12f0(%rbp)
 11bf2af:	c5 fc 10 85 90 e7 ff 	vmovups -0x1870(%rbp),%ymm0
 11bf2b6:	ff 
 11bf2b7:	c5 fc 11 85 f0 ec ff 	vmovups %ymm0,-0x1310(%rbp)
 11bf2be:	ff 
 11bf2bf:	c5 fc 10 85 70 e7 ff 	vmovups -0x1890(%rbp),%ymm0
 11bf2c6:	ff 
 11bf2c7:	c5 fc 11 85 d0 ec ff 	vmovups %ymm0,-0x1330(%rbp)
 11bf2ce:	ff 
 11bf2cf:	c5 fc 10 85 10 e7 ff 	vmovups -0x18f0(%rbp),%ymm0
 11bf2d6:	ff 
 11bf2d7:	c5 fc 10 8d 30 e7 ff 	vmovups -0x18d0(%rbp),%ymm1
 11bf2de:	ff 
 11bf2df:	c5 fc 10 95 50 e7 ff 	vmovups -0x18b0(%rbp),%ymm2
 11bf2e6:	ff 
 11bf2e7:	c5 fc 11 95 b0 ec ff 	vmovups %ymm2,-0x1350(%rbp)
 11bf2ee:	ff 
 11bf2ef:	c5 fc 11 8d 90 ec ff 	vmovups %ymm1,-0x1370(%rbp)
 11bf2f6:	ff 
 11bf2f7:	c5 fc 11 85 70 ec ff 	vmovups %ymm0,-0x1390(%rbp)
 11bf2fe:	ff 
 11bf2ff:	c5 fc 10 85 f0 e6 ff 	vmovups -0x1910(%rbp),%ymm0
 11bf306:	ff 
 11bf307:	c5 fc 11 85 50 ec ff 	vmovups %ymm0,-0x13b0(%rbp)
 11bf30e:	ff 
 11bf30f:	c6 45 a8 00          	movb   $0x0,-0x58(%rbp)
 11bf313:	b0 01                	mov    $0x1,%al
 11bf315:	80 7d c4 00          	cmpb   $0x0,-0x3c(%rbp)
 11bf319:	74 11                	je     11bf32c <br.encodeCommandPlanWithOptionsWrite+0x38ec>
 11bf31b:	48 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%rcx
 11bf322:	eb 4f                	jmp    11bf373 <br.encodeCommandPlanWithOptionsWrite+0x3933>
 11bf324:	c6 45 a8 00          	movb   $0x0,-0x58(%rbp)
 11bf328:	31 c0                	xor    %eax,%eax
 11bf32a:	eb 47                	jmp    11bf373 <br.encodeCommandPlanWithOptionsWrite+0x3933>
 11bf32c:	0f b6 4d d3          	movzbl -0x2d(%rbp),%ecx
 11bf330:	0a 4d c9             	or     -0x37(%rbp),%cl
 11bf333:	f6 c1 01             	test   $0x1,%cl
 11bf336:	74 0d                	je     11bf345 <br.encodeCommandPlanWithOptionsWrite+0x3905>
 11bf338:	0f b6 4d d3          	movzbl -0x2d(%rbp),%ecx
 11bf33c:	83 e1 01             	and    $0x1,%ecx
 11bf33f:	48 83 f1 03          	xor    $0x3,%rcx
 11bf343:	eb 2e                	jmp    11bf373 <br.encodeCommandPlanWithOptionsWrite+0x3933>
 11bf345:	b9 06 00 00 00       	mov    $0x6,%ecx
 11bf34a:	80 7d ce 00          	cmpb   $0x0,-0x32(%rbp)
 11bf34e:	75 23                	jne    11bf373 <br.encodeCommandPlanWithOptionsWrite+0x3933>
 11bf350:	b9 05 00 00 00       	mov    $0x5,%ecx
 11bf355:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 11bf359:	75 18                	jne    11bf373 <br.encodeCommandPlanWithOptionsWrite+0x3933>
 11bf35b:	b9 04 00 00 00       	mov    $0x4,%ecx
 11bf360:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 11bf364:	75 0d                	jne    11bf373 <br.encodeCommandPlanWithOptionsWrite+0x3933>
 11bf366:	80 7d d5 01          	cmpb   $0x1,-0x2b(%rbp)
 11bf36a:	b9 03 00 00 00       	mov    $0x3,%ecx
 11bf36f:	48 83 d9 00          	sbb    $0x0,%rcx
 11bf373:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 11bf377:	0f 84 7e 01 00 00    	je     11bf4fb <br.encodeCommandPlanWithOptionsWrite+0x3abb>
 11bf37d:	4c 89 b5 70 f9 ff ff 	mov    %r14,-0x690(%rbp)
 11bf384:	48 8d 95 d8 fc fe ff 	lea    -0x10328(%rbp),%rdx
 11bf38b:	48 89 95 78 f9 ff ff 	mov    %rdx,-0x688(%rbp)
 11bf392:	48 8d 95 08 1e ff ff 	lea    -0xe1f8(%rbp),%rdx
 11bf399:	48 89 95 80 f9 ff ff 	mov    %rdx,-0x680(%rbp)
 11bf3a0:	48 8d 95 20 ed ff ff 	lea    -0x12e0(%rbp),%rdx
 11bf3a7:	48 89 95 88 f9 ff ff 	mov    %rdx,-0x678(%rbp)
 11bf3ae:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11bf3b2:	c5 f8 11 85 90 f9 ff 	vmovups %xmm0,-0x670(%rbp)
 11bf3b9:	ff 
 11bf3ba:	8b 95 5c ff ff ff    	mov    -0xa4(%rbp),%edx
 11bf3c0:	66 89 95 98 fd ff ff 	mov    %dx,-0x268(%rbp)
 11bf3c7:	0f b6 55 b0          	movzbl -0x50(%rbp),%edx
 11bf3cb:	88 95 a0 f9 ff ff    	mov    %dl,-0x660(%rbp)
 11bf3d1:	c7 85 a1 f9 ff ff 00 	movl   $0x0,-0x65f(%rbp)
 11bf3d8:	00 00 00 
 11bf3db:	c7 85 a4 f9 ff ff 00 	movl   $0x0,-0x65c(%rbp)
 11bf3e2:	00 00 00 
 11bf3e5:	88 9d a8 f9 ff ff    	mov    %bl,-0x658(%rbp)
 11bf3eb:	c7 85 a9 f9 ff ff 00 	movl   $0x0,-0x657(%rbp)
 11bf3f2:	00 00 00 
 11bf3f5:	c7 85 ac f9 ff ff 00 	movl   $0x0,-0x654(%rbp)
 11bf3fc:	00 00 00 
 11bf3ff:	48 89 8d 98 f8 ff ff 	mov    %rcx,-0x768(%rbp)
 11bf406:	48 8d 8d 28 cb ff ff 	lea    -0x34d8(%rbp),%rcx
 11bf40d:	48 89 8d a0 f8 ff ff 	mov    %rcx,-0x760(%rbp)
 11bf414:	48 8d 8d da d1 ff ff 	lea    -0x2e26(%rbp),%rcx
 11bf41b:	48 89 8d a8 f8 ff ff 	mov    %rcx,-0x758(%rbp)
 11bf422:	48 8d 8d 50 ec ff ff 	lea    -0x13b0(%rbp),%rcx
 11bf429:	48 89 8d b0 f8 ff ff 	mov    %rcx,-0x750(%rbp)
 11bf430:	c5 f8 11 85 b8 f8 ff 	vmovups %xmm0,-0x748(%rbp)
 11bf437:	ff 
 11bf438:	48 c7 85 c8 f8 ff ff 	movq   $0x0,-0x738(%rbp)
 11bf43f:	00 00 00 00 
 11bf443:	0f b6 4d a8          	movzbl -0x58(%rbp),%ecx
 11bf447:	88 8d d0 f8 ff ff    	mov    %cl,-0x730(%rbp)
 11bf44d:	c7 85 d1 f8 ff ff 00 	movl   $0x0,-0x72f(%rbp)
 11bf454:	00 00 00 
 11bf457:	c7 85 d4 f8 ff ff 00 	movl   $0x0,-0x72c(%rbp)
 11bf45e:	00 00 00 
 11bf461:	88 85 d8 f8 ff ff    	mov    %al,-0x728(%rbp)
 11bf467:	c7 85 d9 f8 ff ff 00 	movl   $0x0,-0x727(%rbp)
 11bf46e:	00 00 00 
 11bf471:	c7 85 dc f8 ff ff 00 	movl   $0x0,-0x724(%rbp)
 11bf478:	00 00 00 
 11bf47b:	48 83 ec 08          	sub    $0x8,%rsp
 11bf47f:	48 8d 85 00 f2 ff ff 	lea    -0xe00(%rbp),%rax
 11bf486:	4c 8d 95 1a cf ff ff 	lea    -0x30e6(%rbp),%r10
 11bf48d:	4c 8d 9d 98 f8 ff ff 	lea    -0x768(%rbp),%r11
 11bf494:	48 8d 9d 00 f0 ff ff 	lea    -0x1000(%rbp),%rbx
 11bf49b:	4c 8d b5 70 f9 ff ff 	lea    -0x690(%rbp),%r14
 11bf4a2:	48 8d 95 58 8c ff ff 	lea    -0x73a8(%rbp),%rdx
 11bf4a9:	48 8d 8d bc ab ff ff 	lea    -0x5444(%rbp),%rcx
 11bf4b0:	4c 8d 85 90 e8 ff ff 	lea    -0x1770(%rbp),%r8
 11bf4b7:	4c 8d 8d 98 fd ff ff 	lea    -0x268(%rbp),%r9
 11bf4be:	48 8b 7d a0          	mov    -0x60(%rbp),%rdi
 11bf4c2:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 11bf4c6:	50                   	push   %rax
 11bf4c7:	41 52                	push   %r10
 11bf4c9:	ff b5 a8 fd ff ff    	push   -0x258(%rbp)
 11bf4cf:	41 53                	push   %r11
 11bf4d1:	53                   	push   %rbx
 11bf4d2:	41 56                	push   %r14
 11bf4d4:	48 8d 85 a0 c5 ff ff 	lea    -0x3a60(%rbp),%rax
 11bf4db:	50                   	push   %rax
 11bf4dc:	c5 f8 77             	vzeroupper 
 11bf4df:	e8 2c 0f 03 00       	call   11f0410 <br.writePlannedCompressedHeaderLiteralBlocks__anon_31264>
 11bf4e4:	48 83 c4 40          	add    $0x40,%rsp
 11bf4e8:	bb f8 2b 04 01       	mov    $0x1042bf8,%ebx
 11bf4ed:	66 85 c0             	test   %ax,%ax
 11bf4f0:	0f 84 66 03 00 00    	je     11bf85c <br.encodeCommandPlanWithOptionsWrite+0x3e1c>
 11bf4f6:	e9 b2 c5 ff ff       	jmp    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bf4fb:	48 8b 95 08 ff ff ff 	mov    -0xf8(%rbp),%rdx
 11bf502:	80 3a 00             	cmpb   $0x0,(%rdx)
 11bf505:	0f 84 9a 01 00 00    	je     11bf6a5 <br.encodeCommandPlanWithOptionsWrite+0x3c65>
 11bf50b:	48 8b 95 08 fd ff ff 	mov    -0x2f8(%rbp),%rdx
 11bf512:	c5 fc 10 02          	vmovups (%rdx),%ymm0
 11bf516:	c5 fc 10 4a 20       	vmovups 0x20(%rdx),%ymm1
 11bf51b:	c5 fc 10 52 30       	vmovups 0x30(%rdx),%ymm2
 11bf520:	c5 fc 11 95 b0 e9 ff 	vmovups %ymm2,-0x1650(%rbp)
 11bf527:	ff 
 11bf528:	c5 fc 11 8d a0 e9 ff 	vmovups %ymm1,-0x1660(%rbp)
 11bf52f:	ff 
 11bf530:	c5 fc 11 85 80 e9 ff 	vmovups %ymm0,-0x1680(%rbp)
 11bf537:	ff 
 11bf538:	8b 95 5c ff ff ff    	mov    -0xa4(%rbp),%edx
 11bf53e:	66 89 95 96 fd ff ff 	mov    %dx,-0x26a(%rbp)
 11bf545:	4c 89 b5 30 f9 ff ff 	mov    %r14,-0x6d0(%rbp)
 11bf54c:	48 8d 95 d8 fc fe ff 	lea    -0x10328(%rbp),%rdx
 11bf553:	48 89 95 38 f9 ff ff 	mov    %rdx,-0x6c8(%rbp)
 11bf55a:	48 8d 95 08 1e ff ff 	lea    -0xe1f8(%rbp),%rdx
 11bf561:	48 89 95 40 f9 ff ff 	mov    %rdx,-0x6c0(%rbp)
 11bf568:	48 8d 95 20 ed ff ff 	lea    -0x12e0(%rbp),%rdx
 11bf56f:	48 89 95 48 f9 ff ff 	mov    %rdx,-0x6b8(%rbp)
 11bf576:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11bf57a:	c5 f8 11 85 50 f9 ff 	vmovups %xmm0,-0x6b0(%rbp)
 11bf581:	ff 
 11bf582:	0f b6 55 b0          	movzbl -0x50(%rbp),%edx
 11bf586:	88 95 60 f9 ff ff    	mov    %dl,-0x6a0(%rbp)
 11bf58c:	c7 85 61 f9 ff ff 00 	movl   $0x0,-0x69f(%rbp)
 11bf593:	00 00 00 
 11bf596:	c7 85 64 f9 ff ff 00 	movl   $0x0,-0x69c(%rbp)
 11bf59d:	00 00 00 
 11bf5a0:	88 9d 68 f9 ff ff    	mov    %bl,-0x698(%rbp)
 11bf5a6:	c7 85 69 f9 ff ff 00 	movl   $0x0,-0x697(%rbp)
 11bf5ad:	00 00 00 
 11bf5b0:	c7 85 6c f9 ff ff 00 	movl   $0x0,-0x694(%rbp)
 11bf5b7:	00 00 00 
 11bf5ba:	48 89 8d 50 f8 ff ff 	mov    %rcx,-0x7b0(%rbp)
 11bf5c1:	48 8d 8d 28 cb ff ff 	lea    -0x34d8(%rbp),%rcx
 11bf5c8:	48 89 8d 58 f8 ff ff 	mov    %rcx,-0x7a8(%rbp)
 11bf5cf:	48 8d 8d da d1 ff ff 	lea    -0x2e26(%rbp),%rcx
 11bf5d6:	48 89 8d 60 f8 ff ff 	mov    %rcx,-0x7a0(%rbp)
 11bf5dd:	48 8d 8d 50 ec ff ff 	lea    -0x13b0(%rbp),%rcx
 11bf5e4:	48 89 8d 68 f8 ff ff 	mov    %rcx,-0x798(%rbp)
 11bf5eb:	c5 f8 11 85 70 f8 ff 	vmovups %xmm0,-0x790(%rbp)
 11bf5f2:	ff 
 11bf5f3:	48 c7 85 80 f8 ff ff 	movq   $0x0,-0x780(%rbp)
 11bf5fa:	00 00 00 00 
 11bf5fe:	0f b6 4d a8          	movzbl -0x58(%rbp),%ecx
 11bf602:	88 8d 88 f8 ff ff    	mov    %cl,-0x778(%rbp)
 11bf608:	c7 85 89 f8 ff ff 00 	movl   $0x0,-0x777(%rbp)
 11bf60f:	00 00 00 
 11bf612:	c7 85 8c f8 ff ff 00 	movl   $0x0,-0x774(%rbp)
 11bf619:	00 00 00 
 11bf61c:	88 85 90 f8 ff ff    	mov    %al,-0x770(%rbp)
 11bf622:	c7 85 91 f8 ff ff 00 	movl   $0x0,-0x76f(%rbp)
 11bf629:	00 00 00 
 11bf62c:	c7 85 94 f8 ff ff 00 	movl   $0x0,-0x76c(%rbp)
 11bf633:	00 00 00 
 11bf636:	48 83 ec 08          	sub    $0x8,%rsp
 11bf63a:	48 8d 85 00 f2 ff ff 	lea    -0xe00(%rbp),%rax
 11bf641:	4c 8d 95 1a cf ff ff 	lea    -0x30e6(%rbp),%r10
 11bf648:	4c 8d 9d 50 f8 ff ff 	lea    -0x7b0(%rbp),%r11
 11bf64f:	48 8d 9d 00 f0 ff ff 	lea    -0x1000(%rbp),%rbx
 11bf656:	4c 8d b5 30 f9 ff ff 	lea    -0x6d0(%rbp),%r14
 11bf65d:	4c 8d bd a0 c5 ff ff 	lea    -0x3a60(%rbp),%r15
 11bf664:	48 8d 95 40 1d fd ff 	lea    -0x2e2c0(%rbp),%rdx
 11bf66b:	48 8d 8d c4 c1 fd ff 	lea    -0x23e3c(%rbp),%rcx
 11bf672:	4c 8d 85 80 e9 ff ff 	lea    -0x1680(%rbp),%r8
 11bf679:	4c 8d 8d 96 fd ff ff 	lea    -0x26a(%rbp),%r9
 11bf680:	48 8b 7d a0          	mov    -0x60(%rbp),%rdi
 11bf684:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 11bf688:	50                   	push   %rax
 11bf689:	41 52                	push   %r10
 11bf68b:	ff b5 a8 fd ff ff    	push   -0x258(%rbp)
 11bf691:	41 53                	push   %r11
 11bf693:	53                   	push   %rbx
 11bf694:	41 56                	push   %r14
 11bf696:	41 57                	push   %r15
 11bf698:	c5 f8 77             	vzeroupper 
 11bf69b:	e8 c0 66 00 00       	call   11c5d60 <br.writePlannedCompressedHeaderLiteralContexts__anon_31271>
 11bf6a0:	e9 65 01 00 00       	jmp    11bf80a <br.encodeCommandPlanWithOptionsWrite+0x3dca>
 11bf6a5:	4c 89 b5 f0 f8 ff ff 	mov    %r14,-0x710(%rbp)
 11bf6ac:	48 8d 95 d8 fc fe ff 	lea    -0x10328(%rbp),%rdx
 11bf6b3:	48 89 95 f8 f8 ff ff 	mov    %rdx,-0x708(%rbp)
 11bf6ba:	48 8d 95 08 1e ff ff 	lea    -0xe1f8(%rbp),%rdx
 11bf6c1:	48 89 95 00 f9 ff ff 	mov    %rdx,-0x700(%rbp)
 11bf6c8:	48 8d 95 20 ed ff ff 	lea    -0x12e0(%rbp),%rdx
 11bf6cf:	48 89 95 08 f9 ff ff 	mov    %rdx,-0x6f8(%rbp)
 11bf6d6:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11bf6da:	c5 f8 11 85 10 f9 ff 	vmovups %xmm0,-0x6f0(%rbp)
 11bf6e1:	ff 
 11bf6e2:	0f b6 55 b0          	movzbl -0x50(%rbp),%edx
 11bf6e6:	88 95 20 f9 ff ff    	mov    %dl,-0x6e0(%rbp)
 11bf6ec:	c7 85 21 f9 ff ff 00 	movl   $0x0,-0x6df(%rbp)
 11bf6f3:	00 00 00 
 11bf6f6:	c7 85 24 f9 ff ff 00 	movl   $0x0,-0x6dc(%rbp)
 11bf6fd:	00 00 00 
 11bf700:	88 9d 28 f9 ff ff    	mov    %bl,-0x6d8(%rbp)
 11bf706:	c7 85 29 f9 ff ff 00 	movl   $0x0,-0x6d7(%rbp)
 11bf70d:	00 00 00 
 11bf710:	c7 85 2c f9 ff ff 00 	movl   $0x0,-0x6d4(%rbp)
 11bf717:	00 00 00 
 11bf71a:	48 89 8d 08 f8 ff ff 	mov    %rcx,-0x7f8(%rbp)
 11bf721:	48 8d 8d 28 cb ff ff 	lea    -0x34d8(%rbp),%rcx
 11bf728:	48 89 8d 10 f8 ff ff 	mov    %rcx,-0x7f0(%rbp)
 11bf72f:	48 8d 8d da d1 ff ff 	lea    -0x2e26(%rbp),%rcx
 11bf736:	48 89 8d 18 f8 ff ff 	mov    %rcx,-0x7e8(%rbp)
 11bf73d:	48 8d 8d 50 ec ff ff 	lea    -0x13b0(%rbp),%rcx
 11bf744:	48 89 8d 20 f8 ff ff 	mov    %rcx,-0x7e0(%rbp)
 11bf74b:	c5 f8 11 85 28 f8 ff 	vmovups %xmm0,-0x7d8(%rbp)
 11bf752:	ff 
 11bf753:	48 c7 85 38 f8 ff ff 	movq   $0x0,-0x7c8(%rbp)
 11bf75a:	00 00 00 00 
 11bf75e:	0f b6 4d a8          	movzbl -0x58(%rbp),%ecx
 11bf762:	88 8d 40 f8 ff ff    	mov    %cl,-0x7c0(%rbp)
 11bf768:	c7 85 41 f8 ff ff 00 	movl   $0x0,-0x7bf(%rbp)
 11bf76f:	00 00 00 
 11bf772:	c7 85 44 f8 ff ff 00 	movl   $0x0,-0x7bc(%rbp)
 11bf779:	00 00 00 
 11bf77c:	88 85 48 f8 ff ff    	mov    %al,-0x7b8(%rbp)
 11bf782:	c7 85 49 f8 ff ff 00 	movl   $0x0,-0x7b7(%rbp)
 11bf789:	00 00 00 
 11bf78c:	c7 85 4c f8 ff ff 00 	movl   $0x0,-0x7b4(%rbp)
 11bf793:	00 00 00 
 11bf796:	8b 85 5c ff ff ff    	mov    -0xa4(%rbp),%eax
 11bf79c:	66 89 85 94 fd ff ff 	mov    %ax,-0x26c(%rbp)
 11bf7a3:	48 83 ec 08          	sub    $0x8,%rsp
 11bf7a7:	48 8d 85 00 f2 ff ff 	lea    -0xe00(%rbp),%rax
 11bf7ae:	4c 8d 95 1a cf ff ff 	lea    -0x30e6(%rbp),%r10
 11bf7b5:	4c 8d 9d f0 e5 ff ff 	lea    -0x1a10(%rbp),%r11
 11bf7bc:	48 8d 9d 94 fd ff ff 	lea    -0x26c(%rbp),%rbx
 11bf7c3:	4c 8d b5 08 f8 ff ff 	lea    -0x7f8(%rbp),%r14
 11bf7ca:	4c 8d bd 00 f0 ff ff 	lea    -0x1000(%rbp),%r15
 11bf7d1:	0f b6 55 9d          	movzbl -0x63(%rbp),%edx
 11bf7d5:	48 8d 8d b8 d5 ff ff 	lea    -0x2a48(%rbp),%rcx
 11bf7dc:	4c 8d 85 a0 c5 ff ff 	lea    -0x3a60(%rbp),%r8
 11bf7e3:	4c 8d 8d f0 f8 ff ff 	lea    -0x710(%rbp),%r9
 11bf7ea:	48 8b 7d a0          	mov    -0x60(%rbp),%rdi
 11bf7ee:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 11bf7f2:	50                   	push   %rax
 11bf7f3:	41 52                	push   %r10
 11bf7f5:	41 53                	push   %r11
 11bf7f7:	ff b5 a8 fd ff ff    	push   -0x258(%rbp)
 11bf7fd:	53                   	push   %rbx
 11bf7fe:	41 56                	push   %r14
 11bf800:	41 57                	push   %r15
 11bf802:	c5 f8 77             	vzeroupper 
 11bf805:	e8 06 62 00 00       	call   11c5a10 <br.writePlannedCompressedHeader__anon_31277>
 11bf80a:	48 83 c4 40          	add    $0x40,%rsp
 11bf80e:	66 85 c0             	test   %ax,%ax
 11bf811:	0f 85 96 c2 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bf817:	48 8d bd ba a8 ff ff 	lea    -0x5746(%rbp),%rdi
 11bf81e:	48 8d b5 f0 e5 ff ff 	lea    -0x1a10(%rbp),%rsi
 11bf825:	48 8d 95 b8 d5 ff ff 	lea    -0x2a48(%rbp),%rdx
 11bf82c:	e8 5f 5a 00 00       	call   11c5290 <br.initPlannedLiteralEncoder>
 11bf831:	0f b7 85 ba ab ff ff 	movzwl -0x5446(%rbp),%eax
 11bf838:	66 85 c0             	test   %ax,%ax
 11bf83b:	0f 85 6c c2 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bf841:	48 8d 9d 88 34 ff ff 	lea    -0xcb78(%rbp),%rbx
 11bf848:	48 8d b5 ba a8 ff ff 	lea    -0x5746(%rbp),%rsi
 11bf84f:	ba 00 03 00 00       	mov    $0x300,%edx
 11bf854:	48 89 df             	mov    %rbx,%rdi
 11bf857:	e8 04 ff 11 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11bf85c:	48 8d bd bc b1 ff ff 	lea    -0x4e44(%rbp),%rdi
 11bf863:	ba 00 03 00 00       	mov    $0x300,%edx
 11bf868:	48 89 de             	mov    %rbx,%rsi
 11bf86b:	e8 f0 fe 11 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11bf870:	48 8b 85 08 ff ff ff 	mov    -0xf8(%rbp),%rax
 11bf877:	80 38 00             	cmpb   $0x0,(%rax)
 11bf87a:	0f 84 9f 00 00 00    	je     11bf91f <br.encodeCommandPlanWithOptionsWrite+0x3edf>
 11bf880:	48 8b 85 a0 fd ff ff 	mov    -0x260(%rbp),%rax
 11bf887:	0f b6 00             	movzbl (%rax),%eax
 11bf88a:	48 83 e0 7f          	and    $0x7f,%rax
 11bf88e:	48 8d b5 c4 c1 fd ff 	lea    -0x23e3c(%rbp),%rsi
 11bf895:	74 6b                	je     11bf902 <br.encodeCommandPlanWithOptionsWrite+0x3ec2>
 11bf897:	c1 e0 08             	shl    $0x8,%eax
 11bf89a:	4c 8d 3c 40          	lea    (%rax,%rax,2),%r15
 11bf89e:	48 8d 9d 40 1d fd ff 	lea    -0x2e2c0(%rbp),%rbx
 11bf8a5:	45 31 e4             	xor    %r12d,%r12d
 11bf8a8:	4c 8d b5 8e 9b ff ff 	lea    -0x6472(%rbp),%r14
 11bf8af:	4c 89 f7             	mov    %r14,%rdi
 11bf8b2:	49 89 f5             	mov    %rsi,%r13
 11bf8b5:	48 89 da             	mov    %rbx,%rdx
 11bf8b8:	e8 d3 59 00 00       	call   11c5290 <br.initPlannedLiteralEncoder>
 11bf8bd:	0f b7 85 8e 9e ff ff 	movzwl -0x6172(%rbp),%eax
 11bf8c4:	66 85 c0             	test   %ax,%ax
 11bf8c7:	0f 85 e0 c1 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bf8cd:	49 8d 3c 2c          	lea    (%r12,%rbp,1),%rdi
 11bf8d1:	48 81 c7 c0 88 fa ff 	add    $0xfffffffffffa88c0,%rdi
 11bf8d8:	ba 00 03 00 00       	mov    $0x300,%edx
 11bf8dd:	4c 89 f6             	mov    %r14,%rsi
 11bf8e0:	e8 7b fe 11 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11bf8e5:	49 81 c4 00 03 00 00 	add    $0x300,%r12
 11bf8ec:	48 81 c3 08 02 00 00 	add    $0x208,%rbx
 11bf8f3:	4c 89 ee             	mov    %r13,%rsi
 11bf8f6:	48 81 c6 00 01 00 00 	add    $0x100,%rsi
 11bf8fd:	4d 39 e7             	cmp    %r12,%r15
 11bf900:	75 ad                	jne    11bf8af <br.encodeCommandPlanWithOptionsWrite+0x3e6f>
 11bf902:	48 8d 9d c0 08 f9 ff 	lea    -0x6f740(%rbp),%rbx
 11bf909:	48 8d b5 c0 88 fa ff 	lea    -0x57740(%rbp),%rsi
 11bf910:	ba 00 c0 00 00       	mov    $0xc000,%edx
 11bf915:	48 89 df             	mov    %rbx,%rdi
 11bf918:	e8 43 fe 11 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11bf91d:	eb 05                	jmp    11bf924 <br.encodeCommandPlanWithOptionsWrite+0x3ee4>
 11bf91f:	bb f8 2e 04 01       	mov    $0x1042ef8,%ebx
 11bf924:	48 8d bd c0 c8 f9 ff 	lea    -0x63740(%rbp),%rdi
 11bf92b:	ba 00 c0 00 00       	mov    $0xc000,%edx
 11bf930:	48 89 de             	mov    %rbx,%rsi
 11bf933:	e8 28 fe 11 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11bf938:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 11bf93c:	74 21                	je     11bf95f <br.encodeCommandPlanWithOptionsWrite+0x3f1f>
 11bf93e:	80 7d c0 00          	cmpb   $0x0,-0x40(%rbp)
 11bf942:	74 25                	je     11bf969 <br.encodeCommandPlanWithOptionsWrite+0x3f29>
 11bf944:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 11bf94b:	49 89 c4             	mov    %rax,%r12
 11bf94e:	48 85 c0             	test   %rax,%rax
 11bf951:	48 8d b5 bc ab ff ff 	lea    -0x5444(%rbp),%rsi
 11bf958:	75 69                	jne    11bf9c3 <br.encodeCommandPlanWithOptionsWrite+0x3f83>
 11bf95a:	e9 c4 00 00 00       	jmp    11bfa23 <br.encodeCommandPlanWithOptionsWrite+0x3fe3>
 11bf95f:	bb f8 ee 04 01       	mov    $0x104eef8,%ebx
 11bf964:	e9 d5 00 00 00       	jmp    11bfa3e <br.encodeCommandPlanWithOptionsWrite+0x3ffe>
 11bf969:	0f b6 45 cc          	movzbl -0x34(%rbp),%eax
 11bf96d:	0a 45 c2             	or     -0x3e(%rbp),%al
 11bf970:	a8 01                	test   $0x1,%al
 11bf972:	74 16                	je     11bf98a <br.encodeCommandPlanWithOptionsWrite+0x3f4a>
 11bf974:	44 0f b6 65 cc       	movzbl -0x34(%rbp),%r12d
 11bf979:	41 83 e4 01          	and    $0x1,%r12d
 11bf97d:	49 83 f4 03          	xor    $0x3,%r12
 11bf981:	48 8d b5 bc ab ff ff 	lea    -0x5444(%rbp),%rsi
 11bf988:	eb 39                	jmp    11bf9c3 <br.encodeCommandPlanWithOptionsWrite+0x3f83>
 11bf98a:	41 bc 06 00 00 00    	mov    $0x6,%r12d
 11bf990:	80 7d c7 00          	cmpb   $0x0,-0x39(%rbp)
 11bf994:	48 8d b5 bc ab ff ff 	lea    -0x5444(%rbp),%rsi
 11bf99b:	75 26                	jne    11bf9c3 <br.encodeCommandPlanWithOptionsWrite+0x3f83>
 11bf99d:	41 bc 05 00 00 00    	mov    $0x5,%r12d
 11bf9a3:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 11bf9a7:	75 1a                	jne    11bf9c3 <br.encodeCommandPlanWithOptionsWrite+0x3f83>
 11bf9a9:	41 bc 04 00 00 00    	mov    $0x4,%r12d
 11bf9af:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 11bf9b3:	75 0e                	jne    11bf9c3 <br.encodeCommandPlanWithOptionsWrite+0x3f83>
 11bf9b5:	80 7d c5 01          	cmpb   $0x1,-0x3b(%rbp)
 11bf9b9:	41 bc 03 00 00 00    	mov    $0x3,%r12d
 11bf9bf:	49 83 dc 00          	sbb    $0x0,%r12
 11bf9c3:	48 8d 9d 58 8c ff ff 	lea    -0x73a8(%rbp),%rbx
 11bf9ca:	4c 8d b5 c4 55 fe ff 	lea    -0x1aa3c(%rbp),%r14
 11bf9d1:	4c 8d bd 8c 98 ff ff 	lea    -0x6774(%rbp),%r15
 11bf9d8:	4c 89 ff             	mov    %r15,%rdi
 11bf9db:	49 89 f5             	mov    %rsi,%r13
 11bf9de:	48 89 da             	mov    %rbx,%rdx
 11bf9e1:	e8 aa 58 00 00       	call   11c5290 <br.initPlannedLiteralEncoder>
 11bf9e6:	0f b7 85 8c 9b ff ff 	movzwl -0x6474(%rbp),%eax
 11bf9ed:	66 85 c0             	test   %ax,%ax
 11bf9f0:	0f 85 b7 c0 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bf9f6:	ba 00 03 00 00       	mov    $0x300,%edx
 11bf9fb:	4c 89 f7             	mov    %r14,%rdi
 11bf9fe:	4c 89 fe             	mov    %r15,%rsi
 11bfa01:	e8 5a fd 11 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11bfa06:	48 81 c3 08 02 00 00 	add    $0x208,%rbx
 11bfa0d:	4c 89 ee             	mov    %r13,%rsi
 11bfa10:	48 81 c6 00 01 00 00 	add    $0x100,%rsi
 11bfa17:	49 81 c6 00 03 00 00 	add    $0x300,%r14
 11bfa1e:	49 ff cc             	dec    %r12
 11bfa21:	75 b5                	jne    11bf9d8 <br.encodeCommandPlanWithOptionsWrite+0x3f98>
 11bfa23:	48 8d 9d 44 9f fd ff 	lea    -0x260bc(%rbp),%rbx
 11bfa2a:	48 8d b5 c4 55 fe ff 	lea    -0x1aa3c(%rbp),%rsi
 11bfa31:	ba 00 12 00 00       	mov    $0x1200,%edx
 11bfa36:	48 89 df             	mov    %rbx,%rdi
 11bfa39:	e8 22 fd 11 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11bfa3e:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 11bfa42:	41 0f 95 c6          	setne  %r14b
 11bfa46:	48 8d bd c4 43 fe ff 	lea    -0x1bc3c(%rbp),%rdi
 11bfa4d:	ba 00 12 00 00       	mov    $0x1200,%edx
 11bfa52:	48 89 de             	mov    %rbx,%rsi
 11bfa55:	e8 06 fd 11 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11bfa5a:	48 8b 8d a0 c5 ff ff 	mov    -0x3a60(%rbp),%rcx
 11bfa61:	48 83 f9 05          	cmp    $0x5,%rcx
 11bfa65:	0f 92 c0             	setb   %al
 11bfa68:	44 08 f0             	or     %r14b,%al
 11bfa6b:	74 5a                	je     11bfac7 <br.encodeCommandPlanWithOptionsWrite+0x4087>
 11bfa6d:	48 8d bd fa 74 ff ff 	lea    -0x8b06(%rbp),%rdi
 11bfa74:	ba 40 08 00 00       	mov    $0x840,%edx
 11bfa79:	31 f6                	xor    %esi,%esi
 11bfa7b:	e8 c0 f8 11 00       	call   12df340 <compiler_rt.memset>
 11bfa80:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 11bfa84:	0f 84 cf 00 00 00    	je     11bfb59 <br.encodeCommandPlanWithOptionsWrite+0x4119>
 11bfa8a:	80 7d c1 00          	cmpb   $0x0,-0x3f(%rbp)
 11bfa8e:	0f 84 7c 1e 00 00    	je     11c1910 <br.encodeCommandPlanWithOptionsWrite+0x5ed0>
 11bfa94:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 11bfa9b:	49 89 c4             	mov    %rax,%r12
 11bfa9e:	48 85 c0             	test   %rax,%rax
 11bfaa1:	0f 85 d6 1e 00 00    	jne    11c197d <br.encodeCommandPlanWithOptionsWrite+0x5f3d>
 11bfaa7:	48 8d 9d c0 88 fb ff 	lea    -0x47740(%rbp),%rbx
 11bfaae:	48 8d b5 c0 eb fc ff 	lea    -0x31440(%rbp),%rsi
 11bfab5:	ba 80 31 00 00       	mov    $0x3180,%edx
 11bfaba:	48 89 df             	mov    %rbx,%rdi
 11bfabd:	e8 9e fc 11 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11bfac2:	e9 97 00 00 00       	jmp    11bfb5e <br.encodeCommandPlanWithOptionsWrite+0x411e>
 11bfac7:	48 83 f9 40          	cmp    $0x40,%rcx
 11bfacb:	77 3a                	ja     11bfb07 <br.encodeCommandPlanWithOptionsWrite+0x40c7>
 11bfacd:	48 8d 95 a8 c5 ff ff 	lea    -0x3a58(%rbp),%rdx
 11bfad4:	48 8d bd 78 64 ff ff 	lea    -0x9b88(%rbp),%rdi
 11bfadb:	48 8d b5 1a cf ff ff 	lea    -0x30e6(%rbp),%rsi
 11bfae2:	e8 49 53 00 00       	call   11c4e30 <huffman.HuffmanTable(704).Encoder.initSparseTrusted>
 11bfae7:	0f b7 85 b8 6c ff ff 	movzwl -0x9348(%rbp),%eax
 11bfaee:	66 85 c0             	test   %ax,%ax
 11bfaf1:	0f 85 b6 bf ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bfaf7:	48 8d 9d 04 91 fe ff 	lea    -0x16efc(%rbp),%rbx
 11bfafe:	48 8d b5 78 64 ff ff 	lea    -0x9b88(%rbp),%rsi
 11bfb05:	eb 31                	jmp    11bfb38 <br.encodeCommandPlanWithOptionsWrite+0x40f8>
 11bfb07:	48 8d bd 36 5c ff ff 	lea    -0xa3ca(%rbp),%rdi
 11bfb0e:	48 8d b5 1a cf ff ff 	lea    -0x30e6(%rbp),%rsi
 11bfb15:	e8 e6 4f 00 00       	call   11c4b00 <huffman.HuffmanTable(704).Encoder.init>
 11bfb1a:	0f b7 85 76 64 ff ff 	movzwl -0x9b8a(%rbp),%eax
 11bfb21:	66 85 c0             	test   %ax,%ax
 11bfb24:	0f 85 83 bf ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bfb2a:	48 8d 9d c4 88 fe ff 	lea    -0x1773c(%rbp),%rbx
 11bfb31:	48 8d b5 36 5c ff ff 	lea    -0xa3ca(%rbp),%rsi
 11bfb38:	ba 40 08 00 00       	mov    $0x840,%edx
 11bfb3d:	48 89 df             	mov    %rbx,%rdi
 11bfb40:	e8 1b fc 11 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11bfb45:	48 8d bd fa 74 ff ff 	lea    -0x8b06(%rbp),%rdi
 11bfb4c:	ba 40 08 00 00       	mov    $0x840,%edx
 11bfb51:	48 89 de             	mov    %rbx,%rsi
 11bfb54:	e8 07 fc 11 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11bfb59:	bb 38 09 05 01       	mov    $0x1050938,%ebx
 11bfb5e:	80 7d cb 00          	cmpb   $0x0,-0x35(%rbp)
 11bfb62:	41 0f 95 c6          	setne  %r14b
 11bfb66:	48 8d bd 40 ba fc ff 	lea    -0x345c0(%rbp),%rdi
 11bfb6d:	ba 80 31 00 00       	mov    $0x3180,%edx
 11bfb72:	48 89 de             	mov    %rbx,%rsi
 11bfb75:	e8 e6 fb 11 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11bfb7a:	48 8b 8d 00 f0 ff ff 	mov    -0x1000(%rbp),%rcx
 11bfb81:	48 83 f9 05          	cmp    $0x5,%rcx
 11bfb85:	0f 92 c0             	setb   %al
 11bfb88:	44 08 f0             	or     %r14b,%al
 11bfb8b:	0f 84 8e 00 00 00    	je     11bfc1f <br.encodeCommandPlanWithOptionsWrite+0x41df>
 11bfb91:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11bfb95:	c5 fc 11 85 3e ef ff 	vmovups %ymm0,-0x10c2(%rbp)
 11bfb9c:	ff 
 11bfb9d:	c5 fc 11 85 30 ef ff 	vmovups %ymm0,-0x10d0(%rbp)
 11bfba4:	ff 
 11bfba5:	c5 fc 11 85 10 ef ff 	vmovups %ymm0,-0x10f0(%rbp)
 11bfbac:	ff 
 11bfbad:	c5 fc 11 85 f0 ee ff 	vmovups %ymm0,-0x1110(%rbp)
 11bfbb4:	ff 
 11bfbb5:	c5 fc 11 85 d0 ee ff 	vmovups %ymm0,-0x1130(%rbp)
 11bfbbc:	ff 
 11bfbbd:	c5 fc 11 85 b0 ee ff 	vmovups %ymm0,-0x1150(%rbp)
 11bfbc4:	ff 
 11bfbc5:	c5 fc 11 85 90 ee ff 	vmovups %ymm0,-0x1170(%rbp)
 11bfbcc:	ff 
 11bfbcd:	c5 fc 11 85 70 ee ff 	vmovups %ymm0,-0x1190(%rbp)
 11bfbd4:	ff 
 11bfbd5:	80 7d cb 00          	cmpb   $0x0,-0x35(%rbp)
 11bfbd9:	0f 84 1d 02 00 00    	je     11bfdfc <br.encodeCommandPlanWithOptionsWrite+0x43bc>
 11bfbdf:	80 7d c4 00          	cmpb   $0x0,-0x3c(%rbp)
 11bfbe3:	0f 84 41 1d 00 00    	je     11c192a <br.encodeCommandPlanWithOptionsWrite+0x5eea>
 11bfbe9:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 11bfbf0:	49 89 c7             	mov    %rax,%r15
 11bfbf3:	48 85 c0             	test   %rax,%rax
 11bfbf6:	0f 85 90 1e 00 00    	jne    11c1a8c <br.encodeCommandPlanWithOptionsWrite+0x604c>
 11bfbfc:	48 8d 9d 44 df fe ff 	lea    -0x120bc(%rbp),%rbx
 11bfc03:	48 8d b5 1e 46 ff ff 	lea    -0xb9e2(%rbp),%rsi
 11bfc0a:	ba 94 05 00 00       	mov    $0x594,%edx
 11bfc0f:	48 89 df             	mov    %rbx,%rdi
 11bfc12:	c5 f8 77             	vzeroupper 
 11bfc15:	e8 46 fb 11 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11bfc1a:	e9 e2 01 00 00       	jmp    11bfe01 <br.encodeCommandPlanWithOptionsWrite+0x43c1>
 11bfc1f:	48 83 f9 40          	cmp    $0x40,%rcx
 11bfc23:	0f 87 b6 00 00 00    	ja     11bfcdf <br.encodeCommandPlanWithOptionsWrite+0x429f>
 11bfc29:	48 8d 95 08 f0 ff ff 	lea    -0xff8(%rbp),%rdx
 11bfc30:	48 8d bd d0 e2 ff ff 	lea    -0x1d30(%rbp),%rdi
 11bfc37:	48 8d b5 00 f2 ff ff 	lea    -0xe00(%rbp),%rsi
 11bfc3e:	e8 bd 49 00 00       	call   11c4600 <huffman.HuffmanTable(79).Encoder.initSparseTrusted>
 11bfc43:	0f b7 85 be e3 ff ff 	movzwl -0x1c42(%rbp),%eax
 11bfc4a:	66 85 c0             	test   %ax,%ax
 11bfc4d:	0f 85 5a be ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bfc53:	c5 fc 10 85 9e e3 ff 	vmovups -0x1c62(%rbp),%ymm0
 11bfc5a:	ff 
 11bfc5b:	c5 fc 11 85 be dc ff 	vmovups %ymm0,-0x2342(%rbp)
 11bfc62:	ff 
 11bfc63:	c5 fc 10 85 90 e3 ff 	vmovups -0x1c70(%rbp),%ymm0
 11bfc6a:	ff 
 11bfc6b:	c5 fc 11 85 b0 dc ff 	vmovups %ymm0,-0x2350(%rbp)
 11bfc72:	ff 
 11bfc73:	c5 fc 10 85 70 e3 ff 	vmovups -0x1c90(%rbp),%ymm0
 11bfc7a:	ff 
 11bfc7b:	c5 fc 11 85 90 dc ff 	vmovups %ymm0,-0x2370(%rbp)
 11bfc82:	ff 
 11bfc83:	c5 fc 10 85 50 e3 ff 	vmovups -0x1cb0(%rbp),%ymm0
 11bfc8a:	ff 
 11bfc8b:	c5 fc 11 85 70 dc ff 	vmovups %ymm0,-0x2390(%rbp)
 11bfc92:	ff 
 11bfc93:	c5 fc 10 85 d0 e2 ff 	vmovups -0x1d30(%rbp),%ymm0
 11bfc9a:	ff 
 11bfc9b:	c5 fc 10 8d 10 e3 ff 	vmovups -0x1cf0(%rbp),%ymm1
 11bfca2:	ff 
 11bfca3:	c5 fc 10 95 30 e3 ff 	vmovups -0x1cd0(%rbp),%ymm2
 11bfcaa:	ff 
 11bfcab:	c5 fc 11 95 50 dc ff 	vmovups %ymm2,-0x23b0(%rbp)
 11bfcb2:	ff 
 11bfcb3:	c5 fc 11 8d 30 dc ff 	vmovups %ymm1,-0x23d0(%rbp)
 11bfcba:	ff 
 11bfcbb:	c5 fc 10 8d f0 e2 ff 	vmovups -0x1d10(%rbp),%ymm1
 11bfcc2:	ff 
 11bfcc3:	c5 fc 11 8d 10 dc ff 	vmovups %ymm1,-0x23f0(%rbp)
 11bfcca:	ff 
 11bfccb:	c5 fc 11 85 f0 db ff 	vmovups %ymm0,-0x2410(%rbp)
 11bfcd2:	ff 
 11bfcd3:	48 8d 85 f0 db ff ff 	lea    -0x2410(%rbp),%rax
 11bfcda:	e9 aa 00 00 00       	jmp    11bfd89 <br.encodeCommandPlanWithOptionsWrite+0x4349>
 11bfcdf:	48 8d bd e0 e1 ff ff 	lea    -0x1e20(%rbp),%rdi
 11bfce6:	48 8d b5 00 f2 ff ff 	lea    -0xe00(%rbp),%rsi
 11bfced:	e8 ee 44 00 00       	call   11c41e0 <huffman.HuffmanTable(79).Encoder.init>
 11bfcf2:	0f b7 85 ce e2 ff ff 	movzwl -0x1d32(%rbp),%eax
 11bfcf9:	66 85 c0             	test   %ax,%ax
 11bfcfc:	0f 85 ab bd ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bfd02:	c5 fc 10 85 ae e2 ff 	vmovups -0x1d52(%rbp),%ymm0
 11bfd09:	ff 
 11bfd0a:	c5 fc 11 85 ce db ff 	vmovups %ymm0,-0x2432(%rbp)
 11bfd11:	ff 
 11bfd12:	c5 fc 10 85 a0 e2 ff 	vmovups -0x1d60(%rbp),%ymm0
 11bfd19:	ff 
 11bfd1a:	c5 fc 11 85 c0 db ff 	vmovups %ymm0,-0x2440(%rbp)
 11bfd21:	ff 
 11bfd22:	c5 fc 10 85 80 e2 ff 	vmovups -0x1d80(%rbp),%ymm0
 11bfd29:	ff 
 11bfd2a:	c5 fc 11 85 a0 db ff 	vmovups %ymm0,-0x2460(%rbp)
 11bfd31:	ff 
 11bfd32:	c5 fc 10 85 60 e2 ff 	vmovups -0x1da0(%rbp),%ymm0
 11bfd39:	ff 
 11bfd3a:	c5 fc 11 85 80 db ff 	vmovups %ymm0,-0x2480(%rbp)
 11bfd41:	ff 
 11bfd42:	c5 fc 10 85 e0 e1 ff 	vmovups -0x1e20(%rbp),%ymm0
 11bfd49:	ff 
 11bfd4a:	c5 fc 10 8d 20 e2 ff 	vmovups -0x1de0(%rbp),%ymm1
 11bfd51:	ff 
 11bfd52:	c5 fc 10 95 40 e2 ff 	vmovups -0x1dc0(%rbp),%ymm2
 11bfd59:	ff 
 11bfd5a:	c5 fc 11 95 60 db ff 	vmovups %ymm2,-0x24a0(%rbp)
 11bfd61:	ff 
 11bfd62:	c5 fc 11 8d 40 db ff 	vmovups %ymm1,-0x24c0(%rbp)
 11bfd69:	ff 
 11bfd6a:	c5 fc 10 8d 00 e2 ff 	vmovups -0x1e00(%rbp),%ymm1
 11bfd71:	ff 
 11bfd72:	c5 fc 11 8d 20 db ff 	vmovups %ymm1,-0x24e0(%rbp)
 11bfd79:	ff 
 11bfd7a:	c5 fc 11 85 00 db ff 	vmovups %ymm0,-0x2500(%rbp)
 11bfd81:	ff 
 11bfd82:	48 8d 85 00 db ff ff 	lea    -0x2500(%rbp),%rax
 11bfd89:	c5 fc 10 80 ce 00 00 	vmovups 0xce(%rax),%ymm0
 11bfd90:	00 
 11bfd91:	c5 fc 11 85 3e ef ff 	vmovups %ymm0,-0x10c2(%rbp)
 11bfd98:	ff 
 11bfd99:	c5 fc 10 80 c0 00 00 	vmovups 0xc0(%rax),%ymm0
 11bfda0:	00 
 11bfda1:	c5 fc 11 85 30 ef ff 	vmovups %ymm0,-0x10d0(%rbp)
 11bfda8:	ff 
 11bfda9:	c5 fc 10 80 a0 00 00 	vmovups 0xa0(%rax),%ymm0
 11bfdb0:	00 
 11bfdb1:	c5 fc 11 85 10 ef ff 	vmovups %ymm0,-0x10f0(%rbp)
 11bfdb8:	ff 
 11bfdb9:	c5 fc 10 80 80 00 00 	vmovups 0x80(%rax),%ymm0
 11bfdc0:	00 
 11bfdc1:	c5 fc 11 85 f0 ee ff 	vmovups %ymm0,-0x1110(%rbp)
 11bfdc8:	ff 
 11bfdc9:	c5 fc 10 00          	vmovups (%rax),%ymm0
 11bfdcd:	c5 fc 10 48 40       	vmovups 0x40(%rax),%ymm1
 11bfdd2:	c5 fc 10 50 60       	vmovups 0x60(%rax),%ymm2
 11bfdd7:	c5 fc 11 95 d0 ee ff 	vmovups %ymm2,-0x1130(%rbp)
 11bfdde:	ff 
 11bfddf:	c5 fc 11 8d b0 ee ff 	vmovups %ymm1,-0x1150(%rbp)
 11bfde6:	ff 
 11bfde7:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 11bfdec:	c5 fc 11 8d 90 ee ff 	vmovups %ymm1,-0x1170(%rbp)
 11bfdf3:	ff 
 11bfdf4:	c5 fc 11 85 70 ee ff 	vmovups %ymm0,-0x1190(%rbp)
 11bfdfb:	ff 
 11bfdfc:	bb b8 3a 05 01       	mov    $0x1053ab8,%ebx
 11bfe01:	48 8d bd 8a 40 ff ff 	lea    -0xbf76(%rbp),%rdi
 11bfe08:	ba 94 05 00 00       	mov    $0x594,%edx
 11bfe0d:	48 89 de             	mov    %rbx,%rsi
 11bfe10:	c5 f8 77             	vzeroupper 
 11bfe13:	e8 48 f9 11 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11bfe18:	c5 fc 10 85 e0 ef ff 	vmovups -0x1020(%rbp),%ymm0
 11bfe1f:	ff 
 11bfe20:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 11bfe27:	ff 
 11bfe28:	80 7d ca 01          	cmpb   $0x1,-0x36(%rbp)
 11bfe2c:	be 02 00 00 00       	mov    $0x2,%esi
 11bfe31:	bf 02 00 00 00       	mov    $0x2,%edi
 11bfe36:	48 83 df 00          	sbb    $0x0,%rdi
 11bfe3a:	80 7d c5 01          	cmpb   $0x1,-0x3b(%rbp)
 11bfe3e:	41 b8 02 00 00 00    	mov    $0x2,%r8d
 11bfe44:	49 83 d8 00          	sbb    $0x0,%r8
 11bfe48:	80 7d d5 01          	cmpb   $0x1,-0x2b(%rbp)
 11bfe4c:	48 83 de 00          	sbb    $0x0,%rsi
 11bfe50:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 11bfe54:	b8 03 00 00 00       	mov    $0x3,%eax
 11bfe59:	48 0f 45 f8          	cmovne %rax,%rdi
 11bfe5d:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 11bfe61:	b9 04 00 00 00       	mov    $0x4,%ecx
 11bfe66:	48 0f 45 f9          	cmovne %rcx,%rdi
 11bfe6a:	80 7d cd 00          	cmpb   $0x0,-0x33(%rbp)
 11bfe6e:	ba 05 00 00 00       	mov    $0x5,%edx
 11bfe73:	48 0f 45 fa          	cmovne %rdx,%rdi
 11bfe77:	48 89 bd e8 fc ff ff 	mov    %rdi,-0x318(%rbp)
 11bfe7e:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 11bfe82:	4c 0f 45 c0          	cmovne %rax,%r8
 11bfe86:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 11bfe8a:	4c 0f 45 c1          	cmovne %rcx,%r8
 11bfe8e:	80 7d c7 00          	cmpb   $0x0,-0x39(%rbp)
 11bfe92:	4c 0f 45 c2          	cmovne %rdx,%r8
 11bfe96:	4c 89 85 58 fe ff ff 	mov    %r8,-0x1a8(%rbp)
 11bfe9d:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 11bfea1:	48 0f 45 f0          	cmovne %rax,%rsi
 11bfea5:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 11bfea9:	48 0f 45 f1          	cmovne %rcx,%rsi
 11bfead:	80 7d ce 00          	cmpb   $0x0,-0x32(%rbp)
 11bfeb1:	48 0f 45 f2          	cmovne %rdx,%rsi
 11bfeb5:	48 89 b5 f0 fc ff ff 	mov    %rsi,-0x310(%rbp)
 11bfebc:	80 65 9f 0f          	andb   $0xf,-0x61(%rbp)
 11bfec0:	48 c7 45 80 00 00 00 	movq   $0x0,-0x80(%rbp)
 11bfec7:	00 
 11bfec8:	48 c7 85 e0 fd ff ff 	movq   $0x0,-0x220(%rbp)
 11bfecf:	00 00 00 00 
 11bfed3:	45 31 ff             	xor    %r15d,%r15d
 11bfed6:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 11bfeda:	48 8d 04 40          	lea    (%rax,%rax,2),%rax
 11bfede:	48 c1 e0 05          	shl    $0x5,%rax
 11bfee2:	48 8b 8d f8 fd ff ff 	mov    -0x208(%rbp),%rcx
 11bfee9:	c5 fc 10 04 01       	vmovups (%rcx,%rax,1),%ymm0
 11bfeee:	c5 fc 10 4c 01 20    	vmovups 0x20(%rcx,%rax,1),%ymm1
 11bfef4:	c5 fc 10 54 01 40    	vmovups 0x40(%rcx,%rax,1),%ymm2
 11bfefa:	c5 fc 11 85 50 f2 ff 	vmovups %ymm0,-0xdb0(%rbp)
 11bff01:	ff 
 11bff02:	c5 fc 11 95 90 f2 ff 	vmovups %ymm2,-0xd70(%rbp)
 11bff09:	ff 
 11bff0a:	c5 fc 11 8d 70 f2 ff 	vmovups %ymm1,-0xd90(%rbp)
 11bff11:	ff 
 11bff12:	48 8b 85 50 f2 ff ff 	mov    -0xdb0(%rbp),%rax
 11bff19:	48 89 85 70 fd ff ff 	mov    %rax,-0x290(%rbp)
 11bff20:	48 8b 85 58 f2 ff ff 	mov    -0xda8(%rbp),%rax
 11bff27:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 11bff2b:	48 8b 85 60 f2 ff ff 	mov    -0xda0(%rbp),%rax
 11bff32:	48 89 85 40 fe ff ff 	mov    %rax,-0x1c0(%rbp)
 11bff39:	0f b6 8d a8 f2 ff ff 	movzbl -0xd58(%rbp),%ecx
 11bff40:	0f b6 85 a9 f2 ff ff 	movzbl -0xd57(%rbp),%eax
 11bff47:	88 85 80 fd ff ff    	mov    %al,-0x280(%rbp)
 11bff4d:	88 8d 60 ff ff ff    	mov    %cl,-0xa0(%rbp)
 11bff53:	88 8d a8 fd ff ff    	mov    %cl,-0x258(%rbp)
 11bff59:	f6 c1 01             	test   $0x1,%cl
 11bff5c:	74 4a                	je     11bffa8 <br.encodeCommandPlanWithOptionsWrite+0x4568>
 11bff5e:	48 8d bd e0 f8 ff ff 	lea    -0x720(%rbp),%rdi
 11bff65:	48 8d b5 50 f2 ff ff 	lea    -0xdb0(%rbp),%rsi
 11bff6c:	8b 95 68 fd ff ff    	mov    -0x298(%rbp),%edx
 11bff72:	48 8b 8d f8 fb ff ff 	mov    -0x408(%rbp),%rcx
 11bff79:	4c 8b 85 f0 fb ff ff 	mov    -0x410(%rbp),%r8
 11bff80:	c5 f8 77             	vzeroupper 
 11bff83:	e8 48 19 04 00       	call   12018d0 <br.commandWireDistance>
 11bff88:	0f b7 85 e8 f8 ff ff 	movzwl -0x718(%rbp),%eax
 11bff8f:	66 85 c0             	test   %ax,%ax
 11bff92:	0f 85 15 bb ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bff98:	48 8b 85 e0 f8 ff ff 	mov    -0x720(%rbp),%rax
 11bff9f:	48 89 85 e8 fd ff ff 	mov    %rax,-0x218(%rbp)
 11bffa6:	eb 0b                	jmp    11bffb3 <br.encodeCommandPlanWithOptionsWrite+0x4573>
 11bffa8:	48 c7 85 e8 fd ff ff 	movq   $0x0,-0x218(%rbp)
 11bffaf:	00 00 00 00 
 11bffb3:	48 83 ec 08          	sub    $0x8,%rsp
 11bffb7:	48 8d bd 10 f3 ff ff 	lea    -0xcf0(%rbp),%rdi
 11bffbe:	48 8d b5 50 f2 ff ff 	lea    -0xdb0(%rbp),%rsi
 11bffc5:	48 8b 95 e8 fd ff ff 	mov    -0x218(%rbp),%rdx
 11bffcc:	8b 8d 30 fe ff ff    	mov    -0x1d0(%rbp),%ecx
 11bffd2:	44 8b 85 34 fe ff ff 	mov    -0x1cc(%rbp),%r8d
 11bffd9:	4c 8d 8d 20 fd ff ff 	lea    -0x2e0(%rbp),%r9
 11bffe0:	6a 00                	push   $0x0
 11bffe2:	c5 f8 77             	vzeroupper 
 11bffe5:	e8 36 14 04 00       	call   1201420 <br.resolveHqCommand>
 11bffea:	48 83 c4 10          	add    $0x10,%rsp
 11bffee:	0f b7 85 58 f3 ff ff 	movzwl -0xca8(%rbp),%eax
 11bfff5:	66 85 c0             	test   %ax,%ax
 11bfff8:	0f 85 af ba ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11bfffe:	c5 fc 10 85 10 f3 ff 	vmovups -0xcf0(%rbp),%ymm0
 11c0005:	ff 
 11c0006:	c5 fc 10 8d 20 f3 ff 	vmovups -0xce0(%rbp),%ymm1
 11c000d:	ff 
 11c000e:	c5 fc 11 8d 50 ee ff 	vmovups %ymm1,-0x11b0(%rbp)
 11c0015:	ff 
 11c0016:	c5 fc 11 85 40 ee ff 	vmovups %ymm0,-0x11c0(%rbp)
 11c001d:	ff 
 11c001e:	48 8b 85 40 f3 ff ff 	mov    -0xcc0(%rbp),%rax
 11c0025:	48 89 85 b0 fd ff ff 	mov    %rax,-0x250(%rbp)
 11c002c:	0f b6 85 48 f3 ff ff 	movzbl -0xcb8(%rbp),%eax
 11c0033:	88 45 9e             	mov    %al,-0x62(%rbp)
 11c0036:	44 0f b6 a5 4c f3 ff 	movzbl -0xcb4(%rbp),%r12d
 11c003d:	ff 
 11c003e:	0f b6 9d 4d f3 ff ff 	movzbl -0xcb3(%rbp),%ebx
 11c0045:	0f b6 85 50 f3 ff ff 	movzbl -0xcb0(%rbp),%eax
 11c004c:	88 85 e0 fe ff ff    	mov    %al,-0x120(%rbp)
 11c0052:	0f b6 85 5f be ff ff 	movzbl -0x41a1(%rbp),%eax
 11c0059:	88 85 60 fd ff ff    	mov    %al,-0x2a0(%rbp)
 11c005f:	84 c0                	test   %al,%al
 11c0061:	74 3b                	je     11c009e <br.encodeCommandPlanWithOptionsWrite+0x465e>
 11c0063:	48 8b 8d 38 fd ff ff 	mov    -0x2c8(%rbp),%rcx
 11c006a:	4c 8d ad 8a fd ff ff 	lea    -0x276(%rbp),%r13
 11c0071:	4c 89 ef             	mov    %r13,%rdi
 11c0074:	48 8d b5 50 f2 ff ff 	lea    -0xdb0(%rbp),%rsi
 11c007b:	48 8b 95 e8 fd ff ff 	mov    -0x218(%rbp),%rdx
 11c0082:	c5 f8 77             	vzeroupper 
 11c0085:	e8 46 0c 04 00       	call   1200cd0 <br.sameLastDistanceShape>
 11c008a:	4c 8d b5 8c fd ff ff 	lea    -0x274(%rbp),%r14
 11c0091:	48 8d 85 8b fd ff ff 	lea    -0x275(%rbp),%rax
 11c0098:	48 89 45 88          	mov    %rax,-0x78(%rbp)
 11c009c:	eb 15                	jmp    11c00b3 <br.encodeCommandPlanWithOptionsWrite+0x4673>
 11c009e:	41 bd e2 c6 03 01    	mov    $0x103c6e2,%r13d
 11c00a4:	b8 e3 c6 03 01       	mov    $0x103c6e3,%eax
 11c00a9:	48 89 45 88          	mov    %rax,-0x78(%rbp)
 11c00ad:	41 be e4 c6 03 01    	mov    $0x103c6e4,%r14d
 11c00b3:	80 bd e0 fe ff ff 00 	cmpb   $0x0,-0x120(%rbp)
 11c00ba:	0f 84 d3 00 00 00    	je     11c0193 <br.encodeCommandPlanWithOptionsWrite+0x4753>
 11c00c0:	44 88 a5 4d ff ff ff 	mov    %r12b,-0xb3(%rbp)
 11c00c7:	88 9d 4e ff ff ff    	mov    %bl,-0xb2(%rbp)
 11c00cd:	48 8d 85 4e ff ff ff 	lea    -0xb2(%rbp),%rax
 11c00d4:	48 89 85 80 fe ff ff 	mov    %rax,-0x180(%rbp)
 11c00db:	48 8d 85 4d ff ff ff 	lea    -0xb3(%rbp),%rax
 11c00e2:	48 89 85 48 fe ff ff 	mov    %rax,-0x1b8(%rbp)
 11c00e9:	41 80 3e 00          	cmpb   $0x0,(%r14)
 11c00ed:	0f 85 c2 00 00 00    	jne    11c01b5 <br.encodeCommandPlanWithOptionsWrite+0x4775>
 11c00f3:	b1 01                	mov    $0x1,%cl
 11c00f5:	48 8b 85 80 fe ff ff 	mov    -0x180(%rbp),%rax
 11c00fc:	80 38 00             	cmpb   $0x0,(%rax)
 11c00ff:	0f 84 a2 01 00 00    	je     11c02a7 <br.encodeCommandPlanWithOptionsWrite+0x4867>
 11c0105:	48 8b 85 48 fe ff ff 	mov    -0x1b8(%rbp),%rax
 11c010c:	0f b6 00             	movzbl (%rax),%eax
 11c010f:	24 0f                	and    $0xf,%al
 11c0111:	3a 45 9f             	cmp    -0x61(%rbp),%al
 11c0114:	0f 94 c0             	sete   %al
 11c0117:	80 bd e0 fe ff ff 00 	cmpb   $0x0,-0x120(%rbp)
 11c011e:	0f 85 c5 00 00 00    	jne    11c01e9 <br.encodeCommandPlanWithOptionsWrite+0x47a9>
 11c0124:	48 81 bd 40 ff ff ff 	cmpq   $0x81,-0xc0(%rbp)
 11c012b:	81 00 00 00 
 11c012f:	0f 93 c2             	setae  %dl
 11c0132:	0a 95 60 fd ff ff    	or     -0x2a0(%rbp),%dl
 11c0138:	0f 84 ca 00 00 00    	je     11c0208 <br.encodeCommandPlanWithOptionsWrite+0x47c8>
 11c013e:	84 c9                	test   %cl,%cl
 11c0140:	0f 84 75 01 00 00    	je     11c02bb <br.encodeCommandPlanWithOptionsWrite+0x487b>
 11c0146:	0f b6 c8             	movzbl %al,%ecx
 11c0149:	48 8d bd fc f3 ff ff 	lea    -0xc04(%rbp),%rdi
 11c0150:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 11c0154:	48 8b 95 40 fe ff ff 	mov    -0x1c0(%rbp),%rdx
 11c015b:	c5 f8 77             	vzeroupper 
 11c015e:	e8 4d 10 04 00       	call   12011b0 <br.commandEntryForLengthsAndDistance>
 11c0163:	80 bd 0c f4 ff ff 00 	cmpb   $0x0,-0xbf4(%rbp)
 11c016a:	0f 84 c3 01 00 00    	je     11c0333 <br.encodeCommandPlanWithOptionsWrite+0x48f3>
 11c0170:	c5 f8 10 85 fc f3 ff 	vmovups -0xc04(%rbp),%xmm0
 11c0177:	ff 
 11c0178:	c5 f8 29 85 10 f4 ff 	vmovaps %xmm0,-0xbf0(%rbp)
 11c017f:	ff 
 11c0180:	c6 85 20 f4 ff ff 01 	movb   $0x1,-0xbe0(%rbp)
 11c0187:	48 8d 85 10 f4 ff ff 	lea    -0xbf0(%rbp),%rax
 11c018e:	e9 bd 01 00 00       	jmp    11c0350 <br.encodeCommandPlanWithOptionsWrite+0x4910>
 11c0193:	41 80 3e 00          	cmpb   $0x0,(%r14)
 11c0197:	0f 84 ab 00 00 00    	je     11c0248 <br.encodeCommandPlanWithOptionsWrite+0x4808>
 11c019d:	b8 e1 c6 03 01       	mov    $0x103c6e1,%eax
 11c01a2:	48 89 85 80 fe ff ff 	mov    %rax,-0x180(%rbp)
 11c01a9:	b8 e0 c6 03 01       	mov    $0x103c6e0,%eax
 11c01ae:	48 89 85 48 fe ff ff 	mov    %rax,-0x1b8(%rbp)
 11c01b5:	41 0f b6 45 00       	movzbl 0x0(%r13),%eax
 11c01ba:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 11c01be:	0f b6 09             	movzbl (%rcx),%ecx
 11c01c1:	83 e0 1f             	and    $0x1f,%eax
 11c01c4:	48 8d 04 40          	lea    (%rax,%rax,2),%rax
 11c01c8:	48 8d 95 60 be ff ff 	lea    -0x41a0(%rbp),%rdx
 11c01cf:	48 8d 04 c2          	lea    (%rdx,%rax,8),%rax
 11c01d3:	83 e1 1f             	and    $0x1f,%ecx
 11c01d6:	0f b6 04 01          	movzbl (%rcx,%rax,1),%eax
 11c01da:	31 c9                	xor    %ecx,%ecx
 11c01dc:	80 bd e0 fe ff ff 00 	cmpb   $0x0,-0x120(%rbp)
 11c01e3:	0f 84 3b ff ff ff    	je     11c0124 <br.encodeCommandPlanWithOptionsWrite+0x46e4>
 11c01e9:	48 8d 85 30 f3 ff ff 	lea    -0xcd0(%rbp),%rax
 11c01f0:	c5 f8 10 00          	vmovups (%rax),%xmm0
 11c01f4:	c5 f8 29 85 70 f3 ff 	vmovaps %xmm0,-0xc90(%rbp)
 11c01fb:	ff 
 11c01fc:	48 8d 85 70 f3 ff ff 	lea    -0xc90(%rbp),%rax
 11c0203:	e9 a5 01 00 00       	jmp    11c03ad <br.encodeCommandPlanWithOptionsWrite+0x496d>
 11c0208:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 11c020c:	0f b7 84 45 a0 c4 ff 	movzwl -0x3b60(%rbp,%rax,2),%eax
 11c0213:	ff 
 11c0214:	89 c1                	mov    %eax,%ecx
 11c0216:	c1 e1 02             	shl    $0x2,%ecx
 11c0219:	48 8b 94 49 4c 40 05 	mov    0x105404c(%rcx,%rcx,2),%rdx
 11c0220:	01 
 11c0221:	48 89 95 28 fa ff ff 	mov    %rdx,-0x5d8(%rbp)
 11c0228:	8b 8c 49 54 40 05 01 	mov    0x1054054(%rcx,%rcx,2),%ecx
 11c022f:	89 8d 30 fa ff ff    	mov    %ecx,-0x5d0(%rbp)
 11c0235:	66 89 85 34 fa ff ff 	mov    %ax,-0x5cc(%rbp)
 11c023c:	48 8d 85 28 fa ff ff 	lea    -0x5d8(%rbp),%rax
 11c0243:	e9 65 01 00 00       	jmp    11c03ad <br.encodeCommandPlanWithOptionsWrite+0x496d>
 11c0248:	0f b6 45 9c          	movzbl -0x64(%rbp),%eax
 11c024c:	22 85 a8 fd ff ff    	and    -0x258(%rbp),%al
 11c0252:	0f b6 8d 80 fd ff ff 	movzbl -0x280(%rbp),%ecx
 11c0259:	80 e1 03             	and    $0x3,%cl
 11c025c:	80 f9 02             	cmp    $0x2,%cl
 11c025f:	0f 95 c1             	setne  %cl
 11c0262:	20 c1                	and    %al,%cl
 11c0264:	80 f9 01             	cmp    $0x1,%cl
 11c0267:	0f 85 a9 00 00 00    	jne    11c0316 <br.encodeCommandPlanWithOptionsWrite+0x48d6>
 11c026d:	48 8d 9d 88 fd ff ff 	lea    -0x278(%rbp),%rbx
 11c0274:	48 89 df             	mov    %rbx,%rdi
 11c0277:	48 8b b5 e8 fd ff ff 	mov    -0x218(%rbp),%rsi
 11c027e:	48 8d 95 20 fd ff ff 	lea    -0x2e0(%rbp),%rdx
 11c0285:	c5 f8 77             	vzeroupper 
 11c0288:	e8 13 10 04 00       	call   12012a0 <br.decoder.distance_history.symbolForDistance>
 11c028d:	48 8d 85 89 fd ff ff 	lea    -0x277(%rbp),%rax
 11c0294:	48 89 85 80 fe ff ff 	mov    %rax,-0x180(%rbp)
 11c029b:	48 89 9d 48 fe ff ff 	mov    %rbx,-0x1b8(%rbp)
 11c02a2:	e9 42 fe ff ff       	jmp    11c00e9 <br.encodeCommandPlanWithOptionsWrite+0x46a9>
 11c02a7:	31 c0                	xor    %eax,%eax
 11c02a9:	80 bd e0 fe ff ff 00 	cmpb   $0x0,-0x120(%rbp)
 11c02b0:	0f 85 33 ff ff ff    	jne    11c01e9 <br.encodeCommandPlanWithOptionsWrite+0x47a9>
 11c02b6:	e9 69 fe ff ff       	jmp    11c0124 <br.encodeCommandPlanWithOptionsWrite+0x46e4>
 11c02bb:	41 0f b6 4d 00       	movzbl 0x0(%r13),%ecx
 11c02c0:	48 8b 55 88          	mov    -0x78(%rbp),%rdx
 11c02c4:	0f b6 12             	movzbl (%rdx),%edx
 11c02c7:	a8 01                	test   $0x1,%al
 11c02c9:	b8 68 80 05 01       	mov    $0x1058068,%eax
 11c02ce:	be e8 7b 05 01       	mov    $0x1057be8,%esi
 11c02d3:	48 0f 45 c6          	cmovne %rsi,%rax
 11c02d7:	83 e1 1f             	and    $0x1f,%ecx
 11c02da:	48 8d 0c 49          	lea    (%rcx,%rcx,2),%rcx
 11c02de:	c1 e1 04             	shl    $0x4,%ecx
 11c02e1:	48 01 c1             	add    %rax,%rcx
 11c02e4:	83 e2 1f             	and    $0x1f,%edx
 11c02e7:	0f b7 04 51          	movzwl (%rcx,%rdx,2),%eax
 11c02eb:	48 3d ff ff 00 00    	cmp    $0xffff,%rax
 11c02f1:	74 72                	je     11c0365 <br.encodeCommandPlanWithOptionsWrite+0x4925>
 11c02f3:	89 c1                	mov    %eax,%ecx
 11c02f5:	c1 e1 02             	shl    $0x2,%ecx
 11c02f8:	8b 94 49 54 40 05 01 	mov    0x1054054(%rcx,%rcx,2),%edx
 11c02ff:	89 95 28 fc ff ff    	mov    %edx,-0x3d8(%rbp)
 11c0305:	48 8b 8c 49 4c 40 05 	mov    0x105404c(%rcx,%rcx,2),%rcx
 11c030c:	01 
 11c030d:	48 89 8d 20 fc ff ff 	mov    %rcx,-0x3e0(%rbp)
 11c0314:	eb 66                	jmp    11c037c <br.encodeCommandPlanWithOptionsWrite+0x493c>
 11c0316:	b8 d4 6e 03 01       	mov    $0x1036ed4,%eax
 11c031b:	48 89 85 48 fe ff ff 	mov    %rax,-0x1b8(%rbp)
 11c0322:	b8 d5 6e 03 01       	mov    $0x1036ed5,%eax
 11c0327:	48 89 85 80 fe ff ff 	mov    %rax,-0x180(%rbp)
 11c032e:	e9 b6 fd ff ff       	jmp    11c00e9 <br.encodeCommandPlanWithOptionsWrite+0x46a9>
 11c0333:	48 8d 9d 6c e9 ff ff 	lea    -0x1694(%rbp),%rbx
 11c033a:	48 89 df             	mov    %rbx,%rdi
 11c033d:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 11c0341:	48 8b 95 40 fe ff ff 	mov    -0x1c0(%rbp),%rdx
 11c0348:	e8 43 0a 04 00       	call   1200d90 <br.commandEntryForLengths>
 11c034d:	48 89 d8             	mov    %rbx,%rax
 11c0350:	c5 f8 10 00          	vmovups (%rax),%xmm0
 11c0354:	c5 f8 29 85 60 f3 ff 	vmovaps %xmm0,-0xca0(%rbp)
 11c035b:	ff 
 11c035c:	48 8d 85 60 f3 ff ff 	lea    -0xca0(%rbp),%rax
 11c0363:	eb 48                	jmp    11c03ad <br.encodeCommandPlanWithOptionsWrite+0x496d>
 11c0365:	c7 85 28 fc ff ff 00 	movl   $0x0,-0x3d8(%rbp)
 11c036c:	00 00 00 
 11c036f:	48 c7 85 20 fc ff ff 	movq   $0x0,-0x3e0(%rbp)
 11c0376:	00 00 00 00 
 11c037a:	31 c0                	xor    %eax,%eax
 11c037c:	8b 8d 28 fc ff ff    	mov    -0x3d8(%rbp),%ecx
 11c0382:	89 8d 90 fb ff ff    	mov    %ecx,-0x470(%rbp)
 11c0388:	48 8b 8d 20 fc ff ff 	mov    -0x3e0(%rbp),%rcx
 11c038f:	48 89 8d 88 fb ff ff 	mov    %rcx,-0x478(%rbp)
 11c0396:	66 89 85 94 fb ff ff 	mov    %ax,-0x46c(%rbp)
 11c039d:	66 c7 85 96 fb ff ff 	movw   $0x0,-0x46a(%rbp)
 11c03a4:	00 00 
 11c03a6:	48 8d 85 88 fb ff ff 	lea    -0x478(%rbp),%rax
 11c03ad:	48 89 45 88          	mov    %rax,-0x78(%rbp)
 11c03b1:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 11c03b5:	0f b6 41 0a          	movzbl 0xa(%rcx),%eax
 11c03b9:	88 85 60 fd ff ff    	mov    %al,-0x2a0(%rbp)
 11c03bf:	0f b7 41 0c          	movzwl 0xc(%rcx),%eax
 11c03c3:	48 89 85 b8 fd ff ff 	mov    %rax,-0x248(%rbp)
 11c03ca:	4c 8d a5 a0 c5 ff ff 	lea    -0x3a60(%rbp),%r12
 11c03d1:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 11c03d5:	0f 84 41 01 00 00    	je     11c051c <br.encodeCommandPlanWithOptionsWrite+0x4adc>
 11c03db:	8b 85 8b fe ff ff    	mov    -0x175(%rbp),%eax
 11c03e1:	48 8d 8d e1 f5 ff ff 	lea    -0xa1f(%rbp),%rcx
 11c03e8:	89 41 03             	mov    %eax,0x3(%rcx)
 11c03eb:	8b 85 88 fe ff ff    	mov    -0x178(%rbp),%eax
 11c03f1:	89 01                	mov    %eax,(%rcx)
 11c03f3:	8b 85 93 fe ff ff    	mov    -0x16d(%rbp),%eax
 11c03f9:	89 41 13             	mov    %eax,0x13(%rcx)
 11c03fc:	8b 85 90 fe ff ff    	mov    -0x170(%rbp),%eax
 11c0402:	89 41 10             	mov    %eax,0x10(%rcx)
 11c0405:	8b 85 9b fe ff ff    	mov    -0x165(%rbp),%eax
 11c040b:	89 41 23             	mov    %eax,0x23(%rcx)
 11c040e:	8b 85 98 fe ff ff    	mov    -0x168(%rbp),%eax
 11c0414:	89 41 20             	mov    %eax,0x20(%rcx)
 11c0417:	8b 85 a3 fe ff ff    	mov    -0x15d(%rbp),%eax
 11c041d:	89 41 33             	mov    %eax,0x33(%rcx)
 11c0420:	8b 85 a0 fe ff ff    	mov    -0x160(%rbp),%eax
 11c0426:	89 41 30             	mov    %eax,0x30(%rcx)
 11c0429:	8b 85 ab fe ff ff    	mov    -0x155(%rbp),%eax
 11c042f:	89 41 43             	mov    %eax,0x43(%rcx)
 11c0432:	8b 85 a8 fe ff ff    	mov    -0x158(%rbp),%eax
 11c0438:	89 41 40             	mov    %eax,0x40(%rcx)
 11c043b:	0f b7 85 f0 fe ff ff 	movzwl -0x110(%rbp),%eax
 11c0442:	66 89 41 55          	mov    %ax,0x55(%rcx)
 11c0446:	8b 85 ec fe ff ff    	mov    -0x114(%rbp),%eax
 11c044c:	89 41 51             	mov    %eax,0x51(%rcx)
 11c044f:	48 8b 85 38 fe ff ff 	mov    -0x1c8(%rbp),%rax
 11c0456:	48 89 85 d0 f5 ff ff 	mov    %rax,-0xa30(%rbp)
 11c045d:	48 8b 85 c0 fd ff ff 	mov    -0x240(%rbp),%rax
 11c0464:	48 89 85 d8 f5 ff ff 	mov    %rax,-0xa28(%rbp)
 11c046b:	0f b6 45 ca          	movzbl -0x36(%rbp),%eax
 11c046f:	88 85 e0 f5 ff ff    	mov    %al,-0xa20(%rbp)
 11c0475:	48 8b 85 c8 fd ff ff 	mov    -0x238(%rbp),%rax
 11c047c:	48 89 85 e8 f5 ff ff 	mov    %rax,-0xa18(%rbp)
 11c0483:	0f b6 45 d0          	movzbl -0x30(%rbp),%eax
 11c0487:	88 85 f0 f5 ff ff    	mov    %al,-0xa10(%rbp)
 11c048d:	48 8b 85 d0 fd ff ff 	mov    -0x230(%rbp),%rax
 11c0494:	48 89 85 f8 f5 ff ff 	mov    %rax,-0xa08(%rbp)
 11c049b:	0f b6 45 d6          	movzbl -0x2a(%rbp),%eax
 11c049f:	88 85 00 f6 ff ff    	mov    %al,-0xa00(%rbp)
 11c04a5:	48 8b 85 d8 fd ff ff 	mov    -0x228(%rbp),%rax
 11c04ac:	48 89 85 08 f6 ff ff 	mov    %rax,-0x9f8(%rbp)
 11c04b3:	0f b6 45 cd          	movzbl -0x33(%rbp),%eax
 11c04b7:	88 85 10 f6 ff ff    	mov    %al,-0x9f0(%rbp)
 11c04bd:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 11c04c4:	48 89 85 18 f6 ff ff 	mov    %rax,-0x9e8(%rbp)
 11c04cb:	0f b6 45 c1          	movzbl -0x3f(%rbp),%eax
 11c04cf:	88 85 20 f6 ff ff    	mov    %al,-0x9e0(%rbp)
 11c04d5:	48 8b 85 f8 fc ff ff 	mov    -0x308(%rbp),%rax
 11c04dc:	48 89 85 28 f6 ff ff 	mov    %rax,-0x9d8(%rbp)
 11c04e3:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 11c04e7:	88 85 30 f6 ff ff    	mov    %al,-0x9d0(%rbp)
 11c04ed:	0f b6 45 c8          	movzbl -0x38(%rbp),%eax
 11c04f1:	88 85 31 f6 ff ff    	mov    %al,-0x9cf(%rbp)
 11c04f7:	48 8d bd d0 f5 ff ff 	lea    -0xa30(%rbp),%rdi
 11c04fe:	48 8b 75 80          	mov    -0x80(%rbp),%rsi
 11c0502:	c5 f8 77             	vzeroupper 
 11c0505:	e8 36 06 04 00       	call   1200b40 <br.encoder.command_block_split.Result.blockIndex>
 11c050a:	48 69 c0 88 05 00 00 	imul   $0x588,%rax,%rax
 11c0511:	4c 8d 24 28          	lea    (%rax,%rbp,1),%r12
 11c0515:	49 81 c4 d8 fc fe ff 	add    $0xfffffffffffefcd8,%r12
 11c051c:	4c 8d b5 fa 74 ff ff 	lea    -0x8b06(%rbp),%r14
 11c0523:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 11c0527:	0f 84 ec 01 00 00    	je     11c0719 <br.encodeCommandPlanWithOptionsWrite+0x4cd9>
 11c052d:	8b 85 8b fe ff ff    	mov    -0x175(%rbp),%eax
 11c0533:	48 8d 8d 79 f5 ff ff 	lea    -0xa87(%rbp),%rcx
 11c053a:	89 41 03             	mov    %eax,0x3(%rcx)
 11c053d:	8b 85 88 fe ff ff    	mov    -0x178(%rbp),%eax
 11c0543:	89 01                	mov    %eax,(%rcx)
 11c0545:	8b 85 93 fe ff ff    	mov    -0x16d(%rbp),%eax
 11c054b:	89 41 13             	mov    %eax,0x13(%rcx)
 11c054e:	8b 85 90 fe ff ff    	mov    -0x170(%rbp),%eax
 11c0554:	89 41 10             	mov    %eax,0x10(%rcx)
 11c0557:	8b 85 9b fe ff ff    	mov    -0x165(%rbp),%eax
 11c055d:	89 41 23             	mov    %eax,0x23(%rcx)
 11c0560:	8b 85 98 fe ff ff    	mov    -0x168(%rbp),%eax
 11c0566:	89 41 20             	mov    %eax,0x20(%rcx)
 11c0569:	8b 85 a3 fe ff ff    	mov    -0x15d(%rbp),%eax
 11c056f:	89 41 33             	mov    %eax,0x33(%rcx)
 11c0572:	8b 85 a0 fe ff ff    	mov    -0x160(%rbp),%eax
 11c0578:	89 41 30             	mov    %eax,0x30(%rcx)
 11c057b:	8b 85 ab fe ff ff    	mov    -0x155(%rbp),%eax
 11c0581:	89 41 43             	mov    %eax,0x43(%rcx)
 11c0584:	8b 85 a8 fe ff ff    	mov    -0x158(%rbp),%eax
 11c058a:	89 41 40             	mov    %eax,0x40(%rcx)
 11c058d:	0f b7 85 f0 fe ff ff 	movzwl -0x110(%rbp),%eax
 11c0594:	66 89 41 55          	mov    %ax,0x55(%rcx)
 11c0598:	8b 85 ec fe ff ff    	mov    -0x114(%rbp),%eax
 11c059e:	89 41 51             	mov    %eax,0x51(%rcx)
 11c05a1:	48 8b 85 38 fe ff ff 	mov    -0x1c8(%rbp),%rax
 11c05a8:	48 89 85 68 f5 ff ff 	mov    %rax,-0xa98(%rbp)
 11c05af:	48 8b 85 c0 fd ff ff 	mov    -0x240(%rbp),%rax
 11c05b6:	48 89 85 70 f5 ff ff 	mov    %rax,-0xa90(%rbp)
 11c05bd:	0f b6 45 ca          	movzbl -0x36(%rbp),%eax
 11c05c1:	88 85 78 f5 ff ff    	mov    %al,-0xa88(%rbp)
 11c05c7:	48 8b 85 c8 fd ff ff 	mov    -0x238(%rbp),%rax
 11c05ce:	48 89 85 80 f5 ff ff 	mov    %rax,-0xa80(%rbp)
 11c05d5:	0f b6 45 d0          	movzbl -0x30(%rbp),%eax
 11c05d9:	88 85 88 f5 ff ff    	mov    %al,-0xa78(%rbp)
 11c05df:	48 8b 85 d0 fd ff ff 	mov    -0x230(%rbp),%rax
 11c05e6:	48 89 85 90 f5 ff ff 	mov    %rax,-0xa70(%rbp)
 11c05ed:	0f b6 45 d6          	movzbl -0x2a(%rbp),%eax
 11c05f1:	88 85 98 f5 ff ff    	mov    %al,-0xa68(%rbp)
 11c05f7:	48 8b 85 d8 fd ff ff 	mov    -0x228(%rbp),%rax
 11c05fe:	48 89 85 a0 f5 ff ff 	mov    %rax,-0xa60(%rbp)
 11c0605:	0f b6 45 cd          	movzbl -0x33(%rbp),%eax
 11c0609:	88 85 a8 f5 ff ff    	mov    %al,-0xa58(%rbp)
 11c060f:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 11c0616:	48 89 85 b0 f5 ff ff 	mov    %rax,-0xa50(%rbp)
 11c061d:	0f b6 45 c1          	movzbl -0x3f(%rbp),%eax
 11c0621:	88 85 b8 f5 ff ff    	mov    %al,-0xa48(%rbp)
 11c0627:	48 8b 85 f8 fc ff ff 	mov    -0x308(%rbp),%rax
 11c062e:	48 89 85 c0 f5 ff ff 	mov    %rax,-0xa40(%rbp)
 11c0635:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 11c0639:	88 85 c8 f5 ff ff    	mov    %al,-0xa38(%rbp)
 11c063f:	0f b6 45 c8          	movzbl -0x38(%rbp),%eax
 11c0643:	88 85 c9 f5 ff ff    	mov    %al,-0xa37(%rbp)
 11c0649:	48 8d bd 68 f5 ff ff 	lea    -0xa98(%rbp),%rdi
 11c0650:	48 8b 75 80          	mov    -0x80(%rbp),%rsi
 11c0654:	c5 f8 77             	vzeroupper 
 11c0657:	e8 e4 04 04 00       	call   1200b40 <br.encoder.command_block_split.Result.blockIndex>
 11c065c:	48 69 c0 40 08 00 00 	imul   $0x840,%rax,%rax
 11c0663:	4c 8d 34 28          	lea    (%rax,%rbp,1),%r14
 11c0667:	49 81 c6 40 ba fc ff 	add    $0xfffffffffffcba40,%r14
 11c066e:	31 db                	xor    %ebx,%ebx
 11c0670:	4c 8b ad e8 fc ff ff 	mov    -0x318(%rbp),%r13
 11c0677:	eb 09                	jmp    11c0682 <br.encodeCommandPlanWithOptionsWrite+0x4c42>
 11c0679:	49 39 dd             	cmp    %rbx,%r13
 11c067c:	0f 84 97 00 00 00    	je     11c0719 <br.encodeCommandPlanWithOptionsWrite+0x4cd9>
 11c0682:	48 8b 85 c0 fd ff ff 	mov    -0x240(%rbp),%rax
 11c0689:	48 89 85 08 fa ff ff 	mov    %rax,-0x5f8(%rbp)
 11c0690:	48 8b 85 c8 fd ff ff 	mov    -0x238(%rbp),%rax
 11c0697:	48 89 85 10 fa ff ff 	mov    %rax,-0x5f0(%rbp)
 11c069e:	48 8b 85 d0 fd ff ff 	mov    -0x230(%rbp),%rax
 11c06a5:	48 89 85 18 fa ff ff 	mov    %rax,-0x5e8(%rbp)
 11c06ac:	48 8b 85 d8 fd ff ff 	mov    -0x228(%rbp),%rax
 11c06b3:	48 89 85 20 fa ff ff 	mov    %rax,-0x5e0(%rbp)
 11c06ba:	48 8d 85 08 fa ff ff 	lea    -0x5f8(%rbp),%rax
 11c06c1:	48 8b 8d 38 fe ff ff 	mov    -0x1c8(%rbp),%rcx
 11c06c8:	ff 24 dd 28 00 01 01 	jmp    *0x1010028(,%rbx,8)
 11c06cf:	48 8d 85 10 fa ff ff 	lea    -0x5f0(%rbp),%rax
 11c06d6:	eb 10                	jmp    11c06e8 <br.encodeCommandPlanWithOptionsWrite+0x4ca8>
 11c06d8:	48 8d 85 20 fa ff ff 	lea    -0x5e0(%rbp),%rax
 11c06df:	eb 07                	jmp    11c06e8 <br.encodeCommandPlanWithOptionsWrite+0x4ca8>
 11c06e1:	48 8d 85 18 fa ff ff 	lea    -0x5e8(%rbp),%rax
 11c06e8:	48 8b 08             	mov    (%rax),%rcx
 11c06eb:	48 ff c3             	inc    %rbx
 11c06ee:	48 39 4d 80          	cmp    %rcx,-0x80(%rbp)
 11c06f2:	75 85                	jne    11c0679 <br.encodeCommandPlanWithOptionsWrite+0x4c39>
 11c06f4:	48 8d bd 20 ed ff ff 	lea    -0x12e0(%rbp),%rdi
 11c06fb:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 11c06ff:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 11c0703:	48 89 d9             	mov    %rbx,%rcx
 11c0706:	e8 d5 36 00 00       	call   11c3de0 <br.CommandBlockLengthCode.writeLength>
 11c070b:	66 85 c0             	test   %ax,%ax
 11c070e:	0f 84 65 ff ff ff    	je     11c0679 <br.encodeCommandPlanWithOptionsWrite+0x4c39>
 11c0714:	e9 94 b3 ff ff       	jmp    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c0719:	49 8b 04 24          	mov    (%r12),%rax
 11c071d:	48 83 f8 01          	cmp    $0x1,%rax
 11c0721:	0f 86 f7 01 00 00    	jbe    11c091e <br.encodeCommandPlanWithOptionsWrite+0x4ede>
 11c0727:	48 83 f8 04          	cmp    $0x4,%rax
 11c072b:	77 58                	ja     11c0785 <br.encodeCommandPlanWithOptionsWrite+0x4d45>
 11c072d:	48 8d bd 82 fc ff ff 	lea    -0x37e(%rbp),%rdi
 11c0734:	4c 89 e6             	mov    %r12,%rsi
 11c0737:	48 8b 95 b8 fd ff ff 	mov    -0x248(%rbp),%rdx
 11c073e:	c5 f8 77             	vzeroupper 
 11c0741:	e8 3a 73 04 00       	call   1207a80 <br.encoder.command_plan.PrefixAlphabetFor(520).simpleCode>
 11c0746:	44 0f b7 b5 82 fc ff 	movzwl -0x37e(%rbp),%r14d
 11c074d:	ff 
 11c074e:	0f b6 9d 84 fc ff ff 	movzbl -0x37c(%rbp),%ebx
 11c0755:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c0759:	f6 40 08 07          	testb  $0x7,0x8(%rax)
 11c075d:	0f 85 85 00 00 00    	jne    11c07e8 <br.encodeCommandPlanWithOptionsWrite+0x4da8>
 11c0763:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c0767:	48 8b 38             	mov    (%rax),%rdi
 11c076a:	48 8b 47 08          	mov    0x8(%rdi),%rax
 11c076e:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 11c0772:	73 52                	jae    11c07c6 <br.encodeCommandPlanWithOptionsWrite+0x4d86>
 11c0774:	48 8d 48 01          	lea    0x1(%rax),%rcx
 11c0778:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 11c077c:	48 8b 0f             	mov    (%rdi),%rcx
 11c077f:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 11c0783:	eb 63                	jmp    11c07e8 <br.encodeCommandPlanWithOptionsWrite+0x4da8>
 11c0785:	48 8b 85 b8 fd ff ff 	mov    -0x248(%rbp),%rax
 11c078c:	45 0f b7 24 46       	movzwl (%r14,%rax,2),%r12d
 11c0791:	41 0f b6 9c 06 80 05 	movzbl 0x580(%r14,%rax,1),%ebx
 11c0798:	00 00 
 11c079a:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c079e:	f6 40 08 07          	testb  $0x7,0x8(%rax)
 11c07a2:	75 7b                	jne    11c081f <br.encodeCommandPlanWithOptionsWrite+0x4ddf>
 11c07a4:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c07a8:	48 8b 38             	mov    (%rax),%rdi
 11c07ab:	48 8b 47 08          	mov    0x8(%rdi),%rax
 11c07af:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 11c07b3:	73 45                	jae    11c07fa <br.encodeCommandPlanWithOptionsWrite+0x4dba>
 11c07b5:	48 8d 48 01          	lea    0x1(%rax),%rcx
 11c07b9:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 11c07bd:	48 8b 0f             	mov    (%rdi),%rcx
 11c07c0:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 11c07c4:	eb 59                	jmp    11c081f <br.encodeCommandPlanWithOptionsWrite+0x4ddf>
 11c07c6:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c07ca:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 11c07ce:	0f 85 33 11 00 00    	jne    11c1907 <br.encodeCommandPlanWithOptionsWrite+0x5ec7>
 11c07d4:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 11c07d8:	31 d2                	xor    %edx,%edx
 11c07da:	e8 91 33 00 00       	call   11c3b70 <array_list.Aligned(u8,null).append>
 11c07df:	66 85 c0             	test   %ax,%ax
 11c07e2:	0f 85 c5 b2 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c07e8:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c07ec:	0f b6 48 08          	movzbl 0x8(%rax),%ecx
 11c07f0:	80 e1 07             	and    $0x7,%cl
 11c07f3:	c4 c2 71 f7 f6       	shlx   %ecx,%r14d,%esi
 11c07f8:	eb 35                	jmp    11c082f <br.encodeCommandPlanWithOptionsWrite+0x4def>
 11c07fa:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c07fe:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 11c0802:	0f 85 ff 10 00 00    	jne    11c1907 <br.encodeCommandPlanWithOptionsWrite+0x5ec7>
 11c0808:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 11c080c:	31 d2                	xor    %edx,%edx
 11c080e:	c5 f8 77             	vzeroupper 
 11c0811:	e8 5a 33 00 00       	call   11c3b70 <array_list.Aligned(u8,null).append>
 11c0816:	66 85 c0             	test   %ax,%ax
 11c0819:	0f 85 8e b2 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c081f:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c0823:	0f b6 48 08          	movzbl 0x8(%rax),%ecx
 11c0827:	80 e1 07             	and    $0x7,%cl
 11c082a:	c4 c2 71 f7 f4       	shlx   %ecx,%r12d,%esi
 11c082f:	48 8b 08             	mov    (%rax),%rcx
 11c0832:	48 8b 11             	mov    (%rcx),%rdx
 11c0835:	48 8b 49 08          	mov    0x8(%rcx),%rcx
 11c0839:	40 08 74 0a ff       	or     %sil,-0x1(%rdx,%rcx,1)
 11c083e:	0f b6 40 08          	movzbl 0x8(%rax),%eax
 11c0842:	24 07                	and    $0x7,%al
 11c0844:	80 e3 0f             	and    $0xf,%bl
 11c0847:	00 c3                	add    %al,%bl
 11c0849:	80 fb 08             	cmp    $0x8,%bl
 11c084c:	0f 86 c2 00 00 00    	jbe    11c0914 <br.encodeCommandPlanWithOptionsWrite+0x4ed4>
 11c0852:	41 89 f6             	mov    %esi,%r14d
 11c0855:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c0859:	48 8b 38             	mov    (%rax),%rdi
 11c085c:	48 8b 47 08          	mov    0x8(%rdi),%rax
 11c0860:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 11c0864:	73 11                	jae    11c0877 <br.encodeCommandPlanWithOptionsWrite+0x4e37>
 11c0866:	48 8d 48 01          	lea    0x1(%rax),%rcx
 11c086a:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 11c086e:	48 8b 0f             	mov    (%rdi),%rcx
 11c0871:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 11c0875:	eb 25                	jmp    11c089c <br.encodeCommandPlanWithOptionsWrite+0x4e5c>
 11c0877:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c087b:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 11c087f:	0f 85 82 10 00 00    	jne    11c1907 <br.encodeCommandPlanWithOptionsWrite+0x5ec7>
 11c0885:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 11c0889:	31 d2                	xor    %edx,%edx
 11c088b:	c5 f8 77             	vzeroupper 
 11c088e:	e8 dd 32 00 00       	call   11c3b70 <array_list.Aligned(u8,null).append>
 11c0893:	66 85 c0             	test   %ax,%ax
 11c0896:	0f 85 11 b2 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c089c:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c08a0:	48 8b 00             	mov    (%rax),%rax
 11c08a3:	48 8b 08             	mov    (%rax),%rcx
 11c08a6:	48 8b 40 08          	mov    0x8(%rax),%rax
 11c08aa:	44 89 f2             	mov    %r14d,%edx
 11c08ad:	88 74 01 ff          	mov    %dh,-0x1(%rcx,%rax,1)
 11c08b1:	80 fb 11             	cmp    $0x11,%bl
 11c08b4:	72 5e                	jb     11c0914 <br.encodeCommandPlanWithOptionsWrite+0x4ed4>
 11c08b6:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c08ba:	48 8b 38             	mov    (%rax),%rdi
 11c08bd:	48 8b 47 08          	mov    0x8(%rdi),%rax
 11c08c1:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 11c08c5:	73 11                	jae    11c08d8 <br.encodeCommandPlanWithOptionsWrite+0x4e98>
 11c08c7:	48 8d 48 01          	lea    0x1(%rax),%rcx
 11c08cb:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 11c08cf:	48 8b 0f             	mov    (%rdi),%rcx
 11c08d2:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 11c08d6:	eb 25                	jmp    11c08fd <br.encodeCommandPlanWithOptionsWrite+0x4ebd>
 11c08d8:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c08dc:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 11c08e0:	0f 85 21 10 00 00    	jne    11c1907 <br.encodeCommandPlanWithOptionsWrite+0x5ec7>
 11c08e6:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 11c08ea:	31 d2                	xor    %edx,%edx
 11c08ec:	c5 f8 77             	vzeroupper 
 11c08ef:	e8 7c 32 00 00       	call   11c3b70 <array_list.Aligned(u8,null).append>
 11c08f4:	66 85 c0             	test   %ax,%ax
 11c08f7:	0f 85 b0 b1 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c08fd:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c0901:	48 8b 00             	mov    (%rax),%rax
 11c0904:	48 8b 08             	mov    (%rax),%rcx
 11c0907:	48 8b 40 08          	mov    0x8(%rax),%rax
 11c090b:	41 c1 ee 10          	shr    $0x10,%r14d
 11c090f:	44 88 74 01 ff       	mov    %r14b,-0x1(%rcx,%rax,1)
 11c0914:	80 e3 07             	and    $0x7,%bl
 11c0917:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c091b:	88 58 08             	mov    %bl,0x8(%rax)
 11c091e:	48 8b 7d a0          	mov    -0x60(%rbp),%rdi
 11c0922:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 11c0926:	48 8b 55 88          	mov    -0x78(%rbp),%rdx
 11c092a:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 11c092e:	4c 8b 85 40 fe ff ff 	mov    -0x1c0(%rbp),%r8
 11c0935:	c5 f8 77             	vzeroupper 
 11c0938:	e8 93 30 00 00       	call   11c39d0 <br.writeCommandLengthExtras>
 11c093d:	66 85 c0             	test   %ax,%ax
 11c0940:	0f 85 67 b1 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c0946:	48 83 7d 90 00       	cmpq   $0x0,-0x70(%rbp)
 11c094b:	0f 84 64 07 00 00    	je     11c10b5 <br.encodeCommandPlanWithOptionsWrite+0x5675>
 11c0951:	48 8b 85 78 fd ff ff 	mov    -0x288(%rbp),%rax
 11c0958:	48 8b 8d 70 fd ff ff 	mov    -0x290(%rbp),%rcx
 11c095f:	48 01 c8             	add    %rcx,%rax
 11c0962:	48 89 45 88          	mov    %rax,-0x78(%rbp)
 11c0966:	45 31 f6             	xor    %r14d,%r14d
 11c0969:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 11c096d:	0f b6 5d cf          	movzbl -0x31(%rbp),%ebx
 11c0971:	48 8b 95 18 ff ff ff 	mov    -0xe8(%rbp),%rdx
 11c0978:	48 8b b5 00 ff ff ff 	mov    -0x100(%rbp),%rsi
 11c097f:	48 8b bd 20 ff ff ff 	mov    -0xe0(%rbp),%rdi
 11c0986:	4c 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%r8
 11c098d:	4c 8b 8d 30 ff ff ff 	mov    -0xd0(%rbp),%r9
 11c0994:	48 8b 85 08 ff ff ff 	mov    -0xf8(%rbp),%rax
 11c099b:	eb 6a                	jmp    11c0a07 <br.encodeCommandPlanWithOptionsWrite+0x4fc7>
 11c099d:	48 8d 48 01          	lea    0x1(%rax),%rcx
 11c09a1:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 11c09a5:	48 8b 0f             	mov    (%rdi),%rcx
 11c09a8:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 11c09ac:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 11c09b0:	48 8b 01             	mov    (%rcx),%rax
 11c09b3:	48 8b 10             	mov    (%rax),%rdx
 11c09b6:	48 8b 40 08          	mov    0x8(%rax),%rax
 11c09ba:	41 c1 ec 10          	shr    $0x10,%r12d
 11c09be:	44 88 64 02 ff       	mov    %r12b,-0x1(%rdx,%rax,1)
 11c09c3:	80 e3 07             	and    $0x7,%bl
 11c09c6:	88 59 08             	mov    %bl,0x8(%rcx)
 11c09c9:	49 ff c7             	inc    %r15
 11c09cc:	48 8b 95 18 ff ff ff 	mov    -0xe8(%rbp),%rdx
 11c09d3:	48 8b b5 00 ff ff ff 	mov    -0x100(%rbp),%rsi
 11c09da:	48 8b bd 20 ff ff ff 	mov    -0xe0(%rbp),%rdi
 11c09e1:	4c 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%r8
 11c09e8:	4c 8b 8d 30 ff ff ff 	mov    -0xd0(%rbp),%r9
 11c09ef:	48 8b 85 08 ff ff ff 	mov    -0xf8(%rbp),%rax
 11c09f6:	49 ff c6             	inc    %r14
 11c09f9:	4c 3b 75 90          	cmp    -0x70(%rbp),%r14
 11c09fd:	0f b6 5d cf          	movzbl -0x31(%rbp),%ebx
 11c0a01:	0f 84 ae 06 00 00    	je     11c10b5 <br.encodeCommandPlanWithOptionsWrite+0x5675>
 11c0a07:	4c 8b 55 88          	mov    -0x78(%rbp),%r10
 11c0a0b:	47 0f b6 2c 32       	movzbl (%r10,%r14,1),%r13d
 11c0a10:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 11c0a14:	74 34                	je     11c0a4a <br.encodeCommandPlanWithOptionsWrite+0x500a>
 11c0a16:	48 89 b5 88 fc ff ff 	mov    %rsi,-0x378(%rbp)
 11c0a1d:	48 89 bd 98 fb ff ff 	mov    %rdi,-0x468(%rbp)
 11c0a24:	4c 89 85 a0 fb ff ff 	mov    %r8,-0x460(%rbp)
 11c0a2b:	4c 89 8d a8 fb ff ff 	mov    %r9,-0x458(%rbp)
 11c0a32:	45 31 e4             	xor    %r12d,%r12d
 11c0a35:	48 8d 85 88 fc ff ff 	lea    -0x378(%rbp),%rax
 11c0a3c:	48 89 d1             	mov    %rdx,%rcx
 11c0a3f:	45 31 d2             	xor    %r10d,%r10d
 11c0a42:	42 ff 24 d5 50 00 01 	jmp    *0x1010050(,%r10,8)
 11c0a49:	01 
 11c0a4a:	80 38 00             	cmpb   $0x0,(%rax)
 11c0a4d:	0f 84 87 00 00 00    	je     11c0ada <br.encodeCommandPlanWithOptionsWrite+0x509a>
 11c0a53:	4c 89 f1             	mov    %r14,%rcx
 11c0a56:	48 8b 85 08 fd ff ff 	mov    -0x2f8(%rbp),%rax
 11c0a5d:	4c 8b 20             	mov    (%rax),%r12
 11c0a60:	48 8b 85 58 fd ff ff 	mov    -0x2a8(%rbp),%rax
 11c0a67:	0f b6 00             	movzbl (%rax),%eax
 11c0a6a:	48 8b bd a0 fd ff ff 	mov    -0x260(%rbp),%rdi
 11c0a71:	c5 fc 10 07          	vmovups (%rdi),%ymm0
 11c0a75:	c5 fc 10 4f 20       	vmovups 0x20(%rdi),%ymm1
 11c0a7a:	8b 57 40             	mov    0x40(%rdi),%edx
 11c0a7d:	0f b7 77 44          	movzwl 0x44(%rdi),%esi
 11c0a81:	0f b6 7f 46          	movzbl 0x46(%rdi),%edi
 11c0a85:	40 88 bd a6 f1 ff ff 	mov    %dil,-0xe5a(%rbp)
 11c0a8c:	66 89 b5 a4 f1 ff ff 	mov    %si,-0xe5c(%rbp)
 11c0a93:	89 95 a0 f1 ff ff    	mov    %edx,-0xe60(%rbp)
 11c0a99:	c5 fc 11 8d 80 f1 ff 	vmovups %ymm1,-0xe80(%rbp)
 11c0aa0:	ff 
 11c0aa1:	c5 fc 11 85 60 f1 ff 	vmovups %ymm0,-0xea0(%rbp)
 11c0aa8:	ff 
 11c0aa9:	8b 95 fc fe ff ff    	mov    -0x104(%rbp),%edx
 11c0aaf:	8b b5 9c fd ff ff    	mov    -0x264(%rbp),%esi
 11c0ab5:	89 f7                	mov    %esi,%edi
 11c0ab7:	48 03 8d 70 fd ff ff 	add    -0x290(%rbp),%rcx
 11c0abe:	74 7e                	je     11c0b3e <br.encodeCommandPlanWithOptionsWrite+0x50fe>
 11c0ac0:	48 83 f9 01          	cmp    $0x1,%rcx
 11c0ac4:	75 67                	jne    11c0b2d <br.encodeCommandPlanWithOptionsWrite+0x50ed>
 11c0ac6:	48 8b 8d 78 fd ff ff 	mov    -0x288(%rbp),%rcx
 11c0acd:	0f b6 11             	movzbl (%rcx),%edx
 11c0ad0:	8b 8d fc fe ff ff    	mov    -0x104(%rbp),%ecx
 11c0ad6:	89 cf                	mov    %ecx,%edi
 11c0ad8:	eb 64                	jmp    11c0b3e <br.encodeCommandPlanWithOptionsWrite+0x50fe>
 11c0ada:	48 83 bd b8 d5 ff ff 	cmpq   $0x1,-0x2a48(%rbp)
 11c0ae1:	01 
 11c0ae2:	0f 86 e4 fe ff ff    	jbe    11c09cc <br.encodeCommandPlanWithOptionsWrite+0x4f8c>
 11c0ae8:	46 0f b7 a4 6d bc b1 	movzwl -0x4e44(%rbp,%r13,2),%r12d
 11c0aef:	ff ff 
 11c0af1:	42 0f b6 9c 2d bc b3 	movzbl -0x4c44(%rbp,%r13,1),%ebx
 11c0af8:	ff ff 
 11c0afa:	f6 41 08 07          	testb  $0x7,0x8(%rcx)
 11c0afe:	0f 85 eb 01 00 00    	jne    11c0cef <br.encodeCommandPlanWithOptionsWrite+0x52af>
 11c0b04:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c0b08:	48 8b 38             	mov    (%rax),%rdi
 11c0b0b:	48 8b 47 08          	mov    0x8(%rdi),%rax
 11c0b0f:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 11c0b13:	0f 83 b1 01 00 00    	jae    11c0cca <br.encodeCommandPlanWithOptionsWrite+0x528a>
 11c0b19:	48 8d 48 01          	lea    0x1(%rax),%rcx
 11c0b1d:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 11c0b21:	48 8b 0f             	mov    (%rdi),%rcx
 11c0b24:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 11c0b28:	e9 c2 01 00 00       	jmp    11c0cef <br.encodeCommandPlanWithOptionsWrite+0x52af>
 11c0b2d:	48 8b 95 78 fd ff ff 	mov    -0x288(%rbp),%rdx
 11c0b34:	0f b6 7c 0a fe       	movzbl -0x2(%rdx,%rcx,1),%edi
 11c0b39:	0f b6 54 0a ff       	movzbl -0x1(%rdx,%rcx,1),%edx
 11c0b3e:	0f b6 d8             	movzbl %al,%ebx
 11c0b41:	0f b6 f2             	movzbl %dl,%esi
 11c0b44:	40 0f b6 d7          	movzbl %dil,%edx
 11c0b48:	89 df                	mov    %ebx,%edi
 11c0b4a:	c5 f8 77             	vzeroupper 
 11c0b4d:	e8 6e fd 03 00       	call   12008c0 <br.encoder.literal_context.value>
 11c0b52:	4c 89 a5 20 fc ff ff 	mov    %r12,-0x3e0(%rbp)
 11c0b59:	88 9d 28 fc ff ff    	mov    %bl,-0x3d8(%rbp)
 11c0b5f:	48 8b 8d 9f f1 ff ff 	mov    -0xe61(%rbp),%rcx
 11c0b66:	48 8d 95 29 fc ff ff 	lea    -0x3d7(%rbp),%rdx
 11c0b6d:	48 89 4a 3f          	mov    %rcx,0x3f(%rdx)
 11c0b71:	c5 fc 10 85 60 f1 ff 	vmovups -0xea0(%rbp),%ymm0
 11c0b78:	ff 
 11c0b79:	c5 fc 10 8d 80 f1 ff 	vmovups -0xe80(%rbp),%ymm1
 11c0b80:	ff 
 11c0b81:	c5 fc 11 4a 20       	vmovups %ymm1,0x20(%rdx)
 11c0b86:	c5 fc 11 02          	vmovups %ymm0,(%rdx)
 11c0b8a:	0f b6 84 05 2a fc ff 	movzbl -0x3d6(%rbp,%rax,1),%eax
 11c0b91:	ff 
 11c0b92:	48 8d 04 40          	lea    (%rax,%rax,2),%rax
 11c0b96:	c1 e0 08             	shl    $0x8,%eax
 11c0b99:	48 01 e8             	add    %rbp,%rax
 11c0b9c:	48 05 c0 c8 f9 ff    	add    $0xfffffffffff9c8c0,%rax
 11c0ba2:	41 0f b6 9c 05 00 02 	movzbl 0x200(%r13,%rax,1),%ebx
 11c0ba9:	00 00 
 11c0bab:	f6 c3 0f             	test   $0xf,%bl
 11c0bae:	74 31                	je     11c0be1 <br.encodeCommandPlanWithOptionsWrite+0x51a1>
 11c0bb0:	46 0f b7 24 68       	movzwl (%rax,%r13,2),%r12d
 11c0bb5:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 11c0bb9:	f6 41 08 07          	testb  $0x7,0x8(%rcx)
 11c0bbd:	75 54                	jne    11c0c13 <br.encodeCommandPlanWithOptionsWrite+0x51d3>
 11c0bbf:	48 8b 39             	mov    (%rcx),%rdi
 11c0bc2:	48 8b 47 08          	mov    0x8(%rdi),%rax
 11c0bc6:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 11c0bca:	73 1e                	jae    11c0bea <br.encodeCommandPlanWithOptionsWrite+0x51aa>
 11c0bcc:	48 8d 48 01          	lea    0x1(%rax),%rcx
 11c0bd0:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 11c0bd4:	48 8b 0f             	mov    (%rdi),%rcx
 11c0bd7:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 11c0bdb:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 11c0bdf:	eb 32                	jmp    11c0c13 <br.encodeCommandPlanWithOptionsWrite+0x51d3>
 11c0be1:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 11c0be5:	e9 e2 fd ff ff       	jmp    11c09cc <br.encodeCommandPlanWithOptionsWrite+0x4f8c>
 11c0bea:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c0bee:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 11c0bf2:	0f 85 0f 0d 00 00    	jne    11c1907 <br.encodeCommandPlanWithOptionsWrite+0x5ec7>
 11c0bf8:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 11c0bfc:	31 d2                	xor    %edx,%edx
 11c0bfe:	c5 f8 77             	vzeroupper 
 11c0c01:	e8 6a 2f 00 00       	call   11c3b70 <array_list.Aligned(u8,null).append>
 11c0c06:	66 85 c0             	test   %ax,%ax
 11c0c09:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 11c0c0d:	0f 85 9a ae ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c0c13:	0f b6 41 08          	movzbl 0x8(%rcx),%eax
 11c0c17:	24 07                	and    $0x7,%al
 11c0c19:	c4 c2 79 f7 f4       	shlx   %eax,%r12d,%esi
 11c0c1e:	48 8b 01             	mov    (%rcx),%rax
 11c0c21:	48 8b 10             	mov    (%rax),%rdx
 11c0c24:	48 8b 40 08          	mov    0x8(%rax),%rax
 11c0c28:	40 08 74 02 ff       	or     %sil,-0x1(%rdx,%rax,1)
 11c0c2d:	0f b6 41 08          	movzbl 0x8(%rcx),%eax
 11c0c31:	24 07                	and    $0x7,%al
 11c0c33:	80 e3 0f             	and    $0xf,%bl
 11c0c36:	00 c3                	add    %al,%bl
 11c0c38:	80 fb 08             	cmp    $0x8,%bl
 11c0c3b:	0f 86 8d 01 00 00    	jbe    11c0dce <br.encodeCommandPlanWithOptionsWrite+0x538e>
 11c0c41:	41 89 f4             	mov    %esi,%r12d
 11c0c44:	48 8b 39             	mov    (%rcx),%rdi
 11c0c47:	48 8b 47 08          	mov    0x8(%rdi),%rax
 11c0c4b:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 11c0c4f:	73 11                	jae    11c0c62 <br.encodeCommandPlanWithOptionsWrite+0x5222>
 11c0c51:	48 8d 48 01          	lea    0x1(%rax),%rcx
 11c0c55:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 11c0c59:	48 8b 0f             	mov    (%rdi),%rcx
 11c0c5c:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 11c0c60:	eb 25                	jmp    11c0c87 <br.encodeCommandPlanWithOptionsWrite+0x5247>
 11c0c62:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c0c66:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 11c0c6a:	0f 85 97 0c 00 00    	jne    11c1907 <br.encodeCommandPlanWithOptionsWrite+0x5ec7>
 11c0c70:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 11c0c74:	31 d2                	xor    %edx,%edx
 11c0c76:	c5 f8 77             	vzeroupper 
 11c0c79:	e8 f2 2e 00 00       	call   11c3b70 <array_list.Aligned(u8,null).append>
 11c0c7e:	66 85 c0             	test   %ax,%ax
 11c0c81:	0f 85 26 ae ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c0c87:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 11c0c8b:	48 8b 01             	mov    (%rcx),%rax
 11c0c8e:	48 8b 30             	mov    (%rax),%rsi
 11c0c91:	48 8b 40 08          	mov    0x8(%rax),%rax
 11c0c95:	44 89 e2             	mov    %r12d,%edx
 11c0c98:	88 74 06 ff          	mov    %dh,-0x1(%rsi,%rax,1)
 11c0c9c:	80 fb 11             	cmp    $0x11,%bl
 11c0c9f:	0f 82 29 01 00 00    	jb     11c0dce <br.encodeCommandPlanWithOptionsWrite+0x538e>
 11c0ca5:	48 8b 39             	mov    (%rcx),%rdi
 11c0ca8:	48 8b 47 08          	mov    0x8(%rdi),%rax
 11c0cac:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 11c0cb0:	0f 83 dc 00 00 00    	jae    11c0d92 <br.encodeCommandPlanWithOptionsWrite+0x5352>
 11c0cb6:	48 8d 48 01          	lea    0x1(%rax),%rcx
 11c0cba:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 11c0cbe:	48 8b 0f             	mov    (%rdi),%rcx
 11c0cc1:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 11c0cc5:	e9 ed 00 00 00       	jmp    11c0db7 <br.encodeCommandPlanWithOptionsWrite+0x5377>
 11c0cca:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c0cce:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 11c0cd2:	0f 85 2f 0c 00 00    	jne    11c1907 <br.encodeCommandPlanWithOptionsWrite+0x5ec7>
 11c0cd8:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 11c0cdc:	31 d2                	xor    %edx,%edx
 11c0cde:	c5 f8 77             	vzeroupper 
 11c0ce1:	e8 8a 2e 00 00       	call   11c3b70 <array_list.Aligned(u8,null).append>
 11c0ce6:	66 85 c0             	test   %ax,%ax
 11c0ce9:	0f 85 be ad ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c0cef:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 11c0cf3:	0f b6 41 08          	movzbl 0x8(%rcx),%eax
 11c0cf7:	24 07                	and    $0x7,%al
 11c0cf9:	c4 c2 79 f7 f4       	shlx   %eax,%r12d,%esi
 11c0cfe:	48 8b 01             	mov    (%rcx),%rax
 11c0d01:	48 8b 10             	mov    (%rax),%rdx
 11c0d04:	48 8b 40 08          	mov    0x8(%rax),%rax
 11c0d08:	40 08 74 02 ff       	or     %sil,-0x1(%rdx,%rax,1)
 11c0d0d:	0f b6 41 08          	movzbl 0x8(%rcx),%eax
 11c0d11:	24 07                	and    $0x7,%al
 11c0d13:	80 e3 0f             	and    $0xf,%bl
 11c0d16:	00 c3                	add    %al,%bl
 11c0d18:	80 fb 08             	cmp    $0x8,%bl
 11c0d1b:	0f 86 ad 00 00 00    	jbe    11c0dce <br.encodeCommandPlanWithOptionsWrite+0x538e>
 11c0d21:	41 89 f4             	mov    %esi,%r12d
 11c0d24:	48 8b 39             	mov    (%rcx),%rdi
 11c0d27:	48 8b 47 08          	mov    0x8(%rdi),%rax
 11c0d2b:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 11c0d2f:	73 11                	jae    11c0d42 <br.encodeCommandPlanWithOptionsWrite+0x5302>
 11c0d31:	48 8d 48 01          	lea    0x1(%rax),%rcx
 11c0d35:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 11c0d39:	48 8b 0f             	mov    (%rdi),%rcx
 11c0d3c:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 11c0d40:	eb 25                	jmp    11c0d67 <br.encodeCommandPlanWithOptionsWrite+0x5327>
 11c0d42:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c0d46:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 11c0d4a:	0f 85 b7 0b 00 00    	jne    11c1907 <br.encodeCommandPlanWithOptionsWrite+0x5ec7>
 11c0d50:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 11c0d54:	31 d2                	xor    %edx,%edx
 11c0d56:	c5 f8 77             	vzeroupper 
 11c0d59:	e8 12 2e 00 00       	call   11c3b70 <array_list.Aligned(u8,null).append>
 11c0d5e:	66 85 c0             	test   %ax,%ax
 11c0d61:	0f 85 46 ad ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c0d67:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 11c0d6b:	48 8b 01             	mov    (%rcx),%rax
 11c0d6e:	48 8b 30             	mov    (%rax),%rsi
 11c0d71:	48 8b 40 08          	mov    0x8(%rax),%rax
 11c0d75:	44 89 e2             	mov    %r12d,%edx
 11c0d78:	88 74 06 ff          	mov    %dh,-0x1(%rsi,%rax,1)
 11c0d7c:	80 fb 11             	cmp    $0x11,%bl
 11c0d7f:	72 4d                	jb     11c0dce <br.encodeCommandPlanWithOptionsWrite+0x538e>
 11c0d81:	48 8b 39             	mov    (%rcx),%rdi
 11c0d84:	48 8b 47 08          	mov    0x8(%rdi),%rax
 11c0d88:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 11c0d8c:	0f 82 24 ff ff ff    	jb     11c0cb6 <br.encodeCommandPlanWithOptionsWrite+0x5276>
 11c0d92:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c0d96:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 11c0d9a:	0f 85 67 0b 00 00    	jne    11c1907 <br.encodeCommandPlanWithOptionsWrite+0x5ec7>
 11c0da0:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 11c0da4:	31 d2                	xor    %edx,%edx
 11c0da6:	c5 f8 77             	vzeroupper 
 11c0da9:	e8 c2 2d 00 00       	call   11c3b70 <array_list.Aligned(u8,null).append>
 11c0dae:	66 85 c0             	test   %ax,%ax
 11c0db1:	0f 85 f6 ac ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c0db7:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 11c0dbb:	48 8b 01             	mov    (%rcx),%rax
 11c0dbe:	48 8b 10             	mov    (%rax),%rdx
 11c0dc1:	48 8b 40 08          	mov    0x8(%rax),%rax
 11c0dc5:	41 c1 ec 10          	shr    $0x10,%r12d
 11c0dc9:	44 88 64 02 ff       	mov    %r12b,-0x1(%rdx,%rax,1)
 11c0dce:	80 e3 07             	and    $0x7,%bl
 11c0dd1:	88 59 08             	mov    %bl,0x8(%rcx)
 11c0dd4:	e9 f3 fb ff ff       	jmp    11c09cc <br.encodeCommandPlanWithOptionsWrite+0x4f8c>
 11c0dd9:	48 8d 85 98 fb ff ff 	lea    -0x468(%rbp),%rax
 11c0de0:	eb 10                	jmp    11c0df2 <br.encodeCommandPlanWithOptionsWrite+0x53b2>
 11c0de2:	48 8d 85 a0 fb ff ff 	lea    -0x460(%rbp),%rax
 11c0de9:	eb 07                	jmp    11c0df2 <br.encodeCommandPlanWithOptionsWrite+0x53b2>
 11c0deb:	48 8d 85 a8 fb ff ff 	lea    -0x458(%rbp),%rax
 11c0df2:	48 8b 08             	mov    (%rax),%rcx
 11c0df5:	49 ff c4             	inc    %r12
 11c0df8:	49 39 cf             	cmp    %rcx,%r15
 11c0dfb:	75 46                	jne    11c0e43 <br.encodeCommandPlanWithOptionsWrite+0x5403>
 11c0dfd:	48 8d bd 90 e8 ff ff 	lea    -0x1770(%rbp),%rdi
 11c0e04:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 11c0e08:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 11c0e0c:	4c 89 e1             	mov    %r12,%rcx
 11c0e0f:	c5 f8 77             	vzeroupper 
 11c0e12:	e8 c9 2f 00 00       	call   11c3de0 <br.CommandBlockLengthCode.writeLength>
 11c0e17:	4c 8b 8d 30 ff ff ff 	mov    -0xd0(%rbp),%r9
 11c0e1e:	4c 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%r8
 11c0e25:	48 8b bd 20 ff ff ff 	mov    -0xe0(%rbp),%rdi
 11c0e2c:	48 8b b5 00 ff ff ff 	mov    -0x100(%rbp),%rsi
 11c0e33:	48 8b 95 18 ff ff ff 	mov    -0xe8(%rbp),%rdx
 11c0e3a:	66 85 c0             	test   %ax,%ax
 11c0e3d:	0f 85 6a ac ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c0e43:	4c 39 a5 58 fe ff ff 	cmp    %r12,-0x1a8(%rbp)
 11c0e4a:	74 2e                	je     11c0e7a <br.encodeCommandPlanWithOptionsWrite+0x543a>
 11c0e4c:	48 89 b5 88 fc ff ff 	mov    %rsi,-0x378(%rbp)
 11c0e53:	48 89 bd 98 fb ff ff 	mov    %rdi,-0x468(%rbp)
 11c0e5a:	4c 89 85 a0 fb ff ff 	mov    %r8,-0x460(%rbp)
 11c0e61:	4c 89 8d a8 fb ff ff 	mov    %r9,-0x458(%rbp)
 11c0e68:	48 8d 85 88 fc ff ff 	lea    -0x378(%rbp),%rax
 11c0e6f:	48 89 d1             	mov    %rdx,%rcx
 11c0e72:	42 ff 24 e5 50 00 01 	jmp    *0x1010050(,%r12,8)
 11c0e79:	01 
 11c0e7a:	48 89 95 00 f5 ff ff 	mov    %rdx,-0xb00(%rbp)
 11c0e81:	48 89 b5 08 f5 ff ff 	mov    %rsi,-0xaf8(%rbp)
 11c0e88:	0f b6 45 c5          	movzbl -0x3b(%rbp),%eax
 11c0e8c:	88 85 10 f5 ff ff    	mov    %al,-0xaf0(%rbp)
 11c0e92:	8b 85 0b fe ff ff    	mov    -0x1f5(%rbp),%eax
 11c0e98:	48 8d 8d 11 f5 ff ff 	lea    -0xaef(%rbp),%rcx
 11c0e9f:	89 41 03             	mov    %eax,0x3(%rcx)
 11c0ea2:	8b 85 08 fe ff ff    	mov    -0x1f8(%rbp),%eax
 11c0ea8:	89 01                	mov    %eax,(%rcx)
 11c0eaa:	48 89 bd 18 f5 ff ff 	mov    %rdi,-0xae8(%rbp)
 11c0eb1:	88 9d 20 f5 ff ff    	mov    %bl,-0xae0(%rbp)
 11c0eb7:	8b 85 13 fe ff ff    	mov    -0x1ed(%rbp),%eax
 11c0ebd:	89 41 13             	mov    %eax,0x13(%rcx)
 11c0ec0:	8b 85 10 fe ff ff    	mov    -0x1f0(%rbp),%eax
 11c0ec6:	89 41 10             	mov    %eax,0x10(%rcx)
 11c0ec9:	4c 89 85 28 f5 ff ff 	mov    %r8,-0xad8(%rbp)
 11c0ed0:	0f b6 45 d1          	movzbl -0x2f(%rbp),%eax
 11c0ed4:	88 85 30 f5 ff ff    	mov    %al,-0xad0(%rbp)
 11c0eda:	8b 85 1b fe ff ff    	mov    -0x1e5(%rbp),%eax
 11c0ee0:	89 41 23             	mov    %eax,0x23(%rcx)
 11c0ee3:	8b 85 18 fe ff ff    	mov    -0x1e8(%rbp),%eax
 11c0ee9:	89 41 20             	mov    %eax,0x20(%rcx)
 11c0eec:	4c 89 8d 38 f5 ff ff 	mov    %r9,-0xac8(%rbp)
 11c0ef3:	0f b6 45 c7          	movzbl -0x39(%rbp),%eax
 11c0ef7:	88 85 40 f5 ff ff    	mov    %al,-0xac0(%rbp)
 11c0efd:	8b 85 23 fe ff ff    	mov    -0x1dd(%rbp),%eax
 11c0f03:	89 41 33             	mov    %eax,0x33(%rcx)
 11c0f06:	8b 85 20 fe ff ff    	mov    -0x1e0(%rbp),%eax
 11c0f0c:	89 41 30             	mov    %eax,0x30(%rcx)
 11c0f0f:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 11c0f16:	48 89 85 48 f5 ff ff 	mov    %rax,-0xab8(%rbp)
 11c0f1d:	0f b6 45 c0          	movzbl -0x40(%rbp),%eax
 11c0f21:	88 85 50 f5 ff ff    	mov    %al,-0xab0(%rbp)
 11c0f27:	8b 85 2b fe ff ff    	mov    -0x1d5(%rbp),%eax
 11c0f2d:	89 41 43             	mov    %eax,0x43(%rcx)
 11c0f30:	8b 85 28 fe ff ff    	mov    -0x1d8(%rbp),%eax
 11c0f36:	89 41 40             	mov    %eax,0x40(%rcx)
 11c0f39:	48 8b 85 d8 fc ff ff 	mov    -0x328(%rbp),%rax
 11c0f40:	48 89 85 58 f5 ff ff 	mov    %rax,-0xaa8(%rbp)
 11c0f47:	0f b6 45 cc          	movzbl -0x34(%rbp),%eax
 11c0f4b:	88 85 60 f5 ff ff    	mov    %al,-0xaa0(%rbp)
 11c0f51:	0f b6 45 c2          	movzbl -0x3e(%rbp),%eax
 11c0f55:	88 85 61 f5 ff ff    	mov    %al,-0xa9f(%rbp)
 11c0f5b:	0f b7 85 54 fe ff ff 	movzwl -0x1ac(%rbp),%eax
 11c0f62:	66 89 41 55          	mov    %ax,0x55(%rcx)
 11c0f66:	8b 85 50 fe ff ff    	mov    -0x1b0(%rbp),%eax
 11c0f6c:	89 41 51             	mov    %eax,0x51(%rcx)
 11c0f6f:	48 8d bd 00 f5 ff ff 	lea    -0xb00(%rbp),%rdi
 11c0f76:	4c 89 fe             	mov    %r15,%rsi
 11c0f79:	c5 f8 77             	vzeroupper 
 11c0f7c:	e8 df f4 03 00       	call   1200460 <br.encoder.distance_block_split.Result.blockIndex>
 11c0f81:	48 8d 04 40          	lea    (%rax,%rax,2),%rax
 11c0f85:	c1 e0 08             	shl    $0x8,%eax
 11c0f88:	48 01 e8             	add    %rbp,%rax
 11c0f8b:	48 05 c4 43 fe ff    	add    $0xfffffffffffe43c4,%rax
 11c0f91:	41 0f b6 9c 05 00 02 	movzbl 0x200(%r13,%rax,1),%ebx
 11c0f98:	00 00 
 11c0f9a:	f6 c3 0f             	test   $0xf,%bl
 11c0f9d:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 11c0fa1:	0f 84 22 fa ff ff    	je     11c09c9 <br.encodeCommandPlanWithOptionsWrite+0x4f89>
 11c0fa7:	46 0f b7 24 68       	movzwl (%rax,%r13,2),%r12d
 11c0fac:	f6 41 08 07          	testb  $0x7,0x8(%rcx)
 11c0fb0:	75 40                	jne    11c0ff2 <br.encodeCommandPlanWithOptionsWrite+0x55b2>
 11c0fb2:	48 8b 39             	mov    (%rcx),%rdi
 11c0fb5:	48 8b 47 08          	mov    0x8(%rdi),%rax
 11c0fb9:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 11c0fbd:	73 11                	jae    11c0fd0 <br.encodeCommandPlanWithOptionsWrite+0x5590>
 11c0fbf:	48 8d 50 01          	lea    0x1(%rax),%rdx
 11c0fc3:	48 89 57 08          	mov    %rdx,0x8(%rdi)
 11c0fc7:	48 8b 17             	mov    (%rdi),%rdx
 11c0fca:	c6 04 02 00          	movb   $0x0,(%rdx,%rax,1)
 11c0fce:	eb 22                	jmp    11c0ff2 <br.encodeCommandPlanWithOptionsWrite+0x55b2>
 11c0fd0:	80 79 09 00          	cmpb   $0x0,0x9(%rcx)
 11c0fd4:	0f 85 2d 09 00 00    	jne    11c1907 <br.encodeCommandPlanWithOptionsWrite+0x5ec7>
 11c0fda:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 11c0fde:	31 d2                	xor    %edx,%edx
 11c0fe0:	e8 8b 2b 00 00       	call   11c3b70 <array_list.Aligned(u8,null).append>
 11c0fe5:	66 85 c0             	test   %ax,%ax
 11c0fe8:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 11c0fec:	0f 85 bb aa ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c0ff2:	0f b6 41 08          	movzbl 0x8(%rcx),%eax
 11c0ff6:	24 07                	and    $0x7,%al
 11c0ff8:	c4 c2 79 f7 f4       	shlx   %eax,%r12d,%esi
 11c0ffd:	48 8b 01             	mov    (%rcx),%rax
 11c1000:	48 8b 10             	mov    (%rax),%rdx
 11c1003:	48 8b 40 08          	mov    0x8(%rax),%rax
 11c1007:	40 08 74 02 ff       	or     %sil,-0x1(%rdx,%rax,1)
 11c100c:	0f b6 41 08          	movzbl 0x8(%rcx),%eax
 11c1010:	24 07                	and    $0x7,%al
 11c1012:	80 e3 0f             	and    $0xf,%bl
 11c1015:	00 c3                	add    %al,%bl
 11c1017:	80 fb 08             	cmp    $0x8,%bl
 11c101a:	0f 86 a3 f9 ff ff    	jbe    11c09c3 <br.encodeCommandPlanWithOptionsWrite+0x4f83>
 11c1020:	41 89 f4             	mov    %esi,%r12d
 11c1023:	48 8b 39             	mov    (%rcx),%rdi
 11c1026:	48 8b 47 08          	mov    0x8(%rdi),%rax
 11c102a:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 11c102e:	73 11                	jae    11c1041 <br.encodeCommandPlanWithOptionsWrite+0x5601>
 11c1030:	48 8d 48 01          	lea    0x1(%rax),%rcx
 11c1034:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 11c1038:	48 8b 0f             	mov    (%rdi),%rcx
 11c103b:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 11c103f:	eb 1e                	jmp    11c105f <br.encodeCommandPlanWithOptionsWrite+0x561f>
 11c1041:	80 79 09 00          	cmpb   $0x0,0x9(%rcx)
 11c1045:	0f 85 bc 08 00 00    	jne    11c1907 <br.encodeCommandPlanWithOptionsWrite+0x5ec7>
 11c104b:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 11c104f:	31 d2                	xor    %edx,%edx
 11c1051:	e8 1a 2b 00 00       	call   11c3b70 <array_list.Aligned(u8,null).append>
 11c1056:	66 85 c0             	test   %ax,%ax
 11c1059:	0f 85 4e aa ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c105f:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 11c1063:	48 8b 01             	mov    (%rcx),%rax
 11c1066:	48 8b 30             	mov    (%rax),%rsi
 11c1069:	48 8b 40 08          	mov    0x8(%rax),%rax
 11c106d:	44 89 e2             	mov    %r12d,%edx
 11c1070:	88 74 06 ff          	mov    %dh,-0x1(%rsi,%rax,1)
 11c1074:	80 fb 11             	cmp    $0x11,%bl
 11c1077:	0f 82 46 f9 ff ff    	jb     11c09c3 <br.encodeCommandPlanWithOptionsWrite+0x4f83>
 11c107d:	48 8b 39             	mov    (%rcx),%rdi
 11c1080:	48 8b 47 08          	mov    0x8(%rdi),%rax
 11c1084:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 11c1088:	0f 82 0f f9 ff ff    	jb     11c099d <br.encodeCommandPlanWithOptionsWrite+0x4f5d>
 11c108e:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c1092:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 11c1096:	0f 85 6b 08 00 00    	jne    11c1907 <br.encodeCommandPlanWithOptionsWrite+0x5ec7>
 11c109c:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 11c10a0:	31 d2                	xor    %edx,%edx
 11c10a2:	e8 c9 2a 00 00       	call   11c3b70 <array_list.Aligned(u8,null).append>
 11c10a7:	66 85 c0             	test   %ax,%ax
 11c10aa:	0f 84 fc f8 ff ff    	je     11c09ac <br.encodeCommandPlanWithOptionsWrite+0x4f6c>
 11c10b0:	e9 f8 a9 ff ff       	jmp    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c10b5:	f6 85 a8 fd ff ff 01 	testb  $0x1,-0x258(%rbp)
 11c10bc:	0f 84 4b 06 00 00    	je     11c170d <br.encodeCommandPlanWithOptionsWrite+0x5ccd>
 11c10c2:	0f b6 85 60 fd ff ff 	movzbl -0x2a0(%rbp),%eax
 11c10c9:	24 03                	and    $0x3,%al
 11c10cb:	3c 03                	cmp    $0x3,%al
 11c10cd:	0f 85 3a 06 00 00    	jne    11c170d <br.encodeCommandPlanWithOptionsWrite+0x5ccd>
 11c10d3:	80 bd e0 fe ff ff 00 	cmpb   $0x0,-0x120(%rbp)
 11c10da:	74 26                	je     11c1102 <br.encodeCommandPlanWithOptionsWrite+0x56c2>
 11c10dc:	80 7d 9e 00          	cmpb   $0x0,-0x62(%rbp)
 11c10e0:	0f 84 79 b1 ff ff    	je     11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11c10e6:	48 8b 85 b0 fd ff ff 	mov    -0x250(%rbp),%rax
 11c10ed:	48 89 c1             	mov    %rax,%rcx
 11c10f0:	48 c1 e9 30          	shr    $0x30,%rcx
 11c10f4:	48 89 4d 90          	mov    %rcx,-0x70(%rbp)
 11c10f8:	48 c1 e8 20          	shr    $0x20,%rax
 11c10fc:	48 89 45 88          	mov    %rax,-0x78(%rbp)
 11c1100:	eb 7f                	jmp    11c1181 <br.encodeCommandPlanWithOptionsWrite+0x5741>
 11c1102:	48 8b 85 80 fe ff ff 	mov    -0x180(%rbp),%rax
 11c1109:	80 38 00             	cmpb   $0x0,(%rax)
 11c110c:	74 2d                	je     11c113b <br.encodeCommandPlanWithOptionsWrite+0x56fb>
 11c110e:	48 8b 85 48 fe ff ff 	mov    -0x1b8(%rbp),%rax
 11c1115:	0f b6 00             	movzbl (%rax),%eax
 11c1118:	83 e0 0f             	and    $0xf,%eax
 11c111b:	48 89 45 88          	mov    %rax,-0x78(%rbp)
 11c111f:	c6 85 92 fd ff ff 00 	movb   $0x0,-0x26e(%rbp)
 11c1126:	48 c7 45 90 00 00 00 	movq   $0x0,-0x70(%rbp)
 11c112d:	00 
 11c112e:	48 c7 85 b0 fd ff ff 	movq   $0x0,-0x250(%rbp)
 11c1135:	00 00 00 00 
 11c1139:	eb 46                	jmp    11c1181 <br.encodeCommandPlanWithOptionsWrite+0x5741>
 11c113b:	48 8d bd b0 f7 ff ff 	lea    -0x850(%rbp),%rdi
 11c1142:	48 8b b5 e8 fd ff ff 	mov    -0x218(%rbp),%rsi
 11c1149:	8b 95 30 fe ff ff    	mov    -0x1d0(%rbp),%edx
 11c114f:	8b 8d 34 fe ff ff    	mov    -0x1cc(%rbp),%ecx
 11c1155:	45 31 c0             	xor    %r8d,%r8d
 11c1158:	c5 f8 77             	vzeroupper 
 11c115b:	e8 90 f4 03 00       	call   12005f0 <br.encoder.distance.encodeWithFormat>
 11c1160:	48 8b 8d b0 f7 ff ff 	mov    -0x850(%rbp),%rcx
 11c1167:	48 89 c8             	mov    %rcx,%rax
 11c116a:	48 c1 e8 20          	shr    $0x20,%rax
 11c116e:	48 89 45 88          	mov    %rax,-0x78(%rbp)
 11c1172:	48 89 8d b0 fd ff ff 	mov    %rcx,-0x250(%rbp)
 11c1179:	48 c1 e9 30          	shr    $0x30,%rcx
 11c117d:	48 89 4d 90          	mov    %rcx,-0x70(%rbp)
 11c1181:	4c 8d a5 00 f0 ff ff 	lea    -0x1000(%rbp),%r12
 11c1188:	80 7d cb 00          	cmpb   $0x0,-0x35(%rbp)
 11c118c:	0f 84 44 01 00 00    	je     11c12d6 <br.encodeCommandPlanWithOptionsWrite+0x5896>
 11c1192:	8b 85 b3 fe ff ff    	mov    -0x14d(%rbp),%eax
 11c1198:	48 8d 8d a9 f4 ff ff 	lea    -0xb57(%rbp),%rcx
 11c119f:	89 41 03             	mov    %eax,0x3(%rcx)
 11c11a2:	8b 85 b0 fe ff ff    	mov    -0x150(%rbp),%eax
 11c11a8:	89 01                	mov    %eax,(%rcx)
 11c11aa:	8b 85 bb fe ff ff    	mov    -0x145(%rbp),%eax
 11c11b0:	89 41 13             	mov    %eax,0x13(%rcx)
 11c11b3:	8b 85 b8 fe ff ff    	mov    -0x148(%rbp),%eax
 11c11b9:	89 41 10             	mov    %eax,0x10(%rcx)
 11c11bc:	8b 85 c3 fe ff ff    	mov    -0x13d(%rbp),%eax
 11c11c2:	89 41 23             	mov    %eax,0x23(%rcx)
 11c11c5:	8b 85 c0 fe ff ff    	mov    -0x140(%rbp),%eax
 11c11cb:	89 41 20             	mov    %eax,0x20(%rcx)
 11c11ce:	8b 85 cb fe ff ff    	mov    -0x135(%rbp),%eax
 11c11d4:	89 41 33             	mov    %eax,0x33(%rcx)
 11c11d7:	8b 85 c8 fe ff ff    	mov    -0x138(%rbp),%eax
 11c11dd:	89 41 30             	mov    %eax,0x30(%rcx)
 11c11e0:	8b 85 d3 fe ff ff    	mov    -0x12d(%rbp),%eax
 11c11e6:	89 41 43             	mov    %eax,0x43(%rcx)
 11c11e9:	8b 85 d0 fe ff ff    	mov    -0x130(%rbp),%eax
 11c11ef:	89 41 40             	mov    %eax,0x40(%rcx)
 11c11f2:	0f b7 85 f8 fe ff ff 	movzwl -0x108(%rbp),%eax
 11c11f9:	66 89 41 55          	mov    %ax,0x55(%rcx)
 11c11fd:	8b 85 f4 fe ff ff    	mov    -0x10c(%rbp),%eax
 11c1203:	89 41 51             	mov    %eax,0x51(%rcx)
 11c1206:	48 8b 85 d8 fe ff ff 	mov    -0x128(%rbp),%rax
 11c120d:	48 89 85 98 f4 ff ff 	mov    %rax,-0xb68(%rbp)
 11c1214:	48 8b 85 60 fe ff ff 	mov    -0x1a0(%rbp),%rax
 11c121b:	48 89 85 a0 f4 ff ff 	mov    %rax,-0xb60(%rbp)
 11c1222:	0f b6 45 d5          	movzbl -0x2b(%rbp),%eax
 11c1226:	88 85 a8 f4 ff ff    	mov    %al,-0xb58(%rbp)
 11c122c:	48 8b 85 68 fe ff ff 	mov    -0x198(%rbp),%rax
 11c1233:	48 89 85 b0 f4 ff ff 	mov    %rax,-0xb50(%rbp)
 11c123a:	0f b6 45 d4          	movzbl -0x2c(%rbp),%eax
 11c123e:	88 85 b8 f4 ff ff    	mov    %al,-0xb48(%rbp)
 11c1244:	48 8b 85 70 fe ff ff 	mov    -0x190(%rbp),%rax
 11c124b:	48 89 85 c0 f4 ff ff 	mov    %rax,-0xb40(%rbp)
 11c1252:	0f b6 45 d7          	movzbl -0x29(%rbp),%eax
 11c1256:	88 85 c8 f4 ff ff    	mov    %al,-0xb38(%rbp)
 11c125c:	48 8b 85 78 fe ff ff 	mov    -0x188(%rbp),%rax
 11c1263:	48 89 85 d0 f4 ff ff 	mov    %rax,-0xb30(%rbp)
 11c126a:	0f b6 45 ce          	movzbl -0x32(%rbp),%eax
 11c126e:	88 85 d8 f4 ff ff    	mov    %al,-0xb28(%rbp)
 11c1274:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 11c127b:	48 89 85 e0 f4 ff ff 	mov    %rax,-0xb20(%rbp)
 11c1282:	0f b6 45 c4          	movzbl -0x3c(%rbp),%eax
 11c1286:	88 85 e8 f4 ff ff    	mov    %al,-0xb18(%rbp)
 11c128c:	48 8b 85 00 fd ff ff 	mov    -0x300(%rbp),%rax
 11c1293:	48 89 85 f0 f4 ff ff 	mov    %rax,-0xb10(%rbp)
 11c129a:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 11c129e:	88 85 f8 f4 ff ff    	mov    %al,-0xb08(%rbp)
 11c12a4:	0f b6 45 c9          	movzbl -0x37(%rbp),%eax
 11c12a8:	88 85 f9 f4 ff ff    	mov    %al,-0xb07(%rbp)
 11c12ae:	48 8d bd 98 f4 ff ff 	lea    -0xb68(%rbp),%rdi
 11c12b5:	48 8b b5 e0 fd ff ff 	mov    -0x220(%rbp),%rsi
 11c12bc:	c5 f8 77             	vzeroupper 
 11c12bf:	e8 9c f1 03 00       	call   1200460 <br.encoder.distance_block_split.Result.blockIndex>
 11c12c4:	48 69 c0 a8 00 00 00 	imul   $0xa8,%rax,%rax
 11c12cb:	4c 8d 24 28          	lea    (%rax,%rbp,1),%r12
 11c12cf:	49 81 c4 28 cb ff ff 	add    $0xffffffffffffcb28,%r12
 11c12d6:	4c 8d b5 70 ee ff ff 	lea    -0x1190(%rbp),%r14
 11c12dd:	80 7d cb 00          	cmpb   $0x0,-0x35(%rbp)
 11c12e1:	0f 84 f2 01 00 00    	je     11c14d9 <br.encodeCommandPlanWithOptionsWrite+0x5a99>
 11c12e7:	8b 85 b3 fe ff ff    	mov    -0x14d(%rbp),%eax
 11c12ed:	48 8d 8d 41 f4 ff ff 	lea    -0xbbf(%rbp),%rcx
 11c12f4:	89 41 03             	mov    %eax,0x3(%rcx)
 11c12f7:	8b 85 b0 fe ff ff    	mov    -0x150(%rbp),%eax
 11c12fd:	89 01                	mov    %eax,(%rcx)
 11c12ff:	8b 85 bb fe ff ff    	mov    -0x145(%rbp),%eax
 11c1305:	89 41 13             	mov    %eax,0x13(%rcx)
 11c1308:	8b 85 b8 fe ff ff    	mov    -0x148(%rbp),%eax
 11c130e:	89 41 10             	mov    %eax,0x10(%rcx)
 11c1311:	8b 85 c3 fe ff ff    	mov    -0x13d(%rbp),%eax
 11c1317:	89 41 23             	mov    %eax,0x23(%rcx)
 11c131a:	8b 85 c0 fe ff ff    	mov    -0x140(%rbp),%eax
 11c1320:	89 41 20             	mov    %eax,0x20(%rcx)
 11c1323:	8b 85 cb fe ff ff    	mov    -0x135(%rbp),%eax
 11c1329:	89 41 33             	mov    %eax,0x33(%rcx)
 11c132c:	8b 85 c8 fe ff ff    	mov    -0x138(%rbp),%eax
 11c1332:	89 41 30             	mov    %eax,0x30(%rcx)
 11c1335:	8b 85 d3 fe ff ff    	mov    -0x12d(%rbp),%eax
 11c133b:	89 41 43             	mov    %eax,0x43(%rcx)
 11c133e:	8b 85 d0 fe ff ff    	mov    -0x130(%rbp),%eax
 11c1344:	89 41 40             	mov    %eax,0x40(%rcx)
 11c1347:	0f b7 85 f8 fe ff ff 	movzwl -0x108(%rbp),%eax
 11c134e:	66 89 41 55          	mov    %ax,0x55(%rcx)
 11c1352:	8b 85 f4 fe ff ff    	mov    -0x10c(%rbp),%eax
 11c1358:	89 41 51             	mov    %eax,0x51(%rcx)
 11c135b:	48 8b 85 d8 fe ff ff 	mov    -0x128(%rbp),%rax
 11c1362:	48 89 85 30 f4 ff ff 	mov    %rax,-0xbd0(%rbp)
 11c1369:	48 8b 85 60 fe ff ff 	mov    -0x1a0(%rbp),%rax
 11c1370:	48 89 85 38 f4 ff ff 	mov    %rax,-0xbc8(%rbp)
 11c1377:	0f b6 45 d5          	movzbl -0x2b(%rbp),%eax
 11c137b:	88 85 40 f4 ff ff    	mov    %al,-0xbc0(%rbp)
 11c1381:	48 8b 85 68 fe ff ff 	mov    -0x198(%rbp),%rax
 11c1388:	48 89 85 48 f4 ff ff 	mov    %rax,-0xbb8(%rbp)
 11c138f:	0f b6 45 d4          	movzbl -0x2c(%rbp),%eax
 11c1393:	88 85 50 f4 ff ff    	mov    %al,-0xbb0(%rbp)
 11c1399:	48 8b 85 70 fe ff ff 	mov    -0x190(%rbp),%rax
 11c13a0:	48 89 85 58 f4 ff ff 	mov    %rax,-0xba8(%rbp)
 11c13a7:	0f b6 45 d7          	movzbl -0x29(%rbp),%eax
 11c13ab:	88 85 60 f4 ff ff    	mov    %al,-0xba0(%rbp)
 11c13b1:	48 8b 85 78 fe ff ff 	mov    -0x188(%rbp),%rax
 11c13b8:	48 89 85 68 f4 ff ff 	mov    %rax,-0xb98(%rbp)
 11c13bf:	0f b6 45 ce          	movzbl -0x32(%rbp),%eax
 11c13c3:	88 85 70 f4 ff ff    	mov    %al,-0xb90(%rbp)
 11c13c9:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 11c13d0:	48 89 85 78 f4 ff ff 	mov    %rax,-0xb88(%rbp)
 11c13d7:	0f b6 45 c4          	movzbl -0x3c(%rbp),%eax
 11c13db:	88 85 80 f4 ff ff    	mov    %al,-0xb80(%rbp)
 11c13e1:	48 8b 85 00 fd ff ff 	mov    -0x300(%rbp),%rax
 11c13e8:	48 89 85 88 f4 ff ff 	mov    %rax,-0xb78(%rbp)
 11c13ef:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 11c13f3:	88 85 90 f4 ff ff    	mov    %al,-0xb70(%rbp)
 11c13f9:	0f b6 45 c9          	movzbl -0x37(%rbp),%eax
 11c13fd:	88 85 91 f4 ff ff    	mov    %al,-0xb6f(%rbp)
 11c1403:	48 8d bd 30 f4 ff ff 	lea    -0xbd0(%rbp),%rdi
 11c140a:	48 8b b5 e0 fd ff ff 	mov    -0x220(%rbp),%rsi
 11c1411:	c5 f8 77             	vzeroupper 
 11c1414:	e8 47 f0 03 00       	call   1200460 <br.encoder.distance_block_split.Result.blockIndex>
 11c1419:	48 69 c0 ee 00 00 00 	imul   $0xee,%rax,%rax
 11c1420:	4c 8d 34 28          	lea    (%rax,%rbp,1),%r14
 11c1424:	49 81 c6 8a 40 ff ff 	add    $0xffffffffffff408a,%r14
 11c142b:	31 db                	xor    %ebx,%ebx
 11c142d:	4c 8b ad f0 fc ff ff 	mov    -0x310(%rbp),%r13
 11c1434:	eb 09                	jmp    11c143f <br.encodeCommandPlanWithOptionsWrite+0x59ff>
 11c1436:	49 39 dd             	cmp    %rbx,%r13
 11c1439:	0f 84 9a 00 00 00    	je     11c14d9 <br.encodeCommandPlanWithOptionsWrite+0x5a99>
 11c143f:	48 8b 85 60 fe ff ff 	mov    -0x1a0(%rbp),%rax
 11c1446:	48 89 85 e8 f9 ff ff 	mov    %rax,-0x618(%rbp)
 11c144d:	48 8b 85 68 fe ff ff 	mov    -0x198(%rbp),%rax
 11c1454:	48 89 85 f0 f9 ff ff 	mov    %rax,-0x610(%rbp)
 11c145b:	48 8b 85 70 fe ff ff 	mov    -0x190(%rbp),%rax
 11c1462:	48 89 85 f8 f9 ff ff 	mov    %rax,-0x608(%rbp)
 11c1469:	48 8b 85 78 fe ff ff 	mov    -0x188(%rbp),%rax
 11c1470:	48 89 85 00 fa ff ff 	mov    %rax,-0x600(%rbp)
 11c1477:	48 8d 85 e8 f9 ff ff 	lea    -0x618(%rbp),%rax
 11c147e:	48 8b 8d d8 fe ff ff 	mov    -0x128(%rbp),%rcx
 11c1485:	ff 24 dd 78 00 01 01 	jmp    *0x1010078(,%rbx,8)
 11c148c:	48 8d 85 f0 f9 ff ff 	lea    -0x610(%rbp),%rax
 11c1493:	eb 10                	jmp    11c14a5 <br.encodeCommandPlanWithOptionsWrite+0x5a65>
 11c1495:	48 8d 85 00 fa ff ff 	lea    -0x600(%rbp),%rax
 11c149c:	eb 07                	jmp    11c14a5 <br.encodeCommandPlanWithOptionsWrite+0x5a65>
 11c149e:	48 8d 85 f8 f9 ff ff 	lea    -0x608(%rbp),%rax
 11c14a5:	48 8b 08             	mov    (%rax),%rcx
 11c14a8:	48 ff c3             	inc    %rbx
 11c14ab:	48 39 8d e0 fd ff ff 	cmp    %rcx,-0x220(%rbp)
 11c14b2:	75 82                	jne    11c1436 <br.encodeCommandPlanWithOptionsWrite+0x59f6>
 11c14b4:	48 8d bd 50 ec ff ff 	lea    -0x13b0(%rbp),%rdi
 11c14bb:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 11c14bf:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 11c14c3:	48 89 d9             	mov    %rbx,%rcx
 11c14c6:	e8 15 29 00 00       	call   11c3de0 <br.CommandBlockLengthCode.writeLength>
 11c14cb:	66 85 c0             	test   %ax,%ax
 11c14ce:	0f 84 62 ff ff ff    	je     11c1436 <br.encodeCommandPlanWithOptionsWrite+0x59f6>
 11c14d4:	e9 d4 a5 ff ff       	jmp    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c14d9:	49 8b 04 24          	mov    (%r12),%rax
 11c14dd:	48 83 f8 01          	cmp    $0x1,%rax
 11c14e1:	0f 86 f1 01 00 00    	jbe    11c16d8 <br.encodeCommandPlanWithOptionsWrite+0x5c98>
 11c14e7:	48 83 f8 04          	cmp    $0x4,%rax
 11c14eb:	77 55                	ja     11c1542 <br.encodeCommandPlanWithOptionsWrite+0x5b02>
 11c14ed:	48 8d bd 7c fc ff ff 	lea    -0x384(%rbp),%rdi
 11c14f4:	4c 89 e6             	mov    %r12,%rsi
 11c14f7:	48 8b 55 88          	mov    -0x78(%rbp),%rdx
 11c14fb:	c5 f8 77             	vzeroupper 
 11c14fe:	e8 7d 65 04 00       	call   1207a80 <br.encoder.command_plan.PrefixAlphabetFor(520).simpleCode>
 11c1503:	44 0f b7 b5 7c fc ff 	movzwl -0x384(%rbp),%r14d
 11c150a:	ff 
 11c150b:	0f b6 9d 7e fc ff ff 	movzbl -0x382(%rbp),%ebx
 11c1512:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c1516:	f6 40 08 07          	testb  $0x7,0x8(%rax)
 11c151a:	0f 85 82 00 00 00    	jne    11c15a2 <br.encodeCommandPlanWithOptionsWrite+0x5b62>
 11c1520:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c1524:	48 8b 38             	mov    (%rax),%rdi
 11c1527:	48 8b 47 08          	mov    0x8(%rdi),%rax
 11c152b:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 11c152f:	73 4f                	jae    11c1580 <br.encodeCommandPlanWithOptionsWrite+0x5b40>
 11c1531:	48 8d 48 01          	lea    0x1(%rax),%rcx
 11c1535:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 11c1539:	48 8b 0f             	mov    (%rdi),%rcx
 11c153c:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 11c1540:	eb 60                	jmp    11c15a2 <br.encodeCommandPlanWithOptionsWrite+0x5b62>
 11c1542:	0f b7 45 88          	movzwl -0x78(%rbp),%eax
 11c1546:	45 0f b7 24 46       	movzwl (%r14,%rax,2),%r12d
 11c154b:	41 0f b6 9c 06 9e 00 	movzbl 0x9e(%r14,%rax,1),%ebx
 11c1552:	00 00 
 11c1554:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c1558:	f6 40 08 07          	testb  $0x7,0x8(%rax)
 11c155c:	75 7b                	jne    11c15d9 <br.encodeCommandPlanWithOptionsWrite+0x5b99>
 11c155e:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c1562:	48 8b 38             	mov    (%rax),%rdi
 11c1565:	48 8b 47 08          	mov    0x8(%rdi),%rax
 11c1569:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 11c156d:	73 45                	jae    11c15b4 <br.encodeCommandPlanWithOptionsWrite+0x5b74>
 11c156f:	48 8d 48 01          	lea    0x1(%rax),%rcx
 11c1573:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 11c1577:	48 8b 0f             	mov    (%rdi),%rcx
 11c157a:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 11c157e:	eb 59                	jmp    11c15d9 <br.encodeCommandPlanWithOptionsWrite+0x5b99>
 11c1580:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c1584:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 11c1588:	0f 85 79 03 00 00    	jne    11c1907 <br.encodeCommandPlanWithOptionsWrite+0x5ec7>
 11c158e:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 11c1592:	31 d2                	xor    %edx,%edx
 11c1594:	e8 d7 25 00 00       	call   11c3b70 <array_list.Aligned(u8,null).append>
 11c1599:	66 85 c0             	test   %ax,%ax
 11c159c:	0f 85 0b a5 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c15a2:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c15a6:	0f b6 48 08          	movzbl 0x8(%rax),%ecx
 11c15aa:	80 e1 07             	and    $0x7,%cl
 11c15ad:	c4 c2 71 f7 f6       	shlx   %ecx,%r14d,%esi
 11c15b2:	eb 35                	jmp    11c15e9 <br.encodeCommandPlanWithOptionsWrite+0x5ba9>
 11c15b4:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c15b8:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 11c15bc:	0f 85 45 03 00 00    	jne    11c1907 <br.encodeCommandPlanWithOptionsWrite+0x5ec7>
 11c15c2:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 11c15c6:	31 d2                	xor    %edx,%edx
 11c15c8:	c5 f8 77             	vzeroupper 
 11c15cb:	e8 a0 25 00 00       	call   11c3b70 <array_list.Aligned(u8,null).append>
 11c15d0:	66 85 c0             	test   %ax,%ax
 11c15d3:	0f 85 d4 a4 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c15d9:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c15dd:	0f b6 48 08          	movzbl 0x8(%rax),%ecx
 11c15e1:	80 e1 07             	and    $0x7,%cl
 11c15e4:	c4 c2 71 f7 f4       	shlx   %ecx,%r12d,%esi
 11c15e9:	48 8b 08             	mov    (%rax),%rcx
 11c15ec:	48 8b 11             	mov    (%rcx),%rdx
 11c15ef:	48 8b 49 08          	mov    0x8(%rcx),%rcx
 11c15f3:	40 08 74 0a ff       	or     %sil,-0x1(%rdx,%rcx,1)
 11c15f8:	0f b6 40 08          	movzbl 0x8(%rax),%eax
 11c15fc:	24 07                	and    $0x7,%al
 11c15fe:	80 e3 0f             	and    $0xf,%bl
 11c1601:	00 c3                	add    %al,%bl
 11c1603:	80 fb 08             	cmp    $0x8,%bl
 11c1606:	0f 86 c2 00 00 00    	jbe    11c16ce <br.encodeCommandPlanWithOptionsWrite+0x5c8e>
 11c160c:	41 89 f6             	mov    %esi,%r14d
 11c160f:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c1613:	48 8b 38             	mov    (%rax),%rdi
 11c1616:	48 8b 47 08          	mov    0x8(%rdi),%rax
 11c161a:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 11c161e:	73 11                	jae    11c1631 <br.encodeCommandPlanWithOptionsWrite+0x5bf1>
 11c1620:	48 8d 48 01          	lea    0x1(%rax),%rcx
 11c1624:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 11c1628:	48 8b 0f             	mov    (%rdi),%rcx
 11c162b:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 11c162f:	eb 25                	jmp    11c1656 <br.encodeCommandPlanWithOptionsWrite+0x5c16>
 11c1631:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c1635:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 11c1639:	0f 85 c8 02 00 00    	jne    11c1907 <br.encodeCommandPlanWithOptionsWrite+0x5ec7>
 11c163f:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 11c1643:	31 d2                	xor    %edx,%edx
 11c1645:	c5 f8 77             	vzeroupper 
 11c1648:	e8 23 25 00 00       	call   11c3b70 <array_list.Aligned(u8,null).append>
 11c164d:	66 85 c0             	test   %ax,%ax
 11c1650:	0f 85 57 a4 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c1656:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c165a:	48 8b 00             	mov    (%rax),%rax
 11c165d:	48 8b 08             	mov    (%rax),%rcx
 11c1660:	48 8b 40 08          	mov    0x8(%rax),%rax
 11c1664:	44 89 f2             	mov    %r14d,%edx
 11c1667:	88 74 01 ff          	mov    %dh,-0x1(%rcx,%rax,1)
 11c166b:	80 fb 11             	cmp    $0x11,%bl
 11c166e:	72 5e                	jb     11c16ce <br.encodeCommandPlanWithOptionsWrite+0x5c8e>
 11c1670:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c1674:	48 8b 38             	mov    (%rax),%rdi
 11c1677:	48 8b 47 08          	mov    0x8(%rdi),%rax
 11c167b:	48 3b 47 10          	cmp    0x10(%rdi),%rax
 11c167f:	73 11                	jae    11c1692 <br.encodeCommandPlanWithOptionsWrite+0x5c52>
 11c1681:	48 8d 48 01          	lea    0x1(%rax),%rcx
 11c1685:	48 89 4f 08          	mov    %rcx,0x8(%rdi)
 11c1689:	48 8b 0f             	mov    (%rdi),%rcx
 11c168c:	c6 04 01 00          	movb   $0x0,(%rcx,%rax,1)
 11c1690:	eb 25                	jmp    11c16b7 <br.encodeCommandPlanWithOptionsWrite+0x5c77>
 11c1692:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c1696:	80 78 09 00          	cmpb   $0x0,0x9(%rax)
 11c169a:	0f 85 67 02 00 00    	jne    11c1907 <br.encodeCommandPlanWithOptionsWrite+0x5ec7>
 11c16a0:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 11c16a4:	31 d2                	xor    %edx,%edx
 11c16a6:	c5 f8 77             	vzeroupper 
 11c16a9:	e8 c2 24 00 00       	call   11c3b70 <array_list.Aligned(u8,null).append>
 11c16ae:	66 85 c0             	test   %ax,%ax
 11c16b1:	0f 85 f6 a3 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c16b7:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c16bb:	48 8b 00             	mov    (%rax),%rax
 11c16be:	48 8b 08             	mov    (%rax),%rcx
 11c16c1:	48 8b 40 08          	mov    0x8(%rax),%rax
 11c16c5:	41 c1 ee 10          	shr    $0x10,%r14d
 11c16c9:	44 88 74 01 ff       	mov    %r14b,-0x1(%rcx,%rax,1)
 11c16ce:	80 e3 07             	and    $0x7,%bl
 11c16d1:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c16d5:	88 58 08             	mov    %bl,0x8(%rax)
 11c16d8:	f6 45 90 1f          	testb  $0x1f,-0x70(%rbp)
 11c16dc:	74 28                	je     11c1706 <br.encodeCommandPlanWithOptionsWrite+0x5cc6>
 11c16de:	8b 95 b0 fd ff ff    	mov    -0x250(%rbp),%edx
 11c16e4:	48 8b 45 90          	mov    -0x70(%rbp),%rax
 11c16e8:	24 1f                	and    $0x1f,%al
 11c16ea:	0f b6 c8             	movzbl %al,%ecx
 11c16ed:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 11c16f1:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 11c16f5:	c5 f8 77             	vzeroupper 
 11c16f8:	e8 03 22 00 00       	call   11c3900 <br.BitWriter.writeBits>
 11c16fd:	66 85 c0             	test   %ax,%ax
 11c1700:	0f 85 a7 a3 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c1706:	48 ff 85 e0 fd ff ff 	incq   -0x220(%rbp)
 11c170d:	80 bd e0 fe ff ff 00 	cmpb   $0x0,-0x120(%rbp)
 11c1714:	74 12                	je     11c1728 <br.encodeCommandPlanWithOptionsWrite+0x5ce8>
 11c1716:	c5 fc 10 85 40 ee ff 	vmovups -0x11c0(%rbp),%ymm0
 11c171d:	ff 
 11c171e:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 11c1725:	ff 
 11c1726:	eb 6a                	jmp    11c1792 <br.encodeCommandPlanWithOptionsWrite+0x5d52>
 11c1728:	80 bd 60 ff ff ff 01 	cmpb   $0x1,-0xa0(%rbp)
 11c172f:	75 61                	jne    11c1792 <br.encodeCommandPlanWithOptionsWrite+0x5d52>
 11c1731:	48 8b 85 80 fe ff ff 	mov    -0x180(%rbp),%rax
 11c1738:	80 38 00             	cmpb   $0x0,(%rax)
 11c173b:	74 14                	je     11c1751 <br.encodeCommandPlanWithOptionsWrite+0x5d11>
 11c173d:	48 8b 85 48 fe ff ff 	mov    -0x1b8(%rbp),%rax
 11c1744:	0f b6 00             	movzbl (%rax),%eax
 11c1747:	24 0f                	and    $0xf,%al
 11c1749:	3a 45 9f             	cmp    -0x61(%rbp),%al
 11c174c:	0f 95 c0             	setne  %al
 11c174f:	eb 02                	jmp    11c1753 <br.encodeCommandPlanWithOptionsWrite+0x5d13>
 11c1751:	b0 01                	mov    $0x1,%al
 11c1753:	0f b6 8d 80 fd ff ff 	movzbl -0x280(%rbp),%ecx
 11c175a:	80 e1 03             	and    $0x3,%cl
 11c175d:	80 f9 02             	cmp    $0x2,%cl
 11c1760:	74 30                	je     11c1792 <br.encodeCommandPlanWithOptionsWrite+0x5d52>
 11c1762:	84 c0                	test   %al,%al
 11c1764:	74 2c                	je     11c1792 <br.encodeCommandPlanWithOptionsWrite+0x5d52>
 11c1766:	c5 f8 10 85 28 fd ff 	vmovups -0x2d8(%rbp),%xmm0
 11c176d:	ff 
 11c176e:	c5 f8 29 85 20 fd ff 	vmovaps %xmm0,-0x2e0(%rbp)
 11c1775:	ff 
 11c1776:	48 8b 85 38 fd ff ff 	mov    -0x2c8(%rbp),%rax
 11c177d:	48 89 85 30 fd ff ff 	mov    %rax,-0x2d0(%rbp)
 11c1784:	48 8b 85 e8 fd ff ff 	mov    -0x218(%rbp),%rax
 11c178b:	48 89 85 38 fd ff ff 	mov    %rax,-0x2c8(%rbp)
 11c1792:	48 8b 4d 80          	mov    -0x80(%rbp),%rcx
 11c1796:	48 ff c1             	inc    %rcx
 11c1799:	48 89 4d 80          	mov    %rcx,-0x80(%rbp)
 11c179d:	48 3b 8d 40 ff ff ff 	cmp    -0xc0(%rbp),%rcx
 11c17a4:	0f 85 2c e7 ff ff    	jne    11bfed6 <br.encodeCommandPlanWithOptionsWrite+0x4496>
 11c17aa:	48 83 bd f0 fd ff ff 	cmpq   $0x0,-0x210(%rbp)
 11c17b1:	00 
 11c17b2:	0f 84 c1 0a 00 00    	je     11c2279 <br.encodeCommandPlanWithOptionsWrite+0x6839>
 11c17b8:	48 8b 85 f0 fd ff ff 	mov    -0x210(%rbp),%rax
 11c17bf:	c6 80 12 27 02 00 00 	movb   $0x0,0x22712(%rax)
 11c17c6:	8b 8d 5c ff ff ff    	mov    -0xa4(%rbp),%ecx
 11c17cc:	66 89 88 10 27 02 00 	mov    %cx,0x22710(%rax)
 11c17d3:	48 8b 85 08 ff ff ff 	mov    -0xf8(%rbp),%rax
 11c17da:	80 38 00             	cmpb   $0x0,(%rax)
 11c17dd:	74 0d                	je     11c17ec <br.encodeCommandPlanWithOptionsWrite+0x5dac>
 11c17df:	48 8b 85 58 fd ff ff 	mov    -0x2a8(%rbp),%rax
 11c17e6:	0f b6 00             	movzbl (%rax),%eax
 11c17e9:	88 45 9d             	mov    %al,-0x63(%rbp)
 11c17ec:	0f b6 4d 9d          	movzbl -0x63(%rbp),%ecx
 11c17f0:	80 e1 03             	and    $0x3,%cl
 11c17f3:	48 8b 85 f0 fd ff ff 	mov    -0x210(%rbp),%rax
 11c17fa:	88 88 13 27 02 00    	mov    %cl,0x22713(%rax)
 11c1800:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11c1804:	c5 f8 11 00          	vmovups %xmm0,(%rax)
 11c1808:	48 8b 85 08 ff ff ff 	mov    -0xf8(%rbp),%rax
 11c180f:	80 38 00             	cmpb   $0x0,(%rax)
 11c1812:	0f 84 d3 04 00 00    	je     11c1ceb <br.encodeCommandPlanWithOptionsWrite+0x62ab>
 11c1818:	48 8b 85 08 fd ff ff 	mov    -0x2f8(%rbp),%rax
 11c181f:	c5 f8 10 40 40       	vmovups 0x40(%rax),%xmm0
 11c1824:	c5 fc 10 08          	vmovups (%rax),%ymm1
 11c1828:	c5 fc 10 50 20       	vmovups 0x20(%rax),%ymm2
 11c182d:	c5 fc 11 95 b0 ef ff 	vmovups %ymm2,-0x1050(%rbp)
 11c1834:	ff 
 11c1835:	c5 f8 29 85 d0 ef ff 	vmovaps %xmm0,-0x1030(%rbp)
 11c183c:	ff 
 11c183d:	c5 fc 11 8d 90 ef ff 	vmovups %ymm1,-0x1070(%rbp)
 11c1844:	ff 
 11c1845:	48 8b 85 f0 fd ff ff 	mov    -0x210(%rbp),%rax
 11c184c:	48 8d 98 90 13 01 00 	lea    0x11390(%rax),%rbx
 11c1853:	41 be 0a 00 00 00    	mov    $0xa,%r14d
 11c1859:	48 8d bb 80 ec fe ff 	lea    -0x11380(%rbx),%rdi
 11c1860:	c5 fc 10 85 90 ef ff 	vmovups -0x1070(%rbp),%ymm0
 11c1867:	ff 
 11c1868:	c5 fc 10 8d b0 ef ff 	vmovups -0x1050(%rbp),%ymm1
 11c186f:	ff 
 11c1870:	c5 f8 10 95 c0 ef ff 	vmovups -0x1040(%rbp),%xmm2
 11c1877:	ff 
 11c1878:	c5 f8 11 95 50 fc ff 	vmovups %xmm2,-0x3b0(%rbp)
 11c187f:	ff 
 11c1880:	c5 f8 10 95 d0 ef ff 	vmovups -0x1030(%rbp),%xmm2
 11c1887:	ff 
 11c1888:	c5 f8 11 95 60 fc ff 	vmovups %xmm2,-0x3a0(%rbp)
 11c188f:	ff 
 11c1890:	c5 fc 11 8d 40 fc ff 	vmovups %ymm1,-0x3c0(%rbp)
 11c1897:	ff 
 11c1898:	c5 fc 11 85 20 fc ff 	vmovups %ymm0,-0x3e0(%rbp)
 11c189f:	ff 
 11c18a0:	42 0f b6 84 35 20 fc 	movzbl -0x3e0(%rbp,%r14,1),%eax
 11c18a7:	ff ff 
 11c18a9:	89 c1                	mov    %eax,%ecx
 11c18ab:	c1 e1 09             	shl    $0x9,%ecx
 11c18ae:	48 8d 0c c1          	lea    (%rcx,%rax,8),%rcx
 11c18b2:	48 8d 14 29          	lea    (%rcx,%rbp,1),%rdx
 11c18b6:	48 81 c2 40 1d fd ff 	add    $0xfffffffffffd1d40,%rdx
 11c18bd:	89 c1                	mov    %eax,%ecx
 11c18bf:	c1 e1 08             	shl    $0x8,%ecx
 11c18c2:	48 01 e9             	add    %rbp,%rcx
 11c18c5:	48 81 c1 c4 c1 fd ff 	add    $0xfffffffffffdc1c4,%rcx
 11c18cc:	c1 e0 0a             	shl    $0xa,%eax
 11c18cf:	4c 8d 04 28          	lea    (%rax,%rbp,1),%r8
 11c18d3:	49 81 c0 40 ba fb ff 	add    $0xfffffffffffbba40,%r8
 11c18da:	48 89 de             	mov    %rbx,%rsi
 11c18dd:	c5 f8 77             	vzeroupper 
 11c18e0:	e8 8b 1e 00 00       	call   11c3770 <br.encoder.hq_codec.huffman_model.table__anon_32165>
 11c18e5:	66 85 c0             	test   %ax,%ax
 11c18e8:	0f 85 bf a1 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c18ee:	49 ff c6             	inc    %r14
 11c18f1:	48 81 c3 00 04 00 00 	add    $0x400,%rbx
 11c18f8:	49 83 fe 4a          	cmp    $0x4a,%r14
 11c18fc:	0f 85 57 ff ff ff    	jne    11c1859 <br.encodeCommandPlanWithOptionsWrite+0x5e19>
 11c1902:	e9 23 06 00 00       	jmp    11c1f2a <br.encodeCommandPlanWithOptionsWrite+0x64ea>
 11c1907:	66 b8 1a 00          	mov    $0x1a,%ax
 11c190b:	e9 9d a1 ff ff       	jmp    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c1910:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 11c1914:	0a 45 c8             	or     -0x38(%rbp),%al
 11c1917:	a8 01                	test   $0x1,%al
 11c1919:	74 30                	je     11c194b <br.encodeCommandPlanWithOptionsWrite+0x5f0b>
 11c191b:	44 0f b6 65 d2       	movzbl -0x2e(%rbp),%r12d
 11c1920:	41 83 e4 01          	and    $0x1,%r12d
 11c1924:	49 83 f4 03          	xor    $0x3,%r12
 11c1928:	eb 53                	jmp    11c197d <br.encodeCommandPlanWithOptionsWrite+0x5f3d>
 11c192a:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 11c192e:	0a 45 c9             	or     -0x37(%rbp),%al
 11c1931:	a8 01                	test   $0x1,%al
 11c1933:	0f 84 21 01 00 00    	je     11c1a5a <br.encodeCommandPlanWithOptionsWrite+0x601a>
 11c1939:	44 0f b6 7d d3       	movzbl -0x2d(%rbp),%r15d
 11c193e:	41 83 e7 01          	and    $0x1,%r15d
 11c1942:	49 83 f7 03          	xor    $0x3,%r15
 11c1946:	e9 41 01 00 00       	jmp    11c1a8c <br.encodeCommandPlanWithOptionsWrite+0x604c>
 11c194b:	41 bc 06 00 00 00    	mov    $0x6,%r12d
 11c1951:	80 7d cd 00          	cmpb   $0x0,-0x33(%rbp)
 11c1955:	75 26                	jne    11c197d <br.encodeCommandPlanWithOptionsWrite+0x5f3d>
 11c1957:	41 bc 05 00 00 00    	mov    $0x5,%r12d
 11c195d:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 11c1961:	75 1a                	jne    11c197d <br.encodeCommandPlanWithOptionsWrite+0x5f3d>
 11c1963:	41 bc 04 00 00 00    	mov    $0x4,%r12d
 11c1969:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 11c196d:	75 0e                	jne    11c197d <br.encodeCommandPlanWithOptionsWrite+0x5f3d>
 11c196f:	80 7d ca 01          	cmpb   $0x1,-0x36(%rbp)
 11c1973:	41 bc 03 00 00 00    	mov    $0x3,%r12d
 11c1979:	49 83 dc 00          	sbb    $0x0,%r12
 11c197d:	48 8d 9d 08 1e ff ff 	lea    -0xe1f8(%rbp),%rbx
 11c1984:	4c 8d b5 c0 eb fc ff 	lea    -0x31440(%rbp),%r14
 11c198b:	4c 8d bd e0 fc fe ff 	lea    -0x10320(%rbp),%r15
 11c1992:	eb 2d                	jmp    11c19c1 <br.encodeCommandPlanWithOptionsWrite+0x5f81>
 11c1994:	ba 40 08 00 00       	mov    $0x840,%edx
 11c1999:	4c 89 f7             	mov    %r14,%rdi
 11c199c:	31 f6                	xor    %esi,%esi
 11c199e:	e8 9d d9 11 00       	call   12df340 <compiler_rt.memset>
 11c19a3:	48 81 c3 c0 02 00 00 	add    $0x2c0,%rbx
 11c19aa:	49 81 c7 88 05 00 00 	add    $0x588,%r15
 11c19b1:	49 81 c6 40 08 00 00 	add    $0x840,%r14
 11c19b8:	49 ff cc             	dec    %r12
 11c19bb:	0f 84 e6 e0 ff ff    	je     11bfaa7 <br.encodeCommandPlanWithOptionsWrite+0x4067>
 11c19c1:	49 8b 4f f8          	mov    -0x8(%r15),%rcx
 11c19c5:	48 83 f9 05          	cmp    $0x5,%rcx
 11c19c9:	72 c9                	jb     11c1994 <br.encodeCommandPlanWithOptionsWrite+0x5f54>
 11c19cb:	48 83 f9 41          	cmp    $0x41,%rcx
 11c19cf:	73 3a                	jae    11c1a0b <br.encodeCommandPlanWithOptionsWrite+0x5fcb>
 11c19d1:	48 8d bd f4 53 ff ff 	lea    -0xac0c(%rbp),%rdi
 11c19d8:	48 89 de             	mov    %rbx,%rsi
 11c19db:	4c 89 fa             	mov    %r15,%rdx
 11c19de:	e8 4d 34 00 00       	call   11c4e30 <huffman.HuffmanTable(704).Encoder.initSparseTrusted>
 11c19e3:	0f b7 85 34 5c ff ff 	movzwl -0xa3cc(%rbp),%eax
 11c19ea:	66 85 c0             	test   %ax,%ax
 11c19ed:	0f 85 ba a0 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c19f3:	ba 40 08 00 00       	mov    $0x840,%edx
 11c19f8:	4c 8d ad 84 80 fe ff 	lea    -0x17f7c(%rbp),%r13
 11c19ff:	4c 89 ef             	mov    %r13,%rdi
 11c1a02:	48 8d b5 f4 53 ff ff 	lea    -0xac0c(%rbp),%rsi
 11c1a09:	eb 35                	jmp    11c1a40 <br.encodeCommandPlanWithOptionsWrite+0x6000>
 11c1a0b:	48 8d bd b2 4b ff ff 	lea    -0xb44e(%rbp),%rdi
 11c1a12:	48 89 de             	mov    %rbx,%rsi
 11c1a15:	e8 e6 30 00 00       	call   11c4b00 <huffman.HuffmanTable(704).Encoder.init>
 11c1a1a:	0f b7 85 f2 53 ff ff 	movzwl -0xac0e(%rbp),%eax
 11c1a21:	66 85 c0             	test   %ax,%ax
 11c1a24:	0f 85 83 a0 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c1a2a:	ba 40 08 00 00       	mov    $0x840,%edx
 11c1a2f:	4c 8d ad 44 78 fe ff 	lea    -0x187bc(%rbp),%r13
 11c1a36:	4c 89 ef             	mov    %r13,%rdi
 11c1a39:	48 8d b5 b2 4b ff ff 	lea    -0xb44e(%rbp),%rsi
 11c1a40:	e8 1b dd 11 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11c1a45:	4c 89 ee             	mov    %r13,%rsi
 11c1a48:	ba 40 08 00 00       	mov    $0x840,%edx
 11c1a4d:	4c 89 f7             	mov    %r14,%rdi
 11c1a50:	e8 0b dd 11 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11c1a55:	e9 49 ff ff ff       	jmp    11c19a3 <br.encodeCommandPlanWithOptionsWrite+0x5f63>
 11c1a5a:	41 bf 06 00 00 00    	mov    $0x6,%r15d
 11c1a60:	80 7d ce 00          	cmpb   $0x0,-0x32(%rbp)
 11c1a64:	75 26                	jne    11c1a8c <br.encodeCommandPlanWithOptionsWrite+0x604c>
 11c1a66:	41 bf 05 00 00 00    	mov    $0x5,%r15d
 11c1a6c:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 11c1a70:	75 1a                	jne    11c1a8c <br.encodeCommandPlanWithOptionsWrite+0x604c>
 11c1a72:	41 bf 04 00 00 00    	mov    $0x4,%r15d
 11c1a78:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 11c1a7c:	75 0e                	jne    11c1a8c <br.encodeCommandPlanWithOptionsWrite+0x604c>
 11c1a7e:	80 7d d5 01          	cmpb   $0x1,-0x2b(%rbp)
 11c1a82:	41 bf 03 00 00 00    	mov    $0x3,%r15d
 11c1a88:	49 83 df 00          	sbb    $0x0,%r15
 11c1a8c:	48 8d 9d da d1 ff ff 	lea    -0x2e26(%rbp),%rbx
 11c1a93:	4c 8d a5 1e 46 ff ff 	lea    -0xb9e2(%rbp),%r12
 11c1a9a:	4c 8d b5 30 cb ff ff 	lea    -0x34d0(%rbp),%r14
 11c1aa1:	4c 8d ad f0 e0 ff ff 	lea    -0x1f10(%rbp),%r13
 11c1aa8:	eb 62                	jmp    11c1b0c <br.encodeCommandPlanWithOptionsWrite+0x60cc>
 11c1aaa:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11c1aae:	c4 c1 7c 11 84 24 ce 	vmovups %ymm0,0xce(%r12)
 11c1ab5:	00 00 00 
 11c1ab8:	c4 c1 7c 11 84 24 c0 	vmovups %ymm0,0xc0(%r12)
 11c1abf:	00 00 00 
 11c1ac2:	c4 c1 7c 11 84 24 a0 	vmovups %ymm0,0xa0(%r12)
 11c1ac9:	00 00 00 
 11c1acc:	c4 c1 7c 11 84 24 80 	vmovups %ymm0,0x80(%r12)
 11c1ad3:	00 00 00 
 11c1ad6:	c4 c1 7c 11 44 24 60 	vmovups %ymm0,0x60(%r12)
 11c1add:	c4 c1 7c 11 44 24 40 	vmovups %ymm0,0x40(%r12)
 11c1ae4:	c4 c1 7c 11 44 24 20 	vmovups %ymm0,0x20(%r12)
 11c1aeb:	c4 c1 7c 11 04 24    	vmovups %ymm0,(%r12)
 11c1af1:	48 83 c3 4f          	add    $0x4f,%rbx
 11c1af5:	49 81 c6 a8 00 00 00 	add    $0xa8,%r14
 11c1afc:	49 81 c4 ee 00 00 00 	add    $0xee,%r12
 11c1b03:	49 ff cf             	dec    %r15
 11c1b06:	0f 84 f0 e0 ff ff    	je     11bfbfc <br.encodeCommandPlanWithOptionsWrite+0x41bc>
 11c1b0c:	49 8b 4e f8          	mov    -0x8(%r14),%rcx
 11c1b10:	48 83 f9 05          	cmp    $0x5,%rcx
 11c1b14:	72 94                	jb     11c1aaa <br.encodeCommandPlanWithOptionsWrite+0x606a>
 11c1b16:	48 83 f9 41          	cmp    $0x41,%rcx
 11c1b1a:	0f 83 ad 00 00 00    	jae    11c1bcd <br.encodeCommandPlanWithOptionsWrite+0x618d>
 11c1b20:	4c 89 ef             	mov    %r13,%rdi
 11c1b23:	48 89 de             	mov    %rbx,%rsi
 11c1b26:	4c 89 f2             	mov    %r14,%rdx
 11c1b29:	c5 f8 77             	vzeroupper 
 11c1b2c:	e8 cf 2a 00 00       	call   11c4600 <huffman.HuffmanTable(79).Encoder.initSparseTrusted>
 11c1b31:	0f b7 85 de e1 ff ff 	movzwl -0x1e22(%rbp),%eax
 11c1b38:	66 85 c0             	test   %ax,%ax
 11c1b3b:	0f 85 6c 9f ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c1b41:	c5 fc 10 85 be e1 ff 	vmovups -0x1e42(%rbp),%ymm0
 11c1b48:	ff 
 11c1b49:	c5 fc 11 85 de da ff 	vmovups %ymm0,-0x2522(%rbp)
 11c1b50:	ff 
 11c1b51:	c5 fc 10 85 b0 e1 ff 	vmovups -0x1e50(%rbp),%ymm0
 11c1b58:	ff 
 11c1b59:	c5 fc 11 85 d0 da ff 	vmovups %ymm0,-0x2530(%rbp)
 11c1b60:	ff 
 11c1b61:	c5 fc 10 85 90 e1 ff 	vmovups -0x1e70(%rbp),%ymm0
 11c1b68:	ff 
 11c1b69:	c5 fc 11 85 b0 da ff 	vmovups %ymm0,-0x2550(%rbp)
 11c1b70:	ff 
 11c1b71:	c5 fc 10 85 70 e1 ff 	vmovups -0x1e90(%rbp),%ymm0
 11c1b78:	ff 
 11c1b79:	c5 fc 11 85 90 da ff 	vmovups %ymm0,-0x2570(%rbp)
 11c1b80:	ff 
 11c1b81:	c5 fc 10 85 f0 e0 ff 	vmovups -0x1f10(%rbp),%ymm0
 11c1b88:	ff 
 11c1b89:	c5 fc 10 8d 10 e1 ff 	vmovups -0x1ef0(%rbp),%ymm1
 11c1b90:	ff 
 11c1b91:	c5 fc 10 95 30 e1 ff 	vmovups -0x1ed0(%rbp),%ymm2
 11c1b98:	ff 
 11c1b99:	c5 fc 10 9d 50 e1 ff 	vmovups -0x1eb0(%rbp),%ymm3
 11c1ba0:	ff 
 11c1ba1:	c5 fc 11 9d 70 da ff 	vmovups %ymm3,-0x2590(%rbp)
 11c1ba8:	ff 
 11c1ba9:	c5 fc 11 95 50 da ff 	vmovups %ymm2,-0x25b0(%rbp)
 11c1bb0:	ff 
 11c1bb1:	c5 fc 11 8d 30 da ff 	vmovups %ymm1,-0x25d0(%rbp)
 11c1bb8:	ff 
 11c1bb9:	c5 fc 11 85 10 da ff 	vmovups %ymm0,-0x25f0(%rbp)
 11c1bc0:	ff 
 11c1bc1:	48 8d 85 10 da ff ff 	lea    -0x25f0(%rbp),%rax
 11c1bc8:	e9 a9 00 00 00       	jmp    11c1c76 <br.encodeCommandPlanWithOptionsWrite+0x6236>
 11c1bcd:	48 8d bd 00 e0 ff ff 	lea    -0x2000(%rbp),%rdi
 11c1bd4:	48 89 de             	mov    %rbx,%rsi
 11c1bd7:	c5 f8 77             	vzeroupper 
 11c1bda:	e8 01 26 00 00       	call   11c41e0 <huffman.HuffmanTable(79).Encoder.init>
 11c1bdf:	0f b7 85 ee e0 ff ff 	movzwl -0x1f12(%rbp),%eax
 11c1be6:	66 85 c0             	test   %ax,%ax
 11c1be9:	0f 85 be 9e ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c1bef:	c5 fc 10 85 ce e0 ff 	vmovups -0x1f32(%rbp),%ymm0
 11c1bf6:	ff 
 11c1bf7:	c5 fc 11 85 ee d9 ff 	vmovups %ymm0,-0x2612(%rbp)
 11c1bfe:	ff 
 11c1bff:	c5 fc 10 85 c0 e0 ff 	vmovups -0x1f40(%rbp),%ymm0
 11c1c06:	ff 
 11c1c07:	c5 fc 11 85 e0 d9 ff 	vmovups %ymm0,-0x2620(%rbp)
 11c1c0e:	ff 
 11c1c0f:	c5 fc 10 85 a0 e0 ff 	vmovups -0x1f60(%rbp),%ymm0
 11c1c16:	ff 
 11c1c17:	c5 fc 11 85 c0 d9 ff 	vmovups %ymm0,-0x2640(%rbp)
 11c1c1e:	ff 
 11c1c1f:	c5 fc 10 85 80 e0 ff 	vmovups -0x1f80(%rbp),%ymm0
 11c1c26:	ff 
 11c1c27:	c5 fc 11 85 a0 d9 ff 	vmovups %ymm0,-0x2660(%rbp)
 11c1c2e:	ff 
 11c1c2f:	c5 fc 10 85 00 e0 ff 	vmovups -0x2000(%rbp),%ymm0
 11c1c36:	ff 
 11c1c37:	c5 fc 10 8d 20 e0 ff 	vmovups -0x1fe0(%rbp),%ymm1
 11c1c3e:	ff 
 11c1c3f:	c5 fc 10 95 40 e0 ff 	vmovups -0x1fc0(%rbp),%ymm2
 11c1c46:	ff 
 11c1c47:	c5 fc 10 9d 60 e0 ff 	vmovups -0x1fa0(%rbp),%ymm3
 11c1c4e:	ff 
 11c1c4f:	c5 fc 11 9d 80 d9 ff 	vmovups %ymm3,-0x2680(%rbp)
 11c1c56:	ff 
 11c1c57:	c5 fc 11 95 60 d9 ff 	vmovups %ymm2,-0x26a0(%rbp)
 11c1c5e:	ff 
 11c1c5f:	c5 fc 11 8d 40 d9 ff 	vmovups %ymm1,-0x26c0(%rbp)
 11c1c66:	ff 
 11c1c67:	c5 fc 11 85 20 d9 ff 	vmovups %ymm0,-0x26e0(%rbp)
 11c1c6e:	ff 
 11c1c6f:	48 8d 85 20 d9 ff ff 	lea    -0x26e0(%rbp),%rax
 11c1c76:	c5 fc 10 80 ce 00 00 	vmovups 0xce(%rax),%ymm0
 11c1c7d:	00 
 11c1c7e:	c4 c1 7c 11 84 24 ce 	vmovups %ymm0,0xce(%r12)
 11c1c85:	00 00 00 
 11c1c88:	c5 fc 10 80 c0 00 00 	vmovups 0xc0(%rax),%ymm0
 11c1c8f:	00 
 11c1c90:	c4 c1 7c 11 84 24 c0 	vmovups %ymm0,0xc0(%r12)
 11c1c97:	00 00 00 
 11c1c9a:	c5 fc 10 80 a0 00 00 	vmovups 0xa0(%rax),%ymm0
 11c1ca1:	00 
 11c1ca2:	c4 c1 7c 11 84 24 a0 	vmovups %ymm0,0xa0(%r12)
 11c1ca9:	00 00 00 
 11c1cac:	c5 fc 10 80 80 00 00 	vmovups 0x80(%rax),%ymm0
 11c1cb3:	00 
 11c1cb4:	c4 c1 7c 11 84 24 80 	vmovups %ymm0,0x80(%r12)
 11c1cbb:	00 00 00 
 11c1cbe:	c5 fc 10 00          	vmovups (%rax),%ymm0
 11c1cc2:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 11c1cc7:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 11c1ccc:	c5 fc 10 58 60       	vmovups 0x60(%rax),%ymm3
 11c1cd1:	c4 c1 7c 11 5c 24 60 	vmovups %ymm3,0x60(%r12)
 11c1cd8:	c4 c1 7c 11 54 24 40 	vmovups %ymm2,0x40(%r12)
 11c1cdf:	c4 c1 7c 11 4c 24 20 	vmovups %ymm1,0x20(%r12)
 11c1ce6:	e9 00 fe ff ff       	jmp    11c1aeb <br.encodeCommandPlanWithOptionsWrite+0x60ab>
 11c1ceb:	80 7d c6 00          	cmpb   $0x0,-0x3a(%rbp)
 11c1cef:	74 38                	je     11c1d29 <br.encodeCommandPlanWithOptionsWrite+0x62e9>
 11c1cf1:	48 8d 85 d8 e4 fe ff 	lea    -0x11b28(%rbp),%rax
 11c1cf8:	48 89 85 10 fc ff ff 	mov    %rax,-0x3f0(%rbp)
 11c1cff:	48 8d 85 58 8c ff ff 	lea    -0x73a8(%rbp),%rax
 11c1d06:	48 89 85 18 fc ff ff 	mov    %rax,-0x3e8(%rbp)
 11c1d0d:	4c 8d 85 bc ab ff ff 	lea    -0x5444(%rbp),%r8
 11c1d14:	80 7d c0 00          	cmpb   $0x0,-0x40(%rbp)
 11c1d18:	74 2c                	je     11c1d46 <br.encodeCommandPlanWithOptionsWrite+0x6306>
 11c1d1a:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 11c1d21:	48 89 c1             	mov    %rax,%rcx
 11c1d24:	e9 0d 01 00 00       	jmp    11c1e36 <br.encodeCommandPlanWithOptionsWrite+0x63f6>
 11c1d29:	4c 8d 85 f0 e5 ff ff 	lea    -0x1a10(%rbp),%r8
 11c1d30:	b8 01 00 00 00       	mov    $0x1,%eax
 11c1d35:	48 89 85 38 ff ff ff 	mov    %rax,-0xc8(%rbp)
 11c1d3c:	b9 01 00 00 00       	mov    $0x1,%ecx
 11c1d41:	e9 f0 00 00 00       	jmp    11c1e36 <br.encodeCommandPlanWithOptionsWrite+0x63f6>
 11c1d46:	0f b6 45 cc          	movzbl -0x34(%rbp),%eax
 11c1d4a:	89 c2                	mov    %eax,%edx
 11c1d4c:	0a 55 c2             	or     -0x3e(%rbp),%dl
 11c1d4f:	0f b6 c0             	movzbl %al,%eax
 11c1d52:	f6 c2 01             	test   $0x1,%dl
 11c1d55:	0f 84 82 00 00 00    	je     11c1ddd <br.encodeCommandPlanWithOptionsWrite+0x639d>
 11c1d5b:	89 c1                	mov    %eax,%ecx
 11c1d5d:	83 e1 01             	and    $0x1,%ecx
 11c1d60:	48 83 f1 03          	xor    $0x3,%rcx
 11c1d64:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 11c1d68:	40 0f 95 c6          	setne  %sil
 11c1d6c:	80 7d c7 00          	cmpb   $0x0,-0x39(%rbp)
 11c1d70:	40 0f 95 c7          	setne  %dil
 11c1d74:	40 08 d7             	or     %dl,%dil
 11c1d77:	44 0f b6 4d c2       	movzbl -0x3e(%rbp),%r9d
 11c1d7c:	41 f6 d1             	not    %r9b
 11c1d7f:	45 0f b6 c9          	movzbl %r9b,%r9d
 11c1d83:	41 83 e1 01          	and    $0x1,%r9d
 11c1d87:	4f 8d 0c 49          	lea    (%r9,%r9,2),%r9
 11c1d8b:	49 83 c1 03          	add    $0x3,%r9
 11c1d8f:	f6 45 cc 01          	testb  $0x1,-0x34(%rbp)
 11c1d93:	41 ba 02 00 00 00    	mov    $0x2,%r10d
 11c1d99:	4d 0f 44 d1          	cmove  %r9,%r10
 11c1d9d:	40 08 fe             	or     %dil,%sil
 11c1da0:	40 f6 c7 01          	test   $0x1,%dil
 11c1da4:	bf 05 00 00 00       	mov    $0x5,%edi
 11c1da9:	49 0f 45 fa          	cmovne %r10,%rdi
 11c1dad:	48 89 bd 38 ff ff ff 	mov    %rdi,-0xc8(%rbp)
 11c1db4:	40 f6 c6 01          	test   $0x1,%sil
 11c1db8:	75 3e                	jne    11c1df8 <br.encodeCommandPlanWithOptionsWrite+0x63b8>
 11c1dba:	80 7d c5 01          	cmpb   $0x1,-0x3b(%rbp)
 11c1dbe:	be 03 00 00 00       	mov    $0x3,%esi
 11c1dc3:	48 83 de 00          	sbb    $0x0,%rsi
 11c1dc7:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 11c1dcb:	bf 04 00 00 00       	mov    $0x4,%edi
 11c1dd0:	48 0f 44 fe          	cmove  %rsi,%rdi
 11c1dd4:	48 89 bd 38 ff ff ff 	mov    %rdi,-0xc8(%rbp)
 11c1ddb:	eb 1b                	jmp    11c1df8 <br.encodeCommandPlanWithOptionsWrite+0x63b8>
 11c1ddd:	b9 06 00 00 00       	mov    $0x6,%ecx
 11c1de2:	be 06 00 00 00       	mov    $0x6,%esi
 11c1de7:	48 89 b5 38 ff ff ff 	mov    %rsi,-0xc8(%rbp)
 11c1dee:	80 7d c7 00          	cmpb   $0x0,-0x39(%rbp)
 11c1df2:	0f 84 42 05 00 00    	je     11c233a <br.encodeCommandPlanWithOptionsWrite+0x68fa>
 11c1df8:	f6 c2 01             	test   $0x1,%dl
 11c1dfb:	74 09                	je     11c1e06 <br.encodeCommandPlanWithOptionsWrite+0x63c6>
 11c1dfd:	83 e0 01             	and    $0x1,%eax
 11c1e00:	48 83 f0 03          	xor    $0x3,%rax
 11c1e04:	eb 30                	jmp    11c1e36 <br.encodeCommandPlanWithOptionsWrite+0x63f6>
 11c1e06:	b8 06 00 00 00       	mov    $0x6,%eax
 11c1e0b:	80 7d c7 00          	cmpb   $0x0,-0x39(%rbp)
 11c1e0f:	75 25                	jne    11c1e36 <br.encodeCommandPlanWithOptionsWrite+0x63f6>
 11c1e11:	b8 05 00 00 00       	mov    $0x5,%eax
 11c1e16:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 11c1e1a:	75 1a                	jne    11c1e36 <br.encodeCommandPlanWithOptionsWrite+0x63f6>
 11c1e1c:	80 7d c5 01          	cmpb   $0x1,-0x3b(%rbp)
 11c1e20:	ba 03 00 00 00       	mov    $0x3,%edx
 11c1e25:	48 83 da 00          	sbb    $0x0,%rdx
 11c1e29:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 11c1e2d:	b8 04 00 00 00       	mov    $0x4,%eax
 11c1e32:	48 0f 44 c2          	cmove  %rdx,%rax
 11c1e36:	48 8b 95 f0 fd ff ff 	mov    -0x210(%rbp),%rdx
 11c1e3d:	48 8d 5a 10          	lea    0x10(%rdx),%rbx
 11c1e41:	4c 8d b2 90 13 01 00 	lea    0x11390(%rdx),%r14
 11c1e48:	48 89 df             	mov    %rbx,%rdi
 11c1e4b:	4c 89 f6             	mov    %r14,%rsi
 11c1e4e:	48 8b 95 18 fc ff ff 	mov    -0x3e8(%rbp),%rdx
 11c1e55:	4c 8b 8d 38 ff ff ff 	mov    -0xc8(%rbp),%r9
 11c1e5c:	50                   	push   %rax
 11c1e5d:	ff b5 10 fc ff ff    	push   -0x3f0(%rbp)
 11c1e63:	c5 f8 77             	vzeroupper 
 11c1e66:	e8 35 13 00 00       	call   11c31a0 <br.encoder.hq_codec.huffman_model.tables__anon_32179>
 11c1e6b:	48 83 c4 10          	add    $0x10,%rsp
 11c1e6f:	66 85 c0             	test   %ax,%ax
 11c1e72:	0f 85 35 9c ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c1e78:	48 8b 85 f0 fd ff ff 	mov    -0x210(%rbp),%rax
 11c1e7f:	4c 8d b8 90 1f 01 00 	lea    0x11f90(%rax),%r15
 11c1e86:	49 c7 c4 00 04 ff ff 	mov    $0xffffffffffff0400,%r12
 11c1e8d:	4b 8d 3c 27          	lea    (%r15,%r12,1),%rdi
 11c1e91:	48 81 c7 80 e0 ff ff 	add    $0xffffffffffffe080,%rdi
 11c1e98:	ba 00 04 00 00       	mov    $0x400,%edx
 11c1e9d:	48 89 de             	mov    %rbx,%rsi
 11c1ea0:	e8 bb d8 11 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11c1ea5:	4b 8d 3c 27          	lea    (%r15,%r12,1),%rdi
 11c1ea9:	48 81 c7 00 f4 00 00 	add    $0xf400,%rdi
 11c1eb0:	ba 00 04 00 00       	mov    $0x400,%edx
 11c1eb5:	4c 89 f6             	mov    %r14,%rsi
 11c1eb8:	e8 a3 d8 11 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11c1ebd:	4b 8d 3c 27          	lea    (%r15,%r12,1),%rdi
 11c1ec1:	48 81 c7 80 e4 ff ff 	add    $0xffffffffffffe480,%rdi
 11c1ec8:	ba 00 04 00 00       	mov    $0x400,%edx
 11c1ecd:	48 89 de             	mov    %rbx,%rsi
 11c1ed0:	e8 8b d8 11 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11c1ed5:	4b 8d 3c 27          	lea    (%r15,%r12,1),%rdi
 11c1ed9:	48 81 c7 00 f8 00 00 	add    $0xf800,%rdi
 11c1ee0:	ba 00 04 00 00       	mov    $0x400,%edx
 11c1ee5:	4c 89 f6             	mov    %r14,%rsi
 11c1ee8:	e8 73 d8 11 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11c1eed:	4b 8d 3c 27          	lea    (%r15,%r12,1),%rdi
 11c1ef1:	48 81 c7 80 e8 ff ff 	add    $0xffffffffffffe880,%rdi
 11c1ef8:	ba 00 04 00 00       	mov    $0x400,%edx
 11c1efd:	48 89 de             	mov    %rbx,%rsi
 11c1f00:	e8 5b d8 11 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11c1f05:	4b 8d 3c 27          	lea    (%r15,%r12,1),%rdi
 11c1f09:	48 81 c7 00 fc 00 00 	add    $0xfc00,%rdi
 11c1f10:	ba 00 04 00 00       	mov    $0x400,%edx
 11c1f15:	4c 89 f6             	mov    %r14,%rsi
 11c1f18:	e8 43 d8 11 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11c1f1d:	49 81 c4 00 0c 00 00 	add    $0xc00,%r12
 11c1f24:	0f 85 63 ff ff ff    	jne    11c1e8d <br.encodeCommandPlanWithOptionsWrite+0x644d>
 11c1f2a:	80 7d c3 00          	cmpb   $0x0,-0x3d(%rbp)
 11c1f2e:	74 2a                	je     11c1f5a <br.encodeCommandPlanWithOptionsWrite+0x651a>
 11c1f30:	48 8d 85 c4 01 fe ff 	lea    -0x1fe3c(%rbp),%rax
 11c1f37:	48 89 85 08 fc ff ff 	mov    %rax,-0x3f8(%rbp)
 11c1f3e:	48 8d 95 d8 fc fe ff 	lea    -0x10328(%rbp),%rdx
 11c1f45:	80 7d c1 00          	cmpb   $0x0,-0x3f(%rbp)
 11c1f49:	74 3a                	je     11c1f85 <br.encodeCommandPlanWithOptionsWrite+0x6545>
 11c1f4b:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 11c1f52:	48 89 c1             	mov    %rax,%rcx
 11c1f55:	e9 20 01 00 00       	jmp    11c207a <br.encodeCommandPlanWithOptionsWrite+0x663a>
 11c1f5a:	48 8d 95 a0 c5 ff ff 	lea    -0x3a60(%rbp),%rdx
 11c1f61:	48 8d 85 1a cf ff ff 	lea    -0x30e6(%rbp),%rax
 11c1f68:	48 89 85 00 fe ff ff 	mov    %rax,-0x200(%rbp)
 11c1f6f:	b8 01 00 00 00       	mov    $0x1,%eax
 11c1f74:	48 89 85 70 ff ff ff 	mov    %rax,-0x90(%rbp)
 11c1f7b:	b9 01 00 00 00       	mov    $0x1,%ecx
 11c1f80:	e9 f5 00 00 00       	jmp    11c207a <br.encodeCommandPlanWithOptionsWrite+0x663a>
 11c1f85:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 11c1f89:	89 c6                	mov    %eax,%esi
 11c1f8b:	40 0a 75 c8          	or     -0x38(%rbp),%sil
 11c1f8f:	0f b6 c0             	movzbl %al,%eax
 11c1f92:	40 f6 c6 01          	test   $0x1,%sil
 11c1f96:	0f 84 84 00 00 00    	je     11c2020 <br.encodeCommandPlanWithOptionsWrite+0x65e0>
 11c1f9c:	89 c1                	mov    %eax,%ecx
 11c1f9e:	83 e1 01             	and    $0x1,%ecx
 11c1fa1:	48 83 f1 03          	xor    $0x3,%rcx
 11c1fa5:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 11c1fa9:	40 0f 95 c7          	setne  %dil
 11c1fad:	80 7d cd 00          	cmpb   $0x0,-0x33(%rbp)
 11c1fb1:	41 0f 95 c0          	setne  %r8b
 11c1fb5:	41 08 f0             	or     %sil,%r8b
 11c1fb8:	44 0f b6 4d c8       	movzbl -0x38(%rbp),%r9d
 11c1fbd:	41 f6 d1             	not    %r9b
 11c1fc0:	45 0f b6 c9          	movzbl %r9b,%r9d
 11c1fc4:	41 83 e1 01          	and    $0x1,%r9d
 11c1fc8:	4f 8d 0c 49          	lea    (%r9,%r9,2),%r9
 11c1fcc:	49 83 c1 03          	add    $0x3,%r9
 11c1fd0:	f6 45 d2 01          	testb  $0x1,-0x2e(%rbp)
 11c1fd4:	41 ba 02 00 00 00    	mov    $0x2,%r10d
 11c1fda:	4d 0f 44 d1          	cmove  %r9,%r10
 11c1fde:	44 08 c7             	or     %r8b,%dil
 11c1fe1:	41 f6 c0 01          	test   $0x1,%r8b
 11c1fe5:	41 b8 05 00 00 00    	mov    $0x5,%r8d
 11c1feb:	4d 0f 45 c2          	cmovne %r10,%r8
 11c1fef:	4c 89 85 70 ff ff ff 	mov    %r8,-0x90(%rbp)
 11c1ff6:	40 f6 c7 01          	test   $0x1,%dil
 11c1ffa:	75 3f                	jne    11c203b <br.encodeCommandPlanWithOptionsWrite+0x65fb>
 11c1ffc:	80 7d ca 01          	cmpb   $0x1,-0x36(%rbp)
 11c2000:	bf 03 00 00 00       	mov    $0x3,%edi
 11c2005:	48 83 df 00          	sbb    $0x0,%rdi
 11c2009:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 11c200d:	41 b8 04 00 00 00    	mov    $0x4,%r8d
 11c2013:	4c 0f 44 c7          	cmove  %rdi,%r8
 11c2017:	4c 89 85 70 ff ff ff 	mov    %r8,-0x90(%rbp)
 11c201e:	eb 1b                	jmp    11c203b <br.encodeCommandPlanWithOptionsWrite+0x65fb>
 11c2020:	b9 06 00 00 00       	mov    $0x6,%ecx
 11c2025:	bf 06 00 00 00       	mov    $0x6,%edi
 11c202a:	48 89 bd 70 ff ff ff 	mov    %rdi,-0x90(%rbp)
 11c2031:	80 7d cd 00          	cmpb   $0x0,-0x33(%rbp)
 11c2035:	0f 84 a1 02 00 00    	je     11c22dc <br.encodeCommandPlanWithOptionsWrite+0x689c>
 11c203b:	40 f6 c6 01          	test   $0x1,%sil
 11c203f:	74 09                	je     11c204a <br.encodeCommandPlanWithOptionsWrite+0x660a>
 11c2041:	83 e0 01             	and    $0x1,%eax
 11c2044:	48 83 f0 03          	xor    $0x3,%rax
 11c2048:	eb 30                	jmp    11c207a <br.encodeCommandPlanWithOptionsWrite+0x663a>
 11c204a:	b8 06 00 00 00       	mov    $0x6,%eax
 11c204f:	80 7d cd 00          	cmpb   $0x0,-0x33(%rbp)
 11c2053:	75 25                	jne    11c207a <br.encodeCommandPlanWithOptionsWrite+0x663a>
 11c2055:	b8 05 00 00 00       	mov    $0x5,%eax
 11c205a:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 11c205e:	75 1a                	jne    11c207a <br.encodeCommandPlanWithOptionsWrite+0x663a>
 11c2060:	80 7d ca 01          	cmpb   $0x1,-0x36(%rbp)
 11c2064:	be 03 00 00 00       	mov    $0x3,%esi
 11c2069:	48 83 de 00          	sbb    $0x0,%rsi
 11c206d:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 11c2071:	b8 04 00 00 00       	mov    $0x4,%eax
 11c2076:	48 0f 44 c6          	cmove  %rsi,%rax
 11c207a:	48 8b b5 f0 fd ff ff 	mov    -0x210(%rbp),%rsi
 11c2081:	48 8d be 10 00 01 00 	lea    0x10010(%rsi),%rdi
 11c2088:	48 81 c6 90 13 02 00 	add    $0x21390,%rsi
 11c208f:	4c 8b 85 00 fe ff ff 	mov    -0x200(%rbp),%r8
 11c2096:	4c 8b 8d 70 ff ff ff 	mov    -0x90(%rbp),%r9
 11c209d:	50                   	push   %rax
 11c209e:	ff b5 08 fc ff ff    	push   -0x3f8(%rbp)
 11c20a4:	e8 37 0b 00 00       	call   11c2be0 <br.encoder.hq_codec.huffman_model.tables__anon_32189>
 11c20a9:	48 83 c4 10          	add    $0x10,%rsp
 11c20ad:	66 85 c0             	test   %ax,%ax
 11c20b0:	0f 85 f7 99 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c20b6:	80 7d cb 00          	cmpb   $0x0,-0x35(%rbp)
 11c20ba:	74 2a                	je     11c20e6 <br.encodeCommandPlanWithOptionsWrite+0x66a6>
 11c20bc:	4c 8d ad 90 9e ff ff 	lea    -0x6170(%rbp),%r13
 11c20c3:	48 8d 85 28 cb ff ff 	lea    -0x34d8(%rbp),%rax
 11c20ca:	48 89 85 58 fe ff ff 	mov    %rax,-0x1a8(%rbp)
 11c20d1:	80 7d c4 00          	cmpb   $0x0,-0x3c(%rbp)
 11c20d5:	74 4f                	je     11c2126 <br.encodeCommandPlanWithOptionsWrite+0x66e6>
 11c20d7:	4c 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%r14
 11c20de:	4d 89 f4             	mov    %r14,%r12
 11c20e1:	e9 29 01 00 00       	jmp    11c220f <br.encodeCommandPlanWithOptionsWrite+0x67cf>
 11c20e6:	4c 8d ad 10 eb ff ff 	lea    -0x14f0(%rbp),%r13
 11c20ed:	48 8d 85 00 f0 ff ff 	lea    -0x1000(%rbp),%rax
 11c20f4:	48 89 85 58 fe ff ff 	mov    %rax,-0x1a8(%rbp)
 11c20fb:	48 8d 85 00 f2 ff ff 	lea    -0xe00(%rbp),%rax
 11c2102:	48 89 85 10 ff ff ff 	mov    %rax,-0xf0(%rbp)
 11c2109:	b8 01 00 00 00       	mov    $0x1,%eax
 11c210e:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 11c2115:	41 bc 01 00 00 00    	mov    $0x1,%r12d
 11c211b:	41 be 01 00 00 00    	mov    $0x1,%r14d
 11c2121:	e9 e9 00 00 00       	jmp    11c220f <br.encodeCommandPlanWithOptionsWrite+0x67cf>
 11c2126:	0f b6 4d d3          	movzbl -0x2d(%rbp),%ecx
 11c212a:	89 c8                	mov    %ecx,%eax
 11c212c:	0a 45 c9             	or     -0x37(%rbp),%al
 11c212f:	44 0f b6 f1          	movzbl %cl,%r14d
 11c2133:	a8 01                	test   $0x1,%al
 11c2135:	74 7b                	je     11c21b2 <br.encodeCommandPlanWithOptionsWrite+0x6772>
 11c2137:	45 89 f4             	mov    %r14d,%r12d
 11c213a:	41 83 e4 01          	and    $0x1,%r12d
 11c213e:	49 83 f4 03          	xor    $0x3,%r12
 11c2142:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 11c2146:	0f 95 c1             	setne  %cl
 11c2149:	80 7d ce 00          	cmpb   $0x0,-0x32(%rbp)
 11c214d:	0f 95 c2             	setne  %dl
 11c2150:	08 c2                	or     %al,%dl
 11c2152:	0f b6 75 c9          	movzbl -0x37(%rbp),%esi
 11c2156:	40 f6 d6             	not    %sil
 11c2159:	40 0f b6 f6          	movzbl %sil,%esi
 11c215d:	83 e6 01             	and    $0x1,%esi
 11c2160:	48 8d 34 76          	lea    (%rsi,%rsi,2),%rsi
 11c2164:	48 83 c6 03          	add    $0x3,%rsi
 11c2168:	f6 45 d3 01          	testb  $0x1,-0x2d(%rbp)
 11c216c:	bf 02 00 00 00       	mov    $0x2,%edi
 11c2171:	48 0f 44 fe          	cmove  %rsi,%rdi
 11c2175:	08 d1                	or     %dl,%cl
 11c2177:	f6 c2 01             	test   $0x1,%dl
 11c217a:	ba 05 00 00 00       	mov    $0x5,%edx
 11c217f:	48 0f 45 d7          	cmovne %rdi,%rdx
 11c2183:	48 89 95 78 ff ff ff 	mov    %rdx,-0x88(%rbp)
 11c218a:	f6 c1 01             	test   $0x1,%cl
 11c218d:	75 3f                	jne    11c21ce <br.encodeCommandPlanWithOptionsWrite+0x678e>
 11c218f:	80 7d d5 01          	cmpb   $0x1,-0x2b(%rbp)
 11c2193:	b9 03 00 00 00       	mov    $0x3,%ecx
 11c2198:	48 83 d9 00          	sbb    $0x0,%rcx
 11c219c:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 11c21a0:	ba 04 00 00 00       	mov    $0x4,%edx
 11c21a5:	48 0f 44 d1          	cmove  %rcx,%rdx
 11c21a9:	48 89 95 78 ff ff ff 	mov    %rdx,-0x88(%rbp)
 11c21b0:	eb 1c                	jmp    11c21ce <br.encodeCommandPlanWithOptionsWrite+0x678e>
 11c21b2:	41 bc 06 00 00 00    	mov    $0x6,%r12d
 11c21b8:	b9 06 00 00 00       	mov    $0x6,%ecx
 11c21bd:	48 89 8d 78 ff ff ff 	mov    %rcx,-0x88(%rbp)
 11c21c4:	80 7d ce 00          	cmpb   $0x0,-0x32(%rbp)
 11c21c8:	0f 84 3c 01 00 00    	je     11c230a <br.encodeCommandPlanWithOptionsWrite+0x68ca>
 11c21ce:	a8 01                	test   $0x1,%al
 11c21d0:	74 0a                	je     11c21dc <br.encodeCommandPlanWithOptionsWrite+0x679c>
 11c21d2:	41 83 e6 01          	and    $0x1,%r14d
 11c21d6:	49 83 f6 03          	xor    $0x3,%r14
 11c21da:	eb 33                	jmp    11c220f <br.encodeCommandPlanWithOptionsWrite+0x67cf>
 11c21dc:	41 be 06 00 00 00    	mov    $0x6,%r14d
 11c21e2:	80 7d ce 00          	cmpb   $0x0,-0x32(%rbp)
 11c21e6:	75 27                	jne    11c220f <br.encodeCommandPlanWithOptionsWrite+0x67cf>
 11c21e8:	41 be 05 00 00 00    	mov    $0x5,%r14d
 11c21ee:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 11c21f2:	75 1b                	jne    11c220f <br.encodeCommandPlanWithOptionsWrite+0x67cf>
 11c21f4:	80 7d d5 01          	cmpb   $0x1,-0x2b(%rbp)
 11c21f8:	b8 03 00 00 00       	mov    $0x3,%eax
 11c21fd:	48 83 d8 00          	sbb    $0x0,%rax
 11c2201:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 11c2205:	41 be 04 00 00 00    	mov    $0x4,%r14d
 11c220b:	4c 0f 44 f0          	cmove  %rax,%r14
 11c220f:	48 8b 9d f0 fd ff ff 	mov    -0x210(%rbp),%rbx
 11c2216:	4c 8d bb 10 0b 01 00 	lea    0x10b10(%rbx),%r15
 11c221d:	be 4c 61 05 01       	mov    $0x105614c,%esi
 11c2222:	ba 80 08 00 00       	mov    $0x880,%edx
 11c2227:	4c 89 ff             	mov    %r15,%rdi
 11c222a:	e8 31 d5 11 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 11c222f:	48 81 c3 90 1e 02 00 	add    $0x21e90,%rbx
 11c2236:	ba 80 08 00 00       	mov    $0x880,%edx
 11c223b:	48 89 df             	mov    %rbx,%rdi
 11c223e:	31 f6                	xor    %esi,%esi
 11c2240:	e8 fb d0 11 00       	call   12df340 <compiler_rt.memset>
 11c2245:	4c 89 ff             	mov    %r15,%rdi
 11c2248:	48 89 de             	mov    %rbx,%rsi
 11c224b:	48 8b 95 58 fe ff ff 	mov    -0x1a8(%rbp),%rdx
 11c2252:	4c 89 e1             	mov    %r12,%rcx
 11c2255:	4c 8b 85 10 ff ff ff 	mov    -0xf0(%rbp),%r8
 11c225c:	4c 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%r9
 11c2263:	41 56                	push   %r14
 11c2265:	41 55                	push   %r13
 11c2267:	e8 14 03 00 00       	call   11c2580 <br.encoder.hq_codec.huffman_model.tables__anon_32204>
 11c226c:	48 83 c4 10          	add    $0x10,%rsp
 11c2270:	66 85 c0             	test   %ax,%ax
 11c2273:	0f 85 34 98 ff ff    	jne    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c2279:	48 83 bd e0 fc ff ff 	cmpq   $0x0,-0x320(%rbp)
 11c2280:	00 
 11c2281:	74 3a                	je     11c22bd <br.encodeCommandPlanWithOptionsWrite+0x687d>
 11c2283:	c5 fc 10 85 20 fd ff 	vmovups -0x2e0(%rbp),%ymm0
 11c228a:	ff 
 11c228b:	48 8b 85 e0 fc ff ff 	mov    -0x320(%rbp),%rax
 11c2292:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 11c2296:	0f b6 85 53 ff ff ff 	movzbl -0xad(%rbp),%eax
 11c229d:	88 85 20 fc ff ff    	mov    %al,-0x3e0(%rbp)
 11c22a3:	84 c0                	test   %al,%al
 11c22a5:	0f 85 fe 97 ff ff    	jne    11bbaa9 <br.encodeCommandPlanWithOptionsWrite+0x69>
 11c22ab:	48 8b 85 48 fa ff ff 	mov    -0x5b8(%rbp),%rax
 11c22b2:	48 8b 8d e0 fc ff ff 	mov    -0x320(%rbp),%rcx
 11c22b9:	48 89 41 20          	mov    %rax,0x20(%rcx)
 11c22bd:	80 7d 9b 00          	cmpb   $0x0,-0x65(%rbp)
 11c22c1:	74 12                	je     11c22d5 <br.encodeCommandPlanWithOptionsWrite+0x6895>
 11c22c3:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c22c7:	f6 40 08 07          	testb  $0x7,0x8(%rax)
 11c22cb:	74 08                	je     11c22d5 <br.encodeCommandPlanWithOptionsWrite+0x6895>
 11c22cd:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 11c22d1:	c6 40 08 00          	movb   $0x0,0x8(%rax)
 11c22d5:	31 c0                	xor    %eax,%eax
 11c22d7:	e9 d1 97 ff ff       	jmp    11bbaad <br.encodeCommandPlanWithOptionsWrite+0x6d>
 11c22dc:	b9 05 00 00 00       	mov    $0x5,%ecx
 11c22e1:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 11c22e5:	0f 85 ba fc ff ff    	jne    11c1fa5 <br.encodeCommandPlanWithOptionsWrite+0x6565>
 11c22eb:	80 7d ca 01          	cmpb   $0x1,-0x36(%rbp)
 11c22ef:	bf 03 00 00 00       	mov    $0x3,%edi
 11c22f4:	48 83 df 00          	sbb    $0x0,%rdi
 11c22f8:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 11c22fc:	b9 04 00 00 00       	mov    $0x4,%ecx
 11c2301:	48 0f 44 cf          	cmove  %rdi,%rcx
 11c2305:	e9 9b fc ff ff       	jmp    11c1fa5 <br.encodeCommandPlanWithOptionsWrite+0x6565>
 11c230a:	41 bc 05 00 00 00    	mov    $0x5,%r12d
 11c2310:	80 7d d7 00          	cmpb   $0x0,-0x29(%rbp)
 11c2314:	0f 85 28 fe ff ff    	jne    11c2142 <br.encodeCommandPlanWithOptionsWrite+0x6702>
 11c231a:	80 7d d5 01          	cmpb   $0x1,-0x2b(%rbp)
 11c231e:	b9 03 00 00 00       	mov    $0x3,%ecx
 11c2323:	48 83 d9 00          	sbb    $0x0,%rcx
 11c2327:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 11c232b:	41 bc 04 00 00 00    	mov    $0x4,%r12d
 11c2331:	4c 0f 44 e1          	cmove  %rcx,%r12
 11c2335:	e9 08 fe ff ff       	jmp    11c2142 <br.encodeCommandPlanWithOptionsWrite+0x6702>
 11c233a:	b9 05 00 00 00       	mov    $0x5,%ecx
 11c233f:	80 7d d1 00          	cmpb   $0x0,-0x2f(%rbp)
 11c2343:	0f 85 1b fa ff ff    	jne    11c1d64 <br.encodeCommandPlanWithOptionsWrite+0x6324>
 11c2349:	80 7d c5 01          	cmpb   $0x1,-0x3b(%rbp)
 11c234d:	be 03 00 00 00       	mov    $0x3,%esi
 11c2352:	48 83 de 00          	sbb    $0x0,%rsi
 11c2356:	80 7d cf 00          	cmpb   $0x0,-0x31(%rbp)
 11c235a:	b9 04 00 00 00       	mov    $0x4,%ecx
 11c235f:	48 0f 44 ce          	cmove  %rsi,%rcx
 11c2363:	e9 fc f9 ff ff       	jmp    11c1d64 <br.encodeCommandPlanWithOptionsWrite+0x6324>
 11c2368:	4d 39 c1             	cmp    %r8,%r9
 11c236b:	0f 86 ee 9e ff ff    	jbe    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11c2371:	4c 89 c9             	mov    %r9,%rcx
 11c2374:	49 39 f1             	cmp    %rsi,%r9
 11c2377:	0f 83 e2 9e ff ff    	jae    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11c237d:	48 ff c2             	inc    %rdx
 11c2380:	49 39 d3             	cmp    %rdx,%r11
 11c2383:	0f 84 33 a6 ff ff    	je     11bc9bc <br.encodeCommandPlanWithOptionsWrite+0xf7c>
 11c2389:	48 8b bd c0 fd ff ff 	mov    -0x240(%rbp),%rdi
 11c2390:	48 89 bd 48 fd ff ff 	mov    %rdi,-0x2b8(%rbp)
 11c2397:	48 8b bd c8 fd ff ff 	mov    -0x238(%rbp),%rdi
 11c239e:	48 89 bd a8 fc ff ff 	mov    %rdi,-0x358(%rbp)
 11c23a5:	48 8b bd d0 fd ff ff 	mov    -0x230(%rbp),%rdi
 11c23ac:	48 89 bd b0 fc ff ff 	mov    %rdi,-0x350(%rbp)
 11c23b3:	48 8b bd d8 fd ff ff 	mov    -0x228(%rbp),%rdi
 11c23ba:	48 89 bd b8 fc ff ff 	mov    %rdi,-0x348(%rbp)
 11c23c1:	48 8d bd 48 fd ff ff 	lea    -0x2b8(%rbp),%rdi
 11c23c8:	49 89 c8             	mov    %rcx,%r8
 11c23cb:	4c 8b 8d 38 fe ff ff 	mov    -0x1c8(%rbp),%r9
 11c23d2:	ff 24 d5 88 ff 00 01 	jmp    *0x100ff88(,%rdx,8)
 11c23d9:	48 8d bd a8 fc ff ff 	lea    -0x358(%rbp),%rdi
 11c23e0:	eb 10                	jmp    11c23f2 <br.encodeCommandPlanWithOptionsWrite+0x69b2>
 11c23e2:	48 8d bd b0 fc ff ff 	lea    -0x350(%rbp),%rdi
 11c23e9:	eb 07                	jmp    11c23f2 <br.encodeCommandPlanWithOptionsWrite+0x69b2>
 11c23eb:	48 8d bd b8 fc ff ff 	lea    -0x348(%rbp),%rdi
 11c23f2:	4c 8b 0f             	mov    (%rdi),%r9
 11c23f5:	49 89 c8             	mov    %rcx,%r8
 11c23f8:	e9 6b ff ff ff       	jmp    11c2368 <br.encodeCommandPlanWithOptionsWrite+0x6928>
 11c23fd:	49 39 f8             	cmp    %rdi,%r8
 11c2400:	0f 86 59 9e ff ff    	jbe    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11c2406:	4c 89 c1             	mov    %r8,%rcx
 11c2409:	48 ff c2             	inc    %rdx
 11c240c:	48 39 d0             	cmp    %rdx,%rax
 11c240f:	0f 84 f5 a7 ff ff    	je     11bcc0a <br.encodeCommandPlanWithOptionsWrite+0x11ca>
 11c2415:	48 8b b5 60 fe ff ff 	mov    -0x1a0(%rbp),%rsi
 11c241c:	48 89 b5 40 fd ff ff 	mov    %rsi,-0x2c0(%rbp)
 11c2423:	48 8b b5 68 fe ff ff 	mov    -0x198(%rbp),%rsi
 11c242a:	48 89 b5 90 fc ff ff 	mov    %rsi,-0x370(%rbp)
 11c2431:	48 8b b5 70 fe ff ff 	mov    -0x190(%rbp),%rsi
 11c2438:	48 89 b5 98 fc ff ff 	mov    %rsi,-0x368(%rbp)
 11c243f:	48 8b b5 78 fe ff ff 	mov    -0x188(%rbp),%rsi
 11c2446:	48 89 b5 a0 fc ff ff 	mov    %rsi,-0x360(%rbp)
 11c244d:	48 8d b5 40 fd ff ff 	lea    -0x2c0(%rbp),%rsi
 11c2454:	48 89 cf             	mov    %rcx,%rdi
 11c2457:	4c 8b 85 d8 fe ff ff 	mov    -0x128(%rbp),%r8
 11c245e:	ff 24 d5 b0 ff 00 01 	jmp    *0x100ffb0(,%rdx,8)
 11c2465:	48 8d b5 90 fc ff ff 	lea    -0x370(%rbp),%rsi
 11c246c:	eb 10                	jmp    11c247e <br.encodeCommandPlanWithOptionsWrite+0x6a3e>
 11c246e:	48 8d b5 98 fc ff ff 	lea    -0x368(%rbp),%rsi
 11c2475:	eb 07                	jmp    11c247e <br.encodeCommandPlanWithOptionsWrite+0x6a3e>
 11c2477:	48 8d b5 a0 fc ff ff 	lea    -0x360(%rbp),%rsi
 11c247e:	4c 8b 06             	mov    (%rsi),%r8
 11c2481:	48 89 cf             	mov    %rcx,%rdi
 11c2484:	e9 74 ff ff ff       	jmp    11c23fd <br.encodeCommandPlanWithOptionsWrite+0x69bd>
 11c2489:	48 39 7d 80          	cmp    %rdi,-0x80(%rbp)
 11c248d:	0f 86 cc 9d ff ff    	jbe    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11c2493:	48 ff c1             	inc    %rcx
 11c2496:	48 39 c8             	cmp    %rcx,%rax
 11c2499:	0f 84 91 b5 ff ff    	je     11bda30 <br.encodeCommandPlanWithOptionsWrite+0x1ff0>
 11c249f:	4c 89 8d d0 fb ff ff 	mov    %r9,-0x430(%rbp)
 11c24a6:	48 8b b5 20 ff ff ff 	mov    -0xe0(%rbp),%rsi
 11c24ad:	48 89 b5 d8 fb ff ff 	mov    %rsi,-0x428(%rbp)
 11c24b4:	48 8b b5 28 ff ff ff 	mov    -0xd8(%rbp),%rsi
 11c24bb:	48 89 b5 e0 fb ff ff 	mov    %rsi,-0x420(%rbp)
 11c24c2:	48 8b b5 30 ff ff ff 	mov    -0xd0(%rbp),%rsi
 11c24c9:	48 89 b5 e8 fb ff ff 	mov    %rsi,-0x418(%rbp)
 11c24d0:	48 89 d6             	mov    %rdx,%rsi
 11c24d3:	4c 89 c7             	mov    %r8,%rdi
 11c24d6:	ff 24 cd d8 ff 00 01 	jmp    *0x100ffd8(,%rcx,8)
 11c24dd:	48 8d b5 d8 fb ff ff 	lea    -0x428(%rbp),%rsi
 11c24e4:	eb 10                	jmp    11c24f6 <br.encodeCommandPlanWithOptionsWrite+0x6ab6>
 11c24e6:	48 8d b5 e0 fb ff ff 	lea    -0x420(%rbp),%rsi
 11c24ed:	eb 07                	jmp    11c24f6 <br.encodeCommandPlanWithOptionsWrite+0x6ab6>
 11c24ef:	48 8d b5 e8 fb ff ff 	lea    -0x418(%rbp),%rsi
 11c24f6:	48 8b 3e             	mov    (%rsi),%rdi
 11c24f9:	eb 8e                	jmp    11c2489 <br.encodeCommandPlanWithOptionsWrite+0x6a49>
 11c24fb:	48 39 bd 10 fd ff ff 	cmp    %rdi,-0x2f0(%rbp)
 11c2502:	0f 86 57 9d ff ff    	jbe    11bc25f <br.encodeCommandPlanWithOptionsWrite+0x81f>
 11c2508:	48 ff c1             	inc    %rcx
 11c250b:	48 39 c8             	cmp    %rcx,%rax
 11c250e:	0f 84 87 b6 ff ff    	je     11bdb9b <br.encodeCommandPlanWithOptionsWrite+0x215b>
 11c2514:	48 8b b5 60 fe ff ff 	mov    -0x1a0(%rbp),%rsi
 11c251b:	48 89 b5 b0 fb ff ff 	mov    %rsi,-0x450(%rbp)
 11c2522:	48 8b b5 68 fe ff ff 	mov    -0x198(%rbp),%rsi
 11c2529:	48 89 b5 b8 fb ff ff 	mov    %rsi,-0x448(%rbp)
 11c2530:	48 8b b5 70 fe ff ff 	mov    -0x190(%rbp),%rsi
 11c2537:	48 89 b5 c0 fb ff ff 	mov    %rsi,-0x440(%rbp)
 11c253e:	48 8b b5 78 fe ff ff 	mov    -0x188(%rbp),%rsi
 11c2545:	48 89 b5 c8 fb ff ff 	mov    %rsi,-0x438(%rbp)
 11c254c:	48 89 d6             	mov    %rdx,%rsi
 11c254f:	48 8b bd d8 fe ff ff 	mov    -0x128(%rbp),%rdi
 11c2556:	ff 24 cd 00 00 01 01 	jmp    *0x1010000(,%rcx,8)
 11c255d:	48 8d b5 b8 fb ff ff 	lea    -0x448(%rbp),%rsi
 11c2564:	eb 10                	jmp    11c2576 <br.encodeCommandPlanWithOptionsWrite+0x6b36>
 11c2566:	48 8d b5 c0 fb ff ff 	lea    -0x440(%rbp),%rsi
 11c256d:	eb 07                	jmp    11c2576 <br.encodeCommandPlanWithOptionsWrite+0x6b36>
 11c256f:	48 8d b5 c8 fb ff ff 	lea    -0x438(%rbp),%rsi
 11c2576:	48 8b 3e             	mov    (%rsi),%rdi
 11c2579:	eb 80                	jmp    11c24fb <br.encodeCommandPlanWithOptionsWrite+0x6abb>

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
