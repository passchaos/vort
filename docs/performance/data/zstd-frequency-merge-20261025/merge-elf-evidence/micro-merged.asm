
/tmp/vort-zstd-frequency-merge-20261025/micro-bench:     file format elf64-x86-64


Disassembly of section .text:

00000000010bc270 <frequency_merge_bench.query__anon_2967>:
 10bc270:	55                   	push   %rbp
 10bc271:	48 89 e5             	mov    %rsp,%rbp
 10bc274:	48 c7 c1 f8 ff ff ff 	mov    $0xfffffffffffffff8,%rcx
 10bc27b:	31 c0                	xor    %eax,%eax
 10bc27d:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 10bc281:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 10bc288:	0f 1f 84 00 00 00 00 
 10bc28f:	00 
 10bc290:	c5 fe 6f 8c 8f 20 04 	vmovdqu 0x420(%rdi,%rcx,4),%ymm1
 10bc297:	00 00 
 10bc299:	c5 f5 fe 4c 8f 20    	vpaddd 0x20(%rdi,%rcx,4),%ymm1,%ymm1
 10bc29f:	c5 f5 fe 8c 8f 20 08 	vpaddd 0x820(%rdi,%rcx,4),%ymm1,%ymm1
 10bc2a6:	00 00 
 10bc2a8:	c5 f5 fe 8c 8f 20 0c 	vpaddd 0xc20(%rdi,%rcx,4),%ymm1,%ymm1
 10bc2af:	00 00 
 10bc2b1:	c5 fe 7f 4c 8e 20    	vmovdqu %ymm1,0x20(%rsi,%rcx,4)
 10bc2b7:	c5 f5 76 c8          	vpcmpeqd %ymm0,%ymm1,%ymm1
 10bc2bb:	c5 fc 50 d1          	vmovmskps %ymm1,%edx
 10bc2bf:	81 f2 ff 00 00 00    	xor    $0xff,%edx
 10bc2c5:	f3 0f b8 d2          	popcnt %edx,%edx
 10bc2c9:	c5 fe 6f 8c 8f 40 04 	vmovdqu 0x440(%rdi,%rcx,4),%ymm1
 10bc2d0:	00 00 
 10bc2d2:	c5 f5 fe 4c 8f 40    	vpaddd 0x40(%rdi,%rcx,4),%ymm1,%ymm1
 10bc2d8:	c5 f5 fe 8c 8f 40 08 	vpaddd 0x840(%rdi,%rcx,4),%ymm1,%ymm1
 10bc2df:	00 00 
 10bc2e1:	48 01 c2             	add    %rax,%rdx
 10bc2e4:	c5 f5 fe 8c 8f 40 0c 	vpaddd 0xc40(%rdi,%rcx,4),%ymm1,%ymm1
 10bc2eb:	00 00 
 10bc2ed:	c5 fe 7f 4c 8e 40    	vmovdqu %ymm1,0x40(%rsi,%rcx,4)
 10bc2f3:	c5 f5 76 c8          	vpcmpeqd %ymm0,%ymm1,%ymm1
 10bc2f7:	c5 fc 50 c1          	vmovmskps %ymm1,%eax
 10bc2fb:	35 ff 00 00 00       	xor    $0xff,%eax
 10bc300:	f3 0f b8 c0          	popcnt %eax,%eax
 10bc304:	48 01 d0             	add    %rdx,%rax
 10bc307:	48 83 c1 10          	add    $0x10,%rcx
 10bc30b:	48 81 f9 f8 00 00 00 	cmp    $0xf8,%rcx
 10bc312:	0f 82 78 ff ff ff    	jb     10bc290 <frequency_merge_bench.query__anon_2967+0x20>
 10bc318:	5d                   	pop    %rbp
 10bc319:	c5 f8 77             	vzeroupper 
 10bc31c:	c3                   	ret    
