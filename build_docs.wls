#!/usr/bin/env wolframscript
(* Build the Wolfram/Arrays paclet documentation from the literate markdown in
   docs/, writing each notebook into the standard paclet layout under
   Arrays/Documentation/English/. The markdown is the source of truth; the
   notebooks are generated and gitignored.

   Run with:

       wolframscript -f build_docs.wls
*)

(* Pin the front end appearance to Light: a headless session resolves the
   Automatic appearance to Dark, which would invert colors in rasterized
   example output. *)

Quiet @ UsingFrontEnd[CurrentValue[$FrontEnd, LightDark] = "Light"]

repoDir = DirectoryName[$InputFileName]

(* The paclet is nested one level deep: <repo>/Arrays/PacletInfo.wl *)
pacletDir = FileNameJoin[{repoDir, "Arrays"}]

$mtnSource = "/Users/swish/src/wolfram/AISkills/MarkdownToNotebook.wl"

PacletDirectoryLoad[pacletDir]

Needs["Wolfram`Arrays`"]

If[ ! NameQ["Wolfram`Arrays`ArrayContainerQ"],
    Print["FATAL: Wolfram`Arrays` failed to load."];
    Exit[1]
]

(* Prefer the local MarkdownToNotebook checkout; fall back to the deployed
   cloud resource when it is absent. *)

mtn = If[ FileExistsQ[$mtnSource],
    Get[$mtnSource];
    MarkdownToNotebook,
    Quiet @ Check[If[! TrueQ[$CloudConnected], CloudConnect[]], Null];
    ResourceFunction["https://www.wolframcloud.com/obj/nikm/DeployedResources/Function/MarkdownToNotebook"]
]

subdir = <|
    "Symbol" -> {"Documentation", "English", "ReferencePages", "Symbols"},
    "Guide" -> {"Documentation", "English", "Guides"},
    "TechNote" -> {"Documentation", "English", "Tutorials"},
    "Overview" -> {"Documentation", "English", "Tutorials"}
|>

frontmatterTemplate[srcFile_String] := Block[{m},
    m = StringCases[Import[srcFile, "Text"],
        StartOfLine ~~ "Template:" ~~ Whitespace ... ~~ v : Except["\n"] .. :> StringTrim[v], 1];
    If[m === {}, Missing[], First[m]]
]

buildDoc[srcFile_String] := Block[{tmpl, dir, out},
    If[ ! StringStartsQ[StringTrim @ Import[srcFile, "Text"], "---"],
        Print["  (skip ", FileNameTake[srcFile], ": no frontmatter)"];
        Return[]
    ];
    tmpl = frontmatterTemplate[srcFile];
    If[ ! KeyExistsQ[subdir, tmpl],
        Print["  (skip ", FileNameTake[srcFile], ": template ", tmpl, " is not a doc page)"];
        Return[]
    ];
    dir = FileNameJoin[Prepend[subdir[tmpl], pacletDir]];
    Quiet @ CreateDirectory[dir, CreateIntermediateDirectories -> True];
    out = FileNameJoin[{dir, FileBaseName[srcFile] <> ".nb"}];
    mtn[srcFile, out];
    Print["  ", FileNameTake[srcFile], " -> ", FileNameDrop[out, FileNameDepth[repoDir]]]
]

Print["building Wolfram/Arrays documentation"]

Scan[buildDoc, Sort @ FileNames["*.md", FileNameJoin[{repoDir, "docs"}], Infinity]]

(* DocumentationBuild stage: the mtn output is an *authoring* notebook - the
   ExamplesInitializationSection is only collapsed into the Examples section at
   build time, so a page served raw would show a double section rule and fold
   the examples under "Examples Initialization". Build each page in place so
   Examples render as their own section. *)

Print["running DocumentationBuild on generated notebooks"]

Needs["DocumentationBuild`"]

failed = 0

Scan[
    Function[nb, Block[{built},
        (* DocumentationBuildNotebook returns a NotebookObject in current versions;
           read its Notebook expression back and close the front-end window *)
        built = Quiet @ UsingFrontEnd @ Replace[
            DocumentationBuild`DocumentationBuildNotebook[None, Get[nb]],
            obj_NotebookObject :> With[{expr = NotebookGet[obj]}, NotebookClose[obj]; expr]
        ];
        If[ MatchQ[built, _Notebook],
            Export[nb, built, "NB"];
            Print["  built ", FileNameDrop[nb, FileNameDepth[repoDir]],
                " (", Count[built, Cell[___], Infinity], " cells)"],
            failed++;
            Print["  FAILED: ", FileNameDrop[nb, FileNameDepth[repoDir]], " -> ", Head[built]]
        ]
    ]],
    Sort @ FileNames["*.nb", FileNameJoin[{pacletDir, "Documentation"}], Infinity]
]

If[failed > 0, Print["done with ", failed, " DocumentationBuild failure(s)"]; Exit[1]]

Print["done"]
