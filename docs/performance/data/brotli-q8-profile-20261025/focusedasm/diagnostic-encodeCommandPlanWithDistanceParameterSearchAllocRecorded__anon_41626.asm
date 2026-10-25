
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

000000000122fdf0 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_41626>:
 122fdf0:	55                   	push   %rbp
 122fdf1:	48 89 e5             	mov    %rsp,%rbp
 122fdf4:	41 57                	push   %r15
 122fdf6:	41 56                	push   %r14
 122fdf8:	41 55                	push   %r13
 122fdfa:	41 54                	push   %r12
 122fdfc:	53                   	push   %rbx
 122fdfd:	48 81 ec 68 04 00 00 	sub    $0x468,%rsp
 122fe04:	4c 8b 7d 20          	mov    0x20(%rbp),%r15
 122fe08:	41 f6 87 1a 02 00 00 	testb  $0x3,0x21a(%r15)
 122fe0f:	03 
 122fe10:	0f 85 d7 02 00 00    	jne    12300ed <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_41626+0x2fd>
 122fe16:	41 0f b6 87 1b 02 00 	movzbl 0x21b(%r15),%eax
 122fe1d:	00 
 122fe1e:	24 0f                	and    $0xf,%al
 122fe20:	0f 85 c7 02 00 00    	jne    12300ed <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_41626+0x2fd>
 122fe26:	41 f6 87 25 02 00 00 	testb  $0x1,0x225(%r15)
 122fe2d:	01 
 122fe2e:	0f 84 b9 02 00 00    	je     12300ed <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_41626+0x2fd>
 122fe34:	41 80 bf f8 01 00 00 	cmpb   $0x0,0x1f8(%r15)
 122fe3b:	00 
 122fe3c:	0f 85 ab 02 00 00    	jne    12300ed <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_41626+0x2fd>
 122fe42:	49 83 bf 00 02 00 00 	cmpq   $0x0,0x200(%r15)
 122fe49:	00 
 122fe4a:	0f 85 9d 02 00 00    	jne    12300ed <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_41626+0x2fd>
 122fe50:	48 89 7d c8          	mov    %rdi,-0x38(%rbp)
 122fe54:	4c 8b 65 18          	mov    0x18(%rbp),%r12
 122fe58:	f6 45 10 01          	testb  $0x1,0x10(%rbp)
 122fe5c:	0f 84 b4 02 00 00    	je     1230116 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_41626+0x326>
 122fe62:	c4 c1 7c 10 44 24 70 	vmovups 0x70(%r12),%ymm0
 122fe69:	c5 fc 11 85 10 fe ff 	vmovups %ymm0,-0x1f0(%rbp)
 122fe70:	ff 
 122fe71:	c4 c1 7c 10 04 24    	vmovups (%r12),%ymm0
 122fe77:	c4 c1 7c 10 4c 24 20 	vmovups 0x20(%r12),%ymm1
 122fe7e:	c4 c1 7c 10 54 24 40 	vmovups 0x40(%r12),%ymm2
 122fe85:	c4 c1 7c 10 5c 24 60 	vmovups 0x60(%r12),%ymm3
 122fe8c:	c5 fc 11 9d 00 fe ff 	vmovups %ymm3,-0x200(%rbp)
 122fe93:	ff 
 122fe94:	c5 fc 11 95 e0 fd ff 	vmovups %ymm2,-0x220(%rbp)
 122fe9b:	ff 
 122fe9c:	c5 fc 11 8d c0 fd ff 	vmovups %ymm1,-0x240(%rbp)
 122fea3:	ff 
 122fea4:	c5 fc 11 85 a0 fd ff 	vmovups %ymm0,-0x260(%rbp)
 122feab:	ff 
 122feac:	c4 c1 7c 10 04 24    	vmovups (%r12),%ymm0
 122feb2:	c4 c1 7c 10 4c 24 20 	vmovups 0x20(%r12),%ymm1
 122feb9:	c4 c1 7c 10 54 24 40 	vmovups 0x40(%r12),%ymm2
 122fec0:	c4 c1 7c 10 5c 24 60 	vmovups 0x60(%r12),%ymm3
 122fec7:	c5 fc 11 85 c0 fe ff 	vmovups %ymm0,-0x140(%rbp)
 122fece:	ff 
 122fecf:	c5 fc 11 8d e0 fe ff 	vmovups %ymm1,-0x120(%rbp)
 122fed6:	ff 
 122fed7:	c5 fc 11 95 00 ff ff 	vmovups %ymm2,-0x100(%rbp)
 122fede:	ff 
 122fedf:	c5 fc 11 9d 20 ff ff 	vmovups %ymm3,-0xe0(%rbp)
 122fee6:	ff 
 122fee7:	c4 c1 7c 10 44 24 70 	vmovups 0x70(%r12),%ymm0
 122feee:	c5 fc 11 85 30 ff ff 	vmovups %ymm0,-0xd0(%rbp)
 122fef5:	ff 
 122fef6:	48 8d 85 c0 fe ff ff 	lea    -0x140(%rbp),%rax
 122fefd:	48 8d 7d 80          	lea    -0x80(%rbp),%rdi
 122ff01:	48 89 75 b8          	mov    %rsi,-0x48(%rbp)
 122ff05:	48 89 55 98          	mov    %rdx,-0x68(%rbp)
 122ff09:	48 89 4d a0          	mov    %rcx,-0x60(%rbp)
 122ff0d:	4d 89 c6             	mov    %r8,%r14
 122ff10:	4d 89 cd             	mov    %r9,%r13
 122ff13:	41 57                	push   %r15
 122ff15:	50                   	push   %rax
 122ff16:	c5 f8 77             	vzeroupper 
 122ff19:	e8 02 72 f8 ff       	call   11b7120 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_30089>
 122ff1e:	48 83 c4 10          	add    $0x10,%rsp
 122ff22:	0f b7 45 90          	movzwl -0x70(%rbp),%eax
 122ff26:	66 85 c0             	test   %ax,%ax
 122ff29:	0f 85 33 03 00 00    	jne    1230262 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_41626+0x472>
 122ff2f:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 122ff33:	48 89 45 b0          	mov    %rax,-0x50(%rbp)
 122ff37:	48 8b 45 88          	mov    -0x78(%rbp),%rax
 122ff3b:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 122ff3f:	48 8d 7d aa          	lea    -0x56(%rbp),%rdi
 122ff43:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 122ff47:	4c 89 f2             	mov    %r14,%rdx
 122ff4a:	4c 89 e9             	mov    %r13,%rcx
 122ff4d:	4d 89 f8             	mov    %r15,%r8
 122ff50:	e8 7b 16 00 00       	call   12315d0 <br.chooseDistanceParameterAlternativeAlloc>
 122ff55:	0f b7 5d aa          	movzwl -0x56(%rbp),%ebx
 122ff59:	66 85 db             	test   %bx,%bx
 122ff5c:	0f 85 d0 02 00 00    	jne    1230232 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_41626+0x442>
 122ff62:	80 7d ae 00          	cmpb   $0x0,-0x52(%rbp)
 122ff66:	0f 84 db 01 00 00    	je     1230147 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_41626+0x357>
 122ff6c:	0f b7 5d ac          	movzwl -0x54(%rbp),%ebx
 122ff70:	48 8d bd 78 fb ff ff 	lea    -0x488(%rbp),%rdi
 122ff77:	ba 1a 02 00 00       	mov    $0x21a,%edx
 122ff7c:	4c 89 fe             	mov    %r15,%rsi
 122ff7f:	e8 dc f7 0a 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 122ff84:	41 0f b7 87 1c 02 00 	movzwl 0x21c(%r15),%eax
 122ff8b:	00 
 122ff8c:	66 89 85 94 fd ff ff 	mov    %ax,-0x26c(%rbp)
 122ff93:	41 0f b6 87 1e 02 00 	movzbl 0x21e(%r15),%eax
 122ff9a:	00 
 122ff9b:	88 85 96 fd ff ff    	mov    %al,-0x26a(%rbp)
 122ffa1:	49 8b 87 20 02 00 00 	mov    0x220(%r15),%rax
 122ffa8:	c6 45 d7 00          	movb   $0x0,-0x29(%rbp)
 122ffac:	c5 fc 10 85 a0 fd ff 	vmovups -0x260(%rbp),%ymm0
 122ffb3:	ff 
 122ffb4:	c5 fc 10 8d c0 fd ff 	vmovups -0x240(%rbp),%ymm1
 122ffbb:	ff 
 122ffbc:	c5 fc 10 95 e0 fd ff 	vmovups -0x220(%rbp),%ymm2
 122ffc3:	ff 
 122ffc4:	c5 fc 11 85 30 fe ff 	vmovups %ymm0,-0x1d0(%rbp)
 122ffcb:	ff 
 122ffcc:	c5 fc 11 8d 50 fe ff 	vmovups %ymm1,-0x1b0(%rbp)
 122ffd3:	ff 
 122ffd4:	c5 fc 10 85 00 fe ff 	vmovups -0x200(%rbp),%ymm0
 122ffdb:	ff 
 122ffdc:	c5 fc 11 95 70 fe ff 	vmovups %ymm2,-0x190(%rbp)
 122ffe3:	ff 
 122ffe4:	c5 fc 11 85 90 fe ff 	vmovups %ymm0,-0x170(%rbp)
 122ffeb:	ff 
 122ffec:	c5 fc 10 85 10 fe ff 	vmovups -0x1f0(%rbp),%ymm0
 122fff3:	ff 
 122fff4:	c5 fc 11 85 a0 fe ff 	vmovups %ymm0,-0x160(%rbp)
 122fffb:	ff 
 122fffc:	66 89 9d 92 fd ff ff 	mov    %bx,-0x26e(%rbp)
 1230003:	0f b6 4d d7          	movzbl -0x29(%rbp),%ecx
 1230007:	88 8d 97 fd ff ff    	mov    %cl,-0x269(%rbp)
 123000d:	48 89 85 98 fd ff ff 	mov    %rax,-0x268(%rbp)
 1230014:	48 8d 85 30 fe ff ff 	lea    -0x1d0(%rbp),%rax
 123001b:	48 8d bd 68 ff ff ff 	lea    -0x98(%rbp),%rdi
 1230022:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 1230026:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 123002a:	48 8b 4d a0          	mov    -0x60(%rbp),%rcx
 123002e:	4d 89 f0             	mov    %r14,%r8
 1230031:	4d 89 e9             	mov    %r13,%r9
 1230034:	4c 8d 95 78 fb ff ff 	lea    -0x488(%rbp),%r10
 123003b:	41 52                	push   %r10
 123003d:	50                   	push   %rax
 123003e:	c5 f8 77             	vzeroupper 
 1230041:	e8 da 70 f8 ff       	call   11b7120 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_30089>
 1230046:	48 83 c4 10          	add    $0x10,%rsp
 123004a:	0f b7 9d 78 ff ff ff 	movzwl -0x88(%rbp),%ebx
 1230051:	66 85 db             	test   %bx,%bx
 1230054:	0f 85 d8 01 00 00    	jne    1230232 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_41626+0x442>
 123005a:	4c 8b b5 68 ff ff ff 	mov    -0x98(%rbp),%r14
 1230061:	48 8b 9d 70 ff ff ff 	mov    -0x90(%rbp),%rbx
 1230068:	4c 8b 7d c0          	mov    -0x40(%rbp),%r15
 123006c:	4c 39 fb             	cmp    %r15,%rbx
 123006f:	0f 83 3a 01 00 00    	jae    12301af <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_41626+0x3bf>
 1230075:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 1230079:	48 8b 38             	mov    (%rax),%rdi
 123007c:	48 8b 40 08          	mov    0x8(%rax),%rax
 1230080:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1230084:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 1230088:	4c 89 fa             	mov    %r15,%rdx
 123008b:	31 c9                	xor    %ecx,%ecx
 123008d:	ff 50 18             	call   *0x18(%rax)
 1230090:	c5 fc 10 85 a0 fe ff 	vmovups -0x160(%rbp),%ymm0
 1230097:	ff 
 1230098:	c4 c1 7c 11 44 24 70 	vmovups %ymm0,0x70(%r12)
 123009f:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 12300a6:	ff 
 12300a7:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 12300ae:	ff 
 12300af:	c5 fc 10 95 70 fe ff 	vmovups -0x190(%rbp),%ymm2
 12300b6:	ff 
 12300b7:	c5 fc 10 9d 90 fe ff 	vmovups -0x170(%rbp),%ymm3
 12300be:	ff 
 12300bf:	c4 c1 7c 11 5c 24 60 	vmovups %ymm3,0x60(%r12)
 12300c6:	c4 c1 7c 11 54 24 40 	vmovups %ymm2,0x40(%r12)
 12300cd:	c4 c1 7c 11 4c 24 20 	vmovups %ymm1,0x20(%r12)
 12300d4:	c4 c1 7c 11 04 24    	vmovups %ymm0,(%r12)
 12300da:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 12300de:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 12300e4:	4c 89 30             	mov    %r14,(%rax)
 12300e7:	48 89 58 08          	mov    %rbx,0x8(%rax)
 12300eb:	eb 14                	jmp    1230101 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_41626+0x311>
 12300ed:	c5 f8 10 05 c3 f2 e5 	vmovups -0x1a0d3d(%rip),%xmm0        # 108f3b8 <__anon_205615>
 12300f4:	ff 
 12300f5:	c5 f8 11 07          	vmovups %xmm0,(%rdi)
 12300f9:	48 c7 47 10 52 00 00 	movq   $0x52,0x10(%rdi)
 1230100:	00 
 1230101:	48 81 c4 68 04 00 00 	add    $0x468,%rsp
 1230108:	5b                   	pop    %rbx
 1230109:	41 5c                	pop    %r12
 123010b:	41 5d                	pop    %r13
 123010d:	41 5e                	pop    %r14
 123010f:	41 5f                	pop    %r15
 1230111:	5d                   	pop    %rbp
 1230112:	c5 f8 77             	vzeroupper 
 1230115:	c3                   	ret    
 1230116:	48 8d bd 50 ff ff ff 	lea    -0xb0(%rbp),%rdi
 123011d:	41 57                	push   %r15
 123011f:	41 54                	push   %r12
 1230121:	e8 fa 6f f8 ff       	call   11b7120 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_30089>
 1230126:	48 83 c4 10          	add    $0x10,%rsp
 123012a:	48 8b 85 60 ff ff ff 	mov    -0xa0(%rbp),%rax
 1230131:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 1230135:	48 89 41 10          	mov    %rax,0x10(%rcx)
 1230139:	c5 f8 10 85 50 ff ff 	vmovups -0xb0(%rbp),%xmm0
 1230140:	ff 
 1230141:	c5 f8 11 01          	vmovups %xmm0,(%rcx)
 1230145:	eb ba                	jmp    1230101 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_41626+0x311>
 1230147:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 123014e:	ff 
 123014f:	c4 c1 7c 11 44 24 70 	vmovups %ymm0,0x70(%r12)
 1230156:	c5 fc 10 85 c0 fe ff 	vmovups -0x140(%rbp),%ymm0
 123015d:	ff 
 123015e:	c5 fc 10 8d e0 fe ff 	vmovups -0x120(%rbp),%ymm1
 1230165:	ff 
 1230166:	c5 fc 10 95 00 ff ff 	vmovups -0x100(%rbp),%ymm2
 123016d:	ff 
 123016e:	c5 fc 10 9d 20 ff ff 	vmovups -0xe0(%rbp),%ymm3
 1230175:	ff 
 1230176:	c4 c1 7c 11 5c 24 60 	vmovups %ymm3,0x60(%r12)
 123017d:	c4 c1 7c 11 54 24 40 	vmovups %ymm2,0x40(%r12)
 1230184:	c4 c1 7c 11 4c 24 20 	vmovups %ymm1,0x20(%r12)
 123018b:	c4 c1 7c 11 04 24    	vmovups %ymm0,(%r12)
 1230191:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 1230195:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 123019b:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 123019f:	48 89 08             	mov    %rcx,(%rax)
 12301a2:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 12301a6:	48 89 48 08          	mov    %rcx,0x8(%rax)
 12301aa:	e9 52 ff ff ff       	jmp    1230101 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_41626+0x311>
 12301af:	48 85 db             	test   %rbx,%rbx
 12301b2:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 12301b6:	74 16                	je     12301ce <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_41626+0x3de>
 12301b8:	48 8b 38             	mov    (%rax),%rdi
 12301bb:	48 8b 40 08          	mov    0x8(%rax),%rax
 12301bf:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12301c3:	4c 89 f6             	mov    %r14,%rsi
 12301c6:	48 89 da             	mov    %rbx,%rdx
 12301c9:	31 c9                	xor    %ecx,%ecx
 12301cb:	ff 50 18             	call   *0x18(%rax)
 12301ce:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 12301d5:	ff 
 12301d6:	c4 c1 7c 11 44 24 70 	vmovups %ymm0,0x70(%r12)
 12301dd:	c5 fc 10 85 c0 fe ff 	vmovups -0x140(%rbp),%ymm0
 12301e4:	ff 
 12301e5:	c5 fc 10 8d e0 fe ff 	vmovups -0x120(%rbp),%ymm1
 12301ec:	ff 
 12301ed:	c5 fc 10 95 00 ff ff 	vmovups -0x100(%rbp),%ymm2
 12301f4:	ff 
 12301f5:	c5 fc 10 9d 20 ff ff 	vmovups -0xe0(%rbp),%ymm3
 12301fc:	ff 
 12301fd:	c4 c1 7c 11 5c 24 60 	vmovups %ymm3,0x60(%r12)
 1230204:	c4 c1 7c 11 54 24 40 	vmovups %ymm2,0x40(%r12)
 123020b:	c4 c1 7c 11 4c 24 20 	vmovups %ymm1,0x20(%r12)
 1230212:	c4 c1 7c 11 04 24    	vmovups %ymm0,(%r12)
 1230218:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 123021c:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 1230222:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 1230226:	48 89 08             	mov    %rcx,(%rax)
 1230229:	4c 89 78 08          	mov    %r15,0x8(%rax)
 123022d:	e9 cf fe ff ff       	jmp    1230101 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_41626+0x311>
 1230232:	48 83 7d c0 00       	cmpq   $0x0,-0x40(%rbp)
 1230237:	74 1c                	je     1230255 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_41626+0x465>
 1230239:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 123023d:	48 8b 38             	mov    (%rax),%rdi
 1230240:	48 8b 40 08          	mov    0x8(%rax),%rax
 1230244:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1230248:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 123024c:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 1230250:	31 c9                	xor    %ecx,%ecx
 1230252:	ff 50 18             	call   *0x18(%rax)
 1230255:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 1230259:	66 89 58 10          	mov    %bx,0x10(%rax)
 123025d:	e9 9f fe ff ff       	jmp    1230101 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_41626+0x311>
 1230262:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 1230266:	66 89 41 10          	mov    %ax,0x10(%rcx)
 123026a:	e9 92 fe ff ff       	jmp    1230101 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_41626+0x311>

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
