"""Write the run report directly from saved estimates, without estimation."""
import argparse
import json
from pathlib import Path
import pandas as pd


def main(run):
    run=Path(run).resolve();out=run/'results'
    c=json.loads((run/'config.json').read_text())
    status=json.loads((out/'calibration_status.json').read_text())
    dg=json.loads((out/'diagnosis.json').read_text())
    j=dg['central_parameters'];con=dg['constrained'];base=status['baseline_diagnostics']
    seq=pd.read_csv(out/'conditional_sequential.csv').set_index('run_id').loc[c['central_run_id']]
    path=pd.read_csv(out/'conditional_paths.csv');path=path[path.run_id.eq(c['central_run_id'])]
    cmp=pd.read_csv(out/'run_comparison.csv').set_index('object')
    if c['baseline_labor_treatment']=='skilled_normalized_annual_ratio':
        return normalized_report(run,c,status,dg,seq,path,cmp)
    H,L=status['sample']['labor_constants'].values()
    rows=[]
    for key,label in [('a','a'),('xi','xi'),('nu','nu'),('AX','A_X scale'),('AL','A_L scale')]:
        rows.append(f'| {label} | {cmp.loc[key,"run_01"]:.9f} | {seq[key]:.9f} | {j[key]:.9f} |')
    table='\n'.join(rows)
    fitrows='\n'.join(f'| {label} | {100*cmp.loc[key,"run_01"]:.3f}% | {100*cmp.loc[key,"run_02"]:.3f}% |' for key,label in [('Y_relative_rmse','Output'),('wH_relative_rmse','Skilled compensation rate'),('wL_relative_rmse','Unskilled compensation rate'),('Q_relative_rmse','Enterprise value'),('untargeted_FCF_relative_rmse','Untargeted net cash flow')])
    pars=pd.read_csv(out/'conditional_parameters.csv')
    sensitivity='\n'.join(f'| {r.markup:g} | {r.entry_weight:g} | {r.a:.8f} | {r.xi:.6f} | {r.nu:.6f} | {r.xi-r.nu:.6f} |' for r in pars.itertuples())
    report=rf'''# Run 2: fixed sample-mean labor, 2009–2024

**Executed second calibration attempt. Baseline status: {status['status']}.** The external baseline still fails allocation in every fitting year. Conditional on the diagnostic markup 3.5, both spillovers become positive, but their ordering remains inadmissible: xi = {j['xi']:.6f} < nu = {j['nu']:.6f}. These diagnostic estimates are not an adopted full-model parameter vector.

- [17-slide LaTeX report](slides/output/calibration_steps_2009_2024_fixed_mean_labor.pdf)
- [Editable, self-contained Beamer/PGFPlots source](slides/latex/main.tex)
- [Run comparison table](results/run_comparison.csv)
- [Variable-role and constancy ledger](results/variable_roles.csv)
- [Implementation checks](results/synthetic_tests.json)

## What is held constant

The sample contains the same 16 annual observations and September 2026 empirical snapshot as Run 1. Every year from 2009 to 2024 enters fitting; there is no holdout. This is a controlled comparison of the labor treatment, with no data-vintage update.

\[
\bar H=\frac{{1}}{{16}}\sum_{{t=2009}}^{{2024}}H_t={H:.10f},\qquad
\bar L=\frac{{1}}{{16}}\sum_{{t=2009}}^{{2024}}L_t={L:.10f}.
\]

Units are **million persons**. These are separate unweighted means of the two annual employment levels. They are not a mean skill ratio, a fixed 2007 stock, or a per-capita normalization. The labor endowments are identical at every date in every executed scenario.

The theoretical reference is [V6_production.tex](../../../../../AI_drafting/V6_production.tex): its demographic block fixes masses H and L, its state block distinguishes endogenous predetermined knowledge from the exogenous regime, and its unbalanced-growth primitive imposes rho > 1 and xi_u > nu_u > nu_b >= 0. We maintain regime u throughout the observed window. All externally assigned parameters and all five fitted production parameters are single constants within a scenario. Normalization fixes only initial N, not its subsequent path.

Output Y, compensation C, valuation Q and the skill premium r remain annual **targets for endogenous model outcomes**. With fixed quantities, wages are reconstructed at every date as

\[
w_{{L,t}}=\frac{{C_t}}{{r_t\bar H+\bar L}},\qquad
w_{{H,t}}=r_tw_{{L,t}}.
\]

This exactly preserves observed compensation and the premium. Retaining the old annual wages after changing H and L would break the compensation identity. Inferred X, phi, I, N, A_X and A_L also remain time varying. Annual GDPDEF is retained as a measurement conversion into trillion 2017 USD; it is not an exogenous process in the model.

The assignments rho=2 (substitution elasticity 0.5), baseline markup 1.61, alpha=0.5 and N_2009=1 are unchanged. The original literature rationale and its imperfect capital–labor analogy are retained in [the curvature note](../../shared/references/rho_selection.md); this second run introduces no new external estimate. Markups 3.25, 3.5 and 4 are still labelled diagnostic scenarios outside the transferred candidate set.

## Step-by-step procedure and allocation result

1. **P1 allocation:** X=theta(Y−w_L L)/w_H; phi=X/H; I=w_H(H−X). Test every date for 0<X<H and Q>I. No clipping or deletion is used.
2. **P2 entry:** invert a_t=w_H/(Q−I), then fit a constant a using relative valuation residuals. The direct valuation growth diagnostic is G^Q=Q/(Q−I).
3. **Knowledge:** N_2009=1 and N_(t+1)=N_t[1+a(H−X_t)]. Q_t=N_(t+1)q_t is post-entry value; N_t is beginning-of-period knowledge. The last observed growth rate produces N_2025, outside the displayed stock window.
4. **P4 CES inversion:** C_X=(w_H/theta)(X/Y)^rho and C_L=w_L(L/Y)^rho. Given alpha, A_X=(C_X/alpha)^(1/(1−rho)), and analogously A_L.
5. **P5 sequential slopes:** regress coefficient log changes on (1−rho)log G^Q without an intercept, then recover constant technology scales from the full-sample log intercepts.
6. **Joint fit:** profile a, build N(a), and fit log A_X=log A_Xbar+xi log N(a) and log A_L=log A_Lbar+nu log N(a). Minimize the sum of the mean squared relative-Q residual and the two mean squared log-coefficient residuals, with equal block weights. The inversions reuse Y and wages; they are not independent empirical evidence beyond these targets.

At the external baseline mu=1.61, **{base['n_years']-base['n_P1_valid']}/{base['n_years']}** years fail P1. Implied phi ranges from **{base['phi_min']:.6f} to {base['phi_max']:.6f}** and research payroll from **{base['I_min']:.6f} to {base['I_max']:.6f} trillion 2017 USD**. The allocation bound requires mu strictly above **{base['markup_floor_exclusive']:.6f}**, binding in {base['binding_year']}; this is an accounting bound, not a markup estimate. All five external candidates fail. Changing rho cannot affect P1.

At mu=3.5, all years pass the allocation/entry checks: phi lies between {path.phi.min():.6f} and {path.phi.max():.6f}. Downstream estimates below are conditional on this diagnostic markup.

## Estimated constants and comparison

| Parameter | Run 1 joint: annual labor | Run 2 sequential | Run 2 joint: fixed means |
| --- | ---: | ---: | ---: |
{table}

The coefficient a is in inverse million workers per annual model period. Technology scales depend on the output/labor units, alpha and initial-N normalization. Xi and nu are dimensionless elasticities. A_Xbar and A_Lbar are constant; A_X,t and A_L,t are evolving augmentation levels.

The joint objective is {j['objective']:.9f}; the optimizer is interior, with Jacobian rank {j['jacobian_rank']}. Those are implementation/identification diagnostics conditional on the assigned markup and curvature, not evidence that the economic restrictions hold.

| Relative RMSE | Run 1 | Run 2 |
| --- | ---: | ---: |
{fitrows}

The wage targets change when the bridge is reconstructed, so the wage-error comparison also reflects that measurement change. The Y, Q and cash-flow target series are unchanged. Cash flow is untargeted; its large error remains a mapping warning, not a new estimation moment. None of these are out-of-sample or full-equilibrium validation results.

## Why the ordering still fails

Fixing populations removes the secular increase in the measured skilled/unskilled labor mix. The unrestricted joint estimate of xi turns positive, and the absolute xi−nu gap falls by {100*(1-abs(j['xi']-j['nu'])/abs(cmp.loc['xi_minus_nu','run_01'])):.2f}%. This demonstrates that the earlier negative skilled spillover was sensitive to labor mapping. It does not establish that all model restrictions now hold.

With constant theta and alpha,

\[
(1-\rho)(\xi-\nu)=
\frac{{\operatorname{{Cov}}(\log N,\log(w_H/w_L)+\rho\log(X/L))}}{{\operatorname{{Var}}(\log N)}}.
\]

At rho=2, the fitted gap decomposes exactly into **{dg['premium_gap_contribution']:.9f}** from the skill-premium term and **{dg['relative_input_gap_contribution']:.9f}** from relative inputs, summing to **{j['xi']-j['nu']:.9f}**. The remaining failure is the sign/order implied by those mapped series and the maintained relative-wage equation. It is not produced by a solver boundary or a coding sign error: datewise CES recovery has maximum relative error {dg['static_CES_max_relative_error']:.2e}, and synthetic recovery with admissible constants passes.

The closed-cone fit xi>=nu>=0 reaches **xi=nu={con['xi']:.6f}**, with a={con['a']:.9f}, A_Xbar={con['AX']:.6f}, A_Lbar={con['AL']:.6f}. Its objective rises by only **{100*(con['objective_ratio']-1):.4f}%**, from {j['objective']:.9f} to {con['objective']:.9f}. Equality still violates the strict unbalanced-growth primitive. The small objective cost is conditional on the residual weights and is not a statistical rejection test or a confidence region.

## Executed sensitivity checks

Every case below uses the same fixed H and L. Changing the entry-block weight or diagnostic markup does not restore xi>nu. No time-varying exogenous series is reintroduced.

| Diagnostic markup | Entry-block weight | a | xi | nu | xi−nu |
| ---: | ---: | ---: | ---: | ---: | ---: |
{sensitivity}

P3 is also recomputed, with its OLS and relative-Q WLS variants in [p3_diagnostic.json](results/p3_diagnostic.json). Freeing the markup does not produce an admissible inverse markup. With theta externally fixed, P3 reuses the entry restriction and supplies no additional independent moment.

## Scope, verification and reproduction

The change makes the labor endowments consistent with the model's time invariance. It does not convert CPS employment into observed young-cohort population masses, equate an hourly premium with annual compensation differences, align all sector perimeters, or convert an annual period into an OLG generation. RoW, finance, regime-b parameters and transition laws remain outside this production-block calibration. The necessary screen xi>nu>0 is not the complete cross-regime condition xi_u>nu_u>nu_b>=0.

Tests verify known-parameter recovery with fixed and variable labor, unit invariance, entry timing, invalid-allocation rejection, rank-deficient P3 rejection, sample-only averaging, preservation of compensation and the premium, and constant labor in every executed scenario. The original central fit is reproduced and all 195 preserved Run 1 files are hash checked. [validation.json](results/validation.json) records the run identities, units/scope checks and runtime; [input_manifest.csv](results/input_manifest.csv) records hashes of the frozen inputs, manuscript and active code.

From the `Do` directory:

```sh
uv run --no-project --python 3.12 --with-requirements shared/requirements.txt python -B shared/rebuild.py --run runs/02_fixed_mean_labor
```

This rebuilds results, tests, report, slide evidence, editable LaTeX and the PDF. It does not rerun or overwrite Run 1. Source data remain in the project empirical-data package, and the exact observed panel used for this comparison is frozen in `inputs/observed_panel.csv`.
'''
    (run/'README.md').write_text(report)
    print(run/'README.md')

def normalized_report(run,c,status,dg,seq,path,cmp):
    """Run 3 report: H=1 and L=observed L/H. Reads saved estimates only."""
    out=run/'results';j=dg['central_parameters'];con=dg['constrained'];base=status['baseline_diagnostics']
    panel=pd.read_csv(out/'baseline_panel.csv')
    p3=json.loads((out/'p3_diagnostic.json').read_text())['ratio_OLS']
    table='\n'.join(f'| {label} | {cmp.loc[key,"run_01"]:.9f} | {cmp.loc[key,"run_02"]:.9f} | {seq[key]:.9f} | {j[key]:.9f} |'
                    for key,label in [('a','a'),('xi','xi'),('nu','nu'),('AX','A_X scale'),('AL','A_L scale')])
    table+=f'\n| xi − nu | {cmp.loc["xi_minus_nu","run_01"]:.9f} | {cmp.loc["xi_minus_nu","run_02"]:.9f} | {seq["xi"]-seq["nu"]:.9f} | {j["xi"]-j["nu"]:.9f} |'
    fitrows='\n'.join(f'| {label} | {100*cmp.loc[key,"run_01"]:.3f}% | {100*cmp.loc[key,"run_02"]:.3f}% | {100*cmp.loc[key,"run_03"]:.3f}% |' for key,label in [('Y_relative_rmse','Output'),('wH_relative_rmse','Skilled compensation rate'),('wL_relative_rmse','Unskilled compensation rate'),('Q_relative_rmse','Enterprise value'),('untargeted_FCF_relative_rmse','Untargeted net cash flow')])
    pars=pd.read_csv(out/'conditional_parameters.csv')
    sensitivity='\n'.join(f'| {r.markup:g} | {r.entry_weight:g} | {r.a:.8f} | {r.xi:.6f} | {r.nu:.6f} | {r.xi-r.nu:.6f} |' for r in pars.itertuples())
    report=rf"""# Run 3: skilled labor normalized to one, 2009–2024

**Executed third calibration attempt. Baseline status: {status['status']}.** The external baseline fails allocation in every fitting year, exactly as in Run 1. Conditional on the diagnostic markup 3.5, both spillovers are positive, but the ordering is inadmissible by a wide margin: xi = {j['xi']:.6f} < nu = {j['nu']:.6f}. These diagnostic estimates are not an adopted full-model parameter vector.

- [17-slide LaTeX report](slides/output/{c['slides_pdf_name']})
- [Editable, self-contained Beamer/PGFPlots source](slides/latex/main.tex)
- [Three-run comparison table](results/run_comparison.csv)
- [Variable-role ledger](results/variable_roles.csv)
- [Implementation checks](results/synthetic_tests.json)

## What changes relative to Runs 1 and 2

The sample contains the same 16 annual observations and September 2026 empirical snapshot. Every year from 2009 to 2024 enters fitting; there is no holdout. Only the labor inputs change:

\[
H_t=1,\qquad L_t=1\times\frac{{L_t^{{\mathrm{{obs}}}}}}{{H_t^{{\mathrm{{obs}}}}}}\quad\text{{for every }}t.
\]

The unit of labor at each date is that year's skilled workforce. H is constant; L is the observed number of unskilled workers per skilled worker and is **time varying**: it falls from {panel.L.max():.6f} ({int(panel.loc[panel.L.idxmax(),'year'])}) to {panel.L.min():.6f} ({int(panel.loc[panel.L.idxmin(),'year'])}), with mean {panel.L.mean():.6f}. The relative endowment L/H is therefore exactly the observed one at every date. No averaging is used. (Dividing both Run 2 constants by the mean of H would only rescale units and reproduce Run 2's xi and nu exactly, so the annual ratio is the informative version of this normalization.)

Output Y, compensation e, valuation Q and the skill premium w_H/w_L remain annual targets. Notation follows V6_production.tex with the US subscript omitted: e=w_H H+w_L L, varphi is the production share, and xi, nu, A_Xbar, A_Lbar below are the regime-u objects xi_u, nu_u, \bar A_{{X,u}}, \bar A_{{L,u}}. The markup mu=1/vartheta is calibration shorthand. Wages are reconstructed as

\[
w_{{L,t}}=\frac{{e_t}}{{\mathrm{{prem}}_t\cdot 1+L_t}},\qquad w_{{H,t}}=\mathrm{{prem}}_tw_{{L,t}},\qquad \mathrm{{prem}}_t=\text{{observed }}w_{{H,t}}/w_{{L,t}} .
\]

This preserves compensation and the premium exactly, and both wage bills w_H H and w_L L equal their Run 1 values. With H=1, w_H is the skilled wage bill in trillion 2017 USD per year.

The assignments rho=2, baseline markup 1.61, alpha=0.5, N_2009=1, the diagnostic markups 3.25, 3.5 and 4, the residual weights and all P1–P5 equations are unchanged.

## What the normalization does and does not change

Relative to Run 1 the transformation divides H, L and X by the observed H_t and multiplies both wages by it. Three consequences follow from the equations, and the saved results confirm them:

1. **P1 is invariant.** varphi and research payroll I depend only on Y, the wage bills and theta. At mu=1.61, **{base['n_years']-base['n_P1_valid']}/{base['n_years']}** years fail; varphi ranges from **{base['phi_min']:.6f} to {base['phi_max']:.6f}**; the allocation bound requires mu above **{base['markup_floor_exclusive']:.6f}** (binding in {base['binding_year']}), the same as Run 1 ({cmp.loc['baseline_markup_floor','run_01']:.6f}). At mu=3.5, varphi lies between {path.phi.min():.6f} and {path.phi.max():.6f}.
2. **The innovation law loses its scale effect.** Knowledge growth is G_t=1+a(1−varphi_t) instead of 1+a H_t(1−varphi_t); the growth of the skilled workforce no longer raises knowledge growth. The implied a_t = w_H/(Q−I) is the Run 1 series times H_t, so a is in different units (per unit of skilled workforce per year).
3. **Both augmentation terms absorb the growth of H.** Since A_X X and A_L L are invariant, the datewise inversions satisfy A_X(Run 3)=A_X(Run 1)·H_t and A_L(Run 3)=A_L(Run 1)·H_t. The common log H_t trend raises xi and nu together. The relative series X/L and the premium are identical to Run 1, so the gap xi−nu differs from Run 1 only because it is projected on a different knowledge path.

## Estimated constants and comparison

| Parameter | Run 1 joint: annual labor | Run 2 joint: fixed means | Run 3 sequential | Run 3 joint: H=1 |
| --- | ---: | ---: | ---: | ---: |
{table}

a and the technology scales depend on the labor units and are not comparable in level across runs; xi and nu are dimensionless elasticities and are comparable. The joint objective is {j['objective']:.9f}; the optimizer is interior, with Jacobian rank {j['jacobian_rank']}. Those are implementation diagnostics conditional on the assigned markup and curvature, not evidence that the economic restrictions hold.

| Relative RMSE | Run 1 | Run 2 | Run 3 |
| --- | ---: | ---: | ---: |
{fitrows}

Wage targets are in different units across runs; relative errors remain comparable. Y, Q and cash-flow targets are unchanged. Cash flow is untargeted; its large error remains a mapping warning. None of these are out-of-sample or full-equilibrium validation results.

## Why the ordering fails

With constant theta and alpha,

\[
(1-\rho)(\xi-\nu)=
\frac{{\operatorname{{Cov}}(\log N,\log(w_H/w_L)+\rho\log(X/L))}}{{\operatorname{{Var}}(\log N)}}.
\]

At rho=2, the fitted gap decomposes exactly into **{dg['premium_gap_contribution']:.9f}** from the skill-premium term and **{dg['relative_input_gap_contribution']:.9f}** from relative inputs, summing to **{j['xi']-j['nu']:.9f}**. The relative-input term dominates: X/L=varphi_t H_t/L_t rises with the observed skill mix, which the normalization keeps (Run 2 removed it by fixing both stocks). Datewise CES recovery has maximum relative error {dg['static_CES_max_relative_error']:.2e}.

The closed-cone fit xi>=nu>=0 reaches **xi=nu={con['xi']:.6f}**, with a={con['a']:.9f}, A_Xbar={con['AX']:.6f}, A_Lbar={con['AL']:.6f}. Its objective rises by **{100*(con['objective_ratio']-1):.2f}%**, from {j['objective']:.9f} to {con['objective']:.9f} (Run 2: 0.13%). Equality still violates the strict unbalanced-growth primitive. The objective cost is conditional on the residual weights and is not a statistical test.

## Executed sensitivity checks

| Diagnostic markup | Entry-block weight | a | xi | nu | xi−nu |
| ---: | ---: | ---: | ---: | ---: | ---: |
{sensitivity}

No executed case restores xi>nu. P3 is also recomputed ([p3_diagnostic.json](results/p3_diagnostic.json)): the unrestricted ratio regression gives theta={p3['theta']:.4f}>1, an inadmissible inverse markup.

## Scope, verification and reproduction

H=1 is a normalization of the labor unit date by date, so L is not a constant endowment in this run; the model's time-invariant L is relaxed exactly as in Run 1. The run does not convert CPS employment into cohort masses, align sector perimeters, or convert an annual period into an OLG generation. RoW, finance, regime-b parameters and transition laws remain outside this production-block calibration.

[validation.json](results/validation.json) records that H equals one, L equals the observed ratio, the wage bills equal the observed-labor bridge and all targets are unchanged. [input_manifest.csv](results/input_manifest.csv) records hashes of the frozen inputs, manuscript and active code. The shared tests additionally verify that this treatment reproduces the Run 1 allocation.

From the `1_Do` directory:

```sh
uv run --no-project --python 3.12 --with-requirements shared/requirements.txt python -B shared/rebuild.py --run runs/03_normalized_skilled_labor
```

This rebuilds results, tests, report, slide evidence, editable LaTeX and the PDF for Run 3 only. Runs 1 and 2 are read for comparison and never rewritten.
"""
    (run/'README.md').write_text(report)
    print(run/'README.md')


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--run',required=True,type=Path);main(p.parse_args().run)
