---
Template: Symbol
Name: ArrayConjugate
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayConjugate
Keywords: [conjugate, complex conjugation, array container, symbolic array]
SeeAlso: [ArrayTranspose, ArrayMap, ArrayReplaceAll, ArrayMaterialize, ArraySymbolicQ, ArrayContainerQ, ArrayLazyQ]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayConjugate]()[*a*]</code> conjugates the array container *a*.

## Details & Options

- Containers with a native [Conjugate]() are preserved: a [SparseArray]() stays sparse, a packed array stays packed, a structured array such as [SymmetrizedArray]() stays a structured atom, and a [QuantityArray]() keeps its wrapper.
- [Conjugate]() is not natively supported on [NumericArray](), so a [NumericArray]() converts through [Normal]() and re-wraps, staying a [NumericArray]().
- The storage wrappers ([Tabular](), [Dataset](), [EventSeries](), ...) conjugate their materialized data, losing the wrapper.
- A lazy container conjugates through its own head where that head has a rebuild, and stays lazy: an array-valued [InterpolatingFunction]() application conjugates its value grid, an unapplied [Function]() conjugates its body, and an array-valued [Piecewise]() conjugates its branch values.
- A lazy head with no such rebuild, such as a [ParametricFunction](), materializes to its per-scalar expansion before conjugating, and the result is no longer a lazy container.
- Symbolic containers stay in unevaluated [Conjugate]() form.

## Basic Examples

<!-- #| annotation: 26.07.26: Design review - Routes to the container's native Conjugate wherever that preserves the head (SparseArray, packed arrays, SymmetrizedArray, QuantityArray); NumericArray round-trips through Normal because Conjugate does not support it natively. Conjugation transforms values rather than only shape, so a lazy container keeps its head exactly where that head can be rebuilt around transformed values; a head with no such rebuild materializes per scalar and the result is then no longer lazy. -->

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
ArrayConjugate[MatrixSymbol["C", {2, 2}]]
```

<!-- => Conjugate[MatrixSymbol["C", {2, 2}]] -->

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

An array-valued [InterpolatingFunction]() application conjugates its value grid and stays a lazy container:

```wl
if = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}];
conjugated = ArrayConjugate[if[tau]]
```

<!-- => InterpolatingFunction[{{0., 1.}}, <>][tau], the conjugated interpolation -->

Substituting the parameter evaluates the conjugated interpolation:

```wl
conjugated /. tau -> 0.5
```

<!-- => {0.8775811345067771, -0.47942470176036955} -->

Conjugating the evaluated array gives those values back to interpolation accuracy:

```wl
Conjugate[if[0.5]]
```

<!-- => {0.8775824340095093, -0.479425447892118} -->

---

An unapplied [Function]() conjugates its body, keeping the parameter unbound:

```wl
ArrayConjugate[Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}]]
```

<!-- => Function[th, {{Conjugate[Cos[th]], -Conjugate[Sin[th]]}, {Conjugate[Sin[th]], Conjugate[Cos[th]]}}] -->

---

An array-valued [Piecewise]() conjugates its branch values, keeping its conditions:

```wl
ArrayConjugate[Piecewise[{{{{I, 2.}, {3., 4.}}, zz < 0}}, {{5., 6.}, {7., 8.}}]]
```

<!-- => Piecewise[{{{{-I, 2.}, {3., 4.}}, zz < 0}}, {{5., 6.}, {7., 8.}}] -->

## Possible Issues

A lazy head with no conjugating rebuild, such as a [ParametricFunction](), materializes to its per-scalar expansion first, and the conjugated result is no longer a lazy container:

```wl
pf = ParametricNDSolveValue[{y'[t] == {{0, pa}, {-pa, 0}} . y[t], y[0] == {1., 0.}}, y, {t, 0, 1}, {pa}];
ArrayConjugate[pf[pa2][tt]]
```

<!-- => {Conjugate[Indexed[ParametricFunction[<>][pa2][tt], {1}]], Conjugate[Indexed[ParametricFunction[<>][pa2][tt], {2}]]} -->

Binding both parameters still gives the conjugated array:

```wl
ArrayReplaceAll[ArrayConjugate[pf[pa2][tt]], {pa2 -> 1., tt -> 0.5}]
```

<!-- => {0.8775824340095093, -0.479425447892118} -->
