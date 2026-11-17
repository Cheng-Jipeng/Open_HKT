# Credit, capital and buybacks (18 November 2026)

Question from the 16 Nov deck ([Logistics/Discussion_note/29_11_16/slides](../../../../Logistics/Discussion_note/29_11_16/slides/main.pdf)): if the HKT dividend channel ($D/Y\to0$) conflicts with the data, can $Q/Y$ rise through credit and capital expansion instead? And does $D$ miss share buybacks?

Deck: [main.pdf](main.pdf), 10 slides. Every number comes from `data/values.tex`, written by `scripts/build.py`.

## Findings

Sector: Z.1 nonfinancial corporate business (NFC), 93% of AHP total-corporate $Q$ in 2025. $Y$ = NFC GVA. Window 2009–2025, 2011 base alongside.

1. **Buybacks are already in $D$.** $D$ = AHP FCF $=\mathrm{NOS}-T-\mathrm{NCF}$ is measured before financing. Up to transfers and the statistical discrepancy, it equals payout to shareholders (dividends + net buybacks) + payout to creditors (interest − net borrowing) + net financial saving. The split between dividends and buybacks does not change it.
2. **With $D$ = shareholder payout, the conflict with HKT is stronger.** Net dividends + net buybacks rise from 6.6% of GVA (2009) and 10.5% (2011) to 11.2% (2025). The payout yield on equity falls (2.89% → 2.11% from 2009; 4.48% → 2.11% from 2011), only because equity value rises.
3. **Credit does not move $Q/Y$.** By the Fed identity $Q=E+\mathrm{FDI}^{mv}+\mathrm{TL}-\mathrm{FA}$, debt enters $Q$ one-for-one. Debt securities + loans: 93.8% of GVA (2009) → 97.2% (2025), range 87–117%. Of the +272 pp rise in $Q/Y$ (2009–25), debt adds +3 pp, domestic equity +263 pp, FDI equity +40 pp, other liabilities minus financial assets −34 pp.
4. **Capital does not move $Q/Y$.** $K/Y$ at replacement cost: 202% → 202%. Tobin's $q=Q/K$: 1.11 → 2.45, which is all of $\Delta\log(Q/Y)$ (100% from 2009, 105% from 2011).
5. **Debt financed payouts as much as investment.** 2009–25 cumulated: net borrowing \$8.1 tn, net capital formation \$7.8 tn, net buybacks \$5.7 tn, net dividends \$13.6 tn. Over the same years $Q$ rose \$62 tn.
6. **The rise in market equity is concentrated.** Seven AI-related firms (AAPL, MSFT, GOOGL, AMZN, META, NVDA, ORCL) are 7% of Compustat nonfinancial market equity in 2009, 35% in 2025, and 41% of its rise.
7. **The AI cycle is the first credit-and-capital episode in the window, and it starts late in 2025.** MSFT + GOOGL + AMZN + META + ORCL, trailing four quarters: capex \$154bn (2023Q4) → \$691bn (2026Q3), now 95% of operating cash flow. Debt \$430bn → \$873bn; gross long-term issuance \$343bn in the last four quarters. Buybacks fall to \$81bn. Their debt rise is 37% of NFC net borrowing in the four quarters to 2026Q2, but their debt is 5% of NFC debt. Compustat is global and consolidated while Z.1 is domestic, so these shares are orders of magnitude.

## Files

| Path | Content |
|---|---|
| `scripts/fetch_fred.py` | 30 Z.1 / NIPA series from FRED (curl). Raw CSVs and `_metadata.csv` (titles, units, coverage) in `data/raw/fred/`. |
| `scripts/fetch_wrds.py` | Compustat `funda` (US-incorporated USD filers, FY1989–2026) and `fundq` for 8 AI-related firms (2014Q1–2026Q3). Writes `data/raw/wrds/` and `manifest.json`. Licensed data: do not redistribute. |
| `scripts/build.py` | Processed tables, `data/values.{json,tex}`, figures `f1`–`f5`. Checks the Fed $Q$ identity and that the vintage matches the project mapping file (it does, 0.00%). |
| `data/processed/z1_nfc_annual_trn.csv` | NFC stocks and flows, trillion USD, 1990–2025. |
| `data/processed/z1_nfc_ratios_pct_gva.csv` | The same as % of NFC GVA. |
| `data/processed/z1_q_decomposition.csv` | Contributions to $\Delta(Q/Y)$ (equity, FDI, debt, other) and $\Delta\log(Q/Y)=\Delta\log q+\Delta\log(K/Y)$, bases 2009 and 2011. |
| `data/processed/payout_robustness_nfc.csv` | $\Delta\log(Q/D)$ split with $D$ = FCF, shareholder payout, net dividends; bases 2009, 2011, 3-year averages. |
| `data/processed/compustat_nonfin_annual_bn.csv` | Compustat nonfinancial aggregates (dividends, gross buybacks, issuance, debt, capex, R&D, payout yields), USD bn. |
| `data/processed/ai_big5_quarterly_bn.csv`, `ai_firms_debt_by_firm_bn.csv`, `ai_firms_quarterly_musd.csv` | Hyperscaler quarterly flows (trailing four quarters), debt and cash. |
| `figures/f1_credit_q_funding` | $Q/Y$, equity/Y, debt/Y and the contribution bars. |
| `figures/f2_capital_tobin_q` | $K/Y$ by asset type against $Q/Y$; Tobin's $q$. |
| `figures/f3_nfc_flows` | Net dividends + net buybacks vs FCF; net borrowing, NCF and net buybacks. |
| `figures/f4_compustat_payout` | Gross buybacks, dividends, issuance; payout yields on market equity. |
| `figures/f5_ai_hyperscalers` | Hyperscaler cash flows and debt by firm. |

## Data sources for debt and buybacks

- **Debt (aggregate):** Z.1 B.103/L.103 NFC debt securities and loans (`BCNSDODNS`), debt securities (`NCBDBIQ027S`), private-credit loans (`BOGZ1FL103167205Q`, new in Z.1); net borrowing from F.103 (`BOGZ1FU104104005Q`).
- **Buybacks (aggregate):** Z.1 net equity issuance by NFCs (`BOGZ1FU103164103Q`). Net of IPOs and new issues, and includes cash-financed M&A retirements, so it is smaller than gross buybacks.
- **Buybacks (firm level):** Compustat `prstkc` (purchase of common and preferred stock), gross; `sstk` for issuance.
- **Not pulled yet:** gross corporate bond issuance by issuer (SIFMA; Mergent FISD on WRDS), S&P 500 quarterly buybacks (S&P Dow Jones Indices), off-balance-sheet data-center financing.

## Rebuild

```bash
cd scripts
uv run --no-project --python 3.12 python -I fetch_fred.py
WRDS_USER=$(cut -d: -f4 ~/.pgpass | head -1) uv run --no-project --python 3.12 --with wrds --with pandas python -I fetch_wrds.py
uv run --no-project --python 3.12 --with numpy==2.3.5 --with pandas==2.2.3 --with matplotlib==3.10.0 python -I build.py
cd .. && latexmk -pdf main.tex
```

`fetch_fred.py` keeps existing files unless `--refresh` is passed; `fetch_wrds.py` refuses to overwrite.
