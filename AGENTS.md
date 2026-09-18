# Project instructions

## Goal and working method

- Build reproducible LongCLAVIS/TRIGGER analyses for a scientific article and slides.
- Work incrementally on the specific task requested, one notebook at a time.
- Do not recreate deleted notebooks or expand the scope without an explicit request.
- Preserve user changes. Read relevant documentation and source before editing.
- Do not modify this file again unless the user explicitly requests it.

## Code and files

- Keep code simple, compact and direct; use original variable names and avoid presentation-only formatting.
- Use English for code, comments and project documentation.
- In R, use tidyverse style, two-space indentation, `<-` and `%>%`.
- Use shared readers in `R/`; keep analytical decisions explicit in notebooks.
- Use project-relative paths and local files in `data/`. Only `data/download_data.py` may access the API.
- Keep `.qmd` sources and self-contained HTML reports in `analyses/`; regenerate HTML from source.
- Never commit credentials or downloaded data, or expose participant identifiers in reports.

## Scientific correctness

- Default study window: dates strictly after 2025-03-01 and before the current day; timestamps in UTC.
- Use `userId` and the appropriate time key; check duplicate keys and join cardinality.
- Count coverage in distinct five-minute participant-variable buckets, not raw readings.
- Preserve units, coverage information and repeated-measure structure.
- Make filtering, missingness, thresholds and exclusions explicit; do not silently change analytical rules.
- Distinguish exploratory associations from inference and causality; never invent results.
- Run relevant checks and render modified notebooks when feasible; report any limitations.
