---
Template: Symbol
Name: ArrayExplicitValues
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayExplicitValues
Keywords: [sparse array, explicit values, nonzero values, array container]
SeeAlso: [ArrayExplicitPositions, ArrayExplicitLength, ArrayMaterialize, ArrayExplicitQ, ArrayNumericQ, ArrayAllZeroQ]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayExplicitValues]()[*a*]</code> gives the explicitly stored values of a [SparseArray](), or the nonzero values of any other explicit array container via an on-demand [SparseArray]() wrap; lazy and symbolic containers give <code>[Missing]()["NotExplicit"]</code>.

## Details & Options

- For a [SparseArray](), the values are its native `"ExplicitValues"` property, read off the internal representation without materializing the array.
- Any other explicit container is wrapped in a [SparseArray]() on demand, so its values are the nonzero values in row-major order.
- A [NumericArray]() converts through [Normal]() before the wrap, since [SparseArray]() cannot ingest a [NumericArray]() directly.
- A wrapper container such as [QuantityArray]() or [Tabular]() wraps its [ArrayMaterialize]() data; for a [QuantityArray]() the values are therefore nonzero magnitudes, not [Quantity]() expressions.
- An array with a zero dimension gives `{}` directly, since [SparseArray]() cannot represent zero dimensions.
- Lazy and symbolic containers have no addressable stored values and give <code>[Missing]()["NotExplicit"]</code>.

## Basic Examples

The explicitly stored values of a sparse matrix:

```wl
ArrayExplicitValues[SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => {1, 2} -->

A dense list gives its nonzero values via an on-demand sparse wrap:

```wl
ArrayExplicitValues[{{0, 1}, {2, 0}}]
```

<!-- => {1, 2} -->

---

A symbolic container has no explicit values:

```wl
ArrayExplicitValues[MatrixSymbol["M", {2, 3}]]
```

<!-- => Missing["NotExplicit"] -->

## Scope

A [NumericArray]() converts through [Normal]() and reports its nonzero values:

```wl
ArrayExplicitValues[NumericArray[{{1., 0.}, {0., 2.}}]]
```

<!-- => {1., 2.} -->

---

A structured array such as an antisymmetric [SymmetrizedArray]() includes the values implied by its symmetry:

```wl
ArrayExplicitValues[SymmetrizedArray[{{1, 2} -> 3.}, {2, 2}, Antisymmetric[{1, 2}]]]
```

<!-- => {3., -3.} -->

---

A [QuantityArray]() gives its nonzero magnitudes:

```wl
ArrayExplicitValues[QuantityArray[{0., 1.5, 0., 2.5}, "Meters"]]
```

<!-- => {1.5, 2.5} -->

---

An array with a zero dimension gives an empty value list:

```wl
ArrayExplicitValues[{{}}]
```

<!-- => {} -->

---

An array-valued interpolating function is a lazy container when applied to a symbolic parameter:

```wl
f = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}]
```

<!-- => InterpolatingFunction[{{0., 1.}}, "<>"] summary box -->

A lazy container gives <code>[Missing]()["NotExplicit"]</code>:

```wl
ArrayExplicitValues[f[tau]]
```

<!-- => Missing["NotExplicit"] -->

## Properties and Relations

[ArrayExplicitLength]() counts the values [ArrayExplicitValues]() returns:

```wl
ArrayExplicitLength[{{0, 1}, {2, 0}}] === Length[ArrayExplicitValues[{{0, 1}, {2, 0}}]]
```

<!-- => True -->

---

Together with [ArrayExplicitPositions]() and [ArrayDimensions](), the values rebuild the array:

```wl
With[{a = SparseArray[{{0, 1}, {2, 0}}]},
    SparseArray[Thread[Normal[ArrayExplicitPositions[a]] -> ArrayExplicitValues[a]], ArrayDimensions[a]] == a
]
```

<!-- => True -->

## Possible Issues

For a [SparseArray]() with a nonzero background, the stored values are not all of the nonzero entries:

```wl
ArrayExplicitValues[SparseArray[{1 -> 4}, {3}, 1]]
```

<!-- => {4} -->

The background occupies the remaining positions:

```wl
Normal[SparseArray[{1 -> 4}, {3}, 1]]
```

<!-- => {4, 1, 1} -->
