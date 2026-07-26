(* Tests for Wolfram/Arrays shape and value-domain queries: ArrayDimensions,
   ArrayRank, ZeroArrayQ, ArrayNumericQ, ArrayNumberQ.
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

$vec = VectorSymbol["v", 3]
$mat = MatrixSymbol["M", {2, 3}]
$arr = ArraySymbol["T", {2, 3, 4}]
$tensorProduct = Inactive[TensorProduct][VectorSymbol["u", 2], MatrixSymbol["N", {3, 4}]]

(* Set fresh so this file does not depend on assumption state from any other
   .wlt: the runner loads every file into one kernel session and ArrayPart
   rewrites the global $Assumptions in place. *)
$Assumptions = {Element[symA, Matrices[{2, 2}]], Element[symB, Matrices[{2, 2}]]}


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


BeginTestSection["shape - admitted wrapper containers"]

(* Numericity of a wrapper follows the values it wraps, never the wrapper head. *)
VerificationTest[
    {ArrayNumberQ[QuantityArray[{1, 2}, "Meters"]], ArrayNumberQ[QuantityArray[{1., 2.}, "Meters"]]},
    {False, True},
    TestID -> "Wrapper-QuantityArray-numberq-follows-magnitudes"
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
    With[{tab = Tabular[{{1, Missing["bad"]}, {2, 3.5}}, {"x", "y"}]},
        ArrayNumericQ[tab]
    ],
    False,
    TestID -> "Wrapper-Tabular-missing-disqualifies"
]

VerificationTest[
    {ArrayNumberQ[Dataset[{1, 2, 3}]], ArrayNumberQ[Dataset[{1., 2., 3.}]]},
    {False, True},
    TestID -> "Wrapper-Dataset-numberq-off-type"
]

(* An EventSeries answers from the element type of its "Values" column wherever
   that type settles the question, and scans only where it does not: a column of
   complex, rational or big-integer values is typed "NumberExpression" or
   "IntegerExpression", which settles nothing. *)
VerificationTest[
    Map[
        {ArrayNumericQ[EventSeries[#, {{0, 1}}]], ArrayNumberQ[EventSeries[#, {{0, 1}}]]} &,
        {{1., 2.}, {1, 2}, {{1., 2.}, {3., 4.}}, {{1, 2}, {3, 4}}, {1. + 2. I, 3.}, {1/2, 1/3}, {2^200, 1}, {"a", "b"}, {1., Missing[], 3.}}
    ],
    {{True, True}, {True, False}, {True, True}, {True, False}, {True, True}, {True, False}, {True, False}, {False, False}, {False, False}},
    TestID -> "Wrapper-EventSeries-numericity"
]

(* A machine-typed series is never copied to answer either question: the series
   is bounded only by its path length, and the ArrayObject summary box asks both
   on every render. *)
VerificationTest[
    Block[{ArrayMaterialize},
        ArrayMaterialize[___] := Throw["materialized", "shape-eventseries"];
        With[{ev = EventSeries[{{1., 2.}, {3., 4.}}, {{0, 1}}]},
            Catch[{ArrayNumericQ[ev], ArrayNumberQ[ev]}, "shape-eventseries"]
        ]
    ],
    {True, True},
    TestID -> "Wrapper-EventSeries-numericity-does-not-materialize"
]

EndTestSection[]


BeginTestSection["shape - setDimensions"]

(* setDimensions has a symbolic-array-head clause that no in-paclet call site
   reaches (Structural.wl only ever passes an atomic symbol), so nothing else
   would notice if its left-hand side stopped matching - which is exactly what
   splicing an alias from another kernel file into it risked. *)

VerificationTest[
    Wolfram`Arrays`PackageScope`setDimensions[MatrixSymbol["A", {2, 3}], {4}],
    VectorSymbol["A", 4, Reals],
    TestID -> "shape-setdimensions-symbolic-head-to-vector"
]

VerificationTest[
    {
        Wolfram`Arrays`PackageScope`setDimensions[VectorSymbol["A", 3], {2, 5}],
        Wolfram`Arrays`PackageScope`setDimensions[ArraySymbol["T", {2, 3, 4}], {2, 2, 2, 2}]
    },
    {MatrixSymbol["A", {2, 5}, Reals], ArraySymbol["T", {2, 2, 2, 2}, Reals]},
    TestID -> "shape-setdimensions-symbolic-head-to-matrix-and-array"
]

(* ArrayName spells out the same alternatives for the same reason. *)
VerificationTest[
    ArrayName /@ {VectorSymbol["v", 3], MatrixSymbol["M", {2, 2}], ArraySymbol["T", {2, 2, 2}], 7},
    {"v", "M", "T", None},
    TestID -> "shape-setdimensions-arrayname-symbolic-heads"
]

EndTestSection[]
