---
Template: Symbol
Name: ArrayElementDomain
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayElementDomain
Keywords: [element domain, domain lattice, numeric type, symbolic domain, join, element metadata]
SeeAlso: [ArrayElementType, ArrayUnify, ArrayCoerce, ArrayTier, ArrayNumericQ, ArrayNumberQ, ArrayObject]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayElementDomain]()[*a*]</code> gives the element domain of the array container *a*, one of [Integers](), [Rationals](), [Algebraics](), [Reals]() or [Complexes]().

## Details & Options

- The five domains are ordered [Integers]() < [Rationals]() < [Algebraics]() < [Reals]() < [Complexes](), and the domain of an operation over several containers is the maximum of its operands' domains, which [ArrayUnify]() gives as its `"Domain"` key.
- The domain is the tier-independent description of the elements: a [NumericArray]() of type `"Real64"` and a [MatrixSymbol]() declared over [Reals]() both give [Reals](), which is what makes containers of different tiers joinable.
- A container that stores a numeric type answers from it: `"Integer64"` and `"UnsignedInteger8"` give [Integers](), `"Real32"` gives [Reals](), and `"ComplexReal64"` gives [Complexes](). A [ByteArray]() gives [Integers]().
- A [QuantityArray]() answers from its magnitudes, the unit being separate metadata. A [TabularColumn]() and an [EventSeries]() answer from the column element type.
- A [List]() or a [SparseArray]() carrying no type metadata has its domain inferred from the values it holds, the implicit value of a [SparseArray]() included. A packed array answers from its packing without touching an element.
- [Algebraics]() is not inferred from values, which would need [Element](). It is reachable as a declared symbolic domain and as an [ArrayCoerce]() target, and an algebraic value scans as [Reals]() or [Complexes]().
- A symbolic container gives its declared domain, defaulting to [Complexes]() as [Vectors](), [Matrices]() and [Arrays]() do. A structural tree gives the join of its operands' domains.
- Every route reads stored metadata or values the container already holds; none materializes.
- A container whose domain is not known gives `Missing["NotApplicable"]`: an array holding a symbolic element, a column of a non-numeric type, and every container of the lazy tier, whose elements exist only once it is evaluated. An unknown domain contributes nothing to a join rather than making the join unknown.
- <code>[ArrayObject]()[*a*]["Domain"]</code> gives the same domain, and the expanded summary box shows it for a container that carries no element type.

## Basic Examples

<!-- #| annotation: 27.07.26: Design review - one lattice serves both spellings, the numeric container types and the declared symbolic domains, so that a NumericArray and an array symbol join without either being converted to the other. The domain of an unknown-element container is Missing rather than Complexes: reporting the top of the lattice would make every join involving a container that carries no element metadata claim the widest domain, where Missing is dropped from a join and only an all-unknown join is unknown. -->

A [NumericArray]() answers from the type it stores:

```wl
ArrayElementDomain[NumericArray[{1., 2.}, "Real32"]]
```

<!-- => Reals -->

---

A plain integer matrix has its domain inferred from its values:

```wl
ArrayElementDomain[{{1, 2}, {3, 4}}]
```

<!-- => Integers -->

---

A symbolic container gives the domain it was declared over:

```wl
ArrayElementDomain[VectorSymbol["z", 2, Reals]]
```

<!-- => Reals -->

## Scope

### Stored numeric types

An unsigned integer type maps into the same domain as a signed one:

```wl
ArrayElementDomain[NumericArray[{1, 2}, "UnsignedInteger8"]]
```

<!-- => Integers -->

---

A complex type gives the top of the domain order:

```wl
ArrayElementDomain[NumericArray[{1. + 2. I, 3.}, "ComplexReal64"]]
```

<!-- => Complexes -->

---

A [ByteArray]() holds unsigned bytes:

```wl
ArrayElementDomain[ByteArray[{1, 2, 3}]]
```

<!-- => Integers -->

---

A [TabularColumn]() answers from its column element type:

```wl
ArrayElementDomain[TabularColumn[{1, 2}]]
```

<!-- => Integers -->

---

An [EventSeries]() answers from the element type of its values column:

```wl
ArrayElementDomain[EventSeries[{{1., 2.}, {3., 4.}}, {{0, 1}}]]
```

<!-- => Reals -->

---

A [QuantityArray]() answers from its magnitudes, the unit being separate metadata:

```wl
ArrayElementDomain[QuantityArray[{1., 2.}, "Meters"]]
```

<!-- => Reals -->

### Inference from values

Exact rational entries give [Rationals]():

```wl
ArrayElementDomain[{1/2, 1/3}]
```

<!-- => Rationals -->

---

A packed real array answers from its packing, without touching an element:

```wl
ArrayElementDomain[Developer`ToPackedArray[{{1., 2.}, {3., 4.}}]]
```

<!-- => Reals -->

---

A complex entry widens the whole array to [Complexes]():

```wl
ArrayElementDomain[{1. + 2. I, 3.}]
```

<!-- => Complexes -->

---

The implicit value of a [SparseArray]() counts, so an integer-valued sparse array with a real default is a real array:

```wl
ArrayElementDomain[SparseArray[{1 -> 1}, {3}, 0.]]
```

<!-- => Reals -->

### Symbolic containers and trees

An array symbol carrying no domain argument defaults to [Complexes](), as [Vectors](), [Matrices]() and [Arrays]() do:

```wl
ArrayElementDomain[MatrixSymbol["M", {2, 2}]]
```

<!-- => Complexes -->

---

A symbol registered in [$Assumptions]() gives the domain of its assumption:

```wl
$Assumptions = {Element[symR, Matrices[{2, 2}, Reals]]};
ArrayElementDomain[symR]
```

<!-- => Reals -->

---

An [Algebraics]() declaration is carried through:

```wl
ArrayElementDomain[VectorSymbol["za", 2, Algebraics]]
```

<!-- => Algebraics -->

---

A structural tree gives the join of its operands' domains, so an integer matrix and a real array symbol give [Reals]():

```wl
ArrayElementDomain[Inactive[TensorProduct][SparseArray[{{1, 2}, {3, 4}}], VectorSymbol["zr", 2, Reals]]]
```

<!-- => Reals -->

## Properties and Relations

An [ArrayObject]() handle reports the same domain:

```wl
ArrayObject[NumericArray[{1., 2.}, "Real32"]]["Domain"]
```

<!-- => Reals -->

---

[ArrayElementType]() gives the concrete stored type where the container carries one, which the domain abstracts over:

```wl
ArrayElementType[NumericArray[{1., 2.}, "Real32"]]
```

<!-- => "Real32" -->

---

[ArrayUnify]() joins the domains of an operand set, and an integer container joined with a real one gives [Reals]():

```wl
ArrayUnify[{{{1, 2}, {3, 4}}, {{1., 2.}, {3., 4.}}}]["Domain"]
```

<!-- => Reals -->

---

[ArrayCoerce]() widens a domain and refuses to narrow one, so widening an integer array to [Reals]() leaves it as it is, a domain being an upper bound the container already meets:

```wl
ArrayCoerce[{{1, 2}, {3, 4}}, Reals]
```

<!-- => {{1, 2}, {3, 4}} -->

## Possible Issues

An array holding a symbolic element has no domain this tier can read without evaluating it:

```wl
ArrayElementDomain[{{t1, t2}, {t3, t4}}]
```

<!-- => Missing["NotApplicable"] -->

---

A lazy container has elements only once it is evaluated, so no container of that tier reports a domain:

```wl
ArrayElementDomain[Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}]]
```

<!-- => Missing["NotApplicable"] -->

---

A column whose element type is not numeric has no place in the domain order:

```wl
ArrayElementDomain[TabularColumn[{"a", "b"}]]
```

<!-- => Missing["NotApplicable"] -->

The column still reports the type it stores:

```wl
ArrayElementType[TabularColumn[{"a", "b"}]]
```

<!-- => "String" -->
