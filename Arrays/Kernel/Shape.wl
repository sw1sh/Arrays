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

(* The element-domain half of the same $Assumptions entry, read by the element
   lattice of Types.wl. *)
PackageScope[assumptionDomain]

(* The column element-type unwrapper, read by the element lattice of Types.wl
   for the same TabularColumn and EventSeries metadata the numericity probes
   below read. *)
PackageScope[columnLeafType]


ArrayDimensions::usage = "ArrayDimensions[a] gives the dimensions of an array container of any tier without materializing it, recursing structurally through Inactive[D], Transpose, Plus, Inactive[TensorProduct], TensorContract, ArrayContract, Dot, ArrayDot and ArrayReshape nodes in both their active and their inactive spelling; a node whose operand has no known shape, and non-array input including ragged lists, quietly give {}."

ArrayRank::usage = "ArrayRank[a] gives the number of dimensions of an array container of any tier without materializing it."

ZeroArrayQ::usage = "ZeroArrayQ[a] gives True if any dimension of a is 0."

ArrayNumericQ::usage = "ArrayNumericQ[a] gives True if all elements of an explicit array container are numeric; for a SparseArray only the explicit values are tested; packed arrays, NumericArrays and GPUArrays are True by construction; lazy and symbolic containers give False."

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

(* The domain of the same entry.  Vectors, Matrices and Arrays default to
   Complexes and normalize the argument in, so an entry registered without a
   domain reads back as Complexes either way; the Optional here covers the
   spelling that has not been normalized. *)
assumptionDomain[s_Symbol] := FirstCase[
    assumptionElements[],
    HoldPattern[Element][
        s | Verbatim[Alternatives][___, s, ___] | {___, s, ___},
        (Vectors | Matrices | Arrays)[_, domain_ : Complexes, ___]
    ] :> domain,
    Missing["NotFound"],
    {1}
]


(* === shape (never materializes) === *)

(* The generic clause is a quiet shape probe: non-array input, including ragged
   lists that make TensorDimensions emit TensorDimensions::rect and return a
   wrong shape, gives {} without leaking messages. *)
ArrayDimensions[t_] := Quiet[Check[Replace[TensorDimensions[t], Except[_List] :> {}], {}]]

(* The two containers that carry the bulk of the traffic answer from Dimensions
   directly, two orders of magnitude cheaper than the message-trapping probe
   above, which pays for Quiet and Check on every call.  A SparseArray is
   rectangular by construction; a list has to earn it, since Dimensions reports
   the depth a ragged list is rectangular to rather than refusing it. *)

ArrayDimensions[a_SparseArray] := Dimensions[a]

ArrayDimensions[a_List] := With[{dims = Dimensions[a]},
    If[Developer`PackedArrayQ[a] || ArrayQ[a, Length[dims]], dims, {}]
]

(* TensorDimensions does not handle NumericArray *)
ArrayDimensions[a_NumericArray] := Dimensions[a]

(* Dimensions on a GPUArray reads the device buffer's shape without copying it
   back to the kernel. *)
ArrayDimensions[a_GPUArray] := If[GPUArrayQ[a], Dimensions[a], {}]

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

(* Lazy containers answer from their registered shape handler.  Every one of
   them would otherwise reach the generic TensorDimensions probe above and
   report the expression tree instead of the array: Dimensions[ifn[t]] is the
   argument count, Dimensions on an unevaluated Piecewise is its argument count
   too, and Dimensions[pf] reports internal expression parts.  This clause is
   the interception point for all of them at once. *)
ArrayDimensions[a_ ? ArrayLazyQ] := lazyDimensions[a]


(* === structural trees ===

   One clause per head of the structuralNodeOperands table in Classification.wl,
   which is what admits these nodes in the first place; the two tiers answer for
   the same vocabulary and Tests/Shape.wlt walks the table asserting they agree
   with Activate on NON-SQUARE operands, where a shape rule that permutes or
   drops the wrong index still shows.  Every node is matched through
   IgnoringInactive, so the active and the inactive spelling of an operation
   report the same shape - the contraction expression of a tensor network
   carries both.

   An operand shape that comes back {} means the operand has no known shape, and
   the index arithmetic here (Delete, Drop, Permute, RotateRight) would then
   either emit a kernel message or hand back an unevaluated non-List expression
   that an enclosing node propagates - both break the documented "quietly gives
   {}" contract.  Every such clause therefore goes through shapeFromOperands,
   which answers {} for an unknown operand and validates the result as a plain
   integer list.  Inactive[TensorProduct] and Plus are the two exceptions and
   handle a rank-0 operand themselves: Catenate is the RIGHT answer for a tensor
   product with a scalar, and the Plus clause drops scalars because Plus threads
   over them. *)

SetAttributes[shapeFromOperands, HoldRest]

shapeFromOperands[operandShapes_List, dims_] := If[
    MemberQ[operandShapes, {}],
    {},
    Quiet[Check[Replace[dims, Except[{___Integer}] :> {}], {}]]
]

ArrayDimensions[Inactive[D][t_, {d_List, n : _Integer ? NonNegative : 1}]] := With[{dims = ArrayDimensions[t]},
    shapeFromOperands[{dims}, Join[dims, ConstantArray[Length[d], n]]]
]

ArrayDimensions[Inactive[D][t_, __]] := ArrayDimensions[t]

(* Transpose reads its permutation in three spellings and takes {2, 1} when it
   is omitted; the shape rule is shared so that the inactive form a lazy
   contraction emits cannot drift from the active one. *)

transposeShape[dims_, perm : _Cycles | _List] := shapeFromOperands[{dims}, Permute[dims, perm]]

transposeShape[dims_, k_Integer] := shapeFromOperands[{dims}, RotateRight[dims, k]]

transposeShape[dims_, m_Integer <-> n_Integer] := shapeFromOperands[{dims}, Permute[dims, Cycles[{{m, n}}]]]

transposeShape[___] := {}

ArrayDimensions[HoldPattern[IgnoringInactive[Transpose[t_]]]] := transposeShape[ArrayDimensions[t], {2, 1}]

ArrayDimensions[HoldPattern[IgnoringInactive[Transpose[t_, perm_]]]] := transposeShape[ArrayDimensions[t], perm]

ArrayDimensions[Inactive[TensorProduct][ts__]] := Catenate[ArrayDimensions /@ {ts}]

(* A rank-0 operand constrains nothing - Plus threads over a scalar - so it is
   DROPPED rather than padded out to a shape of 1s, which would disagree with
   every dimension but 1 and cut the common shape to nothing.  Operands that
   genuinely disagree still give {}: the shape is taken only as far as every
   remaining operand agrees on it. *)
ArrayDimensions[Verbatim[Plus][ts___]] := With[{dims = DeleteCases[ArrayDimensions /@ {ts}, {}]},
    If[ dims === {},
        {},
        With[{n = Max[Length /@ dims]},
            TakeWhile[Thread[PadRight[#, n, 1] & /@ dims], Apply[Equal]][[All, 1]]
        ]
    ]
]

ArrayDimensions[HoldPattern[IgnoringInactive[(ArrayContract | TensorContract)[t_, c : {{___Integer} ...}]]]] := With[{dims = ArrayDimensions[t]},
    shapeFromOperands[{dims}, Delete[dims, List /@ Catenate[c]]]
]

(* The pairwise-contraction lowerings.  Dot contracts the last level of each
   operand with the first of the next, so the shape of a chain is that rule
   folded over the operand shapes. *)

dotShape[dims1_, dims2_] := Join[Drop[dims1, -1], Drop[dims2, 1]]

ArrayDimensions[HoldPattern[IgnoringInactive[Dot[ts__]]]] := With[{dims = ArrayDimensions /@ {ts}},
    shapeFromOperands[dims, Fold[dotShape, dims]]
]

(* ArrayDot takes either a COUNT of trailing levels of x to contract against the
   same number of leading levels of y, or an explicit list of index pairs; both
   spellings occur in a lowered contraction. *)

ArrayDimensions[HoldPattern[IgnoringInactive[ArrayDot[x_, y_, n_Integer]]]] := With[{
    dims = {ArrayDimensions[x], ArrayDimensions[y]}
},
    shapeFromOperands[dims, Join[Drop[First[dims], - n], Drop[Last[dims], n]]]
]

ArrayDimensions[HoldPattern[IgnoringInactive[ArrayDot[x_, y_, pairs : {{_Integer, _Integer} ...}]]]] := With[{
    dims = {ArrayDimensions[x], ArrayDimensions[y]}
},
    shapeFromOperands[
        dims,
        Join[
            Delete[First[dims], List /@ pairs[[All, 1]]],
            Delete[Last[dims], List /@ pairs[[All, 2]]]
        ]
    ]
]

(* ArrayReshape states its result shape outright; that the operand is a
   container is what classification has already settled. *)
ArrayDimensions[HoldPattern[IgnoringInactive[ArrayReshape[t_, dims : {___Integer}, ___]]]] := dims


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

(* A GPUArray holds a numeric device buffer by construction. *)
ArrayNumericQ[a_GPUArray] := GPUArrayQ[a]

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

(* GPU element types are Real and Complex machine formats, never exact. *)
ArrayNumberQ[a_GPUArray] := GPUArrayQ[a] && StringStartsQ[a["ElementType"], "Real" | "Complex"]

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
