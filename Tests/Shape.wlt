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
$scalarIf = NDSolveValue[{u'[t] == - u[t], u[0] == 1.}, u, {t, 0, 1}]

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

(* The BARE array-valued InterpolatingFunction answers its shape off its own
   "OutputDimensions" property with no probe; a scalar-valued interpolant
   answers {} there and so has no array shape in the bare form either. *)
VerificationTest[
    {ArrayDimensions[$if], ArrayRank[$if], ArrayDimensions[$if'], ArrayDimensions[$scalarIf]},
    {{2}, 1, {2}, {}},
    TestID -> "shape-dimensions-bare-interpolatingfunction"
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

(* A rank-0 operand is a SCALAR FIELD, not an unknown shape: its gradient by n
   coordinates is rank-n.  Routing this through shapeFromOperands, whose only
   test is MemberQ[operandShapes, {}], reported {} and silently cost every
   scalar derivative its index - which is how a covariant derivative of a
   scalar field reaches this clause. *)

VerificationTest[
    ArrayDimensions[Inactive[D][phi, {{p1, p2}}]],
    {2},
    TestID -> "shape-dimensions-inactive-d-scalar-field-gradient"
]

VerificationTest[
    ArrayDimensions[Inactive[D][phi, {{p1, p2}, 2}]],
    {2, 2},
    TestID -> "shape-dimensions-inactive-d-scalar-field-hessian"
]

(* The trade-off this clause accepts, pinned so it is a decision and not a
   surprise: an operand shape of {} means "scalar" OR "no known shape", and the
   two are not distinguishable here, so an UNKNOWN operand is read as a scalar
   and the node reports the gradient shape rather than {}.  The scalar reading
   is the one that carries information, and the alternative cost every real
   scalar field its derivative index.  The result is still validated, so a
   specification that yields no integer list gives {} quietly. *)

VerificationTest[
    ArrayDimensions[Inactive[D][{{1, 2}, {3}}, {{p1, p2}}]],
    {2},
    TestID -> "shape-dimensions-inactive-d-unknown-operand-reads-as-scalar"
]

VerificationTest[
    ArrayDimensions[Inactive[D][phi, {p1, p2}]],
    {},
    TestID -> "shape-dimensions-inactive-d-nonlist-specification"
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

(* The paclet's own shape-only operations are admitted as nodes too, in the
   form they take when their operand is symbolic and they cannot run. Activate
   does not compute those - they fire as soon as the operand becomes explicit,
   so they are only ever seen wrapping a symbolic one - and they are checked
   here against the shape their evaluated counterpart has instead. *)

$symOperand = MatrixSymbol["M", {2, 3}]
$expOperand = ConstantArray[1, {2, 3}]

VerificationTest[
    Map[
        {ArrayContainerQ[First[#]], ArrayDimensions[First[#]] === Last[#]} &,
        {
            {ArrayVector[$symOperand], Dimensions[ArrayVector[$expOperand]]},
            {ReshapeArray[$symOperand, {6}], Dimensions[ReshapeArray[$expOperand, {6}]]},
            {PadArray[$symOperand, 1], Dimensions[PadArray[$expOperand, 1]]},
            {PadArray[$symOperand, {1, 2}], Dimensions[PadArray[$expOperand, {1, 2}]]},
            {PadArray[$symOperand, {{1, 2}, {3, 4}}], Dimensions[PadArray[$expOperand, {{1, 2}, {3, 4}}]]}
        }
    ],
    ConstantArray[{True, True}, 5],
    TestID -> "shape-unevaluated-operation-nodes-agree-with-evaluated"
]

(* A pad specification that does not give an array claims no shape: a partial
   per-level spec pads the outer level with scalars beside blocks and goes
   ragged, and trimming a level to zero collapses what Dimensions reports. *)
VerificationTest[
    {
        ArrayDimensions[PadArray[ArraySymbol["A", {2, 3, 4}], {{1, 2}}]],
        ArrayDimensions[PadArray[$symOperand, -1]]
    },
    {{}, {}},
    TestID -> "shape-pad-node-without-an-array-result-gives-empty"
]

(* An operand that is not a container leaves the call a plain unevaluated
   expression, not an array. *)
VerificationTest[
    {ArrayContainerQ[ArrayVector[notAnArray]], ArrayContainerQ[ReshapeArray[notAnArray, {2}]]},
    {False, False},
    TestID -> "shape-unevaluated-operation-on-non-array-is-not-a-container"
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


(* The List and SparseArray fast clauses must agree with the generic
   TensorDimensions probe they shadow, ragged input included: Dimensions alone
   would report the depth a ragged list is rectangular to rather than refusing
   it, so the clause has to verify rectangularity before trusting it. *)

VerificationTest[
    ArrayDimensions[SparseArray[{{1, 1, 1} -> 1}, {3, 4, 5}]],
    {3, 4, 5},
    TestID -> "shape-fast-sparsearray"
]

VerificationTest[
    ArrayDimensions[Developer`ToPackedArray[{{1., 2.}, {3., 4.}}]],
    {2, 2},
    TestID -> "shape-fast-packed-list"
]

VerificationTest[
    ArrayDimensions[{{1, 2}, {3}}],
    {},
    TestID -> "shape-fast-ragged-list-refused"
]

VerificationTest[
    ArrayDimensions[{{1, 2}, {3, x}}],
    {2, 2},
    TestID -> "shape-fast-unpacked-symbolic-list"
]

VerificationTest[
    ArrayDimensions[{}],
    {0},
    TestID -> "shape-fast-empty-list"
]

VerificationTest[
    ArrayDimensions[{{1, 2}, {3, 4}, {5, {6}}}],
    {},
    TestID -> "shape-fast-ragged-at-depth"
]

(* Dimensions is the whole shape only when the leaves have no shape of their
   own.  A list of SYMBOLIC containers stops Dimensions at the list level, so
   the fast clause has to hand such a list back to the TensorDimensions probe;
   answering {2} for a 2 x 3 array of vectors made squareMatrixQ - and through
   it every square-matrix constructor - disagree with TensorDimensions. *)

VerificationTest[
    ArrayDimensions[{VectorSymbol["fv", 3], VectorSymbol["fw", 3]}],
    {2, 3},
    TestID -> "shape-fast-list-of-symbolic-vectors"
]

VerificationTest[
    ArrayDimensions[{MatrixSymbol["fA", {2, 3}], MatrixSymbol["fB", {2, 3}]}],
    {2, 2, 3},
    TestID -> "shape-fast-list-of-symbolic-matrices"
]

(* A list that MIXES a symbolic leaf with an explicit one is the same array and
   takes the same route; the fast clause used to refuse it outright. *)
VerificationTest[
    ArrayDimensions[{VectorSymbol["fv", 3], {1, 2, 3}}],
    {2, 3},
    TestID -> "shape-fast-list-mixing-symbolic-and-explicit"
]

(* The assumption-registered spelling of the same thing, which is the form an
   Assuming-wrapped shape check produces. *)
VerificationTest[
    Assuming[
        {Element[fa, Vectors[3]], Element[fb, Vectors[3]]},
        ArrayDimensions[{fa, fb}]
    ],
    {2, 3},
    TestID -> "shape-fast-list-of-assumption-registered-vectors"
]

(* Leaves that are EXPLICIT containers keep the fast answer: a NumericArray
   leaf is opaque to TensorDimensions too, so both routes agree on {2}. *)
VerificationTest[
    ArrayDimensions[{NumericArray[{1., 2.}], NumericArray[{3., 4.}]}],
    {2},
    TestID -> "shape-fast-list-of-numericarrays"
]

(* With no VectorSymbol, MatrixSymbol or ArraySymbol in the data and no array
   domain in $Assumptions, a symbolic leaf is impossible and the per-leaf
   ArraySymbolicQ scan is skipped.  The budget sits between the two paths with
   two orders of magnitude to spare on each side: five gated calls cost
   milliseconds, five per-leaf scans of a million leaves cost seconds. *)
VerificationTest[
    Block[{$Assumptions = True},
        Module[{u = Developer`FromPackedArray[RandomReal[1, {1000, 1000}]]},
            {ArrayDimensions[u], First[AbsoluteTiming[Do[ArrayDimensions[u], {5}]]] < 1.25}
        ]
    ],
    {{1000, 1000}, True},
    TestID -> "shape-fast-unpacked-list-skips-the-leaf-scan"
]

EndTestSection[]
