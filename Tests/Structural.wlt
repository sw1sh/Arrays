(* Tests for Wolfram/Arrays structural operations: ArrayTranspose, ArrayContract,
   ArrayPart, SimplifyArray, ArrayName, ArrayMap, ArrayReplaceAll, ArrayConjugate,
   ArrayAllZeroQ, plus the container-preservation contract they all share.
   Run via Tests/RunTests.wls or TestReport. *)

Needs["Wolfram`Arrays`"]

(* === fixtures === *)

$sparse = SparseArray[{{0, 1}, {2, 0}}]
$dense = Normal[$sparse]
$packed = Developer`ToPackedArray[N[{{1, 2}, {3, 4}}]]
$packedComplex = Developer`ToPackedArray[{1. + 2. I, 3. - 1. I}]
$numeric = NumericArray[{{1., 0.}, {0., 2.}}]

$if = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}]
$lazy = $if[tau]

(* A matrix-valued single-coordinate interpolant, built by Interpolation rather
   than NDSolve so its grid values are exact under reinterpolation. *)
$m22If = Interpolation[Table[{t, {{Cos[t], Sin[t]}, {2 t, t^2}}}, {t, 0., 1., .1}]]

$pf = ParametricNDSolveValue[{v'[t] == {{0, pa}, {-pa, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}, {pa}]
$pfLazy = $pf[aa][tt]
$pfM = ParametricNDSolveValue[{m'[t] == {{0, pa}, {-pa, 0}} . m[t], m[0] == {{1., 0.}, {0., 1.}}}, m, {t, 0, 1}, {pa}]
$pfLazyM = $pfM[aa][tt]
$fn = Function[fnT, {{Cos[fnT], -Sin[fnT]}, {Sin[fnT], Cos[fnT]}}]
$pw = Piecewise[{{{{1., 2.}, {3., 4.}}, zz < 0}}, {{5., 6.}, {7., 8.}}]

$vec = VectorSymbol["v", 3]
$mat = MatrixSymbol["M", {2, 3}]
$arr = ArraySymbol["T", {2, 3, 4}]
$matC = MatrixSymbol["C", {2, 2}, Complexes]

(* Set fresh so this file does not depend on assumption state from any other
   .wlt: the runner loads every file into one kernel session and the ArrayPart
   test below rewrites the global $Assumptions entry for symB in place. *)
$Assumptions = {Element[symA, Matrices[{2, 2}]], Element[symB, Matrices[{2, 2}]]}


BeginTestSection["structural"]

VerificationTest[
    {Head[ArrayTranspose[$sparse, {2, 1}]], ArrayTranspose[$sparse, {2, 1}] == Transpose[$dense]},
    {SparseArray, True},
    TestID -> "structural-transpose-sparse"
]

VerificationTest[
    ArrayTranspose[$dense, 1 <-> 2],
    Transpose[$dense],
    TestID -> "structural-transpose-twowayrule-explicit"
]

VerificationTest[
    With[{composed = ArrayTranspose[Transpose[$arr, {2, 3, 1}], {2, 3, 1}]},
        {
            MatchQ[composed, Verbatim[Transpose][ArraySymbol["T", {2, 3, 4}], _]],
            ArrayDimensions[composed] === Dimensions[Transpose[Transpose[ConstantArray[0, {2, 3, 4}], {2, 3, 1}], {2, 3, 1}]]
        }
    ],
    {True, True},
    TestID -> "structural-transpose-permutation-composition"
]

(* Composing a permutation with itself gives the identity list {1, 2}, which the
   precedent semantics keep as an explicit trivial Transpose wrapper. *)
VerificationTest[
    With[{composed = ArrayTranspose[Transpose[$mat, {2, 1}], {2, 1}]},
        {composed === Transpose[$mat, {1, 2}], ArrayDimensions[composed]}
    ],
    {True, {2, 3}},
    TestID -> "structural-transpose-composition-identity"
]

(* An explicit matrix contracts to what TensorContract gives it.  A List
   argument is ONE array and numbers its own levels, so the plain nested-List
   form of this matrix traces identically - pinned in Regressions.wlt. *)
VerificationTest[
    ArrayContract[SparseArray[{{1, 2}, {3, 4}}], {{1, 2}}],
    TensorContract[{{1, 2}, {3, 4}}, {{1, 2}}],
    TestID -> "structural-contract-explicit-matches-tensorcontract"
]

VerificationTest[
    With[{contraction = ArrayContract[ArraySymbol["S", {2, 3, 2}], {{1, 3}}]},
        {MatchQ[contraction, _TensorContract], ArrayDimensions[contraction]}
    ],
    {True, {3}},
    TestID -> "structural-contract-symbolic-inactive"
]

VerificationTest[
    With[{contraction = ArrayContract[Inactive[TensorProduct][VectorSymbol["u", 2], VectorSymbol["w", 2]], {{1, 2}}]},
        {MatchQ[contraction, TensorContract[Inactive[TensorProduct][__], _]], ArrayDimensions[contraction]}
    ],
    {True, {}},
    TestID -> "structural-contract-operand-set-tensor-product"
]

VerificationTest[
    ArrayPart[{{1, 2}, {3, 4}}, {1, 2}],
    2,
    TestID -> "structural-part-explicit"
]

VerificationTest[
    ArrayPart[{{1, 2}, {3, 4}}, {All, 2}],
    {2, 4},
    TestID -> "structural-part-explicit-all"
]

VerificationTest[
    ArrayPart[$mat, {1}],
    VectorSymbol["M"[1], {3}, Reals],
    TestID -> "structural-part-matrixsymbol-row"
]

VerificationTest[
    ArrayPart[$mat, {All, 2}],
    VectorSymbol["M"[][2], {2}, Reals],
    TestID -> "structural-part-matrixsymbol-column"
]

VerificationTest[
    ArrayPart[$vec, {2}],
    ArraySymbol["v"[2], {}],
    TestID -> "structural-part-vectorsymbol-element"
]

VerificationTest[
    ArrayPart[$arr, {1}],
    MatrixSymbol["T"[1], {3, 4}, Reals],
    TestID -> "structural-part-arraysymbol-slice"
]

VerificationTest[
    {ArrayPart[symB, {1}], ArrayDimensions[symB]},
    {symB, {2}},
    TestID -> "structural-part-assumption-symbol-reregisters"
]

VerificationTest[
    SimplifyArray[Inactive[Transpose][$mat, {}]],
    $mat,
    TestID -> "structural-simplify-trivial-transpose"
]

VerificationTest[
    SimplifyArray[Inactive[TensorProduct][$mat]],
    $mat,
    TestID -> "structural-simplify-singleton-tensorproduct"
]

(* A singleton inactive product is its OPERAND, and the operand is handed back
   whole.  Mapping over it instead descends into a container and rebuilds it
   from its parts, which for a SparseArray is a list of sparse rows. *)
VerificationTest[
    With[{simplified = SimplifyArray[Inactive[TensorProduct][$sparse]]},
        {Head[simplified], simplified === $sparse}
    ],
    {SparseArray, True},
    TestID -> "structural-simplify-singleton-tensorproduct-keeps-the-container"
]

(* The ACTIVE spelling is the opposite case: TensorProduct is Flat, so the
   pattern binds the whole product and the map is the recursion through its
   operands. *)
VerificationTest[
    SimplifyArray[TensorProduct[Inactive[Transpose][$mat, {}], VectorSymbol["uS", 2]]],
    TensorProduct[$mat, VectorSymbol["uS", 2]],
    TestID -> "structural-simplify-active-tensorproduct-recurses-through-operands"
]

VerificationTest[
    {ArrayName[$mat], ArrayName[VectorSymbol[nameV, 3]], ArrayName[symA], ArrayName[{1, 2}]},
    {"M", nameV, symA, None},
    TestID -> "structural-name"
]

VerificationTest[
    With[{mapped = ArrayMap[#^2 &, $sparse]},
        {Head[mapped], Normal[mapped]}
    ],
    {SparseArray, {{0, 1}, {4, 0}}},
    TestID -> "structural-map-sparse-element-level"
]

VerificationTest[
    With[{mapped = ArrayMap[#^2 &, $sparse, {2}]},
        {Head[mapped], Normal[mapped]}
    ],
    {SparseArray, {{0, 1}, {4, 0}}},
    TestID -> "structural-map-sparse-rank-level"
]

VerificationTest[
    ArrayMap[Total, $sparse, {1}],
    {1, 2},
    TestID -> "structural-map-sparse-densifies-off-element-level"
]

VerificationTest[
    ArrayMap[# + 1 &, {{1, 2}, {3, 4}}],
    {{2, 3}, {4, 5}},
    TestID -> "structural-map-plain-list"
]

VerificationTest[
    ArrayMap[# * 2 &, $numeric],
    {{2., 0.}, {0., 4.}},
    TestID -> "structural-map-numericarray-densifies"
]

(* A non-numeric-valued f leaves a lazy container unevaluated; a symbolic
   container applies f to the whole container at element level. *)
VerificationTest[
    {Head[ArrayMap[f0, $lazy]], ArrayMap[f0, $mat], Head[ArrayMap[f0, $mat, {1}]]},
    {ArrayMap, f0[$mat], ArrayMap},
    TestID -> "structural-map-lazy-symbolic"
]

VerificationTest[
    With[{substituted = ArrayReplaceAll[$lazy, tau -> 0.5]},
        {
            Developer`PackedArrayQ[substituted] || VectorQ[substituted, NumberQ],
            substituted == $if[0.5]
        }
    ],
    {True, True},
    TestID -> "structural-replaceall-lazy-one-shot-evaluation"
]

VerificationTest[
    With[{substituted = ArrayReplaceAll[SparseArray[{1 -> x1}, 3], x1 -> 2]},
        {Head[substituted], Normal[substituted]}
    ],
    {SparseArray, {2, 0, 0}},
    TestID -> "structural-replaceall-sparse-explicit-values"
]

VerificationTest[
    ArrayReplaceAll[$mat, "M" -> "M2"],
    MatrixSymbol["M2", {2, 3}],
    TestID -> "structural-replaceall-symbolic"
]

VerificationTest[
    With[{conjugated = ArrayConjugate[SparseArray[{1 -> I, 2 -> 2}, 3]]},
        {Head[conjugated], Normal[conjugated]}
    ],
    {SparseArray, {-I, 2, 0}},
    TestID -> "structural-conjugate-sparse"
]

VerificationTest[
    {Developer`PackedArrayQ[ArrayConjugate[$packedComplex]], ArrayConjugate[$packedComplex] == Conjugate[{1. + 2. I, 3. - 1. I}]},
    {True, True},
    TestID -> "structural-conjugate-packed"
]

VerificationTest[
    {Head[ArrayConjugate[$numeric]], Normal[ArrayConjugate[$numeric]] == Normal[$numeric]},
    {NumericArray, True},
    TestID -> "structural-conjugate-numericarray"
]

VerificationTest[
    MatchQ[ArrayConjugate[$matC], _Conjugate],
    True,
    TestID -> "structural-conjugate-symbolic-inactive"
]

VerificationTest[
    TrueQ[Max[Abs[(ArrayConjugate[$lazy] /. tau -> 0.5) - Conjugate[$if[0.5]]]] < 1*^-4],
    True,
    TestID -> "structural-conjugate-lazy-materializes"
]

VerificationTest[
    {
        ArrayAllZeroQ[SparseArray[{}, {2, 2}]],
        ArrayAllZeroQ[{{0, 0}, {0, 0}}],
        ArrayAllZeroQ[{{0, 1}}],
        ArrayAllZeroQ[SparseArray[{1 -> x1}, 3]],
        ArrayAllZeroQ[$lazy],
        ArrayAllZeroQ[$mat]
    },
    {True, True, False, False, False, False},
    TestID -> "structural-allzeroq"
]

EndTestSection[]


BeginTestSection["structural - the operand set"]

(* An operand SET is spelled Inactive[TensorProduct][a1, a2, ...] and its pairs
   number the levels of the operands CONCATENATED, so a two-operand node at
   {{2, 3}} is the matrix product.  A List argument is one array and numbers its
   own levels, which is why the set needs a head of its own.  Every value below
   is the operands' own arithmetic - Dot, TensorContract, a hand sum - never the
   contraction being tested. *)

$opA = SparseArray[{{1, 2}, {3, 4}}]
$opB = SparseArray[{{5, 6}, {7, 8}}]

(* The operands are contracted against each other and the tensor product is
   never built, which is what keeps the container: sparse against sparse is the
   SparseArray that SparseArray arithmetic gives. *)
VerificationTest[
    With[{contraction = ArrayContract[Inactive[TensorProduct][$opA, $opB], {{2, 3}}]},
        {Head[contraction], Normal[contraction], Normal[contraction] === Normal[$opA] . Normal[$opB]}
    ],
    {SparseArray, {{19, 22}, {43, 50}}, True},
    TestID -> "operandset-sparse-pair-contracts-to-a-sparsearray"
]

(* Packed operands give a packed result and exact ones stay exact, both for the
   same reason: each pairwise contraction is arithmetic on the operands. *)
VerificationTest[
    With[{
        packed = ArrayContract[
            Inactive[TensorProduct][Developer`ToPackedArray[{{1., 2.}, {3., 4.}}], Developer`ToPackedArray[{{5., 6.}, {7., 8.}}]],
            {{2, 3}}
        ],
        exact = ArrayContract[Inactive[TensorProduct][{{1/2, 1/3}, {1/4, 1/5}}, {{1/6, 1/7}, {1/8, 1/9}}], {{2, 3}}]
    },
        {Developer`PackedArrayQ[packed, Real], packed, exact}
    ],
    {True, {{19., 22.}, {43., 50.}}, {{1/8, 41/378}, {1/15, 73/1260}}},
    TestID -> "operandset-packed-stays-packed-and-exact-stays-exact"
]

(* A QuantityArray set gives a QuantityArray carrying the PRODUCT of the units,
   which is the unit the contracted magnitudes are in. *)
VerificationTest[
    ArrayContract[
        Inactive[TensorProduct][
            QuantityArray[{{1., 2.}, {3., 4.}}, "Meters"],
            QuantityArray[{{5., 6.}, {7., 8.}}, "Seconds"]
        ],
        {{2, 3}}
    ],
    QuantityArray[{{19., 22.}, {43., 50.}}, "Meters" "Seconds"],
    TestID -> "operandset-quantityarray-pair-carries-the-product-of-the-units"
]

(* A single structured operand keeps its structure, and on EVERY index pair, not
   only the symmetric one.  A one-operand node has no product to keep its
   operand out of, so the operand is contracted bare and reaches the same native
   path the bare container does; wrapped in a product instead, the kernel drives
   the atom's symmetry through a permutation that is not one and does not come
   back, for five of these six pairs. *)
VerificationTest[
    With[{s = SymmetrizedArray[{{1, 1, 2, 2} -> 3., {1, 2, 1, 2} -> 5.}, {2, 2, 2, 2}, Symmetric[{1, 2}]]},
        Map[
            {
                Head[ArrayContract[Inactive[TensorProduct][s], {#}]],
                Normal[ArrayContract[Inactive[TensorProduct][s], {#}]] === TensorContract[Normal[s], {#}],
                ArrayContract[Inactive[TensorProduct][s], {#}] === ArrayContract[s, {#}]
            } &,
            {{1, 2}, {3, 4}, {1, 3}, {2, 4}, {1, 4}, {2, 3}}
        ]
    ],
    ConstantArray[{SymmetrizedArray, True, True}, 6],
    TestID -> "operandset-single-structured-operand-keeps-its-structure"
]

(* The one-operand node and the bare container are the SAME call on every tier,
   the wrapper having nothing to do on one operand: a SparseArray keeps its
   head, a packed array stays packed, and a symbolic operand gives the same
   inactive node either way. *)
VerificationTest[
    {
        ArrayContract[Inactive[TensorProduct][$opA], {{2}}] === ArrayContract[$opA, {{2}}],
        ArrayContract[Inactive[TensorProduct][$opA], {{1, 2}}] === ArrayContract[$opA, {{1, 2}}],
        Developer`PackedArrayQ[ArrayContract[Inactive[TensorProduct][Developer`ToPackedArray[{{1., 2.}, {3., 4.}}]], {{2}}]],
        ArrayContract[Inactive[TensorProduct][MatrixSymbol["Ms1", {2, 2}]], {{1, 2}}] ===
            ArrayContract[MatrixSymbol["Ms1", {2, 2}], {{1, 2}}]
    },
    {True, True, True, True},
    TestID -> "operandset-one-operand-node-is-the-bare-contraction"
]

(* A specification TensorContract cannot act on comes back as the inert node it
   already is, and the product is NOT built to discover that: activating it
   would materialize every element of the outer product to arrive at the same
   answer.  The ByteCount is the check - a built product of two 40x40 operands
   is 40^4 machine reals. *)
VerificationTest[
    With[{d = ConstantArray[1., {40, 40}]},
        Map[
            Quiet[ByteCount[ArrayContract[Inactive[TensorProduct][d, d], #]]] < 10^6 &,
            {{{2, 9}}, {{1, 2}, {2, 3}}}
        ]
    ],
    {True, True},
    TestID -> "operandset-unactionable-specification-never-builds-the-product"
]

(* The two dense LIMITS of contracting the operands pairwise, stated rather than
   promised away: two structured atoms give the dense array their own product
   gives, and a SparseArray with a non-zero background is dense before it is
   contracted at all.  Buying either back would mean building the tensor
   product, which is the cost the node exists to avoid. *)
VerificationTest[
    With[{
        s = SymmetrizedArray[{{1, 1} -> 1., {1, 2} -> 2.}, {3, 3}, Symmetric[{1, 2}]],
        bg = SparseArray[{{1, 1} -> 2.}, {2, 2}, 1.]
    },
        {
            Head[ArrayContract[Inactive[TensorProduct][s, s], {{2, 3}}]],
            ArrayContract[Inactive[TensorProduct][s, s], {{2, 3}}] === Normal[s] . Normal[s],
            Head[ArrayContract[Inactive[TensorProduct][bg, $opA], {{2, 3}}]],
            ArrayContract[Inactive[TensorProduct][bg, $opA], {{2, 3}}] === Normal[bg] . Normal[$opA]
        }
    ],
    {List, True, List, True},
    TestID -> "operandset-dense-limits-of-the-pairwise-route"
]

(* Three operands and two groups chain, the rank being arithmetic on the operand
   ranks rather than anything read off a product that is never built. *)
VerificationTest[
    With[{contraction = ArrayContract[Inactive[TensorProduct][$opA, $opB, $opA], {{2, 3}, {4, 5}}]},
        {Head[contraction], Normal[contraction], Normal[contraction] === Normal[$opA] . Normal[$opB] . Normal[$opA]}
    ],
    {SparseArray, {{85, 126}, {193, 286}}, True},
    TestID -> "operandset-three-operands-chain-through-two-groups"
]

(* The three shapes a group list can take besides a plain product: consuming
   every slot leaves a scalar, a group INSIDE one operand traces it and scales
   the rest, and an empty group list contracts nothing and is the outer product
   the pairs would otherwise index. *)
VerificationTest[
    With[{node = Inactive[TensorProduct][$opA, $opB]},
        {
            ArrayContract[node, {{1, 3}, {2, 4}}],
            Normal[ArrayContract[node, {{1, 2}}]],
            ArrayDimensions[ArrayContract[node, {}]],
            Normal[ArrayContract[node, {}]] === Outer[Times, Normal[$opA], Normal[$opB]]
        }
    ],
    {70, {{25, 30}, {35, 40}}, {2, 2, 2, 2}, True},
    TestID -> "operandset-full-contraction-trace-and-empty-group-list"
]

(* An operand that TensorContract has no evaluation on is materialized one pass
   before any of this: a nested node is such an operand, and left standing it
   would be read as a lazy operand with no lazy container to expand, re-emitting
   the very call it was given. *)
VerificationTest[
    With[{contraction = ArrayContract[
        Inactive[TensorProduct][TensorContract[Inactive[TensorProduct][$opA, $opA], {{2, 3}}], $opA],
        {{2, 3}}
    ]},
        {Head[contraction], Normal[contraction] === Normal[$opA] . Normal[$opA] . Normal[$opA]}
    ],
    {SparseArray, True},
    TestID -> "operandset-nested-node-operand-is-materialized-first"
]

(* An operand with a dimension of 0 empties the contraction whatever the other
   operands are, and on every tier: the short-circuit is taken over the operands
   themselves, not over whichever form the contraction would otherwise leave. *)
VerificationTest[
    {
        ArrayContract[Inactive[TensorProduct][{}, VectorSymbol["u", 2]], {{1, 2}}],
        ArrayContract[Inactive[TensorProduct][{}, Function[zdT, {zdT, 2 zdT}]], {{1, 2}}]
    },
    {{}, {}},
    TestID -> "operandset-zero-dimension-operand-empties-every-tier"
]

(* THE REFUSAL.  A List that names an operand set is DECLINED rather than
   answered, the single-array reading of such a list being a silent wrong
   answer rather than a refusal: a list of two SparseArrays is ArrayQ, and
   reading it as one rank-3 array gives a clean rank-1 container holding the
   answer to a question nobody asked.  A list holds
   a set when at least one element is a container and not every element is a
   plain List - a nested-List matrix is all Lists and stays one array, while a
   container beside a bare scalar or a string names a set as plainly as two
   containers do, and answering those leaks TensorContract's own rectangularity
   messages for a symbol the caller never typed. *)
VerificationTest[
    {
        MatchQ[ArrayContract[{$opA, $opB}, {{2, 3}}], _ArrayContract],
        MatchQ[ArrayContract[{Normal[$opA], $opB}, {{2, 3}}], _ArrayContract]
    },
    {True, True},
    {ArrayContract::operands, ArrayContract::operands},
    TestID -> "operandset-list-of-containers-declines-with-its-message"
]

(* A container beside a non-container is the mistake a rank-0 operand invites,
   and it names a set as plainly.  Answered as one array it reaches
   TensorContract's rectangularity messages instead of this one. *)
VerificationTest[
    {
        MatchQ[ArrayContract[{2, $opA}, {{1, 2}}], _ArrayContract],
        MatchQ[ArrayContract[{$opA, "x"}, {{1, 2}}], _ArrayContract]
    },
    {True, True},
    {ArrayContract::operands, ArrayContract::operands},
    TestID -> "operandset-container-beside-a-non-container-declines-too"
]

VerificationTest[
    MatchQ[ArrayContract[{$opA}, {{1, 2}}], _ArrayContract],
    True,
    {ArrayContract::operands},
    TestID -> "operandset-one-element-list-declines-too"
]

(* A DECLINED CALL IS NOT AN ARRAY.  The refusal leaves the call as written,
   which is this paclet's refusal protocol, and the classification table and the
   contraction shape both ask the same operand-set predicate, so nothing reads
   the untouched expression as a container: it has no tier, no dimensions and no
   materialization, and the reading that was withheld cannot be re-derived
   through an accessor. *)
VerificationTest[
    With[{declined = Quiet[ArrayContract[{$opA, $opB}, {{2, 3}}]]},
        {
            ArrayContainerQ[declined],
            ArrayTier[declined],
            ArrayDimensions[declined],
            MatchQ[ArrayMaterialize[declined], _ArrayMaterialize],
            MatchQ[ArrayMap[fD, declined], _ArrayMap]
        }
    ],
    {False, Missing["NotAContainer"], {}, True, True},
    TestID -> "operandset-declined-call-is-not-a-container"
]

(* Normal densifies every operand of a declined call to a plain List, and the
   densified call is the legitimate single-array spelling, which answers - so
   left to Normal's own recursion the withheld reading would be re-derived
   without a message.  The declined call answers Normal itself instead, its
   operands still the containers they were. *)
VerificationTest[
    MatchQ[
        Normal[Quiet[ArrayContract[{$opA, $opB}, {{2, 3}}]]],
        HoldPattern[ArrayContract[{_SparseArray, _SparseArray}, {{2, 3}}]]
    ],
    True,
    TestID -> "operandset-normal-of-a-declined-call-does-not-rederive-the-reading"
]

(* The single-array reading is untouched where a List really is one array, and
   the two spellings of that array agree, which is what the refusal protects. *)
VerificationTest[
    {
        ArrayContract[{{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}, {{2, 3}}],
        Normal[ArrayContract[SparseArray[{{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}], {{2, 3}}]]
    },
    {{5, 13}, {5, 13}},
    TestID -> "operandset-a-list-of-plain-lists-is-still-one-array"
]

EndTestSection[]


BeginTestSection["structural - container preservation"]

VerificationTest[
    Head /@ {ArrayTranspose[$sparse, {2, 1}], ArrayConjugate[$sparse], ArrayMap[# + 1 &, $sparse], ArrayReplaceAll[$sparse, {}]},
    {SparseArray, SparseArray, SparseArray, SparseArray},
    TestID -> "preservation-sparse-in-sparse-out"
]

VerificationTest[
    Developer`PackedArrayQ /@ {ArrayTranspose[$packed, {2, 1}], ArrayConjugate[$packed], ArrayMap[# + 1. &, $packed]},
    {True, True, True},
    TestID -> "preservation-packed-in-packed-out"
]

VerificationTest[
    Head /@ {ArrayTranspose[$numeric, {2, 1}], ArrayConjugate[$numeric]},
    {NumericArray, NumericArray},
    TestID -> "preservation-numericarray-transpose-conjugate"
]

(* SymmetrizedArray substitution opacity: ArrayReplaceAll must actually reach the
   stored rule values, not bounce off the wrapper. *)
VerificationTest[
    Block[{aa},
        With[{sa = SymmetrizedArray[{{1, 2} -> aa}, {2, 2}, Antisymmetric[{1, 2}]]},
            ArrayReplaceAll[sa, aa -> 5]
        ]
    ],
    {{0, 5}, {-5, 0}},
    TestID -> "Wrapper-SymmetrizedArray-replaceall-substitutes"
]

EndTestSection[]


BeginTestSection["structural - deferred structural trees"]

(* Non-square operands again: on square ones a wrongly sliced Part still has the
   right SHAPE and the wrong value goes unnoticed downstream. *)

$dm23 = ArrayReshape[Range[6], {2, 3}]
$dm34 = ArrayReshape[Range[12], {3, 4}]

$deferredTrees = {
    Inactive[TensorProduct][$dm23, $dm34],
    Inactive[TensorContract][Inactive[TensorProduct][$dm23, $dm34], {{2, 3}}],
    Inactive[ArrayDot][$dm23, $dm34, {{2, 1}}],
    Inactive[Transpose][$dm23, {2, 1}]
}

(* Part on a deferred tree must address the ARRAY, not the expression tree.  For
   Inactive[TensorProduct] the tree reading even has the right shape - the first
   factor - so this compares values against Part of the activated node. *)
VerificationTest[
    Map[ArrayPart[#, {1}] === Part[Activate[#], 1] &, $deferredTrees],
    ConstantArray[True, Length[$deferredTrees]],
    TestID -> "structural-part-deferred-tree-matches-activate"
]

VerificationTest[
    Map[ArrayPart[#, {2, 1}] === Part[Activate[#], 2, 1] &, $deferredTrees],
    ConstantArray[True, Length[$deferredTrees]],
    TestID -> "structural-part-deferred-tree-multi-index"
]

(* A tree carrying a symbolic container has no materialization and no structural
   slice rule, so ArrayPart declines it instead of handing back an operand of
   the node, which for a tensor product would be a rank-2 answer where rank 3 is
   required. *)
VerificationTest[
    With[{symbolicTree = Inactive[TensorProduct][MatrixSymbol["A", {2, 3}], MatrixSymbol["B", {3, 4}]]},
        {
            ArraySymbolicQ[symbolicTree],
            Head[ArrayPart[symbolicTree, {1}]],
            ArrayPart[$mat, {1}]
        }
    ],
    {True, ArrayPart, VectorSymbol["M"[1], 3, Reals]},
    TestID -> "structural-part-symbolic-tree-declines"
]

(* An element-level map over a deferred tree maps the ELEMENTS.  Applying f to
   the node - the leafless-symbolic rule - would rewrite the contraction
   specification too: N turns {{2, 3}} into {{2., 3.}} and TensorContract then
   rejects it, and #*2& gives a scalar multiple of the node rather than an
   array of mapped values. *)
VerificationTest[
    Map[ArrayMap[N, #] === N[Activate[#]] &, $deferredTrees],
    ConstantArray[True, Length[$deferredTrees]],
    TestID -> "structural-map-deferred-tree-matches-activate"
]

VerificationTest[
    With[{tree = Inactive[TensorContract][Inactive[TensorProduct][$dm23, $dm34], {{2, 3}}]},
        {ArrayMap[# * 2 &, tree], ArrayDimensions[ArrayMap[# * 2 &, tree]]}
    ],
    {2 * Activate[Inactive[TensorContract][Inactive[TensorProduct][$dm23, $dm34], {{2, 3}}]], {2, 4}},
    TestID -> "structural-map-deferred-tree-is-an-array"
]

(* The leafless symbolic tree keeps the whole-container rule, which is what lets
   Simplify and friends distribute over it. *)
VerificationTest[
    ArrayMap[Simplify, $mat],
    Simplify[$mat],
    TestID -> "structural-map-symbolic-container-unchanged"
]

EndTestSection[]


BeginTestSection["structural - admitted lazy heads"]

(* ONE-EVALUATION PROOF.  A delayed rule counts entries into the lazy
   expression: the whole-array container is entered once per parameter, and the
   result is an explicit container.  The contrast test below counts the same
   rules against the per-scalar expansion of the same containers, where the
   count is once per parameter PER ELEMENT. *)
VerificationTest[
    Module[{entries},
        Map[
            Function[container,
                entries = 0;
                {
                    ArrayExplicitQ[
                        ArrayReplaceAll[
                            container,
                            {tau :> (entries++; 0.5), aa :> (entries++; 1.), tt :> (entries++; 0.5), zz :> (entries++; -1), fnT :> (entries++; 0.5)}
                        ]
                    ],
                    entries
                }
            ],
            {$lazy, $pfLazy, $pw, $fn}
        ]
    ],
    {{True, 1}, {True, 2}, {True, 1}, {True, 1}},
    TestID -> "Lazy-replaceall-one-evaluation-per-parameter"
]

VerificationTest[
    Module[{entries},
        Map[
            Function[container,
                entries = 0;
                ArrayMaterialize[container] /. {tau :> (entries++; 0.5), aa :> (entries++; 1.), tt :> (entries++; 0.5), zz :> (entries++; -1)};
                entries
            ],
            {$lazy, $pfLazy, $pw}
        ]
    ],
    {2, 4, 4},
    TestID -> "Lazy-materialized-form-evaluates-per-element"
]

(* Function is the one admitted head that can carry a counter inside itself, so
   the whole-array claim is checked directly on head entries and not only on
   substitution sites.  The shape probe enters the closure once and is cached,
   so the count after the probe is entirely due to the substitution. *)
(* The counter and the container are globals on purpose: Module renames a
   Function parameter that shares a scope with its locals, and the rule below is
   keyed on that parameter by name. *)
VerificationTest[
    (
        $closureCalls = 0;
        $closure = Function[cT, ($closureCalls++; {{Cos[cT], -Sin[cT]}, {Sin[cT], Cos[cT]}})];
        $closureShape = ArrayDimensions[$closure];
        $closureCalls = 0;
        $closureApplied = ArrayReplaceAll[$closure, cT -> 0.5];
        {
            $closureShape,
            $closureCalls,
            Developer`PackedArrayQ[$closureApplied],
            $closureApplied == {{Cos[0.5], -Sin[0.5]}, {Sin[0.5], Cos[0.5]}}
        }
    ),
    {{2, 2}, 1, True, True},
    TestID -> "Lazy-Function-substitution-is-one-closure-call"
]

(* A rule keyed on a bound parameter APPLIES the Function; a plain ReplaceAll
   would rewrite the parameter specification into Function[0.5, ...].  Rules on
   free symbols of the body keep the container lazy. *)
VerificationTest[
    With[{substituted = ArrayReplaceAll[Function[gT, {Cos[gT + gPhase], Sin[gT]}], gPhase -> 0]},
        {ArrayLazyQ[substituted], ArrayReplaceAll[substituted, gT -> 0.5] == {Cos[0.5], Sin[0.5]}}
    ],
    {True, True},
    TestID -> "Lazy-Function-free-symbol-substitution-stays-lazy"
]

(* Lazy-preserving structural ops: a Function composes, a Piecewise transforms
   its branch values in place, and both stay lazy. *)
VerificationTest[
    With[{transposed = ArrayTranspose[$fn, {2, 1}]},
        {ArrayLazyQ[transposed], ArrayReplaceAll[transposed, fnT -> 0.5] == Transpose[ArrayReplaceAll[$fn, fnT -> 0.5]]}
    ],
    {True, True},
    TestID -> "Lazy-Function-transpose-stays-lazy"
]

VerificationTest[
    With[{transposed = ArrayTranspose[$pw, {2, 1}]},
        {ArrayLazyQ[transposed], ArrayReplaceAll[transposed, zz -> -1]}
    ],
    {True, {{1., 3.}, {2., 4.}}},
    TestID -> "Lazy-Piecewise-transpose-stays-lazy"
]

(* A ParametricFunction has no value grid to remap and no body to compose, so
   its registry entry declares no rebuild and the op materializes through
   ArrayMaterialize.  The result is no longer lazy, and it still substitutes to
   the same array. *)
VerificationTest[
    With[{transposed = ArrayTranspose[$pfLazyM, {2, 1}]},
        {
            ArrayLazyQ[transposed],
            MatchQ[transposed, {{_Indexed, _Indexed}, {_Indexed, _Indexed}}],
            (transposed /. {aa -> 1., tt -> 0.5}) == Transpose[ArrayReplaceAll[$pfLazyM, {aa -> 1., tt -> 0.5}]]
        }
    ],
    {False, True, True},
    TestID -> "Lazy-ParametricFunction-transpose-materializes"
]

VerificationTest[
    With[{mapped = ArrayMap[# + 1 &, $pw]},
        {ArrayLazyQ[mapped], ArrayReplaceAll[mapped, zz -> -1]}
    ],
    {True, {{2., 3.}, {4., 5.}}},
    TestID -> "Lazy-Piecewise-map-stays-lazy"
]

VerificationTest[
    With[{mapped = ArrayMap[Abs, $fn]},
        {ArrayLazyQ[mapped], ArrayReplaceAll[mapped, fnT -> 0.5] == Map[Abs, ArrayReplaceAll[$fn, fnT -> 0.5], {2}]}
    ],
    {True, True},
    TestID -> "Lazy-Function-map-stays-lazy"
]

VerificationTest[
    With[{mapped = ArrayMap[Abs, $pfLazy]},
        {ArrayLazyQ[mapped], (mapped /. {aa -> 1., tt -> 0.5}) == Abs[ArrayReplaceAll[$pfLazy, {aa -> 1., tt -> 0.5}]]}
    ],
    {False, True},
    TestID -> "Lazy-ParametricFunction-map-materializes"
]

(* Part on an inert lazy form reaches the expression TREE: ifn[t][[1]] gives t,
   a Piecewise indexes its own branch list, and an unapplied Function hands back
   its parameter.  ArrayPart intercepts all three by expanding per scalar. *)
VerificationTest[
    {
        $if[tau][[1]],
        ArrayPart[$pw, {1, 2}],
        ArrayPart[$fn, {2, 1}],
        (ArrayPart[$pfLazy, {1}] /. {aa -> 1., tt -> 0.5}) == First[ArrayReplaceAll[$pfLazy, {aa -> 1., tt -> 0.5}]]
    },
    {tau, Piecewise[{{2., zz < 0}}, 6.], Function[fnT, Sin[fnT]], True},
    TestID -> "Lazy-part-intercepts-expression-tree"
]

(* Conjugation takes the same rebuild-or-materialize route: it cannot simply
   materialize, because Conjugate of an unapplied Function is inert and no later
   substitution can fix it. *)
VerificationTest[
    With[{conjugated = ArrayConjugate[$fn]},
        {ArrayLazyQ[conjugated], ArrayReplaceAll[conjugated, fnT -> 0.5] == Conjugate[ArrayReplaceAll[$fn, fnT -> 0.5]]}
    ],
    {True, True},
    TestID -> "Lazy-Function-conjugate-stays-lazy"
]

(* The BARE InterpolatingFunction goes through the same value-grid rebuilds as
   its applied form, minus the application at the end: every structural op
   below hands back an unapplied InterpolatingFunction whose value at a probe
   point is the op applied to the original's value there. *)
VerificationTest[
    With[{transposed = ArrayTranspose[$m22If, {2, 1}]},
        {Head[transposed], ArrayLazyQ[transposed], TrueQ[Max[Abs[transposed[0.3] - Transpose[$m22If[0.3]]]] < 1*^-4]}
    ],
    {InterpolatingFunction, True, True},
    TestID -> "Lazy-bare-InterpolatingFunction-transpose-stays-lazy"
]

(* Part expands per scalar first, so the part of the bare container is the
   first component's OWN interpolation, unapplied. *)
VerificationTest[
    With[{first = ArrayPart[$if, {1}]},
        {Head[first], TrueQ[Abs[first[0.3] - $if[0.3][[1]]] < 1*^-4]}
    ],
    {InterpolatingFunction, True},
    TestID -> "Lazy-bare-InterpolatingFunction-part-is-unapplied-component"
]

VerificationTest[
    With[{conjugated = ArrayConjugate[$if]},
        {Head[conjugated], ArrayLazyQ[conjugated], TrueQ[Max[Abs[conjugated[0.5] - Conjugate[$if[0.5]]]] < 1*^-4]}
    ],
    {InterpolatingFunction, True, True},
    TestID -> "Lazy-bare-InterpolatingFunction-conjugate-stays-lazy"
]

(* The rebuild remaps the grid values where the map keeps them numeric, and
   declines - leaving ArrayMap unevaluated - where it does not, exactly as the
   applied form does. *)
VerificationTest[
    With[{mapped = ArrayMap[2 # &, $if]},
        {
            Head[mapped],
            ArrayLazyQ[mapped],
            TrueQ[Max[Abs[mapped[0.5] - 2 $if[0.5]]] < 1*^-4],
            MatchQ[ArrayMap[mapSym[#] &, $if], _ArrayMap]
        }
    ],
    {InterpolatingFunction, True, True, True},
    TestID -> "Lazy-bare-InterpolatingFunction-map-rebuilds-where-numeric"
]

(* Substitution never enters the InterpolatingFunction object.  The bare
   form binds its parameter positionally and carries no free symbol, so every
   rule leaves it identical - including a rule keyed on a value the grid
   contains, and one keyed on the grid origin 0., either of which a plain
   ReplaceAll would rewrite into an object that still classifies as a container
   and interpolates wrongly. *)
VerificationTest[
    With[{gridValue = $if["ValuesOnGrid"][[3, 2]]},
        {
            ArrayReplaceAll[$if, {notPresent -> 5}] === $if,
            ArrayReplaceAll[$if, tau -> 0.3] === $if,
            ArrayReplaceAll[$if, gridValue -> 999.] === $if,
            ArrayReplaceAll[$if, 0. -> 1.] === $if
        }
    ],
    {True, True, True, True},
    TestID -> "Lazy-bare-InterpolatingFunction-substitution-leaves-grid-intact"
]

(* The applied form substitutes in its argument positions only: a numeric
   substitution of the parameter is one whole-array evaluation, a symbolic one
   stays inert, and a rule keyed on grid data reaches nothing. *)
VerificationTest[
    With[{gridValue = $if["ValuesOnGrid"][[3, 2]]},
        {
            ArrayReplaceAll[$if[tau], tau -> 0.3] == $if[0.3],
            ArrayReplaceAll[$if[tau], tau -> sigma] === $if[sigma],
            ArrayReplaceAll[$if[tau], gridValue -> 999.] === $if[tau],
            ArrayReplaceAll[$if[tau], 0. -> 1.] === $if[tau]
        }
    ],
    {True, True, True, True},
    TestID -> "Lazy-applied-InterpolatingFunction-substitution-stays-out-of-the-object"
]

EndTestSection[]
