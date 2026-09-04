---
Template: Symbol
Name: ArrayIndexPattern
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayIndexPattern
Keywords: [index notation, einsum, descriptor, axis, hygiene, summary box, dialect]
SeeAlso: [ArrayIndexPlan, ArrayIndexContract, ArrayIndexTransform, ArrayObject, ArrayDimensions]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayIndexPattern]()[*desc*]</code> parses the index descriptor *desc* into a normalized pattern object.

<code>[ArrayIndexPattern]()[*desc*, *bindings*]</code> takes axis sizes out of band from a list of rules.

<code>[ArrayIndexPattern]()[*desc*]["*prop*"]</code> gives the value of the property *prop*.

## Details & Options

- A descriptor is a list of input shapes given to a list of output shapes. A shape is a list of axis terms, one term per dimension, and a bare shape stands for a one-operand descriptor.
- The classic einsum dialect is a string with no whitespace, tokenized character by character, and admits letters, `_`, `,` and `->`: `"ij,jk->ik"` names three axes over two input shapes.
- The einx identifier dialect is a string containing whitespace, tokenized by identifier, and adds digits, `(`, `)`, `[` and `]`: `"b s d, d e -> b s e"` keeps its multi-character names.
- The mode is chosen from the raw string before it is tokenized, so whitespace anywhere makes every name an identifier: `"ij,jk->ik"` and `"i j, j k -> i k"` are the same pattern, while `"ij, jk->ik"` names two rank-1 input shapes.
- The Wolfram list-of-shapes dialect is a list of input shapes given as a [RuleDelayed]() to a list of output shapes, `{{i_, j_}, {j_, k_}} :> {{i, k}}`.
- `"Dialect"` takes three values and they are not one per surface dialect: both string spellings report `"String"`, a list of shapes reports `"Expression"`, and a list of shapes written with [Rule]() reports `"IndexList"`.
- [RuleDelayed]() holds the output shapes, so a bare output symbol names its axis rather than its value. [Rule]() evaluates both of its sides before the descriptor is read; it is accepted, with an `ArrayIndexPattern::rule` message saying so.
- A blank `a_` binds one logical axis across the whole descriptor, whatever a symbol of that name means in the caller's scope.
- A bare symbol `a` on the input side is an ambient expression: the input side has evaluated by the time the descriptor is read, so a symbol carrying a value arrives as that value, and a positive integer there is a literal size.
- A bare symbol on the output side references a blank or a string axis of the same name where the descriptor has one, and otherwise reads its own ambient value, which names an axis where that value is a positive integer or an identifier string.
- A string `"a"` names an axis with no symbol of that name consulted.
- A target marks the axis it wraps: `[a]` in a string tokenized by identifier, and in the Wolfram dialect [Slot]() carrying a string, spelled `#a`, or [Framed]() or [Highlighted]() around an axis spelled as a string or as a bare symbol. A target on a literal size is outside the compiled vocabulary.
- A literal positive integer is a fixed size, and a literal `1` is a unit axis.
- An anonymous `_` names nothing.
- Every axis is interned to an identity carrying its display name, its spelling kind and its Wolfram context. A name established as a blank or a string anywhere in the descriptor interns by name alone, so a Wolfram context does not distinguish two axes of one name; a bare symbol interns by context and name, so two bare symbols in two contexts are two axes. A term with no name - an anonymous axis, a literal, a unit axis - cannot be shared and takes a fresh identity at every occurrence.
- One name takes one spelling: a name spelled both as a symbol and as a string is declined with an `ArrayIndexPattern::mishmash` message.
- An axis identity is an integer, allocated in first-occurrence order over the input shapes left to right and then the output shape. `"Axes"` gives the display names in that order, and the records under `"Effects"` and `"Constraints"` name an axis by its identity.
- A [CircleTimes]() product, spelled `(i j)` in the string dialects, is a composite: one axis term standing for one dimension, whose factors are recorded as a product constraint. The split and the merge a composite names are [ArrayIndexTransform]()'s.
- `"Effects"` classifies each axis as `"Carried"`, `"Contracted"`, `"SelfContracted"`, `"Broadcast"` or `"UnitAxis"`, and carries the input and output occurrences the classification was read from.
- A binding list is a list of rules with positive integer values, keyed by a string for a string axis, by a bare symbol for a bare axis, and by the target head the descriptor used for a targeted one. An inline `Annotation[j, 3]` or `Labeled[3, j]` gives the same size in the descriptor itself. A size does not enter the axis identity, so a sized occurrence and an unsized one of the same spelling are one axis. A blank axis takes its size from the operand, so neither a [Pattern]() binding key nor an inline size on a blank is admitted; both are declined with an `ArrayIndexPattern::patternkey` message.
- Supported properties:

| Property | Value |
|---|---|
| `"Axes"` | the display names of the axes, in first-occurrence order |
| `"Constraints"` | the composite constraints the descriptor imposes |
| `"Descriptor"` | the normalized descriptor, an [Association]() |
| `"Dialect"` | `"String"`, `"Expression"` or `"IndexList"` |
| `"Effects"` | one record per axis, giving its effect class and its occurrences |
| `"InputRanks"` | the number of axis terms in each input shape |
| `"OutputRank"` | the number of axis terms in the output shape |
| `"Targets"` | the axes a target marks, under the `"Targeting"` setting in force |
| `"Properties"` | the list of supported properties |

- `"Targeting"` and `"DefaultOutput"` are resolved here and travel with the object, which is why a prepared pattern or a prepared [ArrayIndexPlan]() declines either of them; [ArrayIndexPlan]() carries that rule, and [ArrayIndexContract]() what a target does. An option name [ArrayIndexPattern]() does not declare is declined before any setting is read.
- `"DefaultOutput"` resolves the output shape of a descriptor that writes none. `"Contracted"`, the default here, keeps the axes occurring exactly once, in first-occurrence order; `"Identity"` keeps the single input shape. An empty output side, as in `"ij->"`, is an output shape that is empty and not a missing one, so `"ij"` has output rank 2 and `"ij->"` has output rank 0.
- The occurrence policy is not decided here: a descriptor the grammar accepts may still be declined where it is analyzed, and `"Effects"` and `"Targets"` run that analysis, so a property lookup can report an `ArrayIndexPlan` message.
- The object is inert and is taken apart rather than recompiled wherever it stands in a descriptor position, for [ArrayIndexPlan](), [ArrayIndexContract]() and [ArrayIndexTransform]() alike, which is the compile-once path. It carries the axis sizes its own construction resolved as well as its settings, so a binding list given with a prepared pattern or a prepared [ArrayIndexPlan]() is declined with an `ArrayIndexPattern::bindings` or an `ArrayIndexPlan::bindings` message: bind the axis in the call that builds the object.
- Its summary box and its property protocol are [ArrayObject]()'s. An unknown property gives an `ArrayIndexPattern::noprop` message, any number of arguments other than one property name gives an `ArrayIndexPattern::propx` message, and a property read from anything other than a compiled pattern gives an `ArrayIndexPattern::malformed` message; each lookup stays unevaluated.

## Basic Examples

<!-- #| annotation: 04.09.26: Design review - the object is the pipeline stopped at normalization: it carries the normalized descriptor and the "Targeting" setting the parse was given, and nothing derived from them. The grammar, the hygiene rules and the binding keys are what a pattern decides; the occurrence policy - a diagonal kept, three occurrences in one operand, a target on an axis that carries no contraction - is the operation analysis, which "Effects" and "Targets" run on demand, and that is why a property lookup can report an ArrayIndexPlan message while the parse that accepted the grammar reports nothing. Storing the analysis in the object instead would turn every occurrence-policy refusal into a parse refusal and put a plan-stage message on this symbol. The setting travels with the descriptor because it selects which occurrences count as targeted and the analysis cannot be rebuilt without it. An axis is interned to a positive integer rather than to a symbol: an adversarial $Context breaks any resolver that maps a name back to a symbol, a user symbol cannot be held as an identity without risking evaluation somewhere in the pipeline, Unique[] demands a lifecycle and leaks into Names[], and an integer domain keeps the solver free of user symbols. The intern key is a function of the spelling alone, so an inline size does not appear in it and a sized occurrence is the same axis as an unsized one of the same spelling; letting a size carry a kind of its own would turn {{i, Annotation[j, 2]}, {j, k}} from a matrix product into an outer product. -->

A descriptor parsed into a pattern object, whose summary box shows the axes it names and the rank of each operand:

```wl
ArrayIndexPattern["ij,jk->ik"]
```

<!-- => an ArrayIndexPattern summary box: axes {i, j, k}, operands {2, 2} -->

---

The axes, in first-occurrence order:

```wl
ArrayIndexPattern["ij,jk->ik"]["Axes"]
```

<!-- => {"i", "j", "k"} -->

---

What the descriptor does with each of them, one record per axis:

```wl
ArrayIndexPattern["ij,jk->ik"]["Effects"]
```

<!-- => {<|"Effect" -> "Carried", "Axis" -> 1, "Inputs" -> {{1, 1}}, "Outputs" -> {{1, 1}}|>, <|"Effect" -> "Contracted", "Axis" -> 2, "Inputs" -> {{1, 2}, {2, 1}}|>, <|"Effect" -> "Carried", "Axis" -> 3, "Inputs" -> {{2, 2}}, "Outputs" -> {{1, 2}}|>} -->

---

The supported properties:

```wl
ArrayIndexPattern["ij,jk->ik"]["Properties"]
```

<!-- => {"Axes", "Constraints", "Descriptor", "Dialect", "Effects", "InputRanks", "OutputRank", "Properties", "Targets"} -->

## Scope

### Dialects

A string with no whitespace is tokenized character by character, so each letter is one axis term:

```wl
ArrayIndexPattern["ij,jk->ik"]["InputRanks"]
```

<!-- => {2, 2} -->

---

A string containing whitespace is tokenized by identifier, which keeps multi-character names:

```wl
ArrayIndexPattern["b s d, d e -> b s e"]["InputRanks"]
```

<!-- => {3, 2} -->

---

The mode is read off the whole string, so one space anywhere makes every name an identifier and `"ij"` becomes a single axis:

```wl
ArrayIndexPattern["ij, jk->ik"]["InputRanks"]
```

<!-- => {1, 1} -->

---

A list of input shapes given as a [RuleDelayed]() to a list of output shapes is the Wolfram dialect:

```wl
ArrayIndexPattern[{{i_, j_}, {j_, k_}} :> {{i, k}}]["Dialect"]
```

<!-- => "Expression" -->

---

The same list written with [Rule]() compiles and reports its own spelling, with a message saying that both sides evaluated before the descriptor was read:

```wl
ArrayIndexPattern[{{i, j}, {j, k}} -> {{i, k}}]["Dialect"]
```

<!-- => ArrayIndexPattern::rule message, then "IndexList" -->

---

A bare shape stands for a one-operand descriptor:

```wl
ArrayIndexPattern[{i_, j_}]["InputRanks"]
```

<!-- => {2} -->

---

The three spellings agree on the pattern they name; the identifier string gives the effects the classic string gave above:

```wl
ArrayIndexPattern["i j, j k -> i k"]["Effects"]
```

<!-- => {<|"Effect" -> "Carried", "Axis" -> 1, "Inputs" -> {{1, 1}}, "Outputs" -> {{1, 1}}|>, <|"Effect" -> "Contracted", "Axis" -> 2, "Inputs" -> {{1, 2}, {2, 1}}|>, <|"Effect" -> "Carried", "Axis" -> 3, "Inputs" -> {{2, 2}}, "Outputs" -> {{1, 2}}|>} -->

---

And so does the list of shapes:

```wl
ArrayIndexPattern[{{i_, j_}, {j_, k_}} :> {{i, k}}]["Effects"]
```

<!-- => {<|"Effect" -> "Carried", "Axis" -> 1, "Inputs" -> {{1, 1}}, "Outputs" -> {{1, 1}}|>, <|"Effect" -> "Contracted", "Axis" -> 2, "Inputs" -> {{1, 2}, {2, 1}}|>, <|"Effect" -> "Carried", "Axis" -> 3, "Inputs" -> {{2, 2}}, "Outputs" -> {{1, 2}}|>} -->

### Axes and hygiene

A composite is one axis term over two axes, and its factors are recorded as a product constraint naming them by identity:

```wl
ArrayIndexPattern["(i j) -> i j"]["Constraints"]
```

<!-- => {<|"Constraint" -> "Product", "Axes" -> {1, 2}, "Source" -> {"Inputs", 1, 1}|>} -->

---

A name repeated within one input shape and absent from the output is self-contracted, its two occurrences on one operand:

```wl
ArrayIndexPattern["ii->"]["Effects"]
```

<!-- => {<|"Effect" -> "SelfContracted", "Axis" -> 1, "Inputs" -> {{1, 1}, {1, 2}}|>} -->

---

A batch descriptor carries three axes and contracts one:

```wl
ArrayIndexPattern["bij,bjk->bik"]["Effects"]
```

<!-- => {<|"Effect" -> "Carried", "Axis" -> 1, "Inputs" -> {{1, 1}, {2, 1}}, "Outputs" -> {{1, 1}}|>, <|"Effect" -> "Carried", "Axis" -> 2, "Inputs" -> {{1, 2}}, "Outputs" -> {{1, 2}}|>, <|"Effect" -> "Contracted", "Axis" -> 3, "Inputs" -> {{1, 3}, {2, 2}}|>, <|"Effect" -> "Carried", "Axis" -> 4, "Inputs" -> {{2, 3}}, "Outputs" -> {{1, 3}}|>} -->

---

A blank binds one logical axis whatever a symbol of that name is bound to where the descriptor is written:

```wl
Block[{j = 3}, ArrayIndexPattern[{{i_, j_}, {j_, k_}} :> {{i, k}}]["Axes"]]
```

<!-- => {"i", "j", "k"} -->

---

A bare symbol on the input side is an ambient expression, and a bound one arrives as its value, so the same descriptor spelled with a bare `j` names two literal axes of size 3:

```wl
Block[{j = 3}, ArrayIndexPattern[{{i_, j}, {j, k_}} :> {{i, k}}]["Axes"]]
```

<!-- => {"i", "3", "3", "k"} -->

A literal takes a fresh identity at every occurrence, so the two are summed separately rather than contracted against one another:

```wl
Block[{j = 3}, ArrayIndexPattern[{{i_, j}, {j, k_}} :> {{i, k}}]["Effects"]]
```

<!-- => {<|"Effect" -> "Carried", "Axis" -> 1, "Inputs" -> {{1, 1}}, "Outputs" -> {{1, 1}}|>, <|"Effect" -> "Contracted", "Axis" -> 2, "Inputs" -> {{1, 2}}|>, <|"Effect" -> "Contracted", "Axis" -> 3, "Inputs" -> {{2, 1}}|>, <|"Effect" -> "Carried", "Axis" -> 4, "Inputs" -> {{2, 2}}, "Outputs" -> {{1, 2}}|>} -->

---

A string axis consults no symbol of that name:

```wl
Block[{j = 3}, ArrayIndexPattern[{{i_, "j"}, {"j", k_}} :> {{i, k}}]["Axes"]]
```

<!-- => {"i", "j", "k"} -->

---

Nor does a targeted `#j`, [Slot]() carrying a string:

```wl
Block[{j = 3}, ArrayIndexPattern[{{i_, #j}, {#j, k_}} :> {{i, k}}]["Axes"]]
```

<!-- => {"i", "j", "k"} -->

---

An anonymous axis has no name to be referenced by and is displayed as the underscore it was written as:

```wl
ArrayIndexPattern[{{i_, _}} :> {{i}}]["Axes"]
```

<!-- => {"i", "_"} -->

### Targets

Brackets mark an axis in the string dialects, which read them under identifier tokenizing:

```wl
ArrayIndexPattern["i [j], [j] k -> i k"]["Targets"]
```

<!-- => {"j"} -->

---

A [Slot]() marks a string axis in the Wolfram dialect:

```wl
ArrayIndexPattern[{{i_, #j}, {#j, k_}} :> {{i, k}}]["Targets"]
```

<!-- => {"j"} -->

---

[Framed]() marks an axis spelled as a symbol, as [Highlighted]() does:

```wl
ArrayIndexPattern[{{i_, Framed[j_]}, {Framed[j_], k_}} :> {{i, k}}]["Targets"]
```

<!-- => {"j"} -->

---

With `"Targeting" -> False` the target wrappers are ignored, and the descriptor marks nothing:

```wl
ArrayIndexPattern[{{i_, #j}, {#j, k_}} :> {{i, k}}, "Targeting" -> False]["Targets"]
```

<!-- => {} -->

### Bindings

A binding list is the second argument and options trail it; an axis sized out of band is an axis of the pattern:

```wl
ArrayIndexPattern["i -> i j", {"j" -> 3}, "DefaultOutput" -> "Identity"]["Axes"]
```

<!-- => {"i", "j"} -->

---

The size a binding gives is recorded as a known-size constraint on that axis:

```wl
ArrayIndexPattern["i -> i j", {"j" -> 3}]["Constraints"]
```

<!-- => {<|"Constraint" -> "KnownSize", "Axis" -> 2, "Size" -> 3, "Source" -> None|>} -->

---

An axis spelled as a bare symbol is keyed by that symbol:

```wl
ArrayIndexPattern[{{i_}} :> {{i, j}}, {j -> 3}]["Constraints"]
```

<!-- => {<|"Constraint" -> "KnownSize", "Axis" -> 2, "Size" -> 3, "Source" -> None|>} -->

---

An inline [Annotation]() gives the same size in the descriptor itself, and the constraint records where it was written:

```wl
ArrayIndexPattern[{{i_}} :> {{i, Annotation[j, 3]}}]["Constraints"]
```

<!-- => {<|"Constraint" -> "KnownSize", "Axis" -> 2, "Size" -> 3, "Source" -> {"Outputs", 1, 2}|>} -->

## Properties and Relations

A prepared pattern stands where [ArrayIndexPlan]() takes a descriptor, which is the compile-once path:

```wl
ArrayIndexPlan[ArrayIndexPattern["ij,jk->ik"], {{2, 2}, {2, 2}}]
```

<!-- => an ArrayIndexPlan summary box: operands {{2, 2}, {2, 2}}, dimensions {2, 2} -->

---

[ArrayIndexContract]() takes one in the same position:

```wl
ArrayIndexContract[ArrayIndexPattern["ij,jk->ik"], {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}]
```

<!-- => {{19, 22}, {43, 50}} -->

---

And so does [ArrayIndexTransform]():

```wl
ArrayIndexTransform[ArrayIndexPattern["ij->ji"], {{1, 2}, {3, 4}}]
```

<!-- => {{1, 3}, {2, 4}} -->

---

A plan gives back the pattern it was built from:

```wl
ArrayIndexPlan["ij,jk->ik", {{2, 2}, {2, 2}}]["Pattern"]
```

<!-- => an ArrayIndexPattern summary box: axes {i, j, k}, operands {2, 2} -->

Its axes are the descriptor's:

```wl
ArrayIndexPlan["ij,jk->ik", {{2, 2}, {2, 2}}]["Pattern"]["Axes"]
```

<!-- => {"i", "j", "k"} -->

## Possible Issues

An argument that is neither a string nor a list of shapes gives an `ArrayIndexPattern::parse` message and stays unevaluated:

```wl
ArrayIndexPattern[42]
```

<!-- => ArrayIndexPattern::parse message, then ArrayIndexPattern[42] unevaluated -->

---

A character the tokenizer does not admit is named, together with the string it was found in:

```wl
ArrayIndexPattern["i$j->i"]
```

<!-- => ArrayIndexPattern::token message, then ArrayIndexPattern["i$j->i"] unevaluated -->

---

An expression that is not an axis term is named as written:

```wl
ArrayIndexPattern[{{i_, f[j_]}} :> {{i}}]
```

<!-- => ArrayIndexPattern::term message, then ArrayIndexPattern[{{i_, f[j_]}} :> {{i}}] unevaluated -->

---

A construct outside the compiled vocabulary is named by the fragment that carries it, here a direct sum:

```wl
ArrayIndexPattern[{{CirclePlus[a1_, b1_]}} :> {{a1}, {b1}}]
```

<!-- => ArrayIndexPattern::unsupported message naming the direct sum, then ArrayIndexPattern[{{CirclePlus[a1_, b1_]}} :> {{a1}, {b1}}] unevaluated, the direct sum echoed in operator form -->

---

An ellipsis is declined the same way, rather than read as a rank the descriptor did not write:

```wl
ArrayIndexPattern["... i -> i ..."]
```

<!-- => ArrayIndexPattern::unsupported message naming "...", then ArrayIndexPattern["... i -> i ..."] unevaluated -->

---

One output shape is compiled, so a descriptor giving two is declined:

```wl
ArrayIndexPattern[{{i_, j_}} :> {{i}, {j}}]
```

<!-- => ArrayIndexPattern::outputs message, then ArrayIndexPattern[{{i_, j_}} :> {{i}, {j}}] unevaluated -->

---

An axis repeated within one output shape names no layout:

```wl
ArrayIndexPattern["i->ii"]
```

<!-- => ArrayIndexPattern::duplicate message, then ArrayIndexPattern["i->ii"] unevaluated -->

---

One name takes one spelling, a blank and a string carrying different hygiene:

```wl
ArrayIndexPattern[{{i_, "i"}} :> {{i}}]
```

<!-- => ArrayIndexPattern::mishmash message, then ArrayIndexPattern[{{i_, "i"}} :> {{i}}] unevaluated -->

---

A bare output axis with no binder of the same name reads its ambient value, and a value that is neither a positive integer nor an identifier string names no axis:

```wl
jj = 1.5;
ArrayIndexPattern[{{i_, k_}} :> {{i, jj}}]
```

<!-- => ArrayIndexPattern::ambient message, then ArrayIndexPattern[{{i_, k_}} :> {{i, jj}}] unevaluated -->

---

A blank axis takes its size from the operand, so a [Pattern]() binding key is declined rather than ignored:

```wl
ArrayIndexPattern["i j", {i_ -> 3}]
```

<!-- => ArrayIndexPattern::patternkey message, then ArrayIndexPattern["i j", {i_ -> 3}] unevaluated -->

---

So is a key naming no axis of the descriptor:

```wl
ArrayIndexPattern["i j", {"z" -> 3}]
```

<!-- => ArrayIndexPattern::bindingkey message, then ArrayIndexPattern["i j", {"z" -> 3}] unevaluated -->

---

The occurrence policy is decided by the analysis, so a property that runs it reports an `ArrayIndexPlan` message; here `"Targeting" -> True` asks every contracted axis to carry a target and the descriptor writes none:

```wl
ArrayIndexPattern["ij,jk->ik", "Targeting" -> True]["Targets"]
```

<!-- => ArrayIndexPlan::target message, then the property lookup unevaluated, the pattern rendering as its summary box -->

---

An unsupported property is named and the lookup stays unevaluated:

```wl
ArrayIndexPattern["ij"]["Bogus"]
```

<!-- => ArrayIndexPattern::noprop message, then the lookup unevaluated, the pattern rendering as its summary box -->

---

So does a lookup given anything other than one property name:

```wl
ArrayIndexPattern["ij"]["Axes", "Dialect"]
```

<!-- => ArrayIndexPattern::propx message, then the lookup unevaluated, the pattern rendering as its summary box -->

---

`"Targeting"` and `"DefaultOutput"` are resolved where a descriptor is compiled, so a call reusing a prepared pattern is declined either of them; see [ArrayIndexPlan]() for the rule:

```wl
pat = ArrayIndexPattern["ij,jk->ik"];
ArrayIndexPlan[pat, {{2, 2}, {2, 2}}, "Targeting" -> True]
```

<!-- => ArrayIndexPattern::prepared message, then ArrayIndexPlan[pat, {{2, 2}, {2, 2}}, "Targeting" -> True] unevaluated, pat rendering as its summary box -->

---

A binding list is read where a descriptor is compiled as well, so a prepared pattern is declined one rather than dropping the size it names; bind `j` in the call that builds the pattern:

```wl
ArrayIndexTransform[ArrayIndexPattern["i -> i j"], {1, 2}, {"j" -> 3}]
```

<!-- => ArrayIndexPattern::bindings message, then the call unevaluated, the pattern rendering as its summary box -->

