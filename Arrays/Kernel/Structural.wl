Package["Wolfram`Arrays`"]

PackageExport[ArrayTranspose]
PackageExport[ArrayContract]
PackageExport[ArrayPart]
PackageExport[SimplifyArray]
PackageExport[ArrayName]
PackageExport[ArrayMap]
PackageExport[ArrayReplaceAll]
PackageExport[ArrayConjugate]

ArrayTranspose::usage = "ArrayTranspose[a, perm] transposes an array container by the given permutation, composing permutations of nested Transpose forms, and keeping symbolic containers in unevaluated form; a lazy container stays lazy where its head supplies a lazy-preserving rebuild (the value grid of an InterpolatingFunction, the branch values of a Piecewise, the body of a Function) and materializes through ArrayMaterialize where it does not, as for a ParametricFunction."

ArrayContract::usage = "ArrayContract[a, pairs] contracts the given index pairs of an array container, keeping symbolic containers in inactive TensorContract form; a lazy container contracts through its head's lazy-preserving rebuild and stays lazy, unless the contraction leaves no array at all. The pairs are slot groups: a group of two slots is an ordinary contraction, a group of one slot sums that slot, and a group of three or more is a generalized trace over the slots it names; every slot names a level the operands have and names it once, and a specification that does not is left as an inactive TensorContract node without the tensor product being built. A List argument is ONE array, whose own levels the pairs number, so ArrayContract[{{1, 2}, {3, 4}}, {{1, 2}}] is a trace, matching its SparseArray form; the equivalence holds for a List whose elements are not themselves array containers.\nArrayContract[Inactive[TensorProduct][a1, a2, ...], pairs] contracts an operand SET, the pairs numbering the levels of the operands concatenated. The operands are contracted against each other and the tensor product is never built, which is what keeps the containers: an all-SparseArray set gives a SparseArray, packed operands give a packed array, exact operands stay exact, and a QuantityArray set gives a QuantityArray carrying the product of the units. A contraction over a SparseArray with a non-zero background, and one over two structured atoms such as SymmetrizedArray, is dense, that being what contracting the operands pairwise gives; a node of ONE operand has no product to keep that operand out of and contracts it bare, so a single structured operand keeps its structure. The result is a container of the tier ArrayUnify joins the operands to: explicit operands contract through the tensor product, an operand set carrying a symbolic container gives a symbolic node, and one carrying exactly one lazy container and no symbolic one is contracted against the value grid, branch values or body of that operand and stays lazy where its head supplies a lazy-preserving rebuild. An operand set carrying SEVERAL lazy containers, and a contraction that leaves no array at all, have no lazy form between them: every lazy operand is expanded per scalar and the contraction is explicit, giving an array - or, for a full contraction, a scalar - of expressions that substitute to the contracted values. A NumericArray, a ByteArray, a Dataset, a Tabular and an ArrayObject handle among the operands are materialized first, TensorContract having no evaluation on those heads. A list that holds an array container and is not a list of plain Lists is an operand set given in place of a node, and is declined with a message naming the tensor-product spelling, since a List already means one array; a declined call is not an array container, so it has no tier and no dimensions, no accessor answers for it, and Normal of it is the call itself, its operands unconverted."

ArrayPart::usage = "ArrayPart[a, {i1, i2, ...}] gives the part of an array container at the given indices, slicing symbolic containers structurally and expanding a lazy container per scalar first, since Part on an inert lazy form reaches the expression tree rather than the array; a deferred structural tree, whose leaves are all explicit, is activated first for the same reason, and a structural tree that carries a symbolic container is left unevaluated rather than sliced wrongly; All entries keep the corresponding level."

SimplifyArray::usage = "SimplifyArray[a] removes trivial structural wrappers such as empty contractions, singleton tensor products and identity transposes from a symbolic array expression."

ArrayName::usage = "ArrayName[a] gives the name of a symbolic array container: the first argument of VectorSymbol, MatrixSymbol or ArraySymbol, an atomic symbol itself, and None otherwise."

ArrayMap::usage = "ArrayMap[f, a] maps f over the deepest elements of an explicit array container, preserving SparseArray structure and repacking packed arrays where the result packs without coercion.\nArrayMap[f, a, level] maps at the given level, densifying a SparseArray when level is not its element level {-1} or {rank}. At element level a lazy container rebuilds and stays lazy where its head supplies a lazy-preserving rebuild; a head with no rebuild, such as a ParametricFunction, and any lazy container mapped off element level materialize through ArrayMaterialize, since a map that crosses index levels commutes with no rebuild. An InterpolatingFunction whose remapped value grid stops being numeric leaves ArrayMap unevaluated. A deferred structural tree, whose leaves are all explicit, is activated and f is mapped over its elements; a leafless symbolic container applies f to the whole container at element level; otherwise ArrayMap is left unevaluated."

ArrayReplaceAll::usage = "ArrayReplaceAll[a, rules] applies rules to an array container: for a lazy container the whole expression is substituted at once, so substituting all parameters evaluates the array-valued function a single time; a Function is the exception in form only, since its parameters are bound rather than free - a rule keyed on every parameter applies the Function, again a single whole-array evaluation, a rule keyed on only some of them curries and gives a Function of the parameters that are still free, and the remaining rules rewrite the free symbols of its body; the same bound-parameter treatment reaches an unapplied Function carried INSIDE an explicit container, such as the per-scalar expansion of a Function container or one element of it, which a plain ReplaceAll would rewrite into Function[0.5, ...]; for a SparseArray the rules map over the explicit values; a structured atom such as SymmetrizedArray or a wrapper container materializes first, since ReplaceAll does not penetrate such atoms; any other container uses ReplaceAll."

ArrayConjugate::usage = "ArrayConjugate[a] conjugates an array container, preserving SparseArray, packed and NumericArray containers, keeping a lazy container lazy where its head supplies a lazy-preserving rebuild and materializing it where it does not, and keeping symbolic containers in unevaluated form."


ArrayContract::operands = "`1` is a list of array containers: a List argument is one array, whose own levels the pairs number, and a set of operands to contract against each other is spelled Inactive[TensorProduct][a1, a2, ...], over whose concatenated levels the pairs run."


(* The lazy-preserving structural rebuild is per head and lives in the registry
   of Lazy.wl: lazyStructuralOp rebuilds where the head supplies one and
   materializes where it does not.  Flatten, reshape and transpose in Vector.wl
   go through the same entry point. *)


ArrayName[t_Symbol ? AtomQ] := t

(* The symbolic array heads are spelled out rather than spliced from the
   symbolicArrayHead alias in Classification.wl: an assignment evaluates its
   left-hand side, so an alias there would silently freeze into a pattern that
   can never match if this file ever loaded first. *)
ArrayName[(VectorSymbol | MatrixSymbol | ArraySymbol)[s_, ___]] := s

ArrayName[___] := None


(* setDimensions lives in Shape.wl: re-registering an atomic symbol is a shape
   operation on its $Assumptions entry. *)

(* Part on an inert lazy form reaches the expression TREE, not the array:
   ifn[t][[1]] gives t, a Piecewise indexes its own branch list, and an
   unapplied Function hands back its parameter symbol.  A lazy container is
   therefore expanded per scalar first, and the part is taken of that explicit
   array of scalar lazy expressions. *)
ArrayPart[a_ ? lazyContainerQ, is : {__}, k_ : 0] := ArrayPart[ArrayMaterialize[a], is, k]

(* Part on a structural tree reaches the expression TREE for the same reason:
   the first part of Inactive[TensorContract][inner, c] is inner, and the first
   part of Inactive[TensorProduct][a, b] is a, which even has the right SHAPE -
   so the wrong value is silent.  A DEFERRED tree therefore materializes first,
   exactly as a lazy container does.  A tree that carries a symbolic container
   has no materialization and no structural slice rule here, so the generic
   clause below declines it and ArrayPart is left unevaluated rather than
   handing back an operand of the node. *)
ArrayPart[a_ ? deferredTreeQ, is : {__}, k_ : 0] := ArrayPart[ArrayMaterialize[a], is, k]

ArrayPart[t_, {i_, is___}, k_ : 0] := With[{nest = Nest[#[] &, #, k] &},
    If[ i === All,
        ArrayPart[t, {is}, k + 1],
        ArrayPart[
            Replace[
                t,
                {
                    (VectorSymbol | ArraySymbol)[s_, {_} | _Integer, dom___] /; k < 1 :> ArraySymbol[nest[s][i], {}, dom],
                    (MatrixSymbol | ArraySymbol)[s_, ds : {_, _}, dom_ : Reals, ___] /; k < 2 :> VectorSymbol[nest[s][i], Drop[ds, {k + 1}], dom],
                    HoldPattern[ArraySymbol[s_, ds_List, dom_ : Reals, ___]] /; k < Length[ds] :> If[Length[ds] - k == 3, MatrixSymbol, ArraySymbol][nest[s][i], Drop[ds, {k + 1}], dom],
                    s_Symbol ? AtomQ :> setDimensions[s, Drop[ArrayDimensions[t], {k + 1}]],
                    _ :> (Part[t, ##] & @@ Append[ConstantArray[All, k], i])
                }
            ],
            {is},
            0
        ]
    ]
] /; ! structuralNodeQ[t]

ArrayPart[t_, {}, ___] := t


(* QuantityArray transposes natively and keeps its wrapper on the generic
   clause; the remaining wrappers have no native Transpose and materialize. *)
ArrayTranspose[t_ ? opaqueWrapperQ, perm_] := ArrayTranspose[ArrayMaterialize[t], perm]

ArrayTranspose[t_, perm_] := If[ZeroArrayQ[t], {}, SimplifyArray @ Transpose[t, Replace[perm, m_ <-> n_ :> Cycles[{{m, n}}]]]]

ArrayTranspose[(Verbatim[Transpose] | Inactive[Transpose])[t_, perm1_], perm2_] := ArrayTranspose[t, PermutationList[PermutationProduct[perm1, perm2]]]

ArrayTranspose[a_ ? lazyContainerQ, perm_] :=
    lazyStructuralOp[Transpose[#, Replace[perm, m_ <-> n_ :> Cycles[{{m, n}}]]] &, a]


(* === the mixing point ===

   An operand SET is spelled Inactive[TensorProduct][a1, a2, ...] and a List is
   ONE array: the pairs of a node number the levels of its operands
   concatenated, while the pairs of a List number that one array's own levels,
   so a plain nested-List matrix contracts exactly as its SparseArray form does.
   One spelling used to carry both readings, told apart by whether every element
   of the list was itself a List, which read an operand set of plain nested
   Lists as a single array and answered a different question - silently, and in
   a container that looked right.  A node head has one reading, and the list of
   containers is declined below rather than answered.

   The node is also the one place in the paclet where containers of DIFFERENT
   kinds meet, so it dispatches on the tier join of its operands (arrayTierJoin
   in Types.wl) rather than on whichever operand's form happens to survive
   TensorContract.  Two of the three joins contract through the node as it
   stands: with every operand explicit the contraction computes through it, and
   with at least one symbolic operand the whole node is a symbolic container,
   lazy operands included.

   A LAZY join is the case the node cannot express - an Inactive[TensorProduct]
   carrying a lazy operand and no symbolic one is not a container at all, since
   admitting one would make classification evaluate a lazy leaf - so it is
   lowered to a UNARY operation on the lazy operand and goes through the head's
   lazy-preserving rebuild, exactly as ArrayTranspose and ArrayConjugate do: the
   explicit operands are contracted against the value grid of an
   InterpolatingFunction, the branch values of a Piecewise or the body of a
   Function, and the result stays lazy.  That lowering needs exactly ONE lazy
   operand; with several, and with a contraction that leaves no array at all,
   every lazy operand is expanded per scalar and the contraction is explicit -
   the materialize-then-operate fallback every structural op has, taken over the
   whole operand set at once rather than one operand at a time. *)

lazyOperandPosition[arrays_List] := SelectFirst[Range[Length[arrays]], lazyContainerQ[arrays[[#]]] &]

lazyOperandCount[arrays_List] := Count[arrays, _ ? lazyContainerQ]

(* Each contracted level is dropped from the tensor product, so the rank of the
   result is arithmetic on the operand ranks and needs no probe of the node. *)
contractedRank[arrays_List, c_] := Total[Map[ArrayRank, arrays]] - Length[Flatten[c]]

(* Every lazy operand replaced by its per-scalar expansion, which is an explicit
   array of scalar expressions that substitute to the right values. *)
expandedOperands[arrays_List] := Replace[arrays, a_ ? lazyContainerQ :> ArrayMaterialize[a], {1}]

(* An operand with a dimension of 0 empties the whole contraction whatever the
   other operands are.  The short-circuit is taken HERE and not on the generic
   single-array clause at the foot of this section, which a node does not reach:
   guarded on the explicit branch alone, a node mixing a zero-dimension operand
   with a symbolic one comes back an inert TensorContract where every other tier
   gives {}. *)

contractJoin[arrays_, c_] := {} /; AnyTrue[arrays, ZeroArrayQ]

(* A WRAPPER operand contracts its materialized data, which is what the
   single-operand clause at the foot of this section already does and for the
   same reason: TensorContract does not evaluate on a wrapper head.  Handing the
   wrapper straight to the tensor product damages more than the operand itself -
   the whole contraction comes back an inert node which satisfies
   ArrayContainerQ but which ArrayMaterialize cannot resolve either, so an
   all-explicit operand set produces something with no values.

   It has to run BEFORE the lazy clauses below, not after: with a lazy operand
   in the set the rebuild is handed an inner contraction that is not an array,
   declines, and the fallback expands the lazy operand per scalar - so a wrapper
   left wrapped here silently defeats the lazy lowering those clauses document,
   and a node carrying a NumericArray beside a lazy operand dropped out of the
   lazy tier where the same node carrying a SparseArray stayed in it.

   The operands that need it are exactly the explicit ones that are not ArrayQ.
   That is the property TensorContract itself turns on, checked head by head: a
   List, a SparseArray, a QuantityArray and a SymmetrizedArray all contract
   natively, and a NumericArray, a ByteArray, a Dataset and a Tabular do not.
   wrapperExplicitQ is the wrong test here - it does not hold for a NumericArray,
   which is the head that started this - and ArrayComputeNativeQ is wrong the
   other way, since it does not hold for a SymmetrizedArray, whose structure the
   clause at the foot of this section deliberately keeps on the native path.  An
   ArrayObject handle nested in a node is reached by the same test and by no
   UpValue, so it contracts the array it materializes to.

   A DEFERRED TREE operand takes the route too, and must: it is not ArrayQ, so
   TensorContract leaves the outer node inert, and its tier is Lazy with no
   registered head, so the several-lazy clause below matches on the tier, finds
   no lazy container to expand and re-emits the very call it was given - which,
   with the node as the entry point, is itself.  Materializing it here settles
   both, one pass before any tier clause runs. *)

nativelyContractibleQ[a_] := ArrayQ[a] || (! ArrayExplicitQ[a] && ! deferredTreeQ[a])

contractJoin[arrays_, c_] := contractJoin[Replace[arrays, a_ /; ! nativelyContractibleQ[a] :> ArrayMaterialize[a], {1}], c] /;
    ! AllTrue[arrays, nativelyContractibleQ]

(* The tier is read over the CONTAINER operands only.  A node may carry a bare
   scalar factor - a scale is an operand of rank 0 - and arrayTierJoin answers
   Missing["NotAContainer"] for any set holding one, which would steer a node
   mixing a scalar with a lazy operand past both lazy clauses into the explicit
   branch, where TensorContract contracts the inert lazy form as an expression
   tree.  indexOperandTier in IndexExecute.wl reads a tier the same way and for
   the same reason. *)

operandTierJoin[arrays_List] := With[{containers = Select[arrays, ArrayContainerQ]},
    If[containers === {}, "Explicit", arrayTierJoin[containers]]
]

(* EXACTLY ONE lazy operand is the case the rebuild can express: the explicit
   operands are contracted against the value grid of an InterpolatingFunction,
   the branch values of a Piecewise or the body of a Function, and the result
   stays lazy.  The inner call is then an all-explicit contraction, so nothing
   recurses back into this clause.

   The result is NOT lifted back to the joined tier when the head has no rebuild
   and lazyStructuralOp materialized: the only lift available is the constant
   Function of Types.wl, whose parameter is a formal one that no operand
   mentions, so the container it builds is lazy in a VESTIGIAL parameter -
   binding the operand's own parameters then hands back a Function rather than
   the contracted array, and the head decides which of the two a caller gets.
   The materialized result is returned as it stands, which is the same
   collapse-to-explicit that ArrayTranspose and ArrayMap already report for a
   head with no rebuild, and the tier lattice allows: a result may be MORE
   specific than the join. *)

contractJoin[arrays_, c_] := With[{k = lazyOperandPosition[arrays]},
    lazyStructuralOp[contractJoin[ReplacePart[arrays, k -> #], c] &, arrays[[k]]]
] /; operandTierJoin[arrays] === "Lazy" && lazyOperandCount[arrays] === 1 && contractedRank[arrays, c] > 0

(* TWO OR MORE lazy operands have no single rebuild between them, and recursing
   through the rebuilds one operand at a time is a SILENT WRONG ANSWER rather
   than a fallback: the inner call returns a lazy container, every rebuild
   requires an array and declines it, and lazyStructuralOp then contracts the
   inert per-scalar expansion of the outer operand - closures, Indexed forms,
   nested Piecewise - arithmetically, producing a container of the right tier
   and shape whose values are not the contraction of anything.  Every lazy
   operand is expanded per scalar instead, and the ONE contraction that follows
   is over explicit arrays of scalar expressions, which substitute correctly
   (ArrayReplaceAll routes a carried bound form through the registry).  That
   contraction re-enters through the node, on a set whose tier has dropped to
   Explicit, so the recursion is one step deep.

   A contraction that leaves NO array - a full contraction to a scalar - takes
   the same route, for the mirror-image reason: there is no lazy container it
   could be, since every rebuild requires an array.  Left to the explicit branch
   it would be an inactive node carrying a lazy operand, which satisfies no
   classification predicate and which ArrayMaterialize cannot resolve either;
   the per-scalar expansion at least gives a scalar expression that substitutes
   to the right value. *)

contractJoin[arrays_, c_] := ArrayContract[Inactive[TensorProduct] @@ expandedOperands[arrays], c] /;
    operandTierJoin[arrays] === "Lazy"

(* A symbolic operand makes the whole node a symbolic container, and the node it
   already is IS the answer: TensorContract leaves a node carrying a symbol
   inert, and SimplifyArray takes off the wrappers that an empty pair list or a
   one-operand node leaves behind. *)

contractJoin[arrays_, c_] := SimplifyArray[TensorContract[Inactive[TensorProduct] @@ arrays, c]] /;
    operandTierJoin[arrays] === "Symbolic"

(* A ONE-OPERAND node has no product to keep out of, which is the whole reason
   the wrapper is worth carrying, so the operand is contracted bare.  Wrapping
   it costs on both counts the wrapper exists to save.  TensorContract takes an
   inactive product down a generic path where a bare operand takes the
   primitive's own, a thousandfold on a million packed reals - and that is the
   shape every sum and every trace the index layer lowers takes.  On a
   structured atom the wrapped form does more than cost: the generic path drives
   the atom's symmetry through a permutation that is not one and the kernel does
   not come back, for every index pair but the symmetric one, where the bare
   contraction carries the symmetry through and answers.

   The clause sits below the tier clauses and not above them, because the
   one-operand case of a LAZY set is the rebuild and not this: a single lazy
   operand handed straight to TensorContract is contracted as an expression
   tree. *)

contractJoin[arrays_, c_] := deferredActivate[TensorContract[First[arrays], c]] /; Length[arrays] === 1

(* A specification TensorContract cannot act on leaves the contraction standing
   over the node, and the product must not be built to discover that a second
   time: activating it materializes every element of the outer product - 40^4
   elements for a pair of 40x40 operands - to arrive back at the same inert
   contraction.  The slots are therefore read off the SPECIFICATION and not off
   what TensorContract returned, because a standing node also means a hyperedge,
   a group of three or more slots spanning operands, which has no pairwise
   reduction and for which activating the product IS the contraction.

   What makes a specification actionable is what TensorContract's own lvrank and
   lvreps messages report: every slot names a level the operands have, and names
   it once. *)

contractSlotsQ[arrays_, c_] := MatchQ[c, {{__Integer ? Positive} ...}] &&
    DuplicateFreeQ[Flatten[c]] && Max[Flatten[c], 0] <= Total[Map[ArrayRank, arrays]]

contractJoin[arrays_, c_] := TensorContract[Inactive[TensorProduct] @@ arrays, c] /;
    ! contractSlotsQ[arrays, c]

(* The explicit contraction, and the reason the node is the spelling.
   TensorContract has an evaluation rule for an INACTIVE TensorProduct operand:
   it contracts the operands against each other and never builds the product.
   On two rank-3 operands of dimension 14 that is 1MB against 125MB, and on a
   pair of 600x600 SparseArrays it is the difference between a millisecond and
   an outer product of a thousand gigabytes.  The CONTAINERS come from the same
   fact - each pairwise contraction is the operands' own arithmetic, so
   SparseArray against SparseArray gives a SparseArray, packed against packed
   stays packed, exact stays exact, and a QuantityArray carries the product of
   the units - where building the product first flattens all of it.

   What TensorContract hands back is the RESIDUAL product, one factor per
   connected component of the contraction graph, and deferredActivate
   (Accessors.wl) finishes it: a contraction that consumes every slot of one
   operand leaves that operand a rank-0 factor, and TensorProduct[x, 0] is 0
   whatever the rank of x, so the scalars are taken out and multiplied back in
   before the product is activated.  That is the same repair-and-activate pass
   ArrayMaterialize applies to a deferred tree, shared rather than restated so
   that a contraction asked for here and one asked for through the tree cannot
   drift apart.

   Reaching it the other way, through ArrayMaterialize of an inactive
   TensorContract over the node, would not do: that clause is gated on
   deferredTreeQ, which asks every leaf for ArrayExplicitQ, so a node carrying a
   bare scalar factor comes back unevaluated instead of contracted, and the tree
   would be walked twice over. *)

contractJoin[arrays_, c_] := deferredActivate[TensorContract[Inactive[TensorProduct] @@ arrays, c]]

ArrayContract[Inactive[TensorProduct][arrays__], c_] := contractJoin[{arrays}, c]

(* A single lazy container is the one-operand case of the same rule: its tier
   join is its own tier, and TensorContract on an inert lazy form reaches the
   expression TREE rather than the array, so it goes through the rebuild too - or,
   for a full contraction to a scalar, through the per-scalar expansion, which is
   the same route the mixed rank-0 case takes and for the same reason: an inert
   lazy form handed to TensorContract is contracted as an expression tree. *)
ArrayContract[a_ ? lazyContainerQ, c_] := contractJoin[{a}, c]

(* TensorContract does not evaluate on the heads that are not ArrayQ, so they
   contract their materialized data instead of returning an inert wrapper.  This
   is the single-operand form of the rule the node applies to its operands
   above, and it is guarded the same way: wrapperExplicitQ alone missed a
   NumericArray, which contracted to an inert TensorContract that
   ArrayMaterialize could not resolve either, while its sibling operations
   (ArrayConjugate, ArrayMap, PadArray) all handle that head. *)
ArrayContract[a_ ? ArrayExplicitQ, c_] /; ! ArrayQ[a] := ArrayContract[ArrayMaterialize[a], c]

(* THE SINGLE ARRAY, and the refusal of the list that is not one.

   TensorContract preserves SymmetrizedArray structure natively (the contraction
   of a structured atom stays a SymmetrizedArray), so structured arrays
   deliberately stay on this native path.

   One operand set, one spelling: a List of containers is a set given where a
   List already means one array, and it is DECLINED here rather than answered.
   The single-array reading of such a list is a silent wrong answer, not a
   refusal: a list of two SparseArrays is ArrayQ, and reading it as one rank-3
   array gives a clean rank-1 SparseArray holding the values of a question
   nobody asked.

   The refusal is this clause's own business and not a clause of its own, so
   operandSetQ (Classification.wl) is evaluated ONCE per call: a separate
   refusing clause has to decline for the call to come back as written, and a
   declining clause leaves this one to ask the same question over again.  The
   two orderings agree: a List reaches here whatever operandSetQ says of it,
   since ArrayExplicitQ of a List IS ArrayQ, so the wrapper clause above cannot
   take one, and lazyContainerQ walks Head-wards to List and declines.

   The declined call comes back as written, which is the paclet's refusal
   protocol, and the same predicate keeps it from being read as an array: the
   node table in Classification.wl and the contraction shape in Shape.wl both
   ask it, so a refusal is not a container, has no tier and no shape, and no
   accessor re-derives the reading that was withheld. *)

ArrayContract[array_, c_] := With[{set = operandSetQ[array]},
    If[set, Message[ArrayContract::operands, array]];
    If[ZeroArrayQ[array], {}, SimplifyArray[TensorContract[array, c]]] /; ! set
]

(* Normal is the one converter that rewrites a declined call THROUGH the
   refusal: it densifies every operand to a plain List at every level, and the
   densified call is the legitimate single-array spelling, which answers - the
   withheld reading re-derived without a message.  The declined call therefore
   answers Normal itself: it is not an array, so it has no normal form, and it
   comes back as written with its operands still the containers they were.  The
   other converters need no such rule - N maps into a SparseArray without
   unwrapping it, so the operand list still names a set and still declines.
   HoldPattern is the same load-time hygiene as everywhere else in the paclet:
   an assignment evaluates the arguments of its left-hand side, and a bare
   declined call there is an argument-checked call on patterns. *)
ArrayContract /: Normal[declined : HoldPattern[ArrayContract[_ ? operandSetQ, _]], ___] := declined


SimplifyArray[a_] := Replace[a, {
    HoldPattern[IgnoringInactive[ArrayContract[t_, {}]]] :> SimplifyArray[t],
    (* A SINGLETON inactive product is its operand: Inactive carries no
       attributes, so this pattern means one operand there and the wrapper comes
       off.  Mapping instead would descend into the operand, which for a
       container means rebuilding it from its parts - a SparseArray comes back a
       list of sparse rows.  The ACTIVE spelling is the opposite case and needs
       the map: TensorProduct is Flat, so TensorProduct[t_] binds t to the whole
       product and the map is the recursion through its operands. *)
    HoldPattern[Inactive[TensorProduct][t_]] :> SimplifyArray[t],
    HoldPattern[TensorProduct[t_]] :> SimplifyArray /@ t,
    HoldPattern[IgnoringInactive[Transpose[t_, {} | Cycles[{}]]]] :> SimplifyArray[t],
    HoldPattern[IgnoringInactive[TensorContract[t_, c_]]] :> TensorContract[SimplifyArray[t], c]
}]


(* ArrayMap preserves SparseArray structure when mapping at the element level
   ({-1} or {rank}) and densifies otherwise; packed arrays repack best-effort;
   NumericArray and structured arrays convert through Normal; lazy and symbolic
   containers are left unevaluated. *)

elementLevelQ[level_, rank_] := MatchQ[level, {-1} | {rank}]

ArrayMap[f_, a_SparseArray, level_ : {-1}] := If[ elementLevelQ[level, ArrayRank[a]],
    SparseArray[Thread[a["ExplicitPositions"] -> Map[f, a["ExplicitValues"]]], Dimensions[a], f[a["ImplicitValue"]]],
    Map[f, Normal[a], level]
]

(* Repacking after a map uses only the plain, non-coercing form of
   Developer`ToPackedArray, so exact results such as {1/2, 1, 3/2} keep value
   parity with Map instead of being coerced to machine reals. *)
ArrayMap[f_, a_List, level_ : {-1}] := With[{result = Map[f, a, level]},
    If[Developer`PackedArrayQ[a], Developer`ToPackedArray[result], result]
]

(* Wrapper containers map over their materialized data, which for
   QuantityArray means the magnitudes (QuantityMagnitude route, never
   Normal), densifying like the NumericArray precedent below. *)
ArrayMap[f_, a_ ? wrapperExplicitQ, level_ : {-1}] := Map[f, ArrayMaterialize[a], level]

ArrayMap[f_, a_ ? ArrayExplicitQ, level_ : {-1}] := Map[f, Normal[a], level]

(* A lazy container maps at element level through its head's lazy-preserving
   rebuild and stays lazy: the value grid of an InterpolatingFunction is
   remapped and reinterpolated, the branch values of a Piecewise are mapped in
   place, the body of a Function is mapped and re-abstracted.  A head with no
   rebuild at all (ParametricFunction) materializes through ArrayMaterialize and
   maps the explicit array, at any level.  A rebuild that DECLINES - an
   InterpolatingFunction whose remapped grid values stop being numeric is no
   longer an InterpolatingFunction - leaves ArrayMap unevaluated rather than
   silently materializing a container the caller asked to keep lazy. *)

(* Element level is spelled {rank} on both branches, never {-1}: the elements of
   a materialized lazy container are scalar EXPRESSIONS, and {-1} would map f
   over their leaves - the parameter symbols inside an Indexed expansion - not
   over the elements. *)

(* Off element level there is nothing to keep lazy - a map that crosses index
   levels does not commute with any of the rebuilds - so every lazy container
   materializes there, whether or not its head has a rebuild.  Making that
   depend on the presence of a Rebuild key would decide the same call two
   different ways for two heads on the same tier. *)

lazyMapResult[f_, a_, level_] := With[{rank = ArrayRank[a]},
    If[
        lazyRebuildableQ[a] && elementLevelQ[level, rank],
        lazyRebuild[Map[f, #, {rank}] &, a],
        Map[f, ArrayMaterialize[a], Replace[level, {-1} :> {rank}]]
    ]
]

ArrayMap[f_, a_ ? lazyContainerQ, level_ : {-1}] := Module[{result},
    result /; ! MissingQ[result = lazyMapResult[f, a, level]]
]

(* A deferred tree DOES have addressable elements, they are only not computed
   yet, so a map over it is a map over those elements and not an application of
   f to the node.  Applying f to the node would rewrite the contraction
   SPECIFICATION along with the data - N turns the index pair {{2, 3}} into
   {{2., 3.}} and TensorContract then rejects it - and mapping f over the LEAVES
   instead would apply it once per leaf, which nothing but the identity
   survives.  The level is spelled {rank} for the same reason as the lazy tier:
   {-1} would map f over the leaves of scalar EXPRESSIONS rather than over the
   elements. *)
ArrayMap[f_, a_ ? deferredTreeQ, level_ : {-1}] :=
    Map[f, ArrayMaterialize[a], Replace[level, {-1} :> {ArrayRank[a]}]]

(* The leafless symbolic containers have no addressable elements, so an
   element-level map applies f to the whole container: Simplify, ComplexExpand
   and friends distribute over the symbolic tree instead of going silently
   inert. *)
ArrayMap[f_, a_ ? ArraySymbolicQ, level_ : {-1}] := f[a] /; elementLevelQ[level, ArrayRank[a]]


(* ArrayReplaceAll on a lazy container substitutes the WHOLE expression at once:
   substituting all parameters evaluates the array-valued function a single time,
   yielding an explicit (typically packed) array.  The registry decides how, so
   that a Function - whose parameter is BOUND, and which a plain ReplaceAll
   would rewrite into Function[0.5, ...] - is applied instead of rewritten,
   still exactly one whole-array evaluation. *)

ArrayReplaceAll[a_ ? lazyContainerQ, rules_] := lazySubstitute[a, rules]

ArrayReplaceAll[a_SparseArray, rules_] := SparseArray[
    Thread[a["ExplicitPositions"] -> scopedReplaceAll[a["ExplicitValues"], rules]],
    Dimensions[a],
    scopedReplaceAll[a["ImplicitValue"], rules]
]

(* Structured atoms are substitution-opaque: sa /. rules returns a
   SymmetrizedArray whose elements are untouched (ReplaceAll does not
   penetrate the atom), a silent no-op.  Substitution therefore goes
   Normal -> ReplaceAll, densifying. *)
ArrayReplaceAll[a : _SymmetrizedArray | _StructuredArray, rules_] := scopedReplaceAll[Normal[a], rules]

(* Wrapper containers substitute on the materialized data for the same
   reason: rules cannot reach inside the wrapper atoms. *)
ArrayReplaceAll[a_ ? wrapperExplicitQ, rules_] := scopedReplaceAll[ArrayMaterialize[a], rules]

(* Every explicit path goes through scopedReplaceAll rather than ReplaceAll: an
   explicit array can CARRY bound-parameter forms - the per-scalar expansion of a
   Function container is an array of unapplied scalar Functions, and so is a
   single element taken out of one by ArrayPart - and a plain ReplaceAll would
   rewrite their parameter specifications instead of applying them.  An array
   with no Function anywhere in it takes the plain path unchanged. *)
ArrayReplaceAll[a_, rules_] := scopedReplaceAll[a, rules]


(* Conjugate is not natively supported on NumericArray, so it converts through
   Normal and re-wraps; lazy containers funnel through ArrayMaterialize. *)

ArrayConjugate[a_NumericArray] := NumericArray[Conjugate[Normal[a]]]

(* QuantityArray conjugates natively and keeps its wrapper on the generic
   explicit clause; the storage wrappers materialize first. *)
ArrayConjugate[a_ ? opaqueWrapperQ] := Conjugate[ArrayMaterialize[a]]

ArrayConjugate[a_ ? ArrayExplicitQ] := Conjugate[a]

(* Conjugation goes through the same rebuild-or-materialize route as the
   structural ops, so a rebuildable head keeps its laziness instead of being
   flattened into an array of inert Conjugate[Function[...]] elements.
   Conjugating an InterpolatingFunction grid and reinterpolating is exact AT THE
   GRID POINTS, since interpolation is a real-coefficient combination of the grid
   values; between them the rebuild reinterpolates from the values alone, so an
   NDSolve-produced interpolant, whose Hermite derivative data the value grid
   does not carry, is reproduced only to interpolation accuracy. *)
ArrayConjugate[a_ ? lazyContainerQ] := lazyStructuralOp[Conjugate, a]

(* A deferred tree fell through every clause once it left the symbolic tier:
   its head is not registered and ArraySymbolicQ no longer holds, so the call
   came back unevaluated and read downstream as one amplitude.  Conjugate is
   not an admitted structural node, so the honest route is materialization. *)
ArrayConjugate[a_ ? deferredTreeQ] := Conjugate[ArrayMaterialize[a]]

ArrayConjugate[a_ ? ArraySymbolicQ] := Conjugate[a]
