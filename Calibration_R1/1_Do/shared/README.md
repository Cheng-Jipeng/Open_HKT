# Shared calibration and reporting

| File | Responsibility |
| --- | --- |
| `calibration.py` | Unchanged P1–P5 equations, sequential estimates, profiled joint fit and fitted paths from Run 1 |
| `input_rules.py` | Select fitting years, average each labor series and reconstruct wages; validate constant primitives |
| `diagnostics.py` | Relative-wage slope decomposition and profiled closed-cone fit |
| `run_calibration.py` | Execute the explicitly configured fixed-mean comparison, write results and input provenance |
| `test_calibration.py` | Synthetic recovery, timing/units, averaging and wage identities; reproduce and preserve Run 1 |
| `build_report.py` | Render the result report from saved estimates |
| `prepare_slide_data.py` | Freeze plotted series and source hashes from saved numerical outputs |
| `build_slides.py` | Native Beamer/PGFPlots; auto-scale axes to visible data and report plotted coordinates |
| `rebuild.py` | Run the complete sequence and export the PDF with latexmk |

The current comparison/report workflow is explicitly dated to 2009–2024, rho=2, diagnostic markup 3.5. Extending the data vintage or changing that specification requires reviewing the date-specific narrative and scenario labels as well as config.json. It is a conditional US production-block workflow, not a two-country general-equilibrium solver.

The core accepts annual targets for endogenous variables. The new input rule freezes exogenous labor stocks and all fitted/assigned scalar parameters within each scenario. It never freezes knowledge, production/research allocations or augmentation paths. All diagnostics and figures are run-specific; do not run historical generators against the new directory structure.

## Supporting material

- [references/](references/README.md): empirical definitions, original-source checks, external-parameter choices and equation audits. These are research documentation, not temporary build files.
- [maintenance/2026-10-17_structure_cleanup/](maintenance/2026-10-17_structure_cleanup/README.md): relocation manifest, original versions of path metadata and verification that numerical artifacts are unchanged.

Run folders and older snapshots are indexed in [the Do README](../README.md). The shared runner is called directly; there is no top-level compatibility launcher.
