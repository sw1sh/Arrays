---
Template: Symbol
Name: ArrayExplicitLength
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayExplicitLength
Keywords: [sparse array, explicit length, nonzero count, array container]
SeeAlso: [ArrayExplicitValues, ArrayExplicitPositions, ArrayMaterialize, ArrayExplicitQ, ZeroArrayQ]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayExplicitLength]()[*a*]</code> gives the number of explicitly stored values of a [SparseArray](), or of nonzero values of any other explicit array container via an on-demand [SparseArray]() wrap; lazy and symbolic containers give <code>[Missing]()["NotExplicit"]</code>.

## Details & Options

- For a [SparseArray](), the count is its native `"ExplicitLength"` property, read off the internal representation without materializing the array.
- Any other explicit container is wrapped in a [SparseArray]() on demand, so the count is its number of nonzero values.
- A [NumericArray]() converts through [Normal]() before the wrap, since [SparseArray]() cannot ingest a [NumericArray]() directly; wrapper containers such as [QuantityArray]() or [Tabular]() wrap their [ArrayMaterialize]() data.
- An array with a zero dimension gives `0` directly, since [SparseArray]() cannot represent zero dimensions.
- Lazy and symbolic containers have no addressable stored values and give <code>[Missing]()["NotExplicit"]</code>.
- For a [SparseArray]() with a nonzero background, the count covers the stored entries only, not every nonzero entry.

## Basic Examples

The number of explicitly stored values of a sparse matrix:

```wl
ArrayExplicitLength[SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => 2 -->

A dense list counts its nonzero values via an on-demand sparse wrap:

```wl
ArrayExplicitLength[{{0, 1}, {2, 0}}]
```

<!-- => 2 -->

---

A symbolic container has no explicit values to count:

```wl
ArrayExplicitLength[ArraySymbol["T", {2, 3, 4}]]
```

<!-- => Missing["NotExplicit"] -->

## Scope

An array with a zero dimension gives 0:

```wl
ArrayExplicitLength[{{}}]
```

<!-- => 0 -->

---

An array-valued interpolating function is a lazy container when applied to a symbolic parameter:

```wl
f = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}]
```

<!-- => InterpolatingFunction[{{0., 1.}}, "<>"] summary box -->

A lazy container gives <code>[Missing]()["NotExplicit"]</code>:

```wl
ArrayExplicitLength[f[tau]]
```

<!-- => Missing["NotExplicit"] -->

## Properties and Relations

[ArrayExplicitLength]() counts the values of [ArrayExplicitValues]() and the positions of [ArrayExplicitPositions]():

```wl
ArrayExplicitLength[{{0, 1}, {2, 0}}] === Length[ArrayExplicitValues[{{0, 1}, {2, 0}}]]
```

<!-- => True -->
