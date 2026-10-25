
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

0000000001276f60 <br.encoder.total_budget.Lease.init>:
 1276f60:	55                   	push   %rbp
 1276f61:	48 89 e5             	mov    %rsp,%rbp
 1276f64:	41 57                	push   %r15
 1276f66:	41 56                	push   %r14
 1276f68:	41 55                	push   %r13
 1276f6a:	41 54                	push   %r12
 1276f6c:	53                   	push   %rbx
 1276f6d:	48 83 ec 18          	sub    $0x18,%rsp
 1276f71:	48 8b 06             	mov    (%rsi),%rax
 1276f74:	4c 8b 4e 08          	mov    0x8(%rsi),%r9
 1276f78:	49 81 f9 a8 f2 11 01 	cmp    $0x111f2a8,%r9
 1276f7f:	41 0f 95 c2          	setne  %r10b
 1276f83:	48 85 c0             	test   %rax,%rax
 1276f86:	41 0f 94 c3          	sete   %r11b
 1276f8a:	45 08 d3             	or     %r10b,%r11b
 1276f8d:	74 33                	je     1276fc2 <br.encoder.total_budget.Lease.init+0x62>
 1276f8f:	80 7a 08 00          	cmpb   $0x0,0x8(%rdx)
 1276f93:	41 0f 94 c2          	sete   %r10b
 1276f97:	48 85 c9             	test   %rcx,%rcx
 1276f9a:	41 0f 94 c3          	sete   %r11b
 1276f9e:	45 84 da             	test   %r11b,%r10b
 1276fa1:	74 46                	je     1276fe9 <br.encoder.total_budget.Lease.init+0x89>
 1276fa3:	66 c7 47 20 00 00    	movw   $0x0,0x20(%rdi)
 1276fa9:	c5 f8 10 06          	vmovups (%rsi),%xmm0
 1276fad:	c5 f8 11 07          	vmovups %xmm0,(%rdi)
 1276fb1:	48 c7 47 10 00 00 00 	movq   $0x0,0x10(%rdi)
 1276fb8:	00 
 1276fb9:	c6 47 18 01          	movb   $0x1,0x18(%rdi)
 1276fbd:	e9 98 01 00 00       	jmp    127715a <br.encoder.total_budget.Lease.init+0x1fa>
 1276fc2:	48 8b 70 40          	mov    0x40(%rax),%rsi
 1276fc6:	48 85 f6             	test   %rsi,%rsi
 1276fc9:	74 05                	je     1276fd0 <br.encoder.total_budget.Lease.init+0x70>
 1276fcb:	4d 85 c0             	test   %r8,%r8
 1276fce:	74 6a                	je     127703a <br.encoder.total_budget.Lease.init+0xda>
 1276fd0:	c5 fc 10 05 48 c8 e0 	vmovups -0x1f37b8(%rip),%ymm0        # 1083820 <__anon_41517>
 1276fd7:	ff 
 1276fd8:	c5 fc 11 07          	vmovups %ymm0,(%rdi)
 1276fdc:	48 c7 47 20 52 00 00 	movq   $0x52,0x20(%rdi)
 1276fe3:	00 
 1276fe4:	e9 71 01 00 00       	jmp    127715a <br.encoder.total_budget.Lease.init+0x1fa>
 1276fe9:	48 85 c9             	test   %rcx,%rcx
 1276fec:	74 1e                	je     127700c <br.encoder.total_budget.Lease.init+0xac>
 1276fee:	c6 41 20 01          	movb   $0x1,0x20(%rcx)
 1276ff2:	4c 89 41 08          	mov    %r8,0x8(%rcx)
 1276ff6:	4c 8b 11             	mov    (%rcx),%r10
 1276ff9:	4d 39 c2             	cmp    %r8,%r10
 1276ffc:	4d 0f 46 d0          	cmovbe %r8,%r10
 1277000:	4c 89 11             	mov    %r10,(%rcx)
 1277003:	c5 f8 10 02          	vmovups (%rdx),%xmm0
 1277007:	c5 f8 11 41 10       	vmovups %xmm0,0x10(%rcx)
 127700c:	49 83 c0 50          	add    $0x50,%r8
 1277010:	0f 92 45 c0          	setb   -0x40(%rbp)
 1277014:	72 46                	jb     127705c <br.encoder.total_budget.Lease.init+0xfc>
 1277016:	80 7a 08 00          	cmpb   $0x0,0x8(%rdx)
 127701a:	74 59                	je     1277075 <br.encoder.total_budget.Lease.init+0x115>
 127701c:	4c 3b 02             	cmp    (%rdx),%r8
 127701f:	76 54                	jbe    1277075 <br.encoder.total_budget.Lease.init+0x115>
 1277021:	c5 fc 10 05 ef f7 e1 	vmovups -0x1e0811(%rip),%ymm0        # 1096818 <__anon_231870>
 1277028:	ff 
 1277029:	c5 fc 11 07          	vmovups %ymm0,(%rdi)
 127702d:	48 c7 47 20 5a 00 00 	movq   $0x5a,0x20(%rdi)
 1277034:	00 
 1277035:	e9 20 01 00 00       	jmp    127715a <br.encoder.total_budget.Lease.init+0x1fa>
 127703a:	80 7a 08 00          	cmpb   $0x0,0x8(%rdx)
 127703e:	74 0f                	je     127704f <br.encoder.total_budget.Lease.init+0xef>
 1277040:	80 78 18 00          	cmpb   $0x0,0x18(%rax)
 1277044:	74 8a                	je     1276fd0 <br.encoder.total_budget.Lease.init+0x70>
 1277046:	48 8b 12             	mov    (%rdx),%rdx
 1277049:	48 3b 50 10          	cmp    0x10(%rax),%rdx
 127704d:	75 81                	jne    1276fd0 <br.encoder.total_budget.Lease.init+0x70>
 127704f:	48 ff c6             	inc    %rsi
 1277052:	0f 94 45 c0          	sete   -0x40(%rbp)
 1277056:	0f 85 cd 00 00 00    	jne    1277129 <br.encoder.total_budget.Lease.init+0x1c9>
 127705c:	c5 fc 10 05 e4 c7 e0 	vmovups -0x1f381c(%rip),%ymm0        # 1083848 <__anon_41519>
 1277063:	ff 
 1277064:	c5 fc 11 07          	vmovups %ymm0,(%rdi)
 1277068:	48 c7 47 20 43 00 00 	movq   $0x43,0x20(%rdi)
 127706f:	00 
 1277070:	e9 e5 00 00 00       	jmp    127715a <br.encoder.total_budget.Lease.init+0x1fa>
 1277075:	49 89 d4             	mov    %rdx,%r12
 1277078:	49 89 f5             	mov    %rsi,%r13
 127707b:	4d 89 c6             	mov    %r8,%r14
 127707e:	49 89 cf             	mov    %rcx,%r15
 1277081:	48 89 fb             	mov    %rdi,%rbx
 1277084:	48 8b 4d 08          	mov    0x8(%rbp),%rcx
 1277088:	be 50 00 00 00       	mov    $0x50,%esi
 127708d:	48 89 c7             	mov    %rax,%rdi
 1277090:	ba 03 00 00 00       	mov    $0x3,%edx
 1277095:	41 ff 11             	call   *(%r9)
 1277098:	48 85 c0             	test   %rax,%rax
 127709b:	0f 84 b3 00 00 00    	je     1277154 <br.encoder.total_budget.Lease.init+0x1f4>
 12770a1:	4c 89 e9             	mov    %r13,%rcx
 12770a4:	c4 c1 78 10 45 00    	vmovups 0x0(%r13),%xmm0
 12770aa:	c5 f8 11 00          	vmovups %xmm0,(%rax)
 12770ae:	c4 c1 78 10 04 24    	vmovups (%r12),%xmm0
 12770b4:	c5 f8 11 40 10       	vmovups %xmm0,0x10(%rax)
 12770b9:	4c 89 78 20          	mov    %r15,0x20(%rax)
 12770bd:	4c 89 70 28          	mov    %r14,0x28(%rax)
 12770c1:	4c 89 70 30          	mov    %r14,0x30(%rax)
 12770c5:	48 c7 40 38 00 00 00 	movq   $0x0,0x38(%rax)
 12770cc:	00 
 12770cd:	48 c7 40 40 01 00 00 	movq   $0x1,0x40(%rax)
 12770d4:	00 
 12770d5:	66 c7 40 48 00 00    	movw   $0x0,0x48(%rax)
 12770db:	4d 85 ff             	test   %r15,%r15
 12770de:	74 31                	je     1277111 <br.encoder.total_budget.Lease.init+0x1b1>
 12770e0:	48 89 c6             	mov    %rax,%rsi
 12770e3:	48 83 c6 10          	add    $0x10,%rsi
 12770e7:	c5 f8 10 06          	vmovups (%rsi),%xmm0
 12770eb:	c5 f8 29 45 c0       	vmovaps %xmm0,-0x40(%rbp)
 12770f0:	41 c6 47 20 01       	movb   $0x1,0x20(%r15)
 12770f5:	4d 89 77 08          	mov    %r14,0x8(%r15)
 12770f9:	49 8b 37             	mov    (%r15),%rsi
 12770fc:	4c 39 f6             	cmp    %r14,%rsi
 12770ff:	4c 0f 47 f6          	cmova  %rsi,%r14
 1277103:	4d 89 37             	mov    %r14,(%r15)
 1277106:	c5 f8 28 45 c0       	vmovaps -0x40(%rbp),%xmm0
 127710b:	c4 c1 78 11 47 10    	vmovups %xmm0,0x10(%r15)
 1277111:	66 c7 43 20 00 00    	movw   $0x0,0x20(%rbx)
 1277117:	c5 f8 10 01          	vmovups (%rcx),%xmm0
 127711b:	c5 f8 11 03          	vmovups %xmm0,(%rbx)
 127711f:	48 89 43 10          	mov    %rax,0x10(%rbx)
 1277123:	c6 43 18 01          	movb   $0x1,0x18(%rbx)
 1277127:	eb 31                	jmp    127715a <br.encoder.total_budget.Lease.init+0x1fa>
 1277129:	48 85 c9             	test   %rcx,%rcx
 127712c:	74 0a                	je     1277138 <br.encoder.total_budget.Lease.init+0x1d8>
 127712e:	48 39 48 20          	cmp    %rcx,0x20(%rax)
 1277132:	0f 85 98 fe ff ff    	jne    1276fd0 <br.encoder.total_budget.Lease.init+0x70>
 1277138:	48 89 70 40          	mov    %rsi,0x40(%rax)
 127713c:	66 c7 47 20 00 00    	movw   $0x0,0x20(%rdi)
 1277142:	c5 f8 10 00          	vmovups (%rax),%xmm0
 1277146:	c5 f8 11 07          	vmovups %xmm0,(%rdi)
 127714a:	48 89 47 10          	mov    %rax,0x10(%rdi)
 127714e:	c6 47 18 00          	movb   $0x0,0x18(%rdi)
 1277152:	eb 06                	jmp    127715a <br.encoder.total_budget.Lease.init+0x1fa>
 1277154:	66 c7 43 20 1a 00    	movw   $0x1a,0x20(%rbx)
 127715a:	48 83 c4 18          	add    $0x18,%rsp
 127715e:	5b                   	pop    %rbx
 127715f:	41 5c                	pop    %r12
 1277161:	41 5d                	pop    %r13
 1277163:	41 5e                	pop    %r14
 1277165:	41 5f                	pop    %r15
 1277167:	5d                   	pop    %rbp
 1277168:	c5 f8 77             	vzeroupper 
 127716b:	c3                   	ret    

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
