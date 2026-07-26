---
Template: Symbol
Name: ArrayExplicitQ
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayExplicitQ
Keywords: [explicit array, array container, predicate, wrapper container, sparse array]
SeeAlso: [ArrayContainerQ, ArrayLazyQ, ArraySymbolicQ, ArrayComputeNativeQ, ArrayMaterialize, ArrayExplicitValues, ArrayNumericQ]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayExplicitQ]()[*a*]</code> gives True if *a* is an explicit array container: `SparseArray`, a packed or plain `List` array, `NumericArray`, a structured array such as `SymmetrizedArray`, or a shape-introspectable wrapper container: `QuantityArray`, `TabularColumn`, `Tabular`, `Dataset`, `ByteArray`, `EventSeries`, or a `DataStructure` array store ("DynamicArray" or "FixedArray").

## Details & Options

- Explicit containers store their elements, in contrast to the lazy parametric tier ([ArrayLazyQ]()) and the symbolic tier ([ArraySymbolicQ]()).
- `SparseArray`, packed and plain `List` arrays and structured arrays such as `SymmetrizedArray` all satisfy `ArrayQ` without materializing; `NumericArray` and the wrapper heads are recognized by dedicated clauses, since `ArrayQ` is False for them.
- Wrapper containers are admitted under a shape-based criterion: the shape is introspectable without materializing and a materialization path exists ([ArrayMaterialize]()); compute-nativeness is a per-head capability flag ([ArrayComputeNativeQ]()), not an admission gate.
- `DataStructure` containers are recognized by store type and are rank-1 only: "DynamicArray" and "FixedArray" stores qualify, other stores such as "LinkedList" do not; the handles have reference semantics, so every ingest path snapshots immediately.
- An array-valued `InterpolatingFunction` applied to all-numeric arguments evaluates to an explicit (typically packed) array, so [ArrayExplicitQ]() gives True there while [ArrayLazyQ]() gives False.
- [ArrayExplicitQ]() gives False for lazy and symbolic containers and for any non-container expression, including ragged lists and `Association`.

## Basic Examples

A `SparseArray` is an explicit container:

```wl
ArrayExplicitQ[SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => True -->

A symbolic container stores no elements:

```wl
ArrayExplicitQ[MatrixSymbol["M", {2, 3}]]
```

<!-- => False -->

## Scope

### Native arrays

`SparseArray`, packed and plain `List` arrays, `NumericArray` and structured arrays are all explicit:

```wl
ArrayExplicitQ /@ {SparseArray[{{0, 1}, {2, 0}}], Developer`ToPackedArray[N[{{1, 2}, {3, 4}}]], {{a1, a2}, {a3, a4}}, NumericArray[{{1., 0.}, {0., 2.}}], SymmetrizedArray[{{1, 2} -> 3.}, {2, 2}, Antisymmetric[{1, 2}]]}
```

<!-- => {True, True, True, True, True} -->

### Wrapper containers

All admitted wrapper heads are explicit containers:

```wl
ArrayExplicitQ /@ {QuantityArray[{1., 2.}, "Meters"], TabularColumn[{1., 2.}], Tabular[{{1., 2.}, {3., 4.}}], Dataset[{1, 2, 3}], ByteArray[{1, 2, 3}], EventSeries[{1., 2.}, {{0, 1}}], CreateDataStructure["DynamicArray", {1., 2.}]}
```

<!-- => {True, True, True, True, True, True, True} -->

---

Only the array-shaped `DataStructure` stores qualify:

```wl
{ArrayExplicitQ[CreateDataStructure["DynamicArray", {1., 2., 3.}]], ArrayExplicitQ[CreateDataStructure["LinkedList"]]}
```

<!-- => {True, False} -->

### Lazy and symbolic containers

Solve a vector-valued ODE, giving an array-valued `InterpolatingFunction`:

```wl
v = NDSolveValue[{f'[t] == {{0, 1}, {-1, 0}} . f[t], f[0] == {1., 0.}}, f, {t, 0, 1}]
```

<!-- => InterpolatingFunction[{{0., 1.}}, "<>"] summary box -->

Applied to a symbolic parameter, the container is lazy, not explicit:

```wl
ArrayExplicitQ[v[tau]]
```

<!-- => False -->

Applied to a numeric argument, it evaluates to an explicit packed array:

```wl
{ArrayExplicitQ[v[0.5]], ArrayLazyQ[v[0.5]]}
```

<!-- => {True, False} -->

## Properties and Relations

Explicit containers expose their stored values through [ArrayExplicitValues]():

```wl
ArrayExplicitValues[SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => {1, 2} -->

---

Being explicit does not imply computing natively; `NumericArray` is a storage-only container:

```wl
{ArrayExplicitQ[NumericArray[{1., 2.}]], ArrayComputeNativeQ[NumericArray[{1., 2.}]]}
```

<!-- => {True, False} -->

## Possible Issues

A ragged list is not an array, hence not an explicit container:

```wl
ArrayExplicitQ[{1, {2}}]
```

<!-- => False -->

---

`Association` is rejected: its `Dimensions` and `Normal` report the entry multiset, not a faithful array shape or materialization:

```wl
ArrayExplicitQ[<|1 -> 1.5, 2 -> 2.5|>]
```

<!-- => False -->
