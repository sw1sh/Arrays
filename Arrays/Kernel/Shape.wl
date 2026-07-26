Package["Wolfram`Arrays`"]

PackageExport[ArrayDimensions]
PackageExport[ArrayRank]
PackageExport[ZeroArrayQ]
PackageExport[ArrayNumericQ]
PackageExport[ArrayNumberQ]
PackageExport[ArrayAllZeroQ]

PackageScope[squareMatrixQ]
PackageScope[setDimensions]

(* ArraySymbolicQ in Classification.wl decides symbolic-tier membership by
   whether a symbol has registered dimensions, so this probe is shared. *)
PackageScope[assumptionDimensions]


ArrayDimensions::usage = "ArrayDimensions[a] gives the dimensions of an array container of any tier without materializing it, recursing structurally through Inactive[D], Transpose, Plus, Inactive[TensorProduct] and TensorContract forms; non-array input, including ragged lists, quietly gives {}."

ArrayRank::usage = "ArrayRank[a] gives the number of dimensions of an array container of any tier without materializing it."

ZeroArrayQ::usage = "ZeroArrayQ[a] gives True if any dimension of a is 0."

ArrayNumericQ::usage = "ArrayNumericQ[a] gives True if all elements of an explicit array container are numeric; for a SparseArray only the explicit values are tested; packed arrays and NumericArrays are True by construction; lazy and symbolic containers give False."

ArrayNumberQ::usage = "ArrayNumberQ[a] gives True if all elements of an explicit array container are inexact numbers (InexactNumberQ); for a SparseArray only the explicit values are tested; Real and Complex packed arrays and NumericArrays are True by construction, Integer ones give False; lazy and symbolic containers give False."

ArrayAllZeroQ::usage = "ArrayAllZeroQ[a] gives True if every element of an explicit array container is provably zero; lazy and symbolic containers give False."


(* === $Assumptions probes === *)

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


(* === shape (never materializes) === *)

(* The generic clause is a quiet shape probe: non-array input, including ragged
   lists that make TensorDimensions emit TensorDimensions::rect and return a
   wrong shape, gives {} without leaking messages. *)
ArrayDimensions[t_] := Quiet[Check[Replace[TensorDimensions[t], Except[_List] :> {}], {}]]

(* TensorDimensions does not handle NumericArray *)
ArrayDimensions[a_NumericArray] := Dimensions[a]

(* Wrapper containers introspect their shape without materializing. *)

ArrayDimensions[a_QuantityArray] := Dimensions[a]

ArrayDimensions[a_TabularColumn] := Dimensions[a]

ArrayDimensions[a_Tabular] := If[TabularQ[a], Dimensions[a], {}]

ArrayDimensions[a_Dataset] := Dimensions[a]

ArrayDimensions[a_ByteArray] := If[ByteArrayQ[a], Dimensions[a], {}]

(* Dimensions on the "Values" TabularColumn view covers scalar, vector and
   higher-rank valued series uniformly; {PathLength, ValueDimensions} would
   misreport a scalar-valued series as {n, 1}. *)
ArrayDimensions[a_EventSeries] := Dimensions[a["Values"]]

ArrayDimensions[ds_DataStructure] := If[wrapperExplicitQ[ds], {ds["Length"]}, {}]

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


(* === element type probes === *)

(* Column element types are strings such as "Real64", "Integer64",
   "UnsignedInteger8" or "ComplexReal64"; anything else ("String", ...) is
   non-numeric.  Missing entries disqualify a column under the all-elements
   semantics of ArrayNumericQ and ArrayNumberQ. *)

numericColumnTypeQ[type_] := StringQ[type] && StringMatchQ[type, ("Integer" | "UnsignedInteger" | "Real" | "ComplexReal") ~~ DigitCharacter ..]

inexactColumnTypeQ[type_] := StringQ[type] && StringMatchQ[type, ("Real" | "ComplexReal") ~~ DigitCharacter ..]

(* A column of vector-valued entries carries its element type inside one
   TypeSpecifier["ListVector"] wrapper per level, so an EventSeries of vectors
   reports TypeSpecifier["ListVector"]["Real64", 2]; the leaf type settles the
   whole column. *)

columnLeafType[TypeSpecifier["ListVector"][type_, _]] := columnLeafType[type]

columnLeafType[type_] := type

(* A machine element type settles numericity and inexactness for a whole
   column without reading a single element.  The remaining types do NOT settle
   them - "NumberExpression" covers complex, rational and exact values that are
   all numeric, "IntegerExpression" covers big integers - so a column carrying
   one of those falls back to an element scan, and only the untyped case pays
   for a copy. *)

machineColumnQ[a_] := numericColumnTypeQ[columnLeafType[a["ElementType"]]] && a["MissingCount"] == 0

(* Dataset numericity reads off the stored type signature: nested
   TypeSystem`Vector wrappers over numeric TypeSystem`Atom leaves, giving
   shape and numericity in one call without traversing the data. *)

numericDatasetTypeQ[TypeSystem`Vector[t_, _]] := numericDatasetTypeQ[t]

numericDatasetTypeQ[TypeSystem`Atom[Real | Integer | Rational | Complex]] := True

numericDatasetTypeQ[___] := False

inexactDatasetTypeQ[TypeSystem`Vector[t_, _]] := inexactDatasetTypeQ[t]

inexactDatasetTypeQ[TypeSystem`Atom[Real | Complex]] := True

inexactDatasetTypeQ[___] := False


ArrayNumericQ[a_SparseArray] := VectorQ[a["ExplicitValues"], NumericQ]

ArrayNumericQ[_NumericArray] := True

ArrayNumericQ[a_List] := Developer`PackedArrayQ[a] || ArrayQ[a, _, NumericQ]

(* QuantityArray magnitudes are numeric by construction: numeric-with-units. *)
ArrayNumericQ[_QuantityArray] := True

ArrayNumericQ[a_TabularColumn] := numericColumnTypeQ[a["ElementType"]] && a["MissingCount"] == 0

(* TabularStructure is itself a Tabular of per-column metadata: its
   "ColumnType" and "MissingCount" columns decide numericity without
   materializing the data. *)
ArrayNumericQ[a_Tabular] := TabularQ[a] && With[{struct = TabularStructure[a]},
    AllTrue[Normal[struct[[All, "ColumnType"]]], numericColumnTypeQ] &&
        Total[Normal[struct[[All, "MissingCount"]]]] == 0
]

ArrayNumericQ[a_Dataset] := numericDatasetTypeQ[Dataset`GetType[a]]

ArrayNumericQ[a_ByteArray] := ByteArrayQ[a]

(* An EventSeries is bounded only by its path length, so the summary box must
   not copy it twice to fill in two boolean rows: the "Values" column is asked
   for its element type first, and the scan runs only when the type does not
   settle the question. *)
ArrayNumericQ[a_EventSeries] := With[{values = a["Values"]},
    If[machineColumnQ[values], True, ArrayQ[ArrayMaterialize[a], _, NumericQ]]
]

(* DataStructure stores are untyped, so the elements are inspected. *)
ArrayNumericQ[ds_DataStructure] := wrapperExplicitQ[ds] && VectorQ[ds["Elements"], NumericQ]

ArrayNumericQ[a_ ? ArrayExplicitQ] := ArrayQ[a, _, NumericQ]

ArrayNumericQ[___] := False


(* ArrayNumberQ mirrors InexactNumberQ, matching the QuantumFramework "NumberQ"
   state property it replaces: exact (integer or rational) values give False, so
   consumers that branch exact-vs-numeric keep exact input on the exact path. *)

ArrayNumberQ[a_SparseArray] := VectorQ[a["ExplicitValues"], InexactNumberQ]

ArrayNumberQ[a_NumericArray] := StringStartsQ[NumericArrayType[a], "Real" | "Complex"]

ArrayNumberQ[a_List] := Developer`PackedArrayQ[a, Real] || Developer`PackedArrayQ[a, Complex] || ArrayQ[a, _, InexactNumberQ]

(* QuantityArray inexactness is judged on the magnitudes, so integer-magnitude
   arrays stay on the exact path like any other integer container. *)
ArrayNumberQ[a_QuantityArray] := ArrayNumberQ[QuantityMagnitude[a]]

ArrayNumberQ[a_TabularColumn] := inexactColumnTypeQ[a["ElementType"]] && a["MissingCount"] == 0

ArrayNumberQ[a_Tabular] := TabularQ[a] && With[{struct = TabularStructure[a]},
    AllTrue[Normal[struct[[All, "ColumnType"]]], inexactColumnTypeQ] &&
        Total[Normal[struct[[All, "MissingCount"]]]] == 0
]

ArrayNumberQ[a_Dataset] := inexactDatasetTypeQ[Dataset`GetType[a]]

(* ByteArray is integer-typed (unsigned 8-bit), hence never inexact. *)
ArrayNumberQ[_ByteArray] := False

ArrayNumberQ[a_EventSeries] := With[{values = a["Values"]},
    If[
        machineColumnQ[values],
        inexactColumnTypeQ[columnLeafType[values["ElementType"]]],
        ArrayQ[ArrayMaterialize[a], _, InexactNumberQ]
    ]
]

ArrayNumberQ[ds_DataStructure] := wrapperExplicitQ[ds] && VectorQ[ds["Elements"], InexactNumberQ]

ArrayNumberQ[a_ ? ArrayExplicitQ] := ArrayQ[a, _, InexactNumberQ]

ArrayNumberQ[___] := False


ArrayAllZeroQ[a_SparseArray] := TrueQ[a["ImplicitValue"] == 0] && AllTrue[a["ExplicitValues"], TrueQ[# == 0] &]

(* Wrappers test their materialized data; for QuantityArray this makes zero
   magnitudes count as zero, matching the magnitude-based materialization. *)
ArrayAllZeroQ[a_ ? wrapperExplicitQ] := AllTrue[Flatten[ArrayMaterialize[a]], TrueQ[# == 0] &]

ArrayAllZeroQ[a_ ? ArrayExplicitQ] := AllTrue[Flatten[Normal[a]], TrueQ[# == 0] &]

ArrayAllZeroQ[___] := False


(* setDimensions reshapes symbolic containers: symbolic array heads rebuild with new
   dimensions, atomic symbols re-register their $Assumptions entry in place, and
   explicit containers flatten or nest and pad to the requested shape. *)

(* The symbolic array heads are spelled out here for the reason
   assumptionDimensions above spells out (Vectors | Matrices | Arrays): the
   left-hand side of an assignment evaluates, so splicing the symbolicArrayHead
   alias from Classification.wl would freeze into a never-matching pattern
   whenever that file had not loaded first. *)
setDimensions[(VectorSymbol | MatrixSymbol | ArraySymbol)[s_, _, dom_ : Reals, sym_ : {}], dims : {___Integer ? Positive}] := Switch[dims,
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
