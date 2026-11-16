Package["Wolfram`Arrays`"]

PackageScope[indexPlanExpression]
PackageScope[indexExecutePlan]


(* === the lowered expression ===

   An execution plan is a single-assignment register file whose registers are
   each read at most once, so the plan is a tree and renders to ONE nested
   expression: every step's expression is substituted straight into the step
   that reads it, and operand k is left standing as Slot[k].  The finished body
   is wrapped in a Function of those slots, which is the head that says what the
   body already is, and which makes the rendered plan directly applicable: the
   application plan["Expression"][a1, a2, ...] is the very one indexExecutePlan
   makes, so the trace a caller inspects is what runs.

   The expression is assembled HELD, part by part, and that is not a formatting
   nicety.  ArrayContract and ArrayTranspose each have a generic clause that
   matches any first argument, so an unheld ArrayTranspose[Slot[1], perm] would
   evaluate to a Transpose of a Slot at the moment it was built, and the plan
   would render - and execute - something other than the step it stands for.
   Function is HoldAll, so the wrapper put on at the end protects what it wraps
   exactly as the Holds below it did.  Building from held parts is also what lets
   a plan render with no operands at all, which is what makes "Expression" a
   property of ArrayIndexPlan rather than of a call.

   A pattern name is substituted into a held right-hand side, which is what lets
   these helpers place an already computed value inside a Hold without
   evaluating what is held beside it. *)

indexHeldValue[x_] := Hold[x]

indexHoldApply[h_, parts : {__Hold}] := Replace[Join @@ parts, Hold[args___] :> Hold[h[args]]]

indexSlotExpression[k_Integer] := Hold[Slot[k]]

indexOnesExpression[n_Integer] := Hold[ConstantArray[1, n]]


(* === one step, one primitive ===

   Every step lowers to a primitive this paclet already has and already
   dispatches on the tier of its operands; there is no array algorithm here, and
   no tier is decided here either.  ReshapeArray, ArrayTranspose and
   ArrayContract each keep a symbolic operand inert and a lazy one lazy where its
   head can rebuild, so a plan whose steps are only those runs on every tier the
   same way, and its result is whatever tier its operands join to.

   A contraction is ArrayContract over an inactive TensorProduct, which is that
   symbol's spelling for an operand SET, and the step therefore names the
   operation rather than the way it is executed.  What ArrayContract does with
   the node is what the index layer needs of it: the operands are contracted
   against each other and the outer product is never built, so a SparseArray set
   gives a SparseArray, packed operands stay packed, exact operands stay exact,
   a structured atom keeps its structure and a QuantityArray carries the product
   of the units.  A List is one array to that symbol as it is to every other one
   here, so an operand set of plain nested Lists is contracted as the set it is.

   A group of one slot sums that slot, a group of two is an ordinary
   contraction, and a group of three or more is the generalized trace a
   hyperedge lowers to.  TensorContract takes all three, so a hyperedge needs no
   pairwise decomposition and the plan carries groups rather than pairs.  An
   empty group list needs no spelling of its own: the operands share no
   contracted axis, and a contraction with nothing to sum is their outer
   product, which is the array the step stands for.

   A batch index is a delta among the operands, after them in the node, and it
   is written INACTIVE: the evaluator unpacks every packed array beside an
   active SymbolicDeltaProductArray, at about the cost of reading the array, and
   ArrayContract takes the inactive delta as the one it activates to. *)

indexDeltaExpression[dims_List] := With[{d = dims, groups = {Range[Length[dims]]}},
    Hold[Inactive[SymbolicDeltaProductArray][d, groups]]
]

indexStepExpression[step : KeyValuePattern["Step" -> "Reshape"], {in_Hold}] :=
    indexHoldApply[ReshapeArray, {in, indexHeldValue[step["Dimensions"]]}]

indexStepExpression[step : KeyValuePattern["Step" -> "Transpose"], {in_Hold}] :=
    indexHoldApply[ArrayTranspose, {in, indexHeldValue[step["Permutation"]]}]

(* Broadcasting repeats an axis the output carries and no operand supplies, and
   it is genuine work rather than bookkeeping that could be elided: Wolfram
   arithmetic does not broadcast a length-1 dimension.  It is the tensor product
   of the register with vectors of ones, which is ArrayContract of their node
   with no group to sum - the same primitive as every contraction, so a symbolic
   register gives the inert product and a lazy one is rebuilt through its head.
   The ones vectors are left unevaluated inside the held expression, so the
   rendered plan names the extent it broadcasts to.

   The ones are integers, and the kernel's product of a packed Real or Complex
   operand with an integer vector comes back unpacked, so the product is passed
   through the plain form of Developer`ToPackedArray - the one form that never
   coerces a value, and that returns a SparseArray, an exact result, an inert
   node and a lazy container exactly as the product made it.

   A RANK-0 register takes ConstantArray instead, and the step's own shape says
   when: the frame it writes is the frame it read plus the axes it spreads, so a
   frame as long as the size list is a frame that was empty. *)
indexStepExpression[step : KeyValuePattern["Step" -> "Broadcast"], {in_Hold}] :=
    If[ Length[step["Frame"]] === Length[step["Sizes"]],
        indexHoldApply[ConstantArray, {in, indexHeldValue[step["Sizes"]]}],
        indexHoldApply[
            Developer`ToPackedArray,
            {
                indexHoldApply[
                    ArrayContract,
                    {
                        indexHoldApply[Inactive[TensorProduct], Join[{in}, Map[indexOnesExpression, step["Sizes"]]]],
                        indexHeldValue[{}]
                    }
                ]
            }
        ]
    ]

(* A multiply takes the operands of a descriptor that are all scalars, which
   have nothing to contract and no frame to align. *)
indexStepExpression[KeyValuePattern["Step" -> "Multiply"], ins : {__Hold}] :=
    indexHoldApply[Times, ins]

indexStepExpression[step : KeyValuePattern["Step" -> "Contract"], ins : {__Hold}] :=
    indexHoldApply[
        ArrayContract,
        {
            indexHoldApply[Inactive[TensorProduct], Join[ins, Map[indexDeltaExpression, Lookup[step, "Deltas", {}]]]],
            indexHeldValue[step["Groups"]]
        }
    ]


(* Registers 1 .. n hold the operands as given and each step writes one fresh
   register, so the walk is a single forward pass: a step's expression is looked
   up by register and never rebuilt.  The finished body leaves its Hold for a
   Function in one step at the end, a head that holds its argument as firmly, so
   nothing below was ever exposed.  A plan with no steps gives Function[Slot[1]],
   which applies to the operand itself - the descriptor that asks for nothing
   copies nothing. *)

indexPlanExpression[plan_Association] := Module[{registers = <||>},
    Do[registers[k] = indexSlotExpression[k], {k, Length[plan["InputDimensions"]]}];
    Do[
        registers[step["Output"]] = indexStepExpression[step, Lookup[registers, step["Inputs"]]],
        {step, plan["Steps"]}
    ];
    Replace[registers[plan["Result"]], Hold[body_] :> Function[body]]
]


(* === execution ===

   TensorProduct has no evaluation on the heads that are not ArrayQ, so a
   NumericArray, a Dataset or a Tabular handed straight to a contraction node is
   not contracted at all: Activate turns the inactive product into a Times of
   the wrappers and the answer is lost with no message.  The operands that need
   materializing are exactly the explicit ones that are not ArrayQ, which is the
   nativelyContractibleQ rule ArrayContract applies to the operands of a node it
   is given.  It is applied here as well, one pass earlier, because an operand
   reaches EVERY step and not only the contraction: a broadcast, a merge and a
   reshape are handed it as it stands, and a wrapper is no more an array to them
   than it is to TensorProduct.  A SparseArray and a packed List are ArrayQ and
   reach the steps with their container intact, which is the whole reason
   execution goes through these primitives.

   A TabularColumn is ArrayQ and passes that rule, and it is materialized all
   the same.  It is rank 1 by construction, so a broadcast, a split or any other
   step that raises the rank has no TabularColumn to hand back, while a merge
   that keeps the rank does - and the container a caller got would then depend
   on which steps the descriptor happened to emit.  opaqueWrapperQ is this
   paclet's own name for a wrapper with no native structural support, and it
   holds for every admitted wrapper except QuantityArray, whose unit the
   executor lifts below and whose container is therefore rebuildable at any
   rank.

   A lazy or a symbolic operand is passed on as it is, since the steps keep it
   lazy or inert.  A DEFERRED TREE - a structural tree whose leaves are all
   explicit, which a tensor-network contraction hands back unactivated - is
   materialized: it has a value and merely defers computing it, and its tier
   reads Lazy with no head to rebuild through, so a step would otherwise expand
   it per scalar. *)

indexNativeOperand[a_ ? opaqueWrapperQ] := ArrayMaterialize[a]

indexNativeOperand[a_ ? deferredTreeQ] := ArrayMaterialize[a]

indexNativeOperand[a_] := If[! ArrayExplicitQ[a] || ArrayQ[a], a, ArrayMaterialize[a]]

(* === units are carried, not computed ===

   A QuantityArray is the one wrapper container that reaches a step, and the
   primitives disagree about it.  TensorContract keeps it and Times keeps it
   against another QuantityArray, but TensorProduct has no evaluation on the
   head at all and Times has none against a plain array, so a broadcast or a
   merge dropped the unit into the elements: a matrix product came back a
   QuantityArray and the batch form of the same descriptor came back a list of
   Quantity, and the container a caller got depended on which steps were
   emitted rather than on what was handed in.

   Repairing that per step would be one wrapper rule per primitive.  The
   descriptor-wide fact is stronger and needs one: with the sum-of-products
   combiner the plan is MULTILINEAR in its operands - a reshape, a transpose and
   a broadcast against ones are linear, a merge multiplies registers holding
   disjoint operands, and a contraction sums products - and registers 1..n are
   read once each, so the result scales by each operand's unit exactly once and
   no step depends on the units at all.  The unit is therefore lifted off the
   operands, the steps run on the magnitudes, which are the packed data the
   wrapper stores and cheaper to compute with than the Quantity elements the
   dropped wrapper produced, and the product of the units goes back on the
   result.  The plan expression is unchanged and still what runs; what it runs
   on is the magnitudes.

   The product is formed by multiplying unit QUANTITIES rather than by rewriting
   unit expressions, so the kernel decides what Meters times Meters is, and a
   product of units that cancels is a plain number that scales the result and
   leaves it unwrapped.  A rank-0 result takes the same scaling and becomes an
   ordinary Quantity, there being no rank-0 QuantityArray.

   A QuantityArray may also carry a unit PER COLUMN, and then there is no single
   unit to lift: one such operand disables the lift for the whole set, every
   QuantityArray goes to the steps as the array of its elements, and the
   elements carry their own units.  The elements and not the wrapper, because a
   contraction sums: a product of different units summed with a zero of another
   is no quantity, and the array of elements is what the contraction can take
   without adding across units it never pairs. *)

indexOperandUnit[a_QuantityArray] := a["UnitBlock"]

indexOperandUnit[_] := None

indexUnitsOff[operands_List] := With[{units = Map[indexOperandUnit, operands]},
    If[ MemberQ[units, _List],
        {Replace[operands, q_QuantityArray :> Normal[q], {1}], {}},
        {MapThread[If[#2 === None, #1, QuantityMagnitude[#1]] &, {operands, units}], DeleteCases[units, None]}
    ]
]

indexUnitsOn[result_, {}] := result

indexUnitsOn[result_, units_List] := With[{scale = Times @@ Map[Quantity[1, #] &, units]},
    If[ MatchQ[scale, _Quantity] && ArrayDimensions[result] =!= {},
        QuantityArray[result, QuantityUnit[scale]],
        scale * result
    ]
]


(* The arity and dimension refusals name ArrayIndexPlan rather than the
   executing symbol, because the mismatch is between the operands and the
   descriptor's input shapes and that is where the fix belongs.

   The dimensions are checked as well as the count, and that check is what makes
   a PREPARED plan safe to hand around.  A plan's steps carry the extents they
   were solved for - a reshape names its dimensions, a broadcast names its sizes
   - so executing one against operands of other dimensions does not fail, it
   quietly lowers to a different array.  A plan built by an executor is solved
   against the very operands it is about to run on and passes this trivially;
   one built by ArrayIndexPlan and reused is exactly where the check earns
   itself. *)

indexExecutePlan[plan_Association, arrays_List] := Module[{operands, units},
    If[ Length[arrays] =!= Length[plan["InputDimensions"]],
        indexFail[
            ArrayIndexPlan,
            "operands",
            {Length[arrays], Length[plan["InputDimensions"]]},
            <|"Operands" -> Length[arrays], "InputShapes" -> Length[plan["InputDimensions"]]|>
        ]
    ];
    operands = Map[indexNativeOperand, unwrapArrayObjects[arrays]];
    Do[
        With[{dims = indexOperandDimensions[operands[[k]]], planned = plan["InputDimensions"][[k]]},
            If[ dims =!= planned,
                indexFail[
                    ArrayIndexPlan,
                    "dimensions",
                    {k, dims, planned},
                    <|"Operand" -> k, "Dimensions" -> dims, "PlanDimensions" -> planned|>
                ]
            ]
        ],
        {k, Length[operands]}
    ];
    {operands, units} = indexUnitsOff[operands];
    (* The operands are handed to the plan's own Function, which is the value
       the "Expression" property renders and this is the application it names.  A
       Function does not rescan what it substitutes, so an operand that itself
       carries a Slot is left alone; it also takes any number of arguments
       silently, which is why the count check above stands in front rather than
       here - too few operands would leave a slot standing in the result. *)
    indexUnitsOn[indexPlanExpression[plan] @@ operands, units]
]
