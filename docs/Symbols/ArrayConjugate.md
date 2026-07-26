---
Template: Symbol
Name: ArrayConjugate
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayConjugate
Keywords: [conjugate, complex conjugation, array container, symbolic array]
SeeAlso: [ArrayTranspose, ArrayMap, ArrayReplaceAll, ArrayMaterialize, ArraySymbolicQ, ArrayContainerQ]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayConjugate]()[*a*]</code> conjugates the array container *a*.

## Details & Options

- Containers with a native [Conjugate]() are preserved: a [SparseArray]() stays sparse, a packed array stays packed, a structured array such as [SymmetrizedArray]() stays a structured atom, and a [QuantityArray]() keeps its wrapper.
- [Conjugate]() is not natively supported on [NumericArray](), so a [NumericArray]() converts through [Normal]() and re-wraps, staying a [NumericArray]().
- The storage wrappers ([Tabular](), [Dataset](), [EventSeries](), ...) conjugate their materialized data, losing the wrapper.
- A lazy parametric container materializes to its per-scalar expansion before conjugating, so the result is no longer a lazy container.
- Symbolic containers stay in unevaluated [Conjugate]() form.

## Basic Examples

<!-- #| annotation: 26.07.26: Design review - Routes to the container's native Conjugate wherever that preserves the head (SparseArray, packed arrays, SymmetrizedArray, QuantityArray); NumericArray round-trips through Normal because Conjugate does not support it natively. Lazy containers materialize per scalar rather than staying lazy: conjugation transforms values, unlike the shape-only ArrayTranspose and ReshapeArray, which keep the container lazy. -->

Conjugate a sparse vector; the container is preserved:

```wl
conjugated = ArrayConjugate[SparseArray[{1 -> I, 2 -> 2}, 3]]
```

<!-- => a SparseArray summary box: rank 1, dimensions {3}, 2 stored elements -->

The elements are conjugated:

```wl
Normal[conjugated]
```

<!-- => {-I, 2, 0} -->

---

A symbolic container stays in unevaluated [Conjugate]() form:

```wl
ArrayConjugate[MatrixSymbol["C", {2, 2}, Complexes]]
```

<!-- => Conjugate[MatrixSymbol["C", {2, 2}, Complexes]] -->

## Scope

### Explicit containers

A packed complex array stays packed:

```wl
ArrayConjugate[Developer`ToPackedArray[{1. + 2. I, 3. - 1. I}]]
```

<!-- => {1. - 2.*I, 3. + 1.*I} (packed) -->

---

A [NumericArray]() converts through [Normal]() and re-wraps:

```wl
conjugatedNumeric = ArrayConjugate[NumericArray[{{1., 0.}, {0., 2.}}]]
```

<!-- => a NumericArray summary box: Real64, dimensions {2, 2} -->

Its real elements are unchanged by conjugation:

```wl
Normal[conjugatedNumeric]
```

<!-- => {{1., 0.}, {0., 2.}} -->

---

A [SymmetrizedArray]() conjugates natively and keeps the structured atom:

```wl
conjugated = ArrayConjugate[SymmetrizedArray[{{1, 2} -> 3. I}, {2, 2}, Antisymmetric[{1, 2}]]]
```

<!-- => a SymmetrizedArray summary box: dimensions {2, 2}, Antisymmetric[{1, 2}] symmetry, 1 rule -->

The independent component is conjugated:

```wl
Normal[conjugated]
```

<!-- => {{0, 0. - 3.*I}, {0. + 3.*I, 0}} -->

### Wrapper containers

A [QuantityArray]() conjugates natively and keeps its wrapper:

```wl
ArrayConjugate[QuantityArray[{{1., 2.}, {3., 4.}}, "Meters"]]
```

<!-- => a QuantityArray summary box: dimensions {2, 2}, unit meters -->

---

A [Tabular]() conjugates its materialized data:

```wl
ArrayConjugate[Tabular[{{1., 2.}, {3., 4.}}]]
```

<!-- => {{1., 2.}, {3., 4.}} -->

### Lazy containers

A lazy container materializes to its per-scalar expansion before conjugating:

```wl
if = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}];
conjugated = ArrayConjugate[if[tau]]
```

<!-- => {Conjugate[InterpolatingFunction[...][tau]], Conjugate[InterpolatingFunction[...][tau]]} -->

Substituting the parameter agrees with conjugating the evaluated array:

```wl
Max[Abs[(conjugated /. tau -> 0.5) - Conjugate[if[0.5]]]] < 1*^-4
```

<!-- => True -->

## Possible Issues

Unlike [ArrayTranspose]() and [ReshapeArray](), conjugating a lazy container does not stay lazy; the result is a plain list of conjugated scalar expressions:

```wl
ArrayLazyQ[ArrayConjugate[if[tau]]]
```

<!-- => False -->
