(* Tests for Wolfram/Arrays shape-changing operations: ArrayVector (flatten),
   ReshapeArray, PadArray.
   Run via Tests/RunTests.wls or TestReport. *)

Needs["Wolfram`Arrays`"]

(* === fixtures === *)

$sparse = SparseArray[{{0, 1}, {2, 0}}]
$packed = Developer`ToPackedArray[N[{{1, 2}, {3, 4}}]]
$numeric = NumericArray[{{1., 0.}, {0., 2.}}]


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
