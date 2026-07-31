(* Tests for the Wolfram/Arrays type algebra: the tier lattice (ArrayTier), the
   element lattice (ArrayElementDomain, ArrayElementType), their joins
   (ArrayUnify), coercion along both lattices (ArrayCoerce), and the mixing
   point that applies them, ArrayContract on a list of containers.
   Run via Tests/RunTests.wls or TestReport. *)

Needs["Wolfram`Arrays`"]

(* === fixtures === *)

$sparse = SparseArray[{{1, 2}, {3, 4}}]
$plainMatrix = {{1, 2}, {3, 4}}
$packedReal = Developer`ToPackedArray[{{1., 2.}, {3., 4.}}]
$symbolicEntries = {{t1, t2}, {t3, t4}}

$int8 = NumericArray[{1, 2}, "Integer8"]
$int64 = NumericArray[{1, 2}, "Integer64"]
$uint8 = NumericArray[{1, 2}, "UnsignedInteger8"]
$real32 = NumericArray[{1., 2.}, "Real32"]
$real64 = NumericArray[{1., 2.}, "Real64"]
$complex32 = NumericArray[{1. + 2. I, 3.}, "ComplexReal32"]
$complex64 = NumericArray[{1. + 2. I, 3.}, "ComplexReal64"]

$overIntegers = VectorSymbol["zi", 2, Integers]
$overRationals = VectorSymbol["zq", 2, Rationals]
$overAlgebraics = VectorSymbol["za", 2, Algebraics]
$overReals = VectorSymbol["zr", 2, Reals]
$overComplexes = VectorSymbol["zc", 2, Complexes]

$matrixOverReals = MatrixSymbol["Mr", {2, 2}, Reals]
$undeclared = MatrixSymbol["Mu", {2, 2}]

$lazyFunction = Function[lzT, {{Cos[lzT], -Sin[lzT]}, {Sin[lzT], Cos[lzT]}}]
$lazyPiecewise = Piecewise[{{{{1., 2.}, {3., 4.}}, lzZ < 0}}, {{5., 6.}, {7., 8.}}]

(* A head with NO lazy-preserving rebuild, which is the other half of the mixing
   point: a real ParametricNDSolveValue rather than a stand-in, since the whole
   point is the head's own behaviour. *)
$lazyParametricOf = ParametricNDSolveValue[
    {lzM'[lzS] == {{0, lzA}, {-lzA, 0}} . lzM[lzS], lzM[0] == {{1., 0.}, {0., 1.}}},
    lzM, {lzS, 0, 1}, {lzA}
]
$lazyParametric = $lazyParametricOf[lzPa][lzPt]

(* The bind-then-contract truth an operand set must agree with: bind every
   parameter FIRST, then contract the explicit arrays.  The operands are wrapped
   in SparseArray so that the list is a list of arrays rather than one array of
   higher rank, which is what a list of plain Lists means to ArrayContract. *)
boundContraction[arrays_, rules_, c_] :=
    Normal[ArrayContract[Map[SparseArray[ArrayReplaceAll[#, rules]] &, arrays], c]]

agreesQ[got_, truth_] := ArrayQ[got, _, NumericQ] && Dimensions[got] === Dimensions[truth] &&
    Max[Abs[got - truth]] < 10.^-12

(* Set fresh so this file does not depend on assumption state from any other
   .wlt: the runner loads every file into one kernel session. *)
$Assumptions = {Element[symT, Matrices[{2, 2}]], Element[symTr, Matrices[{2, 2}, Reals]]}


BeginTestSection["types - tier lattice"]

VerificationTest[
    Map[ArrayTier, {$sparse, $packedReal, $real64, $lazyFunction, $lazyPiecewise, $overReals, symT}],
    {"Explicit", "Explicit", "Explicit", "Lazy", "Lazy", "Symbolic", "Symbolic"},
    TestID -> "types-tier-of-each-tier"
]

(* A tier is a property of a container, so anything else is told so rather than
   being given the most general tier by default. *)
VerificationTest[
    Map[ArrayTier, {"junk", 7, <|1 -> 1.5|>}],
    ConstantArray[Missing["NotAContainer"], 3],
    TestID -> "types-tier-of-non-container"
]

(* The full join table, reflexive cases included: the join is the MAXIMUM in
   Explicit < Lazy < Symbolic, so it is symmetric and idempotent. *)
VerificationTest[
    Outer[
        ArrayUnify[{#1, #2}]["Tier"] &,
        {$sparse, $lazyFunction, $overReals},
        {$sparse, $lazyFunction, $overReals},
        1
    ],
    {
        {"Explicit", "Lazy", "Symbolic"},
        {"Lazy", "Lazy", "Symbolic"},
        {"Symbolic", "Symbolic", "Symbolic"}
    },
    TestID -> "types-tier-join-table"
]

VerificationTest[
    ArrayUnify[{$sparse, $lazyPiecewise, $overComplexes, $real64}]["Tier"],
    "Symbolic",
    TestID -> "types-tier-join-n-ary"
]

EndTestSection[]


BeginTestSection["types - element domain"]

(* The five domains are read off type metadata where a container carries it and
   inferred from values where it does not. *)
VerificationTest[
    Map[ArrayElementDomain, {$int64, $uint8, $real32, $complex64, ByteArray[{1, 2, 3}]}],
    {Integers, Integers, Reals, Complexes, Integers},
    TestID -> "types-domain-of-numeric-types"
]

VerificationTest[
    Map[
        ArrayElementDomain,
        {$sparse, $plainMatrix, $packedReal, {1/2, 1/3}, {1. + 2. I, 3.}, SparseArray[{1 -> 1}, {3}, 0.]}
    ],
    {Integers, Integers, Reals, Rationals, Complexes, Reals},
    TestID -> "types-domain-inferred-from-values"
]

(* A wrapper container answers from the same metadata its numericity probes
   read, and a QuantityArray from its magnitudes: the unit is separate. *)
VerificationTest[
    Map[
        ArrayElementDomain,
        {QuantityArray[{1., 2.}, "Meters"], TabularColumn[{1., 2.}], TabularColumn[{1, 2}],
            EventSeries[{{1., 2.}, {3., 4.}}, {{0, 1}}]}
    ],
    {Reals, Reals, Integers, Reals},
    TestID -> "types-domain-of-wrappers"
]

(* A symbolic container gives its DECLARED domain, and defaults to Complexes as
   Vectors, Matrices and Arrays themselves do. *)
VerificationTest[
    Map[
        ArrayElementDomain,
        {$overIntegers, $overRationals, $overAlgebraics, $overReals, $overComplexes, $undeclared, symT, symTr}
    ],
    {Integers, Rationals, Algebraics, Reals, Complexes, Complexes, Complexes, Reals},
    TestID -> "types-domain-of-symbolic-containers"
]

(* A structural tree has the domain of its operands joined, which is what lets a
   contraction of a mixed operand set report one. *)
VerificationTest[
    ArrayElementDomain[Inactive[TensorProduct][$sparse, $overReals]],
    Reals,
    TestID -> "types-domain-of-structural-tree"
]

(* An array of symbolic entries and every lazy container carry no domain this
   tier can read without evaluating them. *)
VerificationTest[
    Map[ArrayElementDomain, {$symbolicEntries, $lazyFunction, $lazyPiecewise}],
    ConstantArray[Missing["NotApplicable"], 3],
    TestID -> "types-domain-unknown"
]

(* ArrayElementType stays the CONCRETE container type: a QuantityArray of reals
   has domain Reals but no element type, which is exactly the gap the domain
   fills. *)
VerificationTest[
    Map[ArrayElementType, {$real64, TabularColumn[{1., 2.}], QuantityArray[{1., 2.}, "Meters"], $sparse, $overReals}],
    {"Real64", "Real64", Missing["NotApplicable"], Missing["NotApplicable"], Missing["NotApplicable"]},
    TestID -> "types-element-type-is-the-container-type"
]

EndTestSection[]


BeginTestSection["types - element joins"]

(* Every adjacent pair of the chain Integers < Rationals < Algebraics < Reals <
   Complexes, joined as symbolic containers so that only the domains differ. *)
VerificationTest[
    Map[
        ArrayUnify[#]["Domain"] &,
        {
            {$overIntegers, $overRationals},
            {$overRationals, $overAlgebraics},
            {$overAlgebraics, $overReals},
            {$overReals, $overComplexes}
        }
    ],
    {Rationals, Algebraics, Reals, Complexes},
    TestID -> "types-domain-join-adjacent-pairs"
]

VerificationTest[
    Map[ArrayUnify[{#, #}]["Domain"] &, {$overIntegers, $overRationals, $overAlgebraics, $overReals, $overComplexes}],
    {Integers, Rationals, Algebraics, Reals, Complexes},
    TestID -> "types-domain-join-is-idempotent"
]

VerificationTest[
    {ArrayUnify[{$overIntegers, $overComplexes}]["Domain"], ArrayUnify[{$overComplexes, $overIntegers}]["Domain"]},
    {Complexes, Complexes},
    TestID -> "types-domain-join-is-symmetric"
]

(* THE PRECISION RULE: widening the domain must not narrow the precision, so
   "Integer64" with "Real32" is "Real64" and not the "Real32" that taking the
   wider operand's type wholesale would give. *)
VerificationTest[
    ArrayUnify[{$int64, $real32}][[{"Tier", "Domain", "ElementType"}]],
    <|"Tier" -> "Explicit", "Domain" -> Reals, "ElementType" -> "Real64"|>,
    TestID -> "types-precision-is-not-narrowed-by-widening"
]

VerificationTest[
    Map[
        ArrayUnify[#]["ElementType"] &,
        {{$real32, $real32}, {$int8, $int64}, {$uint8, $int8}, {$complex32, $real64}, {$int64, $complex32}}
    ],
    {"Real32", "Integer64", "Integer8", "ComplexReal64", "ComplexReal64"},
    TestID -> "types-element-type-join"
]

(* Symbolic absorption: the symbolic side cannot be narrowed to a machine type
   without materializing it, which the tier join forbids, so the join is
   symbolic over the joined domain and has no concrete element type. *)
VerificationTest[
    Map[
        ArrayUnify[{$overReals, #}][[{"Tier", "Domain", "ElementType"}]] &,
        {$int8, $int64, $uint8, $real32, $real64}
    ],
    ConstantArray[<|"Tier" -> "Symbolic", "Domain" -> Reals, "ElementType" -> Missing["NotApplicable"]|>, 5],
    TestID -> "types-symbolic-absorbs-every-explicit-numeric-type"
]

(* The domains still join: absorption is about the PRECISION, so a complex
   explicit operand widens a symbolic real one. *)
VerificationTest[
    ArrayUnify[{$overReals, $complex64}][[{"Tier", "Domain"}]],
    <|"Tier" -> "Symbolic", "Domain" -> Complexes|>,
    TestID -> "types-symbolic-absorption-still-widens-the-domain"
]

(* An unknown domain contributes NOTHING rather than poisoning the join; only a
   join in which every operand is unknown is itself unknown. *)
VerificationTest[
    ArrayUnify[{$symbolicEntries, $real64}][[{"Domain", "ElementType"}]],
    <|"Domain" -> Reals, "ElementType" -> "Real64"|>,
    TestID -> "types-missing-domain-contributes-nothing"
]

VerificationTest[
    ArrayUnify[{$sparse, $lazyFunction}][[{"Tier", "Domain"}]],
    <|"Tier" -> "Lazy", "Domain" -> Integers|>,
    TestID -> "types-missing-domain-of-a-lazy-operand-contributes-nothing"
]

VerificationTest[
    ArrayUnify[{$symbolicEntries, $lazyFunction}][[{"Domain", "ElementType"}]],
    <|"Domain" -> Missing["NotApplicable"], "ElementType" -> Missing["NotApplicable"]|>,
    TestID -> "types-all-unknown-domains-join-to-unknown"
]

(* The operands come back coerced to the joined tier where the lift exists.  The
   lazy operand of a symbolic join is left alone: it is already a legal leaf of
   the tree such a join builds, and materializing it is the downward move the
   tier join forbids. *)
VerificationTest[
    Map[ArrayTier, ArrayUnify[{$sparse, $lazyFunction}]["Arrays"]],
    {"Lazy", "Lazy"},
    TestID -> "types-unify-coerces-operands-to-the-joined-tier"
]

VerificationTest[
    Map[ArrayTier, ArrayUnify[{$sparse, $lazyFunction, $overReals}]["Arrays"]],
    {"Explicit", "Lazy", "Symbolic"},
    TestID -> "types-unify-leaves-an-uncoercible-operand-of-a-symbolic-join"
]

VerificationTest[
    MatchQ[ArrayUnify[{$sparse, "junk"}], _ArrayUnify],
    True,
    {ArrayUnify::nocontainers},
    TestID -> "types-unify-rejects-non-containers"
]

EndTestSection[]


BeginTestSection["types - coercion"]

(* Deferring a container is free; making one symbolic is not possible at all.
   A symbolic container carries a symbol - a shape and a domain and no values -
   and there is nothing to turn known values into unknown ones with, so the
   coercion refuses and leaves the call unevaluated. The lift that used to serve
   this case, Inactive[TensorProduct][a], is a structural tree over an explicit
   leaf: it computes an array on demand, which is the lazy tier. *)
VerificationTest[
    Map[ArrayTier[Quiet[ArrayCoerce[$plainMatrix, #]]] &, {"Explicit", "Lazy"}],
    {"Explicit", "Lazy"},
    TestID -> "types-coerce-explicit-up-to-the-lazy-tier"
]

VerificationTest[
    {
        Head[Quiet[ArrayCoerce[$plainMatrix, "Symbolic"]]],
        Head[Quiet[ArrayCoerce[$lazyFunction, "Symbolic"]]],
        ArrayTier[Quiet[ArrayCoerce[$overReals, "Symbolic"]]]
    },
    {ArrayCoerce, ArrayCoerce, "Symbolic"},
    TestID -> "types-coerce-refuses-to-invent-a-symbolic-container"
]

(* The lift is the constant Function of a formal parameter, so binding that
   parameter to anything at all gives the array back in one whole-array
   evaluation, exactly as for any other Function container. *)
VerificationTest[
    With[{lifted = ArrayCoerce[$plainMatrix, "Lazy"]},
        {ArrayDimensions[lifted], lifted[0]}
    ],
    {{2, 2}, $plainMatrix},
    TestID -> "types-lazy-lift-keeps-shape-and-values"
]

(* The expression that used to serve as the symbolic lift is a deferred tree:
   it reports the LAZY tier now, and still materializes back to its values. *)
VerificationTest[
    With[{deferred = Inactive[TensorProduct][$plainMatrix]},
        {ArrayTier[deferred], ArrayMaterialize[deferred]}
    ],
    {"Lazy", $plainMatrix},
    TestID -> "types-former-symbolic-lift-is-a-deferred-lazy-container"
]

(* Coercing to the tier a container is already on changes nothing. *)
VerificationTest[
    {
        ArrayCoerce[$sparse, "Explicit"] === $sparse,
        ArrayCoerce[$lazyFunction, "Lazy"] === $lazyFunction,
        ArrayCoerce[$overReals, "Symbolic"] === $overReals
    },
    {True, True, True},
    TestID -> "types-coerce-to-the-same-tier-is-the-identity"
]

(* A domain is an upper bound on the elements, so widening it alone leaves the
   container as it is; a concrete element type converts. *)
VerificationTest[
    {ArrayCoerce[$sparse, Reals] === $sparse, ArrayElementType[ArrayCoerce[$real32, "Real64"]]},
    {True, "Real64"},
    TestID -> "types-coerce-element-domain-and-type"
]

VerificationTest[
    With[{coerced = ArrayCoerce[$plainMatrix, {"Lazy", "Real64"}]},
        {ArrayTier[coerced], ArrayDimensions[coerced]}
    ],
    {"Lazy", {2, 2}},
    TestID -> "types-coerce-tier-and-type-together"
]

(* Down the tier lattice is materialization, which is refused: it can be
   arbitrarily expensive and, for an unbound-parameter container, impossible. *)
VerificationTest[
    MatchQ[ArrayCoerce[$lazyFunction, "Explicit"], _ArrayCoerce],
    True,
    {ArrayCoerce::materialize},
    TestID -> "types-coerce-refuses-materialization"
]

VerificationTest[
    MatchQ[ArrayCoerce[$overReals, "Lazy"], _ArrayCoerce],
    True,
    {ArrayCoerce::materialize},
    TestID -> "types-coerce-refuses-symbolic-to-lazy"
]

(* Narrowing the precision or the domain loses values and is refused, with the
   message naming both types. *)
VerificationTest[
    MatchQ[ArrayCoerce[$real64, "Real32"], _ArrayCoerce],
    True,
    {ArrayCoerce::narrow},
    TestID -> "types-coerce-refuses-precision-narrowing"
]

VerificationTest[
    MatchQ[ArrayCoerce[$packedReal, Integers], _ArrayCoerce],
    True,
    {ArrayCoerce::narrow},
    TestID -> "types-coerce-refuses-domain-narrowing"
]

(* Narrowing a symbolic container to a machine type is the same refusal, which
   is symbolic absorption stated as a coercion: the only way to a machine type
   is materialization. *)
VerificationTest[
    MatchQ[ArrayCoerce[$overReals, "Real64"], _ArrayCoerce],
    True,
    {ArrayCoerce::narrow},
    TestID -> "types-coerce-refuses-narrowing-a-symbolic-container"
]

VerificationTest[
    MatchQ[ArrayCoerce[$symbolicEntries, "Real64"], _ArrayCoerce],
    True,
    {ArrayCoerce::narrow},
    TestID -> "types-coerce-refuses-an-unknown-element-domain"
]

(* A lazy container has no leafless symbolic form: it enters that tier only as
   an operand of a tree that carries a symbolic container. *)
VerificationTest[
    MatchQ[ArrayCoerce[$lazyFunction, "Symbolic"], _ArrayCoerce],
    True,
    {ArrayCoerce::notier},
    TestID -> "types-coerce-refuses-lazy-to-symbolic"
]

VerificationTest[
    MatchQ[ArrayCoerce[$plainMatrix, "Bogus"], _ArrayCoerce],
    True,
    {ArrayCoerce::badspec},
    TestID -> "types-coerce-rejects-a-bad-specification"
]

(* REGRESSION.  A numeric type name whose bit width is not one of the widths the
   precision order knows - "Real24", "Integer3" - parses as a type but names a
   precision with no place in the lattice.  It used to leave every comparison
   against it unevaluated, so the legality guard was neither True nor False and
   BOTH the guard and the refusal analysis declined: the call failed with no
   message at all.  Every failure is a messaged refusal, so it is rejected as
   the specification it is not. *)
VerificationTest[
    {MatchQ[ArrayCoerce[$real64, "Real24"], _ArrayCoerce], MatchQ[ArrayCoerce[$int64, "Integer3"], _ArrayCoerce]},
    {True, True},
    {ArrayCoerce::badspec, ArrayCoerce::badspec},
    TestID -> "types-coerce-rejects-a-width-outside-the-precision-order"
]

(* REGRESSION.  The same values answered two different precisions depending only
   on whether the list happened to be packed, and 64 was the packed answer, so a
   join could claim "Integer64" for an operand set holding 2^100.  A packed
   integer array is exact, like every other integer array. *)
VerificationTest[
    {
        ArrayUnify[{Developer`ToPackedArray[{1, 2}]}][[{"Domain", "ElementType"}]] ===
            ArrayUnify[{{1, 2}}][[{"Domain", "ElementType"}]],
        ArrayUnify[{Developer`ToPackedArray[{1, 2}], {1, 2^100}}]["ElementType"],
        ArrayUnify[{$packedReal}]["ElementType"]
    },
    {True, Missing["NotApplicable"], "Real64"},
    TestID -> "types-packing-does-not-change-the-element-spec"
]

VerificationTest[
    MatchQ[ArrayCoerce["junk", "Lazy"], _ArrayCoerce],
    True,
    {ArrayCoerce::nocontainer},
    TestID -> "types-coerce-rejects-non-containers"
]

EndTestSection[]


BeginTestSection["types - the mixing point"]

(* THE ACCEPTANCE CASE.  ArrayContract on a list of containers is where
   containers of different kinds meet: the result must be a container, and its
   tier must be the join of its operands' tiers rather than whichever operand's
   form happened to survive.  The explicit-with-lazy mix is the one that used to
   return an inactive expression satisfying no predicate at all. *)

$mixes = {
    {$sparse, $plainMatrix},
    {$sparse, $lazyFunction},
    {$sparse, $lazyPiecewise},
    {$sparse, $overReals},
    {$lazyFunction, $overReals},
    {$matrixOverReals, $overReals}
}

VerificationTest[
    Map[ArrayContainerQ[ArrayContract[#, {{1, 3}}]] &, $mixes],
    ConstantArray[True, 6],
    TestID -> "types-mixed-contraction-gives-a-container"
]

VerificationTest[
    Map[{ArrayTier[ArrayContract[#, {{1, 3}}]], ArrayUnify[#]["Tier"]} &, $mixes],
    {
        {"Explicit", "Explicit"},
        {"Lazy", "Lazy"},
        {"Lazy", "Lazy"},
        {"Symbolic", "Symbolic"},
        {"Symbolic", "Symbolic"},
        {"Symbolic", "Symbolic"}
    },
    TestID -> "types-mixed-contraction-has-the-joined-tier"
]

(* The result keeps the shape the tensor product and contraction give it, on
   every tier. *)
VerificationTest[
    Map[ArrayDimensions[ArrayContract[#, {{1, 3}}]] &, $mixes],
    {{2, 2}, {2, 2}, {2, 2}, {2}, {2}, {2}},
    TestID -> "types-mixed-contraction-keeps-its-shape"
]

(* The lazy result is lazy in the operand's own parameter, not in a vestigial
   one: binding it gives the contraction of the bound array. *)
VerificationTest[
    {
        ArrayReplaceAll[ArrayContract[{$sparse, $lazyFunction}, {{1, 3}}], {lzT -> 0.}],
        ArrayContract[Inactive[TensorProduct][$sparse, {{1., 0.}, {0., 1.}}], {{1, 3}}]
    },
    {{{1., 3.}, {2., 4.}}, {{1., 3.}, {2., 4.}}},
    TestID -> "types-lazy-contraction-stays-lazy-in-its-own-parameter"
]

(* ArrayObject wraps a mixed result like any other container and reports the
   joined tier and domain.  The domain of the lazy tier is unknown, so a mix
   that joins to it reports Missing, which is what an unknown domain does
   everywhere else too. *)
VerificationTest[
    Map[
        With[{obj = ArrayObject[ArrayContract[#, {{1, 3}}]]}, {ArrayObjectQ[obj], obj["Tier"], obj["Domain"]}] &,
        $mixes
    ],
    {
        {True, "Explicit", Integers},
        {True, "Lazy", Missing["NotApplicable"]},
        {True, "Lazy", Missing["NotApplicable"]},
        {True, "Symbolic", Reals},
        {True, "Symbolic", Reals},
        {True, "Symbolic", Reals}
    },
    TestID -> "types-arrayobject-reports-the-joined-tier-and-domain"
]

(* The joined DOMAIN of the operands is unaffected by the tier the result lands
   on: an unknown lazy domain contributes nothing, so every mix carries the
   domain of the operand that has one. *)
VerificationTest[
    Map[ArrayUnify[#]["Domain"] &, $mixes],
    {Integers, Integers, Integers, Reals, Reals, Reals},
    TestID -> "types-mixed-contraction-domain-join"
]

(* A single lazy container contracts through the same rule and stays lazy. *)
VerificationTest[
    With[{contraction = ArrayContract[Function[lzR, ConstantArray[lzR, {2, 2, 2, 2}]], {{1, 3}}]},
        {ArrayTier[contraction], ArrayDimensions[contraction]}
    ],
    {"Lazy", {2, 2}},
    TestID -> "types-single-lazy-container-contracts-lazily"
]

(* REGRESSION.  A head with no lazy-preserving rebuild materializes, and the
   result used to be lifted back to the Lazy tier by wrapping it in a constant
   Function - lazy in a FORMAL parameter no operand mentions.  Binding the
   operand's own parameters then gave back a Function instead of the contracted
   array, and the two heads disagreed: the same call with a Function operand
   substituted to the array directly.  The materialized result now stands for
   itself, the collapse to a more specific tier that ArrayTranspose and ArrayMap
   already report for such a head, and binding gives the array on both. *)
VerificationTest[
    With[{contraction = ArrayContract[{$sparse, $lazyParametric}, {{2, 3}}]},
        {
            ArrayContainerQ[contraction],
            ArrayDimensions[contraction],
            FreeQ[contraction, \[FormalX] | \[FormalT]],
            agreesQ[
                ArrayReplaceAll[contraction, {lzPa -> 1., lzPt -> 0.4}],
                boundContraction[{$sparse, $lazyParametric}, {lzPa -> 1., lzPt -> 0.4}, {{2, 3}}]
            ]
        }
    ],
    {True, {2, 2}, True, True},
    TestID -> "types-no-rebuild-contraction-binds-to-the-contracted-array"
]

VerificationTest[
    With[{contraction = ArrayContract[{$lazyParametric, SparseArray[{1., 1.}]}, {{2, 3}}]},
        {
            ArrayDimensions[contraction],
            agreesQ[
                ArrayReplaceAll[contraction, {lzPa -> 1., lzPt -> 0.4}],
                boundContraction[{$lazyParametric, SparseArray[{1., 1.}]}, {lzPa -> 1., lzPt -> 0.4}, {{2, 3}}]
            ]
        }
    ],
    {{2}, True},
    TestID -> "types-no-rebuild-contraction-binds-in-the-rank-1-case"
]

(* REGRESSION.  TWO lazy operands used to recurse through the rebuilds one
   operand at a time: the inner call returned a lazy container, the outer
   rebuild required an array and declined it, and the materialize fallback then
   contracted the INERT per-scalar expansion - closures, Indexed forms, nested
   Piecewise - arithmetically.  The answer was a container of the right tier and
   the right shape whose values were the contraction of nothing, so it was
   silent.  Every lazy operand is expanded per scalar instead and the
   contraction is explicit, which is the only route that agrees with binding
   first and contracting after. *)
VerificationTest[
    With[{operands = {$lazyFunction, $lazyPiecewise}, rules = {lzT -> 0.3, lzZ -> -1.}},
        With[{contraction = ArrayContract[operands, {{2, 3}}]},
            {
                ArrayContainerQ[contraction],
                ArrayDimensions[contraction],
                agreesQ[ArrayReplaceAll[contraction, rules], boundContraction[operands, rules, {{2, 3}}]]
            }
        ]
    ],
    {True, {2, 2}, True},
    TestID -> "types-two-lazy-operands-contract-to-the-contracted-values"
]

VerificationTest[
    With[{
        operands = {$sparse, $lazyFunction, $lazyPiecewise, $lazyParametric},
        rules = {lzT -> 0.3, lzZ -> -1., lzPa -> 1., lzPt -> 0.4}
    },
        With[{contraction = ArrayContract[operands, {{2, 3}, {4, 5}, {6, 7}}]},
            {
                ArrayContainerQ[contraction],
                ArrayDimensions[contraction],
                agreesQ[
                    ArrayReplaceAll[contraction, rules],
                    boundContraction[operands, rules, {{2, 3}, {4, 5}, {6, 7}}]
                ]
            }
        ]
    ],
    {True, {2, 2}, True},
    TestID -> "types-several-lazy-operands-contract-to-the-contracted-values"
]

(* REGRESSION.  A full contraction to a SCALAR has no container to be, and the
   mixed case used to fall through to the tensor-product clause: an inactive
   node carrying a lazy leaf, which satisfies no classification predicate and
   which ArrayMaterialize could not resolve either - neither a container, nor a
   scalar, nor materializable.  The per-scalar expansion gives a scalar
   expression that substitutes to the contracted value, which is what the
   all-explicit control computes outright. *)
VerificationTest[
    With[{identity = SparseArray[{{1., 0.}, {0., 1.}}]},
        {
            FreeQ[ArrayContract[{$lazyFunction, identity}, {{1, 3}, {2, 4}}], _TensorContract | _Inactive],
            Abs[ArrayReplaceAll[ArrayContract[{$lazyFunction, identity}, {{1, 3}, {2, 4}}], lzT -> 0.3] - 2 Cos[0.3]] < 10.^-12,
            Abs[
                ArrayReplaceAll[ArrayContract[{$lazyPiecewise, identity}, {{1, 3}, {2, 4}}], lzZ -> -1.] - 5.
            ] < 10.^-12,
            ArrayContract[{SparseArray[{{1., 2.}, {3., 4.}}], identity}, {{1, 3}, {2, 4}}],
            (* the one-operand form of the same contraction: the trace of a lazy
               container, which TensorContract would otherwise take of the
               expression TREE *)
            Abs[ArrayReplaceAll[ArrayContract[$lazyFunction, {{1, 2}}], lzT -> 0.3] - 2 Cos[0.3]] < 10.^-12
        }
    ],
    {True, True, True, 5., True},
    TestID -> "types-rank-0-mixed-contraction-substitutes-to-the-contracted-value"
]

EndTestSection[]
