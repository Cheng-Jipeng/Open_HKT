# Fixed-nu_b / recalibrated-xi_W common-growth replication

This directory is an isolated counterfactual fork of
`Two_country_production_common_growth`. The source directory is not read for
calibration artifacts and is not modified.

## Equilibrium selection

The U.S. absorbing-regime exponent is fixed at `nu_b = 0.10`. At every
candidate switch state, the solver recalibrates a local post-switch
`xi_W_eff` so that

```text
nu_b * log(G_N_US) = xi_W_eff * log(G_N_W),
```

equivalently `G_b = G_W`. The all-u branch continues to use the primitive
RoW seed `xi_W = 1.00`; the state-specific `xi_W_eff` is fed only to the
corresponding absorbing-regime solve.

## Shared AHP calibration

All three notebooks use

```text
beta=0.45, gamma=0.25, pi=0.75,
a_US=0.20, vartheta_US=0.85,
a_W=0.06, H_W=L_W=3,
A_X_US_u=15, A_L_US_u=1.5,
nu_b=0.10, nu_u=1.75, xi_u=2.25, xi_W=1.00,
omega_bar=0.50, omega_bar_star=0.25,
kappa=1, chi=0.0002, eta=0.010.
```

## Files

- `TwoCountryProductionOLG.jl`: fixed-`nu_b`, state-specific-`xi_W`
  solver.
- `01_v9_unbalanced_branch_recal_xi_W.ipynb`: `T=100` unbalanced branch,
  including state-matched switch-to-b `varphi` for the U.S. and RoW.
- `02_v9_ahp_hkt_scalar_tail_bubble_bounds_recal_xi_W.ipynb`: residual-safe
  horizon search and conditional HKT tail diagnostics, including the requested
  time-varying post-switch `xi_W_eff` plot and CSV.
- `03_v9_ahp_pattern_T110_replication_recal_xi_W.ipynb`: warm-continuation
  `T=110` AHP replication and the inherited parameter sweeps.
- `04_nu_b_sweep_diagnostics_recal_xi_W.ipynb`: fixed-`nu_b` sweep over
  `[0.1, 0.5, 1.0, 1.3]`, organized according to
  `Reference_notes/On_Calibration_variablet_set.md`. It reports each case's
  residual-safe no-buffer horizon, all-`u` and realized switch paths, HKT
  finite-prefix quantities, exact NFA `VA`/`CA` accounting, and the
  finite-horizon leakage-product diagnostic. An opening comparison plots the
  state-specific recalibrated `xi_W_eff` paths for every `nu_b` case.
- `04_nu_b_sweep_diagnostics_recal_xi_W.jl`: local definitions, numerical
  search, plotting, export, and verification functions used by Notebook 04.
- `julia_env/`: isolated Julia environment used by the notebooks.
- `outputs_recal_xi_W/`: generated CSV and PNG artifacts.

## Numerical interpretation

The baseline `T=110` solve uses the model's uncapped default nonlinear-solver
budget. The inherited robustness sweeps use a separately documented cap of
100 inner nonlinear iterations: the uncapped 4,000-iteration sweep policy
exceeded a 7,200-second notebook-cell timeout at a near-boundary parameter
point. The cap and branch budgets are exported in
`sweep_numerical_budget.csv` and
`nfa_sweep_T100_numerical_budget.csv`; cases that do not pass are retained as
numerically unavailable rather than interpolated.

Strict feasibility requires `0 < theta_US_star < 0.9`. The source notebook's
more conservative one-percent interiority screen is retained as a separate
diagnostic. Finite-horizon tail intervals remain conditional unless their
independent future-envelope premises are certified.

Notebook 04 uses a common realized switch date `tau=5`, since the larger
`nu_b` calibrations reach residual-safe horizons shorter than the 15-period
AHP evidence window. Its reported `T_max` values are connected numerical
continuation frontiers, not existence or non-existence results. All
calibration failures and solver budgets are retained in
`outputs_recal_xi_W/04_nu_b_sweep_diagnostics/horizon_search_attempts.csv`.
