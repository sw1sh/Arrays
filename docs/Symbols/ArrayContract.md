---
Template: Symbol
Name: ArrayContract
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayContract
Keywords: [tensor contraction, trace, tensor product, array container, symbolic array]
SeeAlso: [ArrayTranspose, ArrayPart, SimplifyArray, ArrayDimensions, ArrayMaterialize, ArraySymbolicQ, ArrayContainerQ]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayContract]()[*a*, *pairs*]</code> contracts the given index *pairs* of the array container *a*.

<code>[ArrayContract]()[{$a_1$, $a_2$, ...}, *pairs*]</code> contracts index pairs of the inactive tensor product of the containers $a_i$.

## Details & Options

- *pairs* is a list of level pairs <code>{{$s_1$, $t_1$}, ...}</code>, as in [TensorContract]().
- Explicit compute-native containers contract through [TensorContract](), which evaluates immediately: contracting the two levels of a matrix gives its trace.
- [TensorContract]() preserves [SymmetrizedArray]() structure natively, so contracting a structured atom stays a [SymmetrizedArray]().
- [TensorContract]() does not evaluate on the wrapper heads, so wrapper containers, [QuantityArray]() included, contract their materialized data instead of returning an inert wrapper.
- Symbolic containers stay in inactive [TensorContract]() form; [ArrayDimensions]() reads the contracted shape off the wrapper without materializing.
- In the list form, the containers are combined as an inactive [TensorProduct]() and the *pairs* index the concatenated levels; a plain [List]() that is itself an array is instead treated as a single array, matching its [SparseArray]() form.
- An empty contraction <code>{}</code> gives *a* itself, via [SimplifyArray]().
- If any dimension of *a* is 0, the result is the empty array `{}`.

## Basic Examples

Contracting the two levels of a matrix gives its trace:

```wl
ArrayContract[SparseArray[{{1, 2}, {3, 4}}], {{1, 2}}]
```

<!-- => 5 -->

---

A symbolic container stays in inactive [TensorContract]() form:

```wl
contraction = ArrayContract[ArraySymbol["S", {2, 3, 2}], {{1, 3}}]
```

<!-- => TensorContract[ArraySymbol["S", {2, 3, 2}], {{1, 3}}] -->

The contracted shape reads off the wrapper:

```wl
ArrayDimensions[contraction]
```

<!-- => {3} -->

---

A list of containers contracts their inactive tensor product; contracting the two levels of two vectors is their inner product:

```wl
ArrayContract[{VectorSymbol["u", 2], VectorSymbol["w", 2]}, {{1, 2}}]
```

<!-- => TensorContract[Inactive[TensorProduct][VectorSymbol["u", 2], VectorSymbol["w", 2]], {{1, 2}}] -->

## Scope

### Explicit containers

A plain nested-list matrix is a single array and contracts the same way as its [SparseArray]() form:

```wl
ArrayContract[{{1, 2}, {3, 4}}, {{1, 2}}]
```

<!-- => 5 -->

---

Contracting a [SymmetrizedArray]() keeps the structured atom:

```wl
contracted = ArrayContract[SymmetrizedArray[{{1, 2, 1, 2} -> 1.}, {2, 2, 2, 2}, Symmetric[{1, 2}]], {{1, 3}}]
```

<!-- => a SymmetrizedArray summary box: dimensions {2, 2}, no residual symmetry, 1 rule -->

The contracted elements are those of the dense computation:

```wl
Normal[contracted]
```

<!-- => {{0, 0}, {0, 1.}} -->

### Wrapper containers

A wrapper container contracts its materialized data; for a [QuantityArray]() that is the magnitude array:

```wl
ArrayContract[QuantityArray[{{1., 2.}, {3., 4.}}, "Meters"], {{1, 2}}]
```

<!-- => 5. -->

### Symbolic containers

A mixed list of explicit and symbolic containers builds an inactive tensor product, with the pairs indexing the concatenated levels:

```wl
ArrayContract[{SparseArray[{{1, 0}, {0, 1}}], VectorSymbol["u", 2]}, {{1, 3}}]
```

<!-- => TensorContract[Inactive[TensorProduct][SparseArray[...], VectorSymbol["u", 2]], {{1, 3}}] -->

---

An empty contraction gives the container itself:

```wl
ArrayContract[MatrixSymbol["M", {2, 3}], {}]
```

<!-- => MatrixSymbol["M", {2, 3}] -->

## Properties and Relations

Contracting both levels of an explicit container takes its trace:

```wl
ArrayContract[SparseArray[{{1, 2}, {3, 4}}], {{1, 2}}]
```

<!-- => 5 -->

---

[TensorContract]() on the dense form gives that same value:

```wl
TensorContract[{{1, 2}, {3, 4}}, {{1, 2}}]
```

<!-- => 5 -->

---

A tensor product with a zero-dimensional factor contracts to the empty array:

```wl
ArrayContract[Inactive[TensorProduct][{}, {1, 2}], {{1, 2}}]
```

<!-- => {} -->

## Possible Issues

Contracting a [QuantityArray]() works on the materialized magnitudes, so the units are dropped from the result:

```wl
ArrayContract[QuantityArray[{{1., 2.}, {3., 4.}}, "Meters"], {{1, 2}}]
```

<!-- => 5. (not Quantity[5., "Meters"]) -->

---

A plain nested-list matrix is treated as one array, not as a list of vector containers; to contract two explicit vectors as a tensor product, pass them as non-[List]() containers such as [SparseArray]()s:

```wl
ArrayContract[{SparseArray[{1., 2.}], SparseArray[{3., 4.}]}, {{1, 2}}]
```

<!-- => 11. -->
