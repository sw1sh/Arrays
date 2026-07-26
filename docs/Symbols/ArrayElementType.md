---
Template: Symbol
Name: ArrayElementType
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayElementType
Keywords: [element type, numeric type, numeric array type, column element type, element metadata]
SeeAlso: [ArrayElementDomain, ArrayUnify, ArrayCoerce, ArrayTier, ArrayNumberQ, ArrayObject]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayElementType]()[*a*]</code> gives the concrete element type stored by the array container *a*, such as `"Real64"` or `"Integer32"`.

## Details & Options

- A [NumericArray]() gives its [NumericArrayType](), and a [TabularColumn]() its `"ElementType"`.
- Every other container gives `Missing["NotApplicable"]` and describes its elements through [ArrayElementDomain]() instead.
- A type name is a domain together with a machine precision: `"Integer64"`, `"UnsignedInteger8"`, `"Real32"` and `"ComplexReal64"` all map into the five domains of [ArrayElementDomain](), keeping their bit width. A column type that is not numeric, such as `"String"`, has a type but no domain.
- [ArrayUnify]() gives the concrete type of a joined operand set as its `"ElementType"` key, where the join has one. A join with a symbolic or exact operand has a domain and no machine precision, and so no element type.
- [ArrayCoerce]() to a concrete element type gives a [NumericArray]() of that type.
- <code>[ArrayObject]()[*a*]["ElementType"]</code> gives the same type, and the collapsed summary box of a container that carries one shows it.

## Basic Examples

<!-- #| annotation: 27.07.26: Design review - this stays the CONCRETE container type rather than being generalized to cover every container: the gap it leaves, a QuantityArray of reals that stores no type, is exactly what ArrayElementDomain fills, and keeping the two separate is what lets a type name and a declared domain be two spellings of one lattice rather than one property with two meanings. -->

A [NumericArray]() reports the type it stores:

```wl
ArrayElementType[NumericArray[{1., 2.}]]
```

<!-- => "Real64" -->

---

An integer buffer reports its width:

```wl
ArrayElementType[NumericArray[{1, 2}, "Integer32"]]
```

<!-- => "Integer32" -->

---

A [TabularColumn]() reports its column element type:

```wl
ArrayElementType[TabularColumn[{1., 2.}]]
```

<!-- => "Real64" -->

## Scope

An unsigned type is reported as stored, and is not folded into the signed one:

```wl
ArrayElementType[NumericArray[{1, 2}, "UnsignedInteger8"]]
```

<!-- => "UnsignedInteger8" -->

---

A complex buffer reports the complex type:

```wl
ArrayElementType[NumericArray[{1. + 2. I, 3.}, "ComplexReal64"]]
```

<!-- => "ComplexReal64" -->

---

A column of exact integers stores them at machine width:

```wl
ArrayElementType[TabularColumn[{1, 2}]]
```

<!-- => "Integer64" -->

---

A column type need not be numeric:

```wl
ArrayElementType[TabularColumn[{"a", "b"}]]
```

<!-- => "String" -->

## Properties and Relations

An [ArrayObject]() handle reports the same type:

```wl
ArrayObject[NumericArray[{1, 2}, "Integer32"]]["ElementType"]
```

<!-- => "Integer32" -->

---

[ArrayElementDomain]() answers for a container that stores no element type, so a [SparseArray]() of integers has a domain:

```wl
ArrayElementDomain[SparseArray[{{1, 2}, {3, 4}}]]
```

<!-- => Integers -->

---

[ArrayUnify]() gives the concrete type of a joined operand set, and widening the domain does not narrow the precision, so an `"Integer64"` operand joined with a `"Real32"` one gives `"Real64"`:

```wl
ArrayUnify[{NumericArray[{1, 2}, "Integer64"], NumericArray[{1., 2.}, "Real32"]}]["ElementType"]
```

<!-- => "Real64" -->

---

[ArrayCoerce]() to a concrete type gives a [NumericArray]() of that type:

```wl
ArrayElementType[ArrayCoerce[NumericArray[{1., 2.}, "Real32"], "Real64"]]
```

<!-- => "Real64" -->

## Possible Issues

A [SparseArray]() stores no element type, describing its elements through its domain instead:

```wl
ArrayElementType[SparseArray[{{1, 2}, {3, 4}}]]
```

<!-- => Missing["NotApplicable"] -->

---

A [QuantityArray]() carries a unit rather than an element type:

```wl
ArrayElementType[QuantityArray[{1., 2.}, "Meters"]]
```

<!-- => Missing["NotApplicable"] -->

---

A symbolic container has no stored elements and so no stored type:

```wl
ArrayElementType[VectorSymbol["z", 2, Reals]]
```

<!-- => Missing["NotApplicable"] -->
