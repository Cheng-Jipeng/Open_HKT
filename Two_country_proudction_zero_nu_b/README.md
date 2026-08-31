# Zero-exponent two-country production workflow

This directory replicates the three notebooks in
`Two_country_proudction_fixed_nu_b` with the absorbing exponents fixed at
`nu_b = xi_W = 0`.

The specialization is structural, not just a parameter override:

- The absorbing equilibrium has seven unknowns and seven equations.
- `G_N_US^0 = G_N_W^0 = 1` is an identity. It contributes no residual,
  unknown, calibration step, or root-finding dimension.
- One absorbing equilibrium is solved at the normalized state `(1, 1)` for
  each parameterization.
- Its policies, returns, incomes, and aggregate quantities are reused at every
  inherited knowledge state. Per-variety prices and dividends are restated as
  `q_i = qbar_i / N_i` and `d_i = dbar_i / N_i`.
- The legacy `nu_b_eff` record slot is a fixed zero compatibility value. It is
  never an endogenous or switch-specific object.

## Notebooks

1. `01_v9_unbalanced_branch_zero_nu_b.ipynb`
2. `02_v9_ahp_hkt_scalar_tail_bubble_bounds_zero_nu_b.ipynb`
3. `03_v9_ahp_pattern_T110_replication_zero_nu_b.ipynb`
4. `04_phi_spillover_funding_sweeps_zero_nu_b.ipynb`
5. `05_nu_u_funding_regime_sweeps_zero_nu_b.ipynb`
6. `06_post2008_ahp_nfa_calibration_search_zero_nu_b.ipynb`

Notebook 03 includes three local Julia support scripts. Their filenames retain
the source notebook names for traceability.

Notebook 04 is a finite-horizon comparative-static diagnostic for the
increasing `phi_US` all-`u` path. It lowers `nu_u` and raises `xi_u` one at a
time, reports the exact funding-versus-production endpoint decomposition and
the `kappa_D`/`kappa_S` trade-off, and plots all-`u` against switch-to-`b`
`phi_US` and `phi_W`. It also compares the funding identity
`zeta_t = 1 + A_t - B_t` over the joint sweep
`nu_b = xi_W in {0, 0.25, 0.5, 0.75, 1}`, using the specialized zero solver
at zero and the isolated fixed-exponent solver at each positive point. The
equivalent relative-scale decomposition reports `m_t = e_W/e_US`,
`mu_t = Q_W/e_W`,
and `zeta_t = 1 + (m_t/beta)(s_W-mu_t)`, including an exact endpoint split
between relative scale and the RoW capitalization wedge. For the same
five-point exponent sweep, it also plots the all-`u` and switch-to-`b` paths
of `phi`, `e`, `Q`, `q`, and `N` for both the U.S. and RoW (20 regime-country
objects) and exports all underlying levels. Its generated files are written below
`outputs_zero_nu_b/04_phi_spillover_funding_sweeps/`.

Notebook 05 applies the four-section calibration-sweep structure in
`Reference_notes/On_Calibration_variablet_set.md` while holding
`nu_b = xi_W = 0`, `xi_u = 2.25`, and sweeping
`nu_u in {1.25, 1.00, 0.75}`. It reports case-specific residual-safe,
no-buffer horizons up to `T=80`; plots the 20 all-`u` and realized
switch-to-`b` growth objects with an explicit switch date; and adds the U.S.
stock-funding, finite-prefix HKT, NFA VA/CA, and bubble-leakage diagnostics.
Its outputs are written below
`outputs_zero_nu_b/05_nu_u_funding_regime_sweeps/`.

Notebook 06 loads the post-2008 AHP targets directly from `Empirical_Data` and
runs a declared nested-continuation search over `pi`, `omega_bar`,
`omega_bar_star`, and `eta`, holding `nu_b = xi_W = 0` and the production block
fixed. Its preferred `T=16` point is a qualitative liability-valuation match,
not a quantitative calibration: U.S. NFA deteriorates, U.S. equity appreciates,
and the liability term accounts for most gross valuation effects, but the model
gross positions and flow magnitudes remain far below the empirical targets.
The default run records only the certified empirical prefix; set
`NB06_RUN_LONG_HORIZON_AUDIT=true` for the opt-in horizon continuation and
`NB06_RUN_DIRECT_COLD_CHECK=true` for the potentially slow direct-jump check.
Outputs are written below
`outputs_zero_nu_b/06_post2008_ahp_nfa_calibration_search/`.

## Horizon provenance

The original long-horizon labels are not copied as numerical conclusions.
Fresh zero-exponent continuation finds a strictly interior hard-valid main path
through `T=78`; `T=79` reaches the labour cap and the sequential `T=81` probe
is residual-unsafe. Notebook 03 therefore records source request `T=110` and
resolved horizon `T=78` separately. Its pattern and NFA comparative statics
likewise record source requests `T=105` and `T=100`, with resolved horizons
`T=78` and `T=75`.

## Running

Start Julia from the `Codes` directory and open any notebook with the project
environment active. Notebook 02 supports a quick validation run with:

```sh
smoke_dir=$(mktemp -d /tmp/zero-nu-b-smoke.XXXXXX)
AHP_ZERO_NU_B_TAIL_MODE=smoke jupyter nbconvert \
  --to notebook --execute --output-dir "$smoke_dir" \
  Two_country_proudction_zero_nu_b/02_v9_ahp_hkt_scalar_tail_bubble_bounds_zero_nu_b.ipynb
```

Generated artifacts are written below `outputs_zero_nu_b/` and are ignored by
Git.

For an integrated Notebook 03 smoke run, set
`NB03_ZERO_NU_B_SWEEP_MODE=smoke`. The costly failed-horizon audit is opt-in via
`NB03_ZERO_NU_B_RUN_FRONTIER_AUDIT=true`; the selected T=78 equilibrium is
always solved and validated.
