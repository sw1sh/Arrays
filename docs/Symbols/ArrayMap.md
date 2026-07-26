---
Template: Symbol
Name: ArrayMap
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayMap
Keywords: [map, elementwise, sparse array, packed array, level specification, container preservation]
SeeAlso: [ArrayReplaceAll, ArrayConjugate, ArrayMaterialize, ArrayPack, ArrayTranspose, ArrayPart, SimplifyArray, ArrayExplicitValues]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayMap]()[*f*, *a*]</code> maps *f* over the deepest elements of the array container *a*.

<code>[ArrayMap]()[*f*, *a*, *level*]</code> maps *f* over parts of *a* at the given *level*.

## Details & Options

- The default level is `{-1}`; for a container of rank $r$ the element level is `{-1}` or `{r}`, and the *level* specification otherwise follows [Map]().
- At element level a [SparseArray]() stays a [SparseArray](): *f* maps over the explicit values and is also applied to the implicit (background) value.
- At any other level a [SparseArray]() densifies through [Normal]() before mapping.
- A packed array repacks with the plain, non-coercing form of `` Developer`ToPackedArray ``: a result whose values pack as they stand is returned packed, while exact results such as `{1/2, 1, 3/2}` keep value parity with [Map]() instead of being coerced to machine reals.
- [NumericArray](), structured arrays such as [SymmetrizedArray]() and wrapper containers ([QuantityArray](), [Tabular](), ...) map over their materialized data and give an explicit array; a [QuantityArray]() maps over its magnitudes, not over [Quantity]() elements.
- At element level a lazy container maps *f* over its interpolation value grid and reinterpolates, staying lazy, provided *f* keeps the grid values numeric ([Chop](), [N](), [Abs](), ...); otherwise [ArrayMap]() stays unevaluated.
- At element level a symbolic container has no addressable elements, so *f* applies to the whole container, letting [Simplify]() and friends distribute over the symbolic tree; at other levels [ArrayMap]() stays unevaluated.

## Basic Examples

<!-- #| annotation: 26.07.26: Design review - At element level the SparseArray implicit (background) value is mapped alongside the explicit values so the result keeps value parity with Map on the Normal form; repacking uses the plain, non-coercing Developer`ToPackedArray so exact results are not coerced to machine reals. Out-of-scope combinations (non-numeric f on a lazy grid, non-element level on a symbolic container) stay unevaluated. -->

Map over a [SparseArray](), preserving the container:

```wl
mapped = ArrayMap[#^2 &, SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => SparseArray summary box: rank-2, dimensions {2, 2}, 2 stored elements -->

The elements are squared:

```wl
Normal[mapped]
```

<!-- => {{0, 1}, {4, 0}} -->

---

Map over a plain list array:

```wl
ArrayMap[# + 1 &, {{1, 2}, {3, 4}}]
```

<!-- => {{2, 3}, {4, 5}} -->

---

Map at level 1 instead of the element level:

```wl
ArrayMap[Total, SparseArray[{{0, 1}, {2, 0}}], {1}]
```

<!-- => {1, 2} -->

## Scope

The implicit value of a [SparseArray]() is mapped along with the explicit values:

```wl
Normal @ ArrayMap[# + 1 &, SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => {{1, 2}, {3, 1}} -->

---

A packed integer array keeps exact value parity with [Map]():

```wl
ArrayMap[# / 2 &, Developer`ToPackedArray[{1, 2, 3}]]
```

<!-- => {1/2, 1, 3/2} -->

A result whose values pack without coercion comes back repacked:

```wl
ArrayMap[# * 2 &, Developer`ToPackedArray[{1, 2, 3}]]
```

<!-- => {2, 4, 6} (packed Integer array) -->

---

A [NumericArray]() maps over its materialized data, densifying:

```wl
ArrayMap[# * 2 &, NumericArray[{{1., 0.}, {0., 2.}}]]
```

<!-- => {{2., 0.}, {0., 4.}} -->

---

A [QuantityArray]() maps over its magnitudes:

```wl
ArrayMap[#^2 &, QuantityArray[{1, 2, 3}, "Meters"]]
```

<!-- => {1, 4, 9} -->

---

A lazy container with a numeric-valued *f* remaps its value grid, giving another interpolating function applied to the parameter:

```wl
sol = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}];
chopped = ArrayMap[Chop, sol[tau]]
```

<!-- => InterpolatingFunction[{{0., 1.}}, ...][tau], the reinterpolated value grid -->

The remapped container is still lazy:

```wl
ArrayLazyQ[chopped]
```

<!-- => True -->

---

An element-level map applies *f* to the whole symbolic container:

```wl
ArrayMap[Simplify, MatrixSymbol["M", {2, 3}]]
```

<!-- => MatrixSymbol["M", {2, 3}] -->

## Properties and Relations

At element level, [ArrayMap]() squares the elements of a [SparseArray]() and the result materializes to:

```wl
Normal[ArrayMap[#^2 &, SparseArray[{{0, 1}, {2, 0}}]]]
```

<!-- => {{0, 1}, {4, 0}} -->

---

[Map]() at level `{-1}` on the [Normal]() form gives the same array:

```wl
Map[#^2 &, Normal[SparseArray[{{0, 1}, {2, 0}}]], {-1}]
```

<!-- => {{0, 1}, {4, 0}} -->

## Possible Issues

Mapping a [QuantityArray]() acts on the bare magnitudes, so the units are dropped from the result:

```wl
ArrayMap[# + 1 &, QuantityArray[{1, 2}, "Meters"]]
```

<!-- => {2, 3} -->

---

A function that does not keep the value grid numeric leaves a lazy container unevaluated:

```wl
sol = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}];
ArrayMap[f, sol[tau]]
```

<!-- => ArrayMap[f, InterpolatingFunction[...][tau]], the input unevaluated -->

---

A symbolic container only supports mapping at the element level; other levels stay unevaluated:

```wl
ArrayMap[f, MatrixSymbol["M", {2, 3}], {1}]
```

<!-- => ArrayMap[f, MatrixSymbol["M", {2, 3}], {1}], the input unevaluated -->
