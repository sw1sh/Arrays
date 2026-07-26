---
Template: Symbol
Name: ArrayReplaceAll
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayReplaceAll
Keywords: [substitution, replacement rules, lazy evaluation, sparse array, symbolic parameter, interpolating function]
SeeAlso: [ArrayMap, ArrayMaterialize, ArrayLazyQ, ArrayExplicitValues, ArrayConjugate, ArrayName, SimplifyArray]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayReplaceAll]()[*a*, *rules*]</code> applies *rules* to the array container *a*, respecting the substitution semantics of each container kind.

## Details & Options

- On a lazy container the whole expression is substituted at once, so substituting all parameters evaluates the array-valued function a single time and returns an explicit (typically packed) array.
- On a [SparseArray]() the *rules* map over the explicit values and the implicit (background) value, preserving the [SparseArray]() container.
- Structured atoms such as [SymmetrizedArray]() materialize through [Normal]() before substitution, densifying, so the *rules* reach the elements; plain [ReplaceAll]() returns the atom with its elements untouched.
- Wrapper containers ([QuantityArray](), [Tabular](), ...) substitute on their materialized data; for a [QuantityArray]() the *rules* see the magnitudes.
- Any other container, including plain lists and symbolic containers, uses [ReplaceAll]() directly, so a rule can for example rename a [MatrixSymbol]().

## Basic Examples

<!-- #| annotation: 26.07.26: Design review - Structured atoms are substitution-opaque: plain ReplaceAll returns a SymmetrizedArray atom with its elements untouched, a silent no-op, so ArrayReplaceAll materializes through Normal first; wrapper containers substitute on materialized data for the same reason. On a lazy container the whole expression is substituted at once so the array-valued function evaluates a single time, avoiding the per-scalar reinterpolation error of materializing first. -->

An array-valued [NDSolveValue]() solution applied to a symbolic parameter stays unevaluated:

```wl
sol = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}];
state = sol[tau]
```

<!-- => InterpolatingFunction[{{0., 1.}}, ...][tau] -->

That expression is a lazy container:

```wl
ArrayLazyQ[state]
```

<!-- => True -->

Substituting the time parameter evaluates the array-valued [InterpolatingFunction]() once and returns a packed vector:

```wl
ArrayReplaceAll[state, tau -> 0.5]
```

<!-- => {0.877582, -0.479425} -->

---

On a [SparseArray]() the rules map over the explicit values, preserving the container:

```wl
Normal @ ArrayReplaceAll[SparseArray[{1 -> x}, 3], x -> 2]
```

<!-- => {2, 0, 0} -->

---

A rule can rename a symbolic container:

```wl
ArrayReplaceAll[MatrixSymbol["M", {2, 3}], "M" -> "M2"]
```

<!-- => MatrixSymbol["M2", {2, 3}] -->

## Scope

The implicit value of a [SparseArray]() is substituted along with the explicit values:

```wl
Normal @ ArrayReplaceAll[SparseArray[{{1, 1} -> x}, {2, 2}, y], {x -> 1, y -> 2}]
```

<!-- => {{1, 2}, {2, 2}} -->

---

A [SymmetrizedArray]() materializes first, so the substitution actually reaches its elements:

```wl
ArrayReplaceAll[SymmetrizedArray[{{1, 2} -> a}, {2, 2}, Antisymmetric[{1, 2}]], a -> 5]
```

<!-- => {{0, 5}, {-5, 0}} -->

---

A wrapper container substitutes on its materialized data; for a [QuantityArray]() the rules see the magnitudes:

```wl
ArrayReplaceAll[QuantityArray[{1, 2, 3}, "Meters"], 1 -> 10]
```

<!-- => {10, 2, 3} -->

---

A plain list array uses [ReplaceAll]() directly:

```wl
ArrayReplaceAll[{{1, x}, {x, 2}}, x -> 0]
```

<!-- => {{1, 0}, {0, 2}} -->

## Properties and Relations

Substituting the parameter of a lazy container reproduces direct evaluation of the array-valued function exactly:

```wl
sol = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}];
ArrayReplaceAll[sol[tau], tau -> 0.5] == sol[0.5]
```

<!-- => True -->

Materializing first instead expands the container into per-scalar reinterpolations, so substituting into that form only approximates the direct evaluation:

```wl
Max @ Abs[(ArrayMaterialize[sol[tau]] /. tau -> 0.5) - sol[0.5]]
```

<!-- => 1.2995*10^-6 -->

## Possible Issues

Plain [ReplaceAll]() does not penetrate a [SymmetrizedArray]() atom, silently leaving its elements untouched:

```wl
Normal[SymmetrizedArray[{{1, 2} -> a}, {2, 2}, Antisymmetric[{1, 2}]] /. a -> 5]
```

<!-- => {{0, a}, {-a, 0}} -->

---

Substituting on a wrapper container returns materialized data, so a [QuantityArray]() result carries no units:

```wl
ArrayReplaceAll[QuantityArray[{1, 2}, "Meters"], {}]
```

<!-- => {1, 2} -->
