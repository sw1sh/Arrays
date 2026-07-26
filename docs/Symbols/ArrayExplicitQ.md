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

A `SparseArray` stores its explicit values and is explicit:

```wl
ArrayExplicitQ[SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => True -->

---

A packed `List` array is explicit:

```wl
ArrayExplicitQ[Developer`ToPackedArray[N[{{1, 2}, {3, 4}}]]]
```

<!-- => True -->

---

A plain `List` array of symbolic scalars is explicit as well, since it stores its elements:

```wl
ArrayExplicitQ[{{a1, a2}, {a3, a4}}]
```

<!-- => True -->

---

A `NumericArray` is explicit through its own clause, since `ArrayQ` is False for it:

```wl
ArrayExplicitQ[NumericArray[{{1., 0.}, {0., 2.}}]]
```

<!-- => True -->

---

A structured array such as `SymmetrizedArray` is explicit:

```wl
ArrayExplicitQ[SymmetrizedArray[{{1, 2} -> 3.}, {2, 2}, Antisymmetric[{1, 2}]]]
```

<!-- => True -->

### Wrapper containers

A `QuantityArray` is an admitted wrapper container:

```wl
ArrayExplicitQ[QuantityArray[{1., 2.}, "Meters"]]
```

<!-- => True -->

---

A `TabularColumn` is an admitted wrapper container:

```wl
ArrayExplicitQ[TabularColumn[{1., 2.}]]
```

<!-- => True -->

---

A `Tabular` is an admitted wrapper container:

```wl
ArrayExplicitQ[Tabular[{{1., 2.}, {3., 4.}}]]
```

<!-- => True -->

---

A `Dataset` is an admitted wrapper container:

```wl
ArrayExplicitQ[Dataset[{1, 2, 3}]]
```

<!-- => True -->

---

A `ByteArray` is an admitted wrapper container:

```wl
ArrayExplicitQ[ByteArray[{1, 2, 3}]]
```

<!-- => True -->

---

An `EventSeries` is an admitted wrapper container:

```wl
ArrayExplicitQ[EventSeries[{1., 2.}, {{0, 1}}]]
```

<!-- => True -->

---

A "DynamicArray" `DataStructure` store qualifies:

```wl
ArrayExplicitQ[CreateDataStructure["DynamicArray", {1., 2., 3.}]]
```

<!-- => True -->

---

A "LinkedList" store is not array-shaped and does not qualify:

```wl
ArrayExplicitQ[CreateDataStructure["LinkedList"]]
```

<!-- => False -->

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
ArrayExplicitQ[v[0.5]]
```

<!-- => True -->

---

The same numeric application is no longer lazy:

```wl
ArrayLazyQ[v[0.5]]
```

<!-- => False -->

## Properties and Relations

Explicit containers expose their stored values through [ArrayExplicitValues]():

```wl
ArrayExplicitValues[SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => {1, 2} -->

---

A `NumericArray` is an explicit container:

```wl
ArrayExplicitQ[NumericArray[{1., 2.}]]
```

<!-- => True -->

---

Being explicit does not imply computing natively; `NumericArray` is storage-only:

```wl
ArrayComputeNativeQ[NumericArray[{1., 2.}]]
```

<!-- => False -->

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
