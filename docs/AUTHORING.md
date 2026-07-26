# Documentation authoring rules for this paclet

The pages under `docs/` are the source of truth; `Arrays/Documentation` is generated
by `build_docs.wls` and gitignored. Author against the
`wolfram-symbol-page` / `wolfram-guide-page` / `wolfram-tech-note` skills, plus the
house rules below, which are maintainer decisions specific to this paclet.

## Examples show outputs, not tests of outputs

- **One result per example.** An example cell produces one result. Several results
  packed into a list (`{f[a], f[b]}`, `{True, False}`) is several examples wearing a
  trenchcoat: split it into one cell per result, each with its own caption saying
  what that case shows.
- **Never wrap a result to inspect it.** No `Head[...]`, no `MatchQ[...]`, no
  structural probe standing in for the result. Evaluate the expression and show what
  it actually returns.
- **Unevaluated output is shown in full**, exactly as the kernel returns it. The
  reader must see the expression come back unchanged; a `Head` or `MatchQ` test hides
  the very behavior the example exists to demonstrate. When the echoed form is long,
  keep the full output and use a descriptive output hint.
- **An object result is shown as the object.** When a symbol evaluates to an object,
  one of the first examples is the bare construction, displaying its summary box. Do
  not lead with `Head[obj]`, `obj["Property"]`, or a validity predicate: the box is
  the result. Property queries are worth their own later examples, after the object
  itself has been shown.

## Undefined behavior belongs in Possible Issues

Any input a symbol declines to answer for - a result of `Missing[...]`, a `Failure`,
or the call returning unevaluated - is a candidate for `## Possible Issues` rather
than `## Scope`. Scope demonstrates what the symbol supports; Possible Issues is where
a reader looks to find out why their input came back untouched. Move such examples
unless the case is genuinely a supported-scope boundary being contrasted with an
adjacent supported case.

## Prose

- Neutral, informational voice, as in the built-in reference pages. No editorializing
  ("clean", "powerful", "robust"), no design narration ("chosen to avoid", "named X
  because"), no lineage or prior-art commentary.
- Author-facing rationale goes in an MTN annotation marker attached to the
  `## Basic Examples` heading, never between an example caption and its code cell:
  `<!-- #| annotation: DD.MM.YY: Design review - ... -->`
- `## Usage` paragraphs are signatures only. Result-type notes, definitional prose,
  and cross-references belong in `## Details & Options`.

## Mechanics

- Inline code spans containing a backtick (a Wolfram context such as
  `` Wolfram`Arrays` ``) use double-backtick delimiters with pad spaces.
- ASCII only: no em dashes, no unicode arrows or box-drawing characters.
- Every example cell carries a one-sentence, colon-terminated caption; sibling cells
  are separated by `---`.
- Every example is kernel-verified and its real output recorded in the
  `<!-- => ... -->` hint.
