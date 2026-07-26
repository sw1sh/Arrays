---
Template: Symbol
Name: ArrayDimensions
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayDimensions
Keywords: [array dimensions, tensor shape, shape introspection, array container]
SeeAlso: [ArrayRank, ZeroArrayQ, ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ, ArrayMaterialize, ArrayPart, ReshapeArray, ArrayObject]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayDimensions]()[*a*]</code> gives the dimensions of an array container of any tier without materializing it.

## Details & Options

- [ArrayDimensions]() never materializes its argument: every container tier has a shape route that introspects the container directly.
- Explicit containers ([SparseArray](), packed and plain [List]() arrays, structured arrays such as [SymmetrizedArray]()) use the standard tensor-dimension probe; [NumericArray]() and the wrapper containers [QuantityArray](), [TabularColumn](), [Tabular](), [Dataset](), [ByteArray](), [EventSeries]() and [DataStructure]() array stores introspect their shape metadata.
- An [EventSeries]() reports the dimensions of its values, so a scalar-valued series of length $n$ gives $\{n\}$, not $\{n, 1\}$; a [DataStructure]() store is rank 1 and gives its length.
- A lazy container, an array-valued <code>[InterpolatingFunction]()[...][*t*]</code> with a symbolic parameter, reads the `"OutputDimensions"` property off the head without evaluating the interpolation.
- Symbolic containers give their declared dimensions: the second argument of [VectorSymbol](), [MatrixSymbol]() or [ArraySymbol](), or the dimensions registered for an atomic symbol in `$Assumptions` via [Vectors](), [Matrices]() or [Arrays]() domains.
- [ArrayDimensions]() recurses structurally through symbolic trees: <code>[Transpose]()[*t*, *perm*]</code> permutes (or rotates, for an integer, or swaps, for a two-way rule) the dimensions of *t*; <code>[Plus]()</code> keeps the common leading dimensions of its terms; <code>[Inactive]()[[TensorProduct]()]</code> concatenates dimensions; [TensorContract]() deletes the contracted pairs; <code>[Inactive]()[[D]()][*t*, {*params*, *n*}]</code> appends *n* copies of the parameter count.
- Non-array input, including ragged lists, quietly gives `{}`; no messages leak from the shape probe.
- A rank-0 scalar also gives `{}`.

## Basic Examples

Get the dimensions of a large sparse array without touching its elements:

```wl
ArrayDimensions[SparseArray[{{1, 2} -> 1.}, {100, 100}]]
```

<!-- => {100, 100} -->

A symbolic matrix reports its declared dimensions:

```wl
ArrayDimensions[MatrixSymbol["M", {2, 3}]]
```

<!-- => {2, 3} -->

A lazy array-valued interpolating function reports its output dimensions without evaluating:

```wl
f = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}];
ArrayDimensions[f[tau]]
```

<!-- => {2} -->

## Scope

### Explicit containers

A [NumericArray]() introspects its dimensions directly:

```wl
ArrayDimensions[NumericArray[{{1., 0.}, {0., 2.}}]]
```

<!-- => {2, 2} -->

---

A structured array such as [SymmetrizedArray]() reports its shape without densifying:

```wl
ArrayDimensions[SymmetrizedArray[{{1, 2} -> 3.}, {2, 2}, Antisymmetric[{1, 2}]]]
```

<!-- => {2, 2} -->

---

Wrapper containers introspect their shape metadata; a [QuantityArray]() of magnitudes with units:

```wl
ArrayDimensions[QuantityArray[{{1., 2.}, {3., 4.}}, "Meters"]]
```

<!-- => {2, 2} -->

---

A [Tabular]() reports rows and columns:

```wl
ArrayDimensions[Tabular[{{1., 2.}, {3., 4.}, {5., 6.}}, {"a", "b"}]]
```

<!-- => {3, 2} -->

---

A [ByteArray]() is a rank-1 container:

```wl
ArrayDimensions[ByteArray[{1, 2, 3, 255}]]
```

<!-- => {4} -->

---

An [EventSeries]() reports the dimensions of its values:

```wl
ArrayDimensions[EventSeries[{{1., 2.}, {3., 4.}, {5., 6.}}, {{0, 1, 2}}]]
```

<!-- => {3, 2} -->

---

A [DataStructure]() array store gives its length:

```wl
ArrayDimensions[CreateDataStructure["DynamicArray", {1., 2., 3.}]]
```

<!-- => {3} -->

### Symbolic containers

An atomic symbol registered in `$Assumptions` gives its registered dimensions:

```wl
$Assumptions = {Element[symA, Matrices[{2, 2}]]};
ArrayDimensions[symA]
```

<!-- => {2, 2} -->

---

Symbolic dimensions pass through unevaluated:

```wl
ArrayDimensions[VectorSymbol["v", n]]
```

<!-- => {n} -->

### Structural recursion

[Transpose]() with a permutation permutes the dimensions:

```wl
ArrayDimensions[Transpose[ArraySymbol["T", {2, 3, 4}], {2, 3, 1}]]
```

<!-- => {4, 2, 3} -->

---

An integer transpose specification rotates the dimensions:

```wl
ArrayDimensions[Transpose[ArraySymbol["T", {2, 3, 4}], 2]]
```

<!-- => {3, 4, 2} -->

---

A two-way rule swaps a pair of levels:

```wl
ArrayDimensions[Transpose[ArraySymbol["T", {2, 3, 4}], 1 <-> 3]]
```

<!-- => {4, 3, 2} -->

---

A sum of symbolic arrays keeps the common dimensions:

```wl
ArrayDimensions[MatrixSymbol["A", {2, 3}] + MatrixSymbol["B", {2, 3}]]
```

<!-- => {2, 3} -->

---

An inactive tensor product concatenates the factor dimensions:

```wl
ArrayDimensions[Inactive[TensorProduct][VectorSymbol["u", 2], MatrixSymbol["N", {3, 4}]]]
```

<!-- => {2, 3, 4} -->

---

A tensor contraction deletes the contracted levels:

```wl
ArrayDimensions[TensorContract[ArraySymbol["S", {2, 3, 2}], {{1, 3}}]]
```

<!-- => {3} -->

---

An inactive gradient with respect to a parameter list appends the parameter count:

```wl
ArrayDimensions[Inactive[D][VectorSymbol["v", 3], {{p1, p2}}]]
```

<!-- => {3, 2} -->

---

A second-order derivative appends it twice:

```wl
ArrayDimensions[Inactive[D][VectorSymbol["v", 3], {{p1, p2}, 2}]]
```

<!-- => {3, 2, 2} -->

## Properties and Relations

A rank-3 symbolic tensor has three dimensions:

```wl
ArrayDimensions[ArraySymbol["T", {2, 3, 4}]]
```

<!-- => {2, 3, 4} -->

---

[ArrayRank]() is the length of that list:

```wl
ArrayRank[ArraySymbol["T", {2, 3, 4}]]
```

<!-- => 3 -->

---

A degenerate [SparseArray]() reports a dimension of 0:

```wl
ArrayDimensions[SparseArray[{}, {2, 0}]]
```

<!-- => {2, 0} -->

---

[ZeroArrayQ]() tests whether any dimension is 0:

```wl
ZeroArrayQ[SparseArray[{}, {2, 0}]]
```

<!-- => True -->

## Possible Issues

Ragged input gives `{}` quietly, with no message:

```wl
ArrayDimensions[{1, {2}}]
```

<!-- => {} -->

---

A scalar is rank 0 and also gives `{}`:

```wl
ArrayDimensions[7]
```

<!-- => {} -->

---

An [Association]() is not an admitted container, since its shape reports the entry multiset rather than the represented vector; it gives `{}`:

```wl
ArrayDimensions[<|1 -> 1.5, 2 -> 2.5|>]
```

<!-- => {} -->
