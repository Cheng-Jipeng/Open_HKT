# US production calibration: reference-solver audit

Prepared 12 October 2026. Scope: source inspection and a native Julia production-block round trip; no reference solver files were edited, no RoW parameters were estimated, and no general-equilibrium or bubble-existence claim is made.

## Mapping to the reference implementation

Reference: `Codes/Two_country_proudction_zero_nu_b/TwoCountryProductionOLG.jl`, SHA256 `7969cb993828847c33aa828ae25129f3b18152a28ded46f528a8dd48edf5167c`.

| US calibration object | Exact Julia field | Interpretation |
|---|---|---|
| Innovation productivity a | `a_US` | Per model period and inverse skilled-labor unit; always report aH as well. |
| Skilled augmentation exponent xi_u | `ξ_u` | `A_X = A_X_US_u * N^ξ_u` in u. |
| Unskilled augmentation exponent nu_u | `ν_u` | `A_L = A_L_US_u * N^ν_u` in u. |
| u skilled scale | `A_X_US_u` | Baseline augmentation when normalized N=1. |
| u unskilled scale | `A_L_US_u` | Baseline augmentation when normalized N=1. |
| Inverse markup theta | `ϑ_US` | Inverse intermediate-firm markup; this is not household bond share θ. |
| CES curvature rho | `ρ_US` | Substitution elasticity is 1/rho. |
| CES normalization alpha | `α_US` | Fix one normalization; alpha and two scales are not jointly identified. |
| Labor endowments | `H_US`, `L_US` | Fixed in this GE implementation; variable empirical H_t,L_t must be declared as a production-panel extension. |
| Knowledge origin | `N_US_0` | Set to 1 at the initial model date; a coordinate normalization. |

Crucial distinction: `Abar_X_US` and `Abar_L_US` are the absorbing-b scales, not the u scales. With only an observed u panel, they require stated counterfactual assumptions or separate identification. The implementation sets `ν_b=ξ_W=0`; these are imposed restrictions, not estimated US observations. `common_world_growth` is inert at these zeros. See parameter fields lines 67–109 and regime maps lines 231–244.

## Exact production and timing equations

The reference function `compute_production` (lines 254–267) has X=phi H and

```
Y = [alpha (AX X)^(1-rho) + (1-alpha) (AL L)^(1-rho)]^(1/(1-rho))
wH = theta alpha Y^rho AX^(1-rho) X^(-rho)
wL = (1-alpha) Y^rho AL^(1-rho) L^(-rho)
q = wH/(a N)
d = (1-theta)/theta * wH X/N
e = wH H + wL L
I = (1-phi) H wH
G = 1 + a (1-phi) H
Q = G N q = N_next q
D = N d
Y = e + D - I
```

The post-entry capitalization definition appears at lines 480–484. Thus Q is priced at date t but counts N_(t+1) claims; D counts incumbent N_t claims. Aggregate dividend yield D/Q equals (d/q)/G. AHP net cash flow F=Y-e corresponds to D-I under this mapping; it is not automatically incumbent D.

With active research and independently mapped Q and I:

```
a_t = wH_t/(Q_t-I_t)
a_t H_t = (wH_t H_t)/(Q_t-I_t)
G_t = Q_t/(Q_t-I_t)
```

If theta is externally fixed and no independent research observation is used:

```
phi_t = theta (Y_t-wL_t L_t)/(wH_t H_t)
I_t = wH_t H_t - theta (Y_t-wL_t L_t)
X_t = phi_t H_t
```

Require positive real output and labor prices, 0<phi<1, and 0<I<Q for the strictly interior recovery. At phi=1, free entry is an inequality; a<=wH/Q, not a point estimate. Negative implied research is a mapping failure to disclose, not a quantity to clip.

## Knowledge clock and estimation

At initial date t0, set k_t0=log N_t0=0. Then

```
k_t = sum_{s=t0}^{t-1} log G_s
```

The contemporaneous G_t belongs to the transition from t to t+1 and must be excluded from k_t. Do not compress missing calendar years into one transition. For consecutive dates, the augmentation-growth restrictions are

```
Delta log wH - rho Delta log(Y/X) = (1-rho) xi_u log G_t
Delta log wL - rho Delta log(Y/L) = (1-rho) nu_u log G_t
```

The dependent log changes run from t to t+1. Align them with G_t, not G_(t+1). Real-unit consistency matters: common inflation does not cancel from these absolute growth equations.

For fixed alpha and rho != 1, recover

```
CX_t = (wH_t/theta) (X_t/Y_t)^rho
CL_t = wL_t (L_t/Y_t)^rho
AX_t = (CX_t/alpha)^(1/(1-rho))
AL_t = (CL_t/(1-alpha))^(1/(1-rho))
log AX_t = log AXbar_u + xi_u k_t
log AL_t = log ALbar_u + nu_u k_t
```

Datewise recovery exactly reuses the static production restrictions. Constant-parameter fitted paths impose additional restrictions and have genuine fit errors. In particular, using a_t and observed G_t is not a validation of a fitted constant a. With a constant estimate, separately report Ghat_t=1+ahat(1-phi_t)H_t and Qhat_t=Ghat_t whatH_t/ahat. Observed-G and constant-a knowledge paths are distinct diagnostic specifications. Rank and condition-number diagnostics should concern independent moment directions; exact reconstructed identities do not supply additional empirical rank.

These equations are verified against `Plan/identification_moments_evidence/production_analysis.md` (lines 48–88, 115–196) and `Plan/V6_parameter_identifying_moments.tex` (P1–P5).

## Normalization and period units

1. Preserve the full observation rule for employment counts versus hours, education/skill grouping, compensation versus earnings, and total-economy versus corporate scope. A normalized H=1 is allowed, but applying a fresh H_t=1 normalization every year alters the labor unit over time and must not masquerade as constant a.
2. A constant common labor rescaling H'=H/s, L'=L/s with unchanged monetary aggregates implies w'=s w, a'=s a, AX'=s AX and AL'=s AL. Hence aH is invariant. If output/capitalization are also divided by c, w'=s w/c and A'=s A/c, while a'=s a remains unchanged by money units.
3. Fixing alpha is a gauge choice: changing it to alpha' while multiplying AXbar by (alpha/alpha')^(1/(1-rho)) and ALbar by ((1-alpha)/(1-alpha'))^(1/(1-rho)) preserves observables. Apply the same transformation to both regimes if later constructing a GE calibration.
4. Replacing N by cN leaves a and the exponents unchanged, and changes the u scales by c^(-xi) and c^(-nu).
5. Annual Q and annual research payroll yield annual aH and annual G. This is an annual conditional production calibration. It does not automatically calibrate the model's generational saving propensity, beta, or cohort wealth. Converting a to a longer period is not generally multiplication by period length; even under constant research allocation, compounded G must be respected. Rho and the knowledge elasticities are dimensionless, but recovered scale coordinates still depend on real-output/labor units.
6. At rho=1, the individual-scale formulas are undefined and only the Cobb–Douglas composite AX^alpha AL^(1-alpha) is identified. Near rho=1, separate augmentation recovery is ill-conditioned.

## Solver admissibility and what remains outside this run

`validate_params` (lines 143–158) requires positive labor and a, theta and alpha in (0,1), nonnegative exponents, xi_u>nu_u, and rho_US>1. This is an implementation/theory restriction. The comment on line 68 incorrectly calls rho>1 substitutes; because elasticity=1/rho, it means complementarity. The production function itself supports any positive rho and a Cobb–Douglas limit. Thus empirical skill-substitution candidates rho<1 may be valid production scenarios but cannot be exported as runnable parameters for the present full GE solver. Do not choose empirical evidence solely to meet a solver assertion, and do not relabel a constraint-bound solution as an unconstrained estimate.

`compute_diagnostics` additionally requires xi_u>nu_u>nu_b>=0, finite-horizon geometric-tail diagnostics, positive effective kernels, interior equity weights, and small residuals before its bubble flag is set (lines 1540–1616). An exponent ordering alone neither establishes a bubble nor proves asymptotic existence. The finite-horizon terminal closure and labor-allocation floor must remain explicit in any later GE study.

The seven unknowns in `bgp_residual!` include both countries' allocations, both portfolio weights, foreign US-bond demand and two returns. Stock clearing and financial FOCs depend on RoW production and preference/convenience/bond-cost parameters (lines 466–515). Consequently a US-only production calibration can legitimately validate:

- algebra and timing against the native Julia production routine;
- implied research and constant-a admissibility;
- output, wages and capitalization predictions under fitted constant US parameters;
- residual trends, window/measurement robustness and parameter rank;
- solver-field mapping and necessary parameter restrictions.

It cannot establish calibrated RoW parameters, estimated absorbing-state payoffs, full GE market clearing, a model-consistent beta, or a quantitative bubble decomposition. A full GE run at reference RoW/default financial parameters would be a separately labeled sensitivity scenario, not part of the US-only empirical calibration.

## Executed native-code verification

The original Julia source was included with `julia --project=Codes --startup-file=no`; no GE routine was called. Five synthetic interior allocations used alpha=.43, rho=2.2, theta=.63, a=.16, H=1.3, L=2.1, xi=.8, nu=.2, initial AX=.9, AL=1.3, N=1 and phi in [.71,.62,.57,.48,.43]. At each state the actual `compute_production` output was inverted for a, G, phi, AX, AL and checked for Y=e+Nd-I, advancing N by the native knowledge equation. Maximum relative error was **3.3306690738754696e-16**. Julia exited successfully. This is an algebra/implementation interoperability check using synthetic values, not an empirical fit or an equilibrium test.

No applicable on-disk AGENTS.md was found in the project/Code/Calibration ancestors or this solver directory; the user-provided skill-location instruction was respected. The reference solver's Git status was clean after this audit.

## Follow-up: allocation failure and a disciplined stopping rule

The parent calibration run reports implied phi between approximately 1.46 and 1.92 under the externally assigned theta approximately 0.621 with its BA/non-BA measurement bridge. These are parent-run diagnostics, not numbers independently recomputed in this audit. They imply negative research funding at P1. The scientifically appropriate accepted-calibration status is therefore **no admissible estimate under the declared external markup and measurement bridge**, with the rejected observations and source choices preserved. No value of rho, alpha, a, xi or nu can repair this static allocation equation. Taking logarithms, clipping phi at one, dropping only the inconvenient dates, or proceeding as if negative I were admissible would obscure the actual failure.

Useful additional diagnostics require no new parameter fitting. Let T=Y-BL, BH=wH H and BL=wL L. For positive T and BH,

```
theta_ceiling_t = BH_t / (Y_t-BL_t)
positive research in every date requires 0 < theta < min_t theta_ceiling_t
minimum corresponding markup = 1/min_t theta_ceiling_t  (strict inequality)
```

Equality at the ceiling reaches no research in at least one observation and does not justify the free-entry equality there. If T<=0, positive skilled production itself fails for positive theta and cannot be fixed by reducing theta. Q>I must be checked separately: with positive T, I=BH-theta T implies theta>(BH-Q)/T. Thus the full common-theta admissible interval is

```
max(0, max_t[(BH_t-Q_t)/(Y_t-BL_t)]) < theta
                                              < min(1, min_t[BH_t/(Y_t-BL_t)])
```

provided positive outputs, wages, labor and T throughout. For typical positive large Q the lower bound is zero, but it must not be silently omitted from general code.

To localize the measurement problem, let e=BH+BL and s=BH/e. Then

```
phi = theta [1 + (Y/e-1)/s]
s_min = theta (Y/e-1)/(1-theta)
```

When Y/e>1, positive research requires s>s_min. If s_min>=1 (equivalently theta>=e/Y), even allocating all observed compensation to skilled labor cannot rescue the same output/compensation bridge. Otherwise the number makes the dependence on the BA/non-BA compensation split transparent without changing it. A second helpful statistic is the output ceiling BL+BH/theta. These statistics describe incompatibility; they do not identify a new markup or justify changing the source perimeter.

The possible R&D-capitalization adjustment alone does not change the sign test. If the maintained accounting bridge is GVA=Y_model+I rather than GVA=Y_model, solve it jointly with P1:

```
I = [BH - theta (GVA-BL)]/(1-theta).
```

For 0<theta<1 the numerator is exactly the naive-GVA P1 research amount, so an initially negative research amount remains negative. Other substantive output bridges, such as excluding physical-capital income or using a net distributable-output concept, require independently justified definitions and a new declared calibration scenario; they cannot be introduced simply to obtain feasibility.

A small grid below the empirical ceiling can illustrate the mechanics and weak-knowledge-growth behavior of the proposed sequence. Label it **off-literature, feasibility-driven sensitivity**, not an accepted external-markup calibration. Export its five fitted numbers only with that label and its source/normalization assumptions. Keep the failed externally disciplined result as the primary scientific finding. Before presenting any feasible sensitivity as a usable constant-parameter set, still assess constant-a errors, G^Q versus G^a, exponent restrictions, level/growth residuals and weak denominators. Feasibility is necessary, not sufficient.

### P3 as a specification diagnostic, not a replacement theta

The Plan's joint a/theta route is useful even after the prescribed externally fixed-theta route fails:

```
y_t = Q_t/wH_t - H_t
x_t = (Y_t-BL_t)/wH_t
y_t = c - theta x_t, with c=1/a
```

Estimate the unrestricted line, record rank and conditioning, and report c, theta and residuals before imposing signs. A positive fitted slope implies negative theta; a nonpositive intercept prevents positive a. Even c>0 and 0<theta<1 are insufficient unless every observation's allocation and Q-I pass the above tests. Shared wage denominators, common trends and measurement error make a high R-squared weak evidence of valid structural identification. P3 does not require rho, alpha or a measured knowledge stock.

The equivalent original-unit equation is

```
Q_t-BH_t = c wH_t - theta (Y_t-BL_t).
```

Fit without an extra free intercept. Equal-weight OLS on the ratio equation weights this original-unit equation by 1/wH_t^2; state that choice rather than treating both estimators as identical with noisy data. For a direct comparison with the requested P2 objective, profile theta with its fixed weights and

```
c_hat(theta) = sum_t weight_t*wH_t*[Q_t-BH_t+theta*(Y_t-BL_t)]
               / sum_t weight_t*wH_t^2.
```

Only c_hat>0 is admissible. Plot or tabulate this objective over the externally assigned theta grid and, separately, the mathematical feasible interval. If the optimum within the latter hugs an endpoint or has a flat objective, report the restriction/weakness. Do not silently promote the P3 estimate or its restricted optimum to the externally disciplined final theta: P3 is a different cross-date identifying assumption and here serves to diagnose whether constant a/theta and the current mapping can coexist.

### Minimal meaningful pipeline checks

Two compact synthetic checks cover the important scientific failure modes; a broad suite mirroring every algebraic expression adds little.

1. **Known-parameter path recovery and units.** Generate five or more consecutive dates directly from the native Julia production routine with fixed H,L, alpha=.43, rho=2.2, theta=.63, a=.16, xi=.8, nu=.2, AXbar=.9, ALbar=1.3, N0=1 and varying interior phi (the executed round-trip values above suffice). Build Q with N_next. The pipeline must recover all five parameters, recover P3's c=6.25 and theta=.63 when x varies, and align Delta log A_t with G_t. Require numerical-tolerance errors, not exact decimal string equality. Re-run the same synthetic panel under one constant common labor/money rescaling; aH and predicted normalized ratios must be invariant while a and the augmentation scales transform by the formulas above. A constant-phi version should correctly report P3 rank deficiency rather than invent two identified parameters.
2. **Fail-closed observations and calendar alignment.** Inject one phi>1 observation by changing Y or theta and require P1 failure with no accepted five-parameter export. Include phi=1 and Q=I boundary cases as distinct diagnostic statuses, not positive-research estimates. Remove a calendar year from the otherwise exact path: the routine must reject the discontinuous sample or use an explicitly aggregated transition with all intervening G values, never silently pair a two-year wage change with one year's G. These cases test economically consequential acceptance and timing decisions rather than duplicate formulas.

If the final pipeline never invokes P3, omit its synthetic checks. The native Julia round-trip already executed verifies the formulas; running the end-to-end known-parameter fixture through the actual new pipeline additionally verifies estimation, timing, labels and export behavior.


