(* Tests for Wolfram/Arrays shape-changing operations: ArrayVector (flatten),
   ReshapeArray, PadArray.
   Run via Tests/RunTests.wls or TestReport. *)

Needs["Wolfram`Arrays`"]

(* === fixtures === *)

$sparse = SparseArray[{{0, 1}, {2, 0}}]
$packed = Developer`ToPackedArray[N[{{1, 2}, {3, 4}}]]
$numeric = NumericArray[{{1., 0.}, {0., 2.}}]

$pf = ParametricNDSolveValue[{v'[t] == {{0, pa}, {-pa, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}, {pa}]
$pfLazy = $pf[aa][tt]
$pfM = ParametricNDSolveValue[{m'[t] == {{0, pa}, {-pa, 0}} . m[t], m[0] == {{1., 0.}, {0., 1.}}}, m, {t, 0, 1}, {pa}]
$pfLazyM = $pfM[aa][tt]
$fn = Function[fnT, {{Cos[fnT], -Sin[fnT]}, {Sin[fnT], Cos[fnT]}}]
$pw = Piecewise[{{{{1., 2.}, {3., 4.}}, zz < 0}}, {{5., 6.}, {7., 8.}}]


BeginTestSection["flatten-reshape-pad"]

(* Rank 12 is the last rank where equal dimensions still take the CSR fast path. *)
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

EndTestSection[]


BeginTestSection["flatten-reshape - admitted lazy heads"]

(* A Function composes and a Piecewise transforms its branch values, so both
   flatten and reshape without leaving the lazy tier. *)
VerificationTest[
    With[{flat = ArrayVector[$fn]},
        {ArrayLazyQ[flat], ArrayDimensions[flat], ArrayReplaceAll[flat, fnT -> 0.5] == Flatten[ArrayReplaceAll[$fn, fnT -> 0.5]]}
    ],
    {True, {4}, True},
    TestID -> "Lazy-Function-flatten-stays-lazy"
]

VerificationTest[
    With[{flat = ArrayVector[$pw]},
        {ArrayLazyQ[flat], ArrayDimensions[flat], ArrayReplaceAll[flat, zz -> -1]}
    ],
    {True, {4}, {1., 2., 3., 4.}},
    TestID -> "Lazy-Piecewise-flatten-stays-lazy"
]

VerificationTest[
    With[{reshaped = ReshapeArray[$fn, {4}]},
        {ArrayLazyQ[reshaped], ArrayReplaceAll[reshaped, fnT -> 0.5] == Flatten[ArrayReplaceAll[$fn, fnT -> 0.5]]}
    ],
    {True, True},
    TestID -> "Lazy-Function-reshape-stays-lazy"
]

VerificationTest[
    With[{reshaped = ReshapeArray[$pw, {2, 3}, 0.]},
        {ArrayLazyQ[reshaped], ArrayReplaceAll[reshaped, zz -> -1]}
    ],
    {True, {{1., 2., 3.}, {4., 0., 0.}}},
    TestID -> "Lazy-Piecewise-reshape-with-padding-stays-lazy"
]

(* A ParametricFunction declares no rebuild, so flatten materializes and says so
   by no longer being lazy; the values still substitute identically. *)
VerificationTest[
    With[{flat = ArrayVector[$pfLazyM]},
        {
            ArrayLazyQ[flat],
            ArrayDimensions[flat],
            (flat /. {aa -> 1., tt -> 0.5}) == Flatten[ArrayReplaceAll[$pfLazyM, {aa -> 1., tt -> 0.5}]]
        }
    ],
    {False, {4}, True},
    TestID -> "Lazy-ParametricFunction-flatten-materializes"
]

(* A rank-1 lazy container of any head passes straight through: flattening it
   could only turn a lazy container into a materialized one for no gain. *)
VerificationTest[
    ArrayVector[$pfLazy] === $pfLazy,
    True,
    TestID -> "Lazy-rank1-flatten-passthrough"
]

EndTestSection[]
