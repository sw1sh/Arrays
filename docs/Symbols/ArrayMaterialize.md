---
Template: Symbol
Name: ArrayMaterialize
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayMaterialize
Keywords: [materialize, normal form, wrapper container, quantity magnitude, lazy expansion]
SeeAlso: [ArrayPack, ArrayExplicitValues, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ, ArrayComputeNativeQ, ArrayReplaceAll]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayMaterialize]()[*a*]</code> gives an explicit array of scalar expressions for any array container: [Normal]() for explicit containers with wrapper-specific routes, per-scalar expansion for lazy containers, and the input itself for symbolic containers.

## Details & Options

- Explicit containers such as [SparseArray](), [NumericArray]() and structured arrays materialize via [Normal]().
- A [QuantityArray]() materializes via [QuantityMagnitude](), which hands back the internal packed magnitudes essentially for free; [Normal]() would instead build an unpacked array of [Quantity]() expressions, orders of magnitude slower. Units are container metadata, recoverable for a rebuild from <code>*a*["UnitBlock"]</code>.
- A named [Tabular]() materializes per column, since [Normal]() on a named [Tabular]() yields a list of row [Association]()s: each column materializes via [Normal]() to a packed vector and the columns recombine by [Transpose](). An anonymous all-numeric [Tabular]() already converts to a packed matrix via [Normal]().
- An [EventSeries]() materializes as [Normal]() of its `"Values"` column, since the raw `"Values"` property returns a [TabularColumn]()-backed view rather than a plain list. The time index is separate metadata, recoverable for a rebuild from <code>*a*["Times"]</code>.
- A [DataStructure]() array store (`"DynamicArray"` or `"FixedArray"`) materializes as an immediate packed snapshot of its elements: the handles have reference semantics, with copies aliasing the same store, so the snapshot is immune to later mutation of the source handle.
- A lazy array-valued [InterpolatingFunction]() application expands per scalar: each component becomes its own scalar interpolating function applied to the parameter.
- A symbolic container has no elements to materialize and gives the input itself.

## Basic Examples

Materialize a sparse matrix:

```wl
ArrayMaterialize[SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => {{0, 1}, {2, 0}} -->

---

A [QuantityArray]() materializes its packed magnitudes:

```wl
ArrayMaterialize[QuantityArray[{{1., 2.}, {3., 4.}}, "Meters"]]
```

<!-- => {{1., 2.}, {3., 4.}} -->

---

A symbolic container materializes to itself:

```wl
ArrayMaterialize[MatrixSymbol["M", {2, 3}]]
```

<!-- => MatrixSymbol["M", {2, 3}] -->

## Scope

A [NumericArray]() materializes via [Normal]():

```wl
ArrayMaterialize[NumericArray[{{1., 0.}, {0., 2.}}]]
```

<!-- => {{1., 0.}, {0., 2.}} -->

---

A structured array expands to its full element grid:

```wl
ArrayMaterialize[SymmetrizedArray[{{1, 2} -> 3.}, {2, 2}, Antisymmetric[{1, 2}]]]
```

<!-- => {{0, 3.}, {-3., 0}} -->

---

A named [Tabular]() materializes to a matrix on the per-column route:

```wl
ArrayMaterialize[Tabular[{{1., 2.}, {3., 4.}, {5., 6.}}, {"a", "b"}]]
```

<!-- => {{1., 2.}, {3., 4.}, {5., 6.}} -->

---

An [EventSeries]() materializes its values, dropping the time index:

```wl
ArrayMaterialize[EventSeries[{{1., 2.}, {3., 4.}, {5., 6.}}, {{0, 1, 2}}]]
```

<!-- => {{1., 2.}, {3., 4.}, {5., 6.}} -->

---

A [ByteArray]() materializes to an integer vector:

```wl
ArrayMaterialize[ByteArray[{1, 2, 3, 255}]]
```

<!-- => {1, 2, 3, 255} -->

---

A [DataStructure]() array store materializes as a packed snapshot of its elements:

```wl
ds = CreateDataStructure["DynamicArray", {1., 2., 3.}];
ArrayMaterialize[ds]
```

<!-- => {1., 2., 3.} -->

---

An array-valued interpolating function applied to a symbolic parameter is a lazy container:

```wl
f = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}]
```

<!-- => InterpolatingFunction[{{0., 1.}}, "<>"] summary box -->

It materializes per scalar, each component becoming its own scalar interpolation applied to the parameter:

```wl
expansion = ArrayMaterialize[f[tau]]
```

<!-- => {InterpolatingFunction[{{0., 1.}}, <>][tau], InterpolatingFunction[{{0., 1.}}, <>][tau]} -->

Substituting the parameter recovers the values of the original application:

```wl
Max[Abs[(expansion /. tau -> 0.5) - f[0.5]]] < 1*^-4
```

<!-- => True -->

## Properties and Relations

The `"UnitBlock"` metadata rebuilds a [QuantityArray]() around transformed magnitudes:

```wl
With[{qa = QuantityArray[{{1., 2.}, {3., 4.}}, "Seconds"]},
    QuantityMagnitude[QuantityArray[2 ArrayMaterialize[qa], qa["UnitBlock"]]]
]
```

<!-- => {{2., 4.}, {6., 8.}} -->

---

[ArrayPack]() packs the materialized data of a wrapper container:

```wl
ArrayPack[QuantityArray[{1, 2, 3}, "Meters"]]
```

<!-- => {1, 2, 3} (packed) -->

## Possible Issues

[Normal]() on a [QuantityArray]() builds an unpacked array of [Quantity]() expressions, not the magnitudes [ArrayMaterialize]() returns:

```wl
Normal[QuantityArray[{1., 2.}, "Meters"]]
```

<!-- => {Quantity[1., "Meters"], Quantity[2., "Meters"]} -->

---

[Normal]() on a named [Tabular]() gives a list of row associations, not a matrix:

```wl
Normal[Tabular[{{1., 2.}, {3., 4.}}, {"a", "b"}]]
```

<!-- => {<|"a" -> 1., "b" -> 2.|>, <|"a" -> 3., "b" -> 4.|>} -->

---

[DataStructure]() handles alias the same store, so the materialized snapshot is deliberately decoupled: mutating the source afterwards does not change it:

```wl
Module[{ds = CreateDataStructure["DynamicArray", {1., 2., 3.}], snapshot},
    snapshot = ArrayMaterialize[ds];
    ds["Append", 4.];
    {snapshot, ds["Elements"]}
]
```

<!-- => {{1., 2., 3.}, {1., 2., 3., 4.}} -->
