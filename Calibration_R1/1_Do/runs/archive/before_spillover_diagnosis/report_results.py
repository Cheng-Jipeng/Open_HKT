"""Render the current calibration report from computed results and configuration."""
import pandas as pd


def build_report(here, config, status, external, conditional, p3, sourcegrid):
    base = status['baseline_diagnostics']
    sample = status['sample']
    start, end = sample['requested_start'], sample['resolved_end']
    coverage = pd.read_csv(here/'results/input_coverage.csv').set_index('variable')
    macro_end = int(coverage.loc[['Y','Q','COMP'],'latest_year'].min())
    labor_end = int(coverage.loc[['H','L','premium'],'latest_year'].min())
    table = ['| Markup | Labor | Entry weight | a | xi | nu | AX | AL | Q error | xi > nu >= 0 |',
             '| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |']
    if len(conditional):
        for _, row in conditional.iterrows():
            table.append(f'| {row.markup:g} | {row.scenario} | {row.entry_weight:g} | {row.a:.6g} | {row.xi:.5g} | '
                         f'{row.nu:.5g} | {row.AX:.6g} | {row.AL:.6g} | '
                         f'{100*row.free_entry_relative_rmse:.2f}% | {row.xi_gt_nu_ge_zero} |')
    text = f"""# US production calibration: {start}–{end}, rho = {config['baseline_rho']:g}

**Current status: {status['status']}.** {status['reason']}.

## Requested changes and literature choice

The fitting sample is **{start}–{end} ({sample['n_years']} annual observations)**. The end year is resolved from the latest common complete observation of output, valuation, compensation, H, L, the premium and the annual deflator in the preserved September 2026 package. Corporate accounts extend to {macro_end}, but labor and premium inputs end in {labor_end} in this snapshot. `results/input_coverage.csv` records the component endpoints. Missing interior years cause an error rather than compressed knowledge transitions. Untargeted cash-flow availability does not determine the fitting sample.

**rho = {config['baseline_rho']:g}, sigma = 1/rho = {1/config['baseline_rho']:g}** respects the requested rho > 1 model class. All executed curvature candidates satisfy it. The choice is supported as a capital–labor complementarity analogy by [Oberfield and Raval (2021)](https://doi.org/10.3982/ECTA12807), whose aggregate manufacturing range is 0.5–0.7, and the country-level-data variant of [Gechert et al. (2022), Table 9](https://doi.org/10.1016/j.red.2021.05.003), which gives 0.50. Their input margin differs from V6's skilled-production versus unskilled input. This is a maintained model-compatible calibration, not a directly estimated V6 skill elasticity. See [rho_selection.md](rho_selection.md) for verified source loci and the selection rule.

All available dates, including 2023–2024, are now fitting years. **There is no holdout in this run.** The documented CPS disclosure/topcoding comparability caveat for these last years remains. The markup, source mappings, units and compensation bridge are unchanged.

## Allocation and empirical admissibility

At baseline markup {config['baseline_markup']:g}, P1 implies phi **{base['phi_min']:.6f}–{base['phi_max']:.6f}**, with **{base['n_P1_valid']}/{base['n_years']}** interior dates. Implied research payroll ranges from **{base['I_min']:.6f} to {base['I_max']:.6f} trillion 2017 USD**. No invalid date is clipped or deleted.

The common inverse-markup interval is ({base['theta_lower_exclusive']:.6f}, {base['theta_upper_exclusive']:.6f}); its upper bound corresponds to markup strictly above **{base['markup_floor_exclusive']:.6f}**, binding in {base['binding_year']}. This is an accounting feasibility bound, not independent markup evidence. P1 contains no rho, so choosing a compatible curvature cannot by itself repair this allocation restriction.

The run screens {len(external)} external markup/curvature/labor specifications; {int(external.status.eq('feasible').sum())} pass P1/P2. It also screens {len(sourcegrid)} skill-pair/sector/markup combinations; {int(sourcegrid.status.eq('feasible').sum())} pass on their available dates. `complete_fit_window` distinguishes variants with shorter coverage. The unrestricted P3 ratio diagnostic yields theta={p3['ratio_OLS']['theta']} and a={p3['ratio_OLS']['a']}; its admissibility is {p3['ratio_OLS']['admissible']}. Original-unit P3 WLS is separately recorded.

## Conditional downstream experiments

Higher markups {', '.join(str(x) for x in config['diagnostic_markups_outside_candidate_set'])} retain their previous role as scenarios outside the supplied direct-transfer markup set. **They are not accepted baseline estimates.** The unchanged source literature's markup basis still requires a mapping to the model's intermediate stage. No inference that these are impossible under every transformed empirical markup is made.

{chr(10).join(table)}

Q error is relative free-entry RMSE. Full scenario identifiers and objective weights are in `conditional_parameters.csv`; repeated labor/markup rows differ in the existing entry-weight sensitivity. `fixed{config['fixed_labor_reference_year']}` retains the prior counterfactual fixing H and L at that year's levels. No old pre-2009 subwindow is fitted. Parameter sign/order compliance is reported separately from fit quality and does not establish GE admissibility.

## Inputs, equations and units

- Y, Q, compensation and FCF: the preserved Fed/BEA total-corporate mappings. Quarterly flow sums and Q4 valuation are inherited from the data package.
- H and L: CPS MORG private-for-profit BA+/non-BA employment; premium: composition-adjusted hourly wage ratio. The wage bridge is wL=COMP/(premium*H+L), wH=premium*wL.
- Money: trillion 2017 USD, using the same annual mean GDPDEF/100 for each monetary series. Labor: million persons. Plotted wages are thousand 2017 USD per worker-year.
- P1: X=theta*(Y-wL*L)/wH, phi=X/H, I=wH*(H-X), with theta=1/markup. Active entry requires 0<X<H and Q>I.
- P2: Q-I=wH/a. The sequential fit uses Q^(-2) weights. The joint fit profiles log(a), solving the two log-CES regressions at each candidate with weights {config['joint_residual_weights']} on the three mean-square blocks.
- Knowledge: N_{start}=1, N_(t+1)=[1+a*(H_t-X_t)]N_t. Contemporaneous entry changes next year's N. Alpha={config['alpha']:g} is a scale normalization.
- Observed annual H,L define a conditional production extension of the fixed-endowment GE model. The full two-country solver, finance block and regime-b technology are not calibrated. Neither wage bridging nor targeted Q fit is independent validation.

## Figure and reproducibility

`results/figures/calibration_overview.png` is the requested single figure. PDF and SVG copies are available alongside it. It combines the input series, wages, skill premium, compensation shares, phi, research labor/payroll and the markup bound. Downstream innovation and technology paths are explicitly labelled with their diagnostic markup; none is inferred for the rejected baseline.

From this directory, run `python3 run_calibration.py` and `python3 test_calibration.py` in an environment containing `requirements.txt`. A portable isolated alternative is:

```sh
uv run --python 3.12 --with-requirements requirements.txt python run_calibration.py
uv run --python 3.12 --with-requirements requirements.txt python test_calibration.py
```

The numerical tests cover both the original rho=2/3 and the current rho=2 branches. Configuration tests verify automatic sample endpoints, missing-year rejection and the rho>1 rule. Passing them validates implementation, not the empirical model.

The original code, results, reports and figures are preserved under `archive/2026-10-12_before_rho2_2009_latest/` with a SHA-256 manifest. The historical `data_audit.md`, `reference_audit.md`, `solver_audit.md`, and `P1_Diagnosis/` describe the original 1994–2022 exercise. The P1 diagnostic script is pinned to that archived baseline so it cannot accidentally mix samples. Current numerical conclusions are those in this README and `results/`.

Current outputs include `sample_selection.json`, `input_coverage.csv`, `calibration_status.json`, `baseline_panel.csv`, `baseline_allocation.csv`, `external_grid.csv`, `source_feasibility.csv`, `conditional_parameters.csv`, `conditional_paths.csv`, `fit_metrics.csv`, `joint_a_profile.csv`, input/provenance manifests, validation and synthetic-test records. `fit_metrics.csv` contains in-sample errors only. The runner derives status from the computed checks rather than a hard-coded rejection.
"""
    (here/'README.md').write_text(text)
