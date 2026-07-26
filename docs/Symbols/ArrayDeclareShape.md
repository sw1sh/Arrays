---
Template: Symbol
Name: ArrayDeclareShape
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayDeclareShape
Keywords: [shape declaration, lazy container, function shape, shape probe, array container]
SeeAlso: [ArrayLazyQ, ArrayDimensions, ArrayContainerQ, ArrayMaterialize, ArrayReplaceAll, ArrayRank]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayDeclareShape]()[*f*, *dims*]</code> declares *dims* as the shape of the lazy container *f*.

<code>[ArrayDeclareShape]()[*f*]</code> gives the shape declared for *f*.

<code>[ArrayDeclareShape]()[*f*, [None]()]</code> removes the declaration for *f*.

<code>[ArrayDeclareShape]()[[All](), [None]()]</code> removes every declaration.

## Details & Options

- Shape discovery for an unapplied [Function]() is a three-step protocol: a caller declaration made with [ArrayDeclareShape](), then a formal-symbol probe that applies *f* to formal symbols, then a numeric probe that applies *f* at a random point in the unit interval. The first step that yields an array of positive shape settles the shape; when all three fail, *f* is not an array container and no shape is guessed.
- The declaration is consulted before both probes, so it both corrects a shape a probe got wrong and keeps the probes from running.
- Both probes evaluate the body of *f*, so recognizing an undeclared [Function]() runs it once. A [Function]() with side effects or an expensive body is declared rather than probed.
- Only a successful probe is memoized; a probe that finds no array shape is repeated on the next query.
- <code>[ArrayDeclareShape]()[*f*, [None]()]</code> removes the memoized probe result along with the declaration, so the next shape query probes *f* afresh rather than restoring the earlier probed value.
- *dims* must be a list of positive integers, or [None](). Any other specification gives the `ArrayDeclareShape::baddims` message and leaves the call unevaluated.
- Only a lazy head that consults caller declarations accepts one; today that is an unapplied [Function]() of a supported form: <code>[Function]()[*x*, *body*]</code>, <code>[Function]()[{$x_1$, ...}, *body*]</code> and the slot form <code>[Function]()[*body*]</code>. Any other expression, including a three-argument [Function]() and an explicit array, gives the `ArrayDeclareShape::undeclarable` message and leaves the call unevaluated.
- A declared shape admits *f* to the lazy tier: [ArrayLazyQ]() and [ArrayContainerQ]() give True, [ArrayDimensions]() gives *dims*, and [ArrayMaterialize]() expands *f* to an array of that shape.
- The body of a declared [Function]() need not be an explicit array, so [ArrayMaterialize]() gives one scalar [Function]() of the same parameters per position, each wrapping an [Indexed]() of the body.
- A query for an expression with no declaration gives <code>Missing["NotDeclared"]</code>.

## Basic Examples

<!-- #| annotation: 27.07.26: Design review - the declaration is consulted BEFORE the two probes rather than only as their fallback, which makes it the correction for a wrong probed shape as well as the only way to ask a Function for its shape without evaluating its body; the probe memo is invalidated together with the declaration, so a wrong probe cannot be frozen in for the session. The tables are keyed on the whole container expression rather than on a name, so nothing has to be registered before a Function is used. Compared with an array type declaration in a compiled language, this is per-expression session state consulted at call time, not a compile-time annotation, and it is confined to the one lazy head that has no shape property to read. -->

Neither probe settles the shape of a [Function]() whose body stays an unevaluated [If]() at the formal symbol and fails at the numeric point, so it is not a lazy container:

```wl
branchy = Function[q, If[q > 2, {1., 2.}, $Failed]];
ArrayLazyQ[branchy]
```

<!-- => False -->

Declaring the shape records it and gives it back:

```wl
ArrayDeclareShape[branchy, {2}]
```

<!-- => {2} -->

The declaration admits the [Function]() to the lazy tier:

```wl
ArrayLazyQ[branchy]
```

<!-- => True -->

[ArrayDimensions]() now answers from the declaration:

```wl
ArrayDimensions[branchy]
```

<!-- => {2} -->

---

The one-argument form queries the declaration:

```wl
ArrayDeclareShape[branchy]
```

<!-- => {2} -->

---

A declaration of [None]() removes it:

```wl
ArrayDeclareShape[branchy, None]
```

<!-- => None -->

Without a shape the [Function]() leaves the lazy tier again:

```wl
ArrayLazyQ[branchy]
```

<!-- => False -->

## Scope

Substituting the parameter of a declared container applies the [Function]() once, for the whole array:

```wl
ArrayDeclareShape[branchy, {2}];
ArrayReplaceAll[branchy, q -> 3]
```

<!-- => {1., 2.} -->

---

The body of a declared container need not be an explicit array, so materialization gives one scalar [Function]() per position, each indexing the body:

```wl
ArrayMaterialize[branchy]
```

<!-- => {Function[q, Indexed[If[q > 2, {1., 2.}, $Failed], {1}]], Function[q, Indexed[If[q > 2, {1., 2.}, $Failed], {2}]]} -->

---

[ArrayPart]() takes one element of that expansion, again a scalar [Function]() of the same parameter:

```wl
ArrayPart[branchy, {1}]
```

<!-- => Function[q, Indexed[If[q > 2, {1., 2.}, $Failed], {1}]] -->

---

A body that degenerates to an empty list at the probe point has no probed shape, and a declaration supplies one:

```wl
counted = Function[k, Table[1., {k}]];
ArrayDimensions[counted]
```

<!-- => {} -->

With a declared shape the container substitutes to an array of that length:

```wl
ArrayDeclareShape[counted, {3}];
ArrayReplaceAll[counted, k -> 3]
```

<!-- => {1., 1., 1.} -->

---

The slot form of a [Function]() accepts a declaration too:

```wl
ArrayDeclareShape[Function[{Cos[#], Sin[#]}], {2}]
```

<!-- => {2} -->

---

<code>[ArrayDeclareShape]()[[All](), [None]()]</code> clears every declaration and every memoized probe result:

```wl
ArrayDeclareShape[All, None]
```

<!-- => None -->

The containers admitted by declaration alone leave the lazy tier with it:

```wl
ArrayLazyQ[branchy]
```

<!-- => False -->

## Properties and Relations

A probed shape can go stale, since it is memoized and the body of a [Function]() may close over outer state; here the shape is probed while the outer count is 2:

```wl
count = 2;
sized = Function[u, ConstantArray[u, count]];
ArrayDimensions[sized]
```

<!-- => {2} -->

Raising the count does not change the memoized answer:

```wl
count = 5;
ArrayDimensions[sized]
```

<!-- => {2} -->

A declaration is consulted before the probes, so it overrides the memoized shape:

```wl
ArrayDeclareShape[sized, {5}];
ArrayDimensions[sized]
```

<!-- => {5} -->

Removing the declaration drops the memoized probe result with it, so the shape is probed afresh rather than reverting to the stale value:

```wl
ArrayDeclareShape[sized, None];
ArrayDimensions[sized]
```

<!-- => {5} -->

---

The probes evaluate the body of *f*, so a declared shape is also how a [Function]() with side effects is kept from running; here the body increments a counter:

```wl
hits = 0;
observed = Function[s, (hits++; {Sin[s], Cos[s]})];
ArrayDeclareShape[observed, {2}];
ArrayDimensions[observed]
```

<!-- => {2} -->

The counter shows that no probe ran:

```wl
hits
```

<!-- => 0 -->

Without the declaration the shape comes from a probe, which runs the body:

```wl
ArrayDeclareShape[observed, None];
ArrayLazyQ[observed]
```

<!-- => True -->

The counter records that run:

```wl
hits
```

<!-- => 1 -->

## Possible Issues

A shape that is not a list of positive integers is refused and the call is left unevaluated:

```wl
ArrayDeclareShape[Function[q, {q, q}], {0}]
```

<!-- => ArrayDeclareShape::baddims, then ArrayDeclareShape[Function[q, {q, q}], {0}] unevaluated -->

---

An expression whose head consults no caller declaration is refused, rather than recording a declaration that nothing would ever read:

```wl
ArrayDeclareShape[{1, 2, 3}, {7}]
```

<!-- => ArrayDeclareShape::undeclarable, then ArrayDeclareShape[{1, 2, 3}, {7}] unevaluated -->

---

A three-argument [Function]() carries attributes that a structural rebuild could not preserve and is not a supported form:

```wl
ArrayDeclareShape[Function[q, {q, q}, HoldAll], {2}]
```

<!-- => ArrayDeclareShape::undeclarable, then ArrayDeclareShape[Function[q, {q, q}, HoldAll], {2}] unevaluated -->

---

Querying an expression with no declaration gives a [Missing]() result, whether or not its shape is discoverable by probing:

```wl
ArrayDeclareShape[Function[w, {w, w}]]
```

<!-- => Missing["NotDeclared"] -->
