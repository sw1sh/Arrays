Package["Wolfram`Arrays`"]

PackageExport[ArrayTranspose]
PackageExport[ArrayContract]
PackageExport[ArrayPart]
PackageExport[SimplifyArray]
PackageExport[ArrayName]
PackageExport[ArrayMap]
PackageExport[ArrayReplaceAll]
PackageExport[ArrayConjugate]

(* Vector.wl rebuilds lazy containers the same way for Flatten and reshape. *)
PackageScope[reinterpolate]


ArrayTranspose::usage = "ArrayTranspose[a, perm] transposes an array container by the given permutation, composing permutations of nested Transpose forms, transposing the value grid of a lazy container so it stays lazy, and keeping symbolic containers in unevaluated form."

ArrayContract::usage = "ArrayContract[a, pairs] contracts the given index pairs of an array container, keeping symbolic containers in inactive TensorContract form.\nArrayContract[{a1, a2, ...}, pairs] contracts index pairs of the inactive tensor product of the given containers; a plain List that is itself an array is treated as a single array, matching the SparseArray form."

ArrayPart::usage = "ArrayPart[a, {i1, i2, ...}] gives the part of an array container at the given indices, slicing symbolic containers structurally; All entries keep the corresponding level."

SimplifyArray::usage = "SimplifyArray[a] removes trivial structural wrappers such as empty contractions, singleton tensor products and identity transposes from a symbolic array expression."

ArrayName::usage = "ArrayName[a] gives the name of a symbolic array container: the first argument of VectorSymbol, MatrixSymbol or ArraySymbol, an atomic symbol itself, and None otherwise."

ArrayMap::usage = "ArrayMap[f, a] maps f over the deepest elements of an explicit array container, preserving SparseArray structure and repacking packed arrays where the result packs without coercion.\nArrayMap[f, a, level] maps at the given level, densifying a SparseArray when level is not its element level {-1} or {rank}. At element level a lazy container remaps its value grid and stays lazy when f keeps the values numeric, and a symbolic container applies f to the whole container; otherwise ArrayMap is left unevaluated."

ArrayReplaceAll::usage = "ArrayReplaceAll[a, rules] applies rules to an array container: for a lazy container the whole expression is substituted at once, so substituting all parameters evaluates the array-valued function a single time; for a SparseArray the rules map over the explicit values; a structured atom such as SymmetrizedArray or a wrapper container materializes first, since ReplaceAll does not penetrate such atoms; any other container uses ReplaceAll."

ArrayConjugate::usage = "ArrayConjugate[a] conjugates an array container, preserving SparseArray, packed and NumericArray containers, materializing lazy containers, and keeping symbolic containers in unevaluated form."


(* Structural rebuild of a single-parameter array-valued InterpolatingFunction:
   the value array at every grid point is transformed by g and reinterpolated,
   keeping the container lazy for flatten, reshape, transpose and map. *)

reinterpolate[g_, f_InterpolatingFunction] := Interpolation[
    Thread[{f["Grid"], g /@ f["ValuesOnGrid"]}],
    InterpolationOrder -> f["InterpolationOrder"]
]


ArrayName[t_Symbol ? AtomQ] := t

(* The symbolic array heads are spelled out rather than spliced from the
   symbolicArrayHead alias in Classification.wl: an assignment evaluates its
   left-hand side, so an alias there would silently freeze into a pattern that
   can never match if this file ever loaded first. *)
ArrayName[(VectorSymbol | MatrixSymbol | ArraySymbol)[s_, ___]] := s

ArrayName[___] := None


(* setDimensions lives in Shape.wl: re-registering an atomic symbol is a shape
   operation on its $Assumptions entry. *)

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
]

ArrayPart[t_, {}, ___] := t


(* QuantityArray transposes natively and keeps its wrapper on the generic
   clause; the remaining wrappers have no native Transpose and materialize. *)
ArrayTranspose[t_ ? opaqueWrapperQ, perm_] := ArrayTranspose[ArrayMaterialize[t], perm]

ArrayTranspose[t_, perm_] := If[ZeroArrayQ[t], {}, SimplifyArray @ Transpose[t, Replace[perm, m_ <-> n_ :> Cycles[{{m, n}}]]]]

ArrayTranspose[(Verbatim[Transpose] | Inactive[Transpose])[t_, perm1_], perm2_] := ArrayTranspose[t, PermutationList[PermutationProduct[perm1, perm2]]]

ArrayTranspose[expr : (f_InterpolatingFunction)[parameter_], perm_] :=
    reinterpolate[Transpose[#, Replace[perm, m_ <-> n_ :> Cycles[{{m, n}}]]] &, f][parameter] /; ArrayLazyQ[expr]


(* A list is treated as a list of arrays only when its elements are containers
   and at least one of them is not itself a List: a plain nested-List matrix is
   a single array and contracts the same way as its SparseArray form, while a
   list of SparseArray, lazy or symbolic containers is a tensor product.  This
   clause comes before the generic one, which would otherwise match first. *)
ArrayContract[arrays : {__ ? ArrayContainerQ}, c_] := ArrayContract[Inactive[TensorProduct] @@ arrays, c] /; ! AllTrue[arrays, ListQ]

(* TensorContract does not evaluate on the wrapper heads, so they contract
   their materialized data instead of returning an inert wrapper. *)
ArrayContract[a_ ? wrapperExplicitQ, c_] := ArrayContract[ArrayMaterialize[a], c]

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

(* A lazy container maps element-wise over the value grid and reinterpolates,
   staying lazy, when f keeps the grid values numeric (Chop, N, Abs, ...);
   otherwise ArrayMap stays unevaluated. *)
ArrayMap[f_, expr : (g_InterpolatingFunction)[parameter_], level_ : {-1}] := Module[{values},
    Interpolation[
        Thread[{g["Grid"], values}],
        InterpolationOrder -> g["InterpolationOrder"]
    ][parameter] /; ArrayLazyQ[expr] && elementLevelQ[level, ArrayRank[expr]] &&
        ArrayQ[values = Map[f, g["ValuesOnGrid"], {-1}], _, NumericQ]
]

(* Symbolic containers have no addressable elements, so an element-level map
   applies f to the whole container: Simplify, ComplexExpand and friends
   distribute over the symbolic tree instead of going silently inert. *)
ArrayMap[f_, a_ ? ArraySymbolicQ, level_ : {-1}] := f[a] /; elementLevelQ[level, ArrayRank[a]]


(* ArrayReplaceAll on a lazy container substitutes the WHOLE expression at once:
   substituting all parameters evaluates the array-valued function a single time,
   yielding an explicit (typically packed) array. *)

ArrayReplaceAll[a_ ? ArrayLazyQ, rules_] := a /. rules

ArrayReplaceAll[a_SparseArray, rules_] := SparseArray[
    Thread[a["ExplicitPositions"] -> (a["ExplicitValues"] /. rules)],
    Dimensions[a],
    a["ImplicitValue"] /. rules
]

(* Structured atoms are substitution-opaque: sa /. rules returns a
   SymmetrizedArray whose elements are untouched (ReplaceAll does not
   penetrate the atom), a silent no-op.  Substitution therefore goes
   Normal -> ReplaceAll, densifying. *)
ArrayReplaceAll[a : _SymmetrizedArray | _StructuredArray, rules_] := ReplaceAll[Normal[a], rules]

(* Wrapper containers substitute on the materialized data for the same
   reason: rules cannot reach inside the wrapper atoms. *)
ArrayReplaceAll[a_ ? wrapperExplicitQ, rules_] := ReplaceAll[ArrayMaterialize[a], rules]

ArrayReplaceAll[a_, rules_] := ReplaceAll[a, rules]


(* Conjugate is not natively supported on NumericArray, so it converts through
   Normal and re-wraps; lazy containers funnel through ArrayMaterialize. *)

ArrayConjugate[a_NumericArray] := NumericArray[Conjugate[Normal[a]]]

(* QuantityArray conjugates natively and keeps its wrapper on the generic
   explicit clause; the storage wrappers materialize first. *)
ArrayConjugate[a_ ? opaqueWrapperQ] := Conjugate[ArrayMaterialize[a]]

ArrayConjugate[a_ ? ArrayExplicitQ] := Conjugate[a]

ArrayConjugate[a_ ? ArrayLazyQ] := Conjugate[ArrayMaterialize[a]]

ArrayConjugate[a_ ? ArraySymbolicQ] := Conjugate[a]
