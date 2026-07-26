---
Template: Symbol
Name: ArrayUnify
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayUnify
Keywords: [unification, join, common representation, tier join, domain join, element type join, mixed operands]
SeeAlso: [ArrayCoerce, ArrayTier, ArrayElementDomain, ArrayElementType, ArrayContract, ArrayContainerQ, ArrayObject]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayUnify]()[{$a_1$, $a_2$, ...}]</code> gives an [Association]() describing the common representation of the given array containers, with keys `"Tier"`, `"Domain"`, `"ElementType"` and `"Arrays"`.

## Details & Options

- `"Tier"` is the join of the operands' [ArrayTier]() values, the maximum in the order `"Explicit"` < `"Lazy"` < `"Symbolic"`.
- `"Domain"` is the join of the operands' [ArrayElementDomain]() values, the maximum in the order [Integers]() < [Rationals]() < [Algebraics]() < [Reals]() < [Complexes]().
- `"ElementType"` is the concrete numeric type of the join where it has one, and `Missing["NotApplicable"]` otherwise.
- `"Arrays"` gives the operands coerced to the joined tier by [ArrayCoerce]().
- Widening the domain never narrows the precision: the domain and the precision of the join are taken independently, so an `"Integer64"` operand joined with a `"Real32"` one gives `"Real64"` rather than `"Real32"`.
- A symbolic operand absorbs: narrowing it to a machine type would mean materializing it, which the tier join forbids, so a join carrying one has a domain and no `"ElementType"`. The domains still join, so a complex explicit operand widens a symbolic real one.
- An operand whose domain is unknown contributes nothing to the join, including every operand of the lazy tier. Only a join in which every operand is unknown has an unknown `"Domain"`.
- An operand with no lift to the joined tier is returned unchanged in `"Arrays"`. That is the lazy operand of a symbolic join: it is already a legal leaf of a symbolic tree, and materializing it is the downward move the tier join forbids.
- [ArrayContract]() over a list of containers applies these joins, giving a result whose tier is the joined tier.
- Input that is not a non-empty list of expressions satisfying [ArrayContainerQ]() gives an `ArrayUnify::nocontainers` message and stays unevaluated.

## Basic Examples

<!-- #| annotation: 27.07.26: Design review - the two components of an element spec, the domain and the precision, join independently, which is what keeps a widened domain from narrowing the precision; symbolic precision is the top of the precision order and exact precision the bottom, so symbolic absorption and the fact that an exact operand does not force exactness on a machine one both fall out of the lattice rather than being special-cased. An unknown domain is dropped from the join rather than poisoning it, since poisoning would collapse every mix involving a container that carries no element metadata. -->

Two explicit containers of different domains join to the wider one:

```wl
ArrayUnify[{{{1, 2}, {3, 4}}, {{1., 2.}, {3., 4.}}}]
```

<!-- => <|"Tier" -> "Explicit", "Domain" -> Reals, "ElementType" -> "Real64", "Arrays" -> {{{1, 2}, {3, 4}}, {{1., 2.}, {3., 4.}}}|> -->

---

The tier of a mixed operand set is the maximum of its operands' tiers:

```wl
ArrayUnify[{SparseArray[{{1, 2}, {3, 4}}], Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}]}]["Tier"]
```

<!-- => "Lazy" -->

---

Widening the domain does not narrow the precision, so an `"Integer64"` operand joined with a `"Real32"` one gives `"Real64"`:

```wl
ArrayUnify[{NumericArray[{1, 2}, "Integer64"], NumericArray[{1., 2.}, "Real32"]}]["ElementType"]
```

<!-- => "Real64" -->

## Scope

### The tier join

An explicit operand joined with a symbolic one gives the symbolic tier:

```wl
ArrayUnify[{NumericArray[{1., 2.}, "Real64"], VectorSymbol["zr", 2, Reals]}]["Tier"]
```

<!-- => "Symbolic" -->

---

The join over all three tiers is the most general of them:

```wl
ArrayUnify[{
    SparseArray[{{1, 2}, {3, 4}}],
    Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}],
    MatrixSymbol["Mr", {2, 2}, Reals]
}]["Tier"]
```

<!-- => "Symbolic" -->

### The element join

Two operands of the same domain and different widths keep the wider width:

```wl
ArrayUnify[{NumericArray[{1, 2}, "Integer8"], NumericArray[{1, 2}, "Integer64"]}]["ElementType"]
```

<!-- => "Integer64" -->

---

An unsigned operand joins to a signed type, the only rendering that holds both operands:

```wl
ArrayUnify[{NumericArray[{1, 2}, "UnsignedInteger8"], NumericArray[{1, 2}, "Integer8"]}]["ElementType"]
```

<!-- => "Integer8" -->

---

A complex operand and a real one join to the complex domain at the wider width:

```wl
ArrayUnify[{NumericArray[{1. + 2. I, 3.}, "ComplexReal32"], NumericArray[{1., 2.}, "Real64"]}]["ElementType"]
```

<!-- => "ComplexReal64" -->

---

A symbolic operand absorbs the precision of a machine one, leaving the join with a domain and no concrete type:

```wl
ArrayUnify[{VectorSymbol["zr", 2, Reals], NumericArray[{1., 2.}, "Real64"]}]["ElementType"]
```

<!-- => Missing["NotApplicable"] -->

The domains still join, so a complex explicit operand widens a symbolic real one:

```wl
ArrayUnify[{VectorSymbol["zr", 2, Reals], NumericArray[{1. + 2. I, 3.}, "ComplexReal64"]}]["Domain"]
```

<!-- => Complexes -->

---

An operand of unknown domain contributes nothing, so the join carries the domain of the operand that has one:

```wl
ArrayUnify[{{{t1, t2}, {t3, t4}}, NumericArray[{{1., 2.}, {3., 4.}}, "Real64"]}]["Domain"]
```

<!-- => Reals -->

### The coerced operands

The operands come back coerced to the joined tier, so an explicit operand of a lazy join is lifted to a constant [Function]() of a formal parameter:

```wl
ArrayUnify[{{{1, 2}, {3, 4}}, Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}]}]["Arrays"]
```

<!-- => {Function[\[FormalT], {{1, 2}, {3, 4}}], Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}]} -->

---

An explicit operand of a symbolic join is lifted to an inactive tensor product of one operand:

```wl
ArrayUnify[{{{1, 2}, {3, 4}}, MatrixSymbol["Mr", {2, 2}, Reals]}]["Arrays"]
```

<!-- => {Inactive[TensorProduct][{{1, 2}, {3, 4}}], MatrixSymbol["Mr", {2, 2}, Reals]} -->

---

A lazy operand of a symbolic join is returned unchanged, being already a legal leaf of the tree such a join builds:

```wl
ArrayUnify[{Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}], MatrixSymbol["Mr", {2, 2}, Reals]}]["Arrays"]
```

<!-- => {Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}], MatrixSymbol["Mr", {2, 2}, Reals]} -->

## Properties and Relations

[ArrayTier]() of a single container is the one-operand case of the tier join:

```wl
ArrayTier[Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}]]
```

<!-- => "Lazy" -->

---

[ArrayContract]() over a list of containers applies the joins, and its result lands on the joined tier:

```wl
ArrayTier[ArrayContract[{SparseArray[{{1, 2}, {3, 4}}], MatrixSymbol["Mr", {2, 2}, Reals]}, {{1, 3}}]]
```

<!-- => "Symbolic" -->

---

The same operand set gives that tier before the contraction is performed:

```wl
ArrayUnify[{SparseArray[{{1, 2}, {3, 4}}], MatrixSymbol["Mr", {2, 2}, Reals]}]["Tier"]
```

<!-- => "Symbolic" -->

---

A one-operand list joins to that operand's own tier and domain:

```wl
ArrayUnify[{Developer`ToPackedArray[{{1., 2.}, {3., 4.}}]}]
```

<!-- => <|"Tier" -> "Explicit", "Domain" -> Reals, "ElementType" -> "Real64", "Arrays" -> {{{1., 2.}, {3., 4.}}}|> -->

## Possible Issues

A join in which every operand has an unknown domain is itself unknown:

```wl
ArrayUnify[{{{t1, t2}, {t3, t4}}, Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}]}]["Domain"]
```

<!-- => Missing["NotApplicable"] -->

---

An operand that is not a supported container leaves the call unevaluated:

```wl
ArrayUnify[{{{1, 2}, {3, 4}}, "junk"}]
```

<!-- => ArrayUnify::nocontainers message, then ArrayUnify[{{{1, 2}, {3, 4}}, "junk"}] unevaluated -->

---

An empty operand list has nothing to join:

```wl
ArrayUnify[{}]
```

<!-- => ArrayUnify::nocontainers message, then ArrayUnify[{}] unevaluated -->
