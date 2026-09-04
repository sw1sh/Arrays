Package["Wolfram`Arrays`"]

PackageExport[ArrayIndexPattern]
PackageExport[ArrayIndexPlan]
PackageExport[ArrayIndexTransform]
PackageExport[ArrayIndexContract]


(* The public face of the index layer: two inert self-describing objects and two
   executors.  Everything that reads a descriptor, interns an axis, solves a
   size, orders a frame or emits a step lives in IndexNotation.wl,
   IndexSolver.wl, IndexPlan.wl and IndexExecute.wl; this file owns the argument
   patterns, the options, every message template of the four symbols, and the
   boundary at which a refusal becomes a message plus an unevaluated call.

   The four heads are matched in a left-hand side ONLY here.  Every other kernel
   file passes and returns plain Associations, so no compilation stage has to
   know what an object looks like, and an object is exactly one of those
   Associations under one of these heads. *)


ArrayIndexPattern::usage = "ArrayIndexPattern[desc] parses an index descriptor into a normalized pattern object, formatted as a summary box that shows its axes and its operand ranks; desc is a string in the einx or the classic einsum dialect, a list of input shapes given as a RuleDelayed to a list of output shapes, or a bare shape standing for a one-operand descriptor. A string containing a space is tokenized by identifier and one with no space by character, so \"ij,jk->ik\" and \"i j, j k -> i k\" name the same three axes and \"b s d, d e -> b s e\" keeps multi-character names. RuleDelayed holds the output shapes, so a bare output symbol names an axis rather than its global value; Rule evaluates both sides before the descriptor is read and is accepted with a message saying so, which is the spelling classic einsum call sites use. Every axis is interned to an operation-local integer identity carrying its display name, spelling kind and Wolfram context: a blank a_ binds one logical axis across the whole descriptor, a bare a on the input side is an ambient expression that is never localized by a blank of the same name, a bare a on the output side references such a blank where one exists, a string \"a\" and a targeted #a are hygienic, a Wolfram context never distinguishes two established axes of one name, and one name spelled two ways is declined.\nArrayIndexPattern[desc, bindings] takes axis sizes out of band as a list of rules keyed by a string, by a bare symbol, or by the target head the descriptor used; a Pattern key is declined, since a blank axis takes its size from the operand.\nArrayIndexPattern[desc][\"prop\"] gives a property and ArrayIndexPattern[desc][\"Properties\"] the list of supported properties. A descriptor the grammar does not accept, and one naming a construct outside the compiled vocabulary - a CirclePlus direct sum, an ellipsis, a named sequence, a targeted literal, more than one output shape, or an axis repeated within one output shape - is declined with a message naming the fragment and the call is left unevaluated. \"Targeting\" and \"DefaultOutput\" are resolved here and travel with the object, so giving one where the descriptor position already holds a prepared ArrayIndexPattern or ArrayIndexPlan is declined, as is a binding list given there - the sizes it names belong to the call that built the object - and as is an option name ArrayIndexPattern does not declare."

ArrayIndexPlan::usage = "ArrayIndexPlan[desc, dims] solves the axis sizes of an index descriptor against a list of operand dimension lists and gives an execution plan object, formatted as a summary box that shows the operand and output dimensions; sizes come from unifying every atomic axis against its operand dimension and then resolving each CircleTimes composite whose factors are all known but one, iterated to a fixed point, so a plan needs no data at all.\nArrayIndexPlan[desc, arrays] reads the dimensions with ArrayDimensions, treating anything that is not a container as a rank-0 operand; a list of positive-integer vectors whose lengths match the input shapes is read as dimensions rather than as arrays.\nArrayIndexPlan[pattern, dimsOrArrays] reuses a parsed ArrayIndexPattern, which is the compile-once path a contraction over many shapes wants.\nThe plan is an ordered list of steps over a single-assignment register file: a reshape that splits composites and squeezes unit axes, a transpose, a broadcast that appends an axis of a given extent as a tensor product with a vector of ones, an elementwise multiply that merges the operands sharing an axis the output carries, and a contraction of the inactive tensor product of its operands over given slot groups, where a one-slot group sums that slot and an n-slot group is the generalized trace a hyperedge lowers to. ArrayIndexPlan[...][\"Expression\"] gives that plan held, with operand k spelled #k, and it is the same expression the executors release, so the trace is what runs. A size conflict, an axis with no size, an operand whose rank does not match its shape, a composite whose known factors do not divide its dimension, and a dimension that is not a positive integer are each declined with a message naming the axis and both sizes, and the call is left unevaluated. \"Targeting\" and \"DefaultOutput\" are read where a descriptor is compiled, so a prepared ArrayIndexPattern or ArrayIndexPlan in the descriptor position carries the settings its own construction resolved and is declined either of them, and a binding list given with one is declined for the same reason, as is an option name ArrayIndexPlan does not declare."

ArrayIndexTransform::usage = "ArrayIndexTransform[desc, array] rearranges one array container according to an index descriptor: a CircleTimes composite on the input side splits its dimension into its factors with the leftmost factor outermost, a composite on the output side merges them again, a literal 1 is squeezed on the input side and inserted on the output side, and an axis present only on the output side is repeated to the size a binding or an inline Annotation gives it. With no output shape given the descriptor is shape-preserving. The steps are one reshape that splits composites and squeezes unit axes, one broadcast for the repeated axes, one transpose into the output order and one reshape that merges composites and inserts unit axes, each emitted only where it is not the identity, so a pure permutation is a single ArrayTranspose and a pure split is a single ReshapeArray.\nArrayIndexTransform[plan, array] executes a prepared ArrayIndexPlan.\nAn axis on the input and absent from the output would be summed rather than moved, so it is declined with a message naming the axis and ArrayIndexContract; the same holds for an axis repeated within one operand and for an anonymous axis, whatever its extent: the admission is decided before sizes are solved, and the squeezed spelling of a unit axis is the literal 1. A descriptor with more than one input shape or more than one output shape is declined, as is an operand that does not join to the explicit tier. The steps keep the container they are handed: a SparseArray and a packed array come back as themselves, and a QuantityArray comes back a QuantityArray in its own unit, the steps running on its magnitudes and the unit going back on the result; a NumericArray, a TabularColumn, a Tabular, a Dataset, an EventSeries and a ByteArray are materialized first and come back as plain arrays. \"Targeting\" and \"DefaultOutput\" are read where a descriptor is compiled, so a prepared ArrayIndexPattern or ArrayIndexPlan carries the settings its own construction resolved and is declined either of them, and a binding list given with one is declined for the same reason; an option name ArrayIndexTransform does not declare is declined."

ArrayIndexContract::usage = "ArrayIndexContract[desc, arrays] contracts the given array containers according to an index descriptor: an axis on the output is carried, an axis absent from the output is summed over every slot carrying it - one slot for a single occurrence, two for an ordinary contraction, three and more for an index shared by three operands - and an axis repeated within one operand and absent from the output is a trace. With no output shape given, the output is the axes occurring exactly once, in first-occurrence order rather than sorted. Operands sharing an axis the output carries are aligned to a common frame and multiplied elementwise before the contraction, which is what makes a batch matrix product, a Hadamard product and a column scaling ordinary descriptors. The contraction is lowered to an inactive TensorContract over the inactive tensor product of the operands and materialized, so a SparseArray and a packed array keep their container, and a rank-0 operand is kept out of the product and multiplied back in. A QuantityArray keeps its container whatever steps the descriptor emits: with the sum-of-products combiner every step is linear in its operands, so the unit is lifted off them, the steps run on the magnitudes and the product of the units goes back on the result, which is an ordinary Quantity where the result is rank 0 and an unwrapped array where the units cancel; a QuantityArray carrying a unit per column has no single unit to lift, and its elements carry their own units instead. A NumericArray, a TabularColumn, a Tabular, a Dataset, an EventSeries and a ByteArray have no container to rebuild and are materialized first: TensorProduct has no evaluation on those heads, and a TabularColumn is rank 1 by construction, so no step that raises the rank has one to give back.\nArrayIndexContract[plan, arrays] executes a prepared ArrayIndexPlan.\nAn axis repeated within one operand and kept on the output, an axis occurring three or more times in one operand, an axis repeated within one operand that also occurs on another, and an axis repeated within one output shape are each declined with a message naming the axis. An operand set that does not join to the explicit tier is declined, and ArrayMaterialize brings a lazy or symbolic operand to one. \"Targeting\" and \"DefaultOutput\" are read where a descriptor is compiled, so a prepared ArrayIndexPattern or ArrayIndexPlan carries the settings its own construction resolved and is declined either of them, and a binding list given with one is declined for the same reason, while \"Combiner\" is read at execution and is taken with a prepared object as with a descriptor; an option name ArrayIndexContract does not declare is declined."


(* Grammar, hygiene and binding keys refuse on ArrayIndexPattern, whatever entry
   point was called: the tag names the compilation stage the fix belongs to, so
   there is one declaration per refusal rather than one per refusal per
   entrance.  ArrayIndexPattern::rule is the one message that is not a refusal -
   the descriptor compiles and the result is returned - because a Rule
   descriptor is how classic einsum call sites are written. *)

ArrayIndexPattern::parse = "`1` is not an index descriptor: a descriptor is a string in the einx or classic einsum dialect, or a list of input shapes given as a Rule or RuleDelayed to a list of output shapes."

ArrayIndexPattern::token = "`1` in the descriptor string `2` is not an index token: a string with no space is read character by character and admits letters, \"_\", \",\" and \"->\", and a string with a space is read by identifier and adds digits, \"(\", \")\", \"[\" and \"]\"."

ArrayIndexPattern::term = "`1` is not an axis term: an axis term is a blank a_, a bare symbol, a string naming an identifier, a positive integer, an anonymous _, or a CircleTimes of those, each optionally under one Slot, Highlighted or Framed, and Slot targets a string axis."

ArrayIndexPattern::unsupported = "the descriptor names `1`, which is outside the compiled vocabulary: an index descriptor is built from named axes, literal sizes, anonymous axes and CircleTimes products, and gives one list of output shapes."

ArrayIndexPattern::mishmash = "the axis `1` is spelled both as a symbol and as the string \"`1`\": one name takes one spelling, since a blank and a string carry different hygiene."

ArrayIndexPattern::duplicate = "the axis `1` occurs more than once in one output shape: a repeated output axis names no layout."

ArrayIndexPattern::outputs = "the descriptor gives `1` output shapes: one output shape is compiled."

ArrayIndexPattern::patternkey = "`1` is not a binding key: a blank axis takes its size from the operand, so spell the axis as a string or a bare symbol to give it a size out of band."

ArrayIndexPattern::bindingkey = "`1` is not a binding for an axis of this descriptor: a binding list is a list of rules whose values are positive integers, keyed by a string for a string axis, by a bare symbol for a bare axis, and by the target head the descriptor used for a targeted one."

ArrayIndexPattern::rule = "the descriptor `1` is written with Rule, which evaluates both of its sides before the descriptor is read: RuleDelayed holds the output shapes, so a bound output symbol names its axis rather than its value."

ArrayIndexPattern::ambient = "the bare output axis `1` has the value `2`, which is neither a positive integer nor an identifier string: a bare output axis with no binder of the same name reads its ambient value."

ArrayIndexPattern::noprop = "`1` is not a supported ArrayIndexPattern property; use \"Properties\" for the list of supported properties."

ArrayIndexPattern::malformed = "`1` is not a compiled index pattern: a property is read from the object ArrayIndexPattern gives for a descriptor the grammar accepts."

ArrayIndexPattern::propx = "ArrayIndexPattern property lookup called with `1` arguments; 1 property name is expected."

(* Size solving, occurrence policy and targeting refuse on ArrayIndexPlan, since
   a plan is where a descriptor meets shapes and where an effect classification
   becomes a step. *)

ArrayIndexPlan::operands = "`1` operands were given for a descriptor naming `2` input shapes."

ArrayIndexPlan::dimensions = "operand `1` has dimensions `2` where the plan was solved for `3`: a plan carries the dimensions its steps were emitted for, so a descriptor applied to other shapes is planned again rather than reused."

ArrayIndexPlan::rank = "input shape `1` names `2` axes and the operand there has rank `3`: one axis term stands for one dimension, and a CircleTimes composite stands for one."

ArrayIndexPlan::literal = "the literal axis `1` of input shape `2` does not match the dimension `3` there."

ArrayIndexPlan::conflict = "the axis `1` is given the size `2` and the size `3`: one axis takes one size across the whole descriptor."

ArrayIndexPlan::composite = "the composite of input shape `1` has known factors of product `2` against the dimension `3` there: a composite resolves when its known factors divide the dimension and it checks out when they multiply to it."

ArrayIndexPlan::unresolved = "the axis `1` has no size: it is on no operand, and no inline Annotation and no binding rule gives it one."

ArrayIndexPlan::dimension = "the dimension `1` of operand `2` is not a positive integer: an index plan solves over positive integer dimensions."

ArrayIndexPlan::occurrences = "the axis `1` occurs `2` times: an axis repeated within one operand is a trace and takes exactly two occurrences and none elsewhere, while an axis on several operands takes one occurrence in each."

ArrayIndexPlan::diagonal = "the axis `1` is repeated within one input shape and kept on the output: a repeated axis is a trace, and the diagonal this would otherwise name has no lowering here."

ArrayIndexPlan::target = "the targeted axes `1` are not the contracted axes `2`: with \"Targeting\" -> Automatic an explicit target marks a contracted axis exactly, with True every contracted axis carries one, and with False target wrappers are ignored."

ArrayIndexPlan::targetplace = "the targets on `1` mark no input occurrence: a target marks a contracted axis where an input shape carries it, so a target on the output side marks nothing."

ArrayIndexPlan::option = "`1` is not a setting for `2`: \"Targeting\" takes True, Automatic or False, and \"DefaultOutput\" takes \"Contracted\" or \"Identity\"."

ArrayIndexPlan::noprop = "`1` is not a supported ArrayIndexPlan property; use \"Properties\" for the list of supported properties."

ArrayIndexPlan::malformed = "`1` is not a compiled index plan: a property is read from the object ArrayIndexPlan gives for a descriptor whose axis sizes solve against the given dimensions."

ArrayIndexPlan::propx = "ArrayIndexPlan property lookup called with `1` arguments; 1 property name is expected."

(* An option a PREPARED object cannot honour refuses on that object's own head,
   which is the call that takes the setting: "Targeting" selects which
   occurrences count as targeted and "DefaultOutput" decides the output shape of
   a descriptor that writes none, so both are read where a descriptor is
   compiled and both are already resolved in the normalized descriptor an object
   carries.  Passing one to a call that reuses the object names a stage that has
   already run, and the compile-once path exists precisely so that stage does
   not run again. *)

ArrayIndexPattern::prepared = "the option `1` is given with a prepared ArrayIndexPattern, which carries the setting its own construction resolved: \"Targeting\" and \"DefaultOutput\" are read where a descriptor is compiled, so they belong to the ArrayIndexPattern call that built the object, while \"Combiner\" is read at execution and is taken here."

ArrayIndexPlan::prepared = "the option `1` is given with a prepared ArrayIndexPlan, which carries the setting its own construction resolved: \"Targeting\" and \"DefaultOutput\" are read where a descriptor is compiled, so they belong to the ArrayIndexPlan call that built the object, while \"Combiner\" is read at execution and is taken here."

(* A binding list refuses on the same head and for the same reason: a size given
   out of band becomes a known-size constraint of the NORMALIZED descriptor, so
   it is read where a descriptor is compiled and a prepared object carries the
   constraints its own construction resolved.  Taking one silently let the
   compile-once path drop the sizes the caller gave and then report the axis it
   dropped them for as unsized, which names the wrong stage twice over. *)

ArrayIndexPattern::bindings = "the binding list `1` is given with a prepared ArrayIndexPattern, which carries the sizes its own construction resolved: a binding is read where a descriptor is compiled, so it belongs to the ArrayIndexPattern call that built the object."

ArrayIndexPlan::bindings = "the binding list `1` is given with a prepared ArrayIndexPlan, which carries the sizes its own construction resolved: a binding is read where a descriptor is compiled, so it belongs to the ArrayIndexPattern or ArrayIndexPlan call that built the object."

(* An option NAME refuses on the symbol it was given to, since the option list
   being consulted is that symbol's own and they differ: "Combiner" is a setting
   of the contraction and of nothing else.  One declaration per entrance is one
   declaration per option list, which is the same reason ::tier is declared on
   each executor. *)

ArrayIndexPattern::optionname = "`1` is not an option of ArrayIndexPattern; the options are `2`."

ArrayIndexPlan::optionname = "`1` is not an option of ArrayIndexPlan; the options are `2`."

ArrayIndexContract::optionname = "`1` is not an option of ArrayIndexContract; the options are `2`."

ArrayIndexTransform::optionname = "`1` is not an option of ArrayIndexTransform; the options are `2`."

(* The two executors own only what they refuse at execution time. *)

ArrayIndexContract::tier = "the operand set joins to the `1` tier: an index contraction executes on explicit containers, and ArrayMaterialize brings a lazy or symbolic operand to one."

ArrayIndexContract::combiner = "`1` is not a combiner: the sum of products {Times, Plus} is the pairing an inactive TensorContract over an inactive tensor product expresses, and it is the one this lowers."

ArrayIndexTransform::tier = "the operand set joins to the `1` tier: an index rearrangement executes on explicit containers, and ArrayMaterialize brings a lazy or symbolic operand to one."

ArrayIndexTransform::effect = "the axis `1` is on the input and absent from the output, so it would be summed rather than moved: ArrayIndexContract contracts an axis and ArrayIndexTransform rearranges the ones it keeps."

ArrayIndexTransform::arity = "a rearrangement takes one input shape and one output shape; the descriptor gives `1` and `2`."

(* === options === *)

(* "DefaultOutput" is the resolution rule for a descriptor that writes no output
   shape, and it is the one option whose default differs by entrance: a
   rearrangement of an unwritten output preserves the input shape, while a
   contraction keeps the axes that occur exactly once.  "Combiner" is declared
   on the contraction alone, since nothing else pairs two operations. *)

Options[ArrayIndexPattern] = {"DefaultOutput" -> "Contracted", "Targeting" -> Automatic}

Options[ArrayIndexPlan] = {"DefaultOutput" -> "Contracted", "Targeting" -> Automatic}

Options[ArrayIndexContract] = {"Combiner" -> {Times, Plus}, "DefaultOutput" -> "Contracted", "Targeting" -> Automatic}

Options[ArrayIndexTransform] = {"DefaultOutput" -> "Identity", "Targeting" -> Automatic}


(* === the argument check every entrance runs first ===

   The option NAMES are checked before any setting is read.  OptionValue reports
   a name a symbol does not declare with the System message OptionValue::nodef,
   once for every setting the call goes on to read, and then hands back the
   default and computes: a misspelling printed three kernel messages and a
   General::stop and contracted anyway.  Checking the names first makes it one
   refusal in this paclet's own voice, with the call left as written.

   The compile-time settings are then checked against the SPEC.  Both objects
   bake their options in at construction, which is what lets indexPatternDataFor
   take one apart instead of recompiling it; the settings a later call passes
   have nothing left to act on, and accepting them silently made the compile-once
   path admit exactly what the raw path refuses.  "Combiner" is not among them:
   it is read at execution, for the refusal of any pairing other than the sum of
   products, and no stage of compilation looks at it, so a prepared object takes
   it.

   The spec is matched under HoldPattern for the reason every object clause in
   this file is: an assignment evaluates its left-hand side, and both object
   expressions have definitions of their own. *)

$indexCompiledOptions = {"DefaultOutput", "Targeting"}

indexCheckOptions[sym_, spec_, opts_] := (
    With[{names = Keys[Options[sym]]},
        With[{unknown = DeleteCases[Keys[opts], Alternatives @@ names]},
            If[ unknown =!= {},
                indexFail[sym, "optionname", {First[unknown], names}, <|"Options" -> unknown|>]
            ]
        ]
    ];

    indexCheckPrepared[spec, opts]
)

indexCheckPrepared[HoldPattern[ArrayIndexPattern[_ ? indexPatternDataQ]], opts_] :=
    indexRefusePrepared[ArrayIndexPattern, opts]

indexCheckPrepared[HoldPattern[ArrayIndexPlan[_ ? indexPlanQ]], opts_] :=
    indexRefusePrepared[ArrayIndexPlan, opts]

indexCheckPrepared[_, _] := Null

indexRefusePrepared[head_, opts_] := With[{given = Cases[Keys[opts], Alternatives @@ $indexCompiledOptions]},
    If[ given =!= {},
        indexFail[head, "prepared", {First[given]}, <|"Options" -> given|>]
    ]
]


(* The binding position is checked the same way and against the same two object
   heads.  It is a separate pass because it reads a different argument, and it
   runs after the option-name check, so a call that gets both wrong reports the
   name it does not declare first. *)

indexCheckBindings[HoldPattern[ArrayIndexPattern[_ ? indexPatternDataQ]], bindings_] :=
    indexRefusePreparedBindings[ArrayIndexPattern, bindings]

indexCheckBindings[HoldPattern[ArrayIndexPlan[_ ? indexPlanQ]], bindings_] :=
    indexRefusePreparedBindings[ArrayIndexPlan, bindings]

indexCheckBindings[_, _] := Null

indexRefusePreparedBindings[head_, bindings_] :=
    If[ bindings =!= {},
        indexFail[head, "bindings", {bindings}, <|"Bindings" -> bindings|>]
    ]


(* Both settings are checked where they are read rather than where they are
   used, so a pattern object never carries a value the analysis would refuse.
   indexOperationAnalysis keeps its own check on "Targeting", since it is
   reachable with a descriptor this file never saw. *)

indexOption[sym_, opts_, "Targeting"] := With[{value = OptionValue[sym, opts, "Targeting"]},
    If[ ! MatchQ[value, True | Automatic | False],
        indexFail[ArrayIndexPlan, "option", {value, "Targeting"}, <|"Source" -> HoldComplete[value]|>]
    ];

    value
]

indexOption[sym_, opts_, "DefaultOutput"] := With[{value = OptionValue[sym, opts, "DefaultOutput"]},
    If[ ! MatchQ[value, "Contracted" | "Identity"],
        indexFail[ArrayIndexPlan, "option", {value, "DefaultOutput"}, <|"Source" -> HoldComplete[value]|>]
    ];

    value
]

(* The sum of products is the combiner an inactive TensorContract over an
   inactive tensor product IS, so it is the one with a lowering; a general
   {mul, add} pair names a different node and is declined.  The setting is read
   for that refusal, which is why the caller drops the value it gives back. *)

indexOption[sym_, opts_, "Combiner"] := With[{value = OptionValue[sym, opts, "Combiner"]},
    If[ value =!= {Times, Plus},
        indexFail[ArrayIndexContract, "combiner", {value}, <|"Source" -> HoldComplete[value]|>]
    ];

    value
]


(* === compilation === *)

(* The pattern object carries the NORMALIZED DESCRIPTOR and the "Targeting"
   setting the parse was given, and nothing derived from them.  A pattern is the
   pipeline stopped at normalization: the grammar, the hygiene rules and the
   binding keys are what it decides, and the occurrence policy - a diagonal
   kept, three occurrences in one operand, a target on an axis that carries no
   contraction - is the operation analysis, which the executors and the
   "Effects" property run.  So {{a_, a_}} :> {{a}} parses to ONE axis and says
   so, and is refused where it is asked to lower.

   The setting travels with the descriptor because it selects which occurrences
   count as targeted, and the analysis cannot be rebuilt without it.  The
   alternative - storing the analysis itself - makes every occurrence-policy
   refusal a parse refusal and puts a plan-stage message on ArrayIndexPattern. *)

indexPatternDataQ[data_Association] :=
    KeyExistsQ[data, "Normalized"] && KeyExistsQ[data, "Targeting"] && indexNormalizedQ[data["Normalized"]]

indexPatternDataQ[_] := False


(* The two directions between an analysis and the pattern data it was built
   from.  Both are total on their own stage's Association, so a plan can hand
   back the pattern it came from and a pattern can be analyzed on demand. *)

indexPatternData[analysis_] := <|"Normalized" -> analysis["Normalized"], "Targeting" -> analysis["Targeting"]|>

indexPatternAnalysis[data_] := indexOperationAnalysis[data["Normalized"], data["Targeting"]]


(* An object in a descriptor position is taken apart instead of recompiled - a
   pattern gives its own data and a plan gives the data the analysis it was
   built from came from - which is the whole of the compile-once, apply-many
   path.  Both objects have their options baked in at construction, so opts is
   read only on the clause that actually parses something.  HoldPattern is
   load-time hygiene: an assignment evaluates its left-hand side, and both
   object expressions have definitions of their own. *)

indexPatternDataFor[HoldPattern[ArrayIndexPattern[data_ ? indexPatternDataQ]], _, _, _] := data

indexPatternDataFor[HoldPattern[ArrayIndexPlan[plan_ ? indexPlanQ]], _, _, _] := indexPatternData[plan["Analysis"]]

indexPatternDataFor[desc_, bindings_, opts_, sym_] := <|
    "Normalized" -> indexNormalizedDescriptor[
        indexSurfaceDescriptor[desc],
        bindings,
        indexOption[sym, opts, "DefaultOutput"]
    ],
    "Targeting" -> indexOption[sym, opts, "Targeting"]
|>


(* Every entrance reaches its analysis the same way: to pattern data first, then
   through the one analysis clause.  A prepared plan is the exception worth
   naming - it already carries the analysis it was built from, so re-deriving it
   would be work with a chance of disagreeing with the steps. *)

indexAnalysisFor[HoldPattern[ArrayIndexPlan[plan_ ? indexPlanQ]], _, _, _] := plan["Analysis"]

indexAnalysisFor[spec_, bindings_, opts_, sym_] := indexPatternAnalysis[indexPatternDataFor[spec, bindings, opts, sym]]


(* The solve-and-emit half, shared by ArrayIndexPlan and by both executors.  The
   operand count is checked here rather than left to the solver: with fewer
   shapes than input shapes the solver's per-operand pass would take a part that
   does not exist, and with more it would ignore the excess in silence. *)

indexSolvedPlan[analysis_, shapes_] := With[{inputs = analysis["Normalized"]["Inputs"]},
    If[ Length[shapes] =!= Length[inputs],
        indexFail[ArrayIndexPlan, "operands", {Length[shapes], Length[inputs]}, <|"Shapes" -> shapes|>]
    ];

    indexExecutionPlan[analysis, indexSolvedDescriptor[analysis["Normalized"], shapes]]
]


(* A prepared plan is executed as it stands: it was solved against dimensions
   once and carries them, so the executors skip parse and solve entirely. *)

indexPlanFor[HoldPattern[ArrayIndexPlan[plan_ ? indexPlanQ]], _, _] := plan

indexPlanFor[_, analysis_, operands_] := indexSolvedPlan[analysis, indexOperandDimensions /@ operands]


(* ArrayIndexPlan's second argument is a list of dimension lists when every
   element is a list of positive integers as long as the input shape it stands
   for names terms, and a list of arrays otherwise.  A list of positive-integer
   VECTORS that also reads as dimensions is read as dimensions; such operands go
   to ArrayIndexContract, where the argument is always arrays. *)

indexPlanShapes[analysis_, spec_] := With[{ranks = Length /@ analysis["Normalized"]["Inputs"]},
    If[ Length[spec] === Length[ranks] &&
            And @@ MapThread[MatchQ[#1, {___Integer ? Positive}] && Length[#1] === #2 &, {spec, ranks}],

        spec,
        indexOperandDimensions /@ spec
    ]
]


(* A contraction takes its operands as a list, so a List argument IS the operand
   list and anything else is the single operand it stands for.  A rearrangement
   takes exactly one operand, so the two readings of a List collide and the
   descriptor breaks the tie: a one-element list whose element has the rank the
   input shape names is the wrapped spelling, and everything else is the operand
   itself.  Every List type-checks under at most one of the two readings, so the
   tie is settled where it is decidable rather than by convention. *)

indexOperands[ArrayIndexContract, _, arrays_List] := arrays

indexOperands[ArrayIndexContract, _, array_] := {array}

indexOperands[ArrayIndexTransform, analysis_, arg_] :=
    If[ MatchQ[arg, {_}] && (Length /@ analysis["Normalized"]["Inputs"]) === {Length[indexOperandDimensions[First[arg]]]},
        arg,
        {arg}
    ]


(* The executors differ in the effects they admit and in how they read their
   operand argument, and in nothing else: one analysis, one plan, one release of
   the plan expression against the operands. *)

indexExecuted[sym_, spec_, arg_, bindings_, opts_] := Module[{analysis, operands},
    analysis = indexAdmitEffects[indexAnalysisFor[spec, bindings, opts, sym], sym];
    operands = indexOperands[sym, analysis, arg];

    indexExecutePlan[indexPlanFor[spec, analysis, operands], operands, sym]
]


indexPatternObject[spec_, bindings_, opts_] :=
    ArrayIndexPattern[indexPatternDataFor[spec, bindings, opts, ArrayIndexPattern]]

indexPlanObject[spec_, dimsOrArrays_, bindings_, opts_] := With[
    {analysis = indexAnalysisFor[spec, bindings, opts, ArrayIndexPlan]},

    ArrayIndexPlan[indexSolvedPlan[analysis, indexPlanShapes[analysis, dimsOrArrays]]]
]


(* === the boundary === *)

(* One scheme for every refusal: a message on the symbol whose tag names the
   compilation stage the fix belongs to, and the call left as written.  The
   paclet declares no Failure anywhere and reports a refusal with a message plus
   an untouched expression, as ArrayUnify, ArrayCoerce and ArrayObject do, and a
   descriptor that cannot compile is a refusal rather than a value.

   catchIndexFailure turns the internal throw into that message and gives
   $indexFailed, and Module[{result}, result /; cond] - ArrayCoerce's own shape -
   declines the definition once the message has been issued, so the call stays
   as written instead of half-building an object.  The throw travels on a tag
   private to IndexNotation.wl, so a Throw from a user-supplied expression
   propagates untouched.

   bindings is a List of rules and options are trailing BARE rules, spelled out
   rather than left to OptionsPattern[], so the two argument positions cannot
   collide.  OptionsPattern[] also matches a list of rules, and an optional
   argument backtracks: a binding list the normalizer refuses would be re-read
   as an option list and the call would succeed with the bindings dropped.
   Admitting only bare rules there makes the binding position the only reading
   of a List, so a refused binding list declines the call.  A binding list
   spelled with RuleDelayed is admitted here and classified by
   indexNormalizedDescriptor, which owns what a binding key may be. *)

ArrayIndexPattern[desc_, bindings : {(_Rule | _RuleDelayed) ...} : {}, opts : ((_Rule | _RuleDelayed) ...)] :=
    Module[{result},
        result /; (result = catchIndexFailure[
            indexCheckOptions[ArrayIndexPattern, desc, {opts}];
            indexCheckBindings[desc, bindings];
            indexPatternObject[desc, bindings, {opts}]
        ]) =!= $indexFailed
    ] /; ! indexPatternDataQ[desc]

ArrayIndexPlan[spec_, dimsOrArrays_List, bindings : {(_Rule | _RuleDelayed) ...} : {}, opts : ((_Rule | _RuleDelayed) ...)] :=
    Module[{result},
        result /; (result = catchIndexFailure[
            indexCheckOptions[ArrayIndexPlan, spec, {opts}];
            indexCheckBindings[spec, bindings];
            indexPlanObject[spec, dimsOrArrays, bindings, {opts}]
        ]) =!= $indexFailed
    ]

ArrayIndexTransform[spec_, arg_, bindings : {(_Rule | _RuleDelayed) ...} : {}, opts : ((_Rule | _RuleDelayed) ...)] :=
    Module[{result},
        result /; (result = catchIndexFailure[
            indexCheckOptions[ArrayIndexTransform, spec, {opts}];
            indexCheckBindings[spec, bindings];
            indexExecuted[ArrayIndexTransform, spec, arg, bindings, {opts}]
        ]) =!= $indexFailed
    ]

ArrayIndexContract[spec_, arrays_, bindings : {(_Rule | _RuleDelayed) ...} : {}, opts : ((_Rule | _RuleDelayed) ...)] :=
    Module[{result},
        result /; (result = catchIndexFailure[
            indexCheckOptions[ArrayIndexContract, spec, {opts}];
            indexCheckBindings[spec, bindings];
            indexOption[ArrayIndexContract, {opts}, "Combiner"];
            indexExecuted[ArrayIndexContract, spec, arrays, bindings, {opts}]
        ]) =!= $indexFailed
    ]


(* === properties === *)

$indexPatternProperties = {
    "Axes", "Constraints", "Descriptor", "Dialect", "Effects",
    "InputRanks", "OutputRank", "Properties", "Targets"
}

$indexPlanProperties = {
    "AxisSizes", "Effects", "Expression", "InputDimensions",
    "OutputDimensions", "Pattern", "Properties", "Steps"
}


(* An axis is an integer identity and its display name is what a reader asked
   for, so every property that names an axis goes through indexAxisLabel.  Two
   nameless axes - an anonymous term, a literal - can share a display name, and
   a property keyed by name reports them as one entry; the axis table, under
   "Descriptor", is where they stay apart. *)

indexPatternProperty[data_, "Axes"] := With[{normalized = data["Normalized"]},
    Map[indexAxisLabel[normalized, #] &, Keys[normalized["Axes"]]]
]

indexPatternProperty[data_, "Constraints"] := data["Normalized"]["Constraints"]

indexPatternProperty[data_, "Descriptor"] := data["Normalized"]

indexPatternProperty[data_, "Dialect"] := data["Normalized"]["Dialect"]

(* The effect classification is what the analysis decides, so reading it runs
   the analysis: an occurrence policy a descriptor breaks is reported here
   rather than at the parse that accepted the descriptor's grammar. *)

indexPatternProperty[data_, "Effects"] := indexPatternAnalysis[data]["Effects"]

indexPatternProperty[data_, "InputRanks"] := Length /@ data["Normalized"]["Inputs"]

indexPatternProperty[data_, "OutputRank"] := Length[First[data["Normalized"]["Outputs"]]]

(* The targeted axes are read off the validated occurrences rather than off the
   descriptor's target map: an occurrence carries the setting "Targeting"
   selected, so with False - the mode in which a repeated name alone contracts,
   and target wrappers are ignored - it is empty. *)
indexPatternProperty[data_, "Targets"] := With[{analysis = indexPatternAnalysis[data]},
    With[{normalized = analysis["Normalized"], frames = analysis["InputFrames"]},
        DeleteDuplicates[Map[indexAxisLabel[normalized, frames[[#[[1]], #[[2]]]]] &, analysis["TargetedOccurrences"]]]
    ]
]

indexPatternProperty[_, "Properties"] := $indexPatternProperties


indexPlanProperty[plan_, "AxisSizes"] := KeyMap[indexAxisLabel[plan["Analysis"]["Normalized"], #] &, plan["AxisSizes"]]

indexPlanProperty[plan_, "Effects"] := plan["Analysis"]["Effects"]

(* The held expression is the one indexExecutePlan releases, so a trace read
   here is what runs. *)
indexPlanProperty[plan_, "Expression"] := indexPlanExpression[plan]

indexPlanProperty[plan_, "InputDimensions"] := plan["InputDimensions"]

indexPlanProperty[plan_, "OutputDimensions"] := plan["OutputDimensions"]

indexPlanProperty[plan_, "Pattern"] := ArrayIndexPattern[indexPatternData[plan["Analysis"]]]

indexPlanProperty[plan_, "Steps"] := plan["Steps"]

indexPlanProperty[_, "Properties"] := $indexPlanProperties


(* The property protocol is ArrayObject's, and so is the reason each clause
   carries HoldPattern: an assignment evaluates its left-hand side, and the head
   of these is itself an object expression, which the constructor clause above
   would try to compile as a descriptor while the paclet loads.

   The four clauses are mutually exclusive by construction - a supported
   property against an unsupported one, valid object data against invalid, one
   argument against any other count - so none of them depends on ordering.
   Anything unsupported messages and stays unevaluated, matching the way the
   heads themselves decline.

   The supported-property clause carries the same catchIndexFailure boundary the
   heads do, because a property may run a stage: "Effects" analyzes, and a
   descriptor whose occurrence policy the analysis declines must message and
   leave the lookup as written rather than let the throw reach top level. *)

HoldPattern[ArrayIndexPattern[data_ ? indexPatternDataQ][prop_]] := Module[{result},
    result /; MemberQ[$indexPatternProperties, prop] &&
        (result = catchIndexFailure[indexPatternProperty[data, prop]]) =!= $indexFailed
]

HoldPattern[ArrayIndexPattern[data_ ? indexPatternDataQ][prop_]] /; ! MemberQ[$indexPatternProperties, prop] && (Message[ArrayIndexPattern::noprop, prop]; False) := Null

HoldPattern[ArrayIndexPattern[data_][___]] /; ! indexPatternDataQ[data] && (Message[ArrayIndexPattern::malformed, data]; False) := Null

HoldPattern[ArrayIndexPattern[data_ ? indexPatternDataQ][props___]] /; Length[{props}] =!= 1 && (Message[ArrayIndexPattern::propx, Length[{props}]]; False) := Null


HoldPattern[ArrayIndexPlan[plan_ ? indexPlanQ][prop_]] := Module[{result},
    result /; MemberQ[$indexPlanProperties, prop] &&
        (result = catchIndexFailure[indexPlanProperty[plan, prop]]) =!= $indexFailed
]

HoldPattern[ArrayIndexPlan[plan_ ? indexPlanQ][prop_]] /; ! MemberQ[$indexPlanProperties, prop] && (Message[ArrayIndexPlan::noprop, prop]; False) := Null

HoldPattern[ArrayIndexPlan[plan_][___]] /; ! indexPlanQ[plan] && (Message[ArrayIndexPlan::malformed, plan]; False) := Null

HoldPattern[ArrayIndexPlan[plan_ ? indexPlanQ][props___]] /; Length[{props}] =!= 1 && (Message[ArrayIndexPlan::propx, Length[{props}]]; False) := Null


(* === summary boxes === *)

(* Two constant Graphics evaluated once at load, in the palette of
   $arrayObjectIcon and built from primitives so the paclet carries no image
   asset: two operand blocks sharing an axis for the pattern, a stack of
   narrowing rows for the plan. *)

$indexPatternIcon = Graphics[
    {
        EdgeForm[GrayLevel[0.35]],
        FaceForm[GrayLevel[0.85]],
        Rectangle[{0, 0}, {1.2, 1.2}],
        Rectangle[{1.8, 1.8}, {3, 3}],
        FaceForm[GrayLevel[0.55]],
        EdgeForm[None],
        Rectangle[{1.15, 1.35}, {1.85, 1.65}],
        Rectangle[{1.35, 1.15}, {1.65, 1.85}]
    },
    ImageSize -> {24, 24},
    PlotRange -> {{-0.1, 3.1}, {-0.1, 3.1}},
    PlotRangePadding -> None,
    Background -> None
]

$indexPlanIcon = Graphics[
    {
        EdgeForm[GrayLevel[0.35]],
        FaceForm[GrayLevel[0.85]],
        Rectangle[{0, 2.1}, {3, 2.9}],
        Rectangle[{0, 1.1}, {2, 1.9}],
        FaceForm[GrayLevel[0.55]],
        Rectangle[{0, 0.1}, {1, 0.9}]
    },
    ImageSize -> {24, 24},
    PlotRange -> {{-0.1, 3.1}, {-0.1, 3.1}},
    PlotRangePadding -> None,
    Background -> None
]


(* One row per effect class rather than the records themselves: the records
   carry every occurrence of every axis, which is a page of output where the
   question a box answers is what the descriptor DOES. *)

indexEffectTally[effects_] := Counts[Map[Lookup[#, "Effect"] &, effects]]

(* The two rows a box can only draw from an analysis, drawn together because one
   analysis answers both.  A renderer must not message and must not refuse, so
   the analysis is taken quietly: a descriptor whose occurrence policy the
   analysis declines - a kept diagonal, say - still shows its axes, its ranks
   and its dialect, and simply carries no effect tally.  The target row is drawn
   only when there is one, so a descriptor written without brackets - the
   classic einsum spelling - shows no row about them. *)

indexAnalysisItems[data_] := With[{analysis = Quiet[catchIndexFailure[indexPatternAnalysis[data]]]},
    If[ analysis === $indexFailed,
        {},

        Join[
            {BoxForm`SummaryItem[{"effects: ", indexEffectTally[analysis["Effects"]]}]},
            With[{targets = indexPatternProperty[data, "Targets"]},
                If[targets === {}, {}, {BoxForm`SummaryItem[{"targets: ", targets}]}]
            ]
        ]
    ]
]


(* Every row comes from the axis table, the effect records or the solved sizes,
   so a box is drawn without touching an operand: both objects render under a
   blocked ArrayMaterialize, as an ArrayObject does, and a plan renders with no
   arrays anywhere near it.

   An object whose argument is not the Association its head promises draws no
   box at all and prints as itself: MakeBoxes is a renderer and must not
   message. *)

ArrayIndexPattern /: MakeBoxes[obj : ArrayIndexPattern[data_], form : StandardForm | TraditionalForm] /; indexPatternDataQ[data] :=
    BoxForm`ArrangeSummaryBox[
        ArrayIndexPattern,
        obj,
        $indexPatternIcon,
        {
            BoxForm`SummaryItem[{"axes: ", indexPatternProperty[data, "Axes"]}],
            BoxForm`SummaryItem[{"operands: ", indexPatternProperty[data, "InputRanks"]}]
        },
        Join[
            {
                BoxForm`SummaryItem[{"output: ", indexPatternProperty[data, "OutputRank"]}],
                BoxForm`SummaryItem[{"dialect: ", indexPatternProperty[data, "Dialect"]}]
            },
            indexAnalysisItems[data]
        ],
        form,
        "Interpretable" -> Automatic
    ]

ArrayIndexPlan /: MakeBoxes[obj : ArrayIndexPlan[plan_], form : StandardForm | TraditionalForm] /; indexPlanQ[plan] :=
    BoxForm`ArrangeSummaryBox[
        ArrayIndexPlan,
        obj,
        $indexPlanIcon,
        {
            BoxForm`SummaryItem[{"operands: ", plan["InputDimensions"]}],
            BoxForm`SummaryItem[{"dimensions: ", plan["OutputDimensions"]}]
        },
        {
            BoxForm`SummaryItem[{"axes: ", indexPatternProperty[indexPatternData[plan["Analysis"]], "Axes"]}],
            BoxForm`SummaryItem[{"axis sizes: ", indexPlanProperty[plan, "AxisSizes"]}],
            BoxForm`SummaryItem[{"steps: ", Map[Lookup[#, "Step"] &, plan["Steps"]]}],
            BoxForm`SummaryItem[{"effects: ", indexEffectTally[plan["Analysis"]["Effects"]]}]
        },
        form,
        "Interpretable" -> Automatic
    ]
