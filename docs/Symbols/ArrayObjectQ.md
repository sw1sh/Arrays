---
Template: Symbol
Name: ArrayObjectQ
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayObjectQ
Keywords: [array container, container handle, predicate, summary box]
SeeAlso: [ArrayObject, ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayObjectQ]()[*obj*]</code> gives True if *obj* is an [ArrayObject]() handle around a supported array container.

## Details & Options

- [ArrayObjectQ]() gives True when the head of *obj* is [ArrayObject]() and its content satisfies [ArrayContainerQ]().
- Containers of all three tiers give True once wrapped.
- [ArrayObjectQ]() gives False for every other expression, including a raw array container, the symbol [ArrayObject]() itself, and any number of arguments other than one.
- An [ArrayObject]() expression left unevaluated by `ArrayObject::nocontainer` gives False, so the predicate never reports a handle around unsupported content.
- The test reads only the shape and classification tiers and never materializes the wrapped container.

## Basic Examples

<!-- #| annotation: 26.07.26: Design review - the predicate is separate from the head because the head is the object: ArrayObject[expr] stays unevaluated when expr is not a container, so an ArrayObject-headed expression is not by itself proof of a well-formed handle, and every UpValue on the head is guarded by this test rather than by the pattern obj_ArrayObject alone. It is defined as a two-part test (head plus ArrayContainerQ on the content) with a catch-all False clause, so it answers for any argument count instead of staying unevaluated - the usual contract for a *Q predicate in the kernel, where ArrayQ, AssociationQ and NumericArrayQ all answer False rather than echoing. Note the definition must be written with HoldPattern on its left-hand side: an assignment evaluates the arguments of its LHS, so a bare ArrayObjectQ[ArrayObject[a_]] trips the rejection guard on the head and messages while the paclet loads. -->

A handle around a container:

```wl
ArrayObjectQ[ArrayObject[SparseArray[{{0, 1}, {2, 0}}]]]
```

<!-- => True -->

---

A raw container is not a handle:

```wl
ArrayObjectQ[SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => False -->

---

Neither is an ordinary expression:

```wl
ArrayObjectQ[f0[x]]
```

<!-- => False -->

## Scope

A handle around an explicit-tier container:

```wl
ArrayObjectQ[ArrayObject[Tabular[{{1., 2.}, {3., 4.}}]]]
```

<!-- => True -->

---

A handle around a lazy-tier container:

```wl
v = NDSolveValue[{f'[t] == {{0, 1}, {-1, 0}} . f[t], f[0] == {1., 0.}}, f, {t, 0, 1}];
ArrayObjectQ[ArrayObject[v[tau]]]
```

<!-- => True -->

---

A handle around a symbolic-tier container:

```wl
ArrayObjectQ[ArrayObject[MatrixSymbol["M", {2, 3}]]]
```

<!-- => True -->

---

The symbol [ArrayObject]() on its own is not a handle:

```wl
ArrayObjectQ[ArrayObject]
```

<!-- => False -->

---

An argument count other than one gives False rather than staying unevaluated:

```wl
ArrayObjectQ[1, 2]
```

<!-- => False -->

## Properties and Relations

A handle around a matrix of machine reals:

```wl
obj = ArrayObject[{{1., 2.}, {3., 4.}}]
```

<!-- => ArrayObject summary box: kind List, dimensions {2, 2} -->

---

The predicate accepts it:

```wl
ArrayObjectQ[obj]
```

<!-- => True -->

---

A handle is itself an array container, so [ArrayContainerQ]() accepts it too:

```wl
ArrayContainerQ[obj]
```

<!-- => True -->

---

And the shape functions read through it:

```wl
ArrayDimensions[obj]
```

<!-- => {2, 2} -->

---

Wrapping is idempotent, so a doubly wrapped container is a single handle:

```wl
ArrayObjectQ[ArrayObject[ArrayObject[{1., 2.}]]]
```

<!-- => True -->

## Possible Issues

An [ArrayObject]() expression around unsupported content stays unevaluated, and gives False:

```wl
Quiet[ArrayObjectQ[ArrayObject[<|1 -> 1.5, 2 -> 2.5|>]]]
```

<!-- => False -->
