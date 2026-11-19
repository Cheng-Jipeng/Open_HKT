# Credit, capital and buybacks (18 November 2026)

Question from the 16 Nov deck ([Logistics/Discussion_note/29_11_16/slides](../../../../Logistics/Discussion_note/29_11_16/slides/main.pdf)): if the HKT dividend channel ($D/Y\to0$) conflicts with the data, can $Q/Y$ rise through credit and capital expansion instead? And does $D$ miss share buybacks?

Deck: [credit_capital_buybacks_2026_11_18.pdf](credit_capital_buybacks_2026_11_18.pdf), 17 slides (slide 7: FCF decomposition; slide 9: where firm borrowing went, bounds; slides 12–14: the value side and cash-flow side of slide 3 explained for readers new to these data, and how the two connect; slides 16–17: glossary of abbreviations). Every number comes from `data/values.tex`, written by `scripts/build.py`.

## Findings

Sector: Z.1 nonfinancial corporate business (NFC), 93% of AHP total-corporate $Q$ in 2025. $Y$ = NFC GVA. Window 2009–2025, 2011 base alongside.

1. **Buybacks are already in $D$.** $D$ = AHP FCF $=\mathrm{NOS}-T-\mathrm{NCF}$ is measured before financing. Up to transfers and the statistical discrepancy, it equals payout to shareholders (dividends + net buybacks) + payout to creditors (interest − net borrowing) + net financial saving. The split between dividends and buybacks does not change it.
2. **With $D$ = shareholder payout, the conflict with HKT is stronger.** Net dividends + net buybacks rise from 6.6% of GVA (2009) and 10.5% (2011) to 11.2% (2025). The payout yield on equity falls (2.89% → 2.11% from 2009; 4.48% → 2.11% from 2011), only because equity value rises.
3. **Credit does not move $Q/Y$.** By the Fed identity $Q=E+\mathrm{FDI}^{mv}+\mathrm{TL}-\mathrm{FA}$, debt enters $Q$ one-for-one. Debt securities + loans: 93.8% of GVA (2009) → 97.2% (2025), range 87–117%. Of the +272 pp rise in $Q/Y$ (2009–25), debt adds +3 pp, domestic equity +263 pp, FDI equity +40 pp, other liabilities minus financial assets −34 pp.
4. **Capital does not move $Q/Y$.** $K/Y$ at replacement cost: 202% → 202%. Tobin's $q=Q/K$: 1.11 → 2.45, which is all of $\Delta\log(Q/Y)$ (100% from 2009, 105% from 2011).
5. **Internal funds covered net investment; almost all FCF went to shareholders.** 2009–25 cumulated (Z.1 S.5.a, identity closes exactly): $\mathrm{NOS}-T$ = \$28.6 tn against net capital formation \$7.8 tn, so FCF = \$20.8 tn. Of this, shareholders received \$19.4 tn (93%; 98% over 2011–25). Creditors put money in on net (net borrowing \$8.1 tn > net interest \$4.8 tn), and so did foreign parents (net direct investment −\$1.8 tn). Gross acquisition of financial assets is \$15.8 tn, but other liabilities rose \$9.4 tn, so other net financial saving is only \$2.2 tn. Rents, transfers and the statistical discrepancy are \$4.2 tn. Over the same years $Q$ rose \$62 tn.
6. **The rise in market equity is concentrated.** Seven AI-related firms (AAPL, MSFT, GOOGL, AMZN, META, NVDA, ORCL) are 7% of Compustat nonfinancial market equity in 2009, 35% in 2025, and 41% of its rise.
7. **The AI cycle is the first credit-and-capital episode in the window, and it starts late in 2025.** MSFT + GOOGL + AMZN + META + ORCL, trailing four quarters: capex \$154bn (2023Q4) → \$691bn (2026Q3), now 95% of operating cash flow. Debt \$430bn → \$873bn; gross long-term issuance \$343bn in the last four quarters. Buybacks fall to \$81bn. Their debt rise is 37% of NFC net borrowing in the four quarters to 2026Q2, but their debt is 5% of NFC debt. Compustat is global and consolidated while Z.1 is domestic, so these shares are orders of magnitude.
8. **Where firm borrowing went: bounds, not a point (slide 9).** Compustat US nonfinancial firms, 2009–25, `scripts/debt_use_bounds.py`.
   - Firms with positive net debt issuance borrowed \$9.8 tn. Others repaid \$4.4 tn, so the net is \$5.3 tn (Z.1: \$8.1 tn).
   - Money is fungible inside a firm, so each use gets a [lower, pro rata, upper] share of that borrowing:
     - payout [4, 22, 43]%
     - capex [13, 32, 53]%
     - cash M&A [14, 22, 33]%
     - cash and financial assets [11, 22, 37]%
     - payout + cash M&A, which is the Z.1 shareholder line: [23, 43, 65]%
   - Only 4% of borrowing must have gone to payouts. Between 2% and 26% of payouts were debt-financed (13% pro rata).
   - Capex's pro-rata share is 26–35% a year before 2022 and 36–40% in 2022–25.

## Files

| Path | Content |
|---|---|
| `scripts/fetch_fred.py` | 30 Z.1 / NIPA series from FRED (curl). Raw CSVs and `_metadata.csv` (titles, units, coverage) in `data/raw/fred/`. |
| `scripts/fetch_wrds.py` | Compustat `funda` (US-incorporated USD filers, FY1989–2026) and `fundq` for 8 AI-related firms (2014Q1–2026Q3). Writes `data/raw/wrds/` and `manifest.json`. Licensed data: do not redistribute. |
| `scripts/fetch_z1.py` | Z.1 table S11.1.i.a (= S.5.a), NFC integrated accounts, annual, from the Fed's CSV release (10 Sep 2026). Writes `data/raw/fed_z1/` with the line dictionary and `manifest.json`. |
| `scripts/build.py` | Processed tables, `data/values.{json,tex}`, figures `f1`–`f6`. Checks the Fed $Q$ identity and that the vintage matches the project mapping file (it does, 0.00%). |
| `data/processed/z1_nfc_annual_trn.csv` | NFC stocks and flows, trillion USD, 1990–2025. |
| `data/processed/z1_nfc_ratios_pct_gva.csv` | The same as % of NFC GVA. |
| `data/processed/z1_q_decomposition.csv` | Contributions to $\Delta(Q/Y)$ (equity, FDI, debt, other) and $\Delta\log(Q/Y)=\Delta\log q+\Delta\log(K/Y)$, bases 2009 and 2011. |
| `data/processed/fcf_decomposition_nfc_trn.csv`, `fcf_decomposition_nfc_pct_gva.csv` | FCF $=\mathrm{NOS}-T-\mathrm{NCF}$ split into net dividends, net buybacks, net interest, net borrowing, direct investment (outward, inward, excl. reinvested earnings), other financial assets, other liabilities, rents, transfers, capital transfers, statistical discrepancy; 1990–2025. |
| `data/processed/payout_robustness_nfc.csv` | $\Delta\log(Q/D)$ split with $D$ = FCF, shareholder payout, net dividends; bases 2009, 2011, 3-year averages. |
| `data/processed/compustat_nonfin_annual_bn.csv` | Compustat nonfinancial aggregates (dividends, gross buybacks, issuance, debt, capex, R&D, payout yields), USD bn. |
| `data/processed/ai_big5_quarterly_bn.csv`, `ai_firms_debt_by_firm_bn.csv`, `ai_firms_quarterly_musd.csv` | Hyperscaler quarterly flows (trailing four quarters), debt and cash. |
| `figures/f1_credit_q_funding` | $Q/Y$, equity/Y, debt/Y and the contribution bars. |
| `figures/f2_capital_tobin_q` | $K/Y$ by asset type against $Q/Y$; Tobin's $q$. |
| `figures/f3_nfc_flows` | Net dividends + net buybacks vs FCF; net borrowing, NCF and net buybacks. |
| `figures/f4_compustat_payout` | Gross buybacks, dividends, issuance; payout yields on market equity. |
| `figures/f5_ai_hyperscalers` | Hyperscaler cash flows and debt by firm. |
| `data/processed/stock_flow_reconciliation_nfc_trn.csv` | Change in each claim on the NFC sector (E, FDI equity, debt, other liabilities, minus financial assets, and their sum Q), end-2009 and end-2011 to end-2025, split into transactions (FU), revaluation (FR) and other changes; Z.1 S11.1.i.a. 2009 base: Q +62.0 tn, transactions +0.5, revaluation +59.1. |
| `figures/f6_fcf_decomposition` | Where FCF goes: annual stacked uses (% of GVA) and the cumulated 2009–25 waterfall (USD tn). |
| `scripts/debt_use_bounds.py` | Run before `build.py`, which reads its output. Firm-level sources-and-uses bounds on where positive net borrowing went: payout, capex, cash M&A, cash and financial assets, operating deficit. Variants: gross payout, R&D as investment, firm-cumulative flows. Reads the Compustat extract and writes aggregates only. |
| `figures/f7_debt_use_bounds` | Bounds on the share of positive net borrowing going to each use (2009–25), and pro-rata shares by fiscal year. |
| `data/processed/debt_use_bounds_annual.csv`, `debt_use_bounds_summary.csv` | Bounds by fiscal year (USD bn), and summarized over 2009–25 and 2011–25 (% of positive net borrowing, % of payout, % of capex). |

## Data sources for debt and buybacks

- **Debt (aggregate):** Z.1 B.103/L.103 NFC debt securities and loans (`BCNSDODNS`), debt securities (`NCBDBIQ027S`), private-credit loans (`BOGZ1FL103167205Q`, new in Z.1); net borrowing from F.103 (`BOGZ1FU104104005Q`).
- **Buybacks (aggregate):** Z.1 net equity issuance by NFCs (`BOGZ1FU103164103Q`). Net of IPOs and new issues, and includes cash-financed M&A retirements, so it is smaller than gross buybacks.
- **Buybacks (firm level):** Compustat `prstkc` (purchase of common and preferred stock), gross; `sstk` for issuance.
- **Not pulled yet:** gross corporate bond issuance by issuer (SIFMA; Mergent FISD on WRDS), S&P 500 quarterly buybacks (S&P Dow Jones Indices), off-balance-sheet data-center financing.

## Rebuild

```bash
cd scripts
uv run --no-project --python 3.12 python -I fetch_fred.py
uv run --no-project --python 3.12 python -I fetch_z1.py
WRDS_USER=$(cut -d: -f4 ~/.pgpass | head -1) uv run --no-project --python 3.12 --with wrds --with pandas python -I fetch_wrds.py
uv run --no-project --python 3.12 --with numpy==2.3.5 --with pandas==2.2.3 python -I debt_use_bounds.py
uv run --no-project --python 3.12 --with numpy==2.3.5 --with pandas==2.2.3 --with matplotlib==3.10.0 python -I build.py
cd .. && latexmk -pdf credit_capital_buybacks_2026_11_18.tex
```

`fetch_fred.py` keeps existing files unless `--refresh` is passed; `fetch_wrds.py` and `fetch_z1.py` refuse to overwrite.
