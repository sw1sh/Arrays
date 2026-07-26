---
Template: Symbol
Name: ArrayExplicitPositions
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayExplicitPositions
Keywords: [sparse array, explicit positions, nonzero positions, array container]
SeeAlso: [ArrayExplicitValues, ArrayExplicitLength, ArrayMaterialize, ArrayExplicitQ, ArrayDimensions]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayExplicitPositions]()[*a*]</code> gives the positions of the explicitly stored values of a [SparseArray](), or the nonzero positions of any other explicit array container via an on-demand [SparseArray]() wrap; lazy and symbolic containers give <code>[Missing]()["NotExplicit"]</code>.

## Details & Options

- For a [SparseArray](), the positions are its native `"ExplicitPositions"` property, returned as a packed integer array without materializing the array.
- Any other explicit container is wrapped in a [SparseArray]() on demand, so its positions are the positions of its nonzero values in row-major order.
- Each position is a full index list of length <code>[ArrayRank]()[*a*]</code>.
- A [NumericArray]() converts through [Normal]() before the wrap, since [SparseArray]() cannot ingest a [NumericArray]() directly; wrapper containers such as [QuantityArray]() or [Tabular]() wrap their [ArrayMaterialize]() data.
- An array with a zero dimension gives `{}` directly, since [SparseArray]() cannot represent zero dimensions.
- Lazy and symbolic containers have no addressable stored values and give <code>[Missing]()["NotExplicit"]</code>.

## Basic Examples

The positions of the explicitly stored values of a sparse matrix:

```wl
ArrayExplicitPositions[SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => {{1, 2}, {2, 1}} -->

---

A dense list gives its nonzero positions via an on-demand sparse wrap:

```wl
ArrayExplicitPositions[{{0, 1}, {2, 0}}]
```

<!-- => {{1, 2}, {2, 1}} -->

## Scope

A [NumericArray]() converts through [Normal]() and reports its nonzero positions:

```wl
ArrayExplicitPositions[NumericArray[{{1., 0.}, {0., 2.}}]]
```

<!-- => {{1, 1}, {2, 2}} -->

---

An array with a zero dimension gives an empty position list:

```wl
ArrayExplicitPositions[{{}}]
```

<!-- => {} -->

## Properties and Relations

Together with [ArrayExplicitValues]() and [ArrayDimensions](), the positions rebuild the array:

```wl
With[{a = SparseArray[{{0, 1}, {2, 0}}]},
    SparseArray[Thread[Normal[ArrayExplicitPositions[a]] -> ArrayExplicitValues[a]], ArrayDimensions[a]] == a
]
```

<!-- => True -->

---

[ArrayExplicitLength]() counts the positions:

```wl
Length[ArrayExplicitPositions[{{0, 1}, {2, 0}}]] === ArrayExplicitLength[{{0, 1}, {2, 0}}]
```

<!-- => True -->

## Possible Issues

For a [SparseArray]() with a nonzero background, only the stored entries are reported, not every nonzero position:

```wl
ArrayExplicitPositions[SparseArray[{1 -> 4}, {3}, 1]]
```

<!-- => {{1}} -->

---

A symbolic container has no addressable stored values, so no position list is returned:

```wl
ArrayExplicitPositions[VectorSymbol["v", 3]]
```

<!-- => Missing["NotExplicit"] -->

---

An array-valued interpolating function is a lazy container when applied to a symbolic parameter:

```wl
f = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}]
```

<!-- => InterpolatingFunction[{{0., 1.}}, "<>"] summary box -->

Its elements exist only after the parameter is supplied, so the lazy container gives no position list either:

```wl
ArrayExplicitPositions[f[tau]]
```

<!-- => Missing["NotExplicit"] -->

---

For a [SparseArray]() the positions come back as a packed integer array rather than a plain list; apply [Normal]() where a plain list is required:

```wl
Developer`PackedArrayQ[ArrayExplicitPositions[SparseArray[{{0, 1}, {2, 0}}]]]
```

<!-- => True -->
