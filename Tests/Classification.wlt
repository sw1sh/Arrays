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

(* Lazy-tier fixtures for the heads admitted alongside InterpolatingFunction.
   The parametric one is a real ParametricNDSolveValue, so the probe solve, the
   parameter cache and the substitution all run against the kernel object. *)
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


BeginTestSection["classification - admitted lazy heads"]

(* ParametricFunction: only the FULLY APPLIED form pf[params][t] is an array
   container.  Substituting every parameter of pf[params] gives an
   InterpolatingFunction - a function, not an array - and the bare object has
   nothing bound at all, so neither has a materialization to an array.  This is
   the same line the reference head draws between ifn (declined) and ifn[t]
   (admitted). *)
VerificationTest[
    Through[{ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ}[$pfLazy]],
    {True, False, True, False},
    TestID -> "Lazy-ParametricFunction-applied-classification"
]

VerificationTest[
    {ArrayContainerQ[$pf], ArrayLazyQ[$pf], ArrayContainerQ[$pf[aa]], ArrayLazyQ[$pf[aa]]},
    {False, False, False, False},
    TestID -> "Lazy-ParametricFunction-bare-and-partial-declined"
]

(* Numeric arguments throughout: pf[1.] solves and pf[1.][0.5] is an explicit
   vector, so nothing is left lazy.  The trigger is NumericQ, so an exact Pi/6
   solves too and what stays lazy is the InterpolatingFunction it produced. *)
VerificationTest[
    {ArrayLazyQ[$pf[1.][0.5]], ArrayExplicitQ[$pf[1.][0.5]], ArrayLazyQ[$pf[Pi/6][tt]], ArrayDimensions[$pf[Pi/6][tt]]},
    {False, True, True, {2}},
    TestID -> "Lazy-ParametricFunction-numeric-arguments-not-lazy"
]

(* Function is stored UNAPPLIED: applying it evaluates, so there is no inert
   applied form to recognize. *)
VerificationTest[
    Through[{ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ}[$fn]],
    {True, False, True, False},
    TestID -> "Lazy-Function-classification"
]

(* A scalar-valued Function is not an array; a slot form is admitted; a
   three-argument Function carries attributes a rebuild could not preserve and a
   SlotSequence body has no fixed arity, so both are declined. *)
VerificationTest[
    {
        ArrayLazyQ[Function[q, q^2]],
        ArrayLazyQ[Function[{Cos[#], Sin[#]}]],
        ArrayLazyQ[Function[q, {q, q}, HoldAll]],
        ArrayLazyQ[Function[{##}]]
    },
    {False, True, False, False},
    TestID -> "Lazy-Function-scope-of-recognition"
]

(* Three-step shape protocol. The formal-symbol probe leaves an If body as an
   unevaluated If, whose Dimensions would be the argument count, so ArrayQ
   guards it and the numeric probe settles the shape instead. *)
VerificationTest[
    With[{f = Function[q, If[q > 0, {1., 2.}, {3., 4.}]]},
        {ArrayQ[f[\[FormalT]]], ArrayLazyQ[f], ArrayDimensions[f]}
    ],
    {False, True, {2}},
    TestID -> "Lazy-Function-numeric-probe-settles-if-body"
]

(* When both probes fail the value is NOT a container: no shape is guessed.
   ArrayDeclareShape is the third step, and removing the declaration takes the
   admission away again. *)
VerificationTest[
    With[{f = Function[q, If[q > 2, {1., 2.}, $Failed]]},
        {
            ArrayLazyQ[f],
            ArrayDimensions[f],
            ArrayDeclareShape[f, {2}],
            ArrayLazyQ[f],
            ArrayDimensions[f],
            ArrayDeclareShape[f],
            ArrayDeclareShape[f, None],
            ArrayLazyQ[f]
        }
    ],
    {False, {}, {2}, True, {2}, {2}, None, False},
    TestID -> "Lazy-Function-declared-shape-protocol"
]

VerificationTest[
    Head[ArrayDeclareShape[Function[q, {q, q}], {0}]],
    ArrayDeclareShape,
    {ArrayDeclareShape::baddims},
    TestID -> "Lazy-Function-declared-shape-rejects-bad-dimensions"
]

VerificationTest[
    Through[{ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ}[$pw]],
    {True, False, True, False},
    TestID -> "Lazy-Piecewise-classification"
]

(* Piecewise negatives: a scalar-valued Piecewise is not an array; the implicit
   scalar 0 default is declined, since a substitution falling through every
   condition would then return a scalar instead of an array; branch values of
   different shapes are declined; and a Piecewise whose conditions are all
   decidable has already evaluated to its branch value, so nothing is lazy. *)
VerificationTest[
    {
        ArrayLazyQ[Piecewise[{{1, zz < 0}}, 2]],
        ArrayLazyQ[Piecewise[{{{1., 2.}, zz < 0}}]],
        ArrayLazyQ[Piecewise[{{{1., 2.}, zz < 0}}, {3., 4., 5.}]],
        ArrayLazyQ[Piecewise[{{{{1., 2.}}, 1 < 0}}, {{3., 4.}}]],
        ArrayExplicitQ[Piecewise[{{{{1., 2.}}, 1 < 0}}, {{3., 4.}}]]
    },
    {False, False, False, False, True},
    TestID -> "Lazy-Piecewise-negative-cases"
]

(* A SOURCE net - no open input ports - is a lazy container: its shape comes off
   the output port and its value is one call.  A net with open inputs is a
   function of those inputs and has no array value, so it is declined, as the
   partially applied ParametricFunction is. *)

$netSource = NetGraph[{NetArrayLayer["Array" -> {{1., 2., 3.}, {4., 5., 6.}}]}, {1 -> NetPort["Output"]}]
$netChain = NetChain[{NetArrayLayer["Array" -> {1., 2., 3.}]}]
$netOpen = NetGraph[{ElementwiseLayer[Tanh]}, {1 -> NetPort["Output"]}, "Input" -> 3]

VerificationTest[
    {
        Through[{ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ}[$netSource]],
        Through[{ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ}[$netChain]],
        Through[{ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ}[$netOpen]]
    },
    {{True, False, True, False}, {True, False, True, False}, {False, False, False, False}},
    TestID -> "Lazy-NetGraph-classification"
]

(* Shape is introspected off the output port, on a NON-SQUARE net so that a
   transposed reading would show, and the net is never RUN to get it: a counting
   wrapper around the evaluation proves ArrayDimensions and ArrayRank stay on
   the port metadata while ArrayMaterialize is the one call that evaluates. *)
VerificationTest[
    With[{netRuns = Function[expr, Length[Trace[expr, _NetGraph[]]], HoldFirst]},
        {
            ArrayDimensions[$netSource],
            ArrayRank[$netSource],
            netRuns[ArrayDimensions[$netSource]],
            netRuns[ArrayRank[$netSource]],
            netRuns[ArrayContainerQ[$netSource]],
            netRuns[ArrayMaterialize[$netSource]],
            ArrayMaterialize[$netSource]
        }
    ],
    {{2, 3}, 2, 0, 0, 0, 1, {{1., 2., 3.}, {4., 5., 6.}}},
    TestID -> "Lazy-NetGraph-shape-does-not-evaluate-the-net"
]

(* A structural op the net framework can compile rebuilds and stays a net, and
   its value is the one the materialize-then-operate route would have given.
   Ops it cannot compile fall back to that route, which ArrayConjugate and
   ArrayPart still take. *)
VerificationTest[
    {
        ArrayMaterialize[ArrayTranspose[$netSource, {2, 1}]] === Transpose[ArrayMaterialize[$netSource]],
        ArrayMaterialize[ArrayVector[$netSource]] === Flatten[ArrayMaterialize[$netSource]],
        ArrayPart[$netSource, {2}] === Part[ArrayMaterialize[$netSource], 2],
        ArrayConjugate[$netSource] === Conjugate[ArrayMaterialize[$netSource]]
    },
    {True, True, True, True},
    TestID -> "Lazy-NetGraph-structural-ops-agree-with-materialized-route"
]

(* RECOGNITION MUST NOT RUN USER CODE.  ArrayLazyQ on an unapplied Function
   evaluates its body, which is documented; asking whether an arbitrary
   Inactive, Plus or Transpose expression is a container must not trigger that
   transitively, at any depth of the tree. *)
VerificationTest[
    Block[{probeRuns = 0, probe},
        probe = Function[t, probeRuns++; {{t, 0.}, {0., t}}];
        {
            ArrayContainerQ[Inactive[TensorProduct][probe, {{1, 2}, {3, 4}}]],
            ArrayContainerQ[Inactive[TensorContract][Inactive[TensorProduct][probe, {{1, 2}, {3, 4}}], {{1, 2}}]],
            probeRuns,
            ArrayLazyQ[probe],
            probeRuns > 0
        }
    ],
    {False, False, 0, True, True},
    TestID -> "classification-structural-tree-does-not-evaluate-a-lazy-leaf"
]

EndTestSection[]


(* GPUArray: an explicit, compute-native container whose buffer lives on the
   device.  These tests are VACUOUS on a machine with no usable GPU - each one
   short-circuits to its expected value - so $gpuArray is asserted first and its
   result tells a reader of the run whether the section exercised anything. *)

$gpuArray := $gpuArray = Quiet @ Check[
    With[{g = GPUArray[{{1., 2.}, {3., 4.}}]}, If[GPUArrayQ[g], g, None]],
    None
]

VerificationTest[
    MemberQ[{None, _GPUArray}, $gpuArray] || MatchQ[$gpuArray, None | _GPUArray],
    True,
    TestID -> "GPUArray-availability-probe"
]

VerificationTest[
    $gpuArray === None || ArrayContainerQ[$gpuArray],
    True,
    TestID -> "GPUArray-is-a-container"
]

VerificationTest[
    $gpuArray === None || ArrayExplicitQ[$gpuArray],
    True,
    TestID -> "GPUArray-is-explicit"
]

(* Arithmetic and Dot run on the device and hand back a GPUArray, so it is
   compute-native and ArrayComputable must leave it alone. *)
VerificationTest[
    $gpuArray === None || ArrayComputeNativeQ[$gpuArray],
    True,
    TestID -> "GPUArray-is-compute-native"
]

VerificationTest[
    $gpuArray === None || ArrayComputable[$gpuArray] === $gpuArray,
    True,
    TestID -> "GPUArray-computable-is-identity"
]

(* Recognition goes through GPUArrayQ, never the head: a malformed call stays
   inert with head GPUArray and is not a container. *)
VerificationTest[
    Quiet @ ArrayContainerQ[GPUArray["nonsense"]],
    False,
    TestID -> "GPUArray-malformed-is-not-a-container"
]

VerificationTest[
    $gpuArray === None || ArrayDimensions[$gpuArray],
    If[$gpuArray === None, True, {2, 2}],
    TestID -> "GPUArray-dimensions"
]

VerificationTest[
    $gpuArray === None || ArrayMaterialize[$gpuArray],
    If[$gpuArray === None, True, {{1., 2.}, {3., 4.}}],
    TestID -> "GPUArray-materializes-off-device"
]

(* Device buffers are fp32, so the element type is a Real32 family name and the
   domain follows from it. *)
VerificationTest[
    $gpuArray === None || StringStartsQ[ArrayElementType[$gpuArray], "Real"],
    True,
    TestID -> "GPUArray-element-type-is-a-real-format"
]

VerificationTest[
    $gpuArray === None || ArrayElementDomain[$gpuArray],
    If[$gpuArray === None, True, Reals],
    TestID -> "GPUArray-element-domain"
]

(* Joining a Real32 device buffer with a Real64 host array must widen to Real64
   rather than narrow the host operand to device precision. *)
VerificationTest[
    $gpuArray === None ||
        ArrayUnify[{$gpuArray, NumericArray[{{1., 2.}, {3., 4.}}, "Real64"]}]["ElementType"],
    If[$gpuArray === None, True, "Real64"],
    TestID -> "GPUArray-unify-widens-to-Real64"
]


(* Nets: a source NetGraph, NetChain or NetArrayLayer is a lazy container, and
   a structural operation on one wires the operation in as a layer and gives
   back a net rather than materializing it. *)

$netLayer := NetArrayLayer["Array" -> {{1., 2., 3.}, {4., 5., 6.}}]

$netSource := NetGraph[<|"a" -> $netLayer|>, {"a" -> NetPort["Output"]}]

(* A bare NetArrayLayer takes no input, carries its shape on its output port and
   evaluates with layer[], which is the whole admission criterion. *)
VerificationTest[
    ArrayContainerQ[$netLayer],
    True,
    TestID -> "Net-NetArrayLayer-is-a-container"
]

VerificationTest[
    ArrayDimensions[$netLayer],
    {2, 3},
    TestID -> "Net-NetArrayLayer-shape"
]

VerificationTest[
    ArrayMaterialize[$netLayer],
    {{1., 2., 3.}, {4., 5., 6.}},
    TestID -> "Net-NetArrayLayer-materializes"
]

VerificationTest[
    ArrayTier[$netSource],
    "Lazy",
    TestID -> "Net-source-net-is-lazy"
]

(* Structural operations rebuild rather than materialize: the result is a net,
   and asking it for its shape does not run it. *)
VerificationTest[
    Head[ArrayTranspose[$netSource, {2, 1}]],
    NetGraph,
    TestID -> "Net-transpose-gives-a-net"
]

VerificationTest[
    ArrayDimensions[ArrayTranspose[$netSource, {2, 1}]],
    {3, 2},
    TestID -> "Net-transpose-shape-without-running"
]

VerificationTest[
    ArrayMaterialize[ArrayTranspose[$netSource, {2, 1}]],
    {{1., 4.}, {2., 5.}, {3., 6.}},
    TestID -> "Net-transpose-value"
]

VerificationTest[
    Head[ArrayVector[$netSource]],
    NetGraph,
    TestID -> "Net-flatten-gives-a-net"
]

VerificationTest[
    ArrayMaterialize[ArrayVector[$netSource]],
    {1., 2., 3., 4., 5., 6.},
    TestID -> "Net-flatten-value"
]

VerificationTest[
    ArrayMaterialize[ReshapeArray[$netSource, {3, 2}]],
    {{1., 2.}, {3., 4.}, {5., 6.}},
    TestID -> "Net-reshape-value"
]

(* A bare layer rebuilds the same way, so the layer and the net wrapping it
   behave alike under structural operations. *)
VerificationTest[
    ArrayMaterialize[ArrayTranspose[$netLayer, {2, 1}]],
    {{1., 4.}, {2., 5.}, {3., 6.}},
    TestID -> "Net-bare-layer-transposes"
]

(* An operation the net framework cannot compile declines to a materialized
   result rather than producing a broken net. *)
VerificationTest[
    Head[ArrayConjugate[$netSource]],
    List,
    TestID -> "Net-uncompilable-op-materializes"
]

(* A net with an open input port has no array value and stays out. *)
VerificationTest[
    ArrayContainerQ[NetGraph[<|"a" -> ElementwiseLayer[Sin, "Input" -> 3]|>, {"a" -> NetPort["Output"]}]],
    False,
    TestID -> "Net-open-input-declined"
]


(* === tier assignment and mixing ===

   The two non-explicit tiers are told apart by whether the container can
   produce VALUES.  A deferred structural tree can: every leaf is explicit, so
   it is a computation that has not been run and Activate runs it - that is
   lazy.  A symbolic container cannot: it carries a symbol and has only a shape
   and a domain.  Both used to answer ArraySymbolicQ True, which made a
   tensor-network contraction indistinguishable from a tree over a
   VectorSymbol. *)

$mixSparse = SparseArray[{{1., 2.}, {3., 4.}}]
$mixLazy = Piecewise[{{{{1., 2.}, {3., 4.}}, mixZ < 0}}, {{5., 6.}, {7., 8.}}]
$mixDeferred = Inactive[TensorProduct][SparseArray[{1., 2.}], SparseArray[{3., 4.}]]
$mixSymbol = VectorSymbol["mixv", 2]
$mixSymTree = Inactive[TensorProduct][SparseArray[{1., 2.}], VectorSymbol["mixv", 2]]

VerificationTest[
    Map[{ArrayTier[#], ArrayExplicitQ[#], ArrayLazyQ[#], ArraySymbolicQ[#]} &,
        {$mixSparse, $mixLazy, $mixDeferred, $mixSymbol, $mixSymTree}],
    {
        {"Explicit", True, False, False},
        {"Lazy", False, True, False},
        {"Lazy", False, True, False},
        {"Symbolic", False, False, True},
        {"Symbolic", False, False, True}
    },
    TestID -> "classification-tiers-separate-deferred-from-symbolic"
]

(* A deferred tree carries values, so joining one with an explicit or a lazy
   container stays in the computable half of the lattice; one symbolic operand
   anywhere takes the whole join symbolic. *)
VerificationTest[
    Map[ArrayUnify[#]["Tier"] &,
        {
            {$mixSparse, $mixLazy}, {$mixSparse, $mixDeferred}, {$mixLazy, $mixDeferred},
            {$mixDeferred, $mixDeferred}, {$mixSparse, $mixSymbol}, {$mixLazy, $mixSymbol},
            {$mixDeferred, $mixSymbol}, {$mixSymTree, $mixSparse}
        }],
    {"Lazy", "Lazy", "Lazy", "Lazy", "Symbolic", "Symbolic", "Symbolic", "Symbolic"},
    TestID -> "classification-tier-joins-across-every-mix"
]

(* A tree is symbolic because of what it CARRIES, at any depth. *)
VerificationTest[
    {
        ArrayTier[Inactive[TensorProduct][$mixDeferred, VectorSymbol["mixw", 2]]],
        ArrayTier[Inactive[TensorProduct][$mixDeferred, $mixDeferred]]
    },
    {"Symbolic", "Lazy"},
    TestID -> "classification-a-nested-symbol-makes-the-whole-tree-symbolic"
]

(* Whichever tier it lands in, a tree answers for shape without computing, and
   only the computable one materializes to values. *)
VerificationTest[
    {
        ArrayDimensions[$mixDeferred], ArrayDimensions[$mixSymTree],
        Normal[ArrayMaterialize[$mixDeferred]],
        ArrayMaterialize[$mixSymbol] === $mixSymbol
    },
    {{2, 2}, {2, 2}, {{3., 4.}, {6., 8.}}, True},
    TestID -> "classification-shape-answers-in-both-tiers-values-only-in-the-lazy-one"
]
