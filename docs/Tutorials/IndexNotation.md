---
Template: TechNote
Name: IndexNotation
Title: Index Notation and Einstein Summation
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/tutorial/IndexNotation
Keywords: [index notation, einsum, Einstein summation, index descriptor, execution plan, tensor contraction, array tier, deferred tree]
RelatedGuides: [Arrays]
RelatedTutorials: [ArrayContainers]
---

An index descriptor names the axes of each operand and the axes of the result, and everything an index operation does follows from where each name occurs. [ArrayIndexPattern]() compiles a descriptor written in the classic einsum dialect, in the identifier dialect or as a Wolfram list of shapes; [ArrayIndexPlan]() solves the size of every axis against operand shapes and emits the steps that produce the result; [ArrayIndexContract]() and [ArrayIndexTransform]() run them. Solving sizes needs shapes and nothing else, so a plan is available wherever a shape is: from bare dimension lists with no data at all, from an [ArraySymbol]() that has no elements, and from a container that has not computed its own yet. Running the steps needs elements, so the executors take the explicit tier and decline the rest. This note works one matrix product through the three dialects, reads what a plan knows before any data, executes contractions, traces and hyperedges over explicit containers, and then follows the contraction that has no elements to run on: the inert tensor-contraction tree, which is itself an array container this paclet shapes, joins and materializes on demand.

<!-- #| annotation: 04.09.26: Design review - the note is organized around the one asymmetry the four symbols
share: a plan is solved from shapes and an execution needs elements, so ArrayIndexPlan answers on every tier
and the two executors answer on one. The deferred tensor-contraction tree is built literally in every cell
rather than obtained from a tensor-network call, because the docs build evaluates every cell and the note
must load no paclet but this one; EinsteinSummation and ActivateTensors are named in prose with the call that
produces such a tree, and that claim is attached to the contraction descriptor quoted rather than to
descriptors in general, since a pure hyperedge with its axis kept is evaluated eagerly there. Container
preservation is stated as the sufficient condition that held across every descriptor tried - an operand set of
SparseArray with background zero - leaving the mixed cases to the steps and showing them per cell, rather than
as the unconditional sentence the ArrayIndexContract Details bullet carries; the wrappers materialized at the
door are named, those coming back plain arrays. The inertness of the contraction head is stated where the plan
expression and the ArrayContract result are compared, and shown once over explicit leaves, an active head there
contracting on the spot. The claim that a descriptor plans the same way is qualified to the tier: the dimensions
reading of the second argument is taken before any operand is looked at, so ArrayIndexPlan and the executors
read one list of positive-integer vectors differently. ArrayContract appears only on symbolic operands: an operand
set spelled Inactive[TensorProduct] contracts explicit operands on the spot, and applied to a deferred tree it
materializes the leaves, so it is cited here for the one tier where its result is the inert tree the note is
about. -->

## One Descriptor, Three Dialects

A descriptor is a list of input shapes together with a list of output shapes. Each term of an input shape names one axis of the operand standing in that position, an axis name carried onto the output shape is an axis of the result, and an axis name absent from the output is summed over every slot that carries it.

A string descriptor with no space in it is tokenized character by character, so each letter is one axis. A string containing a space is tokenized by identifier instead, which is what keeps multi-character axis names. The Wolfram dialect writes the same shapes as lists of blanks under [RuleDelayed](), which holds the output shapes so that a bare output symbol names an axis rather than standing for its global value.

The classic einsum spelling of a matrix product contracts the shared axis `j`:

```wl
ArrayIndexContract["ij,jk->ik", {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}]
```

<!-- => {{19, 22}, {43, 50}} -->

---

The same descriptor spelled with spaces is tokenized by identifier and names the same three axes, giving the same product:

```wl
ArrayIndexContract["i j, j k -> i k", {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}]
```

<!-- => {{19, 22}, {43, 50}} -->

---

The Wolfram dialect writes the input and output shapes as lists of blanks, and contracts the same axis:

```wl
ArrayIndexContract[{{i_, j_}, {j_, k_}} :> {{i, k}}, {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}]
```

<!-- => {{19, 22}, {43, 50}} -->

---

That array is the ordinary matrix product of the two operands:

```wl
Dot[{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}]
```

<!-- => {{19, 22}, {43, 50}} -->

---

[ArrayIndexPattern]() compiles a descriptor and holds the axes it names and the rank of each operand:

```wl
ArrayIndexPattern["ij,jk->ik"]
```

<!-- => an ArrayIndexPattern summary box: axes {i, j, k}, operands {2, 2} -->

---

The axes it names, in first-occurrence order:

```wl
ArrayIndexPattern["ij,jk->ik"]["Axes"]
```

<!-- => {"i", "j", "k"} -->

---

The identifier spelling names those same three axes:

```wl
ArrayIndexPattern["i j, j k -> i k"]["Axes"]
```

<!-- => {"i", "j", "k"} -->

---

The Wolfram spelling names them too:

```wl
ArrayIndexPattern[{{i_, j_}, {j_, k_}} :> {{i, k}}]["Axes"]
```

<!-- => {"i", "j", "k"} -->

---

What the descriptor does with each axis is one record per axis, `i` and `k` carried to the output and `j` contracted between the two operands:

```wl
ArrayIndexPattern["ij,jk->ik"]["Effects"]
```

<!-- => {<|"Effect" -> "Carried", "Axis" -> 1, "Inputs" -> {{1, 1}}, "Outputs" -> {{1, 1}}|>, <|"Effect" -> "Contracted", "Axis" -> 2, "Inputs" -> {{1, 2}, {2, 1}}|>, <|"Effect" -> "Carried", "Axis" -> 3, "Inputs" -> {{2, 2}}, "Outputs" -> {{1, 2}}|>} -->

---

The Wolfram spelling gives the same three effects, the dialect having decided only how the descriptor was written:

```wl
ArrayIndexPattern[{{i_, j_}, {j_, k_}} :> {{i, k}}]["Effects"]
```

<!-- => {<|"Effect" -> "Carried", "Axis" -> 1, "Inputs" -> {{1, 1}}, "Outputs" -> {{1, 1}}|>, <|"Effect" -> "Contracted", "Axis" -> 2, "Inputs" -> {{1, 2}, {2, 1}}|>, <|"Effect" -> "Carried", "Axis" -> 3, "Inputs" -> {{2, 2}}, "Outputs" -> {{1, 2}}|>} -->

## What the Plan Knows Before Any Data

[ArrayIndexPlan]() reads its second argument as dimensions when every element is a positive-integer vector as long as its input shape's term count, and as operands otherwise. That reading is taken from the second argument alone, before any operand is looked at, and the executors always read theirs as arrays. The solve unifies each atomic axis term against the dimension standing at its position, so an axis given two sizes is a conflict and an axis given one size is settled for the whole descriptor.

The solve reads shapes and never an element. That is why the same descriptor plans the same way whatever tier is holding the elements, which is the property the tier sections below exercise.

Two dimension lists and no arrays at all give a plan for their product:

```wl
ArrayIndexPlan["ij,jk->ik", {{2, 3}, {3, 4}}]
```

<!-- => an ArrayIndexPlan summary box: operands {{2, 3}, {3, 4}}, dimensions {2, 4} -->

---

The size each axis was solved to, keyed by display name:

```wl
ArrayIndexPlan["ij,jk->ik", {{2, 3}, {3, 4}}]["AxisSizes"]
```

<!-- => <|"i" -> 2, "j" -> 3, "k" -> 4|> -->

---

The dimensions of the result, which are the sizes of the carried axes:

```wl
ArrayIndexPlan["ij,jk->ik", {{2, 3}, {3, 4}}]["OutputDimensions"]
```

<!-- => {2, 4} -->

---

The steps that produce it, here a single contraction of the two operands over one slot group:

```wl
ArrayIndexPlan["ij,jk->ik", {{2, 3}, {3, 4}}]["Steps"]
```

<!-- => {<|"Step" -> "Contract", "Inputs" -> {1, 2}, "Output" -> 3, "Groups" -> {{2, 3}}, "Frame" -> {1, 3}, "Dimensions" -> {2, 4}|>} -->

---

Those steps lowered, as a function of the operands with operand `k` written `#k`:

```wl
ArrayIndexPlan["ij,jk->ik", {{2, 3}, {3, 4}}]["Expression"]
```

<!-- => ArrayContract[Inactive[TensorProduct][#1, #2], {{2, 3}}] & -->

The contraction is [ArrayContract]() over the inactive [TensorProduct]() of its operands, which is that symbol's spelling for an operand set: the operands are contracted against each other and the product is never built. An inactive [TensorContract]() over that same node, with arrays in place of the slots, is itself an array container, and the later sections take it up as one.

## Occurrence Decides the Effect

How many times an axis name occurs, and whether the output carries it, is the whole rule. Summing every axis the output does not carry is the Einstein summation convention written out: the classic convention leaves the summed axes implicit in their repetition, and an output shape names the axes that survive instead. A name occurring once and carried is an axis of the result; a name occurring once and absent from the output is summed; a name occurring in two input shapes and absent from the output contracts those two operands; a name occurring in three and absent from the output contracts all three at once; and a name repeated within one input shape and absent from the output is a self-contraction, which is a trace.

An axis shared by more than two operands is not a separate form: it is one contraction whose slot group has that many members. With no output shape written at all, the output is the axes occurring exactly once, in first-occurrence order.

An axis occurring once and absent from the output sums that slot:

```wl
ArrayIndexContract["ij->i", {{{1, 2}, {3, 4}}}]
```

<!-- => {3, 7} -->

---

[Total]() at that level gives the same vector:

```wl
Total[{{1, 2}, {3, 4}}, {2}]
```

<!-- => {3, 7} -->

---

Three operands in a chain contract `j` and then `k`:

```wl
ArrayIndexContract["ij,jk,kl->il", {{{1, 2, 3}, {4, 5, 6}}, {{1, 0}, {0, 1}, {1, 1}}, {{2, 0, 1}, {1, 3, 0}}}]
```

<!-- => {{13, 15, 4}, {31, 33, 10}} -->

---

The same chain of matrix products written with [Dot]():

```wl
Dot[{{1, 2, 3}, {4, 5, 6}}, {{1, 0}, {0, 1}, {1, 1}}, {{2, 0, 1}, {1, 3, 0}}]
```

<!-- => {{13, 15, 4}, {31, 33, 10}} -->

---

One axis on three operands and absent from the output is summed once over all three:

```wl
ArrayIndexContract["i,i,i->", {{1, 2, 3}, {4, 5, 6}, {7, 8, 9}}]
```

<!-- => 270 -->

---

The plan for that descriptor is a single contraction whose slot group has three members:

```wl
ArrayIndexPlan["i,i,i->", {{3}, {3}, {3}}]["Steps"]
```

<!-- => {<|"Step" -> "Contract", "Inputs" -> {1, 2, 3}, "Output" -> 4, "Groups" -> {{1, 2, 3}}, "Frame" -> {}, "Dimensions" -> {}|>} -->

---

The same axis kept on the output multiplies the three operands elementwise instead:

```wl
ArrayIndexContract["i,i,i->i", {{1, 2, 3}, {4, 5, 6}, {7, 8, 9}}]
```

<!-- => {28, 80, 162} -->

---

An axis repeated within one input shape and absent from the output is self-contracted, which is the trace:

```wl
ArrayIndexContract["ii->", {{{1, 2}, {3, 4}}}]
```

<!-- => 5 -->

---

[Tr]() sums that same diagonal:

```wl
Tr[{{1, 2}, {3, 4}}]
```

<!-- => 5 -->

---

Two operands sharing no axis carry no contraction at all, and the result is their outer product:

```wl
ArrayIndexContract["i,j->ij", {{1, 2, 3}, {10, 20}}]
```

<!-- => {{10, 20}, {20, 40}, {30, 60}} -->

---

[Outer]() with [Times]() builds the same matrix:

```wl
Outer[Times, {1, 2, 3}, {10, 20}]
```

<!-- => {{10, 20}, {20, 40}, {30, 60}} -->

---

With no output shape written, `j` occurs twice and is summed while `i` and `k` occur once and are carried, so the matrix product needs no arrow:

```wl
ArrayIndexContract["ij,jk", {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}]
```

<!-- => {{19, 22}, {43, 50}} -->

## Containers Through the Steps

Container preservation is a property of the steps rather than of one descriptor: the executors run on the explicit tier, hand the operands to the primitives the steps lower to, and give back the container those primitives build. A [SparseArray]() and a packed array reach the steps intact, and an operand set of [SparseArray]() with background zero comes back a [SparseArray]() whatever steps the descriptor emits, a rank-0 result being an ordinary number with no [SparseArray]() to build. Where an operand is dense or its background is not zero, the steps decide: a scaling keeps the [SparseArray](), and a contraction summing an axis between such operands comes back a plain array carrying the same values. For a [QuantityArray]() the unit is lifted off, the steps run on the magnitudes, and the product of the units goes back on. A [NumericArray](), a [TabularColumn](), a [Tabular](), a [Dataset](), an [EventSeries]() and a [ByteArray]() are materialized at the door, [TensorProduct]() having no evaluation on those heads, and the result is a plain array. [ArrayIndexTransform]() runs the rearranging half of the same machinery through the same door.

A contraction over [SparseArray]() operands comes back a [SparseArray]():

```wl
s = SparseArray[{{1, 0}, {0, 4}}];
squared = ArrayIndexContract["ij,jk->ik", {s, s}]
```

<!-- => a SparseArray summary box: rank 2, dimensions {2, 2}, 2 stored elements -->

The stored elements are those of the dense product:

```wl
Normal[squared]
```

<!-- => {{1, 0}, {0, 16}} -->

---

A descriptor whose steps emit no contraction node keeps the [SparseArray]() beside a plain-[List]() operand, here a row scaling:

```wl
scaled = ArrayIndexContract["ij,i->ij", {SparseArray[{{1, 0}, {0, 4}}], {10, 20}}]
```

<!-- => a SparseArray summary box: rank 2, dimensions {2, 2}, 2 stored elements -->

The stored elements are the rows scaled:

```wl
Normal[scaled]
```

<!-- => {{10, 0}, {0, 80}} -->

---

A [QuantityArray]() in meters contracted with another comes back a [QuantityArray]() in square meters:

```wl
q = QuantityArray[{{1, 2}, {3, 4}}, "Meters"];
product = ArrayIndexContract["ij,jk->ik", {q, q}]
```

<!-- => a QuantityArray summary box: dimensions {2, 2}, unit "Meters"^2 -->

The magnitudes underneath are the ordinary matrix product:

```wl
QuantityMagnitude[product]
```

<!-- => {{7, 10}, {15, 22}} -->

---

A descriptor that only permutes axes is a rearrangement, which [ArrayIndexTransform]() runs:

```wl
ArrayIndexTransform["ij->ji", {{1, 2, 3}, {4, 5, 6}}]
```

<!-- => {{1, 4}, {2, 5}, {3, 6}} -->

---

[Transpose]() gives the same array:

```wl
Transpose[{{1, 2, 3}, {4, 5, 6}}]
```

<!-- => {{1, 4}, {2, 5}, {3, 6}} -->

---

A [SparseArray]() rearranged by [ArrayIndexTransform]() comes back a [SparseArray]() of the transposed dimensions:

```wl
flipped = ArrayIndexTransform["ij->ji", SparseArray[{{1, 0, 2}, {0, 3, 0}}]]
```

<!-- => a SparseArray summary box: rank 2, dimensions {3, 2}, 3 stored elements -->

The stored elements are those of the transpose:

```wl
Normal[flipped]
```

<!-- => {{1, 0}, {0, 3}, {2, 0}} -->

---

An axis carried on the output by both operands runs the contraction inside it, giving a batch of matrix products:

```wl
ArrayIndexContract["bij,bjk->bik", {{{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}, {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}}]
```

<!-- => {{{7, 10}, {15, 22}}, {{67, 78}, {91, 106}}} -->

---

Threading [Dot]() over the batch gives those same slices:

```wl
MapThread[Dot, {{{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}, {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}}]
```

<!-- => {{{7, 10}, {15, 22}}, {{67, 78}, {91, 106}}} -->

## Carrying a Contraction Without Elements

An [ArraySymbol]() has a name and a shape and no elements. An operand set reaches [ArrayContract]() as an inactive [TensorProduct](), and over operands with no elements the contraction is carried rather than performed: what comes back is a [TensorContract]() over that same node. Its dimensions still follow from its nodes, the contracted slots dropping out, so [ArrayDimensions]() answers for it. That call is what the plan of the previous section lowers its contraction step to, with the operand slots standing where these operands go.

An operand set of two [ArraySymbol]() containers carries the contraction instead of performing it:

```wl
contracted = ArrayContract[Inactive[TensorProduct][ArraySymbol["A", {2, 3}], ArraySymbol["B", {3, 4}]], {{2, 3}}]
```

<!-- => TensorContract[Inactive[TensorProduct][ArraySymbol["A", {2, 3}], ArraySymbol["B", {3, 4}]], {{2, 3}}] -->

It carries no elements, so it is a symbolic container:

```wl
ArrayTier[contracted]
```

<!-- => "Symbolic" -->

Its shape still follows from its nodes, the contracted slots dropping out:

```wl
ArrayDimensions[contracted]
```

<!-- => {2, 4} -->

---

[ArrayMaterialize]() hands a symbolic node back unchanged, there being nothing to run:

```wl
ArrayMaterialize[ArrayContract[Inactive[TensorProduct][ArraySymbol["A", {2, 3}], ArraySymbol["B", {3, 4}]], {{2, 3}}]]
```

<!-- => TensorContract[Inactive[TensorProduct][ArraySymbol["A", {2, 3}], ArraySymbol["B", {3, 4}]], {{2, 3}}] -->

## The Deferred Tree

The tier of a contraction node is decided by its leaves rather than by its heads. Over explicit matrices those same two nodes hold a computation that has a value and has not been performed, which is a container of the lazy tier of [Array Containers](paclet:Wolfram/Arrays/tutorial/ArrayContainers). The contraction head is inactive there: an active [TensorContract]() over explicit leaves performs the contraction as it is entered and leaves nothing deferred. Shape flows through the nodes with nothing computed, and [ArrayMaterialize]() runs the tree through [Activate]().

A contraction node over two explicit matrices holds a computation it has not performed:

```wl
tree = Inactive[TensorContract][Inactive[TensorProduct][{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}], {{2, 3}}];
ArrayTier[tree]
```

<!-- => "Lazy" -->

The same expression is what a tensor-network contraction gives back unactivated: `EinsteinSummation["ij,jk->ik", {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}]` in `` Wolfram`TensorNetworks` `` returns this contraction node, and `ActivateTensors` is that paclet's way of running one. The paclet reads such a node as a container of the lazy tier.

Its shape comes from its nodes, with nothing computed:

```wl
ArrayDimensions[tree]
```

<!-- => {2, 2} -->

[ArrayMaterialize]() runs it:

```wl
ArrayMaterialize[tree]
```

<!-- => {{19, 22}, {43, 50}} -->

That array is the matrix product of the two leaves:

```wl
Dot[{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}]
```

<!-- => {{19, 22}, {43, 50}} -->

---

An active [TensorContract]() over the same two leaves contracts them as it is entered, leaving the product node around the answer and nothing to materialize:

```wl
TensorContract[Inactive[TensorProduct][{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}], {{2, 3}}]
```

<!-- => Inactive[TensorProduct][{{19, 22}, {43, 50}}] -->

---

The same node shape over [ArraySymbol]() leaves has no value to defer, and is symbolic rather than lazy:

```wl
ArrayTier[Inactive[TensorContract][Inactive[TensorProduct][ArraySymbol["A", {2, 3}], ArraySymbol["B", {3, 4}]], {{2, 3}}]]
```

<!-- => "Symbolic" -->

## Planning on Every Tier, Executing on One

Solving reads dimensions, and [ArrayDimensions]() answers on every tier, so the plan is the same object whatever tier is holding the elements. Execution reads elements instead. [ArrayUnify]() joins an operand set to one tier, and that tier is what the executors read: a contraction and a rearrangement execute on explicit containers, and an operand set joining to any other tier is declined with a message naming the joined tier and pointing at [ArrayMaterialize](). The association [ArrayUnify]() returns also carries the operands as the joined tier holds them.

Two [ArraySymbol]() operands, which have no elements, plan to the same single contraction as the dimension lists above:

```wl
ArrayIndexPlan["ij,jk->ik", {ArraySymbol["A", {2, 3}], ArraySymbol["B", {3, 4}]}]["Steps"]
```

<!-- => {<|"Step" -> "Contract", "Inputs" -> {1, 2}, "Output" -> 3, "Groups" -> {{2, 3}}, "Frame" -> {1, 3}, "Dimensions" -> {2, 4}|>} -->

---

The sizes come out the same, read off the shapes of the symbols:

```wl
ArrayIndexPlan["ij,jk->ik", {ArraySymbol["A", {2, 3}], ArraySymbol["B", {3, 4}]}]["AxisSizes"]
```

<!-- => <|"i" -> 2, "j" -> 3, "k" -> 4|> -->

---

A deferred tree plans the same way, its dimensions read from its nodes:

```wl
tree = Inactive[TensorContract][Inactive[TensorProduct][{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}], {{2, 3}}];
ArrayIndexPlan["ij,jk->ik", {tree, {{1, 0}, {0, 1}}}]["InputDimensions"]
```

<!-- => {{2, 2}, {2, 2}} -->

The steps are the one contraction again:

```wl
ArrayIndexPlan["ij,jk->ik", {tree, {{1, 0}, {0, 1}}}]["Steps"]
```

<!-- => {<|"Step" -> "Contract", "Inputs" -> {1, 2}, "Output" -> 3, "Groups" -> {{2, 3}}, "Frame" -> {1, 3}, "Dimensions" -> {2, 2}|>} -->

---

[ArrayUnify]() joins an operand set to one tier, an explicit operand beside a symbolic one giving the symbolic tier:

```wl
ArrayUnify[{{{1, 2}, {3, 4}}, ArraySymbol["B", {2, 2}]}]
```

<!-- => <|"Tier" -> "Symbolic", "Domain" -> Complexes, "ElementType" -> Missing["NotApplicable"], "Arrays" -> {{{1, 2}, {3, 4}}, ArraySymbol["B", {2, 2}]}|> -->

---

An explicit operand beside a deferred tree joins to the lazy tier, and the explicit matrix comes back lifted to a constant [Function]() of a formal parameter, which is how the lazy tier holds it:

```wl
tree = Inactive[TensorContract][Inactive[TensorProduct][{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}], {{2, 3}}];
ArrayUnify[{{{1, 2}, {3, 4}}, tree}]
```

<!-- => <|"Tier" -> "Lazy", "Domain" -> Integers, "ElementType" -> Missing["NotApplicable"], "Arrays" -> {Function[\[FormalT], {{1, 2}, {3, 4}}], Inactive[TensorContract][Inactive[TensorProduct][{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}], {{2, 3}}]}|> -->

That is the tier the executors read, and a contraction runs on explicit containers, so the operand set is declined:

```wl
ArrayIndexContract["ij,jk->ik", {tree, {{1, 0}, {0, 1}}}]
```

<!-- => ArrayIndexContract::tier message naming the Lazy tier, then ArrayIndexContract["ij,jk->ik", {Inactive[TensorContract][Inactive[TensorProduct][{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}], {{2, 3}}], {{1, 0}, {0, 1}}}] unevaluated -->

[ArrayMaterialize]() brings the tree to the explicit tier, and the contraction runs:

```wl
ArrayIndexContract["ij,jk->ik", {ArrayMaterialize[tree], {{1, 0}, {0, 1}}}]
```

<!-- => {{19, 22}, {43, 50}} -->

## Compile Once, Apply Many

A prepared [ArrayIndexPlan]() stands in the descriptor position of either executor and is taken apart rather than compiled again. A prepared [ArrayIndexPattern]() does the same one stage earlier, its axis sizes solved against the operands of each call. A plan carries the dimensions its steps were emitted for, so operands of other dimensions are declined rather than lowered to a different array.

A plan solved from two dimension lists, with no data:

```wl
plan = ArrayIndexPlan["ij,jk->ik", {{2, 2}, {2, 2}}]
```

<!-- => an ArrayIndexPlan summary box: operands {{2, 2}, {2, 2}}, dimensions {2, 2} -->

[ArrayIndexContract]() executes it against operands of those dimensions:

```wl
ArrayIndexContract[plan, {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}]
```

<!-- => {{19, 22}, {43, 50}} -->

---

The same plan against another pair of matrices of those dimensions:

```wl
plan = ArrayIndexPlan["ij,jk->ik", {{2, 2}, {2, 2}}];
ArrayIndexContract[plan, {{{10, 20}, {30, 40}}, {{1, 0}, {0, 1}}}]
```

<!-- => {{10, 20}, {30, 40}} -->

And against sparse operands of those dimensions, which come back sparse:

```wl
ArrayIndexContract[plan, {SparseArray[{{1, 0}, {0, 4}}], SparseArray[{{1, 0}, {0, 4}}]}]
```

<!-- => a SparseArray summary box: rank 2, dimensions {2, 2}, 2 stored elements -->

---

And against unit-carrying operands, the plan being solved from shapes and the container decided at execution:

```wl
plan = ArrayIndexPlan["ij,jk->ik", {{2, 2}, {2, 2}}];
ArrayIndexContract[plan, {QuantityArray[{{1, 2}, {3, 4}}, "Meters"], QuantityArray[{{5, 6}, {7, 8}}, "Meters"]}]
```

<!-- => a QuantityArray summary box: dimensions {2, 2}, unit "Meters"^2 -->

---

A plan solved from two [ArraySymbol]() operands, which carry shapes and no elements, lowers to the same contraction:

```wl
symplan = ArrayIndexPlan["ij,jk->ik", {ArraySymbol["A", {2, 2}], ArraySymbol["B", {2, 2}]}];
symplan["Expression"]
```

<!-- => ArrayContract[Inactive[TensorProduct][#1, #2], {{2, 3}}] & -->

It executes against explicit matrices of those dimensions:

```wl
ArrayIndexContract[symplan, {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}]
```

<!-- => {{19, 22}, {43, 50}} -->

---

A prepared [ArrayIndexPattern]() stands in the descriptor position too, its sizes solved against the operands it is given:

```wl
ArrayIndexPlan[ArrayIndexPattern["ij,jk->ik"], {ArraySymbol["A", {2, 3}], ArraySymbol["B", {3, 4}]}]["OutputDimensions"]
```

<!-- => {2, 4} -->

## Possible Issues

[ArrayIndexTransform]() takes the explicit tier as well, so a deferred tree is declined:

```wl
ArrayIndexTransform["ij->ji", Inactive[TensorContract][Inactive[TensorProduct][{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}], {{2, 3}}]]
```

<!-- => ArrayIndexTransform::tier message naming the Lazy tier, then ArrayIndexTransform["ij->ji", Inactive[TensorContract][Inactive[TensorProduct][{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}], {{2, 3}}]] unevaluated -->

---

Two dimension lists give the axis `j` the size 3 and the size 4, and one axis takes one size across the whole descriptor:

```wl
ArrayIndexPlan["ij,jk->ik", {{2, 3}, {4, 5}}]
```

<!-- => ArrayIndexPlan::conflict message, then ArrayIndexPlan["ij,jk->ik", {{2, 3}, {4, 5}}] unevaluated -->

---

An axis repeated within one input shape is a trace where the output drops it, and names a diagonal where the output keeps it, which has no lowering here:

```wl
ArrayIndexContract["ii->i", {{{1, 2, 3}, {4, 5, 6}, {7, 8, 9}}}]
```

<!-- => ArrayIndexPlan::diagonal message, then ArrayIndexContract["ii->i", {{{1, 2, 3}, {4, 5, 6}, {7, 8, 9}}}] unevaluated -->

The message is reported on [ArrayIndexPlan](), which is where the descriptor is analyzed, whichever symbol was called.

---

[ArrayIndexPlan]() takes a [List]() of operands or of dimension lists, and a bare container in that position is left as it stands, with no message:

```wl
ArrayIndexPlan["ij,jk->ik", ArraySymbol["A", {2, 3}]]
```

<!-- => ArrayIndexPlan["ij,jk->ik", ArraySymbol["A", {2, 3}]] unevaluated, with no message -->

---

The dimensions reading of that list is all or nothing, so a dimension vector beside an array is read as a rank-1 operand:

```wl
ArrayIndexPlan["ij,jk->ik", {ArraySymbol["A", {2, 3}], {3, 4}}]
```

<!-- => ArrayIndexPlan::rank message, then ArrayIndexPlan["ij,jk->ik", {ArraySymbol["A", {2, 3}], {3, 4}}] unevaluated -->

---

That reading is taken before any operand is looked at, so a list of positive-integer vectors is dimensions to [ArrayIndexPlan]():

```wl
ArrayIndexPlan["i,j->ij", {{3}, {4}}]["OutputDimensions"]
```

<!-- => {3, 4} -->

---

[ArrayIndexContract]() always reads its second argument as arrays, so the same list is two rank-1 operands and their outer product is a 1x1 array:

```wl
ArrayIndexContract["i,j->ij", {{3}, {4}}]
```

<!-- => {{12}} -->

---

This contraction of two [SparseArray]() operands, one of them with a background that is not zero, has no sparse result to build and comes back a plain array:

```wl
ArrayIndexContract["ij,jk->ik", {SparseArray[{{1, 1} -> 1, {2, 2} -> 2}, {2, 2}, 5], SparseArray[{{1, 2} -> 3, {2, 1} -> 4}, {2, 2}]}]
```

<!-- => {{20, 3}, {8, 15}} -->

---

The same contraction against a plain-[List]() operand gives a plain array as well:

```wl
ArrayIndexContract["ij,jk->ik", {SparseArray[{{1, 0}, {0, 4}}], {{5, 6}, {7, 8}}}]
```

<!-- => {{5, 6}, {28, 32}} -->

---

The dimensions a plan was solved for are carried in it, so a 2x3 operand reaching a plan emitted for 2x2 is declined:

```wl
plan = ArrayIndexPlan["ij,jk->ik", {{2, 2}, {2, 2}}];
ArrayIndexContract[plan, {{{1, 2, 3}, {4, 5, 6}}, {{1, 2}, {3, 4}, {5, 6}}}]
```

<!-- => ArrayIndexPlan::dimensions message, then the call unevaluated, with plan shown as its summary box -->

A plan is solved from shapes and the executors run on elements, so the descriptor that plans against an [ArraySymbol]() or a deferred tree contracts against the arrays those shapes describe. [ArrayMaterialize]() is the step between, and [ArrayTier]() is what the gate reads.
