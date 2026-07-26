---
Template: Symbol
Name: ArrayLazyQ
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayLazyQ
Keywords: [lazy array, parametric array, interpolating function, piecewise, neural net, array container, predicate]
SeeAlso: [ArrayContainerQ, ArrayExplicitQ, ArraySymbolicQ, ArrayComputeNativeQ, ArrayDimensions, ArrayDeclareShape, ArrayReplaceAll, ArrayMaterialize, ArrayTier]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayLazyQ]()[*a*]</code> gives True if *a* is a lazy parametric array container: an inert array-valued expression whose head is registered in the lazy tier.

## Details & Options

- A lazy container carries no elements: its shape is introspectable without evaluating it, and evaluating it is what produces the array.
- The registered heads are an array-valued [InterpolatingFunction]() application, a fully applied array-valued [ParametricFunction](), an unapplied array-valued [Function](), an array-valued [Piecewise]() and a source [NetGraph]() or [NetChain]().
- An <code>[InterpolatingFunction]()[...][*t*]</code> is lazy when its `"OutputDimensions"` are non-empty and at least one argument is non-numeric.
- A [ParametricFunction]() is lazy only in its fully applied form <code>*pf*[*params*][*t*]</code>, with at least one non-numeric argument: substituting every parameter of <code>*pf*[*params*]</code> gives an [InterpolatingFunction](), a function rather than an array, and the bare object has nothing bound at all.
- A [Function]() is stored unapplied, since applying it evaluates it, so the container is the [Function]() itself and its parameters are bound rather than free. Supported forms are <code>[Function]()[*x*, *body*]</code>, <code>[Function]()[{$x_1$, ...}, *body*]</code> and the slot form <code>[Function]()[*body*]</code>; a three-argument [Function]() and a [SlotSequence]() body are declined.
- The shape of a [Function]() comes from a three-step protocol: an [ArrayDeclareShape]() declaration, a formal-symbol probe, then a numeric probe. Both probes evaluate the body, so recognizing an undeclared [Function]() runs it once; a declaration is consulted first and skips them.
- A [Piecewise]() is lazy when every branch value and the default are arrays of one shape. The scalar default that [Piecewise]() supplies for a branch-only specification is declined, since a substitution falling through every condition would then give a scalar.
- A [NetGraph]() or [NetChain]() is lazy when it is a source net, one with no open input ports, whose output port reports a positive integer dimension list; its value is <code>*net*[]</code>. A net with open inputs is a function of those inputs and is declined.
- The non-numeric test is [NumericQ](), so exact numeric arguments such as $\pi/4$ evaluate an applied form rather than keeping it lazy.
- [ArrayDimensions]() reads the shape per head, never by materializing: the output dimensions of an [InterpolatingFunction](), the common branch shape of a [Piecewise](), the output port of a net, one cached probe solve for a [ParametricFunction](), and the declared or probed shape of a [Function]().
- [ArrayReplaceAll]() substitutes the whole lazy expression at once, so substituting all parameters evaluates the array-valued function a single time.
- Structural operations keep the container lazy where its head supplies a lazy-preserving rebuild: the value grid of an [InterpolatingFunction]() is remapped and reinterpolated, the branch values of a [Piecewise]() are transformed in place, and the body of a [Function]() is transformed and re-abstracted. A [ParametricFunction]() and a net have no rebuild, so their structural operations materialize first.
- The stored-value accessors [ArrayExplicitValues](), [ArrayExplicitPositions]() and [ArrayExplicitLength]() give <code>Missing["NotExplicit"]</code> for lazy containers.

## Basic Examples

<!-- #| annotation: 27.07.26: Design review - the tier is head-driven rather than pattern-driven: one registration per head carries recognition, shape, materialization, substitution and the lazy-preserving rebuild, and the rest of the paclet dispatches through the registry without naming a head. The admission criterion is the same one the explicit tier uses - a shape readable without materializing plus a materialization path - which is what draws the line between the fully applied ParametricFunction (admitted) and the bare or partially applied one (declined), and between a source net (admitted) and a net with open input ports (declined). -->

Solve a vector-valued ODE, giving an array-valued [InterpolatingFunction]():

```wl
v = NDSolveValue[{f'[t] == {{0, 1}, {-1, 0}} . f[t], f[0] == {1., 0.}}, f, {t, 0, 1}]
```

<!-- => InterpolatingFunction[{{0., 1.}}, "<>"] summary box -->

Applied to a symbolic parameter, it is a lazy parametric container:

```wl
ArrayLazyQ[v[tau]]
```

<!-- => True -->

Applied to a numeric argument, the expression is no longer lazy:

```wl
ArrayLazyQ[v[0.5]]
```

<!-- => False -->

---

It has evaluated to an explicit array instead:

```wl
ArrayExplicitQ[v[0.5]]
```

<!-- => True -->

---

An unapplied array-valued [Function]() is a lazy container as it stands:

```wl
rotation = Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}];
ArrayLazyQ[rotation]
```

<!-- => True -->

## Scope

### Interpolating functions

The shape is introspectable without materializing:

```wl
ArrayDimensions[v[tau]]
```

<!-- => {2} -->

---

A scalar-valued [InterpolatingFunction]() application is not a lazy container:

```wl
u = NDSolveValue[{g'[t] == -g[t], g[0] == 1.}, g, {t, 0, 1}];
ArrayLazyQ[u[tau]]
```

<!-- => False -->

---

Structural operations keep a matrix-valued container lazy:

```wl
m = NDSolveValue[{h'[t] == {{0, 1}, {-1, 0}} . h[t], h[0] == {{1., 0.}, {0., 1.}}}, h, {t, 0, 1}];
ArrayLazyQ[ArrayTranspose[m[tau], {2, 1}]]
```

<!-- => True -->

### Parametric functions

A [ParametricNDSolveValue]() solution is a [ParametricFunction]() of its parameters:

```wl
pf = ParametricNDSolveValue[{y'[t] == {{0, pa}, {-pa, 0}} . y[t], y[0] == {1., 0.}}, y, {t, 0, 1}, {pa}]
```

<!-- => ParametricFunction[...] summary box, parameter pa -->

Fully applied to a symbolic parameter and a symbolic time, it is a lazy container:

```wl
ArrayLazyQ[pf[aa][tt]]
```

<!-- => True -->

Its shape comes from a single cached probe solve:

```wl
ArrayDimensions[pf[aa][tt]]
```

<!-- => {2} -->

---

The bare object is a function of its parameters, not an array, so it is not a container:

```wl
ArrayLazyQ[pf]
```

<!-- => False -->

---

The partially applied form gives an [InterpolatingFunction]() once its parameters are numeric, again a function rather than an array:

```wl
ArrayLazyQ[pf[aa]]
```

<!-- => False -->

### Unapplied functions

The shape of a supported [Function]() is discovered without a declaration where a probe settles it:

```wl
ArrayDimensions[rotation]
```

<!-- => {2, 2} -->

---

A scalar-valued [Function]() is not an array container:

```wl
ArrayLazyQ[Function[q, q^2]]
```

<!-- => False -->

---

The slot form is supported:

```wl
ArrayLazyQ[Function[{Cos[#], Sin[#]}]]
```

<!-- => True -->

---

A three-argument [Function]() carries attributes that a structural rebuild could not preserve and is declined:

```wl
ArrayLazyQ[Function[q, {q, q}, HoldAll]]
```

<!-- => False -->

---

A [SlotSequence]() body has no fixed arity and is declined as well:

```wl
ArrayLazyQ[Function[{##}]]
```

<!-- => False -->

---

Where neither probe settles a shape, [ArrayDeclareShape]() supplies one and the [Function]() becomes a container:

```wl
branchy = Function[q, If[q > 2, {1., 2.}, $Failed]];
ArrayDeclareShape[branchy, {2}];
ArrayLazyQ[branchy]
```

<!-- => True -->

### Piecewise arrays

An array-valued [Piecewise]() with an undecidable condition is a lazy container:

```wl
pw = Piecewise[{{{{1., 2.}, {3., 4.}}, zz < 0}}, {{5., 6.}, {7., 8.}}];
ArrayLazyQ[pw]
```

<!-- => True -->

Its shape is the common shape of the branch values and the default:

```wl
ArrayDimensions[pw]
```

<!-- => {2, 2} -->

---

A scalar-valued [Piecewise]() is not an array container:

```wl
ArrayLazyQ[Piecewise[{{1, zz < 0}}, 2]]
```

<!-- => False -->

---

A branch-only specification takes the scalar default that [Piecewise]() supplies, and is declined:

```wl
ArrayLazyQ[Piecewise[{{{1., 2.}, zz < 0}}]]
```

<!-- => False -->

---

Branch values whose shapes disagree are declined too:

```wl
ArrayLazyQ[Piecewise[{{{1., 2.}, zz < 0}}, {3., 4., 5.}]]
```

<!-- => False -->

### Source nets

A [NetGraph]() with no open input ports is a lazy container:

```wl
net = NetGraph[{NetArrayLayer["Array" -> {{1., 2., 3.}, {4., 5., 6.}}]}, {1 -> NetPort["Output"]}];
ArrayLazyQ[net]
```

<!-- => True -->

Its shape is read off the output port, without running the net:

```wl
ArrayDimensions[net]
```

<!-- => {2, 3} -->

---

A [NetChain]() is admitted on the same terms:

```wl
ArrayLazyQ[NetChain[{NetArrayLayer["Array" -> {1., 2., 3.}]}]]
```

<!-- => True -->

---

A net with an open input port is a function of that input and is declined:

```wl
ArrayLazyQ[NetGraph[{ElementwiseLayer[Tanh]}, {1 -> NetPort["Output"]}, "Input" -> 3]]
```

<!-- => False -->

### Other tiers

An explicit container is not lazy:

```wl
ArrayLazyQ[SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => False -->

---

A symbolic container is not lazy either:

```wl
ArrayLazyQ[MatrixSymbol["M", {2, 3}]]
```

<!-- => False -->

## Properties and Relations

[ArrayReplaceAll]() substitutes the whole expression at once, evaluating the array-valued function a single time:

```wl
ArrayReplaceAll[v[tau], tau -> 0.5]
```

<!-- => {0.8775824340095093, -0.479425447892118} -->

---

The result agrees with applying the interpolating function to the same numeric argument directly:

```wl
v[0.5]
```

<!-- => {0.8775824340095093, -0.479425447892118} -->

---

The parameters of a [Function]() are bound, so substituting all of them applies the [Function]() rather than rewriting it:

```wl
ArrayReplaceAll[rotation, th -> 0.5]
```

<!-- => {{0.8775825618903728, -0.479425538604203}, {0.479425538604203, 0.8775825618903728}} -->

---

A head with a lazy-preserving rebuild stays lazy under a structural operation; the branch values of a [Piecewise]() are transposed in place:

```wl
ArrayTranspose[pw, {2, 1}]
```

<!-- => Piecewise[{{{{1., 3.}, {2., 4.}}, zz < 0}}, {{5., 7.}, {6., 8.}}] -->

---

A head with no rebuild materializes first; transposing a source net gives an explicit matrix:

```wl
ArrayTranspose[net, {2, 1}]
```

<!-- => {{1., 4.}, {2., 5.}, {3., 6.}} -->

---

Lazy containers do not compute natively:

```wl
ArrayComputeNativeQ[v[tau]]
```

<!-- => False -->

## Possible Issues

A lazy container stores no elements, so the stored-value accessors decline to answer:

```wl
ArrayExplicitValues[v[tau]]
```

<!-- => Missing["NotExplicit"] -->

---

The non-numeric test is [NumericQ](), so an exact numeric argument evaluates the application instead of keeping it lazy:

```wl
ArrayLazyQ[v[Pi/4]]
```

<!-- => False -->

---

Recognizing an undeclared [Function]() evaluates its body once; here the body increments a counter:

```wl
hits = 0;
observed = Function[s, (hits++; {Sin[s], Cos[s]})];
ArrayLazyQ[observed]
```

<!-- => True -->

The counter records the probe run, which an [ArrayDeclareShape]() declaration would have avoided:

```wl
hits
```

<!-- => 1 -->
