# Goalset: feature

This file belongs to the Project: edit and extend it freely.
`booley init` creates it when it is missing and never rewrites it.

When a session enters Goal Mode with this Goalset, the agent translates
it into the entry tool's Goal arguments. Every Goal is mandatory. Write
new Goals in the same vocabulary as the Goal arguments below.
Each Review Goal names exactly one scope: a `target` or worktree-relative `paths`.

## Goals

- `LINT:<target>`: every Target the change touches lints clean.
- `SIM:<target>`: every Target the change touches passes simulation.
- `REVIEW:rtl_bugs`: the review finishes `clean` (no open findings).
- `REVIEW:tb_quality`: the review finishes `clean` (no open findings).

## Goal arguments

- Repeat each Goal that names `<target>` once for every Target the change touches, replacing `<target>` with the Target name.
- Replace each review's `<rtl-file>` or `<tb-file>` placeholder with its full
  list of category-matching worktree-relative files across the touched Targets.
  Keep one Goal per review kind. For one Target, you may replace `paths` with
  `target` to review that Target's category files and dependency closure.

```json
[
  {
    "family": "LINT",
    "target": "<target>",
    "origin": "feature"
  },
  {
    "family": "SIM",
    "target": "<target>",
    "origin": "feature"
  },
  {
    "family": "REVIEW",
    "review": "rtl_bugs",
    "verdict": "clean",
    "paths": [
      "<rtl-file>"
    ],
    "origin": "feature"
  },
  {
    "family": "REVIEW",
    "review": "tb_quality",
    "verdict": "clean",
    "paths": [
      "<tb-file>"
    ],
    "origin": "feature"
  }
]
```

## Goals that name Test Runs

A `SIM` Goal without `test` covers every Test of its Target, each as its
default Test Variant at the Target's Default Seed. Add `test` to require
one configuration instead:

- `{"family": "SIM", "target": "<target>", "test": "stress+soak"}`: the Test Variant `soak` of the Test `stress`.
- `{"family": "SIM", "target": "<target>", "test": "stress+soak@7"}`: that Test Variant with seed 7.
- `{"family": "SIM", "target": "<target>", "test": "stress@x20"}`: 20 Test Runs of `stress`, each with a different seed.
  Booley draws the seeds when Goal Mode is entered and keeps them for the session.

A `CYCLE_COUNT` Goal accepts the first two forms in `test`, and a `COVERAGE`
Goal accepts all three in `tests`. Test Variants are declared in `tests.toml`.
