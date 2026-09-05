---
Template: Symbol
Name: ArrayTier
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayTier
Keywords: [tier, tier lattice, explicit tier, lazy tier, symbolic tier, classification, join]
SeeAlso: [ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ, ArrayUnify, ArrayCoerce, ArrayElementDomain, ArrayObject]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayTier]()[*a*]</code> gives the tier of the array container *a*, one of `"Explicit"`, `"Lazy"` or `"Symbolic"`.

## Details & Options

- The three tiers are ordered `"Explicit"` < `"Lazy"` < `"Symbolic"`, from the most specific to the most general: binding the parameters of a lazy container gives an explicit one, and specializing a symbolic container gives a lazy or an explicit one.
- A container belongs to exactly one tier. <code>[ArrayTier]()[*a*]</code> gives `"Explicit"` when *a* satisfies [ArrayExplicitQ](), `"Lazy"` when it satisfies [ArrayLazyQ](), and `"Symbolic"` when it satisfies [ArraySymbolicQ]().
- A structural tree whose leaves are all explicit containers, the deferred form a tensor-network contraction returns unactivated, is `"Lazy"`: it has a value and merely defers computing it. A tree that carries a symbolic container at any depth is `"Symbolic"`.
- An expression that is not a supported array container gives `Missing["NotAContainer"]` rather than a tier.
- The tier of an operation over several containers is the maximum of its operands' tiers, which [ArrayUnify]() gives as its `"Tier"` key. A result may land on a more specific tier where an operation genuinely collapses generality, but the join is the contract.
- [ArrayCoerce]() moves a container up the tier lattice and refuses to move it down, which is materialization. The symbolic tier is not reachable by coercion: a container is symbolic because it carries a symbol, and there is nothing to turn known values into unknown ones with, so the only lift is from the explicit tier to the lazy one.
- <code>[ArrayObject]()[*a*]["Tier"]</code> reports the same tier, and the expanded summary box shows it.

## Basic Examples

<!-- #| annotation: 27.07.26: Design review - the classification predicates are probed in a fixed order by one Which rather than by three definitions, so the answer does not depend on definition ordering; the last branch answers Missing["NotAContainer"] for anything that is not a container, so a non-container propagates through a tier join instead of silently reading as the most general tier. -->

A [SparseArray]() holds its elements in memory:

```wl
ArrayTier[SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => "Explicit" -->

---

An unapplied array-valued [Function]() is a lazy container:

```wl
ArrayTier[Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}]]
```

<!-- => "Lazy" -->

---

A [MatrixSymbol]() has a shape and no addressable elements:

```wl
ArrayTier[MatrixSymbol["M", {2, 3}]]
```

<!-- => "Symbolic" -->

## Scope

### Explicit containers

A [NumericArray]() stores its elements in a typed buffer:

```wl
ArrayTier[NumericArray[{1, 2}, "Integer32"]]
```

<!-- => "Explicit" -->

---

A [ByteArray]() is admitted on the same criterion:

```wl
ArrayTier[ByteArray[{1, 2, 3}]]
```

<!-- => "Explicit" -->

### Lazy containers

An array-valued [InterpolatingFunction]() applied to a symbolic parameter awaits that parameter:

```wl
state = NDSolveValue[{f'[t] == {{0, 1}, {-1, 0}} . f[t], f[0] == {1., 0.}}, f, {t, 0, 1}];
ArrayTier[state[tau]]
```

<!-- => "Lazy" -->

---

The unapplied [InterpolatingFunction]() is itself a lazy container, whose elements are the unapplied component interpolants:

```wl
state = NDSolveValue[{f'[t] == {{0, 1}, {-1, 0}} . f[t], f[0] == {1., 0.}}, f, {t, 0, 1}];
ArrayTier[state]
```

<!-- => "Lazy" -->

---

An array-valued [Piecewise]() awaits the condition that selects a branch:

```wl
ArrayTier[Piecewise[{{{{1., 2.}, {3., 4.}}, zz < 0}}, {{5., 6.}, {7., 8.}}]]
```

<!-- => "Lazy" -->

---

A source [NetGraph]() produces its array on the one call that evaluates it:

```wl
ArrayTier[NetGraph[{NetArrayLayer["Array" -> {{1., 2., 3.}, {4., 5., 6.}}]}, {1 -> NetPort["Output"]}]]
```

<!-- => "Lazy" -->

---

A deferred contraction tree whose leaves are all explicit has a value it has merely not computed:

```wl
ArrayTier[Inactive[TensorContract][
    Inactive[TensorProduct][ArrayReshape[Range[6], {2, 3}], ArrayReshape[Range[12], {3, 4}]],
    {{2, 3}}
]]
```

<!-- => "Lazy" -->

### Symbolic containers

A symbol registered in [$Assumptions]() carries its shape in the assumption:

```wl
$Assumptions = {Element[symR, Matrices[{2, 2}, Reals]]};
ArrayTier[symR]
```

<!-- => "Symbolic" -->

---

An inactive tensor product over array symbols is a symbolic tree:

```wl
ArrayTier[Inactive[TensorProduct][MatrixSymbol["A", {2, 3}], MatrixSymbol["B", {3, 4}]]]
```

<!-- => "Symbolic" -->

---

One symbolic leaf at any depth makes the whole tree symbolic; here the contraction above is taken over a [MatrixSymbol]():

```wl
ArrayTier[Inactive[TensorContract][
    Inactive[TensorProduct][MatrixSymbol["A", {2, 3}], ArrayReshape[Range[12], {3, 4}]],
    {{2, 3}}
]]
```

<!-- => "Symbolic" -->

## Properties and Relations

An [ArrayObject]() handle reports the tier of the container it wraps:

```wl
ArrayObject[SparseArray[{{0, 1}, {2, 0}}]]["Tier"]
```

<!-- => "Explicit" -->

---

The tier of a contraction over an operand set of different tiers is the maximum of the operands' tiers, so an explicit operand contracted against a lazy one gives a lazy result:

```wl
ArrayTier[ArrayContract[Inactive[TensorProduct][SparseArray[{{1, 2}, {3, 4}}], Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}]], {{1, 3}}]]
```

<!-- => "Lazy" -->

---

[ArrayUnify]() gives that same maximum as the `"Tier"` of the operand set, before any operation is performed:

```wl
ArrayUnify[{SparseArray[{{1, 2}, {3, 4}}], Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}]}]["Tier"]
```

<!-- => "Lazy" -->

---

[ArrayCoerce]() lifts a container up the lattice, and the lifted container reports the tier it was lifted to:

```wl
ArrayTier[ArrayCoerce[{{1, 2}, {3, 4}}, "Lazy"]]
```

<!-- => "Lazy" -->

## Possible Issues

An expression that is not an array container has no tier:

```wl
ArrayTier["junk"]
```

<!-- => Missing["NotAContainer"] -->

---

An [Association]() is not admitted as a container, since its [Dimensions]() report the entry multiset rather than the represented vector:

```wl
ArrayTier[<|1 -> 1.5|>]
```

<!-- => Missing["NotAContainer"] -->

---

The symbolic tier is not reachable by coercion, so asking for it is refused and the call stays unevaluated:

```wl
ArrayCoerce[{{1, 2}, {3, 4}}, "Symbolic"]
```

<!-- => ArrayCoerce::coerce message, then ArrayCoerce[{{1, 2}, {3, 4}}, "Symbolic"] unevaluated -->
