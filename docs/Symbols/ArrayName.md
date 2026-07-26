---
Template: Symbol
Name: ArrayName
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayName
Keywords: [symbolic arrays, array name, VectorSymbol, MatrixSymbol, ArraySymbol, assumptions]
SeeAlso: [ArraySymbolicQ, ArrayDimensions, ArrayRank, SimplifyArray, ArrayPart, ArrayReplaceAll]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayName]()[*a*]</code> gives the name of the symbolic array container *a*.

## Details & Options

- The name of a [VectorSymbol](), [MatrixSymbol]() or [ArraySymbol]() is its first argument, which can be a string or a symbol.
- An atomic symbol gives itself; this covers symbols registered as arrays in [\$Assumptions]() via [Vectors](), [Matrices]() or [Arrays]() domains.
- Any other input, including explicit and lazy containers, gives [None]().

## Basic Examples

<!-- #| annotation: 26.07.26: Design review - Total accessor over containers: non-symbolic input gives None rather than staying unevaluated, so callers can branch on the result. An atomic symbol gives itself without testing $Assumptions membership, which keeps assumption-registered arrays working with no extra lookup at the cost of also naming unregistered symbols. -->

The name of a symbolic matrix:

```wl
ArrayName[MatrixSymbol["M", {2, 3}]]
```

<!-- => "M" -->

---

A name can also be a symbol:

```wl
ArrayName[VectorSymbol[v, 3]]
```

<!-- => v -->

---

An explicit container has no name:

```wl
ArrayName[SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => None -->

## Scope

The name of an [ArraySymbol]():

```wl
ArrayName[ArraySymbol["T", {2, 3, 4}]]
```

<!-- => "T" -->

---

An assumption-registered symbol is its own name:

```wl
Block[{$Assumptions = Element[a, Matrices[{2, 2}]]}, {ArrayName[a], ArrayDimensions[a]}]
```

<!-- => {a, {2, 2}} -->

---

Non-container input gives [None]():

```wl
ArrayName[{1, 2}]
```

<!-- => None -->

---

A lazy container has no name:

```wl
sol = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}];
ArrayName[sol[tau]]
```

<!-- => None -->

## Properties and Relations

[ArrayReplaceAll]() can rename a symbolic container by rewriting its name:

```wl
ArrayName[ArrayReplaceAll[MatrixSymbol["M", {2, 3}], "M" -> "M2"]]
```

<!-- => "M2" -->

## Possible Issues

[ArrayName]() does not test array membership: any atomic symbol gives itself, whether or not it is registered in [\$Assumptions]():

```wl
ArrayName[x]
```

<!-- => x -->
