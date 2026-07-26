(* Regression and edge-case tests for Wolfram/Arrays. Each test here pins a bug
   that was fixed or a boundary that is easy to break; they are grouped by symptom
   rather than by kernel file.
   Run via Tests/RunTests.wls or TestReport. *)

Needs["Wolfram`Arrays`"]

(* === fixtures === *)

$packedComplex = Developer`ToPackedArray[{1. + 2. I, 3. - 1. I}]

$if = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}]
$lazy = $if[tau]
$ifM = NDSolveValue[{m'[t] == {{0, 1}, {-1, 0}} . m[t], m[0] == {{1., 0.}, {0., 1.}}}, m, {t, 0, 1}]
$lazyM = $ifM[tau]

$mat = MatrixSymbol["M", {2, 3}]


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

(* The coercing rungs are tried in order and evaluation stops at the first
   faithful packing: a mixed Integer/Real list packs on the Real rung, and only
   a list that rung cannot represent reaches the Complex one. *)
VerificationTest[
    With[{packed = ArrayPack[{1, 2.5}]},
        {Developer`PackedArrayQ[packed, Real], packed == {1, 2.5}}
    ],
    {True, True},
    TestID -> "regression-pack-real-rung-coerces-mixed-integer-real"
]

VerificationTest[
    With[{packed = ArrayPack[{1, 2. + 1. I}]},
        {Developer`PackedArrayQ[packed, Complex], packed == {1, 2. + 1. I}}
    ],
    {True, True},
    TestID -> "regression-pack-complex-rung-reached-after-real"
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

(* No exported name may shadow a System` symbol.  The list of names is DERIVED
   from the loaded context rather than written out: a hardcoded list silently
   stops covering the export it was not updated for, which is how
   ArrayComputeNativeQ went unchecked. *)
VerificationTest[
    Select[Names["Wolfram`Arrays`*"], Names["System`" <> Last[StringSplit[#, "`"]]] =!= {} &],
    {},
    TestID -> "no-system-symbol-collisions"
]

(* ... and the derivation must not go vacuous: were the context to come back
   empty, the collision guard above would pass for the wrong reason.  Every
   symbol PacletInfo declares has to be there. *)
VerificationTest[
    Complement[
        Last /@ StringSplit[
            Lookup[<|Rest @ First @ Cases[PacletObject["Wolfram/Arrays"]["Extensions"], {"Kernel", ___}]|>, "Symbols"],
            "`"
        ],
        Names["Wolfram`Arrays`*"]
    ],
    {},
    TestID -> "exports-match-pacletinfo-symbols"
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
