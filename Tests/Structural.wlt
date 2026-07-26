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

$pf = ParametricNDSolveValue[{v'[t] == {{0, pa}, {-pa, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}, {pa}]
$pfLazy = $pf[aa][tt]
$pfM = ParametricNDSolveValue[{m'[t] == {{0, pa}, {-pa, 0}} . m[t], m[0] == {{1., 0.}, {0., 1.}}}, m, {t, 0, 1}, {pa}]
$pfLazyM = $pfM[aa][tt]
$fn = Function[fnT, {{Cos[fnT], -Sin[fnT]}, {Sin[fnT], Cos[fnT]}}]
$pw = Piecewise[{{{{1., 2.}, {3., 4.}}, zz < 0}}, {{5., 6.}, {7., 8.}}]

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


BeginTestSection["structural - deferred structural trees"]

(* Non-square operands again: on square ones a wrongly sliced Part still has the
   right SHAPE and the wrong value goes unnoticed downstream. *)

$dm23 = ArrayReshape[Range[6], {2, 3}]
$dm34 = ArrayReshape[Range[12], {3, 4}]

$deferredTrees = {
    Inactive[TensorProduct][$dm23, $dm34],
    Inactive[TensorContract][Inactive[TensorProduct][$dm23, $dm34], {{2, 3}}],
    Inactive[ArrayDot][$dm23, $dm34, {{2, 1}}],
    Inactive[Transpose][$dm23, {2, 1}]
}

(* Part on a deferred tree must address the ARRAY, not the expression tree.  For
   Inactive[TensorProduct] the tree reading even has the right shape - the first
   factor - so this compares values against Part of the activated node. *)
VerificationTest[
    Map[ArrayPart[#, {1}] === Part[Activate[#], 1] &, $deferredTrees],
    ConstantArray[True, Length[$deferredTrees]],
    TestID -> "structural-part-deferred-tree-matches-activate"
]

VerificationTest[
    Map[ArrayPart[#, {2, 1}] === Part[Activate[#], 2, 1] &, $deferredTrees],
    ConstantArray[True, Length[$deferredTrees]],
    TestID -> "structural-part-deferred-tree-multi-index"
]

(* A tree carrying a symbolic container has no materialization and no structural
   slice rule, so ArrayPart declines it instead of handing back an operand of
   the node, which for a tensor product would be a rank-2 answer where rank 3 is
   required. *)
VerificationTest[
    With[{symbolicTree = Inactive[TensorProduct][MatrixSymbol["A", {2, 3}], MatrixSymbol["B", {3, 4}]]},
        {
            ArraySymbolicQ[symbolicTree],
            Head[ArrayPart[symbolicTree, {1}]],
            ArrayPart[$mat, {1}]
        }
    ],
    {True, ArrayPart, VectorSymbol["M"[1], 3, Reals]},
    TestID -> "structural-part-symbolic-tree-declines"
]

(* An element-level map over a deferred tree maps the ELEMENTS.  Applying f to
   the node - the leafless-symbolic rule - would rewrite the contraction
   specification too: N turns {{2, 3}} into {{2., 3.}} and TensorContract then
   rejects it, and #*2& gives a scalar multiple of the node rather than an
   array of mapped values. *)
VerificationTest[
    Map[ArrayMap[N, #] === N[Activate[#]] &, $deferredTrees],
    ConstantArray[True, Length[$deferredTrees]],
    TestID -> "structural-map-deferred-tree-matches-activate"
]

VerificationTest[
    With[{tree = Inactive[TensorContract][Inactive[TensorProduct][$dm23, $dm34], {{2, 3}}]},
        {ArrayMap[# * 2 &, tree], ArrayDimensions[ArrayMap[# * 2 &, tree]]}
    ],
    {2 * Activate[Inactive[TensorContract][Inactive[TensorProduct][$dm23, $dm34], {{2, 3}}]], {2, 4}},
    TestID -> "structural-map-deferred-tree-is-an-array"
]

(* The leafless symbolic tree keeps the whole-container rule, which is what lets
   Simplify and friends distribute over it. *)
VerificationTest[
    ArrayMap[Simplify, $mat],
    Simplify[$mat],
    TestID -> "structural-map-symbolic-container-unchanged"
]

EndTestSection[]


BeginTestSection["structural - admitted lazy heads"]

(* ONE-EVALUATION PROOF.  A delayed rule counts entries into the lazy
   expression: the whole-array container is entered once per parameter, and the
   result is an explicit container.  The contrast test below counts the same
   rules against the per-scalar expansion of the same containers, where the
   count is once per parameter PER ELEMENT. *)
VerificationTest[
    Module[{entries},
        Map[
            Function[container,
                entries = 0;
                {
                    ArrayExplicitQ[
                        ArrayReplaceAll[
                            container,
                            {tau :> (entries++; 0.5), aa :> (entries++; 1.), tt :> (entries++; 0.5), zz :> (entries++; -1), fnT :> (entries++; 0.5)}
                        ]
                    ],
                    entries
                }
            ],
            {$lazy, $pfLazy, $pw, $fn}
        ]
    ],
    {{True, 1}, {True, 2}, {True, 1}, {True, 1}},
    TestID -> "Lazy-replaceall-one-evaluation-per-parameter"
]

VerificationTest[
    Module[{entries},
        Map[
            Function[container,
                entries = 0;
                ArrayMaterialize[container] /. {tau :> (entries++; 0.5), aa :> (entries++; 1.), tt :> (entries++; 0.5), zz :> (entries++; -1)};
                entries
            ],
            {$lazy, $pfLazy, $pw}
        ]
    ],
    {2, 4, 4},
    TestID -> "Lazy-materialized-form-evaluates-per-element"
]

(* Function is the one admitted head that can carry a counter inside itself, so
   the whole-array claim is checked directly on head entries and not only on
   substitution sites.  The shape probe enters the closure once and is cached,
   so the count after the probe is entirely due to the substitution. *)
(* The counter and the container are globals on purpose: Module renames a
   Function parameter that shares a scope with its locals, and the rule below is
   keyed on that parameter by name. *)
VerificationTest[
    (
        $closureCalls = 0;
        $closure = Function[cT, ($closureCalls++; {{Cos[cT], -Sin[cT]}, {Sin[cT], Cos[cT]}})];
        $closureShape = ArrayDimensions[$closure];
        $closureCalls = 0;
        $closureApplied = ArrayReplaceAll[$closure, cT -> 0.5];
        {
            $closureShape,
            $closureCalls,
            Developer`PackedArrayQ[$closureApplied],
            $closureApplied == {{Cos[0.5], -Sin[0.5]}, {Sin[0.5], Cos[0.5]}}
        }
    ),
    {{2, 2}, 1, True, True},
    TestID -> "Lazy-Function-substitution-is-one-closure-call"
]

(* A rule keyed on a bound parameter APPLIES the Function; a plain ReplaceAll
   would rewrite the parameter specification into Function[0.5, ...].  Rules on
   free symbols of the body keep the container lazy. *)
VerificationTest[
    With[{substituted = ArrayReplaceAll[Function[gT, {Cos[gT + gPhase], Sin[gT]}], gPhase -> 0]},
        {ArrayLazyQ[substituted], ArrayReplaceAll[substituted, gT -> 0.5] == {Cos[0.5], Sin[0.5]}}
    ],
    {True, True},
    TestID -> "Lazy-Function-free-symbol-substitution-stays-lazy"
]

(* Lazy-preserving structural ops: a Function composes, a Piecewise transforms
   its branch values in place, and both stay lazy. *)
VerificationTest[
    With[{transposed = ArrayTranspose[$fn, {2, 1}]},
        {ArrayLazyQ[transposed], ArrayReplaceAll[transposed, fnT -> 0.5] == Transpose[ArrayReplaceAll[$fn, fnT -> 0.5]]}
    ],
    {True, True},
    TestID -> "Lazy-Function-transpose-stays-lazy"
]

VerificationTest[
    With[{transposed = ArrayTranspose[$pw, {2, 1}]},
        {ArrayLazyQ[transposed], ArrayReplaceAll[transposed, zz -> -1]}
    ],
    {True, {{1., 3.}, {2., 4.}}},
    TestID -> "Lazy-Piecewise-transpose-stays-lazy"
]

(* A ParametricFunction has no value grid to remap and no body to compose, so
   its registry entry declares no rebuild and the op materializes through
   ArrayMaterialize.  The result is no longer lazy, and it still substitutes to
   the same array. *)
VerificationTest[
    With[{transposed = ArrayTranspose[$pfLazyM, {2, 1}]},
        {
            ArrayLazyQ[transposed],
            MatchQ[transposed, {{_Indexed, _Indexed}, {_Indexed, _Indexed}}],
            (transposed /. {aa -> 1., tt -> 0.5}) == Transpose[ArrayReplaceAll[$pfLazyM, {aa -> 1., tt -> 0.5}]]
        }
    ],
    {False, True, True},
    TestID -> "Lazy-ParametricFunction-transpose-materializes"
]

VerificationTest[
    With[{mapped = ArrayMap[# + 1 &, $pw]},
        {ArrayLazyQ[mapped], ArrayReplaceAll[mapped, zz -> -1]}
    ],
    {True, {{2., 3.}, {4., 5.}}},
    TestID -> "Lazy-Piecewise-map-stays-lazy"
]

VerificationTest[
    With[{mapped = ArrayMap[Abs, $fn]},
        {ArrayLazyQ[mapped], ArrayReplaceAll[mapped, fnT -> 0.5] == Map[Abs, ArrayReplaceAll[$fn, fnT -> 0.5], {2}]}
    ],
    {True, True},
    TestID -> "Lazy-Function-map-stays-lazy"
]

VerificationTest[
    With[{mapped = ArrayMap[Abs, $pfLazy]},
        {ArrayLazyQ[mapped], (mapped /. {aa -> 1., tt -> 0.5}) == Abs[ArrayReplaceAll[$pfLazy, {aa -> 1., tt -> 0.5}]]}
    ],
    {False, True},
    TestID -> "Lazy-ParametricFunction-map-materializes"
]

(* Part on an inert lazy form reaches the expression TREE: ifn[t][[1]] gives t,
   a Piecewise indexes its own branch list, and an unapplied Function hands back
   its parameter.  ArrayPart intercepts all three by expanding per scalar. *)
VerificationTest[
    {
        $if[tau][[1]],
        ArrayPart[$pw, {1, 2}],
        ArrayPart[$fn, {2, 1}],
        (ArrayPart[$pfLazy, {1}] /. {aa -> 1., tt -> 0.5}) == First[ArrayReplaceAll[$pfLazy, {aa -> 1., tt -> 0.5}]]
    },
    {tau, Piecewise[{{2., zz < 0}}, 6.], Function[fnT, Sin[fnT]], True},
    TestID -> "Lazy-part-intercepts-expression-tree"
]

(* Conjugation takes the same rebuild-or-materialize route: it cannot simply
   materialize, because Conjugate of an unapplied Function is inert and no later
   substitution can fix it. *)
VerificationTest[
    With[{conjugated = ArrayConjugate[$fn]},
        {ArrayLazyQ[conjugated], ArrayReplaceAll[conjugated, fnT -> 0.5] == Conjugate[ArrayReplaceAll[$fn, fnT -> 0.5]]}
    ],
    {True, True},
    TestID -> "Lazy-Function-conjugate-stays-lazy"
]

EndTestSection[]
