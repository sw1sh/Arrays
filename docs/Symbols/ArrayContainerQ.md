---
Template: Symbol
Name: ArrayContainerQ
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayContainerQ
Keywords: [array container, predicate, explicit array, lazy array, symbolic array]
SeeAlso: [ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ, ArrayComputeNativeQ, ArrayDimensions, ArrayRank, ArrayMaterialize, ArrayObject, ArrayTier]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayContainerQ]()[*a*]</code> gives True if *a* is a supported array container of any tier: explicit, lazy parametric, or symbolic.

## Details & Options

- [ArrayContainerQ]() is the top-level admission predicate of the container hierarchy: it is equivalent to <code>[ArrayExplicitQ]()[*a*] || [ArrayLazyQ]()[*a*] || [ArraySymbolicQ]()[*a*]</code>.
- Explicit containers store their elements: `SparseArray`, packed or plain `List` arrays, `NumericArray`, structured arrays such as `SymmetrizedArray`, and the wrapper containers `QuantityArray`, `TabularColumn`, `Tabular`, `Dataset`, `ByteArray`, `EventSeries` and `DataStructure` array stores.
- Lazy containers are inert array-valued expressions whose head is registered in the lazy tier: an array-valued [InterpolatingFunction]() application, a fully applied array-valued [ParametricFunction](), an unapplied array-valued [Function](), an array-valued [Piecewise](), and a source [NetGraph]() or [NetChain]().
- Symbolic containers are `VectorSymbol`, `MatrixSymbol` and `ArraySymbol` objects, atomic symbols registered in `$Assumptions` as elements of `Vectors`, `Matrices` or `Arrays`, and structural trees over array containers, including the deferred contraction tree a tensor-network contraction returns unactivated.
- Recognizing an unapplied [Function]() evaluates its body, since its shape comes from a probe; an [ArrayDeclareShape]() declaration is consulted first and skips the probes.
- Wrapper containers are admitted under a shape-based criterion: the shape is introspectable without materializing and a materialization path exists; whether the container also computes natively is a separate capability flag, [ArrayComputeNativeQ](), not an admission gate.
- Every container answers [ArrayDimensions]() and [ArrayRank]() without materializing and has an [ArrayMaterialize]() route.
- [ArrayContainerQ]() gives False for any other expression, including scalars, ragged lists and `Association`.

## Basic Examples

A `SparseArray` is an explicit-tier container:

```wl
ArrayContainerQ[SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => True -->

A `VectorSymbol` is a symbolic-tier container:

```wl
ArrayContainerQ[VectorSymbol["v", 3]]
```

<!-- => True -->

A ragged list is not an array container:

```wl
ArrayContainerQ[{1, {2}}]
```

<!-- => False -->

## Scope

### Explicit containers

A plain `List` array is an explicit container:

```wl
ArrayContainerQ[{{1, 2}, {3, 4}}]
```

<!-- => True -->

---

A `NumericArray` is an explicit container:

```wl
ArrayContainerQ[NumericArray[{1., 2.}]]
```

<!-- => True -->

---

A `QuantityArray` carries units and is still an explicit container:

```wl
ArrayContainerQ[QuantityArray[{1., 2.}, "Meters"]]
```

<!-- => True -->

---

A `ByteArray` is a rank-1 explicit container:

```wl
ArrayContainerQ[ByteArray[{1, 2, 3}]]
```

<!-- => True -->

---

A `Dataset` is an explicit container:

```wl
ArrayContainerQ[Dataset[{1, 2, 3}]]
```

<!-- => True -->

---

A `Tabular` is an explicit container:

```wl
ArrayContainerQ[Tabular[{{1., 2.}, {3., 4.}}]]
```

<!-- => True -->

---

A `TabularColumn` is an explicit container:

```wl
ArrayContainerQ[TabularColumn[{1., 2.}]]
```

<!-- => True -->

---

An `EventSeries` is an explicit container:

```wl
ArrayContainerQ[EventSeries[{1., 2.}, {{0, 1}}]]
```

<!-- => True -->

---

A `DataStructure` array store is an explicit container:

```wl
ArrayContainerQ[CreateDataStructure["DynamicArray", {1., 2.}]]
```

<!-- => True -->

### Lazy containers

Solve a vector-valued ODE, giving an array-valued `InterpolatingFunction`:

```wl
v = NDSolveValue[{f'[t] == {{0, 1}, {-1, 0}} . f[t], f[0] == {1., 0.}}, f, {t, 0, 1}]
```

<!-- => InterpolatingFunction[{{0., 1.}}, "<>"] summary box -->

Applied to a symbolic parameter, it is a lazy parametric container:

```wl
ArrayContainerQ[v[tau]]
```

<!-- => True -->

---

An unapplied array-valued [Function]() is a lazy container as it stands:

```wl
ArrayContainerQ[Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}]]
```

<!-- => True -->

---

An array-valued [Piecewise]() with an undecidable condition is a lazy container:

```wl
ArrayContainerQ[Piecewise[{{{{1., 2.}, {3., 4.}}, zz < 0}}, {{5., 6.}, {7., 8.}}]]
```

<!-- => True -->

---

A source [NetGraph](), one with no open input ports, is a lazy container:

```wl
ArrayContainerQ[NetGraph[{NetArrayLayer["Array" -> {{1., 2., 3.}, {4., 5., 6.}}]}, {1 -> NetPort["Output"]}]]
```

<!-- => True -->

---

A net with an open input port is a function of that input, and is not a container:

```wl
ArrayContainerQ[NetGraph[{ElementwiseLayer[Tanh]}, {1 -> NetPort["Output"]}, "Input" -> 3]]
```

<!-- => False -->

### Symbolic containers

A `MatrixSymbol` is a container:

```wl
ArrayContainerQ[MatrixSymbol["M", {2, 3}]]
```

<!-- => True -->

An atomic symbol registered in `$Assumptions` is a container too:

```wl
Block[{$Assumptions = {Element[a, Matrices[{2, 2}]]}}, ArrayContainerQ[a]]
```

<!-- => True -->

A deferred contraction tree over explicit matrices is a container of the same tier:

```wl
ArrayContainerQ[
    Inactive[TensorContract][
        Inactive[TensorProduct][ArrayReshape[Range[6], {2, 3}], ArrayReshape[Range[12], {3, 4}]],
        {{2, 3}}
    ]
]
```

<!-- => True -->

## Properties and Relations

[ArrayContainerQ]() is the disjunction of the three tier predicates; a `MatrixSymbol` is a container:

```wl
ArrayContainerQ[MatrixSymbol["M", {2, 3}]]
```

<!-- => True -->

---

Of the three tier predicates, [ArrayExplicitQ]() is False for it:

```wl
ArrayExplicitQ[MatrixSymbol["M", {2, 3}]]
```

<!-- => False -->

---

[ArrayLazyQ]() is False for it as well:

```wl
ArrayLazyQ[MatrixSymbol["M", {2, 3}]]
```

<!-- => False -->

---

[ArraySymbolicQ]() is the single tier predicate that answers True:

```wl
ArraySymbolicQ[MatrixSymbol["M", {2, 3}]]
```

<!-- => True -->

## Possible Issues

`Association` is rejected: `Dimensions` and `Normal` report the entry multiset (the entry count and a list of rules), not the represented vector, so it has neither a faithful shape nor a faithful materialization:

```wl
ArrayContainerQ[<|1 -> 1.5, 2 -> 2.5, 5 -> -1.|>]
```

<!-- => False -->

Convert explicitly instead, e.g. through `SparseArray` with caller-supplied dimensions:

```wl
ArrayContainerQ[SparseArray[Normal[<|1 -> 1.5, 2 -> 2.5, 5 -> -1.|>], {5}]]
```

<!-- => True -->
