---
Template: Symbol
Name: ArrayTranspose
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayTranspose
Keywords: [transpose, permutation, array container, lazy array, symbolic array]
SeeAlso: [ArrayContract, ArrayPart, ArrayConjugate, ReshapeArray, ArrayVector, SimplifyArray, ArrayDimensions, ArrayMaterialize, ArrayContainerQ]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayTranspose]()[*a*, *perm*]</code> transposes the array container *a* by the permutation *perm*.

## Details & Options

- *a* can be an array container of any tier: explicit, lazy parametric, or symbolic.
- *perm* can be a permutation list, a [Cycles]() specification, or a two-way rule $m \leftrightarrow n$ exchanging two levels; a two-way rule is converted to the corresponding [Cycles]() form before transposing.
- Explicit containers with a native [Transpose]() keep their container: [SparseArray](), packed arrays, [NumericArray](), structured arrays such as [SymmetrizedArray](), and [QuantityArray]() all transpose without materializing.
- The remaining wrapper containers ([Tabular](), [Dataset](), [EventSeries](), ...) have no native [Transpose]() and transpose their materialized data, losing the wrapper.
- Applied to a nested [Transpose]() form, active or [Inactive](), [ArrayTranspose]() composes the two permutations into a single [Transpose]() wrapper instead of stacking them.
- A lazy parametric container, an array-valued [InterpolatingFunction]() applied to a symbolic parameter, transposes the value array at every grid point and reinterpolates, so the result stays lazy.
- Symbolic containers such as [MatrixSymbol]() stay in unevaluated [Transpose]() form, with trivial wrappers removed by [SimplifyArray]().
- If any dimension of *a* is 0, the result is the empty array `{}`.

## Basic Examples

Transpose a sparse matrix; the container is preserved:

```wl
transposed = ArrayTranspose[SparseArray[{{0, 1}, {2, 0}}], {2, 1}]
```

<!-- => SparseArray summary box: rank 2, dimensions {2, 2}, 2 stored elements -->

The elements are exchanged:

```wl
Normal[transposed]
```

<!-- => {{0, 2}, {1, 0}} -->

---

A two-way rule exchanges two levels:

```wl
ArrayTranspose[{{1, 2}, {3, 4}}, 1 <-> 2]
```

<!-- => {{1, 3}, {2, 4}} -->

---

A symbolic container stays in unevaluated form:

```wl
ArrayTranspose[MatrixSymbol["M", {2, 3}], {2, 1}]
```

<!-- => Transpose[MatrixSymbol["M", {2, 3}], {2, 1}] -->

The shape reads off the wrapper without materializing:

```wl
ArrayDimensions[ArrayTranspose[MatrixSymbol["M", {2, 3}], {2, 1}]]
```

<!-- => {3, 2} -->

## Scope

### Explicit containers

A [NumericArray]() transposes natively and keeps its container:

```wl
ArrayTranspose[NumericArray[{{1., 0.}, {0., 2.}}], {2, 1}]
```

<!-- => NumericArray summary box: Real64, dimensions {2, 2} -->

---

A [SymmetrizedArray]() stays a structured atom:

```wl
transposedSymmetrized = ArrayTranspose[SymmetrizedArray[{{1, 2} -> 3.}, {2, 2}, Antisymmetric[{1, 2}]], {2, 1}]
```

<!-- => a SymmetrizedArray summary box: dimensions {2, 2}, Antisymmetric[{1, 2}] symmetry, 1 rule -->

Transposing an antisymmetric array negates its independent component:

```wl
Normal[transposedSymmetrized]
```

<!-- => {{0, -3.}, {3., 0}} -->

---

A [Cycles]() specification permutes the levels of a higher-rank container:

```wl
permuted = ArrayTranspose[SparseArray[ArrayReshape[Range[24], {2, 3, 4}]], Cycles[{{1, 3}}]]
```

<!-- => a SparseArray summary box: rank 3, dimensions {4, 3, 2}, 24 stored elements -->

The first and third levels are exchanged in the shape:

```wl
ArrayDimensions[permuted]
```

<!-- => {4, 3, 2} -->

The leading slice of the permuted array reads the original along its third level:

```wl
Normal[permuted][[1]]
```

<!-- => {{1, 13}, {5, 17}, {9, 21}} -->

### Wrapper containers

A [QuantityArray]() transposes natively and keeps its wrapper:

```wl
ArrayTranspose[QuantityArray[{{1., 2.}, {3., 4.}}, "Meters"], {2, 1}]
```

<!-- => a QuantityArray summary box: dimensions {2, 2}, unit meters -->

The magnitudes are transposed underneath:

```wl
QuantityMagnitude[ArrayTranspose[QuantityArray[{{1., 2.}, {3., 4.}}, "Meters"], {2, 1}]]
```

<!-- => {{1., 3.}, {2., 4.}} -->

---

A [Tabular]() has no native [Transpose]() and transposes its materialized data:

```wl
ArrayTranspose[Tabular[{{1., 2.}, {3., 4.}}], {2, 1}]
```

<!-- => {{1., 3.}, {2., 4.}} -->

### Lazy containers

An array-valued [InterpolatingFunction]() applied to a symbolic parameter is a lazy container:

```wl
if = NDSolveValue[{m'[t] == {{0, 1}, {-1, 0}} . m[t], m[0] == {{1., 0.}, {0., 1.}}}, m, {t, 0, 1}];
lazy = if[tau]
```

<!-- => InterpolatingFunction[{{0., 1.}}, ...][tau] -->

Transposing reinterpolates the value grid, giving another [InterpolatingFunction]() applied to the parameter:

```wl
transposed = ArrayTranspose[lazy, {2, 1}]
```

<!-- => InterpolatingFunction[{{0., 1.}}, ...][tau], a reinterpolated matrix-valued function -->

The result is again a lazy container:

```wl
ArrayLazyQ[transposed]
```

<!-- => True -->

Substituting the parameter agrees with transposing the evaluated array:

```wl
Max[Abs[(transposed /. tau -> 0.5) - Transpose[if[0.5]]]] < 1*^-4
```

<!-- => True -->

### Symbolic containers

Transposing an already-transposed symbolic container composes the permutations into a single wrapper:

```wl
ArrayTranspose[Transpose[ArraySymbol["T", {2, 3, 4}], {2, 3, 1}], {2, 3, 1}]
```

<!-- => Transpose[ArraySymbol["T", {2, 3, 4}], {3, 1, 2}] -->

## Properties and Relations

An array with a zero dimension transposes to the empty array:

```wl
ArrayTranspose[ConstantArray[1, {0, 2}], {2, 1}]
```

<!-- => {} -->

## Possible Issues

Composing a permutation with its inverse gives the identity list, which is kept as an explicit trivial [Transpose]() wrapper rather than unwrapped:

```wl
ArrayTranspose[Transpose[MatrixSymbol["M", {2, 3}], {2, 1}], {2, 1}]
```

<!-- => Transpose[MatrixSymbol["M", {2, 3}], {1, 2}] -->
