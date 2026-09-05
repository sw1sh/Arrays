---
Template: Symbol
Name: ArrayIndexPlan
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayIndexPlan
Keywords: [index notation, execution plan, shape inference, axis size, plan steps, compile once, summary box]
SeeAlso: [ArrayIndexPattern, ArrayIndexContract, ArrayIndexTransform, ArrayDimensions, ReshapeArray, ArrayTranspose, ArrayContract, ArrayMaterialize]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayIndexPlan]()[*desc*, *dims*]</code> solves the axis sizes of the index descriptor *desc* against a list of operand dimension lists and gives an execution plan object.

<code>[ArrayIndexPlan]()[*desc*, *arrays*]</code> reads the dimensions from the given array containers.

<code>[ArrayIndexPlan]()[*pattern*, *dimsOrArrays*]</code> solves the sizes of a prepared [ArrayIndexPattern]().

<code>[ArrayIndexPlan]()[*desc*, *dimsOrArrays*, *bindings*]</code> takes axis sizes out of band from a list of rules.

<code>[ArrayIndexPlan]()[*desc*, *dimsOrArrays*]["*prop*"]</code> gives the value of the property *prop*.

## Details & Options

- *desc* is a descriptor in the classic einsum dialect (`"ij,jk->ik"`), in the einx identifier dialect (`"b s d, d e -> b s e"`), or in the Wolfram list-of-shapes dialect (`{{i_, j_}, {j_, k_}} :> {{i, k}}`); [ArrayIndexPattern]() compiles it and owns the tokenizing rules, the axis spellings and the keys a *bindings* list may use.
- Sizes are solved without data: every atomic axis is unified against the operand dimension standing at its position, and then each composite whose factors are all known but one is resolved by division, iterated to a fixed point.
- The second argument is a list of dimension lists or a list of arrays. A list whose every element is a list of positive integers as long as the input shape it stands for names axis terms is read as dimensions; otherwise each element is an operand, its dimensions read with [ArrayDimensions](), and anything that is not a container is a rank-0 operand.
- An [ArrayIndexPattern]() may stand in the descriptor position, which is the compile-once path: the object is taken apart rather than parsed again. The settings and the axis sizes its own construction resolved travel with it, and `"DefaultOutput"` is `"Identity"` only for a descriptor [ArrayIndexTransform]() compiled, so an arrowless descriptor prepared here or by [ArrayIndexPattern]() carries the contracted reading wherever it is executed.
- The plan is an ordered list of steps over a single-assignment register file. Registers 1 to *n* hold the operands as given, each step writes one fresh register, and every register is read at most once. A step record carries `"Step"`, `"Inputs"`, `"Output"`, its own fields, `"Frame"` and `"Dimensions"`.
- Each step, and the primitive it lowers to:

| Step | What it does | Primitive |
|---|---|---|
| `"Reshape"` | splits composites, squeezes and inserts unit axes | [ReshapeArray]() |
| `"Transpose"` | permutes into the frame the next step reads | [ArrayTranspose]() |
| `"Broadcast"` | appends an axis of a given extent | inactive [TensorProduct]() with a vector of ones |
| `"Multiply"` | merges the operands sharing a carried axis | elementwise [Times]() |
| `"Contract"` | sums over slot groups | [ArrayContract]() over an inactive [TensorProduct]() |

- A one-slot group sums that slot, a two-slot group is an ordinary contraction, and a group of three or more is the generalized trace a hyperedge lowers to. The `"Groups"` of a contract step are the *pairs* argument of its [ArrayContract]() call, numbering the concatenated levels of the operands under its inactive [TensorProduct]().
- `"Expression"` is that plan as a [Function]() of the operands, with operand *k* spelled `#k`. It is the function the executors apply, so the trace read here is what runs.
- Supported properties:

| Property | Value |
|---|---|
| `"AxisSizes"` | the solved size of each axis, keyed by display name |
| `"Effects"` | the effect records the analysis produced |
| `"Expression"` | the lowered plan, a [Function]() of the operands with operand *k* as `#k` |
| `"InputDimensions"` | the dimensions the plan was solved for |
| `"OutputDimensions"` | the dimensions of the result |
| `"Pattern"` | the [ArrayIndexPattern]() the plan was built from |
| `"Steps"` | the ordered step records |
| `"Properties"` | the list of supported properties |

- An unknown property gives an `ArrayIndexPlan::noprop` message, any number of arguments other than one property name gives an `ArrayIndexPlan::propx` message, and a property read from anything other than a compiled plan gives an `ArrayIndexPlan::malformed` message; each lookup stays unevaluated.
- A plan carries the dimensions its steps were emitted for: a reshape names its dimensions and a broadcast names its sizes, so a prepared plan given operands of other dimensions gives an `ArrayIndexPlan::dimensions` message and stays unevaluated rather than lowering to a different array.
- The occurrence policy is decided at this stage: a diagonal kept, three occurrences in one operand, and a target that marks no contraction are `ArrayIndexPlan` messages wherever the call was made, so [ArrayIndexContract]() and [ArrayIndexTransform]() report them under this symbol's name.
- The collapsed summary box shows the operand dimensions and the output dimensions. Expanding it adds the axes, the solved axis sizes, the step names and a tally of the effects. Every row is read from the descriptor, the effect records or the solved sizes, so a plan renders with no arrays anywhere near it.
- The options are:

| Option | Settings |
|---|---|
| `"DefaultOutput"` | `"Contracted"` (default) or `"Identity"` |
| `"Targeting"` | `Automatic` (default), `True`, `False` |

- `"Targeting"` selects which occurrences count as targeted, and [ArrayIndexContract]() states what a target does; `"DefaultOutput"` resolves the output shape of a descriptor that writes none, and [ArrayIndexPattern]() states what each setting keeps. A setting outside what an option takes is declined with an `ArrayIndexPlan::option` message wherever the option is read.
- Both are read where a descriptor is compiled, as a *bindings* list is, so a prepared [ArrayIndexPattern]() or [ArrayIndexPlan]() in the descriptor position carries what its own construction resolved and is declined all three; [ArrayIndexContract]()'s `"Combiner"` is read at execution and a prepared plan takes it. An option name the symbol does not declare is declined before any setting is read.

## Basic Examples

<!-- #| annotation: 05.09.26: Design review - the analysis and the solve are two stages because the analysis is purely structural: it reads the normalized descriptor and never a size, so a pattern reports its effects with no operand in sight, while every dimension a step writes down needs the solved sizes. Sizes are solved by unifying atomic axes against dimensions and then resolving each composite whose factor occurrences are all known but one, counted with multiplicity so that (a a) against 9 resolves nothing while (2 c) against 6 resolves c, iterated to a fixed point and revalidated through the all-known branch, which is what makes a composite consistent across operands rather than only within the one that resolved it. The register file is single-assignment and every register is read at most once, so the plan is a tree and renders to one nested expression whose only open positions are the operand slots - that is what lets "Expression" hand back a Function of them, a property of the object rather than of a call, and it is assembled held part by part because ArrayContract and ArrayTranspose each have a generic clause that would match a Slot and evaluate at build time, leaving the plan rendering something other than the step it stands for; the Function put on at the end holds its body as firmly as those parts were held. The merge broadcasts only the operands that actually share an index; lifting every operand into the global frame would materialize the whole outer product before summing it, where a contraction group over the inactive tensor product never builds one. The dimension check on execution is what makes a prepared plan safe to hand around: the steps carry the extents they were solved for, so running one against other dimensions does not fail, it quietly lowers to a different array. -->

An execution plan for a matrix product, solved against two dimension lists:

```wl
ArrayIndexPlan["ij,jk->ik", {{2, 2}, {2, 2}}]
```

<!-- => an ArrayIndexPlan summary box: operands {{2, 2}, {2, 2}}, dimensions {2, 2} -->

---

The dimensions of the result, read with no data:

```wl
ArrayIndexPlan["ij,jk->ik", {{2, 2}, {2, 2}}]["OutputDimensions"]
```

<!-- => {2, 2} -->

---

The steps the plan runs, here a single contraction:

```wl
ArrayIndexPlan["ij,jk->ik", {{2, 2}, {2, 2}}]["Steps"]
```

<!-- => {<|"Step" -> "Contract", "Inputs" -> {1, 2}, "Output" -> 3, "Groups" -> {{2, 3}}, "Frame" -> {1, 3}, "Dimensions" -> {2, 2}|>} -->

---

The lowered plan, a function of the operands with operand *k* written `#k`:

```wl
ArrayIndexPlan["ij,jk->ik", {{2, 2}, {2, 2}}]["Expression"]
```

<!-- => ArrayContract[Inactive[TensorProduct][#1, #2], {{2, 3}}] & -->

## Scope

### Shapes without data

Two dimension lists and no arrays at all give the dimensions of the product:

```wl
ArrayIndexPlan["ij,jk->ik", {{2, 3}, {3, 4}}]["OutputDimensions"]
```

<!-- => {2, 4} -->

The size each axis was solved to, keyed by display name:

```wl
ArrayIndexPlan["ij,jk->ik", {{2, 3}, {3, 4}}]["AxisSizes"]
```

<!-- => <|"i" -> 2, "j" -> 3, "k" -> 4|> -->

---

A composite factor is solved by division: the binding gives `i`, and the dimension 6 leaves `j`:

```wl
ArrayIndexPlan["(i j) -> j i", {{6}}, {"i" -> 2}]["AxisSizes"]
```

<!-- => <|"i" -> 2, "j" -> 3|> -->

---

A list of positive-integer vectors as long as the input shapes name axis terms is read as dimensions rather than as two vector operands:

```wl
ArrayIndexPlan["i,i->i", {{2}, {2}}]["OutputDimensions"]
```

<!-- => {2} -->

---

Given arrays instead, the dimensions are read off the containers:

```wl
ArrayIndexPlan["ij,jk->ik", {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}]["InputDimensions"]
```

<!-- => {{2, 2}, {2, 2}} -->

### Steps

A split and a permutation are two steps over the register file:

```wl
ArrayIndexPlan["(i j) -> j i", {{6}}, {"i" -> 2}]["Steps"]
```

<!-- => {<|"Step" -> "Reshape", "Inputs" -> {1}, "Output" -> 2, "Frame" -> {1, 2}, "Dimensions" -> {2, 3}|>, <|"Step" -> "Transpose", "Inputs" -> {2}, "Output" -> 3, "Permutation" -> {2, 1}, "Frame" -> {2, 1}, "Dimensions" -> {3, 2}|>} -->

The two steps lower to the primitives of their rows:

```wl
ArrayIndexPlan["(i j) -> j i", {{6}}, {"i" -> 2}]["Expression"]
```

<!-- => ArrayTranspose[ReshapeArray[#1, {2, 3}], {2, 1}] & -->

---

Column scaling carries `j` on the output, so the two operands are aligned and merged:

```wl
ArrayIndexPlan["ij,j->ij", {{2, 2}, {2}}]["Steps"]
```

<!-- => {<|"Step" -> "Broadcast", "Inputs" -> {2}, "Output" -> 3, "Sizes" -> {2}, "Axes" -> {1}, "Frame" -> {2, 1}, "Dimensions" -> {2, 2}|>, <|"Step" -> "Transpose", "Inputs" -> {3}, "Output" -> 4, "Permutation" -> {2, 1}, "Frame" -> {1, 2}, "Dimensions" -> {2, 2}|>, <|"Step" -> "Multiply", "Inputs" -> {1, 4}, "Output" -> 5, "Frame" -> {1, 2}, "Dimensions" -> {2, 2}|>} -->

The broadcast is a tensor product against a vector of ones, and the merge an elementwise product:

```wl
ArrayIndexPlan["ij,j->ij", {{2, 2}, {2}}]["Expression"]
```

<!-- => #1*ArrayTranspose[Developer`ToPackedArray[ArrayMaterialize[Inactive[TensorProduct][#2, ConstantArray[1, 2]]]], {2, 1}] & -->

---

Two operands sharing no axis are contracted over no group at all, which is their outer product:

```wl
ArrayIndexPlan["i,j->ij", {{2}, {3}}]["Expression"]
```

<!-- => ArrayContract[Inactive[TensorProduct][#1, #2], {}] & -->

---

A trace is a two-slot group over the product of one operand:

```wl
ArrayIndexPlan["ii->", {{2, 2}}]["Expression"]
```

<!-- => ArrayContract[Inactive[TensorProduct][#1], {{1, 2}}] & -->

---

A single occurrence summed away is a one-slot group:

```wl
ArrayIndexPlan["ij->i", {{2, 2}}]["Expression"]
```

<!-- => ArrayContract[Inactive[TensorProduct][#1], {{2}}] & -->

---

An axis every operand carries and the output keeps is the merge and nothing else:

```wl
ArrayIndexPlan["i,i,i->i", {{2}, {2}, {2}}]["Expression"]
```

<!-- => #1*#2*#3 & -->

### The compile-once path

A prepared [ArrayIndexPattern]() stands in the descriptor position, and the plan is solved without parsing the string again:

```wl
ArrayIndexPlan[ArrayIndexPattern["ij,jk->ik"], {{2, 2}, {2, 2}}]
```

<!-- => an ArrayIndexPlan summary box: operands {{2, 2}, {2, 2}}, dimensions {2, 2} -->

---

A plan hands back the pattern it was built from:

```wl
ArrayIndexPlan["ij,jk->ik", {{2, 2}, {2, 2}}]["Pattern"]
```

<!-- => an ArrayIndexPattern summary box: axes {i, j, k}, operands {2, 2} -->

## Properties and Relations

A plan solved once over dimensions:

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

The descriptor path gives the same result, planning the descriptor at the call instead:

```wl
ArrayIndexContract["ij,jk->ik", {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}]
```

<!-- => {{19, 22}, {43, 50}} -->

---

The plan's own `"Expression"` applied to those operands by hand gives it again:

```wl
plan = ArrayIndexPlan["ij,jk->ik", {{2, 2}, {2, 2}}];
plan["Expression"][{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}]
```

<!-- => {{19, 22}, {43, 50}} -->

---

[ArrayIndexTransform]() executes a prepared plan the same way:

```wl
ArrayIndexTransform[ArrayIndexPlan["ij->ji", {{2, 2}}], {{1, 2}, {3, 4}}]
```

<!-- => {{1, 3}, {2, 4}} -->

## Possible Issues

The axis `j` is size 2 on the first operand and size 3 on the second, and one axis takes one size across the whole descriptor:

```wl
ArrayIndexContract["ij,jk->ik", {{{1, 2}, {3, 4}}, {{1, 2, 3}, {4, 5, 6}, {7, 8, 9}}}]
```

<!-- => ArrayIndexPlan::conflict message, then ArrayIndexContract["ij,jk->ik", {{{1, 2}, {3, 4}}, {{1, 2, 3}, {4, 5, 6}, {7, 8, 9}}}] unevaluated -->

---

One axis term stands for one dimension, so an operand whose rank is not the number of terms in its input shape is declined:

```wl
ArrayIndexContract["ij,jk->ik", {{{1, 2}, {3, 4}}, {10, 20}}]
```

<!-- => ArrayIndexPlan::rank message, then ArrayIndexContract["ij,jk->ik", {{{1, 2}, {3, 4}}, {10, 20}}] unevaluated -->

---

A literal axis is a fixed size and is checked against the dimension standing there:

```wl
ArrayIndexPlan["i 3", {{2, 2}}]
```

<!-- => ArrayIndexPlan::literal message, then ArrayIndexPlan["i 3", {{2, 2}}] unevaluated -->

---

A composite resolves when its known factors divide the dimension, and 2 does not divide 5:

```wl
ArrayIndexTransform["(i j) -> i j", {1, 2, 3, 4, 5}, {"i" -> 2}]
```

<!-- => ArrayIndexPlan::composite message, then ArrayIndexTransform["(i j) -> i j", {1, 2, 3, 4, 5}, {"i" -> 2}] unevaluated -->

---

An axis on no operand takes its size from a binding rule or an inline [Annotation](), and with neither there is nothing to solve it against:

```wl
ArrayIndexPlan["i -> i j", {{2}}]
```

<!-- => ArrayIndexPlan::unresolved message, then ArrayIndexPlan["i -> i j", {{2}}] unevaluated -->

---

A plan solves over positive integer dimensions, so an operand with a zero dimension is declined:

```wl
ArrayIndexPlan["ij", {ConstantArray[1, {2, 0}]}]
```

<!-- => ArrayIndexPlan::dimension message, then ArrayIndexPlan["ij", {{{}, {}}}] unevaluated -->

---

The operand count is checked against the number of input shapes; a descriptor naming one input shape takes one operand:

```wl
ArrayIndexContract["ij->i", {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}]
```

<!-- => ArrayIndexPlan::operands message, then ArrayIndexContract["ij->i", {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}] unevaluated -->

---

A prepared plan carries the dimensions its steps were emitted for, so operands of other dimensions are declined rather than lowered to a different array; plan the descriptor again for the new shapes:

```wl
plan = ArrayIndexPlan["ij,jk->ik", {{2, 2}, {2, 2}}];
ArrayIndexContract[plan, {{{1, 2, 3}, {4, 5, 6}}, {{1, 2}, {3, 4}, {5, 6}}}]
```

<!-- => ArrayIndexPlan::dimensions message, then the call unevaluated, with plan shown as its summary box -->

---

`"Targeting"` is read where a descriptor is compiled, so a prepared plan, which already resolved it, declines the setting:

```wl
plan = ArrayIndexPlan["ij,jk->ik", {{2, 2}, {2, 2}}];
ArrayIndexContract[plan, {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}, "Targeting" -> True]
```

<!-- => ArrayIndexPlan::prepared message, then the call unevaluated, with plan shown as its summary box -->

---

`"DefaultOutput"`, which decides the output shape of a descriptor that writes none, is declined the same way:

```wl
plan = ArrayIndexPlan["ij,jk->ik", {{2, 2}, {2, 2}}];
ArrayIndexContract[plan, {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}, "DefaultOutput" -> "Identity"]
```

<!-- => ArrayIndexPlan::prepared message, then the call unevaluated, with plan shown as its summary box -->

---

A setting outside what an option takes is declined where the option is read:

```wl
ArrayIndexPlan["ij,jk->ik", {{2, 2}, {2, 2}}, "Targeting" -> "Sometimes"]
```

<!-- => ArrayIndexPlan::option message, then ArrayIndexPlan["ij,jk->ik", {{2, 2}, {2, 2}}, "Targeting" -> "Sometimes"] unevaluated -->
