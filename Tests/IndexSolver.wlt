(* Tests for the index-notation size solver and planner: the two solving stages
   (atomic axes unified against operand dimensions and checked against literals,
   then CircleTimes composites resolved to a fixed point), the sizes that arrive
   from outside the operands (inline Annotation and Labeled, out-of-band binding
   rules and the grammar of a binding key), ArrayIndexPlan solved against
   dimension lists with no arrays at all, and the effect classification and
   "Targeting" policy the plan is emitted from.
   Run via Tests/RunTests.wls or TestReport. *)

Needs["Wolfram`Arrays`"]

(* === fixtures === *)

$m23 = ArrayReshape[Range[6], {2, 3}]
$m34 = ArrayReshape[Range[12], {3, 4}]
$a22 = {{1, 2}, {3, 4}}
$b22 = {{5, 6}, {7, 8}}

(* Two descriptors in the expression dialect, where inline sizes and blank axes
   are spelled.  RuleDelayed holds the output side, so these are the descriptors
   as written and not their values. *)
$inlineSize = {{"b", CircleTimes[Annotation["h", 3], "c"]}} :> {{"b", "h", "c"}}
$inlineLabel = {{"b", CircleTimes[Labeled[3, "h"], "c"]}} :> {{"b", "h", "c"}}
$diagonal = {{aa_, aa_}} :> {{aa}}
$bare = {{sI, sJ}, {sJ, sK}} :> {{sI, sK}}

(* An effect record carries the axis it classifies as an internal identity, so a
   test reads the classification and leaves the identities to the descriptor. *)
solverEffects[object_] := Map[Function[record, record["Effect"]], object["Effects"]]

(* A step carries the register it writes and the frame it writes it in beside
   its own fields; a test that is about what the step DOES takes the fields it
   is about. *)
solverStep[plan_, k_Integer, keys_List] := plan["Steps"][[k, keys]]

(* Every refusal is a message plus the call left as written, so a refused call
   is asserted by its head and its message.  Where the point of a refusal is
   that it NAMES something - both sizes of a conflict, both factors of a
   composite that cannot be resolved, the axes a target does and does not mark -
   the expected message carries its arguments too, since the message name alone
   would pass on a diagnostic that named the wrong axis. *)


BeginTestSection["indexsolver"]

(* === stage 1: atomic axes against operand dimensions === *)

(* One axis takes one size across the whole descriptor: j is unified from the
   second dimension of the first operand and the first of the second, and the
   output dimensions follow from the sizes rather than from any operand. *)
VerificationTest[
    With[{plan = ArrayIndexPlan["ij,jk->ik", {{2, 3}, {3, 4}}]},
        {plan["AxisSizes"], plan["OutputDimensions"], plan["InputDimensions"]}
    ],
    {<|"i" -> 2, "j" -> 3, "k" -> 4|>, {2, 4}, {{2, 3}, {3, 4}}},
    TestID -> "indexsolver-unify-shared-axis"
]

(* An axis on three operands is one axis and unifies across all three, which is
   the hyperedge a pairwise contractor cannot express. *)
VerificationTest[
    ArrayIndexPlan["i,i,i->i", {{3}, {3}, {3}}]["OutputDimensions"],
    {3},
    TestID -> "indexsolver-unify-across-three-operands"
]

(* The refusal names BOTH sizes, because either one of them may be the mistake. *)
VerificationTest[
    MatchQ[ArrayIndexPlan["ij,jk->ik", {{2, 3}, {5, 4}}], _ArrayIndexPlan],
    True,
    {HoldForm[Message[MessageName[ArrayIndexPlan, "conflict"], "j", 3, 5]]},
    TestID -> "indexsolver-conflict-names-both-sizes"
]

VerificationTest[
    MatchQ[ArrayIndexPlan["i,i,i->i", {{3}, {4}, {3}}], _ArrayIndexPlan],
    True,
    {HoldForm[Message[MessageName[ArrayIndexPlan, "conflict"], "i", 3, 4]]},
    TestID -> "indexsolver-conflict-across-three-operands"
]

(* A literal axis carries its own size, so the operand is what disagrees with it
   and the refusal is the literal one rather than the conflict one.  A literal
   the output does not carry is summed, and one the output writes is repeated
   into place, which is why 3 appears in both shapes and in neither operand
   twice. *)
VerificationTest[
    ArrayIndexPlan["b 3 c -> b c 3", {{2, 3, 4}}]["OutputDimensions"],
    {2, 4, 3},
    TestID -> "indexsolver-literal-axis-checked-against-the-dimension"
]

VerificationTest[
    MatchQ[ArrayIndexPlan["b 3 c -> b c 3", {{2, 5, 4}}], _ArrayIndexPlan],
    True,
    {HoldForm[Message[MessageName[ArrayIndexPlan, "literal"], "3", 1, 5]]},
    TestID -> "indexsolver-literal-axis-mismatch"
]

(* A unit axis is a literal that the lift squeezes rather than sums, so it is
   checked the same way and leaves no slot in the frame. *)
VerificationTest[
    {ArrayIndexPlan["a 1 -> a", {{3, 1}}]["OutputDimensions"], solverEffects[ArrayIndexPattern["a 1 -> a"]]},
    {{3}, {"Carried", "UnitAxis"}},
    TestID -> "indexsolver-unit-axis-squeezed"
]

VerificationTest[
    MatchQ[ArrayIndexPlan["a 1 -> a", {{3, 2}}], _ArrayIndexPlan],
    True,
    {HoldForm[Message[MessageName[ArrayIndexPlan, "literal"], "1", 1, 2]]},
    TestID -> "indexsolver-unit-axis-mismatch"
]

(* One axis term stands for one dimension, a composite included, so a rank that
   does not match the term count is refused rather than zipped short. *)
VerificationTest[
    MatchQ[ArrayIndexPlan["ij->ji", {ArrayReshape[Range[8], {2, 2, 2}]}], _ArrayIndexPlan],
    True,
    {HoldForm[Message[MessageName[ArrayIndexPlan, "rank"], 1, 2, 3]]},
    TestID -> "indexsolver-rank-mismatch"
]

(* A dimension is checked to be a positive integer before it takes part in
   anything: Mod[n, 3] =!= 0 is True for a symbolic n, so every divisibility and
   equality test downstream would report a mismatch that is not there. *)
VerificationTest[
    MatchQ[ArrayIndexPlan["ij->ji", {ArraySymbol["A", {2, solverN}]}], _ArrayIndexPlan],
    True,
    {HoldForm[Message[MessageName[ArrayIndexPlan, "dimension"], solverN, 1]]},
    TestID -> "indexsolver-non-integer-dimension"
]

VerificationTest[
    MatchQ[ArrayIndexPlan["ij,jk->ik", {{2, 3}}], _ArrayIndexPlan],
    True,
    {HoldForm[Message[MessageName[ArrayIndexPlan, "operands"], 1, 2]]},
    TestID -> "indexsolver-operand-count"
]

(* === stage 2: composites to a fixed point === *)

(* A composite resolves when exactly one factor occurrence is unknown: h comes
   from the binding, so c divides out of 12, and the split is one reshape. *)
VerificationTest[
    With[{plan = ArrayIndexPlan["b (h c) -> b h c", {{2, 12}}, {"h" -> 3}]},
        {plan["AxisSizes"], plan["OutputDimensions"], plan["Steps"]}
    ],
    {
        <|"b" -> 2, "h" -> 3, "c" -> 4|>,
        {2, 3, 4},
        {<|"Step" -> "Reshape", "Inputs" -> {1}, "Output" -> 2, "Frame" -> {1, 2, 3}, "Dimensions" -> {2, 3, 4}|>}
    },
    TestID -> "indexsolver-composite-divides-out-one-unknown"
]

(* The known factors must DIVIDE the dimension; 3 does not divide 13, and the
   refusal names the product of the known factors against the dimension rather
   than a quotient that is not an extent. *)
VerificationTest[
    MatchQ[ArrayIndexPlan["b (h c) -> b h c", {{2, 13}}, {"h" -> 3}], _ArrayIndexPlan],
    True,
    {HoldForm[Message[MessageName[ArrayIndexPlan, "composite"], 1, 3, 13]]},
    TestID -> "indexsolver-composite-divisibility-failure"
]

(* A literal factor is known before any operand is read, so (2 c) against 6
   resolves c on its own.  Counting distinct unknown axes instead of unknown
   occurrences would refuse this. *)
VerificationTest[
    ArrayIndexPlan["(2 c) -> 2 c", {{6}}]["OutputDimensions"],
    {2, 3},
    TestID -> "indexsolver-composite-with-a-literal-factor"
]

(* The fixed point is what makes the order the composites were written in
   irrelevant: (b c) resolves nothing on the first sweep, (a b) then gives b
   from the binding for a, and the second sweep divides c out of 12. *)
VerificationTest[
    With[{plan = ArrayIndexPlan["(b c), (a b) -> c", {{12}, {6}}, {"a" -> 2}]},
        {plan["AxisSizes"], plan["OutputDimensions"]}
    ],
    {<|"b" -> 3, "c" -> 4, "a" -> 2|>, {4}},
    TestID -> "indexsolver-composite-fixed-point-across-operands"
]

(* Every composite is revalidated once the sweeps end, so factors resolved on
   one operand are checked against every other dimension they stand for: a and b
   are 2 and 4 from the second operand and their product is not the 6 of the
   first. *)
VerificationTest[
    MatchQ[ArrayIndexPlan["(a b), a b ->", {{6}, {2, 4}}], _ArrayIndexPlan],
    True,
    {HoldForm[Message[MessageName[ArrayIndexPlan, "composite"], 1, 8, 6]]},
    TestID -> "indexsolver-composite-checked-across-operands"
]

(* Two unknown factors in one composite leave the system underdetermined, and
   the refusal names them together, since that is what has to be supplied
   together for the composite to resolve. *)
VerificationTest[
    MatchQ[ArrayIndexPlan["b (h c) -> b h c", {{2, 12}}], _ArrayIndexPlan],
    True,
    {HoldForm[Message[MessageName[ArrayIndexPlan, "unresolved"], "h, c"]]},
    TestID -> "indexsolver-composite-underdetermined-names-both-axes"
]

(* === sizes from outside the operands === *)

(* An axis on the output and on no input is a broadcast: it reaches no operand,
   so its size comes from a binding or from nowhere at all. *)
VerificationTest[
    MatchQ[ArrayIndexPlan["a -> a r", {{3}}], _ArrayIndexPlan],
    True,
    {HoldForm[Message[MessageName[ArrayIndexPlan, "unresolved"], "r"]]},
    TestID -> "indexsolver-broadcast-axis-needs-a-binding"
]

VerificationTest[
    With[{plan = ArrayIndexPlan["a -> a r", {{3}}, {"r" -> 4}]},
        {plan["OutputDimensions"], solverStep[plan, 1, {"Step", "Sizes", "Dimensions"}]}
    ],
    {{3, 4}, <|"Step" -> "Broadcast", "Sizes" -> {4}, "Dimensions" -> {3, 4}|>},
    TestID -> "indexsolver-broadcast-axis-sized-by-a-binding"
]

(* Equal facts coalesce: the same axis given the same size twice is one fact,
   not a re-declaration. *)
VerificationTest[
    ArrayIndexPlan["a -> a r", {{3}}, {"r" -> 4, "r" -> 4}]["OutputDimensions"],
    {3, 4},
    TestID -> "indexsolver-equal-binding-facts-coalesce"
]

(* Conflicting facts fail whichever order they were written in: the facts are
   grouped by axis before any of them is merged, so neither rule is the one that
   arrived first. *)
VerificationTest[
    {
        MatchQ[ArrayIndexPlan["a -> a r", {{3}}, {"r" -> 4, "r" -> 5}], _ArrayIndexPlan],
        MatchQ[ArrayIndexPlan["a -> a r", {{3}}, {"r" -> 5, "r" -> 4}], _ArrayIndexPlan]
    },
    {True, True},
    {ArrayIndexPlan::conflict, ArrayIndexPlan::conflict},
    TestID -> "indexsolver-conflicting-binding-facts-fail-either-order"
]

(* An inline size is the same kind of fact as an out-of-band rule, so one that
   agrees coalesces with it and one that disagrees is the same conflict. *)
VerificationTest[
    {
        ArrayIndexPlan[$inlineSize, {{2, 12}}]["OutputDimensions"],
        ArrayIndexPlan[$inlineSize, {{2, 12}}, {"h" -> 3}]["OutputDimensions"],
        ArrayIndexPlan[$inlineLabel, {{2, 12}}]["OutputDimensions"]
    },
    {{2, 3, 4}, {2, 3, 4}, {2, 3, 4}},
    TestID -> "indexsolver-inline-size-agrees-with-a-binding"
]

VerificationTest[
    MatchQ[ArrayIndexPlan[$inlineSize, {{2, 12}}, {"h" -> 4}], _ArrayIndexPlan],
    True,
    {HoldForm[Message[MessageName[ArrayIndexPlan, "conflict"], "h", 3, 4]]},
    TestID -> "indexsolver-inline-size-conflicts-with-a-binding"
]

(* A binding on an axis the operands also size is admitted and coalesces with
   the dimension, and one that disagrees with the dimension is the same refusal
   an operand pair would raise. *)
VerificationTest[
    ArrayIndexPlan[$bare, {{2, 3}, {3, 4}}, {sJ -> 3}]["AxisSizes"],
    <|"sI" -> 2, "sJ" -> 3, "sK" -> 4|>,
    TestID -> "indexsolver-binding-agrees-with-the-dimension"
]

VerificationTest[
    MatchQ[ArrayIndexPlan[$bare, {{2, 3}, {3, 4}}, {sJ -> 5}], _ArrayIndexPlan],
    True,
    {HoldForm[Message[MessageName[ArrayIndexPlan, "conflict"], "sJ", 5, 3]]},
    TestID -> "indexsolver-binding-conflicts-with-the-dimension"
]

(* A blank axis is inference-only and takes its size from the operand, so a
   Pattern key is refused by name rather than accepted as a no-op. *)
VerificationTest[
    MatchQ[ArrayIndexPlan[{{a_, b_}} :> {{b, a}}, {{2, 3}}, {a_ -> 3}], _ArrayIndexPlan],
    True,
    {ArrayIndexPattern::patternkey},
    TestID -> "indexsolver-pattern-binding-key-rejected"
]

(* A key that names no axis of the descriptor, and a value that is not a
   positive extent, are refusals of the same grammar: the call is declined
   rather than compiled with the binding dropped, since a dropped binding is an
   axis silently solved from somewhere else. *)
VerificationTest[
    {
        MatchQ[ArrayIndexPattern["ij,jk->ik", {"z" -> 3}], _ArrayIndexPattern],
        MatchQ[ArrayIndexPattern[$bare, {sZ -> 3}], _ArrayIndexPattern]
    },
    {True, True},
    {ArrayIndexPattern::bindingkey, ArrayIndexPattern::bindingkey},
    TestID -> "indexsolver-unknown-binding-key-rejected"
]

VerificationTest[
    {
        MatchQ[ArrayIndexPattern["i j -> j i", {"i" -> 0}], _ArrayIndexPattern],
        MatchQ[ArrayIndexPattern["i j -> j i", {"i" -> 2.5}], _ArrayIndexPattern]
    },
    {True, True},
    {ArrayIndexPattern::bindingkey, ArrayIndexPattern::bindingkey},
    TestID -> "indexsolver-binding-value-must-be-a-positive-integer"
]

(* === planning against dimensions, with no arrays === *)

(* Shape inference with no data: the plan solved from dimension lists is the
   plan solved from the arrays of those dimensions, step for step. *)
VerificationTest[
    With[
        {
            fromDimensions = ArrayIndexPlan["ij,jk->ik", {{2, 3}, {3, 4}}],
            fromArrays = ArrayIndexPlan["ij,jk->ik", {$m23, $m34}]
        },
        {
            fromDimensions["InputDimensions"] === fromArrays["InputDimensions"],
            fromDimensions["OutputDimensions"] === fromArrays["OutputDimensions"],
            fromDimensions["Steps"] === fromArrays["Steps"]
        }
    ],
    {True, True, True},
    TestID -> "indexsolver-dimensions-plan-matches-the-array-plan"
]

(* The second argument reads as dimension lists when every element is a list of
   positive integers as long as the input shape it stands for names terms, and
   as arrays otherwise.  {{2}, {3}} read as arrays would make both axes 1, and
   the length-2 and length-3 vectors have no reading as one-term shapes, so each
   list settles under exactly one of the two readings. *)
VerificationTest[
    {
        ArrayIndexPlan["i,j->ij", {{2}, {3}}]["OutputDimensions"],
        ArrayIndexPlan["i,j->ij", {{9, 9}, {9, 9, 9}}]["OutputDimensions"]
    },
    {{2, 3}, {2, 3}},
    TestID -> "indexsolver-dimension-lists-and-arrays-are-told-apart"
]

(* A step is emitted only when it is not the identity, so a descriptor that asks
   for nothing plans nothing, a pure rearrangement is one transpose, and a
   contraction is one contract over the concatenated frames: i j j k, whose
   second and third slots carry the axis the output drops. *)
VerificationTest[
    {
        ArrayIndexPlan["ij->ij", {{2, 3}}]["Steps"],
        solverStep[ArrayIndexPlan["ij->ji", {{2, 3}}], 1, {"Step", "Permutation", "Dimensions"}],
        solverStep[ArrayIndexPlan["ij,jk->ik", {{2, 3}, {3, 4}}], 1, {"Step", "Inputs", "Groups", "Dimensions"}]
    },
    {
        {},
        <|"Step" -> "Transpose", "Permutation" -> {2, 1}, "Dimensions" -> {3, 2}|>,
        <|"Step" -> "Contract", "Inputs" -> {1, 2}, "Groups" -> {{2, 3}}, "Dimensions" -> {2, 4}|>
    },
    TestID -> "indexsolver-steps-of-the-three-shapes-of-plan"
]

(* The output dimensions the plan reports with no data are the dimensions the
   executed contraction has. *)
VerificationTest[
    With[{plan = ArrayIndexPlan["ij,jk->ik", {{2, 3}, {3, 4}}]},
        {plan["OutputDimensions"], Dimensions[ArrayIndexContract[plan, {$m23, $m34}]]}
    ],
    {{2, 4}, {2, 4}},
    TestID -> "indexsolver-output-dimensions-are-the-computed-dimensions"
]

(* Axis identities are internal and allocated in first-occurrence order, so
   every property that names an axis reports the display name the descriptor
   used, in that order. *)
VerificationTest[
    With[{plan = ArrayIndexPlan["b (h c) -> b h c", {{2, 12}}, {"h" -> 3}]},
        {plan["AxisSizes"], plan["Pattern"]["Axes"]}
    ],
    {<|"b" -> 2, "h" -> 3, "c" -> 4|>, {"b", "h", "c"}},
    TestID -> "indexsolver-axes-reported-by-display-name"
]

(* === effect classification === *)

(* One axis, one effect.  An axis on input and output is carried, one the output
   drops is summed over every slot that carries it, one repeated within an
   operand is a trace, one on the output and no input is repeated into place,
   and a unit axis is reshape alone. *)
VerificationTest[
    {
        solverEffects[ArrayIndexPattern["ij,jk->ik"]],
        solverEffects[ArrayIndexPattern["i i ->"]],
        solverEffects[ArrayIndexPattern["a -> a r"]],
        solverEffects[ArrayIndexPattern["a 3 -> a"]]
    },
    {
        {"Carried", "Contracted", "Carried"},
        {"SelfContracted"},
        {"Carried", "Broadcast"},
        {"Carried", "Contracted"}
    },
    TestID -> "indexsolver-effect-of-each-class"
]

(* A trace is taken before anything else touches the operand, so the pair of
   slots it sums is one contraction group over one operand. *)
VerificationTest[
    solverStep[ArrayIndexPlan["i i ->", {{3, 3}}], 1, {"Step", "Inputs", "Groups", "Dimensions"}],
    <|"Step" -> "Contract", "Inputs" -> {1}, "Groups" -> {{1, 2}}, "Dimensions" -> {}|>,
    TestID -> "indexsolver-trace-is-one-group-on-one-operand"
]

(* The occurrence policy belongs to the analysis and not to the parse: the
   descriptor's grammar is accepted and its one axis is reported, and the
   diagonal it would name is refused where the effects are asked for. *)
VerificationTest[
    {
        ArrayIndexPattern[$diagonal]["Axes"],
        MatchQ[ArrayIndexPattern[$diagonal]["Effects"], HoldPattern[ArrayIndexPattern[_]["Effects"]]]
    },
    {{"aa"}, True},
    {ArrayIndexPlan::diagonal},
    TestID -> "indexsolver-diagonal-declined-by-the-analysis"
]

(* Three occurrences in one operand is a generalized diagonal, and two in one
   operand with another elsewhere mixes a trace with a contraction; the pairwise
   trace expresses neither. *)
VerificationTest[
    {
        MatchQ[ArrayIndexPattern["i i i ->"]["Effects"], HoldPattern[ArrayIndexPattern[_]["Effects"]]],
        MatchQ[ArrayIndexPattern["i i, i k -> k"]["Effects"], HoldPattern[ArrayIndexPattern[_]["Effects"]]]
    },
    {True, True},
    {
        HoldForm[Message[MessageName[ArrayIndexPlan, "occurrences"], "i", 3]],
        HoldForm[Message[MessageName[ArrayIndexPlan, "occurrences"], "i", 3]]
    },
    TestID -> "indexsolver-too-many-occurrences-declined"
]

(* === targeting === *)

(* With Automatic the check runs only once the descriptor has spelled a target
   at all, which is what lets an untargeted einsum descriptor contract by
   repeated name; a target then marks the contracted axis, on however many
   operands it occurs. *)
VerificationTest[
    {
        ArrayIndexPattern["ij,jk->ik"]["Targets"],
        ArrayIndexPattern["i [j], j k -> i k"]["Targets"],
        ArrayIndexPattern["i [j], [j] k -> i k"]["Targets"]
    },
    {{}, {"j"}, {"j"}},
    TestID -> "indexsolver-automatic-targets-the-contracted-axis"
]

(* A target on an axis the output keeps marks no contraction, and the refusal
   names the axes it does mark against the axes it should have. *)
VerificationTest[
    MatchQ[ArrayIndexPattern["[i] j, j k -> i k"]["Targets"], HoldPattern[ArrayIndexPattern[_]["Targets"]]],
    True,
    {HoldForm[Message[MessageName[ArrayIndexPlan, "target"], {"i"}, {"j"}]]},
    TestID -> "indexsolver-automatic-target-on-a-carried-axis"
]

(* With True the check always runs, so a contracted axis carrying no target is a
   refusal naming an empty set of marked axes. *)
VerificationTest[
    {
        MatchQ[ArrayIndexPattern["ij,jk->ik", {}, "Targeting" -> True]["Targets"], HoldPattern[ArrayIndexPattern[_]["Targets"]]],
        ArrayIndexPattern["i [j], j k -> i k", {}, "Targeting" -> True]["Targets"]
    },
    {True, {"j"}},
    {HoldForm[Message[MessageName[ArrayIndexPlan, "target"], {}, {"j"}]]},
    TestID -> "indexsolver-true-requires-a-target-on-every-contracted-axis"
]

(* With False the target wrappers are ignored and a repeated name alone
   contracts, which is classic einsum recovered exactly: the bracketed
   descriptor computes the matrix product the unbracketed one does.
   {{1,2},{3,4}} . {{5,6},{7,8}} is {{19,22},{43,50}}. *)
VerificationTest[
    {
        ArrayIndexPattern["i [j], j k -> i k", {}, "Targeting" -> False]["Targets"],
        solverEffects[ArrayIndexPattern["i [j], j k -> i k", {}, "Targeting" -> False]],
        ArrayIndexContract["i [j], j k -> i k", {$a22, $b22}, {}, "Targeting" -> False],
        ArrayIndexContract["ij,jk->ik", {$a22, $b22}]
    },
    {{}, {"Carried", "Contracted", "Carried"}, {{19, 22}, {43, 50}}, {{19, 22}, {43, 50}}},
    TestID -> "indexsolver-false-recovers-contraction-by-repeated-name"
]

(* The setting is checked where it is read, so an object never carries a value
   the analysis would refuse. *)
VerificationTest[
    MatchQ[ArrayIndexPattern["ij,jk->ik", {}, "Targeting" -> "Sure"], _ArrayIndexPattern],
    True,
    {HoldForm[Message[MessageName[ArrayIndexPlan, "option"], "Sure", "Targeting"]]},
    TestID -> "indexsolver-targeting-takes-three-settings"
]

EndTestSection[]
