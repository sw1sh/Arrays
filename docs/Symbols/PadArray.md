---
Template: Symbol
Name: PadArray
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/PadArray
Keywords: [padding, array container, sparse array, numeric array]
SeeAlso: [ReshapeArray, ArrayVector, ArrayTranspose, ArrayDimensions, ArrayMaterialize, ArrayContainerQ]
RelatedGuides: [Arrays]
---

## Usage

<code>[PadArray]()[*a*, *spec*]</code> pads the array container *a* with zeros according to *spec*.

<code>[PadArray]()[*a*, *spec*, *padding*]</code> pads with the given *padding*.

## Details & Options

- [PadArray]() is the paclet's name for this operation: the natural name `ArrayPad` is a System symbol, and paclet exports must not shadow built-in names, so the word order is reversed.
- *spec* uses the [ArrayPad]() forms: an integer *n* pads with *n* elements on every side at every level, and <code>{{$m_1$, $n_1$}, …}</code> pads level $k$ with $m_k$ elements on the left and $n_k$ on the right.
- Explicit containers pad through [ArrayPad](), preserving the container where [ArrayPad]() does: a [SparseArray]() stays sparse, with the zero and explicit-padding forms alike.
- [ArrayPad]() does not support [NumericArray](), so a [NumericArray]() converts through [Normal]() and re-wraps, staying a [NumericArray]().
- [ArrayPad]() on a [QuantityArray]() would degrade to a mixed list of [Quantity]() elements and plain padding, so every wrapper container — [QuantityArray]() included — pads its materialized data instead, losing the wrapper.
- Lazy and symbolic containers are not padded; [PadArray]() stays unevaluated on them.

## Basic Examples

Pad a matrix with a border of zeros:

```wl
PadArray[{{1}}, 1]
```

<!-- => {{0, 0, 0}, {0, 1, 0}, {0, 0, 0}} -->

---

A [SparseArray]() stays sparse:

```wl
padded = PadArray[SparseArray[{{0, 1}, {2, 0}}], 1];
Head[padded]
```

<!-- => SparseArray -->

```wl
Normal[padded]
```

<!-- => {{0, 0, 0, 0}, {0, 0, 1, 0}, {0, 2, 0, 0}, {0, 0, 0, 0}} -->

## Scope

Pad asymmetrically per level:

```wl
PadArray[{1, 2}, {{2, 0}}]
```

<!-- => {0, 0, 1, 2} -->

---

Pad with an explicit padding element:

```wl
PadArray[{1, 2}, {{1, 1}}, x]
```

<!-- => {x, 1, 2, x} -->

---

A [SparseArray]() stays sparse with an explicit padding value too:

```wl
Normal[PadArray[SparseArray[{{0, 1}, {2, 0}}], 1, 5]]
```

<!-- => {{5, 5, 5, 5}, {5, 0, 1, 5}, {5, 2, 0, 5}, {5, 5, 5, 5}} -->

---

A [NumericArray]() converts through [Normal]() and re-wraps:

```wl
PadArray[NumericArray[{1., 2.}], {{0, 2}}]
```

<!-- => NumericArray summary box: Real64, dimensions {4}; Normal gives {1., 2., 0., 0.} -->

## Possible Issues

A [QuantityArray]() pads its materialized magnitudes, so the units are dropped from the result:

```wl
PadArray[QuantityArray[{1., 2.}, "Meters"], {{0, 1}}]
```

<!-- => {1., 2., 0} -->

---

Lazy and symbolic containers are not padded, so [PadArray]() stays unevaluated on them:

```wl
PadArray[MatrixSymbol["M", {2, 3}], 1]
```

<!-- => PadArray[MatrixSymbol["M", {2, 3}], 1] (unevaluated) -->
