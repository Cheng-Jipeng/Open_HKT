# Structure cleanup, 17 October 2026

This change consolidates all content below `runs/` and `shared/`, leaving only the main README alongside them. It does not change calibration equations, empirical observations, estimated parameters or slide/PDF contents.

- Shared references: `Do/references` → `Do/shared/references`.
- Older snapshots: `Do/archive` → `Do/runs/archive`.
- Historical diagnosis: `Do/P1_Diagnosis` → `Do/runs/archive/P1_Diagnosis_1994_2022`.
- Fourteen redundant top-level symbolic links and the forwarding launcher were removed. Their destinations remain intact.
- Three generated `.pyc` files in the top-level Python cache were removed.
- Current documentation, reference paths and presentation provenance were updated. The historical diagnosis's path constants were updated without rerunning it.

`relocation_manifest.json` records original hashes, moves, removed shortcut targets and the exact before-state backups in `before/`. `verification.json` records post-move checks. These are organization records, not a new calibration run. The before-state material supports recovery of the old path metadata; numerical output files were not overwritten.
