# Why P1 fails: accounting and structural diagnosis

Investigation date: 12 October 2026. All numerical results use the same preserved September 2026 US data as the original calibration. The sample is 1994–2022 unless stated otherwise. This investigation preserves the original calibration and the V6 manuscript/solver. No parameter has been changed to obtain admissibility.

## Finding

**P1 is algebraically correct under V6. The failure rejects the joint mapping and assumptions used to apply it to US corporate accounts. It does not establish that the raw data are erroneous, or that the theory is mathematically inconsistent.**

The strongest measured discrepancy is the use of gross corporate value added in a model whose current production costs are only skilled and unskilled labor. Depreciation and production taxes account for about **86.1% of the summed, real-dollar accounting shortfall at the zero-research boundary**. Removing them as a diagnostic reduces the inferred skilled production share substantially but does not make the baseline valid. Ordinary returns to capital, the mapping of the markup, research accounting and the labor-income bridge remain unresolved.

An important correction to the interpretation of the first run: the markups 3.25–4.0 used there are **outside the supplied grid under direct parameter transfer**. This does not establish that those numbers are outside an appropriately transformed empirical range. A gross-output firm markup and the effective multiplier on consolidated value added are different objects. No valid transformation has yet been estimated for this model's intermediate sector.

## 1. What the restriction actually says

Write `mu=1/vartheta`, `B_H=w_H H`, `B_L=w_L L`, and `C=B_H+B_L`. In the empirical bridge C is measured corporate compensation, including the allocated opportunity income of all H workers.

From the competitive, constant-returns final sector and the one-for-one, labor-only intermediate technology:

\[
Y=P X+B_L,\qquad P=\mu w_H,\qquad X=\varphi H.
\]

Therefore

\[
\varphi=\frac{Y-B_L}{\mu B_H}
=\frac1\mu\left[1+\frac{Y-C}{B_H}\right].
\]

This is V6's P1. It does not use the CES curvature, knowledge stock, innovation productivity, market value Q, discount factors or equilibrium solver. It remains valid at the no-research boundary. Allowing that boundary does not accommodate an implied share above one.

Positive research requires

\[
Y-C<(\mu-1)B_H.
\]

In words: the non-compensation residual must be smaller than the largest monopoly margin that could be earned if every skilled worker produced intermediates. In the mapped data that residual is too large. Negative research is how the inversion expresses this contradiction; it is not a numerical optimization failure.

Equivalently, since `I=(1-phi)B_H`,

\[
Y=C+(\mu-1)B_H-\mu I.
\]

Positive research makes the production-side accounting constraint stricter. The zero-research bound used below is deliberately the weakest possible test.

**Manuscript verification:** `AI_drafting/V6_production.tex`, production technology at lines 323–409, monopoly dividends at 438–450, and the output/income/IPO distinction at 496–514. The young-resource object `e` explicitly includes research founders' proceeds from new equity; employee compensation is an empirical proxy for it, not its definition.

## 2. Quantitative diagnosis

The source accounts obey

\[
Y^{GVA}=C+NOS+CFC+T_{prod},
\]

where CFC is consumption of fixed capital and T_prod is taxes on production/imports less subsidies. The last two components are recovered **together** as `Y-C-NOS` from the preserved accounts; they are not estimated separately here. Current corporate income/wealth taxes are a different item and are not used in this deduction. The [Federal Reserve integrated accounts](https://www.federalreserve.gov/Releases/Z1/current/html/S11_1_i_a.htm) explicitly distinguish these entries.

Define the output-cost shortfall at the boundary as

\[
W_0=Y-C-(\mu-1)B_H.
\]

At mu=1.61, W0 averages **26.17% of gross value added** across dates. CFC plus production taxes average **22.45%**. Their sums in common 2017 dollars account for **86.07%** of the summed W0; the remaining gap averages **3.71% of gross value added**. These are an accounting decomposition, not a causal allocation of the model error.

| Diagnostic specification | Implied phi range | Interior dates |
| --- | ---: | ---: |
| Original gross GVA, mu=1.61 | 1.459–1.915 | 0/29 |
| Net value added at factor cost, mu=1.61 | 1.002–1.212 | 0/29 |
| Net value added at factor cost, mu=1.84 | 0.876–1.061 | 22/29 |
| Gross GVA, raw hourly premium with headcounts, mu=1.61 | 1.471–1.896 | 0/29 |
| Gross GVA, raw hourly premium with observed-hours FTE, mu=1.61 | 1.434–1.796 | 0/29 |

Here the diagnostic net measure is `Y_net_factor_cost=C+NOS`. It still contains the ordinary net return to capital as well as possible rents. Substituting this measure into P1 is an accounting experiment, **not a derivation that the original CES is a production function for that net measure**. It must not be promoted to the baseline solely because it produces smaller residuals. Even this substitution leaves every year infeasible at 1.61; the minimum 1.002 should not be overinterpreted without sampling/revision uncertainty, but the maximum 1.212 is substantial.

The concrete 2022 example, in trillion 2017 USD, is:

| Quantity | Value |
| --- | ---: |
| Gross GVA | 13.0299 |
| Total compensation C | 7.2993 |
| Allocated skilled compensation B_H | 3.6133 |
| Non-compensation residual Y-C | 5.7306 |
| Largest monopoly margin, 0.61 B_H | 2.2041 |
| CFC plus production taxes | 2.9669 |
| Net operating surplus | 2.7637 |

The discrepancy is therefore economically large under the original gross-value-added mapping. It is much smaller, but not eliminated, after removing depreciation and production taxes.

## 3. Genuine weaknesses in the data mapping

**Wage bills versus wage indexes.** A composition-adjusted hourly wage premium is useful for studying skill prices. Multiplying it by changing headcounts is not an exact way to allocate actual annual compensation. The bridge ignores differences in hours, benefits, observed earnings coverage, sector perimeter and composition. The FTE and raw-premium checks above do not replace a properly measured wage bill; they show that these readily available variants do not remove the gross-GVA failure.

With `s=B_H/C`, the boundary requires

\[
s\geq \frac{Y/C-1}{\mu-1}.
\]

That required share exceeds one in **23 of 29 years**. Conditional on the gross GVA/total-compensation mapping and mu=1.61, no rearrangement of a fixed compensation total across skill groups can fix those years. Holding the skill bill share fixed would instead require total modeled resources **28.3–40.7% above observed compensation** merely to reach zero research. There is no independent evidence in this run for such an addition.

**Perimeter.** The corporate data combine NFC and broad domestic financial business, including institutions that are not represented by CPS private-for-profit wage/salary employment. CPS cannot fully isolate incorporated employers. Narrowing the corporate accounts while retaining an economy-wide labor split does not create an exact sector match. Future work should choose a sector before observing which variant fits and measure its output, wages, research, capital and valuation consistently.

**Research production versus equity transfers.** In V6, research income is financed by new claims and is excluded from current final-good Y. The national accounts capitalize research production and record employee compensation. BERD payroll is not the same transaction as founders' IPO proceeds, and all broad nonroutine-cognitive employment is not R&D. The [BEA R&D measurement document](https://www.bea.gov/system/files/2025-09/research-and-development-satellite-account-technical-document.pdf) separately constructs research compensation, operating surplus and production taxes, and addresses survey coverage and establishment/enterprise alignment.

However, a simple change of research capitalization cannot by itself reverse the rejection. Under the restrictive bridge `Y_GVA=Y_model+I` with C unchanged, self-consistency gives

\[
I=\frac{B_H-\vartheta(Y_{GVA}-B_L)}{1-\vartheta}.
\]

The numerator is the same negative quantity as before and the denominator is positive. Hence I stays negative. Merely subtracting an arbitrary R&D expenditure from Y and keeping all other equations unchanged would not be a defensible repair.

**Objects that cannot cause this P1 failure:** changing Q, shifting post-entry stock timing, changing rho, fitting a or N, or consistently rescaling labor and monetary units. These matter for later restrictions but do not change the dimensionless P1 ratio. Annual-to-generation flow scaling also leaves P1 unchanged when output and wages are scaled consistently. A changed cohort composition is a substantive new population mapping, not a unit conversion.

## 4. Why the markup evidence needs to be remapped

The Plan's 1.61 candidate is a listed-firm sales-weighted gross price/marginal-cost estimate; V6 applies one homogeneous markup to a particular intermediate stage with only skilled labor costs. These differ in sector, cost perimeter, aggregation weights and time. The model's final good is produced competitively, so its intermediate markup also cannot simply be called the aggregate-economy markup.

A stylized accounting illustration makes the basis issue concrete. Suppose gross sales are R, purchased materials are M=s_M R, and all remaining variable primary-input cost is C_P. Under the stated constant-returns/no-overhead cost bridge,

\[
C_P+M=R/\mu_{GO}.
\]

Then the multiplier on value added relative to primary-input cost is

\[
\mu_{VA}=\frac{R-M}{C_P}
=\frac{1-s_M}{1/\mu_{GO}-s_M}.
\]

For mu_GO=1.61, material revenue shares of 0.40, 0.45 and 0.50 imply multipliers **2.713, 3.214 and 4.128**. The denominator must be positive. These material shares are illustrative, not measured in the supplied matched panel. Primary-input costs still include capital where present; converting the markup does not eliminate that cost.

This calculation shows why comparing a model-bound markup of 3.08 directly with a firm-level estimate of 1.61 is not decisive. It does not justify selecting s_M=0.45 because it clears the bound. Correct aggregation needs matched input-output or firm/industry data; transform before aggregating and do not infer the cost shares from P1. Basu (2019, [published article and full issue](https://topcat.aeaweb.org/full_issue.php?doi=10.1257/jep.33.3), especially printed p.17) discusses this distinction and the need for firm-level checks. His illustration is a warning about translation, not an endorsement of a high US calibration. Network aggregation requires further assumptions; see [Baqaee and Farhi, Productivity and Misallocation in General Equilibrium](https://www.nber.org/system/files/working_papers/w24007/revisions/w24007.rev10.pdf).

## 5. A defensible resolution

**Recommended approach: repair the measurement design first; use independent research and capital evidence to decide whether a structural extension is warranted. Keep P1 as an overidentifying test during that work.**

1. **Freeze a population and accounting contract before fitting.** Prefer a sector with separately measurable output, costs, labor and R&D. For aggregate US calibration, NFC is a plausible starting scope only if the labor/R&D/valuation counterparts can also be restricted consistently. Select the vintage, tax basis, depreciation treatment, domestic scope and research-output convention in advance. Construct actual compensation bills using matched earnings/hours and benefits; keep composition-adjusted skill prices as separate observations.

2. **Obtain an independent interval for research allocation.** Use matched researcher FTE and compensation, with explicit treatment of technicians, support personnel, non-BA workers and R&D wage differences. Do not infer research as the residual of P1. Existing BERD employee compensation is useful for diagnosis: the preserved 2015–2022 series gives `1-I_RD/B_H` of **0.896–0.917** under the strong common-wage/all-R&D-skilled bridge. This is not an observed headcount share or an accepted model phi. Its survey perimeter and innovation definition need reconciliation. The [NCSES labor-cost decomposition](https://ncses.nsf.gov/pubs/nsf23322?org=NSF) distinguishes employee compensation from temporary staffing and other research costs.

3. **Translate markup evidence on the matched production stage.** Use independently observed material/cost shares, and distinguish variable costs from overhead. Establish whether the model parameter is a structural intermediate markup or a reduced-form value-added multiplier. The latter interpretation changes what external evidence can discipline it. Do not estimate the translation solely from the feasibility threshold.

4. **If aggregate ordinary-capital payments remain material, represent them explicitly.** For example, adding competitively rented K to the *final* constant-returns production sector gives

\[
Y^{fc}=P X+w_L L+r_KK,
\qquad
\varphi=\frac{Y^{fc}-w_L L-r_KK}{\mu w_HH},
\]

where Y_fc is measured on a compatible factor-price gross basis and the gross capital rental cost includes depreciation. Do not subtract CFC twice. Estimate physical stocks and user-cost ranges from independent asset-price, depreciation and required-return evidence. A national-account capital-compensation series constructed residually as value added minus labor is **not independent evidence of normal capital costs**, because it also absorbs rents. If capital is instead inside the monopolistic intermediate producer, both its marginal-cost relation and X=phi H change; rederive the model rather than using this final-sector formula.

5. **Test before calibrating.** Given independent research payroll and the chosen markup basis, calculate the cost gap

\[
W^{required}_t=Y^{mapped}_t-B_{L,t}-\mu_t(B_{H,t}-I^{RD}_t).
\]

Compare it with independent capital-cost ranges and other explicitly modeled payments. This is a specification check; setting an unrestricted time-varying W equal to W_required would be a tautological fit. With the unmodified gross-GVA mapping, the 2015–2022 BERD payroll diagnostic requires an omitted-cost gap of **26.7–31.7% of GVA**. After the CFC/tax diagnostic deduction, the remaining gap is **5.6–9.1% of original GVA**. These are required amounts, not observed capital returns. Under the additional wage-only R&D-output bridge `J_RD=I_RD`, the required amount falls by I_RD/Y; that bridge is also unverified and is separately tabulated.

Use a predeclared measurement range and holdout period. If no common parameter region satisfies the independent moments, report which assumptions fail or remain unidentified. Do not delete invalid years, clip phi, choose a skill partition for fit, subtract all operating surplus, add a free residual, or rename AHP free cash flow as monopoly profits.

**Downstream consequences:** A capital or output-scope revision changes the CES wage restrictions and possibly knowledge spillovers. P4/P5 must be rederived before re-estimation. Current enterprise value includes claims on tangible and intangible operations; it is not automatically the post-entry capitalization of new varieties. Adding capital therefore also requires rechecking P2, entry costs/valuation parity, income ownership, savings and full GE. Subtracting a replacement-cost capital stock from enterprise value is not automatically a valid knowledge-claim valuation.

The defensible current conclusion is an incompatibility of the original empirical interpretation, with substantial evidence locating the problem in gross-accounting and omitted-input/markup mappings. The available moments do not uniquely identify a single cause. The evidence supports the measurement audit and conditional specification tests above; it does not yet warrant a new calibrated US parameter vector.

## Reproduction and evidence

### Data sources actually used

The main analysis keeps the original **14 September 2026** snapshot and 1994–2022 US sample. It combines Federal Reserve/BEA accounts accessed through FRED with Census/BLS CPS outgoing-rotation microdata distributed by NBER. The R&D diagnostic uses NCSES business R&D employee compensation for 2015–2022; it does not replace a baseline input.

| Object | Preserved mapping and original source |
| --- | --- |
| Gross value added | `Y_US_AHP_TOTAL_CORP_GVA`: FRED `BOGZ1FU106902501Q + BOGZ1FU796902505Q` |
| Compensation | `COMP_US_AHP_TOTAL_CORP`: FRED `BOGZ1FU106025005Q + BOGZ1FU796025005Q` |
| Net operating surplus | `NOS_US_AHP_TOTAL_CORP`: FRED `BOGZ1FU106402101Q + BOGZ1FU796402101Q` |
| Skill quantities | `H_US_COLLEGE_EQUIV` and `L_US_NONCOLLEGE`: NBER CPS MORG private-for-profit BA+/non-BA headcounts |
| Baseline relative wage | `WHWL_US_CPS_COMPOSITION_ADJ_COLLEGE_NONCOLLEGE`: CPS hourly mean wages, with 2007 composition weights |
| Wage/hour diagnostics | `WHWL_US_CPS_RAW_MEAN_HOURLY_COLLEGE_NONCOLLEGE`, `H_US_COLLEGE_EQUIV_FTE_OBSERVED_HOURS`, `L_US_NONCOLLEGE_FTE_OBSERVED_HOURS`: same CPS population and vintage |
| Research payroll diagnostic | `I_US_BERD_RD_COMP`: NCSES `NCSES_RD_2015_COST` through `NCSES_RD_2022_COST`, salary/wages/fringe plus stock compensation, excluding temporary staffing |
| Common price index | BEA/FRED `GDPDEF`, 2017=100; the original panel's annual mean deflator is retained |

The three corporate-account rows consistently sum nonfinancial corporate business and domestic financial business. Quarterly FU flows are summed without dividing by four. The combined CFC/tax term is derived from those three rows. Corporate nominal millions and R&D nominal billions are converted to trillions and divided by the same annual deflator. Common deflation cancels from each year's P1 ratio. The corporate compensation total is allocated with the original wage-premium/headcount bridge, whose limitations are assessed above. Exact original baseline selections are in `../results/selected_input_observations.csv` and `../data_audit.md`; added observations, source IDs and vintages are saved in this investigation's `results/additional_input_observations.csv`. Web checks concern definitions and literature, not updated numerical observations.

### Re-run

Run from the project root:

```sh
/Users/jipengcheng/opt/anaconda3/bin/python3 Codes/Calibration_R1/Do/P1_Diagnosis/investigate_p1.py
```

The script uses only preserved US observations and writes its own results. Its internal checks verify the accounting decomposition, the equivalent P1 expressions, the markup illustration and the sign of the self-consistent research-capitalization inversion. This is not a new empirical identification test or a full raw-microdata rebuild.

Delivery checks also compared all 29 recomputed original P1 shares against the saved first-run allocation (maximum absolute difference `3.6e-15`), verified input hashes and observation uniqueness, and visually reviewed the decomposition figure. Results are recorded in `results/delivery_checks.json`.

Files:

- `results/annual_decomposition.csv`: every yearly share, cost gap and diagnostic mapping.
- `results/mapping_comparison.csv`: rejection counts, including raw-premium/FTE alternatives.
- `results/rd_payroll_diagnostic.csv`: independent-payroll proxy and required cost/markup gaps.
- `results/markup_basis_illustration.csv`: mathematical illustration; no materials shares estimated.
- `results/selected_years.csv`, `summary.json`: headline numbers.
- `results/additional_input_observations.csv`, `input_manifest.csv`: exact new mappings and used-file hashes.
- `results/p1_decomposition.png` and `.svg`: decomposition figure.
- `web_source_log.csv`: definition/literature checks and retrieval limitations. No live numerical observations replace the frozen sample.

The original `Do/results` files, Plan, V6 manuscript and reference solver are preserved. The first-run rejection remains valid for its explicitly specified inputs; this document qualifies its economic interpretation.
