---
Template: Symbol
Name: ArrayLazyQ
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayLazyQ
Keywords: [lazy array, parametric array, interpolating function, array container, predicate]
SeeAlso: [ArrayContainerQ, ArrayExplicitQ, ArraySymbolicQ, ArrayComputeNativeQ, ArrayDimensions, ArrayReplaceAll, ArrayMaterialize]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayLazyQ]()[*a*]</code> gives True if *a* is a lazy parametric array container: an array-valued expression *f*[*args*] with at least one non-numeric argument, such as an array-valued `InterpolatingFunction` applied to a symbolic parameter.

## Details & Options

- A lazy container is an inert application that would evaluate to an explicit array if its parameters were numeric; keeping the parameter symbolic defers that evaluation.
- The currently recognized head is `InterpolatingFunction` with array-valued output (non-empty "OutputDimensions"); the set of supported heads is extensible per head.
- Applied to all-numeric arguments, the expression evaluates to an explicit array, so [ArrayLazyQ]() gives False and [ArrayExplicitQ]() gives True.
- A scalar-valued `InterpolatingFunction` application is not an array container at all.
- The shape of a lazy container is introspected without materializing: [ArrayDimensions]() reads the output dimensions of the inert head.
- Structural operations keep the container lazy: [ArrayTranspose](), [ArrayVector](), [ReshapeArray]() and element-level [ArrayMap]() with a numeric-valued function all transform the value grid and reinterpolate.
- [ArrayReplaceAll]() substitutes the whole lazy expression at once, so substituting all parameters evaluates the array-valued function a single time.
- The stored-value accessors [ArrayExplicitValues](), [ArrayExplicitPositions]() and [ArrayExplicitLength]() give <code>Missing["NotExplicit"]</code> for lazy containers.

## Basic Examples

Solve a vector-valued ODE, giving an array-valued `InterpolatingFunction`:

```wl
v = NDSolveValue[{f'[t] == {{0, 1}, {-1, 0}} . f[t], f[0] == {1., 0.}}, f, {t, 0, 1}]
```

<!-- => InterpolatingFunction[{{0., 1.}}, "<>"] summary box -->

Applied to a symbolic parameter, it is a lazy parametric container:

```wl
ArrayLazyQ[v[tau]]
```

<!-- => True -->

Applied to a numeric argument, the expression is no longer lazy:

```wl
ArrayLazyQ[v[0.5]]
```

<!-- => False -->

---

It has evaluated to an explicit array instead:

```wl
ArrayExplicitQ[v[0.5]]
```

<!-- => True -->

## Scope

The shape is introspectable without materializing:

```wl
ArrayDimensions[v[tau]]
```

<!-- => {2} -->

---

A scalar-valued `InterpolatingFunction` application is not a lazy container:

```wl
u = NDSolveValue[{g'[t] == -g[t], g[0] == 1.}, g, {t, 0, 1}];
ArrayLazyQ[u[tau]]
```

<!-- => False -->

---

An explicit container is not lazy:

```wl
ArrayLazyQ[SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => False -->

---

Structural operations keep a matrix-valued container lazy:

```wl
m = NDSolveValue[{h'[t] == {{0, 1}, {-1, 0}} . h[t], h[0] == {{1., 0.}, {0., 1.}}}, h, {t, 0, 1}];
ArrayLazyQ[ArrayTranspose[m[tau], {2, 1}]]
```

<!-- => True -->

## Properties and Relations

[ArrayReplaceAll]() substitutes the whole expression at once, evaluating the array-valued function a single time:

```wl
ArrayReplaceAll[v[tau], tau -> 0.5]
```

<!-- => {0.8775824340095093, -0.479425447892118} -->

---

The result agrees with applying the interpolating function to the same numeric argument directly:

```wl
v[0.5]
```

<!-- => {0.8775824340095093, -0.479425447892118} -->

---

Lazy containers do not compute natively:

```wl
ArrayComputeNativeQ[v[tau]]
```

<!-- => False -->

## Possible Issues

A lazy container stores no elements, so the stored-value accessors decline to answer:

```wl
ArrayExplicitValues[v[tau]]
```

<!-- => Missing["NotExplicit"] -->
