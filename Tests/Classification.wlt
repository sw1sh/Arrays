(* Tests for Wolfram/Arrays container classification: ArrayContainerQ,
   ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ, ArrayComputeNativeQ.
   Run via Tests/RunTests.wls or TestReport. *)

Needs["Wolfram`Arrays`"]

(* === fixtures === *)

$sparse = SparseArray[{{0, 1}, {2, 0}}]
$packed = Developer`ToPackedArray[N[{{1, 2}, {3, 4}}]]
$numeric = NumericArray[{{1., 0.}, {0., 2.}}]
$symmetrized = SymmetrizedArray[{{1, 2} -> 3.}, {2, 2}, Antisymmetric[{1, 2}]]
$plain = {{a1, a2}, {a3, a4}}

$if = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}]
$lazy = $if[tau]
$scalarIf = NDSolveValue[{u'[t] == - u[t], u[0] == 1.}, u, {t, 0, 1}]

$vec = VectorSymbol["v", 3]
$mat = MatrixSymbol["M", {2, 3}]
$arr = ArraySymbol["T", {2, 3, 4}]
$tensorProduct = Inactive[TensorProduct][VectorSymbol["u", 2], MatrixSymbol["N", {3, 4}]]

(* Set fresh so this file does not depend on assumption state from any other
   .wlt: the runner loads every file into one kernel session and ArrayPart
   rewrites the global $Assumptions in place. *)
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


BeginTestSection["classification - admitted wrapper containers"]

(* QuantityArray: compute-native, shape and numericity off the magnitudes *)
VerificationTest[
    With[{qa = QuantityArray[{1., 2., 3.}, "Meters"]},
        {ArrayExplicitQ[qa], ArrayContainerQ[qa], ArrayComputeNativeQ[qa], ArrayDimensions[qa], ArrayNumericQ[qa]}
    ],
    {True, True, True, {3}, True},
    TestID -> "Wrapper-QuantityArray-classification"
]

(* TabularColumn: compute-native, per-instance numericity via ElementType *)
VerificationTest[
    With[{tc = TabularColumn[{1., 2., 3.}]},
        {ArrayExplicitQ[tc], ArrayComputeNativeQ[tc], ArrayDimensions[tc], ArrayNumericQ[tc], Developer`PackedArrayQ[ArrayMaterialize[tc]]}
    ],
    {True, True, {3}, True, True},
    TestID -> "Wrapper-TabularColumn-classification-materialize"
]

(* Tabular: storage-only; anonymous Normal is packed *)
VerificationTest[
    With[{tab = Tabular[{{1., 2.}, {3., 4.}, {5., 6.}}]},
        {ArrayExplicitQ[tab], ArrayComputeNativeQ[tab], ArrayDimensions[tab], ArrayNumericQ[tab], Developer`PackedArrayQ[ArrayMaterialize[tab]]}
    ],
    {True, False, {3, 2}, True, True},
    TestID -> "Wrapper-Tabular-anonymous-classification-materialize"
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

(* DataStructure stores: rank-1 only *)
VerificationTest[
    With[{ds = CreateDataStructure["DynamicArray", {1., 2., 3.}]},
        {ArrayExplicitQ[ds], ArrayComputeNativeQ[ds], ArrayDimensions[ds], ArrayNumericQ[ds], Developer`PackedArrayQ[ArrayMaterialize[ds]]}
    ],
    {True, False, {3}, True, True},
    TestID -> "Wrapper-DataStructure-DynamicArray-classification"
]

VerificationTest[
    ArrayExplicitQ[CreateDataStructure["LinkedList"]],
    False,
    TestID -> "Wrapper-DataStructure-nonarray-store-rejected"
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
