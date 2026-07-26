---
Template: Symbol
Name: ArrayVector
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayVector
Keywords: [flatten, vectorize, sparse array, CSR, array container]
SeeAlso: [ReshapeArray, PadArray, ArrayMaterialize, ArrayPack, ArrayDimensions, ArrayRank]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayVector]()[*a*]</code> flattens an explicit array container to a vector; a lazy container flattens its value grid and stays lazy, and scalar numeric input passes through unchanged.

## Details & Options

- Explicit containers flatten via [Flatten](), preserving the container where [Flatten]() does: a [SparseArray]() stays a [SparseArray](), a packed array stays packed, a [NumericArray]() stays a [NumericArray](), and a [QuantityArray]() or structured array keeps its wrapper.
- A [SparseArray]() of rank above 11 flattens through a raw CSR construction instead; the result is the same rank-1 [SparseArray]().
- Storage wrappers without a native [Flatten]() ([Tabular](), [Dataset](), [ByteArray](), [EventSeries](), [DataStructure]() stores) flatten their [ArrayMaterialize]() data.
- A lazy array-valued [InterpolatingFunction]() application of rank 1 is returned as-is; at higher rank the value grid is flattened and reinterpolated, so the container stays lazy.
- Scalar numeric input passes through unchanged, so [ArrayVector]() can be applied uniformly to rank-0 data.

## Basic Examples

<!-- #| annotation: 26.07.26: Design review - The rank>11 SparseArray path builds the rank-1 result from a raw CSR construction because Flatten's performance degrades badly at those ranks; both routes give the same rank-1 SparseArray, verified in Scope. -->

Flatten a matrix to a vector:

```wl
ArrayVector[{{1, 2}, {3, 4}}]
```

<!-- => {1, 2, 3, 4} -->

---

A [SparseArray]() stays sparse:

```wl
ArrayVector[SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => SparseArray summary box: rank-1, 2 stored elements; Normal is {0, 1, 2, 0} -->

---

A machine number passes through unchanged:

```wl
ArrayVector[3.5]
```

<!-- => 3.5 -->

---

An exact numeric constant passes through unchanged as well:

```wl
ArrayVector[Pi]
```

<!-- => Pi -->

## Scope

A [NumericArray]() keeps its container:

```wl
ArrayVector[NumericArray[{{1., 0.}, {0., 2.}}]]
```

<!-- => NumericArray summary box; Normal is {1., 0., 0., 2.} -->

---

A [QuantityArray]() flattens natively and keeps its wrapper:

```wl
ArrayVector[QuantityArray[{{1., 2.}, {3., 4.}}, "Meters"]]
```

<!-- => a QuantityArray summary box: dimensions {4}, unit "Meters"; magnitudes are {1., 2., 3., 4.} -->

---

A storage wrapper such as a named [Tabular]() flattens its materialized data:

```wl
ArrayVector[Tabular[{{1., 2.}, {3., 4.}}, {"a", "b"}]]
```

<!-- => {1., 2., 3., 4.} -->

---

A rank-12 [SparseArray]() takes the raw CSR path and comes back as a rank-1 [SparseArray]():

```wl
sa = SparseArray[{ConstantArray[1, 12] -> 2., ConstantArray[2, 12] -> 3.}, ConstantArray[2, 12]];
ArrayVector[sa]
```

<!-- => a SparseArray summary box: rank-1, dimensions {4096}, 2 stored elements -->

---

Its length is the product of the original dimensions:

```wl
ArrayDimensions[ArrayVector[sa]]
```

<!-- => {4096} -->

---

The raw CSR route agrees with [Flatten]():

```wl
ArrayVector[sa] == Flatten[sa]
```

<!-- => True -->

---

An array-valued interpolating function applied to a symbolic parameter is a lazy container:

```wl
fM = NDSolveValue[{m'[t] == {{0, 1}, {-1, 0}} . m[t], m[0] == {{1., 0.}, {0., 1.}}}, m, {t, 0, 1}]
```

<!-- => InterpolatingFunction[{{0., 1.}}, "<>"] summary box -->

Flattening reinterpolates the value grid, so the container stays lazy:

```wl
flat = ArrayVector[fM[tau]];
ArrayLazyQ[flat]
```

<!-- => True -->

---

The flattened container has rank 1:

```wl
ArrayDimensions[flat]
```

<!-- => {4} -->

Substituting the parameter matches flattening the original application:

```wl
Max[Abs[(flat /. tau -> 0.5) - Flatten[fM[0.5]]]] < 1*^-4
```

<!-- => True -->

## Properties and Relations

For an explicit container, [ArrayVector]() agrees with [Flatten]() of the [ArrayMaterialize]() data:

```wl
ArrayVector[SparseArray[{{0, 1}, {2, 0}}]] == Flatten[ArrayMaterialize[SparseArray[{{0, 1}, {2, 0}}]]]
```

<!-- => True -->

---

The result has length <code>[Times]() @@ [ArrayDimensions]()[*a*]</code> and rank 1:

```wl
ArrayDimensions[ArrayVector[{{1, 2}, {3, 4}}]]
```

<!-- => {4} -->
