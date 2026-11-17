# Calibration R1: run index

The two 2009–2024 exercises now have separate folders. Run 1 is preserved; Run 2 was executed with skilled and unskilled labor fixed at their separate sample means. Both retain rho=2 and the same observed monetary and premium series.

| Run | Labor treatment | Results and report | LaTeX slides |
| --- | --- | --- | --- |
| [01 — observed labor](runs/01_observed_labor/README.md) | Annual H_t and L_t | [Original report](runs/01_observed_labor/report.md), [results](runs/01_observed_labor/results) | [PDF](runs/01_observed_labor/slides/output/calibration_steps_2009_2024_latex.pdf), [source](runs/01_observed_labor/slides/latex/calibration_steps_2009_2024.tex) |
| [02 — fixed mean labor](runs/02_fixed_mean_labor/README.md) | H=32.828090 and L=71.180553 million | [New report](runs/02_fixed_mean_labor/README.md), [results](runs/02_fixed_mean_labor/results), [comparison](runs/02_fixed_mean_labor/results/run_comparison.csv) | [PDF](runs/02_fixed_mean_labor/slides/output/calibration_steps_2009_2024_fixed_mean_labor.pdf), [source](runs/02_fixed_mean_labor/slides/latex/main.tex) |
| [03 — normalized skilled labor](runs/03_normalized_skilled_labor/README.md) | H=1 and L_t = observed L_t/H_t (annual ratio) | [Report](runs/03_normalized_skilled_labor/README.md), [results](runs/03_normalized_skilled_labor/results), [three-run comparison](runs/03_normalized_skilled_labor/results/run_comparison.csv) | [PDF](runs/03_normalized_skilled_labor/slides/output/calibration_steps_2009_2024_normalized_skilled_labor.pdf), [source](runs/03_normalized_skilled_labor/slides/latex/main.tex) |

**Status:** both external baselines remain `REJECTED_P1`. At the diagnostic markup 3.5, fixing labor changes the joint spillovers from xi=-0.1363, nu=1.6833 to xi=1.0669, nu=1.1814. The ordering xi>nu still fails. Conditional fits are not adopted full-model calibrations.

**Run 3 (added 2026-11-13):** normalizing H=1 with L equal to the observed annual L/H ratio leaves P1 identical to Run 1 (`REJECTED_P1`, markup floor 2.8148). At markup 3.5 the joint fit gives xi=1.3377, nu=3.4110: both positive, but xi−nu=−2.0733, close to Run 1. Rebuild with the Run 2 command below, replacing the run folder by `runs/03_normalized_skilled_labor`. The shared scripts were extended for this treatment; Run 2 results, report and LaTeX source regenerate byte-identically with the extended code (only code hashes in its `input_manifest.csv` would change), and its saved files were not rewritten.

## Organization

```text
Do/
  README.md                   This run index
  runs/
    01_observed_labor/         First run: results, slides, diagnostics, code snapshot
    02_fixed_mean_labor/       Second run: inputs, config, results, slides, report
    archive/                  Older runs and the historical 1994–2022 P1 diagnosis
  shared/
    *.py, requirements.txt    Active calibration and reporting implementation
    references/               Data mappings, source evidence and methodological audits
    maintenance/              Relocation record and backups of changed path metadata
```

Use the explicit run folders above. The loose top-level compatibility shortcuts and redundant launcher have been removed. Numerical results, figures and PDFs from both runs are unchanged. Earlier links that used `Do/Slides` or `Do/results` should now use `runs/01_observed_labor/slides` or `runs/01_observed_labor/results`.

## What the remaining material is for

| Earlier item | Role | Current location / deletion guidance |
| --- | --- | --- |
| `Slides`, `results`, `Spillover_Diagnosis`, `config.json` at the top level | Shortcuts to Run 1, not separate outputs | Redundant shortcuts removed; the actual files remain in Run 1 |
| Top-level `calibration.py`, `test_calibration.py`, `requirements.txt` | Shortcuts to shared implementation | Redundant shortcuts removed; keep the active files in `shared/` |
| Top-level `run_calibration.py` | Small launcher forwarding to the shared runner | Removed; call `shared/run_calibration.py` directly |
| Audit notes, reference conversation, source-validation tables, curvature rationale | Research provenance: definitions, equations, sources and parameter choices | Consolidated in [shared/references](shared/references/README.md); retain for reproducibility |
| `archive/` | Earlier code/configuration/results snapshots | Moved to [runs/archive](runs/archive/README.md); not needed to execute Run 2, but retain to reproduce older findings |
| `P1_Diagnosis/` | Historical 1994–2022 investigation of the allocation failure | Moved into `runs/archive/P1_Diagnosis_1994_2022/` with its results |
| `__pycache__/` | Automatically generated Python bytecode | Removed; safe to delete whenever regenerated |

The reference files are substantive evidence, not temporary files. The historical archives are optional for executing the current run but are the record of earlier specifications and findings. Deleting either category would discard that evidence. The dated [maintenance record](shared/maintenance/2026-10-17_structure_cleanup/README.md) documents the moves, saved originals and verification.

Historical generators inside archived snapshots retain their original execution assumptions. The latest historical P1 diagnosis has its input paths adjusted to the new location; its saved numerical results have not been regenerated. The active workflow remains in `shared/`. The common empirical-data package is unchanged.

## Rebuild Run 2

From this `Do` directory:

```sh
uv run --no-project --python 3.12 --with-requirements shared/requirements.txt python -B shared/rebuild.py --run runs/02_fixed_mean_labor
```

The command performs calibration, numerical checks, report generation, slide-evidence generation and LaTeX compilation. It writes only Run 2 outputs. `latexmk`/pdfLaTeX must be installed for PDF export; the editable source remains available if compilation is unavailable. Numerical dependencies are pinned in `shared/requirements.txt`.

For calibration only:

```sh
uv run --no-project --python 3.12 --with-requirements shared/requirements.txt python -B shared/run_calibration.py --run runs/02_fixed_mean_labor
```

Run 2 freezes only quantities/parameters classified as exogenous in this production block. Observed output, compensation, valuation and the premium remain annual endogenous-outcome targets. Wages are recomputed with the fixed labor quantities so compensation and the premium remain matched exactly. See its variable-role ledger and report for the remaining population/cohort, sector and model-period mapping limits.
