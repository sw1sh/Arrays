---
Template: Symbol
Name: ArrayCoerce
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayCoerce
Keywords: [coercion, tier lift, widening, narrowing, element type, constant function, inactive tensor product]
SeeAlso: [ArrayUnify, ArrayTier, ArrayElementDomain, ArrayElementType, ArrayMaterialize, ArrayPack, ArrayContainerQ]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayCoerce]()[*a*, *spec*]</code> coerces the array container *a* toward *spec*, which names a tier, an element domain, an element type, or a list of a tier and one of those.

## Details & Options

- A tier specification is `"Explicit"`, `"Lazy"` or `"Symbolic"`; an element domain is [Integers](), [Rationals](), [Algebraics](), [Reals]() or [Complexes](); an element type is a numeric type name such as `"Real64"` or `"Integer32"`.
- Coercion may only move up both lattices, the tier order `"Explicit"` < `"Lazy"` < `"Symbolic"` and the element order of [ArrayElementDomain]() together with the precision order of the machine widths.
- Up the tier lattice the lift is free. An explicit container lifts to the lazy tier as a constant [Function]() of a formal parameter, materializing a container whose form is not a plain array first, and to the symbolic tier as an [Inactive]() [TensorProduct]() of one operand. Both are containers of the same shape whose materialization gives the array back.
- Coercing to the tier a container already occupies leaves it unchanged.
- Coercing to an element domain alone changes nothing, a domain being an upper bound on the elements that a narrower container already meets.
- Coercing to a concrete element type gives a [NumericArray]() of that type. The conversion is the kernel's, and a value that does not survive the target type is a refusal rather than a rounded value.
- Every refusal gives a message and leaves the call unevaluated, rather than casting silently:

| Message | Case |
|---|---|
| `ArrayCoerce::materialize` | a request to move down the tier lattice, which [ArrayMaterialize]() performs explicitly |
| `ArrayCoerce::narrow` | a narrowing of the element domain or precision, or a source container whose domain is unknown |
| `ArrayCoerce::notier` | a lazy container asked for the symbolic tier, which has no leafless form |
| `ArrayCoerce::badspec` | a specification that names no tier, domain or element type |
| `ArrayCoerce::nocontainer` | input that is not a supported array container |
| `ArrayCoerce::coerce` | a legal target that this container's values do not survive |

- A lazy container reaches the symbolic tier only as an operand of a structural tree that also carries a symbolic container, which is what [ArrayUnify]() leaves it as.
- Narrowing a symbolic container to a machine type is the `ArrayCoerce::narrow` refusal, symbolic absorption stated as a coercion: the only route to a machine type is materialization.

## Basic Examples

<!-- #| annotation: 27.07.26: Design review - legality is decided by the lattices alone, up or equal on both axes, so the guard is one comparison per axis and the refusal analysis reports which axis it was. Both lattice comparisons are total, an unrecognized component reading below every rung, so an unrecognized specification makes the target illegal rather than leaving the guard stalled on a non-boolean comparison and declining with no message at all. -->

Lifting an explicit array to the lazy tier gives a constant [Function]() of a formal parameter:

```wl
ArrayCoerce[{{1, 2}, {3, 4}}, "Lazy"]
```

<!-- => Function[\[FormalT], {{1, 2}, {3, 4}}] -->

---

Lifting it to the symbolic tier gives an inactive tensor product of one operand:

```wl
ArrayCoerce[{{1, 2}, {3, 4}}, "Symbolic"]
```

<!-- => Inactive[TensorProduct][{{1, 2}, {3, 4}}] -->

---

Coercing to a wider element type gives a [NumericArray]() of that type:

```wl
ArrayCoerce[NumericArray[{1., 2.}, "Real32"], "Real64"]
```

<!-- => NumericArray summary box: Real64, dimensions {2} -->

## Scope

### Tier lifts

The lazy lift keeps the shape, without evaluating anything:

```wl
ArrayDimensions[ArrayCoerce[{{1, 2}, {3, 4}}, "Lazy"]]
```

<!-- => {2, 2} -->

---

Binding the formal parameter to anything at all gives the array back in one whole-array evaluation:

```wl
ArrayCoerce[{{1, 2}, {3, 4}}, "Lazy"][0]
```

<!-- => {{1, 2}, {3, 4}} -->

---

A container whose form is not a plain array is materialized into the lift, so a [QuantityArray]() lifts around its own head:

```wl
ArrayCoerce[QuantityArray[{1., 2.}, "Meters"], "Lazy"]
```

<!-- => Function[\[FormalT], QuantityArray summary box of {1., 2.} meters] -->

---

The symbolic lift materializes back to the array it wraps:

```wl
ArrayMaterialize[ArrayCoerce[{{1, 2}, {3, 4}}, "Symbolic"]]
```

<!-- => {{1, 2}, {3, 4}} -->

---

Coercing to the tier a container already occupies leaves it unchanged:

```wl
ArrayCoerce[Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}], "Lazy"]
```

<!-- => Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}] -->

### Element coercions

Coercing to a domain alone changes nothing, a domain being an upper bound the container already meets:

```wl
ArrayCoerce[{{1, 2}, {3, 4}}, Reals]
```

<!-- => {{1, 2}, {3, 4}} -->

---

Widening a symbolic container's declared domain leaves the container as it is too:

```wl
ArrayCoerce[VectorSymbol["zr", 2, Reals], Complexes]
```

<!-- => VectorSymbol["zr", 2, Reals] -->

---

A plain list coerces to a typed buffer:

```wl
ArrayCoerce[{1, 2, 3}, "Real64"]
```

<!-- => NumericArray summary box: Real64, dimensions {3} -->

---

Exact integers carry no machine precision, so a narrow integer type is a widening of them:

```wl
ArrayCoerce[{1, 2}, "Integer8"]
```

<!-- => NumericArray summary box: Integer8, dimensions {2} -->

---

A tier and an element type coerce together, the conversion happening before the lift:

```wl
ArrayCoerce[{{1, 2}, {3, 4}}, {"Lazy", "Real64"}]
```

<!-- => Function[\[FormalT], {{1., 2.}, {3., 4.}}] -->

## Properties and Relations

[ArrayTier]() of a lifted container reports the tier it was lifted to:

```wl
ArrayTier[ArrayCoerce[{{1, 2}, {3, 4}}, {"Lazy", "Real64"}]]
```

<!-- => "Lazy" -->

---

[ArrayElementType]() of a container coerced to a concrete type reports that type:

```wl
ArrayElementType[ArrayCoerce[NumericArray[{1., 2.}, "Real32"], "Real64"]]
```

<!-- => "Real64" -->

---

[ArrayUnify]() coerces each operand to the joined tier, which is this lift applied across an operand set:

```wl
ArrayUnify[{{{1, 2}, {3, 4}}, Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}]}]["Arrays"]
```

<!-- => {Function[\[FormalT], {{1, 2}, {3, 4}}], Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}]} -->

---

[ArrayMaterialize]() performs the downward move that coercion refuses:

```wl
ArrayMaterialize[Piecewise[{{{1., 2.}, zz < 0}}, {3., 4.}]]
```

<!-- => {Piecewise[{{1., zz < 0}}, 3.], Piecewise[{{2., zz < 0}}, 4.]} -->

## Possible Issues

Moving down the tier lattice is materialization, and is refused:

```wl
ArrayCoerce[Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}], "Explicit"]
```

<!-- => ArrayCoerce::materialize message, then ArrayCoerce[Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}], "Explicit"] unevaluated -->

---

A symbolic container has no lazy form either, for the same reason:

```wl
ArrayCoerce[VectorSymbol["zr", 2, Reals], "Lazy"]
```

<!-- => ArrayCoerce::materialize message, then ArrayCoerce[VectorSymbol["zr", 2, Reals], "Lazy"] unevaluated -->

---

Narrowing the precision loses values:

```wl
ArrayCoerce[NumericArray[{1., 2.}, "Real64"], "Real32"]
```

<!-- => ArrayCoerce::narrow message, then ArrayCoerce[NumericArray[{1., 2.}, "Real64"], "Real32"] unevaluated -->

---

Narrowing the domain loses values in the same way:

```wl
ArrayCoerce[Developer`ToPackedArray[{{1., 2.}, {3., 4.}}], Integers]
```

<!-- => ArrayCoerce::narrow message, then ArrayCoerce[{{1., 2.}, {3., 4.}}, Integers] unevaluated -->

---

A symbolic container cannot be narrowed to a machine type, which is symbolic absorption stated as a coercion:

```wl
ArrayCoerce[VectorSymbol["zr", 2, Reals], "Real64"]
```

<!-- => ArrayCoerce::narrow message, then ArrayCoerce[VectorSymbol["zr", 2, Reals], "Real64"] unevaluated -->

---

A container whose element domain is unknown cannot be widened from anything:

```wl
ArrayCoerce[{{t1, t2}, {t3, t4}}, "Real64"]
```

<!-- => ArrayCoerce::narrow message, then ArrayCoerce[{{t1, t2}, {t3, t4}}, "Real64"] unevaluated -->

---

A lazy container has no leafless symbolic form, and enters that tier only as an operand of a tree carrying a symbolic container:

```wl
ArrayCoerce[Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}], "Symbolic"]
```

<!-- => ArrayCoerce::notier message, then ArrayCoerce[Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}], "Symbolic"] unevaluated -->

---

A specification that names no tier, domain or element type is rejected as one:

```wl
ArrayCoerce[{{1, 2}, {3, 4}}, "Bogus"]
```

<!-- => ArrayCoerce::badspec message, then ArrayCoerce[{{1, 2}, {3, 4}}, "Bogus"] unevaluated -->

---

A type name whose bit width has no place in the precision order is a specification of that kind too:

```wl
ArrayCoerce[NumericArray[{1., 2.}, "Real64"], "Real24"]
```

<!-- => ArrayCoerce::badspec message, then ArrayCoerce[NumericArray[{1., 2.}, "Real64"], "Real24"] unevaluated -->

---

A value that the target type cannot hold is a refusal rather than a rounded value:

```wl
ArrayCoerce[{1, 2^100}, "Integer8"]
```

<!-- => ArrayCoerce::coerce message, then ArrayCoerce[{1, 1267650600228229401496703205376}, "Integer8"] unevaluated -->

---

Input that is not a supported array container is declined before any target is considered:

```wl
ArrayCoerce["junk", "Lazy"]
```

<!-- => ArrayCoerce::nocontainer message, then ArrayCoerce["junk", "Lazy"] unevaluated -->
