# Run 2 LaTeX slides

- [PDF: 17 pages](output/calibration_steps_2009_2024_fixed_mean_labor.pdf)
- [Self-contained source](latex/main.tex): editable Beamer, equations and 29 native PGFPlots; no external graphics/data needed to compile.
- [Plot data](.build/slide_series.csv), [annual growth data](.build/slide_growth.csv), [chart manifest](.build/latex_chart_manifest.json).
- [Compilation, plot and preservation checks](.build/quality_checks.json).

The deck reports the constant-input rule, population means and wage bridge, P1–P5, the joint fit, the relative-wage diagnostic, a Run 1/Run 2 comparison, the constrained fit and the final parameter ledger. The P4 page retains the requested X/Y and L/Y panels alongside effective coefficients and datewise augmentation.

To rebuild only this saved source, run `latexmk -norc -pdf -interaction=nonstopmode -halt-on-error -outdir=../.build/latex main.tex` from `latex/`. To regenerate the source from the numerical results, use the shared workflow in the [run index](../../../README.md). The generator is `../../../shared/build_slides.py` relative to this folder; direct source edits are replaced on regeneration.
