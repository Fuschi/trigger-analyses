# Rendering analyses

Analyses are rendered only as self-contained HTML files. Figures,
styles, and other resources are embedded in each HTML document, so rendering
does not create version-controlled support directories.

From the project root, render all analyses with:

```bash
quarto render
```

Alternatively, from the R console:

```r
quarto::quarto_render()
```

To render a single analysis:

```bash
quarto render analyses/particle_quality_control.qmd
```

Project-wide rendering includes only:

```yaml
project:
  render:
    - analyses/*.qmd
```

The HTML file is written next to its `.qmd` source. Do not manually edit the
generated HTML; regenerate it from the source notebook.
