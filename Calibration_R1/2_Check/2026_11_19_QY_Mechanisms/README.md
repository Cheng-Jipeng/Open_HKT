# Q/Y mechanisms vs data (19 November 2026)

Question: which mechanisms can drive the rise in $Q/Y$ (US corporate enterprise value over gross value added), and what do the data say about each?

Deck: [qy_mechanisms_data_2026_11_19.pdf](qy_mechanisms_data_2026_11_19.pdf), 34 slides (22 main, 12 appendix). It merges two earlier decks into one argument and adds a scorecard (slide 2), a sector reconciliation table (slide 4) and a synthesis figure (slide 5):

- **Deck A**, 16 Nov 2026: HKT mechanisms. [Logistics/Discussion_note/29_11_16/slides](../../../../Logistics/Discussion_note/29_11_16/slides/README.md). Sector: AHP **total corporate**.
- **Deck B**, 18 Nov 2026: credit, capital and buybacks. [2026_11_18_Credit_Buybacks](../2026_11_18_Credit_Buybacks/README.md). Sector: Z.1 **nonfinancial corporate (NFC)**, 93% of total-corporate $Q$ and 87% of its GVA in 2025.

Every slide names its sector. Window 2009–2025, with 2011 bases alongside (2009 FCF is a crisis spike); pre-2009 is grey context. KLEMS series end in 2023.

## Scorecard (slide 2)

Values are given as 2009 / 2011 → 2025.

| | Mechanism | Sector | What must move | Data | Verdict |
|---|---|---|---|---|---|
| a | HKT dividend channel, φ→0 | total corp. | D/Y falls | D/Y 14.4 / 12.5 → 12.7%. Q/Y is 87–102% of Δlog(Q/D) | Conflicts with the data |
| b | Payout form, buybacks | NFC | dividends understate D | D = FCF already includes buybacks. Payout/Y 6.62 / 10.5 → 11.2% | Does not rescue (a) |
| c | Skilled wage bill, free entry Q=(G/a)w_H | total corp. × KLEMS | B_H/Y up; B_H/Q = aH/G up with H | B_H/Y 29.6 / 29.5 → 31.8% (2023). B_H/Q 0.153 → 0.082, against 0.222 at constant a | Direction right, size not: Q outruns B_H |
| d | Funding side | US | ζ → 1 | ζ 1.21 / 1.29 → 1.32; mean 1.29 | No convergence |
| e | Foreign purchases | AHP external | RoW net purchases/Y up | 3.4% of GVA a year (2002–07) vs 3.5% (2009–25). Valuation is 74 / 76% of the rise in foreign-held US equity | Transmission, not cause |
| f | Credit | NFC | Debt/Y up | 93.8 / 87.6 → 97.2%. Debt adds +3.40 of the +272 pp rise in Q/Y | Flat |
| g | Capital deepening | NFC | K/Y up | 202 / 209 → 202% | Flat |
| h | What remains: price of claims | NFC, Compustat | q = Q/K up | q 1.11 / 1.25 → 2.45, which is 99.9 / 105% of Δlog(Q/Y). Seven AI-related firms account for 40.7% of the rise in market equity | Carries the rise. Part of it may be unmeasured intangibles |

Every quantity channel is flat, or rises only with income. Skilled pay rises with $Q$ in direction, but $Q$ rises faster. What is left is a rise in $q$, concentrated in a few large firms. Candidates for that rise (not tested here) are rents and markups, unmeasured intangibles, and a lower required return (the funding side).

## Synthesis figure (slide 5)

`figures/s_synthesis_indexed_ratios.pdf` has eight panels. Each panel shows one mechanism's ratio, over its own sector's GVA, together with $Q/Y$ of the same sector (dashed). All series are indexed to **2011 = 100**. 2009 is not used as the base because 2009 FCF is a crisis spike. The 2009-base values are printed under the figure.

| Panel | Series (sector) | 2025 index, 2011 = 100 | 2025 index, 2009 = 100 | Same-sector Q/Y, 2011 = 100 |
|---|---|---|---|---|
| a | D/Y (total corp.) | 101 | 88 | 206 |
| b | Payout/Y (NFC) | 107 | 169 | 190 |
| c | B_H/Y (total corp. × KLEMS, to 2023) | 108 | 107 | 172 (to 2023) |
| d | ζ (US) | 103 | 109 | 206 |
| e | RoW equity quantity / GVA: quantity of US equity held by RoW (position over its price index) over nominal GVA (AHP external) | 76 | 80 | 206 |
| f | Debt/Y (NFC) | 111 | 104 | 190 |
| g | K/Y (NFC) | 97 | 100 | 190 |
| h | q = Q/K (NFC) | 197 | 221 | 190 |

On a 2009 base, Q/Y is 241 (total corporate) and 221 (NFC).

The data are in `data/synthesis_indexed_ratios.csv`.

## Sector reconciliation (slide 4)

`data/sector_reconciliation.csv`

| | 2009 | 2011 | 2025 | Δlog from 2009 | Δlog from 2011 |
|---|---|---|---|---|---|
| Q/Y, total corp. | 1.94 | 2.27 | 4.66 | 0.88 | 0.72 |
| Q/Y, NFC | 2.24 | 2.61 | 4.97 | 0.79 | 0.64 |
| D/Y, total corp. | 14.4% | 12.5% | 12.7% | −0.13 | 0.01 |
| D/Y, NFC | 13.9% | 12.8% | 11.8% | −0.16 | −0.07 |

Q/Y's share of Δlog(Q/D):

- total corporate: 87% (2009 base), 102% (2011 base)
- NFC: 83% (2009 base), 90% (2011 base)

The total-corporate row reproduces deck A exactly; `build.py` asserts this. The NFC row is cross-checked against deck B's strings.

## Files

| Path | Content |
|---|---|
| `qy_mechanisms_data_2026_11_19.tex` | Source, pdflatex. Numbers come from three namespaced value files: `\va{key}` (deck A), `\vb{key}` (deck B), `\vc{key}` (new). An undefined key prints a red `??ns:key`. |
| `scripts/build.py` | Reads both decks' `data/values.tex` and copies the formatted strings verbatim into `data/values_a.tex` (csname `va:`) and `data/values_b.tex` (`vb:`). This is needed because keys such as `QY2009` and `Y_tn2009` collide between the decks with different meanings. It also copies the figures, computes the new numbers and draws the synthesis figure. Finally it scans the `.tex` and **fails if any `\va`/`\vb`/`\vc` key is undefined**, or if the un-namespaced `\val{}` is used. It writes nothing outside this folder and fetches nothing. |
| `data/values_a.tex`, `data/values_b.tex` | Verbatim copies of the two decks' value strings (163 and 770 keys). |
| `data/values_c.tex`, `values_c.json` | New numbers: B_H/Y, the sector table, synthesis indices, and the NFC share of GVA. |
| `data/synthesis_indexed_ratios.csv`, `data/sector_reconciliation.csv` | Data behind slides 4–5. |
| `figures/a_*.pdf` | Copies of deck A figures: `f_ratios`, `f_decomposition`, `f_gva_percent`, `f_gva_values`, `c_labor_klems`, `f_free_entry`, `f_zeta`, `f_valuation`, `f_topcode_monthly`, `f_premium_treatments`. |
| `figures/b_*.pdf` | Copies of deck B figures `f1`–`f7`. |
| `figures/s_synthesis_indexed_ratios.pdf` | New figure. Drawn in deck B's matplotlib style, with pre-2009 in grey. |

Inputs read by `build.py`, all read-only:

- deck A `data/values.tex` and `figures/`
- deck B `data/values.tex`, `figures/`, `data/processed/z1_nfc_ratios_pct_gva.csv` and `z1_nfc_annual_trn.csv`
- `Codes/Calibration_R1/2_Check/figures/figure_data.csv`
- `Codes/Calibration_R1/2_Check/figures/zeta_funding_ratio_1990_2025.csv`
- `Empirical_Data/AHP_NFA/ahp_us_nfa_decomposition_latest.csv`

## Which slides come from which deck

| Slides | Source |
|---|---|
| 1–5 | New: title, scorecard, framework, the fact with the sector table, synthesis |
| 6 | A3, plus the free-entry prediction from A11 |
| 7 | A5 |
| 8 | B8: figure and robustness table, with B's summary point 1 |
| 9 | A6b, with the key numbers of A6c |
| 10 | A7 |
| 11 | A11 |
| 12 | A8 |
| 13 | A9 |
| 14 | B3 |
| 15 | B4 |
| 16 | B5 |
| 17 | B6 |
| 18 | B7 |
| 19 | B9 |
| 20 | B10 |
| 21 | New. Draws on B8 (concentration), B14 (revaluation), A11, A12, B5 |
| 22 | A13 merged with B11 |
| Appendix | A10a, A10b, A6a, A6c, A12, B12, B13, B14; sources (A14 merged with B15); glossary in 3 slides (B's 2, extended, plus model and survey symbols) |

## Hand-typed numbers

Every other number comes from a value file.

- Model D/Y 1.39% → 0.08% and Δlog(Q/D) = 2.25 for ν_u = 1 (slide 7). Source: `2_Check/On_Model_vs_Data_Failed_Dimensions.md`, row 4, and `2_Check/slides/data/decomp_model.csv`, as listed in deck A's README.
- CPS top code (slides 23–24):
  - fixed top code \$2,884.61 = \$150,000/52
  - new rule: top 3% of earners, about \$9–11k
  - mean above the old cap about \$6k
  - MIS 4 gives 2.098, and 1.780 re-censored
  - BA+ above the cap 10% → 24% (ACS)
  - uncapped ACS hourly premium 2.086 → 2.173
  - rotation dates 2023m4 / 2024m4

  Source: `Empirical_Data/Skill_Premium_and_RD_Share_2026-10-26`, verified 2026-10-26, as in deck A's README.
- Markups μ = 2.34–3.02 without capital and 1.45–1.73 with capital (slides 21, 27). Source: `2_Check/On_Model_vs_Data_Failed_Dimensions.md`, section 2.2.
- From the literature:
  - BJVW research productivity −5.1%/yr (slides 11, 33)
  - DLEU markup 1.61 and the external markup range 1.10–1.84 (slides 21, 27)
- Deck A text (slides 22, 26):
  - ζ ≈ 1.3 and μ ≈ 1.5 in the options list
  - "7–10 pp below KLEMS" for the CPS skilled share
  - "about a third" of the rise in GVA
- Deck B's worked example on slide 29 (100, 20, 30, 5, 50, …). These are illustrative numbers.

## Rebuild

```bash
cd "Codes/Calibration_R1/2_Check/2026_11_19_QY_Mechanisms"
uv run --no-project --python 3.12 --with numpy==2.3.5 --with pandas==2.2.3 --with matplotlib==3.10.0 python -I scripts/build.py
latexmk -pdf qy_mechanisms_data_2026_11_19.tex
latexmk -c
```

To pick up new data, rebuild deck A or deck B in its own folder first; see their READMEs.
