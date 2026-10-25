
/tmp/vort-zstd-single-price-20261025/micro-bench:     file format elf64-x86-64


Disassembly of section .text:

00000000010bd060 <single_cost_bench.query__anon_2965>:
 10bd060:	push   %rbp
 10bd061:	mov    %rsp,%rbp
 10bd064:	mov    (%rsi),%r9
 10bd067:	mov    0x8(%rsi),%r8
 10bd06b:	mov    0x10(%rsi),%rcx
 10bd06f:	cmp    $0x10,%r9
 10bd073:	jae    10bd07a <single_cost_bench.query__anon_2965+0x1a>
 10bd075:	mov    %r9,%rdx
 10bd078:	jmp    10bd0d6 <single_cost_bench.query__anon_2965+0x76>
 10bd07a:	cmp    $0x17,%r9
 10bd07e:	ja     10bd093 <single_cost_bench.query__anon_2965+0x33>
 10bd080:	add    $0x1f0,%r9
 10bd087:	shr    %r9
 10bd08a:	add    $0x10,%r9
 10bd08e:	mov    %r9,%rdx
 10bd091:	jmp    10bd0d6 <single_cost_bench.query__anon_2965+0x76>
 10bd093:	cmp    $0x1f,%r9
 10bd097:	ja     10bd0ad <single_cost_bench.query__anon_2965+0x4d>
 10bd099:	add    $0x3e8,%r9
 10bd0a0:	shr    $0x2,%r9
 10bd0a4:	add    $0x14,%r9
 10bd0a8:	mov    %r9,%rdx
 10bd0ab:	jmp    10bd0d6 <single_cost_bench.query__anon_2965+0x76>
 10bd0ad:	cmp    $0x2f,%r9
 10bd0b1:	ja     10bd0c7 <single_cost_bench.query__anon_2965+0x67>
 10bd0b3:	add    $0x7e0,%r9
 10bd0ba:	shr    $0x3,%r9
 10bd0be:	add    $0x16,%r9
 10bd0c2:	mov    %r9,%rdx
 10bd0c5:	jmp    10bd0d6 <single_cost_bench.query__anon_2965+0x76>
 10bd0c7:	mov    $0x18,%edx
 10bd0cc:	cmp    $0x40,%r9
 10bd0d0:	jae    10bd1a9 <single_cost_bench.query__anon_2965+0x149>
 10bd0d6:	test   %r8,%r8
 10bd0d9:	je     10bd14b <single_cost_bench.query__anon_2965+0xeb>
 10bd0db:	mov    $0x3c,%ax
 10bd0df:	cmp    $0xfffffffffffffffc,%r8
 10bd0e3:	ja     10bd234 <single_cost_bench.query__anon_2965+0x1d4>
 10bd0e9:	mov    $0xfffffffc,%esi
 10bd0ee:	cmp    %rsi,%r8
 10bd0f1:	ja     10bd234 <single_cost_bench.query__anon_2965+0x1d4>
 10bd0f7:	lea    0x3(%r8),%rsi
 10bd0fb:	lzcnt  %rsi,%rsi
 10bd100:	not    %esi
 10bd102:	mov    %esi,%r9d
 10bd105:	and    $0x3f,%r9d
 10bd109:	sub    0x1015508(,%r9,8),%r8
 10bd111:	jb     10bd234 <single_cost_bench.query__anon_2965+0x1d4>
 10bd117:	movzbl 0x1000860(%r9),%r9d
 10bd11f:	shrx   %r9,%r8,%r8
 10bd124:	test   %r8,%r8
 10bd127:	jne    10bd234 <single_cost_bench.query__anon_2965+0x1d4>
 10bd12d:	and    $0x3f,%sil
 10bd131:	cmp    $0x1f,%sil
 10bd135:	ja     10bd234 <single_cost_bench.query__anon_2965+0x1d4>
 10bd13b:	mov    $0x3c,%ax
 10bd13f:	cmp    $0x3,%rcx
 10bd143:	jb     10bd234 <single_cost_bench.query__anon_2965+0x1d4>
 10bd149:	jmp    10bd15b <single_cost_bench.query__anon_2965+0xfb>
 10bd14b:	xor    %esi,%esi
 10bd14d:	mov    $0x3c,%ax
 10bd151:	cmp    $0x3,%rcx
 10bd155:	jb     10bd234 <single_cost_bench.query__anon_2965+0x1d4>
 10bd15b:	cmp    $0x22,%rcx
 10bd15f:	ja     10bd170 <single_cost_bench.query__anon_2965+0x110>
 10bd161:	add    $0xfd,%rcx
 10bd168:	mov    %rcx,%r8
 10bd16b:	jmp    10bd22a <single_cost_bench.query__anon_2965+0x1ca>
 10bd170:	cmp    $0x2a,%rcx
 10bd174:	ja     10bd18c <single_cost_bench.query__anon_2965+0x12c>
 10bd176:	add    $0x1dd,%rcx
 10bd17d:	shr    %rcx
 10bd180:	add    $0x20,%rcx
 10bd184:	mov    %rcx,%r8
 10bd187:	jmp    10bd22a <single_cost_bench.query__anon_2965+0x1ca>
 10bd18c:	cmp    $0x32,%rcx
 10bd190:	ja     10bd1e3 <single_cost_bench.query__anon_2965+0x183>
 10bd192:	add    $0x3d5,%rcx
 10bd199:	shr    $0x2,%rcx
 10bd19d:	add    $0x24,%rcx
 10bd1a1:	mov    %rcx,%r8
 10bd1a4:	jmp    10bd22a <single_cost_bench.query__anon_2965+0x1ca>
 10bd1a9:	mov    $0x3c,%ax
 10bd1ad:	cmp    $0x1ffff,%r9
 10bd1b4:	ja     10bd234 <single_cost_bench.query__anon_2965+0x1d4>
 10bd1b6:	lzcnt  %r9,%rsi
 10bd1bb:	mov    $0x52,%edx
 10bd1c0:	sub    %rsi,%rdx
 10bd1c3:	sub    0x10157b0(,%rdx,8),%r9
 10bd1cb:	jb     10bd234 <single_cost_bench.query__anon_2965+0x1d4>
 10bd1cd:	movzbl 0x1014be0(%rdx),%esi
 10bd1d4:	shrx   %rsi,%r9,%rsi
 10bd1d9:	test   %rsi,%rsi
 10bd1dc:	jne    10bd234 <single_cost_bench.query__anon_2965+0x1d4>
 10bd1de:	jmp    10bd0d6 <single_cost_bench.query__anon_2965+0x76>
 10bd1e3:	cmp    $0x42,%rcx
 10bd1e7:	ja     10bd1fd <single_cost_bench.query__anon_2965+0x19d>
 10bd1e9:	add    $0x7cd,%rcx
 10bd1f0:	shr    $0x3,%rcx
 10bd1f4:	add    $0x26,%rcx
 10bd1f8:	mov    %rcx,%r8
 10bd1fb:	jmp    10bd22a <single_cost_bench.query__anon_2965+0x1ca>
 10bd1fd:	cmp    $0x62,%rcx
 10bd201:	ja     10bd217 <single_cost_bench.query__anon_2965+0x1b7>
 10bd203:	add    $0xfbd,%rcx
 10bd20a:	shr    $0x4,%rcx
 10bd20e:	add    $0x28,%rcx
 10bd212:	mov    %rcx,%r8
 10bd215:	jmp    10bd22a <single_cost_bench.query__anon_2965+0x1ca>
 10bd217:	mov    $0x2a,%r8d
 10bd21d:	cmp    $0x83,%rcx
 10bd224:	jae    10bd2d8 <single_cost_bench.query__anon_2965+0x278>
 10bd22a:	mov    $0x3f,%ax
 10bd22e:	xor    %ecx,%ecx
 10bd230:	test   %cl,%cl
 10bd232:	je     10bd24b <single_cost_bench.query__anon_2965+0x1eb>
 10bd234:	mov    %r9,(%rdi)
 10bd237:	mov    %ax,0x8(%rdi)
 10bd23b:	mov    -0x8(%rbp),%eax
 10bd23e:	mov    %eax,0xa(%rdi)
 10bd241:	movzwl -0x4(%rbp),%eax
 10bd245:	mov    %ax,0xe(%rdi)
 10bd249:	pop    %rbp
 10bd24a:	ret    
 10bd24b:	movzbl %dl,%r10d
 10bd24f:	movzbl 0x1014be0(%r10),%ecx
 10bd257:	movzbl %sil,%edx
 10bd25b:	movzbl 0x1000860(%rdx),%r9d
 10bd263:	add    %rcx,%r9
 10bd266:	movzbl %r8b,%esi
 10bd26a:	movzbl 0x1014c04(%rsi),%ecx
 10bd271:	add    %r9,%rcx
 10bd274:	mov    %ecx,%r9d
 10bd277:	shr    $0x3,%r9d
 10bd27b:	add    $0x6,%r9
 10bd27f:	cmpq   $0x0,0x1015140(,%r10,8)
 10bd288:	je     10bd2d1 <single_cost_bench.query__anon_2965+0x271>
 10bd28a:	cmpq   $0x0,0x1015260(,%rdx,8)
 10bd293:	je     10bd2d1 <single_cost_bench.query__anon_2965+0x271>
 10bd295:	cmpq   $0x0,0x1015360(,%rsi,8)
 10bd29e:	je     10bd2d1 <single_cost_bench.query__anon_2965+0x271>
 10bd2a0:	xor    %edx,%edx
 10bd2a2:	test   %dl,%dl
 10bd2a4:	jne    10bd234 <single_cost_bench.query__anon_2965+0x1d4>
 10bd2a6:	add    $0x19,%ecx
 10bd2a9:	shr    $0x3,%ecx
 10bd2ac:	add    $0x2,%rcx
 10bd2b0:	cmp    %r9,%rcx
 10bd2b3:	cmovb  %rcx,%r9
 10bd2b7:	lea    -0x18(%rbp),%rax
 10bd2bb:	lea    -0x28(%rbp),%rcx
 10bd2bf:	cmovb  %rax,%rcx
 10bd2c3:	movzwl 0xe(%rcx),%eax
 10bd2c7:	mov    %ax,-0x4(%rbp)
 10bd2cb:	mov    0xa(%rcx),%eax
 10bd2ce:	mov    %eax,-0x8(%rbp)
 10bd2d1:	xor    %eax,%eax
 10bd2d3:	jmp    10bd234 <single_cost_bench.query__anon_2965+0x1d4>
 10bd2d8:	lea    -0x3(%rcx),%r8
 10bd2dc:	cmp    $0x1ffff,%r8
 10bd2e3:	ja     10bd234 <single_cost_bench.query__anon_2965+0x1d4>
 10bd2e9:	lzcnt  %r8,%r9
 10bd2ee:	mov    $0x63,%r8d
 10bd2f4:	sub    %r9,%r8
 10bd2f7:	sub    0x1015608(,%r8,8),%rcx
 10bd2ff:	jb     10bd234 <single_cost_bench.query__anon_2965+0x1d4>
 10bd305:	movzbl 0x1014c04(%r8),%r9d
 10bd30d:	shrx   %r9,%rcx,%rcx
 10bd312:	test   %rcx,%rcx
 10bd315:	jne    10bd234 <single_cost_bench.query__anon_2965+0x1d4>
 10bd31b:	jmp    10bd22a <single_cost_bench.query__anon_2965+0x1ca>
