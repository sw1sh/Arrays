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
    "Overview" -> {"Documentation", "English", "Tutorials"},
    (* the paclet-repository submission notebook is not a documentation page:
       it sits beside PacletInfo.wl rather than under Documentation *)
    "Paclet" -> {}
|>

(* every page, the definition notebook included, is rooted at the paclet
   directory: the repository submission expects the definition notebook beside
   PacletInfo.wl, and putting it there also lets the manifest panel resolve the
   paclet from the notebook's own directory *)
outRoot[_String] := pacletDir

frontmatterTemplate[srcFile_String] := Block[{m},
    m = StringCases[Import[srcFile, "Text"],
        StartOfLine ~~ "Template:" ~~ Whitespace ... ~~ v : Except["\n"] .. :> StringTrim[v], 1];
    If[m === {}, Missing[], First[m]]
]

(* The example cells of a page are evaluated in this kernel as the page is
   converted, so a symbol a page assigns leaks into every page converted after
   it: f = NDSolveValue[...] on one page leaves f an InterpolatingFunction, and
   on the next page f'[t] == ... then reduces to True and NDSolveValue fails
   with ::deqn.  Remove exactly the names a page assigns at the start of a line
   in one of its example cells, as soon as it has been converted. *)

pageAssignments[srcFile_String] := DeleteDuplicates @ StringCases[
    Import[srcFile, "Text"],
    StartOfLine ~~ name : (WordCharacter ..) ~~ " = " :> "Global`" <> name
]

clearPageState[srcFile_String] := Quiet @ Remove @@ pageAssignments[srcFile]

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
    dir = FileNameJoin[Prepend[subdir[tmpl], outRoot[tmpl]]];
    Quiet @ CreateDirectory[dir, CreateIntermediateDirectories -> True];
    out = FileNameJoin[{dir, FileBaseName[srcFile] <> ".nb"}];
    mtn[srcFile, out];
    clearPageState[srcFile];
    Print["  ", FileNameTake[srcFile], " -> ", FileNameDrop[out, FileNameDepth[repoDir]]]
]

Print["building Wolfram/Arrays documentation"]

Scan[buildDoc, Sort @ FileNames["*.md", FileNameJoin[{repoDir, "docs"}], Infinity]]

(* No DocumentationBuild stage.  The repository builds documentation itself and
   wants AUTHORING notebooks; a page already built in place does not survive
   PacletBuild, which drops it from the paclet - the guide was the only page to
   ship while this stage ran, and it was the only one exempt from it. *)

(* The definition notebook carries the file list the paclet is BUILT from, and
   MarkdownToNotebook fills it from the MainGuide frontmatter alone.  Left at
   that, the submitted paclet ships the guide and nothing else - no reference
   pages, no tutorials, and so no documentation sidebar on the repository page.
   Refreshing the panel from the paclet directory, after the notebooks exist,
   is what puts every generated page into the paclet. *)

Print["refreshing the definition notebook's paclet file list"]

Needs["DefinitionNotebookClient`"]

defNb = FileNameJoin[{pacletDir, "ResourceDefinition.nb"}]

If[ FileExistsQ[defNb],
    Module[{count},
        count = UsingFrontEnd @ Block[{nbo, n},
            nbo = NotebookOpen[defNb, Visible -> False];
            DefinitionNotebookClient`RefreshFileTreeCells["Paclet", nbo, pacletDir, "PacletFiles"];
            NotebookSave[nbo];
            NotebookClose[nbo];
            Length @ StringCases[Import[defNb, "Text"], ".nb\"" | ".wl\""]
        ];
        Print["  file entries now listed: ", count]
    ],
    Print["  (no ResourceDefinition.nb yet)"]
]

Print["done"]
