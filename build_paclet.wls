#!/usr/bin/env wolframscript
(* Build the Wolfram/Arrays .paclet archive into build/.

   Three stages. PacletDocumentationBuild turns the authoring notebooks
   build_docs.wls generated under Arrays/Documentation into BUILT documentation
   - the same notebooks plus the Index, SearchIndex and SpellIndex a paclet
   needs for its pages to be searchable once installed. Those built pages are
   staged beside the kernel and PacletInfo.wl, since the documentation build
   emits Documentation alone. The archive is then created from that staging
   tree, never from the repository's own paclet directory, so the gitignored
   build subdirectory cannot pack earlier archives into a new one.

   Run build_docs.wls first: this script builds from the notebooks it leaves,
   and fails rather than shipping an archive with no documentation in it.

   Run with:

       wolframscript -f build_paclet.wls
*)

repoDir = DirectoryName[$InputFileName]

pacletDir = FileNameJoin[{repoDir, "Arrays"}]

buildDir = FileNameJoin[{repoDir, "build"}]

PacletDirectoryLoad[pacletDir]

Needs["Wolfram`Arrays`"]

If[ ! NameQ["Wolfram`Arrays`ArrayContainerQ"],
    Print["FATAL: Wolfram`Arrays` failed to load."];
    Exit[1]
]

authored = FileNames["*.nb", FileNameJoin[{pacletDir, "Documentation"}], Infinity]

If[ authored === {},
    Print["FATAL: no documentation notebooks under ", FileNameJoin[{pacletDir, "Documentation"}], "; run build_docs.wls first."];
    Exit[1]
]

Print["authoring notebooks: ", Length[authored]]

(* === built documentation === *)

If[ FailureQ[Quiet @ Check[Needs["PacletTools`"], $Failed]] || ! NameQ["PacletTools`PacletDocumentationBuild"],
    Print["FATAL: PacletTools`PacletDocumentationBuild is unavailable, so the archive would ship unsearchable documentation."];
    Exit[1]
]

docTarget = FileNameJoin[{$TemporaryDirectory, "Wolfram__Arrays-docbuild"}]

Quiet @ DeleteDirectory[docTarget, DeleteContents -> True]

Print["building documentation into ", docTarget]

docResult = PacletTools`PacletDocumentationBuild[pacletDir, docTarget, "Notebooks", OverwriteTarget -> True]

If[ ! MatchQ[docResult, _Success],
    Print["FATAL: the documentation build did not succeed: ", Short[docResult, 5]];
    Exit[1]
]

Print["  ", docResult["SuccessfulFilesCount"], " of ", docResult["ProcessedFilesCount"],
    " pages built, ", docResult["FailedFilesCount"], " failed"]

If[ docResult["FailedFilesCount"] =!= 0,
    Print["FATAL: a page failed to build."];
    Exit[1]
]

builtDocs = FileNameJoin[{docTarget, "Wolfram__Arrays", "Documentation"}]

If[ ! DirectoryQ[builtDocs],
    Print["FATAL: the documentation build left no Documentation directory at ", builtDocs];
    Exit[1]
]

(* The indexes are what separate a built page from an authored one: without
   them an installed paclet's documentation is not searchable. *)

indexDirs = Select[
    FileNameJoin[{builtDocs, "English", #}] & /@ {"Index", "SearchIndex", "SpellIndex"},
    DirectoryQ
]

If[ Length[indexDirs] =!= 3,
    Print["FATAL: the documentation build produced no search indexes; found ", indexDirs];
    Exit[1]
]

Print["  indexes: ", FileNameTake /@ indexDirs]

(* === staging === *)

staging = FileNameJoin[{$TemporaryDirectory, "Wolfram__Arrays-staging", "Arrays"}]

Quiet @ DeleteDirectory[DirectoryName[staging], DeleteContents -> True]
CreateDirectory[DirectoryName[staging], CreateIntermediateDirectories -> True]
CopyDirectory[pacletDir, staging]

(* Earlier archives live in the gitignored build subdirectory of the paclet
   directory; copying it in would pack every previous archive into this one. *)
Quiet @ DeleteDirectory[FileNameJoin[{staging, "build"}], DeleteContents -> True]
Scan[DeleteFile, FileNames[".DS_Store", staging, Infinity]]

(* The authored notebooks are replaced wholesale by the built ones. *)
Quiet @ DeleteDirectory[FileNameJoin[{staging, "Documentation"}], DeleteContents -> True]
CopyDirectory[builtDocs, FileNameJoin[{staging, "Documentation"}]]

Print["staged pages: ", Length @ FileNames["*.nb", FileNameJoin[{staging, "Documentation"}], Infinity]]

(* === archive === *)

Quiet @ CreateDirectory[buildDir]
Scan[DeleteFile, FileNames["*.paclet", buildDir]]

archive = CreatePacletArchive[staging, buildDir]

If[ ! StringQ[archive],
    Print["FATAL: CreatePacletArchive did not return an archive path: ", archive];
    Exit[1]
]

Print["paclet archive: ", archive, " (", FileByteCount[archive], " bytes)"]

(* The archive must answer as a paclet in its own right: a name, a version and
   a manifest PacletObject can read back out of the file. *)

obj = PacletObject[File[archive]]

If[ ! PacletObjectQ[obj],
    Print["FATAL: the archive does not read back as a paclet: ", obj];
    Exit[1]
]

Print["archive reads back as ", obj["Name"], " ", obj["Version"]]
