# Holders of U.S. Treasury securities

This folder contains a reproducible descriptive analysis of who holds U.S. Treasury securities. The data were queried on 2026-09-04.

## Main finding

The answer depends on the unit of comparison.

- **Broad holder sector (2026Q1):** the **rest of the world** is largest, with **$9.317 trillion**, or **32.1%** of the $28.998 trillion reported in Financial Accounts Table L.210.
- **Largest domestic sector (2026Q1):** the **Federal Reserve**, with **$4.000 trillion** (13.8%).
- **Individual foreign economy (June 2026):** **Japan**, with **$1.117 trillion**, followed by the United Kingdom ($0.940 trillion) and mainland China ($0.633 trillion).
- **Official versus private foreign holders (June 2026):** foreign official institutions held **$3.778 trillion** (40.6% of total foreign holdings); private and other foreign holders accounted for the remaining **$5.521 trillion** (59.4%).

Thus, “foreign investors” are collectively the largest sector, but Japan is the largest individual foreign economy. The Federal Reserve is the largest single domestic sector in the non-overlapping Financial Accounts classification.

## Data interpretation

The sector and country results are complementary rather than mechanically comparable:

1. The sector panel uses the Federal Reserve's Financial Accounts Table L.210 definition of **marketable Treasury securities**, net of premiums and discounts, held outside the federal government. It is quarterly and end-of-period.
2. The country panel uses Treasury International Capital (TIC) estimates of foreign holdings of Treasury bills, bonds, and notes. It is monthly and includes marketable and nonmarketable securities.
3. TIC country attribution is primarily custody-based. A security held through a custodian in Belgium, the Cayman Islands, or the United Kingdom need not be beneficially owned by a resident of that economy.
4. The Financial Accounts household sector includes nonprofit organizations and is partly residual; historical negative values should not be interpreted literally as household short positions.

## Long-run decomposition

Figures 07–09 use the period divisions in `AHP_NFA`: 1990Q1–2001Q4, 2002Q1–2007Q4, 2008Q1–2023Q3, and a post-AHP extension beginning in 2023Q4.

The sector decomposition contains four mutually exclusive categories:

- **Rest of world:** the L.210 foreign holder sector.
- **Federal Reserve:** the Federal Reserve Banks' Treasury position.
- **Domestic government and public pensions:** state and local governments, federal government pension funds, and state and local pension funds.
- **Other domestic holders:** the exact residual needed to reconcile the preceding categories to the L.210 total. It includes households and nonprofits, nonfinancial businesses, banks, investment funds, insurers, pension funds not included above, dealers, GSEs, and other domestic financial entities.

Federal intragovernmental holdings are not part of L.210's marketable-securities holder decomposition. Consequently, the government category should not be interpreted as total Treasury trust-fund or intragovernmental debt.

The country-level TIC archive starts in March 2000, so the foreign decompositions begin in 2000 rather than imputing missing 1990–1999 country positions. Country attribution is custody-based; the figures should therefore be read as a decomposition of reported locations, not ultimate beneficial ownership.

Figure 08 is the preferred economic-function/custody-role decomposition. It separates Japan, mainland China, the United Kingdom, other East Asian exporters (Taiwan and South Korea), financial and offshore centres, identifiable core EU-27 economies, commodity exporters, Canada and other advanced economies, and an all-other-foreign residual. Financial/offshore centres include the historical Belgium–Luxembourg and Caribbean Banking Centers bridges plus Ireland, the Netherlands, Switzerland, Hong Kong, and Singapore. Core EU-27 therefore excludes Belgium, Luxembourg, Ireland, and the Netherlands to avoid overlap. Commodity exporters use TIC's historical `Oil Exporters` aggregate before the 2012 reporting break and separately reported Gulf economies thereafter. This grouping is economically informative but necessarily inherits custody-location and historical-classification breaks.

Figure 09 is the stable-panel robustness decomposition. It displays only consistently identifiable large economies—Japan, mainland China, the United Kingdom, Hong Kong, Taiwan, Singapore, and South Korea—and puts every other reported location into an exact residual. This sacrifices regional detail but minimizes artificial changes caused by countries entering or leaving TIC's separately reported rows. Both foreign decompositions retain every monthly total and add exactly to total foreign Treasury holdings.

Long-run descriptive patterns:

- The rest-of-world share rose from 21.2% in 1990Q1 to a peak of 57.3% in 2008Q2, before falling to 32.1% in 2026Q1.
- The Federal Reserve share rose sharply after the global financial crisis and again in 2020, peaked at 26.4% in 2021Q4, and declined to 13.8% by 2026Q1.
- Domestic government and public-pension holdings fell from 21.2% of the L.210 total in 1990Q1 to 7.4% in 2026Q1.
- Within foreign holdings, mainland China's share peaked at 28.2% in July 2011 and fell to 6.8% by June 2026; Japan's share fell from 26.0% in March 2000 to 12.0%. In June 2026, financial/offshore centres were the largest Figure 08 group at 27.4%, while the Figure 09 stable-panel residual was 60.6%.

## Files

- `us_treasury_debt_holders.xlsx`: formatted workbook with summary, current rankings, full sector and country panels, formulas, and source notes.
- `figures/`: nine publication-ready plots in PNG and PDF.
- `figures/07_long_run_coarse_holder_decomposition.*`: 1990–present coarse sector levels and shares.
- `figures/08_long_run_foreign_decomposition.*`: preferred economic-function/custody-role decomposition, March 2000–June 2026.
- `figures/09_long_run_foreign_decomposition_granular.*`: stable-panel economy decomposition, March 2000–June 2026.
- `long_run_sector_decomposition_quarterly.csv`: exact four-way L.210 decomposition with AHP period labels.
- `long_run_foreign_decomposition_functional_monthly.csv`: nine-way Figure 08 decomposition that adds exactly to the TIC foreign total.
- `long_run_foreign_functional_crosswalk.csv`: exact Figure 08 membership and historical-bridge definitions.
- `long_run_foreign_decomposition_stable_panel_monthly.csv`: eight-way Figure 09 decomposition that adds exactly to the TIC foreign total.
- `long_run_foreign_stable_panel_crosswalk.csv`: exact Figure 09 membership definitions.
- `latest_us_treasury_sector_ranking.csv`: latest non-overlapping sector ranking.
- `latest_foreign_country_ranking.csv`: latest foreign-country ranking.
- `us_treasury_sector_positions_quarterly.csv`: long quarterly sector panel from 1990Q1 through 2026Q1.
- `foreign_treasury_holdings_monthly.csv`: long monthly TIC panel from March 2000 through June 2026.
- `us_treasury_sector_series_metadata.csv`: sector definitions and exact FOF/FRED series identifiers.
- `summary_statistics.json`: compact machine-readable headline results.
- `openecon_query_log.json`: OpenEcon query provenance and fallback record.
- `raw/`: downloaded source files.
- `build_us_treasury_holders.py` and `plot_us_treasury_holders.jl`: reproducible data and plotting scripts.
- `plot_long_run_treasury_decomposition.jl` and `plot_proposed_foreign_decompositions.jl`: reproducible long-run aggregation and plotting scripts.

## Sources and provenance

- Data by OpenEcon — https://data.openecon.ai
- Federal Reserve Financial Accounts, Table L.210 — https://www.federalreserve.gov/apps/FOF/Guide/L210.pdf
- FRED sector series — exact URLs are stored row by row in the CSV and workbook.
- U.S. Treasury TIC Major Foreign Holders — https://ticdata.treasury.gov/Publish/slt_table5.html

OpenEcon successfully resolved the key rest-of-world position to FRED series `ROWTSEQ027S`. Because the broader multi-series OpenEcon requests timed out, the scripts then downloaded the exact official FRED series and TIC source files in bulk; this preserves the same provider definitions while making the extraction auditable and reproducible.

## Reproduction

From this directory, run:

```text
python3 build_us_treasury_holders.py
julia plot_us_treasury_holders.jl
julia plot_long_run_treasury_decomposition.jl
```

The source endpoints can revise historical observations. Rerunning the scripts later may therefore change both the latest date and earlier values.
