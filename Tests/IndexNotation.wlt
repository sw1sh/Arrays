(* Tests for the index-notation front end of Wolfram/Arrays: the three dialects
   ArrayIndexPattern parses, the whitespace rule that disambiguates them, the
   term vocabulary (literals, anonymous axes, CircleTimes composites, inline
   sizes), the axis-identity and hygiene rules, the Rule/RuleDelayed asymmetry,
   and the refusal of every construct outside the compiled vocabulary.
   Run via Tests/RunTests.wls or TestReport. *)

Needs["Wolfram`Arrays`"]

(* === fixtures === *)

$notationMat = {{1, 2}, {3, 4}}
$notationOther = {{5, 6}, {7, 8}}
$notationWide = {{1, 2, 3}, {4, 5, 6}}
$notationVec = {1, 2}

(* The matrix product of the two 2x2 fixtures, written out so the expected value
   of a contraction is arithmetic rather than a second run of the pipeline. *)
$notationProduct = {{1*5 + 2*7, 1*6 + 2*8}, {3*5 + 4*7, 3*6 + 4*8}}

(* An interned axis is an operation-local integer under a package-private head,
   so identity is tested by comparing occurrences to EACH OTHER rather than by
   naming the head: what a hygiene rule decides is which two occurrences are the
   same axis, and that survives whatever the identity is spelled as. *)
notationInputTerms[pattern_] := First[pattern["Descriptor"]["Inputs"]]

notationOutputTerms[pattern_] := First[pattern["Descriptor"]["Outputs"]]


BeginTestSection["index notation - the three dialects"]

(* The consolidation claim: the einsum string, the index-list Rule and the
   Einstoff-style RuleDelayed are three spellings of one descriptor.  They agree
   on the interned shapes, on the axis names and on the operand ranks; they
   differ only in the dialect they report and in the targeting a #j records,
   which is a target wrapper and not an axis identity. *)
VerificationTest[
    Block[{i, j, k},
        With[{
                fromString = ArrayIndexPattern["ij,jk->ik"],
                fromList = ArrayIndexPattern[{{i, j}, {j, k}} -> {{i, k}}],
                fromExpression = ArrayIndexPattern[{{i_, #j}, {#j, k_}} :> {{i, k}}]
            },
            {
                fromString["Descriptor"]["Inputs"] === fromList["Descriptor"]["Inputs"] ===
                    fromExpression["Descriptor"]["Inputs"],
                fromString["Descriptor"]["Outputs"] === fromList["Descriptor"]["Outputs"] ===
                    fromExpression["Descriptor"]["Outputs"],
                {fromString["Axes"], fromList["Axes"], fromExpression["Axes"]},
                {fromString["InputRanks"], fromList["InputRanks"], fromExpression["InputRanks"]},
                {fromString["Dialect"], fromList["Dialect"], fromExpression["Dialect"]},
                {fromString["Targets"], fromList["Targets"], fromExpression["Targets"]}
            }
        ]
    ],
    {
        True,
        True,
        {{"i", "j", "k"}, {"i", "j", "k"}, {"i", "j", "k"}},
        {{2, 2}, {2, 2}, {2, 2}},
        {"String", "IndexList", "Expression"},
        {{}, {}, {"j"}}
    },
    {ArrayIndexPattern::rule},
    TestID -> "indexnotation-three-dialects-one-descriptor"
]

VerificationTest[
    Block[{i, j, k},
        {
            ArrayIndexContract["ij,jk->ik", {$notationMat, $notationOther}],
            ArrayIndexContract[{{i, j}, {j, k}} -> {{i, k}}, {$notationMat, $notationOther}],
            ArrayIndexContract[{{i_, #j}, {#j, k_}} :> {{i, k}}, {$notationMat, $notationOther}]
        }
    ],
    {$notationProduct, $notationProduct, $notationProduct},
    {ArrayIndexPattern::rule},
    TestID -> "indexnotation-three-dialects-one-contraction"
]

(* A bare shape stands for a one-operand descriptor and a descriptor with no
   arrow is shape-preserving, so the two call-site sugars normalize to the same
   list-of-shapes form the arrowed spellings give. *)
VerificationTest[
    {
        ArrayIndexTransform[{"i", "j"} :> {"j", "i"}, $notationMat],
        ArrayIndexTransform[{{"i", "j"}}, $notationMat],
        ArrayIndexTransform["i j", $notationMat]
    },
    {Transpose[$notationMat], $notationMat, $notationMat},
    TestID -> "indexnotation-call-site-sugars"
]

EndTestSection[]


BeginTestSection["index notation - the string dialect"]

(* The whitespace rule of the design, in both directions.  With no space the
   string is read character by character, so "ij" names two axes; with a space
   it is read by identifier, so the same characters name ONE axis called "ij".
   Neither reading is a mode flag and neither is ambiguous. *)
VerificationTest[
    {
        ArrayIndexPattern["ij->ji"]["Axes"], ArrayIndexPattern["ij->ji"]["InputRanks"],
        ArrayIndexPattern["i j -> j i"]["Axes"], ArrayIndexPattern["i j -> j i"]["InputRanks"],
        ArrayIndexPattern["ij -> ji"]["Axes"], ArrayIndexPattern["ij -> ji"]["InputRanks"]
    },
    {{"i", "j"}, {2}, {"i", "j"}, {2}, {"ij", "ji"}, {1}},
    TestID -> "indexnotation-whitespace-disambiguation"
]

(* The two spellings of the same three axes compile to the same descriptor, and
   the spaced one is the only one that can keep multi-character names. *)
VerificationTest[
    {
        ArrayIndexPattern["i j, j k -> i k"]["Descriptor"]["Inputs"] ===
            ArrayIndexPattern["ij,jk->ik"]["Descriptor"]["Inputs"],
        ArrayIndexPattern["b s d, d e -> b s e"]["Axes"],
        ArrayIndexPattern["b s d, d e -> b s e"]["InputRanks"]
    },
    {True, {"b", "s", "d", "e"}, {3, 2}},
    TestID -> "indexnotation-whitespace-identifier-names"
]

VerificationTest[
    {
        ArrayIndexTransform["ij->ji", $notationMat],
        ArrayIndexTransform["i j -> j i", $notationMat]
    },
    {Transpose[$notationMat], Transpose[$notationMat]},
    TestID -> "indexnotation-whitespace-both-transpose"
]

(* An empty segment is the empty shape, which is what makes a scalar output and
   a scalar operand expressible: a splitter over characters has no way to write
   either. *)
VerificationTest[
    {
        ArrayIndexContract["ij->", {$notationMat}],
        ArrayIndexContract[",ij", {2, $notationMat}]
    },
    {1 + 2 + 3 + 4, 2 * $notationMat},
    TestID -> "indexnotation-string-empty-segments"
]

(* With no output segment the contraction keeps the axes occurring exactly once,
   in first-occurrence order. *)
VerificationTest[
    ArrayIndexContract["ij,jk", {$notationMat, $notationOther}],
    $notationProduct,
    TestID -> "indexnotation-string-default-output"
]

EndTestSection[]


BeginTestSection["index notation - the term vocabulary"]

(* A positive integer is a literal axis: it is checked against the operand
   dimension and, having no name to be referenced by, it is summed rather than
   carried. *)
VerificationTest[
    {
        ArrayIndexPattern["i 3 -> i"]["Axes"],
        ArrayIndexPattern["i 3 -> i"]["InputRanks"],
        ArrayIndexContract["i 3 -> i", {$notationWide}],
        ArrayIndexContract[{{i_, 3}} :> {{i}}, {$notationWide}]
    },
    {{"i", "3"}, {2}, {1 + 2 + 3, 4 + 5 + 6}, {1 + 2 + 3, 4 + 5 + 6}},
    TestID -> "indexnotation-integer-literal-axis"
]

VerificationTest[
    MatchQ[ArrayIndexContract[{{i_, 3}} :> {{i}}, {$notationMat}], _ArrayIndexContract],
    True,
    {ArrayIndexPlan::literal},
    TestID -> "indexnotation-integer-literal-checked-against-the-operand"
]

(* A literal 1 is a unit axis: squeezed where the input writes it and inserted
   where the output does. *)
VerificationTest[
    {
        ArrayIndexTransform["i 1 -> i", {{1}, {2}, {3}}],
        ArrayIndexTransform["i -> i 1", {1, 2, 3}]
    },
    {{1, 2, 3}, {{1}, {2}, {3}}},
    TestID -> "indexnotation-unit-axis-squeezed-and-inserted"
]

(* An anonymous axis has no name, so it cannot be shared: two of them are two
   axes, and each is summed over. *)
VerificationTest[
    With[{pattern = ArrayIndexPattern[{{_, _}} :> {{}}]},
        {
            pattern["Axes"],
            SameQ @@ notationInputTerms[pattern],
            ArrayIndexContract[{{i_, _}} :> {{i}}, {$notationMat}]
        }
    ],
    {{"_", "_"}, False, {1 + 2, 3 + 4}},
    TestID -> "indexnotation-anonymous-axes-are-distinct"
]

(* A CircleTimes composite splits one dimension into its factors with the
   leftmost factor outermost on the input side and merges them again on the
   output side. *)
VerificationTest[
    {
        ArrayIndexTransform[{{CircleTimes[Annotation["h", 2], "c"]}} :> {{"h", "c"}}, Range[6]],
        ArrayIndexTransform[{{"h", "c"}} :> {{CircleTimes["h", "c"]}}, $notationWide],
        ArrayIndexTransform["(h c) -> h c", Range[6], {"h" -> 2}],
        ArrayIndexTransform["(h c w) -> h c w", Range[12], {"h" -> 2, "c" -> 3}]
    },
    {
        {{1, 2, 3}, {4, 5, 6}},
        {1, 2, 3, 4, 5, 6},
        {{1, 2, 3}, {4, 5, 6}},
        {{{1, 2}, {3, 4}, {5, 6}}, {{7, 8}, {9, 10}, {11, 12}}}
    },
    TestID -> "indexnotation-composite-splits-and-merges"
]

(* The merge follows the order the OUTPUT composite writes, not the order the
   input shape had: with h of size 2 and c of size 3, (c h) runs c outermost. *)
VerificationTest[
    ArrayIndexTransform[{{"h", "c"}} :> {{CircleTimes["c", "h"]}}, $notationWide],
    Flatten[Transpose[$notationWide]],
    TestID -> "indexnotation-composite-merge-follows-the-output-order"
]

(* CircleTimes is not Flat, so associativity is applied at capture: a nested
   product names the same three factors as the flat one. *)
VerificationTest[
    With[{pattern = ArrayIndexPattern[{{CircleTimes[CircleTimes["a", "b"], "c"]}} :> {{"a", "b", "c"}}]},
        {pattern["Axes"], pattern["InputRanks"], pattern["OutputRank"]}
    ],
    {{"a", "b", "c"}, {1}, 3},
    TestID -> "indexnotation-composite-associativity"
]

(* Annotation and Labeled are the two spellings of one inline size, and a
   binding rule gives the same size out of band.  A composite with one unknown
   factor resolves by division, so naming h fixes c and naming c fixes h. *)
VerificationTest[
    {
        ArrayIndexTransform[{{CircleTimes[Annotation["h", 2], "c"]}} :> {{"h", "c"}}, Range[6]],
        ArrayIndexTransform[{{CircleTimes[Labeled[2, "h"], "c"]}} :> {{"h", "c"}}, Range[6]],
        ArrayIndexTransform[{{CircleTimes["h", Labeled[3, "c"]]}} :> {{"h", "c"}}, Range[6]]
    },
    {{{1, 2, 3}, {4, 5, 6}}, {{1, 2, 3}, {4, 5, 6}}, {{1, 2, 3}, {4, 5, 6}}},
    TestID -> "indexnotation-inline-sizes-annotation-and-labeled"
]

(* An inline size supplies a size and nothing else.  The axis it sits on is the
   axis its spelling names, so Annotation[j, 2] is the same j that a bare j is
   and the two occurrences contract; giving the size a spelling of its own would
   turn the matrix product below into an outer product with no message. *)
VerificationTest[
    Block[{i, j, k},
        {
            ArrayIndexContract[{{i, j}, {j, k}} :> {{i, k}}, {$notationMat, $notationMat}],
            ArrayIndexContract[{{i, Annotation[j, 2]}, {j, k}} :> {{i, k}}, {$notationMat, $notationMat}],
            ArrayIndexContract[{{i, Labeled[2, j]}, {j, k}} :> {{i, k}}, {$notationMat, $notationMat}],
            ArrayIndexPattern[{{i, Annotation[j, 2]}, {j, k}} :> {{i, k}}]["Axes"]
        }
    ],
    {
        $notationMat . $notationMat,
        $notationMat . $notationMat,
        $notationMat . $notationMat,
        {"i", "j", "k"}
    },
    TestID -> "indexnotation-inline-size-does-not-split-the-axis"
]

(* A size on a bare symbol still has to agree with the operand, which is the
   other half of the same rule: one axis, so one size. *)
VerificationTest[
    Block[{i, j, k},
        Head[ArrayIndexContract[{{i, Annotation[j, 3]}, {j, k}} :> {{i, k}}, {$notationMat, $notationMat}]]
    ],
    ArrayIndexContract,
    {ArrayIndexPlan::conflict},
    TestID -> "indexnotation-inline-size-must-agree-with-the-operand"
]

(* Because the size carries no spelling, a sized symbol reaches the no-mishmash
   check as the symbol it is: one name still takes one spelling. *)
VerificationTest[
    Block[{aq},
        MatchQ[ArrayIndexPattern[{{Annotation[aq, 2], "bq"}, {"aq", "cq"}} :> {{"bq", "cq"}}], _ArrayIndexPattern]
    ],
    True,
    {ArrayIndexPattern::mishmash},
    TestID -> "indexnotation-sized-symbol-and-string-are-a-mishmash"
]

(* An axis written only on the output side is repeated to the size an inline
   annotation, a Labeled or a binding gives it. *)
VerificationTest[
    {
        ArrayIndexTransform[{{"i"}} :> {{"i", Annotation["r", 3]}}, $notationVec],
        ArrayIndexTransform[{{"i"}} :> {{"i", Labeled[3, "r"]}}, $notationVec],
        ArrayIndexTransform["i -> i r", $notationVec, {"r" -> 3}]
    },
    ConstantArray[{{1, 1, 1}, {2, 2, 2}}, 3],
    TestID -> "indexnotation-output-only-axis-is-repeated"
]

(* A composite whose factors are all unknown leaves the system underdetermined,
   and a composite whose known factors do not divide the dimension has no
   solution; both are named refusals rather than a guessed split. *)
VerificationTest[
    {
        MatchQ[ArrayIndexTransform[{{CircleTimes["h", "c"]}} :> {{"h", "c"}}, Range[6]], _ArrayIndexTransform],
        MatchQ[ArrayIndexTransform["(h c) -> h c", Range[7], {"h" -> 2}], _ArrayIndexTransform]
    },
    {True, True},
    {ArrayIndexPlan::unresolved, ArrayIndexPlan::composite},
    TestID -> "indexnotation-composite-sizes-must-solve"
]

EndTestSection[]


BeginTestSection["index notation - axis identity and hygiene"]

(* REGRESSION 1.  The complete input side is one binder scope, so both
   occurrences of a_ are the same logical axis.  The descriptor parses to ONE
   axis and says so; keeping it on the output is diagonal-keep, which has no
   lowering here and is refused where it is asked to lower, while dropping it is
   the trace. *)
VerificationTest[
    With[{pattern = ArrayIndexPattern[{{aq_, aq_}} :> {{aq}}]},
        {pattern["Axes"], SameQ @@ notationInputTerms[pattern], ArrayIndexContract[{{aq_, aq_}} :> {{}}, {$notationMat}]}
    ],
    {{"aq"}, True, 1 + 4},
    TestID -> "indexnotation-hygiene-repeated-blank-is-one-axis"
]

VerificationTest[
    MatchQ[ArrayIndexContract[{{aq_, aq_}} :> {{aq}}, {$notationMat}], _ArrayIndexContract],
    True,
    {ArrayIndexPlan::diagonal},
    TestID -> "indexnotation-hygiene-repeated-blank-diagonal-refused"
]

(* REGRESSION 2.  "Ambient" does not mean "fresh at each occurrence": two bare
   occurrences of one unbound symbol are one axis, which is exactly why the
   classic einsum spelling {{i, j}, {j, k}} contracts over j. *)
VerificationTest[
    With[{pattern = ArrayIndexPattern[{{aq, aq}} :> {{aq}}]},
        {pattern["Axes"], SameQ @@ notationInputTerms[pattern], ArrayIndexContract[{{aq, aq}} :> {{}}, {$notationMat}]}
    ],
    {{"aq"}, True, 1 + 4},
    TestID -> "indexnotation-hygiene-repeated-bare-is-one-axis"
]

(* REGRESSION 3.  A bare a on the INPUT side is an ambient expression and is
   never localized by the presence of a_ elsewhere, so {{a_, a}} names two
   axes - and the bare a on the OUTPUT side references the completed binding, so
   the output axis is the blank's.  The second axis is therefore summed, and the
   descriptor is a row sum rather than a diagonal. *)
VerificationTest[
    With[{pattern = ArrayIndexPattern[{{aq_, aq}} :> {{aq}}]},
        {
            pattern["Axes"],
            SameQ @@ notationInputTerms[pattern],
            First[notationOutputTerms[pattern]] === First[notationInputTerms[pattern]],
            ArrayIndexContract[{{aq_, aq}} :> {{aq}}, {$notationMat}]
        }
    ],
    {{"aq", "aq"}, False, True, {1 + 2, 3 + 4}},
    TestID -> "indexnotation-hygiene-blank-and-bare-are-two-axes"
]

(* A bare symbol arrives EVALUATED, so a bound one is captured as its value: the
   descriptor the compiler sees names two literal axes of size 2, each nameless
   and therefore summed on its own.  The contraction the caller wrote does not
   happen, and the axis table records what did. *)
VerificationTest[
    Block[{jq = 2},
        {
            ArrayIndexPattern[{{iq_, jq}, {jq, kq_}} :> {{iq, kq}}]["Axes"],
            ArrayIndexContract[{{iq_, jq}, {jq, kq_}} :> {{iq, kq}}, {$notationMat, $notationOther}]
        }
    ],
    {
        {"iq", "2", "2", "kq"},
        Outer[Times, {1 + 2, 3 + 4}, {5 + 7, 6 + 8}]
    },
    TestID -> "indexnotation-hygiene-bound-bare-symbol-is-captured-as-its-value"
]

(* The same capture against an operand the value does not fit is a named
   refusal: the literal axis is checked, so the mistake is reported rather than
   carried. *)
VerificationTest[
    Block[{jq = 3},
        MatchQ[
            ArrayIndexContract[{{iq_, jq}, {jq, kq_}} :> {{iq, kq}}, {$notationMat, $notationOther}],
            _ArrayIndexContract
        ]
    ],
    True,
    {ArrayIndexPlan::literal},
    TestID -> "indexnotation-hygiene-captured-value-is-checked"
]

(* A blank, a string and a #-slot are immune to the binding: none of them is an
   ambient expression, so all three still contract over j where the bare
   spelling above was captured as 2. *)
VerificationTest[
    Block[{jq = 2},
        {
            ArrayIndexContract[{{iq_, jq_}, {jq_, kq_}} :> {{iq, kq}}, {$notationMat, $notationOther}],
            ArrayIndexContract[{{"iq", "jq"}, {"jq", "kq"}} :> {{"iq", "kq"}}, {$notationMat, $notationOther}],
            ArrayIndexContract[{{iq_, #jq}, {#jq, kq_}} :> {{iq, kq}}, {$notationMat, $notationOther}]
        }
    ],
    {$notationProduct, $notationProduct, $notationProduct},
    TestID -> "indexnotation-hygiene-blank-string-and-slot-are-immune"
]

(* On the output side a bare symbol with no binder of the same name reads its
   ambient value: a positive integer becomes a literal axis to repeat to, and an
   identifier string names the axis it spells. *)
VerificationTest[
    {
        Block[{dq = 3}, ArrayIndexTransform[{{"i"}} :> {{"i", dq}}, $notationVec]],
        Block[{dq = "r"}, ArrayIndexPattern[{{"i"}} :> {{"i", dq}}]["Axes"]]
    },
    {{{1, 1, 1}, {2, 2, 2}}, {"i", "r"}},
    TestID -> "indexnotation-hygiene-bare-output-symbol-reads-its-value"
]

(* A value that is neither a positive integer nor an identifier names no axis
   and is refused.  The MatchQ runs INSIDE the Block: a declined call is left as
   written, and the expression that comes back would parse differently once the
   binding it was refused for is gone. *)
VerificationTest[
    Block[{dq = 1.5},
        MatchQ[ArrayIndexPattern[{{"i"}} :> {{"i", dq}}], _ArrayIndexPattern]
    ],
    True,
    {ArrayIndexPattern::ambient},
    TestID -> "indexnotation-hygiene-bare-output-value-must-name-an-axis"
]

(* A Sequence value splices in argument position instead of arriving as one
   value, so it is caught by arity: an empty splice and a several-value splice
   each name no axis, and each takes the same refusal as any other unusable
   value. *)
VerificationTest[
    {
        Block[{dq},
            dq := Sequence[];
            MatchQ[ArrayIndexPattern[{{"i"}} :> {{"i", dq}}], _ArrayIndexPattern]
        ],
        Block[{dq},
            dq := Sequence["p", "q"];
            MatchQ[ArrayIndexPattern[{{"i"}} :> {{"i", dq}}], _ArrayIndexPattern]
        ]
    },
    {True, True},
    {ArrayIndexPattern::ambient, ArrayIndexPattern::ambient},
    TestID -> "indexnotation-hygiene-a-sequence-value-names-no-axis"
]

(* Wolfram contexts do not contribute to axis identity: two blanks of one name
   in two contexts are one axis, and the transpose below is written across
   contexts and still names the two axes it permutes. *)
VerificationTest[
    With[{pattern = ArrayIndexPattern[{{Foo`ax_, Bar`ax_}} :> {{Foo`ax}}]},
        {
            pattern["Axes"],
            SameQ @@ notationInputTerms[pattern],
            ArrayIndexTransform[{{Foo`ax_, Bar`bx_}} :> {{Bar`bx, Foo`ax}}, $notationMat]
        }
    ],
    {{"ax"}, True, Transpose[$notationMat]},
    TestID -> "indexnotation-hygiene-contexts-do-not-split-an-established-axis"
]

(* A BARE symbol is an ambient expression rather than an established name, so it
   interns by context and name: two bare cx in two contexts are two axes,
   exactly as they are two symbols with two values.  The output cx references
   the one written in its own context. *)
VerificationTest[
    With[{pattern = ArrayIndexPattern[{{Foo`cx, Bar`cx}} :> {{Foo`cx}}]},
        {
            pattern["Axes"],
            SameQ @@ notationInputTerms[pattern],
            First[notationOutputTerms[pattern]] === First[notationInputTerms[pattern]],
            ArrayIndexContract[{{Foo`cx, Bar`cx}} :> {{Foo`cx}}, {$notationMat}]
        }
    ],
    {{"cx", "cx"}, False, True, {1 + 2, 3 + 4}},
    TestID -> "indexnotation-hygiene-contexts-separate-two-ambient-axes"
]

(* One name takes one spelling.  A blank and a string carry different hygiene,
   so conflating them would silently give a Block-sensitive axis the immunity of
   a hygienic one. *)
VerificationTest[
    MatchQ[ArrayIndexPattern[{{aq_, "aq"}} :> {{"aq"}}], _ArrayIndexPattern],
    True,
    {ArrayIndexPattern::mishmash},
    TestID -> "indexnotation-hygiene-one-name-one-spelling"
]

(* Two spellings of two DIFFERENT names do not mix anything, so a blank axis and
   a string axis stand side by side. *)
VerificationTest[
    ArrayIndexTransform[{{aq_, "bq"}} :> {{"bq", aq}}, $notationMat],
    Transpose[$notationMat],
    TestID -> "indexnotation-hygiene-two-names-may-take-two-spellings"
]

EndTestSection[]


BeginTestSection["index notation - Rule and RuleDelayed"]

(* RuleDelayed holds the output shapes, which is the asymmetry the hygiene rules
   need; Rule evaluates both sides before the descriptor is read, so it warns.
   The warning is not a refusal - the classic einsum call sites are written with
   Rule and arrive intact when their symbols are unbound - and the two spellings
   compile to the same descriptor. *)
VerificationTest[
    Block[{i, j, k},
        ArrayIndexPattern[{{i, j}, {j, k}} -> {{i, k}}]["Descriptor"]["Outputs"] ===
            ArrayIndexPattern[{{i, j}, {j, k}} :> {{i, k}}]["Descriptor"]["Outputs"]
    ],
    True,
    {ArrayIndexPattern::rule},
    TestID -> "indexnotation-rule-warns-and-still-compiles"
]

VerificationTest[
    Block[{i, j, k}, ArrayIndexPattern[{{i, j}, {j, k}} :> {{i, k}}]["Axes"]],
    {"i", "j", "k"},
    TestID -> "indexnotation-ruledelayed-is-quiet"
]

(* What the warning is about.  Pattern holds its name, so the blank jq_ survives
   either arrow; the OUTPUT jq does not.  Under a binding, Rule has replaced it
   by 2 before the descriptor is read, so the descriptor that arrives is
   {{iq_, jq_}} -> {{2, iq}}: a third axis, the blank now summed rather than
   carried, and a contraction that broadcasts the row sums over a literal extent
   instead of the transpose the RuleDelayed spelling gives. *)
VerificationTest[
    Block[{jq = 2},
        {
            ArrayIndexPattern[{{iq_, jq_}} :> {{jq, iq}}]["Axes"],
            ArrayIndexTransform[{{iq_, jq_}} :> {{jq, iq}}, $notationMat],
            ArrayIndexPattern[{{iq_, jq_}} -> {{jq, iq}}]["Axes"],
            ArrayIndexContract[{{iq_, jq_}} -> {{jq, iq}}, {$notationMat}]
        }
    ],
    {
        {"iq", "jq"},
        Transpose[$notationMat],
        {"iq", "jq", "2"},
        {{1 + 2, 3 + 4}, {1 + 2, 3 + 4}}
    },
    {ArrayIndexPattern::rule, ArrayIndexPattern::rule},
    TestID -> "indexnotation-rule-evaluates-the-output-side"
]

EndTestSection[]


BeginTestSection["index notation - refusals"]

(* Every construct outside the compiled vocabulary is named rather than
   half-handled.  A direct sum, an ellipsis, a named sequence and a Repeated are
   grammar the notation reserves, so they report the construct they name and the
   call is left as written. *)
VerificationTest[
    {
        MatchQ[ArrayIndexPattern[{{CirclePlus["q", "k"]}} :> {{"q", "k"}}], _ArrayIndexPattern],
        MatchQ[ArrayIndexPattern[{{___, "c"}} :> {{"c"}}], _ArrayIndexPattern]
    },
    {True, True},
    {ArrayIndexPattern::unsupported, ArrayIndexPattern::unsupported},
    TestID -> "indexnotation-refuses-direct-sum-and-ellipsis"
]

VerificationTest[
    {
        MatchQ[ArrayIndexPattern[{{__, "c"}} :> {{"c"}}], _ArrayIndexPattern],
        MatchQ[ArrayIndexPattern[{{bq___, "c"}} :> {{"c"}}], _ArrayIndexPattern]
    },
    {True, True},
    {ArrayIndexPattern::unsupported, ArrayIndexPattern::unsupported},
    TestID -> "indexnotation-refuses-sequences-and-named-sequences"
]

VerificationTest[
    {
        MatchQ[ArrayIndexPattern[{{Repeated[bq_], "c"}} :> {{"c"}}], _ArrayIndexPattern],
        MatchQ[ArrayIndexPattern[{{RepeatedNull[bq_], "c"}} :> {{"c"}}], _ArrayIndexPattern]
    },
    {True, True},
    {ArrayIndexPattern::unsupported, ArrayIndexPattern::unsupported},
    TestID -> "indexnotation-refuses-repeated-terms"
]

(* A numbered slot and a slot sequence are Wolfram function slots, not axis
   targets: only a named slot #a targets an axis. *)
VerificationTest[
    {
        MatchQ[ArrayIndexPattern[{{#1, "c"}} :> {{"c"}}], _ArrayIndexPattern],
        MatchQ[ArrayIndexPattern[{{##, "c"}} :> {{"c"}}], _ArrayIndexPattern]
    },
    {True, True},
    {ArrayIndexPattern::unsupported, ArrayIndexPattern::unsupported},
    TestID -> "indexnotation-refuses-numbered-and-sequence-slots"
]

(* A literal has no name to be targeted by, so a target around one is refused
   rather than read as a target on the axis next to it. *)
VerificationTest[
    MatchQ[ArrayIndexPattern[{{Highlighted[4], "c"}} :> {{"c"}}], _ArrayIndexPattern],
    True,
    {ArrayIndexPattern::unsupported},
    TestID -> "indexnotation-refuses-a-targeted-literal"
]

(* The string dialect reserves "...", "+" and "=" and reports them as the
   constructs they name: recognizing them is the point, since "b ... d" must not
   quietly become a rank-2 descriptor. *)
VerificationTest[
    {
        MatchQ[ArrayIndexPattern["b ... d -> b d"], _ArrayIndexPattern],
        MatchQ[ArrayIndexPattern["(q + k) -> q k"], _ArrayIndexPattern]
    },
    {True, True},
    {ArrayIndexPattern::unsupported, ArrayIndexPattern::unsupported},
    TestID -> "indexnotation-refuses-reserved-string-spellings"
]

VerificationTest[
    MatchQ[ArrayIndexPattern["b s, h = 4 -> b s"], _ArrayIndexPattern],
    True,
    {ArrayIndexPattern::unsupported},
    TestID -> "indexnotation-refuses-the-kwarg-spelling-of-a-size"
]

(* A character the tokenizer does not admit is named together with the string it
   was found in, so the refusal quotes what the caller wrote. *)
VerificationTest[
    MatchQ[ArrayIndexPattern["i&j->i"], _ArrayIndexPattern],
    True,
    {ArrayIndexPattern::token},
    TestID -> "indexnotation-refuses-an-unknown-character"
]

(* A bracket names exactly one slot.  "[a b]", "[4]" and a nested "[[s]]" name
   no single slot, and each is quoted up to its MATCHING closer rather than up
   to the first one. *)
VerificationTest[
    {
        MatchQ[ArrayIndexPattern["[a b] c -> c"], _ArrayIndexPattern],
        MatchQ[ArrayIndexPattern["[[s]] c -> c"], _ArrayIndexPattern]
    },
    {True, True},
    {ArrayIndexPattern::term, ArrayIndexPattern::term},
    TestID -> "indexnotation-refuses-a-bracket-over-no-single-slot"
]

(* A composite does not nest and does not hold one factor: CircleTimes is
   associative, so "((a b) c)" names the same product as "(a b c)" and the
   nested spelling is declined rather than given a second reading. *)
VerificationTest[
    {
        MatchQ[ArrayIndexPattern["((a b) c) -> a b c"], _ArrayIndexPattern],
        MatchQ[ArrayIndexPattern["(h) -> h"], _ArrayIndexPattern]
    },
    {True, True},
    {ArrayIndexPattern::term, ArrayIndexPattern::term},
    TestID -> "indexnotation-refuses-a-nested-or-singleton-composite"
]

(* A term the grammar has no reading for is named as the term it is: a System
   symbol carries no axis name of its own, and a string that is not an
   identifier names no axis either. *)
VerificationTest[
    {
        MatchQ[ArrayIndexPattern[{{List, "c"}} :> {{"c"}}], _ArrayIndexPattern],
        MatchQ[ArrayIndexPattern[{{"a b", "c"}} :> {{"c"}}], _ArrayIndexPattern]
    },
    {True, True},
    {ArrayIndexPattern::term, ArrayIndexPattern::term},
    TestID -> "indexnotation-refuses-a-term-with-no-reading"
]

VerificationTest[
    MatchQ[ArrayIndexPattern[{{Slot[bq], "c"}} :> {{"c"}}], _ArrayIndexPattern],
    True,
    {ArrayIndexPattern::term},
    TestID -> "indexnotation-refuses-a-slot-around-a-symbol"
]

(* An unbalanced parenthesis, a second arrow and an empty string leave no
   descriptor to read at all. *)
VerificationTest[
    {
        MatchQ[ArrayIndexPattern["(h c -> h c"], _ArrayIndexPattern],
        MatchQ[ArrayIndexPattern["i->j->k"], _ArrayIndexPattern]
    },
    {True, True},
    {ArrayIndexPattern::parse, ArrayIndexPattern::parse},
    TestID -> "indexnotation-refuses-an-unreadable-string"
]

VerificationTest[
    {
        MatchQ[ArrayIndexPattern[""], _ArrayIndexPattern],
        MatchQ[ArrayIndexPattern[42], _ArrayIndexPattern]
    },
    {True, True},
    {ArrayIndexPattern::parse, ArrayIndexPattern::parse},
    TestID -> "indexnotation-refuses-a-non-descriptor"
]

(* One list of output shapes is compiled, and an axis repeated within one output
   shape names no layout: the tensor-power reading of {{i}} :> {{i, i}} is a
   surprising one and has none here. *)
VerificationTest[
    MatchQ[ArrayIndexPattern[{{"a", "b"}} :> {{"a"}, {"b"}}], _ArrayIndexPattern],
    True,
    {ArrayIndexPattern::outputs},
    TestID -> "indexnotation-refuses-several-output-shapes"
]

VerificationTest[
    MatchQ[ArrayIndexPattern[{{"i"}} :> {{"i", "i"}}], _ArrayIndexPattern],
    True,
    {ArrayIndexPattern::duplicate},
    TestID -> "indexnotation-refuses-a-repeated-output-axis"
]

(* A binding list is keyed the way the descriptor spells the axis.  A Pattern
   key is a hard rejection rather than a silent no-op, since a blank axis takes
   its size from the operand; a key naming no axis of this descriptor and a
   value that is not a positive integer are refused with it. *)
VerificationTest[
    MatchQ[ArrayIndexPattern["i j -> i j", {jq_ -> 3}], _ArrayIndexPattern],
    True,
    {ArrayIndexPattern::patternkey},
    TestID -> "indexnotation-refuses-a-pattern-binding-key"
]

VerificationTest[
    {
        MatchQ[ArrayIndexPattern["i j -> i j", {"z" -> 3}], _ArrayIndexPattern],
        MatchQ[ArrayIndexPattern["i j -> i j", {"j" -> 3/2}], _ArrayIndexPattern]
    },
    {True, True},
    {ArrayIndexPattern::bindingkey, ArrayIndexPattern::bindingkey},
    TestID -> "indexnotation-refuses-a-binding-that-names-no-axis-or-no-size"
]

(* A binding value that is a Sequence splices the pair down to one element in a
   bare read; the pair is read through a held wrapper instead, so the refusal
   is the one bindingkey message with no internal Set::shape beside it. *)
VerificationTest[
    {
        MatchQ[ArrayIndexPattern["i j", {"i" :> Sequence[]}], _ArrayIndexPattern],
        MatchQ[ArrayIndexPattern["i j", {"i" -> Sequence[2, 3]}], _ArrayIndexPattern]
    },
    {True, True},
    {ArrayIndexPattern::bindingkey, ArrayIndexPattern::bindingkey},
    TestID -> "indexnotation-refuses-a-sequence-binding-value"
]

(* An inline size on a blank is the same mistake as a Pattern binding key. *)
VerificationTest[
    MatchQ[ArrayIndexPattern[{{Annotation[aq_, 3]}} :> {{aq}}], _ArrayIndexPattern],
    True,
    {ArrayIndexPattern::patternkey},
    TestID -> "indexnotation-refuses-an-inline-size-on-a-blank"
]

(* A property that is not supported, and a property lookup with a count other
   than one, are declined the way the heads are: a message and the lookup left
   as written. *)
VerificationTest[
    {
        MatchQ[ArrayIndexPattern["ij->i"]["Bogus"], _[_String]],
        MatchQ[ArrayIndexPattern["ij->i"]["Axes", "Dialect"], _[__String]]
    },
    {True, True},
    {ArrayIndexPattern::noprop, ArrayIndexPattern::propx},
    TestID -> "indexnotation-refuses-an-unsupported-property-lookup"
]

(* An option setting the compilation has no reading for is refused where it is
   read, so no pattern object ever carries one. *)
VerificationTest[
    {
        MatchQ[ArrayIndexPattern["ij->i", "Targeting" -> "Yes"], _ArrayIndexPattern],
        MatchQ[ArrayIndexPattern["ij", "DefaultOutput" -> "Bogus"], _ArrayIndexPattern]
    },
    {True, True},
    {ArrayIndexPlan::option, ArrayIndexPlan::option},
    TestID -> "indexnotation-refuses-an-unreadable-option-setting"
]

EndTestSection[]
