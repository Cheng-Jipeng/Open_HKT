# Run 3 LaTeX slides

- [PDF: 17 pages](output/calibration_steps_2009_2024_normalized_skilled_labor.pdf)
- [Self-contained source](latex/main.tex): editable Beamer, equations and 29 native PGFPlots; no external graphics/data needed to compile.
- [Plot data](.build/slide_series.csv), [annual growth data](.build/slide_growth.csv), [chart manifest](.build/latex_chart_manifest.json).

Same layout and page sequence as the Run 2 deck: the normalization rule (H=1, L=observed L/H) and wage bridge, P1–P5, the joint fit, the relative-wage diagnostic, a three-run comparison, the constrained fit and the final parameter ledger.

To rebuild only this saved source, run `latexmk -norc -pdf -interaction=nonstopmode -halt-on-error -outdir=../.build/latex main.tex` from `latex/`. To regenerate from the numerical results, use the shared workflow in the [run index](../../../README.md). The generator is `../../../shared/build_slides.py`; direct source edits are replaced on regeneration.
