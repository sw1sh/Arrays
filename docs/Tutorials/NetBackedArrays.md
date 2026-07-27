---
Template: TechNote
Name: NetBackedArrays
Title: Net-Backed Arrays
Context: Wolfram`Arrays`
ContextPath: [Wolfram`TensorNetworks`]
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/tutorial/NetBackedArrays
Keywords: [neural net, NetGraph, NetChain, lazy array, source net, tensor network, materialization]
RelatedGuides: [Arrays]
---

A neural net with no open input ports has an array value: it takes no arguments, and running it produces a tensor. Such a net meets the paclet's admission criterion, since its shape can be read off its output port without running anything and its materialization is the single call `net[]`. Nets therefore join the lazy tier, beside interpolating functions and unapplied functions. This note builds a source net, reads its shape without evaluating it, materializes it, works through the structural operations, and closes with tensor-network contraction, which can deliver its result as a net rather than as an array.

## A Source Net Is a Container

A [NetArrayLayer]() holding a 2 x 3 array, wrapped in a [NetGraph]() whose only node feeds the output port, is a net that takes no input:

```wl
net = NetGraph[<|"a" -> NetArrayLayer["Array" -> {{1., 2., 3.}, {4., 5., 6.}}]|>, {"a" -> NetPort["Output"]}]
```

<!-- => the NetGraph summary box, one NetArrayLayer node, output port {2, 3} -->

---

Its input ports are empty, which is what makes it a source net:

```wl
Information[net, "InputPorts"]
```

<!-- => <||> -->

---

The paclet admits it as a container:

```wl
ArrayContainerQ[net]
```

<!-- => True -->

---

It belongs to the lazy tier, because its elements are not in memory until the net runs:

```wl
ArrayTier[net]
```

<!-- => "Lazy" -->

## Shape Without Running the Net

The output port carries the shape, so [ArrayDimensions]() answers from the net's own type signature:

```wl
ArrayDimensions[net]
```

<!-- => {2, 3} -->

---

That shape is exactly what the output port reports:

```wl
NetExtract[net, "Output"]
```

<!-- => {2, 3} -->

---

[ArrayRank]() follows from the same reading:

```wl
ArrayRank[net]
```

<!-- => 2 -->

The reading is a lookup rather than an evaluation. For a net wrapping an 800 x 800 array, [ArrayDimensions]() takes about 0.1 milliseconds while [ArrayMaterialize]() takes about 3 milliseconds, and the gap widens with the size of the array and the depth of the net.

## Materialization Runs the Net

[ArrayMaterialize]() calls the net and gives the array it produces:

```wl
ArrayMaterialize[net]
```

<!-- => {{1., 2., 3.}, {4., 5., 6.}} -->

---

That is the same value the net produces when called with no arguments:

```wl
net[]
```

<!-- => {{1., 2., 3.}, {4., 5., 6.}} -->

---

A net does not run arithmetic in place, so it is not compute-native and [ArrayComputable]() materializes it:

```wl
ArrayComputeNativeQ[net]
```

<!-- => False -->

---

```wl
ArrayComputable[net]
```

<!-- => {{1., 2., 3.}, {4., 5., 6.}} -->

## NetChain Behaves the Same Way

A [NetChain]() with no open input ports is admitted on the same terms:

```wl
chain = NetChain[{NetArrayLayer["Array" -> {{1., 2., 3.}, {4., 5., 6.}}]}]
```

<!-- => the NetChain summary box, one NetArrayLayer, output port {2, 3} -->

---

```wl
ArrayDimensions[chain]
```

<!-- => {2, 3} -->

---

```wl
ArrayMaterialize[chain]
```

<!-- => {{1., 2., 3.}, {4., 5., 6.}} -->

## Structural Operations

Nets register no structural rebuild, so a structural operation materializes the net and operates on the resulting array. Transposition gives the transposed array rather than a rewired net:

```wl
ArrayTranspose[net, {2, 1}]
```

<!-- => {{1., 4.}, {2., 5.}, {3., 6.}} -->

---

Taking a row gives the row:

```wl
ArrayPart[net, {1}]
```

<!-- => {1., 2., 3.} -->

---

Taking a single element gives the scalar:

```wl
ArrayPart[net, {2, 3}]
```

<!-- => 6. -->

---

Contracting the two indices traces the array:

```wl
ArrayContract[net, {{1, 2}}]
```

<!-- => 6. -->

---

Flattening to a vector materializes and flattens:

```wl
ArrayVector[net]
```

<!-- => {1., 2., 3., 4., 5., 6.} -->

## Contracting a Tensor Network to a Net

[TensorNetworkContraction]() in `` Wolfram`TensorNetworks` `` accepts `Method -> "NetGraph"`, which lifts each leaf tensor to a layer and wires the contraction as a net. A 2 x 3 and a 3 x 4 matrix contracted over their shared index give a net:

```wl
a = {{1., 2., 3.}, {4., 5., 6.}};
b = {{1., 0., 0., 1.}, {0., 1., 0., 1.}, {0., 0., 1., 1.}};
g = ToTensorNetworkGraph[TensorNetwork[{a, b}, {{1, 2}, {2, 3}}]];
contracted = TensorNetworkContraction[g, {{1, 2}}, Method -> "NetGraph"]
```

<!-- => the NetGraph summary box for the contraction, output port {2, 4} -->

---

The result is itself a container, so the paclet reads its shape without running it:

```wl
ArrayDimensions[contracted]
```

<!-- => {2, 4} -->

---

Running it gives the contracted matrix:

```wl
ArrayMaterialize[contracted]
```

<!-- => {{1., 2., 3., 6.}, {4., 5., 6., 15.}} -->

---

That is the ordinary matrix product of the two leaves:

```wl
Dot[a, b]
```

<!-- => {{1., 2., 3., 6.}, {4., 5., 6., 15.}} -->

---

[TensorNetworkToNetGraph]() is the direct route to the same net:

```wl
ArrayMaterialize[TensorNetworkToNetGraph[g]]
```

<!-- => {{1., 2., 3., 6.}, {4., 5., 6., 15.}} -->

## Details

- Admission has two conditions: the net has no open input ports, and its output port reports a list of positive integer dimensions.
- `"NetGraph"` is a valid `Method` value for [TensorNetworkContraction]() but is deliberately absent from `` Wolfram`TensorNetworks`$TensorNetworkContractionMethods ``, which lists the interchangeable methods that all return arrays.
- Nets register a shape reader and a materializer but no rebuild, because lowering a structural operation into layers would have to encode index permutations as layers, so every structural operation materializes first.

## Possible Issues

A net with an open input port is a function of that input and has no array value, so it is not a container:

```wl
openNet = NetGraph[<|"a" -> ElementwiseLayer[Sin, "Input" -> 3]|>, {"a" -> NetPort["Output"]}];
ArrayContainerQ[openNet]
```

<!-- => False -->

---

Asking for its tier says so rather than guessing:

```wl
ArrayTier[openNet]
```

<!-- => Missing["NotAContainer"] -->

---

Its shape is unknown, which is reported as the empty dimension list:

```wl
ArrayDimensions[openNet]
```

<!-- => {} -->

---

A fully contracted tensor network has a rank-0 output port, and a scalar is not an array container, so contracting two vectors over their shared index gives a net the paclet declines:

```wl
sc = ToTensorNetworkGraph[TensorNetwork[{{1., 2., 3., 4.}, {1., 1., 1., 1.}}, {{1}, {1}}]];
ArrayContainerQ[TensorNetworkContraction[sc, {{1, 2}}, Method -> "NetGraph"]]
```

<!-- => False -->

---

The net itself is fine and produces the scalar; it is only outside the array-container contract:

```wl
TensorNetworkContraction[sc, {{1, 2}}, Method -> "NetGraph"][]
```

<!-- => 10. -->

---

Padding has no net form and no materializing fallback, so it returns unevaluated:

```wl
PadArray[net, {3, 4}]
```

<!-- => PadArray[NetGraph[...], {3, 4}], returned unchanged -->

---

Packing a net leaves it as it is, since a net is not a packable array:

```wl
ArrayPack[net]
```

<!-- => the NetGraph, returned unchanged -->

---

Coercion down the tier lattice is refused: materializing a lazy container is [ArrayMaterialize]()'s job and is requested explicitly:

```wl
ArrayCoerce[net, "Explicit"]
```

<!-- => ArrayCoerce::materialize; the expression returns unevaluated -->

---

A lazy container has no leafless symbolic form either, so the upward coercion is refused as well:

```wl
ArrayCoerce[net, "Symbolic"]
```

<!-- => ArrayCoerce::notier; the expression returns unevaluated -->
