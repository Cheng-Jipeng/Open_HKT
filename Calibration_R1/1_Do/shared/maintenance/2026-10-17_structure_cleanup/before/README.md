# Calibration R1: run index

The two 2009–2024 exercises now have separate folders. Run 1 is preserved; Run 2 was executed with skilled and unskilled labor fixed at their separate sample means. Both retain rho=2 and the same observed monetary and premium series.

| Run | Labor treatment | Results and report | LaTeX slides |
| --- | --- | --- | --- |
| [01 — observed labor](runs/01_observed_labor/README.md) | Annual H_t and L_t | [Original report](runs/01_observed_labor/report.md), [results](runs/01_observed_labor/results) | [PDF](runs/01_observed_labor/slides/output/calibration_steps_2009_2024_latex.pdf), [source](runs/01_observed_labor/slides/latex/calibration_steps_2009_2024.tex) |
| [02 — fixed mean labor](runs/02_fixed_mean_labor/README.md) | H=32.828090 and L=71.180553 million | [New report](runs/02_fixed_mean_labor/README.md), [results](runs/02_fixed_mean_labor/results), [comparison](runs/02_fixed_mean_labor/results/run_comparison.csv) | [PDF](runs/02_fixed_mean_labor/slides/output/calibration_steps_2009_2024_fixed_mean_labor.pdf), [source](runs/02_fixed_mean_labor/slides/latex/main.tex) |

**Status:** both external baselines remain `REJECTED_P1`. At the diagnostic markup 3.5, fixing labor changes the joint spillovers from xi=-0.1363, nu=1.6833 to xi=1.0669, nu=1.1814. The ordering xi>nu still fails. Conditional fits are not adopted full-model calibrations.

## Organization

```text
Do/
  shared/                 Active reusable calibration, diagnostics, tests and reporting
  references/             Common data/source audits and external-parameter rationale
  runs/
    01_observed_labor/
      results/            Preserved original numerical outputs
      slides/             Preserved PDF, editable LaTeX, PPTX and historical generators
      diagnostics/        Original spillover diagnosis
      code_snapshot/      Original calibration implementation and config
      report.md           Original report, unchanged
      preservation_manifest.json
    02_fixed_mean_labor/
      config.json         Explicit rule, fixed sample and constant primitive choices
      inputs/             Frozen observed panel copied from Run 1
      results/            New fits, feasibility checks, sensitivities and audit tables
      slides/
        latex/main.tex    Editable, self-contained Beamer/PGFPlots
        output/           Exported PDF
        .build/           Plot evidence, manifest and compiler working files
      README.md           Run report with formulas and interpretation
  archive/                Earlier dated results, including the 1994–2022 exercise
  P1_Diagnosis/            Historical accounting diagnosis tied to that older archive
```

The original `results`, `Slides`, `Spillover_Diagnosis` and `config.json` paths are compatibility links to **Run 1**, so previous PDF/file references continue to work. Top-level audit notes link to `references/`; `calibration.py`, `requirements.txt` and `test_calibration.py` link to `shared/`. The top-level runner delegates to the shared runner and requires an explicit `--run` directory. Original plotting/report scripts are retained in Run 1's `code_snapshot/`.

Historical slide/report generators inside Run 1 are preserved for provenance; they retain their original working-directory assumptions. Use its self-contained `.tex` to rebuild its PDF, or the new shared workflow for Run 2. The common empirical source package was not moved. All 195 files listed in the Run 1 preservation manifest were verified unchanged after relocation.

## Rebuild Run 2

From this `Do` directory:

```sh
uv run --no-project --python 3.12 --with-requirements shared/requirements.txt python -B shared/rebuild.py --run runs/02_fixed_mean_labor
```

The command performs calibration, numerical checks, report generation, slide-evidence generation and LaTeX compilation. It writes only Run 2 outputs. `latexmk`/pdfLaTeX must be installed for PDF export; the editable source remains available if compilation is unavailable. Numerical dependencies are pinned in `shared/requirements.txt`.

For calibration only:

```sh
uv run --no-project --python 3.12 --with-requirements shared/requirements.txt python -B run_calibration.py --run runs/02_fixed_mean_labor
```

Run 2 freezes only quantities/parameters classified as exogenous in this production block. Observed output, compensation, valuation and the premium remain annual endogenous-outcome targets. Wages are recomputed with the fixed labor quantities so compensation and the premium remain matched exactly. See its variable-role ledger and report for the remaining population/cohort, sector and model-period mapping limits.
