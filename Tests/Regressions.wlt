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

(* Lazy Function fixtures.  Every one of them has its own parameter and its own
   free symbols, because the shape probe memo and the declaration table are
   keyed on the whole Function. *)

$fn2 = Function[{fnX, fnY}, {{fnX, fnY}, {fnY, fnX}}]
$fnM = Function[fnT4, {{Cos[fnT4], -Sin[fnT4]}, {2 Sin[fnT4], Cos[fnT4]}}]
$fnIf = Function[fnT2, If[fnT2 > 2, {1., 2.}]]
$fnTable = Function[fnT3, Table[1., {fnT3}]]
$fnConst = Function[fnT5, ConstantArray[fnT5, $fnN]]
$fnSide = Function[fnT6, ($fnHits++; {Sin[fnT6], Cos[fnT6]})]

$pwM = Piecewise[{{{{1., 2.}, {3., 4.}}, zzM < 0}}, {{5., 6.}, {7., 8.}}]


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

(* A rule keyed on SOME parameters of a multi-parameter Function curries: the
   binding used to be stripped out as bound and then dropped by the free-rules
   branch, so the container came back unchanged with no message. *)
VerificationTest[
    With[{curried = ArrayReplaceAll[$fn2, fnX -> 1.]},
        {ArrayLazyQ[curried], ArrayDimensions[curried], ArrayReplaceAll[curried, fnY -> 2.]}
    ],
    {True, {2, 2}, {{1., 2.}, {2., 1.}}},
    TestID -> "regression-lazy-function-partial-binding-curries"
]

(* A Dispatch table and an Association are rule specifications too: unrecognized,
   they counted as zero bound parameters and the ReplaceAll branch rewrote the
   parameter specification itself. *)
VerificationTest[
    {
        ArrayReplaceAll[$fn2, Dispatch[{fnX -> 1., fnY -> 2.}]],
        ArrayReplaceAll[$fn2, <|fnX -> 1., fnY -> 2.|>],
        ArrayReplaceAll[$fn2, Dispatch[{fnX -> 1.}]]
    },
    {{{1., 2.}, {2., 1.}}, {{1., 2.}, {2., 1.}}, Function[{fnY}, {{1., fnY}, {fnY, 1.}}]},
    TestID -> "regression-lazy-function-dispatch-and-association-rules"
]

(* A declared shape is the one case where the body is NOT an explicit array, so
   materialization may not map over it: it used to hand back an If of Functions
   that is not an array at all and leaked the private rewrap symbol. *)
VerificationTest[
    {
        ArrayLazyQ[$fnIf],
        ArrayDeclareShape[$fnIf, {2}],
        ArrayLazyQ[$fnIf],
        ArrayDimensions[$fnIf],
        ArrayQ[ArrayMaterialize[$fnIf]],
        ArrayReplaceAll[ArrayMaterialize[$fnIf], fnT2 -> 3],
        ArrayReplaceAll[ArrayPart[$fnIf, {1}], fnT2 -> 3],
        ArrayReplaceAll[$fnIf, fnT2 -> 3]
    },
    {False, {2}, True, {2}, True, {1., 2.}, 1., {1., 2.}},
    TestID -> "regression-lazy-function-declared-shape-materializes-array"
]

(* A probe value of {} is an ArrayQ whose shape is {0}: it used to be admitted
   as a rank-1 container of length zero that no declaration could correct. *)
VerificationTest[
    {
        ArrayLazyQ[$fnTable],
        ArrayDimensions[$fnTable],
        ArrayDeclareShape[$fnTable, {3}],
        ArrayDimensions[$fnTable],
        ArrayReplaceAll[$fnTable, fnT3 -> 3]
    },
    {False, {}, {3}, {3}, {1., 1., 1.}},
    TestID -> "regression-lazy-function-empty-probe-not-a-container"
]

(* The per-scalar expansion of a Function container is an array of unapplied
   scalar Functions, and a single element taken out of it is one: substituting
   either used to rewrite the parameter specification (Function::flpar). *)
VerificationTest[
    {
        ArrayReplaceAll[ArrayMaterialize[$fnM], fnT4 -> 0.37] === $fnM[0.37],
        ArrayReplaceAll[ArrayPart[$fnM, {1, 2}], fnT4 -> 0.37] === -Sin[0.37],
        ArrayReplaceAll[{ArrayPart[$fnM, {1, 1}], 2 ArrayPart[$fnM, {2, 1}]}, fnT4 -> 0.37] === {Cos[0.37], 4. Sin[0.37]}
    },
    {True, True, True},
    TestID -> "regression-lazy-function-scalar-elements-substitute"
]

(* A probed shape is a guess and it is memoized: a declaration overrides it, and
   removing the declaration re-probes instead of restoring the stale value. *)
VerificationTest[
    Block[{before, stale, declared, reprobed},
        $fnN = 2;
        before = ArrayDimensions[$fnConst];
        $fnN = 5;
        stale = ArrayDimensions[$fnConst];
        ArrayDeclareShape[$fnConst, {5}];
        declared = ArrayDimensions[$fnConst];
        ArrayDeclareShape[$fnConst, None];
        reprobed = ArrayDimensions[$fnConst];
        {before, stale, declared, reprobed}
    ],
    {{2}, {2}, {5}, {5}},
    TestID -> "regression-lazy-function-declared-shape-overrides-probe"
]

(* Recognizing an undeclared Function EVALUATES its body once - the documented
   contract - and a declared shape is the way to keep it from happening. *)
VerificationTest[
    Block[{declared, undeclared},
        $fnHits = 0;
        ArrayDeclareShape[$fnSide, {2}];
        declared = {ArrayLazyQ[$fnSide], ArrayDimensions[$fnSide], $fnHits};
        ArrayDeclareShape[$fnSide, None];
        ArrayLazyQ[$fnSide];
        ArrayLazyQ[$fnSide];
        undeclared = $fnHits;
        {declared, undeclared}
    ],
    {{True, {2}, 0}, 1},
    TestID -> "regression-lazy-function-declared-shape-skips-probe"
]

(* Off element level every lazy container materializes, whether or not its head
   has a rebuild: it used to depend on the presence of a Rebuild key, so the same
   call was answered for a ParametricFunction and left unevaluated for the rest. *)
VerificationTest[
    {
        Head /@ {ArrayMap[Total, $lazyM, {1}], ArrayMap[Total, $pwM, {1}], ArrayMap[Total, $fnM, {1}]},
        TrueQ[Max[Abs[(ArrayMap[Total, $lazyM, {1}] /. tau -> 0.5) - Map[Total, $ifM[0.5], {1}]]] < 1*^-4],
        ArrayReplaceAll[ArrayMap[Total, $fnM, {1}], fnT4 -> 0.37] === Map[Total, $fnM[0.37], {1}]
    },
    {{List, List, List}, True, True},
    TestID -> "regression-lazy-map-off-element-level-materializes"
]

(* A declaration on an expression whose head never reads one used to be recorded
   and returned as a success while changing nothing. *)
VerificationTest[
    {Head[ArrayDeclareShape[{1, 2, 3}, {7}]], ArrayDeclareShape[{1, 2, 3}], ArrayDimensions[{1, 2, 3}]},
    {ArrayDeclareShape, Missing["NotDeclared"], {3}},
    {ArrayDeclareShape::undeclarable},
    TestID -> "regression-declare-shape-refuses-undeclarable"
]

VerificationTest[
    {Head[ArrayDeclareShape[$fnM, {2, 2, 2, 2}]], Head[ArrayDeclareShape[$fnM, "two"]]},
    {List, ArrayDeclareShape},
    {ArrayDeclareShape::baddims},
    TestID -> "regression-declare-shape-validates-dims"
]

(* The reset entry point clears both tables, so a session that probed or declared
   a shape wrongly is recoverable.  It runs last: it wipes every declaration
   this section made. *)
VerificationTest[
    (
        ArrayDeclareShape[$fnIf, {2}];
        ArrayDeclareShape[All, None];
        {ArrayDeclareShape[$fnIf], ArrayLazyQ[$fnIf], ArrayDeclareShape[$fnM], ArrayLazyQ[$fnM]}
    ),
    {Missing["NotDeclared"], False, Missing["NotDeclared"], True},
    TestID -> "regression-declare-shape-reset-clears-all"
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
