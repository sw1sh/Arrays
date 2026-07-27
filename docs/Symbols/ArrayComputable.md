---
Template: Symbol
Name: ArrayComputable
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayComputable
Keywords: [array container, materialize, native arithmetic, storage-only container]
SeeAlso: [ArrayComputeNativeQ, ArrayMaterialize, ArrayPack, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayComputable]()[*a*]</code> gives a form of an array container that the kernel computes with directly, materializing only the containers that arithmetic does not traverse.

## Details & Options

- A container satisfying [ArrayComputeNativeQ]() is returned unchanged, so a [SparseArray]() keeps its sparsity and a packed array keeps its packing.
- Any other explicit container is materialized through [ArrayMaterialize](), because [Dot](), [Norm](), [KroneckerProduct]() and [Eigensystem]() do not traverse a storage-only container such as a [NumericArray]().
- A lazy container materializes to its per-scalar expansion, an ordinary array of expressions in its parameters, which computes; binding the parameters first with [ArrayReplaceAll]() is cheaper, since it evaluates the underlying function once for the whole array rather than once per element.
- A leafless symbolic container is returned unchanged, because [ArrayMaterialize]() returns one unchanged: it has no elements to compute with.
- [ArrayComputable]() differs from [ArrayMaterialize]() only on compute-native input, which it returns untouched where [ArrayMaterialize]() would discard sparsity and packing.

## Basic Examples

<!-- #| annotation: 27.07.26: Design review - This is the least conversion that makes native arithmetic work, which is why it is a separate function from ArrayMaterialize rather than a guarded call to it: materializing unconditionally would densify every SparseArray at the point where a consumer only wanted to be able to call Dot. A lazy container does materialize, since its per-scalar expansion computes; a caller holding one is usually better off binding parameters with ArrayReplaceAll, which evaluates the whole array once. -->

A [SparseArray]() computes natively and is returned unchanged, sparsity intact:

```wl
ArrayComputable[SparseArray[{1 -> 1, 5 -> 2}, 10]]
```

<!-- => SparseArray[<2>, {10}] -->

---

A [NumericArray]() stores its data but does not traverse it, so it materializes:

```wl
ArrayComputable[NumericArray[{1, 2, 3}, "Integer64"]]
```

<!-- => {1, 2, 3} -->

## Scope

A packed list is already computable and keeps its packing:

```wl
ArrayComputable[Developer`ToPackedArray[{1., 2., 3.}]]
```

<!-- => {1., 2., 3.} (packed Real array) -->

---

A [QuantityArray]() computes natively, so its units survive:

```wl
ArrayComputable[QuantityArray[{1, 2, 3}, "Meters"]]
```

<!-- => QuantityArray[<3>, "Meters"] -->

---

A [ByteArray]() is storage only and materializes to a list of integers:

```wl
ArrayComputable[ByteArray[{1, 2, 3}]]
```

<!-- => {1, 2, 3} -->

---

A structured array is an atom that arithmetic does not penetrate, so it materializes to a dense array:

```wl
ArrayComputable[SymmetrizedArray[{{1, 2} -> 5}, {2, 2}, Symmetric[{1, 2}]]]
```

<!-- => {{0, 5}, {5, 0}} -->

---

An [ArrayObject]() applies the conversion to the container it holds and gives back a raw container, as [ArrayMaterialize]() and [ArrayCoerce]() do:

```wl
ArrayComputable[ArrayObject[NumericArray[{1, 2, 3}, "Integer64"]]]
```

<!-- => {1, 2, 3} -->

---

A lazy container materializes to its per-scalar expansion, which is an ordinary array of expressions:

```wl
ArrayComputable[Function[{t}, {t, 2 t}]]
```

<!-- => {Function[{t}, t], Function[{t}, 2 t]} -->

## Possible Issues

Materializing a lazy container expands it element by element; a caller that intends to bind the parameters anyway should use [ArrayReplaceAll]() instead, which evaluates the underlying function once for the whole array:

```wl
ArrayReplaceAll[Function[{t}, {t, 2 t}], {t -> 3}]
```

<!-- => {3, 6} -->

---

A symbolic container is returned unchanged; there are no elements to compute with:

```wl
ArrayComputable[MatrixSymbol["M", {2, 3}]]
```

<!-- => MatrixSymbol["M", {2, 3}] -->

---

Input that is not an array container at all passes through, so a caller that needs an array must test with [ArrayContainerQ]() first:

```wl
ArrayComputable["not an array"]
```

<!-- => "not an array" -->
