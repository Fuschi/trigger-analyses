# Project instructions

## Purpose

This repository contains reproducible analyses of environmental, wearable,
GPS, and sleep data collected in LongCLAVIS within the European TRIGGER
project.

Treat this as a scientific analysis repository, not as a general-purpose
application. Correctness, traceability, and explicit analytical assumptions
are more important than compact or clever code.

## Before making changes

- Read `README.md` and the relevant files under `docs/` before changing a
  workflow.
- Read the complete source notebook before modifying an analysis.
- Inspect the input schema and existing analytical keys before changing data
  transformations or joins.
- Preserve unrelated local and user-authored changes.
- Make the smallest coherent change that fully addresses the request.

## Repository boundaries

- `data/download_data.py` is the only production workflow allowed to access
  the TRIGGER API.
- Analysis notebooks must read local files from `data/` and must not download
  data or query the API.
- Downloaded datasets, credentials, local logs, and `.Renviron` are local
  artifacts and must not be committed.
- Analysis sources and their self-contained HTML reports are version controlled
  under `analyses/`.
- Do not create a separate output directory, GitHub Markdown render, or
  version-controlled figure directory.
- Never place personally identifying information, API credentials, or raw
  participant-level data in documentation, tests, examples, logs, or commits.

## Scientific integrity

- Do not silently change inclusion criteria, quality-control thresholds,
  variable definitions, temporal aggregation rules, or statistical models.
- Give every non-obvious threshold a named value and document its unit,
  rationale, and analytical consequence.
- Distinguish exploratory visualization from formal statistical inference.
- Do not describe an association as causal unless the design and analysis
  support a causal interpretation.
- Preserve subject-level and repeated-measure structure. Do not treat repeated
  observations as independent during formal inference.
- Report data loss caused by filtering, duplicate removal, missingness, or
  quality control whenever it can affect interpretation.
- Prefer deterministic transformations. Set and document random seeds for
  stochastic procedures.
- Never fabricate results when local data or dependencies are unavailable.

## Analytical data conventions

- Unless an analysis explicitly requires a different window, include only
  dates strictly after 2025-03-01 and strictly before `Sys.Date()`. Earlier
  records were collected during testing, and the current day may be incomplete.
- Use the five-minute bucket as the canonical temporal unit across data
  streams. For availability and coverage, one or multiple raw measurements
  within the same participant, variable, and five-minute bucket count as one
  observed bucket.
- Express high-resolution coverage primarily as observed five-minute buckets.
  Convert buckets to minutes or hours only as a clearly labelled derived
  quantity.
- Use `userId` and the appropriate time bucket as explicit analytical keys.
- Assert the expected join relationship, such as `relationship = "one-to-one"`,
  whenever supported.
- Investigate duplicate keys before choosing how to resolve them. If their
  origin is ambiguous, prefer excluding all affected rows and report the
  number removed.
- Keep timestamps in UTC unless an analysis explicitly requires another time
  zone. Document any conversion.
- Keep measurement units in variable labels, table headings, and explanatory
  text.
- Retain coverage or observation-count variables needed to assess the quality
  of temporal summaries.
- Do not use raw-reading counts as analytical weights unless the scientific
  rationale explicitly requires it.

## Code organization

- Keep analyses linear and focused on analytical narrative, transformations,
  results, and figures.
- During the exploratory phase, write import, variable selection, quality
  control, feature engineering, and other transformations explicitly inside
  each analysis, even when this duplicates code.
- Do not create general or pre-established R helper functions for these steps
  unless the user explicitly asks for them. The variables and rules are still
  analysis-specific and expected to change frequently.
- When modifying existing functions or working in the Python download
  workflow, keep functions small and give each one a clear responsibility.
- Separate input validation, transformation, modelling, and output writing.
- Avoid hidden global state and implicit working-directory changes.
- Use project-root-relative paths and construct them in one configuration
  block.
- Use descriptive names. Prefer clarity over abbreviations.
- Keep user-facing documentation, code comments, messages, and identifiers in
  English.

## R style

- Follow tidyverse style and use two-space indentation.
- Use `<-` for assignment and `TRUE`/`FALSE` instead of `T`/`F`.
- Put spaces around infix operators and after commas.
- Use snake_case for objects and functions.
- Prefer compact, readable code. Keep short expressions, function calls, and
  argument lists on one line when they remain easy to scan; introduce line
  breaks only when they materially improve readability.
- Use `%>%` consistently in existing tidyverse pipelines.
- Use explicit package namespaces in reusable code when they clarify the
  dependency, for example `stats::`, `mgcv::`, or `ThermIndex::`.
- Use `library()` calls only in notebook setup chunks.
- Fail early with clear, actionable validation errors.
- Document exported or reusable functions, including inputs, outputs, units,
  assumptions, and missing-value behaviour.
- Keep plotting data preparation separate from plot construction when either
  step is non-trivial.

## Python style

- Follow PEP 8 and use four-space indentation.
- Use type hints for new and modified reusable functions.
- Use `pathlib.Path` for filesystem paths.
- Use context managers for external resources and connections.
- Validate inputs early and raise specific exceptions with actionable
  messages.
- Keep API access, transformation, and persistence in separate functions.
- Use logging for reusable workflows and reserve `print()` for intentional CLI
  progress output.
- Avoid broad exception handling unless processing must continue per table or
  per item; record enough context to diagnose each failure.
- Do not add a dependency when the standard library or an existing dependency
  provides a clear solution.

## Notebook conventions

- Store analyses as consistently named `.qmd` files directly under
  `analyses/`.
- Treat analyses as independent documents and do not prefix filenames with an
  artificial execution or reading order.
- Start with one setup chunk containing libraries and a `cfg` object.
- Describe the analytical decision before the code that implements it.
- Display coverage summaries before interpreting model output or figures.
- Give tables and figures informative titles, labels, units, and captions.
- Avoid embedding API calls, secrets, absolute user paths, or environment-
  specific values.
- Render only self-contained HTML. Do not manually edit generated `.html`
  files; regenerate them from the `.qmd` source.

## Dependencies and environments

- Python dependencies belong in `requirements.txt` and should be pinned when
  reproducibility requires it.
- R dependencies must be documented in `docs/SETUP.md`; prefer using `renv`
  when dependency management is introduced.
- Do not modify the user's `.Renviron`, Python environment, or global R library
  unless the request explicitly requires it.
- Explain and justify any new runtime dependency.

## Validation and tests

- Add targeted tests for reusable transformations and bug fixes when a test
  framework is available.
- At minimum, test analytical-key uniqueness, join cardinality, boundary
  values, missing values, and invalid sensor measurements when relevant.
- Prefer small synthetic fixtures over copies of real participant data.
- Run the narrowest relevant checks first, followed by broader checks when
  feasible.
- For Python changes, at least perform a syntax/import check on modified
  modules.
- For notebook changes, render the affected notebook when the required local
  data and dependencies are available.
- Render HTML as described in `docs/RENDERING.md`.
- If a notebook cannot be rendered because data or credentials are absent,
  report that limitation explicitly and do not invent or hand-edit outputs.

## Review checklist

Before considering a change complete, verify that:

- analytical assumptions are explicit;
- keys and join cardinalities are preserved;
- missing and invalid values are handled intentionally;
- paths are project-relative;
- names are consistent across source and output directories;
- documentation reflects the implemented workflow;
- no sensitive or generated local data were added;
- relevant checks or renders were run, with any limitations reported.
