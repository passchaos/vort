
/tmp/vort-zstd-frequency-merge-20261025/micro-bench:     file format elf64-x86-64


Disassembly of section .text:

00000000010bc430 <frequency_merge_bench.query__anon_2966>:
 10bc430:	55                   	push   %rbp
 10bc431:	48 89 e5             	mov    %rsp,%rbp
 10bc434:	31 c0                	xor    %eax,%eax
 10bc436:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 10bc43d:	00 00 00 
 10bc440:	8b 8c 87 00 04 00 00 	mov    0x400(%rdi,%rax,4),%ecx
 10bc447:	03 0c 87             	add    (%rdi,%rax,4),%ecx
 10bc44a:	03 8c 87 00 08 00 00 	add    0x800(%rdi,%rax,4),%ecx
 10bc451:	03 8c 87 00 0c 00 00 	add    0xc00(%rdi,%rax,4),%ecx
 10bc458:	89 0c 86             	mov    %ecx,(%rsi,%rax,4)
 10bc45b:	8b 8c 87 04 04 00 00 	mov    0x404(%rdi,%rax,4),%ecx
 10bc462:	03 4c 87 04          	add    0x4(%rdi,%rax,4),%ecx
 10bc466:	03 8c 87 04 08 00 00 	add    0x804(%rdi,%rax,4),%ecx
 10bc46d:	03 8c 87 04 0c 00 00 	add    0xc04(%rdi,%rax,4),%ecx
 10bc474:	89 4c 86 04          	mov    %ecx,0x4(%rsi,%rax,4)
 10bc478:	8b 8c 87 08 04 00 00 	mov    0x408(%rdi,%rax,4),%ecx
 10bc47f:	03 4c 87 08          	add    0x8(%rdi,%rax,4),%ecx
 10bc483:	03 8c 87 08 08 00 00 	add    0x808(%rdi,%rax,4),%ecx
 10bc48a:	03 8c 87 08 0c 00 00 	add    0xc08(%rdi,%rax,4),%ecx
 10bc491:	89 4c 86 08          	mov    %ecx,0x8(%rsi,%rax,4)
 10bc495:	8b 8c 87 0c 04 00 00 	mov    0x40c(%rdi,%rax,4),%ecx
 10bc49c:	03 4c 87 0c          	add    0xc(%rdi,%rax,4),%ecx
 10bc4a0:	03 8c 87 0c 08 00 00 	add    0x80c(%rdi,%rax,4),%ecx
 10bc4a7:	03 8c 87 0c 0c 00 00 	add    0xc0c(%rdi,%rax,4),%ecx
 10bc4ae:	89 4c 86 0c          	mov    %ecx,0xc(%rsi,%rax,4)
 10bc4b2:	48 83 c0 04          	add    $0x4,%rax
 10bc4b6:	48 3d 00 01 00 00    	cmp    $0x100,%rax
 10bc4bc:	75 82                	jne    10bc440 <frequency_merge_bench.query__anon_2966+0x10>
 10bc4be:	31 c9                	xor    %ecx,%ecx
 10bc4c0:	31 c0                	xor    %eax,%eax
 10bc4c2:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 10bc4c9:	1f 84 00 00 00 00 00 
 10bc4d0:	83 3c 8e 01          	cmpl   $0x1,(%rsi,%rcx,4)
 10bc4d4:	48 83 d8 ff          	sbb    $0xffffffffffffffff,%rax
 10bc4d8:	83 7c 8e 04 01       	cmpl   $0x1,0x4(%rsi,%rcx,4)
 10bc4dd:	48 83 d8 ff          	sbb    $0xffffffffffffffff,%rax
 10bc4e1:	83 7c 8e 08 01       	cmpl   $0x1,0x8(%rsi,%rcx,4)
 10bc4e6:	48 83 d8 ff          	sbb    $0xffffffffffffffff,%rax
 10bc4ea:	83 7c 8e 0c 01       	cmpl   $0x1,0xc(%rsi,%rcx,4)
 10bc4ef:	48 83 d8 ff          	sbb    $0xffffffffffffffff,%rax
 10bc4f3:	83 7c 8e 10 01       	cmpl   $0x1,0x10(%rsi,%rcx,4)
 10bc4f8:	48 83 d8 ff          	sbb    $0xffffffffffffffff,%rax
 10bc4fc:	83 7c 8e 14 01       	cmpl   $0x1,0x14(%rsi,%rcx,4)
 10bc501:	48 83 d8 ff          	sbb    $0xffffffffffffffff,%rax
 10bc505:	83 7c 8e 18 01       	cmpl   $0x1,0x18(%rsi,%rcx,4)
 10bc50a:	48 83 d8 ff          	sbb    $0xffffffffffffffff,%rax
 10bc50e:	83 7c 8e 1c 01       	cmpl   $0x1,0x1c(%rsi,%rcx,4)
 10bc513:	48 83 d8 ff          	sbb    $0xffffffffffffffff,%rax
 10bc517:	48 83 c1 08          	add    $0x8,%rcx
 10bc51b:	48 81 f9 00 01 00 00 	cmp    $0x100,%rcx
 10bc522:	75 ac                	jne    10bc4d0 <frequency_merge_bench.query__anon_2966+0xa0>
 10bc524:	5d                   	pop    %rbp
 10bc525:	c3                   	ret    
