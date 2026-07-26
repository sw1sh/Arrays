---
Template: Symbol
Name: ArrayReplaceAll
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayReplaceAll
Keywords: [substitution, replacement rules, lazy evaluation, sparse array, symbolic parameter, interpolating function, bound parameter]
SeeAlso: [ArrayMap, ArrayMaterialize, ArrayLazyQ, ArrayDeclareShape, ArrayExplicitValues, ArrayConjugate, ArrayName, SimplifyArray]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayReplaceAll]()[*a*, *rules*]</code> applies *rules* to the array container *a*, respecting the substitution semantics of each container kind.

## Details & Options

- On a lazy container the whole expression is substituted at once, so substituting all parameters evaluates the array-valued function a single time and returns an explicit (typically packed) array. An array-valued [Piecewise]() whose condition becomes decidable collapses to the branch value the same way.
- An unapplied [Function]() is the exception in form only, since its parameters are bound rather than free: a rule keyed on every parameter applies the [Function](), again a single whole-array evaluation, and the result is repacked.
- A rule keyed on only some parameters of a [Function]() curries, giving a [Function]() of the parameters that are still free; the remaining rules rewrite the free symbols of the body and keep the container lazy.
- The same bound-parameter treatment reaches an unapplied [Function]() carried inside an explicit container, such as the per-scalar expansion of a [Function]() container or a single element taken out of it. Plain [ReplaceAll]() would instead rewrite the parameter specification, producing a [Function]() whose parameter is a value.
- On a [SparseArray]() the *rules* map over the explicit values and the implicit (background) value, preserving the [SparseArray]() container.
- Structured atoms such as [SymmetrizedArray]() materialize through [Normal]() before substitution, densifying, so the *rules* reach the elements; plain [ReplaceAll]() returns the atom with its elements untouched.
- Wrapper containers ([QuantityArray](), [Tabular](), ...) substitute on their materialized data; for a [QuantityArray]() the *rules* see the magnitudes.
- Any other container, including plain lists and symbolic containers, uses [ReplaceAll]() directly, so a rule can for example rename a [MatrixSymbol]().

## Basic Examples

<!-- #| annotation: 26.07.26: Design review - Structured atoms are substitution-opaque: plain ReplaceAll returns a SymmetrizedArray atom with its elements untouched, a silent no-op, so ArrayReplaceAll materializes through Normal first; wrapper containers substitute on materialized data for the same reason. On a lazy container the whole expression is substituted at once so the array-valued function evaluates a single time, avoiding the per-scalar reinterpolation error of materializing first. The Function case is routed through the lazy-head registry rather than through ReplaceAll because its parameters are BOUND: a plain ReplaceAll rewrites the parameter specification into Function[0.5, ...], which the kernel rejects with Function::flpar and from which there is no route back to a value. The scan therefore tests for a bound-parameter form FIRST at every subexpression, which is what makes the treatment reach a Function carried inside an explicit container; an array with no such form anywhere in it stays on the plain ReplaceAll path. -->

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

---

An array-valued [Piecewise]() collapses to the branch its substituted condition selects:

```wl
pw = Piecewise[{{{{1., 2.}, {3., 4.}}, zz < 0}}, {{5., 6.}, {7., 8.}}];
ArrayReplaceAll[pw, zz -> -1]
```

<!-- => {{1., 2.}, {3., 4.}} -->

A value that fails every condition selects the default:

```wl
ArrayReplaceAll[pw, zz -> 1]
```

<!-- => {{5., 6.}, {7., 8.}} -->

### Bound parameters of a Function

The parameters of an unapplied [Function]() are bound, so a rule keyed on every one of them applies the [Function](), a single whole-array evaluation:

```wl
rotation = Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}];
ArrayReplaceAll[rotation, th -> 0.5]
```

<!-- => {{0.8775825618903728, -0.479425538604203}, {0.479425538604203, 0.8775825618903728}} -->

---

A rule keyed on only some parameters curries, giving a [Function]() of the parameters that are still free:

```wl
pair = Function[{xx, yy}, {{xx, yy}, {yy, xx}}];
ArrayReplaceAll[pair, xx -> 1.]
```

<!-- => Function[{yy}, {{1., yy}, {yy, 1.}}] -->

Binding the remaining parameter of that container gives the array:

```wl
ArrayReplaceAll[ArrayReplaceAll[pair, xx -> 1.], yy -> 2.]
```

<!-- => {{1., 2.}, {2., 1.}} -->

---

A rule keyed on a free symbol of the body rewrites the body and keeps the container lazy:

```wl
ArrayReplaceAll[Function[{xx, yy}, {{xx, cc yy}, {yy, xx}}], cc -> 3]
```

<!-- => Function[{xx, yy}, {{xx, 3 yy}, {yy, xx}}] -->

---

The bound-parameter treatment reaches a [Function]() carried inside an explicit container, such as the per-scalar expansion of a [Function]() container:

```wl
ArrayReplaceAll[ArrayMaterialize[rotation], th -> 0.5]
```

<!-- => {{0.8775825618903728, -0.479425538604203}, {0.479425538604203, 0.8775825618903728}} -->

---

A single element taken out of that expansion is one such [Function]() too:

```wl
ArrayReplaceAll[ArrayPart[rotation, {1, 2}], th -> 0.5]
```

<!-- => -0.479425538604203 -->

## Properties and Relations

Substituting the parameter of a lazy container evaluates the array-valued function at that value:

```wl
sol = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}];
ArrayReplaceAll[sol[tau], tau -> 0.5]
```

<!-- => {0.8775824340095093, -0.479425447892118} -->

Direct evaluation of the same function reproduces those values exactly, digit for digit:

```wl
sol[0.5]
```

<!-- => {0.8775824340095093, -0.479425447892118} -->

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

---

Plain [ReplaceAll]() on an unapplied [Function]() rewrites the parameter specification instead of applying the closure, and the kernel rejects the parameter with `Function::flpar`:

```wl
ReplaceAll[rotation, th -> 0.5]
```

<!-- => Function::flpar, then Function[0.5, {{Cos[0.5], -Sin[0.5]}, {Sin[0.5], Cos[0.5]}}] -->
