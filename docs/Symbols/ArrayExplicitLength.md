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

---

A dense list counts its nonzero values via an on-demand sparse wrap:

```wl
ArrayExplicitLength[{{0, 1}, {2, 0}}]
```

<!-- => 2 -->

## Scope

An array with a zero dimension gives 0:

```wl
ArrayExplicitLength[{{}}]
```

<!-- => 0 -->

## Properties and Relations

The count reported for a matrix with two nonzero entries:

```wl
ArrayExplicitLength[{{0, 1}, {2, 0}}]
```

<!-- => 2 -->

---

Taking [Length]() of the [ArrayExplicitValues]() list arrives at the same count:

```wl
Length[ArrayExplicitValues[{{0, 1}, {2, 0}}]]
```

<!-- => 2 -->

## Possible Issues

A symbolic container has no addressable stored values, so there is nothing to count:

```wl
ArrayExplicitLength[ArraySymbol["T", {2, 3, 4}]]
```

<!-- => Missing["NotExplicit"] -->

---

An array-valued interpolating function is a lazy container when applied to a symbolic parameter:

```wl
f = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}]
```

<!-- => InterpolatingFunction[{{0., 1.}}, "<>"] summary box -->

Its elements exist only after the parameter is supplied, so the lazy container gives no count either:

```wl
ArrayExplicitLength[f[tau]]
```

<!-- => Missing["NotExplicit"] -->
