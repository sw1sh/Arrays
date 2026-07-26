---
Template: Symbol
Name: ArrayComputeNativeQ
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayComputeNativeQ
Keywords: [compute native, capability flag, storage container, array container, predicate]
SeeAlso: [ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ, ArrayMaterialize, ArrayPack, ArrayNumericQ]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayComputeNativeQ]()[*a*]</code> gives True if an explicit array container computes natively without materializing: `SparseArray`, packed or plain `List` arrays, `QuantityArray` and `TabularColumn`; storage-only containers (`NumericArray`, structured arrays such as `SymmetrizedArray`, `Tabular`, `Dataset`, `ByteArray`, `EventSeries`, `DataStructure` stores) give False, as do lazy and symbolic containers.

## Details & Options

- [ArrayComputeNativeQ]() is a per-head capability flag, not an admission gate: a container that gives False is still a full explicit-tier container ([ArrayExplicitQ]()), and every operation works on it through its materialization route ([ArrayMaterialize]()).
- The flag is True only for heads verified to run elementwise arithmetic and `Dot` natively without materializing.
- Compute-native and storage-only heads:

| container | flag |
|---|---|
| <code>SparseArray</code> | True |
| packed or plain <code>List</code> array | True |
| <code>QuantityArray</code> | True |
| <code>TabularColumn</code> | True |
| <code>NumericArray</code> | False |
| structured arrays (<code>SymmetrizedArray</code>, ...) | False |
| <code>Tabular</code>, <code>Dataset</code> | False |
| <code>ByteArray</code>, <code>EventSeries</code> | False |
| <code>DataStructure</code> stores | False |

- `EventSeries` does thread elementwise scalar arithmetic natively (adding a scalar stays an `EventSeries`), but it has no native `Dot`, so it gives False.
- A plain `List` gives True only when it is an actual array (`ArrayQ`); a ragged list gives False.
- Lazy and symbolic containers give False: a lazy container defers evaluation, and a symbolic container has no elements to compute with.
- Callers branch on the flag to decide between operating on the container in place and routing through [ArrayMaterialize]() first.

## Basic Examples

A `SparseArray` computes natively:

```wl
ArrayComputeNativeQ[SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => True -->

A `NumericArray` is storage-only:

```wl
ArrayComputeNativeQ[NumericArray[{1., 2.}]]
```

<!-- => False -->

Storage-only containers are still full explicit containers:

```wl
ArrayExplicitQ[NumericArray[{1., 2.}]]
```

<!-- => True -->

## Scope

### Compute-native containers

A `SparseArray` computes natively:

```wl
ArrayComputeNativeQ[SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => True -->

---

A packed `List` array computes natively:

```wl
ArrayComputeNativeQ[Developer`ToPackedArray[N[{1, 2}]]]
```

<!-- => True -->

---

A plain `List` array computes natively:

```wl
ArrayComputeNativeQ[{{1, 2}, {3, 4}}]
```

<!-- => True -->

---

A `QuantityArray` computes natively, keeping its units:

```wl
ArrayComputeNativeQ[QuantityArray[{1., 2.}, "Meters"]]
```

<!-- => True -->

---

A `TabularColumn` computes natively:

```wl
ArrayComputeNativeQ[TabularColumn[{1., 2.}]]
```

<!-- => True -->

### Storage-only containers

A `NumericArray` is storage-only:

```wl
ArrayComputeNativeQ[NumericArray[{1., 2.}]]
```

<!-- => False -->

---

A structured array such as `SymmetrizedArray` is storage-only:

```wl
ArrayComputeNativeQ[SymmetrizedArray[{{1, 2} -> 3.}, {2, 2}, Antisymmetric[{1, 2}]]]
```

<!-- => False -->

---

A `Tabular` is storage-only:

```wl
ArrayComputeNativeQ[Tabular[{{1., 2.}, {3., 4.}}]]
```

<!-- => False -->

---

A `Dataset` is storage-only:

```wl
ArrayComputeNativeQ[Dataset[{1, 2, 3}]]
```

<!-- => False -->

---

A `ByteArray` is storage-only:

```wl
ArrayComputeNativeQ[ByteArray[{1, 2, 3}]]
```

<!-- => False -->

---

An `EventSeries` is storage-only:

```wl
ArrayComputeNativeQ[EventSeries[{1., 2.}, {{0, 1}}]]
```

<!-- => False -->

---

A `DataStructure` array store is storage-only:

```wl
ArrayComputeNativeQ[CreateDataStructure["DynamicArray", {1., 2.}]]
```

<!-- => False -->

### Lazy and symbolic containers

A lazy container defers evaluation, so it does not compute natively:

```wl
v = NDSolveValue[{f'[t] == {{0, 1}, {-1, 0}} . f[t], f[0] == {1., 0.}}, f, {t, 0, 1}];
ArrayComputeNativeQ[v[tau]]
```

<!-- => False -->

---

A symbolic container has no elements to compute with:

```wl
ArrayComputeNativeQ[MatrixSymbol["M", {2, 3}]]
```

<!-- => False -->

## Properties and Relations

A compute-native container runs arithmetic in place; a `QuantityArray` keeps its wrapper:

```wl
2 QuantityArray[{1., 2., 3.}, "Meters"]
```

<!-- => a QuantityArray summary box: 3 meter quantities -->

---

The scaled magnitudes are computed without leaving the wrapper:

```wl
QuantityMagnitude[2 QuantityArray[{1., 2., 3.}, "Meters"]]
```

<!-- => {2., 4., 6.} -->

---

`Dot` on a `SparseArray` stays sparse:

```wl
SparseArray[{{0, 1}, {2, 0}}] . SparseArray[{{0, 1}, {2, 0}}]
```

<!-- => a SparseArray summary box: dimensions {2, 2}, 2 explicit values -->

---

The dense form of that product:

```wl
Normal[SparseArray[{{0, 1}, {2, 0}}] . SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => {{2, 0}, {0, 2}} -->

---

Arithmetic on a storage-only `NumericArray` comes back unevaluated instead of computing:

```wl
2 NumericArray[{1., 2.}]
```

<!-- => the product unchanged: 2 NumericArray[{1., 2.}, "Real64"], the NumericArray shown as its summary box -->

---

A `SparseArray` is a compute-native container and an explicit one:

```wl
ArrayExplicitQ[SparseArray[{1., 2.}]]
```

<!-- => True -->

---

A `QuantityArray` is explicit too:

```wl
ArrayExplicitQ[QuantityArray[{1., 2.}, "Meters"]]
```

<!-- => True -->

---

So is a `TabularColumn`:

```wl
ArrayExplicitQ[TabularColumn[{1., 2.}]]
```

<!-- => True -->

---

Storage-only containers still materialize to explicit data:

```wl
ArrayMaterialize[NumericArray[{{1., 0.}, {0., 2.}}]]
```

<!-- => {{1., 0.}, {0., 2.}} -->

## Possible Issues

`EventSeries` threads elementwise scalar arithmetic natively, staying an `EventSeries`:

```wl
EventSeries[{1., 2.}, {{0, 1}}] + 1
```

<!-- => an EventSeries summary box: 2 events, values {2., 3.} -->

---

The flag is False nonetheless, since `EventSeries` has no native `Dot`:

```wl
ArrayComputeNativeQ[EventSeries[{1., 2.}, {{0, 1}}]]
```

<!-- => False -->
