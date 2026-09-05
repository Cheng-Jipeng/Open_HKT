# U.S. cross-border equity positions

This folder contains a reproducible counterpart to `US_Debt_Positions`, focused on U.S. cross-border equity assets and liabilities. The source files were queried or downloaded on 2026-09-04.

## Main findings

The answer depends on the accounting concept.

- **Broad IMA position (2026Q1):** U.S. equity assets abroad were **$28.106 trillion** and U.S. equity liabilities to foreigners were **$40.232 trillion**, giving a net foreign equity position of **-$12.126 trillion**.
- **Long-run change:** the net equity position was positive in 1990 and peaked at **$4.056 trillion in 2007Q4**. It first turned negative in **2018Q3** and reached **-$13.016 trillion in 2025Q4**, before narrowing in 2026Q1.
- **Latest U.S. portfolio-equity assets survey (December 2025, preliminary):** the total was **$15.246 trillion**. The largest issuer residence was the **Cayman Islands**, at **$2.507 trillion (16.4%)**, followed by the United Kingdom, Canada, and Japan.
- **Latest U.S. portfolio-equity liabilities survey (June 2025, final):** the total was **$19.860 trillion**. The largest reported holder/custody residence was the **Cayman Islands**, at **$2.160 trillion (10.9%)**, closely followed by Canada and the United Kingdom.
- **Private U.S. holders of foreign portfolio equity (June 2025):** other financial corporations held **$9.581 trillion**, or **70.3%** of the $13.619 trillion private-sector panel.
- **U.S. corporate-equity capitalization (2026Q1):** total U.S.-issued corporate equity was **$91.857 trillion**. Foreign residents held **$19.443 trillion (21.2%)**; the exact domestic residual was **$72.414 trillion (78.8%)**.

The Cayman result should not be read as a claim about ultimate beneficial ownership. Fund domicile, security issuance, and custody chains make financial-centre geography quantitatively important on both sides of the U.S. balance sheet.

## Three complementary data concepts

1. **Quarterly IMA gross positions.** `ROWEISQ027S` is the rest of world's equity liability and is therefore a U.S. foreign asset. `ROWEINQ027S` is the rest of world's equity asset and is therefore a U.S. foreign liability. These are the broad macroeconomic stocks used in Figures 02, 03, and 07.
2. **Annual TIC portfolio country surveys.** The asset panel assigns securities to the foreign issuer's residence. The liability panel assigns U.S. securities to the reported foreign holder/custody residence. These panels exclude direct investment and therefore should not be forced to reconcile to the broader IMA totals.
3. **Treasury/CPIS U.S. holder sectors.** The sector table describes private U.S. holders of foreign portfolio equity. It is not an economy-wide sector decomposition and excludes direct investment and government positions.
4. **U.S. equity capitalization by holder residence.** Financial Accounts series `LM883164105` measures the market value of U.S.-issued corporate equity outstanding, while `LM263064105` measures foreign-resident holdings of U.S. issues. Domestic holdings equal the first series minus the second, so Figure 10 obeys an exact accounting identity. This capitalization concept includes public and closely held corporate equity and excludes mutual-fund shares.

TIC means **Treasury International Capital**, the U.S. Treasury reporting system for cross-border financial positions and transactions.

## Long-run period divisions

Figures 07-09 use the period divisions in `AHP_NFA`:

- 1990Q1-2001Q4;
- 2002Q1-2007Q4;
- 2008Q1-2023Q3; and
- a post-AHP extension beginning in 2023Q4.

The quarterly IMA series begins in 1990. The usable two-sided TIC country decomposition begins in 1994 because the official survey archive is not quarterly and does not provide a balanced country panel from 1990.

## Foreign-country decompositions

Figure 08 is the preferred **economic-function and reported-location** decomposition. It contains nine mutually exclusive groups:

- Japan;
- mainland China;
- United Kingdom;
- other East Asian exporters: South Korea and Taiwan;
- financial/offshore centres, including separately reported financial centres and historical geographic bridges;
- identifiable core EU-27 members outside the designated financial-centre subset;
- Middle Eastern commodity exporters, using historical aggregate bridges where necessary;
- Canada and other advanced economies: Australia, Canada, Israel, New Zealand, and Norway; and
- an exact all-other-foreign residual.

This version is economically interpretable, but it intentionally treats financial centres as a separate location-role category rather than mechanically assigning every EU member to the EU group. The complete, non-overlapping membership map is in `equity_functional_crosswalk.csv`.

Figure 09 is the **stable named-economy panel**. It separately identifies Japan, mainland China, the United Kingdom, Canada, Hong Kong, Taiwan, Singapore, and South Korea, with every other reported location placed in an exact residual. It sacrifices regional detail but reduces artificial changes caused by historical reporting breaks and countries entering or leaving separately reported rows.

Both Figure 08 and Figure 09 show assets and liabilities in parallel, in levels and shares. Every survey-date/side panel contains nine groups and adds exactly to the corresponding official survey total.

## Survey conventions and caveats

- A TIC asterisk denotes a position below $0.5 million. The data builder records it at the $0.25 million midpoint and flags the observation as `suppressed_midpoint_lt_0_5m`.
- The private-holder sector cells differ from the reported total by $6 million because of published rounding. The difference is retained explicitly as `Survey rounding residual`.
- Historical aggregates such as British West Indies, Belgium-Luxembourg, and Netherlands Antilles are used as labelled bridges only when their constituent economies are unavailable. Once member economies are reported separately, the members are summed into the same functional category and any obsolete aggregate `*` placeholder is ignored. This prevents reporting transitions from creating artificial movements between financial/offshore centres and the residual.
- Country histories use irregular benchmark/survey dates before the annual sequence becomes regular. No interpolation is used in the country decompositions.
- The December 2025 asset survey is preliminary; the June 2025 liability survey is final.

## Figures

- `figures/01_latest_us_holder_sectors_foreign_equity.*`: private U.S. sector holders of foreign portfolio equity.
- `figures/02_gross_equity_positions_history.*`: quarterly gross asset and liability positions, 1990-present.
- `figures/03_equity_asset_liability_shares.*`: shares of gross equity and the net foreign equity position.
- `figures/04_latest_equity_asset_country_ranking.*`: latest foreign issuer-residence ranking for U.S. portfolio equity assets.
- `figures/05_latest_equity_liability_country_ranking.*`: latest foreign holder/custody-residence ranking for U.S. portfolio equity liabilities.
- `figures/06_country_histories_assets_liabilities.*`: histories of the largest current locations on both sides.
- `figures/07_long_run_gross_net_equity_positions.*`: quarterly gross and net positions in dollars and relative to corporate GVA, with AHP period bands.
- `figures/08_long_run_equity_functional_decomposition.*`: preferred functional/location-role decomposition.
- `figures/09_long_run_equity_stable_panel_decomposition.*`: stable named-economy robustness decomposition.
- `figures/10_us_equity_capitalization_domestic_foreign.*`: quarterly U.S. corporate-equity capitalization split between domestic and foreign residents, in levels and shares.

Every figure is available in both PNG and PDF.

## Data and code files

- `us_cross_border_equity_positions.xlsx`: formatted workbook with a formula-linked summary, current rankings, complete country histories, both decompositions, crosswalks, and source register.
- `us_cross_border_equity_positions_quarterly.csv`: quarterly IMA assets, liabilities, net and gross positions, shares, corporate GVA, ratios, and AHP labels.
- `us_portfolio_equity_assets_by_country.csv`: full TIC asset-side issuer-residence history.
- `us_portfolio_equity_liabilities_by_country.csv`: full TIC liability-side reported-holder/custody history.
- `latest_equity_asset_country_ranking.csv` and `latest_equity_liability_country_ranking.csv`: latest survey rankings.
- `latest_us_holder_sector_equity_assets.csv`: June 2025 private U.S. holder-sector panel.
- `long_run_equity_functional_decomposition.csv`: exact nine-way Figure 08 data.
- `long_run_equity_stable_panel_decomposition.csv`: exact nine-way Figure 09 data.
- `equity_functional_crosswalk.csv` and `equity_stable_panel_crosswalk.csv`: classification definitions and historical bridges.
- `us_equity_positions_source_metadata.csv`: exact source identifiers, definitions, frequencies, units, and URLs.
- `summary_statistics.json`: compact machine-readable headline results.
- `openecon_query_log.json`: OpenEcon query provenance and official-source fallback record.
- `us_equity_capitalization_domestic_foreign_quarterly.csv`: exact quarterly domestic/foreign capitalization decomposition, 1990-present.
- `us_equity_capitalization_source_metadata.csv`: exact series crosswalk and official-source URLs for Figure 10.
- `us_equity_capitalization_summary.json`: latest values and accounting validation for Figure 10.
- `openecon_equity_capitalization_query_log.json`: successful OpenEcon query provenance for the capitalization series.
- `raw/`: unmodified downloaded FRED, TIC, and Treasury/CPIS source files.
- `build_us_equity_data.py`: reproducible data download, cleaning, grouping, and audit logic.
- `plot_us_equity_positions.py`: reproducible nine-figure generator.
- `build_us_equity_capitalization.py` and `plot_us_equity_capitalization.py`: isolated, reproducible Figure 10 data and plotting workflow.
- `build_us_equity_workbook.mjs`: reproducible formatted-workbook generator using the Codex spreadsheet runtime.

## Sources and provenance

- Data by OpenEcon - https://data.openecon.ai
- FRED `ROWEISQ027S` - https://fred.stlouisfed.org/series/ROWEISQ027S
- FRED `ROWEINQ027S` - https://fred.stlouisfed.org/series/ROWEINQ027S
- FRED corporate GVA `A451RC1Q027SBEA` - https://fred.stlouisfed.org/series/A451RC1Q027SBEA
- FRED U.S. corporate-equity capitalization `BOGZ1LM883164105Q` - https://fred.stlouisfed.org/series/BOGZ1LM883164105Q
- FRED foreign holdings of U.S. corporate equity `BOGZ1LM263064105Q` - https://fred.stlouisfed.org/series/BOGZ1LM263064105Q
- Federal Reserve Financial Accounts Table L.224 - https://www.federalreserve.gov/releases/z1/20250911/html/l224.htm
- Treasury TIC U.S. claims from holdings of foreign securities - https://home.treasury.gov/data/treasury-international-capital-tic-system/tic-forms-instructions/us-claims-on-foreigners-from-holdings-of-foreign-securities
- Treasury TIC U.S. liabilities from foreign holdings of U.S. securities - https://home.treasury.gov/data/treasury-international-capital-tic-system/us-liabilities-to-foreigners-from-holdings-of-us-securities
- Treasury/CPIS securities holdings - https://home.treasury.gov/data/treasury-international-capital-tic-system-home-page/tic-forms-instructions/securities-c-annual-cross-us-border-portfolio-holdings

OpenEcon was queried for both exact IMA equity series. It returned no exact candidate and no data payload for either request. Those connector responses were recorded but were not treated as observations. The builder then downloaded the exact official FRED series and Treasury survey files directly, preserving an auditable source chain.

## Reproduction

From this directory, run:

```text
python3 build_us_equity_data.py
/opt/anaconda3/bin/python3 plot_us_equity_positions.py
/Users/jipengcheng/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node build_us_equity_workbook.mjs
python3 build_us_equity_capitalization.py
/opt/anaconda3/bin/python3 plot_us_equity_capitalization.py
```

The workbook builder defaults to the installed Codex `@oai/artifact-tool` module. If that runtime moves, set `CODEX_ARTIFACT_TOOL_PATH` to the absolute path of `artifact_tool.mjs` before running it.

Official endpoints may revise historical observations. A later rerun can therefore change both the latest date and earlier values.
