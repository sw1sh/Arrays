(* Tests for Wolfram/Arrays explicit-storage accessors and conversions:
   ArrayExplicitValues, ArrayExplicitPositions, ArrayExplicitLength,
   ArrayMaterialize, ArrayPack.
   Run via Tests/RunTests.wls or TestReport. *)

Needs["Wolfram`Arrays`"]

(* === fixtures === *)

$sparse = SparseArray[{{0, 1}, {2, 0}}]
$dense = Normal[$sparse]
$numeric = NumericArray[{{1., 0.}, {0., 2.}}]
$symmetrized = SymmetrizedArray[{{1, 2} -> 3.}, {2, 2}, Antisymmetric[{1, 2}]]
$plain = {{a1, a2}, {a3, a4}}

$if = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}]
$lazy = $if[tau]

$pf = ParametricNDSolveValue[{v'[t] == {{0, pa}, {-pa, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}, {pa}]
$pfLazy = $pf[aa][tt]
$fn = Function[fnT, {{Cos[fnT], -Sin[fnT]}, {Sin[fnT], Cos[fnT]}}]
$pw = Piecewise[{{{{1., 2.}, {3., 4.}}, zz < 0}}, {{5., 6.}, {7., 8.}}]

$mat = MatrixSymbol["M", {2, 3}]
$tensorProduct = Inactive[TensorProduct][VectorSymbol["u", 2], MatrixSymbol["N", {3, 4}]]

(* Set fresh so this file does not depend on assumption state from any other
   .wlt: the runner loads every file into one kernel session and ArrayPart
   rewrites the global $Assumptions in place. *)
$Assumptions = {Element[symA, Matrices[{2, 2}]], Element[symB, Matrices[{2, 2}]]}


BeginTestSection["accessors"]

VerificationTest[
    {ArrayExplicitValues[$dense], ArrayExplicitPositions[$dense], ArrayExplicitLength[$dense]},
    {ArrayExplicitValues[$sparse], Normal[ArrayExplicitPositions[$sparse]], ArrayExplicitLength[$sparse]},
    TestID -> "accessors-dense-sparse-parity"
]

VerificationTest[
    {ArrayExplicitValues[$sparse], ArrayExplicitLength[$sparse]},
    {{1, 2}, 2},
    TestID -> "accessors-sparse-native"
]

VerificationTest[
    ArrayExplicitValues[$numeric],
    {1., 2.},
    TestID -> "accessors-numericarray-values"
]

VerificationTest[
    ArrayExplicitValues[$symmetrized],
    {3., -3.},
    TestID -> "accessors-symmetrizedarray-values"
]

VerificationTest[
    {ArrayExplicitValues[$lazy], ArrayExplicitPositions[$lazy], ArrayExplicitLength[$lazy]},
    {Missing["NotExplicit"], Missing["NotExplicit"], Missing["NotExplicit"]},
    TestID -> "accessors-lazy-missing"
]

VerificationTest[
    {ArrayExplicitValues[$mat], ArrayExplicitPositions[symA], ArrayExplicitLength[$tensorProduct]},
    {Missing["NotExplicit"], Missing["NotExplicit"], Missing["NotExplicit"]},
    TestID -> "accessors-symbolic-missing"
]

VerificationTest[
    ArrayMaterialize /@ {$sparse, $numeric, $symmetrized},
    {{{0, 1}, {2, 0}}, {{1., 0.}, {0., 2.}}, {{0, 3.}, {-3., 0}}},
    TestID -> "accessors-materialize-explicit"
]

VerificationTest[
    With[{expansion = ArrayMaterialize[$lazy]},
        {
            Dimensions[expansion] === {2},
            TrueQ[Max[Abs[(expansion /. tau -> 0.5) - $if[0.5]]] < 1*^-4]
        }
    ],
    {True, True},
    TestID -> "accessors-materialize-lazy-matches-per-scalar-expansion"
]

VerificationTest[
    ArrayMaterialize[$mat],
    $mat,
    TestID -> "accessors-materialize-symbolic-identity"
]

VerificationTest[
    With[{x = SparseArray[{1 -> 1, 2 -> I}, 3]},
        {Developer`PackedArrayQ[ArrayPack[x]], ArrayMaterialize[ArrayPack[x]] == Normal[x]}
    ],
    {True, True},
    TestID -> "accessors-pack-materialize-normal-roundtrip"
]

VerificationTest[
    Developer`PackedArrayQ[ArrayPack[Normal[SparseArray[{1 -> 1, 2 -> I}, 3]]]],
    True,
    TestID -> "accessors-pack-mixed-integer-complex"
]

VerificationTest[
    Developer`PackedArrayQ[ArrayPack[{1, 2.5}]],
    True,
    TestID -> "accessors-pack-mixed-integer-real"
]

VerificationTest[
    {ArrayPack[$plain], ArrayPack[$mat], ArrayPack[$lazy]},
    {$plain, $mat, $lazy},
    TestID -> "accessors-pack-unpackable-unchanged"
]

EndTestSection[]


BeginTestSection["accessors - admitted wrapper containers"]

(* QuantityArray materializes via QuantityMagnitude (Normal is the slow unpacked
   trap) and rebuilds from the "UnitBlock" metadata. *)
VerificationTest[
    With[{qa = QuantityArray[{1., 2., 3.}, "Meters"]},
        {ArrayMaterialize[qa] === QuantityMagnitude[qa], Developer`PackedArrayQ[ArrayMaterialize[qa]]}
    ],
    {True, True},
    TestID -> "Wrapper-QuantityArray-materialize-magnitudes-packed"
]

VerificationTest[
    With[{qa = QuantityArray[{{1., 2.}, {3., 4.}}, "Seconds"]},
        With[{rebuilt = QuantityArray[2 ArrayMaterialize[qa], qa["UnitBlock"]]},
            {MatchQ[rebuilt, _QuantityArray], QuantityMagnitude[rebuilt]}
        ]
    ],
    {True, {{2., 4.}, {6., 8.}}},
    TestID -> "Wrapper-QuantityArray-rebuild-roundtrip"
]

VerificationTest[
    With[{tc = TabularColumn[{1., 2., 3.}]},
        Normal[TabularColumn[2 ArrayMaterialize[tc], tc["ElementType"]]]
    ],
    {2., 4., 6.},
    TestID -> "Wrapper-TabularColumn-rebuild-roundtrip"
]

(* A named Tabular has no anonymous matrix to hand back, so materialization goes
   per column. *)
VerificationTest[
    With[{m = {{1., 2.}, {3., 4.}, {5., 6.}}},
        ArrayMaterialize[Tabular[m, {"a", "b"}]] == m
    ],
    True,
    TestID -> "Wrapper-Tabular-named-percolumn-route"
]

VerificationTest[
    With[{m = {{1., 2.}, {3., 4.}}},
        ArrayMaterialize[Tabular[ArrayMaterialize[Tabular[m]]]] == m
    ],
    True,
    TestID -> "Wrapper-Tabular-rebuild-roundtrip"
]

VerificationTest[
    With[{ev = EventSeries[{{1., 2.}, {3., 4.}}, {{0, 1}}]},
        With[{rebuilt = EventSeries[ArrayMaterialize[ev], {Normal[ev["Times"]]}]},
            ArrayMaterialize[rebuilt] == ArrayMaterialize[ev]
        ]
    ],
    True,
    TestID -> "Wrapper-EventSeries-rebuild-roundtrip"
]

(* DataStructure stores have reference semantics, defeated by snapshot-on-ingest:
   the materialized value does not track a later mutation of the store. *)
VerificationTest[
    Module[{ds = CreateDataStructure["DynamicArray", {1., 2., 3.}], snapshot},
        snapshot = ArrayMaterialize[ds];
        ds["Append", 4.];
        {snapshot, ds["Length"]}
    ],
    {{1., 2., 3.}, 4},
    TestID -> "Wrapper-DataStructure-snapshot-defeats-aliasing"
]

EndTestSection[]


BeginTestSection["accessors - materialization invariant"]

(* THE INVARIANT EVERY TIER UPHOLDS: materializing a container gives an EXPLICIT
   container of the same shape.  The one admitted form that has no values to
   compute is a leafless symbolic container, which is why it is listed
   separately below rather than exempted by a special case here. *)

$materializable = {
    SparseArray[{{0, 1}, {2, 0}}],
    NumericArray[{{1., 0.}, {0., 2.}}],
    SymmetrizedArray[{{1, 2} -> 3.}, {2, 2}, Antisymmetric[{1, 2}]],
    QuantityArray[{{1., 2.}, {3., 4.}}, "Meters"],
    ByteArray[{1, 2, 3}],
    $lazy,
    $pfLazy,
    $fn,
    $pw,
    NetGraph[{NetArrayLayer["Array" -> {{1., 2., 3.}, {4., 5., 6.}}]}, {1 -> NetPort["Output"]}],
    Inactive[TensorProduct][ArrayReshape[Range[6], {2, 3}], ArrayReshape[Range[12], {3, 4}]],
    Inactive[TensorContract][
        Inactive[TensorProduct][ArrayReshape[Range[6], {2, 3}], ArrayReshape[Range[12], {3, 4}]],
        {{2, 3}}
    ],
    Inactive[ArrayDot][ArrayReshape[Range[6], {2, 3}], ArrayReshape[Range[12], {3, 4}], {{2, 1}}]
}

VerificationTest[
    Map[
        With[{materialized = ArrayMaterialize[#]},
            {
                ArrayContainerQ[#],
                ArrayExplicitQ[materialized],
                ArrayDimensions[materialized] === ArrayDimensions[#]
            }
        ] &,
        $materializable
    ],
    ConstantArray[{True, True, True}, Length[$materializable]],
    TestID -> "accessors-materialize-gives-explicit-container-of-same-shape"
]

(* A leafless symbolic container has no values, so it stands for itself. *)
VerificationTest[
    Map[ArrayMaterialize[#] === # &, {$mat, $tensorProduct}],
    {True, True},
    TestID -> "accessors-materialize-leafless-symbolic-is-identity"
]

EndTestSection[]


BeginTestSection["accessors - admitted lazy heads"]

VerificationTest[
    Map[{ArrayExplicitValues[#], ArrayExplicitPositions[#], ArrayExplicitLength[#]} &, {$pfLazy, $fn, $pw}],
    ConstantArray[{Missing["NotExplicit"], Missing["NotExplicit"], Missing["NotExplicit"]}, 3],
    TestID -> "Lazy-accessors-not-explicit"
]

(* Per-scalar expansion is head-specific: a Piecewise threads its branch
   structure through every position, so each element is a scalar Piecewise with
   the same conditions. *)
VerificationTest[
    ArrayMaterialize[$pw],
    {
        {Piecewise[{{1., zz < 0}}, 5.], Piecewise[{{2., zz < 0}}, 6.]},
        {Piecewise[{{3., zz < 0}}, 7.], Piecewise[{{4., zz < 0}}, 8.]}
    },
    TestID -> "Lazy-Piecewise-materialize-per-scalar"
]

(* A Function is stored unapplied, so its elements are unapplied too: an array
   of scalar Functions of the same parameter. *)
VerificationTest[
    ArrayMaterialize[$fn],
    {{Function[fnT, Cos[fnT]], Function[fnT, -Sin[fnT]]}, {Function[fnT, Sin[fnT]], Function[fnT, Cos[fnT]]}},
    TestID -> "Lazy-Function-materialize-per-scalar"
]

(* A ParametricFunction has no per-scalar form - there is no way to bind one
   element of a solve - so it falls back to the registry's Indexed expansion,
   which is still an explicit array of scalar expressions that substitutes to
   the right values. *)
VerificationTest[
    With[{expansion = ArrayMaterialize[$pfLazy]},
        {
            Dimensions[expansion],
            MatchQ[expansion, {_Indexed, _Indexed}],
            (expansion /. {aa -> 1., tt -> 0.5}) == ArrayReplaceAll[$pfLazy, {aa -> 1., tt -> 0.5}]
        }
    ],
    {{2}, True, True},
    TestID -> "Lazy-ParametricFunction-materialize-indexed"
]

VerificationTest[
    Map[ArrayPack[#] === # &, {$pfLazy, $fn, $pw}],
    {True, True, True},
    TestID -> "Lazy-accessors-pack-unchanged"
]

EndTestSection[]
