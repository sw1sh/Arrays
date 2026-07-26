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

(* Structural-tree vocabulary, read at call time by Shape.wl, Structural.wl and
   Accessors.wl; nothing here is spliced into a left-hand side either. *)
PackageScope[structuralNodeOperands]
PackageScope[structuralNodeQ]
PackageScope[deferredTreeQ]


ArrayContainerQ::usage = "ArrayContainerQ[a] gives True if a is a supported array container of any tier: explicit, lazy parametric, or symbolic."

ArrayExplicitQ::usage = "ArrayExplicitQ[a] gives True if a is an explicit array container: SparseArray, packed or plain List array, NumericArray, a structured array such as SymmetrizedArray, or a shape-introspectable wrapper container: QuantityArray, TabularColumn, Tabular, Dataset, ByteArray, EventSeries, or a DataStructure array store (\"DynamicArray\" or \"FixedArray\")."

ArrayLazyQ::usage = "ArrayLazyQ[a] gives True if a is a lazy parametric array container: an inert array-valued expression whose head is registered in the lazy tier. The registered heads are an array-valued InterpolatingFunction applied to at least one non-numeric argument, a fully applied array-valued ParametricFunction pf[params][t] with at least one non-numeric argument, an unapplied array-valued Function whose shape an ArrayDeclareShape declaration, a formal-symbol probe or a numeric probe settles, an array-valued Piecewise whose branch values and default are arrays of one shape, and a source NetGraph or NetChain - one with no open input ports, whose output port reports a positive integer dimension list and whose value is net[]. Exact numeric arguments such as Pi or 1/2 evaluate an applied form, so only non-numeric arguments stay lazy. Recognizing an unapplied Function EVALUATES it: with no declared shape its body is run at formal symbols and, failing that, at a random point in {0, 1}, so a Function with side effects or an expensive body should be given a shape with ArrayDeclareShape, which is consulted first and skips both probes."

ArraySymbolicQ::usage = "ArraySymbolicQ[a] gives True if a is a symbolic array container: VectorSymbol, MatrixSymbol, ArraySymbol, an atomic symbol registered in $Assumptions as an element of Vectors, Matrices or Arrays, or a structural tree whose nodes are Inactive[D], Transpose, Inactive[TensorProduct], Plus, TensorContract, ArrayContract, Dot, ArrayDot or ArrayReshape and whose operands are either at least one symbolic container or all explicit containers, the deferred form a tensor-network contraction returns unactivated. Recognizing a structural tree never probes the lazy tier, so it cannot evaluate a Function leaf."

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


(* Lazy tier: an inert array-valued expression whose head chain terminates in a
   symbol registered in the lazy-head registry of Lazy.wl.  Admitting a head is
   one RegisterLazyHead call there and nothing here: this clause, the shape
   clause in Shape.wl, the materialization clause in Accessors.wl and the
   structural clauses in Structural.wl and Vector.wl all dispatch through the
   registry and none of them names a lazy head.

   The registry probe is cheap on everything it declines: lazyContainerQ walks
   Head-wards to a Symbol (one step for a List or a SparseArray) and answers
   False without looking at any element. *)

ArrayLazyQ[a_] := lazyContainerQ[a]

ArrayLazyQ[___] := False


(* Symbolic tier: VectorSymbol | MatrixSymbol | ArraySymbol, atomic symbols registered
   in $Assumptions, and structural trees over symbolic or explicit containers. *)

symbolicArrayHead = VectorSymbol | MatrixSymbol | ArraySymbol

arrayDomainHead = Vectors | Matrices | Arrays

ArraySymbolicQ[symbolicArrayHead[__]] := True

(* assumptionDimensions lives in Shape.wl next to the other $Assumptions probes. *)
ArraySymbolicQ[s_Symbol] := ! MissingQ[assumptionDimensions[s]]


(* === structural trees ===

   A structural tree is a shape-known, evaluation-deferred operation over array
   containers: ArrayDimensions in Shape.wl computes its shape by recursing
   through the node without evaluating it, and Activate is its materialization.
   An operand set admits one under either of two tests:

     - at least one operand is symbolic, the original symbolic-tree rule, which
       keeps a tree that mixes a symbolic container with a scalar admitted, and
       which is also what carries the recursion through a NESTED node, since a
       node whose own operands qualify is itself symbolic; or
     - every operand is an EXPLICIT container, the deferred-tree rule, which is
       what admits the contraction expression that a tensor-network contraction
       returns unactivated, whose leaves are ordinary numeric tensors and whose
       nodes are pure structure.

   The deferred-tree test stops at the explicit tier deliberately.  ArrayLazyQ
   on an unapplied Function EVALUATES its body (see the ArrayLazyQ usage), so
   probing the lazy tier here would make mere classification of an arbitrary
   Inactive, Plus or Transpose expression run user code at any depth of the
   tree - a predicate asked whether something is a container has no business
   doing that.  A lazy leaf is not shut out: a tree that also carries a symbolic
   container is still admitted by the first test, exactly as before.

   TIER DECISION: deferred trees join the SYMBOLIC tier rather than getting one
   of their own.  The tier is not "carries no values", it is "has a shape and no
   addressable elements", and on that reading a deferred tree is already a
   symbolic container with its leaves filled in: ArrayExplicitValues,
   ArrayNumericQ, ArrayAllZeroQ and an off-element-level ArrayMap all have to
   answer for it exactly as they answer for a VectorSymbol tree, and the tier
   claimed inactive trees (Inactive[TensorProduct], Inactive[D], inactive
   TensorContract) before any of them could have a numeric leaf.  Nothing in the
   deferred case needs a per-head registration the way the lazy tier does, since
   the node vocabulary is a closed set of System operations, so the lazy registry
   would buy nothing.  This is therefore a widening of ArraySymbolicQ.

   Recognition is structural and names no paclet: the heads are the System
   operations that a pairwise contraction lowers to, matched through
   IgnoringInactive so that the active and inactive spellings behave
   identically.  HoldPattern is load-time hygiene, as everywhere else in the
   paclet: an assignment evaluates the arguments of its left-hand side, and a
   bare ArrayDot[x_, y_, _] there is an argument-checked call on patterns.

   ONE TABLE OF NODE HEADS, read by every tier.  structuralNodeOperands names
   the admitted heads and picks out their TENSOR operands - only those, since
   the third argument of ArrayDot is a contraction specification and a pair list
   such as {{3, 1}, {2, 2}} would pass ArrayContainerQ as a matrix.  The shape
   recursion of Shape.wl answers for exactly these heads and Tests/Shape.wlt
   walks the table asserting, on NON-SQUARE operands, that ArrayDimensions of
   every admitted node agrees with Dimensions of its Activate.  A head added
   here without a matching ArrayDimensions clause is the classification-versus-
   shape disagreement that assertion exists to catch. *)

structuralNodeOperands[Inactive[D][t_, __]] := {t}

structuralNodeOperands[(Verbatim[Transpose] | Inactive[Transpose])[t_, ___]] := {t}

structuralNodeOperands[Inactive[TensorProduct][ts__]] := {ts}

structuralNodeOperands[Verbatim[Plus][ts__]] := {ts}

structuralNodeOperands[HoldPattern[IgnoringInactive[(ArrayContract | TensorContract)[t_, _]]]] := {t}

structuralNodeOperands[HoldPattern[IgnoringInactive[Dot[ts__]]]] := {ts}

structuralNodeOperands[HoldPattern[IgnoringInactive[ArrayDot[x_, y_, _]]]] := {x, y}

structuralNodeOperands[HoldPattern[IgnoringInactive[ArrayReshape[t_, _, ___]]]] := {t}

structuralNodeOperands[___] := None


structuralNodeQ[a_] := ListQ[structuralNodeOperands[a]]


structuralOperandsQ[operands_List] := AnyTrue[operands, ArraySymbolicQ] || AllTrue[operands, ArrayExplicitQ]

ArraySymbolicQ[a_] := With[{operands = structuralNodeOperands[a]},
    ListQ[operands] && structuralOperandsQ[operands]
]

ArraySymbolicQ[___] := False


(* A DEFERRED tree is a structural tree with no symbolic leaf anywhere: every
   leaf is an explicit container, so the tree has a VALUE and merely defers
   computing it, and Activate is that computation.  That is the whole difference
   from the leafless symbolic containers sharing the tier - a VectorSymbol tree
   has no value at all - and it is what the value-producing operations dispatch
   on: ArrayMaterialize activates such a tree (Accessors.wl), and ArrayPart and
   an element-level ArrayMap go through that materialization rather than
   reaching the expression TREE or rewriting a contraction specification
   (Structural.wl). *)

deferredTreeQ[a_] := With[{operands = structuralNodeOperands[a]},
    ListQ[operands] && AllTrue[operands, deferredLeafQ]
]

deferredLeafQ[a_] := ArrayExplicitQ[a] || deferredTreeQ[a]


ArrayContainerQ[a_] := ArrayExplicitQ[a] || ArrayLazyQ[a] || ArraySymbolicQ[a]

ArrayContainerQ[___] := False
