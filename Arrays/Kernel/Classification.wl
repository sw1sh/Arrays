Package["Wolfram`Arrays`"]

PackageExport[ArrayContainerQ]
PackageExport[ArrayExplicitQ]
PackageExport[ArrayLazyQ]
PackageExport[ArraySymbolicQ]
PackageExport[ArrayComputeNativeQ]

(* Wrapper-container predicates gate the materialize-first clauses in every
   other kernel file, so they cannot stay file-private. *)
PackageScope[wrapperExplicitQ]
PackageScope[opaqueWrapperQ]

(* Symbolic-tier vocabulary.  These are spliced into a definition left-hand side
   only below, after the assignment that binds them; an alias spliced into a
   left-hand side in ANOTHER file would have to be bound before that file loads,
   which is a load-order dependency nothing enforces.  The alternatives are
   therefore spelled out at every cross-file left-hand side
   (ArrayName in Structural.wl, setDimensions in Shape.wl), exactly as
   assumptionDimensions spells out (Vectors | Matrices | Arrays) in Shape.wl. *)
PackageScope[symbolicArrayHead]
PackageScope[arrayDomainHead]


ArrayContainerQ::usage = "ArrayContainerQ[a] gives True if a is a supported array container of any tier: explicit, lazy parametric, or symbolic."

ArrayExplicitQ::usage = "ArrayExplicitQ[a] gives True if a is an explicit array container: SparseArray, packed or plain List array, NumericArray, a structured array such as SymmetrizedArray, or a shape-introspectable wrapper container: QuantityArray, TabularColumn, Tabular, Dataset, ByteArray, EventSeries, or a DataStructure array store (\"DynamicArray\" or \"FixedArray\")."

ArrayLazyQ::usage = "ArrayLazyQ[a] gives True if a is a lazy parametric array container: an array-valued expression f[args] with at least one non-numeric argument, such as an array-valued InterpolatingFunction applied to a symbolic parameter."

ArraySymbolicQ::usage = "ArraySymbolicQ[a] gives True if a is a symbolic array container: VectorSymbol, MatrixSymbol, ArraySymbol, an atomic symbol registered in $Assumptions as an element of Vectors, Matrices or Arrays, or a structural inactive tree of such containers."

ArrayComputeNativeQ::usage = "ArrayComputeNativeQ[a] gives True if an explicit array container computes natively without materializing: SparseArray, packed or plain List arrays, QuantityArray and TabularColumn; storage-only containers (NumericArray, structured arrays such as SymmetrizedArray, Tabular, Dataset, ByteArray, EventSeries, DataStructure stores) give False, as do lazy and symbolic containers."


(* Explicit tier: SparseArray, packed and plain List arrays, and structured
   arrays (SymmetrizedArray etc.) all satisfy ArrayQ without materializing;
   NumericArray does not satisfy ArrayQ and gets its own clause.

   Wrapper containers are admitted under the shape-based criterion: the shape
   is introspectable without materializing AND a materialization path exists.
   Compute-nativeness is a per-head capability flag (ArrayComputeNativeQ),
   not an admission gate.  Note that ArrayQ is False for Tabular, Dataset,
   ByteArray, EventSeries and DataStructure, so they need head-based clauses.

   Association stays rejected: Dimensions and Normal report the entry
   multiset (the entry count and a list of rules), not the represented
   vector, so it has neither a faithful shape nor a faithful materialization;
   convert explicitly, e.g. SparseArray with caller-supplied dimensions. *)

wrapperExplicitQ[_QuantityArray | _TabularColumn | _Dataset | _EventSeries] := True

wrapperExplicitQ[a_Tabular] := TabularQ[a]

wrapperExplicitQ[a_ByteArray] := ByteArrayQ[a]

(* DataStructure array stores are rank-1 only; recognition is by store type.
   The handles have reference semantics (copies alias the same store), so
   every ingest path snapshots immediately: see ArrayMaterialize. *)
wrapperExplicitQ[ds_DataStructure] := DataStructureQ[ds] && MatchQ[ds, DataStructure["DynamicArray" | "FixedArray", ___]]

wrapperExplicitQ[___] := False


(* Wrappers without native structural support: every admitted wrapper except
   QuantityArray, whose Transpose, Conjugate, Flatten and ArrayReshape all
   preserve the wrapper natively. *)

opaqueWrapperQ[_QuantityArray] := False

opaqueWrapperQ[a_] := wrapperExplicitQ[a]


ArrayExplicitQ[_NumericArray] := True

ArrayExplicitQ[a : _QuantityArray | _TabularColumn | _Tabular | _Dataset | _ByteArray | _EventSeries | _DataStructure] := wrapperExplicitQ[a]

ArrayExplicitQ[a_] := ArrayQ[a]

ArrayExplicitQ[___] := False


(* Compute-native capability flag: True only for heads verified to run
   elementwise arithmetic and Dot natively without materializing.
   Storage-only containers (NumericArray, structured-array atoms, Tabular,
   Dataset, ByteArray, EventSeries, DataStructure stores) give False even
   though they are explicit-tier containers.  EventSeries does thread
   elementwise scalar arithmetic natively (ev + 1 stays an EventSeries), but
   it has no native Dot, so it stays False here. *)

ArrayComputeNativeQ[_SparseArray] := True

ArrayComputeNativeQ[a_List] := ArrayQ[a]

ArrayComputeNativeQ[_QuantityArray] := True

ArrayComputeNativeQ[_TabularColumn] := True

ArrayComputeNativeQ[___] := False


(* Lazy tier: an array-valued expression f[args] with at least one non-numeric argument.
   Supported heads are extensible: add one ArrayLazyQ clause (and an ArrayDimensions
   clause) per new head, before the False fall-through. *)

ArrayLazyQ[(f_InterpolatingFunction)[args__]] := f["OutputDimensions"] =!= {} && ! AllTrue[{args}, NumericQ]

ArrayLazyQ[___] := False


(* Symbolic tier: VectorSymbol | MatrixSymbol | ArraySymbol, atomic symbols registered
   in $Assumptions, and structural trees over such containers. *)

symbolicArrayHead = VectorSymbol | MatrixSymbol | ArraySymbol

arrayDomainHead = Vectors | Matrices | Arrays

ArraySymbolicQ[symbolicArrayHead[__]] := True

(* assumptionDimensions lives in Shape.wl next to the other $Assumptions probes. *)
ArraySymbolicQ[s_Symbol] := ! MissingQ[assumptionDimensions[s]]

ArraySymbolicQ[Inactive[D][t_, __]] := ArraySymbolicQ[t]

ArraySymbolicQ[(Verbatim[Transpose] | Inactive[Transpose])[t_, ___]] := ArraySymbolicQ[t]

ArraySymbolicQ[Inactive[TensorProduct][ts__]] := AnyTrue[{ts}, ArraySymbolicQ]

ArraySymbolicQ[Verbatim[Plus][ts__]] := AnyTrue[{ts}, ArraySymbolicQ]

ArraySymbolicQ[HoldPattern[IgnoringInactive[(ArrayContract | TensorContract)[t_, _]]]] := ArraySymbolicQ[t]

ArraySymbolicQ[___] := False


ArrayContainerQ[a_] := ArrayExplicitQ[a] || ArrayLazyQ[a] || ArraySymbolicQ[a]

ArrayContainerQ[___] := False
