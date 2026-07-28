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

ArrayContract::usage = "ArrayContract[a, pairs] contracts the given index pairs of an array container, keeping symbolic containers in inactive TensorContract form; a lazy container contracts through its head's lazy-preserving rebuild and stays lazy, unless the contraction leaves no array at all.\nArrayContract[{a1, a2, ...}, pairs] contracts index pairs of the inactive tensor product of the given containers; a plain List that is itself an array is treated as a single array, matching the SparseArray form. The result is a container of the tier ArrayUnify joins the operands to: explicit operands contract through the tensor product, an operand set carrying a symbolic container gives a symbolic node, and one carrying exactly one lazy container and no symbolic one is contracted against the value grid, branch values or body of that operand and stays lazy where its head supplies a lazy-preserving rebuild. An operand set carrying SEVERAL lazy containers, and a contraction that leaves no array at all, have no lazy form between them: every lazy operand is expanded per scalar and the contraction is explicit, giving an array - or, for a full contraction, a scalar - of expressions that substitute to the contracted values."

ArrayPart::usage = "ArrayPart[a, {i1, i2, ...}] gives the part of an array container at the given indices, slicing symbolic containers structurally and expanding a lazy container per scalar first, since Part on an inert lazy form reaches the expression tree rather than the array; a deferred structural tree, whose leaves are all explicit, is activated first for the same reason, and a structural tree that carries a symbolic container is left unevaluated rather than sliced wrongly; All entries keep the corresponding level."

SimplifyArray::usage = "SimplifyArray[a] removes trivial structural wrappers such as empty contractions, singleton tensor products and identity transposes from a symbolic array expression."

ArrayName::usage = "ArrayName[a] gives the name of a symbolic array container: the first argument of VectorSymbol, MatrixSymbol or ArraySymbol, an atomic symbol itself, and None otherwise."

ArrayMap::usage = "ArrayMap[f, a] maps f over the deepest elements of an explicit array container, preserving SparseArray structure and repacking packed arrays where the result packs without coercion.\nArrayMap[f, a, level] maps at the given level, densifying a SparseArray when level is not its element level {-1} or {rank}. At element level a lazy container rebuilds and stays lazy where its head supplies a lazy-preserving rebuild; a head with no rebuild, such as a ParametricFunction, and any lazy container mapped off element level materialize through ArrayMaterialize, since a map that crosses index levels commutes with no rebuild. An InterpolatingFunction whose remapped value grid stops being numeric leaves ArrayMap unevaluated. A deferred structural tree, whose leaves are all explicit, is activated and f is mapped over its elements; a leafless symbolic container applies f to the whole container at element level; otherwise ArrayMap is left unevaluated."

ArrayReplaceAll::usage = "ArrayReplaceAll[a, rules] applies rules to an array container: for a lazy container the whole expression is substituted at once, so substituting all parameters evaluates the array-valued function a single time; a Function is the exception in form only, since its parameters are bound rather than free - a rule keyed on every parameter applies the Function, again a single whole-array evaluation, a rule keyed on only some of them curries and gives a Function of the parameters that are still free, and the remaining rules rewrite the free symbols of its body; the same bound-parameter treatment reaches an unapplied Function carried INSIDE an explicit container, such as the per-scalar expansion of a Function container or one element of it, which a plain ReplaceAll would rewrite into Function[0.5, ...]; for a SparseArray the rules map over the explicit values; a structured atom such as SymmetrizedArray or a wrapper container materializes first, since ReplaceAll does not penetrate such atoms; any other container uses ReplaceAll."

ArrayConjugate::usage = "ArrayConjugate[a] conjugates an array container, preserving SparseArray, packed and NumericArray containers, keeping a lazy container lazy where its head supplies a lazy-preserving rebuild and materializing it where it does not, and keeping symbolic containers in unevaluated form."


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
ArrayPart[a_ ? ArrayLazyQ, is : {__}, k_ : 0] := ArrayPart[ArrayMaterialize[a], is, k]

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

ArrayTranspose[a_ ? ArrayLazyQ, perm_] :=
    lazyStructuralOp[Transpose[#, Replace[perm, m_ <-> n_ :> Cycles[{{m, n}}]]] &, a]


(* === the mixing point ===

   A list is treated as a list of arrays only when its elements are containers
   and at least one of them is not itself a List: a plain nested-List matrix is
   a single array and contracts the same way as its SparseArray form, while a
   list of SparseArray, lazy or symbolic containers is a tensor product.  This
   clause comes before the generic one, which would otherwise match first.

   The list is also the one place in the paclet where containers of DIFFERENT
   kinds meet, so it dispatches on the tier join of its operands (arrayTierJoin
   in Types.wl) rather than on whichever operand's form happens to survive
   TensorContract.  Two of the three joins are the inactive tensor product
   already: with every operand explicit the contraction computes through it, and
   with at least one symbolic operand the whole node is a symbolic container,
   lazy operands included.

   A LAZY join is the case the tensor product cannot express - an
   Inactive[TensorProduct] carrying a lazy operand and no symbolic one is not a
   container at all, since admitting one would make classification evaluate a
   lazy leaf - and it used to return that non-container.  It is lowered instead
   to a UNARY operation on the lazy operand and goes through the head's
   lazy-preserving rebuild, exactly as ArrayTranspose and ArrayConjugate do: the
   explicit operands are contracted against the value grid of an
   InterpolatingFunction, the branch values of a Piecewise or the body of a
   Function, and the result stays lazy.  That lowering needs exactly ONE lazy
   operand; with several, and with a contraction that leaves no array at all,
   every lazy operand is expanded per scalar and the contraction is explicit -
   the materialize-then-operate fallback every structural op has, taken over the
   whole operand set at once rather than one operand at a time. *)

lazyOperandPosition[arrays_List] := SelectFirst[Range[Length[arrays]], ArrayLazyQ[arrays[[#]]] &]

lazyOperandCount[arrays_List] := Count[arrays, _ ? ArrayLazyQ]

(* Each contracted level is dropped from the tensor product, so the rank of the
   result is arithmetic on the operand ranks and needs no probe of the node. *)
contractedRank[arrays_List, c_] := Total[Map[ArrayRank, arrays]] - Length[Flatten[c]]

(* Every lazy operand replaced by its per-scalar expansion, which is an explicit
   array of scalar expressions that substitute to the right values. *)
expandedOperands[arrays_List] := Replace[arrays, a_ ? ArrayLazyQ :> ArrayMaterialize[a], {1}]

(* A WRAPPER operand contracts its materialized data, which is what the
   single-operand clause at the foot of this section already does and for the
   same reason: TensorContract does not evaluate on a wrapper head.  The list
   form used to hand the wrapper straight to the tensor product, and the damage
   went past the operand itself - the whole contraction came back an inert node
   which satisfied ArrayContainerQ but which ArrayMaterialize could not resolve
   either, so an all-explicit operand set produced something with no values.

   It has to run BEFORE the lazy clauses below, not after: with a lazy operand
   in the set the rebuild is handed an inner contraction that is not an array,
   declines, and the fallback expands the lazy operand per scalar - so a wrapper
   left wrapped here silently defeats the lazy lowering those clauses document,
   and ArrayContract[{NumericArray[...], lazy}, c] dropped out of the lazy tier
   where the same call with a SparseArray stayed in it.

   The operands that need it are exactly the explicit ones that are not ArrayQ.
   That is the property TensorContract itself turns on, checked head by head: a
   List, a SparseArray, a QuantityArray and a SymmetrizedArray all contract
   natively, and a NumericArray, a ByteArray, a Dataset and a Tabular do not.
   wrapperExplicitQ is the wrong test here - it does not hold for a NumericArray,
   which is the head that started this - and ArrayComputeNativeQ is wrong the
   other way, since it does not hold for a SymmetrizedArray, whose structure the
   clause at the foot of this section deliberately keeps on the native path. *)

nativelyContractibleQ[a_] := ! ArrayExplicitQ[a] || ArrayQ[a]

contractJoin[arrays_, c_] := contractJoin[Replace[arrays, a_ /; ! nativelyContractibleQ[a] :> ArrayMaterialize[a], {1}], c] /;
    ! AllTrue[arrays, nativelyContractibleQ]

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
] /; arrayTierJoin[arrays] === "Lazy" && lazyOperandCount[arrays] === 1 && contractedRank[arrays, c] > 0

(* TWO OR MORE lazy operands have no single rebuild between them, and recursing
   through the rebuilds one operand at a time is a SILENT WRONG ANSWER rather
   than a fallback: the inner call returns a lazy container, every rebuild
   requires an array and declines it, and lazyStructuralOp then contracts the
   inert per-scalar expansion of the outer operand - closures, Indexed forms,
   nested Piecewise - arithmetically, producing a container of the right tier
   and shape whose values are not the contraction of anything.  Every lazy
   operand is expanded per scalar instead, and the ONE contraction that follows
   is over explicit arrays of scalar expressions, which substitute correctly
   (ArrayReplaceAll routes a carried bound form through the registry).

   A contraction that leaves NO array - a full contraction to a scalar - takes
   the same route, for the mirror-image reason: there is no lazy container it
   could be, since every rebuild requires an array.  It used to fall through to
   the tensor-product clause, which for a lazy operand is an inactive node that
   satisfies no classification predicate and that ArrayMaterialize cannot
   resolve either; the per-scalar expansion at least gives a scalar expression
   that substitutes to the right value. *)

contractJoin[arrays_, c_] := ArrayContract[Inactive[TensorProduct] @@ expandedOperands[arrays], c] /;
    arrayTierJoin[arrays] === "Lazy"

contractJoin[arrays_, c_] := ArrayContract[Inactive[TensorProduct] @@ arrays, c]

ArrayContract[arrays : {__ ? ArrayContainerQ}, c_] := contractJoin[arrays, c] /; ! AllTrue[arrays, ListQ]

(* A single lazy container is the one-operand case of the same rule: its tier
   join is its own tier, and TensorContract on an inert lazy form reaches the
   expression TREE rather than the array, so it goes through the rebuild too - or,
   for a full contraction to a scalar, through the per-scalar expansion, which is
   the same route the mixed rank-0 case takes and for the same reason: an inert
   lazy form handed to TensorContract is contracted as an expression tree. *)
ArrayContract[a_ ? ArrayLazyQ, c_] := contractJoin[{a}, c]

(* TensorContract does not evaluate on the heads that are not ArrayQ, so they
   contract their materialized data instead of returning an inert wrapper.  This
   is the single-operand form of the rule the list form applies above, and it is
   guarded the same way: wrapperExplicitQ alone missed a NumericArray, which
   contracted to an inert TensorContract that ArrayMaterialize could not resolve
   either, while its sibling operations (ArrayConjugate, ArrayMap, PadArray) all
   handle that head. *)
ArrayContract[a_ ? ArrayExplicitQ, c_] /; ! ArrayQ[a] := ArrayContract[ArrayMaterialize[a], c]

(* TensorContract preserves SymmetrizedArray structure natively (the
   contraction of a structured atom stays a SymmetrizedArray), so structured
   arrays deliberately stay on this native path. *)
ArrayContract[array_, c_] := If[ZeroArrayQ[array], {}, SimplifyArray[TensorContract[array, c]]]


SimplifyArray[a_] := Replace[a, {
    HoldPattern[IgnoringInactive[ArrayContract[t_, {}]]] :> SimplifyArray[t],
    HoldPattern[IgnoringInactive[TensorProduct[t_]]] :> SimplifyArray /@ t, (* TensorProduct is Flat *)
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

ArrayMap[f_, a_ ? ArrayLazyQ, level_ : {-1}] := Module[{result},
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

ArrayReplaceAll[a_ ? ArrayLazyQ, rules_] := lazySubstitute[a, rules]

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
ArrayConjugate[a_ ? ArrayLazyQ] := lazyStructuralOp[Conjugate, a]

ArrayConjugate[a_ ? ArraySymbolicQ] := Conjugate[a]
