# Why the spillover restrictions fail

Investigation: 12 October 2026. Fitting period: 2009–2024, the latest common complete period in the preserved September 2026 package. This diagnosis leaves the source mappings, external baseline, and core calibration equations unchanged. The pre-investigation code, results and figure are preserved in `../archive/before_spillover_diagnosis/` with checksums.

## Finding

**No sign, timing, or inversion error was found. The fitted ordering conflicts with the joint assumptions about CES curvature, factor measurement, and technology dynamics.** The evidence does not uniquely separate a measurement mismatch from a misspecified production structure.

At the diagnostic markup 3.5 and rho=2, the unconstrained joint fit gives:

| Parameter | Estimate | Interpretation |
| --- | ---: | --- |
| a | 0.003084663 | Innovation productivity, per million workers per year |
| xi | -0.136299 | Skilled augmentation elasticity with respect to N |
| nu | 1.683308 | Unskilled augmentation elasticity with respect to N |
| AX | 0.337864 | Skilled technology scale, N_2009=1 |
| AL | 0.193367 | Unskilled technology scale, N_2009=1 |

**Nu is positive and does not itself violate nonnegativity.** Xi is negative, and xi<nu. The manuscript requires xi_u>nu_u>nu_b>=0, with rho_US>1 (`AI_drafting/V6_production.tex`, assumption `ass_absorbing_bg_technology_primitives`). The current production-only screen xi>nu>=0 is merely a necessary, weaker condition; passing it would not validate the unestimated regime-b exponent or the full equilibrium. These estimates fail even that weaker screen.

The external baseline markup 1.61 has a separate, earlier failure: phi exceeds one in all 16 years. It therefore has **no fitted admissible five-parameter vector**. All spillover estimates discussed here are explicitly conditional on a higher diagnostic markup, not a replacement baseline calibration.

## Algebraic mechanism

For the model CES function and skilled-input markup wedge theta=1/mu,

\[
\log(w_H/w_L)=\log[\theta\alpha/(1-\alpha)]
+(1-\rho)\log(A_X/A_L)-\rho\log(X/L).
\]

With A_X=AX N^xi and A_L=AL N^nu, let b(z) denote the OLS slope of z on log N with an intercept over all fitting years. The exact conditional regression identity is

\[
\widehat\xi-\widehat\nu
=\frac{b(\log(w_H/w_L))+\rho b(\log(X/L))}{1-\rho}.
\]

The numerator is positive in this sample, while 1-rho is negative. At rho=2:

\[
\widehat\xi-\widehat\nu
=-0.074789-1.744819=-1.819608.
\]

Thus **95.9% of the fitted negative gap is the relative-production-input term** and 4.1% is the premium term. This is an algebraic decomposition, not a causal share. Neither a constant alpha, a constant markup wedge, nor a change in the initial N normalization can reverse the sign of this contrast; markup can affect the inferred knowledge clock and therefore the magnitude. Common monetary deflation cancels from the contrast.

Between 2009 and 2024, mapped H rises 61.2%, L rises 3.0%, inferred X/L rises 38.4%, and the skill premium rises 15.2%. Under complementarity (rho>1), reconciling the latter two increases requires relative skilled augmentation to fall. Datewise inversion gives A_X down 7.2% and A_L up 104.8%. These endpoint changes describe the unrestricted datewise technologies, not the fitted constant-exponent paths.

The individual exponents can also be traced without optimization ambiguity. Write s_L=w_L L/Y. At rho=2,

\[
A_X=\frac{\alpha w_H}{\theta(1-s_L)^2},\qquad
A_L=\frac{(1-\alpha)Y^2}{w_L L^2}.
\]

Therefore

\[
\widehat\xi=b(\log w_H)-2b(\log(1-s_L))
=0.435875-0.572175=-0.136299,
\]
\[
\widehat\nu=2b(\log Y)-b(\log w_L)-2b(\log L)
=2.124636-0.361087-0.080241=1.683308.
\]

The mapped unskilled compensation share falls from 35.17% to 25.38%. Its effect outweighs skilled real-wage growth in the first equation. Real output growth, combined with much slower growth in L and its inferred wage, generates the large positive nu in the second. The technology parameters absorb these residual movements conditional on the model.

## Discriminating the data hypotheses

All rows below use diagnostic mu=3.5 and rho=2. Except for the explicit end-date test, all use 2009–2024. Every variant recalibrates a and the technology parameters. The FTE/raw-premium joint row is deliberately a joint mapping test; the other rows change one mapping or counterfactual assumption at a time.

| Mapping or counterfactual | xi | nu | xi-nu |
| --- | ---: | ---: | ---: |
| Current mapping | -0.1363 | 1.6833 | -1.8196 |
| End in 2022 | -0.1219 | 1.6067 | -1.7286 |
| Fix H and L at 2007 levels; rebridge wages | 2.0737 | 2.2926 | -0.2189 |
| Raw hourly premium; same headcounts | -0.1342 | 1.7425 | -1.8767 |
| Observed-hours FTE; adjusted premium | -0.1437 | 1.3452 | -1.4889 |
| Raw premium and observed-hours FTE | -0.1430 | 1.3879 | -1.5309 |
| Freeze the premium at its 2009 value | -0.1406 | 1.6416 | -1.7822 |
| Nonfinancial corporate macro accounts; same broad labor | -0.1244 | 1.7824 | -1.9068 |
| Output = compensation + net operating surplus | -0.2596 | 0.9103 | -1.1699 |
| Common implicit deflator from quarterly-deflated GVA | -0.1365 | 1.6831 | -1.8196 |

The negative **level** of xi is sensitive to endowment assumptions: fixing H,L removes it and reduces the absolute ordering gap by about 88%. The **ordering failure** survives every tested mapping. Fixing stocks is a counterfactual, not a correction to observed employment. Likewise, replacing gross output by net factor-cost output does not derive a new valid CES production function; it is a diagnostic subtraction.

The most consequential unresolved mapping is the labor/compensation bridge. It combines actual headcounts with a composition-adjusted hourly wage premium (fixed 2007 age/sex/education-cell weights), then imposes

\[
w_L=C/(rH+L),\qquad w_H=rw_L.
\]

Consequently w_H H+w_L L=C holds by construction. It does **not** establish that the two constructed bills are actual annual skill-specific compensation. Hourly versus annual hours, benefits, within-skill composition, and corporate versus private-for-profit coverage remain mismatched. The FTE series excludes missing/varying hours and is not annual hours worked. None of the available variants provides fully matched annual compensation and efficiency-unit quantities.

Corporate GVA also contains depreciation, production taxes and physical-capital returns, whereas the production block attributes the residual after unskilled compensation to its skilled intermediate margin. This affects X/L as well as P1 feasibility. The net-output and nonfinancial-sector checks reduce some mismatches but cannot isolate all omitted inputs.

The Census documents phased earnings-disclosure changes beginning in January 2023. Excluding 2023–2024 leaves both failures intact, so that transition cannot be their sole explanation. This is not a reconstruction of uncensored earnings. [Census user note](https://www.census.gov/programs-surveys/cps/technical-documentation/user-notes/cps_2023_01.html).

## Equations, timing, optimizer, and restrictions

1. `validate_native_production.jl` extracts and evaluates the actual `ces_F`, `ces_FX`, `ces_FL`, and `compute_production` functions from the Julia solver. It checks the accounting identity and wage derivatives against independent central finite differences, then exports 48 synthetic annual observations across rho=2/3 and rho=2. The Python calibration recovers all five known parameters with maximum relative error 2.3e-12. This tests the production block, not the full GE solver.
2. Static CES reconstruction matches observed output and wages to numerical precision. The slope decomposition above matches the fitted xi-nu to 1e-11. No missing factor 1-rho or swapped skilled/unskilled exponent was found.
3. The synthetic fixture uses post-entry value Q=(N+M)q and N_(t+1)=[1+a(H_t-X_t)]N_t. Python uses the same timing. There is no current-growth inclusion in current N. Alternative empirical annual/Q4 valuation timing remains a measurement issue.
4. Across 81 positive innovation-productivity values spanning 0.01 to 100 times the fitted a, the ordering gap remains negative. The prior entry-weight and markup checks also retain it. Q mainly disciplines the knowledge clock; changing that clock over the tested range does not reverse the factor-price contrast.
5. Re-estimation at rho in {1.1, 1/0.7, 1/0.6, 2, 1/0.3} preserves xi<nu. Xi becomes positive at rho=1/0.3, but the ordering remains wrong. A model-compatible rho alone therefore does not solve the problem. Common monetary rescaling and changing alpha preserve the exponents numerically.
6. The production estimator is deliberately **unconstrained** in xi and nu and then reports admissibility. Hence it can expose a failed primitive restriction. This is a choice of diagnostic estimator, not an accidental failure to enforce an optimizer bound.

For completeness, a separate fit imposes the closed restriction xi>=nu>=0 while preserving the original equal-weight residual objective. Conditional on each a, it projects the two technology slopes onto this ordered cone and profiles over a. The optimum is **xi=nu=0.773505**; the objective rises from 0.099190 to 0.121509 (**22.50%**). Q relative RMSE remains 31.30%. This boundary result is a lower-bound fit cost over the searched a range for the strict model restriction: equality does not satisfy xi>nu. It is neither an accepted calibration nor a statistical rejection test. The level of the objective depends on the declared block weights.

## Literature interpretation and next empirical step

This inversion follows the general logic of [Caselli and Coleman (2006), equation (3) and footnotes 3 and 7–9](https://personal.lse.ac.uk/CASELLIF/papers/wtf.pdf): output, factor quantities and factor prices reveal technology only conditional on the production structure. Their footnote 3 explicitly distinguishes factor augmentation from a rise in relative marginal productivity when the substitution elasticity is below one. Thus xi>nu should not automatically be described as raising the skill premium under rho>1. Their skilled/unskilled margin also differs from the capital–labor evidence used to motivate the current rho; the latter remains an analogy rather than direct empirical validation of this skill margin.

Before adopting a constrained calibration, construct skill quantities and annual compensation on a common sector/hours/composition basis, and decide how the production function represents physical capital and nonlabor value added. Recompute the relative-wage contrast from those independently motivated mappings. If it remains positive with rho>1 and growing N, the strict technology ordering cannot match it exactly without an additional wedge or a changed primitive. Such a wedge should be separately motivated and disciplined rather than absorbed into a parameter bound. No such model revision is adopted in this diagnosis.

## Reproduce and inspect

From `Codes/Calibration_R1/Do`, with Julia on PATH and the Python dependencies in `requirements.txt`:

```sh
python run_calibration.py
julia --startup-file=no Spillover_Diagnosis/validate_native_production.jl
python Spillover_Diagnosis/investigate_spillovers.py
python run_calibration.py
```

The first command builds current calibration inputs; the last refreshes the main figure and report using the completed matching diagnosis. The diagnostic closed forms require rho=2 and equal objective-block weights and reject other settings explicitly. This README describes the dated run; CSV/JSON outputs are regenerated by the scripts.

`results/summary.json` records the checks. `mapping_sensitivity.csv`, `slope_decomposition.csv`, `annual_mechanism.csv`, `endpoint_changes.csv`, `curvature_sensitivity.csv`, `knowledge_clock_sensitivity.csv`, and `constrained_diagnostic.json` contain the numerical evidence. The selected original mapping observations and an input SHA-256 manifest are retained. The expanded single figure is `../results/figures/calibration_overview.pdf` (also PNG/SVG); its sidebar separates external assignments, conditional fitted parameters, fit errors, and primitive failures.
