# Run 1: observed annual labor, 2009–2024

This folder preserves the first run with time-varying skilled and unskilled employment. Its numerical results, report, slide sources/PDFs, original code snapshot and spillover diagnosis are unchanged.

- [Original calibration report](report.md)
- [LaTeX slide PDF](slides/output/calibration_steps_2009_2024_latex.pdf)
- [Editable LaTeX source](slides/latex/calibration_steps_2009_2024.tex)
- [Numerical results](results)
- [Spillover diagnosis](diagnostics/spillover/README.md)
- [Original code snapshot](code_snapshot)
- [195-file preservation manifest](preservation_manifest.json)
- [Run 2: fixed mean labor](../02_fixed_mean_labor/README.md)

The external baseline is `REJECTED_P1`. At diagnostic markup 3.5 and rho=2, the joint fit has xi=-0.136299 and nu=1.683308. These are conditional estimates, not an accepted calibration.

Historical generators retain the original directory assumptions and are kept as source history. To rebuild this self-contained LaTeX PDF, run `latexmk -pdf calibration_steps_2009_2024.tex` from `slides/latex/`, writing new build files to a separate output directory if preserving the snapshot. The active shared workflow is documented in the [run index](../../README.md).
