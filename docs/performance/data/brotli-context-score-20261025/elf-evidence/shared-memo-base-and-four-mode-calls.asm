 120f40e:	4c 8d bd 68 f1 fd ff 	lea    -0x20e98(%rbp),%r15
 120f415:	ba b0 09 02 00       	mov    $0x209b0,%edx
 120f41a:	4c 89 ff             	mov    %r15,%rdi
 120f41d:	31 f6                	xor    %esi,%esi
 120f41f:	e8 dc 69 08 00       	call   1295e00 <compiler_rt.memset>
 120f424:	48 8d bd 08 fd ff ff 	lea    -0x2f8(%rbp),%rdi
 120f42b:	4c 8d ad 1e fb ff ff 	lea    -0x4e2(%rbp),%r13
 120f432:	4c 89 f6             	mov    %r14,%rsi
 120f435:	4c 89 ea             	mov    %r13,%rdx
 120f438:	4c 89 f9             	mov    %r15,%rcx
 120f43b:	e8 30 d2 ff ff       	call   120c670 <br.encoder.literal_context_split.treeBitCostCached__anon_46145>

 120f4ac:	4d 8b 04 24          	mov    (%r12),%r8
 120f4b0:	48 8d bd 18 fd ff ff 	lea    -0x2e8(%rbp),%rdi
 120f4b7:	31 f6                	xor    %esi,%esi
 120f4b9:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 120f4bd:	4c 89 f1             	mov    %r14,%rcx
 120f4c0:	4c 89 8d 70 ff ff ff 	mov    %r9,-0x90(%rbp)
 120f4c7:	41 57                	push   %r15
 120f4c9:	41 55                	push   %r13
 120f4cb:	c5 f8 77             	vzeroupper 
 120f4ce:	e8 dd dc ff ff       	call   120d1b0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230>
 120f4d3:	48 83 c4 10          	add    $0x10,%rsp

 120f637:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 120f63b:	4c 8b 00             	mov    (%rax),%r8
 120f63e:	48 8d bd 18 fd ff ff 	lea    -0x2e8(%rbp),%rdi
 120f645:	be 01 00 00 00       	mov    $0x1,%esi
 120f64a:	48 8b 95 18 ff ff ff 	mov    -0xe8(%rbp),%rdx
 120f651:	48 8b 8d 40 ff ff ff 	mov    -0xc0(%rbp),%rcx
 120f658:	4c 8b 8d 70 ff ff ff 	mov    -0x90(%rbp),%r9
 120f65f:	48 8d 85 68 f1 fd ff 	lea    -0x20e98(%rbp),%rax
 120f666:	50                   	push   %rax
 120f667:	48 8d 85 1e fb ff ff 	lea    -0x4e2(%rbp),%rax
 120f66e:	50                   	push   %rax
 120f66f:	c5 f8 77             	vzeroupper 
 120f672:	e8 39 db ff ff       	call   120d1b0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230>
 120f677:	48 83 c4 10          	add    $0x10,%rsp

 120f87e:	4d 8b 02             	mov    (%r10),%r8
 120f881:	48 8d bd 18 fd ff ff 	lea    -0x2e8(%rbp),%rdi
 120f888:	be 02 00 00 00       	mov    $0x2,%esi
 120f88d:	48 8b 95 20 ff ff ff 	mov    -0xe0(%rbp),%rdx
 120f894:	48 8b 8d 40 ff ff ff 	mov    -0xc0(%rbp),%rcx
 120f89b:	4c 8b 8d 70 ff ff ff 	mov    -0x90(%rbp),%r9
 120f8a2:	48 8d 85 68 f1 fd ff 	lea    -0x20e98(%rbp),%rax
 120f8a9:	50                   	push   %rax
 120f8aa:	48 8d 85 1e fb ff ff 	lea    -0x4e2(%rbp),%rax
 120f8b1:	50                   	push   %rax
 120f8b2:	c5 f8 77             	vzeroupper 
 120f8b5:	e8 f6 d8 ff ff       	call   120d1b0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230>
 120f8ba:	48 83 c4 10          	add    $0x10,%rsp

 120fa7e:	4d 8b 01             	mov    (%r9),%r8
 120fa81:	48 8d bd 18 fd ff ff 	lea    -0x2e8(%rbp),%rdi
 120fa88:	be 03 00 00 00       	mov    $0x3,%esi
 120fa8d:	48 8b 95 28 ff ff ff 	mov    -0xd8(%rbp),%rdx
 120fa94:	48 8b 8d 40 ff ff ff 	mov    -0xc0(%rbp),%rcx
 120fa9b:	4c 8b 8d 70 ff ff ff 	mov    -0x90(%rbp),%r9
 120faa2:	48 8d 85 68 f1 fd ff 	lea    -0x20e98(%rbp),%rax
 120faa9:	50                   	push   %rax
 120faaa:	48 8d 85 1e fb ff ff 	lea    -0x4e2(%rbp),%rax
 120fab1:	50                   	push   %rax
 120fab2:	c5 f8 77             	vzeroupper 
 120fab5:	e8 f6 d6 ff ff       	call   120d1b0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230>
 120faba:	48 83 c4 10          	add    $0x10,%rsp
