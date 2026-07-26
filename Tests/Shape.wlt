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

$pf = ParametricNDSolveValue[{v'[t] == {{0, pa}, {-pa, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}, {pa}]
$pfLazy = $pf[aa][tt]
$fn = Function[fnT, {{Cos[fnT], -Sin[fnT]}, {Sin[fnT], Cos[fnT]}}]
$pw = Piecewise[{{{{1., 2.}, {3., 4.}}, zz < 0}}, {{5., 6.}, {7., 8.}}]

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


BeginTestSection["shape - admitted lazy heads"]

(* Every lazy head must intercept Dimensions, which on an inert form reports the
   expression TREE.  The container survey is CONTRADICTED for Piecewise: in 15.0
   Dimensions does NOT thread through the branches of an unevaluated
   array-valued Piecewise, it reports the argument count, and since the kernel
   normalizes a one-argument Piecewise to Piecewise[pairs, default] that count is
   {2} for every Piecewise whatever its branch values are. *)
VerificationTest[
    {
        {Dimensions[$pfLazy], ArrayDimensions[$pfLazy], ArrayRank[$pfLazy]},
        {Dimensions[$pw], ArrayDimensions[$pw], ArrayRank[$pw]},
        {Dimensions[Piecewise[{{ConstantArray[1., {2, 3, 4}], zz < 0}}, ConstantArray[0., {2, 3, 4}]]], ArrayDimensions[Piecewise[{{ConstantArray[1., {2, 3, 4}], zz < 0}}, ConstantArray[0., {2, 3, 4}]]]}
    },
    {{{1}, {2}, 1}, {{2}, {2, 2}, 2}, {{2}, {2, 3, 4}}},
    TestID -> "Lazy-shape-intercepts-expression-tree"
]

VerificationTest[
    Block[{ArrayMaterialize},
        ArrayMaterialize[___] := Throw["materialized", "shape-lazy"];
        Catch[Map[ArrayDimensions, {$pfLazy, $fn, $pw}], "shape-lazy"]
    ],
    {{2}, {2, 2}, {2, 2}},
    TestID -> "Lazy-shape-without-materializing"
]

(* The ParametricFunction probe solve is cached per object, so the shape is read
   a second time without entering the solver at all: blocking the probe's own
   RandomReal draw pins that the cache, not the kernel's parameter cache, is
   what answers. *)
VerificationTest[
    (
        ArrayDimensions[$pfLazy];
        Block[{RandomReal},
            RandomReal[___] := Throw["probed", "shape-pf-cache"];
            Catch[ArrayDimensions[$pfLazy], "shape-pf-cache"]
        ]
    ),
    {2},
    TestID -> "Lazy-ParametricFunction-shape-probe-cached"
]

(* Numericity and zero probes stay on the explicit tier: a lazy container has no
   readable elements, so all four answer False rather than materializing. *)
VerificationTest[
    Map[{ArrayNumericQ[#], ArrayNumberQ[#], ArrayAllZeroQ[#], ZeroArrayQ[#]} &, {$pfLazy, $fn, $pw}],
    {{False, False, False, False}, {False, False, False, False}, {False, False, False, False}},
    TestID -> "Lazy-shape-numericity-and-zero-probes"
]

EndTestSection[]


BeginTestSection["shape - structural nodes"]

(* Operands are deliberately NON-SQUARE and pairwise distinct in rank: a shape
   rule that permutes, drops or joins the wrong index still reports the right
   answer on square operands, so a square fixture cannot see the drift this
   section exists to catch. *)

$m23 = ArrayReshape[Range[6], {2, 3}]
$m34 = ArrayReshape[Range[12], {3, 4}]
$m43 = ArrayReshape[Range[12], {4, 3}]

(* One node per head of the structuralNodeOperands table in Classification.wl.
   Both spellings of ArrayDot appear, since a lowered contraction emits the
   integer form and the index-pair form depending on the method, and Transpose
   appears inactive, which is the form a lazy contraction wraps its result in. *)

$structuralNodes = {
    Inactive[TensorProduct][$m23, $m34],
    Inactive[TensorContract][Inactive[TensorProduct][$m23, $m34], {{2, 3}}],
    Inactive[ArrayDot][$m23, $m34, {{2, 1}}],
    Inactive[ArrayDot][$m23, $m34, 1],
    Inactive[Dot][$m23, $m34],
    Inactive[Dot][$m23, $m34, $m43],
    Inactive[ArrayReshape][$m23, {3, 2}],
    Inactive[Transpose][$m23, {2, 1}],
    Inactive[Transpose][$m23],
    Inactive[Transpose][Inactive[ArrayDot][$m23, $m34, {{2, 1}}], {2, 1}]
}

(* The classification tier and the shape tier answer for the SAME vocabulary:
   every node admitted as a container reports the shape its Activate has.  A
   head admitted in Classification.wl with no matching ArrayDimensions clause
   fails here with {} against the true dimensions. *)
VerificationTest[
    Map[
        {ArrayContainerQ[#], ArrayDimensions[#] === Dimensions[Activate[#]]} &,
        $structuralNodes
    ],
    ConstantArray[{True, True}, Length[$structuralNodes]],
    TestID -> "shape-structural-node-shapes-agree-with-activate"
]

(* A shape that came back {} must never leak out of the index arithmetic: the
   enclosing node has to answer {} quietly rather than emit Delete::partw and
   hand back an unevaluated Delete expression that fails ListQ. *)
VerificationTest[
    With[{unknown = Inactive[TensorContract][Inactive[TensorProduct][unknownA, unknownB], {{1, 2}}]},
        Map[
            With[{dims = ArrayDimensions[#]}, {dims, ListQ[dims]}] &,
            {
                unknown,
                Inactive[TensorContract][Inactive[TensorProduct][unknown, $m43], {{2, 3}}],
                Inactive[ArrayDot][unknown, $m34, {{2, 1}}],
                Inactive[Transpose][unknown, {2, 1}],
                Inactive[Dot][unknown, $m34]
            }
        ]
    ],
    ConstantArray[{{}, True}, 5],
    TestID -> "shape-structural-unknown-operand-gives-empty-quietly"
]

(* Plus threads over a scalar, so a rank-0 operand constrains nothing and the
   container shape survives; operands that genuinely disagree still give {}. *)
VerificationTest[
    {
        ArrayDimensions[MatrixSymbol["A", {2, 3}] + 1],
        ArrayRank[MatrixSymbol["A", {2, 3}] + 1],
        ArrayDimensions[MatrixSymbol["A", {2, 3}] + MatrixSymbol["B", {3, 2}]]
    },
    {{2, 3}, 2, {}},
    TestID -> "shape-plus-broadcasts-scalar-operand"
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
