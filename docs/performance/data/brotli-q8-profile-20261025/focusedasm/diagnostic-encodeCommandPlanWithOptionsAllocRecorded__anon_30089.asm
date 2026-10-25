
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

00000000011b7120 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_30089>:
 11b7120:	55                   	push   %rbp
 11b7121:	48 89 e5             	mov    %rsp,%rbp
 11b7124:	41 57                	push   %r15
 11b7126:	41 56                	push   %r14
 11b7128:	41 55                	push   %r13
 11b712a:	41 54                	push   %r12
 11b712c:	53                   	push   %rbx
 11b712d:	48 83 ec 78          	sub    $0x78,%rsp
 11b7131:	49 89 ff             	mov    %rdi,%r15
 11b7134:	48 8b 45 18          	mov    0x18(%rbp),%rax
 11b7138:	48 8b 80 08 02 00 00 	mov    0x208(%rax),%rax
 11b713f:	48 01 c8             	add    %rcx,%rax
 11b7142:	73 0c                	jae    11b7150 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_30089+0x30>
 11b7144:	66 41 c7 47 10 43 00 	movw   $0x43,0x10(%r15)
 11b714b:	e9 f4 00 00 00       	jmp    11b7244 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_30089+0x124>
 11b7150:	49 89 f2             	mov    %rsi,%r10
 11b7153:	48 89 c8             	mov    %rcx,%rax
 11b7156:	48 c1 e8 03          	shr    $0x3,%rax
 11b715a:	48 83 f8 41          	cmp    $0x41,%rax
 11b715e:	be 40 00 00 00       	mov    $0x40,%esi
 11b7163:	48 0f 43 f0          	cmovae %rax,%rsi
 11b7167:	48 81 fe 00 10 00 00 	cmp    $0x1000,%rsi
 11b716e:	41 bc 00 10 00 00    	mov    $0x1000,%r12d
 11b7174:	4c 0f 42 e6          	cmovb  %rsi,%r12
 11b7178:	31 c0                	xor    %eax,%eax
 11b717a:	84 c0                	test   %al,%al
 11b717c:	0f 85 bb 00 00 00    	jne    11b723d <br.encodeCommandPlanWithOptionsAllocRecorded__anon_30089+0x11d>
 11b7182:	49 8b 3a             	mov    (%r10),%rdi
 11b7185:	49 8b 42 08          	mov    0x8(%r10),%rax
 11b7189:	4c 8b 5d 08          	mov    0x8(%rbp),%r11
 11b718d:	4c 89 e6             	mov    %r12,%rsi
 11b7190:	48 89 55 98          	mov    %rdx,-0x68(%rbp)
 11b7194:	31 d2                	xor    %edx,%edx
 11b7196:	49 89 cd             	mov    %rcx,%r13
 11b7199:	4c 89 5d c0          	mov    %r11,-0x40(%rbp)
 11b719d:	4c 89 d9             	mov    %r11,%rcx
 11b71a0:	4c 89 cb             	mov    %r9,%rbx
 11b71a3:	4c 89 55 a0          	mov    %r10,-0x60(%rbp)
 11b71a7:	4d 89 c6             	mov    %r8,%r14
 11b71aa:	ff 10                	call   *(%rax)
 11b71ac:	4c 8b 5d 18          	mov    0x18(%rbp),%r11
 11b71b0:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 11b71b4:	4d 89 f0             	mov    %r14,%r8
 11b71b7:	4c 8b 75 a0          	mov    -0x60(%rbp),%r14
 11b71bb:	48 85 c0             	test   %rax,%rax
 11b71be:	74 7d                	je     11b723d <br.encodeCommandPlanWithOptionsAllocRecorded__anon_30089+0x11d>
 11b71c0:	49 89 d9             	mov    %rbx,%r9
 11b71c3:	4c 8b 55 10          	mov    0x10(%rbp),%r10
 11b71c7:	48 89 45 a8          	mov    %rax,-0x58(%rbp)
 11b71cb:	48 c7 45 b0 00 00 00 	movq   $0x0,-0x50(%rbp)
 11b71d2:	00 
 11b71d3:	4c 89 65 b8          	mov    %r12,-0x48(%rbp)
 11b71d7:	c6 45 d0 00          	movb   $0x0,-0x30(%rbp)
 11b71db:	c6 45 cf 00          	movb   $0x0,-0x31(%rbp)
 11b71df:	48 8d 45 a8          	lea    -0x58(%rbp),%rax
 11b71e3:	48 89 45 88          	mov    %rax,-0x78(%rbp)
 11b71e7:	66 c7 45 90 00 00    	movw   $0x0,-0x70(%rbp)
 11b71ed:	48 8d 75 88          	lea    -0x78(%rbp),%rsi
 11b71f1:	4c 89 f7             	mov    %r14,%rdi
 11b71f4:	4c 89 e9             	mov    %r13,%rcx
 11b71f7:	41 53                	push   %r11
 11b71f9:	41 52                	push   %r10
 11b71fb:	e8 40 48 00 00       	call   11bba40 <br.encodeCommandPlanWithOptionsWrite>
 11b7200:	48 83 c4 10          	add    $0x10,%rsp
 11b7204:	66 85 c0             	test   %ax,%ax
 11b7207:	75 4a                	jne    11b7253 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_30089+0x133>
 11b7209:	48 8d bd 70 ff ff ff 	lea    -0x90(%rbp),%rdi
 11b7210:	48 8d 75 a8          	lea    -0x58(%rbp),%rsi
 11b7214:	4c 89 f2             	mov    %r14,%rdx
 11b7217:	e8 74 00 00 00       	call   11b7290 <array_list.Aligned(u8,null).toOwnedSlice>
 11b721c:	44 0f b7 65 80       	movzwl -0x80(%rbp),%r12d
 11b7221:	66 45 85 e4          	test   %r12w,%r12w
 11b7225:	75 53                	jne    11b727a <br.encodeCommandPlanWithOptionsAllocRecorded__anon_30089+0x15a>
 11b7227:	c5 f8 10 85 70 ff ff 	vmovups -0x90(%rbp),%xmm0
 11b722e:	ff 
 11b722f:	66 41 c7 47 10 00 00 	movw   $0x0,0x10(%r15)
 11b7236:	c4 c1 78 11 07       	vmovups %xmm0,(%r15)
 11b723b:	eb 07                	jmp    11b7244 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_30089+0x124>
 11b723d:	66 41 c7 47 10 1a 00 	movw   $0x1a,0x10(%r15)
 11b7244:	48 83 c4 78          	add    $0x78,%rsp
 11b7248:	5b                   	pop    %rbx
 11b7249:	41 5c                	pop    %r12
 11b724b:	41 5d                	pop    %r13
 11b724d:	41 5e                	pop    %r14
 11b724f:	41 5f                	pop    %r15
 11b7251:	5d                   	pop    %rbp
 11b7252:	c3                   	ret    
 11b7253:	41 89 c4             	mov    %eax,%r12d
 11b7256:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 11b725a:	48 85 d2             	test   %rdx,%rdx
 11b725d:	74 14                	je     11b7273 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_30089+0x153>
 11b725f:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 11b7263:	49 8b 3e             	mov    (%r14),%rdi
 11b7266:	49 8b 46 08          	mov    0x8(%r14),%rax
 11b726a:	31 c9                	xor    %ecx,%ecx
 11b726c:	4c 8b 45 c0          	mov    -0x40(%rbp),%r8
 11b7270:	ff 50 18             	call   *0x18(%rax)
 11b7273:	66 45 89 67 10       	mov    %r12w,0x10(%r15)
 11b7278:	eb ca                	jmp    11b7244 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_30089+0x124>
 11b727a:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 11b727e:	48 85 d2             	test   %rdx,%rdx
 11b7281:	75 dc                	jne    11b725f <br.encodeCommandPlanWithOptionsAllocRecorded__anon_30089+0x13f>
 11b7283:	eb ee                	jmp    11b7273 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_30089+0x153>

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
