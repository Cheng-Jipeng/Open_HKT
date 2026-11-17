# Model-versus-data scorecard: dimensions the V6 two-country production model fails to match

Prepared 26 October 2026, revised 30 October 2026 (section 6 lists the changes). The Chinese version is [On_Model_vs_Data_Failed_Dimensions_CN.md](On_Model_vs_Data_Failed_Dimensions_CN.md); the two have the same content. The figure-led deck is [slides/model_vs_data_slides.pdf](slides/model_vs_data_slides.pdf).

Three sources, none of which was modified:

1. **Model and simulations.** `AI_drafting/V6_production.tex` (production block, free entry, funding identity, asymptotic HKT reduction) and the zero-exponent solver with notebooks 02–06 in `Two_country_proudction_zero_nu_b/` (`outputs_zero_nu_b/`). The AHP-seeded calibration is β=0.45, γ=0.25, ϑ_US=0.85, a_US=0.20, a_W=0.06, A_X,US,u=15, A_L,US,u=1.5, H_US=L_US=1, H_W=L_W=3, ξ_u=2.25, ν_u∈{0.75, 1.00, 1.25, 1.75}, ν_b=ξ_W=0, π=0.75 (notebook 06 also searches π, ω̄, ω̄*, η). Notebook 06 uses one period as an episode index and states that this is a plotting convention, not a calibrated model frequency. R1 and the mapping package use one period = one year.
2. **Pilot calibration.** `Calibration_R1/1_Do/runs/01_observed_labor`, `runs/02_fixed_mean_labor`, the spillover diagnosis, and `Calibration_R1/0_Plan`.
3. **Empirical data.** `Empirical_Data/Variable_mappings/Empirical_Mapping_Annual` (AHP corporate and external mappings, implied a and implied β diagnostics, overidentification checks), `Empirical_Data/AHP_NFA`, `US_Equity_Positions`, `US_Debt_Positions`, the mechanism-evidence package (US vs G4), and `Skill_Premium_and_RD_Share_2026-10-26`.

Notation: Y = AHP total-corporate GVA; COMP = corporate compensation; Q = AHP enterprise value (EV, end-year); D = AHP free cash flow (FCF); e = w_H H + w_L L; B_H and B_L = skilled and unskilled wage bills from the CPS bridge; I = (1−φ)H w_H, the IPO transfer. Ratios are unit-free; levels are trillion 2017 USD in the R1 panel and nominal USD in the mapping package.

---

## 1. Scorecard

| # | Dimension | Data (US unless noted) | Model | Verdict | Structural source |
|---|---|---|---|---|---|
| 1 | Valuation scale: Q/Y, Q/COMP | Q/Y: 1.29 (1990), 2.23 (2007), 1.94 (2009), 4.45 (2024), 4.66 (2025). Q/COMP: 2.0, 3.7, 3.3, 7.9, 8.3. Implied β=(Q+NFA)/e: 2.0 (1990), 3.6 (2007), 4.7 (2022), 6.3 (2025); all 36 years > 1 | Identity Q+NFA=A=βe. ν_u sweeps: Q/e falls from 0.41 (t=1) to 0.23–0.25 (T=80). Notebook 06 best point: from about 0.8 to 0.5 | **Fails**: 2025 level off by 10× or more; trend sign reversed | Two-period OLG: equity value is financed by the current young cohort's saving |
| 2 | Non-labor income and the markup | (Y−COMP)/Y: 36% (1990) → 44% (2022–25). FCF/Y: 6.4% → 12.7%. CFC + taxes 25–27%; NCF 4–7% (−0.6% in 2009) | No capital, so net cash flow D−I = Y−e, all of Y−COMP. P1 year-by-year markup floor 2.35–2.81, common bound 2.81 (observed labor), 2.73 (mean labor); with 1−φ≈7%, μ=2.34–3.02 by premium series. Notebooks use ϑ=0.85 (μ=1.18), D/Y=1.4% | **Fails**: model net cash flow is 44% of GVA, FCF is 12% | No corporate capital |
| 3 | Dividend yield D/Q | 5.0% (1990), 3.6% (2007), 7.5% (2009), 3.4% (2022), 2.7% (2025). Cash dividends/equity: 7.8% → 2.7% | d/q = a(1−ϑ)/ϑ·φH = 0.20×0.176×0.98 = 3.45%/period (t=1), falling with φ | Level matched by choice of ϑ; direction matched | Mechanism is wrong (row 4) |
| 4 | Decomposition of the Q/D rise | 2007→2025: Δlog(Q/D)=+0.29, with Δlog(Q/Y)=+0.74, Δlog(D/Y)=+0.45. 1990→2025: +0.61, with +1.29, +0.68. 2009→2024: +0.97, with +0.83, −0.14. D/Y has no downward trend (7.5–15% over 2005–25, 12.5–12.7% in 2023–25); Q/Y dominates in every window | ν_u=1, t=1→80: Δlog(Q/e)=−0.59, Δlog(d/q)=−2.1; D/Y falls from 1.39% to 0.08%. The explosive q/d is a dividend collapse | **Fails: wrong channel** | φ→0 mechanism combined with the funding cap |
| 5 | R&D share of skilled labor, 1−φ | BERD researchers/H 3.4–3.8%; BERD personnel/H 4.9–5.7%; NSCG for-profit RD1 6.1–7.3% (6.9% in 2010, 7.3% in 2023); BERD labor cost/skilled bill 7.1–10.5% by premium. About +1–2pp per decade. NRC occupational share 30.5% (1990) → 43.9% (2024), with total employment as denominator, not H | AHP seed: 1.8% (t=1). ν_u=1.75: 1.9% → 0.6% (T=30), falling. ν_u=1.25/1.00/0.75: 25%/88%/99% (T=80). Notebook 06 best point: 28–30%. R1 conditional (μ=3.5): 22–30%, implying 7.2–9.7 million R&D workers, 3.5–6× NSCG RD1 (1.4–2.2 million); research payroll 2–3× BERD labor cost | **Fails level and trend** | φ-decay mechanism; P1 counts all of Y−COMP as profit |
| 6 | Free entry: q=w_H/(aN), equivalently B_H/Q=a·H/G_N | B_H/Q: 0.098 (1995), 0.101 (2007), 0.123 (2009), 0.077 (2019), 0.079 (2022). Q/w_H index: 1995=1, 2022=2.86. Implied a: −54% to −62%; implied a·H: −19% to −22%, and −38% on the patent stock, which starts in 2001 with an initial-stock effect (1995–2007 mean vs 2018–24 mean). Free-entry residual mean +5–7%/yr, cumulative about +1.4 log (1995–2024). R1 constant-a: Q RMSE 25–31%, over-predicted in 2009–12 (−0.53 to −0.20), under-predicted in 2013–24 (+0.05 to +0.37) | Holds exactly. AHP seed: a·H=0.2, B_H/Q≈0.20 | **Fails in trend**; the level can be set by a (section 2.5) | Entry cost is skilled labor only; the total price (fundamental + bubble) is pinned to entry cost |
| 7 | Skill premium w_H/w_L | 1.8–2.5: CPS re-censored 1.87 → 1.78 (2009–24); ACS annual 2.47 → 2.44; ACS hourly 2.09 → 2.17; BLS medians flat at 1.82. The package jump to 2.16 in 2023–24 is a top-code artifact | w_H/w_L=0.088 (t=1), 0.040–0.050 (T=80), 0.11 after a switch. w_L/w_H=(A_X/A_L)φ²/ϑ (ρ=2, α=½, H=L) | **Fails by 20× or more** | A_X/A_L=10 with ρ=2 |
| 8 | Skilled wage-bill share and skill upgrading | B_H/COMP: 29% (1994), 40% (2009), 50% (2022); 47–58% under the ACS annual premium (2009–24). BA+ employment share 19.5% (1994) → 36% (2024). H/L: +134% (1994–2024), +56% (2009–24). COMP/Y 64% → 56% | Identity w_H H/e = βζ·aH/G_N: 8.1% (t=1), 3.8–4.8% (T=80); limit βaH/(1+aH)=7.5% as ζ→1. H, L fixed | **Fails level and trend** | Funding cap plus free entry pin this share; fixed endowments |
| 9 | Technology ordering ξ_u > ν_u | Relative-wage inversion at ρ=2: ξ−ν=−1.82 (observed labor), −0.11 (mean labor); across eight premium series −1.32 to −1.86 and −0.03 to −0.13; never positive. Imposing ξ≥ν≥0 gives only the boundary ξ=ν | Requires ξ_u > ν_u > ν_b = 0, ψ>0 | **Fails under every mapping** | ρ>1 and ξ>ν cannot accommodate rising X/L with a flat premium |
| 10 | Output growth | Real corporate GVA: 2.4%/yr (1990–2025), 2.4%/yr (2008–23), 2.8%/yr (2009–24) | Notebook 06: Y_US 10.5%/period, ×4.5 over 16 periods. ν_u sweeps: 0.7–0.9%/period at t≈16, 6–17%/period at T=80 | **Fails under one period = one year**; a longer period no longer maps to the 2008–23 window | Y∝N^ν_u, ν_u=1.75, G_N≈1.06 |
| 11 | Equity price indices | AHP implied liability price ×2.22, asset price ×1.05 (2008Q1–2023Q3); MSCI USA ×5.4 (2011–25); S&P 500 ×4.7 (2007–25); ACWI ex-US ×1.9 (2011–25); OECD G4 local ×1.08 (2007–21), ×1.24 (2007–24) | Notebook 06 best point: q_US ×1.29 (log growth 32% of data), q_W ×0.97 (close to 1.05). AHP baseline: q_US ×1.00, q_W ×0.52. Sweeps to T=80: q_US from 1.09 to 0.91/0.59/0.12; q_W from 2.30 to 0.06–0.16, about −4% to −5%/period | **Fails**: US well under-predicted; apart from the searched q_W, long-run direction reversed | q=Q/N_{t+1}, with Q capped and N growing |
| 12 | External positions and flows, 2008Q1–2023Q3, /GVA | ΔNFA −1.02; net equity VA −0.67 (liability −0.72, asset +0.05); CA −0.52; equity liabilities 1.55; equity assets 1.17. NFA/GVA: −0.14 (2008Q1) → −1.06 (2023Q3) | −0.0016; −0.011 (−0.011, −0.0005); +0.0098; 0.018; 0.093. NFA/Y: −0.35 → −0.08 | **Fails**: scale off by 13–620×; CA and asset VA signs reversed; NFA/Y trend reversed. Only the liability share of gross VA matches (0.96 vs 0.93) | Positions ∝ βe; NFA level nearly constant while Y rises ×4.5 |
| 13 | Foreign ownership of US equity | Equity liabilities/Y (AHP concept, portfolio plus FDI): 0.76 (2007), 1.34 (2022), 1.94 (2025), about 42% of EV in 2025, in the September 2026 release; 1.46 (2022), 2.27 (2025) in the June 2026 release that notebook 06 uses | Liability exposure/Y: 0.27 (t=1) → 0.018 (t=16); position level ×0.30, Y ×4.5 | **Fails: trend reversed** | As above |
| 14 | RoW growth and research intensity | G4 NRC share +5.5pp (2011–24), US +6.3pp. Researcher FTE per 100 employed: G4 0.40 → 0.66 (2011–24), US 0.57 → 0.82 (2008–23). R&D capital: G4 +34%, US +53% (2007–21) | ξ_W=0: no RoW technical growth, and Y_W does not grow. e_W stays at 5.0–5.1 through t=60; with ν_u≤1 it rises to 8.1/15.5 at T=80 through the RoW IPO transfer (φ_W falls to 0.12/0.04), not output growth. In b, aggregate growth is zero in both countries | **Fails**: RoW stagnates; no US-only shift into research in the data | Zero-exponent specialization |
| 15 | Regime switch | No identifiable b-type event. 2007→09: nominal GVA −4.8% (recovered 2010), real GVA −7.3% (recovered by 2012); EV 2007→08 −22% (recovered 2010) | τ=16: e_US −39%, Q_US −21%, φ_US falls to 0.885; then zero aggregate growth and q_US −2.3%/period | Not identifiable; size and permanence unlike any observed event | ν_b=0 and Ā_b<Ā_u |
| 16 | Bubble share | Not measurable | Finite-prefix upper bound at t=1: 6×10⁻⁹ to 8×10⁻⁷; 3×10⁻⁵ at t=20 with ν_u=1. Total leakage 0.32/period (switch 0.29, dividend 0.035) | No visible bubble at the data-relevant early dates | π=0.75 switch leakage |

**What the model does match:** the D/Q level (a result of ϑ=0.85 and a·H=0.2) and the direction of the US yield decline; in the notebook 06 best point, the q_W path, the signs of ΔNFA and liability VA, and the liability share of gross VA; a roughly flat RoW yield within the window (though at 13.5–18%, above G4 FCF/EV of 6–9%). R1's G_N≈1.02–1.03 is close to R&D capital growth of about 3%/yr, but that is a result of fitting Q and comes with 3.5–6× the R&D workers. R1's fits of Y (RMSE 1.2–1.6%) and wages (2–4%) are inversions, not validation.

---

## 2. Detail by dimension

### 2.1 Valuation scale (rows 1, 11, 12, 13)

The tightest constraint is A=βe=Q+NFA, which holds exactly along every path. ζ=Q/(βe) only rewrites it, and the world version is Q_US+Q_W=βe_US+s_W e_W. The bounds ζ∈[½, 3/2] and ζ→1 from `lem_relative_dividend_bounds` and `prop_hkt_cone_invariance` hold only inside the HKT cone. In notebook 05 ζ falls from 0.90 to 0.50–0.56, and in the notebook 06 best point from about 1.76 to 1.17; neither is in the tail region. Whatever ζ is, world equity value equals the current young cohort's total saving.

The data need Q/COMP rising from 2 to 8 and implied β rising from 2.0 to 6.3 (`data_final/implied_beta_US_main.csv`). A longer period changes only the level. With a T-year period, Q/(5e)=1.67 and A/(5e)=1.26 in 2025, and T≥7 gives A/(Te)<1. Rescaling cannot remove the ×3.2 rise in A/e over 1990–2025, and the implied-β readme already notes that rescaling without rebuilding cohort income and asset ownership is arbitrary.

Because Q is capped and N_{t+1} grows, q=Q/N_{t+1} falls in every sweep. Notebook 06 gets a rising q_US through the portfolio search (ω̄=0.95, ω̄*=0.425, η=0.086), with log growth only 32% of the data. External positions and valuation effects are 1–8% of their empirical size. The model's NFA level also stays nearly constant (−0.92 to −0.96) while Y rises ×4.5, so row 10's high growth mechanically depresses every /Y ratio.

### 2.2 Income shares, the markup and the mapping of D (rows 2, 3, 4, 5)

Without capital, Y = w_L L + φH w_H + D, so D−I = Y−e. P1 has the closed form:

μ = (1 + (Y−COMP)/B_H) / φ

If capital absorbs all of Y−COMP−FCF (CFC, taxes, NCF), then PX = B_H + FCF and D−I = FCF, so:

μ = (1 + FCF/B_H) / φ

The only difference is whether 44% or 12% of GVA enters. With φ=1−NSCG share, all years 2009–2024, and three premia (package CPS, re-censored CPS, ACS annual):

| Setting | Implied μ | Note |
|---|---|---|
| No capital | 2.34–3.02 | 2.79 in 2022, the existing P1 result |
| Capital absorbs Y−COMP−FCF | 1.45–1.73 | 1.54 in 2022, inside the external 1.10–1.84 |

This is an accounting illustration, not an estimate. FCF still contains the net return to capital, so 1.45–1.73 should be read as an upper bound on the pure-rent markup. The P1 rejection, the μ≥2.7 floor and R1's 250% untargeted FCF RMSE (model net cash flow about 3× FCF) are one problem: the model has no capital, and its net cash flow is 3.7× FCF.

On trend, with ρ>1 and A_X X/(A_L L) growing, the X-share of output goes to zero, so D/Y→0 and d/q∝φ→0. In the data D/Y has no downward trend, and the yield fell because Q/Y rose. That conclusion does not depend on the window, but "D/Y rose" does: 8.1% → 12.7% over 2007→2025, 14.4% → 12.5% over 2009→2024 (2009 FCF is unusually high because NCF is negative).

### 2.3 The R&D share (row 5)

The empirical counterparts of 1−φ cluster at 3–10% and move 1–2pp per decade. In the model, 1−φ is set jointly by free entry and funding: G_N = a·βζ·(e/w_H), 1−φ=(G_N−1)/(aH). In the AHP seed at t=1, 0.2×0.4066×12.34=1.0036, so 1−φ=1.8%. It then either keeps falling (ν_u=1.75) or explodes (ν_u≤1.25). Notebook 06's 28–30% comes from a higher ζ. R1's 22–30% comes from setting μ=3.5 and assigning all of Y−B_L to the skilled margin.

With a, ϑ, H constant, the model's yield moves only with φ, which is an analytic result. Matching D/Q −26% over 2007→2025 needs φ to fall 26%, taking 1−φ from 7% to about 31%; from 1990 (D/Q −46%) it needs about 50%. Measured 1−φ shows nothing like that. The data pattern to match is a small, nearly flat R&D share with a large rise in Q/Y. In the current block 1−φ is the only source of yield variation, and that is the conflict.

### 2.4 The free-entry (indifference) condition (row 6)

Free entry gives q=w_H/(aN), equivalently Q=G_N w_H/a, equivalently B_H/Q=a·H/G_N. Implied a, the residual (dlog a = −residual) and the R1 constant-a fit are **one restriction written three ways**, not three independent checks. Similar results across knowledge mappings are not independent evidence either, because G_N≈1 and N barely affects the ratio. What matters is the mapping of Q, w_H and H.

The established fact is that Q/w_H rose to 2.86× over 1995–2022 (R1 sample 2009–24: ×2.85 with observed labor, ×2.23 with mean labor) while knowledge-stock growth stayed at 2–4%/yr. This moment alone cannot separate:

- A secularly falling a_t (fishing out).
- An entry cost not denominated in skilled wages.
- A price component that entry cannot replicate (rent or bubble). V6 currently lets the bubble crowd out the fundamental inside a fixed q rather than lift q.

Q as EV also contains the value of physical capital, while free entry restricts only variety value. Once capital is added, this residual must be recomputed.

### 2.5 Factor proportions and the skill premium (rows 7, 8, 9)

With ρ=2, log(w_H/w_L) = log[ϑα/(1−α)] − (ρ−1) log(A_X/A_L) − ρ log(X/L). A_X/A_L equals 10 in both the AHP seed and the HKT default, putting the skilled wage at 5–9% of the unskilled wage. Along the unbalanced branch, A_X/A_L∝N^{ξ−ν} and φ∝N^{−ψ/ρ} cancel asymptotically, so the premium and the skilled bill share converge to constants (the latter to 7.5%), not to zero. What goes to zero is the production part φw_H H/e and D/Y.

One identity links three failed dimensions:

w_H H/e = (Q/e) · (aH/G_N)

| | w_H H/e | Q/e | aH/G_N |
|---|---|---|---|
| Data 2022 | 0.495 | 6.27 | 0.079 |
| Model t=1 | 0.081 | 0.406 | 0.199 |

The skilled bill share is low because the funding cap holds Q/e down; a·H is actually 2.5× the data value. If the cap is relaxed so that Q/e≈6, with a·H≈0.08, free entry automatically delivers a skilled bill share near 0.5 (G_N≈1). So the free-entry **level** problem can be solved, and the real conflict is the **trend**, the fall in B_H/Q in row 6.

On trend, H/L rose 134% since 1994 and 56% since 2009 with a roughly flat premium. Under ρ>1 that requires A_X/A_L to fall, hence ξ<ν in every mapping. The model also has no skill upgrading.

### 2.6 RoW and the regime structure (rows 14, 15, 16)

With ξ_W=ν_b=0 the RoW has no technical growth. The absorbing regime has zero aggregate growth in both countries, and US income falls 39% at the switch; that size reflects both ν_b=0 and the calibration's Ā_b (10, 1) below the u-regime (15, 1.5). The covered RoW does grow, and its research intensity rises at least as fast as in the US (G4 researcher FTE per 100 employed +64%, US +43%, different windows). The US/RoW asymmetry in the data is mainly in valuations (MSCI USA ×5.4 vs ACWI ex-US ×1.9) and sector productivity (US relative ICT productivity +98% vs G4 +42%); R&D capital also differs (+53% vs +34%), but that is not a US-only shift. In the simulations the bubble share upper bound at date 1 is below 10⁻⁶, and switch leakage (0.29/period) dominates.

---

## 3. Reading for model modification

The ranking is my judgment, based on how many scorecard dimensions each change addresses.

1. **The funding cap is the first-order failure (rows 1, 8, 11, 12, 13).** As long as equity value equals the current young cohort's saving, no production-block change can deliver Q/COMP rising from 2 to 8, gross positions of 1–2 GVA, or valuation effects of −0.7 GVA. Candidates: a longer or multi-period life cycle, wealth held across cohorts, outside wealth or bequests, or an asset-holding sector whose demand is not tied to current labor income. Implied β (2.0 → 6.3) is the direct target. Relaxing the cap also addresses the skilled-bill-share level (section 2.5).

2. **Corporate capital (rows 2, 3, 5).** Adding depreciation, production taxes and net investment lets P1 deliver μ≈1.45–1.73 together with 1−φ≈7% (section 2.2) and removes the 3.7× ambiguity in D. Capital also adds a Q-growth channel that does not run through φ (capital accumulation, Tobin's q), though it remains subject to the cap in row 1.

3. **An explosive Q/D mechanism that does not need 1−φ→1 (rows 4, 5, 6).** The data decomposition is clear: Q/D rose mainly through Q/Y, with the R&D share steady near 7%. The current mechanism produces the opposite decomposition. A replacement should let the price of incumbent claims rise relative to entry cost: a convex or goods-denominated entry cost, a declining a(N), heterogeneous varieties whose rents entry cannot replicate, or a bubble component that lifts q above w_H/(aN). The targets are the fall in B_H/Q (0.10 → 0.08) and Q/w_H of about ×2.9.

4. **Factor-proportions block (rows 7–9).** With ρ>1 the model cannot hold rising H/L, a flat premium and ξ>ν together. Options: let H_t grow exogenously and re-check the ordering, separate the skilled production input from BA+ employment in the mapping, or accept that the φ-decay mechanism (which needs ρ>1 and ξ>ν) is not the source of the valuation facts.

5. **Growth calibration, RoW and the absorbing regime (rows 10, 14–16).** ξ_W>0 and ν_b>0 (`Two_country_proudction_fixed_nu_b` has a fixed-exponent solver) would remove RoW stagnation and the zero-growth absorbing regime. Output growth needs a·H, 1−φ and ν_u disciplined jointly.

## 4. Dimensions the data cannot discipline

π and the b-regime technology (no operational regime classifier; an all-u sample is right-censored), the bubble share, γ<1 (external evidence centers on γ≈1), and the RoW safe rate R_f^W. These remain scenarios, not targets.

## 5. Source files used

- Model: `AI_drafting/V6_production.tex` lines 300–515 (production, free entry, output identity), 1281–1335 (NFA bridge), 1506–1540 (technology primitives), 2074–2135 and 2305–2365 (cone and asymptotic reduction). Solver: `Two_country_proudction_zero_nu_b/TwoCountryProductionOLG.jl` (`compute_production`).
- Simulations: `outputs_zero_nu_b/05_nu_u_funding_regime_sweeps/{all_u_and_realized_switch_state_paths,production_wage_and_force_paths,us_bubble_share_bound_leakage,stock_funding_identity_summary}.csv`; `outputs_zero_nu_b/06_post2008_ahp_nfa_calibration_search/{model_empirical_comparison,candidate_summary,best_candidate_path,run_manifest}.csv`; `outputs_zero_nu_b/02_ahp_hkt_scalar_tail_bubble_bounds/calibration_manifest.csv`; `outputs_zero_nu_b/04_phi_spillover_funding_sweeps/spillover_sweep_summary.csv`.
- Calibration: `Calibration_R1/1_Do/runs/01_observed_labor/{report.md,Spillover_Diagnosis/README.md,results/baseline_allocation.csv}`; `Calibration_R1/1_Do/runs/02_fixed_mean_labor/{README.md,results/run_comparison.csv,results/conditional_paths.csv,results/calibration_status.json}`; `Calibration_R1/1_Do/shared/references/data_audit.md`.
- Data: `Empirical_Mapping_Annual/data_intermediate/{us_corporate_external_corporate,us_corporate_external_external,labor_wages,row_corporate}.csv`; `data_final/{implied_beta_US_main,implied_ai_US_main,us_row_dq_two_panel}.csv`; `diagnostics/{implied_beta_readme.md,overidentification_checks.csv}`; `Mechanism_Evidence_US_ROW/processed/dated_moments.csv`; `WRDS_Enhancement_2026-09-19/processed/wrds_dated_moments.csv`; `AHP_NFA/ahp_us_nfa_period_summary.csv`; `US_Equity_Positions/{summary_statistics.json,us_equity_capitalization_summary.json}`; `Skill_Premium_and_RD_Share_2026-10-26/{README.md,data/derived/*.csv,figures/data/*.csv}`.

## 6. Revisions of 30 October

Changes from the 26 October draft after recomputation:

- **Row 4:** "D/Y rose" depends on the window. Over 2009→2024 D/Y fell (14.4% → 12.5%). The robust statement is that D/Y has no downward trend and Q/Y dominates.
- **Row 6:** the draft's "three independent checks" are one restriction written three ways. The implied a·H decline is corrected to −19% to −38% (draft −40%), with a itself at −54% to −62%.
- **Row 8:** the draft's claim that the skilled bill share goes to zero was wrong. It follows the identity w_H H/e=βζ·aH/G_N, with limit 7.5%.
- **Row 10:** output growth added; the draft omitted it.
- **Row 12:** scale miss corrected to 13–620× (draft 50–100×), and the NFA/Y trend added.
- **Row 14:** e_W is not constant at every date; φ_W at T=80 is 0.04–0.53 (draft 0.12–0.53).
- **Other numbers:** H/L +134% since 1994 (draft 85%); ζ at T=80 is 0.50–0.56; μ floor 2.35–2.81, and μ=2.34–3.02 with 1−φ≈7%; NSCG lower bound 6.1% (2013, a year with a data caveat); A_X/A_L is 10 in both calibrations (draft said 10 or 15); q_W end range 0.06–0.16.
- **Mechanism statements:** the 1.8% R&D share comes from G_N=a·βζ(e/w_H), not from a dominant production margin; T≥7 years suffices for A/(Te)<1 in 2025, so a generation-length period is not required.
- **Added:** the closed-form μ comparison (section 2.2) and the identity w_H H/e=(Q/e)(aH/G_N) (section 2.5).
- **Rows 12 and 13, vintages:** external accounts exist in a June 2026 release (`AHP_NFA`, notebook 06 targets) and a September 2026 release. The draft mixed them. Row 13 now reports both, and foreign-held equity in 2025 is about 42% of EV on the same vintage, not 49%. Row 12's NFA/GVA now uses the same vintage as its ΔNFA.
- **Row 9:** eight distinct premium series; the ninth row in `calibration_sensitivity.csv` is a splice equal to the re-censored CPS series.
- **Row 6:** the −38% in implied a·H comes only from the patent stock. The other three knowledge mappings give about −20%.
