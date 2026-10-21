# V6 external-calibration literature review

Review date: 27 September 2026.

The authoritative definitions are in ../V6_parameter_calibration_groups.tex.
The completed standalone source is ../V6_external_calibration_literature_review.tex;
the adjacent PDF is its compiled delivery. This review does not modify or estimate the model.

Scope: 11 families / 19 scalar parameters in Group A and the free externally disciplinable
part of Group B. Labor endowments, Group C, and imposed zero exponents are excluded from
conventional-value searches.

## Evidence and reproducibility

- The review Markdown/JSON files, supplements, and growth_bibliography.json retain detailed source checks.
- source_ledger.json/.csv contains 31 referenced sources, original links, and version-specific locators.
- scite_bibliography_raw.json and scite_references_raw.bib preserve connector metadata unchanged;
  the final ledger corrects online-versus-issue years and pins the versions actually used.
  Original-paper author metadata takes precedence over connector errors (notably
  James A. Kahn and Laura Bottazzi).
- Connector logs record successful Consensus/Scite/Undermind retrievals and Wiley Gateway failures.
  The completed Undermind search returned 175 ranked discovery records; the review does not claim
  that all 175 were read or verified.
- The six TeX assembly fragments are preamble_intro, preference_tables, production_tables,
  growth_tables, scale_tables, and recommendations.
- Run build_review.py from this directory to assemble the standalone TeX source and ledgers.
- Compile from Calibration_R1 using the relative source filename with latexmk and
  output directory build/external_review.
- The final artifact uses no external TeX inputs or bibliography files.
- source_hashes_before.json, manifest.json, and validation.json document preservation,
  coverage, compilation, arithmetic checks, and visual inspection.

## Interpretation

Point estimates, imposed calibrations, population percentiles, statistical intervals,
meta-analysis summaries, normalizations, and analyst scenario grids remain distinct.
The final recommendations are conditional research candidates, not a validated calibration
vector. Unassigned empirical values are intentional when no accurate numerical transfer
is supported. Fitting production moments is still a model-based calibration step, even
when it is external to the international-finance target block.

Independent economic audits checked the parameter definitions, inverse markups, CES
mapping, period conversion, reference continuity, and scalar coverage. They corrected
the distinction between theorem and solver restrictions and added the active-research
condition required for recovering innovation productivity.
