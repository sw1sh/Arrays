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
| structured arrays (<code>SymmetrizedArray</code>, …) | False |
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

The compute-native heads:

```wl
ArrayComputeNativeQ /@ {SparseArray[{{0, 1}, {2, 0}}], Developer`ToPackedArray[N[{1, 2}]], {{1, 2}, {3, 4}}, QuantityArray[{1., 2.}, "Meters"], TabularColumn[{1., 2.}]}
```

<!-- => {True, True, True, True, True} -->

### Storage-only containers

The storage-only heads, all explicit containers nonetheless:

```wl
ArrayComputeNativeQ /@ {NumericArray[{1., 2.}], SymmetrizedArray[{{1, 2} -> 3.}, {2, 2}, Antisymmetric[{1, 2}]], Tabular[{{1., 2.}, {3., 4.}}], Dataset[{1, 2, 3}], ByteArray[{1, 2, 3}], EventSeries[{1., 2.}, {{0, 1}}], CreateDataStructure["DynamicArray", {1., 2.}]}
```

<!-- => {False, False, False, False, False, False, False} -->

### Lazy and symbolic containers

Neither lazy nor symbolic containers compute natively:

```wl
v = NDSolveValue[{f'[t] == {{0, 1}, {-1, 0}} . f[t], f[0] == {1., 0.}}, f, {t, 0, 1}];
{ArrayComputeNativeQ[v[tau]], ArrayComputeNativeQ[MatrixSymbol["M", {2, 3}]]}
```

<!-- => {False, False} -->

## Properties and Relations

A compute-native container runs arithmetic in place; a `QuantityArray` keeps its wrapper:

```wl
With[{qa = QuantityArray[{1., 2., 3.}, "Meters"]}, {Head[2 qa], QuantityMagnitude[2 qa]}]
```

<!-- => {QuantityArray, {2., 4., 6.}} -->

---

`Dot` on a `SparseArray` stays sparse:

```wl
With[{s = SparseArray[{{0, 1}, {2, 0}}]}, {Head[s . s], Normal[s . s]}]
```

<!-- => {SparseArray, {{2, 0}, {0, 2}}} -->

---

Arithmetic on a storage-only `NumericArray` goes inert instead of computing:

```wl
Head[2 NumericArray[{1., 2.}]]
```

<!-- => Times -->

---

Every compute-native container is explicit:

```wl
ArrayExplicitQ /@ {SparseArray[{1., 2.}], QuantityArray[{1., 2.}, "Meters"], TabularColumn[{1., 2.}]}
```

<!-- => {True, True, True} -->

---

Storage-only containers still materialize to explicit data:

```wl
ArrayMaterialize[NumericArray[{{1., 0.}, {0., 2.}}]]
```

<!-- => {{1., 0.}, {0., 2.}} -->

## Possible Issues

`EventSeries` threads elementwise scalar arithmetic natively, yet the flag is False because it has no native `Dot`:

```wl
With[{ev = EventSeries[{1., 2.}, {{0, 1}}]}, {Head[ev + 1], ArrayComputeNativeQ[ev]}]
```

<!-- => {EventSeries, False} -->
