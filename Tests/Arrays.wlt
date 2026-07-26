(* Tests for Wolfram/Arrays. Run via Tests/RunTests.wls or TestReport. *)

Needs["Wolfram`Arrays`"]

(* === fixtures === *)

$sparse = SparseArray[{{0, 1}, {2, 0}}]
$dense = Normal[$sparse]
$packed = Developer`ToPackedArray[N[{{1, 2}, {3, 4}}]]
$packedComplex = Developer`ToPackedArray[{1. + 2. I, 3. - 1. I}]
$numeric = NumericArray[{{1., 0.}, {0., 2.}}]
$symmetrized = SymmetrizedArray[{{1, 2} -> 3.}, {2, 2}, Antisymmetric[{1, 2}]]
$plain = {{a1, a2}, {a3, a4}}

$if = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}]
$lazy = $if[tau]
$ifM = NDSolveValue[{m'[t] == {{0, 1}, {-1, 0}} . m[t], m[0] == {{1., 0.}, {0., 1.}}}, m, {t, 0, 1}]
$lazyM = $ifM[tau]
$scalarIf = NDSolveValue[{u'[t] == - u[t], u[0] == 1.}, u, {t, 0, 1}]

$vec = VectorSymbol["v", 3]
$mat = MatrixSymbol["M", {2, 3}]
$arr = ArraySymbol["T", {2, 3, 4}]
$matC = MatrixSymbol["C", {2, 2}, Complexes]
$tensorProduct = Inactive[TensorProduct][VectorSymbol["u", 2], MatrixSymbol["N", {3, 4}]]

$Assumptions = {Element[symA, Matrices[{2, 2}]], Element[symB, Matrices[{2, 2}]]}


BeginTestSection["classification"]

VerificationTest[
    Through[{ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ}[$sparse]],
    {True, True, False, False},
    TestID -> "classification-sparse"
]

VerificationTest[
    Through[{ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ}[$packed]],
    {True, True, False, False},
    TestID -> "classification-packed"
]

VerificationTest[
    Through[{ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ}[$plain]],
    {True, True, False, False},
    TestID -> "classification-plain-list"
]

VerificationTest[
    Through[{ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ}[$numeric]],
    {True, True, False, False},
    TestID -> "classification-numericarray"
]

VerificationTest[
    Through[{ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ}[$symmetrized]],
    {True, True, False, False},
    TestID -> "classification-symmetrizedarray"
]

VerificationTest[
    Through[{ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ}[$lazy]],
    {True, False, True, False},
    TestID -> "classification-lazy-interpolatingfunction"
]

VerificationTest[
    {ArrayExplicitQ[$if[0.5]], ArrayLazyQ[$if[0.5]]},
    {True, False},
    TestID -> "classification-lazy-numeric-argument-is-explicit"
]

VerificationTest[
    ArrayLazyQ[$scalarIf[tau]],
    False,
    TestID -> "classification-scalar-interpolatingfunction-not-lazy"
]

VerificationTest[
    Through[{ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ}[$vec]],
    {True, False, False, True},
    TestID -> "classification-vectorsymbol"
]

VerificationTest[
    Through[{ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ}[$mat]],
    {True, False, False, True},
    TestID -> "classification-matrixsymbol"
]

VerificationTest[
    ArraySymbolicQ[$arr],
    True,
    TestID -> "classification-arraysymbol"
]

VerificationTest[
    {ArraySymbolicQ[symA], ArrayContainerQ[symA], ArraySymbolicQ[symZ]},
    {True, True, False},
    TestID -> "classification-assumption-registered-symbol"
]

VerificationTest[
    Through[{ArrayContainerQ, ArraySymbolicQ}[$tensorProduct]],
    {True, True},
    TestID -> "classification-inactive-tensorproduct-tree"
]

VerificationTest[
    ArraySymbolicQ[Transpose[$mat]],
    True,
    TestID -> "classification-transpose-tree"
]

VerificationTest[
    ArraySymbolicQ[MatrixSymbol["A", {2, 3}] + MatrixSymbol["B", {2, 3}]],
    True,
    TestID -> "classification-plus-tree"
]

VerificationTest[
    ArraySymbolicQ[TensorContract[ArraySymbol["S", {2, 3, 2}], {{1, 3}}]],
    True,
    TestID -> "classification-tensorcontract-tree"
]

VerificationTest[
    ArraySymbolicQ[Inactive[D][$vec, x]],
    True,
    TestID -> "classification-inactive-d-tree"
]

VerificationTest[
    Through[{ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ}["junk"]],
    {False, False, False, False},
    TestID -> "classification-junk-string"
]

VerificationTest[
    Through[{ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ}[f0[x]]],
    {False, False, False, False},
    TestID -> "classification-junk-expression"
]

VerificationTest[
    {ArrayContainerQ[5], ArrayContainerQ[{1, {2}}]},
    {False, False},
    TestID -> "classification-scalar-and-ragged-not-containers"
]

EndTestSection[]


BeginTestSection["shape"]

VerificationTest[
    ArrayDimensions /@ {$sparse, $packed, $plain, $numeric, $symmetrized},
    {{2, 2}, {2, 2}, {2, 2}, {2, 2}, {2, 2}},
    TestID -> "shape-dimensions-explicit-containers"
]

VerificationTest[
    ArrayDimensions[$lazy],
    {2},
    TestID -> "shape-dimensions-lazy-interpolatingfunction"
]

VerificationTest[
    ArrayDimensions[$mat],
    {2, 3},
    TestID -> "shape-dimensions-matrixsymbol"
]

VerificationTest[
    ArrayDimensions[symA],
    {2, 2},
    TestID -> "shape-dimensions-assumption-symbol"
]

VerificationTest[
    ArrayDimensions[Transpose[$mat]],
    {3, 2},
    TestID -> "shape-dimensions-transpose-default"
]

VerificationTest[
    ArrayDimensions[Transpose[$arr, {2, 3, 1}]],
    Dimensions[Transpose[ConstantArray[0, {2, 3, 4}], {2, 3, 1}]],
    TestID -> "shape-dimensions-transpose-permutation"
]

VerificationTest[
    ArrayDimensions[Transpose[$arr, 2]],
    RotateRight[{2, 3, 4}, 2],
    TestID -> "shape-dimensions-transpose-rotation"
]

VerificationTest[
    ArrayDimensions[Transpose[$arr, 1 <-> 3]],
    {4, 3, 2},
    TestID -> "shape-dimensions-transpose-twowayrule"
]

VerificationTest[
    ArrayDimensions[MatrixSymbol["A", {2, 3}] + MatrixSymbol["B", {2, 3}]],
    {2, 3},
    TestID -> "shape-dimensions-plus"
]

VerificationTest[
    ArrayDimensions[$tensorProduct],
    {2, 3, 4},
    TestID -> "shape-dimensions-inactive-tensorproduct"
]

VerificationTest[
    ArrayDimensions[TensorContract[ArraySymbol["S", {2, 3, 2}], {{1, 3}}]],
    {3},
    TestID -> "shape-dimensions-tensorcontract"
]

VerificationTest[
    ArrayDimensions[Inactive[D][$vec, {{p1, p2}}]],
    {3, 2},
    TestID -> "shape-dimensions-inactive-d-gradient"
]

VerificationTest[
    ArrayDimensions[Inactive[D][$vec, {{p1, p2}, 2}]],
    {3, 2, 2},
    TestID -> "shape-dimensions-inactive-d-hessian"
]

VerificationTest[
    ArrayDimensions[Inactive[D][$vec, x]],
    {3},
    TestID -> "shape-dimensions-inactive-d-scalar-parameter"
]

VerificationTest[
    {ArrayRank[$arr], ArrayRank[$lazy], ArrayRank[$sparse], ArrayRank[5]},
    {3, 1, 2, 0},
    TestID -> "shape-rank"
]

VerificationTest[
    {ZeroArrayQ[$sparse], ZeroArrayQ[ConstantArray[1, {2, 0}]], ZeroArrayQ[$mat]},
    {False, True, False},
    TestID -> "shape-zeroarrayq"
]

VerificationTest[
    {ArrayNumericQ[$sparse], ArrayNumericQ[SparseArray[{1 -> x1}, 3]], ArrayNumericQ[$packed], ArrayNumericQ[$numeric]},
    {True, False, True, True},
    TestID -> "shape-numericq-explicit"
]

VerificationTest[
    {ArrayNumericQ[{1, Pi}], ArrayNumericQ[{1, x1}], ArrayNumericQ[$lazy], ArrayNumericQ[$mat]},
    {True, False, False, False},
    TestID -> "shape-numericq-list-lazy-symbolic"
]

VerificationTest[
    {ArrayNumberQ[{1, Pi}], ArrayNumberQ[{1., 2.5}], ArrayNumberQ[$packed], ArrayNumberQ[$sparse], ArrayNumberQ[$lazy]},
    {False, True, True, False, False},
    TestID -> "shape-numberq"
]

EndTestSection[]


BeginTestSection["accessors"]

VerificationTest[
    {ArrayExplicitValues[$dense], ArrayExplicitPositions[$dense], ArrayExplicitLength[$dense]},
    {ArrayExplicitValues[$sparse], Normal[ArrayExplicitPositions[$sparse]], ArrayExplicitLength[$sparse]},
    TestID -> "accessors-dense-sparse-parity"
]

VerificationTest[
    {ArrayExplicitValues[$sparse], ArrayExplicitLength[$sparse]},
    {{1, 2}, 2},
    TestID -> "accessors-sparse-native"
]

VerificationTest[
    ArrayExplicitValues[$numeric],
    {1., 2.},
    TestID -> "accessors-numericarray-values"
]

VerificationTest[
    ArrayExplicitValues[$symmetrized],
    {3., -3.},
    TestID -> "accessors-symmetrizedarray-values"
]

VerificationTest[
    {ArrayExplicitValues[$lazy], ArrayExplicitPositions[$lazy], ArrayExplicitLength[$lazy]},
    {Missing["NotExplicit"], Missing["NotExplicit"], Missing["NotExplicit"]},
    TestID -> "accessors-lazy-missing"
]

VerificationTest[
    {ArrayExplicitValues[$mat], ArrayExplicitPositions[symA], ArrayExplicitLength[$tensorProduct]},
    {Missing["NotExplicit"], Missing["NotExplicit"], Missing["NotExplicit"]},
    TestID -> "accessors-symbolic-missing"
]

VerificationTest[
    ArrayMaterialize /@ {$sparse, $numeric, $symmetrized},
    {{{0, 1}, {2, 0}}, {{1., 0.}, {0., 2.}}, {{0, 3.}, {-3., 0}}},
    TestID -> "accessors-materialize-explicit"
]

VerificationTest[
    With[{expansion = ArrayMaterialize[$lazy]},
        {
            Dimensions[expansion] === {2},
            TrueQ[Max[Abs[(expansion /. tau -> 0.5) - $if[0.5]]] < 1*^-4]
        }
    ],
    {True, True},
    TestID -> "accessors-materialize-lazy-matches-per-scalar-expansion"
]

VerificationTest[
    ArrayMaterialize[$mat],
    $mat,
    TestID -> "accessors-materialize-symbolic-identity"
]

VerificationTest[
    With[{x = SparseArray[{1 -> 1, 2 -> I}, 3]},
        {Developer`PackedArrayQ[ArrayPack[x]], ArrayMaterialize[ArrayPack[x]] == Normal[x]}
    ],
    {True, True},
    TestID -> "accessors-pack-materialize-normal-roundtrip"
]

VerificationTest[
    Developer`PackedArrayQ[ArrayPack[Normal[SparseArray[{1 -> 1, 2 -> I}, 3]]]],
    True,
    TestID -> "accessors-pack-mixed-integer-complex"
]

VerificationTest[
    Developer`PackedArrayQ[ArrayPack[{1, 2.5}]],
    True,
    TestID -> "accessors-pack-mixed-integer-real"
]

VerificationTest[
    {ArrayPack[$plain], ArrayPack[$mat], ArrayPack[$lazy]},
    {$plain, $mat, $lazy},
    TestID -> "accessors-pack-unpackable-unchanged"
]

EndTestSection[]


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


BeginTestSection["container-preservation"]

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

EndTestSection[]


BeginTestSection["flatten-reshape-pad"]

VerificationTest[
    With[{sa12 = SparseArray[{ConstantArray[1, 12] -> 2., ConstantArray[2, 12] -> 3.}, ConstantArray[2, 12]]},
        {Head[ArrayVector[sa12]], ArrayVector[sa12] == Flatten[sa12]}
    ],
    {SparseArray, True},
    TestID -> "flatten-sparse-rank12-csr-fast-path"
]

VerificationTest[
    With[{sa13 = SparseArray[{{1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 3} -> 5.}, {2, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3}]},
        ArrayVector[sa13] == Flatten[sa13]
    ],
    True,
    TestID -> "flatten-sparse-rank13-unequal-dimensions-parity"
]

VerificationTest[
    {Head[ArrayVector[$sparse]], ArrayVector[$sparse] == {0, 1, 2, 0}},
    {SparseArray, True},
    TestID -> "flatten-sparse-low-rank"
]

VerificationTest[
    {ArrayVector[3.5], ArrayVector[Pi]},
    {3.5, Pi},
    TestID -> "flatten-scalar-passthrough"
]

VerificationTest[
    {ArrayVector[{{1, 2}, {3, 4}}], Developer`PackedArrayQ[ArrayVector[$packed]]},
    {{1, 2, 3, 4}, True},
    TestID -> "flatten-lists"
]

VerificationTest[
    {Head[ArrayVector[$numeric]], Normal[ArrayVector[$numeric]]},
    {NumericArray, {1., 0., 0., 2.}},
    TestID -> "flatten-numericarray"
]

VerificationTest[
    With[{reshaped = ReshapeArray[$sparse, {4}]},
        {Head[reshaped], Normal[reshaped]}
    ],
    {SparseArray, {0, 1, 2, 0}},
    TestID -> "reshape-sparse"
]

VerificationTest[
    ReshapeArray[{1, 2, 3, 4}, {2, 3}, 0],
    {{1, 2, 3}, {4, 0, 0}},
    TestID -> "reshape-list-with-padding"
]

VerificationTest[
    PadArray[{{1}}, 1],
    {{0, 0, 0}, {0, 1, 0}, {0, 0, 0}},
    TestID -> "pad-list"
]

VerificationTest[
    Head[PadArray[$sparse, 1]],
    SparseArray,
    TestID -> "pad-sparse-stays-sparse"
]

VerificationTest[
    Select[
        {
            "ArrayContainerQ", "ArrayExplicitQ", "ArrayLazyQ", "ArraySymbolicQ",
            "ArrayDimensions", "ArrayRank", "ZeroArrayQ", "ArrayNumericQ", "ArrayNumberQ",
            "ArrayExplicitValues", "ArrayExplicitPositions", "ArrayExplicitLength", "ArrayMaterialize", "ArrayPack",
            "ArrayTranspose", "ArrayContract", "ArrayPart", "SimplifyArray", "ArrayName",
            "ArrayMap", "ArrayReplaceAll", "ArrayConjugate", "ArrayAllZeroQ",
            "ArrayVector", "ReshapeArray", "PadArray"
        },
        Names["System`" <> #] =!= {} &
    ],
    {},
    TestID -> "no-system-symbol-collisions"
]

EndTestSection[]


BeginTestSection["regressions"]

(* ArrayMap on a packed integer array keeps exact value parity with Map. *)
VerificationTest[
    ArrayMap[# / 2 &, Developer`ToPackedArray[{1, 2, 3}]],
    {1/2, 1, 3/2},
    TestID -> "regression-map-packed-exact-value-parity"
]

VerificationTest[
    ArrayMap[Sqrt, Developer`ToPackedArray[{1, 4, 2}]],
    {1, 2, Sqrt[2]},
    TestID -> "regression-map-packed-exact-sqrt"
]

VerificationTest[
    Developer`PackedArrayQ[ArrayMap[# * 2 &, Developer`ToPackedArray[{1, 2, 3}]]],
    True,
    TestID -> "regression-map-packed-repacks-plain"
]

(* Assumption-registered symbols are recognized inside And conjunctions and
   multi-symbol Element entries, in parity with ArrayDimensions. *)
VerificationTest[
    Block[{$Assumptions = Element[symM1, Matrices[{2, 2}]] && z1 > 0},
        {ArraySymbolicQ[symM1], ArrayContainerQ[symM1], ArrayDimensions[symM1]}
    ],
    {True, True, {2, 2}},
    TestID -> "regression-symbolicq-and-conjunction-assumptions"
]

VerificationTest[
    Block[{$Assumptions = {Element[symP1 | symQ1, Matrices[{3, 3}]]}},
        {ArraySymbolicQ[symP1], ArraySymbolicQ[symQ1], ArrayDimensions[symP1]}
    ],
    {True, True, {3, 3}},
    TestID -> "regression-symbolicq-alternatives-assumptions"
]

VerificationTest[
    Block[{$Assumptions = Element[symR1, Matrices[{2, 2}]] && z1 > 0},
        ArrayPart[symR1, {1}];
        {ArrayDimensions[symR1], Count[$Assumptions, Element[symR1, _]], MemberQ[$Assumptions, z1 > 0]}
    ],
    {{2}, 1, True},
    TestID -> "regression-setdimensions-and-conjunction-no-duplicate"
]

VerificationTest[
    Block[{$Assumptions = {Element[symP2 | symQ2, Matrices[{3, 3}]]}},
        ArrayPart[symP2, {1}];
        {ArrayDimensions[symP2], ArrayDimensions[symQ2]}
    ],
    {{3}, {3, 3}},
    TestID -> "regression-setdimensions-alternatives-split"
]

(* ArrayPack never destroys exact values that do not survive machine precision. *)
VerificationTest[
    ArrayPack[{1/2, 1/3}],
    {1/2, 1/3},
    TestID -> "regression-pack-exact-rationals-unchanged"
]

VerificationTest[
    ArrayPack[{1, 2^200 + 1}],
    {1, 2^200 + 1},
    TestID -> "regression-pack-unrepresentable-big-integer-unchanged"
]

(* A plain List matrix contracts the same way as its SparseArray form. *)
VerificationTest[
    ArrayContract[{{1, 2}, {3, 4}}, {{1, 2}}],
    TensorContract[{{1, 2}, {3, 4}}, {{1, 2}}],
    TestID -> "regression-contract-plain-list-matrix-traces"
]

(* Lazy structural ops keep the container lazy: flatten, reshape, transpose. *)
VerificationTest[
    With[{flat = ArrayVector[$lazyM]},
        {
            ArrayLazyQ[flat],
            ArrayDimensions[flat],
            TrueQ[Max[Abs[(flat /. tau -> 0.5) - Flatten[$ifM[0.5]]]] < 1*^-4]
        }
    ],
    {True, {4}, True},
    TestID -> "regression-lazy-flatten-stays-lazy"
]

VerificationTest[
    With[{reshaped = ReshapeArray[$lazyM, {4}]},
        {ArrayLazyQ[reshaped], TrueQ[Max[Abs[(reshaped /. tau -> 0.5) - Flatten[$ifM[0.5]]]] < 1*^-4]}
    ],
    {True, True},
    TestID -> "regression-lazy-reshape-stays-lazy"
]

VerificationTest[
    With[{transposed = ArrayTranspose[$lazyM, {2, 1}]},
        {ArrayLazyQ[transposed], TrueQ[Max[Abs[(transposed /. tau -> 0.5) - Transpose[$ifM[0.5]]]] < 1*^-4]}
    ],
    {True, True},
    TestID -> "regression-lazy-transpose-stays-lazy"
]

VerificationTest[
    ArrayLazyQ[ArrayVector[$lazy]],
    True,
    TestID -> "regression-lazy-flatten-rank1-passthrough"
]

(* ArrayNumberQ mirrors InexactNumberQ: exact values give False. *)
VerificationTest[
    {
        ArrayNumberQ[SparseArray[{1, 2, 3}]],
        ArrayNumberQ[NumericArray[{1, 2, 3}, "Integer64"]],
        ArrayNumberQ[NumericArray[{1., 2.}]],
        ArrayNumberQ[Developer`ToPackedArray[{1, 2, 3}]],
        ArrayNumberQ[$packedComplex],
        ArrayNumberQ[SparseArray[{1., 2.}]]
    },
    {False, False, True, False, True, True},
    TestID -> "regression-numberq-inexact-semantics"
]

(* Ragged input gives a quiet {} instead of a wrong shape plus a message. *)
VerificationTest[
    ArrayDimensions[{1, {2}}],
    {},
    TestID -> "regression-dimensions-ragged-quiet-empty"
]

(* Simplify-family maps stay meaningful on symbolic and lazy containers. *)
VerificationTest[
    ArrayMap[Simplify, $mat],
    $mat,
    TestID -> "regression-map-symbolic-simplify-whole-container"
]

VerificationTest[
    With[{chopped = ArrayMap[Chop, $lazy]},
        {ArrayLazyQ[chopped], TrueQ[Max[Abs[(chopped /. tau -> 0.5) - $if[0.5]]] < 1*^-4]}
    ],
    {True, True},
    TestID -> "regression-map-lazy-chop-stays-lazy"
]

(* PadArray preserves NumericArray containers. *)
VerificationTest[
    With[{padded = PadArray[NumericArray[{1., 2.}], {{0, 2}}]},
        {Head[padded], Normal[padded]}
    ],
    {NumericArray, {1., 2., 0., 0.}},
    TestID -> "regression-pad-numericarray"
]

EndTestSection[]


BeginTestSection["edge-cases"]

VerificationTest[
    {ArrayDimensions[{}], ZeroArrayQ[{}], ArrayExplicitQ[{}], ArrayVector[{}], ArrayMaterialize[{}]},
    {{0}, True, True, {}, {}},
    TestID -> "edge-empty-list"
]

VerificationTest[
    {ArrayExplicitValues[{}], ArrayExplicitPositions[{}], ArrayExplicitLength[{}]},
    {{}, {}, 0},
    TestID -> "edge-empty-list-accessors"
]

VerificationTest[
    {ArrayDimensions[{{}}], ZeroArrayQ[{{}}], ArrayExplicitValues[{{}}], ArrayExplicitLength[{{}}]},
    {{1, 0}, True, {}, 0},
    TestID -> "edge-nested-empty"
]

VerificationTest[
    {ArrayDimensions[7], ArrayRank[7], ArrayContainerQ[7], ArrayVector[7]},
    {{}, 0, False, 7},
    TestID -> "edge-rank0-scalar"
]

VerificationTest[
    {ArrayDimensions[{5}], ArrayExplicitValues[{5}], ArrayExplicitValues[{0}], ArrayExplicitLength[{0}]},
    {{1}, {5}, {}, 0},
    TestID -> "edge-single-element-and-zero-vectors"
]

VerificationTest[
    {ArrayTranspose[ConstantArray[1, {0, 2}], {2, 1}], ArrayContract[Inactive[TensorProduct][{}, {1, 2}], {{1, 2}}]},
    {{}, {}},
    TestID -> "edge-zero-dimension-structural-short-circuit"
]

EndTestSection[]


BeginTestSection["Arrays - admitted wrapper containers"]

(* QuantityArray: compute-native, materializes via QuantityMagnitude (Normal is the
   slow unpacked trap), rebuilds from the "UnitBlock" metadata *)
VerificationTest[
    With[{qa = QuantityArray[{1., 2., 3.}, "Meters"]},
        {ArrayExplicitQ[qa], ArrayContainerQ[qa], ArrayComputeNativeQ[qa], ArrayDimensions[qa], ArrayNumericQ[qa]}
    ],
    {True, True, True, {3}, True},
    TestID -> "Wrapper-QuantityArray-classification"
]

VerificationTest[
    With[{qa = QuantityArray[{1., 2., 3.}, "Meters"]},
        {ArrayMaterialize[qa] === QuantityMagnitude[qa], Developer`PackedArrayQ[ArrayMaterialize[qa]]}
    ],
    {True, True},
    TestID -> "Wrapper-QuantityArray-materialize-magnitudes-packed"
]

VerificationTest[
    With[{qa = QuantityArray[{{1., 2.}, {3., 4.}}, "Seconds"]},
        With[{rebuilt = QuantityArray[2 ArrayMaterialize[qa], qa["UnitBlock"]]},
            {MatchQ[rebuilt, _QuantityArray], QuantityMagnitude[rebuilt]}
        ]
    ],
    {True, {{2., 4.}, {6., 8.}}},
    TestID -> "Wrapper-QuantityArray-rebuild-roundtrip"
]

VerificationTest[
    {ArrayNumberQ[QuantityArray[{1, 2}, "Meters"]], ArrayNumberQ[QuantityArray[{1., 2.}, "Meters"]]},
    {False, True},
    TestID -> "Wrapper-QuantityArray-numberq-follows-magnitudes"
]

(* TabularColumn: compute-native, per-instance numericity via ElementType *)
VerificationTest[
    With[{tc = TabularColumn[{1., 2., 3.}]},
        {ArrayExplicitQ[tc], ArrayComputeNativeQ[tc], ArrayDimensions[tc], ArrayNumericQ[tc], Developer`PackedArrayQ[ArrayMaterialize[tc]]}
    ],
    {True, True, {3}, True, True},
    TestID -> "Wrapper-TabularColumn-classification-materialize"
]

VerificationTest[
    ArrayNumericQ[TabularColumn[{"a", "b"}]],
    False,
    TestID -> "Wrapper-TabularColumn-string-column-not-numeric"
]

VerificationTest[
    ArrayNumericQ[TabularColumn[{1., Missing[], 3.}]],
    False,
    TestID -> "Wrapper-TabularColumn-missing-disqualifies"
]

VerificationTest[
    With[{tc = TabularColumn[{1., 2., 3.}]},
        Normal[TabularColumn[2 ArrayMaterialize[tc], tc["ElementType"]]]
    ],
    {2., 4., 6.},
    TestID -> "Wrapper-TabularColumn-rebuild-roundtrip"
]

(* Tabular: storage-only; anonymous Normal is packed; named route goes per-column *)
VerificationTest[
    With[{tab = Tabular[{{1., 2.}, {3., 4.}, {5., 6.}}]},
        {ArrayExplicitQ[tab], ArrayComputeNativeQ[tab], ArrayDimensions[tab], ArrayNumericQ[tab], Developer`PackedArrayQ[ArrayMaterialize[tab]]}
    ],
    {True, False, {3, 2}, True, True},
    TestID -> "Wrapper-Tabular-anonymous-classification-materialize"
]

VerificationTest[
    With[{m = {{1., 2.}, {3., 4.}, {5., 6.}}},
        ArrayMaterialize[Tabular[m, {"a", "b"}]] == m
    ],
    True,
    TestID -> "Wrapper-Tabular-named-percolumn-route"
]

VerificationTest[
    With[{tab = Tabular[{{1, Missing["bad"]}, {2, 3.5}}, {"x", "y"}]},
        ArrayNumericQ[tab]
    ],
    False,
    TestID -> "Wrapper-Tabular-missing-disqualifies"
]

VerificationTest[
    With[{m = {{1., 2.}, {3., 4.}}},
        ArrayMaterialize[Tabular[ArrayMaterialize[Tabular[m]]]] == m
    ],
    True,
    TestID -> "Wrapper-Tabular-rebuild-roundtrip"
]

(* Dataset: storage-only; shape and numericity off the type signature. Normal is a
   pass-through of the wrapped storage, so packedness follows construction: a Dataset
   built over a packed matrix materializes packed. *)
VerificationTest[
    With[{ds = Dataset[Developer`ToPackedArray[{{1., 2.}, {3., 4.}}]]},
        {ArrayExplicitQ[ds], ArrayComputeNativeQ[ds], ArrayDimensions[ds], ArrayNumericQ[ds], Developer`PackedArrayQ[ArrayMaterialize[ds]]}
    ],
    {True, False, {2, 2}, True, True},
    TestID -> "Wrapper-Dataset-classification-materialize"
]

VerificationTest[
    {ArrayNumberQ[Dataset[{1, 2, 3}]], ArrayNumberQ[Dataset[{1., 2., 3.}]]},
    {False, True},
    TestID -> "Wrapper-Dataset-numberq-off-type"
]

(* ByteArray: storage-only integer vector *)
VerificationTest[
    With[{ba = ByteArray[{1, 2, 3, 255}]},
        {ArrayExplicitQ[ba], ArrayComputeNativeQ[ba], ArrayDimensions[ba], ArrayNumericQ[ba], ArrayNumberQ[ba], ArrayMaterialize[ba]}
    ],
    {True, False, {4}, True, False, {1, 2, 3, 255}},
    TestID -> "Wrapper-ByteArray-classification-materialize"
]

(* EventSeries: storage-only time-indexed; raw "Values" needs Normal in v15 *)
VerificationTest[
    With[{ev = EventSeries[{{1., 2.}, {3., 4.}, {5., 6.}}, {{0, 1, 2}}]},
        {ArrayExplicitQ[ev], ArrayComputeNativeQ[ev], ArrayDimensions[ev], ArrayMaterialize[ev] == {{1., 2.}, {3., 4.}, {5., 6.}}}
    ],
    {True, False, {3, 2}, True},
    TestID -> "Wrapper-EventSeries-classification-materialize"
]

VerificationTest[
    With[{ev = EventSeries[{{1., 2.}, {3., 4.}}, {{0, 1}}]},
        With[{rebuilt = EventSeries[ArrayMaterialize[ev], {Normal[ev["Times"]]}]},
            ArrayMaterialize[rebuilt] == ArrayMaterialize[ev]
        ]
    ],
    True,
    TestID -> "Wrapper-EventSeries-rebuild-roundtrip"
]

(* DataStructure stores: rank-1, reference semantics defeated by snapshot-on-ingest *)
VerificationTest[
    With[{ds = CreateDataStructure["DynamicArray", {1., 2., 3.}]},
        {ArrayExplicitQ[ds], ArrayComputeNativeQ[ds], ArrayDimensions[ds], ArrayNumericQ[ds], Developer`PackedArrayQ[ArrayMaterialize[ds]]}
    ],
    {True, False, {3}, True, True},
    TestID -> "Wrapper-DataStructure-DynamicArray-classification"
]

VerificationTest[
    Module[{ds = CreateDataStructure["DynamicArray", {1., 2., 3.}], snapshot},
        snapshot = ArrayMaterialize[ds];
        ds["Append", 4.];
        {snapshot, ds["Length"]}
    ],
    {{1., 2., 3.}, 4},
    TestID -> "Wrapper-DataStructure-snapshot-defeats-aliasing"
]

VerificationTest[
    ArrayExplicitQ[CreateDataStructure["LinkedList"]],
    False,
    TestID -> "Wrapper-DataStructure-nonarray-store-rejected"
]

(* SymmetrizedArray substitution opacity: ArrayReplaceAll must actually substitute *)
VerificationTest[
    Block[{aa},
        With[{sa = SymmetrizedArray[{{1, 2} -> aa}, {2, 2}, Antisymmetric[{1, 2}]]},
            ArrayReplaceAll[sa, aa -> 5]
        ]
    ],
    {{0, 5}, {-5, 0}},
    TestID -> "Wrapper-SymmetrizedArray-replaceall-substitutes"
]

(* Association stays rejected: entry multiset is not a faithful shape *)
VerificationTest[
    ArrayContainerQ[<|1 -> 1.5, 2 -> 2.5, 5 -> -1.|>],
    False,
    TestID -> "Wrapper-Association-stays-rejected"
]

(* compute-native capability pins across the board *)
VerificationTest[
    ArrayComputeNativeQ /@ {
        SparseArray[{1., 0., 2.}],
        Developer`ToPackedArray[{1., 2.}],
        NumericArray[{1., 2.}, "Real64"],
        SymmetrizedArray[{{1, 2} -> 1.}, {2, 2}, Symmetric[{1, 2}]]
    },
    {True, True, False, False},
    TestID -> "Wrapper-ComputeNativeQ-pins"
]

EndTestSection[]
