---
Template: Symbol
Name: ReshapeArray
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ReshapeArray
Keywords: [reshape, dimensions, array container, lazy array, padding]
SeeAlso: [PadArray, ArrayVector, ArrayTranspose, ArrayDimensions, ArrayMaterialize, ArrayPack, ArrayContainerQ]
RelatedGuides: [Arrays]
---

## Usage

<code>[ReshapeArray]()[*a*, *dims*]</code> reshapes the array container *a* to the given dimensions.

<code>[ReshapeArray]()[*a*, *dims*, *pad*]</code> pads with *pad* when the reshape needs more elements.

## Details & Options

- [ReshapeArray]() is the paclet's name for this operation: the natural name `ArrayReshape` is a System symbol, and paclet exports must not shadow built-in names, so the word order is reversed.
- *dims* must be a list of non-negative integers.
- Explicit containers reshape through [ArrayReshape]() with its semantics: elements are taken in row-major order, excess elements are dropped, and missing elements are filled with 0 or with *pad*.
- The container is preserved wherever [ArrayReshape]() preserves it: a [SparseArray]() stays sparse, a packed array stays packed, a [NumericArray]() stays a [NumericArray](), and a [QuantityArray]() keeps its wrapper.
- The remaining wrapper containers ([Tabular](), [Dataset](), [EventSeries](), …) reshape their materialized data, losing the wrapper.
- A lazy parametric container — an array-valued [InterpolatingFunction]() applied to a symbolic parameter — reshapes the value array at every grid point and reinterpolates, so the result stays lazy.
- Symbolic containers are not reshaped; [ReshapeArray]() stays unevaluated on them.

## Basic Examples

Reshape a sparse matrix to a vector; the container is preserved:

```wl
reshaped = ReshapeArray[SparseArray[{{0, 1}, {2, 0}}], {4}];
Head[reshaped]
```

<!-- => SparseArray -->

The elements are taken in row-major order:

```wl
Normal[reshaped]
```

<!-- => {0, 1, 2, 0} -->

---

A third argument pads when the reshape needs more elements:

```wl
ReshapeArray[{1, 2, 3, 4}, {2, 3}, 0]
```

<!-- => {{1, 2, 3}, {4, 0, 0}} -->

## Scope

### Explicit containers

A packed array stays packed:

```wl
Developer`PackedArrayQ[ReshapeArray[Developer`ToPackedArray[N @ {1, 2, 3, 4}], {2, 2}]]
```

<!-- => True -->

---

A [NumericArray]() keeps its container:

```wl
ReshapeArray[NumericArray[{{1., 0.}, {0., 2.}}], {4}]
```

<!-- => NumericArray summary box: Real64, dimensions {4} -->

---

Excess elements are dropped:

```wl
ReshapeArray[Range[6], {2, 2}]
```

<!-- => {{1, 2}, {3, 4}} -->

---

The padding element can be symbolic:

```wl
ReshapeArray[{1, 2}, {4}, x]
```

<!-- => {1, 2, x, x} -->

### Wrapper containers

A [QuantityArray]() reshapes natively and keeps its wrapper:

```wl
Head[ReshapeArray[QuantityArray[{{1., 2.}, {3., 4.}}, "Meters"], {4}]]
```

<!-- => QuantityArray -->

---

A [Tabular]() reshapes its materialized data:

```wl
ReshapeArray[Tabular[{{1., 2.}, {3., 4.}}], {4}]
```

<!-- => {1., 2., 3., 4.} -->

### Lazy containers

An array-valued [InterpolatingFunction]() applied to a symbolic parameter reshapes its value grid and stays lazy:

```wl
if = NDSolveValue[{m'[t] == {{0, 1}, {-1, 0}} . m[t], m[0] == {{1., 0.}, {0., 1.}}}, m, {t, 0, 1}];
reshaped = ReshapeArray[if[tau], {4}];
ArrayLazyQ[reshaped]
```

<!-- => True -->

Substituting the parameter agrees with reshaping the evaluated array:

```wl
Max[Abs[(reshaped /. tau -> 0.5) - Flatten[if[0.5]]]] < 1*^-4
```

<!-- => True -->

## Possible Issues

Symbolic containers are not reshaped, so [ReshapeArray]() stays unevaluated on them:

```wl
ReshapeArray[MatrixSymbol["M", {2, 3}], {6}]
```

<!-- => ReshapeArray[MatrixSymbol["M", {2, 3}], {6}] (unevaluated) -->
