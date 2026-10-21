# Goalset: feature

This file belongs to the Project: edit and extend it freely.
`booley init` creates it when it is missing and never rewrites it.

When a session enters Goal Mode with this Goalset, the agent translates
it into the entry tool's Goal arguments. Every Goal is mandatory. Write
new Goals in the same vocabulary as the Goal arguments below.

## Goals

- `lint`: every Target the change touches lints clean.
- `sim`: every Target the change touches passes simulation.
- `review`: the `rtl_bugs` review finishes `clean` (no open findings).
- `review`: the `tb_quality` review finishes `clean` (no open findings).

## Goal arguments

- Repeat each Goal that names `<target>` once for every Target the change touches, replacing `<target>` with the Target name.

```json
[
  {
    "family": "lint",
    "target": "<target>",
    "origin": "feature"
  },
  {
    "family": "sim",
    "target": "<target>",
    "origin": "feature"
  },
  {
    "family": "review",
    "review": "rtl_bugs",
    "verdict": "clean",
    "origin": "feature"
  },
  {
    "family": "review",
    "review": "tb_quality",
    "verdict": "clean",
    "origin": "feature"
  }
]
```
