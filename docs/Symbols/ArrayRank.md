---
Template: Symbol
Name: ArrayRank
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayRank
Keywords: [array rank, tensor rank, array depth, array container]
SeeAlso: [ArrayDimensions, ZeroArrayQ, ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ, ArrayTranspose, ArrayContract]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayRank]()[*a*]</code> gives the number of dimensions of an array container of any tier without materializing it.

## Details & Options

- [ArrayRank]() is the length of <code>[ArrayDimensions]()[*a*]</code> and inherits all of its shape routes: explicit containers and wrappers introspect their shape metadata, a lazy <code>[InterpolatingFunction]()[...][*t*]</code> reads `"OutputDimensions"` off its head, and symbolic containers recurse structurally through [Transpose](), [Plus](), inactive [TensorProduct](), [TensorContract]() and inactive [D]() forms.
- The argument is never materialized: the rank of a large [SparseArray](), a lazy parametric array or a purely symbolic tensor costs only a shape probe.
- Scalars and non-array input, including ragged lists, give rank 0, since [ArrayDimensions]() gives `{}` for them.

## Basic Examples

A symbolic rank-3 tensor:

```wl
ArrayRank[ArraySymbol["T", {2, 3, 4}]]
```

<!-- => 3 -->

A sparse matrix has rank 2:

```wl
ArrayRank[SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => 2 -->

A scalar has rank 0:

```wl
ArrayRank[5]
```

<!-- => 0 -->

## Scope

A lazy array-valued interpolating function reports its rank without evaluating:

```wl
f = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}];
ArrayRank[f[tau]]
```

<!-- => 1 -->

---

Wrapper containers report the rank of their shape metadata:

```wl
ArrayRank[QuantityArray[{{1., 2.}, {3., 4.}}, "Meters"]]
```

<!-- => 2 -->

---

The rank of a symbolic structural tree follows the structure; an inactive tensor product adds the factor ranks:

```wl
ArrayRank[Inactive[TensorProduct][VectorSymbol["u", 2], MatrixSymbol["N", {3, 4}]]]
```

<!-- => 3 -->

---

A contraction removes two levels per index pair:

```wl
ArrayRank[TensorContract[ArraySymbol["S", {2, 3, 2}], {{1, 3}}]]
```

<!-- => 1 -->

---

Symbolic dimensions still count toward the rank:

```wl
ArrayRank[VectorSymbol["v", n]]
```

<!-- => 1 -->

## Properties and Relations

A symbolic matrix declares two dimensions:

```wl
ArrayDimensions[MatrixSymbol["M", {2, 3}]]
```

<!-- => {2, 3} -->

---

[ArrayRank]() is the length of that list:

```wl
ArrayRank[MatrixSymbol["M", {2, 3}]]
```

<!-- => 2 -->

## Possible Issues

Non-array input, including ragged lists, gives rank 0, indistinguishable from a scalar:

```wl
ArrayRank[{1, {2}}]
```

<!-- => 0 -->
