
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

000000000123dfe0 <br.encoder.quality_profile.Active.prefer>:
 123dfe0:	55                   	push   %rbp
 123dfe1:	48 89 e5             	mov    %rsp,%rbp
 123dfe4:	41 57                	push   %r15
 123dfe6:	41 56                	push   %r14
 123dfe8:	41 55                	push   %r13
 123dfea:	41 54                	push   %r12
 123dfec:	53                   	push   %rbx
 123dfed:	48 8b 47 10          	mov    0x10(%rdi),%rax
 123dff1:	4c 8b 88 c8 32 02 00 	mov    0x232c8(%rax),%r9
 123dff8:	4d 85 c9             	test   %r9,%r9
 123dffb:	74 1a                	je     123e017 <br.encoder.quality_profile.Active.prefer+0x37>
 123dffd:	49 c1 e1 04          	shl    $0x4,%r9
 123e001:	4e 8b 8c 08 b8 30 02 	mov    0x230b8(%rax,%r9,1),%r9
 123e008:	00 
 123e009:	4c 89 4d a0          	mov    %r9,-0x60(%rbp)
 123e00d:	c6 45 a8 01          	movb   $0x1,-0x58(%rbp)
 123e011:	4c 8d 55 a0          	lea    -0x60(%rbp),%r10
 123e015:	eb 06                	jmp    123e01d <br.encoder.quality_profile.Active.prefer+0x3d>
 123e017:	41 ba 70 0a 00 01    	mov    $0x1000a70,%r10d
 123e01d:	45 31 c9             	xor    %r9d,%r9d
 123e020:	4d 89 c3             	mov    %r8,%r11
 123e023:	49 29 d3             	sub    %rdx,%r11
 123e026:	4d 0f 43 cb          	cmovae %r11,%r9
 123e02a:	0f b6 98 d0 42 02 00 	movzbl 0x242d0(%rax),%ebx
 123e031:	84 db                	test   %bl,%bl
 123e033:	75 7e                	jne    123e0b3 <br.encoder.quality_profile.Active.prefer+0xd3>
 123e035:	80 b8 d1 42 02 00 00 	cmpb   $0x0,0x242d1(%rax)
 123e03c:	74 75                	je     123e0b3 <br.encoder.quality_profile.Active.prefer+0xd3>
 123e03e:	4c 8b b0 20 30 02 00 	mov    0x23020(%rax),%r14
 123e045:	4d 85 f6             	test   %r14,%r14
 123e048:	74 69                	je     123e0b3 <br.encoder.quality_profile.Active.prefer+0xd3>
 123e04a:	4d 6b de 23          	imul   $0x23,%r14,%r11
 123e04e:	eb 09                	jmp    123e059 <br.encoder.quality_profile.Active.prefer+0x79>
 123e050:	49 83 c3 dd          	add    $0xffffffffffffffdd,%r11
 123e054:	4d 85 f6             	test   %r14,%r14
 123e057:	74 5a                	je     123e0b3 <br.encoder.quality_profile.Active.prefer+0xd3>
 123e059:	42 80 bc 30 d2 42 02 	cmpb   $0x1,0x242d2(%rax,%r14,1)
 123e060:	00 01 
 123e062:	4d 8d 76 ff          	lea    -0x1(%r14),%r14
 123e066:	75 e8                	jne    123e050 <br.encoder.quality_profile.Active.prefer+0x70>
 123e068:	46 0f b6 7c d8 18    	movzbl 0x18(%rax,%r11,8),%r15d
 123e06e:	41 80 e7 0f          	and    $0xf,%r15b
 123e072:	41 80 ff 07          	cmp    $0x7,%r15b
 123e076:	75 d8                	jne    123e050 <br.encoder.quality_profile.Active.prefer+0x70>
 123e078:	4a 83 bc d8 58 ff ff 	cmpq   $0x0,-0xa8(%rax,%r11,8)
 123e07f:	ff 00 
 123e081:	75 cd                	jne    123e050 <br.encoder.quality_profile.Active.prefer+0x70>
 123e083:	42 80 bc d8 48 ff ff 	cmpb   $0x0,-0xb8(%rax,%r11,8)
 123e08a:	ff 00 
 123e08c:	74 c2                	je     123e050 <br.encoder.quality_profile.Active.prefer+0x70>
 123e08e:	4a 39 94 d8 40 ff ff 	cmp    %rdx,-0xc0(%rax,%r11,8)
 123e095:	ff 
 123e096:	75 b8                	jne    123e050 <br.encoder.quality_profile.Active.prefer+0x70>
 123e098:	4a 39 b4 f0 d0 32 02 	cmp    %rsi,0x232d0(%rax,%r14,8)
 123e09f:	00 
 123e0a0:	75 ae                	jne    123e050 <br.encoder.quality_profile.Active.prefer+0x70>
 123e0a2:	4e 8b 9c d8 08 ff ff 	mov    -0xf8(%rax,%r11,8),%r11
 123e0a9:	ff 
 123e0aa:	40 b6 01             	mov    $0x1,%sil
 123e0ad:	48 89 75 b0          	mov    %rsi,-0x50(%rbp)
 123e0b1:	eb 19                	jmp    123e0cc <br.encoder.quality_profile.Active.prefer+0xec>
 123e0b3:	c7 45 c7 00 00 00 00 	movl   $0x0,-0x39(%rbp)
 123e0ba:	c7 45 c4 00 00 00 00 	movl   $0x0,-0x3c(%rbp)
 123e0c1:	48 c7 45 b0 00 00 00 	movq   $0x0,-0x50(%rbp)
 123e0c8:	00 
 123e0c9:	45 31 db             	xor    %r11d,%r11d
 123e0cc:	44 0f b6 7f 18       	movzbl 0x18(%rdi),%r15d
 123e0d1:	44 0f b6 77 19       	movzbl 0x19(%rdi),%r14d
 123e0d6:	48 8b b8 28 30 02 00 	mov    0x23028(%rax),%rdi
 123e0dd:	84 db                	test   %bl,%bl
 123e0df:	75 7d                	jne    123e15e <br.encoder.quality_profile.Active.prefer+0x17e>
 123e0e1:	80 b8 d1 42 02 00 00 	cmpb   $0x0,0x242d1(%rax)
 123e0e8:	74 74                	je     123e15e <br.encoder.quality_profile.Active.prefer+0x17e>
 123e0ea:	48 8b 98 20 30 02 00 	mov    0x23020(%rax),%rbx
 123e0f1:	48 85 db             	test   %rbx,%rbx
 123e0f4:	74 7f                	je     123e175 <br.encoder.quality_profile.Active.prefer+0x195>
 123e0f6:	4c 6b e3 23          	imul   $0x23,%rbx,%r12
 123e0fa:	49 89 dd             	mov    %rbx,%r13
 123e0fd:	eb 0a                	jmp    123e109 <br.encoder.quality_profile.Active.prefer+0x129>
 123e0ff:	90                   	nop
 123e100:	49 83 c4 dd          	add    $0xffffffffffffffdd,%r12
 123e104:	4d 85 ed             	test   %r13,%r13
 123e107:	74 6c                	je     123e175 <br.encoder.quality_profile.Active.prefer+0x195>
 123e109:	42 80 bc 28 d2 42 02 	cmpb   $0x1,0x242d2(%rax,%r13,1)
 123e110:	00 01 
 123e112:	4d 8d 6d ff          	lea    -0x1(%r13),%r13
 123e116:	75 e8                	jne    123e100 <br.encoder.quality_profile.Active.prefer+0x120>
 123e118:	42 0f b6 74 e0 18    	movzbl 0x18(%rax,%r12,8),%esi
 123e11e:	40 80 e6 0f          	and    $0xf,%sil
 123e122:	40 80 fe 07          	cmp    $0x7,%sil
 123e126:	75 d8                	jne    123e100 <br.encoder.quality_profile.Active.prefer+0x120>
 123e128:	4a 83 bc e0 58 ff ff 	cmpq   $0x0,-0xa8(%rax,%r12,8)
 123e12f:	ff 00 
 123e131:	75 cd                	jne    123e100 <br.encoder.quality_profile.Active.prefer+0x120>
 123e133:	42 80 bc e0 48 ff ff 	cmpb   $0x0,-0xb8(%rax,%r12,8)
 123e13a:	ff 00 
 123e13c:	74 c2                	je     123e100 <br.encoder.quality_profile.Active.prefer+0x120>
 123e13e:	4e 39 84 e0 40 ff ff 	cmp    %r8,-0xc0(%rax,%r12,8)
 123e145:	ff 
 123e146:	75 b8                	jne    123e100 <br.encoder.quality_profile.Active.prefer+0x120>
 123e148:	4a 39 8c e8 d0 32 02 	cmp    %rcx,0x232d0(%rax,%r13,8)
 123e14f:	00 
 123e150:	75 ae                	jne    123e100 <br.encoder.quality_profile.Active.prefer+0x120>
 123e152:	4e 8b ac e0 08 ff ff 	mov    -0xf8(%rax,%r12,8),%r13
 123e159:	ff 
 123e15a:	b1 01                	mov    $0x1,%cl
 123e15c:	eb 2a                	jmp    123e188 <br.encoder.quality_profile.Active.prefer+0x1a8>
 123e15e:	c7 45 bf 00 00 00 00 	movl   $0x0,-0x41(%rbp)
 123e165:	c7 45 bc 00 00 00 00 	movl   $0x0,-0x44(%rbp)
 123e16c:	48 8b 98 20 30 02 00 	mov    0x23020(%rax),%rbx
 123e173:	eb 0e                	jmp    123e183 <br.encoder.quality_profile.Active.prefer+0x1a3>
 123e175:	c7 45 bf 00 00 00 00 	movl   $0x0,-0x41(%rbp)
 123e17c:	c7 45 bc 00 00 00 00 	movl   $0x0,-0x44(%rbp)
 123e183:	31 c9                	xor    %ecx,%ecx
 123e185:	45 31 ed             	xor    %r13d,%r13d
 123e188:	4c 39 c2             	cmp    %r8,%rdx
 123e18b:	0f 92 45 cc          	setb   -0x34(%rbp)
 123e18f:	41 0f 92 c4          	setb   %r12b
 123e193:	c4 c1 78 10 02       	vmovups (%r10),%xmm0
 123e198:	c5 f8 29 45 90       	vmovaps %xmm0,-0x70(%rbp)
 123e19d:	c6 45 d0 09          	movb   $0x9,-0x30(%rbp)
 123e1a1:	41 80 e7 03          	and    $0x3,%r15b
 123e1a5:	44 88 7d cd          	mov    %r15b,-0x33(%rbp)
 123e1a9:	41 80 e6 01          	and    $0x1,%r14b
 123e1ad:	44 88 75 ce          	mov    %r14b,-0x32(%rbp)
 123e1b1:	48 89 fe             	mov    %rdi,%rsi
 123e1b4:	48 ff c6             	inc    %rsi
 123e1b7:	49 c7 c2 ff ff ff ff 	mov    $0xffffffffffffffff,%r10
 123e1be:	4c 0f 45 d6          	cmovne %rsi,%r10
 123e1c2:	4c 89 90 28 30 02 00 	mov    %r10,0x23028(%rax)
 123e1c9:	48 8b 70 18          	mov    0x18(%rax),%rsi
 123e1cd:	48 81 fe 00 02 00 00 	cmp    $0x200,%rsi
 123e1d4:	41 ba 00 02 00 00    	mov    $0x200,%r10d
 123e1da:	4c 0f 42 d6          	cmovb  %rsi,%r10
 123e1de:	4c 39 d3             	cmp    %r10,%rbx
 123e1e1:	0f 83 2c 01 00 00    	jae    123e313 <br.encoder.quality_profile.Active.prefer+0x333>
 123e1e7:	4c 69 d3 18 01 00 00 	imul   $0x118,%rbx,%r10
 123e1ee:	4a 89 7c 10 20       	mov    %rdi,0x20(%rax,%r10,1)
 123e1f3:	c5 f8 28 45 90       	vmovaps -0x70(%rbp),%xmm0
 123e1f8:	c4 a1 78 11 44 10 28 	vmovups %xmm0,0x28(%rax,%r10,1)
 123e1ff:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 123e203:	c4 a1 7c 11 44 10 38 	vmovups %ymm0,0x38(%rax,%r10,1)
 123e20a:	4a 89 54 10 58       	mov    %rdx,0x58(%rax,%r10,1)
 123e20f:	42 c6 44 10 60 01    	movb   $0x1,0x60(%rax,%r10,1)
 123e215:	4a c7 44 10 68 8e 9e 	movq   $0x1139e8e,0x68(%rax,%r10,1)
 123e21c:	13 01 
 123e21e:	4a c7 44 10 70 00 00 	movq   $0x0,0x70(%rax,%r10,1)
 123e225:	00 00 
 123e227:	4e 89 4c 10 78       	mov    %r9,0x78(%rax,%r10,1)
 123e22c:	4e 89 84 10 80 00 00 	mov    %r8,0x80(%rax,%r10,1)
 123e233:	00 
 123e234:	42 c6 84 10 88 00 00 	movb   $0x1,0x88(%rax,%r10,1)
 123e23b:	00 01 
 123e23d:	4e 89 9c 10 90 00 00 	mov    %r11,0x90(%rax,%r10,1)
 123e244:	00 
 123e245:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 123e249:	42 88 b4 10 98 00 00 	mov    %sil,0x98(%rax,%r10,1)
 123e250:	00 
 123e251:	8b 75 c4             	mov    -0x3c(%rbp),%esi
 123e254:	8b 7d c7             	mov    -0x39(%rbp),%edi
 123e257:	42 89 b4 10 99 00 00 	mov    %esi,0x99(%rax,%r10,1)
 123e25e:	00 
 123e25f:	42 89 bc 10 9c 00 00 	mov    %edi,0x9c(%rax,%r10,1)
 123e266:	00 
 123e267:	4e 89 ac 10 a0 00 00 	mov    %r13,0xa0(%rax,%r10,1)
 123e26e:	00 
 123e26f:	42 88 8c 10 a8 00 00 	mov    %cl,0xa8(%rax,%r10,1)
 123e276:	00 
 123e277:	8b 4d bc             	mov    -0x44(%rbp),%ecx
 123e27a:	8b 75 bf             	mov    -0x41(%rbp),%esi
 123e27d:	42 89 8c 10 a9 00 00 	mov    %ecx,0xa9(%rax,%r10,1)
 123e284:	00 
 123e285:	42 89 b4 10 ac 00 00 	mov    %esi,0xac(%rax,%r10,1)
 123e28c:	00 
 123e28d:	c5 fc 10 05 a3 0d e5 	vmovups -0x1af25d(%rip),%ymm0        # 108f038 <__anon_27426+0x60>
 123e294:	ff 
 123e295:	c4 a1 7c 11 84 10 10 	vmovups %ymm0,0x110(%rax,%r10,1)
 123e29c:	01 00 00 
 123e29f:	c5 fc 10 05 71 0d e5 	vmovups -0x1af28f(%rip),%ymm0        # 108f018 <__anon_27426+0x40>
 123e2a6:	ff 
 123e2a7:	c4 a1 7c 11 84 10 f0 	vmovups %ymm0,0xf0(%rax,%r10,1)
 123e2ae:	00 00 00 
 123e2b1:	c5 fc 10 05 3f 0d e5 	vmovups -0x1af2c1(%rip),%ymm0        # 108eff8 <__anon_27426+0x20>
 123e2b8:	ff 
 123e2b9:	c4 a1 7c 11 84 10 d0 	vmovups %ymm0,0xd0(%rax,%r10,1)
 123e2c0:	00 00 00 
 123e2c3:	c5 fc 10 05 0d 0d e5 	vmovups -0x1af2f3(%rip),%ymm0        # 108efd8 <__anon_27426>
 123e2ca:	ff 
 123e2cb:	c4 a1 7c 11 84 10 b0 	vmovups %ymm0,0xb0(%rax,%r10,1)
 123e2d2:	00 00 00 
 123e2d5:	0f b6 4d d0          	movzbl -0x30(%rbp),%ecx
 123e2d9:	42 88 8c 10 30 01 00 	mov    %cl,0x130(%rax,%r10,1)
 123e2e0:	00 
 123e2e1:	0f b6 4d cd          	movzbl -0x33(%rbp),%ecx
 123e2e5:	42 88 8c 10 31 01 00 	mov    %cl,0x131(%rax,%r10,1)
 123e2ec:	00 
 123e2ed:	0f b6 4d ce          	movzbl -0x32(%rbp),%ecx
 123e2f1:	42 88 8c 10 32 01 00 	mov    %cl,0x132(%rax,%r10,1)
 123e2f8:	00 
 123e2f9:	46 88 a4 10 33 01 00 	mov    %r12b,0x133(%rax,%r10,1)
 123e300:	00 
 123e301:	42 c6 84 10 34 01 00 	movb   $0x1,0x134(%rax,%r10,1)
 123e308:	00 01 
 123e30a:	48 ff 80 20 30 02 00 	incq   0x23020(%rax)
 123e311:	eb 07                	jmp    123e31a <br.encoder.quality_profile.Active.prefer+0x33a>
 123e313:	c6 80 d0 42 02 00 01 	movb   $0x1,0x242d0(%rax)
 123e31a:	4c 39 c2             	cmp    %r8,%rdx
 123e31d:	0f 92 c0             	setb   %al
 123e320:	5b                   	pop    %rbx
 123e321:	41 5c                	pop    %r12
 123e323:	41 5d                	pop    %r13
 123e325:	41 5e                	pop    %r14
 123e327:	41 5f                	pop    %r15
 123e329:	5d                   	pop    %rbp
 123e32a:	c5 f8 77             	vzeroupper 
 123e32d:	c3                   	ret    

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
