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

(* A plain List argument means a list of arrays to ArrayContract (precedent
   semantics), so the explicit matrix goes in as a SparseArray. *)
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
    With[{contraction = ArrayContract[{VectorSymbol["u", 2], VectorSymbol["w", 2]}, {{1, 2}}]},
        {MatchQ[contraction, TensorContract[Inactive[TensorProduct][__], _]], ArrayDimensions[contraction]}
    ],
    {True, {}},
    TestID -> "structural-contract-list-tensor-product"
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
