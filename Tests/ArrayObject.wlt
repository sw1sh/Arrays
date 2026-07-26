(* Tests for the Wolfram/Arrays container handle: ArrayObject, ArrayObjectQ,
   their properties, the transparent introspection UpValues, and the summary
   box (which must render every tier without materializing anything).
   Run via Tests/RunTests.wls or TestReport. *)

Needs["Wolfram`Arrays`"]

(* === fixtures === *)

$sparse = SparseArray[{{0, 1}, {2, 0}}]
$packed = Developer`ToPackedArray[N[{{1, 2}, {3, 4}}]]
$plain = {{a1, a2}, {a3, a4}}
$numeric = NumericArray[{1., 2.}]
$symmetrized = SymmetrizedArray[{{1, 2} -> 3.}, {2, 2}, Antisymmetric[{1, 2}]]

$quantity = QuantityArray[{1., 2., 3.}, "Meters"]
$column = TabularColumn[{1., 2., 3.}]
$tabular = Tabular[{{1., 2.}, {3., 4.}}]
$dataset = Dataset[{{1., 2.}, {3., 4.}}]
$bytes = ByteArray[{1, 2, 3}]
$events = EventSeries[{{1., 2.}, {3., 4.}}, {{0, 1}}]
$store = CreateDataStructure["DynamicArray", {1., 2., 3.}]

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
$Assumptions = {Element[symA, Matrices[{2, 2}]]}


BeginTestSection["arrayobject - construction"]

VerificationTest[
    ArrayObjectQ /@ ArrayObject /@ {$sparse, $packed, $plain, $numeric, $symmetrized},
    {True, True, True, True, True},
    TestID -> "arrayobject-construction-explicit"
]

VerificationTest[
    ArrayObjectQ /@ ArrayObject /@ {$quantity, $column, $tabular, $dataset, $bytes, $events, $store},
    {True, True, True, True, True, True, True},
    TestID -> "arrayobject-construction-wrappers"
]

VerificationTest[
    ArrayObjectQ[ArrayObject[$lazy]],
    True,
    TestID -> "arrayobject-construction-lazy"
]

VerificationTest[
    ArrayObjectQ /@ ArrayObject /@ {$vec, $mat, $arr, symA, $tensorProduct},
    {True, True, True, True, True},
    TestID -> "arrayobject-construction-symbolic"
]

(* The wrapped container comes back unchanged, including reference-semantics
   handles: the object holds the container, it does not copy or convert it. *)
VerificationTest[
    {ArrayObject[$sparse]["Data"] === $sparse, ArrayObject[$store]["Data"] === $store},
    {True, True},
    TestID -> "arrayobject-data-is-the-raw-container"
]

(* ArrayContainerQ is True on an ArrayObject, which would otherwise make a
   doubly wrapped object legal; wrapping is idempotent instead. *)
VerificationTest[
    ArrayObject[ArrayObject[$sparse]] === ArrayObject[$sparse],
    True,
    TestID -> "arrayobject-construction-idempotent"
]

VerificationTest[
    MatchQ[ArrayObject["junk"], _ArrayObject],
    True,
    {ArrayObject::nocontainer},
    TestID -> "arrayobject-construction-nocontainer-message"
]

(* An Association is rejected by the classification tier, so it is rejected
   here too: the handle admits exactly what ArrayContainerQ admits. *)
VerificationTest[
    MatchQ[ArrayObject[<|1 -> 1.5, 2 -> 2.5|>], _ArrayObject],
    True,
    {ArrayObject::nocontainer},
    TestID -> "arrayobject-construction-rejects-association"
]

VerificationTest[
    {ArrayObjectQ[$sparse], ArrayObjectQ["junk"], ArrayObjectQ[ArrayObject], ArrayObjectQ[]},
    {False, False, False, False},
    TestID -> "arrayobject-objectq-rejects-non-objects"
]

(* Wrong arity is diagnosed, not accepted in silence: a two-argument
   ArrayObject reads as a handle at a glance while failing ArrayObjectQ. *)
VerificationTest[
    MatchQ[ArrayObject[$sparse, $sparse], _ArrayObject],
    True,
    {ArrayObject::argx},
    TestID -> "arrayobject-construction-wrong-arity-message"
]

VerificationTest[
    MatchQ[ArrayObject[], _ArrayObject],
    True,
    {ArrayObject::argx},
    TestID -> "arrayobject-construction-no-arguments-message"
]

EndTestSection[]


BeginTestSection["arrayobject - properties"]

VerificationTest[
    ArrayObject[$sparse]["Properties"],
    {"ComputeNativeQ", "Data", "Dimensions", "Domain", "ElementType", "Kind",
        "Normal", "NumberQ", "NumericQ", "Properties", "Rank", "Tier"},
    TestID -> "arrayobject-properties-list"
]

(* Kind is derived from the head, so it is precise at head level: a packed
   List is distinguished from a plain one, and an assumption-registered symbol
   reports "Symbol". *)
VerificationTest[
    Map[
        ArrayObject[#]["Kind"] &,
        {$sparse, $packed, $plain, $numeric, $symmetrized, $quantity, $column,
            $tabular, $dataset, $bytes, $events, $store, $lazy, $vec, $mat, $arr,
            symA, $tensorProduct}
    ],
    {"SparseArray", "PackedArray", "List", "NumericArray", "SymmetrizedArray",
        "QuantityArray", "TabularColumn", "Tabular", "Dataset", "ByteArray",
        "EventSeries", "DataStructure", "InterpolatingFunction", "VectorSymbol",
        "MatrixSymbol", "ArraySymbol", "Symbol", "TensorProduct"},
    TestID -> "arrayobject-property-kind"
]

VerificationTest[
    Map[ArrayObject[#]["Tier"] &, {$sparse, $quantity, $lazy, $mat, symA, $tensorProduct}],
    {"Explicit", "Explicit", "Lazy", "Symbolic", "Symbolic", "Symbolic"},
    TestID -> "arrayobject-property-tier"
]

VerificationTest[
    Map[{#["Dimensions"], #["Rank"]} &, ArrayObject /@ {$sparse, $numeric, $lazy, $arr, symA}],
    {{{2, 2}, 2}, {{2}, 1}, {{2}, 1}, {{2, 3, 4}, 3}, {{2, 2}, 2}},
    TestID -> "arrayobject-property-dimensions-rank"
]

VerificationTest[
    Map[ArrayObject[#]["ComputeNativeQ"] &, {$sparse, $packed, $quantity, $column, $numeric, $tabular, $lazy, $mat}],
    {True, True, True, True, False, False, False, False},
    TestID -> "arrayobject-property-computenativeq"
]

VerificationTest[
    Map[{#["NumericQ"], #["NumberQ"]} &, ArrayObject /@ {$sparse, $packed, $plain, $bytes, $lazy, $mat}],
    {{True, False}, {True, True}, {False, False}, {True, False}, {False, False}, {False, False}},
    TestID -> "arrayobject-property-numericity"
]

(* Element type is reported only where the container carries one; every other
   head, QuantityArray included (it carries a unit, not an element type), gives
   Missing["NotApplicable"]. *)
VerificationTest[
    Map[ArrayObject[#]["ElementType"] &, {$numeric, $column, $quantity, $sparse, $mat}],
    {"Real64", "Real64", Missing["NotApplicable"], Missing["NotApplicable"], Missing["NotApplicable"]},
    TestID -> "arrayobject-property-elementtype"
]

VerificationTest[
    Map[ArrayObject[#]["Normal"] &, {$sparse, $numeric, $bytes, $mat}],
    {{{0, 1}, {2, 0}}, {1., 2.}, {1, 2, 3}, $mat},
    TestID -> "arrayobject-property-normal"
]

(* "Normal" routes through ArrayMaterialize, so a wrapper takes its dedicated
   materialization path (magnitudes for a QuantityArray) rather than Normal. *)
VerificationTest[
    {ArrayObject[$quantity]["Normal"], Developer`PackedArrayQ[ArrayObject[$column]["Normal"]]},
    {{1., 2., 3.}, True},
    TestID -> "arrayobject-property-normal-wrapper-routes"
]

VerificationTest[
    ArrayObject[$sparse]["Data"] === $sparse && ArrayObject[symA]["Data"] === symA,
    True,
    TestID -> "arrayobject-property-data"
]

VerificationTest[
    Head[ArrayObject[$sparse]["Bogus"]],
    ArrayObject[$sparse],
    {ArrayObject::noprop},
    TestID -> "arrayobject-property-unknown-message"
]

(* A bad property ARITY is diagnosed too, not only a bad property name. *)
VerificationTest[
    Head[ArrayObject[$sparse]["Kind", "Tier"]],
    ArrayObject[$sparse],
    {ArrayObject::propx},
    TestID -> "arrayobject-property-wrong-arity-message"
]

VerificationTest[
    Head[ArrayObject[$sparse][]],
    ArrayObject[$sparse],
    {ArrayObject::propx},
    TestID -> "arrayobject-property-no-arguments-message"
]

EndTestSection[]


BeginTestSection["arrayobject - transparent operations"]

(* Every exported function takes a handle and gives the RAW-container answer.
   The tier UpValues make a handle satisfy ArrayContainerQ and ArrayExplicitQ,
   which are the guards nearly every definition in the paclet is written
   against, so an operation that did not unwrap would hand the wrapper straight
   to a System function: ArrayVector[obj] gave back the handle, ArrayPart
   indexed the handle expression, ArrayContract went inert and
   ArrayExplicitValues emitted SparseArray::list.  A failure here reports the
   operations that stopped agreeing with the raw container. *)
VerificationTest[
    With[{obj = ArrayObject[$sparse]},
        Select[
            {
                ArrayVector, ArrayPack, ArrayName, SimplifyArray, ArrayConjugate,
                ArrayMaterialize, Normal, ArrayDimensions, ArrayRank, ZeroArrayQ, ArrayAllZeroQ,
                ArrayExplicitValues, ArrayExplicitPositions, ArrayExplicitLength,
                ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ,
                ArrayComputeNativeQ, ArrayNumericQ, ArrayNumberQ,
                ArrayTranspose[#, {2, 1}] &,
                ArrayContract[#, {{1, 2}}] &,
                ArrayPart[#, {1}] &,
                ArrayReplaceAll[#, {2 -> 9}] &,
                ArrayMap[fmap, #] &,
                ArrayMap[fmap, #, {1}] &,
                ReshapeArray[#, {4}] &,
                ReshapeArray[#, {6}, 7] &,
                PadArray[#, 1] &,
                PadArray[#, 1, 5] &
            },
            #[obj] =!= #[$sparse] &
        ]
    ],
    {},
    TestID -> "arrayobject-unwraps-every-operation"
]

(* The same across every tier, for the operations that are defined on all of
   them.  Normal is excluded here: on a handle it is ArrayMaterialize by design,
   which deliberately differs from Normal on a QuantityArray or an EventSeries. *)
VerificationTest[
    Select[
        Tuples[{
            {$sparse, $numeric, $quantity, $column, $bytes, $events, $store, $lazy, $vec, $mat, symA, $tensorProduct},
            {
                ArrayDimensions, ArrayRank, ArrayName, ArrayMaterialize, ArrayPack, ArrayVector,
                ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ,
                ArrayComputeNativeQ, ArrayNumericQ, ArrayNumberQ, ZeroArrayQ
            }
        }],
        Last[#][ArrayObject[First[#]]] =!= Last[#][First[#]] &
    ],
    {},
    TestID -> "arrayobject-unwraps-every-tier"
]

(* An UpValue exists for exactly the functions that back a property, plus
   Normal. *)
VerificationTest[
    With[{obj = ArrayObject[$sparse]},
        {
            ArrayContainerQ[obj], ArrayExplicitQ[obj], ArrayLazyQ[obj], ArraySymbolicQ[obj],
            ArrayDimensions[obj], ArrayRank[obj], ArrayComputeNativeQ[obj],
            ArrayNumericQ[obj], ArrayNumberQ[obj]
        }
    ],
    {True, True, False, False, {2, 2}, 2, True, True, False},
    TestID -> "arrayobject-upvalues-introspection"
]

VerificationTest[
    {Normal[ArrayObject[$sparse]], ArrayMaterialize[ArrayObject[$numeric]]},
    {{{0, 1}, {2, 0}}, {1., 2.}},
    TestID -> "arrayobject-upvalues-normal-roundtrip"
]

VerificationTest[
    With[{obj = ArrayObject[$lazy]},
        {ArrayLazyQ[obj], ArrayExplicitQ[obj], ArraySymbolicQ[obj], ArrayDimensions[obj]}
    ],
    {True, False, False, {2}},
    TestID -> "arrayobject-upvalues-lazy-tier"
]

(* A structural result is never re-wrapped: the handle goes in, a raw container
   comes out, which is the whole reason no operation has to decide whether to
   rebuild one. *)
VerificationTest[
    With[{obj = ArrayObject[$sparse]},
        {Head[ArrayVector[obj]], Normal[ArrayTranspose[obj, {2, 1}]], ArrayObjectQ[ArrayVector[obj]]}
    ],
    {SparseArray, {{0, 2}, {1, 0}}, False},
    TestID -> "arrayobject-structural-operations-give-raw-containers"
]

EndTestSection[]


BeginTestSection["arrayobject - stale handles"]

(* A handle carries the evaluated flag from the moment it was built, so the
   rejection guard on the head never fires a second time; admission can lapse
   all the same, and the handle must then say so instead of falling through to
   the generic clauses, which would report dimensions {} and rank 0. *)

$staleObject = Block[{$Assumptions = {Element[symStale, Matrices[{2, 2}]]}}, ArrayObject[symStale]]

VerificationTest[
    {ArrayObjectQ[$staleObject], Quiet[ArrayDimensions[$staleObject]], Quiet[ArrayRank[$staleObject]], Quiet[Normal[$staleObject]]},
    {False, Missing["NotAContainer"], Missing["NotAContainer"], Missing["NotAContainer"]},
    TestID -> "arrayobject-stale-handle-is-not-a-container"
]

VerificationTest[
    ArrayDimensions[$staleObject],
    Missing["NotAContainer"],
    {ArrayObject::nocontainer},
    TestID -> "arrayobject-stale-handle-messages"
]

VerificationTest[
    Head[$staleObject["Kind"]],
    $staleObject,
    {ArrayObject::nocontainer},
    TestID -> "arrayobject-stale-property-messages"
]

(* Predicates answer False rather than messaging: a predicate is asked whether
   something is a container, so saying no IS the answer. *)
VerificationTest[
    Quiet @ Through[
        {ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ, ArrayComputeNativeQ,
            ArrayNumericQ, ArrayNumberQ, ArrayAllZeroQ}[$staleObject]
    ],
    {False, False, False, False, False, False, False, False},
    TestID -> "arrayobject-stale-handle-predicates-are-false"
]

(* An invalid handle built from unsupported input behaves the same way. *)
VerificationTest[
    Quiet[{ArrayDimensions[ArrayObject["junk"]], ArrayRank[ArrayObject["junk"]]}],
    {Missing["NotAContainer"], Missing["NotAContainer"]},
    TestID -> "arrayobject-invalid-handle-never-claims-rank-zero"
]

EndTestSection[]


BeginTestSection["arrayobject - summary box"]

VerificationTest[
    Map[Head[ToBoxes[ArrayObject[#], StandardForm]] &, {$sparse, $numeric, $quantity, $tabular, $store, $lazy, $mat, symA}],
    ConstantArray[InterpretationBox, 8],
    TestID -> "arrayobject-box-renders-every-tier"
]

(* The box must draw any container without evaluating it.  Blocking
   ArrayMaterialize away turns any materialization attempt into a Throw, so the
   test fails loudly instead of silently getting slower.  EVERY admitted head is
   covered, not just the lazy and symbolic tiers: the box's numeric and inexact
   rows call element predicates, and an EventSeries used to answer both of them
   by copying the whole series. *)
VerificationTest[
    Block[{ArrayMaterialize},
        ArrayMaterialize[___] := Throw["materialized", "arrayobject-box"];
        Map[
            Catch[ToBoxes[ArrayObject[#], StandardForm]; "no-materialize", "arrayobject-box"] &,
            {$sparse, $packed, $plain, $numeric, $symmetrized, $quantity, $column,
                $tabular, $dataset, $bytes, $events, $store, $lazy, $vec, $mat, $arr,
                symA, $tensorProduct}
        ]
    ],
    ConstantArray["no-materialize", 18],
    TestID -> "arrayobject-box-does-not-materialize"
]

VerificationTest[
    With[{obj = ArrayObject[$lazy]},
        ToBoxes[obj, StandardForm];
        {ArrayLazyQ[obj["Data"]], MatchQ[obj["Data"], $if[_]]}
    ],
    {True, True},
    TestID -> "arrayobject-box-leaves-lazy-container-lazy"
]

(* The collapsed row carries the kind and the dimensions. *)
VerificationTest[
    With[{boxes = ToString[ToBoxes[ArrayObject[$sparse], StandardForm], InputForm]},
        {StringContainsQ[boxes, "kind: "], StringContainsQ[boxes, "SparseArray"], StringContainsQ[boxes, "dimensions: "]}
    ],
    {True, True, True},
    TestID -> "arrayobject-box-collapsed-row"
]

(* Element-type and unit rows appear only where the container exposes one. *)
VerificationTest[
    Map[
        StringContainsQ[ToString[ToBoxes[ArrayObject[#], StandardForm], InputForm], "element type: "] &,
        {$numeric, $column, $sparse}
    ],
    {True, True, False},
    TestID -> "arrayobject-box-element-type-row"
]

VerificationTest[
    With[{boxes = ToString[ToBoxes[ArrayObject[$quantity], StandardForm], InputForm]},
        {StringContainsQ[boxes, "unit: "], StringContainsQ[boxes, "Meters"]}
    ],
    {True, True},
    TestID -> "arrayobject-box-quantityarray-unit-row"
]

EndTestSection[]


BeginTestSection["arrayobject - admitted lazy heads"]

VerificationTest[
    ArrayObjectQ /@ ArrayObject /@ {$pfLazy, $fn, $pw},
    {True, True, True},
    TestID -> "Lazy-arrayobject-construction"
]

(* Kind is derived from the head chain, so a newly admitted head reports its own
   name with no lookup table to update: the chain of a fully applied
   ParametricFunction takes one step more than an InterpolatingFunction and
   still lands on the constructor symbol. *)
VerificationTest[
    Map[ArrayObject[#]["Kind"] &, {$lazy, $pfLazy, $fn, $pw}],
    {"InterpolatingFunction", "ParametricFunction", "Function", "Piecewise"},
    TestID -> "Lazy-arrayobject-property-kind"
]

VerificationTest[
    Map[
        {#["Tier"], #["Dimensions"], #["Rank"], #["ComputeNativeQ"], #["NumericQ"], #["NumberQ"], #["ElementType"]} &,
        ArrayObject /@ {$pfLazy, $fn, $pw}
    ],
    {
        {"Lazy", {2}, 1, False, False, False, Missing["NotApplicable"]},
        {"Lazy", {2, 2}, 2, False, False, False, Missing["NotApplicable"]},
        {"Lazy", {2, 2}, 2, False, False, False, Missing["NotApplicable"]}
    },
    TestID -> "Lazy-arrayobject-properties"
]

(* The bare and partially applied ParametricFunction are not containers, so the
   handle declines them the same way it declines any other unsupported input. *)
VerificationTest[
    Quiet[{Head[ArrayObject[$pf]], Head[ArrayObject[$pf[aa]]]}],
    {ArrayObject, ArrayObject},
    TestID -> "Lazy-arrayobject-declines-non-container-parametric-arities"
]

VerificationTest[
    Map[
        With[{obj = ArrayObject[#]}, {ArrayContainerQ[obj], ArrayLazyQ[obj], ArrayExplicitQ[obj], ArraySymbolicQ[obj], ArrayDimensions[obj], ArrayRank[obj]}] &,
        {$pfLazy, $fn, $pw}
    ],
    {
        {True, True, False, False, {2}, 1},
        {True, True, False, False, {2, 2}, 2},
        {True, True, False, False, {2, 2}, 2}
    },
    TestID -> "Lazy-arrayobject-upvalues"
]

(* Every new head draws a full box from shape-only probes.  A ParametricFunction
   is the sharp case: its shape comes from a probe solve, which is not a
   materialization of the container, and the cached shape means the box does not
   even enter the solver on a redraw. *)
VerificationTest[
    Block[{ArrayMaterialize},
        ArrayMaterialize[___] := Throw["materialized", "arrayobject-box-lazy"];
        Map[
            Catch[ToBoxes[ArrayObject[#], StandardForm]; "no-materialize", "arrayobject-box-lazy"] &,
            {$pfLazy, $fn, $pw}
        ]
    ],
    {"no-materialize", "no-materialize", "no-materialize"},
    TestID -> "Lazy-arrayobject-box-does-not-materialize"
]

VerificationTest[
    Map[Head[ToBoxes[ArrayObject[#], StandardForm]] &, {$pfLazy, $fn, $pw}],
    ConstantArray[InterpretationBox, 3],
    TestID -> "Lazy-arrayobject-box-renders"
]

VerificationTest[
    Map[
        With[{obj = ArrayObject[#]},
            ToBoxes[obj, StandardForm];
            ArrayLazyQ[obj["Data"]]
        ] &,
        {$pfLazy, $fn, $pw}
    ],
    {True, True, True},
    TestID -> "Lazy-arrayobject-box-leaves-container-lazy"
]

EndTestSection[]
