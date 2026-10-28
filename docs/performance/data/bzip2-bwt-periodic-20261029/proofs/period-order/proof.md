# Exact periodic BWT expansion for the stable doubling implementation

Theorem. Let x be a nonempty byte string of length n with least exact whole-string period p, p|n, and x=b^r for a primitive base b of length p and r=n/p. Let h=ceil(log2(n)), S=2^h-1 (S=0 when n=1). Let the base BWT be obtained by lexicographically sorting its p distinct cyclic rotations. Then the old full-doubling transform equals each byte of BWT(b) repeated r times, and

    original_pointer(x) = original_pointer(b) * r + (floor(S/p) mod r).

For p<n this also equals the current unique-class-stop implementation, because its class count is at most p<n at every stage, so it executes all h rounds. A primitive base has no rotation ties: its full-doubling transform, its early-stop transform and the naive rotation sort have the same order and original pointer.

1. Sorting invariant. Initially, stable byte counting sorts cyclic prefixes of length1 and orders equal bytes by increasing original index. Suppose order sorts cyclic prefixes of length L. After shifting every index by -L modulo n, the resulting list is sorted by the second class class[(index+L) mod n]. A stable counting sort by the first class therefore orders pairs lexicographically and constructs the classes for prefixes of length2L. When L>=n, comparison of the first n bytes determines every complete rotation. This reasoning does not require n to be a power of two.

2. Tie invariant. Consider any two indexes whose complete cyclic rotations are identical, whether or not the current prefix classes have already separated different primitive rotations. Their relative order after processed shifts summing to T is increasing (index+T) mod n. This holds initially with T=0. In a round with shift L, an output index i comes from previous index (i+L) mod n. Those previous indexes also have identical complete rotations, so induction orders them by (i+L+T) mod n. Their current first classes are equal, and the counting sort is stable, so their relative order is unchanged. The new invariant has T'=T+L. Distinct indexes have distinct modular keys. After all h rounds, T=S.

3. Equivalence classes and transformed bytes. Since b is primitive, two complete rotations of x are identical exactly when their indexes have the same residue a modulo p. The equivalence classes follow the lexicographic order of b's distinct rotations. The preceding character of every member a+kp is b[(a-1) mod p], so each base BWT byte expands to r adjacent copies. The expansion is per byte, not r copies of the entire BWT sequence.

4. Pointer rank. The class containing original index0 is the class for residue0, at base row original_pointer(b). Write S=qp+s with 0<=s<p. For class indexes kp, the sorting keys are ((k+q) mod r)*p+s. Index0 therefore has within-class rank q mod r, proving the formula. The offset uses the full input's S, not the primitive base's doubling sum.

5. Full order, including other residues. For residue a, define q_a=floor((S+a)/p). Its exact ordered indexes are

    a + p*((j-q_a) mod r), j=0..r-1.

The possible carry in S+a matters for nonzero residues. Applying one shared q=floor(S/p) to every residue would not in general recover the full order, although the pointer formula uses residue0 and is unchanged.

6. Period definition. A prefix/KMP period which does not divide n is not sufficient. Compute candidate=n-prefix_function[n-1], and accept it only when n mod candidate=0; otherwise p=n. Equivalently, a naive oracle checks divisors p and x[i]=x[i mod p]. In particular, ababa has a prefix period2 but least whole-string period5, so it must not use a p=2 expansion.

Examples: aaaaa has n5,p1,r5,S7 and pointer2. For ba repeated5 times, the naive base pointer is1, n10,S15, and the full pointer is1*5+(7 mod5)=7. For baa repeated3 times, the base pointer is2, n9,S15 and full pointer is2*3+(5 mod3)=8. At power-of-two n, S=n-1 and the within-original-class offset is r-1.

Bounds. For Bzip2 n<=900000, h<=20 and S<=1048575; the pointer is at most n-1. The proof covers this bound mathematically. The executed Python fixture sizes are much smaller and do not constitute a measured 900000-byte test or a production implementation.

Executed validation. The independent Python model uses literal stable counting sorts and class-pair reconstruction, without an early stop. Its period is independently checked by naive divisor enumeration and KMP; its base BWT uses naive complete rotation sorting. Every input checks bytes, pointer and the complete predicted order. Properly periodic inputs also check the modular tie invariant after every doubling stage. Exhaustive three-byte alphabet strings at lengths1..10 contain88572 inputs, including411 properly periodic strings. Additional49 periodic fixtures include non-power-of-two lengths, bases with nonzero original pointers and primitive periods through513; five non-integral-period/primitive controls complete88626 cases. See results.json and audit.json for exact counts and identities.

No worktree source, test, tool or documentation files were changed, and no compiler, codec benchmark or whole-repository test was started. The only executed model command was pinned to CPU4.
