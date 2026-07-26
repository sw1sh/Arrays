---
Template: Symbol
Name: ArrayPack
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayPack
Keywords: [packed array, machine precision, type coercion, array container]
SeeAlso: [ArrayMaterialize, ArrayExplicitQ, ArrayNumericQ, ArrayNumberQ, ArrayMap, ArrayElementType, ArrayCoerce]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayPack]()[*a*]</code> gives a best-effort packed array conversion of an explicit array container; any input that cannot be packed faithfully, including lazy and symbolic containers, is returned unchanged.

## Details & Options

- [ArrayPack]() tries the plain, [Real]() and [Complex]() forms of `` Developer`ToPackedArray `` in turn.
- The coercing [Real]() and [Complex]() forms are accepted only when every value survives at machine precision, verified by a [SetPrecision]() round trip; an array containing an exact value such as `1/3` or `2^200 + 1` is returned unchanged.
- The [Complex]() fallback packs the mixed Integer/Complex lists that [Normal]() of a numeric [SparseArray]() with complex entries produces, which the plain form leaves unpacked.
- A non-[List]() explicit container packs its [ArrayMaterialize]() data, which routes wrapper heads through their dedicated materialization paths: magnitudes for [QuantityArray](), per-column [Normal]() for a named [Tabular](), and so on; the packed result replaces the container only when packing succeeds.
- Lazy and symbolic containers, and any list that fails the machine-precision check, are returned unchanged.

## Basic Examples

<!-- #| annotation: 26.07.26: Design review - Best-effort with a fidelity guard: coercing pack forms are accepted only when a SetPrecision round trip shows every value survives at machine precision, so exact values are never silently destroyed and ArrayPack is always safe to apply (anything unpackable comes back unchanged). The Complex fallback exists for the mixed Integer/Complex lists Normal of a complex SparseArray produces. -->

Pack a mixed integer and real list; the integer is coerced to a machine real, giving a packed [Real]() array:

```wl
ArrayPack[{1, 2.5}]
```

<!-- => {1., 2.5} (packed Real array) -->

---

Exact rationals do not survive machine precision, so the list is returned unchanged:

```wl
ArrayPack[{1/2, 1/3}]
```

<!-- => {1/2, 1/3} -->

## Scope

[Normal]() of a complex-valued [SparseArray]() produces a mixed Integer/Complex list:

```wl
Normal[SparseArray[{1 -> 1, 2 -> I}, 3]]
```

<!-- => {1, I, 0} (unpacked) -->

The plain packing form hands that list back element for element, still unpacked:

```wl
Developer`ToPackedArray[Normal[SparseArray[{1 -> 1, 2 -> I}, 3]]]
```

<!-- => {1, I, 0} (unpacked) -->

The [Complex]() fallback coerces every entry to a machine complex, giving a packed array whose values survive at machine precision:

```wl
ArrayPack[Normal[SparseArray[{1 -> 1, 2 -> I}, 3]]]
```

<!-- => {1. + 0.*I, 0. + 1.*I, 0. + 0.*I} (packed Complex array) -->

---

A [SparseArray]() packs its materialized data:

```wl
ArrayPack[SparseArray[{1 -> 1, 2 -> I}, 3]]
```

<!-- => {1. + 0.*I, 0. + 1.*I, 0. + 0.*I} (packed Complex array) -->

---

A [QuantityArray]() packs its magnitudes through the [ArrayMaterialize]() route:

```wl
ArrayPack[QuantityArray[{1, 2, 3}, "Meters"]]
```

<!-- => {1, 2, 3} (packed Integer array) -->

---

A symbolic container is returned unchanged:

```wl
ArrayPack[MatrixSymbol["M", {2, 3}]]
```

<!-- => MatrixSymbol["M", {2, 3}] -->

---

A list of symbolic elements cannot pack and is returned unchanged:

```wl
ArrayPack[{{a1, a2}, {a3, a4}}]
```

<!-- => {{a1, a2}, {a3, a4}} -->

## Possible Issues

An integer too large for a machine integer would not survive coercion, so the exact-value guard leaves the list unchanged:

```wl
ArrayPack[{1, 2^200 + 1}]
```

<!-- => {1, 1606938044258990275541962092341162602522202993782792835301377} -->

---

One unrepresentable exact value keeps the whole array unpacked; the inexact entries are not coerced separately:

```wl
ArrayPack[{1/3, 0.5}]
```

<!-- => {1/3, 0.5} -->

---

Packing a [SparseArray]() trades the sparse container for a packed dense array in which every implicit zero is stored; for large sparse data keep the container and use [ArrayExplicitValues]() instead:

```wl
ArrayPack[SparseArray[{1 -> 1., 5 -> 2.}, 10]]
```

<!-- => {1., 0., 0., 0., 2., 0., 0., 0., 0., 0.} (packed Real array) -->
