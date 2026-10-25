
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

0000000001277170 <br.encoder.quality_profile.Scope.finish>:
 1277170:	55                   	push   %rbp
 1277171:	48 89 e5             	mov    %rsp,%rbp
 1277174:	41 57                	push   %r15
 1277176:	41 56                	push   %r14
 1277178:	41 54                	push   %r12
 127717a:	53                   	push   %rbx
 127717b:	48 83 ec 20          	sub    $0x20,%rsp
 127717f:	48 89 fb             	mov    %rdi,%rbx
 1277182:	4c 8b 77 20          	mov    0x20(%rdi),%r14
 1277186:	4c 8b 3f             	mov    (%rdi),%r15
 1277189:	4c 8b 67 08          	mov    0x8(%rdi),%r12
 127718d:	48 8b 77 10          	mov    0x10(%rdi),%rsi
 1277191:	48 8b 47 18          	mov    0x18(%rdi),%rax
 1277195:	48 8d 7d d0          	lea    -0x30(%rbp),%rdi
 1277199:	ba 01 00 00 00       	mov    $0x1,%edx
 127719e:	ff 90 c0 02 00 00    	call   *0x2c0(%rax)
 12771a4:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 12771a8:	48 8b 4d d8          	mov    -0x28(%rbp),%rcx
 12771ac:	4c 29 f8             	sub    %r15,%rax
 12771af:	4c 19 e1             	sbb    %r12,%rcx
 12771b2:	48 63 d1             	movslq %ecx,%rdx
 12771b5:	48 85 d2             	test   %rdx,%rdx
 12771b8:	78 41                	js     12771fb <br.encoder.quality_profile.Scope.finish+0x8b>
 12771ba:	48 c1 e1 20          	shl    $0x20,%rcx
 12771be:	74 0f                	je     12771cf <br.encoder.quality_profile.Scope.finish+0x5f>
 12771c0:	41 c6 86 d2 42 02 00 	movb   $0x0,0x242d2(%r14)
 12771c7:	00 
 12771c8:	48 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%rax
 12771cf:	80 7b 48 00          	cmpb   $0x0,0x48(%rbx)
 12771d3:	74 36                	je     127720b <br.encoder.quality_profile.Scope.finish+0x9b>
 12771d5:	48 8b 4b 40          	mov    0x40(%rbx),%rcx
 12771d9:	48 c1 e1 04          	shl    $0x4,%rcx
 12771dd:	49 8b 94 0e d0 30 02 	mov    0x230d0(%r14,%rcx,1),%rdx
 12771e4:	00 
 12771e5:	49 ff 8e c8 32 02 00 	decq   0x232c8(%r14)
 12771ec:	48 39 c2             	cmp    %rax,%rdx
 12771ef:	76 1c                	jbe    127720d <br.encoder.quality_profile.Scope.finish+0x9d>
 12771f1:	41 c6 86 d2 42 02 00 	movb   $0x0,0x242d2(%r14)
 12771f8:	00 
 12771f9:	eb 12                	jmp    127720d <br.encoder.quality_profile.Scope.finish+0x9d>
 12771fb:	41 c6 86 d2 42 02 00 	movb   $0x0,0x242d2(%r14)
 1277202:	00 
 1277203:	31 c0                	xor    %eax,%eax
 1277205:	80 7b 48 00          	cmpb   $0x0,0x48(%rbx)
 1277209:	75 ca                	jne    12771d5 <br.encoder.quality_profile.Scope.finish+0x65>
 127720b:	31 d2                	xor    %edx,%edx
 127720d:	31 c9                	xor    %ecx,%ecx
 127720f:	48 89 c6             	mov    %rax,%rsi
 1277212:	48 29 d6             	sub    %rdx,%rsi
 1277215:	48 0f 43 ce          	cmovae %rsi,%rcx
 1277219:	80 7b 38 00          	cmpb   $0x0,0x38(%rbx)
 127721d:	74 12                	je     1277231 <br.encoder.quality_profile.Scope.finish+0xc1>
 127721f:	48 69 53 30 18 01 00 	imul   $0x118,0x30(%rbx),%rdx
 1277226:	00 
 1277227:	49 89 44 16 38       	mov    %rax,0x38(%r14,%rdx,1)
 127722c:	49 89 4c 16 40       	mov    %rcx,0x40(%r14,%rdx,1)
 1277231:	49 8b 96 c8 32 02 00 	mov    0x232c8(%r14),%rdx
 1277238:	48 85 d2             	test   %rdx,%rdx
 127723b:	74 3a                	je     1277277 <br.encoder.quality_profile.Scope.finish+0x107>
 127723d:	48 c1 e2 04          	shl    $0x4,%rdx
 1277241:	49 8b b4 16 c0 30 02 	mov    0x230c0(%r14,%rdx,1),%rsi
 1277248:	00 
 1277249:	48 01 c6             	add    %rax,%rsi
 127724c:	0f 92 45 d0          	setb   -0x30(%rbp)
 1277250:	73 33                	jae    1277285 <br.encoder.quality_profile.Scope.finish+0x115>
 1277252:	41 c6 86 d2 42 02 00 	movb   $0x0,0x242d2(%r14)
 1277259:	00 
 127725a:	48 c7 c6 ff ff ff ff 	mov    $0xffffffffffffffff,%rsi
 1277261:	49 89 b4 16 c0 30 02 	mov    %rsi,0x230c0(%r14,%rdx,1)
 1277268:	00 
 1277269:	0f b6 53 50          	movzbl 0x50(%rbx),%edx
 127726d:	83 e2 0f             	and    $0xf,%edx
 1277270:	ff 24 d5 60 0e 01 01 	jmp    *0x1010e60(,%rdx,8)
 1277277:	0f b6 53 50          	movzbl 0x50(%rbx),%edx
 127727b:	83 e2 0f             	and    $0xf,%edx
 127727e:	ff 24 d5 60 0e 01 01 	jmp    *0x1010e60(,%rdx,8)
 1277285:	49 89 b4 16 c0 30 02 	mov    %rsi,0x230c0(%r14,%rdx,1)
 127728c:	00 
 127728d:	0f b6 53 50          	movzbl 0x50(%rbx),%edx
 1277291:	83 e2 0f             	and    $0xf,%edx
 1277294:	ff 24 d5 60 0e 01 01 	jmp    *0x1010e60(,%rdx,8)
 127729b:	49 89 86 38 30 02 00 	mov    %rax,0x23038(%r14)
 12772a2:	31 c9                	xor    %ecx,%ecx
 12772a4:	84 c9                	test   %cl,%cl
 12772a6:	0f 85 94 00 00 00    	jne    1277340 <br.encoder.quality_profile.Scope.finish+0x1d0>
 12772ac:	49 8b 8e 48 30 02 00 	mov    0x23048(%r14),%rcx
 12772b3:	49 8b 9e 50 30 02 00 	mov    0x23050(%r14),%rbx
 12772ba:	4d 8b 9e 58 30 02 00 	mov    0x23058(%r14),%r11
 12772c1:	4d 8b 96 60 30 02 00 	mov    0x23060(%r14),%r10
 12772c8:	4d 8b 8e 68 30 02 00 	mov    0x23068(%r14),%r9
 12772cf:	4d 8b 86 70 30 02 00 	mov    0x23070(%r14),%r8
 12772d6:	49 8b be 78 30 02 00 	mov    0x23078(%r14),%rdi
 12772dd:	49 8b b6 80 30 02 00 	mov    0x23080(%r14),%rsi
 12772e4:	49 8b 96 88 30 02 00 	mov    0x23088(%r14),%rdx
 12772eb:	49 03 8e 40 30 02 00 	add    0x23040(%r14),%rcx
 12772f2:	0f 92 45 d0          	setb   -0x30(%rbp)
 12772f6:	72 48                	jb     1277340 <br.encoder.quality_profile.Scope.finish+0x1d0>
 12772f8:	48 01 d9             	add    %rbx,%rcx
 12772fb:	0f 92 45 d0          	setb   -0x30(%rbp)
 12772ff:	72 3f                	jb     1277340 <br.encoder.quality_profile.Scope.finish+0x1d0>
 1277301:	4c 01 d9             	add    %r11,%rcx
 1277304:	0f 92 45 d0          	setb   -0x30(%rbp)
 1277308:	72 36                	jb     1277340 <br.encoder.quality_profile.Scope.finish+0x1d0>
 127730a:	4c 01 d1             	add    %r10,%rcx
 127730d:	0f 92 45 d0          	setb   -0x30(%rbp)
 1277311:	72 2d                	jb     1277340 <br.encoder.quality_profile.Scope.finish+0x1d0>
 1277313:	4c 01 c9             	add    %r9,%rcx
 1277316:	0f 92 45 d0          	setb   -0x30(%rbp)
 127731a:	72 24                	jb     1277340 <br.encoder.quality_profile.Scope.finish+0x1d0>
 127731c:	4c 01 c1             	add    %r8,%rcx
 127731f:	0f 92 45 d0          	setb   -0x30(%rbp)
 1277323:	72 1b                	jb     1277340 <br.encoder.quality_profile.Scope.finish+0x1d0>
 1277325:	48 01 f9             	add    %rdi,%rcx
 1277328:	0f 92 45 d0          	setb   -0x30(%rbp)
 127732c:	72 12                	jb     1277340 <br.encoder.quality_profile.Scope.finish+0x1d0>
 127732e:	48 01 f1             	add    %rsi,%rcx
 1277331:	0f 92 45 d0          	setb   -0x30(%rbp)
 1277335:	72 09                	jb     1277340 <br.encoder.quality_profile.Scope.finish+0x1d0>
 1277337:	48 01 d1             	add    %rdx,%rcx
 127733a:	0f 92 45 d0          	setb   -0x30(%rbp)
 127733e:	73 0f                	jae    127734f <br.encoder.quality_profile.Scope.finish+0x1df>
 1277340:	41 c6 86 d2 42 02 00 	movb   $0x0,0x242d2(%r14)
 1277347:	00 
 1277348:	48 c7 c1 ff ff ff ff 	mov    $0xffffffffffffffff,%rcx
 127734f:	48 39 c1             	cmp    %rax,%rcx
 1277352:	76 08                	jbe    127735c <br.encoder.quality_profile.Scope.finish+0x1ec>
 1277354:	41 c6 86 d2 42 02 00 	movb   $0x0,0x242d2(%r14)
 127735b:	00 
 127735c:	31 d2                	xor    %edx,%edx
 127735e:	48 29 c8             	sub    %rcx,%rax
 1277361:	48 0f 43 d0          	cmovae %rax,%rdx
 1277365:	49 89 96 90 30 02 00 	mov    %rdx,0x23090(%r14)
 127736c:	e9 06 02 00 00       	jmp    1277577 <br.encoder.quality_profile.Scope.finish+0x407>
 1277371:	49 03 8e 58 30 02 00 	add    0x23058(%r14),%rcx
 1277378:	0f 92 45 d0          	setb   -0x30(%rbp)
 127737c:	0f 83 9d 01 00 00    	jae    127751f <br.encoder.quality_profile.Scope.finish+0x3af>
 1277382:	41 c6 86 d2 42 02 00 	movb   $0x0,0x242d2(%r14)
 1277389:	00 
 127738a:	48 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%rax
 1277391:	49 89 86 58 30 02 00 	mov    %rax,0x23058(%r14)
 1277398:	e9 da 01 00 00       	jmp    1277577 <br.encoder.quality_profile.Scope.finish+0x407>
 127739d:	49 03 8e 80 30 02 00 	add    0x23080(%r14),%rcx
 12773a4:	0f 92 45 d0          	setb   -0x30(%rbp)
 12773a8:	0f 83 7a 01 00 00    	jae    1277528 <br.encoder.quality_profile.Scope.finish+0x3b8>
 12773ae:	41 c6 86 d2 42 02 00 	movb   $0x0,0x242d2(%r14)
 12773b5:	00 
 12773b6:	48 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%rax
 12773bd:	49 89 86 80 30 02 00 	mov    %rax,0x23080(%r14)
 12773c4:	e9 ae 01 00 00       	jmp    1277577 <br.encoder.quality_profile.Scope.finish+0x407>
 12773c9:	49 03 8e 48 30 02 00 	add    0x23048(%r14),%rcx
 12773d0:	0f 92 45 d0          	setb   -0x30(%rbp)
 12773d4:	0f 83 57 01 00 00    	jae    1277531 <br.encoder.quality_profile.Scope.finish+0x3c1>
 12773da:	41 c6 86 d2 42 02 00 	movb   $0x0,0x242d2(%r14)
 12773e1:	00 
 12773e2:	48 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%rax
 12773e9:	49 89 86 48 30 02 00 	mov    %rax,0x23048(%r14)
 12773f0:	e9 82 01 00 00       	jmp    1277577 <br.encoder.quality_profile.Scope.finish+0x407>
 12773f5:	49 03 8e 50 30 02 00 	add    0x23050(%r14),%rcx
 12773fc:	0f 92 45 d0          	setb   -0x30(%rbp)
 1277400:	0f 83 34 01 00 00    	jae    127753a <br.encoder.quality_profile.Scope.finish+0x3ca>
 1277406:	41 c6 86 d2 42 02 00 	movb   $0x0,0x242d2(%r14)
 127740d:	00 
 127740e:	48 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%rax
 1277415:	49 89 86 50 30 02 00 	mov    %rax,0x23050(%r14)
 127741c:	e9 56 01 00 00       	jmp    1277577 <br.encoder.quality_profile.Scope.finish+0x407>
 1277421:	49 03 8e 70 30 02 00 	add    0x23070(%r14),%rcx
 1277428:	0f 92 45 d0          	setb   -0x30(%rbp)
 127742c:	0f 83 11 01 00 00    	jae    1277543 <br.encoder.quality_profile.Scope.finish+0x3d3>
 1277432:	41 c6 86 d2 42 02 00 	movb   $0x0,0x242d2(%r14)
 1277439:	00 
 127743a:	48 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%rax
 1277441:	49 89 86 70 30 02 00 	mov    %rax,0x23070(%r14)
 1277448:	e9 2a 01 00 00       	jmp    1277577 <br.encoder.quality_profile.Scope.finish+0x407>
 127744d:	49 03 8e 40 30 02 00 	add    0x23040(%r14),%rcx
 1277454:	0f 92 45 d0          	setb   -0x30(%rbp)
 1277458:	0f 83 ee 00 00 00    	jae    127754c <br.encoder.quality_profile.Scope.finish+0x3dc>
 127745e:	41 c6 86 d2 42 02 00 	movb   $0x0,0x242d2(%r14)
 1277465:	00 
 1277466:	48 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%rax
 127746d:	49 89 86 40 30 02 00 	mov    %rax,0x23040(%r14)
 1277474:	e9 fe 00 00 00       	jmp    1277577 <br.encoder.quality_profile.Scope.finish+0x407>
 1277479:	49 03 8e 60 30 02 00 	add    0x23060(%r14),%rcx
 1277480:	0f 92 45 d0          	setb   -0x30(%rbp)
 1277484:	0f 83 cb 00 00 00    	jae    1277555 <br.encoder.quality_profile.Scope.finish+0x3e5>
 127748a:	41 c6 86 d2 42 02 00 	movb   $0x0,0x242d2(%r14)
 1277491:	00 
 1277492:	48 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%rax
 1277499:	49 89 86 60 30 02 00 	mov    %rax,0x23060(%r14)
 12774a0:	e9 d2 00 00 00       	jmp    1277577 <br.encoder.quality_profile.Scope.finish+0x407>
 12774a5:	49 03 8e 68 30 02 00 	add    0x23068(%r14),%rcx
 12774ac:	0f 92 45 d0          	setb   -0x30(%rbp)
 12774b0:	0f 83 a8 00 00 00    	jae    127755e <br.encoder.quality_profile.Scope.finish+0x3ee>
 12774b6:	41 c6 86 d2 42 02 00 	movb   $0x0,0x242d2(%r14)
 12774bd:	00 
 12774be:	48 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%rax
 12774c5:	49 89 86 68 30 02 00 	mov    %rax,0x23068(%r14)
 12774cc:	e9 a6 00 00 00       	jmp    1277577 <br.encoder.quality_profile.Scope.finish+0x407>
 12774d1:	49 03 8e 88 30 02 00 	add    0x23088(%r14),%rcx
 12774d8:	0f 92 45 d0          	setb   -0x30(%rbp)
 12774dc:	0f 83 85 00 00 00    	jae    1277567 <br.encoder.quality_profile.Scope.finish+0x3f7>
 12774e2:	41 c6 86 d2 42 02 00 	movb   $0x0,0x242d2(%r14)
 12774e9:	00 
 12774ea:	48 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%rax
 12774f1:	49 89 86 88 30 02 00 	mov    %rax,0x23088(%r14)
 12774f8:	eb 7d                	jmp    1277577 <br.encoder.quality_profile.Scope.finish+0x407>
 12774fa:	49 03 8e 78 30 02 00 	add    0x23078(%r14),%rcx
 1277501:	0f 92 45 d0          	setb   -0x30(%rbp)
 1277505:	73 69                	jae    1277570 <br.encoder.quality_profile.Scope.finish+0x400>
 1277507:	41 c6 86 d2 42 02 00 	movb   $0x0,0x242d2(%r14)
 127750e:	00 
 127750f:	48 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%rax
 1277516:	49 89 86 78 30 02 00 	mov    %rax,0x23078(%r14)
 127751d:	eb 58                	jmp    1277577 <br.encoder.quality_profile.Scope.finish+0x407>
 127751f:	49 89 8e 58 30 02 00 	mov    %rcx,0x23058(%r14)
 1277526:	eb 4f                	jmp    1277577 <br.encoder.quality_profile.Scope.finish+0x407>
 1277528:	49 89 8e 80 30 02 00 	mov    %rcx,0x23080(%r14)
 127752f:	eb 46                	jmp    1277577 <br.encoder.quality_profile.Scope.finish+0x407>
 1277531:	49 89 8e 48 30 02 00 	mov    %rcx,0x23048(%r14)
 1277538:	eb 3d                	jmp    1277577 <br.encoder.quality_profile.Scope.finish+0x407>
 127753a:	49 89 8e 50 30 02 00 	mov    %rcx,0x23050(%r14)
 1277541:	eb 34                	jmp    1277577 <br.encoder.quality_profile.Scope.finish+0x407>
 1277543:	49 89 8e 70 30 02 00 	mov    %rcx,0x23070(%r14)
 127754a:	eb 2b                	jmp    1277577 <br.encoder.quality_profile.Scope.finish+0x407>
 127754c:	49 89 8e 40 30 02 00 	mov    %rcx,0x23040(%r14)
 1277553:	eb 22                	jmp    1277577 <br.encoder.quality_profile.Scope.finish+0x407>
 1277555:	49 89 8e 60 30 02 00 	mov    %rcx,0x23060(%r14)
 127755c:	eb 19                	jmp    1277577 <br.encoder.quality_profile.Scope.finish+0x407>
 127755e:	49 89 8e 68 30 02 00 	mov    %rcx,0x23068(%r14)
 1277565:	eb 10                	jmp    1277577 <br.encoder.quality_profile.Scope.finish+0x407>
 1277567:	49 89 8e 88 30 02 00 	mov    %rcx,0x23088(%r14)
 127756e:	eb 07                	jmp    1277577 <br.encoder.quality_profile.Scope.finish+0x407>
 1277570:	49 89 8e 78 30 02 00 	mov    %rcx,0x23078(%r14)
 1277577:	48 83 c4 20          	add    $0x20,%rsp
 127757b:	5b                   	pop    %rbx
 127757c:	41 5c                	pop    %r12
 127757e:	41 5e                	pop    %r14
 1277580:	41 5f                	pop    %r15
 1277582:	5d                   	pop    %rbp
 1277583:	c3                   	ret    

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
