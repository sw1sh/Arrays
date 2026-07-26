Package["Wolfram`Arrays`"]

PackageExport[ArrayDeclareShape]

(* === the lazy-head registry ===

   The lazy tier is head-driven: a lazy container is an inert expression whose
   head chain terminates in one registered symbol, and everything the rest of
   the paclet needs to know about that head lives in ONE registration here -
   recognition, shape, materialization, substitution and the lazy-preserving
   structural rebuild.  Admitting a head later is one RegisterLazyHead call in
   this file, not an edit in Classification.wl, Shape.wl, Accessors.wl,
   Structural.wl and Vector.wl; those five files dispatch only through the
   generic entry points below and never name a lazy head.

   The registry is deliberately PackageScope, not exported: a head admitted
   from outside would have to be trusted to keep the whole per-head contract
   (an inert form that Part, Map and Dimensions must never be allowed to reach,
   a shape probe that does not materialize, a substitution that is exactly one
   whole-array evaluation), and there is no way to check that from a
   registration.  The one piece of the protocol a CALLER does have to supply -
   the shape of a Function whose body defeats both probes - is exported, as
   ArrayDeclareShape.

   Nothing here is spliced into a definition left-hand side, so this file has no
   load-order dependency on any other: the registry is read at call time, never
   at definition time. *)

PackageScope[RegisterLazyHead]
PackageScope[lazyContainerQ]
PackageScope[lazyDimensions]
PackageScope[lazyMaterialize]
PackageScope[lazySubstitute]
PackageScope[lazyRebuild]
PackageScope[lazyRebuildableQ]
PackageScope[lazyStructuralOp]
PackageScope[lazyDeclarableQ]
PackageScope[scopedReplaceAll]


ArrayDeclareShape::usage = "ArrayDeclareShape[f, dims] declares dims as the shape of the lazy container f, for the case where shape discovery has no probe or gets it wrong: it is the third step of the Function shape protocol and is consulted BEFORE the formal-symbol probe and the numeric probe, so it both corrects a probed shape and keeps the probes - which evaluate the body of f - from running at all.\nArrayDeclareShape[f] gives the declared shape of f, or Missing[\"NotDeclared\"].\nArrayDeclareShape[f, None] removes the declaration and the memoized probe result, so the shape of f is probed afresh.\nArrayDeclareShape[All, None] removes every declaration and every memoized probe result.\nOnly a lazy head that consults caller declarations accepts one; today that is an unapplied Function."

ArrayDeclareShape::baddims = "`1` is not a list of positive integers or None."

ArrayDeclareShape::undeclarable = "`1` does not consult a caller-declared shape; only a lazy head that registers one does, today an unapplied Function of a supported form."


(* === registration and dispatch === *)

(* Handler keys, all optional except the first two:

     "ContainerQ"  expr -> True if expr is a lazy container of this head
     "Dimensions"  expr -> the shape of expr, or {}
     "Materialize" expr -> an explicit array of scalar expressions
                           (default: an Indexed expansion, see below)
     "Substitute"  {expr, rules} -> the substituted expression
                           (default: ReplaceAll, one whole-array evaluation)
     "Rebuild"     {g, expr} -> a lazy container for g applied to the array,
                           or a Missing when this head has no sound rebuild
                           for that g; an ABSENT key declares that the head has
                           no lazy-preserving rebuild at all, and the
                           structural ops then materialize.
     "BoundForm"   True if the inert form of this head BINDS its parameters, so
                           that a plain ReplaceAll on any expression CARRYING one
                           would rewrite the binder instead of substituting
                           through it; every substitution in the paclet then
                           routes such a subexpression through "Substitute", at
                           container level and inside explicit containers alike
                           (see scopedReplaceAll).
     "DeclarableQ" expr -> True if this head consults a caller-declared shape;
                           an ABSENT key declines every ArrayDeclareShape
                           declaration for the head, so a declaration that
                           could never be read is refused with a message
                           instead of being recorded as a silent no-op. *)

$lazyRegistry = <||>

RegisterLazyHead[head_Symbol, handlers_Association] := ($lazyRegistry[head] = handlers;)

(* Head resolution walks Head-wards to the Symbol that every expression's head
   chain terminates in, which is what makes the same registration serve every
   arity of a curried head: InterpolatingFunction[data][t] -> ...[data] ->
   InterpolatingFunction, and ParametricFunction[data][a][t] takes one step
   more.  An unregistered head answers False after one or two Head calls, so
   putting a registry probe in front of the generic ArrayDimensions clause
   costs a Head walk on a plain List, not a scan of its elements. *)

lazyHeadSymbol[h_Symbol] := h

lazyHeadSymbol[expr_] := lazyHeadSymbol[Head[expr]]


lazyHandler[expr_, key_] := Lookup[Lookup[$lazyRegistry, lazyHeadSymbol[expr], <||>], key, Missing["NotRegistered"]]


lazyContainerQ[expr_] := With[{handler = lazyHandler[expr, "ContainerQ"]},
    ! MissingQ[handler] && TrueQ[handler[expr]]
]


lazyDimensions[expr_] := With[{handler = lazyHandler[expr, "Dimensions"]},
    If[MissingQ[handler], {}, Replace[handler[expr], Except[{___Integer}] :> {}]]
]


(* The default materialization indexes the whole lazy expression per position.
   It is the honest answer for a head with no per-scalar form: every element is
   a scalar expression that substitutes to the right value, at the cost of one
   whole-array evaluation per element instead of one for the array.  A head that
   CAN expand per scalar (InterpolatingFunction reinterpolates, Piecewise and
   Function thread through their branches and bodies) registers "Materialize"
   and never reaches this. *)

indexedMaterialize[expr_] := With[{dims = lazyDimensions[expr]},
    MapIndexed[Indexed[expr, #2] &, ConstantArray[0, dims], {Length[dims]}]
]


lazyMaterialize[expr_] := With[{handler = lazyHandler[expr, "Materialize"]},
    If[MissingQ[handler], indexedMaterialize[expr], handler[expr]]
]


lazySubstitute[expr_, rules_] := With[{handler = lazyHandler[expr, "Substitute"]},
    If[MissingQ[handler], ReplaceAll[expr, rules], handler[expr, rules]]
]


lazyRebuildableQ[expr_] := ! MissingQ[lazyHandler[expr, "Rebuild"]]


lazyRebuild[g_, expr_] := With[{handler = lazyHandler[expr, "Rebuild"]},
    If[MissingQ[handler], Missing["NoRebuild"], handler[g, expr]]
]


lazyDeclarableQ[expr_] := With[{handler = lazyHandler[expr, "DeclarableQ"]},
    ! MissingQ[handler] && TrueQ[handler[expr]]
]


(* The shared shape of every structural op on a lazy container: rebuild and stay
   lazy where the head has a sound rebuild, materialize and apply g where it has
   none.  Laziness is never dropped silently - a head without a rebuild says so
   by omitting the key, and the op documents that it materializes. *)

lazyStructuralOp[g_, expr_] := Replace[lazyRebuild[g, expr], _Missing :> g[ArrayMaterialize[expr]]]


(* === scope-safe substitution ===

   A rule specification can arrive as a bare rule, a list of rules, a Dispatch
   table or an Association, and the bound-versus-free analysis of a Function's
   parameters has to see through all four: an unrecognized wrapper counts as zero
   bound parameters and sends a rule keyed on a parameter down the rewriting
   branch, which is the one thing this head exists to avoid.  Normalization is
   one level deep by design - a Dispatch nested inside the right-hand side of a
   rule is data, not a rule specification.

   Plain ReplaceAll is not scope-safe on an expression that CARRIES an unapplied
   Function, and the per-scalar expansion of a Function container is exactly an
   array of such forms: a rule keyed on the parameter would rewrite the parameter
   SPECIFICATION - Function[0.37, Cos[0.37]], which the kernel rejects with
   Function::flpar - instead of applying the closure, and there would be no route
   back to a value.  Substitution therefore scans with the bound-parameter rule
   FIRST at every subexpression, so a Function node is substituted through the
   registry and the scan does not descend into what that returns, while
   everything else takes the caller's rules unchanged.  The FreeQ test keeps the
   common case, an array with no bound-parameter form anywhere in it, on the
   plain ReplaceAll path. *)

normalizeRule[d_Dispatch] := Normal[d]

normalizeRule[a_Association] := Normal[a]

normalizeRule[rules_] := rules

normalizeRules[rules_] := Flatten[{normalizeRule[rules]}]


(* The heads to watch for come from the registry, not from this definition: a
   head declares its inert form to be a binder with "BoundForm" and its
   substitution with "Substitute", and gets both the container-level and the
   carried-scalar treatment from that one registration. *)

boundFormPattern[] := Alternatives @@ Map[Blank, Keys[Select[$lazyRegistry, TrueQ[Lookup[#, "BoundForm", False]] &]]]

scopedReplaceAll[expr_, rules_] := With[{pattern = boundFormPattern[]},
    If[ FreeQ[expr, pattern],
        ReplaceAll[expr, rules],
        ReplaceAll[expr, Prepend[normalizeRules[rules], b : pattern :> lazySubstitute[b, rules]]]
    ]
]


(* === caller-declared shapes ===

   Two per-expression tables, both keyed on the container itself: what the caller
   declared, and what a head's shape probe discovered.  A declaration is
   consulted BEFORE a probe (see functionShape), which makes it an override
   rather than only a fallback - a probe can guess a shape that is merely stale
   or, for a branchy body, simply wrong, and the caller needs a way to say so.
   Declaring a shape also means the probe never runs, which is the only way to
   ask a Function for its shape without evaluating its body.

   A declaration is refused for an expression whose head does not consult one:
   recorded silently it would read as a success and change nothing.  The probe
   memo is invalidated with the declaration, so ArrayDeclareShape[f, None]
   re-probes and ArrayDeclareShape[All, None] resets the whole tier - without
   which a wrong probe would be frozen in for the session and the memo would
   only ever grow. *)

$declaredShapes = <||>

$probedShapes = <||>

declaredShape[expr_] := Replace[Lookup[$declaredShapes, Key[expr], {}], Except[{__Integer}] :> {}]

forgetProbedShape[expr_] := ($probedShapes = KeyDrop[$probedShapes, Key[expr]];)

ArrayDeclareShape[All, None] := ($declaredShapes = <||>; $probedShapes = <||>; None)

ArrayDeclareShape[expr_ ? lazyDeclarableQ, dims : {__Integer ? Positive}] := (
    $declaredShapes[expr] = dims;
    forgetProbedShape[expr];
    dims
)

ArrayDeclareShape[expr_ ? lazyDeclarableQ, None] := (
    $declaredShapes = KeyDrop[$declaredShapes, Key[expr]];
    forgetProbedShape[expr];
    None
)

ArrayDeclareShape[expr_] := Lookup[$declaredShapes, Key[expr], Missing["NotDeclared"]]

ArrayDeclareShape[_, dims_] /; ! MatchQ[dims, {__Integer ? Positive} | None] && (Message[ArrayDeclareShape::baddims, dims]; False) := Null

ArrayDeclareShape[expr_, dims_] /; MatchQ[dims, {__Integer ? Positive} | None] && ! lazyDeclarableQ[expr] &&
    (Message[ArrayDeclareShape::undeclarable, expr]; False) := Null


(* === InterpolatingFunction: the reference implementation ===

   Shape is free from Head[expr]["OutputDimensions"]; the applied form is inert
   on any non-numeric argument (the trigger is NumericQ, so Pi and 1/2 do NOT
   stay lazy - a documented contract, not a bug); one substitution is one packed
   whole-array evaluation.  A derivative ifn' is itself an InterpolatingFunction
   in 15.0, so Derivative[__][ifn][t] never survives as an inert form and needs
   no separate recognition pattern. *)

interpolatingContainerQ[(f_InterpolatingFunction)[args__]] := f["OutputDimensions"] =!= {} && ! AllTrue[{args}, NumericQ]

interpolatingContainerQ[_] := False


interpolatingDimensions[(f_InterpolatingFunction)[__]] := Replace[f["OutputDimensions"], Except[_List] :> {}]

interpolatingDimensions[_] := {}


(* Per-scalar expansion of a single-parameter array-valued InterpolatingFunction
   application, ported from the QuantumFramework ExpandInterpolatingFunction. *)

interpolatingMaterialize[(f_InterpolatingFunction)[parameter_]] := Map[
    Interpolation[Thread[{f["Grid"], #}], InterpolationOrder -> f["InterpolationOrder"]][parameter] &,
    Transpose[f["ValuesOnGrid"], InversePermutation[Cycles[{Range[Length[f["OutputDimensions"]] + 1]}]]],
    {-2}
]

interpolatingMaterialize[expr_] := indexedMaterialize[expr]


(* The lazy-preserving rebuild transforms the value array at every grid point
   and reinterpolates.  It declines - and the caller then leaves its operation
   unevaluated rather than guessing - when g takes the grid values out of the
   numeric domain, because an Interpolation over non-numeric values is not an
   InterpolatingFunction at all. *)

interpolatingRebuild[g_, (f_InterpolatingFunction)[parameter_]] := Module[{values = Quiet[Map[g, f["ValuesOnGrid"]]]},
    If[ ArrayQ[values, _, NumericQ],
        Interpolation[Thread[{f["Grid"], values}], InterpolationOrder -> f["InterpolationOrder"]][parameter],
        Missing["NotRebuildable"]
    ]
]

interpolatingRebuild[_, _] := Missing["NotRebuildable"]


RegisterLazyHead[InterpolatingFunction, <|
    "ContainerQ" -> interpolatingContainerQ,
    "Dimensions" -> interpolatingDimensions,
    "Materialize" -> interpolatingMaterialize,
    "Rebuild" -> interpolatingRebuild
|>]


(* === ParametricFunction ===

   Three arities exist - the bare object pf, the partially applied pf[params],
   and the fully applied pf[params][t] - and only the LAST is an array
   container.  The criterion is the one the whole paclet is written against: a
   shape that is introspectable without materializing AND a materialization
   path.  Substituting every parameter of pf[params][t] is one whole-array solve
   and interpolation evaluation returning a packed array; substituting every
   parameter of pf[params] returns an InterpolatingFunction, which is a
   function, not an array, and the bare pf has nothing bound at all.  This is
   exactly why the bare InterpolatingFunction is not a container either while
   ifn[t] is, so the two heads stay consistent.  ArrayObject's Kind is derived
   from the head chain, so all three arities report "ParametricFunction"; only
   the applied one is admitted, and the other two are declined by
   ArrayContainerQ with the usual message.

   The object has no shape property (Dimensions[pf] reports internal expression
   parts), so the shape comes from ONE probe solve at a random parameter point
   and is cached per object: the kernel caches parameter solves internally, but
   caching here keeps ArrayDimensions from entering the solver at all after the
   first call.  Only a successful probe is cached, so a probe that fails because
   the random point was outside the parameter domain is not frozen in. *)

parametricParameterCount[pf_ParametricFunction] := parametricParameterCount[pf] =
    Replace[Quiet[pf["Parameters"]], {l_List :> Length[l], _ :> 0}]


parametricProbe[pf_ParametricFunction] := With[{n = parametricParameterCount[pf]},
    If[ n < 1,
        {},
        Replace[
            Quiet[Check[pf @@ RandomReal[{0, 1}, n], $Failed]],
            {
                (f_InterpolatingFunction) :> Replace[f["OutputDimensions"], Except[{__Integer}] :> {}],
                _ :> {}
            }
        ]
    ]
]


parametricShape[pf_ParametricFunction] := With[{dims = parametricProbe[pf]},
    If[dims === {}, {}, parametricShape[pf] = dims]
]


parametricContainerQ[(pf_ParametricFunction)[params__][arg_]] :=
    Length[{params}] === parametricParameterCount[pf] &&
        parametricShape[pf] =!= {} &&
        ! AllTrue[{params, arg}, NumericQ]

parametricContainerQ[_] := False


parametricDimensions[(pf_ParametricFunction)[__][_]] := parametricShape[pf]

parametricDimensions[_] := {}


(* No "Rebuild": a ParametricFunction carries no value grid to remap and no
   body to compose, and wrapping the inert form in Transpose would produce an
   expression whose head is Transpose - not a lazy container at all.  The
   structural ops therefore materialize, which for this head is the Indexed
   expansion: correct under substitution, one whole-array evaluation per element
   instead of one for the array. *)

RegisterLazyHead[ParametricFunction, <|
    "ContainerQ" -> parametricContainerQ,
    "Dimensions" -> parametricDimensions
|>]


(* === unapplied Function ===

   A Function is NOT inert under application - f[t] expands immediately - so the
   container is the UNAPPLIED Function and its parameter is a bound variable,
   not a free symbol.  That makes substitution the one place this head differs
   from every other: a rule keyed on a bound parameter is an APPLICATION (one
   closure call, one whole array, repacked), a rule keyed on SOME of several
   parameters curries, and the remaining rules rewrite the free symbols of the
   body and keep the container lazy.  A plain ReplaceAll would instead rewrite
   the parameter specification itself and produce Function[0.5, ...], which the
   kernel rejects with Function::flpar.

   Shape discovery has no property, so it is the three-step protocol: a caller
   declaration through ArrayDeclareShape, which is consulted first and is
   therefore both the correction for a wrong probe and the way to avoid probing
   at all; a formal-symbol probe, which settles every dimension-transparent
   body; and a numeric probe at a random interior point, which settles the If
   bodies the formal probe leaves as an unevaluated If.  When all three fail the
   value is NOT a container - no shape is guessed.  ArrayQ and a positive-shape
   test guard both probes, because Dimensions on an unevaluated If body reports
   the argument count and an empty probe value has a zero dimension.

   RECOGNITION EVALUATES THE BODY.  Both probes apply f, so asking a predicate
   whether a Function is a container runs the function once - at formal symbols,
   and if that leaves no array, at a random point in {0, 1}.  A successful probe
   is memoized, and a declared shape short-circuits both probes, but a Function
   with side effects or an expensive body should be declared, not probed.

   Supported forms are the named ones, Function[x, body] and
   Function[{x, ...}, body], and the slot form Function[body]; a slot form has
   no addressable parameter, so rules only reach its body, and a rebuild
   normalizes it to a formal-variable named form (which is strictly more
   substitutable than what it replaces).  A three-argument Function carries
   attributes that a rebuild could not preserve and is declined. *)

$formalVariables = {\[FormalT], \[FormalU], \[FormalV], \[FormalW], \[FormalX], \[FormalY], \[FormalZ]}

functionSlotFormQ[f_Function] := Length[f] === 1

functionArity[f_Function] := If[
    functionSlotFormQ[f],
    Max[1, Cases[f, Slot[n_Integer] :> n, {0, Infinity}]],
    Replace[Extract[f, 1, Hold], {Hold[l_List] :> Length[l], _ :> 1}]
]

functionVariables[f_Function] := If[
    functionSlotFormQ[f],
    {},
    Replace[Extract[f, 1, Hold], {Hold[l_List] :> l, Hold[v_] :> {v}}]
]

functionSupportedQ[f_Function] := Length[f] <= 2 && FreeQ[f, _SlotSequence] &&
    (functionSlotFormQ[f] || MatchQ[Extract[f, 1, Hold], Hold[_Symbol] | Hold[{__Symbol}]]) &&
    functionArity[f] <= Length[$formalVariables]

functionSupportedQ[_] := False


(* The body under the container's own parameters: the declared symbols for a
   named form, formal variables for a slot form.  Materialization and rebuild
   both re-wrap this body, so the parameters they write into the wrapper are the
   same ones the body mentions. *)

functionBody[f_Function] := If[
    functionSlotFormQ[f],
    f @@ Take[$formalVariables, functionArity[f]],
    f @@ functionVariables[f]
]

(* Extract with Hold keeps a parameter specification unevaluated on its way into
   the new wrapper; Function is HoldAll, so the body it receives is not
   re-evaluated either. *)

functionRewrap[f_Function, body_] := If[
    functionSlotFormQ[f],
    Function @@ {Take[$formalVariables, functionArity[f]], body},
    Function @@ Append[Extract[f, 1, Hold], body]
]


(* Probes are thunks so that the numeric one is never run when the formal one
   has already settled the shape.

   A probe settles the shape only when its value is an array of a POSITIVE
   shape, the same shape a caller is allowed to declare.  ArrayQ[{}] is True and
   Dimensions[{}] is {0}, so a body that degenerates to an empty list at the
   probe point - Table[1., {t}] at t = 0.63 runs zero iterations - would
   otherwise be admitted as a rank-1 container of length 0, a wrong shape that
   propagates into ArrayRank, into the ConstantArray of the Indexed expansion and
   into Table::iterb messages at the caller. *)

probeShapeQ[dims_] := MatchQ[dims, {__Integer ? Positive}]

firstArrayShape[{}] := {}

firstArrayShape[{probe_, rest___}] := With[{value = probe[]},
    If[ArrayQ[value] && probeShapeQ[Dimensions[value]], Dimensions[value], firstArrayShape[{rest}]]
]

functionProbeShape[f_Function] := If[
    functionSupportedQ[f],
    firstArrayShape[{
        Function[Quiet[Check[f @@ Take[$formalVariables, functionArity[f]], $Failed]]],
        Function[Quiet[Check[f @@ RandomReal[{0, 1}, functionArity[f]], $Failed]]]
    }],
    {}
]

functionProbeShape[_] := {}


(* Only a successful probe is memoized, so a Function whose shape becomes
   discoverable later is not frozen out, and the memo is a table rather than a
   definition so that ArrayDeclareShape can drop one entry or all of them.

   A caller declaration is consulted FIRST.  A probed shape is a guess: it is
   memoized for a Function whose body closes over outer state that can change
   under it, and the numeric probe reads one branch of a branchy body.  The
   declaration is therefore an override - the correction a caller can actually
   make - and, since the probes evaluate the body of f, declaring the shape is
   also the way to keep them from running. *)

probedFunctionShape[f_Function] := If[
    KeyExistsQ[$probedShapes, f],
    Lookup[$probedShapes, Key[f], {}],
    With[{dims = functionProbeShape[f]}, If[probeShapeQ[dims], $probedShapes[f] = dims, {}]]
]

functionShape[f_Function] := Replace[declaredShape[f], {} :> probedFunctionShape[f]]

functionShape[_] := {}


functionContainerQ[f_Function] := functionSupportedQ[f] && functionShape[f] =!= {}

functionContainerQ[_] := False


functionDimensions[f_Function] := functionShape[f]

functionDimensions[_] := {}


(* Materialization gives an array of scalar Functions of the same parameters:
   the container is unapplied, so its elements are unapplied too.

   The body is only mapped over when it IS an explicit array of the container's
   shape.  For a declared shape - the case ArrayDeclareShape exists for, a body
   that stays an unevaluated If - it is not: mapping would thread over the
   ARGUMENTS of the If and hand back an If of Functions that is not an array at
   all.  Such a body is indexed instead, one Indexed per position, which is again
   a scalar Function of the same parameters and collapses to the right value the
   moment the parameter is bound. *)

functionMaterialize[f_Function] := With[{dims = functionShape[f], body = functionBody[f]},
    If[ ArrayQ[body] && Dimensions[body] === dims,
        Map[functionRewrap[f, #] &, body, {Length[dims]}],
        MapIndexed[functionRewrap[f, Indexed[body, #2]] &, ConstantArray[0, dims], {Length[dims]}]
    ]
]

functionMaterialize[expr_] := indexedMaterialize[expr]


(* Composition is the sound analogue of the InterpolatingFunction grid remap:
   there is no grid to transform, so the transformed body is re-abstracted over
   the same parameters.  It needs the same explicit-array guard as
   materialization: g applied to a body that is an unevaluated If threads over
   the branches instead of the elements, so a declared-shape Function declines
   the rebuild and its structural ops go through the per-scalar expansion. *)

functionRebuild[g_, f_Function] := With[{body = functionBody[f]},
    If[ ArrayQ[body] && Dimensions[body] === functionShape[f],
        With[{rebuilt = Quiet[g[body]]},
            If[ArrayQ[rebuilt], functionRewrap[f, rebuilt], Missing["NotRebuildable"]]
        ],
        Missing["NotRebuildable"]
    ]
]

functionRebuild[_, _] := Missing["NotRebuildable"]


boundRulePattern[vars_] := HoldPattern[Rule | RuleDelayed][Alternatives @@ vars, _]

(* Re-abstraction over the parameters a substitution left unbound.  Function is
   HoldAll, so the body written into the new wrapper is not re-evaluated, and the
   parameters are the container's own, so nothing is renamed or captured. *)

functionCurry[vars_List, body_] := Function @@ {vars, body}

functionSubstitute[f_Function, rules_] := Module[{vars, all, bound, free, boundVars, restVars},
    vars = functionVariables[f];
    all = normalizeRules[rules];
    bound = Cases[all, boundRulePattern[vars]];
    free = DeleteCases[all, boundRulePattern[vars]];
    boundVars = Union[Cases[bound, HoldPattern[Rule | RuleDelayed][v_, _] :> v]];
    Which[
        vars =!= {} && Length[boundVars] === Length[vars],
        (* Every parameter is bound: one closure call for the whole array.  The
           output of a Function is unpacked, so it is repacked here; the
           remaining free rules apply to the explicit result. *)
        ArrayPack[ReplaceAll[f @@ (vars /. bound), free]],

        boundVars =!= {},
        (* SOME parameters are bound: the container curries rather than applies.
           The bound arguments go into the body and the result is re-abstracted
           over the parameters that are still free, so a caller sweeping one
           parameter at a time gets a smaller container back instead of - as a
           free-rules-only branch would give - the original container with the
           binding silently dropped. *)
        restVars = DeleteCases[vars, Alternatives @@ boundVars];
        functionCurry[restVars, ReplaceAll[functionBody[f], Join[bound, free]]],

        True,
        (* ReplaceAll on the container itself is scope-safe here because the
           rules that could capture a parameter have been removed, and Function
           is HoldAll so the rewritten body is not evaluated. *)
        ReplaceAll[f, free]
    ]
]

functionSubstitute[expr_, rules_] := ReplaceAll[expr, rules]


RegisterLazyHead[Function, <|
    "ContainerQ" -> functionContainerQ,
    "Dimensions" -> functionDimensions,
    "Materialize" -> functionMaterialize,
    "Substitute" -> functionSubstitute,
    "Rebuild" -> functionRebuild,
    "BoundForm" -> True,
    "DeclarableQ" -> functionSupportedQ
|>]


(* === array-valued Piecewise ===

   KERNEL CONTRADICTS THE SURVEY: Dimensions does NOT thread through the
   branches of an unevaluated array-valued Piecewise in 15.0.  It reports the
   argument count - {2} for every Piecewise, since the kernel normalizes a
   one-argument Piecewise to Piecewise[pairs, default] - exactly the
   expression-tree reading that the container layer exists to intercept.  The
   shape is still free without materializing, but it comes from the branch
   values themselves: every branch value and the default must be an array, and
   all of them must have the same dimensions.

   Requiring the default to be an array too is deliberate.  Piecewise supplies a
   scalar 0 default when the caller gives only branches, and admitting that form
   would make a substitution that falls through every condition return the
   scalar 0 instead of an array - a container whose materialization is not an
   array of the declared shape.

   A Piecewise survives evaluation exactly when at least one condition is
   undecidable, so no separate non-numeric-argument test is needed: an
   all-decidable Piecewise has already collapsed to its branch value.  The
   implementation does not require the conditions to mention exactly one
   variable; recognition, shape and the rebuild are all variable-count
   independent, and a multi-variable Piecewise behaves identically. *)

(* HoldPattern is load-time hygiene, not decoration: an assignment evaluates the
   arguments of its left-hand side, and a bare Piecewise[pairs : {{_, _} ..},
   default_] there is an argument-checked Piecewise call that emits
   Piecewise::pairs for the PATTERN while the paclet loads. *)

piecewiseValues[HoldPattern[Piecewise[pairs : {{_, _} ..}, default_]]] := Append[pairs[[All, 1]], default]

piecewiseValues[_] := {}


piecewiseShape[expr_Piecewise] := With[{values = piecewiseValues[expr]},
    If[ values =!= {} && AllTrue[values, ArrayQ] && SameQ @@ Map[Dimensions, values],
        Dimensions[First[values]],
        {}
    ]
]

piecewiseShape[_] := {}


piecewiseContainerQ[expr_Piecewise] := piecewiseShape[expr] =!= {}

piecewiseContainerQ[_] := False


piecewiseDimensions[expr_Piecewise] := piecewiseShape[expr]

piecewiseDimensions[_] := {}


(* Per-scalar expansion threads the branch structure through every position: the
   result is an array of scalar Piecewise expressions, each with the same
   conditions.  The default array supplies the traversal shape. *)

piecewiseMaterialize[expr : HoldPattern[Piecewise[pairs_, default_]]] := With[{dims = piecewiseShape[expr]},
    MapIndexed[
        Function[{value, position},
            Piecewise[MapAt[Extract[#, position] &, pairs, {All, 1}], Extract[default, position]]
        ],
        default,
        {Length[dims]}
    ]
]

piecewiseMaterialize[expr_] := indexedMaterialize[expr]


(* Transforming every branch value and the default keeps the conditions, hence
   the laziness, intact. *)

piecewiseRebuild[g_, HoldPattern[Piecewise[pairs_, default_]]] := With[{
        rebuilt = Quiet[Piecewise[MapAt[g, pairs, {All, 1}], g[default]]]
    },
    If[piecewiseShape[rebuilt] =!= {}, rebuilt, Missing["NotRebuildable"]]
]

piecewiseRebuild[_, _] := Missing["NotRebuildable"]


RegisterLazyHead[Piecewise, <|
    "ContainerQ" -> piecewiseContainerQ,
    "Dimensions" -> piecewiseDimensions,
    "Materialize" -> piecewiseMaterialize,
    "Rebuild" -> piecewiseRebuild
|>]


(* === source NetGraph and NetChain ===

   A net meets the criterion the whole paclet is written against: the shape is
   introspectable without evaluating anything - NetExtract[net, "Output"] reads
   the output port off the net's own type signature - and the materialization is
   one call, net[].  The SOURCE distinction is the admission gate: a net with
   open input ports is a function of those inputs and has no array value at all,
   so it is declined, exactly as the bare ParametricFunction is.  A rank-0
   output port reports a type name rather than a dimension list and is declined
   too, for the same reason a rank-0 anything is not a container.

   NO "Rebuild": a structural op would have to be lowered into layers, and
   TransposeLayer is a documented trap there - PermutationList without an
   explicit length truncates a permutation that fixes trailing levels, so a
   permutation built from it is silently partial.  Omitting the key is how a
   head says it has none, and the structural ops then materialize-then-operate,
   which is the sound default.  Nothing else in the paclet needs an edit: the
   registry is the single point where a head is admitted. *)

netOutputDimensions[net_] := Replace[
    Quiet[Check[NetExtract[net, "Output"], $Failed]],
    {d_Integer :> {d}, d : {___Integer} :> d, _ :> {}}
]

netSourceQ[net_] := Quiet[Check[Length[Information[net, "InputPorts"]] === 0, False]]

netContainerQ[net : _NetGraph | _NetChain] := netSourceQ[net] && MatchQ[netOutputDimensions[net], {__Integer ? Positive}]

netContainerQ[_] := False


netDimensions[net : _NetGraph | _NetChain] := netOutputDimensions[net]

netDimensions[_] := {}


netMaterialize[net : _NetGraph | _NetChain] := net[]

netMaterialize[expr_] := indexedMaterialize[expr]


RegisterLazyHead[NetGraph, <|
    "ContainerQ" -> netContainerQ,
    "Dimensions" -> netDimensions,
    "Materialize" -> netMaterialize
|>]

RegisterLazyHead[NetChain, <|
    "ContainerQ" -> netContainerQ,
    "Dimensions" -> netDimensions,
    "Materialize" -> netMaterialize
|>]
