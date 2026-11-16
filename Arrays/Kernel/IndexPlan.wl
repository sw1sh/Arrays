Package["Wolfram`Arrays`"]

PackageScope[indexOperationAnalysis]
PackageScope[indexAdmitEffects]
PackageScope[indexExecutionPlan]
PackageScope[indexPlanQ]
PackageScope[$indexCheckedPlan]


(* === the middle of the compiler ===

   Two values are built here.  The OPERATION ANALYSIS says what a descriptor
   does to each of its axes; the EXECUTION PLAN says how.  They are separated
   because the analysis is purely structural - it reads the normalized
   descriptor and never a size - so a parsed pattern can report its effects with
   no operand in sight, while the plan needs the solved sizes for every
   dimension it writes down.

   Nothing in this file matches a normalized term in a definition left-hand
   side.  indexAxis and indexProduct belong to IndexNotation.wl, and a term
   reaches this file already flattened by indexFlatTerms, so an axis id is read
   out by part rather than by pattern.

   The message templates live in IndexOperators.wl beside the symbols that own
   them; a refusal here throws through indexFail and is turned into a message at
   the public boundary. *)


(* The diagnostic payload of a refusal about one axis: its id, and the held
   surface fragment it was captured from.  The path is wrapped in Key because a
   path is itself a List, and a bare List key reads as several keys. *)

indexAxisSource[normalized_Association, id_Integer] :=
    With[{path = Lookup[Lookup[normalized["Axes"], id, <||>], "Source", None]},
        <|"Axis" -> id, "Source" -> Lookup[normalized["SourceMap"], Key[path], None]|>
    ]

indexAxisNames[normalized_Association, ids_List] := Map[Function[id, indexAxisLabel[normalized, id]], ids]


(* === frames === *)

(* A FRAME is the axis content of a shape after the two structural erasures the
   lift performs on the way in: a CircleTimes composite is flattened to its
   factors, because the split reshape gives each factor its own dimension, and a
   unit axis is dropped, because the same reshape squeezes it.  Nothing else is
   erased - a literal of size two or more keeps its slot and is summed like any
   other axis the output does not carry.

   An input frame is NOT duplicate-free: an axis repeated within one operand
   occurs twice and is resolved into a trace by the plan's self-contraction
   step.  An output frame is duplicate-free, since a repeated output axis was
   already declined at normalization.

   The path of every surviving input occurrence is kept beside its frame
   position, because "Targets" is keyed by path: an occurrence is what a target
   sits on, and a target may sit on a composite, in which case it stands for
   every factor under it. *)

indexFrames[normalized_Association] :=
    Module[{axes = normalized["Axes"], shapes = normalized["Inputs"], frames, positions = {}, units = {}, outFrame = {}},
        frames = Table[
            Module[{frame = {}},
                Do[
                    With[{id = leaf[[1, 1]], path = Join[{"Inputs", k}, leaf[[2]]]},
                        If[ axes[id]["Kind"] === "Unit",
                            AppendTo[units, <|"Effect" -> "UnitAxis", "Axis" -> id, "Side" -> "Inputs", "Source" -> path|>],
                            AppendTo[frame, id];
                            AppendTo[positions, path -> {k, Length[frame]}]
                        ]
                    ],
                    {leaf, indexFlatTerms[shapes[[k]]]}
                ];
                frame
            ],
            {k, Length[shapes]}
        ];
        Do[
            With[{id = leaf[[1, 1]], path = Join[{"Outputs", 1}, leaf[[2]]]},
                If[ axes[id]["Kind"] === "Unit",
                    AppendTo[units, <|"Effect" -> "UnitAxis", "Axis" -> id, "Side" -> "Outputs", "Source" -> path|>],
                    AppendTo[outFrame, id]
                ]
            ],
            {leaf, indexFlatTerms[First[normalized["Outputs"]]]}
        ];
        <|"InputFrames" -> frames, "OutputFrame" -> outFrame, "Positions" -> positions, "Units" -> units|>
    ]


(* === effect classification === *)

(* One axis, one effect, and the occurrence policy is checked in the same place
   that assigns it, so an effect that exists is admissible and the analysis
   carries no list of violations.

   The branches are ordered from the most local evidence outwards.  Three
   occurrences in one operand is a generalized diagonal with no lowering here;
   two in one operand and any elsewhere mixes a trace with a contraction, which
   the pairwise trace cannot express; two in one operand and kept on the output
   is the diagonal "ii->i", which is declined by name rather than answered with
   row sums.  What survives is the trace, the carry and the contraction.

   A "Contracted" axis with ONE occurrence is not a separate effect: an axis the
   output drops is summed over every slot that carries it, and one slot is the
   degenerate case of that, not a different operation. *)

indexClassifyAxis[normalized_Association, id_Integer, inputs_List, outputs_List] :=
    Module[{repeat = If[inputs === {}, 0, Max[Counts[inputs[[All, 1]]]]]},
        Which[
            inputs === {},
                <|"Effect" -> "Broadcast", "Axis" -> id, "Outputs" -> outputs|>,
            repeat >= 3 || (repeat === 2 && Length[inputs] > 2),
                indexFail[ArrayIndexPlan, "occurrences",
                    {indexAxisLabel[normalized, id], Length[inputs]}, indexAxisSource[normalized, id]],
            repeat === 2 && outputs =!= {},
                indexFail[ArrayIndexPlan, "diagonal",
                    {indexAxisLabel[normalized, id]}, indexAxisSource[normalized, id]],
            repeat === 2,
                <|"Effect" -> "SelfContracted", "Axis" -> id, "Inputs" -> inputs|>,
            outputs =!= {},
                <|"Effect" -> "Carried", "Axis" -> id, "Inputs" -> inputs, "Outputs" -> outputs|>,
            True,
                <|"Effect" -> "Contracted", "Axis" -> id, "Inputs" -> inputs|>
        ]
    ]


(* === targeting === *)

(* A target is recorded per path, and a path may name a composite, so an
   occurrence counts as targeted when SOME target path is a prefix of it.  A
   target that is a prefix of no input occurrence - one on the output side, or
   on an axis the frame dropped - is a target on nothing and is refused by
   name: the marked-versus-contracted comparison below has nothing of it to
   show, and both of that message's sets can be empty while the stray target
   is the whole problem. *)

indexPathPrefixQ[prefix_List, path_List] :=
    Length[prefix] <= Length[path] && Take[path, Length[prefix]] === prefix

(* The axes under a target path, read from the descriptor's own terms rather
   than from the surviving occurrences: a target that survives nowhere still
   sits somewhere, and its refusal names the axes it sits on. *)
indexTargetPathAxes[normalized_Association, paths_List] :=
    Module[{leaves},
        leaves = Join[
            Catenate @ Table[
                Map[Function[leaf, {Join[{"Inputs", k}, leaf[[2]]], leaf[[1, 1]]}],
                    indexFlatTerms[normalized["Inputs"][[k]]]],
                {k, Length[normalized["Inputs"]]}
            ],
            Map[Function[leaf, {Join[{"Outputs", 1}, leaf[[2]]], leaf[[1, 1]]}],
                indexFlatTerms[First[normalized["Outputs"]]]]
        ];
        DeleteDuplicates @ Catenate @ Map[
            Function[t, Map[Last, Select[leaves, Function[leaf, indexPathPrefixQ[t, First[leaf]]]]]],
            paths
        ]
    ]

indexTargetedOccurrences[normalized_Association, frames_List, positions_List, effects_List, targeting_] :=
    Module[{targets = Keys[normalized["Targets"]], occurrences, matched, unmatched, marked, wanted},
        If[targeting === False, occurrences = {},
            occurrences = Values @ Select[positions,
                Function[place, AnyTrue[targets, Function[t, indexPathPrefixQ[t, First[place]]]]]];
            matched = Select[targets,
                Function[t, AnyTrue[positions, Function[place, indexPathPrefixQ[t, First[place]]]]]];
            unmatched = Complement[targets, matched];
            If[ unmatched =!= {},
                indexFail[ArrayIndexPlan, "targetplace",
                    {indexAxisNames[normalized, indexTargetPathAxes[normalized, unmatched]]},
                    <|"Targets" -> unmatched|>
                ]
            ];
            (* The comparison is between AXES and not between occurrences: a
               target marks the axis it sits on, so one bracket on one operand
               marks a contracted axis that occurs on two, and the marked set is
               what the refusal names.  Comparing occurrence lists instead would
               refuse "i [j], j k -> i k" with a message naming j on both sides
               of its own mismatch. *)
            marked = DeleteDuplicates[Map[Function[place, Extract[frames, place]], occurrences]];
            wanted = Map[Function[record, record["Axis"]],
                Cases[effects, KeyValuePattern["Effect" -> "Contracted" | "SelfContracted"]]];
            (* With Automatic the check runs only once the descriptor has spelled
               a target at all, which is what lets an untargeted einsum
               descriptor contract by repeated name.  With True it always runs,
               so a contracted axis with no target is a refusal. *)
            If[ (targeting === True || targets =!= {}) && Sort[marked] =!= Sort[wanted],
                indexFail[ArrayIndexPlan, "target",
                    {indexAxisNames[normalized, marked], indexAxisNames[normalized, wanted]},
                    <|"Targets" -> targets|>
                ]
            ]
        ];
        occurrences
    ]


(* === the analysis === *)

indexOperationAnalysis[normalized_Association, targeting_] :=
    Module[{parts, frames, outFrame, positions, units, unitRecords, inputOccurrences, outputOccurrences,
            effects},
        If[ ! MatchQ[targeting, True | Automatic | False],
            indexFail[ArrayIndexPlan, "option", {targeting, "Targeting"}, <|"Option" -> "Targeting"|>]
        ];
        parts = indexFrames[normalized];
        frames = parts["InputFrames"];
        outFrame = parts["OutputFrame"];
        positions = parts["Positions"];
        units = parts["Units"];
        (* An occurrence is a {operand, framePosition} pair, and the whole
           classification reads these two tables.  Grouping by axis keeps the
           occurrences of one axis in operand-then-position order, which is the
           order the contraction groups and the trace pairs are read in. *)
        inputOccurrences = GroupBy[
            Catenate @ Table[{frames[[k, p]], {k, p}}, {k, Length[frames]}, {p, Length[frames[[k]]]}],
            First -> Last
        ];
        outputOccurrences = GroupBy[Table[{outFrame[[q]], {1, q}}, {q, Length[outFrame]}], First -> Last];
        unitRecords = GroupBy[units, Function[unit, unit["Axis"]], First];
        (* Axis ids are allocated in first-occurrence order, so walking the axis
           table in key order gives the effect records in that order too, and
           every id in the table occurs somewhere by construction. *)
        effects = Table[
            If[ KeyExistsQ[unitRecords, id],
                unitRecords[id],
                indexClassifyAxis[normalized, id, Lookup[inputOccurrences, id, {}], Lookup[outputOccurrences, id, {}]]
            ],
            {id, Keys[normalized["Axes"]]}
        ];
        <|
            "Normalized" -> normalized,
            "InputFrames" -> frames,
            "OutputFrame" -> outFrame,
            "Effects" -> effects,
            "Targeting" -> targeting,
            "TargetedOccurrences" -> indexTargetedOccurrences[normalized, frames, positions, effects, targeting]
        |>
    ]


(* === entrance policy === *)

(* The entry symbol is compared rather than matched, because the public heads
   are declared in IndexOperators.wl and a left-hand side here would freeze
   against whichever file loaded first.  A contraction admits every effect the
   analysis can produce; a rearrangement admits every effect that moves an axis
   and none that sums one, so the axis that would be summed is named and
   ArrayIndexContract is named beside it. *)

indexAdmitEffects[analysis_Association, sym_Symbol] :=
    Module[{normalized = analysis["Normalized"], summed},
        If[ sym === ArrayIndexTransform,
            If[ Length[analysis["InputFrames"]] > 1,
                indexFail[ArrayIndexTransform, "arity",
                    {Length[analysis["InputFrames"]], Length[normalized["Outputs"]]}, <||>]
            ];
            summed = FirstCase[analysis["Effects"], KeyValuePattern["Effect" -> "Contracted" | "SelfContracted"], None];
            If[ summed =!= None,
                indexFail[ArrayIndexTransform, "effect",
                    {indexAxisLabel[normalized, summed["Axis"]]}, indexAxisSource[normalized, summed["Axis"]]]
            ]
        ];
        analysis
    ]


(* === the plan === *)

(* ArrayTranspose and Transpose take the SCATTER permutation: input level i
   goes to output level perm[[i]].  The planner always knows the GATHER instead
   - which input position supplies each output position - and Ordering turns one
   into the other.  current and wanted are the same set, duplicate-free. *)

indexGatherPermutation[current_List, wanted_List] :=
    Ordering[Flatten[Map[Function[id, FirstPosition[current, id]], wanted]]]

(* The extent an operand has on each entry of its frame: an atomic term stands
   for the operand's own dimension at its position, a factor of a composite for
   the size its axis was solved to, and a unit axis is no entry at all.  These
   are the solved sizes, except where "DimensionMismatch" -> "Pad" let an
   operand be shorter than its axes. *)

indexActualFrameDims[normalized_Association, k_Integer, shape_List, sizes_Association] :=
    Map[
        Function[leaf, If[Length[leaf[[2]]] === 1, shape[[First[leaf[[2]]]]], sizes[leaf[[1, 1]]]]],
        Select[
            indexFlatTerms[normalized["Inputs"][[k]]],
            Function[leaf, normalized["Axes"][leaf[[1, 1]]]["Kind"] =!= "Unit"]
        ]
    ]

(* Every step carries "Step", "Inputs", "Output", "Frame" and "Dimensions"; its
   own fields sit between the register it writes and the shape of what it
   writes, so a step reads as verb, operands, result, argument, shape. *)

indexEmit[step_String, inputs_List, output_Integer, own_Association, frame_List, dims_List] :=
    Join[<|"Step" -> step, "Inputs" -> inputs, "Output" -> output|>, own, <|"Frame" -> frame, "Dimensions" -> dims|>]


(* The plan is a single-assignment register file: registers 1 to n hold the
   operands as given, each step writes one fresh register, and every register is
   read at most once, a tensor power's copies apart - so the whole plan renders
   to one nested expression whose only open positions are the operand slots,
   which is the Function that "Expression" hands back.

   The passes are the alignment core: split each operand into its axes, padding
   it where it is shorter than they are, trace it, contract the operands against
   each other, raise the result to a tensor power where the output repeats an
   axis, and lower it back onto the output shape.  A step is emitted only when it
   is not the identity, which is why a pure permutation comes out as a single
   ArrayTranspose and a pure split as a single ReshapeArray.

   No operand is ever lifted into a common frame.  An axis two operands share
   and the output keeps - a batch index - is a diagonal, which a contraction
   group alone cannot spell, and it is spelled with a DELTA in the contraction:
   one slot tied to each slot that carries the axis, and one slot left free to
   carry it to the output.  ArrayContract contracts a delta by identifying the
   slots it ties, so the batch index costs what the result costs, where lifting
   the operands into a common frame and multiplying them elementwise builds
   their outer product first; and the same node is what stays inert over a
   symbolic operand and what a lazy operand's rebuild contracts. *)

indexExecutionPlan[analysis_Association, solved_Association] :=
    Module[{
            sizes = solved["AxisSizes"], inputShapes = solved["InputShapes"], effects = analysis["Effects"],
            outFrame = analysis["OutputFrame"], outDims = First[solved["OutputShapes"]],
            frames, dims, actual, regs, steps = {}, next, n, traces, scalars, tensors,
            slotFrame, slotDims, batch, deltas = {}, deltaGroups = {}, fullFrame, fullDims,
            groups, dropped, result, resultFrame, resultDims, spread, factors,
            idSpan, sizeOf, counts, copies, base, powerGroups
        },
        frames = analysis["InputFrames"];
        n = Length[frames];
        regs = Range[n];
        next = n + 1;
        dims = Table[Lookup[sizes, frames[[k]]], {k, n}];
        actual = Table[indexActualFrameDims[analysis["Normalized"], k, inputShapes[[k]], sizes], {k, n}];

        (* A tensor power copies the axes it repeats, and a copy is numbered
           past every axis id, so that a frame stays a list of integers and the
           size of an entry is the size of the axis it copies. *)
        idSpan = Max[Prepend[Keys[sizes], 0]] + 1;
        sizeOf = Function[frame, Lookup[sizes, Mod[frame, idSpan]]];

        (* 1.  Split and squeeze.  One reshape does both: splitting a composite
               and dropping a unit axis each preserve the element count, and
               ReshapeArray preserves element order, so the leftmost factor of a
               composite lands on the outermost axis.  An operand shorter than
               its axes, which "DimensionMismatch" -> "Pad" admits, is then padded
               to them: an extent of 1 repeated, any other extent padded at the
               end with 1s, which is IndexedMultiply's rule. *)
        Do[
            If[ actual[[k]] =!= inputShapes[[k]],
                AppendTo[steps, indexEmit["Reshape", {regs[[k]]}, next, <||>, frames[[k]], actual[[k]]]];
                regs[[k]] = next++
            ];
            If[ actual[[k]] =!= dims[[k]],
                AppendTo[steps, indexEmit["Pad", {regs[[k]]}, next,
                    <|
                        "Padding" -> MapThread[{0, #1 - #2} &, {dims[[k]], actual[[k]]}],
                        "Repeat" -> MapThread[#2 === 1 && #1 > 1 &, {dims[[k]], actual[[k]]}]
                    |>,
                    frames[[k]], dims[[k]]]];
                regs[[k]] = next++
            ],
            {k, n}
        ];

        (* 2.  Self-contraction.  A trace is taken before anything else touches
               the operand, so every frame is duplicate-free from here on and
               the contraction never sees a repeated slot of one operand. *)
        traces = GroupBy[
            Cases[effects, KeyValuePattern["Effect" -> "SelfContracted"]],
            Function[effect, effect["Inputs"][[1, 1]]],
            Function[group, Sort[Map[Function[effect, Sort[effect["Inputs"][[All, 2]]]], group]]]
        ];
        Do[
            With[{pairs = Lookup[traces, k, {}]},
                If[ pairs =!= {},
                    dropped = List /@ Sort[Catenate[pairs]];
                    frames[[k]] = Delete[frames[[k]], dropped];
                    dims[[k]] = Delete[dims[[k]], dropped];
                    AppendTo[steps, indexEmit["Contract", {regs[[k]]}, next, <|"Groups" -> pairs|>, frames[[k]], dims[[k]]]];
                    regs[[k]] = next++
                ]
            ],
            {k, n}
        ];

        (* 3.  Contract.  The tensors are numbered by concatenating their
               frames, and every axis the output does not carry becomes one
               ascending group of the slots that carry it: one slot is a sum,
               two an ordinary contraction, three or more the hyperedge a
               pairwise contractor cannot express.  An axis the output carries
               and two or more slots supply is a batch index, and gets a delta
               of one slot more than it has occurrences: each occurrence is
               grouped with a slot of the delta, and the last slot is free and
               carries the axis on.  The deltas come FIRST in the node, so the
               batch axes lead the result, which is where a batch product keeps
               them and where the delta route computes them, and the result
               needs no transpose to reach the common layout.  A rank-0 operand
               joins the node too, contributing no slot, so a scale and a
               contraction are one step; a set of scalars alone has nothing to
               contract and is multiplied. *)
        scalars = Select[Range[n], Function[k, frames[[k]] === {}]];
        tensors = Select[Range[n], Function[k, frames[[k]] =!= {}]];
        slotFrame = Catenate[frames[[tensors]]];
        slotDims = Catenate[dims[[tensors]]];
        batch = DeleteDuplicates[Select[outFrame, Function[id, Count[slotFrame, id] >= 2]]];
        With[{offset = Total[Map[Function[id, Count[slotFrame, id] + 1], batch]]},
            fullFrame = {};
            fullDims = {};
            Do[
                With[{occurrences = Flatten[Position[slotFrame, id]], base = Length[fullFrame]},
                    AppendTo[deltas, ConstantArray[sizes[id], Length[occurrences] + 1]];
                    deltaGroups = Join[deltaGroups, Table[{base + i, offset + occurrences[[i]]}, {i, Length[occurrences]}]];
                    fullFrame = Join[fullFrame, ConstantArray[id, Length[occurrences] + 1]];
                    fullDims = Join[fullDims, ConstantArray[sizes[id], Length[occurrences] + 1]]
                ],
                {id, batch}
            ];
            fullFrame = Join[fullFrame, slotFrame];
            fullDims = Join[fullDims, slotDims];
            groups = Join[
                deltaGroups,
                Map[
                    Function[id, offset + Flatten[Position[slotFrame, id]]],
                    DeleteDuplicates[Select[slotFrame, Function[id, ! MemberQ[outFrame, id]]]]
                ]
            ]
        ];
        dropped = List /@ Sort[Catenate[groups]];
        resultFrame = Delete[fullFrame, dropped];
        resultDims = Delete[fullDims, dropped];
        Which[
            tensors === {} && Length[scalars] === 1,
                result = regs[[First[scalars]]],
            tensors === {},
                AppendTo[steps, indexEmit["Multiply", regs[[scalars]], next, <||>, resultFrame, resultDims]];
                result = next++,
            Length[tensors] === 1 && groups === {} && scalars === {},
                result = regs[[First[tensors]]],
            True,
                AppendTo[steps, indexEmit["Contract", regs[[Join[tensors, scalars]]], next,
                    If[deltas === {}, <|"Groups" -> groups|>, <|"Groups" -> groups, "Deltas" -> deltas|>], resultFrame, resultDims]];
                result = next++
        ];

        (* 4.  Repeat the axes the output carries and no operand supplies.  This
               is genuine work: Wolfram arithmetic does not broadcast a size-1
               dimension, so the step cannot be elided. *)
        spread = DeleteDuplicates[Select[outFrame, Function[id, ! MemberQ[resultFrame, id]]]];
        If[ spread =!= {},
            factors = Lookup[sizes, spread];
            resultFrame = Join[resultFrame, spread];
            resultDims = Join[resultDims, factors];
            AppendTo[steps, indexEmit["Broadcast", {result}, next, <|"Sizes" -> factors, "Axes" -> spread|>, resultFrame, resultDims]];
            result = next++
        ];

        (* 5.  The tensor power.  An output that names an axis more than once,
               which "IndexMultiplicity" -> True admits, is read as a tensor power
               of the result so far, which carries each output axis once: as many
               copies as the most-repeated axis has occurrences, the r-th
               occurrence of an axis read off the r-th copy, and an axis's slots
               in the copies past its own count summed together in one group, as
               EinsteinSummation reads it.  The copies are the one register read
               more than once, so the rendered plan writes the result so far once
               per copy. *)
        If[ ! DuplicateFreeQ[outFrame],
            counts = Counts[outFrame];
            copies = Max[counts];
            base = resultFrame;
            powerGroups = DeleteCases[
                Table[Table[(r - 1) Length[base] + p, {r, counts[base[[p]]] + 1, copies}], {p, Length[base]}],
                {}
            ];
            fullFrame = Catenate[Table[base + (r - 1) idSpan, {r, copies}]];
            fullDims = Catenate[ConstantArray[resultDims, copies]];
            dropped = List /@ Sort[Catenate[powerGroups]];
            resultFrame = Delete[fullFrame, dropped];
            resultDims = Delete[fullDims, dropped];
            AppendTo[steps, indexEmit["Contract", ConstantArray[result, copies], next, <|"Groups" -> powerGroups|>, resultFrame, resultDims]];
            result = next++;
            outFrame = MapIndexed[
                Function[{id, position}, id + (Count[Take[outFrame, First[position]], id] - 1) idSpan],
                outFrame
            ]
        ];

        (* 6.  Permute into the output order. *)
        If[ resultFrame =!= outFrame,
            AppendTo[steps, indexEmit["Transpose", {result}, next, <|"Permutation" -> indexGatherPermutation[resultFrame, outFrame]|>, outFrame, sizeOf[outFrame]]];
            result = next++;
            resultFrame = outFrame;
            resultDims = sizeOf[outFrame]
        ];

        (* 7.  Merge the output composites and insert the output unit axes.  The
               dimensions come from the solver, which multiplied each composite
               out while it was checking the operands. *)
        If[ resultDims =!= outDims,
            AppendTo[steps, indexEmit["Reshape", {result}, next, <||>, outFrame, outDims]];
            result = next++
        ];

        <|
            "Analysis" -> analysis,
            "Solved" -> solved,
            "Steps" -> steps,
            "Registers" -> next - 1,
            "Result" -> result,
            "InputDimensions" -> inputShapes,
            "OutputDimensions" -> outDims,
            "AxisSizes" -> sizes
        |>
    ]


(* === validity === *)

(* Total predicates, in the paclet's own idiom: a first clause that answers for
   a well-formed value and a catch-all that answers False, so the caller never
   has to guard the call. *)

indexDimensionsQ[dims_] := MatchQ[dims, {___Integer}] && AllTrue[dims, Positive]

indexPermutationQ[perm_] := MatchQ[perm, {___Integer}] && Sort[perm] === Range[Length[perm]]

(* A contraction group is ascending and duplicate-free, and no slot is in two
   groups: the slots of a group are levels of one tensor product, and a level
   contracted twice is not a level at all. *)
indexGroupsQ[groups_List] :=
    AllTrue[groups, Function[group, MatchQ[group, {__Integer}] && AllTrue[group, Positive] && OrderedQ[group] && DuplicateFreeQ[group]]] &&
        DuplicateFreeQ[Catenate[groups]]

indexGroupsQ[_] := False

(* A batch delta ties every slot it has, all of one extent: one slot for each
   occurrence of the batch axis, two or more, and the free one. *)
indexDeltasQ[deltas_List] :=
    AllTrue[deltas, Function[delta, MatchQ[delta, {_Integer, _, __}] && indexDimensionsQ[delta] && SameQ @@ delta]]

indexDeltasQ[_] := False

indexStepQ[step_Association] :=
    And[
        MemberQ[{"Reshape", "Pad", "Transpose", "Broadcast", "Multiply", "Contract"}, Lookup[step, "Step"]],
        MatchQ[Lookup[step, "Inputs"], {___Integer}],
        IntegerQ[Lookup[step, "Output"]],
        MatchQ[Lookup[step, "Frame"], {___Integer}],
        indexDimensionsQ[Lookup[step, "Dimensions"]],
        Switch[step["Step"],
            "Transpose", indexPermutationQ[Lookup[step, "Permutation"]],
            "Contract", indexGroupsQ[Lookup[step, "Groups"]] && indexDeltasQ[Lookup[step, "Deltas", {}]],
            "Broadcast", indexDimensionsQ[Lookup[step, "Sizes"]] && MatchQ[Lookup[step, "Axes"], {__Integer}],
            "Pad",
                MatchQ[Lookup[step, "Padding"], {{0, _Integer ? NonNegative} ...}] &&
                    MatchQ[Lookup[step, "Repeat"], {(True | False) ...}] &&
                    Length[step["Padding"]] === Length[step["Frame"]] === Length[step["Repeat"]],
            _, True
        ]
    ]

indexStepQ[_] := False

(* The steps and the stage they were built from are both checked, because a plan
   object is a value a caller can hold and hand back: the steps say what runs and
   the solved descriptor says what they run on, and a plan carrying one without
   the other is declined here rather than half-executed.

   The check reads every step and the whole solved stage, and a call that runs a
   prepared plan meets the plan at every stage it passes - the option check, the
   binding check, the analysis and the plan lookup each match it - so the
   entrance checks it once and binds it as $indexCheckedPlan for the rest of the
   call, and the plan it bound passes at once.  The comparison is SameQ on the
   one expression the call was handed, which answers without walking it. *)

$indexCheckedPlan = None;

indexPlanQ[plan_Association] /; plan === $indexCheckedPlan := True

indexPlanQ[plan_Association] :=
    With[{steps = Lookup[plan, "Steps"]},
        And[
            ContainsAll[Keys[plan],
                {"Analysis", "Solved", "Steps", "Registers", "Result", "InputDimensions", "OutputDimensions", "AxisSizes"}],
            indexSolvedQ[Lookup[plan, "Solved"]],
            ListQ[steps],
            AllTrue[steps, indexStepQ],
            DuplicateFreeQ[Map[Function[step, step["Output"]], steps]],
            AllTrue[steps, Function[step, AllTrue[step["Inputs"], Function[register, register < step["Output"]]]]],
            IntegerQ[Lookup[plan, "Registers"]],
            IntegerQ[Lookup[plan, "Result"]],
            ListQ[Lookup[plan, "InputDimensions"]],
            indexDimensionsQ[Lookup[plan, "OutputDimensions"]],
            AssociationQ[Lookup[plan, "AxisSizes"]]
        ]
    ]

indexPlanQ[_] := False
