Package["Wolfram`Arrays`"]

PackageExport[ArrayObject]
PackageExport[ArrayObjectQ]

PackageScope[unwrapArrayObjects]


(* ArrayObject is a completeness feature: a uniform, self-describing handle
   around any supported container, whose summary box says at a glance what kind
   of container it is and what shape it has.  It is a thin veneer: no other
   kernel file mentions ArrayObject, every other function keeps operating on RAW
   containers, and the handle is unwrapped to one - by obj["Data"], or by the
   unwrapping UpValues below - before any of them sees it.

   Nothing here is spliced into a definition left-hand side, so this file has no
   load-order dependency on any other. *)


ArrayObject::usage = "ArrayObject[a] gives a self-describing handle around the array container a, formatted as a summary box that shows its container kind and dimensions; ArrayObject[a][\"prop\"] gives a property and ArrayObject[a][\"Properties\"] the list of supported properties. Input that is not an array container stays unevaluated."

ArrayObjectQ::usage = "ArrayObjectQ[obj] gives True if obj is an ArrayObject wrapping a supported array container."


ArrayObject::nocontainer = "`1` is not a supported array container; ArrayObject accepts any expression satisfying ArrayContainerQ."

ArrayObject::noprop = "`1` is not a supported ArrayObject property; use \"Properties\" for the list of supported properties."

ArrayObject::argx = "ArrayObject called with `1` arguments; 1 argument is expected."

ArrayObject::propx = "ArrayObject property lookup called with `1` arguments; 1 property name is expected."


(* === construction === *)

(* The object IS the wrapper expression, so the head carries no constructor,
   only a rejection guard.  The guard's condition ends in False either way: for
   a container it short-circuits at ! ArrayContainerQ and the expression is left
   alone, and for anything else it emits the message and then declines, so
   unsupported input stays unevaluated instead of yielding a half-formed object.

   The cost of this design is that ArrayContainerQ runs on every evaluation of
   the object rather than once at construction; every tier predicate answers
   from shape alone and never materializes, so this is bounded by ArrayQ on a
   plain nested List - O(n) in the element count, and paid again on every
   property read and every render.  The one head whose SHAPE is not free is an
   unapplied Function: it has no shape property, so recognizing one evaluates
   its body at a probe point unless ArrayDeclareShape has already given the
   shape (see Lazy.wl).  Validating once and storing a normalized form would
   trade that for a worse failure: admission can LAPSE (an assumption-registered
   symbol whose $Assumptions entry is removed stops being a container), and a
   handle validated once would go on reporting a shape it no longer has.  Every
   use re-validates instead, so a stale handle messages - see objectData. *)

ArrayObject[a_] /; ! ArrayContainerQ[a] && (Message[ArrayObject::nocontainer, a]; False) := Null

(* Wrong arity is declined with a message for the same reason unsupported input
   is: ArrayObject[a, b] would otherwise stay unevaluated in silence and read as
   a handle at a glance while failing ArrayObjectQ. *)
ArrayObject[args___] /; Length[{args}] =!= 1 && (Message[ArrayObject::argx, Length[{args}]]; False) := Null

(* ArrayContainerQ has an UpValue for ArrayObject below, which would otherwise
   make ArrayObject[ArrayObject[a]] a legal doubly-wrapped object whose Kind is
   "ArrayObject"; wrapping is idempotent instead. *)
ArrayObject[obj_ArrayObject ? ArrayObjectQ] := obj


(* HoldPattern is load-time hygiene, not decoration: an assignment evaluates the
   arguments of its left-hand side, so a bare ArrayObject[a_] here would be
   evaluated against the rejection guard above and emit ArrayObject::nocontainer
   for the pattern "a_" while the paclet loads.  The same applies to the
   property dispatch below, whose head is also an ArrayObject expression. *)

ArrayObjectQ[HoldPattern[ArrayObject[a_]]] := ArrayContainerQ[a]

ArrayObjectQ[___] := False


(* === container kind === *)

(* Kind is derived from the head rather than looked up in a table, so a head
   admitted later by the classification tier reports its own name instead of
   being silently mislabelled by a stale lookup.  headKind recurses Head-wards
   until it reaches a Symbol, which every atom's head chain terminates in:
   SparseArray[data] -> SparseArray, InterpolatingFunction[data][t] ->
   InterpolatingFunction[data] -> InterpolatingFunction.  Inactive is unwrapped
   so an inactive symbolic tree reports the operation (Inactive[TensorProduct]
   -> "TensorProduct"), not "Inactive".

   Verified head by head against a live kernel; only two containers do not have
   an informative head, and each gets its own arrayKind clause: a List, whose
   packing is the interesting distinction, and an assumption-registered symbol,
   whose head is Symbol. *)

headKind[Inactive[h_]] := headKind[h]

headKind[h_Symbol] := SymbolName[h]

headKind[h_] := headKind[Head[h]]


arrayKind[a_List] := If[Developer`PackedArrayQ[a], "PackedArray", "List"]

arrayKind[_Symbol] := "Symbol"

arrayKind[a_] := headKind[a]


(* The tier and the element metadata are the type algebra's, not the handle's:
   ArrayTier, ArrayElementType and ArrayElementDomain live in Types.wl, where
   the lattices they order are defined, and the handle only reports them. *)


(* === properties === *)

$arrayObjectProperties = {
    "ComputeNativeQ", "Data", "Dimensions", "Domain", "ElementType", "Kind",
    "Normal", "NumberQ", "NumericQ", "Properties", "Rank", "Tier"
}

arrayObjectProperty[a_, "Data"] := a

arrayObjectProperty[a_, "Kind"] := arrayKind[a]

arrayObjectProperty[a_, "Tier"] := ArrayTier[a]

arrayObjectProperty[a_, "Dimensions"] := ArrayDimensions[a]

arrayObjectProperty[a_, "Rank"] := ArrayRank[a]

arrayObjectProperty[a_, "ComputeNativeQ"] := ArrayComputeNativeQ[a]

arrayObjectProperty[a_, "NumericQ"] := ArrayNumericQ[a]

arrayObjectProperty[a_, "NumberQ"] := ArrayNumberQ[a]

arrayObjectProperty[a_, "ElementType"] := ArrayElementType[a]

(* The domain is the element type's tier-independent counterpart: a symbolic
   array over Reals and a "Real64" NumericArray describe their elements in the
   same terms, which is what makes them joinable. *)
arrayObjectProperty[a_, "Domain"] := ArrayElementDomain[a]

(* "Normal" is the only property that materializes. *)
arrayObjectProperty[a_, "Normal"] := ArrayMaterialize[a]

arrayObjectProperty[_, "Properties"] := $arrayObjectProperties


(* The four dispatch clauses are mutually exclusive by construction (MemberQ
   against ! MemberQ, ArrayContainerQ against its negation, one argument against
   any other count), so none of them depends on definition ordering.  Anything
   unsupported messages and stays unevaluated, matching the way the head itself
   declines unsupported input. *)

HoldPattern[ArrayObject[a_ ? ArrayContainerQ][prop_]] := arrayObjectProperty[a, prop] /; MemberQ[$arrayObjectProperties, prop]

HoldPattern[ArrayObject[a_ ? ArrayContainerQ][prop_]] /; ! MemberQ[$arrayObjectProperties, prop] && (Message[ArrayObject::noprop, prop]; False) := Null

(* A stale handle: the expression carries the evaluated flag from the moment it
   was built, so the rejection guard on the head never fires a second time and a
   handle whose container stopped qualifying would otherwise read properties
   straight off a non-container. *)
HoldPattern[ArrayObject[a_][___]] /; ! ArrayContainerQ[a] && (Message[ArrayObject::nocontainer, a]; False) := Null

HoldPattern[ArrayObject[a_ ? ArrayContainerQ][props___]] /; Length[{props}] =!= 1 && (Message[ArrayObject::propx, Length[{props}]]; False) := Null


(* === transparent operations === *)

(* Every exported function that takes a container takes a handle too, and gives
   the answer for the RAW container: the handle is unwrapped on the way in and
   never rebuilt on the way out.  "Never rebuilt" is the whole rule, and it is
   what keeps the veneer thin - no operation has to decide whether to re-wrap
   its result, and no other kernel file learns that ArrayObject exists.

   These clauses are not a convenience.  The tier UpValues below make a handle
   satisfy ArrayContainerQ and ArrayExplicitQ, which are the guards nearly every
   definition in the paclet is written against, so WITHOUT them ArrayVector[obj]
   would match `a_ ? ArrayExplicitQ` in Vector.wl and hand the wrapper straight
   to Flatten: a silent wrong answer rather than an inert expression.

   An UpValue reaches an argument, not an argument's parts, so a handle nested
   inside a list is not unwrapped here: ArrayContract[{a, obj}, pairs] carries it
   into the inactive tensor product, where the Normal UpValue below still gives
   TensorContract the right array, but the result can come back in a different
   container form than the raw-container call would give.  Pass obj["Data"] in a
   list to keep the forms identical. *)

(* The container inside a handle, taken without re-validating it: each caller
   below has already settled what an invalid handle is to do. *)
objectContainer[HoldPattern[ArrayObject[a_]]] := a

(* A malformed handle (wrong arity, already diagnosed by ArrayObject::argx) has
   no container to take, so it stands for itself and fails the test below. *)
objectContainer[expr_] := expr

(* Handles taken out of an expression that something else is about to evaluate.

   An UpValue reaches a handle that is an ARGUMENT, which covers every operation
   this file forwards; it cannot reach one nested inside an expression that a
   third function evaluates.  A deferred structural tree is exactly that case: a
   handle passes deferredLeafQ, because ArrayExplicitQ forwards, and its shape
   reads through the node - but the tree materializes by Activate, which hands
   the handle itself to TensorProduct, Dot, Transpose or Plus, none of which
   know it.  Every node head produced an unevaluated expression rather than the
   tree's array, so the unwrapping happens once, here, rather than as an UpValue
   on each of those heads - which would mean giving Plus and Dot UpValues for a
   container handle, far past what this file is for.

   Kept beside objectContainer so that knowledge of the handle's shape stays in
   this file and the caller only names the helper. *)

unwrapArrayObjects[expr_] := expr /. o_ArrayObject /; ArrayObjectQ[o] :> objectContainer[o]

(* Re-validation on use, since the handle carries the evaluated flag and its
   container's admission can lapse.  A stale handle messages and gives
   Missing["NotAContainer"], instead of falling through to a generic clause:
   ArrayDimensions would otherwise reach the TensorDimensions probe in Shape.wl
   and report {} for it, and ArrayRank would report rank 0. *)
objectData[f_, obj_] := With[{a = objectContainer[obj]},
    If[ ArrayContainerQ[a],
        f[a],

        Message[ArrayObject::nocontainer, a];
        Missing["NotAContainer"]
    ]
]


(* Classification and shape predicates answer False for a stale handle rather
   than messaging: a predicate is asked whether something is a container, so
   saying no IS the answer. *)

ArrayObject /: ArrayContainerQ[obj_ArrayObject ? ArrayObjectQ] := True

ArrayObject /: ArrayExplicitQ[obj_ArrayObject ? ArrayObjectQ] := ArrayExplicitQ[objectContainer[obj]]

ArrayObject /: ArrayLazyQ[obj_ArrayObject ? ArrayObjectQ] := ArrayLazyQ[objectContainer[obj]]

ArrayObject /: ArraySymbolicQ[obj_ArrayObject ? ArrayObjectQ] := ArraySymbolicQ[objectContainer[obj]]

ArrayObject /: ArrayComputeNativeQ[obj_ArrayObject ? ArrayObjectQ] := ArrayComputeNativeQ[objectContainer[obj]]

ArrayObject /: ArrayNumericQ[obj_ArrayObject ? ArrayObjectQ] := ArrayNumericQ[objectContainer[obj]]

ArrayObject /: ArrayNumberQ[obj_ArrayObject ? ArrayObjectQ] := ArrayNumberQ[objectContainer[obj]]

ArrayObject /: ZeroArrayQ[obj_ArrayObject ? ArrayObjectQ] := ZeroArrayQ[objectContainer[obj]]

ArrayObject /: ArrayAllZeroQ[obj_ArrayObject ? ArrayObjectQ] := ArrayAllZeroQ[objectContainer[obj]]


(* Type algebra.  ArrayUnify takes a LIST, and an UpValue reaches an argument
   rather than an argument's parts, so a handle inside such a list is not
   unwrapped here - pass obj["Data"], as for the list form of ArrayContract. *)

ArrayObject /: ArrayTier[obj_ArrayObject] := objectData[ArrayTier, obj]

ArrayObject /: ArrayElementDomain[obj_ArrayObject] := objectData[ArrayElementDomain, obj]

ArrayObject /: ArrayElementType[obj_ArrayObject] := objectData[ArrayElementType, obj]

ArrayObject /: ArrayCoerce[obj_ArrayObject, spec_] := objectData[ArrayCoerce[#, spec] &, obj]


(* Shape and materialization. *)

ArrayObject /: ArrayDimensions[obj_ArrayObject] := objectData[ArrayDimensions, obj]

ArrayObject /: ArrayRank[obj_ArrayObject] := objectData[ArrayRank, obj]

ArrayObject /: ArrayMaterialize[obj_ArrayObject] := objectData[ArrayMaterialize, obj]

ArrayObject /: ArrayComputable[obj_ArrayObject] := objectData[ArrayComputable, obj]

ArrayObject /: Normal[obj_ArrayObject] := objectData[ArrayMaterialize, obj]


(* Accessors. *)

ArrayObject /: ArrayExplicitValues[obj_ArrayObject] := objectData[ArrayExplicitValues, obj]

ArrayObject /: ArrayExplicitPositions[obj_ArrayObject] := objectData[ArrayExplicitPositions, obj]

ArrayObject /: ArrayExplicitLength[obj_ArrayObject] := objectData[ArrayExplicitLength, obj]

ArrayObject /: ArrayPack[obj_ArrayObject] := objectData[ArrayPack, obj]


(* Structural and value operations. *)

ArrayObject /: ArrayName[obj_ArrayObject] := objectData[ArrayName, obj]

ArrayObject /: SimplifyArray[obj_ArrayObject] := objectData[SimplifyArray, obj]

ArrayObject /: ArrayConjugate[obj_ArrayObject] := objectData[ArrayConjugate, obj]

ArrayObject /: ArrayTranspose[obj_ArrayObject, perm_] := objectData[ArrayTranspose[#, perm] &, obj]

ArrayObject /: ArrayContract[obj_ArrayObject, c_] := objectData[ArrayContract[#, c] &, obj]

ArrayObject /: ArrayPart[obj_ArrayObject, is_List, k___] := objectData[ArrayPart[#, is, k] &, obj]

ArrayObject /: ArrayReplaceAll[obj_ArrayObject, rules_] := objectData[ArrayReplaceAll[#, rules] &, obj]

ArrayObject /: ArrayMap[f_, obj_ArrayObject, level___] := objectData[ArrayMap[f, #, level] &, obj]


(* Flatten, reshape and pad. *)

ArrayObject /: ArrayVector[obj_ArrayObject] := objectData[ArrayVector, obj]

ArrayObject /: ReshapeArray[obj_ArrayObject, dims_, pad___] := objectData[ReshapeArray[#, dims, pad] &, obj]

ArrayObject /: PadArray[obj_ArrayObject, spec_, padding___] := objectData[PadArray[#, spec, padding] &, obj]


(* === summary box === *)

(* A fixed 3 x 3 grid motif, built from primitives so the paclet carries no
   image asset.  It is a constant expression evaluated once at load. *)

$arrayObjectIcon = Graphics[
    {
        EdgeForm[GrayLevel[0.35]],
        FaceForm[GrayLevel[0.85]],
        Rectangle[#, # + {0.86, 0.86}] & /@ Tuples[{0, 1, 2}, 2],
        FaceForm[GrayLevel[0.55]],
        Rectangle[{0, 2}, {0.86, 2.86}]
    },
    ImageSize -> {24, 24},
    PlotRange -> {{-0.07, 2.93}, {-0.07, 2.93}},
    PlotRangePadding -> None,
    Background -> None
]


(* The element row is the element TYPE where the container carries one and the
   element DOMAIN where it does not, so that every container that has element
   metadata at all shows it in terms the type algebra can join.  A QuantityArray
   carries a unit rather than an element type and gets its own row too;
   "UnitBlock" is the cheap accessor, while QuantityUnit builds a full array of
   per-element units. *)

arrayDomainItems[a_] := With[{domain = ArrayElementDomain[a]},
    If[MissingQ[domain], {}, {BoxForm`SummaryItem[{"domain: ", domain}]}]
]

arrayElementItems[a_QuantityArray] := Join[
    {BoxForm`SummaryItem[{"unit: ", a["UnitBlock"]}]},
    arrayDomainItems[a]
]

arrayElementItems[a_] := With[{type = ArrayElementType[a]},
    If[MissingQ[type], arrayDomainItems[a], {BoxForm`SummaryItem[{"element type: ", type}]}]
]


(* MakeBoxes holds its argument, and every quantity on the box comes from the
   classification and shape tiers, which are shape-only probes: an NDSolve-backed
   lazy container and a symbolic container both draw a full box without ever
   reaching ArrayMaterialize.  A test pins this by blocking ArrayMaterialize
   away while rendering every admitted head.  ArrayNumericQ and ArrayNumberQ do
   read elements, but only on the explicit tier: on a lazy or symbolic container
   they fall straight through to False, and every wrapper head answers from
   stored type metadata (see the EventSeries clauses in Shape.wl).

   A stale handle draws no box at all: MakeBoxes is a renderer and must not
   message, so the guard simply declines and the expression prints as itself. *)

ArrayObject /: MakeBoxes[obj : ArrayObject[a_], form : StandardForm | TraditionalForm] /; ArrayObjectQ[obj] :=
    BoxForm`ArrangeSummaryBox[
        ArrayObject,
        obj,
        $arrayObjectIcon,
        {
            BoxForm`SummaryItem[{"kind: ", arrayKind[a]}],
            BoxForm`SummaryItem[{"dimensions: ", ArrayDimensions[a]}]
        },
        Join[
            {
                BoxForm`SummaryItem[{"tier: ", ArrayTier[a]}],
                BoxForm`SummaryItem[{"compute native: ", ArrayComputeNativeQ[a]}],
                BoxForm`SummaryItem[{"numeric: ", ArrayNumericQ[a]}],
                BoxForm`SummaryItem[{"inexact: ", ArrayNumberQ[a]}]
            },
            arrayElementItems[a]
        ],
        form,
        "Interpretable" -> Automatic
    ]
