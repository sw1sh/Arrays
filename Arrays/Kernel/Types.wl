Package["Wolfram`Arrays`"]

PackageExport[ArrayTier]
PackageExport[ArrayElementDomain]
PackageExport[ArrayElementType]
PackageExport[ArrayUnify]
PackageExport[ArrayCoerce]

(* The joins are read at call time by the mixing point in Structural.wl and by
   the summary box in ArrayObject.wl; nothing here is spliced into a definition
   left-hand side, so this file has no load-order dependency on any other. *)
PackageScope[arrayTierJoin]
PackageScope[arrayElementSpec]
PackageScope[arrayElementSpecJoin]
PackageScope[elementSpecDomain]
PackageScope[elementSpecType]


ArrayTier::usage = "ArrayTier[a] gives the tier of an array container: \"Explicit\", \"Lazy\" or \"Symbolic\"; anything that is not a container gives Missing[\"NotAContainer\"]. The tiers are ordered Explicit < Lazy < Symbolic, most specific to most general, and the tier of an operation over several containers is the maximum of its operands' tiers."

ArrayElementDomain::usage = "ArrayElementDomain[a] gives the element domain of an array container, one of Integers, Rationals, Algebraics, Reals or Complexes, ordered Integers < Rationals < Algebraics < Reals < Complexes. A numeric container type maps into the same lattice (\"Integer64\" and \"UnsignedInteger8\" give Integers, \"Real32\" gives Reals, \"ComplexReal64\" gives Complexes), the exact entries of a List or SparseArray are inferred from the values, a symbolic container gives its declared domain, defaulting to Complexes as Vectors, Matrices and Arrays do, and a structural tree gives the join of its operands. A container whose domain is not known, including every lazy container, gives Missing[\"NotApplicable\"], which contributes nothing to a join rather than making it unknown."

ArrayElementType::usage = "ArrayElementType[a] gives the concrete element type of an array container that carries one, as NumericArray and TabularColumn do (\"Real64\", \"Integer32\", ...); every other container gives Missing[\"NotApplicable\"] and describes its elements through ArrayElementDomain instead."

ArrayUnify::usage = "ArrayUnify[{a1, a2, ...}] gives an Association describing the common representation of the given array containers: \"Tier\" is the joined tier, \"Domain\" the joined element domain, \"ElementType\" the concrete numeric type of the join where it has one, and \"Arrays\" the operands coerced to the joined tier. Widening the domain never narrows the precision, so an \"Integer64\" operand joined with a \"Real32\" one gives \"Real64\"; a symbolic operand absorbs, since narrowing it to a machine type would mean materializing it; and an operand whose domain is unknown contributes nothing to the join. An operand with no lift to the joined tier is returned unchanged, which is the lazy operand of a symbolic join: it is already a legal leaf of a symbolic tree, and materializing it is the downward move the tier join forbids."

ArrayCoerce::usage = "ArrayCoerce[a, spec] coerces the array container a toward spec, which names a tier (\"Explicit\", \"Lazy\" or \"Symbolic\"), an element domain (Integers, Rationals, Algebraics, Reals or Complexes), an element type (\"Real64\", \"Integer32\", ...), or a list of a tier and one of those. Coercion may only move UP both lattices: an explicit container lifts to the lazy tier as a constant Function of a formal parameter, materializing a container whose form is not a plain array first, and to the symbolic tier as an inactive tensor product; a request that would move down either lattice - materializing a lazy or symbolic container, narrowing Reals to Integers, narrowing \"Real64\" to \"Real32\", or coercing a container whose element domain is unknown - is refused with a message naming both types instead of being cast silently. Coercing to a concrete element type gives a NumericArray of that type, and a value that does not survive it is a refusal rather than a rounded value. Coercing to a domain alone changes nothing, since a domain is an upper bound on the elements and a narrower container already meets a wider one."


ArrayUnify::nocontainers = "`1` is not a non-empty list of supported array containers; ArrayUnify accepts a list of expressions satisfying ArrayContainerQ."

ArrayCoerce::nocontainer = "`1` is not a supported array container; ArrayCoerce accepts any expression satisfying ArrayContainerQ."

ArrayCoerce::badspec = "`1` is not a coercion specification; use a tier (\"Explicit\", \"Lazy\", \"Symbolic\"), an element domain (Integers, Rationals, Algebraics, Reals, Complexes), an element type (\"Real64\", ...), or a list of them."

ArrayCoerce::narrow = "an array of element type `1` cannot be coerced to `2`: coercion may only widen a KNOWN element domain and precision, and the requested change loses values."

ArrayCoerce::materialize = "a `1` container cannot be coerced to the `2` tier: moving down the tier lattice is materialization, which can be arbitrarily expensive and, for an unbound-parameter container, impossible; ArrayMaterialize performs it explicitly."

ArrayCoerce::notier = "a `1` container has no leafless `2` form: it enters that tier only as an operand of a structural tree that carries a symbolic container."

ArrayCoerce::coerce = "`1` cannot be coerced to `2`."


(* === axis 1: the tier lattice ===

   A total order, most specific to most general, whose join is the maximum:
   binding a lazy container's parameters yields an explicit one, and
   specializing a symbolic container yields a lazy or explicit one, so
   generality increases to the right.  A result may be MORE specific than the
   join when an operation genuinely collapses generality, but that is an
   opportunistic simplification and never the contract. *)

$arrayTiers = {"Explicit", "Lazy", "Symbolic"}

$arrayTierIndex = AssociationThread[$arrayTiers -> Range[Length[$arrayTiers]]]


(* A container belongs to exactly one tier, and Which pins the probe order
   independently of definition ordering.  The last branch answers for anything
   that is not a container at all, which the tier join then propagates rather
   than reporting a tier nothing has. *)
ArrayTier[a_] := Which[
    ArrayExplicitQ[a], "Explicit",
    ArrayLazyQ[a], "Lazy",
    ArraySymbolicQ[a], "Symbolic",
    True, Missing["NotAContainer"]
]


arrayTierJoin[arrays_List] := With[{indices = Lookup[$arrayTierIndex, ArrayTier /@ arrays, 0]},
    If[arrays === {} || MemberQ[indices, 0], Missing["NotAContainer"], $arrayTiers[[Max[indices]]]]
]


(* === axis 2: the element lattice ===

   Numeric container types and symbolic domains are two spellings of one
   lattice and unify in it.  An element spec is the pair {domain, precision}:
   the domain is one of the five below, and the precision is a SECONDARY
   component whose own order runs exact < 8 < 16 < 32 < 64 < symbolic.

   The two components join independently, which is what keeps a widened domain
   from narrowing the precision: "Integer64" with "Real32" widens Integers to
   Reals and keeps 64, giving "Real64" rather than the "Real32" that taking the
   second operand's type wholesale would give.  Symbolic precision is the TOP of
   the precision order, which is symbolic absorption: a symbolic operand joined
   with any machine one stays symbolic over the joined domain, because narrowing
   it to a machine type would mean materializing it and the tier join already
   forbids that.  Exact precision is the BOTTOM: an exact operand does not force
   exactness on a machine one, matching the fidelity rule of ArrayPack, which
   still governs any actual packing decision.

   An unknown or inapplicable domain is Missing and contributes NOTHING to a
   join: it is dropped, and only a join in which every operand is unknown is
   itself unknown.  Poisoning the join instead would collapse every mix
   involving a container that carries no element metadata. *)

$arrayElementDomains = {Integers, Rationals, Algebraics, Reals, Complexes}

$arrayElementDomainIndex = AssociationThread[$arrayElementDomains -> Range[Length[$arrayElementDomains]]]

$arrayElementPrecisions = {"Exact", 8, 16, 32, 64, "Symbolic"}

$arrayElementPrecisionIndex = AssociationThread[$arrayElementPrecisions -> Range[Length[$arrayElementPrecisions]]]


domainJoin[domains_List] := $arrayElementDomains[[Max[Lookup[$arrayElementDomainIndex, domains, 1]]]]

precisionJoin[precisions_List] := $arrayElementPrecisions[[Max[Lookup[$arrayElementPrecisionIndex, precisions, 1]]]]


arrayElementSpecJoin[specs_List] := With[{known = DeleteMissing[specs]},
    If[
        known === {},
        Missing["NotApplicable"],
        {domainJoin[known[[All, 1]]], precisionJoin[known[[All, 2]]]}
    ]
]


elementSpecDomain[{domain_, _}] := domain

elementSpecDomain[___] := Missing["NotApplicable"]


(* Rendering a spec back to a container type.  Only a machine precision has one:
   an exact or symbolic spec is described by its domain alone.  A real or
   complex domain has no 8- or 16-bit machine type that could hold the operand
   that carried the wider domain, so those widths round UP to 32 - a widening,
   which is the direction coercion is allowed to move in. *)

machineRealWidth[width_Integer] := If[width > 32, 64, 32]

elementSpecType[{Integers, width_Integer}] := "Integer" <> ToString[width]

elementSpecType[{Reals, width_Integer}] := "Real" <> ToString[machineRealWidth[width]]

elementSpecType[{Complexes, width_Integer}] := "ComplexReal" <> ToString[machineRealWidth[width]]

elementSpecType[___] := Missing["NotApplicable"]


(* The numeric container types map into the lattice by name, keeping the bit
   width as the precision: the signed and unsigned integer types share the
   Integers domain, and an unsigned operand therefore joins to a SIGNED type,
   which is the only rendering that holds both operands. *)

typeWidth[type_String] := ToExpression[StringDelete[type, LetterCharacter]]

numericTypeSpec[type_String] := Which[
    StringMatchQ[type, ("Integer" | "UnsignedInteger") ~~ DigitCharacter ..], {Integers, typeWidth[type]},
    StringMatchQ[type, "Real" ~~ DigitCharacter ..], {Reals, typeWidth[type]},
    StringMatchQ[type, "ComplexReal" ~~ DigitCharacter ..], {Complexes, typeWidth[type]},
    True, Missing["NotApplicable"]
]

numericTypeSpec[___] := Missing["NotApplicable"]


(* Column element types arrive as the same type names, wrapped in one
   TypeSpecifier["ListVector"] per level for a column of array-valued entries;
   columnLeafType in Shape.wl unwraps them.  A type that is not numeric
   ("String", "NumberExpression", ...) has no domain in this lattice. *)

columnTypeSpec[type_] := numericTypeSpec[columnLeafType[type]]


(* Value inference for the containers that carry no type metadata.  The packed
   rungs answer for a packed array without touching an element; everything else
   is scanned, and a single non-numeric element makes the whole domain unknown
   rather than Complexes, so a symbolic-entry array contributes nothing to a
   join instead of pushing it to the top of the lattice.

   Algebraics is not inferred from values: deciding it needs Element, which is
   neither cheap nor decidable in general.  The domain is reachable from a
   DECLARED symbolic domain and as a coercion target, and an algebraic value
   scans as Reals or Complexes, which are wider and therefore sound. *)

scalarDomainIndex[_Integer] := 1

scalarDomainIndex[_Rational] := 2

scalarDomainIndex[x_] := Which[! NumericQ[x], 0, TrueQ[Im[x] == 0], 4, True, 5]


scalarPrecision[x_] := If[MachineNumberQ[x], 64, "Exact"]


scannedSpec[{}] := Missing["NotApplicable"]

scannedSpec[values_List] := With[{indices = Map[scalarDomainIndex, values]},
    If[
        MemberQ[indices, 0],
        Missing["NotApplicable"],
        {$arrayElementDomains[[Max[indices]]], precisionJoin[Map[scalarPrecision, values]]}
    ]
]


(* A packed INTEGER array is exact, and its 64-bit machine width is a storage
   detail rather than an element precision: reporting 64 would make the same
   values answer two different precisions depending only on whether the list
   happens to be packed (the scanned rung below gives "Exact" for an integer,
   since MachineNumberQ is False for one), and the join would then claim an
   "Integer64" element type for an operand set holding values no Integer64 can
   store.  The packed REAL and COMPLEX rungs do carry a machine precision: their
   elements are machine numbers, which is exactly what the scanned rung would
   answer for them one element at a time. *)

valuesSpec[a_] := Which[
    Developer`PackedArrayQ[a, Integer], {Integers, "Exact"},
    Developer`PackedArrayQ[a, Real], {Reals, 64},
    Developer`PackedArrayQ[a, Complex], {Complexes, 64},
    True, scannedSpec[Flatten[a]]
]


(* Per-container element specs.  Every clause answers from stored metadata or
   from values the container already holds, and none of them materializes: the
   summary box of ArrayObject reads the domain of every admitted head, and a
   test blocks ArrayMaterialize away while it renders each one. *)

arrayElementSpec[a_NumericArray] := numericTypeSpec[NumericArrayType[a]]

arrayElementSpec[a_TabularColumn] := columnTypeSpec[a["ElementType"]]

arrayElementSpec[a_EventSeries] := columnTypeSpec[a["Values"]["ElementType"]]

arrayElementSpec[a_ByteArray] := If[ByteArrayQ[a], {Integers, 8}, Missing["NotApplicable"]]

(* QuantityArray carries its unit as separate metadata, so the domain is the one
   of its magnitudes; QuantityMagnitude hands back the internal packed
   magnitudes essentially for free, where Normal would build an array of
   Quantity expressions. *)
arrayElementSpec[a_QuantityArray] := valuesSpec[QuantityMagnitude[a]]

(* The implicit value counts: an integer-valued SparseArray of machine reals is
   not an integer array, and the default 0 of a real array does not make it one
   either, since the domains join. *)
arrayElementSpec[a_SparseArray] := valuesSpec[Append[a["ExplicitValues"], a["ImplicitValue"]]]

arrayElementSpec[a_List] := valuesSpec[a]

(* The symbolic array heads are spelled out rather than spliced from the
   symbolicArrayHead alias in Classification.wl, for the reason ArrayName in
   Structural.wl spells them out: an assignment evaluates its left-hand side, so
   an alias there would freeze into a pattern that can never match.  The domain
   argument defaults to Complexes, as Vectors, Matrices and Arrays do. *)

arrayElementSpec[(VectorSymbol | MatrixSymbol | ArraySymbol)[_, _, domain_ : Complexes, ___]] := symbolicSpec[domain]

arrayElementSpec[s_Symbol ? AtomQ] := symbolicSpec[assumptionDomain[s]]

symbolicSpec[domain_] := If[KeyExistsQ[$arrayElementDomainIndex, domain], {domain, "Symbolic"}, Missing["NotApplicable"]]

(* A structural tree has the domain its operands join to, which is what makes a
   contraction of a mixed operand set report the joined domain: the node table
   of Classification.wl picks out the tensor operands, so a contraction
   specification is not mistaken for one.  Every remaining container - the whole
   lazy tier included - has no element metadata this tier can read without
   evaluating it, and answers Missing. *)
arrayElementSpec[a_] := With[{operands = structuralNodeOperands[a]},
    If[ListQ[operands], arrayElementSpecJoin[Map[arrayElementSpec, operands]], Missing["NotApplicable"]]
]


ArrayElementDomain[a_] := elementSpecDomain[arrayElementSpec[a]]


ArrayElementType[a_NumericArray] := NumericArrayType[a]

ArrayElementType[a_TabularColumn] := a["ElementType"]

ArrayElementType[___] := Missing["NotApplicable"]


(* === coercion ===

   Coercion moves a container ALONG the lattices and never against them.  Up the
   tier lattice it is free: an explicit array becomes a constant lazy Function
   (lazyConstant, which lives beside the head it constructs in Lazy.wl) or an
   inactive tensor product, both of which are containers of the same shape whose
   materialization gives the array back.  Down the tier lattice it is
   MATERIALIZATION, which is refused here and left to ArrayMaterialize: it can
   be arbitrarily expensive, and for a container whose parameters are unbound it
   is not possible at all.

   The lazy-to-symbolic lift is the one upward move with no form: an inactive
   tensor product over a lazy operand and no symbolic one is not a container,
   because admitting one would make classification of an arbitrary inactive
   expression evaluate a lazy leaf.  A lazy container reaches the symbolic tier
   only as an operand of a tree that also carries a symbolic container, which is
   exactly the situation in which a tier join asks for it. *)

$coercionTarget = <|"Tier" -> Automatic, "Domain" -> Automatic, "Precision" -> Automatic|>

addCoercionPart[$Failed, _] := $Failed

(* A numeric type name is a coercion target only when its bit width is one of
   the widths the precision order knows: numericTypeSpec parses any digit
   sequence, so "Real24" and "Integer3" name a spec whose precision has no place
   in the lattice.  Admitting one would leave every comparison against it
   undecided - and a legality guard that is neither True nor False declines
   silently, so the call would fail with no message at all.  It is rejected as a
   specification instead, which is what it is. *)

coercionPrecisionQ[type_] := ! MissingQ[type] && KeyExistsQ[$arrayElementPrecisionIndex, Last[type]]

addCoercionPart[target_, part_] := With[{type = numericTypeSpec[part]},
    Which[
        KeyExistsQ[$arrayTierIndex, part], Append[target, "Tier" -> part],
        KeyExistsQ[$arrayElementDomainIndex, part], Append[target, "Domain" -> part],
        coercionPrecisionQ[type], Append[target, <|"Domain" -> First[type], "Precision" -> Last[type]|>],
        True, $Failed
    ]
]

coercionTarget[spec_] := Fold[addCoercionPart, $coercionTarget, Flatten[{spec}]]


targetElementSpec[target_] := {Lookup[target, "Domain"], Lookup[target, "Precision"]}

elementTargetQ[target_] := targetElementSpec[target] =!= {Automatic, Automatic}


(* Lattice legality, which is what the guard tests.  A tier target is legal when
   it is at or above the container's own tier, and an element target when the
   container's own domain is known and neither component of the target lies
   below it.  A target that is legal here can still have no form - the
   lazy-to-symbolic lift, or a machine type that no value survives - and those
   refuse on the way out, below. *)

tierTargetQ[a_, target_] := With[{tier = Lookup[target, "Tier"]},
    tier === Automatic || Lookup[$arrayTierIndex, tier, 0] >= Lookup[$arrayTierIndex, ArrayTier[a], 0]
]

(* Both comparisons are TOTAL: an index that is not in the lattice reads as 0,
   below every rung, so an unrecognized component makes the target illegal
   rather than leaving the Which - and with it the guard and the refusal
   analysis that reads it - stalled on a non-boolean comparison. *)

domainIndex[domain_] := Lookup[$arrayElementDomainIndex, domain, 0]

precisionIndex[precision_] := Lookup[$arrayElementPrecisionIndex, precision, 0]

elementTargetLegalQ[a_, target_] := With[{
    spec = arrayElementSpec[a],
    domain = Lookup[target, "Domain"],
    precision = Lookup[target, "Precision"]
},
    Which[
        ! elementTargetQ[target], True,
        MissingQ[spec], False,
        domain =!= Automatic && domainIndex[domain] < domainIndex[First[spec]], False,
        precision =!= Automatic && precisionIndex[precision] < precisionIndex[Last[spec]], False,
        True, True
    ]
]

coercionLegalQ[a_, target_] := target =!= $Failed && tierTargetQ[a, target] && elementTargetLegalQ[a, target]


(* Coercing to a concrete element type gives a NumericArray of that type: it is
   the container that carries an element type outright, so the result states its
   own domain and precision rather than leaving them to be inferred again.  The
   conversion is the kernel's, which declines a value that does not survive the
   target type (a big integer, a non-integral real), and a declined conversion
   is a refusal here rather than a rounded value. *)

numericArrayData[a_NumericArray] := a

numericArrayData[a_List] := a

numericArrayData[a_] := ArrayMaterialize[a]

coerceElementType[a_, target_] := With[{type = elementSpecType[targetElementSpec[target]]},
    If[
        MissingQ[type],
        a,
        With[{converted = Quiet[NumericArray[numericArrayData[a], type]]},
            If[NumericArrayQ[converted], converted, Missing["NotCoercible"]]
        ]
    ]
]


(* The tier lift, which answers Missing where the target has no form.  The
   classification tier decides that, not a head test: a lift whose result is not
   a container has not lifted anything. *)

coerceTier[a_, Automatic] := a

coerceTier[a_, tier_] := Which[
    ArrayTier[a] === tier, a,
    tier === "Lazy", liftedContainer[lazyConstant[a]],
    tier === "Symbolic", liftedContainer[Inactive[TensorProduct][a]],
    True, Missing["NotCoercible"]
]

liftedContainer[a_] := If[ArrayContainerQ[a], a, Missing["NotCoercible"]]


coercedArray[a_, target_] := With[{converted = coerceElementType[a, target]},
    If[MissingQ[converted], converted, coerceTier[converted, Lookup[target, "Tier"]]]
]


(* Refusals are messaged and the call is left unevaluated, never cast silently.
   The reason is picked apart here so that the message names what actually went
   wrong: a specification that is not one, a downward tier move, a lazy operand
   with no symbolic form, a narrowing or unknown element domain, and a
   conversion that no value survives. *)

specLabel[spec_] := Replace[elementSpecType[spec], _Missing :> elementSpecDomain[spec]]

coercionRefusal[a_, spec_] := With[{target = coercionTarget[spec]},
    Which[
        target === $Failed,
        Message[ArrayCoerce::badspec, spec],

        ! tierTargetQ[a, target],
        Message[ArrayCoerce::materialize, ArrayTier[a], Lookup[target, "Tier"]],

        ! elementTargetLegalQ[a, target],
        Message[ArrayCoerce::narrow, specLabel[arrayElementSpec[a]], specLabel[targetElementSpec[target]]],

        ArrayTier[a] === "Lazy" && Lookup[target, "Tier"] === "Symbolic",
        Message[ArrayCoerce::notier, "Lazy", "Symbolic"],

        True,
        Message[ArrayCoerce::coerce, a, spec]
    ]
]


ArrayCoerce[a_ ? ArrayContainerQ, spec_] := Module[{result},
    result /; ! MissingQ[result = coercedArray[a, coercionTarget[spec]]]
] /; coercionLegalQ[a, coercionTarget[spec]]

(* Reached when the clause above declines, which is a legal target with no
   form; the refusal analysis covers that case too. *)
ArrayCoerce[a_ ? ArrayContainerQ, spec_] /; (coercionRefusal[a, spec]; False) := Null

ArrayCoerce[a_, _] /; ! ArrayContainerQ[a] && (Message[ArrayCoerce::nocontainer, a]; False) := Null


(* === unification ===

   The joined tier and domain, plus the operands coerced to the joined tier, so
   that a mixing operation asks once and then works in one representation.  An
   operand with no lift to the joined tier is returned unchanged rather than
   materialized: that is the lazy operand of a symbolic join, which is already a
   legal leaf of the tree such a join builds. *)

unifiedOperand[a_, tier_] := Replace[coerceTier[a, tier], _Missing :> a]

ArrayUnify[arrays : {__ ? ArrayContainerQ}] := With[{
    tier = arrayTierJoin[arrays],
    spec = arrayElementSpecJoin[Map[arrayElementSpec, arrays]]
},
    <|
        "Tier" -> tier,
        "Domain" -> elementSpecDomain[spec],
        "ElementType" -> elementSpecType[spec],
        "Arrays" -> Map[unifiedOperand[#, tier] &, arrays]
    |>
]

ArrayUnify[arrays_] /; ! MatchQ[arrays, {__ ? ArrayContainerQ}] &&
    (Message[ArrayUnify::nocontainers, arrays]; False) := Null
