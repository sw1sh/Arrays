Package["Wolfram`Arrays`"]

PackageScope[$indexFailed]
PackageScope[indexFail]
PackageScope[catchIndexFailure]

PackageScope[indexAxis]
PackageScope[indexProduct]

PackageScope[indexSurfaceDescriptor]
PackageScope[indexNormalizedDescriptor]
PackageScope[indexNormalizedQ]
PackageScope[indexAxisLabel]
PackageScope[indexFlatTerms]


(* === the refusal protocol ===

   A stage that cannot compile a descriptor throws {sym, tag, args, data} on
   $indexFailTag; the public entry point that wrapped the pipeline in
   catchIndexFailure issues the message and gives $indexFailed, on which the
   entry point's own condition fails and the call is left as written.  One
   scheme, no Failure: the paclet reports every refusal as a message plus an
   untouched expression, and a descriptor that does not compile is a refusal
   rather than a value.

   The tag is file-private on purpose.  A descriptor is a user expression and a
   Throw raised from inside one carries some other tag and passes through
   untouched, where a shared or a string tag would swallow it and report a
   compilation failure that never happened.

   Message TEMPLATES are declared in IndexOperators.wl beside the symbol that
   owns them and are raised from wherever the refusal happens, so the tag names
   the compilation stage the fix belongs to: a grammar refusal reached through
   ArrayIndexContract still messages ArrayIndexPattern::parse.  data carries the
   source reference of the offending fragment for a caller that inspects the
   throw; the boundary itself reads only sym, tag and args. *)

indexFail[sym_Symbol, tag_String, args_List, data_Association] :=
    Throw[{sym, tag, args, data}, $indexFailTag]

SetAttributes[catchIndexFailure, HoldFirst]

catchIndexFailure[expr_] := Catch[expr, $indexFailTag, indexFailMessage]

indexFailMessage[{sym_Symbol, tag_String, args_List, _Association}, _] := (
    Message[MessageName[sym, tag], Sequence @@ args];
    $indexFailed
)


(* === hold discipline ===

   A descriptor arrives EVALUATED - the public symbols do not hold it, and must
   not.  The asymmetry the hygiene rules need is RuleDelayed's own HoldRest: in
   {{a_, k}} :> {{b, a}} the input side has evaluated, so a bound k arrives as
   its value and reads as a literal dimension, while the output side arrives as
   written.  Rule evaluates both sides, which is exactly why -> warns.

   Everything below therefore works on HoldComplete wrappers.  A child is
   re-wrapped with Extract before it is looked at, every Pattern or Blank match
   on a fragment is Verbatim-guarded so that a literal Blank[] in the descriptor
   is matched as DATA, and no traversal uses an anonymous Function: a Slot[...]
   in a descriptor would be reinterpreted as a function slot inside a &. *)

indexShow[held_] := Replace[held, HoldComplete[e_] :> HoldForm[e]]

indexHeldLength[held_] := Replace[held, HoldComplete[e_] :> Length[Unevaluated[e]]]

indexTermFailure[held_] :=
    indexFail[ArrayIndexPattern, "term", {indexShow[held]}, <|"Source" -> held|>]

indexUnsupported[held_] :=
    indexFail[ArrayIndexPattern, "unsupported", {indexShow[held]}, <|"Source" -> held|>]


(* A valid axis name is rolled here rather than taken from a resource function:
   it is one line and the whole grammar depends on it. *)
$indexNamePattern = (LetterCharacter | "$") ~~ (LetterCharacter | DigitCharacter | "$") ...

indexNameQ[s_String] := StringMatchQ[s, $indexNamePattern]


(* === the string dialect ===

   Einx tokenizes by identifier and classic einsum by character, and the two
   disagree about what "ijk" means.  The mode is chosen ONCE, on the raw string,
   before tokenizing: a string containing a space is read by identifier, one
   with no space by character.  So "ij,jk->ik" and "i j, j k -> i k" name the
   same three axes and "b s d, d e -> b s e" keeps multi-character names, with
   no mode flag and no ambiguity in either direction.

   Both modes are TOTAL: every character either produces a token or produces a
   marker that indexTokenize turns into a refusal.  Recognizing the reserved
   spellings "...", "+" and "=" rather than skipping them is the whole point -
   "b ... d" must not quietly become a rank-2 descriptor.

   A token is one of the delimiter strings "(", ")", "[", "]", ",", "->", "_",
   an Integer literal, or a name.  The two kinds of string never collide,
   because a name matches $indexNamePattern and no delimiter does. *)

indexTokenize[s_String] :=
    Module[{tokens, bad},
        tokens =
            If[ StringContainsQ[s, " "],
                StringCases[s, {
                    "..." :> indexReservedToken["..."],
                    "->" -> "->",
                    d : ("(" | ")" | "[" | "]" | ",") :> d,
                    "_" -> "_",
                    r : ("+" | "=") :> indexReservedToken[r],
                    n : DigitCharacter .. :> FromDigits[n],
                    id : $indexNamePattern :> id,
                    WhitespaceCharacter :> Nothing,
                    c : _ :> indexBadToken[c]
                }],
                StringCases[s, {
                    "->" -> "->",
                    c : LetterCharacter :> c,
                    "_" -> "_",
                    "," -> ",",
                    c : _ :> indexBadToken[c]
                }]
            ];
        bad = FirstCase[tokens, _indexBadToken | _indexReservedToken];
        Replace[bad, {
            indexBadToken[c_] :> indexFail[ArrayIndexPattern, "token", {c, s}, <|"Source" -> HoldComplete[s]|>],
            indexReservedToken[c_] :> indexFail[ArrayIndexPattern, "unsupported", {c}, <|"Source" -> HoldComplete[s]|>],
            _ :> tokens
        }]
    ]


indexTokenText[tok_] := If[IntegerQ[tok], ToString[tok], tok]


(* The token run a refusal names, rebuilt the way the caller would have written
   it: a bracket binds to what it encloses, everything else is separated by one
   space.  A refusal quotes source, so it must not invent whitespace the caller
   did not write. *)
indexTokenRun[toks_List] :=
    StringJoin[Table[
        indexTokenText[toks[[k]]] <>
            If[ k === Length[toks] || MatchQ[toks[[k]], "(" | "["] || MatchQ[toks[[k + 1]], ")" | "]"],
                "",
                " "
            ],
        {k, Length[toks]}
    ]]


(* The position of the token closing the group that opens at start, by counting
   depth rather than taking the first closer: a nested spelling - "((a b) c)",
   "[[s]]" - is one group with one end, and a refusal that named it up to the
   INNER closer would quote a fragment the caller did not write.  None when the
   group never closes. *)
indexBalancedEnd[toks_List, start_Integer, open_String, close_String] :=
    Module[{depth = 0, end = None},
        Do[
            Which[
                toks[[k]] === open, depth = depth + 1,
                toks[[k]] === close, depth = depth - 1
            ];
            If[depth === 0, end = k; Break[]],
            {k, start, Length[toks]}
        ];

        end
    ]


(* The string dialect has no expression fragment to hold: a term's source is the
   text the caller wrote.  It is wrapped through a function rather than written
   as HoldComplete[text] directly, so that the map carries the TEXT and not the
   local variable the text is read from. *)
indexHoldToken[text_String] := HoldComplete[text]

indexStringTermFailure[text_String, s_String] :=
    indexFail[ArrayIndexPattern, "term", {text}, <|"Source" -> HoldComplete[s]|>]


(* Segments are split on the "," and "->" TOKENS, so an empty segment is the
   empty shape: "ij->" is a scalar output and ",ij" a scalar operand, neither of
   which a splitter over characters can express. *)
indexSplitSegments[toks_List] :=
    Module[{bounds = Join[{0}, Flatten[Position[toks, ",", {1}, Heads -> False]], {Length[toks] + 1}]},
        Table[Take[toks, {bounds[[k]] + 1, bounds[[k + 1]] - 1}], {k, Length[bounds] - 1}]
    ]


(* One slot is a single token or a parenthesized composite.  A composite does
   not nest: CircleTimes is associative, so "((a b) c)" names the same product
   as "(a b c)" and the nested spelling is declined rather than given a second
   reading. *)
indexReadSlot[toks_List, i_Integer, s_String] :=
    If[ toks[[i]] === "(",
        Module[{close = indexBalancedEnd[toks, i, "(", ")"], members},
            If[ close === None,
                indexFail[ArrayIndexPattern, "parse", {s}, <|"Source" -> HoldComplete[s]|>]
            ];
            members = Take[toks, {i + 1, close - 1}];
            If[ IntersectingQ[members, {"(", "[", "]"}],
                indexStringTermFailure[indexTokenRun[Take[toks, {i, close}]], s]
            ];
            {members, True, close + 1}
        ],
        {{toks[[i]]}, False, i + 1}
    ]


indexSlotText[members_List, groupQ_, target_] :=
    Module[{inner},
        inner =
            If[ groupQ,
                "(" <> StringRiffle[Map[indexTokenText, members], " "] <> ")",
                indexTokenText[First[members]]
            ];
        If[target === None, inner, "[" <> inner <> "]"]
    ]


(* A bracket that names no single slot is reported as the whole bracketed
   fragment, running to the closing "]" or, when there is none, to the end of
   the shape - the caller wrote the bracket, not the token the walk stopped
   on. *)
indexBracketText[toks_List, start_Integer] :=
    With[{close = indexBalancedEnd[toks, start, "[", "]"]},
        indexTokenRun[Take[toks, {start, If[close === None, Length[toks], close]}]]
    ]


(* Every NAMED axis a string dialect produces has kind "String": the dialect has
   no symbol at all, so it has no hygiene question to answer.  A literal, a unit
   and an anonymous axis carry their own kinds here as in every dialect, having
   no name to be spelled one way or another. *)
indexStringTerm[tok_, s_String] :=
    Which[
        tok === "_", indexSurfaceAnonymous[],
        IntegerQ[tok] && Positive[tok], indexSurfaceLiteral[tok],
        StringQ[tok] && indexNameQ[tok], indexSurfaceAxis[tok, "String", None],
        True, indexStringTermFailure[indexTokenText[tok], s]
    ]


(* Bracketing is one target per slot: "[s]" or "[(h c)]".  "[a b]", "[4]" and a
   nested "[[s]]" name no single slot and are declined.  The target head
   recorded is Slot, which is the hygienic target a string axis takes and the
   key an out-of-band binding for one uses. *)
indexParseSegment[toks_List, base_List, s_String] :=
    Module[{i = 1, n = Length[toks], terms = {}, sources = {}, targets = {}, target, bracket, members, groupQ, text, path},
        While[i <= n,
            target = None;
            bracket = i;
            If[ toks[[i]] === "[",
                target = "Slot";
                i = i + 1
            ];
            If[i > n, indexStringTermFailure[indexBracketText[toks, bracket], s]];
            {members, groupQ, i} = indexReadSlot[toks, i, s];
            If[ target =!= None,
                If[i > n || toks[[i]] =!= "]", indexStringTermFailure[indexBracketText[toks, bracket], s]];
                i = i + 1
            ];
            path = Append[base, Length[terms] + 1];
            text = indexSlotText[members, groupQ, target];
            If[ groupQ,
                If[Length[members] < 2, indexStringTermFailure[text, s]];
                terms = Append[terms, indexSurfaceProduct[Table[indexStringTerm[members[[k]], s], {k, Length[members]}]]];
                sources = Join[
                    sources,
                    {path -> indexHoldToken[text]},
                    Table[Append[path, k] -> indexHoldToken[indexTokenText[members[[k]]]], {k, Length[members]}]
                ],
                If[target =!= None && IntegerQ[First[members]], indexStringTermFailure[text, s]];
                terms = Append[terms, indexStringTerm[First[members], s]];
                sources = Join[sources, {path -> indexHoldToken[text]}]
            ];
            If[target =!= None, targets = Append[targets, path -> target]]
        ];
        {terms, sources, targets}
    ]


indexParseString[s_String] :=
    Module[{tokens, arrows, specified, inputSegments, outputSegments, captured, split},
        If[ StringTrim[s] === "",
            indexFail[ArrayIndexPattern, "parse", {s}, <|"Source" -> HoldComplete[s]|>]
        ];
        tokens = indexTokenize[s];
        arrows = Flatten[Position[tokens, "->", {1}, Heads -> False]];
        If[ Length[arrows] > 1,
            indexFail[ArrayIndexPattern, "parse", {s}, <|"Source" -> HoldComplete[s]|>]
        ];
        specified = Length[arrows] === 1;
        inputSegments = indexSplitSegments[If[specified, Take[tokens, First[arrows] - 1], tokens]];
        outputSegments = If[specified, indexSplitSegments[Drop[tokens, First[arrows]]], {}];
        captured = Join[
            Table[indexParseSegment[inputSegments[[k]], {"Inputs", k}, s], {k, Length[inputSegments]}],
            Table[indexParseSegment[outputSegments[[k]], {"Outputs", k}, s], {k, Length[outputSegments]}]
        ];
        split = Length[inputSegments];
        <|
            "Dialect" -> "String",
            "Arrow" -> If[specified, Rule, None],
            "Inputs" -> Map[First, Take[captured, split]],
            "Outputs" -> Map[First, Drop[captured, split]],
            "OutputSpecified" -> specified,
            "Targets" -> Association[Catenate[captured[[All, 3]]]],
            "SourceMap" -> Association[Catenate[captured[[All, 2]]]],
            "Source" -> HoldComplete[s]
        |>
    ]


(* === the Wolfram expression and einsum-list dialects ===

   They are one parser.  "Dialect" is "IndexList" when the arrow was Rule and
   "Expression" otherwise; nothing downstream branches on it, and the
   distinction is kept only so that a pattern object can report the spelling it
   was written in.

   Side normalization, one rule for every dialect: a side is a LIST OF SHAPES
   iff it is a non-empty List every element of which is a List, and is a single
   shape otherwise.  That subsumes both call-site sugars - a bare shape
   {i, j} :> {j, i} is a one-operand descriptor - and settles the {} ambiguity:
   {{i, i}} -> {} and {{i, j}} :> {{}} both give one scalar output shape. *)

indexNormalizeSide[held_] :=
    If[ MatchQ[held, HoldComplete[{__List}]],
        Table[Extract[held, {1, k}, HoldComplete], {k, indexHeldLength[held]}],
        {held}
    ]


(* A term wears at most one target head and at most one inline size, in either
   nesting order, so the two are peeled together and normalized to one pair.
   Slot carries a String only: Slot[b] and Slot[b_] fall through to the term
   dispatch, which declines them and names Highlighted and Framed as the target
   heads a symbol-kind axis takes. *)
indexPeelTerm[held_, target_, size_] :=
    Replace[held, {
        HoldComplete[Slot[s_String]] /; target === None :> indexPeelTerm[HoldComplete[s], "Slot", size],
        HoldComplete[Highlighted[x_]] /; target === None :> indexPeelTerm[HoldComplete[x], "Highlighted", size],
        HoldComplete[Framed[x_]] /; target === None :> indexPeelTerm[HoldComplete[x], "Framed", size],
        HoldComplete[Annotation[x_, n_Integer]] /; size === None && Positive[n] :> indexPeelTerm[HoldComplete[x], target, n],
        HoldComplete[Labeled[n_Integer, x_]] /; size === None && Positive[n] :> indexPeelTerm[HoldComplete[x], target, n],
        _ :> {target, size, held}
    }]


indexInlineSize[held_] := Part[indexPeelTerm[held, None, None], 2]


(* CircleTimes is not Flat, so associativity is applied here: the factors are
   collected depth first with the outermost factor first, and the order is the
   order the caller wrote. *)
indexProductFactors[held_] :=
    Replace[held, {
        HoldComplete[CircleTimes[xs__]] :>
            Catenate[Map[indexProductFactors, Cases[HoldComplete[xs], x_ :> HoldComplete[x], {1}]]],
        _ :> {held}
    }]


(* === the term grammar ===

   An axis term is a blank a_, a bare symbol, a string naming an identifier, a
   positive integer, an anonymous _, or a CircleTimes of those, each optionally
   under one target head and one inline size.  Everything else is declined by
   name.  The out-of-scope spellings are matched EXPLICITLY rather than left to
   the catch-all, so that an ellipsis, a named sequence and a direct sum each
   report the construct the descriptor named instead of a generic grammar
   failure.

   A blank cannot be given a size: it takes its size from the operand, and an
   inline Annotation on one is the same mistake as a Pattern binding key.

   An inline size is a FACT about an axis and never part of how the axis is
   spelled, so the kind recorded here is decided by the spelling alone:
   Annotation[j, 2] is the same bare j that j is, and Annotation["j", 2] the
   same string axis as "j".  Letting the size carry a kind of its own would give
   one name two identities, which turns {{i, Annotation[j, 2]}, {j, k}} from a
   matrix product into an outer product and hides a symbol/string mishmash from
   the check below. *)
indexSurfaceTerm[inner_, target_, size_, held_] :=
    Replace[inner, {
        HoldComplete[Verbatim[Pattern][s_Symbol, Verbatim[Blank][]]] :>
            If[ size === None,
                indexSurfaceAxis[SymbolName[Unevaluated[s]], "Blank", None],
                indexFail[ArrayIndexPattern, "patternkey", {indexShow[held]}, <|"Source" -> held|>]
            ],
        HoldComplete[Verbatim[Blank][]] :>
            If[size === None, indexSurfaceAnonymous[], indexTermFailure[held]],
        HoldComplete[Verbatim[BlankSequence][___] | Verbatim[BlankNullSequence][___]] :> indexUnsupported[held],
        HoldComplete[Verbatim[Repeated][___] | Verbatim[RepeatedNull][___]] :> indexUnsupported[held],
        HoldComplete[Verbatim[Pattern][_, Verbatim[BlankSequence][___] | Verbatim[BlankNullSequence][___] |
                Verbatim[Repeated][___] | Verbatim[RepeatedNull][___]]] :> indexUnsupported[held],
        HoldComplete[_CirclePlus | _SlotSequence] :> indexUnsupported[held],
        HoldComplete[Slot[_Integer]] :> indexUnsupported[held],
        HoldComplete[_Slot] :> indexTermFailure[held],
        HoldComplete[s_Symbol] :>
            If[ Context[Unevaluated[s]] === "System`",
                indexTermFailure[held],
                indexSurfaceAxis[SymbolName[Unevaluated[s]], "Bare", Context[Unevaluated[s]]]
            ],
        HoldComplete[str_String] :>
            If[ indexNameQ[str],
                indexSurfaceAxis[str, "String", None],
                indexTermFailure[held]
            ],
        HoldComplete[n_Integer] :>
            Which[
                target =!= None, indexUnsupported[held],
                size =!= None || ! Positive[n], indexTermFailure[held],
                True, indexSurfaceLiteral[n]
            ],
        _ :> indexTermFailure[held]
    }]


indexCaptureTerm[held_, path_] :=
    Module[{target, size, inner, factors, subs},
        {target, size, inner} = indexPeelTerm[held, None, None];
        If[ MatchQ[inner, HoldComplete[_CircleTimes]],
            factors = indexProductFactors[inner];
            If[size =!= None || Length[factors] < 2, indexTermFailure[held]];
            subs = Table[indexCaptureTerm[factors[[k]], Append[path, k]], {k, Length[factors]}];
            {
                indexSurfaceProduct[Map[First, subs]],
                Join[{path -> held}, Catenate[subs[[All, 2]]]],
                Join[If[target === None, {}, {path -> target}], Catenate[subs[[All, 3]]]]
            },
            {
                indexSurfaceTerm[inner, target, size, held],
                {path -> held},
                If[target === None, {}, {path -> target}]
            }
        ]
    ]


indexCaptureShape[shapeHeld_, base_List, source_] :=
    Module[{captured},
        If[ ! MatchQ[shapeHeld, HoldComplete[_List]],
            indexFail[ArrayIndexPattern, "parse", {indexShow[source]}, <|"Source" -> source|>]
        ];
        captured = Table[
            indexCaptureTerm[Extract[shapeHeld, {1, k}, HoldComplete], Append[base, k]],
            {k, indexHeldLength[shapeHeld]}
        ];
        If[ captured === {},
            {{}, {}, {}},
            {Map[First, captured], Catenate[captured[[All, 2]]], Catenate[captured[[All, 3]]]}
        ]
    ]


(* Output-side capture, in order: an established name gives a reference to the
   binder of that name; otherwise the symbol's ambient value is read, which
   normalizes to a literal axis if it is a positive integer and to a string axis
   if it is a valid identifier; otherwise the occurrence is an ambient axis of
   its own.  Reading the value is the point - an output symbol with no binder of
   the same name means whatever it means in the caller's scope.

   An occurrence carrying an inline size is exempt from the value read:
   Annotation[r, 3] declares an axis of size 3, so a chance binding of r in the
   caller's scope is not what that occurrence asks about. *)
indexEstablishedNames[shapes_List] :=
    DeleteDuplicates[Cases[shapes, indexSurfaceAxis[name_, "Blank" | "String", _] :> name, Infinity]]


indexAmbientValue[term_, value_] :=
    Which[
        IntegerQ[value] && Positive[value], indexSurfaceLiteral[value],
        StringQ[value] && indexNameQ[value], indexSurfaceAxis[value, "String", None],
        True, indexFail[ArrayIndexPattern, "ambient", {First[term], value}, <|"Source" -> HoldComplete[value]|>]
    ]

(* A Sequence value splices in argument position, so the two-argument
   definition above never sees it: whatever arity the splice leaves lands
   here.  A run of values names no axis any more than a lone unusable one
   does, so it takes the same refusal, rendered under the Sequence it
   splices from. *)
indexAmbientValue[term_, values___] :=
    indexFail[
        ArrayIndexPattern, "ambient",
        {First[term], HoldForm[Sequence[values]]},
        <|"Source" -> HoldComplete[values]|>
    ]


indexResolveTerm[term_, path_, sourceMap_, established_] :=
    Replace[term, {
        indexSurfaceProduct[fs_] :>
            indexSurfaceProduct[Table[indexResolveTerm[fs[[k]], Append[path, k], sourceMap, established], {k, Length[fs]}]],
        indexSurfaceAxis[name_, "Bare", _] /; ! MemberQ[established, name] :>
            Replace[indexPeelTerm[sourceMap[path], None, None], {
                {_, None, HoldComplete[s_Symbol]} /; ValueQ[Unevaluated[s]] :> indexAmbientValue[term, s],
                _ :> term
            }],
        _ :> term
    }]


indexParseExpression[held_, arrow_] :=
    Module[{outputHeld, specified, inputShapes, outputShapes, captured, split, inputs, outputs, sourceMap, established},
        outputHeld = If[arrow === None, None, Extract[held, {1, 2}, HoldComplete]];
        specified = arrow =!= None && ! MatchQ[outputHeld, HoldComplete[Automatic]];
        inputShapes = indexNormalizeSide[If[arrow === None, held, Extract[held, {1, 1}, HoldComplete]]];
        outputShapes = If[specified, indexNormalizeSide[outputHeld], {}];
        captured = Join[
            Table[indexCaptureShape[inputShapes[[k]], {"Inputs", k}, held], {k, Length[inputShapes]}],
            Table[indexCaptureShape[outputShapes[[k]], {"Outputs", k}, held], {k, Length[outputShapes]}]
        ];
        split = Length[inputShapes];
        inputs = Map[First, Take[captured, split]];
        outputs = Map[First, Drop[captured, split]];
        sourceMap = Association[Catenate[captured[[All, 2]]]];
        established = indexEstablishedNames[Join[inputs, outputs]];
        outputs = Table[
            Table[indexResolveTerm[outputs[[j, k]], {"Outputs", j, k}, sourceMap, established], {k, Length[outputs[[j]]]}],
            {j, Length[outputs]}
        ];
        <|
            "Dialect" -> If[arrow === Rule, "IndexList", "Expression"],
            "Arrow" -> arrow,
            "Inputs" -> inputs,
            "Outputs" -> outputs,
            "OutputSpecified" -> specified,
            "Targets" -> Association[Catenate[captured[[All, 3]]]],
            "SourceMap" -> sourceMap,
            "Source" -> held
        |>
    ]


(* Rule is accepted rather than rejected because the classic einsum call sites
   are written with it and arrive intact when their symbols are unbound; the
   warning says what it costs, and the descriptor still compiles. *)
indexSurfaceDescriptor[desc_] :=
    Replace[HoldComplete[desc], {
        HoldComplete[s_String] :> indexParseString[s],
        HoldComplete[RuleDelayed[_, _]] :> indexParseExpression[HoldComplete[desc], RuleDelayed],
        HoldComplete[Rule[_, _]] :> (
            Message[ArrayIndexPattern::rule, HoldForm[desc]];
            indexParseExpression[HoldComplete[desc], Rule]
        ),
        HoldComplete[_List] :> indexParseExpression[HoldComplete[desc], None],
        _ :> indexFail[ArrayIndexPattern, "parse", {HoldForm[desc]}, <|"Source" -> HoldComplete[desc]|>]
    }]


(* === capture, hygiene and interning ===

   After normalization the whole term vocabulary is indexAxis[id] and
   indexProduct[{...}]: a literal, a unit axis and an anonymous axis are all
   axes, distinguished by the "Kind" of their axis-table entry rather than by a
   head of their own, so a traversal has two cases and not six.

   An interned axis IS a positive Integer, allocated in first-occurrence order
   over the input shapes left to right and then the output shape.  Four reasons
   it is not a symbol, all of them scars in the prior art: an adversarial
   $Context breaks any resolver that maps a name back to a symbol; a user symbol
   cannot be held as an identity without risking evaluation somewhere in the
   pipeline, so Block[{c = 3}, {{a_, c_}} :> {{c, a}}] must transpose rather
   than resolve c to 3; Unique[] demands a lifecycle and leaks into Names[]; and
   an integer domain keeps the solver free of user symbols. *)

indexSurfaceLeaves[term_, path_] :=
    Replace[term, {
        indexSurfaceProduct[fs_] :>
            Catenate[Table[indexSurfaceLeaves[fs[[k]], Append[path, k]], {k, Length[fs]}]],
        _ :> {{term, path}}
    }]


indexNormalizeTerm[term_, path_, idAt_] :=
    Replace[term, {
        indexSurfaceProduct[fs_] :>
            indexProduct[Table[indexNormalizeTerm[fs[[k]], Append[path, k], idAt], {k, Length[fs]}]],
        _ :> indexAxis[idAt[path]]
    }]


(* The intern key decides identity, and it is the whole of the hygiene rule.
   An established name - one spelled as a blank or a string ANYWHERE in the
   descriptor - interns by name alone, so a Wolfram context never distinguishes
   two established axes of one name.  A bare symbol is an ambient expression and
   interns by context and name, so two bare symbols in two contexts are two
   axes, exactly as they are two symbols with two values; on the output side a
   bare symbol references an established binder of the same name when there is
   one.

   The key is a function of the SPELLING, which is why an inline size does not
   appear in it: a sized occurrence is the same axis as an unsized one of the
   same spelling, and both reach whichever branch that spelling reaches.

   The consequences are the three regressions this rule exists for:
   {{a_, a_}} :> {{a}} is one axis, {{a, a}} :> {{a}} is one axis - "ambient"
   does not mean "fresh at each occurrence", and this is exactly why
   {{i, j}, {j, k}} -> {{i, k}} contracts - and {{a_, a}} :> {{a}} is TWO axes
   whose output a resolves to the blank. *)
indexInternKey[name_String, kind_String, ctx_, side_String, established_List] :=
    Which[
        MemberQ[{"Blank", "String"}, kind], "axis:" <> name,
        side === "Outputs" && MemberQ[established, name], "axis:" <> name,
        True, "ambient:" <> ctx <> name
    ]


(* The no-mishmash check runs BEFORE any interning, because a_ and "a" would
   otherwise both intern to "axis:a" and be silently conflated although a blank
   and a string carry different hygiene. *)
indexPolicyCheck[name_String, kinds_List] :=
    If[ IntersectingQ[kinds, {"Blank", "Bare"}] && MemberQ[kinds, "String"],
        indexFail[ArrayIndexPattern, "mishmash", {name}, <|"Axis" -> name|>]
    ]


indexCollectPolicy[shapes_List] := (
    KeyValueMap[
        indexPolicyCheck,
        GroupBy[Cases[shapes, indexSurfaceAxis[name_, kind_, _] :> {name, kind}, Infinity], First -> Last]
    ];
    indexEstablishedNames[shapes]
)


(* A binding key names an axis the way the descriptor spells it: a string for a
   string axis, a bare symbol for a bare axis, and the target head the
   descriptor used around either.  A Pattern key is a hard rejection and not a
   silent no-op, since a blank is inference-only and takes its size from the
   operand. *)
indexBindingAxis[held_, keyTable_] :=
    Module[{inner = Part[indexPeelTerm[held, None, None], 3], key},
        key = Replace[inner, {
            HoldComplete[Verbatim[Pattern][_Symbol, Verbatim[Blank][]]] :>
                indexFail[ArrayIndexPattern, "patternkey", {indexShow[inner]}, <|"Source" -> held|>],
            HoldComplete[s_String] :> "axis:" <> s,
            HoldComplete[s_Symbol] :> "ambient:" <> Context[Unevaluated[s]] <> SymbolName[Unevaluated[s]],
            _ :> None
        }];
        If[key =!= None && KeyExistsQ[keyTable, key], keyTable[key], None]
    ]


(* The value is read through an Apply into HoldComplete rather than
   substituted bare: a Sequence value splices in a bare position, collapsing
   the pair to one element and leaking a Set::shape from the destructuring on
   the way to the refusal, where the held read keeps the pair a pair for any
   value at all. *)
indexBindingFact[entry_, keyTable_] :=
    Module[{key, held, value, id},
        {key, held} = Replace[entry, {
            (Rule | RuleDelayed)[k_, v_] :> {HoldComplete[k], HoldComplete @@ {v}},
            _ :> indexFail[ArrayIndexPattern, "bindingkey", {entry}, <|"Source" -> HoldComplete[entry]|>]
        }];
        If[ ! MatchQ[held, HoldComplete[_Integer ? Positive]],
            indexFail[ArrayIndexPattern, "bindingkey", {entry}, <|"Source" -> HoldComplete[entry]|>]
        ];
        value = First[held];
        id = indexBindingAxis[key, keyTable];
        If[ id === None,
            indexFail[ArrayIndexPattern, "bindingkey", {entry}, <|"Source" -> HoldComplete[entry]|>]
        ];
        <|"Axis" -> id, "Size" -> value, "Source" -> "Binding", "Key" -> key|>
    ]


indexBindingFacts[bindings_List, keyTable_] :=
    Table[indexBindingFact[bindings[[k]], keyTable], {k, Length[bindings]}]


indexFactAxis[fact_Association] := fact["Axis"]

indexFactSize[fact_Association] := fact["Size"]


(* Equal facts coalesce and conflicting facts fail order-independently, so that
   an inline Annotation, a literal axis and a binding rule that disagree report
   the same refusal whichever order they were written in. *)
indexCheckFacts[facts_List, axisTable_] :=
    Module[{grouped = GroupBy[facts, indexFactAxis -> indexFactSize], ids, sizes},
        ids = Keys[grouped];
        Do[
            sizes = DeleteDuplicates[grouped[ids[[k]]]];
            If[ Length[sizes] > 1,
                indexFail[
                    ArrayIndexPlan, "conflict",
                    {axisTable[ids[[k]], "Name"], sizes[[1]], sizes[[2]]},
                    <|"Axis" -> ids[[k]]|>
                ]
            ],
            {k, Length[ids]}
        ]
    ]


indexKnownSizeConstraint[fact_Association, axisTable_] :=
    <|
        "Constraint" -> "KnownSize", "Axis" -> fact["Axis"], "Size" -> fact["Size"],
        "Source" -> If[fact["Source"] === "Binding", None, axisTable[fact["Axis"], "Source"]]
    |>


indexTermAxisId[indexAxis[id_Integer]] := id


indexShapeAxisIds[shape_List] := Map[indexTermAxisId, Map[First, indexFlatTerms[shape]]]


(* A composite never nests: CircleTimes is flattened by associativity at
   capture, so one Product record per composite occurrence is the whole of the
   shape-free product system. *)
indexTermProducts[term_, path_] :=
    Replace[term, {
        indexProduct[_] :> {<|"Constraint" -> "Product", "Axes" -> indexShapeAxisIds[{term}], "Source" -> path|>},
        _ :> {}
    }]


indexShapeProducts[shape_List, base_List] :=
    Catenate[Table[indexTermProducts[shape[[k]], Append[base, k]], {k, Length[shape]}]]


(* With no output shape written, "Contracted" keeps the axes occurring exactly
   once across the input frames, in first-occurrence order rather than sorted,
   and "Identity" keeps the single input shape.  A nameless axis - an anonymous
   one, a literal and a unit - cannot reach the output at all, having no name to
   be referenced by, so it is summed rather than carried. *)
indexDefaultOutput[inputs_List, axisTable_, defaultOutput_String, surface_Association] :=
    Module[{all, ids, counts, once},
        If[ defaultOutput === "Identity",
            If[ Length[inputs] =!= 1,
                indexFail[
                    ArrayIndexTransform, "arity",
                    {Length[inputs], Length[surface["Outputs"]]},
                    <|"Source" -> surface["Source"]|>
                ]
            ];
            First[inputs],
            all = Catenate[Map[indexShapeAxisIds, inputs]];
            ids = Table[
                If[MemberQ[{"Anonymous", "Literal", "Unit"}, axisTable[all[[k]], "Kind"]], Nothing, all[[k]]],
                {k, Length[all]}
            ];
            counts = Counts[ids];
            once = DeleteDuplicates[ids];
            Table[If[counts[once[[k]]] === 1, indexAxis[once[[k]]], Nothing], {k, Length[once]}]
        ]
    ]


indexShapeLeaves[shape_List, base_List] :=
    Catenate[Table[indexSurfaceLeaves[shape[[k]], Append[base, k]], {k, Length[shape]}]]


indexLiteralFact[id_Integer, n_Integer] :=
    <|"Axis" -> id, "Size" -> n, "Source" -> "Literal", "Key" -> None|>


indexAxisInfo[term_, key_, id_Integer, path_List] :=
    Replace[term, {
        indexSurfaceAxis[name_, kind_, ctx_] :>
            <|"Name" -> name, "Kind" -> kind, "Context" -> ctx, "Key" -> key, "Source" -> path|>,
        indexSurfaceLiteral[n_] :>
            <|"Name" -> ToString[n], "Kind" -> If[n === 1, "Unit", "Literal"], "Context" -> None,
              "Key" -> "fresh:" <> ToString[id], "Source" -> path|>,
        indexSurfaceAnonymous[] :>
            <|"Name" -> "_", "Kind" -> "Anonymous", "Context" -> None,
              "Key" -> "fresh:" <> ToString[id], "Source" -> path|>
    }]


indexNormalizedDescriptor[surface_Association, bindings_List, defaultOutput_String] :=
    Module[{
            inputs = surface["Inputs"], outputs = surface["Outputs"], sourceMap = surface["SourceMap"],
            established, leaves, keyTable = <||>, axisTable = <||>, literalSizes = <||>, idAt = <||>,
            count = 0, term, path, key, id, normalizedInputs, outputShape, outIds, repeated,
            facts, constraints
        },

        If[ Length[outputs] > 1,
            indexFail[ArrayIndexPattern, "outputs", {Length[outputs]}, <|"Source" -> surface["Source"]|>]
        ];

        established = indexCollectPolicy[Join[inputs, outputs]];

        leaves = Join[
            Catenate[Table[indexShapeLeaves[inputs[[j]], {"Inputs", j}], {j, Length[inputs]}]],
            Catenate[Table[indexShapeLeaves[outputs[[j]], {"Outputs", j}], {j, Length[outputs]}]]
        ];

        (* An anonymous axis, a literal and a unit have no name, so they cannot
           be shared and take a fresh identity at every occurrence. *)
        Do[
            {term, path} = leaves[[j]];
            key = Replace[term, {
                indexSurfaceAxis[name_, kind_, ctx_] :> indexInternKey[name, kind, ctx, First[path], established],
                _ :> None
            }];
            If[ key =!= None && KeyExistsQ[keyTable, key],
                id = keyTable[key],
                count = count + 1;
                id = count;
                axisTable[id] = indexAxisInfo[term, key, id, path];
                If[key =!= None, keyTable[key] = id];
                Replace[term, indexSurfaceLiteral[n_] :> (literalSizes[id] = n)];
            ];
            idAt[path] = id,
            {j, Length[leaves]}
        ];

        normalizedInputs = Table[
            Table[indexNormalizeTerm[inputs[[j, k]], {"Inputs", j, k}, idAt], {k, Length[inputs[[j]]]}],
            {j, Length[inputs]}
        ];
        outputShape =
            If[ surface["OutputSpecified"],
                Table[indexNormalizeTerm[outputs[[1, k]], {"Outputs", 1, k}, idAt], {k, Length[First[outputs]]}],
                indexDefaultOutput[normalizedInputs, axisTable, defaultOutput, surface]
            ];

        (* A repeated output axis names no layout: the tensor power reading of
           {{i}} :> {{i, i}} is a surprising one and has no lowering here. *)
        outIds = indexShapeAxisIds[outputShape];
        repeated = FirstCase[Tally[outIds], {axis_, n_} /; n > 1 :> axis];
        If[ ! MissingQ[repeated],
            indexFail[ArrayIndexPattern, "duplicate", {axisTable[repeated, "Name"]}, <|"Axis" -> repeated|>]
        ];

        facts = DeleteDuplicates @ Join[
            KeyValueMap[indexLiteralFact, literalSizes],
            (* An inline size is read off the SOURCE of the occurrence and not
               off its normalized term, because the term records the spelling
               and the spelling is deliberately blind to the size.  A leaf of a
               dialect that carries no source - the string dialect writes its
               sizes out of band - peels to no size and contributes nothing. *)
            Catenate @ Table[
                With[{inline = indexInlineSize[sourceMap[leaves[[j, 2]]]]},
                    If[ inline === None,
                        {},
                        {<|
                            "Axis" -> idAt[leaves[[j, 2]]],
                            "Size" -> inline,
                            "Source" -> "Inline", "Key" -> None
                        |>}
                    ]
                ],
                {j, Length[leaves]}
            ],
            indexBindingFacts[bindings, keyTable]
        ];
        indexCheckFacts[facts, axisTable];

        constraints = Join[
            Table[indexKnownSizeConstraint[facts[[k]], axisTable], {k, Length[facts]}],
            Catenate[Table[indexShapeProducts[normalizedInputs[[j]], {"Inputs", j}], {j, Length[normalizedInputs]}]],
            indexShapeProducts[outputShape, {"Outputs", 1}]
        ];

        <|
            "Inputs" -> normalizedInputs,
            "Outputs" -> {outputShape},
            "OutputSpecified" -> surface["OutputSpecified"],
            "Axes" -> axisTable,
            "Targets" -> surface["Targets"],
            "Bindings" -> facts,
            "Constraints" -> constraints,
            "SourceMap" -> sourceMap,
            "Dialect" -> surface["Dialect"]
        |>
    ]


(* The validity predicate is total and is called from the pipeline, not only
   from the tests: a stage that hands on a descriptor states what it hands on. *)
$indexNormalizedKeys = {
    "Inputs", "Outputs", "OutputSpecified", "Axes", "Targets",
    "Bindings", "Constraints", "SourceMap", "Dialect"
};

indexNormalizedTermQ[term_, ids_List] :=
    Replace[term, {
        indexAxis[id_Integer] :> MemberQ[ids, id],
        indexProduct[fs_List] :> And @@ Table[indexNormalizedTermQ[fs[[k]], ids], {k, Length[fs]}],
        _ :> False
    }]

indexNormalizedShapeQ[shape_, ids_List] :=
    ListQ[shape] && And @@ Table[indexNormalizedTermQ[shape[[k]], ids], {k, Length[shape]}]

indexNormalizedShapesQ[shapes_List, ids_List] :=
    And @@ Table[indexNormalizedShapeQ[shapes[[k]], ids], {k, Length[shapes]}]

indexHeldQ[e_] := MatchQ[e, _HoldComplete]

indexNormalizedQ[expr_] :=
    TrueQ @ And[
        AssociationQ[expr],
        ContainsAll[Keys[expr], $indexNormalizedKeys],
        AssociationQ[expr["Axes"]],
        ListQ[expr["Inputs"]],
        ListQ[expr["Outputs"]],
        Length[expr["Outputs"]] === 1,
        indexNormalizedShapesQ[Join[expr["Inputs"], expr["Outputs"]], Keys[expr["Axes"]]],
        AssociationQ[expr["SourceMap"]],
        AllTrue[Values[expr["SourceMap"]], indexHeldQ]
    ]


indexAxisLabel[normalized_Association, id_Integer] :=
    Replace[Lookup[normalized["Axes"], id], {
        info_Association :> info["Name"],
        _ :> Missing["NotFound"]
    }]


(* The path a leaf gets here is the suffix INSIDE the shape, so a caller that
   holds the shape's own path appends it and lands on the SourceMap entry. *)
indexFlatTermsAt[term_, path_List] :=
    Replace[term, {
        indexProduct[fs_List] :>
            Catenate[Table[indexFlatTermsAt[fs[[k]], Append[path, k]], {k, Length[fs]}]],
        _ :> {{term, path}}
    }]

indexFlatTerms[shape_List] :=
    Catenate[Table[indexFlatTermsAt[shape[[k]], {k}], {k, Length[shape]}]]
