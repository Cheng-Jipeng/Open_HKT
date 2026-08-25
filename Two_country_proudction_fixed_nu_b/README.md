# Fixed-`nu_b` two-country production workflow

This directory is an independent counterfactual workflow. It holds
`nu_b = 1.0 = xi_W` fixed at every absorbing successor and does not impose the
common-world-growth condition. The reference implementation and notebooks in
`../Two_country_production_common_growth` are read-only inputs.

## Files

- `TwoCountryProductionOLG.jl`: fixed-`nu_b` solver. The compatibility field
  `BGPResult.nu_b_eff` always equals the primitive `ProductionParams.nu_b`.
  `common_world_growth=true` and `calibrate_common_growth` are rejected.
- `01_v9_unbalanced_branch_fixed_nu_b.ipynb`: replication of source Notebook
  03, including state-matched switch-to-`b` labor allocations for the US and
  RoW. With the source-03 calibration otherwise unchanged, the verified
  no-buffer continuation ends at `T=20`; this calibration violates
  `nu_u > nu_b`, so equilibrium results are reported without theorem-based
  bubble certification.
- `02_v9_ahp_hkt_scalar_tail_bubble_bounds_fixed_nu_b.ipynb`: fixed-`nu_b`
  replication of source Notebook 17 under the AHP-matching calibration. It
  plots and exports the common-growth-implied time-varying exponent as a
  reference series that is never fed into the solver.
- `03_v9_ahp_pattern_T110_replication_fixed_nu_b.ipynb`: fixed-`nu_b`
  replication of source Notebook 19. Its three sibling `.jl` files implement
  the `T=110` continuation, the `T=105` persistence/risk-aversion sweeps, and
  the `T=100` portfolio/NFA sweeps.

All generated CSVs and figures are isolated under `outputs_fixed_nu_b/`.

## Calibration and interpretation

Notebooks 02 and 03 preserve the source AHP calibration except for
`nu_b=1.0` and `common_world_growth=false`; `xi_W` was already 1.0. Equality to
the source common-growth AHP path is therefore a comparison diagnostic, not a
replication gate. Direct equilibrium accounting uses `NFA = A - Q_US`.

The theoretical lower bubble-share curves remain conditional whenever the
independent HKT entry gate fails. A finite-envelope pass is not labelled as an
infinite-horizon certificate.

## Execution

From `Codes/`:

```sh
jupyter nbconvert --to notebook --execute --inplace \
  Two_country_proudction_fixed_nu_b/01_v9_unbalanced_branch_fixed_nu_b.ipynb \
  --ExecutePreprocessor.timeout=900

jupyter nbconvert --to notebook --execute --inplace \
  Two_country_proudction_fixed_nu_b/02_v9_ahp_hkt_scalar_tail_bubble_bounds_fixed_nu_b.ipynb \
  --ExecutePreprocessor.timeout=1800

jupyter nbconvert --to notebook --execute --inplace \
  Two_country_proudction_fixed_nu_b/03_v9_ahp_pattern_T110_replication_fixed_nu_b.ipynb \
  --ExecutePreprocessor.timeout=1800
```

Notebook 03 uses a bounded 60-sweep comparative-static retry by default and
exports unresolved points as numerically unavailable. To reproduce the source
notebook's exhaustive retry schedule, set
`NB03_FIXED_NU_B_SWEEP_BRANCH_ITER_SCHEDULE=60,200,500,1000`.

