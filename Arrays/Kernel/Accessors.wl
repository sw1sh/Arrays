Package["Wolfram`Arrays`"]

PackageExport[ArrayExplicitValues]
PackageExport[ArrayExplicitPositions]
PackageExport[ArrayExplicitLength]
PackageExport[ArrayMaterialize]
PackageExport[ArrayComputable]
PackageExport[ArrayPack]


ArrayExplicitValues::usage = "ArrayExplicitValues[a] gives the explicitly stored values of a SparseArray, or the nonzero values of any other explicit array container via an on-demand SparseArray wrap; lazy and symbolic containers give Missing[\"NotExplicit\"]."

ArrayExplicitPositions::usage = "ArrayExplicitPositions[a] gives the positions of the explicitly stored values of a SparseArray, or the nonzero positions of any other explicit array container via an on-demand SparseArray wrap; lazy and symbolic containers give Missing[\"NotExplicit\"]."

ArrayExplicitLength::usage = "ArrayExplicitLength[a] gives the number of explicitly stored values of a SparseArray, or of nonzero values of any other explicit array container via an on-demand SparseArray wrap; lazy and symbolic containers give Missing[\"NotExplicit\"]."

ArrayMaterialize::usage = "ArrayMaterialize[a] gives an explicit array of scalar expressions for any array container: Normal for explicit containers, with wrapper-specific routes: QuantityMagnitude for a QuantityArray, per-column Normal for a named Tabular, Normal of the \"Values\" column for an EventSeries, and an immediate packed snapshot of the elements for a DataStructure store, whose handles otherwise alias each other; a lazy container expands per scalar where its head has a per-scalar form (reinterpolation for an InterpolatingFunction, per-position branch threading for a Piecewise, an array of scalar Functions for a Function) and through Indexed where it has none, as for a ParametricFunction; a deferred structural tree, whose leaves are all explicit, is activated; the leafless symbolic containers give the input itself."

ArrayComputable::usage = "ArrayComputable[a] gives a form of an array container that the kernel computes with directly: a container whose arithmetic is native (ArrayComputeNativeQ) is returned unchanged, and any other explicit container is materialized, since Dot, Norm, KroneckerProduct and Eigensystem do not traverse a storage-only container. Lazy and symbolic containers are returned unchanged, because there is no computable form of one short of binding its parameters."

ArrayPack::usage = "ArrayPack[a] gives a best-effort packed array conversion of an explicit array container, trying the plain, Real and Complex forms of Developer`ToPackedArray in turn; the coercing forms are accepted only when every value survives at machine precision, and any input that cannot be packed faithfully, including lazy and symbolic containers, is returned unchanged."


(* On-demand SparseArray wrap for dense explicit containers; SparseArray cannot
   ingest a NumericArray or an array with a zero dimension directly. *)

toSparseArray[a_SparseArray] := a

toSparseArray[a_NumericArray] := SparseArray[Normal[a]]

(* Wrapper containers wrap their materialized data: SparseArray cannot ingest
   the wrapper heads directly, and for QuantityArray a direct SparseArray
   would take the slow Normal route through Quantity elements. *)
toSparseArray[a_ ? wrapperExplicitQ] := SparseArray[ArrayMaterialize[a]]

toSparseArray[a_] := SparseArray[a]


ArrayExplicitValues[a_SparseArray] := a["ExplicitValues"]

ArrayExplicitValues[a_ ? ArrayExplicitQ] := If[ZeroArrayQ[a], {}, toSparseArray[a]["ExplicitValues"]]

ArrayExplicitValues[a_ ? lazyContainerQ] := Missing["NotExplicit"]

ArrayExplicitValues[a_ ? ArraySymbolicQ] := Missing["NotExplicit"]


ArrayExplicitPositions[a_SparseArray] := a["ExplicitPositions"]

ArrayExplicitPositions[a_ ? ArrayExplicitQ] := If[ZeroArrayQ[a], {}, toSparseArray[a]["ExplicitPositions"]]

ArrayExplicitPositions[a_ ? lazyContainerQ] := Missing["NotExplicit"]

ArrayExplicitPositions[a_ ? ArraySymbolicQ] := Missing["NotExplicit"]


ArrayExplicitLength[a_SparseArray] := a["ExplicitLength"]

ArrayExplicitLength[a_ ? ArrayExplicitQ] := If[ZeroArrayQ[a], 0, toSparseArray[a]["ExplicitLength"]]

ArrayExplicitLength[a_ ? lazyContainerQ] := Missing["NotExplicit"]

ArrayExplicitLength[a_ ? ArraySymbolicQ] := Missing["NotExplicit"]


(* Wrapper materialization routes.  TabularColumn, Dataset and ByteArray ride
   the generic Normal clause below; the heads here need dedicated paths. *)

(* QuantityMagnitude hands back the internal packed magnitudes essentially for
   free; Normal would instead build an unpacked array of Quantity expressions,
   orders of magnitude slower.  Units are container metadata, recoverable for
   a rebuild from a["UnitBlock"]. *)
ArrayMaterialize[a_QuantityArray] := QuantityMagnitude[a]

(* Normal on a named Tabular yields a list of row Associations; the cheap
   route is per-column Normal (packed vectors) recombined by Transpose.  An
   anonymous all-numeric Tabular already Normals to a packed matrix. *)
ArrayMaterialize[a_Tabular ? TabularQ] := With[{keys = ColumnKeys[a]},
    If[ keys === None,
        Normal[a],
        Transpose[Map[Normal[a[[All, #]]] &, keys]]
    ]
]

(* The raw "Values" property returns a TabularColumn-backed view, not a plain
   list; Normal converts it to a packed array.  The time index is separate
   metadata, recoverable for a rebuild from a["Times"]. *)
ArrayMaterialize[a_EventSeries] := Normal[a["Values"]]

(* DataStructure handles have reference semantics (copies alias the same
   store), so materialization snapshots the elements immediately at the
   module boundary: the packed copy is immune to later mutation of the
   source handle. *)
ArrayMaterialize[ds_DataStructure ? wrapperExplicitQ] := Developer`ToPackedArray[ds["Elements"]]

(* Normal on a GPUArray copies the device buffer back to the kernel, which is
   the materialization and the point at which fp32 device precision becomes
   visible in ordinary machine reals. *)
ArrayMaterialize[a_GPUArray] := Normal[a]

ArrayMaterialize[a_ ? ArrayExplicitQ] := Normal[a]

(* A lazy container expands through its registered materialization handler: a
   per-scalar form where the head has one (reinterpolation for an
   InterpolatingFunction, threading through the branches of a Piecewise, an
   array of scalar Functions for a Function), and an Indexed expansion where it
   does not. *)
ArrayMaterialize[a_ ? lazyContainerQ] := lazyMaterialize[a]

(* A deferred tree is a structural tree whose leaves are all explicit, so its
   shape and its values are both fully determined and its materialization is one
   Activate.  Returning the tree unchanged would make ArrayMaterialize the only
   tier that hands back something ArrayExplicitQ rejects, and would leave every
   materialize-then-operate fallback - ArrayNumericQ, ArrayAllZeroQ, the wrapper
   clauses of Vector.wl and Structural.wl - with nothing to fall back to.  The
   leafless symbolic containers keep the identity behaviour below: they have no
   values to compute.

   Any ArrayObject handle among the leaves is unwrapped first.  A handle passes
   deferredLeafQ - ArrayExplicitQ forwards through it - and the node reads its
   shape through the same forwarding, but Activate would hand the handle itself
   to TensorProduct, Dot or Transpose, none of which know it, and the tree came
   back an unevaluated expression instead of its array.

   Only the NODE heads are activated.  A bare Activate fires every Inactive in
   the expression, the leaves' own included: a leaf carrying
   Inactive[Integrate][x, x] came back as x^2/2, which evaluates the contents
   rather than materializing the tree.  $inactiveNodeHeads is the vocabulary
   from Classification.wl restricted to the heads a clause admits INACTIVELY.

   The CONTRACTIONS are activated first, and that is the whole reason this is
   two passes rather than one.  A contraction over a tensor product is the shape
   a tensor-network contraction leaves behind, and TensorContract handles an
   INACTIVE TensorProduct operand directly - it contracts the operands against
   each other and never builds the product.  Activate the product first and the
   full outer product is built, only to be summed away immediately: on two rank-3
   operands of dimension 14 that is 125MB and 23ms against 1MB and 0.6ms, a
   factor of 119 in memory that grows with the rank of the tree.  A single
   restricted pass does not help, because it is the ORDER and not the vocabulary
   that decides this - it measures the same 125MB as a bare Activate.

   This is what TensorNetworks does in ActivateTensors, and for this reason. *)
ArrayMaterialize[a_ ? deferredTreeQ] := Activate[
    Activate[unwrapArrayObjects[a], ArrayContract | TensorContract],
    $inactiveNodeHeads
]

ArrayMaterialize[a_ ? ArraySymbolicQ] := a


(* The least conversion that makes native arithmetic work.  A container that
   already computes is returned untouched, which is the whole point: an
   unconditional ArrayMaterialize would densify a SparseArray and unpack a
   packed array at the moment a caller only wanted to be able to call Dot.
   Everything else materializes, lazy containers included, since a lazy
   container's per-scalar expansion is an ordinary array of expressions in its
   parameters and does compute.  The leafless symbolic containers need no
   clause of their own: ArrayMaterialize returns those unchanged already. *)

ArrayComputable[a_ ? ArrayComputeNativeQ] := a

ArrayComputable[a_ ? ArrayContainerQ] := ArrayMaterialize[a]

ArrayComputable[a_] := a


(* Best-effort packing: the plain form first, then the Real and Complex coercing
   forms, which pack the mixed Integer/Real and Integer/Complex lists that
   Normal of a numeric SparseArray can produce.  A coerced packing is accepted
   only when every value survives at machine precision (SetPrecision round-trip),
   so exact values such as 1/3 or 2^200 + 1 are never silently destroyed. *)

faithfulPackQ[packed_, a_] := Developer`PackedArrayQ[packed] && SetPrecision[packed, Infinity] == a

(* Rungs are tried in order and evaluation stops at the first faithful packing;
   collecting the candidates in a list would pack the array once per rung before
   testing any of them. *)

packRungs[a_, {}] := a

packRungs[a_, {type_, rest___}] := With[{packed = Developer`ToPackedArray[a, type]},
    If[faithfulPackQ[packed, a], packed, packRungs[a, {rest}]]
]

packList[a_List] := With[{packed = Developer`ToPackedArray[a]},
    If[ Developer`PackedArrayQ[packed],
        packed,
        packRungs[a, {Real, Complex}]
    ]
]

ArrayPack[a_List] := packList[a]

(* Non-List explicit containers pack their materialized data, which routes
   wrapper heads through their dedicated ArrayMaterialize paths (magnitudes
   for QuantityArray, per-column Normal for named Tabular, ...). *)
ArrayPack[a_] := If[ ArrayExplicitQ[a],
    With[{packed = packList[ArrayMaterialize[a]]},
        If[Developer`PackedArrayQ[packed], packed, a]
    ],

    a
]
