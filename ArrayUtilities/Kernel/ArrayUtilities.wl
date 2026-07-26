Package["WolframInstitute`ArrayUtilities`"]

PackageExport[ArrayContainerQ]
PackageExport[ArrayExplicitQ]
PackageExport[ArrayLazyQ]
PackageExport[ArraySymbolicQ]

PackageExport[ArrayDimensions]
PackageExport[ArrayRank]
PackageExport[ZeroArrayQ]
PackageExport[ArrayNumericQ]
PackageExport[ArrayNumberQ]

PackageExport[ArrayExplicitValues]
PackageExport[ArrayExplicitPositions]
PackageExport[ArrayExplicitLength]
PackageExport[ArrayMaterialize]
PackageExport[ArrayPack]

PackageExport[ArrayTranspose]
PackageExport[ArrayContract]
PackageExport[ArrayPart]
PackageExport[SimplifyArray]
PackageExport[ArrayName]
PackageExport[ArrayMap]
PackageExport[ArrayReplaceAll]
PackageExport[ArrayConjugate]
PackageExport[ArrayAllZeroQ]

PackageExport[ArrayVector]
PackageExport[ReshapeArray]
PackageExport[PadArray]

PackageScope[squareMatrixQ]
PackageScope[setDimensions]


(* === usage messages === *)

ArrayContainerQ::usage = "ArrayContainerQ[a] gives True if a is a supported array container of any tier: explicit, lazy parametric, or symbolic."

ArrayExplicitQ::usage = "ArrayExplicitQ[a] gives True if a is an explicit array container: SparseArray, packed or plain List array, NumericArray, or a structured array such as SymmetrizedArray."

ArrayLazyQ::usage = "ArrayLazyQ[a] gives True if a is a lazy parametric array container: an array-valued expression f[args] with at least one non-numeric argument, such as an array-valued InterpolatingFunction applied to a symbolic parameter."

ArraySymbolicQ::usage = "ArraySymbolicQ[a] gives True if a is a symbolic array container: VectorSymbol, MatrixSymbol, ArraySymbol, an atomic symbol registered in $Assumptions as an element of Vectors, Matrices or Arrays, or a structural inactive tree of such containers."

ArrayDimensions::usage = "ArrayDimensions[a] gives the dimensions of an array container of any tier without materializing it, recursing structurally through Inactive[D], Transpose, Plus, Inactive[TensorProduct] and TensorContract forms; non-array input, including ragged lists, quietly gives {}."

ArrayRank::usage = "ArrayRank[a] gives the number of dimensions of an array container of any tier without materializing it."

ZeroArrayQ::usage = "ZeroArrayQ[a] gives True if any dimension of a is 0."

ArrayNumericQ::usage = "ArrayNumericQ[a] gives True if all elements of an explicit array container are numeric; for a SparseArray only the explicit values are tested; packed arrays and NumericArrays are True by construction; lazy and symbolic containers give False."

ArrayNumberQ::usage = "ArrayNumberQ[a] gives True if all elements of an explicit array container are inexact numbers (InexactNumberQ); for a SparseArray only the explicit values are tested; Real and Complex packed arrays and NumericArrays are True by construction, Integer ones give False; lazy and symbolic containers give False."

ArrayExplicitValues::usage = "ArrayExplicitValues[a] gives the explicitly stored values of a SparseArray, or the nonzero values of any other explicit array container via an on-demand SparseArray wrap; lazy and symbolic containers give Missing[\"NotExplicit\"]."

ArrayExplicitPositions::usage = "ArrayExplicitPositions[a] gives the positions of the explicitly stored values of a SparseArray, or the nonzero positions of any other explicit array container via an on-demand SparseArray wrap; lazy and symbolic containers give Missing[\"NotExplicit\"]."

ArrayExplicitLength::usage = "ArrayExplicitLength[a] gives the number of explicitly stored values of a SparseArray, or of nonzero values of any other explicit array container via an on-demand SparseArray wrap; lazy and symbolic containers give Missing[\"NotExplicit\"]."

ArrayMaterialize::usage = "ArrayMaterialize[a] gives an explicit array of scalar expressions for any array container: Normal for explicit containers, per-scalar expansion of an array-valued InterpolatingFunction application for lazy containers, and the input itself for symbolic containers."

ArrayPack::usage = "ArrayPack[a] gives a best-effort packed array conversion of an explicit array container, trying the plain, Real and Complex forms of Developer`ToPackedArray in turn; the coercing forms are accepted only when every value survives at machine precision, and any input that cannot be packed faithfully, including lazy and symbolic containers, is returned unchanged."

ArrayTranspose::usage = "ArrayTranspose[a, perm] transposes an array container by the given permutation, composing permutations of nested Transpose forms, transposing the value grid of a lazy container so it stays lazy, and keeping symbolic containers in unevaluated form."

ArrayContract::usage = "ArrayContract[a, pairs] contracts the given index pairs of an array container, keeping symbolic containers in inactive TensorContract form.\nArrayContract[{a1, a2, ...}, pairs] contracts index pairs of the inactive tensor product of the given containers; a plain List that is itself an array is treated as a single array, matching the SparseArray form."

ArrayPart::usage = "ArrayPart[a, {i1, i2, ...}] gives the part of an array container at the given indices, slicing symbolic containers structurally; All entries keep the corresponding level."

SimplifyArray::usage = "SimplifyArray[a] removes trivial structural wrappers such as empty contractions, singleton tensor products and identity transposes from a symbolic array expression."

ArrayName::usage = "ArrayName[a] gives the name of a symbolic array container: the first argument of VectorSymbol, MatrixSymbol or ArraySymbol, an atomic symbol itself, and None otherwise."

ArrayMap::usage = "ArrayMap[f, a] maps f over the deepest elements of an explicit array container, preserving SparseArray structure and repacking packed arrays where the result packs without coercion.\nArrayMap[f, a, level] maps at the given level, densifying a SparseArray when level is not its element level {-1} or {rank}. At element level a lazy container remaps its value grid and stays lazy when f keeps the values numeric, and a symbolic container applies f to the whole container; otherwise ArrayMap is left unevaluated."

ArrayReplaceAll::usage = "ArrayReplaceAll[a, rules] applies rules to an array container: for a lazy container the whole expression is substituted at once, so substituting all parameters evaluates the array-valued function a single time; for a SparseArray the rules map over the explicit values; any other container uses ReplaceAll."

ArrayConjugate::usage = "ArrayConjugate[a] conjugates an array container, preserving SparseArray, packed and NumericArray containers, materializing lazy containers, and keeping symbolic containers in unevaluated form."

ArrayAllZeroQ::usage = "ArrayAllZeroQ[a] gives True if every element of an explicit array container is provably zero; lazy and symbolic containers give False."

ArrayVector::usage = "ArrayVector[a] flattens an explicit array container to a vector, using a raw CSR construction for a SparseArray of rank above 11; a lazy container flattens its value grid and stays lazy; scalar numeric input passes through unchanged."

ReshapeArray::usage = "ReshapeArray[a, dims] reshapes an explicit array container to the given dimensions, preserving the container where ArrayReshape does; a lazy container reshapes its value grid and stays lazy.\nReshapeArray[a, dims, pad] pads with pad when the reshape needs more elements."

PadArray::usage = "PadArray[a, spec] pads an explicit array container with zeros according to spec, preserving the container where ArrayPad does; a NumericArray converts through Normal and re-wraps.\nPadArray[a, spec, padding] pads with the given padding."


(* === classification === *)

(* Explicit tier: SparseArray, packed and plain List arrays, and structured
   arrays (SymmetrizedArray etc.) all satisfy ArrayQ without materializing;
   NumericArray does not satisfy ArrayQ and gets its own clause. *)

ArrayExplicitQ[_NumericArray] := True

ArrayExplicitQ[a_] := ArrayQ[a]

ArrayExplicitQ[___] := False


(* Lazy tier: an array-valued expression f[args] with at least one non-numeric argument.
   Supported heads are extensible: add one ArrayLazyQ clause (and an ArrayDimensions
   clause) per new head, before the False fall-through. *)

ArrayLazyQ[(f_InterpolatingFunction)[args__]] := f["OutputDimensions"] =!= {} && ! AllTrue[{args}, NumericQ]

ArrayLazyQ[___] := False


(* Symbolic tier: VectorSymbol | MatrixSymbol | ArraySymbol, atomic symbols registered
   in $Assumptions, and structural trees over such containers. *)

symbolicArrayHead = VectorSymbol | MatrixSymbol | ArraySymbol

arrayDomainHead = Vectors | Matrices | Arrays

(* $Assumptions can arrive as a list, a single expression, or an And conjunction
   (the form Assuming and Refine produce); And is Flat, so splicing one level of
   And suffices.  A single Element entry can register several symbols at once
   through Alternatives or a symbol list. *)
assumptionElements[] := Catenate[
    Replace[Developer`ToList[$Assumptions], {HoldPattern[And][as___] :> {as}, a_ :> {a}}, {1}]
]

(* FirstCase holds its rule, so the domain heads are spelled out rather than
   going through the arrayDomainHead alias, which would stay unevaluated. *)
assumptionDimensions[s_Symbol] := FirstCase[
    assumptionElements[],
    HoldPattern[Element][
        s | Verbatim[Alternatives][___, s, ___] | {___, s, ___},
        (Vectors | Matrices | Arrays)[dims_, ___]
    ] :> dims,
    Missing["NotFound"],
    {1}
]

ArraySymbolicQ[symbolicArrayHead[__]] := True

ArraySymbolicQ[s_Symbol] := ! MissingQ[assumptionDimensions[s]]

ArraySymbolicQ[Inactive[D][t_, __]] := ArraySymbolicQ[t]

ArraySymbolicQ[(Verbatim[Transpose] | Inactive[Transpose])[t_, ___]] := ArraySymbolicQ[t]

ArraySymbolicQ[Inactive[TensorProduct][ts__]] := AnyTrue[{ts}, ArraySymbolicQ]

ArraySymbolicQ[Verbatim[Plus][ts__]] := AnyTrue[{ts}, ArraySymbolicQ]

ArraySymbolicQ[HoldPattern[IgnoringInactive[(ArrayContract | TensorContract)[t_, _]]]] := ArraySymbolicQ[t]

ArraySymbolicQ[___] := False


ArrayContainerQ[a_] := ArrayExplicitQ[a] || ArrayLazyQ[a] || ArraySymbolicQ[a]

ArrayContainerQ[___] := False


(* === shape (never materializes) === *)

(* The generic clause is a quiet shape probe: non-array input, including ragged
   lists that make TensorDimensions emit TensorDimensions::rect and return a
   wrong shape, gives {} without leaking messages. *)
ArrayDimensions[t_] := Quiet[Check[Replace[TensorDimensions[t], Except[_List] :> {}], {}]]

(* TensorDimensions does not handle NumericArray *)
ArrayDimensions[a_NumericArray] := Dimensions[a]

ArrayDimensions[(f_InterpolatingFunction)[__]] := Replace[f["OutputDimensions"], Except[_List] :> {}]

ArrayDimensions[Inactive[D][t_, {d_List, n : _Integer ? NonNegative : 1}]] := Join[ArrayDimensions[t], ConstantArray[Length[d], n]]

ArrayDimensions[Inactive[D][t_, __]] := ArrayDimensions[t]

ArrayDimensions[Verbatim[Transpose][t_, perm : _Cycles | _List : {2, 1}]] := Permute[ArrayDimensions[t], perm]

ArrayDimensions[Verbatim[Transpose][t_, k_Integer]] := RotateRight[ArrayDimensions[t], k]

ArrayDimensions[Verbatim[Transpose][t_, m_Integer <-> n_Integer]] := Permute[ArrayDimensions[t], Cycles[{{m, n}}]]

ArrayDimensions[Inactive[TensorProduct][ts__]] := Catenate[ArrayDimensions /@ {ts}]

ArrayDimensions[Verbatim[Plus][ts___]] := With[{dims = ArrayDimensions /@ {ts}}, {n = Max[Length /@ dims]},
    TakeWhile[Thread[PadRight[#, n, 1] & /@ dims], Apply[Equal]][[All, 1]]
]

ArrayDimensions[IgnoringInactive[(ArrayContract | TensorContract)[t_, c : {{___Integer} ...}]]] := Delete[ArrayDimensions[t], List /@ Catenate[c]]


ArrayRank[t_] := Length[ArrayDimensions[t]]


ZeroArrayQ[t_] := MemberQ[ArrayDimensions[t], 0]

ZeroArrayQ[___] := False


squareMatrixQ[t_] := MatchQ[ArrayDimensions[t], {n_, n_} | {_, 0}]


ArrayNumericQ[a_SparseArray] := VectorQ[a["ExplicitValues"], NumericQ]

ArrayNumericQ[_NumericArray] := True

ArrayNumericQ[a_List] := Developer`PackedArrayQ[a] || ArrayQ[a, _, NumericQ]

ArrayNumericQ[a_ ? ArrayExplicitQ] := ArrayQ[a, _, NumericQ]

ArrayNumericQ[___] := False


(* ArrayNumberQ mirrors InexactNumberQ, matching the QuantumFramework "NumberQ"
   state property it replaces: exact (integer or rational) values give False, so
   consumers that branch exact-vs-numeric keep exact input on the exact path. *)

ArrayNumberQ[a_SparseArray] := VectorQ[a["ExplicitValues"], InexactNumberQ]

ArrayNumberQ[a_NumericArray] := StringStartsQ[NumericArrayType[a], "Real" | "Complex"]

ArrayNumberQ[a_List] := Developer`PackedArrayQ[a, Real] || Developer`PackedArrayQ[a, Complex] || ArrayQ[a, _, InexactNumberQ]

ArrayNumberQ[a_ ? ArrayExplicitQ] := ArrayQ[a, _, InexactNumberQ]

ArrayNumberQ[___] := False


(* === accessors === *)

(* On-demand SparseArray wrap for dense explicit containers; SparseArray cannot
   ingest a NumericArray or an array with a zero dimension directly. *)

toSparseArray[a_SparseArray] := a

toSparseArray[a_NumericArray] := SparseArray[Normal[a]]

toSparseArray[a_] := SparseArray[a]


ArrayExplicitValues[a_SparseArray] := a["ExplicitValues"]

ArrayExplicitValues[a_ ? ArrayExplicitQ] := If[ZeroArrayQ[a], {}, toSparseArray[a]["ExplicitValues"]]

ArrayExplicitValues[a_ ? ArrayLazyQ] := Missing["NotExplicit"]

ArrayExplicitValues[a_ ? ArraySymbolicQ] := Missing["NotExplicit"]


ArrayExplicitPositions[a_SparseArray] := a["ExplicitPositions"]

ArrayExplicitPositions[a_ ? ArrayExplicitQ] := If[ZeroArrayQ[a], {}, toSparseArray[a]["ExplicitPositions"]]

ArrayExplicitPositions[a_ ? ArrayLazyQ] := Missing["NotExplicit"]

ArrayExplicitPositions[a_ ? ArraySymbolicQ] := Missing["NotExplicit"]


ArrayExplicitLength[a_SparseArray] := a["ExplicitLength"]

ArrayExplicitLength[a_ ? ArrayExplicitQ] := If[ZeroArrayQ[a], 0, toSparseArray[a]["ExplicitLength"]]

ArrayExplicitLength[a_ ? ArrayLazyQ] := Missing["NotExplicit"]

ArrayExplicitLength[a_ ? ArraySymbolicQ] := Missing["NotExplicit"]


(* Per-scalar expansion of a single-parameter array-valued InterpolatingFunction
   application, ported from the QuantumFramework ExpandInterpolatingFunction. *)

expandInterpolatingFunction[f_InterpolatingFunction, parameter_] := Map[
    Interpolation[Thread[{f["Grid"], #}], InterpolationOrder -> f["InterpolationOrder"]][parameter] &,
    Transpose[f["ValuesOnGrid"], InversePermutation[Cycles[{Range[Length[f["OutputDimensions"]] + 1]}]]],
    {-2}
]


(* Structural rebuild of a single-parameter array-valued InterpolatingFunction:
   the value array at every grid point is transformed by g and reinterpolated,
   keeping the container lazy for flatten, reshape, transpose and map. *)

reinterpolate[g_, f_InterpolatingFunction] := Interpolation[
    Thread[{f["Grid"], g /@ f["ValuesOnGrid"]}],
    InterpolationOrder -> f["InterpolationOrder"]
]


ArrayMaterialize[a_ ? ArrayExplicitQ] := Normal[a]

ArrayMaterialize[expr : (f_InterpolatingFunction)[parameter_]] := expandInterpolatingFunction[f, parameter] /; ArrayLazyQ[expr]

ArrayMaterialize[a_ ? ArraySymbolicQ] := a


(* Best-effort packing: the plain form first, then the Real and Complex coercing
   forms, which pack the mixed Integer/Real and Integer/Complex lists that
   Normal of a numeric SparseArray can produce.  A coerced packing is accepted
   only when every value survives at machine precision (SetPrecision round-trip),
   so exact values such as 1/3 or 2^200 + 1 are never silently destroyed. *)

faithfulPackQ[packed_, a_] := Developer`PackedArrayQ[packed] && SetPrecision[packed, Infinity] == a

packList[a_List] := With[{packed = Developer`ToPackedArray[a]},
    If[ Developer`PackedArrayQ[packed],
        packed,
        SelectFirst[
            {
                Developer`ToPackedArray[a, Real],
                Developer`ToPackedArray[a, Complex]
            },
            faithfulPackQ[#, a] &,
            a
        ]
    ]
]

ArrayPack[a_List] := packList[a]

ArrayPack[a_] := If[ ArrayExplicitQ[a],
    With[{packed = packList[Normal[a]]},
        If[Developer`PackedArrayQ[packed], packed, a]
    ],

    a
]


(* === structural operations === *)

ArrayName[t_Symbol ? AtomQ] := t

ArrayName[symbolicArrayHead[s_, ___]] := s

ArrayName[___] := None


(* setDimensions reshapes symbolic containers: symbolic array heads rebuild with new
   dimensions, atomic symbols re-register their $Assumptions entry in place, and
   explicit containers flatten or nest and pad to the requested shape. *)

setDimensions[symbolicArrayHead[s_, _, dom_ : Reals, sym_ : {}], dims : {___Integer ? Positive}] := Switch[dims,
    {_}, VectorSymbol[s, dims, dom],
    {_, _}, MatrixSymbol[s, dims, dom, sym],
    _, ArraySymbol[s, dims, dom, sym]
]

setDimensions[s_Symbol ? AtomQ, dims : {___Integer ? Positive}, defDom_ : Reals, defSym_ : {}] := Block[{
    pos, entry, rest, domSym,
    newElement = With[{head = Switch[dims, {_}, Vectors, {_, _}, Matrices, _, Arrays]},
        If[head === Vectors, Element[s, head[dims, #]] &, Element[s, head[dims, ##]] &]
    ]
},
    $Assumptions = assumptionElements[];
    pos = FirstPosition[
        $Assumptions,
        HoldPattern[Element][s | Verbatim[Alternatives][___, s, ___] | {___, s, ___}, _],
        Missing[],
        {1},
        Heads -> False
    ];
    If[ MissingQ[pos],
        $Assumptions = Append[$Assumptions, newElement[defDom, defSym]],

        entry = Extract[$Assumptions, pos];
        domSym = Replace[
            entry,
            {Element[_, arrayDomainHead[_, dom_ : defDom, sym_ : defSym]] :> {dom, sym}, _ :> {defDom, defSym}}
        ];
        (* A multi-symbol Element keeps its other symbols registered; the entry for s
           is re-registered separately with the new dimensions. *)
        rest = Replace[
            entry,
            {
                HoldPattern[Element][Verbatim[Alternatives][a___, s, b___], domain_] /; {a, b} =!= {} :>
                    {Element[Replace[Alternatives[a, b], Verbatim[Alternatives][x_] :> x], domain]},
                HoldPattern[Element][{a___, s, b___}, domain_] /; {a, b} =!= {} :>
                    {Element[Replace[{a, b}, {x_} :> x], domain]},
                _ :> {}
            }
        ];
        $Assumptions = Append[Join[Delete[$Assumptions, pos], rest], newElement @@ domSym]
    ];
    s
]

setDimensions[t_, dims : {___, 0, ___}] := ArrayReshape[{}, Append[DeleteCases[dims, 0], 0]]

setDimensions[t_, dims : {___Integer ? Positive}, pad_ : 0] := With[{
    s = Replace[
        ArrayDepth[t] - Length[dims],
        {
            0 :> t,
            p_Integer ? Positive :> Flatten[t, p],
            n_Integer :> Nest[List, t, - n]
        }
    ]
},
    If[dims === {}, s, PadRight[s, dims, pad]]
]


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

ArrayReplaceAll[a_, rules_] := ReplaceAll[a, rules]


(* Conjugate is not natively supported on NumericArray, so it converts through
   Normal and re-wraps; lazy containers funnel through ArrayMaterialize. *)

ArrayConjugate[a_NumericArray] := NumericArray[Conjugate[Normal[a]]]

ArrayConjugate[a_ ? ArrayExplicitQ] := Conjugate[a]

ArrayConjugate[a_ ? ArrayLazyQ] := Conjugate[ArrayMaterialize[a]]

ArrayConjugate[a_ ? ArraySymbolicQ] := Conjugate[a]


ArrayAllZeroQ[a_SparseArray] := TrueQ[a["ImplicitValue"] == 0] && AllTrue[a["ExplicitValues"], TrueQ[# == 0] &]

ArrayAllZeroQ[a_ ? ArrayExplicitQ] := AllTrue[Flatten[Normal[a]], TrueQ[# == 0] &]

ArrayAllZeroQ[___] := False


(* === flatten to vector === *)

(* ArrayVector subsumes the QuantumFramework SparseArrayFlatten helper: raw CSR
   construction for a SparseArray of rank above 11 (Flatten degrades there),
   scalar passthrough, generic Flatten for the explicit tier. The name follows
   the Array* scheme without colliding with System`ArrayFlatten. *)

ArrayVector[sa_SparseArray] := With[{dims = sa["Dimensions"]},
    With[{
        (* if all dimensions are equal don't fold *)
        cs = If[Equal @@ dims, dims ^ Range[Length[dims] - 1, 0, -1], Reverse @ FoldList[Times, 1, dims[[-1 ;; 2 ;; -1]]]],
        ps = Catenate @ MapThread[ConstantArray, {Range[0, dims[[1]] - 1], Differences @ sa["RowPointers"]}]
    },
        SparseArray[
            Automatic,
            {Times @@ dims},
            sa["ImplicitValue"],
            {
                1,
                {
                    {0, sa["ExplicitLength"]},
                    List /@ (1 + First[cs] * ps + Total[Thread[Rest[cs] #] & /@ (sa["ColumnIndices"] - 1), {2}])
                },
                sa["ExplicitValues"]
            }
        ]
    ] /; Length[dims] > 11
]

ArrayVector[x_ ? NumericQ] := x

ArrayVector[a_ ? ArrayExplicitQ] := Flatten[a]

ArrayVector[expr : (f_InterpolatingFunction)[parameter_]] :=
    If[ArrayRank[expr] == 1, expr, reinterpolate[Flatten, f][parameter]] /; ArrayLazyQ[expr]


(* === reshape and pad (non-colliding System equivalents) === *)

ReshapeArray[a_ ? ArrayExplicitQ, dims : {___Integer ? NonNegative}] := ArrayReshape[a, dims]

ReshapeArray[a_ ? ArrayExplicitQ, dims : {___Integer ? NonNegative}, pad_] := ArrayReshape[a, dims, pad]

ReshapeArray[expr : (f_InterpolatingFunction)[parameter_], dims : {___Integer ? NonNegative}] :=
    reinterpolate[ArrayReshape[#, dims] &, f][parameter] /; ArrayLazyQ[expr]

ReshapeArray[expr : (f_InterpolatingFunction)[parameter_], dims : {___Integer ? NonNegative}, pad_] :=
    reinterpolate[ArrayReshape[#, dims, pad] &, f][parameter] /; ArrayLazyQ[expr]


(* ArrayPad does not support NumericArray, so it converts through Normal and
   re-wraps, mirroring the ArrayConjugate NumericArray clause. *)

PadArray[a_NumericArray, spec_] := NumericArray[ArrayPad[Normal[a], spec]]

PadArray[a_NumericArray, spec_, padding_] := NumericArray[ArrayPad[Normal[a], spec, padding]]

PadArray[a_ ? ArrayExplicitQ, spec_] := ArrayPad[a, spec]

PadArray[a_ ? ArrayExplicitQ, spec_, padding_] := ArrayPad[a, spec, padding]
