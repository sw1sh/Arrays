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

PacletDirectoryLoad[pacletDir]

Needs["Wolfram`Arrays`"]

If[ ! NameQ["Wolfram`Arrays`ArrayContainerQ"],
    Print["FATAL: Wolfram`Arrays` failed to load."];
    Exit[1]
]

(* MarkdownToNotebook is fetched as a plain .wl from its GitHub repository,
   over an unauthenticated URL, and that is the only source: a build depends on
   no checkout beside this one and on no cloud login, so it runs the same way on
   a development machine and on a runner.  MTN_REF pins the git ref to fetch
   from; the default is the upstream default branch. *)

$mtnRef = Replace[Environment["MTN_REF"], Except[_String] -> "main"]

$mtnURL = StringJoin[
    "https://raw.githubusercontent.com/WolframInstitute/MarkdownToNotebook/",
    $mtnRef,
    "/MarkdownToNotebook.wl"
]

fetchMarkdownToNotebook[] := Module[{response, body, file},
    response = Quiet @ Check[URLRead[HTTPRequest[$mtnURL], {"StatusCode", "Body"}], $Failed];
    If[ ! AssociationQ[response] || response["StatusCode"] =!= 200,
        Print["FATAL: could not fetch MarkdownToNotebook from ", $mtnURL];
        Print["  ", Replace[response, {a_Association :> {"status", a["StatusCode"]}, other_ :> other}]];
        Exit[1]
    ];
    body = response["Body"];
    If[ ! StringQ[body] || ! StringContainsQ[body, "MarkdownToNotebook"],
        Print["FATAL: the response from ", $mtnURL, " is not the package file."];
        Exit[1]
    ];
    file = FileNameJoin[{$TemporaryDirectory, "MarkdownToNotebook-" <> $mtnRef <> ".wl"}];
    Export[file, body, "Text", CharacterEncoding -> "UTF-8"];
    Get[file];
    Print["  MarkdownToNotebook fetched from ", $mtnRef, " (", StringLength[body], " bytes)"];
    MarkdownToNotebook
]

mtn = fetchMarkdownToNotebook[]

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

defNb = FileNameJoin[{pacletDir, "ResourceDefinition.nb"}]

(* The refresh matters to repository submission alone: the panel's file list is
   what SubmitRepository packs. A kernel that cannot load the client or reach a
   front end still leaves every generated notebook on disk, so the paclet
   archive is unaffected - report and continue rather than fail the build. *)
Which[
    ! FileExistsQ[defNb],
        Print["  (no ResourceDefinition.nb yet)"],
    FailureQ[Quiet @ Check[Needs["DefinitionNotebookClient`"], $Failed]],
        Print["  (DefinitionNotebookClient is unavailable; the file list is refreshed at submission)"],
    True,
        Module[{count},
            count = Quiet @ Check[
                UsingFrontEnd @ Block[{nbo},
                    nbo = NotebookOpen[defNb, Visible -> False];
                    DefinitionNotebookClient`RefreshFileTreeCells["Paclet", nbo, pacletDir, "PacletFiles"];
                    NotebookSave[nbo];
                    NotebookClose[nbo];
                    Length @ StringCases[Import[defNb, "Text"], ".nb\"" | ".wl\""]
                ],
                $Failed
            ];
            If[ IntegerQ[count],
                Print["  file entries now listed: ", count],
                Print["  (the front end refresh did not run; the file list is refreshed at submission)"]
            ]
        ]
]

Print["done"]
